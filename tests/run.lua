-- Tests for ModPage's pure helpers. Run from the repo root: lua tests/run.lua

local function stub()
    return setmetatable({}, { __index = function() return function() end end })
end
CreateFrame = stub
UIParent = stub()
SlashCmdList = {}

local ns = {}
assert(loadfile("ModPage.lua"))("ModPage", ns)
assert(loadfile("Options.lua"))("ModPage", ns)

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

-- StepPage: Off sits below page 1; the ends don't wrap
local S = ns.StepPage
check("off + 1 is page 1", S(nil, 1), 1)
check("page 1 - 1 is off", S(1, -1), nil)
check("off - 1 stays off", S(nil, -1), nil)
check("page 2 + 1", S(2, 1), 3)
check("page 15 + 1 stays 15", S(15, 1), 15)

-- Wiring between the files
check("settings page hooked up", type(ns.OnChanged), "function")
check("SetPage action", type(ns.actions.SetPage), "function")
check("SetPage refuses before load", (ns.actions.SetPage("shift", 3)), false)

print(("%d/%d passed"):format(total - failures, total))
os.exit(failures == 0 and 0 or 1)
