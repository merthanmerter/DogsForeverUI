-- The Castbar module: the player's casting bar, the swing bars above it, and
-- what is done to the game's own castbar and swing timer.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

local Style

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

-- The bar in a state's colour, on the flat fill every bar wears, with its sheen.
local function Wears(bar, state)
    return bar:GetStatusBarTexture().texture == Style.FLAT_TEXTURE and bar.sheen ~= nil
        and Near(bar.statusColor, Style.CAST_COLOR[state])
end


-- Begin a cast the way the game does: set what the API will report, then send
-- the event that says to go and read it. Every cast carries an ID, as the game's
-- do, because that is how an event is told to be about this cast rather than
-- about some other spell the player pressed while it was running.
local castID = "cast-1"

-- opts.text: the cast's display text, when it is not its name (the game's
-- spells behind using an object are named "No Text").
local function StartCast(name, length, opts)
    opts = opts or {}
    castID = opts.castID or castID
    local text = opts.text or name
    if opts.noText then text = nil end
    castingInfo = { name, text, "Interface\\Icons\\" .. name, now * 1000,
        (now + length) * 1000, false, castID, opts.notInterruptible or false }
    channelInfo = nil
    Fire(opts.event or "UNIT_SPELLCAST_START", "player", castID, 1)
end

local function StartChannel(name, length, opts)
    opts = opts or {}
    castingInfo = nil
    channelInfo = { name, name, "Interface\\Icons\\" .. name, now * 1000,
        (now + length) * 1000, false, opts.notInterruptible or false }
    Fire(opts.event or "UNIT_SPELLCAST_CHANNEL_START", "player", nil, 1)
end

-- The game clears the cast before it sends the event that ends it.
local function StopCast(event, interruptedBy)
    castingInfo, channelInfo = nil, nil
    Fire(event or "UNIT_SPELLCAST_STOP", "player", castID, 1, interruptedBy)
end

-- What the game sends when a spell the player pressed is refused while another
-- cast is still running: the same event, with a different cast's ID, and the
-- cast underneath carrying on untouched.
local function OtherSpellFailed(event)
    Fire(event or "UNIT_SPELLCAST_FAILED", "player", "cast-other", 2)
end

LoadAddon()
Style = DogsForeverUI.Style

local bar = DogsForeverUI.Castbar.CastBar.castbar
local DB

-------------------------------------------------------------------------------

print("== loading ==")
Fire("ADDON_LOADED", "DogsForeverUI")
DB = DogsForeverUI.Castbar.db

check("the addon builds its saved settings", type(DB) == "table")
check("with the defaults filled in", DB.barWidth == 130 and DB.barHeight == 20)
check("and no switches: the castbar, its spell name and the swing bars are always on",
    DB.enabled == nil and DB.showText == nil and DB.showSwing == nil and DB.failedHold == nil
    and DogsForeverUI.Castbar.FAILED_HOLD == 0.6)
check("and a position worked out from the screen size",
    DB.barLeft == (1920 - 130) / 2, DB.barLeft)
check("placement mode is never restored", DB.unlocked == false)

print("== the bar is off screen when nothing is happening ==")
-- It is not kept on screen the rest of the time. Unlocking is how it is found in
-- order to be placed, which is why that is reachable from a command and from the
-- options rather than only by right-clicking a bar that is not there.
Tick(0)
check("with nothing casting the bar is not drawn", bar:IsShown() == false)
check("and a refresh does not put it back", (function()
    DogsForeverUI.Castbar:Refresh()
    return bar:IsShown() == false
end)())

DogsForeverUI.Castbar:Unlock()
check("unlocking is what brings it out to be placed", bar:IsShown() == true)
DogsForeverUI.Castbar:Lock()
check("and locking takes it away again", bar:IsShown() == false)

DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
check("the options' lock button unlocks it", DB.unlocked == true and bar:IsShown() == true)
DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
check("and locks it again", DB.unlocked == false and bar:IsShown() == false)

-- Right-clicking the bar used to unlock it. It does not any more, and there is
-- nothing else a click on a locked bar should do either.
bar.scripts.OnMouseDown(bar, "RightButton")
check("right-clicking the bar does nothing at all",
    DB.unlocked == false and bar:IsShown() == false)
check("and a locked bar does not take mouse clicks in the first place",
    bar.mouseEnabled == false, bar.mouseEnabled)

-- While it is being placed, a right-click used to lock it again. The placing
-- dialog does that now, and a right-click does nothing.
DogsForeverUI.Castbar.Unlock()
pendingTimer = nil
bar.scripts.OnMouseUp(bar, "RightButton")
check("right-clicking an unlocked bar does nothing: it stays unlocked",
    DB.unlocked == true and pendingTimer == nil and bar:IsShown() == true)
DogsForeverUI.Castbar.Lock()
check("locked, it is put away", DB.unlocked == false and bar:IsShown() == false)

print("== the game's own castbar ==")
check("it is hidden as soon as the addon loads",
    PlayerCastingBarFrame:IsShown() == false)
-- The game shows its bar again at the start of every cast, so one Hide() would
-- only last until the next one.
PlayerCastingBarFrame:Show()
check("and hidden again when the game shows it",
    PlayerCastingBarFrame:IsShown() == false)

-- There is no option for this: the addon being on is what hides the game's bar,
-- because two casting bars is not a configuration anybody wants.
check("no setting is kept for it", DB.hideDefault == nil, tostring(DB.hideDefault))
DogsForeverUI.Castbar:Refresh()
PlayerCastingBarFrame:Show()
check("a refresh leaves it away", PlayerCastingBarFrame:IsShown() == false)

print("== a cast ==")
-- The last cast ended nearly full; the new one must not show that for a frame.
bar:SetMinMaxValues(0, 1)
bar:SetValue(0.98)
StartCast("Holy Light", 2.5)
check("the bar appears", bar:IsShown() == true)
check("already at the new cast's start, not a flash of the last one's end",
    bar:GetValue() < 0.01 and select(2, bar:GetMinMaxValues()) == 2.5, bar:GetValue())
check("fading in from nothing, not appearing at once", bar:GetAlpha() == 0, bar:GetAlpha())
Tick(Style.FADE_IN / 2)
check("part-way in", bar:GetAlpha() > 0 and bar:GetAlpha() < 1, bar:GetAlpha())
Tick(Style.FADE_IN)
check("then fully there", bar:GetAlpha() == 1, bar:GetAlpha())
check("with the spell's name on it", bar.spellText.text == "Holy Light", bar.spellText.text)
-- The addon's one look: the cast bar art, in the game's castbar yellow.
check("wearing the flat fill in the cast colour",
    Wears(bar, "casting"),
    tostring(bar:GetStatusBarTexture().texture) .. " / " .. Show(bar.statusColor))
check("the labels' own gold, #ffbb20, not the game's orange-leaning classic yellow",
    Near(bar.statusColor, { 1, 0xbb / 255, 0x20 / 255 }), Show(bar.statusColor))
check("on the black background, at half",
    bar.bg.colorTexture ~= nil and Near(bar.bg.colorTexture, Style.BACKGROUND_COLOR) and bar.bg.colorTexture[4] == 0.5,
    tostring(bar.bg.colorTexture and bar.bg.colorTexture[1]))
check("with white labels",
    Near(bar.spellText.textColor, { 1, 1, 1 })
    and Near(bar.timeText.textColor, { 1, 1, 1 }),
    Show(bar.spellText.textColor))

check("and measures the cast's own length", select(2, bar:GetMinMaxValues()) == 2.5)

Tick(1.0 - 1.5 * Style.FADE_IN)
check("a second in, it is a second along", math.abs(bar:GetValue() - 1.0) < 0.001,
    bar:GetValue())
check("and the timer counts down, not up", bar.timeText.text == "1.5", bar.timeText.text)

-- The spark rides the leading edge, so its offset is the bar's width times how
-- far along the cast is.
check("the spark sits at the leading edge",
    math.abs(bar.spark.points[4] - DB.barWidth * (1.0 / 2.5)) < 0.001,
    bar.spark.points[4])

-- The moment the cast is done the bar is on its way out: it is not left
-- sitting at 0.0 - or, when the last frame landed just short of the end, at
-- 0.1 - waiting for the stop event to arrive. That is what a stuck bar looks
-- like. It fades rather than vanishing.
Tick(1.6)
Tick(Style.FADE_OUT / 2)
check("the moment the cast is done the bar fades out",
    bar:IsShown() == true and bar:GetAlpha() < 1, bar:GetAlpha())
Tick(Style.FADE_OUT)
check("and is gone", bar:IsShown() == false)
StopCast()
check("and the stop event that follows changes nothing", bar:IsShown() == false)

print("== a channel drains instead of filling ==")
StartChannel("Drain Life", 4)
Tick(0)
check("a channel starts full", math.abs(bar:GetValue() - 4) < 0.001, bar:GetValue())
Tick(1)
check("and empties as it runs", math.abs(bar:GetValue() - 3) < 0.001, bar:GetValue())
check("in the channel colour",
    Wears(bar, "channel"),
    tostring(bar:GetStatusBarTexture().texture))

print("== how a cast ends ==")
StopCast("UNIT_SPELLCAST_CHANNEL_STOP")
Tick(Style.FADE_OUT + 0.05)
check("a channel that runs its course fades away", bar:IsShown() == false)

StartCast("Holy Light", 2.5)
Tick(0.5)
StopCast("UNIT_SPELLCAST_INTERRUPTED")
check("an interrupted cast wears the failed colour",
    Wears(bar, "failed"),
    tostring(bar:GetStatusBarTexture().texture))
check("and fills, so the colour reads as a bar", bar:GetValue() == 1, bar:GetValue())
Tick(DogsForeverUI.Castbar.FAILED_HOLD - 0.01)
check("it is held long enough to be read", bar:IsShown() == true)
check("and the four state colours are gone from the settings",
    DB.statusBarColor == nil and DB.channelColor == nil
    and DB.uninterruptibleColor == nil and DB.failedColor == nil)
Tick(0.02)
Tick(Style.FADE_OUT + 0.05)
check("and then fades away", bar:IsShown() == false)

-- A channel is interrupted by its stop event carrying whoever did it; without
-- that it simply ended.
StartChannel("Drain Life", 4)
Tick(1)
StopCast("UNIT_SPELLCAST_CHANNEL_STOP", "Creature-0-1-2-3-4-5")
check("an interrupted channel says so the same way",
    bar:IsShown() == true
    and Wears(bar, "failed"),
    tostring(bar:GetStatusBarTexture().texture))
Tick(DogsForeverUI.Castbar.FAILED_HOLD + 0.01)

-- Whoever did the interrupting may come back as a secret, and a secret may not
-- be compared - not even to nil. A name that cannot be read is still a name.
do
    local secretInterrupter = {}
    secretValues[secretInterrupter] = true

    StartChannel("Drain Life", 4)
    Tick(1)
    local ok = pcall(StopCast, "UNIT_SPELLCAST_CHANNEL_STOP", secretInterrupter)
    check("a secret interrupter does not throw", ok)
    check("and still reads as an interruption", bar:IsShown() == true
        and Wears(bar, "failed"),
        tostring(bar:GetStatusBarTexture().texture))
    Tick(DogsForeverUI.Castbar.FAILED_HOLD + 0.01)
end

print("== events belonging to some other spell ==")
-- The bug this fixes: pressing a second spell while one is casting - a queued
-- instant, a second swing at a skinning node - makes the game refuse the new
-- one, and that refusal arrives as UNIT_SPELLCAST_FAILED for the player like any
-- other. Taken at face value it turned the bar red while the cast underneath it
-- carried on quite happily.
do
    StartCast("Holy Light", 2.5, { castID = "cast-real" })
    Tick(0.5)
    OtherSpellFailed()
    Tick(0)
    check("a queued spell failing does not turn the cast red",
        Wears(bar, "casting"),
        tostring(bar:GetStatusBarTexture().texture))
    check("and the cast carries on", bar:IsShown() == true
        and math.abs(bar:GetValue() - 0.5) < 0.001, bar:GetValue())

    OtherSpellFailed("UNIT_SPELLCAST_INTERRUPTED")
    Tick(0)
    check("nor does an interrupt meant for another spell",
        bar:IsShown() == true
        and Wears(bar, "casting"))

    -- The same again with cast IDs the client will not let us compare: the
    -- fallback asks the game whether anything is still casting, and something is.
    local secretID = {}
    secretValues[secretID] = true
    StartCast("Holy Light", 2.5, { castID = secretID })
    Tick(0.5)
    local ok = pcall(OtherSpellFailed)
    check("a secret cast ID does not throw", ok)
    Tick(0)
    check("and the cast still carries on", bar:IsShown() == true
        and Wears(bar, "casting"))

    -- But a real interruption, where the game has already cleared the cast,
    -- still reads as one.
    castingInfo = nil
    Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "cast-other", 2)
    check("while a real interruption still says so",
        Wears(bar, "failed"),
        tostring(bar:GetStatusBarTexture().texture))
    Tick(DogsForeverUI.Castbar.FAILED_HOLD + 0.01)
    castID = "cast-1"
end

print("== no cooldown is ever read ==")
-- This addon drew a global cooldown bar until 2026-09-22. Three designs were
-- tried and all three failed; the third failed *in game*, throwing once per
-- frame, because LuaDurationObject:IsActive() returns a secret boolean in combat
-- and merely testing it is an error. The core file records the whole history.
--
-- Every cooldown call in this harness raises, so anything that goes looking for
-- one fails here instead of in somebody's raid.
do
    local ok = pcall(Tick, 0)
    check("an idle frame reads no cooldown", ok)

    StartCast("Holy Light", 2.5)
    local okCast = pcall(Tick, 0.2)
    check("nor does a frame with a cast running", okCast)
    check("and the cast draws normally", bar:IsShown() == true
        and bar.spellText.text == "Holy Light", bar.spellText.text)
    StopCast()
    Tick(0)
    Tick(Style.FADE_OUT + 0.05)
    check("with nothing drawn behind it once it ends", bar:IsShown() == false)

    -- The settings that only existed for it are gone too.
    check("no showGCD setting remains", DB.showGCD == nil, tostring(DB.showGCD))
    check("no gcdColor setting remains", DB.gcdColor == nil, tostring(DB.gcdColor))
end

print("== pushback and interruptibility ==")
StartCast("Heal", 3)
Tick(1)
-- A pushback does not restart the cast, it moves the end: the addon re-reads
-- rather than trusting the event's arguments, so the new time is picked up.
castingInfo[5] = (now + 2.5) * 1000
Fire("UNIT_SPELLCAST_DELAYED", "player")
Tick(0)
check("a pushback moves the end of the cast",
    math.abs(select(2, bar:GetMinMaxValues()) - 3.5) < 0.001,
    select(2, bar:GetMinMaxValues()))

Fire("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "player")
check("an uninterruptible cast changes colour",
    Wears(bar, "uninterruptible"),
    tostring(bar:GetStatusBarTexture().texture))
Fire("UNIT_SPELLCAST_INTERRUPTIBLE", "player")
check("and changes back",
    Wears(bar, "casting"))
StopCast()
Tick(0)

print("== cast times the client will not let us read ==")
-- Storing a secret and handing it to SetValue is allowed; reading it is not. The
-- bar still has to work, without the parts that need arithmetic.
do
    local secretStart, secretEnd = {}, {}
    secretValues[secretStart] = true
    secretValues[secretEnd] = true

    castingInfo = { "Shadow Bolt", "Shadow Bolt", "icon", secretStart, secretEnd,
        false, "cast-9", false }
    channelInfo = nil
    local ok = pcall(Fire, "UNIT_SPELLCAST_START", "player")
    check("a cast with secret times does not throw", ok)
    local okTick = pcall(Tick, 0.5)
    check("nor does drawing it", okTick)
    check("the bar is still shown", bar:IsShown() == true)
    check("with the spell's name", bar.spellText.text == "Shadow Bolt")
    check("the secret is handed to the bar untouched",
        select(2, bar:GetMinMaxValues()) == secretEnd)
    check("and no timer is invented for it", bar.timeText.text == "", bar.timeText.text)
    StopCast()
    Tick(0)
end

print("== the swing bars ==")
local SB = DogsForeverUI.Castbar.SwingBars
local mh, oh, ranged = SB.bars[1], SB.bars[2], SB.bars[3]
do
    attackSpeed = { 2.6, nil, nil }
    DogsForeverUI.Castbar:Refresh()

    check("there are three, in the game's order",
        mh.hand.label == "Main Hand" and oh.hand.label == "Off Hand"
        and ranged.hand.label == "Ranged")
    check("each exactly the castbar's size",
        mh.width == DB.barWidth and mh.height == DB.barHeight,
        tostring(mh.width) .. "x" .. tostring(mh.height))
    check("with the castbar's border, three pixels outside it",
        mh.border ~= nil and mh.border.points[1] == "BOTTOMRIGHT"
        and mh.border.points[4] == 3 and mh.border.points[5] == -3)
    check("the one difference: each hand's colour from the palette",
        Near(mh.statusColor, Style.SWING_COLOR.mainhand)
        and Near(oh.statusColor, Style.SWING_COLOR.offhand)
        and Near(ranged.statusColor, Style.SWING_COLOR.ranged),
        Show(mh.statusColor))
    check("on the flat fill with its sheen, in grey as the game's swing timer is",
        mh:GetStatusBarTexture().texture == Style.FLAT_TEXTURE and mh.sheen ~= nil
        and Near(mh.statusColor, { 0.6, 0.6, 0.6 }))
    check("its text white, as the castbar's",
        Near(mh.typeText.textColor, { 1, 1, 1 }) and Near(mh.timeText.textColor, { 1, 1, 1 }))

    -- Nothing is happening, so nothing is shown. The game's own bars sit on
    -- screen empty all day; these follow the castbar's rule instead.
    check("with nothing swinging, no bar is on screen",
        not mh:IsShown() and not oh:IsShown() and not ranged:IsShown())

    -- A swing, exactly as the client reports one: how long until the next,
    -- and which hand.
    -- The game's own swing timer switched off (Options > Advanced, Edit
    -- Mode's Swing Timer box): off here too.
    C_CVar.SetCVar("showSwingTimer", "0")
    Fire("PLAYER_SWING", 2.6, 0)
    check("the game's swing timer off: no bar, even swinging", not mh:IsShown())
    DogsForeverUI.Castbar.db.unlocked = true
    DogsForeverUI.Castbar:Refresh()
    check("nor in Unlock Mode - the whole group away, so it has no piece there",
        not mh:IsShown() and SB.group.shown == false)
    DogsForeverUI.Castbar.db.unlocked = false
    C_CVar.SetCVar("showSwingTimer", "1")
    check("switched on again in the game: back at once", SB.group.shown ~= false)
    DogsForeverUI.Castbar:Refresh()

    Fire("PLAYER_SWING", 2.6, 0)
    check("a swing brings its bar up", mh:IsShown() == true)
    check("starting from empty",
        mh:GetValue() == 0 and select(2, mh:GetMinMaxValues()) == 2.6)
    check("with the hand's name and the time to the next swing on it",
        mh.typeText.text == "Main Hand" and mh.timeText.text == "2.6", mh.timeText.text)
    Tick(1)
    check("a second later it is a second along",
        math.abs(mh:GetValue() - 1) < 0.001, mh:GetValue())
    check("and counts down", mh.timeText.text == "1.6", mh.timeText.text)

    -- The next swing's event lands a moment after the timer runs out. Hiding
    -- at exactly zero made the bar blink between every swing, so it holds.
    Tick(1.6)
    check("when the next swing is due it empties",
        mh:GetValue() == 0 and mh.timeText.text == "0.0", mh.timeText.text)
    check("but stays up, waiting for that swing", mh:IsShown() == true)
    Tick(0.3)
    Fire("PLAYER_SWING", 2.6, 0)
    check("a swing arriving in that time carries straight on, with no blink",
        mh:IsShown() == true and mh.timeText.text == "2.6")
    Tick(2.6)
    Tick(1.1)
    Tick(Style.FADE_OUT + 0.05)
    check("and when no swing comes, the bar fades away", mh:IsShown() == false)

    Fire("PLAYER_SWING", 1.8, 1)
    check("a swing for a hand with nothing in it is ignored",
        oh.endTime == nil and not oh:IsShown())

    local secret = {}
    secretValues[secret] = true
    local ok = pcall(Fire, "PLAYER_SWING", secret, 0)
    check("a duration the client will not let us read does not throw", ok)
    check("and brings nothing up", mh.endTime == nil and not mh:IsShown())
    secretValues[secret] = nil

    -- Every hand that is swinging gets a row - ranged, off hand, main hand, top
    -- to bottom - and the stack closes up round the ones that are not.
    attackSpeed = { 2.6, 1.8, nil }
    Fire("WEAPON_SLOT_CHANGED")
    check("equipping an off hand shows nothing until it swings", oh:IsShown() == false)
    Fire("PLAYER_SWING", 2.6, 0)
    Fire("PLAYER_SWING", 1.8, 1)
    check("swinging both hands shows both", mh:IsShown() and oh:IsShown())
    check("with the off hand above the main hand",
        oh.points[1] == "BOTTOMLEFT" and oh.points[2] == mh and oh.points[3] == "TOPLEFT")
    check("the castbar's own daylight between them",
        oh.points[5] == DogsForeverUI.Castbar.STACK_GAP, tostring(oh.points[5]))
    check("and the main hand at the bottom of the stack, nearest the castbar",
        mh.points[2] == SB.group)

    attackSpeed = { 2.6, 1.8, 3.0 }
    Fire("UNIT_ATTACK_SPEED", "player")
    Fire("PLAYER_SWING", 3.0, 2)
    check("a ranged swing comes in at the top",
        ranged:IsShown() == true and ranged.points[2] == oh and mh.points[2] == SB.group)
    check("and the stack is tall enough for all three",
        SB.group.height == 3 * DB.barHeight + 2 * DogsForeverUI.Castbar.STACK_GAP, SB.group.height)

    attackSpeed = { 2.6, nil, 3.0 }
    Fire("WEAPON_SLOT_CHANGED")
    check("taking the off hand away fades it out in its own row",
        oh:IsShown() == true and ranged.points[2] == oh)
    Tick(Style.FADE_OUT + 0.05)
    check("and once it is gone, closes its row up",
        oh:IsShown() == false and ranged.points[2] == mh)

    -- Let everything run out, and nothing is left on screen.
    attackSpeed = { 2.6, nil, nil }
    Fire("WEAPON_SLOT_CHANGED")
    Tick(4)
    Tick(1.1)
    Tick(Style.FADE_OUT + 0.05)
    check("once all swinging stops, the stack is empty",
        not mh:IsShown() and not oh:IsShown() and not ranged:IsShown())

    -- Range, from the client's own range check.
    check("range events are asked for on a hand that can swing", rangeChecks[0] == true)
    Fire("PLAYER_SWING_RANGE_UPDATE", 0, false, true)
    check("a target out of reach dims the bar, by the game's own amount",
        mh.alpha == 0.4, tostring(mh.alpha))
    check("and turns its text red",
        mh.timeText.textColor[1] == 1 and mh.timeText.textColor[2] < 0.2)
    Fire("PLAYER_SWING_RANGE_UPDATE", 0, true, true)
    check("back in reach, it is whole again", mh.alpha == 1)
    Fire("PLAYER_SWING_RANGE_UPDATE", 0, false, false)
    check("a check that could not be made is not read as out of range", mh.alpha == 1)

    inRange[0] = false
    Fire("PLAYER_TARGET_CHANGED")
    check("a new target out of reach is asked about straight away", mh.alpha == 0.4)
    -- The documentation is explicit: nil is "no check could be made", and must
    -- not be treated as out of range.
    inRange[0] = nil
    Fire("PLAYER_TARGET_CHANGED")
    check("and nil - no target at all - is not out of range", mh.alpha == 1)
end

print("== where the swing bars go ==")
do
    -- Bottom to top: the castbar, the countdown and combo points' row, then
    -- the swing bars, with the group's daylight between each.
    local GAP = 6 + 2 * 3
    check("before the world is entered (the castbar's place not final): shown over the castbar",
        SB.group.points[1] == "BOTTOM" and SB.group.points[2] == bar
        and SB.group.points[3] == "TOP")
    check("at their own size, the castbar's to start", SB.group.width == DB.swingWidth
        and DB.swingWidth == DB.barWidth and DB.swingHeight == DB.barHeight)
    Fire("PLAYER_ENTERING_WORLD")
    -- How far above the castbar's top their bottom is.
    local function Above() return DB.swingBottom - (GetScreenHeight() + DB.barTop) end
    check("then placed ONCE at the top of the castbar group, centred over it, written for the boxes",
        DB.swingPlaced == true and SB.group.points[1] == "BOTTOMLEFT" and SB.group.points[2] == UIParent
        and DB.swingLeft == DB.barLeft + (DB.barWidth - DB.swingWidth) / 2
        and SB.group.points[4] == DB.swingLeft and SB.group.points[5] == DB.swingBottom)
    check("over the countdown's row, for a class with mana",
        DogsForeverUI.Castbar.STACK_GAP == GAP and Above() == GAP + DB.barHeight + GAP, tostring(Above()))
    local left, bottom = DB.swingLeft, DB.swingBottom
    DB.barLeft, DB.barTop = DB.barLeft + 50, DB.barTop - 30
    DogsForeverUI.Castbar.Refresh()
    check("the castbar moved: they stay where they are - nothing moves with anything unless anchored",
        DB.swingLeft == left and DB.swingBottom == bottom and SB.group.points[4] == left)
    DB.barLeft, DB.barTop = DB.barLeft - 50, DB.barTop + 30

    -- Their default, worked out again after a reset (which clears the place).
    local function Reset()
        DB.swingPlaced = nil
        DogsForeverUI.Castbar.Refresh()
    end
    -- A warrior has neither mana nor combo points: no row is kept for them.
    units.player.class = "WARRIOR"
    Reset()
    check("a warrior's sit straight on the castbar, with no empty row between",
        Above() == GAP, tostring(Above()))
    -- A rogue has no mana, but has combo points: the row is theirs.
    units.player.class = "ROGUE"
    Reset()
    check("a rogue's leave the row for the combo points",
        Above() == GAP + DB.barHeight + GAP, tostring(Above()))
    units.player.class = "PRIEST"
    Reset()
    check("a priest's leave the row for the countdown, which is always on",
        Above() == GAP + DB.barHeight + GAP, tostring(Above()))

    DogsForeverUI.Castbar.Unlock()
    check("unlocking shows all three, whatever is equipped",
        mh:IsShown() and oh:IsShown() and ranged:IsShown())
    check("each as it really looks mid-swing: named, full, on its own background",
        oh.typeText.text == "Off Hand" and oh.timeText.text == ""
        and not PlacingLook(oh.bg) and oh:GetValue() == 1,
        oh.timeText.text)
    check("and clickable, to be dragged", mh.mouseEnabled == true)

    SB.group.left, SB.group.bottom = 700, 400
    mh.scripts.OnMouseDown(mh, "LeftButton")
    check("picking up any bar moves the whole stack", SB.group.moving == true)
    mh.scripts.OnMouseUp(mh, "LeftButton")
    check("dropping it saves where it was put",
        DB.swingPlaced == true and DB.swingLeft == 700 and DB.swingBottom == 400)
    check("and from then on it stays there rather than following the castbar",
        SB.group.points[2] == UIParent and SB.group.points[4] == 700
        and SB.group.points[5] == 400)

    pendingTimer = nil
    mh.scripts.OnMouseUp(mh, "RightButton")
    check("right-clicking a swing bar does nothing: still unlocked",
        DB.unlocked == true and pendingTimer == nil)
    DogsForeverUI.Castbar.Lock()
    check("locked, they have not moved", DB.swingLeft == 700 and DB.swingBottom == 400)
    check("locking puts them away again until something swings",
        not mh:IsShown() and not oh:IsShown() and not ranged:IsShown())
    check("and they stop taking the mouse", mh.mouseEnabled == false)

    -- The saved position has to survive the pass that drops settings an older
    -- version wrote.
    Fire("PLAYER_ENTERING_WORLD")
    check("a dragged position survives the load-time clean-up",
        DB.swingPlaced == true and DB.swingLeft == 700 and DB.swingBottom == 400)
end

print("== the game's swing timer ==")
do
    local main, off, rng = SwingTimerMainHandFrame, SwingTimerOffHandFrame, SwingTimerRangedFrame

    check("the game's swing bars are faded out, all three",
        main.alpha == 0 and off.alpha == 0 and rng.alpha == 0, tostring(main.alpha))
    check("not hidden: hiding one re-lays the protected bottom-managed stack",
        main.shown == true)

    main:UpdateSystemSettingOpacity()
    check("Edit Mode putting its opacity back does not bring one back",
        main.alpha == 0, tostring(main.alpha))
    off:SetAlpha(1)
    check("nor does the managed container fading it in", off.alpha == 0)

    -- (By calls alone: a field written onto the game's frame taints its Edit Mode.)
    check("Edit Mode can neither drag them nor show their box: no field of theirs written",
        main.isLocked == nil and main.defaultHideSelection == nil
        and (not main.Selection or (main.Selection.alpha == 0 and main.Selection.mouseEnabled == false)))

    -- Always on: a refresh keeps the game's faded and this addon's up.
    DogsForeverUI.Castbar.Refresh()
    check("a refresh keeps the game's faded and this addon's there",
        main.alpha == 0 and SB.group.shown == true)
    Fire("PLAYER_SWING", 2.6, 0)
    check("ready for the next swing", mh:IsShown() == true)
    Tick(2.6)
    Tick(1.1)
end

print("== always on ==")
DogsForeverUI.Castbar:Refresh()
StartCast("Fireball", 2)
Tick(0.5)
check("the spell name always shows", bar.spellText.text == "Fireball", bar.spellText.text)
check("and the time left", bar.timeText.text ~= "", bar.timeText.text)
StopCast()
Tick(0)

print("== what the bar says: the cast's display text, never a placeholder ==")
-- Picking up a quest item or opening something: the spell behind it is named
-- "No Text"; its display text says what is happening, and is what the game's
-- own castbar shows.
StartCast("No Text", 1.5, { text = "Opening" })
Tick(0.2)
check("the display text, as the game's castbar shows it", bar.spellText.text == "Opening",
    bar.spellText.text)
StopCast()
Tick(0)
StartCast("No Text", 1.5, { noText = true })
Tick(0.2)
check("no display text at all: no name on the bar, never the placeholder",
    bar.spellText.text == "", bar.spellText.text)
StopCast()
Tick(0)

print("== placing the bar ==")
-- What every bar here shows while it is unlocked: an empty bar on the
-- options window's background, saying what it is on the left, and nothing
-- else - "unlocked" is gone.
DogsForeverUI.Castbar:Unlock()
check("unlocking shows the bar", bar:IsShown() == true)
check("named on the left, where the spell goes",
    bar.spellText.text == "Castbar" and bar.spellText.justifyH == "LEFT", bar.spellText.text)
check("and no word on the right", bar.timeText.text == "", bar.timeText.text)
check("on its own background, as it really looks",
    not PlacingLook(bar.bg) and DogsForeverUI.Style.StripesOf == nil
    and (function()
        for _, region in ipairs(bar.regions) do
            if region.atlas == "RaidFrame-Shield-Overlay" then return false end
        end
        return true
    end)())
check("and full, in its colour, as a cast shows",
    bar:GetValue() == 1, bar:GetValue())
bar.left, bar.top = 400, 900
DB.barWidth, DB.barHeight = 100, 12
bar.width, bar.height = 100.0000305175781, 12.00004577636719
bar.scripts.OnMouseUp(bar, "LeftButton")
check("dragging it saves where it was put", DB.barLeft == 400, DB.barLeft)
check("and stops the addon re-centring it at login", DB.autoPlaced == false)
-- Dragging moves the bar; it cannot resize it. Reading the size back used to
-- round it a little every time, so a width of exactly 100 drifted and a size
-- typed into the options panel was overwritten by a drag.
check("dragging does not touch the width", DB.barWidth == 100, DB.barWidth)
check("or the height", DB.barHeight == 12, DB.barHeight)
DogsForeverUI.Castbar:Lock()
check("locking takes the bar off screen again", bar:IsShown() == false)
StartCast("Frostbolt", 2)
Tick(0.1)
check("and the next cast wears its own name and time again, off the placing look",
    bar.spellText.text == "Frostbolt" and bar.timeText.text ~= ""
    and not PlacingLook(bar.bg), bar.timeText.text)
Tick(3)

print("== the group's default position ==")
-- The castbar, the swing bars above it and the countdown under it are one
-- group, placed by the castbar: its top edge 830/1200 (about 69%) of the way
-- down the screen.
-- Everything is derived from the screen, so it holds at any resolution.
do
    -- Driven through the real load path rather than by calling the placement
    -- function directly, which is private: an auto-placed bar is re-centred on
    -- PLAYER_ENTERING_WORLD, once the screen size is final.
    local function CastbarDefault(w, h)
        GetScreenWidth = function() return w end
        GetScreenHeight = function() return h end
        DB.autoPlaced = true
        Fire("PLAYER_ENTERING_WORLD")
        return DB.barLeft, DB.barTop
    end

    -- The player's 2560x1440 at a UI scale of 1.2: a UI 2133.33 x 1200. They
    -- asked for about 20 below -756 there (65%, -780), then 10 higher: -770;
    -- then 60 lower with the unit frames' row (2026-10-01): -830.
    local left, top = CastbarDefault(2133.3333, 1200)
    check("horizontally centred", math.abs(left - 1016.6667) < 0.01, left)
    check("830 of the way down on the player's screen", math.abs(top - -830) < 0.01, top)

    for _, size in ipairs({ { 1920, 1080 }, { 3440, 1440 }, { 1280, 720 } }) do
        local w, h = size[1], size[2]
        local l, t = CastbarDefault(w, h)
        check("and the same share at " .. w .. "x" .. h,
            math.abs(t / h - -830 / 1200) < 1e-9 and math.abs(l - (w - DB.barWidth) / 2) < 0.01, t)
    end

    -- The countdown and the combo points share the row just above the
    -- castbar by default, centred on it with the group's daylight between:
    -- worked out once (here after a reset), then where they are.
    local FSR, Combo = DogsForeverUI.FiveSecondRule, DogsForeverUI.ComboPoints
    FSR.db.placed, Combo.db.placed = nil, nil
    DogsForeverUI.Castbar.Refresh()
    for _, pair in ipairs({ { DogsForeverUIFiveSecondBar, FSR.db }, { DogsForeverUIComboBar, Combo.db } }) do
        local row, rdb = pair[1], pair[2]
        check(row:GetName() .. " placed once, centred just above the castbar",
            rdb.placed == true and row.points[1] == "TOPLEFT" and row.points[2] == UIParent
            and math.abs(row.points[4] - (DB.barLeft + (DB.barWidth - rdb.barWidth) / 2)) < 1e-6
            and math.abs(row.points[5] - (DB.barTop + 6 + 3 + 3 + rdb.barHeight)) < 1e-6,
            tostring(row.points[5]))
    end
    local countdown = DogsForeverUIFiveSecondBar
    local fsrDB = DogsForeverUI.FiveSecondRule.db
    check("at its own size", countdown.width == fsrDB.barWidth and countdown.height == fsrDB.barHeight)
    local before = countdown.width
    DB.barWidth = DB.barWidth + 40
    DogsForeverUI.Castbar.Refresh()
    check("which the castbar's width no longer changes", countdown.width == before)
    DB.barWidth = DB.barWidth - 40
    DogsForeverUI.Castbar.Refresh()

    -- Put the stub screen back for everything after this.
    GetScreenWidth = function() return 1920 end
    GetScreenHeight = function() return 1080 end
    DB.barLeft, DB.barTop = 400, -300
end


print("== the spell name is one line, never two ==")
do
    -- A long name in a narrow bar has to be cut short rather than wrap and spill
    -- out of the bar. Word wrap off is what makes the client truncate it.
    for _, label in ipairs({ { "spell name", bar.spellText }, { "timer", bar.timeText } }) do
        check(("the %s never wraps"):format(label[1]),
            label[2].wordWrap == false, tostring(label[2].wordWrap))
        check(("  and is held to one line"):format(label[1]),
            label[2].maxLines == 1, tostring(label[2].maxLines))
    end

    -- Truncation needs a width to truncate against, which is the second anchor
    -- holding the name off the timer.
    StartCast("Supercalifragilistic Expialidocious Bolt of Considerable Length", 3)
    Tick(0.1)
    check("the name is given a right edge to be cut off at",
        bar.spellText.points[2] == bar.timeText, tostring(bar.spellText.points[2]))
    check("and is not shortened by the addon itself",
        bar.spellText.text:find("Supercalifragilistic") == 1, bar.spellText.text)
    StopCast()
    Tick(0)
end

print("== text padding ==")
-- The text is sized to the bar's height less a share of it kept clear above and
-- below, so it does not fill a short bar edge to edge. The rule is
-- Style.SetFont, which every bar in the addon uses.
do
    local function FontSize()
        DogsForeverUI.Castbar:Refresh()
        return select(2, bar.spellText:GetFont())
    end

    DB.barHeight = 12

    -- With no padding the text would be the bar's full 12, but no text on any
    -- bar grows past Style.MAX_FONT_SIZE.
    DB.textPadding = 0
    check("with no padding the text fills the bar, up to the size cap",
        FontSize() == math.min(12, Style.MAX_FONT_SIZE), FontSize())

    DB.textPadding = 0.15
    -- 15% off each end of 12 leaves 8.4, floored to 8 and kept even.
    check("15% padding brings it down to fit inside the bar",
        FontSize() == 8, FontSize())
    check("which is smaller than the bar", FontSize() < DB.barHeight)

    DB.textPadding = 0.4
    check("more padding, smaller text", FontSize() == 2, FontSize())

    -- Raising the padding must thin the text, never make it disappear: the
    -- too-small-to-read rule is measured against the bar, not the font.
    check("and the text is still drawn",
        bar.spellText.font ~= nil and FontSize() > 0, FontSize())

    -- Out of range values are somebody's hand-edited saved variables.
    DB.textPadding = 5
    check("an absurd padding is clamped rather than obeyed", FontSize() == 2, FontSize())
    DB.textPadding = -1
    check("and so is a negative one",
        FontSize() == math.min(12, Style.MAX_FONT_SIZE), FontSize())
    DB.textPadding = nil
    check("a missing padding falls back to the default", FontSize() == 8, FontSize())

    -- A bar too short for text at any size hides it instead.
    DB.barHeight = 6
    DB.textPadding = 0.15
    DogsForeverUI.Castbar:Refresh()
    check("a bar too short for text hides it", bar.spellText.textColor == nil
        or bar.spellText.textColor[4] == 0, "shown")

    DB.barHeight, DB.textPadding = 12, 0.15
    DogsForeverUI.Castbar:Refresh()
end

print("== no switch ==")
PlayerCastingBarFrame:Show()
check("the game's castbar is always held down", PlayerCastingBarFrame:IsShown() == false)
check("with no command anywhere", SlashCmdList.DCB == nil)

print("== retail ==")
-- Retail has no swing timer at all: no API, no frames, no strings, no switch
-- (Blizzard_SwingTimer is WoW Forever's). The castbar carries on without it.
do
    WOW_PROJECT_ID = WOW_PROJECT_MAINLINE
    C_SwingTimer, Enum.PlayerSwingType = nil, nil
    SwingTimerMainHandFrame, SwingTimerOffHandFrame, SwingTimerRangedFrame = nil, nil, nil
    SWING_TIMER_MAIN_HAND, SWING_TIMER_OFF_HAND, SWING_TIMER_RANGED = nil, nil, nil
    castingInfo, channelInfo = nil, nil
    local ok, err = pcall(function()
        Reload(nil)
        Login()
    end)
    check("the addon loads and logs in with no error", ok, tostring(err))
    Style = DogsForeverUI.Style
    local Castbar = DogsForeverUI.Castbar
    local rbar = Castbar.CastBar.castbar
    check("no swing bars are made, so none is placed",
        Castbar.SwingBars.group == nil and DogsForeverUI.Snap.EntryById("swing") == nil)
    check("their saved sizes are kept all the same",
        Castbar.db.swingWidth == 130 and Castbar.db.swingHeight == 20)

    ok, err = pcall(DogsForeverUI.SetUnlocked, true)
    check("Unlock Mode opens with no error", ok, tostring(err))
    check("with the castbar there to place", rbar:IsShown() == true)
    DogsForeverUI.SetUnlocked(false)

    -- An empowered cast (Evoker) comes as a channel with stages: it fills like
    -- a cast, to the end of its hold at the last stage, and ends on its own stop.
    local plainChannelInfo = UnitChannelInfo
    function UnitChannelInfo(token)
        local c = channelInfo
        if token ~= "player" or not c then return plainChannelInfo(token) end
        return c[1], c[2], c[3], c[4], c[5], c[6], c[7], 357208, c.stages ~= nil, c.stages
    end
    function GetUnitEmpowerHoldAtMaxTime() return 1000 end
    channelInfo = { "Fire Breath", "Fire Breath", "icon", now * 1000, (now + 2) * 1000, false, false, stages = 3 }
    ok, err = pcall(Fire, "UNIT_SPELLCAST_EMPOWER_START", "player", "guid-1", 357208)
    check("an empowered cast starts with no error", ok, tostring(err))
    Tick(Style.FADE_IN)
    check("and shows, held to the end of the last stage's hold",
        rbar:IsShown() == true and math.abs(select(2, rbar:GetMinMaxValues()) - 3) < 1e-6,
        select(2, rbar:GetMinMaxValues()))
    Tick(1)
    check("filling like a cast, not draining like a channel",
        math.abs(rbar:GetValue() - (1 + Style.FADE_IN)) < 1e-6 and Wears(rbar, "casting"), rbar:GetValue())
    Fire("UNIT_SPELLCAST_EMPOWER_UPDATE", "player", "guid-1", 357208)
    check("a stage reached changes nothing", rbar:IsShown() == true and Wears(rbar, "casting"))
    channelInfo = nil
    Fire("UNIT_SPELLCAST_EMPOWER_STOP", "player", "guid-1", 357208, true, nil)
    Tick(Style.FADE_OUT + 0.05)
    check("released, it goes as a finished cast", rbar:IsShown() == false)

    channelInfo = { "Fire Breath", "Fire Breath", "icon", now * 1000, (now + 2) * 1000, false, false, stages = 3 }
    Fire("UNIT_SPELLCAST_EMPOWER_START", "player", "guid-2", 357208)
    Tick(0.5)
    channelInfo = nil
    Fire("UNIT_SPELLCAST_EMPOWER_STOP", "player", "guid-2", 357208, false, nil)
    check("cut short, it says so in the failed colour", rbar:IsShown() == true and Wears(rbar, "failed"))
    Tick(Castbar.FAILED_HOLD + 0.01)
    Tick(Style.FADE_OUT + 0.05)
    check("and then goes", rbar:IsShown() == false)

    -- Secret times and a secret `complete`: handed on, never compared.
    local secretEnd, secretComplete = {}, {}
    secretValues[secretEnd], secretValues[secretComplete] = true, true
    channelInfo = { "Fire Breath", "Fire Breath", "icon", now * 1000, secretEnd, false, false, stages = 3 }
    ok, err = pcall(Fire, "UNIT_SPELLCAST_EMPOWER_START", "player", "guid-3", 357208)
    check("a secret end time does not throw", ok, tostring(err))
    channelInfo = nil
    ok, err = pcall(Fire, "UNIT_SPELLCAST_EMPOWER_STOP", "player", "guid-3", 357208, secretComplete, nil)
    check("nor does a secret stop", ok, tostring(err))
    Tick(Style.FADE_OUT + 0.05)
    check("which ends it", rbar:IsShown() == false)
    UnitChannelInfo = plainChannelInfo
end

Summary()
