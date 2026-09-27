-- MODULE: Cooldowns  (DogsForeverUI.Cooldowns, settings section "cooldowns")
--
-- The cooldown manager: spells and items the player adds by ID (its own tab
-- in Settings; hover a spell or an item to see its ID - TooltipIDs.lua). Each
-- is a bar with its icon on the left, its name and the time left, on screen
-- only while it cools down, draining to empty. The bars stack UP from their
-- spot (or down: the growDirection setting) in the order they were added, and
-- close up as they end.
--
-- A spell's cooldown is asked of the rank you know (NS.CooldownID), so an ID
-- added for any rank works. A spell can also track its buff's DURATION: while
-- the buff is on you, a bar of the same look counts it down. A spell with no
-- cooldown of its own always does; one with a cooldown tracks its Cooldown
-- (the default), its Duration, or Both - a dropdown on its row. Duration bars
-- are the game's (Durations.lua) and stack on top of the cooldown bars.
--
-- By default the first bar sits in line with the castbar - its top level with
-- the castbar's top - and over the player frame's health bar: its left edge,
-- its width. More bars stack up from there. Both follow the castbar and the
-- player frame when those move; dragged, the bars stay where they are put.
--
-- NO "READY" / MISSING-BUFF REMINDERS. A mode that showed an icon while a
-- spell was ready and its buff was not on you existed for a few hours on
-- 2026-09-27 and was taken out: whether a buff is on you cannot be read by an
-- addon in combat on this client (every aura query needs aura access a
-- tainted caller does not get there, and GetPlayerAuraBySpellID answers
-- nothing for an aura it keeps secret), so the icons came up in combat with
-- the buff still on. Nothing that cannot work properly with the API ships.
--
-- The game's own Cooldown Manager is in this client but switched off, and it
-- has nothing to show for these classes and no way to add a spell to it.
--
-- COOLDOWNS ARE SECRET ON THIS CLIENT. In combat the start and length of a
-- spell's cooldown cannot be read, compared or worked with. A GCD bar this
-- addon once drew died of exactly that: it decided whether to show on a
-- duration object's IsActive(), which turned secret in combat and threw every
-- frame. So nothing here is decided on a number:
--
--   * whether a spell is cooling down is SpellCooldownInfo.isActive, and
--     whether that is only the global cooldown is .isOnGCD - both documented
--     NeverSecret, fields Blizzard marks for exactly this. isOnGCD is only to
--     be trusted when SPELL_UPDATE_COOLDOWN fires, so it is read then and
--     kept. Should isActive ever arrive secret after all, it is never looked
--     at: the bar keeps its place and the game sets its alpha from the
--     boolean (SetAlphaFromBoolean).
--   * a bar runs from C_Spell.GetSpellCooldownDuration - a duration object
--     handed to the status bar (SetTimerDuration), the global cooldown left
--     out - and its time is formatted by the game (FormatRemainingDuration),
--     rounded UP to the whole second as the game's own cooldown numbers on
--     the action buttons are (it was truncated at first, and read a second
--     behind them).
--
-- Items are not secret (C_Item.GetItemCooldown has no secrecy on it), so their
-- numbers are read - and checked first; an item whose numbers ever are secret
-- shows nothing rather than something wrong.
--
-- The list survives "Reset everything": it is the player's own list, not a
-- setting (NS.keep).

DogsForeverUI.Cooldowns = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.Cooldowns
    local Style = DogsForeverUI.Style
    local IsSecret = issecretvalue or function() return false end

    local Place, Refresh, Update, Lock, Unlock

    NS.key = "cooldowns"
    NS.title = "Cooldowns"

    NS.defaults = {
        enabled = true,
        unlocked = false,
        barWidth = 150,          -- the whole row, icon included: the player frame's width
        barHeight = 20,          -- the castbar's height
        growDirection = "up",    -- which way more bars stack from the first
        frameStrata = "MEDIUM",
        showTooltipIDs = true,   -- TooltipIDs.lua
        tracked = {},            -- { kind, id, track, buff }, in order (see Durations.lua)
    }
    NS.placement = { barLeft = true, barTop = true, autoPlaced = true }
    NS.keep = { tracked = true }

    NS.KINDS = { spell = "Spell", item = "Item" }
    NS.GROW = {
        { value = "up",   label = "Upward" },
        { value = "down", label = "Downward" },
    }
    local VALID_GROW = { up = true, down = true }
    -- Widths earlier versions had as their default and saved into the
    -- player's settings: 200 (the first), then 130 (the castbars', briefly).
    -- Either is taken as "the default", which is the player frame's.
    local OLD_DEFAULT_WIDTHS = { [200] = true, [130] = true }

    -- Daylight between two bars, as between the castbar group's: every border
    -- is drawn outside its bar, so a gap has to leave room for two.
    local GAP = 6 + 2 * Style.BORDER_INSET
    NS.GAP = GAP   -- the buff bars' too (Durations.lua)
    -- How often everything looks again - a cooldown ends with no event.
    local POLL = 0.1
    -- An item's cooldown this short is the global cooldown, not the item's.
    local MIN_ITEM_COOLDOWN = 1.5
    local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
    local COLOR = Style.GOLD

    local function Call(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, a, b, c, d, e = pcall(fn, ...)
        if ok then return a, b, c, d, e end
    end

    local function Api(namespace, name)
        local t = _G[namespace]
        return type(t) == "table" and t[name] or nil
    end

    local function Plain(value)
        return not IsSecret(value)
    end

    ---------------------------------------------------------------------------
    -- What an ID is: whether the game knows it, and its name and icon.
    ---------------------------------------------------------------------------

    function NS.Exists(kind, id)
        if kind == "spell" then
            if Call(Api("C_Spell", "DoesSpellExist"), id) then return true end
            return type(Call(Api("C_Spell", "GetSpellName"), id)) == "string"
        elseif kind == "item" then
            return Call(Api("C_Item", "GetItemInfoInstant"), id) ~= nil
        end
        return false
    end

    -- An item's name may not be loaded yet: the game is asked for it and
    -- GET_ITEM_INFO_RECEIVED redraws when it comes.
    function NS.Describe(entry)
        local name, icon
        if entry.kind == "spell" then
            name = Call(Api("C_Spell", "GetSpellName"), entry.id)
            icon = Call(Api("C_Spell", "GetSpellTexture"), entry.id)
        else
            name = Call(Api("C_Item", "GetItemNameByID"), entry.id)
            icon = Call(Api("C_Item", "GetItemIconByID"), entry.id)
            if not icon then
                icon = select(5, Call(Api("C_Item", "GetItemInfoInstant"), entry.id))
            end
            if not name then Call(Api("C_Item", "RequestLoadItemDataByID"), entry.id) end
        end
        if type(name) ~= "string" or IsSecret(name) then
            name = NS.KINDS[entry.kind] .. " " .. entry.id
        end
        return name, icon or QUESTION_MARK
    end

    ---------------------------------------------------------------------------
    -- The list, as the options change it.
    ---------------------------------------------------------------------------

    local function Valid(entry)
        return type(entry) == "table" and NS.KINDS[entry.kind] ~= nil
            and type(entry.id) == "number" and entry.id > 0 and entry.id % 1 == 0
    end

    -- Answers whether it was added, and a line to say so.
    function NS.Add(kind, id)
        id = tonumber(id)
        if not NS.KINDS[kind] then return false, "Unknown kind." end
        if not id or id <= 0 or id % 1 ~= 0 then
            return false, "Type a spell or item ID: a whole number."
        end
        if not NS.Exists(kind, id) then
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

    -- For a spell with a cooldown: what its row tracks. "cooldown" (the
    -- default, stored as nothing), "buff" (its buff's duration) or "both".
    -- A spell with no cooldown has no choice: it tracks its duration.
    NS.TRACK = {
        { value = "cooldown", label = "Cooldown" },
        { value = "buff",     label = "Duration" },
        { value = "both",     label = "Both" },
    }
    local SAVED_TRACK = { buff = true, both = true }

    function NS.SetTrack(index, track)
        local entry = NS.db.tracked[index]
        if not entry then return end
        entry.track = SAVED_TRACK[track] and track or nil
        Refresh()
    end

    function NS.Remove(index)
        if not NS.db.tracked[index] then return end
        table.remove(NS.db.tracked, index)
        Refresh()
    end

    ---------------------------------------------------------------------------
    -- Reading a cooldown: whether it is cooling down for real (true, false,
    -- or a secret that is never looked at), the duration for its bar, and a
    -- spell's charges.
    ---------------------------------------------------------------------------

    -- Whether a spell is only on the global cooldown, as read when
    -- SPELL_UPDATE_COOLDOWN last fired - the only time the field is to be
    -- trusted.
    local onGCD = setmetatable({}, { __mode = "k" })
    -- An item's duration object, reused.
    local itemDurations = setmetatable({}, { __mode = "k" })

    -- The rank to ask about. Ranks of a spell share one cooldown, but the game
    -- may answer nothing for a rank you do not know - one added by an old ID
    -- after a higher rank was trained. So: the ID as added while it is in your
    -- spellbook, otherwise the rank the game knows by the spell's name.
    -- Worked out once and kept until the spellbook changes.
    local cooldownIDs = setmetatable({}, { __mode = "k" })

    function NS.CooldownID(entry)
        local id = cooldownIDs[entry]
        if id then return id end
        id = entry.id
        local inBook = Api("C_SpellBook", "IsSpellInSpellBook")
        if not (inBook and Call(inBook, id) == true) then
            local name = Call(Api("C_Spell", "GetSpellName"), id)
            if Plain(name) and type(name) == "string" then
                local info = Call(Api("C_Spell", "GetSpellInfo"), name)
                if type(info) == "table" and Plain(info.spellID) and type(info.spellID) == "number" then
                    id = info.spellID
                end
            end
        end
        cooldownIDs[entry] = id
        return id
    end

    local function ForgetRanks()
        for entry in pairs(cooldownIDs) do cooldownIDs[entry] = nil end
    end

    local function SpellCooldown(entry, cooldownEvent)
        local id = NS.CooldownID(entry)
        local charges = Call(Api("C_Spell", "GetSpellCharges"), id)
        if type(charges) == "table" and Plain(charges.maxCharges)
           and type(charges.maxCharges) == "number" and charges.maxCharges > 1 then
            -- A spell with charges: the bar is the next charge coming back.
            return charges.isActive, Call(Api("C_Spell", "GetSpellChargeDuration"), id),
                charges.currentCharges
        end

        local info = Call(Api("C_Spell", "GetSpellCooldown"), id)
        if type(info) ~= "table" then return false end
        local active = info.isActive
        if not Plain(active) then
            return active, Call(Api("C_Spell", "GetSpellCooldownDuration"), id, true)
        end
        if not active then
            onGCD[entry] = nil
            return false
        end
        if cooldownEvent or onGCD[entry] == nil then
            local gcd = info.isOnGCD
            onGCD[entry] = Plain(gcd) and gcd == true
        end
        if onGCD[entry] then return false end
        return true, Call(Api("C_Spell", "GetSpellCooldownDuration"), id, true)
    end

    local function ItemCooldown(entry)
        local start, length, enabled = Call(Api("C_Item", "GetItemCooldown"), entry.id)
        if not (Plain(start) and Plain(length) and Plain(enabled)) then return false end
        if type(start) ~= "number" or type(length) ~= "number" then return false end
        if enabled == false or enabled == 0 then return false end
        if start <= 0 or length <= MIN_ITEM_COOLDOWN or start + length <= GetTime() then
            return false
        end

        local duration = itemDurations[entry]
        if not duration then
            duration = Call(Api("C_DurationUtil", "CreateDuration"))
            if not duration then return false end
            itemDurations[entry] = duration
        end
        if not pcall(duration.SetTimeFromStart, duration, start, length) then return false end
        return true, duration
    end

    ---------------------------------------------------------------------------
    -- The time left, formatted by the game: "45s", "1m 30s", "2h 5m". Blizzard's
    -- own aura timer set-up (Blizzard_AuraContainerShared) with two units
    -- instead of one. Two of them, each matching the game's own numbers for
    -- the same thing, which round differently:
    --
    --   * cooldowns round UP, as the action buttons' cooldown numbers do
    --     (truncated, they read a second behind them);
    --   * buffs TRUNCATE, as the game's own buff timers do (Blizzard's aura
    --     formatter; rounded up, the buff bars read a second ahead of them).
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
    NS.auraFormatter = MakeFormatter("Truncate")   -- the buff bars' (Durations.lua)

    local function ShowTime(label, duration)
        if type(duration) ~= "table" and type(duration) ~= "userdata" then
            label:SetText("")
            return
        end
        -- The text is secret in combat: handed on, never compared - not even
        -- with nil - and every hand-over guarded, so a refusal is one blank
        -- label, not an error ten times a second.
        if formatter then
            local ok, text = pcall(duration.FormatRemainingDuration, duration, formatter)
            if ok and (IsSecret(text) or text ~= nil) and pcall(label.SetText, label, text) then
                return
            end
        end
        local ok, left = pcall(duration.GetRemainingDuration, duration)
        if ok and (IsSecret(left) or type(left) == "number")
           and pcall(label.SetFormattedText, label, "%.0f", left) then
            return
        end
        label:SetText("")
    end

    ---------------------------------------------------------------------------
    -- The bars: one per tracked entry, made as needed and kept.
    ---------------------------------------------------------------------------

    local function EnumValue(group, key, fallback)
        local enum = type(Enum) == "table" and Enum[group]
        return type(enum) == "table" and enum[key] or fallback
    end
    local IMMEDIATE = EnumValue("StatusBarInterpolation", "Immediate", 0)
    local REMAINING = EnumValue("StatusBarTimerDirection", "RemainingTime", 1)

    -- The anchor: the first bar's place. Bars go up (or down) from it. It is
    -- what is dragged while unlocked.
    local holder = CreateFrame("Frame", "DogsForeverUICooldowns", UIParent)
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    holder:Hide()
    NS.holder = holder

    local rows = {}
    NS.rows = rows

    local function OnePixel(frame)
        if PixelUtil and PixelUtil.GetNearestPixelSize then
            local ok, px = pcall(PixelUtil.GetNearestPixelSize, 1, frame:GetEffectiveScale(), 1)
            if ok and type(px) == "number" and px > 0 then return px end
        end
        return 1
    end

    local function StartDrag(_, button)
        if button == "LeftButton" and NS.db.unlocked then holder:StartMoving() end
    end

    local function EndDrag(_, button)
        if DogsForeverUI.RightClickLock(NS, button) then return end
        if button ~= "LeftButton" or not NS.db.unlocked then return end
        holder:StopMovingOrSizing()
        local db = NS.db
        db.autoPlaced = false
        db.barLeft = holder:GetLeft()
        db.barTop = -1 * (GetScreenHeight() - holder:GetTop())
        Refresh()
        DogsForeverUI.RefreshOptions()
    end

    local function NewRow()
        local row = CreateFrame("Frame", nil, holder)
        row:SetFrameLevel(holder:GetFrameLevel() + 2)
        row:Hide()

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints(row)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.divider = row:CreateTexture(nil, "ARTWORK")

        local bar = CreateFrame("StatusBar", nil, row)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        row.bar = bar
        row.spark = Style.AddSpark(bar)
        row.nameText = bar:CreateFontString(nil, "OVERLAY")
        row.timeText = bar:CreateFontString(nil, "OVERLAY")
        -- A spell's charges, in the icon's corner.
        row.countText = row:CreateFontString(nil, "OVERLAY")

        row.border = Style.AddBorder(row)

        row:SetScript("OnMouseDown", StartDrag)
        row:SetScript("OnMouseUp", EndDrag)
        return row
    end

    local LayOutRow   -- below

    local function RowAt(index)
        if not rows[index] then
            rows[index] = NewRow()
            LayOutRow(rows[index])
        end
        return rows[index]
    end

    local function HideBeyond(last)
        for index, row in pairs(rows) do
            if index > last then Style.HideNow(row) end
        end
    end

    -- Size, fonts and paint: everything that follows a setting. `parts` holds
    -- the pieces - icon, divider, bar, spark, nameText, timeText, countText,
    -- bg - which on a cooldown bar are the row's own fields and on a buff bar
    -- (Durations.lua) are kept beside the game's button. A buff bar also
    -- brings `paint(bar)`, its own fill, and `timeRoom`, the space kept
    -- clear for its time (see Durations.lua for why).
    function NS.LayOutParts(frame, parts)
        local db = NS.db
        local width, height = db.barWidth, db.barHeight
        local px = OnePixel(frame)
        frame:SetSize(width, height)
        -- The pieces; anchors to the bar's own frame go to `frame`, never to
        -- this table (on a buff bar the two are different things).
        local row = parts

        row.icon:ClearAllPoints()
        row.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        row.icon:SetSize(height, height)

        row.divider:ClearAllPoints()
        row.divider:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 0, 0)
        row.divider:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 0, 0)
        row.divider:SetWidth(px)
        local d = Style.DIVIDER_COLOR
        row.divider:SetColorTexture(d[1], d[2], d[3], d[4] or 1)

        -- One anchor and a size of its own, so its height is there to be read
        -- for the text and the spark straight away.
        local bar = row.bar
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", row.divider, "TOPRIGHT", 0, 0)
        bar:SetSize(math.max(1, width - height - px), height)

        if row.paint then row.paint(bar) else Style.Paint(bar, COLOR) end
        Style.SetBackground(row.bg, db.unlocked)

        for _, label in ipairs({ row.nameText, row.timeText }) do
            label:ClearAllPoints()
            Style.SingleLine(label)
            Style.SetFont(bar, label)
        end
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetPoint("LEFT", bar, "LEFT", 4, 0)
        if row.timeRoom then
            row.nameText:SetPoint("RIGHT", bar, "RIGHT", -row.timeRoom, 0)
        else
            row.nameText:SetPoint("RIGHT", row.timeText, "LEFT", -6, 0)
        end
        row.timeText:SetJustifyH("RIGHT")
        row.timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)

        row.countText:ClearAllPoints()
        Style.SingleLine(row.countText)
        Style.SetFont(bar, row.countText)
        row.countText:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", -1, 1)

        Style.PinSpark(row.spark, bar)
    end

    function LayOutRow(row)
        NS.LayOutParts(row, row)
        row:EnableMouse(NS.db.unlocked and true or false)
    end

    local function GrowsDown()
        return NS.db.growDirection == "down"
    end

    ---------------------------------------------------------------------------
    -- SLIDING. When a bar ends and the ones beyond it close up, they glide to
    -- their new place rather than jump: each eases towards where it should
    -- be, fast at first and slowing as it arrives (SLIDE_RATE: most of the
    -- way in about a quarter of a second, whatever the frame rate), and a new
    -- place set on the way simply becomes the new target. A frame that is not
    -- on screen yet, or a change of which way the bars grow, is placed at
    -- once - there is nothing to slide from. Only the addon's own frames move
    -- here, by anchor offsets, so it is the same in combat.
    ---------------------------------------------------------------------------

    local SLIDE_RATE = 12            -- per second: 1 - e^(-rate * t) of the way
    local SNAP = 0.5                 -- close enough to stop, in UI units
    local sliding = setmetatable({}, { __mode = "k" })   -- frame -> { point, y, target }
    local slider = CreateFrame("Frame")
    slider:Hide()

    local function PutAt(frame, point, y)
        frame:ClearAllPoints()
        frame:SetPoint(point, holder, point, 0, y)
    end

    slider:SetScript("OnUpdate", function(self, elapsed)
        local step = 1 - math.exp(-SLIDE_RATE * (elapsed or 0))
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
        if not moving then self:Hide() end
    end)

    -- Put `frame` at `y` off the holder's `point` (TOPLEFT or BOTTOMLEFT),
    -- gliding there unless `instant`.
    function NS.SlideTo(frame, point, y, instant)
        local s = sliding[frame]
        if instant or not s or s.point ~= point then
            sliding[frame] = { point = point, y = y, target = y }
            PutAt(frame, point, y)
            return
        end
        if s.target == y then return end
        s.target = y
        slider:Show()
    end

    -- Bars from the holder up (or down). A bar not yet on screen takes its
    -- place at once.
    local function BarSlot(row, slot, instant)
        local db = NS.db
        local offset = (slot - 1) * (db.barHeight + GAP)
        local instantly = instant or not row:IsShown()
        if GrowsDown() then
            NS.SlideTo(row, "TOPLEFT", -offset, instantly)
        else
            NS.SlideTo(row, "BOTTOMLEFT", offset, instantly)
        end
    end

    ---------------------------------------------------------------------------
    -- Placing.
    ---------------------------------------------------------------------------

    -- The addon's own spot: x from the player frame (its left edge, the
    -- health bar's), y from the castbar (its top edge) - both as their
    -- modules save them, TOPLEFT offsets from the top left of the screen.
    local function DefaultSpot()
        local fdb = DogsForeverUI.Frames and DogsForeverUI.Frames.db
        local cdb = DogsForeverUI.Castbar and DogsForeverUI.Castbar.db
        local left, top = fdb and fdb.playerLeft, cdb and cdb.barTop
        if type(left) == "number" and type(top) == "number" then return left, top end
    end

    -- First run, a reset, or never dragged: at DefaultSpot, or centred near
    -- the top of the screen if the frames have no place yet.
    function Place()
        local db = NS.db
        local left, top = DefaultSpot()
        if not left then
            local screenWidth = GetScreenWidth() or 0
            left = screenWidth > 0 and (screenWidth - db.barWidth) / 2 or 0
            top = -200
        end
        db.barLeft, db.barTop = left, top
        db.autoPlaced = true
    end

    local function Anchor()
        local db = NS.db
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.barLeft, db.barTop)
    end

    -- The castbar or the player frame moved while the bars still go with
    -- them: follow. Asked on every update, the poll that watches the
    -- cooldowns and every event.
    local function Follow()
        local db = NS.db
        if not db.autoPlaced then return end
        local left, top = DefaultSpot()
        if left and (left ~= db.barLeft or top ~= db.barTop) then
            db.barLeft, db.barTop = left, top
            Anchor()
        end
    end

    function NS.Normalise(db)
        -- Anything malformed or twice in the list goes; the order is kept. What
        -- a spell tracks is kept ("buff" or "both"; the cooldown is the
        -- default and stored as nothing); anything else an older version saved
        -- on an entry is dropped.
        local seen, clean = {}, {}
        if type(db.tracked) ~= "table" then db.tracked = {} end
        for _, entry in ipairs(db.tracked) do
            if Valid(entry) then
                local key = entry.kind .. ":" .. entry.id
                if not seen[key] then
                    seen[key] = true
                    clean[#clean + 1] = { kind = entry.kind, id = entry.id,
                        track = SAVED_TRACK[entry.track] and entry.track or nil,
                        -- learned: does it put a buff on you (Durations.lua)
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
    -- Drawing.
    ---------------------------------------------------------------------------

    local function Appear(frame, instant)
        if instant then Style.ShowNow(frame) else Style.FadeIn(frame) end
    end

    -- While unlocked: every bar, full, so there is something to drag and the
    -- space they take shows. The first says what it is; with nothing tracked,
    -- one bar stands in.
    local function ShowPlacing()
        local tracked = NS.db.tracked
        local count = math.max(1, #tracked)
        for index = 1, count do
            local row = RowAt(index)
            local entry = tracked[index]
            local name, texture = "Cooldowns", QUESTION_MARK
            if entry then name, texture = NS.Describe(entry) end
            row.icon:SetTexture(texture)
            row.bar:SetMinMaxValues(0, 1)
            row.bar:SetValue(1)
            row.spark:SetAlpha(0)
            row.countText:SetText("")
            row.nameText:SetText(index == 1 and "Cooldowns" or name)
            row.timeText:SetText(index == 1 and Style.PLACEMENT_LABEL or "")
            BarSlot(row, index, true)
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
            -- Fading out keeps its place until it is gone, so the bars beyond
            -- it do not slide onto it.
            if row:IsShown() then
                BarSlot(row, slot + 1)
                Style.FadeOut(row)
                return slot + 1
            end
            return slot
        end

        slot = slot + 1
        BarSlot(row, slot, instant)
        local name, texture = NS.Describe(entry)
        row.icon:SetTexture(texture)
        row.nameText:SetText(name)
        if duration and type(row.bar.SetTimerDuration) == "function"
           and pcall(row.bar.SetTimerDuration, row.bar, duration, IMMEDIATE, REMAINING) then
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
        else
            Appear(row, instant)
        end
        return slot
    end

    -- What every bar shows now. `cooldownEvent`: SPELL_UPDATE_COOLDOWN just
    -- fired, so whether a spell is only on the global cooldown can be read.
    -- `instant`: a setting changed, so bars appear at once rather than fade.
    function Update(cooldownEvent, instant)
        local db = NS.db
        Follow()
        local tracked = db.tracked
        if not db.enabled or (#tracked == 0 and not db.unlocked) then
            for _, row in pairs(rows) do Style.HideNow(row) end
            holder:Hide()
            return
        end
        holder:Show()
        if db.unlocked then ShowPlacing(); return end

        local slot = 0
        for index, entry in ipairs(tracked) do
            if NS.ShowsCooldown(entry) then
                slot = ShowBar(index, entry, slot, cooldownEvent, instant)
            elseif rows[index] then
                -- Only its buff: that bar is the game's, in the stack above.
                Style.HideNow(rows[index])
            end
        end
        HideBeyond(#tracked)
        -- The buff bars ride on top of however many cooldown bars there are.
        NS.Durations.Follow(slot)
    end
    NS.Update = Update

    function Refresh()
        local db = NS.db
        if db.autoPlaced then Place() end
        holder:SetFrameStrata(db.frameStrata or "MEDIUM")
        holder:SetSize(db.barWidth, db.barHeight)
        Anchor()
        -- Cleared so the client's layout cache never wins over the position
        -- saved here.
        holder:SetUserPlaced(false)

        -- Settings changed: whatever was on screen is redrawn at once, and
        -- anything that should no longer be there goes at once too.
        for _, row in pairs(rows) do
            LayOutRow(row)
            Style.HideNow(row)
        end
        ForgetRanks()
        NS.Durations.Refresh()
        Update(true, true)
    end

    -- Polled, because a cooldown that ends fires no event.
    local elapsedSince = 0
    holder:SetScript("OnUpdate", function(_, elapsed)
        elapsedSince = elapsedSince + elapsed
        if elapsedSince < POLL then return end
        elapsedSince = 0
        Update(false)
    end)

    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "SPELL_UPDATE_COOLDOWN",
                             "SPELL_UPDATE_CHARGES", "BAG_UPDATE_COOLDOWN",
                             "GET_ITEM_INFO_RECEIVED", "SPELLS_CHANGED" }) do
        pcall(NS.RegisterEvent, NS, event)
    end
    NS:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            -- UIParent is unscaled at ADDON_LOADED; only the addon's own
            -- placement is worked out again, never one the player chose.
            if NS.db.autoPlaced then Place() end
            Refresh()
            DogsForeverUI.RefreshOptions()
            return
        end
        if event == "GET_ITEM_INFO_RECEIVED" then DogsForeverUI.RefreshOptions() end
        -- A spell learned: its ranks, and whether it has a cooldown, may be new.
        if event == "SPELLS_CHANGED" then
            ForgetRanks()
            NS.Durations.Refresh()
        end
        Update(event == "SPELL_UPDATE_COOLDOWN")
    end)

    function Unlock()
        NS.db.unlocked = true
        Refresh()
    end

    function Lock()
        NS.db.unlocked = false
        holder:StopMovingOrSizing()
        Refresh()
    end

    NS.Init = Refresh
    NS.Refresh = Refresh
    NS.Lock = Lock
    NS.Unlock = Unlock

    DogsForeverUI:RegisterModule(NS)
end
