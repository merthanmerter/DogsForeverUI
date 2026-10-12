-- "Skinnable (150)" on a living creature's tooltip, for a skinner: only once
-- the game has confirmed one like it (a corpse saying so, or a skin), never a
-- guess, never a pet or a corpse; the skill it takes by level, the line
-- coloured by the player's skill.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

local postCalls = {}
TooltipDataProcessor = {
    AllTypes = "ALL",
    AddTooltipPostCall = function(kind, fn)
        postCalls[kind] = postCalls[kind] or {}
        table.insert(postCalls[kind], fn)
    end,
}

-- The player's Skinning, or none.
skinning = nil
C_SkillInfo = {
    GetSkillLineInfoByID = function(id)
        if id == 393 and skinning then return { skillID = 393, name = "Skinning", rank = skinning, modifier = 0 } end
    end,
}
local spellName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id)
    if id == 8613 or id == 8617 then return "Skinning" end
    if id == 133 then return "Fireball" end
    return spellName(id)
end
-- A test sets `controlled` on a unit.
function UnitPlayerControlled(token)
    local u = Unit(token)
    return u ~= nil and u.controlled == true
end
lootSource = nil
function GetLootSourceInfo() return lootSource end
-- The open loot window's items, by item ID.
lootItems = {}
function GetNumLootItems() return #lootItems end
function GetLootSlotLink(slot)
    local item = lootItems[slot]
    return item and ("|cffffffff|Hitem:%d::::::::60:::::|h[Item]|h|r"):format(item)
end
local CLOTH_NAMES = { [2589] = "Linen Cloth", [2592] = "Wool Cloth", [4306] = "Silk Cloth" }
C_Item.GetItemNameByID = function(item) return CLOTH_NAMES[item] end
C_Item.GetItemIconByID = function(item) return 1000 + item end
-- The game's tooltip data for a unit: its name, and its "Skinnable" line on a
-- corpse it marks.
C_TooltipInfo.GetUnit = function(token)
    local u = Unit(token)
    if not u then return end
    local lines = { { leftText = u.name } }
    if u.gameSkinnable then table.insert(lines, { leftText = "Skinnable" }) end
    return { lines = lines }
end
-- The wait after a loot window shuts.
local function Wait()
    local timer = pendingTimer
    pendingTimer = nil
    if timer then timer() end
end

LoadAddon()
Login()

local NS = DogsForeverUI.Skinning

local tip = CreateFrame("Frame", "SkinTooltip", UIParent)
tip.lines = {}
-- Each line also a font string of its own, SkinTooltipTextLeftN, as the game's are.
function tip:AddLine(text, r, g, b)
    local line = { text = text, colour = { r, g, b } }
    function line:GetText() return self.text end
    function line:SetText(t) self.text = t end
    function line:SetTextColor(r2, g2, b2) self.colour = { r2, g2, b2 } end
    table.insert(self.lines, line)
    _G["SkinTooltipTextLeft" .. #self.lines] = line
end
function tip:GetName() return "SkinTooltip" end
function tip:NumLines() return #self.lines end
function tip:GetUnit() if self.unit then return "someone", self.unit end end
function tip:ClearLines()
    self.lines = {}
    for _, hook in ipairs(self.hooks.OnTooltipCleared or {}) do hook(self) end
end
function tip:Show() end

local function Guid(npcID) return ("Creature-0-4372-0-17-%d-0000ABCDEF"):format(npcID) end

-- Hovering a unit: the line the addon added, if any.
local GAME_YELLOW = { 1, 0.82, 0.1 }
local function Hover(unit, twice)
    units.mouseover = unit
    tip:ClearLines()
    tip.unit = "mouseover"
    tip:AddLine(unit.name)
    -- The game's own line on a corpse it says can be skinned.
    if unit.gameSkinnable then tip:AddLine("Skinnable", GAME_YELLOW[1], GAME_YELLOW[2], GAME_YELLOW[3]) end
    for _ = 1, twice and 2 or 1 do
        for _, fn in ipairs(postCalls[Enum.TooltipDataType.Unit] or {}) do fn(tip, {}) end
    end
    local skin
    for i = 2, #tip.lines do
        if tip.lines[i].text:find(NS.LABEL, 1, true) then
            check("one line, never two", skin == nil)
            skin = tip.lines[i]
        end
    end
    return skin
end

-- A corpse of `unit`'s kind the game marks "Skinnable", hovered.
local function SeeMarkedCorpse(unit)
    unit.dead, unit.gameSkinnable = true, true
    Hover(unit)
    unit.dead, unit.gameSkinnable = nil, nil
end

local wolf = { name = "Timber Wolf", level = 30, guid = Guid(69) }
local whelp = { name = "Black Whelp", level = 22, guid = Guid(2725) }

Section("the rule")
check("level 5 takes 1", NS.Required(5) == 1)
check("level 10 takes 1", NS.Required(10) == 1)
check("level 16 takes 60", NS.Required(16) == 60)
check("level 20 takes 100", NS.Required(20) == 100)
check("level 30 takes 150", NS.Required(30) == 150)
check("a hidden level takes no number", NS.Required(-1) == nil)
check("an NPC ID read from a creature's GUID", NS.NpcID(Guid(69)) == 69)
check("and none from a player's", NS.NpcID("Player-4372-00ABCDEF") == nil)

Section("only once the game confirms it")
skinning = 140
check("a creature never seen dead: no line, no guess", Hover(wolf) == nil)
SeeMarkedCorpse(wolf)
local line = Hover(wolf)
check("a corpse said Skinnable: the living say so, with the skill it takes", line and line.text == "Skinnable (150)", line and line.text)
skinning = nil
check("no Skinning: no line", Hover(wolf) == nil)

Section("the colour")
skinning = 140
line = Hover(wolf)
check("red with the skill too low", line and line.colour[1] == NS.RED[1] and line.colour[2] == NS.RED[2])
skinning = 150
line = Hover(wolf)
check("orange with just enough: a sure skill-up", line and line.colour[1] == NS.ORANGE[1] and line.colour[2] == NS.ORANGE[2])
skinning = 174
line = Hover(wolf)
check("still orange just short of yellow", line and line.colour[2] == NS.ORANGE[2])
skinning = 175
line = Hover(wolf)
check("yellow past the sure skill-up", line and line.colour[2] == NS.YELLOW[2] and line.colour[1] == NS.YELLOW[1])
skinning = 200
line = Hover(wolf)
check("green with plenty", line and line.colour[1] == NS.GREEN[1])
skinning = 249
line = Hover(wolf)
check("still green just short of no skill-up", line and line.colour[1] == NS.GREEN[1])
skinning = 250
line = Hover(wolf)
check("grey with no skill-up left", line and line.colour[1] == NS.GREY[1] and line.colour[2] == NS.GREY[2])
skinning = 200
check("processed twice: still one line", Hover(wolf, true) ~= nil)

Section("which creatures")
wolf.dead = true
check("a corpse the game does not mark: no line", Hover(wolf) == nil)
wolf.dead = nil
local pet = { name = "Wolf", level = 30, controlled = true, guid = Guid(69) }
check("a pet, of a kind confirmed: no line", Hover(pet) == nil)
local skull = { name = "Big Bear", level = -1, guid = Guid(1225) }
SeeMarkedCorpse(skull)
line = Hover(skull)
check("a skull level: red, no number", line and line.text == "Skinnable" and line.colour[1] == NS.RED[1])

Section("learned by skinning")
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 133)
lootSource = whelp.guid
Fire("LOOT_OPENED")
check("ordinary loot after another spell: nothing learned", Hover(whelp) == nil)
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 8617)
Tick(NS.LOOT_WAIT + 1)
Fire("LOOT_OPENED")
check("loot long after a skin: nothing learned", Hover(whelp) == nil)
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 8617)
Tick(1)
Fire("LOOT_OPENED")
line = Hover(whelp)
check("skinned once: every one like it says so", line and line.text == "Skinnable (110)", line and line.text)
check("kept in the section", NS.db.learned[2725] == true)
DogsForeverUI:Reset("skinning")
check("and kept through a reset", NS.db.learned[2725] == true)

Section("the game's own line on a corpse")
wolf.dead, wolf.gameSkinnable = true, true
line = Hover(wolf)
check("made the same as the living's: the number", line and line.text == "Skinnable (150)", line and line.text)
check("and the colour, not the game's yellow", line and line.colour[1] == NS.GREEN[1] and line.colour[2] == NS.GREEN[2])
line = Hover(wolf, true)
check("processed twice: still one line, still ours", line and line.text == "Skinnable (150)")
wolf.dead, wolf.gameSkinnable = nil, nil

Section("read after looting, without a second hover")
lootSource = nil  -- the game names no source: the target is it
units.mouseover = nil
local spider = { name = "Gloomrise Soldier", level = 28, guid = Guid(1555), dead = true }
units.target = spider
Fire("LOOT_OPENED")
Fire("LOOT_CLOSED")
Wait()
check("looted, never marked: nothing learned", NS.db.learned[1555] == nil)
spider.dead = nil
check("the living say nothing", Hover(spider) == nil)
units.mouseover = nil
local boar = { name = "Mangy Boar", level = 12, guid = Guid(1984), dead = true, gameSkinnable = true }
units.target = boar
Fire("LOOT_OPENED")
Fire("LOOT_CLOSED")
check("not read before the wait", NS.db.learned[1984] == nil)
Wait()
check("read through the target after the wait: it can", NS.db.learned[1984] == true)
local cat = { name = "Mottled Cat", level = 12, guid = Guid(1985), dead = true, gameSkinnable = true }
units.target = cat
Fire("LOOT_OPENED")
Fire("LOOT_CLOSED")
units.target = nil
Wait()
check("the corpse no longer at hand: nothing read", NS.db.learned[1985] == nil)

Section("the list")
local db = { learned = { [5] = true, [6] = false, x = true } }
NS.Normalise(db)
check("a no from an older version goes, a yes stays", db.learned[5] == true and db.learned[6] == nil and db.learned.x == nil)

Section("cloth")
-- Hovering a unit: the cloth line, and the line just before it.
local function ClothLine(unit, twice)
    local skin = Hover(unit, twice)
    local found, before
    for i = 2, #tip.lines do
        if tip.lines[i].text:find("Cloth", 1, true) then
            check("one cloth line, never two", found == nil)
            found, before = tip.lines[i], tip.lines[i - 1]
        end
    end
    return found, before, skin
end
local function Loot(unit, items)
    lootSource, lootItems = unit.guid, items
    Fire("LOOT_OPENED")
    Fire("LOOT_CLOSED")
    lootSource, lootItems = nil, {}
end
skinning = nil
local bandit = { name = "Defias Bandit", level = 12, guid = Guid(116) }
check("never looted: no cloth line", ClothLine(bandit) == nil)
Loot(bandit, { 2589, 2770 })
local cloth = ClothLine(bandit)
check("linen seen in its loot: named, with its icon, for anyone", cloth and cloth.text == "|T3589:0|t Linen Cloth", cloth and cloth.text)
check("in the game's yellow", cloth and cloth.colour[1] == NS.YELLOW[1] and cloth.colour[2] == NS.YELLOW[2] and cloth.colour[3] == NS.YELLOW[3])
Loot(bandit, { 2592 })
cloth = ClothLine(bandit, true)
check("wool too: both, lowest first, one line however often processed",
    cloth and cloth.text == "|T3589:0|t Linen Cloth   |T3592:0|t Wool Cloth", cloth and cloth.text)
check("anything else in the loot: not noted", NS.db.cloth[116][2770] == nil)
bandit.dead = true
check("a corpse: no cloth line", ClothLine(bandit) == nil)
bandit.dead = nil
local seen = { name = "Lurking Worgen", level = 25, guid = Guid(1766) }
Loot(seen, { 4306 })
skinning = 200
SeeMarkedCorpse(seen)
local before, skinLine
cloth, before, skinLine = ClothLine(seen)
check("skinnable and cloth both: the cloth under the Skinnable line",
    cloth and cloth.text == "|T5306:0|t Silk Cloth" and before == skinLine and skinLine ~= nil)
NS.db.showCloth = false
check("its switch off: no cloth line", ClothLine(bandit) == nil)
cloth, before, skinLine = ClothLine(seen)
check("and the Skinnable line stays", cloth == nil and skinLine ~= nil)
NS.db.showCloth = true
DogsForeverUI:Reset("skinning")
check("kept through a reset", NS.db.cloth[116] and NS.db.cloth[116][2589] == true)
local db = { cloth = { [116] = { [2589] = true, [2770] = true }, [117] = { [2770] = true }, [118] = true } }
NS.Normalise(db)
check("anything but cloth goes from the list",
    db.cloth[116][2589] == true and db.cloth[116][2770] == nil and db.cloth[117] == nil and db.cloth[118] == nil)

Section("the switch")
NS.db.showSkinnable = false
check("off: no line", Hover(wolf) == nil)
NS.db.showSkinnable = true
check("on again", Hover(wolf) ~= nil)

Summary()
