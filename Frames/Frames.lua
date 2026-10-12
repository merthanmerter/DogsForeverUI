-- MODULE: Frames  (DogsForeverUI.Frames, settings section "frames")
--
-- The player, the target, the focus, the target's target, the pet and the
-- party as two plain bars each -- health over power, one border round the pair
-- and a hairline between them -- with the level written before the name. The
-- pet's frame hangs under the player's until it is put somewhere else, and the
-- player's totems hang under the player's frame too (Totems.lua). The party's
-- four are a column down the left of the screen, placed as one, in either of
-- the game's party styles, each member's pet a box on their left; the game's raid frames keep their own, drawn with
-- this addon's bar textures (RaidFrames.lua).
--
-- Only the look changes. Left-click targets, right-click opens the unit menu and
-- hovering shows the tooltip, exactly as the game's frames do, because the click
-- surface is a real SecureUnitButton with the game's own attributes on it. The
-- heals on their way to a unit are shaded in on its health bar -- see the
-- incoming-heal note in UnitPlate.lua, which draws them without ever adding
-- anything up.
--
-- What the target and the focus are casting is drawn onto their plates, because
-- the frame that used to draw it is not on screen any more -- see
-- UnitCastbar.lua.
--
-- The buffs and debuffs are rows of the client's own aura container, which the
-- game fills itself - an addon cannot read a hostile unit's auras, and these
-- never do - each put below, above or nowhere by a setting of its own. See
-- UnitAuras.lua.
--
-- The game's frames are not destroyed to make room: their artwork is faded out
-- (the target and focus frames shrunk as well) and their mouse turned off. No Edit Mode setting
-- is read or written, no Blizzard function is replaced, and only the party's
-- frame is reparented - see BlizzardFrames.lua.

DogsForeverUI.Frames = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.Frames

    local PlaceFrames, BuildPlates, onEvent, onUpdate
    local Refresh, Lock, Unlock

    NS.key = "frames"
    NS.title = "Frames"

    -- Always on, like everything the addon draws (the player, 2026-09-29: "if
    -- the addon is installed all its features should be enabled"): no
    -- switch for the frames themselves, the name, the level, the incoming
    -- heals or the nameplates' look. Turning the addon off in the addon list is how the
    -- game's own come back.
    NS.defaults = {
        unlocked = false,
        barWidth = 150,
        barHeight = 30,          -- the health bar
        powerHeight = 10,        -- the resource bar under it
        showCastbar = true,      -- what the target and the focus are casting
        castbarHeight = 8,       -- thin: it sits under a plate, not beside it
        textPadding = 0.15,
        showHealthText = true,
        showPowerText = true,
        classColors = true,
        frameStrata = "MEDIUM",
        -- The party's four frames (UnitPlate.lua, THE PARTY): a size and
        -- layer of their own. Their health bar 40 to start (the player,
        -- 2026-10-03) - kept under the name it had while the compact style
        -- was a switch, so a height set then stays.
        partyWidth = 120,
        partyRaidHealth = 40,
        partyPower = 8,
        partyStrata = "MEDIUM",
        -- The column's order, the game's three (UnitPlate.lua, SORTING THE
        -- COLUMN): "role" (tank on top), "group" or "alphabetical"; and the
        -- player's own frame in it (SHOW SELF), on to start (the player,
        -- 2026-10-03: "Show self should be on by default").
        partySort = "role",
        partyShowSelf = true,
        -- The members' pets, a box left of each frame (PartyPets.lua).
        partyShowPets = true,
        -- Where each frame's buffs and debuffs go: "below", "above" or "off"
        -- (UnitAuras.lua). The game has none on the target of target.
        targetAuras = "below",
        focusAuras = "below",
        targettargetAuras = "off",
        petAuras = "below",      -- the game's pet frame shows them too
        partyAuras = "right",    -- beside each party frame: "right" or "off"
        -- The party frames' dispel marks on the player frame too: the type
        -- icons and the wash (UnitAuras.lua, PLAYER_DISPEL).
        playerDispel = true,
        -- How many of the addon's defaults for the game's nameplate options
        -- have been set, each once (NamePlates.lua, DEFAULTS). `true` from
        -- before they were counted is the first.
        nameplateDefaults = 0,
    }

    -- Saved keys that are not settings: where each frame was put.
    NS.placement = {
        playerLeft = true, playerTop = true, playerPlaced = true,
        targetLeft = true, targetTop = true, targetPlaced = true,
        focusLeft = true, focusTop = true, focusPlaced = true,
        targettargetLeft = true, targettargetTop = true, targettargetPlaced = true,
        petLeft = true, petTop = true, petPlaced = true,
        -- The party's column, party1's top left; the others hang under it.
        partyLeft = true, partyTop = true, partyPlaced = true,
    }

    -- SECRET VALUES
    -- This client hands addon code "secret numbers" it may store and pass on but
    -- may not read, compare or do arithmetic with, and health is always one of
    -- them. Nothing here ever inspects a health or power value: they go straight
    -- to SetMinMaxValues, SetValue and SetFormattedText, all of which take a
    -- secret. A unit's class can be secret too, and that one *is* read -- as a
    -- table key -- so it is checked first and a plain colour used instead.

    -- THE TIMER, awake only while it has work, every frame: a cast bar on
    -- screen, and every plate on screen (UnitPlate.lua, WHAT MOVES THE BARS).
    -- Asleep otherwise - the module frame hidden, its events still coming -
    -- and woken by any of them, a plate shown, a refresh, or placing.
    local castbars = {}          -- the target's and the focus's, once built

    NS:RegisterEvent("PLAYER_ENTERING_WORLD")
    NS:RegisterEvent("PLAYER_TARGET_CHANGED")
    pcall(NS.RegisterEvent, NS, "PLAYER_FOCUS_CHANGED")
    -- The cast bars read what is being cast on their own timer; an interrupted
    -- cast is the one thing that cannot be seen that way, because a cast that
    -- ended and a cast that was stopped both simply stop being reported.
    pcall(NS.RegisterUnitEvent, NS, "UNIT_SPELLCAST_INTERRUPTED", "target", "focus")
    -- A cast starting: the bar shows it, and is drawn every frame from then
    -- (see onUpdate). A cast already going is read on a target or focus change.
    local CAST_STARTS = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true,
                          UNIT_SPELLCAST_EMPOWER_START = true }
    for event in pairs(CAST_STARTS) do
        pcall(NS.RegisterUnitEvent, NS, event, "target", "focus")
    end
    -- Leaving combat is when anything that was refused in combat is done.
    NS:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- A layout change re-applies the game's frames' sizes, and two of those are
    -- held retired (faded and shrunk, their aura rows replaced by the addon's).
    -- The hooks on their sizing catch most of it; this is the backstop.
    pcall(NS.RegisterEvent, NS, "EDIT_MODE_LAYOUTS_UPDATED")
    -- What a plate shows besides its bars: who the unit is, what level it is and
    -- what colour it should be. A client without one of these must not lose the
    -- others.
    for _, event in ipairs({ "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION",
                             "UNIT_DISPLAYPOWER", "UNIT_CLASSIFICATION_CHANGED" }) do
        pcall(NS.RegisterEvent, NS, event)
    end
    -- Whose target changed: only the target's is drawn here (its target).
    pcall(NS.RegisterUnitEvent, NS, "UNIT_TARGET", "target")
    -- A pet summoned, dismissed or swapped for another - the player's or a
    -- party member's. Its argument is the owner, not the pet.
    pcall(NS.RegisterEvent, NS, "UNIT_PET")
    -- Who leads the group, for the crown over a frame. Neither names a unit.
    -- And the party's roles (the icon after a member's level).
    for _, event in ipairs({ "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED" }) do
        pcall(NS.RegisterEvent, NS, event)
    end
    -- Resting starting or ending, for the "Zzz" over the player's level.
    pcall(NS.RegisterEvent, NS, "PLAYER_UPDATE_RESTING")
    -- The game's Target of Target switch, which the target's target follows.
    NS:RegisterEvent("CVAR_UPDATE")

    NS:SetScript("OnEvent", function(_, event, ...)
        NS:Show()
        onEvent(event, ...)
    end)
    NS:SetScript("OnUpdate", function() onUpdate() end)
    DogsForeverUI.WatchPlacing(function() NS:Show() end)

    -- First start, and after a reset.
    function NS.Init()
        BuildPlates()
        Refresh()
    end

    -- A first run, or a reset - of everything, or of one frame's place in
    -- Edit Mode (Core\Snap.lua) - leaves a frame without a position.
    function NS.Normalise(db)
        for _, unit in ipairs({ "player", "target", "focus", "targettarget", "pet", "party" }) do
            if db[unit .. "Left"] == nil or db[unit .. "Top"] == nil then
                PlaceFrames()
                return
            end
        end
    end

    -- The plates are built once, and only out of combat: each one owns a secure
    -- click button, and anchoring a protected frame is refused while the player
    -- is fighting. A /reload in the middle of a fight is the one case that gets
    -- here in combat, and it is answered by waiting for the end of it.
    function BuildPlates()
        if NS.plates or InCombatLockdown() then return end

        -- The target's target and the pet are drawn smaller, as the game draws
        -- them. The target's target is the one unit with no event worth the
        -- name behind it - see its plate.
        NS.plates = {
            player = NS.UnitPlate.New("player", "Player"),
            target = NS.UnitPlate.New("target", "Target"),
            focus = NS.UnitPlate.New("focus", "Focus"),
            targettarget = NS.UnitPlate.New("targettarget", "TargetOfTarget",
                NS.UnitPlate.SMALL_SCALE),
            pet = NS.UnitPlate.New("pet", "Pet", NS.UnitPlate.SMALL_SCALE),
        }
        -- The party: the target frame's design, a little smaller, in a column.
        for index = 1, 4 do
            local unit = "party" .. index
            NS.plates[unit] = NS.UnitPlate.New(unit, "Party" .. index, NS.UnitPlate.PARTY_SCALE)
        end
        -- And the player's own, for Show self (UnitPlate.lua, SHOW SELF).
        NS.plates.partyplayer = NS.UnitPlate.New("player", "PartyPlayer", NS.UnitPlate.PARTY_SCALE, 0)
        -- The members' pets, a box left of each (PartyPets.lua).
        for index = 1, 4 do NS.plates["partypet" .. index] = NS.PartyPets.New(index) end
        -- Their column laid out by secure code too, so it can close up in combat.
        NS.UnitPlate.BuildColumn()
        castbars[1], castbars[2] = NS.plates.target.castbar, NS.plates.focus.castbar
        -- (The target's target appearing: its beat starts.)
        NS.plates.targettarget:HookScript("OnShow", function() NS:Show() end)
    end

    -- Default placement: one row across the lower part of the screen. The focus
    -- and the player sit left of the middle, the target and its target right of
    -- it, with the clear middle between them for the castbar and the countdown.
    --
    -- The row's top edge is a share of the screen's height, so it lands in the
    -- same place at any resolution and UI scale: 75% of the way down, which the
    -- player chose (-900 on a UI 1200 units tall - 2560x1440 at a UI scale of
    -- 1.2; it was 70%, -840, until 2026-10-01). A default, and nothing more:
    -- no frame here moves to follow another bar at runtime.
    local ROW_TOP         = 0.75   -- share of the screen height, from the top
    local CENTRE_GAP      = 140    -- clear space each side of the middle
    local SIDE_GAP        = 8      -- between a frame and the one beside it
    local PET_GAP         = 6      -- the player's border to the pet's name band
    -- The party's column: against the left edge of the screen - just its
    -- border's width in, so the border is not cut off - and centred top to
    -- bottom (the player asked). See NS.PlaceParty.
    local PARTY_EDGE      = DogsForeverUI.Style.BORDER_INSET + 1

    -- The top of that row, as a TOPLEFT offset from the top of the screen.
    local function RowTop(screenHeight)
        return -screenHeight * ROW_TOP
    end

    -- A frame the player has put somewhere is never moved by the addon again -
    -- that is what the `<unit>Placed` keys mark - so this only ever writes to a
    -- frame still sitting where the addon put it, and can be called again once
    -- the screen size is final.
    function PlaceFrames()
        local db = NS.db
        local screenWidth = GetScreenWidth() or 0
        local screenHeight = GetScreenHeight() or 0

        local places = {}
        local guessing = screenWidth <= 0 or screenHeight <= 0

        if guessing then
            -- Screen size not known yet: any number beats leaving them unplaced.
            places.player = { 300, -400 }
            places.target = { 700, -400 }
            places.focus = { 100, -400 }
            places.targettarget = { 900, -400 }
        else
            local width = db.barWidth or NS.defaults.barWidth
            local middle = screenWidth / 2
            local top = RowTop(screenHeight)

            -- The room a plate's badge takes up on its side, so the frame
            -- beyond it does not land on top of the badge.
            local side = NS.UnitPlate.SideRoom() + SIDE_GAP

            places.player = { middle - CENTRE_GAP - width, top }
            places.target = { middle + CENTRE_GAP, top }
            -- Outside those two, past each one's badge: focus on the left,
            -- target-of-target on the right.
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

    -- THE PARTY'S COLUMN, by default against the left edge and centred top to
    -- bottom: the whole column as Unlock Mode boxes it - the border over the
    -- first frame's name row down to the last frame's border - with exactly
    -- as much screen above it as below (the player, 2026-10-03: "exactly Y
    -- centered"; the top border was left out until then, so the column sat
    -- half a border high). Worked out from the party frames' size, so until
    -- the column is put somewhere by the player it stays centred when that
    -- changes: Refresh asks again every time.
    function NS.PartyColumn(db)
        local UnitPlate = NS.UnitPlate
        local _, health, power = UnitPlate.Size(db, { partyIndex = 1 })
        local nameRow = UnitPlate.PartyTopRoom()
        local inset = DogsForeverUI.Style.BORDER_INSET
        -- (Above the first frame's top: its name row and the border over it.)
        local above = nameRow + inset
        -- Four frames, five with the player's own (Show self).
        local frames = db.partyShowSelf and UnitPlate.PARTY_SIZE or 4
        return above + (frames - 1) * UnitPlate.PartyStep(db) + health + 1 + power + inset, above
    end

    function NS.PlaceParty()
        local db = NS.db
        if db.partyPlaced then return end
        local screenHeight = GetScreenHeight() or 0
        if screenHeight <= 0 then screenHeight = 768 end
        local column, above = NS.PartyColumn(db)
        db.partyLeft = PARTY_EDGE
        db.partyTop = -(screenHeight - column) / 2 - above
    end

    -- THE PET, by default right under the player's frame and lined up with its
    -- left edge, its name band clear of the player's border - where the game
    -- hangs its own pet frame. Worked out ONCE, from where the player's frame
    -- is then - on a first start, or Reset To Default Position (which clears
    -- the pet's place) - and from then on it stays where it is: it never
    -- moves with the player's frame (the player, 2026-10-02: nothing moves
    -- with anything unless anchored to it on purpose, in Edit Mode). Only a
    -- place worked out before the screen's size was known is worked out again
    -- (`again`, PlaceFrames).
    local petFromGuess = false   -- worked out from the player's place when the screen was unknown

    function NS.PlacePet(again, guessing)
        local db = NS.db
        if db.petPlaced or db.playerLeft == nil or db.playerTop == nil then return end
        if db.petLeft ~= nil and db.petTop ~= nil and not (again and petFromGuess) then return end
        local height = (db.barHeight or NS.defaults.barHeight) + 1
            + (db.powerHeight or NS.defaults.powerHeight)
        db.petLeft = db.playerLeft
        db.petTop = db.playerTop - height - DogsForeverUI.Style.BORDER_INSET - PET_GAP
            - NS.UnitPlate.TopRoom() * NS.UnitPlate.SMALL_SCALE
        petFromGuess = guessing and true or false
    end

    function onEvent(event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            -- UIParent is unscaled at ADDON_LOADED, so a position worked out
            -- there lands in the wrong coordinate space. PlaceFrames only writes
            -- to a frame the player has not put somewhere themselves.
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
            -- Whatever combat refused: building the plates after a /reload in a
            -- fight, and handing the game's frames their mouse back.
            BuildPlates()
            Refresh()
            return
        end

        if not NS.plates then return end

        if event == "PLAYER_TARGET_CHANGED" then
            -- The target's target goes with it.
            NS.plates.target:Update()
            NS.plates.targettarget:Update()
            -- And the game's own frames, which it sets up afresh for the new
            -- unit, are faded and retired again (BlizzardFrames.lua).
            NS.BlizzardFrames.Refresh()
        elseif event == "PLAYER_FOCUS_CHANGED" then
            NS.plates.focus:Update()
            NS.BlizzardFrames.Refresh()
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            local plate = NS.plates[...]
            if plate and plate.castbar then plate.castbar:Interrupted() end
        elseif CAST_STARTS[event] then
            local plate = NS.plates[...]
            if plate and plate.castbar then plate.castbar:OnUpdate() end
        elseif event == "UNIT_TARGET" then
            -- The target's (the only one registered): its target goes with it.
            if ... == "target" then NS.plates.targettarget:Update() end
        elseif event == "CVAR_UPDATE" then
            NS.plates.targettarget:Update()
        elseif event == "PLAYER_UPDATE_RESTING" then
            NS.plates.player:Update()
        elseif event == "UNIT_PET" then
            -- A new pet can arrive between two looks of the unit watch, with
            -- no hide and show in between to repaint the plate.
            local owner = ...
            local index = type(owner) == "string" and owner:match("^party(%d)$")
            local plate = owner == "player" and NS.plates.pet or index and NS.plates["partypet" .. index]
            if plate then plate:Update() end
        elseif event == "PARTY_LEADER_CHANGED" or event == "GROUP_ROSTER_UPDATE"
               or event == "PLAYER_ROLES_ASSIGNED" then
            -- Someone joined or left, or a role was given: the column sorted
            -- again (in combat, as combat ends).
            if event ~= "PARTY_LEADER_CHANGED" and NS.UnitPlate.SortParty(NS.db) then Refresh() end
            for _, plate in pairs(NS.plates) do plate:Update() end
        else
            -- A unit event: (unit, ...). Only the units drawn here matter.
            local unit = ...
            -- (A member's name arriving after they joined: sorted by it.)
            if type(unit) ~= "string" then return end
            if event == "UNIT_NAME_UPDATE" and unit:match("^party%d$")
                and NS.UnitPlate.SortParty(NS.db) then Refresh() end
            -- Each plate is keyed by its unit, but for the player's own frame
            -- in the party's column (SHOW SELF).
            local plate = NS.plates[unit]
            if plate then plate:Update() end
            if unit == "player" then NS.plates.partyplayer:Update() end
        end
    end

    function onUpdate()
        if not NS.plates then return end
        local busy = false

        -- The cast bars are an animation: one on screen is drawn every frame,
        -- which is what the game does with its own.
        for index = 1, #castbars do
            local castbar = castbars[index]
            if castbar.bar:IsShown() then
                castbar:OnUpdate()
                busy = true
            end
        end

        -- Every plate on screen, every frame (UnitPlate.lua, WHAT MOVES THE
        -- BARS).
        for _, plate in pairs(NS.plates) do
            if plate:IsShown() then
                plate:OnUpdate()
                busy = true
            end
        end

        if not busy then NS:Hide() end
    end

    -------------------------------------------------------------------------
    -- Settings changed.
    -------------------------------------------------------------------------

    function Refresh()
        -- The pet's default place, if it has none yet (worked out once); the
        -- party's column stays centred on the screen at its size until it is
        -- placed.
        NS.PlacePet()
        NS.PlaceParty()

        -- The plates may not exist yet - a /reload in the middle of a fight
        -- leaves them until it ends - but the game's frames are not waiting on
        -- them, so that half happens either way.
        if NS.plates then
            -- The party's order first: each frame's place in the column.
            NS.UnitPlate.SortParty(NS.db)
            for _, plate in pairs(NS.plates) do plate:Refresh() end
        end

        NS.BlizzardFrames.Refresh()
        NS.UnitAuras.Refresh()
        NS.Totems.Refresh()
        NS.NamePlates.Refresh()
        NS:Show()
    end

    -- In combat too, as the game's Edit Mode works in combat. What the game
    -- refuses then - the click actions (secure attributes), showing and
    -- hiding the plates, their place and size - Refresh skips (every one of
    -- those calls is behind an InCombatLockdown check in UnitPlate.lua and
    -- BlizzardFrames.lua), and PLAYER_REGEN_ENABLED's Refresh does the moment
    -- combat ends. Everything else - the look, the names, the bars - at once.
    function Unlock()
        NS.db.unlocked = true
        Refresh()
    end

    function Lock()
        NS.db.unlocked = false
        Refresh()
    end

    NS.Refresh = Refresh
    NS.Lock = Lock
    NS.Unlock = Unlock

    DogsForeverUI:RegisterModule(NS)
end
