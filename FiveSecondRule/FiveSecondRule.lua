-- MODULE: Five Second Rule  (DogsForeverUI.FiveSecondRule, settings section "fsr")
--
-- Counts down the five-second rule after you spend mana, and is gone the rest
-- of the time.
--
-- Part of the castbar group, the way the swing bars are: it sits just above
-- the castbar, under the swing bars, in the row it shares with the combo
-- points (nobody needs both: a rogue has no mana), and goes wherever the
-- castbar goes until it is dragged somewhere of its own; it takes its size,
-- strata, text padding, spark and seconds from the castbar's settings; it is
-- unlocked and locked with the castbar; and its one
-- switch, Five second rule, sits in the options' Castbars section. It has no
-- section of its own.

DogsForeverUI.FiveSecondRule = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.FiveSecondRule
    local POWER_MANA = 0   -- Enum.PowerType.Mana; the only pool this module tracks

    local onEvent, onUpdate
    local TriggerFSR, SpellHasManaCost, Refresh

    NS.key = "fsr"
    NS.title = "5SR"

    -- Only what is its own: everything else is the castbar's (see above).
    NS.defaults = {
        enabled = true,
    }

    -- Saved keys that are not settings: where the bar was dragged to, once it
    -- has been. Until then it has no position of its own.
    NS.placement = { barLeft = true, barTop = true, placed = true }

    NS.mp5StartTime = 0

    -- Set when a mana-costing cast lands. The next mana change inside this window
    -- is that cast's cost, and that is what starts the five seconds.
    local castPendingUntil = 0

    -- SECRET VALUES
    -- UnitPower and its relatives hand addon code a "secret number": it can be
    -- stored and passed to APIs that accept one, but reading it, comparing it or
    -- doing arithmetic on it is an error. Nothing here inspects a power value --
    -- the five-second rule is driven by events instead.
    local IsSecret = issecretvalue

    NS:RegisterEvent("PLAYER_ENTERING_WORLD")
    NS:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    NS:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    NS:SetScript("OnEvent", function(_, event, arg1, ...) onEvent(event, arg1, ...) end)

    -- Whether this character's class has mana at all: not a warrior, not a
    -- rogue. What the castbar group keeps a row for.
    function NS.ClassHasMana()
        local _, class = UnitClass("player")
        if IsSecret(class) then return true end
        return class ~= "WARRIOR" and class ~= "ROGUE"
    end

    -- First start, and after a reset: a reset leaves it back in its row.
    function NS.Init()
        -- Nothing to track for a class with no mana.
        NS.noMana = not NS.ClassHasMana()
        if NS.noMana then
            NS:SetScript("OnUpdate", nil)
            NS.StatusBar.statusbar:Hide()
            return
        end

        NS:SetScript("OnUpdate", onUpdate)
        Refresh()
    end

    function onEvent(event, arg1, ...)
        local db = NS.db

        if event == "PLAYER_ENTERING_WORLD" then
            Refresh()
            return
        end

        if not db.enabled or NS.noMana then return end

        if event == "UNIT_POWER_UPDATE" then
            -- The one power signal that survives secret values: the player's mana
            -- moved. Landing inside the window after a mana-costing cast makes it
            -- that cast's cost, which a free (Clearcasting-style) cast never
            -- produces.
            local powerToken = ...
            if arg1 == "player" and (IsSecret(powerToken) or powerToken == "MANA")
               and GetTime() <= castPendingUntil then
                TriggerFSR()
            end

        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            if arg1 == "player" and SpellHasManaCost(select(2, ...)) then
                castPendingUntil = GetTime() + 0.4
            end
        end
    end

    function onUpdate()
        if not NS.db.enabled or UnitIsDead("player") then
            NS.StatusBar.statusbar:Hide()
            return
        end

        NS.StatusBar:OnUpdate()
    end

    function TriggerFSR()
        NS.mp5StartTime = GetTime() + 5
        castPendingUntil = 0

        NS.StatusBar.statusbar:Show()
    end

    function SpellHasManaCost(spellID)
        if not spellID or IsSecret(spellID) then
            return true   -- cannot tell; the power change still has to happen
        end

        local costs = C_Spell.GetSpellPowerCost(spellID)
        if not costs then return false end

        for _, cost in ipairs(costs) do
            if cost.type == POWER_MANA
               and ((cost.cost or 0) > 0 or (cost.minCost or 0) > 0) then
                return true
            end
        end

        return false
    end

    function Refresh()
        NS.StatusBar:Refresh()
    end

    -- Switching it on or off can take the row away from, or give it back to,
    -- the swing bars above it: the whole castbar group is laid out again, and
    -- that redraws this bar too.
    function NS.Refresh()
        DogsForeverUI.Castbar.Refresh()
    end
    NS.Redraw = Refresh

    DogsForeverUI:RegisterModule(NS)
end
