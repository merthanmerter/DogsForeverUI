-- NAMESPACE: DogsForeverUI
-- SETTINGS:  DogsForeverUIDB
--
-- One addon, five parts, one look:
--
--   Frames          the player, target, focus and target-of-target as plain
--                   double bars                                  (Frames\)
--   Castbar         a casting bar and auto-attack swing bars     (Castbar\)
--   Five Second     the countdown after mana is spent            (FiveSecondRule\)
--   Chat            a window to select and copy chat from        (Chat\)
--   Menus           a quieter micro menu and bag bar             (Menus\)
--
-- They were five addons once. Each part is a module here: it registers itself
-- with this file, keeps its settings in its own section of the one saved table,
-- and draws with the shared look in Core\Style.lua. The options are one panel
-- with a tab per module (Options\).
--
-- This file owns the saved settings and nothing else. Every module gets a
-- section table that is created here once and never replaced, so a reference a
-- module or the options panel holds stays good for the whole session.

DogsForeverUI = CreateFrame("Frame")

do -- private scope
    local Core = DogsForeverUI
    local ADDON_NAME = ...

    Core.ADDON_NAME = ADDON_NAME
    Core.TITLE = "Dog's Forever UI"
    Core.MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

    -- The modules in the order they registered, which is the .toc's order and
    -- the order of the tabs.
    Core.modules = {}

    -- The live settings: { [module key] = section }. `DogsForeverUIDB` is
    -- pointed at this table, so the game writes the live settings to disk and
    -- there is nothing to keep in sync.
    Core.db = {}

    function Core.Print(message)
        print(Core.TITLE .. " - " .. message)
    end

    -- The options panel replaces this once it is built; until then a setting
    -- changed from a drag has no panel to show it on.
    function Core.RefreshOptions() end

    -- A right-click on a bar that is being placed locks its module again, so
    -- placing things does not end with a trip back to the options. Called from
    -- each bar's mouse-up; answers whether it was that click.
    --
    -- The lock waits for the next frame. The unit plates' click surface is a
    -- secure button whose right-click opens the unit menu, and locking gives
    -- that action back: done inside the click, the same click would go on to
    -- open the menu. Every bar waits the same way, so they all behave alike.
    function Core.RightClickLock(module, button)
        if button ~= "RightButton" or not (module.db and module.db.unlocked) then
            return false
        end
        C_Timer.After(0, function()
            if module.db.unlocked then
                module.Lock()
                Core.RefreshOptions()
            end
        end)
        return true
    end

    local adopted = false   -- the saved file has been read into Core.db
    local settled = false   -- ... and the modules have been redrawn from it

    -- Settings hold nested tables, so a copy of the defaults has to be a deep
    -- one or every section would share the same arrays.
    local function DeepCopy(value)
        if type(value) ~= "table" then return value end
        local copy = {}
        for key, inner in pairs(value) do copy[key] = DeepCopy(inner) end
        return copy
    end

    -- Edit Mode's two opt-outs on a game frame this addon takes over: `isLocked`
    -- (EditModeSystemMixin:CanBeMoved) so it cannot be dragged unseen, and
    -- `defaultHideSelection` so it is not highlighted. Plain fields the game
    -- keeps for exactly this - no Edit Mode setting is written. What the frame
    -- had is kept in `saved` and put back when `held` is false.
    function Core.HoldEditMode(saved, frame, held)
        local was = saved[frame]
        if was == nil then
            was = { locked = frame.isLocked, hidden = frame.defaultHideSelection }
            saved[frame] = was
        end
        if held then
            frame.isLocked = true
            frame.defaultHideSelection = true
        else
            frame.isLocked = was.locked
            frame.defaultHideSelection = was.hidden
        end
    end

    local function Wipe(tbl)
        for key in pairs(tbl) do tbl[key] = nil end
    end

    -- Bring one section into line with its module: every default present,
    -- anything that is neither a default nor a placement key dropped (a setting
    -- an older version wrote and this one no longer has), placement mode off -
    -- logging in to unlocked bars is not what anybody wants - and then whatever
    -- the module itself needs, such as a first position.
    local function Normalise(module)
        local db = module.db
        local defaults = module.defaults or {}
        local placement = module.placement or {}

        for key, value in pairs(defaults) do
            if db[key] == nil then db[key] = DeepCopy(value) end
        end
        for key in pairs(db) do
            if defaults[key] == nil and not placement[key] then db[key] = nil end
        end
        if db.unlocked ~= nil then db.unlocked = false end

        if module.Normalise then module.Normalise(db) end
    end

    -- module = {
    --   key        the section's name in the saved table
    --   title      the tab's label
    --   defaults   the settings and their values
    --   placement  saved keys that are positions rather than settings
    --   Normalise  (db) whatever else a section needs once loaded
    --   Init       ()   first start, and after a reset
    --   Refresh    ()   redraw from the settings
    -- }
    function Core:RegisterModule(module)
        local db = self.db[module.key]
        if not db then
            db = {}
            self.db[module.key] = db
        end
        module.db = db
        self.modules[#self.modules + 1] = module

        -- Defaults only, so the section is usable at once. The rest of
        -- Normalise waits for ADDON_LOADED, when every file of the module - and
        -- whatever its own Normalise calls - has loaded.
        for key, value in pairs(module.defaults or {}) do
            if db[key] == nil then db[key] = DeepCopy(value) end
        end
        return db
    end

    function Core:GetModule(key)
        for _, module in ipairs(self.modules) do
            if module.key == key then return module end
        end
    end

    -- SAVED VARIABLES
    --
    -- This client does not reliably have the saved table in place by the time
    -- ADDON_LOADED fires, so the live table is filled from defaults at once and
    -- the file's contents are copied into it whenever they turn up. Two rules
    -- keep that safe, and breaking either silently destroys the player's
    -- settings:
    --
    --   * Keep looking until something is adopted. A file that arrives after the
    --     world is up must still be read, or the addon runs on defaults and
    --     writes *those* over the player's file at logout.
    --   * Never overwrite a file that was not understood. If the game still
    --     holds a table of its own at unload time and nothing was ever adopted
    --     from it, leave it exactly where it is.
    local function LoadSettings()
        local saved = DogsForeverUIDB
        if type(saved) ~= "table" or next(saved) == nil then saved = nil end

        if saved and saved ~= Core.db and not adopted then
            for _, module in ipairs(Core.modules) do
                local from = saved[module.key]
                if type(from) == "table" then
                    Wipe(module.db)
                    for key, value in pairs(from) do module.db[key] = value end
                end
            end
            adopted = true
        end

        DogsForeverUIDB = Core.db

        -- A section for a module this version does not have is dropped.
        for key in pairs(Core.db) do
            if not Core:GetModule(key) then Core.db[key] = nil end
        end

        for _, module in ipairs(Core.modules) do Normalise(module) end
    end

    -- ADDONS_UNLOADING: the game is about to write the file, on /reload, on
    -- logout and on quit. Blizzard's own saved-variable UI does exactly this -
    -- see SaveVariables in Blizzard_EventTrace - rather than trusting the global
    -- to still be pointing at the live table after a whole session.
    local function SaveSettings()
        local saved = DogsForeverUIDB
        if not adopted and type(saved) == "table" and saved ~= Core.db
           and next(saved) ~= nil then
            return
        end
        DogsForeverUIDB = Core.db
    end

    local function Each(method)
        for _, module in ipairs(Core.modules) do
            if module[method] then module[method]() end
        end
    end

    -- Back to defaults, for one module. The section is emptied and refilled
    -- rather than replaced, so every reference already handed out is still
    -- looking at the settings in use.
    function Core:Reset(key)
        local module = self:GetModule(key)
        if not module then return end

        Wipe(module.db)
        for name, value in pairs(module.defaults or {}) do
            module.db[name] = DeepCopy(value)
        end
        Normalise(module)
        if module.Init then module.Init() end
    end

    Core:RegisterEvent("ADDON_LOADED")
    Core:RegisterEvent("VARIABLES_LOADED")
    Core:RegisterEvent("PLAYER_LOGIN")
    Core:RegisterEvent("PLAYER_ENTERING_WORLD")
    Core:RegisterEvent("ADDONS_UNLOADING")

    Core:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" then
            if arg1 == ADDON_NAME then
                LoadSettings()
                Each("Init")
            end
            return
        end

        if event == "ADDONS_UNLOADING" then
            SaveSettings()
            return
        end

        -- Deliberately no giving up: a table that arrives even one event late
        -- must still be read.
        if not settled then
            LoadSettings()
            if adopted then
                Each("Refresh")
                settled = true
            end
        end
    end)
end
