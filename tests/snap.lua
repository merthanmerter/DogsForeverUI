-- Unlock Mode, EllesmereUI's, ported (Core\Snap.lua, DogsForeverUI.lua,
-- Options\Unlock.lua): the addon's own pieces only, a mover over each, the bar
-- along the top, each mover's cog menu, snapping to the nearest piece,
-- matching sizes, anchoring to a side, the Unsaved Changes question - and a
-- box over each of the game's own frames that hands over to the game's Edit
-- Mode.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

LoadAddon()
Login()

local Core = DogsForeverUI
local Snap = Core.Snap
local Options = Core.Options
local Unlock = Options.Unlock
local db = Snap.db
local manager = EditModeManagerFrame
local BORDER = Core.Style.BORDER_INSET

-- A frame's place in the harness: it keeps what GetLeft and the rest answer.
local function Put(frame, left, bottom, width, height)
    frame.left, frame.bottom, frame.width, frame.height = left, bottom, width, height
    frame.top = bottom + height
    frame.right = nil
end
-- Out of reach. (In game a frame with no place answers nil and is skipped;
-- the harness answers 0, which would put every frame in the corner.)
local function Clear(frame)
    Put(frame, -10000, -10000, 1, 1)
end
local function EntryOf(frame) return Snap.EntryOf(frame) end
local function Near(a, b) return a and b and math.abs(a - b) < 0.001 end
local function Click(button, ...) button.scripts.OnClick(button, ...) end
local function MoverOf(frame) return Snap.movers[EntryOf(frame)] end
local function Same(a, b)
    return a and b and Near(a[1], b[1]) and Near(a[2], b[2]) and Near(a[3], b[3])
        and (b[4] == nil or Near(a[4], b[4]))
end
local function Enter(box, text)
    box:SetText(text)
    box.scripts.OnEnterPressed(box)
end
-- A mover pressed and let go of where it is: a click.
local function Press(frame)
    local mover = MoverOf(frame)
    mover.scripts.OnMouseDown(mover, "LeftButton")
    mover.scripts.OnMouseUp(mover, "LeftButton")
end

-- The harness keeps no layout: a piece put by its bottom left on UIParent
-- (as Unlock Mode puts every piece) is read back there.
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
end

-- A piece's own save lays it out again from its saved place, which the
-- harness - keeping no layout - cannot follow: counted instead.
local saves = 0
for _, id in ipairs({ "castbar", "cooldowns", "xp" }) do
    Snap.EntryById(id).opts.save = function() saves = saves + 1 end
end

local cursorX, cursorY = 600, 310
function GetCursorPosition() return cursorX, cursorY end
local function MoveTo(x, y)
    cursorX, cursorY = x, y
    Tick(0.02)
end

local plates = Core.Frames.plates
local castbar = Core.Castbar.CastBar.castbar
local holder = Core.Cooldowns.holder

Section("its own settings: the bar's switches, what hangs from what, whose size matches whose")
check("placing is a module, with its section saved like the rest",
    Core:GetModule("placing") == Snap and Core.db.placing == db)
check("one switch, Snap Elements, on; no grid, overlay, coordinates or hover bar switches",
    db.snap == true and db.grid == nil and db.dark == nil and db.coords == nil and db.hoverBar == nil)
check("no grid spacing: EllesmereUI's grid is 32 pixels", db.spacing == nil)

Section("every piece that can be dragged has a mover")
do
    local pieces = {
        player = plates.player, target = plates.target, focus = plates.focus,
        party1 = plates.party1, castbar = castbar,
        swing = Core.Castbar.SwingBars and Core.Castbar.SwingBars.group,
        cooldowns = holder, micro = Core.Menus.MicroMenu.holder,
    }
    for name, frame in pairs(pieces) do
        check(name .. " is registered", frame ~= nil and EntryOf(frame) ~= nil)
    end
    check("the party's frames are one group, so never snap to one another",
        EntryOf(plates.party1).opts.group == "party" and EntryOf(plates.party2).opts.group == "party"
        and EntryOf(plates.player).opts.group == nil)
end

-- Out of the way: only what a check puts on screen counts. (A piece's parts
-- - the cooldown bars, the swing bars - have no place in the harness either.)
for _, entry in ipairs(Snap.entries) do
    Clear(entry.frame)
    entry.opts.parts = nil
end
Core.SetUnlocked(true)
-- The cooldown bars shown while unlocked have no place in the harness either.
for _, row in pairs(Core.Cooldowns.rows) do row.shown = false end

Section("snapping, EllesmereUI's: to the nearest piece, edges and middles within 6")
do
    check("Unlock Mode open", Core.IsUnlocked())
    local a, b = castbar, holder
    a.shown, b.shown = true, true
    Put(a, 500, 300, 200, 20)

    Put(b, 700 + 2 * BORDER + 3, 300, 100, 20)
    local pull = Snap.Find(EntryOf(b))
    check("beside it, 3 off: flush against it", Near(pull.dx, -3) and pull.target == EntryOf(a))
    check("a guide where the edges meet, and one along the tops",
        Near(pull.x, 700 + BORDER) and Near(pull.y, 320 + BORDER))

    Put(b, 505, 600, 100, 20)
    pull = Snap.Find(EntryOf(b))
    check("far apart but the nearest: its left lined up with the castbar's", Near(pull.dx, -5) and pull.dy == 0)
    Put(b, 512, 600, 100, 20)
    check("nothing within 6: nothing", Snap.Find(EntryOf(b)).dx == 0)

    Put(b, 500, 320 + 2 * BORDER, 200, 20)
    Snap.AnchorHere(EntryOf(b), EntryOf(a))
    check("never to a piece anchored to it", Snap.Find(EntryOf(a)).target ~= EntryOf(b))
    Snap.Unanchor(EntryOf(b))
    Clear(b)

    Put(a, 3, 300, 200, 20)
    check("not to the screen's edge", Snap.Find(EntryOf(a)).dx == 0)

    -- The screen's middle lines, both ways: a piece's middle onto them.
    -- (Its box: its frame and the border; the screen 1920 x 1080.)
    Put(a, 960 - 100 + 4, 300, 200, 20)
    pull = Snap.Find(EntryOf(a))
    -- (A piece centred on the screen may meet it on the same line: either way.)
    check("4 off the screen's middle across: onto it, a guide down it",
        Near(pull.dx, -4) and Near(pull.x, 960))
    Put(a, 100, 540 - 10 - 5, 200, 20)
    pull = Snap.Find(EntryOf(a))
    check("and 5 off its middle up and down: onto it too, a guide along it",
        Near(pull.dy, 5) and Near(pull.y, 540) and pull.screenY == true)
    Put(a, 960 - 100 + 9, 540 - 10 + 9, 200, 20)
    check("further than 6: no pull", Snap.Find(EntryOf(a)).dx == 0 and Snap.Find(EntryOf(a)).dy == 0)
    Unlock.Set("snap", false)
    Put(a, 960 - 100 + 4, 300, 200, 20)
    check("Snap Elements off: not that either", Snap.Find(EntryOf(a)).dx == 0)
    Unlock.Set("snap", true)

    Put(a, 500, 300, 200, 20)
    Put(b, 700 + 2 * BORDER + 3, 300, 100, 20)
    Unlock.Set("snap", false)
    check("Snap Elements off: nothing pulls", Snap.Find(EntryOf(b)).dx == 0 and Snap.Rules() == false)
    Unlock.Set("snap", true)
    Clear(b)

    -- The screen's middle lines: each only while the piece in hand (dragged,
    -- or else selected) is on it - the player, 2026-10-03.
    a.shown = true
    Snap.Deselect()
    Put(a, 960 - 100, 540 - 10, 200, 20)
    Snap.LayOutMovers()
    local g = Snap.guides
    check("nothing in hand: no middle line, though a piece sits on both",
        not g or (not g.cx:IsShown() and not g.cy:IsShown()))
    Snap.Select(EntryOf(a))
    Snap.LayOutMovers()
    g = Snap.guides
    -- On whole screen pixels from the top left, as the grid's lines are (one
    -- pixel thick and centred halfway between two pixels, the game drew them
    -- zero pixels wide): 2 pixels thick, centred on the middle.
    local px = Snap.Pixel()
    local function Whole(v) return math.abs(v / px - math.floor(v / px + 0.5)) < 1e-6 end
    local vx, hy = g.cx.points[4], -g.cy.points[5]
    check("selected, on both middles: both lines, over everything, in gold",
        g:IsShown() and g.cx:IsShown() and g.cy:IsShown() and g.strata == "TOOLTIP"
        and Same(g.cx.colorTexture, Core.Style.GOLD) and Same(g.cy.colorTexture, Core.Style.GOLD))
    check("each 2 pixels thick, centred on the screen's middle, on whole pixels",
        g.cx.points[1] == "TOPLEFT" and g.cy.points[1] == "TOPLEFT"
        and Near(g.cx.width, 2 * px) and Near(g.cy.height, 2 * px)
        and Near(vx + g.cx.width / 2, 960) and Near(hy + g.cy.height / 2, 540)
        and Whole(vx) and Whole(hy), vx .. " " .. hy)
    Put(a, 960 - 100, 300, 200, 20)
    Snap.LayOutMovers()
    check("on the middle across only: the line down the screen only", g.cx:IsShown() and not g.cy:IsShown())
    Put(a, 100, 540 - 10, 200, 20)
    Snap.LayOutMovers()
    check("on the middle up and down only: the line along it only", g.cy:IsShown() and not g.cx:IsShown())
    Put(a, 960 - 100 + 0.8, 300, 200, 20)
    Snap.LayOutMovers()
    check("a screen pixel off (the game's rounding): still on it", g.cx:IsShown())
    Put(a, 960 - 100 + 3, 540 - 10 + 3, 200, 20)
    Snap.LayOutMovers()
    check("off both: neither", not g.cx:IsShown() and not g.cy:IsShown())
    Snap.Deselect()
    Clear(a)
end

Section("a piece's name row counts as part of it")
do
    local plate = plates.player
    Put(plate, 400, 400, 200, 30)
    local box = Snap.Box(EntryOf(plate))
    check("the box reaches over the bars by the name row, and the border round it",
        Near(box.t, 430 + Core.Frames.UnitPlate.TopRoom() + BORDER) and Near(box.l, 400 - BORDER))
    Clear(plate)
end

Section("party frames never snap to each other")
do
    Put(plates.party1, 100, 500, 120, 30)
    Put(plates.party2, 102, 500 - 30 - 2 * BORDER - 3, 120, 30)
    plates.party1.shown, plates.party2.shown = true, true
    local pull = Snap.Find(EntryOf(plates.party2))
    check("party2 is not pulled to party1", pull.target ~= EntryOf(plates.party1))
    Clear(plates.party1)
    Clear(plates.party2)
end

Section("the grid: EllesmereUI's, every 32 pixels out from the screen's middle")
do
    local grid = Core.grid
    check("on while Unlock Mode is open", grid ~= nil and grid:IsShown())
    grid.width, grid.height = 1920, 1080
    Core.UpdateGrid()
    local first = grid.lines[1]
    check("its first line 32 pixels right of the middle", Near(first.points[4], 960 + 32))
    check("always bright gold", Same(first.colorTexture, Core.Style.GOLD) and Near(first.colorTexture[4], 0.30))
    local centre, pip = 0, 0
    for _, line in ipairs(grid.lines) do
        if line.shown ~= false and line.sublevel == -6 then centre = centre + 1 end
        if line.shown ~= false and line.sublevel == -5 then pip = pip + 1 end
    end
    check("the two middle lines brighter, a small white cross on the middle", centre == 2 and pip == 2)
    check("under all the UI, never in the mouse's way",
        grid.strata == "BACKGROUND" and grid.mouseEnabled == false)
end

Section("dragging: freely, snapped as it goes, a gold line where it meets")
do
    -- (Laid out by their modules as Unlock Mode opened: out of the way again.)
    for _, entry in ipairs(Snap.entries) do Clear(entry.frame) end
    Put(castbar, 500, 300, 200, 20)
    castbar.points = {}
    cursorX, cursorY = 600, 310
    Snap.Start(castbar)
    check("not the game's StartMoving: the addon moves it", castbar.moving ~= true)
    MoveTo(602, 310)
    check("a couple of pixels is still a click: it does not move", castbar.points[1] == nil)
    MoveTo(700, 400)
    check("it follows the mouse", castbar.points[1] == "BOTTOMLEFT" and castbar.points[2] == UIParent
        and Near(castbar.points[4], 600) and Near(castbar.points[5], 390))
    check("a drag selects it", Snap.Selected() == castbar)

    holder.shown = true
    Put(holder, 900, 390, 100, 20)
    MoveTo(600 + 197 - 2 * BORDER, 400)
    check("3 from the next piece: flush against it",
        Near(castbar.points[4], 700 - 2 * BORDER) and Near(castbar.points[5], 390))
    local line = Snap.guides.x
    check("a line in the addon's gold, at half, where the two meet",
        line:IsShown() and Same(line.colorTexture, Core.Style.GOLD) and Near(line.colorTexture[4], 0.5))
    Tick(0.02)
    check("the piece it snaps to outlined white, steady", Same(MoverOf(holder).outline.colour, { 1, 1, 1, 0.9 }))
    check("let go: moved", Snap.Stop(castbar) == true)
    check("and the lines go", not Snap.guides.x:IsShown() and not Snap.guides.y:IsShown())
    Clear(holder)

    Put(castbar, 500, 300, 200, 20)
    cursorX, cursorY = 600, 310
    Snap.Start(castbar)
    MoveTo(-2000, 310)
    check("never off the screen: its border at the edge", Near(castbar.points[4], BORDER))
    Snap.Stop(castbar)

    -- Shift: along one line only, once it has gone 3.
    Put(castbar, 500, 300, 200, 20)
    cursorX, cursorY = 600, 310
    Snap.Start(castbar)
    shiftDown = true
    MoveTo(700, 340)
    check("Shift held: along the way it went furthest only",
        Near(castbar.points[4], 600) and Near(castbar.points[5], 300))
    shiftDown = false
    MoveTo(700, 340)
    check("Shift let go: free again", Near(castbar.points[5], 330))
    Snap.Stop(castbar)
    Snap.Deselect()
    Clear(castbar)
end

Section("a click selects, a click again lets go; the arrow keys move it a pixel, Shift 100")
do
    castbar.shown = true
    Put(castbar, 500, 300, 200, 20)
    Tick(0.02)
    Press(castbar)
    check("clicked: selected, and its menu opened beside it", Snap.Selected() == castbar
        and Unlock.menu:IsShown() and Unlock.menu.title.text == "Castbar")
    Tick(0.02)
    local mover = MoverOf(castbar)
    check("selected: a white outline and a white wash", Same(mover.outline.colour, { 1, 1, 1, 0.9 })
        and mover.wash:IsShown())
    check("its top left in numbers while selected",
        mover.coords:IsShown() and mover.coords.text == "500, " .. tostring(320 - 1080))
    local keys = Snap.keys
    check("the arrow keys taken while a piece is selected", keys:IsKeyboardEnabled())
    keys.scripts.OnKeyDown(keys, "UP")
    check("Up: a pixel up", Near(castbar.points[5], 301) and keys.propagates == false)
    shiftDown = true
    keys.scripts.OnKeyDown(keys, "RIGHT")
    shiftDown = false
    check("Shift+Right: 100 right", Near(castbar.points[4], 600))
    keys.scripts.OnKeyDown(keys, "A")
    check("any other key goes on to the game", keys.propagates == true)
    Press(castbar)
    check("clicked again: let go of, its menu shut", Snap.Selected() == nil and not keys:IsKeyboardEnabled()
        and not Unlock.menu:IsShown())

    -- A click on empty space lets go too (the player, 2026-10-03); one on
    -- the piece, the bar or the menu does not.
    Press(castbar)
    mouseOver = { [mover] = true }
    Fire("GLOBAL_MOUSE_DOWN")
    check("a click on a piece: still selected", Snap.Selected() == castbar)
    mouseOver = { [Unlock.bar] = true }
    Fire("GLOBAL_MOUSE_DOWN")
    check("a click on the bar: still selected", Snap.Selected() == castbar)
    mouseOver = {}
    Fire("GLOBAL_MOUSE_DOWN")
    check("a click on empty space: let go of", Snap.Selected() == nil and not keys:IsKeyboardEnabled())
    Core.RevertEditMode()
    Clear(castbar)
end

Section("a mover over every piece, EllesmereUI's, in the addon's look")
do
    castbar.shown = true
    Put(castbar, 500, 300, 200, 20)
    Tick(0.02)
    local mover = MoverOf(castbar)
    check("over it, the size of what shows of it",
        mover:IsShown() and Near(mover.width, 200 + 2 * BORDER) and Near(mover.height, 20 + 2 * BORDER))
    check("its name in it", mover.label.text == "Castbar" and mover.label:IsShown())
    check("dark, outlined in gold", mover.bg.alpha ~= 0 and Same(mover.outline.colour, { Core.Style.GOLD[1],
        Core.Style.GOLD[2], Core.Style.GOLD[3], 0.6 }))
    check("in the DIALOG strata", mover.strata == "DIALOG")

    check("nothing on it but its name: no links, no settings button", mover.links == nil and mover.cog == nil)
    mouseOver = { [mover] = true }
    Tick(0.02)
    check("under the mouse: white at once, its size unchanged", Same(mover.outline.colour, { 1, 1, 1, 0.9 })
        and Near(mover.width, 200 + 2 * BORDER))
    mouseOver = {}
    Tick(0.02)
    check("the mouse gone: gold again", Near(mover.outline.colour[4], 0.6))

    check("its place in numbers, selected or not", mover.coords:IsShown()
        and mover.coords.text == "500, " .. tostring(320 - 1080) and Snap.Selected() == nil)

    shiftDown = true
    mover.scripts.OnMouseUp(mover, "RightButton")
    shiftDown = false
    check("Shift+Right-click: hidden", not mover:IsShown())
    Tick(0.02)
    check("until Unlock Mode closes", not mover:IsShown())
    Core.SetUnlocked(false)
    Core.SetUnlocked(true)
    Tick(0.02)
    check("open again: back", mover:IsShown())

    plates.player.shown, plates.target.shown = true, true
    Put(plates.player, 100, 100, 600, 400)
    Put(plates.target, 200, 200, 50, 50)
    Tick(0.02)
    check("the smaller over the bigger", MoverOf(plates.target):GetFrameLevel() > MoverOf(plates.player):GetFrameLevel())
    Clear(plates.player)
    Clear(plates.target)
    Clear(castbar)
end

Section("W Match and H Match: one piece's size taken from another's")
do
    local cdb = Core.Castbar.db
    local width, height = cdb.barWidth, cdb.barHeight
    local castEntry, playerEntry = EntryOf(castbar), EntryOf(plates.player)
    castbar.shown, plates.player.shown = true, true
    Put(castbar, 500, 300, 200, 20)
    Put(plates.player, 300, 400, 150, 30)
    Tick(0.02)
    local mover = MoverOf(castbar)
    local menu = Unlock.menu
    Press(castbar)
    check("in its menu: Match Width and Match Height", menu.matchW:IsShown() and menu.matchH:IsShown()
        and menu.matchW.label.text == "Match Width" and menu.matchH.label.text == "Match Height")
    Click(menu.matchW)
    check("Match Width: waiting for the piece to match, the menu out of the way",
        Snap.Picking() and Snap.Picking().axis == "w" and not menu:IsShown())
    Tick(0.02)
    check("its mover says what to click", mover.pick:IsShown()
        and mover.pick.text == "Click any element\nto match its width")
    check("the screen darker while it waits, at once", Near(Unlock.dimmer.level, 0.5))
    Press(plates.player)
    check("clicked: the castbar takes the player frame's width", cdb.barWidth == 150
        and Snap.MatchOf(castEntry, "w") == "player" and Snap.Picking() == nil)
    check("still the castbar selected, its menu back", Snap.Selected() == castbar and menu:IsShown()
        and menu.entry == castEntry)
    Tick(0.02)
    check("the screen as it was", Near(Unlock.dimmer.level, 0.2))
    check("the menu says so, an Extra Width in place of its width",
        menu.matchW.label.text == "Unmatch Width: Player" and menu.extraW:IsShown() and not menu.wRow:IsShown())
    Enter(menu.extraW.box, "6")
    check("an extra: 6 wider", cdb.barWidth == 156)
    plates.player.width = 170
    Snap.ScheduleMatches()
    Tick(0.02)
    check("the player frame resized: the castbar follows the next frame", cdb.barWidth == 176)

    inCombat = true
    plates.player.width = 200
    Snap.ApplyMatches()
    check("never in combat", cdb.barWidth == 176)
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    Tick(0.02)
    check("caught up when it ends", cdb.barWidth == plates.player:GetWidth() + 6)

    local ok, why = Snap.SetMatch(playerEntry, "w", castEntry)
    check("a unit frame has no width of its own: EllesmereUI's words",
        not ok and why == "Elements cannot size match to\nCastbar")
    local fsrEntry = Snap.EntryById("fsr")
    Snap.SetMatch(fsrEntry, "w", castEntry)
    Snap.ClearMatch(castEntry, "w")
    ok, why = Snap.SetMatch(castEntry, "w", fsrEntry)
    check("round in a circle: refused", not ok and why == "This would create a circular width match")
    Snap.Refuse(castEntry, why)
    check("a refusal flashes red round the piece and says why at the cursor",
        Snap.refusal:IsShown() and Snap.refusal.why == why and GameTooltip.owner == Snap.refusal)
    Tick(1)
    Tick(1)
    Tick(1.1)
    check("and goes after 3 seconds", not Snap.refusal:IsShown())
    Snap.ClearMatch(fsrEntry, "w")

    Snap.SetMatch(castEntry, "h", playerEntry)
    Tick(0.02)
    check("a height too", cdb.barHeight == plates.player:GetHeight())
    Snap.OpenCog(castEntry, mover)
    Click(menu.matchH)
    check("Unmatch Height: its own height again, as it is now", Snap.MatchOf(castEntry, "h") == nil)
    Snap.Deselect()
    Core.RevertEditMode()
    check("Exit Without Saving's revert: the sizes back", cdb.barWidth == width and cdb.barHeight == height)
    Clear(castbar)
    Clear(plates.player)
end

Section("Anchor: from exactly where it is - and moving with it")
do
    local a, b, c = castbar, holder, Snap.EntryById("xp").frame
    local A, B, C = EntryOf(a), EntryOf(b), EntryOf(c)
    a.shown, b.shown, c.shown = true, true, true
    Put(a, 500, 300, 200, 20)
    Put(b, 900, 600, 100, 20)
    Tick(0.02)
    local pieceMenu = Unlock.menu
    Press(b)
    check("in its menu: Anchor", pieceMenu.anchor:IsShown() and pieceMenu.anchor.label.text == "Anchor")
    Click(pieceMenu.anchor)
    check("Anchor: waiting for the piece to anchor to", Snap.Picking() and Snap.Picking().axis == "anchor"
        and not pieceMenu:IsShown())
    Tick(0.02)
    check("its mover says what to click", MoverOf(b).pick.text == "Click any element\nto anchor to it")
    b.points = {}
    Press(a)
    check("clicked: anchored at once, no side asked - and nothing moved",
        Snap.AnchorOf(B) == "castbar" and b.points[1] == nil and Near(b.left, 900))
    local to, side, x, y = Snap.AnchorOf(B)
    check("from exactly where it is: above the castbar, its offset kept",
        to == "castbar" and side == "above" and Near(x, 950 - 600) and Near(y, (600 - BORDER) - (320 + BORDER)))
    Tick(0.02)
    check("its name orange; its menu back, offering Remove Anchor",
        Same(MoverOf(b).label.textColor, { 1, 0.7, 0.3, 0.85 }) and pieceMenu:IsShown()
        and pieceMenu.entry == B and pieceMenu.anchor.label.text == "Remove Anchor")

    Put(a, 550, 300, 200, 20)
    Tick(0.02)
    check("the castbar moved: it comes along, the same way off", Near(b.left, 950) and Near(b.bottom, 600))
    Snap.Select(B)
    Snap.Nudge(5, 0)
    check("moved by hand: still anchored, at the new offset", Snap.AnchorOf(B) == "castbar"
        and Near(select(3, Snap.AnchorOf(B)), 355))

    local ok, why = Snap.AnchorHere(A, A)
    check("not to itself", not ok and why == "An element cannot anchor to itself")
    ok, why = Snap.AnchorHere(A, B)
    check("not in a circle", not ok and why == "This would create a circular anchor")
    Put(c, 1200, 800, 100, 20)
    Snap.AnchorHere(C, B)
    ok, why = Snap.AnchorHere(C, A)
    check("nor to a piece further up its own line", not ok and why == "This would create a circular anchor")
    Snap.Unanchor(C)

    Snap.OpenCog(B)
    Click(pieceMenu.anchor)
    check("Remove Anchor: it stays where it is, anchored to nothing",
        Snap.AnchorOf(B) == nil and Near(b.left, 955))

    -- RELATIVE TO SCREEN: from where it is.
    Put(a, 1700, 300, 200, 20)
    a.points = {}
    Snap.AnchorToScreen(A, "SCREEN_RIGHT")
    to, side, x = Snap.AnchorOf(A)
    check("to the screen's right edge, from where it is", to == "SCREEN_RIGHT" and side == "left"
        and Near(x, 1900 + BORDER - 1920) and a.points[1] == nil)
    Snap.ClearScreenAnchor(A)
    check("Center: let go of the edge", Snap.AnchorOf(A) == nil)

    Snap.Deselect()
    Core.RevertEditMode()
    Clear(a)
    Clear(b)
    Clear(c)
end

Section("a piece's menu: size, place, anchor, screen, reset - free on the screen")
do
    local cdb = Core.Castbar.db
    local width = cdb.barWidth
    castbar.shown, plates.player.shown = true, true
    cdb.barLeft, cdb.barTop, cdb.autoPlaced = 500, -760, false
    Put(castbar, 500, 300, 200, 20)
    Put(plates.player, 100, 600, 150, 30)
    Tick(0.02)
    local mover = MoverOf(castbar)
    mover.scripts.OnMouseUp(mover, "RightButton")
    local menu = Unlock.menu
    check("right-click: selected, and its menu centred in the right half of the screen - not by the piece",
        Snap.Selected() == castbar and menu:IsShown() and menu.title.text == "Castbar"
        and menu.points[1] == "CENTER" and menu.points[2] == UIParent and menu.points[3] == "CENTER"
        and Near(menu.points[4], 1920 / 4) and menu.points[5] == 0)
    check("in the addon's look", menu.bg ~= nil and menu.border ~= nil and menu.strata == "FULLSCREEN")
    check("its size and place; no anchor rows while it has none",
        menu.wRow:IsShown() and menu.hRow:IsShown() and menu.xRow:IsShown() and menu.yRow:IsShown()
        and not menu.anchored:IsShown() and not menu.extraW:IsShown())
    check("Relative to Screen, Center on Screen, Reset Position - no snap target",
        menu.snapRow == nil and menu.snapTarget == nil
        and menu.screen:IsShown() and menu.screen.control.label.text == "Center"
        and menu.centre.label.text == "Center on Screen" and menu.reset.label.text == "Reset Position")
    check("its numbers: the top left from the screen's top left, the width",
        menu.xRow.box.text == "500" and menu.yRow.box.text == tostring(320 - 1080)
        and menu.wRow.box.text == tostring(width))

    menu.scripts.OnDragStart(menu)
    menu.scripts.OnDragStop(menu)
    menu.points = { "TOPLEFT", UIParent, "BOTTOMLEFT", 77, 777 }
    Snap.OpenCog(EntryOf(castbar), mover)
    check("dragged: it stays where it was put", menu.points[4] == 77 and menu.dragged == true)

    Enter(menu.xRow.box, "450")
    check("X typed: moved there", Near(castbar.points[4], 450))
    Enter(menu.wRow.box, "180")
    check("Width typed: the castbar's own width setting", cdb.barWidth == 180)
    Click(menu.centre)
    check("Center on Screen: its middle on the screen's middle, both ways",
        Near(castbar.left + castbar.width / 2, 960) and Near(castbar.bottom + castbar.height / 2, 540),
        tostring(castbar.left) .. " " .. tostring(castbar.bottom))

    Snap.AnchorHere(EntryOf(castbar), EntryOf(plates.player))
    Unlock.RefreshMenu()
    check("anchored: to what, and the offset", menu.anchored:IsShown() and menu.anchored.value.text == "Player"
        and menu.offsetX:IsShown())
    Enter(menu.offsetY.box, "-10")
    check("an offset typed: moved by it", Near(select(4, Snap.AnchorOf(EntryOf(castbar))), -10))

    Click(menu.reset)
    check("Reset Position: placed by the addon again", cdb.autoPlaced == true)

    mouseOver = {}
    Fire("GLOBAL_MOUSE_DOWN")
    check("a click elsewhere shuts it", not menu:IsShown())
    Snap.Deselect()
    Core.RevertEditMode()
    cdb.barWidth = width
    Clear(castbar)
    Clear(plates.player)
end

Section("Exit: Unsaved Changes, EllesmereUI's question")
do
    local cdb = Core.Castbar.db
    cdb.barLeft, cdb.autoPlaced = 800, false
    Core.CommitEditMode()
    local bar = Unlock.bar
    check("the bar along the top: Unlock Mode, Preview, Snap Elements, Exit and Save & Exit - nothing else",
        bar:IsShown() and bar.title.text == "Unlock Mode" and bar.exit.label.text == "Exit"
        and bar.save.label.text == "Save & Exit" and bar.snap and bar.preview and #bar.controls == 2
        and bar.dark == nil and bar.coords == nil and bar.hoverBar == nil and bar.grid == nil)

    -- PREVIEW: Unlock Mode's look gone, the frames alone.
    local function AnyMoverShown()
        for _, mover in pairs(Snap.movers) do if mover:IsShown() then return true end end
        return false
    end
    castbar.shown = true
    Put(castbar, 500, 300, 200, 20)
    Tick(0.02)
    check("before: movers, the grid and the dimmer", AnyMoverShown() and Core.grid:IsShown()
        and Unlock.dimmer:IsShown() and not Snap.Previewing())
    Press(castbar)
    check("(a piece selected, its menu open)", Snap.Selected() == castbar and Unlock.menu:IsShown())
    Unlock.SetPreview(true)
    Tick(0.02)
    check("Preview on: no mover, no grid, no dimmer, nothing selected, the menu shut",
        Snap.Previewing() and not AnyMoverShown() and not Core.grid:IsShown()
        and not Unlock.dimmer:IsShown() and Snap.Selected() == nil and not Unlock.menu:IsShown()
        and bar:IsShown())
    local left = castbar.left
    Snap.Start(castbar)
    check("nothing picked up while previewing", not Snap.IsDragging() and castbar.left == left)
    Unlock.Escape()
    Tick(0.02)
    check("Esc: back to Unlock Mode's look first, still unlocked", not Snap.Previewing()
        and Core.IsUnlocked() and AnyMoverShown() and Core.grid:IsShown() and Unlock.dimmer:IsShown())
    Unlock.SetPreview(true)
    Core.SetUnlocked(false)
    Core.SetUnlocked(true)
    check("Unlock Mode closed and opened again: not previewing", not Snap.Previewing())
    Snap.Deselect()
    Clear(castbar)
    -- Centred, slightly below the micro menu's own place on the top edge.
    local micro = Snap.EntryById("micro")
    local box = micro and Snap.Box(micro)
    local below = Unlock.BAR_GAP + (box and (box.t - box.b) or 0)
    check("it opens slightly below the micro menu's place, centred",
        bar.points[1] == "TOP" and bar.points[3] == "TOP" and bar.points[4] == 0
        and Near(bar.points[5], -below) and below > Unlock.BAR_GAP)
    bar.scripts.OnDragStart(bar)
    check("dragged around by itself", bar.moving == true)
    bar.scripts.OnDragStop(bar)
    check("nothing changed: Save & Exit not lit", bar.save.style == nil)
    cdb.barLeft = 900
    Core.EditModeMoved()
    check("something changed: lit", bar.save.style == "active")
    Click(bar.exit)
    local ask = Unlock.ask
    check("Exit asks", ask:IsShown() and ask.title.text == "Unsaved Changes"
        and ask.text.text == "You have unsaved position changes.\nWhat would you like to do?"
        and ask.discard.label.text == "Exit Without Saving" and ask.save.label.text == "Save & Exit")
    check("and Unlock Mode stays open until answered", Core.IsUnlocked())
    -- Continue (the player, 2026-10-03: "in case user changes their mind").
    check("Continue between the two", ask.continue ~= nil and ask.continue.label.text == "Continue")
    Click(ask.continue)
    check("Continue: the question away, Unlock Mode still open, the change still there and unsaved",
        not ask:IsShown() and Core.IsUnlocked() and bar:IsShown() and Near(cdb.barLeft, 900)
        and Core.EditModePending())
    Click(bar.exit)
    check("Exit again: asked again", ask:IsShown())
    Click(ask.discard)
    check("Exit Without Saving: put back, and closed", Near(cdb.barLeft, 800) and not Core.IsUnlocked()
        and not ask:IsShown() and not bar:IsShown())

    Core.SetUnlocked(true)
    cdb.barLeft = 900
    Core.EditModeMoved()
    Click(bar.save)
    check("Save & Exit: kept, and closed", Near(cdb.barLeft, 900) and not Core.IsUnlocked()
        and not Core.EditModePending())

    Core.SetUnlocked(true)
    cdb.barLeft = 950
    Core.EditModeMoved()
    Fire("ADDONS_UNLOADING")
    check("a /reload with it unsaved: the saved file has the last saved place", Near(cdb.barLeft, 900))
    Core.RevertEditMode()
end

Section("Esc, a step at a time")
do
    local esc = Unlock.esc
    check("Esc taken while Unlock Mode is open", esc:IsShown() and esc:IsKeyboardEnabled())
    castbar.shown = true
    Put(castbar, 500, 300, 200, 20)
    Tick(0.02)
    local mover = MoverOf(castbar)
    mover.scripts.OnMouseUp(mover, "RightButton")
    esc.scripts.OnKeyDown(esc, "ESCAPE")
    check("a menu open: shut", not Unlock.menu:IsShown() and Core.IsUnlocked() and esc.propagates == false)
    Snap.StartPicking(EntryOf(castbar), "anchor")
    esc.scripts.OnKeyDown(esc, "ESCAPE")
    check("waiting for a piece: stopped", Snap.Picking() == nil and Core.IsUnlocked())
    esc.scripts.OnKeyDown(esc, "W")
    check("other keys go on to the game", esc.propagates == true)
    esc.scripts.OnKeyDown(esc, "ESCAPE")
    check("else: Unlock Mode left", not Core.IsUnlocked() and not esc:IsKeyboardEnabled())
    Clear(castbar)
end

Section("the game's own frames: a box over each that hands over to the game's Edit Mode")
do
    Core.SetUnlocked(true)
    local system = CreateFrame("Frame", "DogsTestSystem", UIParent)
    system.Selection = CreateFrame("Frame", nil, system)
    Put(system.Selection, 800, 600, 80, 40)
    function system:GetSystemName() return "Test Bar" end
    table.insert(manager.registeredSystemFrames, system)
    Tick(0.02)
    local box = Unlock.boxes[system]
    check("a box over it, named", box and box:IsShown() and box.label.text == "Test Bar"
        and box.points[1] == "BOTTOMLEFT" and Near(box.points[4], 800) and Near(box.width, 80))
    check("no hint until the mouse is over it", not box.action:IsShown())
    -- (Its place as the game would read it back.)
    box.left, box.top = 800, 640
    mouseOver = { [box] = true }
    Tick(0.02)
    check("too small for it: no Edit from Blizzard, the name where it was",
        not box.action:IsShown() and box.label.points[5] == 0)
    Put(system.Selection, 800, 600, 200, 40)
    Tick(0.02)
    check("big enough: under the mouse, Edit from Blizzard, the name up",
        box.action:IsShown() and box.action.text == "Edit from Blizzard" and box.label.points[5] == 5)
    local handover = Unlock.handover
    check("a secure button over it runs the game's own /editmode",
        handover:IsShown() and handover.points[4] == 800 and handover:GetAttribute("type") == "macro"
        and handover:GetAttribute("macrotext") == "/editmode")
    handover.scripts.PreClick(handover, "LeftButton")
    check("clicked, nothing unsaved: Unlock Mode closed as the game's opens", not Core.IsUnlocked())
    check("the button still there for its own click to finish", handover:IsShown())
    handover.scripts.PostClick(handover, "LeftButton")
    check("then gone", not handover:IsShown())
    check("the options not brought back over the game's Edit Mode", not Options.IsShown())

    Core.SetUnlocked(true)
    Core.EditModeMoved()
    Tick(0.02)
    check("something unsaved: no secure button", not handover:IsShown())
    box.scripts.OnMouseUp(box, "LeftButton")
    local ask = Unlock.ask
    check("the box clicked asks first", ask:IsShown() and Core.IsUnlocked())
    Tick(0.2)
    local secure = Unlock.secureAsk
    check("its buttons secure too, each running /editmode after",
        secure.discard:IsShown() and secure.save:IsShown()
        and secure.discard:GetAttribute("macrotext") == "/editmode")
    secure.discard.scripts.PreClick(secure.discard, "LeftButton")
    check("Exit Without Saving: put back and closed", not Core.IsUnlocked() and not Core.EditModePending())
    secure.discard.scripts.PostClick(secure.discard, "LeftButton")
    check("and the secure buttons go", not secure.discard:IsShown() and not secure.save:IsShown())

    Core.SetUnlocked(true)
    mouseOver = {}
    Snap.StartPicking(EntryOf(castbar), "anchor")
    box.scripts.OnMouseUp(box, "LeftButton")
    check("waiting for a piece: the game's frames refused",
        Snap.refusal.why == "Elements cannot be anchored to\nTest Bar" and Core.IsUnlocked())
    Core.SetHeld(system, true)
    Tick(0.02)
    check("one the addon stands in for has no box", not box:IsShown())
    Core.SetHeld(system, false)
    table.remove(manager.registeredSystemFrames)
    Tick(0.02)
    check("gone from the game's list: gone", not box:IsShown())
end

Section("a fight: Unlock Mode put away, back after it")
do
    Core.SetUnlocked(false)
    inCombat = true
    Core.SetUnlocked(true)
    check("not opened in combat", not Core.IsUnlocked())
    inCombat = false
    Core.SetUnlocked(true)
    Core.EditModeMoved()
    Fire("PLAYER_REGEN_DISABLED")
    inCombat = true
    check("a fight: put away, what changed kept", not Core.IsUnlocked() and not Unlock.bar:IsShown()
        and Core.UnlockSuspended() and Core.EditModePending())
    inCombat = false
    pendingTimer = nil
    Fire("PLAYER_REGEN_ENABLED")
    check("back half a second after it", pendingTimer ~= nil)
    pendingTimer()
    check("back", Core.IsUnlocked() and Unlock.bar:IsShown() and Core.EditModePending())
    Core.RevertEditMode()
    Core.SetUnlocked(false)
end

Section("talent buttons show their rank out of the most there is")
do
    local talents = {}
    PlayerSpellsFrame = { TalentsFrame = talents }
    TalentButtonUtil = { SetSpendText = function(button, text) button.SpendText:SetText(text) end }
    -- (The talent window loading: the addon hooks the game's writer then.)
    Fire("ADDON_LOADED", "Blizzard_PlayerSpells")
    local function Written(frame, current, max, text)
        local b = { nodeInfo = { currentRank = current, maxRanks = max }, SpendText = UIParent:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med1") }
        function b:GetTalentFrame() return frame end
        TalentButtonUtil.SetSpendText(b, text)
        return b.SpendText.text
    end
    check("the game writes \"1\" on a class talent of 5: it reads 1/5", Written(talents, 1, 5, "1") == "1/5")
    check("a talent with one rank keeps the game's text", Written(talents, 1, 1, "1") == "1")
    check("where the game shows nothing, nothing", Written(talents, 0, 5, "") == "")
    check("the game writes \"3\" on a class talent: it reads 3/5", Written(talents, 3, 5, "3") == "3/5")
    check("another talent tree (a profession's) keeps the game's text", Written({}, 3, 5, "3") == "3")
end

Section("the raid frames' Edit Mode box is fitted to the raid frames")
do
    -- The game's container, left by its own RefreshSize stretched over the
    -- raid-style party frames too: 1500 x 900, but its flow used 300 x 200.
    local container = CreateFrame("Frame", "CompactRaidFrameContainer", UIParent)
    container.Selection = CreateFrame("Frame", nil, container)
    container.width, container.height = 1500, 900
    container.flowOrientation = "vertical"
    container.flowMaxPrimaryUsed, container.flowMaxSecondaryUsed = 300, 200
    function FlowContainer_GetUsedBounds(c)
        return c.flowMaxPrimaryUsed, c.flowMaxSecondaryUsed
    end
    Core.Frames.RaidFrames.FitRaidBox()
    local p1, rel1, rp1, x1, y1 = container.Selection:GetPoint(1)
    local p2, rel2, rp2, x2, y2 = container.Selection:GetPoint(2)
    check("its box round what the raid frames take, from the container's own corners",
        p1 == "TOPLEFT" and rel1 == container and x1 == 0 and y1 == 0
        and p2 == "BOTTOMRIGHT" and rel2 == container and rp2 == "BOTTOMRIGHT"
        and Near(x2, 300 - 1500) and Near(y2, 900 - 200))
    check("the container itself left as the game made it", container.width == 1500 and container.height == 900)
    -- Edit Mode keeps it on screen by its clamp: the box's, not the whole
    -- stretched container's (it jumped about, and dragged went sideways only).
    local insets = container.clampInsets
    check("and its clamp is that box, as the game's UpdateClampOffsets would fit it",
        insets and insets[1] == 0 and Near(insets[2], 300 - 1500) and insets[3] == 0
        and Near(insets[4], 900 - 200))
    container.width, container.height = 3000, 3000
    Core.Frames.RaidFrames.FitRaidBox()
    check("the 3000 x 3000 the game gives it while laying out: still clamped by the raid frames only",
        Near(container.clampInsets[2], 300 - 3000) and Near(container.clampInsets[4], 3000 - 200))

    -- The game's, edited in the game's Edit Mode from Unlock Mode's handover
    -- box, as the quest tracker is (the player, 2026-10-03: "make it similar
    -- to objectives ... forward user to blizz edit mode").
    container.shown = true
    container.left, container.top = 40, 800
    table.insert(EditModeManagerFrame.registeredSystemFrames, container)
    Fire("ADDON_LOADED", "Blizzard_CompactRaidFrames")
    local GF = Core.GameFrames
    check("not a piece of Unlock Mode's: no mover, nothing of theirs held or moved",
        Snap.EntryById("raid") == nil and not Core.IsHeld(container) and Core.GameFrames.places.raid == nil)
    check("the size they take kept", GF.db.raidWidth == 300 and GF.db.raidHeight == 200)
    local function Listed()
        for _, system in ipairs(Snap.GameSystems()) do
            if system == container then return true end
        end
        return false
    end
    check("shown: a handover box over them", Listed())
    container.shown = false
    container.flowMaxPrimaryUsed, container.flowMaxSecondaryUsed = 0, 0
    local box = Snap.SystemBox(container)
    check("no raid up: the handover box all the same, where the game has them, the size they took when last seen",
        Listed() and box and Near(box.l, 40) and Near(box.t, 800) and Near(box.r - box.l, 300)
        and Near(box.t - box.b, 200))

    -- The game's Edit Mode open, its raid preview up (View Raid Size): its
    -- own box measured - and out of a raid, Unlock Mode shows exactly it
    -- (the player, 2026-10-03: "the raid frames in our unlock mode and blizz
    -- edit mode doesnt match").
    local selection = container.Selection
    selection.left, selection.right, selection.top, selection.bottom = 500, 620, 600, 450
    container.shown = true
    GF.RememberEditModeRaid()
    check("the game's Edit Mode shut: nothing measured", GF.db.raidEditWidth == 0)
    local wasActive = EditModeManagerFrame.IsEditModeActive
    EditModeManagerFrame.IsEditModeActive = function() return true end
    GF.RememberEditModeRaid()
    EditModeManagerFrame.IsEditModeActive = wasActive
    container.shown = false
    box = Snap.SystemBox(container)
    check("no raid up: the very box the game's Edit Mode last showed - its place, its size",
        box and Near(box.l, 500) and Near(box.r, 620) and Near(box.t, 600) and Near(box.b, 450),
        box and ("%s %s %s %s"):format(box.l, box.r, box.t, box.b))
    GF.db.raidEditWidth, GF.db.raidEditHeight = 0, 0
end

Section("the damage meter: a handover box even while it hides out of combat")
do
    -- The game's, shown In Combat only (its Edit Mode Visibility): out of a
    -- fight hidden, but still where the game keeps it.
    local meter = CreateFrame("Frame", "DamageMeter", UIParent)
    meter.left, meter.right, meter.top, meter.bottom = 1500, 1800, 400, 200
    meter.shown = false
    table.insert(EditModeManagerFrame.registeredSystemFrames, meter)
    local function Listed()
        for _, system in ipairs(Snap.GameSystems()) do
            if system == meter then return true end
        end
        return false
    end
    cvars.damageMeterEnabled = true
    local box = Snap.SystemBox(meter)
    check("hidden out of combat: its box all the same, where the game has it",
        Listed() and box and Near(box.l, 1500) and Near(box.r, 1800) and Near(box.t, 400) and Near(box.b, 200))
    cvars.damageMeterEnabled = false
    check("switched off in the game's options: no box", not Listed())
    cvars.damageMeterEnabled = true
    meter.shown = true
    check("shown: a box as any of the game's frames", Listed())
    meter.shown = false
    cvars.damageMeterEnabled = nil
    table.remove(EditModeManagerFrame.registeredSystemFrames)
end

Section("old switches are dropped from a saved file; anchors and matches kept")
do
    Reload({ placing = { gridSize = 32, gridSpacing = 48, showGrid = true, snapGrid = false,
                         snapFrames = true, snapEdges = false,
                         grid = true, spacing = 200, darkOverlays = false,
                         snaps = {
                             fsr = { to = "castbar", point = "BOTTOM", rel = "TOP", x = 0, y = 6, explicit = true },
                             -- Hung from the player only for having been dropped beside it.
                             cooldowns = { to = "player", point = "BOTTOM", rel = "TOP", x = 0, y = 70 },
                             pet = "player",
                             -- One of the game's frames: moved in the game's Edit Mode now.
                             loot = { to = "game:MainMenuBar", point = "BOTTOM", rel = "TOP", x = 0, y = 0, explicit = true },
                         },
                         matches = { xp = { w = "castbar", wx = 0 } } } })
    Login()
    local fresh = DogsForeverUI.Snap.db
    check("no old switch left", fresh.gridSize == nil and fresh.gridSpacing == nil and fresh.showGrid == nil
        and fresh.snapGrid == nil and fresh.snapFrames == nil and fresh.snapEdges == nil
        and fresh.spacing == nil and fresh.darkOverlays == nil and fresh.grid == nil)
    check("anchors made on purpose and whose size matches whose: kept",
        fresh.snaps.fsr and fresh.snaps.fsr.to == "castbar" and fresh.matches.xp.w == "castbar")
    check("pieces that only hung from another for having been dropped beside it: let go",
        fresh.snaps.cooldowns == nil and fresh.snaps.pet == nil)
    check("none to the game's frames", fresh.snaps.loot == nil)
end

Summary()
