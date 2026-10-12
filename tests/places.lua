-- The addon's own default layout (Core\DefaultPlaces.lua): the action bars,
-- the unit frames, the XP bar, the cooldowns and the castbar where the player
-- asked for them (2026-10-03), once per character.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

-- The game's minimap, as tests\minimap.lua builds it: one of the pieces laid out.
MinimapCluster = newWidget("Frame", UIParent)
Minimap = newWidget("Minimap", MinimapCluster)
Minimap:SetSize(198, 198)
function Minimap:SetMaskTexture() end
-- The main chat window, another piece laid out.
ChatFrame1 = newWidget("ScrollingMessageFrame", UIParent)
ChatFrame1:SetSize(430, 120)
-- The game's Edit Mode frame its tooltip is put in the corner of.
GameTooltipDefaultContainer = newWidget("Frame", UIParent)
GameTooltipDefaultContainer:SetSize(250, 150)

LoadAddon()
Login()

local Core = DogsForeverUI
local Snap = Core.Snap
local Places = Core.DefaultPlaces
local Bars = Core.ActionBars
local db = Snap.db
local BORDER = Core.Style.BORDER_INSET

local function Near(a, b) return a and b and math.abs(a - b) < 0.001 end

-- A frame's place in the harness: it keeps what GetLeft and the rest answer.
local function Put(frame, left, bottom, width, height)
    frame.left, frame.bottom, frame.width, frame.height = left, bottom, width, height
    frame.top = bottom + height
    frame.right = nil
end

-- The harness keeps no layout: a piece put by its bottom left on UIParent
-- (as Unlock Mode puts every piece) is read back there. Its own save would
-- lay it out again from its saved place, which the harness cannot follow;
-- its name row, reach and companions are left out - the frame alone.
for _, entry in ipairs(Snap.entries) do
    local frame = entry.frame
    local SetPoint = frame.SetPoint
    frame.SetPoint = function(self, point, rel, relPoint, x, y)
        SetPoint(self, point, rel, relPoint, x, y)
        if point == "BOTTOMLEFT" and rel == UIParent and relPoint == "BOTTOMLEFT" then
            self.left, self.bottom = x, y
            self.top = y + (self.height or 0)
        end
    end
    entry.opts.save = function() end
    entry.opts.parts, entry.opts.extra, entry.opts.moveWith = nil, nil, nil
    Put(frame, -10000, -10000, 1, 1)
end

local function F(id) return assert(Snap.EntryById(id), "no piece " .. id).frame end
local function At(id, left, bottom)
    local frame = F(id)
    return Near(frame.left, left) and Near(frame.bottom, bottom)
end
local function HangsFrom(id, to)
    local link = Snap.LinkOf(Snap.EntryById(id))
    return link ~= nil and link.to == to
end

-- Everything where it might be on a first login, nothing anchored.
local function Scatter()
    Put(F("player"), 600, 300, 200, 50)
    Put(F("target"), 1100, 300, 200, 50)
    Put(F("focus"), 100, 500, 120, 40)
    Put(F("targettarget"), 1600, 500, 120, 40)
    for _, id in ipairs({ "bar1", "bar2", "bar3" }) do Put(F(id), 500, 100, 440, 36) end
    Put(F("bar4"), 100, 700, 200, 36)
    Put(F("bar5"), 1300, 700, 200, 36)
    for _, id in ipairs({ "bar6", "bar7", "bar8" }) do Put(F(id), 900, 600, 36, 440) end
    Put(F("xp"), 10, 900, 600, 10)
    Put(F("cooldowns"), 50, 50, 300, 40)
    Put(F("threat"), 1500, 50, 150, 20)
    Put(F("castbar"), 70, 80, 250, 20)
    Put(F("pet"), 600, 240, 100, 30)
    Put(F("stance"), 50, 50, 100, 24)
    Put(F("petbar"), 50, 80, 200, 24)
    Put(F("minimap"), 100, 100, 200, 200)
    Put(F("micro"), 100, 500, 300, 30)
    Put(F("bags"), 300, 300, 150, 30)
    Put(F("chat"), 400, 400, 450, 180)
    Put(F("tooltip"), 500, 500, 250, 150)
    Put(F("toasts"), 800, 800, 260, 28)
    Put(F("party"), 3, 700, 120, 33)
    db.snaps = {}
    db.defaultPlaces = nil
end

local laidOut = 0
local LayOutAll = Bars.LayOutAll
Bars.LayOutAll = function() laidOut = laidOut + 1 end

Section("the pet bar and the pet's unit frame: two pieces, not one")
do
    local bar, plate = Snap.EntryById("petbar"), Snap.EntryById("pet")
    check("the pet bar is \"petbar\" in Unlock Mode", bar and bar.frame == _G.DogsForeverUIActionBarPetBar)
    check("\"pet\" is the pet's unit frame", plate and plate.frame ~= bar.frame and plate.opts.name ~= "Pet Bar")
    check("Reset Position on the pet frame resets the pet frame",
        Snap.CanReset(plate) and Snap.CanReset(bar))
end

Section("laid out as the player asked")
do
    Scatter()
    for _, key in ipairs({ "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8" }) do
        Bars.db[key .. "Buttons"], Bars.db[key .. "Rows"], Bars.db[key .. "Spacing"] = 12, 1, 4
    end
    -- The unit frames' name rows over them, as in game: the player's and
    -- the target's 20 tall, the small frames' 10.
    for id, room in pairs({ player = 20, target = 20, focus = 10, targettarget = 10 }) do
        Snap.EntryById(id).opts.extra = function() return 0, 0, room, 0 end
    end
    -- What the old shared id left behind: the pet frame's anchor, made on
    -- the pet bar.
    db.snaps.pet = { to = "player", point = "TOP", rel = "BOTTOM", x = -500, y = 900, explicit = true }
    db.anchoredByDefault = db.anchoredByDefault or {}
    db.anchoredByDefault.pet = true
    check("due on a character that has never had it", Places.Due())
    check("laid out", Places.Apply() == true and db.defaultPlaces == Places.VERSION and not Places.Due())
    check("the pet frame anchored to the player frame again, from where it is",
        HangsFrom("pet", "player") and db.snaps.pet.x ~= -500)

    -- Action Bar 1: its box (440 + the border each side) centred on 1920,
    -- its top 3 above the player frame's (350): 353, its bottom 317.
    check("Action Bar 1 centred, its Y 3 above the player frame's", At("bar1", 740, 317))
    check("Action Bar 1 anchored to nothing", Snap.LinkOf(Snap.EntryById("bar1")) == nil)
    -- The player frame's box 28 clear of Action Bar 1's on the left (the
    -- player: 770, not 790), the target's on the right; neither moved up or
    -- down.
    local bar1Left, bar1Right = 740 - BORDER, 740 + 440 + BORDER
    check("the player frame 28 out to the left of it", Places.SIDE_GAP == 28
        and At("player", bar1Left - 28 - BORDER - 200, 300))
    check("the target frame 28 out to the right of it", At("target", bar1Right + 28 + BORDER, 300))
    -- Focus: its box 15 off the player frame's, the two boxes' middles level
    -- (name rows included): the player's box 297 to 373, middle 335; the
    -- focus's 56 tall (40, its name row 10, the border), so its frame's
    -- bottom at 335 - 28 + 3 - not 305, where the frames' own middles would
    -- put it.
    check("focus 15 left of the player frame, centred on it, anchored to it",
        At("focus", 506 - BORDER - 15 - BORDER - 120, 310) and HangsFrom("focus", "player"))
    check("target of target 15 right of the target frame, centred on it, anchored to it",
        At("targettarget", 1214 + 200 + BORDER + 15 + BORDER, 310) and HangsFrom("targettarget", "target"))

    check("Action Bar 2 snapped under Action Bar 1, centred, anchored to it",
        At("bar2", 740, 317 - BORDER - BORDER - 36) and HangsFrom("bar2", "bar1"))
    -- The XP bar's box 0 to 16 (10 tall, its border): Action Bar 3's 15 above.
    check("Action Bar 3 centred, 15 above the XP bar, anchored to nothing",
        At("bar3", 740, 16 + 15 + BORDER) and Snap.LinkOf(Snap.EntryById("bar3")) == nil)
    local twoRows = true
    for n = 1, 5 do
        local key = "bar" .. n
        twoRows = twoRows and Bars.db[key .. "Buttons"] == 12 and Bars.db[key .. "Rows"] == 2
            and Bars.db[key .. "Spacing"] == 2
    end
    check("Action Bars 1 to 5: twelve buttons in two rows, 2 apart", twoRows)
    check("Action Bar 4 snapped to Action Bar 3's left, level, anchored to it",
        At("bar4", 740 - BORDER - BORDER - 200, 34) and HangsFrom("bar4", "bar3"))
    check("Action Bar 5 snapped to Action Bar 3's right, level, anchored to it",
        At("bar5", 1180 + BORDER + BORDER, 34) and HangsFrom("bar5", "bar3"))
    -- Action Bar 1's box 737 to 1183, 314 to 356.
    check("the stance bar snapped on top of Action Bar 1, at its left edge, anchored to it",
        At("stance", 740, 356 + BORDER) and HangsFrom("stance", "bar1"))
    -- Action Bar 2's box bottom: 275 - 3.
    -- (Its own size: the repair laid it out again.)
    local pet = F("petbar")
    check("the pet bar snapped under Action Bar 2, centred on it, anchored to it",
        At("petbar", 960 - pet.width / 2, 272 - BORDER - pet.height) and HangsFrom("petbar", "bar2"))
    check("the minimap snapped into the screen's top right corner",
        At("minimap", 1920 - BORDER - 200, 1080 - BORDER - 200))
    check("the micro menu centred, snapped to the top of the screen",
        At("micro", 960 - 150, 1080 - BORDER - 30))
    local game, look, gap = Core.GameFrames, Core.Chat.Look, Places.EDGE_GAP
    check("no damage meter piece: the meter is the game's alone", Snap.EntryById("meter") == nil)
    check("the chat's panel 400 wide and its tabs' sidebar beside it, 200 high",
        game.db.chatWidth == 400 + look.GAP + look.SIDE_WIDTH and game.db.chatHeight == 200,
        tostring(game.db.chatWidth) .. "x" .. tostring(game.db.chatHeight))
    check("the chat window inside it: that less the sidebar and the panel's room round it",
        Near(ChatFrame1:GetWidth(), 400 - 2 * look.PAD - look.SCROLL_ROOM)
        and Near(ChatFrame1:GetHeight(), 200 - 2 * look.PAD - look.TOP_ROOM),
        tostring(ChatFrame1:GetWidth()) .. "x" .. tostring(ChatFrame1:GetHeight()))
    check("15 in from the bottom left corner", At("chat", gap + BORDER, gap + BORDER))
    check("the loot toasts over the focus frame, left edges level, bottom level with the cooldowns', anchored to nothing",
        At("toasts", F("focus").left, F("cooldowns").bottom) and Snap.LinkOf(Snap.EntryById("toasts")) == nil,
        tostring(F("toasts").left) .. "," .. tostring(F("toasts").bottom))
    check("the tooltip 15 in from the bottom right corner, anchored to nothing",
        At("tooltip", 1920 - gap - BORDER - 250, gap + BORDER) and Snap.LinkOf(Snap.EntryById("tooltip")) == nil,
        tostring(F("tooltip").left) .. "," .. tostring(F("tooltip").bottom))
    check("the bag bar in the bottom right corner",
        At("bags", 1920 - BORDER - 150, BORDER))
    -- The party's whole column of four (Frames.PartyColumn), its box's top
    -- as far under the screen's top as its bottom is over the screen's bottom.
    local column = Core.Frames.PartyColumn(Core.Frames.db)
    check("the party's column exactly centred top to bottom, its left edge where it was",
        Near(F("party").top + BORDER, (1080 + column) / 2) and Near(F("party").left, 3),
        tostring(F("party").top) .. " for a column of " .. tostring(column))

    check("Action Bars 6, 7 and 8 one button wide: 12 rows",
        Bars.db.bar6Rows == 12 and Bars.db.bar7Rows == 12 and Bars.db.bar8Rows == 12 and laidOut == 1)
    check("Action Bar 6 on the screen's right edge, centred top to bottom",
        At("bar6", 1920 - BORDER - 36, 540 - 220))
    check("Action Bar 7 snapped to its left, anchored to it",
        At("bar7", 1881 - BORDER - BORDER - 36, 320) and HangsFrom("bar7", "bar6"))
    check("Action Bar 8 snapped to 7's left, anchored to it",
        At("bar8", 1839 - BORDER - BORDER - 36, 320) and HangsFrom("bar8", "bar7"))

    check("the XP bar centred, on the screen's bottom edge", At("xp", 660, BORDER))
    -- (The castbar's own default top: 830 of 1200 down the screen.)
    local castbarTop = 1080 * (1 - 830 / 1200)
    check("the castbar centred left to right, at its own default height",
        At("castbar", 960 - 125, castbarTop - 20), tostring(F("castbar").left) .. "," .. tostring(F("castbar").bottom))
    check("the cooldowns at the player frame's X, level with the castbar (tops level)",
        At("cooldowns", 506, castbarTop - 40), tostring(F("cooldowns").left) .. "," .. tostring(F("cooldowns").bottom))
    check("the threat bar the same at the target frame's X, anchored to it",
        At("threat", bar1Right + 28 + BORDER, castbarTop - 20) and HangsFrom("threat", "target"),
        tostring(F("threat").left) .. "," .. tostring(F("threat").bottom))
end

Section("entering Unlock Mode moves nothing")
do
    -- (The frames given their own sizes first - the test's made-up ones
    -- are not theirs - and everything hanging from them settled.)
    Core.SetUnlocked(true)
    Core.SetUnlocked(false)
    for _ = 1, 5 do Tick(0.02) end
    local before = {}
    for _, entry in ipairs(Snap.entries) do before[entry] = { entry.frame.left, entry.frame.bottom } end
    Core.SetUnlocked(true)
    for _ = 1, 5 do Tick(0.02) end
    local moved = {}
    for _, entry in ipairs(Snap.entries) do
        local was = before[entry]
        if not (Near(entry.frame.left, was[1]) and Near(entry.frame.bottom, was[2])) then
            moved[#moved + 1] = string.format("%s (%.1f, %.1f -> %.1f, %.1f)", tostring(entry.opts.id),
                was[1] or 0, was[2] or 0, entry.frame.left or 0, entry.frame.bottom or 0)
        end
    end
    check("every piece where it was", #moved == 0, table.concat(moved, ", "))
    Core.RevertEditMode()
    Core.SetUnlocked(false)
end

Section("a piece's parts showing or hiding moves nothing")
do
    local entry = Snap.EntryById("cooldowns")
    Snap.AnchorHere(entry, Snap.EntryById("player"))
    local frame = F("cooldowns")
    local left, bottom = frame.left, frame.bottom
    -- A bar of the cooldowns' showing, wider than them and below them (as
    -- in Unlock Mode, or a fight).
    local row = CreateFrame("Frame", nil, UIParent)
    Put(row, left - 100, bottom - 60, 500, 45)
    row:Show()
    entry.opts.parts = function() return { row } end
    for _ = 1, 5 do Tick(0.02) end
    check("the cooldowns stay where they are as a bar shows", At("cooldowns", left, bottom))
    row:Hide()
    for _ = 1, 5 do Tick(0.02) end
    check("and as it goes", At("cooldowns", left, bottom))
    entry.opts.parts = nil

    -- An anchor saved before: measured by the whole box, parts and all.
    local link = db.snaps.focus
    local focusLeft, focusBottom = F("focus").left, F("focus").bottom
    db.snaps.focus = { to = "player", point = link.point, rel = link.rel, x = link.x - 37, y = link.y + 11,
                       explicit = true }
    for _ = 1, 5 do Tick(0.02) end
    check("an anchor saved before: taken again from where it is - nothing moves",
        At("focus", focusLeft, focusBottom) and db.snaps.focus.box == 2 and Near(db.snaps.focus.x, link.x))
end

Section("once: what is moved afterwards stays")
do
    Put(F("bar3"), 100, 100, 440, 36)
    Places.Schedule()
    pendingTimer = nil
    Places.Schedule()
    check("not laid out again", pendingTimer == nil and At("bar3", 100, 100))
end

Section("Reset Position: that one piece back in its place in the layout")
do
    Snap.Unanchor(Snap.EntryById("bar4"))
    Put(F("bar3"), 740, 607, 440, 36)
    Put(F("bar4"), 30, 30, 200, 36)
    check("Action Bar 4 back on Action Bar 3's left, anchored to it",
        Places.Place("bar4") and At("bar4", 534, 607) and HangsFrom("bar4", "bar3"))
    check("a piece not in the layout: left to its own reset", Places.Place("loot") == false)
end

Section("first login: a moment after the world is up, never in combat")
do
    Scatter()
    inCombat = true
    pendingTimer = nil
    Places.scheduled = false    -- (the harness keeps one timer: login's was overwritten)
    Places.Schedule()
    local timer = pendingTimer
    pendingTimer = nil
    timer()
    check("in combat: waits, without asking again", Places.Due() and pendingTimer == nil and At("bar1", 500, 100))
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    check("asked again as the fight ends", pendingTimer ~= nil)
    pendingTimer()
    check("then laid out", not Places.Due() and At("bar1", 740, 317))
end

Section("a character with the layout already: only the change, nothing else laid out again")
do
    -- As the player has it: version 4, Action Bar 1 where they left it,
    -- Action Bar 2 hanging from it, something else moved by hand.
    Put(F("bar1"), 700, 400, 440, 36)
    Put(F("bar2"), 700, 400 - 2 * BORDER - 36, 440, 36)
    Snap.AnchorHere(Snap.EntryById("bar2"), Snap.EntryById("bar1"))
    Put(F("xp"), 123, 456, 600, 10)
    Put(F("player"), 480, 300, 200, 50)
    Put(F("target"), 1240, 300, 200, 50)
    db.defaultPlaces = 4
    check("due", Places.Due())
    check("brought up to date", Places.Update() == true and not Places.Due()
        and db.defaultPlaces == Places.VERSION)
    check("Action Bar 1 3 higher, from where it was", At("bar1", 700, 403))
    check("what hangs from it comes along", At("bar2", 700, 403 - 2 * BORDER - 36))
    check("the player frame 20 further left, the target 20 further right",
        At("player", 460, 300) and At("target", 1260, 300))
    check("nothing else moved", At("xp", 123, 456))

    -- One already on version 5: only the last change.
    db.defaultPlaces = 5
    Places.Update()
    check("from 5: only the frames moved out, bar 1 left where it is",
        At("bar1", 700, 403) and At("player", 440, 300) and At("target", 1280, 300))

    -- One on version 7: only the chat and the bag bar.
    Put(F("bags"), 300, 300, 150, 30)
    Put(F("chat"), 400, 400, 450, 180)
    db.defaultPlaces = 7
    Places.Update()
    local gap = Places.EDGE_GAP
    check("from 7: the chat 15 in from the bottom left corner, the bag bar in the right one",
        At("chat", gap + BORDER, gap + BORDER) and At("bags", 1920 - BORDER - 150, BORDER))
    check("and nothing else moved", At("bar1", 700, 403) and At("player", 440, 300))

    -- One on version 8: the bag bar, then the chat.
    Put(F("bags"), 1700, 300, 150, 30)
    Put(F("chat"), 400, 400, 450, 180)
    db.defaultPlaces = 8
    Places.Update()
    check("from 8: the bag bar back into the corner, the chat 15 in from its corner",
        At("bags", 1920 - BORDER - 150, BORDER) and At("chat", gap + BORDER, gap + BORDER))

    -- One on version 9 (or 10): only the chat.
    Put(F("bags"), 1700, 300, 150, 30)
    Put(F("chat"), 400, 400, 450, 180)
    db.defaultPlaces = 9
    Places.Update()
    check("from 9: only the chat, 15 in from its corner; the bag bar left",
        At("chat", gap + BORDER, gap + BORDER) and At("bags", 1700, 300))

    -- One on version 16: the tooltip still anchored to the damage meter's
    -- piece, gone since the meter went back to the game.
    Put(F("chat"), 400, 400, 450, 180)
    Put(F("tooltip"), 500, 500, 250, 150)
    db.snaps.tooltip = { to = "meter", point = "BOTTOMRIGHT", rel = "BOTTOMLEFT", x = 0, y = 0, explicit = true }
    db.defaultPlaces = 16
    Places.Update()
    for _ = 1, 5 do Tick(0.02) end
    check("from 16: the tooltip let go of the meter, 15 in from the bottom right corner",
        Snap.LinkOf(Snap.EntryById("tooltip")) == nil and At("tooltip", 1920 - gap - BORDER - 250, gap + BORDER),
        tostring(F("tooltip").left) .. "," .. tostring(F("tooltip").bottom))

    -- One on version 17: only the chat, wider by its tabs' sidebar.
    Put(F("chat"), 400, 400, 450, 180)
    Put(F("tooltip"), 500, 500, 250, 150)
    db.defaultPlaces = 17
    Places.Update()
    check("from 17: the chat back in its corner, its sidebar's width more; the tooltip left",
        At("chat", gap + BORDER, gap + BORDER) and At("tooltip", 500, 500)
        and Core.GameFrames.db.chatWidth == Places.CHAT_SIZE[1])

    -- One on version 19: only the loot toasts, new.
    Put(F("toasts"), 800, 800, 260, 28)
    db.defaultPlaces = 19
    Places.Update()
    check("from 19: the loot toasts placed; the tooltip left",
        At("toasts", F("focus").left, F("cooldowns").bottom) and At("tooltip", 500, 500))

    -- One on version 20: the loot toasts over the chat, anchored to it.
    Put(F("toasts"), 800, 800, 260, 28)
    db.snaps.toasts = { to = "chat", point = "BOTTOMLEFT", rel = "TOPLEFT", x = 0, y = 15, explicit = true }
    db.defaultPlaces = 20
    Places.Update()
    check("from 20: the loot toasts let go of the chat, over the focus frame, anchored to nothing",
        At("toasts", F("focus").left, F("cooldowns").bottom) and Snap.LinkOf(Snap.EntryById("toasts")) == nil
        and At("tooltip", 500, 500), tostring(F("toasts").left) .. "," .. tostring(F("toasts").bottom))

    -- One on version 21: the loot toasts anchored to the focus frame.
    Put(F("toasts"), 800, 800, 260, 28)
    db.snaps.toasts = { to = "focus", point = "BOTTOMLEFT", rel = "TOPLEFT", x = 0, y = 15, explicit = true }
    db.defaultPlaces = 21
    Places.Update()
    check("from 21: the loot toasts let go of the focus frame, where they are",
        Snap.LinkOf(Snap.EntryById("toasts")) == nil and At("toasts", 800, 800),
        tostring(F("toasts").left) .. "," .. tostring(F("toasts").bottom))
end

Bars.LayOutAll = LayOutAll

Section("Reset everything: the layout in the same moment, not a moment later")
do
    pendingTimer = nil
    Places.scheduled = false
    check("reset", Core:ResetAll() == true)
    check("laid out already - nothing waiting to lay it out", not Places.Due()
        and db.defaultPlaces == Places.VERSION)
    check("bars 1 to 5 in two rows straight away", Bars.db.bar1Rows == 2 and Bars.db.bar3Rows == 2)
end

Summary()
