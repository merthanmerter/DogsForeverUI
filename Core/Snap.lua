-- MODULE: Placing  (DogsForeverUI.Snap, settings section "placing")
-- Unlock Mode's engine, EllesmereUI's ported: a mover over every registered
-- piece, dragging with snapping, selection and nudging, size matches and
-- anchors. Its windows (bar, menus, game-frame boxes) are Options\Unlock.lua.

local Snap = {
    key = "placing",
    title = "Placing",
    defaults = { snap = true },     -- Snap Elements
    -- Anchors, size matches, which default anchors were made, the default layout's version.
    placement = { snaps = true, matches = true, anchoredByDefault = true, defaultPlaces = true },
}
DogsForeverUI.Snap = Snap

do -- private scope
    local Core = DogsForeverUI
    local Style = Core.Style

    local THRESHOLD = 4             -- screen pixels before a press becomes a drag
    local SNAP_THRESH = 6           -- EllesmereUI's snapping distance
    local BORDER = Style.BORDER_INSET
    local IN_COMBAT = "Can't be moved in combat."

    local entries, byFrame, byId = {}, {}, {}
    Snap.entries = entries

    local drag                      -- the drag under way
    local selected, keys, guides
    local picking                   -- { entry, axis } while a match or anchor waits for its piece
    local previewing = false
    local hiddenForNow = setmetatable({}, { __mode = "k" })

    ---------------------------------------------------------------------------
    -- Pieces
    ---------------------------------------------------------------------------

    -- opts: save(), name (or a function), id (saved; the party's four share one),
    -- group (never snaps within), extra() -> l, r, t, b reach past the frame,
    -- parts() -> regions shown with it, moveWith() -> frames dragged along,
    -- fixedEdge() -> "LEFT", "RIGHT" or "" (the edge it grows from).
    function Snap.Register(frame, opts)
        if byFrame[frame] then return byFrame[frame] end
        local entry = { frame = frame, opts = opts }
        byFrame[frame] = entry
        entries[#entries + 1] = entry
        if opts.id and not byId[opts.id] then byId[opts.id] = entry end
        frame:HookScript("OnSizeChanged", function() Snap.ScheduleMatches() end)
        return entry
    end

    -- Left-dragged while `module` is unlocked (`target` moves, the frame by default); `save` after.
    function Snap.Draggable(frame, module, save, target)
        target = target or frame
        frame:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" and module.db.unlocked then Snap.Start(target) end
        end)
        frame:SetScript("OnMouseUp", function(_, button)
            if button ~= "LeftButton" or not module.db.unlocked then return end
            Snap.Stop(target)
            save()
        end)
    end

    -- A module's movable piece, its place in db.barLeft/barTop: registered, dragged, and
    -- the module's Unlock/Lock (redraw after each). Answers its save.
    function Snap.Piece(frame, module, opts, redraw)
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        local function Save()
            local db = module.db
            db.autoPlaced = false
            db.barLeft, db.barTop = frame:GetLeft(), frame:GetTop() - GetScreenHeight()
            redraw()
            Core.RefreshOptions()
        end
        opts.save = Save
        Snap.Register(frame, opts)
        Snap.Draggable(frame, module, Save)
        function module.Unlock()
            module.db.unlocked = true
            redraw()
        end
        function module.Lock()
            module.db.unlocked = false
            frame:StopMovingOrSizing()
            redraw()
        end
        return Save
    end

    -- At its saved place; not user-placed, so the client's layout cache never wins over it.
    function Snap.Put(frame, db)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.barLeft, db.barTop)
        frame:SetUserPlaced(false)
    end

    function Snap.EntryOf(frame) return byFrame[frame] end
    function Snap.EntryById(id) return byId[id] end

    local function NameOf(entry)
        local name = entry and entry.opts.name
        if type(name) == "function" then name = name() end
        return name or ""
    end
    Snap.NameOf = NameOf

    -- One of the saved tables (snaps, matches, anchoredByDefault).
    local function Saved(key)
        local t = Snap.db[key]
        if type(t) ~= "table" then
            t = {}
            Snap.db[key] = t
        end
        return t
    end

    Snap.SCREEN_EDGES = {
        { key = "SCREEN_LEFT",   label = "Left",   name = "Left Screen Edge",   side = "right" },
        { key = "SCREEN_RIGHT",  label = "Right",  name = "Right Screen Edge",  side = "left" },
        { key = "SCREEN_TOP",    label = "Top",    name = "Top Screen Edge",    side = "below" },
        { key = "SCREEN_BOTTOM", label = "Bottom", name = "Bottom Screen Edge", side = "above" },
    }
    local edgeByKey = {}
    for _, edge in ipairs(Snap.SCREEN_EDGES) do edgeByKey[edge.key] = edge end

    function Snap.IsScreenEdge(key) return edgeByKey[key] ~= nil end

    function Snap.TargetName(id)
        if edgeByKey[id] then return edgeByKey[id].name end
        local entry = byId[id]
        return entry and NameOf(entry) or tostring(id)
    end

    ---------------------------------------------------------------------------
    -- Boxes, in UIParent's units, y up
    ---------------------------------------------------------------------------

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

    local function SizedBox(l, r, t, b)
        if l and r - l > 0 and t - b > 0 then return NewBox(l, r, t, b) end
    end

    local function Shifted(box, dx, dy)
        return NewBox(box.l + dx, box.r + dx, box.t + dy, box.b + dy)
    end

    -- One of the nine SetPoint points of the edges `l`, `r`, `t`, `b`.
    local function PointAt(point, l, r, t, b)
        local x = point:find("LEFT") and l or point:find("RIGHT") and r or (l + r) / 2
        local y = point:find("TOP") and t or point:find("BOTTOM") and b or (t + b) / 2
        return x, y
    end

    -- What shows of a piece, as edges (asked every frame): frame, shown parts, extra (a unit
    -- frame's name row) and border. `bare`: no parts, which come and go (anchors are measured so).
    local function Edges(entry, bare)
        local l, r, t, b = Rect(entry.frame)
        if not l then return end
        if entry.opts.parts and not bare then
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
        local extra = entry.opts.extra
        if extra then
            local k = entry.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
            local el, er, et, eb = extra()
            l, r = l - (el or 0) * k, r + (er or 0) * k
            t, b = t + (et or 0) * k, b - (eb or 0) * k
        end
        if r - l <= 0 or t - b <= 0 then return end
        return l - BORDER, r + BORDER, t + BORDER, b - BORDER
    end

    local function Box(entry, bare)
        local l, r, t, b = Edges(entry, bare)
        if l then return NewBox(l, r, t, b) end
    end
    Snap.Box = Box

    local function AnchorBox(entry) return Box(entry, true) end
    Snap.AnchorBox = AnchorBox

    -- A piece, or a screen edge: a strip one unit wide just outside the screen.
    local function ParentEdges(to)
        if edgeByKey[to] then
            local width, height = GetScreenWidth(), GetScreenHeight()
            if to == "SCREEN_LEFT" then return -1, 0, height, 0 end
            if to == "SCREEN_RIGHT" then return width, width + 1, height, 0 end
            if to == "SCREEN_TOP" then return 0, width, height + 1, height end
            return 0, width, 0, -1
        end
        local entry = byId[to]
        if entry then return Edges(entry, true) end
    end

    ---------------------------------------------------------------------------
    -- Anchors: placing.snaps[id] = { to, point, rel, x, y, explicit = true, box }.
    -- A piece is re-placed from where its anchor IS, never moved by deltas (drift).
    ---------------------------------------------------------------------------

    local ANCHOR_BOX = 2            -- links without it were measured by Box: recaptured

    local function Snaps() return Saved("snaps") end

    local function LinkOf(id)
        local link = Snaps()[id]
        if type(link) == "table" and type(link.to) == "string" then return link.to, link end
    end

    local function Anchor(entry) return select(2, LinkOf(entry.opts.id)) end
    Snap.LinkOf = Anchor

    -- Everything hanging from `entry`, however far down (and itself), as a set.
    local function Followers(entry)
        local seen = { [entry] = true }
        local function Walk(id)
            if not id then return end
            for childId in pairs(Snaps()) do
                local child = byId[childId]
                if child and not seen[child] and LinkOf(childId) == id then
                    seen[child] = true
                    Walk(child.opts.id)
                end
            end
        end
        Walk(entry.opts.id)
        return seen
    end

    local function LetGo(entry)
        if entry.opts.id then Snaps()[entry.opts.id] = nil end
    end

    -- A piece that grows one way hangs above or below by its fixed edge, not its middle.
    local function GrowPoint(entry, point)
        local side = point:match("^TOP") or point:match("^BOTTOM")
        if not side or not entry.opts.fixedEdge then return point end
        return side .. entry.opts.fixedEdge()
    end

    -- `entry`'s `point` on `to`'s `rel`, at the offset they have now (`box`: its AnchorBox).
    local function HangFrom(entry, to, point, rel, box)
        local id = entry.opts.id
        if not id then return end
        point, rel = GrowPoint(entry, point), GrowPoint(entry, rel)
        local pl, pr, pt, pb = ParentEdges(to)
        if to == id or not (pl and box) then
            Snaps()[id] = nil
            return
        end
        local px, py = PointAt(rel, pl, pr, pt, pb)
        local mx, my = PointAt(point, box.l, box.r, box.t, box.b)
        Snaps()[id] = { to = to, point = point, rel = rel, x = mx - px, y = my - py, explicit = true,
                        box = ANCHOR_BOX }
    end

    -- Moved by hand: still anchored, at the new offset.
    local function MovedByHand(entry)
        local link = Anchor(entry)
        local box = link and AnchorBox(entry)
        if box then HangFrom(entry, link.to, link.point, link.rel, box) end
    end

    -- Its anchor retaken by the edge it grows from now.
    function Snap.KeepEdge(entry)
        local link = Anchor(entry)
        if link and GrowPoint(entry, link.point) ~= link.point then MovedByHand(entry) end
    end

    ---------------------------------------------------------------------------
    -- The game's own Edit Mode systems on screen (read only), for Options\Unlock.lua's handover boxes
    ---------------------------------------------------------------------------

    local function RegionBox(region)
        local ok, l, r, t, b = pcall(Rect, region)
        if ok then return SizedBox(l, r, t, b) end
    end

    local function Visible(system)
        local ok, shown = pcall(system.IsVisible, system)
        return ok and shown
    end

    -- No raid up: boxed all the same, at the size last seen (ActionBars\GameFrames.lua).
    local function RaidResting(system)
        return system == CompactRaidFrameContainer and not Visible(system)
    end

    -- Hidden by its own Visibility setting: boxed all the same, unless switched off.
    local function MeterResting(system)
        if system ~= DamageMeter or Visible(system) then return false end
        return GetCVarBool("damageMeterEnabled") and C_DamageMeter.IsDamageMeterAvailable() or false
    end

    function Snap.SystemBox(system)
        if MeterResting(system) then return RegionBox(system) end
        if RaidResting(system) then return SizedBox(Core.GameFrames.RaidBox()) end
        if system.Selection then return RegionBox(system.Selection) or RegionBox(system) end
    end

    function Snap.GameSystems()
        local list = {}
        for _, system in ipairs(EditModeManagerFrame.registeredSystemFrames) do
            if not Core.IsHeld(system) then
                local seen, alpha = pcall(system.GetEffectiveAlpha, system)
                if (Visible(system) and (not seen or type(alpha) ~= "number" or alpha > 0.01))
                   or ((RaidResting(system) or MeterResting(system)) and Snap.SystemBox(system)) then
                    list[#list + 1] = system
                end
            end
        end
        return list
    end

    function Snap.SystemName(system)
        local ok, name = pcall(system.GetSystemName, system)
        if ok and type(name) == "string" and name ~= "" then return name end
        return system:GetName() or "?"
    end

    ---------------------------------------------------------------------------
    -- Snapping (EllesmereUI's SnapPosition): edges and middles of the ONE nearest
    -- piece, and the screen's middle lines, within SNAP_THRESH; each axis alone.
    ---------------------------------------------------------------------------

    function Snap.Rules() return Snap.db.snap and true or false end

    -- What hangs from the same piece as `entry`, as a set.
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

    -- Never itself, what hangs from it or beside it, its own group, or one hidden for now.
    local function SnapTarget(entry, box)
        local below, siblings = Followers(entry), Siblings(entry)
        local best, bestD
        for _, other in ipairs(entries) do
            if not below[other] and not siblings[other] and Shown(other)
               and (entry.opts.group == nil or other.opts.group ~= entry.opts.group) then
                local oL, oR, oT, oB = Edges(other)
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

    -- The nearest of `mine` to any of `theirs` within reach, if nearer than `best`.
    local function Closest(mine, theirs, best, at)
        for _, a in ipairs(mine) do
            for _, b in ipairs(theirs) do
                local delta = a - b
                if math.abs(delta) < SNAP_THRESH and (not best or math.abs(delta) < math.abs(best)) then
                    best, at = delta, b
                end
            end
        end
        return best, at
    end

    -- { dx, dy, x, y = the lines met, target = the piece snapped to, screenX/Y = by the screen's middle }
    local function SnapPosition(entry, box)
        local result = { dx = 0, dy = 0 }
        if not Snap.Rules() then return result end
        local ddx, x, ddy, y
        local target = SnapTarget(entry, box)
        result.target = target
        local o = target and Box(target)
        if o then
            ddx, x = Closest({ box.l, box.cx, box.r }, { o.l, o.cx, o.r })
            ddy, y = Closest({ box.t, box.cy, box.b }, { o.t, o.cy, o.b })
        end
        local pieceDx, pieceDy = ddx, ddy
        ddx, x = Closest({ box.cx }, { GetScreenWidth() / 2 }, ddx, x)
        ddy, y = Closest({ box.cy }, { GetScreenHeight() / 2 }, ddy, y)
        result.screenX = ddx ~= pieceDx or nil
        result.screenY = ddy ~= pieceDy or nil
        if ddx then result.dx, result.x = -ddx, x end
        if ddy then result.dy, result.y = -ddy, y end
        return result
    end

    function Snap.Find(entry)
        local box = Box(entry)
        if not box then return { dx = 0, dy = 0 } end
        return SnapPosition(entry, box)
    end

    ---------------------------------------------------------------------------
    -- Guides: gold lines across the screen where a dragged piece met
    ---------------------------------------------------------------------------

    -- One real screen pixel in UIParent's units.
    local function Pixel()
        local _, height = GetPhysicalScreenSize()
        return GetScreenHeight() / height
    end
    Snap.Pixel = Pixel

    local function Guides()
        if guides then return guides end
        guides = CreateFrame("Frame", Core.ADDON_NAME .. "SnapGuides", UIParent)
        guides:SetAllPoints(UIParent)
        guides:SetFrameStrata("TOOLTIP")
        guides:EnableMouse(false)
        -- x, y: where a dragged piece met; cx, cy: the screen's middle lines, brighter.
        local gold = Style.GOLD
        for _, axis in ipairs({ "x", "y", "cx", "cy" }) do
            local line = guides:CreateTexture(nil, "OVERLAY", nil, 6)
            line:SetColorTexture(gold[1], gold[2], gold[3], (axis == "cx" or axis == "cy") and 0.9 or 0.5)
            -- Laid on whole pixels below: no snapping of the game's on top.
            line:SetSnapToPixelGrid(false)
            line:SetTexelSnappingBias(0)
            line:Hide()
            guides[axis] = line
        end
        Snap.guides = guides
        return guides
    end

    local function OnPixel(v, px) return math.floor(v / px + 0.5) * px end

    -- A line across the screen at `at`, `pixels` thick, on whole pixels from the top left:
    -- one pixel centred between two pixels came out zero or one wide.
    local function ShowLine(line, vertical, at, pixels)
        if not at then
            line:Hide()
            return
        end
        pixels = pixels or 1
        local px = Pixel()
        local lead = math.floor(pixels / 2) * px
        local width, height = GetScreenWidth(), GetScreenHeight()
        line:ClearAllPoints()
        if vertical then
            line:SetPoint("TOPLEFT", UIParent, "TOPLEFT", OnPixel(at, px) - lead, 0)
            line:SetSize(pixels * px, height)
        else
            line:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -(OnPixel(height - at, px) - lead))
            line:SetSize(width, pixels * px)
        end
        line:Show()
    end

    local function HideLines()
        if not guides then return end
        guides.x:Hide()
        guides.y:Hide()
    end

    -- The screen's middle lines over every mover, each only while the piece in hand
    -- (dragged, else selected) has its middle on it, within a unit. `entry` nil: none.
    local CENTRE_PIXELS, CENTRED = 2, 1
    local function ShowCentreLines(entry)
        local l, r, t, b
        if entry then l, r, t, b = Edges(entry) end
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
    -- Refused (EllesmereUI's FlashRedBorder): the outline red for 1.5 s, the reason at the cursor for 3 s
    ---------------------------------------------------------------------------

    local REFUSE_FADE, REFUSE_TIP = 1.5, 3
    local REFUSE_SIDES = {
        top = { "TOPLEFT", "TOPRIGHT" }, bottom = { "BOTTOMLEFT", "BOTTOMRIGHT" },
        left = { "TOPLEFT", "BOTTOMLEFT" }, right = { "TOPRIGHT", "BOTTOMRIGHT" },
    }
    local refusal

    local function DrawRefusal(self)
        local t = GetTime() - self.started
        if t >= REFUSE_TIP then
            self:Hide()
            return
        end
        local alpha = t < REFUSE_FADE and 1 or 0     -- nothing animated in Unlock Mode
        for side in pairs(REFUSE_SIDES) do self[side]:SetAlpha(alpha) end
    end

    local function Refuse(entry, why)
        if not refusal then
            refusal = CreateFrame("Frame", Core.ADDON_NAME .. "SnapRefusal", UIParent)
            refusal:SetFrameStrata("TOOLTIP")
            refusal:EnableMouse(false)
            for side, points in pairs(REFUSE_SIDES) do
                local line = refusal:CreateTexture(nil, "OVERLAY")
                line:SetColorTexture(1, 0.2, 0.2, 1)
                line:SetPoint(points[1], refusal, points[1], 0, 0)
                line:SetPoint(points[2], refusal, points[2], 0, 0)
                refusal[side] = line
            end
            refusal:SetScript("OnUpdate", DrawRefusal)
            refusal:SetScript("OnHide", function(self)
                if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            end)
            Snap.refusal = refusal
        end
        local box = entry and Box(entry)
        refusal:ClearAllPoints()
        if box then
            refusal:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", box.l, box.b)
            refusal:SetSize(box.r - box.l, box.t - box.b)
        else
            refusal:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            refusal:SetSize(1, 1)
        end
        local thick = 2 * Pixel()
        for side in pairs(REFUSE_SIDES) do
            local line = refusal[side]
            if side == "top" or side == "bottom" then line:SetHeight(thick) else line:SetWidth(thick) end
            line:SetShown(box ~= nil)
        end
        refusal.started, refusal.why = GetTime(), why
        refusal:Show()
        DrawRefusal(refusal)
        if why then
            GameTooltip:SetOwner(refusal, "ANCHOR_CURSOR")
            GameTooltip:SetText(why, 1, 1, 1)
            GameTooltip:Show()
        end
    end
    Snap.Refuse = Refuse

    ---------------------------------------------------------------------------
    -- Picking: the next piece clicked is the one to match ("w", "h") or anchor to
    ---------------------------------------------------------------------------

    function Snap.StartPicking(entry, axis)
        if not (entry and (axis == "anchor" and entry.opts.id or Snap.SizeOf(entry, axis) ~= nil)) then
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

    ---------------------------------------------------------------------------
    -- Moving
    ---------------------------------------------------------------------------

    local function Cursor()
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        return x / scale, y / scale
    end

    -- The frame and whatever moves with it, each with where it started.
    local function Moving(entry)
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

    -- In combat a protected piece stays put.
    local function Blocked(moving)
        if not InCombatLockdown() then return false end
        for _, mover in ipairs(moving) do
            if mover.frame:IsProtected() then return true end
        end
        return false
    end

    local function MoveAll(moving, dx, dy)
        if Blocked(moving) then return false end
        for _, mover in ipairs(moving) do
            local frame = mover.frame
            local k = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (mover.left + dx) * k, (mover.bottom + dy) * k)
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
    -- Following: every anchored piece put where its anchor says, every frame,
    -- locked or not, then saved once at rest (protected ones wait out combat)
    ---------------------------------------------------------------------------

    local unsaved = {}              -- pieces moved by following, not saved yet
    local SETTLED = 0.5

    -- Answers whether it moved (no tables made while nothing moves).
    local function Place(entry)
        local id = entry.opts.id
        local to, link = LinkOf(id)
        if not to or (drag and drag.entry.opts.id == id) then return false end
        local ml, mr, mt, mb = Edges(entry, true)
        local pl, pr, pt, pb = ParentEdges(to)
        if not (ml and pl) then return false end
        if link.box ~= ANCHOR_BOX then
            HangFrom(entry, to, link.point, link.rel, NewBox(ml, mr, mt, mb))
            return false
        end
        local px, py = PointAt(link.rel, pl, pr, pt, pb)
        local mx, my = PointAt(link.point, ml, mr, mt, mb)
        local dx, dy = px + (link.x or 0) - mx, py + (link.y or 0) - my
        if math.abs(dx) < SETTLED and math.abs(dy) < SETTLED then return false end
        if not MoveAll(Moving(entry), dx, dy) then return false end
        unsaved[entry] = true
        return true
    end

    -- A chain settles in as many passes as it is long. Answers whether any moved.
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

    local function SaveFollowed()
        if drag or next(unsaved) == nil then return end
        for entry in pairs(unsaved) do
            unsaved[entry] = nil
            if entry.opts.save then entry.opts.save() end
        end
        Core.EditModeMoved()
    end

    -- A revert put every place back: nothing to keep.
    function Snap.ForgetGameFrames()
        for entry in pairs(unsaved) do unsaved[entry] = nil end
    end

    local following = CreateFrame("Frame")
    following:SetScript("OnUpdate", function()
        if next(Snaps()) == nil then return end
        if not FollowAll() then SaveFollowed() end
    end)

    ---------------------------------------------------------------------------
    -- Dragging (in place of StartMoving): Shift keeps it to one line
    ---------------------------------------------------------------------------

    local function Follow()
        if not drag then return end
        -- The button is up: the mouse-up is on its way, or never comes.
        if not IsMouseButtonDown("LeftButton") then
            HideLines()
            return
        end
        local x, y = Cursor()
        local dx, dy = x - drag.x, y - drag.y
        if not drag.moved then
            local reach = THRESHOLD / UIParent:GetEffectiveScale()
            if dx * dx + dy * dy < reach * reach then return end
            drag.moved = true
            Snap.Select(drag.entry)
        end
        if IsShiftKeyDown() then
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
        MoveAll(drag.moving, box.l - drag.box.l, box.b - drag.box.b)
        drag.snap = snap
        local g = Guides()
        ShowLine(g.x, true, snap.x)
        ShowLine(g.y, false, snap.y)
        FollowAll()
    end

    local function EndDrag()
        drag = nil
        HideLines()
        if guides then guides:SetScript("OnUpdate", nil) end
    end

    -- A press: a drag if the mouse moves. While picking, the press picks this piece.
    function Snap.Start(frame)
        if previewing then return end
        local entry = byFrame[frame]
        if not entry then
            frame:StartMoving()
            return
        end
        if picking then
            local pick = picking
            Snap.StopPicking()
            if entry ~= pick.entry then
                local ok, why
                if pick.axis == "anchor" then
                    ok, why = Snap.AnchorHere(pick.entry, entry)
                else
                    ok, why = Snap.SetMatch(pick.entry, pick.axis, entry)
                end
                if not ok and why then Refuse(entry, why) end
            end
            return
        end
        local box = Box(entry)
        if not box then         -- not laid out yet: the game's way
            frame:StartMoving()
            return
        end
        local moving = Moving(entry)
        if Blocked(moving) then
            Refuse(entry, IN_COMBAT)
            return
        end
        local x, y = Cursor()
        drag = { entry = entry, frame = frame, box = box, moving = moving, x = x, y = y, moved = false }
        local g = Guides()
        g:SetScript("OnUpdate", Follow)
        g:Show()
    end

    -- In place of StopMovingOrSizing. Answers whether it moved (a click is not a drag).
    function Snap.Stop(frame)
        if not drag or drag.frame ~= frame then
            frame:StopMovingOrSizing()
            return false
        end
        Follow()                -- the last movement before the button rose
        local moved, entry = drag.moved, drag.entry
        if moved then
            MovedByHand(entry)
            Core.EditModeMoved()
        end
        EndDrag()
        if moved then FollowAll() end
        return moved
    end

    function Snap.IsDragging() return drag ~= nil end

    ---------------------------------------------------------------------------
    -- The selected piece: arrow keys move it a pixel, Shift 100; other keys
    -- go on to the game (none can be kept in combat)
    ---------------------------------------------------------------------------

    local NUDGE = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }

    local function KeysOn()
        keys:EnableKeyboard(selected ~= nil and Core.IsUnlocked() and not InCombatLockdown())
    end

    local function Keys()
        if keys then return keys end
        keys = CreateFrame("Frame", Core.ADDON_NAME .. "SnapKeys", UIParent)
        keys:EnableMouse(false)
        keys:SetScript("OnKeyDown", function(self, key)
            if InCombatLockdown() then return end
            local dir = NUDGE[key]
            self:SetPropagateKeyboardInput(not dir)
            if dir then
                local step = Pixel() * (IsShiftKeyDown() and 100 or 1)
                Snap.Nudge(dir[1] * step, dir[2] * step)
            end
        end)
        keys:SetScript("OnKeyUp", function(self)
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
        end)
        keys:SetScript("OnEvent", KeysOn)
        keys:RegisterEvent("PLAYER_REGEN_DISABLED")
        keys:RegisterEvent("PLAYER_REGEN_ENABLED")
        Snap.keys = keys
        return keys
    end

    -- Its top left from the screen's top left (y negative down): the menu's numbers.
    function Snap.PositionOf(entry)
        local left, _, top = Rect(entry.frame)
        if not left then return end
        return left, top - GetScreenHeight()
    end

    local function Whole(value)
        return value >= 0 and math.floor(value + 0.5) or -math.floor(-value + 0.5)
    end
    Snap.Whole = Whole

    function Snap.Select(entry)
        Keys()
        selected = entry
        KeysOn()
        Snap.SelectionChanged()
    end

    function Snap.Deselect()
        local was = selected
        selected = nil
        if keys then KeysOn() end
        if was then Snap.SelectionChanged() end
    end

    function Snap.Selected() return selected and selected.frame end
    function Snap.SelectedEntry() return selected end

    -- Moved and saved there (anchored: at the new offset).
    local function MoveBy(entry, dx, dy)
        local box = Box(entry)
        if not box then return false end
        local placed = OnScreen(Shifted(box, dx, dy))
        if not MoveAll(Moving(entry), placed.l - box.l, placed.b - box.b) then
            Refuse(entry, IN_COMBAT)
            return false
        end
        MovedByHand(entry)
        Core.EditModeMoved()
        if entry.opts.save then entry.opts.save() end
        FollowAll()
        return true
    end

    -- For Core\Defaults.lua.
    function Snap.Shift(entry, dx, dy)
        if not entry or drag then return false end
        if math.abs(dx) < 0.01 and math.abs(dy) < 0.01 then return true end
        return MoveBy(entry, dx, dy)
    end

    function Snap.FrameRect(entry)
        if entry then return Rect(entry.frame) end
    end

    function Snap.Nudge(dx, dy)
        if not selected or drag then return false end
        return MoveBy(selected, dx, dy)
    end

    -- Its top left to `x`, `y` (Snap.PositionOf's numbers; nil keeps that one).
    function Snap.MoveTo(entry, x, y)
        local left, top = Snap.PositionOf(entry)
        if not left or drag then return false end
        return MoveBy(entry, (x or left) - left, (y or top) - top)
    end

    -- Its middle on the screen's, both ways.
    function Snap.CentreOnScreen(entry)
        local box = Box(entry)
        if not box or drag then return false end
        return MoveBy(entry, GetScreenWidth() / 2 - box.cx, GetScreenHeight() / 2 - box.cy)
    end

    -- Unlock Mode closed: a drag stays where it is, nothing selected or picking.
    function Snap.Cancel()
        EndDrag()
        picking = nil
        Snap.Deselect()
        FollowAll()
        SaveFollowed()
    end

    ---------------------------------------------------------------------------
    -- Sizes, and W / H Match (EllesmereUI's): placing.matches[id] = { w = id, wx = extra, h, hx }.
    -- A piece resized for any reason: its matchers sized again next frame; never in combat.
    ---------------------------------------------------------------------------

    local AXES = { "w", "h" }
    local AXIS_WORD = { w = "width", h = "height" }
    local SIZE_MIN, SIZE_MAX = 1, 4000
    local EXTRA_MIN, EXTRA_MAX = -100, 100

    -- A match or an anchor made or let go of: unsaved, and the menu told.
    local function Edited()
        Core.EditModeMoved()
        Snap.SelectionChanged()
        return true
    end

    -- Each piece with a size of its own (the unit frames share one): the setting,
    -- what a new value moves, and whether it keeps an auto-placed bar where it is.
    local specs
    local function Specs()
        if specs then return specs end
        local Castbar = Core.Castbar
        local function Own(module) return function() return module.db end end
        local function Bar(module, placedKey)
            local keepCentred = Castbar.KeepCentred(Own(module), placedKey, "barLeft")
            return { module = module, w = { key = "barWidth", onChange = keepCentred }, h = { key = "barHeight" } }
        end
        local function Plain(module)
            return { module = module, w = { key = "barWidth", keepsPlacement = true },
                     h = { key = "barHeight", keepsPlacement = true } }
        end
        specs = {
            castbar = { module = Castbar, w = { key = "barWidth", onChange = Castbar.WidthChanged },
                        h = { key = "barHeight" } },
            swing = { module = Castbar, w = { key = "swingWidth", keepsPlacement = true,
                      onChange = Castbar.KeepCentred(Own(Castbar), "swingPlaced", "swingLeft") } },
            fsr = Bar(Core.FiveSecondRule, "placed"),
            combo = Bar(Core.ComboPoints, "placed"),
            xp = Bar(Core.XPBar, nil),
            cooldowns = Plain(Core.Cooldowns),
            threat = Plain(Core.Threat),
            toasts = Plain(Core.LootToasts),
            party = { module = Core.Frames, w = { key = "partyWidth" } },
        }
        return specs
    end

    -- Every size setting of one module's pieces: reverted with the places (DogsForeverUI.lua).
    function Snap.SizeKeys(module)
        local keys = {}
        for _, spec in pairs(Specs()) do
            if spec.module == module then
                for _, axis in ipairs(AXES) do
                    if spec[axis] then keys[spec[axis].key] = true end
                end
            end
        end
        return keys
    end

    local function SizeOf(entry, axis)
        local spec = entry and Specs()[entry.opts.id]
        return spec and spec[axis], spec
    end

    -- Its width ("w") or height ("h"), if it has one of its own.
    function Snap.SizeOf(entry, axis)
        local size, spec = SizeOf(entry, axis)
        if size then return spec.module.db[size.key] end
    end

    -- As its menu's box sets it. Answers whether it changed.
    function Snap.SetSize(entry, axis, value)
        local size, spec = SizeOf(entry, axis)
        if not size or type(value) ~= "number" then return false end
        value = math.max(SIZE_MIN, math.min(SIZE_MAX, Whole(value)))
        local module = spec.module
        local db = module.db
        local old = db[size.key]
        if old == value then return false end
        db[size.key] = value
        if size.onChange then size.onChange(old, value) end
        if db.autoPlaced ~= nil and not size.keepsPlacement then db.autoPlaced = false end
        if module.Refresh then module.Refresh() end
        Core.RefreshOptions()
        Core.EditModeMoved()
        return true
    end

    local function Matches() return Saved("matches") end

    -- The id it takes its width / height from, and the extra.
    function Snap.MatchOf(entry, axis)
        local match = entry and Matches()[entry.opts.id]
        if type(match) ~= "table" or type(match[axis]) ~= "string" then return end
        return match[axis], tonumber(match[axis .. "x"]) or 0
    end

    -- Whether `targetId` already takes that size from `childId`, however far round.
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
        local size = target and Measured(target.frame, axis)
        if not size then return false end
        local k = entry.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        return Snap.SetSize(entry, axis, size / k + extra)
    end

    local waiting = false           -- combat stopped a pass: one more when it ends

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

    local MatchSoon, matcher = Core.Waker(Snap.ApplyMatches)
    matcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    matcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    matcher:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" or waiting then MatchSoon() end
    end)

    function Snap.ScheduleMatches()
        if next(Matches()) ~= nil then MatchSoon() end
    end

    -- Answers true, or false and why not (EllesmereUI's words).
    function Snap.SetMatch(entry, axis, target)
        local id = entry and entry.opts.id
        local to = target and target.opts.id
        if not SizeOf(entry, axis) or not to or to == id then
            return false, "Elements cannot size match to\n" .. NameOf(target)
        end
        if WouldCircle(id, to, axis) then
            return false, "This would create a circular " .. AXIS_WORD[axis] .. " match"
        end
        local matches = Matches()
        local match = type(matches[id]) == "table" and matches[id] or {}
        matches[id] = match
        match[axis], match[axis .. "x"] = to, 0
        Snap.ApplyMatches()
        return Edited()
    end

    -- Its own size again, as it is now.
    function Snap.ClearMatch(entry, axis)
        local id = entry and entry.opts.id
        local match = id and Matches()[id]
        if type(match) ~= "table" or match[axis] == nil then return false end
        match[axis], match[axis .. "x"] = nil, nil
        if next(match) == nil then Matches()[id] = nil end
        Core.RefreshOptions()
        return Edited()
    end

    function Snap.SetMatchExtra(entry, axis, extra)
        local id = entry and entry.opts.id
        local match = id and Matches()[id]
        if type(match) ~= "table" or match[axis] == nil or type(extra) ~= "number" then return false end
        match[axis .. "x"] = math.max(EXTRA_MIN, math.min(EXTRA_MAX, Whole(extra)))
        Core.EditModeMoved()
        Snap.ApplyMatches()
        return true
    end

    ---------------------------------------------------------------------------
    -- Reset Position: its place forgotten, laid out and anchored as on a first start
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
    -- The pet bar's id is "petbar" ("pet" is the unit frame), its settings' "pet".
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
        if InCombatLockdown() and entry.frame:IsProtected() then
            Refuse(entry, IN_COMBAT)
            return false
        end
        local db = module.db
        for index = 2, #spec do db[spec[index]] = nil end
        if module.Normalise then module.Normalise(db) end
        LetGo(entry)
        -- Every module laid out again: a castbar-group bar back in it, the pet under the player.
        for _, other in ipairs(Core.modules) do
            if other.placement and other.Refresh then Core.Safely(other.Refresh) end
        end
        Snap.ReanchorAfterReset(entry)
        FollowAll()
        Core.EditModeMoved()
        Core.RefreshOptions()
        return true
    end

    ---------------------------------------------------------------------------
    -- Anchoring (EllesmereUI's Anchor and Relative to Screen): from exactly where
    -- it is, moving with the other from then on; never to itself or in a circle
    ---------------------------------------------------------------------------

    -- side -> this piece's point, on the other's point
    local SIDES = {
        above = { point = "BOTTOM", rel = "TOP" },
        below = { point = "TOP",    rel = "BOTTOM" },
        left  = { point = "RIGHT",  rel = "LEFT" },
        right = { point = "LEFT",   rel = "RIGHT" },
    }

    -- How many steps up `entry`'s chain the piece `id` is (nil: not on it).
    local function DepthAbove(entry, id)
        local current = entry.opts.id
        for depth = 1, 32 do
            local to = LinkOf(current)
            if not to then return nil end
            if to == id then return depth end
            current = to
        end
    end

    -- Why `entry` cannot be anchored to `target`, or nothing.
    local function AnchorRefusal(entry, target)
        if not (entry and entry.opts.id and target and target.opts.id) then
            return "Elements cannot be anchored to\n" .. NameOf(target)
        end
        if target == entry or target.opts.id == entry.opts.id then
            return "An element cannot anchor to itself"
        end
        if Followers(entry)[target] or (DepthAbove(entry, target.opts.id) or 0) >= 2 then
            return "This would create a circular anchor"
        end
    end

    -- Which side of `parent` `box` is on: the way it is furthest out, by their sizes.
    local function SideOf(box, parent)
        local dx, dy = box.cx - parent.cx, box.cy - parent.cy
        local nx = dx / math.max(1, (parent.r - parent.l + box.r - box.l) / 2)
        local ny = dy / math.max(1, (parent.t - parent.b + box.t - box.b) / 2)
        if math.abs(ny) >= math.abs(nx) then return dy >= 0 and "above" or "below" end
        return dx >= 0 and "right" or "left"
    end

    -- Anchored on the side it is on, from where it is. Answers whether both are laid out.
    local function HangBeside(entry, target)
        local box, parent = AnchorBox(entry), AnchorBox(target)
        if not (box and parent) then return false end
        local spec = SIDES[SideOf(box, parent)]
        HangFrom(entry, target.opts.id, spec.point, spec.rel, box)
        return true
    end

    function Snap.AnchorHere(entry, target)
        local why = AnchorRefusal(entry, target)
        if why then return false, why end
        if not HangBeside(entry, target) then return false, "Elements cannot be anchored to\n" .. NameOf(target) end
        return Edited()
    end

    function Snap.AnchorToScreen(entry, key)
        local edge = edgeByKey[key]
        local box = entry and AnchorBox(entry)
        if not (edge and box and entry.opts.id) then return false end
        local spec = SIDES[edge.side]
        HangFrom(entry, key, spec.point, spec.rel, box)
        return Edited()
    end

    -- Center: lets go of a screen edge (an anchor to a piece stays).
    function Snap.ClearScreenAnchor(entry)
        local link = entry and Anchor(entry)
        if not (link and edgeByKey[link.to]) then return false end
        LetGo(entry)
        return Edited()
    end

    -- What it hangs from, the side it is on, and its offset.
    function Snap.AnchorOf(entry)
        local link = entry and Anchor(entry)
        if not link then return end
        for side, spec in pairs(SIDES) do
            if GrowPoint(entry, spec.point) == link.point and GrowPoint(entry, spec.rel) == link.rel then
                return link.to, side, link.x or 0, link.y or 0
            end
        end
        return link.to, nil, link.x or 0, link.y or 0
    end

    function Snap.SetAnchorOffset(entry, x, y)
        local link = entry and Anchor(entry)
        if not link then return false end
        if Blocked(Moving(entry)) then
            Refuse(entry, IN_COMBAT)
            return false
        end
        link.x, link.y = x or link.x, y or link.y
        FollowAll()
        SaveFollowed()
        Core.EditModeMoved()
        return true
    end

    -- Not anchored any more: it stays where it is.
    function Snap.Unanchor(entry)
        if not (entry and Anchor(entry)) then return false end
        LetGo(entry)
        return Edited()
    end

    ---------------------------------------------------------------------------
    -- Anchored to start with: made once each from where they are, remembered
    -- (placing.anchoredByDefault) so one let go of stays let go; Reset remakes it
    ---------------------------------------------------------------------------

    local DEFAULT_ANCHORS = {
        { "focus", "player" }, { "pet", "player" }, { "cooldowns", "player" },
        { "targettarget", "target" }, { "threat", "target" },
        { "fsr", "castbar" }, { "swing", "fsr" },
        { "petbar", "bar2" }, { "stance", "bar1" },
    }

    local function MadeByDefault() return Saved("anchoredByDefault") end

    -- Answers whether any is still to be made (a piece not laid out yet).
    function Snap.AnchorDefaults()
        local made, pending = MadeByDefault(), false
        for _, pair in ipairs(DEFAULT_ANCHORS) do
            local id = pair[1]
            local entry, target = byId[id], byId[pair[2]]
            if not made[id] and entry and target then
                -- Anchored already, or it can't be: done too.
                if LinkOf(id) or AnchorRefusal(entry, target) or HangBeside(entry, target) then
                    made[id] = true
                else
                    pending = true
                end
            end
        end
        return pending
    end

    -- Every half second until every piece is laid out (modules place theirs as the world loads).
    local since, tries = 0, 0
    Snap.ScheduleDefaults = Core.Waker(function(elapsed)
        since = since + elapsed
        if since < 0.5 then return true end
        since, tries = 0, tries + 1
        if Snap.AnchorDefaults() and tries < 20 then return true end
        tries = 0
        return false
    end)

    function Snap.ReanchorAfterReset(entry)
        local id = entry.opts.id
        if id then MadeByDefault()[id] = nil end
        if Snap.AnchorDefaults() then Snap.ScheduleDefaults() end
        Core.DefaultPlaces.Place(id)
    end

    ---------------------------------------------------------------------------
    -- Movers (EllesmereUI's, in the addon's look, nothing animated): dark, gold
    -- outline (white under the mouse, selected or snapped to), name orange while
    -- anchored, place in the corner; smaller over bigger; Shift+Right-click hides
    ---------------------------------------------------------------------------

    local movers = {}               -- entry -> its mover
    Snap.movers = movers

    Snap.STRATA = "DIALOG"
    Snap.MOVER_LEVEL = 600
    local ANCHORED = { 1, 0.7, 0.3 }
    local LABEL_ANCHORED = { ANCHORED[1], ANCHORED[2], ANCHORED[3], 0.85 }
    local LABEL_PLAIN = { 1, 1, 1, 0.75 }
    local OUTLINE_LIT = { 1, 1, 1, 0.9 }
    local OUTLINE_REST = { Style.GOLD[1], Style.GOLD[2], Style.GOLD[3], 0.6 }
    local PICK_TEXT = {
        w = "Click any element\nto match its width",
        h = "Click any element\nto match its height",
        anchor = "Click any element\nto anchor to it",
    }

    local function W() return Core.Widgets end      -- loads after this file

    -- A mover's look, Options\Unlock.lua's boxes too: dark, outlined, its name in the middle
    -- (on `labels`, else on itself).
    function Snap.MoverLook(frame, labels)
        local bg = Style.WINDOW_BACKGROUND
        frame.bg = frame:CreateTexture(nil, "BACKGROUND")
        frame.bg:SetAllPoints(frame)
        frame.bg:SetColorTexture(bg[1], bg[2], bg[3], 0.95)
        frame.outline = W().Border(frame, OUTLINE_REST)
        frame.label = W().Text(labels or frame, 10, LABEL_PLAIN)
        frame.label:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.label:SetJustifyH("CENTER")
    end

    -- Its outline white under the mouse (selected, snapped to), else gold.
    function Snap.Light(frame, lit)
        local colour = lit and OUTLINE_LIT or OUTLINE_REST
        if frame.outline.colour ~= colour then W().TintBorder(frame.outline, colour) end
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
        local labels = CreateFrame("Frame", nil, mover)
        labels:SetAllPoints(mover)
        labels:SetFrameLevel(mover:GetFrameLevel() + 3)
        Snap.MoverLook(mover, labels)
        mover.wash = mover:CreateTexture(nil, "ARTWORK")
        mover.wash:SetAllPoints(mover)
        mover.wash:SetColorTexture(1, 1, 1, 1)
        mover.wash:SetAlpha(0.10)
        mover.wash:Hide()
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
                if IsShiftKeyDown() then
                    -- Hidden, and not snapped to, until Unlock Mode closes.
                    hiddenForNow[entry] = true
                    if selected == entry then Snap.Deselect() end
                    self.hovered, self.pressed = false, false
                    self:Hide()
                else
                    Snap.Select(entry)
                    Snap.OpenCog(entry)
                end
                return
            end
            if button ~= "LeftButton" or not self.pressed then return end
            self.pressed = false
            local wasDragging = drag ~= nil and drag.entry == entry
            if Snap.Stop(entry.frame) then
                if entry.opts.save then entry.opts.save() end
            elseif wasDragging then
                Snap.Clicked(entry, self.wasSelected)       -- a click, not a drag
            end
        end)
        mover:SetScript("OnEnter", function(self) self.hovered = true end)
        mover:SetScript("OnLeave", function(self) self.hovered = false end)
        movers[entry] = mover
        return mover
    end

    -- Its mover over `l`, `r`, `t`, `b`, in its state; answers its layout item.
    local function LayOutMover(entry, l, r, t, b)
        local w = W()
        local mover = movers[entry] or NewMover(entry)
        local isSelected = selected == entry
        local picker = picking ~= nil and picking.entry == entry
        local width, height = r - l, t - b

        mover.label:SetText(NameOf(entry))
        w.SetTextColour(mover.label, Anchor(entry) and LABEL_ANCHORED or LABEL_PLAIN)
        mover:ClearAllPoints()
        mover:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (l + r) / 2, (t + b) / 2)
        mover:SetSize(width, height)
        if picker then
            mover.pick:SetWidth(math.max(60, width - 8))
            mover.pick:SetText(PICK_TEXT[picking.axis])
        end
        mover.pick:SetShown(picker)
        mover.label:SetShown(not picker)

        Snap.Light(mover, mover.hovered or mover:IsMouseOver() or isSelected or mover.snapping
            or (drag and drag.moved and drag.entry == entry))
        mover.wash:SetShown(isSelected)

        local x, y = Snap.PositionOf(entry)
        if x then mover.coords:SetFormattedText("%d, %d", Whole(x), Whole(y)) end
        mover.coords:SetShown(x ~= nil)
        mover:Show()
        local item = mover.layout or { frame = mover, entry = entry }
        mover.layout = item
        item.area = width * height
        return item
    end

    -- Anchor links: an orange line from an anchored piece's middle to its anchor's,
    -- while either is under the mouse, selected or dragged.
    local lineFrame
    local lines = {}

    local function Active(entry)
        if not entry then return false end
        local mover = movers[entry]
        if mover and mover:IsShown() and (mover.hovered or mover:IsMouseOver()) then return true end
        return selected == entry or (drag ~= nil and drag.moved and drag.entry == entry)
    end

    local function DrawLines()
        if not lineFrame then
            lineFrame = CreateFrame("Frame", nil, UIParent)
            lineFrame:SetAllPoints(UIParent)
            lineFrame:SetFrameStrata(Snap.STRATA)
            lineFrame:SetFrameLevel(Snap.MOVER_LEVEL - 1)
            lineFrame:EnableMouse(false)
        end
        local used = 0
        for _, entry in ipairs(entries) do
            local link = Anchor(entry)
            local mover = movers[entry]
            -- Measured only when a line is wanted: this runs every frame.
            local bl, br, bt, bb, pl, pr, pt, pb
            if link and mover and mover:IsShown() and (Active(entry) or Active(byId[link.to])) then
                bl, br, bt, bb = Edges(entry)
                if bl then pl, pr, pt, pb = ParentEdges(link.to) end
            end
            if pl then
                used = used + 1
                local line = lines[used]
                if not line then
                    line = lineFrame:CreateLine(nil, "ARTWORK")
                    line:SetColorTexture(ANCHORED[1], ANCHORED[2], ANCHORED[3], 0.75)
                    lines[used] = line
                end
                line:SetThickness(3 * Pixel())
                line:SetStartPoint("BOTTOMLEFT", UIParent, (bl + br) / 2, (bt + bb) / 2)
                line:SetEndPoint("BOTTOMLEFT", UIParent, (pl + pr) / 2, (pt + pb) / 2)
                line:Show()
            end
        end
        for spare = used + 1, #lines do lines[spare]:Hide() end
        lineFrame:Show()
    end

    ---------------------------------------------------------------------------
    -- Laying it all out, every frame while Unlock Mode is open
    ---------------------------------------------------------------------------

    -- The party's column has one mover, its first frame's.
    local function OwnsMover(entry)
        return entry.opts.group ~= "party" or byId[entry.opts.id] == entry
    end

    local function HideMovers()
        for _, mover in pairs(movers) do
            mover.hovered, mover.pressed = false, false
            mover:Hide()
        end
        if lineFrame then lineFrame:Hide() end
        ShowCentreLines(nil)
    end

    local shown = {}                -- the movers shown this frame
    local function Bigger(a, b) return a.area > b.area end

    local function LayOutMovers()
        if previewing then
            HideMovers()
            return
        end
        ShowCentreLines((drag and drag.entry) or selected)
        local snapTo = drag and drag.moved and drag.snap and drag.snap.target
        for entry, mover in pairs(movers) do mover.snapping = entry == snapTo end
        for index = #shown, 1, -1 do shown[index] = nil end
        for _, entry in ipairs(entries) do
            local l, r, t, b
            if OwnsMover(entry) and not hiddenForNow[entry] and entry.frame:IsVisible() then
                l, r, t, b = Edges(entry)
            end
            if l then
                shown[#shown + 1] = LayOutMover(entry, l, r, t, b)
            elseif movers[entry] then
                movers[entry]:Hide()
            end
        end
        -- Smaller over bigger; the selected or dragged one over all.
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

    -- Preview: no movers or lines (nor, in Options\Unlock.lua, boxes, grid or
    -- dimmer); nothing picked up. Off whenever Unlock Mode opens or closes.
    function Snap.Previewing() return previewing end

    function Snap.SetPreview(on)
        on = on and true or false
        if on == previewing then return end
        if on then Snap.Cancel() end
        previewing = on
        if Core.IsUnlocked() then LayOutMovers() end
    end

    local driver

    local function Drive()
        if not Core.IsUnlocked() then
            Snap.UpdateGameLook()
            return
        end
        LayOutMovers()
        Snap.OnDrive()
    end

    -- The core calls this whenever Unlock Mode may have opened or closed.
    function Snap.UpdateGameLook()
        local on = Core.IsUnlocked()
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
        Snap.ForgetGameFrames()
        HideMovers()
        if keys then KeysOn() end
    end

    ---------------------------------------------------------------------------
    -- Settings
    ---------------------------------------------------------------------------

    function Snap.Normalise(db)
        if type(db.snap) ~= "boolean" then db.snap = true end
        -- Older files: only anchors made on purpose, and none to the game's frames.
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
        Core.UpdateGrid()
        Snap.ScheduleDefaults()
        Core.DefaultPlaces.Schedule()   -- a reset or a new character: the default layout, once
    end
    Snap.Init = Snap.Refresh

    Core:RegisterModule(Snap)
end
