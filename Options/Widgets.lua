-- The options' controls, drawn in the frames' look (Core\Style.lua) rather
-- than the game's templates; gold is the one accent. Every control showing a
-- setting takes `get`/`set` and has a Refresh() that never writes it.

local W = {}
DogsForeverUI.Widgets = W

do -- private scope
    local Style = DogsForeverUI.Style
    local CursorY = DogsForeverUI.CursorY

    W.GOLD = { Style.GOLD[1], Style.GOLD[2], Style.GOLD[3], 1 }
    W.TEXT = { 0.94, 0.94, 0.94, 1 }
    W.MUTED = { 0.62, 0.62, 0.62, 1 }
    W.DIM = { 0.40, 0.40, 0.40, 1 }
    W.DARK_TEXT = { 0.08, 0.06, 0.02, 1 }
    W.GOOD = { 0.55, 0.85, 0.45, 1 }
    W.BAD = { 1.00, 0.42, 0.36, 1 }
    W.DANGER = { 0.70, 0.16, 0.10, 1 }
    W.FIELD = { 0, 0, 0, 0.45 }
    W.RAISED = { 1, 1, 1, 0.05 }
    W.HOVER = { 1, 1, 1, 0.10 }
    W.PRESSED = { 1, 1, 1, 0.03 }
    W.TRACK = { 0.16, 0.16, 0.17, 1 }
    W.WASH = { Style.GOLD[1], Style.GOLD[2], Style.GOLD[3], 0.06 }
    -- Outlines neutral and opaque, so no side of one looks different.
    W.LINE = { 0.25, 0.25, 0.26, 1 }
    W.LINE_HOVER = { 0.42, 0.42, 0.43, 1 }
    W.FAINT = { 0.14, 0.14, 0.15, 1 }
    W.FOCUS = { Style.GOLD[1], Style.GOLD[2], Style.GOLD[3], 1 }
    W.KNOB_LINE = { 0.02, 0.02, 0.02, 1 }

    W.CONTROL_HEIGHT = 24
    W.TOGGLE_WIDTH = 40
    local TOGGLE_HEIGHT = 20
    local ARM_TIME = 4

    ---------------------------------------------------------------------------
    -- Pieces
    ---------------------------------------------------------------------------

    function W.Colour(texture, colour)
        texture:SetVertexColor(colour[1], colour[2], colour[3], colour[4] or 1)
    end

    function W.SetTextColour(text, colour)
        text:SetTextColor(colour[1], colour[2], colour[3], colour[4] or 1)
    end

    function W.Flat(parent, layer, colour, sublevel)
        local texture = parent:CreateTexture(nil, layer, nil, sublevel)
        texture:SetTexture(Style.FLAT_TEXTURE)
        W.Colour(texture, colour)
        return texture
    end

    -- One line, or wrapped to `width` (then anchor both sides and FitText it).
    -- No shadow: a fraction of a pixel off, it smeared the letters.
    function W.Text(parent, size, colour, bold, width)
        local text = parent:CreateFontString(nil, "OVERLAY")
        if bold then
            Style.SetBoldFont(text, size)
        else
            text:SetFont(Style.FONT, size, "")
        end
        text:SetShadowOffset(0, 0)
        W.SetTextColour(text, colour or W.TEXT)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(width ~= nil)
        if width then text:SetWidth(width) end
        return text
    end

    -- Wrapped text as tall as its lines, so no last word drops out of sight.
    function W.FitText(text)
        local height = text:GetStringHeight() or 0
        if height > 0 then text:SetHeight(height) end
        return height
    end

    W.Pixel = Style.OnePixel

    -- A control's outline: four opaque lines just inside its edges, each a
    -- whole number of pixels, on a frame over it. (Style.AddBorder lost
    -- sides on the window's small boxes.)
    -- Each side between two corners; the upright ones stop short of top and
    -- bottom, so no pixel is drawn twice.
    local SIDES = {
        { key = "top", "TOPLEFT", "TOPRIGHT" },
        { key = "bottom", "BOTTOMLEFT", "BOTTOMRIGHT" },
        { key = "left", "TOPLEFT", "BOTTOMLEFT", upright = true },
        { key = "right", "TOPRIGHT", "BOTTOMRIGHT", upright = true },
    }
    local outlines = setmetatable({}, { __mode = "k" })

    local function LayOut(outline)
        local edge = outline.edge
        -- A hair over, so a one-pixel line never rounds away.
        local thick = W.Pixel(edge) * 1.01
        for _, side in ipairs(SIDES) do
            local line, inset = outline[side.key], side.upright and thick or 0
            line:ClearAllPoints()
            line:SetPoint(side[1], edge, side[1], 0, -inset)
            line:SetPoint(side[2], edge, side[2], 0, inset)
            if side.upright then line:SetWidth(thick) else line:SetHeight(thick) end
        end
    end

    function W.TintBorder(outline, colour)
        outline.colour = colour
        for _, side in ipairs(SIDES) do W.Colour(outline[side.key], colour) end
    end

    function W.Border(frame, colour)
        local edge = CreateFrame("Frame", nil, frame)
        edge:SetAllPoints(frame)
        edge:SetFrameLevel(frame:GetFrameLevel() + 8)
        local outline = { edge = edge }
        for _, side in ipairs(SIDES) do
            outline[side.key] = W.Flat(edge, "OVERLAY", W.LINE, 7)
        end
        LayOut(outline)
        W.TintBorder(outline, colour or W.LINE)
        outlines[outline] = true
        return outline
    end

    -- A plain `colour` behind `frame`, and an outline (`line`) on it.
    local function Backdrop(frame, colour, line)
        frame.bg = W.Flat(frame, "BACKGROUND", colour)
        frame.bg:SetAllPoints(frame)
        frame.border = W.Border(frame, line)
    end

    local rescale = CreateFrame("Frame")
    rescale:RegisterEvent("UI_SCALE_CHANGED")
    rescale:RegisterEvent("DISPLAY_SIZE_CHANGED")
    rescale:SetScript("OnEvent", function()
        for outline in pairs(outlines) do LayOut(outline) end
    end)

    -- Windows wearing Style.AddBorder: put on whole pixels when shown or moved.
    local snapped = {}
    function W.KeepSnapped(border)
        snapped[#snapped + 1] = border
    end
    function W.SnapBorders()
        for _, border in ipairs(snapped) do
            if border:IsVisible() then pcall(Style.SnapBorder, border) end
        end
    end

    -- A hairline along `parent`'s top edge, `y` down.
    function W.Hairline(parent, colour, y, left, right)
        local line = W.Flat(parent, "ARTWORK", colour)
        line:SetPoint("TOPLEFT", parent, "TOPLEFT", left or 0, -(y or 0))
        line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(right or 0), -(y or 0))
        line:SetHeight(W.Pixel(parent))
        return line
    end

    -- Two rotated strokes: "close" (a cross) or "down" (a chevron).
    function W.Glyph(parent, kind, size, colour)
        local thick = math.max(1.2, W.Pixel(parent))
        local strokes = {}
        for index = 1, 2 do
            local stroke = W.Flat(parent, "OVERLAY", colour or W.TEXT)
            if kind == "close" then
                stroke:SetSize(size * 1.3, thick)
                stroke:SetPoint("CENTER", parent, "CENTER", 0, 0)
                stroke:SetRotation(math.rad(index == 1 and 45 or -45))
            else
                local half = size * 0.55
                stroke:SetSize(half, thick)
                stroke:SetPoint("CENTER", parent, "CENTER", (index == 1 and -1 or 1) * half * 0.35, 0)
                stroke:SetRotation(math.rad(index == 1 and -45 or 45))
            end
            strokes[index] = stroke
        end
        return strokes
    end

    function W.Tooltip(frame, title, text)
        if not text then return end
        frame:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(title, 1, 1, 1)
            GameTooltip:AddLine(text, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end

    ---------------------------------------------------------------------------
    -- Buttons. Styles: normal, primary (gold outline), active (gold), armed
    -- (red), flat, nav (the sidebar's).
    ---------------------------------------------------------------------------

    local CLEAR = { 0, 0, 0, 0 }

    function W.PaintButton(button)
        local style = button.style or "normal"
        local enabled = button:IsEnabled()
        local bg, text, line = W.RAISED, W.TEXT, W.LINE
        if style == "active" then
            bg, text = W.GOLD, W.DARK_TEXT
        elseif style == "armed" then
            bg, text = W.DANGER, W.TEXT
        elseif style == "primary" then
            text, line = W.GOLD, W.GOLD
        elseif style == "flat" or style == "nav" then
            bg = CLEAR
        end
        if style == "nav" and not button.selected then text = W.MUTED end
        if not enabled then
            text = W.DIM
        elseif button.pressed then
            bg = (style == "normal" or style == "primary") and W.PRESSED or bg
        elseif button.hovered then
            if style == "active" or style == "armed" then
                bg = { math.min(1, bg[1] * 1.15), math.min(1, bg[2] * 1.15), math.min(1, bg[3] * 1.15), 1 }
            elseif style == "nav" then
                bg, text = W.RAISED, W.TEXT
            elseif style == "primary" then
                bg = W.WASH
            else
                bg = W.HOVER
                if style == "normal" then line = W.LINE_HOVER end
            end
        end
        if button.selected and enabled and style == "flat" then text = W.GOLD end
        W.Colour(button.bg, bg)
        if button.border then W.TintBorder(button.border, line) end
        if button.label then W.SetTextColour(button.label, text) end
        for _, stroke in ipairs(button.glyph or {}) do W.Colour(stroke, text) end
    end
    local PaintButton = W.PaintButton

    -- `onClick(button, mouseButton)`.
    function W.Button(parent, label, width, onClick, style)
        local button = CreateFrame("Button", nil, parent)
        button:SetSize(width, W.CONTROL_HEIGHT)
        button:RegisterForClicks("LeftButtonUp")
        button.style = style
        button.bg = W.Flat(button, "BACKGROUND", W.RAISED)
        button.bg:SetAllPoints(button)
        if label then
            button.label = W.Text(button, 12)
            button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
            button.label:SetJustifyH("CENTER")
            button.label:SetText(label)
        end
        if style ~= "flat" and style ~= "nav" then button.border = W.Border(button) end

        button:SetScript("OnEnter", function(self) self.hovered = true; PaintButton(self) end)
        button:SetScript("OnLeave", function(self) self.hovered, self.pressed = false, false; PaintButton(self) end)
        button:SetScript("OnMouseDown", function(self) self.pressed = true; PaintButton(self) end)
        button:SetScript("OnMouseUp", function(self) self.pressed = false; PaintButton(self) end)
        button:SetScript("OnClick", function(self, mouse)
            if self:IsEnabled() and onClick then onClick(self, mouse) end
        end)
        PaintButton(button)
        return button
    end

    function W.SetLabel(button, label)
        button.label:SetText(label)
    end

    function W.SetStyle(button, style)
        button.style = style
        PaintButton(button)
    end

    -- A square, outline-free button with a drawn mark.
    function W.IconButton(parent, kind, size, onClick)
        local button = W.Button(parent, nil, size, onClick, "flat")
        button:SetHeight(size)
        button.glyph = W.Glyph(button, kind, size * 0.45)
        PaintButton(button)
        return button
    end

    -- One click arms it (red, `armedLabel`), a second within ARM_TIME acts.
    -- `ask()` (optional) says whether this click needs arming at all.
    -- button.press: the click, for a box whose Enter presses it.
    function W.TwoStep(parent, label, armedLabel, width, action, ask)
        local function Disarm(button)
            button.armed = false
            W.SetLabel(button, label)
            W.SetStyle(button, nil)
        end
        local function Press(button)
            if not button.armed and (not ask or ask()) then
                button.armed = true
                W.SetLabel(button, armedLabel)
                W.SetStyle(button, "armed")
                local token = (button.armedToken or 0) + 1
                button.armedToken = token
                C_Timer.After(ARM_TIME, function()
                    if button.armed and button.armedToken == token then Disarm(button) end
                end)
                return
            end
            Disarm(button)
            action(button)
        end
        local button = W.Button(parent, label, width, Press)
        button.press = function() if button:IsEnabled() then Press(button) end end
        button.disarm = function() if button.armed then Disarm(button) end end
        return button
    end

    ---------------------------------------------------------------------------
    -- The toggle: a bar that fills gold when on, its knob sliding along.
    ---------------------------------------------------------------------------

    local KNOB = 14
    local SLIDE_TIME = 0.12

    local function PlaceKnob(toggle, v)
        toggle.value = v
        toggle.track:SetValue(v)
        toggle.knob:ClearAllPoints()
        toggle.knob:SetPoint("LEFT", toggle.track, "LEFT", 3 + v * (W.TOGGLE_WIDTH - 6 - KNOB), 0)
        local shade = 0.62 + 0.38 * v
        W.Colour(toggle.knob, { shade, shade, shade, 1 })
    end

    local function Slide(toggle, elapsed)
        local v, target = toggle.value, toggle.target
        local step = elapsed / SLIDE_TIME
        if math.abs(target - v) <= step then
            PlaceKnob(toggle, target)
            toggle:SetScript("OnUpdate", nil)
        else
            PlaceKnob(toggle, v + (target > v and step or -step))
        end
    end

    -- `set(on)` writes the setting; the caller refreshes.
    function W.Toggle(parent, get, set)
        local toggle = CreateFrame("Button", nil, parent)
        toggle:SetSize(W.TOGGLE_WIDTH, TOGGLE_HEIGHT)
        toggle:RegisterForClicks("LeftButtonUp")

        local track = CreateFrame("StatusBar", nil, toggle)
        track:SetAllPoints(toggle)
        track:SetMinMaxValues(0, 1)
        W.Flat(track, "BACKGROUND", W.TRACK):SetAllPoints(track)
        Style.Paint(track, W.GOLD)
        toggle.track = track
        toggle.knob = W.Flat(track, "OVERLAY", W.TEXT)
        toggle.knob:SetSize(KNOB, KNOB)
        toggle.border = W.Border(toggle)

        toggle:SetScript("OnClick", function() set(not get()) end)
        toggle:SetScript("OnEnter", function(self) W.TintBorder(self.border, W.FOCUS) end)
        toggle:SetScript("OnLeave", function(self) W.TintBorder(self.border, W.LINE) end)

        -- At once the first time and while unseen; sliding after.
        function toggle.Refresh()
            local target = get() and 1 or 0
            toggle.target = target
            if toggle.value == nil or not toggle:IsVisible() then
                PlaceKnob(toggle, target)
                toggle:SetScript("OnUpdate", nil)
            elseif toggle.value ~= target then
                toggle:SetScript("OnUpdate", Slide)
            end
        end
        return toggle
    end

    ---------------------------------------------------------------------------
    -- Boxes. Tab walks them in the order they were made.
    ---------------------------------------------------------------------------

    local boxes = {}

    local function FocusNext(box)
        for index, other in ipairs(boxes) do
            if other == box then
                for step = 1, #boxes - 1 do
                    local nextBox = boxes[(index - 1 + step) % #boxes + 1]
                    if nextBox:IsVisible() then
                        nextBox:SetFocus()
                        return
                    end
                end
                return
            end
        end
    end

    local function NewBox(parent, name, width, maxLetters, justify)
        local box = CreateFrame("EditBox", name, parent)
        box:SetSize(width, W.CONTROL_HEIGHT)
        box:SetAutoFocus(false)
        box:SetMultiLine(false)
        box:SetMaxLetters(maxLetters)
        box:SetFont(Style.FONT, 12, "")
        box:SetTextColor(W.TEXT[1], W.TEXT[2], W.TEXT[3], 1)
        box:SetJustifyH(justify or "CENTER")
        box:SetTextInsets(8, 8, 0, 0)
        Backdrop(box, W.FIELD)
        box:HookScript("OnEditFocusGained", function(self) W.TintBorder(self.border, W.FOCUS) end)
        box:HookScript("OnEditFocusLost", function(self) W.TintBorder(self.border, W.LINE) end)
        return box
    end

    -- A box for a value: Tab or leaving it keeps what was typed (`Commit`),
    -- Esc puts the shown value back (`Revert`).
    local function Typed(box, Commit, Revert)
        box:SetScript("OnEscapePressed", function(self)
            Revert()
            self:ClearFocus()
        end)
        box:SetScript("OnTabPressed", function(self)
            Commit()
            FocusNext(self)
        end)
        box:HookScript("OnEditFocusLost", Commit)
        boxes[#boxes + 1] = box
    end

    -- A text box, with a grey `hint` while empty.
    function W.TextBox(parent, name, width, maxLetters, hint)
        local box = NewBox(parent, name, width, maxLetters, "LEFT")
        if hint then
            box.hint = W.Text(box, 12, W.DIM)
            box.hint:SetPoint("LEFT", box, "LEFT", 8, 0)
            box.hint:SetText(hint)
            local function ShowHint(self)
                self.hint:SetShown(self:GetText() == "" and not self.focused)
            end
            box:HookScript("OnEditFocusGained", function(self) self.focused = true; ShowHint(self) end)
            box:HookScript("OnEditFocusLost", function(self) self.focused = false; ShowHint(self) end)
            box:HookScript("OnTextChanged", ShowHint)
            box.ShowHint = ShowHint
        end
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        box:SetScript("OnTabPressed", FocusNext)
        boxes[#boxes + 1] = box
        return box
    end

    -- A number box: Enter, Tab or leaving it keeps a number inside
    -- `limits` = { min, max, decimals } (optional), anything else is put
    -- back; Esc puts the old one back.
    function W.NumberBox(parent, name, width, get, set, limits)
        limits = limits or {}
        local box = NewBox(parent, name, width, 7)

        local function Show()
            local value = get()
            if type(value) ~= "number" then
                box:SetText("")
            elseif limits.decimals then
                box:SetText((string.format("%.1f", value):gsub("%.0$", "")))
            else
                box:SetText(tostring(math.floor(value + 0.5)))
            end
            box.shownText = box:GetText()
        end

        local function Commit()
            if box:GetText() == box.shownText then return end
            local value = tonumber(box:GetText())
            if value and limits.decimals then value = math.floor(value * 10 + 0.5) / 10 end
            if value and (limits.min and value < limits.min or limits.max and value > limits.max) then
                value = nil
            end
            if value then set(value) end
            Show()
        end

        box:SetScript("OnEnterPressed", function(self)
            Commit()
            self:ClearFocus()
        end)
        Typed(box, Commit, Show)
        box.Refresh = Show
        return box
    end

    ---------------------------------------------------------------------------
    -- The slider: a thin bar filled gold to the value, a knob on it, the
    -- value beside it. The knob is a frame over the track; the thumb the
    -- mouse drags is invisible under it (the track drew over a visible one).
    ---------------------------------------------------------------------------

    local KNOB_SIZE = 12
    local KNOB_HOVER = { 1, 0.86, 0.55, 1 }

    -- spec = { min, max, step, text(value), input, inputWidth, inputHeight,
    --          inputGap, scale }; with `input` the value is a box to type
    -- into, its number divided by `scale` (100 for a percentage).
    function W.Slider(parent, width, spec, get, set)
        local slider = CreateFrame("Slider", nil, parent)
        slider:SetSize(width, 18)
        slider:SetOrientation("HORIZONTAL")
        slider:SetMinMaxValues(spec.min, spec.max)
        slider:SetValueStep(spec.step)
        slider:SetObeyStepOnDrag(true)
        slider:EnableMouse(true)

        local track = CreateFrame("StatusBar", nil, slider)
        track:SetPoint("LEFT", slider, "LEFT", 0, 0)
        track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
        track:SetHeight(4)
        track:SetMinMaxValues(spec.min, spec.max)
        Backdrop(track, W.TRACK, W.FAINT)
        Style.Paint(track, W.GOLD)
        slider.track = track

        local thumb = slider:CreateTexture(nil, "OVERLAY")
        thumb:SetColorTexture(0, 0, 0, 0)
        thumb:SetSize(KNOB_SIZE, KNOB_SIZE)
        slider:SetThumbTexture(thumb)

        local knob = CreateFrame("Frame", nil, slider)
        knob:SetSize(KNOB_SIZE, KNOB_SIZE)
        knob:SetFrameLevel(track:GetFrameLevel() + 10)
        knob.fill = W.Flat(knob, "ARTWORK", W.GOLD)
        knob.fill:SetAllPoints(knob)
        knob.border = W.Border(knob, W.KNOB_LINE)
        slider.knob = knob
        slider:SetScript("OnEnter", function() W.Colour(knob.fill, KNOB_HOVER) end)
        slider:SetScript("OnLeave", function() W.Colour(knob.fill, W.GOLD) end)

        local box
        if spec.input then
            box = NewBox(parent, nil, spec.inputWidth or 44, 8)
            box:SetHeight(spec.inputHeight or 20)
            box:SetTextInsets(3, 3, 0, 0)
            box:SetPoint("LEFT", slider, "RIGHT", spec.inputGap or 6, 0)
            slider.input = box
        else
            slider.valueText = W.Text(parent, 12, W.MUTED)
            slider.valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)
        end

        local function Show(value)
            track:SetValue(value)
            local share = 0
            if spec.max > spec.min then
                share = math.max(0, math.min(1, (value - spec.min) / (spec.max - spec.min)))
            end
            knob:ClearAllPoints()
            knob:SetPoint("LEFT", slider, "LEFT", share * (width - KNOB_SIZE), 0)
            local text = spec.text and spec.text(value) or tostring(value)
            if not box then
                slider.valueText:SetText(text)
            elseif not box:HasFocus() then
                box:SetText(text)
                box.shownText = text
            end
        end

        local refreshing = false
        slider:SetScript("OnValueChanged", function(_, value)
            value = math.floor(value / spec.step + 0.5) * spec.step
            Show(value)
            if not refreshing then set(value) end
        end)

        function slider.Refresh()
            local value = get() or spec.min
            refreshing = true
            slider:SetValue(value)
            refreshing = false
            Show(value)
        end

        if box then
            local function Commit()
                local typed = box:GetText()
                if typed == box.shownText then return end
                local number = tonumber((tostring(typed):gsub("[^%d%.%-]", "")))
                if number then
                    if spec.scale then number = number / spec.scale end
                    number = math.max(spec.min, math.min(spec.max, number))
                    slider:SetValue(math.floor(number / spec.step + 0.5) * spec.step)
                end
                box:ClearFocus()
                slider.Refresh()
            end
            box:SetScript("OnEnterPressed", Commit)
            Typed(box, Commit, function() box:SetText(box.shownText or "") end)
            box.Refresh = slider.Refresh
        end
        return slider
    end

    ---------------------------------------------------------------------------
    -- Choices
    ---------------------------------------------------------------------------

    -- A few choices side by side, the picked one gold.
    -- choices = { { value, label }, ... }
    function W.Segmented(parent, choices, segmentWidth, get, set)
        local frame = CreateFrame("Frame", nil, parent)
        frame:SetSize(segmentWidth * #choices, W.CONTROL_HEIGHT - 2)
        Backdrop(frame, W.FIELD)
        frame.segments = {}

        for index, choice in ipairs(choices) do
            local x = (index - 1) * segmentWidth
            local segment = W.Button(frame, choice.label, segmentWidth, function() set(choice.value) end, "flat")
            segment:SetHeight(W.CONTROL_HEIGHT - 2)
            segment:SetPoint("LEFT", frame, "LEFT", x, 0)
            segment.value = choice.value
            if index > 1 then
                local divider = W.Flat(frame, "ARTWORK", W.FAINT)
                divider:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
                divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, 0)
                divider:SetWidth(W.Pixel(frame))
            end
            frame.segments[index] = segment
        end

        function frame.Refresh()
            local current = get()
            for _, segment in ipairs(frame.segments) do
                W.SetStyle(segment, segment.value == current and "active" or "flat")
            end
        end
        return frame
    end

    -- The one list every dropdown opens.
    local popup
    local ITEM_HEIGHT = 22
    local ITEM_PAD = 8
    local POPUP_MAX_WIDTH = 320

    local function ClosePopup()
        if popup and popup:IsShown() then
            popup:Hide()
            popup.owner = nil
        end
    end
    W.ClosePopup = ClosePopup

    -- Also for windows a click in which must not close it (Unlock Mode's).
    function W.Popup()
        if popup then return popup end
        popup = CreateFrame("Frame", nil, UIParent)
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetClampedToScreen(true)
        popup:EnableMouse(true)
        popup:Hide()
        Backdrop(popup, { 0.06, 0.06, 0.06, 0.98 })
        popup.items = {}
        -- A click anywhere else shuts it, as the game's menus do.
        popup:SetScript("OnEvent", function(self)
            if not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then ClosePopup() end
        end)
        popup:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
        popup:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
        return popup
    end

    -- As wide as its widest choice (never narrower than the button, never
    -- past POPUP_MAX_WIDTH, cut short with "..." there).
    local function OpenPopup(owner, choices, get, set)
        local list = W.Popup()
        if list:IsShown() and list.owner == owner then
            ClosePopup()
            return
        end
        list.owner = owner
        list:SetScale(owner:GetEffectiveScale() / UIParent:GetEffectiveScale())
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
        local current = get()
        local widest = 0
        for index, choice in ipairs(choices) do
            local item = list.items[index]
            if not item then
                item = W.Button(list, "", owner:GetWidth() - 4, nil, "flat")
                item:SetHeight(ITEM_HEIGHT)
                item.label:ClearAllPoints()
                item.label:SetPoint("LEFT", item, "LEFT", ITEM_PAD, 0)
                item.label:SetPoint("RIGHT", item, "RIGHT", -ITEM_PAD, 0)
                item.label:SetJustifyH("LEFT")
                item.label:SetWordWrap(false)
                list.items[index] = item
            end
            W.SetLabel(item, choice.label)
            widest = math.max(widest, item.label:GetUnboundedStringWidth())
        end
        local width = math.min(math.max(owner:GetWidth(), widest + 2 * ITEM_PAD + 4), POPUP_MAX_WIDTH)
        list:SetSize(width, #choices * ITEM_HEIGHT + 4)
        for index, choice in ipairs(choices) do
            local item = list.items[index]
            item:SetWidth(width - 4)
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", list, "TOPLEFT", 2, -2 - (index - 1) * ITEM_HEIGHT)
            item:SetScript("OnClick", function()
                set(choice.value)
                ClosePopup()
            end)
            item.selected = choice.value == current
            item:Show()
            PaintButton(item)
        end
        for index = #choices + 1, #list.items do list.items[index]:Hide() end
        list:Show()
        list:Raise()
    end

    -- A button showing the picked choice, opening the list under it.
    function W.Dropdown(parent, width, choices, get, set)
        local button = W.Button(parent, "", width, nil)
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", button, "LEFT", 8, 0)
        button.label:SetPoint("RIGHT", button, "RIGHT", -22, 0)
        button.label:SetJustifyH("LEFT")
        button.label:SetWordWrap(false)
        local mark = CreateFrame("Frame", nil, button)
        mark:SetSize(12, 12)
        mark:SetPoint("RIGHT", button, "RIGHT", -6, -1)
        button.glyph = W.Glyph(mark, "down", 12)
        button.choices = choices
        button:SetScript("OnClick", function(self)
            OpenPopup(self, choices, get, function(value)
                set(value)
                self.Refresh()
            end)
        end)
        function button.Refresh()
            local current = get()
            local label = ""
            for _, choice in ipairs(choices) do
                if choice.value == current then label = choice.label end
            end
            W.SetLabel(button, label)
            PaintButton(button)
        end
        return button
    end

    -- The panel a section's settings sit on.
    function W.Card(parent)
        local card = CreateFrame("Frame", nil, parent)
        Backdrop(card, { 1, 1, 1, 0.035 }, W.FAINT)
        return card
    end

    -- A one-line note over `parent`, a coloured dot before its text; hidden.
    function W.Toast(parent)
        local toast = CreateFrame("Frame", nil, parent)
        toast:SetFrameLevel(parent:GetFrameLevel() + 40)
        Backdrop(toast, { 0.09, 0.09, 0.09, 0.97 })
        toast.dot = W.Flat(toast, "ARTWORK", W.GOOD)
        toast.dot:SetSize(6, 6)
        toast.dot:SetPoint("LEFT", toast, "LEFT", 12, 0)
        toast.text = W.Text(toast, 12)
        toast.text:SetPoint("LEFT", toast.dot, "RIGHT", 8, 0)
        toast:Hide()
        return toast
    end

    ---------------------------------------------------------------------------
    -- Smooth scrolling for a ScrollFrame with its child set, by hand (which
    -- scroll templates a client ships varies). The page eases to its target;
    -- a slim gold thumb shows and drags it, nothing when the page fits.
    -- `onScroll(y)` is told every move. Answers { Update, ScrollTo(y, now),
    -- Limit, Target }.
    ---------------------------------------------------------------------------

    local SCROLL_WIDTH = 4
    local MIN_THUMB = 28
    local WHEEL_STEP = 70
    local EASE = 14         -- per second: how quickly the page catches up
    local THUMB = Style.BORDER_COLOR

    function W.Scroller(scrollFrame, onScroll)
        local scroller = {}
        local target = 0

        local track = CreateFrame("Frame", nil, scrollFrame:GetParent())
        track:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 6, -4)
        track:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 6, 4)
        track:SetWidth(SCROLL_WIDTH)
        -- Runs the easing: always shown, unlike the track.
        local driver = CreateFrame("Frame", nil, scrollFrame:GetParent())
        local groove = track:CreateTexture(nil, "BACKGROUND")
        groove:SetAllPoints(track)
        groove:SetColorTexture(1, 1, 1, 0.04)

        local thumb = CreateFrame("Frame", nil, track)
        thumb:SetWidth(SCROLL_WIDTH)
        thumb:SetHeight(MIN_THUMB)
        thumb:EnableMouse(true)
        thumb:RegisterForDrag("LeftButton")
        local thumbTexture = thumb:CreateTexture(nil, "ARTWORK")
        thumbTexture:SetAllPoints(thumb)
        thumbTexture:SetColorTexture(THUMB[1], THUMB[2], THUMB[3], 0.7)
        thumb:SetScript("OnEnter", function() thumbTexture:SetColorTexture(THUMB[1], THUMB[2], THUMB[3], 1) end)
        thumb:SetScript("OnLeave", function() thumbTexture:SetColorTexture(THUMB[1], THUMB[2], THUMB[3], 0.7) end)

        local function ContentHeight()
            return scrollFrame:GetScrollChild():GetHeight()
        end

        function scroller.Limit()
            return math.max(0, ContentHeight() - scrollFrame:GetHeight())
        end

        local function Clamp(y)
            return math.max(0, math.min(y, scroller.Limit()))
        end

        function scroller.Update()
            local limit = scroller.Limit()
            local trackHeight = track:GetHeight()
            if limit <= 0 or trackHeight <= 0 then
                track:Hide()
                return
            end
            track:Show()
            local height = trackHeight * (scrollFrame:GetHeight() / ContentHeight())
            height = math.min(trackHeight, math.max(MIN_THUMB, height))
            thumb:SetHeight(height)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", track, "TOP", 0,
                -(trackHeight - height) * (scrollFrame:GetVerticalScroll() / limit))
        end

        local function Set(y)
            scrollFrame:SetVerticalScroll(y)
            scroller.Update()
            onScroll(y)
        end

        local function Ease(self, elapsed)
            local y = scrollFrame:GetVerticalScroll()
            local gap = target - y
            if math.abs(gap) < 0.5 then
                self:SetScript("OnUpdate", nil)
                Set(target)
            else
                Set(y + gap * (1 - math.exp(-EASE * elapsed)))
            end
        end

        function scroller.ScrollTo(y, now)
            target = Clamp(y)
            if now then
                driver:SetScript("OnUpdate", nil)
                Set(target)
            else
                driver:SetScript("OnUpdate", Ease)
            end
        end

        function scroller.Target() return target end

        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(_, delta)
            scroller.ScrollTo(target - delta * WHEEL_STEP)
        end)
        scrollFrame:HookScript("OnSizeChanged", function()
            target = Clamp(target)
            scroller.Update()
        end)

        thumb:SetScript("OnDragStart", function(self)
            local startCursor, startScroll = CursorY(self), scrollFrame:GetVerticalScroll()
            self:SetScript("OnUpdate", function(me)
                local travel = track:GetHeight() - me:GetHeight()
                local limit = scroller.Limit()
                if travel <= 0 or limit <= 0 then return end
                -- Dragging down scrolls down; the cursor axis points up.
                scroller.ScrollTo(startScroll + (startCursor - CursorY(me)) * (limit / travel), true)
            end)
        end)
        thumb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

        scroller.Update()
        return scroller
    end
end
