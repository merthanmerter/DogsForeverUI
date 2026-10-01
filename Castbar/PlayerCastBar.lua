-- The casting bar.
--
-- Drawn in the addon's one look (Core\Style.lua): the flat fill with its sheen,
-- in the castbar colours, the black background, the rounded gold
-- border, gold labels and the spark.
--
-- The bar is on screen while a cast or a channel is running and for the moment
-- after one fails, and at no other time, fading in and out rather than
-- appearing and vanishing. To see where it sits, unlock it.

local CastBar = {}
DogsForeverUI.Castbar.CastBar = CastBar

do -- private scope

    -- Private to this file: these names are shared by every addon when left
    -- global.
    local Refresh, Begin, Finish, OnUpdate, Lock, Unlock, ShowPlacementPreview
    local onMouseDown, onMouseUp, Colour, Paint, Hide

    local Style = DogsForeverUI.Style
    local castbar = CreateFrame("StatusBar", "DogsForeverUICastBar", UIParent)
    -- Off screen from the start: it only ever fades in for a cast.
    castbar:Hide()
    castbar:SetMovable(true)
    castbar:SetScript("OnMouseDown", function(_, button) onMouseDown(button) end)
    castbar:SetScript("OnMouseUp", function(_, button) onMouseUp(button) end)

    local PLACEMENT_NAME = "Castbar"   -- what it says it is while being placed

    local function Options()
        return DogsForeverUI.Castbar.db
    end

    -- WHAT THE BAR IS WEARING: the palette's colour for each state
    -- (Style.CAST_COLOR) - casting, channelling, uninterruptible, failed.

    -- Which of them the bar is in right now.
    function Colour()
        if DogsForeverUI.Castbar.holdFailed then return "failed" end

        local cast = DogsForeverUI.Castbar.cast
        if cast.notInterruptible then
            return "uninterruptible"
        elseif cast.channel then
            return "channel"
        end

        return "casting"
    end

    -- The fill is set in three places, so it is worth one function.
    function Paint()
        Style.Paint(castbar, Style.CAST_COLOR[Colour()])
    end

    function Refresh()
        local db = Options()

        -- POSITION, SIZE
        castbar:ClearAllPoints()
        castbar:SetFrameStrata(db.frameStrata or "MEDIUM")
        castbar:SetWidth(db.barWidth)
        castbar:SetHeight(db.barHeight)
        castbar:SetPoint("TOPLEFT", db.barLeft, db.barTop)

        -- The client caches named, user-placed frames in layout-local.txt and
        -- restores them at login, after this addon has already positioned the
        -- bar from its own saved settings. StartMoving sets that flag on every
        -- drag, so clear it here -- the position saved by onMouseUp is the one
        -- that should win. Has to come after SetMovable: SetUserPlaced errors on
        -- a frame that is neither movable nor resizable.
        castbar:SetUserPlaced(false)
        -- Clickable only while being placed: the drag is the only thing a click
        -- on this bar does.
        castbar:EnableMouse(db.unlocked and true or false)
        castbar:SetClampedToScreen(true)

        -- FOREGROUND, in the colour of whichever state the bar is in.
        Paint()

        -- BORDER
        if not castbar.border then castbar.border = Style.AddBorder(castbar) end

        -- BACKGROUND: plain black while the bar is being placed.
        if not castbar.bg then
            castbar.bg = castbar:CreateTexture(nil, "BACKGROUND")
        end
        castbar.bg:SetAllPoints(true)
        Style.SetBackground(castbar.bg, db.unlocked)

        -- TEXT
        -- Two labels rather than one: the spell on the left, the time left on
        -- the right, which is where the game puts them.
        if not castbar.spellText then
            castbar.spellText = castbar:CreateFontString(nil, "OVERLAY")
        end
        if not castbar.timeText then
            castbar.timeText = castbar:CreateFontString(nil, "OVERLAY")
        end

        for _, label in ipairs({ castbar.spellText, castbar.timeText }) do
            label:ClearAllPoints()
            Style.SingleLine(label)
        end

        -- The same two places whether casting or being placed: then the bar's
        -- name sits where the spell's does, and the time's is empty.
        castbar.spellText:SetJustifyH("LEFT")
        castbar.spellText:SetPoint("LEFT", castbar, "LEFT", 4, 0)
        -- The spell name gives way to the timer rather than running under it.
        -- This second point is also what gives the name a width to be
        -- truncated against.
        castbar.spellText:SetPoint("RIGHT", castbar.timeText, "LEFT", -6, 0)

        castbar.timeText:SetJustifyH("RIGHT")
        castbar.timeText:SetPoint("RIGHT", castbar, "RIGHT", -4, 0)

        Style.SetFont(castbar, castbar.spellText, db.textPadding)
        Style.SetFont(castbar, castbar.timeText, db.textPadding)

        -- SPARK: always there, on every bar the addon draws.
        if not castbar.spark then castbar.spark = Style.AddSpark(castbar) end
        castbar.spark:SetHeight(db.barHeight * Style.SPARK_HEIGHT)

        -- VISIBILITY
        -- Settings can change at any moment, including while nothing is casting,
        -- so this settles the between-casts state rather than waiting for the
        -- next OnUpdate to do it.
        if db.unlocked then
            ShowPlacementPreview()
        elseif not DogsForeverUI.Castbar.cast.active then
            OnUpdate()
        end
    end

    -- A cast has started: everything about it that does not change while it runs.
    function Begin()
        local db = Options()
        if db.unlocked then return end

        local cast = DogsForeverUI.Castbar.cast
        Paint()

        -- Never nil (BeginCast), and possibly a secret, which may not be tested.
        castbar.spellText:SetText(cast.name)

        if castbar.spark then
            -- Only a bar whose progress can be measured has somewhere to put it.
            if cast.plain then
                castbar.spark:Show()
            else
                castbar.spark:Hide()
            end
        end

        -- Where the cast is now, before the bar is seen: shown first, it drew
        -- one frame of wherever the last cast ended - nearly full - and then
        -- jumped back to the start.
        OnUpdate()
        if cast.active then Style.FadeIn(castbar) end
    end

    -- The cast ended. A cast that simply finished is gone at once - the game
    -- shows an empty bar at zero for a moment and it reads as a bar that is
    -- stuck. A cast that failed is filled and repainted, and OnUpdate clears it
    -- when the hold runs out.
    --
    -- Every function here takes no arguments and reads what it needs off the
    -- namespace, as the countdown bar does. They are all called
    -- with a colon, so a parameter would silently receive the module table.
    function Finish()
        local db = Options()
        if db.unlocked then return end

        if not DogsForeverUI.Castbar.holdFailed then
            Hide()
            return
        end

        Paint()
        -- Full, so the colour reads as a bar rather than a sliver.
        castbar:SetMinMaxValues(0, 1)
        castbar:SetValue(1)
        castbar.timeText:SetText("")
        if castbar.spark then castbar.spark:Hide() end
        Style.FadeIn(castbar)
    end

    function OnUpdate()
        local db = Options()

        if db.unlocked then
            ShowPlacementPreview()
            return
        end

        local cast = DogsForeverUI.Castbar.cast

        if not cast.active then
            -- A failed cast is held for a moment; everything else is gone.
            local holdUntil = DogsForeverUI.Castbar.holdUntil or 0
            if holdUntil > 0 and GetTime() < holdUntil then return end
            Hide()
            return
        end

        if not cast.plain then
            -- The times could not be read. They can still be handed straight to
            -- the bar, which fills correctly without this addon ever seeing
            -- them -- but a channel cannot be made to drain and no text or spark
            -- can be placed, because all three need arithmetic. The cast then
            -- ends on its event alone.
            castbar:SetMinMaxValues(cast.startTime, cast.endTime)
            castbar:SetValue(GetTime() * 1000)
            castbar.timeText:SetText("")
            return
        end

        local length = cast.endTime - cast.startTime
        local elapsed = GetTime() - cast.startTime

        -- Done. The stop event is on its way and usually arrives in the same
        -- frame, but the bar is not kept on screen waiting for it: a bar sitting
        -- at 0.0 - or, if the last frame landed just short, at 0.1 - is what a
        -- stuck bar looks like.
        if length <= 0 or elapsed >= length then
            DogsForeverUI.Castbar.EndCast(false)
            return
        end

        -- A cast fills up; a channel drains away.
        local value = cast.channel and (length - elapsed) or elapsed

        castbar:SetMinMaxValues(0, length)
        castbar:SetValue(value)

        castbar.timeText:SetFormattedText("%.1f", length - elapsed)

        if castbar.spark then
            castbar.spark:SetPoint("CENTER", castbar, "LEFT",
                db.barWidth * (value / length), 0)
        end
    end

    -- Gone by fading out, not at once (Style.FadeOut); called every frame
    -- between casts, which only carries the fade on.
    function Hide()
        Style.FadeOut(castbar)
    end

    function Lock()
        -- Back to whatever the bar shows when it is not being placed, which with
        -- nothing casting is nothing at all - at once: the placement preview is
        -- put away, not faded out like a finished cast.
        if not DogsForeverUI.Castbar.cast.active then Style.HideNow(castbar) end
        OnUpdate()
    end

    function Unlock()
        -- Clickable for the drag. Refresh runs straight after this and sets the
        -- same thing from the setting, so this is only to cover the gap.
        castbar:EnableMouse(true)
        ShowPlacementPreview()
    end

    -- What the bar shows while it is being placed, as every bar here does: an
    -- empty bar, so the striped black background and the outline give the
    -- exact footprint, and its name.
    function ShowPlacementPreview()
        Style.ShowNow(castbar)
        castbar:SetMinMaxValues(0, 1)
        castbar:SetValue(0)
        castbar.spellText:SetText(PLACEMENT_NAME)
        castbar.timeText:SetText("")
        if castbar.spark then castbar.spark:Hide() end
    end

    -- Dragging, and a right-click to lock it again once it is placed. There is
    -- no right-click to unlock: placement is turned on with the button in the
    -- options, which is the only way to it now that the bar is not on screen
    -- to be clicked most of the time.
    function onMouseDown(button)
        if button == "LeftButton" and Options().unlocked then
            castbar:StartMoving()
        end
    end

    function onMouseUp(button)
        if DogsForeverUI.RightClickLock(DogsForeverUI.Castbar, button) then return end
        if button ~= "LeftButton" then return end

        castbar:StopMovingOrSizing()

        -- A dragged position is the player's, and is never recomputed by the
        -- addon.
        --
        -- Only the position is written. Dragging cannot resize this bar -
        -- StartMoving is the only thing onMouseDown calls, and StartSizing is
        -- never called at all - so reading the width and height back here
        -- changed nothing except to round them: a size set to exactly 100 came
        -- back as 100.0000305175781 and was saved that way, creeping a little
        -- further on every drag and quietly overwriting a size typed into the
        -- options panel.
        local db = Options()
        db.autoPlaced = false
        db.barLeft = castbar:GetLeft()
        db.barTop = -1 * (GetScreenHeight() - castbar:GetTop())

        Refresh()

        DogsForeverUI.RefreshOptions()
    end

    -- Expose Field Variables and Functions
    CastBar.castbar = castbar
    CastBar.Refresh = Refresh
    CastBar.Begin = Begin
    CastBar.Finish = Finish
    CastBar.OnUpdate = OnUpdate
    CastBar.Lock = Lock
    CastBar.Unlock = Unlock
end
