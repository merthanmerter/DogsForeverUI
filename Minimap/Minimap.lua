-- MINIMAP  (DogsForeverUI.Minimap)
-- The game's minimap, square, in the frames' border, its round art faded; the
-- header row laid along a band on the map's edge (below it by default); the
-- dial, mail flag, coordinates and the group finder's eye moved into its corners
-- (on retail the difficulty flag and the expansion button, its eye left alone).
-- No setting of its own; nothing of the game's is given a field.

local MinimapLook = {}
DogsForeverUI.Minimap = MinimapLook

do -- private scope
    local Style = DogsForeverUI.Style
    local Core = DogsForeverUI
    local Faded = Core.Fade

    local COORDS_SIZE = 10      -- GameFontHighlightSmall's, before the game sets a font
    local EYE_HALF = 15         -- half the eye's picture, in the button's units

    MinimapLook.PAD, MinimapLook.GAP = 4, 4         -- the header row, in from the ends; between
    MinimapLook.EDIT_PADDING = 2                    -- Edit Mode's box, round title and map
    MinimapLook.ICON_SIZE = 15
    MinimapLook.ICON_ALPHA = 0.8                    -- the header's letters at rest
    MinimapLook.LETTER_COLOR = { 1, 0.82, 0 }       -- the zone name's gold
    MinimapLook.LETTER_GAP = 6                      -- between the clock's, the day's and the T's texts
    MinimapLook.HIT_PAD = 3
    MinimapLook.TRACKING_LETTER = "T"
    MinimapLook.DIAL_INSET = 2
    MinimapLook.DIAL_SCALE = 0.85                   -- of the game's own size for it
    MinimapLook.MAIL_INSET = 4
    MinimapLook.COORDS_INSET = 3
    MinimapLook.COORDS_SHADOW = { x = 1, y = -1, alpha = 1 }
    MinimapLook.CORNER = 10                         -- an edge button rounds a corner by this
    MinimapLook.EYE_SCALE = 0.6
    MinimapLook.EYE_INSET = 3

    local NameBand = Core.Frames.UnitPlate.NameBand

    -- LibDBIcon, if an addon has loaded it, and whether it made a button.
    function MinimapLook.LibDBIcon()
        local ok, lib = pcall(_G.LibStub, "LibDBIcon-1.0", true)
        if ok and type(lib) == "table" and type(lib.objects) == "table" then return lib end
    end

    function MinimapLook.MadeBy(lib, frame)
        if not lib then return false end
        for _, object in pairs(lib.objects) do
            if object == frame then return true end
        end
        return false
    end

    -- The game sets its round mask again when "Rotate Minimap" switches.
    local function Square()
        local map = _G.Minimap
        if not map then return end
        map:SetMaskTexture(Style.FLAT_TEXTURE)
        Faded(_G.MinimapCompassTexture)
        Faded(_G.MinimapCompassTextureUnderlay)
    end

    ---------------------------------------------------------------------------
    -- THE TITLE: a band of the player frame's name band's height, exactly
    -- the map's width with its border, on the map's edge. It draws nothing.

    -- The addon's own setting (ActionBars\GameFrames.lua), not Edit Mode's.
    function MinimapLook.HeaderBelow()
        local game = Core.GameFrames
        return not game or game.db.minimapHeaderBelow ~= false
    end

    -- How far the map's border reaches past the map, in the map's units.
    local function Reach()
        return MinimapLook.border and MinimapLook.border.out or Style.BORDER_INSET
    end

    -- ... in `band`'s units.
    function MinimapLook.BorderOut(band)
        local bandScale = band:GetEffectiveScale()
        if not bandScale or bandScale == 0 then return Reach() end
        return Reach() * _G.Minimap:GetEffectiveScale() / bandScale
    end

    -- The game's header row along the band, `lift` off its middle: the zone
    -- name from the left, then from the right tracking, the calendar and
    -- the clock, each by its middle on one line. `side`: the border's reach.
    local function PlaceRow(band, lift, side)
        local cluster = _G.MinimapCluster
        local PAD, GAP = MinimapLook.PAD + side, MinimapLook.GAP
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
        if cluster.Tracking then Next(cluster.Tracking) end
        if _G.GameTimeFrame then Next(_G.GameTimeFrame) end
        local clock = _G.TimeManagerClockButton     -- with Blizzard_TimeManager, later
        if clock then
            Next(clock)
            local ticker = _G.TimeManagerClockTicker
            if ticker then
                ticker:ClearAllPoints()
                ticker:SetPoint("RIGHT", clock, "RIGHT", 0, 0)
            end
        end
        local zone = cluster.ZoneTextButton
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
    -- THE HEADER'S LETTERS: the calendar and tracking stay the game's buttons,
    -- their art faded under text in the clock's font and the zone's gold -
    -- the day of the month, and T. Each button exactly as wide as its text.

    -- Every picture of a header button's faded, whichever the client draws
    -- with (Forever's StateTexture, retail's own; the game sets a picture
    -- again on every state change, never its alpha), and its hover glow
    -- emptied (the game sets its alpha on every hover, never its picture).
    -- Retail frames its zone button with a nine-slice too. A lettered
    -- button's child frames too, all but our letters.
    local letters = {}          -- button -> our letters on it
    local function FadeTextures(frame)
        for _, region in ipairs({ frame:GetRegions() }) do
            if region:IsObjectType("Texture") then Faded(region) end
        end
    end
    local function FadeArt(button)
        if not button then return end
        FadeTextures(button)
        local glyph = letters[button]
        if glyph then
            for _, child in ipairs({ button:GetChildren() }) do
                if child ~= glyph then FadeTextures(child) end
            end
        end
        Faded(button.BorderTop)
        if button.AddTexture then button.AddTexture:SetTexture(nil) end
    end

    -- Dimmed until the mouse is over it, a pixel down while pressed; the
    -- game's art faded again after each state change (a client may swap it).
    local function Letters(button)
        local glyph = CreateFrame("Frame", nil, button)
        letters[button] = glyph
        glyph:SetSize(MinimapLook.ICON_SIZE, MinimapLook.ICON_SIZE)
        glyph:EnableMouse(false)

        local label = glyph:CreateFontString(nil, "OVERLAY")
        label:SetFontObject(WhiteNormalNumberFont)     -- the clock's time's
        local colour = MinimapLook.LETTER_COLOR
        label:SetTextColor(colour[1], colour[2], colour[3])
        label:SetPoint("CENTER", glyph, "CENTER", 0, 0)
        glyph.label = label

        local function Rest()
            glyph:SetAlpha(MinimapLook.ICON_ALPHA)
            FadeArt(button)
        end
        local function At(x, y)
            glyph:ClearAllPoints()
            glyph:SetPoint("CENTER", button, "CENTER", x, y)
            FadeArt(button)
        end
        Rest()
        At(0, 0)
        button:HookScript("OnEnter", function()
            glyph:SetAlpha(1)
            FadeArt(button)
        end)
        button:HookScript("OnLeave", Rest)
        button:HookScript("OnMouseDown", function() At(1, -1) end)
        button:HookScript("OnMouseUp", function() At(0, 0) end)
        button:SetHitRectInsets(-MinimapLook.HIT_PAD, -MinimapLook.HIT_PAD, 0, 0)
        return glyph
    end

    -- ICON_SIZE until the font has measured the text.
    local function FitWidth(button, glyph, also)
        local width = math.ceil(glyph.label:GetStringWidth() or 0)
        if width <= 0 then width = MinimapLook.ICON_SIZE end
        button:SetWidth(width)
        glyph:SetWidth(width)
        if also then also:SetWidth(width) end
    end

    -- After the game's own SetDate.
    local function CalendarDay()
        local glyph, button = MinimapLook.calendarIcon, _G.GameTimeFrame
        glyph.label:SetText(C_DateAndTime.GetCurrentCalendarTime().monthDay)
        FitWidth(button, glyph)
        FadeArt(button)
    end

    local function BuildIcons()
        local calendar = _G.GameTimeFrame
        if calendar and not MinimapLook.calendarIcon then
            calendar:SetSize(MinimapLook.ICON_SIZE, MinimapLook.ICON_SIZE)
            MinimapLook.calendarIcon = Letters(calendar)
            if calendar.SetDate then
                hooksecurefunc(calendar, "SetDate", CalendarDay)
            elseif GameTimeFrame_SetDate then
                hooksecurefunc("GameTimeFrame_SetDate", CalendarDay)
            end
            CalendarDay()
        end

        local tracking = _G.MinimapCluster and _G.MinimapCluster.Tracking
        local button = tracking and tracking.Button
        if button and not MinimapLook.trackingIcon then
            tracking:SetSize(MinimapLook.ICON_SIZE, MinimapLook.ICON_SIZE)
            button:SetSize(MinimapLook.ICON_SIZE, MinimapLook.ICON_SIZE)
            Faded(tracking.Background)
            local glyph = Letters(button)
            glyph.label:SetText(MinimapLook.TRACKING_LETTER)
            FitWidth(button, glyph, tracking)
            MinimapLook.trackingIcon = glyph
        end
    end

    -- Measured again whenever the header is placed: at load the font may
    -- not have measured anything yet.
    local function FitLetters()
        local day, letter = MinimapLook.calendarIcon, MinimapLook.trackingIcon
        if day then FitWidth(_G.GameTimeFrame, day) end
        if letter then
            local tracking = _G.MinimapCluster.Tracking
            FitWidth(tracking.Button, letter, tracking)
        end
    end

    -- EDIT MODE'S BOX is the cluster's rect, sized for the round frame: put
    -- round the title and the map with its border instead (as the unit
    -- frames' systems do), and the cluster's clamp and clicks fitted to it
    -- as EditModeSystemMixin:UpdateClampOffsets would.
    function MinimapLook.FitEditBox()
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
        -- In screen units, then back into the cluster's.
        local out = Reach() * ms
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
    end

    function MinimapLook.PlaceHeader()
        local band, map = MinimapLook.band, _G.Minimap
        if not (band and map) then return end
        local out = MinimapLook.BorderOut(band)
        local underneath = MinimapLook.HeaderBelow()
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
        -- The map's border covers the band's foot: centred on the rest.
        PlaceRow(band, (underneath and -1 or 1) * out / 2, out)
        MinimapLook.FitEditBox()
        -- The drawer's handle keeps clear of the border, whose reach a rescale changes.
        if MinimapLook.Buttons then MinimapLook.Buttons.Place() end
    end

    ---------------------------------------------------------------------------
    -- THE CORNERS

    -- The game places and sizes the dial for its round frame each time the
    -- minimap is scaled (Camelot\Diel.lua): into the top right corner, a
    -- little smaller, from the game's own size each time.
    local function PlaceDial()
        local cluster, map = _G.MinimapCluster, _G.Minimap
        local dial = cluster and cluster.DielFrame
        if not (dial and map) then return end
        local minimapScale = cluster.GetEditModeScale and cluster:GetEditModeScale() or 1
        dial:SetScale(math.max(1, minimapScale) * MinimapLook.DIAL_SCALE)
        local inset = MinimapLook.DIAL_INSET
        local dialScale = dial:GetEffectiveScale()
        if dialScale and dialScale > 0 then inset = inset * map:GetEffectiveScale() / dialScale end
        dial:ClearAllPoints()
        dial:SetPoint("TOPRIGHT", map, "TOPRIGHT", -inset, -inset)
        dial:SetFrameLevel(map:GetFrameLevel() + 8)
        dial:SetAlpha(1)
    end

    -- Bottom right, right-aligned, outlined once (in the font and size the
    -- game gave it) with a solid shadow.
    local function PlaceCoords()
        local map = _G.Minimap
        local container = _G.MinimapCluster and _G.MinimapCluster.MinimapContainer
        local coords = container and container.PlayerCoords
        if not (coords and map) then return end
        coords:ClearAllPoints()
        coords:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -MinimapLook.COORDS_INSET, MinimapLook.COORDS_INSET)
        coords:SetFrameLevel(map:GetFrameLevel() + 8)
        local text = coords.CoordText
        if not text then return end
        local shadow = MinimapLook.COORDS_SHADOW
        text:SetShadowColor(0, 0, 0, shadow.alpha)
        text:SetShadowOffset(shadow.x, shadow.y)
        text:SetJustifyH("RIGHT")
        local file, size, flags = text:GetFont()
        if type(flags) ~= "string" or not flags:find("OUTLINE") then
            text:SetFont(file or Style.FONT, size or COORDS_SIZE, "OUTLINE")
        end
    end

    -- The mail flag in the top left corner, the dial's mirror; retail's
    -- instance difficulty flag (no dial there) in the top right, over the map.
    local function PlaceFlags()
        local cluster, map = _G.MinimapCluster, _G.Minimap
        if not (cluster and map) then return end
        local mail, difficulty, inset = cluster.IndicatorFrame, cluster.InstanceDifficulty, MinimapLook.MAIL_INSET
        if mail then
            mail:ClearAllPoints()
            mail:SetPoint("TOPLEFT", map, "TOPLEFT", inset, -inset)
        end
        if difficulty then
            difficulty:ClearAllPoints()
            difficulty:SetPoint("TOPRIGHT", map, "TOPRIGHT", -inset, -inset)
            difficulty:SetFrameLevel(map:GetFrameLevel() + 8)
        end
    end

    -- BUTTONS ON THE EDGE: placed by an angle round the old circle, moved to
    -- the square's edge along it (LibDBIcon's rule for a square map). Only
    -- for a button named like LibDBIcon's that the library does not place:
    -- the library asks GetMinimapShape itself.
    local placed = setmetatable({}, { __mode = "k" })   -- button -> the x, y given it here
    local busy = false

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

    function MinimapLook.SquareButton(frame)
        local map = _G.Minimap
        if busy or not map or frame:GetNumPoints() ~= 1 then return end
        local buttons = MinimapLook.Buttons
        if buttons and buttons.Has(frame) then return end      -- in the drawer
        local point, relative, relativePoint, x, y = frame:GetPoint(1)
        if point ~= "CENTER" or relative ~= map or relativePoint ~= "CENTER" then return end
        if type(x) ~= "number" or type(y) ~= "number" then return end
        local mine = placed[frame]
        if mine and mine[1] == x and mine[2] == y then return end
        local nx, ny = OntoSquare(frame, x, y)
        if not nx then return end
        if frame:IsProtected() and InCombatLockdown() then return end
        busy = true
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", map, "CENTER", nx, ny)
        busy = false
        placed[frame] = { nx, ny }
    end

    -- THE GROUP FINDER'S EYE, in its default place: inside the bottom left
    -- corner, smaller. Through the widget's own Base methods, never Edit
    -- Mode's overrides, which write into the frame.
    local eyeShrunk = false

    local function Base(frame, method)
        return frame[method .. "Base"] or frame[method]
    end

    -- Edit Mode's Size setting for it (100 is the game's).
    local function EditModeEyeScale(eye)
        local setting = Enum.EditModeGroupFinderSetting and Enum.EditModeGroupFinderSetting.Size
        if setting and eye.GetSettingValue then
            -- (pcall: its settings are not there until Edit Mode has loaded them.)
            local ok, value = pcall(eye.GetSettingValue, eye, setting)
            if ok and type(value) == "number" and value > 0 then return value / 100 end
        end
        return 1
    end

    -- The game anchors it to the micro menu (out of sight here, a mouseover) from many
    -- places, in combat too: EllesmereUI's way, it is taken out of the micro menu - its
    -- parent the screen, out of the menu's layout - and put back after each of the game's
    -- moves and queue changes (a place refused in combat is taken as combat ends).
    local function PlaceEye()
        local eye, map = _G.QueueStatusButton, _G.Minimap
        if not (eye and map) then return end
        if eye:IsProtected() and InCombatLockdown() then return end
        if eye:GetParent() ~= UIParent then
            if eye.SetIsLayoutFrame then pcall(eye.SetIsLayoutFrame, eye, false) end
            eye:SetParent(UIParent)
        end
        local scale = EditModeEyeScale(eye)

        if eye.IsInDefaultPosition and not eye:IsInDefaultPosition() then
            -- Placed by the player: Edit Mode's size, where they put it.
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
        Base(eye, "ClearAllPoints")(eye)
        Base(eye, "SetPoint")(eye, "CENTER", map, "BOTTOMLEFT", offset, offset)
    end
    -- The rescale places it through a copy of its method no hook reaches: a frame later.
    local PlaceEyeSoon = Core.Waker(PlaceEye)

    -- RETAIL'S EXPANSION BUTTON, off the round frame's edge: over the eye in
    -- its corner, as small, each time the game sets its icon and its place.
    local function PlaceExpansion()
        local button, eye = _G.ExpansionLandingPageMinimapButton, _G.QueueStatusButton
        if not (Core.RETAIL and button and eye) then return end
        button:SetScale(MinimapLook.EYE_SCALE)
        button:ClearAllPoints()
        button:SetPoint("BOTTOM", eye, "TOP", 0, 0)
    end

    local function PlaceCorners()
        PlaceDial()
        PlaceCoords()
        PlaceFlags()
        PlaceEye()
        PlaceExpansion()
    end

    local hooked = setmetatable({}, { __mode = "k" })
    local function FindButtons()
        local map = _G.Minimap
        if not (map and map.GetChildren) then return end
        local lib = MinimapLook.LibDBIcon()
        for _, child in ipairs({ map:GetChildren() }) do
            local name = child:GetName()
            if name and name:find("^LibDBIcon10_") and not MinimapLook.MadeBy(lib, child) then
                if not hooked[child] then
                    hooked[child] = true
                    hooksecurefunc(child, "SetPoint", MinimapLook.SquareButton)
                end
                MinimapLook.SquareButton(child)
            end
        end
    end
    -- Addons make their buttons at login too, some after this addon's turn.
    local FindButtonsSoon = Core.Waker(FindButtons)

    local cornersBuilt = false
    local function BuildCorners()
        local cluster = _G.MinimapCluster
        if not cluster or cornersBuilt then return end
        cornersBuilt = true
        if cluster.SetEditModeScale then hooksecurefunc(cluster, "SetEditModeScale", PlaceDial) end
        -- The tracking button showing adds a point to the mail flag.
        if MiniMapIndicatorFrame_UpdatePosition then hooksecurefunc("MiniMapIndicatorFrame_UpdatePosition", PlaceFlags) end
        local eye = _G.QueueStatusButton
        for _, method in ipairs({ "UpdateDefaultAnchor", "UpdatePosition", "UpdateSystemSettingSize", "UpdateDisplay" }) do
            if eye and eye[method] then hooksecurefunc(eye, method, PlaceEye) end
        end
        EventRegistry:RegisterCallback("QueueStatusButton.OnShow", PlaceEye, placed)
        EventRegistry:RegisterCallback("Minimap.OnScaleUpdated", PlaceEyeSoon, placed)
        local expansion = _G.ExpansionLandingPageMinimapButton
        if expansion and expansion.UpdateIcon then hooksecurefunc(expansion, "UpdateIcon", PlaceExpansion) end
        PlaceCorners()
    end

    -- The hybrid minimap (load on demand) cuts its own canvas with a round
    -- mask three units in: that mask made the square, over the whole map.
    local hybridSquared = false
    local function SquareHybrid()
        local hybrid = _G.HybridMinimap
        local mask = hybrid and hybrid.CircleMask
        if not mask or hybridSquared then return end
        hybridSquared = true
        mask:SetTexture(Style.FLAT_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:ClearAllPoints()
        mask:SetAllPoints(hybrid)
    end

    local function Build()
        local map, cluster = _G.Minimap, _G.MinimapCluster
        if not map or MinimapLook.frame then return end

        local frame = CreateFrame("Frame", nil, map)
        frame:SetAllPoints(map)
        frame:SetFrameLevel(map:GetFrameLevel() + 1)
        frame:EnableMouse(false)
        MinimapLook.frame = frame
        MinimapLook.border = Style.AddBorder(frame)

        -- The game pings only inside its round map: a corner, after it.
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

        -- Edit Mode's minimap size scales it with no UI scale event.
        EventRegistry:RegisterCallback("Minimap.OnScaleUpdated", function()
            Style.Refit(MinimapLook.border)
            MinimapLook.PlaceHeader()
        end, MinimapLook)

        if not cluster then return end
        -- On the cluster, under everything it holds.
        local band = CreateFrame("Frame", nil, cluster)
        band:SetFrameLevel(cluster:GetFrameLevel())
        band:EnableMouse(false)
        MinimapLook.band = band
        FadeArt(cluster.ZoneTextButton)
        Faded(cluster.BorderTop)        -- (live retail's header frame, on the cluster)
        -- Rotate Minimap switching: the game sets its round mask again.
        if cluster.UpdateMinimapConfig then hooksecurefunc(cluster, "UpdateMinimapConfig", Square) end
        -- The game putting the row back on its anchors (a layout loading),
        -- the cluster laying itself out, or Edit Mode re-anchoring its box.
        if cluster.SetHeaderUnderneath then
            hooksecurefunc(cluster, "SetHeaderUnderneath", function()
                MinimapLook.PlaceHeader()
                PlaceFlags()
            end)
        end
        if cluster.Layout then hooksecurefunc(cluster, "Layout", MinimapLook.FitEditBox) end
        for _, method in ipairs({ "AnchorSelectionFrame", "UpdateClampOffsets" }) do
            if rawget(cluster, method) then hooksecurefunc(cluster, method, MinimapLook.FitEditBox) end
        end
        if cluster.Selection then cluster.Selection:HookScript("OnShow", MinimapLook.FitEditBox) end
    end

    -- Addons placing buttons round the minimap ask this; nothing of Blizzard's does.
    function GetMinimapShape() return "SQUARE" end

    -- Again as the game's pieces arrive (the clock comes with Blizzard_TimeManager).
    local function Apply()
        Build()
        BuildIcons()
        MinimapLook.PlaceHeader()
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
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    local QUEUE_EVENTS = { LFG_UPDATE = true, LFG_QUEUE_STATUS_UPDATE = true, LFG_PROPOSAL_UPDATE = true,
                           LFG_ROLE_CHECK_UPDATE = true }
    for event in pairs(QUEUE_EVENTS) do pcall(watcher.RegisterEvent, watcher, event) end
    watcher:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" then return FindButtonsSoon() end
        if QUEUE_EVENTS[event] then return PlaceEye() end
        -- (A corner piece the game moved in combat may not be moved back then: now.)
        if event == "PLAYER_REGEN_ENABLED" then return PlaceCorners() end
        Apply()
        if event == "PLAYER_ENTERING_WORLD" and MinimapLook.border then
            Style.Refit(MinimapLook.border)
            MinimapLook.PlaceHeader()
            PlaceCorners()
        end
    end)
end
