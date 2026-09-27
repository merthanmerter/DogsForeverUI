-- MODULE: Frames  (DogsForeverUI.Frames, settings section "frames")
--
-- The player, the target, the focus, the target's target and the pet as two
-- plain bars each -- health over power, one border round the pair and a
-- hairline between them -- with the level written before the name. The pet's
-- frame hangs under the player's until it is put somewhere else, and the
-- player's totems hang under the player's frame too (Totems.lua).
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
-- (the target and focus frames shrunk as well) and their mouse turned off, all
-- of which is undone the moment the module is turned off. No Edit Mode setting
-- is read or written, no Blizzard function is replaced, and nothing is
-- reparented - see BlizzardFrames.lua.

DogsForeverUI.Frames = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.Frames

    local PlaceFrames, BuildPlates, onEvent, onUpdate
    local Refresh, ToggleLock, Lock, Unlock

    NS.key = "frames"
    NS.title = "Frames"

    NS.defaults = {
        enabled = true,
        unlocked = false,
        barWidth = 150,
        barHeight = 30,          -- the health bar
        powerHeight = 10,        -- the resource bar under it
        showCastbar = true,      -- what the target and the focus are casting
        castbarHeight = 8,       -- thin: it sits under a plate, not beside it
        textPadding = 0.15,
        showName = true,
        showHealthText = true,
        showPowerText = true,
        showLevel = true,
        showHealPrediction = true,
        classColors = true,
        frameStrata = "MEDIUM",
        styleNamePlates = true,  -- the game's nameplates in this look (NamePlates.lua)
        -- Where each frame's buffs and debuffs go: "below", "above" or "off"
        -- (UnitAuras.lua). The game has none on the target of target.
        targetAuras = "below",
        focusAuras = "below",
        targettargetAuras = "off",
        petAuras = "below",      -- the game's pet frame shows them too
    }

    -- Saved keys that are not settings: where each frame was put.
    NS.placement = {
        playerLeft = true, playerTop = true, playerPlaced = true,
        targetLeft = true, targetTop = true, targetPlaced = true,
        focusLeft = true, focusTop = true, focusPlaced = true,
        targettargetLeft = true, targettargetTop = true, targettargetPlaced = true,
        petLeft = true, petTop = true, petPlaced = true,
    }

    -- SECRET VALUES
    -- This client hands addon code "secret numbers" it may store and pass on but
    -- may not read, compare or do arithmetic with, and health is always one of
    -- them. Nothing here ever inspects a health or power value: they go straight
    -- to SetMinMaxValues, SetValue and SetFormattedText, all of which take a
    -- secret. A unit's class can be secret too, and that one *is* read -- as a
    -- table key -- so it is checked first and a plain colour used instead.

    -- How often the bars are redrawn. The values behind them are secret, so
    -- there is nothing to compare against to know they changed, and this client
    -- has no readable health event to lean on either: the bars are simply
    -- repainted, which is six setter calls and no reads at all.
    local UPDATE_INTERVAL = 0.05
    local sinceUpdate = 0

    NS:RegisterEvent("PLAYER_ENTERING_WORLD")
    NS:RegisterEvent("PLAYER_TARGET_CHANGED")
    pcall(NS.RegisterEvent, NS, "PLAYER_FOCUS_CHANGED")
    -- The cast bars read what is being cast on their own timer; an interrupted
    -- cast is the one thing that cannot be seen that way, because a cast that
    -- ended and a cast that was stopped both simply stop being reported.
    pcall(NS.RegisterUnitEvent, NS, "UNIT_SPELLCAST_INTERRUPTED", "target", "focus")
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
                             "UNIT_DISPLAYPOWER", "UNIT_CLASSIFICATION_CHANGED",
                             "UNIT_TARGET" }) do
        pcall(NS.RegisterEvent, NS, event)
    end
    -- A pet summoned, dismissed or swapped for another. Its argument is the
    -- owner, not the pet.
    pcall(NS.RegisterUnitEvent, NS, "UNIT_PET", "player")
    -- Who leads the group, for the crown over a frame. Neither names a unit.
    for _, event in ipairs({ "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE" }) do
        pcall(NS.RegisterEvent, NS, event)
    end

    NS:SetScript("OnEvent", function(_, event, ...) onEvent(event, ...) end)
    NS:SetScript("OnUpdate", function(_, elapsed) onUpdate(elapsed) end)

    -- First start, and after a reset.
    function NS.Init()
        BuildPlates()
        Refresh()
    end

    -- A first run, or a reset, leaves the frames without a position.
    function NS.Normalise(db)
        if db.playerLeft == nil or db.playerTop == nil
           or db.targetLeft == nil or db.targetTop == nil
           or db.petLeft == nil or db.petTop == nil then
            PlaceFrames()
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
    end

    -- Default placement: one row across the lower part of the screen. The focus
    -- and the player sit left of the middle, the target and its target right of
    -- it, with the clear middle between them for the castbar and the countdown.
    --
    -- The row's top edge is a share of the screen's height, so it lands in the
    -- same place at any resolution and UI scale: 70% of the way down, which the
    -- player chose (-840 on a UI 1200 units tall - 2560x1440 at a UI scale of
    -- 1.2). A default, and nothing more: no frame here moves to follow another
    -- bar at runtime.
    local ROW_TOP         = 0.70   -- share of the screen height, from the top
    local CENTRE_GAP      = 140    -- clear space each side of the middle
    local SIDE_GAP        = 8      -- between a frame and the one beside it
    local PET_GAP         = 6      -- the player's border to the pet's name band

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

        if screenWidth <= 0 or screenHeight <= 0 then
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

        NS.PlacePet()
    end

    -- THE PET, by default right under the player's frame and lined up with its
    -- left edge, its name band clear of the player's border - where the game
    -- hangs its own pet frame. Worked out from wherever the player's frame is
    -- now, so until the pet is put somewhere itself it goes with the player's
    -- frame, dragged, typed or resized: Refresh asks again every time.
    function NS.PlacePet()
        local db = NS.db
        if db.petPlaced or db.playerLeft == nil or db.playerTop == nil then return end
        local height = (db.barHeight or NS.defaults.barHeight) + 1
            + (db.powerHeight or NS.defaults.powerHeight)
        db.petLeft = db.playerLeft
        db.petTop = db.playerTop - height - DogsForeverUI.Style.BORDER_INSET - PET_GAP
            - NS.UnitPlate.TopRoom() * NS.UnitPlate.SMALL_SCALE
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

        if not NS.db.enabled or not NS.plates then return end

        if event == "PLAYER_TARGET_CHANGED" then
            -- The target's target goes with it.
            NS.plates.target:Update()
            NS.plates.targettarget:Update()
            -- And the game's own frames are told again to stay out of it. Its
            -- cast bar in particular decides afresh whether to appear, and the
            -- game puts that switch back itself on a CVar change.
            NS.BlizzardFrames.Refresh()
        elseif event == "PLAYER_FOCUS_CHANGED" then
            NS.plates.focus:Update()
            NS.BlizzardFrames.Refresh()
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            local unit = ...
            for _, plate in pairs(NS.plates) do
                if plate.unit == unit and plate.castbar then
                    plate.castbar:Interrupted()
                end
            end
        elseif event == "UNIT_TARGET" then
            -- Whose target changed. The only one drawn here is the target's.
            if ... == "target" then NS.plates.targettarget:Update() end
        elseif event == "UNIT_PET" then
            -- A new pet can arrive between two looks of the unit watch, with
            -- no hide and show in between to repaint the plate.
            NS.plates.pet:Update()
        elseif event == "PARTY_LEADER_CHANGED" or event == "GROUP_ROSTER_UPDATE" then
            for _, plate in pairs(NS.plates) do plate:Update() end
        else
            -- A unit event: (unit, ...). Only the units drawn here matter.
            local unit = ...
            for _, plate in pairs(NS.plates) do
                if plate.unit == unit then plate:Update() end
            end
        end
    end

    -- The bars are repainted on a timer rather than per event: their values are
    -- secret, so there is nothing to compare to know one moved.
    function onUpdate(elapsed)
        if not NS.plates then return end

        -- The cast bars are an animation: a bar that creeps forward twenty
        -- times a second reads as stuttering, so they are drawn every frame,
        -- which is what the game does with its own. It is a read and four
        -- setter calls, and only while something is casting.
        for _, plate in pairs(NS.plates) do
            if plate.castbar then plate.castbar:OnUpdate() end
        end

        sinceUpdate = sinceUpdate + (elapsed or 0)
        if sinceUpdate < UPDATE_INTERVAL then return end

        local step = sinceUpdate
        sinceUpdate = 0

        for _, plate in pairs(NS.plates) do plate:OnUpdate(step) end
    end

    -------------------------------------------------------------------------
    -- Settings changed.
    -------------------------------------------------------------------------

    function Refresh()
        -- The pet goes with the player's frame until it is placed itself.
        NS.PlacePet()

        -- The plates may not exist yet - a /reload in the middle of a fight
        -- leaves them until it ends - but the game's frames are not waiting on
        -- them, so that half happens either way.
        if NS.plates then
            for _, plate in pairs(NS.plates) do plate:Refresh() end
        end

        NS.BlizzardFrames.Refresh()
        NS.UnitAuras.Refresh()
        NS.Totems.Refresh()
        NS.NamePlates.Refresh()
    end

    function ToggleLock()
        if NS.db.unlocked then Lock() else Unlock() end
    end

    -- Placement turns the frames' click actions off, which means writing secure
    -- attributes, which the game refuses in combat. So does moving them, which
    -- is not something to be doing mid-fight anyway.
    function Unlock()
        if InCombatLockdown() then
            DogsForeverUI.Print("the frames cannot be unlocked in combat.")
            return
        end

        NS.db.unlocked = true
        Refresh()
    end

    function Lock()
        if InCombatLockdown() then
            DogsForeverUI.Print("the frames cannot be locked in combat.")
            return
        end

        NS.db.unlocked = false
        Refresh()
    end

    NS.Refresh = Refresh
    NS.Lock = Lock
    NS.Unlock = Unlock
    NS.ToggleLock = ToggleLock

    DogsForeverUI:RegisterModule(NS)
end
