-- MODULE: Cooldowns  (DogsForeverUI.Cooldowns, settings section "cooldowns")
-- Bars - or square icons in rows, each entry its choice - for spells and items
-- added by ID: a bar while it cools down, an icon always on its spot (lit while
-- it cools down, faint and grey while it doesn't); or a spell's buff while it
-- runs (the game's aura container). Also IDs on tooltips and talent ranks.
-- Cooldown numbers are secret in combat: only isActive/isOnGCD (NeverSecret) are read.

DogsForeverUI.Cooldowns = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.Cooldowns
    local Style = DogsForeverUI.Style
    local Core = DogsForeverUI
    local IsSecret = issecretvalue

    local Place, Refresh, Update, Polling, SavePlace
    local Durations = {}
    NS.Durations = Durations

    NS.key = "cooldowns"
    NS.title = "Cooldowns"

    NS.defaults = {
        unlocked = false,
        barWidth = 150,          -- the whole row, icon included: the player frame's width
        barHeight = 20,          -- the castbar's height
        growDirection = "up",
        iconSize = 32,           -- the icon entries'
        iconsPerRow = 6,
        iconGrow = "center",     -- along a row: "center" (both sides of its middle), "right" or "left"
        iconRowsGrow = "up",     -- the next row: "up" or "down"
        hideIconsOutOfCombat = true,
        frameStrata = "MEDIUM",
        showTooltipIDs = true,
        tracked = {},            -- { kind, id, track, buff, buffIDs, display }, in order
        buffIDsMatch = 0,        -- how the saved buffIDs were found (BUFF_IDS_MATCH): older ones go
    }
    -- The bars' place, and the icons' holder's middle from the screen's (the first
    -- icon's, or the first row's middle when they grow both sides).
    NS.placement = { barLeft = true, barTop = true, autoPlaced = true, iconX = true, iconY = true }
    NS.keep = { tracked = true }   -- the player's own list survives Reset everything

    NS.GROW = {
        { value = "up",   label = "Upward" },
        { value = "down", label = "Downward" },
    }
    -- Each entry's look ("bar" is stored as nothing).
    NS.DISPLAY = {
        { value = "bar",  label = "Bar" },
        { value = "icon", label = "Icon" },
    }
    NS.ICON_GROW = {
        { value = "center", label = "Both sides" },
        { value = "right", label = "Rightward" },
        { value = "left",  label = "Leftward" },
    }
    NS.ICON_MIN, NS.ICON_MAX = 20, 64
    NS.PER_ROW_MAX = 20
    -- A spell with a cooldown and a buff: what its row tracks ("cooldown" is stored as nothing).
    NS.TRACK = {
        { value = "cooldown", label = "Cooldown" },
        { value = "buff",     label = "Duration" },
        { value = "both",     label = "Both" },
    }

    local KINDS = { spell = "Spell", item = "Item" }
    local VALID_GROW = { up = true, down = true }
    local VALID_ICON_GROW = { center = true, right = true, left = true }
    local BUFF_TRACKS = { buff = true, both = true }   -- the tracks saved; "cooldown" is nil
    local OLD_DEFAULT_WIDTHS = { [200] = true, [130] = true }   -- earlier defaults, taken as today's
    local NOT_AN_ID = "Type a spell or item ID: a whole number."

    local GAP = 6 + 2 * Style.BORDER_INSET   -- room for two borders drawn outside their bars
    local POLL = 0.1                          -- a cooldown ends with no event
    local GCD = 1.5                           -- the global cooldown at its longest
    local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
    local WEAK = { __mode = "k" }
    local IMMEDIATE = Core.EnumValue("StatusBarInterpolation", "Immediate", 0)
    local REMAINING = Core.EnumValue("StatusBarTimerDirection", "RemainingTime", 1)
    local ELAPSED = Core.EnumValue("StatusBarTimerDirection", "ElapsedTime", 0)

    -- A game API call; nothing if it is missing or raises.
    local function Ask(namespace, name, ...)
        return Core.Try(Core.Api(namespace, name), ...)
    end

    local function Plain(value, kind)
        return not IsSecret(value) and type(value) == kind
    end

    local function GrowsDown()
        return NS.db.growDirection == "down"
    end

    -- Shown as an icon, not a bar.
    local function IsIcon(entry)
        return entry.display == "icon"
    end

    -- A positive whole number, or nil.
    local function WholeID(value)
        local id = tonumber(value)
        if id and id > 0 and id % 1 == 0 then return id end
    end

    ---------------------------------------------------------------------------
    -- What an ID is
    ---------------------------------------------------------------------------

    local function Exists(kind, id)
        if kind == "spell" then
            return Ask("C_Spell", "DoesSpellExist", id) or type(Ask("C_Spell", "GetSpellName", id)) == "string"
        end
        return Ask("C_Item", "GetItemInfoInstant", id) ~= nil
    end

    -- An item's name may not be loaded yet: asked for once (this runs ten times a
    -- second), GET_ITEM_INFO_RECEIVED redraws.
    local requested = {}            -- item ID -> its data asked for
    function NS.Describe(entry)
        local name, icon
        if entry.kind == "spell" then
            name = Ask("C_Spell", "GetSpellName", entry.id)
            icon = Ask("C_Spell", "GetSpellTexture", entry.id)
        else
            name = Ask("C_Item", "GetItemNameByID", entry.id)
            icon = Ask("C_Item", "GetItemIconByID", entry.id) or select(5, Ask("C_Item", "GetItemInfoInstant", entry.id))
            if not name and not requested[entry.id] then
                requested[entry.id] = true
                Ask("C_Item", "RequestLoadItemDataByID", entry.id)
            end
        end
        if not Plain(name, "string") then name = KINDS[entry.kind] .. " " .. entry.id end
        return name, icon or QUESTION_MARK
    end

    -- The rank the game knows by the spell's name (the one learned), and the name.
    local function KnownRank(id)
        local name = Ask("C_Spell", "GetSpellName", id)
        if not Plain(name, "string") then return nil end
        local info = Ask("C_Spell", "GetSpellInfo", name)
        return type(info) == "table" and Plain(info.spellID, "number") and info.spellID or nil, name
    end

    local function InBook(id)
        return Ask("C_SpellBook", "IsSpellInSpellBook", id) == true
    end

    -- A spell in your spellbook (any rank), an item in your bags or worn.
    local function Yours(kind, id)
        if kind == "spell" then
            if InBook(id) then return true end
            local known = KnownRank(id)
            return known ~= nil and InBook(known)
        end
        local count = Ask("C_Item", "GetItemCount", id)
        if Plain(count, "number") and count > 0 then return true end
        return Ask("C_Item", "IsEquippedItem", id) == true
    end

    -- Every spell of the class's talent tree, every spec's and the hero talents (GetTreeNodes:
    -- "nodes for all class specializations"), read once it has loaded.
    local talentSpells
    local function TalentSpells()
        if talentSpells then return talentSpells end
        local made = {}
        local config = Ask("C_ClassTalents", "GetActiveConfigID")
        local info = Plain(config, "number") and Ask("C_Traits", "GetConfigInfo", config)
        for _, tree in ipairs(type(info) == "table" and info.treeIDs or {}) do
            for _, node in ipairs(Ask("C_Traits", "GetTreeNodes", tree) or {}) do
                local nodeInfo = Ask("C_Traits", "GetNodeInfo", config, node)
                for _, entryID in ipairs(type(nodeInfo) == "table" and nodeInfo.entryIDs or {}) do
                    local entryInfo = Ask("C_Traits", "GetEntryInfo", config, entryID)
                    local definition = type(entryInfo) == "table" and Plain(entryInfo.definitionID, "number")
                        and Ask("C_Traits", "GetDefinitionInfo", entryInfo.definitionID)
                    local spell = type(definition) == "table" and definition.spellID
                    if Plain(spell, "number") then made[spell] = true end
                end
            end
        end
        if next(made) then talentSpells = made end
        return made
    end

    -- Of the spec now (the options list the rest after, dimmed; nothing of it shows): a
    -- talent only while had (one not taken, or another spec's, is in no spellbook - it
    -- passed as a proc: Dominate Mind not taken, Benediction out of Holy); any other spell
    -- as the game's spellbook says - on retail it holds the other specs' spells too, marked
    -- off-spec (FindSpellBookSlotForSpell with and without them; hidden, replaced and
    -- not-yet-learnt ones searched). Not in it at all - a buff or proc, an item - and all of
    -- Forever, which has no specs: always. (Guessing from a cooldown or a cast failed: out of
    -- its spec a spell tells of no cooldown - Holy Word: Serenity looked like a proc.)
    local currentNow = setmetatable({}, WEAK)   -- entry -> bool, until a refresh
    function NS.IsCurrent(entry)
        local Find = Core.Api("C_SpellBook", "FindSpellBookSlotForSpell")
        if not Core.RETAIL or entry.kind ~= "spell" or not Find then return true end
        local current = currentNow[entry]
        if current == nil then
            if TalentSpells()[entry.id] and not NS.KnownNow(entry) then
                current = false
            else
                current = Core.Try(Find, entry.id, true, true, true, false) ~= nil
                    or Core.Try(Find, entry.id, true, true, true, true) == nil
            end
            currentNow[entry] = current
        end
        return current
    end

    ---------------------------------------------------------------------------
    -- The list
    ---------------------------------------------------------------------------

    -- Answers whether it was added, and a line to say so.
    function NS.Add(kind, id)
        id = WholeID(id)
        if not KINDS[kind] then return false, "Unknown kind." end
        if not id then return false, NOT_AN_ID end
        if not Exists(kind, id) then
            return false, "No " .. kind .. " has the ID " .. id .. "."
        end
        local entry = { kind = kind, id = id }
        local name = NS.Describe(entry)
        for _, other in ipairs(NS.db.tracked) do
            if other.kind == kind and other.id == id then
                return false, name .. " is already tracked."
            end
        end
        table.insert(NS.db.tracked, entry)
        Refresh()
        return true, "Tracking " .. name .. "."
    end

    -- The options' Add box: "spell 2983", "Item ID 6948", "s2983"... or a bare
    -- number. An ID both a spell and an item: the one you have; neither, the
    -- spell (a proc's buff); both, nothing - the line names both.
    local PREFIXES = { s = "spell", spell = "spell", i = "item", item = "item" }

    function NS.AddID(text)
        text = tostring(text or ""):lower():match("^%s*(.-)%s*$")
        local word, number = text:match("^(%a+)%s*[:%s]%s*i?d?%s*:?%s*(%d+)$")
        if not word then word, number = text:match("^(%a+)(%d+)$") end
        if word then
            local kind = PREFIXES[word] or PREFIXES[word:match("^(%a+)id$") or ""]
            if not kind then return false, "Type an ID, or spell or item and an ID." end
            return NS.Add(kind, number)
        end

        local id = WholeID(text)
        if not id then return false, NOT_AN_ID end
        local spell, item = Exists("spell", id), Exists("item", id)
        if spell and item then
            local mySpell, myItem = Yours("spell", id), Yours("item", id)
            if mySpell ~= myItem then return NS.Add(mySpell and "spell" or "item", id) end
            local itemName = NS.Describe({ kind = "item", id = id })
            if not mySpell then
                local ok, message = NS.Add("spell", id)
                if ok then
                    message = message .. " For the item " .. itemName .. ", type item " .. id .. "."
                end
                return ok, message
            end
            return false, id .. " is the spell " .. NS.Describe({ kind = "spell", id = id })
                .. " and the item " .. itemName .. ": type spell " .. id .. " or item " .. id .. "."
        end
        if spell then return NS.Add("spell", id) end
        if item then return NS.Add("item", id) end
        return false, "No spell or item has the ID " .. id .. "."
    end

    function NS.SetTrack(index, track)
        local entry = NS.db.tracked[index]
        if not entry then return end
        entry.track = BUFF_TRACKS[track] and track or nil
        Refresh()
    end

    -- "bar" or "icon".
    function NS.DisplayOf(entry)
        return IsIcon(entry) and "icon" or "bar"
    end

    function NS.SetDisplay(index, display)
        local entry = NS.db.tracked[index]
        if not entry then return end
        entry.display = display == "icon" and "icon" or nil
        Refresh()
    end

    function NS.Remove(index)
        if not NS.db.tracked[index] then return end
        table.remove(NS.db.tracked, index)
        Refresh()
    end

    ---------------------------------------------------------------------------
    -- What an entry tracks. A spell with no cooldown tracks its buff; whether
    -- it leaves one is learned (entry.buff, saved): no API says so. A spell
    -- with one that leaves one is the player's choice.
    ---------------------------------------------------------------------------

    local hasCooldown = setmetatable({}, WEAK)   -- entry -> bool, until a refresh

    local function HasCharges(charges)
        return type(charges) == "table" and Plain(charges.maxCharges, "number") and charges.maxCharges > 1
    end

    -- An item always; a spell unless its base cooldown is 0 and it has no charges.
    function NS.HasCooldown(entry)
        if entry.kind ~= "spell" then return true end
        local known = hasCooldown[entry]
        if known == nil then
            local ms = Core.Try(GetSpellBaseCooldown, entry.id)
            known = not Plain(ms, "number") or ms > 0 or HasCharges(Ask("C_Spell", "GetSpellCharges", entry.id))
            hasCooldown[entry] = known
        end
        return known
    end

    -- THE GAME'S OWN WAY (Blizzard_CooldownViewer\CooldownViewerItemData.lua,
    -- GetAssociatedAuraSpellPriority): a Cooldown Manager entry's aura is one of its OWN
    -- spells - its linked ones, its tooltip's override, its override, its spell - cast by the
    -- player; never another entry's (Shadowform's, overridden to Voidform's aura, is not
    -- Voidform's). Each entry by its spell: those IDs, and whether it shows an aura on its
    -- caster (an aura list's entry, or its selfAura). For the spec now: read once, again
    -- after a refresh; not kept while empty (not loaded yet; Forever has none).
    local AURA_CATEGORIES = { TrackedBuff = true, GroupBuff = true, SpecAgnosticTracked = true,
                              EquipSlotTracked = true, TrackedBar = true }
    local viewer        -- spellID -> { ids = { id, ... }, aura = bool }

    local function Add(ids, id)
        if Plain(id, "number") and id > 0 and not tContains(ids, id) then ids[#ids + 1] = id end
    end

    local function Viewer()
        if viewer then return viewer end
        local made = {}
        for key, category in pairs(Enum.CooldownViewerCategory or {}) do
            local set = Ask("C_CooldownViewer", "GetCooldownViewerCategorySet", category, true)
            for _, cooldownID in ipairs(type(set) == "table" and set or {}) do
                local info = Ask("C_CooldownViewer", "GetCooldownViewerCooldownInfo", cooldownID)
                local spell = type(info) == "table" and info.spellID
                if Plain(spell, "number") and spell > 0 then
                    local own = made[spell] or { ids = {}, aura = false }
                    made[spell] = own
                    for _, id in ipairs(type(info.linkedSpellIDs) == "table" and info.linkedSpellIDs or {}) do
                        Add(own.ids, id)
                    end
                    Add(own.ids, info.overrideTooltipSpellID)
                    Add(own.ids, info.overrideSpellID)
                    Add(own.ids, spell)
                    own.aura = own.aura or AURA_CATEGORIES[key] == true or info.selfAura == true
                end
            end
        end
        if next(made) then viewer = made end
        return made
    end

    -- A spell entry's aura IDs, from its own Cooldown Manager entries (theirs the spell, one of
    -- its ranks): kept (entry.buffIDs) while the spec now lists none of them - another spec's
    -- spell has its own still - and none when its entries show no aura. Into `ranks`, for its
    -- Duration to follow.
    local listedNow = setmetatable({}, WEAK)    -- entry -> the spec now's Cooldown Manager has it
    local function AddBuffIDs(entry, ranks)
        local data = Viewer()
        local ids, aura, listed = {}, false, false
        for id in pairs(ranks) do
            local own = data[id]
            if own then
                listed, aura = true, aura or own.aura
                for _, buff in ipairs(own.ids) do Add(ids, buff) end
            end
        end
        if listed then entry.buffIDs = aura and ids or nil end
        listedNow[entry] = listed
        for _, id in ipairs(entry.buffIDs or {}) do ranks[id] = true end
    end

    -- Cooldown, duration or both: a spell with a cooldown and a buff in the Cooldown Manager.
    -- One it lacks with none saved (another spec's; all of Forever, whose lists are empty):
    -- only once its own buff was seen on the player after their cast (entry.buff -
    -- Apotheosis's, Enrage's; never Swiftmend's, nor Prayer of Mending's, another spell on
    -- others). The same on both clients.
    function NS.HasChoice(entry)
        if entry.kind ~= "spell" or not NS.HasCooldown(entry) then return false end
        return entry.buffIDs ~= nil or (not listedNow[entry] and entry.buff == true)
    end

    -- "cooldown", "buff", "both", or nil once a spell with no cooldown is seen to leave no buff.
    function NS.TrackOf(entry)
        if NS.HasChoice(entry) then return entry.track or "cooldown" end
        if NS.HasCooldown(entry) then return "cooldown" end
        if entry.buff ~= false then return "buff" end
    end

    function NS.ShowsCooldown(entry)
        local track = NS.TrackOf(entry)
        return track == "cooldown" or track == "both"
    end

    function NS.ShowsBuff(entry)
        return BUFF_TRACKS[NS.TrackOf(entry)] == true
    end

    ---------------------------------------------------------------------------
    -- Reading a cooldown: active (true, false, or a secret never looked at),
    -- the duration for its bar, and a spell's charges.
    ---------------------------------------------------------------------------

    local onGCD = setmetatable({}, WEAK)          -- isOnGCD read: when it said so, or false
    local itemDurations = setmetatable({}, WEAK)  -- reused duration objects
    local cooldownIDs = setmetatable({}, WEAK)    -- until a refresh

    -- The game may answer nothing for a rank you don't know: the ID as added
    -- while in your spellbook, else the rank it knows by the name. Kept only
    -- once found in the spellbook, which may be empty as the world loads.
    function NS.CooldownID(entry)
        local id = cooldownIDs[entry]
        if id then return id end
        id = entry.id
        if not InBook(id) then id = KnownRank(id) or id end
        if InBook(id) then cooldownIDs[entry] = id end
        return id
    end

    -- The player has `id` now: learnt in this spec (a replaced one's base too), or a pet's.
    local function Has(id)
        if Core.Try(IsPlayerSpell, id) == true or Core.Try(IsSpellKnown, id, true) == true then return true end
        local Find = Core.Api("C_SpellBook", "FindSpellBookSlotForSpell")
        return Find ~= nil and Core.Try(Find, id, true, true, false, false) ~= nil
    end

    -- A spell's cooldown shows only while the player has it (by any rank): the game answers
    -- one not learnt - another spec's, a talent not taken - with some other cooldown (Prayer
    -- of Mending in Shadow showed Power Word: Shield's). Asked again after a refresh.
    local knownNow = setmetatable({}, WEAK)     -- entry -> bool, until a refresh
    function NS.KnownNow(entry)
        if entry.kind ~= "spell" then return true end
        local known = knownNow[entry]
        if known == nil then
            local rank = KnownRank(entry.id)
            known = Has(entry.id) or (rank ~= nil and rank ~= entry.id and Has(rank))
            knownNow[entry] = known
        end
        return known
    end

    local function SpellCooldown(entry, cooldownEvent)
        local id = NS.CooldownID(entry)
        local charges = Ask("C_Spell", "GetSpellCharges", id)
        if HasCharges(charges) then   -- the next charge coming back
            return charges.isActive, Ask("C_Spell", "GetSpellChargeDuration", id), charges.currentCharges
        end

        local info = Ask("C_Spell", "GetSpellCooldown", id)
        if type(info) ~= "table" then return false end
        -- Its own cooldown, the global one left out (ignoreGCD).
        local duration = Ask("C_Spell", "GetSpellCooldownDuration", id, true)
        local active = info.isActive
        if IsSecret(active) then return active, duration end
        if not active then
            onGCD[entry] = nil
            return false
        end
        -- The game's plain answer, where it gives one (Forever; retail out of combat):
        -- nothing of its own left is the global cooldown alone, else its own - exact,
        -- at once, with no "0 s" as a global cooldown ends.
        local ok, zero = pcall(duration and duration.IsZero, duration)
        if ok and Plain(zero, "boolean") then
            onGCD[entry] = nil
            if zero then return false end
            return true, duration
        end
        -- Secret (retail in a fight): isOnGCD, trusted only on SPELL_UPDATE_COOLDOWN and
        -- never past a global cooldown's length - one wrong answer must not hide a
        -- cooldown for good. A "no" within that length keeps the "yes" (the game says
        -- no for a global cooldown's last moments as a cast ends: a "0 s" icon) - but
        -- the spell's own cast clears it (the learner, below): its cooldown at once (one
        -- cast right as another's global cooldown ended showed late).
        if cooldownEvent or onGCD[entry] == nil then
            local gcd, since = info.isOnGCD, onGCD[entry]
            if not IsSecret(gcd) and gcd == true then
                onGCD[entry] = GetTime()
            elseif not (since and GetTime() - since < GCD) then
                onGCD[entry] = false
            end
        end
        if onGCD[entry] and GetTime() - onGCD[entry] < GCD then return false end
        return true, duration
    end

    local function ItemCooldown(entry)
        local start, length, enabled = Ask("C_Item", "GetItemCooldown", entry.id)
        if not (Plain(start, "number") and Plain(length, "number")) or IsSecret(enabled) then return false end
        if enabled == false or enabled == 0 then return false end
        if start <= 0 or length <= GCD or start + length <= GetTime() then return false end

        local duration = itemDurations[entry]
        if not duration then
            duration = Ask("C_DurationUtil", "CreateDuration")
            if not duration then return false end
            itemDurations[entry] = duration
        end
        if not pcall(duration.SetTimeFromStart, duration, start, length) then return false end
        return true, duration
    end

    ---------------------------------------------------------------------------
    -- The time left, formatted by the game ("45s", "1m 30s"; an icon's one unit,
    -- "2m"): cooldowns round up like the action buttons, buffs truncate like
    -- the game's buff timers.
    ---------------------------------------------------------------------------

    local function MakeFormatter(rounding, units)
        local ok, made = pcall(function()
            local f = C_StringUtil.CreateSecondsFormatter()
            local curve = C_CurveUtil.CreateCurve()
            curve:SetType(Enum.LuaCurveType.Step)
            local interval = Enum.SecondsFormatterInterval
            curve:AddPoint(0, interval.Seconds)
            curve:AddPoint(1 + 1.5 * 60, interval.Minutes)
            curve:AddPoint(1 + 1.5 * 3600, interval.Hours)
            curve:AddPoint(1 + 1.5 * 86400, interval.Days)
            f:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
            f:SetRounding(Enum.SecondsFormatterRounding[rounding])
            f:SetCanRoundUpLastUnit(true)
            f:SetMinInterval(interval.Seconds)
            f:SetMaxIntervalCurve(curve)
            f:SetDesiredUnitCount(units)
            return f
        end)
        if ok then return made end
    end
    NS.formatter = MakeFormatter("RoundUp", 2)
    NS.auraFormatter = MakeFormatter("Truncate", 2)
    NS.iconFormatter = MakeFormatter("RoundUp", 1)
    NS.iconAuraFormatter = MakeFormatter("Truncate", 1)

    -- The text is secret in combat: handed on, never compared, every hand-over guarded.
    local function ShowTime(label, duration, formatter)
        if type(duration) ~= "table" and type(duration) ~= "userdata" then
            label:SetText("")
            return
        end
        if formatter then
            local ok, text = pcall(duration.FormatRemainingDuration, duration, formatter)
            if ok and (IsSecret(text) or text ~= nil) and pcall(label.SetText, label, text) then return end
        end
        local ok, left = pcall(duration.GetRemainingDuration, duration)
        if ok and (IsSecret(left) or type(left) == "number")
           and pcall(label.SetFormattedText, label, "%.0f", left) then
            return
        end
        label:SetText("")
    end

    ---------------------------------------------------------------------------
    -- The bars. The holder is the first bar's place, and what is dragged.
    ---------------------------------------------------------------------------

    local holder = CreateFrame("Frame", "DogsForeverUICooldowns", UIParent)
    holder:Hide()
    NS.holder = holder

    local rows = {}
    NS.rows = rows

    -- A bar's pieces on `frame`, into `p` (the row itself, or a buff bar's own table).
    local function MakePieces(frame, p)
        p.bg = frame:CreateTexture(nil, "BACKGROUND")
        p.bg:SetAllPoints(frame)
        p.icon = frame:CreateTexture(nil, "ARTWORK")
        p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        p.divider = frame:CreateTexture(nil, "ARTWORK")
        p.bar = CreateFrame("StatusBar", nil, frame)
        p.bar:SetMinMaxValues(0, 1)
        p.bar:SetValue(0)
        p.spark = Style.AddSpark(p.bar)
        p.nameText = p.bar:CreateFontString(nil, "OVERLAY")
        p.timeText = p.bar:CreateFontString(nil, "OVERLAY")
        p.countText = frame:CreateFontString(nil, "OVERLAY")   -- a spell's charges, in the icon's corner
        p.border = Style.AddBorder(frame)
        return p
    end

    -- Size, fonts and paint. A buff bar brings `paint(bar)`, its own fill, and
    -- `timeRoom`: its name keeps clear of the time by a fixed space, since the
    -- game makes the time's text secret and a name anchored to it vanished.
    local function LayOut(frame, p)
        local db = NS.db
        local width, height = db.barWidth, db.barHeight
        local px = Style.OnePixel(frame)
        frame:SetSize(width, height)

        p.icon:ClearAllPoints()
        p.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        p.icon:SetSize(height, height)

        p.divider:ClearAllPoints()
        p.divider:SetPoint("TOPLEFT", p.icon, "TOPRIGHT", 0, 0)
        p.divider:SetPoint("BOTTOMLEFT", p.icon, "BOTTOMRIGHT", 0, 0)
        p.divider:SetWidth(px)
        p.divider:SetColorTexture(unpack(Style.DIVIDER_COLOR))

        -- One anchor and its own size, so its height is there to be read at once.
        local bar = p.bar
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", p.divider, "TOPRIGHT", 0, 0)
        bar:SetSize(math.max(1, width - height - px), height)

        if p.paint then p.paint(bar) else Style.Paint(bar, Style.COOLDOWN_COLOR) end
        Style.SetBackground(p.bg)

        Style.BarLabels(bar, p.nameText, p.timeText, nil, nil, p.timeRoom)

        p.countText:ClearAllPoints()
        Style.SingleLine(p.countText)
        Style.SetFont(bar, p.countText)
        p.countText:SetPoint("BOTTOMRIGHT", p.icon, "BOTTOMRIGHT", -1, 1)

        Style.PinSpark(p.spark, bar)
    end

    local function LayOutRow(row)
        LayOut(row, row)
        row:EnableMouse(NS.db.unlocked)
    end

    -- Dragging a row moves the holder, and every row with it.
    local function RowAt(index)
        if not rows[index] then
            local row = CreateFrame("Frame", nil, holder)
            row:SetFrameLevel(holder:GetFrameLevel() + 2)
            row:Hide()
            MakePieces(row, row)
            Core.Snap.Draggable(row, NS, SavePlace, holder)
            LayOutRow(row)
            rows[index] = row
        end
        return rows[index]
    end

    ---------------------------------------------------------------------------
    -- The icons: square, the time inside, in rows from the first icon's place
    -- (the icon holder): along a row rightward or leftward, so many to a row,
    -- the next row above or below. Every icon entry always on its own spot, so
    -- nothing moves as cooldowns and buffs come and go.
    ---------------------------------------------------------------------------

    local ICON_GAP = 6                -- between two icons, their borders clear
    local ICONS_BELOW = -150          -- the first icon's default place, from the screen's middle
    local ICONS_ABOVE = 30            -- levels over the bars' holder
    local TIME_PADDING = 0.3          -- the time's room in the icon, above and below
    local COUNT_SHARE = 0.44          -- the charges' and stacks' size, of the icon's: 14 on 32, over the time's 11
    local IDLE_ALPHA = 0.35           -- an icon with nothing running: faint and grey, border and all (0.15, 0.25 too faint)
    -- The action buttons' proc glow (ActionButtonSpellAlertTemplate's loop): 1.4 times
    -- the icon, its flipbook 30 frames a second.
    local GLOW_ATLAS = "UI-HUD-ActionBar-Proc-Loop-Flipbook"
    local GLOW_REACH = 0.2            -- of the icon's size, past each edge
    -- The game's Cooldown Manager icon (Blizzard_CooldownViewer\CooldownViewer.xml), the
    -- shape that glow is drawn round: its rounded mask and its swipe, rounded to match.
    local ICON_MASK = "UI-HUD-CoolDownManager-Mask"
    local ICON_SWIPE = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"

    local iconHolder = CreateFrame("Frame", "DogsForeverUICooldownIcons", UIParent)
    iconHolder:Hide()
    -- Over the bars, their buffs and what covers them, wherever the two meet.
    iconHolder:SetFrameLevel(holder:GetFrameLevel() + ICONS_ABOVE)
    NS.iconHolder = iconHolder

    local icons = {}
    NS.icons = icons

    -- A buff button's glow: a texture on the button itself, over its picture and border
    -- (under its swipe and texts), and its loop - handed to the game, which plays it each
    -- time the buff shows and stops it as it goes (AddAuraShownAnimation; a frame of ours
    -- playing it on its own OnShow never glowed). As the game's template: the sheet unseen
    -- (alpha 0) but while its loop plays, which lights it - drawn at 1, a loop not running
    -- showed the whole sheet, a grid of little glows round the icon.
    local function AddGlow(frame)
        local glow = frame:CreateTexture(nil, "OVERLAY")
        glow:SetAtlas(GLOW_ATLAS)
        glow:SetAlpha(0)
        local spin = frame:CreateAnimationGroup()
        spin:SetLooping("REPEAT")
        local lit = spin:CreateAnimation("Alpha")
        lit:SetTarget(glow)
        lit:SetOrder(1)
        lit:SetDuration(0.001)
        lit:SetFromAlpha(1)
        lit:SetToAlpha(1)
        local flip = spin:CreateAnimation("FlipBook")
        flip:SetOrder(2)
        flip:SetTarget(glow)
        flip:SetDuration(1)
        flip:SetFlipBookRows(6)
        flip:SetFlipBookColumns(5)
        flip:SetFlipBookFrames(30)
        flip:SetFlipBookFrameWidth(0)
        flip:SetFlipBookFrameHeight(0)
        return glow, spin
    end

    local function PlaceGlow(frame, glow, size)
        local reach = math.floor(size * GLOW_REACH + 0.5)
        glow:ClearAllPoints()
        glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -reach, reach)
        glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", reach, -reach)
    end

    -- `texture` cut to the game's rounded icon shape.
    local function Rounded(frame, texture)
        local mask = frame:CreateMaskTexture()
        mask:SetAtlas(ICON_MASK)
        mask:SetAllPoints(texture)
        texture:AddMaskTexture(mask)
    end

    -- An icon's pieces on `frame`, into `p` (the icon itself, or a buff icon's
    -- own table): the picture, a swipe darkening it as its time runs - a
    -- cooldown's part still to go, a buff's part gone (one that never ends
    -- stays clear) - the time and charges over both, a buff's glow, and the border:
    -- one real pixel of the bars' colour (a cooldown's gold, a duration's green)
    -- round the picture, the same shape, so its corners follow the glow's.
    local function MakeIconPieces(frame, p, buff)
        local colour = buff and Style.DURATION_COLOR or Style.COOLDOWN_COLOR
        p.border = frame:CreateTexture(nil, "BACKGROUND")
        p.border:SetTexture(Style.FLAT_TEXTURE)
        p.border:SetVertexColor(colour[1], colour[2], colour[3], 1)
        Rounded(frame, p.border)
        p.icon = frame:CreateTexture(nil, "ARTWORK")
        p.icon:SetAllPoints(frame)
        p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        Rounded(frame, p.icon)
        if buff then p.glow, p.spin = AddGlow(frame) end
        local swipe = CreateFrame("Cooldown", nil, frame)
        swipe:SetAllPoints(frame)
        -- The swipe file is white: tinted as the game's are, cooldown and buff alike
        -- (CooldownViewerConstants.ITEM_COOLDOWN_COLOR) - untinted, it covered the icon white.
        swipe:SetSwipeTexture(ICON_SWIPE)
        swipe:SetSwipeColor(0, 0, 0, 0.7)
        swipe:SetReverse(buff == true)
        swipe:SetDrawEdge(false)
        swipe:SetDrawBling(false)
        swipe:SetHideCountdownNumbers(true)
        p.swipe = swipe
        p.front = CreateFrame("Frame", nil, frame)
        p.front:SetAllPoints(frame)
        p.front:SetFrameLevel(swipe:GetFrameLevel() + 1)
        p.timeText = p.front:CreateFontString(nil, "OVERLAY")
        p.countText = p.front:CreateFontString(nil, "OVERLAY")   -- a spell's charges, a buff's stacks
        return p
    end

    local function LayOutIcon(frame, p)
        frame:SetSize(NS.db.iconSize, NS.db.iconSize)
        if p.glow then PlaceGlow(frame, p.glow, NS.db.iconSize) end
        local px = Style.OnePixel(frame)
        p.border:ClearAllPoints()
        p.border:SetPoint("TOPLEFT", frame, "TOPLEFT", -px, px)
        p.border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", px, -px)
        for _, label in ipairs({ p.timeText, p.countText }) do
            label:ClearAllPoints()
            Style.SingleLine(label)
        end
        Style.SetFont(frame, p.timeText, TIME_PADDING)
        p.timeText:SetPoint("CENTER", frame, "CENTER", 0, 0)
        -- Past the bars' largest text (a floor raises it): plain to read, and with a
        -- shadow under its outline, over the glow too.
        Style.SetFont(frame, p.countText, nil, math.floor(NS.db.iconSize * COUNT_SHARE))
        p.countText:SetShadowOffset(1, -1)
        p.countText:SetShadowColor(0, 0, 0, 1)
        p.countText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    end

    local function NewIcon()
        local icon = CreateFrame("Frame", nil, iconHolder)
        icon:Hide()
        -- Its layers drawn as one before its alpha: faint, the picture still hides the
        -- border's square under it (each layer faint on its own, it tinted the picture gold).
        icon:SetFlattensRenderLayers(true)
        MakeIconPieces(icon, icon)
        LayOutIcon(icon, icon)
        return icon
    end

    local function IconAt(index)
        if not icons[index] then icons[index] = NewIcon() end
        return icons[index]
    end

    -- Spot `n` (from 0) of `count`: its offset from the holder - the first icon, or
    -- (both sides) the first row's middle, each row centred on what it holds.
    local function GridSpot(n, count)
        local db = NS.db
        local step, perRow = db.iconSize + ICON_GAP, db.iconsPerRow
        local column, row = n % perRow, math.floor(n / perRow)
        local x = column * step * (db.iconGrow == "left" and -1 or 1)
        if db.iconGrow == "center" then
            x = (column - (math.min(perRow, count - row * perRow) - 1) / 2) * step
        end
        return x, row * step * (db.iconRowsGrow == "down" and -1 or 1)
    end

    local LISTS = { rows, icons }            -- the bars' and the icons'
    local function HideBeyond(last)
        for _, list in ipairs(LISTS) do
            for index, frame in pairs(list) do
                if index > last then Style.HideNow(frame) end
            end
        end
    end

    -- Gliding: frames going to a new spot ease in (SLIDE_RATE: most of the way
    -- in a quarter second at any frame rate); a new target on the way is simply
    -- taken. Only anchor offsets move, the game's buff icons' through Core.Call.
    local SLIDE_RATE = 12            -- per second: 1 - e^(-rate * t) of the way
    local SNAP = 0.5                 -- close enough to stop, in UI units
    local sliding = setmetatable({}, WEAK)   -- frame -> { to, point, x, y, tx, ty }

    local function PutAt(frame, s)
        Core.Call(frame, "ClearAllPoints")
        Core.Call(frame, "SetPoint", s.point, s.to, s.point, s.x, s.y)
    end

    local WakeSlider = Core.Waker(function(elapsed)
        local step = 1 - math.exp(-SLIDE_RATE * elapsed)
        local moving = false
        for frame, s in pairs(sliding) do
            if s.x ~= s.tx or s.y ~= s.ty then
                s.x, s.y = s.x + (s.tx - s.x) * step, s.y + (s.ty - s.y) * step
                if math.abs(s.tx - s.x) < SNAP and math.abs(s.ty - s.y) < SNAP then s.x, s.y = s.tx, s.ty end
                PutAt(frame, s)
                if s.x ~= s.tx or s.y ~= s.ty then moving = true end
            end
        end
        return moving
    end)

    -- `frame` `x`, `y` from `to`'s `point`, gliding there unless `instant` - or
    -- new, or after a change of point: nothing to glide from.
    local function GlideTo(frame, to, point, x, y, instant)
        local s = sliding[frame]
        if instant or not s or s.point ~= point or s.to ~= to then
            s = { to = to, point = point, x = x, y = y, tx = x, ty = y }
            sliding[frame] = s
            PutAt(frame, s)
        elseif s.tx ~= x or s.ty ~= y then
            s.tx, s.ty = x, y
            WakeSlider()
        end
    end

    -- `frame` `count` bars up (or down) from the holder.
    local function StackAt(frame, count, instant)
        local down = GrowsDown()
        GlideTo(frame, holder, down and "TOPLEFT" or "BOTTOMLEFT", 0,
            count * (NS.db.barHeight + GAP) * (down and -1 or 1), instant)
    end

    -- `frame` on icon spot `n`: noted, and put there by PlaceGrid once every spot is
    -- counted (a row growing both sides is centred on its count).
    local gridFrames, gridInstant = {}, {}
    local function GridAt(frame, n, instant)
        gridFrames[n + 1], gridInstant[n + 1] = frame, instant == true
    end

    local function PlaceGrid(count)
        for n = 1, count do
            local x, y = GridSpot(n - 1, count)
            GlideTo(gridFrames[n], iconHolder, "CENTER", x, y, gridInstant[n])
        end
    end

    ---------------------------------------------------------------------------
    -- Buff bars: the game's aura container for add-ons, filtered to every rank
    -- of the tracked spells. The game fills and runs each button, nothing is
    -- read; the addon shapes a button only as it is made (initializeFrame).
    -- It won't say how many it shows, so its stack rides on the cooldown bars.
    ---------------------------------------------------------------------------

    local GROUP = "tracked"
    -- Cast by the player only, as the game's Cooldown Manager: the filter token says so
    -- (isFromPlayerOrPlayerPet is true for ANY player's aura - another priest's Renew).
    local YOURS = "HELPFUL|PLAYER"
    local MAX_BARS = 20
    local DARK = { 0.05, 0.05, 0.05, 1 }   -- the elapsed part, over the colour
    local TIME_ROOM = 40                   -- kept clear for "59 m" and the like
    local SHEEN, SHADE = 0.22, 0.25        -- as Style's sheen, under the game's fill
    local LOOK_AFTER = 0.5                 -- seconds after a cast, to look for its buff

    local entryRanks = setmetatable({}, WEAK)   -- entry -> { [id] = true }
    local rankOwners = {}                       -- id -> { entry, ... }

    -- The spellbook's spell IDs by name, read once a refresh (a list of spells
    -- read it whole for each, on every SPELLS_CHANGED - a shapeshift's too).
    local function SpellBookByName()
        local byName = {}
        local lines = Ask("C_SpellBook", "GetNumSpellBookSkillLines")
        if not Plain(lines, "number") then return byName end
        local bank = Core.EnumValue("SpellBookSpellBank", "Player", 0)
        for line = 1, lines do
            local skill = Ask("C_SpellBook", "GetSpellBookSkillLineInfo", line)
            if type(skill) == "table" and Plain(skill.itemIndexOffset, "number")
               and Plain(skill.numSpellBookItems, "number") then
                for slot = skill.itemIndexOffset + 1, skill.itemIndexOffset + skill.numSpellBookItems do
                    local item = Ask("C_SpellBook", "GetSpellBookItemInfo", slot, bank)
                    if type(item) == "table" and Plain(item.name, "string") and Plain(item.spellID, "number") then
                        local same = byName[item.name] or {}
                        byName[item.name] = same
                        same[#same + 1] = item.spellID
                    end
                end
            end
        end
        return byName
    end

    -- Every ID of the spell's ranks you have, into `ids`: as added, the
    -- game's by name, and `book`'s (SpellBookByName) of that name.
    local function AddRanks(id, ids, book)
        ids[id] = true
        local known, name = KnownRank(id)
        if not name then return end
        if known then ids[known] = true end
        for _, rank in ipairs(book[name] or {}) do ids[rank] = true end
    end

    local function AurasReadable()
        local secret = Ask("C_Secrets", "ShouldAurasBeSecret")
        return not (IsSecret(secret) or secret == true)
    end

    -- Yours (or your pet's) only: another player's of the same spell on you taught
    -- that a spell leaves a buff. Its caster unread (secret): not counted.
    local function FromYou(aura)
        if IsSecret(aura) or type(aura) ~= "table" then return false end
        local source = aura.sourceUnit
        if not Plain(source, "string") then return false end
        for _, unit in ipairs({ "player", "pet" }) do
            local same = UnitIsUnit(source, unit)
            if not IsSecret(same) and same then return true end
        end
        return false
    end

    local function BuffUp(ranks)
        for id in pairs(ranks) do
            if FromYou(Ask("C_UnitAuras", "GetPlayerAuraBySpellID", id)) then return true end
        end
        return false
    end

    -- Each spell entry's ranks (and its Cooldown Manager buff's IDs) and each ID's
    -- entries; a buff already on you noticed.
    local function MapRanks()
        for id in pairs(rankOwners) do rankOwners[id] = nil end
        local readable, book = AurasReadable(), nil
        for _, entry in ipairs(NS.db.tracked) do
            if entry.kind == "spell" then
                book = book or SpellBookByName()
                local ranks = {}
                AddRanks(entry.id, ranks, book)
                AddBuffIDs(entry, ranks)
                entryRanks[entry] = ranks
                for id in pairs(ranks) do
                    rankOwners[id] = rankOwners[id] or {}
                    table.insert(rankOwners[id], entry)
                end
                if entry.buff ~= true and readable and BuffUp(ranks) then entry.buff = true end
            end
        end
    end

    -- After a cast: its buff seen means it has one, for good (one cast on
    -- someone else, or already gone, unlearns nothing); missing means "none"
    -- only for a spell never seen to leave one, and only while auras can be
    -- read (not in combat).
    local function Look(entries)
        local changed = false
        local readable = AurasReadable()
        for _, entry in ipairs(entries) do
            local ranks = entryRanks[entry]
            if ranks and tContains(NS.db.tracked, entry) then
                local learned
                if BuffUp(ranks) then learned = true elseif readable and entry.buff == nil then learned = false end
                if learned ~= nil and entry.buff ~= learned then
                    entry.buff = learned
                    changed = true
                end
            end
        end
        if changed then
            Refresh()
            Core.RefreshOptions()
        end
    end

    -- A tracked spell cast: its cooldown its own, never the global one - shown at once
    -- (SpellCooldown); after a moment, its buff looked for.
    local learner = CreateFrame("Frame")
    learner:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    learner:SetScript("OnEvent", function(_, _, _, _, spellID)
        if IsSecret(spellID) or not rankOwners[spellID] then return end
        local entries = {}
        for i, entry in ipairs(rankOwners[spellID]) do
            entries[i] = entry
            onGCD[entry] = false
        end
        Update(false)
        C_Timer.After(LOOK_AFTER, function() Look(entries) end)
    end)

    local pieces = setmetatable({}, WEAK)   -- button -> its pieces
    local buttons = {}                      -- every one made, in order

    -- The colour (with its sheen) is the background, the game fills the dark
    -- with the time ELAPSED from the right: a timed buff drains like a
    -- cooldown, a buff that never ends (a zero-length timer) stays full.
    local function Build(button)
        local p = MakePieces(button, {})
        local bar = p.bar
        local fill = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
        fill:SetAllPoints(bar)
        fill:SetTexture(Style.FLAT_TEXTURE)
        fill:SetVertexColor(Style.DURATION_COLOR[1], Style.DURATION_COLOR[2], Style.DURATION_COLOR[3], 1)
        local sheen = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
        sheen:SetTexture(Style.FLAT_TEXTURE)
        sheen:SetPoint("TOPLEFT", bar, "TOPLEFT")
        sheen:SetPoint("BOTTOMRIGHT", bar, "RIGHT")
        sheen:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, SHEEN))
        local shade = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
        shade:SetTexture(Style.FLAT_TEXTURE)
        shade:SetPoint("TOPLEFT", bar, "LEFT")
        shade:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
        shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, SHADE), CreateColor(0, 0, 0, 0))

        p.paint = function(statusBar)
            Style.SetBarFill(statusBar)
            statusBar:SetStatusBarColor(unpack(DARK))
            statusBar:SetReverseFill(true)
        end
        p.timeRoom = TIME_ROOM
        p.spark:SetAlpha(0)   -- its place would be the colour's end
        pieces[button] = p
        buttons[#buttons + 1] = button
        LayOut(button, p)
        p.width, p.height, p.px = NS.db.barWidth, NS.db.barHeight, p.divider:GetWidth()

        -- Handed to the game, which runs them from here on.
        Core.Call(button, "SetIcon", p.icon)
        Core.Call(button, "SetDurationBar", bar, { interpolation = IMMEDIATE, direction = ELAPSED })
        Core.Call(button, "SetDurationText", p.timeText,
            NS.auraFormatter and { textFormatter = NS.auraFormatter } or nil)
        Core.Call(button, "SetSpellName", p.nameText)
        Core.Call(button, "SetApplicationCount", p.countText)
    end

    -- A buff icon: square like the cooldowns' with a green border, glowing, run by
    -- the game, faded in as it shows; the world under it stays clickable.
    local iconPieces = setmetatable({}, WEAK)   -- button -> its pieces, and the size it was given

    local function BuildIcon(button)
        local p = MakeIconPieces(button, {}, true)
        LayOutIcon(button, p)
        p.size = NS.db.iconSize
        iconPieces[button] = p
        Core.Call(button, "EnableMouse", false)
        local fade = button:CreateAnimationGroup()
        local alpha = fade:CreateAnimation("Alpha")
        alpha:SetFromAlpha(0)
        alpha:SetToAlpha(1)
        alpha:SetDuration(Style.FADE_IN)
        -- Handed to the game, which runs them from here on.
        Core.Call(button, "SetIcon", p.icon)
        Core.Call(button, "SetDurationCooldown", p.swipe)
        Core.Call(button, "SetDurationText", p.timeText,
            NS.iconAuraFormatter and { textFormatter = NS.iconAuraFormatter } or nil)
        Core.Call(button, "SetApplicationCount", p.countText)
        Core.Call(button, "AddAuraShownAnimation", fade)
        Core.Call(button, "AddAuraShownAnimation", p.spin)
    end

    -- A new size for buff bars and icons already made, only while auras aren't
    -- secret (else once they can be: Update asks again). Sizes only: re-laying
    -- the game's name and time was refused half way and lost every name.
    local resizeWaiting = false
    local function Resize()
        resizeWaiting = not AurasReadable()
        if resizeWaiting then return end
        local db = NS.db
        local width, height = db.barWidth, db.barHeight
        for _, button in ipairs(buttons) do
            local p = pieces[button]
            if p.width ~= width or p.height ~= height then
                p.width, p.height = width, height
                pcall(button.SetSize, button, width, height)
                pcall(p.icon.SetSize, p.icon, height, height)
                pcall(p.bar.SetSize, p.bar, math.max(1, width - height - p.px), height)
            end
        end
        for button, p in pairs(iconPieces) do
            if p.size ~= db.iconSize then
                p.size = db.iconSize
                pcall(button.SetSize, button, db.iconSize, db.iconSize)
                pcall(PlaceGlow, button, p.glow, db.iconSize)
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Buff bars: the game's group of buffs, which closes up by itself over a buff
    -- not on you (whether one is up is secret, so the addon cannot place them),
    -- stacked on top of the cooldown bars, in the order they came (aura instance
    -- IDs: the oldest nearest the cooldowns, a new one at the far end). Duration
    -- entries, and a Both entry's buff while its cooldown isn't running. A
    -- duration-only icon is a Both one with no cooldown: its buff on its own spot.
    ---------------------------------------------------------------------------

    local anchors = { bar = CreateFrame("Frame", nil, holder) }
    anchors.bar:SetSize(1, 1)
    Durations.anchors = anchors
    local followedBars                      -- last followed (nil: not since a refresh)

    -- Bars: up (or down) a column from the anchor.
    local function DirectBars(c)
        local flow, down = AnchorUtil.FlowDirection, GrowsDown()
        local point = down and "TOPLEFT" or "BOTTOMLEFT"
        Core.Call(c, "SetFlowLayoutAxis", AnchorUtil.FlowLayoutAxis.Vertical)
        Core.Call(c, "SetFlowLayoutAnchorPoint", point)
        Core.Call(c, "SetFlowLayoutGrowthDirection", flow.Right, down and flow.Down or flow.Up)
        Core.Call(c, "SetAuraGroupLayout", GROUP, { elementSpacing = GAP, lineSpacing = GAP })
        Core.Call(c, "ClearAllPoints")
        Core.Call(c, "SetPoint", point, anchors.bar, point, 0, 0)
    end

    local groups = {}                       -- "bar" -> the game's container
    Durations.groups = groups
    -- "bar" / a Both slot's key -> the IDs last handed to the game, while on: new
    -- filters make the game drop and look again, so only what changed is sent.
    local sent = {}

    local function SameSet(a, b)
        if not b then return false end
        for id in pairs(a) do if not b[id] then return false end end
        for id in pairs(b) do if not a[id] then return false end end
        return true
    end

    -- The bars' group filled with `ids`; made the first time it has any.
    local function FillBars(ids)
        local c = groups.bar
        if not next(ids) then
            if c then
                Core.Call(c, "SetEnabled", false)
                Core.Call(c, "Hide")
            end
            sent.bar = nil
            return
        end
        if not c then
            c = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
            Core.Call(c, "SetEditModePreviewEnabled", false)
            Core.Call(c, "SetUnit", "player")
            -- (The game's default order put a proc after a cast buff: a new bar in the middle.)
            local sort, direction = _G.AuraContainerSortMethod, _G.AuraContainerSortDirection
            Core.Call(c, "AddAuraGroup", GROUP, YOURS, {
                maxFrameCount = MAX_BARS,
                initializeFrame = Build,
                candidateFilters = { includeSpellIDs = ids, isFromPlayerOrPlayerPet = true },
                sortMethod = sort and sort.AuraInstanceIDOnly,
                sortDirection = direction and direction.Normal,
            })
            groups.bar = c
        end
        DirectBars(c)
        if SameSet(ids, sent.bar) then return end
        sent.bar = ids
        Core.Call(c, "SetAuraGroupCandidateFilters", GROUP, { includeSpellIDs = ids, isFromPlayerOrPlayerPet = true })
        Core.Call(c, "SetEnabled", true)
        Core.Call(c, "Show")
        Core.Call(c, "UpdateAllAuras")
    end

    -- On top of `bars` cooldown bars; at once after a refresh.
    function Durations.Follow(bars)
        if bars == followedBars then return end
        local instant = followedBars == nil
        followedBars = bars
        StackAt(anchors.bar, bars, instant)
    end

    ---------------------------------------------------------------------------
    -- Both: the buff over the entry's own cooldown bar or icon, on one of the
    -- game's aura slots. While it is up the cooldown under it is unseen; as it
    -- ends, the cooldown shows (ShowCooldown, ShowIcon). An icon's spot is always
    -- its own; a bar's only while its cooldown runs - then its buff is in the buff
    -- bars' group instead, which closes up over it (PlaceBuffs). (Its spot kept
    -- while the buff might be up left an empty row in a fight, the buff unread.)
    -- A Duration icon is the same: its buff over its faint icon.
    ---------------------------------------------------------------------------

    local OVER = 10                         -- levels over the bar or icon it covers
    local slotContainer
    local slots = {}                        -- "bar3" / "icon3" -> its frame
    local slotOn = {}                       -- key -> the game shows its buff there
    local cooling = setmetatable({}, WEAK)  -- a Both bar entry -> its cooldown runs: its buff on its slot

    local function SlotOn(key, on)
        if not slots[key] or slotOn[key] == on then return end
        slotOn[key] = on
        Core.Call(slotContainer, "SetAuraSlotEnabled", key, on)
    end

    -- Whether an entry's buff lies over its bar (Both) or icon (Both or Duration).
    local function Covered(entry)
        local track = NS.TrackOf(entry)
        return track == "both" or (track == "buff" and IsIcon(entry))
    end

    local function CoverOf(index, entry)
        if Covered(entry) then return slots[(IsIcon(entry) and "icon" or "bar") .. index] end
    end

    local function Overlays()
        local wanted, changed = {}, false
        for index, entry in ipairs(NS.db.tracked) do
            if Covered(entry) then
                local icon = IsIcon(entry)
                local key = (icon and "icon" or "bar") .. index
                local over = icon and IconAt(index) or RowAt(index)
                local ranks = entryRanks[entry]
                local filters = { includeSpellIDs = ranks, isFromPlayerOrPlayerPet = true }
                if not slotContainer then
                    slotContainer = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
                    Core.Call(slotContainer, "SetEditModePreviewEnabled", false)
                    Core.Call(slotContainer, "SetUnit", "player")
                end
                if not slots[key] then
                    slots[key] = Core.Call(slotContainer, "AddAuraSlot", key, YOURS,
                        { initializeFrame = icon and BuildIcon or Build, candidateFilters = filters })
                    sent[key], slotOn[key], changed = ranks, true, true
                elseif not SameSet(ranks, sent[key]) then
                    Core.Call(slotContainer, "SetAuraSlotCandidateFilters", key, filters)
                    sent[key], changed = ranks, true
                end
                if icon then SlotOn(key, true) end      -- a bar's: PlaceBuffs
                local frame = slots[key]
                Core.Call(frame, "ClearAllPoints")
                Core.Call(frame, "SetAllPoints", over)
                Core.Call(frame, "SetFrameLevel", over:GetFrameLevel() + OVER)
                wanted[key] = true
            end
        end
        if not slotContainer then return end
        for key in pairs(slots) do
            if not wanted[key] and sent[key] then
                SlotOn(key, false)
                sent[key], changed = nil, true
            end
        end
        Core.Call(slotContainer, "SetFrameStrata", NS.db.frameStrata)
        Core.Call(slotContainer, "SetEnabled", next(wanted) ~= nil)
        if changed then Core.Call(slotContainer, "UpdateAllAuras") end
    end

    -- Each bar's buff where it shows: a Duration bar's in the buff bars' group; a Both
    -- bar's on its slot while its cooldown runs, else in the group too.
    local function PlaceBuffs()
        local ids = {}
        for index, entry in ipairs(NS.db.tracked) do
            local track = NS.TrackOf(entry)
            if not IsIcon(entry) and (track == "buff" or track == "both") then
                local onSlot = track == "both" and cooling[entry] == true
                if not onSlot then
                    for id in pairs(entryRanks[entry]) do ids[id] = true end
                end
                if track == "both" then SlotOn("bar" .. index, onSlot) end
            end
        end
        FillBars(ids)
    end

    -- Ranks, and whether a spell has a cooldown, worked out again; each bar's buff
    -- placed, each covered entry its slot.
    function Durations.Refresh()
        for entry in pairs(hasCooldown) do hasCooldown[entry] = nil end
        for entry in pairs(cooldownIDs) do cooldownIDs[entry] = nil end
        for entry in pairs(knownNow) do knownNow[entry] = nil end
        for entry in pairs(currentNow) do currentNow[entry] = nil end
        viewer = nil
        followedBars = nil
        MapRanks()
        Resize()
        Overlays()
        PlaceBuffs()
    end

    ---------------------------------------------------------------------------
    -- Placing: in line with the castbar's top, over the player frame's left
    -- edge - worked out once (first run, a reset), never following them after.
    ---------------------------------------------------------------------------

    local fromGuess = false   -- the player frame had no place yet: again at PLAYER_ENTERING_WORLD

    function Place()
        local db, castbar = NS.db, Core.Castbar
        local left = Core.Frames.db.playerLeft
        fromGuess = left == nil
        db.barLeft = left or (GetScreenWidth() - db.barWidth) / 2
        db.barTop = castbar.db.barTop or castbar.DefaultTop()
        db.autoPlaced = true
    end

    -- A saved list of buff IDs, whole numbers only; none: nil.
    local function BuffIDs(list)
        local ids = {}
        for _, id in ipairs(type(list) == "table" and list or {}) do ids[#ids + 1] = WholeID(id) end
        return ids[1] and ids or nil
    end

    -- Malformed or repeated entries go, the order kept; only kind, id, track, buff, buff IDs and
    -- display are kept. Buff IDs found another way than the game's own (other entries' auras
    -- among them: Shadowform's on Voidform) dropped once, found again.
    local BUFF_IDS_MATCH = 1
    function NS.Normalise(db)
        local seen, clean = {}, {}
        local strict = db.buffIDsMatch == BUFF_IDS_MATCH
        db.buffIDsMatch = BUFF_IDS_MATCH
        if type(db.tracked) ~= "table" then db.tracked = {} end
        for _, entry in ipairs(db.tracked) do
            if type(entry) == "table" and KINDS[entry.kind] and type(entry.id) == "number" and WholeID(entry.id) then
                local key = entry.kind .. ":" .. entry.id
                if not seen[key] then
                    seen[key] = true
                    clean[#clean + 1] = { kind = entry.kind, id = entry.id,
                        track = BUFF_TRACKS[entry.track] and entry.track or nil,
                        buff = (entry.buff == true or entry.buff == false) and entry.buff or nil,
                        buffIDs = strict and BuffIDs(entry.buffIDs) or nil,
                        display = IsIcon(entry) and "icon" or nil }
                end
            end
        end
        for i = #db.tracked, 1, -1 do db.tracked[i] = nil end
        for i, entry in ipairs(clean) do db.tracked[i] = entry end

        if not VALID_GROW[db.growDirection] then db.growDirection = "up" end
        if not VALID_GROW[db.iconRowsGrow] then db.iconRowsGrow = "up" end
        if not VALID_ICON_GROW[db.iconGrow] then db.iconGrow = NS.defaults.iconGrow end
        local function Within(value, low, high, default)
            return math.max(low, math.min(high, math.floor(tonumber(value) or default)))
        end
        local defaults = NS.defaults
        db.iconSize = Within(db.iconSize, NS.ICON_MIN, NS.ICON_MAX, defaults.iconSize)
        db.iconsPerRow = Within(db.iconsPerRow, 1, NS.PER_ROW_MAX, defaults.iconsPerRow)
        if OLD_DEFAULT_WIDTHS[db.barWidth] then db.barWidth = NS.defaults.barWidth end
        if db.barLeft == nil or db.barTop == nil then Place() end
        -- The first icon under the character, in the middle of the screen.
        if db.iconX == nil or db.iconY == nil then db.iconX, db.iconY = 0, ICONS_BELOW end
    end

    ---------------------------------------------------------------------------
    -- Drawing
    ---------------------------------------------------------------------------

    -- Unlocked: every bar full and named, every icon on its spot, to drag; one
    -- bar stands in for an empty list.
    local function ShowPlacing()
        local tracked = NS.db.tracked
        local count = math.max(1, #tracked)
        local barSlot, iconSlot = 0, 0
        for index = 1, count do
            local entry = tracked[index]
            local frame
            if entry and IsIcon(entry) then
                frame = IconAt(index)
                GridAt(frame, iconSlot, true)
                iconSlot = iconSlot + 1
            else
                frame = RowAt(index)
                StackAt(frame, barSlot, true)
                barSlot = barSlot + 1
            end
            local name, texture = "Cooldowns", QUESTION_MARK
            if entry then name, texture = NS.Describe(entry) end
            frame.icon:SetTexture(texture)
            if frame.bar then
                frame.bar:SetMinMaxValues(0, 1)
                frame.bar:SetValue(1)
                frame.spark:SetAlpha(0)
                frame.nameText:SetText(name)
            else
                frame.swipe:Clear()
                frame.icon:SetDesaturated(false)
            end
            frame.countText:SetText("")
            frame.timeText:SetText("")
            Style.ShowNow(frame)
        end
        PlaceGrid(iconSlot)
        HideBeyond(count)
    end

    local BOTH_WAIT = 0.4                       -- a Both cooldown's wait for its buff, up a moment after the cast
    local started = setmetatable({}, WEAK)      -- a Both entry -> when its cooldown began

    -- Whether `entry` cools down now (true, false, or a secret never looked at), its duration
    -- and a spell's charges. A Both entry's (`cover`) only a moment after it starts, as its
    -- buff lands then and the cooldown flashed before it; `waiting`, true meanwhile.
    local function ReadCooldown(entry, cooldownEvent, cover)
        local shown, duration, charges
        if entry.kind == "spell" then
            shown, duration, charges = SpellCooldown(entry, cooldownEvent)
        else
            shown, duration = ItemCooldown(entry)
        end
        local secret = IsSecret(shown)
        if not (secret or shown == true) then
            started[entry] = nil
        elseif cover and not secret then
            started[entry] = started[entry] or GetTime()
            if GetTime() - started[entry] < BOTH_WAIT then return shown, duration, charges, true end
        end
        return shown, duration, charges, false
    end

    local function ShowCount(label, charges)
        if charges == nil or not pcall(label.SetText, label, charges) then label:SetText("") end
    end

    local barSince = setmetatable({}, WEAK)     -- entry -> when its bar came: its place, the oldest lowest

    -- A bar for `entry` on spot `slot`; `cover`, a Both entry's buff over it while its
    -- cooldown runs (`cooling`). Answers the next spot.
    local function ShowCooldown(frame, entry, slot, cooldownEvent, instant, cover)
        local shown, duration, charges, waiting = ReadCooldown(entry, cooldownEvent, cover)
        local secret = IsSecret(shown)
        if cover then cooling[entry] = secret or shown == true end

        if not (secret or shown == true) then
            -- Fading out keeps its place, so the ones beyond don't slide onto it. Gone, it
            -- holds no spot: the stack closes up (a Both entry's buff, still up, is in the
            -- buff bars' group by then).
            if not frame:IsShown() then
                barSince[entry] = nil
                return slot
            end
            StackAt(frame, slot, instant)
            Style.FadeOut(frame)
            return slot + 1
        end

        barSince[entry] = barSince[entry] or GetTime()
        StackAt(frame, slot, instant or not frame:IsShown())
        local name, texture = NS.Describe(entry)
        frame.icon:SetTexture(texture)
        frame.nameText:SetText(name)
        local bar = frame.bar
        if duration and pcall(bar.SetTimerDuration, bar, duration, IMMEDIATE, REMAINING) then
            frame.spark:SetAlpha(1)
        else
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            frame.spark:SetAlpha(0)
        end
        ShowTime(frame.timeText, duration, NS.formatter)
        ShowCount(frame.countText, charges)
        if secret then
            -- Never looked at: the game shows or hides it.
            Style.ShowNow(frame)
            frame:SetAlphaFromBoolean(shown, 1, 0)
        elseif cover then
            -- Unseen until its buff has had its moment to come; then under it,
            -- hidden while it is up. The buff's frame is never touched: the
            -- game denies addons it while auras are secret (in combat). Its
            -- spark (taller than the bar) would poke out round the buff's.
            Style.ShowNow(frame)
            frame.spark:SetAlpha(0)
            if waiting then frame:SetAlpha(0) end
        elseif instant then
            Style.ShowNow(frame)
        else
            Style.FadeIn(frame)
        end
        return slot + 1
    end

    -- An icon for `entry`, always on spot `slot`: lit while it cools down, faint and grey
    -- while it doesn't (a Duration icon always: its buff, the game's, glowing, lies over it
    -- while up, as a Both icon's does - `cover`).
    local function ShowIcon(icon, entry, slot, cooldownEvent, instant, cover)
        GridAt(icon, slot, instant)
        local _, texture = NS.Describe(entry)
        icon.icon:SetTexture(texture)
        local shown, duration, charges, waiting = false, nil, nil, false
        if NS.ShowsCooldown(entry) then shown, duration, charges, waiting = ReadCooldown(entry, cooldownEvent, cover) end
        local secret = IsSecret(shown)
        if not secret and (waiting or not shown) then shown, duration = false, nil end

        if not (duration and pcall(icon.swipe.SetCooldownFromDurationObject, icon.swipe, duration)) then
            icon.swipe:Clear()
        end
        ShowTime(icon.timeText, duration, NS.iconFormatter)
        ShowCount(icon.countText, charges)
        icon:Show()
        if secret then
            -- Never looked at: the game picks.
            icon:SetAlphaFromBoolean(shown, 1, IDLE_ALPHA)
            icon.icon:SetDesaturation(C_CurveUtil.EvaluateColorValueFromBoolean(shown, 0, 1))
        else
            icon:SetAlpha(shown and 1 or IDLE_ALPHA)
            icon.icon:SetDesaturated(not shown)
        end
        return slot + 1
    end

    local fighting = false                      -- in combat: the icons shown though Hide out of combat is on

    -- The bars in the order they came (the list's order ties): the oldest lowest, a new
    -- one on top, the rest closing up as one goes. (In the list's order, one came in the
    -- middle of the stack.)
    local barOrder = {}                         -- the bar entries' indexes, each Update
    local function Older(a, b)
        local tracked = NS.db.tracked
        local x, y = barSince[tracked[a]] or math.huge, barSince[tracked[b]] or math.huge
        if x ~= y then return x < y end
        return a < b
    end

    -- Bar entries stack as bars, each while it has a cooldown (and while placing
    -- an empty list); icon entries fill the icon rows, each on its spot.
    -- `cooldownEvent`: SPELL_UPDATE_COOLDOWN just fired, isOnGCD can be read.
    -- `instant`: a setting changed, bars and icons appear at once.
    function Update(cooldownEvent, instant)
        if resizeWaiting then Resize() end
        local db = NS.db
        local tracked = db.tracked
        local hasBar, hasIcon = #tracked == 0 and db.unlocked, false
        for _, entry in ipairs(tracked) do
            if IsIcon(entry) then hasIcon = true else hasBar = true end
        end
        holder:SetShown(hasBar)
        iconHolder:SetShown(hasIcon and (fighting or db.unlocked or not db.hideIconsOutOfCombat))
        if not (hasBar or hasIcon) then
            HideBeyond(0)
            Polling(false)
            return
        end
        if db.unlocked then
            ShowPlacing()
            Polling(true)
            return
        end

        local barSlot, iconSlot = 0, 0
        wipe(barOrder)
        for index, entry in ipairs(tracked) do
            local isIcon, cooldown = IsIcon(entry), NS.ShowsCooldown(entry)
            -- Not of the spec now (a talent not taken, another spec's spell), nothing; a
            -- bar's buff alone is the game's group's; a spell not had now shows no cooldown;
            -- one with neither cooldown nor buff, nothing.
            if not NS.IsCurrent(entry) or (cooldown and not NS.KnownNow(entry))
               or not (cooldown or (isIcon and NS.ShowsBuff(entry))) then
                local frame = (isIcon and icons or rows)[index]
                if frame then Style.HideNow(frame) end
                barSince[entry], cooling[entry] = nil, nil
            elseif isIcon then
                iconSlot = ShowIcon(IconAt(index), entry, iconSlot, cooldownEvent, instant, CoverOf(index, entry))
            else
                barOrder[#barOrder + 1] = index
            end
        end
        table.sort(barOrder, Older)
        local moved = false                     -- a Both bar's buff to or from its slot
        for _, index in ipairs(barOrder) do
            local entry = tracked[index]
            local was = cooling[entry]
            barSlot = ShowCooldown(RowAt(index), entry, barSlot, cooldownEvent, instant, CoverOf(index, entry))
            moved = moved or cooling[entry] ~= was
        end
        if moved then PlaceBuffs() end
        PlaceGrid(iconSlot)
        HideBeyond(#tracked)
        Durations.Follow(barSlot)

        -- Polled while anything is tracked: an ending fires no event, and after
        -- a loading screen neither may a cooldown the game reports late.
        Polling(true)
    end
    NS.Update = Update

    function Refresh()
        local db = NS.db
        holder:SetFrameStrata(db.frameStrata)
        holder:SetSize(db.barWidth, db.barHeight)
        Core.Snap.Put(holder, db)
        iconHolder:SetFrameStrata(db.frameStrata)
        iconHolder:SetSize(db.iconSize, db.iconSize)
        iconHolder:ClearAllPoints()
        iconHolder:SetPoint("CENTER", UIParent, "CENTER", db.iconX, db.iconY)

        -- Settings changed: redrawn and replaced at once.
        for _, row in pairs(rows) do
            LayOutRow(row)
            Style.HideNow(row)
        end
        for _, icon in pairs(icons) do
            LayOutIcon(icon, icon)
            Style.HideNow(icon)
        end
        Durations.Refresh()
        Update(true, true)
    end

    local elapsedSince, polling = 0, false
    local function Poll(_, elapsed)
        elapsedSince = elapsedSince + elapsed
        if elapsedSince < POLL then return end
        elapsedSince = 0
        Update(false)
    end

    -- On the module's own frame: the holder is hidden while icons are shown.
    function Polling(on)
        if on == polling then return end
        polling = on
        NS:SetScript("OnUpdate", on and Poll or nil)
    end

    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES",
                             "BAG_UPDATE_COOLDOWN", "GET_ITEM_INFO_RECEIVED", "SPELLS_CHANGED",
                             "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        NS:RegisterEvent(event)
    end
    pcall(NS.RegisterEvent, NS, "COOLDOWN_VIEWER_DATA_LOADED")     -- retail: its buffs known
    NS:RegisterUnitEvent("UNIT_PET", "player")                     -- a pet's spells had or not

    -- The spells changed: worked out again once, a frame later - a shapeshift, a stance or
    -- a talent fires SPELLS_CHANGED in bursts, in combat too.
    local SpellsChanged = Core.Waker(function()
        Durations.Refresh()
        Core.RefreshOptions()
        Update(false)
        return false
    end)

    local function Tracks(kind, id)
        for _, entry in ipairs(NS.db.tracked) do
            if entry.kind == kind and entry.id == id then return true end
        end
        return false
    end

    NS:SetScript("OnEvent", function(_, event, id)
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            fighting = event == "PLAYER_REGEN_DISABLED"
            Update(false)
            return
        end
        if event == "PLAYER_ENTERING_WORLD" then
            fighting = InCombatLockdown()
            -- The frames are placed now: a guessed spot worked out again, never the player's.
            if NS.db.autoPlaced and fromGuess then Place() end
            Refresh()
            Core.RefreshOptions()
            return
        end
        if event == "SPELLS_CHANGED" or event == "COOLDOWN_VIEWER_DATA_LOADED" or event == "UNIT_PET" then
            SpellsChanged()
            return
        end
        -- (Any item in the game loading fires it: only a tracked one's name redraws.)
        if event == "GET_ITEM_INFO_RECEIVED" then
            if not Tracks("item", id) then return end
            Core.RefreshOptions()
        end
        Update(event == "SPELL_UPDATE_COOLDOWN")
    end)

    -- Snapped by the whole stack on screen, not just the first bar; what hangs
    -- from it (the icons, anchored) hangs from the stack at its tallest - every
    -- bar entry up, as placing shows it - so nothing ever overlaps it.
    local stack = {}            -- the rows, asked for every frame: one list
    SavePlace = Core.Snap.Piece(holder, NS, {
        name = "Cooldown Bars", id = "cooldowns",
        parts = function()
            wipe(stack)
            for _, row in pairs(rows) do stack[#stack + 1] = row end
            return stack
        end,
        reach = function()
            local bars = 0
            for _, entry in ipairs(NS.db.tracked) do
                if not IsIcon(entry) then bars = bars + 1 end
            end
            local reach = math.max(0, bars - 1) * (NS.db.barHeight + GAP)
            if GrowsDown() then return 0, reach end
            return reach, 0
        end,
    }, Refresh)
    holder:EnableMouse(false)   -- dragged by its rows: the scripts Piece set catch no clicks

    -- The icons' piece, moved by its mover, snapped by every icon on screen:
    -- the first icon's middle saved from the screen's.
    iconHolder:SetMovable(true)
    iconHolder:SetClampedToScreen(true)
    Core.Snap.Register(iconHolder, {
        name = "Cooldown Icons", id = "cooldownicons",
        parts = function()
            local list = {}
            for _, icon in pairs(icons) do list[#list + 1] = icon end
            return list
        end,
        save = function()
            local x, y = iconHolder:GetCenter()
            local cx, cy = UIParent:GetCenter()
            NS.db.iconX, NS.db.iconY = x - cx, y - cy
            Refresh()
            Core.RefreshOptions()
        end,
    })

    NS.Init = Refresh
    NS.Refresh = Refresh

    Core:RegisterModule(NS)
end

-------------------------------------------------------------------------------
-- IDs on tooltips: "Spell ID 2983" / "Item ID 6948", small and grey at the foot.
-- One post-call for every kind, added at the first PLAYER_ENTERING_WORLD so the
-- line comes last. A secret ID is never read: the line's SetFormattedText gets it.
-------------------------------------------------------------------------------

do -- private scope
    local Cooldowns = DogsForeverUI.Cooldowns
    local Core = DogsForeverUI
    local IsSecret = issecretvalue

    local GREY = { 0.55, 0.55, 0.55 }
    local SPELL, ITEM = "Spell ID", "Item ID"
    local TEXT_SIZE = 10
    local SECRET_ROOM = "000000"   -- a secret ID's line, as wide as its number
    local WEAK = { __mode = "k" }
    -- The C_TooltipInfo getters of a unit's aura.
    local AURA_GETTERS = {
        GetUnitAura = true, GetUnitAuraByAuraInstanceID = true,
        GetUnitBuff = true, GetUnitBuffByAuraInstanceID = true,
        GetUnitDebuff = true, GetUnitDebuffByAuraInstanceID = true,
    }

    local restore = setmetatable({}, WEAK)   -- tooltip -> { line = its own font }
    local added = setmetatable({}, WEAK)     -- tooltip -> its line since last cleared (processed twice: one line)
    local hooked = setmetatable({}, WEAK)

    -- The tooltips' face (the addon's) at TEXT_SIZE: their small font is 12 too.
    local idFont
    local function IDFont()
        if not idFont then
            idFont = CreateFont("DogsForeverUITooltipIDFont")
            local file, _, flags = GameTooltipTextSmall:GetFont()
            idFont:SetFont(file, TEXT_SIZE, flags or "")
        end
        return idFont
    end

    -- The next tooltip to use that line has its normal size again.
    local function Cleared(tooltip)
        added[tooltip] = nil
        local fonts = restore[tooltip]
        if not fonts then return end
        for line, font in pairs(fonts) do line:SetFontObject(font) end
        restore[tooltip] = nil
    end

    local function LastLine(tooltip)
        local name, count = tooltip:GetName(), tooltip:NumLines()
        if IsSecret(name) or IsSecret(count) or type(name) ~= "string" or count < 1 then return nil end
        return _G[name .. "TextLeft" .. count]
    end

    local function Number(value)
        if IsSecret(value) or type(value) ~= "number" or value <= 0 then return nil end
        return value
    end

    -- What the tooltip was built from: C_TooltipInfo's getter and its arguments.
    local function BuiltFrom(tooltip)
        if not tooltip.GetPrimaryTooltipInfo then return nil end
        local ok, info = pcall(tooltip.GetPrimaryTooltipInfo, tooltip)
        if ok and type(info) == "table" then return info end
    end

    -- An action button (a spell, an item, a macro's), a pet button, a stance.
    local function FromGetter(tooltip)
        local info = BuiltFrom(tooltip)
        if not info or type(info.getterArgs) ~= "table" then return end
        local getter, first = info.getterName, info.getterArgs[1]
        if IsSecret(getter) or IsSecret(first) or first == nil then return end

        if getter == "GetAction" then
            local kind, id, subType = Core.Try(GetActionInfo, first)
            if IsSecret(kind) or IsSecret(subType) then return end
            -- A macro showing a spell or item hands back its ID, the subtype saying which.
            if kind == "spell" or (kind == "macro" and subType == "spell") then return SPELL, Number(id) end
            if kind == "item" or (kind == "macro" and subType == "item") then return ITEM, Number(id) end
            if kind == "macro" then return SPELL, Number((Core.Try(GetMacroSpell, id))) end
        elseif getter == "GetPetAction" then
            return SPELL, Number((select(7, Core.Try(GetPetActionInfo, first))))
        elseif getter == "GetShapeshift" then
            return SPELL, Number((select(4, Core.Try(GetShapeshiftFormInfo, first))))
        end
    end

    local function Index(t, key) return t[key] end

    -- A field of the tooltip data, which may be a secret table (each field comes back secret).
    local function Field(data, key)
        if type(data) ~= "table" and not issecrettable(data) then return nil end
        local ok, value = pcall(Index, data, key)
        if ok then return value end
    end

    -- The label for a plain tooltip data kind.
    local function LabelOf(kind)
        local kinds = Enum.TooltipDataType
        if kind == kinds.Spell or kind == kinds.UnitAura then return SPELL end
        if kind == kinds.Item or kind == kinds.Toy then return ITEM end
    end

    -- The line's label and the ID, or nothing; true third when the ID is secret.
    local function Resolve(tooltip, data)
        local kind, raw = Field(data, "type"), Field(data, "id")
        local plainKind = not IsSecret(kind) and kind ~= nil
        if IsSecret(raw) then
            local label
            if plainKind then
                label = LabelOf(kind)
            else
                -- The kind secret too: the getter says whether it was an aura's.
                local info = BuiltFrom(tooltip)
                local getter = info and info.getterName
                if not IsSecret(getter) and AURA_GETTERS[getter] then label = SPELL end
            end
            if label then return label, raw, true end
            return
        end
        local id = Number(raw)
        if id and plainKind then
            local label = LabelOf(kind)
            if label then return label, id end
            -- A mount's data carries the mount's ID: its spell is in the journal.
            if kind == Enum.TooltipDataType.Mount then
                local spell = Number((select(2, Core.Try(Core.Api("C_MountJournal", "GetMountInfoByID"), id))))
                if spell then return SPELL, spell end
            end
        end
        local label, fromGetter = FromGetter(tooltip)
        if label and fromGetter then return label, fromGetter end
    end

    local function AddLine(tooltip, data)
        -- (A tooltip the game forbids to add-ons - a UI widget's EmbeddedItemTooltip, say -
        -- refuses even a hook: asking whether it is forbidden is all that is allowed.)
        if not Cooldowns.db.showTooltipIDs or tooltip:IsForbidden() then return end
        -- `label` stands for the ID: the ID itself may be secret, never tested.
        local label, id, secret = Resolve(tooltip, data)
        if not label then return end
        if secret then
            -- Shown only through the line itself: no line without a named tooltip.
            local name = tooltip:GetName()
            if IsSecret(name) or type(name) ~= "string" then return end
        end
        local text = label .. " " .. (secret and SECRET_ROOM or id)
        if added[tooltip] == text then return end
        added[tooltip] = text

        if not hooked[tooltip] then
            hooked[tooltip] = true
            tooltip:HookScript("OnTooltipCleared", Cleared)
        end
        tooltip:AddLine(text, unpack(GREY))
        local line = LastLine(tooltip)
        if line then
            if secret then line:SetFormattedText(label .. " %d", id) end
            local fonts = restore[tooltip] or {}
            restore[tooltip] = fonts
            if fonts[line] == nil then fonts[line] = line:GetFontObject() or GameTooltipText end
            line:SetFontObject(IDFont())
        end
        tooltip:Show()
    end

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_ENTERING_WORLD")
    loader:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        local processor = TooltipDataProcessor
        if processor then processor.AddTooltipPostCall(processor.AllTypes, AddLine) end
    end)

    ---------------------------------------------------------------------------
    -- Talent ranks: "1/5" on a class talent button, not the game's bare "1".
    -- One-rank talents and buttons the game leaves blank keep its text.
    ---------------------------------------------------------------------------

    local function AfterSpendText(button, text)
        local talents = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
        if not (talents and button.GetTalentFrame and button:GetTalentFrame() == talents) then return end
        local info = button.nodeInfo
        if text == nil or tostring(text) == "" or type(info) ~= "table" then return end
        local current, max = info.currentRank, info.maxRanks
        if type(current) ~= "number" or type(max) ~= "number" or max <= 1 then return end
        local shown = current .. "/" .. max
        if button.SpendText then button.SpendText:SetText(shown) end
        for _, shadow in ipairs(button.spendTextShadows or {}) do shadow:SetText(shown) end
    end

    -- Hooked once the game's talent code is there.
    local talentLoader = CreateFrame("Frame")
    local function HookTalents()
        if not TalentButtonUtil then return end
        hooksecurefunc(TalentButtonUtil, "SetSpendText", AfterSpendText)
        talentLoader:UnregisterAllEvents()
    end
    talentLoader:RegisterEvent("ADDON_LOADED")
    talentLoader:SetScript("OnEvent", HookTalents)
    HookTalents()
end
