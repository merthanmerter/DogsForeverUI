-- The core: one addon, eight modules, one saved table.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

local EXPECTED = { "placing", "frames", "castbar", "fsr", "combo", "xp", "loot", "toasts", "cooldowns", "threat", "chat", "menus",
                   "actionbars", "gameframes", "gamedefaults", "fishing", "skinning" }

Section("loading")
LoadAddon()
local Core = DogsForeverUI

check("the addon's namespace exists", type(Core) == "table")
do
    local keys = {}
    for index, module in ipairs(Core.modules) do keys[index] = module.key end
    check("thirteen modules register, in .toc order",
        table.concat(keys, ",") == table.concat(EXPECTED, ","), table.concat(keys, ","))
end
for _, key in ipairs(EXPECTED) do
    local module = Core:GetModule(key)
    check(key .. " has a title and a settings section",
        module and type(module.title) == "string" and Core.db[key] == module.db)
end
check("each section has its defaults the moment it registers",
    Core.db.frames.barWidth == 150 and Core.db.castbar.barWidth == 130
    and Core.db.chat.showButton == true and Core.db.menus.quietMicroMenu == true)
-- Everything the addon draws is always on: no switch for any part of it.
check("no Enabled switch in any section, nor the always-on ones",
    Core.db.frames.enabled == nil and Core.db.castbar.enabled == nil and Core.db.fsr.enabled == nil
    and Core.db.combo.enabled == nil and Core.db.xp.enabled == nil and Core.db.cooldowns.enabled == nil
    and Core.db.frames.showLevel == nil and Core.db.frames.showHealPrediction == nil
    and Core.db.frames.styleNamePlates == nil and Core.db.castbar.showText == nil
    and Core.db.castbar.showSwing == nil and Core.db.castbar.failedHold == nil
    and Core.db.xp.showRested == nil)

check("the settings are per character; only the profiles and flight times are the account's",
    TOC_TEXT:find("\n## SavedVariablesPerCharacter: DogsForeverUIDB%s") ~= nil
    and TOC_TEXT:find("\n## SavedVariables: DogsForeverUIProfiles, DogsForeverUIFlights%s") ~= nil
    and select(2, TOC_TEXT:gsub("\n## SavedVariables", "")) == 2)

Login()
check("after login the saved name is the live table", DogsForeverUIDB == Core.db)
check("with a section per module and nothing else", (function()
    local count = 0
    for key in pairs(DogsForeverUIDB) do
        count = count + 1
        if not Core:GetModule(key) then return false end
    end
    return count == #EXPECTED
end)())
check("every movable bar has a first position",
    Core.db.frames.playerLeft ~= nil and Core.db.castbar.barLeft ~= nil)
check("placed by the addon, so a new resolution may move it",
    Core.db.castbar.autoPlaced == true)
check("the countdown placed once, over the castbar, its spot written for the boxes",
    Core.db.fsr.placed == true and Core.db.fsr.barLeft ~= nil)
check("the castbar group's bars each sized on their own, from the castbar's to start",
    Core.db.fsr.barWidth == 130 and Core.db.combo.barHeight == 20 and Core.db.castbar.swingWidth == 130
    and Core.db.fsr.sized == true and Core.db.castbar.swingSized == true)
check("no colour settings in any section", (function()
    for _, section in pairs(Core.db) do
        for key in pairs(section) do
            if key:lower():find("colou?r") and key ~= "classColors" then return false end
        end
    end
    return true
end)())

Section("the five addons that became one")
check("the old addons' globals are gone",
    DogsFramesForever == nil and DogsCastbarForever == nil
    and DogsFiveSecondRuleForever == nil and DogsChatForever == nil
    and DogsMenusForever == nil)
check("and so are their saved tables",
    DogsFramesForeverDB == nil and DogsCastbarForeverDB == nil
    and DogsFSRForeverDB == nil and FSRForeverDB == nil)
-- Everything is in the options panel; there is no command of any kind.
do
    local commands = {}
    for name in pairs(SlashCmdList) do commands[#commands + 1] = name end
    for name in pairs(_G) do
        if type(name) == "string" and name:find("^SLASH_") then commands[#commands + 1] = name end
    end
    check("there are no slash commands at all", #commands == 0, table.concat(commands, ", "))
end

Section("saved settings that arrive late")
Reload(nil)
Fire("ADDON_LOADED", "DogsForeverUI")
check("the addon starts on defaults when there is no file",
    DogsForeverUI.db.frames.barWidth == 150)

DogsForeverUIDB = {
    frames = { barWidth = 240, showHealthText = false, showName = false, showLevel = false, enabled = false,
               playerLeft = 400, playerTop = -300,
               playerPlaced = true, holdTime = 1.5, healthColor = { 0, 1, 0, 1 } },
    castbar = { barWidth = 150, failedHold = 1.2, statusBarBackgroundColor = { 0, 0, 0, 0.55 } },
    fsr = { enabled = false, barWidth = 90, statusBarColor = { 0.6, 0.6, 0.6 } },
    retired = { something = true },
}
Fire("PLAYER_LOGIN")
local db = DogsForeverUI.db
check("a file that arrives late is still read",
    db.frames.barWidth == 240 and db.castbar.barWidth == 150 and db.frames.showHealthText == false)
check("a switch a player once turned off is gone: everything is on now",
    db.frames.enabled == nil and db.frames.showLevel == nil and db.fsr.enabled == nil
    and db.castbar.failedHold == nil and db.frames.showName == nil)
check("into the same section tables, so every reference handed out still works",
    DogsForeverUI.Frames.db == db.frames and DogsForeverUI.Castbar.db == db.castbar)
check("settings it did not have are filled in from the defaults",
    db.frames.powerHeight == 10 and db.chat.showButton == true)
check("a setting an older version wrote is dropped",
    db.frames.holdTime == nil and db.frames.healthColor == nil
    and db.castbar.statusBarBackgroundColor == nil and db.fsr.statusBarColor == nil)
check("a file from before the group's bars were sized on their own: each takes the castbar's, once",
    db.fsr.barWidth == 150 and db.fsr.sized == true and db.castbar.swingWidth == 150)
check("a section for a module this version does not have is dropped", db.retired == nil)
check("and a hand-placed position is left where it was",
    db.frames.playerLeft == 400 and db.frames.playerPlaced == true)
check("placement mode is never restored", db.castbar.unlocked == false)

local live = DogsForeverUIDB
Fire("PLAYER_ENTERING_WORLD")
check("a later zone change does not overwrite the live settings",
    DogsForeverUIDB == live and db.frames.barWidth == 240)

Section("the file is written at ADDONS_UNLOADING")
DogsForeverUIDB = { frames = { barWidth = 999 } }
Fire("ADDONS_UNLOADING")
check("the live settings are put back for the game to write",
    DogsForeverUIDB == live and DogsForeverUIDB.frames.barWidth == 240)

-- The one case where taking the name back would lose data: a table the addon
-- never managed to read is still sitting there.
Reload(nil)
local untouched = { frames = { barWidth = 777 } }
DogsForeverUIDB = untouched
Fire("ADDONS_UNLOADING")
check("a file that was never read is left exactly where it was",
    DogsForeverUIDB == untouched and DogsForeverUIDB.frames.barWidth == 777)

Section("reset")
Reload({ castbar = { barWidth = 250, textPadding = 0.3 }, frames = { barWidth = 300 } })
Login()
local castbar = DogsForeverUI.Castbar
local section = castbar.db
DogsForeverUI:Reset("castbar")
check("a reset puts that module's defaults back",
    section.barWidth == 130 and section.textPadding == 0.15)
check("in the same table", castbar.db == section and DogsForeverUI.db.castbar == section)
check("and leaves the other modules alone", DogsForeverUI.db.frames.barWidth == 300)
check("and places the bar again", section.barLeft ~= nil and section.autoPlaced == true)

Section("profiles: saved by one character")
Reload({ castbar = { barWidth = 250, barLeft = 500, barTop = -600, autoPlaced = false },
         frames = { barWidth = 300, showHealthText = false },
         cooldowns = { tracked = { { kind = "spell", id = 100 } } } })
DogsForeverUIProfiles = nil
Login()
local Profiles = DogsForeverUI.Profiles
check("no profiles to start, and the account's table is the live one",
    #Profiles.Names() == 0 and DogsForeverUIProfiles == Profiles.saved)
local ok, message = Profiles.Save("   ")
check("a profile needs a name", not ok and message == "Type a name for the profile.", message)
ok, message = Profiles.Save(string.rep("x", Profiles.MAX_NAME + 1))
check("of at most " .. Profiles.MAX_NAME .. " letters", not ok)
ok, message = Profiles.Save("  Main  ")
check("saved, the name trimmed", ok and message == "Profile Main saved." and Profiles.Exists("Main"), message)
local main = Profiles.saved.Main
check("with every module's settings",
    main.castbar.barWidth == 250 and main.castbar.barLeft == 500 and main.frames.showHealthText == false
    and main.fsr ~= nil and main.menus ~= nil)
check("a copy, not the live sections", main.castbar ~= DogsForeverUI.db.castbar
    and main.cooldowns.growDirection ~= nil and main.cooldowns ~= DogsForeverUI.db.cooldowns)
check("without the cooldown list: that is the character's own", main.cooldowns.tracked == nil)
check("and without placement mode", main.castbar.unlocked == nil)
DogsForeverUI.db.castbar.barWidth = 260
ok, message = Profiles.Save("Main")
check("saving under the same name updates it",
    ok and message == "Profile Main updated." and Profiles.saved.Main.castbar.barWidth == 260, message)
Profiles.Save("alt layout")
check("listed by name, whatever the case", table.concat(Profiles.Names(), ",") == "alt layout,Main")

-- The game writes the account's table at unload, like the character's.
Fire("ADDONS_UNLOADING")
local file = DogsForeverUIProfiles
check("the profiles are handed to the game to write", file == Profiles.saved and file.Main ~= nil)

Section("profiles: loaded by another character")
Reload({ castbar = { barWidth = 111 }, frames = { barWidth = 180, showHealthText = true },
         cooldowns = { tracked = { { kind = "item", id = 6948 } } } })
DogsForeverUIProfiles = file
Login()
Profiles = DogsForeverUI.Profiles
check("the other character sees the account's profiles",
    table.concat(Profiles.Names(), ",") == "alt layout,Main")
local castbarSection = DogsForeverUI.db.castbar
ok, message = Profiles.Load("Main")
check("loading takes the profile's settings", ok and message == "Profile Main loaded."
    and DogsForeverUI.db.castbar.barWidth == 260 and DogsForeverUI.db.castbar.barLeft == 500
    and DogsForeverUI.db.frames.barWidth == 300 and DogsForeverUI.db.frames.showHealthText == false, message)
check("into the same section tables", DogsForeverUI.Castbar.db == castbarSection
    and DogsForeverUI.db.castbar == castbarSection)
check("keeping this character's cooldown list",
    #DogsForeverUI.db.cooldowns.tracked == 1 and DogsForeverUI.db.cooldowns.tracked[1].id == 6948)
check("and placed where the profile has it, not by the addon",
    DogsForeverUI.db.castbar.autoPlaced == false)
DogsForeverUI.db.castbar.barWidth = 199
check("after that the profile is its own: a change here does not reach it",
    Profiles.saved.Main.castbar.barWidth == 260)
ok, message = Profiles.Load("Nope")
check("a name no profile has is refused", not ok and message == "No profile is called Nope.", message)
inCombat = true
ok, message = Profiles.Load("Main")
check("nothing loads in combat", not ok and message == "Profiles cannot be loaded in combat."
    and DogsForeverUI.db.castbar.barWidth == 199, message)
inCombat = false
DogsForeverUI.SetUnlocked(true)
Profiles.Load("Main")
check("loading while unlocked locks the UI", not DogsForeverUI.IsUnlocked())

-- A profile from an older version: settings it lacks come from the defaults,
-- and ones this version dropped are dropped.
Profiles.saved.Old = { castbar = { barWidth = 140, retired = true }, gone = { x = 1 } }
Profiles.Load("Old")
check("an older profile: what it lacks from the defaults, what is retired dropped",
    DogsForeverUI.db.castbar.barWidth == 140 and DogsForeverUI.db.castbar.retired == nil
    and DogsForeverUI.db.frames.barWidth == 150 and DogsForeverUI.db.gone == nil)

ok, message = Profiles.Delete("Old")
check("deleted", ok and message == "Profile Old deleted." and not Profiles.Exists("Old"), message)
ok = Profiles.Delete("Old")
check("only once", not ok)

Section("profiles: a file that arrives late")
Reload(nil)
DogsForeverUIProfiles = nil
Fire("ADDON_LOADED", "DogsForeverUI")
Profiles = DogsForeverUI.Profiles
Profiles.Save("Early")
DogsForeverUIProfiles = { Late = { castbar = { barWidth = 170 } } }
Fire("PLAYER_ENTERING_WORLD")
check("is still read, and a profile saved before it came is kept beside it",
    Profiles.Exists("Late") and Profiles.Exists("Early") and DogsForeverUIProfiles == Profiles.saved)

Reload(nil)
local untouchedProfiles = { Theirs = { frames = { barWidth = 1 } } }
DogsForeverUIProfiles = untouchedProfiles
Fire("ADDONS_UNLOADING")
check("a profiles file that was never read is left where it was",
    DogsForeverUIProfiles == untouchedProfiles)

Summary()
