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
    local VALID = { below = true, above = true, off = true, right = true }
    local byUnit = {}
    for _, entry in ipairs(UnitAuras.UNITS) do byUnit[entry.unit] = entry end

    local SMALL, LARGE = 17, 21       -- the game's target frame sizes
    local SPACING = 3                 -- between icons and between rows
    local GAP = 7                     -- daylight to the plate's border or name row
    local MAX_BUFFS, MAX_DEBUFFS = 32, 16
    local TOT_POLL = 0.5              -- the target's target has no aura events

    local containers = {}             -- unit -> container, or false if it cannot be made
    UnitAuras.containers = containers
    local order = {}                  -- unit -> "friendly" / "hostile", as last laid out

    local function Call(object, method, ...)
        if type(object) ~= "table" and type(object) ~= "userdata" then return nil end
        local fn = object[method]
        if type(fn) ~= "function" then return nil end
        local ok, result = pcall(fn, object, ...)
        if ok then return result end
    end

    -- Where a unit's auras go: "below", "above" or "off".
    function UnitAuras.Side(unit)
        local entry, db = byUnit[unit], NS.db
        if not entry or not db then return "off" end
        local side = db[entry.key]
        return VALID[side] and side or "off"
    end

    ---------------------------------------------------------------------------
    -- One button, as the game makes it: the icon, a hairline of black round it,
    -- the time left as a swipe, the stack count, and for a debuff the border
    -- in its dispel type's colour.
    ---------------------------------------------------------------------------

    local function ButtonMaker(size, debuff)
        return function(button)
            pcall(button.SetSize, button, size, size)

            local edge = button:CreateTexture(nil, "BACKGROUND")
            edge:SetColorTexture(0, 0, 0, 1)
            edge:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
            edge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)

            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(button)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            Call(button, "SetIcon", icon)

            local ok, swipe = pcall(CreateFrame, "Cooldown", nil, button, "CooldownFrameTemplate")
            if not ok or not swipe then ok, swipe = pcall(CreateFrame, "Cooldown", nil, button) end
            if ok and swipe then
                swipe:SetAllPoints(icon)
                Call(swipe, "SetReverse", true)
                Call(swipe, "SetDrawEdge", false)
                Call(swipe, "SetHideCountdownNumbers", true)
                Call(button, "SetDurationCooldown", swipe)
            end

            local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
            Call(button, "SetApplicationCount", count)

            if debuff then
                local dispel = button:CreateTexture(nil, "OVERLAY")
                dispel:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
                dispel:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
                local styles = type(Enum) == "table" and Enum.CustomAuraButtonDispelTypeTextureStyle
                Call(button, "AddDispelTypeTexture", dispel,
                    { style = type(styles) == "table" and styles.Border or nil })
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Laying a container out.
    ---------------------------------------------------------------------------

    -- Friendly: buffs, then a new row of debuffs (yours first). Hostile: your
    -- debuffs, everyone else's, then a new row of buffs.
    local function Layouts(friendly)
        local function Layout(index, newLine)
            return { elementSpacing = SPACING, lineSpacing = SPACING, groupSpacing = SPACING,
                     groupLineSpacing = SPACING, layoutIndex = index, forceNewLine = newLine }
        end
        if friendly then
            return { buffs = Layout(1, false), mine = Layout(2, true), others = Layout(3, false) }
        end
        return { mine = Layout(1, false), others = Layout(2, false), buffs = Layout(3, true) }
    end

    local function Friendly(unit)
        local ok, friend = pcall(UnitIsFriend, "player", unit)
        if not ok or IsSecret(friend) then return false end
        return friend and true or false
    end

    local function ApplyOrder(container, unit, force)
        local kind = Friendly(unit) and "friendly" or "hostile"
        if order[unit] == kind and not force then return end
        order[unit] = kind
        for key, layout in pairs(Layouts(kind == "friendly")) do
            Call(container, "SetAuraGroupLayout", key, layout)
        end
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
        local layouts = Layouts(false)
        Call(container, "AddAuraGroup", "mine", "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY",
            { maxFrameCount = MAX_DEBUFFS, initializeFrame = ButtonMaker(large, true),
              layout = layouts.mine })
        Call(container, "AddAuraGroup", "others", "HARMFUL|!PLAYER",
            { maxFrameCount = MAX_DEBUFFS, initializeFrame = ButtonMaker(small, true),
              layout = layouts.others })
        Call(container, "AddAuraGroup", "buffs", "HELPFUL",
            { maxFrameCount = MAX_BUFFS, initializeFrame = ButtonMaker(small, false),
              layout = layouts.buffs })
        order[unit] = "hostile"

        containers[unit] = container
        return container
    end

    ---------------------------------------------------------------------------

    local function RefreshUnit(unit)
        local side = UnitAuras.Side(unit)
        local plate = NS.plates and NS.plates[unit]
        local container = containers[unit]

        if side == "off" or not plate then
            if container then
                Call(container, "SetEnabled", false)
                Call(container, "Hide")
            end
            return
        end

        if container == nil then container = Create(unit, plate) end
        if not container then return end

        Place(container, plate, side)
        Call(container, "SetEnabled", true)
        Call(container, "Show")
        ApplyOrder(container, unit, true)
        Call(container, "UpdateAllAuras")
    end

    function UnitAuras.Refresh()
        for _, entry in ipairs(UnitAuras.UNITS) do RefreshUnit(entry.unit) end
    end

    -- A different unit behind the same token: the container is not told by
    -- the token, so it is asked to look again, and to re-order for a friend.
    local function Changed(unit)
        local container = containers[unit]
        if not container or UnitAuras.Side(unit) == "off" then return end
        ApplyOrder(container, unit)
        Call(container, "UpdateAllAuras")
    end
    UnitAuras.Changed = Changed

    local watcher = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
                             "UNIT_TARGET", "UNIT_FACTION", "UNIT_PET",
                             "GROUP_ROSTER_UPDATE" }) do
        pcall(watcher.RegisterEvent, watcher, event)
    end
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
            if unit == "target" then Changed("targettarget") end
        elseif event == "UNIT_PET" then
            -- The owner's event: a new pet behind the same token.
            if unit == "player" then Changed("pet") end
        elseif byUnit[unit] then
            Changed(unit)
        end
    end)

    -- The target's target sends no UNIT_AURA of its own, so its auras are
    -- looked at again every half second while its row is on.
    local sincePoll = 0
    watcher:SetScript("OnUpdate", function(_, elapsed)
        sincePoll = sincePoll + (elapsed or 0)
        if sincePoll < TOT_POLL then return end
        sincePoll = 0
        local container = containers.targettarget
        if container and UnitAuras.Side("targettarget") ~= "off" then
            Call(container, "UpdateAllAuras")
        end
    end)
end
