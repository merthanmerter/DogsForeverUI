-- MODULE: Combo points  (DogsForeverUI.ComboPoints, settings section "combo")
--
-- A bar for a rogue's combo points - and a druid's, in cat form - in the same
-- look as the castbar and the five-second countdown: one bordered bar, split
-- into a segment per point, each filling as the point is gained. It is on
-- screen while there are points to show, and gone the rest of the time.
--
-- The game's own combo points sat on the target frame; those are taken off it
-- while this is on (BlizzardComboFrame.lua).
--
-- Part of the castbar group, like the five-second countdown, and in the same
-- row as it - just above the castbar, centred on it, under the swing bars -
-- since the two are never wanted together: a rogue has no mana. Its size and
-- layer are its own (Sizes, "Combo points"); it takes the castbar's placement
-- mode and text padding, and goes wherever the castbar goes until it is
-- dragged or given a position of its own (Positions). Always on, no switch.
--
-- NOTHING IS READ. GetComboPoints is SecretWhenUnitPowerRestricted, so the
-- count is never compared or counted with. Each segment is a status bar of its
-- own that covers one point's stretch - the first from 0 to 1, the second from
-- 1 to 2 - and every one is handed the same count: a status bar clamps its own
-- value, so a segment is full exactly when its point is reached and empty until
-- then, and the addon never had to ask which that was.

DogsForeverUI.ComboPoints = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.ComboPoints
    local Style = DogsForeverUI.Style
    local IsSecret = issecretvalue

    local Refresh, Update

    NS.key = "combo"
    NS.title = "Combo"

    -- Always on (the player, 2026-09-29), no switch. Its own size and layer
    -- since then; it took the castbar's before, and `sized` says that was
    -- copied over once, so no bar changes size on the way.
    NS.defaults = {
        barWidth = 130,
        barHeight = 20,
        frameStrata = "MEDIUM",
        sized = false,
    }

    -- Where it is. Until it is placed on its own it sits in its row over the
    -- castbar, and these say where that is, for the Positions boxes.
    NS.placement = { barLeft = true, barTop = true, placed = true }

    function NS.Normalise(db)
        local castbar = DogsForeverUI.Castbar.db
        if not db.sized and castbar then
            db.barWidth, db.barHeight = castbar.barWidth, castbar.barHeight
            db.frameStrata = castbar.frameStrata
            db.sized = true
        end
    end

    -- The group's settings: size, strata, whether it is being placed.
    local function Group()
        return DogsForeverUI.Castbar.db
    end

    -- Enum.PowerType.ComboPoints, with its documented value behind it.
    local COMBO_POINTS = (type(Enum) == "table" and type(Enum.PowerType) == "table"
        and Enum.PowerType.ComboPoints) or 4

    -- How many segments when the game will not say: a rogue's five.
    local DEFAULT_MAX = 5
    local MOST = 10

    -- The hairline between two segments, the border's gold, as between a unit
    -- frame's two bars.
    local DIVIDER = 1

    local bar = CreateFrame("Frame", "DogsForeverUIComboBar", UIParent)
    bar:Hide()
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(true)
    bar.border = Style.AddBorder(bar)
    -- Its name, while it is being placed - above the segments.
    bar.placementLabels = Style.AddPlacementLabels(bar)

    local segments, dividers = {}, {}
    NS.bar = bar
    NS.segments = segments

    -- How many points there can be. Asked of the game, and the default when the
    -- answer cannot be read.
    local function MaxPoints()
        local max = UnitPowerMax("player", COMBO_POINTS)
        if IsSecret(max) or type(max) ~= "number" or max <= 0 then return DEFAULT_MAX end
        return math.min(max, MOST)
    end

    -- Whether this character's class ever has combo points: a rogue, or a
    -- druid. What the castbar group keeps a row for.
    function NS.ClassUses()
        local _, class = UnitClass("player")
        if IsSecret(class) then return false end
        return class == "ROGUE" or class == "DRUID"
    end

    -- Whether the player has combo points right now: a rogue always, a druid
    -- while in cat form - which is when a druid's resource is energy.
    local function UsesComboPoints()
        local _, class = UnitClass("player")
        if IsSecret(class) then return false end
        if class == "ROGUE" then return true end
        if class ~= "DRUID" then return false end
        local _, token = UnitPowerType("player")
        return not IsSecret(token) and token == "ENERGY"
    end

    -- Whether there is anything to show. A count that can be read says so
    -- itself; one that cannot is shown while there is a target to have points
    -- on, since the segments draw it correctly either way.
    local function HasPoints(points)
        if IsSecret(points) then return UnitExists("target") and true or false end
        return type(points) == "number" and points > 0
    end

    -- Lay the segments out: as many as there can be points, sharing the bar's
    -- width with a hairline between each two.
    local function Layout()
        local db = NS.db
        local count = MaxPoints()
        local width = (db.barWidth - (count - 1) * DIVIDER) / count

        for index = 1, math.max(count, #segments) do
            local segment = segments[index]
            if index <= count then
                if not segment then
                    segment = CreateFrame("StatusBar", nil, bar)
                    segments[index] = segment
                end
                Style.Paint(segment, Style.COMBO_COLOR)
                segment:SetMinMaxValues(index - 1, index)
                segment:ClearAllPoints()
                segment:SetPoint("TOPLEFT", bar, "TOPLEFT", (index - 1) * (width + DIVIDER), 0)
                segment:SetSize(width, db.barHeight)
                segment:Show()
            elseif segment then
                segment:Hide()
            end

            local divider = dividers[index]
            if index < count then
                if not divider then
                    divider = bar:CreateTexture(nil, "ARTWORK")
                    dividers[index] = divider
                end
                local c = Style.BORDER_COLOR
                divider:SetColorTexture(c[1], c[2], c[3], 1)
                divider:ClearAllPoints()
                divider:SetPoint("TOPLEFT", bar, "TOPLEFT", index * (width + DIVIDER) - DIVIDER, 0)
                divider:SetSize(DIVIDER, db.barHeight)
                divider:Show()
            elseif divider then
                divider:Hide()
            end
        end
    end

    -- What the bar shows right now. It fades in and out, as every castbar does
    -- (Style.FadeIn/FadeOut); switched off, being placed, or `settled` - a
    -- settings change, such as locking the group again - it goes or comes at
    -- once.
    function Update(settled)
        local db = NS.db

        -- Placed with the castbar group - by a character that has combo points
        -- to show: nobody else has anything to place here.
        if Group().unlocked then
            for _, segment in ipairs(segments) do segment:SetValue(0) end
            if UsesComboPoints() then Style.ShowNow(bar) else Style.HideNow(bar) end
            return
        end

        -- The same count to every segment, shown or not: each one draws its
        -- own point, and none is left holding a count from before.
        local points = GetComboPoints("player", "target")
        for _, segment in ipairs(segments) do segment:SetValue(points) end

        if not UsesComboPoints() then
            Style.HideNow(bar)
        elseif HasPoints(points) then
            if settled then Style.ShowNow(bar) else Style.FadeIn(bar) end
        elseif settled then
            Style.HideNow(bar)
        else
            Style.FadeOut(bar)
        end
    end

    function Refresh()
        local db, group = NS.db, Group()
        local castbar = DogsForeverUI.Castbar

        bar:ClearAllPoints()
        bar:SetFrameStrata(db.frameStrata or "MEDIUM")
        bar:SetSize(db.barWidth, db.barHeight)
        if db.placed then
            -- Placed somewhere of its own: it stays there.
            bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.barLeft, db.barTop)
        else
            -- The countdown's row: just above the castbar, centred on it, and
            -- wherever that goes. Where that is, written back for the
            -- Positions boxes.
            bar:SetPoint("BOTTOM", castbar.CastBar.castbar, "TOP", 0, castbar.STACK_GAP)
            db.barLeft, db.barTop = castbar.OverCastbar(db.barWidth, db.barHeight, castbar.STACK_GAP)
        end
        bar:SetMovable(true)
        -- After SetMovable: SetUserPlaced errors on a frame that is neither
        -- movable nor resizable.
        bar:SetUserPlaced(false)
        bar:SetClampedToScreen(true)
        -- Clickable only while being placed: the drag is all a click does.
        bar:EnableMouse(group.unlocked and true or false)

        Style.SetBackground(bar.bg, group.unlocked)
        Style.ShowPlacementLabels(bar.placementLabels, bar, "Combo points", group.unlocked,
            group.textPadding)
        Layout()

        NS.BlizzardComboFrame.Refresh()
        Update(true)
    end

    bar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and Group().unlocked then self:StartMoving() end
    end)
    bar:SetScript("OnMouseUp", function(self, button)
        -- A right-click locks the castbar group again once it is placed.
        if DogsForeverUI.RightClickLock(DogsForeverUI.Castbar, button) then return end
        if button ~= "LeftButton" or not Group().unlocked then return end
        self:StopMovingOrSizing()
        -- Dragged: somewhere of its own from now on, no longer in the row.
        local db = NS.db
        db.placed = true
        db.barLeft = self:GetLeft()
        db.barTop = -1 * (GetScreenHeight() - self:GetTop())
        Refresh()
        DogsForeverUI.RefreshOptions()
    end)

    NS:RegisterEvent("PLAYER_ENTERING_WORLD")
    NS:RegisterEvent("PLAYER_TARGET_CHANGED")
    for _, event in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
        pcall(NS.RegisterUnitEvent, NS, event, "player")
    end
    pcall(NS.RegisterEvent, NS, "UPDATE_SHAPESHIFT_FORM")

    NS:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            Refresh()
        elseif event == "UNIT_MAXPOWER" then
            Layout()
            Update()
        else
            Update()
        end
    end)

    NS.Init = Refresh
    -- A switch flipped in the Castbars section can take the row away from, or
    -- give it back to, the swing bars above it: the whole group is laid out
    -- again.
    NS.Refresh = function() DogsForeverUI.Castbar.Refresh() end
    NS.Redraw = Refresh

    DogsForeverUI:RegisterModule(NS)
end
