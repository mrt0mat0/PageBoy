-- PageBoy: hold Shift, Ctrl or Alt to page your main action bar.
-- While a modifier is held, the main bar's 12 buttons are told to use that modifier's page.
-- Let go and the override is cleared, so the game's own paging (form and stance bars,
-- manual page flips) takes over again. Vehicle, possess and override bars are never touched.
-- It all runs through a secure state driver, which the game evaluates itself, so it works
-- in combat without reading anything the combat restrictions protect.

local _, ns = ...
ns = ns or {}

local MODIFIERS = { "shift", "ctrl", "alt" }
local MODIFIER_KEYS = { shift = "SHIFT", ctrl = "CTRL", alt = "ALT" }
local DEFAULT_PAGES = { shift = 2 }
local MAX_PAGE = 15
local BUTTONS = 12

local function Say(text)
    print("|cff33ff99PageBoy|r: " .. text)
end

---------------------------------------------------------------------------
-- Settings (per character). Pages live under their own table so profiles can be added
-- later by pointing a character at a shared table instead.
---------------------------------------------------------------------------
local function Pages()
    return PageBoyCharDB.pages
end

-- "7" -> 7, "off" -> false, anything else -> nil (invalid).
local function ParsePage(text)
    text = (text or ""):lower()
    if text == "off" or text == "none" or text == "0" then return false end
    local n = tonumber(text)
    if n and n == math.floor(n) and n >= 1 and n <= MAX_PAGE then return n end
    return nil
end
ns.ParsePage = ParsePage

-- What each page normally belongs to, on the Retail UI that WoW Forever is built on.
-- 180 action slots make 15 pages of 12. A page whose bar you haven't turned on is free space.
local PAGE_USES = {
    [1] = "Main Bar", [2] = "Main Bar Page 2",
    [3] = "Action Bar 4", [4] = "Action Bar 5", [5] = "Action Bar 3", [6] = "Action Bar 2",
    [7] = "Form/Stance Bar", [8] = "Form/Stance Bar", [9] = "Form/Stance Bar", [10] = "Form/Stance Bar",
    [11] = "Possess/Special Bar", [12] = "Unused",
    [13] = "Action Bar 6", [14] = "Action Bar 7", [15] = "Action Bar 8",
}

local function PageLabel(page)
    if not page then return "Off" end
    return ("Page %d  ·  %s"):format(page, PAGE_USES[page] or "")
end
ns.PageLabel = PageLabel
ns.MAX_PAGE = MAX_PAGE
ns.MODIFIERS = MODIFIERS
ns.MODIFIER_KEYS = MODIFIER_KEYS

-- The state driver's rule. Special bars keep the game's own paging; otherwise the first
-- held modifier (Shift, then Ctrl, then Alt) picks the page; otherwise "default".
local function PageCondition(pages)
    local parts = { "[overridebar][vehicleui][possessbar] default" }
    for _, mod in ipairs(MODIFIERS) do
        local page = pages[mod]
        if page then parts[#parts + 1] = ("[mod:%s] %d"):format(mod, page) end
    end
    parts[#parts + 1] = "default"
    return table.concat(parts, "; ")
end
ns.PageCondition = PageCondition

---------------------------------------------------------------------------
-- Paging
---------------------------------------------------------------------------
local header = CreateFrame("Frame", "PageBoyHeader", UIParent, "SecureHandlerStateTemplate")
header:SetAttribute("_onstate-page", [[
    local page = tonumber(newstate)
    for i = 1, 12 do
        local button = self:GetFrameRef("button" .. i)
        if button then button:SetAttribute("actionpage", page) end
    end
]])

local applied = false
local function Apply()
    if InCombatLockdown() then return false end
    for i = 1, BUTTONS do
        local button = _G["ActionButton" .. i]
        if button then header:SetFrameRef("button" .. i, button) end
    end
    RegisterStateDriver(header, "page", PageCondition(Pages()))
    applied = true
    return true
end

---------------------------------------------------------------------------
-- Keybind conflicts: if Shift+1 is bound to something (by default, "Action Page 1"),
-- the game uses that binding and your button never sees the key.
---------------------------------------------------------------------------
-- Each conflict is { combo = "SHIFT-1", action = "ACTIONPAGE1" }.
local function Conflicts()
    local found = {}
    for _, mod in ipairs(MODIFIERS) do
        if Pages()[mod] then
            for i = 1, BUTTONS do
                for _, key in ipairs({ GetBindingKey("ACTIONBUTTON" .. i) }) do
                    -- A button bound to an already-modified key (CTRL-Q) has no plain key to extend.
                    if not key:find("-", 2, true) then
                        local combo = MODIFIER_KEYS[mod] .. "-" .. key
                        local action = GetBindingAction(combo)
                        if action and action ~= "" then found[#found + 1] = { combo = combo, action = action } end
                    end
                end
            end
        end
    end
    return found
end

local function ConflictText(c)
    return c.combo .. " = " .. c.action
end
ns.ConflictText = ConflictText

local function ReportConflicts()
    local found = Conflicts()
    if #found == 0 then return end
    Say(("%d key combos are bound to something else, so they won't reach your paged buttons. /pageboy has a button to remove them:"):format(#found))
    for _, c in ipairs(found) do print("  " .. ConflictText(c)) end
end

-- Unbind every conflict and remember what each was, so it can be undone.
local function ClearConflicts()
    local found = Conflicts()
    local removed = PageBoyCharDB.removedBindings or {}
    for _, c in ipairs(found) do
        removed[c.combo] = c.action
        SetBinding(c.combo, nil)
    end
    PageBoyCharDB.removedBindings = removed
    SaveBindings(GetCurrentBindingSet())
    return #found
end

-- Put back what ClearConflicts removed, unless you've bound that combo to something else since.
local function RestoreBindings()
    local restored = 0
    for combo, action in pairs(PageBoyCharDB.removedBindings or {}) do
        local current = GetBindingAction(combo)
        if not current or current == "" then
            SetBinding(combo, action)
            restored = restored + 1
        end
    end
    PageBoyCharDB.removedBindings = nil
    SaveBindings(GetCurrentBindingSet())
    return restored
end

---------------------------------------------------------------------------
-- Test build diagnostics
---------------------------------------------------------------------------
local function Show(label, value)
    print(("  %s: %s"):format(label, tostring(value)))
end

-- How the main bar is responding to paging.
local function Debug()
    Say("debug")
    local b = _G.ActionButton1
    Show("ActionButton1 exists", b ~= nil)
    if not b then return end
    local parent = b:GetParent()
    Show("parent", parent and parent:GetName())
    Show("button actionpage attribute", b:GetAttribute("actionpage"))
    Show("useparent-actionpage", b:GetAttribute("useparent-actionpage"))
    Show("parent actionpage attribute", parent and parent:GetAttribute("actionpage"))
    Show("button.action (what it shows)", b.action)
    Show("has UpdateAction method", type(b.UpdateAction) == "function")
    Show("GetActionBarPage()", GetActionBarPage and GetActionBarPage())
    Show("GetBonusBarOffset()", GetBonusBarOffset and GetBonusBarOffset())
    Show("driver rule", PageCondition(Pages()))
    Show("rule result right now", SecureCmdOptionParse(PageCondition(Pages())))
    Show("driver state", header:GetAttribute("state-page"))
    Show("in combat", InCombatLockdown())
end

-- Is a value readable, or sealed by the combat restrictions?
local function Describe(value)
    if value == nil then return "nothing" end
    if issecretvalue and issecretvalue(value) then return "SECRET (can show, can't read)" end
    local ok, text = pcall(tostring, value)   -- without issecretvalue, reading a secret throws
    if not ok then return "SECRET (can show, can't read)" end
    return "readable (" .. text .. ")"
end

local function ProbeAura(label, unit, filter)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
        Show(label, "no C_UnitAuras.GetAuraDataByIndex")
        return
    end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, 1, filter)
    if not ok then
        Show(label, "BLOCKED: " .. tostring(aura))
    elseif not aura then
        Show(label, "none to test (put one on first)")
    else
        Show(label .. " name", Describe(aura.name))
        Show(label .. " time left", Describe(aura.expirationTime))
    end
end

-- What this client lets an addon read right now, and which newer Blizzard tools exist.
local function Probe()
    Say("probe (run it out of combat, in open-world combat, and on a boss)")
    Show("in combat", InCombatLockdown())
    Show("in instance", select(2, IsInInstance()))
    Show("issecretvalue exists", issecretvalue ~= nil)
    ProbeAura("your first buff", "player", "HELPFUL")
    ProbeAura("your debuff on target", "target", "HARMFUL|PLAYER")
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, 61304)   -- the global cooldown
        if not ok then
            Show("spell cooldown", "BLOCKED: " .. tostring(info))
        else
            Show("spell cooldown duration", Describe(info and info.duration))
        end
    end
    local ok, hp = pcall(UnitHealth, "target")
    Show("target health", ok and Describe(hp) or ("BLOCKED: " .. tostring(hp)))
    local names = {}
    for _, name in ipairs({ "C_CooldownViewer", "C_CurveUtil", "C_DurationUtil", "C_EncounterTimeline",
            "C_DamageMeter", "C_Secrets", "C_UnitAuras", "C_ActionBar" }) do
        names[#names + 1] = name .. (_G[name] and " yes" or " no")
    end
    Show("APIs", table.concat(names, ", "))
end

---------------------------------------------------------------------------
-- Setup and commands
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("UPDATE_BINDINGS")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        PageBoyCharDB = PageBoyCharDB or {}
        if not PageBoyCharDB.pages then
            PageBoyCharDB.pages = {}
            for mod, page in pairs(DEFAULT_PAGES) do PageBoyCharDB.pages[mod] = page end
        end
        Apply()
        ReportConflicts()
    elseif event == "UPDATE_BINDINGS" then
        if ns.OnChanged then ns.OnChanged() end
    elseif not applied then
        Apply()   -- logged in mid-fight: set up once combat ends
    end
end)

-- Changes go through here from both the slash command and the settings page.
ns.actions = {}
function ns.actions.SetPage(mod, page)
    if not PageBoyCharDB then return false, "not loaded yet." end
    if InCombatLockdown() then return false, "can't change that in combat." end
    Pages()[mod] = page or nil
    Apply()
    if ns.OnChanged then ns.OnChanged() end
    return true
end
function ns.actions.ClearConflicts()
    if not PageBoyCharDB then return false, "not loaded yet." end
    if InCombatLockdown() then return false, "can't change keybinds in combat." end
    local n = ClearConflicts()
    if ns.OnChanged then ns.OnChanged() end
    return true, ("removed %d keybinds. Undo puts them back."):format(n)
end

function ns.actions.RestoreBindings()
    if not PageBoyCharDB then return false, "not loaded yet." end
    if InCombatLockdown() then return false, "can't change keybinds in combat." end
    local n = RestoreBindings()
    if ns.OnChanged then ns.OnChanged() end
    return true, ("restored %d keybinds."):format(n)
end

ns.CanUndoBindings = function() return PageBoyCharDB and PageBoyCharDB.removedBindings ~= nil end
ns.GetPage = function(mod) return PageBoyCharDB and Pages()[mod] end
ns.Conflicts = function() return PageBoyCharDB and Conflicts() or {} end

local function Summary()
    local parts = {}
    for _, mod in ipairs(MODIFIERS) do
        parts[#parts + 1] = ("%s: %s"):format(MODIFIER_KEYS[mod], Pages()[mod] and ("page " .. Pages()[mod]) or "off")
    end
    return table.concat(parts, ", ")
end

SLASH_PAGEBOY1 = "/pageboy"
SlashCmdList.PAGEBOY = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if not PageBoyCharDB then
        Say("not loaded yet.")
    elseif cmd == "" or cmd == "options" or cmd == "settings" then
        if InCombatLockdown() then
            Say("settings open after combat.")
        elseif ns.OpenOptions then
            ns.OpenOptions()
        else
            Say("this client has no addon settings page. /pageboy help lists the commands.")
        end
    elseif cmd == "debug" then
        Debug()
    elseif cmd == "probe" then
        Probe()
    elseif cmd == "keys" then
        local found = Conflicts()
        if #found == 0 then Say("no keybind conflicts.") else ReportConflicts() end
    elseif InCombatLockdown() then
        Say("can't change that in combat.")
    elseif MODIFIER_KEYS[cmd] then
        local page = ParsePage(arg)
        if page == nil then
            Say(("use /pageboy %s <1-%d> or /pageboy %s off."):format(cmd, MAX_PAGE, cmd))
            return
        end
        local ok, why = ns.actions.SetPage(cmd, page)
        if not ok then Say(why) return end
        Say(Summary())
        ReportConflicts()
    else
        Say(Summary())
        print("  /pageboy  -  open the settings page")
        print("  /pageboy shift|ctrl|alt <page or off>  -  set a modifier's page")
        print("  /pageboy keys  -  list keybinds that block a modifier")
        print("  /pageboy debug  -  how the main bar is responding")
        print("  /pageboy probe  -  what this client lets addons read")
    end
end
