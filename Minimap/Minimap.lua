-- MINIMAP  (DogsForeverUI.Minimap)
--
-- The game's minimap, square and in the addon's one look: the frames' border
-- round it - gold, bevel and black, the corners rounded - and nothing of the
-- game's round frame left. No setting and no command; it is the look.
--
-- SQUARE. The map is cut to shape by its mask (Minimap:SetMaskTexture); the
-- game gives it a round one (Blizzard_Minimap Camelot\Skin.lua), the addon a
-- plain white square - the flat fill every bar uses. The game sets its round
-- mask again whenever "Rotate Minimap" is switched (a callback on the
-- rotateMinimap CVar), so the square one goes back on after it.
--
-- THE GAME'S ROUND ART is faded, not hidden: the ring (MinimapCompassTexture),
-- the ring under it in rotating mode (MinimapCompassTextureUnderlay) and the
-- zone header's bronze strip (MinimapCluster.BorderTop, a nine-slice), each
-- at no opacity. The game only ever sets their atlas, size, place and shown
-- state, never their alpha (checked across the game's UI), so they stay faded.
--
-- THE BORDER is the frames' own (Style.AddBorder), on a frame of the addon's
-- that covers the map exactly and is its child - so it moves, scales, shows
-- and hides with the map. Edit Mode's minimap size changes its scale without
-- any UI scale event, so the border is laid out again on the real pixels when
-- the game says the minimap was rescaled.
--
-- THE TITLE sits right on the map as the player frame's name sits on its
-- frame, in that frame's NAME BAND's height but drawing nothing - no
-- background, no line - exactly the minimap's width - border's outer edge to
-- border's outer edge - from the map's edge out, the map's border reaching
-- over its foot. The game's header row is moved into it and laid along its
-- middle: the zone name at the left end, tracking at the right, the calendar
-- before it, the clock before that (see PlaceRow). Above or below the map by
-- the addon's own setting, Header below (on by default - HeaderBelow); Edit
-- Mode's "Header Underneath" puts the strip back on the game's anchors each
-- time it is applied, so the row is moved in again after the game's own code
-- (a post-hook, not a replacement).
--
-- EDIT MODE'S BOX fits the title and the map with its border, 2 units out
-- all round (see FitEditBox): the game's is the whole cluster, sized for the
-- round frame.
--
-- DAY AND NIGHT: the game's own dial (MinimapCluster.DielFrame, its ring and
-- its sun or moon), moved into the map's top right corner, a little smaller
-- than the game draws it. The game places and sizes it for its round frame
-- each time the minimap is scaled (Camelot\Diel.lua), so it is moved and
-- sized again after that.
--
-- THE COORDINATES (the game's, when its setting is on) inside the map, in its
-- bottom right corner, with a solid black text shadow so they read over the map.
--
-- THE CORNERS. The game pings only where the round map was (MinimapMixin:
-- OnClick measures the click against a circle); a click in a corner, outside
-- that circle, is pinged here, after the game's own handler has passed it by.
--
-- Addons that place buttons round the minimap ask GetMinimapShape(); it now
-- says "SQUARE". Nothing of Blizzard's reads it.
--
-- BUTTONS ON THE EDGE follow the square: the mail flag in the top left
-- corner, the difficulty flag under the dial, the group finder's eye smaller
-- and inside the bottom left corner (the coordinates' mirror), and addons'
-- edge buttons moved from the old circle to the square's edge (see BUTTONS
-- ROUND THE EDGE below) - though those are now gathered into a drawer beside
-- the map, behind a handle on the map's side (Buttons.lua).
--
-- Nothing of the game's is given a field or has its scripts replaced; the
-- only things of the game's moved are the header row, the dial, the
-- coordinates, the mail and difficulty flags (the difficulty flag's banner
-- faded and its player count laid on its skull), the eye in its default
-- place and the minimap's Edit Mode box; the calendar and tracking buttons
-- are resized and their art faded under letters of the addon's (see THE
-- HEADER'S LETTERS).

local MinimapLook = {}
DogsForeverUI.Minimap = MinimapLook

do -- private scope

    local Style = DogsForeverUI.Style

    MinimapLook.MASK = Style.FLAT_TEXTURE

    local Faded = DogsForeverUI.Fade

    local function Square()
        local map = _G.Minimap
        if not map then return end
        map:SetMaskTexture(MinimapLook.MASK)
        Faded(_G.MinimapCompassTexture)
        Faded(_G.MinimapCompassTextureUnderlay)
        local cluster = _G.MinimapCluster
        if cluster then Faded(cluster.BorderTop) end
    end

    ---------------------------------------------------------------------------
    -- THE TITLE
    ---------------------------------------------------------------------------

    -- The band takes the player frame's NAME BAND's height (UnitPlate.
    -- TopRoom), and EXACTLY THE MINIMAP'S WIDTH: from the border's outer edge
    -- on one side to the other's. It sits on the map's edge, the border over
    -- its foot.
    local NameBand = DogsForeverUI.Frames.UnitPlate.NameBand
    -- The row inside it: PAD in from each end, GAP between neighbours.
    MinimapLook.PAD, MinimapLook.GAP = 4, 4
    -- Edit Mode's box, this much outside the title and the map's border.
    MinimapLook.EDIT_PADDING = 2

    -- HEADER BELOW: the addon's own setting now (ActionBars\GameFrames.lua,
    -- minimapHeaderBelow; the player, 2026-10-03: below by default, put back
    -- by a reset), not Edit Mode's "Header Underneath" - which the game takes
    -- in only from its layout as it loads, and which a preset in use cannot
    -- hold. The band is drawn above or below the map by it, whatever the
    -- game's own setting says; the cluster is hung by the map and the band
    -- together, so it follows.
    local function HeaderBelow()
        local game = DogsForeverUI.GameFrames
        local db = game and game.db
        if type(db) ~= "table" then return true end
        return db.minimapHeaderBelow ~= false
    end
    MinimapLook.HeaderBelow = HeaderBelow

    -- The band draws nothing: no black, no gold line (the player asked,
    -- 2026-10-02 - the row bare on the map's edge). It is only the place the
    -- row is laid along, and part of Edit Mode's box.

    -- How far the map's border reaches out past the map, in the band's units
    -- (the border is in the map's, which Edit Mode's minimap size scales).
    local function BorderOut(band)
        local map, border = _G.Minimap, MinimapLook.border
        local out = (border and border.out) or Style.BORDER_INSET
        local bandScale = band:GetEffectiveScale()
        if not bandScale or bandScale == 0 then return out end
        return out * map:GetEffectiveScale() / bandScale
    end
    MinimapLook.BorderOut = BorderOut

    -- The game's header row, laid along the band's middle - the middle of the
    -- part the map's border does not cover, `lift` from the band's own: the
    -- zone name at the left end (the player asked, 2026-10-02), tracking at
    -- the right, the calendar before it, the clock before that, the zone name
    -- cut short before the clock. Each is anchored
    -- by its middle, so every icon and label sits on the one line. `side`:
    -- how far the band reaches past the map each side (the border's reach),
    -- so the row keeps PAD in from the map's edge, where it always was.
    local function PlaceRow(band, lift, side)
        local cluster = _G.MinimapCluster
        local PAD, GAP = MinimapLook.PAD + (side or 0), MinimapLook.GAP
        local tracking, calendar = cluster.Tracking, _G.GameTimeFrame
        local clock, zone = _G.TimeManagerClockButton, cluster.ZoneTextButton

        -- The strip itself, which a few of the game's pieces still hang from,
        -- along the same line.
        local strip = cluster.BorderTop
        strip:ClearAllPoints()
        strip:SetPoint("LEFT", band, "LEFT", PAD, lift)
        strip:SetPoint("RIGHT", band, "RIGHT", -PAD, lift)

        -- From the right end inwards: tracking, the calendar, the clock -
        -- each hung off the one before it, or off the band's end when the
        -- ones before are missing. Each is exactly as wide as its text (the
        -- clock's time against its right edge), so LETTER_GAP is the space
        -- between the texts themselves.
        local rightOf
        local function Next(frame)
            frame:ClearAllPoints()
            if rightOf then
                frame:SetPoint("RIGHT", rightOf, "LEFT", -MinimapLook.LETTER_GAP, 0)
            else
                frame:SetPoint("RIGHT", band, "RIGHT", -PAD, lift)
            end
            rightOf = frame
        end
        if tracking then Next(tracking) end
        if calendar then Next(calendar) end
        if clock then
            Next(clock)
            local ticker = _G.TimeManagerClockTicker
            if ticker then
                ticker:ClearAllPoints()
                ticker:SetPoint("RIGHT", clock, "RIGHT", 0, 0)
            end
        end
        if zone then
            zone:ClearAllPoints()
            zone:SetPoint("LEFT", band, "LEFT", PAD, lift)
            if rightOf then
                zone:SetPoint("RIGHT", rightOf, "LEFT", -GAP, 0)
            else
                zone:SetPoint("RIGHT", band, "RIGHT", -PAD, lift)
            end
            local text = _G.MinimapZoneText
            if text then
                text:ClearAllPoints()
                text:SetPoint("LEFT", zone, "LEFT", 0, 0)
                text:SetPoint("RIGHT", zone, "RIGHT", 0, 0)
            end
        end
    end

    ---------------------------------------------------------------------------
    -- THE HEADER'S LETTERS. The calendar and tracking stay the game's buttons
    -- - their clicks, tooltips and menu - but not its art: the bronze-framed
    -- pictures, each a different size and off the clock's line, are faded
    -- (the player, 2026-10-02: "they look terrible and not aligned") and each
    -- button shows text instead, centred on it so they sit on one line with
    -- the clock: the day of the month for the calendar, T for tracking. In
    -- the clock's own font (the font object its time inherits), so the same
    -- size, but the game's gold - the zone name's own. Plain text: a drawn
    -- calendar tile and a magnifying glass came first, then an underline,
    -- and the player wanted none of them. A little dimmed until the mouse is
    -- over them, and a pixel down while pressed. Each button is ICON_SIZE
    -- tall and exactly as wide as its text, so the row's gaps are the same
    -- between every pair of texts; HIT_PAD more each side takes clicks.
    --
    -- The game sets the calendar's art again each time the date is refreshed
    -- (GameTimeFrame_SetDate, looked up by name when it is called), so it is
    -- faded again, and the day written, after that (a post-hook).
    ---------------------------------------------------------------------------
    MinimapLook.ICON_SIZE = 15
    MinimapLook.ICON_ALPHA = 0.8        -- at rest; 1 under the mouse
    MinimapLook.LETTER_FONT = "WhiteNormalNumberFont"   -- TimeManagerClockTicker's
    MinimapLook.LETTER_COLOR = { 1, 0.82, 0 }   -- NORMAL_FONT_COLOR, the zone name's gold
    MinimapLook.LETTER_GAP = 6          -- between the clock's, the day's and the T's texts
    MinimapLook.HIT_PAD = 3
    MinimapLook.TRACKING_LETTER = "T"

    local function FadeArt(button)
        for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
            local texture = type(button[get]) == "function" and button[get](button)
            if texture then texture:SetAlpha(0) end
        end
    end

    -- The glyph brightens under the mouse and moves a pixel while pressed.
    local function Respond(button, glyph)
        local function Rest() glyph:SetAlpha(MinimapLook.ICON_ALPHA) end
        local function At(x, y)
            glyph:ClearAllPoints()
            glyph:SetPoint("CENTER", button, "CENTER", x, y)
        end
        Rest()
        At(0, 0)
        button:HookScript("OnEnter", function() glyph:SetAlpha(1) end)
        button:HookScript("OnLeave", Rest)
        button:HookScript("OnMouseDown", function() At(1, -1) end)
        button:HookScript("OnMouseUp", function() At(0, 0) end)
    end

    -- Text on a button, in the clock's font and the zone name's gold, held
    -- in a frame of its own so it brightens and is pressed as one.
    local function Letters(button)
        local size, colour = MinimapLook.ICON_SIZE, MinimapLook.LETTER_COLOR
        local glyph = CreateFrame("Frame", nil, button)
        glyph:SetSize(size, size)
        glyph:EnableMouse(false)

        local label = glyph:CreateFontString(nil, "OVERLAY")
        local font = _G[MinimapLook.LETTER_FONT] or _G.GameFontNormal
        if font then label:SetFontObject(font) end
        label:SetTextColor(colour[1], colour[2], colour[3])
        label:SetPoint("CENTER", glyph, "CENTER", 0, 0)
        glyph.label = label

        local pad = MinimapLook.HIT_PAD
        button:SetHitRectInsets(-pad, -pad, 0, 0)
        Respond(button, glyph)
        return glyph
    end

    -- The button exactly as wide as its text; ICON_SIZE until the font has
    -- measured it.
    local function FitWidth(button, glyph, ...)
        local width = math.ceil(glyph.label:GetStringWidth() or 0)
        if width <= 0 then width = MinimapLook.ICON_SIZE end
        button:SetWidth(width)
        glyph:SetWidth(width)
        for _, other in ipairs({ ... }) do other:SetWidth(width) end
    end

    local function CalendarDay()
        local glyph, button = MinimapLook.calendarIcon, _G.GameTimeFrame
        FadeArt(button)
        if not glyph then return end
        local now = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
        glyph.label:SetText(now and now.monthDay or "")
        FitWidth(button, glyph)
    end

    local function BuildCalendarIcon()
        local button = _G.GameTimeFrame
        if not button or MinimapLook.calendarIcon then return end
        local size = MinimapLook.ICON_SIZE
        button:SetSize(size, size)
        MinimapLook.calendarIcon = Letters(button)
        if type(_G.GameTimeFrame_SetDate) == "function" then
            hooksecurefunc("GameTimeFrame_SetDate", CalendarDay)
        end
        CalendarDay()
    end

    local function BuildTrackingIcon()
        local tracking = _G.MinimapCluster and _G.MinimapCluster.Tracking
        local button = tracking and tracking.Button
        if not button or MinimapLook.trackingIcon then return end
        local size = MinimapLook.ICON_SIZE
        tracking:SetSize(size, size)
        button:SetSize(size, size)
        Faded(tracking.Background)
        FadeArt(button)

        local glyph = Letters(button)
        glyph.label:SetText(MinimapLook.TRACKING_LETTER)
        FitWidth(button, glyph, tracking)
        MinimapLook.trackingIcon = glyph
    end

    local function BuildIcons()
        BuildCalendarIcon()
        BuildTrackingIcon()
    end

    -- Measured again whenever the header is placed: at load the font may not
    -- have measured anything yet.
    local function FitLetters()
        local day, letter = MinimapLook.calendarIcon, MinimapLook.trackingIcon
        if day then FitWidth(_G.GameTimeFrame, day) end
        if letter then
            local tracking = _G.MinimapCluster.Tracking
            FitWidth(tracking.Button, letter, tracking)
        end
    end

    -- EDIT MODE'S BOX. The minimap's box in Edit Mode is the cluster's own
    -- rect, and the game sizes the cluster to its round frame's parts plus
    -- padding (ResizeLayoutMixin, widthPadding 20) - far bigger than the
    -- square map. Edit Mode lets a system's box (its Selection) sit inside
    -- the system's frame, re-anchoring it by its TOPLEFT and BOTTOMRIGHT from
    -- the frame's own (the unit frames' and castbar's systems do), and it snaps
    -- and clamps by that box. So the box is put exactly round the title and
    -- the map with its border, the same way, and the cluster's clamp and its
    -- clickable area are fitted to it as EditModeSystemMixin:
    -- UpdateClampOffsets would. Worked out again whenever the cluster lays
    -- itself out, the box shows, the header moves or the minimap is rescaled.
    local function FitEditBox()
        local cluster, map, band = _G.MinimapCluster, _G.Minimap, MinimapLook.band
        local box = cluster and cluster.Selection
        if not (box and map and band) then return end
        local cs, ms, bs = cluster:GetEffectiveScale(), map:GetEffectiveScale(), band:GetEffectiveScale()
        local cl, cr, ct, cb = cluster:GetLeft(), cluster:GetRight(), cluster:GetTop(), cluster:GetBottom()
        local ml, mr, mt, mb = map:GetLeft(), map:GetRight(), map:GetTop(), map:GetBottom()
        local bl, br, bt, bb = band:GetLeft(), band:GetRight(), band:GetTop(), band:GetBottom()
        if not (cl and cr and ct and cb and ml and mr and mt and mb and bl and br and bt and bb)
            or not (cs and cs > 0) then
            return
        end
        -- Everything in screen units: the band's edges, the map's with its
        -- border, the cluster's; then EDIT_PADDING (the cluster's units) more
        -- all round.
        local out = ((MinimapLook.border and MinimapLook.border.out) or Style.BORDER_INSET) * ms
        local pad = MinimapLook.EDIT_PADDING * cs
        local left = math.min(bl * bs, ml * ms - out) - pad
        local right = math.max(br * bs, mr * ms + out) + pad
        local top = math.max(bt * bs, mt * ms + out) + pad
        local bottom = math.min(bb * bs, mb * ms - out) - pad
        local dl, dr = (left - cl * cs) / cs, (right - cr * cs) / cs
        local dt, db = (top - ct * cs) / cs, (bottom - cb * cs) / cs

        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", cluster, "TOPLEFT", dl, dt)
        box:SetPoint("BOTTOMRIGHT", cluster, "BOTTOMRIGHT", dr, db)
        cluster:SetClampRectInsets(dl, dr, dt, db)
        cluster:SetHitRectInsets(dl, -dr, -dt, db)
        MinimapLook.editBox = { dl, dr, dt, db }
    end
    MinimapLook.FitEditBox = FitEditBox

    -- The band on the map's edge - above it, or under it - from the map's
    -- border's outer edge on the left to its outer edge on the right, and the
    -- game's header row moved into it.
    local function PlaceHeader()
        local band, map = MinimapLook.band, _G.Minimap
        local cluster = _G.MinimapCluster
        if not (band and map and cluster and cluster.BorderTop) then return end
        local out = BorderOut(band)
        local underneath = HeaderBelow()
        band:ClearAllPoints()
        if underneath then
            band:SetPoint("TOPLEFT", map, "BOTTOMLEFT", -out, 0)
            band:SetPoint("TOPRIGHT", map, "BOTTOMRIGHT", out, 0)
        else
            band:SetPoint("BOTTOMLEFT", map, "TOPLEFT", -out, 0)
            band:SetPoint("BOTTOMRIGHT", map, "TOPRIGHT", out, 0)
        end
        local _, height = NameBand()
        band:SetHeight(height)
        FitLetters()
        -- The map's border covers the band's foot: centre on the rest.
        PlaceRow(band, (underneath and -1 or 1) * out / 2, out)
        FitEditBox()
        -- The addon buttons' handle keeps clear of the map's border, whose
        -- reach a rescale changes.
        local buttons = MinimapLook.Buttons
        if buttons and buttons.Place then buttons.Place() end
    end
    MinimapLook.PlaceHeader = PlaceHeader

    local function BuildHeader()
        local cluster = _G.MinimapCluster
        if not (cluster and cluster.BorderTop and _G.Minimap) or MinimapLook.band then return end
        -- On the cluster, like the header row it holds (the game never scales
        -- it), and under everything the cluster holds.
        local band = CreateFrame("Frame", nil, cluster)
        band:SetFrameLevel(cluster:GetFrameLevel())
        band:EnableMouse(false)
        MinimapLook.band = band

        -- The game's own Header Underneath applied (a layout loading): its
        -- row put back on its anchors - moved into the band again, on the
        -- side the addon's setting says.
        if type(cluster.SetHeaderUnderneath) == "function" then
            hooksecurefunc(cluster, "SetHeaderUnderneath", function()
                PlaceHeader()
                MinimapLook.PlaceFlags()
            end)
        end
        -- The cluster sizes itself to its parts (ResizeLayoutMixin), which
        -- moves the box's frame: fit the box again after.
        if type(cluster.Layout) == "function" then
            hooksecurefunc(cluster, "Layout", FitEditBox)
        end
        -- The game anchoring its box again, or working its clamp out again
        -- (Edit Mode keeps every system on screen by it): ours after.
        for _, method in ipairs({ "AnchorSelectionFrame", "UpdateClampOffsets" }) do
            if type(rawget(cluster, method)) == "function" then hooksecurefunc(cluster, method, FitEditBox) end
        end
        if cluster.Selection and cluster.Selection.HookScript then
            cluster.Selection:HookScript("OnShow", FitEditBox)
        end
        PlaceHeader()
    end

    ---------------------------------------------------------------------------
    -- DAY AND NIGHT, AND THE COORDINATES
    ---------------------------------------------------------------------------

    -- The dial: DIAL_INSET (map units) in from the corner, at DIAL_SCALE of
    -- the size the game gives it (the player asked for it a little closer to
    -- the corner and a little smaller). The mail flag keeps its own inset.
    MinimapLook.DIAL_INSET = 2
    MinimapLook.DIAL_SCALE = 0.85
    MinimapLook.MAIL_INSET = 4
    MinimapLook.COORDS_INSET = 3

    local function PlaceDial()
        local cluster, map = _G.MinimapCluster, _G.Minimap
        local dial = cluster and cluster.DielFrame
        if not (dial and map) then return end
        -- The game's own size for it (Camelot\Diel.lua: never below 1 as the
        -- minimap shrinks), worked out afresh each time so it is never
        -- shrunk twice.
        local minimapScale = type(cluster.GetEditModeScale) == "function" and cluster:GetEditModeScale() or 1
        dial:SetScale(math.max(1, minimapScale or 1) * MinimapLook.DIAL_SCALE)
        local inset = MinimapLook.DIAL_INSET
        local dialScale = dial:GetEffectiveScale()
        if dialScale and dialScale > 0 then inset = inset * map:GetEffectiveScale() / dialScale end
        dial:ClearAllPoints()
        dial:SetPoint("TOPRIGHT", map, "TOPRIGHT", -inset, -inset)
        dial:SetFrameLevel(map:GetFrameLevel() + 8)
        dial:SetAlpha(1)
    end

    local function PlaceCoords()
        local map = _G.Minimap
        local container = _G.MinimapCluster and _G.MinimapCluster.MinimapContainer
        local coords = container and container.PlayerCoords
        if not (coords and map) then return end
        coords:ClearAllPoints()
        coords:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -MinimapLook.COORDS_INSET, MinimapLook.COORDS_INSET)
        coords:SetFrameLevel(map:GetFrameLevel() + 8)
        local text = coords.CoordText
        if text then
            text:SetJustifyH("RIGHT")
            -- Drawn as every bar's label is (Style.SetFont, Style.SingleLine):
            -- outlined, with a solid black drop shadow, so they read over any
            -- map (the player asked for a shadow, not a box behind them, then
            -- for it as strong as the frames' text). The font and size stay
            -- the ones the game gave them.
            local shadow = MinimapLook.COORDS_SHADOW
            text:SetShadowColor(0, 0, 0, shadow.alpha)
            text:SetShadowOffset(shadow.x, shadow.y)
            local file, size, flags = text:GetFont()
            if type(flags) ~= "string" or not flags:find("OUTLINE") then
                text:SetFont(file or Style.FONT, size or MinimapLook.COORDS_SIZE, "OUTLINE")
            end
        end
    end
    MinimapLook.COORDS_SHADOW = { x = 1, y = -1, alpha = 1 }
    -- GameFontHighlightSmall's size, if the game has not given them a font yet.
    MinimapLook.COORDS_SIZE = 10

    -- THE DIFFICULTY FLAG'S LOOK (the player asked, 2026-10-01): no banner
    -- behind it, and the player count on the skull's bottom right corner,
    -- like an item's stack count (chosen from four sketches; the count in the
    -- skull's middle was rejected). The banner - its backing and its border,
    -- in each of the flag's three modes (Default, Guild, ChallengeMode) - is
    -- faded; the game only ever sets their atlas (SetFlipped), never their
    -- alpha. The count is laid under the skull by the mode's layout frame
    -- (VerticalLayoutFrame, or the guild mode's HorizontalLayoutFrame) each
    -- time the flag updates, so it is put on the corner right after each
    -- layout (a post-hook), outlined as stack counts are.
    MinimapLook.COUNT_OFFSET = { x = 3, y = -2 }   -- out past the corner a little
    local function CountOnSkull(holder)
        local text = holder and holder.Text
        if not (text and holder.DifficultyTextures) then return end
        local skull
        for _, texture in ipairs(holder.DifficultyTextures) do
            if texture:IsShown() then skull = texture end
        end
        if not skull then return end
        local offset = MinimapLook.COUNT_OFFSET
        text:ClearAllPoints()
        text:SetPoint("BOTTOMRIGHT", skull, "BOTTOMRIGHT", offset.x, offset.y)
        text:SetJustifyH("RIGHT")
        local file, size, flags = text:GetFont()
        if file and (type(flags) ~= "string" or not flags:find("OUTLINE")) then
            text:SetFont(file, size or MinimapLook.COORDS_SIZE, "OUTLINE")
        end
    end

    local function StyleDifficulty()
        local flag = _G.MinimapCluster and _G.MinimapCluster.InstanceDifficulty
        if not flag or MinimapLook.difficultyDone then return end
        MinimapLook.difficultyDone = true
        for _, key in ipairs({ "Default", "Guild", "ChallengeMode" }) do
            local mode = flag[key]
            if mode then
                Faded(mode.Background)
                Faded(mode.Border)
            end
        end
        -- The holders of the skull and the count: the default mode itself,
        -- and the guild mode's Instance row.
        for _, holder in ipairs({ flag.Default, flag.Guild and flag.Guild.Instance }) do
            if holder and type(holder.Layout) == "function" then
                hooksecurefunc(holder, "Layout", CountOnSkull)
                CountOnSkull(holder)
            end
        end
    end

    -- The mail (and crafting order) flags into the map's top left corner,
    -- the dial's mirror; the game hangs them under the tracking button. The
    -- dungeon difficulty flag under the dial, which it would cover otherwise
    -- (the game hangs it under the header's right end).
    local function PlaceFlags()
        StyleDifficulty()
        local cluster, map = _G.MinimapCluster, _G.Minimap
        if not (cluster and map) then return end
        local inset = MinimapLook.MAIL_INSET
        local mail = cluster.IndicatorFrame
        if mail then
            mail:ClearAllPoints()
            mail:SetPoint("TOPLEFT", map, "TOPLEFT", inset, -inset)
        end
        local difficulty, dial = cluster.InstanceDifficulty, cluster.DielFrame
        if difficulty and dial then
            difficulty:ClearAllPoints()
            difficulty:SetPoint("TOPRIGHT", dial, "BOTTOMRIGHT", 0, -2)
        end
    end
    MinimapLook.PlaceFlags = PlaceFlags

    ---------------------------------------------------------------------------
    -- BUTTONS ROUND THE EDGE
    --
    -- A button that sits on the minimap's edge is placed by an angle: its
    -- centre that far round a circle about the map's centre. On a square map
    -- the same angle goes to the square's edge instead - the rule LibDBIcon
    -- uses for a square minimap (GetMinimapShape "SQUARE"): the point pushed
    -- out along its angle to the corner's diagonal (less CORNER, so a button
    -- rounds a corner rather than sitting on its point) and held to the
    -- square as far out as the circle had it.
    --
    -- An addon's button named like LibDBIcon's (LibDBIcon10_<name>) that the
    -- LibDBIcon library does not handle - one an addon places itself when the
    -- library is missing, as the Dungeon Journal does - does not ask
    -- GetMinimapShape, so it is moved each time it is placed, dragging
    -- included. Buttons LibDBIcon places itself are left to it: it asks the
    -- shape. (The group finder's eye, which Camelot pins on the round edge,
    -- has a corner of its own: see THE GROUP FINDER'S EYE below.)
    ---------------------------------------------------------------------------
    MinimapLook.CORNER = 10
    local placed = setmetatable({}, { __mode = "k" })   -- button -> the x, y given it here
    local busy = false

    -- Where a point on the circle goes on the square, in `frame`'s units.
    local function OntoSquare(frame, x, y)
        local map = _G.Minimap
        local r = math.sqrt(x * x + y * y)
        if r == 0 then return end
        local half = (map:GetWidth() or 0) / 2 * map:GetEffectiveScale() / frame:GetEffectiveScale()
        if r < half / 2 then return end     -- well inside the map: not an edge button
        local reach = math.sqrt(2) * r - MinimapLook.CORNER
        local function Held(v) return math.max(-r, math.min(r, v / r * reach)) end
        return Held(x), Held(y)
    end

    -- Move a button that sits on the round edge to the square's, once per
    -- placing: a place this file gave it is not moved again.
    local function ToSquareEdge(frame)
        local map = _G.Minimap
        if busy or not map or frame:GetNumPoints() ~= 1 then return end
        -- Kept in the addon buttons' drawer (Buttons.lua), not on the edge.
        local buttons = MinimapLook.Buttons
        if buttons and buttons.Has and buttons.Has(frame) then return end
        local point, relative, relativePoint, x, y = frame:GetPoint(1)
        if point ~= "CENTER" or relative ~= map or relativePoint ~= "CENTER" then return end
        if type(x) ~= "number" or type(y) ~= "number" then return end
        local mine = placed[frame]
        if mine and mine[1] == x and mine[2] == y then return end
        local nx, ny = OntoSquare(frame, x, y)
        if not nx then return end
        if frame.IsProtected and frame:IsProtected() and InCombatLockdown() then return end
        busy = true
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", map, "CENTER", nx, ny)
        busy = false
        placed[frame] = { nx, ny }
    end
    MinimapLook.SquareButton = ToSquareEdge

    ---------------------------------------------------------------------------
    -- THE GROUP FINDER'S EYE, while it is in its default place: inside the
    -- map's bottom left corner, the coordinates' mirror, at EYE_SCALE of the
    -- size Edit Mode gives it. (Pushed out to the square's corner along its old
    -- angle, it hung half off the map - the player asked for it in here, and
    -- smaller.) The button keeps the game's layout otherwise: its picture (the
    -- Eye, 30 of its 45 units, centred) is what is lined up with the corner.
    --
    -- Scaled and anchored through the widget's own methods (the Base ones
    -- Edit Mode keeps), not Edit Mode's overrides, which write into the frame.
    -- Edit Mode putting its size back, or the player moving it, is caught by
    -- the hooks in BuildCorners; moved, it gets Edit Mode's size back too.
    ---------------------------------------------------------------------------
    MinimapLook.EYE_SCALE = 0.6
    MinimapLook.EYE_INSET = 3
    local EYE_HALF = 15             -- half the Eye picture, in the button's units
    local eyeShrunk = false

    local function Base(frame, method)
        return frame[method .. "Base"] or frame[method]
    end

    -- The size Edit Mode would give it: its Size setting, 100 is the game's.
    local function EditModeEyeScale(eye)
        local setting = type(Enum) == "table" and Enum.EditModeGroupFinderSetting
            and Enum.EditModeGroupFinderSetting.Size
        if setting and type(eye.GetSettingValue) == "function" then
            local ok, value = pcall(eye.GetSettingValue, eye, setting)
            if ok and type(value) == "number" and value > 0 then return value / 100 end
        end
        return 1
    end

    local function PlaceEye()
        local eye, map = _G.QueueStatusButton, _G.Minimap
        if not (eye and map) then return end
        if eye.IsProtected and eye:IsProtected() and InCombatLockdown() then return end
        local scale = EditModeEyeScale(eye)

        if type(eye.IsInDefaultPosition) == "function" and not eye:IsInDefaultPosition() then
            -- Placed by the player: Edit Mode's size, and where they put it.
            if eyeShrunk then
                Base(eye, "SetScale")(eye, scale)
                eyeShrunk = false
            end
            return
        end

        Base(eye, "SetScale")(eye, scale * MinimapLook.EYE_SCALE)
        eyeShrunk = true
        local eyeScale = eye:GetEffectiveScale()
        if not eyeScale or eyeScale <= 0 then return end
        local offset = MinimapLook.EYE_INSET * map:GetEffectiveScale() / eyeScale + EYE_HALF
        eye:ClearAllPoints()
        Base(eye, "SetPoint")(eye, "CENTER", map, "BOTTOMLEFT", offset, offset)
    end

    local function LibDBIconHandles(button)
        local stub = _G.LibStub
        if type(stub) ~= "table" and type(stub) ~= "function" then return false end
        local ok, lib = pcall(stub, "LibDBIcon-1.0", true)
        if not ok then return false end
        if not (lib and type(lib.objects) == "table") then return false end
        for _, object in pairs(lib.objects) do
            if object == button then return true end
        end
        return false
    end

    local hooked = setmetatable({}, { __mode = "k" })
    local function FindButtons()
        local map = _G.Minimap
        if not (map and map.GetChildren) then return end
        for _, child in ipairs({ map:GetChildren() }) do
            local name = child.GetName and child:GetName()
            if type(name) == "string" and name:find("^LibDBIcon10_") and not LibDBIconHandles(child) then
                if not hooked[child] then
                    hooked[child] = true
                    hooksecurefunc(child, "SetPoint", ToSquareEdge)
                end
                ToSquareEdge(child)
            end
        end
    end

    local function BuildCorners()
        local cluster = _G.MinimapCluster
        if not cluster or MinimapLook.cornersDone then return end
        MinimapLook.cornersDone = true
        -- Camelot\Diel.lua sets the minimap's scale through its own
        -- SetEditModeScale, which places the dial on the round frame.
        if type(cluster.SetEditModeScale) == "function" then
            hooksecurefunc(cluster, "SetEditModeScale", PlaceDial)
        end
        -- The eye: placed from Edit Mode through its own method; from the
        -- minimap's rescale through a copy of that method the game took at
        -- load, which no hook reaches - so after the rescale, a frame later.
        -- Its size from Edit Mode's Size setting, through its own method.
        local eye = _G.QueueStatusButton
        if eye and type(eye.UpdateDefaultAnchor) == "function" then
            hooksecurefunc(eye, "UpdateDefaultAnchor", PlaceEye)
        end
        if eye and type(eye.UpdateSystemSettingSize) == "function" then
            hooksecurefunc(eye, "UpdateSystemSettingSize", PlaceEye)
        end
        if type(EventRegistry) == "table" and type(EventRegistry.RegisterCallback) == "function" then
            EventRegistry:RegisterCallback("Minimap.OnScaleUpdated", function()
                C_Timer.After(0, PlaceEye)
            end, placed)
        end
        PlaceDial()
        PlaceCoords()
        PlaceFlags()
        PlaceEye()
    end

    -- The hybrid minimap (Blizzard_HybridMinimap, load on demand) draws some
    -- interiors on a map canvas of its own over the minimap, cut by its own
    -- round mask - three units in from the edge, for the round frame. The
    -- same mask object takes the square instead and covers the whole map;
    -- every texture it masks follows.
    local function SquareHybrid()
        local hybrid = _G.HybridMinimap
        local mask = hybrid and hybrid.CircleMask
        if not mask or MinimapLook.hybridDone then return end
        MinimapLook.hybridDone = true
        mask:SetTexture(MinimapLook.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:ClearAllPoints()
        mask:SetAllPoints(hybrid)
    end

    local function Build()
        local map = _G.Minimap
        if not map or MinimapLook.frame then return end

        local frame = CreateFrame("Frame", nil, map)
        frame:SetAllPoints(map)
        frame:SetFrameLevel(map:GetFrameLevel() + 1)
        frame:EnableMouse(false)
        MinimapLook.frame = frame
        MinimapLook.border = Style.AddBorder(frame)

        -- A click in a corner: the game's handler has already measured it
        -- against its circle and let it go, so only those are pinged here.
        map:HookScript("OnMouseUp", function(self)
            local scale = self:GetEffectiveScale()
            local x, y = GetCursorPosition()
            local cx, cy = self:GetCenter()
            if not (scale and x and cx) then return end
            x, y = x / scale - cx, y / scale - cy
            if math.sqrt(x * x + y * y) >= self:GetWidth() / 2 then
                self:PingLocation(x, y)
            end
        end)

        if type(EventRegistry) == "table" and type(EventRegistry.RegisterCallback) == "function" then
            EventRegistry:RegisterCallback("Minimap.OnScaleUpdated", function()
                Style.Refit(MinimapLook.border)
                -- The band's width follows the border's reach.
                PlaceHeader()
            end, MinimapLook)
        end
    end

    function GetMinimapShape() return "SQUARE" end

    local function Apply()
        Build()
        BuildHeader()
        BuildIcons()
        -- Again as the game's pieces arrive: the clock comes with
        -- Blizzard_TimeManager, loaded after the minimap.
        PlaceHeader()
        BuildCorners()
        Square()
        SquareHybrid()
        FindButtons()
    end
    Apply()

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:RegisterEvent("PLAYER_LOGIN")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("CVAR_UPDATE")
    watcher:SetScript("OnEvent", function(_, event, name)
        if event == "PLAYER_LOGIN" then
            -- Addons make their minimap buttons at login too, some after
            -- this addon's turn: look again once they all have had theirs.
            C_Timer.After(0, FindButtons)
            return
        end
        if event == "CVAR_UPDATE" then
            -- The game's own callback may run after this one: square again
            -- on the next frame too, once it has.
            if name == "rotateMinimap" then
                Square()
                C_Timer.After(0, Square)
            end
            return
        end
        Apply()
        if event == "PLAYER_ENTERING_WORLD" and MinimapLook.border then
            Style.Refit(MinimapLook.border)
            PlaceHeader()
            PlaceDial()
            PlaceCoords()
            PlaceFlags()
            PlaceEye()
        end
    end)
end
