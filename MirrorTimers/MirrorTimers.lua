-- MODULE: Mirror timers  (DogsForeverUI.MirrorTimers, DogsForeverUI.FlightTimer)
--
-- The game's timer bars (breath, fatigue, feign death) in the addon's look,
-- and a flight path timer like them. No settings, no commands. Nothing of the
-- game's is shown, hidden, moved or given a field; its timer bars are faded.

DogsForeverUI.MirrorTimers = {}
DogsForeverUI.FlightTimer = {}

do -- private scope
    local NS = DogsForeverUI.MirrorTimers
    local Flight = DogsForeverUI.FlightTimer
    local Style = DogsForeverUI.Style
    local Routes = DogsForeverUI.FlightRoutes
    local IsSecret = issecretvalue

    -- The game's bar's width (MirrorTimer.xml) and the castbar's height, so
    -- the label fits inside the bar.
    local WIDTH, HEIGHT = 195, 20
    local TEXT_PADDING = 0.15

    -- The classic timer bars' own colours (MirrorTimerColors).
    local COLOURS = {
        BREATH     = { 0.0, 0.5, 1.0 },
        EXHAUSTION = { 1.0, 0.9, 0.0 },
        DEATH      = { 1.0, 0.7, 0.0 },
        FEIGNDEATH = { 1.0, 0.7, 0.0 },
    }
    local OTHER_COLOUR = COLOURS.EXHAUSTION

    -- A bar in the breath bar's look, centred on `parent`: the castbar's two
    -- labels, a name on the left and the time on the right.
    local function NewBar(parent, colour)
        local bar = CreateFrame("StatusBar", nil, parent)
        bar:SetSize(WIDTH, HEIGHT)
        bar:SetPoint("CENTER", parent, "CENTER", 0, 0)
        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints(bar)
        Style.SetBackground(bar.bg)
        Style.Paint(bar, colour)
        bar.border = Style.AddBorder(bar)
        bar.spark = Style.AddSpark(bar)
        Style.PinSpark(bar.spark, bar)
        bar.nameText = bar:CreateFontString(nil, "OVERLAY")
        bar.timeText = bar:CreateFontString(nil, "OVERLAY")
        Style.BarLabels(bar, bar.nameText, bar.timeText, TEXT_PADDING)
        return bar
    end

    ---------------------------------------------------------------------------
    -- The game's timer bars: one of ours on each (MirrorTimerContainer's), its
    -- child, so it goes, scales and shows with it, even in Edit Mode. The
    -- game's bar is read every frame and handed on; secret values untouched.
    ---------------------------------------------------------------------------

    local ours = {}                          -- the game's timer frame -> our bar on it
    NS.bars = ours

    local function Draw(bar)
        local timer = bar.timer
        local kind = timer.timer
        if bar.kind ~= kind then
            bar.kind = kind
            local c = COLOURS[kind] or OTHER_COLOUR
            bar:SetStatusBarColor(c[1], c[2], c[3], 1)
        end
        if not kind then
            -- Edit Mode showing where the bars sit, no timer running.
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            bar.nameText:SetText("Timer bar")
            bar.timeText:SetText("")
            bar.spark:SetAlpha(0)
            return
        end
        local low, high = timer.StatusBar:GetMinMaxValues()
        local value = timer.StatusBar:GetValue()
        bar:SetMinMaxValues(low, high)
        bar:SetValue(value)
        bar.nameText:SetText(timer.Text:GetText())
        if IsSecret(value) or IsSecret(low) or IsSecret(high) then
            bar.timeText:SetFormattedText("%.1f", value)
            bar.spark:SetAlpha(0)
        else
            bar.timeText:SetFormattedText("%.1f", math.max(0, value))
            bar.spark:SetAlpha(Style.SparkAlpha(value - low, high - low))
        end
    end

    -- Each of the game's bars once, faded whole: nothing of the game's writes
    -- those alphas. Blizzard_MirrorTimer loads before the addon; the events
    -- are there in case it ever comes later.
    local function Take()
        local container = MirrorTimerContainer
        if not (container and container.mirrorTimers) then return end
        for _, timer in ipairs(container.mirrorTimers) do
            if not ours[timer] then
                local bar = NewBar(timer, OTHER_COLOUR)
                bar:SetFrameLevel(timer:GetFrameLevel() + 2)
                bar.timer = timer
                bar:SetScript("OnUpdate", Draw)  -- only while the game's bar is shown
                ours[timer] = bar
                timer.StatusBar:SetAlpha(0)
                for _, region in ipairs({ timer:GetRegions() }) do region:SetAlpha(0) end
                Draw(bar)
            end
        end
    end
    Take()

    ---------------------------------------------------------------------------
    -- The flight timer: on a taxi, where to on the left, the time left on the
    -- right, in the timer bars' yellow. The game says nothing of a flight's
    -- length, so each route is timed the first time it is flown (boarding to
    -- landing); until then its length (FlightRoutes.lua) over the taxi's speed,
    -- EllesmereUI's method; a route missing there says "Collecting time".
    -- Frequent Flier flies 20% faster: times are kept without it. Shared by
    -- the account (DogsForeverUIFlights); a /reload in the air carries on.
    ---------------------------------------------------------------------------

    local TIMER_WIDTH, TIMER_HEIGHT = 206, 32   -- MirrorTimerTemplate: the container with one timer
    local BOARD_WAIT = 10                    -- the flight master can refuse: given up after this
    local MIN_FLIGHT = 5                     -- shorter is not worth remembering
    -- Yards a second, EllesmereUI's fit to Classic flight times; a flight more
    -- than a third off it is bad data, not a speed.
    local SPEED, SPEED_STEP = 30.4, 0.25
    -- Frequent Flier: node 110300 of the Adventure Legacy tree (1188).
    local LEGACY_TREE, FREQUENT_FLIER, FLIER_BONUS = 1188, 110300, 1.2

    -- { routes = { ["From > To"] = seconds without Frequent Flier }, speed,
    --   current = the flight in progress }. The core's saved-table rules:
    -- looked for until read (it can arrive late), never written over unread.
    local saved = { routes = {} }
    Flight.saved = saved
    local adopted = false

    local flight                             -- { key, name, yards, started, learn, mult, total }
    local pending                            -- a flight taken, the taxi not boarded yet
    local reloaded, entered = false, false   -- this session began with a /reload; PEW has said
    local lastHere

    local function FrequentFlier()
        local config = C_Traits.GetConfigIDByTreeID(LEGACY_TREE)
        local node = config and C_Traits.GetNodeInfo(config, FREQUENT_FLIER)
        return node and (node.activeRank or 0) > 0 and FLIER_BONUS or 1
    end

    -- Learned, else its length over the speed; nil if neither.
    local function Duration(key, yards, mult)
        local seconds = key and saved.routes[key] or yards and yards / (saved.speed or SPEED)
        return seconds and seconds / mult
    end

    local function Here()
        for index = 1, NumTaxiNodes() do
            if TaxiNodeGetType(index) == "CURRENT" then return TaxiNodeName(index) end
        end
    end

    -- "Ironforge > Lakeshire": the open flight master to slot.
    local function RouteKey(slot)
        local from = Here() or lastHere
        return from and (from .. " > " .. TaxiNodeName(slot))
    end

    -- Every hop's length summed; nil if one is unknown.
    local function Yards(slot)
        local hops, mapID = GetNumRoutes(slot), GetTaxiMapID()
        if hops < 1 or not mapID then return nil end
        local ids = {}
        for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(mapID)) do ids[node.slotIndex] = node.nodeID end
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

    local function MinutesSeconds(seconds)
        seconds = math.max(0, math.floor(seconds + 0.5))
        return math.floor(seconds / 60), seconds % 60
    end

    -- The game's timer container hides and shrinks with no timer running, so
    -- the bar hangs off a holder of one timer's size put on its anchor.
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetSize(TIMER_WIDTH, TIMER_HEIGHT)
    holder:Hide()
    Flight.holder = holder
    local bar = NewBar(holder, COLOURS.EXHAUSTION)
    Flight.bar = bar

    -- On the game's timer bars' anchor, at their scale: Edit Mode carries over.
    local function Place()
        local container = MirrorTimerContainer
        holder:ClearAllPoints()
        if container and container:GetNumPoints() > 0 then
            local point, relativeTo, relativePoint, x, y = container:GetPoint(1)
            holder:SetScale(container:GetScale())
            holder:SetPoint(point, relativeTo or UIParent, relativePoint, x, y)
        else
            holder:SetScale(1)
            holder:SetPoint("TOP", UIParent, "TOP", 0, -100)   -- MirrorTimer.xml's default
        end
    end

    local function DrawFlight()
        local total = flight.total
        if total then
            local left = math.max(0, total - (GetTime() - flight.started))
            bar:SetMinMaxValues(0, total)
            bar:SetValue(left)
            bar.timeText:SetFormattedText("%d:%02d", MinutesSeconds(left))
            bar.spark:SetAlpha(Style.SparkAlpha(left, total))
        else
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(1)
            bar.timeText:SetText("Collecting time")
            bar.spark:SetAlpha(0)
        end
    end

    local function Begin(f)
        f.mult = FrequentFlier()
        f.total = Duration(f.key, f.yards, f.mult)
        flight, saved.current = f, f
        -- "Booty Bay, Stranglethorn" -> "Booty Bay": fits beside the time.
        bar.nameText:SetText(f.name:match("^([^,]+)") or f.name)
        Place()
        DrawFlight()
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
        flight, saved.current = nil, nil
        holder:Hide()
    end

    bar:SetScript("OnUpdate", function()
        if not flight then
            holder:Hide()
        elseif not UnitOnTaxi("player") then
            Land()
        else
            DrawFlight()
        end
    end)

    -- Waits for the taxi after a flight is taken; runs only while one is.
    local boarding = CreateFrame("Frame")
    boarding:Hide()
    boarding:SetScript("OnUpdate", function(self)
        if pending and UnitOnTaxi("player") then
            Begin({ key = pending.key, name = pending.name, yards = pending.yards, started = GetTime(), learn = true })
        elseif pending and GetTime() - pending.at <= BOARD_WAIT then
            return
        end
        pending = nil
        self:Hide()
    end)

    hooksecurefunc("TakeTaxiNode", function(slot)
        if flight then return end
        local destination = TaxiNodeName(slot)
        if type(destination) ~= "string" or destination == "" then return end
        pending = { key = RouteKey(slot), name = destination, yards = Yards(slot), at = GetTime() }
        boarding:Show()
    end)
    -- A flight cut short is not learned from.
    hooksecurefunc("TaxiRequestEarlyLanding", function()
        if flight then flight.learn = false end
    end)

    -- A reachable flight point's tooltip, on either flight map, gets its time.
    local function AddTime(slot)
        local seconds = Duration(RouteKey(slot), Yards(slot), FrequentFlier())
        if not seconds then return end
        GameTooltip:AddLine(("Flight time: %d:%02d"):format(MinutesSeconds(seconds)), 1, 1, 1)
        GameTooltip:Show()
    end
    hooksecurefunc("TaxiNodeOnButtonEnter", function(button)
        local slot = button:GetID()
        if TaxiNodeGetType(slot) == "REACHABLE" then AddTime(slot) end
    end)
    -- The newer map is load-on-demand, its pins given the mixin's function as
    -- they are made: hooked as it loads.
    local function HookFlightMap()
        hooksecurefunc(FlightMap_FlightPointPinMixin, "OnMouseEnter", function(pin)
            local node = pin.taxiNodeData
            if node.state == Enum.FlightPathState.Reachable then AddTime(node.slotIndex) end
        end)
    end
    if FlightMap_FlightPointPinMixin then HookFlightMap() end

    -- After a /reload in the air: the flight under way, on the same clock.
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

    -- A file there, not yet read: never written over.
    local function Unread(file)
        return not adopted and type(file) == "table" and file ~= saved and next(file) ~= nil
    end

    local function Load()
        local file = DogsForeverUIFlights
        if Unread(file) then
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
            -- The flight under way: kept until PLAYER_ENTERING_WORLD says reload
            -- (carried on) or login (dropped); dropped now if a login was said.
            if not flight and saved.current == nil and type(file.current) == "table"
               and (reloaded or not entered) then
                saved.current = file.current
            end
            adopted = true
            Resume()
        end
        DogsForeverUIFlights = saved
    end

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "ADDON_LOADED", "VARIABLES_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
                             "ADDONS_UNLOADING", "TAXIMAP_OPENED" }) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", function(_, event, ...)
        if event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" then Take() end
        if event == "ADDONS_UNLOADING" then
            if not Unread(DogsForeverUIFlights) then DogsForeverUIFlights = saved end
            return
        elseif event == "TAXIMAP_OPENED" then
            lastHere = Here()
            return
        elseif event == "ADDON_LOADED" and ... == "Blizzard_FlightMap" then
            HookFlightMap()
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Only the first says how the session began; later ones are loading screens.
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
