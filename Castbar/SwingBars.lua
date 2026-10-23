-- The castbar group's swing bars - main hand, off hand, ranged - in place of
-- the game's swing timer (faded, below). Timed by the client's C_SwingTimer
-- events alone; up while a hand swings, then held empty for IDLE_HOLD so the
-- next swing carries straight on. Stacked bottom to top, snug.

local SwingBars = {}
DogsForeverUI.Castbar.SwingBars = SwingBars

-- WoW Forever's alone: retail has no swing timer (Blizzard_SwingTimer is
-- camelot's). Nothing is made there - no bars, no piece to place - and the
-- castbar is answered as if no hand ever swung.
if DogsForeverUI.RETAIL then
    local function None() return false end
    SwingBars.Refresh, SwingBars.OnUpdate, SwingBars.OnEvent, SwingBars.Busy = None, None, None, None
    return
end

do -- private scope
    local NS = DogsForeverUI.Castbar
    local Style = DogsForeverUI.Style
    local Core = DogsForeverUI
    local IsSecret = issecretvalue

    local STACK_GAP = NS.STACK_GAP
    local OUT_OF_RANGE_ALPHA = 0.4           -- Blizzard_SwingTimer's
    local IDLE_HOLD = 1.0                    -- an emptied bar waits this long for the next swing
    local GAME_CVAR = "showSwingTimer"       -- the game's switch: off there, off here
    local SwingType = Enum.PlayerSwingType

    -- One frame holding all three, placed, dragged and saved as one.
    local group = CreateFrame("Frame", "DogsForeverUISwingBars", UIParent)
    group:SetMovable(true)
    group:SetClampedToScreen(true)

    -- In the game's order: the stack's bottom to top.
    local bars, byType = {}, {}
    for index, hand in ipairs({
        { swingType = SwingType.MainHand, label = SWING_TIMER_MAIN_HAND, colour = Style.SWING_COLOR.mainhand },
        { swingType = SwingType.OffHand, label = SWING_TIMER_OFF_HAND, colour = Style.SWING_COLOR.offhand },
        { swingType = SwingType.Ranged, label = SWING_TIMER_RANGED, colour = Style.SWING_COLOR.ranged },
    }) do
        local bar = CreateFrame("StatusBar", nil, group)
        bar.hand = hand
        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints(bar)
        bar.border = Style.AddBorder(bar)
        bar.spark = Style.AddSpark(bar)
        bar.typeText = bar:CreateFontString(nil, "OVERLAY")
        bar.timeText = bar:CreateFontString(nil, "OVERLAY")
        bars[index] = bar
        byType[hand.swingType] = bar
    end

    -- Main hand always; the others while UnitAttackSpeed has a speed for them,
    -- the game's test. A secret speed counts: a bar that never fills beats none.
    local function CanSwing(hand)
        if hand.swingType == SwingType.MainHand then return true end
        local _, offHand, ranged = UnitAttackSpeed("player")
        local speed = ranged
        if hand.swingType == SwingType.OffHand then speed = offHand end
        if IsSecret(speed) then return true end
        return speed ~= nil and speed > 0
    end

    local function GameOn()
        return C_CVar.GetCVar(GAME_CVAR) ~= "0"
    end

    local function ShouldShow(bar)
        if not GameOn() then return false end
        return NS.db.unlocked or CanSwing(bar.hand) and (bar.endTime ~= nil or bar.idleUntil ~= nil)
    end

    -- The 5SR / combo row's height, 0 for a class with neither.
    local function RowHeight()
        local fsr, combo = Core.FiveSecondRule, Core.ComboPoints
        local height = 0
        if fsr.ClassHasMana() then height = fsr.db.barHeight end
        if combo.ClassUses() then height = math.max(height, combo.db.barHeight) end
        return height
    end

    -- Dimmed with red text while out of reach, as the game's; not while placed.
    local function SetOutOfRange(bar, outOfRange)
        bar.outOfRange = outOfRange
        local dim = outOfRange and not NS.db.unlocked
        bar:SetAlpha(dim and OUT_OF_RANGE_ALPHA or 1)
        local c = Style.TEXT_COLOR
        local r, g, b = c[1], c[2], c[3]
        if dim then r, g, b = RED_FONT_COLOR:GetRGB() end
        bar.typeText:SetTextColor(r, g, b)
        bar.timeText:SetTextColor(r, g, b)
    end

    -- Between swings: empty at 0.0, as the game's. Unlocked: full and named.
    local function ShowIdle(bar)
        local unlocked = NS.db.unlocked
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(unlocked and 1 or 0)
        bar.typeText:SetText(bar.hand.label)
        bar.timeText:SetText(unlocked and "" or "0.0")
        bar.spark:Hide()
    end

    -- The bars shown, stacked from the group's bottom. One fading out keeps its
    -- row (`leaving`) until gone; `settled` (a settings change) is at once.
    local shown = {}                         -- Layout's, refilled each time
    local function Layout(settled)
        local db = NS.db
        local instant = settled or db.unlocked
        wipe(shown)
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
        for index, bar in ipairs(shown) do
            bar:ClearAllPoints()
            if index == 1 then
                bar:SetPoint("BOTTOMLEFT", group, "BOTTOMLEFT", 0, 0)
            else
                bar:SetPoint("BOTTOMLEFT", shown[index - 1], "TOPLEFT", 0, STACK_GAP)
            end
        end
        local count = math.max(1, #shown)
        group:SetSize(db.swingWidth, count * db.swingHeight + (count - 1) * STACK_GAP)

        -- By default at the top of the group, over the row when this class has
        -- one, centred over the castbar: worked out once, then kept.
        local above = STACK_GAP
        local row = RowHeight()
        if row > 0 then above = above + row + STACK_GAP end
        if not db.swingPlaced and NS.GroupSettled() then
            local left, top = NS.OverCastbar(db.swingWidth, 0, above)
            db.swingLeft, db.swingBottom = left, GetScreenHeight() + top
            db.swingPlaced = true
        end
        group:ClearAllPoints()
        if db.swingPlaced and db.swingLeft and db.swingBottom then
            group:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.swingLeft, db.swingBottom)
        else
            group:SetPoint("BOTTOM", NS.CastBar.castbar, "TOP", 0, above)
        end
    end

    -- Range events asked for on every hand that can swing, and the target asked
    -- about now - again on every change, as the game's bars switch the check
    -- too. Nil from IsTargetWithinSwingRange is "no check made", not out of range.
    local function UpdateRange()
        for _, bar in ipairs(bars) do
            local outOfRange = false
            if CanSwing(bar.hand) then
                C_SwingTimer.EnableRangeCheck(bar.hand.swingType, true)
                local inRange = C_SwingTimer.IsTargetWithinSwingRange(bar.hand.swingType)
                outOfRange = not IsSecret(inRange) and inRange == false
            end
            SetOutOfRange(bar, outOfRange)
        end
    end

    -- A hand swung: its bar runs from empty until the next swing. A duration
    -- that cannot be read, or is no length, leaves it alone, as the game's.
    local function OnSwing(duration, swingType)
        if IsSecret(swingType) or IsSecret(duration) then return end
        local bar = byType[swingType]
        if not bar or NS.db.unlocked or not CanSwing(bar.hand)
           or type(duration) ~= "number" or duration <= 0 then
            return
        end
        bar.duration, bar.endTime, bar.idleUntil = duration, GetTime() + duration, nil
        -- Coming up, or back from fading: it needs a row. One already up keeps its own.
        if not bar:IsShown() or bar.leaving then Layout() end
        bar:SetMinMaxValues(0, duration)
        bar:SetValue(0)
        bar.timeText:SetFormattedText("%.1f", duration)
        bar.spark:Show()
    end

    -- THE GAME'S SWING BARS are faded, not hidden: they are bottom-managed,
    -- and hiding one re-lays the protected stack from tainted code. Edit Mode's
    -- opacity, the managed container and its animations all write their alpha,
    -- all through SetAlpha: that is followed, and put back to 0.
    local GAME_BARS = { SwingTimerMainHandFrame, SwingTimerOffHandFrame, SwingTimerRangedFrame }
    local holding = false                    -- our own SetAlpha, not answered by the hook
    local function Hold(frame)
        holding = true
        frame:SetAlpha(0)
        holding = false
    end
    for _, frame in ipairs(GAME_BARS) do
        hooksecurefunc(frame, "SetAlpha", function(self)
            if not holding then Hold(self) end
        end)
    end

    function SwingBars.Refresh()
        local db = NS.db
        group:SetFrameStrata(db.swingStrata)
        -- After SetMovable: the client's layout cache never wins over the saved place.
        group:SetUserPlaced(false)
        for _, bar in ipairs(bars) do
            bar:SetSize(db.swingWidth, db.swingHeight)
            bar:EnableMouse(db.unlocked)
            Style.Paint(bar, bar.hand.colour)
            Style.SetBackground(bar.bg)
            -- (SetFont whitens the text; UpdateRange puts the range look back.)
            Style.BarLabels(bar, bar.typeText, bar.timeText, db.textPadding)
            bar.spark:SetHeight(db.swingHeight * Style.SPARK_HEIGHT)
            if db.unlocked or not bar.endTime then ShowIdle(bar) end
        end
        Layout(true)
        UpdateRange()
        -- The game's swing timer off: the whole group away, Unlock Mode's piece too.
        group:SetShown(GameOn())
        for _, frame in ipairs(GAME_BARS) do
            Core.HoldEditMode(frame, true)
            Hold(frame)
        end
    end

    -- Where the group is now, the player's from here on: a drag's end, a
    -- nudge, or following its anchor (Core\Snap.lua).
    local function SavePlace()
        local db = NS.db
        db.swingLeft, db.swingBottom = group:GetLeft(), group:GetBottom()
        db.swingPlaced = true
        SwingBars.Refresh()
    end
    Core.Snap.Register(group, { save = SavePlace, name = "Swing Timers", id = "swing" })
    -- Pick up any bar and all three move.
    for _, bar in ipairs(bars) do Core.Snap.Draggable(bar, NS, SavePlace, group) end

    -- Drawn every frame, as the castbar is.
    function SwingBars.OnUpdate()
        local db = NS.db
        if db.unlocked then return end
        local now, relayout = GetTime(), false
        for _, bar in ipairs(bars) do
            if bar.endTime then
                local remaining = bar.endTime - now
                if remaining <= 0 then
                    -- Empty, and held for the next swing.
                    bar.duration, bar.endTime, bar.idleUntil = nil, nil, now + IDLE_HOLD
                    ShowIdle(bar)
                else
                    local elapsed = bar.duration - remaining
                    bar:SetValue(elapsed)
                    bar.timeText:SetFormattedText("%.1f", remaining)
                    bar.spark:SetPoint("CENTER", bar, "LEFT", db.swingWidth * elapsed / bar.duration, 0)
                end
            elseif bar.idleUntil and now >= bar.idleUntil then
                -- No swing came: it fades out, and the stack closes up once it has.
                bar.idleUntil = nil
                relayout = true
            end
            -- Faded out, whatever took it away: its row goes now.
            if bar.leaving and not bar:IsShown() then
                bar.leaving = nil
                relayout = true
            end
        end
        if relayout then Layout() end
    end

    -- Swinging, holding for the next swing, or fading out of its row.
    function SwingBars.Busy()
        for _, bar in ipairs(bars) do
            if bar.endTime or bar.idleUntil or bar.leaving then return true end
        end
        return false
    end

    -- True when the event was one of these.
    function SwingBars.OnEvent(event, ...)
        if event == "PLAYER_SWING" then
            OnSwing(...)
        elseif event == "PLAYER_SWING_RANGE_UPDATE" then
            local swingType, isInRange, checksRange = ...
            if not (IsSecret(swingType) or IsSecret(isInRange) or IsSecret(checksRange))
               and byType[swingType] then
                SetOutOfRange(byType[swingType], checksRange and not isInRange)
            end
        elseif event == "PLAYER_TARGET_CHANGED" then
            UpdateRange()
        elseif event == "WEAPON_SLOT_CHANGED" or event == "UNIT_ATTACK_SPEED" then
            Layout()          -- a hand gained or lost something to swing with
            UpdateRange()
        elseif event == "CVAR_UPDATE" then
            if ... ~= GAME_CVAR then return false end
            SwingBars.Refresh()
        else
            return false
        end
        return true
    end

    for _, event in ipairs({ "PLAYER_SWING", "PLAYER_SWING_RANGE_UPDATE", "PLAYER_TARGET_CHANGED",
                             "WEAPON_SLOT_CHANGED", "CVAR_UPDATE" }) do
        NS:RegisterEvent(event)
    end
    NS:RegisterUnitEvent("UNIT_ATTACK_SPEED", "player")

    SwingBars.group = group
    SwingBars.bars = bars
end
