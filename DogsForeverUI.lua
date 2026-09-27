-- NAMESPACE: DogsForeverUI
-- SETTINGS:  DogsForeverUIDB
--
-- One addon, many parts, one look:
--
--   Frames          the player, target, focus, target-of-target and pet as
--                   plain double bars                            (Frames\)
--   Castbar         a casting bar and auto-attack swing bars     (Castbar\)
--   Five Second     the countdown after mana is spent            (FiveSecondRule\)
--   Combo points    a bar of segments above the castbar          (ComboPoints\)
--   XP bar          the addon's own experience bar               (XPBar\)
--   Loot rolls      where the game's loot roll windows appear    (LootRolls\)
--   Cooldowns       bars for the spells and items the player
--                   adds by ID, and IDs on tooltips             (Cooldowns\)
--   Chat            a window to select and copy chat from        (Chat\)
--   Menus           a quieter micro menu, auto-hiding bars       (Menus\)
--
-- and, with no settings of their own, the breath bar (MirrorTimers\) and
-- fishing with a double right-click (Fishing\).
--
-- They were five addons once. Each part with settings is a module here: it
-- registers itself with this file, keeps its settings in its own section of
-- the one saved table, and draws with the shared look in Core\Style.lua. The
-- options are one page with a section per part, and a tab for the cooldown
-- manager (Options\).
--
-- This file owns the saved settings, and the two things that are every
-- module's at once: placing the UI (one unlock for everything, with a grid)
-- and resetting it. Every module gets a section table that is created here
-- once and never replaced, so a reference a module or the options panel holds
-- stays good for the whole session.

DogsForeverUI = CreateFrame("Frame")

do -- private scope
    local Core = DogsForeverUI
    local ADDON_NAME = ...

    Core.ADDON_NAME = ADDON_NAME
    Core.TITLE = "Dog's Forever UI"
    Core.MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

    -- The modules in the order they registered, which is the .toc's order.
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

    ---------------------------------------------------------------------------
    -- PLACING THE UI: ONE LOCK FOR EVERYTHING
    --
    -- Every module that can be moved (it has Lock and Unlock) is unlocked and
    -- locked together, from the one button at the top of the options - the
    -- player asked for one global unlock, not one per piece. While unlocked, a
    -- grid covers the screen to line things up against.
    --
    -- Unlocking waits for the end of combat: the frames' click surfaces are
    -- secure, and placing them rewrites secure attributes, which the game
    -- refuses in combat. Locking locks whatever the game allows at once.
    ---------------------------------------------------------------------------

    local function Movable()
        local list = {}
        for _, module in ipairs(Core.modules) do
            if module.Lock and module.Unlock and module.db then list[#list + 1] = module end
        end
        return list
    end

    function Core.IsUnlocked()
        for _, module in ipairs(Movable()) do
            if module.db.unlocked then return true end
        end
        return false
    end

    local UpdateGrid   -- below

    -- Answers whether it happened.
    function Core.SetUnlocked(unlocked)
        if unlocked and InCombatLockdown() then
            Core.Print("the UI cannot be unlocked in combat.")
            return false
        end
        for _, module in ipairs(Movable()) do
            if (module.db.unlocked and true or false) ~= unlocked then
                if unlocked then module.Unlock() else module.Lock() end
            end
        end
        UpdateGrid()
        Core.RefreshOptions()
        return true
    end

    function Core.ToggleUnlocked()
        return Core.SetUnlocked(not Core.IsUnlocked())
    end

    -- A right-click on anything being placed locks the whole UI again, so
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
            if Core.IsUnlocked() then Core.SetUnlocked(false) end
        end)
        return true
    end

    -- THE GRID. Lines every GRID_STEP UI units out from the middle of the
    -- screen both ways, so the centre lines are exact; those two in the
    -- border's gold, the rest faint white. Each line one real pixel thick.
    -- Under all the UI, over the world, and never in the mouse's way.
    local GRID_STEP = 32
    local GRID_LINE = { 1, 1, 1, 0.12 }
    local GRID_CENTRE_ALPHA = 0.8
    local grid

    local function LayOutGrid()
        local width, height = UIParent:GetWidth(), UIParent:GetHeight()
        local scale = UIParent:GetEffectiveScale()
        local thick = 1
        if PixelUtil and PixelUtil.GetNearestPixelSize then
            thick = PixelUtil.GetNearestPixelSize(1, scale, 1)
        end
        local gold = Core.Style.BORDER_COLOR

        local used = 0
        local function Line(vertical, offset)
            used = used + 1
            local line = grid.lines[used]
            if not line then
                line = grid:CreateTexture(nil, "BACKGROUND")
                grid.lines[used] = line
            end
            line:ClearAllPoints()
            if vertical then
                line:SetPoint("TOP", grid, "TOP", offset, 0)
                line:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
                line:SetWidth(thick)
            else
                line:SetPoint("LEFT", grid, "LEFT", 0, offset)
                line:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
                line:SetHeight(thick)
            end
            if offset == 0 then
                line:SetColorTexture(gold[1], gold[2], gold[3], GRID_CENTRE_ALPHA)
            else
                line:SetColorTexture(GRID_LINE[1], GRID_LINE[2], GRID_LINE[3], GRID_LINE[4])
            end
            line:Show()
        end

        for step = 0, math.floor(width / 2 / GRID_STEP) do
            Line(true, step * GRID_STEP)
            if step > 0 then Line(true, -step * GRID_STEP) end
        end
        for step = 0, math.floor(height / 2 / GRID_STEP) do
            Line(false, step * GRID_STEP)
            if step > 0 then Line(false, -step * GRID_STEP) end
        end
        for spare = used + 1, #grid.lines do grid.lines[spare]:Hide() end
    end

    function UpdateGrid()
        local shown = Core.IsUnlocked()
        if shown and not grid then
            grid = CreateFrame("Frame", Core.ADDON_NAME .. "Grid", UIParent)
            grid:SetAllPoints(UIParent)
            grid:SetFrameStrata("BACKGROUND")
            grid:SetFrameLevel(0)
            grid:EnableMouse(false)
            grid.lines = {}
            grid:RegisterEvent("UI_SCALE_CHANGED")
            grid:RegisterEvent("DISPLAY_SIZE_CHANGED")
            grid:SetScript("OnEvent", function(self)
                if self:IsShown() then LayOutGrid() end
            end)
            Core.grid = grid
        end
        if not grid then return end
        if shown then
            LayOutGrid()
            grid:Show()
        else
            grid:Hide()
        end
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

    -- A game frame this addon takes over, gone from Edit Mode too: nothing of
    -- it to see or click there, since the addon's own piece is what shows.
    --
    --   * `isLocked` (EditModeSystemMixin:CanBeMoved), so it cannot be dragged;
    --   * `defaultHideSelection`, so opening Edit Mode does not highlight it;
    --   * its selection box (`Selection`, the blue box with the name) at no
    --     opacity and taking no mouse. The flag alone is not enough: Edit
    --     Mode's own "Target and Focus" and "Cast Bar" boxes highlight their
    --     systems directly, whatever the flag says. Nothing of the game's sets
    --     the box's alpha or mouse (EditModeSystemSelectionBaseMixin), so it
    --     stays as set; the mouse waits for the end of combat, as Edit Mode
    --     itself cannot open in combat.
    --
    -- Plain fields and plain calls - no Edit Mode setting is written, no
    -- function replaced. What the frame had is kept in `saved` and put back
    -- when `held` is false.
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

        local selection = frame.Selection
        if type(selection) == "table" and type(selection.SetAlpha) == "function" then
            pcall(selection.SetAlpha, selection, held and 0 or 1)
            if not InCombatLockdown() and type(selection.EnableMouse) == "function" then
                pcall(selection.EnableMouse, selection, not held)
            end
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
    --   title      the module's name
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
    -- looking at the settings in use. What a module lists in `keep` is the
    -- player's own content rather than a setting (the cooldowns they track),
    -- and comes through a reset untouched.
    function Core:Reset(key)
        local module = self:GetModule(key)
        if not module then return end

        local kept = {}
        for name in pairs(module.keep or {}) do kept[name] = module.db[name] end
        Wipe(module.db)
        for name, value in pairs(module.defaults or {}) do
            module.db[name] = DeepCopy(value)
        end
        for name, value in pairs(kept) do module.db[name] = value end
        Normalise(module)
        if module.Init then module.Init() end
    end

    -- Back to defaults, everything at once: the one reset button in the
    -- options. The UI is locked first (a reset puts every piece back in its
    -- place, which is nothing to be dragging). Not in combat - resetting the
    -- frames rewrites their secure parts. Answers whether it happened.
    function Core:ResetAll()
        if InCombatLockdown() then
            Core.Print("the UI cannot be reset in combat.")
            return false
        end
        if Core.IsUnlocked() then Core.SetUnlocked(false) end
        for _, module in ipairs(self.modules) do self:Reset(module.key) end
        UpdateGrid()
        Core.RefreshOptions()
        return true
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
