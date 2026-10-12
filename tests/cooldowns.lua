-- The cooldown manager: a list the player builds by ID, a bar for each while
-- it cools down, stacking up from beside the castbar - and nothing decided
-- on a secret, in combat or out. Also the IDs on tooltips.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

-------------------------------------------------------------------------------
-- THE GAME'S COOLDOWNS, as this client hands them out. In combat a cooldown's
-- numbers are secret; only isActive and isOnGCD, documented NeverSecret, stay
-- plain (unless a test makes isActive secret too, to see it is never looked
-- at). The duration object a status bar runs is drawn, never decided on:
-- asking it IsActive or IsZero raises here, because in game it answered with
-- a secret in combat and the old GCD bar threw every frame on it.
-------------------------------------------------------------------------------

local SECRET = SecretCastValue("cooldown number")
-- A secret false: marked secret, and only ever handed to the client's own
-- SetAlphaFromBoolean (which may look at it).
local SECRET_FALSE = setmetatable({}, { __tostring = function() return "<secret false>" end })
secretValues[SECRET_FALSE] = true
secretActive = false

spells = {
    [100] = { name = "Charge" },
    [200] = { name = "Mocking Blow" },
    [300] = { name = "Rush", charges = 2 },
}
cooldowns = {}      -- spellID -> { start, length }
gcdUntil = 0
forms = {}          -- { { spellID, active } }
local askedIgnoreGCD = {}

local function Running(c) return c ~= nil and c.start + c.length > now end

local function NewDuration(remaining)
    local d = { remaining = remaining }
    function d:GetRemainingDuration()
        if inCombat then return SECRET end
        return self.remaining
    end
    function d:SetTimeFromStart(start, length) self.remaining = start + length - now end
    function d:IsActive() error("decided on a duration object's IsActive, secret in combat", 2) end
    function d:IsZero() error("decided on a duration object's IsZero, secret in combat", 2) end
    function d:HasExpired() error("decided on a duration object's HasExpired, secret in combat", 2) end
    return d
end

C_Spell.DoesSpellExist = function(id) return spells[id] ~= nil end
do
    local plainName = C_Spell.GetSpellName
    C_Spell.GetSpellName = function(id)
        if spells[id] then return spells[id].name end
        return plainName(id)
    end
end
C_Spell.GetSpellTexture = function(id) return spells[id] and ("icon" .. id) or nil end
C_Spell.GetSpellCooldown = function(id)
    if not spells[id] then return nil end
    local own = Running(cooldowns[id])
    local gcd = now < gcdUntil
    local length = own and cooldowns[id].length or (gcd and 1.5 or 0)
    local active = own or gcd
    if secretActive then active = active and SECRET_TRUE or SECRET_FALSE end
    return {
        startTime = inCombat and SECRET or now, duration = inCombat and SECRET or length,
        modRate = inCombat and SECRET or 1,
        isEnabled = true, isActive = active, isOnGCD = (not own) and gcd,
    }
end
C_Spell.GetSpellCooldownDuration = function(id, ignoreGCD)
    askedIgnoreGCD[#askedIgnoreGCD + 1] = ignoreGCD
    local c = cooldowns[id]
    return NewDuration(Running(c) and (c.start + c.length - now) or 0)
end
C_Spell.GetSpellCharges = function(id)
    local s = spells[id]
    if not s or not s.charges then return nil end
    return { maxCharges = s.charges, currentCharges = inCombat and SECRET or (s.current or s.charges),
             isActive = Running(cooldowns[id]) }
end
C_Spell.GetSpellChargeDuration = function(id)
    local c = cooldowns[id]
    return NewDuration(Running(c) and (c.start + c.length - now) or 0)
end
function GetNumShapeshiftForms() return #forms end
function GetShapeshiftFormInfo(index)
    local form = forms[index]
    if not form then return nil end
    return "icon", form.active, true, form.spellID
end

-- Items: not secret. 6948 is cached, 5512 not yet.
items = { [6948] = { name = "Hearthstone", icon = "hearth" }, [5512] = { icon = "stone" } }
itemCooldowns = {}  -- itemID -> { start, length }
local requested = {}
do
    local plainInstant = C_Item.GetItemInfoInstant
    C_Item.GetItemInfoInstant = function(id)
        if items[id] then return id, nil, nil, nil, items[id].icon end
        return plainInstant(id)
    end
end
C_Item.GetItemNameByID = function(id) return items[id] and items[id].name end
C_Item.GetItemIconByID = function(id) return items[id] and items[id].icon end
C_Item.RequestLoadItemDataByID = function(id) requested[id] = true end
C_Item.GetItemCooldown = function(id)
    local c = itemCooldowns[id]
    if not c then return 0, 0, true end
    return c.start, c.length, true
end
C_DurationUtil = { CreateDuration = function() return NewDuration(0) end }

-- Tooltips: the processor's one catch-all post-call, and a tooltip whose
-- lines are reused the way the game's are.
Enum.TooltipDataType = { Item = 0, Spell = 1, Unit = 2, UnitAura = 7, Mount = 10,
                         PetAction = 11, Toy = 19, Macro = 25 }
local postCalls = {}
TooltipDataProcessor = {
    AllTypes = "ALL",
    AddTooltipPostCall = function(kind, fn)
        postCalls[kind] = postCalls[kind] or {}
        table.insert(postCalls[kind], fn)
    end,
}
GameTooltipText, GameTooltipTextSmall = { name = "normal" }, { name = "small" }
-- Both at 12, as the addon makes every tooltip font (ActionBars\GameFrames.lua).
function GameTooltipText.GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function GameTooltipTextSmall.GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
C_MountJournal = { GetMountInfoByID = function(id) if id == 77 then return "Horse", 458 end end }
actions = {}        -- slot -> { kind, id }
function GetActionInfo(slot) local a = actions[slot]; if a then return a[1], a[2], a[3] end end
function GetMacroSpell(index) return index == 3 and 2983 or nil end
function GetPetActionInfo(index)
    if index == 4 then return "Bite", "icon", false, false, true, true, 17253 end
end

local tip = CreateFrame("Frame", "TestTooltip", UIParent)
tip.count, tip.pool = 0, {}
function tip:AddLine(text, r, g, b)
    self.count = self.count + 1
    local line = self.pool[self.count]
    if not line then
        line = newWidget("FontString", self)
        line.fontObject = GameTooltipText
        function line:GetFontObject() return self.fontObject end
        self.pool[self.count] = line
        _G["TestTooltipTextLeft" .. self.count] = line
    end
    line.text, line.textColor = text, { r, g, b }
end
function tip:NumLines() return self.count end
function tip:ClearLines()
    self.count = 0
    self.info = nil
    for _, hook in ipairs(self.hooks.OnTooltipCleared or {}) do hook(self) end
end
function tip:GetPrimaryTooltipInfo() return self.info end
function tip:Show() end

local function Hover(data, info)
    tip:ClearLines()
    tip.info = info
    tip:AddLine("Some Title")
    tip:AddLine("A line of text")
    for _, fn in ipairs(postCalls.ALL or {}) do fn(tip, data) end
end

-------------------------------------------------------------------------------

-- The game's seconds formatter, as far as the addon sets it up: kept so a test
-- can see how it rounds.
Enum.LuaCurveType = Enum.LuaCurveType or { Linear = 0, Step = 1 }
Enum.SecondsFormatterInterval = { Seconds = 0, Minutes = 1, Hours = 2, Days = 3 }
Enum.SecondsFormatterAbbreviation = { None = 0, Truncate = 1, OneLetter = 2 }
Enum.SecondsFormatterRounding = { RoundUp = 0, Truncate = 1 }
formatterMade = nil
C_StringUtil = {
    CreateSecondsFormatter = function()
        local f = {}
        for _, method in ipairs({ "SetDefaultAbbreviation", "SetRounding", "SetCanRoundUpLastUnit",
                                  "SetMinInterval", "SetMaxIntervalCurve", "SetDesiredUnitCount" }) do
            f[method] = function(self, value) self[method .. "Value"] = value end
        end
        formatterMade = f
        return f
    end,
}

-- Seal of Command: no cooldown of its own, three ranks, two in the spellbook
-- and the highest known to the game by name. Base cooldowns are static spell
-- data, in milliseconds; everything else here has one.
spells[20375] = { name = "Seal of Command" }
spells[20915] = { name = "Seal of Command" }
spells[20918] = { name = "Seal of Command" }
baseCooldowns = { [20375] = 0, [20915] = 0, [20918] = 0, [800] = 0 }
-- The auras on you, by spell ID, as the game answers GetPlayerAuraBySpellID -
-- nil while auras are secret (aurasSecret), as it does in combat. Holy Light
-- (800) stands for a spell with no cooldown that leaves no buff.
auras = {}
spells[800] = { name = "Holy Light" }
C_UnitAuras = {
    GetPlayerAuraBySpellID = function(id)
        if aurasSecret then return nil end
        return auras[id]
    end,
}
-- Casting a spell: the game's event, then the moment the addon looks.
local function Cast(id)
    pendingTimer = nil
    Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. id, id)
    if pendingTimer then pendingTimer() end
end
function GetSpellBaseCooldown(id) return baseCooldowns[id] or 10000, 1500 end
do
    local plainInfo = C_Spell.GetSpellInfo
    C_Spell.GetSpellInfo = function(spell)
        if spell == "Seal of Command" then return { name = spell, spellID = 20918 } end
        return plainInfo(spell)
    end
end
spellbook = { { spellID = 100, name = "Charge" }, { spellID = 20375, name = "Seal of Command" },
              { spellID = 20915, name = "Seal of Command" } }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #spellbook } end,
    GetSpellBookItemInfo = function(slot) return spellbook[slot] end,
}
aurasSecret = false
C_Secrets = { ShouldAurasBeSecret = function() return aurasSecret end }

LoadAddon()
Login()

local Core = DogsForeverUI
local NS = Core.Cooldowns
local DB = NS.db
local holder = NS.holder
local GAP = 6 + 2 * Core.Style.BORDER_INSET
local step = DB.barHeight + GAP

Section("the defaults")
check("always on - no switch - with IDs on tooltips, tracking nothing",
    DB.enabled == nil and DB.showTooltipIDs == true and #DB.tracked == 0)
check("the player frame's width and the castbar's height",
    DB.barWidth == Core.Frames.db.barWidth and DB.barHeight == Core.Castbar.db.barHeight)
check("bars growing upward to start", DB.growDirection == "up")
check("placed by the addon", DB.autoPlaced == true)
check("nothing on screen with nothing to track", not holder:IsShown())
check("no cooldown asked about with nothing to track", #askedIgnoreGCD == 0)
check("nothing of the old ready icons left", NS.icons == nil and NS.MODES == nil
    and NS.SetMode == nil and DB.iconSize == nil)

Section("in line with the castbar, over the player frame's health bar")
do
    local p = holder.points
    check("the first bar's left edge on the player frame's, its top on the castbar's",
        p[1] == "TOPLEFT" and p[2] == UIParent and p[3] == "TOPLEFT"
        and p[4] == Core.Frames.db.playerLeft and p[5] == Core.Castbar.db.barTop,
        tostring(p[4]) .. "," .. tostring(p[5]))
    check("and the Positions boxes say so",
        DB.barLeft == Core.Frames.db.playerLeft and DB.barTop == Core.Castbar.db.barTop)

    local castTop, playerLeft = Core.Castbar.db.barTop, Core.Frames.db.playerLeft
    Core.Castbar.db.barTop = castTop + 40
    Core.Frames.db.playerLeft = playerLeft - 25
    NS.Update()
    NS.Refresh()
    Fire("PLAYER_ENTERING_WORLD")
    check("worked out once: the castbar or the player frame moving leaves the bars where they are",
        holder.points[4] == playerLeft and holder.points[5] == castTop
        and DB.barLeft == playerLeft and DB.barTop == castTop)
    Core.Castbar.db.barTop, Core.Frames.db.playerLeft = castTop, playerLeft
    NS.Update()
    check("a cooldown's time rounded up to the second, as the action buttons count",
        NS.formatter ~= nil
        and NS.formatter.SetRoundingValue == Enum.SecondsFormatterRounding.RoundUp)
    check("a buff's truncated, as the game's own buff timers count",
        NS.auraFormatter ~= nil and NS.auraFormatter ~= NS.formatter
        and NS.auraFormatter.SetRoundingValue == Enum.SecondsFormatterRounding.Truncate)
end

Section("adding by ID")
do
    local ok, message = NS.Add("spell", "abc")
    check("not a number is refused", not ok and message:find("whole number") ~= nil, message)
    ok, message = NS.Add("spell", 12.5)
    check("nor a fraction", not ok)
    ok, message = NS.Add("spell", 999)
    check("an ID no spell has is refused", not ok and message == "No spell has the ID 999.", message)
    ok, message = NS.Add("spell", "100")
    check("a spell is added, typed as text", ok and message == "Tracking Charge.", message)
    check("with nothing but its kind and ID", DB.tracked[1].mode == nil)
    ok, message = NS.Add("spell", 100)
    check("but only once", not ok and message == "Charge is already tracked.", message)
    ok = NS.Add("item", 6948)
    check("an item is added", ok)
    ok, message = NS.Add("item", 1)
    check("an ID no item has is refused", not ok and message == "No item has the ID 1.", message)
    NS.Add("spell", 200)
    check("in the order added",
        DB.tracked[1].kind == "spell" and DB.tracked[1].id == 100
        and DB.tracked[2].kind == "item" and DB.tracked[2].id == 6948
        and DB.tracked[3].id == 200)
end

Section("nothing cooling down, nothing shown")
Tick(0.2)
check("no bar", not NS.rows[1]:IsShown() and not NS.rows[2]:IsShown() and not NS.rows[3]:IsShown())

Section("a spell's cooldown starts")
cooldowns[100] = { start = now, length = 12 }
Fire("SPELL_UPDATE_COOLDOWN")
Tick(0.5)
do
    local row = NS.rows[1]
    check("its bar shows", row:IsShown() and row:GetAlpha() == 1)
    check("with its icon on the left", row.icon.texture == "icon100"
        and row.icon.points[1] == "TOPLEFT" and row.icon.width == DB.barHeight)
    check("its name", row.nameText.text == "Charge", row.nameText.text)
    check("run by the game from the cooldown's duration, draining",
        row.bar.timer ~= nil and row.bar.timer.direction == Enum.StatusBarTimerDirection.RemainingTime)
    check("the global cooldown left out of it", askedIgnoreGCD[#askedIgnoreGCD] == true)
    check("the time left", row.timeText.text == "12" or row.timeText.text == "11", row.timeText.text)
    check("in the first place", row.points[1] == "BOTTOMLEFT" and row.points[2] == holder
        and row.points[5] == 0)
end

Section("the global cooldown alone shows nothing")
gcdUntil = now + 1.5
Fire("SPELL_UPDATE_COOLDOWN")
Tick(0.2)
check("Mocking Blow, on the global cooldown only, has no bar", not NS.rows[3]:IsShown())
Tick(0.2)
check("nor while it lasts", not NS.rows[3]:IsShown())
gcdUntil = 0

Section("the bars stack UP in the order added and close up")
itemCooldowns[6948] = { start = now, length = 1800 }
cooldowns[200] = { start = now, length = 8 }
Fire("BAG_UPDATE_COOLDOWN")
Fire("SPELL_UPDATE_COOLDOWN")
Tick(0.5)
do
    check("three bars, each above the last",
        NS.rows[1].points[5] == 0 and NS.rows[2].points[5] == step and NS.rows[3].points[5] == 2 * step,
        tostring(NS.rows[2].points[5]))
    check("an item's bar, named and with its icon",
        NS.rows[2].nameText.text == "Hearthstone" and NS.rows[2].icon.texture == "hearth")
    check("run from a duration built from its (plain) numbers",
        NS.rows[2].bar.timer ~= nil and NS.rows[2].bar.timer.duration.remaining > 1799
        and NS.rows[2].bar.timer.duration.remaining <= 1800)

    cooldowns[100] = nil
    Tick(0.2)
    Tick(Core.Style.FADE_OUT + 0.1)
    check("a finished cooldown fades out with no event", not NS.rows[1]:IsShown())
    Tick(0.2)
    check("and the rest close up onto its place",
        NS.rows[2].points[5] == 0 and NS.rows[3].points[5] == step, tostring(NS.rows[2].points[5]))
end

Section("bars glide to a new place rather than jump")
do
    -- Charge cools down again: its bar takes the first place at once (it was
    -- not on screen, nothing to glide from); the two above glide up.
    cooldowns[100] = { start = now, length = 12 }
    Fire("SPELL_UPDATE_COOLDOWN")
    Tick(0.02)
    local y2, y3 = NS.rows[2].points[5], NS.rows[3].points[5]
    check("a bar coming on screen is put in its place at once",
        NS.rows[1]:IsShown() and NS.rows[1].points[5] == 0, tostring(NS.rows[1].points[5]))
    check("the one above it on its way up, not there yet", y2 > 0 and y2 < step, tostring(y2))
    check("and the next one too", y3 > step and y3 < 2 * step, tostring(y3))
    Tick(0.02)
    check("still rising", NS.rows[2].points[5] > y2 and NS.rows[2].points[5] < step,
        tostring(NS.rows[2].points[5]))
    check("kept to its side of the holder while it moves",
        NS.rows[2].points[1] == "BOTTOMLEFT" and NS.rows[2].points[2] == holder)
    for _ = 1, 10 do Tick(0.05) end
    check("arrives exactly on its place",
        NS.rows[2].points[5] == step and NS.rows[3].points[5] == 2 * step,
        tostring(NS.rows[2].points[5]) .. " " .. tostring(NS.rows[3].points[5]))

    -- The same at a slow frame rate: one long frame lands it, never past it.
    cooldowns[100] = nil
    Tick(0.2)
    Tick(Core.Style.FADE_OUT + 0.1)
    Tick(2)
    check("a long frame: there, not beyond",
        NS.rows[2].points[5] == 0 and NS.rows[3].points[5] == step, tostring(NS.rows[2].points[5]))

    -- A new place set half way: it turns towards that one.
    cooldowns[100] = { start = now, length = 12 }
    Fire("SPELL_UPDATE_COOLDOWN")
    Tick(0.02)
    cooldowns[100] = nil
    Fire("SPELL_UPDATE_COOLDOWN")
    Tick(0.2)
    Tick(Core.Style.FADE_OUT + 0.1)
    for _ = 1, 10 do Tick(0.05) end
    check("sent back half way, it settles where it now belongs",
        NS.rows[2].points[5] == 0 and NS.rows[3].points[5] == step, tostring(NS.rows[2].points[5]))

    -- A setting changed: everything at once, no glide.
    cooldowns[100] = { start = now, length = 12 }
    Fire("SPELL_UPDATE_COOLDOWN")
    Tick(0.02)
    NS.Refresh()
    check("a refresh puts every bar in its place at once",
        NS.rows[1].points[5] == 0 and NS.rows[2].points[5] == step and NS.rows[3].points[5] == 2 * step,
        tostring(NS.rows[2].points[5]))
    cooldowns[100] = nil
    Tick(0.2)
    Tick(Core.Style.FADE_OUT + 0.1)
    for _ = 1, 10 do Tick(0.05) end
end

Section("bars growing downward")
DB.growDirection = "down"
NS.Refresh()
check("a new direction: the bars are there at once",
    NS.rows[2].points[1] == "TOPLEFT" and NS.rows[2].points[5] == 0)
Tick(0.2)
check("the next bar UNDER the first",
    NS.rows[2].points[1] == "TOPLEFT" and NS.rows[2].points[5] == 0
    and NS.rows[3].points[1] == "TOPLEFT" and NS.rows[3].points[5] == -step,
    tostring(NS.rows[3].points[5]))
DB.growDirection = "up"
NS.Refresh()

Section("in combat: the numbers are secret, the bars carry on")
inCombat = true
cooldowns[100] = { start = now, length = 12 }
do
    local ok, err = pcall(function()
        Fire("SPELL_UPDATE_COOLDOWN")
        Tick(0.5)
    end)
    check("no secret is decided on", ok, tostring(err))
    local row = NS.rows[1]
    check("the bar shows all the same", row:IsShown())
    check("the time left handed to the text untouched", issecretvalue(row.timeText.text))
    cooldowns[100] = nil
    ok, err = pcall(function() Tick(0.2); Tick(Core.Style.FADE_OUT + 0.1) end)
    check("and ends when isActive says so", ok and not row:IsShown(), tostring(err))
end
inCombat = false

Section("a secret isActive is handed to the game, never looked at")
do
    secretActive = true
    cooldowns[100] = { start = now, length = 12 }
    local ok, err = pcall(function() Fire("SPELL_UPDATE_COOLDOWN"); Tick(0.2) end)
    local row = NS.rows[1]
    check("no error", ok, tostring(err))
    check("the game shows it while it cools down", row:IsShown() and row.alphaFrom ~= nil
        and row.alpha == 1)
    cooldowns[100] = nil
    Tick(0.2)
    check("and hides it after", row.alpha == 0)
    secretActive = false
    cooldowns = {}
    Tick(0.2)
    Tick(Core.Style.FADE_OUT + 0.1)
end

Section("a spell with charges")
NS.Add("spell", 300)
cooldowns[300] = { start = now, length = 20 }
spells[300].current = 1
Fire("SPELL_UPDATE_CHARGES")
Tick(0.5)
do
    local row = NS.rows[4]
    check("shows the next charge coming back", row:IsShown() and row.nameText.text == "Rush")
    check("with the charges on the icon", tostring(row.countText.text) == "1", tostring(row.countText.text))
    inCombat = true
    local ok, err = pcall(Tick, 0.2)
    check("a secret count is handed on, not read", ok and issecretvalue(row.countText.text), tostring(err))
    inCombat = false
end
cooldowns = {}
itemCooldowns = {}
Tick(0.2)
Tick(Core.Style.FADE_OUT + 0.1)

Section("removing")
check("no reordering: they stack in the order added", NS.Move == nil)
NS.Remove(4)
check("removed", #DB.tracked == 3)

Section("an item whose name is not loaded yet")
NS.Add("item", 5512)
check("is named by its ID meanwhile", select(1, NS.Describe(DB.tracked[4])) == "Item 5512")
check("and the game is asked for it", requested[5512] == true)

Section("a cooldown added by a rank you do not know")
do
    -- Frost Nova: rank 1 (450) long since replaced by rank 4 (451), the one
    -- the game knows by name. Ranks share one cooldown.
    spells[450] = { name = "Frost Nova" }
    spells[451] = { name = "Frost Nova" }
    local plainInfo = C_Spell.GetSpellInfo
    C_Spell.GetSpellInfo = function(spell)
        if spell == "Frost Nova" then return { name = spell, spellID = 451 } end
        return plainInfo(spell)
    end
    C_SpellBook.IsSpellInSpellBook = function(id) return id ~= 450 end
    NS.Add("spell", 450)                     -- index 5
    check("asked of the rank you know", NS.CooldownID(DB.tracked[5]) == 451)
    check("a rank you know is asked as added", NS.CooldownID(DB.tracked[1]) == 100)
    cooldowns[451] = { start = now, length = 25 }
    Fire("SPELL_UPDATE_COOLDOWN")
    Tick(0.2)
    check("so its bar shows when you cast rank 4",
        NS.rows[5]:IsShown() and NS.rows[5].bar.timer ~= nil
        and NS.rows[5].bar.timer.duration.remaining > 24, tostring(NS.rows[5]:IsShown()))
    check("named as added", NS.rows[5].nameText.text == "Frost Nova")
    cooldowns = {}
    NS.Remove(5)
    C_SpellBook.IsSpellInSpellBook = nil
    C_Spell.GetSpellInfo = plainInfo
    Tick(0.2)
    Tick(Core.Style.FADE_OUT + 0.1)
end

Section("a spell with no cooldown tracks its buff instead")
do
    local Durations = NS.Durations
    check("no container for buffs while nothing tracked needs one", Durations.container == nil)
    NS.Add("spell", 20375)                   -- Seal of Command, index 5
    local entry = DB.tracked[5]
    check("Seal of Command: no cooldown of its own, so a duration bar and nothing else",
        not NS.HasCooldown(entry) and NS.ShowsBuff(entry) and not NS.ShowsCooldown(entry))
    check("Charge, with one, stays a cooldown bar to start",
        NS.HasCooldown(DB.tracked[1]) and NS.ShowsCooldown(DB.tracked[1])
        and not NS.ShowsBuff(DB.tracked[1]))
    check("an item only ever its cooldown",
        NS.ShowsCooldown(DB.tracked[2]) and not NS.ShowsBuff(DB.tracked[2]))
    -- Whether a spell leaves a buff on you is learned from casting it - the
    -- same for every spell; nothing about any spell is written down.
    local mocking = DB.tracked[3]
    check("Mocking Blow: a cooldown, no buff seen - its cooldown, no choice",
        not NS.HasChoice(mocking) and NS.TrackOf(mocking) == "cooldown" and mocking.buff == nil)
    NS.SetTrack(3, "both")
    check("and setting it to anything else changes nothing", NS.TrackOf(mocking) == "cooldown"
        and not NS.ShowsBuff(mocking))
    mocking.track = nil

    aurasSecret = true
    Cast(200)
    check("cast in combat with no buff to be seen: nothing learned (a missing buff proves nothing then)",
        mocking.buff == nil)
    aurasSecret = false
    Cast(200)
    check("cast out of combat, no buff on you: learned it leaves none", mocking.buff == false
        and not NS.HasChoice(mocking))

    auras[100] = { name = "Charge" }
    Cast(100)
    auras[100] = nil
    check("cast and its buff seen on you: learned it leaves one - and now the choice",
        DB.tracked[1].buff == true and NS.HasChoice(DB.tracked[1])
        and NS.TrackOf(DB.tracked[1]) == "cooldown")

    check("Seal of Command: no cooldown, its duration", not NS.HasChoice(entry) and NS.TrackOf(entry) == "buff")
    NS.Add("spell", 800)
    local holy = DB.tracked[#DB.tracked]
    check("a spell with no cooldown tracks its duration until seen otherwise", NS.TrackOf(holy) == "buff")
    Cast(800)
    check("cast and no buff: nothing to track", holy.buff == false and NS.TrackOf(holy) == nil
        and not NS.ShowsBuff(holy))
    NS.Remove(#DB.tracked)

    auras[20375] = { name = "Seal of Command" }
    NS.Refresh()
    check("a buff already on you is noticed when the list refreshes", entry.buff == true)
    auras[20375] = nil
    check("a cast of another spell teaches this one nothing", (function()
        Cast(7620)
        return entry.buff == true
    end)())

    local c = Durations.container
    check("the game's aura container for add-ons, on you",
        c ~= nil and c.template == "CustomAuraContainerTemplate" and c.unit == "player"
        and c.parent == holder and c.editModePreview == false)
    local group = c.auraGroups.tracked
    check("your helpful auras only", group and group.filter == "HELPFUL")
    local ids = group.candidateFilters.includeSpellIDs
    check("filtered to every rank: the ID added, the spellbook's, the game's highest",
        ids[20375] and ids[20915] and ids[20918] and not ids[100])

    local b = group.sample
    check("each bar built like a cooldown bar: its size",
        b.width == DB.barWidth and b.height == DB.barHeight, tostring(b.width))
    check("its time with the buff formatter, not the cooldowns'",
        b.durationTextOptions and b.durationTextOptions.textFormatter == NS.auraFormatter)
    check("its icon, its name, its time, handed to the game",
        b.iconRegion ~= nil and b.spellName ~= nil and b.durationText ~= nil and b.count ~= nil)
    check("a bar the game fills with the time ELAPSED, from the right",
        b.durationBar ~= nil and b.durationBarOptions.direction == Enum.StatusBarTimerDirection.ElapsedTime
        and b.durationBar.reverseFill == true)
    check("in the dark, over green: a timed buff drains, one that never ends stays full",
        b.durationBar.statusColor[1] < 0.1 and b.durationBar.statusColor[4] == 1)
    local greenFound = false
    for _, r in ipairs(b.durationBar.regions) do
        if r.layer == "BACKGROUND" and r.vertexColor and r.vertexColor[1] == Core.Style.DURATION_COLOR[1]
            and r.vertexColor[2] == Core.Style.DURATION_COLOR[2] then greenFound = true end
    end
    check("the duration green under it, apart from the cooldowns' gold", greenFound)
    local name = b.spellName
    check("the name kept clear of the time by a fixed space, not anchored to the time's text",
        name.anchors[2][2] == b.durationBar and name.anchors[2][1] == "RIGHT")

    check("stacked in one column, growing up",
        c.flowAxis == AnchorUtil.FlowLayoutAxis.Vertical and c.flowV == AnchorUtil.FlowDirection.Up
        and c.flowPoint == "BOTTOMLEFT" and c.points[2] == Durations.anchor)

    -- On top of the cooldown bars: two up, the buff stack starts above them.
    cooldowns[100] = { start = now, length = 12 }
    cooldowns[200] = { start = now, length = 12 }
    Fire("SPELL_UPDATE_COOLDOWN")
    Tick(0.2)
    Tick(0.5)
    local a = Durations.anchor.points
    check("on top of the cooldown bars showing", a[1] == "BOTTOMLEFT" and a[2] == holder
        and a[5] == 2 * step, tostring(a[5]))
    check("and never a cooldown bar of its own", not (NS.rows[5] and NS.rows[5]:IsShown()))
    cooldowns[100] = nil
    Tick(0.2)
    Tick(Core.Style.FADE_OUT + 0.1)
    Tick(0.2)
    check("moving down as they end", Durations.anchor.points[5] == step,
        tostring(Durations.anchor.points[5]))
    cooldowns = {}
    Tick(0.2)
    Tick(Core.Style.FADE_OUT + 0.1)
    Tick(0.2)

    DB.growDirection = "down"
    NS.Refresh()
    check("growing down: under the cooldown bars, stacking down",
        Durations.anchor.points[1] == "TOPLEFT" and c.flowV == AnchorUtil.FlowDirection.Down
        and c.flowPoint == "TOPLEFT")
    DB.growDirection = "up"
    NS.Refresh()

    spellbook[#spellbook + 1] = { spellID = 20919, name = "Seal of Command" }
    Fire("SPELLS_CHANGED")
    check("a rank learned is added to the filter",
        c.auraGroups.tracked.candidateFilters.includeSpellIDs[20919] == true)

    local width = DB.barWidth
    DB.barWidth = width + 20
    aurasSecret = true
    NS.Refresh()
    check("a new size waits while the game keeps the bars from the addon", b.width == width)
    aurasSecret = false
    NS.Refresh()
    check("and reaches them once it does not", b.width == width + 20)
    check("without touching the name or the time, which the game owns: both keep their anchors",
        #b.spellName.anchors == 2 and b.spellName.anchors[1][2] == b.durationBar
        and #b.durationText.anchors == 1)
    Fire("SPELLS_CHANGED")
    check("nor on every spellbook change", #b.spellName.anchors == 2)
    DB.barWidth = width
    NS.Refresh()

    NS.Remove(5)
    check("nothing left to track by buff: the container stops",
        c.aurasEnabled == false and c.shown == false)
end

Section("a spell with a cooldown: Cooldown, Duration or Both")
do
    local Durations = NS.Durations
    local charge = DB.tracked[1]             -- Charge, spell 100: has a cooldown
    check("the three choices, Duration being its buff's",
        NS.TRACK[1].label == "Cooldown" and NS.TRACK[2].label == "Duration" and NS.TRACK[3].label == "Both")
    check("Cooldown to start, stored as nothing", NS.TrackOf(charge) == "cooldown" and charge.track == nil)

    NS.SetTrack(1, "both")
    check("Both: a cooldown bar and a duration bar",
        NS.ShowsCooldown(charge) and NS.ShowsBuff(charge) and charge.track == "both")
    NS.Add("spell", 20375)                   -- so the duration container exists
    local c = Durations.container
    check("its buff joins the duration filter",
        c.auraGroups.tracked.candidateFilters.includeSpellIDs[100] == true)
    cooldowns[100] = { start = now, length = 12 }
    Fire("SPELL_UPDATE_COOLDOWN")
    Tick(0.2)
    check("and its cooldown bar still shows", NS.rows[1]:IsShown())

    NS.SetTrack(1, "buff")
    Tick(0.2)
    check("Duration: its buff only - no cooldown bar",
        not NS.ShowsCooldown(charge) and NS.ShowsBuff(charge) and not NS.rows[1]:IsShown()
        and c.auraGroups.tracked.candidateFilters.includeSpellIDs[100] == true)

    NS.SetTrack(1, "cooldown")
    check("Cooldown again: out of the filter, stored as nothing",
        charge.track == nil and c.auraGroups.tracked.candidateFilters.includeSpellIDs[100] == nil)
    NS.SetTrack(1, "sideways")
    check("a value that is not one is the default", charge.track == nil)

    cooldowns = {}
    NS.Remove(#DB.tracked)
    Tick(0.2)
    Tick(Core.Style.FADE_OUT + 0.1)
end

Section("unlocked: every bar full, to drag")
Core.SetUnlocked(true)
do
    local first = NS.rows[1]
    check("shown", holder:IsShown() and first:IsShown() and NS.rows[4]:IsShown())
    local name = NS.Describe(NS.db.tracked[1])
    check("each bar as it really looks: what it tracks, and nothing more",
        first.points[5] == 0 and first.nameText.text == name
        and first.timeText.text == "", first.nameText.text)
    check("full, on its own background",
        first.bar.value == 1 and not PlacingLook(first.bg))
    check("taking the mouse", first.mouseEnabled == true)
    first.scripts.OnMouseDown(first, "LeftButton")
    check("dragging moves them all", holder.moving == true)
    holder.left, holder.top = 700, 1080 - 90
    first.scripts.OnMouseUp(first, "LeftButton")
    check("and the spot is kept as the player's, off the castbars",
        DB.barLeft == 700 and DB.barTop == -90 and DB.autoPlaced == false
        and holder.points[2] == UIParent)
    pendingTimer = nil
    first.scripts.OnMouseUp(first, "RightButton")
    check("a right-click does nothing: still unlocked", Core.IsUnlocked() and pendingTimer == nil
        and DB.barLeft == 700)
    Core.SetUnlocked(false)
    check("locked from the dialog: the bars stop taking the mouse", first.mouseEnabled == false)
end

Section("reset everything keeps the list")
-- (The cooldowns' own first place: the addon's layout over it, laid out by
-- the reset too, is tests\places.lua's.)
local layOut = Core.DefaultPlaces.Apply
Core.DefaultPlaces.Apply = function() return false end
Core:ResetAll()
Core.DefaultPlaces.Apply = layOut
check("the settings are back to defaults, in line with the castbar again",
    DB.autoPlaced == true and holder.points[5] == Core.Castbar.db.barTop
    and holder.points[4] == Core.Frames.db.playerLeft)
check("the tracked list is the player's and stays", #DB.tracked == 4)

Section("a saved list is cleaned on load")
do
    -- A reload starts the game's tooltip processor afresh too.
    for kind in pairs(postCalls) do postCalls[kind] = nil end
    Reload({ cooldowns = { barWidth = 130, iconSize = 26, growDirection = "sideways", tracked = {
        { kind = "spell", id = 100 }, { kind = "spell", id = 100 }, { kind = "pet", id = 3 },
        "junk", { kind = "item", id = -2 }, { kind = "item", id = 6948, mode = "ready" },
        { kind = "spell", id = 200, mode = "cooldown" },
        { kind = "spell", id = 300, track = "both" }, { kind = "spell", id = 20375, track = "weird" },
    } } })
    Login()
    local db = DogsForeverUI.Cooldowns.db
    local tracked = db.tracked
    check("twice, unknown kinds and nonsense dropped, the order kept",
        #tracked == 5 and tracked[1].id == 100 and tracked[2].id == 6948 and tracked[3].id == 200, #tracked)
    check("what a spell tracks is kept, an unknown value dropped",
        tracked[4].track == "both" and tracked[5].track == nil)
    check("an old tracked spell is kept, as a bar like the rest",
        tracked[2].mode == nil and tracked[3].mode == nil)
    check("the old icon size is dropped", db.iconSize == nil)
    check("a width an older version defaulted to becomes the player frame's", db.barWidth == 150, db.barWidth)
    check("a direction that is not one goes back to upward", db.growDirection == "up")
end

-------------------------------------------------------------------------------
Section("IDs on tooltips")
do
    local kinds = Enum.TooltipDataType
    local NS2 = DogsForeverUI.Cooldowns
    check("one hook for every kind of tooltip", postCalls.ALL ~= nil and #postCalls.ALL == 1)

    Hover({ type = kinds.Spell, id = 2983 })
    local last = tip.pool[tip.count]
    check("a spell's ID, last", tip.count == 3 and last.text == "Spell ID 2983", last.text)
    local idFont = _G.DogsForeverUITooltipIDFont
    check("small: a font of the addon's own, smaller than the tooltips' 12 (their small font is 12 too)",
        idFont ~= nil and last.fontObject == idFont and select(2, idFont:GetFont()) == 10)
    check("and grey", last.textColor[1] == last.textColor[2] and last.textColor[1] < 0.7)

    Hover({ type = kinds.Item, id = 6948 })
    check("an item's", tip.pool[tip.count].text == "Item ID 6948")
    check("the lines before it are their normal size", tip.pool[2].fontObject == GameTooltipText)
    Hover({ type = kinds.UnitAura, id = 774 })
    check("an aura's", tip.pool[tip.count].text == "Spell ID 774")
    Hover({ type = kinds.Mount, id = 77 })
    check("a mount's spell, not its mount ID", tip.pool[tip.count].text == "Spell ID 458")

    Hover({ type = kinds.PetAction }, { getterName = "GetPetAction", getterArgs = { 4 } })
    check("a pet ability, from the pet bar button", tip.pool[tip.count].text == "Spell ID 17253",
        tip.pool[tip.count].text)
    forms = { { spellID = 71, active = false } }
    Hover({ type = kinds.Spell }, { getterName = "GetShapeshift", getterArgs = { 1 } })
    check("a stance, from the stance button", tip.pool[tip.count].text == "Spell ID 71",
        tip.pool[tip.count].text)
    forms = {}
    actions[12] = { "macro", 3 }
    Hover({ type = kinds.Macro }, { getterName = "GetAction", getterArgs = { 12 } })
    check("a macro's spell, from the action button", tip.pool[tip.count].text == "Spell ID 2983",
        tip.pool[tip.count].text)
    -- #showtooltip: the game hands the shown spell's own ID back, not the macro's index.
    actions[14] = { "macro", 12294, "spell" }
    Hover({ type = kinds.Macro }, { getterName = "GetAction", getterArgs = { 14 } })
    check("a macro showing a spell: that spell's ID", tip.pool[tip.count].text == "Spell ID 12294",
        tip.pool[tip.count].text)
    actions[15] = { "macro", 6948, "item" }
    Hover({ type = kinds.Macro }, { getterName = "GetAction", getterArgs = { 15 } })
    check("a macro showing an item: that item's ID", tip.pool[tip.count].text == "Item ID 6948",
        tip.pool[tip.count].text)
    actions[13] = { "item", 6948 }
    Hover({ type = kinds.Macro }, { getterName = "GetAction", getterArgs = { 13 } })
    check("an item on an action button", tip.pool[tip.count].text == "Item ID 6948")
    Hover({ type = kinds.Unit, guid = "Creature-1" })
    check("nothing for a unit", tip.count == 2)

    tip:ClearLines()
    tip:AddLine("One")
    tip:AddLine("Two")
    tip:AddLine("Three")
    check("a small line goes back to normal once the tooltip is cleared",
        tip.pool[3].fontObject == GameTooltipText)

    -- An aura the client restricts (Clearcasting): its ID secret. Handed to
    -- the line's own SetFormattedText, never read (the stand-in errors if
    -- compared, and cannot be formatted by real Lua, so the line keeps it).
    local secretID = SecretCastValue("aura id")
    local ok, err = pcall(Hover, { type = kinds.UnitAura, id = secretID })
    check("a secret ID: no error, never looked at", ok, tostring(err))
    check("still shown: handed to the line itself, small and grey",
        tip.count == 3 and tip.pool[3].text == secretID and tip.pool[3].fontObject == _G.DogsForeverUITooltipIDFont
        and tip.pool[3].textColor[1] < 0.7)
    -- The kind secret too: the getter says it was an aura's tooltip.
    local secretKind = SecretCastValue("tooltip kind")
    ok, err = pcall(Hover, { type = secretKind, id = secretID },
        { getterName = "GetUnitAuraByAuraInstanceID", getterArgs = { "player", 41 } })
    check("its kind secret as well: an aura's, from the getter", ok and tip.count == 3
        and tip.pool[3].text == secretID, tostring(err))
    ok, err = pcall(Hover, { type = secretKind, id = secretID }, { getterName = "GetHyperlink", getterArgs = { "x" } })
    check("secret and from something else: no line, no guess", ok and tip.count == 2, tostring(err))

    tip:ClearLines()
    tip:AddLine("Title")
    postCalls.ALL[1](tip, { type = kinds.Spell, id = 5 })
    postCalls.ALL[1](tip, { type = kinds.Spell, id = 5 })
    check("a tooltip processed twice gets one line", tip.count == 2)

    NS2.db.showTooltipIDs = false
    Hover({ type = kinds.Spell, id = 2983 })
    check("switched off, no line", tip.count == 2)
end

Section("one Add for spells and items: what an ID is, worked out")
do
    local CD = DogsForeverUI.Cooldowns
    local tracked = CD.db.tracked
    for index = #tracked, 1, -1 do tracked[index] = nil end
    local function Last() return tracked[#tracked] end

    -- 4000 is both a spell and an item; 6948 an item only, 200 a spell only.
    spells[4000] = { name = "Shared Spell" }
    items[4000] = { name = "Shared Item", icon = "shared" }
    local inBook, bags, worn = {}, {}, {}
    C_SpellBook.IsSpellInSpellBook = function(id) return inBook[id] == true end
    C_Item.GetItemCount = function(id) return bags[id] or 0 end
    C_Item.IsEquippedItem = function(id) return worn[id] == true end

    local ok, message = CD.AddID("6948")
    check("a bare number only an item has: the item", ok and Last().kind == "item" and Last().id == 6948, message)
    ok, message = CD.AddID(" 200 ")
    check("only a spell has: the spell", ok and Last().kind == "spell" and Last().id == 200, message)
    ok, message = CD.AddID("424242")
    check("nothing has it: refused", not ok and message == "No spell or item has the ID 424242.", message)
    ok, message = CD.AddID("abc")
    check("not a number: refused", not ok and message:find("whole number") ~= nil, message)
    ok, message = CD.AddID("12.5")
    check("nor a fraction", not ok)

    -- Clearcasting (16870) is also an item: a proc, never in a spellbook,
    -- with no cooldown of its own.
    baseCooldowns[4000] = 0
    ok, message = CD.AddID("4000")
    check("both have it and neither is yours: the spell (a proc's buff), the line says how to get the item",
        ok and Last().kind == "spell" and Last().id == 4000
        and message == "Tracking Shared Spell. For the item Shared Item, type item 4000.", message)
    check("and it tracks its duration", CD.TrackOf(Last()) == "buff")
    table.remove(tracked)
    bags[4000] = 2
    ok = CD.AddID("4000")
    check("the item in your bags: the item", ok and Last().kind == "item" and Last().id == 4000)
    table.remove(tracked)
    bags[4000] = nil
    worn[4000] = true
    ok = CD.AddID("4000")
    check("worn counts as yours", ok and Last().kind == "item")
    table.remove(tracked)
    worn[4000] = nil
    inBook[4000] = true
    ok = CD.AddID("4000")
    check("the spell in your spellbook: the spell", ok and Last().kind == "spell" and Last().id == 4000)
    table.remove(tracked)
    bags[4000] = 1
    local count = #tracked
    ok, message = CD.AddID("4000")
    check("both yours: nothing added, and the line says how to pick", not ok and #tracked == count
        and message == "4000 is the spell Shared Spell and the item Shared Item: type spell 4000 or item 4000.",
        message)
    bags[4000], inBook[4000] = nil, nil

    -- Another rank known by the name counts as having the spell: with the
    -- item in your bags as well, both are yours and it asks.
    items[20375] = { name = "Some Item" }
    bags[20375] = 1
    check("(an ID that is an item too, the item yours: the item)",
        CD.AddID("20375") == true and Last().kind == "item")
    table.remove(tracked)
    inBook[20918] = true
    check("a rank you do not have, when the game knows another by its name: yours",
        CD.AddID("20375") == false)
    inBook[20918], items[20375], bags[20375] = nil, nil, nil

    for _, typed in ipairs({ "item 4000", "Item ID 4000", "item:4000", "I4000", "itemid 4000" }) do
        ok = CD.AddID(typed)
        check("\"" .. typed .. "\" adds the item", ok and Last().kind == "item" and Last().id == 4000)
        table.remove(tracked)
    end
    for _, typed in ipairs({ "spell 4000", "Spell ID 4000", "s 4000", "s4000" }) do
        ok = CD.AddID(typed)
        check("\"" .. typed .. "\" adds the spell", ok and Last().kind == "spell" and Last().id == 4000)
        table.remove(tracked)
    end
    ok, message = CD.AddID("item 200")
    check("a kind typed is taken at its word", not ok and message == "No item has the ID 200.", message)
    ok, message = CD.AddID("toy 4000")
    check("an unknown word is refused", not ok and message == "Type an ID, or spell or item and an ID.", message)
end

Summary()
