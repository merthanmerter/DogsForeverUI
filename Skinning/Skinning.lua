-- MODULE: Skinning  (DogsForeverUI.Skinning, settings section "skinning")
--
-- "Skinnable (150)" on the tooltip of a living creature a skinner could skin,
-- the number the skill it takes, the line coloured by the player's own skill:
-- red below it, orange up to ORANGE_ROOM above it (a sure skill-up, the
-- player, 2026-10-07: "add orange for guaranteed skill-up like Classic"),
-- yellow up to YELLOW_ROOM, green up to GREY_ROOM, grey past that - no
-- skill-up left in it (the player, 2026-10-07: "there should be also grey
-- 'no skill up'"). Only for a
-- character that has Skinning; a switch under Extras, on by default (the
-- player, 2026-10-06: "if player is skinner show skinable on alive skinable
-- creature tooltips"). The game says it of a corpse at most, never of a living
-- creature - and there in one fixed yellow, whatever the skill. That line is
-- made the same as the addon's (the player, 2026-10-06: "if its fixed color
-- in game default (when theyre dead) we should replace it with ours too"):
-- the same text, the number in it, and the same colour; and the creature is
-- learned from it, the game's word being the surest there is.
--
-- WHICH CREATURES. The game has no call that says whether a creature can be
-- skinned (nothing in its API documentation, nothing in its UI code), and
-- says it only of a corpse, once its loot is gone. So the line shows only for
-- a creature the game has confirmed - never a guess (the player, 2026-10-07:
-- "remove the guess, only show when confirmed", after a Gloomrise Soldier, a
-- Beast that cannot be skinned, said "Skinnable" alive). Confirmed once a
-- corpse of one like it said "Skinnable" or the player skinned one (the loot
-- window opening straight after a Skinning cast), kept by NPC ID in the
-- section's `learned` list. A looted corpse is read MARK_WAIT after its loot
-- window closes, through C_TooltipInfo.GetUnit, while it is still the target
-- or under the mouse - the player need not hover it again; otherwise whenever
-- its tooltip next shows. The list is the player's own, not a setting, and
-- comes through a reset (Core:Reset's `keep`).
--
-- A unit the player controls - a hunter's pet, a warlock's - is never one.
--
-- CLOTH. The cloth a living creature drops on its tooltip, icon and name in
-- the game's yellow (the player, 2026-10-07: "on humanoids ... which kind of
-- cloth (linen, silk, wool etc.) ... default yellow is a fine color"), for
-- anyone, a switch of its own under Extras, on by default. Confirmed the same
-- way, never a guess: each raw cloth (CLOTH) the player has seen in a
-- creature's loot window, kept by NPC ID in the section's `cloth` list, which
-- comes through a reset too. It shares this module's hook and learning.
--
-- THE SKILL IT TAKES is Classic's rule by the creature's level: 1 up to level
-- 10, (level - 10) x 10 up to 20, level x 5 above. A creature whose level is
-- hidden (a skull) shows the line red with no number.
--
-- HOW. A TooltipDataProcessor post-call on unit tooltips, the same hook the
-- other tooltip lines use (ActionBars\GameFrames.lua, Cooldowns\TooltipIDs.lua).
-- Anything the client keeps secret - the unit, its state, its GUID - and the
-- line is simply not added.

DogsForeverUI.Skinning = {}

do -- private scope
    local NS = DogsForeverUI.Skinning

    NS.key = "skinning"
    NS.title = "Skinning"

    NS.defaults = {
        showSkinnable = true,   -- the line on living creatures' tooltips
        showCloth = true,       -- the cloth line on living creatures' tooltips
        learned = {},           -- [npcID] = true: the game said it can be skinned
        cloth = {},             -- [npcID] = { [itemID] = true }: cloth seen in its loot
    }
    NS.keep = { learned = true, cloth = true }

    -- Raw cloth, lowest first: Linen, Wool, Silk, Mageweave, Runecloth, Felcloth.
    NS.CLOTH = { 2589, 2592, 4306, 4338, 14047, 14256 }
    local IS_CLOTH = {}
    for _, item in ipairs(NS.CLOTH) do IS_CLOTH[item] = true end

    NS.LABEL = "Skinnable"
    local SKINNING_SKILL = 393
    -- Skinning (Apprentice): only its name is used, which every rank shares.
    local SKINNING_SPELL = 8613
    -- How long after a Skinning cast the loot window counts as its loot.
    NS.LOOT_WAIT = 3
    -- How long after its loot window closes a corpse is read: the server
    -- marks it "Skinnable" a moment after.
    NS.MARK_WAIT = 1
    -- Where a corpse being looted or just looted is: under the mouse (a
    -- right-click), or targeted (the creature just killed).
    local CORPSE_UNITS = { "mouseover", "target" }
    -- Above the skill it takes by less than this, orange: a sure skill-up.
    NS.ORANGE_ROOM = 25
    -- Above it by less than this, yellow; past it, green.
    NS.YELLOW_ROOM = 50
    -- Above it by this much or more, grey: the skill no longer goes up.
    NS.GREY_ROOM = 100

    NS.RED = { 1, 0.1, 0.1 }
    NS.ORANGE = { 1, 0.5, 0.25 }
    NS.YELLOW = { 1, 0.82, 0 }
    NS.GREEN = { 0.25, 0.75, 0.25 }
    NS.GREY = { 0.5, 0.5, 0.5 }

    local IsSecret = issecretvalue or function() return false end

    local function Plain(value) return value ~= nil and not IsSecret(value) end

    -- The player's Skinning skill, or nil without it.
    function NS.Skill()
        local info = type(C_SkillInfo) == "table" and C_SkillInfo.GetSkillLineInfoByID
        if type(info) == "function" then
            local ok, line = pcall(info, SKINNING_SKILL)
            if ok and type(line) == "table" and Plain(line.rank) and type(line.rank) == "number" then
                return line.rank + ((Plain(line.modifier) and type(line.modifier) == "number") and line.modifier or 0)
            end
        end
        -- The old skill list, where the client still has it.
        if type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function" then
            local name = type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function"
                and C_Spell.GetSpellName(SKINNING_SPELL)
            for i = 1, GetNumSkillLines() or 0 do
                local skill, header, _, rank, _, modifier = GetSkillLineInfo(i)
                if not header and Plain(skill) and skill == name and type(rank) == "number" then
                    return rank + (type(modifier) == "number" and modifier or 0)
                end
            end
        end
        return nil
    end

    -- The skill a creature of `level` takes; nil for a hidden level.
    function NS.Required(level)
        if type(level) ~= "number" or level < 1 then return nil end
        if level <= 10 then return 1 end
        if level <= 20 then return (level - 10) * 10 end
        return level * 5
    end

    function NS.Colour(skill, required)
        if not required or skill < required then return NS.RED end
        if skill < required + NS.ORANGE_ROOM then return NS.ORANGE end
        if skill < required + NS.YELLOW_ROOM then return NS.YELLOW end
        if skill < required + NS.GREY_ROOM then return NS.GREEN end
        return NS.GREY
    end

    -- The NPC ID in a creature's GUID ("Creature-0-server-instance-zone-ID-spawn").
    function NS.NpcID(guid)
        if not Plain(guid) or type(guid) ~= "string" then return nil end
        local kind, id = guid:match("^(%a+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)")
        if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
        return tonumber(id)
    end

    -- What the creature `unit` is: "alive" or "dead" for an NPC, nil for a
    -- player, a pet, or anything the client will not say.
    local function State(unit)
        if not UnitExists(unit) then return nil end
        local player = UnitIsPlayer(unit)
        local controlled = type(UnitPlayerControlled) == "function" and UnitPlayerControlled(unit)
        local dead = type(UnitIsDeadOrGhost) == "function" and UnitIsDeadOrGhost(unit)
        if not Plain(player) or not Plain(controlled) or not Plain(dead) then return nil end
        if player or controlled then return nil end
        return dead and "dead" or "alive"
    end

    -- The corpse `guid`'s kind confirmed skinnable.
    local function Learn(guid)
        local id = NS.NpcID(guid)
        if id then NS.db.learned[id] = true end
    end

    -- The game's text for that line (UNIT_SKINNABLE_LEATHER, "Skinnable").
    local function GameLabel() return _G.UNIT_SKINNABLE_LEATHER or NS.LABEL end

    -- The game's own line on a corpse that can be skinned, in its one fixed
    -- colour.
    local function GameLine(tip)
        local name = type(tip.GetName) == "function" and tip:GetName()
        local count = type(tip.NumLines) == "function" and tip:NumLines()
        if not Plain(name) or not Plain(count) or type(name) ~= "string" or type(count) ~= "number" then return nil end
        local label = GameLabel()
        for i = 2, count do
            local line = _G[name .. "TextLeft" .. i]
            local text = line and type(line.GetText) == "function" and line:GetText()
            if Plain(text) and text == label then return line end
        end
    end

    -- Whether the corpse `unit`'s tooltip data has the game's line.
    local function Marked(unit)
        if type(C_TooltipInfo) ~= "table" or type(C_TooltipInfo.GetUnit) ~= "function" then return false end
        local data = C_TooltipInfo.GetUnit(unit)
        if type(data) ~= "table" or not Plain(data.lines) or type(data.lines) ~= "table" then return false end
        local label = GameLabel()
        for i = 2, #data.lines do
            local text = data.lines[i].leftText
            if Plain(text) and text == label then return true end
        end
        return false
    end

    -- The unit token of the corpse `guid`, while it is targeted or under the
    -- mouse.
    local function CorpseUnit(guid)
        for _, unit in ipairs(CORPSE_UNITS) do
            local current = State(unit) == "dead" and UnitGUID(unit)
            if Plain(current) and current == guid then return unit end
        end
    end

    -- The line's text and colour for a creature of `unit`'s level.
    local function Look(unit, skill)
        local level = UnitLevel(unit)
        local required = Plain(level) and NS.Required(level) or nil
        local text = required and ("%s (%d)"):format(NS.LABEL, required) or NS.LABEL
        return text, NS.Colour(skill, required)
    end

    -- The cloth line for NPC `id`: each cloth seen in its loot, icon and
    -- name, lowest first; nil for none.
    function NS.ClothText(id)
        local seen = NS.db.cloth[id]
        if not seen then return nil end
        local parts = {}
        for _, item in ipairs(NS.CLOTH) do
            local name = seen[item] and C_Item.GetItemNameByID(item)
            if name then
                parts[#parts + 1] = ("|T%s:0|t %s"):format(C_Item.GetItemIconByID(item) or "", name)
            end
        end
        return #parts > 0 and table.concat(parts, "   ") or nil
    end

    -- Per tooltip, whether it has the lines since it was last cleared: the
    -- game processes some tooltips twice.
    local added = setmetatable({}, { __mode = "k" })
    local hooked = setmetatable({}, { __mode = "k" })
    local function Cleared(tip) added[tip] = nil end

    function NS.Add(tip, data)
        if added[tip] then return end
        if type(tip) ~= "table" or type(tip.GetUnit) ~= "function" or type(tip.AddLine) ~= "function" then return end
        local ok, _, unit = pcall(tip.GetUnit, tip)
        if not ok or not Plain(unit) or type(unit) ~= "string" then return end
        local state = State(unit)

        -- A corpse: the game's own line, when it has one, made the same as
        -- the line on the living - and the creature learned from it.
        if state == "dead" then
            local skill = NS.db.showSkinnable and NS.Skill()
            local line = skill and GameLine(tip)
            if not line then return end
            Learn(UnitGUID(unit))
            local text, colour = Look(unit, skill)
            line:SetText(text)
            line:SetTextColor(colour[1], colour[2], colour[3])
            if type(tip.Show) == "function" then tip:Show() end
            return
        end

        local id = state == "alive" and NS.NpcID(UnitGUID(unit))
        if not id then return end
        local skill = NS.db.showSkinnable and NS.db.learned[id] and NS.Skill()
        local cloth = NS.db.showCloth and NS.ClothText(id)
        if not skill and not cloth then return end

        if not hooked[tip] and type(tip.HookScript) == "function" then
            hooked[tip] = true
            tip:HookScript("OnTooltipCleared", Cleared)
        end
        added[tip] = true
        if skill then
            local text, colour = Look(unit, skill)
            tip:AddLine(text, colour[1], colour[2], colour[3])
        end
        if cloth then tip:AddLine(cloth, NS.YELLOW[1], NS.YELLOW[2], NS.YELLOW[3]) end
        if type(tip.Show) == "function" then tip:Show() end
    end

    ---------------------------------------------------------------------------
    -- Learning: the loot window straight after a Skinning cast is a skin;
    -- any other is the corpse's own loot, its cloth noted.
    ---------------------------------------------------------------------------

    local skinnedAt, lootingGUID

    local function SkinningName()
        if type(C_Spell) ~= "table" or type(C_Spell.GetSpellName) ~= "function" then return nil end
        local name = C_Spell.GetSpellName(SKINNING_SPELL)
        return Plain(name) and name or nil
    end

    local function OnCast(spellID)
        if not Plain(spellID) or type(spellID) ~= "number" then return end
        local name = SkinningName()
        local cast = C_Spell.GetSpellName(spellID)
        if name and Plain(cast) and cast == name then skinnedAt = GetTime() end
    end

    -- The creature corpse the open loot window is on: the game's word for it,
    -- else the corpse under the mouse or targeted.
    local function LootSource()
        local guid = type(GetLootSourceInfo) == "function" and GetLootSourceInfo(1)
        if NS.NpcID(guid) then return guid end
        for _, unit in ipairs(CORPSE_UNITS) do
            guid = State(unit) == "dead" and UnitGUID(unit)
            if NS.NpcID(guid) then return guid end
        end
    end

    -- Each cloth in the open loot window, noted for the NPC `id`.
    local function LearnCloth(id)
        for slot = 1, GetNumLootItems() do
            local link = GetLootSlotLink(slot)
            local item = Plain(link) and type(link) == "string" and tonumber(link:match("item:(%d+)"))
            if item and IS_CLOTH[item] then
                NS.db.cloth[id] = NS.db.cloth[id] or {}
                NS.db.cloth[id][item] = true
            end
        end
    end

    local function OnLoot()
        local skin = skinnedAt and GetTime() - skinnedAt <= NS.LOOT_WAIT
        skinnedAt = nil
        local guid = LootSource()
        if not guid then return end
        if skin then
            Learn(guid)
        else
            lootingGUID = guid
            LearnCloth(NS.NpcID(guid))
        end
    end

    -- MARK_WAIT after a corpse's loot window shut: read it, if it is still
    -- at hand.
    local function OnLootClosed()
        local guid = lootingGUID
        lootingGUID = nil
        if not guid then return end
        C_Timer.After(NS.MARK_WAIT, function()
            local unit = CorpseUnit(guid)
            if unit and Marked(unit) then Learn(guid) end
        end)
    end

    -- Anything malformed in the lists goes (a "no" from an older version too).
    function NS.Normalise(db)
        if type(db.learned) ~= "table" then db.learned = {} end
        for id, value in pairs(db.learned) do
            if type(id) ~= "number" or value ~= true then db.learned[id] = nil end
        end
        if type(db.cloth) ~= "table" then db.cloth = {} end
        for id, items in pairs(db.cloth) do
            if type(id) ~= "number" or type(items) ~= "table" then
                db.cloth[id] = nil
            else
                for item, value in pairs(items) do
                    if not IS_CLOTH[item] or value ~= true then items[item] = nil end
                end
                if next(items) == nil then db.cloth[id] = nil end
            end
        end
    end

    -- The switches are read at each tooltip: nothing to redraw.
    function NS.Refresh() end
    NS.Init = NS.Refresh

    DogsForeverUI:RegisterModule(NS)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("LOOT_OPENED")
    events:RegisterEvent("LOOT_CLOSED")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    events:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_LOGIN" then
            self:UnregisterEvent("PLAYER_LOGIN")
            local processor = _G.TooltipDataProcessor
            local kinds = type(Enum) == "table" and Enum.TooltipDataType
            if type(processor) == "table" and type(processor.AddTooltipPostCall) == "function"
                and kinds and kinds.Unit then
                processor.AddTooltipPostCall(kinds.Unit, NS.Add)
            end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            OnCast(select(3, ...))
        elseif event == "LOOT_OPENED" then
            OnLoot()
        elseif event == "LOOT_CLOSED" then
            OnLootClosed()
        end
    end)
end
