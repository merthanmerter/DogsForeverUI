-- Professions: two gathering helpers, double right-click fishing and the Skinnable line.

-------------------------------------------------------------------------------
-- MODULE: Fishing  (DogsForeverUI.Fishing, settings section "fishing")
-- Double right-clicks in the world: with a fishing pole in hand it casts
-- Fishing; on a Basic Campfire it sits down. A cast (or /sit, protected) needs
-- a secure button and a real click, so on the second right-click the right
-- mouse button is override-bound to a secure button of the addon's, and
-- letting go is the click; the binding comes off straight after. A single
-- right-click is never touched, and nothing is armed while a line is out.
-------------------------------------------------------------------------------

DogsForeverUI.Fishing = {}

do -- private scope
    local NS = DogsForeverUI.Fishing
    local IsSecret = issecretvalue

    NS.key = "fishing"
    NS.title = "Double-click"

    NS.defaults = {
        fishing = true,     -- double right-click with a pole casts Fishing
        camping = true,     -- double right-click on a Basic Campfire sits down
    }
    -- Classic's pole in hand. Retail's sits in its profession slot for good, so
    -- every double-click would cast: no fishing there (and not in the options).
    NS.FISHING_OFFERED = not DogsForeverUI.RETAIL

    local BUTTON_NAME = "DogsForeverUIFishingButton"
    local FISHING_SPELL_ID = 7620       -- cast by name: the rank the player has
    local CAMPFIRE_SPELL_ID = 818       -- the spell and the object it makes share the name
    local CAMPFIRE_NAME = "Basic Campfire"
    local WEAPON, FISHING_POLE = Enum.ItemClass.Weapon, Enum.ItemWeaponSubclass.Fishingpole
    local OBJECT = Enum.TooltipDataType.Object
    local DOUBLE_CLICK = 0.4    -- seconds between the two right-clicks
    local ARMED_FOR = 0.5       -- an unused binding comes off after this

    local button
    local expiry                -- shown only while a binding is on (the secure button cannot be in combat)
    local lastRightClick, armedAt
    local campfireSeen = false

    -- Looked up by name, a spell answers only from the player's spellbook.
    local function KnownFishing()
        local name = C_Spell.GetSpellName(FISHING_SPELL_ID)
        if type(name) ~= "string" or not C_Spell.GetSpellInfo(name) then return nil end
        return name
    end

    local function CampfireName()
        local name = C_Spell.GetSpellName(CAMPFIRE_SPELL_ID)
        if type(name) == "string" and not IsSecret(name) then return name end
        return CAMPFIRE_NAME
    end

    -- What the world tooltip shows: true for a campfire, false for anything
    -- else (a secret included), nil for nothing.
    local function OverCampfire()
        local data = C_TooltipInfo.GetWorldCursor()
        if type(data) ~= "table" then return nil end
        if IsSecret(data.type) or IsSecret(data.lines) or data.type ~= OBJECT then return false end
        local line = type(data.lines) == "table" and data.lines[1]
        local name = type(line) == "table" and line.leftText or nil
        if name == nil or IsSecret(name) then return false end
        return name == CampfireName()
    end

    -- A campfire is remembered until the mouse is seen elsewhere: mouse-look
    -- hides the world cursor between the two clicks. Not read with camping off.
    local function LookUnderMouse()
        if not NS.db.camping then
            campfireSeen = false
            return
        end
        local over = OverCampfire()
        if over ~= nil then
            campfireSeen = over
        elseif not IsMouselooking() then
            campfireSeen = false
        end
    end

    local function PoleInHand()
        local itemID = GetInventoryItemID("player", INVSLOT_MAINHAND)
        if not itemID then return false end
        local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
        return classID == WEAPON and subClassID == FISHING_POLE
    end

    -- Casting or channelling anything (a line out above all); a secret answer counts as busy.
    local function Busy()
        for _, info in ipairs({ UnitChannelInfo, UnitCastingInfo }) do
            local name = info("player")
            if IsSecret(name) or name ~= nil then return true end
        end
        return false
    end

    local function Ready()
        local loot = _G.LootFrame
        return not (InCombatLockdown() or Busy() or (loot and loot:IsShown()) or IsMounted() or IsSwimming()
            or UnitExists("mouseover") or GetCursorInfo())
    end

    local function Disarm()
        if not armedAt or InCombatLockdown() then return end
        armedAt = nil
        ClearOverrideBindings(button)
        expiry:Hide()
    end

    local function Arm(kind, value)
        button:SetAttribute("type", kind)
        button:SetAttribute("spell", kind == "spell" and value or nil)
        button:SetAttribute("macrotext", kind == "macro" and value or nil)
        SetOverrideBindingClick(button, true, "BUTTON2", BUTTON_NAME)
        armedAt = GetTime()
        expiry:Show()
        -- Mouse-look on, the release would go to the camera, not the binding.
        if IsMouselooking() then MouselookStop() end
    end

    -- What a double-click now would do, if anything.
    local function Action()
        if not Ready() then return nil end
        if NS.db.camping and campfireSeen then return "macro", "/sit" end
        if NS.FISHING_OFFERED and NS.db.fishing and PoleInHand() then
            local spell = KnownFishing()
            if spell then return "spell", spell end
        end
    end

    local function OnWorldMouseDown(_, mouseButton)
        if mouseButton ~= "RightButton" then return end
        -- A binding still on would take this click's release: off first.
        Disarm()
        LookUnderMouse()
        local now = GetTime()
        local double = lastRightClick ~= nil and now - lastRightClick <= DOUBLE_CLICK
        lastRightClick = (not double) and now or nil      -- a third click starts a new pair
        if not double then return end
        local kind, value = Action()
        if kind then Arm(kind, value) end
    end

    local function Build()
        button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
        button:SetSize(1, 1)
        button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        button:SetAlpha(0)
        button:EnableMouse(false)
        button:SetAttribute("type", "spell")
        -- On the release whatever the key-down setting: the binding goes on with the button down.
        button:SetAttribute("useOnKeyDown", false)
        button:RegisterForClicks("AnyUp")
        button:SetScript("PostClick", Disarm)       -- after the secure click itself

        button:RegisterEvent("PLAYER_REGEN_DISABLED")
        button:RegisterEvent("WORLD_CURSOR_TOOLTIP_UPDATE")
        button:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
        button:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
        button:SetScript("OnEvent", function(_, event)
            if event == "WORLD_CURSOR_TOOLTIP_UPDATE" then
                LookUnderMouse()
            elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
                -- The line in: a click made while it was out (the catch) starts no pair.
                lastRightClick = nil
            else
                Disarm()        -- into combat while it still can, or the line going out
            end
        end)
        expiry = CreateFrame("Frame")
        expiry:Hide()
        expiry:SetScript("OnUpdate", function(self)
            if not armedAt then self:Hide()
            elseif GetTime() - armedAt > ARMED_FOR then Disarm() end
        end)

        WorldFrame:HookScript("OnMouseDown", OnWorldMouseDown)
    end

    -- The switches are read at each click.
    function NS.Refresh() end
    NS.Init = NS.Refresh

    DogsForeverUI:RegisterModule(NS)

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        Build()
    end)
end

-------------------------------------------------------------------------------
-- MODULE: Skinning  (DogsForeverUI.Skinning, settings section "skinning")
-- "Skinnable (150)" on a living creature's tooltip for a skinner, coloured by
-- the player's skill: red below it, then orange (a sure skill-up), yellow,
-- green, grey. Shown only for a creature confirmed - a corpse of its kind
-- said so, or the player skinned one - kept by NPC ID in `learned`; the
-- game's own corpse line made the same. The cloth a creature drops (seen in
-- its loot, kept in `cloth`) on its tooltip too, for anyone. Never a guess,
-- never a pet; anything secret and the line is not added.
-------------------------------------------------------------------------------

DogsForeverUI.Skinning = {}

do -- private scope
    local NS = DogsForeverUI.Skinning
    local IsSecret = issecretvalue

    NS.key = "skinning"
    NS.title = "Skinning"

    NS.defaults = {
        showSkinnable = true,   -- the line on living creatures' tooltips
        showCloth = true,       -- the cloth line on living creatures' tooltips
        learned = {},           -- [npcID] = true: the game said it can be skinned
        cloth = {},             -- [npcID] = { [itemID] = true }: cloth seen in its loot
    }
    NS.keep = { learned = true, cloth = true }  -- the player's own, through a reset
    -- Classic's skill by level and its cloth: retail has neither, so nothing
    -- there (settings kept, not in the options).
    NS.OFFERED = not DogsForeverUI.RETAIL

    -- Raw cloth, lowest first: Linen, Wool, Silk, Mageweave, Runecloth, Felcloth.
    local CLOTH = { 2589, 2592, 4306, 4338, 14047, 14256 }
    local IS_CLOTH = {}
    for _, item in ipairs(CLOTH) do IS_CLOTH[item] = true end

    NS.LABEL = "Skinnable"
    NS.LOOT_WAIT = 3            -- a loot window this soon after a Skinning cast is a skin
    local SKINNING_SKILL = 393
    local SKINNING_SPELL = 8613 -- only its name is used, which every rank shares
    local MARK_WAIT = 1         -- the server marks a corpse "Skinnable" a moment after its loot closes
    local CORPSE_UNITS = { "mouseover", "target" }
    -- Above the skill it takes by less than these: orange, yellow, green; past the last, grey.
    local ORANGE_ROOM, YELLOW_ROOM, GREY_ROOM = 25, 50, 100

    NS.RED = { 1, 0.1, 0.1 }
    NS.ORANGE = { 1, 0.5, 0.25 }
    NS.YELLOW = { 1, 0.82, 0 }
    NS.GREEN = { 0.25, 0.75, 0.25 }
    NS.GREY = { 0.5, 0.5, 0.5 }

    local function Plain(value) return value ~= nil and not IsSecret(value) end

    -- The player's Skinning skill, or nil without it.
    local function Skill()
        local line = C_SkillInfo.GetSkillLineInfoByID(SKINNING_SKILL)
        if type(line) ~= "table" or not Plain(line.rank) or type(line.rank) ~= "number" then return nil end
        local modifier = line.modifier
        return line.rank + ((Plain(modifier) and type(modifier) == "number") and modifier or 0)
    end

    -- Classic's rule: 1 up to level 10, (level - 10) x 10 up to 20, level x 5 above; nil for a skull.
    function NS.Required(level)
        if type(level) ~= "number" or level < 1 then return nil end
        if level <= 10 then return 1 end
        if level <= 20 then return (level - 10) * 10 end
        return level * 5
    end

    local function Colour(skill, required)
        if not required or skill < required then return NS.RED end
        if skill < required + ORANGE_ROOM then return NS.ORANGE end
        if skill < required + YELLOW_ROOM then return NS.YELLOW end
        if skill < required + GREY_ROOM then return NS.GREEN end
        return NS.GREY
    end

    -- The NPC ID in a creature's GUID ("Creature-0-server-instance-zone-ID-spawn").
    function NS.NpcID(guid)
        if not Plain(guid) or type(guid) ~= "string" then return nil end
        local kind, id = guid:match("^(%a+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)")
        if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
        return tonumber(id)
    end

    -- "alive" or "dead" for an NPC; nil for a player, a pet, or a secret.
    local function State(unit)
        if not UnitExists(unit) then return nil end
        local player, controlled, dead = UnitIsPlayer(unit), UnitPlayerControlled(unit), UnitIsDeadOrGhost(unit)
        if not Plain(player) or not Plain(controlled) or not Plain(dead) then return nil end
        if player or controlled then return nil end
        return dead and "dead" or "alive"
    end

    local function Learn(guid)
        local id = NS.NpcID(guid)
        if id then NS.db.learned[id] = true end
    end

    local function GameLabel() return _G.UNIT_SKINNABLE_LEATHER or NS.LABEL end

    -- The game's own "Skinnable" line on a corpse's tooltip.
    local function GameLine(tip)
        local name, count = tip:GetName(), tip:NumLines()
        if not Plain(name) or not Plain(count) or type(name) ~= "string" or type(count) ~= "number" then return nil end
        local label = GameLabel()
        for i = 2, count do
            local line = _G[name .. "TextLeft" .. i]
            local text = line and line:GetText()
            if Plain(text) and text == label then return line end
        end
    end

    -- Whether the corpse `unit`'s tooltip data has the game's line.
    local function Marked(unit)
        local data = C_TooltipInfo.GetUnit(unit)
        if type(data) ~= "table" or not Plain(data.lines) or type(data.lines) ~= "table" then return false end
        local label = GameLabel()
        for i = 2, #data.lines do
            local text = data.lines[i].leftText
            if Plain(text) and text == label then return true end
        end
        return false
    end

    -- The corpse `guid`'s unit token, while targeted or under the mouse.
    local function CorpseUnit(guid)
        for _, unit in ipairs(CORPSE_UNITS) do
            local current = State(unit) == "dead" and UnitGUID(unit)
            if Plain(current) and current == guid then return unit end
        end
    end

    local function Look(unit, skill)
        local level = UnitLevel(unit)
        local required = Plain(level) and NS.Required(level) or nil
        local text = required and ("%s (%d)"):format(NS.LABEL, required) or NS.LABEL
        return text, Colour(skill, required)
    end

    -- Each cloth seen in NPC `id`'s loot, icon and name, lowest first; nil for none.
    local function ClothText(id)
        local seen = NS.db.cloth[id]
        if not seen then return nil end
        local parts = {}
        for _, item in ipairs(CLOTH) do
            local name = seen[item] and C_Item.GetItemNameByID(item)
            if name then parts[#parts + 1] = ("|T%s:0|t %s"):format(C_Item.GetItemIconByID(item) or "", name) end
        end
        return #parts > 0 and table.concat(parts, "   ") or nil
    end

    -- Per tooltip, whether it has the lines since last cleared: some are processed twice.
    local added = setmetatable({}, { __mode = "k" })
    local hooked = setmetatable({}, { __mode = "k" })
    local function Cleared(tip) added[tip] = nil end

    local function Add(tip)
        -- (A tooltip the game forbids to add-ons: asking that is all that is allowed.)
        if tip:IsForbidden() or added[tip] then return end
        local ok, _, unit = pcall(tip.GetUnit, tip)
        if not ok or not Plain(unit) or type(unit) ~= "string" then return end
        local state = State(unit)

        -- A corpse: the game's own line made the same as the living's, and its kind learned.
        if state == "dead" then
            local line = NS.db.showSkinnable and GameLine(tip)
            local skill = line and Skill()
            if not skill then return end
            Learn(UnitGUID(unit))
            local text, colour = Look(unit, skill)
            line:SetText(text)
            line:SetTextColor(colour[1], colour[2], colour[3])
            tip:Show()
            return
        end

        local id = state == "alive" and NS.NpcID(UnitGUID(unit))
        if not id then return end
        local skill = NS.db.showSkinnable and NS.db.learned[id] and Skill()
        local cloth = NS.db.showCloth and ClothText(id)
        if not skill and not cloth then return end

        if not hooked[tip] then
            hooked[tip] = true
            tip:HookScript("OnTooltipCleared", Cleared)
        end
        added[tip] = true
        if skill then
            local text, colour = Look(unit, skill)
            tip:AddLine(text, colour[1], colour[2], colour[3])
        end
        if cloth then tip:AddLine(cloth, NS.YELLOW[1], NS.YELLOW[2], NS.YELLOW[3]) end
        tip:Show()
    end

    -- LEARNING: the loot window straight after a Skinning cast is a skin;
    -- any other is the corpse's own loot, its cloth noted, and the corpse read
    -- MARK_WAIT after its loot closes, while still at hand.
    local skinnedAt, lootingGUID

    local function OnCast(spellID)
        if not Plain(spellID) or type(spellID) ~= "number" then return end
        local name, cast = C_Spell.GetSpellName(SKINNING_SPELL), C_Spell.GetSpellName(spellID)
        if Plain(name) and Plain(cast) and cast == name then skinnedAt = GetTime() end
    end

    -- The corpse the loot window is on: the game's word, else the one under the mouse or targeted.
    local function LootSource()
        local guid = GetLootSourceInfo and GetLootSourceInfo(1)
        if NS.NpcID(guid) then return guid end
        for _, unit in ipairs(CORPSE_UNITS) do
            guid = State(unit) == "dead" and UnitGUID(unit)
            if NS.NpcID(guid) then return guid end
        end
    end

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

    local function OnLootClosed()
        local guid = lootingGUID
        lootingGUID = nil
        if not guid then return end
        C_Timer.After(MARK_WAIT, function()
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

    -- The switches are read at each tooltip.
    function NS.Refresh() end
    NS.Init = NS.Refresh

    DogsForeverUI:RegisterModule(NS)

    if NS.OFFERED then
        local events = CreateFrame("Frame")
        events:RegisterEvent("PLAYER_LOGIN")
        events:RegisterEvent("LOOT_OPENED")
        events:RegisterEvent("LOOT_CLOSED")
        events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        events:SetScript("OnEvent", function(self, event, ...)
            if event == "PLAYER_LOGIN" then
                self:UnregisterEvent("PLAYER_LOGIN")
                -- The same hook as the other tooltip lines (ActionBars\GameFrames.lua, Cooldowns\Cooldowns.lua).
                if TooltipDataProcessor then TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, Add) end
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                OnCast(select(3, ...))
            elseif event == "LOOT_OPENED" then
                OnLoot()
            else
                OnLootClosed()
            end
        end)
    end
end
