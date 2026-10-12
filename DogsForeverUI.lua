-- NAMESPACE: DogsForeverUI
-- SETTINGS:  DogsForeverUIDB, per character
--            DogsForeverUIProfiles, the account's (Core\Profiles.lua)
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
--   Loot toasts     a toast for each item looted and roll won    (LootRolls\)
--   Cooldowns       bars for the spells and items the player
--                   adds by ID, and IDs on tooltips             (Cooldowns\)
--   Threat          the player's threat on the target            (Threat\)
--   Chat            a window to select and copy chat from        (Chat\)
--   Menus           a quieter micro menu, auto-hiding bars       (Menus\)
--
-- and, with no settings of their own, the breath bar (MirrorTimers\) and
-- fishing, and sitting at a campfire, with a double right-click (Fishing\),
-- and "Skinnable" on living creatures' tooltips for a skinner, and the cloth
-- they drop (Skinning\).
--
-- They were five addons once. Each part with settings is a module here: it
-- registers itself with this file, keeps its settings in its own section of
-- the one saved table, and draws with the shared look in Core\Style.lua. The
-- options are one page with a section per part, and a tab for the cooldown
-- manager (Options\).
--
-- This file owns the saved settings, and the things that are every module's
-- at once: Edit Mode (everything unlocked at once, with a grid), resetting
-- it, and taking over a whole set of settings (a profile). Every module gets
-- a section table that is created here once and never replaced, so a
-- reference a module or the options panel holds stays good for the whole
-- session.

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

    ---------------------------------------------------------------------------
    -- SMALL HELPERS every part uses, for the game's own objects and APIs,
    -- which differ between clients and may be missing altogether.
    ---------------------------------------------------------------------------

    local function Answer(ok, ...)
        if ok then return ... end
    end

    -- `fn(...)` if it is a function; an error in it is swallowed. Answers
    -- what it answered.
    function Core.Try(fn, ...)
        if type(fn) ~= "function" then return end
        return Answer(pcall(fn, ...))
    end

    -- `object:method(...)` if it has that method; an error in it is
    -- swallowed. Answers what it answered.
    function Core.Call(object, method, ...)
        if type(object) ~= "table" and type(object) ~= "userdata" then return end
        local fn = object[method]
        if type(fn) ~= "function" then return end
        return Answer(pcall(fn, object, ...))
    end

    -- A function of one of the game's API namespaces (C_Spell, ...), or nil.
    function Core.Api(namespace, name)
        local t = _G[namespace]
        return type(t) == "table" and t[name] or nil
    end

    -- Enum[group][key], or `fallback` where the client has none.
    function Core.EnumValue(group, key, fallback)
        local enum = type(Enum) == "table" and Enum[group]
        return type(enum) == "table" and enum[key] or fallback
    end

    -- One of the game's regions at no opacity: there still, never seen.
    function Core.Fade(region)
        if type(region) == "table" and type(region.SetAlpha) == "function" then
            pcall(region.SetAlpha, region, 0)
        end
    end

    -- A part of one of the game's objects, by its getter (`method`) where it
    -- has one, by its key otherwise: a button's icon, its border.
    function Core.Region(object, method, key)
        if type(object[method]) == "function" then
            local ok, region = pcall(object[method], object)
            if ok and region then return region end
        end
        return object[key]
    end

    -- The cursor's height in `frame`'s units, for a drag along it.
    function Core.CursorY(frame)
        local _, y = GetCursorPosition()
        return y / frame:GetEffectiveScale()
    end

    -- The options panel replaces this once it is built; until then a setting
    -- changed from a drag has no panel to show it on.
    function Core.RefreshOptions() end

    ---------------------------------------------------------------------------
    -- UNLOCK MODE: EllesmereUI's, ported (the player, 2026-10-02: "port it
    -- properly, our own frames like ellesmere" - Ellesmere\EllesmereUI\
    -- EUI_UnlockMode.lua). The addon's own pieces are moved in it - a mover
    -- over each (Core\Snap.lua), the bar along the top, each mover's cog menu
    -- and the question about unsaved changes (Options\Unlock.lua). The game's
    -- own frames stay the game's: they show a box that hands over to the
    -- game's Edit Mode, which is the game's own, opened and used as ever - as
    -- EllesmereUI does with the game frames it does not replace.
    --
    -- Opened from the options' Unlock UI. Never in combat ("Cannot enter
    -- Unlock Mode during combat."); a fight starting while it is open
    -- suspends it - everything put away, what was changed kept unsaved - and
    -- it comes back half a second after the fight.
    ---------------------------------------------------------------------------

    local function CanMove(module)
        return module.Lock and module.Unlock and module.db
    end

    local function Movable()
        local list = {}
        for _, module in ipairs(Core.modules) do
            if CanMove(module) then list[#list + 1] = module end
        end
        return list
    end

    -- (No list made: asked every frame - the bars' mouseover, Unlock Mode's
    -- movers.)
    function Core.IsUnlocked()
        for _, module in ipairs(Core.modules) do
            if CanMove(module) and module.db.unlocked then return true end
        end
        return false
    end

    local UpdateGrid   -- below

    -- Options\Unlock.lua replaces these: the bar shown or taken away, and
    -- kept up to date.
    function Core.PlacingChanged() end
    function Core.EditModeChanged() end

    -- Whether the game's Edit Mode is open. Read only, never written.
    function Core.EditModeOpen()
        local manager = _G.EditModeManagerFrame
        if type(manager) ~= "table" or type(manager.IsEditModeActive) ~= "function" then
            return false
        end
        local ok, active = pcall(manager.IsEditModeActive, manager)
        return ok and active and true or false
    end

    -- One module locked or unlocked. An error in one is reported and the rest
    -- still go.
    local function Switch(module, unlocked)
        local ok, err = pcall(unlocked and module.Unlock or module.Lock)
        if not ok then
            local handler = geterrorhandler and geterrorhandler()
            if handler then handler(err) end
        end
    end

    -- The game's frames the addon stands in for (its unit frames' party
    -- column...): no handover box over them (Core.HoldEditMode, below).
    local held = setmetatable({}, { __mode = "k" })
    function Core.IsHeld(frame) return held[frame] == true end
    function Core.SetHeld(frame, on) held[frame] = on and true or nil end

    ---------------------------------------------------------------------------
    -- SAVED THE WAY ELLESMEREUI SAVES: a piece moved, resized, matched or
    -- anchored is a change - Save & Exit keeps it, Exit asks (Unsaved
    -- Changes: Exit Without Saving, or Save & Exit), Esc and a click away
    -- keep Unlock Mode open. What every piece's place was when Unlock Mode
    -- opened is kept, and whether anything changed since. A /reload or
    -- logout meanwhile: the saved file gets the places as they were then.
    ---------------------------------------------------------------------------

    local snapshot              -- [module key] = { [key] = value }
    local pending = false       -- something changed since
    local suspended = false     -- put away for a fight, to come back after it

    -- What Save and Revert cover of a module: its places, and the sizes a
    -- piece's own menu sets (Core\Snap.lua, SIZES).
    local function EditModeKeys(module)
        local keys = {}
        for key in pairs(module.placement or {}) do keys[key] = true end
        if Core.Snap and Core.Snap.SizeKeys then
            for key in pairs(Core.Snap.SizeKeys(module)) do keys[key] = true end
        end
        return keys
    end

    -- (Copies: what hangs from what is a table - Core\Snap.lua.)
    local function Positions()
        local saved = {}
        for _, module in ipairs(Core.modules) do
            if module.placement and module.db then
                local section = {}
                for key in pairs(EditModeKeys(module)) do section[key] = Core.DeepCopy(module.db[key]) end
                saved[module.key] = section
            end
        end
        return saved
    end

    local function WritePositions(saved)
        for _, module in ipairs(Core.modules) do
            local section = saved[module.key]
            if section and module.placement and module.db then
                for key in pairs(EditModeKeys(module)) do
                    -- (A place may be nothing - not placed yet; a size never.)
                    if section[key] ~= nil or module.placement[key] then
                        module.db[key] = Core.DeepCopy(section[key])
                    end
                end
            end
        end
    end

    -- A piece moved or resized, a match or an anchor changed (Core\Snap.lua).
    function Core.EditModeMoved()
        if not Core.IsUnlocked() then return end
        pending = true
        Core.EditModeChanged()
    end

    function Core.EditModePending() return pending end

    -- A SETTING CHANGED IN UNLOCK MODE (an element's menu: an action bar's
    -- rows, a frame's auras, a layer...) is an unsaved change like a move
    -- (the player, 2026-10-03: "after editing action bars it doesn't ask for
    -- save"): what it was before is kept, to go back to on Exit Without
    -- Saving or a /reload unsaved.
    local edits = {}            -- [module] = { [key] = the value before }

    function Core.NoteEdit(module, key)
        if not (module and module.db and Core.IsUnlocked()) then return end
        local before = edits[module]
        if not before then
            before = {}
            edits[module] = before
        end
        if before[key] == nil then
            local value = module.db[key]
            before[key] = value == nil and edits or Core.DeepCopy(value)  -- (edits: "was nothing")
        end
        Core.EditModeMoved()
    end

    -- Every setting changed back, each module laid out again.
    local function UndoEdits()
        for module, before in pairs(edits) do
            for key, value in pairs(before) do
                if value == edits then module.db[key] = nil else module.db[key] = value end
            end
            if module.Refresh then
                local ok, err = pcall(module.Refresh)
                if not ok and geterrorhandler then geterrorhandler()(err) end
            end
        end
        edits = {}
    end

    -- Kept (Save & Exit): what is where now is what Exit Without Saving
    -- goes back to.
    function Core.CommitEditMode()
        snapshot = Positions()
        edits = {}
        pending = false
        Core.EditModeChanged()
    end

    -- Put back where they were, and laid out there.
    function Core.RevertEditMode()
        if pending then UndoEdits() end
        if pending and snapshot then
            WritePositions(snapshot)
            for _, module in ipairs(Core.modules) do
                if module.placement and module.Refresh then module.Refresh() end
            end
        end
        pending = false
        if Core.Snap and Core.Snap.ForgetGameFrames then Core.Snap.ForgetGameFrames() end
        Core.EditModeChanged()
    end

    -- Options\Unlock.lua replaces these: the Unsaved Changes question, and
    -- taking it away.
    function Core.AskUnsaved(after)
        Core.RevertEditMode()
        Core.SetUnlocked(false)
        if after then after() end
    end
    function Core.DropUnsavedQuestion() end

    -- PLACING: Unlock Mode or the game's Edit Mode opening or closing, for
    -- what shows only to be placed (the bag bar, the auto-hidden bars).
    local placingWatchers = {}
    function Core.WatchPlacing(fn) placingWatchers[#placingWatchers + 1] = fn end
    local function Placing()
        for _, fn in ipairs(placingWatchers) do fn() end
    end
    EventRegistry:RegisterCallback("EditMode.Enter", Placing, Core)
    EventRegistry:RegisterCallback("EditMode.Exit", Placing, Core)

    -- A WAKER, for what has work only now and then: `step(elapsed)` every
    -- frame from a wake on, until it answers false. Answers the wake, and
    -- the frame (for its events).
    function Core.Waker(step)
        local frame = CreateFrame("Frame")
        frame:Hide()
        frame:SetScript("OnUpdate", function(self, elapsed)
            if not step(elapsed) then self:Hide() end
        end)
        return function() frame:Show() end, frame
    end

    -- A RETRY, for a one-time default that waits for the saved settings or
    -- the end of a fight: answers a function that tries `fn` now, and again
    -- every half second until it answers true.
    function Core.Retry(fn)
        local since = 0
        local wake = Core.Waker(function(elapsed)
            since = since + elapsed
            if since < 0.5 then return true end
            since = 0
            return not fn()
        end)
        return function()
            if not fn() then wake() end
        end
    end

    local function Show(unlocked)
        UpdateGrid()
        Core.RefreshOptions()
        Core.PlacingChanged(unlocked)
        if Core.Snap then Core.Snap.UpdateGameLook() end
        Placing()
    end

    -- Opened or closed, every piece together. Answers whether it happened:
    -- never opened in combat.
    function Core.SetUnlocked(unlocked)
        local was = Core.IsUnlocked()
        if unlocked and not was then
            if InCombatLockdown() then
                Core.Print("Cannot enter Unlock Mode during combat.")
                return false
            end
            -- What Exit Without Saving goes back to.
            Core.CommitEditMode()
        end
        if not unlocked then
            suspended = false
            if Core.Snap then Core.Snap.Cancel() end
        end
        for _, module in ipairs(Movable()) do
            if (module.db.unlocked and true or false) ~= unlocked then
                Switch(module, unlocked)
            end
        end
        Show(unlocked)
        return true
    end

    -- Leaving (EllesmereUI's RequestClose): `save` keeps everything first;
    -- nothing changed, it just closes; changes unsaved, it asks. `after`
    -- runs once it has closed (the handover to the game's Edit Mode).
    function Core.RequestClose(save, after)
        if not Core.IsUnlocked() and not suspended then
            if after then after() end
            return
        end
        if save then
            Core.CommitEditMode()
        elseif pending then
            Core.AskUnsaved(after)
            return
        end
        Core.SetUnlocked(false)
        if after then after() end
    end

    -- The options' Unlock UI: Unlock Mode, or out of it again.
    function Core.ToggleUnlocked()
        if Core.IsUnlocked() then
            Core.RequestClose(false)
            return true
        end
        return Core.SetUnlocked(true)
    end

    -- A FIGHT: Unlock Mode put away, its changes kept unsaved; back half a
    -- second after the fight (EllesmereUI's SuspendForCombat and
    -- ResumeAfterCombat). Only the movers and the bar go - the pieces lock
    -- as they lock for a fight anyway.
    local combat = CreateFrame("Frame")
    combat:RegisterEvent("PLAYER_REGEN_DISABLED")
    combat:RegisterEvent("PLAYER_REGEN_ENABLED")
    combat:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if not Core.IsUnlocked() then return end
            suspended = true
            if Core.Snap then Core.Snap.Cancel() end
            for _, module in ipairs(Movable()) do
                if module.db.unlocked then Switch(module, false) end
            end
            Show(false)
        elseif suspended then
            local function Resume()
                if not suspended or InCombatLockdown() then return end
                suspended = false
                for _, module in ipairs(Movable()) do
                    if not module.db.unlocked then Switch(module, true) end
                end
                Show(true)
            end
            C_Timer.After(0.5, Resume)
        end
    end)

    function Core.UnlockSuspended() return suspended end

    ---------------------------------------------------------------------------
    -- THE GRID (EllesmereUI's): lines in the addon's gold every 32 real
    -- pixels out from the screen's middle, the two middle lines brighter, a
    -- small white cross on the middle itself. Always EllesmereUI's Bright,
    -- with no switch (the player, 2026-10-03). Under all the UI, never in the
    -- mouse's way. Only seen - nothing snaps to it.
    ---------------------------------------------------------------------------

    local GRID_PIXELS = 32
    local GRID_ALPHA, CENTRE_ALPHA = 0.30, 0.50
    local PIP_ARM, PIP_ALPHA = 20, 0.5
    local WHITE = { 1, 1, 1 }
    local grid

    local function OnePixel()
        if PixelUtil and PixelUtil.GetPixelToUIUnitFactor then
            local scale = grid:GetEffectiveScale()
            if type(scale) == "number" and scale > 0 then return PixelUtil.GetPixelToUIUnitFactor() / scale end
        end
        return 1
    end

    local function LayOutGrid()
        local pixel = OnePixel()
        local width, height = grid:GetWidth(), grid:GetHeight()
        local spacing = GRID_PIXELS * pixel
        local function Snapped(v) return math.floor(v / pixel + 0.5) * pixel end
        local cx, cy = Snapped(width / 2), Snapped(height / 2)
        local gold = Core.Style.GOLD

        local used = 0
        local function Line(vertical, at, alpha, sublevel, colour, length, from)
            used = used + 1
            local texture = grid.lines[used]
            if not texture then
                texture = grid:CreateTexture(nil, "BACKGROUND")
                grid.lines[used] = texture
            end
            colour = colour or gold
            texture:SetColorTexture(colour[1], colour[2], colour[3], alpha)
            texture:SetDrawLayer("BACKGROUND", sublevel)
            texture:ClearAllPoints()
            if vertical then
                texture:SetPoint("TOPLEFT", grid, "TOPLEFT", at, -(from or 0))
                texture:SetSize(pixel, length or height)
            else
                texture:SetPoint("TOPLEFT", grid, "TOPLEFT", from or 0, -at)
                texture:SetSize(length or width, pixel)
            end
            texture:Show()
        end

        -- Each line out from the middle, one side then the other.
        local function Pair(vertical, middle, k, limit)
            for side = 1, -1, -2 do
                local at = Snapped(middle + side * k * spacing)
                if at > 0 and at < limit then Line(vertical, at, GRID_ALPHA, -7) end
            end
        end
        for k = 1, math.floor(width / spacing) do Pair(true, cx, k, width) end
        for k = 1, math.floor(height / spacing) do Pair(false, cy, k, height) end
        Line(true, cx, CENTRE_ALPHA, -6)
        Line(false, cy, CENTRE_ALPHA, -6)
        Line(true, cx, PIP_ALPHA, -5, WHITE, 2 * PIP_ARM, cy - PIP_ARM)
        Line(false, cy, PIP_ALPHA, -5, WHITE, 2 * PIP_ARM, cx - PIP_ARM)
        for spare = used + 1, #grid.lines do grid.lines[spare]:Hide() end
    end

    function UpdateGrid()
        -- (Not while previewing: Core\Snap.lua, PREVIEW.)
        local snap = Core.Snap
        local shown = Core.IsUnlocked() and not (snap and snap.Previewing and snap.Previewing())
        if shown and not grid then
            grid = CreateFrame("Frame", Core.ADDON_NAME .. "Grid", UIParent)
            grid:SetAllPoints(UIParent)
            grid:SetFrameStrata("BACKGROUND")
            grid:SetFrameLevel(1)
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
    Core.UpdateGrid = UpdateGrid

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
    -- Its selection box (`Selection`, the blue box with the name) at no
    -- opacity and taking no mouse - so it can be neither seen nor dragged.
    -- Nothing of the game's sets the box's alpha or mouse
    -- (EditModeSystemSelectionBaseMixin), so it stays as set; the mouse waits
    -- for the end of combat, as Edit Mode itself cannot open in combat.
    --
    -- CALLS ONLY, NO FIELD WRITTEN onto the game's frame. Until 2026-10-03
    -- this also set the frame's `isLocked` and `defaultHideSelection`. A
    -- value the addon writes onto the game's frame is the addon's
    -- (tainted): opening the game's Edit Mode, each held frame's own
    -- OnEditModeEnter read `defaultHideSelection` first and ran tainted from
    -- there - the micro menu's updating the queue status button, the chat
    -- frame's FCF_SelectDockFrame and FCF_SetLocked, the XP bar's
    -- isInEditMode - leaving the game's shared state tainted, which the rest
    -- of Edit Mode's opening then read: its party frames could no longer
    -- compare their secret health colours (CompactUnitFrame.lua: "attempt to
    -- compare local 'oldR' (a secret number value, while execution tainted
    -- by 'DogsForeverUI')"), on opening and on closing alike.
    --
    -- (`saved` is kept for the callers; nothing is stored in it now.)
    function Core.HoldEditMode(saved, frame, held)
        -- (And no overlay in the addon's Edit Mode: the addon's own piece is
        -- what is placed there - Core\Snap.lua.)
        Core.SetHeld(frame, held)

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

    Core.DeepCopy = DeepCopy

    -- Back to defaults, for one module - or, given `from`, to those settings
    -- instead (a profile's section, Core\Profiles.lua). The section is
    -- emptied and refilled rather than replaced, so every reference already
    -- handed out is still looking at the settings in use; whatever `from`
    -- lacks comes from the defaults, and whatever this version no longer has
    -- is dropped, as for a file loaded at login. What a module lists in `keep`
    -- is the player's own content rather than a setting (the cooldowns they
    -- track), and comes through untouched.
    function Core:Reset(key, from)
        local module = self:GetModule(key)
        if not module then return end

        local kept = {}
        for name in pairs(module.keep or {}) do kept[name] = module.db[name] end
        Wipe(module.db)
        local source = type(from) == "table" and from or module.defaults or {}
        for name, value in pairs(source) do
            module.db[name] = DeepCopy(value)
        end
        for name in pairs(module.keep or {}) do module.db[name] = kept[name] end
        Normalise(module)
        if module.Init then module.Init() end
    end

    -- Every module's settings at once: `settings` = { [module key] = section },
    -- a module missing from it back to defaults; nil = everything to defaults.
    -- The UI is locked first (every piece goes back to a place, which is
    -- nothing to be dragging). Not in combat - it rewrites the frames' secure
    -- parts - so the caller checks.
    local function ApplyAll(settings)
        if Core.IsUnlocked() then Core.SetUnlocked(false) end
        -- Every place is the new settings' now: nothing left unsaved.
        pending = false
        edits = {}
        Core.DropUnsavedQuestion()
        for _, module in ipairs(Core.modules) do
            Core:Reset(module.key, settings and settings[module.key])
        end
        UpdateGrid()
        Core.RefreshOptions()
    end

    -- Back to defaults, everything at once: the one reset button in the
    -- options. Answers whether it happened.
    function Core:ResetAll()
        if InCombatLockdown() then
            Core.Print("the UI cannot be reset in combat.")
            return false
        end
        ApplyAll(nil)
        -- The addon's own layout laid out now, in the same moment (laid out a
        -- moment later, everything first showed in the wrong place).
        local places = Core.DefaultPlaces
        if places and places.Apply then places.Apply() end
        return true
    end

    -- A whole set of settings taken over at once: a profile being loaded.
    -- Answers whether it happened.
    function Core:ApplySettings(settings)
        if InCombatLockdown() then return false end
        ApplyAll(settings)
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
            -- Moved in Edit Mode and never saved: lost, as the game's own
            -- unsaved changes are.
            if pending then
                for module, before in pairs(edits) do
                    for key, value in pairs(before) do
                        if value == edits then module.db[key] = nil else module.db[key] = value end
                    end
                end
            end
            if pending and snapshot then WritePositions(snapshot) end
            SaveSettings()
            return
        end

        -- Deliberately no giving up: a table that arrives even one event late
        -- must still be read.
        if not settled then
            LoadSettings()
            if adopted then
                settled = true
                Each("Refresh")
            end
        end
    end)

    -- Whether the saved file has been read in: until then the settings are
    -- the defaults, and a one-time step that trusts a "done" flag in them
    -- would run again on every login (NamePlates.lua, DEFAULTS).
    function Core.SettingsSettled() return settled end

    -- Whether a one-time step may trust its flag: the file is in, or two
    -- seconds have passed since the world first came up (a character with
    -- no saved file yet - nothing will arrive).
    local worldAt
    local trustWatch = CreateFrame("Frame")
    trustWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
    trustWatch:SetScript("OnEvent", function(self)
        worldAt = worldAt or GetTime()
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end)
    local TRUST_AFTER = 2
    function Core.SettingsTrusted()
        if settled then return true end
        return worldAt ~= nil and GetTime() - worldAt >= TRUST_AFTER
    end
end
