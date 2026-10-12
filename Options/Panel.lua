-- The options window: a header (Quick Keybinds, Unlock UI, Reset everything),
-- a sidebar of sections and one scrolling page of cards, built on first open;
-- changes apply at once. Also the game menu's button to it and the first
-- start's Install question.

local Options = {}
DogsForeverUI.Options = Options

do -- private scope
    local Core = DogsForeverUI
    local Style = Core.Style
    local W = Core.Widgets
    local PANEL_NAME = Core.ADDON_NAME .. "Options"

    local WIDTH, HEIGHT = 920, 640
    local HEADER = 60
    local SIDEBAR = 210
    local PAD = 32                  -- the page's margins, left and right
    local GUTTER = 14               -- room for the scrollbar
    local INSET = 4                 -- so a card's outline is not cut off
    local CONTENT_WIDTH = WIDTH - SIDEBAR - 2 * PAD - GUTTER - 2 * INSET
    local CARD_PAD = 20
    local ROW_MIN = 50
    local TOP_PAD = 20
    local HEADING = 30
    local SECTION_GAP = 36
    local NAV_ROW = 36
    local BUTTON_HEIGHT = 28        -- the header's
    local SEPARATOR = { 1, 1, 1, 0.06 }
    local STRIPE = { 1, 1, 1, 0.025 }
    local SIDEBAR_SHADE = { 0, 0, 0, 0.3 }
    local GLOW = 0.08               -- the gold light at the window's top
    local UNLOCK_LABEL, LOCK_LABEL = "Unlock UI", "Lock UI"

    local window, content, scrollFrame, scroller, toast
    local refreshers = {}
    local sections = {}
    Options.sections = sections
    Options.controls = {}           -- ["Section/Label"] = the row's control

    local function Refresh()
        for index = 1, #refreshers do refreshers[index]() end
    end

    local function Register(refresh)
        refreshers[#refreshers + 1] = refresh
    end

    local function Gold(alpha)
        return CreateColor(W.GOLD[1], W.GOLD[2], W.GOLD[3], alpha)
    end

    function Options.Percent(value)
        return string.format("%d%%", math.floor((value or 0) * 100 + 0.5))
    end

    -- The layers a piece can be drawn in (Unlock Mode's Layer choice).
    local STRATA = {}
    for _, value in ipairs({ "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG",
                             "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }) do
        STRATA[#STRATA + 1] = { value = value, label = value:sub(1, 1) .. value:sub(2):lower():gsub("_d", " d") }
    end
    Options.STRATA = STRATA

    -- What a click did, in the toast at the window's foot: a green or red
    -- mark, and a longer stay if it failed.
    local function Say(ok, message)
        if not message then return end
        toast.text:SetText(message)
        W.Colour(toast.dot, ok and W.GOOD or W.BAD)
        W.SetTextColour(toast.text, ok and W.TEXT or W.BAD)
        toast:SetWidth(math.min(WIDTH - SIDEBAR - 40, toast.text:GetStringWidth() + 40))
        toast.message = message
        Style.FadeIn(toast)
        local token = (toast.token or 0) + 1
        toast.token = token
        C_Timer.After(ok and 3 or 6, function()
            if toast.token == token then Style.FadeOut(toast) end
        end)
    end

    ---------------------------------------------------------------------------
    -- The page: sections top to bottom, each a heading, an optional note and
    -- a card of rows. Rows Measure() themselves, so a list that grows lays
    -- the page out again.
    ---------------------------------------------------------------------------

    local function Relayout()
        local y = TOP_PAD
        for _, section in ipairs(sections) do
            section.top = y
            section.heading:ClearAllPoints()
            section.heading:SetPoint("TOPLEFT", content, "TOPLEFT", INSET, -y)
            y = y + HEADING
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
                row.stripe:SetShown(index % 2 == 0)
                inside = inside + height
            end
            card:SetHeight(math.max(1, inside))
            y = y + inside + SECTION_GAP
        end
        content:SetHeight(y - SECTION_GAP + 40)
        scroller.Update()
        W.SnapBorders()
    end

    -- A full row also closes a half-filled pair of small switches.
    local function AddRow(section, row)
        row:SetWidth(CONTENT_WIDTH)
        row.stripe = W.Flat(row, "BACKGROUND", STRIPE, -1)
        row.stripe:SetAllPoints(row)
        section.rows[#section.rows + 1] = row
        section.pair = nil
    end

    -- A wash under the mouse.
    local function AddHover(frame)
        frame.hover = W.Flat(frame, "BACKGROUND", W.WASH)
        frame.hover:SetAllPoints(frame)
        frame.hover:Hide()
        frame:SetScript("OnEnter", function(self) self.hover:Show() end)
        frame:SetScript("OnLeave", function(self) self.hover:Hide() end)
    end

    -- The getter and setter of the setting `entry` names: its module redraws,
    -- the page too unless `quiet` (a slider being dragged).
    local function Setting(entry, quiet)
        local module, db = entry.module, entry.module.db
        local function Get() return db[entry.key] end
        local function Set(value)
            db[entry.key] = value
            if module.Refresh then module.Refresh() end
            if not quiet then Refresh() end
        end
        return Get, Set
    end

    local Page = {}
    Page.__index = Page

    function Page:Section(title, note)
        local section = { title = title, rows = {} }
        section.heading = W.Text(content, 17, W.GOLD, true)
        section.heading:SetText(title)
        -- A rule running off the heading to the page's edge, fading out.
        local rule = W.Flat(content, "ARTWORK", W.GOLD)
        rule:SetPoint("LEFT", section.heading, "RIGHT", 12, 0)
        rule:SetSize(math.max(0, CONTENT_WIDTH - section.heading:GetStringWidth() - 12), W.Pixel(content))
        rule:SetGradient("HORIZONTAL", Gold(0.45), Gold(0))
        if note then
            section.note = W.Text(content, 12, W.MUTED, false, CONTENT_WIDTH)
            section.note:SetText(note)
        end
        section.card = W.Card(content)
        section.card:SetWidth(CONTENT_WIDTH)
        sections[#sections + 1] = section
        self.section = section
    end

    -- A row: a name, what it does, its control on the right. `clickable`:
    -- the whole row presses the control.
    local function SettingRow(page, label, description, controlWidth, clickable)
        local row = CreateFrame(clickable and "Button" or "Frame", nil, page.section.card)
        if clickable then
            row:RegisterForClicks("LeftButtonUp")
            AddHover(row)
        end

        local textWidth = CONTENT_WIDTH - 2 * CARD_PAD - controlWidth - 24
        row.label = W.Text(row, 14, W.TEXT)
        row.label:SetWidth(textWidth)
        row.label:SetText(label)
        row.label:SetPoint("TOPLEFT", row, "TOPLEFT", CARD_PAD, description and -14 or -18)
        if description then
            row.description = W.Text(row, 12, W.MUTED, false, textWidth)
            row.description:SetText(description)
            row.description:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
            row.description:SetPoint("TOPRIGHT", row.label, "BOTTOMLEFT", textWidth, -4)
        end
        function row.Measure()
            local height = 14 + (row.label:GetStringHeight() or 14) + 14
            if row.description then height = height + 4 + W.FitText(row.description) end
            return math.max(ROW_MIN, height)
        end
        AddRow(page.section, row)
        return row
    end

    local function Keep(page, label, control)
        Options.controls[page.section.title .. "/" .. label] = control
        Register(control.Refresh)
    end

    -- entry = { module, key, label, tooltip, compact }: compact switches
    -- share a row two by two, with no line under their names.
    function Page:Check(entry)
        local Get, Set = Setting(entry)
        local row
        if entry.compact then
            local section = self.section
            local pair = section.pair
            if not pair or pair.count == 2 then
                pair = CreateFrame("Frame", nil, section.card)
                pair.count = 0
                function pair.Measure() return 44 end
                AddRow(section, pair)
                section.pair = pair
            end
            local half = (CONTENT_WIDTH - 2 * CARD_PAD) / 2
            row = CreateFrame("Button", nil, pair)
            row:SetSize(half - 12, 34)
            row:SetPoint("LEFT", pair, "LEFT", CARD_PAD + pair.count * (half + 12) - 6, 0)
            row:RegisterForClicks("LeftButtonUp")
            AddHover(row)
            row.label = W.Text(row, 14, W.TEXT)
            row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
            row.label:SetText(entry.label)
            pair.count = pair.count + 1
        else
            row = SettingRow(self, entry.label, entry.tooltip, W.TOGGLE_WIDTH, true)
        end
        local toggle = W.Toggle(row, Get, Set)
        toggle:SetPoint("RIGHT", row, "RIGHT", entry.compact and -6 or -CARD_PAD, 0)
        row:SetScript("OnClick", function() Set(not Get()) end)
        toggle.row = row
        Keep(self, entry.label, toggle)
    end

    -- entry = { module, key, label, tooltip, choices = { { value, label } }, segmentWidth }
    function Page:Choice(entry)
        local width = entry.segmentWidth or 72
        local row = SettingRow(self, entry.label, entry.tooltip, width * #entry.choices)
        local control = W.Segmented(row, entry.choices, width, Setting(entry))
        control:SetPoint("RIGHT", row, "RIGHT", -CARD_PAD, 0)
        Keep(self, entry.label, control)
    end

    -- entry = { module, key, label, description, min, max, step, text }
    local SLIDER_WIDTH, SLIDER_VALUE = 180, 52
    function Page:Slider(entry)
        local row = SettingRow(self, entry.label, entry.description, SLIDER_WIDTH + SLIDER_VALUE)
        local slider = W.Slider(row, SLIDER_WIDTH, entry, Setting(entry, true))
        slider:SetPoint("RIGHT", row, "RIGHT", -CARD_PAD - SLIDER_VALUE, 0)
        Keep(self, entry.label, slider)
    end

    ---------------------------------------------------------------------------
    -- Lists the player builds: a box and a button to add, a line per entry.
    ---------------------------------------------------------------------------

    local LIST_TOP = 60             -- the add row, above the entries
    local ENTRY = 38
    local ICON = 22
    local CHOICE_SEGMENT = 74
    local FIXED_TRACK = { buff = "Duration", cooldown = "Cooldown" }

    local function Line(parent)
        local line = CreateFrame("Frame", nil, parent)
        line:SetSize(CONTENT_WIDTH, ENTRY)
        line:EnableMouse(true)
        AddHover(line)
        W.Hairline(line, SEPARATOR, 0, CARD_PAD, CARD_PAD)
        return line
    end

    -- The box (named PANEL_NAME .. `boxName`, `hint` while empty) on top,
    -- `empty` said while there is no line.
    local function ListRow(page, empty, boxName, maxLetters, hint)
        local row = CreateFrame("Frame", nil, page.section.card)
        row.count = 0
        row.lines = {}
        function row.Measure()
            return LIST_TOP + math.max(1, row.count) * ENTRY + 8
        end
        row.empty = W.Text(row, 12, W.DIM)
        row.empty:SetPoint("TOPLEFT", row, "TOPLEFT", CARD_PAD, -(LIST_TOP + 12))
        row.empty:SetText(empty)
        AddRow(page.section, row)
        row.box = W.TextBox(row, PANEL_NAME .. boxName, 220, maxLetters, hint)
        row.box:SetPoint("TOPLEFT", row, "TOPLEFT", CARD_PAD, -18)
        return row
    end

    -- A line per item (MakeLine() as needed, then fill(line, item, index)),
    -- the rest hidden; the page laid out again if the count changed.
    local function ShowLines(row, items, MakeLine, fill)
        for index, item in ipairs(items) do
            local line = row.lines[index] or MakeLine()
            row.lines[index] = line
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -(LIST_TOP + (index - 1) * ENTRY))
            line:Show()
            fill(line, item, index)
        end
        row.empty:SetShown(#items == 0)
        for index = #items + 1, #row.lines do row.lines[index]:Hide() end
        if row.count ~= #items then
            row.count = #items
            Relayout()
        end
    end

    -- The cooldown manager's list (Cooldowns\Cooldowns.lua): an ID box and
    -- Add, then a line per entry with what it tracks (a choice where there
    -- is one) and a cross.
    function Page:Cooldowns()
        local Cooldowns = Core.Cooldowns
        local row = ListRow(self, "Nothing tracked yet. Type an ID above - Add works out whether it is a spell or an item.",
            "IdBox", 24, "Spell or item ID")
        local box = row.box
        local function Add()
            local ok, message = Cooldowns.AddID(box:GetText())
            Say(ok, message)
            if ok then
                box:SetText("")
                box:ShowHint()
            end
            box:ClearFocus()
            Refresh()
        end
        row.add = W.Button(row, "Add", 80, Add)
        row.add:SetPoint("LEFT", box, "RIGHT", 10, 0)
        box:SetScript("OnEnterPressed", Add)

        local function MakeLine()
            local line = Line(row)
            line.icon = line:CreateTexture(nil, "ARTWORK")
            line.icon:SetSize(ICON, ICON)
            line.icon:SetPoint("LEFT", line, "LEFT", CARD_PAD, 0)
            line.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            line.text = W.Text(line, 13)
            line.text:SetPoint("LEFT", line.icon, "RIGHT", 10, 0)
            line.text:SetWidth(CONTENT_WIDTH - 2 * CARD_PAD - ICON - 10 - CHOICE_SEGMENT * #Cooldowns.TRACK - 50)
            line.remove = W.IconButton(line, "close", 22, function()
                Cooldowns.Remove(line.index)
                Refresh()
            end)
            line.remove:SetPoint("RIGHT", line, "RIGHT", -CARD_PAD + 4, 0)
            W.Tooltip(line.remove, "Remove", "Stop tracking this.")
            line.choice = W.Segmented(line, Cooldowns.TRACK, CHOICE_SEGMENT,
                function()
                    local entry = line.index and Cooldowns.db.tracked[line.index]
                    return entry and Cooldowns.TrackOf(entry)
                end,
                function(value)
                    Cooldowns.SetTrack(line.index, value)
                    Refresh()
                end)
            line.choice:SetPoint("RIGHT", line.remove, "LEFT", -12, 0)
            -- Nothing to choose: what it tracks, in words, in the same place.
            line.fixed = W.Text(line, 12, W.MUTED)
            line.fixed:SetPoint("LEFT", line.choice, "LEFT", 8, 0)
            return line
        end

        local function Fill(line, entry, index)
            line.index = index
            local name, icon = Cooldowns.Describe(entry)
            line.icon:SetTexture(icon)
            line.text:SetText(name .. "  |cff808080" .. entry.kind .. " " .. entry.id .. "|r")
            local choose = Cooldowns.HasChoice(entry)
            line.choice:SetShown(choose)
            line.fixed:SetShown(not choose)
            if choose then
                line.choice.Refresh()
            else
                line.fixed:SetText(FIXED_TRACK[Cooldowns.TrackOf(entry)] or "Nothing to track")
            end
        end

        Register(function() ShowLines(row, Cooldowns.db.tracked, MakeLine, Fill) end)
        Options.idList = row
    end

    -- The profiles (DogsForeverUI.lua): a name and Save (asking when the name
    -- is taken), then a line per profile with Load and Delete, which always
    -- ask. A name clicked goes into the box.
    function Page:Profiles()
        local Profiles = Core.Profiles
        local row = ListRow(self, "No profiles yet.", "ProfileName", Profiles.MAX_NAME, "Profile name")
        local box = row.box
        row.save = W.TwoStep(row, "Save", "Overwrite?", 96, function()
            Say(Profiles.Save(box:GetText()))
            box:ClearFocus()
            Refresh()
        end, function() return Profiles.Exists(box:GetText()) end)
        row.save:SetPoint("LEFT", box, "RIGHT", 10, 0)
        box:SetScript("OnEnterPressed", row.save.press)

        local function MakeLine()
            local line = Line(row)
            line.name = W.Button(line, "", 260, function()
                box:SetText(line.profile)
                box:ShowHint()
            end, "flat")
            line.name:SetPoint("LEFT", line, "LEFT", CARD_PAD - 6, 0)
            line.name.label:ClearAllPoints()
            line.name.label:SetPoint("LEFT", line.name, "LEFT", 6, 0)
            line.name.label:SetFont(Style.FONT, 13, "")
            line.delete = W.TwoStep(line, "Delete", "Really delete?", 110, function()
                Say(Profiles.Delete(line.profile))
                Refresh()
            end)
            line.delete:SetPoint("RIGHT", line, "RIGHT", -CARD_PAD, 0)
            line.load = W.TwoStep(line, "Load", "Really load?", 110, function()
                Say(Profiles.Load(line.profile))
                Refresh()
            end)
            line.load:SetPoint("RIGHT", line.delete, "LEFT", -8, 0)
            return line
        end

        local function Fill(line, name)
            if line.profile ~= name then
                line.load.disarm()
                line.delete.disarm()
            end
            line.profile = name
            W.SetLabel(line.name, name)
        end

        Register(function() ShowLines(row, Profiles.Names(), MakeLine, Fill) end)
        Options.profileList = row
    end

    ---------------------------------------------------------------------------
    -- What the page shows. Everything is always on (no Enabled anywhere);
    -- sizes, places and each piece's own settings are in Unlock Mode.
    ---------------------------------------------------------------------------

    local function Describe(page)
        local Menus, Cooldowns, Fishing, Skinning = Core.Menus, Core.Cooldowns, Core.Fishing, Core.Skinning
        local Bars = Menus.ActionBars

        page:Section("Cooldown manager",
            "Bars for the spells and items you add by ID - hover anything to see its ID. A spell tracks its cooldown, or the duration of its buff while it is on you (any rank); once you have cast it out of combat and its buff was seen, a spell with both lets you pick. Items track their cooldown. The bars sit in line with the castbar, over the player frame.")
        page:Check({ module = Cooldowns, key = "showTooltipIDs", label = "IDs on tooltips" })
        page:Choice({
            module = Cooldowns, key = "growDirection", label = "Bars grow",
            choices = Cooldowns.GROW, segmentWidth = 84,
        })
        page:Cooldowns()

        page:Section("Auto-hide",
            "Each of these stays out of sight until the mouse is over it. Buttons and keybindings work as always, and the bars show while Edit Mode is open or something is on the cursor.")
        page:Check({ module = Menus, key = "quietMicroMenu", label = "Micro Menu", compact = true })
        for _, entry in ipairs(Bars.LIST) do
            page:Check({ module = Menus, key = entry.key, label = entry.label, compact = true })
        end
        page:Slider({
            module = Menus, key = "fadeOutDelay", label = "Hide after",
            description = "How long after the mouse leaves before it fades out.",
            min = Bars.MIN_DELAY, max = Bars.MAX_DELAY, step = 0.1,
            text = function(value) return string.format("%.1fs", value or 0) end,
        })

        page:Section("Extras", "Small helpers for chat, professions and tooltips.")
        page:Check({ module = Core.Chat, key = "showButton", label = "Chat copy button",
            tooltip = "A button above the chat menu button opens the chat tab you are looking at in a window you can copy from." })
        page:Check({ module = Menus, key = "hideIssueReporter", label = "Hide the Issue Reporter",
            tooltip = "Takes the beta's box and its \"Press F6\" lines off tooltips. F6 still works." })
        page:Check({ module = Fishing, key = "fishing", label = "Double-click fishing",
            tooltip = "Double right-click in the world with a fishing pole in hand to cast Fishing." })
        page:Check({ module = Fishing, key = "camping", label = "Double-click camping",
            tooltip = "Double right-click a Basic Campfire to sit down." })
        page:Check({ module = Skinning, key = "showSkinnable", label = "Skinnable on tooltips",
            tooltip = "Shows the skill a creature takes to skin, coloured like a recipe, once one like it has been confirmed skinnable." })
        page:Check({ module = Skinning, key = "showCloth", label = "Cloth on tooltips",
            tooltip = "Names the cloth a creature drops, once you have seen it in the loot of one like it." })

        page:Section("Profiles",
            "Save every setting on this page under a name, for any of your characters to load. Loading one replaces this character's settings; the cooldown list stays each character's own.")
        page:Profiles()
    end

    ---------------------------------------------------------------------------
    -- The sidebar: the page's table of contents.
    ---------------------------------------------------------------------------

    local active, clicked

    local function SetActive(section)
        active = section
        for _, entry in ipairs(sections) do
            local button = entry.nav
            button.selected = entry == section
            button.accent:SetShown(button.selected)
            button.glow:SetShown(button.selected)
            W.PaintButton(button)
        end
    end
    function Options.Active() return active end

    -- The section being read: the last whose heading reached the top, or the
    -- last one at the page's end. One picked in the sidebar stays lit until
    -- the page is scrolled by hand.
    local function Follow(y)
        if clicked then return end
        local current = sections[1]
        for _, section in ipairs(sections) do
            if section.top and section.top - TOP_PAD <= y + 8 then current = section end
        end
        if y >= scroller.Limit() - 1 and scroller.Limit() > 0 then
            current = sections[#sections]
        end
        if current ~= active then SetActive(current) end
    end

    local function GoTo(section)
        clicked = section
        SetActive(section)
        scroller.ScrollTo((section.top or 0) - TOP_PAD)
    end

    local function BuildSidebar()
        local sidebar = CreateFrame("Frame", nil, window)
        sidebar:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -HEADER)
        sidebar:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 0, 0)
        sidebar:SetWidth(SIDEBAR)
        W.Flat(sidebar, "BACKGROUND", SIDEBAR_SHADE):SetAllPoints(sidebar)
        local rule = W.Flat(sidebar, "ARTWORK", W.FAINT)
        rule:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
        rule:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)
        rule:SetWidth(W.Pixel(sidebar))

        -- The picked entry: a gold bar on its left edge, a gold light off it.
        for index, section in ipairs(sections) do
            local button = W.Button(sidebar, section.title, SIDEBAR, function() GoTo(section) end, "nav")
            button:SetHeight(NAV_ROW)
            button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, -16 - (index - 1) * NAV_ROW)
            button.label:ClearAllPoints()
            button.label:SetPoint("LEFT", button, "LEFT", 24, 0)
            button.label:SetFont(Style.FONT, 14, "")
            button.glow = W.Flat(button, "BORDER", W.GOLD)
            button.glow:SetAllPoints(button)
            button.glow:SetGradient("HORIZONTAL", Gold(0.15), Gold(0))
            button.glow:Hide()
            button.accent = W.Flat(button, "ARTWORK", W.GOLD)
            button.accent:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
            button.accent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
            button.accent:SetWidth(3)
            button.accent:Hide()
            section.nav = button
        end

        local version = C_AddOns.GetAddOnMetadata(Core.ADDON_NAME, "Version")
        if version then
            local text = W.Text(sidebar, 11, W.DIM)
            text:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 24, 16)
            text:SetText("Version " .. version)
        end
    end

    ---------------------------------------------------------------------------
    -- The header: the title, Quick Keybinds, Unlock UI, Reset everything and
    -- a close; dragging it moves the window.
    ---------------------------------------------------------------------------

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
        -- A gold light from the top, and a gold rule under it, brightest in
        -- the middle.
        local glow = W.Flat(header, "BACKGROUND", W.GOLD)
        glow:SetAllPoints(header)
        glow:SetGradient("VERTICAL", Gold(0), Gold(GLOW))
        for _, half in ipairs({ { "BOTTOMLEFT", 0, 0.6 }, { "BOTTOMRIGHT", 0.6, 0 } }) do
            local rule = W.Flat(header, "ARTWORK", W.GOLD)
            rule:SetPoint(half[1], header, half[1], 0, 0)
            rule:SetSize(WIDTH / 2, W.Pixel(header))
            rule:SetGradient("HORIZONTAL", Gold(half[2]), Gold(half[3]))
        end

        local icon = header:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(Core.MEDIA .. "icon")
        icon:SetSize(30, 30)
        icon:SetPoint("LEFT", header, "LEFT", 20, 0)
        local title = W.Text(header, 18, W.GOLD, true)
        title:SetPoint("LEFT", icon, "RIGHT", 12, 0)
        title:SetText(Core.TITLE)

        local close = W.IconButton(header, "close", 30, Options.Close)
        close:SetPoint("RIGHT", header, "RIGHT", -14, 0)
        window.closeButton = close

        local reset = W.TwoStep(header, "Reset everything", "Really reset?", 140, function()
            if Core:ResetAll() then
                Say(true, "Everything is back to its defaults.")
            else
                Say(false, "The UI cannot be reset in combat.")
            end
            Refresh()
        end)
        reset:SetHeight(BUTTON_HEIGHT)
        reset:SetPoint("RIGHT", close, "LEFT", -12, 0)
        W.Tooltip(reset, "Reset everything",
            "Every setting, size and position back to its default. Your cooldown list and your profiles stay.")
        window.resetButton = reset

        -- Unlock Mode (Options\Unlock.lua): this window makes way for it.
        local unlock = W.Button(header, UNLOCK_LABEL, 110, function()
            Core.ToggleUnlocked()
            Refresh()
        end, "primary")
        unlock:SetHeight(BUTTON_HEIGHT)
        unlock:SetPoint("RIGHT", reset, "LEFT", -8, 0)
        Register(function()
            local unlocked = Core.IsUnlocked()
            W.SetLabel(unlock, unlocked and LOCK_LABEL or UNLOCK_LABEL)
            W.SetStyle(unlock, unlocked and "active" or "primary")
        end)
        window.unlockButton = unlock

        local keybinds = W.Button(header, "Quick Keybinds", 130, function()
            if InCombatLockdown() then
                Say(false, "Keys cannot be bound in combat.")
                return
            end
            Options.Keybinds.Open()
        end)
        keybinds:SetHeight(BUTTON_HEIGHT)
        keybinds:SetPoint("RIGHT", unlock, "LEFT", -8, 0)
        window.keybindsButton = keybinds
    end

    ---------------------------------------------------------------------------
    -- The window
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

        Describe(setmetatable({}, Page))

        scroller = W.Scroller(scrollFrame, Follow)
        -- Scrolling by hand: the page says again which section is read.
        scrollFrame:HookScript("OnMouseWheel", function()
            clicked = nil
            W.ClosePopup()
        end)
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
        W.Flat(window, "BACKGROUND", Style.WINDOW_BACKGROUND):SetAllPoints(window)
        window.border = Style.AddBorder(window)
        W.KeepSnapped(window.border)
        Options.window = window

        BuildHeader()
        BuildPage()
        BuildSidebar()
        toast = W.Toast(window)
        toast:SetHeight(30)
        toast:SetPoint("BOTTOM", window, "BOTTOM", SIDEBAR / 2, 18)

        -- Esc closes it, as the game's own windows.
        table.insert(UISpecialFrames, PANEL_NAME)

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

    function Core.RefreshOptions()
        if window and window:IsShown() then Refresh() end
    end

    ---------------------------------------------------------------------------
    -- The game menu's (Esc) button, EllesmereUI's way: the game's button
    -- template in gold, under Options (or the Shop). Nothing of the game's is
    -- written to: its buttons below only moved, the menu only made taller.
    ---------------------------------------------------------------------------

    local GameMenu = {}
    Options.GameMenu = GameMenu
    GameMenu.LABEL = Core.TITLE
    GameMenu.LIGHT = Style.GOLD
    GameMenu.ROOM = 40              -- what it adds to the menu: its height and the gap
    GameMenu.lifts = {}             -- button -> { piece key -> its gold copy }
    local MENU_GAP = 12             -- above it
    local LIFT = 0.65               -- how much gold the added copy brings
    local PIECES = { "Left", "Center", "Right" }

    -- Its art and hover glow greyed and tinted gold (kept through the
    -- template's own pressed/released updates). Tinting alone left the greyed
    -- red art a dark gold: a copy of each piece is added over it (ADD blend).
    local function Tint(self)
        local light, copies = GameMenu.LIGHT, GameMenu.lifts[self]
        for _, key in ipairs(PIECES) do
            local texture = self[key]
            texture:SetDesaturated(true)
            texture:SetVertexColor(light[1], light[2], light[3], 1)
            local copy = copies[key]
            if not copy then
                copy = self:CreateTexture(nil, "BACKGROUND", nil, 1)
                copy:SetAllPoints(texture)
                copy:SetBlendMode("ADD")
                copies[key] = copy
            end
            local atlas = texture:GetAtlas()
            if atlas then copy:SetAtlas(atlas) end
            copy:SetTexCoord(texture:GetTexCoord())
            copy:SetDesaturated(true)
            copy:SetVertexColor(light[1], light[2], light[3], LIFT)
            copy:SetShown(atlas ~= nil)
        end
        local glow = self:GetHighlightTexture()
        if glow then
            glow:SetDesaturated(true)
            glow:SetVertexColor(light[1], light[2], light[3], 1)
        end
    end

    local function BuildMenuButton(menu)
        local button = CreateFrame("Button", Core.ADDON_NAME .. "GameMenuButton", menu, "MainMenuFrameButtonTemplate")
        button:SetSize(200, 35)
        button:SetText(GameMenu.LABEL)
        GameMenu.lifts[button] = {}
        Tint(button)
        hooksecurefunc(button, "UpdateButton", Tint)
        -- Resized, the template re-cuts its end pieces: the copies follow.
        button:HookScript("OnSizeChanged", Tint)
        -- In combat too: neither the menu nor the options are protected.
        button:SetScript("OnClick", function()
            HideUIPanel(menu)
            Options.Open()
        end)
        GameMenu.button = button
    end

    -- Each layout: under Options (or the Shop under it), the game's buttons
    -- below moved down, the menu's own height made taller.
    hooksecurefunc(GameMenuFrame, "Layout", function(menu)
        if not GameMenu.button then BuildMenuButton(menu) end
        local own = GameMenu.button
        local anchor
        for gameButton in menu.buttonPool:EnumerateActive() do
            local text = gameButton:GetText()
            if text == BLIZZARD_STORE then
                anchor = gameButton
                break
            elseif text == GAMEMENU_OPTIONS then
                anchor = gameButton
            end
        end
        if not anchor then
            own:Hide()
            return
        end
        local width, height = anchor:GetWidth(), anchor:GetHeight()
        if width and width > 0 then own:SetSize(width, height or 35) end
        own:ClearAllPoints()
        own:SetPoint("TOP", anchor, "BOTTOM", 0, -MENU_GAP)
        own:Show()
        -- Its art: the template sets it only in its OnShow, which never ran
        -- for a button made while the menu showed.
        own:UpdateButton()
        Tint(own)

        local bottom = anchor:GetBottom()
        if bottom then
            for gameButton in menu.buttonPool:EnumerateActive() do
                local top = gameButton:GetTop()
                if top and top < bottom + 2 then
                    local point, relative, relativePoint, x, y = gameButton:GetPoint(1)
                    if point then
                        gameButton:ClearAllPoints()
                        gameButton:SetPoint(point, relative, relativePoint, x, y - GameMenu.ROOM)
                    end
                end
            end
        end
        menu:SetHeight(menu:GetHeight() + GameMenu.ROOM)
    end)

    ---------------------------------------------------------------------------
    -- The first start's question, once per character, out of combat: Install
    -- (defaults, the game's settings of Core\Defaults.lua, a reload) or
    -- Disable Addon (for this character, a reload). Never "/console
    -- cvar_default": that resets every game setting.
    ---------------------------------------------------------------------------

    local Install = {}
    Options.Install = Install
    local INSTALL_WIDTH, INSTALL_HEIGHT = 380, 150
    local INSTALL_DELAY = 1         -- after the world is up: the action bars place themselves first

    local function Installed()
        return Core.GameDefaults.db.installed == true
    end

    local function DoInstall()
        if InCombatLockdown() or not Core:ResetAll() then return end
        local db = Core.GameDefaults.db
        db.installed = true
        -- The game's settings set again once the UI is back, and checked after.
        db.done = 0
        Install.window:Hide()
        ReloadUI()
    end

    -- Not marked answered: turned on again later, it asks again.
    local function DisableAddon()
        if InCombatLockdown() then return end
        local name = UnitName("player")
        if issecretvalue(name) or not name or name == "" then
            C_AddOns.DisableAddOn(Core.ADDON_NAME)
        else
            C_AddOns.DisableAddOn(Core.ADDON_NAME, name)
        end
        C_AddOns.SaveAddOns()
        Install.window:Hide()
        ReloadUI()
    end

    local function BuildQuestion()
        local question = Options.Unlock.NewWindow("Install", INSTALL_WIDTH, INSTALL_HEIGHT, "FULLSCREEN_DIALOG")
        question:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        question.title = W.Text(question, 16, W.GOLD, true)
        question.title:SetPoint("TOP", question, "TOP", 0, -18)
        question.title:SetText(Core.TITLE)
        question.text = W.Text(question, 12, W.TEXT, false, INSTALL_WIDTH - 40)
        question.text:SetPoint("TOP", question.title, "BOTTOM", 0, -12)
        question.text:SetJustifyH("CENTER")
        question.text:SetText("Set up Dog's Forever UI? Every setting of the addon goes back to its default, "
            .. "the game's settings it is built around are set, and the UI reloads.")
        question.install = W.Button(question, "Install", 120, DoInstall, "active")
        question.install:SetPoint("BOTTOMLEFT", question, "BOTTOM", 4, 16)
        question.disable = W.Button(question, "Disable Addon", 120, DisableAddon)
        question.disable:SetPoint("BOTTOMRIGHT", question, "BOTTOM", -4, 16)
        Install.window = question
    end

    -- Asked now, if still to be asked and it can be.
    function Install.Ask()
        if Installed() or InCombatLockdown() or not Core.SettingsTrusted() then return false end
        if not Install.window then BuildQuestion() end
        Install.window:Show()
        return true
    end

    -- Tried every half second from INSTALL_DELAY on, until asked.
    local since = 0
    local wake, events = Core.Waker(function(elapsed)
        since = since + elapsed
        if since < INSTALL_DELAY then return true end
        since = INSTALL_DELAY - 0.5
        return not (Installed() or Install.Ask())
    end)
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            -- A fight: put away, asked again after.
            if not (Install.window and Install.window:IsShown()) then return end
            Install.window:Hide()
        elseif Installed() then
            return
        end
        since = 0
        wake()
    end)
end
