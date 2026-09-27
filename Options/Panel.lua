-- The options: one panel in the game's Settings, one page, and - listed under
-- it - a tab for the cooldown manager (the player asked for everything else in
-- one place, and for the cooldown manager on its own).
--
-- At the top, always in reach: the one Unlock UI button that places every
-- piece at once, and the one Reset everything. Under them the page scrolls, in
-- sections: each part's switches two to a row, then one Sizes section with a
-- row per element (width, heights, layer) and the text padding. Every setting
-- explains itself in its tooltip. Pages.lua describes the page; this file is
-- the widgets, the layout and the registration.
--
-- Two rules carried over: every position comes from a running cursor rather
-- than a magic number, so adding an option cannot land on top of something
-- else, and every widget registers its own refresh closure, so refreshing the
-- panel never has to know what is on it.

local Options = {}
DogsForeverUI.Options = Options

do -- private scope

    local Core = DogsForeverUI
    local TITLE = Core.TITLE
    local PANEL_NAME = Core.ADDON_NAME .. "Options"

    local panel
    local refreshers = {}

    ---------------------------------------------------------------------------
    -- Widget factories. Templates differ between clients, so every CreateFrame
    -- goes through TryCreate and a missing template costs one widget, not the
    -- panel.
    ---------------------------------------------------------------------------

    -- Current templates only, verified against the Blizzard source in this
    -- install.
    local CHECK_TEMPLATES = { "UICheckButtonTemplate", "ChatConfigCheckButtonTemplate" }
    local SLIDER_TEMPLATES = { "UISliderTemplateWithLabels", "UISliderTemplate" }
    local BUTTON_TEMPLATES = { "UIPanelButtonTemplate" }

    local EDIT_BACKDROP = {
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 26,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    }

    local function TryCreate(kind, parent, templates, name)
        for _, template in ipairs(templates) do
            local ok, widget = pcall(CreateFrame, kind, name, parent, template)
            if ok and widget then return widget end
        end
        return nil
    end

    -- Templates expose their label in different places, and on some of them
    -- `.text` is a plain string rather than a font string, so check for the
    -- method.
    local function AsFontString(candidate)
        if type(candidate) == "table" and type(candidate.SetText) == "function" then
            return candidate
        end
        return nil
    end

    local function LabelOf(widget, suffix)
        local name = widget.GetName and widget:GetName()
        return AsFontString(widget.Text)
            or AsFontString(widget.text)
            or AsFontString(name and _G[name .. (suffix or "Text")])
    end

    local function Refresh()
        for i = 1, #refreshers do refreshers[i]() end
    end

    local function AddCheck(parent, x, y, label, tooltip, get, set)
        local check = TryCreate("CheckButton", parent, CHECK_TEMPLATES)
        if not check then return nil end

        check:SetPoint("TOPLEFT", x, y)
        local text = LabelOf(check)
        if not text then
            text = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            text:SetPoint("LEFT", check, "RIGHT", 2, 0)
        end
        text:SetText(label)

        check:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
        if tooltip then
            check:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(label, 1, 1, 1)
                GameTooltip:AddLine(tooltip, nil, nil, nil, true)
                GameTooltip:Show()
            end)
            check:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        refreshers[#refreshers + 1] = function() check:SetChecked(get() and true or false) end
        return check
    end

    -- spec = { label, min, max, step, get, set, text, lowText, highText }
    local function AddSlider(parent, x, y, spec)
        local slider = TryCreate("Slider", parent, SLIDER_TEMPLATES)
        if not slider then return nil end

        slider:SetPoint("TOPLEFT", x, y)
        -- The template has no size of its own: without a height the slider is
        -- zero tall and draws nothing - bar, thumb and labels all gone, just
        -- an empty gap where it should be. 17 is Blizzard's own
        -- (OptionsSliderTemplate, the same template with a size).
        slider:SetSize(200, 17)
        slider:SetOrientation("HORIZONTAL")
        slider:SetMinMaxValues(spec.min, spec.max)
        slider:SetValueStep(spec.step)
        if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end

        local name = slider.GetName and slider:GetName()
        local title = LabelOf(slider)
        if not title then
            title = slider:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            title:SetPoint("BOTTOM", slider, "TOP", 0, 2)
        end
        local low = AsFontString(slider.Low) or AsFontString(name and _G[name .. "Low"])
        local high = AsFontString(slider.High) or AsFontString(name and _G[name .. "High"])
        if low then low:SetText(spec.lowText or spec.min) end
        if high then high:SetText(spec.highText or spec.max) end

        -- Rounded before formatting rather than left to "%d" to truncate: a
        -- slider step of 0.01 produces values like 55.00000000000001, which some
        -- Lua versions refuse to format as an integer at all.
        local function Caption(value)
            local shown = spec.text and spec.text(value)
                or string.format("%d", math.floor((value or 0) + 0.5))
            return spec.label .. ": " .. shown
        end

        slider:SetScript("OnValueChanged", function(_, value)
            value = math.floor(value / spec.step + 0.5) * spec.step
            spec.set(value)
            title:SetText(Caption(value))
        end)

        refreshers[#refreshers + 1] = function()
            local value = spec.get() or spec.min
            slider:SetValue(value)
            title:SetText(Caption(value))
        end
        return slider
    end

    local function AddButton(parent, x, y, label, width, onClick)
        local button = TryCreate("Button", parent, BUTTON_TEMPLATES)
        if not button then return nil end
        button:SetPoint("TOPLEFT", x, y)
        button:SetWidth(width)
        button:SetHeight(22)
        button:SetText(label)
        button:SetScript("OnClick", onClick)
        return button
    end

    local function AddText(parent, x, y, text, font, width)
        local fs = parent:CreateFontString(nil, "ARTWORK", font)
        fs:SetPoint("TOPLEFT", x, y)
        fs:SetJustifyH("LEFT")
        if width then
            fs:SetWidth(width)
            fs:SetWordWrap(true)
        end
        fs:SetText(text)
        return fs
    end

    -- A number box with its title above it. Anything that is not a number is
    -- put back rather than stored: a nil width reaches SetWidth and takes the
    -- bar down with it. `limits` = { min, max, decimals }, optional: a number
    -- outside min..max is put back too, and `decimals` shows tenths.
    local function AddEditBox(parent, name, x, y, title, get, set, limits)
        limits = limits or {}
        local box = CreateFrame("EditBox", name, parent,
            BackdropTemplateMixin and "BackdropTemplate" or nil)
        box:SetPoint("TOPLEFT", x, y)
        box:SetSize(75, 25)
        if box.SetBackdrop then
            box:SetBackdrop(EDIT_BACKDROP)
            box:SetBackdropColor(0, 0, 0, 1)
        end
        box:SetMultiLine(false)
        box:SetAutoFocus(false)
        -- Six, not four: a position on a tall screen is a negative four-digit
        -- number, and a shorter limit silently cut the minus sign off it.
        box:SetMaxLetters(6)
        box:SetJustifyH("CENTER")
        box:SetJustifyV("MIDDLE")
        box:SetFontObject(GameFontNormal)

        local label = box:CreateFontString(nil, "ARTWORK")
        label:SetFont(DogsForeverUI.Style.FONT, 12, "")
        label:SetPoint("TOP", 0, 12)
        label:SetText(title)

        local function Show()
            local value = get()
            if type(value) ~= "number" then
                box:SetText("")
            elseif limits.decimals then
                -- Tenths, without a trailing ".0" on a whole number.
                local text = string.format("%.1f", value):gsub("%.0$", "")
                box:SetText(text)
            else
                box:SetText(tostring(math.floor(value + 0.5)))
            end
        end

        box:SetScript("OnEnterPressed", function(self)
            local value = tonumber(self:GetText())
            if value and limits.decimals then value = math.floor(value * 10 + 0.5) / 10 end
            if value and (limits.min and value < limits.min
                          or limits.max and value > limits.max) then
                value = nil
            end
            if value then set(value) end
            Show()
            self:ClearFocus()
        end)
        box:SetScript("OnEscapePressed", function(self)
            Show()
            self:ClearFocus()
        end)

        refreshers[#refreshers + 1] = Show
        box:SetCursorPosition(0)
        return box
    end

    local STRATA = {
        "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG",
        "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP",
    }

    -- Blizzard_Menu, not UIDropDownMenu. Blizzard's own 11.0 implementation
    -- guide says UIDropDownMenu "is now deprecated", that Blizzard_Menu is "a
    -- complete replacement", and that no shims were provided. The button works
    -- out its own label from whichever radio reports itself selected.
    local function AddStrata(parent, x, y, get, set)
        local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, parent,
            "WowStyle1DropdownTemplate")
        if not ok or not dropdown then return nil end

        dropdown:SetPoint("TOPLEFT", x, y)
        dropdown:SetWidth(120)

        local function Selected(value) return get() == value end
        dropdown:SetupMenu(function(_, rootDescription)
            for _, value in ipairs(STRATA) do
                rootDescription:CreateRadio(value, Selected, set, value)
            end
        end)
        refreshers[#refreshers + 1] = function() dropdown:GenerateMenu() end
        return dropdown
    end

    -- A dropdown of named choices, Blizzard_Menu like the layer one.
    -- choices = { { value, label }, ... }
    local function AddChoice(parent, x, y, width, choices, get, set)
        local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, parent,
            "WowStyle1DropdownTemplate")
        if not ok or not dropdown then return nil end

        dropdown:SetPoint("TOPLEFT", x, y)
        dropdown:SetWidth(width)

        local function Selected(value) return get() == value end
        dropdown:SetupMenu(function(_, rootDescription)
            for _, choice in ipairs(choices) do
                rootDescription:CreateRadio(choice.label, Selected, set, choice.value)
            end
        end)
        refreshers[#refreshers + 1] = function() dropdown:GenerateMenu() end
        return dropdown
    end

    local function Percent(value)
        return string.format("%d%%", math.floor((value or 0) * 100 + 0.5))
    end
    Options.Percent = Percent

    function Options.Seconds(value)
        return string.format("%.1fs", value or 0)
    end

    ---------------------------------------------------------------------------
    -- THE PAGE: one, scrolling, in sections from top to bottom. Inside a
    -- section, settings sit two to a row in two fixed columns, so everything
    -- lines up; a section always starts on a fresh row under a heading.
    ---------------------------------------------------------------------------

    local LEFT, RIGHT = 16, 320
    local CONTENT_WIDTH = 600
    local CHECK_ROW = 26
    local SLIDER_ROW = 62
    local BOX_ROW = 52
    local CHOICE_ROW = 56
    local HEADING_ROW = 30
    local SECTION_GAP = 14

    -- The size rows: the element's name, then its boxes, then its layer.
    local SIZE_LABEL_WIDTH = 110
    local SIZE_BOX_X = LEFT + SIZE_LABEL_WIDTH
    local SIZE_BOX_STEP = 84
    local SIZE_STRATA_X = SIZE_BOX_X + 4 * SIZE_BOX_STEP + 6

    local Page = {}
    Page.__index = Page

    local function NewPage(content)
        return setmetatable({
            content = content,
            y = -8,          -- the top of the next row
            column = 1,      -- which column the next setting takes
            rowHeight = 0,   -- the tallest setting on the row being filled
            sections = 0,
        }, Page)
    end

    -- A setting changed: its module redraws, and the panel shows what the
    -- settings are now.
    function Page:Changed(module)
        if module and module.Refresh then module.Refresh() end
        Refresh()
    end

    -- Close the row being filled, if any.
    function Page:EndRow()
        if self.column == 2 then
            self.y = self.y - self.rowHeight
            self.column, self.rowHeight = 1, 0
        end
    end

    -- The next slot in the two columns, `height` tall: its x and its top.
    function Page:Slot(height)
        local x = self.column == 1 and LEFT or RIGHT
        local y = self.y
        self.rowHeight = math.max(self.rowHeight, height)
        if self.column == 1 then
            self.column = 2
        else
            self.y = self.y - self.rowHeight
            self.column, self.rowHeight = 1, 0
        end
        return x, y
    end

    function Page:Section(title)
        self:EndRow()
        if self.sections > 0 then self.y = self.y - SECTION_GAP end
        self.sections = self.sections + 1
        AddText(self.content, LEFT, self.y, title, "GameFontNormalLarge")
        local rule = self.content:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(1, 0.82, 0, 0.25)
        rule:SetPoint("TOPLEFT", self.content, "TOPLEFT", LEFT, self.y - 22)
        rule:SetSize(CONTENT_WIDTH - 2 * LEFT, 1)
        self.y = self.y - HEADING_ROW
    end

    -- entry = { module, key, label, tooltip }
    function Page:Check(entry)
        local module, db = entry.module, entry.module.db
        local x, y = self:Slot(CHECK_ROW)
        AddCheck(self.content, x, y, entry.label, entry.tooltip,
            function() return db[entry.key] end,
            function(value)
                db[entry.key] = value
                self:Changed(module)
            end)
    end

    -- A setting with a few named values, as a dropdown under its label.
    -- entry = { module, key, label, tooltip, choices = { { value, label } } }
    function Page:Choice(entry)
        local module, db = entry.module, entry.module.db
        local x, y = self:Slot(CHOICE_ROW)
        local label = AddText(self.content, x + 4, y - 4, entry.label, "GameFontHighlight")
        local dropdown = AddChoice(self.content, x + 4, y - 22, 160, entry.choices,
            function() return db[entry.key] end,
            function(value)
                db[entry.key] = value
                self:Changed(module)
            end)
        if dropdown and entry.tooltip then
            dropdown:HookScript("OnEnter", function(widget)
                GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
                GameTooltip:SetText(entry.label, 1, 1, 1)
                GameTooltip:AddLine(entry.tooltip, nil, nil, nil, true)
                GameTooltip:Show()
            end)
            dropdown:HookScript("OnLeave", function() GameTooltip:Hide() end)
        end
        return label, dropdown
    end

    -- entry = { module, key, label, min, max, step, lowText, highText, text }
    function Page:Slider(entry)
        local module, db = entry.module, entry.module.db
        local x, y = self:Slot(SLIDER_ROW)
        AddSlider(self.content, x + 4, y - 18, {
            label = entry.label, min = entry.min, max = entry.max, step = entry.step,
            lowText = entry.lowText, highText = entry.highText, text = entry.text,
            get = function() return db[entry.key] end,
            set = function(value)
                db[entry.key] = value
                if module.Refresh then module.Refresh() end
            end,
        })
    end

    -- One number box. entry = { module, key, title, min, max, decimals,
    -- onChange(old, new), placed, keepsPlacement }: onChange runs before the
    -- redraw - a width
    -- that keeps its bar centred moves the bar with it. A typed size or
    -- position is the player's, so a bar the addon was placing itself
    -- (autoPlaced) is left where it now is from then on, and `placed` names
    -- the flag that says a unit frame has been placed.
    local function Box(page, entry, x, y)
        local module, db = entry.module, entry.module.db
        return AddEditBox(page.content, PANEL_NAME .. module.key .. entry.key, x, y, entry.title,
            function() return db[entry.key] end,
            function(value)
                local old = db[entry.key]
                db[entry.key] = value
                if entry.onChange then entry.onChange(old, value) end
                if entry.placed then db[entry.placed] = true end
                if db.autoPlaced ~= nil and not entry.keepsPlacement then
                    db.autoPlaced = false
                end
                page:Changed(module)
            end,
            { min = entry.min, max = entry.max, decimals = entry.decimals })
    end

    -- A row of boxes: the element's name, then its boxes.
    -- row = { module, label, boxes = { { key, title, onChange, placed }, ... } }
    -- Answers where the row's boxes stand, for SizeRow's layer dropdown.
    function Page:Row(row)
        self:EndRow()
        local module = row.module
        local top = self.y - 16
        AddText(self.content, LEFT, top - 5, row.label, "GameFontHighlight")
        for index, entry in ipairs(row.boxes) do
            entry.module = module
            Box(self, entry, SIZE_BOX_X + (index - 1) * SIZE_BOX_STEP, top)
        end
        self.y = self.y - BOX_ROW - 4
        return top
    end

    -- A size row: a row of boxes, and the element's layer at its end.
    function Page:SizeRow(row)
        local module, db = row.module, row.module.db
        local top = self:Row(row)
        local layer = self.content:CreateFontString(nil, "ARTWORK")
        layer:SetFont(DogsForeverUI.Style.FONT, 12, "")
        layer:SetPoint("TOPLEFT", self.content, "TOPLEFT", SIZE_STRATA_X + 4, top + 12)
        layer:SetText("Layer")
        AddStrata(self.content, SIZE_STRATA_X, top,
            function() return db.frameStrata end,
            function(value)
                db.frameStrata = value
                self:Changed(module)
            end)
    end

    -- A list the player builds, in four rows from the top:
    --
    --   * a box for an ID, with its title, and a button per kind to add it;
    --   * one line saying what the last add did (nothing to start);
    --   * column headings: the name, and - when the list has one - the
    --     column saying what each entry does;
    --   * a row per entry: icon, name and ID; in that column either a
    --     dropdown (the entry has a choice) or a word (it does not); Up/Down
    --     buttons when the order means something; Remove.
    --
    -- Every explanation is the page's, above all this - nothing here wraps, so
    -- nothing can run into the rows. The list grows, so it has to be the last
    -- thing on the page: the page's height follows it.
    --
    -- spec = { title, empty, buttons = { { kind, label }, ... },
    --          add(kind, text) -> ok, message   entries() -> list
    --          describe(entry) -> name, icon, detail   remove(index)
    --          column (heading), choices, getChoice(index),
    --          setChoice(index, value), hasChoice(entry),
    --          fixedChoice(entry) -> text                     (optional)
    --          move(index, delta)                             (optional) }
    local LIST_ROW = 30
    local LIST_ICON = 20
    local CHOICE_WIDTH = 120
    local REMOVE_WIDTH = 76

    function Page:IdList(spec)
        self:EndRow()
        local content = self.content
        local top = self.y

        -- The box, its title over it, and the add buttons beside it.
        local box = CreateFrame("EditBox", PANEL_NAME .. "IdBox", content,
            BackdropTemplateMixin and "BackdropTemplate" or nil)
        box:SetPoint("TOPLEFT", LEFT + 4, top - 18)
        box:SetSize(110, 25)
        if box.SetBackdrop then
            box:SetBackdrop(EDIT_BACKDROP)
            box:SetBackdropColor(0, 0, 0, 1)
        end
        box:SetMultiLine(false)
        box:SetAutoFocus(false)
        box:SetMaxLetters(9)
        box:SetJustifyH("CENTER")
        box:SetJustifyV("MIDDLE")
        box:SetFontObject(GameFontNormal)
        local title = box:CreateFontString(nil, "ARTWORK")
        title:SetFont(DogsForeverUI.Style.FONT, 12, "")
        title:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 2, 2)
        title:SetText(spec.title)

        -- What the last add did: one line, never wrapped.
        local status = AddText(content, LEFT + 4, top - 50, "", "GameFontHighlightSmall")
        status:SetWidth(CONTENT_WIDTH - 2 * LEFT - 8)
        status:SetWordWrap(false)

        local function Added(kind)
            local ok, message = spec.add(kind, box:GetText())
            status:SetText(ok and message or ("|cffff5555" .. message .. "|r"))
            if ok then box:SetText("") end
            box:ClearFocus()
            Refresh()
        end

        local x = LEFT + 4 + 110 + 10
        for _, button in ipairs(spec.buttons) do
            AddButton(content, x, top - 19, button.label, 90, function() Added(button.kind) end)
            x = x + 96
        end
        box:SetScript("OnEnterPressed", function() Added(spec.buttons[1].kind) end)
        box:SetScript("OnEscapePressed", function(self)
            self:SetText("")
            self:ClearFocus()
        end)

        -- The columns, measured from the row's right edge inwards: Remove,
        -- then Up/Down if any, then the choice column.
        local right = CONTENT_WIDTH - 2 * LEFT
        local removeX = right - REMOVE_WIDTH
        local choiceRight = removeX - 8 - (spec.move and 2 * 58 or 0)
        local choiceX = choiceRight - CHOICE_WIDTH

        local headTop = top - 72
        local nameHead = AddText(content, LEFT + 4 + LIST_ICON + 8, headTop, "Spell or item", "GameFontNormalSmall")
        if spec.column then
            AddText(content, LEFT + choiceX + 4, headTop, spec.column, "GameFontNormalSmall")
        end
        local rule = content:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(1, 0.82, 0, 0.25)
        rule:SetPoint("TOPLEFT", content, "TOPLEFT", LEFT, headTop - 14)
        rule:SetSize(right, 1)

        local listTop = headTop - 20
        local emptyText = AddText(content, LEFT + 4, listTop - 8, spec.empty or "", "GameFontDisable")
        local rows = {}

        local function Row(index)
            if rows[index] then return rows[index] end
            local row = CreateFrame("Frame", nil, content)
            row:SetSize(right, LIST_ROW)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetPoint("LEFT", 4, 0)
            row.icon:SetSize(LIST_ICON, LIST_ICON)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(false)
            row.text:SetWidth((spec.choices and choiceX or choiceRight) - LIST_ICON - 20)

            if spec.choices then
                row.choice = AddChoice(row, choiceX, -2, CHOICE_WIDTH, spec.choices,
                    function() return row.index and spec.getChoice(row.index) end,
                    function(value)
                        spec.setChoice(row.index, value)
                        Refresh()
                    end)
                -- Where there is nothing to choose: what it does, in words,
                -- in the same place.
                row.fixed = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.fixed:SetPoint("LEFT", row, "LEFT", choiceX + 12, 0)
                row.fixed:SetJustifyH("LEFT")
            end

            row.remove = AddButton(row, removeX, -4, "Remove", REMOVE_WIDTH, function()
                spec.remove(row.index)
                Refresh()
            end)
            -- Moving up and down, only for a list whose order means something.
            if spec.move then
                row.down = AddButton(row, removeX - 58, -4, "Down", 54, function()
                    spec.move(row.index, 1)
                    Refresh()
                end)
                row.up = AddButton(row, removeX - 2 * 58, -4, "Up", 54, function()
                    spec.move(row.index, -1)
                    Refresh()
                end)
            end
            rows[index] = row
            return row
        end

        refreshers[#refreshers + 1] = function()
            local entries = spec.entries()
            for index, entry in ipairs(entries) do
                local row = Row(index)
                row.index = index
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", content, "TOPLEFT", LEFT, listTop - (index - 1) * LIST_ROW)
                local name, icon, detail = spec.describe(entry)
                row.icon:SetTexture(icon)
                row.text:SetText(name .. "  |cff999999" .. detail .. "|r")
                if row.choice then
                    if spec.hasChoice(entry) then
                        row.fixed:SetText("")
                        row.fixed:Hide()
                        row.choice:Show()
                        row.choice:GenerateMenu()
                    else
                        row.choice:Hide()
                        row.fixed:SetText(spec.fixedChoice and spec.fixedChoice(entry) or "")
                        row.fixed:Show()
                    end
                end
                for _, key in ipairs({ "up", "down", "remove" }) do
                    if row[key] then row[key]:Enable() end
                end
                if row.up and index == 1 then row.up:Disable() end
                if row.down and index == #entries then row.down:Disable() end
                row:Show()
            end
            for index = #entries + 1, #rows do rows[index]:Hide() end
            if #entries == 0 then emptyText:Show() else emptyText:Hide() end
            content:SetHeight(-listTop + math.max(1, #entries) * LIST_ROW + 12)
        end

        self.y = listTop - LIST_ROW
        return nameHead
    end

    function Page:Finish()
        self:EndRow()
        return -self.y + 12
    end

    ---------------------------------------------------------------------------
    -- Pages.lua describes the page; this file builds it.
    ---------------------------------------------------------------------------

    local describe
    local tabs = {}      -- { name, title, subtitle, build, panel }, in order

    function Options.Describe(build)
        describe = build
    end

    -- A tab of its own: a page listed under the addon in Settings > AddOns.
    -- The unlock and the reset stay on the main page only - they are the whole
    -- UI's.
    function Options.DescribeTab(name, title, subtitle, build)
        tabs[#tabs + 1] = { name = name, title = title, subtitle = subtitle, build = build }
    end

    -- The two things that are the whole UI's, not a section's: placing it
    -- (one unlock for everything) and resetting it. On the panel itself, above
    -- the scrolling page, so they are always in reach.
    local UNLOCK_LABEL, LOCK_LABEL = "Unlock UI", "Lock UI"
    local RESET_LABEL, RESET_ARMED = "Reset everything", "Really reset?"

    local function BuildToolbar(parent)
        local unlock = AddButton(parent, 16, -58, UNLOCK_LABEL, 130, function()
            Core.ToggleUnlocked()
            Refresh()
        end)
        if unlock then
            refreshers[#refreshers + 1] = function()
                unlock:SetText(Core.IsUnlocked() and LOCK_LABEL or UNLOCK_LABEL)
            end
        end
        parent.unlockButton = unlock

        -- Two steps, because one click throws away every setting there is.
        local reset = AddButton(parent, 152, -58, RESET_LABEL, 130, function(button)
            if not button.armed then
                button.armed = true
                button:SetText(RESET_ARMED)
                if C_Timer and C_Timer.After then
                    C_Timer.After(5, function()
                        if button.armed then
                            button.armed = false
                            button:SetText(RESET_LABEL)
                        end
                    end)
                end
                return
            end
            button.armed = false
            button:SetText(RESET_LABEL)
            Core:ResetAll()
            Refresh()
        end)
        parent.resetButton = reset

        local hint = AddText(parent, 292, -62,
            "|cff999999Unlocked, drag anything to move it; a grid shows to line things up. Right-click any of it to lock.|r",
            "GameFontHighlightSmall")
        hint:SetPoint("RIGHT", parent, "RIGHT", -32, 0)
        hint:SetWordWrap(true)
    end

    local function BuildPage(parent, build, contentName, top)
        local frame = CreateFrame("Frame", nil, parent)
        frame:SetPoint("TOPLEFT", 8, top or -92)
        frame:SetPoint("BOTTOMRIGHT", -26, 8)

        local scroll = CreateFrame("ScrollFrame", nil, frame)
        scroll:SetAllPoints()

        local content = CreateFrame("Frame", contentName, scroll)
        content:SetWidth(CONTENT_WIDTH)
        content:SetHeight(1)
        scroll:SetScrollChild(content)

        local page = NewPage(content)
        if build then build(page) end
        content:SetHeight(page:Finish())

        frame.content = content
        if Core.ScrollBar then
            frame.UpdateScrollBar = Core.ScrollBar.Attach(scroll)
            refreshers[#refreshers + 1] = frame.UpdateScrollBar
        end
        parent.page = frame
        return frame
    end

    local function BuildPanel()
        panel = CreateFrame("Frame", PANEL_NAME, UIParent)
        panel.name = TITLE
        panel:Hide()

        AddText(panel, 16, -16, TITLE, "GameFontNormalLarge")
        local subtitle = AddText(panel, 16, -38,
            "Unit frames, a castbar with swing bars, the five-second rule, combo points, an XP bar, cooldown bars, a chat copy window and quieter menus - one addon, one look.",
            "GameFontHighlightSmall")
        subtitle:SetPoint("RIGHT", panel, "RIGHT", -32, 0)

        BuildToolbar(panel)
        BuildPage(panel, describe, PANEL_NAME .. "Page")

        panel:SetScript("OnShow", function()
            Refresh()
            if panel.page.UpdateScrollBar then panel.page.UpdateScrollBar() end
        end)

        return panel
    end

    -- A tab's panel: its title and a line saying what it is, then its page -
    -- no toolbar.
    local function BuildTab(tab)
        local frame = CreateFrame("Frame", PANEL_NAME .. tab.name, UIParent)
        frame.name = tab.title
        frame:Hide()

        AddText(frame, 16, -16, tab.title, "GameFontNormalLarge")
        local subtitle = AddText(frame, 16, -38, tab.subtitle or "", "GameFontHighlightSmall")
        subtitle:SetPoint("RIGHT", frame, "RIGHT", -32, 0)
        subtitle:SetWordWrap(true)

        BuildPage(frame, tab.build, PANEL_NAME .. tab.name .. "Page", -66)
        frame.subtitle = subtitle
        -- The page starts under the text above it however many lines that
        -- text takes - known only once the panel has its width, so asked each
        -- time it is shown.
        frame:SetScript("OnShow", function()
            local ok, height = pcall(subtitle.GetStringHeight, subtitle)
            if ok and type(height) == "number" and height > 0 then
                frame.page:ClearAllPoints()
                frame.page:SetPoint("TOPLEFT", 8, -(38 + height + 14))
                frame.page:SetPoint("BOTTOMRIGHT", -26, 8)
            end
            Refresh()
            if frame.page.UpdateScrollBar then frame.page.UpdateScrollBar() end
        end)
        tab.panel = frame
        return frame
    end
    Options.tabs = tabs

    -------------------------------------------------------------------------------
    -- Registration: the panel is a category of the game's own options, under
    -- Settings > AddOns, which is the one way into it. There are no slash
    -- commands.
    -------------------------------------------------------------------------------

    local function Register()
        BuildPanel()
        for _, tab in ipairs(tabs) do BuildTab(tab) end

        if not (Settings and Settings.RegisterCanvasLayoutCategory
                and Settings.RegisterAddOnCategory) then
            return
        end
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, TITLE)
        if ok and category then
            category.ID = TITLE
            pcall(Settings.RegisterAddOnCategory, category)
            panel.category = category
        end

        -- Each tab is listed under the addon's own entry.
        if not (panel.category and Settings.RegisterCanvasLayoutSubcategory) then return end
        for _, tab in ipairs(tabs) do
            local okTab, sub = pcall(Settings.RegisterCanvasLayoutSubcategory,
                panel.category, tab.panel, tab.title)
            if okTab and sub then tab.panel.category = sub end
        end
    end

    function Options.Refresh()
        if panel then Refresh() end
    end
    Core.RefreshOptions = Options.Refresh

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        Register()
    end)
end
