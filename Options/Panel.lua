-- The options: a window of the addon's own, in the frames' look, opened from
-- its button at the end of the micro menu (Menus\OptionsButton.lua) - the one
-- way in. It is not in the game's Settings any more (the player asked for its
-- own window, 2026-09-29).
--
--   +------------------------------------------------------------------+
--   | [icon] Dog's Forever UI              [Unlock UI] [Reset all] [x] |  header: drag to move
--   +------------+-----------------------------------------------------+
--   | Unit frames|  Unit frames                                        |
--   | Castbars   |  +-----------------------------------------------+  |
--   | XP bar     |  | Enabled                                  [==] |  |  a card of rows:
--   | ...        |  | what it does, in a line or two                |  |  name, what it does,
--   |            |  +-----------------------------------------------+  |  the control on the right
--   |            |  Castbars ...                                       |
--   +------------+-----------------------------------------------------+
--
-- ONE PAGE, as the player wants it (no tabs - 2026-09-27): every section on
-- one scrolling page. The sidebar is its table of contents: a click glides
-- the page to that section, and whichever section you are reading is lit as
-- you scroll. The cooldown manager and the profiles are sections like the
-- rest.
--
-- Every setting says what it does under its name, rather than in a tooltip.
-- Changes take effect at once - there is no Apply. What a click did that is
-- not plain to see (a profile saved, an ID refused) shows in a toast at the
-- foot of the window. Esc or the cross closes it; the header drags it.
--
-- The window is built the first time it is opened. Pages.lua describes what
-- is on the page; Widgets.lua draws the controls; this file lays them out.

local Options = {}
DogsForeverUI.Options = Options

do -- private scope

    local Core = DogsForeverUI
    local Style = Core.Style
    local W = Core.Widgets
    local TITLE = Core.TITLE
    local PANEL_NAME = Core.ADDON_NAME .. "Options"

    local WIDTH, HEIGHT = 880, 620
    local HEADER = 52
    local SIDEBAR = 190
    local PAD = 28                  -- the page's margins, left and right
    local GUTTER = 14               -- room for the scrollbar
    local INSET = 4                 -- so a card's outline is not cut off
    local CONTENT_WIDTH = WIDTH - SIDEBAR - 2 * PAD - GUTTER - 2 * INSET
    local CARD_PAD = 16             -- inside a card, left and right
    local ROW_MIN = 46
    local TOP_PAD = 20
    local SECTION_GAP = 34
    local NAV_ROW = 32
    local SEPARATOR = { 1, 1, 1, 0.06 }
    local BACKGROUND = { Style.BACKGROUND_COLOR[1], Style.BACKGROUND_COLOR[2],
                         Style.BACKGROUND_COLOR[3], 0.96 }

    local window, content, scrollFrame, scroller
    local refreshers = {}
    local sections = {}
    local describe
    Options.sections = sections
    Options.controls = {}           -- ["Section/Label"] = the row's control

    local function Refresh()
        for index = 1, #refreshers do refreshers[index]() end
    end

    local function Register(refresh)
        refreshers[#refreshers + 1] = refresh
    end

    function Options.Percent(value)
        return string.format("%d%%", math.floor((value or 0) * 100 + 0.5))
    end

    function Options.Seconds(value)
        return string.format("%.1fs", value or 0)
    end

    ---------------------------------------------------------------------------
    -- THE TOAST: one line at the foot of the window saying what a click did.
    ---------------------------------------------------------------------------

    local toast

    local function BuildToast()
        toast = CreateFrame("Frame", nil, window)
        toast:SetHeight(30)
        toast:SetPoint("BOTTOM", window, "BOTTOM", SIDEBAR / 2, 18)
        toast:SetFrameLevel(window:GetFrameLevel() + 40)
        local bg = W.Flat(toast, "BACKGROUND", { 0.09, 0.09, 0.09, 0.97 })
        bg:SetAllPoints(toast)
        toast.border = W.Border(toast)
        toast.dot = W.Flat(toast, "ARTWORK", W.GOOD)
        toast.dot:SetSize(6, 6)
        toast.dot:SetPoint("LEFT", toast, "LEFT", 12, 0)
        toast.text = W.Text(toast, 12)
        toast.text:SetPoint("LEFT", toast.dot, "RIGHT", 8, 0)
        toast:Hide()
    end

    -- ok: whether it worked (a green or a red mark, and a longer stay if not).
    function Options.Say(ok, message)
        if not toast or not message then return end
        toast.text:SetText(message)
        W.Colour(toast.dot, ok and W.GOOD or W.BAD)
        W.SetTextColour(toast.text, ok and W.TEXT or W.BAD)
        local width = toast.text.GetStringWidth and toast.text:GetStringWidth() or 300
        toast:SetWidth(math.min(WIDTH - SIDEBAR - 40, (width or 300) + 40))
        toast.message = message
        Style.FadeIn(toast)
        local token = (toast.token or 0) + 1
        toast.token = token
        C_Timer.After(ok and 3 or 6, function()
            if toast.token == token then Style.FadeOut(toast) end
        end)
    end

    ---------------------------------------------------------------------------
    -- THE PAGE: sections top to bottom, each a heading, an optional line
    -- under it and a card of rows. Rows know their own height (Measure), so
    -- a list that grows lays the page out again below it (Relayout).
    ---------------------------------------------------------------------------

    local function Relayout()
        if not content then return end
        local y = TOP_PAD
        for _, section in ipairs(sections) do
            section.top = y
            section.heading:ClearAllPoints()
            section.heading:SetPoint("TOPLEFT", content, "TOPLEFT", INSET, -y)
            y = y + 22
            if section.note then
                section.note:ClearAllPoints()
                section.note:SetPoint("TOPLEFT", content, "TOPLEFT", INSET, -y)
                section.note:SetPoint("TOPRIGHT", content, "TOPLEFT", INSET + CONTENT_WIDTH, -y)
                y = y + W.FitText(section.note) + 6
            end
            y = y + 8
            local card = section.card
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", content, "TOPLEFT", INSET, -y)
            local inside = 0
            for index, row in ipairs(section.rows) do
                local height = row.Measure()
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -inside)
                row:SetHeight(height)
                row.separator:SetShown(index > 1)
                inside = inside + height
            end
            card:SetHeight(math.max(1, inside))
            y = y + inside + SECTION_GAP
        end
        content:SetHeight(y - SECTION_GAP + 40)
        if scroller then scroller.Update() end
        W.SnapBorders()
    end
    Options.Relayout = Relayout

    local function AddRow(section, row)
        row:SetWidth(CONTENT_WIDTH)
        row.separator = W.Hairline(row, SEPARATOR, 0, CARD_PAD, CARD_PAD)
        section.rows[#section.rows + 1] = row
        return row
    end

    local Page = {}
    Page.__index = Page

    -- A setting changed: its module redraws, and the page shows what the
    -- settings are now.
    function Page:Changed(module)
        if module and module.Refresh then module.Refresh() end
        Refresh()
    end

    function Page:Section(title, note)
        local section = { title = title, rows = {} }
        section.heading = W.Text(content, 16, W.TEXT, true)
        section.heading:SetText(title)
        if note then
            section.note = W.Text(content, 12, W.MUTED, false, CONTENT_WIDTH)
            section.note:SetText(note)
        end
        section.card = W.Card(content)
        section.card:SetWidth(CONTENT_WIDTH)
        sections[#sections + 1] = section
        self.section = section
        self.pair = nil
    end

    -- Closes a half-filled pair of small switches: the next one starts a row.
    function Page:EndRow()
        self.pair = nil
    end

    -- A row with a name, a line or two on what it does, and its control on
    -- the right. `clickable`: the whole row presses the control.
    local function SettingRow(page, label, description, controlWidth, clickable)
        local row = CreateFrame(clickable and "Button" or "Frame", nil, page.section.card)
        row.hover = W.Flat(row, "BACKGROUND", { 1, 1, 1, 0.035 })
        row.hover:SetAllPoints(row)
        row.hover:Hide()
        if clickable then
            row:RegisterForClicks("LeftButtonUp")
            row:SetScript("OnEnter", function(self) self.hover:Show() end)
            row:SetScript("OnLeave", function(self) self.hover:Hide() end)
        end

        local textWidth = CONTENT_WIDTH - 2 * CARD_PAD - controlWidth - 24
        row.label = W.Text(row, 13, W.TEXT)
        row.label:SetWidth(textWidth)
        row.label:SetText(label)
        row.label:SetPoint("TOPLEFT", row, "TOPLEFT", CARD_PAD, description and -13 or -16)
        if description then
            row.description = W.Text(row, 12, W.MUTED, false, textWidth)
            row.description:SetText(description)
            row.description:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
            row.description:SetPoint("TOPRIGHT", row.label, "BOTTOMLEFT", textWidth, -4)
        end
        function row.Measure()
            local height = 13 + (row.label:GetStringHeight() or 14) + 13
            if row.description then height = height + 4 + W.FitText(row.description) end
            return math.max(ROW_MIN, height)
        end
        AddRow(page.section, row)
        return row
    end

    local function Keep(page, label, control)
        Options.controls[page.section.title .. "/" .. label] = control
    end

    -- entry = { module, key, label, tooltip (what it does), compact }
    -- A compact switch has no line of its own: two share a row, name and
    -- switch each (the action bars under Auto-hide).
    function Page:Check(entry)
        local module, db = entry.module, entry.module.db
        local function Get() return db[entry.key] end
        local function Set(value)
            db[entry.key] = value
            self:Changed(module)
        end

        local toggle
        if entry.compact then
            local pair = self.pair
            if not pair or pair.count == 2 then
                pair = CreateFrame("Frame", nil, self.section.card)
                pair.count = 0
                function pair.Measure() return 40 end
                AddRow(self.section, pair)
                self.pair = pair
            end
            local half = (CONTENT_WIDTH - 2 * CARD_PAD) / 2
            local cell = CreateFrame("Button", nil, pair)
            cell:SetSize(half - 12, 32)
            cell:SetPoint("LEFT", pair, "LEFT", CARD_PAD + pair.count * (half + 12) - 6, 0)
            cell:RegisterForClicks("LeftButtonUp")
            cell.hover = W.Flat(cell, "BACKGROUND", { 1, 1, 1, 0.035 })
            cell.hover:SetAllPoints(cell)
            cell.hover:Hide()
            cell:SetScript("OnEnter", function(me) me.hover:Show() end)
            cell:SetScript("OnLeave", function(me) me.hover:Hide() end)
            cell.label = W.Text(cell, 13, W.TEXT)
            cell.label:SetPoint("LEFT", cell, "LEFT", 6, 0)
            cell.label:SetText(entry.label)
            toggle = W.Toggle(cell, Get, Set)
            toggle:SetPoint("RIGHT", cell, "RIGHT", -6, 0)
            cell:SetScript("OnClick", function() Set(not Get()) end)
            pair.count = pair.count + 1
            toggle.row = cell
        else
            self.pair = nil
            local row = SettingRow(self, entry.label, entry.tooltip, W.TOGGLE_WIDTH, true)
            toggle = W.Toggle(row, Get, Set)
            toggle:SetPoint("RIGHT", row, "RIGHT", -CARD_PAD, 0)
            row:SetScript("OnClick", function() Set(not Get()) end)
            toggle.row = row
        end
        Register(toggle.Refresh)
        Keep(self, entry.label, toggle)
        return toggle
    end

    -- A setting with a few named values, side by side.
    -- entry = { module, key, label, tooltip, choices = { { value, label } } }
    function Page:Choice(entry)
        self.pair = nil
        local module, db = entry.module, entry.module.db
        local width = entry.segmentWidth or 72
        local row = SettingRow(self, entry.label, entry.tooltip, width * #entry.choices)
        local control = W.Segmented(row, entry.choices, width,
            function() return db[entry.key] end,
            function(value)
                db[entry.key] = value
                self:Changed(module)
            end)
        control:SetPoint("RIGHT", row, "RIGHT", -CARD_PAD, 0)
        Register(control.Refresh)
        Keep(self, entry.label, control)
        return control
    end

    -- entry = { module, key, label, description, min, max, step, text }
    local SLIDER_WIDTH, SLIDER_VALUE = 180, 52
    function Page:Slider(entry)
        self.pair = nil
        local module, db = entry.module, entry.module.db
        local row = SettingRow(self, entry.label, entry.description, SLIDER_WIDTH + SLIDER_VALUE)
        local slider = W.Slider(row, SLIDER_WIDTH, entry,
            function() return db[entry.key] end,
            function(value)
                db[entry.key] = value
                if module.Refresh then module.Refresh() end
            end)
        slider:SetPoint("RIGHT", row, "RIGHT", -CARD_PAD - SLIDER_VALUE, 0)
        Register(slider.Refresh)
        Keep(self, entry.label, slider)
        return slider
    end

    -- ROWS OF BOXES: the element's name, then its number boxes, each with a
    -- small title over it. A typed size or position is the player's: a bar
    -- the addon was placing itself (autoPlaced) stays where it now is, and
    -- `placed` names the flag that says a unit frame has been placed.
    -- box = { key, title, min, max, decimals, onChange(old, new), placed,
    --         keepsPlacement }: onChange runs before the redraw - a width that
    -- keeps its bar centred moves the bar with it.
    --
    -- The columns, left to right: the name (LABEL_WIDTH, never wrapped), up to
    -- MAX_BOXES boxes, then - right-aligned, so every row's layer lines up -
    -- the layer. Worked out so the widest row still leaves LAYER_GAP clear
    -- before the layer (an earlier layout put the unit frames' fourth box
    -- under the layer dropdown).
    local LABEL_WIDTH = 116
    local BOX_WIDTH, BOX_STEP = 60, 70
    local BOX_X = CARD_PAD + LABEL_WIDTH + 8
    local MAX_BOXES = 4
    local LAYER_WIDTH, LAYER_GAP = 132, 40
    local BOX_ROW = 62
    local BOX_TOP = -28
    assert(BOX_X + (MAX_BOXES - 1) * BOX_STEP + BOX_WIDTH + LAYER_GAP
        <= CONTENT_WIDTH - CARD_PAD - LAYER_WIDTH, "the size rows do not fit")

    -- `get(db)` / `set(db, value)`, optional: a box whose number is worked out
    -- from a saved one rather than being it (the swing bars' Y, saved from
    -- the bottom of the screen since they grow upwards).
    local function Box(page, module, row, entry, x)
        local db = module.db
        local function Get()
            if entry.get then return entry.get(db) end
            return db[entry.key]
        end
        local box = W.NumberBox(row, PANEL_NAME .. module.key .. entry.key, BOX_WIDTH,
            Get,
            function(value)
                local old = Get()
                if entry.set then entry.set(db, value) else db[entry.key] = value end
                if entry.onChange then entry.onChange(old, value) end
                if entry.placed then db[entry.placed] = true end
                if db.autoPlaced ~= nil and not entry.keepsPlacement then db.autoPlaced = false end
                page:Changed(module)
            end,
            { min = entry.min, max = entry.max, decimals = entry.decimals })
        box:SetPoint("TOPLEFT", row, "TOPLEFT", x, BOX_TOP)
        local title = W.Text(row, 11, W.MUTED)
        title:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 1, 4)
        title:SetText(entry.title)
        Register(box.Refresh)
        return box
    end

    -- row = { module, label, boxes = { box, ... } }
    function Page:Row(spec)
        self.pair = nil
        local row = CreateFrame("Frame", nil, self.section.card)
        function row.Measure() return BOX_ROW end
        row.label = W.Text(row, 13, W.TEXT)
        row.label:SetWidth(LABEL_WIDTH)
        row.label:SetPoint("LEFT", row, "TOPLEFT", CARD_PAD, BOX_TOP - W.CONTROL_HEIGHT / 2)
        row.label:SetText(spec.label)
        assert(#spec.boxes <= MAX_BOXES, "more boxes than a row has room for")
        row.boxes = {}
        for index, entry in ipairs(spec.boxes) do
            row.boxes[index] = Box(self, spec.module, row, entry, BOX_X + (index - 1) * BOX_STEP)
        end
        AddRow(self.section, row)
        return row
    end

    -- A size row: a row of boxes, and the element's layer at its end.
    local STRATA = {}
    for _, value in ipairs({ "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG",
                             "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }) do
        STRATA[#STRATA + 1] = { value = value, label = value:sub(1, 1) .. value:sub(2):lower():gsub("_d", " d") }
    end
    Options.STRATA = STRATA

    -- spec.layerKey: the setting the layer is kept in (frameStrata unless said).
    function Page:SizeRow(spec)
        local row = self:Row(spec)
        local module, db = spec.module, spec.module.db
        local layerKey = spec.layerKey or "frameStrata"
        local layer = W.Dropdown(row, LAYER_WIDTH, STRATA,
            function() return db[layerKey] end,
            function(value)
                db[layerKey] = value
                self:Changed(module)
            end)
        layer:SetPoint("TOPRIGHT", row, "TOPRIGHT", -CARD_PAD, BOX_TOP)
        local title = W.Text(row, 11, W.MUTED)
        title:SetPoint("BOTTOMLEFT", layer, "TOPLEFT", 1, 4)
        title:SetText("Layer")
        row.layer = layer
        Register(layer.Refresh)
        return row
    end

    ---------------------------------------------------------------------------
    -- LISTS the player builds: a box and a button to add, then a line per
    -- entry. Both below grow and shrink, and lay the page out again when they
    -- do.
    ---------------------------------------------------------------------------

    local LIST_TOP = 60             -- the add row, above the entries
    local ENTRY = 38
    local ICON = 22

    -- One line of a list, lazily made: a faint line over it, a wash under the
    -- mouse.
    local function Line(parent)
        local line = CreateFrame("Frame", nil, parent)
        line:SetSize(CONTENT_WIDTH, ENTRY)
        line:EnableMouse(true)
        line.hover = W.Flat(line, "BACKGROUND", { 1, 1, 1, 0.035 })
        line.hover:SetAllPoints(line)
        line.hover:Hide()
        line:SetScript("OnEnter", function(self) self.hover:Show() end)
        line:SetScript("OnLeave", function(self) self.hover:Hide() end)
        W.Hairline(line, SEPARATOR, 0, CARD_PAD, CARD_PAD)
        return line
    end

    local function ListRow(page)
        page.pair = nil
        local row = CreateFrame("Frame", nil, page.section.card)
        row.count = 0
        function row.Measure()
            return LIST_TOP + math.max(1, row.count) * ENTRY + 8
        end
        row.empty = W.Text(row, 12, W.DIM)
        row.empty:SetPoint("TOPLEFT", row, "TOPLEFT", CARD_PAD, -(LIST_TOP + 12))
        row.lines = {}
        AddRow(page.section, row)
        return row
    end

    -- Shows `count` entries, and lays the page out again if that changed.
    local function Counted(row, count)
        row.empty:SetShown(count == 0)
        for index = count + 1, #row.lines do row.lines[index]:Hide() end
        if row.count ~= count then
            row.count = count
            Relayout()
        end
    end

    local function PlaceLine(row, line, index)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -(LIST_TOP + (index - 1) * ENTRY))
        line:Show()
    end

    -- The cooldown manager's list.
    -- spec = { title (the box's hint), empty, addLabel, add(text) -> ok, message,
    --          entries() -> list, describe(entry) -> name, icon, detail,
    --          remove(index), choices, getChoice(index), setChoice(index, value),
    --          hasChoice(entry), fixedChoice(entry) -> text }
    local CHOICE_SEGMENT = 74

    function Page:IdList(spec)
        local row = ListRow(self)
        row.empty:SetText(spec.empty or "")

        local box = W.TextBox(row, PANEL_NAME .. "IdBox", 220, 24, spec.title)
        box:SetPoint("TOPLEFT", row, "TOPLEFT", CARD_PAD, -18)
        local function Add()
            local ok, message = spec.add(box:GetText())
            Options.Say(ok, message)
            if ok then
                box:SetText("")
                if box.ShowHint then box:ShowHint() end
            end
            box:ClearFocus()
            Refresh()
        end
        local add = W.Button(row, spec.addLabel or "Add", 80, Add)
        add:SetPoint("LEFT", box, "RIGHT", 10, 0)
        box:SetScript("OnEnterPressed", Add)
        row.box, row.add = box, add

        local choiceWidth = spec.choices and CHOICE_SEGMENT * #spec.choices or 0

        local function MakeLine()
            local line = Line(row)
            line.icon = line:CreateTexture(nil, "ARTWORK")
            line.icon:SetSize(ICON, ICON)
            line.icon:SetPoint("LEFT", line, "LEFT", CARD_PAD, 0)
            line.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            line.text = W.Text(line, 13)
            line.text:SetPoint("LEFT", line.icon, "RIGHT", 10, 0)
            line.text:SetWidth(CONTENT_WIDTH - 2 * CARD_PAD - ICON - 10 - choiceWidth - 50)
            line.remove = W.IconButton(line, "close", 22, function()
                spec.remove(line.index)
                Refresh()
            end)
            line.remove:SetPoint("RIGHT", line, "RIGHT", -CARD_PAD + 4, 0)
            W.Tooltip(line.remove, "Remove", "Stop tracking this.")
            if spec.choices then
                line.choice = W.Segmented(line, spec.choices, CHOICE_SEGMENT,
                    function() return line.index and spec.getChoice(line.index) end,
                    function(value)
                        spec.setChoice(line.index, value)
                        Refresh()
                    end)
                line.choice:SetPoint("RIGHT", line.remove, "LEFT", -12, 0)
                -- Where there is nothing to choose: what it does, in words,
                -- in the same place.
                line.fixed = W.Text(line, 12, W.MUTED)
                line.fixed:SetPoint("LEFT", line.choice, "LEFT", 8, 0)
            end
            return line
        end

        Register(function()
            local entries = spec.entries()
            for index, entry in ipairs(entries) do
                local line = row.lines[index] or MakeLine()
                row.lines[index] = line
                line.index = index
                PlaceLine(row, line, index)
                local name, icon, detail = spec.describe(entry)
                line.icon:SetTexture(icon)
                line.text:SetText(name .. "  |cff808080" .. detail .. "|r")
                if line.choice then
                    if spec.hasChoice(entry) then
                        line.fixed:Hide()
                        line.choice:Show()
                        line.choice.Refresh()
                    else
                        line.choice:Hide()
                        line.fixed:SetText(spec.fixedChoice and spec.fixedChoice(entry) or "")
                        line.fixed:Show()
                    end
                end
            end
            Counted(row, #entries)
        end)
        Options.idList = row
        return row
    end

    -- THE PROFILES (Core\Profiles.lua): a name and Save, then a line per saved
    -- profile with Load and Delete. Save asks first when the name is taken;
    -- Load (it replaces every setting this character has) and Delete (it
    -- cannot be undone) always do. A profile's name, clicked, goes into the
    -- box, so saving again updates it.
    function Page:Profiles()
        local Profiles = Core.Profiles
        local row = ListRow(self)
        row.empty:SetText("No profiles yet.")

        local box = W.TextBox(row, PANEL_NAME .. "ProfileName", 220, Profiles.MAX_NAME, "Profile name")
        box:SetPoint("TOPLEFT", row, "TOPLEFT", CARD_PAD, -18)
        local save = W.TwoStep(row, "Save", "Overwrite?", 96, function()
            local ok, message = Profiles.Save(box:GetText())
            Options.Say(ok, message)
            box:ClearFocus()
            Refresh()
        end, function() return Profiles.Exists(box:GetText()) end)
        save:SetPoint("LEFT", box, "RIGHT", 10, 0)
        box:SetScript("OnEnterPressed", function() save.press() end)
        row.box, row.save = box, save

        local function MakeLine()
            local line = Line(row)
            line.name = W.Button(line, "", 260, function(self)
                box:SetText(self.profile)
                if box.ShowHint then box:ShowHint() end
            end, "flat")
            line.name:SetPoint("LEFT", line, "LEFT", CARD_PAD - 6, 0)
            line.name.label:ClearAllPoints()
            line.name.label:SetPoint("LEFT", line.name, "LEFT", 6, 0)
            line.name.label:SetFont(Style.FONT, 13, "")
            line.delete = W.TwoStep(line, "Delete", "Really delete?", 110, function()
                Options.Say(Profiles.Delete(line.profile))
                Refresh()
            end)
            line.delete:SetPoint("RIGHT", line, "RIGHT", -CARD_PAD, 0)
            line.load = W.TwoStep(line, "Load", "Really load?", 110, function()
                Options.Say(Profiles.Load(line.profile))
                Refresh()
            end)
            line.load:SetPoint("RIGHT", line.delete, "LEFT", -8, 0)
            return line
        end

        Register(function()
            local names = Profiles.Names()
            for index, name in ipairs(names) do
                local line = row.lines[index] or MakeLine()
                row.lines[index] = line
                if line.profile ~= name then
                    line.load.disarm()
                    line.delete.disarm()
                end
                line.profile = name
                line.name.profile = name
                W.SetLabel(line.name, name)
                PlaceLine(row, line, index)
            end
            Counted(row, #names)
        end)
        Options.profileList = row
        return row
    end

    local function NewPage()
        return setmetatable({}, Page)
    end

    ---------------------------------------------------------------------------
    -- THE SIDEBAR: the page's table of contents.
    ---------------------------------------------------------------------------

    local active, clicked

    local function SetActive(section)
        active = section
        for _, entry in ipairs(sections) do
            local button = entry.nav
            if button then
                button.selected = entry == section
                button.accent:SetShown(button.selected)
                W.PaintButton(button)
            end
        end
    end
    Options.Active = function() return active end

    -- The section being read: the last one whose heading has reached the top
    -- of the page - or, once the page is scrolled to its end, the last one.
    -- A section picked in the sidebar stays lit until the page is scrolled
    -- by hand, though the end of the page may come before its heading can
    -- reach the top.
    local function Follow(y)
        if clicked then return end
        local current = sections[1]
        for _, section in ipairs(sections) do
            if section.top and section.top - TOP_PAD <= y + 8 then current = section end
        end
        if scroller and y >= scroller.Limit() - 1 and scroller.Limit() > 0 then
            current = sections[#sections]
        end
        if current ~= active then SetActive(current) end
    end

    local function GoTo(section)
        clicked = section
        SetActive(section)
        scroller.ScrollTo((section.top or 0) - TOP_PAD)
    end
    Options.GoTo = GoTo

    local function BuildSidebar()
        local sidebar = CreateFrame("Frame", nil, window)
        sidebar:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -HEADER)
        sidebar:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 0, 0)
        sidebar:SetWidth(SIDEBAR)
        local bg = W.Flat(sidebar, "BACKGROUND", { 1, 1, 1, 0.025 })
        bg:SetAllPoints(sidebar)
        local rule = W.Flat(sidebar, "ARTWORK", W.FAINT)
        rule:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
        rule:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)
        rule:SetWidth(W.Pixel(sidebar))

        for index, section in ipairs(sections) do
            local button = W.Button(sidebar, section.title, SIDEBAR - 16, function() GoTo(section) end, "flat")
            button:SetHeight(NAV_ROW - 2)
            button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, -14 - (index - 1) * NAV_ROW)
            button.label:ClearAllPoints()
            button.label:SetPoint("LEFT", button, "LEFT", 16, 0)
            button.label:SetFont(Style.FONT, 13, "")
            button.accent = W.Flat(button, "ARTWORK", W.GOLD)
            button.accent:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -6)
            button.accent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 6)
            button.accent:SetWidth(3)
            button.accent:Hide()
            button.section = section
            section.nav = button
        end

        local version
        if C_AddOns and C_AddOns.GetAddOnMetadata then
            local ok, value = pcall(C_AddOns.GetAddOnMetadata, Core.ADDON_NAME, "Version")
            version = ok and value or nil
        end
        if version then
            local text = W.Text(sidebar, 11, W.DIM)
            text:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 24, 16)
            text:SetText("Version " .. version)
        end
        window.sidebar = sidebar
    end

    ---------------------------------------------------------------------------
    -- THE HEADER: the title, and the two things that are the whole UI's -
    -- placing it (one unlock for everything, with a grid) and resetting it -
    -- always in reach. Dragging it moves the window.
    ---------------------------------------------------------------------------

    local UNLOCK_LABEL, LOCK_LABEL = "Unlock UI", "Lock UI"

    function Options.Close()
        if not window then return end
        W.ClosePopup()
        window.closing = true
        Style.FadeOut(window)
    end

    local function BuildHeader()
        local header = CreateFrame("Frame", nil, window)
        header:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
        header:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
        header:SetHeight(HEADER)
        header:EnableMouse(true)
        header:RegisterForDrag("LeftButton")
        header:SetScript("OnDragStart", function() window:StartMoving() end)
        header:SetScript("OnDragStop", function()
            window:StopMovingOrSizing()
            W.SnapBorders()
        end)
        local rule = W.Flat(header, "ARTWORK", W.FAINT)
        rule:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
        rule:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
        rule:SetHeight(W.Pixel(header))

        local icon = header:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(Core.MEDIA .. "icon")
        icon:SetSize(24, 24)
        icon:SetPoint("LEFT", header, "LEFT", 18, 0)
        local title = W.Text(header, 16, W.GOLD, true)
        title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
        title:SetText(TITLE)

        local close = W.IconButton(header, "close", 28, Options.Close)
        close:SetPoint("RIGHT", header, "RIGHT", -12, 0)
        window.closeButton = close

        local reset = W.TwoStep(header, "Reset everything", "Really reset?", 140, function()
            if Core:ResetAll() then
                Options.Say(true, "Everything is back to its defaults.")
            else
                Options.Say(false, "The UI cannot be reset in combat.")
            end
            Refresh()
        end)
        reset:SetPoint("RIGHT", close, "LEFT", -12, 0)
        W.Tooltip(reset, "Reset everything",
            "Every setting, size and position back to its default. Your cooldown list and your profiles stay.")
        window.resetButton = reset

        local unlock = W.Button(header, UNLOCK_LABEL, 110, function()
            if not Core.ToggleUnlocked() then
                Options.Say(false, "The UI cannot be unlocked in combat.")
            end
            Refresh()
        end)
        unlock:SetPoint("RIGHT", reset, "LEFT", -8, 0)
        W.Tooltip(unlock, "Unlock UI",
            "Drag anything on screen to move it; a grid shows to line things up. Right-click any of it, or click here again, to lock.")
        Register(function()
            local unlocked = Core.IsUnlocked()
            W.SetLabel(unlock, unlocked and LOCK_LABEL or UNLOCK_LABEL)
            W.SetStyle(unlock, unlocked and "active" or nil)
        end)
        window.unlockButton = unlock
    end

    ---------------------------------------------------------------------------
    -- THE WINDOW
    ---------------------------------------------------------------------------

    local function BuildPage()
        scrollFrame = CreateFrame("ScrollFrame", nil, window)
        scrollFrame:SetPoint("TOPLEFT", window, "TOPLEFT", SIDEBAR + PAD - INSET, -HEADER - 1)
        scrollFrame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD - GUTTER + INSET, 1)
        content = CreateFrame("Frame", PANEL_NAME .. "Page", scrollFrame)
        content:SetWidth(CONTENT_WIDTH + 2 * INSET)
        content:SetHeight(1)
        scrollFrame:SetScrollChild(content)
        window.page = content

        if describe then describe(NewPage()) end

        scroller = Core.ScrollBar.Attach(scrollFrame, Follow)
        -- Scrolling by hand lets the page say which section is being read.
        scrollFrame:HookScript("OnMouseWheel", function() clicked = nil end)
        scrollFrame:HookScript("OnMouseWheel", W.ClosePopup)
        Options.scroller = scroller
    end

    local function Build()
        if window then return end
        window = CreateFrame("Frame", PANEL_NAME, UIParent)
        window:SetSize(WIDTH, HEIGHT)
        window:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
        window:SetFrameStrata("DIALOG")
        window:SetToplevel(true)
        window:SetMovable(true)
        window:SetClampedToScreen(true)
        window:EnableMouse(true)
        window:Hide()
        local bg = W.Flat(window, "BACKGROUND", BACKGROUND)
        bg:SetAllPoints(window)
        window.border = Style.AddBorder(window)
        W.KeepSnapped(window.border)
        Options.window = window

        BuildHeader()
        BuildPage()
        BuildSidebar()
        BuildToast()

        -- Esc closes it, as it does the game's own windows.
        if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, PANEL_NAME) end

        window:SetScript("OnShow", function(self)
            self.closing = false
            Relayout()
            Refresh()
            Follow(scrollFrame:GetVerticalScroll())
        end)
        window:SetScript("OnHide", function(self)
            self.closing = false
            W.ClosePopup()
        end)
    end

    function Options.Describe(build)
        describe = build
    end

    function Options.Open()
        Build()
        window.closing = false
        Style.FadeIn(window)
    end

    function Options.IsShown()
        return window ~= nil and window:IsShown() and not window.closing
    end

    function Options.Toggle()
        if Options.IsShown() then Options.Close() else Options.Open() end
    end

    function Options.Refresh()
        if window and window:IsShown() then Refresh() end
    end
    Core.RefreshOptions = Options.Refresh
end
