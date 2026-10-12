-- MODULE: Action bars  (DogsForeverUI.ActionBars, settings section "actionbars")
-- EllesmereUI's way: eight secure bars of our own on the game's action slots (bar 1 pages like the
-- game's), the game's stance and pet buttons in two more. The game's bars hide without a protected
-- call; keys stay the game's (a key presses its hidden button); painting uses secret-safe calls only.

local AB = CreateFrame("Frame")
DogsForeverUI.ActionBars = AB

do -- private scope
    local Core = DogsForeverUI
    local IsSecret = issecretvalue

    local BUTTONS, BASE = 12, 45        -- an action bar's buttons; the game's action button's size
    local SCALE = 0.8                   -- the game's 80% is our 100%
    local SHOWN_ROWS, SHOWN_SPACING = 2, 2
    local CLICK_BUTTON = "Keybind"      -- the "mouse button" a wheel binding clicks with
    local COUNTDOWN_CVAR = "countdownForCooldowns"

    AB.key = "actionbars"
    AB.title = "Action bars"

    -- Slot offsets and binding commands are the game's; `game` is the bar each stands in for.
    AB.BARS = {
        { key = "bar1", label = "Action Bar 1", offset = 0,   command = "ACTIONBUTTON",          game = "MainActionBar", main = true, shown = true },
        { key = "bar2", label = "Action Bar 2", offset = 60,  command = "MULTIACTIONBAR1BUTTON", game = "MultiBarBottomLeft", shown = true },
        { key = "bar3", label = "Action Bar 3", offset = 48,  command = "MULTIACTIONBAR2BUTTON", game = "MultiBarBottomRight", shown = true },
        { key = "bar4", label = "Action Bar 4", offset = 24,  command = "MULTIACTIONBAR3BUTTON", game = "MultiBarRight", shown = true },
        { key = "bar5", label = "Action Bar 5", offset = 36,  command = "MULTIACTIONBAR4BUTTON", game = "MultiBarLeft", shown = true },
        { key = "bar6", label = "Action Bar 6", offset = 144, command = "MULTIACTIONBAR5BUTTON", game = "MultiBar5" },
        { key = "bar7", label = "Action Bar 7", offset = 156, command = "MULTIACTIONBAR6BUTTON", game = "MultiBar6" },
        { key = "bar8", label = "Action Bar 8", offset = 168, command = "MULTIACTIONBAR7BUTTON", game = "MultiBar7" },
        { key = "stance", label = "Stance Bar", command = "SHAPESHIFTBUTTON", game = "StanceBar",
          stance = true, prefix = "StanceButton", count = 10, gameBase = 30, grow = true },
        -- (Unlock Mode id "petbar": "pet" is the pet's unit frame.)
        { key = "pet", id = "petbar", label = "Pet Bar", command = "BONUSACTIONBUTTON", game = "PetActionBar",
          pet = true, prefix = "PetActionButton", count = 10, gameBase = 30, defaultSize = 20 },
    }
    AB.byKey = {}
    for _, bar in ipairs(AB.BARS) do
        bar.count = bar.count or BUTTONS
        bar.id = bar.id or bar.key
        bar.own = not (bar.stance or bar.pet)    -- buttons of our own, not the game's
        AB.byKey[bar.key] = bar
    end

    AB.SHOW = {
        { value = "always", label = "Always" },
        { value = "combat", label = "In combat" },
        { value = "nocombat", label = "Out of combat" },
        { value = "never", label = "Never" },
    }
    -- As the game's Edit Mode: Rows counts columns when vertical.
    AB.ORIENTATION = {
        { value = "horizontal", label = "Horizontal" },
        { value = "vertical", label = "Vertical" },
    }
    -- Which way a bar whose width changes by itself grows: the edge it keeps (Snap's fixedEdge).
    AB.GROW = {
        { value = "right", label = "Left to right" },
        { value = "left", label = "Right to left" },
        { value = "center", label = "From the middle" },
    }
    local FIXED_EDGE = { right = "LEFT", left = "RIGHT", center = "" }
    local GROW_SHIFT = { right = 0, left = 1, center = 0.5 }   -- share of a width change moved to the left edge
    local SHOW_TAIL = { always = "show", combat = "[combat] show; hide", nocombat = "[nocombat] show; hide", never = "hide" }
    AB.SIZE_MIN, AB.SIZE_MAX = 16, 64
    AB.SPACING_MAX = 12

    -- The flags mark one-time migrations and the game's bar switches turned on once.
    AB.defaults = { unlocked = false, shownByDefault = false, sizesRestored = false, fixedSizes = false,
                    gameToggles = false, gameBarsOn = false }
    AB.placement = {}
    for _, bar in ipairs(AB.BARS) do
        local k = bar.key
        AB.defaults[k .. "Buttons"] = bar.count
        AB.defaults[k .. "Rows"] = bar.shown and SHOWN_ROWS or 1
        AB.defaults[k .. "Size"] = bar.defaultSize or bar.gameBase or 36
        AB.defaults[k .. "Spacing"] = 2
        AB.defaults[k .. "Show"] = "always"
        AB.defaults[k .. "Orientation"] = "horizontal"
        if bar.own then AB.defaults[k .. "ShowEmpty"] = true end     -- Always Show Buttons
        if bar.grow then AB.defaults[k .. "Grow"] = "right" end
        for _, suffix in ipairs({ "Placed", "Left", "Top" }) do AB.placement[k .. suffix] = true end
    end

    AB.buttons = {}         -- bar key -> { button }
    AB.all = {}             -- every action button of ours (not stance or pet)
    AB.commands = setmetatable({}, { __mode = "k" })   -- button -> its binding command
    local frames = {}       -- bar key -> its secure frame
    local barOf = {}        -- action button -> its bar's key
    local entries = {}      -- bar key -> its Unlock Mode entry

    ---------------------------------------------------------------------------
    -- The game's bars, out of sight at file load (before a /reload restores combat). Never Hide()
    -- (the game shows them again): under a hidden frame - bar 1, which vehicles and pet battles
    -- still use, kept in place at no opacity instead.
    ---------------------------------------------------------------------------

    local hidden = CreateFrame("Frame", "DogsForeverUIHiddenBars", UIParent)
    hidden:SetAllPoints(UIParent)       -- full size: what is under it keeps its place
    hidden:Hide()
    AB.hidden = hidden

    local function NoMouse(frame)
        if frame then frame:EnableMouse(false) end
    end

    -- The main bar's page arrows, invisible but still clickable over our buttons.
    local function NoPagerMouse(bar)
        local pager = bar.ActionBarPageNumber
        if not pager then return end
        NoMouse(pager)
        NoMouse(pager.UpButton)
        NoMouse(pager.DownButton)
    end

    local function NoSelection(frame)
        local selection = frame and frame.Selection
        if not selection then return end
        selection:SetAlpha(0)
        NoMouse(selection)
    end

    local function DisposeGameBars()
        for _, info in ipairs(AB.BARS) do
            local bar = _G[info.game]
            if bar then
                if info.main then
                    if bar.HideBase then pcall(bar.HideBase, bar) end
                    hooksecurefunc(bar, "Show", function(self)
                        self:SetAlpha(0)
                        NoPagerMouse(self)
                    end)
                    NoMouse(bar)
                    NoPagerMouse(bar)
                    NoSelection(bar)
                    if bar.EndCaps then
                        NoSelection(bar.EndCaps.LeftEndCap)
                        NoSelection(bar.EndCaps.RightEndCap)
                    end
                    bar:SetAlpha(0)
                else
                    pcall(bar.UnregisterAllEvents, bar)
                    bar:SetParent(hidden)
                    -- Back under the hidden frame whenever the game shows it again.
                    bar:HookScript("OnShow", function(self)
                        if not InCombatLockdown() then self:SetParent(hidden) end
                    end)
                end
                -- The game's action buttons stay where they are, quiet: the keys still press them.
                if info.own and bar.actionButtons then
                    for _, button in pairs(bar.actionButtons) do
                        pcall(button.UnregisterAllEvents, button)
                        pcall(button.SetAttributeNoHandler, button, "statehidden", true)
                    end
                end
            end
        end
        if ActionBarParent then
            pcall(ActionBarParent.Hide, ActionBarParent)
            ActionBarParent:SetParent(hidden)
        end
    end

    -- The game's button broadcasters (EllesmereUI's): quiet but for ACTIONBAR_SLOT_CHANGED and
    -- PLAYER_ENTERING_WORLD (the hidden buttons' slots, for the keys); ticks and casts come back
    -- only while the vehicle bar or extra button shows and cooldowns are not secret.
    local TICK_EVENTS = {
        "ACTIONBAR_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_STATE", "ACTIONBAR_UPDATE_USABLE",
        "SPELL_UPDATE_COOLDOWN", "UPDATE_SHAPESHIFT_FORM",
    }
    local CAST_EVENTS = {
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED",
        "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    }
    local QUIET_EVENTS = {
        "UPDATE_BINDINGS", "GAME_PAD_ACTIVE_CHANGED", "PET_BAR_UPDATE",
        "UNIT_FLAGS", "UNIT_AURA", "PLAYER_MOUNT_DISPLAY_CHANGED",
    }

    local function QuietBroadcasters()
        local buttons = ActionBarButtonEventsFrame
        for _, events in ipairs({ QUIET_EVENTS, TICK_EVENTS }) do
            for _, event in ipairs(events) do pcall(buttons.UnregisterEvent, buttons, event) end
        end
        pcall(ActionBarActionEventsFrame.UnregisterAllEvents, ActionBarActionEventsFrame)
    end

    local function Shown(name)
        local frame = _G[name]
        return frame and frame:IsShown() or false
    end

    local broadcasting = false
    local function UpdateBroadcasters()
        local Secret = C_Secrets.ShouldCooldownsBeSecret
        local want = (Shown("OverrideActionBarButton1") or Shown("ExtraActionButton1"))
            and not (Secret and Secret() == true)
        if want == broadcasting then return end
        broadcasting = want
        QuietBroadcasters()
        if not want then return end
        local buttons, actions = ActionBarButtonEventsFrame, ActionBarActionEventsFrame
        for _, event in ipairs(TICK_EVENTS) do pcall(buttons.RegisterEvent, buttons, event) end
        for _, event in ipairs(CAST_EVENTS) do pcall(actions.RegisterUnitEvent, actions, event, "player") end
    end

    -- Bar 1's pages, as the game's on this client: override, vehicle or possess bar, the page
    -- keys, every class's form (6 + its offset), skyriding, then page 1.
    local function PageConditions()
        local parts = {
            "[overridebar] " .. C_ActionBar.GetOverrideBarIndex(),
            "[vehicleui][possessbar] " .. C_ActionBar.GetVehicleBarIndex(),
        }
        for page = 2, NUM_ACTIONBAR_PAGES do parts[#parts + 1] = "[bar:" .. page .. "] " .. page end
        for form = 1, 4 do parts[#parts + 1] = "[bonusbar:" .. form .. "] " .. (6 + form) end
        parts[#parts + 1] = "[bonusbar:5] 11"
        parts[#parts + 1] = "1"
        return table.concat(parts, "; ")
    end

    ---------------------------------------------------------------------------
    -- Painting: icon, count, cooldowns, hotkeys - once a frame, secret values handed to widgets
    -- as they are. Range and glow are the game's button code's, from the button's own events.
    ---------------------------------------------------------------------------

    local function Has(action) return action and C_ActionBar.HasAction(action) and true or false end

    -- A cooldown from the client's info and duration object (which may be secret).
    local function SetDuration(cooldown, info, Duration, action)
        local duration = info and info.isActive and Duration(action)
        if duration then cooldown:SetCooldownFromDurationObject(duration) else cooldown:Clear() end
    end

    local function PaintCooldown(button, action)
        local api, charge, loss = C_ActionBar, button.chargeCooldown, button.lossOfControlCooldown
        if not Has(action) then
            button.cooldown:Clear()
            charge:Clear()
            loss:Clear()
            return
        end
        SetDuration(button.cooldown, api.GetActionCooldown(action), api.GetActionCooldownDuration, action)
        local charges = api.GetActionCharges(action)
        local max = charges and charges.maxCharges
        if charges and charges.isActive and not IsSecret(max) and type(max) == "number" and max > 1 then
            SetDuration(charge, charges, api.GetActionChargeDuration, action)
        else
            charge:Clear()
        end
        SetDuration(loss, api.GetActionLossOfControlCooldownInfo(action), api.GetActionLossOfControlCooldownDuration, action)
    end

    local function PaintCount(button, action)
        local text = Has(action) and C_ActionBar.GetActionDisplayCount(action)
        -- A secret count is set as it is; only a plain nothing becomes "".
        if not IsSecret(text) and not text then text = "" end
        button.Count:SetText(text)
    end

    -- The game's Show Numbers for Cooldowns: its own buttons follow it through the broadcaster ours are off.
    local function PaintCountdowns()
        local hide = not GetCVarBool(COUNTDOWN_CVAR)
        for _, button in ipairs(AB.all) do button.cooldown:SetHideCountdownNumbers(hide) end
    end

    local function PaintUsable(icon, action)
        local usable, noMana = C_ActionBar.IsUsableAction(action)
        if usable then
            icon:SetVertexColor(1, 1, 1)
        elseif noMana then
            icon:SetVertexColor(0.5, 0.5, 1)
        elseif usable ~= nil then
            icon:SetVertexColor(0.4, 0.4, 0.4)
        end
    end

    -- An empty slot with Always Show Buttons off: at no opacity (a secure button cannot hide in
    -- combat, and must still take a drop) - but shown while dragging, unlocked or binding keys.
    local dragging = false
    function AB.PaintEmpty(button, filled)
        local key, db = barOf[button], AB.db
        local hide = not filled and key and db and db[key .. "ShowEmpty"] == false
            and not dragging and not db.unlocked and not AB.keybinding
        button:SetAlpha(hide and 0 or 1)
    end

    -- Everything a slot's contents decide (EllesmereUI's ForceButtonRefresh).
    local function PaintButton(button)
        local action = button:GetAttribute("action")
        if not action then return end
        local api, icon = C_ActionBar, button.icon
        local filled = Has(action)
        icon:SetTexture(api.GetActionTexture(action))
        icon:SetShown(filled)
        icon:SetDesaturated(false)
        if filled then pcall(PaintUsable, icon, action) end
        PaintCount(button, action)
        button.Name:SetText(filled and api.UsesActionText(action) and api.GetActionText(action) or "")
        PaintCooldown(button, action)
        button:SetChecked(filled and (api.IsCurrentAction(action) or api.IsAutoRepeatAction(action)) and true or false)
        button.Border:SetShown(filled and api.IsEquippedAction(action) and true or false)
        AB.PaintEmpty(button, filled)
    end

    -- A wheel has no key-up, so it binds to a click of the button, not its command: ours with
    -- "Keybind", the game's stance/pet buttons with the left button.
    function AB.ClickOf(button)
        local name = button:GetName()
        return name and "CLICK " .. name .. ":" .. (barOf[button] and CLICK_BUTTON or "LeftButton")
    end

    function AB.IsWheel(key) return type(key) == "string" and key:find("MOUSEWHEEL", 1, true) ~= nil end

    -- Every key of the button: its command's, in the game's order, then the wheels clicking it.
    function AB.KeysOf(button)
        local keys = {}
        local command = AB.commands[button]
        if command then
            keys = { GetBindingKey(command, nil, C_KeyBindings.GetBindingContextForAction(command)) }
        end
        local click = AB.ClickOf(button)
        if click then
            for _, key in ipairs({ GetBindingKey(click) }) do keys[#keys + 1] = key end
        end
        return keys
    end

    local function Replace(text, find, with)
        if type(find) ~= "string" or find == "" then return text end
        local at = text:find(find, 1, true)
        if not at then return text end
        return text:sub(1, at - 1) .. with .. text:sub(at + #find)
    end

    -- The game's short form; a wheel shorter still ("WU", "WD"), as EllesmereUI writes them.
    local function KeyText(key)
        local text = GetBindingText(key, 1)
        text = Replace(text, KEY_MOUSEWHEELUP, "WU")
        text = Replace(text, KEY_MOUSEWHEELDOWN, "WD")
        text = Replace(text, "MOUSEWHEELUP", "WU")
        return Replace(text, "MOUSEWHEELDOWN", "WD")
    end

    local function PaintHotkey(button)
        local hotkey = button.HotKey
        if not (hotkey and AB.commands[button]) then return end
        -- A key on the keyboard (or mouse) before a wheel.
        local key
        for _, each in ipairs(AB.KeysOf(button)) do
            if not AB.IsWheel(each) then key = each break end
            key = key or each
        end
        local text = key and KeyText(key) or ""
        if text == "" then
            hotkey:SetText(RANGE_INDICATOR)     -- kept for the out-of-range colour
            hotkey:Hide()
        else
            hotkey:SetText(text)
            hotkey:Show()
        end
    end

    local function PaintHotkeys()
        for _, button in ipairs(AB.all) do PaintHotkey(button) end
        for _, button in ipairs(AB.buttons.stance) do PaintHotkey(button) end
        for _, button in ipairs(AB.buttons.pet) do PaintHotkey(button) end
    end

    -- The game's extra action and vehicle buttons, their broadcaster quiet while cooldowns are
    -- secret: cooldowns (and vehicle keys) painted here by widget calls, nothing written onto them.
    local GAME_ACTION_BUTTONS = { "ExtraActionButton1" }
    for index = 1, 6 do GAME_ACTION_BUTTONS[index + 1] = "OverrideActionBarButton" .. index end

    local function PaintGameCooldown(button)
        local action = button:GetAttribute("action")
        if not Has(action) then return end
        SetDuration(button.cooldown, C_ActionBar.GetActionCooldown(action), C_ActionBar.GetActionCooldownDuration, action)
    end

    local function PaintVehicleHotkey(button, index)
        local key = GetBindingKey("ACTIONBUTTON" .. index)
        if not (key and button.HotKey) then return end
        button.HotKey:SetText(KeyText(key))
        button.HotKey:Show()
    end

    local function PaintGameButtons(keys)
        for index, name in ipairs(GAME_ACTION_BUTTONS) do
            local button = _G[name]
            if button and button:IsShown() then
                pcall(PaintGameCooldown, button)
                if keys and index > 1 then pcall(PaintVehicleHotkey, button, index - 1) end
            end
        end
    end

    local function PaintStances()
        local forms = GetNumShapeshiftForms()
        for index, button in ipairs(AB.buttons.stance) do
            if index <= forms then
                local texture, active, castable = GetShapeshiftFormInfo(index)
                local shade = castable and 1 or 0.4
                button.icon:SetTexture(texture)
                button.icon:SetShown(texture ~= nil)
                button.icon:SetVertexColor(shade, shade, shade)
                button:SetChecked(active and true or false)
                if button.cooldown then
                    local start, duration, enable = GetShapeshiftFormCooldown(index)
                    CooldownFrame_Set(button.cooldown, start, duration, enable)
                end
            end
        end
    end

    -- By hand: the game's PetActionBar:Update run from here taints what its Edit Mode reads.
    local function PaintPets()
        local hasBar = PetHasActionBar()
        for index, button in ipairs(AB.buttons.pet) do
            local _, texture, isToken, active, autoCastAllowed, autoCastEnabled = GetPetActionInfo(index)
            local icon = button.icon
            if hasBar and texture then
                local shade = GetPetActionSlotUsable(index) and 1 or 0.4
                icon:SetTexture(isToken and _G[texture] or texture)
                icon:SetVertexColor(shade, shade, shade)
                icon:Show()
            else
                icon:Hide()
            end
            local overlay = button.AutoCastOverlay
            if overlay then
                overlay:SetShown(hasBar and texture and autoCastAllowed and true or false)
                overlay:ShowAutoCastEnabled(autoCastEnabled and true or false)
            end
            button:SetChecked(hasBar and active and true or false)
            if button.cooldown then
                local start, duration, enable = GetPetActionCooldown(index)
                CooldownFrame_Set(button.cooldown, start, duration, enable)
            end
        end
    end

    local function RefreshAll()
        for _, button in ipairs(AB.all) do pcall(PaintButton, button) end
        pcall(PaintCountdowns)
        PaintHotkeys()
        pcall(PaintStances)
        pcall(PaintPets)
    end

    local dirty = {}        -- what waits for the next frame: "all", "cooldowns", "counts", "hotkeys", "stances", "pets"
    local slots = {}        -- slots whose contents changed
    local painter = CreateFrame("Frame")
    painter:Hide()
    -- (Plain loops, no closures: the cooldown events come many times a second in a fight.)
    painter:SetScript("OnUpdate", function(self)
        self:Hide()
        if dirty.all then
            wipe(dirty)
            wipe(slots)
            RefreshAll()
            PaintGameButtons(true)
            return
        end
        local game = false      -- the game's extra and vehicle buttons, once
        if next(slots) then
            for _, button in ipairs(AB.all) do
                local action = button:GetAttribute("action")
                if action and slots[action] then pcall(PaintButton, button) end
            end
            wipe(slots)
            game = true
        end
        if dirty.cooldowns then
            dirty.cooldowns = nil
            for _, button in ipairs(AB.all) do
                if button:IsVisible() then pcall(PaintCooldown, button, button:GetAttribute("action")) end
            end
            game = true
        end
        if game then PaintGameButtons(false) end
        if dirty.counts then
            dirty.counts = nil
            for _, button in ipairs(AB.all) do pcall(PaintCount, button, button:GetAttribute("action")) end
        end
        if dirty.hotkeys then
            dirty.hotkeys = nil
            PaintHotkeys()
        end
        if dirty.stances then
            dirty.stances = nil
            pcall(PaintStances)
        end
        if dirty.pets then
            dirty.pets = nil
            pcall(PaintPets)
        end
    end)

    local function Mark(what)
        dirty[what] = true
        painter:Show()
    end
    AB.Mark = Mark

    ---------------------------------------------------------------------------
    -- A key presses the game's hidden twin, so after its ActionButtonDown / MultiActionButtonDown
    -- ours shows pushed while the key is held, at least PRESS_MIN; a wheel's click for PRESS_MIN.
    ---------------------------------------------------------------------------

    local PRESS_MIN = 0.1
    local held = {}             -- button -> its state, while it shows pressed
    local states = {}           -- button -> { keys = base key names, since = seconds }
    local watcher = CreateFrame("Frame")
    watcher:Hide()

    -- "SHIFT-1" -> "1": IsKeyDown takes the bare key ("SHIFT--" ends in the minus key).
    local function BaseKey(key)
        if key:sub(-1) == "-" then return "-" end
        return key:match("[^%-]+$")
    end

    local function Release(button)
        held[button] = nil
        -- (Held down by the mouse meanwhile: the game's own state shows it.)
        local state = button.GetButtonState and button:GetButtonState()
        if state ~= "PUSHED" then button:GetPushedTexture():Hide() end
    end

    local function ShowPress(button, fromKey)
        local pushed = button:GetPushedTexture()
        if not (pushed and button:IsVisible()) then return end
        local state = states[button] or { keys = {} }
        states[button] = state
        local keys = state.keys
        wipe(keys)
        if fromKey then
            for _, key in ipairs(AB.KeysOf(button)) do
                if not AB.IsWheel(key) then keys[#keys + 1] = BaseKey(key) end
            end
        end
        state.since = 0
        pushed:Show()
        held[button] = state
        watcher:Show()
    end

    watcher:SetScript("OnUpdate", function(self, elapsed)
        for button, state in pairs(held) do
            state.since = state.since + elapsed
            local down = false
            for _, key in ipairs(state.keys) do
                if IsKeyDown(key) then
                    down = true
                    break
                end
            end
            if not down and state.since >= PRESS_MIN then Release(button) end
        end
        if not next(held) then self:Hide() end
    end)

    local function OnPreClick(self, mouse)
        if mouse == CLICK_BUTTON then ShowPress(self, false) end
    end

    ---------------------------------------------------------------------------
    -- Our bars and buttons.
    ---------------------------------------------------------------------------

    -- The events each button hands the game's button code; never slot or cooldown events (that
    -- code, run from here, would pass secret cooldowns on tainted).
    local BUTTON_EVENTS = {
        "ACTIONBAR_UPDATE_STATE", "ACTIONBAR_UPDATE_USABLE", "PLAYER_ENTERING_WORLD",
        "UPDATE_SHAPESHIFT_FORM", "SPELL_UPDATE_CHARGES", "UPDATE_INVENTORY_ALERTS",
        "PLAYER_EQUIPMENT_CHANGED", "PLAYER_TARGET_CHANGED",
        "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
        "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
    }
    local STANCE_EVENTS = {
        "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_FORM", "ACTIONBAR_PAGE_CHANGED",
        "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_COOLDOWN",
    }
    local PET_EVENTS = {
        "PET_BAR_UPDATE", "PET_BAR_UPDATE_COOLDOWN", "PET_BAR_UPDATE_USABLE",
        "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_FARSIGHT_FOCUS_CHANGED",
        "PLAYER_ENTERING_WORLD", "PET_BAR_SHOWGRID", "PET_BAR_HIDEGRID",
    }

    -- Out of the game's broadcaster list in place (table.remove would move, and taint, its entries).
    local function OffBroadcaster(button)
        local list = ActionBarButtonEventsFrame.frames
        if not list then return end
        if list[#list] == button then
            list[#list] = nil
            return
        end
        for key, frame in pairs(list) do
            if frame == button then list[key] = nil end
        end
    end

    -- A mouse click acts on release, a key (and a wheel's "Keybind" click) on press, as the game's
    -- buttons: a Shift-drag never casts. Set in the secure wrap, so it holds in combat.
    AB.CLICK_SNIPPET = [[ self:SetAttribute("useOnKeyDown", button == "Keybind") ]]

    -- Bar 1's: on a page change, the action slot of that page.
    local PAGE_SNIPPET = "local page = tonumber(message) or 1; self:SetAttribute('action', %d + (page - 1) * 12)"

    local function NewActionButton(info, index, frame)
        local slot = info.offset + index
        local name = "DogsForeverUIActionButton" .. slot
        local button = _G[name] or CreateFrame("CheckButton", name, frame,
            "ActionBarButtonTemplate, SecureActionButtonTemplate")
        button:SetParent(frame)
        button:UnregisterEvent("ACTIONBAR_SLOT_CHANGED")
        button:UnregisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
        OffBroadcaster(button)
        for _, event in ipairs(BUTTON_EVENTS) do pcall(button.RegisterEvent, button, event) end
        button:SetID(0)
        button:SetAttribute("action", slot)
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:SetAttribute("useOnKeyDown", GetCVarBool("ActionButtonUseKeyDown"))
        if info.main then button:SetAttribute("_childupdate-page", PAGE_SNIPPET:format(index)) end
        button.commandName = info.command .. index
        AB.commands[button] = button.commandName
        AB.all[#AB.all + 1] = button
        barOf[button] = info.key
        frame:WrapScript(button, "OnClick", AB.CLICK_SNIPPET)
        button:HookScript("PreClick", OnPreClick)
        return button
    end

    -- The game's stance/pet button (30) in an action button's shape (45), so a size draws it as ours.
    local function GameButtonLikeOurs(button)
        if InCombatLockdown() then return end
        button:SetSize(BASE, BASE)
        if button.HotKey then
            button.HotKey:ClearAllPoints()
            button.HotKey:SetPoint("TOPRIGHT", -5, -5)
        end
        if button.Count then
            button.Count:ClearAllPoints()
            button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 5)
        end
        if button.AutoCastOverlay then button.AutoCastOverlay:SetSize(BASE, BASE) end
    end

    local function TakeGameButton(info, index, frame)
        local button = _G[info.prefix .. index]
        if not button then return end
        button:SetAttributeNoHandler("statehidden", nil)
        for _, event in ipairs(info.stance and STANCE_EVENTS or PET_EVENTS) do
            pcall(button.RegisterEvent, button, event)
        end
        if info.pet then
            pcall(button.RegisterUnitEvent, button, "UNIT_PET", "player")
            pcall(button.RegisterUnitEvent, button, "UNIT_FLAGS", "pet")
        end
        button:SetParent(frame)
        GameButtonLikeOurs(button)
        AB.commands[button] = info.command .. index     -- kept here: nothing written onto the game's button
        return button
    end

    local function NewBar(info)
        local frame = CreateFrame("Frame", "DogsForeverUIActionBar" .. (info.key:match("%d+") or info.label:gsub(" ", "")),
            UIParent, "SecureHandlerStateTemplate")
        frame:SetSize(1, 1)
        frame:SetPoint("CENTER")
        frame:SetMouseClickEnabled(false)
        frame:SetClampedToScreen(true)
        frames[info.key] = frame

        local buttons = {}
        for index = 1, info.count do
            if info.own then
                buttons[index] = NewActionButton(info, index, frame)
            else
                buttons[index] = TakeGameButton(info, index, frame)
            end
        end
        AB.buttons[info.key] = buttons

        if info.main then
            -- The page, set securely: on our buttons, and on the game's bar 1 whose buttons the keys press.
            frame:SetFrameRef("gamebar", MainActionBar)
            frame:SetAttribute("_onstate-page", [[
                local page = tonumber(newstate) or 1
                self:SetAttribute("actionpage", page)
                self:ChildUpdate("page", page)
                local game = self:GetFrameRef("gamebar")
                if game then game:SetAttribute("actionpage", page) end
            ]])
            RegisterStateDriver(frame, "page", PageConditions())
            frame:HookScript("OnAttributeChanged", function(_, name)
                if name == "state-page" then Mark("all") end
            end)
        end
        return frame
    end

    ---------------------------------------------------------------------------
    -- When each bar is there: the game's Action Bar 2-8 switch, its Show, then what the game
    -- hides it for. Driven securely, so it holds in combat; every bar shows unlocked.
    ---------------------------------------------------------------------------

    local TOGGLE = { bar2 = 1, bar3 = 2, bar4 = 3, bar5 = 4, bar6 = 5, bar7 = 6, bar8 = 7 }
    local TOGGLES = 7
    local ON_BY_DEFAULT = { 1, 2, 3, 4 }       -- bars 2 to 5
    -- The switches are the server's: what we wrote is trusted a while over the client's lagging copy.
    local written, writtenAt = nil, 0
    local TRUST_WRITTEN = 10

    local function On(value) return value and value ~= 0 and true or false end

    local function GameToggles()
        if GetActionBarToggles then return { GetActionBarToggles() } end
    end

    local function Toggles()
        if written and GetTime() - writtenAt < TRUST_WRITTEN then return written end
        written = nil
        return GameToggles()
    end

    local function GameShown(info)
        local toggles = TOGGLE[info.key] and Toggles()
        if not toggles then return true end
        local value = toggles[TOGGLE[info.key]]
        return value == nil or On(value)
    end

    -- Whether the client says Action Bars 2 to 5 are on (Core\Defaults.lua: the server can
    -- hand back the old switches after login).
    function AB.GameBarsAllOn()
        local toggles = GameToggles()
        if not toggles then return true end
        for _, index in ipairs(ON_BY_DEFAULT) do
            if not On(toggles[index]) then return false end
        end
        return true
    end

    -- Action Bars 2 to 5 switched on in the game's options, the others kept; answers whether done.
    function AB.SwitchGameBarsOn()
        if not (SetActionBarToggles and GetActionBarToggles) then return true end
        if InCombatLockdown() then return false end
        local now = Toggles()
        local wanted, changed = {}, false
        for index = 1, TOGGLES do wanted[index] = On(now[index]) end
        for _, index in ipairs(ON_BY_DEFAULT) do
            if not wanted[index] then wanted[index], changed = true, true end
        end
        -- Written again while the client says they are off, whatever we noted as written.
        if not changed and not AB.GameBarsAllOn() then changed = true end
        if changed then
            if not pcall(SetActionBarToggles, unpack(wanted, 1, TOGGLES)) then return false end
            written, writtenAt = wanted, GetTime()
        end
        AB.LayOutAll()
        return true
    end

    -- Once per character (and after Reset everything), only once the saved settings are trusted,
    -- or it would redo every reload.
    function AB.GameBarDefaults()
        local db = AB.db
        if not db or db.gameBarsOn then return true end
        if not (SetActionBarToggles and GetActionBarToggles) then return true end
        if not Core.SettingsTrusted() or InCombatLockdown() or not AB.SwitchGameBarsOn() then return false end
        db.gameBarsOn = true
        return true
    end

    local TryGameBarDefaults = Core.Retry(AB.GameBarDefaults)
    AB.TryGameBarDefaults = TryGameBarDefaults

    local function Visibility(info)
        local db = AB.db
        if not GameShown(info) then return "hide" end
        if db.unlocked then return "show" end
        local show = db[info.key .. "Show"]
        local tail = SHOW_TAIL[show] or "show"
        if info.pet then
            if show == "never" then return "hide" end
            local only = show == "combat" and ",combat" or show == "nocombat" and ",nocombat" or ""
            return "[petbattle] hide; [novehicleui,pet,nooverridebar,nopossessbar" .. only .. "] show; hide"
        end
        if info.stance then
            if GetNumShapeshiftForms() == 0 then return "hide" end
            return "[vehicleui][petbattle] hide; " .. tail
        end
        if info.main then return "[petbattle] hide; " .. tail end
        return "[vehicleui][petbattle][overridebar] hide; " .. tail
    end

    ---------------------------------------------------------------------------
    -- Layout: each the game's button scaled to the size set (its art with it). Out of combat only.
    ---------------------------------------------------------------------------

    local pending = false   -- combat came first: laid out as it ends
    local ready = false     -- the game's bars laid out, to take first places from
    local laidWidth = {}    -- each bar's width as last laid out (Grow)

    -- The stance bar never shows more buttons than stances (at least one while unlocked).
    local function Count(info)
        local db = AB.db
        local count = Clamp(tonumber(db[info.key .. "Buttons"]) or info.count, 1, info.count)
        if info.stance then count = math.min(count, math.max(GetNumShapeshiftForms(), db.unlocked and 1 or 0)) end
        return count
    end

    local function Shape(info)
        local db, key = AB.db, info.key
        local count = Count(info)
        local n = math.max(count, 1)
        local size = Clamp(tonumber(db[key .. "Size"]) or 36, AB.SIZE_MIN, AB.SIZE_MAX)
        local spacing = Clamp(tonumber(db[key .. "Spacing"]) or 2, 0, AB.SPACING_MAX)
        local lines = Clamp(tonumber(db[key .. "Rows"]) or 1, 1, n)
        local vertical = db[key .. "Orientation"] == "vertical"
        local rows, columns
        if vertical then
            rows = math.ceil(n / lines)
            columns = math.ceil(n / rows)
        else
            columns = math.ceil(n / lines)
            rows = math.ceil(n / columns)
        end
        return {
            count = count, size = size, spacing = spacing, rows = rows, columns = columns, vertical = vertical,
            width = columns * size + (columns - 1) * spacing,
            height = rows * size + (rows - 1) * spacing,
        }
    end

    local function LayOut(info)
        local db, key = AB.db, info.key
        local frame, buttons = frames[key], AB.buttons[key]
        local shape = Shape(info)
        local scale = shape.size / BASE
        local step = (shape.size + shape.spacing) / scale
        for index, button in ipairs(buttons) do
            if index <= shape.count then
                -- As the game's grid: horizontal rows fill left to right, added upwards;
                -- vertical columns fill top to bottom, added to the right.
                local column, row
                if shape.vertical then
                    column = math.floor((index - 1) / shape.rows)
                    row = (index - 1) % shape.rows
                else
                    column = (index - 1) % shape.columns
                    row = shape.rows - 1 - math.floor((index - 1) / shape.columns)
                end
                button:SetScale(scale)
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", frame, "TOPLEFT", column * step, -row * step)
                button:SetAttributeNoHandler("statehidden", nil)
                button:Show()
            else
                button:SetAttributeNoHandler("statehidden", true)
                button:Hide()
            end
        end
        frame:SetSize(math.max(1, shape.width), math.max(1, shape.height))
        -- A growing bar's place moved so the edge it grows from stays (its place is its top left).
        local wide = laidWidth[key]
        laidWidth[key] = shape.width
        if info.grow and wide and wide ~= shape.width and db[key .. "Left"] then
            db[key .. "Left"] = db[key .. "Left"] + (wide - shape.width) * (GROW_SHIFT[db[key .. "Grow"]] or 0)
        end
        if db[key .. "Placed"] then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db[key .. "Left"] or 0, db[key .. "Top"] or 0)
        end
        if info.grow then Core.Snap.KeepEdge(entries[key]) end
        RegisterAttributeDriver(frame, "state-visibility", Visibility(info))
    end

    function AB.LayOutAll()
        if InCombatLockdown() then
            pending = true
            return false
        end
        pending = false
        for _, info in ipairs(AB.BARS) do LayOut(info) end
        Core.Menus.ActionButtons.Apply()        -- the buttons' look, then painted
        RefreshAll()
        return true
    end

    ---------------------------------------------------------------------------
    -- A bar's first place: its game bar's (still measurable under the hidden frame), with its
    -- buttons, rows and Show, at our size. Once, and on Reset Position.
    ---------------------------------------------------------------------------

    local function Measure(region)
        if not region then return end
        local ok, left, right, top, bottom = pcall(function()
            return region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
        end)
        if not (ok and left and right and top and bottom) or right <= left or top <= bottom then return end
        local k = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
        return left * k, right * k, top * k, bottom * k
    end

    -- The game's Hidden is not copied: its on/off switch is followed live (GameShown).
    local GAME_SHOW = { InCombat = "combat", OutOfCombat = "nocombat" }

    -- The action bars at 80% of the game's button at Edit Mode's Icon Size; stance and pet 100%.
    local function GameSize(info)
        if info.defaultSize then return info.defaultSize end
        local game = _G[info.game]
        local first = game and game.actionButtons and game.actionButtons[1]
        local width
        if first and info.own then
            local l, r = Measure(first)
            if l then width = r - l end
        end
        -- Stance/pet buttons sit in our scaled bars (measuring would compound): Edit Mode's scale.
        if not width then
            local scale = 1
            local container = first and first.container
            if container then
                local ok, value = pcall(container.GetScale, container)
                if ok and type(value) == "number" and value > 0 then scale = value end
            end
            width = (info.gameBase or BASE) * scale
        end
        return Clamp(math.floor(width * (info.own and SCALE or 1) + 0.5), AB.SIZE_MIN, AB.SIZE_MAX)
    end

    function AB.Seed(info)
        local db, key = AB.db, info.key
        local game = _G[info.game]
        local width, height = GetScreenWidth(), GetScreenHeight()
        if info.shown then
            db[key .. "Buttons"], db[key .. "Rows"], db[key .. "Spacing"] = info.count, SHOWN_ROWS, SHOWN_SPACING
        end
        if game then
            if info.own and not info.shown then
                local count = tonumber(game.numButtonsShowable)
                if count then db[key .. "Buttons"] = Clamp(count, 1, BUTTONS) end
                local rows = tonumber(game.numRows)
                if rows then
                    count = db[key .. "Buttons"]
                    -- A vertical bar of the game's: its rows are columns.
                    if game.isHorizontal == false then rows = math.ceil(count / math.max(1, rows)) end
                    db[key .. "Rows"] = Clamp(rows, 1, count)
                end
            end
            db[key .. "Size"] = GameSize(info)
            if info.own then db[key .. "Show"] = GAME_SHOW[game.visibility] or "always" end
        end
        -- Centred where the game's was; without one, bars 1-3 stacked at the bottom, the rest right.
        local shape = Shape(info)
        local cx, cy
        local l, r, t, b = Measure(game)
        if l then
            cx, cy = (l + r) / 2, (t + b) / 2
        elseif not info.own then
            cx, cy = width / 2, 200 + (info.pet and 40 or 0)
        else
            local n = tonumber(key:match("%d+"))
            if n <= 3 then
                cx, cy = width / 2, 40 + (n - 1) * (shape.height + 6)
            else
                cx, cy = width - 40 - (n - 4) * (shape.width + 6), height / 2
            end
        end
        db[key .. "Left"] = cx - shape.width / 2
        db[key .. "Top"] = (cy + shape.height / 2) - height
        db[key .. "Placed"] = true
    end

    local function SeedAll()
        if InCombatLockdown() then return false end
        local any = false
        for _, info in ipairs(AB.BARS) do
            if not AB.db[info.key .. "Placed"] then
                AB.Seed(info)
                any = true
            end
        end
        return any
    end

    -- Once the game's bars are laid out: first places, and once each the game's button sizes
    -- (GameSize), then the fixed ones (the pet bar's 20).
    function AB.Ready()
        local db = AB.db
        ready = true
        local any = SeedAll()
        if not InCombatLockdown() then
            if not db.sizesRestored then
                for _, info in ipairs(AB.BARS) do db[info.key .. "Size"] = GameSize(info) end
                db.sizesRestored, any = true, true
            end
            if not db.fixedSizes then
                for _, info in ipairs(AB.BARS) do
                    if info.defaultSize then db[info.key .. "Size"] = info.defaultSize end
                end
                db.fixedSizes, any = true, true
            end
        end
        if any then AB.LayOutAll() end
        TryGameBarDefaults()
    end

    local function SavePlace(info)
        local frame = frames[info.key]
        local left, top = frame:GetLeft(), frame:GetTop()
        if not (left and top) then return end
        local k = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local db = AB.db
        db[info.key .. "Left"], db[info.key .. "Top"], db[info.key .. "Placed"] = left * k, top * k - GetScreenHeight(), true
        if not InCombatLockdown() then LayOut(info) end
        Core.RefreshOptions()
    end

    ---------------------------------------------------------------------------
    -- Built now, as the file loads.
    ---------------------------------------------------------------------------

    DisposeGameBars()
    QuietBroadcasters()
    for _, info in ipairs(AB.BARS) do
        entries[info.key] = Core.Snap.Register(NewBar(info), {
            save = function() SavePlace(info) end,
            name = info.label, id = info.id,
            fixedEdge = info.grow and function()
                return FIXED_EDGE[AB.db and AB.db[info.key .. "Grow"]] or FIXED_EDGE.right
            end or nil,
        })
    end

    -- The game's bar 1 gone, its page code would reset to 1: the page keys step from ours (EllesmereUI's).
    local function CurrentPage()
        local page = tonumber(frames.bar1:GetAttribute("state-page"))
        if not page or page < 1 or page > NUM_ACTIONBAR_PAGES then page = C_ActionBar.GetActionBarPage() or 1 end
        return page
    end
    ActionBar_PageUp = function()
        local page = CurrentPage() + 1
        C_ActionBar.SetActionBarPage(page > NUM_ACTIONBAR_PAGES and 1 or page)
    end
    ActionBar_PageDown = function()
        local page = CurrentPage() - 1
        C_ActionBar.SetActionBarPage(page < 1 and NUM_ACTIONBAR_PAGES or page)
    end

    -- One of the game's Action Bar 2-8 switches changed (and once as its settings load).
    EventRegistry:RegisterCallback("ActionBarShownSettingUpdated", function()
        if AB.db then AB.LayOutAll() end
    end, AB)

    for _, event in ipairs({ "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_EXTRA_ACTIONBAR",
                             "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                             "UPDATE_SHAPESHIFT_FORMS" }) do
        pcall(AB.RegisterEvent, AB, event)
    end
    for _, event in ipairs({ "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }) do
        pcall(AB.RegisterUnitEvent, AB, event, "player")
    end
    AB:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            UpdateBroadcasters()
            return
        end
        if event == "PLAYER_REGEN_ENABLED" then
            UpdateBroadcasters()
            if ready and SeedAll() then pending = true end
            if pending then AB.LayOutAll() end
            if ready then TryGameBarDefaults() end
            return
        end
        if event == "PLAYER_ENTERING_WORLD" then
            AB.LayOutAll()
            C_Timer.After(1, AB.Ready)      -- once Edit Mode has laid the game's bars out
        elseif event == "UPDATE_SHAPESHIFT_FORMS" then
            if InCombatLockdown() then pending = true else LayOut(AB.byKey.stance) end
        end
        -- The vehicle bar or extra button shown or gone: a frame later, once it has shown.
        C_Timer.After(0, UpdateBroadcasters)
    end)

    -- What each event repaints.
    local EVENTS = {
        PLAYER_ENTERING_WORLD = "all", UPDATE_BONUS_ACTIONBAR = "all", ACTIONBAR_PAGE_CHANGED = "all",
        UPDATE_VEHICLE_ACTIONBAR = "all", UPDATE_OVERRIDE_ACTIONBAR = "all", SPELLS_CHANGED = "all",
        UPDATE_EXTRA_ACTIONBAR = "all", SPELL_UPDATE_ICON = "all", PLAYER_SPECIALIZATION_CHANGED = "all",
        ACTIONBAR_SLOT_CHANGED = "all", ACTIONBAR_SHOWGRID = "all", ACTIONBAR_HIDEGRID = "all",
        ACTIONBAR_UPDATE_COOLDOWN = "cooldowns", SPELL_UPDATE_COOLDOWN = "cooldowns",
        LOSS_OF_CONTROL_ADDED = "cooldowns", LOSS_OF_CONTROL_UPDATE = "cooldowns",
        SPELL_UPDATE_CHARGES = "counts", BAG_UPDATE_DELAYED = "counts",
        UPDATE_BINDINGS = "hotkeys", GAME_PAD_ACTIVE_CHANGED = "hotkeys",
        UPDATE_SHAPESHIFT_FORMS = "stances", UPDATE_SHAPESHIFT_FORM = "stances",
        UPDATE_SHAPESHIFT_COOLDOWN = "stances", UPDATE_SHAPESHIFT_USABLE = "stances",
        PET_BAR_UPDATE = "pets", PET_BAR_UPDATE_COOLDOWN = "pets", PET_BAR_UPDATE_USABLE = "pets",
        PET_UI_UPDATE = "pets", UNIT_PET = "pets",
    }
    local events = CreateFrame("Frame")
    for event in pairs(EVENTS) do
        -- (The player's pet and spec only.)
        if event == "UNIT_PET" or event == "PLAYER_SPECIALIZATION_CHANGED" then
            pcall(events.RegisterUnitEvent, events, event, "player")
        else
            pcall(events.RegisterEvent, events, event)
        end
    end
    pcall(events.RegisterEvent, events, "CVAR_UPDATE")
    events:SetScript("OnEvent", function(_, event, arg1)
        if event == "CVAR_UPDATE" then
            -- (Its name as the client writes it: compared in any case.)
            if type(arg1) == "string" and arg1:lower() == COUNTDOWN_CVAR:lower() then pcall(PaintCountdowns) end
        elseif event == "ACTIONBAR_SLOT_CHANGED" and arg1 ~= 0 and arg1 ~= nil then
            slots[arg1] = true
            painter:Show()
        else
            if event == "ACTIONBAR_SHOWGRID" or event == "ACTIONBAR_HIDEGRID" then
                dragging = event == "ACTIONBAR_SHOWGRID"
            end
            Mark(EVENTS[event])
        end
    end)

    -- The game's key handlers: bar 1's buttons by number, the others by the game bar they replace.
    local byGameBar = {}
    for _, info in ipairs(AB.BARS) do
        if info.own then byGameBar[info.game] = info.key end
    end
    local function Pressed(key, id)
        local list = key and AB.buttons[key]
        local button = list and list[tonumber(id) or 0]
        if button then ShowPress(button, true) end
    end
    hooksecurefunc("ActionButtonDown", function(id) Pressed("bar1", id) end)
    hooksecurefunc("MultiActionButtonDown", function(barName, id) Pressed(byGameBar[barName], id) end)

    ---------------------------------------------------------------------------
    -- The module.
    ---------------------------------------------------------------------------

    function AB.Normalise(db)
        for key, value in pairs(AB.defaults) do
            if type(value) == "number" and type(db[key]) ~= "number" then db[key] = value end
        end
        for _, info in ipairs(AB.BARS) do
            local key = info.key
            if not SHOW_TAIL[db[key .. "Show"]] then db[key .. "Show"] = "always" end
            if db[key .. "Orientation"] ~= "vertical" then db[key .. "Orientation"] = "horizontal" end
            if info.grow and not FIXED_EDGE[db[key .. "Grow"]] then db[key .. "Grow"] = "right" end
            if info.own and type(db[key .. "ShowEmpty"]) ~= "boolean" then db[key .. "ShowEmpty"] = true end
        end
        -- Once: bars 1-5 that took the game's Never before they were on by default.
        if not db.shownByDefault then
            for _, info in ipairs(AB.BARS) do
                if info.shown and db[info.key .. "Show"] == "never" then db[info.key .. "Show"] = "always" end
            end
            db.shownByDefault = true
        end
        -- Once: bars that took Never from a game bar switched off (the switch is followed live now).
        if not db.gameToggles then
            for key in pairs(TOGGLE) do
                if db[key .. "Show"] == "never" then db[key .. "Show"] = "always" end
            end
            db.gameToggles = true
        end
    end

    -- Reset Position (Core\Snap.lua): the game's bar's place again.
    function AB.ResetPlace(key)
        local info = AB.byKey[key]
        if not info or InCombatLockdown() then return false end
        AB.Seed(info)
        LayOut(info)
        return true
    end

    -- A reset or a profile: a bar left without a place takes its game bar's at once.
    function AB.Refresh()
        if not AB.db then return end
        if not InCombatLockdown() and ready then SeedAll() end
        AB.LayOutAll()
        if ready then TryGameBarDefaults() end
    end
    AB.Init = AB.Refresh

    function AB.Unlock()
        AB.db.unlocked = true
        AB.LayOutAll()
    end

    function AB.Lock()
        AB.db.unlocked = false
        AB.LayOutAll()
    end

    Core:RegisterModule(AB)
end
