-- What the addon's action buttons show (ActionBars.lua): EllesmereUI's
-- central painter, simply. One frame takes the action bar events and paints
-- every button they concern, with the client's secret-safe calls only - a
-- texture, a count and a cooldown each take a value the addon may not look at
-- (in instances in combat) as it is. The game's own button code is never run
-- from here: run from an addon, it would pass those values on tainted and the
-- client would refuse them.
--
--   * a slot's contents changed (a spell dragged on, a spec changed): that
--     button repainted - icon, count, name, cooldowns, the usable tint;
--   * the cooldowns changed: every shown button's cooldown, charge and
--     loss-of-control swipes, once a frame however many events came;
--   * a page changed (bar 1's forms, stealth, vehicles, the page keys):
--     every button of the bar repainted;
--   * the keys rebound: every hotkey, as the game writes them;
--   * the stance and pet bars: the game's own buttons, painted as the
--     game's own bars would (theirs are gone).
--
-- What else a button shows - checked, usable, range, proc glow, flashing -
-- is its own (the game's) button code's, from its own events.

do -- private scope
    local AB = DogsForeverUI.ActionBars
    local IsSecret = issecretvalue or function() return false end

    -- (C_ActionBar's own calls throughout: the old globals - HasAction,
    -- GetActionTexture and the rest - exist only with the client's
    -- deprecation fallbacks switched on.)
    local function Has(action) return action and C_ActionBar.HasAction(action) and true or false end

    ---------------------------------------------------------------------------
    -- One button.
    ---------------------------------------------------------------------------

    local function ChargeCooldown(button)
        if button.chargeCooldown then return button.chargeCooldown end
        local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cooldown:SetHideCountdownNumbers(true)
        cooldown:SetDrawSwipe(false)
        cooldown:SetDrawEdge(true)
        cooldown:SetAllPoints(button.icon or button)
        button.chargeCooldown = cooldown
        return cooldown
    end

    local function PaintCooldown(button, action)
        local api = C_ActionBar
        local cooldown = button.cooldown
        if not cooldown then return end
        if not Has(action) then
            cooldown:Clear()
            if button.chargeCooldown then button.chargeCooldown:Clear() end
            if button.lossOfControlCooldown then button.lossOfControlCooldown:Clear() end
            return
        end
        local info = api.GetActionCooldown and api.GetActionCooldown(action)
        if info and info.isActive and api.GetActionCooldownDuration and cooldown.SetCooldownFromDurationObject then
            local duration = api.GetActionCooldownDuration(action)
            if duration then cooldown:SetCooldownFromDurationObject(duration) else cooldown:Clear() end
        else
            cooldown:Clear()
        end
        local charges = api.GetActionCharges and api.GetActionCharges(action)
        local max = charges and charges.maxCharges
        if charges and charges.isActive and not IsSecret(max) and type(max) == "number" and max > 1
           and api.GetActionChargeDuration then
            local duration = api.GetActionChargeDuration(action)
            local charge = ChargeCooldown(button)
            if duration then charge:SetCooldownFromDurationObject(duration) else charge:Clear() end
        elseif button.chargeCooldown then
            button.chargeCooldown:Clear()
        end
        local loss = button.lossOfControlCooldown
        if loss then
            local lossInfo = api.GetActionLossOfControlCooldownInfo and api.GetActionLossOfControlCooldownInfo(action)
            if lossInfo and lossInfo.isActive and api.GetActionLossOfControlCooldownDuration then
                local duration = api.GetActionLossOfControlCooldownDuration(action)
                if duration then loss:SetCooldownFromDurationObject(duration) else loss:Clear() end
            else
                loss:Clear()
            end
        end
    end

    local function PaintCount(button, action)
        local count = button.Count
        local api = C_ActionBar
        if not count then return end
        if not (Has(action) and api.GetActionDisplayCount) then
            count:SetText("")
            return
        end
        local text = api.GetActionDisplayCount(action)
        -- (A secret count is set as it is; only a plain nothing is made "".)
        if not IsSecret(text) and text == nil then text = "" end
        count:SetText(text)
    end

    -- THE GAME'S "SHOW NUMBERS FOR COOLDOWNS" (Options > Action Bars,
    -- countdownForCooldowns - the player, 2026-10-06: "Action bars should
    -- respect Blizzard 'Show Numbers for Cooldown' setting"). The game's own
    -- buttons follow it through its broadcaster (ActionButton.lua,
    -- ActionButton_UpdateCooldownNumberHidden); the addon's are off that
    -- (ActionBars.lua), so it is followed here: the same call on the
    -- button's cooldown, as the setting is now. (The charge swipe never
    -- shows numbers, as on the game's.)
    AB.COUNTDOWN_CVAR = "countdownForCooldowns"
    local function CountdownShown()
        if C_CVar and C_CVar.GetCVar then
            local ok, value = pcall(C_CVar.GetCVar, AB.COUNTDOWN_CVAR)
            if ok and value ~= nil then return value == "1" or value == 1 or value == true end
        end
        return GetCVarBool and GetCVarBool(AB.COUNTDOWN_CVAR) and true or false
    end

    local function PaintCountdowns()
        local hide = not CountdownShown()
        for _, button in ipairs(AB.all) do
            local cooldown = button.cooldown
            if cooldown and cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(hide) end
        end
    end
    AB.PaintCountdowns = PaintCountdowns

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

    -- Everything a slot's contents decide (EllesmereUI's ForceButtonRefresh).
    local function PaintButton(button)
        local action = button:GetAttribute("action")
        if not action then return end
        local api = C_ActionBar
        local icon = button.icon or button.Icon
        local filled = Has(action)
        if icon then
            icon:SetTexture(api.GetActionTexture(action))
            icon:SetShown(filled)
            if icon.SetDesaturated then icon:SetDesaturated(false) end
            if filled then pcall(PaintUsable, icon, action) end
        end
        PaintCount(button, action)
        local name = button.Name
        if name and api.UsesActionText then
            if filled and api.UsesActionText(action) then
                name:SetText(api.GetActionText and api.GetActionText(action) or "")
            else
                name:SetText("")
            end
        end
        PaintCooldown(button, action)
        if filled then
            button:SetChecked((api.IsCurrentAction(action) or api.IsAutoRepeatAction(action)) and true or false)
        else
            button:SetChecked(false)
        end
        if button.Border then button.Border:SetShown(filled and api.IsEquippedAction(action) and true or false) end
        AB.PaintEmpty(button, filled)
    end

    -- AN EMPTY SLOT, with its bar's Always Show Buttons off: not there (no
    -- opacity - a secure button cannot be hidden in combat, and the slot
    -- must still take a drop) - but there while an action is being dragged
    -- (the game's ACTIONBAR_SHOWGRID ... HIDEGRID, as its own bars show
    -- their grid) and in Unlock Mode, to be seen as it is placed.
    local dragging = false
    function AB.PaintEmpty(button, filled)
        local key = AB.barOf and AB.barOf[button]
        local db = AB.db
        -- (Nor while keys are being bound: Options\Keybinds.lua.)
        local hide = not filled and key and db and db[key .. "ShowEmpty"] == false
            and not dragging and not db.unlocked and not AB.keybinding
        button:SetAlpha(hide and 0 or 1)
    end

    ---------------------------------------------------------------------------
    -- HOTKEYS: the key bound to the button's command, as the game writes it
    -- (short form); none, the range dot kept for the out-of-range colour.
    --
    -- THE MOUSE WHEEL is a key of the button's too (Options\Keybinds.lua,
    -- the player, 2026-10-03: "assign mouse scrolls as an extra"). The game
    -- will not bind the wheel to an action button's command - those run on
    -- the key's down AND up, and a wheel has no up (its "Can't bind
    -- mousewheel to actions with up and down states") - so a wheel is bound
    -- to a click of the button itself instead: the addon's buttons clicked
    -- with "Keybind" (no mouse button: the shift-drag guard leaves it be,
    -- and the button's own type and action are used), the game's stance and
    -- pet buttons with the left button.
    ---------------------------------------------------------------------------

    AB.CLICK_BUTTON = "Keybind"

    -- The click a wheel is bound to: "CLICK <name>:<button>".
    function AB.ClickOf(button)
        local name = button and button.GetName and button:GetName()
        if not name then return end
        return "CLICK " .. name .. ":" .. (AB.barOf[button] and AB.CLICK_BUTTON or "LeftButton")
    end

    function AB.IsWheel(key) return type(key) == "string" and key:find("MOUSEWHEEL", 1, true) ~= nil end

    -- Every key of the button: its command's, in the game's order, then the
    -- wheels clicking it.
    function AB.KeysOf(button)
        local keys = {}
        local command = AB.commands[button]
        if command then
            local context = C_KeyBindings and C_KeyBindings.GetBindingContextForAction
                and C_KeyBindings.GetBindingContextForAction(command)
            for _, key in ipairs({ GetBindingKey(command, nil, context) }) do keys[#keys + 1] = key end
        end
        local click = AB.ClickOf(button)
        if click then
            for _, key in ipairs({ GetBindingKey(click) }) do keys[#keys + 1] = key end
        end
        return keys
    end

    -- A key as the button writes it: the game's short form, a wheel shorter
    -- still ("WU", "WD"), as EllesmereUI writes them.
    local function Replace(text, find, with)
        if type(find) ~= "string" or find == "" then return text end
        local at = text:find(find, 1, true)
        if not at then return text end
        return text:sub(1, at - 1) .. with .. text:sub(at + #find)
    end
    function AB.KeyText(key)
        local text = GetBindingText and GetBindingText(key, 1) or key or ""
        text = Replace(text, _G.KEY_MOUSEWHEELUP, "WU")
        text = Replace(text, _G.KEY_MOUSEWHEELDOWN, "WD")
        text = Replace(text, "MOUSEWHEELUP", "WU")
        return Replace(text, "MOUSEWHEELDOWN", "WD")
    end

    local function PaintHotkey(button)
        local hotkey = button.HotKey
        local command = AB.commands[button]
        if not (hotkey and command) then return end
        -- A key on the keyboard (or mouse) before a wheel.
        local key
        for _, each in ipairs(AB.KeysOf(button)) do
            if not AB.IsWheel(each) then key = each break end
            key = key or each
        end
        local text = key and AB.KeyText(key) or ""
        if text == "" then
            hotkey:SetText(RANGE_INDICATOR or "")
            hotkey:Hide()
        else
            hotkey:SetText(text)
            hotkey:Show()
        end
    end

    local ALL = AB.all      -- every action button of the addon's (ActionBars.lua, built by now)
    local GAME_BARS = { "stance", "pet" }

    local function PaintHotkeys()
        for _, button in ipairs(ALL) do PaintHotkey(button) end
        for _, key in ipairs(GAME_BARS) do
            for _, button in ipairs(AB.buttons[key] or {}) do PaintHotkey(button) end
        end
    end

    ---------------------------------------------------------------------------
    -- THE GAME'S OWN EXTRA ACTION AND VEHICLE BUTTONS (ExtraActionButton1,
    -- OverrideActionBarButton1-6): their cooldowns come from the game's
    -- button broadcaster, which is quiet while the cooldowns are secret
    -- (ActionBars.lua) - so they were left blank then. Painted here, as
    -- EllesmereUI does (EllesmereUIActionBars.lua, ForceCooldownPaint): the
    -- slot read by GetAttribute (never the button's own field), the cooldown
    -- set from the client's duration object (it takes a secret) - a call on
    -- the game's cooldown frame, nothing written onto it. And the vehicle
    -- buttons' keys (the broadcaster's binding updates are quiet too).
    ---------------------------------------------------------------------------

    local GAME_ACTION_BUTTONS = { "ExtraActionButton1" }
    for index = 1, 6 do GAME_ACTION_BUTTONS[#GAME_ACTION_BUTTONS + 1] = "OverrideActionBarButton" .. index end

    local function PaintGameCooldown(button)
        local api = C_ActionBar
        local cooldown = button.cooldown
        if not (cooldown and api.GetActionCooldown) then return end
        local action = button:GetAttribute("action")
        if not (action and Has(action)) then return end
        local info = api.GetActionCooldown(action)
        local duration = info and info.isActive and api.GetActionCooldownDuration and api.GetActionCooldownDuration(action)
        if duration and cooldown.SetCooldownFromDurationObject then
            cooldown:SetCooldownFromDurationObject(duration)
        else
            cooldown:Clear()
        end
    end

    local function PaintVehicleHotkey(button, index)
        local hotkey = button.HotKey
        if not hotkey then return end
        local key = GetBindingKey("ACTIONBUTTON" .. index)
        if key then
            hotkey:SetText(AB.KeyText(key))
            hotkey:Show()
        end
    end

    local function PaintGameButtons(keys)
        for index, name in ipairs(GAME_ACTION_BUTTONS) do
            local button = _G[name]
            if type(button) == "table" and button.IsShown and button:IsShown() then
                pcall(PaintGameCooldown, button)
                if keys and index > 1 then pcall(PaintVehicleHotkey, button, index - 1) end
            end
        end
    end

    ---------------------------------------------------------------------------
    -- THE STANCE AND PET BARS, painted as the game's own bars paint them
    -- (EllesmereUI's painters): the stance's icon, the one in use checked,
    -- its cooldown; the pet bar by the game's own update out of combat, by
    -- hand in it.
    ---------------------------------------------------------------------------

    local function PaintStances()
        local forms = GetNumShapeshiftForms() or 0
        for index, button in ipairs(AB.buttons.stance or {}) do
            if index <= forms then
                local texture, active, castable = GetShapeshiftFormInfo(index)
                local icon = button.icon or button.Icon
                if icon then
                    icon:SetTexture(texture)
                    icon:SetShown(texture ~= nil)
                    local shade = castable and 1 or 0.4
                    icon:SetVertexColor(shade, shade, shade)
                end
                button:SetChecked(active and true or false)
                if button.cooldown and GetShapeshiftFormCooldown then
                    local start, duration, enable = GetShapeshiftFormCooldown(index)
                    CooldownFrame_Set(button.cooldown, start, duration, enable)
                end
            end
        end
    end

    -- All by hand. NEVER the game's PetActionBar:Update from here: run from
    -- the addon, every value it keeps on the game's pet bar and buttons is
    -- the addon's (tainted), and the game's Edit Mode, showing the pet bar as
    -- it opens, read them - and the rest of its opening was tainted with it:
    -- the party frames' secret health colours could no longer be compared
    -- (CompactUnitFrame.lua: "attempt to compare local 'oldR' (a secret
    -- number value, while execution tainted by 'DogsForeverUI')").
    local function PaintPets()
        local hasBar = PetHasActionBar and PetHasActionBar()
        for index, button in ipairs(AB.buttons.pet or {}) do
            local _, texture, isToken, active, autoCastAllowed, autoCastEnabled = GetPetActionInfo(index)
            local icon = button.icon or button.Icon
            if icon then
                if hasBar and texture then
                    icon:SetTexture(isToken and _G[texture] or texture)
                    local usable = GetPetActionSlotUsable and GetPetActionSlotUsable(index)
                    local shade = usable and 1 or 0.4
                    icon:SetVertexColor(shade, shade, shade)
                    icon:Show()
                else
                    icon:Hide()
                end
            end
            if button.AutoCastOverlay then
                button.AutoCastOverlay:SetShown(hasBar and texture and autoCastAllowed and true or false)
                if button.AutoCastOverlay.ShowAutoCastEnabled then
                    button.AutoCastOverlay:ShowAutoCastEnabled(autoCastEnabled and true or false)
                end
            end
            button:SetChecked(hasBar and active and true or false)
            if button.cooldown and GetPetActionCooldown then
                local start, duration, enable = GetPetActionCooldown(index)
                CooldownFrame_Set(button.cooldown, start, duration, enable)
            end
        end
    end

    ---------------------------------------------------------------------------
    -- ALL OF IT, and what each event repaints - once a frame, whatever came.
    ---------------------------------------------------------------------------

    function AB.RefreshAll()
        for _, button in ipairs(ALL) do pcall(PaintButton, button) end
        pcall(PaintCountdowns)
        PaintHotkeys()
        pcall(PaintStances)
        pcall(PaintPets)
    end

    local dirty = {}        -- what waits for the next frame: "all", "cooldowns", "counts", "hotkeys", "stances", "pets"
    local slots = {}        -- slots whose contents changed
    local painter = CreateFrame("Frame")
    painter:Hide()
    -- (Plain loops, no closure made: the cooldown events come many times a
    -- second in a fight.)
    painter:SetScript("OnUpdate", function(self)
        self:Hide()
        if dirty.all then
            -- (Everything else waiting is in it.)
            dirty.all, dirty.cooldowns, dirty.counts = nil, nil, nil
            dirty.hotkeys, dirty.stances, dirty.pets = nil, nil, nil
            for slot in pairs(slots) do slots[slot] = nil end
            AB.RefreshAll()
            -- (A vehicle entered, the extra button come: theirs, keys too.)
            PaintGameButtons(true)
            return
        end
        local game = false      -- the game's extra and vehicle buttons, once
        if next(slots) then
            for _, button in ipairs(ALL) do
                local action = button:GetAttribute("action")
                if action and slots[action] then pcall(PaintButton, button) end
            end
            for slot in pairs(slots) do slots[slot] = nil end
            game = true
        end
        if dirty.cooldowns then
            dirty.cooldowns = nil
            for _, button in ipairs(ALL) do
                if button:IsVisible() then pcall(PaintCooldown, button, button:GetAttribute("action")) end
            end
            game = true
        end
        if game then PaintGameButtons(false) end
        if dirty.counts then
            dirty.counts = nil
            for _, button in ipairs(ALL) do pcall(PaintCount, button, button:GetAttribute("action")) end
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

    -- A page changed (ActionBars.lua, from the secure driver's attribute).
    function AB.PageChanged() Mark("all") end

    local EVENTS = {
        PLAYER_ENTERING_WORLD = "all", UPDATE_BONUS_ACTIONBAR = "all", ACTIONBAR_PAGE_CHANGED = "all",
        UPDATE_VEHICLE_ACTIONBAR = "all", UPDATE_OVERRIDE_ACTIONBAR = "all", SPELLS_CHANGED = "all",
        UPDATE_EXTRA_ACTIONBAR = "all",
        SPELL_UPDATE_ICON = "all", PLAYER_SPECIALIZATION_CHANGED = "all",
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
        -- (The player's pet and spec only: a group member's are not the bars'.)
        if event == "UNIT_PET" or event == "PLAYER_SPECIALIZATION_CHANGED" then
            pcall(events.RegisterUnitEvent, events, event, "player")
        else
            pcall(events.RegisterEvent, events, event)
        end
    end
    pcall(events.RegisterEvent, events, "ACTIONBAR_SLOT_CHANGED")
    pcall(events.RegisterEvent, events, "ACTIONBAR_SHOWGRID")
    pcall(events.RegisterEvent, events, "ACTIONBAR_HIDEGRID")
    pcall(events.RegisterEvent, events, "CVAR_UPDATE")
    events:SetScript("OnEvent", function(_, event, arg1)
        if event == "CVAR_UPDATE" then
            -- (Its name as the client writes it: compared in any case.)
            if type(arg1) == "string" and arg1:lower() == AB.COUNTDOWN_CVAR:lower() then pcall(PaintCountdowns) end
            return
        end
        if event == "ACTIONBAR_SHOWGRID" or event == "ACTIONBAR_HIDEGRID" then
            dragging = event == "ACTIONBAR_SHOWGRID"
            Mark("all")
            return
        end
        if event == "ACTIONBAR_SLOT_CHANGED" then
            if arg1 == 0 or arg1 == nil then
                Mark("all")
            else
                slots[arg1] = true
                painter:Show()
            end
            return
        end
        Mark(EVENTS[event])
    end)

    ---------------------------------------------------------------------------
    -- A KEY PRESSED, SEEN ON THE BUTTON (the player, 2026-10-03: "when im
    -- pressing a hotkey from keyboard i should be visually see it on our
    -- action bar"). A key presses the game's hidden twin of the button
    -- (ActionBars.lua: the keys stay the game's), so the addon's button never
    -- goes down by itself. EllesmereUI's pushed-state flash
    -- (EllesmereUIActionBars, HookPushedFlash): after the game's own
    -- ActionButtonDown / MultiActionButtonDown (post-hooks - nothing of the
    -- game's replaced or run), the matching button of the addon's shows its
    -- pressed look (the dark wash a mouse press gives it, Menus\
    -- ActionButtons.lua) for as long as one of its keys is held, at least
    -- PRESS_MIN; a wheel clicking it (the "Keybind" click) for PRESS_MIN.
    -- Widget calls only; in combat too.
    ---------------------------------------------------------------------------

    local PRESS_MIN = 0.1
    local held = {}             -- button -> its state, while it shows pressed
    local states = {}           -- button -> { keys = base key names, since = seconds }, kept for its next press
    local holding = 0
    local watcher = CreateFrame("Frame")
    watcher:Hide()

    -- "SHIFT-1" -> "1": IsKeyDown takes the bare key. (The minus key is "-":
    -- "SHIFT--" ends in it.)
    local function BaseKey(key)
        if type(key) ~= "string" then return end
        if key:sub(-1) == "-" then return "-" end
        return key:match("[^%-]+$")
    end

    local function PushedOf(button)
        return button and (button.GetPushedTexture and button:GetPushedTexture() or button.PushedTexture)
    end

    local function Release(button)
        held[button] = nil
        holding = math.max(0, holding - 1)
        local pushed = PushedOf(button)
        -- (Held down by the mouse meanwhile: the game's own state shows it.)
        local state = button.GetButtonState and button:GetButtonState()
        if pushed and state ~= "PUSHED" then pushed:Hide() end
    end

    local function ShowPress(button, fromKey)
        local pushed = PushedOf(button)
        if not (pushed and button:IsVisible()) then return end
        local state = states[button]
        if not state then
            state = { keys = {} }
            states[button] = state
        end
        local keys = state.keys
        for index = #keys, 1, -1 do keys[index] = nil end
        if fromKey then
            for _, key in ipairs(AB.KeysOf(button)) do
                if not AB.IsWheel(key) then keys[#keys + 1] = BaseKey(key) end
            end
        end
        state.since = 0
        pushed:Show()
        if not held[button] then holding = holding + 1 end
        held[button] = state
        watcher:Show()
    end

    watcher:SetScript("OnUpdate", function(self, elapsed)
        for button, state in pairs(held) do
            state.since = state.since + (elapsed or 0)
            local down = false
            if IsKeyDown then
                for _, key in ipairs(state.keys) do
                    if IsKeyDown(key) then
                        down = true
                        break
                    end
                end
            end
            if not down and state.since >= PRESS_MIN then Release(button) end
        end
        if holding <= 0 then
            holding = 0
            self:Hide()
        end
    end)

    -- The game's key handlers: bar 1's buttons by number, the others by the
    -- game's bar they stand in for.
    local byGameBar = {}
    for _, info in ipairs(AB.BARS) do
        if not info.stance and not info.pet then byGameBar[info.game] = info.key end
    end
    local function Button(key, id)
        local list = key and AB.buttons[key]
        return list and list[tonumber(id) or 0]
    end
    if type(ActionButtonDown) == "function" then
        hooksecurefunc("ActionButtonDown", function(id)
            local button = Button("bar1", id)
            if button then ShowPress(button, true) end
        end)
    end
    if type(MultiActionButtonDown) == "function" then
        hooksecurefunc("MultiActionButtonDown", function(barName, id)
            local button = Button(byGameBar[barName], id)
            if button then ShowPress(button, true) end
        end)
    end
    -- A wheel bound to the button clicks it ("Keybind"): a short flash.
    -- (Every button is built as ActionBars.lua loads, before this file.)
    local function OnPreClick(self, mouse)
        if mouse == AB.CLICK_BUTTON then ShowPress(self, false) end
    end
    for _, button in ipairs(ALL) do button:HookScript("PreClick", OnPreClick) end
end
