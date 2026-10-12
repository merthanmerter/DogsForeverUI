-- Loot rolls: the game's roll windows moved to the addon's holder, exactly in
-- the middle of the screen by default, placed with the rest of the UI.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

-- The game's container and windows (Mainline GroupLootFrame.lua/.xml), with
-- its own layout: each window centred on the container's bottom edge,
-- reservedSize apart.
GroupLootContainer = newWidget("Frame", UIParent)
GroupLootContainer.rollFrames, GroupLootContainer.maxIndex = {}, 0
GroupLootContainer.reservedSize = 100
for i = 1, 4 do
    local frame = newWidget("Frame", UIParent)
    frame.name = "GroupLootFrame" .. i
    frame:SetSize(277, 67)
    frame.shown = false
    _G[frame.name] = frame
end
function GroupLootContainer_Update(self)
    for i = 1, self.maxIndex do
        local frame = self.rollFrames[i]
        if frame then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", self, "BOTTOM", 0, self.reservedSize * (i - 1 + 0.5))
        end
    end
end
local function Roll(i)
    GroupLootContainer.rollFrames[i] = _G["GroupLootFrame" .. i]
    GroupLootContainer.maxIndex = math.max(GroupLootContainer.maxIndex, i)
    GroupLootContainer_Update(GroupLootContainer)
end

GetScreenWidth = function() return 2133.3333 end
GetScreenHeight = function() return 1200 end
LoadAddon()
Login()

local NS = DogsForeverUI.LootRolls
local DB = NS.db
local holder = NS.holder

Section("the default place")
do
    check("the holder is a roll window's size", holder.width == 277 and holder.height == 67)
    local centreX = DB.barLeft + 277 / 2
    local centreY = DB.barTop - 67 / 2
    check("its centre exactly the screen's, across",
        math.abs(centreX - 2133.3333 / 2) < 1e-9, centreX)
    check("and down", math.abs(centreY - -600) < 1e-9, centreY)
    check("placed there", holder.points[1] == "TOPLEFT" and holder.points[4] == DB.barLeft
        and holder.points[5] == DB.barTop)
    check("hidden while locked", holder:IsShown() == false)
end

Section("the game's rolls go to it")
do
    Roll(1)
    Roll(2)
    local one, two = GroupLootFrame1.points, GroupLootFrame2.points
    check("the first roll centred on it, so on the screen's centre",
        one[1] == "CENTER" and one[2] == holder and one[3] == "CENTER" and one[4] == 0 and one[5] == 0)
    check("the next stacked above, the game's distance apart",
        two[2] == holder and two[5] == 100)
    check("one anchor each", GroupLootFrame1:GetNumPoints() == 1)
    inCombat = true
    Roll(3)
    check("in combat too, nothing refused",
        GroupLootFrame3.points[2] == holder and #blocked == 0)
    inCombat = false
end

Section("placing it")
do
    DogsForeverUI.SetUnlocked(true)
    check("unlocking shows it in the frames' look, standing in for a roll window",
        holder:IsShown() and holder.mouseEnabled == true
        and holder.bg.colorTexture[4] == DogsForeverUI.Style.BACKGROUND_COLOR[4]
        and holder.border ~= nil and not PlacingLook(holder.bg))
    holder.left, holder.top = 100, 1200 - 200
    holder.scripts.OnMouseDown(holder, "LeftButton")
    holder.scripts.OnMouseUp(holder, "LeftButton")
    check("a drag is saved as the player's",
        DB.barLeft == 100 and DB.barTop == -200 and DB.autoPlaced == false)
    pendingTimer = nil
    holder.scripts.OnMouseUp(holder, "RightButton")
    check("a right-click does nothing: still unlocked", DB.unlocked == true and pendingTimer == nil)
    DogsForeverUI.SetUnlocked(false)
    check("locked, the holder goes", DB.unlocked == false and holder:IsShown() == false)
    check("the rolls follow", GroupLootFrame1.points[2] == holder)
    Fire("PLAYER_ENTERING_WORLD")
    check("and a placed holder is not re-centred", DB.barLeft == 100)
end

Section("reset")
do
    DogsForeverUI:ResetAll()
    check("back in the exact centre",
        math.abs(DB.barLeft + 277 / 2 - 2133.3333 / 2) < 1e-9
        and math.abs(DB.barTop - 67 / 2 - -600) < 1e-9 and DB.autoPlaced == true)
end

Summary()
