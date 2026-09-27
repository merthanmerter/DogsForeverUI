-- The countdown bar.
--
-- One of the castbar group: drawn exactly like the castbar (Core\Style.lua) in
-- the palette's countdown grey, at the castbar's size and strata, with its text
-- padding, spark and seconds settings - all read from the castbar's settings,
-- so the two can never drift apart. It sits just above the castbar, under the
-- swing bars, with the group's daylight between each, and goes wherever the
-- castbar goes - until it is dragged, when it stays where it was put. It is
-- unlocked and locked with the castbar.

local StatusBar = {}
DogsForeverUI.FiveSecondRule.StatusBar = StatusBar

do -- private scope

    local NS = DogsForeverUI.FiveSecondRule
    local Style = DogsForeverUI.Style

    local Refresh, ShowPlacementPreview, OnUpdate
    local onMouseDown, onMouseUp, resetManaGain

    local statusbar = CreateFrame("StatusBar", "DogsForeverUIFiveSecondBar", UIParent)
    statusbar:Hide()   -- off screen until a countdown fades it in
    statusbar:SetMovable(true)
    statusbar:SetScript("OnMouseDown", function(_, button) onMouseDown(button) end)
    statusbar:SetScript("OnMouseUp", function(_, button) onMouseUp(button) end)
    local mp5delay = 5
    local PLACEMENT_NAME = "5SR"   -- what it says it is while being placed

    -- The countdown's own settings: whether it is on, where it sits.
    local function Options()
        return NS.db
    end

    -- The group's: size, look, and whether the group is being placed.
    local function Group()
        return DogsForeverUI.Castbar.db
    end

    -- Whether it has anything to show at all.
    local function Wanted()
        return Options().enabled and not NS.noMana
    end

    function Refresh()
        local db, group = Options(), Group()

        -- POSITION, SIZE
        statusbar:ClearAllPoints()
        statusbar:SetFrameStrata(group.frameStrata or "MEDIUM")

        local unlocked = group.unlocked

        statusbar:SetWidth(group.barWidth)
        statusbar:SetHeight(group.barHeight)
        if db.placed then
            -- Dragged somewhere of its own: it stays there.
            statusbar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.barLeft, db.barTop)
        else
            -- Its row, shared with the combo points: just above the castbar,
            -- centred on it, and wherever that goes.
            statusbar:SetPoint("BOTTOM", DogsForeverUI.Castbar.CastBar.castbar,
                "TOP", 0, DogsForeverUI.Castbar.STACK_GAP)
        end

        -- The client caches named, user-placed frames in layout-local.txt and
        -- restores them at login, after the addon has already positioned the
        -- bar from its own saved settings. StartMoving sets that flag on every
        -- drag, so clear it here -- the position saved by onMouseUp is the one
        -- that should win. Has to come after SetMovable: SetUserPlaced errors on
        -- a frame that is neither movable nor resizable.
        statusbar:SetUserPlaced(false)
        -- Clickable only while being placed: the drag is the only thing a click
        -- on this bar does, so the rest of the time it stays out of the way of
        -- whatever is underneath it.
        statusbar:EnableMouse(unlocked and true or false)
        statusbar:SetClampedToScreen(true)

        statusbar:SetMinMaxValues(0, mp5delay)

        -- FOREGROUND, BORDER, BACKGROUND
        Style.Paint(statusbar, Style.COUNTDOWN_COLOR)
        if not statusbar.border then statusbar.border = Style.AddBorder(statusbar) end
        if not statusbar.bg then
            statusbar.bg = statusbar:CreateTexture(nil, "BACKGROUND")
        end
        statusbar.bg:SetAllPoints(true)
        Style.SetBackground(statusbar.bg, unlocked)

        -- TEXT: the seconds on the left; while being placed, the bar's name
        -- there instead and "unlocked" on the right, as on every bar.
        if not statusbar.label then
            statusbar.label = statusbar:CreateFontString(nil, "OVERLAY")
            statusbar.stateText = statusbar:CreateFontString(nil, "OVERLAY")
        end
        for _, label in ipairs({ statusbar.label, statusbar.stateText }) do
            label:ClearAllPoints()
            Style.SingleLine(label)
            Style.SetFont(statusbar, label, group.textPadding)
        end
        statusbar.stateText:SetJustifyH("RIGHT")
        statusbar.stateText:SetPoint("RIGHT", statusbar, "RIGHT", -4, 0)
        statusbar.stateText:SetText("")
        statusbar.label:SetJustifyH("LEFT")
        statusbar.label:SetPoint("LEFT", statusbar, "LEFT", 4, 0)
        statusbar.label:SetPoint("RIGHT", statusbar.stateText, "LEFT", -6, 0)

        -- SPARK: always there, on every bar the addon draws.
        if not statusbar.spark then statusbar.spark = Style.AddSpark(statusbar) end
        statusbar.spark:SetHeight(group.barHeight * Style.SPARK_HEIGHT)
        statusbar.spark:Show()

        -- VISIBILITY. A countdown already running is left to OnUpdate; with
        -- none, the bar is put away at once.
        if not Wanted() then
            Style.HideNow(statusbar)
        elseif unlocked then
            ShowPlacementPreview()
        elseif (NS.mp5StartTime or 0) <= 0 then
            Style.HideNow(statusbar)
        end
    end

    -- What the bar shows while it is being placed, as every bar here does:
    -- empty, so the black background and the border show the exact footprint,
    -- and labelled so its state is unmistakable.
    function ShowPlacementPreview()
        Style.ShowNow(statusbar)
        statusbar:SetValue(0)
        statusbar.label:SetText(PLACEMENT_NAME)
        statusbar.stateText:SetText(Style.PLACEMENT_LABEL)
        if statusbar.spark then statusbar.spark:Hide() end
    end

    local function Unlocked()
        return Group().unlocked
    end

    -- The countdown fades in and out, as every castbar does
    -- (Style.FadeIn/FadeOut); switched off, it goes at once.
    function OnUpdate()
        if not Wanted() then
            Style.HideNow(statusbar)
            return
        end

        if Unlocked() then
            ShowPlacementPreview()
            return
        end

        local remaining = NS.mp5StartTime - GetTime()
        if NS.mp5StartTime <= 0 or remaining < 0 then
            resetManaGain()
            return
        end

        statusbar:SetValue(remaining)
        Style.FadeIn(statusbar)

        statusbar.label:SetFormattedText("%.1fs", remaining)

        if statusbar.spark then
            local width = statusbar:GetWidth()
            statusbar.spark:Show()
            statusbar.spark:SetPoint("CENTER", statusbar, "LEFT",
                math.min(width * (remaining / mp5delay), width), 0)
        end
    end

    -- Dragging, and a right-click to lock the group again once it is placed.
    -- There is no right-click to unlock: placement is turned on with the button
    -- in the options, which is the only way to it now that the bar is not on
    -- screen to be clicked most of the time.
    function onMouseDown(button)
        if button == "LeftButton" and Unlocked() then
            statusbar:StartMoving()
        end
    end

    function onMouseUp(button)
        if DogsForeverUI.RightClickLock(DogsForeverUI.Castbar, button) then return end
        if button ~= "LeftButton" or not Unlocked() then return end

        statusbar:StopMovingOrSizing()

        -- Dragged: somewhere of its own from now on, no longer under the
        -- castbar. Only the position is written: dragging cannot resize this
        -- bar, and reading the size back only rounded it - a size of exactly
        -- 100 came back as 100.0000305175781 and crept further on every drag.
        local db = Options()
        db.placed = true
        db.barLeft = statusbar:GetLeft()
        db.barTop = -1 * (GetScreenHeight() - statusbar:GetTop())

        Refresh()
        DogsForeverUI.RefreshOptions()
    end

    function resetManaGain()
        NS.mp5StartTime = 0

        if not Unlocked() then
            Style.FadeOut(statusbar)
        end
    end

    StatusBar.statusbar = statusbar
    StatusBar.Refresh = Refresh
    StatusBar.OnUpdate = OnUpdate
end
