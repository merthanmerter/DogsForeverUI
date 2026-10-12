-- The first start's question and the game menu's button (Options\Panel.lua),
-- and the game's Quick Keybind Mode brought to the addon's (Options\Keybinds.lua).
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

-- The game's menu: a layout frame with a pool of buttons (MainMenuFrameTemplates.lua).
GAMEMENU_OPTIONS, BLIZZARD_STORE = "Options", "Shop"
local menuButtons = {}
GameMenuFrame = newWidget("Frame")
local function MenuButton(text, top)
    local button = newWidget("Button", GameMenuFrame)
    button.text, button.top, button.bottom = text, top, top - 35
    button:SetPoint("TOP", GameMenuFrame, "TOP", 0, -(1000 - top))
    menuButtons[#menuButtons + 1] = button
    return button
end
GameMenuFrame.height = 300
GameMenuFrame.buttonPool = { EnumerateActive = function()
    local index = 0
    return function() index = index + 1; return menuButtons[index] end
end }
function GameMenuFrame:Layout() self.height = 300 end
MenuButton("Options", 900)
MenuButton("Shop", 865)
MenuButton("Addons", 810)
MenuButton("Log Out", 740)

-- The game's Quick Keybind Mode window.
QuickKeybindFrame = newWidget("Frame")
for _, key in ipairs({ "OkayButton", "CancelButton", "DefaultsButton", "UseCharacterBindingsButton" }) do
    QuickKeybindFrame[key] = newWidget("Button", QuickKeybindFrame)
end
QuickKeybindFrame.shown = false

LoadAddon()
Login()

local Core = DogsForeverUI
local Options = Core.Options
local GD = Core.GameDefaults
local function Click(button, ...) button.scripts.OnClick(button, ...) end

Section("the first start's question")
do
    local Install = Options.Install
    check("not answered yet", GD.db.installed == false)
    Tick(2.1)
    Tick(1.1)
    local window = Install.window
    check("asked once the settings are in: Install or Disable Addon, no Cancel", window ~= nil and window:IsShown()
        and window.install.label.text == "Install" and window.disable.label.text == "Disable Addon"
        and window.cancel == nil)
    Core.Castbar.db.barWidth = 222
    local reloads = ReloadCount
    local disabled
    C_AddOns = C_AddOns or {}
    C_AddOns.DisableAddOn = function(name, character) disabled = { name, character } end
    Click(window.disable)
    check("Disable Addon: off for this character, the UI reloaded, nothing else changed",
        disabled ~= nil and disabled[1] == Core.ADDON_NAME and disabled[2] == UnitName("player")
        and ReloadCount == reloads + 1 and Core.Castbar.db.barWidth == 222)
    check("not answered: turned on again, it asks again", GD.db.installed == false)

    check("asked again for a character that has not answered", Install.Ask() and window:IsShown())
    Click(window.install)
    check("Install: every setting back to its default", Core.Castbar.db.barWidth == Core.Castbar.defaults.barWidth)
    check("answered (kept through the reset), the game's settings to be set again, the UI reloaded",
        GD.db.installed == true and GD.db.done == 0 and ReloadCount == reloads + 2)
    Fire("PLAYER_ENTERING_WORLD")
    Tick(1.1)
    check("not asked again on the next load", not window:IsShown())
    Core:ResetAll()
    check("Reset everything keeps the answer", GD.db.installed == true)
end

Section("the game's own settings: the second step")
do
    check("friendly players' plates, auto loot, combined bags, interact key on; the Cooldown Manager off; camera never adjusted, at the farthest",
        C_CVar.GetCVar("nameplateShowFriendlyPlayers") == "1" and C_CVar.GetCVar("autoLootDefault") == "1"
        and C_CVar.GetCVar("combinedBags") == "1" and C_CVar.GetCVar("cooldownViewerEnabled") == "0"
        and C_CVar.GetCVar("cameraSmoothStyle") == "0")
    check("every step done", GD.db.done == #GD.STEPS and #GD.STEPS == 3)
    check("a number read back as a number", GD.Same("2.000000", "2") and not GD.Same("1", "2"))
end

Section("the game menu's button")
do
    GameMenuFrame:Layout()
    local GameMenu = Options.GameMenu
    local button = GameMenu.button
    check("under the Shop, the game's template, the addon's name",
        button ~= nil and button.template == "MainMenuFrameButtonTemplate" and button.text == GameMenu.LABEL
        and button.points[1] == "TOP" and button.points[2] == menuButtons[2] and button:IsShown())
    check("the game's buttons under it moved down, the menu made taller",
        menuButtons[3].points[5] == -(1000 - 810) - GameMenu.ROOM and menuButtons[4].points[5] == -(1000 - 740) - GameMenu.ROOM
        and menuButtons[1].points[5] == -(1000 - 900) and GameMenuFrame.height == 300 + GameMenu.ROOM)
    local copies = GameMenu.lifts[button]
    check("its art a light gold: each piece's copy added over it (it was too dark to see)",
        copies ~= nil and copies.Center ~= nil and copies.Center.blendMode == "ADD"
        and copies.Center.allPointsTo == button.Center)
    local glow = button:GetHighlightTexture()
    check("its hover glow greyed and the same light gold, not the game's red",
        glow ~= nil and glow.desaturated == true and glow.vertexColor and glow.vertexColor[1] == GameMenu.LIGHT[1]
        and glow.vertexColor[3] == GameMenu.LIGHT[3])
    GameMenuFrame.shown = true
    Click(button)
    check("a click: the menu shut, the options open", GameMenuFrame.shown == false and Options.IsShown())
    Options.Close()
    Tick(1)

    inCombat = true
    GameMenuFrame:Layout()
    check("in combat: still there, under the Shop", button:IsShown() and button.points[2] == menuButtons[2])
    GameMenuFrame.shown = true
    Click(button)
    check("and a click still opens the options", GameMenuFrame.shown == false and Options.IsShown())
    Options.Close()
    inCombat = false
end

Section("the game's Quick Keybind Mode: the addon's instead")
do
    local Keybinds = Options.Keybinds
    QuickKeybindFrame:Show()
    local window = Keybinds.window
    check("the game's window out of sight and deaf, the addon's there",
        Keybinds.IsOpen() and Keybinds.mode == "game" and QuickKeybindFrame.alpha == 0
        and QuickKeybindFrame.mouseEnabled == false and QuickKeybindFrame.OkayButton.mouseEnabled == false
        and window:IsShown())
    check("the addon's window takes no keyboard: Escape reaches the game's", window.keyboardEnabled == false)
    local okay, cancel = window.gameOkay, window.gameCancel
    check("its Okay and Cancel secure buttons clicking the game's own",
        okay.template == "SecureActionButtonTemplate" and okay:GetAttribute("type") == "click"
        and okay:GetAttribute("clickbutton") == QuickKeybindFrame.OkayButton
        and cancel:GetAttribute("clickbutton") == QuickKeybindFrame.CancelButton and okay:IsShown())
    check("every button there to point at (empty slots, auto-hidden bars)", Core.ActionBars.keybinding == true)
    check("the secure Okay and Cancel a strata above the window: the window never comes up over them",
        okay.strata == Keybinds.SECURE_STRATA and cancel.strata == Keybinds.SECURE_STRATA
        and okay.strata ~= window.strata and okay.allPointsTo == window.okay and cancel.allPointsTo == window.cancel)

    -- A key bound here: saved at once (the game's Cancel loads the saved
    -- keys), put back by Cancel.
    local function Saved(key)
        for _, each in ipairs(savedBindings[GetCurrentBindingSet()] or {}) do
            if each[1] == key then return each[2] end
        end
        return ""
    end
    local one = _G.DogsForeverUIActionButton1
    mouseOver = { [one] = true }
    Keybinds.Drive()
    Keybinds.capture.scripts.OnKeyDown(Keybinds.capture, "K")
    check("a key bound, and saved at once", GetBindingAction("K") == "ACTIONBUTTON1" and Saved("K") == "ACTIONBUTTON1")
    cancel.scripts.PreClick(cancel, "LeftButton")
    check("the secure Cancel's own part: the key put back and saved, before the game's Cancel loads them",
        GetBindingAction("K") == "" and Saved("K") == "")
    Keybinds.capture.scripts.OnKeyDown(Keybinds.capture, "K")
    okay.scripts.PreClick(okay, "LeftButton")
    QuickKeybindFrame:Hide()
    for _, hook in ipairs(QuickKeybindFrame.hooks.OnHide or {}) do hook(QuickKeybindFrame) end
    check("left by its Okay: kept", GetBindingAction("K") == "ACTIONBUTTON1" and Saved("K") == "ACTIONBUTTON1")

    -- Again, and left by Escape (the game's window takes it): put back.
    QuickKeybindFrame:Show()
    for _, hook in ipairs(QuickKeybindFrame.hooks.OnShow or {}) do hook(QuickKeybindFrame) end
    mouseOver = { [one] = true }
    Keybinds.Drive()
    Keybinds.capture.scripts.OnKeyDown(Keybinds.capture, "L")
    mouseOver = {}
    Keybinds.Drive()
    QuickKeybindFrame:Hide()
    for _, hook in ipairs(QuickKeybindFrame.hooks.OnHide or {}) do hook(QuickKeybindFrame) end
    check("left any other way (Escape, the game's Cancel): what it bound put back, and saved",
        GetBindingAction("L") == "" and Saved("L") == "" and GetBindingAction("K") == "ACTIONBUTTON1")

    QuickKeybindFrame:Show()
    for _, hook in ipairs(QuickKeybindFrame.hooks.OnShow or {}) do hook(QuickKeybindFrame) end
    QuickKeybindFrame:Hide()
    -- (The harness's Hide runs no OnHide; the game's does.)
    for _, hook in ipairs(QuickKeybindFrame.hooks.OnHide or {}) do hook(QuickKeybindFrame) end
    check("the game's window shut: the addon's with it, the game's back as it was",
        not Keybinds.IsOpen() and not window:IsShown() and QuickKeybindFrame.alpha == 1
        and QuickKeybindFrame.mouseEnabled == true and not okay:IsShown() and Core.ActionBars.keybinding == false,
        table.concat({ tostring(Keybinds.IsOpen()), tostring(window:IsShown()), tostring(QuickKeybindFrame.alpha), tostring(QuickKeybindFrame.mouseEnabled), tostring(okay:IsShown()), tostring(Core.ActionBars.keybinding) }, ","))
end

check("nothing forbidden called", #forbiddenCalls == 0)
Summary()
