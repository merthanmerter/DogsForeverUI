-- The Frames module: the player, target, focus and target-of-target plates,
-- the target and focus cast bars, and what is done to the game's own frames.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

local function SetTarget(unit)
    units.target = unit
    Fire("PLAYER_TARGET_CHANGED")
end

LoadAddon()

local NS = DogsForeverUI.Frames
local DB

print("== loading ==")
Fire("ADDON_LOADED", "DogsForeverUI")
DB = DogsForeverUI.Frames.db

check("the addon builds its saved settings", type(DB) == "table")
check("with the defaults filled in",
    DB.barWidth == 150 and DB.barHeight == 30
    and DB.powerHeight == 10)
check("and no switches: the frames, the level, the heals and the nameplates are always on",
    DB.enabled == nil and DB.showLevel == nil and DB.showHealPrediction == nil
    and DB.styleNamePlates == nil)
check("and no aura settings, since there is no aura row",
    DB.auraSize == nil and DB.aurasOnTop == nil,
    tostring(DB.auraSize) .. ", " .. tostring(DB.aurasOnTop))
check("placement mode is never restored", DB.unlocked == false)
check("and no texture or health colour settings, since neither is a choice",
    DB.barTexture == nil and DB.healthColor == nil,
    tostring(DB.barTexture) .. ", " .. tostring(DB.healthColor))

-- THE PALETTE, worked out here from the hex the player asked for rather than
-- read back from the addon, so a slip in the addon's arithmetic shows up.
-- The fill the player chose in game for every bar: a flat colour with a sheen.
local FILL = "Interface\\Buttons\\WHITE8X8"
-- The hex the player gave, then made lighter and more vivid once seen in game:
-- scaled up by LIGHTER, and every channel pushed VIVID times further from the
-- brightest one (saturation, same hue; a grey stays grey).
local LIGHTER, VIVID = 2.5, 2.0
-- No channel past full: a tint cannot go brighter than 1.
local function Push(c, amount)
    local top = math.max(c[1], c[2], c[3])
    local out = {}
    for i = 1, 3 do out[i] = math.min(1, math.max(0, top - (top - c[i]) * amount)) end
    return out
end
local function Vivid(c) return Push(c, VIVID) end
local function Lit(r, g, b)
    return Vivid({ r / 255 * LIGHTER, g / 255 * LIGHTER, b / 255 * LIGHTER })
end
local HEALTH = Lit(0x43, 0x58, 0x2f)
-- Mana as the player picked it, #18376e on screen: the tint is divided by the
-- classic texture's average shade (about 0.62) to make up for the multiply -
-- then lifted with the rest of the palette by the same step (LIGHTER and VIVID
-- over their earlier 1.7 and 1.4). Its blue is at full by now, so it is pushed
-- a fixed 1.15: harder only took green out and read darker.
local MANA = Push({ 0x18 / 255 / 0.62 * LIGHTER / 1.7, 0x37 / 255 / 0.62 * LIGHTER / 1.7,
    0x6e / 255 / 0.62 * LIGHTER / 1.7 }, 1.15)
local GOLD = { 1, 0xbb / 255, 0x20 / 255 }

-- A game colour at the palette's depth: brightest channel `top` (out of 255),
-- no channel under mana's darkest share of it, then made vivid - by the old
-- 1.6 when it is at full brightness, where a harder push only darkened it.
local function Toned(r, g, b, top)
    local floor = top * 0x19 / 0x6e
    local scale = top / math.max(r, g, b)
    return Push({ math.max(floor, r * scale) / 255, math.max(floor, g * scale) / 255,
        math.max(floor, b * scale) / 255 }, top >= 255 and 1.6 or VIVID)
end
local HEALTH_TOP, POWER_TOP = 0x58 * LIGHTER, math.min(255, 0x6e * LIGHTER)

local function Near(colour, want)
    if type(colour) ~= "table" then return false end
    for i = 1, 3 do
        if type(colour[i]) ~= "number" or math.abs(colour[i] - want[i]) > 0.002 then
            return false
        end
    end
    return true
end
local function Show(colour)
    if type(colour) ~= "table" then return tostring(colour) end
    return string.format("%.3f, %.3f, %.3f", colour[1] or -1, colour[2] or -1, colour[3] or -1)
end
check("all four plates are built", NS.plates ~= nil and NS.plates.player ~= nil
    and NS.plates.target ~= nil and NS.plates.focus ~= nil
    and NS.plates.targettarget ~= nil)

local player, target = NS.plates.player, NS.plates.target
local focus, tot = NS.plates.focus, NS.plates.targettarget

print("== the default position puts the player left of centre and the target right ==")
do
    -- A row across the middle of the screen: the player, then whatever the other
    -- two addons are drawing in the middle, then the target.
    local function Defaults(w, h)
        GetScreenWidth = function() return w end
        GetScreenHeight = function() return h end
        DB.playerPlaced, DB.targetPlaced = false, false
        Fire("PLAYER_ENTERING_WORLD")
        return DB.playerLeft, DB.playerTop, DB.targetLeft, DB.targetTop
    end

    local pLeft, pTop, tLeft, tTop = Defaults(2133.3333, 1200)
    check("the player sits left of the middle", pLeft + DB.barWidth < 2133.3333 / 2, pLeft)
    check("the target sits right of it", tLeft > 2133.3333 / 2, tLeft)
    check("with the same gap either side",
        math.abs((2133.3333 / 2 - (pLeft + DB.barWidth)) - (tLeft - 2133.3333 / 2)) < 0.01)
    check("both at the same height", pTop == tTop, pTop)
    -- The player's own screen: 2560x1440 at a UI scale of 1.2 is a UI 1200
    -- units tall, and 75% of the way down it is -900 (70%, -840, until
    -- 2026-10-01).
    check("at -900 on the player's 2560x1440 screen", math.abs(pTop - -900) < 0.001, pTop)

    -- It is a share of the screen, not a pixel count, so it holds anywhere.
    for _, size in ipairs({ { 1920, 1080 }, { 3440, 1440 }, { 1280, 720 } }) do
        local w, h = size[1], size[2]
        local left, top, right = Defaults(w, h)
        check("centred at " .. w .. "x" .. h,
            math.abs((w / 2 - (left + DB.barWidth)) - (right - w / 2)) < 0.01, left)
        check("and 75% of the way down there too", math.abs(top / h - -0.75) < 1e-9, top)
    end

    -- A frame the player has put somewhere is never moved again.
    DB.playerPlaced, DB.playerLeft, DB.playerTop = true, 111, -222
    Fire("PLAYER_ENTERING_WORLD")
    check("a frame the player placed is left alone",
        DB.playerLeft == 111 and DB.playerTop == -222, DB.playerLeft)
    check("while the other one is still placed by the addon", DB.targetPlaced ~= true)

    GetScreenWidth = function() return 1920 end
    GetScreenHeight = function() return 1080 end
    DB.playerPlaced = false
    Fire("PLAYER_ENTERING_WORLD")
end

print("== the default row ==")
do
    -- The four frames land on one line, in the order focus, player, target,
    -- target-of-target, with the middle left clear for the castbar and the
    -- countdown. Those bars' positions are not read: this is where the frames
    -- sit by default, worked out from the screen, and a bar the player has
    -- dragged does not take the frames with it.
    local castbar, fsr = DogsForeverUI.Castbar.db, DogsForeverUI.FiveSecondRule.db
    local saved = { castbar.barTop, castbar.autoPlaced, fsr.barTop, fsr.autoPlaced }
    castbar.barTop, castbar.autoPlaced = -1, false   -- must be ignored
    fsr.barTop, fsr.autoPlaced = -2, false           -- must be ignored

    for _, unit in ipairs({ "player", "target", "focus", "targettarget" }) do
        DB[unit .. "Placed"] = nil
    end
    Fire("PLAYER_ENTERING_WORLD")

    check("the row sits 75% of the way down the screen",
        math.abs(DB.playerTop - -1080 * 0.75) < 0.01, DB.playerTop)
    check("all four on the same line",
        DB.targetTop == DB.playerTop and DB.focusTop == DB.playerTop
        and DB.targettargetTop == DB.playerTop)
    check("and neither bar's own position was consulted for it",
        DB.playerTop ~= -1 and DB.playerTop ~= -2)

    check("focus, player, target, target-of-target, left to right",
        DB.focusLeft < DB.playerLeft and DB.playerLeft < DB.targetLeft
        and DB.targetLeft < DB.targettargetLeft, DB.focusLeft)
    check("with the middle of the screen left clear between the two big ones",
        DB.playerLeft + DB.barWidth < 1920 / 2 and DB.targetLeft > 1920 / 2)
    check("and room beside each for its level badge",
        DB.playerLeft - (DB.focusLeft + DB.barWidth) >= NS.UnitPlate.SideRoom(),
        DB.playerLeft - (DB.focusLeft + DB.barWidth))

    -- A frame the player has placed is never moved again.
    DB.focusTop, DB.focusLeft, DB.focusPlaced = -100, 50, true
    Fire("PLAYER_ENTERING_WORLD")
    check("a dragged frame is left where the player put it",
        DB.focusTop == -100 and DB.focusLeft == 50)
    check("while the others are still placed by the addon",
        DB.playerTop == DB.targetTop)

    castbar.barTop, castbar.autoPlaced, fsr.barTop, fsr.autoPlaced =
        saved[1], saved[2], saved[3], saved[4]
    DB.focusPlaced = nil
    Fire("PLAYER_ENTERING_WORLD")
end

print("== the small frame ==")
do
    -- One size setting for all four; the target's target takes a fraction of
    -- it, as the game draws it smaller too.
    check("the target of target is drawn smaller",
        tot:GetWidth() < target:GetWidth(), tot:GetWidth())
    check("by the scale the addon says", tot:GetWidth()
        == math.floor(DB.barWidth * NS.UnitPlate.SMALL_SCALE + 0.5), tot:GetWidth())
    check("and the others are full size", focus:GetWidth() == DB.barWidth)

    -- Badges outwards: the two left of the middle wear theirs on the left.
    check("the focus wears its badges outwards on the left, like the player",
        focus.badgeOnLeft == true and player.badgeOnLeft == true)
    check("and the target of target on the right, like the target",
        not tot.badgeOnLeft and not target.badgeOnLeft)
    check("no plate has a level circle any more",
        focus.levelRing == nil and target.levelRing == nil and player.levelDisc == nil)

    check("no plate has an aura row any more",
        focus.auras == nil and target.auras == nil and tot.auras == nil)

    check("the target and the focus have a cast bar",
        target.castbar ~= nil and focus.castbar ~= nil)
    check("and the target of target does not, as in the game", tot.castbar == nil)
end

print("== the focus and the target of target ==")
do
    check("with no focus, its plate is off screen", focus:IsShown() == false)
    units.focus = { name = "Healer", level = 60, isPlayer = true, class = "PRIEST",
        reaction = 5, health = 5000, healthMax = 5000,
        power = 10, powerMax = 100, powerToken = "MANA" }
    Fire("PLAYER_FOCUS_CHANGED")
    Tick()
    check("setting a focus brings it out", focus:IsShown() == true
        and focus.nameText.text == "Healer", focus.nameText.text)

    -- The target's target has no event worth the name behind it, so the plate
    -- polls for it rather than waiting.
    check("with no target of target, its plate is off screen", tot:IsShown() == false)
    units.targettarget = { name = "Sheep", level = 10, isPlayer = false, reaction = 4,
        health = 50, healthMax = 100, power = 0, powerMax = 0, powerToken = "MANA" }
    Tick(0.3)
    check("one appearing is noticed without an event", tot:IsShown() == true
        and tot.nameText.text == "Sheep", tot.nameText.text)

    units.targettarget.name = "Boar"
    Tick(0.3)
    check("and so is it becoming somebody else", tot.nameText.text == "Boar",
        tot.nameText.text)

    units.targettarget = nil
    Tick(0.3)
    check("and it going away", tot:IsShown() == false)

    units.focus = nil
    Fire("PLAYER_FOCUS_CHANGED")

    -- The game has a setting for whether a target of target is shown at all.
    -- It is the player's answer to that question, not something for this addon
    -- to ask again.
    units.targettarget = { name = "Sheep", level = 10, isPlayer = false, reaction = 4,
        health = 50, healthMax = 100, power = 0, powerMax = 0, powerToken = "MANA" }
    Tick(0.3)
    check("with the game's setting on, the plate is drawn", tot:IsShown() == true)

    cvars.showTargetOfTarget = false
    Fire("CVAR_UPDATE", "showTargetOfTarget")
    Tick(0.3)
    check("turning it off takes the plate away", tot:IsShown() == false)

    cvars.showTargetOfTarget = true
    Fire("CVAR_UPDATE", "showTargetOfTarget")
    Tick(0.3)
    check("and turning it back on brings it out again", tot:IsShown() == true)

    units.targettarget = nil
    Tick(0.3)
end

print("== clicking ==")
do
    -- The click surface is a real secure unit button carrying what the game's own
    -- frames carry: left-click targets, right-click opens the unit menu. Those
    -- attributes are why it still works in combat.
    check("the player plate has a secure click button", player.click ~= nil
        and player.click.template == "SecureUnitButtonTemplate", player.click.template)
    check("bound to the right unit", player.click:GetAttribute("unit") == "player")
    check("left-click targets", player.click:GetAttribute("*type1") == "target")
    check("right-click opens the unit menu",
        player.click:GetAttribute("*type2") == "togglemenu")
    check("the target plate is bound to the target",
        target.click:GetAttribute("unit") == "target")
    check("and both register clicks", player.click.clicks[1] == "AnyUp")

    -- Hovering shows the game's unit tooltip, as the game's frames do.
    player.click.scripts.OnEnter(player.click)
    check("hovering shows the unit tooltip", GameTooltip.tooltipUnit == "player")
end

print("== the player plate ==")
Tick()
check("the player is on screen", player:IsShown() == true)
check("with their name on it", player.nameText.text == "Dogsdog", player.nameText.text)
check("the health bar knows the pool it is drawing",
    select(2, player.health:GetMinMaxValues()) == 10000)
check("and is filled to the health in it", player.health:GetValue() == 8000,
    player.health:GetValue())
check("the resource bar likewise",
    player.power:GetValue() == 3000 and select(2, player.power:GetMinMaxValues()) == 5000)
-- Shortened and given its share by the game, from the secret numbers: "8K | 80%".
check("health is written short, with its share", player.healthText.text == "8K | 80%",
    player.healthText.text)
check("and so is the resource", player.powerText.text == "3K | 60%", player.powerText.text)
check("the class colour is used for a player, exactly as the game gives it",
    Near(player.health.statusColor, { 1, 1, 1 }),
    Show(player.health.statusColor))
check("mana is tinted to show #18376e on the texture", Near(player.power.statusColor, MANA),
    Show(player.power.statusColor))
check("every bar wears the flat fill",
    player.health:GetStatusBarTexture().texture == FILL
    and player.power:GetStatusBarTexture().texture == FILL
    and player.prediction:GetStatusBarTexture().texture == FILL,
    tostring(player.power:GetStatusBarTexture().texture))
check("with the soft sheen and shade on health and power, not on the heal shading",
    player.health.sheen ~= nil and player.health.shade ~= nil
    and player.power.sheen ~= nil and player.prediction.sheen == nil)
-- A colour, not a file: when the file it used to be went missing, the game drew
-- its missing-texture green behind every bar.
check("the empty part behind each is a plain colour, from no file",
    player.healthBG.colorTexture ~= nil and player.powerBG.colorTexture ~= nil
    and player.healthBG.texture == nil and player.powerBG.texture == nil,
    tostring(player.healthBG.texture))
local WHITE = { 1, 1, 1 }
check("the name and the values on the bars are white",
    Near(player.nameText.textColor, WHITE) and Near(player.healthText.textColor, WHITE)
    and Near(player.powerText.textColor, WHITE),
    Show(player.nameText.textColor))
check("and the player's own level is #ffbb20",
    Near(player.levelText.textColor, GOLD), Show(player.levelText.textColor))
check("the values are centred on their bars",
    player.healthText.points[1] == "CENTER" and player.healthText.points[2] == player.health
    and player.powerText.points[1] == "CENTER" and player.powerText.points[2] == player.power)

print("== the row above the frame ==")
-- The level at the left end, the name centred, a crown at the right end while
-- the unit leads - above the frame, clear of its border.
local BOLD = "Interface\\AddOns\\DogsForeverUI\\Media\\Dog-Bold.ttf"
check("the level is above the frame's left end", player.levelText.text == "60"
    and player.levelText.points[1] == "BOTTOMLEFT" and player.levelText.points[2] == player
    and player.levelText.points[3] == "TOPLEFT" and player.levelText.points[5] == 6,
    player.levelText.text)
do
    local left, right = player.nameText.anchors[1], player.nameText.anchors[2]
    check("the name centred above it, the same margin either end",
        left[1] == "BOTTOMLEFT" and left[2] == player and left[3] == "TOPLEFT"
        and right[1] == "BOTTOMRIGHT" and right[3] == "TOPRIGHT"
        and left[4] == -right[4] and left[4] > 0 and left[5] == 6
        and player.nameText.justifyH == "CENTER", tostring(left[4]))
    check("both in the bold font, the level a touch smaller",
        player.nameText.font[1] == BOLD and player.levelText.font[1] == BOLD
        and player.nameText.font[2] == 13 and player.levelText.font[2] == 11,
        tostring(player.nameText.font[1]))
    check("clear of the border, which reaches three pixels out",
        left[5] > DogsForeverUI.Style.BORDER_INSET)
end
do
    local Style = DogsForeverUI.Style
    local band, top = player.nameBand, player.nameLineTop
    local width = player.width
    local room = NS.UnitPlate.TopRoom()
    check("a black band behind the row, from the frame's top edge up, the whole width",
        band[1].points[1] == "BOTTOMLEFT" and band[1].points[2] == player
        and band[1].points[3] == "TOPLEFT" and band[1].points[4] == 0 and band[1].points[5] == 0
        and band[3].points[4] + band[3].width == width
        and band[1].height == room and band[1].layer == "BACKGROUND")
    check("tall enough for the name's letters to sit centred in it",
        room == 6 + 13 + 2 + 3)
    check("fading in at the left, solid in the middle, fading out at the right",
        band[1].gradient.orientation == "HORIZONTAL"
        and band[1].gradient.from.a == 0 and band[1].gradient.to.a > 0
        and band[2].vertexColor[1] == 0 and band[2].vertexColor[4] == band[1].gradient.to.a
        and band[3].gradient.from.a == band[1].gradient.to.a and band[3].gradient.to.a == 0)
    check("the fades over the outer third or so of each end",
        band[1].width == band[3].width and band[1].width > width * 0.3
        and band[1].width < width * 0.4)
    check("a line in the border's gold along its top, fading the same way",
        top[1].points[1] == "TOPLEFT" and top[1].points[5] == room and top[1].height == 1
        and top[2].vertexColor[1] == Style.BORDER_COLOR[1]
        and top[1].gradient.from.a == 0 and top[3].gradient.to.a == 0)
    check("and none along its bottom, where the frame's own border already is",
        player.nameLineBottom == nil)
    check("the lines over the black", top[1].sublevel > band[1].sublevel)
    check("on every frame, the small one's band at its scale",
        target.nameBand ~= nil and focus.nameLineTop ~= nil
        and tot.nameBand[1].height == room * NS.UnitPlate.SMALL_SCALE)
end
check("no crown while the player does not lead", player.leader.alpha == 0)
units.player.leader = true
player:Update()
-- This client says the player leads while solo; the game's own frame shows no
-- crown outside a group, and neither does this.
check("no crown while solo, whatever the client says about leading", player.leader.alpha == 0)
inGroup = true
player:Update()
check("a crown at the frame's top right, mirroring the level at its top left, while they do",
    player.leader.alpha == 1 and player.leader.points[1] == "BOTTOMRIGHT" and player.leader.points[2] == player
    and player.leader.points[3] == "TOPRIGHT" and player.leader.points[4] == -player.levelText.points[4]
    and player.leader.points[5] == player.levelText.points[5] and player.leader.texture ~= nil)
units.player.leader = nil
Fire("PARTY_LEADER_CHANGED")
check("and it goes when the lead passes on, on the game's event", player.leader.alpha == 0)
units.player.instanceLeader = true
atlases["UI-HUD-UnitFrame-Player-Group-GuideIcon"] = true
Fire("GROUP_ROSTER_UPDATE")
check("the leader of an instance group has the crown too, as on the game's frame",
    player.leader.alpha == 1 and player.leader.texture == "Interface\\GroupFrame\\UI-Group-LeaderIcon")
lfgGroup = true
Fire("GROUP_ROSTER_UPDATE")
check("in a group the dungeon finder made, the game's guide mark instead",
    player.leader.alpha == 1 and player.leader.atlas == "UI-HUD-UnitFrame-Player-Group-GuideIcon")
lfgGroup = false
units.player.instanceLeader = nil
Fire("GROUP_ROSTER_UPDATE")
check("and the crown's own art back after", player.leader.alpha == 0
    and player.leader.texture == "Interface\\GroupFrame\\UI-Group-LeaderIcon")
inGroup = false
Fire("GROUP_ROSTER_UPDATE")

-- Resting: a "Zzz" over the player's level, the frame's top left corner.
resting = false
function IsResting() return resting end
Fire("PLAYER_UPDATE_RESTING")
check("no Zzz while the player is not resting", player.rest ~= nil and player.rest.alpha == 0)
check("only the player's frame has one", target.rest == nil and focus.rest == nil)
resting = true
Fire("PLAYER_UPDATE_RESTING")
check("resting: the Zzz shows, on the game's event", player.rest.alpha == 1)
check("over the level, at the frame's top left",
    player.rest.points[1] == "BOTTOMLEFT" and player.rest.points[2] == player.levelText
    and player.rest.points[3] == "TOPLEFT" and player.rest.width > 0 and player.rest.width == player.rest.height)
check("the game's still rest icon where its animated one is missing",
    player.rest.texture == "Interface\\CharacterFrame\\UI-StateIcon")
local hiddenRest = Unreadable and Unreadable("whether the player rests")
if hiddenRest then
    resting = hiddenRest
    local ok = pcall(player.Update, player)
    check("a resting state that cannot be read hides it and raises nothing", ok and player.rest.alpha == 0)
end
resting = false
Fire("PLAYER_UPDATE_RESTING")
check("and it goes when resting ends", player.rest.alpha == 0)

NS:Refresh()
check("the level is always drawn: there is no setting to turn it off",
    DB.showLevel == nil and player.levelText.text == "60", player.levelText.text)

print("== the target ==")
check("with no target, the target plate is off screen", target:IsShown() == false)

SetTarget({
    name = "Hogger", level = 11, isPlayer = false, reaction = 1,
    health = 500, healthMax = 2000, power = 100, powerMax = 100, powerToken = "RAGE",
})
Tick()
check("targeting something brings it out", target:IsShown() == true)
check("with its name", target.nameText.text == "Hogger", target.nameText.text)
check("and its level", target.levelText.text == "11", target.levelText.text)
-- The game's own colour for the unit, not one worked out here - then toned.
check("an unfriendly target wears the game's red, toned to the health green's depth",
    Near(target.health.statusColor, Toned(1, 0, 0, HEALTH_TOP)),
    Show(target.health.statusColor))

-- "Class and reaction colours" turns off both, which is what it says. It used
-- to leave a *player* on the game's reaction colour when unticked.
DB.classColors = false
NS:Refresh()
check("unticking it puts the health green on a player",
    Near(player.health.statusColor, HEALTH), Show(player.health.statusColor))
check("and on everything else too",
    Near(target.health.statusColor, HEALTH), Show(target.health.statusColor))

DB.classColors = true
NS:Refresh()
check("ticking it back puts the class colour on the player",
    Near(player.health.statusColor, { 1, 1, 1 }),
    Show(player.health.statusColor))
check("and the game's colour back on the target",
    Near(target.health.statusColor, Toned(1, 0, 0, HEALTH_TOP)),
    Show(target.health.statusColor))

check("rage is exactly the game's red",
    Near(target.power.statusColor, { 1, 0, 0 }),
    Show(target.power.statusColor))

SetTarget(nil)
Tick()
check("dropping the target takes the plate away again", target:IsShown() == false)

-- There is no aura suite any more: the aura row was taken out of the addon.
-- This client refuses a tainted caller aura data outright while
-- C_Secrets.ShouldAurasBeSecret() is true, and lists a hostile unit's auras as
-- empty even when it is false, so a target's debuffs could never reach the
-- plate. The game draws every unit's auras now; what is checked below is that
-- this addon leaves its aura display alone.

print("== the target's cast bar ==")
do
    SetTarget({
        name = "Hogger", level = 11, isPlayer = false, reaction = 1,
        health = 500, healthMax = 2000, power = 100, powerMax = 100, powerToken = "RAGE",
    })
    Tick()

    local bar = target.castbar.bar
    check("with nothing being cast there is no bar", bar:IsShown() == false)

    -- A cast starting brings the bar out; from then it is read from the game
    -- every frame: no cast ID, nothing to keep.
    casting.target = { name = "No Text", text = "Collecting", start = now, finish = now + 2 }
    Fire("UNIT_SPELLCAST_START", "target")
    Tick()
    check("a cast says what the game's castbar says: its display text, never the placeholder name",
        bar.spellText.text == "Collecting", bar.spellText.text)
    casting.target = { name = "Shoot", start = now, finish = now + 2 }
    Tick()
    check("a cast brings it out", bar:IsShown() == true)
    check("with the spell on it", bar.spellText.text == "Shoot", bar.spellText.text)

    -- Under the plate, or over it when the auras take the underside - and then
    -- clear of the name and level row, not just the border.
    local inset = DogsForeverUI.Style.BORDER_INSET
    DB.targetAuras = "above"
    NS.Refresh()
    check("under the plate while the auras are above it",
        bar.points[1] == "TOPLEFT" and bar.points[2] == target
        and bar.points[3] == "BOTTOMLEFT" and bar.points[5] == -(4 + 2 * inset),
        tostring(bar.points[5]))
    DB.targetAuras = "below"
    NS.Refresh()
    check("over it, clear of the name row, while they are underneath",
        bar.points[1] == "BOTTOMLEFT" and bar.points[3] == "TOPLEFT"
        and bar.points[5] == NS.UnitPlate.TopRoom() + 4 + inset,
        tostring(bar.points[5]))
    DB.targetAuras = "off"
    NS.Refresh()
    check("and under it, where the game puts a target's, with no auras shown",
        bar.points[1] == "TOPLEFT" and bar.points[3] == "BOTTOMLEFT", tostring(bar.points[1]))
    DB.targetAuras = "below"
    NS.Refresh()
    check("measured against the cast's own length",
        select(2, bar:GetMinMaxValues()) == 2)
    check("wearing the flat fill, in the castbar's #ffbb20",
        bar:GetStatusBarTexture().texture == FILL and bar.sheen ~= nil
        and Near(bar.statusColor, { 1, 0xbb / 255, 0x20 / 255 }),
        tostring(bar:GetStatusBarTexture().texture) .. " / " .. Show(bar.statusColor))
    check("with the spell and timer in white",
        Near(bar.spellText.textColor, { 1, 1, 1 }) and Near(bar.timeText.textColor, { 1, 1, 1 }),
        Show(bar.spellText.textColor))
    -- Opposite the auras, so they never meet: by default they are under it.
    check("over the plate while the auras are under it, as they are to start",
        bar.anchors[1][1] == "BOTTOMLEFT" and bar.anchors[1][2] == target
        and bar.anchors[1][3] == "TOPLEFT",
        tostring(bar.anchors[1][1]))

    -- The clock steps a tenth of a second per tick, and one has gone by since
    -- the cast was set up.
    Tick(1)
    check("a second in, it is a second along",
        math.abs(bar:GetValue() - 1.1) < 0.001, bar:GetValue())
    check("and the timer counts down", bar.timeText.text == "0.9", bar.timeText.text)
    check("with the castbar's spark riding the end of the fill",
        bar.spark and bar.spark.alpha == 1 and bar.spark.points[2] == bar:GetStatusBarTexture()
        and bar.spark.points[3] == "RIGHT", tostring(bar.spark and bar.spark.alpha))

    -- The name has to be readable on a bar this thin. The shared font rule
    -- sizes text from the bar's height, which on an 8px bar comes out at 4px
    -- and invisible, so there is a floor under it - and the rule also fades a
    -- short bar's text to transparent, which has to be undone after.
    do
        local _, size = bar.spellText:GetFont()
        check("the spell name is sized to stay readable on a thin bar",
            type(size) == "number" and size >= 9, tostring(size))
        check("and is not left transparent by the short-bar rule",
            bar.spellText.textColor == nil or bar.spellText.textColor[4] == nil
            or bar.spellText.textColor[4] > 0,
            bar.spellText.textColor and tostring(bar.spellText.textColor[4]))
        local _, timeSize = bar.timeText:GetFont()
        check("and the timer with it", type(timeSize) == "number" and timeSize >= 9,
            tostring(timeSize))
    end

    -- Every frame rather than on the plates' twenty-a-second beat: a bar that
    -- only moves when the bars are repainted reads as stuttering.
    local before = bar:GetValue()
    Tick(0.01)
    check("it advances on a frame shorter than the plates' beat",
        bar:GetValue() > before, bar:GetValue())

    -- An uninterruptible cast and a channel say so the way the game says it.
    casting.target.notInterruptible = true
    Tick()
    check("an uninterruptible cast turns the game's castbar grey",
        Near(bar.statusColor, { 0.7, 0.7, 0.7 }), Show(bar.statusColor))
    casting.target.notInterruptible = false

    casting.target = { name = "Drain", start = now, finish = now + 4, channel = true }
    Tick()
    check("a channel turns the player's softer green",
        Near(bar.statusColor, DogsForeverUI.Style.CAST_COLOR.channel), Show(bar.statusColor))
    Tick(1)
    check("and drains rather than fills",
        math.abs(bar:GetValue() - 2.9) < 0.001, bar:GetValue())

    -- Nothing being cast is the end of it: no stop event needed.
    casting.target = nil
    Tick()
    Tick(DogsForeverUI.Style.FADE_OUT + 0.05)
    check("the bar fades away when the cast does", bar:IsShown() == false)

    -- The one thing polling cannot see. The event holds the bar for a moment
    -- in the interrupted red.
    casting.target = { name = "Shoot", start = now, finish = now + 2 }
    Fire("UNIT_SPELLCAST_START", "target")
    Tick()
    Fire("UNIT_SPELLCAST_INTERRUPTED", "target")
    casting.target = nil
    Tick()
    check("an interrupted cast is held, in red",
        bar:IsShown() == true and Near(bar.statusColor, Toned(0.9, 0.2, 0.2, POWER_TOP)),
        Show(bar.statusColor))
    check("full, with no moving edge, so no spark", bar.spark.alpha == 0)
    Tick(0.7)
    Tick(DogsForeverUI.Style.FADE_OUT + 0.05)
    check("and then fades away", bar:IsShown() == false)

    -- A unit the client will not talk about - most other players - still gets
    -- its cast bar: the bar runs itself from the cast's duration, and the
    -- secrets are handed on, never tested.
    castingSecret.target = true
    casting.target = { name = "Shoot", start = now, finish = now + 2 }
    Fire("UNIT_SPELLCAST_START", "target")
    local ok, err = pcall(Tick)
    check("a unit whose casting is secret does not throw", ok, tostring(err))
    Tick(DogsForeverUI.Style.FADE_IN + 0.05)
    check("and its cast is shown all the same", bar:IsShown() == true)
    check("the bar run by the game from the cast's duration, filling",
        bar.timer ~= nil and issecretvalue(bar.timer.duration)
        and bar.timer.direction == Enum.StatusBarTimerDirection.ElapsedTime)
    check("the spell's name handed to the label untouched", issecretvalue(bar.spellText.text))
    check("the grey for a cast that can't be interrupted picked by the secret itself",
        bar:GetStatusBarTexture().vertexFromBoolean ~= nil
        and issecretvalue(bar:GetStatusBarTexture().vertexFromBoolean.value))
    check("the time left handed on as well", issecretvalue(bar.timeText.text))
    casting.target = { name = "Drain", start = now, finish = now + 4, channel = true }
    Tick()
    check("a secret channel drains", bar.timer.direction == Enum.StatusBarTimerDirection.RemainingTime
        and Near(bar.statusColor, DogsForeverUI.Style.CAST_COLOR.channel), Show(bar.statusColor))
    casting.target = nil
    Tick()
    Tick(DogsForeverUI.Style.FADE_OUT + 0.05)
    check("and it fades away when the cast does", bar:IsShown() == false)
    castingSecret.target = nil

    -- The option.
    casting.target = { name = "Shoot", start = now, finish = now + 2 }
    Fire("UNIT_SPELLCAST_START", "target")
    Tick()
    Tick(DogsForeverUI.Style.FADE_IN + 0.05)
    check("a cast the client will say is read as before", bar:IsShown() == true)

    DB.showCastbar = false
    NS:Refresh()
    Tick()
    check("and it can be turned off", bar:IsShown() == false)
    DB.showCastbar = true
    NS:Refresh()

    casting.target = nil
    SetTarget(nil)
    Tick()
end

print("== incoming heals ==")
do
    -- The shading covers the *missing* health: its left edge is anchored to the
    -- end of the health bar's own fill, so it starts exactly where health stops,
    -- and it is scaled to the missing health and filled with the heals on their
    -- way. Its width is then the heal's share of what is missing, of what is
    -- missing's share of the bar - the right answer, with nothing added up here.
    --
    -- An earlier version drew UnitHealth(unit, true) on a bar *behind* the health
    -- bar and showed nothing at all in game.
    check("the shading starts where the health bar's fill ends",
        player.prediction.anchors[1][2] == player.health:GetStatusBarTexture(),
        tostring(player.prediction.anchors[1][2]))

    units.player.incoming = 1500
    Tick()
    check("the health bar still shows what is really there",
        player.health:GetValue() == 8000, player.health:GetValue())
    check("the shading is scaled to the missing health",
        select(2, player.prediction:GetMinMaxValues()) == 2000,
        select(2, player.prediction:GetMinMaxValues()))
    check("and filled with the heals on their way",
        player.prediction:GetValue() == 1500, player.prediction:GetValue())

    -- No heal in flight reports nothing at all rather than zero, and testing
    -- that value against nil is exactly what may not be done to a secret.
    units.player.incoming = nil
    Fire("UNIT_HEAL_PREDICTION", "player")
    local ok = pcall(Tick)
    check("no heal in flight draws nothing, and does not throw", ok
        and player.prediction:GetValue() == 0, player.prediction:GetValue())

    local secretHeal = {}
    secretValues[secretHeal] = true
    units.player.incoming = secretHeal
    Fire("UNIT_HEAL_PREDICTION", "player")
    local okSecret = pcall(Tick)
    check("a secret heal reaches the bar untouched",
        okSecret and player.prediction:GetValue() == secretHeal)

    units.player.incoming = 1500
    NS:Refresh()
    Tick()
    check("always drawn: there is no setting to turn it off",
        DB.showHealPrediction == nil and player.prediction:IsShown() == true)
    units.player.incoming = nil

    -- A heal absorb is the same the other way round: over the health, filled
    -- back from the end of the health bar's fill.
    units.player.healAbsorb = 3000
    Tick()
    local absorb = player.healAbsorb
    check("a heal absorb shaded over the health, back from the fill's end",
        absorb:IsShown() and absorb.reverseFill == true
        and absorb.anchors[1][2] == player.health
        and absorb.anchors[2][2] == player.health:GetStatusBarTexture()
        and select(2, absorb:GetMinMaxValues()) == 8000 and absorb:GetValue() == 3000)
    check("in its own dark shade, over the health bar",
        absorb.statusColor[4] == NS.UnitPlate.HEAL_ABSORB_COLOR[4]
        and absorb:GetFrameLevel() > player.health:GetFrameLevel())
    units.player.healAbsorb = nil
    Tick()
    check("none: nothing shaded", absorb:GetValue() == 0)

    -- Shields, EllesmereUI's way: two health-bar-sized bars of the whole
    -- shield out of the maximum, cut by the heal bars' boxes.
    units.player.shield = 2500
    Tick()
    local shield, over = player.shield, player.overShield
    check("a shield on from the fill's end, cut off at the bar's end",
        shield:GetParent() == player.prediction and player.prediction.clipsChildren
        and shield.anchors[1][1] == "TOPLEFT" and shield.anchors[1][2] == player.prediction
        and shield.reverseFill == false
        and select(2, shield:GetMinMaxValues()) == 10000 and shield:GetValue() == 2500)
    check("and back from the bar's end over the health, cut off at the fill's: only what the missing health cannot hold",
        over:GetParent() == player.healAbsorb and player.healAbsorb.clipsChildren
        and over.anchors[1][1] == "TOPRIGHT" and over.anchors[1][2] == player.health
        and over.reverseFill == true
        and select(2, over:GetMinMaxValues()) == 10000 and over:GetValue() == 2500)
    player.health:GetScript("OnSizeChanged")(player.health, 200, 30)
    local lines = shield.regions[#shield.regions]
    -- (The player, 2026-10-20: "the shield stripes are a little buggy - exactly Blizzard's".)
    local fill, wrap = shield:GetStatusBarTexture(), TextureKitConstants.AddressModeWrap
    check("both as big as the health bar, exactly the game's raid-frame shield: its atlases, repeated and tiled both ways",
        shield.width == 200 and shield.height == 30 and over.width == 200 and over.height == 30
        and fill.atlas == "raidframe-shield-fill" and lines.atlas == "RaidFrame-Shield-Overlay"
        and tiling[lines].modes[1] == wrap and tiling[lines].modes[2] == wrap
        and tiling[lines].horiz == true and tiling[lines].vert == true and tiling[fill].horiz == true
        and lines.allPointsTo == fill)
    units.player.shield = nil
end

print("== the bars are read every frame, as the game's own unit frames read them ==")
do
    local player = NS.plates.player
    -- A heal lands with no UNIT_HEALTH yet (it comes late on this client).
    units.player.health = 7000
    Tick(0.01)
    check("the next frame shows it, no event needed", player.health:GetValue() == 7000,
        player.health:GetValue())
    units.player.healthMax = 12000
    Tick(0.01)
    check("a new max too", select(2, player.health:GetMinMaxValues()) == 12000)
    units.player.health, units.player.healthMax = 8000, 10000
    Tick(0.01)

    -- The client knows a heal landed before the server confirms it: the bar
    -- shows the client's (UnitHealth's default), as the game's frames do.
    units.player.predictedHealth = 9000
    Tick(0.01)
    check("the client's predicted health, not the server's late one",
        player.health:GetValue() == 9000, player.health:GetValue())
    units.player.predictedHealth = nil
    Tick(0.01)

    local paint, painted = player.PaintBars, 0
    player.PaintBars = function(self) painted = painted + 1; return paint(self) end
    Tick(0.01)
    check("a plate on screen is painted each frame", painted == 1, painted)
    player.PaintBars = paint
end

print("== the resource bar's text ==")
do
    -- The bar is ten pixels tall and the shared text rule sizes a label to the
    -- bar less its padding, which gave a four-pixel font: the "show resource"
    -- option looked like it did nothing at all. There is a floor under it now.
    local _, size = player.powerText:GetFont()
    check("the resource label is big enough to read", size >= 9, tostring(size))
    check("and it is not faded out on a bar that short",
        player.powerText.textColor[4] == nil or player.powerText.textColor[4] > 0)
    check("the resource number is on it", player.powerText.text == "3K | 60%",
        player.powerText.text)
end

print("== the palette ==")
do
    -- Every resource but mana is exactly the game's own colour for it.
    units.player.powerToken = "ENERGY"
    NS:Refresh()
    check("energy is exactly the game's yellow",
        Near(player.power.statusColor, { 1, 1, 0 }),
        Show(player.power.statusColor))
    units.player.powerToken = "FOCUS"
    NS:Refresh()
    check("focus exactly the game's orange, not pushed into rage's red",
        Near(player.power.statusColor, { 1, 0.5, 0.25 }),
        Show(player.power.statusColor))
    units.player.powerToken = "ENERGY"
    NS:Refresh()
    check("still on the same art",
        player.power:GetStatusBarTexture().texture == FILL)

    -- A resource the game lists no colour for wears mana's, not a blank.
    units.player.powerToken = "SOMETHINGNEW"
    NS:Refresh()
    check("a resource the game has no colour for wears mana's",
        Near(player.power.statusColor, MANA), Show(player.power.statusColor))

    units.player.powerToken = "MANA"
    NS:Refresh()

    -- The heal shading and the backgrounds are fixed, as they shipped.
    check("the heal shading is its fixed green",
        Near(player.prediction.statusColor, { 0.5, 0.9, 0.6 })
        and player.prediction.statusColor[4] == 0.45,
        Show(player.prediction.statusColor))
    -- A black tone at half (the player, 2026-10-03: as the chat panel's).
    local bg = player.healthBG.colorTexture
    check("and the backgrounds a black tone, at half",
        bg[1] <= 0.1 and bg[1] == bg[2] and bg[2] == bg[3] and bg[4] == 0.5
        and Near(player.powerBG.colorTexture, bg) and player.powerBG.colorTexture[4] == 0.5
        and Near(player.healthBG.vertexColor, { 1, 1, 1 }) and player.healthBG.alpha == 1,
        Show(bg) .. " @ " .. tostring(bg[4]))
    check("with no colour settings left in the defaults",
        DB.healthBackgroundColor == nil and DB.healPredictionColor == nil
        and DB.powerBackgroundColor == nil)
end

print("== the badges: elite at the top right like the crown, pvp outside ==")
do
    local function Is(p, inside, anchor, outside, x)
        return p[1] == inside and p[2] == anchor and p[3] == outside
            and p[4] == x and p[5] == 0
    end
    local function Where(p)
        return tostring(p[1]) .. " " .. tostring(p[3]) .. " " .. tostring(p[4]) .. " " .. tostring(p[5])
    end

    local npc = {
        name = "Apothecary Zamah", level = 22, isPlayer = false, reaction = 5,
        health = 746, healthMax = 746, power = 0, powerMax = 100, powerToken = "MANA",
        faction = "Horde", pvp = true, classification = "normal",
    }
    SetTarget(npc)
    NS:Refresh()
    Tick()

    local elite, pvp = target.eliteBadge, target.pvpBadge
    check("a flagged Horde unit gets the game's round Horde emblem",
        pvp.shown and pvp.icon.atlas == "UI-HUD-UnitFrame-SmallCircle-Horde",
        tostring(pvp.icon.atlas))
    check("no elite badge for a normal NPC", not elite.shown)
    check("the PvP badge sits on the target's outer side, centred on its line, 8px away",
        Is(pvp.points, "LEFT", target, "RIGHT", 8), Where(pvp.points))
    check("a circle a little shorter than the plate",
        pvp.width == target.badgeDiameter and pvp.height == target.badgeDiameter
        and pvp.height < target:GetHeight() + 1,
        tostring(pvp.width) .. " vs " .. tostring(target:GetHeight()))
    check("the emblem fits inside it, in the art's own proportions",
        pvp.icon.height < pvp.height
        and math.abs(pvp.icon.width / pvp.icon.height - 30 / 40) < 1e-6)

    npc.classification = "elite"
    NS.plates.target:Update()
    check("an elite NPC gets the game's gold elite emblem",
        elite.shown and elite.alpha == 1 and elite.icon.atlas == "nameplates-icon-elite-gold",
        tostring(elite.icon.atlas))
    local crown = target.leader
    check("at the top right corner, exactly where the crown goes",
        elite.points[1] == "BOTTOMRIGHT" and elite.points[2] == target and elite.points[3] == "TOPRIGHT"
        and elite.points[4] == crown.points[4] and elite.points[5] == crown.points[5], Where(elite.points))
    check("a little larger than the crown, smaller than the PvP circle",
        elite.width == elite.height and elite.width > crown.width and elite.width < pvp.width,
        tostring(elite.width) .. " vs " .. tostring(crown.width))
    check("the bare emblem: no ring, no dark disc", elite.ring.alpha == 0 and elite.disc.alpha == 0)
    check("the emblem fitted inside that size", elite.icon.width <= elite.width + 1e-9
        and elite.icon.height <= elite.height + 1e-9)
    check("and the PvP badge stays on the right",
        Is(pvp.points, "LEFT", target, "RIGHT", 8), Where(pvp.points))

    npc.classification = "worldboss"
    NS.plates.target:Update()
    check("a world boss wears the skull", elite.icon.atlas == "UI-HUD-UnitFrame-Target-HighLevelTarget_Icon")
    npc.classification, npc.boss = "elite", true
    NS.plates.target:Update()
    check("so does a dungeon boss, though only elite", elite.icon.atlas == "UI-HUD-UnitFrame-Target-HighLevelTarget_Icon")
    npc.boss = nil
    npc.classification = "rareelite"
    NS.plates.target:Update()
    check("a rare elite, the silver one", elite.icon.atlas == "nameplates-icon-elite-silver")
    npc.classification = "rare"
    NS.plates.target:Update()
    check("a rare, the star",
        elite.icon.atlas == "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star")

    npc.classification = "normal"
    NS.plates.target:Update()
    check("back to normal, the elite badge goes and the PvP badge stays put",
        not elite.shown and Is(pvp.points, "LEFT", target, "RIGHT", 8), Where(pvp.points))

    -- The focus: PvP on its left, the elite emblem at its top right as well.
    local focusPlate = NS.plates.focus
    units.focus = {
        name = "Boss", level = 60, isPlayer = false, reaction = 2, classification = "elite",
        health = 100, healthMax = 100, power = 0, powerMax = 100, powerToken = "MANA",
    }
    focusPlate:Update()
    check("the focus's elite emblem sits at its top right too, like its crown",
        focusPlate.eliteBadge.points[1] == "BOTTOMRIGHT" and focusPlate.eliteBadge.points[2] == focusPlate
        and focusPlate.eliteBadge.points[3] == "TOPRIGHT"
        and focusPlate.eliteBadge.points[5] == focusPlate.leader.points[5],
        Where(focusPlate.eliteBadge.points))
    units.focus = nil
    focusPlate:Update()

    npc.pvp = false
    NS.plates.target:Update()
    check("unflagged, the PvP badge is not drawn", pvp.alpha == 0)

    npc.pvp = SECRET_TRUE
    NS.plates.target:Update()
    check("a secret flag is handed to the client, never looked at",
        pvp.alphaFrom == SECRET_TRUE and pvp.alpha == 1)

    npc.pvp, npc.faction = true, "Alliance"
    NS.plates.target:Update()
    check("Alliance gets its own emblem",
        pvp.icon.atlas == "UI-HUD-UnitFrame-SmallCircle-Alliance")

    npc.ffa = true
    NS.plates.target:Update()
    check("free-for-all wins over the faction, as in the game",
        pvp.icon.atlas == "UI-HUD-UnitFrame-Player-PVP-FFAIcon" and pvp.alpha == 1)
    npc.ffa = nil

    npc.faction = "Neutral"
    NS.plates.target:Update()
    check("a neutral unit has no PvP badge", not pvp.shown)

    check("the player plate has no badges of its own",
        player.pvpBadge == nil and player.eliteBadge == nil)

    npc.faction, npc.classification = "Horde", "elite"
    NS:Refresh()
    Tick()

    local eliteBefore, pvpBefore = elite.shown, pvp.shown
    DB.unlocked = true
    NS.plates.target:Update()
    check("in Edit Mode the badges show as they really are",
        elite.shown == eliteBefore and pvp.shown == pvpBefore)
    DB.unlocked = false

    SetTarget(nil)
    NS:Refresh()
    Tick()
end


print("== the border ==")
do
    local border = player.border
    local gold = DogsForeverUI.Style.BORDER_COLOR
    local edges = { border.top, border.bottom, border.left, border.right }
    local solid = #edges == 4
    for _, line in ipairs(edges) do
        solid = solid and line.texture == "Interface\\Buttons\\WHITE8X8"
            and Near(line.vertexColor, gold)
    end
    check("four plain lines outermost, in the tooltip's gold", solid)
    check("each one pixel thick",
        border.top.height == 1 and border.bottom.height == 1
        and border.left.width == 1 and border.right.width == 1)
    local Style = DogsForeverUI.Style
    check("then a soft bevel and a black line, each a pixel further in",
        #border.lines == 3
        and Near(border.lines[2].top.vertexColor, Style.BEVEL_COLOR)
        and Near(border.lines[3].top.vertexColor, { 0, 0, 0 })
        and border.lines[2].top.points[5] == -1 and border.lines[3].top.points[5] == -2)
    check("three pixels outside the plate, with no gap",
        border.points[1] == "BOTTOMRIGHT" and border.points[4] == 3 and border.points[5] == -3
        and border.gap == nil)
    check("drawn over the bars", border:GetFrameLevel() > player.health:GetFrameLevel())

    -- Rounded corners of radius 4, anti-aliased: the lines stop four short of
    -- each corner and the curve is drawn pixel by pixel, each at the share of
    -- it a true one-pixel quarter ring would cover.
    local p = border.top.points
    check("the straight lines stop four pixels short of each corner",
        p[1] == "TOPRIGHT" and p[4] == -4 and p[5] == 0
        and border.left.points[1] == "BOTTOMLEFT" and border.left.points[5] == 4)
    check("eleven pixels of curve in each of the four corners", #border.steps == 44,
        #border.steps)
    local function Dot(dots, colour, point, x, y)
        for _, dot in ipairs(dots) do
            local d = dot.points
            if d[1] == point and d[3] == point and d[4] == x and d[5] == y
                and dot.width == 1 and dot.height == 1 and Near(dot.vertexColor, colour) then
                return dot.vertexColor[4]
            end
        end
    end
    local function Ring(point, x, y) return Dot(border.steps, gold, point, x, y) end
    local function About(a, want) return a ~= nil and math.abs(a - want) < 0.02 end
    check("nearly solid where the curve meets the lines",
        About(Ring("TOPLEFT", 3, 0), 0.96) and About(Ring("TOPLEFT", 0, -3), 0.96)
        and About(Ring("BOTTOMRIGHT", -3, 0), 0.96), Ring("TOPLEFT", 3, 0))
    check("part-covered round the bend, so it reads as a curve and not steps",
        About(Ring("TOPLEFT", 2, 0), 0.70) and About(Ring("TOPLEFT", 1, -1), 0.92)
        and About(Ring("TOPLEFT", 2, -1), 0.43), Ring("TOPLEFT", 1, -1))
    check("and the very corner left empty", Ring("TOPLEFT", 0, 0) == nil
        and Ring("TOPRIGHT", 0, 0) == nil and Ring("BOTTOMLEFT", 0, 0) == nil)

    -- The inner lines curve too, each in its own ring: the black one, two
    -- pixels in, meets the bar's square corner and covers it.
    local function Inner(line, colour, point, x, y)
        return Dot(border.lines[line].steps, colour, point, x, y)
    end
    check("the bevel and the black line curve with the gold",
        About(Inner(2, Style.BEVEL_COLOR, "TOPLEFT", 3, -1), 0.95)
        and About(Inner(2, Style.BEVEL_COLOR, "TOPLEFT", 2, -2), 0.68)
        and About(Inner(3, { 0, 0, 0 }, "TOPLEFT", 3, -2), 0.92)
        and About(Inner(3, { 0, 0, 0 }, "TOPLEFT", 2, -2), 0.32),
        Inner(3, { 0, 0, 0 }, "TOPLEFT", 3, -2))
end

-- A border of more than one line: each nested one pixel further in, each with
-- its own curve, and no gap when none is asked for.
do
    local host = CreateFrame("Frame", nil, UIParent)
    host:SetSize(100, 20)
    local gold, shade = { 0.7, 0.56, 0.38, 1 }, { 0.43, 0.35, 0.24, 1 }
    local b = DogsForeverUI.Style.AddBorder(host, { radius = 4, gap = 0, lines = { gold, shade } })
    check("two lines, the outer one first",
        #b.lines == 2 and Near(b.lines[1].top.vertexColor, gold)
        and Near(b.lines[2].top.vertexColor, shade) and b.top == b.lines[1].top)
    check("the inner one a pixel further in",
        b.lines[1].top.points[5] == 0 and b.lines[2].top.points[5] == -1
        and b.lines[2].left.points[4] == 1)
    check("two pixels out in all, with no gap drawn",
        b.points[4] == 2 and b.points[5] == -2 and b.gap == nil)
    check("each line curving in its own corner pixels",
        #b.lines[1].steps > 0 and #b.lines[2].steps > 0
        and #b.lines[1].steps ~= #b.lines[2].steps)
end

-- On the player's screen - 1440 pixels high, UI scale 1.2 - one unit of a
-- border is about two real pixels. The border is drawn on the real pixels:
-- each line two of them, the corners worked out pixel by pixel at that size,
-- not one unit to a 2x2 block, which drew the corners stepped.
do
    local host = CreateFrame("Frame", nil, UIParent)
    host:SetSize(100, 20)
    local b = DogsForeverUI.Style.AddBorder(host)

    -- The player's screen, then fitted again the way a UI scale change does.
    PixelUtil = { GetPixelToUIUnitFactor = function() return 768 / 1440 end }
    function b:GetEffectiveScale() return 1.2 end
    for _, frame in ipairs(allFrames) do
        if frame.events.UI_SCALE_CHANGED and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, "UI_SCALE_CHANGED")
        end
    end
    local px = (768 / 1440) / 1.2
    local function Same(a, want) return math.abs(a - want) < 1e-9 end
    check("each line two real pixels thick",
        Same(b.lines[1].top.height, 2 * px) and Same(b.lines[3].left.width, 2 * px),
        tostring(b.lines[1].top.height / px))
    check("the second line two real pixels in",
        Same(b.lines[2].top.points[5], -2 * px), tostring(b.lines[2].top.points[5] / px))
    check("the straight lines stopping eight real pixels short of a corner",
        Same(b.top.points[4], -8 * px), tostring(b.top.points[4] / px))
    check("and every corner pixel one real pixel",
        Same(b.steps[1].width, px) and Same(b.steps[1].height, px))
    check("so the curve has many more pixels to be smooth with",
        #b.steps > 44, #b.steps)
    PixelUtil = nil
end

print("== the font ==")
check("the values are in the player's own font, Media\\Dog.ttf; the name and level in its bold cut",
    player.healthText.font[1] == "Interface\\AddOns\\DogsForeverUI\\Media\\Dog.ttf"
    and player.powerText.font[1] == player.healthText.font[1]
    and player.nameText.font[1] == "Interface\\AddOns\\DogsForeverUI\\Media\\Dog-Bold.ttf"
    and player.levelText.font[1] == player.nameText.font[1],
    tostring(player.healthText.font[1]))

-- Text on a bar follows its height up to a cap, and a taller bar only gains room
-- round its text: 14 on a 20-high bar looked too large.
do
    local function NameSize(height)
        DB.barHeight = height
        NS:Refresh()
        return player.healthText.font[2]
    end
    check("the default health bar is 30 high, its text held at 11", NameSize(30) == 11, NameSize(30))
    check("a 16-high one keeps the 10 it always had", NameSize(16) == 10, NameSize(16))
    check("a taller one does not grow its text past 11",
        NameSize(30) == 11 and NameSize(60) == 11, NameSize(60))
    check("a short one still shrinks it", NameSize(12) == 8, NameSize(12))
    DB.barHeight = 30
    NS:Refresh()
end

print("== the spark on each bar ==")
-- The castbar's spark at the end of every fill, pinned to the fill texture
-- itself, and shown only between empty and full - which the game works out
-- through a curve, since health and power are secret.
do
    local spark = player.healthSpark
    check("the health bar has the castbar's spark",
        spark.texture == DogsForeverUI.Style.SPARK and spark.blendMode == "ADD")
    check("pinned to the end of the health fill",
        spark.points[1] == "CENTER" and spark.points[2] == player.health:GetStatusBarTexture()
        and spark.points[3] == "RIGHT")
    check("as tall as the castbar draws it, for this bar",
        spark.height == player.health:GetHeight() * DogsForeverUI.Style.SPARK_HEIGHT,
        spark.height)
    check("and the resource bar its own, on its own fill",
        player.powerSpark.points[2] == player.power:GetStatusBarTexture())

    units.player.health, units.player.power = 8000, 3000
    Fire("UNIT_HEALTH", "player"); Fire("UNIT_POWER_FREQUENT", "player", "MANA")
    Tick()
    check("part-way down, both show", spark.alpha == 1 and player.powerSpark.alpha == 1,
        tostring(spark.alpha))
    units.player.health = units.player.healthMax
    Fire("UNIT_HEALTH", "player")
    Tick()
    check("at full health the spark goes: there is no edge to mark", spark.alpha == 0,
        tostring(spark.alpha))
    units.player.power = 0
    Fire("UNIT_POWER_FREQUENT", "player", "MANA")
    Tick()
    check("nor on an empty bar", player.powerSpark.alpha == 0, tostring(player.powerSpark.alpha))
    units.player.health, units.player.power = 8000, 3000
    Fire("UNIT_HEALTH", "player"); Fire("UNIT_POWER_FREQUENT", "player", "MANA")
    Tick()

    check("no setting takes the sparks away: they are the look",
        DogsForeverUI.Castbar.db.showSpark == nil and spark.alpha == 1)

    DB.unlocked = true
    NS:Refresh()
    Tick()
    check("in Edit Mode the bars are painted as they really are, sparks and all",
        spark.alpha == 1)
    DB.unlocked = false
    NS:Refresh()
    Tick()
end

print("== the seam between the bars ==")
-- A solid line carrying on the border's inner black one, so the two bars read as
-- one framed piece.
do
    local line = player.divider.colorTexture
    check("the divider is the border's inner black line, carried across",
        line[1] == 0 and line[2] == 0 and line[3] == 0 and line[4] == 1,
        table.concat(line, ", "))
end

print("== values the client will not let us read ==")
do
    -- Health is always secret on this client. Storing one and handing it to
    -- SetValue is allowed; reading, comparing or adding it is not. Nothing here
    -- may throw, and the secret has to reach the bar untouched.
    local secretHealth, secretMax, secretClass = {}, {}, {}
    secretValues[secretHealth] = true
    secretValues[secretMax] = true
    secretValues[secretClass] = true

    units.player.health = secretHealth
    units.player.predictedHealth = secretHealth
    units.player.healthMax = secretMax
    units.player.class = secretClass

    -- Colours follow the unit rather than the clock, so this is the event path.
    local okColour = pcall(NS.Refresh, NS)
    check("a unit whose class cannot be read does not throw", okColour)

    local ok = pcall(Tick)
    check("a frame of secret health does not throw", ok)
    check("the secret reaches the bar untouched", player.health:GetValue() == secretHealth)
    check("and so does the pool", select(2, player.health:GetMinMaxValues()) == secretMax)
    check("whether the spark shows is the game's secret answer, handed on unread",
        secretValues[player.healthSpark.alpha] == true, tostring(player.healthSpark.alpha))
    -- The whole colour, not one channel of it: a toned friendly green would
    -- pass a one-channel check against the plain green either way.
    check("a class that cannot be read, no class colour call: the health green",
        Near(player.health.statusColor, HEALTH), Show(player.health.statusColor))
    -- The game's own class colour takes the secret class (C_ClassColor,
    -- AllowedWhenTainted) and answers a colour as secret; it goes to the bar
    -- untouched (EllesmereUI's way).
    local secretR, secretG, secretB = {}, {}, {}
    for _, v in ipairs({ secretR, secretG, secretB }) do secretValues[v] = true end
    local hadClassColor = C_ClassColor
    C_ClassColor = { GetClassColor = function(class)
        if class == secretClass then return { r = secretR, g = secretG, b = secretB } end
    end }
    local okSecretColour = pcall(function() NS:Refresh(); Tick() end)
    check("a secret class: the game's class colour for it, handed to the bar unread",
        okSecretColour and player.health.statusColor[1] == secretR and player.health.statusColor[3] == secretB)
    C_ClassColor = hadClassColor

    units.player.health = 8000
    units.player.predictedHealth = nil
    units.player.healthMax = 10000
    units.player.class = "PRIEST"
    Tick()

    -- A dungeon NPC: its name is secret (UnitName is
    -- SecretWhenUnitNameIdentityRestricted), and so, for safety, are its
    -- level and whether it is the player. The name has to reach the plate as
    -- itself - it once went through `scrub` and came out blank.
    local secretName, secretLevel, secretSame = {}, {}, {}
    secretValues[secretName] = true
    secretValues[secretLevel] = true
    secretValues[secretSame] = true
    SetTarget({
        name = secretName, level = secretLevel, comparisonSecret = secretSame,
        isPlayer = false, reaction = 2,
        health = 5000, healthMax = 5000, power = 0, powerMax = 100, powerToken = "MANA",
    })
    local okNpc = pcall(function() NS:Refresh(); Tick() end)
    check("a dungeon NPC with a secret name, level and identity does not throw", okNpc)
    check("its secret name reaches the plate as itself, not blanked",
        target.nameText.text == secretName, tostring(target.nameText.text))
    check("its secret level is handed to the font string to format",
        target.levelText.text == secretLevel, tostring(target.levelText.text))
    check("and its level is written in the frames' #ffbb20, since it cannot be compared",
        Near(target.levelText.textColor, GOLD), Show(target.levelText.textColor))

    check("the name has no switch: always shown", DB.showName == nil)

    SetTarget(nil)
    NS:Refresh()
    Tick()
end

print("== the game's own frames ==")
check("the player frame's artwork is faded out",
    PlayerFrame.PlayerFrameContainer.alpha == 0, PlayerFrame.PlayerFrameContainer.alpha)
check("and so are its bars", PlayerFrame.PlayerFrameContent.alpha == 0)
-- (The player, 2026-10-20: a magenta orb and a white glow over the plate in Voidform.)
check("and the shadow class bar's Voidform art on them", InsanityBarFrame.alpha == 0)
check("the player frame itself is left alone, so the totems in it survive",
    PlayerFrame.alpha == nil, tostring(PlayerFrame.alpha))
check("the pet frame is faded out whole - the pet plate draws it now",
    PetFrame.alpha == 0, tostring(PetFrame.alpha))
check("it takes no clicks while it is invisible", PlayerFrame.mouseEnabled == false)
check("the target frame's artwork is faded out",
    TargetFrame.TargetFrameContainer.alpha == 0)
check("and its bars, name and level with it",
    TargetFrame.TargetFrameContent.TargetFrameContentMain.alpha == 0)
-- Its buffs and debuffs are deliberately NOT faded. This client will not let an
-- addon read a unit's auras, so this addon cannot draw them itself, and fading
-- the only display of them that works would lose them entirely.
check("but its buffs and debuffs are left alone, since only the game can draw them",
    (TargetFrame.TargetFrameContent.TargetFrameContentContextual.alpha or 1) == 1,
    tostring(TargetFrame.TargetFrameContent.TargetFrameContentContextual.alpha))
check("the focus frame goes the same way",
    FocusFrame.TargetFrameContainer.alpha == 0
    and FocusFrame.TargetFrameContent.TargetFrameContentMain.alpha == 0
    and (FocusFrame.TargetFrameContent.TargetFrameContentContextual.alpha or 1) == 1)
do
    local ok = true
    for _, frame in ipairs({ TargetFrame, FocusFrame }) do
        local c = frame.TargetFrameContent.TargetFrameContentContextual
        for _, key in ipairs({ "PvpBackgroundCircle", "PvpBackgroundIcon", "PvpIcon",
                "PrestigePortrait", "PrestigeBadge", "HighLevelTexture", "BossIcon",
                "LeaderIcon", "GuideIcon" }) do
            if c[key].alpha ~= 0 then ok = false end
        end
    end
    check("the game's own badges (Camelot's PvpBackground pair, its crown and guide mark included) are faded on both", ok)
end
-- THE GAME'S AURA ROWS, RETIRED.
-- The aura container is a forbidden object - an addon may not hide, anchor or
-- read it - so the frame that holds it is faded to nothing and shrunk to a
-- hundredth of its size: invisible, and too small to catch the mouse.
do
    check("the target frame is faded and shrunk, so its auras neither show nor take the mouse",
        TargetFrame.alpha == 0 and TargetFrame:GetScale() == 0.01,
        tostring(TargetFrame.alpha) .. " / " .. tostring(TargetFrame:GetScale()))
    check("the focus frame too", FocusFrame.alpha == 0 and FocusFrame:GetScale() == 0.01)

    TargetFrame.editModeSize = 1.5
    TargetFrame:UpdateSystemSettingFrameSize()
    check("Edit Mode's Frame Size cannot bring it back", TargetFrame:GetScale() == 0.01,
        tostring(TargetFrame:GetScale()))
end

-- Edit Mode is not allowed to move them or highlight them either.
do
    -- No field written onto them (a value the addon writes onto the game's
    -- frame taints the game's Edit Mode as it opens and closes): their
    -- selection box unseen and taking no mouse, by calls alone.
    check("no Edit Mode field of theirs written",
        TargetFrame.isLocked == nil and FocusFrame.isLocked == nil
        and TargetFrame.defaultHideSelection == nil and FocusFrame.defaultHideSelection == nil)
    check("their Edit Mode selection box unseen, taking no mouse",
        TargetFrame.Selection.alpha == 0 and TargetFrame.Selection.mouseEnabled == false
        and FocusFrame.Selection.alpha == 0 and FocusFrame.Selection.mouseEnabled == false)
    local moved = EditModeDragForTests(TargetFrame)
    check("so dragging one in Edit Mode does nothing at all", moved == false)
    TargetFrame.isSelected = false
end

-- THE ADDON'S OWN AURA ROWS: the client's aura container made for add-ons,
-- one per frame, each Below, Above or Off.
do
    local Auras = NS.UnitAuras
    local flow = AnchorUtil.FlowDirection
    local c = Auras.containers.target
    check("the target's own aura row, from the game's add-on aura container",
        c ~= nil and c.template == "CustomAuraContainerTemplate" and c.unit == "target"
        and c.parent == target)
    check("with no Edit Mode preview auras", c.editModePreview == false)
    check("your own buffs, the ones you can purge, everyone else's, your own debuffs and everyone else's",
        c.auraGroups.mybuffs.filter == "HELPFUL|PLAYER"
        and c.auraGroups.purge.filter == "HELPFUL|!PLAYER|RAID_PLAYER_DISPELLABLE"
        and c.auraGroups.buffs.filter == "HELPFUL|!PLAYER|!RAID_PLAYER_DISPELLABLE"
        and c.auraGroups.mine.filter:find("HARMFUL|PLAYER", 1, true) == 1
        and c.auraGroups.others.filter == "HARMFUL|!PLAYER")
    -- (isFromPlayerOrPlayerPet is true for ANY player's aura: asked for
    -- false, every buff another player cast was dropped - the player,
    -- 2026-10-05: a friendly target showed no buffs.)
    local function FromPlayer(key)
        return c.auraGroups[key].candidateFilters and c.auraGroups[key].candidateFilters.isFromPlayerOrPlayerPet
    end
    check("everyone else's split off by the filter tokens only, never by the aura's any-player field",
        FromPlayer("mybuffs") == true and FromPlayer("mine") == true and FromPlayer("purge") == nil
        and FromPlayer("buffs") == nil and FromPlayer("others") == nil)
    check("the two plain groups for a unit too far away to be seen: off while it is near",
        c.auraGroups.farbuffs.filter == "HELPFUL" and c.auraGroups.fardebuffs.filter == "HARMFUL"
        and c.auraGroups.farbuffs.enabled == false and c.auraGroups.fardebuffs.enabled == false
        and c.auraGroups.buffs.enabled ~= false and c.auraGroups.mine.enabled ~= false)
    check("your debuffs larger, as the game draws them (21 and 17), your buffs too",
        c.auraGroups.mine.sample.width == 21 and c.auraGroups.others.sample.width == 17
        and c.auraGroups.buffs.sample.width == 17 and c.auraGroups.mybuffs.sample.width == 21)
    local gold = DogsForeverUI.Style.GOLD
    local function Edge(sample)
        for _, region in ipairs(sample.regions or {}) do
            if region.layer == "BACKGROUND" and region.colorTexture then return region.colorTexture end
        end
    end
    check("your buffs edged in gold, everyone else's in black",
        Edge(c.auraGroups.mybuffs.sample)[1] == gold[1] and Edge(c.auraGroups.buffs.sample)[1] == 0)
    local ring
    for _, region in ipairs(c.auraGroups.purge.sample.regions or {}) do
        if region.texture == Auras.STEALABLE_ART then ring = region end
    end
    local plainRing = false
    for _, region in ipairs(c.auraGroups.buffs.sample.regions or {}) do
        if region.texture == Auras.STEALABLE_ART then plainRing = true end
    end
    check("a buff you can purge: the game's stealable border round it (added, 24 round 17); the rest none",
        ring ~= nil and ring.blendMode == "ADD" and ring.width == 24 and not plainRing,
        tostring(ring and ring.width))
    check("each with its icon, swipe and count handed to the game",
        c.auraGroups.buffs.sample.iconRegion ~= nil and c.auraGroups.buffs.sample.cooldown ~= nil
        and c.auraGroups.buffs.sample.count ~= nil)
    check("and a debuff's border in its dispel colour",
        c.auraGroups.mine.sample.dispel ~= nil and c.auraGroups.buffs.sample.dispel == nil)

    check("below to start: under the border, growing down",
        c.points[1] == "TOPLEFT" and c.points[2] == target and c.points[3] == "BOTTOMLEFT"
        and c.points[5] == -(DogsForeverUI.Style.BORDER_INSET + 7)
        and c.flowPoint == "TOPLEFT" and c.flowV == flow.Down and c.flowH == flow.Right,
        tostring(c.points[1]) .. " " .. tostring(c.points[5]))
    check("rows as wide as the frame", c.lineSize == DB.barWidth, tostring(c.lineSize))
    check("an enemy's debuffs first, their buffs on a row of their own (yours first)",
        c.auraGroups.mine.layout.layoutIndex == 1 and c.auraGroups.others.layout.layoutIndex == 2
        and c.auraGroups.mybuffs.layout.layoutIndex == 3 and c.auraGroups.mybuffs.layout.forceNewLine == true
        and c.auraGroups.purge.layout.layoutIndex == 4
        and c.auraGroups.buffs.layout.layoutIndex == 5 and c.auraGroups.buffs.layout.forceNewLine == false)

    friendlyUnits.target = true
    local before = c.updates
    Fire("PLAYER_TARGET_CHANGED")
    check("a new target: the row looks again", c.updates > before)
    check("and a friend's buffs come first, yours before the rest",
        c.auraGroups.mybuffs.layout.layoutIndex == 1 and c.auraGroups.buffs.layout.layoutIndex == 3
        and c.auraGroups.mine.layout.forceNewLine == true)
    check("a friend's buffs are never purged: that group off (out of range they passed it too)",
        c.auraGroups.purge.enabled == false)
    -- Too far away to be seen: the client cannot judge PLAYER / !PLAYER and
    -- every aura passes every group (the player, 2026-10-04: three times).
    local hadTarget = units.target
    units.target = units.target or { name = "Far", level = 60, health = 1, healthMax = 1,
                                     power = 0, powerMax = 1, reaction = 5 }
    farUnits.target = true
    before = c.updates
    Auras.Poll(nil, 1)
    check("too far to be seen: only the two plain groups, so each aura shows once",
        c.auraGroups.farbuffs.enabled == true and c.auraGroups.fardebuffs.enabled == true
        and c.auraGroups.mybuffs.enabled == false and c.auraGroups.buffs.enabled == false
        and c.auraGroups.mine.enabled == false and c.auraGroups.others.enabled == false
        and c.updates > before,
        tostring(UnitExists("target")) .. tostring(c.auraGroups.farbuffs.enabled) .. tostring(c.updates - before))
    farUnits.target = nil
    Auras.Poll(nil, 1)
    units.target = hadTarget
    check("seen again: the full row back, a friend's purge group still off",
        c.auraGroups.farbuffs.enabled == false and c.auraGroups.buffs.enabled == true
        and c.auraGroups.mybuffs.enabled == true and c.auraGroups.purge.enabled == false)
    friendlyUnits.target = nil
    Fire("PLAYER_TARGET_CHANGED")
    check("an enemy again: the purge group back on", c.auraGroups.purge.enabled == true)

    DB.targetAuras = "above"
    NS.Refresh()
    check("above: clear of the name row, growing up",
        c.points[1] == "BOTTOMLEFT" and c.points[3] == "TOPLEFT"
        and c.points[5] == NS.UnitPlate.TopRoom() + 7
        and c.flowPoint == "BOTTOMLEFT" and c.flowV == flow.Up,
        tostring(c.points[1]) .. " " .. tostring(c.points[5]))
    DB.targetAuras = "off"
    NS.Refresh()
    check("off: gone", c.shown == false and c.aurasEnabled == false)
    DB.targetAuras = "below"
    NS.Refresh()
    check("and back", c.shown == true and c.aurasEnabled == true)

    check("the focus has its own", Auras.containers.focus ~= nil
        and Auras.containers.focus.unit == "focus" and Auras.containers.focus.parent == focus)
    check("the target of target none to start - the game has none", Auras.containers.targettarget == nil)
    DB.targettargetAuras = "below"
    NS.Refresh()
    local totRow = Auras.containers.targettarget
    check("but one when asked for", totRow ~= nil and totRow.unit == "targettarget")
    local polled = totRow.updates
    Tick(0.6)
    check("looked at again on a timer, having no aura events of its own", totRow.updates > polled)
    DB.targettargetAuras = "off"
    NS.Refresh()
end

check("and both target-of-target frames whole, since nothing else lives in them",
    TargetFrameToT.alpha == 0 and FocusFrameToT.alpha == 0,
    tostring(TargetFrameToT.alpha))
-- The game's own cast bars: nothing written onto them. A value the addon
-- writes onto them is tainted, and the game's Edit Mode, changing the target
-- as it opens and closes, had the castbar read it - its opening and closing
-- then ran tainted ("attempt to compare local 'oldR' (a secret number value,
-- while execution tainted by 'DogsForeverUI')"). They are the retired target
-- and focus frames' children, so never seen.
check("the game's own cast bars: no field of theirs written, nothing called on them",
    TargetFrameSpellBar.showCastbar ~= false and FocusFrameSpellBar.showCastbar ~= false,
    tostring(TargetFrameSpellBar.showCastbar))

-- There is no option for this: two sets of unit frames is not a configuration
check("no setting is kept for it", DB.hideDefault == nil, tostring(DB.hideDefault))
do
    local point, relativeTo, relativePoint, x, y = TargetFrame:GetPoint()
    check("and the target frame, never moved, is where the game had it",
        point == "TOPLEFT" and relativeTo == UIParent
        and relativePoint == "TOPLEFT" and x == 250 and y == -100,
        tostring(point) .. " " .. tostring(x) .. ", " .. tostring(y))
end

print("== placing the frames ==")
do
    NS:Unlock()
    check("unlocking shows both plates", player:IsShown() == true and target:IsShown() == true)
    -- As the game's own frames are in Edit Mode: as they really look (the
    -- Edit Mode box over each says what it is).
    check("each as it really looks: its unit's name, health and level",
        player.nameText.text ~= "Player" and player.nameText.text ~= ""
        and player.healthText.text ~= "" and player.levelText.text ~= "",
        player.nameText.text)
    check("on the bars' own background, not a placing look",
        not PlacingLook(player.healthBG) and not PlacingLook(player.powerBG))
    check("clicking does not target or open a menu while placing",
        player.click:GetAttribute("*type1") == nil
        and player.click:GetAttribute("*type2") == nil)

    player.left, player.top = 400, 900
    player.click.scripts.OnMouseUp(player.click, "LeftButton")
    check("dragging one saves where it was put", DB.playerLeft == 400, DB.playerLeft)
    check("and stops the addon placing it at login", DB.playerPlaced == true)
    check("the other one is untouched", DB.targetPlaced ~= true)

    NS:Lock()
    Tick()
    check("locking takes the placement name and look off", player.nameText.text == "Dogsdog"
        and not PlacingLook(player.healthBG), player.nameText.text)
    check("and gives the clicks back",
        player.click:GetAttribute("*type1") == "target"
        and player.click:GetAttribute("*type2") == "togglemenu")

    -- In combat too, as the game's Edit Mode works in combat: the look at
    -- once, and what the game refuses in combat (the secure click actions)
    -- the moment it ends.
    blocked = {}
    inCombat = true
    NS:Unlock()
    Tick()
    check("unlocking in combat: unlocked at once",
        DB.unlocked == true and not PlacingLook(player.healthBG))
    check("nothing the game refuses in combat even tried", #blocked == 0, table.concat(blocked, ", "))
    check("the clicks are left as they were until it ends",
        player.click:GetAttribute("*type1") == "target")
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    check("combat over: the clicks go too", player.click:GetAttribute("*type1") == nil)
    inCombat = true
    NS:Lock()
    Tick()
    check("locking in combat too, nothing refused", DB.unlocked == false and #blocked == 0)
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    check("and the clicks are back after it", player.click:GetAttribute("*type1") == "target")
end

print("== in combat, nothing the game would refuse ==")
do
    -- The bug this section exists for. The plates were shown and hidden by
    -- hand from a 0.05s timer; a plate holds a secure button, which makes it
    -- protected, so in combat every one of those calls was refused, nothing
    -- changed, and the timer tried again - 7937 "interface actions failed"
    -- against this addon in one evening. Visibility belongs to the game's
    -- secure unit watch now.
    SetTarget(nil)
    Tick()
    blocked = {}
    inCombat = true

    SetTarget({
        name = "Hogger", level = 11, isPlayer = false, reaction = 1,
        health = 500, healthMax = 2000, power = 100, powerMax = 100, powerToken = "RAGE",
    })
    for _ = 1, 20 do Tick(0.05) end
    check("a target picked up in combat is shown", target:IsShown() == true)
    check("and painted", target.nameText.text == "Hogger", target.nameText.text)

    -- The target's target coming and going mid-fight, which it does all the
    -- time and which used to be the worst of it.
    units.targettarget = { name = "Sheep", level = 10, isPlayer = false, reaction = 4,
        health = 10, healthMax = 10, power = 0, powerMax = 0, powerToken = "MANA" }
    for _ = 1, 20 do Tick(0.05) end
    check("the target's target appears in combat", tot:IsShown() == true)
    units.targettarget = nil
    for _ = 1, 20 do Tick(0.05) end
    check("and goes again", tot:IsShown() == false)

    SetTarget(nil)
    for _ = 1, 20 do Tick(0.05) end
    check("a target dropped in combat is hidden", target:IsShown() == false)

    check("and not one show, hide or move of a plate was refused",
        #blocked == 0, table.concat(blocked, ", "))

    -- Settings changed mid-fight wait for the end of it rather than being
    -- refused.
    local width = target.width
    DB.barWidth = DB.barWidth + 40
    NS:Refresh()
    for _ = 1, 5 do Tick(0.05) end
    check("a size changed in combat waits", target.width == width, target.width)
    check("still nothing refused", #blocked == 0, table.concat(blocked, ", "))

    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    Tick()
    check("combat over, the new size lands", target.width == width + 40, target.width)

    DB.barWidth = DB.barWidth - 40
    NS:Refresh()
    Tick()
    check("and the old size comes back once set again",
        player:IsShown() == true and target.width == width, target.width)
end

print("== a reload in the middle of a fight ==")
do
    -- Anchoring a protected frame is refused in combat, so the plates wait for
    -- the end of it rather than being built half way.
    local keptPlates = NS.plates
    NS.plates = nil
    inCombat = true
    Fire("PLAYER_ENTERING_WORLD")
    check("no plate is built in combat", NS.plates == nil)
    local ok = pcall(Tick)
    check("and nothing throws while there is none", ok)

    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    check("they are built the moment combat ends", NS.plates ~= nil)

    NS.plates = keptPlates
    NS:Refresh()
end

print("== the options ==")
DB.showHealthText, DB.showPowerText = false, false
NS:Refresh()
Tick()
check("the name is always there", player.nameText.text == "Dogsdog", player.nameText.text)
check("the health number can be turned off", player.healthText.text == "")
check("and the resource number", player.powerText.text == "")
DB.showHealthText, DB.showPowerText = true, true
NS:Refresh()

print("== the lock button and reset ==")
DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
check("the lock button unlocks", DB.unlocked == true)
DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
check("and locks", DB.unlocked == false)

-- A right-click on a frame being placed does nothing: the placing dialog is
-- what locks. While unlocked it has no unit menu to open either.
DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
check("unlocked, a right-click has no menu to open", player.click:GetAttribute("*type2") == nil)
pendingTimer = nil
player.click.scripts.OnMouseUp(player.click, "RightButton")
check("right-clicking a placed frame does not lock them",
    DB.unlocked == true and pendingTimer == nil and player.click:GetAttribute("*type2") == nil)
DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
check("locked, the unit menu is back on right-click",
    player.click:GetAttribute("*type2") == "togglemenu")
DB.barWidth = 200
DogsForeverUI:Reset("frames")
check("a reset puts the defaults back", DB.barWidth == 150, DB.barWidth)

print("== the pet ==")
do
    local pet = NS.plates.pet
    check("a pet plate is built", pet ~= nil and pet.unit == "pet")
    check("drawn small, like the target of target",
        pet:GetWidth() == math.floor(DB.barWidth * NS.UnitPlate.SMALL_SCALE + 0.5), pet:GetWidth())
    check("with no badges and no cast bar",
        pet.pvpBadge == nil and pet.eliteBadge == nil and pet.castbar == nil)

    -- Its place: under the player's frame, left edges lined up, its name band
    -- clear of the player's border.
    -- Worked out here from the pieces: the player's frame, its border, a gap
    -- of 6, and the pet's own name band over it.
    local function Under(playerTop)
        return playerTop - (DB.barHeight + 1 + DB.powerHeight)
            - DogsForeverUI.Style.BORDER_INSET - 6
            - NS.UnitPlate.TopRoom() * NS.UnitPlate.SMALL_SCALE
    end
    -- (No place of its own yet: a first start, or a reset.)
    DB.petPlaced, DB.petLeft, DB.petTop = nil, nil, nil
    DB.playerPlaced, DB.playerLeft, DB.playerTop = true, 300, -500
    NS.Refresh()
    check("by default under the player's frame, lined up with its left edge",
        DB.petLeft == 300 and math.abs(DB.petTop - Under(-500)) < 1e-9,
        DB.petLeft .. ", " .. DB.petTop)
    check("its name band clear of the player's border",
        DB.petTop + NS.UnitPlate.TopRoom() * NS.UnitPlate.SMALL_SCALE
            < -500 - (DB.barHeight + 1 + DB.powerHeight) - DogsForeverUI.Style.BORDER_INSET)
    check("and the plate is put there",
        pet.points[1] == "TOPLEFT" and pet.points[4] == DB.petLeft and pet.points[5] == DB.petTop)

    -- Worked out once: it never moves with the player's frame - only when
    -- anchored to it on purpose, in Edit Mode.
    local petTop = DB.petTop
    player.left, player.top = 420, 1080 - 610
    DB.unlocked = true
    player.click.scripts.OnMouseDown(player.click, "LeftButton")
    player.click.scripts.OnMouseUp(player.click, "LeftButton")
    DB.unlocked = false
    check("dragging the player's frame leaves the pet where it is",
        DB.petLeft == 300 and DB.petTop == petTop, DB.petLeft .. ", " .. DB.petTop)
    DB.barHeight = 40
    NS.Refresh()
    check("and so does a taller player frame", DB.petTop == petTop, DB.petTop)
    DB.barHeight = 30
    Fire("PLAYER_ENTERING_WORLD")
    check("and a loading screen", DB.petLeft == 300 and DB.petTop == petTop)
    DB.petLeft, DB.petTop = nil, nil
    NS.Refresh()
    check("its place cleared (Reset To Default Position): under the player's frame again, where it is now",
        DB.petLeft == 420 and math.abs(DB.petTop - Under(-610)) < 1e-9, DB.petLeft .. ", " .. DB.petTop)

    DB.petPlaced, DB.petLeft, DB.petTop = true, 77, -88
    DB.playerLeft = 555
    NS.Refresh()
    check("once placed itself, it stays put", DB.petLeft == 77 and DB.petTop == -88)
    DB.petPlaced = nil
    DB.playerPlaced = nil
    Fire("PLAYER_ENTERING_WORLD")

    -- Shown while there is a pet, by the game's unit watch.
    check("no pet, no plate", pet:IsShown() == false)
    units.pet = { name = "Wolfie", level = 58, isPlayer = false, reaction = 5, playerControlled = true,
        health = 900, healthMax = 1000, power = 50, powerMax = 100, powerToken = "FOCUS" }
    friendlyUnits.pet = true
    Fire("UNIT_PET", "player")
    Tick()
    check("a pet brings it out, with the pet's name",
        pet:IsShown() == true and pet.nameText.text == "Wolfie", pet.nameText.text)
    check("and its health", pet.health.value == 900 and pet.health.max == 1000)
    check("a friendly pet: the health green, not a selection colour",
        Near(pet.health.statusColor, HEALTH), Show(pet.health.statusColor))
    check("its focus exactly the game's orange", Near(pet.power.statusColor, { 1, 0.5, 0.25 }),
        Show(pet.power.statusColor))

    -- Another pet between two looks of the unit watch: no hide and show.
    units.pet = { name = "Fluffy", level = 58, isPlayer = false, reaction = 5,
        health = 50, healthMax = 100, power = 0, powerMax = 0, powerToken = "MANA" }
    Fire("UNIT_PET", "player")
    check("a different pet is repainted at once", pet.nameText.text == "Fluffy",
        pet.nameText.text)

    -- The right-click is the game's pet menu.
    check("left-click targets the pet, right-click opens its menu",
        pet.click:GetAttribute("unit") == "pet" and pet.click:GetAttribute("*type1") == "target"
        and pet.click:GetAttribute("*type2") == "togglemenu")

    -- A hunter's pet wears the game's happiness face, made on the plate.
    check("the plate carries the game's happiness face",
        pet.happiness ~= nil and pet.happiness.template == "PetFrameHappinessTemplate")
    check("on the plate's outer side",
        pet.happiness.points[1] == "LEFT" and pet.happiness.points[2] == pet
        and pet.happiness.points[3] == "RIGHT")
    petHappiness = nil
    Fire("UNIT_PET", "player")
    check("hidden for a pet with no mood to show", pet.happiness:IsShown() == false)
    petHappiness = 3
    Fire("UNIT_PET", "player")
    check("shown for a hunter's pet", pet.happiness:IsShown() == true)
    check("taking the mouse, for its tooltip", pet.happiness.mouseEnabled == true)
    petHappiness = nil

    -- The game's pet frame is off screen, and nothing of it takes the mouse.
    check("the game's pet frame takes no clicks", PetFrame.mouseEnabled == false)
    check("its aura row is hidden, so no invisible aura pops a tooltip",
        PetFrame.AuraFrameContainer:IsShown() == false)
    check("its happiness face takes no mouse", PetFrameHappiness.mouseEnabled == false)
    check("it is out of Edit Mode: its box unseen, taking no mouse - no field of it written",
        PetFrame.isLocked == nil and PetFrame.Selection.alpha == 0 and PetFrame.Selection.mouseEnabled == false)
    -- The managed-frame container puts its alpha back whenever the UI returns.
    PetFrame:SetAlpha(1)
    check("the game putting its alpha back is undone at once", PetFrame.alpha == 0,
        tostring(PetFrame.alpha))

    -- Its buffs and debuffs, like the game's pet frame, at the game's 15.
    local Auras = NS.UnitAuras
    local row = Auras.containers.pet
    check("the pet has an aura row, below it", row ~= nil and row.unit == "pet"
        and Auras.Side("pet") == "below")
    check("with the game's pet aura size",
        row.auraGroups.buffs.sample.width == 15, row.auraGroups.buffs.sample.width)
    local updates = row.updates
    Fire("UNIT_PET", "player")
    check("a new pet makes it look again", row.updates > updates)

    units.pet = nil
    Fire("UNIT_PET", "player")
    Tick()
    check("the pet gone, the plate goes", pet:IsShown() == false)
end

print("== a class keeps its own colour ==")
do
    -- Exactly the game's class colour: toned, druid orange once came out red,
    -- and every class looked unlike itself.
    SetTarget({ name = "Moonkin", level = 60, class = "DRUID", isPlayer = true, reaction = 5,
        health = 100, healthMax = 100, power = 1, powerMax = 1, powerToken = "MANA" })
    Tick()
    local worn = target.health.statusColor
    check("a druid wears the game's druid orange, exactly",
        Near(worn, { 1, 0.49, 0.04 }), Show(worn))
    check("orange, not red: green at more than a third of red",
        worn[2] > worn[1] / 3 and worn[3] < worn[2], Show(worn))
    SetTarget(nil)
end

print("== an empowered cast (retail's Evokers): a cast, held at its last stage ==")
do
    -- The client reports one as a channel with its stages (isEmpowered,
    -- numStages, never secret); the game's bar fills it and adds the hold.
    local plainChannel = UnitChannelInfo
    function UnitChannelInfo(token)
        local c = casting[token]
        if c and c.stages and not castingSecret[token] then
            return c.name, c.name, "icon", c.start * 1000, c.finish * 1000, false, false, 1, true, c.stages
        end
        return plainChannel(token)
    end
    function GetUnitEmpowerHoldAtMaxTime() return 1000 end

    SetTarget({ name = "Scalecommander", level = 70, isPlayer = false, reaction = 2,
        health = 100, healthMax = 100, power = 0, powerMax = 100, powerToken = "MANA" })
    local bar = target.castbar.bar
    casting.target = { name = "Fire Breath", start = now, finish = now + 2, channel = true, stages = 3 }
    Fire("UNIT_SPELLCAST_EMPOWER_START", "target")
    Tick()
    check("measured with the hold at its last stage", select(2, bar:GetMinMaxValues()) == 3,
        tostring(select(2, bar:GetMinMaxValues())))
    check("in the cast's colour, not the channel's",
        Near(bar.statusColor, DogsForeverUI.Style.CAST_COLOR.casting), Show(bar.statusColor))
    local before = bar:GetValue()
    Tick(1)
    check("filling, not draining", bar:GetValue() > before, bar:GetValue())

    Fire("UNIT_SPELLCAST_EMPOWER_STOP", "target", "cast-1", 1, SECRET_TRUE)
    check("a secret end is never looked at", not Near(bar.statusColor, Toned(0.9, 0.2, 0.2, POWER_TOP)))
    Fire("UNIT_SPELLCAST_EMPOWER_STOP", "target", "cast-1", 1, false)
    casting.target = nil
    Tick()
    check("cut short: held in the interrupted red",
        bar:IsShown() == true and Near(bar.statusColor, Toned(0.9, 0.2, 0.2, POWER_TOP)), Show(bar.statusColor))

    castingSecret.target = true
    casting.target = { name = "Fire Breath", start = now, finish = now + 2, channel = true, stages = 3 }
    function UnitChannelInfo(token)
        local c = casting[token]
        if c and c.stages and castingSecret[token] then
            local s = SecretCastValue
            return s("name"), s("name"), s("icon"), s("start"), s("end"), false, s("notInterruptible"),
                s("spell"), true, c.stages
        end
        return plainChannel(token)
    end
    Tick(1)
    local ok, err = pcall(Tick)
    check("a secret empowered cast does not throw", ok, tostring(err))
    check("and fills like a cast", bar.timer ~= nil
        and bar.timer.direction == Enum.StatusBarTimerDirection.ElapsedTime)
    castingSecret.target, casting.target = nil, nil
    UnitChannelInfo, GetUnitEmpowerHoldAtMaxTime = plainChannel, nil
    SetTarget(nil)
    Tick()
end

print("== retail: the PvP badge in retail's own faction art ==")
do
    -- UnitPlate.lua alone as the retail client loads it (Core.RETAIL set),
    -- next to everything else as it is.
    local retail = setmetatable({ RETAIL = true, Frames = setmetatable({}, { __index = NS }) },
        { __index = DogsForeverUI })
    local env = setmetatable({ DogsForeverUI = retail }, { __index = _G })
    assert(loadfile(ADDON_PATH .. "/Frames/UnitPlate.lua", "t", env))("DogsForeverUI", {})
    atlases["UI-HUD-UnitFrame-Player-PVP-HordeIcon"] = { width = 30, height = 40 }
    units.target = { name = "Grunt", level = 70, isPlayer = false, reaction = 2, faction = "Horde", pvp = true,
        health = 100, healthMax = 100, power = 0, powerMax = 100, powerToken = "MANA" }
    local plate = retail.Frames.UnitPlate.New("target", "RetailTarget")
    plate:Refresh()
    check("a flagged Horde unit wears retail's Horde emblem (there is no small circle there)",
        plate.pvpBadge.shown and plate.pvpBadge.icon.atlas == "UI-HUD-UnitFrame-Player-PVP-HordeIcon",
        tostring(plate.pvpBadge.icon.atlas))
    units.target = nil
end

Summary()
