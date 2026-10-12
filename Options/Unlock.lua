-- Unlock Mode's windows, EllesmereUI's in the addon's look: the bar, a piece's
-- menu, Unsaved Changes, the handover boxes over the game's own frames, the
-- dimmer and Esc. The movers are Core\Snap.lua's; open/save is DogsForeverUI.lua's.

local Unlock = {}
DogsForeverUI.Options.Unlock = Unlock

do -- private scope
    local Core = DogsForeverUI
    local Options = Core.Options
    local Snap = Core.Snap
    local Style = Core.Style
    local W = Core.Widgets

    local STRATA = "FULLSCREEN"             -- over the movers (Snap.STRATA)
    local TOP_STRATA = "FULLSCREEN_DIALOG"  -- the questions, over everything
    local ANCHORED = { 1, 0.7, 0.3, 0.85 }
    local REMOVE = { 0.9, 0.3, 0.3, 1 }
    -- Each axis of a piece's size, and its rows of the menu.
    local AXES = {
        { axis = "w", word = "Width",  row = "wRow", extra = "extraW", match = "matchW" },
        { axis = "h", word = "Height", row = "hRow", extra = "extraH", match = "matchH" },
    }

    local fromOptions = false               -- the options were open when Unlock Mode opened
    local bar, menu, ask

    local function HideQuietly(frame)
        if frame and frame:IsShown() then
            frame.quiet = true
            frame:Hide()
            frame.quiet = false
        end
    end

    -- `fn` every tenth of a second while `frame` shows.
    local function Every(frame, fn)
        local elapsed = 0
        frame:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed < 0.1 then return end
            elapsed = 0
            fn()
        end)
    end

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

    -- Dragged by anywhere but its controls; kept there until the UI reloads.
    local function Draggable(frame)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        frame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            self:SetUserPlaced(false)
            self.dragged = true
            W.SnapBorders()
        end)
    end

    ---------------------------------------------------------------------------
    -- The bar along the top: Preview, Snap Elements, Exit, Save & Exit
    ---------------------------------------------------------------------------

    local BAR_WIDTH, BAR_HEIGHT = 640, 64
    local BAR_SIDE = 16
    local SAVE_EXIT = "Save & Exit"
    local HINT = "Use arrow keys to move selected element 1px any direction. Shift+Right Click to temporarily hide overlay"
    Unlock.BAR_GAP = 8

    local function RefreshBar()
        if not bar then return end
        for _, control in ipairs(bar.controls) do control.Refresh() end
        W.SetStyle(bar.save, Core.EditModePending() and "active" or nil)
    end

    -- One of the bar's switches changed (and the tests' way to change one).
    function Unlock.Set(key, value)
        Snap.db[key] = value
        RefreshBar()
    end

    -- Preview: the movers, boxes, grid, dimmer and menu gone, the frames alone.
    function Unlock.SetPreview(on)
        if on then
            HideQuietly(menu)
            W.ClosePopup()
        end
        Snap.SetPreview(on)
        Core.UpdateGrid()
        Snap.OnDrive()
        RefreshBar()
    end

    -- Centred, just below the micro menu's place, until dragged.
    -- Centred BAR_GAP under the micro menu's default top-edge place (the Keybinds window too).
    function Unlock.PlaceUnderMicro(frame)
        local below = Unlock.BAR_GAP
        local micro = Snap.EntryById("micro")
        local box = micro and Snap.Box(micro)
        if box then below = below + (box.t - box.b) end
        frame:ClearAllPoints()
        frame:SetPoint("TOP", UIParent, "TOP", 0, -below)
    end

    local function PlaceBar()
        if not bar.dragged then Unlock.PlaceUnderMicro(bar) end
    end

    -- A switch with its name after it (clickable too), left of `right`.
    local function Switch(name, right, get, set)
        local text = W.Text(bar, 12, W.TEXT)
        text:SetPoint("RIGHT", right, "LEFT", -22, 0)
        text:SetText(name)
        local toggle = W.Toggle(bar, get, set)
        toggle:SetPoint("RIGHT", text, "LEFT", -8, 0)
        local hit = CreateFrame("Button", nil, bar)
        hit:SetPoint("TOPLEFT", text, "TOPLEFT", -2, 4)
        hit:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", 2, -4)
        hit:SetScript("OnClick", function() toggle:Click() end)
        bar.controls[#bar.controls + 1] = toggle
        return toggle, 22 + (text:GetStringWidth() or 0) + 8 + W.TOGGLE_WIDTH
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
        local snapWidth, previewWidth
        bar.snap, snapWidth = Switch("Snap Elements", bar.exit, Snap.Rules,
            function(on) Unlock.Set("snap", on and true or false) end)
        bar.preview, previewWidth = Switch("Preview", bar.snap, Snap.Previewing, Unlock.SetPreview)

        bar.hint = W.Text(bar, 11, W.MUTED)
        bar.hint:SetPoint("TOPLEFT", bar, "TOPLEFT", BAR_SIDE, -42)
        bar.hint:SetText(HINT)
        -- Wide enough for the hint, and for the title beside the buttons and switches.
        local row = 112 + 8 + 80 + snapWidth + previewWidth
        bar:SetWidth(math.max(BAR_WIDTH, (bar.hint:GetStringWidth() or 0) + 2 * BAR_SIDE,
            (bar.title:GetStringWidth() or 0) + 24 + row + 2 * BAR_SIDE))

        Draggable(bar)
        bar:SetScript("OnHide", function() W.ClosePopup() end)
    end

    ---------------------------------------------------------------------------
    -- A piece's menu, opened by clicking it: size or Match Width / Height,
    -- place, Anchor, Relative to Screen, Center, Reset - then its own settings
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

    local function MenuEntry() return menu and menu.entry end

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
        return row
    end

    local function MenuButton(text, onClick)
        local button = W.Button(menu, text, MENU_INNER, function()
            local entry = MenuEntry()
            if entry then onClick(entry) end
            Unlock.RefreshMenu()
        end)
        button:SetHeight(ROW - 2)
        return button
    end

    -- A piece's own settings: the addon's that are about it, changed at once.
    local ownSettings           -- [piece id] = its items

    local function Whole(value) return tostring(math.floor(value + 0.5)) end
    local function WholePercent(value) return Whole(value) .. "%" end

    local function BuildOwnSettings()
        ownSettings = {}
        local function Add(id, module, key, label, kind, item)
            item = item or {}
            item.module, item.key, item.label, item.kind = module, key, label, kind
            local list = ownSettings[id] or {}
            ownSettings[id] = list
            list[#list + 1] = item
        end
        local function Toggle(id, module, key, label) Add(id, module, key, label, "toggle") end
        local function Choice(id, module, key, label, choices) Add(id, module, key, label, "choice", { choices = choices }) end
        local function Number(id, module, key, label, max) Add(id, module, key, label, "number", { min = 1, max = max or 400 }) end
        local function Slider(id, module, key, label, min, max, step, text)
            Add(id, module, key, label, "slider", { min = min, max = max, step = step, text = text })
        end
        local function Layer(id, module, key) Choice(id, module, key or "frameStrata", "Layer", Options.STRATA) end
        local function Padding(id, module)
            Slider(id, module, "textPadding", "Text padding", 0, Style.MAX_TEXT_PADDING, 0.01, Options.Percent)
        end

        local Frames, Menus, Castbar, Cooldowns = Core.Frames, Core.Menus, Core.Castbar, Core.Cooldowns
        local Auras = Frames.UnitAuras
        for _, unit in ipairs({ "player", "target", "focus", "targettarget", "pet", "party" }) do
            for _, aura in ipairs(Auras.UNITS) do
                -- By the frame it is on: the party's Show self row is the player's unit on a party frame.
                if (aura.plate or aura.unit) == unit or (unit == "party" and aura.key == "partyAuras") then
                    Choice(unit, Frames, aura.key, "Auras", aura.choices or Auras.CHOICES)
                    break
                end
            end
            if unit == "target" or unit == "focus" then Toggle(unit, Frames, "showCastbar", "Castbar") end
            Toggle(unit, Frames, "showHealthText", "Health text")
            Toggle(unit, Frames, "showPowerText", "Resource text")
            Toggle(unit, Frames, "classColors", "Class colours")
            if unit == "player" then Toggle(unit, Frames, "playerDispel", "Dispel marks") end
            if unit == "party" then
                Choice(unit, Frames, "partySort", "Sort by", Frames.UnitPlate.SORTS)
                Toggle(unit, Frames, "partyShowSelf", "Show self")
                Toggle(unit, Frames, "partyShowPets", "Show pets")
                Number(unit, Frames, "partyRaidHealth", "Health height")
                Number(unit, Frames, "partyPower", "Power height")
                Layer(unit, Frames, "partyStrata")
            else
                -- The unit frames share these.
                Number(unit, Frames, "barWidth", "Width", 4000)
                Number(unit, Frames, "barHeight", "Health height")
                Number(unit, Frames, "powerHeight", "Power height")
                Number(unit, Frames, "castbarHeight", "Cast height")
                Padding(unit, Frames)
                Layer(unit, Frames)
            end
        end
        Padding("castbar", Castbar)
        Layer("castbar", Castbar)
        Number("swing", Castbar, "swingHeight", "Height")
        Layer("swing", Castbar, "swingStrata")
        for id, module in pairs({ fsr = Core.FiveSecondRule, combo = Core.ComboPoints, xp = Core.XPBar,
                                  cooldowns = Cooldowns, threat = Core.Threat }) do
            Layer(id, module)
        end
        Choice("cooldowns", Cooldowns, "growDirection", "Bars grow", Cooldowns.GROW)
        Toggle("cooldowns", Cooldowns, "showTooltipIDs", "IDs on tooltips")
        Choice("toasts", Core.LootToasts, "growDirection", "Toasts grow", Cooldowns.GROW)
        Toggle("micro", Menus, "quietMicroMenu", "Auto-hide")
        Toggle("xp", Menus, "fadeXPBar", "Auto-hide")

        local Bars, fades = Core.ActionBars, {}
        for _, info in ipairs(Menus.ActionBars.LIST) do fades[info.label] = info.key end
        for _, info in ipairs(Bars.BARS) do
            local k, id = info.key, info.id or info.key
            Slider(id, Bars, k .. "Buttons", "Buttons", 1, info.count, 1, Whole)
            Choice(id, Bars, k .. "Orientation", "Orientation", Bars.ORIENTATION)
            if info.grow then Choice(id, Bars, k .. "Grow", "Grow", Bars.GROW) end
            -- Rows or Columns with the orientation: read again as the menu refreshes.
            Slider(id, Bars, k .. "Rows", function()
                return Bars.db[k .. "Orientation"] == "vertical" and "Columns" or "Rows"
            end, 1, info.count, 1, Whole)
            Slider(id, Bars, k .. "Size", "Button size", Bars.SIZE_MIN, Bars.SIZE_MAX, 1, Whole)
            Slider(id, Bars, k .. "Spacing", "Spacing", 0, Bars.SPACING_MAX, 1, Whole)
            Choice(id, Bars, k .. "Show", "Show", Bars.SHOW)
            if Bars.defaults[k .. "ShowEmpty"] ~= nil then Toggle(id, Bars, k .. "ShowEmpty", "Always show buttons") end
            if fades[info.label] then Toggle(id, Menus, fades[info.label], "Auto-hide") end
        end

        -- The game's frames placed in Unlock Mode (ActionBars\GameFrames.lua).
        local Game = Core.GameFrames
        Slider("minimap", Game, "minimapSize", "Size", Game.SIZE_MIN, Game.SIZE_MAX, 5, WholePercent)
        Toggle("minimap", Game, "minimapHeaderBelow", "Header below")
        Toggle("minimap", Game, "minimapRotate", "Rotate minimap")
        Slider("bags", Game, "bagsSize", "Size", Game.SIZE_MIN, Game.SIZE_MAX, 5, WholePercent)
        Slider("chat", Game, "chatWidth", "Width", Game.CHAT_MIN, Game.CHAT_MAX, 1, Whole)
        Slider("chat", Game, "chatHeight", "Height", Game.CHAT_MIN / 2, Game.CHAT_MAX, 1, Whole)
        Toggle("chat", Core.Chat, "showButton", "Copy button")
    end

    local function OwnSettings(entry)
        if not ownSettings then BuildOwnSettings() end
        return ownSettings[entry.opts.id or false] or {}
    end

    local function SettingRow(parent, item)
        local label = item.label
        local row = Row(parent, type(label) == "function" and label() or label)
        if type(label) == "function" then row.labelOf = label end
        local module, key = item.module, item.key
        local function Get() return module.db and module.db[key] end
        local function Set(value)
            Core.NoteEdit(module, key)      -- an unsaved change of Unlock Mode's, like a move
            module.db[key] = value
            if module.Refresh then module.Refresh() end
            Core.RefreshOptions()
            if row.control then row.control.Refresh() end
        end
        local kind = item.kind
        if kind == "toggle" then
            row.control = W.Toggle(row, function() return Get() and true or false end,
                function(on) Set(on and true or false) end)
        elseif kind == "choice" then
            row.control = W.Dropdown(row, CONTROL, item.choices, Get, Set)
            row.control:SetHeight(ROW - 2)
        elseif kind == "number" then
            row.control = W.NumberBox(row, nil, NUMBER, Get, Set, { min = item.min, max = item.max })
            row.control:SetHeight(ROW - 2)
        else
            -- Its value typed in the box beside it; a share as a percentage.
            row.control = W.Slider(row, CONTROL - SLIDER_VALUE,
                { min = item.min, max = item.max, step = item.step, text = item.text,
                  input = true, inputWidth = SLIDER_VALUE - SLIDER_GAP, inputGap = SLIDER_GAP,
                  inputHeight = ROW - 4, scale = item.text == Options.Percent and 100 or nil },
                Get, Set)
        end
        row.control:SetPoint("RIGHT", row, "RIGHT", kind == "slider" and -SLIDER_VALUE or 0, 0)
        return row
    end

    local function SettingsKey(items)
        local parts = {}
        for _, item in ipairs(items) do parts[#parts + 1] = item.module.key .. "." .. item.key end
        return table.concat(parts, "|")
    end

    -- The block of `entry`'s settings (pieces alike share one); nothing when none.
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

    local function BuildMenu()
        if menu then return end
        menu = NewWindow("UnlockMenu", MENU_WIDTH, 200)
        Unlock.menu = menu
        menu.title = W.Text(menu, 13, W.GOLD, true)
        menu.title:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_SIDE, -10)
        menu.title:SetWidth(MENU_INNER)
        menu.rule = W.Hairline(menu, W.FAINT, 30, MENU_SIDE, MENU_SIDE)

        local function Rounded(value) return value and Snap.Whole(value) end

        -- Match / Anchor: the next piece clicked; the menu steps aside until then (ReopenAfterPick).
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
        for _, size in ipairs(AXES) do
            local axis = size.axis
            menu[size.row] = NumberRow(size.word, function(entry) return Rounded(Snap.SizeOf(entry, axis)) end,
                function(entry, value) Snap.SetSize(entry, axis, value) end)
            menu[size.extra] = NumberRow("Extra " .. size.word,
                function(entry) return select(2, Snap.MatchOf(entry, axis)) end,
                function(entry, value) Snap.SetMatchExtra(entry, axis, value) end)
            menu[size.match] = MenuButton("", function(entry)
                if Snap.MatchOf(entry, axis) then Snap.ClearMatch(entry, axis) else Pick(entry, axis) end
            end)
        end
        menu.xRow = NumberRow("X Position", function(entry) return Rounded((Snap.PositionOf(entry))) end,
            function(entry, value) Snap.MoveTo(entry, value, nil) end)
        menu.yRow = NumberRow("Y Position", function(entry) return Rounded(select(2, Snap.PositionOf(entry))) end,
            function(entry, value) Snap.MoveTo(entry, nil, value) end)
        menu.anchor = MenuButton("Anchor", function(entry)
            local to = Snap.AnchorOf(entry)
            if to and not Snap.IsScreenEdge(to) then Snap.Unanchor(entry) else Pick(entry, "anchor") end
        end)

        menu.anchored = Row(menu, "Anchored to")
        menu.anchored.value = W.Text(menu.anchored, 12, ANCHORED)
        menu.anchored.value:SetPoint("RIGHT", menu.anchored, "RIGHT", 0, 0)
        menu.anchored.value:SetJustifyH("RIGHT")
        menu.offsetX = NumberRow("Offset X", function(entry) return Rounded(select(3, Snap.AnchorOf(entry))) end,
            function(entry, value) Snap.SetAnchorOffset(entry, value, nil) end)
        menu.offsetY = NumberRow("Offset Y", function(entry) return Rounded(select(4, Snap.AnchorOf(entry))) end,
            function(entry, value) Snap.SetAnchorOffset(entry, nil, value) end)
        menu.numberRows = { menu.wRow, menu.hRow, menu.extraW, menu.extraH, menu.xRow, menu.yRow,
                            menu.offsetX, menu.offsetY }

        local screens = { { value = "CENTER", label = "Center" } }
        for _, edge in ipairs(Snap.SCREEN_EDGES) do screens[#screens + 1] = { value = edge.key, label = edge.label } end
        menu.screen = Row(menu, "Relative to Screen")
        menu.screen.control = W.Dropdown(menu.screen, 96, screens, function()
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

        menu.centre = MenuButton("Center on Screen", Snap.CentreOnScreen)
        menu.reset = MenuButton("Reset Position", Snap.ResetPlace)
        menu.settingsRule = W.Flat(menu, "ARTWORK", W.FAINT)
        menu.settingsRule:SetSize(MENU_INNER, W.Pixel(menu))

        Draggable(menu)
        Every(menu, Unlock.RefreshMenu)
        -- Shut by a click anywhere else, as the game's menus are - not in its
        -- dropdown's list, nor on its own piece (that click is Snap.Clicked's).
        menu:HookScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
        menu:HookScript("OnHide", function(self)
            W.ClosePopup()
            self.entry = nil
            self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        end)
        menu:SetScript("OnEvent", function(self)
            if self:IsMouseOver() then return end
            local list = W.Popup()
            if list:IsShown() and list:IsMouseOver() then return end
            local mover = self.entry and Snap.movers[self.entry]
            if mover and mover:IsVisible() and mover:IsMouseOver() then return end
            self:Hide()
        end)
    end

    -- Which rows the menu has for `entry` now: laid out again when it changes.
    local function Shape(entry)
        return table.concat({
            tostring(Snap.SizeOf(entry, "w") ~= nil), tostring(Snap.MatchOf(entry, "w") ~= nil),
            tostring(Snap.SizeOf(entry, "h") ~= nil), tostring(Snap.MatchOf(entry, "h") ~= nil),
            tostring(Snap.AnchorOf(entry) ~= nil), tostring(Snap.CanReset(entry)),
            tostring(entry.opts.id ~= nil), SettingsKey(OwnSettings(entry)),
        }, ",")
    end

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
        for _, size in ipairs(AXES) do
            local sized, matched = Snap.SizeOf(entry, size.axis) ~= nil, Snap.MatchOf(entry, size.axis) ~= nil
            Put(menu[size.row], step, sized and not matched)
            Put(menu[size.extra], step, sized and matched)
        end
        for _, size in ipairs(AXES) do Put(menu[size.match], step, Snap.SizeOf(entry, size.axis) ~= nil) end
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
            -- (A number being typed is left as it is.)
            if row:IsShown() and not row.box:HasFocus() then row.box.Refresh() end
        end
        local to = Snap.AnchorOf(entry)
        if to then menu.anchored.value:SetText(Snap.TargetName(to)) end
        for _, size in ipairs(AXES) do
            local button, matched = menu[size.match], Snap.MatchOf(entry, size.axis)
            W.SetLabel(button, matched and ("Unmatch " .. size.word .. ": " .. Snap.TargetName(matched))
                or ("Match " .. size.word))
            W.SetStyle(button, matched and "active" or nil)
        end
        local onPiece = to and not Snap.IsScreenEdge(to)
        W.SetLabel(menu.anchor, onPiece and "Remove Anchor" or "Anchor")
        if onPiece then W.SetTextColour(menu.anchor.label, REMOVE) else W.PaintButton(menu.anchor) end
        menu.screen.control.Refresh()
        if menu.block then
            for _, row in ipairs(menu.block.rows) do
                if not (row.control.HasFocus and row.control:HasFocus()) then row.control.Refresh() end
                if row.labelOf then row.label:SetText(row.labelOf()) end
            end
        end
    end

    -- Free on the screen, centred in its right half (a piece that resizes never
    -- takes it along), until dragged.
    function Snap.OpenCog(entry)
        if not entry or InCombatLockdown() then return end
        BuildMenu()
        menu.reopen = nil
        menu.entry = entry
        menu.title:SetText(Snap.NameOf(entry))
        LayOutMenu()
        if not menu.dragged then
            menu:ClearAllPoints()
            menu:SetPoint("CENTER", UIParent, "CENTER", GetScreenWidth() / 4, 0)
        end
        menu:Show()
        menu:Raise()
        Unlock.RefreshMenu()
    end

    -- A click on a piece: selected and its menu opened - or, its menu open, let go of.
    function Snap.Clicked(entry, wasSelected)
        if wasSelected and menu and menu:IsShown() and menu.entry == entry then
            Snap.Deselect()
            return
        end
        Snap.Select(entry)
        Snap.OpenCog(entry)
    end

    -- A pick from the menu over: the menu back, if the same piece is still selected.
    local function ReopenAfterPick()
        local entry = menu and menu.reopen
        if not entry or Snap.Picking() then return end
        menu.reopen = nil
        if Snap.SelectedEntry() == entry and Core.IsUnlocked() then Snap.OpenCog(entry) end
    end

    ---------------------------------------------------------------------------
    -- Unsaved Changes (EllesmereUI's), on Exit. Leaving for the game's Edit Mode,
    -- secure buttons over its answers run the game's /editmode after: the one
    -- way into it that leaves the game's code untainted.
    ---------------------------------------------------------------------------

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

    -- A secure button running /editmode, `before(self, mouse)` first and its `Done(self)` after.
    local function EditModeButton(before)
        local button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
        button:RegisterForClicks("LeftButtonUp")
        button:SetAttribute("useOnKeyDown", false)
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", "/editmode")
        -- Hidden only once its click is done: hidden mid-click, its macro might never run.
        button:SetScript("PreClick", function(self, mouse)
            self.clicking = true
            before(self, mouse)
        end)
        button:SetScript("PostClick", function(self)
            self.clicking = false
            if self.Done then self.Done(self) end
        end)
        button:Hide()
        RegisterStateDriver(button, "visibility", "[combat] hide")
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
            if save then Core.CommitEditMode() else Core.RevertEditMode() end
            Core.SetUnlocked(false)
            if after then after() end
        end
        -- Continue: the question away, Unlock Mode still open, every change unsaved - as Esc.
        ask.continue = W.Button(ask, "Continue", 140, function() ask:Hide() end)
        ask.continue:SetPoint("BOTTOM", ask, "BOTTOM", 0, 16)
        ask.discard = W.Button(ask, "Exit Without Saving", 140, function() Answer(false) end)
        ask.discard:SetPoint("RIGHT", ask.continue, "LEFT", -8, 0)
        ask.save = W.Button(ask, SAVE_EXIT, 140, function() Answer(true) end, "active")
        ask.save:SetPoint("LEFT", ask.continue, "RIGHT", 8, 0)
        secureAsk.discard = EditModeButton(function() Answer(false) end)
        secureAsk.save = EditModeButton(function() Answer(true) end)
        for _, button in pairs(secureAsk) do
            button:SetFrameStrata(TOP_STRATA)
            button.Done = UpdateSecureAsk
        end
        Unlock.secureAsk = secureAsk
        ask:HookScript("OnHide", function(self)
            if not self.quiet then self.after = nil end
            UpdateSecureAsk()
        end)
        -- Placed again while it shows: the first time, its buttons have no place to read yet.
        Every(ask, UpdateSecureAsk)
    end

    -- `after`: what runs once Unlock Mode has closed (Handover: the game's Edit Mode).
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
    -- The game's own frames (EllesmereUI's Blizzard movers): a box over each,
    -- "Edit from Blizzard" under the mouse. A click closes Unlock Mode (asking
    -- when something is unsaved) and opens the game's Edit Mode, through one
    -- secure button laid over the box under the mouse: the addon's own code
    -- opening Edit Mode would taint the game's unit frames. Never in combat.
    ---------------------------------------------------------------------------

    local BLIZZ_LEVEL = Snap.MOVER_LEVEL - 100
    local boxes = {}            -- system -> its box
    Unlock.boxes = boxes
    local hiddenBoxes = {}      -- Shift+Right-clicked: hidden until Unlock Mode closes
    local seen = {}             -- system -> true: boxed this frame
    local handover              -- the secure button
    local hoveredBox

    -- Closed (asked first when something is unsaved), then the game's Edit Mode.
    local function Leave()
        Handover()
        Core.RequestClose(false, Handover)
    end

    local function PickRefused(name)
        local pick = Snap.Picking()
        if not pick then return false end
        Snap.StopPicking()
        Snap.Refuse(pick.entry, (pick.axis == "anchor" and "Elements cannot be anchored to\n"
            or "Elements cannot size match to\n") .. name)
        return true
    end

    local function HideBox(box)
        hiddenBoxes[box.system] = true
        box:Hide()
    end

    local function NewBox(system)
        local box = CreateFrame("Frame", nil, UIParent)
        box:SetFrameStrata(Snap.STRATA)
        box:SetFrameLevel(BLIZZ_LEVEL)
        box:EnableMouse(true)
        box:Hide()
        box.system = system
        Snap.MoverLook(box)
        box.action = W.Text(box, 9, { Style.GOLD[1], Style.GOLD[2], Style.GOLD[3], 1 })
        box.action:SetPoint("TOP", box.label, "BOTTOM", 0, -3)
        box.action:SetJustifyH("CENTER")
        box.action:SetText("Edit from Blizzard")
        box.action:Hide()
        -- Without the secure button over it (something unsaved, or not ready yet).
        box:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" then
                if IsShiftKeyDown() then HideBox(self) end
            elseif button == "LeftButton" and not PickRefused(self.name or "") then
                Leave()
            end
        end)
        boxes[system] = box
        return box
    end

    local function HandoverButton()
        if handover then return handover end
        handover = EditModeButton(function(self, mouse)
            if mouse == "RightButton" then
                -- Shift+Right-click hides the box under it, as on any mover; no macro.
                if IsShiftKeyDown() and self.box then HideBox(self.box) end
                self:SetAttribute("type", nil)
                return
            end
            self:SetAttribute("type", "macro")
            Leave()
        end)
        handover:SetFrameStrata(Snap.STRATA)
        handover:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        function handover.Done(self)
            if InCombatLockdown() then return end
            self:SetAttribute("type", "macro")
            if not Core.IsUnlocked() then
                self.box = nil
                self:Hide()
            end
        end
        Unlock.handover = handover
        return handover
    end

    local function OwnMoverUnderMouse()
        for _, mover in pairs(Snap.movers) do
            if mover:IsShown() and mover:IsMouseOver() then return true end
        end
        return false
    end

    -- Every frame while Unlock Mode is open: each box placed, named and lit only when that changed.
    local function LayOutBoxes()
        for system in pairs(seen) do seen[system] = nil end
        hoveredBox = nil
        if Core.IsUnlocked() and not Snap.Previewing() then
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
                    if not hoveredBox and box:IsMouseOver() and not OwnMoverUnderMouse() then hoveredBox = box end
                    seen[system] = true
                end
            end
            for _, box in pairs(boxes) do
                local over = box == hoveredBox and not Snap.Picking()
                Snap.Light(box, over)
                -- "Edit from Blizzard" only where it fits under the name.
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
        local button = (wanted or handover) and HandoverButton()
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
    -- The dimmer (EllesmereUI's overlay): darker while a piece is picked; none while previewing
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
        dimmer:Hide()
        Unlock.dimmer = dimmer
        return dimmer
    end

    -- At once: nothing animated in Unlock Mode.
    local function FadeDimmer()
        if not dimmer then return end
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
    -- Esc, a step at a time: Quick Keybinds, the question, a list, the menu,
    -- a pick, Preview - else Unlock Mode left. Other keys go on to the game.
    ---------------------------------------------------------------------------

    local esc

    function Unlock.Escape()
        local keybinds = Options.Keybinds
        if keybinds.IsOpen() then
            keybinds.Close(false)
        elseif ask and ask:IsShown() then
            ask:Hide()
        elseif W.Popup():IsShown() then
            W.ClosePopup()
        elseif menu and menu:IsShown() then
            menu:Hide()
        elseif Snap.Picking() then
            Snap.StopPicking()
        elseif Snap.Previewing() then
            Unlock.SetPreview(false)
        else
            Core.RequestClose(false)
        end
    end

    local function Esc()
        if esc then return esc end
        esc = CreateFrame("Frame", Core.ADDON_NAME .. "UnlockEsc", UIParent)
        esc:SetFrameStrata(TOP_STRATA)
        esc:EnableMouse(false)
        esc:SetScript("OnKeyDown", function(self, key)
            if InCombatLockdown() then return end
            self:SetPropagateKeyboardInput(key ~= "ESCAPE")
            if key == "ESCAPE" then Unlock.Escape() end
        end)
        esc:SetScript("OnKeyUp", function(self)
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
        end)
        Unlock.esc = esc
        return esc
    end

    ---------------------------------------------------------------------------
    -- A click on nothing of Unlock Mode's lets go of the selected piece (not
    -- while dragging, picking or previewing); listened for while it is open.
    ---------------------------------------------------------------------------

    local function OverUnlockMode()
        if OwnMoverUnderMouse() then return true end
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
    -- Kept up while Unlock Mode is open, and on whatever changed
    ---------------------------------------------------------------------------

    -- Every frame (Core\Snap.lua's driver).
    function Snap.OnDrive()
        FadeDimmer()
        LayOutBoxes()
    end

    -- The selection, a pick, a match or an anchor changed.
    function Snap.SelectionChanged()
        ReopenAfterPick()
        if not (menu and menu:IsShown()) then return end
        if Snap.SelectedEntry() ~= menu.entry then menu:Hide() else Unlock.RefreshMenu() end
    end

    function Core.EditModeChanged()
        if bar and bar:IsShown() then RefreshBar() end
    end

    -- Opened or closed (Core.SetUnlocked, or a fight putting it away and back).
    -- The options make way and come back after - not after a fight, nor for the game's Edit Mode.
    function Core.PlacingChanged(unlocked)
        if Snap.Previewing() then
            Snap.SetPreview(false)
            Core.UpdateGrid()
        end
        if unlocked then
            if Options.IsShown() then
                fromOptions = true
                Options.Close()
            end
            BuildBar()
            PlaceBar()
            RefreshBar()
            bar:Show()
            Dimmer():Show()
            FadeDimmer()
            Esc():Show()
            esc:EnableKeyboard(not InCombatLockdown())
            away:RegisterEvent("GLOBAL_MOUSE_DOWN")
            return
        end
        away:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        Options.Keybinds.Close(true)        -- Quick Keybind Mode with it, its keys kept
        HideQuietly(bar)
        HideQuietly(menu)
        W.ClosePopup()
        if dimmer then dimmer:Hide() end
        if esc then                         -- not protected: put away in combat too
            esc:EnableKeyboard(false)
            esc:Hide()
        end
        HideBoxes()
        if Core.UnlockSuspended() then return end
        HideQuietly(ask)
        UpdateSecureAsk()
        if fromOptions then
            fromOptions = false
            Options.Open()
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
