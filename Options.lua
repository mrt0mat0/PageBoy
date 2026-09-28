-- PageBoy settings page: Options > AddOns > PageBoy, or /pageboy.
-- Changes go through ns.actions.SetPage, the same code the slash command uses.

local addonName, ns = ...
ns = ns or {}

local LEFT = 16
local ROW_TOP, ROW_GAP = -96, 32
local LABELS = { shift = "Shift", ctrl = "Ctrl", alt = "Alt" }

local panel = CreateFrame("Frame")
panel.name = "PageBoy"
local built, Refresh
local widgets = { values = {} }

local function Do(ok, message)
    if not ok and message then print("|cff33ff99PageBoy|r: " .. message) end
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
local function ModifierRow(mod, y)
    Text(panel, "GameFontHighlight", LABELS[mod], LEFT, y - 4)
    Button(panel, "-", 24, LEFT + 70, y, function()
        Do(ns.actions.SetPage(mod, ns.StepPage(ns.GetPage(mod), -1)))
    end)
    local value = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    value:SetPoint("TOPLEFT", LEFT + 98, y - 4)
    value:SetWidth(70)
    value:SetJustifyH("CENTER")
    Button(panel, "+", 24, LEFT + 172, y, function()
        Do(ns.actions.SetPage(mod, ns.StepPage(ns.GetPage(mod), 1)))
    end)
    widgets.values[mod] = value
end

local function Build()
    local version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(addonName, "Version")
    Text(panel, "GameFontNormalLarge", "PageBoy", LEFT, -16)
    Text(panel, "GameFontDisableSmall", "Version " .. (version or "?") .. "  ·  Settings are saved per character", LEFT, -40)

    Text(panel, "GameFontNormal", "Hold a Key to Page Your Main Bar", LEFT, -70)
    for i, mod in ipairs(ns.MODIFIERS) do ModifierRow(mod, ROW_TOP - (i - 1) * ROW_GAP) end

    local below = ROW_TOP - #ns.MODIFIERS * ROW_GAP - 4
    Text(panel, "GameFontDisableSmall",
        "Alt is the game's default self-cast key. Paging on Alt stops Alt self-cast on your main bar.",
        LEFT, below, 560)
    Text(panel, "GameFontDisableSmall",
        "Pages 7 to 10 hold druid form, warrior stance and rogue stealth bars, so paging there shows those bars.",
        LEFT, below - 16, 560)

    Text(panel, "GameFontNormal", "Keybind Conflicts", LEFT, below - 52)
    widgets.conflicts = Text(panel, "GameFontHighlightSmall", "", LEFT, below - 72, 560)
    built = true
end

function Refresh()
    if not built then return end
    for mod, value in pairs(widgets.values) do
        local page = ns.GetPage(mod)
        value:SetText(page and ("Page " .. page) or "|cff999999Off|r")
    end
    local found = ns.Conflicts()
    if #found == 0 then
        widgets.conflicts:SetText("None. Your modifiers reach your action buttons.")
    else
        widgets.conflicts:SetText("These key combos are bound to something else, so they won't reach your paged buttons."
            .. " Unbind them in Options > Keybindings:\n\n" .. table.concat(found, "\n"))
    end
end

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
