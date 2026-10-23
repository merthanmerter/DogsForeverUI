-- MODULE: Threat  (DogsForeverUI.Threat, settings section "threat")
-- The player's threat on the target as the game counts it (the top threat's share; holding
-- it, the lead over the next), a bar over the target frame while on its threat list. Event-driven.
-- Boss numbers are secret: handed to the bar and label unread, no spark.

DogsForeverUI.Threat = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.Threat
    local Style = DogsForeverUI.Style
    local IsSecret = issecretvalue

    local Place, Refresh, Update

    NS.key = "threat"
    NS.title = "Threat"

    NS.defaults = {
        unlocked = false,
        barWidth = 150,          -- the target frame's width
        barHeight = 20,          -- the castbar's height
        frameStrata = "MEDIUM",
    }
    NS.placement = { barLeft = true, barTop = true, autoPlaced = true }

    local bar = CreateFrame("StatusBar", "DogsForeverUIThreatBar", UIParent)
    bar:SetMinMaxValues(0, 100)
    bar:Hide()
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.border = Style.AddBorder(bar)
    bar.spark = Style.AddSpark(bar)
    bar.nameText = bar:CreateFontString(nil, "OVERLAY")
    bar.valueText = bar:CreateFontString(nil, "OVERLAY")
    NS.bar = bar

    -- The target frame's left edge, the castbar's top (its default before it has one).
    function Place()
        local db = NS.db
        local frames, castbar = DogsForeverUI.Frames.db, DogsForeverUI.Castbar
        db.barLeft = frames.targetLeft or (GetScreenWidth() - db.barWidth) / 2
        db.barTop = castbar.db.barTop or castbar.DefaultTop()
        db.autoPlaced = true
    end

    function NS.Normalise(db)
        if db.barLeft == nil or db.barTop == nil then Place() end
    end

    function Update()
        if NS.db.unlocked then -- as it looks holding the target
            bar:SetValue(100)
            bar.valueText:SetText("100%")
            bar.spark:SetAlpha(0)
            Style.ShowNow(bar)
            return
        end
        -- The game's own number (its target frame's, UnitFrame_UpdateThreatIndicator): the share
        -- of the top threat, and while holding it, the lead over the next.
        local tanking, _, _, percent = UnitDetailedThreatSituation("player", "target")
        if not IsSecret(tanking) and tanking then
            percent = UnitThreatPercentageOfLead("player", "target") or percent
        end
        local secret = IsSecret(percent)
        if not secret and percent == nil then
            Style.FadeOut(bar)
            return
        end
        bar:SetValue(percent)
        bar.valueText:SetFormattedText("%.0f%%", percent)
        bar.spark:SetAlpha(secret and 0 or Style.SparkAlpha(percent, 100))
        Style.FadeIn(bar)
    end

    function Refresh()
        local db = NS.db
        DogsForeverUI.Snap.Put(bar, db)
        bar:SetSize(db.barWidth, db.barHeight)
        bar:SetFrameStrata(db.frameStrata)
        bar:EnableMouse(db.unlocked)
        Style.Paint(bar, Style.GOLD)
        Style.SetBackground(bar.bg)
        Style.PinSpark(bar.spark, bar)
        Style.BarLabels(bar, bar.nameText, bar.valueText)
        bar.nameText:SetText("Threat")

        Update()
    end

    DogsForeverUI.Snap.Piece(bar, NS, { name = "Threat", id = "threat" }, Refresh)

    NS:RegisterEvent("PLAYER_ENTERING_WORLD")
    NS:RegisterEvent("PLAYER_TARGET_CHANGED")
    NS:RegisterUnitEvent("UNIT_THREAT_LIST_UPDATE", "target")
    NS:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            -- The frames are placed now: our own spot again, never the player's.
            if NS.db.autoPlaced then Place() end
            Refresh()
            return
        end
        Update()
    end)

    NS.Init = Refresh
    NS.Refresh = Refresh

    DogsForeverUI:RegisterModule(NS)
end
