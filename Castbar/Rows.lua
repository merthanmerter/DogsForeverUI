-- The castbar group's row over the castbar (Castbar.JoinRow): the five-second
-- rule and combo points, a module each. A class has one or the other, a druid both.

-------------------------------------------------------------------------------
-- MODULE: Five Second Rule  (DogsForeverUI.FiveSecondRule, settings section "fsr")
-- Counts down the five-second rule after mana is spent; gone the rest of the
-- time. Driven by events alone: no power value is ever read.
-------------------------------------------------------------------------------

DogsForeverUI.FiveSecondRule = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.FiveSecondRule
    local Style = DogsForeverUI.Style
    local Castbar = DogsForeverUI.Castbar
    local IsSecret = issecretvalue

    local DELAY = 5
    local PENDING = 0.4                      -- a cast's mana change arrives within this
    local MANA = Enum.PowerType.Mana

    NS.key = "fsr"
    NS.title = "5SR"

    local countdownEnd = 0                   -- when the five seconds are up; 0 for none
    local pendingUntil = 0                   -- a mana-costing cast landed: its cost moves mana before this
    local noMana = false

    local bar = CreateFrame("StatusBar", "DogsForeverUIFiveSecondBar", UIParent)
    bar:Hide()
    bar:SetMinMaxValues(0, DELAY)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.border = Style.AddBorder(bar)
    bar.spark = Style.AddSpark(bar)
    bar.label = bar:CreateFontString(nil, "OVERLAY")
    NS.bar = bar

    local Place = Castbar.JoinRow(NS, bar, "5SR")

    -- Not a warrior, not a rogue: what the castbar group keeps a row for.
    function NS.ClassHasMana()
        local _, class = UnitClass("player")
        if IsSecret(class) then return true end
        return class ~= "WARRIOR" and class ~= "ROGUE"
    end

    -- On mana now: not in cat (the combo points' turn) or bear form. A form
    -- the client keeps secret counts as mana.
    local function ManaActive()
        local powerType, token = UnitPowerType("player")
        if IsSecret(powerType) or IsSecret(token) then return true end
        if token ~= nil then return token == "MANA" end
        return powerType == nil or powerType == MANA
    end

    -- One the client will not name might: the mana change still has to follow.
    local function SpellHasManaCost(spellID)
        if IsSecret(spellID) or not spellID then return true end
        local costs = C_Spell.GetSpellPowerCost(spellID)
        if not costs then return false end
        for _, cost in ipairs(costs) do
            if cost.type == MANA and ((cost.cost or 0) > 0 or (cost.minCost or 0) > 0) then
                return true
            end
        end
        return false
    end

    -- Unlocked: as it really looks, a countdown just begun.
    local function ShowPreview()
        Style.ShowNow(bar)
        bar:SetValue(DELAY)
        bar.label:SetFormattedText("%.1fs", DELAY)
        bar.spark:Hide()
    end

    local function Redraw()
        Place()
        Style.Paint(bar, Style.COUNTDOWN_COLOR)
        Style.SetBackground(bar.bg)
        local label = bar.label
        label:ClearAllPoints()
        Style.SingleLine(label)
        Style.SetFont(bar, label, Castbar.db.textPadding)
        label:SetJustifyH("LEFT")
        label:SetPoint("LEFT", bar, "LEFT", 4, 0)
        label:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        bar.spark:SetHeight(NS.db.barHeight * Style.SPARK_HEIGHT)
        -- A countdown running is left to OnUpdate; with none the bar goes at once.
        if Castbar.db.unlocked and not noMana then
            ShowPreview()
        elseif noMana or countdownEnd <= 0 or not ManaActive() then
            Style.HideNow(bar)
        end
        NS:Show()
    end

    -- Runs only while there is something to draw: a countdown, or the group
    -- being placed. Hidden otherwise; events still arrive.
    NS:SetScript("OnUpdate", function()
        local unlocked = Castbar.db.unlocked
        if noMana or UnitIsDead("player") then
            Style.HideNow(bar)
        elseif unlocked then
            ShowPreview()
        elseif not ManaActive() then
            Style.HideNow(bar)               -- cat or bear form: out of sight, still counting
        else
            local remaining = countdownEnd - GetTime()
            if countdownEnd <= 0 or remaining < 0 then
                countdownEnd = 0
                Style.FadeOut(bar)
            else
                bar:SetValue(remaining)
                bar.label:SetFormattedText("%.1fs", remaining)
                bar.spark:Show()
                bar.spark:SetPoint("CENTER", bar, "LEFT", bar:GetWidth() * remaining / DELAY, 0)
                Style.FadeIn(bar)
            end
        end
        if not unlocked and (countdownEnd <= 0 or GetTime() > countdownEnd) then NS:Hide() end
    end)

    NS:RegisterEvent("PLAYER_ENTERING_WORLD")
    NS:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    NS:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    NS:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            Redraw()
        elseif noMana then
            return
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local _, _, spellID = ...
            if SpellHasManaCost(spellID) then pendingUntil = GetTime() + PENDING end
        elseif GetTime() <= pendingUntil then
            -- Mana moving just after a mana-costing cast is its cost (a free
            -- cast never moves it): the one power signal secret values leave.
            local _, powerToken = ...
            if IsSecret(powerToken) or powerToken == "MANA" then
                countdownEnd = GetTime() + DELAY
                pendingUntil = 0
                NS:Show()                    -- brought out by the next OnUpdate, fading in
            end
        end
    end)

    function NS.Init()
        noMana = not NS.ClassHasMana()
        Redraw()
    end

    NS.Redraw = Redraw

    DogsForeverUI:RegisterModule(NS)
end

-------------------------------------------------------------------------------
-- MODULE: Combo points  (DogsForeverUI.ComboPoints, settings section "combo")
-- A rogue's (or cat druid's) combo points: one bar split into a segment per
-- point, shown while there are points. The game's gems are held off the target.
-- The count is never read (SecretWhenUnitPowerRestricted): every segment,
-- ranged over its own point, is handed it and clamps it.
-------------------------------------------------------------------------------

DogsForeverUI.ComboPoints = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.ComboPoints
    local Style = DogsForeverUI.Style
    local Castbar = DogsForeverUI.Castbar
    local IsSecret = issecretvalue

    local COMBO_POINTS = Enum.PowerType.ComboPoints
    local DEFAULT_MAX, MOST = 5, 10          -- segments when the game will not say; never more
    local DIVIDER = 1                        -- the gold hairline between two segments

    NS.key = "combo"
    NS.title = "Combo"

    local bar = CreateFrame("Frame", "DogsForeverUIComboBar", UIParent)
    bar:Hide()
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.border = Style.AddBorder(bar)
    local segments, dividers = {}, {}
    NS.bar = bar
    NS.segments = segments

    local Place = Castbar.JoinRow(NS, bar, "Combo Points")

    -- A rogue or a druid: what the castbar group keeps a row for.
    function NS.ClassUses()
        local _, class = UnitClass("player")
        if IsSecret(class) then return false end
        return class == "ROGUE" or class == "DRUID"
    end

    -- Points right now: a rogue always, a druid in cat form (on energy).
    local function UsesComboPoints()
        if not NS.ClassUses() then return false end
        local _, class = UnitClass("player")
        if class == "ROGUE" then return true end
        local _, token = UnitPowerType("player")
        return not IsSecret(token) and token == "ENERGY"
    end

    local function MaxPoints()
        local max = UnitPowerMax("player", COMBO_POINTS)
        if IsSecret(max) or max <= 0 then return DEFAULT_MAX end
        return math.min(max, MOST)
    end

    -- A readable count says itself; a secret one shows while there is a target.
    local function HasPoints(points)
        if IsSecret(points) then return UnitExists("target") end
        return points > 0
    end

    -- As many segments as there can be points, sharing the bar's width.
    local function Layout()
        local db = NS.db
        local count = MaxPoints()
        local width = (db.barWidth - (count - 1) * DIVIDER) / count
        local c = Style.BORDER_COLOR
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

    -- Fades in and out; being placed or `settled` (a settings change), at once.
    local function Update(settled)
        if Castbar.db.unlocked then
            -- As it really looks: every point lit.
            for _, segment in ipairs(segments) do segment:SetValue(#segments) end
            if UsesComboPoints() then Style.ShowNow(bar) else Style.HideNow(bar) end
            return
        end
        -- Every segment gets the count, shown or not: none keeps an old one.
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

    -- The game's gems sit on UIParent by the target frame and show again at
    -- every point: held down from their OnShow. Not protected, so safe in combat.
    ComboFrame:HookScript("OnShow", function(self) self:Hide() end)

    local function Redraw()
        Place()
        Style.SetBackground(bar.bg)
        Layout()
        ComboFrame:Hide()
        Update(true)
    end

    NS:RegisterEvent("PLAYER_ENTERING_WORLD")
    NS:RegisterEvent("PLAYER_TARGET_CHANGED")
    NS:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    for _, event in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
        NS:RegisterUnitEvent(event, "player")
    end
    NS:SetScript("OnEvent", function(_, event, _, powerType)
        if event == "PLAYER_ENTERING_WORLD" then
            Redraw()
        elseif event == "UNIT_MAXPOWER" then
            Layout()
            Update()
        elseif event == "UNIT_POWER_FREQUENT" and not IsSecret(powerType)
               and (powerType == "MANA" or powerType == "RAGE") then
            return                           -- never combo points; a change of form has its own events
        else
            Update()
        end
    end)

    NS.Init = Redraw
    NS.Redraw = Redraw

    DogsForeverUI:RegisterModule(NS)
end
