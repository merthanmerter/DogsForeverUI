-- UNLOCK MODE, ITS ENGINE AND ITS MOVERS: EllesmereUI's, ported (the player,
-- 2026-10-02: "port it properly, our own frames like ellesmere" -
-- Ellesmere\EllesmereUI\EUI_UnlockMode.lua). The addon's own pieces only; the
-- game's own frames stay the game's, a box over each handing over to the
-- game's Edit Mode (Options\Unlock.lua). DogsForeverUI.lua opens and closes
-- it; Options\Unlock.lua is its bar, each mover's cog menu, the anchor side
-- menu, the Unsaved Changes question and the handover boxes. Here:
--
--   * a MOVER over every piece, dark, its name in it and its place in
--     numbers in its corner, gold outlined - white under the mouse and while
--     selected, its name orange while anchored (THE MOVERS, below);
--   * DRAGGED freely - Shift keeps it to one line - and snapped while
--     dragged to the one piece nearest it (or the one picked as its snap
--     target): its edges or middle within 6 units of that piece's edges or
--     middle, a line along each, that piece outlined white - and its
--     middle onto the screen's middle lines, across and up and down (the
--     player, 2026-10-03). Nothing else pulls: not the screen's edges, not
--     the grid (Snap Elements off: nothing);
--   * a click SELECTS it (a white wash, white outline), a click again lets
--     go; the arrow keys move the selected one a pixel, Shift 100.
--     Right-click: selected, and its cog menu. Shift+Right-click: hidden
--     until Unlock Mode closes;
--   * W Match / H Match take another piece's width / height, kept whenever
--     that changes (SIZES); Anchor puts it against a side of another -
--     Left, Right, Top or Bottom, flush and centred - and it moves with it
--     from then on, the offset kept as it is dragged or typed (ANCHORED);
--     the cog's Relative to Screen does the same to a screen edge, from where
--     it is. A link drawn from an anchored piece to its anchor while either
--     is under the mouse;
--   * a piece that cannot do what was asked flashes red, the reason at the
--     cursor.
--
-- Every piece that can be dragged registers here once (Snap.Register). The
-- piece is where it shows when its move ends, and its own save (opts.save)
-- reads it back as before.

local Snap = {
    key = "placing",
    title = "Placing",
    -- The bar's one switch, kept with the settings: whether pieces snap.
    -- The grid is always bright, the movers always dark with their place in
    -- numbers, and the bar always shown (the player, 2026-10-03: no options
    -- for those). Every older switch (grid, dark, coords, hoverBar, showGrid,
    -- gridSpacing, spacing...) is dropped from a saved file.
    defaults = {
        snap = true,            -- pieces snap (Snap Elements)
    },
    -- What hangs from what, and whose size matches whose (below): kept with
    -- the places, saved and reverted with them. Which anchors the addon made
    -- to start with (ANCHORED TO START WITH), and which version of the
    -- addon's own default layout it has had (Core\DefaultPlaces.lua). (No
    -- game Edit Mode layout of the addon's any more: the "Default Preset"
    -- went, 2026-10-03 - the addon places its pieces itself.)
    placement = { snaps = true, matches = true, anchoredByDefault = true, defaultPlaces = true },
}
DogsForeverUI.Snap = Snap

do -- private scope
    local Core = DogsForeverUI
    local Style = Core.Style

    -- How far the mouse goes before a press becomes a drag, on screen.
    Snap.THRESHOLD = 4
    -- EllesmereUI's snapping distance (SNAP_THRESH), UIParent's units.
    Snap.SNAP_THRESH = 6
    -- What shows of a piece is its bars and the border round them.
    local BORDER = Style.BORDER_INSET

    ---------------------------------------------------------------------------
    -- The pieces.
    ---------------------------------------------------------------------------

    local entries = {}          -- in the order they registered
    local byFrame = {}
    Snap.entries = entries

    -- opts = {
    --   group  pieces of one group never snap to each other (the party's
    --          frames, which move as one column)
    --   extra  () -> left, right, top, bottom: how far the piece reaches
    --          beyond its frame, in the frame's units (a unit frame's name
    --          row above its bars)
    --   parts  () -> list of regions the piece is made of besides the frame
    --          (the cooldown bars above their holder; the party's others)
    --   moveWith () -> list of frames that move with it, live, as one (the
    --          party's column: any one of the four dragged takes the rest)
    --   save   () where it is now, kept: a drag's end, a nudge, following
    --   name   what the piece is called (on its mover, its menu's title)
    --   id     a short name kept in the saved settings: what hangs from
    --          what (the party's four share one)
    -- }
    local byId = {}

    function Snap.Register(frame, opts)
        if byFrame[frame] then return byFrame[frame] end
        local entry = { frame = frame, opts = opts or {} }
        byFrame[frame] = entry
        entries[#entries + 1] = entry
        local id = entry.opts.id
        if id and not byId[id] then byId[id] = entry end
        -- A piece resized for any reason: whatever matches its size follows
        -- (SIZES, below).
        if frame.HookScript then
            frame:HookScript("OnSizeChanged", function()
                if Snap.ScheduleMatches then Snap.ScheduleMatches() end
            end)
        end
        return entry
    end

    function Snap.EntryOf(frame) return byFrame[frame] end
    function Snap.EntryById(id) return byId[id] end

    -- What a piece is called: on its mover, its menu's title.
    local function NameOf(entry)
        local name = entry and entry.opts.name
        if type(name) == "function" then name = name() end
        return name or ""
    end
    Snap.NameOf = NameOf

    ---------------------------------------------------------------------------
    -- THE SCREEN'S EDGES, to anchor to (EllesmereUI's SCREEN_LEFT ...):
    -- each a strip one unit wide just outside the screen, so its inner edge
    -- IS the screen's edge.
    ---------------------------------------------------------------------------

    Snap.SCREEN_EDGES = {
        { key = "SCREEN_LEFT",   label = "Left",   name = "Left Screen Edge",   side = "right" },
        { key = "SCREEN_RIGHT",  label = "Right",  name = "Right Screen Edge",  side = "left" },
        { key = "SCREEN_TOP",    label = "Top",    name = "Top Screen Edge",    side = "below" },
        { key = "SCREEN_BOTTOM", label = "Bottom", name = "Bottom Screen Edge", side = "above" },
    }
    local edgeByKey = {}
    for _, edge in ipairs(Snap.SCREEN_EDGES) do edgeByKey[edge.key] = edge end

    function Snap.IsScreenEdge(key) return edgeByKey[key] ~= nil end

    -- What an anchor target is called: a piece's name, or the screen edge's.
    function Snap.TargetName(id)
        if edgeByKey[id] then return edgeByKey[id].name end
        local entry = byId[id]
        return entry and NameOf(entry) or tostring(id)
    end

    ---------------------------------------------------------------------------
    -- ANCHORED, AND MOVING WITH (EllesmereUI's Anchor). A piece moves with
    -- another only when it was anchored to it - never because it was
    -- dropped beside it: snapping only places.
    --
    -- What is kept is the anchor, as EllesmereUI keeps one: this point of the
    -- piece's box on that point of the other's - its near edge on the
    -- other's edge, the middles across - this far off: placing.snaps =
    -- { [piece id] = { to = the other's id or a screen edge, point, rel, x,
    -- y, explicit = true } }. Where a piece goes is worked out again from
    -- where the other one IS, whenever that has moved for any reason -
    -- never carried along by how far it moved, which drifts (FollowAll).
    ---------------------------------------------------------------------------

    local function Snaps()
        local db = Snap.db
        if type(db) ~= "table" then return {} end
        if type(db.snaps) ~= "table" then db.snaps = {} end
        return db.snaps
    end

    -- What `id` is anchored to, and the anchor.
    local function LinkOf(id)
        local link = id and Snaps()[id]
        if type(link) == "table" and type(link.to) == "string" then return link.to, link end
    end

    -- Everything hanging from `entry`, however far down.
    local function Followers(entry)
        local list, seen = {}, { [entry] = true }
        local function Walk(from)
            local id = from.opts.id
            if not id then return end
            for childId in pairs(Snaps()) do
                local child = byId[childId]
                if LinkOf(childId) == id and child and not seen[child] then
                    seen[child] = true
                    list[#list + 1] = child
                    Walk(child)
                end
            end
        end
        Walk(entry)
        return list, seen
    end

    function Snap.LinkOf(entry) return select(2, LinkOf(entry.opts.id)) end

    local function LetGo(entry)
        if entry.opts.id then Snaps()[entry.opts.id] = nil end
    end

    -- A point of a box (the nine SetPoint names), in UIParent's units: of
    -- its edges given as numbers (PointAt), or of a box table (PointOf).
    local function PointAt(point, l, r, t, b)
        local x = point:find("LEFT") and l or point:find("RIGHT") and r or (l + r) / 2
        local y = point:find("TOP") and t or point:find("BOTTOM") and b or (t + b) / 2
        return x, y
    end

    local function PointOf(box, point)
        return PointAt(point, box.l, box.r, box.t, box.b)
    end

    local ParentBox     -- below: the box of what a piece hangs from
    local AnchorBox     -- below: the box an anchor is measured by

    -- Which box an anchor's offset was measured by: 2, AnchorBox's. (Before
    -- 2026-10-03 it was the whole box, parts and all - and a piece whose
    -- parts come and go jumped as they did: the cooldowns, anchored to the
    -- player frame, as their bars showed in Unlock Mode or in a fight.)
    local ANCHOR_BOX = 2

    -- A piece that grows one way (opts.fixedEdge() -> "LEFT" or "RIGHT", the
    -- edge that stays put; "" its middle - a stance bar as stances are
    -- learnt) hangs above or below another by that edge, not by its middle,
    -- so it grows away from it.
    local function GrowPoint(entry, point)
        local side = point:match("^TOP") or point:match("^BOTTOM")
        if not side or not entry.opts.fixedEdge then return point end
        return side .. entry.opts.fixedEdge()
    end

    -- `entry` anchored to `to`, its `point` on the other's `rel`, at the
    -- offset the two have now (`box`: the piece's own AnchorBox, where it is).
    local function HangFrom(entry, to, point, rel, box)
        local id = entry.opts.id
        if not id then return end
        if not to or to == id then
            Snaps()[id] = nil
            return
        end
        point, rel = point or "CENTER", rel or "CENTER"
        point, rel = GrowPoint(entry, point), GrowPoint(entry, rel)
        local parent = ParentBox(to)
        if not (parent and box) then
            Snaps()[id] = nil
            return
        end
        local px, py = PointOf(parent, rel)
        local mx, my = PointOf(box, point)
        Snaps()[id] = { to = to, point = point, rel = rel, x = mx - px, y = my - py, explicit = true,
                        box = ANCHOR_BOX }
    end

    -- Its anchor, if it has one.
    local function Explicit(entry)
        local _, link = LinkOf(entry.opts.id)
        return link
    end

    -- Moved by hand (already where it was put): an anchored piece stays
    -- anchored, the offset changed (EllesmereUI recaptures it on the drag's
    -- end); any other is simply where it is put.
    local function MovedByHand(entry)
        local link = Explicit(entry)
        local box = link and AnchorBox(entry)
        if box then HangFrom(entry, link.to, link.point, link.rel, box) end
    end

    -- Its anchor by the edge it grows from now (its setting changed, or an
    -- anchor made before it had one): taken again from where it is.
    function Snap.KeepEdge(entry)
        local link = Explicit(entry)
        if link and GrowPoint(entry, link.point) ~= link.point then MovedByHand(entry) end
    end

    -- A region's rectangle in UIParent's units, y up from the bottom.
    local function Rect(region)
        local left, right = region:GetLeft(), region:GetRight()
        local top, bottom = region:GetTop(), region:GetBottom()
        if not (left and right and top and bottom) then return end
        local k = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
        return left * k, right * k, top * k, bottom * k
    end

    local function NewBox(l, r, t, b)
        return { l = l, r = r, t = t, b = b, cx = (l + r) / 2, cy = (t + b) / 2 }
    end

    local function Shifted(box, dx, dy)
        return NewBox(box.l + dx, box.r + dx, box.t + dy, box.b + dy)
    end

    -- `l`, `r`, `t`, `b` reaching `entry`'s extra (its name row) further
    -- out, and its border round that; nothing when it has no size.
    local function Bordered(entry, l, r, t, b)
        local extra = entry.opts.extra
        if extra then
            local frame = entry.frame
            local k = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
            local el, er, et, eb = extra()
            l, r = l - (el or 0) * k, r + (er or 0) * k
            t, b = t + (et or 0) * k, b - (eb or 0) * k
        end
        if r - l <= 0 or t - b <= 0 then return end
        return l - BORDER, r + BORDER, t + BORDER, b - BORDER
    end

    -- What shows of a piece: its frame and parts, how far it reaches, and
    -- its border round all that - as its four edges (BoxEdges: no table, for
    -- what asks every frame), or a box (Box).
    local function BoxEdges(entry)
        local l, r, t, b = Rect(entry.frame)
        if not l then return end
        if entry.opts.parts then
            for _, part in ipairs(entry.opts.parts() or {}) do
                if part:IsVisible() then
                    local pl, pr, pt, pb = Rect(part)
                    if pl then
                        l, r = math.min(l, pl), math.max(r, pr)
                        t, b = math.max(t, pt), math.min(b, pb)
                    end
                end
            end
        end
        return Bordered(entry, l, r, t, b)
    end

    local function Box(entry)
        local l, r, t, b = BoxEdges(entry)
        if l then return NewBox(l, r, t, b) end
    end
    Snap.Box = Box

    -- What an anchor is measured by: the frame, how far it reaches and its
    -- border - not its parts, which come and go (the cooldowns' bars, the
    -- party's other members), so what hangs from it, or it from another,
    -- never moves for one showing or hiding. (Edges, or a box, as above.)
    local function AnchorEdges(entry)
        local l, r, t, b = Rect(entry.frame)
        if not l then return end
        return Bordered(entry, l, r, t, b)
    end

    function AnchorBox(entry)
        local l, r, t, b = AnchorEdges(entry)
        if l then return NewBox(l, r, t, b) end
    end
    Snap.AnchorBox = AnchorBox

    -- What a piece hangs from: one of the addon's pieces, or a screen edge
    -- (edges, or a box).
    local function ParentEdges(to)
        if edgeByKey[to] then
            local width, height = GetScreenWidth(), GetScreenHeight()
            if to == "SCREEN_LEFT" then return -1, 0, height, 0 end
            if to == "SCREEN_RIGHT" then return width, width + 1, height, 0 end
            if to == "SCREEN_TOP" then return 0, width, height + 1, height end
            return 0, width, 0, -1
        end
        local entry = byId[to]
        if entry then return AnchorEdges(entry) end
    end

    function ParentBox(to)
        local l, r, t, b = ParentEdges(to)
        if l then return NewBox(l, r, t, b) end
    end

    ---------------------------------------------------------------------------
    -- THE GAME'S OWN FRAMES: every Edit Mode system the game has (its
    -- manager's list, read only) that is on screen and not one the addon
    -- stands in for (Core.HoldEditMode). Not moved here: Options\Unlock.lua
    -- lays a box over each that hands over to the game's Edit Mode.
    ---------------------------------------------------------------------------

    -- The raid frames hidden (no raid up): their box all the same, where the
    -- game has them, at the size they took when last seen
    -- (ActionBars\GameFrames.lua, GF.RaidBox) - so they can be handed to the
    -- game's Edit Mode from Unlock Mode at any time, as the quest tracker can.
    local function RaidResting(system)
        if system ~= _G.CompactRaidFrameContainer then return false end
        local ok, shown = pcall(system.IsVisible, system)
        return not (ok and shown)
    end

    -- The damage meter hidden by its own Visibility (In Combat, In Group) out
    -- of a fight or a group: its box all the same, where the game keeps it
    -- (the player, 2026-10-06: "show damage meter in our unlock mode too
    -- similar to raid frames") - so it can be handed to the game's Edit Mode
    -- at any time. Not when it is switched off (Options > Advanced: Enable
    -- Damage Meter) or not to be had here.
    local function MeterResting(system)
        if system ~= _G.DamageMeter then return false end
        local ok, shown = pcall(system.IsVisible, system)
        if ok and shown then return false end
        local enabled = (_G.C_CVar and _G.C_CVar.GetCVarBool) or _G.GetCVarBool
        if enabled and not enabled("damageMeterEnabled") then return false end
        local meter = _G.C_DamageMeter
        if meter and meter.IsDamageMeterAvailable then
            local fine, available = pcall(meter.IsDamageMeterAvailable)
            if fine and not available then return false end
        end
        return true
    end

    function Snap.GameSystems()
        local manager = _G.EditModeManagerFrame
        local systems = type(manager) == "table" and manager.registeredSystemFrames
        local list = {}
        if type(systems) ~= "table" then return list end
        for _, system in ipairs(systems) do
            if type(system) == "table" and not (Core.IsHeld and Core.IsHeld(system))
               and type(system.IsVisible) == "function" then
                local ok, shown = pcall(system.IsVisible, system)
                local seen, alpha = pcall(system.GetEffectiveAlpha, system)
                if ok and shown and (not seen or type(alpha) ~= "number" or alpha > 0.01) then
                    list[#list + 1] = system
                elseif (RaidResting(system) or MeterResting(system)) and Snap.SystemBox(system) then
                    list[#list + 1] = system
                end
            end
        end
        return list
    end

    -- Where one of them is: its Edit Mode box (Selection), or the frame.
    function Snap.SystemBox(system)
        if MeterResting(system) then
            -- Hidden, but still placed and sized where the game has it.
            local ok, l, r, t, b = pcall(Rect, system)
            if ok and l and r - l > 0 and t - b > 0 then return NewBox(l, r, t, b) end
            return
        end
        if RaidResting(system) then
            local game = Core.GameFrames
            local l, r, t, b
            if game and game.RaidBox then l, r, t, b = game.RaidBox() end
            if l and r - l > 0 and t - b > 0 then return NewBox(l, r, t, b) end
            return
        end
        for _, region in ipairs({ system.Selection, system }) do
            if type(region) == "table" and type(region.GetLeft) == "function" then
                local ok, l, r, t, b = pcall(Rect, region)
                if ok and l and r - l > 0 and t - b > 0 then return NewBox(l, r, t, b) end
            end
        end
    end

    -- What the game calls it (its Edit Mode window's title for it).
    function Snap.SystemName(system)
        if type(system.GetSystemName) == "function" then
            local ok, name = pcall(system.GetSystemName, system)
            if ok and type(name) == "string" and name ~= "" then return name end
        end
        local name = type(system.GetName) == "function" and system:GetName()
        return type(name) == "string" and name or "?"
    end

    ---------------------------------------------------------------------------
    -- SNAPPING (EllesmereUI's SnapPosition): while a piece is dragged, the
    -- ONE piece nearest it - edge to edge, however far - or the one picked
    -- as its snap target. Of the three pairs of edges and middles across
    -- (left, middle, right against left, middle, right) the closest within
    -- 6 units is met exactly, and so up and down; each way on its own.
    -- Never the piece itself, what hangs from it, what hangs from the same
    -- piece as it, its own group, or a piece hidden for now. Snap Elements
    -- off, or its snap target None: nothing.
    ---------------------------------------------------------------------------

    local hiddenForNow = setmetatable({}, { __mode = "k" })
    local snapTargets = {}      -- entry -> an id, or "_disable_" (None); this Unlock Mode only

    function Snap.Rules()
        local db = Snap.db or Snap.defaults
        return db.snap and true or false
    end

    -- What hangs from the same piece as `entry`.
    local function Siblings(entry)
        local set = {}
        local to = LinkOf(entry.opts.id)
        if not to then return set end
        for childId in pairs(Snaps()) do
            local child = byId[childId]
            if child and child ~= entry and LinkOf(childId) == to then set[child] = true end
        end
        return set
    end

    local function Shown(entry)
        return entry.frame:IsVisible() and not hiddenForNow[entry]
    end

    -- The piece `entry` snaps to at `box`: its snap target, else the one
    -- nearest.
    local function SnapTarget(entry, box)
        local wanted = snapTargets[entry]
        if wanted == "_disable_" then return end
        if wanted and byId[wanted] and byId[wanted] ~= entry and Shown(byId[wanted]) then
            return byId[wanted]
        end
        local _, below = Followers(entry)
        local siblings = Siblings(entry)
        local best, bestD
        for _, other in ipairs(entries) do
            if other ~= entry and Shown(other) and not below[other] and not siblings[other]
               and (entry.opts.group == nil or other.opts.group ~= entry.opts.group) then
                local oL, oR, oT, oB = BoxEdges(other)
                if oL then
                    local gx = math.max(0, oL - box.r, box.l - oR)
                    local gy = math.max(0, oB - box.t, box.b - oT)
                    local d = math.sqrt(gx * gx + gy * gy)
                    if not bestD or d < bestD then best, bestD = other, d end
                end
            end
        end
        return best
    end

    -- Where `box` snaps: { dx, dy, x = the line across, y = the line up and
    -- down (each where it met), target = the piece it snapped by }.
    local function SnapPosition(entry, box)
        local result = { dx = 0, dy = 0 }
        if not Snap.Rules() then return result end
        local function Closest(mine, theirs, bestDelta, at)
            for _, a in ipairs(mine) do
                for _, b in ipairs(theirs) do
                    local delta = a - b
                    if math.abs(delta) < Snap.SNAP_THRESH and (not bestDelta or math.abs(delta) < math.abs(bestDelta)) then
                        bestDelta, at = delta, b
                    end
                end
            end
            return bestDelta, at
        end
        local ddx, x, ddy, y
        local target = SnapTarget(entry, box)
        result.target = target
        local o = target and Box(target)
        if o then
            ddx, x = Closest({ box.l, box.cx, box.r }, { o.l, o.cx, o.r })
            ddy, y = Closest({ box.t, box.cy, box.b }, { o.t, o.cy, o.b })
        end
        -- THE SCREEN'S MIDDLE LINES, both ways (the player, 2026-10-03: "we
        -- can snap elements to X center but we need same with Y center"): a
        -- piece's middle pulled onto the screen's, whichever is nearer when
        -- a piece's line is in reach too.
        local pieceDx, pieceDy = ddx, ddy
        ddx, x = Closest({ box.cx }, { GetScreenWidth() / 2 }, ddx, x)
        ddy, y = Closest({ box.cy }, { GetScreenHeight() / 2 }, ddy, y)
        result.screenX = ddx ~= pieceDx or nil     -- (by the screen's middle, not a piece)
        result.screenY = ddy ~= pieceDy or nil
        if ddx then result.dx, result.x = -ddx, x end
        if ddy then result.dy, result.y = -ddy, y end
        return result
    end

    -- The pull for a piece where it is now.
    function Snap.Find(entry)
        local box = Box(entry)
        if not box then return { dx = 0, dy = 0 } end
        return SnapPosition(entry, box)
    end

    -- Its snap target: an id, "_disable_" (None), or nothing (the nearest).
    function Snap.SetSnapTarget(entry, id)
        if entry then snapTargets[entry] = id end
    end

    -- The UI unlocked.
    local function Unlocked()
        return Core.IsUnlocked and Core.IsUnlocked() or false
    end

    ---------------------------------------------------------------------------
    -- THE GUIDES while dragging (EllesmereUI's ShowAlignmentGuides): a line a
    -- real pixel wide across the whole screen, in the addon's gold at half,
    -- along each edge or middle that met.
    ---------------------------------------------------------------------------

    local guides

    local function Pixel()
        local _, physicalHeight = GetPhysicalScreenSize()
        if not physicalHeight or physicalHeight <= 0 then return 1 end
        return GetScreenHeight() / physicalHeight
    end
    Snap.Pixel = Pixel

    local function Guides()
        if guides then return guides end
        guides = CreateFrame("Frame", Core.ADDON_NAME .. "SnapGuides", UIParent)
        guides:SetAllPoints(UIParent)
        guides:SetFrameStrata("TOOLTIP")
        guides:EnableMouse(false)
        -- x, y: where a dragged piece meets (SnapPosition); cx, cy: the
        -- screen's own middle lines (ShowCentreLines), brighter.
        for _, axis in ipairs({ "x", "y", "cx", "cy" }) do
            local line = guides:CreateTexture(nil, "OVERLAY", nil, 6)
            local gold = Style.GOLD
            local centre = axis == "cx" or axis == "cy"
            line:SetColorTexture(gold[1], gold[2], gold[3], centre and 0.9 or 0.5)
            -- Laid on whole screen pixels below, so the game's own snapping
            -- of a texture to the pixel grid is not wanted on top of it.
            if line.SetSnapToPixelGrid then line:SetSnapToPixelGrid(false) end
            if line.SetTexelSnappingBias then line:SetTexelSnappingBias(0) end
            line:Hide()
            guides[axis] = line
        end
        Snap.guides = guides
        return guides
    end

    -- One real screen pixel in UIParent's units - what the grid lays its own
    -- lines on (DogsForeverUI.lua, OnePixel).
    local function PixelUnit()
        if PixelUtil and PixelUtil.GetPixelToUIUnitFactor then
            local scale = UIParent:GetEffectiveScale()
            if type(scale) == "number" and scale > 0 then
                return PixelUtil.GetPixelToUIUnitFactor() / scale
            end
        end
        return Pixel()
    end

    -- A line across the whole screen at `at` (x down it, or y along it, in
    -- UIParent's units, y up), `pixels` real pixels thick. ON WHOLE PIXELS,
    -- from the screen's top left as the grid's are: a line one pixel thick
    -- centred on a point halfway between two pixels - the screen's very
    -- middle, as it happens - came out zero pixels wide, or one, as the
    -- game snapped its two edges: the centre lines that showed "kinda", or
    -- not at all (the player, 2026-10-03).
    local function OnPixel(v, px) return math.floor(v / px + 0.5) * px end

    local function ShowLine(line, vertical, at, pixels)
        if not at then
            line:Hide()
            return
        end
        pixels = pixels or 1
        local px = PixelUnit()
        local thick = pixels * px
        local lead = math.floor(pixels / 2) * px          -- so the line is centred on `at`
        local width, height = GetScreenWidth(), GetScreenHeight()
        line:ClearAllPoints()
        if vertical then
            line:SetPoint("TOPLEFT", UIParent, "TOPLEFT", OnPixel(at, px) - lead, 0)
            line:SetSize(thick, height)
        else
            line:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -(OnPixel(height - at, px) - lead))
            line:SetSize(width, thick)
        end
        line:Show()
    end

    local function HideLines()
        if not guides then return end
        guides.x:Hide()
        guides.y:Hide()
    end

    -- THE SCREEN'S MIDDLE LINES, over everything (the player, 2026-10-03,
    -- three times: "show the horizontal line like the vertical one"). The
    -- grid's own middle lines are under the movers: the vertical one showed
    -- above and below a piece in the middle while the horizontal one, right
    -- behind that same piece, did not. So both are drawn again over every
    -- mover, in the snap lines' gold, the whole time Unlock Mode is open -
    -- the cross always there, never one line without the other. `entry`
    -- nil: none (previewing, or Unlock Mode closed).
    --
    -- ONLY WHILE A PIECE IS ON THEM (the player, 2026-10-03, after the lines
    -- finally drew: "visible only if the selected frame is snapped to
    -- them"): the line down the screen's middle while the piece being
    -- dragged - or else the selected one - has its middle there across, the
    -- line along it while it has it there up and down; each on its own.
    -- (Within a unit: the game puts a frame on whole screen pixels.)
    local CENTRE_PIXELS, CENTRED = 2, 1
    local function ShowCentreLines(entry)
        local l, r, t, b
        if entry then l, r, t, b = BoxEdges(entry) end
        if not l and not guides then return end
        local g = Guides()
        if l and not g:IsShown() then g:Show() end
        local x, y = GetScreenWidth() / 2, GetScreenHeight() / 2
        local onX = l and math.abs((l + r) / 2 - x) < CENTRED
        local onY = l and math.abs((t + b) / 2 - y) < CENTRED
        ShowLine(g.cx, true, onX and x or nil, CENTRE_PIXELS)
        ShowLine(g.cy, false, onY and y or nil, CENTRE_PIXELS)
    end

    ---------------------------------------------------------------------------
    -- Dragging.
    ---------------------------------------------------------------------------

    local drag      -- the drag under way
    local Select    -- below
    local Refuse    -- below
    local picking   -- { entry, axis } while a match, anchor or snap target waits for its piece
    local IN_COMBAT = "Can't be moved in combat."

    local function Cursor()
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        return x / scale, y / scale
    end

    -- What moves when a piece moves: the frame, and whatever goes with it
    -- (the party's other three) - each with where it started, in UIParent's
    -- units.
    local function Movers(entry)
        local list, seen = {}, {}
        local function Add(frame)
            if seen[frame] then return end
            seen[frame] = true
            local left, _, _, bottom = Rect(frame)
            if left then list[#list + 1] = { frame = frame, left = left, bottom = bottom } end
        end
        Add(entry.frame)
        if entry.opts.moveWith then
            for _, frame in ipairs(entry.opts.moveWith() or {}) do Add(frame) end
        end
        return list
    end

    -- In combat: a piece the game protects stays put.
    local function Blocked(movers)
        if not InCombatLockdown() then return false end
        for _, mover in ipairs(movers) do
            local frame = mover.frame
            if frame.IsProtected and frame:IsProtected() then return true end
        end
        return false
    end

    -- A frame put with its bottom left at `x`, `y` (UIParent's units).
    local function PutAt(frame, x, y)
        local k = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x * k, y * k)
    end

    -- Everything that moves, `dx`, `dy` from where it started.
    local function MoveAll(movers, dx, dy)
        if Blocked(movers) then return false end
        for _, mover in ipairs(movers) do
            PutAt(mover.frame, mover.left + dx, mover.bottom + dy)
        end
        return true
    end

    -- Kept on screen whole, border and all.
    local function OnScreen(box)
        local width, height = GetScreenWidth(), GetScreenHeight()
        local dx, dy = 0, 0
        if box.r - box.l <= width then
            if box.l < 0 then dx = -box.l elseif box.r > width then dx = width - box.r end
        end
        if box.t - box.b <= height then
            if box.b < 0 then dy = -box.b elseif box.t > height then dy = height - box.t end
        end
        return Shifted(box, dx, dy)
    end

    ---------------------------------------------------------------------------
    -- FOLLOWING: every anchored piece put where its anchor says, from where
    -- what it hangs from is now - every frame, locked or not (the player,
    -- 2026-10-02: "anchored elements should be moving with the parent
    -- element"), each kept through its own save. (A piece the game protects
    -- waits out combat.)
    ---------------------------------------------------------------------------

    local unsaved = {}      -- pieces moved by following, not saved yet
    local SETTLED = 0.5     -- closer than this is where it should be

    -- One piece put where its anchor says. Answers whether it moved. (Asked
    -- every frame: measured as numbers, no table made while nothing moves.)
    local function Place(entry)
        local id = entry.opts.id
        local to, link = LinkOf(id)
        if not to then return false end
        -- Being dragged itself: it goes where the mouse takes it.
        if drag and drag.entry.opts.id == id then return false end
        local ml, mr, mt, mb = AnchorEdges(entry)
        local pl, pr, pt, pb = ParentEdges(to)
        if not (ml and pl) then return false end
        -- Measured by the old, whole box: taken again from where it is now
        -- (nothing moves) - see ANCHOR_BOX.
        if link.box ~= ANCHOR_BOX then
            HangFrom(entry, to, link.point, link.rel, NewBox(ml, mr, mt, mb))
            return false
        end
        local px, py = PointAt(link.rel, pl, pr, pt, pb)
        local mx, my = PointAt(link.point, ml, mr, mt, mb)
        local dx, dy = px + (link.x or 0) - mx, py + (link.y or 0) - my
        if math.abs(dx) < SETTLED and math.abs(dy) < SETTLED then return false end
        if not MoveAll(Movers(entry), dx, dy) then return false end
        unsaved[entry] = true
        return true
    end

    -- Every piece that hangs from another, parents before children: a chain
    -- settles in as many passes as it is long. Answers whether any moved.
    local function FollowAll()
        local moved = false
        for _ = 1, 6 do
            local any = false
            for childId in pairs(Snaps()) do
                local child = byId[childId]
                if child and Place(child) then any = true end
            end
            if not any then break end
            moved = true
        end
        return moved
    end

    -- What following moved, kept - once it has come to rest and nothing is
    -- being dragged.
    local function SaveFollowed()
        if drag then return end
        local any = false
        for entry in pairs(unsaved) do
            unsaved[entry] = nil
            if entry.opts.save then entry.opts.save() end
            any = true
        end
        if any and Core.EditModeMoved then Core.EditModeMoved() end
    end

    -- A revert put every place and anchor back at once: nothing to keep.
    function Snap.ForgetGameFrames()
        for entry in pairs(unsaved) do unsaved[entry] = nil end
    end

    local following = CreateFrame("Frame")
    following:SetScript("OnUpdate", function()
        if next(Snaps()) == nil then return end
        if not FollowAll() then SaveFollowed() end
    end)

    local function Follow()
        if not drag then return end
        -- The button is up: the piece's mouse-up is on its way, or the drag
        -- ended without one; the piece stays where it last showed.
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            HideLines()
            return
        end
        local x, y = Cursor()
        local dx, dy = x - drag.x, y - drag.y
        if not drag.moved then
            local reach = Snap.THRESHOLD / UIParent:GetEffectiveScale()
            if dx * dx + dy * dy < reach * reach then return end
            drag.moved = true
            -- A drag selects (EllesmereUI's OnDragStart).
            Select(drag.entry)
        end
        -- SHIFT HELD: along one line only - the way the mouse has gone
        -- further, once it has gone 3 units; let go of Shift and it moves
        -- freely again.
        if IsShiftKeyDown and IsShiftKeyDown() then
            if not drag.axis and (math.abs(dx) > 3 or math.abs(dy) > 3) then
                drag.axis = math.abs(dx) >= math.abs(dy) and "x" or "y"
            end
            if drag.axis == "x" then dy = 0 elseif drag.axis == "y" then dx = 0 end
        else
            drag.axis = nil
        end

        local box = Shifted(drag.box, dx, dy)
        local snap = SnapPosition(drag.entry, box)
        box = OnScreen(Shifted(box, snap.dx, snap.dy))
        MoveAll(drag.movers, box.l - drag.box.l, box.b - drag.box.b)
        drag.at, drag.snap = box, snap
        local g = Guides()
        ShowLine(g.x, true, snap.x)
        ShowLine(g.y, false, snap.y)
        -- What hangs from it comes along in the same frame.
        FollowAll()
    end

    -- In place of frame:StartMoving(): a press - a drag if the mouse moves.
    -- While a match, an anchor or a snap target waits for its piece, the
    -- press picks this one instead.
    function Snap.Start(frame)
        -- (Previewing: nothing is picked up.)
        if Snap.Previewing and Snap.Previewing() then return end
        local entry = byFrame[frame]
        if not entry then
            frame:StartMoving()
            return
        end
        if picking then
            local pick = picking
            if entry == pick.entry then
                -- The piece that is picking: picking stops.
                Snap.StopPicking()
                return
            end
            Snap.StopPicking()
            local ok, why = Snap.Picked(pick, entry)
            if not ok and why then Refuse(entry, why) end
            return
        end
        local box = Box(entry)
        -- Not laid out yet: dragged the game's way.
        if not box or not Rect(frame) then
            frame:StartMoving()
            return
        end
        local movers = Movers(entry)
        -- One the game protects, in combat: it stays put - and says so.
        if Blocked(movers) then
            Refuse(entry, IN_COMBAT)
            return
        end
        local x, y = Cursor()
        drag = { entry = entry, frame = frame, box = box, movers = movers,
                 x = x, y = y, moved = false }
        local g = Guides()
        g:SetScript("OnUpdate", Follow)
        g:Show()
    end

    -- In place of frame:StopMovingOrSizing(). The piece is already where it
    -- shows; answers whether it was moved at all (a click is not a drag).
    function Snap.Stop(frame)
        if not drag or drag.frame ~= frame then
            if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
            return false
        end
        Follow()            -- the last bit of movement before the button rose
        local moved = drag.moved
        local entry = drag.entry
        if moved then
            -- Anchored: still anchored, at the offset it was dragged to.
            MovedByHand(entry)
            if Core.EditModeMoved then Core.EditModeMoved() end
        end
        drag = nil
        HideLines()
        if guides then guides:SetScript("OnUpdate", nil) end
        if moved then FollowAll() end
        return moved
    end

    function Snap.IsDragging() return drag ~= nil end
    function Snap.DragSnapTarget() return drag and drag.moved and drag.snap and drag.snap.target or nil end

    ---------------------------------------------------------------------------
    -- THE SELECTED PIECE (EllesmereUI's SelectMover): clicked, or dragged.
    -- The arrow keys move it a real pixel at a time, Shift 100; every other
    -- key goes on to the game. Clicking it again lets go of it, and so does a
    -- click on empty space (Options\Unlock.lua, the player, 2026-10-03). (A
    -- frame cannot choose in combat which keys it keeps: none then.)
    ---------------------------------------------------------------------------

    local selected, keys

    local function KeysOn()
        keys:EnableKeyboard(selected ~= nil and Unlocked() and not InCombatLockdown())
    end

    local function Keys()
        if keys then return keys end
        keys = CreateFrame("Frame", Core.ADDON_NAME .. "SnapKeys", UIParent)
        keys:EnableMouse(false)
        keys:SetScript("OnKeyDown", function(self, key)
            if InCombatLockdown() then return end
            local step = Pixel() * ((IsShiftKeyDown and IsShiftKeyDown()) and 100 or 1)
            local dx, dy
            if key == "UP" then dx, dy = 0, step
            elseif key == "DOWN" then dx, dy = 0, -step
            elseif key == "LEFT" then dx, dy = -step, 0
            elseif key == "RIGHT" then dx, dy = step, 0
            end
            if dx then
                self:SetPropagateKeyboardInput(false)
                Snap.Nudge(dx, dy)
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)
        keys:SetScript("OnKeyUp", function(self)
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
        end)
        keys:SetScript("OnEvent", function() KeysOn() end)
        keys:RegisterEvent("PLAYER_REGEN_DISABLED")
        keys:RegisterEvent("PLAYER_REGEN_ENABLED")
        Snap.keys = keys
        return keys
    end

    -- WHERE IT IS, in numbers: the piece's top left from the screen's top
    -- left in UI units, y negative going down - the numbers the options'
    -- Positions rows show.
    function Snap.PositionOf(entry)
        local left, _, top = Rect(entry.frame)
        if not left then return end
        return left, top - GetScreenHeight()
    end

    local function Whole(value)
        return value >= 0 and math.floor(value + 0.5) or -math.floor(-value + 0.5)
    end
    Snap.Whole = Whole

    -- Options\Unlock.lua replaces this: the selection, a pick or what it
    -- waits for changed (the cog menu kept up, the dimmer for a pick).
    function Snap.SelectionChanged() end

    function Select(entry)
        selected = entry
        KeysOn()
        Snap.SelectionChanged()
    end

    function Snap.Select(entry)
        Keys()
        Select(entry)
    end

    function Snap.Deselect()
        local was = selected
        selected = nil
        if keys then KeysOn() end
        if was then Snap.SelectionChanged() end
    end

    function Snap.Selected() return selected and selected.frame end
    function Snap.SelectedEntry() return selected end

    -- A piece moved `dx`, `dy` UI units, and saved there, exactly as pushed
    -- (anchored: at the new offset).
    local function MoveBy(entry, dx, dy)
        local box = Box(entry)
        if not box then return false end
        local placed = OnScreen(Shifted(box, dx, dy))
        if not MoveAll(Movers(entry), placed.l - box.l, placed.b - box.b) then
            Refuse(entry, IN_COMBAT)
            return false
        end
        MovedByHand(entry)
        if Core.EditModeMoved then Core.EditModeMoved() end
        if entry.opts.save then entry.opts.save() end
        FollowAll()
        return true
    end

    -- For the addon's own default layout (Core\DefaultPlaces.lua): a piece
    -- moved by so much, kept there (and anchored at the new offset if it is),
    -- and where its frame is, in UIParent's units.
    function Snap.Shift(entry, dx, dy)
        if not entry or drag then return false end
        if math.abs(dx) < 0.01 and math.abs(dy) < 0.01 then return true end
        return MoveBy(entry, dx, dy)
    end
    function Snap.FrameRect(entry)
        if entry then return Rect(entry.frame) end
    end

    -- The selected piece, by the arrow keys.
    function Snap.Nudge(dx, dy)
        local entry = selected
        if not entry or drag then return false end
        return MoveBy(entry, dx, dy)
    end

    -- Typed into its menu: its top left to `x`, `y` (Snap.PositionOf's
    -- numbers; nil keeps that one).
    function Snap.MoveTo(entry, x, y)
        local left, top = Snap.PositionOf(entry)
        if not left or drag then return false end
        return MoveBy(entry, (x or left) - left, (y or top) - top)
    end

    -- Center on Screen: its middle on the screen's middle, BOTH ways (the
    -- player, 2026-10-03 - EllesmereUI's did left to right only).
    function Snap.CentreOnScreen(entry)
        local box = Box(entry)
        if not box or drag then return false end
        return MoveBy(entry, GetScreenWidth() / 2 - box.cx, GetScreenHeight() / 2 - box.cy)
    end

    -- Unlock Mode closed: whatever is being dragged stays where it is,
    -- nothing is selected or picking, and the session's choices go.
    function Snap.Cancel()
        drag = nil
        HideLines()
        if guides then guides:SetScript("OnUpdate", nil) end
        picking = nil
        Snap.Deselect()
        for key in pairs(snapTargets) do snapTargets[key] = nil end
        FollowAll()
        SaveFollowed()
    end

    ---------------------------------------------------------------------------
    -- REFUSED (EllesmereUI's FlashRedBorder and its cursor tooltip): the
    -- piece's outline red for 1.5 s - and the reason at the cursor for 3 s.
    ---------------------------------------------------------------------------

    local REFUSE_FADE, REFUSE_TIP = 1.5, 3
    local REFUSE_COLOR = { 1, 0.2, 0.2 }
    local refusal

    local function DrawRefusal(self)
        local t = GetTime() - self.started
        if t >= REFUSE_TIP then
            self:Hide()
            return
        end
        -- Steady, then gone (nothing animated in Unlock Mode).
        local alpha = t < REFUSE_FADE and 1 or 0
        for _, side in ipairs({ "top", "bottom", "left", "right" }) do self[side]:SetAlpha(alpha) end
    end

    function Refuse(entry, why)
        if not refusal then
            refusal = CreateFrame("Frame", Core.ADDON_NAME .. "SnapRefusal", UIParent)
            refusal:SetFrameStrata("TOOLTIP")
            refusal:EnableMouse(false)
            for _, side in ipairs({ "top", "bottom", "left", "right" }) do
                local line = refusal:CreateTexture(nil, "OVERLAY")
                line:SetColorTexture(REFUSE_COLOR[1], REFUSE_COLOR[2], REFUSE_COLOR[3], 1)
                refusal[side] = line
            end
            refusal:SetScript("OnUpdate", DrawRefusal)
            refusal:SetScript("OnHide", function(self)
                local tooltip = GameTooltip
                if tooltip and tooltip.GetOwner and tooltip:GetOwner() == self then tooltip:Hide() end
            end)
            Snap.refusal = refusal
        end
        local box = entry and Box(entry)
        local thick = 2 * Pixel()
        refusal:ClearAllPoints()
        if box then
            refusal:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", box.l, box.b)
            refusal:SetSize(box.r - box.l, box.t - box.b)
        else
            refusal:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            refusal:SetSize(1, 1)
        end
        for _, side in ipairs({ "top", "bottom" }) do
            refusal[side]:ClearAllPoints()
            refusal[side]:SetPoint(side:upper() .. "LEFT", refusal, side:upper() .. "LEFT", 0, 0)
            refusal[side]:SetPoint(side:upper() .. "RIGHT", refusal, side:upper() .. "RIGHT", 0, 0)
            refusal[side]:SetHeight(thick)
            refusal[side]:SetShown(box ~= nil)
        end
        for _, side in ipairs({ "left", "right" }) do
            refusal[side]:ClearAllPoints()
            refusal[side]:SetPoint("TOP" .. side:upper(), refusal, "TOP" .. side:upper(), 0, 0)
            refusal[side]:SetPoint("BOTTOM" .. side:upper(), refusal, "BOTTOM" .. side:upper(), 0, 0)
            refusal[side]:SetWidth(thick)
            refusal[side]:SetShown(box ~= nil)
        end
        refusal.started = GetTime()
        refusal.why = why
        refusal:Show()
        DrawRefusal(refusal)
        local tooltip = GameTooltip
        if why and tooltip then
            tooltip:SetOwner(refusal, "ANCHOR_CURSOR")
            tooltip:SetText(why, 1, 1, 1)
            tooltip:Show()
        end
    end
    Snap.Refuse = function(entry, why) Refuse(entry, why) end

    ---------------------------------------------------------------------------
    -- SIZES, AND ONE PIECE'S SIZE MATCHING ANOTHER'S (EllesmereUI's W Match /
    -- H Match). A piece with a size of its own - the options' Sizes rows, set
    -- exactly as they set them - can take its width or height from another
    -- piece, give or take a few units (Extra Width / Height).
    --
    -- Kept as placing.matches = { [piece id] = { w = the other's id, wx =
    -- extra, h = ..., hx = ... } }: saved and reverted with the places, and
    -- in profiles. Whenever a piece changes size for any reason, whatever
    -- matches it is sized again the next frame. Never in combat.
    ---------------------------------------------------------------------------

    local AXES = { "w", "h" }
    local AXIS_WORD = { w = "width", h = "height" }
    Snap.AXIS_WORD = AXIS_WORD

    -- Each piece with a size of its own, as its Sizes row in the options has
    -- it (Options\Pages.lua): the setting, what else a new value moves, and
    -- whether it leaves a bar the addon places itself where it is. The unit
    -- frames share one width, so none of them has its own; the party's
    -- column does.
    local SIZED = { "castbar", "swing", "fsr", "combo", "xp", "cooldowns", "threat", "toasts", "party" }
    -- Sized where they are, by their module's barWidth and barHeight.
    local PLAIN_SIZED = { cooldowns = "Cooldowns", threat = "Threat", toasts = "LootToasts" }

    local function SizeSpec(id)
        local Castbar, FSR, Combo = Core.Castbar, Core.FiveSecondRule, Core.ComboPoints
        local XP, Frames = Core.XPBar, Core.Frames
        local Plain = PLAIN_SIZED[id] and Core[PLAIN_SIZED[id]]
        local function Own(module) return function() return module.db end end
        if id == "castbar" and Castbar then
            return { module = Castbar,
                     w = { key = "barWidth", onChange = Castbar.WidthChanged },
                     h = { key = "barHeight" } }
        elseif id == "swing" and Castbar then
            return { module = Castbar,
                     w = { key = "swingWidth", keepsPlacement = true,
                           onChange = Castbar.KeepCentred(Own(Castbar), "swingPlaced", "swingLeft") } }
        elseif (id == "fsr" and FSR or id == "combo" and Combo) and Castbar then
            local module = id == "fsr" and FSR or Combo
            return { module = module,
                     w = { key = "barWidth", onChange = Castbar.KeepCentred(Own(module), "placed", "barLeft") },
                     h = { key = "barHeight" } }
        elseif id == "xp" and XP and Castbar then
            return { module = XP, w = { key = "barWidth", onChange = Castbar.KeepCentred(Own(XP), nil, "barLeft") },
                     h = { key = "barHeight" } }
        elseif Plain then
            return { module = Plain,
                     w = { key = "barWidth", keepsPlacement = true },
                     h = { key = "barHeight", keepsPlacement = true } }
        elseif id == "party" and Frames then
            return { module = Frames, w = { key = "partyWidth" } }
        end
    end

    -- Every size setting of one module's pieces: reverted with the places
    -- (DogsForeverUI.lua).
    function Snap.SizeKeys(module)
        local keys = {}
        for _, id in ipairs(SIZED) do
            local spec = SizeSpec(id)
            if spec and spec.module == module then
                for _, axis in ipairs(AXES) do
                    if spec[axis] then keys[spec[axis].key] = true end
                end
            end
        end
        return keys
    end

    -- Whether a piece has a width ("w") or height ("h") of its own, and what.
    function Snap.SizeOf(entry, axis)
        local spec = entry and SizeSpec(entry.opts.id)
        local size = spec and spec[axis]
        if not size then return end
        return spec.module.db[size.key]
    end

    Snap.SIZE_MIN, Snap.SIZE_MAX = 1, 4000

    -- Set as its Sizes box in the options sets it. Answers whether it
    -- changed.
    function Snap.SetSize(entry, axis, value)
        local spec = entry and SizeSpec(entry.opts.id)
        local size = spec and spec[axis]
        if not size or type(value) ~= "number" then return false end
        value = math.max(Snap.SIZE_MIN, math.min(Snap.SIZE_MAX, Whole(value)))
        local module = spec.module
        local db = module.db
        local old = db[size.key]
        if old == value then return false end
        db[size.key] = value
        if size.onChange then size.onChange(old, value) end
        if db.autoPlaced ~= nil and not size.keepsPlacement then db.autoPlaced = false end
        if module.Refresh then module.Refresh() end
        if Core.RefreshOptions then Core.RefreshOptions() end
        if Core.EditModeMoved then Core.EditModeMoved() end
        return true
    end

    local function Matches()
        local db = Snap.db
        if type(db) ~= "table" then return {} end
        if type(db.matches) ~= "table" then db.matches = {} end
        return db.matches
    end

    -- The id of the piece `entry` takes its width / height from, and the
    -- extra; nothing when it takes it from none.
    function Snap.MatchOf(entry, axis)
        local id = entry and entry.opts.id
        local match = id and Matches()[id]
        if type(match) ~= "table" or type(match[axis]) ~= "string" then return end
        return match[axis], tonumber(match[axis .. "x"]) or 0
    end

    -- Whether `targetId` already takes that size from `childId`, however
    -- far round.
    local function WouldCircle(childId, targetId, axis)
        local id = targetId
        for _ = 1, 32 do
            if id == childId then return true end
            local match = Matches()[id]
            id = type(match) == "table" and match[axis] or nil
            if type(id) ~= "string" then return false end
        end
        return true
    end

    local function Measured(frame, axis)
        local size = axis == "w" and frame:GetWidth() or frame:GetHeight()
        if type(size) ~= "number" or size <= 0 then return end
        return size * frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    end

    local function ApplyMatch(entry, axis)
        local to, extra = Snap.MatchOf(entry, axis)
        local target = to and byId[to]
        if not target then return false end
        local size = Measured(target.frame, axis)
        if not size then return false end
        local k = entry.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        return Snap.SetSize(entry, axis, size / k + extra)
    end

    local waiting = false   -- combat stopped a pass: one more when it ends

    -- Every match, until nothing changes.
    function Snap.ApplyMatches()
        if next(Matches()) == nil then return end
        if InCombatLockdown() then
            waiting = true
            return
        end
        waiting = false
        for _ = 1, 6 do
            local any = false
            for id in pairs(Matches()) do
                local entry = byId[id]
                if entry then
                    for _, axis in ipairs(AXES) do
                        if ApplyMatch(entry, axis) then any = true end
                    end
                end
            end
            if not any then break end
        end
    end

    -- The next frame, once however many sizes changed in this one.
    local MatchSoon, matcher = Core.Waker(Snap.ApplyMatches)
    matcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    matcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    matcher:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" or waiting then MatchSoon() end
    end)

    function Snap.ScheduleMatches()
        if next(Matches()) ~= nil then MatchSoon() end
    end

    -- `entry` takes its width / height from `target`'s from now on, with
    -- no extra. Answers true, or false and why not (EllesmereUI's words).
    function Snap.SetMatch(entry, axis, target)
        local id = entry and entry.opts.id
        local spec = id and SizeSpec(id)
        if not (spec and spec[axis]) then
            return false, "Elements cannot size match to\n" .. NameOf(target)
        end
        local to = target and target.opts.id
        if not to or to == id then
            return false, "Elements cannot size match to\n" .. NameOf(target)
        end
        if WouldCircle(id, to, axis) then
            return false, "This would create a circular " .. AXIS_WORD[axis] .. " match"
        end
        local matches = Matches()
        local match = type(matches[id]) == "table" and matches[id] or {}
        matches[id] = match
        match[axis], match[axis .. "x"] = to, 0
        if Core.EditModeMoved then Core.EditModeMoved() end
        Snap.ApplyMatches()
        Snap.SelectionChanged()
        return true
    end

    -- Its own size again, as it is now.
    function Snap.ClearMatch(entry, axis)
        local id = entry and entry.opts.id
        local match = id and Matches()[id]
        if type(match) ~= "table" or match[axis] == nil then return false end
        match[axis], match[axis .. "x"] = nil, nil
        if next(match) == nil then Matches()[id] = nil end
        if Core.EditModeMoved then Core.EditModeMoved() end
        if Core.RefreshOptions then Core.RefreshOptions() end
        Snap.SelectionChanged()
        return true
    end

    Snap.EXTRA_MIN, Snap.EXTRA_MAX = -100, 100

    function Snap.SetMatchExtra(entry, axis, extra)
        local id = entry and entry.opts.id
        local match = id and Matches()[id]
        if type(match) ~= "table" or match[axis] == nil or type(extra) ~= "number" then return false end
        match[axis .. "x"] = math.max(Snap.EXTRA_MIN, math.min(Snap.EXTRA_MAX, Whole(extra)))
        if Core.EditModeMoved then Core.EditModeMoved() end
        Snap.ApplyMatches()
        return true
    end

    ---------------------------------------------------------------------------
    -- PICKING (EllesmereUI's pick modes): the next piece clicked is the one
    -- to match ("w", "h"), to anchor to ("anchor") or to snap to
    -- ("snaptarget"); the picking piece clicked again, Esc, or the menu
    -- stop it.
    ---------------------------------------------------------------------------

    function Snap.StartPicking(entry, axis)
        if not entry then return false end
        if axis == "anchor" then
            if not entry.opts.id then return false end
        elseif axis == "w" or axis == "h" then
            if Snap.SizeOf(entry, axis) == nil then return false end
        elseif axis ~= "snaptarget" then
            return false
        end
        picking = { entry = entry, axis = axis }
        Snap.SelectionChanged()
        return true
    end

    function Snap.StopPicking()
        if not picking then return end
        picking = nil
        Snap.SelectionChanged()
    end

    function Snap.Picking() return picking end

    local AnchorRefusal     -- below (ANCHORED)

    -- The piece picked for `pick`. Answers true, or false and why not.
    -- Anchored: from exactly where it is (Snap.AnchorHere - the player,
    -- 2026-10-03: no side to choose, "just anchor from current position").
    function Snap.Picked(pick, target)
        local entry = pick.entry
        if pick.axis == "snaptarget" then
            Snap.SetSnapTarget(entry, target.opts.id)
            Snap.SelectionChanged()
            return target.opts.id ~= nil
        elseif pick.axis == "anchor" then
            return Snap.AnchorHere(entry, target)
        end
        return Snap.SetMatch(entry, pick.axis, target)
    end

    ---------------------------------------------------------------------------
    -- RESET POSITION: a piece's place forgotten, so its module places it
    -- again as on a first start - and it is anchored as it starts.
    ---------------------------------------------------------------------------

    local RESETS = {
        castbar   = { "Castbar", "barLeft", "barTop", "autoPlaced" },
        swing     = { "Castbar", "swingPlaced", "swingLeft", "swingBottom" },
        fsr       = { "FiveSecondRule", "placed" },
        combo     = { "ComboPoints", "placed" },
        xp        = { "XPBar", "barLeft", "barTop", "autoPlaced" },
        cooldowns = { "Cooldowns", "barLeft", "barTop", "autoPlaced" },
        threat    = { "Threat", "barLeft", "barTop", "autoPlaced" },
        loot      = { "LootRolls", "barLeft", "barTop", "autoPlaced" },
        toasts    = { "LootToasts", "barLeft", "barTop", "autoPlaced" },
        micro     = { "Menus", "microPlaced" },
        bags      = { "GameFrames", "bagsPlaced", "bagsLeft", "bagsTop" },
    }
    for _, unit in ipairs({ "player", "target", "focus", "targettarget", "pet", "party" }) do
        RESETS[unit] = { "Frames", unit .. "Placed", unit .. "Left", unit .. "Top" }
    end
    -- The action bars: the game's bar's place again (ActionBars\ActionBars.lua).
    -- (By its id in Unlock Mode: the pet bar's is "petbar", its settings'
    -- "pet" - "pet" is the pet's unit frame, above.)
    for _, bar in ipairs({ "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8", "stance", "pet" }) do
        RESETS[bar == "pet" and "petbar" or bar] = { "ActionBars", bar .. "Placed", bar .. "Left", bar .. "Top" }
    end

    function Snap.CanReset(entry)
        return entry ~= nil and RESETS[entry.opts.id] ~= nil
    end

    function Snap.ResetPlace(entry)
        local spec = entry and RESETS[entry.opts.id]
        local module = spec and Core[spec[1]]
        if not (module and module.db) then return false end
        if InCombatLockdown() and entry.frame.IsProtected and entry.frame:IsProtected() then
            Refuse(entry, IN_COMBAT)
            return false
        end
        local db = module.db
        for index = 2, #spec do db[spec[index]] = nil end
        if module.Normalise then module.Normalise(db) end
        LetGo(entry)
        -- Every module laid out again: a bar of the castbar group goes back
        -- into it, the pet back under the player.
        for _, other in ipairs(Core.modules) do
            if other.placement and other.Refresh then
                local ok, err = pcall(other.Refresh)
                if not ok and geterrorhandler then geterrorhandler()(err) end
            end
        end
        if Snap.ReanchorAfterReset then Snap.ReanchorAfterReset(entry) end
        FollowAll()
        if Core.EditModeMoved then Core.EditModeMoved() end
        if Core.RefreshOptions then Core.RefreshOptions() end
        return true
    end

    ---------------------------------------------------------------------------
    -- ANCHORED (EllesmereUI's Anchor and Relative to Screen):
    --
    --   * ANCHOR, then the other piece: anchored from exactly where it is
    --     (Snap.AnchorHere - no side asked, the player, 2026-10-03), and
    --     moving with it from then on, however it moves or is resized.
    --     Dragged, nudged or typed afterwards, it stays anchored at the new
    --     offset (MovedByHand). Not to itself, not into a circle, and not to
    --     a piece two or more steps above it ("This would create a circular
    --     anchor"); Remove Anchor: it stays where it is.
    --   * RELATIVE TO SCREEN: to a screen edge, from exactly where it is -
    --     it keeps its distance to that edge as the screen changes size;
    --     Center lets go of a screen edge.
    ---------------------------------------------------------------------------

    -- side -> this piece's point, on the other's point.
    local SIDES = {
        above = { point = "BOTTOM", rel = "TOP" },
        below = { point = "TOP",    rel = "BOTTOM" },
        left  = { point = "RIGHT",  rel = "LEFT" },
        right = { point = "LEFT",   rel = "RIGHT" },
    }

    -- How far above `entry` the piece `id` is, along what it hangs from (1:
    -- its own anchor; nil: not above it).
    local function DepthAbove(entry, id)
        local current, depth = entry.opts.id, 0
        for _ = 1, 32 do
            local to = LinkOf(current)
            if not to then return nil end
            depth = depth + 1
            if to == id then return depth end
            current = to
        end
    end

    -- Why `entry` cannot be anchored to `target`, or nothing.
    function AnchorRefusal(entry, target)
        if not (entry and entry.opts.id and target and target.opts.id) then
            return "Elements cannot be anchored to\n" .. NameOf(target)
        end
        if target == entry or target.opts.id == entry.opts.id then
            return "An element cannot anchor to itself"
        end
        local _, below = Followers(entry)
        if below[target] then return "This would create a circular anchor" end
        local depth = DepthAbove(entry, target.opts.id)
        if depth and depth >= 2 then return "This would create a circular anchor" end
    end

    -- RELATIVE TO SCREEN: to a screen edge, from where it is.
    function Snap.AnchorToScreen(entry, key)
        local edge = edgeByKey[key]
        local box = entry and AnchorBox(entry)
        if not (edge and box and entry.opts.id) then return false end
        local spec = SIDES[edge.side]
        HangFrom(entry, key, spec.point, spec.rel, box)
        if Core.EditModeMoved then Core.EditModeMoved() end
        Snap.SelectionChanged()
        return true
    end

    -- Center: let go of a screen edge (an anchor to a piece stays).
    function Snap.ClearScreenAnchor(entry)
        local link = entry and Explicit(entry)
        if not (link and edgeByKey[link.to]) then return false end
        LetGo(entry)
        if Core.EditModeMoved then Core.EditModeMoved() end
        Snap.SelectionChanged()
        return true
    end

    -- What `entry` is anchored to: the other's id (or screen edge), the side
    -- it is on, and its offset from that side (UIParent's units).
    function Snap.AnchorOf(entry)
        local link = entry and Explicit(entry)
        if not link then return end
        for side, spec in pairs(SIDES) do
            if GrowPoint(entry, spec.point) == link.point and GrowPoint(entry, spec.rel) == link.rel then
                return link.to, side, link.x or 0, link.y or 0
            end
        end
        return link.to, nil, link.x or 0, link.y or 0
    end

    -- The offset typed: moved there at once.
    function Snap.SetAnchorOffset(entry, x, y)
        local link = entry and Explicit(entry)
        if not link then return false end
        if InCombatLockdown() and Blocked(Movers(entry)) then
            Refuse(entry, IN_COMBAT)
            return false
        end
        link.x, link.y = x or link.x, y or link.y
        FollowAll()
        SaveFollowed()
        if Core.EditModeMoved then Core.EditModeMoved() end
        return true
    end

    -- Not anchored any more: it stays where it is.
    function Snap.Unanchor(entry)
        if not (entry and Explicit(entry)) then return false end
        LetGo(entry)
        if Core.EditModeMoved then Core.EditModeMoved() end
        Snap.SelectionChanged()
        return true
    end

    ---------------------------------------------------------------------------
    -- ANCHORED TO START WITH (the player, 2026-10-02: focus, cooldowns and
    -- pet anchored to the player frame by default, from where they are; the
    -- target of target to the target; the swing timers to the 5SR, the 5SR to
    -- the castbar). Made once each, from where the two are then - and
    -- remembered (placing.anchoredByDefault), so one let go of stays let go.
    -- Reset Position anchors it again.
    ---------------------------------------------------------------------------

    Snap.DEFAULT_ANCHORS = {
        { "focus", "player" }, { "pet", "player" }, { "cooldowns", "player" },
        { "targettarget", "target" }, { "threat", "target" },
        { "fsr", "castbar" }, { "swing", "fsr" },
        -- (The pet bar to Action Bar 2, under it, and the stance bar to Action
        -- Bar 1, over it: the player, 2026-10-03.)
        { "petbar", "bar2" }, { "stance", "bar1" },
    }

    -- Which side of `parent` `box` is on: the way it is furthest out,
    -- measured against the two boxes' sizes.
    local function SideOf(box, parent)
        local dx, dy = box.cx - parent.cx, box.cy - parent.cy
        local nx = dx / math.max(1, (parent.r - parent.l + box.r - box.l) / 2)
        local ny = dy / math.max(1, (parent.t - parent.b + box.t - box.b) / 2)
        if math.abs(ny) >= math.abs(nx) then return dy >= 0 and "above" or "below" end
        return dx >= 0 and "right" or "left"
    end

    -- ANCHOR, as the player has it (2026-10-03): `entry` anchored to
    -- `target` from exactly where it is - nothing moves; from then on it
    -- keeps that place relative to the other, on the side it is on.
    function Snap.AnchorHere(entry, target)
        local why = AnchorRefusal(entry, target)
        if why then return false, why end
        local box, parent = AnchorBox(entry), AnchorBox(target)
        if not (box and parent) then return false, "Elements cannot be anchored to\n" .. NameOf(target) end
        local spec = SIDES[SideOf(box, parent)]
        HangFrom(entry, target.opts.id, spec.point, spec.rel, box)
        if Core.EditModeMoved then Core.EditModeMoved() end
        Snap.SelectionChanged()
        return true
    end

    local function MadeByDefault()
        local db = Snap.db
        if type(db) ~= "table" then return {} end
        if type(db.anchoredByDefault) ~= "table" then db.anchoredByDefault = {} end
        return db.anchoredByDefault
    end

    -- Every default anchor not made yet, made where it can be now. Answers
    -- whether any is still to be made (a piece not laid out yet).
    function Snap.AnchorDefaults()
        local made, waiting = MadeByDefault(), false
        for _, pair in ipairs(Snap.DEFAULT_ANCHORS) do
            local id, to = pair[1], pair[2]
            local entry, target = byId[id], byId[to]
            if not made[id] and entry and target then
                if LinkOf(id) or AnchorRefusal(entry, target) then
                    made[id] = true          -- anchored already, or it can't be
                else
                    local box, parent = AnchorBox(entry), AnchorBox(target)
                    if box and parent then
                        local spec = SIDES[SideOf(box, parent)]
                        HangFrom(entry, to, spec.point, spec.rel, box)
                        made[id] = true
                    else
                        waiting = true
                    end
                end
            end
        end
        return waiting
    end

    -- Tried until every piece is laid out (the modules place theirs as the
    -- world loads).
    local defaultsTimer
    function Snap.ScheduleDefaults()
        if defaultsTimer then return end
        local tries = 0
        local function Try()
            tries = tries + 1
            if Snap.AnchorDefaults() and tries < 20 then
                C_Timer.After(0.5, Try)
            else
                defaultsTimer = nil
            end
        end
        defaultsTimer = true
        C_Timer.After(0.5, Try)
    end

    -- A piece reset: its default anchor made again.
    function Snap.ReanchorAfterReset(entry)
        local id = entry and entry.opts.id
        if id then MadeByDefault()[id] = nil end
        if Snap.AnchorDefaults() then Snap.ScheduleDefaults() end
        -- A piece of the addon's default layout: back in its place there.
        local places = Core.DefaultPlaces
        if places and places.Place then places.Place(id) end
    end

    ---------------------------------------------------------------------------
    -- THE MOVERS (EllesmereUI's CreateMover, in the addon's look, nothing
    -- animated - the player, 2026-10-03: "we dont need animated elements in
    -- unlock mode"): one over each shown piece while Unlock Mode is open, the
    -- size of what shows of it (Box), taking the mouse:
    --
    --   * always dark (the window's dark at 0.95), its name in white, its top
    --     left in numbers in its corner (no switches for these - the player,
    --     2026-10-03);
    --   * its outline the addon's gold at 0.6 - white under the mouse and
    --     while selected, a white wash over it while selected; its name orange
    --     while anchored;
    --   * CLICKED: selected, and its menu opened beside it (Snap.Clicked -
    --     Options\Unlock.lua): its size, place, Match Width / Height, Anchor,
    --     snap target and its own settings. No links or cog on the mover
    --     itself (the player, 2026-10-03). While it waits for another piece
    --     it says what to click;
    --   * the piece it snaps to while dragged (or its chosen snap target while
    --     selected) outlined white;
    --   * smaller movers over bigger ones; Shift+Right-click hides one until
    --     Unlock Mode closes.
    ---------------------------------------------------------------------------

    local movers = {}             -- entry -> its mover
    Snap.movers = movers

    Snap.STRATA = "DIALOG"
    Snap.MOVER_LEVEL = 600        -- the movers from here up
    local ANCHORED = { 1, 0.7, 0.3 }
    -- A mover's name and outline colours: made once, as they are set every
    -- frame.
    local LABEL_ANCHORED = { ANCHORED[1], ANCHORED[2], ANCHORED[3], 0.85 }
    local LABEL_PLAIN = { 1, 1, 1, 0.75 }
    local OUTLINE_LIT = { 1, 1, 1, 0.9 }
    local OUTLINE_REST = { Style.GOLD[1], Style.GOLD[2], Style.GOLD[3], 0.6 }

    local function W() return Core.Widgets end

    -- Options\Unlock.lua replaces these: a piece's menu opened beside its
    -- mover, and a click on a mover (select it and open its menu, or let go).
    function Snap.OpenCog(entry, mover) end
    function Snap.Clicked(entry, mover, wasSelected)
        if wasSelected then Snap.Deselect() else Snap.Select(entry) end
    end

    local PICK_TEXT = {
        w = "Click any element\nto match its width",
        h = "Click any element\nto match its height",
        anchor = "Click any element\nto anchor to it",
        snaptarget = "Click any element\nto snap to it",
    }

    -- Hidden for now (Shift+Right-click): out of sight and not snapped to,
    -- until Unlock Mode closes.
    local function HideForNow(entry, frame)
        hiddenForNow[entry] = true
        if selected and selected == entry then Snap.Deselect() end
        if frame then
            frame.hovered, frame.pressed = false, false
            frame:Hide()
        end
    end

    local function NewMover(entry)
        local w = W()
        local mover = CreateFrame("Button", nil, UIParent)
        mover:SetFrameStrata(Snap.STRATA)
        mover:SetFrameLevel(Snap.MOVER_LEVEL)
        mover:EnableMouse(true)
        mover:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        mover:Hide()
        mover.entry = entry
        local bg = Style.WINDOW_BACKGROUND
        mover.bg = mover:CreateTexture(nil, "BACKGROUND")
        mover.bg:SetAllPoints(mover)
        mover.bg:SetColorTexture(bg[1], bg[2], bg[3], 0.95)
        mover.wash = mover:CreateTexture(nil, "ARTWORK")
        mover.wash:SetAllPoints(mover)
        mover.wash:SetColorTexture(1, 1, 1, 1)
        mover.wash:SetAlpha(0.10)
        mover.wash:Hide()
        mover.outline = w.Border(mover, Style.GOLD)

        local labels = CreateFrame("Frame", nil, mover)
        labels:SetAllPoints(mover)
        labels:SetFrameLevel(mover:GetFrameLevel() + 3)
        mover.labels = labels
        mover.label = w.Text(labels, 10, { 1, 1, 1, 0.75 })
        mover.label:SetPoint("CENTER", mover, "CENTER", 0, 0)
        mover.label:SetJustifyH("CENTER")
        mover.coords = w.Text(labels, 9, { 1, 1, 1, 0.7 })
        mover.coords:SetPoint("TOPLEFT", mover, "TOPLEFT", 3, -2)
        mover.coords:Hide()
        mover.pick = w.Text(labels, 10, { 1, 1, 1, 0.85 }, false, 1)
        mover.pick:SetPoint("CENTER", mover, "CENTER", 0, 0)
        mover.pick:SetJustifyH("CENTER")
        mover.pick:Hide()

        mover:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then return end
            self.pressed = true
            self.wasSelected = selected == entry
            Keys()
            Snap.Start(entry.frame)
        end)
        mover:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" then
                if IsShiftKeyDown and IsShiftKeyDown() then
                    HideForNow(entry, self)
                else
                    Snap.Select(entry)
                    Snap.OpenCog(entry, self)
                end
                return
            end
            if button ~= "LeftButton" or not self.pressed then return end
            self.pressed = false
            local wasDragging = drag ~= nil and drag.entry == entry
            local moved = Snap.Stop(entry.frame)
            if moved then
                if entry.opts.save then entry.opts.save() end
            elseif wasDragging then
                -- A click: selected and its menu, or let go of.
                Snap.Clicked(entry, self, self.wasSelected)
            end
        end)
        mover:SetScript("OnEnter", function(self) self.hovered = true end)
        mover:SetScript("OnLeave", function(self) self.hovered = false end)
        movers[entry] = mover
        return mover
    end

    -- One piece's mover over it (`l`, `r`, `t`, `b`: what shows of the
    -- piece) and in its state; answers it with its area, in a table kept
    -- with the mover.
    local function LayOutMover(entry, l, r, t, b)
        local w = W()
        local mover = movers[entry] or NewMover(entry)
        local dragging = drag and drag.moved and drag.entry == entry
        local isSelected = selected == entry
        local pick = picking
        local picker = pick and pick.entry == entry
        local over = mover.hovered or mover:IsMouseOver()

        local anchored = Explicit(entry) ~= nil
        mover.label:SetText(NameOf(entry))
        w.SetTextColour(mover.label, anchored and LABEL_ANCHORED or LABEL_PLAIN)
        local width, height = r - l, t - b
        mover:ClearAllPoints()
        mover:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (l + r) / 2, (t + b) / 2)
        mover:SetSize(width, height)

        -- Waiting for another piece: says what to click.
        if picker then
            mover.pick:SetWidth(math.max(60, width - 8))
            mover.pick:SetText(PICK_TEXT[pick.axis] or "")
            mover.pick:Show()
            mover.label:Hide()
        else
            mover.pick:Hide()
            mover.label:Show()
        end

        -- Its look; the piece snapped to outlined white.
        local lit = over or isSelected or dragging or mover.snapping
        local outline = lit and OUTLINE_LIT or OUTLINE_REST
        if mover.outline.colour ~= outline then w.TintBorder(mover.outline, outline) end
        mover.wash:SetShown(isSelected)

        local x, y = Snap.PositionOf(entry)
        if x then
            mover.coords:SetFormattedText("%d, %d", Whole(x), Whole(y))
            mover.coords:Show()
        else
            mover.coords:Hide()
        end
        mover:Show()
        local item = mover.layout or { frame = mover, entry = entry }
        mover.layout = item
        item.area = width * height
        return item
    end

    ---------------------------------------------------------------------------
    -- ANCHOR LINKS (EllesmereUI's, drawn at once): an orange line from an
    -- anchored piece's middle to its anchor's, while either is under the
    -- mouse, selected or dragged.
    ---------------------------------------------------------------------------

    local lineFrame
    local lines = {}

    local function LineFrame()
        if lineFrame then return lineFrame end
        lineFrame = CreateFrame("Frame", nil, UIParent)
        lineFrame:SetAllPoints(UIParent)
        lineFrame:SetFrameStrata(Snap.STRATA)
        lineFrame:SetFrameLevel(Snap.MOVER_LEVEL - 1)
        lineFrame:EnableMouse(false)
        return lineFrame
    end

    local function Active(entry)
        if not entry then return false end
        local mover = movers[entry]
        if mover and mover:IsShown() and (mover.hovered or mover:IsMouseOver()) then return true end
        if selected == entry then return true end
        return drag ~= nil and drag.moved and drag.entry == entry
    end

    local function DrawLines()
        local holder = LineFrame()
        local used = 0
        if holder.CreateLine then
            for _, entry in ipairs(entries) do
                local link = Explicit(entry)
                local mover = movers[entry]
                -- (Measured only when a line is wanted: this runs every frame.)
                local bl, br, bt, bb, pl, pr, pt, pb
                if link and mover and mover:IsShown() and (Active(entry) or Active(byId[link.to])) then
                    bl, br, bt, bb = BoxEdges(entry)
                    if bl then pl, pr, pt, pb = ParentEdges(link.to) end
                end
                if pl then
                    used = used + 1
                    local line = lines[used]
                    if not line then
                        line = holder:CreateLine(nil, "ARTWORK")
                        lines[used] = line
                    end
                    line:SetColorTexture(ANCHORED[1], ANCHORED[2], ANCHORED[3], 0.75)
                    line:SetThickness(3 * Pixel())
                    line:SetStartPoint("BOTTOMLEFT", UIParent, (bl + br) / 2, (bt + bb) / 2)
                    line:SetEndPoint("BOTTOMLEFT", UIParent, (pl + pr) / 2, (pt + pb) / 2)
                    line:Show()
                end
            end
        end
        for spare = used + 1, #lines do lines[spare]:Hide() end
        holder:Show()
    end

    ---------------------------------------------------------------------------
    -- LAYING IT ALL OUT, every frame while Unlock Mode is open.
    ---------------------------------------------------------------------------

    -- The party's four frames are one column with one mover, the first's,
    -- which reaches over all four.
    local function OwnsMover(entry)
        return entry.opts.group ~= "party" or byId[entry.opts.id] == entry
    end

    -- PREVIEW (the player, 2026-10-03: "a preview switch on our Unlock Mode
    -- menu to hide unlock style and show actual frames"): no movers, no
    -- lines - nor (Options\Unlock.lua, DogsForeverUI.lua) the game frames'
    -- boxes, the grid or the dimmer - only the frames themselves, and the
    -- bar to switch it off. Nothing can be picked up meanwhile. Off again
    -- whenever Unlock Mode opens or closes.
    local previewing = false
    function Snap.Previewing() return previewing end

    -- The movers shown this frame (one list, refilled each frame).
    local shown = {}
    local function Bigger(a, b) return a.area > b.area end

    local function LayOutMovers()
        if previewing then
            for _, mover in pairs(movers) do
                mover.hovered, mover.pressed = false, false
                mover:Hide()
            end
            if lineFrame then lineFrame:Hide() end
            ShowCentreLines(nil)
            return
        end
        ShowCentreLines((drag and drag.entry) or selected)
        -- The piece snapped to (while dragging), or the selected one's chosen
        -- snap target: outlined white (EllesmereUI's snap highlight, still).
        local snapTo = Snap.DragSnapTarget()
        if not snapTo and selected then
            local wanted = snapTargets[selected]
            if wanted and wanted ~= "_disable_" then snapTo = byId[wanted] end
        end
        for entry, mover in pairs(movers) do mover.snapping = entry == snapTo end
        for index = #shown, 1, -1 do shown[index] = nil end
        for _, entry in ipairs(entries) do
            local l, r, t, b
            if OwnsMover(entry) and not hiddenForNow[entry] and entry.frame:IsVisible() then
                l, r, t, b = BoxEdges(entry)
            end
            if l then
                shown[#shown + 1] = LayOutMover(entry, l, r, t, b)
            elseif movers[entry] then
                movers[entry]:Hide()
            end
        end
        -- Smaller over bigger; one selected or dragged over all.
        table.sort(shown, Bigger)
        local count = #shown
        for index, item in ipairs(shown) do
            local raised = item.entry == selected or (drag and drag.entry == item.entry)
            local level = Snap.MOVER_LEVEL + index + (raised and count + 5 or 0)
            if item.frame:GetFrameLevel() ~= level then item.frame:SetFrameLevel(level) end
        end
        DrawLines()
    end
    Snap.LayOutMovers = LayOutMovers

    function Snap.SetPreview(on)
        on = on and true or false
        if on == previewing then return end
        if on then
            Snap.Cancel()
            if Snap.Picking() then Snap.StopPicking() end
            Snap.Deselect()
        end
        previewing = on
        if Unlocked() then LayOutMovers() end
    end

    local driver

    local function Drive(_, elapsed)
        if not Unlocked() then
            Snap.UpdateGameLook()
            return
        end
        LayOutMovers()
        if Snap.OnDrive then Snap.OnDrive(elapsed) end
    end

    -- Shown while Unlock Mode is open (the core calls this whenever that may
    -- have changed), gone otherwise.
    function Snap.UpdateGameLook()
        local on = Unlocked()
        if on and not driver then
            driver = CreateFrame("Frame", nil, UIParent)
            driver:SetScript("OnUpdate", Drive)
        end
        if driver then driver:SetShown(on) end
        if on then
            Keys()
            KeysOn()
            LayOutMovers()
            return
        end
        for key in pairs(hiddenForNow) do hiddenForNow[key] = nil end
        ShowCentreLines(nil)
        Snap.ForgetGameFrames()
        for _, mover in pairs(movers) do
            mover.hovered, mover.pressed = false, false
            mover:Hide()
        end
        if lineFrame then lineFrame:Hide() end
        if keys then KeysOn() end
    end

    ---------------------------------------------------------------------------
    -- A section of the saved table of its own - the bar's switches, what
    -- hangs from what and whose size matches whose - kept in profiles with
    -- the rest.
    ---------------------------------------------------------------------------

    function Snap.Normalise(db)
        if type(db.snap) ~= "boolean" then db.snap = true end
        -- Only anchors made on purpose are kept: a piece that hung from
        -- another just for having been dropped beside it (before 2026-10-02)
        -- stays where it is, and follows nothing; and none to one of the
        -- game's frames (moved in the game's Edit Mode since 2026-10-02).
        if type(db.snaps) == "table" then
            for id, link in pairs(db.snaps) do
                if type(link) ~= "table" or not link.explicit
                   or (type(link.to) == "string" and link.to:find("^game:")) then
                    db.snaps[id] = nil
                end
            end
        end
    end

    function Snap.Refresh()
        if Core.UpdateGrid then Core.UpdateGrid() end
        Snap.ScheduleDefaults()
        -- (A reset or a new character: the addon's default layout, once.)
        local places = Core.DefaultPlaces
        if places and places.Schedule then places.Schedule() end
    end
    Snap.Init = Snap.Refresh

    Core:RegisterModule(Snap)
end
