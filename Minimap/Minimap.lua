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
-- frame, in that frame's NAME BAND exactly (UnitPlate: black fading out to
-- both ends under a thin gold line that fades the same way, the same height),
-- the map's width, from the map's edge out, the map's border drawn over its
-- foot. The
-- game's header row is moved into it and laid along its middle: tracking at
-- the left end, the calendar at the right, the clock before it, the zone name
-- between (see PlaceRow). Edit Mode's "header underneath" puts the strip back
-- on the game's anchors each time it is applied, so the band follows it:
-- under the map, the row moved in again after the game's own code (a
-- post-hook, not a replacement).
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
-- ROUND THE EDGE below).
--
-- Nothing of the game's is given a field or has its scripts replaced; the
-- only things of the game's moved are the header row, the dial, the
-- coordinates, the mail and difficulty flags, the eye in its default place and
-- the minimap's Edit Mode box.

local MinimapLook = {}
DogsForeverUI.Minimap = MinimapLook

do -- private scope

    local Style = DogsForeverUI.Style

    MinimapLook.MASK = Style.FLAT_TEXTURE

    local function Faded(region)
        if region and region.SetAlpha then region:SetAlpha(0) end
    end

    local function Square()
        local map = _G.Minimap
        if not map then return end
        map:SetMaskTexture(MinimapLook.MASK)
        Faded(_G.MinimapCompassTexture)
        Faded(_G.MinimapCompassTextureUnderlay)
        local cluster = _G.MinimapCluster
        if cluster then Faded(cluster.BorderTop) end
    end
    MinimapLook.Square = Square

    ---------------------------------------------------------------------------
    -- THE TITLE
    ---------------------------------------------------------------------------

    -- The band wears the player frame's NAME BAND exactly - its look from
    -- UnitPlate.NAME_BAND (black fading out to both ends under a gold line
    -- that fades the same way) and its height (UnitPlate.TopRoom), and it sits
    -- on the map as that band sits on its frame: the map's width, from its
    -- edge out, the border drawn over its foot. The fallbacks are the same
    -- numbers, for a load without the frames.
    local function NameBand()
        local UnitPlate = DogsForeverUI.Frames and DogsForeverUI.Frames.UnitPlate
        local look = UnitPlate and UnitPlate.NAME_BAND or { alpha = 0.55, lineAlpha = 0.9, fade = 0.35 }
        local height = UnitPlate and UnitPlate.TopRoom and UnitPlate.TopRoom() or 24
        return look, height
    end
    MinimapLook.NameBand = NameBand
    -- The row inside it: PAD in from each end, GAP between neighbours.
    MinimapLook.PAD, MinimapLook.GAP = 4, 4
    -- Edit Mode's box, this much outside the title and the map's border.
    MinimapLook.EDIT_PADDING = 2

    local underneath = false   -- Edit Mode's "header underneath"

    -- One of the band's two layers, three pieces: a fade in over the outer
    -- `fade` of the width, solid, a fade out (a texture fades one way only) -
    -- UnitPlate's own construction.
    local function Pieces(band, sub, colour, alpha)
        local pieces = {}
        local r, g, b = colour[1], colour[2], colour[3]
        for i = 1, 3 do
            local piece = band:CreateTexture(nil, "BACKGROUND", nil, sub)
            piece:SetTexture(Style.FLAT_TEXTURE)
            if i == 2 or not (piece.SetGradient and CreateColor) then
                piece:SetVertexColor(r, g, b, i == 2 and alpha or alpha / 2)
            elseif i == 1 then
                piece:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, alpha))
            else
                piece:SetGradient("HORIZONTAL", CreateColor(r, g, b, alpha), CreateColor(r, g, b, 0))
            end
            pieces[i] = piece
        end
        return pieces
    end

    -- The pieces across the band's width, as UnitPlate lays its own: the
    -- black its full height, the line one real pixel tall on its outer edge -
    -- the top, or the bottom when the band is under the map.
    local function LayOutBand(band)
        local width = band:GetWidth() or 0
        if width <= 0 then return end
        local look = NameBand()
        local edge = math.floor(width * look.fade + 0.5)
        local from, to = { 0, edge, width - edge }, { edge, width - edge, width }
        local outer = underneath and "BOTTOMLEFT" or "TOPLEFT"
        for i = 1, 3 do
            local fill, line = band.fill[i], band.line[i]
            fill:ClearAllPoints()
            fill:SetPoint("TOPLEFT", band, "TOPLEFT", from[i], 0)
            fill:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT", from[i], 0)
            fill:SetWidth(to[i] - from[i])
            line:ClearAllPoints()
            line:SetPoint(outer, band, outer, from[i], 0)
            line:SetWidth(to[i] - from[i])
            if PixelUtil and PixelUtil.SetHeight then
                PixelUtil.SetHeight(line, 1, 1)
            else
                line:SetHeight(1)
            end
        end
    end

    -- How far the map's border reaches out past the map, in the band's units
    -- (the border is in the map's, which Edit Mode's minimap size scales).
    local function BorderOut(band)
        local map, border = _G.Minimap, MinimapLook.border
        local out = (border and border.out) or Style.BORDER_INSET
        local bandScale = band:GetEffectiveScale()
        if not bandScale or bandScale == 0 then return out end
        return out * map:GetEffectiveScale() / bandScale
    end

    -- The game's header row, laid along the band's middle - the middle of the
    -- part the map's border does not cover, `lift` from the band's own:
    -- tracking at the left end, the calendar at the right, the clock before
    -- it, the zone name between, cut short before the clock. Each is anchored
    -- by its middle, so every icon and label sits on the one line.
    local function PlaceRow(band, lift)
        local cluster = _G.MinimapCluster
        local PAD, GAP = MinimapLook.PAD, MinimapLook.GAP
        local tracking, calendar = cluster.Tracking, _G.GameTimeFrame
        local clock, zone = _G.TimeManagerClockButton, cluster.ZoneTextButton

        -- The strip itself, which a few of the game's pieces still hang from,
        -- along the same line.
        local strip = cluster.BorderTop
        strip:ClearAllPoints()
        strip:SetPoint("LEFT", band, "LEFT", PAD, lift)
        strip:SetPoint("RIGHT", band, "RIGHT", -PAD, lift)

        if tracking then
            tracking:ClearAllPoints()
            tracking:SetPoint("LEFT", band, "LEFT", PAD, lift)
        end
        if calendar then
            calendar:ClearAllPoints()
            calendar:SetPoint("RIGHT", band, "RIGHT", -PAD, lift)
        end
        local rightOf = calendar
        if clock then
            clock:ClearAllPoints()
            if calendar then
                clock:SetPoint("RIGHT", calendar, "LEFT", -GAP / 2, 0)
            else
                clock:SetPoint("RIGHT", band, "RIGHT", -PAD, lift)
            end
            local ticker = _G.TimeManagerClockTicker
            if ticker then
                ticker:ClearAllPoints()
                ticker:SetPoint("RIGHT", clock, "RIGHT", 0, 0)
            end
            rightOf = clock
        end
        if zone then
            zone:ClearAllPoints()
            if tracking then
                zone:SetPoint("LEFT", tracking, "RIGHT", GAP, 0)
            else
                zone:SetPoint("LEFT", band, "LEFT", PAD, lift)
            end
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

    -- The band on the map's edge - above it, or under it - the map's width,
    -- as the player frame's sits on its frame, and the game's header row
    -- moved into it.
    local function PlaceHeader()
        local band, map = MinimapLook.band, _G.Minimap
        local cluster = _G.MinimapCluster
        if not (band and map and cluster and cluster.BorderTop) then return end
        local out = BorderOut(band)
        band:ClearAllPoints()
        if underneath then
            band:SetPoint("TOPLEFT", map, "BOTTOMLEFT", 0, 0)
            band:SetPoint("TOPRIGHT", map, "BOTTOMRIGHT", 0, 0)
        else
            band:SetPoint("BOTTOMLEFT", map, "TOPLEFT", 0, 0)
            band:SetPoint("BOTTOMRIGHT", map, "TOPRIGHT", 0, 0)
        end
        local _, height = NameBand()
        band:SetHeight(height)
        LayOutBand(band)
        -- The map's border covers the band's foot: centre on the rest.
        PlaceRow(band, (underneath and -1 or 1) * out / 2)
        FitEditBox()
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
        local look = NameBand()
        band.fill = Pieces(band, -8, { 0, 0, 0 }, look.alpha)
        band.line = Pieces(band, -7, Style.BORDER_COLOR, look.lineAlpha)
        band:SetScript("OnSizeChanged", LayOutBand)
        MinimapLook.band = band

        if type(cluster.SetHeaderUnderneath) == "function" then
            hooksecurefunc(cluster, "SetHeaderUnderneath", function(_, below)
                underneath = below and true or false
                PlaceHeader()
                MinimapLook.PlaceFlags()
            end)
        end
        -- The cluster sizes itself to its parts (ResizeLayoutMixin), which
        -- moves the box's frame: fit the box again after.
        if type(cluster.Layout) == "function" then
            hooksecurefunc(cluster, "Layout", FitEditBox)
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
    MinimapLook.PlaceDial = PlaceDial

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

    -- The mail (and crafting order) flags into the map's top left corner,
    -- the dial's mirror; the game hangs them under the tracking button. The
    -- dungeon difficulty flag under the dial, which it would cover otherwise
    -- (the game hangs it under the header's right end).
    local function PlaceFlags()
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
    MinimapLook.OntoSquare = OntoSquare

    -- Move a button that sits on the round edge to the square's, once per
    -- placing: a place this file gave it is not moved again.
    local function ToSquareEdge(frame)
        local map = _G.Minimap
        if busy or not map or frame:GetNumPoints() ~= 1 then return end
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
    MinimapLook.PlaceEye = PlaceEye

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
    MinimapLook.FindButtons = FindButtons

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
