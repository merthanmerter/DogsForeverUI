-- Quick Keybind Mode (Options\Keybinds.lua), from the options window's
-- header: the addon's own capture over the button pointed at, a key
-- replacing its first key, the mouse wheel an extra key (a click of the
-- button, where the game will not take the wheel on the command), Escape
-- taking the first key off as the game's does; every change saved at once
-- (a quit keeps it), Cancel putting back exactly what the mode changed. And a
-- key pressed showing on the addon's button (ActionBars\ActionBars.lua).
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

-- The game's key handlers for its bars (Blizzard_ActionBar), and the keys
-- held down.
keysDown = {}
function IsKeyDown(key) return keysDown[key] == true end
gameDowns = {}
function ActionButtonDown(id) gameDowns[#gameDowns + 1] = id end
function MultiActionButtonDown(bar, id) gameDowns[#gameDowns + 1] = bar .. id end

LoadAddon()
Login()

local Core = DogsForeverUI
local Options = Core.Options
local Unlock = Options.Unlock
local Keybinds = Options.Keybinds
local Bars = Core.ActionBars

local one = _G.DogsForeverUIActionButton1
local two = _G.DogsForeverUIActionButton2

local function Point(button)
    mouseOver = { [button] = true }
    Keybinds.Drive()
end

local function Press(key)
    local capture = Keybinds.capture
    capture.scripts.OnKeyDown(capture, key)
end

local function Wheel(delta)
    local capture = Keybinds.capture
    capture.scripts.OnMouseWheel(capture, delta)
end

local function Click(button, ...) button.scripts.OnClick(button, ...) end

local function Keys(command) return table.concat({ GetBindingKey(command) }, ",") end

-- What the game's own saved file says `key` is bound to.
local function Saved(key)
    for _, each in ipairs(savedBindings[GetCurrentBindingSet()] or {}) do
        if each[1] == key then return each[2] end
    end
    return ""
end

Section("opened from the options window, beside Unlock UI")
do
    bindings.ACTIONBUTTON1 = "1"
    bindings.ACTIONBUTTON2 = "2"
    SaveBindings(GetCurrentBindingSet())
    Core.SetUnlocked(true)
    Tick(0.02)
    check("no longer on Unlock Mode's bar", Unlock.bar.keybinds == nil)
    Core.SetUnlocked(false)

    Options.Open()
    local header = Options.window.keybindsButton
    check("a Quick Keybinds button left of Unlock UI", header ~= nil and header.label.text == "Quick Keybinds"
        and header.points[1] == "RIGHT" and header.points[2] == Options.window.unlockButton)
    Click(header)
    local window = Keybinds.window
    check("the options make way, the window at the top of the screen",
        Keybinds.IsOpen() and Keybinds.mode == "own" and not Options.IsShown() and window:IsShown()
        and window.points[1] == "TOP" and window.points[2] == UIParent)
    check("titled as the game's", window.title.text == "Quick Keybind Mode")
    check("Okay and Cancel", window.okay.label.text == "Okay" and window.cancel.label.text == "Cancel")
    check("every button there to point at", Bars.keybinding == true)
end

Section("pointing at a button")
do
    Point(one)
    local capture = Keybinds.capture
    check("the capture over it, taking keys, mouse buttons and the wheel",
        capture:IsShown() and capture.allPointsTo == one and capture.keyboardEnabled == true
        and capture.strata == "TOOLTIP")
    check("its tooltip: its name and its key", GameTooltip.owner == capture
        and GameTooltip:GetLines():find("Name of ACTIONBUTTON1", 1, true) ~= nil
        and GameTooltip:GetLines():find("1", 1, true) ~= nil)
    mouseOver = {}
    Keybinds.Drive()
    check("pointing at nothing: the capture gone", not capture:IsShown())
end

Section("a key, kept at once")
do
    Point(one)
    Press("Q")
    check("replaces its key", Keys("ACTIONBUTTON1") == "Q")
    check("saved into the game's own file at once", Saved("Q") == "ACTIONBUTTON1" and Saved("1") == "")
    LoadBindings(GetCurrentBindingSet())
    check("so a quit or a reload now keeps it", Keys("ACTIONBUTTON1") == "Q")
    Press("LSHIFT")
    check("a modifier alone binds nothing", Keys("ACTIONBUTTON1") == "Q")
    shiftDown = true
    Press("E")
    shiftDown = false
    check("held modifiers bind with it", Keys("ACTIONBUTTON1") == "SHIFT-E")
    Keybinds.capture.scripts.OnMouseDown(Keybinds.capture, "MiddleButton")
    check("a mouse button binds", Keys("ACTIONBUTTON1") == "BUTTON3")
    Keybinds.capture.scripts.OnMouseDown(Keybinds.capture, "LeftButton")
    check("but never the left or right", Keys("ACTIONBUTTON1") == "BUTTON3")
    Point(two)
    Press("BUTTON3")
    check("a key taken from another button: moved, and said",
        Keys("ACTIONBUTTON2") == "BUTTON3" and Keys("ACTIONBUTTON1") == ""
        and Keybinds.window.output.text:find("taken from", 1, true) ~= nil)
end

Section("the mouse wheel, an extra key")
do
    Point(one)
    Press("1")
    Wheel(1)
    check("the button's key kept", Keys("ACTIONBUTTON1") == "1")
    check("the wheel clicks the button itself: the game takes no wheel on an action button's command",
        GetBindingAction("MOUSEWHEELUP") == "CLICK DogsForeverUIActionButton1:Keybind"
        and Saved("MOUSEWHEELUP") == "CLICK DogsForeverUIActionButton1:Keybind")
    Fire("UPDATE_BINDINGS")
    Tick(0)
    check("its hotkey still its key", one.HotKey.text == "1")
    ctrlDown = true
    Wheel(-1)
    ctrlDown = false
    check("down, with a modifier, as well", GetBindingAction("CTRL-MOUSEWHEELDOWN")
        == "CLICK DogsForeverUIActionButton1:Keybind")
    check("listed in its tooltip", GameTooltip:GetLines():find("MOUSEWHEELUP", 1, true) ~= nil)
    Point(two)
    Press("ESCAPE")
    Wheel(1)
    Fire("UPDATE_BINDINGS")
    Tick(0)
    check("moved to another button; a wheel alone written short", GetBindingAction("MOUSEWHEELUP")
        == "CLICK DogsForeverUIActionButton2:Keybind" and two.HotKey.text == "WU")
    local snippet = _G.DogsForeverUIActionBar1.wrapped[one].OnClick
    check("a wheel's click acts as it is pressed (a key), a mouse click as it is let go",
        snippet:find('button == "Keybind"', 1, true) ~= nil and snippet:find("useOnKeyDown", 1, true) ~= nil)
end

Section("Escape unbinds the first key, as the game's does")
do
    Point(one)
    Press("ESCAPE")
    check("its first key off, the wheel kept", Keys("ACTIONBUTTON1") == ""
        and Keys("CLICK DogsForeverUIActionButton1:Keybind") ~= "")
    Press("ESCAPE")
    check("no key left: its wheels next", Keys("CLICK DogsForeverUIActionButton1:Keybind") == "")
    SetBinding("F", "ACTIONBUTTON1")
    SetBinding("G", "ACTIONBUTTON1")
    Press("ESCAPE")
    check("two keys: the first off, the second its first now", Keys("ACTIONBUTTON1") == "G")
    check("and the mode still open", Keybinds.IsOpen())
end

Section("Okay and Cancel")
do
    Point(one)
    Press("Z")
    Click(Keybinds.window.okay)
    check("Okay: kept, the window gone, the options back", not Keybinds.IsOpen()
        and GetBindingAction("Z") == "ACTIONBUTTON1" and Saved("Z") == "ACTIONBUTTON1"
        and not Keybinds.window:IsShown() and not Keybinds.capture:IsShown() and Options.IsShown()
        and Bars.keybinding == false)

    Click(Options.window.keybindsButton)
    Point(one)
    Press("X")
    check("saved at once", Saved("X") == "ACTIONBUTTON1")
    Click(Keybinds.window.cancel)
    check("Cancel: exactly what the mode changed put back, and saved",
        GetBindingAction("X") == "" and Saved("X") == "" and GetBindingAction("Z") == "ACTIONBUTTON1"
        and Saved("Z") == "ACTIONBUTTON1" and not Keybinds.IsOpen())

    Click(Options.window.keybindsButton)
    Point(two)
    Press("Z")
    check("a key moved from another button", Keys("ACTIONBUTTON2") == "Z" and Keys("ACTIONBUTTON1") == "")
    mouseOver = {}
    Keybinds.Drive()
    local window = Keybinds.window
    window.scripts.OnKeyDown(window, "ESCAPE")
    check("Esc pointing at nothing: as Cancel - the key back on its first button",
        not Keybinds.IsOpen() and GetBindingAction("Z") == "ACTIONBUTTON1" and Saved("Z") == "ACTIONBUTTON1"
        and Keys("ACTIONBUTTON2") == "", Keys("ACTIONBUTTON1") .. " / " .. Keys("ACTIONBUTTON2"))

    Click(Options.window.keybindsButton)
    Point(one)
    Press("V")
    Fire("PLAYER_REGEN_DISABLED")
    check("a fight: left, its keys kept", not Keybinds.IsOpen() and GetBindingAction("V") == "ACTIONBUTTON1")
    Fire("PLAYER_REGEN_ENABLED")
    check("and saved", Saved("V") == "ACTIONBUTTON1")
    Options.Close()
end

Section("Unlock Mode open: left first")
do
    Core.SetUnlocked(true)
    check("opened from Unlock Mode", Keybinds.Open() == false and not Core.IsUnlocked() and Keybinds.IsOpen())
    Core.SetUnlocked(true)
    Keybinds.Drive()
    check("Unlock Mode opened meanwhile: the mode left, its keys kept", not Keybinds.IsOpen())
    Core.SetUnlocked(false)
end

Section("the stance bar")
do
    Keybinds.Open()
    local stance = Bars.buttons.stance[1]
    stance.shown = true
    if stance then
        Point(stance)
        Wheel(1)
        check("the wheel on its command, where the game takes it", GetBindingAction("MOUSEWHEELUP") == "SHAPESHIFTBUTTON1")
    end
    Click(Keybinds.window.cancel)
    check("Cancel: the wheel back on the button it clicked before",
        GetBindingAction("MOUSEWHEELUP") == "CLICK DogsForeverUIActionButton2:Keybind")
end

Section("a key pressed, seen on the button")
do
    local pushed = one:GetPushedTexture()
    one.shown = true
    pushed.shown = false
    keysDown.V = true
    ActionButtonDown(1)
    check("the game's own handler still runs", gameDowns[#gameDowns] == 1)
    check("bar 1's button shows its pressed look", pushed.shown == true)
    Tick(0.2)
    check("held: still pressed", pushed.shown == true)
    keysDown.V = nil
    Tick(0.05)
    check("let go: back", pushed.shown == false)
    local bar2 = Bars.buttons.bar2[3]
    bar2.shown = true
    local pushed2 = bar2:GetPushedTexture()
    MultiActionButtonDown("MultiBarBottomLeft", 3)
    check("another bar's button, by the game's bar it stands in for", pushed2.shown == true)
    Tick(0.2)
    check("a quick tap still shows a moment, then goes", pushed2.shown == false)
    for _, hook in ipairs(one.hooks.PreClick or {}) do hook(one, "Keybind") end
    check("a wheel clicking it: a short flash", pushed.shown == true)
    Tick(0.2)
    check("then gone", pushed.shown == false)
end

check("nothing forbidden called", #forbiddenCalls == 0)
Summary()
