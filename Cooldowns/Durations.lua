-- The cooldown manager's BUFF bars: for a spell with no cooldown of its own
-- (Seal of Command, Battle Shout...), a bar that counts its buff down while it
-- is on you - the same look as a cooldown bar: icon, name, time, draining.
--
-- WHY THIS WORKS IN COMBAT. An addon cannot read a buff in combat on this
-- client (see the note in Cooldowns.lua on the ready icons that were taken
-- out). But the client makes an aura container for add-ons to use,
-- CustomAuraContainerTemplate (Blizzard_AuraContainer): the GAME fills it from
-- the unit's auras - secret or not - and runs each button itself: its icon,
-- its duration bar (SetDurationBar), its time (SetDurationText), its name
-- (SetSpellName), its tooltip. The addon only says which unit (you), which
-- auras ("HELPFUL", and a list of spell IDs - candidateFilters.includeSpellIDs,
-- which Blizzard permits for helpful auras on a friendly unit), and how each
-- button looks, which can only be set up as the game makes it
-- (initializeFrame): after that the game denies addon code the button while
-- auras are secret. Nothing is ever read, so nothing can go wrong in combat.
--
-- WHICH SPELLS. Two static questions, asked when the list or the spellbook
-- changes, never in combat:
--
--   * does it have a cooldown? A base cooldown above 0 (GetSpellBaseCooldown,
--     static spell data, plain) or charges;
--   * does it put a buff on you? No API says so beforehand: "helpful" and
--     "self buff" were tried and were wrong both ways (Consecration and Will
--     of the Forsaken count as helpful and leave no buff). So it is LEARNED,
--     the same way for every spell: after you cast a tracked spell, half a
--     second later, is its buff (any rank) on you? Seen: it has one
--     (entry.buff = true). Not there while auras can be read: it has none
--     (false). In combat auras are secret to add-ons and a missing buff
--     proves nothing, so only a buff actually seen counts then. A buff
--     already on you when the list refreshes (after a reload) is noticed too.
--     Kept on the entry, so it is saved with the list.
--
-- A cooldown and a buff seen: its row has a dropdown - Cooldown (the default),
-- Duration, Both. Otherwise it tracks the one thing it can, and the row says
-- which: a spell with a cooldown its cooldown (until a buff is seen); one with
-- none its duration - or nothing, once it is seen to leave no buff.
--
-- EVERY RANK. Each rank of a spell is its own ID, and the buff on you carries
-- the ID of the rank you cast. So the filter holds every spell in your
-- spellbook with the tracked spell's name (C_SpellBook, read out of combat,
-- again on SPELLS_CHANGED), plus the highest rank the game knows by that name
-- (C_Spell.GetSpellInfo), plus the ID as added.
--
-- WHERE. In a stack of their own directly on top of the cooldown bars, growing
-- the same way: the game will not say how many buff bars it shows (the
-- container's size is secret), so the two cannot be merged into one list, but
-- the addon knows how many cooldown bars are up and moves the buff stack's
-- anchor with them. Within the stack the game orders the bars, not the list.
--
-- A size change reaches bars the game has already made only while auras are
-- not secret (out of combat); a bar made later takes the new size itself.
--
-- A BUFF THAT DOES NOT RUN OUT (a stance, an aura) shows a FULL bar. The game
-- hands such a buff's bar a zero-length timer, and whether a buff has an end
-- is not something the addon can ask. So the bar is built the other way
-- round: the gold (with its sheen) is the bar's background, the part the
-- game fills is the dark, filling from the right with the time ELAPSED. A
-- timed buff drains leftward exactly like a cooldown bar; a zero-length timer
-- has no elapsed time, so the gold stays whole. (Filled with the time
-- remaining, as at first, it came out empty.) No spark: its place would be
-- the gold's end, which a buff that does not run out has at the far right.
--
-- THE NAME keeps clear of the time by a fixed space rather than by being
-- anchored to the time's text: the game marks the time's text secret once it
-- runs it, and a name anchored to it did not show.

local Durations = {}
DogsForeverUI.Cooldowns.Durations = Durations

do -- private scope
    local NS = DogsForeverUI.Cooldowns
    local Style = DogsForeverUI.Style
    local IsSecret = issecretvalue or function() return false end

    local GROUP = "tracked"
    local MAX_BARS = 20
    local GAP = 6 + 2 * Style.BORDER_INSET
    local COLOR = Style.GOLD
    local DARK = { 0.05, 0.05, 0.05, 1 }   -- the elapsed part: opaque, over the gold
    local TIME_ROOM = 40                   -- kept clear for "59 m" and the like
    local SHEEN, SHADE = 0.22, 0.25        -- the fill's sheen, as Style.MakeSheen draws it

    local function Call(object, method, ...)
        if object == nil then return nil end
        local fn = object[method]
        if type(fn) ~= "function" then return nil end
        local ok, a, b = pcall(fn, object, ...)
        if ok then return a, b end
    end

    local function Global(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, a, b = pcall(fn, ...)
        if ok then return a, b end
    end

    local function Api(namespace, name)
        local t = _G[namespace]
        return type(t) == "table" and t[name] or nil
    end

    local function EnumValue(group, key, fallback)
        local enum = type(Enum) == "table" and Enum[group]
        return type(enum) == "table" and enum[key] or fallback
    end
    local IMMEDIATE = EnumValue("StatusBarInterpolation", "Immediate", 0)
    local ELAPSED = EnumValue("StatusBarTimerDirection", "ElapsedTime", 0)

    ---------------------------------------------------------------------------
    -- Which spells track a buff, and every ID that buff can carry.
    ---------------------------------------------------------------------------

    local hasCooldown = setmetatable({}, { __mode = "k" })  -- entry -> bool, cached

    local function NoCooldown(id)
        local ms = Global(_G.GetSpellBaseCooldown, id)
        if IsSecret(ms) or type(ms) ~= "number" or ms > 0 then return false end
        local charges = Global(Api("C_Spell", "GetSpellCharges"), id)
        if type(charges) == "table" and not IsSecret(charges.maxCharges)
           and type(charges.maxCharges) == "number" and charges.maxCharges > 1 then
            return false
        end
        return true
    end

    -- Whether the entry has a cooldown to show at all: an item always, a spell
    -- unless its base cooldown is 0 and it has no charges.
    function NS.HasCooldown(entry)
        if entry.kind ~= "spell" then return true end
        local known = hasCooldown[entry]
        if known == nil then
            known = not NoCooldown(entry.id)
            hasCooldown[entry] = known
        end
        return known
    end

    -- Whether the spell has been seen to put a buff on you (see WHICH SPELLS).
    function NS.CanHaveBuff(entry)
        return entry.kind == "spell" and entry.buff == true
    end

    -- Whether its row offers the choice: it has a cooldown and a buff seen.
    function NS.HasChoice(entry)
        return NS.HasCooldown(entry) and NS.CanHaveBuff(entry)
    end

    -- What it tracks: "cooldown", "buff" or "both" - its own choice when it
    -- has one (entry.track; nil is the cooldown), otherwise the one thing it
    -- can: its cooldown; with none, its buff - or nil, nothing, once it has
    -- been seen to leave no buff.
    function NS.TrackOf(entry)
        if entry.kind ~= "spell" then return "cooldown" end
        if NS.HasChoice(entry) then return entry.track or "cooldown" end
        if NS.HasCooldown(entry) then return "cooldown" end
        if entry.buff == false then return nil end
        return "buff"
    end

    function NS.ShowsCooldown(entry)
        local track = NS.TrackOf(entry)
        return track == "cooldown" or track == "both"
    end

    function NS.ShowsBuff(entry)
        local track = NS.TrackOf(entry)
        return track == "buff" or track == "both"
    end

    local function Plain(value, kind)
        return not IsSecret(value) and type(value) == kind
    end

    -- Every ID of the spell's ranks you have, into `ids`.
    local function AddRanks(id, ids)
        ids[id] = true
        local name = Global(Api("C_Spell", "GetSpellName"), id)
        if not Plain(name, "string") then return end

        local info = Global(Api("C_Spell", "GetSpellInfo"), name)
        if type(info) == "table" and Plain(info.spellID, "number") then ids[info.spellID] = true end

        local lines = Global(Api("C_SpellBook", "GetNumSpellBookSkillLines"))
        local bank = EnumValue("SpellBookSpellBank", "Player", 0)
        if not Plain(lines, "number") then return end
        for line = 1, lines do
            local skill = Global(Api("C_SpellBook", "GetSpellBookSkillLineInfo"), line)
            if type(skill) == "table" and Plain(skill.itemIndexOffset, "number")
               and Plain(skill.numSpellBookItems, "number") then
                for slot = skill.itemIndexOffset + 1, skill.itemIndexOffset + skill.numSpellBookItems do
                    local item = Global(Api("C_SpellBook", "GetSpellBookItemInfo"), slot, bank)
                    if type(item) == "table" and Plain(item.name, "string") and item.name == name
                       and Plain(item.spellID, "number") then
                        ids[item.spellID] = true
                    end
                end
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Learning whether a spell leaves a buff on you.
    ---------------------------------------------------------------------------

    local entryRanks = setmetatable({}, { __mode = "k" })   -- entry -> { [id] = true }
    local rankOwners = {}                                    -- id -> { entry, ... }
    local LOOK_AFTER = 0.5                                   -- seconds after the cast

    local function AurasReadable()
        local secret = Global(Api("C_Secrets", "ShouldAurasBeSecret"))
        return not (IsSecret(secret) or secret == true)
    end

    local function BuffUp(ranks)
        for id in pairs(ranks) do
            local aura = Global(Api("C_UnitAuras", "GetPlayerAuraBySpellID"), id)
            -- Secret first: a secret is never compared, not even with nil.
            if not IsSecret(aura) and aura ~= nil then return true end
        end
        return false
    end

    local function StillTracked(entry)
        for _, other in ipairs(NS.db.tracked) do
            if other == entry then return true end
        end
        return false
    end

    -- Every spell entry's ranks, and which entries each ID belongs to; and any
    -- buff already on you noticed.
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

    local function Look(entries)
        local changed = false
        local readable = AurasReadable()
        for _, entry in ipairs(entries) do
            local ranks = entryRanks[entry]
            if ranks and StillTracked(entry) then
                local learned
                if BuffUp(ranks) then learned = true elseif readable then learned = false end
                if learned ~= nil and entry.buff ~= learned then
                    entry.buff = learned
                    changed = true
                end
            end
        end
        if changed then
            NS.Refresh()
            DogsForeverUI.RefreshOptions()
        end
    end

    local learner = CreateFrame("Frame")
    pcall(learner.RegisterUnitEvent, learner, "UNIT_SPELLCAST_SUCCEEDED", "player")
    learner:SetScript("OnEvent", function(_, _, unit, _, spellID)
        if unit ~= "player" or IsSecret(spellID) then return end
        local owners = rankOwners[spellID]
        if not owners or not (C_Timer and C_Timer.After) then return end
        local entries = {}
        for i, entry in ipairs(owners) do entries[i] = entry end
        C_Timer.After(LOOK_AFTER, function() Look(entries) end)
    end)

    function Durations.SpellIDs()
        local ids, any = {}, false
        for _, entry in ipairs(NS.db.tracked) do
            if NS.ShowsBuff(entry) then
                AddRanks(entry.id, ids)
                any = true
            end
        end
        return ids, any
    end

    ---------------------------------------------------------------------------
    -- The bars: the game's buttons, made to look like cooldown bars.
    ---------------------------------------------------------------------------

    local parts = setmetatable({}, { __mode = "k" })   -- button -> its pieces
    local buttons = {}                                 -- every one made, in order

    -- initializeFrame: the one moment the addon may build on the button.
    local function Build(button)
        local p = {}
        p.bg = button:CreateTexture(nil, "BACKGROUND")
        p.bg:SetAllPoints(button)
        p.icon = button:CreateTexture(nil, "ARTWORK")
        p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        p.divider = button:CreateTexture(nil, "ARTWORK")

        local bar = CreateFrame("StatusBar", nil, button)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        p.bar = bar

        -- The gold, under everything on the bar, with the sheen and shade the
        -- addon's fills have.
        local gold = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
        gold:SetAllPoints(bar)
        gold:SetTexture(Style.FLAT_TEXTURE)
        gold:SetVertexColor(COLOR[1], COLOR[2], COLOR[3], 1)
        local sheen = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
        sheen:SetTexture(Style.FLAT_TEXTURE)
        sheen:SetPoint("TOPLEFT", bar, "TOPLEFT")
        sheen:SetPoint("BOTTOMRIGHT", bar, "RIGHT")
        local shade = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
        shade:SetTexture(Style.FLAT_TEXTURE)
        shade:SetPoint("TOPLEFT", bar, "LEFT")
        shade:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
        if sheen.SetGradient and CreateColor then
            sheen:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, SHEEN))
            shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, SHADE), CreateColor(0, 0, 0, 0))
        end
        p.gold, p.sheen, p.shade = gold, sheen, shade

        -- The part the game fills: the elapsed time, dark, from the right.
        p.paint = function(statusBar)
            Style.SetBarFill(statusBar)
            statusBar:SetStatusBarColor(DARK[1], DARK[2], DARK[3], DARK[4])
            if statusBar.SetReverseFill then statusBar:SetReverseFill(true) end
        end
        p.timeRoom = TIME_ROOM
        p.spark = Style.AddSpark(bar)
        p.spark:SetAlpha(0)
        p.nameText = bar:CreateFontString(nil, "OVERLAY")
        p.timeText = bar:CreateFontString(nil, "OVERLAY")
        p.countText = button:CreateFontString(nil, "OVERLAY")
        p.border = Style.AddBorder(button)

        parts[button] = p
        buttons[#buttons + 1] = button
        NS.LayOutParts(button, p)
        -- What it was laid out at, so Resize knows when there is anything to do.
        p.width, p.height = NS.db.barWidth, NS.db.barHeight
        p.px = p.divider:GetWidth()

        -- Handed to the game, which runs them from here on.
        Call(button, "SetIcon", p.icon)
        Call(button, "SetDurationBar", bar, { interpolation = IMMEDIATE, direction = ELAPSED })
        Call(button, "SetDurationText", p.timeText,
            NS.auraFormatter and { textFormatter = NS.auraFormatter } or nil)
        Call(button, "SetSpellName", p.nameText)
        Call(button, "SetApplicationCount", p.countText)
    end

    -- A new size for the bars already made - only while the game lets the
    -- addon at them (auras not secret), and only when the size did change.
    --
    -- Sizes ONLY: the button, the icon and the bar. The name and the time are
    -- the game's once it runs them (their text is secret), and re-laying them
    -- out from here is refused - it once cleared the name's anchors and then
    -- failed before setting new ones, which left every buff bar without its
    -- name. They hang off the bar, so they follow it anyway; their font size
    -- is the one they were made with.
    local function Resize()
        local secret = Global(Api("C_Secrets", "ShouldAurasBeSecret"))
        if IsSecret(secret) or secret == true then return end
        local db = NS.db
        local width, height = db.barWidth, db.barHeight
        for _, button in ipairs(buttons) do
            local p = parts[button]
            if p and (p.width ~= width or p.height ~= height) then
                p.width, p.height = width, height
                pcall(button.SetSize, button, width, height)
                pcall(p.icon.SetSize, p.icon, height, height)
                pcall(p.bar.SetSize, p.bar, math.max(1, width - height - (p.px or 1)), height)
            end
        end
    end

    ---------------------------------------------------------------------------
    -- The container, on an anchor of the addon's own that sits on top of the
    -- cooldown bars.
    ---------------------------------------------------------------------------

    local anchor = CreateFrame("Frame", nil, NS.holder)
    anchor:SetSize(1, 1)
    local container          -- nil: not made yet; false: this client has none
    local placedFor          -- "up:3" - what the anchor was last placed for
    Durations.anchor = anchor

    local function GrowsDown() return NS.db.growDirection == "down" end

    -- Which way it grows, and where it hangs off the anchor.
    local function Direct(c)
        local flow = type(AnchorUtil) == "table" and AnchorUtil.FlowDirection or {}
        local axis = type(AnchorUtil) == "table" and AnchorUtil.FlowLayoutAxis or {}
        local down = GrowsDown()
        local point = down and "TOPLEFT" or "BOTTOMLEFT"
        Call(c, "SetFlowLayoutAxis", axis.Vertical)
        Call(c, "SetFlowLayoutAnchorPoint", point)
        Call(c, "SetFlowLayoutGrowthDirection", flow.Right, down and flow.Down or flow.Up)
        Call(c, "ClearAllPoints")
        Call(c, "SetPoint", point, anchor, point, 0, 0)
    end

    local function Filters(ids)
        return { includeSpellIDs = ids }
    end

    local function Create(ids)
        local ok, c = pcall(CreateFrame, "AuraContainer", nil, NS.holder, "CustomAuraContainerTemplate")
        if not ok or not c then
            container = false
            return nil
        end
        Call(c, "SetEditModePreviewEnabled", false)
        Call(c, "SetUnit", "player")
        Direct(c)
        Call(c, "AddAuraGroup", GROUP, "HELPFUL", {
            maxFrameCount = MAX_BARS,
            initializeFrame = Build,
            candidateFilters = Filters(ids),
            layout = { elementSpacing = GAP, lineSpacing = GAP },
        })
        container = c
        Durations.container = c
        return c
    end

    -- On top of `slots` cooldown bars, gliding there as they come and go
    -- (NS.SlideTo) - at once after a refresh, when nothing is on screen to
    -- glide from.
    function Durations.Follow(slots)
        local db = NS.db
        local down = GrowsDown()
        local instant = placedFor == nil
        local key = (down and "down:" or "up:") .. slots .. ":" .. db.barHeight
        if key == placedFor then return end
        placedFor = key
        local offset = slots * (db.barHeight + GAP)
        if down then
            NS.SlideTo(anchor, "TOPLEFT", -offset, instant)
        else
            NS.SlideTo(anchor, "BOTTOMLEFT", offset, instant)
        end
    end

    function Durations.Refresh()
        for entry in pairs(hasCooldown) do hasCooldown[entry] = nil end
        placedFor = nil
        MapRanks()
        local ids, any = Durations.SpellIDs()
        Durations.ids = ids

        if not any or not NS.db.enabled then
            if container then
                Call(container, "SetEnabled", false)
                Call(container, "Hide")
            end
            return
        end

        if container == nil then Create(ids) end
        if not container then return end

        Call(container, "SetAuraGroupCandidateFilters", GROUP, Filters(ids))
        Direct(container)
        Resize()
        Call(container, "SetEnabled", true)
        Call(container, "Show")
        Call(container, "UpdateAllAuras")
    end
end
