-- A PANEL: the frame the chat windows sit in (the
-- player, 2026-10-03: "make the chatbar look like the Flare addon - their
-- layout but with our style ... default background opacity 0, on mouseover
-- 50%"). Drawn in the addon's own look (Core\Style.lua): the windows' dark
-- tone, no border and no line (the player, 2026-10-05: "remove the border
-- from the chat", then the line under the letter buttons).
--
--   * the background: the windows' tone, at no opacity until the mouse is
--     over the panel (or `active()` says it is in use), then at half -
--     faded over a fifth of a second either way;
--   * the panel's letter buttons: faded with the background - gone at rest,
--     whole under the mouse.
--
-- The panel is the addon's own frame and takes no mouse: clicks go through it
-- to whatever is under it, as before.

local Panel = {}
DogsForeverUI.Panel = Panel

do -- private scope
    local Style = DogsForeverUI.Style

    Panel.REST_ALPHA = 0        -- the background with the mouse away
    Panel.HOVER_ALPHA = 0.5     -- and with it over the panel
    Panel.FADE_TIME = 0.2       -- seconds from one to the other

    local function Step(panel, elapsed)
        local over = panel:IsMouseOver() or (panel.active and panel.active())
        local target = over and Panel.HOVER_ALPHA or Panel.REST_ALPHA
        local now = panel.bgAlpha
        if now == target then return end
        local step = (elapsed or 0) * (Panel.HOVER_ALPHA - Panel.REST_ALPHA) / Panel.FADE_TIME
        if now < target then now = math.min(target, now + step) else now = math.max(target, now - step) end
        panel.bgAlpha = now
        Panel.Paint(panel)
    end

    -- The background at its opacity; its letter buttons with it - none at
    -- rest, whole at the top of the fade (the player, 2026-10-03: "icons
    -- (letter buttons) should fade with bg and borders aswell"): the panel's
    -- owner says which they are (panel.letters).
    function Panel.Paint(panel)
        local colour = Style.WINDOW_BACKGROUND
        panel.bg:SetColorTexture(colour[1], colour[2], colour[3], panel.bgAlpha)
        if panel.letters then
            local k = (panel.bgAlpha - Panel.REST_ALPHA) / (Panel.HOVER_ALPHA - Panel.REST_ALPHA)
            k = math.max(0, math.min(1, k))
            for _, button in ipairs(panel.letters() or {}) do Panel.FadeLetter(button, k) end
        end
    end

    -- `opts`: active = function() -> whether to keep the background up with
    -- the mouse away (a chat edit box in use), letters = function() -> the
    -- letter buttons (Panel.Letter) that fade with it.
    function Panel.New(parent, opts)
        opts = opts or {}
        local panel = CreateFrame("Frame", nil, parent)
        panel:EnableMouse(false)
        panel.active = opts.active
        panel.letters = opts.letters
        panel.bgAlpha = Panel.REST_ALPHA

        panel.bg = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
        panel.bg:SetAllPoints(panel)
        local colour = Style.WINDOW_BACKGROUND
        panel.bg:SetColorTexture(colour[1], colour[2], colour[3], panel.bgAlpha)

        Panel.Paint(panel)
        panel:SetScript("OnUpdate", Step)
        return panel
    end

    ---------------------------------------------------------------------------
    -- LETTERS FOR ICONS (the player, 2026-10-03: "all icons in chat and
    -- damage meter should be letters similar to our minimap calendar and
    -- tracking"): a button's art off and a letter on it instead, as the
    -- minimap's header has them (Minimap\Minimap.lua, THE HEADER'S LETTERS) -
    -- the clock's font, the zone name's gold, a little dimmed until the mouse
    -- is over it, a pixel down while pressed. The panels' titles are written
    -- in the same font and gold (Panel.Title).
    ---------------------------------------------------------------------------

    Panel.LETTER_FONT = "WhiteNormalNumberFont"     -- the minimap clock's
    Panel.LETTER_COLOR = { 1, 0.82, 0 }             -- NORMAL_FONT_COLOR, the zone name's gold
    Panel.LETTER_ALPHA = 0.8                        -- at rest; 1 under the mouse
    Panel.MUTED = { 0.5, 0.5, 0.5 }                 -- a letter for something switched off

    function Panel.Font(text)
        if type(text) ~= "table" or type(text.SetFontObject) ~= "function" then return end
        local font = _G[Panel.LETTER_FONT] or _G.GameFontNormal
        if font then text:SetFontObject(font) end
    end

    -- A pane's title (a tab's words): the letters' font,
    -- in `colour` (the gold when none).
    function Panel.Title(text, colour)
        if type(text) ~= "table" then return end
        Panel.Font(text)
        colour = colour or Panel.LETTER_COLOR
        if text.SetTextColor then text:SetTextColor(colour[1], colour[2], colour[3]) end
    end

    -- A letter's opacity: dimmed or whole (the mouse on it), times its
    -- panel's fade. Kept here, by button - nothing written on the button.
    local holders = setmetatable({}, { __mode = "k" })   -- button -> { frame, hover, fade, alert }

    local function PaintLetter(entry)
        if entry.alert then return end      -- (blinking: Blink paints it)
        entry.frame:SetAlpha((entry.hover and 1 or Panel.LETTER_ALPHA) * entry.fade)
    end

    ---------------------------------------------------------------------------
    -- A LETTER THAT BLINKS (the player, 2026-10-03: "when chat for example
    -- 'Channels' icon is blinking it should show that icon too"): while the
    -- game flashes a button the letter shows, faded or not, and blinks as the
    -- game's flash does - a second up, a second down (ChannelFrameButton's
    -- FlashAnim) - from BLINK_LOW to whole and back.
    ---------------------------------------------------------------------------

    Panel.BLINK_TIME = 1        -- seconds from low to whole
    Panel.BLINK_LOW = 0.25

    local function Blink(entry, elapsed)
        entry.blink = (entry.blink + (elapsed or 0)) % (2 * Panel.BLINK_TIME)
        local up = entry.blink / Panel.BLINK_TIME
        if up > 1 then up = 2 - up end
        entry.frame:SetAlpha(Panel.BLINK_LOW + (1 - Panel.BLINK_LOW) * up)
    end

    -- `button`'s letter blinking (`on`) or back to its panel's fade.
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

    -- `button`'s letter faded to `k` (0 none - 1 whole) with its panel.
    function Panel.FadeLetter(button, k)
        local entry = holders[button]
        if not entry or entry.fade == k then return end
        entry.fade = k
        PaintLetter(entry)
    end

    -- `button` showing `letter` (its own art off: the textures the caller
    -- names, `art`). Answers the letter's text, to change it later.
    function Panel.Letter(button, letter, art)
        for _, texture in ipairs(art or {}) do
            if type(texture) == "table" and texture.SetAlpha then texture:SetAlpha(0) end
        end
        local holder = CreateFrame("Frame", nil, button)
        holder:SetAllPoints(button)
        holder:EnableMouse(false)
        holder:SetFrameLevel(button:GetFrameLevel() + 2)
        local text = holder:CreateFontString(nil, "OVERLAY")
        Panel.Title(text)
        text:SetText(letter)
        local function At(x, y)
            text:ClearAllPoints()
            text:SetPoint("CENTER", holder, "CENTER", x, y)
        end
        At(0, 0)
        local entry = { frame = holder, hover = false, fade = 1 }
        holders[button] = entry
        PaintLetter(entry)
        button:HookScript("OnEnter", function() entry.hover = true; PaintLetter(entry) end)
        button:HookScript("OnLeave", function() entry.hover = false; PaintLetter(entry) end)
        button:HookScript("OnMouseDown", function() At(1, -1) end)
        button:HookScript("OnMouseUp", function() At(0, 0) end)
        return text
    end

    -- A frame that sees the mouse come and go but takes no click: the click
    -- and the mouse's motion go on to whatever is under it (EllesmereUI's
    -- ghost tabs, field-tested: without the passing on, the frame under it
    -- lost its clicks and its tooltip). Where the client has no such flags:
    -- deaf to the mouse.
    function Panel.PassThrough(frame)
        if frame.SetMouseClickEnabled and frame.SetMouseMotionEnabled then
            frame:SetMouseClickEnabled(false)
            frame:SetMouseMotionEnabled(true)
            if frame.SetPropagateMouseClicks then frame:SetPropagateMouseClicks(true) end
            if frame.SetPropagateMouseMotion then frame:SetPropagateMouseMotion(true) end
        else
            frame:EnableMouse(false)
        end
    end

    -- A LETTER OVER A BUTTON OF THE GAME'S (the chat's header buttons): the
    -- button stays the game's, untouched by any script of the addon's - the
    -- letter is drawn by a ghost on `host` laid over it (anchored to it,
    -- never its child), whole while the mouse is on it, faded and blinking
    -- as any letter (keyed by the game's button, in the addon's own table).
    -- Answers the letter's text and the ghost.
    function Panel.Ghost(host, button, letter)
        local ghost = CreateFrame("Frame", nil, host)
        ghost:SetAllPoints(button)
        local text = ghost:CreateFontString(nil, "OVERLAY")
        Panel.Title(text)
        text:SetText(letter)
        text:SetPoint("CENTER", ghost, "CENTER", 0, 0)
        local entry = { frame = ghost, hover = false, fade = 1 }
        holders[button] = entry
        PaintLetter(entry)
        ghost:SetScript("OnEnter", function() entry.hover = true; PaintLetter(entry) end)
        ghost:SetScript("OnLeave", function() entry.hover = false; PaintLetter(entry) end)
        Panel.PassThrough(ghost)
        return text, ghost
    end

    ---------------------------------------------------------------------------
    -- A SCROLLBAR IN THE ADDON'S LOOK (the player, 2026-10-03: "scrollbars of
    -- chat and damage meter should be suitable with our style"): the game's
    -- minimal scrollbar (MinimalScrollBar.xml) - its track, thumb and arrow
    -- art at no opacity (the game changes the thumb's art as the mouse comes
    -- and goes, but each texture keeps its own opacity) - with a thin dark
    -- track and a gold thumb of the addon's drawn in their place, and no
    -- arrows. The game's thumb is still what is dragged.
    ---------------------------------------------------------------------------

    Panel.SCROLL_WIDTH = 3      -- the room a scrollbar takes
    Panel.SCROLL_PIXELS = 2     -- its track and thumb: real screen pixels

    -- THE SAME THICKNESS ON THE SCREEN WHEREVER IT IS DRAWN (the player,
    -- 2026-10-05, the tabs' sidebar's scrollbar beside the chat's: "obviously
    -- thicker than chat scroll"): the same width in UI units came out at
    -- different widths, the chat window being drawn at a scale of its own.
    -- `pixels` real pixels in `region`'s UI units.
    function Panel.Pixels(region, pixels)
        local scale = region:GetEffectiveScale()
        if PixelUtil and PixelUtil.GetPixelToUIUnitFactor and type(scale) == "number" and scale > 0 then
            return pixels * PixelUtil.GetPixelToUIUnitFactor() / scale
        end
        return pixels
    end

    local function Off(region)
        if type(region) == "table" and region.SetAlpha then region:SetAlpha(0) end
    end

    local styledBars = setmetatable({}, { __mode = "k" })
    function Panel.ScrollBar(bar)
        if type(bar) ~= "table" or styledBars[bar] then return end
        local track = bar.Track
        local thumb = track and track.Thumb
        if type(track) ~= "table" or type(thumb) ~= "table" or type(track.CreateTexture) ~= "function" then return end
        styledBars[bar] = true
        for _, key in ipairs({ "Begin", "Middle", "End" }) do
            Off(track[key])
            Off(thumb[key])
        end
        -- No arrows at all (the player, 2026-10-03: "we dont need scroll
        -- arrow icons"): each arrow button invisible and deaf to the mouse;
        -- the wheel and the thumb still scroll.
        for _, key in ipairs({ "Back", "Forward" }) do
            local step = bar[key]
            if type(step) == "table" then
                Off(step.Texture)
                Off(step)
                if step.EnableMouse then step:EnableMouse(false) end
            end
        end

        -- The track the bar's whole height (the player, 2026-10-03: "chat
        -- scrollbar should be full height properly fit the actual text
        -- area"): the game keeps 19 at each end for the arrows, gone here.
        if track.ClearAllPoints and track.SetPoint then
            track:ClearAllPoints()
            track:SetPoint("TOP", bar, "TOP", 0, 0)
            track:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
        end

        local width = Panel.Pixels(track, Panel.SCROLL_PIXELS)
        local back = track:CreateTexture(nil, "BACKGROUND")
        local tone = Style.BACKGROUND_COLOR
        back:SetColorTexture(tone[1], tone[2], tone[3], tone[4])
        back:SetWidth(width)
        back:SetPoint("TOP", track, "TOP", 0, 0)
        back:SetPoint("BOTTOM", track, "BOTTOM", 0, 0)

        local fill = thumb:CreateTexture(nil, "OVERLAY")
        local gold = Style.BORDER_COLOR
        fill:SetColorTexture(gold[1], gold[2], gold[3], 1)
        fill:SetWidth(width)
        fill:SetPoint("TOP", thumb, "TOP", 0, 0)
        fill:SetPoint("BOTTOM", thumb, "BOTTOM", 0, 0)
        return fill
    end

    -- At rest now, whatever it was (a panel shown again).
    function Panel.Rest(panel)
        panel.bgAlpha = Panel.REST_ALPHA
        Panel.Paint(panel)
    end
end
