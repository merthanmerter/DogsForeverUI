-- MODULE: XP bar  (DogsForeverUI.XPBar, settings section "xp")
--
-- An experience bar of the addon's own, in the addon's one look, at any size.
-- While a faction is watched ("Show as experience bar"), it shows that
-- reputation instead, in the standing's colour (see WatchedReputation).
--
-- The game's own XP bar cannot be made smaller than Edit Mode's slider allows
-- (half its width, and never any thinner) without taking it apart: its frame
-- art and its segment dividers are built for the size the game gives it, it is
-- part of the stack the protected action bars are laid out on, and Edit Mode's
-- settings must not be written from an addon. The castbar went the same way -
-- see the note on the abandoned castbar resizer: owning the frame beats
-- negotiating with Blizzard's. So this draws one, and the game's is faded out
-- while it is on (BlizzardXPBar.lua).
--
-- There is no text on the bar, by request: it is a bar and nothing else. The
-- numbers are in the tooltip on hover.
--
-- XP is not a secret value on this client, so the numbers are read. They are
-- still asked about first, and a value that cannot be read is handed straight
-- to the bar with no rested shading or tooltip, which both need arithmetic.

DogsForeverUI.XPBar = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.XPBar
    local Style = DogsForeverUI.Style
    local IsSecret = issecretvalue

    local Place, Refresh, Update, ToggleLock, Lock, Unlock

    NS.key = "xp"
    NS.title = "XP bar"

    NS.defaults = {
        enabled = true,
        unlocked = false,
        barWidth = 300,
        barHeight = 10,
        showRested = true,
        frameStrata = "MEDIUM",
    }

    NS.placement = { barLeft = true, barTop = true, autoPlaced = true }

    -- The bar, the rested XP shaded in beyond it, and the frame they sit in.
    local bar = CreateFrame("StatusBar", "DogsForeverUIXPBar", UIParent)
    bar:SetFrameLevel(3)
    bar:Hide()

    local rested = CreateFrame("StatusBar", nil, bar)
    rested:SetFrameLevel(2)
    rested:SetAllPoints(bar)

    -- The background belongs to the rested bar, which sits under the XP bar: on
    -- the XP bar itself it would be drawn over the rested shading.
    bar.bg = rested:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.border = Style.AddBorder(bar)
    -- The spark at the end of the XP, as on the castbar.
    bar.spark = Style.AddSpark(bar)
    -- No text on the bar - except, while it is being placed, its name and
    -- "unlocked", as on every bar.
    bar.placementLabels = Style.AddPlacementLabels(bar)

    NS.bar = bar
    NS.rested = rested

    -- How far above the bottom of the screen the bar sits when the game's own
    -- XP bar cannot be measured: about where that bar is by default.
    local FALLBACK_BOTTOM = 64

    local function Number(value)
        return BreakUpLargeNumbers and BreakUpLargeNumbers(value) or tostring(value)
    end

    -- Whether the game would show an XP bar at all: not at the level cap, not
    -- with XP gain switched off, not under a game rule that disables it. The
    -- game's own answer, asked of its own helper when there is one.
    local function XPToShow()
        if type(GameRulesUtil) == "table" and type(GameRulesUtil.CanShowExperienceBar) == "function" then
            local ok, can = pcall(GameRulesUtil.CanShowExperienceBar)
            if ok then return can and true or false end
        end
        if type(IsXPUserDisabled) == "function" and IsXPUserDisabled() then return false end
        local level, cap = UnitLevel("player"), GetMaxPlayerLevel and GetMaxPlayerLevel()
        if IsSecret(level) or type(cap) ~= "number" then return true end
        return level < cap
    end

    -- A REPUTATION SHOWN AS THE XP BAR. Ticking "Show as experience bar" for a
    -- faction (the reputation panel) watches it, and the game then puts that
    -- reputation in its own bar at the bottom - with the XP bar pushed off to
    -- a second one. With this bar on, the watched reputation is shown here
    -- instead, in the colour of the standing (the game's FACTION_BAR_COLORS:
    -- red, orange, yellow, green), and the game's reputation bar is faded out
    -- like its XP bar (BlizzardXPBar.lua). Unticked, the bar is the XP bar
    -- again. Worked out as the game's own reputation bar works it out
    -- (ReputationStatusBarMixin:Update): the standing within its tier, or
    -- within a friendship rank, or the renown level of a major faction (drawn
    -- blue, as the game draws it) - the last two only where this client has
    -- them. The name and numbers are in the tooltip, as for XP.
    local RENOWN_COLOR = { 0.0, 0.6, 1.0 }
    local REACTION_FALLBACK = {
        { 0.8, 0.13, 0.13 }, { 0.8, 0.13, 0.13 }, { 0.75, 0.27, 0.0 }, { 0.9, 0.7, 0.0 },
        { 0.0, 0.6, 0.1 }, { 0.0, 0.6, 0.1 }, { 0.0, 0.6, 0.1 }, { 0.0, 0.6, 0.1 },
    }

    local function Call(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, a, b, c, d = pcall(fn, ...)
        if ok then return a, b, c, d end
    end

    local function ReactionColour(reaction)
        local colours = _G.FACTION_BAR_COLORS
        local colour = type(colours) == "table" and colours[reaction]
        if type(colour) == "table" and type(colour.r) == "number" then
            return { colour.r, colour.g, colour.b }
        end
        return REACTION_FALLBACK[reaction] or REACTION_FALLBACK[4]
    end

    local function StandingLabel(reaction)
        local key = "FACTION_STANDING_LABEL" .. tostring(reaction)
        if type(GetText) == "function" then
            local text = Call(GetText, key, UnitSex and UnitSex("player") or nil)
            if type(text) == "string" then return text end
        end
        return type(_G[key]) == "string" and _G[key] or nil
    end

    local function WatchedReputation()
        local rep = type(C_Reputation) == "table" and Call(C_Reputation.GetWatchedFactionData)
        if type(rep) ~= "table" or not rep.factionID or rep.factionID == 0 then return nil end
        local id = rep.factionID
        local low, high, value = rep.currentReactionThreshold, rep.nextReactionThreshold, rep.currentStanding
        local colour = ReactionColour(rep.reaction)
        local label = StandingLabel(rep.reaction)

        if Call(C_Reputation.IsMajorFaction, id) then
            local major = type(C_MajorFactions) == "table" and Call(C_MajorFactions.GetMajorFactionData, id)
            if type(major) == "table" and major.renownLevelThreshold then
                low, high, value = 0, major.renownLevelThreshold, major.renownReputationEarned or 0
                label = major.renownLevel and ("Renown " .. major.renownLevel) or label
                colour = RENOWN_COLOR
            end
        elseif type(C_GossipInfo) == "table" then
            local friend = Call(C_GossipInfo.GetFriendshipReputation, id)
            if type(friend) == "table" and (friend.friendshipFactionID or 0) > 0 then
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
            -- Handed to the bar as they are; nothing is worked out from them.
            return { name = rep.name, colour = colour, secret = true, low = low, high = high, value = value }
        end
        low, high, value = tonumber(low) or 0, tonumber(high) or 1, tonumber(value) or 0
        local max, current = high - low, value - low
        if max <= 0 then max, current = 1, 1 end   -- the top of the last tier: full
        return { name = rep.name, label = label, colour = colour,
                 value = math.max(0, math.min(current, max)), max = max }
    end

    -- First run, a reset, or a new resolution while the bar is still where the
    -- addon put it: centred, over where the game's own XP bar sits when that can
    -- be measured, and a little above the bottom of the screen when it cannot.
    function Place()
        local db = NS.db
        local screenWidth = GetScreenWidth() or 0
        local screenHeight = GetScreenHeight() or 0
        local width = db.barWidth or NS.defaults.barWidth
        local height = db.barHeight or NS.defaults.barHeight

        if screenWidth <= 0 or screenHeight <= 0 then
            db.barLeft, db.barTop = 90, -68
            return
        end

        local centre
        local game = _G.MainStatusTrackingBarContainer
        if type(game) == "table" and type(game.GetCenter) == "function" then
            local ok, _, y = pcall(game.GetCenter, game)
            local okScale, scale = pcall(game.GetEffectiveScale, game)
            local okParent, parentScale = pcall(UIParent.GetEffectiveScale, UIParent)
            if ok and okScale and okParent and type(y) == "number" and not IsSecret(y)
               and type(scale) == "number" and not IsSecret(scale)
               and type(parentScale) == "number" and parentScale > 0 and y > 0 then
                centre = y * scale / parentScale
            end
        end
        centre = centre or (FALLBACK_BOTTOM + height / 2)

        db.barLeft = (screenWidth - width) / 2
        db.barTop = -(screenHeight - centre - height / 2)
        db.autoPlaced = true
    end

    function NS.Normalise(db)
        if db.barLeft == nil or db.barTop == nil then Place() end
    end

    -- What the bar shows right now: the XP in it and the rested XP beyond it.
    function Update()
        local db = NS.db
        if not db.enabled then bar:Hide(); return end

        if db.unlocked then
            bar:Show()
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            rested:SetValue(0)
            bar.spark:SetAlpha(0)
            return
        end

        local rep = WatchedReputation()
        if rep then
            bar:Show()
            local c = rep.colour
            bar:SetStatusBarColor(c[1], c[2], c[3], 1)
            rested:SetMinMaxValues(0, 1)
            rested:SetValue(0)
            if rep.secret then
                bar:SetMinMaxValues(rep.low, rep.high)
                bar:SetValue(rep.value)
                bar.spark:SetAlpha(0)
                return
            end
            bar:SetMinMaxValues(0, rep.max)
            bar:SetValue(rep.value)
            bar.spark:SetAlpha(Style.ShowSparks() and Style.SparkAlpha(rep.value, rep.max) or 0)
            return
        end

        if not XPToShow() then bar:Hide(); return end
        bar:Show()
        local xpColour = Style.XP_COLOR
        bar:SetStatusBarColor(xpColour[1], xpColour[2], xpColour[3], 1)

        local current, max = UnitXP("player"), UnitXPMax("player")
        if IsSecret(current) or IsSecret(max) then
            bar:SetMinMaxValues(0, max)
            bar:SetValue(current)
            rested:SetMinMaxValues(0, 1)
            rested:SetValue(0)
            -- Where the edge is cannot be judged, so no spark over it.
            bar.spark:SetAlpha(0)
            return
        end

        if type(max) ~= "number" or max <= 0 then max = 1 end
        current = type(current) == "number" and current or 0

        bar:SetMinMaxValues(0, max)
        bar:SetValue(current)
        bar.spark:SetAlpha(Style.ShowSparks() and Style.SparkAlpha(current, max) or 0)

        local restedXP = db.showRested and GetXPExhaustion and GetXPExhaustion() or nil
        if IsSecret(restedXP) or type(restedXP) ~= "number" then restedXP = 0 end
        rested:SetMinMaxValues(0, max)
        rested:SetValue(math.min(current + restedXP, max))
    end
    NS.Update = Update

    function Refresh()
        local db = NS.db

        bar:ClearAllPoints()
        bar:SetFrameStrata(db.frameStrata or "MEDIUM")
        bar:SetSize(db.barWidth, db.barHeight)
        bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.barLeft, db.barTop)
        bar:SetMovable(true)
        -- After SetMovable: SetUserPlaced errors on a frame that is neither
        -- movable nor resizable. Cleared so the client's layout cache never wins
        -- over the position saved here.
        bar:SetUserPlaced(false)
        bar:SetClampedToScreen(true)
        -- The mouse is for the tooltip, and for the drag while it is unlocked.
        bar:EnableMouse(true)

        Style.Paint(bar, Style.XP_COLOR)
        -- Solid: the rested stretch is its own colour in the bar. It is not
        -- faded out while unlocked - this frame carries the background too -
        -- but simply empty then (see Update).
        Style.Paint(rested, Style.RESTED_COLOR)
        Style.SetBackground(bar.bg, db.unlocked)
        Style.ShowPlacementLabels(bar.placementLabels, bar, "XP bar", db.unlocked)
        Style.PinSpark(bar.spark, bar)

        NS.BlizzardXPBar.Refresh()
        Update()
    end

    -- Hovering says what the numbers are, as the game's bar does.
    bar:SetScript("OnEnter", function(self)
        if NS.db.unlocked or not GameTooltip then return end
        local rep = WatchedReputation()
        if rep then
            if rep.secret or type(rep.name) ~= "string" then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(rep.name)
            local line = string.format("%s / %s", Number(rep.value), Number(rep.max))
            if rep.label then line = line .. "  (" .. rep.label .. ")" end
            local c = rep.colour
            GameTooltip:AddLine(line, c[1], c[2], c[3])
            GameTooltip:Show()
            return
        end
        local current, max = UnitXP("player"), UnitXPMax("player")
        if IsSecret(current) or IsSecret(max) or type(max) ~= "number" or max <= 0 then return end

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(string.format("XP: %s / %s (%d%%)", Number(current), Number(max),
            math.floor(current / max * 100)))
        GameTooltip:AddLine(string.format("%s to level", Number(max - current)), 1, 1, 1)
        local restedXP = GetXPExhaustion and GetXPExhaustion()
        if type(restedXP) == "number" and not IsSecret(restedXP) and restedXP > 0 then
            GameTooltip:AddLine(string.format("Rested: %s", Number(restedXP)), 0.4, 0.6, 1)
        end
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- Dragging, while unlocked, and a right-click to lock it again once it is
    -- placed. Only the position is written: a drag cannot resize the bar, and
    -- reading the size back would only round it.
    bar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and NS.db.unlocked then self:StartMoving() end
    end)
    bar:SetScript("OnMouseUp", function(self, button)
        if DogsForeverUI.RightClickLock(NS, button) then return end
        if button ~= "LeftButton" or not NS.db.unlocked then return end
        self:StopMovingOrSizing()
        local db = NS.db
        db.autoPlaced = false
        db.barLeft = self:GetLeft()
        db.barTop = -1 * (GetScreenHeight() - self:GetTop())
        Refresh()
        DogsForeverUI.RefreshOptions()
    end)

    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION",
                             "PLAYER_LEVEL_UP", "PLAYER_UPDATE_RESTING", "ENABLE_XP_GAIN",
                             "DISABLE_XP_GAIN",
                             -- A reputation changing, or another one watched.
                             "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" }) do
        pcall(NS.RegisterEvent, NS, event)
    end
    NS:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            -- UIParent is unscaled at ADDON_LOADED, so a position worked out
            -- there lands in the wrong coordinate space. Only the addon's own
            -- placement is worked out again, never one the player chose.
            if NS.db.autoPlaced then Place() end
            Refresh()
            return
        end
        Update()
    end)

    function ToggleLock()
        if NS.db.unlocked then Lock() else Unlock() end
    end

    function Unlock()
        NS.db.unlocked = true
        Refresh()
    end

    function Lock()
        NS.db.unlocked = false
        bar:StopMovingOrSizing()
        Refresh()
    end

    NS.Init = Refresh
    NS.Refresh = Refresh
    NS.Lock = Lock
    NS.Unlock = Unlock
    NS.ToggleLock = ToggleLock

    DogsForeverUI:RegisterModule(NS)
end
