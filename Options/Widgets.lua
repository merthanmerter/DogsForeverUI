-- The options window's controls, drawn in the frames' look rather than taken
-- from the game's templates: the same flat fills with their sheen, the same
-- dark background, the same gold border colour (Core\Style.lua) - as one
-- plain line inside each control's edges (W.Border), since a control is
-- small - and the addon's font.
--
--   Button      a flat button; states: normal, active (gold), armed (red)
--   TwoStep     a button that asks first: one click arms it, the next acts
--   Toggle      an on/off switch: a small bar that fills gold, knob at its end
--   Slider      a bar that fills gold to the value, with a thumb
--   NumberBox   a box for a number: Enter or leaving it keeps the number,
--               Esc puts the old one back, Tab goes on to the next box
--   TextBox     a box for a name or an ID
--   Segmented   a few choices side by side, the picked one gold
--   Dropdown    a longer list of choices, opened under the button
--   Card        the panel a section's settings sit on
--   Glyph       the two drawn marks: a close cross and a chevron
--
-- Every control takes `get` and `set` where it shows a setting, and has a
-- Refresh() that shows what `get` says now. No control writes a setting on
-- its own refresh.

local W = {}
DogsForeverUI.Widgets = W

do -- private scope
    local Style = DogsForeverUI.Style
    local FLAT = Style.FLAT_TEXTURE
    local B = Style.BORDER_COLOR

    W.GOLD = { Style.GOLD[1], Style.GOLD[2], Style.GOLD[3], 1 }
    W.TEXT = { 0.94, 0.94, 0.94, 1 }
    W.MUTED = { 0.62, 0.62, 0.62, 1 }
    W.DIM = { 0.40, 0.40, 0.40, 1 }
    W.DARK_TEXT = { 0.08, 0.06, 0.02, 1 }
    W.GOOD = { 0.55, 0.85, 0.45, 1 }
    W.BAD = { 1.00, 0.42, 0.36, 1 }
    W.DANGER = { 0.70, 0.16, 0.10, 1 }
    W.FIELD = { 0, 0, 0, 0.45 }
    W.RAISED = { 1, 1, 1, 0.07 }
    W.HOVER = { 1, 1, 1, 0.12 }
    W.PRESSED = { 1, 1, 1, 0.03 }
    W.TRACK = { 0.13, 0.13, 0.13, 1 }
    -- Outline colours, OPAQUE: the border's gold mixed with the window's dark
    -- by hand (at 55% and 30%), so nothing under a line can show through and
    -- make one side of an outline look different from another.
    local function Mix(share)
        local dark = 0.06
        return { B[1] * share + dark * (1 - share), B[2] * share + dark * (1 - share),
                 B[3] * share + dark * (1 - share), 1 }
    end
    W.LINE = Mix(0.55)                          -- a control's outline
    W.FAINT = Mix(0.30)                         -- a card's, and the rules
    W.FOCUS = { Style.GOLD[1], Style.GOLD[2], Style.GOLD[3], 1 }
    W.KNOB_LINE = { 0.02, 0.02, 0.02, 1 }

    W.CONTROL_HEIGHT = 24

    ---------------------------------------------------------------------------
    -- Pieces.
    ---------------------------------------------------------------------------

    function W.Flat(parent, layer, colour, sublevel)
        local texture = parent:CreateTexture(nil, layer, nil, sublevel)
        texture:SetTexture(FLAT)
        W.Colour(texture, colour)
        return texture
    end

    function W.Colour(texture, colour)
        texture:SetVertexColor(colour[1], colour[2], colour[3], colour[4] or 1)
    end

    -- Text in the addon's font. One line unless `width` is given, then it
    -- wraps to that width (give such text two anchors, left and right, too,
    -- and FitText it).
    --
    -- No drop shadow: on the window's dark background it adds nothing, and
    -- one UI unit of shadow is not a whole number of pixels at most UI
    -- scales - it smeared the letters' edges, which read as text drawn
    -- without anti-aliasing.
    function W.Text(parent, size, colour, bold, width)
        local text = parent:CreateFontString(nil, "OVERLAY")
        if bold then
            Style.SetBoldFont(text, size)
        else
            text:SetFont(Style.FONT, size, "")
        end
        text:SetShadowOffset(0, 0)
        colour = colour or W.TEXT
        text:SetTextColor(colour[1], colour[2], colour[3], colour[4] or 1)
        text:SetJustifyH("LEFT")
        if width then
            text:SetWidth(width)
            text:SetWordWrap(true)
        else
            text:SetWordWrap(false)
        end
        return text
    end

    -- Wrapped text laid out for sure: pinned left and right, so its width is
    -- the anchors' and not a guess, and as tall as its lines. A width alone
    -- let a last word drop out of sight (a description ended at "smaller"
    -- with its "text." gone). Answers the height.
    function W.FitText(text)
        local height = text:GetStringHeight() or 0
        if height > 0 then text:SetHeight(height) end
        return height
    end

    function W.SetTextColour(text, colour)
        text:SetTextColor(colour[1], colour[2], colour[3], colour[4] or 1)
    end

    ---------------------------------------------------------------------------
    -- A CONTROL'S OUTLINE: four plain lines just INSIDE its edges, on a thin
    -- frame over it (so nothing the control holds - a gold fill, a picked
    -- segment - is drawn over them). Each line a whole number of pixels thick
    -- (PixelUtil, the game's own), at least one; square corners; opaque.
    --
    -- Not the frames' drawn border (Style.AddBorder): in the options window,
    -- round boxes and buttons, that came out with some sides missing or dim
    -- and others bright, and neither pixel-snapping it nor thicker lines put
    -- it right. The frames themselves keep it; the window wears it too.
    ---------------------------------------------------------------------------

    local SIDES = { "top", "bottom", "left", "right" }
    local outlines = setmetatable({}, { __mode = "k" })

    -- One UI unit, to the nearest whole pixel and at least one - and a hair
    -- over, so a line exactly a pixel thick can never round away to none.
    local function Thickness(frame)
        if PixelUtil and PixelUtil.GetNearestPixelSize and frame.GetEffectiveScale then
            local scale = frame:GetEffectiveScale()
            if type(scale) == "number" and scale > 0 then
                return PixelUtil.GetNearestPixelSize(1, scale, 1) * 1.01
            end
        end
        return 1
    end

    local function LayOut(outline)
        local edge, thick = outline.edge, Thickness(outline.edge)
        local top, bottom, left, right = outline.top, outline.bottom, outline.left, outline.right
        top:ClearAllPoints()
        top:SetPoint("TOPLEFT", edge, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", edge, "TOPRIGHT", 0, 0)
        top:SetHeight(thick)
        bottom:ClearAllPoints()
        bottom:SetPoint("BOTTOMLEFT", edge, "BOTTOMLEFT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", 0, 0)
        bottom:SetHeight(thick)
        -- The sides between the top and the bottom, so no pixel is drawn twice.
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", edge, "TOPLEFT", 0, -thick)
        left:SetPoint("BOTTOMLEFT", edge, "BOTTOMLEFT", 0, thick)
        left:SetWidth(thick)
        right:ClearAllPoints()
        right:SetPoint("TOPRIGHT", edge, "TOPRIGHT", 0, -thick)
        right:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", 0, thick)
        right:SetWidth(thick)
        outline.thick = thick
    end

    function W.Border(frame, colour)
        local edge = CreateFrame("Frame", nil, frame)
        edge:SetAllPoints(frame)
        edge:SetFrameLevel(frame:GetFrameLevel() + 8)
        local outline = { frame = frame, edge = edge }
        for _, side in ipairs(SIDES) do
            local line = edge:CreateTexture(nil, "OVERLAY", nil, 7)
            line:SetTexture(FLAT)
            outline[side] = line
        end
        LayOut(outline)
        W.TintBorder(outline, colour or W.LINE)
        outlines[outline] = true
        return outline
    end

    -- An outline's lines in another colour: a box with the keyboard, say.
    function W.TintBorder(outline, colour)
        outline.colour = colour
        for _, side in ipairs(SIDES) do W.Colour(outline[side], colour) end
    end

    -- A new UI scale: every line a whole number of pixels again.
    function W.RelayOutlines()
        for outline in pairs(outlines) do LayOut(outline) end
    end
    local rescale = CreateFrame("Frame")
    rescale:RegisterEvent("UI_SCALE_CHANGED")
    rescale:RegisterEvent("DISPLAY_SIZE_CHANGED")
    rescale:SetScript("OnEvent", W.RelayOutlines)

    -- The window's own border is the frames' (Style.AddBorder); its edges are
    -- put on whole pixels (Style.SnapBorder) whenever the window is shown or
    -- moved.
    local snapped = {}
    function W.KeepSnapped(border)
        snapped[#snapped + 1] = border
    end
    function W.SnapBorders()
        for _, border in ipairs(snapped) do
            if border:IsVisible() then pcall(Style.SnapBorder, border) end
        end
    end

    -- The thickness of a thin line, in `region`'s units: the whole number of
    -- real pixels nearest one UI unit, as the borders' lines (W.Border) - one
    -- pixel alone can vanish.
    function W.Pixel(region)
        if PixelUtil and PixelUtil.GetPixelToUIUnitFactor and region.GetEffectiveScale then
            local scale = region:GetEffectiveScale()
            if type(scale) == "number" and scale > 0 then
                local px = PixelUtil.GetPixelToUIUnitFactor() / scale
                return math.max(1, math.floor(1 / px + 0.5)) * px
            end
        end
        return 1
    end

    -- A hairline across `parent`: along its top edge, `y` down.
    function W.Hairline(parent, colour, y, left, right)
        local line = W.Flat(parent, "ARTWORK", colour)
        line:SetPoint("TOPLEFT", parent, "TOPLEFT", left or 0, -(y or 0))
        line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(right or 0), -(y or 0))
        line:SetHeight(W.Pixel(parent))
        return line
    end

    -- The two drawn marks, from two rotated strokes each: "close" (a cross,
    -- `size` across) and "down" (a chevron). Answers the strokes.
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
                -- The two halves of a "v", "\" and "/", meeting at the bottom.
                local half = size * 0.55
                stroke:SetSize(half, thick)
                local x = (index == 1 and -1 or 1) * half * 0.35
                stroke:SetPoint("CENTER", parent, "CENTER", x, 0)
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
    -- Buttons.
    ---------------------------------------------------------------------------

    local function PaintButton(button)
        local style = button.style or "normal"
        local enabled = button:IsEnabled()
        local bg, text = W.RAISED, W.TEXT
        if style == "active" then
            bg, text = W.GOLD, W.DARK_TEXT
        elseif style == "armed" then
            bg, text = W.DANGER, W.TEXT
        elseif style == "flat" then
            bg = { 0, 0, 0, 0 }
        end
        if not enabled then
            text = W.DIM
        elseif button.pressed then
            bg = style == "normal" and W.PRESSED or bg
        elseif button.hovered then
            if style == "normal" or style == "flat" then
                bg = W.HOVER
            else
                bg = { math.min(1, bg[1] * 1.15), math.min(1, bg[2] * 1.15), math.min(1, bg[3] * 1.15), 1 }
            end
        end
        -- The picked item of a list, or of the sidebar, in gold.
        if button.selected and enabled and style == "flat" then text = W.GOLD end
        W.Colour(button.bg, bg)
        if button.label then W.SetTextColour(button.label, text) end
        if button.glyph then
            for _, stroke in ipairs(button.glyph) do W.Colour(stroke, text) end
        end
    end
    W.PaintButton = PaintButton

    -- `onClick(button, mouseButton)`. The label is button.label; set it with
    -- W.SetLabel.
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
        if style ~= "flat" then button.border = W.Border(button) end

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

    function W.SetEnabled(button, enabled)
        if enabled then button:Enable() else button:Disable() end
        PaintButton(button)
    end

    -- A small square button with a drawn mark and no outline: the window's
    -- close button, a list row's remove.
    function W.IconButton(parent, kind, size, onClick)
        local button = W.Button(parent, nil, size, onClick, "flat")
        button:SetHeight(size)
        button.glyph = W.Glyph(button, kind, size * 0.45)
        PaintButton(button)
        return button
    end

    -- A button that asks first: the first click arms it - red, its label
    -- saying what the next click does - and a second within ARM_TIME acts.
    -- `ask()` (optional) answers whether this click needs asking at all;
    -- with none, every click does. button.press is the click, for a box whose
    -- Enter should press it.
    W.ARM_TIME = 4

    function W.TwoStep(parent, label, armedLabel, width, action, ask)
        local restStyle
        local function Disarm(button)
            button.armed = false
            W.SetLabel(button, label)
            W.SetStyle(button, restStyle)
        end
        local function Press(button)
            if not button.armed and (not ask or ask()) then
                button.armed = true
                W.SetLabel(button, armedLabel)
                W.SetStyle(button, "armed")
                local token = (button.armedToken or 0) + 1
                button.armedToken = token
                C_Timer.After(W.ARM_TIME, function()
                    if button.armed and button.armedToken == token then Disarm(button) end
                end)
                return
            end
            Disarm(button)
            action(button)
        end
        local button = W.Button(parent, label, width, Press)
        restStyle = button.style
        button.press = function() if button:IsEnabled() then Press(button) end end
        button.disarm = function() if button.armed then Disarm(button) end end
        return button
    end

    ---------------------------------------------------------------------------
    -- The toggle: a small bar, dark when off, filled gold when on, a light
    -- knob riding the end of the fill. It slides between the two.
    ---------------------------------------------------------------------------

    W.TOGGLE_WIDTH, W.TOGGLE_HEIGHT = 36, 18
    local KNOB = 12
    local SLIDE_TIME = 0.12

    local function PlaceKnob(toggle, v)
        toggle.value = v
        toggle.track:SetValue(v)
        toggle.knob:ClearAllPoints()
        local travel = W.TOGGLE_WIDTH - 6 - KNOB
        toggle.knob:SetPoint("LEFT", toggle.track, "LEFT", 3 + v * travel, 0)
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
        toggle:SetSize(W.TOGGLE_WIDTH, W.TOGGLE_HEIGHT)
        toggle:RegisterForClicks("LeftButtonUp")

        local track = CreateFrame("StatusBar", nil, toggle)
        track:SetAllPoints(toggle)
        track:SetMinMaxValues(0, 1)
        local bg = W.Flat(track, "BACKGROUND", W.TRACK)
        bg:SetAllPoints(track)
        Style.Paint(track, W.GOLD)
        toggle.track = track
        toggle.knob = W.Flat(track, "OVERLAY", W.TEXT)
        toggle.knob:SetSize(KNOB, KNOB)
        toggle.border = W.Border(toggle)

        toggle.get = get
        toggle:SetScript("OnClick", function() set(not get()) end)
        toggle:SetScript("OnEnter", function(self) W.TintBorder(self.border, W.FOCUS) end)
        toggle:SetScript("OnLeave", function(self) W.TintBorder(self.border, W.LINE) end)

        -- Instantly the first time (and whenever the panel is not on screen);
        -- sliding after that.
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
    -- The slider: a thin bar filled gold up to the value, a knob on it, and
    -- the value written beside it.
    --
    -- The knob is a frame of its own, over everything else, drawn where the
    -- value is. The slider's thumb - what the mouse drags - is invisible
    -- under it, the same size, so it sits exactly where the knob is drawn. A
    -- visible thumb could not be used: a thumb is one of the slider's own
    -- textures, and the track (a child frame) and its border are drawn over
    -- those, which cut a dark band through the middle of it.
    ---------------------------------------------------------------------------

    local KNOB_WIDTH, KNOB_HEIGHT = 10, 16

    -- spec = { min, max, step, text(value) -> string }
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
        track:SetHeight(6)
        track:SetMinMaxValues(spec.min, spec.max)
        local bg = W.Flat(track, "BACKGROUND", W.TRACK)
        bg:SetAllPoints(track)
        Style.Paint(track, W.GOLD)
        track.border = W.Border(track)
        slider.track = track

        local thumb = slider:CreateTexture(nil, "OVERLAY")
        thumb:SetColorTexture(0, 0, 0, 0)
        thumb:SetSize(KNOB_WIDTH, KNOB_HEIGHT)
        slider:SetThumbTexture(thumb)

        -- Above the track's border, which is above the track.
        local knob = CreateFrame("Frame", nil, slider)
        knob:SetSize(KNOB_WIDTH, KNOB_HEIGHT)
        knob:SetFrameLevel(track:GetFrameLevel() + 10)
        knob.fill = W.Flat(knob, "ARTWORK", W.TEXT)
        knob.fill:SetAllPoints(knob)
        knob.border = W.Border(knob, W.KNOB_LINE)
        slider.knob = knob
        slider:SetScript("OnEnter", function() W.Colour(knob.fill, W.GOLD) end)
        slider:SetScript("OnLeave", function() W.Colour(knob.fill, W.TEXT) end)

        slider.valueText = W.Text(parent, 12, W.TEXT)
        slider.valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)

        local function Show(value)
            track:SetValue(value)
            local share = 0
            if spec.max > spec.min then
                share = math.max(0, math.min(1, (value - spec.min) / (spec.max - spec.min)))
            end
            knob:ClearAllPoints()
            knob:SetPoint("LEFT", slider, "LEFT", share * (width - KNOB_WIDTH), 0)            slider.valueText:SetText(spec.text and spec.text(value) or tostring(value))
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
        return slider
    end

    ---------------------------------------------------------------------------
    -- Boxes.
    ---------------------------------------------------------------------------

    -- The boxes in the order they were made, for Tab to walk.
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
        box.bg = W.Flat(box, "BACKGROUND", W.FIELD)
        box.bg:SetAllPoints(box)
        box.border = W.Border(box)
        box:HookScript("OnEditFocusGained", function(self) W.TintBorder(self.border, W.FOCUS) end)
        box:HookScript("OnEditFocusLost", function(self) W.TintBorder(self.border, W.LINE) end)
        return box
    end

    -- A text box with a grey hint in it while it is empty.
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
        boxes[#boxes + 1] = box
        box:SetScript("OnTabPressed", FocusNext)
        return box
    end

    -- A number box. Enter, Tab or leaving it keeps the number typed;
    -- anything that is not a number, or is outside min..max, is put back
    -- rather than kept (a nil width takes a bar down with it); Esc puts the
    -- old one back. `limits` = { min, max, decimals }, optional.
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
        box:SetScript("OnEscapePressed", function(self)
            Show()
            self:ClearFocus()
        end)
        box:SetScript("OnTabPressed", function(self)
            Commit()
            FocusNext(self)
        end)
        box:HookScript("OnEditFocusLost", Commit)
        box.Refresh = Show
        boxes[#boxes + 1] = box
        return box
    end

    ---------------------------------------------------------------------------
    -- Choices.
    ---------------------------------------------------------------------------

    -- A few choices side by side in one outline, the picked one filled gold.
    -- choices = { { value, label }, ... }
    function W.Segmented(parent, choices, segmentWidth, get, set)
        local frame = CreateFrame("Frame", nil, parent)
        frame:SetSize(segmentWidth * #choices, W.CONTROL_HEIGHT - 2)
        local bg = W.Flat(frame, "BACKGROUND", W.FIELD)
        bg:SetAllPoints(frame)
        frame.border = W.Border(frame)
        frame.segments = {}

        for index, choice in ipairs(choices) do
            local segment = W.Button(frame, choice.label, segmentWidth, function()
                set(choice.value)
            end, "flat")
            segment:SetHeight(W.CONTROL_HEIGHT - 2)
            segment:SetPoint("LEFT", frame, "LEFT", (index - 1) * segmentWidth, 0)
            segment.value = choice.value
            if index > 1 then
                local divider = W.Flat(frame, "ARTWORK", W.FAINT)
                divider:SetPoint("TOPLEFT", frame, "TOPLEFT", (index - 1) * segmentWidth, 0)
                divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (index - 1) * segmentWidth, 0)
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

    -- The one list a dropdown opens, shared: only one is ever open.
    local popup
    local ITEM_HEIGHT = 22

    local function ClosePopup()
        if popup and popup:IsShown() then
            popup:Hide()
            popup.owner = nil
        end
    end
    W.ClosePopup = ClosePopup

    local function Popup()
        if popup then return popup end
        popup = CreateFrame("Frame", nil, UIParent)
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetClampedToScreen(true)
        popup:EnableMouse(true)
        popup:Hide()
        local bg = W.Flat(popup, "BACKGROUND", { 0.06, 0.06, 0.06, 0.98 })
        bg:SetAllPoints(popup)
        popup.border = W.Border(popup)
        popup.items = {}
        -- A click anywhere else shuts it, as the game's own menus do.
        popup:SetScript("OnEvent", function(self)
            if not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then
                ClosePopup()
            end
        end)
        popup:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
        popup:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
        return popup
    end

    local function OpenPopup(owner, choices, get, set)
        local list = Popup()
        if list:IsShown() and list.owner == owner then
            ClosePopup()
            return
        end
        list.owner = owner
        list:SetScale(owner:GetEffectiveScale() / UIParent:GetEffectiveScale())
        list:SetSize(owner:GetWidth(), #choices * ITEM_HEIGHT + 4)
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
        local current = get()
        for index, choice in ipairs(choices) do
            local item = list.items[index]
            if not item then
                item = W.Button(list, "", owner:GetWidth() - 4, nil, "flat")
                item:SetHeight(ITEM_HEIGHT)
                item.label:ClearAllPoints()
                item.label:SetPoint("LEFT", item, "LEFT", 8, 0)
                list.items[index] = item
            end
            item:SetWidth(owner:GetWidth() - 4)
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", list, "TOPLEFT", 2, -2 - (index - 1) * ITEM_HEIGHT)
            W.SetLabel(item, choice.label)
            item:SetScript("OnClick", function()
                set(choice.value)
                ClosePopup()
            end)
            item.selected = choice.value == current
            item:Show()
            W.PaintButton(item)
        end
        for index = #choices + 1, #list.items do list.items[index]:Hide() end
        list:Show()
        list:Raise()    end
    W.OpenPopup = OpenPopup

    -- A button showing the picked choice, opening the list under it.
    function W.Dropdown(parent, width, choices, get, set)
        local button = W.Button(parent, "", width, nil)
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", button, "LEFT", 8, 0)
        button.label:SetPoint("RIGHT", button, "RIGHT", -22, 0)
        button.label:SetJustifyH("LEFT")
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
            W.PaintButton(button)
        end
        return button
    end

    ---------------------------------------------------------------------------
    -- The card a section's settings sit on.
    ---------------------------------------------------------------------------

    function W.Card(parent)
        local card = CreateFrame("Frame", nil, parent)
        local bg = W.Flat(card, "BACKGROUND", { 1, 1, 1, 0.035 })
        bg:SetAllPoints(card)
        card.border = W.Border(card, W.FAINT)
        return card
    end
end
