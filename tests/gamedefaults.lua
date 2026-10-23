-- The game's own settings the addon wants on (Core\Defaults.lua): Action
-- Bars 2 to 5, nameplates on in the Large style with class-coloured friendly
-- names, the damage meter on and reset in each new instance - once per
-- character, checked again after writing (the server can hand the old values
-- back), set again by Reset everything, and the player's own change kept.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

Enum.NamePlateStyle = Enum.NamePlateStyle or { Thin = 1, Modern = 2, Block = 3 }
-- The client's settings as a fresh character has them: everything off.
local store = {
    nameplateShowEnemies = "0", nameplateShowAll = "0", nameplateStyle = "1",
    nameplateShowFriendlyClassColor = "0", nameplateUseClassColorForFriendlyPlayerUnitNames = "0",
    damageMeterEnabled = "0", damageMeterResetOnNewInstance = "0",
    countdownForCooldowns = "0",
}
local realCVar = C_CVar
C_CVar = {
    GetCVar = function(name) if store[name] ~= nil then return store[name] end return realCVar.GetCVar(name) end,
    SetCVar = function(name, value)
        if store[name] ~= nil then store[name] = tostring(value) return true end
        return realCVar.SetCVar(name, value)
    end,
}
local toggles = { false, false, false, false, true, false, false }   -- bars 2 ... 8
local sets = 0
GetActionBarToggles = function() return unpack(toggles) end
SetActionBarToggles = function(...)
    sets = sets + 1
    toggles = { ... }
end

LoadAddon()

local Core = DogsForeverUI
local GD = Core.GameDefaults
local LARGE = tostring(Enum.NamePlateStyle.Modern)

local function AllOn()
    return store.nameplateShowEnemies == "1" and store.nameplateShowAll == "1"
        and store.nameplateStyle == LARGE
        and store.nameplateShowFriendlyClassColor == "1"
        and store.nameplateUseClassColorForFriendlyPlayerUnitNames == "1"
        and store.damageMeterEnabled == "1" and store.damageMeterResetOnNewInstance == "1"
        and store.countdownForCooldowns == "1"
end
local function BarsOn() return toggles[1] and toggles[2] and toggles[3] and toggles[4] and toggles[5] end

Section("a first start")
do
    check("a module of its own, one count", Core:GetModule("gamedefaults") == GD and GD.db.done == 0)
    Login()
    Tick(0.1)
    check("nothing before the saved settings can be trusted", store.nameplateShowAll == "0" and sets == 0)
    Tick(2.1)
    Tick(0.6)
    check("then: nameplates on, always shown, Large, friendly players in class colours; the damage meter on and auto reset",
        AllOn(), store.nameplateStyle)
    check("Action Bars 2 to 5 on in the game's options, the others as they were", BarsOn() and not toggles[6])
    check("counted as done", GD.db.done == #GD.STEPS)
end

Section("checked after writing")
do
    -- The server hands the old values back a moment later.
    store.nameplateShowAll, store.nameplateShowEnemies = "0", "0"
    toggles = { false, false, false, false, true, false, false }
    Tick(3.1)
    check("written again", store.nameplateShowAll == "1" and store.nameplateShowEnemies == "1" and BarsOn())
    for _ = 1, 3 do Tick(15) end
    check("and then left alone: watching over", not GD.Watching())
    store.nameplateShowAll = "0"
    toggles[3] = false
    Fire("PLAYER_ENTERING_WORLD")
    for _ = 1, 3 do Tick(15) end
    check("the player's own change afterwards stays, through a reload's events",
        store.nameplateShowAll == "0" and toggles[3] == false)
end

Section("never in combat")
do
    GD.db.done = 0
    inCombat = true
    GD.Try()
    Tick(0.6)
    check("not in combat", store.nameplateShowAll == "0" and GD.db.done == 0)
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    check("but as it ends", store.nameplateShowAll == "1" and GD.db.done == #GD.STEPS)
end

Section("Reset everything sets them all again")
do
    for _ = 1, 3 do Tick(15) end
    store.damageMeterResetOnNewInstance = "0"
    store.nameplateStyle = "1"
    Core:ResetAll()
    Tick(0.6)
    check("set again", AllOn() and GD.db.done == #GD.STEPS)
end

Section("no key bound, kept or loaded: the player's own bindings untouched")
do
    local cycle = Core.Frames.UnitPlate.CYCLE
    SetBinding("1", "ACTIONBUTTON1")
    local loads, saves = LoadBindings, SaveBindings
    local touched = false
    LoadBindings = function(...) touched = true; return loads(...) end
    SaveBindings = function(...) touched = true; return saves(...) end
    Core:ResetAll()
    for _ = 1, 3 do Tick(15) end
    LoadBindings, SaveBindings = loads, saves
    check("the party cycle unbound", GetBindingKey(cycle[1].command) == nil and GetBindingKey(cycle[2].command) == nil)
    check("an action bar key still bound, nothing loaded or saved", GetBindingAction("1") == "ACTIONBUTTON1" and not touched)
end

C_CVar = realCVar
check("nothing forbidden called", #forbiddenCalls == 0)
Summary()
