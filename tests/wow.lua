-- WoW API stubs, enough to load the whole of Dog's Forever UI outside the game,
-- give it units to draw, send it events and step its frames. Shared by every
-- test file here; each one loads this first:
--
--     assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)
--
-- The whole addon is loaded, not a stub of it: the secure click buttons, the
-- secret-value handling and what is done to the game's own frames are exactly
-- the parts that cannot be judged by reading.
--
-- Time is controlled rather than real, so the same run gives the same answer
-- every time.

ADDON_PATH, TOC_TEXT = ...

-- WoW Forever (Blizzard_ProjectConstants); a test may set WOW_PROJECT_ID to
-- WOW_PROJECT_MAINLINE before loading the addon to play retail.
WOW_PROJECT_MAINLINE, WOW_PROJECT_CAMELOT = 1, 18
WOW_PROJECT_ID = WOW_PROJECT_ID or WOW_PROJECT_CAMELOT

checksRun, checksFailed = 0, 0

function check(label, condition, detail)
    checksRun = checksRun + 1
    if condition then
        print("  ok   " .. label)
    else
        checksFailed = checksFailed + 1
        print("  FAIL " .. label .. (detail ~= nil and (" :: " .. tostring(detail)) or ""))
    end
end

-------------------------------------------------------------------------------
-- Widgets.
-------------------------------------------------------------------------------

Widget = {}
Widget.__index = Widget

function newWidget(kind, parent)
    return setmetatable({
        kind = kind, parent = parent, shown = true, enabled = true,
        points = {}, scripts = {}, hooks = {}, events = {}, regions = {},
        width = 0, height = 0, text = "", checked = false, value = 0,
        min = 0, max = 0, scale = 1,
    }, Widget)
end

-- As in game, a frame given a mouse script takes the mouse, whatever
-- EnableMouse said before; given a key script, the keyboard; a wheel script, the wheel.
local MOUSE_SCRIPTS = { OnMouseDown = true, OnMouseUp = true, OnEnter = true, OnLeave = true,
                        OnMouseWheel = true, OnDragStart = true }
local KEY_SCRIPTS = { OnKeyDown = true, OnKeyUp = true }
function Widget:SetScript(name, func)
    self.scripts[name] = func
    if func and MOUSE_SCRIPTS[name] and self.kind == "Frame" then self.mouseEnabled = true end
    if func and KEY_SCRIPTS[name] then self.keyboardEnabled = true end
    if func and name == "OnMouseWheel" then self.wheelEnabled = true end
end
function Widget:GetScript(name) return self.scripts[name] end
function Widget:HasScript() return true end
function Widget:HookScript(name, func)
    self.hooks[name] = self.hooks[name] or {}
    table.insert(self.hooks[name], func)
end
function Widget:RegisterEvent(event) self.events[event] = true end
-- (Up to two units, as the game's: a second registration replaces the first.)
function Widget:RegisterUnitEvent(event, unit, unit2)
    self.events[event] = unit and { [unit] = true, [unit2 or unit] = true } or true
end
function Widget:UnregisterEvent(event) self.events[event] = nil end
function Widget:UnregisterAllEvents() self.events = {} end
function Widget:RegisterForDrag() end
function Widget:SetMovable() end
function Widget:SetResizable() end
function Widget:SetUserPlaced(v) self.userPlaced = v end
function Widget:SetClampedToScreen(v) self.clamped = v end
function Widget:EnableMouse(v) self.mouseEnabled = v end
function Widget:IsMouseEnabled() return self.mouseEnabled and true or false end
function Widget:SetHitRectInsets(l, r, t, b) self.hitInsets = { l, r, t, b } end
function Widget:EnableMouseWheel(v) self.wheelEnabled = v and true or false end
-- The keyboard: whether a frame takes keys, and whether the last one it was
-- handed goes on to the game.
function Widget:EnableKeyboard(v) self.keyboardEnabled = v and true or false end
function Widget:IsKeyboardEnabled() return self.keyboardEnabled == true end
function Widget:SetPropagateKeyboardInput(v)
    if inCombat then error("SetPropagateKeyboardInput() is blocked in combat", 2) end
    self.propagates = v and true or false
end
function Widget:IsProtected() return self.protected == true end
function Widget:StartMoving() self.moving = true end
function Widget:StopMovingOrSizing() self.moving = false end
function Widget:SetFrameStrata(v) self.strata = v end
function Widget:GetFrameStrata() return self.strata or "MEDIUM" end
function Widget:SetIgnoreParentAlpha(v) self.ignoreParentAlpha = v end
function Widget:GetParent() return self.parent end
function Widget:SetParent(p) self.parent = p end
function Widget:SetWidth(v) self.width = v end
function Widget:SetHeight(v) self.height = v end
function Widget:SetSize(w, h) self.width, self.height = w, h end
-- Hung off an add-on aura container with groups while auras are secret (`secretAnchoring`,
-- a fight): its size comes back secret, as in game (SecretWhenAnchoringSecret).
local function AnchoredSecret(self)
    local to = secretAnchoring and self.points and self.points[2]
    return type(to) == "table" and to.auraGroupOrder ~= nil and #to.auraGroupOrder > 0
end
function Widget:GetWidth()
    if AnchoredSecret(self) then return Unreadable("the width of a frame hung off an aura container") end
    return self.width
end
function Widget:GetHeight()
    if AnchoredSecret(self) then return Unreadable("the height of a frame hung off an aura container") end
    return self.height
end
function Widget:GetName() return self.name end
-- WHAT THE GAME REFUSES. A secure button is protected, and so is the frame it
-- is a child of or anchored to: that is how a plate becomes protected. In
-- combat, showing, hiding, moving or resizing a protected frame from addon code
-- is refused, and the game counts every refusal against the addon - the
-- "Interface actions failed because of this AddOn" line in the addon list. The
-- refused call does nothing, exactly as in game, and is recorded in `blocked`.
-- The secure unit watch is the one caller allowed to, as it is in game.
blocked = {}
local secureCaller = false
local function Refused(frame, what)
    if inCombat and frame.protected and not secureCaller then
        blocked[#blocked + 1] = tostring(frame.name) .. ":" .. what
        return true
    end
end

function Widget:Show()
    if Refused(self, "Show") then return end
    local was = self.shown
    self.shown = true
    if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
    for _, hook in ipairs(self.hooks.OnShow or {}) do hook(self) end
end
function Widget:Hide()
    if Refused(self, "Hide") then return end
    local was = self.shown
    self.shown = false
    if not was then return end
    if self.scripts.OnHide then self.scripts.OnHide(self) end
    for _, hook in ipairs(self.hooks.OnHide or {}) do hook(self) end
end
function Widget:IsShown() return self.shown end
function Widget:Enable() self.enabled = true end
function Widget:Disable() self.enabled = false end
function Widget:IsEnabled() return self.enabled end
function Widget:SetEnabled(v) self.enabled = v and true or false end
-- What keeps a clamped frame on screen: its rect pulled in (or out) by these.
function Widget:SetClampRectInsets(l, r, t, b) self.clampInsets = { l, r, t, b } end
function Widget:SetAllPoints(relative) self.allPointsTo = relative or self.parent end
function Widget:ClearAllPoints() self.points = {}; self.anchors = {} end
-- A frame the game forbids to add-ons (set `forbidden`): only this may be asked of it.
function Widget:IsForbidden() return self.forbidden == true end
function Widget:SetPoint(point, a, b, c, d)
    -- The game refuses to anchor to anything that is not a frame or region:
    -- "SetPoint(): Wrong object type for function". A plain Lua table (no
    -- metatable: not a widget, not one of the game's frames) is refused here
    -- too - it once was, in game, when a buff bar anchored to its parts table.
    if type(a) == "table" and getmetatable(a) == nil then
        error(tostring(self.kind) .. ":SetPoint(): Wrong object type for function", 2)
    end
    -- Once an add-on aura container has a group it carries
    -- UntrustedLayoutScriptExecution, which reaches "anything anchored to
    -- this object" (ForbiddenAspectConstantsDocumentation): an add-on frame
    -- may not be anchored to it (Blizzard_CustomAuraContainer.lua says so) -
    -- unless made with DisableUntrustedLayoutScriptsTemplate, opted in to that aspect.
    if type(a) == "table" and a.auraGroupOrder and #a.auraGroupOrder > 0
       and self.template ~= "DisableUntrustedLayoutScriptsTemplate" then
        error(tostring(self.kind) .. ":SetPoint(): may not anchor to an aura container with groups", 2)
    end
    if type(a) == "number" or a == nil then
        self.points = { point, self.parent, point, a or 0, b or 0 }
    else
        self.points = { point, a, b, c or 0, d or 0 }
    end
    -- Every anchor, not just the last one: a frame pinned by two corners has two,
    -- and which frame each one is pinned to is the thing worth asserting.
    self.anchors = self.anchors or {}
    self.anchors[#self.anchors + 1] = self.points
end
-- With an index, that anchor of a frame pinned by several, as in game.
function Widget:GetPoint(index)
    local p = (index and self.anchors and self.anchors[index]) or self.points
    return p[1] or "CENTER", p[2], p[3] or "CENTER", p[4] or 0, p[5] or 0
end
function Widget:GetNumPoints() return #(self.anchors or {}) end
function Widget:GetLeft() return self.left or 0 end
function Widget:GetTop() return self.top or 0 end
function Widget:GetBottom() return self.bottom or 0 end
function Widget:GetRight() return self.right or ((self.left or 0) + (self.width or 0)) end
function Widget:SetAlpha(v) self.alpha = v end
-- The client's own: it may look at a secret boolean, the addon may not.
function Widget:SetAlphaFromBoolean(v, ifTrue, ifFalse)
    self.alphaFrom = v
    local truth = (v == SECRET_TRUE) or (v == true)
    self.alpha = truth and ifTrue or ifFalse
end
-- As in game, a font string given text before it has a font raises.
local function NeedsFont(self)
    if self.kind == "FontString" and not (self.font or self.fontObject or self.inherits) then
        error("FontString:SetText(): Font not set", 3)
    end
end
function Widget:SetText(v) NeedsFont(self); self.text = v end
function Widget:SetFormattedText(fmt, ...) self.text = string.format(fmt, ...) end
function Widget:GetText() return self.text end
function Widget:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
function Widget:SetShadowOffset(x, y) self.shadowOffset = { x, y } end
function Widget:SetShadowColor(r, g, b, a) self.shadowColor = { r, g, b, a } end
function Widget:SetJustifyH(v) self.justifyH = v end
function Widget:SetJustifyV() end
-- The three calls that keep a label on one line. All recorded, because "never
-- two lines" is only enforceable by checking the addon asked for it.
function Widget:SetWordWrap(v) self.wordWrap = v end
function Widget:SetNonSpaceWrap(v) self.nonSpaceWrap = v end
function Widget:SetMaxLines(v) self.maxLines = v end
function Widget:SetFont(path, size, flags)
    self.font = { path, size, flags }
    return true
end
function Widget:GetFont()
    local f = self.font
    if not f then return nil end
    return f[1], f[2], f[3]
end
function Widget:SetFontObject(font) self.fontObject = font end
function Widget:SetTextHeight(height) self.textHeight = height end
-- Blizzard_Menu dropdown button: the generator is kept so a test can ask what
-- the menu would contain, and GenerateMenu re-runs it as the real one does.
function Widget:SetupMenu(generator)
    self.menuGenerator = generator
    self:GenerateMenu()
end
function Widget:GenerateMenu()
    if not self.menuGenerator then return end
    local root = { entries = {} }
    function root:CreateRadio(text, isSelected, setSelected, value)
        self.entries[#self.entries + 1] =
            { text = text, isSelected = isSelected, setSelected = setSelected, value = value }
    end
    function root:SetTag() end
    function root:SetMaximumWidth() end
    self.menuRoot = root
    self.menuGenerator(self, root)
end
function Widget:SetDefaultText(v) self.defaultText = v end
function Widget:SetChecked(v) self.checked = v and true or false end
function Widget:GetChecked() return self.checked end
function Widget:Click()
    self.checked = not self.checked
    if self.scripts.OnClick then self.scripts.OnClick(self) end
end
function Widget:SetScrollChild(c) self.scrollChild = c end
function Widget:GetScrollChild() return self.scrollChild end
function Widget:GetVerticalScroll() return self.scroll or 0 end
function Widget:SetVerticalScroll(v) self.scroll = v end
function Widget:GetHorizontalScroll() return self.hscroll or 0 end
function Widget:SetHorizontalScroll(v) self.hscroll = v end
function Widget:SetMinMaxValues(a, b) self.min, self.max = a, b end
function Widget:GetMinMaxValues() return self.min, self.max end
function Widget:SetValueStep(v) self.step = v end
function Widget:SetObeyStepOnDrag() end
function Widget:SetOrientation(o) self.orientation = o end
function Widget:GetOrientation() return self.orientation or "HORIZONTAL" end
function Widget:SetValue(v)
    self.value = v
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
end
function Widget:GetValue() return self.value end
function Widget:SetBackdrop() end
function Widget:SetBackdropColor(r, g, b, a) self.backdropColor = { r, g, b, a } end
function Widget:SetBackdropBorderColor() end
function Widget:SetTexture(v) self.texture, self.atlas = v, nil end     -- an atlas replaced, as in game
-- (An atlas answers its file, as in game.)
function Widget:GetTexture() return self.texture or (self.atlas and "atlas file " .. self.atlas) end
function Widget:SetColorTexture(r, g, b, a) self.colorTexture = { r, g, b, a } end
function Widget:SetVertexColor(r, g, b, a) self.vertexColor = { r, g, b, a } end
-- Picks one of two colours by a boolean that may be a secret, unlooked-at.
function Widget:SetVertexColorFromBoolean(value, ifTrue, ifFalse)
    self.vertexFromBoolean = { value = value, ifTrue = ifTrue, ifFalse = ifFalse }
end
-- The client's ColorMixin, as far as a gradient and coloured text need it.
local ColorMixin = {}
ColorMixin.__index = ColorMixin
function ColorMixin:WrapTextInColorCode(text)
    local function Byte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x%s|r"):format(Byte(self.r), Byte(self.g), Byte(self.b), text)
end
function CreateColor(r, g, b, a) return setmetatable({ r = r, g = g, b = b, a = a or 1 }, ColorMixin) end
function Widget:SetGradient(orientation, from, to)
    self.gradient = { orientation = orientation, from = from, to = to }
end
function Widget:SetTexCoord(...) self.texCoord = { ... } end
function Widget:SetBlendMode(mode) self.blendMode = mode end
function Widget:SetDesaturated(v) self.desaturated = v and true or false end
function Widget:SetDesaturation(v) self.desaturation = v end
-- A frame's layers drawn as one image before its alpha applies.
function Widget:SetFlattensRenderLayers(v) self.flattensRenderLayers = v end
-- Kept off the widget, as the game keeps them (no Lua field on a game texture).
tiling = setmetatable({}, { __mode = "k" })     -- region -> { horiz =, vert =, modes = }
local function Tiling(region)
    tiling[region] = tiling[region] or {}
    return tiling[region]
end
function Widget:SetHorizTile(v) Tiling(self).horiz = v end
function Widget:SetVertTile(v) Tiling(self).vert = v end
-- The game's (Blizzard_SharedXMLBase\TextureUtil.lua): an atlas, its address modes, tiled to match.
TextureKitConstants = { IgnoreAtlasSize = false, AddressModeClamp = 1, AddressModeWrap = 2 }
function SetTextureWithAddressModeOptions(region, asset, autoSize, addressModeU, addressModeV)
    region:SetAtlas(asset, autoSize)
    Tiling(region).modes = { addressModeU, addressModeV }
    region:SetHorizTile(addressModeU == TextureKitConstants.AddressModeWrap)
    region:SetVertTile(addressModeV == TextureKitConstants.AddressModeWrap)
end
function Widget:SetMultiLine() end
function Widget:SetAutoFocus() end
function Widget:SetMaxLetters() end
function Widget:SetCursorPosition() end
-- The one box with the keyboard, as in game.
focusedBox = nil
function Widget:SetFocus() focusedBox = self end
function Widget:HasFocus() return focusedBox == self end
function Widget:ClearFocus() if focusedBox == self then focusedBox = nil end end
function Widget:HighlightText() self.highlighted = true end
function Widget:SetTextInsets() end
function Widget:SetRotation(radians) self.rotation = radians end
function Widget:SetDrawLayer(layer, sublevel) self.layer, self.sublevel = layer, sublevel end
function Widget:SetTextScale(scale) self.textScale = scale end
function Widget:GetDrawLayer() return self.layer, self.sublevel end
function Widget:SetThumbTexture(texture) self.thumb = texture end
function Widget:GetThumbTexture() return self.thumb end
-- A button's fonts per state, and a font object (CreateFont).
function Widget:SetNormalFontObject(font) self.normalFont = font end
function Widget:SetHighlightFontObject(font) self.highlightFont = font end
function Widget:SetDisabledFontObject(font) self.disabledFont = font end
function CreateFont(name)
    local font = newWidget("Font")
    font.name = name
    if name then _G[name] = font end
    return font
end
function Widget:Raise() end
function Widget:GetStringWidth() return #(tostring(self.text or "")) * 6 end
function Widget:GetUnboundedStringWidth() return self:GetStringWidth() end
function Widget:SetScale(v) self.scale = v end
function Widget:SetIgnoreParentScale(v) self.ignoreParentScale = v end
function Widget:GetScale() return self.scale end
function Widget:GetEffectiveScale() return 1 end
function Widget:AddMessage(msg) print(msg) end
function Widget:CreateFontString(_, _, inherits)
    local fs = newWidget("FontString", self)
    fs.inherits = inherits
    self.regions[#self.regions + 1] = fs
    return fs
end
-- A line from one point to another (the anchor lines in Edit Mode).
function Widget:CreateLine(_, layer)
    local line = newWidget("Line", self)
    line.layer = layer
    self.regions[#self.regions + 1] = line
    return line
end
function Widget:SetStartPoint(point, relative, x, y) self.startPoint = { point, relative, x, y } end
function Widget:SetEndPoint(point, relative, x, y) self.endPoint = { point, relative, x, y } end
function Widget:SetThickness(v) self.thickness = v end
-- A frame's own textures and font strings, not its child frames' - as in game.
function Widget:GetRegions() return unpack(self.regions) end
function Widget:IsObjectType(kind) return self.kind == kind end
function Widget:GetChildren()
    local children = {}
    for _, frame in ipairs(allFrames) do
        if frame.parent == self then children[#children + 1] = frame end
    end
    return unpack(children)
end
function Widget:CreateTexture(_, layer, _, sublevel)
    local tex = newWidget("Texture", self)
    tex.layer, tex.sublevel = layer, sublevel
    self.regions[#self.regions + 1] = tex
    return tex
end

-- A StatusBar's texture is a real region, so setting the bar's texture and
-- reading it back through GetStatusBarTexture gives what was set - the addon
-- recolours through exactly that path.
function Widget:SetStatusBarTexture(path)
    self.statusTexture = self.statusTexture or newWidget("Texture", self)
    self.statusTexture:SetTexture(path)
end
function Widget:GetStatusBarTexture()
    self.statusTexture = self.statusTexture or newWidget("Texture", self)
    return self.statusTexture
end
function Widget:SetStatusBarColor(r, g, b, a) self.statusColor = { r, g, b, a } end
function Widget:GetStatusBarColor()
    local c = self.statusColor or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4]
end
function Widget:SetReverseFill(v) self.reverseFill = v and true or false end

function CreateFrame(kind, name, parent, template)
    local f = newWidget(kind, parent)
    f.name, f.template = name, template
    if name then _G[name] = f end
    -- A secure button is protected, and makes the frame it lives in protected.
    if template and template:find("Secure") then
        f.protected = true
        if parent then parent.protected = true end
    end
    return f
end

-- THE SECURE UNIT WATCH, as the game runs it (Blizzard_RestrictedAddOnEnvironment/
-- SecureStateDriver.lua): a registered frame is shown while the unit in its
-- "unit" attribute exists and hidden when it does not, by secure code, in
-- combat or out. The game runs it on a 0.2s timer; here it runs after every
-- event and every tick, and once when a frame is registered.
local watched = {}
-- A secure state driver on "visibility" (RegisterStateDriver), as far as the
-- addon writes one: "[group:raid] hide; [@unit,exists] show; hide".
stateDrivers = {}
inRaid, inGroup = false, false
function IsInRaid() return inRaid end
function IsInGroup() return inGroup or inRaid end
local function DriverShows(condition)
    for clause in (condition .. ";"):gmatch("%s*([^;]*);") do
        local test, action = clause:match("^%[(.-)%]%s*(%a+)$")
        if not test then return clause:match("^%s*(%a+)") == "show" end
        local ok = true
        if test:find("group:raid") then ok = ok and inRaid end
        -- (In a party or a raid, as the game's [group:party] is.)
        if test:find("group:party") then ok = ok and (inGroup or inRaid) end
        if test:find("combat") then ok = ok and inCombat == true end
        local unit = test:match("@([%w]+),exists")
        if unit then ok = ok and UnitExists(unit) end
        if ok then return action == "show" end
    end
    -- No clause applies: the game leaves the frame as it is.
    return nil
end
function RunUnitWatch()
    secureCaller = true
    for frame in pairs(watched) do
        local unit = frame:GetAttribute("unit")
        if unit and UnitExists(unit) then
            if not frame.shown then frame:Show() end
        elseif frame.shown then
            frame:Hide()
        end
    end
    for frame, condition in pairs(stateDrivers) do
        local shows = DriverShows(condition)
        if shows then
            if not frame.shown then frame:Show() end
        elseif shows == false and frame.shown then
            frame:Hide()
        end
    end
    secureCaller = false
end
function RegisterUnitWatch(frame) watched[frame] = true; RunUnitWatch() end
function UnregisterUnitWatch(frame) watched[frame] = nil end
function RegisterStateDriver(frame, state, condition)
    if state == "visibility" then stateDrivers[frame] = condition; RunUnitWatch() end
end
function UnregisterStateDriver(frame, state)
    if state == "visibility" then stateDrivers[frame] = nil end
end

UIParent = newWidget("Frame")
GameTooltip = newWidget("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:AddLine() end
GameFontNormal = {}

-- The game's alerts (AlertFrames.lua) and its loot lines (GlobalStrings).
AlertFrame = newWidget("Frame")
AlertFrame:RegisterEvent("LOOT_ITEM_ROLL_WON")
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
GOLD_AMOUNT, SILVER_AMOUNT, COPPER_AMOUNT = "%d Gold", "%d Silver", "%d Copper"
YOU_WON_LABEL, MONEY = "You Won!", "Money"
ITEM_QUALITY_COLORS = { [1] = { r = 1, g = 1, b = 1 }, [3] = { r = 0, g = 0.44, b = 0.87 },
                        [4] = { r = 0.64, g = 0.21, b = 0.93 } }
C_CurrencyInfo = { GetCoinTextureString = function(copper) return "coins:" .. copper end }

function GetCursorPosition() return 0, 500 end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
-- 768 / 1080 of a UI unit per pixel at scale 1; the grid lays itself out in these.
function GetPhysicalScreenSize() return 1920, 1080 end
-- The keyboard and mouse, as far as a drag asks: set these in a test.
shiftDown, ctrlDown, leftButtonDown = false, false, true
function IsShiftKeyDown() return shiftDown end
function IsControlKeyDown() return ctrlDown end
function IsMouseButtonDown(button) return button == "LeftButton" and leftButtonDown end

-- Controlled time -------------------------------------------------------------
now = 1000
function GetTime() return now end

C_Timer = { After = function(_, func) pendingTimer = func end }

SlashCmdList = {}

-- The 3D world, which a click on anything that is not UI lands on.
WorldFrame = newWidget("Frame")

-- Override bindings: key -> the button a press of it clicks, with its owner.
overrideBindings = {}
function SetOverrideBindingClick(owner, _, key, buttonName)
    overrideBindings[key] = { owner = owner, button = buttonName }
end
function ClearOverrideBindings(owner)
    for key, binding in pairs(overrideBindings) do
        if binding.owner == owner then overrideBindings[key] = nil end
    end
end

-- What the player holds, and the items the game knows: itemID -> class and
-- subclass, as GetItemInfoInstant gives them (classID 6th, subClassID 7th).
INVSLOT_MAINHAND = 16
equipped = {}
function GetInventoryItemID(_, slot) return equipped[slot] end
itemClasses = {
    [6256] = { 2, 20 },    -- Fishing Pole
    [2361] = { 2, 1 },     -- Battleworn Hammer
}
C_Item = {
    GetItemInfoInstant = function(itemID)
        local info = itemClasses[itemID]
        if not info then return nil end
        return itemID, nil, nil, nil, nil, info[1], info[2]
    end,
    GetItemCount = function() return 0 end,
}
Enum = Enum or {}
Enum.ItemClass = { Weapon = 2 }
Enum.ItemWeaponSubclass = { Fishingpole = 20 }

-- Mouse-look: holding the right button in the world turns it on, and while it
-- is on, letting go of the button goes to the camera rather than to a binding.
mouselooking = false
function IsMouselooking() return mouselooking end
function MouselookStop() mouselooking = false end

-- Whether the player knows Fishing; the spell answers by name only then.
knowsFishing = true
mounted, swimming = false, false
function IsMounted() return mounted end
function IsSwimming() return swimming end

-- The game's options (Blizzard_Settings): an addon registers a panel as a
-- category under AddOns, which is how the player reaches it.
Settings = { addOnCategories = {} }
function Settings.RegisterCanvasLayoutCategory(frame, name)
    return { frame = frame, name = name }
end
function Settings.RegisterAddOnCategory(category)
    table.insert(Settings.addOnCategories, category)
end
-- A page listed under a category (a tab of the addon's own).
function Settings.RegisterCanvasLayoutSubcategory(parent, frame, name)
    local sub = { frame = frame, name = name, parent = parent }
    parent.subcategories = parent.subcategories or {}
    table.insert(parent.subcategories, sub)
    return sub
end

-- The addon's chat output is kept so the tests can assert on it, and still
-- printed: swallowing it would swallow this file's own output too, since `check`
-- prints through the same global.
printed = {}
local realPrint = print
function print(...)
    local parts = {}
    for index = 1, select("#", ...) do parts[#parts + 1] = tostring((select(index, ...))) end
    printed[#printed + 1] = table.concat(parts, " ")
    realPrint(...)
end

-- Follows a method rather than replacing it, which is what lets an addon react
-- to Edit Mode re-anchoring a frame without tainting it.
-- Given only a name, it follows the global function of that name.
function hooksecurefunc(target, name, post)
    if type(target) == "string" then
        target, name, post = _G, target, name
    end
    local original = target[name]
    target[name] = function(...)
        local results = { original(...) }
        post(...)
        return unpack and unpack(results) or table.unpack(results)
    end
end

-- Nothing in this client is secret unless a test says so.
secretValues = {}
function issecretvalue(v) return secretValues[v] == true end
-- The client's own helper: every secret argument comes back nil. Modelled so a
-- name routed through it goes blank here exactly as it did in a dungeon.
function scrub(...)
    local out = { ... }
    for i = 1, select("#", ...) do
        if secretValues[out[i]] then out[i] = nil end
    end
    return unpack(out, 1, select("#", ...))
end

-- A *secret table*: one that can still be indexed, where every field read
-- comes back secret. The client reports these as something other than a
-- plain table, which is the whole reason the aura row may not ask `type()`
-- about one - a loop that stopped at `type(aura) ~= "table"` treated the
-- first restricted debuff as the end of the list. The exact type name the
-- client gives is not the point and is not modelled here; that it is not
-- "table" is.
secretTables = {}
local rawtype = type
function type(v)
    if secretTables[v] then return "userdata" end
    return rawtype(v)
end
function issecrettable(v) return secretTables[v] == true end

-- Dropdown menu API -----------------------------------------------------------
BackdropTemplateMixin = {}
ColorPickerFrame = newWidget("Frame")
function ColorPickerFrame:SetupColorPickerAndShow(info) self.info = info end
function ColorPickerFrame:GetColorRGB() return 1, 1, 1 end
function ColorPickerFrame:GetColorAlpha() return 1 end

-- Widget methods this addon needs and the castbar harness never did -----------

-- The client formats a secret value and marks the result secret; real Lua
-- cannot format the stand-in tables this harness uses for one. So a format that
-- fails keeps the value itself, which is what the tests need to see: that the
-- secret reached the widget rather than being read on the way.
function Widget:SetFormattedText(fmt, ...)
    NeedsFont(self)
    local ok, text = pcall(string.format, fmt, ...)
    self.text = ok and text or (...)
end

function Widget:SetFrameLevel(v) self.frameLevel = v end
function Widget:SetTexCoord(...) self.texCoord = { ... } end
function Widget:SetDrawEdge(v) self.drawEdge = v end
function Widget:SetDrawBling(v) self.drawBling = v end
function Widget:SetReverse(v) self.reverse = v end
function Widget:SetHideCountdownNumbers(v) self.hideNumbers = v end
function Widget:SetCooldown(start, duration) self.cooldown = { start, duration } end
function Widget:SetUnitAura(unit, index, filter) self.tooltipAura = { unit, index, filter } end
function Widget:GetFrameLevel() return self.frameLevel or 1 end
-- An atlas sets the texture's coordinates to its region, which is what
-- GetTexCoord then answers (all eight corner values, as in game);
-- `atlasRegions` gives the region for an atlas a test cares about.
atlasRegions = {}
function Widget:SetAtlas(v)
    self.atlas, self.texture = v, nil       -- a texture replaced, as in game
    self.texCoord = nil
    self.atlasCoords = atlasRegions[v]
end
function Widget:GetAtlas() return self.atlas end
function Widget:GetSize() return self.width, self.height end
function Widget:GetTexCoord()
    if self.texCoord then
        local l, r, t, b = unpack(self.texCoord)
        return l, t, l, b, r, t, r, b
    end
    if self.atlasCoords then return unpack(self.atlasCoords) end
    return 0, 0, 0, 1, 1, 0, 1, 1
end
function Widget:SetTextureSliceMargins(l, t, r, b) self.sliceMargins = { l, t, r, b } end
function Widget:SetTextureSliceMode(mode) self.sliceMode = mode end
function Widget:AddMaskTexture(mask) self.mask = mask end
function Widget:RemoveMaskTexture(mask) if self.mask == mask then self.mask = nil end end
function Widget:CreateMaskTexture()
    local mask = newWidget("MaskTexture", self)
    self.regions[#self.regions + 1] = mask
    return mask
end
function Widget:SetAttribute(key, value) self.attributes[key] = value end
function Widget:GetAttribute(key) return self.attributes[key] end
function Widget:RegisterForClicks(...) self.clicks = { ... } end
function Widget:SetUnit(unit) self.tooltipUnit = unit end

-- newWidget does not know about attributes, so give every widget the table
-- lazily rather than reaching back into it.
local rawIndex = Widget.__index
Widget.__index = function(table, key)
    if key == "attributes" then
        rawset(table, "attributes", {})
        return rawget(table, "attributes")
    end
    return rawIndex[key]
end

-- The art the modern unit frames are drawn with. Only the atlases this stub
-- lists exist, so the addon's "ask before using it" can be tested both ways.
atlases = {
    ["UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health"] = true,
    ["UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Status"] = true,
    ["ui-castingbar-filling-standard"] = true,
    ["ui-castingbar-filling-channel"] = true,
    ["ui-castingbar-uninterruptable"] = true,
    ["ui-castingbar-interrupted"] = true,
    ["UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana"] = true,
    ["UI-HUD-UnitFrame-Player-PortraitOn-Bar-Rage"] = true,
    ["ui-swingtimerbar-filling-mainhand"] = true,
    -- The PvP badges, with their proportions: taller than wide.
    ["UI-HUD-UnitFrame-SmallCircle-Horde"] = { width = 30, height = 40 },
    ["UI-HUD-UnitFrame-SmallCircle-Alliance"] = { width = 30, height = 40 },
    ["nameplates-icon-elite-gold"] = { width = 20, height = 20 },
    ["nameplates-icon-elite-silver"] = { width = 20, height = 20 },
    ["UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star"] = { width = 20, height = 20 },
    ["UI-HUD-UnitFrame-Target-HighLevelTarget_Icon"] = { width = 20, height = 20 },
    ["UI-HUD-UnitFrame-Player-PVP-FFAIcon"] = { width = 30, height = 40 },
    ["UI-LFG-RoleIcon-DPS-Micro-GroupFinder"] = true,
}

-- The tooltip border's art, and the nine-slice utility that lays it out
-- (Blizzard_SharedXML/NineSlice.lua): one texture per piece, named after it.
local TOOLTIP_PIECES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center",
}
NineSliceLayouts = { TooltipDefaultLayout = {} }
for _, piece in ipairs(TOOLTIP_PIECES) do
    local atlas = "Tooltip-NineSlice-" .. piece
    NineSliceLayouts.TooltipDefaultLayout[piece] = { atlas = atlas }
    atlases[atlas] = true
end
NineSliceUtil = {
    GetLayout = function(name) return NineSliceLayouts[name] end,
    -- A texture kit fills the layout's "%s", as in game.
    ApplyLayout = function(container, layout, kit)
        for _, piece in ipairs(TOOLTIP_PIECES) do
            if layout[piece] then
                container[piece] = container[piece] or container:CreateTexture()
                local atlas = layout[piece].atlas
                if kit then atlas = atlas:format(kit) end
                container[piece]:SetAtlas(atlas)
            end
        end
    end,
}

C_Texture = {
    GetAtlasInfo = function(name)
        if type(atlases[name]) == "table" then return atlases[name] end
        if atlases[name] then return { width = 124, height = 20 } end
        return nil
    end,
}

-- The game's nameplate driver (Blizzard_NamePlates, always loaded): no plates.
NamePlateDriverFrame = { OnNamePlateAdded = function() end, UpdateNamePlateOptions = function() end }
C_NamePlate = { GetNamePlateForUnit = function() end, GetNamePlates = function() return {} end }
function CompactUnitFrame_UpdatePlayerLevelDiff() end
function CompactUnitFrame_UpdateName() end
function CompactUnitFrame_UpdateHealthColor() end
tapDenied = {}            -- unit -> tapped by someone else
function CompactUnitFrame_IsTapDenied(frame) return tapDenied[frame.unit] == true end
-- SharedXML's TableUtil.
function tContains(t, value)
    for _, v in ipairs(t) do if v == value then return true end end
    return false
end
-- The client's table.wipe and SharedXMLBase's Clamp (math.clamp).
wipe = wipe or function(t)
    for k in pairs(t) do t[k] = nil end
    return t
end
Clamp = Clamp or function(value, low, high) return math.max(low, math.min(high, value)) end

-- The setting the game keeps for the target of target, under Options > Combat.
cvars = { showTargetOfTarget = true, showSwingTimer = true }
function GetCVarBool(name) return cvars[name] and true or false end
-- Setting one fires CVAR_UPDATE, as the game does; writes in combat are
-- counted, since the game may refuse them.
cvarWritesInCombat = 0
-- (And the value as written, for a setting that is a word: whisperMode.)
cvarText = {}
C_CVar = {
    GetCVar = function(name) return cvars[name] and "1" or "0" end,
    SetCVar = function(name, value)
        if inCombat then cvarWritesInCombat = cvarWritesInCombat + 1 end
        cvarText[name] = value
        cvars[name] = (value == "1" or value == 1 or value == true)
        Fire("CVAR_UPDATE", name, cvars[name] and "1" or "0")
        return true
    end,
}
C_DamageMeter = { IsDamageMeterAvailable = function() return true, "" end }

-- Combat ----------------------------------------------------------------------
inCombat = false
function InCombatLockdown() return inCombat end

-- Colour tables, as the game defines them -------------------------------------
RAID_CLASS_COLORS = {
    PRIEST = { r = 1, g = 1, b = 1 },
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
}
FACTION_BAR_COLORS = {
    [1] = { r = 0.8, g = 0.3, b = 0.2 },   -- hated
    [4] = { r = 0.9, g = 0.9, b = 0.2 },   -- neutral
    [5] = { r = 0.2, g = 0.8, b = 0.2 },   -- friendly
}
-- Each resource names the art the modern UI draws it with; the client may or
-- may not have that art, which is what `atlases` above decides. Energy names
-- art this stub does not have, so it exercises the fallback.
PowerBarColor = {
    MANA = { r = 0, g = 0, b = 1, atlasElementName = "Mana" },
    RAGE = { r = 1, g = 0, b = 0, atlasElementName = "Rage" },
    ENERGY = { r = 1, g = 1, b = 0, atlasElementName = "Energy" },
    FOCUS = { r = 1, g = 0.5, b = 0.25, atlasElementName = "Focus" },
}
function GetCreatureDifficultyColor(level)
    if type(level) ~= "number" or level < 0 then return { r = 1, g = 0, b = 0 } end
    return { r = 0.5, g = 0.8, b = 0.5 }
end

-- The units, as the game would report them ------------------------------------
units = {
    player = {
        name = "Dogsdog", level = 60, class = "PRIEST", isPlayer = true, reaction = 5,
        health = 8000, healthMax = 10000, incoming = 0,
        power = 3000, powerMax = 5000, powerToken = "MANA",
    },
}

function Unit(token) return units[token] end
-- Whether a unit leads the group; a test sets `leader` on a unit.
-- UnitIsGroupLeader counts only the player's own party; UnitLeadsAnyGroup
-- counts the instance group (dungeon finder, battleground) too - a test sets
-- `instanceLeader` for a unit leading only that one.
function UnitIsGroupLeader(token)
    local u = Unit(token)
    return u ~= nil and u.leader == true
end
function UnitLeadsAnyGroup(token)
    local u = Unit(token)
    return u ~= nil and (u.leader == true or u.instanceLeader == true)
end
-- Whether the group is one the dungeon finder made; a test sets it.
lfgGroup = false
function HasLFGRestrictions() return lfgGroup == true end

function UnitExists(token) return Unit(token) ~= nil end
-- Spells the player has: all, but those a test puts in `unknownSpells`.
unknownSpells = {}
function IsPlayerSpell(id) return not unknownSpells[id] end
function UnitIsUnit(a, b)
    -- SecretWhenUnitComparisonRestricted: a restricted unit's answer is secret.
    local u = Unit(a)
    if u and u.comparisonSecret then return u.comparisonSecret end
    return a == b or (u ~= nil and u == Unit(b))
end
function UnitIsPlayer(token)
    local u = Unit(token)
    return u ~= nil and u.isPlayer == true
end
-- A follower dungeon's NPCs (set `asPlayer` on the unit).
function UnitTreatAsPlayerForDisplay(token)
    local u = Unit(token)
    return u ~= nil and u.asPlayer == true
end
-- A test sets `offline` on a unit that has logged off, `dead` on one that died.
function UnitIsConnected(token)
    local u = Unit(token)
    return u ~= nil and u.offline ~= true
end
function UnitIsDeadOrGhost(token)
    local u = Unit(token)
    return u ~= nil and u.dead == true
end
PLAYER_OFFLINE, DEAD = "Offline", "Dead"
function UnitName(token)
    local u = Unit(token)
    if not u then return end
    return u.name
end
-- A unit's GUID: "Player-<name>" (plain, as the player's own always is).
function UnitGUID(token)
    local u = Unit(token)
    if not u then return end
    return u.guid or ("Player-" .. tostring(u.name))
end
function UnitLevel(token)
    local u = Unit(token)
    return u and u.level or 0
end
-- PvP. `pvp` may be SECRET_TRUE, a stand-in for the secret boolean UnitIsPVP
-- returns for an identity-restricted unit: the test checks it arrives at
-- SetAlphaFromBoolean as itself, i.e. it was passed on rather than looked at.
SECRET_TRUE = setmetatable({}, { __tostring = function() return "<secret true>" end })
secretValues[SECRET_TRUE] = true
function UnitFactionGroup(token)
    local u = Unit(token)
    return u and u.faction
end
function UnitIsPVP(token)
    local u = Unit(token)
    if not u then return false end
    return u.pvp
end
-- The player's threat on a mob: a test sets `threat` (the raw percentage,
-- maybe secret) on the unit, `tanking` and `lead` (the percentage of the next's,
-- UnitThreatPercentageOfLead) while holding it; none = not on its threat list.
function UnitDetailedThreatSituation(token, mob)
    local u = Unit(mob)
    if not (u and u.threat) then return end
    return u.tanking or false, 1, u.scaledThreat or u.threat, u.threat, 0
end
function UnitThreatPercentageOfLead(token, mob)
    local u = Unit(mob)
    return u and u.lead
end
function UnitClassification(token)
    local u = Unit(token)
    return u and u.classification or "normal"
end
function UnitIsBossMob(token)
    local u = Unit(token)
    return u ~= nil and u.boss == true
end
function UnitIsPVPFreeForAll(token)
    local u = Unit(token)
    return u ~= nil and u.ffa == true
end
function UnitClass(token)
    local u = Unit(token)
    if not u then return end
    return u.class, u.class
end
-- What a unit is casting. The cast bars read this on their own timer rather
-- than piecing it together from events, so a test sets it and steps the clock.
casting = {}
castingSecret = {}

function UnitCastingInfo(token)
    local c = casting[token]
    if not c or c.channel then return end
    return c.name, c.name, "icon", c.start * 1000, c.finish * 1000, false, "cast-1",
        c.notInterruptible
end

function UnitChannelInfo(token)
    local c = casting[token]
    if not c or not c.channel then return end
    return c.name, c.name, "icon", c.start * 1000, c.finish * 1000, false,
        c.notInterruptible
end

-- The colour the game paints a unit's bar: green for a friend, yellow for a
-- neutral, red for an enemy. The addon asks for this rather than working one
-- out, so the stub answers the same way the client does.
function UnitSelectionColor(token)
    local u = Unit(token)
    if not u then return 1, 1, 1, 1 end
    if (u.reaction or 0) >= 5 then return 0, 1, 0, 1 end
    if (u.reaction or 0) == 4 then return 1, 1, 0, 1 end
    return 1, 0, 0, 1
end

function UnitReaction(token)
    local u = Unit(token)
    return u and u.reaction
end
-- Mana, unless the unit's powerToken says otherwise.
function UnitHasPowerType(token, powerType)
    local u = Unit(token)
    return u ~= nil and powerType == Enum.PowerType.Mana and (u.powerToken or "MANA") == "MANA"
end
function UnitPowerType(token)
    local u = Unit(token)
    if not u then return end
    return 0, u.powerToken
end
function UnitHealthMax(token)
    local u = Unit(token)
    return u and u.healthMax or 0
end
function UnitHealth(token, usePredicted)
    local u = Unit(token)
    if not u then return 0 end
    -- The client's own signature: usePredicted defaults to true. Predicted
    -- health is the client's own, ahead of the server's confirmed value - NOT
    -- the heals in flight: the game's frames draw those on top of it
    -- (UnitFrameHealPredictionBars_Update), and in game a bar of predicted
    -- health behind the real one showed nothing.
    if usePredicted == nil then usePredicted = true end
    if usePredicted and u.predictedHealth ~= nil then return u.predictedHealth end
    return u.health
end
-- Missing health and incoming heals: what the heal shading is drawn from. Both
-- are secret-able and neither is ever read by the addon.
function UnitHealthMissing(token, usePredicted)
    local u = Unit(token)
    if not u then return 0 end
    if u.missingHealth ~= nil then return u.missingHealth end
    -- A secret stands in for itself: real Lua cannot subtract the tables this
    -- harness uses for one, and the client would hand back another secret.
    if type(u.health) ~= "number" or type(u.healthMax) ~= "number" then
        return u.health
    end
    return u.healthMax - u.health
end

function UnitGetIncomingHeals(token)
    local u = Unit(token)
    if not u then return end
    return u.incoming     -- nil when nothing is on its way, as the game reports
end

function UnitGetTotalHealAbsorbs(token)
    local u = Unit(token)
    return u and u.healAbsorb or 0
end

function UnitGetTotalAbsorbs(token)
    local u = Unit(token)
    return u and u.shield or 0
end

-- The client answers in advance whether it will say what a unit is casting,
-- which is what lets the cast bar avoid testing a secret at all.
C_Secrets = {
    ShouldUnitSpellCastingBeSecret = function(token)
        return castingSecret[token] and true or false
    end,
}

-- No aura stubs: this addon no longer reads auras at all. The client refuses a
-- tainted caller while C_Secrets.ShouldAurasBeSecret() is true and lists a
-- hostile unit's auras as empty when it is false, so the aura row came out and
-- the game draws every unit's auras itself.

AuraUtil = AuraUtil or {}
function AuraUtil.GetAuraBorderColor(dispelName)
    if dispelName == "Magic" then return { r = 0.2, g = 0.6, b = 1 } end
    return { r = 0.8, g = 0, b = 0 }
end
-- The game's own aura classification (AuraUtil.ProcessAura), the aura
-- container's policy that applies it, its sort methods and its dispel-type
-- texture styles (Blizzard_AuraContainerShared.lua, AuraContainerShared docs).
AuraUtil.AuraUpdateChangedType = { None = 1, Debuff = 2, Buff = 3, Dispel = 4 }
CustomAuraContainerAuraProcessingPolicy = { None = 0, ProcessAura = 1 }
AuraContainerSortMethod = { Default = 0, BigDefensive = 1, UnitFrameDebuff = 2 }
Enum = Enum or {}
Enum.CustomAuraButtonDispelTypeTextureStyle = { Border = 0, BorderWithIcon = 1, Icon = 2,
                                                PreserveAsset = 3, CustomAsset = 4 }

function UnitPowerMax(token)
    local u = Unit(token)
    return u and u.powerMax or 0
end
function UnitPower(token)
    local u = Unit(token)
    return u and u.power or 0
end

-- Curves (C_CurveUtil): points joined by straight lines, evaluated by the game.
C_CurveUtil = {
    CreateCurve = function()
        local curve = { points = {} }
        function curve:SetType(kind) self.kind = kind end
        function curve:AddPoint(x, y)
            table.insert(self.points, { x, y })
            table.sort(self.points, function(a, b) return a[1] < b[1] end)
        end
        function curve:Evaluate(x)
            local p = self.points
            if x <= p[1][1] then return p[1][2] end
            for i = 2, #p do
                if x <= p[i][1] then
                    local a, b = p[i - 1], p[i]
                    return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1])
                end
            end
            return p[#p][2]
        end
        return curve
    end,
    -- The client's own: it may look at a secret boolean, the addon may not.
    EvaluateColorValueFromBoolean = function(v, ifTrue, ifFalse)
        if v == SECRET_TRUE or v == true then return ifTrue end
        return ifFalse
    end,
}
Enum = Enum or {}
Enum.LuaCurveType = { Linear = 0, Step = 1, Cosine = 2, Cubic = 3 }

-- The game's own curves (Blizzard_SharedXMLBase/CurveConstants.lua).
CurveConstants = {}
CurveConstants.ScaleTo100 = C_CurveUtil.CreateCurve()
CurveConstants.ScaleTo100:SetType(Enum.LuaCurveType.Linear)
CurveConstants.ScaleTo100:AddPoint(0.0, 0)
CurveConstants.ScaleTo100:AddPoint(1.0, 100)

-- The game's number shortener: "505K", "12.4K". It takes a secret and gives
-- back a secret, which the addon can only hand on.
function AbbreviateNumbers(n)
    if secretValues[n] then
        local secret = {}
        secretValues[secret] = true
        return secret
    end
    local function Short(v) return (string.format("%.1f", v):gsub("%.0$", "")) end
    if n >= 1e9 then return Short(n / 1e9) .. "B" end
    if n >= 1e6 then return Short(n / 1e6) .. "M" end
    if n >= 1e3 then return Short(n / 1e3) .. "K" end
    return tostring(math.floor(n))
end

-- A unit's fraction of health or power, evaluated through a curve by the game.
-- When the numbers are secret, so is the answer: a secret stand-in the addon
-- can only hand on.
curveResults = {}
local function Percent(value, max, curve)
    if type(value) ~= "number" or type(max) ~= "number" then
        local secret = {}
        secretValues[secret] = true
        curveResults[#curveResults + 1] = secret
        return secret
    end
    local fraction = max > 0 and value / max or 0
    return curve and curve:Evaluate(fraction) or fraction
end
function UnitHealthPercent(token, usePredicted, curve)
    return Percent(UnitHealth(token, usePredicted), UnitHealthMax(token), curve)
end
function UnitPowerPercent(token, powerType, unmodified, curve)
    return Percent(UnitPower(token), UnitPowerMax(token), curve)
end

-- The game's own player and target frames, which the addon must fade out. The
-- pet frame is a child of the player frame, and the target's contextual content
-- is where its buffs and debuffs live: neither may be touched.
PlayerFrame = newWidget("Button")
PlayerFrame.name = "PlayerFrame"
PlayerFrame.PlayerFrameContainer = newWidget("Frame", PlayerFrame)
PlayerFrame.PlayerFrameContent = newWidget("Frame", PlayerFrame)
-- Retail shadow's class bar: its Voidform art over the player frame's portrait and mana bar.
InsanityBarFrame = newWidget("Frame", PlayerFrame)
PetFrame = newWidget("Button", PlayerFrame)
PetFrame.name = "PetFrame"
-- Its aura row (buttons that take the mouse) and its happiness face, a frame
-- of its own that takes the mouse for its tooltip (Mainline PetFrame.xml).
PetFrame.AuraFrameContainer = newWidget("Frame", PetFrame)
PetFrameHappiness = newWidget("Frame", PetFrame)
PetFrameHappiness.mouseEnabled = true

TargetFrame = newWidget("Button")
TargetFrame.name = "TargetFrame"
TargetFrame.TargetFrameContainer = newWidget("Frame", TargetFrame)
TargetFrame.TargetFrameContent = newWidget("Frame", TargetFrame)
TargetFrame.TargetFrameContent.TargetFrameContentMain =
    newWidget("Frame", TargetFrame.TargetFrameContent)
TargetFrame.TargetFrameContent.TargetFrameContentContextual =
    newWidget("Frame", TargetFrame.TargetFrameContent)

-- The focus frame is built from the same template as the target frame, so it has
-- the same parts inside it. The two target-of-target frames are frames of their
-- own, children of those two rather than of their content.
FocusFrame = newWidget("Button")
FocusFrame.name = "FocusFrame"
FocusFrame.TargetFrameContainer = newWidget("Frame", FocusFrame)
FocusFrame.TargetFrameContent = newWidget("Frame", FocusFrame)
FocusFrame.TargetFrameContent.TargetFrameContentMain =
    newWidget("Frame", FocusFrame.TargetFrameContent)
FocusFrame.TargetFrameContent.TargetFrameContentContextual =
    newWidget("Frame", FocusFrame.TargetFrameContent)

-- The game's PvP badge, which sits in the contextual content beside the auras.
for _, frame in ipairs({ TargetFrame, FocusFrame }) do
    local contextual = frame.TargetFrameContent.TargetFrameContentContextual
    for _, key in ipairs({ "PvpBackgroundCircle", "PvpBackgroundIcon", "PvpIcon",
            "PrestigePortrait", "PrestigeBadge", "HighLevelTexture", "BossIcon",
            "LeaderIcon", "GuideIcon" }) do
        contextual[key] = newWidget("Texture", contextual)
    end
end

-- TargetFrameMixin:AnchorAuraContainer anchors the aura container to this, so
-- where this is, the auras are. It sits inset inside its own frame, and the
-- addon measures that inset rather than assuming it.
TargetFrame.left, TargetFrame.bottom, TargetFrame.top = 500, 300, 420
TargetFrame.TargetFrameContainer.FrameTexture = newWidget("Texture", TargetFrame.TargetFrameContainer)
TargetFrame.TargetFrameContainer.FrameTexture.left = 520
TargetFrame.TargetFrameContainer.FrameTexture.bottom = 340
TargetFrame.TargetFrameContainer.FrameTexture.top = 400
-- The threat number over the frame; while it shows, the game raises an aura row
-- stacked on top by its height.
TargetFrame.threatNumericIndicator = newWidget("Frame", TargetFrame)
TargetFrame.threatNumericIndicator.height = 18
TargetFrame.threatNumericIndicator.shown = false
-- The game re-anchors its aura row through this; the addon follows it.
TargetFrame.auraAnchorings = 0
function TargetFrame:AnchorAuraContainer() self.auraAnchorings = self.auraAnchorings + 1 end
-- Edit Mode's "Frame Size": EditModeUnitFrameSystemMixin:UpdateSystemSettingFrameSize
-- scales the frame to the setting.
function TargetFrame:UpdateSystemSettingFrameSize() self:SetScale(self.editModeSize or 1) end
-- Where the game had the frame. Parking it on the plate has to be undone from
-- here, so this is what turning the addon off must put back.
TargetFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -100)

FocusFrame.left, FocusFrame.bottom, FocusFrame.top = 700, 500, 600
FocusFrame.TargetFrameContainer.FrameTexture = newWidget("Texture", FocusFrame.TargetFrameContainer)
FocusFrame.TargetFrameContainer.FrameTexture.left = 712
FocusFrame.TargetFrameContainer.FrameTexture.bottom = 530
FocusFrame.TargetFrameContainer.FrameTexture.top = 590
FocusFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -100)

-- Edit Mode positions every system it owns through this one method, and drags
-- and layout changes all end up here. The addon follows it so a frame carrying
-- auras cannot be walked off its plate.
-- EditModeSystemMixin:CanBeMoved is `self.isSelected and not self.isLocked`, and
-- OnDragStart does nothing when it is false. Modelled exactly, so a test can
-- drag a frame the way Edit Mode drags one.
function TargetFrame:CanBeMoved() return self.isSelected and not self.isLocked end
function FocusFrame:CanBeMoved() return self.isSelected and not self.isLocked end
local function EditModeDrag(frame)
    -- As in game: a drag starts on the frame's selection box - one taking no
    -- mouse cannot be grabbed at all.
    local selection = frame.Selection
    if selection and selection.mouseEnabled == false then return false end
    frame.isSelected = true
    if not frame:CanBeMoved() then return false end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 950, -650)
    return true
end
EditModeDragForTests = EditModeDrag

editModeAnchored = {}
function TargetFrame:ApplySystemAnchor()
    editModeAnchored.target = true
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 900, -600)
end
function FocusFrame:ApplySystemAnchor()
    editModeAnchored.focus = true
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 900, -700)
end

TargetFrameToT = newWidget("Button")
TargetFrameToT.name = "TargetFrameToT"
TargetFrameSpellBar = newWidget("StatusBar")
TargetFrameSpellBar.name = "TargetFrameSpellBar"
FocusFrameSpellBar = newWidget("StatusBar")
FocusFrameSpellBar.name = "FocusFrameSpellBar"
FocusFrameToT = newWidget("Button")
FocusFrameToT.name = "FocusFrameToT"

-------------------------------------------------------------------------------
-- Moving and resizing are refused on a protected frame in combat too. Wrapped
-- here, after every widget method exists.
for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetWidth", "SetHeight",
                         "SetSize", "SetFrameStrata", "SetUserPlaced" }) do
    local original = Widget[method]
    Widget[method] = function(self, ...)
        if Refused(self, method) then return end
        return original(self, ...)
    end
end

-------------------------------------------------------------------------------
-- Everything below was added when the five addons became one: the pieces the
-- castbar, five-second, chat and menus tests need, on top of the frames stubs
-- above, and the event bus that delivers an event to every frame that asked
-- for it - the core, and each module, now listen for their own.
-------------------------------------------------------------------------------

unpack = unpack or table.unpack
tinsert = table.insert

-- Every frame the addon makes, so events and frame updates can be delivered
-- the way the game delivers them: to whoever registered, to whoever is shown.
allFrames = {}

function CreateFrame(kind, name, parent, template)
    -- A template this client does not have is an error in game too, which is
    -- what the addon's fallbacks are for.
    if template and missingTemplates[template] then
        error("unknown template " .. template)
    end
    local f = newWidget(kind, parent)
    f.name, f.template = name, template
    if name then _G[name] = f end
    -- As in game: one level over its parent.
    if parent and parent.frameLevel then f.frameLevel = parent.frameLevel + 1 end
    -- A secure button is protected, and makes the frame it lives in protected.
    if template and template:find("Secure") then
        f.protected = true
        if parent then parent.protected = true end
    end
    if template and template:find("ActionBarButtonTemplate") and actionButtonTemplate then
        actionButtonTemplate(f)
        -- Its OnLoad: on the game's broadcaster's list.
        table.insert(ActionBarButtonEventsFrame.frames, f)
    end
    -- The game menu's button (ThreeSliceButtonTemplate): its three pieces of
    -- red art, set only as it is shown (UpdateButton), and its red glow.
    if template == "MainMenuFrameButtonTemplate" then
        for _, key in ipairs({ "Left", "Center", "Right" }) do
            local piece = f:CreateTexture()
            function piece:GetAtlas() return self.atlas end
            function piece:SetAtlas(atlas) self.atlas = atlas end
            function piece:GetTexCoord() return 0, 0, 0, 1, 1, 0, 1, 1 end
            f[key] = piece
        end
        f.highlight = f:CreateTexture()
        f.highlight.atlas = "128-RedButton-Highlight"
        function f:GetHighlightTexture() return self.highlight end
        function f:UpdateButton()
            self.Left.atlas, self.Center.atlas, self.Right.atlas =
                "128-RedButton-Left", "_128-RedButton-Center", "128-RedButton-Right"
        end
    end
    allFrames[#allFrames + 1] = f
    return f
end

-- Templates that do not exist here, so the fallbacks run: the tab system is
-- the one the options panel falls back from.
missingTemplates = { TabSystemTemplate = true }

-- As the game: a secret only from untainted code - the game's own, not the addon's.
function Widget:SetShown(v)
    if secretValues[v] then
        local source = debug.getinfo(2, "S").source
        if source:find("DogsForeverUI", 1, true) and not source:find("tests", 1, true) then
            error("bad argument #1 to 'SetShown' (Secret values are only allowed during untainted execution)", 2)
        end
    end
    if v then self:Show() else self:Hide() end
end
function Widget:GetAlpha() return self.alpha or 1 end
-- What is actually drawn: a frame and every parent above it.
function Widget:IsVisible()
    local frame = self
    while frame do
        if frame.shown == false then return false end
        frame = frame.parent
    end
    return true
end
function Widget:GetEffectiveAlpha()
    local alpha, frame = 1, self
    while frame do
        alpha = alpha * (frame.alpha or 1)
        frame = frame.parent
    end
    return alpha
end
function Widget:SetToplevel(v) self.toplevel = v end
-- The addon's own frames under the mouse: those in `mouseOver`, as the game's.
function Widget:IsMouseOver() return mouseOver ~= nil and mouseOver[self] == true end
function Widget:GetCenter()
    if self.center then return self.center[1], self.center[2] end
    return (self.width or 0) / 2, (self.height or 0) / 2
end
function Widget:SetNormalTexture(texture) self.normalTexture = texture end
function Widget:SetHighlightTexture(texture) self.highlightTexture = texture end
function Widget:SetPushedTexture(texture) self.pushedTexture = texture end
function Widget:SetCheckedTexture(texture) self.checkedTexture = texture end
function Widget:GetStringHeight() return 14 end
function Widget:SetMotionScriptsWhileDisabled() end
function Widget:SetSnapToPixelGrid(v) self.snapToPixelGrid = v end
function Widget:SetTexelSnappingBias(v) self.texelSnappingBias = v end

-- A ScrollingMessageFrame, as far as the chat copy window uses one.
function Widget:SetIndentedWordWrap(v) self.indentedWordWrap = v end
function Widget:SetFading(v) self.fading = v end
function Widget:SetTextCopyable(v) self.textIsCopyable = v and true or false end
function Widget:IsTextCopyable() return self.textIsCopyable end
function Widget:SetMouseClickEnabled(v) self.mouseClicks = v and true or false end
function Widget:IsMouseClickEnabled() return self.mouseClicks end
-- The mouse's motion seen, and clicks and motion handed on to what is under
-- a frame (a ghost over the game's own tabs).
function Widget:SetMouseMotionEnabled(v) self.mouseMotion = v and true or false end
function Widget:SetPropagateMouseClicks(v) self.propagateClicks = v and true or false end
function Widget:SetPropagateMouseMotion(v) self.propagateMotion = v and true or false end
function Widget:SetClipsChildren(v) self.clipsChildren = v and true or false end
function Widget:SetOnTextCopiedCallback(func) self.onTextCopied = func end
function Widget:Clear() self.lines = {}; self.durationObject = nil end
-- A cooldown set from the client's duration object (secret-safe).
function Widget:SetCooldownFromDurationObject(duration) self.durationObject = duration end
function Widget:SetDrawSwipe(v) self.drawSwipe = v end
function Widget:AddMessage(message, r, g, b)
    self.lines = self.lines or {}
    table.insert(self.lines, { message = message, r = r, g = g, b = b })
end
function Widget:GetNumMessages() return #(self.lines or {}) end
function Widget:ScrollToBottom() self.scrollOffset = 0 end
-- Scrolled by lines up from the newest; `visibleLines` of them fit (10 unless
-- a test says otherwise).
function Widget:GetNumVisibleLines() return self.visibleLines or 10 end
function Widget:GetMaxScrollRange()
    return math.max(0, #(self.lines or {}) - self:GetNumVisibleLines())
end
function Widget:GetScrollOffset() return self.scrollOffset or 0 end
function Widget:SetScrollOffset(offset)
    self.scrollOffset = math.max(0, math.min(offset, self:GetMaxScrollRange()))
end
function Widget:ScrollByAmount(amount) self:SetScrollOffset(self:GetScrollOffset() + amount) end
-- What the client does when a drag across the text ends: it copies, and tells
-- whoever asked to be told.
function Widget:Copy(text, numCharacters)
    if not self.textIsCopyable or not self.mouseClicks then return false end
    clipboard = text
    if self.onTextCopied then self.onTextCopied(self, text, numCharacters) end
    return true
end

local Animation = {}
Animation.__index = Animation
function Animation:SetOrder(v) self.order = v end
function Animation:SetDuration(v) self.duration = v end
function Animation:SetStartDelay(v) self.startDelay = v end
function Animation:SetFromAlpha(v) self.fromAlpha = v end
function Animation:SetToAlpha(v) self.toAlpha = v end
function Animation:SetTarget(v) self.target = v end
function Animation:SetFlipBookRows(v) self.rows = v end
function Animation:SetFlipBookColumns(v) self.columns = v end
function Animation:SetFlipBookFrames(v) self.frames = v end
function Animation:SetFlipBookFrameWidth(v) self.frameWidth = v end
function Animation:SetFlipBookFrameHeight(v) self.frameHeight = v end

local AnimationGroup = {}
AnimationGroup.__index = AnimationGroup
function AnimationGroup:CreateAnimation(kind)
    local animation = setmetatable({ kind = kind }, Animation)
    table.insert(self.animations, animation)
    return animation
end
function AnimationGroup:SetScript(name, func) self.scripts[name] = func end
function AnimationGroup:SetLooping(v) self.looping = v end
function AnimationGroup:Play() self.playing = true; self.plays = self.plays + 1 end
function AnimationGroup:Stop() self.playing = false end
function AnimationGroup:IsPlaying() return self.playing end
function AnimationGroup:Finish()
    self.playing = false
    if self.scripts.OnFinished then self.scripts.OnFinished(self) end
end
function Widget:CreateAnimationGroup()
    local group = setmetatable({ animations = {}, scripts = {}, plays = 0 }, AnimationGroup)
    self.animationGroup = group
    return group
end

UIParent:SetSize(1920, 1080)
UIParent.name = "UIParent"

-- The tooltip, as far as the addon uses one.
GameTooltip.name = "GameTooltip"
GameTooltip.lines = {}
function GameTooltip:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
function GameTooltip:SetText(text) self.lines = { text } end
function GameTooltip:AddLine(text) table.insert(self.lines, text) end
function GameTooltip:GetLines() return table.concat(self.lines, " | ") end
function GameTooltip:IsOwned(frame) return self.owner == frame end
function GameTooltip_SetDefaultAnchor(tooltip, owner) tooltip:SetOwner(owner, "ANCHOR_NONE"); tooltip.defaultAnchor = true end

GameFontNormalLarge, GameFontHighlight, GameFontHighlightSmall = {}, {}, {}
GameFontNormalSmall, GameFontDisableSmall, ChatFontNormal = {}, {}, {}
UISpecialFrames = {}

-------------------------------------------------------------------------------
-- The castbar: the player's cast, the swing timer and the game's own bars.
-------------------------------------------------------------------------------

-- The player's cast, as the game would report it. Other units read `casting`
-- from the frames stubs above.
castingInfo, channelInfo = nil, nil

function UnitCastingInfo(token)
    if token == "player" then
        local c = castingInfo
        if not c then return nil end
        return c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8]
    end
    local c = casting[token]
    if not c or c.channel then return end
    -- c.text: the cast's display text, when it is not its name.
    return c.name, c.text or c.name, "icon", c.start * 1000, c.finish * 1000, false, "cast-1",
        c.notInterruptible
end

function UnitChannelInfo(token)
    if token == "player" then
        local c = channelInfo
        if not c then return nil end
        return c[1], c[2], c[3], c[4], c[5], c[6], c[7]
    end
    local c = casting[token]
    if not c or not c.channel then return end
    if castingSecret[token] then
        local s = SecretCastValue
        return s("name"), s("name"), s("icon"), s("start"), s("end"), false, s("notInterruptible")
    end
    return c.name, c.name, "icon", c.start * 1000, c.finish * 1000, false,
        c.notInterruptible
end

-- For a unit whose casting is secret every value comes back as a secret the
-- addon may only hand on; one that is compared, concatenated or indexed
-- raises, as the client would.
function SecretCastValue(label)
    local value = setmetatable({}, {
        __tostring = function() return "secret " .. label end,
        __eq = function() error("compared a secret " .. label, 2) end,
        __lt = function() error("compared a secret " .. label, 2) end,
        __le = function() error("compared a secret " .. label, 2) end,
        __concat = function() error("concatenated a secret " .. label, 2) end,
        __index = function() error("indexed a secret " .. label, 2) end,
    })
    secretValues[value] = true
    return value
end
do
    local plainCastingInfo = UnitCastingInfo
    function UnitCastingInfo(token)
        local c = casting[token]
        if token ~= "player" and c and not c.channel and castingSecret[token] then
            local s = SecretCastValue
            return s("name"), s("name"), s("icon"), s("start"), s("end"), false, s("cast id"),
                s("notInterruptible")
        end
        return plainCastingInfo(token)
    end
end

-- The cast's time as a duration object, which a status bar can run by itself
-- (SetTimerDuration). For a secret unit the object is a secret too, whose
-- remaining time is one as well.
local function Duration(token, wantChannel)
    local c = casting[token]
    if not c or (c.channel and true or false) ~= wantChannel then return nil end
    local duration = { start = c.start, finish = c.finish, channel = wantChannel }
    function duration:GetRemainingDuration()
        if castingSecret[token] then return SecretCastValue("remaining") end
        return self.finish - GetTime()
    end
    if castingSecret[token] then secretValues[duration] = true end
    return duration
end
function UnitCastingDuration(token) return Duration(token, false) end
function UnitChannelDuration(token) return Duration(token, true) end
function Widget:SetTimerDuration(duration, interpolation, direction)
    self.timer = { duration = duration, interpolation = interpolation, direction = direction }
end
Enum = Enum or {}
Enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 }
Enum.StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 }

-- The game's own casting bar, which the castbar must take off screen.
PlayerCastingBarFrame = newWidget("Frame")
PlayerCastingBarFrame.name = "PlayerCastingBarFrame"

-- Cooldowns are read by the Cooldowns module alone, and only through what is
-- documented NeverSecret (SpellCooldownInfo.isActive/isOnGCD) plus duration
-- objects handed straight to a bar. The addon drew a global cooldown bar until
-- 2026-09-22, and its third design threw once per frame in game because a
-- duration object's IsActive() is a secret boolean in combat. So every cooldown
-- call raises here by default, and anything else that goes looking for one
-- fails in this harness instead of in somebody's raid; tests/cooldowns.lua
-- replaces these with a model of the secret rules for the module it tests.
local function forbidden(what)
    return function()
        error("the addon read " .. what .. ", which is secret in combat "
            .. "and is why the global cooldown bar was removed", 2)
    end
end

C_ActionBar = {
    GetActionCooldown = forbidden("C_ActionBar.GetActionCooldown"),
    GetActionCooldownDuration = forbidden("C_ActionBar.GetActionCooldownDuration"),
}
GetSpellCooldown = forbidden("GetSpellCooldown")

-- What a spell costs, for the five-second rule. Spell 1 costs mana; spell 2
-- is free.
spellCosts = { [1] = { { type = 0, cost = 100 } }, [2] = {} }
C_Spell = {
    GetSpellCooldown = forbidden("C_Spell.GetSpellCooldown"),
    GetSpellPowerCost = function(spellID) return spellCosts[spellID] end,
    GetSpellName = function(spellID)
        if spellID == 7620 then return "Fishing" end
        if spellID == 818 then return "Basic Campfire" end
        return nil
    end,
    GetSpellInfo = function(spell)
        if spell == "Fishing" and knowsFishing then return { name = "Fishing" } end
        return nil
    end,
}

-- What the world cursor is over, as the game's world tooltip gets it: nil, or
-- tooltip data ({ type = Enum.TooltipDataType.*, lines = { { leftText } } }).
worldCursor = nil
C_TooltipInfo = {
    GetWorldCursor = function() return worldCursor end,
}

Enum = Enum or {}
Enum.TooltipDataType = { Unit = 2, Object = 4 }
Enum.PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 }
SWING_TIMER_MAIN_HAND = "Main Hand"
SWING_TIMER_OFF_HAND = "Off Hand"
SWING_TIMER_RANGED = "Ranged"
RED_FONT_COLOR = { GetRGB = function() return 1, 0.125, 0.125 end }

-- Main hand only unless a test equips more. The game reports no speed for a
-- slot with nothing in it.
attackSpeed = { 2.6, nil, nil }
function UnitAttackSpeed() return attackSpeed[1], attackSpeed[2], attackSpeed[3] end

-- Which hands have asked for range events, and where the target is for each.
-- Nil is "no check could be made", which must never read as out of range.
rangeChecks, inRange = {}, {}
C_SwingTimer = {
    EnableRangeCheck = function(swingType, enable) rangeChecks[swingType] = enable end,
    IsTargetWithinSwingRange = function(swingType) return inRange[swingType] end,
}

-- The game's own swing bars. Edit Mode's opacity setting writes the frame's
-- alpha - the preset layout ships it at 50 - which is one of the things the
-- addon has to keep undoing.
local function BlizzardSwingFrame(name)
    local frame = newWidget("Frame")
    frame.name = name
    function frame:UpdateSystemSettingOpacity() self:SetAlpha(0.5) end
    _G[name] = frame
    return frame
end
BlizzardSwingFrame("SwingTimerMainHandFrame")
BlizzardSwingFrame("SwingTimerOffHandFrame")
BlizzardSwingFrame("SwingTimerRangedFrame")

-------------------------------------------------------------------------------
-- The five-second rule.
-------------------------------------------------------------------------------

playerDead = false
function UnitIsDead() return playerDead end

-- The game player frame's mana bar, which the countdown can sit inside. Absent
-- unless a test puts one there.
playerManaBar = nil
function PlayerFrame_GetManaBar() return playerManaBar end

-------------------------------------------------------------------------------
-- The chat: the game's chat windows, recording every call that would change
-- one, and the helpers the copy window uses.
-------------------------------------------------------------------------------

clipboard = nil
function BreakUpLargeNumbers(value) return tostring(value) end

scrollWiring = {}
ScrollUtil = {
    InitScrollingMessageFrameWithScrollBar = function(messageFrame, scrollBar)
        scrollWiring[#scrollWiring + 1] = { messageFrame = messageFrame, scrollBar = scrollBar }
    end,
}

chatEdits = {}

function NewChatWindow(name, messages, tabText)
    local window = { name = name, messages = messages }

    local function record(method)
        return function(self)
            chatEdits[#chatEdits + 1] = self.name .. ":" .. method
        end
    end

    -- Everything the addon must not do to a chat window. None of these are
    -- implemented: being called at all is the failure.
    for _, method in ipairs({ "SetTextCopyable", "SetMouseClickEnabled", "SetPassThroughButtons",
                              "SetOnTextCopiedCallback", "HookScript", "SetScript", "EnableMouse",
                              "SetParent", "SetMaxLines", "Clear", "AddMessage" }) do
        window[method] = record(method)
    end

    window.shown = true
    window.GetName = function(self) return self.name end
    window.IsShown = function(self) return self.shown end
    window.GetNumMessages = function(self) return #self.messages end
    window.GetMessageInfo = function(self, index)
        local entry = self.messages[index]
        if not entry then return nil end
        return entry[1], entry[2], entry[3], entry[4]
    end

    _G[name] = window
    _G[name .. "Tab"] = { Text = { GetText = function() return tabText end } }
    return window
end

-- A value that cannot be read, the way this client's secret values behave:
-- touching it in any way raises.
function Unreadable(label)
    local function raise()
        error("the addon read " .. label .. ", which can be a secret value on this client", 2)
    end
    local value = setmetatable({}, {
        __index = raise, __concat = raise, __len = raise,
        __tostring = raise, __lt = raise, __le = raise,
        __add = raise, __call = raise,
    })
    secretValues[value] = true
    return value
end

-------------------------------------------------------------------------------
-- The menus: the game's micro menu and bag bar, as objects of their own that
-- record every call the addon must not make on them.
-------------------------------------------------------------------------------

forbiddenCalls = {}
local FORBIDDEN = {
    "Show", "Hide", "SetShown", "SetScript", "SetPoint", "ClearAllPoints",
    "SetParent", "SetSize", "SetWidth", "SetHeight", "SetScale", "Layout",
    "SetAtlas", "SetTexture", "SetNormalAtlas", "SetPushedAtlas",
}

local Blizzard = {}
Blizzard.__index = Blizzard
blizzardObjects = {}

function NewBlizzard(name)
    local w = setmetatable({
        name = name, shown = true, alpha = 1, mouse = true, hooks = {}, children = {},
    }, Blizzard)
    table.insert(blizzardObjects, w)
    return w
end

-- The game's bars the addon's own action bars take over (ActionBars\) are
-- moved out of sight on purpose: their calls are kept apart, in
-- `takenOverCalls`, and a reparent is done.
takenOverCalls = {}
for _, method in ipairs(FORBIDDEN) do
    Blizzard[method] = function(self, a)
        if self.takenOver then
            table.insert(takenOverCalls, tostring(self.name) .. ":" .. method)
            if method == "SetParent" then self.parent, self.parentFrame = a, a end
            return
        end
        table.insert(forbiddenCalls, tostring(self.name) .. ":" .. method)
    end
end
function Blizzard:SetAlpha(a) self.alpha = a end
function Blizzard:GetAlpha() return self.alpha end
function Blizzard:EnableMouse(v) self.mouse = v and true or false end
function Blizzard:IsMouseEnabled() return self.mouse end
function Blizzard:IsShown() return self.shown end
function Blizzard:GetChildren() return unpack(self.children) end
function Blizzard:HookScript(script, fn)
    self.hooks[script] = self.hooks[script] or {}
    table.insert(self.hooks[script], fn)
end
-- Which of the game's frames the mouse is over: the micro menu by its own flag,
-- anything else by being in `mouseOver`.
mouseOver = {}
function Blizzard:IsMouseOver()
    if self == MicroMenu then return mouseOverMenu end
    return mouseOver[self] == true
end
-- Where a frame sits, for anything that asks which way it faces: `center` if a
-- test gave it one, the middle of the screen otherwise.
function Blizzard:GetCenter()
    local c = self.center or { 960, 540 }
    return c[1], c[2]
end
function Blizzard:GetEffectiveScale() return 1 end
function Blizzard:GetScale() return self.scale or 1 end
function Blizzard:IsProtected() return self.protected == true end
-- Vertex colour, kept beside the object so it adds no field to it.
vertexColors = setmetatable({}, { __mode = "k" })
function Blizzard:SetVertexColor(r, g, b, a) vertexColors[self] = { r, g, b, a or 1 } end
function Blizzard:GetVertexColor()
    local v = vertexColors[self] or { 1, 1, 1, 1 }
    return v[1], v[2], v[3], v[4]
end
function VertexAlpha(region) return select(4, region:GetVertexColor()) end
function Blizzard:GetFrameLevel() return 1 end
function Blizzard:GetName() return self.name end
-- A button: enabled unless a test says not, and "PUSHED" while the game holds
-- it down for its open window.
function Blizzard:IsEnabled() return self.enabled ~= false end
function Blizzard:GetButtonState() return self.buttonState or "NORMAL" end
function Blizzard:GetParent() return self.parentFrame end
function Blizzard:GetBottom() return self.bottom or 0 end
function Blizzard:GetAtlas() return self.atlasName end
function Blizzard:GetNormalTexture() return self.normalTexture end
function Blizzard:GetPushedTexture() return self.pushedTexture end
function Blizzard:GetDisabledTexture() return self.disabledTexture end
function Blizzard:GetHighlightTexture() return self.highlightTexture end
function Blizzard:GetRegions() return unpack(self.regions or {}) end
function Blizzard:GetObjectType() return self.objectType or "Frame" end
function Blizzard:IsObjectType(t) return self:GetObjectType() == t end

-- The game showing or hiding one of its own frames, hooks and all.
function BlizzardSetShown(frame, shown)
    frame.shown = shown
    for _, fn in ipairs(frame.hooks[shown and "OnShow" or "OnHide"] or {}) do fn(frame) end
end

-- The action bars, under their Mainline names (Blizzard_ActionBar). The
-- extra bars ship hidden until Edit Mode turns them on; here they are all on.
for _, name in ipairs({
    "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
    "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar",
}) do
    _G[name] = NewBlizzard(name)
end

-- What is on the cursor (a spell being dragged, say), Edit Mode, and a spell
-- flyout: each makes every faded action bar show.
cursorInfo = nil
function GetCursorInfo() return cursorInfo end
EditModeManagerFrame = { active = false, raidStyleParty = false, alpha = 1 }
function EditModeManagerFrame:IsEditModeActive() return self.active end
-- Its window as a widget: what the addon may do to it is set its opacity
-- and lay a frame of its own over it.
function EditModeManagerFrame:SetAlpha(a) self.alpha = a end
function EditModeManagerFrame:GetAlpha() return self.alpha end
function EditModeManagerFrame:GetFrameStrata() return "DIALOG" end
function EditModeManagerFrame:GetFrameLevel() return 1 end
-- Edit Mode's Party Frames "Use Raid-Style Party Frames"; a test sets it.
function EditModeManagerFrame:UseRaidStylePartyFrames() return self.raidStyleParty end
-- Its window's switches and grid (EditModeGridMixin: lines every
-- gridSpacing from its middle), the systems it knows, and the one method an
-- addon may call on it (a secure delegate in game), counted.
EditModeManagerFrame.snapEnabled = true
EditModeManagerFrame.registeredSystemFrames = {}
EditModeManagerFrame.cleared = 0
function EditModeManagerFrame:ClearSelectedSystem() self.cleared = self.cleared + 1 end
-- Whether Edit Mode may be entered now (off: the addon's own unlock).
EditModeManagerFrame.canEnter = false
function EditModeManagerFrame:CanEnterEditMode() return self.canEnter end
-- Its window's buttons: Save, Revert All Changes, and the close button.
for _, key in ipairs({ "SaveChangesButton", "RevertAllChangesButton", "CloseButton" }) do
    local button = CreateFrame("Button")
    button.enabled = false
    function button:SetEnabled(on) self.enabled = on and true or false end
    EditModeManagerFrame[key] = button
end
-- The game's own unsaved-changes flag, as SetHasActiveChanges keeps it.
EditModeManagerFrame.hasActiveChanges = false
function EditModeManagerFrame:SetHasActiveChanges(has)
    self.hasActiveChanges = has and true or false
    self.SaveChangesButton:SetEnabled(has)
    self.RevertAllChangesButton:SetEnabled(has)
end
-- editModeActive, as the manager keeps it beside IsEditModeActive.
setmetatable(EditModeManagerFrame, { __index = function(self, key)
    if key == "editModeActive" then return rawget(self, "active") end
end })
-- The show / hide switches in its window (EditModeAccountSettingsMixin).
EditModeManagerFrame.AccountSettings = { settingsCheckButtons = {} }
for _, key in ipairs({ "TargetAndFocus", "PartyFrames", "CastBar", "PetFrame", "SwingTimer" }) do
    local switch = { checked = true }
    function switch:IsControlChecked() return self.checked end
    EditModeManagerFrame.AccountSettings.settingsCheckButtons[key] = switch
end
-- The layouts as the client keeps them (C_EditMode): the saved ones, the
-- active one counted after the game's presets, which the game makes in Lua
-- (EditModePresetLayoutManager). What SaveLayouts is handed is kept, presets
-- left out, and the last call is kept to look at; choosing a layout or
-- adding one makes the game read them again (EDIT_MODE_LAYOUTS_UPDATED).
Enum.EditModeLayoutType = { Preset = 0, Account = 1, Character = 2, Server = 3 }
Constants = Constants or {}
Constants.EditModeConsts = { EditModeMaxLayoutsPerType = 5 }
local function Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, inner in pairs(value) do copy[key] = Copy(inner) end
    return copy
end
EditModePresetLayoutManager = {
    presets = {
        { layoutName = "Modern", layoutType = 0, systems = {} },
        { layoutName = "Classic", layoutType = 0, systems = {} },
    },
    defaults = {},      -- [system] = the default anchor a test gives it
}
function EditModePresetLayoutManager:GetCopyOfPresetLayouts() return Copy(self.presets) end
function EditModePresetLayoutManager:GetDefaultSystemAnchorInfo(system)
    return self.defaults[system]
end
C_EditMode = { saved = { activeLayout = 1, layouts = {} }, reads = 0 }
function C_EditMode.GetLayouts() return Copy(C_EditMode.saved) end
function C_EditMode.SaveLayouts(info)
    local kept = {}
    for _, layout in ipairs(info.layouts) do
        if layout.layoutType ~= 0 then kept[#kept + 1] = Copy(layout) end
    end
    C_EditMode.saved = { activeLayout = info.activeLayout, layouts = kept }
    C_EditMode.lastSave = Copy(info)
end
local function LayoutsRead()
    C_EditMode.reads = C_EditMode.reads + 1
    Fire("EDIT_MODE_LAYOUTS_UPDATED")
end
function C_EditMode.SetActiveLayout(index)
    C_EditMode.saved.activeLayout = index
    LayoutsRead()
end
function C_EditMode.OnLayoutAdded(index, activate)
    if activate then C_EditMode.saved.activeLayout = index end
    LayoutsRead()
end
function C_EditMode.IsValidLayoutName(name) return type(name) == "string" and name ~= "" end
-- The game's own settings window for one of its frames, opened as the game
-- selects a frame (a click on its box); its rows are the game's pooled
-- setting frames (a test adds them). Selecting is the game's code, as the
-- player's click runs it; ClearSelectedSystem (counted above) closes it.
EditModeSystemSettingsDialog = CreateFrame("Frame", "EditModeSystemSettingsDialog", UIParent)
EditModeSystemSettingsDialog.shown = false
EditModeSystemSettingsDialog.strata = "DIALOG"
EditModeSystemSettingsDialog.frameLevel = 200
EditModeSystemSettingsDialog.Title = EditModeSystemSettingsDialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
EditModeSystemSettingsDialog.Border = CreateFrame("Frame", nil, EditModeSystemSettingsDialog)
EditModeSystemSettingsDialog.Settings = CreateFrame("Frame", nil, EditModeSystemSettingsDialog)
EditModeSystemSettingsDialog.Settings.rows = {}
function EditModeSystemSettingsDialog.Settings:GetChildren() return unpack(self.rows) end
function EditModeSystemSettingsDialog:UpdateDialog() end
function EditModeSystemSettingsDialog:AttachToSystemFrame(system)
    self.attachedToSystem = system
    self.Title:SetText(system:GetSystemName())
    self:UpdateDialog(system)
    self:Show()
end
function EditModeManagerFrame:SelectSystem(system)
    for _, other in ipairs(self.registeredSystemFrames) do other.isSelected = nil end
    system.isSelected = true
    EditModeSystemSettingsDialog:AttachToSystemFrame(system)
end
local clearSelected = EditModeManagerFrame.ClearSelectedSystem
function EditModeManagerFrame:ClearSelectedSystem()
    clearSelected(self)
    for _, other in ipairs(self.registeredSystemFrames) do other.isSelected = nil end
    -- (The harness's Hide runs no OnHide; the game's window has one.)
    local dialog = EditModeSystemSettingsDialog
    dialog:Hide()
    for _, hook in ipairs(dialog.hooks.OnHide or {}) do hook(dialog) end
end
-- Its own layout list (a dropdown that opens on the player's press), and
-- whether a preset is the layout in use.
EditModeManagerFrame.LayoutDropdown = CreateFrame("Button", nil, UIParent)
EditModeManagerFrame.LayoutDropdown:SetParent(EditModeManagerFrame)
EditModeManagerFrame.LayoutDropdown:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPLEFT", 25, -52)
EditModeManagerFrame.LayoutDropdown:SetWidth(210)
EditModeManagerFrame.presetActive = false
function EditModeManagerFrame:IsActiveLayoutPreset() return self.presetActive end
function EditModeManagerFrame:HasActiveChanges() return self.hasActiveChanges end
-- A reload of the UI, counted (the addon reloads for what the game takes
-- in only as it loads).
ReloadCount = 0
function ReloadUI() ReloadCount = ReloadCount + 1 end
function HideUIPanel(frame) frame:Hide() end
-- The game's addon list.
C_AddOns = C_AddOns or {}
function C_AddOns.GetAddOnMetadata() return nil end
function C_AddOns.DisableAddOn() end
function C_AddOns.SaveAddOns() end
-- Forever's beta ships the Issue Reporter.
function C_AddOns.DoesAddOnExist(name) return name == "Blizzard_PTRFeedback" end
-- The game's descriptions of each system's settings, as its Edit Mode window
-- shows them (EditModeSettingDisplayInfoManager); a test gives a system its
-- list. And the one way the game applies a setting live, counted: the addon
-- must never call it.
Enum.EditModeSettingDisplayType = { Dropdown = 0, Checkbox = 1, Slider = 2 }
Enum.EditModeUnitFrameSetting = { HidePortrait = 0, UseRaidStylePartyFrames = 2, FrameSize = 3 }
EditModeSettingDisplayInfoManager = { infos = {} }
function EditModeSettingDisplayInfoManager:GetSystemSettingDisplayInfo(system) return self.infos[system] end
function EditModeSettingDisplayInfoManager:GetSystemSettingDisplayInfoMap(system)
    local map = {}
    for _, info in ipairs(self.infos[system] or {}) do map[info.setting] = info end
    return map
end
EditModeManagerFrame.settingChangesApplied = 0
function EditModeManagerFrame:OnSystemSettingChange() self.settingChangesApplied = self.settingChangesApplied + 1 end
EditModeManagerFrame.Grid = NewBlizzard("EditModeManagerFrame.Grid")
EditModeManagerFrame.Grid.gridSpacing = 100
EditModeManagerFrame.Grid.shown = false
EditModeManagerFrame.Grid.center = { 960, 540 }

-- The game's callback registry: listeners per event, called in order.
EventRegistry = { callbacks = {} }
function EventRegistry:RegisterCallback(event, func, owner)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], { func = func, owner = owner })
end
function EventRegistry:TriggerEvent(event, ...)
    for _, listener in ipairs(self.callbacks[event] or {}) do listener.func(listener.owner, ...) end
end

-- The game's party frame: four pooled member frames (secure unit buttons),
-- each with its pet, and the background behind them. The game sets a member's
-- alpha itself (0.6 while phased), and goes over its members in
-- UpdatePartyFrames whenever the group or the raid-style setting changes.
PartyFrame = NewBlizzard("PartyFrame")
-- Taken away whole by the addon (Frames\BlizzardFrames.lua, RetireParty):
-- reparented under a hidden frame, its events off.
PartyFrame.takenOver = true
PartyFrame.Background = NewBlizzard("PartyFrame.Background")
for index = 1, 4 do
    local member = NewBlizzard("PartyFrame.MemberFrame" .. index)
    member.PetFrame = NewBlizzard("PartyFrame.MemberFrame" .. index .. ".PetFrame")
    -- The mixin's methods, copied onto the frame as the game's mixins are:
    -- UpdateNotPresentIcon sets the member's alpha (1, or 0.6 while phased).
    member.phased = false
    function member:UpdateNotPresentIcon() self:SetAlpha(self.phased and 0.6 or 1) end
    function member:UpdateMember() self:UpdateNotPresentIcon() end
    PartyFrame["MemberFrame" .. index] = member
end
-- Showing the party frame builds its members afresh, each one set up (alpha 1).
function PartyFrame:InitializePartyMemberFrames()
    for index = 1, 4 do self["MemberFrame" .. index]:UpdateMember() end
end
function PartyFrame:UpdatePartyFrames() end
function PartyFrame:UpdatePartyMemberBackground() self.Background:Show() end

-- The raid-style frames: made by the game as needed, each set up through
-- CompactUnitFrame_SetUpFrame. A test makes one with NewCompactFrame.
function CompactUnitFrame_SetUpFrame(frame, func, ...) if func then func(frame, ...) end end
function NewCompactFrame(name)
    local frame = CreateFrame("Button", name, UIParent)
    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetAtlas("raidframe-hp-bg-white")
    frame.healthBar = CreateFrame("StatusBar", nil, frame)
    frame.healthBar:SetStatusBarTexture("RaidFrame-Hp-Fill")
    frame.powerBar = CreateFrame("StatusBar", nil, frame)
    frame.powerBar:SetStatusBarTexture("_RaidFrame-Resource-Fill")
    frame.powerBar.background = frame.powerBar:CreateTexture(nil, "BACKGROUND")
    return frame
end
SpellFlyout = NewBlizzard("SpellFlyout")
SpellFlyout.shown = false
-- The spellbook: a tab of PlayerSpellsFrame, beside the talents, as Camelot
-- builds it (Blizzard_PlayerSpells/Camelot).
PlayerSpellsFrame = NewBlizzard("PlayerSpellsFrame")
PlayerSpellsFrame.shown = false
PlayerSpellsFrame.SpellBookFrame = NewBlizzard("PlayerSpellsFrame.SpellBookFrame")
PlayerSpellsFrame.TalentsFrame = NewBlizzard("PlayerSpellsFrame.TalentsFrame")
PlayerSpellsFrame.TalentsFrame.shown = false

-- The menu sits in its Edit Mode container unless the game lends it to
-- another bar.
MicroMenuContainer = NewBlizzard("MicroMenuContainer")
MicroMenu = NewBlizzard("MicroMenu")
MicroMenu.parentFrame = MicroMenuContainer
MicroMenu.BorderArt = NewBlizzard("MicroMenu.BorderArt")
MicroMenu.BackgroundArt = NewBlizzard("MicroMenu.BackgroundArt")
mouseOverMenu = false

-- The buttons, with every piece of art the template gives them
-- (Blizzard_MicroMenu\Mainline\MainMenuBarMicroButtons.xml): the backing, the
-- four state textures, the alert flash.
local function MicroButton(name, index, extras)
    local b = NewBlizzard(name)
    b.layoutIndex = index
    b.Background = NewBlizzard(name .. ".Background")
    b.PushedBackground = NewBlizzard(name .. ".PushedBackground")
    b.PushedBackground.shown = false
    b.FlashBorder = NewBlizzard(name .. ".FlashBorder")
    b.FlashBorder.shown = false
    b.FlashContent = NewBlizzard(name .. ".FlashContent")
    b.FlashContent.shown = false
    b.normalTexture = NewBlizzard(name .. ".Normal")
    b.normalTexture.atlasName = "UI-HUD-MicroMenu-" .. name .. "-Up"
    b.pushedTexture = NewBlizzard(name .. ".Pushed")
    b.disabledTexture = NewBlizzard(name .. ".Disabled")
    b.highlightTexture = NewBlizzard(name .. ".Highlight")
    for _, key in ipairs(extras or {}) do
        b[key] = NewBlizzard(name .. "." .. key)
    end
    _G[name] = b
    return b
end

MicroButton("CharacterMicroButton", 1, { "Shadow", "PushedShadow", "Portrait" })
MicroButton("TalentMicroButton", 2)
MicroButton("QuestLogMicroButton", 3)
MicroButton("MainMenuMicroButton", 4, { "MainMenuBarPerformanceBar" })
MicroMenu.children = { CharacterMicroButton, TalentMicroButton, QuestLogMicroButton,
    MainMenuMicroButton }

-- The talents, as this client has them: one trait tree in the active config,
-- split in the classic three (trait groups), each with its icon and the points
-- spent in it. `talentTrees[i] = { groupID, icon, spent }`; no config at all
-- before level ten.
talentConfigID = 7
talentTrees = {
    { groupID = 101, icon = 1001, spent = 0 },
    { groupID = 102, icon = 1002, spent = 0 },
    { groupID = 103, icon = 1003, spent = 0 },
}
C_ClassTalents = { GetActiveConfigID = function() return talentConfigID end }
C_Traits = {
    GetConfigInfo = function(configID)
        if configID == talentConfigID then return { ID = configID, treeIDs = { 55 } } end
    end,
    GetGroupDisplayInfoByTreeID = function(treeID)
        local out = {}
        for i, tree in ipairs(talentTrees) do
            out[i] = { groupID = tree.groupID, treeID = treeID, orderIndex = i,
                       displayName = "Tree " .. i, icon = tree.icon }
        end
        return out
    end,
    GetGroupCurrencyInfo = function(configID, groupIDs)
        local out = {}
        for _, id in ipairs(groupIDs) do
            for _, tree in ipairs(talentTrees) do
                if tree.groupID == id then
                    out[#out + 1] = { traitNodeGroupID = id, currencyInfos = { { spent = tree.spent } } }
                end
            end
        end
        return out
    end,
}

-- A micro button's anchors and hit box, kept beside it (no new field): the
-- addon lays the row out itself, and the game's own layout lays it out again
-- whenever it runs.
microPoints, microHitRects = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
for _, b in ipairs(MicroMenu.children) do
    function b:ClearAllPoints() microPoints[self] = {} end
    function b:SetPoint(point, relativeTo, relativePoint, x, y)
        microPoints[self] = microPoints[self] or {}
        table.insert(microPoints[self], { point, relativeTo, relativePoint, x or 0, y or 0 })
    end
    function b:SetHitRectInsets(l, r, t, bottom) microHitRects[self] = { l, r, t, bottom } end
end
-- MicroMenuMixin:Layout: the game's grid, every shown button anchored to the
-- menu, 27 apart (32 wide, childXPadding -5).
gameLayouts = 0
function MicroMenu:Layout()
    gameLayouts = gameLayouts + 1
    local x = 0
    for _, b in ipairs(self.children) do
        if b.layoutIndex and b.shown then
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self, "TOPLEFT", x, 0)
            x = x + 27
        end
    end
end

slotShowHide = {}

-- A bag slot, with every region its template declares - the icon mask
-- included, which is the one a fade once cut the bags out of their slots with.
local function BagButton(name)
    local b = NewBlizzard(name)
    b.normalTexture = NewBlizzard(name .. ".Normal")
    b.pushedTexture = NewBlizzard(name .. ".Pushed")
    b.highlightTexture = NewBlizzard(name .. ".Highlight")
    b.highlightTexture.alpha = 0.4
    b.icon = NewBlizzard(name .. ".icon")
    b.Count = NewBlizzard(name .. ".Count")
    b.SquareMask = NewBlizzard(name .. ".SquareMask")
    b.SquareMask.objectType = "MaskTexture"
    b.regions = { b.normalTexture, b.pushedTexture, b.highlightTexture, b.icon, b.Count,
        b.SquareMask }
    b.Show = function(self)
        table.insert(slotShowHide, self.name .. ":Show")
        self.shown = true
        for _, fn in ipairs(self.hooks.OnShow or {}) do fn(self) end
    end
    b.Hide = function(self)
        table.insert(slotShowHide, self.name .. ":Hide")
        self.shown = false
        for _, fn in ipairs(self.hooks.OnHide or {}) do fn(self) end
    end
    _G[name] = b
    return b
end

local function NewPool(prefix)
    local pool = { activeObjects = {}, made = 0 }
    function pool:Acquire()
        self.made = self.made + 1
        local d = NewBlizzard(prefix .. self.made)
        self.activeObjects[d] = true
        return d
    end
    function pool:ReleaseAll() self.activeObjects = {} end
    function pool:EnumerateActive() return pairs(self.activeObjects) end
    return pool
end

BagsBar = NewBlizzard("BagsBar")
BagsBar.BorderArt = NewBlizzard("BagsBar.BorderArt")

-- Its size and place, through the plain methods Edit Mode keeps as *Base
-- (EditModeSystemMixin:OnSystemLoad) - the only ones the addon may use on it
-- (ActionBars\GameFrames.lua). Its place recorded in `basePoints`.
BagsBar.scale, BagsBar.width, BagsBar.height, BagsBar.basePoints = 1, 200, 40, {}
function BagsBar:GetScale() return self.scale end
function BagsBar:GetEffectiveScale() return self.scale end
function BagsBar:SetScaleBase(scale) self.scale = scale end
function BagsBar:GetWidth() return self.width end
function BagsBar:GetHeight() return self.height end
function BagsBar:ClearAllPointsBase() self.basePoints = {} end
function BagsBar:SetPointBase(...) table.insert(self.basePoints, { ... }) end

-- The bag bar is the one menu frame the addon hides and shows, whole: every
-- such call is kept in `barShowHide`, and refused in combat if the bar is
-- protected, as the game refuses it.
barShowHide = {}
function BagsBar:Show()
    if inCombat and self.protected then
        table.insert(blocked, "BagsBar:Show")
        return
    end
    table.insert(barShowHide, "Show")
    self.shown = true
end
function BagsBar:Hide()
    if inCombat and self.protected then
        table.insert(blocked, "BagsBar:Hide")
        return
    end
    table.insert(barShowHide, "Hide")
    self.shown = false
end

-- The game's own hiding of the bag bar when a gamepad takes over
-- (Blizzard_ActionBar\Shared\MainActionBar.lua), and showing it again after.
function MainActionBar_InitializeGamepad() BlizzardSetShown(BagsBar, false) end
function MainActionBar_InitializeMKB() BlizzardSetShown(BagsBar, true) end

-- The bag calls a click on the backpack makes, recorded in `bagCalls`.
bagCalls = {}
cursorItem = false
modifiedOpenAll = false
function IsModifiedClick(what) return what == "OPENALLBAGS" and modifiedOpenAll end
function ToggleAllBags() table.insert(bagCalls, "ToggleAllBags") end
function ToggleBag(id) table.insert(bagCalls, "ToggleBag" .. tostring(id)) end
function PutItemInBackpack()
    if not cursorItem then return false end
    cursorItem = false
    table.insert(bagCalls, "PutItemInBackpack")
    return true
end
C_Container = C_Container or {}
function C_Container.CalculateTotalNumberOfFreeBagSlots() return 7 end
BACKPACK_TOOLTIP = "Backpack"
NUM_FREE_SLOTS = "(%d free)"
function MicroButtonTooltipText(text, action) return text .. " (B)" end

-- Which files this client has: all of them, but those a test takes away.
missingFiles = {}
function GetFileIDFromPath(path) if not missingFiles[path] then return 1 end end
-- The player's portrait, drawn into a texture.
function SetPortraitTexture(texture, unit)
    texture.portraitOf = unit
    texture.portraitDraws = (texture.portraitDraws or 0) + 1
end
BagsBar.HorizontalDividersPool = NewPool("HDivider")
BagsBar.VerticalDividersPool = NewPool("VDivider")

BagButton("MainMenuBarBackpackButton")

-- The backpack's icon mask takes anchors for real, since the game's own code
-- moves it: MainMenuBarBackpackMixin:UpdateItemContextOverlayTextures
-- (Shared\MainMenuBarBagButtons.lua) re-anchors it to an inset box whenever the
-- backpack is dimmed, and nothing anchors it back. The template has it centred
-- on the icon (Camelot\MainMenuBarBagButtons.xml).
do
    local b = MainMenuBarBackpackButton
    local mask = b.SquareMask
    mask.points = { { "CENTER", b.icon, "CENTER", 0, 0 } }
    function mask:ClearAllPoints() self.points = {} end
    function mask:SetPoint(point, relativeTo, relativePoint, x, y)
        if type(relativePoint) ~= "string" then
            relativePoint, x, y = point, relativePoint, x
        end
        table.insert(self.points, { point, relativeTo, relativePoint, x or 0, y or 0 })
    end
    b.ItemContextOverlay = NewBlizzard("MainMenuBarBackpackButton.ItemContextOverlay")
    b.ItemContextOverlay.shown = false
    function b:UpdateItemContextOverlayTextures(contextMode)
        if contextMode then
            self.SquareMask:ClearAllPoints()
            self.SquareMask:SetPoint("TOPLEFT", self, "TOPLEFT", 4, -4)
            self.SquareMask:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -6, 6)
        end
    end
    -- ItemButtonMixin:UpdateItemContextOverlay, as the game calls it.
    function b:UpdateItemContextOverlay(contextMode)
        if contextMode then self:UpdateItemContextOverlayTextures(contextMode) end
        self.ItemContextOverlay.shown = contextMode ~= nil
    end
end

BagButton("CharacterBag0Slot")
BagButton("CharacterBag1Slot")
BagButton("CharacterReagentBag0Slot")
BagButton("KeyRingButton")
KeyRingButton.mouse = false -- a slot that never took the mouse must not start to

allBagButtons = {
    MainMenuBarBackpackButton, CharacterBag0Slot, CharacterBag1Slot,
    CharacterReagentBag0Slot, KeyRingButton,
}
MainMenuBarBagManager = {}
function MainMenuBarBagManager:EnumerateBagButtons() return ipairs(allBagButtons) end

function BagsBar:Layout()
    self.HorizontalDividersPool:ReleaseAll()
    for _ = 1, #allBagButtons - 1 do self.HorizontalDividersPool:Acquire() end
end
BagsBar:Layout()

ContainerFrameContainer = { ContainerFrames = {} }
for i = 1, 6 do
    local f = NewBlizzard("ContainerFrame" .. i)
    f.shown = false
    ContainerFrameContainer.ContainerFrames[i] = f
    _G["ContainerFrame" .. i] = f
end
ContainerFrameCombinedBags = NewBlizzard("ContainerFrameCombinedBags")
ContainerFrameCombinedBags.shown = false
-- Every bag window tells the game's callback registry as it shows and hides
-- (ContainerFrame_OnShow / OnHide, Blizzard_UIPanels_Game\Mainline).
local bagWindows = { ContainerFrameCombinedBags }
for _, f in ipairs(ContainerFrameContainer.ContainerFrames) do bagWindows[#bagWindows + 1] = f end
for _, f in ipairs(bagWindows) do
    f:HookScript("OnShow", function(self) EventRegistry:TriggerEvent("ContainerFrame.OpenBag", self) end)
    f:HookScript("OnHide", function(self) EventRegistry:TriggerEvent("ContainerFrame.CloseBag", self) end)
end

function IsAnyBagOpen()
    if ContainerFrameCombinedBags.shown then return true end
    for _, f in ipairs(ContainerFrameContainer.ContainerFrames) do
        if f.shown then return true end
    end
    return false
end

-------------------------------------------------------------------------------
-- The XP bar: the player's XP, and the game's own status-tracking containers,
-- as Blizzard objects that record every call the addon must not make on them.
-------------------------------------------------------------------------------

xp = { current = 2500, max = 10000, rested = 1500, canShow = true }
function UnitXP() return xp.current end
function UnitXPMax() return xp.max end
function GetXPExhaustion() return xp.rested end
GameRulesUtil = { CanShowExperienceBar = function() return xp.canShow end }

StatusTrackingBarInfo = { BarsEnum = { None = -1, Reputation = 1, Honor = 2, Artifact = 3, Experience = 4, HouseFavor = 6 } }

-- The house the player tracks ("Show as Experience Bar"), and the favor its
-- levels need; a test sets them. Its favor only ever arrives by event.
house = { tracked = nil, maxLevel = 10, requested = 0 }
C_Housing = {
    GetTrackedHouseGuid = function() return house.tracked end,
    GetCurrentHouseLevelFavor = function() house.requested = house.requested + 1 end,
    GetHouseLevelFavorForLevel = function(level) return (level - 1) * 1000 end,
    GetMaxHouseLevel = function() return house.maxLevel end,
}

-- Honor, and whether the game would show its bar (a test sets it).
honor = { current = 300, max = 1000, level = 4, canShow = false }
function UnitHonor() return honor.current end
function UnitHonorMax() return honor.max end
function UnitHonorLevel() return honor.level end

-- The faction the player watches ("Show as experience bar"); a test sets it.
watchedFaction = nil
C_Reputation = {
    GetWatchedFactionData = function() return watchedFaction end,
    IsMajorFaction = function() return false end,
}
FACTION_STANDING_LABEL4 = "Neutral"
FACTION_STANDING_LABEL5 = "Friendly"
-- No friendship factions here; the player is female (UnitSex 3).
C_GossipInfo = { GetFriendshipReputation = function() end }
function UnitSex() return 3 end

local function NewContainer(name, shown)
    local container = NewBlizzard(name)
    container.bars = {
        [StatusTrackingBarInfo.BarsEnum.Reputation] = NewBlizzard(name .. ".Reputation"),
        [StatusTrackingBarInfo.BarsEnum.Honor] = NewBlizzard(name .. ".Honor"),
        [StatusTrackingBarInfo.BarsEnum.Artifact] = NewBlizzard(name .. ".Artifact"),
        [StatusTrackingBarInfo.BarsEnum.Experience] = NewBlizzard(name .. ".Experience"),
        [StatusTrackingBarInfo.BarsEnum.HouseFavor] = NewBlizzard(name .. ".HouseFavor"),
    }
    container.BarFrameTexture = NewBlizzard(name .. ".BarFrameTexture")
    container.HorizontalDividersPool = NewPool(name .. ".Divider")
    for _ = 1, 3 do container.HorizontalDividersPool:Acquire().GetParent = function() return container end end
    container.shownBarIndex = shown
    container.pendingBarToShowIndex = false

    -- What the game does when it changes the bar a container shows, and when
    -- it lays the dividers out again - handing out fresh ones at full alpha.
    function container:ApplyPendingBarToShow()
        self.shownBarIndex = self.pendingBarToShowIndex or self.shownBarIndex
    end
    function container:UpdateDividers()
        self.HorizontalDividersPool:ReleaseAll()
        for _ = 1, 3 do
            self.HorizontalDividersPool:Acquire().GetParent = function() return self end
        end
    end
    _G[name] = container
    return container
end

-- The manager that sorts out which container shows which bar, on every zone
-- change, loading screen and reputation change.
StatusTrackingBarManager = NewBlizzard("StatusTrackingBarManager")
function StatusTrackingBarManager:UpdateBarsShown() end
function StatusTrackingBarManager:CanShowBar(index)
    return index == StatusTrackingBarInfo.BarsEnum.Honor and honor.canShow
end

NewContainer("MainStatusTrackingBarContainer", StatusTrackingBarInfo.BarsEnum.Experience)
NewContainer("SecondaryStatusTrackingBarContainer", StatusTrackingBarInfo.BarsEnum.Artifact)
function MainStatusTrackingBarContainer:GetCenter() return 960, 70 end
function MainStatusTrackingBarContainer:GetEffectiveScale() return 1 end

-------------------------------------------------------------------------------
-- Combo points: the count on the target, how many there can be, and the game's
-- own gems on the target frame.
-------------------------------------------------------------------------------

Enum.PowerType = Enum.PowerType or {}
Enum.PowerType.Mana = 0
Enum.PowerType.ComboPoints = 4

combo = { points = 0, max = 5 }
function GetComboPoints() return combo.points end

local unitPowerMax = UnitPowerMax
function UnitPowerMax(token, powerType)
    if powerType == Enum.PowerType.ComboPoints then return combo.max end
    return unitPowerMax(token)
end

-- A plain frame of the game's, on UIParent: shown and hidden by the game as the
-- points change, and allowed to be hidden by an addon.
ComboFrame = newWidget("Frame")
ComboFrame.name = "ComboFrame"
ComboFrame:Hide()

RAID_CLASS_COLORS.DRUID = { r = 1, g = 0.49, b = 0.04 }
RAID_CLASS_COLORS.ROGUE = { r = 1, g = 0.96, b = 0.41 }

-------------------------------------------------------------------------------
-- Loading the addon and driving it.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- The action buttons, as Blizzard_ActionBar builds them (ActionBarMixin:
-- ActionBar_OnLoad): each in a container of its own, which Edit Mode's Icon
-- Size scales, with ActionButtonTemplate's art - the icon under a mask, the
-- slot background and slot art, the frame, and the pressed, hover and checked
-- textures. Three a bar is plenty.
-------------------------------------------------------------------------------

local function ArtTexture(parent, atlas)
    local t = newWidget("Texture", parent)
    t.alpha, t.atlas = 1, atlas
    return t
end

local function ActionButton(bar, index)
    local container = newWidget("Frame", bar)
    container.scale = 1
    local b = newWidget("CheckButton", container)
    b.name = tostring(bar.name) .. "Button" .. index
    b.container, b.bar = container, bar
    b.icon = ArtTexture(b)
    b.IconMask = ArtTexture(b, "UI-HUD-ActionBar-IconFrame-Mask")
    b.icon.mask = b.IconMask
    b.SlotBackground = ArtTexture(b, "UI-HUD-ActionBar-IconFrame-Background")
    b.SlotArt = ArtTexture(b, "ui-hud-actionbar-iconframe-slot")
    b.NormalTexture = ArtTexture(b, "UI-HUD-ActionBar-IconFrame")
    b.PushedTexture = ArtTexture(b, "UI-HUD-ActionBar-IconFrame-Down")
    b.HighlightTexture = ArtTexture(b, "UI-HUD-ActionBar-IconFrame-Mouseover")
    b.CheckedTexture = ArtTexture(b, "UI-HUD-ActionBar-IconFrame-Mouseover")
    b.cooldown = newWidget("Cooldown", b)
    b.lossOfControlCooldown = newWidget("Cooldown", b)
    b.chargeCooldown = newWidget("Cooldown", b)
    function b:GetNormalTexture() return self.NormalTexture end
    function b:GetPushedTexture() return self.PushedTexture end
    function b:GetHighlightTexture() return self.HighlightTexture end
    function b:GetCheckedTexture() return self.CheckedTexture end
    return b
end

for _, name in ipairs({
    "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
    "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar",
}) do
    local bar = _G[name]
    bar.actionButtons = {}
    for i = 1, 3 do bar.actionButtons[i] = ActionButton(bar, i) end
end

-- Edit Mode's Icon Size, as EditModeActionBarSystemMixin:
-- UpdateSystemSettingIconSize applies it: every container of the bar scaled,
-- then the bar laid out. `laidOutAt` is each container's scale when the layout
-- ran - what the game sized the bar from.
function ApplyIconSize(bar, percent)
    for _, button in pairs(bar.actionButtons) do button.container:SetScale(percent / 100) end
    bar.laidOutAt = {}
    for i, button in pairs(bar.actionButtons) do bar.laidOutAt[i] = button.container.scale end
end

-- The main bar's own art (Mainline MainActionBar.xml) and, on Camelot, its end
-- caps: Edit Mode systems of their own (Camelot MainMenuBarEndCaps.xml).
MainActionBar.BorderArt = NewBlizzard("MainActionBar.BorderArt")
-- Its Leave Vehicle button (Shared\VehicleLeaveButton.xml): 32 square, three state textures.
MainActionBar.VehicleLeaveButton = newWidget("Button", MainActionBar)
MainActionBar.VehicleLeaveButton.width, MainActionBar.VehicleLeaveButton.height = 32, 32
for _, state in ipairs({ "Normal", "Pushed", "Highlight" }) do
    local texture = MainActionBar.VehicleLeaveButton:CreateTexture(nil, state == "Highlight" and "HIGHLIGHT" or "ARTWORK")
    MainActionBar.VehicleLeaveButton["Get" .. state .. "Texture"] = function() return texture end
end
MainActionBar.EndCaps = NewBlizzard("MainActionBar.EndCaps")
MainActionBar.EndCaps.LeftEndCap = NewBlizzard("MainActionBar.EndCaps.LeftEndCap")
MainActionBar.EndCaps.RightEndCap = NewBlizzard("MainActionBar.EndCaps.RightEndCap")
local dividers = { NewBlizzard("Divider1"), NewBlizzard("Divider2") }
MainActionBar.HorizontalDividersPool = {
    EnumerateActive = function() local i = 0; return function() i = i + 1; return dividers[i] end end,
}
function MainActionBar:UpdateDividers() end
actionBarDividers = dividers

-- Edit Mode's selection box - the blue box with the system's name - on every
-- system this addon takes over: a child frame, shown when Edit Mode
-- highlights the system, taking the mouse so it can be picked and dragged.
editModeSystems = {
    PlayerFrame, TargetFrame, FocusFrame, PlayerCastingBarFrame, PetFrame,
    MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer,
    MainActionBar.EndCaps.LeftEndCap, MainActionBar.EndCaps.RightEndCap,
}
for _, system in ipairs(editModeSystems) do
    if type(system) == "table" and not system.Selection then
        system.Selection = newWidget("Frame", system)
        system.Selection.alpha, system.Selection.mouseEnabled = 1, true
    end
end

-------------------------------------------------------------------------------
-- THE ADDON'S OWN ACTION BARS (ActionBars\): the secure parts they are built
-- of, the game's button broadcasters, and the game's action slots - empty to
-- start (`actionSlots[slot] = { texture = ... }` fills one). Stance and pet
-- buttons under the game's own names.
-------------------------------------------------------------------------------

function Widget:SetID(id) self.id = id end
function Widget:GetID() return self.id or 0 end
function Widget:SetAttributeNoHandler(key, value) self.attributes[key] = value end
function Widget:SetFrameRef(name, frame)
    self.frameRefs = self.frameRefs or {}
    self.frameRefs[name] = frame
end
function Widget:GetFrameRef(name) return self.frameRefs and self.frameRefs[name] end
function Widget:Execute() end
-- A secure header wrapping a frame's script: the snippet kept, by frame.
function Widget:WrapScript(frame, script, pre)
    self.wrapped = self.wrapped or {}
    self.wrapped[frame] = self.wrapped[frame] or {}
    self.wrapped[frame][script] = pre
end
-- A state driver's snippet run as the game would, for a test: the page set.
function Widget:ChildUpdate(name, message)
    for _, frame in ipairs(allFrames) do
        if frame.parent == self then
            local snippet = frame.attributes["_childupdate-" .. name]
            if snippet then frame.childUpdates = (frame.childUpdates or 0) + 1; frame.lastMessage = message end
        end
    end
end
attributeDrivers = {}
function RegisterAttributeDriver(frame, attribute, condition)
    attributeDrivers[frame] = attributeDrivers[frame] or {}
    attributeDrivers[frame][attribute] = condition
end
stateDriverStrings = {}
do
    local registerState = RegisterStateDriver
    function RegisterStateDriver(frame, state, condition)
        stateDriverStrings[frame] = stateDriverStrings[frame] or {}
        stateDriverStrings[frame][state] = condition
        registerState(frame, state, condition)
    end
end
ActionBarButtonEventsFrame = newWidget("Frame")
ActionBarButtonEventsFrame.frames = {}
for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS",
                         "ACTIONBAR_UPDATE_COOLDOWN" }) do
    ActionBarButtonEventsFrame.events[event] = true
end
ActionBarActionEventsFrame = newWidget("Frame")
ActionBarActionEventsFrame.events.ACTIONBAR_UPDATE_STATE = true
ActionBarParent = newWidget("Frame")

-- (The plain globals of these live only in Blizzard's deprecation fallbacks,
-- loaded only while the loadDeprecationFallbacks CVar is on - so not here.)
actionSlots = {}
function C_ActionBar.HasAction(slot) return actionSlots[slot] ~= nil end
function C_ActionBar.GetActionTexture(slot) return actionSlots[slot] and actionSlots[slot].texture end
function C_ActionBar.IsCurrentAction() return false end
function C_ActionBar.IsAutoRepeatAction() return false end
function C_ActionBar.IsEquippedAction() return false end
function C_ActionBar.IsUsableAction(slot) return actionSlots[slot] ~= nil, false end
-- Key bindings: an ordered list of { key, action }, as the game keeps them.
-- `bindings.COMMAND = "KEY"` binds a key the old way; reading it gives the
-- command's first key. A command that runs on the key's down and up (the
-- action buttons') takes no mouse wheel, as the game's.
bindingList = {}
local function FindBinding(key)
    for index, each in ipairs(bindingList) do
        if each[1] == key then return index end
    end
end
local function RunsOnUp(action)
    return type(action) == "string" and (action:find("^ACTIONBUTTON") or action:find("^MULTIACTIONBAR")
        or action:find("^BONUSACTIONBUTTON")) ~= nil
end
function SetBinding(key, action)
    if action and key:find("MOUSEWHEEL") and RunsOnUp(action) then return false end
    local index = FindBinding(key)
    if index then table.remove(bindingList, index) end
    if action then bindingList[#bindingList + 1] = { key, action } end
    return true
end
function SetBindingClick(key, buttonName, mouse)
    return SetBinding(key, "CLICK " .. buttonName .. ":" .. (mouse or "LeftButton"))
end
function GetBindingKey(command)
    local keys = {}
    for _, each in ipairs(bindingList) do
        if each[2] == command then keys[#keys + 1] = each[1] end
    end
    return unpack(keys)
end
function GetBindingAction(key)
    local index = FindBinding(key)
    return index and bindingList[index][2] or ""
end
bindings = setmetatable({}, {
    __index = function(_, command) return (GetBindingKey(command)) end,
    __newindex = function(_, command, key) SetBinding(key, command) end,
})
Enum = Enum or {}
Enum.BindingSet = { Default = 0, Account = 1, Character = 2 }
savedBindings = { [0] = {}, [1] = {}, [2] = {} }
function GetCurrentBindingSet() return 1 end
local function CopyBindings(list)
    local copy = {}
    for index, each in ipairs(list) do copy[index] = { each[1], each[2] } end
    return copy
end
function SaveBindings(set) savedBindings[set] = CopyBindings(bindingList) end
function LoadBindings(set) bindingList = CopyBindings(savedBindings[set] or {}) end
C_KeyBindings = { GetBindingContextForAction = function() return nil end }
function GetBindingName(action) return "Name of " .. action end
function GetConvertedKeyOrButton(input)
    local mouse = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
    return mouse[input] or input
end
function IsKeyPressIgnoredForBinding(key)
    return key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT"
end
function CreateKeyChordStringUsingMetaKeyState(key)
    return (ctrlDown and "CTRL-" or "") .. (shiftDown and "SHIFT-" or "") .. key
end
function GetBindingText(key) return key or "" end
function GetBindingFromClick(key) return GetBindingAction(key) end
RANGE_INDICATOR = "*"
NUM_ACTIONBAR_PAGES = 6
pages = {}
function C_ActionBar.GetActionBarPage() return 1 end
function C_ActionBar.SetActionBarPage(page) pages[#pages + 1] = page end
function C_ActionBar.GetVehicleBarIndex() return 12 end
function C_ActionBar.GetOverrideBarIndex() return 14 end
function C_ActionBar.GetTempShapeshiftBarIndex() return 13 end
shapeshiftForms = {}
function GetNumShapeshiftForms() return #shapeshiftForms end
function GetShapeshiftFormInfo(index)
    local form = shapeshiftForms[index]
    if form then return form.texture, form.active, true end
end
function GetShapeshiftFormCooldown() return 0, 0, 1 end
function CooldownFrame_Set(cooldown, start, duration, enable) cooldown.set = { start, duration, enable } end
petActions = {}
function PetHasActionBar() return next(petActions) ~= nil end
function GetPetActionInfo(index)
    local action = petActions[index]
    if action then return action.name, action.texture, false, action.active, false, false end
end
function GetPetActionCooldown() return 0, 0, 1 end
function GetPetActionSlotUsable() return true end
petBarUpdates = 0
function PetActionBar:Update() petBarUpdates = petBarUpdates + 1 end
for _, name in ipairs({ "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
                        "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar" }) do
    _G[name].takenOver = true
end
-- The extra action button's container (Blizzard_UIPanels_Game), moved into a
-- holder of the addon's (ActionBars\GameFrames.lua).
-- Made afresh for each load (Reload): the game has one per session, and two
-- loads' hooks on one would hand it back and forth between their holders.
function NewExtraAbilityContainer()
    ExtraAbilityContainer = NewBlizzard("ExtraAbilityContainer")
    ExtraAbilityContainer.takenOver = true
    ExtraAbilityContainer.Selection = NewBlizzard("ExtraAbilityContainer.Selection")
    ExtraAbilityContainer.Selection.takenOver = true
    function ExtraAbilityContainer:AddFrame() end
    function ExtraAbilityContainer:ApplySystemAnchor() end
end
NewExtraAbilityContainer()
-- Its button on its bar (ExtraActionBar.xml): 52 across, its icon and texts, the wide skin art over it.
ExtraActionBarFrame = newWidget("Frame")
ExtraActionButton1 = newWidget("CheckButton", ExtraActionBarFrame)
ExtraActionButton1.icon = ExtraActionButton1:CreateTexture(nil, "BACKGROUND")
ExtraActionButton1.IconMask = ExtraActionButton1:CreateMaskTexture()
ExtraActionButton1.icon:AddMaskTexture(ExtraActionButton1.IconMask)
ExtraActionButton1.Flash = ExtraActionButton1:CreateTexture(nil, "OVERLAY")
ExtraActionButton1.cooldown = newWidget("Cooldown", ExtraActionButton1)
ExtraActionButton1.HighlightTexture = ExtraActionButton1:CreateTexture(nil, "HIGHLIGHT")
ExtraActionButton1.PushedTexture = ExtraActionButton1:CreateTexture(nil, "ARTWORK")
function ExtraActionButton1:GetHighlightTexture() return self.HighlightTexture end
function ExtraActionButton1:GetPushedTexture() return self.PushedTexture end
ExtraActionButton1.width, ExtraActionButton1.height = 52, 52
ExtraActionButton1.HotKey = ExtraActionButton1:CreateFontString(nil, "ARTWORK", "NumberFontNormalGray")
ExtraActionButton1.Count = ExtraActionButton1:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
ExtraActionButton1.style = ExtraActionButton1:CreateTexture(nil, "OVERLAY")
for index, button in ipairs(StanceBar.actionButtons) do _G["StanceButton" .. index] = button end
for index, button in ipairs(PetActionBar.actionButtons) do _G["PetActionButton" .. index] = button end

-- What the game's action button template gives a button: its icon, its
-- cooldowns, its count, hotkey and macro name, its equipped border.
actionButtonTemplate = function(f)
    local function Art(atlas)
        local t = f:CreateTexture()
        t.alpha, t.atlas = 1, atlas
        return t
    end
    f.icon = Art()
    f.IconMask = Art("UI-HUD-ActionBar-IconFrame-Mask")
    f.icon.mask = f.IconMask
    f.SlotBackground = Art("UI-HUD-ActionBar-IconFrame-Background")
    f.SlotArt = Art("ui-hud-actionbar-iconframe-slot")
    f.NormalTexture = Art("UI-HUD-ActionBar-IconFrame")
    f.NormalTexture.width, f.NormalTexture.height = 46, 45
    f.PushedTexture = Art("UI-HUD-ActionBar-IconFrame-Down")
    f.HighlightTexture = Art("UI-HUD-ActionBar-IconFrame-Mouseover")
    f.CheckedTexture = Art("UI-HUD-ActionBar-IconFrame-Mouseover")
    function f:GetNormalTexture() return self.NormalTexture end
    function f:GetPushedTexture() return self.PushedTexture end
    function f:GetHighlightTexture() return self.HighlightTexture end
    function f:GetCheckedTexture() return self.CheckedTexture end
    f.cooldown = newWidget("Cooldown", f)
    f.lossOfControlCooldown = newWidget("Cooldown", f)
    f.chargeCooldown = newWidget("Cooldown", f)
    f.Count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    f.HotKey = f:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmallGray")
    f.Name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
    f.Border = f:CreateTexture()
    f.width, f.height = 45, 45
end

-- The game menu (Blizzard_GameMenu, loaded before any addon); tests/install.lua
-- gives it buttons.
GameMenuFrame = newWidget("Frame")
function GameMenuFrame:Layout() end

-- The .toc's own list, so the tests load exactly what the game loads.
local function TocFiles()
    local files = {}
    for line in (TOC_TEXT .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and not line:find("^#") then
            files[#files + 1] = (line:gsub("\\", "/"))
        end
    end
    return files
end

function LoadAddon()
    for _, file in ipairs(TocFiles()) do
        local chunk = assert(loadfile(ADDON_PATH .. "/" .. file))
        chunk("DogsForeverUI", {})
    end
end

-- An event, to every frame that registered for it. A unit event registered
-- for particular units reaches only those, as RegisterUnitEvent does in game.
function Fire(event, ...)
    local unit = ...
    for _, frame in ipairs(allFrames) do
        local wanted = frame.events[event]
        if wanted and frame.scripts.OnEvent then
            if wanted == true or (unit ~= nil and wanted[unit]) then
                frame.scripts.OnEvent(frame, event, ...)
            end
        end
    end
    RunUnitWatch()
end

-- A frame's worth of time, to every shown frame with an OnUpdate - which is
-- only the addon's own, and only while they are shown, as in game.
function Tick(seconds)
    seconds = seconds or 0.1
    now = now + seconds
    RunUnitWatch()
    for _, frame in ipairs(allFrames) do
        if frame.shown then
            if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, seconds) end
            for _, hook in ipairs(frame.hooks.OnUpdate or {}) do hook(frame, seconds) end    -- as the game's HookScript
        end
    end
end

-- The precise clock: the harness's time, a hundredth of a millisecond more each look.
local preciseLooks = 0
function GetTimePreciseSec()
    preciseLooks = preciseLooks + 1
    return now + preciseLooks * 1e-5
end

-- A new session: everything the last load made is forgotten, the saved file
-- is whatever the test says it is, and the addon is loaded again.
function Reload(saved)
    for index = #allFrames, 1, -1 do allFrames[index] = nil end
    -- The old addon's listeners went with it.
    EventRegistry.callbacks = {}
    DogsForeverUI = nil
    DogsForeverUIDB = saved
    if NewExtraAbilityContainer then NewExtraAbilityContainer() end
    LoadAddon()
end

-- The first events of every session, as the game sends them.
function Login()
    Fire("ADDON_LOADED", "DogsForeverUI")
    Fire("VARIABLES_LOADED")
    Fire("PLAYER_LOGIN")
    Fire("PLAYER_ENTERING_WORLD")
end

function Summary()
    print("")
    if checksFailed == 0 then
        print("ALL CHECKS PASSED (" .. checksRun .. ")")
    else
        print(checksFailed .. " CHECK(S) FAILED of " .. checksRun)
        error("tests failed")
    end
end

-- Whether a bar's background wears the old placing look - the options
-- window's colour - which no bar wears any more (one Edit Mode look).
function PlacingLook(texture)
    local c, w = texture and texture.colorTexture, DogsForeverUI.Style.WINDOW_BACKGROUND
    return c ~= nil and c[1] == w[1] and c[2] == w[2] and c[3] == w[3] and c[4] == w[4]
end

function Section(title)
    print("== " .. title .. " ==")
end

-- Frames pinned to UIParent by one point placed as the game would (the harness
-- keeps no layout otherwise): for following anchors. Answers the undo.
function PlaceByPoints()
    local base = Widget.SetPoint
    local function Share(point)
        return point:find("LEFT") and 0 or point:find("RIGHT") and 1 or 0.5,
            point:find("TOP") and 1 or point:find("BOTTOM") and 0 or 0.5
    end
    Widget.SetPoint = function(self, ...)
        base(self, ...)
        local p = self.points
        if p[2] == UIParent and self.width and self.height then
            local rx, ry = Share(p[3])
            local fx, fy = Share(p[1])
            self.left = rx * GetScreenWidth() + p[4] - fx * self.width
            self.bottom = ry * GetScreenHeight() + p[5] - fy * self.height
            self.top, self.right = self.bottom + self.height, nil
        end
    end
    return function() Widget.SetPoint = base end
end

-- THE CLIENT'S AURA CONTAINER FOR ADD-ONS (CustomAuraContainerTemplate). The
-- game fills it from the unit's auras itself; the harness records what the
-- addon asked of it, and makes one sample button per group through the
-- group's initializeFrame, as the game does before it locks buttons away.
do
    local plainCreateFrame = CreateFrame
    function CreateFrame(kind, name, parent, template)
        local f = plainCreateFrame(kind, name, parent, template)
        if template == "CustomAuraContainerTemplate" then
            f.auraGroups, f.auraGroupOrder, f.updates = {}, {}, 0
            f.auraSlots = {}
            function f:SetEditModePreviewEnabled(v) self.editModePreview = v end
            function f:SetUnit(unit) self.unit = unit end
            function f:SetEnabled(v) self.aurasEnabled = v end
            function f:UpdateAllAuras() self.updates = self.updates + 1 end
            function f:SetAuraProcessingPolicy(policy, opts) self.policy, self.policyOptions = policy, opts end
            local function Sample(container)
                local sample = newWidget("Frame", container)
                function sample:SetIcon(icon) self.iconRegion = icon end
                function sample:SetDurationCooldown(cd) self.cooldown = cd end
                function sample:SetApplicationCount(fs) self.count = fs end
                function sample:SetDurationText(fs, opts) self.durationText, self.durationTextOptions = fs, opts end
                function sample:SetDurationBar(bar, opts) self.durationBar, self.durationBarOptions = bar, opts end
                -- Played by the game each time it shows the frame for an aura, every one
                -- handed to it (the first as `shownAnimation`).
                function sample:AddAuraShownAnimation(group)
                    self.shownAnimation = self.shownAnimation or group
                    self.shownAnimations = self.shownAnimations or {}
                    table.insert(self.shownAnimations, group)
                end
                -- Every dispel-type texture and its options, the first as `dispel`.
                function sample:AddDispelTypeTexture(tex, opts)
                    self.dispel, self.dispelOptions = self.dispel or tex, self.dispelOptions or opts
                    self.dispels = self.dispels or {}
                    table.insert(self.dispels, { texture = tex, options = opts })
                end
                return sample
            end
            -- A slot: one frame the game shows for the first aura that passes.
            function f:AddAuraSlot(key, filter, options)
                local sample = Sample(self)
                options.initializeFrame(sample)
                self.auraSlots[key] = { filter = filter, options = options, sample = sample,
                                        candidateFilters = options.candidateFilters, enabled = true }
                return sample
            end
            function f:SetAuraSlotEnabled(key, enabled) self.auraSlots[key].enabled = enabled end
            function f:SetAuraSlotCandidateFilters(key, filters) self.auraSlots[key].candidateFilters = filters end
            function f:AddAuraGroup(key, filter, options)
                local sample = Sample(self)
                function sample:SetDurationBar(bar, opts) self.durationBar, self.durationBarOptions = bar, opts end
                -- A label the game runs refuses layout from addon code from then on
                -- (its text is secret): the call raises, as it does in game.
                local function GameOwned(fs)
                    -- Clearing its anchors goes through (as it did in game); laying
                    -- it out again does not.
                    for _, m in ipairs({ "SetPoint", "SetFont", "SetTextColor",
                                         "SetJustifyH", "SetWordWrap", "SetMaxLines",
                                         "SetNonSpaceWrap", "SetShadowOffset", "SetText" }) do
                        fs[m] = function() error("FontString:" .. m .. "(): the game owns this text", 2) end
                    end
                end
                function sample:SetDurationText(fs, opts)
                    self.durationText, self.durationTextOptions = fs, opts
                    GameOwned(fs)
                end
                function sample:SetSpellName(fs) self.spellName = fs; GameOwned(fs) end
                options.initializeFrame(sample)
                self.auraGroups[key] = { filter = filter, options = options,
                                         layout = options.layout, sample = sample,
                                         candidateFilters = options.candidateFilters }
                table.insert(self.auraGroupOrder, key)
            end
            function f:SetAuraGroupCandidateFilters(key, filters)
                self.auraGroups[key].candidateFilters = filters
            end
            function f:SetAuraGroupEnabled(key, enabled) self.auraGroups[key].enabled = enabled end
            function f:SetFlowLayoutAxis(axis) self.flowAxis = axis end
            function f:SetAuraGroupLayout(key, layout) self.auraGroups[key].layout = layout end
            function f:SetFlowLayoutAnchorPoint(point) self.flowPoint = point end
            function f:SetFlowLayoutGrowthDirection(h, v) self.flowH, self.flowV = h, v end
            function f:SetFlowLayoutMaximumLineSize(n) self.lineSize = n end
        end
        return f
    end
end
-- The aura container's sort enums (Blizzard_AuraContainerShared.lua).
AuraContainerSortMethod = { Default = 0, AuraInstanceIDOnly = 8 }
AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
AnchorUtil = AnchorUtil or {}
AnchorUtil.FlowDirection = { Left = 1, Right = 2, Up = 3, Down = 4 }
AnchorUtil.FlowLayoutAxis = { Horizontal = 0, Vertical = 1 }
-- Who is friendly: nobody, unless a test says so.
friendlyUnits = {}
function UnitIsFriend(_, unit) return friendlyUnits[unit] == true end
function UnitCanAttack(_, unit) return not friendlyUnits[unit] end
-- Hostile (red): a reaction under neutral's 4.
function UnitIsEnemy(_, unit)
    local u = Unit(unit)
    return u ~= nil and not friendlyUnits[unit] and (u.reaction or 4) < 4
end
-- A player, or a unit a player controls (a pet: `playerControlled = true`).
function UnitPlayerControlled(token)
    local u = Unit(token)
    return u ~= nil and (u.isPlayer or u.playerControlled) == true
end
-- Too far away to be seen: `farUnits[unit] = true`.
farUnits = {}
function UnitIsVisible(unit) return UnitExists(unit) and not farUnits[unit] end

-------------------------------------------------------------------------------
-- The pet's happiness face (Blizzard_FrameXML/PetHappiness.xml): a template
-- the addon makes one of on its pet plate. The game's mixin decides whether it
-- shows - a hunter's pet with a mood - which `petHappiness` stands in for.
-------------------------------------------------------------------------------

petHappiness = nil
do
    local plainCreateFrame = CreateFrame
    function CreateFrame(kind, name, parent, template)
        local f = plainCreateFrame(kind, name, parent, template)
        if template == "PetFrameHappinessTemplate" then
            f.mouseEnabled, f.updates = true, 0
            f:SetSize(24, 23)
            f.texture = f:CreateTexture(nil, "BACKGROUND")
            function f:UpdateHappiness()
                self.updates = self.updates + 1
                if petHappiness then self:Show() else self:Hide() end
            end
        end
        return f
    end
end

-------------------------------------------------------------------------------
-- The totems (Blizzard_UnitFrame/Mainline/TotemFrame.lua): the game's totem
-- frame, a child of its player frame, filling pooled buttons from the totem
-- slots - `totems[slot] = { icon = }` - and laying them out left to right, as
-- TotemFrameMixin:Update and the HorizontalLayoutFrame it inherits do. Every
-- button has TotemButtonTemplate's parts: the round ring, the icon under a
-- circle mask, the swipe, the time under the button.
-------------------------------------------------------------------------------

function Widget:SetSwipeTexture(v) self.swipeTexture = v end
function Widget:SetSwipeColor(r, g, b, a) self.swipeColor = { r, g, b, a } end
function Widget:SetTexCoordRange(low, high) self.texCoordRange = { low, high } end
atlases.NPE_ArrowDown = { width = 64, height = 128 }
atlases.CircleMask ={ width = 64, height = 64, file = "circle-mask-file",
    leftTexCoord = 0.1, rightTexCoord = 0.2, topTexCoord = 0.3, bottomTexCoord = 0.4 }

totems = {}
TotemFrame = newWidget("Frame", PlayerFrame)
TotemFrame.name = "TotemFrame"
TotemFrame.shown = false
TotemFrame.leftPadding, TotemFrame.spacing = 15, -6

local function TotemButton(frame, number)
    local b = newWidget("Button", frame)
    b.name = "TotemButton" .. number
    b:SetSize(37, 37)
    b.Border = newWidget("Texture", b)
    b.Border.atlas = "UI-HUD-UnitFrame-TotemFrame"
    b.Icon = newWidget("Frame", b)
    b.Icon:SetSize(22, 22)
    b.Icon.Texture = b.Icon:CreateTexture(nil, "BACKGROUND", nil, 2)
    b.Icon.TextureMask = b.Icon:CreateMaskTexture()
    b.Icon.Texture:AddMaskTexture(b.Icon.TextureMask)
    b.Icon.Cooldown = newWidget("Cooldown", b.Icon)
    local circle = atlases.CircleMask
    b.Icon.Cooldown:SetSwipeTexture(circle.file)
    b.Icon.Cooldown:SetTexCoordRange({ x = circle.leftTexCoord, y = circle.topTexCoord },
        { x = circle.rightTexCoord, y = circle.bottomTexCoord })
    b.Duration = b:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
    b.Duration:SetPoint("TOP", b, "BOTTOM", 0, 5)
    b.shown = false
    return b
end

do
    local pool = { active = {}, inactive = {}, made = 0 }
    function pool:Acquire()
        local b = table.remove(self.inactive)
        if not b then
            self.made = self.made + 1
            b = TotemButton(TotemFrame, self.made)
        end
        self.active[b] = true
        return b
    end
    -- The frame pool's resetter: hidden, anchors cleared.
    function pool:ReleaseAll()
        for b in pairs(self.active) do
            b:ClearAllPoints()
            b.shown = false
            table.insert(self.inactive, b)
        end
        self.active = {}
    end
    function pool:EnumerateActive() return pairs(self.active) end
    TotemFrame.totemPool = pool
end

TotemFrame.layouts = 0
function TotemFrame:Layout()
    self.layouts = self.layouts + 1
    local list = {}
    for b in self.totemPool:EnumerateActive() do
        if b.shown then list[#list + 1] = b end
    end
    table.sort(list, function(a, b) return a.layoutIndex < b.layoutIndex end)
    for i, b in ipairs(list) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self, "TOPLEFT", self.leftPadding + (i - 1) * (37 + self.spacing), 2)
    end
end

-- The game's own fill: a button per totem out, in slot order.
function TotemFrame:Update()
    self.totemPool:ReleaseAll()
    local active = 0
    for slot = 1, 4 do
        local totem = totems[slot]
        if totem then
            local b = self.totemPool:Acquire()
            b.layoutIndex, b.slot = slot, slot
            -- Whether the addon's look was on the button before the game
            -- filled it: anything changed after this point is changed on a
            -- button holding the game's (in combat, secret) totem data.
            local totemsModule = DogsForeverUI and DogsForeverUI.Frames
                and DogsForeverUI.Frames.Totems
            b.lookBeforeFill = totemsModule ~= nil and totemsModule.looks[b] ~= nil
            b.Icon.Texture:SetTexture(totem.icon)
            b.Icon.Cooldown:SetCooldown(now, 60)
            b.Duration:SetText("1m")
            b:Show()
            active = active + 1
        end
    end
    self:Layout()
    self:SetShown(active > 0)
end

-- Always there on this client; a test that needs other answers redefines them.
function UnitInRange() return true, true end
function UnitGroupRolesAssigned() return "NONE" end
function IsResting() return false end
C_ClassColor = { GetClassColor = function() end }
C_GameRules = { IsGameRuleActive = function() return false end }
Enum.GameRule = { UnitFramePvPContextualDisabled = 1 }
