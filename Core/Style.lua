-- THE LOOK
--
-- Every bar in the addon - unit frames, cast bars, swing bars, the five-second
-- countdown - is drawn from here, so they cannot drift apart:
--
--   * the fill: a flat colour with a soft sheen and shade, on every bar;
--   * behind it, a black tone, nearly opaque;
--   * round it, the tooltip's gold line, a soft bevel and a black line, the
--     corners rounded;
--   * labels in Media\Dog.ttf, outlined;
--   * the colours from one palette.

local Style = {}
DogsForeverUI.Style = Style

do -- private scope

    -- The fill, on every bar - unit frames, castbars, swing bars, the
    -- countdown, combo points, XP: FLAT_TEXTURE, a plain colour with
    -- AddSheen's soft shading on top. The player picked it for the frames from
    -- a preview and then asked for it on every bar. The game's own art was
    -- used before (the modern health bar, the cast bar and swing timer fills),
    -- but each is drawn for its own bar's proportions and broke up stretched
    -- into others; flat colour shaded only from top to bottom stretches any
    -- way cleanly, and needs no art the client might not have.
    Style.FLAT_TEXTURE = "Interface\\Buttons\\WHITE8X8"

    -- Behind every bar, for the part of it that is not filled: a plain black
    -- tone, nearly opaque, drawn as a colour rather than from a file. It used
    -- to be a texture in Media\, and when that file went missing the game drew
    -- its stand-in for a missing texture - solid green - behind every bar.
    Style.BACKGROUND_COLOR = { 0.05, 0.05, 0.05, 0.9 }

    -- Every label on every bar - unit frames, castbars, swing bars, the
    -- countdown, combo points, XP - is white, as the player asked. GOLD, the
    -- game's heading gold #ffbb20, is kept for the cast's fill and the
    -- player's own level.
    Style.TEXT_COLOR = { 1, 1, 1 }
    Style.GOLD = { 0xff / 255, 0xbb / 255, 0x20 / 255 }

    -- The border, three one-pixel lines with rounded corners, from the outside
    -- in: the game's tooltip gold - its line, measured off a screenshot at
    -- 178,142,97 - a darker gold under it as a soft bevel, and a black line
    -- that the bar's colour stops against. The tooltip border itself was the
    -- look wanted, but its gold line has a heavy dark band inside it baked into
    -- the same art, which cannot be taken off; drawn, the shade inside is ours
    -- to choose. BORDER_COLOR is the gold, for what is drawn to go with the
    -- border (the badge rings); DIVIDER_COLOR the black, for the hairlines
    -- between two bars, which continue the inner line.
    Style.BORDER_COLOR = { 178 / 255, 142 / 255, 97 / 255, 1 }
    Style.BEVEL_COLOR = { 110 / 255, 88 / 255, 60 / 255, 1 }
    Style.DIVIDER_COLOR = { 0, 0, 0, 1 }

    -- Every label on a bar, in the player's own font; a unit frame's name and
    -- level in its bold cut.
    Style.FONT = DogsForeverUI.MEDIA .. "Dog.ttf"
    Style.BOLD_FONT = DogsForeverUI.MEDIA .. "Dog-Bold.ttf"

    -- How far outside the bar the border reaches, for the spacing between
    -- bars: its three lines, each snapped to one real pixel.
    Style.BORDER_INSET = 3

    Style.SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"

    -- While a bar is being placed it says what it is and that it is unlocked,
    -- as the swing bars always have: its name on the left, this word on the
    -- right. A bar that reads only "unlocked" leaves the player guessing which
    -- one it is.
    Style.PLACEMENT_LABEL = "unlocked"

    ---------------------------------------------------------------------------
    -- THE PALETTE
    --
    -- Two muted colours rather than the game's full-strength ones, and every
    -- other colour pulled to the same two tones so the bars read as one set:
    --
    --   * health at the brightness of #43582f;
    --   * resources, casts and swings at the brightness of #19366e.
    --
    -- Seen in game, the palette was then asked to be lighter and more vivid, so
    -- every colour is adjusted twice on the way out; the hex stays as given so
    -- the base is readable:
    --
    --   * LIGHTER scales it up, brightest channel and all;
    --   * VIVID pushes the other channels further from the brightest, which is
    --     saturation without a change of hue. A grey stays grey.
    --
    -- Tone takes one of the game's colours - a class, a reaction, a resource, a
    -- cast state - keeps its hue, scales it so its brightest channel is that
    -- tone's, and raises any channel below the mana colour's darkest share of
    -- its tone up to it, so pure red becomes a deep red rather than red on black.
    ---------------------------------------------------------------------------

    -- Raised three times since (1.3/1.25, 1.7/1.4, 2.1/1.6): "these tones are
    -- too dark", and again on the modern bar art.
    local LIGHTER = 2.5
    local VIVID = 2.0
    local function hex(value) return value / 255 * LIGHTER end

    -- A tint cannot go past full, so no channel is left above 1: a lift that
    -- would take one past it stops there.
    local function Push(r, g, b, amount)
        local brightest = math.max(r, g, b)
        local function one(c)
            return math.min(1, math.max(0, brightest - (brightest - c) * amount))
        end
        return one(r), one(g), one(b)
    end

    local function Vivid(r, g, b) return Push(r, g, b, VIVID) end

    Style.HEALTH_COLOR = { Vivid(hex(0x43), hex(0x58), hex(0x2f)) }
    Style.HEALTH_TONE = hex(0x58)
    Style.POWER_TONE = math.min(1, hex(0x6e))
    local MIN_SHARE = 0x19 / 0x6e

    -- Mana is the exception: #18376e, as the player picked it, meant as the
    -- colour seen on screen rather than the tint. A tint multiplies with the
    -- texture, and the classic status bar texture is a grey gradient averaging
    -- roughly TEXTURE_SHADE, so the tint is divided by that to land on #18376e.
    --
    -- When the whole palette was then made lighter and more vivid again, mana
    -- was lifted with it by the same step the others took - LIGHTER and VIVID
    -- each over their previous 1.7 and 1.4 - rather than left behind as the one
    -- dark bar.
    --
    -- Past LIGHTER 2.1 its blue is at full, and a harder push then only takes
    -- green out of it, which reads darker, not more vivid. So from there it is
    -- pushed a fixed, lighter amount: the blue stays full and the green left in
    -- is what makes it lighter (#1a6fff; it was #165edc).
    local TEXTURE_SHADE = 0.62
    local MANA_LIFT = LIGHTER / 1.7
    local MANA_PUSH = 1.15
    Style.MANA_COLOR = { Push(
        0x18 / 255 / TEXTURE_SHADE * MANA_LIFT,
        0x37 / 255 / TEXTURE_SHADE * MANA_LIFT,
        0x6e / 255 / TEXTURE_SHADE * MANA_LIFT,
        MANA_PUSH) }

    -- At a tone of full brightness the lift has nowhere left to go, and a
    -- harder push only takes the other channels out, which reads darker: a
    -- blue went from #0053e7 to #0033ff. Those colours keep the push they had.
    local FULL_VIVID = 1.6

    function Style.Tone(r, g, b, tone)
        local floor = tone * MIN_SHARE
        local brightest = math.max(r, g, b)
        if brightest <= 0 then return floor, floor, floor end

        local scale = tone / brightest
        return Push(math.max(floor, r * scale), math.max(floor, g * scale),
            math.max(floor, b * scale), tone >= 1 and FULL_VIVID or VIVID)
    end

    -- A colour at the resource bars' depth, as a table.
    local function Toned(r, g, b)
        return { Style.Tone(r, g, b, Style.POWER_TONE) }
    end

    -- One of the game's own colour objects, as a table, or the value it has
    -- always had where the client does not define it.
    local function GameColour(colour, r, g, b)
        if type(colour) == "table" and type(colour.GetRGB) == "function" then
            return { colour:GetRGB() }
        end
        return { r, g, b }
    end

    -- A cast bar's colour per state: exactly the game's own classic castbar
    -- colours, not toned - CastingBarTypeInfo's classicFillColor
    -- (Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua): yellow for a cast,
    -- green for a channel, grey when it cannot be interrupted, red when it
    -- failed or was interrupted.
    --
    -- Except the cast: the game's classic yellow (1, 0.7, 0) reads orange, and
    -- the player asked for it to be the heading gold, #ffbb20.
    Style.CAST_COLOR = {
        casting         = { Style.GOLD[1], Style.GOLD[2], Style.GOLD[3] },
        channel         = GameColour(CASTBAR_CLASSIC_GREEN, 0.0, 1.0, 0.0),
        uninterruptible = GameColour(CASTBAR_CLASSIC_GRAY, 0.7, 0.7, 0.7),
        failed          = GameColour(CASTBAR_CLASSIC_RED, 1.0, 0.0, 0.0),
    }

    -- The swing bars: grey, as the game's own swing timer is. Its grey used to
    -- come from the swing timer art, left untinted; on the flat fill the grey
    -- has to be the colour itself. One colour for every hand; each bar is
    -- labelled.
    local SWING_GREY = { 0.6, 0.6, 0.6 }
    Style.SWING_COLOR = {
        mainhand = SWING_GREY,
        offhand  = SWING_GREY,
        ranged   = SWING_GREY,
    }

    -- The five-second countdown: the player's mana bar colour, since it is
    -- mana it counts for.
    Style.COUNTDOWN_COLOR = Style.MANA_COLOR

    -- The XP bar: the game's classic experience purple, exactly - not toned
    -- like the rest of the palette, which made it far brighter than the
    -- original. The classic XP bar was this same texture tinted this same
    -- colour, so it looks as it did.
    Style.XP_COLOR = { 0.58, 0.0, 0.55 }

    -- Combo points: the red of the game's own combo point gems, at the
    -- resource bars' depth.
    Style.COMBO_COLOR = Toned(1.0, 0.15, 0.1)

    -- The rested XP still ahead of it, in the classic bar's own rested blue,
    -- exactly, drawn solid so it reads as its own stretch of the bar.
    Style.RESTED_COLOR = { 0.0, 0.39, 0.88 }

    -- Whether this client has a piece of the game's art, asked before it is
    -- used: a missing atlas draws nothing at all.
    function Style:HasAtlas(name)
        if type(name) ~= "string" then return false end
        if type(C_Texture) ~= "table" or type(C_Texture.GetAtlasInfo) ~= "function" then
            return false
        end
        local ok, info = pcall(C_Texture.GetAtlasInfo, name)
        return ok and info ~= nil
    end

    ---------------------------------------------------------------------------
    -- Drawing.
    ---------------------------------------------------------------------------

    -- A bar's fill, the flat colour, stretched along the bar rather than tiled.
    -- The colour is the bar's own tint (SetStatusBarColor).
    function Style.SetBarFill(bar)
        bar:SetStatusBarTexture(Style.FLAT_TEXTURE)
        local fill = bar:GetStatusBarTexture()
        fill:SetHorizTile(false)
        fill:SetVertTile(false)
        return fill
    end

    -- A bar in the addon's look: the flat fill in a colour from the palette,
    -- with its sheen and shade.
    function Style.Paint(bar, colour)
        Style.SetBarFill(bar)
        Style.AddSheen(bar)
        bar:SetStatusBarColor(colour[1], colour[2], colour[3], 1)
    end

    -- Soft shading over a flat fill, so it reads as a bar rather than a
    -- sticker: a light sheen fading down over the top half, a slight shade
    -- deepening over the bottom half. Both are pinned to the fill itself, so
    -- they cover only what is filled and follow it as it grows - the value
    -- is never read, so a secret one is fine. Shaded only from top to bottom,
    -- it stretches any way without breaking up.
    --
    -- MakeSheen hands the two textures back and writes nothing on the bar, for
    -- a bar that is not the addon's own (the game's nameplates); AddSheen is
    -- for the addon's bars, and keeps them on the bar so they are made once.
    local SHEEN, SHADE = 0.22, 0.25

    function Style.AddSheen(bar)
        if bar.sheen then return end
        bar.sheen, bar.shade = Style.MakeSheen(bar)
    end

    function Style.MakeSheen(bar)
        local fill = bar:GetStatusBarTexture()

        local sheen = bar:CreateTexture(nil, "ARTWORK", nil, 1)
        sheen:SetTexture(Style.FLAT_TEXTURE)
        sheen:SetPoint("TOPLEFT", fill, "TOPLEFT")
        sheen:SetPoint("BOTTOMRIGHT", fill, "RIGHT")

        local shade = bar:CreateTexture(nil, "ARTWORK", nil, 1)
        shade:SetTexture(Style.FLAT_TEXTURE)
        shade:SetPoint("TOPLEFT", fill, "LEFT")
        shade:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")

        -- Bottom colour first, then top.
        if sheen.SetGradient and CreateColor then
            sheen:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, SHEEN))
            shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, SHADE), CreateColor(0, 0, 0, 0))
        else
            sheen:SetVertexColor(1, 1, 1, SHEEN / 2)
            shade:SetVertexColor(0, 0, 0, SHADE / 2)
        end
        return sheen, shade
    end

    -- The part of a bar that is not filled. While the bar is being placed it is
    -- plain black instead, so the outline and the label are all there is to
    -- read.
    local PLACING_BACKGROUND = { 0, 0, 0, 1 }

    function Style.SetBackground(texture, unlocked)
        local colour = unlocked and PLACING_BACKGROUND or Style.BACKGROUND_COLOR
        texture:SetColorTexture(colour[1], colour[2], colour[3], colour[4])
        texture:SetVertexColor(1, 1, 1)
        texture:SetAlpha(1)
        return texture
    end

    -- THE PIXEL GRID. A border is laid out in units - each line one unit wide,
    -- the corners four units in radius - and a unit is about one UI unit,
    -- which on a sharp screen is more than one real pixel: at 2560x1440 and a
    -- UI scale of 1.2, two. So a border is drawn on the real pixels: each unit
    -- is K whole pixels, and the curves are worked out pixel by pixel at that
    -- resolution. An earlier version drew each unit as a single step, which
    -- the screen showed as 2x2 blocks: the corners came out stepped.
    --
    -- Returns the size of one real pixel in `region`'s UI units, and K.
    local function Grid(region)
        if PixelUtil and PixelUtil.GetPixelToUIUnitFactor and region.GetEffectiveScale then
            local scale = region:GetEffectiveScale()
            if type(scale) == "number" and scale > 0 then
                local px = PixelUtil.GetPixelToUIUnitFactor() / scale
                return px, math.max(1, math.floor(1 / px + 0.5))
            end
        end
        return 1, 1
    end

    -- THE ROUNDED CORNERS. WoW cannot round a texture, and a curve drawn from a
    -- file would blur against a one-pixel line, so each corner is drawn pixel
    -- by pixel - anti-aliased, the way a font draws a curve: every pixel of the
    -- corner gets, as its opacity, the share of it a true curve would cover.
    --
    -- A border is one or more LINES, each a unit wide, the first outermost,
    -- then an optional GAP filled with the bar's own background, then the bar.
    -- Counted in real pixels from the border's outer corner (x along the edge,
    -- y into the box), with W the pixels in a line and R the radius, in each
    -- corner:
    --
    --   * line i's curve is a quarter ring W pixels wide, between radius
    --     R - i*W and R - (i-1)*W, centred R pixels in, so every line meets its
    --     straight stretch exactly where that stops;
    --   * the gap curves with the innermost ring's inner edge.
    --
    -- The bar's square corner, lines + gap in, must lie wholly inside the
    -- outer curve, or it pokes out past it: at a radius of 4 units that takes
    -- two units of border (one line and a gap, or two lines).
    --
    -- Worked out once per shape by sampling each pixel on a fine grid. Pixels
    -- with less than FAINTEST are left out. The default - gold, bevel and
    -- black, no gap, radius 4 (the player tried 3, then 6, and settled here) -
    -- at one pixel a unit:
    --
    --     gold                  bevel                 black
    --     .    0.16 0.70 0.96   .    .    .    .      .    .    .    .
    --     0.16 0.92 0.43 0.05   .    .    0.57 0.95   .    .    .    .
    --     0.70 0.43 .    .      .    0.57 0.68 0.08   .    .    0.32 0.92
    --     0.96 0.05 .    .      .    0.95 0.08 .      .    .    0.92 0.21
    --
    -- The bar starts three units in, under the black line's curve.
    Style.DEFAULT_BORDER = {
        radius = 4, gap = 0,
        lines = { Style.BORDER_COLOR, Style.BEVEL_COLOR, Style.DIVIDER_COLOR },
    }

    -- All in real pixels: `radius`, `width` (one line) and `gap`.
    local shapes = {}
    local function Shape(radius, lines, width, gap)
        local key = radius .. ":" .. lines .. ":" .. width .. ":" .. gap
        if shapes[key] then return shapes[key] end
        local SAMPLES, FAINTEST = 16, 0.04
        local inside = lines * width + gap      -- where the bar starts
        local shape = { rings = {}, fill = {} }
        for ring = 1, lines do shape.rings[ring] = {} end
        for y = 0, radius - 1 do
            for x = 0, radius - 1 do
                local hits, fill = {}, 0
                for ring = 1, lines do hits[ring] = 0 end
                for sy = 0, SAMPLES - 1 do
                    for sx = 0, SAMPLES - 1 do
                        local dx = x + (sx + 0.5) / SAMPLES - radius
                        local dy = y + (sy + 0.5) / SAMPLES - radius
                        local d = math.sqrt(dx * dx + dy * dy)
                        local ring = math.floor((radius - d) / width) + 1
                        if d <= radius and ring >= 1 and ring <= lines then
                            hits[ring] = hits[ring] + 1
                        elseif d < radius - lines * width then
                            fill = fill + 1
                        end
                    end
                end
                for ring = 1, lines do
                    local share = hits[ring] / SAMPLES ^ 2
                    if share >= FAINTEST then
                        local list = shape.rings[ring]
                        list[#list + 1] = { x, y, share }
                    end
                end
                fill = fill / SAMPLES ^ 2
                if gap > 0 and (x < inside or y < inside) and fill >= FAINTEST then
                    shape.fill[#shape.fill + 1] = { x, y, fill }
                end
            end
        end
        shapes[key] = shape
        return shape
    end

    -- Each corner, and which way "in" is from it.
    local CORNERS = {
        { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 },
        { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 },
    }

    -- Every border made, so a change of UI scale can re-snap them all.
    local borders = setmetatable({}, { __mode = "k" })

    local function Span(texture, border, a, ax, ay, b, bx, by)
        texture:ClearAllPoints()
        texture:SetPoint(a, border, a, ax, ay)
        texture:SetPoint(b, border, b, bx, by)
    end

    -- A bevelled band's colour at one corner pixel. The top and left sides
    -- are lit, the bottom and right shaded (light from the top left): the top
    -- left corner is all light, the bottom right all shade, and the other two
    -- turn from one to the other round the curve - a pixel's share of each is
    -- how far along the top (or left) edge it lies against how far down the
    -- right (or bottom) one. `x`, `y`: the pixel's place from the corner.
    local function BevelColour(bevel, point, x, y)
        local lit
        if point == "TOPLEFT" then
            lit = 1
        elseif point == "BOTTOMRIGHT" then
            lit = 0
        elseif point == "TOPRIGHT" then
            lit = (x + 0.5) / (x + y + 1)       -- far along the top: lit
        else -- BOTTOMLEFT
            lit = (y + 0.5) / (x + y + 1)       -- far up the left: lit
        end
        local l, s = bevel.light, bevel.shade
        return l[1] * lit + s[1] * (1 - lit), l[2] * lit + s[2] * (1 - lit),
            l[3] * lit + s[3] * (1 - lit)
    end

    -- The corner pixels of one band, made as they are needed - how many there
    -- are depends on the screen - each at its share of the band's colour.
    -- Pixels a finer grid no longer needs are hidden.
    local function Dots(band, pixels, border, px)
        local colour = band.colour
        local alpha = colour[4] or 1
        local index = 0
        for _, corner in ipairs(CORNERS) do
            local point, inX, inY = corner[1], corner[2], corner[3]
            for _, pixel in ipairs(pixels) do
                index = index + 1
                local dot = band.steps[index]
                if not dot then
                    dot = band.make()
                    band.steps[index] = dot
                end
                dot:ClearAllPoints()
                dot:SetPoint(point, border, point, inX * pixel[1] * px, inY * pixel[2] * px)
                dot:SetSize(px, px)
                local r, g, b = colour[1], colour[2], colour[3]
                if band.bevel then r, g, b = BevelColour(band.bevel, point, pixel[1], pixel[2]) end
                dot:SetVertexColor(r, g, b, alpha * pixel[3])
                dot:Show()
            end
        end
        for spare = index + 1, #band.steps do band.steps[spare]:Hide() end
    end

    -- One straight band, `at` pixels in from the border's edge and `thick`
    -- pixels thick, on all four sides, stopping `cut` short of each corner.
    local function Band(band, border, at, thick, cut)
        Span(band.top, border, "TOPLEFT", cut, -at, "TOPRIGHT", -cut, -at)
        Span(band.bottom, border, "BOTTOMLEFT", cut, at, "BOTTOMRIGHT", -cut, at)
        Span(band.left, border, "TOPLEFT", at, -cut, "BOTTOMLEFT", at, cut)
        Span(band.right, border, "TOPRIGHT", -at, -cut, "BOTTOMRIGHT", -at, cut)
        band.top:SetHeight(thick)
        band.bottom:SetHeight(thick)
        band.left:SetWidth(thick)
        band.right:SetWidth(thick)
    end

    -- Lay a border out on the real pixels of where it is now.
    local function Fit(border)
        local spec = border.spec
        local px, k = Grid(border)
        k = border.unitPixels or k
        local width, radius, gap = k, spec.radius * k, spec.gap * k
        local lines = #spec.lines
        local shape = Shape(radius, lines, width, gap)
        local cut = radius * px
        local out = (lines * width + gap) * px
        local bar = border:GetParent()
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", bar, "TOPLEFT", -out, out)
        border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", out, -out)

        for index, line in ipairs(border.lines) do
            Band(line, border, (index - 1) * width * px, width * px, cut)
            Dots(line, shape.rings[index], border, px)
        end
        if border.gap then
            Band(border.gap, border, lines * width * px, gap * px, cut)
            Dots(border.gap, shape.fill, border, px)
        end
    end

    local function Pixel(parent, layer, sublevel, colour)
        local texture = parent:CreateTexture(nil, layer, nil, sublevel)
        texture:SetTexture(Style.FLAT_TEXTURE)
        texture:SetVertexColor(colour[1], colour[2], colour[3], colour[4] or 1)
        return texture
    end

    -- A band's four straight pieces, its corner pixels (made by Dots), and
    -- how to make one more of them.
    local function Band4(make, colour)
        return { top = make(), bottom = make(), left = make(), right = make(),
                 steps = {}, make = make, colour = colour }
    end

    -- The border a bar wears: its lines with rounded corners, on a frame just
    -- outside the bar, above everything the bar holds; and the gap inside
    -- them, in the background's colour, drawn on the bar itself under
    -- everything it holds. `spec` is DEFAULT_BORDER unless another is given:
    -- { radius =, lines = { colour, ... } outermost first, gap = pixels }.
    -- The outermost line is also border.top/bottom/left/right and .steps.
    --
    -- `ownScale`: the border does not take its bar's scale. For a bar the game
    -- scales on its own - a nameplate grows and shrinks with distance - the
    -- one-pixel lines would land between pixels and draw blurred and two wide;
    -- the game's own nameplate borders ignore their parent's scale for the same
    -- reason (NamePlateFullBorderTemplate). The anchors still follow the bar.
    --
    -- `unitPixels`: how many real pixels a unit is, instead of about one UI
    -- unit's worth. A nameplate is small, and the frames' border - two pixels a
    -- line on a sharp screen - is heavy on it; at 1 it is the same three lines,
    -- one pixel each.
    --
    -- `spec.bevel = { light =, shade = }`, optional: the outermost line drawn
    -- as a bevel, a slight 3D edge at no extra thickness - its colour times
    -- `light` on the top and left, times `shade` on the bottom and right, the
    -- corners turning between the two (BevelColour).
    function Style.AddBorder(bar, spec, ownScale, unitPixels)
        spec = spec or Style.DEFAULT_BORDER
        local border = CreateFrame("Frame", nil, bar)
        if ownScale and type(border.SetIgnoreParentScale) == "function" then
            border:SetIgnoreParentScale(true)
        end
        border:SetFrameLevel(bar:GetFrameLevel() + 5)
        border.spec = spec
        border.unitPixels = unitPixels

        border.lines = {}
        for index, colour in ipairs(spec.lines) do
            border.lines[index] = Band4(function()
                return Pixel(border, "OVERLAY", 0, colour)
            end, colour)
        end
        local outer = border.lines[1]

        if spec.bevel then
            local base, a = outer.colour, outer.colour[4] or 1
            local function Times(k)
                return { math.min(1, base[1] * k), math.min(1, base[2] * k), math.min(1, base[3] * k) }
            end
            outer.bevel = { light = Times(spec.bevel.light), shade = Times(spec.bevel.shade) }
            local light, shade = outer.bevel.light, outer.bevel.shade
            for _, side in ipairs({ "top", "left" }) do
                outer[side]:SetVertexColor(light[1], light[2], light[3], a)
            end
            for _, side in ipairs({ "bottom", "right" }) do
                outer[side]:SetVertexColor(shade[1], shade[2], shade[3], a)
            end
        end
        border.top, border.bottom, border.left, border.right = outer.top, outer.bottom, outer.left, outer.right
        border.steps = outer.steps

        if spec.gap > 0 then
            local fill = Style.BACKGROUND_COLOR
            border.gap = Band4(function()
                return Pixel(bar, "BACKGROUND", -8, fill)
            end, fill)
        end
        Fit(border)
        borders[border] = true
        return border
    end

    -- Lay a border out again on the real pixels, for a bar whose scale the
    -- addon has just changed itself: the rescale below only follows the UI's
    -- own scale, and may run before the addon has caught up with it.
    function Style.Refit(border) pcall(Fit, border) end

    local rescale = CreateFrame("Frame")
    rescale:RegisterEvent("UI_SCALE_CHANGED")
    rescale:RegisterEvent("DISPLAY_SIZE_CHANGED")
    rescale:SetScript("OnEvent", function()
        -- Guarded one by one: a border on a frame the game has since closed to
        -- addon code (an aura button while auras are secret) must not stop
        -- the rest.
        for border in pairs(borders) do pcall(Fit, border) end
    end)

    ---------------------------------------------------------------------------
    -- FADING. A bar that comes and goes - the castbars - fades in and out
    -- rather than appearing and vanishing. FadeIn shows a hidden frame from
    -- nothing and brings it up; FadeOut takes it down and hides it at the end.
    -- Either can be called every frame: it carries on from wherever the alpha
    -- is, so a cast that starts while the last one is fading out simply fades
    -- back in. ShowNow is for a bar that must be there at once (being placed).
    -- One driver runs every fade, and only while something is fading. Alpha is
    -- not a protected call, so this works in combat.
    ---------------------------------------------------------------------------
    Style.FADE_IN, Style.FADE_OUT = 0.15, 0.3      -- seconds, full to nothing

    local fading = {}           -- frame -> the alpha it is heading for
    local fader = CreateFrame("Frame")
    fader:Hide()
    fader:SetScript("OnUpdate", function(_, elapsed)
        for frame, target in pairs(fading) do
            local alpha = frame:GetAlpha()
            if target == 1 then
                alpha = math.min(1, alpha + elapsed / Style.FADE_IN)
            else
                alpha = math.max(0, alpha - elapsed / Style.FADE_OUT)
            end
            frame:SetAlpha(alpha)
            if alpha == target then
                fading[frame] = nil
                if target == 0 then frame:Hide() end
            end
        end
        if next(fading) == nil then fader:Hide() end
    end)

    function Style.FadeIn(frame)
        if not frame:IsShown() then
            frame:SetAlpha(0)
            frame:Show()
        end
        if frame:GetAlpha() < 1 then
            fading[frame] = 1
            fader:Show()
        else
            fading[frame] = nil
        end
    end

    function Style.FadeOut(frame)
        if not frame:IsShown() then
            fading[frame] = nil
            return
        end
        fading[frame] = 0
        fader:Show()
    end

    function Style.ShowNow(frame)
        fading[frame] = nil
        frame:SetAlpha(1)
        frame:Show()
    end

    function Style.HideNow(frame)
        fading[frame] = nil
        frame:Hide()
    end

    -- The spark at a bar's leading edge: the castbar's, on every bar. It is
    -- drawn under the bar's text, and as tall as the castbar draws it.
    Style.SPARK_HEIGHT = 2.2   -- times the bar's height

    function Style.AddSpark(bar)
        local spark = bar:CreateTexture(nil, "OVERLAY", nil, -1)
        spark:SetTexture(Style.SPARK)
        spark:SetWidth(16)
        spark:SetVertexColor(1, 1, 1)
        spark:SetBlendMode("ADD")
        return spark
    end

    -- A spark pinned to the end of a bar's fill, so it follows the fill
    -- wherever the value puts it - with nothing read or worked out, which is
    -- what a secret value needs. The fill texture has to be set first.
    function Style.PinSpark(spark, bar)
        spark:ClearAllPoints()
        spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
        spark:SetHeight((bar:GetHeight() or 0) * Style.SPARK_HEIGHT)
    end

    -- Every bar has its spark on the leading edge, and every bar that counts
    -- down shows the seconds left. They used to be two settings (Show spark,
    -- Show time left); the player took them out - they are the look, not a
    -- choice.

    -- Whether a spark shows, for a bar whose value is plain: only strictly
    -- between empty and full, where there is an edge to mark. At either end a
    -- spark would only glow against the bar's own end.
    function Style.SparkAlpha(value, max)
        if type(value) ~= "number" or type(max) ~= "number" or max <= 0 then return 0 end
        return (value > 0 and value < max) and 1 or 0
    end

    -- The same, for health and power, which are secret on this client. The
    -- game evaluates the curve: it maps the unit's fraction to the spark's
    -- alpha - nothing at empty or full, all of it in between - and the result
    -- goes straight to SetAlpha, which takes a secret. The addon never sees
    -- the fraction.
    local sparkCurve
    if type(C_CurveUtil) == "table" and type(C_CurveUtil.CreateCurve) == "function" then
        sparkCurve = C_CurveUtil.CreateCurve()
        if Enum.LuaCurveType then sparkCurve:SetType(Enum.LuaCurveType.Linear) end
        sparkCurve:AddPoint(0, 0)
        sparkCurve:AddPoint(0.001, 1)
        sparkCurve:AddPoint(0.999, 1)
        sparkCurve:AddPoint(1, 0)
    end

    local function Evaluated(query, ...)
        if not sparkCurve or type(query) ~= "function" then return 0 end
        local ok, alpha = pcall(query, ...)
        return ok and alpha or 0
    end

    function Style.HealthSparkAlpha(unit)
        return Evaluated(UnitHealthPercent, unit, false, sparkCurve)
    end

    function Style.PowerSparkAlpha(unit)
        return Evaluated(UnitPowerPercent, unit, nil, false, sparkCurve)
    end

    -- The two placement labels, for a bar with no text of its own to wear
    -- them in (combo points, the XP bar): the name on the left, giving way to
    -- the word on the right. On a frame of their own above the bar, so a fill
    -- or a segment drawn over the bar cannot cover them.
    local PLACEMENT_TEXT_MIN = 8   -- a thin bar still says what it is

    function Style.AddPlacementLabels(bar)
        local holder = CreateFrame("Frame", nil, bar)
        holder:SetAllPoints(bar)
        holder:SetFrameLevel(bar:GetFrameLevel() + 5)

        local labels = {
            holder = holder,
            name = holder:CreateFontString(nil, "OVERLAY"),
            state = holder:CreateFontString(nil, "OVERLAY"),
        }
        Style.SingleLine(labels.name)
        Style.SingleLine(labels.state)
        labels.state:SetJustifyH("RIGHT")
        labels.state:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        labels.name:SetJustifyH("LEFT")
        labels.name:SetPoint("LEFT", bar, "LEFT", 4, 0)
        labels.name:SetPoint("RIGHT", labels.state, "LEFT", -6, 0)
        return labels
    end

    -- Shown while the bar is being placed, empty the rest of the time.
    function Style.ShowPlacementLabels(labels, bar, name, unlocked, padding)
        Style.SetFont(bar, labels.name, padding, PLACEMENT_TEXT_MIN)
        Style.SetFont(bar, labels.state, padding, PLACEMENT_TEXT_MIN)
        labels.name:SetText(unlocked and name or "")
        labels.state:SetText(unlocked and Style.PLACEMENT_LABEL or "")
    end

    -- One line, always: a long label in a narrow bar is cut short with an
    -- ellipsis rather than wrapped out of the bar.
    function Style.SingleLine(label)
        label:SetShadowOffset(1, -1)
        label:SetWordWrap(false)
        if type(label.SetNonSpaceWrap) == "function" then label:SetNonSpaceWrap(false) end
        if type(label.SetMaxLines) == "function" then label:SetMaxLines(1) end
    end

    ---------------------------------------------------------------------------
    -- Text size.
    --
    -- How much of a bar's height is left clear above and below its text, as a
    -- fraction of that height: 0.15 leaves 15% at the top and 15% at the
    -- bottom. Each module has its own `textPadding` setting.
    ---------------------------------------------------------------------------

    local DEFAULT_TEXT_PADDING = 0.15
    Style.MAX_TEXT_PADDING = 0.4

    -- A bar shorter than this has no room for text at any size. Measured against
    -- the bar rather than the font, so raising the padding thins the text
    -- instead of making it vanish.
    local MIN_BAR_HEIGHT = 8

    -- The largest the text on any bar gets. Text follows the bar's height up
    -- to here and no further: a 16-high health bar gets 10, a 20-high one 11,
    -- and a taller bar only gains room round its text. Without the cap a
    -- 20-high bar's text came out 14 and looked too large; 12 was still a
    -- touch large.
    Style.MAX_FONT_SIZE = 11

    local function Padding(padding)
        if type(padding) ~= "number" then return DEFAULT_TEXT_PADDING end
        if padding < 0 then return 0 end
        return math.min(padding, Style.MAX_TEXT_PADDING)
    end

    -- Size a bar's label to the bar, leaving the padding clear, in the text
    -- colour (or `colour`) - or transparent when the bar is too short for text
    -- at all. `minimum` is a floor under the size, for bars that are thin by
    -- design.
    function Style.SetFont(bar, label, padding, minimum, colour)
        local height = bar:GetHeight() or 0
        local px = math.floor(height * (1 - 2 * Padding(padding)))
        px = px - px % 2                       -- even sizes sit evenly in the bar
        px = math.max(1, math.min(px, Style.MAX_FONT_SIZE))
        if minimum and px < minimum then px = minimum end

        if height < MIN_BAR_HEIGHT and not minimum then
            label:SetTextColor(0, 0, 0, 0)
        else
            colour = colour or Style.TEXT_COLOR
            label:SetTextColor(colour[1], colour[2], colour[3])
        end
        label:SetFont(Style.FONT, px, "OUTLINE")
    end

    -- A label in the bold cut, at a fixed size. The game only finds a font
    -- file that was in the folder when it started, so one just added may not
    -- load until a restart: then the regular cut, rather than no text at all.
    function Style.SetBoldFont(label, px)
        if not label:SetFont(Style.BOLD_FONT, px, "OUTLINE") then
            label:SetFont(Style.FONT, px, "OUTLINE")
        end
    end
end
