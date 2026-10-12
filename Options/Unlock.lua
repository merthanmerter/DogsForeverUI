-- UNLOCK MODE'S WINDOWS, EllesmereUI's (Ellesmere\EllesmereUI\
-- EUI_UnlockMode.lua), in the addon's look (Options\Widgets.lua). The movers
-- and what they do are Core\Snap.lua's, what is open and what is saved
-- DogsForeverUI.lua's; this file is the rest:
--
--   * THE BAR along the top: Grid Lines, Dark Overlays, Snap Elements,
--     Coordinates, Hover Top Bar; Exit and Save & Exit;
--   * a piece's MENU, opened by clicking the piece: its size, Match Width /
--     Height, place, Anchor, snap target, Center on Screen, Relative to
--     Screen, Reset Position - and its own settings;
--   * the ANCHOR MENU, at the cursor, once the piece to anchor to is picked;
--   * UNSAVED CHANGES, asked on Exit;
--   * the GAME'S OWN FRAMES: a box over each that hands over to the game's
--     Edit Mode ("Edit from Blizzard");
--   * the screen's DIMMER, darker while a piece is being picked;
--   * ESC: the menu shut, then the picking stopped, then Unlock Mode left.
--
-- No tooltips and few words (the player, 2026-10-02: "less description ...
-- this looks too AI").

local Unlock = {}
DogsForeverUI.Options.Unlock = Unlock

do -- private scope
    local Core = DogsForeverUI
    local Options = Core.Options
    local Snap = Core.Snap
    local Style = Core.Style
    local W = Core.Widgets

    -- Over the movers (Snap.STRATA); the questions over everything.
    local STRATA = "FULLSCREEN"
    local TOP_STRATA = "FULLSCREEN_DIALOG"
    local ANCHORED = { 1, 0.7, 0.3, 0.85 }
    local REMOVE = { 0.9, 0.3, 0.3, 1 }

    local fromOptions = false   -- the options were open when Unlock Mode opened

    local function Settings() return Snap.db or Snap.defaults end

    local function HideQuietly(frame)
        if frame and frame:IsShown() then
            frame.quiet = true
            frame:Hide()
            frame.quiet = false
        end
    end

    -- A window of the addon's: its dark, its border.
    local function NewWindow(name, width, height, strata)
        local frame = CreateFrame("Frame", name and (Core.ADDON_NAME .. name) or nil, UIParent)
        frame:SetSize(width, height)
        frame:SetFrameStrata(strata or STRATA)
        frame:SetToplevel(true)
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        frame:Hide()
        frame.bg = W.Flat(frame, "BACKGROUND", Style.WINDOW_BACKGROUND)
        frame.bg:SetAllPoints(frame)
        frame.border = Style.AddBorder(frame)
        W.KeepSnapped(frame.border)
        frame:HookScript("OnShow", W.SnapBorders)
        return frame
    end
    Unlock.NewWindow = NewWindow

    -- Shut by a click anywhere else (as the game's own menus are) - but not
    -- one in a dropdown's list it opened, nor on `keep()`'s frames.
    local function ShutOnClickAway(frame, keep)
        frame:HookScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
        frame:HookScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
        frame:SetScript("OnEvent", function(self)
            if self:IsMouseOver() then return end
            local list = W.Popup()
            if list:IsShown() and list:IsMouseOver() then return end
            for _, other in ipairs(keep and keep() or {}) do
                if other and other:IsVisible() and other:IsMouseOver() then return end
            end
            self:Hide()
        end)
    end

    ---------------------------------------------------------------------------
    -- THE BAR (EllesmereUI's top HUD):
    --
    --   +-----------------------------------------------------------------+
    --   | Unlock Mode         (o) Snap Elements   [ Exit ] [ Save & Exit ] |
    --   | Use arrow keys to move selected element 1px any direction. ...  |
    --   +-----------------------------------------------------------------+
    --
    -- Snap Elements is its one switch: the grid always bright, the movers
    -- always dark with their place in numbers, the bar always shown (the
    -- player, 2026-10-03: no options for those, no hover bar). Dragged by
    -- anywhere but its buttons, it stays where it is put until the UI
    -- reloads.
    ---------------------------------------------------------------------------

    local BAR_WIDTH, BAR_HEIGHT = 640, 64
    local BAR_SIDE = 16
    local SAVE_EXIT = "Save & Exit"
    local HINT = "Use arrow keys to move selected element 1px any direction. Shift+Right Click to temporarily hide overlay"

    local bar

    -- One of the bar's switches changed (and the tests' way to change one).
    function Unlock.Set(key, value)
        local db = Snap.db
        if not db then return end
        db[key] = value
        Unlock.RefreshBar()
    end

    -- PREVIEW (Core\Snap.lua): Unlock Mode's own look gone - movers, the
    -- game frames' boxes, the grid, the dimmer, an open menu - the frames
    -- alone, until it is switched off.
    function Unlock.SetPreview(on)
        on = on and true or false
        if on then
            Unlock.CloseMenu()
            W.ClosePopup()
        end
        Snap.SetPreview(on)
        if Core.UpdateGrid then Core.UpdateGrid() end
        if Snap.OnDrive then Snap.OnDrive() end
        Unlock.RefreshBar()
    end

    function Unlock.RefreshBar()
        if not bar then return end
        for _, control in ipairs(bar.controls) do control.Refresh() end
        W.SetStyle(bar.save, Core.EditModePending() and "active" or nil)
    end

    -- WHERE THE BAR OPENS (the player, 2026-10-03): centred, slightly below
    -- the micro menu's own place by default (centred on the top edge -
    -- Core\DefaultPlaces.lua), so the two never overlap; where it was dragged
    -- to from then on.
    Unlock.BAR_GAP = 8
    local function PlaceBar()
        if not bar or bar.dragged then return end
        local below = Unlock.BAR_GAP
        local micro = Snap.EntryById("micro")
        local box = micro and Snap.Box(micro)
        if box then below = below + (box.t - box.b) end
        bar:ClearAllPoints()
        bar:SetPoint("TOP", UIParent, "TOP", 0, -below)
    end

    local function BuildBar()
        if bar then return end
        bar = NewWindow("UnlockBar", BAR_WIDTH, BAR_HEIGHT)
        bar:SetPoint("TOP", UIParent, "TOP", 0, -8)
        bar.controls = {}
        Unlock.bar = bar

        bar.title = W.Text(bar, 15, W.GOLD, true)
        bar.title:SetPoint("TOPLEFT", bar, "TOPLEFT", BAR_SIDE, -14)
        bar.title:SetText("Unlock Mode")

        bar.save = W.Button(bar, SAVE_EXIT, 112, function() Core.RequestClose(true) end)
        bar.save:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -BAR_SIDE, -10)
        bar.exit = W.Button(bar, "Exit", 80, function() Core.RequestClose(false) end)
        bar.exit:SetPoint("RIGHT", bar.save, "LEFT", -8, 0)

        -- Snap Elements, its name after it, left of Exit.
        local text = W.Text(bar, 12, W.TEXT)
        text:SetPoint("RIGHT", bar.exit, "LEFT", -22, 0)
        text:SetText("Snap Elements")
        local snap = W.Toggle(bar, function() return Settings().snap and true or false end,
            function(on) Unlock.Set("snap", on and true or false) end)
        snap:SetPoint("RIGHT", text, "LEFT", -8, 0)
        local hit = CreateFrame("Button", nil, bar)
        hit:SetPoint("TOPLEFT", text, "TOPLEFT", -2, 4)
        hit:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", 2, -4)
        hit:SetScript("OnClick", function() snap:Click() end)
        bar.snap = snap
        bar.controls[#bar.controls + 1] = snap

        -- Preview, its name after it, left of Snap Elements.
        local previewText = W.Text(bar, 12, W.TEXT)
        previewText:SetPoint("RIGHT", snap, "LEFT", -22, 0)
        previewText:SetText("Preview")
        local preview = W.Toggle(bar, function() return Snap.Previewing() end,
            function(on) Unlock.SetPreview(on) end)
        preview:SetPoint("RIGHT", previewText, "LEFT", -8, 0)
        local previewHit = CreateFrame("Button", nil, bar)
        previewHit:SetPoint("TOPLEFT", previewText, "TOPLEFT", -2, 4)
        previewHit:SetPoint("BOTTOMRIGHT", previewText, "BOTTOMRIGHT", 2, -4)
        previewHit:SetScript("OnClick", function() preview:Click() end)
        bar.preview = preview
        bar.controls[#bar.controls + 1] = preview

        -- (Quick Keybinds left this bar for the options window's header,
        -- beside Unlock UI - the player, 2026-10-03.)

        bar.hint = W.Text(bar, 11, W.MUTED)
        bar.hint:SetPoint("TOPLEFT", bar, "TOPLEFT", BAR_SIDE, -42)
        bar.hint:SetText(HINT)
        -- Wide enough for the hint, and for the title beside the row of
        -- buttons and switches.
        local row = 112 + 8 + 80 + 22 + (text:GetStringWidth() or 0) + 8 + W.TOGGLE_WIDTH
            + 22 + (previewText:GetStringWidth() or 0) + 8 + W.TOGGLE_WIDTH
        bar:SetWidth(math.max(BAR_WIDTH, (bar.hint:GetStringWidth() or 0) + 2 * BAR_SIDE,
            (bar.title:GetStringWidth() or 0) + 24 + row + 2 * BAR_SIDE))

        -- Dragged anywhere.
        bar:SetMovable(true)
        bar:RegisterForDrag("LeftButton")
        bar:SetScript("OnDragStart", function(self) self:StartMoving() end)
        bar:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            self:SetUserPlaced(false)
            self.dragged = true
            W.SnapBorders()
        end)
        bar:SetScript("OnHide", function() W.ClosePopup() end)
    end

    ---------------------------------------------------------------------------
    -- A PIECE'S MENU (EllesmereUI's mover menu), beside its mover - opened
    -- by a click on the piece (the player, 2026-10-03: no settings button on
    -- the frames; match and anchor in the menu, not on the frame):
    --
    --   Target
    --   Width                 [ 200 ]   (Extra Width while matched)
    --   Height                [  20 ]
    --   [ Match Width ]                  (Unmatch Width: Player)
    --   [ Match Height ]
    --   X Position            [ 500 ]
    --   Y Position            [-760 ]
    --   [ Anchor ]                       (Remove Anchor while anchored)
    --   Anchored to           Player     (while anchored)
    --   Offset X / Offset Y   [ 0 ]
    --   [ Select Snap Target ][ None ]
    --   Relative to Screen    [ Center v ]
    --   [ Center on Screen ]
    --   [ Reset Position ]
    --   ---------------------------------
    --   ...its own settings
    ---------------------------------------------------------------------------

    local MENU_WIDTH = 250
    local MENU_SIDE = 10
    local MENU_INNER = MENU_WIDTH - 2 * MENU_SIDE
    local ROW = 24
    local GAP = 4
    local NUMBER = 64
    local CONTROL = 112
    local SLIDER_VALUE = 52     -- the typed value's box right of a slider, and its gap
    local SLIDER_GAP = 6
    local REFRESH_EVERY = 0.1

    local menu

    local function MenuEntry() return menu and menu.entry end

    -- A box's number as it is now, unless it is being typed in.
    local function ShowNumber(box)
        if not box:HasFocus() then box.Refresh() end
    end

    local function Row(parent, title)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(MENU_INNER, ROW)
        row.label = W.Text(row, 12, W.TEXT)
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.label:SetText(title or "")
        return row
    end

    local function NumberRow(title, get, set)
        local row = Row(menu, title)
        row.box = W.NumberBox(row, nil, NUMBER, function()
            local entry = MenuEntry()
            return entry and get(entry) or nil
        end, function(value)
            local entry = MenuEntry()
            if entry then set(entry, value) end
            Unlock.RefreshMenu()
        end)
        row.box:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.box:SetHeight(ROW - 2)
        row.numbers = { row.box }
        return row
    end

    local function MenuButton(text, width, onClick)
        local button = W.Button(menu, text, width or MENU_INNER, function(self, mouse)
            local entry = MenuEntry()
            if entry then onClick(entry, self, mouse) end
            Unlock.RefreshMenu()
        end)
        button:SetHeight(ROW - 2)
        return button
    end

    ---------------------------------------------------------------------------
    -- A PIECE'S OWN SETTINGS (the player, 2026-10-02: "we need settings like
    -- buffs on top/bottom for target frame and etc. in unlock mode menus"):
    -- the addon's own that are about that piece, changed at once.
    ---------------------------------------------------------------------------

    local ownSettings

    local function Whole(value) return tostring(math.floor(value + 0.5)) end
    local function WholePercent(value) return Whole(value) .. "%" end

    local function OwnSettings(entry)
        if not ownSettings then
            ownSettings = {}
            local function Add(id, item)
                ownSettings[id] = ownSettings[id] or {}
                table.insert(ownSettings[id], item)
            end
            local Frames, Menus = Core.Frames, Core.Menus
            local Auras = Frames and Frames.UnitAuras
            if Frames then
                for _, unit in ipairs({ "player", "target", "focus", "targettarget", "pet", "party" }) do
                    for _, aura in ipairs(Auras and Auras.UNITS or {}) do
                        -- (By the frame it is on: the party's Show self row is
                        -- the player's unit on a party frame.)
                        if (aura.plate or aura.unit) == unit or (unit == "party" and aura.key == "partyAuras") then
                            Add(unit, { module = Frames, key = aura.key, label = "Auras", kind = "choice",
                                        choices = aura.choices or Auras.CHOICES })
                            break
                        end
                    end
                    if unit == "target" or unit == "focus" then
                        Add(unit, { module = Frames, key = "showCastbar", label = "Castbar", kind = "toggle" })
                    end
                    Add(unit, { module = Frames, key = "showHealthText", label = "Health text", kind = "toggle" })
                    Add(unit, { module = Frames, key = "showPowerText", label = "Resource text", kind = "toggle" })
                    Add(unit, { module = Frames, key = "classColors", label = "Class colours", kind = "toggle" })
                    if unit == "player" then
                        -- The party frames' dispel marks (UnitAuras.lua, PLAYER_DISPEL).
                        Add(unit, { module = Frames, key = "playerDispel", label = "Dispel marks", kind = "toggle" })
                    end
                    -- Their sizes and layer, from the options' Sizes section
                    -- (gone since 2026-10-03: the player, "we handle this in
                    -- unlock mode"). The unit frames share theirs.
                    if unit == "party" then
                        -- The column's order and the player's own frame in it
                        -- (UnitPlate.lua, SORTING THE COLUMN, SHOW SELF).
                        Add(unit, { module = Frames, key = "partySort", label = "Sort by", kind = "choice",
                                    choices = Frames.UnitPlate.SORTS })
                        Add(unit, { module = Frames, key = "partyShowSelf", label = "Show self", kind = "toggle" })
                        Add(unit, { module = Frames, key = "partyShowPets", label = "Show pets", kind = "toggle" })
                        Add(unit, { module = Frames, key = "partyRaidHealth", label = "Health height", kind = "number", min = 1, max = 400 })
                        Add(unit, { module = Frames, key = "partyPower", label = "Power height", kind = "number", min = 1, max = 400 })
                        Add(unit, { module = Frames, key = "partyStrata", label = "Layer", kind = "choice", choices = Options.STRATA })
                    else
                        Add(unit, { module = Frames, key = "barWidth", label = "Width", kind = "number", min = 1, max = 4000 })
                        Add(unit, { module = Frames, key = "barHeight", label = "Health height", kind = "number", min = 1, max = 400 })
                        Add(unit, { module = Frames, key = "powerHeight", label = "Power height", kind = "number", min = 1, max = 400 })
                        Add(unit, { module = Frames, key = "castbarHeight", label = "Cast height", kind = "number", min = 1, max = 400 })
                        Add(unit, { module = Frames, key = "textPadding", label = "Text padding", kind = "slider",
                                    min = 0, max = Core.Style.MAX_TEXT_PADDING, step = 0.01, text = Options.Percent })
                        Add(unit, { module = Frames, key = "frameStrata", label = "Layer", kind = "choice", choices = Options.STRATA })
                    end
                end
            end
            local Castbar = Core.Castbar
            if Castbar then
                Add("castbar", { module = Castbar, key = "textPadding", label = "Text padding", kind = "slider",
                                 min = 0, max = Core.Style.MAX_TEXT_PADDING, step = 0.01, text = Options.Percent })
                Add("castbar", { module = Castbar, key = "frameStrata", label = "Layer", kind = "choice", choices = Options.STRATA })
                Add("swing", { module = Castbar, key = "swingHeight", label = "Height", kind = "number", min = 1, max = 400 })
                Add("swing", { module = Castbar, key = "swingStrata", label = "Layer", kind = "choice", choices = Options.STRATA })
            end
            -- The rest of the castbar group, the XP bar, the cooldowns and the
            -- threat bar: their layer.
            for id, module in pairs({ fsr = Core.FiveSecondRule, combo = Core.ComboPoints, xp = Core.XPBar,
                                      cooldowns = Core.Cooldowns, threat = Core.Threat }) do
                if module then
                    Add(id, { module = module, key = "frameStrata", label = "Layer", kind = "choice", choices = Options.STRATA })
                end
            end
            local Cooldowns = Core.Cooldowns
            if Cooldowns then
                Add("cooldowns", { module = Cooldowns, key = "growDirection", label = "Bars grow", kind = "choice",
                                   choices = Cooldowns.GROW })
                Add("cooldowns", { module = Cooldowns, key = "showTooltipIDs", label = "IDs on tooltips", kind = "toggle" })
                if Core.LootToasts then
                    Add("toasts", { module = Core.LootToasts, key = "growDirection", label = "Toasts grow", kind = "choice",
                                    choices = Cooldowns.GROW })
                end
            end
            if Menus then
                Add("micro", { module = Menus, key = "quietMicroMenu", label = "Auto-hide", kind = "toggle" })
                Add("xp", { module = Menus, key = "fadeXPBar", label = "Auto-hide", kind = "toggle" })
            end
            -- The action bars (ActionBars\ActionBars.lua): how many buttons,
            -- in how many rows, how big, how far apart, and when it is there;
            -- then its Auto-hide (Menus\ActionBars.lua).
            local Bars = Core.ActionBars
            if Bars then
                local fades = {}
                for _, entry in ipairs(Menus and Menus.ActionBars and Menus.ActionBars.LIST or {}) do
                    fades[entry.label] = entry.key
                end
                for _, info in ipairs(Bars.BARS) do
                    local k, id = info.key, info.id or info.key
                    Add(id, { module = Bars, key = k .. "Buttons", label = "Buttons", kind = "slider",
                              min = 1, max = info.count, step = 1, text = Whole })
                    Add(id, { module = Bars, key = k .. "Orientation", label = "Orientation", kind = "choice",
                              choices = Bars.ORIENTATION })
                    if info.grow then
                        Add(id, { module = Bars, key = k .. "Grow", label = "Grow", kind = "choice", choices = Bars.GROW })
                    end
                    Add(id, { module = Bars, key = k .. "Rows", kind = "slider",
                              label = function()
                                  return Bars.db and Bars.db[k .. "Orientation"] == "vertical" and "Columns" or "Rows"
                              end,
                              min = 1, max = info.count, step = 1, text = Whole })
                    Add(id, { module = Bars, key = k .. "Size", label = "Button size", kind = "slider",
                              min = Bars.SIZE_MIN, max = Bars.SIZE_MAX, step = 1, text = Whole })
                    Add(id, { module = Bars, key = k .. "Spacing", label = "Spacing", kind = "slider",
                              min = 0, max = Bars.SPACING_MAX, step = 1, text = Whole })
                    Add(id, { module = Bars, key = k .. "Show", label = "Show", kind = "choice", choices = Bars.SHOW })
                    if Bars.defaults[k .. "ShowEmpty"] ~= nil then
                        Add(id, { module = Bars, key = k .. "ShowEmpty", label = "Always show buttons", kind = "toggle" })
                    end
                    if Menus and fades[info.label] then
                        Add(id, { module = Menus, key = fades[info.label], label = "Auto-hide", kind = "toggle" })
                    end
                end
            end
            -- The game's frames placed in Unlock Mode (ActionBars\GameFrames.lua):
            -- the minimap's size, the chat window's (Edit Mode's no longer).
            local Game = Core.GameFrames
            if Game then
                Add("minimap", { module = Game, key = "minimapSize", label = "Size", kind = "slider",
                                 min = Game.SIZE_MIN, max = Game.SIZE_MAX, step = 5, text = WholePercent })
                -- The title under the map (on by default; the addon's own, at
                -- once - not Edit Mode's Header Underneath).
                Add("minimap", { module = Game, key = "minimapHeaderBelow", label = "Header below", kind = "toggle" })
                -- Rotate minimap: the addon's own too, at once - no reload.
                Add("minimap", { module = Game, key = "minimapRotate", label = "Rotate minimap", kind = "toggle" })
                Add("bags", { module = Game, key = "bagsSize", label = "Size", kind = "slider",
                              min = Game.SIZE_MIN, max = Game.SIZE_MAX, step = 5, text = WholePercent })
                Add("chat", { module = Game, key = "chatWidth", label = "Width", kind = "slider",
                              min = Game.CHAT_MIN, max = Game.CHAT_MAX, step = 1, text = Whole })
                Add("chat", { module = Game, key = "chatHeight", label = "Height", kind = "slider",
                              min = Game.CHAT_MIN / 2, max = Game.CHAT_MAX, step = 1, text = Whole })
                if Core.Chat then
                    Add("chat", { module = Core.Chat, key = "showButton", label = "Copy button", kind = "toggle" })
                end
            end
        end
        return ownSettings[entry.opts.id or false] or {}
    end

    local function SettingRow(parent, item)
        -- (A label may change with another setting - Rows or Columns with the
        -- orientation: a function, read again as the menu refreshes.)
        local label = item.label
        local row = Row(parent, type(label) == "function" and label() or label)
        if type(label) == "function" then row.labelOf = label end
        local function Get() return item.module.db and item.module.db[item.key] end
        local function Set(value)
            -- An unsaved change of Unlock Mode's, like a move.
            Core.NoteEdit(item.module, item.key)
            item.module.db[item.key] = value
            if item.module.Refresh then item.module.Refresh() end
            Core.RefreshOptions()
            if row.control and row.control.Refresh then row.control.Refresh() end
        end
        local kind = item.kind
        if kind == "toggle" then
            row.control = W.Toggle(row, function() return Get() and true or false end,
                function(on) Set(on and true or false) end)
            row.control:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        elseif kind == "choice" then
            row.control = W.Dropdown(row, CONTROL, item.choices, Get, Set)
            row.control:SetHeight(ROW - 2)
            row.control:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        elseif kind == "number" then
            -- A size typed (Enter or Tab), as the options' Sizes rows had it.
            row.control = W.NumberBox(row, nil, NUMBER, Get, function(value)
                local old = Get()
                Set(value)
                if item.onChange then item.onChange(old, value) end
            end, { min = item.min, max = item.max })
            row.control:SetHeight(ROW - 2)
            row.control:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        else
            -- Its value a box beside it, typed into for an exact number (the
            -- player, 2026-10-03). A share shown as a percentage (Options.Percent)
            -- is typed as one.
            local text = item.text
            row.control = W.Slider(row, CONTROL - SLIDER_VALUE,
                { min = item.min, max = item.max, step = item.step, text = text,
                  input = true, inputWidth = SLIDER_VALUE - SLIDER_GAP, inputGap = SLIDER_GAP,
                  inputHeight = ROW - 4, scale = item.scale or (text == Options.Percent and 100 or nil) },
                Get, Set)
            row.control:SetPoint("RIGHT", row, "RIGHT", -SLIDER_VALUE, 0)
        end
        return row
    end

    local function SettingsKey(items)
        local parts = {}
        for _, item in ipairs(items) do
            parts[#parts + 1] = (item.module.key or "?") .. "." .. item.key
        end
        return table.concat(parts, "|")
    end

    -- The block for `entry`'s settings (pieces alike share one); nothing
    -- when it has none.
    local function SettingsBlock(entry)
        local items = OwnSettings(entry)
        if #items == 0 then return end
        local key = SettingsKey(items)
        menu.blocks = menu.blocks or {}
        local block = menu.blocks[key]
        if block then return block end
        block = CreateFrame("Frame", nil, menu)
        block.rows = {}
        for index, item in ipairs(items) do
            local row = SettingRow(block, item)
            row:SetPoint("TOPLEFT", block, "TOPLEFT", 0, -(index - 1) * (ROW + GAP))
            block.rows[index] = row
        end
        block.height = #items * (ROW + GAP)
        block:SetSize(MENU_INNER, block.height)
        menu.blocks[key] = block
        return block
    end

    local function ScreenChoices()
        local list = { { value = "CENTER", label = "Center" } }
        for _, edge in ipairs(Snap.SCREEN_EDGES) do list[#list + 1] = { value = edge.key, label = edge.label } end
        return list
    end

    local function BuildMenu()
        if menu then return end
        menu = NewWindow("UnlockMenu", MENU_WIDTH, 200)
        Unlock.menu = menu
        menu.title = W.Text(menu, 13, W.GOLD, true)
        menu.title:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_SIDE, -10)
        menu.title:SetWidth(MENU_INNER)
        menu.rule = W.Hairline(menu, W.FAINT, 30, MENU_SIDE, MENU_SIDE)

        local function Size(axis) return function(entry) local size = Snap.SizeOf(entry, axis); return size and Snap.Whole(size) end end
        local function SetSize(axis) return function(entry, value) Snap.SetSize(entry, axis, value) end end
        local function Extra(axis) return function(entry) return select(2, Snap.MatchOf(entry, axis)) end end
        local function SetExtra(axis) return function(entry, value) Snap.SetMatchExtra(entry, axis, value) end end
        menu.wRow = NumberRow("Width", Size("w"), SetSize("w"))
        menu.hRow = NumberRow("Height", Size("h"), SetSize("h"))
        menu.extraW = NumberRow("Extra Width", Extra("w"), SetExtra("w"))
        menu.extraH = NumberRow("Extra Height", Extra("h"), SetExtra("h"))
        menu.xRow = NumberRow("X Position",
            function(entry) local x = Snap.PositionOf(entry); return x and Snap.Whole(x) end,
            function(entry, value) Snap.MoveTo(entry, value, nil) end)
        menu.yRow = NumberRow("Y Position",
            function(entry) local _, y = Snap.PositionOf(entry); return y and Snap.Whole(y) end,
            function(entry, value) Snap.MoveTo(entry, nil, value) end)

        -- MATCH WIDTH / HEIGHT and ANCHOR: the next piece clicked is the one
        -- to match or anchor to; the menu steps aside until it is, and comes
        -- back after (Unlock.ReopenAfterPick).
        local function Pick(entry, axis)
            local pick = Snap.Picking()
            if pick and pick.entry == entry and pick.axis == axis then
                Snap.StopPicking()
            elseif Snap.StartPicking(entry, axis) then
                menu.reopen = entry
                HideQuietly(menu)
                menu.entry = nil
            end
        end
        for _, axis in ipairs({ "w", "h" }) do
            local button = MenuButton("", nil, function(entry)
                if Snap.MatchOf(entry, axis) then Snap.ClearMatch(entry, axis) else Pick(entry, axis) end
            end)
            menu[axis == "w" and "matchW" or "matchH"] = button
        end
        menu.anchor = MenuButton("Anchor", nil, function(entry)
            if Snap.AnchorOf(entry) and not Snap.IsScreenEdge(Snap.AnchorOf(entry)) then
                Snap.Unanchor(entry)
            else
                Pick(entry, "anchor")
            end
        end)

        menu.anchored = Row(menu, "Anchored to")
        menu.anchored.value = W.Text(menu.anchored, 12, ANCHORED)
        menu.anchored.value:SetPoint("RIGHT", menu.anchored, "RIGHT", 0, 0)
        menu.anchored.value:SetJustifyH("RIGHT")
        menu.offsetX = NumberRow("Offset X",
            function(entry) local _, _, x = Snap.AnchorOf(entry); return x and Snap.Whole(x) end,
            function(entry, value) Snap.SetAnchorOffset(entry, value, nil) end)
        menu.offsetY = NumberRow("Offset Y",
            function(entry) local _, _, _, y = Snap.AnchorOf(entry); return y and Snap.Whole(y) end,
            function(entry, value) Snap.SetAnchorOffset(entry, nil, value) end)
        -- (The number rows, refreshed together as the menu is.)
        menu.numberRows = { menu.wRow, menu.hRow, menu.extraW, menu.extraH, menu.xRow, menu.yRow,
                            menu.offsetX, menu.offsetY }

        menu.screen = Row(menu, "Relative to Screen")
        menu.screen.control = W.Dropdown(menu.screen, 96, ScreenChoices(), function()
            local to = Snap.AnchorOf(MenuEntry())
            return Snap.IsScreenEdge(to) and to or "CENTER"
        end, function(value)
            local entry = MenuEntry()
            if not entry then return end
            if value == "CENTER" then Snap.ClearScreenAnchor(entry) else Snap.AnchorToScreen(entry, value) end
            Unlock.RefreshMenu()
        end)
        menu.screen.control:SetHeight(ROW - 2)
        menu.screen.control:SetPoint("RIGHT", menu.screen, "RIGHT", 0, 0)

        menu.centre = MenuButton("Center on Screen", nil, function(entry) Snap.CentreOnScreen(entry) end)
        menu.reset = MenuButton("Reset Position", nil, function(entry) Snap.ResetPlace(entry) end)
        menu.settingsRule = W.Flat(menu, "ARTWORK", W.FAINT)
        menu.settingsRule:SetSize(MENU_INNER, W.Pixel(menu))

        -- Dragged by anywhere but its controls; kept there for the session.
        menu:SetMovable(true)
        menu:RegisterForDrag("LeftButton")
        menu:SetScript("OnDragStart", function(self) self:StartMoving() end)
        menu:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            self:SetUserPlaced(false)
            self.dragged = true
            W.SnapBorders()
        end)

        menu.elapsed = 0
        menu:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed < REFRESH_EVERY then return end
            self.elapsed = 0
            Unlock.RefreshMenu()
        end)
        menu:HookScript("OnHide", function(self)
            W.ClosePopup()
            self.entry = nil
        end)
        -- A click on its own piece is that piece's (Snap.Clicked: it closes).
        ShutOnClickAway(menu, function()
            local entry = MenuEntry()
            return { entry and Snap.movers[entry] }
        end)
    end

    -- Which rows the menu has for `entry` now, in one string: laid out again
    -- when it changes.
    local function Shape(entry)
        return table.concat({
            tostring(Snap.SizeOf(entry, "w") ~= nil), tostring(Snap.MatchOf(entry, "w") ~= nil),
            tostring(Snap.SizeOf(entry, "h") ~= nil), tostring(Snap.MatchOf(entry, "h") ~= nil),
            tostring(Snap.AnchorOf(entry) ~= nil), tostring(Snap.CanReset(entry)),
            tostring(entry.opts.id ~= nil),
            SettingsKey(OwnSettings(entry)),
        }, ",")
    end

    local AXES = { "w", "h" }

    local function LayOutMenu()
        local entry = MenuEntry()
        local y = 38
        local function Put(region, height, shown)
            if shown == false then
                region:Hide()
                return
            end
            region:ClearAllPoints()
            region:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_SIDE, -y)
            region:Show()
            y = y + height
        end
        local step = ROW + GAP
        for _, axis in ipairs(AXES) do
            local sized = Snap.SizeOf(entry, axis) ~= nil
            local matched = Snap.MatchOf(entry, axis) ~= nil
            Put(axis == "w" and menu.wRow or menu.hRow, step, sized and not matched)
            Put(axis == "w" and menu.extraW or menu.extraH, step, sized and matched)
        end
        Put(menu.matchW, step, Snap.SizeOf(entry, "w") ~= nil)
        Put(menu.matchH, step, Snap.SizeOf(entry, "h") ~= nil)
        Put(menu.xRow, step)
        Put(menu.yRow, step)
        Put(menu.anchor, step, entry.opts.id ~= nil)
        local anchored = Snap.AnchorOf(entry) ~= nil
        Put(menu.anchored, step, anchored)
        Put(menu.offsetX, step, anchored)
        Put(menu.offsetY, step, anchored)
        Put(menu.screen, step)
        Put(menu.centre, step)
        Put(menu.reset, step, Snap.CanReset(entry))
        local block = SettingsBlock(entry)
        for _, other in pairs(menu.blocks or {}) do
            if other ~= block then other:Hide() end
        end
        menu.block = block
        if block then
            y = y + 2
            Put(menu.settingsRule, 8)
            Put(block, block.height)
        else
            menu.settingsRule:Hide()
        end
        menu:SetHeight(y + 6)
        menu.shape = Shape(entry)
    end

    function Unlock.RefreshMenu()
        local entry = MenuEntry()
        if not (menu and menu:IsShown() and entry) then return end
        if Shape(entry) ~= menu.shape then LayOutMenu() end
        menu.title:SetText(Snap.NameOf(entry))
        for _, row in ipairs(menu.numberRows) do
            if row:IsShown() then ShowNumber(row.box) end
        end
        local to = Snap.AnchorOf(entry)
        if to then menu.anchored.value:SetText(Snap.TargetName(to)) end
        for _, axis in ipairs(AXES) do
            local button = axis == "w" and menu.matchW or menu.matchH
            local word = axis == "w" and "Width" or "Height"
            local matched = Snap.MatchOf(entry, axis)
            W.SetLabel(button, matched and ("Unmatch " .. word .. ": " .. Snap.TargetName(matched)) or ("Match " .. word))
            W.SetStyle(button, matched and "active" or nil)
        end
        local onPiece = to and not Snap.IsScreenEdge(to)
        W.SetLabel(menu.anchor, onPiece and "Remove Anchor" or "Anchor")
        if onPiece then W.SetTextColour(menu.anchor.label, REMOVE) else W.PaintButton(menu.anchor) end
        menu.screen.control.Refresh()
        if menu.block then
            for _, row in ipairs(menu.block.rows) do
                -- (A number being typed is left as it is.)
                if not (row.control.HasFocus and row.control:HasFocus()) then row.control.Refresh() end
                if row.labelOf then row.label:SetText(row.labelOf()) end
            end
        end
    end

    -- A piece clicked or right-clicked: its menu, beside it.
    function Snap.OpenCog(entry, mover)
        if not entry or InCombatLockdown() then return end
        BuildMenu()
        menu.reopen = nil
        menu.entry = entry
        menu.title:SetText(Snap.NameOf(entry))
        LayOutMenu()
        -- FREE ON THE SCREEN (the player, 2026-10-03: "these options doesnt
        -- have to be connected to the element"): centred in the right half of
        -- the screen, both ways (the player, later the same day: not beside
        -- the piece, and not against the screen's edge), so a piece that
        -- changes size (an action bar's rows) never takes it along - and
        -- where it was dragged to from then on.
        if not menu.dragged then
            menu:ClearAllPoints()
            menu:SetPoint("CENTER", UIParent, "CENTER", GetScreenWidth() / 4, 0)
        end
        menu:Show()
        menu:Raise()
        Unlock.RefreshMenu()
    end

    function Unlock.CloseMenu() HideQuietly(menu) end

    -- A click on a piece (not a drag): selected and its menu opened - or,
    -- its menu open already, let go of.
    function Snap.Clicked(entry, mover, wasSelected)
        if wasSelected and menu and menu:IsShown() and menu.entry == entry then
            Snap.Deselect()
            return
        end
        Snap.Select(entry)
        Snap.OpenCog(entry, mover)
    end

    -- A pick started from the menu, over: the menu back, for the same piece
    -- still selected - unless the anchor's side is being asked first.
    local function ReopenAfterPick()
        local entry = menu and menu.reopen
        if not entry or Snap.Picking() then return end
        menu.reopen = nil
        if Snap.SelectedEntry() == entry and Core.IsUnlocked() then Snap.OpenCog(entry) end
    end

    ---------------------------------------------------------------------------
    -- UNSAVED CHANGES (EllesmereUI's): Exit with something changed.
    --
    -- Leaving for the game's Edit Mode (a handover box), its two buttons
    -- are secure ones too: what they do first, then the game's own
    -- /editmode - the one way into the game's Edit Mode that leaves the
    -- game's code untainted.
    ---------------------------------------------------------------------------

    local ask
    local secureAsk = {}        -- "discard" / "save" -> the secure button over it

    -- Leaving for the game's Edit Mode: the options window not brought back.
    local function Handover()
        fromOptions = false
    end

    local function PlaceOver(button, under)
        local left, top = under:GetLeft(), under:GetTop()
        if not (left and top) then return false end
        local k = under:GetEffectiveScale() / UIParent:GetEffectiveScale()
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * k, top * k)
        button:SetSize(under:GetWidth() * k, under:GetHeight() * k)
        return true
    end

    -- A secure button running /editmode, `before` first.
    local function EditModeButton(before)
        local button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
        button:RegisterForClicks("LeftButtonUp")
        button:SetAttribute("useOnKeyDown", false)
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", "/editmode")
        -- Hidden only once its click is done: hidden in the middle of it, its
        -- macro might never run.
        button:SetScript("PreClick", function(self, mouse)
            self.clicking = true
            before(self, mouse)
        end)
        button:SetScript("PostClick", function(self)
            self.clicking = false
            if self.Done then self.Done(self) end
        end)
        button:Hide()
        if RegisterStateDriver then RegisterStateDriver(button, "visibility", "[combat] hide") end
        return button
    end

    local function UpdateSecureAsk()
        if InCombatLockdown() then return end
        local handover = ask and ask:IsShown() and ask.after == Handover
        for key, button in pairs(secureAsk) do
            local under = ask and ask[key]
            local wanted = handover and under and PlaceOver(button, under)
            if wanted then button:SetFrameLevel(under:GetFrameLevel() + 20) end
            if wanted or not button.clicking then button:SetShown(wanted and true or false) end
        end
    end

    local function BuildAsk()
        if ask then return end
        ask = NewWindow("Unsaved", 470, 132, TOP_STRATA)
        ask:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
        Unlock.ask = ask
        ask.title = W.Text(ask, 15, W.GOLD, true)
        ask.title:SetPoint("TOP", ask, "TOP", 0, -16)
        ask.title:SetJustifyH("CENTER")
        ask.title:SetText("Unsaved Changes")
        ask.text = W.Text(ask, 12, W.TEXT, false, 320)
        ask.text:SetPoint("TOP", ask.title, "BOTTOM", 0, -10)
        ask.text:SetJustifyH("CENTER")
        ask.text:SetText("You have unsaved position changes.\nWhat would you like to do?")
        local function Answer(save)
            local after = ask.after
            ask.after = nil
            ask:Hide()
            if save then
                Core.CommitEditMode()
            else
                Core.RevertEditMode()
            end
            Core.SetUnlocked(false)
            if after then after() end
        end
        -- CONTINUE (the player, 2026-10-03: "in case user changes their
        -- mind"): the question away, Unlock Mode still open, every change
        -- still there and unsaved - as Esc does.
        ask.continue = W.Button(ask, "Continue", 140, function() ask:Hide() end)
        ask.continue:SetPoint("BOTTOM", ask, "BOTTOM", 0, 16)
        ask.discard = W.Button(ask, "Exit Without Saving", 140, function() Answer(false) end)
        ask.discard:SetPoint("RIGHT", ask.continue, "LEFT", -8, 0)
        ask.save = W.Button(ask, SAVE_EXIT, 140, function() Answer(true) end, "active")
        ask.save:SetPoint("LEFT", ask.continue, "RIGHT", 8, 0)
        ask.Answer = Answer
        -- The secure buttons over its own: Exit Without Saving and Save when
        -- leaving for the game's Edit Mode.
        secureAsk.discard = EditModeButton(function() Answer(false) end)
        secureAsk.save = EditModeButton(function() Answer(true) end)
        for _, button in pairs(secureAsk) do
            button:SetFrameStrata(TOP_STRATA)
            button.Done = function() UpdateSecureAsk() end
        end
        Unlock.secureAsk = secureAsk
        ask:HookScript("OnHide", function(self)
            if not self.quiet then self.after = nil end
            UpdateSecureAsk()
        end)
        -- Put over the buttons again while it shows: the first time it opens
        -- its buttons have no place to be read yet.
        ask.elapsed = 0
        ask:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed < 0.1 then return end
            self.elapsed = 0
            UpdateSecureAsk()
        end)
    end

    -- `after`: what runs once Unlock Mode has closed (Handover: the game's
    -- Edit Mode, through the secure buttons).
    function Core.AskUnsaved(after)
        BuildAsk()
        ask.after = after
        ask:Show()
        ask:Raise()
        UpdateSecureAsk()
    end

    function Core.DropUnsavedQuestion()
        if ask then ask:Hide() end
    end

    ---------------------------------------------------------------------------
    -- THE GAME'S OWN FRAMES (EllesmereUI's Blizzard movers): a box over each
    -- of the game's Edit Mode frames on screen - its name in it; under the
    -- mouse, "Edit from Blizzard" under the name. A click closes
    -- Unlock Mode (asking first when something is unsaved) and opens the
    -- game's own Edit Mode.
    --
    -- The click that opens it is the game's /editmode, run by a secure
    -- button: the addon's own code opening Edit Mode would carry its taint
    -- into the game's unit frames. One secure button, put over whichever box
    -- is under the mouse; never in combat (Unlock Mode is put away then), and
    -- not while something is unsaved: then the box itself takes the click and
    -- asks (UNSAVED CHANGES), whose buttons are secure in turn.
    ---------------------------------------------------------------------------

    local BLIZZ_LEVEL = Snap.MOVER_LEVEL - 100
    local BOX_LINE = { Style.GOLD[1], Style.GOLD[2], Style.GOLD[3], 0.6 }
    local BOX_LINE_OVER = { 1, 1, 1, 0.9 }
    local boxes = {}            -- system -> its box
    Unlock.boxes = boxes
    local hiddenBoxes = {}      -- Shift+Right-clicked: hidden until Unlock Mode closes
    local seen = {}             -- system -> true: boxed this frame (LayOutBoxes)
    local handover              -- the secure button
    local hoveredBox

    -- Closed (asked first when something is unsaved), then the game's Edit
    -- Mode. From the secure button nothing is unsaved (else it is not
    -- shown): closed at once.
    local function Leave()
        Handover()
        Core.RequestClose(false, Handover)
    end

    local function PickRefused(name)
        local pick = Snap.Picking()
        if not pick then return false end
        Snap.StopPicking()
        local why
        if pick.axis == "anchor" then
            why = "Elements cannot be anchored to\n" .. name
        elseif pick.axis == "snaptarget" then
            why = "Elements cannot snap to\n" .. name
        else
            why = "Elements cannot size match to\n" .. name
        end
        Snap.Refuse(pick.entry, why)
        return true
    end

    local function NewBox(system)
        local box = CreateFrame("Frame", nil, UIParent)
        box:SetFrameStrata(Snap.STRATA)
        box:SetFrameLevel(BLIZZ_LEVEL)
        box:EnableMouse(true)
        box:Hide()
        box.system = system
        local bg = Style.WINDOW_BACKGROUND
        box.bg = box:CreateTexture(nil, "BACKGROUND")
        box.bg:SetAllPoints(box)
        box.bg:SetColorTexture(bg[1], bg[2], bg[3], 0.95)
        box.outline = W.Border(box, BOX_LINE)
        box.label = W.Text(box, 10, { 1, 1, 1, 0.75 })
        box.label:SetPoint("CENTER", box, "CENTER", 0, 0)
        box.label:SetJustifyH("CENTER")
        box.action = W.Text(box, 9, { Style.GOLD[1], Style.GOLD[2], Style.GOLD[3], 1 })
        box.action:SetPoint("TOP", box.label, "BOTTOM", 0, -3)
        box.action:SetJustifyH("CENTER")
        box.action:SetText("Edit from Blizzard")
        box.action:Hide()
        box:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" then
                if IsShiftKeyDown and IsShiftKeyDown() then
                    hiddenBoxes[system] = true
                    self:Hide()
                end
                return
            end
            if button ~= "LeftButton" then return end
            if PickRefused(self.name or "") then return end
            -- (Without the secure button over it - something unsaved, or
            -- not ready yet: asked, or closed, then the game's Edit Mode.)
            Leave()
        end)
        boxes[system] = box
        return box
    end

    local function Handover_Button()
        if handover then return handover end
        handover = EditModeButton(Leave)
        handover:SetFrameStrata(Snap.STRATA)
        -- Shift+Right-click hides the box under it, as on any mover.
        handover:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        handover:SetScript("PreClick", function(self, mouse)
            self.clicking = true
            if mouse == "RightButton" then
                if IsShiftKeyDown and IsShiftKeyDown() and self.box then
                    hiddenBoxes[self.box.system] = true
                    self.box:Hide()
                end
                -- A right click runs no macro.
                self:SetAttribute("type", nil)
                return
            end
            self:SetAttribute("type", "macro")
            Leave()
        end)
        handover:SetScript("PostClick", function(self)
            self.clicking = false
            if InCombatLockdown() then return end
            self:SetAttribute("type", "macro")
            if not Core.IsUnlocked() then
                self.box = nil
                self:Hide()
            end
        end)
        Unlock.handover = handover
        return handover
    end

    -- One of our own movers under the mouse: it is what is clicked.
    local function OwnMoverUnderMouse()
        for _, mover in pairs(Snap.movers) do
            if mover:IsShown() and mover:IsMouseOver() then return true end
        end
        return false
    end

    -- Every frame while Unlock Mode is open (Snap.OnDrive): so each box is
    -- only placed, named and lit again when that changed.
    local function LayOutBoxes()
        for system in pairs(seen) do seen[system] = nil end
        local on = Core.IsUnlocked() and not Snap.Previewing()
        hoveredBox = nil
        if on then
            for _, system in ipairs(Snap.GameSystems()) do
                local shape = not hiddenBoxes[system] and Snap.SystemBox(system)
                if shape then
                    local box = boxes[system] or NewBox(system)
                    local width, height = shape.r - shape.l, shape.t - shape.b
                    if box.atL ~= shape.l or box.atB ~= shape.b or box.atW ~= width or box.atH ~= height then
                        box.atL, box.atB, box.atW, box.atH = shape.l, shape.b, width, height
                        box:ClearAllPoints()
                        box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", shape.l, shape.b)
                        box:SetSize(width, height)
                    end
                    local name = Snap.SystemName(system)
                    if box.name ~= name then
                        box.name = name
                        box.label:SetText(name)
                    end
                    box:Show()
                    local over = box:IsMouseOver() and not OwnMoverUnderMouse()
                    if over and not hoveredBox then hoveredBox = box end
                    seen[system] = true
                end
            end
            for _, box in pairs(boxes) do
                local over = box == hoveredBox and not Snap.Picking()
                if box.lit ~= over then
                    box.lit = over
                    W.TintBorder(box.outline, over and BOX_LINE_OVER or BOX_LINE)
                end
                -- "Edit from Blizzard" only where it fits in the box, with the
                -- name over it (the player, 2026-10-03).
                local fits = (box:GetWidth() or 0) >= (box.action:GetStringWidth() or 0) + 8
                    and (box:GetHeight() or 0) >= (box.label:GetStringHeight() or 10)
                        + (box.action:GetStringHeight() or 9) + 10
                local hint = over and fits
                if box.hint ~= hint then
                    box.hint = hint
                    box.label:ClearAllPoints()
                    box.label:SetPoint("CENTER", box, "CENTER", 0, hint and 5 or 0)
                    box.action:SetShown(hint)
                end
            end
        end
        for system, box in pairs(boxes) do
            if not seen[system] then box:Hide() end
        end
        -- The secure button over the box under the mouse.
        if InCombatLockdown() then return end
        local wanted = hoveredBox ~= nil and not Snap.Picking() and not Core.EditModePending()
            and not (ask and ask:IsShown())
        local button = (wanted or handover) and Handover_Button()
        if not button then return end
        if wanted and PlaceOver(button, hoveredBox) then
            button.box = hoveredBox
            button:SetFrameLevel(BLIZZ_LEVEL + 1)
            button:Show()
        elseif not button.clicking then
            button.box = nil
            button:Hide()
        end
    end

    local function HideBoxes()
        for system in pairs(hiddenBoxes) do hiddenBoxes[system] = nil end
        for _, box in pairs(boxes) do box:Hide() end
        hoveredBox = nil
        if handover and not InCombatLockdown() and not handover.clicking then
            handover.box = nil
            handover:Hide()
        end
    end

    ---------------------------------------------------------------------------
    -- THE DIMMER (EllesmereUI's overlay): the screen a little darker under
    -- the movers - more while a piece is being picked.
    ---------------------------------------------------------------------------

    local DIM, DIM_PICK = 0.20, 0.50
    local dimmer

    local function Dimmer()
        if dimmer then return dimmer end
        dimmer = CreateFrame("Frame", Core.ADDON_NAME .. "UnlockDimmer", UIParent)
        dimmer:SetAllPoints(UIParent)
        dimmer:SetFrameStrata(Snap.STRATA)
        dimmer:SetFrameLevel(1)
        dimmer:EnableMouse(false)
        dimmer.fill = dimmer:CreateTexture(nil, "BACKGROUND")
        dimmer.fill:SetAllPoints(dimmer)
        dimmer.fill:SetColorTexture(0.02, 0.03, 0.04, 1)
        dimmer.level = DIM
        dimmer.fill:SetAlpha(DIM)
        dimmer:Hide()
        Unlock.dimmer = dimmer
        return dimmer
    end

    -- At once: nothing animated in Unlock Mode.
    local function FadeDimmer()
        if not dimmer then return end
        -- (None while previewing.)
        local previewing = Snap.Previewing()
        if dimmer:IsShown() == previewing then dimmer:SetShown(not previewing) end
        if previewing then return end
        local wanted = Snap.Picking() and DIM_PICK or DIM
        if dimmer.level ~= wanted then
            dimmer.level = wanted
            dimmer.fill:SetAlpha(wanted)
        end
    end

    ---------------------------------------------------------------------------
    -- ESC, a step at a time (EllesmereUI's): a menu open - shut; a piece
    -- being picked - stopped; else Unlock Mode left (asking when something
    -- is unsaved). Every other key goes on to the game.
    ---------------------------------------------------------------------------

    local esc

    local function Escape()
        -- Quick Keybind Mode: left as its Cancel leaves it.
        local keybinds = Core.Options.Keybinds
        if keybinds and keybinds.IsOpen() then
            keybinds.Close(false)
            return
        end
        if ask and ask:IsShown() then
            ask:Hide()
            return
        end
        local list = W.Popup()
        if list:IsShown() then
            W.ClosePopup()
            return
        end
        if menu and menu:IsShown() then
            menu:Hide()
            return
        end
        if Snap.Picking() then
            Snap.StopPicking()
            return
        end
        -- Previewing: back to Unlock Mode's look first.
        if Snap.Previewing() then
            Unlock.SetPreview(false)
            return
        end
        Core.RequestClose(false)
    end
    Unlock.Escape = Escape

    local function Esc()
        if esc then return esc end
        esc = CreateFrame("Frame", Core.ADDON_NAME .. "UnlockEsc", UIParent)
        esc:SetFrameStrata(TOP_STRATA)
        esc:EnableMouse(false)
        esc:SetScript("OnKeyDown", function(self, key)
            if InCombatLockdown() then return end
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                Escape()
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)
        esc:SetScript("OnKeyUp", function(self)
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
        end)
        Unlock.esc = esc
        return esc
    end

    ---------------------------------------------------------------------------
    -- A CLICK ON EMPTY SPACE lets go of the selected piece (the player,
    -- 2026-10-03) - on nothing of Unlock Mode's: no piece, not the bar, its
    -- menu, a dropdown's list or a question. Not while dragging or picking.
    -- Listened for only while Unlock Mode is open (Core.PlacingChanged).
    ---------------------------------------------------------------------------

    local function OverUnlockMode()
        for _, mover in pairs(Snap.movers) do
            if mover:IsShown() and mover:IsMouseOver() then return true end
        end
        for _, frame in ipairs({ bar, menu, W.Popup(), ask }) do
            if frame and frame:IsShown() and frame:IsMouseOver() then return true end
        end
        return false
    end

    local away = CreateFrame("Frame")
    away:SetScript("OnEvent", function()
        if not Core.IsUnlocked() or not Snap.Selected() then return end
        if Snap.Previewing() or Snap.IsDragging() or Snap.Picking() then return end
        if OverUnlockMode() then return end
        Snap.Deselect()
    end)

    ---------------------------------------------------------------------------
    -- KEPT UP while Unlock Mode is open (Core\Snap.lua's driver calls this
    -- every frame), and whatever changed.
    ---------------------------------------------------------------------------

    function Snap.OnDrive()
        FadeDimmer()
        LayOutBoxes()
    end

    -- The selection, a pick, a match or an anchor changed.
    function Snap.SelectionChanged()
        ReopenAfterPick()
        if menu and menu:IsShown() then
            local entry = Snap.SelectedEntry()
            if entry ~= menu.entry then
                menu:Hide()
            else
                Unlock.RefreshMenu()
            end
        end
    end

    function Core.EditModeChanged()
        if bar and bar:IsShown() then Unlock.RefreshBar() end
    end

    -- Opened or closed (DogsForeverUI.lua: Core.SetUnlocked, a fight putting
    -- it away and bringing it back). The options make way for Unlock Mode,
    -- coming back after - not after a fight's suspension, nor when it closed
    -- for the game's Edit Mode.
    function Core.PlacingChanged(unlocked)
        -- Opened or closed: never still previewing.
        if Snap.Previewing() then
            Snap.SetPreview(false)
            if Core.UpdateGrid then Core.UpdateGrid() end
        end
        if unlocked then
            if Options.IsShown() then
                fromOptions = true
                Options.Close()
            end
            BuildBar()
            PlaceBar()
            Unlock.RefreshBar()
            bar:Show()
            Dimmer().level = DIM
            dimmer.fill:SetAlpha(DIM)
            dimmer:Show()
            Esc():Show()
            esc:EnableKeyboard(not InCombatLockdown())
            away:RegisterEvent("GLOBAL_MOUSE_DOWN")
        else
            away:UnregisterEvent("GLOBAL_MOUSE_DOWN")
            -- Quick Keybind Mode with it, its keys kept.
            if Core.Options.Keybinds then Core.Options.Keybinds.Close(true, false) end
            HideQuietly(bar)
            HideQuietly(menu)
            W.ClosePopup()
            if dimmer then dimmer:Hide() end
            -- (Not a protected frame: put away in combat too.)
            if esc then
                esc:EnableKeyboard(false)
                esc:Hide()
            end
            HideBoxes()
            if Core.UnlockSuspended() then return end
            if ask and ask:IsShown() then HideQuietly(ask) end
            UpdateSecureAsk()
            if fromOptions then
                fromOptions = false
                Options.Open()
            end
        end
    end

    -- Combat over: the secure buttons put right again.
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function()
        UpdateSecureAsk()
        if not Core.IsUnlocked() then HideBoxes() end
    end)
end
