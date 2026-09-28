-- PageBoy settings page: Options > AddOns > PageBoy, or /pageboy.
-- Changes go through ns.actions.SetPage, the same code the slash command uses.

local addonName, ns = ...
ns = ns or {}

local LEFT = 16
local ROW_TOP, ROW_GAP = -96, 36
local LABELS = { shift = "Shift", ctrl = "Ctrl", alt = "Alt" }

-- Hover help shown next to a modifier's label: title, then the explanation.
local HELP = {
    alt = { "Alt and Self-Cast",
        "By default, holding Alt while casting a helpful spell casts it on yourself.\n\n"
        .. "If Alt pages your bar, Alt+key fires the spell on your Alt page instead, and those "
        .. "spells always self-cast because Alt is still held.\n\n"
        .. "No problem if you don't self-cast with Alt. Otherwise, move self-cast to another "
        .. "key in the game's options, or page with Shift or Ctrl instead." },
}
ns.HELP = HELP

local panel = CreateFrame("Frame")
panel.name = "PageBoy"
local built, Refresh
local widgets = { values = {} }

local function Do(ok, message, always)
    if message and (always or not ok) then print("|cff33ff99PageBoy|r: " .. message) end
    Refresh()
end

local function Text(parent, font, text, x, y, width)
    local fs = parent:CreateFontString(nil, "ARTWORK", font)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetJustifyH("LEFT")
    if width then fs:SetWidth(width) end
    fs:SetText(text)
    return fs
end

local function Button(parent, text, width, x, y, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- Shift / Ctrl / Alt:  [-] Page 2 [+]
-- A "(?)" that explains something on hover.
local function HelpMark(anchor, help)
    local mark = CreateFrame("Frame", nil, panel)
    mark:SetSize(20, 16)
    mark:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
    local text = mark:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetAllPoints()
    text:SetText("(?)")
    mark:EnableMouse(true)
    mark:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(help[1], 1, 0.82, 0)
        GameTooltip:AddLine(help[2], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    mark:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Dropdown of Off and every page. Newer clients have the DropdownButton menus; older
-- ones only UIDropDownMenu, so fall back to that when the newer template isn't there.
local function PageDropdown(mod, x, y)
    local function Choose(page) Do(ns.actions.SetPage(mod, page)) end
    local options = { false }
    for page = 1, ns.MAX_PAGE do options[#options + 1] = page end

    local ok, dd = pcall(CreateFrame, "DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    if ok and dd and dd.SetupMenu then
        dd:SetPoint("TOPLEFT", x, y + 2)
        dd:SetWidth(230)
        dd:SetupMenu(function(_, root)
            for _, page in ipairs(options) do
                local value = page or nil
                root:CreateRadio(ns.PageLabel(value),
                    function() return ns.GetPage(mod) == value end,
                    function() Choose(value) end)
            end
        end)
        dd.Update = function(self) self:GenerateMenu() end
        return dd
    end

    dd = CreateFrame("Frame", "PageBoyDropdown" .. mod, panel, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", x - 16, y + 4)
    UIDropDownMenu_SetWidth(dd, 210)
    UIDropDownMenu_Initialize(dd, function(_, level)
        for _, page in ipairs(options) do
            local value = page or nil
            local info = UIDropDownMenu_CreateInfo()
            info.text = ns.PageLabel(value)
            info.checked = ns.GetPage(mod) == value
            info.func = function() Choose(value) end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    dd.Update = function(self) UIDropDownMenu_SetText(self, ns.PageLabel(ns.GetPage(mod))) end
    return dd
end

local function ModifierRow(mod, y)
    local label = Text(panel, "GameFontHighlight", LABELS[mod], LEFT, y - 4)
    if HELP[mod] then HelpMark(label, HELP[mod]) end
    widgets.values[mod] = PageDropdown(mod, LEFT + 80, y)
end

local function Build()
    local version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(addonName, "Version")
    Text(panel, "GameFontNormalLarge", "PageBoy", LEFT, -16)
    Text(panel, "GameFontDisableSmall", "Version " .. (version or "?") .. "  ·  Settings are saved per character", LEFT, -40)

    Text(panel, "GameFontNormal", "Hold a Key to Page Your Main Bar", LEFT, -70)
    for i, mod in ipairs(ns.MODIFIERS) do ModifierRow(mod, ROW_TOP - (i - 1) * ROW_GAP) end

    local below = ROW_TOP - #ns.MODIFIERS * ROW_GAP - 4
    Text(panel, "GameFontDisableSmall",
        "Pages 7 to 10 hold druid form, warrior stance and rogue stealth bars, so paging there shows those bars.",
        LEFT, below, 560)

    Text(panel, "GameFontNormal", "Keybind Conflicts", LEFT, below - 36)
    widgets.remove = Button(panel, "Remove Conflicts", 140, LEFT, below - 56, function()
        StaticPopup_Show("PAGEBOY_REMOVE_CONFLICTS", #ns.Conflicts())
    end)
    widgets.undo = Button(panel, "Undo", 80, LEFT + 146, below - 56, function()
        local ok, message = ns.actions.RestoreBindings()
        Do(ok, message, true)
    end)
    widgets.conflicts = Text(panel, "GameFontHighlightSmall", "", LEFT, below - 86, 560)
    built = true
end

function Refresh()
    if not built then return end
    for _, dropdown in pairs(widgets.values) do dropdown:Update() end
    local found = ns.Conflicts()
    widgets.remove:SetEnabled(#found > 0)
    widgets.undo:SetShown(ns.CanUndoBindings())
    if #found == 0 then
        widgets.conflicts:SetText("None. Your modifiers reach your action buttons.")
    else
        local lines = {}
        for i, c in ipairs(found) do lines[i] = ns.ConflictText(c) end
        widgets.conflicts:SetText("These key combos are bound to something else, so they won't reach your paged buttons:\n\n"
            .. table.concat(lines, "\n"))
    end
end

StaticPopupDialogs["PAGEBOY_REMOVE_CONFLICTS"] = {
    text = "Unbind %d key combos so your modifiers reach your action buttons? PageBoy remembers them, and Undo puts them back.",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function()
        local ok, message = ns.actions.ClearConflicts()
        Do(ok, message, true)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

panel:SetScript("OnShow", function()
    if not built then Build() end
    Refresh()
end)

ns.OnChanged = function()
    if panel:IsVisible() then Refresh() end
end

-- Newer clients have the Settings panel; older ones the Interface Options frame.
if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    ns.OpenOptions = function() Settings.OpenToCategory(category:GetID()) end
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
    ns.OpenOptions = function()
        -- The first call only opens the frame on some clients; the second selects the page.
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end
