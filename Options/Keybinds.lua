-- Quick Keybind Mode, the addon's own: from the options' header, and in place
-- of the game's whenever it opens (never the game's run from here: taint). A
-- capture over the pointed button binds a key (its first), the wheel (an extra
-- one, AB.ClickOf) or Escape (unbinds); saved at once, Cancel puts it back.

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
    local SMALL_BARS = { "stance", "pet" }
    local GAME_PARTS = { "OkayButton", "CancelButton", "DefaultsButton", "UseCharacterBindingsButton" }
    -- The secure Okay and Cancel a strata above the window: the toplevel
    -- window, raised as clicked, once came up over them.
    Keybinds.SECURE_STRATA = "FULLSCREEN_DIALOG"

    local window, capture, driver
    local lit = {}              -- button -> its light
    local pointed               -- the button under the mouse
    local open = false
    local fromOptions = false
    local saveAfterCombat = false
    local hideAfterCombat = false
    local okayed = false        -- the game's mode left by its Okay
    local before = {}           -- "context|key" -> { key, action, context } before the mode changed it
    local gameButtons = {}      -- our secure button -> the window's button under it

    function Keybinds.IsOpen() return open end

    ---------------------------------------------------------------------------
    -- Names
    ---------------------------------------------------------------------------

    local function NameOf(action)
        if not action or action == "" then return end
        -- A wheel clicking one of the bars' buttons: that button's name.
        local frame = action:match("^CLICK ([^:]+):")
        if frame and _G[frame] and AB.commands[_G[frame]] then action = AB.commands[_G[frame]] end
        local name = GetBindingName(action)
        return name ~= "" and name or action
    end

    local function Say(text, colour)
        window.output:SetText(text)
        W.SetTextColour(window.output, colour or W.TEXT)
    end

    local function ShowTooltip(button)
        local tip = GameTooltip
        tip:SetOwner(capture, "ANCHOR_RIGHT")
        tip:AddLine(NameOf(AB.commands[button]) or "", 1, 1, 1)
        local keys = AB.KeysOf(button)
        if #keys > 0 then
            local names = {}
            for index, key in ipairs(keys) do names[index] = GetBindingText(key) end
            tip:AddLine(table.concat(names, ", "), 0.1, 1, 0.1)
            tip:AddLine(ESCAPE_TO_UNBIND or "Press Escape to unbind", 1, 0.82, 0)
        else
            tip:AddLine(NOT_BOUND or "Not Bound", 1, 0.25, 0.25)
            tip:AddLine(PRESS_KEY_TO_BIND or "Press a key to bind", 1, 0.82, 0)
        end
        tip:Show()
    end

    ---------------------------------------------------------------------------
    -- Kept at once, and put back: every change notes what the key was bound
    -- to the first time (Remember).
    ---------------------------------------------------------------------------

    local function Remember(key, context)
        local id = tostring(context or "") .. "|" .. key
        if before[id] then return end
        before[id] = { key = key, action = GetBindingAction(key, nil, context) or "", context = context }
    end

    local function Set(key, command, context)
        Remember(key, context)
        return SetBinding(key, command, context)
    end

    -- Into the game's binding set in use; after the fight, in one.
    local function Save()
        if InCombatLockdown() then
            saveAfterCombat = true
            return
        end
        saveAfterCombat = false
        SaveBindings(GetCurrentBindingSet())
    end

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
        before = {}
        if any then Save() end
        AB.Mark("hotkeys")
    end

    ---------------------------------------------------------------------------
    -- Binding: the game's listener's steps (Blizzard_Keybindings.lua).
    ---------------------------------------------------------------------------

    local function ContextOf(command)
        return C_KeyBindings.GetBindingContextForAction(command)
    end

    -- The first key off, its second bound again so it is the first now.
    local function Unbind(button)
        local command = AB.commands[button]
        local context = ContextOf(command)
        local key1, key2 = GetBindingKey(command, nil, context)
        if key1 then
            Set(key1, nil, context)
            if key2 then Set(key2, command, context) end
        else
            local click = AB.ClickOf(button)
            for _, key in ipairs(click and { GetBindingKey(click) } or {}) do Set(key, nil) end
        end
        Say(KEY_UNBOUND or "Key unbound")
    end

    local function SayTaken(key, from)
        local name = NameOf(from)
        if name then
            Say(("%s taken from %s"):format(GetBindingText(key), name), ERROR)
        else
            Say(KEY_BOUND or "Key bound")
        end
    end

    -- The button's first key replaced, its other keys kept in order.
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
            for _, each in ipairs(order) do SetBinding(each, nil, context) end
            for _, each in ipairs(keys) do SetBinding(each, command, context) end
            if old ~= "" then SetBinding(key, old, context) end
            Say(KEYBINDINGFRAME_MOUSEWHEEL_ERROR or "Can't bind that key", ERROR)
            return
        end
        SayTaken(key, old ~= "" and old ~= command and old or nil)
    end

    -- An extra key: on the command where the game takes it (stance
    -- buttons), else a click of the button.
    local function BindWheel(button, key)
        local command = AB.commands[button]
        local context = ContextOf(command)
        local click = AB.ClickOf(button)
        local old = GetBindingAction(key, nil, context)
        if old == command or old == click then
            Say(KEY_BOUND or "Key bound")
            return
        end
        if old ~= "" then Set(key, nil, context) end
        local bound = Set(key, command, context)
        if not bound and click then
            Remember(key)
            bound = SetBindingClick(key, button:GetName(), click:match(":(.+)$"))
        end
        if not bound then
            if old ~= "" then SetBinding(key, old, context) end
            Say(KEYBINDINGFRAME_MOUSEWHEEL_ERROR or "Can't bind the mouse wheel there", ERROR)
            return
        end
        SayTaken(key, old ~= "" and old or nil)
    end

    local function Press(input)
        if InCombatLockdown() or not open or not pointed then return end
        local button = pointed
        if input == "ESCAPE" then
            Unbind(button)
        else
            local key = GetConvertedKeyOrButton(input)
            if IsKeyPressIgnoredForBinding(key) then return end
            local chord = CreateKeyChordStringUsingMetaKeyState(key)
            if AB.IsWheel(chord) then BindWheel(button, chord) else BindKey(button, chord) end
        end
        Save()
        AB.Mark("hotkeys")
        if pointed == button then ShowTooltip(button) end
    end

    -- Print Screen still reaches the game (its binding, never run from here).
    local function PassOn(frame, key)
        if InCombatLockdown() then return end
        frame:SetPropagateKeyboardInput(GetBindingFromClick(key) == "SCREENSHOT")
    end

    ---------------------------------------------------------------------------
    -- The capture over the button pointed at, and the lights
    ---------------------------------------------------------------------------

    local function Capture()
        if capture then return end
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
            Press(key)
        end)
        capture:SetScript("OnMouseDown", function(_, mouse)
            if mouse ~= "LeftButton" and mouse ~= "RightButton" then Press(mouse) end
        end)
        capture:SetScript("OnMouseWheel", function(_, delta)
            Press(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
        end)
        Keybinds.capture = capture
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
            if GameTooltip:IsOwned(capture) then GameTooltip:Hide() end
        end
    end

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

    -- Every bindable one of `buttons` lit; answers the one under the mouse,
    -- or `under`.
    local function LightAll(buttons, under)
        for _, button in ipairs(buttons) do
            local bindable = AB.commands[button] ~= nil and button:IsVisible() and button:GetEffectiveAlpha() > 0
            Light(button):SetShown(bindable)
            if bindable and not under and button:IsMouseOver() then under = button end
        end
        return under
    end

    -- Each frame: every bindable button lit, the one under the mouse taken.
    function Keybinds.Drive()
        -- Unlock Mode opened meanwhile: left, its keys kept.
        if open and Keybinds.mode == "own" and Core.IsUnlocked() then
            Keybinds.Close(true)
            return
        end
        local under = LightAll(AB.all)
        for _, key in ipairs(SMALL_BARS) do under = LightAll(AB.buttons[key] or {}, under) end
        Point(under)
    end

    ---------------------------------------------------------------------------
    -- The window: title, how to, what the last key did; Reset to Default,
    -- Cancel and Okay.
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

        window.okay = W.Button(window, OKAY or "Okay", 90, function() Keybinds.Close(true) end, "active")
        window.okay:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -SIDE, 12)
        window.cancel = W.Button(window, CANCEL or "Cancel", 90, function() Keybinds.Close(false) end)
        window.cancel:SetPoint("RIGHT", window.okay, "LEFT", -8, 0)
        -- As the game's Reset to Default: every key its default, saved.
        window.defaults = W.TwoStep(window, "Reset to Default", "Reset every key?", 150, function()
            if InCombatLockdown() then return end
            LoadBindings(Enum.BindingSet.Default)
            before = {}
            Save()
            AB.Mark("hotkeys")
            Say("Every key reset to the game's defaults.")
        end)
        window.defaults:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", SIDE, 12)

        -- Pointing at nothing, keys go nowhere (no spell cast while binding)
        -- but Escape, which cancels, and Print Screen.
        window:SetScript("OnKeyDown", function(self, key)
            PassOn(self, key)
            if key == "ESCAPE" then Keybinds.Close(false) end
        end)

        driver = CreateFrame("Frame", nil, UIParent)
        driver:Hide()
        driver:SetScript("OnUpdate", Keybinds.Drive)
    end

    -- Every button lit, empty slots and auto-hidden bars too (AB.keybinding).
    local function Begin()
        Say("")
        before = {}
        AB.keybinding = true
        AB.Mark("all")
        Core.Menus.ActionBars:Refresh()
        window:Show()
        driver:Show()
        Keybinds.Drive()
    end

    -- Left: kept (`keep`), or what the mode changed put back.
    local function Finish(keep)
        open = false
        if keep then before = {} else PutBack() end
        AB.keybinding = false
        AB.Mark("all")
        Core.Menus.ActionBars:Refresh()
        Point(nil)
        driver:Hide()
        for _, light in pairs(lit) do light:Hide() end
        window:Hide()
        window.defaults.disarm()
    end

    -- Where Unlock Mode's bar opens: centred, under the micro menu's place.
    ---------------------------------------------------------------------------
    -- The game's own mode comes here: its window out of sight and deaf, ours
    -- over it. Our Okay and Cancel are secure buttons clicking the game's,
    -- so its own code saves or loads the keys and closes it (run from here,
    -- closing would open Edit Mode tainted). Our window takes no keyboard:
    -- Escape reaches the game's, which cancels.
    ---------------------------------------------------------------------------

    local function PlaceGameButton(button, over)
        button:ClearAllPoints()
        button:SetAllPoints(over)
        button:SetFrameStrata(Keybinds.SECURE_STRATA)
        button:SetFrameLevel(over:GetFrameLevel() + 10)
    end

    -- A secure button over `over`, clicking the game's `key` button after
    -- `first()`. UIParent's: a window holding a secure button could not be
    -- hidden in combat.
    local function GameButton(over, key, first)
        local button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
        button:RegisterForClicks("LeftButtonUp")
        button:SetAttribute("useOnKeyDown", false)
        button:SetAttribute("type", "click")
        button:SetAttribute("clickbutton", QuickKeybindFrame[key])
        button:SetScript("PreClick", first)
        PlaceGameButton(button, over)
        -- Hovered and pressed with the addon's button under it.
        for _, script in ipairs({ "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp" }) do
            button:SetScript(script, function() over:GetScript(script)(over) end)
        end
        button:Hide()
        gameButtons[button] = over
        return button
    end

    local function ShowGameButtons(shown)
        if InCombatLockdown() then
            hideAfterCombat = not shown
            return
        end
        hideAfterCombat = false
        for button, over in pairs(gameButtons) do
            if shown then PlaceGameButton(button, over) end
            button:SetShown(shown)
        end
    end

    local function HideGameWindow(hidden)
        local frame = QuickKeybindFrame
        frame:SetAlpha(hidden and 0 or 1)
        frame:EnableMouse(not hidden)
        for _, key in ipairs(GAME_PARTS) do frame[key]:EnableMouse(not hidden) end
    end

    ---------------------------------------------------------------------------
    -- Opening and closing
    ---------------------------------------------------------------------------

    -- From the options: they make way and come back after. Unlock Mode is
    -- left first (asking about unsaved changes).
    function Keybinds.Open()
        if open or InCombatLockdown() then return false end
        if Core.IsUnlocked() then
            Core.RequestClose(false, Keybinds.Open)
            return false
        end
        Build()
        open, Keybinds.mode = true, "own"
        fromOptions = Core.Options.IsShown()
        if fromOptions then Core.Options.Close() end
        Unlock.PlaceUnderMicro(window)
        window:EnableKeyboard(true)
        ShowGameButtons(false)
        Begin()
        return true
    end

    -- Okay keeps (saved already); Cancel puts back what the mode changed.
    function Keybinds.Close(keep)
        if not open or Keybinds.mode ~= "own" then return end
        if keep then Save() end
        Finish(keep)
        if fromOptions then
            fromOptions = false
            Core.Options.Open()
        end
    end

    local function OpenForGame()
        if open or InCombatLockdown() then return end
        Build()
        if not window.gameOkay then
            window.gameOkay = GameButton(window.okay, "OkayButton", function() okayed = true end)
            -- The keys put back and saved first: the game's Cancel then loads them.
            window.gameCancel = GameButton(window.cancel, "CancelButton", function()
                okayed = false
                PutBack()
            end)
        end
        open, Keybinds.mode = true, "game"
        okayed = false
        HideGameWindow(true)
        window:ClearAllPoints()
        window:SetPoint("TOP", QuickKeybindFrame, "TOP", 0, 0)
        window:EnableKeyboard(false)
        Begin()
        ShowGameButtons(true)
    end

    -- The game's window hidden, however: ours with it, and unless by its
    -- Okay, the keys this mode changed put back.
    local function GameClosed()
        HideGameWindow(false)
        if not open or Keybinds.mode ~= "game" then return end
        Finish(okayed)
        okayed = false
        ShowGameButtons(false)
    end

    -- The game's mode is LoadOnDemand (Blizzard_QuickKeybind).
    local function FollowGame()
        QuickKeybindFrame:HookScript("OnShow", OpenForGame)
        QuickKeybindFrame:HookScript("OnHide", GameClosed)
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", function(self, event, name)
        if event == "ADDON_LOADED" then
            if name ~= "Blizzard_QuickKeybind" then return end
            FollowGame()
            self:UnregisterEvent("ADDON_LOADED")
        elseif event == "PLAYER_REGEN_DISABLED" then
            -- A fight: the addon's own mode left, what was bound kept.
            if open and Keybinds.mode == "own" then Keybinds.Close(true) end
        else
            if saveAfterCombat then Save() end
            if hideAfterCombat then ShowGameButtons(false) end
        end
    end)
    if QuickKeybindFrame then FollowGame() else events:RegisterEvent("ADDON_LOADED") end
end
