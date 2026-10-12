-- The Combo points module: a bar of segments for a rogue's (or a cat druid's)
-- combo points, drawn without reading the count, and the game's own gems taken
-- off the target frame. One of the castbar group: in the row just above the
-- castbar, at its size, placed and locked with it.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

local function Near(colour, want)
    if type(colour) ~= "table" then return false end
    for i = 1, 3 do
        if type(colour[i]) ~= "number" or math.abs(colour[i] - want[i]) > 0.002 then
            return false
        end
    end
    return true
end

-- How full each segment is drawn: a status bar clamps its value to its range.
local function Fill(segment)
    local value = segment:GetValue()
    if value <= segment.min then return 0 end
    if value >= segment.max then return 1 end
    return value - segment.min
end

local function Filled(segments)
    local out = {}
    for index, segment in ipairs(segments) do
        if segment:IsShown() then out[#out + 1] = Fill(segment) end
    end
    return table.concat(out, ",")
end

units.player.class = "ROGUE"
units.player.powerToken = "ENERGY"

LoadAddon()
Login()

local NS = DogsForeverUI.ComboPoints
local Castbar = DogsForeverUI.Castbar
local Style = DogsForeverUI.Style
local DB = NS.db
local GROUP = Castbar.db
local bar, segments = NS.bar, NS.segments
local castbar = Castbar.CastBar.castbar
local GAP = 6 + 3 + 3

-- At its default spot: the row just above the castbar, centred on it -
-- placed there once (TOPLEFT on the screen).
local function InItsRow()
    local p = bar.points
    return p[1] == "TOPLEFT" and p[2] == UIParent
        and math.abs(p[4] - (GROUP.barLeft + (GROUP.barWidth - DB.barWidth) / 2)) < 1e-6
        and math.abs(p[5] - (GROUP.barTop + GAP + DB.barHeight)) < 1e-6
end

local function SetPoints(points)
    combo.points = points
    Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
end

Section("the bar")
check("a segment per combo point", #segments == 5)
check("each one covering its own point",
    segments[1].min == 0 and segments[1].max == 1 and segments[5].min == 4 and segments[5].max == 5)
check("no switch - always on - and no placement mode of its own",
    DB.enabled == nil and DB.unlocked == nil)
Fire("PLAYER_ENTERING_WORLD")
check("its own size and layer, the castbar's to start",
    bar.width == DB.barWidth and bar.height == DB.barHeight and bar.strata == DB.frameStrata
    and DB.barWidth == GROUP.barWidth)
check("sharing that width with a hairline between each two",
    math.abs(segments[1].width * 5 + 4 - DB.barWidth) < 0.001, segments[1].width)
check("placed once in its row just above the castbar, centred on it: the countdown's, a rogue having no mana",
    DB.placed == true and InItsRow(), tostring(bar.points[2]))
-- Flat colour, shaded only top to bottom: the game's bar art broke up
-- stretched into a short, tall segment.
check("a flat fill in the combo red",
    segments[1]:GetStatusBarTexture().texture == Style.FLAT_TEXTURE
    and Near(segments[1].statusColor, Style.COMBO_COLOR))
do
    local seg = segments[1]
    local sheen, shade, fill = seg.sheen, seg.shade, seg:GetStatusBarTexture()
    check("with a sheen over its top half and a shade over its bottom half",
        sheen ~= nil and shade ~= nil
        and sheen.gradient.orientation == "VERTICAL" and shade.gradient.orientation == "VERTICAL"
        and sheen.gradient.to.a > 0 and sheen.gradient.from.a == 0
        and shade.gradient.from.a > 0 and shade.gradient.to.a == 0)
    check("pinned to the fill, so they cover only what is filled",
        sheen.points[2] == fill and shade.points[2] == fill
        and sheen.points[3] == "RIGHT" and shade.points[3] == "BOTTOMRIGHT")
    local before = sheen
    NS.Refresh()
    check("made once, not again on every layout", seg.sheen == before)
end
check("on the black background, with the border every bar wears",
    bar.bg.colorTexture ~= nil and Near(bar.bg.colorTexture, Style.BACKGROUND_COLOR) and bar.border ~= nil)

Section("points")
check("no points, no bar", bar:IsShown() == false)
SetPoints(1)
check("the first point brings it out", bar:IsShown() == true)
check("with the first segment full and the rest empty", Filled(segments) == "1,0,0,0,0",
    Filled(segments))
SetPoints(3)
check("three points, three segments", Filled(segments) == "1,1,1,0,0", Filled(segments))
SetPoints(5)
check("five, all of them", Filled(segments) == "1,1,1,1,1")
SetPoints(0)
check("spending them fades the bar out", bar:IsShown() == true and bar:GetAlpha() <= 1)
Tick(DogsForeverUI.Style.FADE_OUT + 0.05)
check("and it is gone", bar:IsShown() == false)

-- The count is never read: every segment is simply handed it.
do
    local hidden = Unreadable("the combo points")
    units.target = { name = "Hogger", level = 11, reaction = 1, health = 1, healthMax = 1 }
    combo.points = hidden
    local ok, err = pcall(Fire, "UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
    check("a count the client will not let us read does not throw", ok, err)
    check("it reaches every segment untouched",
        segments[1]:GetValue() == hidden and segments[5]:GetValue() == hidden)
    check("and the bar shows while there is a target to have points on", bar:IsShown())
    units.target = nil
    SetPoints(0)
end

combo.max = 6
Fire("UNIT_MAXPOWER", "player", "COMBO_POINTS")
check("a sixth point from a talent adds a segment", Filled(segments) == "0,0,0,0,0,0"
    or #segments == 6, #segments)
combo.max = 5
Fire("UNIT_MAXPOWER", "player", "COMBO_POINTS")
check("and losing it takes the segment away", Filled(segments) == "0,0,0,0,0", Filled(segments))

Section("who has combo points")
units.player.class = "WARRIOR"
SetPoints(3)
check("a warrior never sees it", bar:IsShown() == false)
units.player.class = "DRUID"
units.player.powerToken = "MANA"
SetPoints(3)
check("nor a druid out of cat form", bar:IsShown() == false)
units.player.powerToken = "ENERGY"
Fire("UPDATE_SHAPESHIFT_FORM")
check("but a druid in cat form does", bar:IsShown() == true)
units.player.class = "ROGUE"
SetPoints(0)

Section("the game's combo points are off the target frame")
ComboFrame:Show()
check("the game showing its gems puts them straight back down", ComboFrame:IsShown() == false)
DogsForeverUI.ComboPoints.Refresh()
ComboFrame:Show()
check("and after a refresh too: they are never the game's again", ComboFrame:IsShown() == false)

Section("placing it, with the castbar")
DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
check("unlocking the castbar shows it as it really looks: every point lit",
    GROUP.unlocked == true and bar:IsShown() and Filled(segments) == "1,1,1,1,1"
    and not PlacingLook(bar.bg), Filled(segments))
check("where it was placed, on the screen - dragging the castbar does not take it along",
    DB.placed == true and bar.points[2] == UIParent)
bar.left, bar.top = 700, 400
bar.scripts.OnMouseUp(bar, "LeftButton")
check("dragging it puts it somewhere of its own", DB.placed == true and DB.barLeft == 700)
check("where it now stays", bar.points[2] == UIParent and bar.points[4] == 700)
DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
check("locking the castbar puts it away", GROUP.unlocked == false and bar:IsShown() == false)

DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
pendingTimer = nil
bar.scripts.OnMouseUp(bar, "RightButton")
check("a right-click on it does nothing: still being placed, still where it was",
    pendingTimer == nil and GROUP.unlocked == true and DB.barLeft == 700)
DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
Fire("PLAYER_ENTERING_WORLD")
check("and a placed bar is never moved again", DB.barLeft == 700)

-- A warrior has no combo points: nothing to place.
units.player.class = "WARRIOR"
DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
check("a warrior has no combo bar to place", bar:IsShown() == false)
DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
units.player.class = "ROGUE"

-- Its size, as its Unlock Mode menu sets it (the options' Sizes rows went
-- there, 2026-10-03).
local Snap = DogsForeverUI.Snap
local comboEntry, castEntry = Snap.EntryById("combo"), Snap.EntryById("castbar")
check("a size of its own in Unlock Mode", Snap.SizeOf(comboEntry, "w") ~= nil and Snap.SizeOf(comboEntry, "h") ~= nil)
Snap.SetSize(comboEntry, "w", 150)
check("its own width, the segments sharing it",
    DB.barWidth == 150 and math.abs(segments[1].width * 5 + 4 - 150) < 0.001)
Snap.SetSize(castEntry, "w", 200)
check("the castbar's width is the castbar's alone", DB.barWidth == 150 and bar.width == 150)
Snap.SetSize(castEntry, "w", 100)
DB.placed, DB.barLeft = true, 500
DogsForeverUI.ComboPoints.Refresh()
check("placed on its own", bar.points[1] == "TOPLEFT" and bar.points[4] == 500)
Snap.SetSize(comboEntry, "w", 100)
check("placed on its own, a new width keeps its centre", DB.barLeft == 525)

DogsForeverUI:Reset("combo")
check("a reset puts it back in its row, wherever that is now (placed there once again)",
    DB.placed == true and InItsRow())

Summary()
