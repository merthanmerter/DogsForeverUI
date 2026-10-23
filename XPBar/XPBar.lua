-- MODULE: XP bar  (DogsForeverUI.XPBar, settings section "xp")
-- Rested XP shaded beyond it, the numbers on hover; a tracked house or a watched
-- reputation shows in it instead, an honor bar stacks over it. The game's bars are only faded:
-- their container is in the stack the protected action bars are laid out on.

DogsForeverUI.XPBar = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.XPBar
    local Style = DogsForeverUI.Style
    local Core = DogsForeverUI
    local IsSecret = issecretvalue
    local Number = BreakUpLargeNumbers

    local FALLBACK_BOTTOM = 64               -- about the game's XP bar, when it cannot be measured
    local HONOR_GAP = 2 + 2 * Style.BORDER_INSET
    local RENOWN_COLOR = { 0.0, 0.6, 1.0 }
    local HOUSE_COLOR = { 0.9, 0.8, 0.6 }    -- the gold of the game's house bar
    local BARS = StatusTrackingBarInfo.BarsEnum
    local OURS = { [BARS.Experience] = true, [BARS.Reputation] = true, [BARS.Honor] = true,
                   [BARS.HouseFavor] = true }
    local CONTAINERS = { MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }

    NS.key = "xp"
    NS.title = "XP bar"

    NS.defaults = {
        unlocked = false,
        barWidth = 300,
        barHeight = 10,
        frameStrata = "MEDIUM",
    }
    NS.placement = { barLeft = true, barTop = true, autoPlaced = true }

    local bar = CreateFrame("StatusBar", "DogsForeverUIXPBar", UIParent)
    bar:SetFrameLevel(3)
    bar:Hide()
    bar:EnableMouse(true)                    -- the tooltip, and the drag while unlocked
    local rested = CreateFrame("StatusBar", nil, bar)
    rested:SetFrameLevel(2)
    rested:SetAllPoints(bar)
    -- The background is the rested bar's: on the XP bar it would cover the shading.
    bar.bg = rested:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.border = Style.AddBorder(bar)
    bar.spark = Style.AddSpark(bar)
    NS.bar = bar
    NS.rested = rested

    -- Not the XP bar's child: at the level cap it takes the XP bar's place.
    local honor = CreateFrame("StatusBar", "DogsForeverUIHonorBar", UIParent)
    honor:Hide()
    honor:EnableMouse(true)                  -- the tooltip
    honor.bg = honor:CreateTexture(nil, "BACKGROUND")
    honor.bg:SetAllPoints(honor)
    honor.border = Style.AddBorder(honor)
    honor.spark = Style.AddSpark(honor)
    NS.honor = honor

    local reactionColours = {}               -- reaction -> { r, g, b }, made once each
    local function ReactionColour(reaction)
        local colour = reactionColours[reaction]
        if not colour then
            local c = FACTION_BAR_COLORS[reaction] or FACTION_BAR_COLORS[4]
            colour = { c.r, c.g, c.b }
            reactionColours[reaction] = colour
        end
        return colour
    end

    local function StandingLabel(reaction)
        local key = "FACTION_STANDING_LABEL" .. reaction
        return Core.Try(GetText, key, UnitSex("player")) or _G[key]
    end

    -- The watched reputation ("Show as experience bar"), worked out as the
    -- game's bar does (ReputationStatusBarMixin:Update): the standing within
    -- its tier, a friendship rank, or a major faction's renown, in blue.
    local function WatchedReputation()
        local rep = C_Reputation.GetWatchedFactionData()
        if not rep or rep.factionID == 0 then return end
        local id = rep.factionID
        local low, high, value = rep.currentReactionThreshold, rep.nextReactionThreshold, rep.currentStanding
        local colour, label = ReactionColour(rep.reaction), StandingLabel(rep.reaction)

        if C_Reputation.IsMajorFaction(id) then
            local major = C_MajorFactions.GetMajorFactionData(id)
            if major and major.renownLevelThreshold then
                low, high, value = 0, major.renownLevelThreshold, major.renownReputationEarned or 0
                label = major.renownLevel and ("Renown " .. major.renownLevel) or label
                colour = RENOWN_COLOR
            end
        else
            local friend = C_GossipInfo.GetFriendshipReputation(id)
            if friend and friend.friendshipFactionID > 0 then
                if friend.nextThreshold then
                    low, high, value = friend.reactionThreshold, friend.nextThreshold, friend.standing
                else
                    low, high, value = 0, 1, 1
                end
                label = friend.reaction or label
                colour = ReactionColour(5)
            end
        end

        if IsSecret(low) or IsSecret(high) or IsSecret(value) then
            return { name = rep.name, colour = colour, secret = true, low = low, high = high, value = value }
        end
        local max, current = high - low, value - low
        if max <= 0 then max, current = 1, 1 end   -- the top of the last tier: full
        return { name = rep.name, label = label, colour = colour,
                 low = 0, high = max, value = math.max(0, math.min(current, max)) }
    end

    -- The tracked house ("Show as Experience Bar" on its dashboard), worked out
    -- as the game's bar does (HouseFavorBarMixin:Update): the favor within its
    -- level. Only HOUSE_LEVEL_FAVOR_UPDATED carries it, asked for by RequestHouse.
    local houseFavor                         -- the tracked house's last HouseLevelFavor

    local function RequestHouse()
        local guid = C_Housing.GetTrackedHouseGuid()
        if guid then C_Housing.GetCurrentHouseLevelFavor(guid) end
    end

    local function TrackedHouse()
        local guid = C_Housing.GetTrackedHouseGuid()
        if not guid or not houseFavor or houseFavor.houseGUID ~= guid then return end
        local level = houseFavor.houseLevel
        local low = C_Housing.GetHouseLevelFavorForLevel(level)
        local max, current = C_Housing.GetHouseLevelFavorForLevel(level + 1) - low, houseFavor.houseFavor - low
        if level >= C_Housing.GetMaxHouseLevel() or max <= 0 then max, current = 1, 1 end   -- the top level: full
        return { name = "House", label = "Level " .. level, colour = HOUSE_COLOR,
                 low = 0, high = max, value = math.max(0, math.min(current, max)) }
    end

    -- In the game's order: a tracked house before a watched reputation.
    local function Watched()
        return TrackedHouse() or WatchedReputation()
    end

    -- First run, a reset, or a new resolution while still the addon's place:
    -- centred, over the game's XP bar where that can be measured.
    local function Place()
        local db = NS.db
        local width, height = GetScreenWidth(), GetScreenHeight()
        if width <= 0 or height <= 0 then
            db.barLeft, db.barTop = 90, -68
            return
        end
        local centre = FALLBACK_BOTTOM + db.barHeight / 2
        local game = MainStatusTrackingBarContainer
        local _, y = game:GetCenter()
        if type(y) == "number" and not IsSecret(y) and y > 0 then
            centre = y * game:GetEffectiveScale() / UIParent:GetEffectiveScale()
        end
        db.barLeft = (width - db.barWidth) / 2
        db.barTop = -(height - centre - db.barHeight / 2)
        db.autoPlaced = true
    end

    function NS.Normalise(db)
        if db.barLeft == nil or db.barTop == nil then Place() end
    end

    local function UpdateHonor()
        if not StatusTrackingBarManager:CanShowBar(BARS.Honor) then
            honor:Hide()
            return
        end
        honor:ClearAllPoints()
        if bar:IsShown() then
            honor:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, HONOR_GAP)
        else
            honor:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
        end
        honor:Show()
        local current, max = UnitHonor("player"), UnitHonorMax("player")
        local secret = IsSecret(current) or IsSecret(max)
        if not secret and max <= 0 then max = 1 end
        honor:SetMinMaxValues(0, max)
        honor:SetValue(current)
        honor.spark:SetAlpha(secret and 0 or Style.SparkAlpha(current, max))
    end

    -- Shown at `value` of low..high in `colour`, nothing rested beyond it.
    local function Fill(colour, low, high, value, sparkAlpha)
        bar:Show()
        bar:SetStatusBarColor(colour[1], colour[2], colour[3], 1)
        bar:SetMinMaxValues(low, high)
        bar:SetValue(value)
        bar.spark:SetAlpha(sparkAlpha)
        rested:SetMinMaxValues(0, 1)
        rested:SetValue(0)
    end

    -- Unlocked it shows the real XP, as it really looks.
    local function UpdateXP()
        local watched = Watched()
        if watched then
            Fill(watched.colour, watched.low, watched.high, watched.value,
                watched.secret and 0 or Style.SparkAlpha(watched.value, watched.high))
            return
        end
        if not GameRulesUtil.CanShowExperienceBar() then
            -- Nothing to show (the level cap), but still there to be placed.
            bar:SetShown(NS.db.unlocked)
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            rested:SetValue(0)
            bar.spark:SetAlpha(0)
            return
        end
        local current, max = UnitXP("player"), UnitXPMax("player")
        if IsSecret(current) or IsSecret(max) then
            -- Straight to the bar: no rested shading or spark, which need arithmetic.
            Fill(Style.XP_COLOR, 0, max, current, 0)
            return
        end
        if max <= 0 then max = 1 end
        Fill(Style.XP_COLOR, 0, max, current, Style.SparkAlpha(current, max))
        local restedXP = GetXPExhaustion()
        if IsSecret(restedXP) or not restedXP then restedXP = 0 end
        rested:SetMinMaxValues(0, max)
        rested:SetValue(math.min(current + restedXP, max))
    end

    local function Update()
        UpdateXP()
        UpdateHonor()
    end

    -- THE GAME'S BARS: while a status-tracking container shows one of ours,
    -- its bar, frame art and dividers are faded - followed after every change
    -- of bar and every re-layout of dividers (handed out at full alpha).
    local faded = {}                         -- container -> { region -> its alpha before }

    local function Fade(container, region)
        local alphas = faded[container]
        if alphas[region] == nil then alphas[region] = region:GetAlpha() end
        region:SetAlpha(0)
    end

    local function Restore(container, region)
        local alpha = faded[container][region]
        if alpha == nil then return end
        region:SetAlpha(alpha)
        faded[container][region] = nil
    end

    local function FollowContainer(container)
        local shown = container.shownBarIndex
        local hide = OURS[shown] == true
        if hide then
            if container.bars[shown] then Fade(container, container.bars[shown]) end
            Fade(container, container.BarFrameTexture)
            local dividers = container.HorizontalDividersPool
            if dividers then
                for divider in dividers:EnumerateActive() do Fade(container, divider) end
            end
            -- Ours it no longer shows (the game hid them) get their alpha back.
            for index in pairs(OURS) do
                if index ~= shown and container.bars[index] then Restore(container, container.bars[index]) end
            end
        else
            for region in pairs(faded[container]) do Restore(container, region) end
        end
        -- Out of Edit Mode too while it shows ours.
        Core.HoldEditMode(container, hide)
    end

    local function FollowContainers()
        for _, container in ipairs(CONTAINERS) do FollowContainer(container) end
    end

    for _, container in ipairs(CONTAINERS) do
        faded[container] = {}
        local function Follow() FollowContainer(container) end
        hooksecurefunc(container, "ApplyPendingBarToShow", Follow)
        if container.UpdateDividers then hooksecurefunc(container, "UpdateDividers", Follow) end
        container:HookScript("OnShow", Follow)
        -- Ours faded the moment they are shown, whatever showed them: a zone
        -- change once let one through beside the addon's.
        for index in pairs(OURS) do
            local gameBar = container.bars[index]
            if gameBar then gameBar:HookScript("OnShow", function(self) Fade(container, self) end) end
        end
    end
    -- The game sorting out its bars: every zone change and loading screen.
    hooksecurefunc(StatusTrackingBarManager, "UpdateBarsShown", function()
        FollowContainers()
        Update()
    end)

    local function Refresh()
        local db = NS.db
        Core.Snap.Put(bar, db)
        bar:SetSize(db.barWidth, db.barHeight)
        bar:SetFrameStrata(db.frameStrata)
        Style.Paint(bar, Style.XP_COLOR)
        Style.Paint(rested, Style.RESTED_COLOR)
        Style.SetBackground(bar.bg)
        Style.PinSpark(bar.spark, bar)

        honor:SetFrameStrata(db.frameStrata)
        honor:SetSize(db.barWidth, math.max(1, math.floor(db.barHeight * 2 / 3 + 0.5)))
        Style.Paint(honor, Style.HONOR_COLOR)
        Style.SetBackground(honor.bg)
        Style.PinSpark(honor.spark, honor)

        FollowContainers()
        Update()
    end

    local function HideTooltip() GameTooltip:Hide() end

    -- The tooltip titled "XP: 1,234 / 5,000 (24%)"; false while that cannot be read.
    local function AmountTooltip(owner, name, current, max)
        if IsSecret(current) or IsSecret(max) or max <= 0 then return false end
        GameTooltip:SetOwner(owner, "ANCHOR_TOP")
        GameTooltip:SetText(("%s: %s / %s (%d%%)"):format(name, Number(current), Number(max),
            math.floor(current / max * 100)))
        return true
    end

    bar:SetScript("OnEnter", function(self)
        if NS.db.unlocked then return end
        local watched = Watched()
        if watched then
            if watched.secret then return end
            local line = ("%s / %s"):format(Number(watched.value), Number(watched.high))
            if watched.label then line = line .. "  (" .. watched.label .. ")" end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(watched.name)
            GameTooltip:AddLine(line, watched.colour[1], watched.colour[2], watched.colour[3])
            GameTooltip:Show()
            return
        end
        local current, max = UnitXP("player"), UnitXPMax("player")
        if not AmountTooltip(self, "XP", current, max) then return end
        GameTooltip:AddLine(("%s to level"):format(Number(max - current)), 1, 1, 1)
        local restedXP = GetXPExhaustion()
        if not IsSecret(restedXP) and restedXP and restedXP > 0 then
            GameTooltip:AddLine(("Rested: %s"):format(Number(restedXP)), 0.4, 0.6, 1)
        end
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", HideTooltip)

    honor:SetScript("OnEnter", function(self)
        if not AmountTooltip(self, "Honor", UnitHonor("player"), UnitHonorMax("player")) then return end
        local level = UnitHonorLevel("player")
        if not IsSecret(level) then
            GameTooltip:AddLine(("Honor level %d"):format(level), 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    honor:SetScript("OnLeave", HideTooltip)

    -- Only the position is saved: reading the size back would only round it.
    Core.Snap.Piece(bar, NS, { name = "XP Bar", id = "xp" }, Refresh)

    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP",
        "PLAYER_UPDATE_RESTING", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN",
        "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",            -- the watched reputation
        "TRACKED_HOUSE_CHANGED", "HOUSE_LEVEL_FAVOR_UPDATED",               -- the tracked house
        "HONOR_XP_UPDATE", "HONOR_LEVEL_UPDATE", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA",  -- honor
    }) do
        NS:RegisterEvent(event)
    end
    NS:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            -- UIParent is unscaled at ADDON_LOADED: only the addon's own place is worked out again.
            if NS.db.autoPlaced then Place() end
            RequestHouse()
            Refresh()
            return
        elseif event == "TRACKED_HOUSE_CHANGED" then
            RequestHouse()
        elseif event == "HOUSE_LEVEL_FAVOR_UPDATED" then
            local favor = ...
            if favor.houseGUID == C_Housing.GetTrackedHouseGuid() then houseFavor = favor end
        end
        Update()
    end)

    NS.Init = Refresh
    NS.Refresh = Refresh

    DogsForeverUI:RegisterModule(NS)
end
