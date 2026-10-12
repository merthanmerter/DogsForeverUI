-- The plates' buff and debuff rows: the client's own aura container
-- (CustomAuraContainerTemplate), which fills itself from the unit's auras -
-- secret or not, never read here. The addon gives it a unit, groups by filter
-- string, a flow direction and the buttons' look, set as each button is made
-- (initializeFrame): after that the buttons are off limits while auras are
-- secret. The game's own rows are retired with their frames (BlizzardFrames.lua).

local UnitAuras = {}
DogsForeverUI.Frames.UnitAuras = UnitAuras

do -- private scope
    local NS = DogsForeverUI.Frames
    local Style = DogsForeverUI.Style
    local Call = DogsForeverUI.Call
    local IsSecret = issecretvalue

    UnitAuras.CHOICES = {
        { value = "below", label = "Below" },
        { value = "above", label = "Above" },
        { value = "off",   label = "Off" },
    }
    -- The party's column has no room above or below: beside each frame.
    local PARTY_CHOICES = {
        { value = "right", label = "Right" },
        { value = "off",   label = "Off" },
    }
    UnitAuras.UNITS = {
        { unit = "target",       key = "targetAuras",       label = "Target auras" },
        { unit = "focus",        key = "focusAuras",        label = "Focus auras" },
        { unit = "targettarget", key = "targettargetAuras", label = "Target of target auras" },
        { unit = "pet",          key = "petAuras",          label = "Pet auras", iconScale = 15 / 17 },
    }
    for index = 1, 4 do
        UnitAuras.UNITS[#UnitAuras.UNITS + 1] = {
            unit = "party" .. index, key = "partyAuras", label = "Party auras",
            choices = PARTY_CHOICES, iconScale = 15 / 17,
        }
    end
    -- Show self: the same row on the player's frame in the column.
    UnitAuras.UNITS[#UnitAuras.UNITS + 1] = {
        unit = "player", plate = "partyplayer", self = true, key = "partyAuras", label = "Party auras",
        choices = PARTY_CHOICES, iconScale = 15 / 17,
    }
    local VALID = { below = true, above = true, off = true, right = true }
    local byUnit = {}
    for _, entry in ipairs(UnitAuras.UNITS) do byUnit[entry.unit] = entry end

    -- Whose an aura is only the "PLAYER"/"!PLAYER" filter tokens can tell:
    -- isFromPlayerOrPlayerPet is true for ANY player's aura, so it is asked
    -- only on your own groups, where it changes nothing.
    local MINE = { isFromPlayerOrPlayerPet = true }
    -- A unit too far away to be seen passes every filter, so its row is then
    -- two plain groups instead, each aura once (Reach).
    local FAR = { farbuffs = true, fardebuffs = true }

    local SMALL, LARGE = 17, 21       -- the game's target frame sizes
    local SPACING = 3                 -- between icons and between rows
    local GAP = 7                     -- daylight to the plate's border or name row
    local MAX_BUFFS, MAX_DEBUFFS, MAX_MY_BUFFS = 32, 16, 16
    local POLL = 0.5                  -- the target's target has no aura events
    local FLOW = AnchorUtil.FlowDirection
    local DISPEL_STYLE = Enum.CustomAuraButtonDispelTypeTextureStyle

    local containers = {}             -- unit -> container, or false if it cannot be made
    UnitAuras.containers = containers
    local order = {}                  -- unit -> "friendly" / "hostile" / "party", as last laid out
    local groupKeys = {}              -- unit -> every group key its row has
    local far = {}                    -- unit -> its row is the two plain groups now

    local function IsParty(unit)
        return byUnit[unit] ~= nil and byUnit[unit].key == "partyAuras"
    end

    -- "below", "above", "right" or "off".
    function UnitAuras.Side(unit)
        local entry, db = byUnit[unit], NS.db
        if not entry then return "off" end
        if entry.self and not db.partyShowSelf then return "off" end
        local side = db[entry.key]
        return VALID[side] and side or "off"
    end

    -- Buttons. Your own buffs are a group of their own, larger, edged in gold;
    -- a purgeable buff wears the game's stealable border (24 round a 17).
    UnitAuras.STEALABLE_ART = "Interface\\TargetingFrame\\UI-TargetingFrame-Stealable"
    local STEALABLE_SCALE = 24 / 17

    -- The time left as a swipe over `icon`.
    local function NewSwipe(button, icon)
        local ok, swipe = pcall(CreateFrame, "Cooldown", nil, button, "CooldownFrameTemplate")
        if not ok then return nil end
        swipe:SetAllPoints(icon)
        swipe:SetReverse(true)
        swipe:SetDrawEdge(false)
        swipe:SetHideCountdownNumbers(true)
        return swipe
    end

    -- A button's edge (gold round your own), cropped icon, swipe and count;
    -- the preview's buttons wear the same.
    local function Dress(button)
        local edge = button:CreateTexture(nil, "BACKGROUND")
        edge:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
        edge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(button)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local swipe = NewSwipe(button, icon)
        local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
        return edge, icon, swipe, count
    end

    local function EdgeColour(mine)
        if mine then return Style.GOLD[1], Style.GOLD[2], Style.GOLD[3], 1 end
        return 0, 0, 0, 1
    end

    local function ButtonMaker(size, debuff, mine, dispelStyle, purgeable)
        return function(button)
            pcall(button.SetSize, button, size, size)
            if purgeable then
                local ring = button:CreateTexture(nil, "OVERLAY")
                ring:SetTexture(UnitAuras.STEALABLE_ART)
                ring:SetBlendMode("ADD")
                local across = math.floor(size * STEALABLE_SCALE + 0.5)
                ring:SetSize(across, across)
                ring:SetPoint("CENTER", button, "CENTER", 0, 0)
            end

            local edge, icon, swipe, count = Dress(button)
            edge:SetColorTexture(EdgeColour(mine))
            Call(button, "SetIcon", icon)
            if swipe then Call(button, "SetDurationCooldown", swipe) end
            Call(button, "SetApplicationCount", count)

            if debuff then
                local dispel = button:CreateTexture(nil, "OVERLAY")
                dispel:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
                dispel:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
                Call(button, "AddDispelTypeTexture", dispel, { style = dispelStyle or DISPEL_STYLE.Border })
            end
        end
    end

    -- One group's place in the row.
    local function Layout(index, newLine)
        return { elementSpacing = SPACING, lineSpacing = SPACING, groupSpacing = SPACING,
                 groupLineSpacing = SPACING, layoutIndex = index, forceNewLine = newLine }
    end

    -- Friendly: buffs (yours, purgeable, the rest), then a row of debuffs
    -- (yours first). Hostile: debuffs first, then a row of buffs.
    local function Layouts(friendly)
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
        local friend = UnitIsFriend("player", unit)
        return not IsSecret(friend) and friend and true or false
    end

    -- Close enough to be seen? No unit, or a secret answer, counts as seen.
    local function Seen(unit)
        local exists = UnitExists(unit)
        if IsSecret(exists) or not exists then return true end
        local visible = UnitIsVisible(unit)
        if IsSecret(visible) or visible == nil then return true end
        return visible and true or false
    end

    -- Each group on or off: the plain pair while the unit cannot be seen,
    -- every other group while it can - but a friend's buffs are never purged.
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

    -- Answers true when seen-or-not changed (or `force`) and the groups switched.
    local function Reach(container, unit, force)
        local away = not Seen(unit)
        if far[unit] == away and not force then return false end
        far[unit] = away
        ApplyGroups(container, unit)
        return true
    end

    local function ApplyOrder(container, unit, force)
        if order[unit] == "party" then return end      -- (fixed)
        local kind = Friendly(unit) and "friendly" or "hostile"
        if order[unit] == kind and not force then return end
        order[unit] = kind
        for key, layout in pairs(Layouts(kind == "friendly")) do
            Call(container, "SetAuraGroupLayout", key, layout)
        end
        ApplyGroups(container, unit)
    end

    -- Rows as wide as the plate, hung below, above (clear of the name row) or
    -- right of it. Guarded: the client may refuse layout once it has groups.
    local function Place(container, plate, side)
        local above = side == "above"
        Call(container, "SetFlowLayoutAnchorPoint", above and "BOTTOMLEFT" or "TOPLEFT")
        Call(container, "SetFlowLayoutGrowthDirection", FLOW.Right, above and FLOW.Up or FLOW.Down)
        Call(container, "SetFlowLayoutMaximumLineSize", (NS.UnitPlate.Size(NS.db, plate)))
        Call(container, "ClearAllPoints")
        if side == "right" then
            Call(container, "SetPoint", "TOPLEFT", plate, "TOPRIGHT", Style.BORDER_INSET + GAP, 0)
        elseif above then
            Call(container, "SetPoint", "BOTTOMLEFT", plate, "TOPLEFT", 0, NS.UnitPlate.TopRoom() * (plate.scale or 1) + GAP)
        else
            Call(container, "SetPoint", "TOPLEFT", plate, "BOTTOMLEFT", 0, -(Style.BORDER_INSET + GAP))
        end
    end

    ---------------------------------------------------------------------------
    -- A party member's auras, chosen by the game's own rule (the container's
    -- ProcessAura policy) and filters; on the frame itself, as the raid-style
    -- frames draw them: each dispellable type's icon at the top right, the
    -- health fill washed in its colour, a big defensive in the middle.
    ---------------------------------------------------------------------------

    UnitAuras.DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison", "Bleed" }
    local TYPE_ICON = 14                    -- the game's (CompactDispelDebuffTemplate)
    local DEFENSIVE = 22                    -- the game's centre icon (11 * 2)
    -- This client flags permanent buffs as big defensives too; maxDuration
    -- always drops permanent auras, and only those with no limit.
    local DEFENSIVE_FILTER = { maxDuration = math.huge }

    local indicators = {}       -- party unit -> its container on the frame itself
    UnitAuras.indicators = indicators

    -- The colours the dispel marks are drawn in.
    local DISPEL = { Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Disease = { 0.6, 0.4, 0 },
                     Poison = { 0, 0.6, 0 } }
    function UnitAuras.DispelColour(kind)
        local colour = DISPEL[kind] or DISPEL.Magic
        return colour[1], colour[2], colour[3]
    end

    -- `texture` over `plate`'s health FILL only, so the health still reads.
    local function OverFill(texture, plate)
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", plate.health, "TOPLEFT", 0, 0)
        texture:SetPoint("BOTTOMRIGHT", plate.health:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    end

    -- The dispel wash (EllesmereUI's "fill"): the bars' flat fill in the type's
    -- colour with their sheen over it, one level over the health bar and under
    -- the frame's words. Answers its texture.
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

    local function TypeIconMaker(frame)
        pcall(frame.SetSize, frame, TYPE_ICON, TYPE_ICON)
        Call(frame, "EnableMouse", false)
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(frame)
        Call(frame, "AddDispelTypeTexture", icon, { style = DISPEL_STYLE.Icon })
    end

    -- Taking no mouse, so the frame can still be clicked there.
    local function DefensiveMaker(plate, size)
        local make = ButtonMaker(size, false)
        return function(frame)
            make(frame)
            Call(frame, "ClearAllPoints")
            Call(frame, "SetPoint", "CENTER", plate, "CENTER", 0, 0)
            Call(frame, "EnableMouse", false)
        end
    end

    -- The client's container for `unit` on `parent`, or nil where it cannot be made.
    local function NewContainer(parent, unit)
        local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
        if not ok or not container then return nil end
        Call(container, "SetEditModePreviewEnabled", false)
        Call(container, "SetUnit", unit)
        return container
    end

    -- `marksOnly`: the type icons and the wash, no big defensive (the player's).
    local function CreateIndicators(unit, plate, marksOnly)
        local box = NewContainer(plate, unit)
        if not box then return nil end
        Call(box, "SetFrameLevel", plate:GetFrameLevel() + 8)
        Call(box, "SetFlowLayoutAnchorPoint", "TOPRIGHT")
        Call(box, "SetFlowLayoutGrowthDirection", FLOW.Left, FLOW.Down)
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
        local size = math.max(10, math.min(DEFENSIVE, health + power - 4))
        Call(box, "AddAuraSlot", "defensive", "HELPFUL|BIG_DEFENSIVE",
            { initializeFrame = DefensiveMaker(plate, size), sortMethod = AuraContainerSortMethod.BigDefensive,
              candidateFilters = DEFENSIVE_FILTER })
        return box
    end

    -- A row's groups, in order. `large`: the larger size; `own`: asked only of
    -- your auras (MINE); `gold`: your buffs' gold edge; `debuff`: a dispel
    -- border. A party member's: `only` its game classification (one per aura,
    -- so never both), `unsorted` the filter should the policy be refused.
    local ROW_GROUPS = {
        { key = "mine",       filter = "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY", debuff = true, large = true, own = true },
        { key = "others",     filter = "HARMFUL|!PLAYER", debuff = true },
        { key = "mybuffs",    filter = "HELPFUL|PLAYER", large = true, own = true, gold = true },
        -- The game's filter says which buffs can be taken off (EllesmereUI's
        -- purge split): each of this group wears the stealable border.
        { key = "purge",      filter = "HELPFUL|!PLAYER|RAID_PLAYER_DISPELLABLE", purgeable = true },
        { key = "buffs",      filter = "HELPFUL|!PLAYER|!RAID_PLAYER_DISPELLABLE" },
        { key = "farbuffs",   filter = "HELPFUL" },
        { key = "fardebuffs", filter = "HARMFUL", debuff = true },
    }
    -- Everyone else's buffs worth a look, each kind ruling out the ones before;
    -- the debuffs you can dispel on a row of their own, then the rest the game shows.
    local PARTY_GROUPS = {
        { key = "mybuffs",    filter = "HELPFUL|PLAYER", large = true, own = true, gold = true },
        { key = "external",   filter = "HELPFUL|!PLAYER|EXTERNAL_DEFENSIVE" },
        { key = "important",  filter = "HELPFUL|!PLAYER|!EXTERNAL_DEFENSIVE|IMPORTANT" },
        { key = "hots",       filter = "HELPFUL|!PLAYER|!EXTERNAL_DEFENSIVE|!IMPORTANT|RAID_IN_COMBAT" },
        { key = "buffs",      filter = "HELPFUL|!PLAYER|!EXTERNAL_DEFENSIVE|!IMPORTANT|!RAID_IN_COMBAT|RAID" },
        { key = "dispel",     filter = "HARMFUL|RAID", debuff = true, only = "Dispel", newLine = true,
          style = DISPEL_STYLE.BorderWithIcon },
        { key = "debuffs",    filter = "HARMFUL", unsorted = "HARMFUL|!RAID", debuff = true, only = "Debuff" },
        { key = "farbuffs",   filter = "HELPFUL", newLine = true },
        { key = "fardebuffs", filter = "HARMFUL", debuff = true, newLine = true },
    }

    -- `groups` added to `unit`'s row, their keys kept for ApplyGroups; each in
    -- `layouts` by its key, or in order. `classify`: the game sorts the auras.
    local function AddGroups(unit, container, groups, small, large, layouts, classify)
        local keys = {}
        groupKeys[unit] = keys
        for index, group in ipairs(groups) do
            local candidates = group.own and MINE or nil
            if group.only then
                candidates = { processedAuraType = classify and AuraUtil.AuraUpdateChangedType[group.only] or nil }
            end
            keys[index] = group.key
            Call(container, "AddAuraGroup", group.key, not classify and group.unsorted or group.filter, {
                maxFrameCount = group.gold and MAX_MY_BUFFS or group.debuff and MAX_DEBUFFS or MAX_BUFFS,
                initializeFrame = ButtonMaker(group.large and large or small, group.debuff, group.gold,
                    group.style, group.purgeable),
                candidateFilters = candidates,
                layout = layouts and layouts[group.key] or Layout(index, group.newLine or false),
            })
        end
    end

    local function Create(unit, plate)
        local container = NewContainer(plate, unit)
        containers[unit] = container or false
        if not container then return nil end

        local scale = byUnit[unit].iconScale or plate.scale or 1
        local small = math.floor(SMALL * scale + 0.5)
        local large = math.floor(LARGE * scale + 0.5)
        if IsParty(unit) then
            local classify = pcall(container.SetAuraProcessingPolicy, container,
                CustomAuraContainerAuraProcessingPolicy.ProcessAura)
            AddGroups(unit, container, PARTY_GROUPS, small, large, nil, classify)
            order[unit] = "party"
            indicators[unit] = CreateIndicators(unit, plate)
            Reach(container, unit, true)
            return container
        end
        AddGroups(unit, container, ROW_GROUPS, small, large, Layouts(false))
        order[unit] = "hostile"
        far[unit] = false
        ApplyGroups(container, unit)
        return container
    end

    -- Your own buffs on a party pet (UnitPlate.lua), `size` across, at most
    -- `count`, on `parent`. Placed by its owner.
    function UnitAuras.NewMineRow(parent, unit, size, count)
        local container = NewContainer(parent, unit)
        if not container then return nil end
        Call(container, "AddAuraGroup", "mybuffs", "HELPFUL|PLAYER",
            { maxFrameCount = count, initializeFrame = ButtonMaker(size, false, true),
              candidateFilters = MINE,
              layout = { elementSpacing = 1, lineSpacing = 1, layoutIndex = 1 } })
        return container
    end

    ---------------------------------------------------------------------------
    -- PREVIEW: while Unlock Mode is open each party frame shows a few made-up
    -- auras of the addon's own (the client's container fakes auras only in
    -- the game's Edit Mode), picked at random each time it opens; the real
    -- row steps aside meanwhile.
    ---------------------------------------------------------------------------

    local ICONS = "Interface\\Icons\\"
    local PREVIEW_BUFFS = {
        "Spell_Holy_WordFortitude", "Spell_Holy_PowerWordShield", "Spell_Nature_Rejuvenation",
        "Spell_Holy_Renew", "Spell_Holy_MagicalSentry", "Spell_Nature_Regeneration",
        "Spell_Holy_SealOfWisdom", "Spell_Holy_FistOfJustice",
    }
    local PREVIEW_DEBUFFS = {
        { icon = "Spell_Shadow_ShadowWordPain", kind = "Magic" },
        { icon = "Spell_Frost_FrostNova", kind = "Magic" },
        { icon = "Spell_Shadow_CurseOfSargeras", kind = "Curse" },
        { icon = "Spell_Nature_CorrosiveBreath", kind = "Poison" },
        { icon = "Ability_Creature_Disease_02", kind = "Disease" },
    }

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
        local yours = math.random(1, 2)         -- the first one or two
        for index, icon in ipairs(Some(PREVIEW_BUFFS, 2, 4)) do
            buffs[#buffs + 1] = { icon = icon, duration = math.random(20, 60), left = math.random(5, 19) / 20,
                                  count = math.random(1, 6) == 1 and math.random(2, 5) or nil,
                                  mine = index <= yours }
        end
        for _, debuff in ipairs(Some(PREVIEW_DEBUFFS, 1, 2)) do
            debuffs[#debuffs + 1] = { icon = debuff.icon, kind = debuff.kind, duration = math.random(8, 24),
                                      left = math.random(5, 19) / 20 }
        end
        picks[unit] = { buffs = buffs, debuffs = debuffs }
    end

    local function PreviewButton(row)
        local button = CreateFrame("Frame", nil, row)
        button.edge, button.icon, button.swipe, button.count = Dress(button)
        return button
    end

    -- The made-up debuffs' types at the frame's top right, the frame washed in
    -- the first's colour, as the real marks (CreateIndicators).
    local function ShowPreviewMarks(row, plate, pick)
        local marks = row.marks
        if not marks then
            marks = CreateFrame("Frame", nil, row)
            marks:EnableMouse(false)
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
        marks.wash:SetVertexColor(UnitAuras.DispelColour(kinds[1]))
        marks.washFrame:SetShown(kinds[1] ~= nil)
        for index, kind in ipairs(kinds) do
            local icon = marks.icons[index] or marks:CreateTexture(nil, "OVERLAY")
            marks.icons[index] = icon
            icon:SetSize(TYPE_ICON, TYPE_ICON)
            icon:ClearAllPoints()
            icon:SetPoint("TOPRIGHT", marks, "TOPRIGHT", -2 - (index - 1) * (TYPE_ICON + 1), -2)
            local atlas = "RaidFrame-Icon-Debuff" .. kind
            if Style:HasAtlas(atlas) then
                icon:SetAtlas(atlas)
            else
                icon:SetColorTexture(UnitAuras.DispelColour(kind))
            end
            icon.kind = kind
            icon:Show()
        end
        for index = #kinds + 1, #marks.icons do marks.icons[index]:Hide() end
        marks:Show()
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
        -- Yours first, as the container lays a friend's out; debuffs a new row.
        local list = {}
        for _, aura in ipairs(pick.buffs) do if aura.mine then list[#list + 1] = aura end end
        for _, aura in ipairs(pick.buffs) do if not aura.mine then list[#list + 1] = aura end end
        local firstDebuff = #list + 1
        for _, aura in ipairs(pick.debuffs) do list[#list + 1] = aura end
        local x, y, line, now = 0, 0, 0, GetTime()
        for index, aura in ipairs(list) do
            local button = row.buttons[index] or PreviewButton(row)
            row.buttons[index] = button
            local size = aura.mine and large or small
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
                button.edge:SetColorTexture(UnitAuras.DispelColour(aura.kind))
            else
                button.edge:SetColorTexture(EdgeColour(aura.mine))
            end
            button.count:SetText(aura.count and tostring(aura.count) or "")
            if button.swipe then
                button.swipe:SetCooldown(now - aura.duration * (1 - aura.left), aura.duration)
            end
            button.aura = aura
            button:Show()
        end
        for index = #list + 1, #row.buttons do row.buttons[index]:Hide() end
        row:SetSize(width, y + line)
        ShowPreviewMarks(row, plate, pick)
        row:Show()
    end

    -- Unlock Mode open for the frames (their own flag: the core's stays set
    -- until the last module has locked).
    local function Unlocked()
        return NS.db.unlocked == true
    end

    local function Previewing(unit)
        return IsParty(unit) and Unlocked()
    end

    -- A container on or off, asked to look again when on.
    local function Switch(box, on)
        Call(box, "SetEnabled", on)
        Call(box, on and "Show" or "Hide")
        if on then Call(box, "UpdateAllAuras") end
    end

    -- A party frame's marks and big defensive, on or off with its row.
    local function Indicators(unit, on)
        if indicators[unit] then Switch(indicators[unit], on) end
    end

    local function RefreshUnit(unit)
        local side = UnitAuras.Side(unit)
        local plate = NS.plates and NS.plates[byUnit[unit].plate or unit]
        local container = containers[unit]

        if side == "off" or not plate then
            if container then Switch(container, false) end
            Indicators(unit, false)
            if previews[unit] then previews[unit]:Hide() end
            return
        end

        if Previewing(unit) then
            if container then Call(container, "Hide") end
            Indicators(unit, false)
            ShowPreview(unit, plate)
            return
        end
        if previews[unit] then previews[unit]:Hide() end

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

    -- A different unit behind the same token: the container is asked to look
    -- again, and re-ordered for a friend.
    local function Changed(unit)
        local container = containers[unit]
        if not container or UnitAuras.Side(unit) == "off" then return end
        ApplyOrder(container, unit)
        Reach(container, unit)
        Call(container, "UpdateAllAuras")
        if indicators[unit] then Call(indicators[unit], "UpdateAllAuras") end
    end

    local watcher = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_FACTION", "GROUP_ROSTER_UPDATE" }) do
        watcher:RegisterEvent(event)
    end
    watcher:RegisterUnitEvent("UNIT_TARGET", "target")
    watcher:RegisterUnitEvent("UNIT_PET", "player")    -- a new pet behind the same token
    watcher:SetScript("OnEvent", function(_, event, unit)
        if event == "GROUP_ROSTER_UPDATE" then
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

    -- Every half second while a row is on: the target's target looked at
    -- again, and every unit asked whether it can be seen (FAR).
    local sincePoll = 0
    function UnitAuras.Poll(_, elapsed)
        sincePoll = sincePoll + (elapsed or 0)
        if sincePoll < POLL then return end
        sincePoll = 0
        for unit, container in pairs(containers) do
            if container and UnitAuras.Side(unit) ~= "off" and not Previewing(unit) then
                if Reach(container, unit) or unit == "targettarget" then
                    Call(container, "UpdateAllAuras")
                end
            end
        end
    end

    -- PLAYER_DISPEL: the party's dispel marks on the player frame too
    -- (setting playerDispel) - no aura row, no big defensive.
    local playerMarks           -- once made (false: could not be)

    local function RefreshPlayerMarks()
        local plate = NS.plates and NS.plates.player
        local on = NS.db.playerDispel == true and plate ~= nil
        if on and playerMarks == nil then
            playerMarks = CreateIndicators("player", plate, true) or false
        end
        if playerMarks then Switch(playerMarks, on) end
    end
    function UnitAuras.PlayerMarks() return playerMarks end

    function UnitAuras.Refresh()
        RefreshPlayerMarks()
        -- Unlock Mode just opened: new made-up auras for this time.
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
        watcher:SetScript("OnUpdate", polling and UnitAuras.Poll or nil)
    end
end
