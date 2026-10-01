-- MODULE: Castbar  (DogsForeverUI.Castbar, settings section "castbar")
--
-- A casting bar of the addon's own, which replaces the game's rather than
-- editing it. The game's bar is hidden -- see BlizzardCastbar.lua, which never
-- writes an Edit Mode setting and never replaces a Blizzard function.
--
-- The bar draws casts and channels, and nothing else. There is no global
-- cooldown bar: drawing one means deciding whether a cooldown is running, that
-- decision is a boolean, and in combat every boolean on that path is a secret
-- value that addon code may not test. The game's action buttons already run the
-- swipe.
--
-- Above it sit the auto-attack swing bars - main hand, off hand and ranged -
-- which replace the game's own swing timer the same way: styled exactly like
-- the castbar, driven by the client's official C_SwingTimer events, and with
-- the game's bars faded out while the module is on. See SwingBars.lua and
-- BlizzardSwingTimer.lua.
--
-- Between the two, in one row, sit the five-second countdown (FiveSecondRule\)
-- and the combo points (ComboPoints\), which are part of the same group: the
-- same size and look from this module's settings, placed and locked with it,
-- and shown in the options' Castbars section. See RowInUse for the order.

DogsForeverUI.Castbar = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.Castbar

    local CenterBar, onEvent, onUpdate
    local BeginCast, EndCast, ReadCast, EventIsOurs, Refresh
    local ToggleLock, Lock, Unlock

    NS.key = "castbar"
    NS.title = "Castbars"

    -- The castbar, its spell name, the swing bars, the five-second countdown
    -- and the combo points are always on - no switches (the player,
    -- 2026-09-29). What is left to set is the group's size, layer and place.
    NS.defaults = {
        unlocked = false,
        barWidth = 130,
        barHeight = 20,
        textPadding = 0.15,       -- every bar of the group's
        frameStrata = "MEDIUM",
        -- The swing bars' own size and layer, as a group (the player,
        -- 2026-09-29: "all castbars managed individually"). They took the
        -- castbar's until then; `swingSized` says the castbar's were copied
        -- over once, so nobody's bars change size on the way.
        swingWidth = 130,
        swingHeight = 20,
        swingStrata = "MEDIUM",
        swingSized = false,
    }

    -- How long a cast that failed stays up in its own colour, in seconds.
    -- A setting once; fixed since 2026-09-29.
    NS.FAILED_HOLD = 0.6

    -- Saved keys that are not settings: the bar's placement, and the swing
    -- bars' once the player has dragged them. Until then they are anchored to
    -- the castbar and have no position of their own.
    NS.placement = {
        barLeft = true, barTop = true, autoPlaced = true,
        swingLeft = true, swingBottom = true, swingPlaced = true,
    }

    -- SECRET VALUES
    -- This client hands addon code "secret numbers" it may store and pass on but
    -- may not read, compare or do arithmetic with. Cast times are normally plain,
    -- but nothing here assumes it: when they come back secret the bar is still
    -- driven correctly, because SetMinMaxValues and SetValue accept a secret,
    -- and only the parts that genuinely need arithmetic -- the remaining-seconds
    -- text, the spark's position and the drain direction of a channel -- step
    -- aside. See `cast.plain`.
    local IsSecret = issecretvalue

    -- THE CAST IN PROGRESS
    -- Times are kept in whatever form they arrived: seconds when they could be
    -- read, raw milliseconds when they could not.
    local cast = {
        active = false,
        channel = false,
        plain = false,
        startTime = 0,
        endTime = 0,
        name = nil,
        castID = nil,
        notInterruptible = false,
    }
    NS.cast = cast

    -- A cast that failed stays on screen, in its own colour, long enough to be
    -- read. A cast that simply finished does not: it is gone the moment it is
    -- done. Zero means nothing is being held.
    --
    -- Both live on the namespace because CastBar reads them: every function
    -- there takes no arguments, since they are all called with a colon and a
    -- parameter would silently receive the module table instead.
    NS.holdUntil = 0
    NS.holdFailed = false

    -- Only the player's own casts, so the client filters for us rather than this
    -- module waking for every cast in the zone.
    local CAST_EVENTS = {
        "UNIT_SPELLCAST_START",
        "UNIT_SPELLCAST_STOP",
        "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_FAILED_QUIET",
        "UNIT_SPELLCAST_INTERRUPTED",
        "UNIT_SPELLCAST_DELAYED",
        "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_UPDATE",
        "UNIT_SPELLCAST_CHANNEL_STOP",
        "UNIT_SPELLCAST_INTERRUPTIBLE",
        "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    }
    for _, event in ipairs(CAST_EVENTS) do
        -- A client without one of these must not lose the other ten.
        pcall(NS.RegisterUnitEvent, NS, event, "player")
    end

    -- The swing bars. PLAYER_SWING carries the time to the next swing and which
    -- hand swung; the rest say that a hand gained or lost something to swing
    -- with, or that the target moved in or out of reach. Each one on its own,
    -- for the same reason as above.
    for _, event in ipairs({ "PLAYER_SWING", "PLAYER_SWING_RANGE_UPDATE",
                             "PLAYER_TARGET_CHANGED", "WEAPON_SLOT_CHANGED" }) do
        pcall(NS.RegisterEvent, NS, event)
    end
    pcall(NS.RegisterUnitEvent, NS, "UNIT_ATTACK_SPEED", "player")
    NS:RegisterEvent("PLAYER_ENTERING_WORLD")

    NS:SetScript("OnEvent", function(_, event, ...) onEvent(event, ...) end)
    NS:SetScript("OnUpdate", function() onUpdate() end)

    -- First start, and after a reset.
    function NS.Init()
        Refresh()
    end

    -- A first run, or a reset, leaves the bar without a position. Settings
    -- from before the swing bars had a size of their own give them the
    -- castbar's, once.
    function NS.Normalise(db)
        if db.barLeft == nil or db.barTop == nil then CenterBar() end
        if not db.swingSized then
            db.swingWidth, db.swingHeight = db.barWidth, db.barHeight
            db.swingStrata = db.frameStrata
            db.swingSized = true
        end
    end

    -- Where a bar of the group that has not been placed on its own goes: in
    -- the group, centred over the castbar, `above` its top edge, and
    -- following it wherever it is put. Answers the TOPLEFT for the Positions
    -- boxes, worked out from the castbar's settings rather than measured.
    function NS.OverCastbar(width, height, above)
        local db = NS.db
        local left = (db.barLeft or 0) + ((db.barWidth or 0) - width) / 2
        local top = (db.barTop or 0) + above + height
        return left, top
    end

    -- A width that keeps a bar centred where it was, for a bar placed on its
    -- own (one still in the group is centred over the castbar anyway).
    function NS.KeepCentred(db, placedKey, leftKey)
        return function(old, new)
            if type(old) == "number" and type(new) == "number" and db()[placedKey]
               and db()[leftKey] then
                db()[leftKey] = db()[leftKey] + (old - new) / 2
            end
        end
    end

    -- Default placement: centred horizontally, its top edge about 64% of the
    -- way down the screen - the whole group, since the swing bars and the
    -- countdown hang off this bar. Where the player put it: first 65% (about
    -- 20 below the old -756 on their UI 1200 units tall), then 10 higher -
    -- 770 of their 1200. A share of the screen rather than a pixel count, so
    -- it lands in the same place at any resolution or UI scale.
    local TOP_SHARE       = 770 / 1200

    -- The daylight between two bars of the group, and what it takes to get it.
    -- Every bar draws its border on a frame three pixels *outside* itself, so a
    -- gap measured between the bars is six pixels smaller on screen than it
    -- reads here: at four, the two borders overlapped by two.
    local BORDER_INSET    = DogsForeverUI.Style.BORDER_INSET
    local VISIBLE_GAP     = 6      -- daylight between the two borders
    local STACK_GAP       = VISIBLE_GAP + 2 * BORDER_INSET
    NS.STACK_GAP = STACK_GAP

    -- THE GROUP, bottom to top: the castbar; one row for the five-second
    -- countdown and the combo points, which share it because nobody needs
    -- both - a rogue has no mana; then the swing bars, main hand, off hand,
    -- ranged, bottom to top. The row is kept only for a character with something to put in
    -- it: a warrior has neither, and gets the swing bars straight on the
    -- castbar.
    function NS.RowInUse()
        return NS.RowHeight() > 0
    end

    -- How tall the countdown and combo points' row over the castbar is: the
    -- taller of whichever of them this character has and has left in the
    -- row (one placed elsewhere takes no room there); 0 for none.
    function NS.RowHeight()
        local height = 0
        local fsr, combo = DogsForeverUI.FiveSecondRule, DogsForeverUI.ComboPoints
        if fsr and fsr.db and fsr.ClassHasMana() and not fsr.db.placed then
            height = math.max(height, fsr.db.barHeight or 0)
        end
        if combo and combo.db and combo.ClassUses() and not combo.db.placed then
            height = math.max(height, combo.db.barHeight or 0)
        end
        return height
    end

    -- A new width keeps the castbar where it was centred: it grows or shrinks
    -- by half on each side rather than out to the right. The bars still in
    -- the group are centred over it, so they stay centred too.
    function NS.WidthChanged(old, new)
        if type(old) ~= "number" or type(new) ~= "number" then return end
        local db = NS.db
        if db.barLeft then db.barLeft = db.barLeft + (old - new) / 2 end
    end

    function CenterBar()
        local db = NS.db
        local screenWidth = GetScreenWidth() or 0
        local screenHeight = GetScreenHeight() or 0

        if screenWidth <= 0 or screenHeight <= 0 then
            -- Screen size not known yet: any number beats leaving it unplaced.
            db.barLeft = 90
            db.barTop = -68
            return
        end

        local width = db.barWidth or NS.defaults.barWidth

        db.barLeft = (screenWidth - width) / 2
        db.barTop = -screenHeight * TOP_SHARE

        -- Still the addon's placement rather than the player's, so it may be
        -- recomputed once the screen size is final. Dragging the bar clears it.
        db.autoPlaced = true
    end

    -------------------------------------------------------------------------
    -- Reading the cast in progress.
    --
    -- Asked of the game rather than pieced together from event arguments: the
    -- event says *that* something changed, and these two say what the state now
    -- is, including the new end time after a pushback.
    -------------------------------------------------------------------------

    -- The last value is the text to show: the cast's display text, as the
    -- game's own castbar shows it (CastingBarMixin: self.Text:SetText(text)),
    -- not its name. The name only says that something is being cast; for the
    -- spells behind picking up a quest item or using an object it is a
    -- placeholder, "No Text", and the display text says what is happening.
    function ReadCast()
        local name, text, _, startMS, endMS, _, castID, notInterruptible = UnitCastingInfo("player")
        if name then
            return name, startMS, endMS, notInterruptible, false, castID, text
        end

        -- Channels report the same values without the cast ID, so the
        -- not-interruptible flag sits one place earlier.
        local cname, ctext, _, cstartMS, cendMS, _, cnotInterruptible = UnitChannelInfo("player")
        if cname then
            return cname, cstartMS, cendMS, cnotInterruptible, true, nil, ctext
        end
    end

    -- Whether a stop, failure or interruption is about the cast on the bar.
    --
    -- It very often is not. Pressing a second spell while one is casting - a
    -- queued instant, a second swing at a skinning node - makes the game refuse
    -- the new one, and that refusal arrives as UNIT_SPELLCAST_FAILED for the
    -- player like any other. Taking it at face value turned the bar red while
    -- the cast underneath it carried on quite happily, which is exactly what it
    -- looked like: a bug.
    --
    -- The game's own castbar compares cast IDs, and so does this when it can.
    -- They are secret values on a unit whose casting is restricted, and a secret
    -- may not be compared, so there is a second test that needs no reading at
    -- all: the game clears the cast the instant it really ends, so a cast still
    -- in progress means the event belongs to something else.
    --
    -- Note the order: whether a value is secret is asked *before* anything is
    -- compared to it, even to nil, because comparing a secret is itself the
    -- error this is trying to avoid.
    function EventIsOurs(eventCastID)
        local mine = cast.castID
        if not (IsSecret(mine) or IsSecret(eventCastID))
           and mine ~= nil and eventCastID ~= nil then
            return mine == eventCastID
        end

        return ReadCast() == nil
    end

    function BeginCast()
        local name, startMS, endMS, notInterruptible, channel, castID, text = ReadCast()
        if not name then
            EndCast(false)
            return
        end

        cast.active = true
        cast.channel = channel
        -- What the bar says. A secret text is passed on as it is; a missing
        -- one leaves the bar without a name rather than with a placeholder.
        if IsSecret(text) or type(text) == "string" then cast.name = text else cast.name = "" end
        cast.castID = castID
        cast.notInterruptible = notInterruptible and true or false

        -- Milliseconds as the game reports them. Converted to seconds only when
        -- they can be read at all; left untouched when they cannot, so they can
        -- still be handed to the bar.
        cast.plain = not (IsSecret(startMS) or IsSecret(endMS))
        if cast.plain then
            cast.startTime = startMS / 1000
            cast.endTime = endMS / 1000
        else
            cast.startTime = startMS
            cast.endTime = endMS
        end

        NS.holdUntil = 0
        NS.holdFailed = false

        NS.CastBar:Begin()
    end

    -- `failed` distinguishes a cast that was interrupted or refused from one
    -- that simply finished. A finished cast is gone at once; a failed one is
    -- held in its own colour for long enough to be read.
    function EndCast(failed)
        if not cast.active then return end

        cast.active = false
        cast.castID = nil
        NS.holdFailed = failed and true or false

        local hold = failed and NS.FAILED_HOLD or 0
        NS.holdUntil = hold > 0 and (GetTime() + hold) or 0

        NS.CastBar:Finish()
    end
    NS.EndCast = EndCast

    function onEvent(event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            -- UIParent is unscaled at ADDON_LOADED, so a centred position worked
            -- out there lands in the wrong coordinate space. Only an
            -- addon-chosen position is recomputed here, never a dragged one.
            if NS.db.autoPlaced then CenterBar() end
            Refresh()
            return
        end

        -- The swing bars take theirs first.
        if NS.SwingBars.OnEvent(event, ...) then return end

        -- (unit, castGUID, spellID, ...) on every cast event this module takes.
        local _, castID, _, interruptedBy = ...

        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
           or event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
            -- Delay and channel-update are pushbacks and ticks: the cast carries
            -- on, with new times, which is exactly what re-reading gives.
            BeginCast()

        elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET"
               or event == "UNIT_SPELLCAST_INTERRUPTED" then
            -- A channel has no cast ID to be named in, and the game reports its
            -- interruption as CHANNEL_STOP instead, so these never belong to one.
            if not cast.channel and EventIsOurs(castID) then EndCast(true) end

        elseif event == "UNIT_SPELLCAST_STOP" then
            if EventIsOurs(castID) then EndCast(false) end

        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            -- The fourth argument names whoever interrupted it, and is nil when
            -- the channel simply ran its course. Asked secret-first, as above:
            -- a name that cannot be read is still a name, so it was interrupted.
            EndCast(IsSecret(interruptedBy) or interruptedBy ~= nil)

        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
            cast.notInterruptible = false
            NS.CastBar:Refresh()

        elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            cast.notInterruptible = true
            NS.CastBar:Refresh()
        end
    end

    function onUpdate()
        NS.CastBar:OnUpdate()
        NS.SwingBars.OnUpdate()
    end

    -------------------------------------------------------------------------
    -- Settings changed.
    -------------------------------------------------------------------------

    function Refresh()
        NS.CastBar:Refresh()
        NS.BlizzardCastbar.Refresh()
        -- After the castbar: the swing bars are anchored to it until dragged.
        NS.SwingBars.Refresh()
        NS.BlizzardSwingTimer.Refresh()
        -- And the row over it - the countdown and the combo points - which
        -- takes its size, its look and its placement mode from this module.
        for _, module in ipairs({ DogsForeverUI.FiveSecondRule, DogsForeverUI.ComboPoints }) do
            if module and module.db and module.Redraw then module.Redraw() end
        end
    end

    -- The bar is off screen except while something is casting, so placement is
    -- turned on with the button in the options rather than by clicking a bar
    -- that is not there.
    function ToggleLock()
        if NS.db.unlocked then Lock() else Unlock() end
    end

    function Unlock()
        NS.db.unlocked = true
        NS.CastBar:Unlock()
        Refresh()
    end

    function Lock()
        NS.db.unlocked = false
        NS.CastBar:Lock()
        Refresh()
    end

    NS.Refresh = Refresh
    NS.Lock = Lock
    NS.Unlock = Unlock
    NS.ToggleLock = ToggleLock

    DogsForeverUI:RegisterModule(NS)
end
