-- The quest tracker in the addon's look: the headers' strips gone for the name
-- band and hairlines, the collapse buttons a flat minus and plus that follow
-- the game's collapse state, the quest buttons smaller, no dashes, item
-- buttons and progress bars in the bars' look - and not one field written on
-- the game's frames.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

-------------------------------------------------------------------------------
-- The game's tracker, as Blizzard_ObjectiveTracker builds it - loaded before
-- the addon, its sections added when the world is first entered.
-------------------------------------------------------------------------------

local function Texture(parent, layer)
    local t = newWidget("Texture", parent)
    t.alpha, t.layer = 1, layer or "ARTWORK"
    parent.regions[#parent.regions + 1] = t
    return t
end

local function MinimizeButton(parent)
    local b = newWidget("Button", parent)
    b.NormalTexture, b.PushedTexture, b.HighlightTexture = Texture(b), Texture(b), Texture(b)
    function b:GetNormalTexture() return self.NormalTexture end
    function b:GetPushedTexture() return self.PushedTexture end
    function b:GetHighlightTexture() return self.HighlightTexture end
    return b
end

-- A header; a section's has the appear animation's glow and shine too.
local function Header(parent, section)
    local h = newWidget("Frame", parent)
    h.width, h.height = 260, section and 26 or 32
    h.Background = Texture(h, "BACKGROUND")
    h.Text = h:CreateFontString()
    if section then
        h.Glow, h.Shine = Texture(h, "OVERLAY"), Texture(h, "ARTWORK")
    end
    h.MinimizeButton = MinimizeButton(h)
    function h:SetCollapsed(collapsed) self.atlasCollapsed = collapsed end
    return h
end

ObjectiveTrackerFrame = newWidget("Frame", UIParent)
local tracker = ObjectiveTrackerFrame
tracker.Header = Header(tracker)
tracker.modules, tracker.isCollapsed = {}, false
function tracker:IsCollapsed() return self.isCollapsed end
function tracker:AddModule(module) table.insert(self.modules, module) end
-- The opacity background: the game's nine-slice, its alpha the Edit Mode
-- setting's, written only by SetBackgroundAlpha.
tracker.NineSlice = newWidget("Frame", tracker)
function tracker:SetBackgroundAlpha(alpha) self.NineSlice:SetAlpha(alpha) end
function tracker:SetCollapsed(collapsed)
    self.isCollapsed = collapsed
    self.Header:SetCollapsed(collapsed)
end
function tracker:ToggleCollapsed() self:SetCollapsed(not self.isCollapsed) end
-- Edit Mode's box, as EditModeObjectiveTrackerSystemMixin anchors it: the
-- whole frame, 30 out on the left.
tracker.Selection = newWidget("Frame", tracker)
function tracker:AnchorSelectionFrame()
    self.Selection:ClearAllPoints()
    self.Selection:SetPoint("TOPLEFT", self, "TOPLEFT", -30, 0)
    self.Selection:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
end
function tracker:UpdateHeaderPosition() end
-- The game working the clamp out from the box as it anchored it: none.
function tracker:UpdateClampOffsets() self:SetClampRectInsets(0, 0, 0, 0) end
ObjectiveTrackerManager = { backgroundAlpha = 0 }
function ObjectiveTrackerManager:SetOpacity(opacity)
    self.backgroundAlpha = (opacity or 0) / 100
    tracker:SetBackgroundAlpha(self.backgroundAlpha)
end

local function Module()
    local m = newWidget("Frame", tracker)
    m.Header = Header(m, true)
    m.usedBlocks, m.isCollapsed, m.layouts = {}, false, 0
    function m:IsCollapsed() return self.isCollapsed end
    function m:ToggleCollapsed()
        self.isCollapsed = not self.isCollapsed
        self.Header:SetCollapsed(self.isCollapsed)
    end
    function m:EndLayout() self.layouts = self.layouts + 1 end
    function m:GetExistingBlock(id)
        for _, blocks in pairs(self.usedBlocks) do
            if blocks[id] then return blocks[id] end
        end
    end
    return m
end

local quests = Module()
local achievements = Module()

-- A quest's block: its quest button and two objective lines with dashes.
local function Line(block)
    local line = newWidget("Frame", block)
    line.Dash, line.Text = line:CreateFontString(), line:CreateFontString()
    line.Dash.alpha = 1
    return line
end
local block = newWidget("Frame", quests)
block.poiButton = newWidget("Button", block)
block.usedLines = { [1] = Line(block), [2] = Line(block) }
quests.usedBlocks.ObjectiveTrackerQuestPOIBlockTemplate = { [101] = block }

-- A quest item button (QuestObjectiveItemButtonTemplate).
local item = newWidget("Button", block)
item.template = "QuestObjectiveItemButtonTemplate"
item.icon = Texture(item, "BORDER")
item.Cooldown = newWidget("Cooldown", item)
item.NormalTexture, item.PushedTexture, item.HighlightTexture = Texture(item), Texture(item), Texture(item)
function item:GetNormalTexture() return self.NormalTexture end
function item:GetPushedTexture() return self.PushedTexture end
function item:GetHighlightTexture() return self.HighlightTexture end
-- And the find-group eye, which is left alone.
local eye = newWidget("Button", block)
eye.template = "QuestObjectiveFindGroupButtonTemplate"
quests.usedRightEdgeFrames = { a = item, b = eye }

-- A progress bar: the skill-bar frame, a navy background, the game's blue.
local progress = newWidget("Frame", block)
local bar = newWidget("StatusBar", progress)
progress.Bar = bar
bar.width, bar.height = 180, 15
bar.BorderLeft, bar.BorderRight, bar.BorderMid = Texture(bar), Texture(bar), Texture(bar)
local navy = Texture(bar, "BACKGROUND")
local fill = bar:GetStatusBarTexture()
fill.layer = "BACKGROUND"
function fill:GetDrawLayer() return self.layer end
bar:SetStatusBarColor(0.26, 0.42, 1)
quests.usedProgressBars = { [101] = progress }

-- Every key each of the game's objects has, so any the addon adds shows.
local gameObjects = {
    tracker, tracker.NineSlice, tracker.Selection, tracker.Header, tracker.Header.MinimizeButton, quests, quests.Header,
    quests.Header.MinimizeButton, block, block.poiButton, block.usedLines[1],
    item, eye, progress, bar,
}
local keysBefore = {}
for _, object in ipairs(gameObjects) do
    local keys = {}
    for key in pairs(object) do keys[key] = true end
    keysBefore[object] = keys
end

LoadAddon()
Login()
-- The game adds its sections as the world is entered.
tracker:AddModule(quests)
tracker:AddModule(achievements)

local Objectives = DogsForeverUI.Objectives

Section("the tracker's header")
check("the bronze strip is hidden", tracker.Header.Background.shown == false)
local title = Objectives.parts[tracker.Header]
check("the gold line is drawn, no black band", title and title.strip.line and not title.strip.band)
local line = title.strip.line
check("the line is solid, then fades out on the right",
    line.solid.vertexColor and line.solid.vertexColor[4] == DogsForeverUI.Frames.UnitPlate.NAME_BAND.lineAlpha
    and line.fade.gradient ~= nil)
check("the line is the header's own region, under its title",
    line.solid.parent == tracker.Header and line.solid.layer == "BACKGROUND")

Section("the collapse buttons")
local button = tracker.Header.MinimizeButton
check("the game's button art is faded",
    button.NormalTexture.alpha == 0 and button.PushedTexture.alpha == 0 and button.HighlightTexture.alpha == 0)
local glyph = title.glyph
check("a minus, no plus, while open", glyph.across.shown and not glyph.upright.shown)
tracker:ToggleCollapsed()
check("a plus once collapsed", glyph.upright.shown == true)
check("the game still swapped its own atlas", tracker.Header.atlasCollapsed == true)
tracker:ToggleCollapsed()
check("a minus again", glyph.upright.shown == false)
-- Gold at rest, white under the mouse (the player, 2026-10-01: the muted
-- border gold was lost against the world).
local function Coloured(colour)
    local c = glyph.across.vertexColor
    return c[1] == colour[1] and c[2] == colour[2] and c[3] == colour[3]
end
local gold, white = DogsForeverUI.Style.GOLD, DogsForeverUI.Style.TEXT_COLOR
check("gold at rest", Coloured(gold))
button.scripts.OnEnter = nil
for _, fn in ipairs(button.hooks.OnEnter or {}) do fn(button) end
check("white under the mouse", Coloured(white))
for _, fn in ipairs(button.hooks.OnLeave or {}) do fn(button) end
check("back to gold after", Coloured(gold))

Section("a section's header")
check("its strip, glow and shine are hidden",
    quests.Header.Background.shown == false and quests.Header.Glow.shown == false
    and quests.Header.Shine.shown == false)
local section = Objectives.parts[quests.Header]
check("a hairline only, fainter", section.strip.line and not section.strip.band
    and section.strip.line.solid.vertexColor[4] == Objectives.SECTION_LINE)
quests:ToggleCollapsed()
check("its button follows its own collapse", section.glyph.upright.shown == true
    and title.glyph.upright.shown == false)
quests:ToggleCollapsed()
check("every section added gets it", Objectives.parts[achievements.Header] ~= nil)

Section("after a layout")
quests:EndLayout()
check("the game's layout still ran", quests.layouts == 1)
check("the quest button is smaller", block.poiButton.scale == Objectives.POI_SCALE)
check("no dashes", block.usedLines[1].Dash.alpha == 0 and block.usedLines[2].Dash.alpha == 0)
local parts = DogsForeverUI.Menus.ActionButtons.parts[item]
check("the item button is in the action buttons' look", parts ~= nil
    and item.NormalTexture.alpha == 0 and item.icon.allPointsTo == parts.inner)
check("the find-group eye is left alone", DogsForeverUI.Menus.ActionButtons.parts[eye] == nil)
check("the progress bar's frame and navy are faded",
    bar.BorderLeft.alpha == 0 and bar.BorderMid.alpha == 0 and navy.alpha == 0)
check("its fill is not", fill.alpha ~= 0)
check("flat, in the game's blue", fill.texture == DogsForeverUI.Style.FLAT_TEXTURE
    and bar.statusColor[1] == 0.26 and bar.statusColor[3] == 1)
check("with a border and background", Objectives.parts[bar] and Objectives.parts[bar].border
    and Objectives.parts[bar].bg)

Section("again, and pooled frames handed round")
local regions = #tracker.Header.regions
local barRegions = #bar.regions
block.poiButton.scale = 1          -- the pool handed it to a new block
quests:EndLayout()
check("the quest button is made smaller again", block.poiButton.scale == Objectives.POI_SCALE)
check("nothing made twice", #tracker.Header.regions == regions and #bar.regions == barRegions)
Objectives.Apply()
check("a second apply adds nothing", #tracker.Header.regions == regions)

Section("an item button the game protects, in combat")
local protectedItem = newWidget("Button", block)
protectedItem.template, protectedItem.protected = "QuestObjectiveItemButtonTemplate", true
protectedItem.icon = Texture(protectedItem, "BORDER")
quests.usedRightEdgeFrames.c = protectedItem
local wasInCombat = InCombatLockdown
InCombatLockdown = function() return true end
quests:EndLayout()
check("waits", DogsForeverUI.Menus.ActionButtons.parts[protectedItem] == nil)
InCombatLockdown = wasInCombat
Fire("PLAYER_REGEN_ENABLED")
check("styled once the fight ends", DogsForeverUI.Menus.ActionButtons.parts[protectedItem] ~= nil)

-- Which frame and point the box's edge `point` hangs from.
local function Anchor(frame, point)
    for _, a in ipairs(frame.anchors or {}) do
        if a[1] == point then return a[2], a[3], a[4], a[5] end
    end
end

Section("the opacity background")
local box = Objectives.box
check("the box is made, the tracker's child at its level, under the sections",
    box and box.frame.parent == tracker and box.frame.frameLevel == tracker:GetFrameLevel())
check("in the frames' look: their background and border",
    box.bg.colorTexture and box.bg.colorTexture[4] == DogsForeverUI.Style.BACKGROUND_COLOR[4]
    and box.border ~= nil)
check("opacity 0: nothing shows", box.frame.alpha == 0)
ObjectiveTrackerManager:SetOpacity(100)
check("the setting drives the box", box.frame.alpha == 1)
check("and the game's nine-slice stays faded", tracker.NineSlice.alpha == 0)
ObjectiveTrackerManager:SetOpacity(40)
check("in between too", math.abs(box.frame.alpha - 0.4) < 1e-6 and tracker.NineSlice.alpha == 0)
local rel, relPoint = Anchor(box.frame, "BOTTOM")
check("open: down to where the game's background ends", rel == tracker.NineSlice and relPoint == "BOTTOM")
local _, _, left = Anchor(box.frame, "LEFT")
local _, _, right = Anchor(box.frame, "RIGHT")
check("out past both sides, the quest buttons inside",
    left == -Objectives.BOX_LEFT and right == Objectives.BOX_RIGHT)
check("from the header's top", (Anchor(box.frame, "TOP")) == tracker.Header)
tracker:ToggleCollapsed()
rel = Anchor(box.frame, "BOTTOM")
check("collapsed: round the header only", rel == tracker.Header and title.glyph.upright.shown)
tracker:ToggleCollapsed()
check("open again", (Anchor(box.frame, "BOTTOM")) == tracker.NineSlice)

Section("Edit Mode's box fits what is drawn")
-- A moved tracker, as tall as Edit Mode's Height setting, round a short list.
tracker.left, tracker.right, tracker.top, tracker.bottom = 0, 260, 1000, 200
tracker.Header.bottom = 968
box.frame.left, box.frame.right, box.frame.top, box.frame.bottom = -14, 268, 1000, 800
tracker:AnchorSelectionFrame()
local out = (box.border.out or DogsForeverUI.Style.BORDER_INSET) + Objectives.EDIT_PADDING
local p1, p2 = tracker.Selection.anchors[1], tracker.Selection.anchors[2]
check("by its corners from the tracker's own, as Edit Mode reads them",
    tracker.Selection:GetNumPoints() == 2 and p1[1] == "TOPLEFT" and p1[2] == tracker
    and p2[1] == "BOTTOMRIGHT" and p2[2] == tracker)
check("round the box and its border, a little out",
    p1[4] == -14 - out and p1[5] == out and p2[4] == 8 + out and p2[5] == 600 - out,
    table.concat({ p1[4], p1[5], p2[4], p2[5] }, ", "))
local function ClampIsBox()
    local c = tracker.clampInsets
    return c and c[1] == p1[4] and c[2] == p2[4] and c[3] == p1[5] and c[4] == p2[5]
end
check("and its clamp is that box: Edit Mode keeps it on screen by the box, not the tall frame",
    ClampIsBox())
tracker:UpdateClampOffsets()
check("the game working its clamp out again: the box's again after", ClampIsBox())
box.frame.bottom = 990             -- nothing below the header yet
tracker:UpdateHeaderPosition()
p2 = tracker.Selection.anchors[2]
check("never shorter than the header", p2[5] == 768 - out)

Section("auto-hide")
local DB = DogsForeverUI.Menus.db
local Bars = DogsForeverUI.Menus.ActionBars
mouseOver = {}
tracker.alpha = 1
check("on to start", DB.fadeObjectives == true)
for _ = 1, 30 do Tick(0.2) end
check("fades away with the mouse elsewhere", tracker.alpha == 0)
mouseOver[tracker] = true
for _ = 1, 5 do Tick(0.2) end
check("the frame's own (screen-tall) rect does not count", tracker.alpha == 0)
mouseOver[tracker] = nil
mouseOver[box.frame] = true
for _ = 1, 5 do Tick(0.2) end
check("the mouse over what is drawn brings it back", tracker.alpha == 1)
mouseOver = {}
for _ = 1, 30 do Tick(0.2) end
tracker.alpha = 1                 -- the game bringing its managed frames in
Tick(0.1)
check("the game setting it back up is undone", tracker.alpha == 0)

-- A quest progressed while it is hidden: nothing shown of it (that feature
-- was removed, 2026-10-03).
check("no switch for showing a progressed quest", DB.showProgressedQuest == nil)
Fire("QUEST_WATCH_UPDATE", 101)
Tick(0.5)
check("a quest progressed while hidden: still hidden", block.ignoreParentAlpha ~= true and tracker.alpha == 0)

DB.fadeObjectives = false
DogsForeverUI.Menus.Refresh()
Tick(0)
check("unticked: back as it was", tracker.alpha == 1)

Section("no field on the game's frames")
-- The harness keeps a widget's state (shown, alpha, scale, points...) on the
-- stand-in itself; in game that is the client's. Anything else is the addon's.
local HARNESS = {
    alpha = true, shown = true, scale = true, points = true, anchors = true,
    allPointsTo = true, vertexColor = true, texture = true, texCoord = true,
    blendMode = true, colorTexture = true, statusTexture = true, statusColor = true,
    frameLevel = true, hooks = true, scripts = true, regions = true, gradient = true,
    width = true, height = true, atlasCollapsed = true, layouts = true, isCollapsed = true,
    left = true, right = true, top = true, bottom = true,   -- the test's own rects
    clampInsets = true,                                     -- SetClampRectInsets
    ignoreParentAlpha = true,                               -- SetIgnoreParentAlpha
}
local added = {}
for _, object in ipairs(gameObjects) do
    for key in pairs(object) do
        if not keysBefore[object][key] and not HARNESS[key] then
            added[#added + 1] = tostring(key)
        end
    end
end
check("none added", #added == 0, table.concat(added, ", "))

Summary()
