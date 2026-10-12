-- The minimap: square, the frames' border round it, the game's round art
-- faded, corners that ping, and nothing of the game's given a field.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

-- The game's minimap, as Blizzard_Minimap builds it before any addon loads:
-- the map, its ring and the ring under it, and the day/night dial on the
-- cluster. The map starts with the round mask Camelot\Skin.lua gives it.
MinimapCluster = newWidget("Frame", UIParent)
-- The game's Rotate Minimap, as its layout applies it: the CVar, nothing else.
function MinimapCluster:SetRotateMinimap(on) C_CVar.SetCVar("rotateMinimap", on and "1" or "0") end
Minimap = newWidget("Minimap", MinimapCluster)
Minimap:SetSize(198, 198)
Minimap.center = { 1700, 900 }
Minimap.mask = "ui-hud-minimap-frame-generic-mask"
function Minimap:SetMaskTexture(mask) self.mask = mask end
pings = {}
function Minimap:PingLocation(x, y) pings[#pings + 1] = { x, y } end
MinimapCompassTexture = newWidget("Texture", Minimap)
MinimapCompassTextureUnderlay = newWidget("Texture", Minimap)
MinimapCluster:SetFrameLevel(4)
Minimap:SetFrameLevel(6)
-- The header row: the strip everything hangs from, the zone name on it.
MinimapCluster.BorderTop = newWidget("Frame", MinimapCluster)
MinimapCluster.BorderTop:SetSize(175, 16)
MinimapCluster.BorderTop:SetPoint("TOP", MinimapCluster, "TOP", 15, -4)
MinimapCluster.ZoneTextButton = newWidget("Button", MinimapCluster)
MinimapCluster.ZoneTextButton:SetPoint("LEFT", MinimapCluster.BorderTop, "LEFT", 4, 0)
MinimapZoneText = newWidget("FontString", MinimapCluster.ZoneTextButton)
MinimapZoneText:SetWidth(130)
MinimapZoneText:SetPoint("CENTER", MinimapCluster.ZoneTextButton, "CENTER", 0, 1)
MinimapCluster.Tracking = newWidget("Frame", MinimapCluster)
MinimapCluster.Tracking:SetPoint("RIGHT", MinimapCluster.BorderTop, "LEFT", -2, 0)
MinimapCluster.Tracking:SetSize(17, 17)
MinimapCluster.Tracking.Background = newWidget("Texture", MinimapCluster.Tracking)
MinimapCluster.Tracking.Button = newWidget("Button", MinimapCluster.Tracking)
MinimapCluster.Tracking.Button:SetSize(13, 14)
GameTimeFrame = newWidget("Button", MinimapCluster)
GameTimeFrame:SetPoint("TOPLEFT", MinimapCluster.BorderTop, "TOPRIGHT", 1, 0)
GameTimeFrame:SetSize(19, 18)
-- The font object the clock's time inherits.
WhiteNormalNumberFont = {}
-- The calendar's art is set again, by name, each time the date refreshes.
today = 2
C_DateAndTime = C_DateAndTime or {}
function C_DateAndTime.GetCurrentCalendarTime() return { monthDay = today } end
dateSet = 0
function GameTimeFrame_SetDate() dateSet = dateSet + 1 end
-- The clock comes later, with Blizzard_TimeManager.
-- The cluster's rect, as the game sized it round the round frame (a
-- ResizeLayoutFrame, 20 wider than its parts); the map inside it; the Edit
-- Mode box covering the whole cluster, as the template has it.
MinimapCluster.left, MinimapCluster.width, MinimapCluster.top, MinimapCluster.bottom = 1640, 280, 1080, 800
Minimap.left, Minimap.width, Minimap.top, Minimap.bottom = 1670, 198, 1040, 842
MinimapCluster.Selection = newWidget("Frame", MinimapCluster)
MinimapCluster.Selection:SetAllPoints(MinimapCluster)
MinimapCluster.Selection.shown = false
function MinimapCluster:Layout() self.laidOut = (self.laidOut or 0) + 1 end
function MinimapCluster:SetClampRectInsets(l, r, t, b) self.clampInsets = { l, r, t, b } end
function MinimapCluster:SetHitRectInsets(l, r, t, b) self.hitInsets = { l, r, t, b } end
-- The day/night dial (Camelot\Diel.lua), which the game places on its round
-- frame from its SetEditModeScale - adding a point, as it does in game.
MinimapCluster.DielFrame = newWidget("Frame", MinimapCluster)
MinimapCluster.DielFrame:SetFrameLevel(5)
minimapScale = 1
function MinimapCluster:GetEditModeScale() return minimapScale end
function MinimapCluster:SetEditModeScale(scale)
    minimapScale = scale
    self.DielFrame:SetScale(math.max(1, scale))
    self.DielFrame:SetPoint("CENTER", 63 * math.min(1, scale), 72 * math.min(1, scale))
end
-- Edit Mode's "header underneath": the strip back on the game's anchors.
function MinimapCluster:SetHeaderUnderneath(below)
    self.BorderTop:ClearAllPoints()
    if below then
        self.BorderTop:SetPoint("BOTTOM", self, "BOTTOM", 15, 2)
    else
        self.BorderTop:SetPoint("TOP", self, "TOP", 15, -4)
    end
end
-- The mail flag under the tracking button, the difficulty flag under the
-- header's right end.
MinimapCluster.IndicatorFrame = newWidget("Frame", MinimapCluster)
MinimapCluster.IndicatorFrame:SetPoint("TOPRIGHT", MinimapCluster, "TOPLEFT", 0, 0)
MinimapCluster.InstanceDifficulty = newWidget("Frame", MinimapCluster)
MinimapCluster.InstanceDifficulty:SetPoint("TOPRIGHT", MinimapCluster.BorderTop, "TOPRIGHT", 0, -15)
-- Its modes (InstanceDifficulty.xml): each with a banner behind it; the
-- default one and the guild one's Instance row hold the skulls and the count,
-- which their layout frame lays under the skull.
do
    local flag = MinimapCluster.InstanceDifficulty
    local function Holder(parent)
        local h = newWidget("Frame", parent)
        h.DifficultyTextures = {}
        for i, key in ipairs({ "NormalTexture", "HeroicTexture", "MythicTexture" }) do
            local t = h:CreateTexture(nil, "ARTWORK")
            t.shown = (i == 1)
            h[key] = t
            h.DifficultyTextures[i] = t
        end
        h.Text = h:CreateFontString()
        h.Text:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
        function h:Layout()
            local above = self.DifficultyTextures[1]
            for _, t in ipairs(self.DifficultyTextures) do if t.shown then above = t end end
            self.Text:ClearAllPoints()
            self.Text:SetPoint("TOP", above, "BOTTOM", 0, 0)
        end
        return h
    end
    for _, key in ipairs({ "Default", "Guild", "ChallengeMode" }) do
        local mode = key == "Default" and Holder(flag) or newWidget("Frame", flag)
        mode.Background = mode:CreateTexture(nil, "BACKGROUND")
        mode.Border = mode:CreateTexture(nil, "ARTWORK")
        flag[key] = mode
    end
    flag.Guild.Instance = Holder(flag.Guild)
    flag.Default:Layout()
end
-- The children the map holds, as GetChildren gives them.
mapChildren = {}
function Minimap:GetChildren() return unpack(mapChildren) end
-- The group finder's eye (Camelot QueueStatusFrameOverrides.lua): in its
-- default place, pinned to the round map's edge.
eyeDefault = true
QueueStatusButton = newWidget("Button", UIParent)
function QueueStatusButton:IsInDefaultPosition() return eyeDefault end
function QueueStatusButton:UpdateDefaultAnchor()
    if self:IsInDefaultPosition() then
        self:ClearAllPoints()
        self:SetPoint("CENTER", Minimap, "CENTER", -68, -68)
    end
end
-- Edit Mode putting its Size setting on it, through its own SetScale.
function QueueStatusButton:UpdateSystemSettingSize() self:SetScale(1) end
QueueStatusButton:UpdateDefaultAnchor()
-- The copy of that method the game hands the rescale callback at load.
local gameRescale = QueueStatusButton.UpdateDefaultAnchor
-- The coordinates, under the map.
MinimapCluster.MinimapContainer = newWidget("Frame", MinimapCluster)
local coords = newWidget("Frame", MinimapCluster.MinimapContainer)
coords.CoordText = newWidget("FontString", coords)
coords.CoordText:SetFont("Interface\\AddOns\\DogsForeverUI\\Media\\Dog.ttf", 10, "")
coords:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, -18)
MinimapCluster.MinimapContainer.PlayerCoords = coords

-- The game's own event registry, as far as the minimap's rescale goes.
EventRegistry = { callbacks = {} }
function EventRegistry:RegisterCallback(event, func, owner)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], func)
end
function EventRegistry:TriggerEvent(event, ...)
    for _, func in ipairs(self.callbacks[event] or {}) do func(...) end
end

local function Keys(t)
    local keys = {}
    for k in pairs(t) do keys[k] = true end
    return keys
end
EventRegistry:RegisterCallback("Minimap.OnScaleUpdated", function() gameRescale(QueueStatusButton) end)

-- What the game says about widgets and globals, as far as the addon buttons'
-- drawer asks: a widget's type, and which addon made a global (none listed:
-- the game's own, secure).
function Widget:GetObjectType() return self.kind end
function Widget:IsObjectType(kind) return self.kind == kind end
owners = {}
function issecurevariable(name)
    if owners[name] then return false, owners[name] end
    return true
end
UISpecialFrames = {}
-- The game's AddOns button by the map: a menu of the addons that asked for a
-- place in it, shown while there is one (AddonCompartment.lua); and the
-- addons' titles, by name.
AddonCompartmentFrame = CreateFrame("Button", "AddonCompartmentFrame", MinimapCluster)
AddonCompartmentFrame.registeredAddons = {}
function AddonCompartmentFrame:UpdateDisplay() self:SetShown(#self.registeredAddons > 0) end
function AddonCompartmentFrame:RegisterAddon(data)
    table.insert(self.registeredAddons, data)
    self:UpdateDisplay()
end
titles = {}
C_AddOns = C_AddOns or {}
function C_AddOns.DoesAddOnExist(name) return titles[name] ~= nil end
function C_AddOns.GetAddOnTitle(name) return titles[name] end

local before = Keys(Minimap)
local beforeEye = Keys(QueueStatusButton)
local beforeCluster = Keys(MinimapCluster)
local beforeDial = Keys(MinimapCluster.DielFrame)
local beforeCoords = Keys(coords)

LoadAddon()

-- An addon's own minimap button with no LibDBIcon library to place it (the
-- Dungeon Journal's fallback): on a circle 8 out from the map's edge, at an
-- angle, placed again at every step of a drag.
local function Ring(button, degrees)
    local a, r = math.rad(degrees), 99 + 8
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end
local journal = CreateFrame("Button", "LibDBIcon10_ForeverDungeonJournal", Minimap)
mapChildren[#mapChildren + 1] = journal
-- Protected, so the addon buttons' drawer leaves it on the edge (an addon's
-- button normally goes into the drawer: see "addon buttons" below).
journal.protected = true
Ring(journal, 180)
-- A map pin some addon puts on the map: not a button round the edge.
local pin = CreateFrame("Frame", "SomeAddonPin1", Minimap)
mapChildren[#mapChildren + 1] = pin
pin:SetPoint("CENTER", Minimap, "CENTER", -80, 60)

Login()

local NS = DogsForeverUI.Minimap
local Style = DogsForeverUI.Style

Section("square")
check("the round mask swapped for a plain square", Minimap.mask == Style.FLAT_TEXTURE, tostring(Minimap.mask))
check("the game's ring faded", MinimapCompassTexture.alpha == 0)
check("the ring under it (rotating mode) faded", MinimapCompassTextureUnderlay.alpha == 0)
check("the header's bronze strip faded", MinimapCluster.BorderTop.alpha == 0)
check("none of them hidden: shown and hidden by the game alone",
    MinimapCompassTexture.shown and MinimapCompassTextureUnderlay.shown and MinimapCluster.BorderTop.shown)

Section("the frames' border")
check("on a frame of the addon's, a child of the map", NS.frame ~= nil and NS.frame.parent == Minimap)
check("covering the map exactly", NS.frame.allPointsTo == Minimap)
check("drawn over the map", NS.frame:GetFrameLevel() > Minimap:GetFrameLevel())
check("the frames' own border, with its three lines",
    NS.border ~= nil and NS.border.spec == Style.DEFAULT_BORDER and #NS.border.lines == 3)
check("the frame takes no clicks from the map", NS.frame.mouseEnabled == false)
Fire("PLAYER_ENTERING_WORLD")
check("made once, not again", DogsForeverUI.Minimap.frame == NS.frame)
local ok = pcall(EventRegistry.TriggerEvent, EventRegistry, "Minimap.OnScaleUpdated", 1.2)
check("laid out again when Edit Mode rescales the minimap", ok)

Section("the title, on the map")
local band = NS.band
local strip = MinimapCluster.BorderTop
local function Anchor(frame, i) return frame.anchors and frame.anchors[i] or {} end
-- Under the map by default - the addon's own setting (the player, 2026-10-03).
local Game = DogsForeverUI.GameFrames
check("by default the title under the map", Game.db.minimapHeaderBelow == true and NS.HeaderBelow()
    and Anchor(band, 1)[1] == "TOPLEFT" and Anchor(band, 1)[2] == Minimap and Anchor(band, 1)[3] == "BOTTOMLEFT")
-- (Above it from here on, for what follows.)
Game.db.minimapHeaderBelow = false
NS.PlaceHeader()
check("a band of the addon's on the cluster, under the header row",
    band ~= nil and band.parent == MinimapCluster and band:GetFrameLevel() == MinimapCluster:GetFrameLevel())
local out = NS.border.out
local lift = out / 2
local UnitPlate = DogsForeverUI.Frames.UnitPlate
check("sitting right on the map's top edge, exactly the minimap's width: border's outer edge to border's",
    Anchor(band, 1)[1] == "BOTTOMLEFT" and Anchor(band, 1)[2] == Minimap and Anchor(band, 1)[3] == "TOPLEFT"
    and Anchor(band, 2)[1] == "BOTTOMRIGHT" and Anchor(band, 2)[2] == Minimap and Anchor(band, 2)[3] == "TOPRIGHT"
    and Anchor(band, 1)[4] == -out and Anchor(band, 2)[4] == out and Anchor(band, 1)[5] == 0 and out > 0)
check("the player frame's name band height", band.height == UnitPlate.TopRoom() and band.height == 24,
    tostring(band.height))
check("drawing nothing: no background, no line",
    band.fill == nil and band.line == nil and NS.BAND_FADE == nil)
check("takes no clicks", band.mouseEnabled == false)

local function OnLine(frame, relative, point, relativePoint, x, y)
    local a = Anchor(frame, 1)
    return a[1] == point and a[2] == relative and a[3] == relativePoint and a[4] == x and a[5] == y
end
local tracking = MinimapCluster.Tracking
local zone = MinimapCluster.ZoneTextButton
-- The band reaches `out` past the map each side; the row stays PAD in from
-- the map's edge, where it always was.
local inset = NS.PAD + out
check("tracking at the right end, PAD in from the map, on the band's middle clear of the border",
    #tracking.anchors == 1 and OnLine(tracking, band, "RIGHT", "RIGHT", -inset, lift))
check("the calendar just before it, on the same line",
    #GameTimeFrame.anchors == 1 and OnLine(GameTimeFrame, tracking, "RIGHT", "LEFT", -NS.LETTER_GAP, 0))
check("the zone name at the left end, by its middle, up to the calendar",
    #zone.anchors == 2 and OnLine(zone, band, "LEFT", "LEFT", inset, lift)
    and Anchor(zone, 2)[1] == "RIGHT" and Anchor(zone, 2)[2] == GameTimeFrame and Anchor(zone, 2)[5] == 0)
check("its label filling it, with no offset of its own",
    #MinimapZoneText.anchors == 2 and OnLine(MinimapZoneText, zone, "LEFT", "LEFT", 0, 0)
    and Anchor(MinimapZoneText, 2)[1] == "RIGHT" and Anchor(MinimapZoneText, 2)[5] == 0)

-- The clock arrives with Blizzard_TimeManager.
TimeManagerClockButton = newWidget("Button", MinimapCluster)
TimeManagerClockButton:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -4, 0)
TimeManagerClockTicker = newWidget("FontString", TimeManagerClockButton)
TimeManagerClockTicker:SetPoint("CENTER", TimeManagerClockButton, "CENTER", 3, 1)
Fire("ADDON_LOADED", "Blizzard_TimeManager")
check("the clock just before the calendar, on the same line",
    #TimeManagerClockButton.anchors == 1
    and OnLine(TimeManagerClockButton, GameTimeFrame, "RIGHT", "LEFT", -NS.LETTER_GAP, 0))
check("its time against its right edge, with no offset",
    #TimeManagerClockTicker.anchors == 1 and OnLine(TimeManagerClockTicker, TimeManagerClockButton, "RIGHT", "RIGHT", 0, 0))
check("the zone name now stops before the clock",
    Anchor(zone, 2)[2] == TimeManagerClockButton and Anchor(zone, 2)[4] == -NS.GAP)

Section("the header's letters")
local size = NS.ICON_SIZE
local calendarIcon, glass = NS.calendarIcon, NS.trackingIcon
-- The stub measures 6 a character: "2" and "T" are 6 wide.
check("the calendar and tracking buttons ICON_SIZE tall, exactly as wide as their text",
    GameTimeFrame.width == 6 and GameTimeFrame.height == size
    and tracking.width == 6 and tracking.height == size
    and tracking.Button.width == 6 and tracking.Button.height == size)
check("taking clicks HIT_PAD past each side",
    GameTimeFrame.hitInsets[1] == -NS.HIT_PAD and GameTimeFrame.hitInsets[2] == -NS.HIT_PAD
    and tracking.Button.hitInsets[1] == -NS.HIT_PAD)
check("the game's round button behind tracking faded", tracking.Background.alpha == 0)
check("the day of the month on the calendar, centred",
    calendarIcon ~= nil and calendarIcon.parent == GameTimeFrame and calendarIcon.width == 6
    and OnLine(calendarIcon, GameTimeFrame, "CENTER", "CENTER", 0, 0) and calendarIcon.label.text == 2
    and OnLine(calendarIcon.label, calendarIcon, "CENTER", "CENTER", 0, 0))
check("T on tracking, centred",
    glass ~= nil and glass.parent == tracking.Button and glass.label.text == NS.TRACKING_LETTER
    and NS.TRACKING_LETTER == "T" and OnLine(glass, tracking.Button, "CENTER", "CENTER", 0, 0))
local gold = NS.LETTER_COLOR
check("in the clock's own font, the zone name's gold",
    calendarIcon.label.textColor[1] == gold[1] and calendarIcon.label.textColor[2] == gold[2]
    and glass.label.textColor[3] == gold[3]
    and calendarIcon.label.fontObject == WhiteNormalNumberFont and glass.label.fontObject == WhiteNormalNumberFont)
check("plain text: no underline", calendarIcon.underline == nil and glass.underline == nil)
check("both a little dimmed at rest", calendarIcon.alpha == NS.ICON_ALPHA and glass.alpha == NS.ICON_ALPHA
    and NS.ICON_ALPHA < 1)
for _, hook in ipairs(GameTimeFrame.hooks.OnEnter) do hook(GameTimeFrame) end
check("full under the mouse", calendarIcon.alpha == 1)
for _, hook in ipairs(GameTimeFrame.hooks.OnMouseDown) do hook(GameTimeFrame) end
check("a pixel down while pressed", OnLine(calendarIcon, GameTimeFrame, "CENTER", "CENTER", 1, -1))
for _, hook in ipairs(GameTimeFrame.hooks.OnMouseUp) do hook(GameTimeFrame) end
for _, hook in ipairs(GameTimeFrame.hooks.OnLeave) do hook(GameTimeFrame) end
check("and back", calendarIcon.alpha == NS.ICON_ALPHA and OnLine(calendarIcon, GameTimeFrame, "CENTER", "CENTER", 0, 0))
today = 3
GameTimeFrame_SetDate()
check("the day written again after the game refreshes the date", calendarIcon.label.text == 3 and dateSet == 1)
today = 30
GameTimeFrame_SetDate()
check("a two-figure day widens the button to fit, still as tall",
    GameTimeFrame.width == 12 and calendarIcon.width == 12 and GameTimeFrame.height == size)
-- Before the font has measured anything: the square, till placed again.
function glass.label:GetStringWidth() return 0 end
NS.PlaceHeader()
check("a text not yet measured: ICON_SIZE wide", tracking.Button.width == size and tracking.width == size)
glass.label.GetStringWidth = nil
NS.PlaceHeader()
check("measured once the header is placed again", tracking.Button.width == 6 and tracking.width == 6)

Section("Edit Mode's box")
local box = MinimapCluster.Selection
-- Where the band and the map now are: the band on the map's top edge, as
-- wide as the map with its border.
band.left, band.width, band.top, band.bottom = 1670 - out, 198 + 2 * out, 1040 + 24, 1040
NS.FitEditBox()
local pad = NS.EDIT_PADDING
local dl, dr = (1670 - out - pad) - 1640, (1868 + out + pad) - 1920
local dt, db = (1064 + pad) - 1080, (842 - out - pad) - 800
check("2 units round the title and the map with its border, by the cluster's corners",
    #box.anchors == 2 and OnLine(box, MinimapCluster, "TOPLEFT", "TOPLEFT", dl, dt)
    and Anchor(box, 2)[1] == "BOTTOMRIGHT" and Anchor(box, 2)[2] == MinimapCluster
    and Anchor(box, 2)[4] == dr and Anchor(box, 2)[5] == db,
    table.concat(Anchor(box, 1), ",", 4) .. " / " .. table.concat(Anchor(box, 2), ",", 4))
check("the cluster clamped by the same box, as Edit Mode's UpdateClampOffsets would",
    MinimapCluster.clampInsets[1] == dl and MinimapCluster.clampInsets[2] == dr
    and MinimapCluster.clampInsets[3] == dt and MinimapCluster.clampInsets[4] == db)
check("and clickable only there",
    MinimapCluster.hitInsets[1] == dl and MinimapCluster.hitInsets[2] == -dr
    and MinimapCluster.hitInsets[3] == -dt and MinimapCluster.hitInsets[4] == db)
box:ClearAllPoints()
box:SetAllPoints(MinimapCluster)
MinimapCluster:Layout()
check("fitted again after the cluster lays itself out", #box.anchors == 2 and MinimapCluster.laidOut == 1)
box:ClearAllPoints()
for _, hook in ipairs(box.hooks.OnShow or {}) do hook(box) end
check("and when the box shows", #box.anchors == 2 and Anchor(box, 1)[4] == dl)

Section("header below: the addon's own setting, at once")
Game.db.minimapHeaderBelow = true
Game.Refresh()
check("switched on: the band under the map", Anchor(band, 1)[1] == "TOPLEFT" and Anchor(band, 1)[3] == "BOTTOMLEFT")
check("the row in it, on the part the border leaves",
    Anchor(strip, 1)[2] == band and Anchor(strip, 1)[5] == -lift and #strip.anchors == 2
    and OnLine(zone, band, "LEFT", "LEFT", inset, -lift) and OnLine(tracking, band, "RIGHT", "RIGHT", -inset, -lift))
check("still the minimap's width", Anchor(band, 1)[4] == -out and Anchor(band, 2)[4] == out)
MinimapCluster:SetHeaderUnderneath(false)
check("the game's own Header Underneath applied: the row moved back in, the side the addon's",
    Anchor(band, 1)[1] == "TOPLEFT" and Anchor(strip, 1)[2] == band)
Game.db.minimapHeaderBelow = false
Game.Refresh()
check("switched off: back on top", Anchor(band, 1)[1] == "BOTTOMLEFT" and Anchor(strip, 1)[2] == band
    and OnLine(zone, band, "LEFT", "LEFT", inset, lift) and OnLine(tracking, band, "RIGHT", "RIGHT", -inset, lift))
MinimapCluster:SetHeaderUnderneath(true)
check("and the game's own Header Underneath does not take it down", Anchor(band, 1)[1] == "BOTTOMLEFT")

Section("day and night: the game's own dial")
local dial = MinimapCluster.DielFrame
check("shown, at full opacity", dial.shown and dial.alpha == 1)
check("close in the map's top right corner",
    #dial.anchors == 1 and Anchor(dial, 1)[1] == "TOPRIGHT" and Anchor(dial, 1)[2] == Minimap
    and Anchor(dial, 1)[4] == -NS.DIAL_INSET and Anchor(dial, 1)[5] == -NS.DIAL_INSET and NS.DIAL_INSET < 4)
check("a little smaller than the game draws it", dial.scale == NS.DIAL_SCALE and NS.DIAL_SCALE < 1)
check("over the map and its border", dial:GetFrameLevel() > NS.frame:GetFrameLevel() + 5)
MinimapCluster:SetEditModeScale(0.8)
check("moved back after the game places it on its round frame",
    #dial.anchors == 1 and Anchor(dial, 1)[1] == "TOPRIGHT" and Anchor(dial, 1)[2] == Minimap)
check("and sized again from the game's size, never shrunk twice", dial.scale == NS.DIAL_SCALE)
MinimapCluster:SetEditModeScale(1.5)
check("the game's larger size, at the same share", math.abs(dial.scale - 1.5 * NS.DIAL_SCALE) < 1e-9)
MinimapCluster:SetEditModeScale(1)

Section("the coordinates")
check("inside the map, bottom right",
    #coords.anchors == 1 and Anchor(coords, 1)[1] == "BOTTOMRIGHT" and Anchor(coords, 1)[2] == Minimap
    and Anchor(coords, 1)[4] == -NS.COORDS_INSET and Anchor(coords, 1)[5] == NS.COORDS_INSET)
check("right-aligned, over the map", coords.CoordText.justifyH == "RIGHT"
    and coords:GetFrameLevel() > Minimap:GetFrameLevel())

check("a solid black text shadow, not a box behind them",
    coords.CoordText.shadowColor ~= nil and coords.CoordText.shadowColor[1] == 0
    and coords.CoordText.shadowColor[4] == 1 and coords.CoordText.shadowOffset[1] == NS.COORDS_SHADOW.x
    and coords.CoordText.shadowOffset[2] == NS.COORDS_SHADOW.y and NS.coordsBack == nil)
do
    local file, size, flags = coords.CoordText:GetFont()
    check("outlined like every bar's label, in the font and size the game gave them",
        file == "Interface\\AddOns\\DogsForeverUI\\Media\\Dog.ttf" and size == 10 and flags == "OUTLINE")
    Fire("PLAYER_ENTERING_WORLD")
    file, size, flags = coords.CoordText:GetFont()
    check("placed again: outlined once, nothing else changed", size == 10 and flags == "OUTLINE")
end

Section("the mail and difficulty flags")
local mail, difficulty = MinimapCluster.IndicatorFrame, MinimapCluster.InstanceDifficulty
local function Mail()
    return #mail.anchors == 1 and Anchor(mail, 1)[1] == "TOPLEFT" and Anchor(mail, 1)[2] == Minimap
        and Anchor(mail, 1)[3] == "TOPLEFT" and Anchor(mail, 1)[4] == NS.MAIL_INSET
end
local function Difficulty()
    return #difficulty.anchors == 1 and Anchor(difficulty, 1)[1] == "TOPRIGHT"
        and Anchor(difficulty, 1)[2] == MinimapCluster.DielFrame and Anchor(difficulty, 1)[3] == "BOTTOMRIGHT"
end
check("mail in the map's top left corner, the dial's mirror", Mail())
check("difficulty under the dial, not over it", Difficulty())
MinimapCluster:SetHeaderUnderneath(true)
check("still there with the header under the map", Mail() and Difficulty())
MinimapCluster:SetHeaderUnderneath(false)

Section("the difficulty flag")
do
    local flag = MinimapCluster.InstanceDifficulty
    local D = flag.Default
    local function OnSkull(holder, skull)
        local a = Anchor(holder.Text, 1)
        return #holder.Text.anchors == 1 and a[1] == "BOTTOMRIGHT" and a[2] == skull and a[3] == "BOTTOMRIGHT"
            and a[4] == NS.COUNT_OFFSET.x and a[5] == NS.COUNT_OFFSET.y and holder.Text.justifyH == "RIGHT"
    end
    check("no banner behind it, in any of its modes",
        D.Background.alpha == 0 and D.Border.alpha == 0 and flag.Guild.Background.alpha == 0
        and flag.Guild.Border.alpha == 0 and flag.ChallengeMode.Background.alpha == 0
        and flag.ChallengeMode.Border.alpha == 0)
    check("the skull itself left alone", D.NormalTexture.alpha == nil and D.NormalTexture.shown)
    check("the player count on the skull's bottom right corner, like a stack count", OnSkull(D, D.NormalTexture))
    local _, _, flags = D.Text:GetFont()
    check("outlined, as stack counts are", flags == "OUTLINE")
    D.NormalTexture.shown, D.HeroicTexture.shown = false, true
    D:Layout()
    check("the game lays it out again (heroic): back on the corner of the skull shown", OnSkull(D, D.HeroicTexture))
    D.NormalTexture.shown, D.HeroicTexture.shown = true, false
    D:Layout()
    flag.Guild.Instance:Layout()
    check("the guild mode's count on its skull's corner too", OnSkull(flag.Guild.Instance, flag.Guild.Instance.NormalTexture))
end

Section("buttons round the edge")
local function At(frame)
    local p = Anchor(frame, 1)
    return p[1], p[2], p[4], p[5]
end
local function Near(a, b) return math.abs(a - b) < 0.01 end
do
    local point, relative, x, y = At(journal)
    check("an addon's own button: from the circle to the square's edge",
        #journal.anchors == 1 and point == "CENTER" and relative == Minimap and Near(x, -107) and Near(y, 0),
        tostring(x) .. "," .. tostring(y))
end
Ring(journal, 225)
do
    local _, _, x, y = At(journal)
    local want = (math.sqrt(2) * 107 - NS.CORNER) * -math.sqrt(0.5)
    check("dragged to a corner: round the corner, out along its diagonal",
        #journal.anchors == 1 and Near(x, want) and Near(y, want) and math.abs(x) > 99,
        tostring(x) .. "," .. tostring(y))
end
Ring(journal, 90)
do
    local _, _, x, y = At(journal)
    check("dragged to the top: the square's top edge, as far out as the circle had it",
        #journal.anchors == 1 and Near(x, 0) and Near(y, 107))
end
check("a map pin left where its addon put it", Near(Anchor(pin, 1)[4], -80) and Near(Anchor(pin, 1)[5], 60))

local handled
do
    -- One LibDBIcon itself places: it asks the shape, so it is left to it.
    handled = CreateFrame("Button", "LibDBIcon10_Other", Minimap)
    mapChildren[#mapChildren + 1] = handled
    LibStub = setmetatable({}, { __call = function(_, name)
        if name == "LibDBIcon-1.0" then return { objects = { Other = handled } } end
    end })
    handled:SetPoint("CENTER", Minimap, "CENTER", -107, 0.5)
    Fire("PLAYER_ENTERING_WORLD")
    check("a button LibDBIcon places is not projected: it goes into the addon buttons' drawer",
        NS.Buttons.Has(handled) and Anchor(handled, 1)[2] ~= Minimap and #handled.anchors == 1)
    LibStub = nil
end

local eye = QueueStatusButton
-- Its 30-unit picture (half 15) the coordinates' inset in from the corner.
local eyeWant = NS.EYE_INSET + 15
local function InCorner()
    local point, relative, relativePoint, x, y = unpack(Anchor(eye, 1))
    return #eye.anchors == 1 and point == "CENTER" and relative == Minimap
        and relativePoint == "BOTTOMLEFT" and Near(x, eyeWant) and Near(y, eyeWant)
end
check("the group finder's eye: inside the map's bottom left corner, the coordinates' mirror",
    InCorner(), table.concat({ tostring(Anchor(eye, 1)[3]), tostring(Anchor(eye, 1)[4]),
        tostring(Anchor(eye, 1)[5]) }, ","))
check("and smaller than the game draws it", eye.scale == NS.EYE_SCALE and NS.EYE_SCALE < 1, eye.scale)
eye:UpdateDefaultAnchor()
check("again after Edit Mode places it", InCorner())
EventRegistry:TriggerEvent("Minimap.OnScaleUpdated", 1)
check("the game's rescale puts it back on the circle", Near(Anchor(eye, 1)[4], -68))
Tick(0)
check("and it goes to the corner a frame later", InCorner())
eye:UpdateSystemSettingSize()
check("Edit Mode setting its size: made small again", eye.scale == NS.EYE_SCALE, eye.scale)
eyeDefault = false
eye:ClearAllPoints()
eye:SetPoint("CENTER", UIParent, "CENTER", 300, 200)
eye:UpdateDefaultAnchor()
Fire("PLAYER_ENTERING_WORLD")
check("moved in Edit Mode: left where the player put it",
    Anchor(eye, 1)[2] == UIParent and Near(Anchor(eye, 1)[4], 300))
check("at Edit Mode's size again", eye.scale == 1, eye.scale)

Section("rotate minimap switched")
Minimap.mask = "ui-hud-minimap-frame-generic-mask"     -- the game's callback
Fire("CVAR_UPDATE", "rotateMinimap", "1")
check("square again at once", Minimap.mask == Style.FLAT_TEXTURE)
Minimap.mask = "ui-hud-minimap-frame-generic-mask"     -- the game's ran after ours
Tick(0)
check("and again on the next frame, so it stays square whichever ran last", Minimap.mask == Style.FLAT_TEXTURE)
Minimap.mask = "kept"
Fire("CVAR_UPDATE", "cameraDistanceMaxZoomFactor", "2")
check("other settings left alone", Minimap.mask == "kept")
Minimap.mask = Style.FLAT_TEXTURE

Section("a click in the map")
local function Click(x, y)
    pings = {}
    function GetCursorPosition() return x, y end
    for _, hook in ipairs(Minimap.hooks.OnMouseUp or {}) do hook(Minimap, "LeftButton") end
end
check("follows the game's handler rather than replacing it",
    Minimap.scripts.OnMouseUp == nil and #(Minimap.hooks.OnMouseUp or {}) == 1)
Click(1700 + 20, 900 + 20)
check("inside the old circle: the game's own ping, none added", #pings == 0)
Click(1700 + 95, 900 + 95)
check("in a corner: pinged where it was clicked",
    #pings == 1 and pings[1][1] == 95 and pings[1][2] == 95)

Section("the hybrid minimap")
HybridMinimap = newWidget("Frame", Minimap)
HybridMinimap.CircleMask = newWidget("MaskTexture", HybridMinimap)
HybridMinimap.CircleMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
HybridMinimap.CircleMask:SetPoint("TOPLEFT", HybridMinimap, "TOPLEFT", 3, -3)
local hybridKeys = Keys(HybridMinimap)
Fire("ADDON_LOADED", "Blizzard_HybridMinimap")
check("its round mask made the square", HybridMinimap.CircleMask.texture == Style.FLAT_TEXTURE)
check("over the whole map, not three units in", HybridMinimap.CircleMask.allPointsTo == HybridMinimap
    and #HybridMinimap.CircleMask.points == 0)

Section("addon buttons: gathered into a drawer")
local B = NS.Buttons
local Look = DogsForeverUI.Menus.ActionButtons
-- LibDBIcon, with the buttons it made: each with the round backing, the
-- picture, the ring and the round hover glow, on the map's edge.
local lib = { objects = {} }
LibStub = setmetatable({}, { __call = function(_, name)
    if name == "LibDBIcon-1.0" then return lib end
end })
local function LibButton(name, degrees)
    local b = CreateFrame("Button", "LibDBIcon10_" .. name, Minimap)
    mapChildren[#mapChildren + 1] = b
    b:SetSize(31, 31)
    local backing = b:CreateTexture(nil, "BACKGROUND")
    backing:SetTexture(136467)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    icon:SetSize(18, 18)
    b.icon = icon
    local ring = b:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetTexture(136477)
    function b:GetHighlightTexture() return glow end
    b.parts = { backing = backing, icon = icon, ring = ring, glow = glow }
    lib.objects[name] = b
    Ring(b, degrees or 200)
    return b
end
local alpha = LibButton("Alpha", 200)
local zeta = LibButton("Zeta", 160)
-- LibDBIcon crops its pictures itself.
function zeta.icon:UpdateCoord() end
-- An addon's own button, not LibDBIcon's: its picture its normal texture.
local function Edge(name, kind, size, x, y)
    local f = CreateFrame(kind, name, Minimap)
    mapChildren[#mapChildren + 1] = f
    f:SetSize(size, size)
    f.center = { 1700 + x, 900 + y }
    return f
end
owners.SomeAddonMinimapButton = "SomeAddon"
local custom = Edge("SomeAddonMinimapButton", "Button", 32, -107, 0)
local picture = custom:CreateTexture(nil, "ARTWORK")
picture:SetTexture("Interface\\AddOns\\SomeAddon\\icon")
function custom:GetNormalTexture() return picture end
-- What is not an addon's minimap button.
owners.SomeAddonInside, owners.SomeAddonPin2, owners.SomeAddonDecor = "SomeAddon", "SomeAddon", "SomeAddon"
owners.MineOnTheEdge = "DogsForeverUI"
local inside = Edge("SomeAddonInside", "Button", 32, 20, 10)
local pin2 = Edge("SomeAddonPin2", "Button", 16, 0, 105)
local decor = Edge("SomeAddonDecor", "Frame", 32, 0, -105)
local game = Edge("MiniMapGameButton", "Button", 32, 105, 0)
local mine = Edge("MineOnTheEdge", "Button", 32, 105, 20)
Fire("PLAYER_ENTERING_WORLD")

check("LibDBIcon's buttons, an addon's own and its look-alike taken in",
    B.Has(alpha) and B.Has(zeta) and B.Has(custom) and B.Has(handled))
check("not a button inside the map, a map pin, a plain frame, the game's own or this addon's",
    not (B.Has(inside) or B.Has(pin2) or B.Has(decor) or B.Has(game) or B.Has(mine)))
check("nor a protected one", not B.Has(journal))
do
    local names = {}
    for _, entry in ipairs(B.list) do names[#names + 1] = entry.name end
    check("in name order, LibDBIcon's prefix left off", table.concat(names, ",") == "alpha,other,someaddonminimapbutton,zeta",
        table.concat(names, ","))
end
local function Slot(button)
    for _, entry in ipairs(B.list) do if entry.button == button then return entry.slot end end
end
local function InSlot(button)
    local slot = Slot(button)
    return slot ~= nil and button.parent == slot and #button.anchors == 1
        and OnLine(button, slot, "CENTER", "CENTER", 0, 0)
end
check("each centred in a slot of its own", InSlot(alpha) and InSlot(zeta) and InSlot(custom) and InSlot(handled))
local inner = B.SLOT - 2 * B.INSET
check("sized to the slot's inside, at its own scale",
    alpha.width == inner and alpha.height == inner and alpha.scale == 1)
check("drawn over the drawer", alpha.strata == B.STRATA and alpha:GetFrameLevel() > Slot(alpha):GetFrameLevel())
check("the round backing and ring faded", alpha.parts.backing.alpha == 0 and alpha.parts.ring.alpha == 0)
check("the picture square, filling the button, cropped like an action button's",
    alpha.parts.icon.alpha ~= 0 and alpha.parts.icon.allPointsTo == alpha
    and alpha.parts.icon.texCoord[1] == Look.ICON_CROP)
check("LibDBIcon's own crop left to it", zeta.parts.icon.texCoord == nil)
check("the round glow made the action buttons' flat light",
    alpha.parts.glow.texture == Style.FLAT_TEXTURE and alpha.parts.glow.blendMode == "ADD"
    and alpha.parts.glow.vertexColor[4] == Look.HOVER[4] and alpha.parts.glow.allPointsTo == alpha)
check("an addon's own button: its normal texture is its picture", picture.allPointsTo == custom
    and picture.texCoord[1] == Look.ICON_CROP)
check("each slot an action button's: the thin bevelled border, the dark square",
    B.list[1].border.spec == Look.BORDER and B.list[1].inner ~= nil)

local drawer, handle = B.drawer, B.handle
check("collapsed to begin with: the buttons not drawn", not drawer:IsShown() and not alpha:IsVisible())
check("the drawer in the map's border, Esc closes it",
    B.border.spec == Style.DEFAULT_BORDER and UISpecialFrames[#UISpecialFrames] == B.NAME)
check("the title's row untouched: the zone name still at its left end, tracking at its right",
    OnLine(zone, band, "LEFT", "LEFT", inset, lift) and OnLine(tracking, band, "RIGHT", "RIGHT", -inset, lift))

local mapOut, handleOut, dOut = NS.border.out, 0, B.border.out
local fromMap = mapOut + B.HANDLE_GAP + handleOut
local fromHandle = handleOut + B.GAP + dOut
check("a handle outside the map's bottom corner, its foot on the border's foot, towards the screen's middle, the buff toggle's size",
    handle:IsShown() and handle.width == 15 and handle.height == 30 and #handle.anchors == 1
    and OnLine(handle, Minimap, "BOTTOMRIGHT", "BOTTOMLEFT", -fromMap, -mapOut))
local arrow, glow = handle.arrows[1], handle.glow
check("the game's own collapse arrow, at its size, no box and no border",
    arrow.atlas == "bag-arrow" and arrow.width == 10 and arrow.height == 16
    and handle.border == nil and #handle.regions == 2)
check("shut: it points out, to where the drawer opens (the atlas points left as drawn)",
    arrow.rotation == 0 and handle.pointsLeft == true)
check("its light off", not glow.shown)
check("the drawer out of the handle, GAP between their borders, their feet on one line, growing up",
    #drawer.anchors == 1 and OnLine(drawer, handle, "BOTTOMRIGHT", "BOTTOMLEFT", -fromHandle, dOut))

local SLOT, PAD = B.SLOT, B.PAD
check("one row: the drawer sized round four slots",
    drawer.width == 2 * PAD + 4 * SLOT and drawer.height == 2 * PAD + SLOT)
check("the slots left to right from its top left",
    OnLine(Slot(alpha), drawer, "TOPLEFT", "TOPLEFT", PAD, -PAD)
    and OnLine(Slot(zeta), drawer, "TOPLEFT", "TOPLEFT", PAD + 3 * SLOT, -PAD))

handle.scripts.OnEnter(handle)
check("under the mouse: the same arrow added over it, as the game's", glow.shown and glow.atlas == "bag-arrow"
    and glow.blendMode == "ADD" and glow.alpha == 0.4 and glow.rotation == arrow.rotation)
handle.scripts.OnMouseDown(handle)
check("pressed: nudged", Anchor(arrow, 1)[4] == B.PUSHED_OFFSET and Anchor(arrow, 1)[5] == -B.PUSHED_OFFSET)
handle.scripts.OnMouseUp(handle)
check("let go: back", Anchor(arrow, 1)[4] == 0)
handle.scripts.OnLeave(handle)
handle:Click()
Tick(1)
check("a click opens it", B.IsOpen() and drawer:IsShown() and drawer.alpha == 1 and alpha:IsVisible())
check("open: it points back in", math.abs(arrow.rotation - math.pi) < 1e-9 and handle.pointsLeft == false)

MinimapCluster:SetHeaderUnderneath(true)
check("the title under the map: handle and drawer stay where they were",
    OnLine(handle, Minimap, "BOTTOMRIGHT", "BOTTOMLEFT", -fromMap, -mapOut) and OnLine(drawer, handle, "BOTTOMRIGHT", "BOTTOMLEFT", -fromHandle, dOut))
MinimapCluster:SetHeaderUnderneath(false)

Ring(alpha, 45)
check("its addon placing it on the edge again: back in its slot at once", InSlot(alpha))
alpha:SetParent(Minimap)
check("or giving it back to the map", InSlot(alpha))
NS.SquareButton(alpha)
check("never pushed to the square's edge", InSlot(alpha))

alpha:Hide()
check("hidden by its addon: out of the drawer, the rest closing up", not Slot(alpha).shown
    and drawer.width == 2 * PAD + 3 * SLOT and OnLine(Slot(handled), drawer, "TOPLEFT", "TOPLEFT", PAD, -PAD))
alpha:Show()
check("shown again: back", Slot(alpha).shown and drawer.width == 2 * PAD + 4 * SLOT)

mouseOver = { [drawer] = true }
drawer.scripts.OnEvent(drawer, "GLOBAL_MOUSE_DOWN", "LeftButton")
check("a click inside leaves it open", B.IsOpen())
mouseOver = {}
drawer.scripts.OnEvent(drawer, "GLOBAL_MOUSE_DOWN", "LeftButton")
Tick(1)
check("a click anywhere else closes it", not B.IsOpen() and not drawer:IsShown())
check("shut again: pointing out", arrow.rotation == 0)
handle:Click()
handle:Click()
Tick(1)
check("a second click on the handle closes it", not B.IsOpen() and not drawer:IsShown())
handle:Click()
Tick(1)
drawer:Hide()
drawer.scripts.OnHide(drawer)
check("Esc closes it", not B.IsOpen())

UIParent.width = 3840
B.Open()
check("the map on the screen's left half: handle and drawer on its right",
    OnLine(handle, Minimap, "BOTTOMLEFT", "BOTTOMRIGHT", fromMap, -mapOut) and OnLine(drawer, handle, "BOTTOMLEFT", "BOTTOMRIGHT", fromHandle, dOut))
check("open on the right: the arrow points back left", arrow.rotation == 0 and handle.pointsLeft == true)
B.Close(true)
check("shut on the right: it points out, right", math.abs(arrow.rotation - math.pi) < 1e-9)
B.Open()
UIParent.width = 0
Fire("DISPLAY_SIZE_CHANGED")
Tick(B.SCAN)
check("moved back to the right half: on its left again within a look",
    OnLine(handle, Minimap, "BOTTOMRIGHT", "BOTTOMLEFT", -fromMap, -mapOut))
B.Close(true)

for _, button in ipairs({ alpha, zeta, custom, handled }) do button:Hide() end
check("every addon button hidden: no handle", not handle:IsShown())
B.Open()
check("and nothing to open", not B.IsOpen())
for _, button in ipairs({ alpha, zeta, custom, handled }) do button:Show() end
check("one shown again: the handle back", handle:IsShown())

local beta = LibButton("Beta", 300)
Tick(B.SCAN)
check("a button made later is taken in on the next look", B.Has(beta) and InSlot(beta)
    and B.list[2].button == beta)

Section("addon buttons: the game's AddOns menu")
local compartment = AddonCompartmentFrame
local function Parked() return compartment:GetParent() ~= MinimapCluster and not compartment:IsVisible() end
-- The drawer's button for an entry of the game's menu, if it is shown.
local function Made(text)
    for _, entry in ipairs(B.list) do
        if entry.name == text:lower() and entry.button:IsShown() then return entry.button end
    end
end
local count = #B.list
-- An addon with its own edge button and, by its TOC, an entry in the game's menu.
titles.LfgAddon = "LFG Addon"
owners.LfgAddonMinimapButton = "LfgAddon"
local lfg = Edge("LfgAddonMinimapButton", "Button", 32, 0, 107)
Fire("ADDON_LOADED", "LfgAddon")
Tick(B.SCAN)
compartment:RegisterAddon({ text = "LFG Addon" })
check("an entry whose addon's button is in the drawer: that button, nothing more, the game's button put away",
    B.Has(lfg) and #B.list == count + 1 and Parked())
beta.compartmentData = { text = "Beta" }
compartment:RegisterAddon(beta.compartmentData)
check("LibDBIcon's entry for a button in the drawer: nothing more", #B.list == count + 1 and Parked())
-- An addon in the menu alone, with no edge button (TomTom-Paste).
local clicked
compartment:RegisterAddon({ text = "Menu Only", icon = "Interface\\Icons\\menu",
    func = function(_, input, menu) clicked = { input.buttonName, menu } end })
local own = Made("Menu Only")
check("an addon in the menu alone: a button of its own in the drawer, its picture in it, the game's still put away",
    own ~= nil and InSlot(own) and own.icon.texture == "Interface\\Icons\\menu" and Parked())
own.scripts.OnClick(own, "RightButton")
check("a click on it does what the menu's entry does", clicked and clicked[1] == "RightButton" and clicked[2] == own)
-- LibDBIcon's entry for a data object with no button: its hover reads the
-- object's name from the entry handed with it.
local hovered = {}
compartment:RegisterAddon({ text = "Paste",
    funcOnEnter = function(_, menu) hovered[#hovered + 1] = menu.text end,
    funcOnLeave = function(_, menu) hovered[#hovered + 1] = menu.text end })
local paste = Made("Paste")
paste.scripts.OnEnter(paste)
paste.scripts.OnLeave(paste)
check("its hover handed the entry, as the game's menu hands it", hovered[1] == "Paste" and hovered[2] == "Paste")
lfg:Hide()
check("an addon hiding its edge button: its entry gets a button in the drawer instead", Made("LFG Addon") ~= nil and Parked())
lfg:Show()
check("shown again: that one goes", Made("LFG Addon") == nil)
LibStub = nil

Section("other addons asking")
check("GetMinimapShape says square", GetMinimapShape() == "SQUARE")

Section("nothing written into the game's tables")
do
    local function Added(t, was, allowed)
        local added = {}
        for k in pairs(Keys(t)) do
            if not was[k] and not (allowed and allowed[k]) then added[#added + 1] = tostring(k) end
        end
        return added
    end
    -- mask/center are this stub's own bookkeeping.
    local onMap = Added(Minimap, before, { mask = true })
    check("no field added to the minimap", #onMap == 0, table.concat(onMap, ", "))
    -- clampInsets/hitInsets/laidOut: where this stub's methods keep what they were given.
    -- (Not Edit Mode's isLocked/defaultHideSelection either, since 2026-10-03:
    -- written by the addon, they tainted the game's Edit Mode.)
    local onCluster = Added(MinimapCluster, beforeCluster, { clampInsets = true, hitInsets = true, laidOut = true })
    check("no field added to the cluster", #onCluster == 0, table.concat(onCluster, ", "))
    -- Where this stub keeps a widget's anchors, alpha and level.
    local stub = { anchors = true, alpha = true, frameLevel = true, points = true, scale = true }
    local onDial = Added(MinimapCluster.DielFrame, beforeDial, stub)
    check("no field added to the dial", #onDial == 0, table.concat(onDial, ", "))
    local onCoords = Added(coords, beforeCoords, stub)
    check("no field added to the coordinates", #onCoords == 0, table.concat(onCoords, ", "))
    local onEye = Added(QueueStatusButton, beforeEye, stub)
    check("no field added to the eye", #onEye == 0, table.concat(onEye, ", "))
    local onHybrid = Added(HybridMinimap, hybridKeys)
    check("no field added to the hybrid minimap", #onHybrid == 0, table.concat(onHybrid, ", "))
end

Section("rotate minimap: the addon's own setting")
do
    local Core = DogsForeverUI
    local GF = Core.GameFrames
    -- ROTATE MINIMAP: the addon's own, at once - no reload (the player,
    -- 2026-10-03: "why do I need reload for rotate minimap?").
    GF.Ready()
    check("off by default, as the game's is", GF.db.minimapRotate == false and C_CVar.GetCVar("rotateMinimap") == "0")
    local reloads = ReloadCount
    GF.db.minimapRotate = true
    GF.Refresh()
    check("switched on: the minimap turns at once - the game's own rotateMinimap, no reload",
        C_CVar.GetCVar("rotateMinimap") == "1" and ReloadCount == reloads)
    MinimapCluster:SetRotateMinimap(false)
    check("the game's layout setting its own over it: the addon's put straight back",
        C_CVar.GetCVar("rotateMinimap") == "1")
    GF.db.minimapRotate = false
    inCombat = true
    GF.Refresh()
    check("never in combat", C_CVar.GetCVar("rotateMinimap") == "1")
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    check("but as it ends", C_CVar.GetCVar("rotateMinimap") == "0")

    -- Both put back by a reset.
    GF.db.minimapHeaderBelow, GF.db.minimapRotate = false, true
    GF.Refresh()
    Core:ResetAll()
    check("Reset everything: the title under the map again, the minimap not turning",
        GF.db.minimapHeaderBelow == true and NS.band.anchors[1][1] == "TOPLEFT"
        and GF.db.minimapRotate == false and C_CVar.GetCVar("rotateMinimap") == "0")
end

Summary()
