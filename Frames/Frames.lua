-- MODULE: Frames  (DogsForeverUI.Frames, settings section "frames")
--
-- Player, target, focus, target of target, pet and party as two bars each
-- over a secure click button, the party's pets beside them (UnitPlate.lua);
-- the target's and focus's casts (UnitCastbar.lua), auras (UnitAuras.lua).
-- The game's own frames are faded, never replaced (BlizzardFrames.lua).

DogsForeverUI.Frames = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.Frames
    local Style = DogsForeverUI.Style

    NS.key = "frames"
    NS.title = "Frames"

    NS.defaults = {
        unlocked = false,
        barWidth = 150,
        barHeight = 30,          -- the health bar
        powerHeight = 10,        -- the resource bar under it
        showCastbar = true,      -- what the target and the focus are casting
        castbarHeight = 8,
        textPadding = 0.15,
        showHealthText = true,
        showPowerText = true,
        classColors = true,
        frameStrata = "MEDIUM",
        -- The party's column (UnitPlate.lua, THE PARTY).
        partyWidth = 120,
        partyRaidHealth = 40,
        partyPower = 8,
        partyStrata = "MEDIUM",
        partySort = "role",      -- "role", "group" or "alphabetical"
        partyLayout = "column",  -- "column" (party1 on top) or "row" (party1 at the left)
        partyShowSelf = true,
        partyShowPets = true,
        -- Auras: "below", "above" or "off"; the party's "right" or "off".
        targetAuras = "below",
        focusAuras = "below",
        targettargetAuras = "off",
        petAuras = "below",
        partyAuras = "right",
        playerDispel = true,     -- the party's dispel marks on the player frame too
        nameplateDefaults = 0,   -- how many nameplate defaults were set (NamePlates.lua)
    }

    NS.placement = {
        playerLeft = true, playerTop = true, playerPlaced = true,
        targetLeft = true, targetTop = true, targetPlaced = true,
        focusLeft = true, focusTop = true, focusPlaced = true,
        targettargetLeft = true, targettargetTop = true, targettargetPlaced = true,
        petLeft = true, petTop = true, petPlaced = true,
        partyLeft = true, partyTop = true, partyPlaced = true,   -- party1's; the rest follow it
    }

    -- Default row: focus and player left of the middle, target and its target
    -- right of it, 75% of the way down the screen.
    local ROW_TOP = 0.75
    local CENTRE_GAP = 140       -- clear space each side of the middle
    local SIDE_GAP = 8           -- between a frame and the one beside it
    local PET_GAP = 6            -- the player's border to the pet's name band
    local PARTY_EDGE = Style.BORDER_INSET + 1

    -- The party's height as Unlock Mode boxes it (a row's is one frame's), and
    -- how far its box reaches above party1's top.
    function NS.PartyColumn(db)
        local UnitPlate = NS.UnitPlate
        local _, health, power = UnitPlate.Size(db, { partyIndex = 1 })
        local above = UnitPlate.PartyTopRoom() + Style.BORDER_INSET
        local frames = UnitPlate.InRow(db) and 1 or db.partyShowSelf and UnitPlate.PARTY_SIZE or 4
        return above + (frames - 1) * UnitPlate.PartyStep(db) + health + 1 + power + Style.BORDER_INSET, above
    end

    -- Against the left edge, centred top to bottom, until the player places it.
    function NS.PlaceParty()
        local db = NS.db
        if db.partyPlaced then return end
        local screenHeight = GetScreenHeight()
        if screenHeight <= 0 then screenHeight = 768 end
        local column, above = NS.PartyColumn(db)
        db.partyLeft = PARTY_EDGE
        db.partyTop = -(screenHeight - column) / 2 - above
    end

    -- Under the player's frame, worked out once: it never follows the player's
    -- frame, but one guessed before the screen size was known is redone (`again`).
    local petFromGuess = false

    function NS.PlacePet(again, guessing)
        local db = NS.db
        if db.petPlaced or db.playerLeft == nil or db.playerTop == nil then return end
        if db.petLeft ~= nil and db.petTop ~= nil and not (again and petFromGuess) then return end
        db.petLeft = db.playerLeft
        db.petTop = db.playerTop - (db.barHeight + 1 + db.powerHeight) - Style.BORDER_INSET - PET_GAP
            - NS.UnitPlate.TopRoom() * NS.UnitPlate.SMALL_SCALE
        petFromGuess = guessing and true or false
    end

    -- Writes only frames the player has not placed (`<unit>Placed`), so it may
    -- run again once the screen size is final.
    local function PlaceFrames()
        local db = NS.db
        local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
        local guessing = screenWidth <= 0 or screenHeight <= 0
        local places

        if guessing then
            places = { player = { 300, -400 }, target = { 700, -400 },
                       focus = { 100, -400 }, targettarget = { 900, -400 } }
        else
            local width, middle, top = db.barWidth, screenWidth / 2, -screenHeight * ROW_TOP
            -- Past each plate's badge, so the next frame does not cover it.
            local side = NS.UnitPlate.SideRoom() + SIDE_GAP
            places = {
                player = { middle - CENTRE_GAP - width, top },
                target = { middle + CENTRE_GAP, top },
            }
            places.focus = { places.player[1] - side - width, top }
            places.targettarget = { places.target[1] + width + side, top }
        end

        for unit, place in pairs(places) do
            if not db[unit .. "Placed"] then
                db[unit .. "Left"], db[unit .. "Top"] = place[1], place[2]
            end
        end

        NS.PlacePet(true, guessing)
        NS.PlaceParty()
    end

    -- Built once, out of combat: each plate anchors a secure button. A /reload
    -- mid-fight waits for its end.
    local function BuildPlates()
        if NS.plates or InCombatLockdown() then return end
        local UnitPlate = NS.UnitPlate
        NS.plates = {
            player = UnitPlate.New("player", "Player"),
            target = UnitPlate.New("target", "Target"),
            focus = UnitPlate.New("focus", "Focus"),
            targettarget = UnitPlate.New("targettarget", "TargetOfTarget", UnitPlate.SMALL_SCALE),
            pet = UnitPlate.New("pet", "Pet", UnitPlate.SMALL_SCALE),
        }
        for index = 1, 4 do
            NS.plates["party" .. index] = UnitPlate.New("party" .. index, "Party" .. index, UnitPlate.PARTY_SCALE)
        end
        NS.plates.partyplayer = UnitPlate.New("player", "PartyPlayer", UnitPlate.PARTY_SCALE, 0)
        for index = 1, 4 do NS.plates["partypet" .. index] = NS.PartyPets.New(index) end
        UnitPlate.BuildColumn()
    end

    -- The plates may wait for combat's end; the game's frames do not.
    local function Refresh()
        NS.PlacePet()
        NS.PlaceParty()
        if NS.plates then
            NS.UnitPlate.SortParty(NS.db)
            for _, plate in pairs(NS.plates) do plate:Refresh() end
        end
        NS.BlizzardFrames.Refresh()
        NS.UnitAuras.Refresh()
        NS.Totems.Refresh()
        NS.NamePlates.Refresh()
        NS:Show()
    end
    NS.Refresh = Refresh

    function NS.Init()
        BuildPlates()
        Refresh()
    end

    -- A first run or a reset leaves a frame without a position.
    function NS.Normalise(db)
        for _, unit in ipairs({ "player", "target", "focus", "targettarget", "pet", "party" }) do
            if db[unit .. "Left"] == nil or db[unit .. "Top"] == nil then
                PlaceFrames()
                return
            end
        end
    end

    -- In combat too: what combat refuses waits for PLAYER_REGEN_ENABLED.
    function NS.Unlock()
        NS.db.unlocked = true
        Refresh()
    end

    function NS.Lock()
        NS.db.unlocked = false
        Refresh()
    end

    -- Events. A cast starting wakes its bar, drawn every frame from then; an
    -- interrupt is the one thing polling cannot see.
    local CAST_STARTS = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true,
                          UNIT_SPELLCAST_EMPOWER_START = true }

    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
                             "PLAYER_REGEN_ENABLED", "EDIT_MODE_LAYOUTS_UPDATED", "UNIT_NAME_UPDATE",
                             "UNIT_LEVEL", "UNIT_FACTION", "UNIT_DISPLAYPOWER", "UNIT_CLASSIFICATION_CHANGED",
                             "UNIT_PET", "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE",
                             "PLAYER_ROLES_ASSIGNED", "PLAYER_UPDATE_RESTING", "CVAR_UPDATE" }) do
        NS:RegisterEvent(event)
    end
    NS:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "target", "focus")
    NS:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "target", "focus")
    for event in pairs(CAST_STARTS) do NS:RegisterUnitEvent(event, "target", "focus") end
    NS:RegisterUnitEvent("UNIT_TARGET", "target")

    local function OnEvent(event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            -- UIParent is unscaled at ADDON_LOADED: placed again here.
            PlaceFrames()
            BuildPlates()
            NS.NamePlates.Init()
            Refresh()
            return
        end
        if event == "EDIT_MODE_LAYOUTS_UPDATED" then
            NS.BlizzardFrames.Refresh()
            return
        end
        if event == "PLAYER_REGEN_ENABLED" then
            -- Whatever combat refused.
            BuildPlates()
            Refresh()
            return
        end

        local plates = NS.plates
        if not plates then return end

        if event == "PLAYER_TARGET_CHANGED" then
            plates.target:Update()
            plates.targettarget:Update()
            NS.BlizzardFrames.Refresh()
            NS.UnitPlate.FollowTarget()
        elseif event == "PLAYER_FOCUS_CHANGED" then
            plates.focus:Update()
            NS.BlizzardFrames.Refresh()
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            plates[...].castbar:Interrupted()
        elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
            -- An empowered cast (retail) cut short: not complete, maybe secret.
            local unit, _, _, complete = ...
            if not issecretvalue(complete) and complete == false then plates[unit].castbar:Interrupted() end
        elseif CAST_STARTS[event] then
            plates[...].castbar:OnUpdate()
        elseif event == "UNIT_TARGET" or event == "CVAR_UPDATE" then
            plates.targettarget:Update()
        elseif event == "PLAYER_UPDATE_RESTING" then
            plates.player:Update()
        elseif event == "UNIT_PET" then
            -- Its argument is the owner. A new pet may arrive with no hide/show
            -- of the plate to repaint it.
            local owner = ...
            local index = type(owner) == "string" and owner:match("^party(%d)$")
            local plate = owner == "player" and plates.pet or index and plates["partypet" .. index]
            if plate then plate:Update() end
        elseif event == "PARTY_LEADER_CHANGED" or event == "GROUP_ROSTER_UPDATE"
               or event == "PLAYER_ROLES_ASSIGNED" then
            if event ~= "PARTY_LEADER_CHANGED" and NS.UnitPlate.SortParty(NS.db) then Refresh() end
            for _, plate in pairs(plates) do plate:Update() end
            NS.UnitPlate.FollowTarget()     -- the target may be in another slot now
        else
            local unit = ...
            if type(unit) ~= "string" then return end
            -- A member's name arriving after they joined: sorted by it.
            if event == "UNIT_NAME_UPDATE" and unit:match("^party%d$")
                and NS.UnitPlate.SortParty(NS.db) then Refresh() end
            if plates[unit] then plates[unit]:Update() end
            if unit == "player" then plates.partyplayer:Update() end
        end
    end

    -- Every frame while a cast bar or plate is on screen; asleep otherwise
    -- (hidden, its events still coming).
    local function OnUpdate()
        if not NS.plates then
            NS:Hide()
            return
        end
        local busy = false
        for _, plate in pairs(NS.plates) do
            local castbar = plate.castbar
            if castbar and castbar.bar:IsShown() then
                castbar:OnUpdate()
                busy = true
            end
            if plate:IsShown() then
                plate:OnUpdate()
                busy = true
            end
        end
        if not busy then NS:Hide() end
    end

    NS:SetScript("OnEvent", function(_, event, ...)
        NS:Show()
        OnEvent(event, ...)
    end)
    NS:SetScript("OnUpdate", OnUpdate)
    DogsForeverUI.WatchPlacing(function() NS:Show() end)

    DogsForeverUI:RegisterModule(NS)
end
