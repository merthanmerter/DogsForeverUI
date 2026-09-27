-- The auto-attack swing bars: main hand, off hand and ranged.
--
-- WHERE THE TIMING COMES FROM
-- The client has an official swing timer API, C_SwingTimer, and the game's own
-- swing bars (Blizzard_SwingTimer) are built on nothing else. PLAYER_SWING
-- arrives the moment a hand swings, carrying the time until its next swing and
-- which hand it was, so there is nothing to work out: no combat log - which
-- addons do not get on this client anyway - no attack speed arithmetic, no
-- guessing at parries. The bar runs from the swing to the next one.
--
-- Range comes from the same place. C_SwingTimer.EnableRangeCheck asks for
-- PLAYER_SWING_RANGE_UPDATE whenever the target moves in or out of reach, and
-- IsTargetWithinSwingRange answers on the spot when the target changes. A bar
-- out of range is dimmed and its text turned red, with the game's own numbers.
--
-- WHAT THEY LOOK LIKE
-- Exactly like the castbar above them, in the addon's one look: the same width
-- and height, border, background, fonts, fill and spark. What differs is the
-- colour: grey, as the game's swing timer is (Style.SWING_COLOR).
-- Every size comes from the castbar's own settings, so the two can never drift
-- apart.
--
-- WHEN THEY ARE ON SCREEN
-- While that hand is swinging, and not otherwise - the castbar's rule, not the
-- game's. The game's own bars sit on screen empty at 0.0 all day by default;
-- an empty bar when nothing is happening is clutter, so these come up on a
-- swing and go when the swinging stops.
--
-- Not the instant a timer runs out, though. The next PLAYER_SWING lands a few
-- milliseconds after the last timer ends, and hiding at exactly zero made a
-- bar blink off and on between every swing. So an emptied bar holds, reading
-- 0.0, for IDLE_HOLD: a swing that arrives in that time carries straight on,
-- and one that does not - the player stopped attacking, or the target walked
-- out of reach - lets it go.
--
-- WHERE THEY ARE
-- Stacked above the castbar - ranged, off hand, main hand, top to bottom, so
-- the main hand is nearest the castbar - with the same daylight between each
-- as between the castbar and the five-second-rule bar. A hand that is not swinging gives up its row,
-- so the stack always sits snug against the castbar. Until they are dragged
-- they are anchored to the castbar itself, so they go wherever it goes; once
-- dragged, they stay where they were put.

local SwingBars = {}
DogsForeverUI.Castbar.SwingBars = SwingBars

do -- private scope

    local NS = DogsForeverUI.Castbar
    local Style = DogsForeverUI.Style
    local IsSecret = issecretvalue

    -- Every function here is called with a dot. Several take arguments, and a
    -- colon would hand them the module table instead - see the note in
    -- CastBar.lua.

    -- The castbar group's gap between two bars (see Castbar.lua).
    local STACK_GAP = NS.STACK_GAP

    -- Blizzard_SwingTimer.lua's own value for a target out of reach.
    local OUT_OF_RANGE_ALPHA = 0.4

    -- How long an emptied bar stays up waiting for the next swing. Long enough
    -- to cover the event arriving late, short enough that a bar does not hang
    -- about once the swinging has stopped.
    local IDLE_HOLD = 1.0

    local PLACEMENT_LABEL = Style.PLACEMENT_LABEL

    -- Enum.PlayerSwingType, with its documented values behind it so a client
    -- without the table still loads.
    local SwingType = (type(Enum) == "table" and type(Enum.PlayerSwingType) == "table")
        and Enum.PlayerSwingType or { MainHand = 0, OffHand = 1, Ranged = 2 }

    local function Label(global, fallback)
        return type(global) == "string" and global or fallback
    end

    -- Top to bottom, as the game shows them. The labels are the game's own
    -- strings - the ones its bars wear.
    local HANDS = {
        { swingType = SwingType.MainHand,
          label = Label(SWING_TIMER_MAIN_HAND, "Main Hand"),
          colour = Style.SWING_COLOR.mainhand },
        { swingType = SwingType.OffHand,
          label = Label(SWING_TIMER_OFF_HAND, "Off Hand"),
          colour = Style.SWING_COLOR.offhand },
        { swingType = SwingType.Ranged,
          label = Label(SWING_TIMER_RANGED, "Ranged"),
          colour = Style.SWING_COLOR.ranged },
    }

    local function Options()
        return DogsForeverUI.Castbar.db
    end

    ---------------------------------------------------------------------------
    -- The frames.
    ---------------------------------------------------------------------------

    -- One frame holding all three, so they are placed, dragged and saved as one.
    local group = CreateFrame("Frame", "DogsForeverUISwingBars", UIParent)

    local bars = {}
    local byType = {}

    local onMouseDown, onMouseUp

    for index, hand in ipairs(HANDS) do
        local bar = CreateFrame("StatusBar", nil, group)
        bar.hand = hand

        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints(true)

        bar.border = Style.AddBorder(bar)

        bar.typeText = bar:CreateFontString(nil, "OVERLAY")
        bar.timeText = bar:CreateFontString(nil, "OVERLAY")

        -- The drag belongs to the group: pick up any bar and all three move.
        bar:SetScript("OnMouseDown", function(_, button) onMouseDown(button) end)
        bar:SetScript("OnMouseUp", function(_, button) onMouseUp(button) end)

        bars[index] = bar
        byType[hand.swingType] = bar
    end

    ---------------------------------------------------------------------------
    -- What can swing.
    ---------------------------------------------------------------------------

    -- The main hand always can. The other two can when UnitAttackSpeed reports
    -- a speed for them, which is exactly the test the game's own bars make.
    --
    -- UnitAttackSpeed is SecretWhenUnitStatsRestricted. For the player that is
    -- not expected to happen, but a secret may not even be compared, so it is
    -- asked first - and a speed that cannot be read is taken to be one, since
    -- a bar that shows and never fills costs less than one that is missing.
    local function CanSwing(hand)
        if hand.swingType == SwingType.MainHand then return true end

        local _, offHand, ranged = UnitAttackSpeed("player")
        -- An if, not `a and b or c`: an empty off hand reports nil, and the
        -- idiom would fall straight through to the ranged speed and show an
        -- off-hand bar for anybody carrying a bow.
        local speed
        if hand.swingType == SwingType.OffHand then
            speed = offHand
        else
            speed = ranged
        end

        if IsSecret(speed) then return true end
        return speed ~= nil and speed > 0
    end

    -- Swinging, or just emptied and waiting for the next swing.
    local function IsBusy(bar)
        return bar.endTime ~= nil or bar.idleUntil ~= nil
    end

    -- Whether the swing bars are on at all: Swing timers, their own switch.
    -- The castbar's switch (Castbar) is the castbar's alone - the player asked
    -- to turn each bar of the group on and off by itself.
    local function Active()
        local db = Options()
        return db and db.showSwing and true or false
    end

    local function ShouldShow(bar)
        local db = Options()
        if not Active() then return false end
        if db.unlocked then return true end
        return CanSwing(bar.hand) and IsBusy(bar)
    end

    ---------------------------------------------------------------------------
    -- Drawing.
    ---------------------------------------------------------------------------

    local function Paint(bar)
        Style.Paint(bar, bar.hand.colour)
    end

    local function TextColour(bar)
        if bar.outOfRange and not Options().unlocked then
            if RED_FONT_COLOR and RED_FONT_COLOR.GetRGB then
                return RED_FONT_COLOR:GetRGB()
            end
            return 1, 0.125, 0.125
        end
        local colour = Style.TEXT_COLOR
        return colour[1], colour[2], colour[3]
    end

    -- Dimmed and red while the target is out of reach, as the game does it.
    -- Placement mode suppresses it, again as the game does in Edit Mode.
    local function ApplyRange(bar)
        local dim = bar.outOfRange and not Options().unlocked
        bar:SetAlpha(dim and OUT_OF_RANGE_ALPHA or 1)

        local r, g, b = TextColour(bar)
        bar.typeText:SetTextColor(r, g, b)
        bar.timeText:SetTextColor(r, g, b)
    end

    -- Everything that follows a setting: size, fill, background, fonts and
    -- spark. Every one of them is the castbar's own setting.
    local function Restyle(bar)
        local db = Options()

        bar:SetSize(db.barWidth, db.barHeight)
        Paint(bar)
        Style.SetBackground(bar.bg, db.unlocked)

        for _, label in ipairs({ bar.typeText, bar.timeText }) do
            label:ClearAllPoints()
            Style.SingleLine(label)
        end

        bar.typeText:SetJustifyH("LEFT")
        bar.typeText:SetPoint("LEFT", bar, "LEFT", 4, 0)
        bar.typeText:SetPoint("RIGHT", bar.timeText, "LEFT", -6, 0)
        bar.timeText:SetJustifyH("RIGHT")
        bar.timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)

        Style.SetFont(bar, bar.typeText, db.textPadding)
        Style.SetFont(bar, bar.timeText, db.textPadding)

        if not bar.spark then bar.spark = Style.AddSpark(bar) end
        bar.spark:SetHeight(db.barHeight * Style.SPARK_HEIGHT)
        if not bar.endTime then bar.spark:Hide() end

        ApplyRange(bar)
    end

    -- An empty bar at 0.0: what the game's bars show between swings.
    local function ShowIdle(bar)
        local db = Options()
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        bar.typeText:SetText(bar.hand.label)
        bar.timeText:SetText(db.unlocked and PLACEMENT_LABEL or "0.0")
        if bar.spark then bar.spark:Hide() end
    end

    local function Clear(bar)
        bar.duration, bar.endTime = nil, nil
        ShowIdle(bar)
    end

    ---------------------------------------------------------------------------
    -- Placement.
    ---------------------------------------------------------------------------

    -- The visible bars, stacked from the bottom of the group upwards so the
    -- stack always sits snug against whatever is under it: main hand at the
    -- bottom, then off hand, then ranged. A hand with nothing to swing gives up
    -- its row.
    --
    -- Bars fade in and out, as every castbar does (Style.FadeIn/FadeOut). A bar
    -- on its way out keeps its row until it has faded - `leaving` - so the one
    -- above does not slide over it; OnUpdate lays the stack out again when it
    -- is gone. `settled` is a settings change - switched off, placed, locked
    -- again - and then bars go or come at once rather than fading.
    local function Layout(settled)
        local db = Options()
        local height = db.barHeight
        local instant = settled or not Active() or db.unlocked

        local shown = {}
        for _, bar in ipairs(bars) do
            if ShouldShow(bar) then
                shown[#shown + 1] = bar
                bar.leaving = nil
                if instant then Style.ShowNow(bar) else Style.FadeIn(bar) end
            elseif instant or not bar:IsShown() then
                bar.leaving = nil
                Style.HideNow(bar)
            else
                shown[#shown + 1] = bar
                bar.leaving = true
                Style.FadeOut(bar)
            end
        end

        local below
        for index = 1, #shown do
            local bar = shown[index]
            bar:ClearAllPoints()
            if below then
                bar:SetPoint("BOTTOMLEFT", below, "TOPLEFT", 0, STACK_GAP)
            else
                bar:SetPoint("BOTTOMLEFT", group, "BOTTOMLEFT", 0, 0)
            end
            below = bar
        end

        local count = math.max(1, #shown)
        group:SetSize(db.barWidth, count * height + (count - 1) * STACK_GAP)

        group:ClearAllPoints()
        if db.swingPlaced and db.swingLeft and db.swingBottom then
            group:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.swingLeft, db.swingBottom)
        else
            -- Not placed by the player yet: at the top of the castbar group,
            -- over the countdown and combo points' row when this character
            -- keeps one, with the same daylight as everything else in the
            -- stack, and following the castbar wherever it is put.
            local above = STACK_GAP
            if NS.RowInUse() then above = above + db.barHeight + STACK_GAP end
            group:SetPoint("BOTTOMLEFT", NS.CastBar.castbar, "TOPLEFT", 0, above)
        end
    end

    function onMouseDown(button)
        if button == "LeftButton" and Options().unlocked then
            group:StartMoving()
        end
    end

    -- A right-click locks the castbar and these with it, as on the castbar.
    function onMouseUp(button)
        if DogsForeverUI.RightClickLock(DogsForeverUI.Castbar, button) then return end
        if button ~= "LeftButton" or not Options().unlocked then return end

        group:StopMovingOrSizing()

        -- The player's position from here on, and never recomputed. Only the
        -- position is written, for the same reason as on the castbar.
        local db = Options()
        db.swingLeft = group:GetLeft()
        db.swingBottom = group:GetBottom()
        db.swingPlaced = true

        SwingBars.Refresh()
    end

    ---------------------------------------------------------------------------
    -- Range.
    ---------------------------------------------------------------------------

    local function SetOutOfRange(bar, outOfRange)
        bar.outOfRange = outOfRange and true or false
        ApplyRange(bar)
    end

    -- Ask for range events on every hand that can swing, and ask where the
    -- target is right now. Asked again whenever anything changes rather than
    -- once: the game's own bars switch the same range check on and off, and a
    -- request made once could be undone by them.
    --
    -- Nil from IsTargetWithinSwingRange is "no check could be made" - no
    -- target, nothing to hit it with - and the documentation is explicit that
    -- it must not be treated as out of range.
    local function UpdateRange()
        local api = C_SwingTimer
        for _, bar in ipairs(bars) do
            local hand = bar.hand
            local outOfRange = false

            if type(api) == "table" and Active() and CanSwing(hand) then
                if type(api.EnableRangeCheck) == "function" then
                    pcall(api.EnableRangeCheck, hand.swingType, true)
                end
                if type(api.IsTargetWithinSwingRange) == "function" then
                    local ok, inRange = pcall(api.IsTargetWithinSwingRange, hand.swingType)
                    if ok and not IsSecret(inRange) and inRange == false then
                        outOfRange = true
                    end
                end
            end

            SetOutOfRange(bar, outOfRange)
        end
    end

    ---------------------------------------------------------------------------
    -- Swinging.
    ---------------------------------------------------------------------------

    -- A hand has swung: its bar starts again from empty and runs for as long as
    -- the game says the next swing is away. A duration that cannot be read, or
    -- is not a real length, leaves the bar alone - the game's bars do the same.
    local function OnSwing(duration, swingType)
        if IsSecret(swingType) then return end
        local bar = byType[swingType]
        local db = Options()
        if not bar or not Active() or db.unlocked or not CanSwing(bar.hand) then
            return
        end

        if IsSecret(duration) or type(duration) ~= "number" or duration <= 0 then
            return
        end

        bar.duration = duration
        bar.endTime = GetTime() + duration
        bar.idleUntil = nil

        -- Coming up from nothing, or from fading out: it needs a row in the
        -- stack and to fade back in. A bar that was already up - swinging, or
        -- holding between swings - keeps the one it has, so steady swinging
        -- never re-lays anything.
        if not bar:IsShown() or bar.leaving then Layout() end

        bar:SetMinMaxValues(0, duration)
        bar:SetValue(0)
        bar.timeText:SetText(string.format("%.1f", duration))
        if bar.spark then bar.spark:Show() end
    end

    ---------------------------------------------------------------------------
    -- Called by the core file.
    ---------------------------------------------------------------------------

    function SwingBars.Refresh()
        local db = Options()
        if not db then return end

        group:SetFrameStrata(db.frameStrata or "MEDIUM")
        group:SetMovable(true)
        -- After SetMovable: SetUserPlaced errors on a frame that is neither
        -- movable nor resizable. Cleared so the client's layout cache never
        -- wins over the position this addon saved.
        group:SetUserPlaced(false)
        group:SetClampedToScreen(true)

        for _, bar in ipairs(bars) do
            bar:EnableMouse(db.unlocked and true or false)
            Restyle(bar)
        end

        Layout(true)
        UpdateRange()

        for _, bar in ipairs(bars) do
            if db.unlocked or not bar.endTime then ShowIdle(bar) end
        end

        if Active() then group:Show() else group:Hide() end
    end

    -- Drawn every frame, as the castbar is: a bar that creeps forward on a
    -- slower beat reads as stuttering.
    function SwingBars.OnUpdate()
        local db = Options()
        if not db or not Active() or db.unlocked then return end

        local now = GetTime()
        local relayout = false

        for _, bar in ipairs(bars) do
            local endTime, duration = bar.endTime, bar.duration
            if endTime then
                local remaining = endTime - now
                if remaining <= 0 then
                    -- Empty, and held for the next swing rather than hidden.
                    Clear(bar)
                    bar.idleUntil = now + IDLE_HOLD
                else
                    local elapsed = duration - remaining
                    bar:SetValue(elapsed)
                    bar.timeText:SetText(string.format("%.1f", remaining))
                    if bar.spark then
                        bar.spark:SetPoint("CENTER", bar, "LEFT",
                            db.barWidth * (elapsed / duration), 0)
                    end
                end
            elseif bar.idleUntil and now >= bar.idleUntil then
                -- No swing came: the swinging has stopped, so the bar fades out
                -- and the stack closes up round whatever is left once it has.
                bar.idleUntil = nil
                relayout = true
            end

            -- Faded out - whatever took it away, even mid-swing: its row goes
            -- now.
            if bar.leaving and not bar:IsShown() then
                bar.leaving = nil
                relayout = true
            end
        end

        if relayout then Layout() end
    end

    -- True when the event was one of these, so the core can stop looking.
    function SwingBars.OnEvent(event, ...)
        if event == "PLAYER_SWING" then
            OnSwing(...)
        elseif event == "PLAYER_SWING_RANGE_UPDATE" then
            local swingType, isInRange, checksRange = ...
            if IsSecret(swingType) or IsSecret(isInRange) or IsSecret(checksRange) then
                return true
            end
            local bar = byType[swingType]
            if bar then SetOutOfRange(bar, checksRange and not isInRange) end
        elseif event == "PLAYER_TARGET_CHANGED" then
            UpdateRange()
        elseif event == "WEAPON_SLOT_CHANGED" or event == "UNIT_ATTACK_SPEED" then
            -- A hand has gained or lost something to swing with.
            Layout()
            UpdateRange()
        else
            return false
        end
        return true
    end

    -- Expose Field Variables and Functions
    SwingBars.group = group
    SwingBars.bars = bars
    SwingBars.STACK_GAP = STACK_GAP
end
