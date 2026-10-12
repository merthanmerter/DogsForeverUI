-- The buffs and debuffs over or under the target, focus, target-of-target and
-- pet frames: the addon's own aura rows, each with a setting of its own -
-- Below, Above or Off.
--
-- WHY THE ADDON'S OWN. The game's rows could not be moved from above to below:
-- which side they go on is TargetFrame.buffsOnTop, written only by Edit Mode's
-- "Buffs on top", and the frames are out of Edit Mode because this addon draws
-- them. Writing that field from here would taint the game's own aura code,
-- which in combat runs on secret aura data and breaks when tainted. So the
-- game's rows are retired (BlizzardFrames.lua) and these take their place.
--
-- WHAT THEY ARE MADE OF. The client's own aura container, the template it
-- makes for add-ons to use: CustomAuraContainerTemplate, declared with
-- allowUntaintedCreation (Blizzard_AuraContainer). The game fills it from the
-- unit's auras itself - secret or not, the addon never reads one - and each
-- button shows its tooltip on hover by itself. The addon gives it a unit,
-- groups with a filter string ("HELPFUL", "HARMFUL|PLAYER"), a direction to
-- grow in, and the buttons' look, which can only be set up as each button is
-- made (initializeFrame): after that the game denies addon code access to the
-- buttons while auras are secret.
--
-- As the game's target frame has them: buffs 17 across, your own debuffs 21,
-- everyone else's 17; a friendly unit's buffs first, an enemy's debuffs first,
-- the second kind starting a new row; rows as wide as the frame. The pet's are
-- the game's pet frame's 15 (PartyAuraFrameTemplate), whatever size its plate
-- is drawn at.
--
-- The target and focus castbars go on the side the auras are not
-- (BlizzardFrames.AurasBelow, read by UnitCastbar).

local UnitAuras = {}
DogsForeverUI.Frames.UnitAuras = UnitAuras

do -- private scope
    local NS = DogsForeverUI.Frames
    local Style = DogsForeverUI.Style
    local IsSecret = issecretvalue or function() return false end

    UnitAuras.CHOICES = {
        { value = "below", label = "Below" },
        { value = "above", label = "Above" },
        { value = "off",   label = "Off" },
    }
    -- The party's frames are a column, so a row above or below one would run
    -- into the next: theirs go beside the frame, one setting for all four.
    UnitAuras.PARTY_CHOICES = {
        { value = "right", label = "Right" },
        { value = "off",   label = "Off" },
    }
    UnitAuras.UNITS = {
        { unit = "target",       key = "targetAuras",       label = "Target auras" },
        { unit = "focus",        key = "focusAuras",        label = "Focus auras" },
        { unit = "targettarget", key = "targettargetAuras", label = "Target of target auras" },
        { unit = "pet",          key = "petAuras",          label = "Pet auras",
          iconScale = 15 / 17 },
    }
    for index = 1, 4 do
        UnitAuras.UNITS[#UnitAuras.UNITS + 1] = {
            unit = "party" .. index, key = "partyAuras", label = "Party auras",
            choices = UnitAuras.PARTY_CHOICES, iconScale = 15 / 17,
        }
    end
    -- The player's own frame in the party's column (Show self): the same
    -- row, on that frame (`plate`) - not on the player frame - and only
    -- while it is on.
    UnitAuras.UNITS[#UnitAuras.UNITS + 1] = {
        unit = "player", plate = "partyplayer", self = true, key = "partyAuras", label = "Party auras",
        choices = UnitAuras.PARTY_CHOICES, iconScale = 15 / 17,
    }    local VALID = { below = true, above = true, off = true, right = true }
    local byUnit = {}
    for _, entry in ipairs(UnitAuras.UNITS) do byUnit[entry.unit] = entry end

    -- WHOSE AN AURA IS. Only the filter tokens can tell: "PLAYER" is yours
    -- (or your pet's), "!PLAYER" everyone else's. The aura's own field,
    -- isFromPlayerOrPlayerPet, is NOT "yours" - it is true for an aura cast by
    -- ANY player (EllesmereUI found the same: "same-spec allies' buffs pass
    -- it"). Asking it for false, as this file did from 2026-10-04, dropped
    -- every buff another player had cast: a friendly target showed none, the
    -- party frames none of anyone else's (the player, 2026-10-05). It stays on
    -- your own groups only, where it is always true and changes nothing.
    --
    -- A UNIT TOO FAR AWAY TO BE SEEN (the player, 2026-10-04: a party member
    -- out of range had every buff three times under the target frame): the
    -- client can then not tell "PLAYER" from "!PLAYER" (nor the purge or
    -- importance filters), and an aura passes every group. While a unit is not
    -- visible its row is two plain groups instead - every buff, every debuff
    -- - so each aura shows once (Reach, below).
    local MINE = { isFromPlayerOrPlayerPet = true }
    -- The two plain groups, and when they are the ones on.
    local FAR = { farbuffs = true, fardebuffs = true }

    local SMALL, LARGE = 17, 21       -- the game's target frame sizes
    local SPACING = 3                 -- between icons and between rows
    local GAP = 7                     -- daylight to the plate's border or name row
    local MAX_BUFFS, MAX_DEBUFFS, MAX_MY_BUFFS = 32, 16, 16
    local TOT_POLL = 0.5              -- the target's target has no aura events

    local containers = {}             -- unit -> container, or false if it cannot be made
    UnitAuras.containers = containers
    local order = {}                  -- unit -> "friendly" / "hostile", as last laid out

    local Call = DogsForeverUI.Call

    -- Where a unit's auras go: "below", "above" or "off".
    function UnitAuras.Side(unit)
        local entry, db = byUnit[unit], NS.db
        if not entry or not db then return "off" end
        if entry.self and not db.partyShowSelf then return "off" end
        local side = db[entry.key]
        return VALID[side] and side or "off"
    end

    ---------------------------------------------------------------------------
    -- One button, as the game makes it: the icon, a hairline of black round it,
    -- the time left as a swipe, the stack count, and for a debuff the border
    -- in its dispel type's colour.
    --
    -- YOUR OWN BUFFS TOLD APART (the player, 2026-10-03: "Party frames
    -- our/player auras should be distinguishable"): the addon never reads an
    -- aura - whose it is can only be asked of the client by a group's filter
    -- - so your buffs are a group of their own ("HELPFUL|PLAYER"), first,
    -- at the size the game gives your own debuffs, their hairline in the
    -- addon's gold (Style.GOLD). Everyone else's buffs as before.
    ---------------------------------------------------------------------------

    local function DispelStyles()
        local styles = type(Enum) == "table" and Enum.CustomAuraButtonDispelTypeTextureStyle
        return type(styles) == "table" and styles or {}
    end

    -- `dispelStyle`: how a debuff's dispel type is drawn round it (the game's
    -- border, Border, when not given).
    -- A buff an enemy has that can be purged or stolen: the game's target
    -- frame's stealable border round it (TargetFrameAuraButton.xml,
    -- StealableBorder: this art, added, 24 round a 17 icon).
    UnitAuras.STEALABLE_ART = "Interface\\TargetingFrame\\UI-TargetingFrame-Stealable"
    UnitAuras.STEALABLE_SCALE = 24 / 17

    -- The time left as a swipe over `icon`, on `button`.
    local function NewSwipe(button, icon)
        local ok, swipe = pcall(CreateFrame, "Cooldown", nil, button, "CooldownFrameTemplate")
        if not ok or not swipe then ok, swipe = pcall(CreateFrame, "Cooldown", nil, button) end
        if not ok or not swipe then return nil end
        swipe:SetAllPoints(icon)
        Call(swipe, "SetReverse", true)
        Call(swipe, "SetDrawEdge", false)
        Call(swipe, "SetHideCountdownNumbers", true)
        return swipe
    end

    local function ButtonMaker(size, debuff, mine, dispelStyle, purgeable)
        return function(button)
            pcall(button.SetSize, button, size, size)
            if purgeable then
                local ring = button:CreateTexture(nil, "OVERLAY")
                ring:SetTexture(UnitAuras.STEALABLE_ART)
                ring:SetBlendMode("ADD")
                local across = math.floor(size * UnitAuras.STEALABLE_SCALE + 0.5)
                ring:SetSize(across, across)
                ring:SetPoint("CENTER", button, "CENTER", 0, 0)
            end

            local edge = button:CreateTexture(nil, "BACKGROUND")
            if mine then
                edge:SetColorTexture(Style.GOLD[1], Style.GOLD[2], Style.GOLD[3], 1)
            else
                edge:SetColorTexture(0, 0, 0, 1)
            end
            edge:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
            edge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)

            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(button)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            Call(button, "SetIcon", icon)

            local swipe = NewSwipe(button, icon)
            if swipe then Call(button, "SetDurationCooldown", swipe) end

            local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
            Call(button, "SetApplicationCount", count)

            if debuff then
                local dispel = button:CreateTexture(nil, "OVERLAY")
                dispel:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
                dispel:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
                Call(button, "AddDispelTypeTexture", dispel,
                    { style = dispelStyle or DispelStyles().Border })
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Laying a container out.
    ---------------------------------------------------------------------------

    -- One group's place in the row.
    local function Layout(index, newLine)
        return { elementSpacing = SPACING, lineSpacing = SPACING, groupSpacing = SPACING,
                 groupLineSpacing = SPACING, layoutIndex = index, forceNewLine = newLine }
    end

    -- Friendly: buffs (yours first), then a new row of debuffs (yours
    -- first). Hostile: your debuffs, everyone else's, then a new row of buffs
    -- (yours first).
    local function Layouts(friendly)
        -- (The purgeable buffs before the rest of the buffs: what can be taken
        -- off first.)
        if friendly then
            return { mybuffs = Layout(1, false), purge = Layout(2, false), buffs = Layout(3, false),
                     mine = Layout(4, true), others = Layout(5, false),
                     farbuffs = Layout(6, false), fardebuffs = Layout(7, true) }
        end
        return { mine = Layout(1, false), others = Layout(2, false),
                 mybuffs = Layout(3, true), purge = Layout(4, false), buffs = Layout(5, false),
                 fardebuffs = Layout(6, false), farbuffs = Layout(7, true) }
    end

    local function Friendly(unit)
        local ok, friend = pcall(UnitIsFriend, "player", unit)
        if not ok or IsSecret(friend) then return false end
        return friend and true or false
    end

    -- Whether the unit is close enough to be seen (see FAR). A unit that is
    -- not there, or an answer the client keeps secret, counts as seen: the
    -- full row.
    local function Seen(unit)
        local ok, exists = pcall(UnitExists, unit)
        if not ok or IsSecret(exists) or not exists then return true end
        local okVisible, visible = pcall(UnitIsVisible, unit)
        if not okVisible or IsSecret(visible) or visible == nil then return true end
        return visible and true or false
    end

    local groupKeys = {}              -- unit -> every group key its row has
    local far = {}                    -- unit -> its row is the two plain groups now

    -- Each group on or off for who the unit is now: the plain pair while it
    -- cannot be seen, every other group while it can - but a friend's buffs
    -- are never purged.
    local function ApplyGroups(container, unit)
        local away = far[unit] == true
        local friend = order[unit] == "friendly"
        for _, key in ipairs(groupKeys[unit] or {}) do
            local on
            if FAR[key] then
                on = away
            else
                on = not away and not (key == "purge" and friend)
            end
            Call(container, "SetAuraGroupEnabled", key, on)
        end
    end

    -- Seen or not changed since last time (or `force`): the groups switched.
    -- Answers true when they were.
    local function Reach(container, unit, force)
        local away = not Seen(unit)
        if far[unit] == away and not force then return false end
        far[unit] = away
        ApplyGroups(container, unit)
        return true
    end

    local function ApplyOrder(container, unit, force)
        if order[unit] == "party" then return end      -- (a party row's order is fixed)
        local kind = Friendly(unit) and "friendly" or "hostile"
        if order[unit] == kind and not force then return end
        order[unit] = kind
        for key, layout in pairs(Layouts(kind == "friendly")) do
            Call(container, "SetAuraGroupLayout", key, layout)
        end
        ApplyGroups(container, unit)
    end

    -- Which way it grows, and where it hangs off the plate: `side` is "below",
    -- "above" or "right" (the party's, beside the frame, level with its top).
    local function Place(container, plate, side)
        local flow = type(AnchorUtil) == "table" and AnchorUtil.FlowDirection or {}
        local scale = plate.scale or 1
        local above = side == "above"
        local point = above and "BOTTOMLEFT" or "TOPLEFT"
        Call(container, "SetFlowLayoutAnchorPoint", point)
        Call(container, "SetFlowLayoutGrowthDirection", flow.Right, above and flow.Up or flow.Down)
        -- Rows as wide as the plate.
        local width = NS.UnitPlate.Size(NS.db, plate)
        Call(container, "SetFlowLayoutMaximumLineSize", width)

        -- Guarded: once it has groups the client restricts layout on the
        -- container, and an anchor it refused must not become an error.
        Call(container, "ClearAllPoints")
        if side == "right" then
            Call(container, "SetPoint", "TOPLEFT", plate, "TOPRIGHT", Style.BORDER_INSET + GAP, 0)
        elseif above then
            -- Clear of the name and level row over the plate's border.
            Call(container, "SetPoint", "BOTTOMLEFT", plate, "TOPLEFT", 0,
                NS.UnitPlate.TopRoom() * scale + GAP)
        else
            Call(container, "SetPoint", "TOPLEFT", plate, "BOTTOMLEFT", 0,
                -(Style.BORDER_INSET + GAP))
        end
    end

    ---------------------------------------------------------------------------
    -- A PARTY MEMBER'S AURAS AS THE GAME'S PARTY FRAMES CHOOSE THEM (the
    -- player, 2026-10-03: "Party frames dispelable debuffs should be
    -- blizz-like" - "show important buffs similar to blizz default"). The
    -- game's own rule, run by the client in the container (its ProcessAura
    -- policy: AuraUtil.ProcessAura, what PartyMemberFrame and the raid-style
    -- frames sort every aura with), and the game's own filters:
    --
    --   * your own buffs, first, as before (gold, larger);
    --   * everyone else's buffs only where the game would show them - the
    --     ones ProcessAura calls a Buff (a spell flagged to show on raid
    --     frames for your spec, ...); the rest stay off, as on the game's;
    --   * the debuffs YOU can dispel (the RAID filter: "harmful auras the
    --     player can dispel") first on a row of their own, each in the
    --     game's dispel border with its type's corner icon; then the other
    --     debuffs ProcessAura shows, in the game's plain dispel border.
    --
    -- And on the frame itself, as the raid-style frames draw them
    -- (Blizzard_PrivateAurasUI): the type of each debuff you can dispel as
    -- the game's icon at the top right (one per type, up to every type),
    -- the frame washed in that type's colour (the game's dispel highlight:
    -- its fill, gradient and edge), and a big defensive in the middle.
    ---------------------------------------------------------------------------

    local function IsParty(unit)
        return byUnit[unit] ~= nil and byUnit[unit].key == "partyAuras"
    end

    UnitAuras.DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison", "Bleed" }
    UnitAuras.TYPE_ICON = 14                -- the game's (CompactDispelDebuffTemplate)
    UnitAuras.DEFENSIVE = 22                -- the game's centre icon (11 * 2)
    -- This client flags permanent buffs as big defensives too - Find Herbs
    -- sat in the middle of a frame (the player, 2026-10-04). The container's
    -- maxDuration filter always drops permanent auras; with no limit it drops
    -- only those, and every timed one stays the game's choice.
    UnitAuras.DEFENSIVE_FILTER = { maxDuration = math.huge }

    local indicators = {}       -- party unit -> its container on the frame itself
    UnitAuras.indicators = indicators

    ---------------------------------------------------------------------------
    -- THE DISPEL WASH, EllesmereUI's (EUI_RaidFrames_AuraContainers.lua,
    -- ApplyRFDispelSlot, its default "fill"): the game's art stretched over
    -- the whole frame, above everything, hid the bars and the name (the
    -- player, 2026-10-03: "when there is a dispelable debuff I cant see the
    -- healthbars at all!!!"). Now, as Ellesmere's: one slot per dispel type -
    -- so its colour is known, never read from the aura - each a flat wash in
    -- that type's colour laid over the health bar's FILL only (anchored to its
    -- fill texture, so the health still reads), one level over the health bar
    -- and under the frame's words (UnitPlate.lua, THE WORDS' LAYER). Never
    -- takes the mouse.
    --
    -- IN THE BARS' OWN LOOK (the player, 2026-10-03, a screenshot: "did you
    -- mess with the party frames bar textures (which should be our standard
    -- texture)"): a plain colour square looked like a flat sticker over the
    -- bar. The wash is the bar's own fill - the flat texture in the type's
    -- colour - with the sheen and shade every bar of the addon's wears over it
    -- (Style.SheenOver), so a dispellable debuff reads as the bar turning that
    -- colour, nothing more.
    ---------------------------------------------------------------------------

    -- `texture` laid over `plate`'s health fill.
    local function OverFill(texture, plate)
        local fill = plate.health.GetStatusBarTexture and plate.health:GetStatusBarTexture()
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", plate.health, "TOPLEFT", 0, 0)
        texture:SetPoint("BOTTOMRIGHT", fill or plate.health, "BOTTOMRIGHT", 0, 0)
    end

    -- The wash on `owner`, over `plate`'s health fill, in the bars' look and
    -- the colour r, g, b. Answers its fill texture.
    local function Wash(owner, plate, r, g, b)
        local wash = owner:CreateTexture(nil, "ARTWORK", nil, 0)
        wash:SetTexture(Style.FLAT_TEXTURE)
        wash:SetVertexColor(r, g, b, 1)
        OverFill(wash, plate)
        Style.SheenOver(owner, wash, 1)
        return wash
    end

    local function WashMaker(plate, kind)
        return function(frame)
            Call(frame, "ClearAllPoints")
            Call(frame, "SetAllPoints", plate.health)
            Call(frame, "SetFrameLevel", plate.health:GetFrameLevel() + 1)
            Call(frame, "EnableMouse", false)
            Wash(frame, plate, UnitAuras.DispelColour(kind))
        end
    end

    -- A dispel type's icon (the game's RaidFrame-Icon-Debuff... atlas).
    local function TypeIconMaker(frame)
        local size = UnitAuras.TYPE_ICON
        pcall(frame.SetSize, frame, size, size)
        Call(frame, "EnableMouse", false)
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(frame)
        Call(frame, "AddDispelTypeTexture", icon, { style = DispelStyles().Icon })
    end

    -- The big defensive, in the middle of the frame, drawn as every other
    -- aura button; taking no mouse, so the frame can still be clicked there.
    local function DefensiveMaker(plate, size)
        local make = ButtonMaker(size, false)
        return function(frame)
            make(frame)
            Call(frame, "ClearAllPoints")
            Call(frame, "SetPoint", "CENTER", plate, "CENTER", 0, 0)
            Call(frame, "EnableMouse", false)
        end
    end

    -- `marksOnly`: the type icons and the wash, no big defensive (the
    -- player frame's - PLAYER_DISPEL, below).
    local function CreateIndicators(unit, plate, marksOnly)
        local ok, box = pcall(CreateFrame, "AuraContainer", nil, plate, "CustomAuraContainerTemplate")
        if not ok or not box then return nil end
        Call(box, "SetEditModePreviewEnabled", false)
        Call(box, "SetUnit", unit)
        Call(box, "SetFrameLevel", plate:GetFrameLevel() + 8)
        -- The type icons from the frame's top right, leftwards.
        local flow = type(AnchorUtil) == "table" and AnchorUtil.FlowDirection or {}
        Call(box, "SetFlowLayoutAnchorPoint", "TOPRIGHT")
        Call(box, "SetFlowLayoutGrowthDirection", flow.Left, flow.Down)
        Call(box, "ClearAllPoints")
        Call(box, "SetPoint", "TOPRIGHT", plate, "TOPRIGHT", -2, -2)
        for index, kind in ipairs(UnitAuras.DISPEL_TYPES) do
            Call(box, "AddAuraGroup", kind, "HARMFUL|RAID",
                { maxFrameCount = 1, initializeFrame = TypeIconMaker,
                  candidateFilters = { includeDispelTypes = { [kind] = true } },
                  layout = { elementSpacing = 1, groupSpacing = 1, layoutIndex = index } })
        end
        for _, kind in ipairs(UnitAuras.DISPEL_TYPES) do
            Call(box, "AddAuraSlot", "wash" .. kind, "HARMFUL|RAID",
                { initializeFrame = WashMaker(plate, kind),
                  candidateFilters = { includeDispelTypes = { [kind] = true } } })
        end
        if marksOnly then return box end
        local _, health, power = NS.UnitPlate.Size(NS.db, plate)
        local size = math.max(10, math.min(UnitAuras.DEFENSIVE, (health or 0) + (power or 0) - 4))
        local sort = type(AuraContainerSortMethod) == "table" and AuraContainerSortMethod.BigDefensive or nil
        Call(box, "AddAuraSlot", "defensive", "HELPFUL|BIG_DEFENSIVE",
            { initializeFrame = DefensiveMaker(plate, size), sortMethod = sort,
              candidateFilters = UnitAuras.DEFENSIVE_FILTER })
        return box
    end

    -- A group added to `unit`'s row, its key kept for ApplyGroups.
    local function AddGroup(unit, container, key, filter, options)
        groupKeys[unit] = groupKeys[unit] or {}
        table.insert(groupKeys[unit], key)
        Call(container, "AddAuraGroup", key, filter, options)
    end

    -- EVERYONE ELSE'S BUFFS ON A PARTY FRAME (the player, 2026-10-05: "why
    -- not important buffs in party frames too"): the ones worth a look, each
    -- kind its own group, every one after the first ruling out the ones
    -- before it ("!") so no buff is in two - the game's filters, nothing read:
    --   * external defensives (Pain Suppression, Blessing of Protection, ...)
    --   * the ones the game flags as important
    --   * the ones it flags to show on raid frames in combat (others' HoTs)
    --   * the ones YOU could put on them (RAID: helpful auras the player can
    --     apply) - another priest's Fortitude, as your own would be.
    -- The game's own party-frame rule (ProcessAura's "Buff") was asked before:
    -- on this client that is little more than your own, so nobody else's
    -- buffs ever showed.
    UnitAuras.PARTY_BUFFS = {
        { key = "external",  filter = "HELPFUL|!PLAYER|EXTERNAL_DEFENSIVE" },
        { key = "important", filter = "HELPFUL|!PLAYER|!EXTERNAL_DEFENSIVE|IMPORTANT" },
        { key = "hots",      filter = "HELPFUL|!PLAYER|!EXTERNAL_DEFENSIVE|!IMPORTANT|RAID_IN_COMBAT" },
        { key = "buffs",     filter = "HELPFUL|!PLAYER|!EXTERNAL_DEFENSIVE|!IMPORTANT|!RAID_IN_COMBAT|RAID" },
    }

    local function PartyGroups(unit, container, small, large)
        local changed = type(AuraUtil) == "table" and AuraUtil.AuraUpdateChangedType
        local policy = type(CustomAuraContainerAuraProcessingPolicy) == "table"
            and CustomAuraContainerAuraProcessingPolicy.ProcessAura
        -- (Without the game's classification - an older client - the debuffs
        -- are shown unsorted rather than not at all.)
        local classify = false
        if changed and policy and type(container.SetAuraProcessingPolicy) == "function" then
            classify = pcall(container.SetAuraProcessingPolicy, container, policy)
        end
        local function Only(kind)
            return { processedAuraType = classify and changed[kind] or nil }
        end
        local styles = DispelStyles()
        local index = 1
        AddGroup(unit, container, "mybuffs", "HELPFUL|PLAYER",
            { maxFrameCount = MAX_MY_BUFFS, initializeFrame = ButtonMaker(large, false, true),
              candidateFilters = MINE, layout = Layout(index, false) })
        for _, group in ipairs(UnitAuras.PARTY_BUFFS) do
            index = index + 1
            AddGroup(unit, container, group.key, group.filter,
                { maxFrameCount = MAX_BUFFS, initializeFrame = ButtonMaker(small, false),
                  layout = Layout(index, false) })
        end
        -- The game's classification is one value per aura, so the two debuff
        -- rows never share one: a dispellable boss debuff, which the game
        -- calls a Debuff, goes on the second row, as on the game's frames.
        AddGroup(unit, container, "dispel", "HARMFUL|RAID",
            { maxFrameCount = MAX_DEBUFFS, initializeFrame = ButtonMaker(small, true, false, styles.BorderWithIcon),
              candidateFilters = Only("Dispel"), layout = Layout(index + 1, true) })
        AddGroup(unit, container, "debuffs", classify and "HARMFUL" or "HARMFUL|!RAID",
            { maxFrameCount = MAX_DEBUFFS, initializeFrame = ButtonMaker(small, true, false, styles.Border),
              candidateFilters = Only("Debuff"), layout = Layout(index + 2, false) })
        -- Too far away to be seen (FAR): every buff, then every debuff.
        AddGroup(unit, container, "farbuffs", "HELPFUL",
            { maxFrameCount = MAX_BUFFS, initializeFrame = ButtonMaker(small, false),
              layout = Layout(index + 3, true) })
        AddGroup(unit, container, "fardebuffs", "HARMFUL",
            { maxFrameCount = MAX_DEBUFFS, initializeFrame = ButtonMaker(small, true, false, styles.Border),
              layout = Layout(index + 4, true) })
    end

    local function Create(unit, plate)
        local ok, container = pcall(CreateFrame, "AuraContainer", nil, plate,
            "CustomAuraContainerTemplate")
        if not ok or not container then
            containers[unit] = false
            return nil
        end
        Call(container, "SetEditModePreviewEnabled", false)
        Call(container, "SetUnit", unit)

        local scale = byUnit[unit].iconScale or plate.scale or 1
        local small = math.floor(SMALL * scale + 0.5)
        local large = math.floor(LARGE * scale + 0.5)
        if IsParty(unit) then
            PartyGroups(unit, container, small, large)
            order[unit] = "party"
            containers[unit] = container
            indicators[unit] = CreateIndicators(unit, plate)
            Reach(container, unit, true)
            return container
        end
        local layouts = Layouts(false)
        AddGroup(unit, container, "mine", "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY",
            { maxFrameCount = MAX_DEBUFFS, initializeFrame = ButtonMaker(large, true),
              candidateFilters = MINE, layout = layouts.mine })
        AddGroup(unit, container, "others", "HARMFUL|!PLAYER",
            { maxFrameCount = MAX_DEBUFFS, initializeFrame = ButtonMaker(small, true),
              layout = layouts.others })
        AddGroup(unit, container, "mybuffs", "HELPFUL|PLAYER",
            { maxFrameCount = MAX_MY_BUFFS, initializeFrame = ButtonMaker(large, false, true),
              candidateFilters = MINE, layout = layouts.mybuffs })
        -- PURGEABLE BUFFS (EllesmereUI's purge split, EUI_UnitFrames_
        -- AuraContainers.lua PurgeGlow - the game's filter answers which buff
        -- can be taken off, so every button of this group is one by
        -- construction and wears the game's stealable border; nothing read).
        -- A friend's buffs are never in it.
        AddGroup(unit, container, "purge", "HELPFUL|!PLAYER|RAID_PLAYER_DISPELLABLE",
            { maxFrameCount = MAX_BUFFS, initializeFrame = ButtonMaker(small, false, false, nil, true),
              layout = layouts.purge })
        AddGroup(unit, container, "buffs", "HELPFUL|!PLAYER|!RAID_PLAYER_DISPELLABLE",
            { maxFrameCount = MAX_BUFFS, initializeFrame = ButtonMaker(small, false),
              layout = layouts.buffs })
        -- Too far away to be seen (FAR).
        AddGroup(unit, container, "farbuffs", "HELPFUL",
            { maxFrameCount = MAX_BUFFS, initializeFrame = ButtonMaker(small, false),
              layout = layouts.farbuffs })
        AddGroup(unit, container, "fardebuffs", "HARMFUL",
            { maxFrameCount = MAX_DEBUFFS, initializeFrame = ButtonMaker(small, true),
              layout = layouts.fardebuffs })
        order[unit] = "hostile"
        far[unit] = false
        ApplyGroups(container, unit)

        containers[unit] = container
        return container
    end

    -- A PARTY PET'S ROW (PartyPets.lua; the player, 2026-10-07: "our buffs
    -- heals can be show inside their frame but tiny"): your own buffs on the
    -- pet - your heals over time - `size` across, at most `count`, on
    -- `parent`. Placed by its owner.
    function UnitAuras.NewMineRow(parent, unit, size, count)
        local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
        if not ok or not container then return nil end
        Call(container, "SetEditModePreviewEnabled", false)
        Call(container, "SetUnit", unit)
        Call(container, "AddAuraGroup", "mybuffs", "HELPFUL|PLAYER",
            { maxFrameCount = count, initializeFrame = ButtonMaker(size, false, true),
              candidateFilters = MINE,
              layout = { elementSpacing = 1, lineSpacing = 1, layoutIndex = 1 } })
        return container
    end

    ---------------------------------------------------------------------------
    -- PREVIEW AURAS (the player, 2026-10-03: "in preview mode show few random
    -- auras (buff/debuff)"): while Unlock Mode is open, each party frame shows
    -- a few made-up buffs and debuffs where its auras go, so the row can be
    -- seen as it is placed. The client's own container can only show made-up
    -- auras in the game's Edit Mode (its data source is switched by the
    -- client then, AuraUtil.SetDataProvider - never from an addon), so these
    -- are icons of the addon's own, drawn as the container's buttons are:
    -- the icon, a hairline round it - a debuff's in its dispel type's colour -
    -- the time left as a swipe, now and then a stack count. Which, and how
    -- many (PREVIEW_BUFFS 2-4 buffs, then a new row of 1-2 debuffs), is picked
    -- at random each time Unlock Mode opens. The real row steps aside
    -- meanwhile and comes back as it closes.
    ---------------------------------------------------------------------------

    local ICONS = "Interface\\Icons\\"
    UnitAuras.PREVIEW_BUFFS = {
        "Spell_Holy_WordFortitude", "Spell_Holy_PowerWordShield", "Spell_Nature_Rejuvenation",
        "Spell_Holy_Renew", "Spell_Holy_MagicalSentry", "Spell_Nature_Regeneration",
        "Spell_Holy_SealOfWisdom", "Spell_Holy_FistOfJustice",
    }
    UnitAuras.PREVIEW_DEBUFFS = {
        { icon = "Spell_Shadow_ShadowWordPain", kind = "Magic" },
        { icon = "Spell_Frost_FrostNova", kind = "Magic" },
        { icon = "Spell_Shadow_CurseOfSargeras", kind = "Curse" },
        { icon = "Spell_Nature_CorrosiveBreath", kind = "Poison" },
        { icon = "Ability_Creature_Disease_02", kind = "Disease" },
    }
    -- The game's own dispel colours (DebuffTypeColor), with these where it
    -- has none.
    local DISPEL = { Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Disease = { 0.6, 0.4, 0 },
                     Poison = { 0, 0.6, 0 } }
    local function DispelColour(kind)
        local game = type(DebuffTypeColor) == "table" and DebuffTypeColor[kind]
        if type(game) == "table" and game.r then return game.r, game.g, game.b end
        local own = DISPEL[kind] or DISPEL.Magic
        return own[1], own[2], own[3]
    end
    UnitAuras.DispelColour = DispelColour

    local previews = {}         -- unit -> its preview row
    UnitAuras.previews = previews
    local picks = {}            -- unit -> what its row shows this time
    local wasPreviewing = false

    -- Some of a list, in a random order.
    local function Some(list, least, most)
        local pool = {}
        for index, item in ipairs(list) do pool[index] = item end
        local chosen = {}
        for _ = 1, math.min(#pool, math.random(least, most)) do
            chosen[#chosen + 1] = table.remove(pool, math.random(#pool))
        end
        return chosen
    end

    local function Pick(unit)
        local buffs, debuffs = {}, {}
        local chosen = Some(UnitAuras.PREVIEW_BUFFS, 2, 4)
        local yours = math.random(1, 2)         -- (the first one or two: yours)
        for index, icon in ipairs(chosen) do
            buffs[#buffs + 1] = { icon = icon, duration = math.random(20, 60), left = math.random(5, 19) / 20,
                                  count = math.random(1, 6) == 1 and math.random(2, 5) or nil,
                                  mine = index <= yours }
        end
        for _, debuff in ipairs(Some(UnitAuras.PREVIEW_DEBUFFS, 1, 2)) do
            debuffs[#debuffs + 1] = { icon = debuff.icon, kind = debuff.kind, duration = math.random(8, 24),
                                      left = math.random(5, 19) / 20 }
        end
        picks[unit] = { buffs = buffs, debuffs = debuffs }
    end

    local function PreviewButton(row)
        local button = CreateFrame("Frame", nil, row)
        button.edge = button:CreateTexture(nil, "BACKGROUND")
        button.edge:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
        button.edge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints(button)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.swipe = NewSwipe(button, button.icon)
        button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
        return button
    end

    local function ShowPreview(unit, plate)
        if not picks[unit] then Pick(unit) end
        local row = previews[unit]
        if not row then
            row = CreateFrame("Frame", nil, plate)
            row.buttons = {}
            previews[unit] = row
        end
        row:SetFrameLevel(plate:GetFrameLevel() + 5)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", plate, "TOPRIGHT", Style.BORDER_INSET + GAP, 0)
        local scale = byUnit[unit].iconScale or 1
        local small = math.floor(SMALL * scale + 0.5)
        local large = math.floor(LARGE * scale + 0.5)
        local width = math.max(large, (NS.UnitPlate.Size(NS.db, plate)))
        local pick = picks[unit]
        local list = {}
        -- Yours first, as the container lays a friend's out.
        for _, aura in ipairs(pick.buffs) do if aura.mine then list[#list + 1] = aura end end
        for _, aura in ipairs(pick.buffs) do if not aura.mine then list[#list + 1] = aura end end
        local firstDebuff = #list + 1
        for _, aura in ipairs(pick.debuffs) do list[#list + 1] = aura end
        local x, y, line, now = 0, 0, 0, GetTime and GetTime() or 0
        for index, aura in ipairs(list) do
            local button = row.buttons[index] or PreviewButton(row)
            row.buttons[index] = button
            local size = aura.mine and large or small
            -- Debuffs a new row, as a friend's auras are laid out; a row as
            -- wide as the frame, as tall as its tallest icon.
            if (index == firstDebuff and index > 1) or (x > 0 and x + size > width) then
                x, y, line = 0, y + line + SPACING, 0
            end
            line = math.max(line, size)
            button:SetSize(size, size)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", row, "TOPLEFT", x, -y)
            x = x + size + SPACING
            button.icon:SetTexture(ICONS .. aura.icon)
            if aura.kind then
                button.edge:SetColorTexture(DispelColour(aura.kind))
            elseif aura.mine then
                button.edge:SetColorTexture(Style.GOLD[1], Style.GOLD[2], Style.GOLD[3], 1)
            else
                button.edge:SetColorTexture(0, 0, 0, 1)
            end
            button.count:SetText(aura.count and tostring(aura.count) or "")
            if button.swipe then
                Call(button.swipe, "SetCooldown", now - aura.duration * (1 - aura.left), aura.duration)
            end
            button.aura = aura
            button:Show()
        end
        for index = #list + 1, #row.buttons do row.buttons[index]:Hide() end
        row:SetSize(width, y + line)

        -- On the frame, as the real ones (CreateIndicators): the made-up
        -- debuffs' types at the top right, the frame washed in the first's
        -- colour.
        local marks = row.marks
        if not marks then
            marks = CreateFrame("Frame", nil, row)
            marks:EnableMouse(false)
            -- (The wash on a frame of its own, one level over the health
            -- bar - under the frame's words - as the real one.)
            marks.washFrame = CreateFrame("Frame", nil, row)
            marks.washFrame:EnableMouse(false)
            marks.wash = Wash(marks.washFrame, plate, 1, 1, 1)
            marks.icons = {}
            row.marks = marks
        end
        marks:ClearAllPoints()
        marks:SetAllPoints(plate)
        marks:SetFrameLevel(plate:GetFrameLevel() + 8)
        marks.washFrame:ClearAllPoints()
        marks.washFrame:SetAllPoints(plate.health)
        marks.washFrame:SetFrameLevel(plate.health:GetFrameLevel() + 1)
        OverFill(marks.wash, plate)
        local kinds, seen = {}, {}
        for _, aura in ipairs(pick.debuffs) do
            if not seen[aura.kind] then
                seen[aura.kind] = true
                kinds[#kinds + 1] = aura.kind
            end
        end
        marks.wash:SetVertexColor(DispelColour(kinds[1]))
        marks.washFrame:SetShown(kinds[1] ~= nil)
        local iconSize = UnitAuras.TYPE_ICON
        for index, kind in ipairs(kinds) do
            local icon = marks.icons[index] or marks:CreateTexture(nil, "OVERLAY")
            marks.icons[index] = icon
            icon:SetSize(iconSize, iconSize)
            icon:ClearAllPoints()
            icon:SetPoint("TOPRIGHT", marks, "TOPRIGHT", -2 - (index - 1) * (iconSize + 1), -2)
            local atlas = "RaidFrame-Icon-Debuff" .. kind
            if Style:HasAtlas(atlas) then
                icon:SetAtlas(atlas)
            else
                icon:SetColorTexture(DispelColour(kind))
            end
            icon.kind = kind
            icon:Show()
        end
        for index = #kinds + 1, #marks.icons do marks.icons[index]:Hide() end
        marks:Show()
        row:Show()
    end

    local function HidePreview(unit)
        if previews[unit] then previews[unit]:Hide() end
    end

    -- Unlock Mode open for the frames (their own flag: the core's says so
    -- until the last module has locked, after these refreshed).
    local function Unlocked()
        return NS.db ~= nil and NS.db.unlocked == true
    end

    -- Whether a unit's row shows made-up auras now: a party frame's, while
    -- Unlock Mode is open.
    local function Previewing(unit)
        return byUnit[unit] ~= nil and byUnit[unit].key == "partyAuras" and Unlocked()
    end

    -- The party frame's own indicators (the type icons, the highlight, the
    -- big defensive) on or off with its row.
    local function Indicators(unit, on)
        local box = indicators[unit]
        if not box then return end
        Call(box, "SetEnabled", on)
        Call(box, on and "Show" or "Hide")
        if on then Call(box, "UpdateAllAuras") end
    end

    local function RefreshUnit(unit)
        local side = UnitAuras.Side(unit)
        local plate = NS.plates and NS.plates[byUnit[unit].plate or unit]
        local container = containers[unit]

        if side == "off" or not plate then
            if container then
                Call(container, "SetEnabled", false)
                Call(container, "Hide")
            end
            Indicators(unit, false)
            HidePreview(unit)
            return
        end

        if Previewing(unit) then
            if container then Call(container, "Hide") end
            Indicators(unit, false)
            ShowPreview(unit, plate)
            return
        end
        HidePreview(unit)

        if container == nil then container = Create(unit, plate) end
        if not container then return end

        Place(container, plate, side)
        Call(container, "SetEnabled", true)
        Call(container, "Show")
        ApplyOrder(container, unit, true)
        Reach(container, unit, true)
        Call(container, "UpdateAllAuras")
        Indicators(unit, true)
    end

    -- A different unit behind the same token: the container is not told by
    -- the token, so it is asked to look again, and to re-order for a friend.
    local function Changed(unit)
        local container = containers[unit]
        if not container or UnitAuras.Side(unit) == "off" then return end
        ApplyOrder(container, unit)
        Reach(container, unit)
        Call(container, "UpdateAllAuras")
        if indicators[unit] then Call(indicators[unit], "UpdateAllAuras") end
    end

    local watcher = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
                             "UNIT_FACTION", "GROUP_ROSTER_UPDATE" }) do
        pcall(watcher.RegisterEvent, watcher, event)
    end
    -- The target's new target; the owner's event for a new pet behind the
    -- same token.
    pcall(watcher.RegisterUnitEvent, watcher, "UNIT_TARGET", "target")
    pcall(watcher.RegisterUnitEvent, watcher, "UNIT_PET", "player")
    watcher:SetScript("OnEvent", function(_, event, unit)
        if event == "GROUP_ROSTER_UPDATE" then
            -- Someone joined or left: party1 may be someone else now.
            for index = 1, 4 do Changed("party" .. index) end
        elseif event == "PLAYER_TARGET_CHANGED" then
            Changed("target")
            Changed("targettarget")
        elseif event == "PLAYER_FOCUS_CHANGED" then
            Changed("focus")
        elseif event == "UNIT_TARGET" then
            Changed("targettarget")
        elseif event == "UNIT_PET" then
            Changed("pet")
        elseif byUnit[unit] then
            Changed(unit)
        end
    end)

    -- Every half second while a row is on (the timer runs only then -
    -- UnitAuras.Refresh): the target's target, which sends no UNIT_AURA of
    -- its own, looked at again; and every unit asked whether it can be seen
    -- (FAR), its groups switched the moment that changes.
    local sincePoll = 0
    local function Poll(_, elapsed)
        sincePoll = sincePoll + (elapsed or 0)
        if sincePoll < TOT_POLL then return end
        sincePoll = 0
        for unit, container in pairs(containers) do
            if container and UnitAuras.Side(unit) ~= "off" and not Previewing(unit) then
                if Reach(container, unit) or unit == "targettarget" then
                    Call(container, "UpdateAllAuras")
                end
            end
        end
    end
    UnitAuras.Poll = Poll

    ---------------------------------------------------------------------------
    -- PLAYER_DISPEL (the player, 2026-10-06: "similar to party frames ...
    -- show statuses (curse, poison etc.) in player frame too ... default but
    -- optional"): the party frame's marks on the player frame - the type of
    -- each debuff you can dispel at the top right, the health fill washed in
    -- its colour - no aura row, no big defensive. Setting playerDispel.
    ---------------------------------------------------------------------------

    local playerMarks           -- the player frame's, once made (false: could not be)

    local function RefreshPlayerMarks()
        local plate = NS.plates and NS.plates.player
        local on = NS.db ~= nil and NS.db.playerDispel == true and plate ~= nil
        if on and playerMarks == nil then
            playerMarks = CreateIndicators("player", plate, true) or false
        end
        if not playerMarks then return end
        Call(playerMarks, "SetEnabled", on)
        Call(playerMarks, on and "Show" or "Hide")
        if on then Call(playerMarks, "UpdateAllAuras") end
    end
    UnitAuras.PlayerMarks = function() return playerMarks end

    function UnitAuras.Refresh()
        RefreshPlayerMarks()
        -- (Unlock Mode just opened: new made-up auras for this time.)
        local previewing = Unlocked()
        if previewing and not wasPreviewing then
            for unit in pairs(picks) do picks[unit] = nil end
        end
        wasPreviewing = previewing
        for _, entry in ipairs(UnitAuras.UNITS) do RefreshUnit(entry.unit) end
        local polling = false
        for unit, container in pairs(containers) do
            if container and UnitAuras.Side(unit) ~= "off" then polling = true end
        end
        watcher:SetScript("OnUpdate", polling and Poll or nil)
    end
end
