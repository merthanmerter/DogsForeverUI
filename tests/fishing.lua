-- Fishing with the mouse: a double right-click in the world, with a fishing pole
-- in hand, casts Fishing through a secure button of the addon's own. A single
-- right-click, or any click without a pole, is left entirely to the game.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

LoadAddon()
Login()

local button = _G.DogsForeverUIFishingButton
local POLE, HAMMER = 6256, 2361

-- The right button pressed on the world, `gap` seconds after the last one. The
-- game turns mouse-look on as it goes down.
local function RightClick(gap)
    now = now + (gap or 1)
    mouselooking = true
    for _, hook in ipairs(WorldFrame.hooks.OnMouseDown or {}) do hook(WorldFrame, "RightButton") end
end
local function DoubleClick()
    RightClick(1)
    RightClick(0.2)
end
local function Armed() return overrideBindings.BUTTON2 ~= nil end
-- Letting go of the second click: the binding clicks the button, and the
-- button's own PostClick runs after the secure click.
local function Release()
    if button.scripts.PostClick then button.scripts.PostClick(button, "LeftButton", false) end
end

Section("the button that casts")
check("there is a secure action button to cast from", button ~= nil
    and button.template == "SecureActionButtonTemplate")
check("set to cast a spell", button:GetAttribute("type") == "spell")
check("on letting go, whatever the key-down setting",
    button:GetAttribute("useOnKeyDown") == false)
check("out of sight and out of the mouse's way", button.alpha == 0 and button.mouseEnabled == false)
check("and the world's clicks are followed, not replaced",
    WorldFrame.hooks.OnMouseDown and #WorldFrame.hooks.OnMouseDown == 1
    and WorldFrame.scripts.OnMouseDown == nil)
local db = DogsForeverUI.Fishing.db
check("both switches on by default, and no command",
    db.fishing == true and db.camping == true and next(SlashCmdList) == nil)

Section("with nothing in hand, the right mouse button is the game's")
equipped[INVSLOT_MAINHAND] = nil
DoubleClick()
check("no pole, a double right-click does nothing", not Armed())
equipped[INVSLOT_MAINHAND] = HAMMER
DoubleClick()
check("nor with a weapon", not Armed())

Section("with a pole, a double right-click casts Fishing")
equipped[INVSLOT_MAINHAND] = POLE
RightClick(1)
check("a single right-click is left alone: looting the bobber, turning the camera",
    not Armed() and mouselooking == true)
RightClick(0.2)
check("the second click of a double binds the right button to the cast",
    Armed() and overrideBindings.BUTTON2.button == "DogsForeverUIFishingButton")
check("which casts Fishing, by name", button:GetAttribute("spell") == "Fishing")
check("with mouse-look let go of, so the release reaches the binding and not the camera",
    mouselooking == false)
Release()
check("and letting go of it casts, and hands the right button straight back", not Armed())

RightClick(1)
RightClick(0.6)
check("two right-clicks too far apart are not a double", not Armed())

DoubleClick()
Release()
RightClick(0.2)
check("a third click right after a double does not start another", not Armed())

Section("when a cast cannot be meant")
local function Blocked(what, set, unset)
    set()
    DoubleClick()
    local armed = Armed()
    unset()
    Release()
    check("nothing is armed " .. what, not armed)
end
Blocked("in combat", function() inCombat = true end, function() inCombat = false end)
Blocked("while mounted", function() mounted = true end, function() mounted = false end)
Blocked("while swimming", function() swimming = true end, function() swimming = false end)
Blocked("with the mouse over someone",
    function() units.mouseover = { name = "Someone" } end, function() units.mouseover = nil end)
Blocked("with something on the cursor", function() cursorInfo = "item" end,
    function() cursorInfo = nil end)
Blocked("by a player who does not know Fishing", function() knowsFishing = false end,
    function() knowsFishing = true end)

Section("with a line out, every click is the bobber's")
-- The line is out: Fishing is being channelled.
local function LineOut() channelInfo = { "Fishing", "Fishing", "icon", 0, 30000, false, false } end
local function LineIn()
    channelInfo = nil
    Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
end

DoubleClick()
Fire("UNIT_SPELLCAST_CHANNEL_START", "player")
LineOut()
check("casting takes the binding off", not Armed())
DoubleClick()
check("a double-click on the bobber is never a new cast", not Armed())

-- The first click catches (the line comes in), the second lands right after.
RightClick(1)
LineIn()
RightClick(0.2)
check("nor is a double-click whose first click was the catch", not Armed())

LootFrame = CreateFrame("Frame", "LootFrame", UIParent)
DoubleClick()
check("nor anything while the loot window is open", not Armed())
LootFrame:Hide()
DoubleClick()
Release()
check("and with the loot put away, a double-click casts again", button:GetAttribute("spell")
    == "Fishing" and not Armed())

channelInfo = { Unreadable("a channelled spell"), nil, nil, 0, 0, false, false }
DoubleClick()
check("a channel the client will not describe counts as busy", not Armed())
channelInfo = nil

Section("a binding left armed never outstays its welcome")
DoubleClick()
check("armed", Armed())
RightClick(1)
check("one not let go of by its own click comes off at the very next right-click",
    not Armed())

DoubleClick()
Fire("PLAYER_REGEN_DISABLED")
check("combat starting takes it off on the way in", not Armed())

DoubleClick()
Tick(0.3)
check("unused, it stays a moment", Armed())
Tick(0.3)
check("then comes off by itself", not Armed())

Section("switched off under Extras, a pole does nothing")
db.fishing = false
DoubleClick()
check("no cast with double-click fishing off", not Armed())
db.fishing = true

equipped[INVSLOT_MAINHAND] = nil

Section("a double right-click on a Basic Campfire sits down")
local function Over(kind, name)
    worldCursor = kind and { type = Enum.TooltipDataType[kind], lines = { { leftText = name } } } or nil
    Fire("WORLD_CURSOR_TOOLTIP_UPDATE", 0)
end

Over("Object", "Basic Campfire")
RightClick(1)
check("a single right-click on the fire is left alone", not Armed())
RightClick(0.2)
check("the second click binds the right button to sitting",
    Armed() and button:GetAttribute("type") == "macro"
    and button:GetAttribute("macrotext") == "/sit")
Release()
check("letting go sits, and the right button is the game's again", not Armed())

-- Mouse-look hides the world cursor between the two clicks.
RightClick(1)
mouselooking = true
Over(nil)
RightClick(0.2)
check("the fire is remembered while mouse-look hides it", Armed()
    and button:GetAttribute("macrotext") == "/sit")
Release()

mouselooking = false
Over(nil)
DoubleClick()
check("moved off the fire, a double-click does nothing", not Armed())

Over("Object", "Mailbox")
DoubleClick()
check("nor on another object", not Armed())

Over("Unit", "Basic Campfire")
DoubleClick()
check("nor on someone who shares the name", not Armed())

Over("Object", "Basic Campfire")
equipped[INVSLOT_MAINHAND] = POLE
DoubleClick()
check("with a pole in hand, the fire under the mouse wins",
    Armed() and button:GetAttribute("type") == "macro")
Release()
Over(nil)
DoubleClick()
check("and off the fire, the pole fishes again", Armed()
    and button:GetAttribute("type") == "spell" and button:GetAttribute("spell") == "Fishing"
    and button:GetAttribute("macrotext") == nil)
Release()
equipped[INVSLOT_MAINHAND] = nil

Over("Object", "Basic Campfire")
inCombat = true
DoubleClick()
inCombat = false
check("not in combat", not Armed())
Release()

db.camping = false
DoubleClick()
check("switched off under Extras, the fire does nothing", not Armed())
db.camping = true

Over("Object", Unreadable("an object's name"))
DoubleClick()
check("a name the client will not describe is never taken for the fire", not Armed())
Over(nil)

Section("on retail (its pole always in its slot) only the campfire")
check("offered on Forever", DogsForeverUI.Fishing.FISHING_OFFERED == true)
DogsForeverUI.Fishing.FISHING_OFFERED = false
equipped[INVSLOT_MAINHAND] = POLE
DoubleClick()
check("no fishing where it is not offered", not Armed())
Over("Object", "Basic Campfire")
DoubleClick()
check("the fire still sits down", Armed() and button:GetAttribute("macrotext") == "/sit")
Release()
Over(nil)
equipped[INVSLOT_MAINHAND] = nil
DogsForeverUI.Fishing.FISHING_OFFERED = true

Summary()
