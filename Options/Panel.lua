-- The options: one panel in the game's Settings, with a tab per module.
--
-- Each tab is a page of its own that scrolls, laid out the way every Dog's
-- panel always was: a column of checkboxes with tooltips on the left, size and
-- position on the right, sliders that carry their value in the label, and a row
-- of buttons at the bottom. The pages themselves are described in Pages.lua;
-- this file is the widgets, the tabs and the registration.
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
    local pages = {}        -- { key, build }, in tab order
    local tabs = {}         -- the built pages, by index
    local selected = 1

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
        slider:SetWidth(200)
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

    local function Percent(value)
        return string.format("%d%%", math.floor((value or 0) * 100 + 0.5))
    end
    Options.Percent = Percent

    function Options.Seconds(value)
        return string.format("%.1fs", value or 0)
    end

    ---------------------------------------------------------------------------
    -- A page: two columns that run side by side, then full width below them.
    ---------------------------------------------------------------------------

    local CHECK_ROW = 26
    local SLIDER_ROW = 62
    local BOX_ROW = 52
    local LEFT, RIGHT = 16, 330
    local CONTENT_WIDTH = 600

    local Page = {}
    Page.__index = Page

    local function NewPage(module, content)
        return setmetatable({
            module = module,
            db = module.db,
            content = content,
            leftY = -8,
            rightY = -8,
            y = nil,        -- the full-width cursor, once Below has been called
        }, Page)
    end

    -- A setting changed: the module redraws, and the panel shows what the
    -- setting is now - a check that turned another off, a lock button's label.
    function Page:Changed()
        if self.module.Refresh then self.module.Refresh() end
        Refresh()
    end

    function Page:LeftHeading(text)
        AddText(self.content, LEFT, self.leftY, text, "GameFontNormalLarge")
        self.leftY = self.leftY - 28
    end

    function Page:RightHeading(text)
        AddText(self.content, RIGHT, self.rightY, text, "GameFontNormalLarge")
        self.rightY = self.rightY - 34
    end

    -- Room in the right column: a number box's title sits above the box, so
    -- boxes after a row of checks need it.
    function Page:RightSpace(pixels)
        self.rightY = self.rightY - pixels
    end

    -- entry = { label, tooltip, key, right = optional true, module = optional }:
    -- `right` puts it in the right-hand column. `module` is for a setting of
    -- another module shown on this page - the countdown's, on the castbar's.
    function Page:Check(entry)
        local owner = entry.module or self.module
        local db = owner.db
        local x = entry.right and RIGHT or LEFT
        local y = entry.right and self.rightY or self.leftY
        AddCheck(self.content, x, y, entry.label, entry.tooltip,
            function() return db[entry.key] end,
            function(value)
                db[entry.key] = value
                if owner ~= self.module and owner.Refresh then owner.Refresh() end
                self:Changed()
            end)
        if entry.right then
            self.rightY = self.rightY - CHECK_ROW
        else
            self.leftY = self.leftY - CHECK_ROW
        end
    end

    -- Number boxes, two to a row. entry = { key, title, placed, min, max,
    -- decimals }: typing a position means the player has placed that frame, so
    -- the addon stops working one out for it - `placed` names the flag that
    -- says so, and `autoPlaced` is cleared for a single bar. min, max and
    -- decimals are as for AddEditBox. `onChange(old, new)` runs before the
    -- redraw - a width that keeps its bar centred moves the bar with it.
    function Page:Boxes(list)
        local db = self.db
        for index, entry in ipairs(list) do
            local column = (index % 2 == 1) and RIGHT or (RIGHT + 110)
            local y = self.rightY - (math.ceil(index / 2) - 1) * BOX_ROW
            AddEditBox(self.content, PANEL_NAME .. self.module.key .. entry.key,
                column, y, entry.title,
                function() return db[entry.key] end,
                function(value)
                    local old = db[entry.key]
                    db[entry.key] = value
                    if entry.onChange then entry.onChange(old, value) end
                    if entry.placed then db[entry.placed] = true end
                    if db.autoPlaced ~= nil then db.autoPlaced = false end
                    self:Changed()
                end,
                { min = entry.min, max = entry.max, decimals = entry.decimals })
        end
        self.rightY = self.rightY - math.ceil(#list / 2) * BOX_ROW - 8
    end

    function Page:Strata()
        local db = self.db
        AddText(self.content, RIGHT, self.rightY, "Frame strata", "GameFontNormal")
        self.rightY = self.rightY - 20
        AddStrata(self.content, RIGHT, self.rightY,
            function() return db.frameStrata end,
            function(value)
                db.frameStrata = value
                self:Changed()
            end)
        self.rightY = self.rightY - 32
    end

    -- Full width from here on, under whichever column is longer.
    function Page:Below()
        if not self.y then self.y = math.min(self.leftY, self.rightY) - 18 end
        return self.y
    end

    -- spec as for AddSlider, with `key` in place of get/set.
    function Page:Slider(spec)
        local db = self.db
        local y = self:Below()
        AddSlider(self.content, LEFT + 4, y, {
            label = spec.label, min = spec.min, max = spec.max, step = spec.step,
            lowText = spec.lowText, highText = spec.highText, text = spec.text,
            get = function() return db[spec.key] end,
            set = function(value)
                db[spec.key] = value
                if self.module.Refresh then self.module.Refresh() end
            end,
        })
        self.y = y - SLIDER_ROW - 6
    end

    function Page:TextPadding()
        self:Slider({
            key = "textPadding", label = "Text padding",
            min = 0, max = DogsForeverUI.Style.MAX_TEXT_PADDING, step = 0.01,
            lowText = "0%", highText = "40%", text = Percent,
        })
    end

    -- "Reset to defaults", two-step because one click throws away every setting
    -- on the tab; and, for a module that can be moved, the lock button, whose
    -- label follows the state since it is both halves of it. `alsoReset` names
    -- other modules whose settings this tab shows, reset along with its own.
    function Page:Actions(lockedLabel, alsoReset)
        local module = self.module
        local db = self.db
        local y = self:Below()

        AddButton(self.content, LEFT + 4, y, "Reset to defaults", 150, function(button)
            if not button.armed then
                button.armed = true
                button:SetText("Really reset?")
                if C_Timer and C_Timer.After then
                    C_Timer.After(5, function()
                        if button.armed then
                            button.armed = false
                            button:SetText("Reset to defaults")
                        end
                    end)
                end
                return
            end

            button.armed = false
            button:SetText("Reset to defaults")
            if db.unlocked and module.Lock then module.Lock() end
            for _, key in ipairs(alsoReset or {}) do Core:Reset(key) end
            Core:Reset(module.key)
            Refresh()
        end)

        if module.ToggleLock then
            local place = AddButton(self.content, LEFT + 164, y, "Unlock to move", 150,
                function()
                    module.ToggleLock()
                    Refresh()
                end)
            if place then
                refreshers[#refreshers + 1] = function()
                    place:SetText(db.unlocked and lockedLabel or "Unlock to move")
                end
            end
        end

        self.y = y - 34
    end

    function Page:Note(text)
        local y = self:Below()
        local note = AddText(self.content, LEFT + 4, y, "|cff999999" .. text .. "|r",
            "GameFontHighlight", CONTENT_WIDTH - 40)
        local height = note.GetStringHeight and note:GetStringHeight() or 14
        self.y = y - math.max(14, height) - 12
    end

    -- A paragraph at the top of a page with no columns.
    function Page:Intro(text)
        local note = AddText(self.content, LEFT, self.leftY, text,
            "GameFontHighlight", CONTENT_WIDTH - 40)
        local height = note.GetStringHeight and note:GetStringHeight() or 14
        self.leftY = self.leftY - math.max(14, height) - 14
    end

    function Page:Finish()
        return -(self:Below()) + 12
    end

    ---------------------------------------------------------------------------
    -- Pages are added by Pages.lua, in the order the tabs should run.
    ---------------------------------------------------------------------------

    function Options.AddPage(key, build)
        pages[#pages + 1] = { key = key, build = build }
    end

    local function BuildPage(index, entry, parent)
        local module = Core:GetModule(entry.key)

        local frame = CreateFrame("Frame", nil, parent)
        frame:SetPoint("TOPLEFT", 8, -96)
        frame:SetPoint("BOTTOMRIGHT", -26, 8)
        frame:Hide()

        local scroll = CreateFrame("ScrollFrame", nil, frame)
        scroll:SetAllPoints()

        local content = CreateFrame("Frame", PANEL_NAME .. module.key, scroll)
        content:SetWidth(CONTENT_WIDTH)
        content:SetHeight(1)
        scroll:SetScrollChild(content)

        local page = NewPage(module, content)
        entry.build(page)
        content:SetHeight(page:Finish())

        frame.content = content
        if Core.ScrollBar then
            frame.UpdateScrollBar = Core.ScrollBar.Attach(scroll)
            refreshers[#refreshers + 1] = frame.UpdateScrollBar
        end

        tabs[index] = frame
        return frame
    end

    local function Select(index)
        if not tabs[index] then return end
        selected = index
        for i, frame in ipairs(tabs) do frame:SetShown(i == index) end
        if panel and panel.tabButtons then
            for i, button in ipairs(panel.tabButtons) do
                if i == index then button:Disable() else button:Enable() end
            end
        end
        Refresh()
    end

    -- The tabs: the game's own TabSystemTemplate, as the Friends frame uses on
    -- this client; a row of plain buttons where that is missing.
    local function BuildTabs(parent)
        local ok, system = pcall(CreateFrame, "Frame", nil, parent, "TabSystemTemplate")
        if ok and system and type(system.AddTab) == "function" then
            system:SetPoint("TOPLEFT", 12, -58)
            system:SetTabSelectedCallback(function(index)
                Select(index)
                return false
            end)
            for _, entry in ipairs(pages) do
                system:AddTab(Core:GetModule(entry.key).title)
            end
            parent.tabSystem = system
            return function(index) system:SetTab(index) end
        end

        parent.tabButtons = {}
        local x = 12
        for index, entry in ipairs(pages) do
            local button = AddButton(parent, x, -60, Core:GetModule(entry.key).title, 80,
                function() Select(index) end)
            parent.tabButtons[index] = button
            x = x + 84
        end
        return Select
    end

    local function BuildPanel()
        panel = CreateFrame("Frame", PANEL_NAME, UIParent)
        panel.name = TITLE
        panel:Hide()

        AddText(panel, 16, -16, TITLE, "GameFontNormalLarge")
        local subtitle = AddText(panel, 16, -38,
            "Unit frames, a castbar with swing bars, the five-second rule, combo points, an XP bar, a chat copy window and quieter menus - one addon, one look.",
            "GameFontHighlightSmall")
        subtitle:SetPoint("RIGHT", panel, "RIGHT", -32, 0)

        for index, entry in ipairs(pages) do BuildPage(index, entry, panel) end

        panel.SelectTab = BuildTabs(panel)
        panel.SelectTab(selected)

        panel:SetScript("OnShow", function()
            Refresh()
            for _, frame in ipairs(tabs) do
                if frame.UpdateScrollBar then frame.UpdateScrollBar() end
            end
        end)

        return panel
    end

    -------------------------------------------------------------------------------
    -- Registration: the panel is a category of the game's own options, under
    -- Settings > AddOns, which is the one way into it. There are no slash
    -- commands.
    -------------------------------------------------------------------------------

    local function Register()
        BuildPanel()

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
