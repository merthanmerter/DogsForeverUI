-- The breath bar, and the game's other timer bars: the addon's own bar on each
-- of the game's, going wherever the game's goes, the game's faded, the game's
-- numbers handed on, and nothing of the game's touched beyond its alpha.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

LoadAddon()

-- The game's timer bars, as MirrorTimer.xml builds them: a container with three
-- timer frames, each with its bar and, as its own regions, the box its label
-- sits in, a background, the label and the frame art. It arrives after the
-- addon here, so the addon has to go and find it.
local container = CreateFrame("Frame", "MirrorTimerContainer", UIParent)
container.mirrorTimers = {}
for i = 1, 3 do
    local timer = CreateFrame("Frame", nil, container)
    timer:SetSize(206, 32)
    timer:SetFrameLevel(10)
    timer.StatusBar = CreateFrame("StatusBar", nil, timer)
    timer.TextBorder = timer:CreateTexture(nil, "BACKGROUND")
    timer:CreateTexture(nil, "BACKGROUND")          -- the background, no key
    timer.Text = timer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timer.Border = timer:CreateTexture(nil, "OVERLAY")
    timer.shown = false
    container.mirrorTimers[i] = timer
end
local function Keys(t)
    local keys = {}
    for k in pairs(t) do keys[k] = true end
    return keys
end
local before = Keys(container.mirrorTimers[1])

Login()

local NS = DogsForeverUI.MirrorTimers
local game = container.mirrorTimers[1]
local bar = NS.bars[game]
local Style = DogsForeverUI.Style

-- A timer starting, as MirrorTimerMixin:Setup has it.
local function Start(timer, kind, label, max, value)
    timer.timer = kind
    timer.StatusBar:SetMinMaxValues(0, max)
    timer.StatusBar:SetValue(value)
    timer.Text:SetText(label)
    timer.shown = true
end

Section("the addon's bars on the game's")
check("one on each of the game's three, found once the game's UI is there",
    NS.bars[container.mirrorTimers[1]] ~= nil and NS.bars[container.mirrorTimers[2]] ~= nil
    and NS.bars[container.mirrorTimers[3]] ~= nil)
check("a child of the game's bar, so it goes, scales, shows and hides with it",
    bar.parent == game)
check("centred on it, the game's width and the castbar's height",
    bar.points[1] == "CENTER" and bar.points[2] == game and bar.points[3] == "CENTER"
    and bar.width == 195 and bar.height == 20)
check("drawn over it", bar.frameLevel > game:GetFrameLevel())
check("in the addon's look: flat fill, black background, the border",
    bar:GetStatusBarTexture().texture == Style.FLAT_TEXTURE and bar.bg ~= nil and bar.border ~= nil)
Fire("PLAYER_ENTERING_WORLD")
check("made once, not again", NS.bars[game] == bar)

Section("the game's own, faded")
check("its bar", game.StatusBar.alpha == 0)
check("and every part round it: the label's box, the background, the label, the frame art",
    game.TextBorder.alpha == 0 and game.regions[2].alpha == 0 and game.Text.alpha == 0
    and game.Border.alpha == 0)
check("hidden by nothing: still shown and hidden by the game alone", game.shown == false)

Section("holding your breath")
Start(game, "BREATH", "Breath", 60, 45)
Tick()
check("the game's range and value, handed on", bar.min == 0 and bar.max == 60 and bar.value == 45)
check("its label on the left, the seconds left on the right",
    bar.nameText.text == "Breath" and bar.timeText.text == "45.0", bar.timeText.text)
check("in the breath bar's blue", bar.statusColor[1] == 0 and bar.statusColor[2] == 0.5
    and bar.statusColor[3] == 1)
check("with the spark on its edge", bar.spark.alpha == 1)
game.StatusBar:SetValue(12.34)
Tick()
check("following the game's bar down", bar.value == 12.34 and bar.timeText.text == "12.3")
game.StatusBar:SetValue(-0.2)
Tick()
check("never a negative time", bar.timeText.text == "0.0")

Section("fatigue")
local second = container.mirrorTimers[2]
Start(second, "EXHAUSTION", "Fatigue", 60, 30)
Tick()
local fatigue = NS.bars[second]
check("in its own yellow, on its own bar",
    fatigue.statusColor[1] == 1 and fatigue.statusColor[2] == 0.9 and fatigue.nameText.text == "Fatigue")

Section("a secret value")
local secret = setmetatable({}, { __tostring = function() return "secret" end })
secretValues[secret] = true
game.StatusBar.value = secret
local ok, err = pcall(Tick)
check("raises nothing", ok, tostring(err))
check("handed to the bar untouched, with no spark", bar.value == secret and bar.spark.alpha == 0)
secretValues[secret] = nil

Section("Edit Mode showing where the bars sit")
game.timer = nil
Tick()
check("an empty bar that says what it is",
    bar.value == 0 and bar.nameText.text == "Timer bar" and bar.timeText.text == "")

Section("nothing written into the game's tables")
do
    local after = Keys(game)
    local added = {}
    for k in pairs(after) do
        if not before[k] and k ~= "timer" then added[#added + 1] = tostring(k) end
    end
    check("no field added to the game's timer bar", #added == 0, table.concat(added, ", "))
end

Summary()
