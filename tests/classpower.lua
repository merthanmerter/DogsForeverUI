-- The class resource (ActionBars\GameFrames.lua): the game's own frame for a class's points -
-- a death knight's runes here - centred on a piece of the addon's, on the secondary power's
-- spot to start, movable in Unlock Mode; put back each time the game's managed layout takes it.
local ADDON_PATH, TOC_TEXT = ...
WOW_PROJECT_ID = 1
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)
AssistedCombatManager = { SetAssistedHighlightFrameShown = function() end }
units.player.class = "DEATHKNIGHT"

-- The game's player frame's bottom managed container and the rune frame it manages: on every
-- show the frame goes back into it (ManagedFrameMixin:OnShow -> AddManagedFrame -> UpdateFrame),
-- and again as the UI shows after Alt-Z (UpdateManagedFrames -> UpdateFrame), with no show.
local home = CreateFrame("Frame", "PlayerBottomManagedFrameContainer", UIParent)
function home:UpdateFrame(frame)
    frame:ClearAllPoints()
    frame:SetParent(self)
end
local runes = CreateFrame("Frame", "RuneFrame", home)
runes.layoutParent = home
runes:SetSize(160, 24)
runes:SetScript("OnShow", function(self) self.layoutParent:UpdateFrame(self) end)

LoadAddon()
Login()

local Core = DogsForeverUI
local Game = Core.GameFrames
local Snap = Core.Snap
local place = Game.places.classpower

local function Near(a, b) return a and b and math.abs(a - b) < 0.001 end
local function OnPlace()
    return runes:GetParent() == place and runes.points[1] == "CENTER" and runes.points[2] == place
end

Section("the runes on a piece of their own")
do
    local entry = Snap.EntryById("classpower")
    check("a piece in Unlock Mode, named for what it is",
        place ~= nil and entry ~= nil and Snap.NameOf(entry) == "Class Resource")
    check("the game's frame on it, centred", OnPlace())
    check("the piece the frame's size", place.width == 160 and place.height == 24)
    check("no field written on the game's frame", rawget(runes, "ignoreFramePositionManager") == nil)
end

Section("taken back by the game's managed layout: put back at once")
do
    runes:Hide()
    runes:Show()
    check("on a show", OnPlace())
    home:UpdateFrame(runes)
    check("as the UI shows again (no show of its own)", OnPlace())
end

Section("its first place: the secondary power's spot")
do
    Game.PlaceClassPower()
    local castbar, row = Core.Castbar, Core.FiveSecondRule
    local left, width, top = castbar.RowPlace(row)
    check("its middle on the secondary power bar's middle",
        Near(Game.db.classpowerLeft + 80, left + width / 2)
        and Near(Game.db.classpowerTop - 12, top - row.db.barHeight / 2) and Game.db.classpowerPlaced == true,
        tostring(Game.db.classpowerLeft) .. "," .. tostring(Game.db.classpowerTop))
    check("in the default layout, so Reset Position puts it back there",
        Core.DefaultPlaces.Place("classpower") == true)
end

Summary()
