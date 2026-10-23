-- The Five Second Rule module: the countdown after mana is spent, one of the
-- castbar group - under the castbar, at its size and in its look, placed and
-- locked with it.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

local function Near(colour, want)
    if type(colour) ~= "table" then return false end
    for i = 1, 3 do
        if type(colour[i]) ~= "number" or math.abs(colour[i] - want[i]) > 0.002 then
            return false
        end
    end
    return true
end

-- A spell lands and the mana it cost comes off: the two halves of what starts
-- the five seconds. Spell 1 costs mana, spell 2 is free (see spellCosts).
local function Spend(spellID)
    Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", spellID or 1)
    Fire("UNIT_POWER_UPDATE", "player", "MANA")
end

LoadAddon()
Login()

local NS = DogsForeverUI.FiveSecondRule
local Castbar = DogsForeverUI.Castbar
local Style = DogsForeverUI.Style
local DB = NS.db
local GROUP = Castbar.db
local bar = NS.bar
local castbar = Castbar.CastBar.castbar
local GAP = 6 + 3 + 3

-- At its default spot: the row just above the castbar, centred on it, the
-- group's gap between - placed there once (TOPLEFT on the screen).
local function InItsRow()
    local p = bar.points
    return p[1] == "TOPLEFT" and p[2] == UIParent
        and math.abs(p[4] - (GROUP.barLeft + (GROUP.barWidth - DB.barWidth) / 2)) < 1e-6
        and math.abs(p[5] - (GROUP.barTop + GAP + DB.barHeight)) < 1e-6
end

Section("loading")
check("the countdown has no switch - always on - and no placement mode of its own",
    DB.enabled == nil and DB.integrateIntoPlayerFrame == nil and DB.showSpark == nil
    and DB.unlocked == nil)
check("and no colour settings: the look is the addon's",
    DB.statusBarColor == nil and DB.statusBarBackgroundColor == nil)
Fire("PLAYER_ENTERING_WORLD")
check("placed ONCE at its default: its row just above the castbar, the group's gap between",
    DB.placed == true and InItsRow(), tostring(bar.points[2]))
check("its own size and layer, the castbar's to start",
    bar.width == DB.barWidth and bar.height == DB.barHeight and bar.strata == DB.frameStrata
    and DB.barWidth == GROUP.barWidth and DB.frameStrata == GROUP.frameStrata, bar.width)
check("and where it sits written back, for the Positions boxes",
    DB.barLeft == GROUP.barLeft + (GROUP.barWidth - DB.barWidth) / 2
    and DB.barTop == GROUP.barTop + Castbar.STACK_GAP + DB.barHeight)
DB.barWidth, DB.barHeight = 160, 16
Castbar.Refresh()
check("a size of its own", bar.width == 160 and bar.height == 16)
local placedLeft, placedTop = bar.points[4], bar.points[5]
GROUP.barWidth = GROUP.barWidth + 30
GROUP.barLeft, GROUP.barTop = GROUP.barLeft - 40, GROUP.barTop + 25
Castbar.Refresh()
check("which the castbar's no longer changes - nor its moving: it stays where it is",
    bar.width == 160 and bar.points[4] == placedLeft and bar.points[5] == placedTop)
GROUP.barLeft, GROUP.barTop = GROUP.barLeft + 40, GROUP.barTop - 25
GROUP.barWidth = GROUP.barWidth - 30
DB.barWidth, DB.barHeight = 100, 12
Castbar.Refresh()

Section("the countdown")
Tick(0.1)
check("nothing spent, nothing shown", bar:IsShown() == false)

Spend(2)
Tick(0.1)
check("a free spell starts nothing", bar:IsShown() == false)

Spend(1)
Tick(0.1)
check("spending mana brings the bar out", bar:IsShown() == true)
check("counting down from five", math.abs(bar:GetValue() - 4.9) < 0.001, bar:GetValue())
check("with the seconds on it", bar.label.text == "4.9s", bar.label.text)
-- Not shown at once by the mana event: it fades in, as every bar of the group.
check("fading in from nothing, not appearing at once", bar:GetAlpha() < 1, bar:GetAlpha())

Tick(2)
check("and keeps counting", bar.label.text == "2.9s", bar.label.text)

Tick(3)
Tick(Style.FADE_OUT + 0.05)
check("faded away once the five seconds are up", bar:IsShown() == false)

-- Mana moving without a mana-costing cast in front of it is regen or a potion.
Fire("UNIT_POWER_UPDATE", "player", "MANA")
Tick(0.1)
check("mana changing on its own starts nothing", bar:IsShown() == false)

-- A cast whose ID cannot be read still counts: the mana change is the proof.
do
    local secretID = Unreadable("a spell ID")
    Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", secretID)
    Fire("UNIT_POWER_UPDATE", "player", "MANA")
    Tick(0.1)
    check("a spell the client will not name still starts it", bar:IsShown() == true)
    Tick(5)
end

-- A druid: shifting into cat form costs mana (the countdown starts), then
-- the resource is energy - the combo points' turn, not the countdown's.
Spend(1)
Tick(0.1)
units.player.powerToken = "ENERGY"
Tick(0.1)
check("on energy (cat form): out of sight - the combo points show instead", bar:IsShown() == false)
units.player.powerToken = "RAGE"
Tick(0.1)
check("on rage (bear form): out of sight too", bar:IsShown() == false)
units.player.powerToken = "MANA"
Tick(0.1)
check("back on mana with seconds left: the countdown shows again", bar:IsShown() == true)
Tick(6)

playerDead = true
Spend(1)
Tick(0.1)
check("the dead count nothing", bar:IsShown() == false)
playerDead = false

Section("the look")
Spend(1)
Tick(0.1)
check("the flat fill with its sheen, in the player's mana bar colour",
    bar:GetStatusBarTexture().texture == Style.FLAT_TEXTURE and bar.sheen ~= nil
    and Near(bar.statusColor, Style.MANA_COLOR))
check("on the black background, at half",
    bar.bg.colorTexture ~= nil and Near(bar.bg.colorTexture, Style.BACKGROUND_COLOR) and bar.bg.colorTexture[4] == 0.5)
check("with a white label, as every bar's", Near(bar.label.textColor, { 1, 1, 1 }))
check("the same border as every bar", bar.border ~= nil and bar.border:IsShown())
check("and the spark on the leading edge", bar.spark ~= nil and bar.spark:IsShown())

-- The seconds and the spark are always there: no setting takes them away.
Castbar.Refresh()
Tick(0.1)
check("the seconds always show", bar.label.text ~= "", bar.label.text)
check("and the spark", bar.spark:IsShown())
check("with no setting for either", GROUP.showTime == nil and GROUP.showSpark == nil)
Tick(5)

Section("placing it, with the castbar")
DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
check("unlocking the castbar shows the countdown to be placed too",
    GROUP.unlocked == true and bar:IsShown())
check("as it really looks, a countdown just begun: full, 5.0s on the left",
    bar.label.text == "5.0s" and bar.label.justifyH == "LEFT" and bar.stateText == nil
    and bar:GetValue() == 5,
    tostring(bar.label.text))
check("on its own background, not a placing look", bar.bg.colorTexture ~= nil
    and not PlacingLook(bar.bg))
check("where it was placed, on the screen - dragging the castbar does not take it along",
    DB.placed == true and bar.points[2] == UIParent)

bar.left, bar.top = 300, 700
bar.scripts.OnMouseUp(bar, "LeftButton")
check("dragging the countdown itself puts it somewhere of its own",
    DB.placed == true and DB.barLeft == 300)
check("where it now stays", bar.points[2] == UIParent and bar.points[4] == 300)
DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
check("and locking the castbar puts it away", GROUP.unlocked == false and bar:IsShown() == false)
Spend(1)
Tick(0.1)
check("the next countdown wears its seconds, off the placing look",
    bar.label.text == "4.9s" and not PlacingLook(bar.bg), bar.label.text)
Tick(5)

DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
pendingTimer = nil
bar.scripts.OnMouseUp(bar, "RightButton")
check("a right-click on it does nothing: still being placed, still where it was",
    pendingTimer == nil and GROUP.unlocked == true and DB.barLeft == 300)
DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
check("locked, it is put away", GROUP.unlocked == false and bar:IsShown() == false)

Fire("PLAYER_ENTERING_WORLD")
check("a countdown the player placed is never moved again",
    DB.placed == true and DB.barLeft == 300, DB.barLeft)

Section("never inside the player frame")
-- That option is gone: the countdown is always a bar of its own, in the group.
playerManaBar = CreateFrame("StatusBar", "PlayerManaBarStub", UIParent)
DB.integrateIntoPlayerFrame = true
NS.Refresh()
check("a leftover setting for it does nothing", bar.points[2] ~= playerManaBar
    and bar.border:IsShown())
playerManaBar = nil
DB.integrateIntoPlayerFrame = nil
NS.Refresh()

Section("a class with no mana")
units.player.class = "WARRIOR"
NS.Init()
Spend(1)
Tick(0.1)
check("a warrior never sees it", bar:IsShown() == false)
units.player.class = "PRIEST"
NS.Init()

Section("resetting it")
DogsForeverUI:Reset("fsr")
check("a reset puts it back in its row over the castbar, wherever that is now (placed there once again)",
    DB.placed == true and InItsRow())

Section("retail")
-- Retail has no five-second rule: the same bar is the secondary power the
-- game's player frame shows as its second bar, in that power's colour.
do
    WOW_PROJECT_ID = WOW_PROJECT_MAINLINE
    -- (Blizzard_UnitFrame's, mainline: the second bar a spec shows, if any.)
    local second
    GetUnitSecondaryPowerInfo = function() if second then return second, "MANA" end end
    local ok, err = pcall(function()
        Reload(nil)
        Login()
    end)
    check("the addon loads and logs in with no error", ok, tostring(err))
    local rNS = DogsForeverUI.FiveSecondRule
    check("a holy priest (no second power): no row kept for it", rNS.ClassHasMana() == false)
    Spend(1)
    Tick(0.1)
    check("spending mana shows no countdown", rNS.bar:IsShown() == false)
    DogsForeverUI.SetUnlocked(true)
    check("nor does Unlock Mode: nothing to place", rNS.bar:IsShown() == false)
    DogsForeverUI.SetUnlocked(false)
    check("its settings are kept all the same", rNS.db.barWidth ~= nil and rNS.db.sized == true)

    -- Shadow form: insanity the player's own power, the game's second bar
    -- mana - which goes under the player's health; insanity comes here.
    second = Enum.PowerType.Mana
    PowerBarColor.INSANITY = { r = 0.4, g = 0, b = 0.8 }
    units.player.powerToken = "INSANITY"
    Fire("UNIT_DISPLAYPOWER", "player")
    check("shadow: insanity's bar in its place, shown", rNS.ClassHasMana() and rNS.bar:IsShown())
    check("in insanity's colour", rNS.bar.statusColor and rNS.bar.statusColor[1] == 0.4
        and rNS.bar.statusColor[3] == 0.8)
    check("its count alone, no share repeating it", rNS.bar.label.text ~= "" and not rNS.bar.label.text:find("%", 1, true))
    check("centred, as the unit frames' health and power", rNS.bar.label.justifyH == "CENTER")
    -- (The player, 2026-10-20, after hiding it at 0 kept going wrong: "just remove the
    -- hiding logic".) Shown whatever its count, in a fight or out of one.
    local had = units.player.power
    units.player.power = 0
    Fire("UNIT_POWER_FREQUENT", "player", "INSANITY")
    Tick(1)
    check("at 0, out of a fight: shown all the same", rNS.bar:IsShown() and rNS.bar.alpha == 1)
    units.player.power = SecretCastValue("insanity")
    local ok, err = pcall(Fire, "UNIT_POWER_FREQUENT", "player", "INSANITY")
    check("a secret count: shown, nothing made from it, no error", ok and rNS.bar:IsShown()
        and rNS.bar.alpha == 1, tostring(err))
    units.player.power = had
    local player = DogsForeverUI.Frames.plates.player
    player:Refresh()
    local mana = DogsForeverUI.Style.MANA_COLOR
    check("and the player's power bar under health shows the mana",
        player.power.statusColor and player.power.statusColor[1] == mana[1] and player.power.statusColor[3] == mana[3])
    units.player.powerToken, PowerBarColor.INSANITY = nil, nil
    second = nil
    Fire("PLAYER_SPECIALIZATION_CHANGED")
    check("a spec with none: gone", rNS.bar:IsShown() == false)
end

Summary()
