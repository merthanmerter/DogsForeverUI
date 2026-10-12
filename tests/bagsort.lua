-- The bags' Clean Up button, the addon's: partial stacks joined, then every item
-- in order by type, rarity, unit value, stack value or name first. Moves are made as the game
-- makes them - picked up and put down, a moved slot locked until the server
-- answers - and the bags the sort must leave alone are left alone.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

-- id = { class, subclass, quality, item level, sell price, stack size, name }
local ITEMS = {
    [10] = { 0, 1, 1, 12, 25, 5, "Minor Healing Potion" },
    [11] = { 2, 7, 2, 15, 300, 1, "Sword of Testing" },
    [12] = { 4, 2, 3, 20, 500, 1, "Blue Vest" },
    [13] = { 7, 5, 1, 5, 13, 20, "Linen Cloth" },
    [14] = { 15, 0, 0, 1, 40, 1, "Broken Fang" },
    [15] = { 6, 2, 1, 5, 1, 200, "Rough Arrow" },
}
for id, item in pairs(ITEMS) do itemClasses[id] = { item[1], item[2] } end
function C_Item.GetItemInfo(link)
    local item = ITEMS[tonumber(link:match("item:(%d+)"))]
    return item[7], link, item[3], item[4], 1, "", "", item[6], "", 0, item[5]
end

-- Thirty recipes, one of each subclass, for a full bag.
for i = 1, 30 do ITEMS[100 + i] = { 9, i, 2, 10, i, 1, ("Recipe %02d"):format(i) } end
for id, item in pairs(ITEMS) do itemClasses[id] = { item[1], item[2] } end

-- The bags: the backpack (no family, as the client has it), a bag, a quiver
-- (one kind only) and two empty bag slots. A slot is { id, count } or false.
local bags
local function Fill()
    bags = {
        [0] = { { 14, 1 }, { 13, 7 }, false, { 12, 1 }, { 13, 8 }, { 11, 1 } },
        [1] = { family = 0, { 10, 3 }, { 13, 20 }, false, { 10, 2 } },
        [2] = { family = 1, { 15, 50 }, false },
        [3] = {},
        [4] = {},
    }
end
Fill()

Constants.InventoryConstants = { NumBagSlots = 4 }
Enum.ItemQuality = { Poor = 0 }
function C_Container.GetContainerNumSlots(bag) return #bags[bag] end
function C_Container.GetContainerNumFreeSlots(bag) return 0, bags[bag].family end

-- The server: a slot moved is locked until it answers.
local locked = {}
local function Key(bag, slot) return bag .. ":" .. slot end
-- A slot a trade or the mail holds stays locked whatever the server answers.
local stuck = {}
local function Answer()
    locked = {}
    for key in pairs(stuck) do locked[key] = true end
end

function C_Container.GetContainerItemInfo(bag, slot)
    local s = bags[bag][slot]
    if not s then return nil end
    local item = ITEMS[s[1]]
    return { itemID = s[1], stackCount = s[2], hyperlink = "item:" .. s[1], quality = item[3],
             itemName = item[7], isLocked = locked[Key(bag, slot)] == true }
end

-- The cursor: what was picked up and from where. Put down on an empty slot it
-- moves, on its own kind it tops that up (the rest stays on the cursor), on
-- anything else the two swap. A locked slot does nothing.
local held
local refused, pickups = 0, 0
function C_Container.PickupContainerItem(bag, slot)
    pickups = pickups + 1
    if locked[Key(bag, slot)] then refused = refused + 1; return end
    local s = bags[bag][slot]
    if not held then
        if s then held = { bag = bag, slot = slot } end
        return
    end
    local from = bags[held.bag]
    local item = from[held.slot]
    if not s then
        bags[bag][slot], from[held.slot] = item, false
    elseif s[1] == item[1] then
        local room = math.min(ITEMS[s[1]][6] - s[2], item[2])
        s[2], item[2] = s[2] + room, item[2] - room
        if item[2] == 0 then from[held.slot] = false end
    else
        bags[bag][slot], from[held.slot] = item, s
    end
    locked[Key(bag, slot)], locked[Key(held.bag, held.slot)] = true, true
    held = nil
end
function ClearCursor() held = nil end
function GetCursorInfo() return held and "item" or cursorInfo end

SOUNDKIT = { UI_BAG_SORTING_01 = 1 }
sounds = {}
function PlaySound(id) sounds[#sounds + 1] = id end
BAG_CLEANUP_BAGS = "Clean Up Bags"
-- The game's context menu: the last one opened, its title and radios.
MenuResponse = { Close = 2 }
local menu
MenuUtil = {}
function MenuUtil.CreateContextMenu(owner, generator)
    menu = { owner = owner, radios = {} }
    local root = {}
    function root:CreateTitle(text) menu.title = text end
    function root:CreateRadio(text, isSelected, setSelected, data)
        local radio = { text = text, data = data }
        function radio:SetResponse(response) self.response = response end
        function radio:Selected() return isSelected(data) end
        function radio:Pick() setSelected(data) end
        menu.radios[#menu.radios + 1] = radio
        return radio
    end
    generator(owner, root)
end
function Widget:SetNormalAtlas(atlas) self.normalAtlas = atlas end
function Widget:SetPushedAtlas(atlas) self.pushedAtlas = atlas end

-- The game's own button, as its XML builds it.
local gameButton = CreateFrame("Button", "BagItemAutoSortButton", UIParent)

LoadAddon()
Login()

local Sort = DogsForeverUI.Menus.BagSort
local DB = DogsForeverUI.Menus.db
local button = Sort.button

-- A click, then every pass the sort asks for, the server answering between.
local function Click()
    pendingTimer = nil
    button.scripts.OnClick(button, "LeftButton")
    local passes = 0
    while pendingTimer and passes < 200 do
        local pass = pendingTimer
        pendingTimer = nil
        Answer()
        pass()
        passes = passes + 1
    end
    Answer()
    return passes
end

-- The sortable slots' items in order, by id ("-" an empty slot); and the
-- stacks of one item, the largest first. Which copy of an item comes first
-- is the sort's to pick.
local function Contents()
    local out = {}
    for _, bag in ipairs({ 0, 1 }) do
        for _, s in ipairs(bags[bag]) do out[#out + 1] = s and tostring(s[1]) or "-" end
    end
    return table.concat(out, " ")
end
local function Stacks(id)
    local out = {}
    for _, bag in ipairs({ 0, 1 }) do
        for _, s in ipairs(bags[bag]) do
            if s and s[1] == id then out[#out + 1] = s[2] end
        end
    end
    table.sort(out, function(a, b) return a > b end)
    return table.concat(out, " ")
end

Section("the button")
check("the addon's own, over the game's, as its child", button and button.parent == gameButton
    and button.allPointsTo == gameButton)
check("in the game's art", button.normalAtlas == "bags-button-autosort-up"
    and button.pushedAtlas == "bags-button-autosort-down")
check("the game's button is left as it is", gameButton.scripts.OnClick == nil)
gameButton:SetFrameLevel(7)
button.scripts.OnShow(button)
check("lifted above all else in the bag window each time it shows (the gamepad bag bar lies over it)",
    button:GetFrameLevel() == 107, button:GetFrameLevel())
check("left and right clicks", button.clicks[1] == "LeftButtonUp" and button.clicks[2] == "RightButtonUp")
check("type first by default", DB.bagSort == "type")
button.scripts.OnEnter(button)
check("its tooltip says what it does", GameTooltip:GetLines()
    == "Clean Up Bags | Joins stacks, then sorts by type, then rarity, unit value, stack value and name."
    .. " Junk goes last."
    .. " | Right-click to choose what it sorts by.", GameTooltip:GetLines())

-- A right-click, and the radio named `label` picked in the menu it opens.
local function Pick(label)
    menu = nil
    button.scripts.OnClick(button, "RightButton")
    for _, radio in ipairs(menu and menu.radios or {}) do
        if radio.text == label then radio:Pick() end
    end
end

Section("the right-click menu")
pendingTimer = nil
button.scripts.OnClick(button, "RightButton")
check("the game's context menu, on the button", menu and menu.owner == button and menu.title == "Sort bags by")
check("a radio each: type, rarity, unit value, stack value, name",
    #menu.radios == 5 and menu.radios[1].text == "Type" and menu.radios[3].text == "Unit Value"
    and menu.radios[4].text == "Stack Value" and menu.radios[5].text == "Name")
check("the pick ticked, and a pick closes the menu",
    menu.radios[1]:Selected() and not menu.radios[2]:Selected() and menu.radios[2].response == MenuResponse.Close)
check("a right-click sorts nothing", pendingTimer == nil and #sounds == 0)

Section("by type")
local passes = Click()
check("the bag sound, once", #sounds == 1)
check("stacks joined", Stacks(10) == "5" and Stacks(13) == "20 15", Stacks(13))
check("then the game's classes in order, the gaps at the end",
    Contents() == "10 11 12 13 13 14 - - - -", Contents())
check("never a move onto a locked slot", refused == 0, refused)
check("in three batches: the stacks, then the order in two", passes == 3, passes)
check("the quiver untouched", bags[2][1][1] == 15 and bags[2][1][2] == 50 and bags[2][2] == false)
check("nothing left on the cursor", GetCursorInfo() == nil)
check("again: nothing to move", Click() == 0 and Contents() == "10 11 12 13 13 14 - - - -")

Section("by rarity, unit value, stack value and name, picked from the menu")
Pick("Rarity")
check("picking only picks: nothing moved", DB.bagSort == "rarity" and Contents() == "10 11 12 13 13 14 - - - -")
Click()
check("a left-click then sorts by it: the best first, item level within one",
    Contents() == "12 11 10 13 13 14 - - - -", Contents())
Click()
check("and again by the same pick: nothing to move", Contents() == "12 11 10 13 13 14 - - - -")
Pick("Unit Value")
Click()
check("unit value: what one sells for, the dearest first, junk last all the same",
    DB.bagSort == "value" and Contents() == "12 11 10 13 13 14 - - - -", Contents())
Pick("Stack Value")
Click()
check("stack value: what the whole stack sells for - 20 cloth (260) before 15 (195), both before 5 potions (125)",
    DB.bagSort == "stack" and Contents() == "12 11 13 13 10 14 - - - -", Contents())
check("the fuller stack the dearer", bags[0][3][2] == 20 and bags[0][4][2] == 15)
Pick("Name")
Click()
check("A to Z, junk last all the same", Contents() == "12 13 13 10 11 14 - - - -", Contents())
button.scripts.OnEnter(button)
check("the tooltip follows the pick", GameTooltip:GetLines()
    == "Clean Up Bags | Joins stacks, then sorts by name, then type, rarity, unit value and stack value."
    .. " Junk goes last. | Right-click to choose what it sorts by.", GameTooltip:GetLines())
check("still never a move onto a locked slot", refused == 0, refused)

Section("two stacks of one item trade places without joining")
Fill()
bags[0] = { { 13, 15 }, { 13, 20 } }
bags[1] = { family = 0 }
Click()
check("the full one first: put down on the partial, their counts swapped",
    bags[0][1][2] == 20 and bags[0][2][2] == 15 and refused == 0)

Section("the backpack, whatever the client says of it")
Fill()
bags[0].family = 1
Pick("Type")
Click()
check("sorted with the bags all the same", Contents() == "10 11 12 13 13 14 - - - -", Contents())

Section("a full bag, scrambled")
Fill()
bags[1] = { family = 0 }
for slot = 1, 40 do bags[1][slot] = false end
-- The even ones from the start of the bag, the odd ones backwards from its
-- end, a gap of ten between.
for i = 1, 30 do bags[1][i % 2 == 0 and i / 2 or 40 - (i - 1) / 2] = { 100 + i, 1 } end
passes = Click()
local inOrder = true
local want = { 11, 12, 13 }
for i = 1, 30 do want[#want + 1] = 100 + i end
want[#want + 1] = 14
local got = {}
for _, bag in ipairs({ 0, 1 }) do
    for _, s in ipairs(bags[bag]) do if s then got[#got + 1] = s[1] end end
end
for i, id in ipairs(want) do if got[i] ~= id then inOrder = false end end
check("sorted, the gaps at the end", inOrder and #got == #want and bags[1][28] ~= false
    and bags[1][29] == false, table.concat(got, " "))
check("all at once: the stacks, then the order in two batches however mixed", passes == 3, passes)
check("never a move onto a locked slot", refused == 0, refused)

Section("each batch waits for the server to answer the last")
Fill()
pendingTimer = nil
button.scripts.OnClick(button, "LeftButton")
local sent = pickups
check("the first batch goes out at once", sent > 0 and pendingTimer ~= nil)
for _ = 1, 3 do
    local look = pendingTimer
    pendingTimer = nil
    look()
end
check("nothing more while its slots are still locked", pickups == sent and pendingTimer ~= nil)
Answer()
passes = 0
while pendingTimer and passes < 50 do
    local look = pendingTimer
    pendingTimer = nil
    Answer()
    look()
    passes = passes + 1
end
check("answered, it goes on and finishes", Contents() == "10 11 12 13 13 14 - - - -" and refused == 0, Contents())

Section("a slot that stays locked")
Fill()
stuck[Key(1, 2)] = true
Answer()
passes = Click()
check("the rest is sorted around it, and the run ends rather than waiting on it for good",
    pendingTimer == nil and passes < 80 and Contents() == "10 11 12 13 14 - - 13 - -" and refused == 0,
    passes .. " " .. Contents() .. " refused " .. refused)
stuck = {}
Answer()
Click()
check("freed, the next click finishes the sort", Contents() == "10 11 12 13 13 14 - - - -", Contents())

Section("a slot the server answers late")
Fill()
stuck[Key(1, 2)] = true
pendingTimer = nil
button.scripts.OnClick(button, "LeftButton")
for tick = 1, 100 do
    if not pendingTimer then break end
    if tick == 20 then stuck = {} end
    local look = pendingTimer
    pendingTimer = nil
    Answer()
    look()
end
check("the same click waits for it, then sorts it in too", Contents() == "10 11 12 13 13 14 - - - -"
    and pendingTimer == nil and refused == 0, Contents())

Section("in the order the bags window draws its slots")
-- A window that draws the backpack from the bottom right, bag 1 above it:
-- the reading order is not the bags' own.
Fill()
local drawn = {}
for _, bag in ipairs({ 0, 1 }) do
    for slot = 1, #bags[bag] do drawn[#drawn + 1] = { bag = bag, slot = slot } end
end
local COLUMNS = 4
for k, at in ipairs(drawn) do
    local i = k - 1
    at.top, at.left = math.floor(i / COLUMNS) * 40, (COLUMNS - 1 - i % COLUMNS) * 40 + 0.3
end
ContainerFrameCombinedBags = {}
function ContainerFrameCombinedBags:IsShown() return true end
function ContainerFrameCombinedBags:EnumerateValidItems()
    local buttons = {}
    for i, at in ipairs(drawn) do
        buttons[i] = { GetBagID = function() return at.bag end, GetID = function() return at.slot end,
                       GetTop = function() return at.top + 0.2 end, GetLeft = function() return at.left end }
    end
    return ipairs(buttons)
end
Click()
local reading = {}
table.sort(drawn, function(a, b)
    if a.top ~= b.top then return a.top > b.top end
    return a.left < b.left
end)
for _, at in ipairs(drawn) do
    local s = bags[at.bag][at.slot]
    reading[#reading + 1] = s and tostring(s[1]) or "-"
end
check("read top left to bottom right: in order, the gaps at the end",
    table.concat(reading, " ") == "10 11 12 13 13 14 - - - -", table.concat(reading, " "))
ContainerFrameCombinedBags = nil

Section("the player's cursor is theirs")
Fill()
cursorInfo = "spell"
local before = #sounds
check("something on the cursor: nothing moves, no sound", Click() == 0 and #sounds == before
    and Contents() == "14 13 - 12 13 11 10 13 - 10")
cursorInfo = nil

Summary()
