-- THE GAME'S OWN SETTINGS THE ADDON WANTS ON (the player, 2026-10-03: "when
-- our addon is installed: action bars 2-3-4-5 should be active in blizz
-- settings by default!!! plates should be enabled and default plate style
-- should be 'Large' and 'class colored names' should be active! damage meter
-- and auto reset damage meter should be enabled by default!!!"):
--
--   * Action Bars 2, 3, 4 and 5 on (Options > Action Bars);
--   * nameplates on - enemy plates, and always shown (Options > Nameplates:
--     Enemy Units, Always Show Nameplates) - in the Large style (Camelot's
--     name for Enum.NamePlateStyle.Modern, Camelot\NameplatesOverrides.lua),
--     friendly players' names and bars in class colours;
--   * the damage meter on, and reset on entering a new instance (Options >
--     Advanced: Enable Damage Meter, Auto Reset Damage Meter);
--   * Show Numbers for Cooldowns on (Options > Action Bars).
--
-- ONCE per character, in steps (`done` counts them: a step added later still
-- reaches a character that had the earlier ones). Changed in the game's
-- options afterwards, they stay changed; Reset everything puts the count
-- back and so sets them all again. Only once the saved settings can be
-- trusted (Core.SettingsTrusted - or `done` reads "not yet" on every
-- reload), out of combat.
--
-- AND CHECKED: some of these are kept by the server, which can hand the old
-- values back a moment after the addon wrote them (the bars and nameplates
-- were set by earlier versions and still came up off). So for half a minute
-- after a step, whatever it wrote is read back a few times and written again
-- if it is not what was written. After that, whatever the player sets is
-- theirs.
--
-- Written with the client's own SetCVar and SetActionBarToggles - never the
-- game's Settings or CVarCallbackRegistry helpers, whose state the addon's
-- call would taint.

local GameDefaults = {
    key = "gamedefaults",
    title = "Game settings",
    -- installed: the first-start question answered (Options\Install.lua) -
    -- kept through Reset everything, never carried by a profile.
    defaults = { done = 0, installed = false },
    keep = { installed = true },
}
DogsForeverUI.GameDefaults = GameDefaults

do -- private scope
    local Core = DogsForeverUI

    local function ReadCVar(name)
        local ok, value = pcall(C_CVar.GetCVar, name)
        return ok and value or nil
    end

    -- The same setting: equal as written, or as numbers (the client gives
    -- "2.000000" back for "2").
    local function Same(a, b)
        if a == b then return true end
        local x, y = tonumber(a), tonumber(b)
        return x ~= nil and y ~= nil and math.abs(x - y) < 1e-6
    end
    GameDefaults.Same = Same

    local function WriteCVar(name, value)
        return pcall(C_CVar.SetCVar, name, value)
    end

    -- Step 1's settings, worked out when it runs (the enum is the client's).
    local function FirstSettings()
        local wanted = {
            { "nameplateShowEnemies", "1" },
            { "nameplateShowAll", "1" },
            { "nameplateShowFriendlyClassColor", "1" },
            { "nameplateUseClassColorForFriendlyPlayerUnitNames", "1" },
            { "damageMeterEnabled", "1" },
            { "damageMeterResetOnNewInstance", "1" },
        }
        local large = type(Enum) == "table" and Enum.NamePlateStyle and Enum.NamePlateStyle.Modern
        if large then wanted[#wanted + 1] = { "nameplateStyle", tostring(large) } end
        return wanted
    end

    -- Step 2 (the player, 2026-10-03: "enemy and friendly nameplates should
    -- be enabled ... autoloot, combine bags, enable interact key should be
    -- enabled ... cooldown manager should be disabled ... camera following
    -- style should be 'never adjust camera' ... max camera settings should
    -- be 2"): Friendly Player Nameplates on (enemy ones were already); Auto
    -- Loot; Use Combined Inventory Bags; Enable Interact Key (soft
    -- interact on for any input, Controls.lua's value - Enum.SoftTargetEnableFlags.Any);
    -- the Cooldown Manager off (shown from the next load); Camera Following
    -- Style Never Adjust Camera (0); Max Camera Distance 2 (the slider's top,
    -- Camelot\ControlsOverrides.lua).
    local function SecondSettings()
        local wanted = {
            { "nameplateShowEnemies", "1" },
            { "nameplateShowFriendlyPlayers", "1" },
            { "autoLootDefault", "1" },
            { "combinedBags", "1" },
            { "cooldownViewerEnabled", "0" },
            { "cameraSmoothStyle", "0" },
            { "cameraDistanceMaxZoomFactor", "2" },
        }
        local flags = type(Enum) == "table" and Enum.SoftTargetEnableFlags
        local any = flags and flags.Any
        if any then wanted[#wanted + 1] = { "softTargetInteract", tostring(any) } end
        return wanted
    end

    -- Step 3 (the player, 2026-10-06: "Action bars should respect Blizzard
    -- 'Show Numbers for Cooldown' setting (and it should be default)"):
    -- Show Numbers for Cooldowns on (Options > Action Bars). The addon's
    -- bars follow it (ActionBars\Paint.lua).
    local function ThirdSettings()
        return { { "countdownForCooldowns", "1" } }
    end

    -- Each step: the CVars it sets, and whether it switches the bars on.
    local STEPS = {
        { cvars = FirstSettings, bars = true },
        { cvars = SecondSettings },
        { cvars = ThirdSettings },
    }
    GameDefaults.STEPS = STEPS

    ---------------------------------------------------------------------------
    -- Checked after writing: at these many seconds after a step ran.
    ---------------------------------------------------------------------------

    GameDefaults.CHECKS = { 3, 10, 30 }
    local watched = {}          -- CVar -> the value written
    local watchBars = false
    local since, nextCheck

    local checker = CreateFrame("Frame")
    checker:Hide()

    local function Check()
        if InCombatLockdown() then return end
        for name, value in pairs(watched) do
            if not Same(ReadCVar(name), value) then WriteCVar(name, value) end
        end
        local bars = Core.ActionBars
        if watchBars and bars and bars.GameBarsAllOn and not bars.GameBarsAllOn() then
            bars.SwitchGameBarsOn()
        end
    end
    GameDefaults.Check = Check

    checker:SetScript("OnUpdate", function(self, elapsed)
        since = since + (elapsed or 0)
        local at = GameDefaults.CHECKS[nextCheck]
        if not at then
            self:Hide()
            for name in pairs(watched) do watched[name] = nil end
            watchBars = false
            return
        end
        if since >= at then
            nextCheck = nextCheck + 1
            Check()
        end
    end)

    local function Watch()
        since, nextCheck = 0, 1
        checker:Show()
    end

    function GameDefaults.Watching() return checker:IsShown() end

    ---------------------------------------------------------------------------
    -- The steps not yet done, now. Answers whether nothing is left to do.
    ---------------------------------------------------------------------------

    function GameDefaults.Apply()
        local db = GameDefaults.db
        if type(db) ~= "table" then return true end
        local done = tonumber(db.done) or 0
        if done >= #STEPS then return true end
        if not Core.SettingsTrusted() or InCombatLockdown() then return false end
        for index = done + 1, #STEPS do
            local step = STEPS[index]
            local ok, err = pcall(function()
                for _, setting in ipairs(step.cvars and step.cvars() or {}) do
                    local name, value = setting[1], setting[2]
                    -- (A setting this client does not have is left alone.)
                    local now = ReadCVar(name)
                    if now ~= nil then
                        watched[name] = value
                        if not Same(now, value) then WriteCVar(name, value) end
                    end
                end
                local bars = Core.ActionBars
                if step.bars and bars and bars.SwitchGameBarsOn then
                    watchBars = true
                    bars.SwitchGameBarsOn()
                end
            end)
            if not ok and geterrorhandler then geterrorhandler()(err) end
            db.done = index
        end
        Watch()
        return true
    end

    -- Tried until done: as the world comes up, as a fight ends, after a
    -- reset - and each half second until the settings can be trusted.
    GameDefaults.Try = Core.Retry(GameDefaults.Apply)

    function GameDefaults.Normalise(db)
        db.done = math.max(0, math.floor(tonumber(db.done) or 0))
        db.installed = db.installed == true
    end

    -- First start, and Reset everything (`done` back to 0).
    function GameDefaults.Init()
        if Core.SettingsTrusted() then GameDefaults.Try() end
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function() GameDefaults.Try() end)

    Core:RegisterModule(GameDefaults)
end
