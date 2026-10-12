-- MODULE: Cooldowns  (DogsForeverUI.Cooldowns, settings section "cooldowns")
-- Bars for spells and items added by ID while they cool down, or a spell's buff
-- while it runs (the game's aura container). Also IDs on tooltips and talent ranks.
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
        frameStrata = "MEDIUM",
        showTooltipIDs = true,
        tracked = {},            -- { kind, id, track, buff }, in order
    }
    NS.placement = { barLeft = true, barTop = true, autoPlaced = true }
    NS.keep = { tracked = true }   -- the player's own list survives Reset everything

    NS.GROW = {
        { value = "up",   label = "Upward" },
        { value = "down", label = "Downward" },
    }
    -- A spell with a cooldown and a buff: what its row tracks ("cooldown" is stored as nothing).
    NS.TRACK = {
        { value = "cooldown", label = "Cooldown" },
        { value = "buff",     label = "Duration" },
        { value = "both",     label = "Both" },
    }

    local KINDS = { spell = "Spell", item = "Item" }
    local VALID_GROW = { up = true, down = true }
    local BUFF_TRACKS = { buff = true, both = true }   -- the tracks saved; "cooldown" is nil
    local OLD_DEFAULT_WIDTHS = { [200] = true, [130] = true }   -- earlier defaults, taken as today's
    local NOT_AN_ID = "Type a spell or item ID: a whole number."

    local GAP = 6 + 2 * Style.BORDER_INSET   -- room for two borders drawn outside their bars
    local POLL = 0.1                          -- a cooldown ends with no event
    local MIN_ITEM_COOLDOWN = 1.5             -- shorter is the global cooldown
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

    -- An item's name may not be loaded yet: asked for, GET_ITEM_INFO_RECEIVED redraws.
    function NS.Describe(entry)
        local name, icon
        if entry.kind == "spell" then
            name = Ask("C_Spell", "GetSpellName", entry.id)
            icon = Ask("C_Spell", "GetSpellTexture", entry.id)
        else
            name = Ask("C_Item", "GetItemNameByID", entry.id)
            icon = Ask("C_Item", "GetItemIconByID", entry.id) or select(5, Ask("C_Item", "GetItemInfoInstant", entry.id))
            if not name then Ask("C_Item", "RequestLoadItemDataByID", entry.id) end
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

    function NS.Remove(index)
        if not NS.db.tracked[index] then return end
        table.remove(NS.db.tracked, index)
        Refresh()
    end

    ---------------------------------------------------------------------------
    -- What an entry tracks. A spell with no cooldown tracks its buff; whether
    -- it leaves one is learned (entry.buff, saved): no API says so.
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

    function NS.HasChoice(entry)
        return NS.HasCooldown(entry) and entry.kind == "spell" and entry.buff == true
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

    local onGCD = setmetatable({}, WEAK)          -- isOnGCD, trusted only on SPELL_UPDATE_COOLDOWN
    local itemDurations = setmetatable({}, WEAK)  -- reused duration objects
    local cooldownIDs = setmetatable({}, WEAK)    -- until a refresh

    -- The game may answer nothing for a rank you don't know: the ID as added
    -- while in your spellbook, else the rank it knows by the name.
    function NS.CooldownID(entry)
        local id = cooldownIDs[entry]
        if id then return id end
        id = entry.id
        if not InBook(id) then id = KnownRank(id) or id end
        cooldownIDs[entry] = id
        return id
    end

    local function SpellCooldown(entry, cooldownEvent)
        local id = NS.CooldownID(entry)
        local charges = Ask("C_Spell", "GetSpellCharges", id)
        if HasCharges(charges) then   -- the next charge coming back
            return charges.isActive, Ask("C_Spell", "GetSpellChargeDuration", id), charges.currentCharges
        end

        local info = Ask("C_Spell", "GetSpellCooldown", id)
        if type(info) ~= "table" then return false end
        local active = info.isActive
        if IsSecret(active) then
            return active, Ask("C_Spell", "GetSpellCooldownDuration", id, true)
        end
        if not active then
            onGCD[entry] = nil
            return false
        end
        if cooldownEvent or onGCD[entry] == nil then
            local gcd = info.isOnGCD
            onGCD[entry] = not IsSecret(gcd) and gcd == true
        end
        if onGCD[entry] then return false end
        return true, Ask("C_Spell", "GetSpellCooldownDuration", id, true)
    end

    local function ItemCooldown(entry)
        local start, length, enabled = Ask("C_Item", "GetItemCooldown", entry.id)
        if not (Plain(start, "number") and Plain(length, "number")) or IsSecret(enabled) then return false end
        if enabled == false or enabled == 0 then return false end
        if start <= 0 or length <= MIN_ITEM_COOLDOWN or start + length <= GetTime() then return false end

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
    -- The time left, formatted by the game ("45s", "1m 30s"): cooldowns round
    -- up like the action buttons, buffs truncate like the game's buff timers.
    ---------------------------------------------------------------------------

    local function MakeFormatter(rounding)
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
            f:SetDesiredUnitCount(2)
            return f
        end)
        if ok then return made end
    end
    local formatter = MakeFormatter("RoundUp")
    NS.formatter = formatter
    NS.auraFormatter = MakeFormatter("Truncate")

    -- The text is secret in combat: handed on, never compared, every hand-over guarded.
    local function ShowTime(label, duration)
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

    local function HideBeyond(last)
        for index, row in pairs(rows) do
            if index > last then Style.HideNow(row) end
        end
    end

    -- Sliding: bars closing up glide there, easing in (SLIDE_RATE: most of the
    -- way in a quarter second at any frame rate); a new target on the way is
    -- simply taken. Only our own frames move, by anchor offsets.
    local SLIDE_RATE = 12            -- per second: 1 - e^(-rate * t) of the way
    local SNAP = 0.5                 -- close enough to stop, in UI units
    local sliding = setmetatable({}, WEAK)   -- frame -> { point, y, target }

    local function PutAt(frame, point, y)
        frame:ClearAllPoints()
        frame:SetPoint(point, holder, point, 0, y)
    end

    local WakeSlider = Core.Waker(function(elapsed)
        local step = 1 - math.exp(-SLIDE_RATE * elapsed)
        local moving = false
        for frame, s in pairs(sliding) do
            if s.y ~= s.target then
                local y = s.y + (s.target - s.y) * step
                if math.abs(s.target - y) < SNAP then y = s.target end
                s.y = y
                PutAt(frame, s.point, y)
                if y ~= s.target then moving = true end
            end
        end
        return moving
    end)

    -- `frame` `count` bars up (or down) from the holder, gliding there unless
    -- `instant` - or new, or after a change of direction: nothing to glide from.
    local function StackAt(frame, count, instant)
        local point = GrowsDown() and "TOPLEFT" or "BOTTOMLEFT"
        local y = count * (NS.db.barHeight + GAP) * (GrowsDown() and -1 or 1)
        local s = sliding[frame]
        if instant or not s or s.point ~= point then
            sliding[frame] = { point = point, y = y, target = y }
            PutAt(frame, point, y)
        elseif s.target ~= y then
            s.target = y
            WakeSlider()
        end
    end

    ---------------------------------------------------------------------------
    -- Buff bars: the game's aura container for add-ons, filtered to every rank
    -- of the tracked spells. The game fills and runs each button, nothing is
    -- read; the addon shapes a button only as it is made (initializeFrame).
    -- It won't say how many it shows, so its stack rides on the cooldown bars.
    ---------------------------------------------------------------------------

    local GROUP = "tracked"
    local MAX_BARS = 20
    local DARK = { 0.05, 0.05, 0.05, 1 }   -- the elapsed part, over the colour
    local TIME_ROOM = 40                   -- kept clear for "59 m" and the like
    local SHEEN, SHADE = 0.22, 0.25        -- as Style's sheen, under the game's fill
    local LOOK_AFTER = 0.5                 -- seconds after a cast, to look for its buff

    local entryRanks = setmetatable({}, WEAK)   -- entry -> { [id] = true }
    local rankOwners = {}                       -- id -> { entry, ... }

    -- Every ID of the spell's ranks you have, into `ids`: as added, the
    -- game's by name, and the spellbook's of that name.
    local function AddRanks(id, ids)
        ids[id] = true
        local known, name = KnownRank(id)
        if not name then return end
        if known then ids[known] = true end
        local lines = Ask("C_SpellBook", "GetNumSpellBookSkillLines")
        if not Plain(lines, "number") then return end
        local bank = Core.EnumValue("SpellBookSpellBank", "Player", 0)
        for line = 1, lines do
            local skill = Ask("C_SpellBook", "GetSpellBookSkillLineInfo", line)
            if type(skill) == "table" and Plain(skill.itemIndexOffset, "number")
               and Plain(skill.numSpellBookItems, "number") then
                for slot = skill.itemIndexOffset + 1, skill.itemIndexOffset + skill.numSpellBookItems do
                    local item = Ask("C_SpellBook", "GetSpellBookItemInfo", slot, bank)
                    if type(item) == "table" and Plain(item.name, "string") and item.name == name
                       and Plain(item.spellID, "number") then
                        ids[item.spellID] = true
                    end
                end
            end
        end
    end

    local function AurasReadable()
        local secret = Ask("C_Secrets", "ShouldAurasBeSecret")
        return not (IsSecret(secret) or secret == true)
    end

    local function BuffUp(ranks)
        for id in pairs(ranks) do
            local aura = Ask("C_UnitAuras", "GetPlayerAuraBySpellID", id)
            if not IsSecret(aura) and aura ~= nil then return true end
        end
        return false
    end

    -- Each spell entry's ranks and each ID's entries; a buff already on you noticed.
    local function MapRanks()
        for id in pairs(rankOwners) do rankOwners[id] = nil end
        local readable = AurasReadable()
        for _, entry in ipairs(NS.db.tracked) do
            if entry.kind == "spell" then
                local ranks = {}
                AddRanks(entry.id, ranks)
                entryRanks[entry] = ranks
                for id in pairs(ranks) do
                    rankOwners[id] = rankOwners[id] or {}
                    table.insert(rankOwners[id], entry)
                end
                if entry.buff ~= true and readable and BuffUp(ranks) then entry.buff = true end
            end
        end
    end

    -- After a cast: its buff seen means it has one; missing proves nothing
    -- while auras are secret (combat), and "none" otherwise.
    local function Look(entries)
        local changed = false
        local readable = AurasReadable()
        for _, entry in ipairs(entries) do
            local ranks = entryRanks[entry]
            if ranks and tContains(NS.db.tracked, entry) then
                local learned
                if BuffUp(ranks) then learned = true elseif readable then learned = false end
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

    local learner = CreateFrame("Frame")
    learner:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    learner:SetScript("OnEvent", function(_, _, _, _, spellID)
        if IsSecret(spellID) or not rankOwners[spellID] then return end
        local entries = {}
        for i, entry in ipairs(rankOwners[spellID]) do entries[i] = entry end
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

    -- A new size for bars already made, only while auras aren't secret. Sizes only:
    -- re-laying the game's name and time was refused half way and lost every name.
    local function Resize()
        if not AurasReadable() then return end
        local width, height = NS.db.barWidth, NS.db.barHeight
        for _, button in ipairs(buttons) do
            local p = pieces[button]
            if p.width ~= width or p.height ~= height then
                p.width, p.height = width, height
                pcall(button.SetSize, button, width, height)
                pcall(p.icon.SetSize, p.icon, height, height)
                pcall(p.bar.SetSize, p.bar, math.max(1, width - height - p.px), height)
            end
        end
    end

    local anchor = CreateFrame("Frame", nil, holder)
    anchor:SetSize(1, 1)
    Durations.anchor = anchor
    local placedSlots, placedDown, placedHeight   -- what it was last placed for (nil: not since a refresh)

    local function Direct(c)
        local flow, down = AnchorUtil.FlowDirection, GrowsDown()
        local point = down and "TOPLEFT" or "BOTTOMLEFT"
        Core.Call(c, "SetFlowLayoutAxis", AnchorUtil.FlowLayoutAxis.Vertical)
        Core.Call(c, "SetFlowLayoutAnchorPoint", point)
        Core.Call(c, "SetFlowLayoutGrowthDirection", flow.Right, down and flow.Down or flow.Up)
        Core.Call(c, "ClearAllPoints")
        Core.Call(c, "SetPoint", point, anchor, point, 0, 0)
    end

    local function CreateContainer(ids)
        local c = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
        Core.Call(c, "SetEditModePreviewEnabled", false)
        Core.Call(c, "SetUnit", "player")
        Direct(c)
        Core.Call(c, "AddAuraGroup", GROUP, "HELPFUL", {
            maxFrameCount = MAX_BARS,
            initializeFrame = Build,
            candidateFilters = { includeSpellIDs = ids },
            layout = { elementSpacing = GAP, lineSpacing = GAP },
        })
        Durations.container = c
        return c
    end

    -- On top of `slots` cooldown bars; at once after a refresh.
    function Durations.Follow(slots)
        local db, down = NS.db, GrowsDown()
        if slots == placedSlots and down == placedDown and db.barHeight == placedHeight then return end
        local instant = placedSlots == nil
        placedSlots, placedDown, placedHeight = slots, down, db.barHeight
        StackAt(anchor, slots, instant)
    end

    -- Ranks, and whether a spell has a cooldown, worked out again.
    function Durations.Refresh()
        for entry in pairs(hasCooldown) do hasCooldown[entry] = nil end
        for entry in pairs(cooldownIDs) do cooldownIDs[entry] = nil end
        placedSlots = nil
        MapRanks()
        local ids = {}
        for _, entry in ipairs(NS.db.tracked) do
            if NS.ShowsBuff(entry) then
                for id in pairs(entryRanks[entry]) do ids[id] = true end
            end
        end

        local c = Durations.container
        if not next(ids) then
            if c then
                Core.Call(c, "SetEnabled", false)
                Core.Call(c, "Hide")
            end
            return
        end
        c = c or CreateContainer(ids)
        Core.Call(c, "SetAuraGroupCandidateFilters", GROUP, { includeSpellIDs = ids })
        Direct(c)
        Resize()
        Core.Call(c, "SetEnabled", true)
        Core.Call(c, "Show")
        Core.Call(c, "UpdateAllAuras")
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

    -- Malformed or repeated entries go, the order kept; only kind, id, track and buff are kept.
    function NS.Normalise(db)
        local seen, clean = {}, {}
        if type(db.tracked) ~= "table" then db.tracked = {} end
        for _, entry in ipairs(db.tracked) do
            if type(entry) == "table" and KINDS[entry.kind] and type(entry.id) == "number" and WholeID(entry.id) then
                local key = entry.kind .. ":" .. entry.id
                if not seen[key] then
                    seen[key] = true
                    clean[#clean + 1] = { kind = entry.kind, id = entry.id,
                        track = BUFF_TRACKS[entry.track] and entry.track or nil,
                        buff = (entry.buff == true or entry.buff == false) and entry.buff or nil }
                end
            end
        end
        for i = #db.tracked, 1, -1 do db.tracked[i] = nil end
        for i, entry in ipairs(clean) do db.tracked[i] = entry end

        if not VALID_GROW[db.growDirection] then db.growDirection = "up" end
        if OLD_DEFAULT_WIDTHS[db.barWidth] then db.barWidth = NS.defaults.barWidth end
        if db.barLeft == nil or db.barTop == nil then Place() end
    end

    ---------------------------------------------------------------------------
    -- Drawing
    ---------------------------------------------------------------------------

    -- Unlocked: every bar full, named, to drag; one stands in for an empty list.
    local function ShowPlacing()
        local tracked = NS.db.tracked
        local count = math.max(1, #tracked)
        for index = 1, count do
            local row = RowAt(index)
            local name, texture = "Cooldowns", QUESTION_MARK
            if tracked[index] then name, texture = NS.Describe(tracked[index]) end
            row.icon:SetTexture(texture)
            row.bar:SetMinMaxValues(0, 1)
            row.bar:SetValue(1)
            row.spark:SetAlpha(0)
            row.countText:SetText("")
            row.nameText:SetText(name)
            row.timeText:SetText("")
            StackAt(row, index - 1, true)
            Style.ShowNow(row)
        end
        HideBeyond(count)
    end

    local function ShowBar(index, entry, slot, cooldownEvent, instant)
        local row = RowAt(index)
        local shown, duration, charges
        if entry.kind == "spell" then
            shown, duration, charges = SpellCooldown(entry, cooldownEvent)
        else
            shown, duration = ItemCooldown(entry)
        end
        local secret = IsSecret(shown)

        if not (secret or shown == true) then
            -- Fading out keeps its place, so the bars beyond don't slide onto it.
            if not row:IsShown() then return slot end
            StackAt(row, slot)
            Style.FadeOut(row)
            return slot + 1
        end

        StackAt(row, slot, instant or not row:IsShown())
        local name, texture = NS.Describe(entry)
        row.icon:SetTexture(texture)
        row.nameText:SetText(name)
        if duration and pcall(row.bar.SetTimerDuration, row.bar, duration, IMMEDIATE, REMAINING) then
            row.spark:SetAlpha(1)
        else
            row.bar:SetMinMaxValues(0, 1)
            row.bar:SetValue(0)
            row.spark:SetAlpha(0)
        end
        ShowTime(row.timeText, duration)
        if charges == nil or not pcall(row.countText.SetText, row.countText, charges) then
            row.countText:SetText("")
        end
        if secret then
            -- Never looked at: the game shows or hides it.
            Style.ShowNow(row)
            row:SetAlphaFromBoolean(shown, 1, 0)
        elseif instant then
            Style.ShowNow(row)
        else
            Style.FadeIn(row)
        end
        return slot + 1
    end

    -- `cooldownEvent`: SPELL_UPDATE_COOLDOWN just fired, isOnGCD can be read.
    -- `instant`: a setting changed, bars appear at once.
    function Update(cooldownEvent, instant)
        local db = NS.db
        local tracked = db.tracked
        if #tracked == 0 and not db.unlocked then
            for _, row in pairs(rows) do Style.HideNow(row) end
            holder:Hide()
            Polling(false)
            return
        end
        holder:Show()
        if db.unlocked then
            ShowPlacing()
            Polling(true)
            return
        end

        local slot = 0
        for index, entry in ipairs(tracked) do
            if NS.ShowsCooldown(entry) then
                slot = ShowBar(index, entry, slot, cooldownEvent, instant)
            elseif rows[index] then
                Style.HideNow(rows[index])   -- its buff bar is the game's, above
            end
        end
        HideBeyond(#tracked)
        Durations.Follow(slot)

        -- Polled only while a bar is up: an ending fires no event, a start does.
        local any = false
        for _, row in pairs(rows) do
            if row:IsShown() then any = true; break end
        end
        Polling(any)
    end
    NS.Update = Update

    function Refresh()
        local db = NS.db
        holder:SetFrameStrata(db.frameStrata)
        holder:SetSize(db.barWidth, db.barHeight)
        Core.Snap.Put(holder, db)

        -- Settings changed: redrawn and replaced at once.
        for _, row in pairs(rows) do
            LayOutRow(row)
            Style.HideNow(row)
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

    function Polling(on)
        if on == polling then return end
        polling = on
        holder:SetScript("OnUpdate", on and Poll or nil)
    end

    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES",
                             "BAG_UPDATE_COOLDOWN", "GET_ITEM_INFO_RECEIVED", "SPELLS_CHANGED" }) do
        NS:RegisterEvent(event)
    end
    NS:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            -- The frames are placed now: a guessed spot worked out again, never the player's.
            if NS.db.autoPlaced and fromGuess then Place() end
            Refresh()
            Core.RefreshOptions()
            return
        end
        if event == "GET_ITEM_INFO_RECEIVED" then Core.RefreshOptions() end
        if event == "SPELLS_CHANGED" then Durations.Refresh() end
        Update(event == "SPELL_UPDATE_COOLDOWN")
    end)

    -- Snapped by the whole stack on screen, not just the first bar.
    SavePlace = Core.Snap.Piece(holder, NS, {
        name = "Cooldowns", id = "cooldowns",
        parts = function()
            local list = {}
            for _, row in pairs(rows) do list[#list + 1] = row end
            return list
        end,
    }, Refresh)
    holder:EnableMouse(false)   -- dragged by its rows: the scripts Piece set catch no clicks

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
        for line, font in pairs(restore[tooltip] or {}) do line:SetFontObject(font) end
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

    -- A field of the tooltip data, which may be a secret table (each field comes back secret).
    local function Field(data, key)
        if type(data) ~= "table" and not issecrettable(data) then return nil end
        local ok, value = pcall(function() return data[key] end)
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
        if not Cooldowns.db.showTooltipIDs then return end
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
