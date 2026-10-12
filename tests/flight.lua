-- The flight path timer: a yellow bar while on a taxi, the route's time
-- learned from the first flight on it ("Collecting time" until then), the
-- times shared account-wide and kept by the core's late-file rules.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

-- The flight master: a map of nodes, Stormwind the one you stand at. `hops`
-- lists the slots a flight passes, start first; node IDs 20xx are not in
-- FlightRoutes.lua, 2/4/5/12 are (2->4 2347 yards, 2->5 3395, 5->12 1827).
onTaxi = false
function UnitOnTaxi(unit) return unit == "player" and onTaxi end
taxiNodes = {
    { name = "Stormwind, Elwynn", type = "CURRENT", nodeID = 2 },
    { name = "Ironforge, Dun Morogh", type = "REACHABLE", nodeID = 2001, hops = { 1, 2 } },
    { name = "Sentinel Hill, Westfall", type = "REACHABLE", nodeID = 2002, hops = { 1, 3 } },
    { name = "Lakeshire, Redridge", type = "REACHABLE", nodeID = 4, hops = { 1, 4 } },
    { name = "Darkshire, Duskwood", type = "REACHABLE", nodeID = 12, hops = { 1, 6, 5 } },
    { name = "Goldshire, Elwynn", type = "DISTANT", nodeID = 5 },
}
function NumTaxiNodes() return #taxiNodes end
function TaxiNodeName(i) return taxiNodes[i] and taxiNodes[i].name end
function TaxiNodeGetType(i) return taxiNodes[i] and taxiNodes[i].type or "NONE" end
function GetTaxiMapID() return 1415 end
function GetNumRoutes(i) return taxiNodes[i].hops and #taxiNodes[i].hops - 1 or 0 end
function TaxiGetNodeSlot(i, hop, source) return taxiNodes[i].hops[source and hop or hop + 1] end
C_TaxiMap = { GetAllTaxiNodes = function()
    local out = {}
    for slot, node in ipairs(taxiNodes) do out[slot] = { slotIndex = slot, nodeID = node.nodeID } end
    return out
end }
-- Frequent Flier: off until a test buys it.
frequentFlier = 0
C_Traits.GetConfigIDByTreeID = function(tree) return tree == 1188 and 40 or nil end
C_Traits.GetNodeInfo = function(config, node)
    if config == 40 and node == 110300 then return { activeRank = frequentFlier } end
end
-- The older flight map's tooltip (TaxiFrame.lua): the node's name.
function TaxiNodeOnButtonEnter(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip.lines = { TaxiNodeName(button:GetID()) }
end
local function Hover(slot)
    TaxiNodeOnButtonEnter({ GetID = function() return slot end })
    return GameTooltip.lines[2]
end
taken = {}
function TakeTaxiNode(slot) taken[#taken + 1] = slot end
earlyLandings = 0
function TaxiRequestEarlyLanding() earlyLandings = earlyLandings + 1 end

-- The game's timer bars' container, moved in Edit Mode and scaled.
local container = CreateFrame("Frame", "MirrorTimerContainer", UIParent)
container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 700, -150)
container:SetScale(1.2)

DogsForeverUIFlights = nil
LoadAddon()
Login()

local NS = DogsForeverUI.FlightTimer
local bar, holder = NS.bar, NS.holder
local Style = DogsForeverUI.Style

local function Fly(slot, seconds, step)
    TakeTaxiNode(slot)
    Tick(0.5)
    onTaxi = true
    Tick(0.1)
    local flown = 0
    step = step or 1
    while flown < seconds do Tick(step); flown = flown + step end
end
local function Arrive()
    onTaxi = false
    Tick(0.1)
end

Section("before any flight")
check("nothing shown", holder.shown == false)
check("the saved name is the live table", DogsForeverUIFlights == NS.saved)

Section("a route never flown")
TakeTaxiNode(2)
check("the game's call still made", taken[1] == 2)
Tick(0.5)
check("nothing yet: not on the taxi", holder.shown == false)
onTaxi = true
Tick(0.1)
check("on the taxi: the bar", holder.shown == true)
check("where it is flying, without the zone", bar.nameText.text == "Ironforge", bar.nameText.text)
check("says it is collecting the time", bar.timeText.text == "Collecting time", bar.timeText.text)
check("a full bar, no spark", bar.value == 1 and bar.max == 1 and bar.spark.alpha == 0)
check("in yellow, in the addon's look",
    bar.statusColor[1] == 1 and bar.statusColor[2] == 0.9 and bar.statusColor[3] == 0
    and bar:GetStatusBarTexture().texture == Style.FLAT_TEXTURE and bar.border ~= nil)
check("the breath bar's size", bar.width == 195 and bar.height == 20)
check("on the game's timer bars' anchor, at their scale",
    holder.points[1] == "TOPLEFT" and holder.points[2] == UIParent and holder.points[4] == 700
    and holder.points[5] == -150 and holder.scale == 1.2)
for _ = 1, 90 do Tick(1) end
Arrive()
check("landed: the bar goes", holder.shown == false)
local learned = NS.saved.routes["Stormwind, Elwynn > Ironforge, Dun Morogh"]
check("the route's time learned", learned and math.abs(learned - 90.1) < 0.2, tostring(learned))
check("no flight kept in progress", NS.saved.current == nil)

Section("the same route again")
Fly(2, 30)
check("counts down from what was learned", bar.max == learned and bar.timeText.text == "1:00",
    bar.timeText.text)
check("the bar empties as it goes", math.abs(bar.value - (learned - 30)) < 0.01)
check("with the spark", bar.spark.alpha == 1)
for _ = 1, 70 do Tick(1) end
check("never below nothing", bar.timeText.text == "0:00" and bar.value == 0)
Arrive()
learned = NS.saved.routes["Stormwind, Elwynn > Ironforge, Dun Morogh"]
check("each flight replaces the route's time (a changed route is relearned)",
    math.abs(learned - 100.1) < 0.2, tostring(learned))

Section("a refused flight")
TakeTaxiNode(3)
Tick(11)
onTaxi = true
Tick(0.1)
check("not boarded in time: no bar for whatever comes next", holder.shown == false)
onTaxi = false
Tick(0.1)

Section("an early landing")
Fly(3, 20)
TaxiRequestEarlyLanding()
check("the game's call still made", earlyLandings == 1)
Arrive()
check("not learned from", NS.saved.routes["Stormwind, Elwynn > Sentinel Hill, Westfall"] == nil)

Section("a route not flown, its length known")
Fly(4, 0)
local estimate = 2347 / 30.4
check("counts down from length over speed", math.abs(bar.max - estimate) < 0.01 and bar.timeText.text == "1:17",
    bar.timeText.text)
for _ = 1, 70 do Tick(1) end
Arrive()
local lakeshire = NS.saved.routes["Stormwind, Elwynn > Lakeshire, Redridge"]
check("learned all the same", lakeshire and math.abs(lakeshire - 70.1) < 0.2, tostring(lakeshire))
local speed = 30.4 + (2347 / lakeshire - 30.4) * 0.25
check("the speed nudged a quarter towards the flight's", math.abs(NS.saved.speed - speed) < 0.001,
    tostring(NS.saved.speed))
Fly(4, 0)
check("the learned time wins over the length", bar.max == lakeshire)
Arrive()
NS.saved.routes["Stormwind, Elwynn > Lakeshire, Redridge"] = lakeshire

Section("a speed far off is not taken")
Fly(5, 400)
Arrive()
check("route learned, speed left alone", NS.saved.routes["Stormwind, Elwynn > Darkshire, Duskwood"]
    and math.abs(NS.saved.speed - speed) < 0.001)
NS.saved.routes["Stormwind, Elwynn > Darkshire, Duskwood"] = nil

Section("the flight map's tooltips")
local function Clock(s) s = math.floor(s + 0.5) return ("Flight time: %d:%02d"):format(math.floor(s / 60), s % 60) end
check("a learned route: its time", Hover(2) == Clock(NS.saved.routes["Stormwind, Elwynn > Ironforge, Dun Morogh"]),
    tostring(GameTooltip.lines[2]))
check("two hops: both lengths over the speed", Hover(5) == Clock((3395 + 1827) / speed), tostring(GameTooltip.lines[2]))
check("an unknown route: nothing added", Hover(3) == nil)
check("where you stand: nothing added", Hover(1) == nil)
frequentFlier = 1
check("Frequent Flier: 20% faster", Hover(5) == Clock((3395 + 1827) / speed / 1.2), tostring(GameTooltip.lines[2]))
Fly(2, 50)
Arrive()
check("learned without the perk", math.abs(NS.saved.routes["Stormwind, Elwynn > Ironforge, Dun Morogh"] - 50.1 * 1.2) < 0.3)
NS.saved.routes["Stormwind, Elwynn > Ironforge, Dun Morogh"] = learned
frequentFlier = 0
Enum.FlightPathState = Enum.FlightPathState or { Current = 0, Reachable = 1, Unreachable = 2 }
FlightMap_FlightPointPinMixin = { OnMouseEnter = function(pin) GameTooltip.lines = { pin.taxiNodeData.name } end }
Fire("ADDON_LOADED", "Blizzard_FlightMap")
local function Pin(slot, state)
    FlightMap_FlightPointPinMixin.OnMouseEnter({ taxiNodeData = { slotIndex = slot, state = state, name = "x" } })
    return GameTooltip.lines[2]
end
check("the newer map: a reachable pin gets the time", Pin(5, Enum.FlightPathState.Reachable) == Clock((3395 + 1827) / speed))
check("the newer map: other pins nothing", Pin(5, Enum.FlightPathState.Unreachable) == nil)

Section("a /reload in the air")
Fly(3, 40)
local file = DogsForeverUIFlights
check("the flight in progress is kept", file.current and file.current.name == "Sentinel Hill, Westfall")
Fire("ADDONS_UNLOADING")
Reload(nil)
DogsForeverUIFlights = file
Fire("ADDON_LOADED", "DogsForeverUI")
Fire("PLAYER_ENTERING_WORLD", false, true)
NS = DogsForeverUI.FlightTimer
bar, holder = NS.bar, NS.holder
check("carries on: the bar again", holder.shown == true and bar.nameText.text == "Sentinel Hill")
check("the times read back", NS.saved.routes["Stormwind, Elwynn > Ironforge, Dun Morogh"] == learned)
for _ = 1, 20 do Tick(1) end
Arrive()
local westfall = NS.saved.routes["Stormwind, Elwynn > Sentinel Hill, Westfall"]
check("learned on the same clock across the reload", westfall and math.abs(westfall - 60.1) < 0.3,
    tostring(westfall))

Section("logging in in the air")
DogsForeverUIFlights.current = { key = "A > B", name = "B", started = now - 5, learn = true }
local saved = DogsForeverUIFlights
Reload(nil)
DogsForeverUIFlights = saved
onTaxi = true
Fire("ADDON_LOADED", "DogsForeverUI")
Fire("PLAYER_ENTERING_WORLD", true, false)
NS = DogsForeverUI.FlightTimer
check("the flight is unknown: nothing shown", NS.holder.shown == false and NS.saved.current == nil)
onTaxi = false

Section("a file that turns up late")
Reload(nil)
DogsForeverUIFlights = nil
Fire("ADDON_LOADED", "DogsForeverUI")
NS = DogsForeverUI.FlightTimer
Fire("PLAYER_ENTERING_WORLD", true, false)
NS.saved.routes["X > Y"] = 50
DogsForeverUIFlights = { routes = { ["P > Q"] = 70, ["X > Y"] = 10 } }
Fire("PLAYER_ENTERING_WORLD", false, false)
check("read when it arrives, merged with what was learned first",
    NS.saved.routes["P > Q"] == 70 and NS.saved.routes["X > Y"] == 50
    and DogsForeverUIFlights == NS.saved)

Section("a file never read is not written over")
Reload(nil)
DogsForeverUIFlights = nil
Fire("ADDON_LOADED", "DogsForeverUI")
local untouched = { routes = { ["K > L"] = 33 } }
DogsForeverUIFlights = untouched
Fire("ADDONS_UNLOADING")
check("left exactly where it is", DogsForeverUIFlights == untouched)

Summary()
