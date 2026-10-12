-- The countdown bar.
--
-- One of the castbar group: drawn exactly like the castbar (Core\Style.lua) in
-- the palette's countdown colour, at its own size and layer (Sizes, "Five
-- second rule"), with the group's text padding. The spark and the seconds are
-- always there. By default it sits just above the castbar, centred on it,
-- under the swing bars, with the group's daylight between each - worked out
-- once (a first start, a reset); it never moves with the castbar after that
-- (only when anchored to it on purpose, in Edit Mode).

local StatusBar = {}
DogsForeverUI.FiveSecondRule.StatusBar = StatusBar

do -- private scope

    local NS = DogsForeverUI.FiveSecondRule
    local Style = DogsForeverUI.Style

    local Refresh, ShowPreview, OnUpdate
    local onMouseDown, onMouseUp

    local statusbar = CreateFrame("StatusBar", "DogsForeverUIFiveSecondBar", UIParent)
    statusbar:Hide()   -- off screen until a countdown fades it in
    statusbar:SetMovable(true)
    statusbar:SetScript("OnMouseDown", function(_, button) onMouseDown(button) end)
    statusbar:SetScript("OnMouseUp", function(_, button) onMouseUp(button) end)
    local mp5delay = 5

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
        return not NS.noMana
    end

    function Refresh()
        local db, group = Options(), Group()

        -- POSITION, SIZE: its own.
        statusbar:ClearAllPoints()
        statusbar:SetFrameStrata(db.frameStrata or "MEDIUM")

        local unlocked = group.unlocked

        statusbar:SetWidth(db.barWidth)
        statusbar:SetHeight(db.barHeight)
        -- Its default: its row, shared with the combo points, just above the
        -- castbar and centred on it - taken once (a reset clears `placed`).
        local castbar = DogsForeverUI.Castbar
        if not db.placed and castbar.GroupSettled() then
            db.barLeft, db.barTop = castbar.OverCastbar(db.barWidth, db.barHeight, castbar.STACK_GAP)
            db.placed = true
        end
        if db.placed then
            statusbar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.barLeft, db.barTop)
        else
            -- (Before the castbar has its place: shown over it.)
            statusbar:SetPoint("BOTTOM", castbar.CastBar.castbar, "TOP", 0, castbar.STACK_GAP)
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
        Style.SetBackground(statusbar.bg)

        -- TEXT: the seconds on the left.
        if not statusbar.label then
            statusbar.label = statusbar:CreateFontString(nil, "OVERLAY")
        end
        local label = statusbar.label
        label:ClearAllPoints()
        Style.SingleLine(label)
        Style.SetFont(statusbar, label, group.textPadding)
        label:SetJustifyH("LEFT")
        label:SetPoint("LEFT", statusbar, "LEFT", 4, 0)
        label:SetPoint("RIGHT", statusbar, "RIGHT", -4, 0)

        -- SPARK: always there, on every bar the addon draws.
        if not statusbar.spark then statusbar.spark = Style.AddSpark(statusbar) end
        statusbar.spark:SetHeight(db.barHeight * Style.SPARK_HEIGHT)
        statusbar.spark:Show()

        -- VISIBILITY. A countdown already running is left to OnUpdate; with
        -- none, the bar is put away at once.
        if not Wanted() then
            Style.HideNow(statusbar)
        elseif unlocked then
            ShowPreview()
        elseif (NS.mp5StartTime or 0) <= 0 or not NS.ManaActive() then
            Style.HideNow(statusbar)
        end
    end

    -- What the bar shows in Edit Mode, as it really looks: a countdown just
    -- begun.
    function ShowPreview()
        Style.ShowNow(statusbar)
        statusbar:SetValue(mp5delay)
        statusbar.label:SetFormattedText("%.1fs", mp5delay)
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
            ShowPreview()
            return
        end

        -- Not on mana now (a druid in cat or bear form): out of sight, still
        -- counting (FiveSecondRule.ManaActive).
        if not NS.ManaActive() then
            Style.HideNow(statusbar)
            return
        end

        -- Nothing counting down, or the five seconds are up.
        local remaining = NS.mp5StartTime - GetTime()
        if NS.mp5StartTime <= 0 or remaining < 0 then
            NS.mp5StartTime = 0
            Style.FadeOut(statusbar)
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

    -- Dragging, while unlocked. Placement is turned on and off from the
    -- options and the placing dialog, the only way to it now that the bar is
    -- not on screen to be clicked most of the time.
    function onMouseDown(button)
        if button == "LeftButton" and Unlocked() then
            DogsForeverUI.Snap.Start(statusbar)
        end
    end
    -- Where the bar is now, kept: somewhere of its own from now on, no
    -- longer under the castbar. Only the position is written: dragging
    -- cannot resize this bar, and reading the size back only rounded it - a
    -- size of exactly 100 came back as 100.0000305175781 and crept further on
    -- every drag. A drag's end, a nudge, or - locked or not - following what
    -- it is anchored to (Core\Snap.lua).
    local function SavePlace()
        local db = Options()
        db.placed = true
        db.barLeft = statusbar:GetLeft()
        db.barTop = -1 * (GetScreenHeight() - statusbar:GetTop())

        Refresh()
        DogsForeverUI.RefreshOptions()
    end

    DogsForeverUI.Snap.Register(statusbar, { save = SavePlace, name = "5SR", id = "fsr" })

    function onMouseUp(button)
        if button ~= "LeftButton" or not Unlocked() then return end
        DogsForeverUI.Snap.Stop(statusbar)
        SavePlace()
    end

    StatusBar.statusbar = statusbar
    StatusBar.Refresh = Refresh
    StatusBar.OnUpdate = OnUpdate
end
