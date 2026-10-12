-- DogsForeverUI: the namespace, module registry, saved settings (DogsForeverUIDB, per
-- character; a section table is never replaced, so references stay good), profiles,
-- shared helpers and Unlock Mode (movers in Core\Snap.lua, its bar in Options\Unlock.lua).

DogsForeverUI = CreateFrame("Frame")

do -- private scope
    local Core = DogsForeverUI
    local ADDON_NAME = ...

    Core.ADDON_NAME = ADDON_NAME
    Core.TITLE = "Dog's Forever UI"
    Core.MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

    Core.modules = {}       -- in .toc order
    Core.db = {}            -- [module key] = section; DogsForeverUIDB points here

    function Core.Print(message)
        print(Core.TITLE .. " - " .. message)
    end

    ---------------------------------------------------------------------------
    -- Helpers
    ---------------------------------------------------------------------------

    local function Answer(ok, ...)
        if ok then return ... end
    end

    -- fn(...) if it is a function, errors swallowed.
    function Core.Try(fn, ...)
        if type(fn) ~= "function" then return end
        return Answer(pcall(fn, ...))
    end

    -- object:method(...) if it has that method, errors swallowed.
    function Core.Call(object, method, ...)
        if type(object) ~= "table" and type(object) ~= "userdata" then return end
        local fn = object[method]
        if type(fn) ~= "function" then return end
        return Answer(pcall(fn, object, ...))
    end

    -- fn(...), an error handed to the game's error handler instead of stopping the caller.
    function Core.Safely(fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end

    -- A function of a game API namespace (C_Spell, ...), or nil.
    function Core.Api(namespace, name)
        local t = _G[namespace]
        return type(t) == "table" and t[name] or nil
    end

    -- Enum[group][key], or `fallback` where the client has none.
    function Core.EnumValue(group, key, fallback)
        local enum = Enum[group]
        return enum and enum[key] or fallback
    end

    -- A game region at no opacity: still there, never seen.
    function Core.Fade(region)
        if type(region) == "table" and region.SetAlpha then pcall(region.SetAlpha, region, 0) end
    end

    -- A part of a game object: by its getter where it has one, else by its key.
    function Core.Region(object, method, key)
        if type(object[method]) == "function" then
            local ok, region = pcall(object[method], object)
            if ok and region then return region end
        end
        return object[key]
    end

    -- The cursor's height in `frame`'s units.
    function Core.CursorY(frame)
        local _, y = GetCursorPosition()
        return y / frame:GetEffectiveScale()
    end

    -- Settings hold nested tables: copies must be deep.
    local function DeepCopy(value)
        if type(value) ~= "table" then return value end
        local copy = {}
        for key, inner in pairs(value) do copy[key] = DeepCopy(inner) end
        return copy
    end
    Core.DeepCopy = DeepCopy

    local function Wipe(tbl)
        for key in pairs(tbl) do tbl[key] = nil end
    end

    -- Replaced by the options panel once it is built.
    function Core.RefreshOptions() end

    -- `step(elapsed)` every frame from a wake on, until it answers false.
    -- Answers the wake, and the frame (for its events).
    function Core.Waker(step)
        local frame = CreateFrame("Frame")
        frame:Hide()
        frame:SetScript("OnUpdate", function(self, elapsed)
            if not step(elapsed) then self:Hide() end
        end)
        return function() frame:Show() end, frame
    end

    -- A function that tries `fn` now, and every half second until it answers true.
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

    ---------------------------------------------------------------------------
    -- The grid (EllesmereUI's, Bright): gold lines every 32 real pixels out
    -- from the screen's middle, a white cross on it. Seen only, never snapped to.
    ---------------------------------------------------------------------------

    local GRID_PIXELS = 32
    local GRID_ALPHA, CENTRE_ALPHA = 0.30, 0.50
    local PIP_ARM, PIP_ALPHA = 20, 0.5
    local WHITE = { 1, 1, 1 }
    local grid

    local function LayOutGrid()
        local pixel = Core.Style.PixelSize(grid)
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

    local function UpdateGrid()
        local shown = Core.IsUnlocked() and not Core.Snap.Previewing()
        if shown and not grid then
            grid = CreateFrame("Frame", ADDON_NAME .. "Grid", UIParent)
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

    ---------------------------------------------------------------------------
    -- Unlock Mode: every movable module at once. Never entered in combat; a
    -- fight suspends it (changes kept unsaved) and it returns 0.5s after.
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

    -- (No list made: asked every frame.)
    function Core.IsUnlocked()
        for _, module in ipairs(Core.modules) do
            if CanMove(module) and module.db.unlocked then return true end
        end
        return false
    end

    -- Replaced by Options\Unlock.lua: its bar shown or hidden, and kept up to date.
    function Core.PlacingChanged() end
    function Core.EditModeChanged() end

    -- Whether the game's Edit Mode is open. Read only, never written.
    function Core.EditModeOpen()
        return EditModeManagerFrame:IsEditModeActive() == true
    end

    local function Switch(module, unlocked)
        Core.Safely(unlocked and module.Unlock or module.Lock)
    end

    -- Game frames the addon stands in for: no handover box over them.
    local held = setmetatable({}, { __mode = "k" })
    function Core.IsHeld(frame) return held[frame] == true end
    function Core.SetHeld(frame, on) held[frame] = on and true or nil end

    -- A game frame the addon stands in for, out of Edit Mode's sight: its
    -- selection box clear and deaf (mouse only out of combat). Calls only - a
    -- field written onto the game's frame taints its Edit Mode.
    function Core.HoldEditMode(frame, isHeld)
        Core.SetHeld(frame, isHeld)
        local selection = frame.Selection
        if type(selection) == "table" and selection.SetAlpha then
            pcall(selection.SetAlpha, selection, isHeld and 0 or 1)
            if not InCombatLockdown() and selection.EnableMouse then
                pcall(selection.EnableMouse, selection, not isHeld)
            end
        end
    end

    -- Saving as EllesmereUI does: a move, resize, match or anchor is an
    -- unsaved change until Save & Exit; a /reload meanwhile drops it.
    local snapshot              -- [module key] = { [key] = value } when Unlock Mode opened
    local pending = false       -- something changed since
    local suspended = false     -- put away for a fight
    local NOTHING = {}          -- a setting that was nil before an edit
    local edits = {}            -- [module] = { [key] = the value before }

    -- What Save and Revert cover of a module: its places and its sizes (Snap).
    local function EditModeKeys(module)
        local keys = {}
        for key in pairs(module.placement or {}) do keys[key] = true end
        for key in pairs(Core.Snap.SizeKeys(module)) do keys[key] = true end
        return keys
    end

    local function Positions()
        local saved = {}
        for _, module in ipairs(Core.modules) do
            if module.placement and module.db then
                local section = {}
                for key in pairs(EditModeKeys(module)) do section[key] = DeepCopy(module.db[key]) end
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
                    -- (A place may be nil - not placed yet; a size never.)
                    if section[key] ~= nil or module.placement[key] then
                        module.db[key] = DeepCopy(section[key])
                    end
                end
            end
        end
    end

    -- Every setting changed in Unlock Mode put back; answers the modules touched.
    local function UndoEdits()
        local touched = edits
        for module, before in pairs(touched) do
            for key, value in pairs(before) do
                if value == NOTHING then module.db[key] = nil else module.db[key] = value end
            end
        end
        edits = {}
        return touched
    end

    -- A piece moved or resized, a match or an anchor changed (Core\Snap.lua).
    function Core.EditModeMoved()
        if not Core.IsUnlocked() then return end
        pending = true
        Core.EditModeChanged()
    end

    function Core.EditModePending() return pending end

    -- A setting changed in Unlock Mode (an element's menu) is unsaved like a move.
    function Core.NoteEdit(module, key)
        if not (module and module.db and Core.IsUnlocked()) then return end
        local before = edits[module]
        if not before then
            before = {}
            edits[module] = before
        end
        if before[key] == nil then
            local value = module.db[key]
            before[key] = value == nil and NOTHING or DeepCopy(value)
        end
        Core.EditModeMoved()
    end

    -- Save & Exit: what is where now is what Exit Without Saving goes back to.
    function Core.CommitEditMode()
        snapshot = Positions()
        edits = {}
        pending = false
        Core.EditModeChanged()
    end

    function Core.RevertEditMode()
        if pending then
            for module in pairs(UndoEdits()) do
                if module.Refresh then Core.Safely(module.Refresh) end
            end
            if snapshot then
                WritePositions(snapshot)
                for _, module in ipairs(Core.modules) do
                    if module.placement and module.Refresh then module.Refresh() end
                end
            end
        end
        pending = false
        Core.Snap.ForgetGameFrames()
        Core.EditModeChanged()
    end

    -- Replaced by Options\Unlock.lua: the Unsaved Changes question, and taking it away.
    function Core.AskUnsaved(after)
        Core.RevertEditMode()
        Core.SetUnlocked(false)
        if after then after() end
    end
    function Core.DropUnsavedQuestion() end

    -- Unlock Mode or the game's Edit Mode opening or closing, for what shows
    -- only to be placed (the bag bar, the auto-hidden bars).
    local placingWatchers = {}
    function Core.WatchPlacing(fn) placingWatchers[#placingWatchers + 1] = fn end
    local function Placing()
        for _, fn in ipairs(placingWatchers) do fn() end
    end
    EventRegistry:RegisterCallback("EditMode.Enter", Placing, Core)
    EventRegistry:RegisterCallback("EditMode.Exit", Placing, Core)

    local function Show(unlocked)
        UpdateGrid()
        Core.RefreshOptions()
        Core.PlacingChanged(unlocked)
        Core.Snap.UpdateGameLook()
        Placing()
    end

    -- Opened or closed, every piece together. Answers whether it happened.
    function Core.SetUnlocked(unlocked)
        if unlocked and not Core.IsUnlocked() then
            if InCombatLockdown() then
                Core.Print("Cannot enter Unlock Mode during combat.")
                return false
            end
            Core.CommitEditMode()
        end
        if not unlocked then
            suspended = false
            Core.Snap.Cancel()
        end
        for _, module in ipairs(Movable()) do
            if (module.db.unlocked and true or false) ~= unlocked then
                Switch(module, unlocked)
            end
        end
        Show(unlocked)
        return true
    end

    -- EllesmereUI's RequestClose: `save` keeps everything; unsaved changes
    -- ask first. `after` runs once closed.
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

    function Core.ToggleUnlocked()
        if Core.IsUnlocked() then
            Core.RequestClose(false)
            return true
        end
        return Core.SetUnlocked(true)
    end

    -- A fight: movers and bar put away (EllesmereUI's SuspendForCombat), back after it.
    local combat = CreateFrame("Frame")
    combat:RegisterEvent("PLAYER_REGEN_DISABLED")
    combat:RegisterEvent("PLAYER_REGEN_ENABLED")
    combat:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if not Core.IsUnlocked() then return end
            suspended = true
            Core.Snap.Cancel()
            for _, module in ipairs(Movable()) do
                if module.db.unlocked then Switch(module, false) end
            end
            Show(false)
        elseif suspended then
            C_Timer.After(0.5, function()
                if not suspended or InCombatLockdown() then return end
                suspended = false
                for _, module in ipairs(Movable()) do
                    if not module.db.unlocked then Switch(module, true) end
                end
                Show(true)
            end)
        end
    end)

    function Core.UnlockSuspended() return suspended end

    ---------------------------------------------------------------------------
    -- Modules and saved settings
    ---------------------------------------------------------------------------

    local adopted = false   -- the saved file has been read into Core.db
    local settled = false   -- ... and the modules redrawn from it
    local worldAt           -- when the world first came up

    -- A saved file not read in yet (it can arrive late): never overwritten.
    local function Unread(file, live, read)
        return not read and type(file) == "table" and file ~= live and next(file) ~= nil
    end

    local function FillDefaults(db, defaults)
        for key, value in pairs(defaults) do
            if db[key] == nil then db[key] = DeepCopy(value) end
        end
    end

    -- Every default present, anything neither a default nor a placement key
    -- dropped, placement mode off, then the module's own Normalise.
    local function Normalise(module)
        local db = module.db
        local defaults = module.defaults or {}
        local placement = module.placement or {}
        FillDefaults(db, defaults)
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
    --   keep       keys a reset and a profile leave alone (the player's content)
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
        -- Defaults only: the rest of Normalise waits for ADDON_LOADED.
        FillDefaults(db, module.defaults or {})
        return db
    end

    function Core:GetModule(key)
        for _, module in ipairs(self.modules) do
            if module.key == key then return module end
        end
    end

    -- Read into the live sections once it is there, then the name points at them.
    local function LoadSettings()
        if Unread(DogsForeverUIDB, Core.db, adopted) then
            for _, module in ipairs(Core.modules) do
                local from = DogsForeverUIDB[module.key]
                if type(from) == "table" then
                    Wipe(module.db)
                    for key, value in pairs(from) do module.db[key] = value end
                end
            end
            adopted = true
        end

        DogsForeverUIDB = Core.db
        for key in pairs(Core.db) do
            if not Core:GetModule(key) then Core.db[key] = nil end
        end
        for _, module in ipairs(Core.modules) do Normalise(module) end
    end

    local function Each(method)
        for _, module in ipairs(Core.modules) do
            if module[method] then module[method]() end
        end
    end

    -- One module back to its defaults, or to `from` (a profile's section).
    -- Emptied and refilled in place; its `keep` keys untouched.
    function Core:Reset(key, from)
        local module = self:GetModule(key)
        if not module then return end

        local kept = {}
        for name in pairs(module.keep or {}) do kept[name] = module.db[name] end
        Wipe(module.db)
        local source = type(from) == "table" and from or module.defaults or {}
        for name, value in pairs(source) do module.db[name] = DeepCopy(value) end
        for name in pairs(module.keep or {}) do module.db[name] = kept[name] end
        Normalise(module)
        if module.Init then module.Init() end
    end

    -- Every module at once: `settings` = { [module key] = section }, a missing
    -- one (or nil) back to defaults. Locked first; the caller checks combat.
    local function ApplyAll(settings)
        if Core.IsUnlocked() then Core.SetUnlocked(false) end
        pending = false
        edits = {}
        Core.DropUnsavedQuestion()
        for _, module in ipairs(Core.modules) do
            Core:Reset(module.key, settings and settings[module.key])
        end
        UpdateGrid()
        Core.RefreshOptions()
    end

    -- Everything to defaults, the default layout laid out at once. Answers whether it happened.
    function Core:ResetAll()
        if InCombatLockdown() then
            Core.Print("the UI cannot be reset in combat.")
            return false
        end
        ApplyAll(nil)
        Core.DefaultPlaces.Apply()
        return true
    end

    -- A profile loaded. Answers whether it happened.
    function Core:ApplySettings(settings)
        if InCombatLockdown() then return false end
        ApplyAll(settings)
        return true
    end

    -- Whether the saved file has been read in (until then: defaults).
    function Core.SettingsSettled() return settled end

    -- Whether a one-time step may trust its flag: the file is in, or two
    -- seconds have passed since the world came up (no file will arrive).
    local TRUST_AFTER = 2
    function Core.SettingsTrusted()
        if settled then return true end
        return worldAt ~= nil and GetTime() - worldAt >= TRUST_AFTER
    end

    ---------------------------------------------------------------------------
    -- Profiles: the whole UI's settings under a name, for any character of the
    -- account (DogsForeverUIProfiles). Loading one is a reset to it; a module's
    -- `keep` stays.
    ---------------------------------------------------------------------------

    local Profiles = { MAX_NAME = 32 }
    Core.Profiles = Profiles

    local profiles = {}         -- [name] = { [module key] = section }; DogsForeverUIProfiles points here
    Profiles.saved = profiles
    local profilesRead = false

    local function Trim(text)
        if type(text) ~= "string" then return "" end
        return (text:match("^%s*(.-)%s*$"))
    end

    function Profiles.Names()
        local names = {}
        for name in pairs(profiles) do names[#names + 1] = name end
        table.sort(names, function(a, b)
            local la, lb = a:lower(), b:lower()
            if la == lb then return a < b end
            return la < lb
        end)
        return names
    end

    function Profiles.Exists(name)
        return profiles[Trim(name)] ~= nil
    end

    -- Each answers whether it happened and a line to say so (Save: also the name).
    function Profiles.Save(name)
        name = Trim(name)
        if name == "" then return false, "Type a name for the profile." end
        if #name > Profiles.MAX_NAME then
            return false, "A profile's name is at most " .. Profiles.MAX_NAME .. " letters."
        end
        local replaced = profiles[name] ~= nil
        -- This character's settings now, minus what a profile does not carry.
        local settings = {}
        for _, module in ipairs(Core.modules) do
            local section = DeepCopy(module.db)
            for key in pairs(module.keep or {}) do section[key] = nil end
            section.unlocked = nil
            settings[module.key] = section
        end
        profiles[name] = settings
        return true, "Profile " .. name .. (replaced and " updated." or " saved."), name
    end

    function Profiles.Load(name)
        name = Trim(name)
        local profile = profiles[name]
        if not profile then return false, "No profile is called " .. name .. "." end
        if not Core:ApplySettings(profile) then
            return false, "Profiles cannot be loaded in combat."
        end
        return true, "Profile " .. name .. " loaded."
    end

    function Profiles.Delete(name)
        name = Trim(name)
        if not profiles[name] then return false, "No profile is called " .. name .. "." end
        profiles[name] = nil
        return true, "Profile " .. name .. " deleted."
    end

    -- A profile saved before a late file turned up is kept beside the file's.
    local function LoadProfiles()
        local file = DogsForeverUIProfiles
        if Unread(file, profiles, profilesRead) then
            for name, profile in pairs(file) do
                if type(name) == "string" and type(profile) == "table" and profiles[name] == nil then
                    profiles[name] = profile
                end
            end
            profilesRead = true
        end
        DogsForeverUIProfiles = profiles
    end

    ---------------------------------------------------------------------------
    -- Events: the saved tables read as they arrive (no giving up: one that
    -- arrives even one event late must be read), handed back at ADDONS_UNLOADING
    -- as Blizzard_EventTrace's SaveVariables does.
    ---------------------------------------------------------------------------

    Core:RegisterEvent("ADDON_LOADED")
    Core:RegisterEvent("VARIABLES_LOADED")
    Core:RegisterEvent("PLAYER_LOGIN")
    Core:RegisterEvent("PLAYER_ENTERING_WORLD")
    Core:RegisterEvent("ADDONS_UNLOADING")

    Core:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDONS_UNLOADING" then
            -- Unlock Mode changes never saved are lost, as the game's own are.
            if pending then
                UndoEdits()
                if snapshot then WritePositions(snapshot) end
            end
            if not Unread(DogsForeverUIDB, Core.db, adopted) then DogsForeverUIDB = Core.db end
            if not Unread(DogsForeverUIProfiles, profiles, profilesRead) then DogsForeverUIProfiles = profiles end
            return
        end

        if event == "ADDON_LOADED" then
            if arg1 == ADDON_NAME then
                LoadSettings()
                Each("Init")
            end
        else
            if event == "PLAYER_ENTERING_WORLD" then worldAt = worldAt or GetTime() end
            if not settled then
                LoadSettings()
                if adopted then
                    settled = true
                    Each("Refresh")
                end
            end
        end
        if not profilesRead then LoadProfiles() end
    end)
end
