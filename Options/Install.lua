-- THE FIRST START'S QUESTION (the player, 2026-10-03: "when the addon loaded
-- for the first time we should add an 'install' / 'cancel' popup that would
-- reset everything to default and set what our UI provides"):
--
--   +---------------------------------------------+
--   |              Dog's Forever UI               |
--   |  Set up Dog's Forever UI? ...               |
--   |       [ Disable Addon ]   [ Install ]       |
--   +---------------------------------------------+
--
-- Install: every setting of the addon back to its default (Reset
-- everything), the game's own settings the UI is built round set again
-- (Core\GameDefaults.lua, all its steps - checked again after the load),
-- and the UI reloaded, so everything starts from them. Disable Addon: the
-- addon off for this character, the UI reloaded (no Cancel - the player,
-- 2026-10-03). Asked once per character (the addon's settings are the
-- character's), as the world comes up, out of combat; Install is kept
-- (gamedefaults.installed, untouched by Reset everything).
--
-- Not the game's "/console cvar_default": that would throw away every one
-- of the game's settings - graphics, sound, everything - not only the ones
-- the UI is built round.

local Install = {}
DogsForeverUI.Options.Install = Install

do -- private scope
    local Core = DogsForeverUI
    local Unlock = Core.Options.Unlock
    local W = Core.Widgets

    local WIDTH, HEIGHT = 380, 150
    Install.DELAY = 1          -- after the world is up (the action bars place themselves first)

    local window

    local function Settings() return Core.GameDefaults and Core.GameDefaults.db end

    function Install.Asked()
        local db = Settings()
        return db == nil or db.installed == true
    end

    local function Answered()
        local db = Settings()
        if db then db.installed = true end
        if window then window:Hide() end
    end

    function Install.Install()
        if InCombatLockdown() then return false end
        if not Core:ResetAll() then return false end
        Answered()
        -- Every one of the game's settings set again once the UI is back,
        -- and checked after (the reset set them now; a reload ends the
        -- checking).
        local db = Settings()
        if db then db.done = 0 end
        if type(ReloadUI) == "function" then ReloadUI() end
        return true
    end

    -- DISABLE ADDON (the player, 2026-10-03: "no 'cancel' button ... its
    -- either 'Install' or 'Disable Addon'"): the addon turned off for this
    -- character in the game's addon list, and the UI reloaded without it.
    -- Not marked answered: turned on again later, it asks again.
    function Install.Disable()
        if InCombatLockdown() then return false end
        local addons = type(C_AddOns) == "table" and C_AddOns
        local disable = addons and addons.DisableAddOn
        if type(disable) ~= "function" then return false end
        local name = UnitName and UnitName("player")
        if type(name) == "string" and name ~= "" and not (issecretvalue and issecretvalue(name)) then
            disable(Core.ADDON_NAME, name)
        else
            disable(Core.ADDON_NAME)
        end
        if addons and type(addons.SaveAddOns) == "function" then addons.SaveAddOns() end
        if window then window:Hide() end
        if type(ReloadUI) == "function" then ReloadUI() end
        return true
    end

    local function Build()
        if window then return end
        window = Unlock.NewWindow("Install", WIDTH, HEIGHT, "FULLSCREEN_DIALOG")
        window:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        Install.window = window
        window.title = W.Text(window, 16, W.GOLD, true)
        window.title:SetPoint("TOP", window, "TOP", 0, -18)
        window.title:SetText(Core.TITLE or "Dog's Forever UI")
        window.text = W.Text(window, 12, W.TEXT, false, WIDTH - 40)
        window.text:SetPoint("TOP", window.title, "BOTTOM", 0, -12)
        window.text:SetJustifyH("CENTER")
        window.text:SetText("Set up Dog's Forever UI? Every setting of the addon goes back to its default, "
            .. "the game's settings it is built around are set, and the UI reloads.")
        window.install = W.Button(window, "Install", 120, function() Install.Install() end, "active")
        window.install:SetPoint("BOTTOMLEFT", window, "BOTTOM", 4, 16)
        window.disable = W.Button(window, "Disable Addon", 120, function() Install.Disable() end)
        window.disable:SetPoint("BOTTOMRIGHT", window, "BOTTOM", -4, 16)
    end

    -- Asked now, if it is still to be asked and can be.
    function Install.Ask()
        if Install.Asked() or InCombatLockdown() or not Core.SettingsTrusted() then return false end
        Build()
        window:Show()
        return true
    end

    -- Tried until it can be: the saved settings in (or no file to wait for),
    -- out of combat.
    local waiter = CreateFrame("Frame")
    waiter:Hide()
    local since = 0
    waiter:SetScript("OnUpdate", function(self, elapsed)
        since = since + (elapsed or 0)
        if since < Install.DELAY then return end
        since = Install.DELAY - 0.5
        if Install.Asked() or Install.Ask() then self:Hide() end
    end)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            -- (A fight: put away, asked again after.)
            if window and window:IsShown() then
                window:Hide()
                since = 0
                waiter:Show()
            end
            return
        end
        if not Install.Asked() then
            since = 0
            waiter:Show()
        end
    end)
end
