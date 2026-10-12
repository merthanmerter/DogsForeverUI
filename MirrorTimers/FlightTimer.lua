-- FLIGHT TIMER  (DogsForeverUI.FlightTimer)
--
-- On a flight path, a bar like the breath bar, in yellow: where you are flying
-- to on the left, the time left on the right. No setting and no command.
--
-- THE TIME LEFT is learned, not read: the game says whether you are on a taxi
-- (UnitOnTaxi) and nothing about how long the flight takes - there is no call
-- for it anywhere (C_TaxiMap has nodes and their places, no times). So each
-- route - from this flight master to that one - is timed the first time it is
-- flown, and the bar counts down on that route ever after. A route is timed
-- from getting on the taxi (UnitOnTaxi turning true) to getting off, the same
-- two moments every time, so the learned time is what the bar counts.
--
-- Until then the time is the route's length (FlightRoutes.lua, summed hop by
-- hop) over the taxi's speed - EllesmereUI's method: a speed fitted to Classic
-- flight times, nudged by every flight learned on a route of known length.
-- Only a route missing from that table shows a full bar that says
-- "Collecting time" until you land. Frequent Flier (Adventure Legacy perk,
-- per character) flies 20% faster: times are kept without it and divided by
-- it when shown. The flight map's tooltips show the same time for each
-- reachable flight point.
--
-- The times are shared by every character of the account (DogsForeverUIFlights,
-- the addon's second account-wide table): a flight is the same flight for all
-- of them. Each new flight on a route replaces its time, so a route the game
-- changes is relearned the next time it is flown. A flight cut short - an
-- early landing asked for (TaxiRequestEarlyLanding) - is not learned from.
--
-- A /reload in the air carries on: the flight in progress is kept in the same
-- table, and GetTime runs on through a reload. Logging in in the air does not:
-- the flight is unknown then, and nothing is shown.
--
-- WHERE: exactly where the game puts its first timer bar - the breath bar's
-- spot. The game's timer bars sit in MirrorTimerContainer, an Edit Mode system
-- that is hidden (and shrinks to nothing) while no timer runs, so the bar
-- cannot hang off it. Instead a holder the size of the container with one
-- timer in it (MirrorTimer.xml) is put on the container's own anchor, at its
-- scale, each time a flight starts: Edit Mode moves and the Size setting carry
-- over. Nothing of the game's is shown, hidden, moved or written.

local FlightTimer = {}
DogsForeverUI.FlightTimer = FlightTimer

do -- private scope

    local Style = DogsForeverUI.Style
    local Routes = DogsForeverUI.FlightRoutes

    -- The breath bar's size and labels (MirrorTimers.lua), in the timer bars'
    -- yellow (MirrorTimerColors' EXHAUSTION).
    local WIDTH, HEIGHT = 195, 20
    local TEXT_PADDING = 0.15
    local COLOUR = { 1.0, 0.9, 0.0 }

    -- One of the game's timer bars (MirrorTimerTemplate), which is what the
    -- container is the size of with one timer running.
    local TIMER_WIDTH, TIMER_HEIGHT = 206, 32

    local COLLECTING = "Collecting time"

    -- After a flight is taken, how long to wait for the taxi before giving up
    -- (the flight master can refuse: not enough money, in combat...).
    local BOARD_WAIT = 10
    -- Shorter than this is not a flight worth remembering.
    local MIN_FLIGHT = 5

    -- Yards a second, EllesmereUI's fit to measured Classic flight times; a
    -- learned flight more than a third off it is bad data, not a speed.
    local SPEED = 30.4
    local SPEED_STEP = 0.25

    -- Frequent Flier: node 110300 of the Adventure Legacy tree (1188).
    local LEGACY_TREE, FREQUENT_FLIER, FLIER_BONUS = 1188, 110300, 1.2

    ---------------------------------------------------------------------------
    -- The saved times.
    ---------------------------------------------------------------------------

    -- { routes = { ["From > To"] = seconds without Frequent Flier },
    --   speed = the fitted yards a second, current = the flight in progress }.
    -- DogsForeverUIFlights is pointed at this table. The same rules as every
    -- saved table of the addon (Core\Profiles.lua): looked for until read,
    -- since this client can hand it over late, and never written over unread.
    local saved = { routes = {} }
    FlightTimer.saved = saved
    local adopted = false

    -- The flight under way: { key, name, yards, started, learn, mult, total }
    -- - also saved.current, so a /reload carries it on.
    local flight
    local pending         -- a flight taken, the taxi not boarded yet
    local reloaded = false   -- this session began with a /reload
    local entered = false    -- PLAYER_ENTERING_WORLD has said which

    local function FrequentFlier()
        local config = C_Traits.GetConfigIDByTreeID(LEGACY_TREE)
        local node = config and C_Traits.GetNodeInfo(config, FREQUENT_FLIER)
        return node and (node.activeRank or 0) > 0 and FLIER_BONUS or 1
    end

    -- A route's time: learned, else its length over the speed; nil if neither.
    local function Duration(key, yards, mult)
        local seconds = key and saved.routes[key]
            or yards and yards / (saved.speed or SPEED)
        return seconds and seconds / mult
    end

    -- "Ironforge > Lakeshire" from the map's open flight master to slot.
    local function Here()
        for index = 1, NumTaxiNodes() do
            if TaxiNodeGetType(index) == "CURRENT" then return TaxiNodeName(index) end
        end
    end
    local lastHere

    local function RouteKey(slot)
        local from = Here() or lastHere
        return from and (from .. " > " .. TaxiNodeName(slot))
    end

    -- The route's length to slot, every hop's summed; nil if a hop is unknown.
    local function Yards(slot)
        local hops, mapID = GetNumRoutes(slot), GetTaxiMapID()
        if hops < 1 or not mapID then return nil end
        local ids = {}
        for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(mapID)) do
            ids[node.slotIndex] = node.nodeID
        end
        local yards = 0
        for hop = 1, hops do
            local from = ids[TaxiGetNodeSlot(slot, hop, true)]
            local to = ids[TaxiGetNodeSlot(slot, hop, false)]
            local length = from and to and Routes[from * 10000 + to]
            if not length then return nil end
            yards = yards + length
        end
        return yards
    end

    ---------------------------------------------------------------------------
    -- The bar.
    ---------------------------------------------------------------------------

    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetSize(TIMER_WIDTH, TIMER_HEIGHT)
    holder:Hide()
    FlightTimer.holder = holder

    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetSize(WIDTH, HEIGHT)
    bar:SetPoint("CENTER", holder, "CENTER", 0, 0)
    FlightTimer.bar = bar

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    Style.SetBackground(bar.bg)
    Style.Paint(bar, COLOUR)
    bar.border = Style.AddBorder(bar)
    bar.spark = Style.AddSpark(bar)
    Style.PinSpark(bar.spark, bar)

    bar.nameText = bar:CreateFontString(nil, "OVERLAY")
    bar.timeText = bar:CreateFontString(nil, "OVERLAY")
    Style.SingleLine(bar.nameText)
    Style.SingleLine(bar.timeText)
    bar.timeText:SetJustifyH("RIGHT")
    bar.timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    bar.nameText:SetJustifyH("LEFT")
    bar.nameText:SetPoint("LEFT", bar, "LEFT", 4, 0)
    bar.nameText:SetPoint("RIGHT", bar.timeText, "LEFT", -6, 0)
    Style.SetFont(bar, bar.nameText, TEXT_PADDING)
    Style.SetFont(bar, bar.timeText, TEXT_PADDING)

    -- On the game's timer bars' anchor, at their scale.
    local function Place()
        holder:ClearAllPoints()
        local container = _G.MirrorTimerContainer
        if type(container) == "table" and type(container.GetNumPoints) == "function"
            and container:GetNumPoints() > 0 then
            local point, relativeTo, relativePoint, x, y = container:GetPoint(1)
            holder:SetScale(container:GetScale() or 1)
            holder:SetPoint(point, relativeTo or UIParent, relativePoint, x, y)
        else
            -- MirrorTimer.xml's own default.
            holder:SetScale(1)
            holder:SetPoint("TOP", UIParent, "TOP", 0, -100)
        end
    end

    -- "Booty Bay, Stranglethorn" -> "Booty Bay": the place, not its zone,
    -- so the name fits beside the time.
    local function ShortName(name)
        return (name:match("^([^,]+)") or name)
    end

    -- Minutes and seconds, formatted by the font string itself: drawn every
    -- frame of a flight, so no string is built for it in Lua.
    local function SetClock(seconds)
        seconds = math.max(0, math.floor(seconds + 0.5))
        bar.timeText:SetFormattedText("%d:%02d", math.floor(seconds / 60), seconds % 60)
    end

    local function Draw()
        local total = flight.total
        if total then
            local left = math.max(0, total - (GetTime() - flight.started))
            bar:SetMinMaxValues(0, total)
            bar:SetValue(left)
            SetClock(left)
            bar.spark:SetAlpha(Style.SparkAlpha(left, total))
        else
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(1)
            bar.timeText:SetText(COLLECTING)
            bar.spark:SetAlpha(0)
        end
    end

    ---------------------------------------------------------------------------
    -- A flight.
    ---------------------------------------------------------------------------

    local function Begin(f)
        f.mult = FrequentFlier()
        f.total = Duration(f.key, f.yards, f.mult)
        flight, saved.current = f, f
        bar.nameText:SetText(ShortName(f.name))
        Place()
        Draw()
        holder:Show()
    end

    local function Land()
        local seconds = (GetTime() - flight.started) * flight.mult
        if flight.learn and flight.key and seconds >= MIN_FLIGHT then
            saved.routes[flight.key] = math.floor(seconds * 10 + 0.5) / 10
            if flight.yards then
                local speed, measured = saved.speed or SPEED, flight.yards / seconds
                if measured > speed * 0.75 and measured < speed * 1.33 then
                    saved.speed = speed + (measured - speed) * SPEED_STEP
                end
            end
        end
        flight = nil
        saved.current = nil
        holder:Hide()
    end

    bar:SetScript("OnUpdate", function()
        if not flight then holder:Hide() return end
        if not UnitOnTaxi("player") then Land() return end
        Draw()
    end)

    -- Waits for the taxi after a flight is taken; runs only while one is.
    local boarding = CreateFrame("Frame")
    boarding:Hide()
    boarding:SetScript("OnUpdate", function(self)
        if not pending then self:Hide() return end
        if UnitOnTaxi("player") then
            local p = pending
            pending = nil
            self:Hide()
            Begin({ key = p.key, name = p.name, yards = p.yards, started = GetTime(), learn = true })
        elseif GetTime() - pending.at > BOARD_WAIT then
            pending = nil
            self:Hide()
        end
    end)

    local function Taken(slot)
        if flight then return end
        local destination = TaxiNodeName(slot)
        if type(destination) ~= "string" or destination == "" then return end
        pending = { key = RouteKey(slot), name = destination, yards = Yards(slot), at = GetTime() }
        boarding:Show()
    end

    local function EarlyLanding()
        if flight then flight.learn = false end
    end

    -- A reachable flight point's tooltip on either flight map gets its time.
    local function AddTime(slot)
        local seconds = Duration(RouteKey(slot), Yards(slot), FrequentFlier())
        if not seconds then return end
        seconds = math.floor(seconds + 0.5)
        GameTooltip:AddLine(("Flight time: %d:%02d"):format(math.floor(seconds / 60), seconds % 60), 1, 1, 1)
        GameTooltip:Show()
    end

    hooksecurefunc("TaxiNodeOnButtonEnter", function(button)
        local slot = button:GetID()
        if TaxiNodeGetType(slot) == "REACHABLE" then AddTime(slot) end
    end)

    -- The newer map is load-on-demand; its pins take the mixin's function
    -- when made, so it is hooked as it loads, before the first pin.
    local function HookFlightMap()
        hooksecurefunc(FlightMap_FlightPointPinMixin, "OnMouseEnter", function(pin)
            local node = pin.taxiNodeData
            if node.state == Enum.FlightPathState.Reachable then AddTime(node.slotIndex) end
        end)
    end
    if FlightMap_FlightPointPinMixin then HookFlightMap() end

    if type(TakeTaxiNode) == "function" then
        hooksecurefunc("TakeTaxiNode", Taken)
    end
    if type(TaxiRequestEarlyLanding) == "function" then
        hooksecurefunc("TaxiRequestEarlyLanding", EarlyLanding)
    end

    -- After a /reload in the air: the flight that was under way, if it is
    -- still, on the same clock.
    local function Resume()
        if flight or not reloaded then return end
        local c = saved.current
        if type(c) == "table" and type(c.name) == "string" and type(c.started) == "number"
            and c.started <= GetTime() and UnitOnTaxi("player") then
            Begin({
                key = type(c.key) == "string" and c.key or nil,
                name = c.name,
                yards = type(c.yards) == "number" and c.yards or nil,
                started = c.started,
                learn = c.learn == true,
            })
        end
    end

    ---------------------------------------------------------------------------
    -- The saved table.
    ---------------------------------------------------------------------------

    local function Load()
        local file = DogsForeverUIFlights
        if not adopted and type(file) == "table" and file ~= saved and next(file) ~= nil then
            if type(file.routes) == "table" then
                for key, seconds in pairs(file.routes) do
                    if type(key) == "string" and type(seconds) == "number" and seconds > 0
                        and saved.routes[key] == nil then
                        saved.routes[key] = seconds
                    end
                end
            end
            if not saved.speed and type(file.speed) == "number" and file.speed > 0 then
                saved.speed = file.speed
            end
            -- The flight that was under way: kept until PLAYER_ENTERING_WORLD
            -- says whether this is a reload (then it carries on) or a login
            -- (then it is dropped) - or, the file late, dropped now if that
            -- was a login.
            if not flight and saved.current == nil and type(file.current) == "table"
                and (reloaded or not entered) then
                saved.current = file.current
            end
            adopted = true
            Resume()
        end
        DogsForeverUIFlights = saved
    end

    local function Save()
        local file = DogsForeverUIFlights
        if not adopted and type(file) == "table" and file ~= saved and next(file) ~= nil then
            return
        end
        DogsForeverUIFlights = saved
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("VARIABLES_LOADED")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ADDONS_UNLOADING")
    events:RegisterEvent("TAXIMAP_OPENED")
    events:SetScript("OnEvent", function(_, event, ...)
        if event == "ADDONS_UNLOADING" then
            Save()
            return
        end
        if event == "TAXIMAP_OPENED" then
            lastHere = Here()
            return
        end
        if event == "ADDON_LOADED" and ... == "Blizzard_FlightMap" then
            HookFlightMap()
        end
        if event == "PLAYER_ENTERING_WORLD" then
            -- Only the first says how the session began; later ones are
            -- loading screens.
            if not entered then
                local isInitialLogin, isReloadingUi = ...
                reloaded = isReloadingUi == true and not isInitialLogin
                entered = true
            end
            if not adopted then Load() end
            if reloaded then
                Resume()
            elseif not flight then
                saved.current = nil
            end
            return
        end
        if not adopted then Load() end
    end)
end
