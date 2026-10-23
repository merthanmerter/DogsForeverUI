-- Loot toasts: a toast for each item looted and roll won, money added up, the
-- game's roll-won alert off.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

-- The items the client has cached: link -> name, quality, icon, sell price,
-- stack size; and how many the bags hold.
local CLOTH = "|cffffffff|Hitem:2589::::::::|h[Linen Cloth]|h|r"
local SWORD = "|cff0070dd|Hitem:2000::::::::|h[Archeus]|h|r"
local cached = {
    [CLOTH] = { "Linen Cloth", 1, 132889, 13, 20 },
    [SWORD] = { "Archeus", 3, 135349, 2500, 1 },
}
C_Item.GetItemInfo = function(link)
    local item = cached[link]
    if item then return item[1], link, item[2], nil, nil, nil, nil, item[5], nil, item[3], item[4] end
end
local inBags = { [CLOTH] = 7 }
C_Item.GetItemCount = function(link) return inBags[link] or 0 end
local loading = {}
Item = { CreateFromItemLink = function(_, link)
    return { ContinueOnItemLoad = function(_, callback) loading[link] = callback end }
end }
SOUNDKIT = { UI_EPICLOOT_TOAST = 31578 }
played = {}
function PlaySound(kit) played[#played + 1] = kit end
function GameTooltip:SetHyperlink(link) self.link = link end

LoadAddon()
Login()

local NS = DogsForeverUI.LootToasts
local DB, holder, active = NS.db, NS.holder, NS.active
local function Looted(link, count)
    Fire("CHAT_MSG_LOOT", count and ("You receive loot: " .. link .. "x" .. count .. ".")
        or ("You receive loot: " .. link .. "."))
end
local function Wait(seconds) for _ = 1, seconds * 10 do Tick(0.1) end end

Section("the game's roll-won alert")
check("switched off", AlertFrame.events.LOOT_ITEM_ROLL_WON == nil)

Section("an item looted")
Looted(CLOTH)
local first = active[1]
check("a toast at once, nothing waited for", #active == 1 and first:IsShown())
check("its icon cut round in the game's ring",
    first.icon.texture == 132889 and first.icon.mask.atlas == "CircleMask"
    and first.ring.texture == "Interface\\Minimap\\MiniMap-TrackingBorder")
check("rows: its name in its quality's colour with how many the bags hold in grey, what it sells for",
    first.text:GetText() == "|cffffffffLinen Cloth|r |cff999999(7)|r\ncoins:13", first.text:GetText())
inBags[CLOTH] = 8
Fire("BAG_UPDATE_DELAYED")
check("counted again as the bags change", first.text:GetText():find("(8)", 1, true))
check("on the holder, as wide and high as set",
    first.points[2] == holder and first.width == DB.barWidth and first.height == DB.barHeight)
check("the ring as LibDBIcon's: 50 for a 31 button, the icon 24 in its middle",
    first.ring.width == DB.barHeight * (50 / 31) and first.icon.width == DB.barHeight * (24 / 31))
check("the text a left block right against the piece, wrapping in the rest of the width",
    first.text.justifyH == "LEFT" and first.text.points[4] == DB.barHeight
    and first.text.width == DB.barWidth - DB.barHeight and first.text.wordWrap ~= false)
check("no roll row", not first.text:GetText():find("You Won!"))
Looted(CLOTH, 2)
check("the same item again: added to its toast", #active == 1
    and first.text:GetText() == "|cffffffffLinen Cloth x3|r |cff999999(8)|r\ncoins:39", first.text:GetText())

Section("stacked upwards")
Looted(SWORD)
local sword = active[1]
check("the newest on the holder, the one before above it",
    sword.points[1] == "BOTTOMLEFT" and sword.points[2] == holder
    and first.points[1] == "BOTTOMLEFT" and first.points[2] == sword and first.points[3] == "TOPLEFT")
DB.growDirection = "down"
NS.Refresh()
check("or downwards", sword.points[1] == "TOPLEFT" and first.points[2] == sword and first.points[3] == "BOTTOMLEFT")
DB.growDirection = "up"
NS.Refresh()

Section("gone after a while, held under the mouse")
first.scripts.OnEnter(first)
Wait(6)
check("the hovered one stays, the other fades and is put away",
    first:IsShown() and #active == 1 and active[1] == first)
check("its tooltip", GameTooltip.link == CLOTH)
first.scripts.OnLeave(first)
Wait(6)
check("let go of: gone too", #active == 0 and not first:IsShown())

Section("a roll won")
Fire("LOOT_ITEM_ROLL_WON", SWORD, 1, 1, 87, false)
Looted(SWORD)
local won = active[1]
check("one toast for the roll and its loot line; not stackable, no count",
    #active == 1 and won.text:GetText():find("^|cff0070deArcheus|r\ncoins:2500\n"), won.text:GetText())
-- (The player, 2026-10-22: twice as large was a little much.)
local wonSize = math.floor(1.6 * DB.barHeight + 0.5)
check("1.6 times as large", won.height == wonSize and won.icon.width == wonSize * (24 / 31)
    and won.text.points[4] == wonSize and won.text.width == DB.barWidth - wonSize)
check("a row more: You Won! and the need roll",
    won.text:GetText():find("\n|cff%x+You Won!|r |T[^|]*Dice[^|]*|t 87$"), won.text:GetText())
check("the game's sound", played[#played] == SOUNDKIT.UI_EPICLOOT_TOAST)
Wait(6)
Looted(SWORD)
Fire("LOOT_ITEM_ROLL_WON", SWORD, 1, 2, 42, false)
check("its loot line first: the same one toast", #active == 1 and active[1].text:GetText():find(" 42$"))
Wait(6)

Section("money")
Fire("CHAT_MSG_MONEY", "You loot 1 Gold, 2 Silver, 3 Copper")
Fire("CHAT_MSG_MONEY", "You loot 5 Copper")
check("added up on one toast, Money in gold", #active == 1
    and active[1].text:GetText():find("^|cff%x+Money|r\ncoins:10208$"), active[1].text:GetText())
check("a toast handed back from the won roll: its usual size again",
    active[1].height == DB.barHeight and active[1].icon.width == DB.barHeight * (24 / 31))
Wait(6)

Section("never more than five")
for i = 1, 7 do
    local link = "|cffffffff|Hitem:" .. i .. "::::::::|h[Item " .. i .. "]|h|r"
    cached[link] = { "Item " .. i, 1, 1, 0, 1 }
    Looted(link)
end
check("the oldest put away", #active == 5 and active[1].text:GetText() == "|cffffffffItem 7|r")
Wait(6)

Section("not cached, secret")
local NEW = "|cffffffff|Hitem:3000::::::::|h[Fresh]|h|r"
Looted(NEW)
check("waited for", #active == 0 and loading[NEW] ~= nil)
cached[NEW] = { "Fresh", 1, 1, 0, 1 }
loading[NEW]()
check("then shown", #active == 1 and active[1].text:GetText() == "|cffffffffFresh|r")
local secret = "You receive loot: " .. CLOTH .. "."
secretValues[secret] = true
Fire("CHAT_MSG_LOOT", secret)
check("a secret line never read", #active == 1)
Wait(6)

Section("placing")
DogsForeverUI.SetUnlocked(true)
check("shown to be placed", holder:IsShown() and holder:IsMouseEnabled())
check("samples: a stack on the holder, money above, a roll won on top",
    #active == 3 and active[1].text:GetText():find("Linen Cloth x2|r ", 1, true) and active[1].points[2] == holder
    and active[2].text:GetText():find("Money|r", 1, true) and active[3].text:GetText():find("You Won!.* 87$"))
Wait(30)
check("never timed out", #active == 3 and active[3]:IsShown())
DB.barWidth = 300
NS.Refresh()
check("resized with the setting, not made again", #active == 3 and active[1].width == 300 and active[1].alpha == 1)
DB.barWidth = NS.defaults.barWidth
Fire("CHAT_MSG_MONEY", "You loot 5 Copper")
check("real money beside them, not into the sample", #active == 4 and active[1].text:GetText():find("\ncoins:5$"))
DogsForeverUI.SetUnlocked(false)
check("a piece of its own, sized, with a reset",
    DogsForeverUI.Snap.CanReset(DogsForeverUI.Snap.EntryById("toasts"))
    and DogsForeverUI.Snap.SizeOf(DogsForeverUI.Snap.EntryById("toasts"), "h") ~= nil)
check("hidden again, the samples gone, the real one left", not holder:IsShown()
    and #active == 1 and not active[1].sample)

Summary()
