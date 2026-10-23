-- Style: the one look every bar is drawn with (DogsForeverUI.Style).
-- The palette, a flat fill with sheen and shade, rounded pixel-exact borders,
-- fades, sparks, label fonts - and the game's text in the addon's font (DogsForeverUI.Fonts).

local Style = {}
DogsForeverUI.Style = Style
local Fonts = {}
DogsForeverUI.Fonts = Fonts

do -- private scope

    -- A flat colour stretches any way cleanly; the game's bar art broke up stretched.
    Style.FLAT_TEXTURE = "Interface\\Buttons\\WHITE8X8"
    Style.SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
    Style.FONT = DogsForeverUI.MEDIA .. "Dog.ttf"
    Style.BOLD_FONT = DogsForeverUI.MEDIA .. "Dog-Bold.ttf"

    -- Behind every bar (a colour, not a file: a missing file draws solid green).
    Style.BACKGROUND_COLOR = { 0.05, 0.05, 0.05, 0.5 }
    -- The addon's windows: the options, the placing dialog.
    Style.WINDOW_BACKGROUND = { 0.05, 0.05, 0.05, 0.96 }

    Style.TEXT_COLOR = { 1, 1, 1 }
    Style.GOLD = { 0xff / 255, 0xbb / 255, 0x20 / 255 }      -- the game's heading gold

    -- The game's small gold toggle arrow (the buff frame's and bag bar's), pointing
    -- left, at their size; under the mouse a copy added over it at the game's strength.
    Style.ARROW = { atlas = "bag-arrow", width = 10, height = 16, highlight = 0.4 }

    -- The border's three lines, outside in: the tooltip's gold, a darker
    -- bevel, black (also the hairline between two bars).
    Style.BORDER_COLOR = { 178 / 255, 142 / 255, 97 / 255, 1 }
    Style.BEVEL_COLOR = { 110 / 255, 88 / 255, 60 / 255, 1 }
    Style.DIVIDER_COLOR = { 0, 0, 0, 1 }

    -- How far the border reaches outside its bar.
    Style.BORDER_INSET = 3

    ---------------------------------------------------------------------------
    -- Palette: health at the brightness of #43582f, resources at #19366e,
    -- each lifted by LIGHTER and saturated by VIVID (a grey stays grey).
    ---------------------------------------------------------------------------

    local LIGHTER = 2.5
    local VIVID = 2.0
    local function hex(value) return value / 255 * LIGHTER end

    -- Saturation without a change of hue; no channel past 1.
    local function Push(r, g, b, amount)
        local brightest = math.max(r, g, b)
        local function one(c)
            return math.min(1, math.max(0, brightest - (brightest - c) * amount))
        end
        return one(r), one(g), one(b)
    end

    Style.HEALTH_COLOR = { Push(hex(0x43), hex(0x58), hex(0x2f), VIVID) }
    Style.HEALTH_TONE = hex(0x58)
    local POWER_TONE = math.min(1, hex(0x6e))
    local MIN_SHARE = 0x19 / 0x6e

    -- Mana: #18376e as seen on screen through a texture averaging
    -- TEXTURE_SHADE, lifted with the palette; past full blue a fixed push.
    local TEXTURE_SHADE = 0.62
    local MANA_LIFT = LIGHTER / 1.7
    local MANA_PUSH = 1.15
    Style.MANA_COLOR = { Push(
        0x18 / 255 / TEXTURE_SHADE * MANA_LIFT,
        0x37 / 255 / TEXTURE_SHADE * MANA_LIFT,
        0x6e / 255 / TEXTURE_SHADE * MANA_LIFT,
        MANA_PUSH) }

    -- At full tone a harder push only darkens: those keep a softer one.
    local FULL_VIVID = 1.6

    -- A game colour at `tone`: its hue kept, its brightest channel at the
    -- tone, no channel below the mana colour's darkest share.
    function Style.Tone(r, g, b, tone)
        local floor = tone * MIN_SHARE
        local brightest = math.max(r, g, b)
        if brightest <= 0 then return floor, floor, floor end

        local scale = tone / brightest
        return Push(math.max(floor, r * scale), math.max(floor, g * scale),
            math.max(floor, b * scale), tone >= 1 and FULL_VIVID or VIVID)
    end

    -- A game colour object as a table, or the given values where it is missing.
    local function GameColour(colour, r, g, b)
        if type(colour) == "table" and colour.GetRGB then return { colour:GetRGB() } end
        return { r, g, b }
    end

    -- A resource's colour (UnitPowerType's two answers): mana ours, any other exactly the
    -- game's PowerBarColor - plain fields or a colour object, by token or by number.
    local MANA = Enum.PowerType.Mana
    local function PowerBarRGB(info)
        if type(info) ~= "table" then return end
        if type(info.r) == "number" then return info.r, info.g, info.b end
        if info.GetRGB then return info:GetRGB() end
    end
    function Style.PowerColour(powerType, token)
        if issecretvalue(powerType) or issecretvalue(token) or token == "MANA"
           or (token == nil and powerType == MANA) then
            return unpack(Style.MANA_COLOR)
        end
        local r, g, b = PowerBarRGB(PowerBarColor[token])
        if not r then r, g, b = PowerBarRGB(PowerBarColor[powerType]) end
        if r then return r, g, b end
        return unpack(Style.MANA_COLOR)
    end

    -- Cast states: the game's classic castbar colours, but the cast in the
    -- heading gold and the channel in a softer green (#04b237).
    Style.CAST_COLOR = {
        casting         = { Style.GOLD[1], Style.GOLD[2], Style.GOLD[3] },
        channel         = { 0x04 / 255, 0xb2 / 255, 0x37 / 255 },
        uninterruptible = GameColour(CASTBAR_CLASSIC_GRAY, 0.7, 0.7, 0.7),
        failed          = GameColour(CASTBAR_CLASSIC_RED, 1.0, 0.0, 0.0),
    }
    Style.COOLDOWN_COLOR = Style.CAST_COLOR.casting
    Style.DURATION_COLOR = Style.CAST_COLOR.channel

    local SWING_GREY = { 0.6, 0.6, 0.6 }
    Style.SWING_COLOR = { mainhand = SWING_GREY, offhand = SWING_GREY, ranged = SWING_GREY }

    Style.COUNTDOWN_COLOR = Style.MANA_COLOR
    Style.XP_COLOR = { 0.58, 0.0, 0.55 }                  -- the classic XP purple, untoned
    Style.COMBO_COLOR = { Style.Tone(1.0, 0.15, 0.1, POWER_TONE) }
    Style.RESTED_COLOR = { 0.0, 0.39, 0.88 }              -- the classic rested blue
    Style.HONOR_COLOR = { 0.94, 0.33, 0.0 }               -- the game's honor fill

    -- A missing atlas draws nothing: ask first.
    function Style:HasAtlas(name)
        return type(name) == "string" and C_Texture.GetAtlasInfo(name) ~= nil
    end

    ---------------------------------------------------------------------------
    -- Bars
    ---------------------------------------------------------------------------

    -- The flat fill, stretched rather than tiled; the colour is the bar's tint.
    function Style.SetBarFill(bar)
        bar:SetStatusBarTexture(Style.FLAT_TEXTURE)
        local fill = bar:GetStatusBarTexture()
        fill:SetHorizTile(false)
        fill:SetVertTile(false)
        return fill
    end

    function Style.Paint(bar, colour)
        Style.SetBarFill(bar)
        Style.AddSheen(bar)
        bar:SetStatusBarColor(colour[1], colour[2], colour[3], 1)
    end

    -- A sheen over the top half and a shade over the bottom, pinned to the
    -- fill so the value is never read (a secret is fine). AddSheen keeps them
    -- on the addon's own bar; MakeSheen writes nothing on it (game nameplates).
    local SHEEN, SHADE = 0.22, 0.25

    function Style.AddSheen(bar)
        if bar.sheen then return end
        bar.sheen, bar.shade = Style.MakeSheen(bar)
    end

    function Style.MakeSheen(bar)
        return Style.SheenOver(bar, bar:GetStatusBarTexture(), 1, bar:GetOrientation() == "VERTICAL")
    end

    -- The sheen and shade on `owner`, pinned to `region`, at ARTWORK
    -- `sublevel`; a `vertical` bar has them left and right.
    function Style.SheenOver(owner, region, sublevel, vertical)
        local sheen = owner:CreateTexture(nil, "ARTWORK", nil, sublevel)
        sheen:SetTexture(Style.FLAT_TEXTURE)
        local shade = owner:CreateTexture(nil, "ARTWORK", nil, sublevel)
        shade:SetTexture(Style.FLAT_TEXTURE)
        Style.TurnSheen(sheen, shade, region, vertical)
        return sheen, shade
    end

    -- A sheen and shade laid out again, for a bar turned the other way.
    function Style.TurnSheen(sheen, shade, region, vertical)
        sheen:ClearAllPoints()
        sheen:SetPoint("TOPLEFT", region, "TOPLEFT")
        sheen:SetPoint("BOTTOMRIGHT", region, vertical and "BOTTOM" or "RIGHT")
        shade:ClearAllPoints()
        shade:SetPoint("TOPLEFT", region, vertical and "TOP" or "LEFT")
        shade:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT")

        if vertical then
            -- Left colour first, then right.
            sheen:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, SHEEN), CreateColor(1, 1, 1, 0))
            shade:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, SHADE))
        else
            -- Bottom colour first, then top.
            sheen:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, SHEEN))
            shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, SHADE), CreateColor(0, 0, 0, 0))
        end
    end

    -- Whether the pieces are being placed (Unlock Mode).
    function Style.Previewing()
        return DogsForeverUI.IsUnlocked()
    end

    -- The part of a bar that is not filled.
    function Style.SetBackground(texture)
        local colour = Style.BACKGROUND_COLOR
        texture:SetColorTexture(colour[1], colour[2], colour[3], colour[4])
        texture:SetVertexColor(1, 1, 1)
        texture:SetAlpha(1)
        return texture
    end

    ---------------------------------------------------------------------------
    -- Borders, drawn on real pixels: each unit is K whole pixels, the rounded
    -- corners anti-aliased pixel by pixel (each pixel at the share of it a
    -- true curve covers).
    ---------------------------------------------------------------------------

    -- One real pixel in `region`'s UI units (1 where the client says nothing).
    function Style.PixelSize(region)
        local scale = region:GetEffectiveScale()
        if PixelUtil and type(scale) == "number" and scale > 0 then
            return PixelUtil.GetPixelToUIUnitFactor() / scale
        end
        return 1
    end

    -- One real pixel in `region`'s units, and K: the whole pixels in a unit.
    local function Grid(region)
        local px = Style.PixelSize(region)
        return px, math.max(1, math.floor(1 / px + 0.5))
    end

    -- Radius 4 units, three lines (gold, bevel, black), no gap.
    Style.DEFAULT_BORDER = {
        radius = 4, gap = 0,
        lines = { Style.BORDER_COLOR, Style.BEVEL_COLOR, Style.DIVIDER_COLOR },
    }

    -- A corner's pixels per line (ring) and gap fill, in real pixels: each
    -- { x, y, share } from the outer corner. Worked out once per shape.
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

    -- Every border made, re-snapped on a change of UI scale.
    local borders = setmetatable({}, { __mode = "k" })

    local function Span(texture, border, a, ax, ay, b, bx, by)
        texture:ClearAllPoints()
        texture:SetPoint(a, border, a, ax, ay)
        texture:SetPoint(b, border, b, bx, by)
    end

    -- A bevelled band's colour at one corner pixel: lit from the top left,
    -- the top-right and bottom-left corners turning from light to shade.
    local function BevelColour(bevel, point, x, y)
        local lit
        if point == "TOPLEFT" then
            lit = 1
        elseif point == "BOTTOMRIGHT" then
            lit = 0
        elseif point == "TOPRIGHT" then
            lit = (x + 0.5) / (x + y + 1)
        else -- BOTTOMLEFT
            lit = (y + 0.5) / (x + y + 1)
        end
        local l, s = bevel.light, bevel.shade
        return l[1] * lit + s[1] * (1 - lit), l[2] * lit + s[2] * (1 - lit),
            l[3] * lit + s[3] * (1 - lit)
    end

    -- A band's corner pixels, made as needed; spares hidden.
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

    -- One straight band `at` in from the edge, `thick`, stopping `cut` short of each corner.
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
        border.out = out
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

    -- A band's four straight pieces, its corner pixels, and how to make one more.
    local function Band4(make, colour)
        return { top = make(), bottom = make(), left = make(), right = make(),
                 steps = {}, make = make, colour = colour }
    end

    -- The border a bar wears, on a frame just outside it; the gap (if any)
    -- drawn on the bar under everything it holds. The outermost line is also
    -- border.top/bottom/left/right and .steps.
    --   spec       DEFAULT_BORDER or { radius =, lines = { colour, ... }, gap =,
    --              bevel = { light =, shade = } (the outer line lit/shaded) }
    --   ownScale   ignore the bar's scale (a nameplate's: lines would blur)
    --   unitPixels real pixels per unit instead of about one UI unit's worth
    function Style.AddBorder(bar, spec, ownScale, unitPixels)
        spec = spec or Style.DEFAULT_BORDER
        local border = CreateFrame("Frame", nil, bar)
        if ownScale then border:SetIgnoreParentScale(true) end
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
            local light, shade = Times(spec.bevel.light), Times(spec.bevel.shade)
            outer.bevel = { light = light, shade = shade }
            for side, colour in pairs({ top = light, left = light, bottom = shade, right = shade }) do
                outer[side]:SetVertexColor(colour[1], colour[2], colour[3], a)
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

    -- Laid out again, for a bar the addon has just rescaled itself.
    function Style.Refit(border) pcall(Fit, border) end

    -- One whole real pixel in `frame`'s units (PixelUtil.GetNearestPixelSize(1, scale, 1)).
    function Style.OnePixel(frame)
        local px, k = Grid(frame)
        return px * k
    end

    -- A border's outer edges put on whole screen pixels where its bar is now,
    -- or a one-pixel line between two pixels can round away. It measures the
    -- bar: the addon's own frames only (never a nameplate), again after a move.
    function Style.SnapBorder(border)
        local bar, out = border:GetParent(), border.out
        if not (bar and out) then return end
        local px = Grid(bar)
        local left, right, top, bottom = bar:GetLeft(), bar:GetRight(), bar:GetTop(), bar:GetBottom()
        if not (left and right and top and bottom) or px <= 0 then return end
        local function Nudge(v) return (math.floor(v / px + 0.5) - v / px) * px end
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", bar, "TOPLEFT", -out + Nudge(left), out + Nudge(top))
        border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", out + Nudge(right), -out + Nudge(bottom))
    end

    local rescale = CreateFrame("Frame")
    rescale:RegisterEvent("UI_SCALE_CHANGED")
    rescale:RegisterEvent("DISPLAY_SIZE_CHANGED")
    rescale:SetScript("OnEvent", function()
        -- One by one: a frame the game has since closed to addons must not stop the rest.
        for border in pairs(borders) do pcall(Fit, border) end
    end)

    ---------------------------------------------------------------------------
    -- Fading: FadeIn/FadeOut carry on from the current alpha, so either may be
    -- called every frame. One driver, only while something fades; alpha is
    -- not protected, so this works in combat.
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

    -- A shield exactly as the game's raid frames draw it (CompactUnitFrame.lua): its fill, its
    -- stripes over it, each the game's atlas, repeated both ways at its own size - never
    -- stretched. Unit frames and nameplates alike.
    Style.SHIELD_FILL = "raidframe-shield-fill"
    Style.SHIELD_LINES = "RaidFrame-Shield-Overlay"
    function Style.ShieldArt(region, atlas)
        local wrap = TextureKitConstants.AddressModeWrap
        SetTextureWithAddressModeOptions(region, atlas, TextureKitConstants.IgnoreAtlasSize, wrap, wrap)
    end

    ---------------------------------------------------------------------------
    -- Sparks: the castbar's, on every bar's leading edge, under its text.
    ---------------------------------------------------------------------------
    Style.SPARK_HEIGHT = 2.2   -- times the bar's height

    function Style.AddSpark(bar)
        local spark = bar:CreateTexture(nil, "OVERLAY", nil, -1)
        spark:SetTexture(Style.SPARK)
        spark:SetWidth(16)
        spark:SetVertexColor(1, 1, 1)
        spark:SetBlendMode("ADD")
        return spark
    end

    -- Pinned to the fill's end: it follows a secret value with nothing read.
    -- The fill texture has to be set first.
    function Style.PinSpark(spark, bar)
        spark:ClearAllPoints()
        spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
        spark:SetHeight((bar:GetHeight() or 0) * Style.SPARK_HEIGHT)
    end

    -- Shown only strictly between empty and full, for a plain value.
    function Style.SparkAlpha(value, max)
        if type(value) ~= "number" or type(max) ~= "number" or max <= 0 then return 0 end
        return (value > 0 and value < max) and 1 or 0
    end

    -- The same for secret health and power: the game evaluates the curve and
    -- SetAlpha takes the secret result.
    local sparkCurve = C_CurveUtil.CreateCurve()
    sparkCurve:SetType(Enum.LuaCurveType.Linear)
    sparkCurve:AddPoint(0, 0)
    sparkCurve:AddPoint(0.001, 1)
    sparkCurve:AddPoint(0.999, 1)
    sparkCurve:AddPoint(1, 0)

    local function Evaluated(ok, alpha)
        if ok then return alpha end
        return 0
    end

    function Style.HealthSparkAlpha(unit)
        return Evaluated(pcall(UnitHealthPercent, unit, true, sparkCurve))
    end

    function Style.PowerSparkAlpha(unit)
        return Evaluated(pcall(UnitPowerPercent, unit, nil, false, sparkCurve))
    end

    -- One line, cut with an ellipsis; no shadow (the OUTLINE already rings it).
    function Style.SingleLine(label)
        label:SetShadowOffset(0, 0)
        label:SetWordWrap(false)
        label:SetNonSpaceWrap(false)
        label:SetMaxLines(1)
    end

    ---------------------------------------------------------------------------
    -- Text size: a module's `textPadding` is the share of the bar's height
    -- kept clear above and below its text.
    ---------------------------------------------------------------------------

    local DEFAULT_TEXT_PADDING = 0.15
    Style.MAX_TEXT_PADDING = 0.4
    local MIN_BAR_HEIGHT = 8        -- shorter bars have no room for text
    Style.MAX_FONT_SIZE = 11

    local function Padding(padding)
        if type(padding) ~= "number" then return DEFAULT_TEXT_PADDING end
        if padding < 0 then return 0 end
        return math.min(padding, Style.MAX_TEXT_PADDING)
    end

    -- A bar's label sized to the bar, in the text colour (or `colour`), or
    -- transparent on a bar too short for text. `minimum` floors the size.
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

    -- A bar's two labels: name on the left, cut short at the value on the right
    -- (or `room` short of the bar's right, where the value's width isn't ours).
    function Style.BarLabels(bar, name, value, padding, minimum, room)
        for _, label in ipairs({ name, value }) do
            label:ClearAllPoints()
            Style.SingleLine(label)
            Style.SetFont(bar, label, padding, minimum)
        end
        value:SetJustifyH("RIGHT")
        value:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        name:SetJustifyH("LEFT")
        name:SetPoint("LEFT", bar, "LEFT", 4, 0)
        if room then
            name:SetPoint("RIGHT", bar, "RIGHT", -room, 0)
        else
            name:SetPoint("RIGHT", value, "LEFT", -6, 0)
        end
    end

    -- The bold cut, or the regular one where a font added mid-session won't load yet.
    function Style.SetBoldFont(label, px)
        if not label:SetFont(Style.BOLD_FONT, px, "OUTLINE") then
            label:SetFont(Style.FONT, px, "OUTLINE")
        end
    end

    ---------------------------------------------------------------------------
    -- Fonts: every shared font object in a game Latin face gets Dog.ttf
    -- (display faces and headings Dog-Bold.ttf), size and outline kept; widget
    -- calls only, no font variable written (taint). Other alphabets and the
    -- combat text stay the game's.
    ---------------------------------------------------------------------------

    local REGULAR, BOLD = Style.FONT, Style.BOLD_FONT

    -- The game's Latin faces, and whether each is a display face (bold cut).
    local LATIN_FACES = {
        ["frizqt__.ttf"] = false,
        ["arialn.ttf"] = false,
        ["morpheus.ttf"] = true,
        ["skurri.ttf"] = true,
    }

    -- Font objects named as headings or titles take the bold cut too.
    local HEADING_NAMES = { "header", "title", "huge" }

    -- The combat text's fonts: 64px fonts shrunk with SetTextHeight, spaced
    -- wrong after SetFont. The world fonts too: a change passes on to children.
    local KEPT = {
        SystemFont_World = true,
        SystemFont_World_ThickOutline = true,
        CombatTextFont = true,
        CombatTextFontOutline = true,
    }

    local CHAT_SPACING = 3      -- a little more room between chat lines

    -- A font file's lower-case name, worked out once per file (every font is
    -- asked again as each addon loads).
    local faces = {}            -- file -> its name, or false
    local function Face(file)
        if type(file) ~= "string" then return nil end
        local face = faces[file]
        if face == nil then
            local name = file:match("([^\\/]+)$")
            face = name and name:lower() or false
            faces[file] = face
        end
        return face or nil
    end
    local BOLD_FACE = Face(BOLD)

    local function IsHeading(name)
        local lower = name:lower()
        for _, word in ipairs(HEADING_NAMES) do
            if lower:find(word, 1, true) then return true end
        end
        return false
    end

    -- A font object's SetFont answers nothing (SimpleFontAPI): whether the
    -- bold cut loaded (added mid-session it won't) is read back.
    local function Replace(name, font)
        local file, size, flags = font:GetFont()
        local display = LATIN_FACES[Face(file)]
        if display == nil or type(size) ~= "number" or size <= 0 then return end

        local wanted = (display or IsHeading(name)) and BOLD or REGULAR
        font:SetFont(wanted, size, flags or "")
        if wanted == BOLD and Face(font:GetFont()) ~= BOLD_FACE then
            font:SetFont(REGULAR, size, flags or "")
        end
    end

    local function ApplyFonts()
        if not GetFonts then return end
        for _, name in ipairs(GetFonts() or {}) do
            local font = _G[name]
            if not KEPT[name] and type(font) == "table" and font.GetFont then Replace(name, font) end
        end
    end

    -- The chat windows set their font file on themselves (UPDATE_CHAT_WINDOWS,
    -- the Font Size menu), past the font object: each one, and its edit box,
    -- given the player's font at the game's size. Other faces left alone.
    local function ChatFont(frame)
        if not (frame and frame.GetFont) then return end
        local file, size, flags = frame:GetFont()
        if type(size) == "number" and size > 0 and (LATIN_FACES[Face(file)] ~= nil or file == REGULAR) then
            frame:SetFont(REGULAR, size, flags or "")
        end
    end

    -- One message frame: a chat window, or the addon's copy of one.
    function Fonts.Chat(frame)
        ChatFont(frame)
        if frame and frame.SetSpacing then frame:SetSpacing(CHAT_SPACING) end
    end

    -- Whether `frame` is back in a game Latin face (the game set its font).
    local function GameFace(frame)
        if not (frame and frame.GetFont) then return false end
        local file = frame:GetFont()
        return type(file) == "string" and file ~= REGULAR and LATIN_FACES[Face(file)] ~= nil
    end

    -- The game's CHAT_FRAMES, read only - or, while it has none, the numbered
    -- windows. (Made once: KeepChat asks five times a second.)
    local numbered
    local function ChatNames()
        if CHAT_FRAMES and CHAT_FRAMES[1] ~= nil then return CHAT_FRAMES end
        if not numbered then
            local max = Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows or 10
            numbered = {}
            for i = 1, max do numbered[i] = "ChatFrame" .. i end
        end
        return numbered
    end

    -- Every chat window and its edit box in the player's font; `lostOnly`:
    -- only those the game has set back to its own.
    local function ChatFonts(lostOnly)
        for _, name in ipairs(ChatNames()) do
            local frame = _G[name]
            if frame then
                if not lostOnly or GameFace(frame) then Fonts.Chat(frame) end
                local box = frame.editBox or _G[name .. "EditBox"]
                if not lostOnly or GameFace(box) then ChatFont(box) end
            end
        end
    end

    function Fonts.ApplyChat() ChatFonts(false) end

    -- Polled by Chat\ChatLook.lua, never a hook on FCF_SetChatWindowFontSize:
    -- the game runs it while making a whisper window, and a hook broke it.
    function Fonts.KeepChat() ChatFonts(true) end

    -- The game's fonts now, each addon's as it loads; the chat after the game sets it.
    ApplyFonts()
    Fonts.ApplyChat()
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:RegisterEvent("UPDATE_CHAT_WINDOWS")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:SetScript("OnEvent", function(_, event)
        if event == "ADDON_LOADED" then ApplyFonts() end
        Fonts.ApplyChat()
    end)
end
