-- The bags' Clean Up button: the game's lies under Camelot's gamepad bag bar,
-- so ours sits over it, in its art, and does what it does - the server's sort.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

SOUNDKIT = { UI_BAG_SORTING_01 = 1 }
sounds = {}
function PlaySound(id) sounds[#sounds + 1] = id end
local sorts = 0
function C_Container.SortBags() sorts = sorts + 1 end
BAG_CLEANUP_BAGS, BAG_CLEANUP_BAGS_DESCRIPTION = "Clean Up Bags", "Sorts the bags."
HIGHLIGHT_FONT_COLOR = {}
function GameTooltip_SetTitle(tip, text) tip.title = text end
function GameTooltip_AddNormalLine() end
function GameTooltip_Hide() GameTooltip:Hide() end
function Widget:SetNormalAtlas(atlas) self.normalAtlas = atlas end
function Widget:SetPushedAtlas(atlas) self.pushedAtlas = atlas end

-- The game's own button, as its XML builds it.
local gameButton = CreateFrame("Button", "BagItemAutoSortButton", UIParent)
gameButton:SetFrameLevel(5)

LoadAddon()
Login()

local button = DogsForeverUI.Menus.BagSort.button

Section("the Clean Up button")
check("ours, over the game's in its art", button and button.parent == gameButton
    and button.allPointsTo == gameButton and button.normalAtlas == "bags-button-autosort-up")
button.scripts.OnShow(button)
check("raised over the gamepad bag bar that covers the game's", button:GetFrameLevel() > gameButton:GetFrameLevel() + 50)
check("the game's button left as it is", gameButton.scripts.OnClick == nil)
button.scripts.OnClick(button, "LeftButton")
check("a click: the game's own sort, instant, with its sound", sorts == 1 and sounds[#sounds] == 1)
button.scripts.OnEnter(button)
check("its tooltip the game's", GameTooltip.title == "Clean Up Bags")

Summary()
