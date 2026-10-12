-- MODULE: Threat  (DogsForeverUI.Threat, settings section "threat")
--
-- One bar over the target frame, as the cooldowns are over the player frame:
-- the player's threat on the target, as a share of what it takes to pull it -
-- 100% is holding it. The game's own number (UnitDetailedThreatSituation's
-- scaled percentage). Shown only while the player is on the target's threat
-- list - an NPC in a fight with them; a player, a friend or a mob out of
-- combat has none.
--
-- Against a boss the numbers are secret (SecretWhenUnitThreatValuesRestricted):
-- handed to the bar and its label as they are, never read - the bar is the
-- same there, only its spark is left off.
--
-- No polling: the game sends UNIT_THREAT_LIST_UPDATE whenever the target's
-- threat list changes, and that is when the bar is redrawn.
--
-- By default its left edge is the target frame's and its top level with the
-- castbar's, as the cooldowns' first bar sits on the player's side; anchored
-- to the target frame (Core\Snap.lua).

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
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:Hide()
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.border = Style.AddBorder(bar)
    bar.spark = Style.AddSpark(bar)
    bar.nameText = bar:CreateFontString(nil, "OVERLAY")
    bar.valueText = bar:CreateFontString(nil, "OVERLAY")
    NS.bar = bar

    -- The target frame's left edge and the castbar's top, as their modules
    -- save them; the castbar's own default top before it has one.
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
        if NS.db.unlocked then
            -- As it really looks, holding the target.
            bar:SetValue(100)
            bar.valueText:SetText("100%")
            bar.spark:SetAlpha(0)
            Style.ShowNow(bar)
            return
        end
        local _, _, percent = UnitDetailedThreatSituation("player", "target")
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
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.barLeft, db.barTop)
        bar:SetSize(db.barWidth, db.barHeight)
        bar:SetFrameStrata(db.frameStrata)
        -- After SetMovable: cleared so the client's layout cache never wins
        -- over the place saved here.
        bar:SetUserPlaced(false)
        bar:EnableMouse(db.unlocked)

        Style.Paint(bar, Style.GOLD)
        Style.SetBackground(bar.bg)
        Style.PinSpark(bar.spark, bar)
        for _, label in ipairs({ bar.nameText, bar.valueText }) do
            label:ClearAllPoints()
            Style.SingleLine(label)
            Style.SetFont(bar, label)
        end
        bar.valueText:SetJustifyH("RIGHT")
        bar.valueText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        bar.nameText:SetJustifyH("LEFT")
        bar.nameText:SetPoint("LEFT", bar, "LEFT", 4, 0)
        bar.nameText:SetPoint("RIGHT", bar.valueText, "LEFT", -6, 0)
        bar.nameText:SetText("Threat")

        Update()
    end

    -- Dragging, while unlocked. Where it is now, kept: a drag's end, a nudge,
    -- or - locked or not - following what it is anchored to (Core\Snap.lua).
    local function SavePlace()
        local db = NS.db
        db.autoPlaced = false
        db.barLeft = bar:GetLeft()
        db.barTop = -1 * (GetScreenHeight() - bar:GetTop())
        Refresh()
        DogsForeverUI.RefreshOptions()
    end
    bar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and NS.db.unlocked then DogsForeverUI.Snap.Start(self) end
    end)
    bar:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" or not NS.db.unlocked then return end
        DogsForeverUI.Snap.Stop(self)
        SavePlace()
    end)
    DogsForeverUI.Snap.Register(bar, { save = SavePlace, name = "Threat", id = "threat" })

    NS:RegisterEvent("PLAYER_ENTERING_WORLD")
    NS:RegisterEvent("PLAYER_TARGET_CHANGED")
    NS:RegisterUnitEvent("UNIT_THREAT_LIST_UPDATE", "target")
    NS:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            -- The frames have their places now: the addon's own spot worked
            -- out again, never one the player chose.
            if NS.db.autoPlaced then Place() end
            Refresh()
            return
        end
        Update()
    end)

    function NS.Unlock()
        NS.db.unlocked = true
        Refresh()
    end

    function NS.Lock()
        NS.db.unlocked = false
        bar:StopMovingOrSizing()
        Refresh()
    end

    NS.Init = Refresh
    NS.Refresh = Refresh

    DogsForeverUI:RegisterModule(NS)
end
