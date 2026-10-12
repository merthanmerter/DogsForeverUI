-- Panel: the backdrop the chat sits in (DogsForeverUI.Panel) - the windows'
-- tone, clear at rest and at half under the mouse - plus letters in place of
-- button icons and the addon's thin scrollbar. Takes no mouse itself.

local Panel = {}
DogsForeverUI.Panel = Panel

do -- private scope
    local Style = DogsForeverUI.Style

    ---------------------------------------------------------------------------
    -- Letters for icons, as the minimap header has them: the clock's font in
    -- the zone name's gold, dimmed until the mouse is on it, a pixel down
    -- while pressed. Kept by button in our own table - nothing written on it.
    ---------------------------------------------------------------------------

    Panel.LETTER_FONT = "WhiteNormalNumberFont"
    Panel.LETTER_COLOR = { 1, 0.82, 0 }             -- NORMAL_FONT_COLOR
    Panel.LETTER_ALPHA = 0.8                        -- at rest; 1 under the mouse
    Panel.MUTED = { 0.5, 0.5, 0.5 }                 -- a letter for something switched off
    -- A blinking letter (the game flashing its button): low to whole and back.
    Panel.BLINK_TIME = 1
    Panel.BLINK_LOW = 0.25

    local holders = setmetatable({}, { __mode = "k" })   -- button -> { frame, hover, fade, alert, blink }

    local function PaintLetter(entry)
        if entry.alert then return end      -- (Blink paints it)
        entry.frame:SetAlpha((entry.hover and 1 or Panel.LETTER_ALPHA) * entry.fade)
    end

    local function Blink(entry, elapsed)
        entry.blink = (entry.blink + elapsed) % (2 * Panel.BLINK_TIME)
        local up = entry.blink / Panel.BLINK_TIME
        if up > 1 then up = 2 - up end
        entry.frame:SetAlpha(Panel.BLINK_LOW + (1 - Panel.BLINK_LOW) * up)
    end

    -- `button`'s letter blinking (`on`), or back to its panel's fade.
    function Panel.Alert(button, on)
        local entry = holders[button]
        on = on and true or false
        if not entry or entry.alert == on then return end
        entry.alert = on
        if on then
            entry.blink = 0
            entry.frame:SetScript("OnUpdate", function(_, elapsed) Blink(entry, elapsed) end)
            Blink(entry, 0)
        else
            entry.frame:SetScript("OnUpdate", nil)
            PaintLetter(entry)
        end
    end

    -- `letter` on `frame`, kept for `button`. Answers its text and its entry.
    local function Hold(button, frame, letter)
        local text = frame:CreateFontString(nil, "OVERLAY")
        text:SetFontObject(_G[Panel.LETTER_FONT] or GameFontNormal)
        local colour = Panel.LETTER_COLOR
        text:SetTextColor(colour[1], colour[2], colour[3])
        text:SetText(letter)
        text:SetPoint("CENTER", frame, "CENTER", 0, 0)
        local entry = { frame = frame, hover = false, fade = 1 }
        holders[button] = entry
        PaintLetter(entry)
        return text, entry
    end

    local function Hover(entry, on)
        entry.hover = on
        PaintLetter(entry)
    end

    -- `button` showing `letter`, its own `art` textures off. Answers the text.
    function Panel.Letter(button, letter, art)
        for _, texture in ipairs(art or {}) do
            if type(texture) == "table" and texture.SetAlpha then texture:SetAlpha(0) end
        end
        local holder = CreateFrame("Frame", nil, button)
        holder:SetAllPoints(button)
        holder:EnableMouse(false)
        holder:SetFrameLevel(button:GetFrameLevel() + 2)
        local text, entry = Hold(button, holder, letter)
        local function At(x, y)
            text:ClearAllPoints()
            text:SetPoint("CENTER", holder, "CENTER", x, y)
        end
        button:HookScript("OnEnter", function() Hover(entry, true) end)
        button:HookScript("OnLeave", function() Hover(entry, false) end)
        button:HookScript("OnMouseDown", function() At(1, -1) end)
        button:HookScript("OnMouseUp", function() At(0, 0) end)
        return text
    end

    -- Sees the mouse but takes no click: clicks and motion pass on to what is
    -- under it (EllesmereUI's ghost tabs: else the frame below lost its tooltip).
    function Panel.PassThrough(frame)
        frame:SetMouseClickEnabled(false)
        frame:SetMouseMotionEnabled(true)
        frame:SetPropagateMouseClicks(true)
        frame:SetPropagateMouseMotion(true)
    end

    -- A letter over a game button (the chat's header): the button untouched,
    -- the letter drawn by a ghost on `host` laid over it. Answers the text and the ghost.
    function Panel.Ghost(host, button, letter)
        local ghost = CreateFrame("Frame", nil, host)
        ghost:SetAllPoints(button)
        local text, entry = Hold(button, ghost, letter)
        ghost:SetScript("OnEnter", function() Hover(entry, true) end)
        ghost:SetScript("OnLeave", function() Hover(entry, false) end)
        Panel.PassThrough(ghost)
        return text, ghost
    end

    ---------------------------------------------------------------------------
    -- The backdrop
    ---------------------------------------------------------------------------

    local REST_ALPHA = 0
    Panel.HOVER_ALPHA = 0.5
    local FADE_TIME = 0.2       -- seconds from one to the other

    -- The background at its opacity, the panel's letter buttons faded with it.
    function Panel.Paint(panel)
        local colour = Style.WINDOW_BACKGROUND
        panel.bg:SetColorTexture(colour[1], colour[2], colour[3], panel.bgAlpha)
        if not panel.letters then return end
        local k = (panel.bgAlpha - REST_ALPHA) / (Panel.HOVER_ALPHA - REST_ALPHA)
        k = math.max(0, math.min(1, k))
        for _, button in ipairs(panel.letters() or {}) do
            local entry = holders[button]
            if entry and entry.fade ~= k then
                entry.fade = k
                PaintLetter(entry)
            end
        end
    end

    local function Step(panel, elapsed)
        local over = panel:IsMouseOver() or (panel.active and panel.active())
        local target = over and Panel.HOVER_ALPHA or REST_ALPHA
        local now = panel.bgAlpha
        if now == target then return end
        local step = elapsed * (Panel.HOVER_ALPHA - REST_ALPHA) / FADE_TIME
        if now < target then now = math.min(target, now + step) else now = math.max(target, now - step) end
        panel.bgAlpha = now
        Panel.Paint(panel)
    end

    -- opts.active() -> keep the background up with the mouse away (an edit
    -- box in use); opts.letters() -> the letter buttons that fade with it.
    function Panel.New(parent, opts)
        opts = opts or {}
        local panel = CreateFrame("Frame", nil, parent)
        panel:EnableMouse(false)
        panel.active = opts.active
        panel.letters = opts.letters
        panel.bgAlpha = REST_ALPHA
        panel.bg = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
        panel.bg:SetAllPoints(panel)
        Panel.Paint(panel)
        panel:SetScript("OnUpdate", Step)
        return panel
    end

    ---------------------------------------------------------------------------
    -- The game's minimal scrollbar in the addon's look: its art and arrows
    -- clear, a thin dark track and a gold thumb drawn instead; the game's
    -- thumb is still what is dragged.
    ---------------------------------------------------------------------------

    Panel.SCROLL_WIDTH = 3      -- the room a scrollbar takes
    Panel.SCROLL_PIXELS = 2     -- its track and thumb, in real pixels

    -- `pixels` real pixels in `region`'s units: the same on screen whatever its scale.
    function Panel.Pixels(region, pixels)
        return pixels * Style.PixelSize(region)
    end

    local function Off(region)
        if region then region:SetAlpha(0) end
    end

    -- A full-height strip of `colour` on `parent`, `width` wide.
    local function Strip(parent, layer, colour, alpha, width)
        local texture = parent:CreateTexture(nil, layer)
        texture:SetColorTexture(colour[1], colour[2], colour[3], alpha)
        texture:SetWidth(width)
        texture:SetPoint("TOP", parent, "TOP", 0, 0)
        texture:SetPoint("BOTTOM", parent, "BOTTOM", 0, 0)
        return texture
    end

    local styledBars = setmetatable({}, { __mode = "k" })
    function Panel.ScrollBar(bar)
        if not bar or styledBars[bar] then return end
        local track = bar.Track
        local thumb = track and track.Thumb
        if not thumb then return end
        styledBars[bar] = true
        for _, key in ipairs({ "Begin", "Middle", "End" }) do
            Off(track[key])
            Off(thumb[key])
        end
        -- No arrows: invisible and deaf; the wheel and the thumb still scroll.
        for _, key in ipairs({ "Back", "Forward" }) do
            local step = bar[key]
            if step then
                Off(step.Texture)
                Off(step)
                step:EnableMouse(false)
            end
        end

        -- The track the bar's whole height (the game keeps 19 for the arrows).
        track:ClearAllPoints()
        track:SetPoint("TOP", bar, "TOP", 0, 0)
        track:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)

        local width = Panel.Pixels(track, Panel.SCROLL_PIXELS)
        local tone = Style.BACKGROUND_COLOR
        Strip(track, "BACKGROUND", tone, tone[4], width)
        return Strip(thumb, "OVERLAY", Style.BORDER_COLOR, 1, width)
    end
end
