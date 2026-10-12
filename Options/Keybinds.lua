-- QUICK KEYBIND MODE (the player, 2026-10-03: "a QuickKeybinding Mode
-- similar to blizz default ... Also I should be able to assign mouse scrolls
-- as an extra"). Opened from the options window's header, beside Unlock UI
-- (the player, 2026-10-03: "add quick keybind button directly to main menu
-- next to unlock ui"; it left Unlock Mode's bar) - and in place of the
-- game's own whenever the game opens its own (below).
--
-- As the game's: every button of the addon's bars is lit, and a key pressed
-- while pointing at one binds it there; Escape over a button unbinds; Okay
-- keeps, Cancel (or Escape pointing at nothing) puts every key back.
--
-- But the game's own mode is never run from here: opened by the addon, its
-- whole input path would be tainted (EllesmereUI found keys it passes on -
-- Print Screen's screenshot - then refused as forbidden). EllesmereUI's own
-- way instead (Ellesmere\EllesmereUIActionBars, its macro capture): a plain
-- frame of the addon's, laid over the button pointed at, takes the key, the
-- mouse button or the wheel before anything of the game's sees it, and the
-- binding is set from the addon's code - SetBinding, out of combat, as the
-- game's own listener does (Blizzard_Keybindings.lua, ProcessInput).
--
--   * A KEY (or a mouse button but the left and right) becomes the button's
--     first key, as the game's mode makes it; its other keys stay. A key
--     taken from something else says so.
--   * THE WHEEL is AN EXTRA key: the button's own keys stay. The game will
--     not bind the wheel to an action button's command (it runs on the key's
--     down and up), so the wheel clicks the button itself (Paint.lua,
--     AB.ClickOf).
--   * ESCAPE takes the button's first key off, as the game's does (its next
--     key becomes the first); with no key left, its wheels.
--
-- KEPT AT ONCE (the player, 2026-10-03: "they should work properly in
-- harmony with blizzard default binding structure, dont reset when quit"):
-- every change is saved into the game's binding set in use the moment it is
-- made (SaveBindings - the game's own file, the character's or the
-- account's, as the game has it), so a quit, a /reload or a crash keeps it.
-- What each key was bound to before the mode first changed it is kept, and
-- Cancel (Escape pointing at nothing, the game's Cancel) puts exactly those
-- keys back and saves again. Reset to Default is the game's: every key the
-- game's default, saved at once, nothing to put back.

local Keybinds = {}
DogsForeverUI.Options.Keybinds = Keybinds

do -- private scope
    local Core = DogsForeverUI
    local Unlock = Core.Options.Unlock
    local Style = Core.Style
    local W = Core.Widgets
    local AB = Core.ActionBars

    local WIDTH, SIDE = 460, 16
    local LIT = { Style.GOLD[1], Style.GOLD[2], Style.GOLD[3], 0.14 }
    local POINTED = { Style.GOLD[1], Style.GOLD[2], Style.GOLD[3], 0.32 }
    local ERROR = { 1, 0.35, 0.35, 1 }
    -- The secure Okay and Cancel over the window's (the game's mode): a
    -- strata above the window's own, so the window - a toplevel frame,
    -- raised as it is clicked - can never come up over them (it did: the
    -- clicks went to the window's plain buttons, which do nothing in the
    -- game's mode - the player, 2026-10-03: "buttons not working in the
    -- binding mode dialog").
    Keybinds.SECURE_STRATA = "FULLSCREEN_DIALOG"

    local window, capture, driver
    local lit = {}          -- button -> its light
    local pointed           -- the button under the mouse
    local open = false
    local fromOptions = false
    local saveAfterCombat = false
    local okayed = false    -- the game's mode: left by its Okay (not Cancel, not Escape)

    function Keybinds.IsOpen() return open end

    ---------------------------------------------------------------------------
    -- THE BUTTONS: the addon's action buttons, then the stance and pet bars'.
    ---------------------------------------------------------------------------

    local SMALL_BARS = { "stance", "pet" }

    local function EachButton(fn)
        for _, button in ipairs(AB.all or {}) do fn(button) end
        for _, key in ipairs(SMALL_BARS) do
            for _, button in ipairs(AB.buttons and AB.buttons[key] or {}) do fn(button) end
        end
    end

    local function Bindable(button)
        return AB.commands[button] ~= nil and button:IsVisible()
            and (button:GetEffectiveAlpha() or 1) > 0
    end

    local function NameOf(action)
        if type(action) ~= "string" or action == "" then return end
        -- A wheel on one of the bars' buttons: that button's name.
        local frame = action:match("^CLICK ([^:]+):")
        if frame and _G[frame] and AB.commands[_G[frame]] then action = AB.commands[_G[frame]] end
        local name = GetBindingName and GetBindingName(action)
        return name and name ~= "" and name or action
    end

    local function KeyName(key)
        return GetBindingText and GetBindingText(key) or key
    end

    ---------------------------------------------------------------------------
    -- WHAT THE WINDOW SAYS, and the tooltip on the button pointed at.
    ---------------------------------------------------------------------------

    local function Say(text, colour)
        if not window then return end
        window.output:SetText(text or "")
        W.SetTextColour(window.output, colour or W.TEXT)
    end

    local function ShowTooltip(button)
        local tip = GameTooltip
        if not tip then return end
        tip:SetOwner(capture, "ANCHOR_RIGHT")
        tip:AddLine(NameOf(AB.commands[button]) or "", 1, 1, 1)
        local keys = AB.KeysOf(button)
        if #keys > 0 then
            local names = {}
            for index, key in ipairs(keys) do names[index] = KeyName(key) end
            tip:AddLine(table.concat(names, ", "), 0.1, 1, 0.1)
            tip:AddLine(_G.ESCAPE_TO_UNBIND or "Press Escape to unbind", 1, 0.82, 0)
        else
            tip:AddLine(_G.NOT_BOUND or "Not Bound", 1, 0.25, 0.25)
            tip:AddLine(_G.PRESS_KEY_TO_BIND or "Press a key to bind", 1, 0.82, 0)
        end
        tip:Show()
    end

    ---------------------------------------------------------------------------
    -- KEPT AT ONCE, AND PUT BACK: every key changed goes through Set /
    -- SetClick, which first note what it was bound to (once, the first time).
    ---------------------------------------------------------------------------

    local before = {}       -- "context|key" -> { key, action, context } before the mode changed it

    local function Remember(key, context)
        local id = tostring(context or "") .. "|" .. key
        if before[id] then return end
        local action = GetBindingAction(key, nil, context)
        before[id] = { key = key, action = action or "", context = context }
    end

    local function Set(key, command, context)
        Remember(key, context)
        return SetBinding(key, command, context)
    end

    local function SetClick(key, name, mouse)
        Remember(key, nil)
        return SetBindingClick(key, name, mouse)
    end

    local function Forget()
        for id in pairs(before) do before[id] = nil end
    end

    -- Saved into the game's binding set in use (after the fight, in one).
    local function Save()
        if not SaveBindings or not GetCurrentBindingSet then return end
        if InCombatLockdown() then
            saveAfterCombat = true
            return
        end
        saveAfterCombat = false
        SaveBindings(GetCurrentBindingSet())
    end

    -- Every key the mode changed back as it was, and saved.
    local function PutBack()
        for _, entry in pairs(before) do
            local action = entry.action
            if action == "" then
                SetBinding(entry.key, nil, entry.context)
            else
                local frame, mouse = action:match("^CLICK (.+):([^:]+)$")
                if frame then
                    SetBindingClick(entry.key, frame, mouse)
                else
                    SetBinding(entry.key, action, entry.context)
                end
            end
        end
        local any = next(before) ~= nil
        Forget()
        if any then Save() end
        if AB.Mark then AB.Mark("hotkeys") end
    end

    ---------------------------------------------------------------------------
    -- BINDING (the game's listener's steps, Blizzard_Keybindings.lua).
    ---------------------------------------------------------------------------

    local function ContextOf(command)
        return C_KeyBindings and C_KeyBindings.GetBindingContextForAction
            and C_KeyBindings.GetBindingContextForAction(command)
    end

    -- Escape: the button's first key off, as the game's ClearActionPrimaryBinding
    -- (its second key bound again, so it is the first now); with no key on
    -- its command, its wheels.
    local function Unbind(button)
        local command = AB.commands[button]
        local context = ContextOf(command)
        local key1, key2 = GetBindingKey(command, nil, context)
        if key1 then
            Set(key1, nil, context)
            if key2 then Set(key2, command, context) end
        else
            local click = AB.ClickOf(button)
            local wheels = click and { GetBindingKey(click) } or {}
            for _, key in ipairs(wheels) do Set(key, nil) end
        end
        Say(_G.KEY_UNBOUND or "Key unbound")
    end

    -- Taken from something else: said, as the game's mode says it.
    local function SayTaken(key, from)
        local name = NameOf(from)
        if name then
            Say(("%s taken from %s"):format(KeyName(key), name), ERROR)
        else
            Say(_G.KEY_BOUND or "Key bound")
        end
    end

    -- A key: the button's first key replaced, its other keys kept in order.
    local function BindKey(button, key)
        local command = AB.commands[button]
        local context = ContextOf(command)
        local keys = { GetBindingKey(command, nil, context) }
        for _, each in ipairs(keys) do Set(each, nil, context) end
        local old = GetBindingAction(key, nil, context)
        if old ~= "" then Set(key, nil, context) end

        local order, replaced = {}, false
        for _, each in ipairs(keys) do
            if not replaced and not AB.IsWheel(each) then
                order[#order + 1] = key
                replaced = true
            elseif each ~= key then
                order[#order + 1] = each
            end
        end
        if not replaced then table.insert(order, 1, key) end

        local bound = true
        for _, each in ipairs(order) do
            if not Set(each, command, context) and each == key then bound = false end
        end
        if not bound then
            -- Put back as it was.
            for _, each in ipairs(order) do SetBinding(each, nil, context) end
            for _, each in ipairs(keys) do SetBinding(each, command, context) end
            if old ~= "" then SetBinding(key, old, context) end
            Say(_G.KEYBINDINGFRAME_MOUSEWHEEL_ERROR or "Can't bind that key", ERROR)
            return
        end
        SayTaken(key, old ~= "" and old ~= command and old or nil)
    end

    -- A wheel: an extra key. On the command where the game takes it (the
    -- stance buttons'), else a click of the button.
    local function BindWheel(button, key)
        local command = AB.commands[button]
        local context = ContextOf(command)
        local click = AB.ClickOf(button)
        local old = GetBindingAction(key, nil, context)
        if old == command or old == click then
            Say(_G.KEY_BOUND or "Key bound")
            return
        end
        if old ~= "" then Set(key, nil, context) end
        local bound = Set(key, command, context)
        if not bound and click then
            bound = SetClick(key, button:GetName(), click:match(":(.+)$"))
        end
        if not bound then
            if old ~= "" then SetBinding(key, old, context) end
            Say(_G.KEYBINDINGFRAME_MOUSEWHEEL_ERROR or "Can't bind the mouse wheel there", ERROR)
            return
        end
        SayTaken(key, old ~= "" and old or nil)
    end

    -- Whatever was pressed over the button: bound, and kept at once.
    function Keybinds.Press(input)
        if InCombatLockdown() or not open or not pointed then return end
        local button = pointed
        if input == "ESCAPE" then
            Unbind(button)
        else
            local key = GetConvertedKeyOrButton and GetConvertedKeyOrButton(input) or input
            if IsKeyPressIgnoredForBinding and IsKeyPressIgnoredForBinding(key) then return end
            local chord = CreateKeyChordStringUsingMetaKeyState
                and CreateKeyChordStringUsingMetaKeyState(key) or key
            if AB.IsWheel(chord) then BindWheel(button, chord) else BindKey(button, chord) end
        end
        Save()
        if AB.Mark then AB.Mark("hotkeys") end
        if pointed == button then ShowTooltip(button) end
    end

    -- Print Screen still takes a screenshot (the game's own binding, passed
    -- on - never run from here), as in the game's mode.
    local function PassOn(frame, key)
        if not frame.SetPropagateKeyboardInput or InCombatLockdown() then return end
        local action = GetBindingFromClick and GetBindingFromClick(key)
        frame:SetPropagateKeyboardInput(action == "SCREENSHOT")
    end

    ---------------------------------------------------------------------------
    -- THE CAPTURE: over the button pointed at, taking every key, mouse button
    -- and wheel turn (not passed on - nothing of the game's sees them).
    ---------------------------------------------------------------------------

    local function Capture()
        if capture then return capture end
        capture = CreateFrame("Frame", Core.ADDON_NAME .. "KeybindCapture", UIParent)
        capture:SetFrameStrata("TOOLTIP")
        capture:EnableMouse(true)
        capture:EnableKeyboard(true)
        capture:EnableMouseWheel(true)
        capture:Hide()
        capture.fill = W.Flat(capture, "BACKGROUND", POINTED)
        capture.fill:SetAllPoints(capture)
        capture.border = Style.AddBorder(capture)
        capture:SetScript("OnKeyDown", function(self, key)
            PassOn(self, key)
            Keybinds.Press(key)
        end)
        capture:SetScript("OnMouseDown", function(_, mouse)
            if mouse ~= "LeftButton" and mouse ~= "RightButton" then Keybinds.Press(mouse) end
        end)
        capture:SetScript("OnMouseWheel", function(_, delta)
            Keybinds.Press(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
        end)
        Keybinds.capture = capture
        return capture
    end

    local function Point(button)
        if pointed == button then return end
        pointed = button
        Capture()
        if button then
            capture:ClearAllPoints()
            capture:SetAllPoints(button)
            capture:Show()
            ShowTooltip(button)
        else
            capture:Hide()
            if GameTooltip and GameTooltip:IsOwned(capture) then GameTooltip:Hide() end
        end
    end

    -- Every button bindable lit; the one under the mouse taken. Each frame.
    local function Light(button)
        local light = lit[button]
        if not light then
            light = CreateFrame("Frame", nil, driver)
            light:SetFrameStrata("DIALOG")
            light:SetAllPoints(button)
            light.fill = W.Flat(light, "OVERLAY", LIT)
            light.fill:SetAllPoints(light)
            lit[button] = light
        end
        return light
    end

    local under             -- (Drive's: the button found under the mouse)

    local function LightOne(button)
        local bindable = Bindable(button)
        Light(button):SetShown(bindable)
        if bindable and not under and button:IsMouseOver() then under = button end
    end

    local function Drive()
        -- (Unlock Mode opened meanwhile, from the options: kept and left.)
        if open and Keybinds.mode == "own" and Core.IsUnlocked() then
            Keybinds.Close(true)
            return
        end
        under = nil
        EachButton(LightOne)
        Point(under)
    end
    Keybinds.Drive = Drive

    ---------------------------------------------------------------------------
    -- THE WINDOW, at the top of the screen (where Unlock Mode's bar opens):
    --
    --   Quick Keybind Mode
    --   Point at a button and press a key. ...
    --   (what the last key did)
    --   [ Reset to Default ]                         [ Cancel ] [ Okay ]
    ---------------------------------------------------------------------------

    local function Build()
        if window then return end
        window = Unlock.NewWindow("Keybinds", WIDTH, 132)
        Keybinds.window = window

        window.title = W.Text(window, 15, W.GOLD, true)
        window.title:SetPoint("TOPLEFT", window, "TOPLEFT", SIDE, -14)
        window.title:SetText("Quick Keybind Mode")

        window.text = W.Text(window, 12, W.MUTED, false, WIDTH - 2 * SIDE)
        window.text:SetPoint("TOPLEFT", window.title, "BOTTOMLEFT", 0, -8)
        window.text:SetText("Point at a button and press a key. The mouse wheel binds as an extra key. Escape unbinds.")

        window.output = W.Text(window, 12, W.TEXT, false, WIDTH - 2 * SIDE)
        window.output:SetPoint("TOPLEFT", window.text, "BOTTOMLEFT", 0, -8)

        window.okay = W.Button(window, _G.OKAY or "Okay", 90, function() Keybinds.Close(true) end, "active")
        window.okay:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -SIDE, 12)
        window.cancel = W.Button(window, _G.CANCEL or "Cancel", 90, function() Keybinds.Close(false) end)
        window.cancel:SetPoint("RIGHT", window.okay, "LEFT", -8, 0)
        -- Every key of the game's back to its defaults, saved at once - as
        -- the game's own Reset to Default (KeybindListener:ResetBindingsToDefault).
        window.defaults = W.TwoStep(window, "Reset to Default", "Reset every key?", 150, function()
            if InCombatLockdown() or not LoadBindings then return end
            LoadBindings(Enum.BindingSet.Default)
            Forget()
            Save()
            if AB.Mark then AB.Mark("hotkeys") end
            Say("Every key reset to the game's defaults.")
        end)
        window.defaults:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", SIDE, 12)

        -- Keys while pointing at nothing: kept from the game (no spell cast
        -- while binding), but Escape, which leaves as Cancel does, and Print
        -- Screen. (The game's mode: no keyboard - its own window takes them.)
        window:SetScript("OnKeyDown", function(self, key)
            PassOn(self, key)
            if key == "ESCAPE" then Keybinds.Close(false) end
        end)

        driver = CreateFrame("Frame", nil, UIParent)
        driver:Hide()
        driver:SetScript("OnUpdate", Drive)
    end

    -- What every mode has: the buttons lit (the empty ones and the
    -- auto-hidden bars there too: AB.keybinding, Menus\ActionBars.lua), the
    -- capture following the mouse.
    local function Begin()
        Say("")
        Forget()
        AB.keybinding = true
        if AB.Mark then AB.Mark("all") end
        -- (The auto-hidden bars woken to show for it.)
        DogsForeverUI.Menus.ActionBars:Refresh()
        window:Show()
        driver:Show()
        Drive()
    end

    local function Finish()
        AB.keybinding = false
        if AB.Mark then AB.Mark("all") end
        DogsForeverUI.Menus.ActionBars:Refresh()
        Point(nil)
        driver:Hide()
        for _, light in pairs(lit) do light:Hide() end
        window:Hide()
        if window.defaults.disarm then window.defaults.disarm() end
    end

    -- Where Unlock Mode's bar opens: centred, just under the micro menu's
    -- place on the top edge.
    local function PlaceWindow()
        local below = Unlock.BAR_GAP or 8
        local micro = Core.Snap and Core.Snap.EntryById("micro")
        local box = micro and Core.Snap.Box(micro)
        if box then below = below + (box.t - box.b) end
        window:ClearAllPoints()
        window:SetPoint("TOP", UIParent, "TOP", 0, -below)
    end

    -- From the options window's header: that window makes way and comes back
    -- after. Unlock Mode open: left first (asked about, when something in it
    -- is unsaved), then this.
    function Keybinds.Open()
        if open or InCombatLockdown() then return false end
        if Core.IsUnlocked() then
            Core.RequestClose(false, function() Keybinds.Open() end)
            return false
        end
        Build()
        open, Keybinds.mode = true, "own"
        local options = Core.Options
        fromOptions = options.IsShown and options.IsShown() or false
        if fromOptions then options.Close() end
        PlaceWindow()
        window:EnableKeyboard(true)
        Keybinds.ShowGameButtons(false)
        Begin()
        return true
    end

    -- Okay (keep): what was bound stays (it is saved already). Cancel: every
    -- key the mode changed put back, and saved.
    function Keybinds.Close(keep)
        if not open or Keybinds.mode ~= "own" then return end
        open = false
        if keep then
            Forget()
            Save()
        else
            PutBack()
        end
        if AB.Mark then AB.Mark("hotkeys") end
        Finish()
        if fromOptions then
            fromOptions = false
            if Core.Options.Open then Core.Options.Open() end
        end
    end

    ---------------------------------------------------------------------------
    -- THE GAME'S QUICK KEYBIND MODE COMES HERE (the player, 2026-10-03:
    -- "games default quick keybinding should redirect to 'our' quick
    -- keybinding"): opened by the game (Options > Keybindings, Edit Mode),
    -- its window is put out of sight - no opacity, no mouse - and this one is
    -- there instead, binding the addon's buttons as above, the wheel too.
    --
    -- The game's window stays open behind it, and does what only it may:
    -- this window's Okay and Cancel are secure buttons that click the game's
    -- own Okay and Cancel (a "click" SecureActionButton), so the game saves
    -- or puts back the keys and closes its mode - and goes back to Edit Mode
    -- or the options - with its own code, nothing of the addon's in it (run
    -- from here, its closing would open Edit Mode tainted). This window takes
    -- no keyboard: Escape, pointing at nothing, reaches the game's, which
    -- cancels as it always has. As the game's window hides, whatever way,
    -- this mode ends with it - and unless that was its Okay, the keys this
    -- mode changed (saved at once, so the game's own Cancel, which loads the
    -- saved keys, keeps them) are put back.
    ---------------------------------------------------------------------------

    local gameButtons = {}      -- ours -> the game's button it clicks
    local GAME_PARTS = { "OkayButton", "CancelButton", "DefaultsButton", "UseCharacterBindingsButton" }

    local function GameFrame()
        local frame = _G.QuickKeybindFrame
        return type(frame) == "table" and frame.SetAlpha and frame or nil
    end

    -- Kept over the window's own button: its place, and a strata above the
    -- window's.
    local function PlaceGameButton(button, over)
        button:ClearAllPoints()
        button:SetAllPoints(over)
        button:SetFrameStrata(Keybinds.SECURE_STRATA)
        button:SetFrameLevel((over:GetFrameLevel() or 1) + 10)
    end

    -- A secure button over `over`, clicking the game's `key` button, `before`
    -- first.
    local function GameButton(over, key, before)
        local frame = GameFrame()
        local target = frame and frame[key]
        if not target or InCombatLockdown() then return end
        -- (UIParent's, not the window's: a window holding a secure button
        -- could not be hidden in combat.)
        local button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
        button:RegisterForClicks("LeftButtonUp")
        button:SetAttribute("useOnKeyDown", false)
        button:SetAttribute("type", "click")
        button:SetAttribute("clickbutton", target)
        button:SetScript("PreClick", function() before() end)
        PlaceGameButton(button, over)
        -- (Its look the addon's button under it: hovered and pressed with it.)
        button:SetScript("OnEnter", function() over:GetScript("OnEnter")(over) end)
        button:SetScript("OnLeave", function() over:GetScript("OnLeave")(over) end)
        button:SetScript("OnMouseDown", function() over:GetScript("OnMouseDown")(over) end)
        button:SetScript("OnMouseUp", function() over:GetScript("OnMouseUp")(over) end)
        button:Hide()
        gameButtons[button] = over
        return button
    end

    -- The secure Okay and Cancel shown (the game's mode) or not.
    local hideAfterCombat = false
    function Keybinds.ShowGameButtons(shown)
        if InCombatLockdown() then
            hideAfterCombat = not shown
            return
        end
        hideAfterCombat = false
        for button, over in pairs(gameButtons) do
            if shown then PlaceGameButton(button, over) end
            button:SetShown(shown and true or false)
        end
    end

    -- The game's window out of sight and deaf (`hidden`), or back as it was.
    local function HideGameWindow(hidden)
        local frame = GameFrame()
        if not frame then return end
        frame:SetAlpha(hidden and 0 or 1)
        if frame.EnableMouse then frame:EnableMouse(not hidden) end
        for _, key in ipairs(GAME_PARTS) do
            local part = frame[key]
            if type(part) == "table" and part.EnableMouse then part:EnableMouse(not hidden) end
        end
    end

    function Keybinds.OpenForGame()
        if open or InCombatLockdown() or not GameFrame() then return end
        Build()
        if not window.gameOkay then
            -- Okay: the game saves (KeybindListener:Commit) and closes.
            window.gameOkay = GameButton(window.okay, "OkayButton", function() okayed = true end)
            -- Cancel: the keys put back and saved first - the game then loads
            -- the saved keys, as its Cancel does.
            window.gameCancel = GameButton(window.cancel, "CancelButton", function()
                okayed = false
                PutBack()
            end)
        end
        if not (window.gameOkay and window.gameCancel) then return end
        open, Keybinds.mode = true, "game"
        okayed = false
        HideGameWindow(true)
        window:ClearAllPoints()
        window:SetPoint("TOP", GameFrame(), "TOP", 0, 0)
        window:EnableKeyboard(false)
        Begin()
        Keybinds.ShowGameButtons(true)
    end

    -- The game's window hidden (its Okay, its Cancel, Escape...): ours with
    -- it. Not by its Okay: the keys this mode changed put back.
    function Keybinds.GameClosed()
        HideGameWindow(false)
        if not open or Keybinds.mode ~= "game" then return end
        open = false
        if okayed then
            Forget()
        else
            PutBack()
        end
        okayed = false
        if AB.Mark then AB.Mark("hotkeys") end
        Finish()
        Keybinds.ShowGameButtons(false)
    end

    -- Followed once the game's mode is there (its own addon, loaded when
    -- the game first needs it).
    local followed = false
    local function FollowGame()
        local frame = GameFrame()
        if followed or not frame or not frame.HookScript then return end
        followed = true
        frame:HookScript("OnShow", function() Keybinds.OpenForGame() end)
        frame:HookScript("OnHide", function() Keybinds.GameClosed() end)
        if frame:IsShown() then Keybinds.OpenForGame() end
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("ADDON_LOADED")
    events:SetScript("OnEvent", function(self, event, name)
        if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
            if event == "PLAYER_LOGIN" or name == "Blizzard_QuickKeybind" then FollowGame() end
            -- (Followed: nothing more to wait for.)
            if followed then
                self:UnregisterEvent("ADDON_LOADED")
                self:UnregisterEvent("PLAYER_LOGIN")
            end
            return
        end
        if event == "PLAYER_REGEN_DISABLED" then
            -- A fight: the addon's own mode left, what was bound kept.
            if open and Keybinds.mode == "own" then Keybinds.Close(true) end
            return
        end
        if saveAfterCombat then Save() end
        if hideAfterCombat then Keybinds.ShowGameButtons(false) end
    end)
    FollowGame()
end
