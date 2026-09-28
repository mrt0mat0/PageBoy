-- Tests for PageBoy's pure helpers. Run from the repo root: lua tests/run.lua

local function stub()
    return setmetatable({}, { __index = function() return function() end end })
end
CreateFrame = stub
UIParent = stub()
SlashCmdList = {}
StaticPopupDialogs = {}

local ns = {}
assert(loadfile("PageBoy.lua"))("PageBoy", ns)
assert(loadfile("Options.lua"))("PageBoy", ns)

local failures, total = 0, 0
local function check(name, got, want)
    total = total + 1
    if got ~= want then
        failures = failures + 1
        print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
    end
end

-- PageCondition
local C = ns.PageCondition
check("shift only", C({ shift = 2 }), "[overridebar][vehicleui][possessbar] default; [mod:shift] 2; default")
check("all three, Shift first", C({ alt = 9, shift = 2, ctrl = 3 }),
    "[overridebar][vehicleui][possessbar] default; [mod:shift] 2; [mod:ctrl] 3; [mod:alt] 9; default")
check("nothing set", C({}), "[overridebar][vehicleui][possessbar] default; default")
check("stealth only, not Shadowmeld", C({ stealth = 8 }), "[overridebar][vehicleui][possessbar] default; [bonusbar:1, stealth] 8; default")
check("modifiers win over stealth", C({ stealth = 8, shift = 2 }),
    "[overridebar][vehicleui][possessbar] default; [mod:shift] 2; [bonusbar:1, stealth] 8; default")

-- ParsePage
local P = ns.ParsePage
check("page 7", P("7"), 7)
check("off", P("off"), false)
check("OFF any case", P("OFF"), false)
check("0 means off", P("0"), false)
check("too high", P("16"), nil)
check("not a number", P("seven"), nil)
check("no fractions", P("2.5"), nil)
check("empty", P(""), nil)

-- PageLabel
local PL = ns.PageLabel
check("off label", PL(nil), "Off")
check("page 2 label", PL(2), "Page 2  ·  Main Bar Page 2")
check("page 14 label", PL(14), "Page 14  ·  Action Bar 7")
for page = 1, ns.MAX_PAGE do
    check("page " .. page .. " has a use", PL(page):find("·  %S") ~= nil, true)
end

-- Wiring between the files
check("settings page hooked up", type(ns.OnChanged), "function")
check("Alt has self-cast help", ns.HELP.alt and ns.HELP.alt[1], "Alt and Self-Cast")
check("Shift has no help mark", ns.HELP.shift, nil)
check("Stealth has help", ns.HELP.stealth and ns.HELP.stealth[1], "Stealth Bar")
check("stealth is a trigger", ns.TRIGGERS[4], "stealth")
check("SetPage action", type(ns.actions.SetPage), "function")
check("SetPage refuses before load", (ns.actions.SetPage("shift", 3)), false)

-- Keybind conflicts: remove them, then undo, with fake bindings
local BINDS
GetBindingKey = function(command)
    local keys = {}
    for key, action in pairs(BINDS) do if action == command then keys[#keys + 1] = key end end
    table.sort(keys)
    return unpack and unpack(keys) or table.unpack(keys)
end
GetBindingAction = function(key) return BINDS[key] or "" end
SetBinding = function(key, action) BINDS[key] = action end
local saves = 0
SaveBindings = function() saves = saves + 1 end
GetCurrentBindingSet = function() return 1 end
InCombatLockdown = function() return false end

BINDS = { ["1"] = "ACTIONBUTTON1", ["2"] = "ACTIONBUTTON2", ["SHIFT-1"] = "ACTIONPAGE1",
    ["CTRL-Q"] = "ACTIONBUTTON3", ["SHIFT-CTRL-Q"] = "SOMETHING" }
PageBoyCharDB = { pages = { shift = 2, stealth = 8 } }
check("one conflict (SHIFT-1), stealth isn't a key", #ns.Conflicts(), 1)
check("conflict text", ns.ConflictText(ns.Conflicts()[1]), "SHIFT-1 = ACTIONPAGE1")
check("remove succeeds", (ns.actions.ClearConflicts()), true)
check("SHIFT-1 unbound", BINDS["SHIFT-1"], nil)
check("bindings saved", saves, 1)
check("no conflicts left", #ns.Conflicts(), 0)
check("undo available", ns.CanUndoBindings(), true)
check("undo succeeds", (ns.actions.RestoreBindings()), true)
check("SHIFT-1 restored", BINDS["SHIFT-1"], "ACTIONPAGE1")
check("undo used up", ns.CanUndoBindings(), false)

ns.actions.ClearConflicts()
BINDS["SHIFT-1"] = "MY_OWN_MACRO"
ns.actions.RestoreBindings()
check("undo doesn't overwrite a newer binding", BINDS["SHIFT-1"], "MY_OWN_MACRO")

InCombatLockdown = function() return true end
check("no keybind changes in combat", (ns.actions.ClearConflicts()), false)
PageBoyCharDB, InCombatLockdown = nil, nil

print(("%d/%d passed"):format(total - failures, total))
os.exit(failures == 0 and 0 or 1)
