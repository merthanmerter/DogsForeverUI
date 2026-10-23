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
check("nothing of the old per-entry modes left", NS.MODES == nil and NS.SetMode == nil)

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

-- (The player, 2026-10-17: Dash gone after a loading screen until a form change.)
Section("after a loading screen: a cooldown never lost to a late or wrong answer, with no event")
do
    local plain = C_Spell.GetSpellCooldown
    local function Answer(field, value)
        C_Spell.GetSpellCooldown = function(id)
            local info = plain(id)
            if info then info[field] = value end
            return info
        end
    end
    local function Gone()
        cooldowns[200] = nil
        for _ = 1, 10 do Tick(0.1) end
    end
    Answer("isActive", false)
    cooldowns[200] = { start = now, length = 30 }
    Fire("PLAYER_ENTERING_WORLD")
    Tick(0.2)
    check("while the world loads the game says it is not cooling down: no bar", not NS.rows[3]:IsShown())
    C_Spell.GetSpellCooldown = plain
    Tick(0.2)
    check("then it does, and no event comes: its bar all the same", NS.rows[3]:IsShown())
    Gone()
    Answer("isOnGCD", true)
    cooldowns[200] = { start = now, length = 30 }
    Fire("SPELL_UPDATE_COOLDOWN")
    Tick(0.2)
    check("taken for the global cooldown on the event: no bar", not NS.rows[3]:IsShown())
    C_Spell.GetSpellCooldown = plain
    Tick(1.4)
    Tick(0.1)
    check("never past a global cooldown's length, with no event: its bar", NS.rows[3]:IsShown())
    Gone()
end

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

-- (The player, 2026-10-22, in Shadow: Prayer of Mending, not had in that spec, showed a
-- cooldown as Power Word: Shield was cast - the game answers a spell not learnt with
-- some other cooldown.)
Section("a spell not had now (another spec's, a talent not taken) shows no cooldown")
do
    unknownSpells[100] = true
    NS.Durations.Refresh()
    Tick(0.2)
    Tick(Core.Style.FADE_OUT + 0.1)
    check("its cooldown running by the game's word: no bar", not NS.rows[1]:IsShown())
    unknownSpells[100] = nil
    NS.Durations.Refresh()
    Tick(0.2)
    check("had again (the spec changed back): its bar", NS.rows[1]:IsShown())
end

-- (The player, 2026-10-22: reading C_Spell.GetOverrideSpell's ID instead made some cooldowns
-- show late - its variant read as the global cooldown at first.)
Section("a spell's own cooldown is read, never the ID GetOverrideSpell hands back")
do
    local asked = {}
    local plain = C_Spell.GetSpellCooldown
    C_Spell.GetSpellCooldown = function(id)
        asked[id] = true
        return plain(id)
    end
    C_Spell.GetOverrideSpell = function(id) return id == 100 and 101 or id end
    Tick(0.2)
    check("its own ID asked, the variant never", asked[100] and not asked[101] and NS.rows[1]:IsShown())
    C_Spell.GetOverrideSpell, C_Spell.GetSpellCooldown = nil, plain
end

Section("the global cooldown alone shows nothing")
gcdUntil = now + 1.5
Fire("SPELL_UPDATE_COOLDOWN")
Tick(0.2)
check("Mocking Blow, on the global cooldown only, has no bar", not NS.rows[3]:IsShown())
Tick(0.2)
check("nor while it lasts", not NS.rows[3]:IsShown())
-- (The player, 2026-10-20: "0 s" icons as a cast ends.) The game says the
-- spell is not on the global cooldown for the GCD's last moments.
do
    local plain = C_Spell.GetSpellCooldown
    C_Spell.GetSpellCooldown = function(id)
        local info = plain(id)
        if info then info.isOnGCD = false end
        return info
    end
    Tick(0.9)
    Fire("SPELL_UPDATE_COOLDOWN")
    Tick(0.1)
    check("a cast ending in the GCD's last moments: still no bar", not NS.rows[3]:IsShown())
    C_Spell.GetSpellCooldown = plain
end
gcdUntil = 0
Tick(0.2)

-- (The player, 2026-10-22: some cooldowns showed late - a spell cast right as another's
-- global cooldown ended was kept hidden for the rest of 1.5 s.)
Section("a cooldown cast within another's global cooldown shows at once")
do
    local id = DB.tracked[3].id
    gcdUntil = now + 1.5
    Fire("SPELL_UPDATE_COOLDOWN")
    Tick(0.1)
    cooldowns[id] = { start = now, length = 20 }
    Cast(id)
    Fire("SPELL_UPDATE_COOLDOWN")
    Tick(0.01)
    check("secret (a fight): its own cast clears the global cooldown's mark - at once", NS.rows[3]:IsShown())
    cooldowns[id], gcdUntil = nil, 0
    Tick(0.2)
    Tick(Core.Style.FADE_OUT + 0.1)

    -- Out of a fight (and on Forever) the game answers plainly whether anything of its own is left.
    local plainDuration = C_Spell.GetSpellCooldownDuration
    C_Spell.GetSpellCooldownDuration = function(spell, ignoreGCD)
        local d = plainDuration(spell, ignoreGCD)
        function d:IsZero() return self.remaining <= 0 end
        return d
    end
    local plain = C_Spell.GetSpellCooldown
    gcdUntil = now + 1.5
    Fire("SPELL_UPDATE_COOLDOWN")
    Tick(0.1)
    check("plain: the global cooldown alone, no bar", not NS.rows[3]:IsShown())
    C_Spell.GetSpellCooldown = function(spell)
        local info = plain(spell)
        if info then info.isOnGCD = false end
        return info
    end
    Fire("SPELL_UPDATE_COOLDOWN")
    Tick(0.1)
    check("plain: a global cooldown's last moments told wrong - still no \"0 s\" bar", not NS.rows[3]:IsShown())
    cooldowns[id] = { start = now, length = 20 }
    Fire("SPELL_UPDATE_COOLDOWN")
    Tick(0.01)
    check("plain: its own cooldown at once, no cast event needed", NS.rows[3]:IsShown())
    C_Spell.GetSpellCooldown, C_Spell.GetSpellCooldownDuration = plain, plainDuration
    cooldowns[id], gcdUntil = nil, 0
    Tick(0.2)
    Tick(Core.Style.FADE_OUT + 0.1)
end

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

Section("bar or icon, each entry its own: square icons in rows")
do
    local iconHolder, icons, rows = NS.iconHolder, NS.icons, NS.rows
    local Style = Core.Style
    local function At(frame) return frame.points[4], frame.points[5] end
    local function Near(a, b) return math.abs(a - b) < 0.01 end
    local function Spot(frame, x, y)
        local fx, fy = At(frame)
        return frame.points[2] == iconHolder and frame.points[1] == "CENTER" and Near(fx, x) and Near(fy, y)
    end
    -- (A buff button's pieces are a table of their own: its border found as its child.)
    local function BorderOf(frame)
        for _, f in ipairs(allFrames) do
            if f.parent == frame and f.spec then return f end
        end
    end
    local function Bordered(frame, colour)
        local border = BorderOf(frame)
        local spec = border and border.spec
        local line = spec and spec.lines[1]
        return spec ~= nil and spec.radius == Style.DEFAULT_BORDER.radius and #spec.lines == 1
            and line[1] == colour[1] and line[2] == colour[2] and line[3] == colour[3]
            and border.unitPixels == 1
    end
    -- (The player, 2026-10-22: both sides from the middle, by default.)
    -- (The player, 2026-10-23: the default icon size 30; then 32.)
    check("a bar to start; icons 32 across, 5 to a row, both sides, rows growing up",
        NS.DisplayOf(DB.tracked[1]) == "bar" and DB.tracked[1].display == nil
        and NS.defaults.iconSize == 32 and NS.defaults.iconsPerRow == 5
        and NS.defaults.iconGrow == "center" and NS.defaults.iconRowsGrow == "up")
    DB.iconGrow = "right"
    cooldowns[100] = { start = now, length = 12 }
    cooldowns[200] = { start = now, length = 90 }
    itemCooldowns[6948] = { start = now, length = 1800 }
    NS.SetDisplay(1, "icon")
    NS.SetDisplay(3, "icon")
    local size = DB.iconSize
    local step = size + 6           -- an icon and the gap between two
    check("bars and icons at once: the bars' holder and the icons' both shown",
        holder:IsShown() and iconHolder:IsShown() and DB.tracked[1].display == "icon")
    check("the item, still a bar, the first bar", rows[2]:IsShown() and rows[2].points[5] == 0
        and not rows[1]:IsShown() and not rows[3]:IsShown())
    check("the first icon's place an icon's size", iconHolder.width == size and iconHolder.height == size)
    local charge = icons[1]
    check("a square icon, the picture's baked edge cut off",
        charge:IsShown() and charge.width == size and charge.icon.texture == "icon100"
        and charge.icon.allPointsTo == charge and charge.icon.mask == nil)
    check("the action buttons' corners, one line a real pixel wide, a cooldown's gold",
        Bordered(charge, Style.COOLDOWN_COLOR))
    local swipe = charge.swipe
    check("its time a dark swipe over the picture, the part still to go",
        swipe.allPointsTo == charge and not swipe.reverse and swipe.drawEdge == false
        and swipe.durationObject ~= nil and swipe.durationObject.remaining > 11)
    check("the time inside it, in one unit (the bars' two)",
        charge.timeText.points[1] == "CENTER" and charge.timeText.points[2] == charge
        and charge.timeText.text ~= "" and NS.iconFormatter.SetDesiredUnitCountValue == 1
        and NS.formatter.SetDesiredUnitCountValue == 2)
    check("the first on the first place, the next icon to its right (the bar between counts not)",
        Spot(charge, 0, 0) and Spot(icons[3], step, 0))

    -- Two to a row: the third starts the next row, above.
    DB.iconsPerRow = 2
    NS.Add("spell", 300)
    cooldowns[300] = { start = now, length = 30 }
    NS.SetDisplay(4, "icon")
    check("so many to a row, the next row above", Spot(icons[4], 0, step))
    DB.iconGrow, DB.iconRowsGrow = "left", "down"
    NS.Refresh()
    check("or leftward, the next row below", Spot(icons[3], -step, 0) and Spot(icons[4], 0, -step))
    DB.iconGrow, DB.iconRowsGrow = "center", "up"
    NS.Refresh()
    check("or both sides: each row centred on the holder, a part-full one on what it holds",
        Spot(charge, -step / 2, 0) and Spot(icons[3], step / 2, 0) and Spot(icons[4], 0, step))
    DB.iconGrow = "right"
    NS.Refresh()

    -- Duration only (a spell with no cooldown): the game's group, which closes up
    -- by itself over a buff not on you - whether one is up is secret.
    NS.Add("spell", 20375)
    NS.SetDisplay(5, "icon")
    local group = NS.Durations.groups.icon
    local tracked = group and group.auraGroups.tracked
    check("a duration-only icon: the game's group on the icons' piece, every rank its filter",
        tracked ~= nil and group.parent == iconHolder and group.unit == "player" and group.aurasEnabled == true
        and tracked.candidateFilters.includeSpellIDs[20375] and tracked.candidateFilters.includeSpellIDs[20918])
    local bars = NS.Durations.groups.bar
    check("and not in the bars' group",
        bars == nil or bars.aurasEnabled == false
        or not bars.auraGroups.tracked.candidateFilters.includeSpellIDs[20375])
    local anchor = NS.Durations.anchors.icon
    -- (The player, 2026-10-17: a duration icon started a new row after a part-full one.)
    check("laid out as the cooldown icons, rightward, up, carrying on their row: the spot after the third, one column left",
        group.flowAxis == AnchorUtil.FlowLayoutAxis.Horizontal and group.flowPoint == "BOTTOMLEFT"
        and group.flowH == AnchorUtil.FlowDirection.Right and group.flowV == AnchorUtil.FlowDirection.Up
        and group.lineSize == size and tracked.layout.elementSpacing == 6
        and group.points[2] == anchor and Spot(anchor, step, step))
    DB.iconGrow = "center"
    NS.Refresh()
    -- (The player, 2026-10-22: "why some icons appear on 2nd row when there is room in 1st
    -- row"; 2026-10-23: "it should be completely centered, not one side growing longer".)
    check("both sides: the part-full last row shared, the game's group hung by its middle right of the row's",
        group.flowPoint == "BOTTOMLEFT" and group.points[1] == "BOTTOM" and group.points[3] == "BOTTOM"
        and group.lineSize == size and Spot(anchor, step / 2, step))
    local last = icons[4]
    check("that row's cooldown icon hung off the group's left edge, a gap clear: the whole row centred as one",
        last.points[1] == "BOTTOMLEFT" and last.points[2] == group and last.points[3] == "BOTTOMLEFT"
        and Near(last.points[4], -step) and Near(last.points[5], 0))
    check("made to be allowed there (the game refuses any other add-on frame)",
        last.template == "DisableUntrustedLayoutScriptsTemplate"
        and last.swipe.template == "DisableUntrustedLayoutScriptsTemplate")
    check("a full row before it: centred on the holder", Spot(charge, -step / 2, 0) and Spot(icons[3], step / 2, 0))
    -- (The player, 2026-10-23: "Style.lua:619 attempt to perform arithmetic on 'height' (a
    -- secret number)" - hung off the group, an icon's size is secret in a fight.)
    secretAnchoring = true
    check("laid out again in a fight: its size never read while hung there", pcall(NS.Refresh))
    secretAnchoring = false
    -- (The player, 2026-10-23: "icons sometimes jump to another position and come back ...
    -- when a single row has max icons".) A cooldown over: two left, a full row - the buffs
    -- a row of their own. Gliding there, the group dragged the icons hung off it along.
    local saved = cooldowns[300]
    cooldowns[300] = nil
    Tick(0.2)
    Tick(Core.Style.FADE_OUT + 0.1)
    Tick(0.15)
    check("the row's arrangement changed: the group's anchor there at once, never glided",
        Spot(anchor, 0, step) and not icons[4]:IsShown())
    cooldowns[300] = saved
    Tick(0.15)
    check("and back as the cooldown returns, at once too", Spot(anchor, step / 2, step) and icons[4].points[2] == group)
    NS.Unlock()
    check("placing: every icon on the holder, never on the group (Unlock Mode measures them)",
        icons[4].points[2] == iconHolder)
    NS.Lock()
    DB.iconsPerRow = 3
    NS.Refresh()
    check("after a full row: a row of their own, the group hung by its middle (it sizes itself)",
        group.points[1] == "BOTTOM" and group.points[3] == "BOTTOM" and group.lineSize == 3 * size + 12
        and Spot(anchor, 0, step))
    DB.iconsPerRow = 2
    refuseJoinable = true
    NS.Refresh()
    check("a client refusing even those: no icon lost - it keeps its spot, the group carries on the row",
        Spot(icons[4], 0, step) and group.points[1] == "BOTTOMLEFT" and Spot(anchor, step, step))
    refuseJoinable = nil
    DB.iconGrow = "right"
    NS.Refresh()
    local seal = tracked.sample
    check("square, a duration's green border; the game runs its time, in one unit, and fades it in",
        seal.iconRegion ~= nil and seal.iconRegion.allPointsTo == seal and Bordered(seal, Style.DURATION_COLOR)
        and seal.durationTextOptions.textFormatter == NS.iconAuraFormatter
        and seal.shownAnimation ~= nil and seal.shownAnimation.animations[1].kind == "Alpha")
    check("its swipe run by the game, darkening the part gone (one that never ends stays clear)",
        seal.cooldown ~= nil and seal.cooldown.reverse == true and seal.cooldown:GetParent() == seal)
    check("taking no mouse: the world under the icons stays clickable", seal.mouseEnabled == false)

    -- Both: the buff over the entry's own cooldown icon (or bar), shown first.
    DB.tracked[1].buff, DB.tracked[3].buff = true, true
    NS.SetTrack(1, "both")
    NS.SetDisplay(3, "bar")
    NS.SetTrack(3, "both")
    local overlays
    for _, f in ipairs(allFrames) do
        if f.auraSlots and f.auraSlots.icon1 then overlays = f end
    end
    local over = overlays and overlays.auraSlots.icon1.sample
    check("both, as an icon: one of the game's aura slots, the buff's ranks its filter",
        over ~= nil and overlays.aurasEnabled == true
        and overlays.auraSlots.icon1.candidateFilters.includeSpellIDs[100])
    check("covering the cooldown icon exactly, over it: the duration first, the cooldown as it ends",
        over.allPointsTo == charge and over:GetFrameLevel() > charge:GetFrameLevel()
        and Bordered(over, Style.DURATION_COLOR))
    local overBar = overlays.auraSlots.bar3 and overlays.auraSlots.bar3.sample
    check("both, as a bar: a buff bar over its own cooldown bar",
        overBar ~= nil and overBar.allPointsTo == rows[3] and overBar.durationBar ~= nil
        and overBar:GetFrameLevel() > rows[3]:GetFrameLevel())
    -- (The player, 2026-10-17: the buff bar over its cooldown bar came over the icons.)
    check("the icons over the bars and whatever covers them",
        iconHolder:GetFrameLevel() > overBar:GetFrameLevel() and charge:GetFrameLevel() > overBar:GetFrameLevel())
    -- (The player, 2026-10-17: the cooldown showed for a moment before its buff.)
    check("both: the cooldown unseen as it starts, its buff a moment behind the cast",
        charge:IsShown() and charge:GetAlpha() == 0 and rows[3]:GetAlpha() == 0)
    -- (The player, 2026-10-17: errors in combat - the game denies addons the
    -- buff's frame while auras are secret.)
    over.IsShown = function() error("denied while auras are secret") end
    Tick(0.5)
    check("then under its buff, hidden by it whole (time and count too), the buff never read",
        charge:IsShown() and charge:GetAlpha() == 1
        and over:GetFrameLevel() > charge.front:GetFrameLevel())
    over.IsShown = nil
    check("neither in a group: one spot each, not a second bar or icon",
        not group.auraGroups.tracked.candidateFilters.includeSpellIDs[100]
        and (bars == nil or bars.aurasEnabled == false
            or not bars.auraGroups.tracked.candidateFilters.includeSpellIDs[200]))
    check("a Both bar's spark hidden: taller than the bar, it poked out round its buff's",
        rows[3].spark:GetAlpha() == 0)
    -- (The player, 2026-10-22: Both entries' spots kept for good left gaps all through the
    -- bars - "all over the place, not stacking".)
    cooldowns[100] = nil
    Tick(0.2)
    Tick(Core.Style.FADE_OUT + 0.1)
    for _ = 1, 20 do Tick(0.05) end
    check("a Both entry's cooldown over: no gap left, the rest close up as ever",
        not charge:IsShown() and Spot(icons[4], 0, 0))
    cooldowns[100] = { start = now, length = 12 }
    NS.SetTrack(1, "cooldown")
    check("back to its cooldown only: its slot let go", overlays.auraSlots.icon1.enabled == false)
    NS.SetTrack(3, "cooldown")
    NS.SetDisplay(3, "icon")
    DB.tracked[1].buff, DB.tracked[3].buff = nil, nil

    cooldowns[100] = nil
    Tick(0.2)
    Tick(0.05)
    check("a finished one fades out in its place, with no event",
        charge:IsShown() and charge:GetAlpha() < 1 and Spot(charge, 0, 0))
    Tick(Core.Style.FADE_OUT + 0.1)
    for _ = 1, 20 do Tick(0.05) end
    check("gone; the next glides onto its place, the rest closing up behind it (the bars' glide)",
        not charge:IsShown() and Spot(icons[3], 0, 0) and Spot(icons[4], step, 0))
    check("the duration-only group following: the spot after theirs, a whole row wide",
        Spot(anchor, 0, step) and group.lineSize == 2 * size + 6)

    NS.Unlock()
    check("unlocked: each entry on its own piece, bars and icons",
        icons[1]:IsShown() and icons[5]:IsShown() and icons[1].icon.texture == "icon100"
        and rows[2]:IsShown() and not rows[1]:IsShown() and holder:IsShown() and iconHolder:IsShown())
    NS.Lock()

    local entry = Core.Snap.EntryById("cooldownicons")
    check("the icons their own piece in Unlock Mode, the bars' named Cooldown Bars",
        entry ~= nil and entry.frame == iconHolder and Core.Snap.NameOf(entry) == "Cooldown Icons"
        and Core.Snap.NameOf(Core.Snap.EntryById("cooldowns")) == "Cooldown Bars")

    NS.Remove(5)
    NS.Remove(4)
    check("no duration-only icon left: their group off", group.aurasEnabled == false)
    cooldowns[200], cooldowns[300], itemCooldowns[6948] = nil, nil, nil
    DB.iconsPerRow = NS.defaults.iconsPerRow
    NS.SetDisplay(1, "bar")
    NS.SetDisplay(3, "bar")
    check("no icon entry left: the icons away", holder:IsShown() and not iconHolder:IsShown()
        and DB.tracked[1].display == nil)
    Tick(Core.Style.FADE_OUT + 0.3)
end

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
    local loaded = false                     -- the spellbook, empty as the world loads
    C_Spell.GetSpellInfo = function(spell)
        if spell == "Frost Nova" and loaded then return { name = spell, spellID = 451 } end
        return plainInfo(spell)
    end
    C_SpellBook.IsSpellInSpellBook = function(id) return loaded and id ~= 450 end
    NS.Add("spell", 450)                     -- index 5
    NS.CooldownID(DB.tracked[5])
    loaded = true
    check("asked of the rank you know (an answer from before the spellbook loaded not kept)",
        NS.CooldownID(DB.tracked[5]) == 451)
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
    check("no container for buffs on while nothing tracked needs one",
        Durations.groups.bar == nil or Durations.groups.bar.aurasEnabled == false)
    NS.Add("spell", 20375)                   -- Seal of Command, index 5
    local entry = DB.tracked[5]
    check("Seal of Command: no cooldown of its own, so a duration bar and nothing else",
        not NS.HasCooldown(entry) and NS.ShowsBuff(entry) and not NS.ShowsCooldown(entry))
    check("Charge, with one, stays a cooldown bar to start",
        NS.HasCooldown(DB.tracked[1]) and NS.ShowsCooldown(DB.tracked[1])
        and not NS.ShowsBuff(DB.tracked[1]))
    check("an item only ever its cooldown",
        NS.ShowsCooldown(DB.tracked[2]) and not NS.ShowsBuff(DB.tracked[2]))
    -- (The player, 2026-10-21, of Swiftmend on Forever: "are we sure there are durations?
    -- this seems wrong" - no list says so there; a buff seen after their cast does.)
    local mocking = DB.tracked[3]
    check("a spell with a cooldown, its buff never seen: its cooldown only",
        not NS.HasChoice(mocking) and NS.TrackOf(mocking) == "cooldown" and mocking.buff == nil)
    mocking.buff = true
    check("its buff seen on the player after their cast: the choice, its cooldown to start",
        NS.HasChoice(mocking) and NS.TrackOf(mocking) == "cooldown")
    mocking.buff = nil
    check("an item: no choice", not NS.HasChoice(DB.tracked[2]))

    -- (The player, 2026-10-20, after every guess failed - Mass Dispel, Prayer of Mending,
    -- Apotheosis, Voidform flickering, Shadowform's icon on it: "use the game's way".)
    -- Blizzard_CooldownViewer's own: a spell's aura is one of ITS OWN Cooldown Manager
    -- entry's spells (linked, tooltip override, override, spell), cast by the player.
    spells[228260] = { name = "Voidform" }              -- the spell cast
    spells[194249] = { name = "Voidform" }              -- its aura, another spell
    spells[232698] = { name = "Shadowform" }
    spells[33076] = { name = "Prayer of Mending" }
    spells[200183] = { name = "Apotheosis" }
    spells[47585] = { name = "Dispersion" }
    local wasViewer, wasCategories = C_CooldownViewer, Enum.CooldownViewerCategory
    Enum.CooldownViewerCategory = { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3, GroupBuff = 4 }
    local viewer = {
        [1] = { spellID = 228260, selfAura = true, linkedSpellIDs = { 194249 } },          -- Voidform, its aura linked
        -- Shadowform's, its aura overridden by Voidform's while in it: not Voidform's.
        [2] = { spellID = 232698, selfAura = true, overrideSpellID = 194249, linkedSpellIDs = {} },
        [3] = { spellID = 33076, selfAura = false, linkedSpellIDs = { 41635 } },           -- Prayer of Mending: on others
        [4] = { spellID = 47585, selfAura = false, linkedSpellIDs = {} },                  -- Dispersion, a tracked bar
        [5] = { spellID = 200183, selfAura = true, linkedSpellIDs = {} },                  -- Apotheosis
    }
    local spec                                          -- nil: not loaded yet
    local SETS = {
        shadow = { [0] = { 1 }, [2] = { 2 }, [3] = { 4 } },
        holy = { [0] = { 3, 5 } },
    }
    C_CooldownViewer = {
        GetCooldownViewerCategorySet = function(category) return spec and SETS[spec][category] or {} end,
        GetCooldownViewerCooldownInfo = function(id) return viewer[id] end,
    }
    local voidform, mending = { kind = "spell", id = 228260 }, { kind = "spell", id = 33076 }
    local dispersion, apotheosis = { kind = "spell", id = 47585 }, { kind = "spell", id = 200183 }
    local mine = { voidform, mending, dispersion, apotheosis }
    for _, entry in ipairs(mine) do DB.tracked[#DB.tracked + 1] = entry end
    Core.RETAIL = true
    NS.Durations.Refresh()
    check("retail, its list not loaded yet: no choice", not NS.HasChoice(voidform))
    spec = "holy"
    NS.Durations.Refresh()
    check("its own entry with its aura on its caster: the choice (Apotheosis)", NS.HasChoice(apotheosis))
    check("its own entry with its aura on others: its cooldown only (Prayer of Mending)",
        not NS.HasChoice(mending) and NS.TrackOf(mending) == "cooldown")
    spec = "shadow"
    NS.Durations.Refresh()
    check("Voidform: the choice", NS.HasChoice(voidform))
    check("Dispersion, its own entry in the Tracked Bars: the choice", NS.HasChoice(dispersion))
    check("another spec's spells keep their answers (Apotheosis, Prayer of Mending as Shadow)",
        NS.HasChoice(apotheosis) and not NS.HasChoice(mending))
    -- (The player, 2026-10-20: Apotheosis as Shadow, nothing saved: "how come it has no
    -- duration?") The spec now's Cooldown Manager lacks it: its own buff seen on the player
    -- after their cast decides.
    local holyApotheosis = { kind = "spell", id = 200183, buff = true }
    local holyMending = { kind = "spell", id = 33076, buff = false }
    DB.tracked[#DB.tracked + 1] = holyApotheosis
    DB.tracked[#DB.tracked + 1] = holyMending
    NS.Durations.Refresh()
    check("another spec's spell, nothing saved: its own buff seen after its cast, the choice (Apotheosis)",
        NS.HasChoice(holyApotheosis))
    check("and never seen (Prayer of Mending's is another spell on others): its cooldown only",
        not NS.HasChoice(holyMending))
    voidform.buff = false
    NS.Durations.Refresh()
    check("the spec now's Cooldown Manager answers before what was seen", NS.HasChoice(voidform))
    voidform.buff = nil
    table.remove(DB.tracked)
    table.remove(DB.tracked)
    voidform.track = "buff"
    NS.Durations.Refresh()
    local filters = NS.Durations.groups.bar.auraGroups.tracked.candidateFilters
    check("Voidform's Duration follows its own entry's aura, never Shadowform's (its icon on it, a flicker)",
        filters.includeSpellIDs[194249] == true and not filters.includeSpellIDs[232698])
    -- (isFromPlayerOrPlayerPet is true for ANY player's aura: the filter token decides.)
    check("the player's own auras only, as the game's (HELPFUL|PLAYER)",
        NS.Durations.groups.bar.auraGroups.tracked.filter == "HELPFUL|PLAYER")
    voidform.track = nil
    local saved = { buffIDsMatch = 1, tracked = { { kind = "spell", id = 228260, buffIDs = { 194249, "x", -1 } } } }
    NS.Normalise(saved)
    check("its aura's IDs saved with it, whole numbers only",
        saved.tracked[1].buffIDs and #saved.tracked[1].buffIDs == 1 and saved.tracked[1].buffIDs[1] == 194249)
    -- (The core drops a saved key that is no default: the flag a default, or the old
    -- lists went on every load.)
    saved = { tracked = { { kind = "spell", id = 228260, buffIDs = { 232698, 194249 } } } }
    NS.Normalise(saved)
    check("those found another way dropped once, to be found again; the flag a default the core keeps",
        saved.tracked[1].buffIDs == nil and saved.buffIDsMatch == 1 and NS.defaults.buffIDsMatch ~= nil)
    Core.RETAIL = false
    -- (Forever's lists are empty: the same rule, the cast deciding.)
    check("Forever, never cast or its buff never seen (a Swiftmend): its cooldown only",
        not NS.HasChoice({ kind = "spell", id = 99999 }) and not NS.HasChoice({ kind = "spell", id = 99999, buff = false }))
    check("Forever, its buff seen on the player after their cast (an Enrage): the choice",
        NS.HasChoice({ kind = "spell", id = 99999, buff = true }))
    for _ = 1, #mine do table.remove(DB.tracked) end
    C_CooldownViewer, Enum.CooldownViewerCategory = wasViewer, wasCategories
    NS.Durations.Refresh()

    -- Whether a spell with no cooldown leaves a buff on you is learned from
    -- casting it - the same for every spell; nothing is written down.
    check("Seal of Command: no cooldown, its duration", not NS.HasChoice(entry) and NS.TrackOf(entry) == "buff")
    NS.Add("spell", 800)
    local holy = DB.tracked[#DB.tracked]
    check("a spell with no cooldown tracks its duration until seen otherwise", NS.TrackOf(holy) == "buff")
    aurasSecret = true
    Cast(800)
    check("cast in combat with no buff to be seen: nothing learned (a missing buff proves nothing then)",
        holy.buff == nil)
    aurasSecret = false
    Cast(800)
    check("cast and no buff: nothing to track", holy.buff == false and NS.TrackOf(holy) == nil
        and not NS.ShowsBuff(holy))
    NS.Remove(#DB.tracked)

    -- (Another priest's Renew on you is no proof yours leaves one.)
    auras[20375] = { name = "Seal of Command", sourceUnit = "party1" }
    NS.Refresh()
    check("another player's of it on you: nothing learned", entry.buff == nil)
    auras[20375] = { name = "Seal of Command", sourceUnit = "player" }
    NS.Refresh()
    check("a buff of yours already on you is noticed when the list refreshes", entry.buff == true)
    auras[20375] = nil
    check("a cast of another spell teaches this one nothing", (function()
        Cast(7620)
        return entry.buff == true
    end)())
    Cast(20375)
    check("cast and its buff not seen (on someone else, already gone): still has one",
        entry.buff == true and NS.TrackOf(entry) == "buff")

    local c = Durations.groups.bar
    check("the game's aura container for add-ons, on you",
        c ~= nil and c.template == "CustomAuraContainerTemplate" and c.unit == "player"
        and c.parent == holder and c.editModePreview == false)
    local group = c.auraGroups.tracked
    check("your helpful auras only", group and group.filter == "HELPFUL|PLAYER")
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
        and c.flowPoint == "BOTTOMLEFT" and c.points[2] == Durations.anchors.bar)

    -- On top of the cooldown bars: two up, the buff stack starts above them.
    cooldowns[100] = { start = now, length = 12 }
    cooldowns[200] = { start = now, length = 12 }
    Fire("SPELL_UPDATE_COOLDOWN")
    Tick(0.2)
    Tick(0.5)
    local a = Durations.anchors.bar.points
    check("on top of the cooldown bars showing", a[1] == "BOTTOMLEFT" and a[2] == holder
        and a[5] == 2 * step, tostring(a[5]))
    check("and never a cooldown bar of its own", not (NS.rows[5] and NS.rows[5]:IsShown()))
    cooldowns[100] = nil
    Tick(0.2)
    Tick(Core.Style.FADE_OUT + 0.1)
    Tick(0.2)
    check("moving down as they end", Durations.anchors.bar.points[5] == step,
        tostring(Durations.anchors.bar.points[5]))
    cooldowns = {}
    Tick(0.2)
    Tick(Core.Style.FADE_OUT + 0.1)
    Tick(0.2)

    DB.growDirection = "down"
    NS.Refresh()
    check("growing down: under the cooldown bars, stacking down",
        Durations.anchors.bar.points[1] == "TOPLEFT" and c.flowV == AnchorUtil.FlowDirection.Down
        and c.flowPoint == "TOPLEFT")
    DB.growDirection = "up"
    NS.Refresh()

    spellbook[#spellbook + 1] = { spellID = 20919, name = "Seal of Command" }
    -- (A shapeshift fires a burst of them: worked out once, a frame later.)
    local sets = 0
    local Set = c.SetAuraGroupCandidateFilters
    c.SetAuraGroupCandidateFilters = function(...)
        sets = sets + 1
        return Set(...)
    end
    Fire("SPELLS_CHANGED")
    Fire("SPELLS_CHANGED")
    Fire("SPELLS_CHANGED")
    check("a burst of spell changes: nothing yet", not c.auraGroups.tracked.candidateFilters.includeSpellIDs[20919])
    Tick(0.01)
    check("a rank learned is added to the filter, once",
        c.auraGroups.tracked.candidateFilters.includeSpellIDs[20919] == true and sets == 1)
    Fire("SPELLS_CHANGED")
    Tick(0.01)
    check("nothing new: the game not handed the same filter again (it would drop and look again)", sets == 1)
    c.SetAuraGroupCandidateFilters = Set

    local width = DB.barWidth
    DB.barWidth = width + 20
    aurasSecret = true
    NS.Refresh()
    check("a new size waits while the game keeps the bars from the addon", b.width == width)
    aurasSecret = false
    Tick(0.2)
    check("and reaches them once it does not, with nothing else changed (a size set in a fight)",
        b.width == width + 20)
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

    charge.buff = true                       -- its buff seen after a cast: the choice
    NS.SetTrack(1, "both")
    check("Both: its cooldown and its buff",
        NS.ShowsCooldown(charge) and NS.ShowsBuff(charge) and charge.track == "both")
    NS.Add("spell", 20375)                   -- so the duration container exists
    local c = Durations.groups.bar
    check("its buff not a second bar in the duration group: it covers its own cooldown bar (see icons)",
        not c.auraGroups.tracked.candidateFilters.includeSpellIDs[100])
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
    check("an icon size an older version saved is the ring icons' now", db.iconSize == 26)
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
    -- (The player, 2026-10-22: a UI widget's spell tooltip, forbidden to add-ons, raised
    -- "Attempt to access forbidden object" on the hook.)
    tip:ClearLines()
    tip.forbidden = true
    local HookScript, AddLine = tip.HookScript, tip.AddLine
    local function Forbidden() error("Attempt to access forbidden object from code tainted by an AddOn") end
    tip.HookScript, tip.AddLine = Forbidden, Forbidden
    -- (The game's own post-call, with the tooltip it built.)
    local ok, err = pcall(postCalls.ALL[1], tip, { type = kinds.Spell, id = 1215386 })
    check("a tooltip the game forbids to add-ons: left alone, no error", ok, err)
    tip.forbidden, tip.HookScript, tip.AddLine = nil, HookScript, AddLine

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
