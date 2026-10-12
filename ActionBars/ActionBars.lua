-- MODULE: action bars of the addon's own  (DogsForeverUI.ActionBars, settings
-- section "actionbars") - EllesmereUI's way (the player, 2026-10-03: "port all
-- of them like ellesmere" - Ellesmere\EllesmereUIActionBars). Ten bars, each a
-- piece of Unlock Mode like the castbar: moved, snapped, anchored, and set in
-- its menu (Buttons, Rows, Button size, Spacing, Show).
--
--   * ACTION BARS 1 TO 8: secure bars of the addon's own, the buttons its own
--     too (ActionBarButtonTemplate, as the game's): the same action slots as
--     the game's eight bars, so every spell stays where it was. Bar 1 pages
--     as the game's does (forms and stances, stealth, vehicles, possess,
--     the override bar, the page keys), from a secure state driver.
--   * THE STANCE AND PET BARS: the game's own buttons, moved into bars of
--     the addon's own.
--   * THE GAME'S BARS: out of sight for good, and out of its Edit Mode -
--     without a single protected call from the addon's code: the main bar at
--     no opacity and taking no mouse, the others moved under a hidden frame.
--     Their buttons stay where they are, quietly: KEYBINDINGS ARE THE GAME'S
--     OWN, untouched - a key presses the game's (hidden) button, as ever, so
--     press-and-hold and empowered spells work as the game made them. The
--     addon's bar 1 tells the game's which page it is on, so a key fires what
--     its button shows.
--
-- What a button shows - icon, count, cooldowns, hotkey - is painted by the
-- addon (Paint.lua), with the client's secret-safe calls; the game's button
-- code is never run from here.
--
-- Built as the file loads: before the game restores combat on a /reload, so
-- nothing protected is ever touched in combat. Laid out and placed out of
-- combat only (again as combat ends, if it came first).

local AB = CreateFrame("Frame")
DogsForeverUI.ActionBars = AB

do -- private scope
    local Core = DogsForeverUI

    AB.key = "actionbars"
    AB.title = "Action bars"

    -- The bars: the game's action slots for each (its slot numbering), the
    -- binding command its keys are (the game's), the game's bar it stands in
    -- for, and the size of the game's button it is built from.
    AB.BARS = {
        { key = "bar1", label = "Action Bar 1", offset = 0,   command = "ACTIONBUTTON",          game = "MainActionBar", main = true, shown = true },
        { key = "bar2", label = "Action Bar 2", offset = 60,  command = "MULTIACTIONBAR1BUTTON", game = "MultiBarBottomLeft", shown = true },
        { key = "bar3", label = "Action Bar 3", offset = 48,  command = "MULTIACTIONBAR2BUTTON", game = "MultiBarBottomRight", shown = true },
        { key = "bar4", label = "Action Bar 4", offset = 24,  command = "MULTIACTIONBAR3BUTTON", game = "MultiBarRight", shown = true },
        { key = "bar5", label = "Action Bar 5", offset = 36,  command = "MULTIACTIONBAR4BUTTON", game = "MultiBarLeft", shown = true },
        { key = "bar6", label = "Action Bar 6", offset = 144, command = "MULTIACTIONBAR5BUTTON", game = "MultiBar5" },
        { key = "bar7", label = "Action Bar 7", offset = 156, command = "MULTIACTIONBAR6BUTTON", game = "MultiBar6" },
        { key = "bar8", label = "Action Bar 8", offset = 168, command = "MULTIACTIONBAR7BUTTON", game = "MultiBar7" },
        -- (The stance and pet bars' buttons are the game's small ones, 30
        -- across - gameBase - made the action buttons' 45 in the addon's
        -- bars, so the same size draws the same: GameButtonLikeOurs.)
        -- (Its width changes as stances are learnt: it has a Grow - AB.GROW.)
        { key = "stance", label = "Stance Bar", command = "SHAPESHIFTBUTTON", game = "StanceBar",
          stance = true, prefix = "StanceButton", count = 10, gameBase = 30, grow = true },
        -- (The pet bar's buttons 20 by default, whatever the game's: the
        -- player, 2026-10-03.)
        { key = "pet", id = "petbar", label = "Pet Bar", command = "BONUSACTIONBUTTON", game = "PetActionBar",
          pet = true, prefix = "PetActionButton", count = 10, gameBase = 30, defaultSize = 20 },
    }
    local BUTTONS, BASE = 12, 45
    AB.byKey = {}
    for _, bar in ipairs(AB.BARS) do
        bar.count = bar.count or BUTTONS
        bar.base = bar.base or BASE
        -- Its id in Unlock Mode: its key, but the pet bar's "petbar" - "pet"
        -- is the pet's unit frame (two pieces under one id shared one anchor
        -- and one menu: the pet bar hung from the player frame).
        bar.id = bar.id or bar.key
        AB.byKey[bar.key] = bar
    end

    -- Show: when a bar is there (Never keeps its keys working).
    AB.SHOW = {
        { value = "always", label = "Always" },
        { value = "combat", label = "In combat" },
        { value = "nocombat", label = "Out of combat" },
        { value = "never", label = "Never" },
    }
    -- Orientation, as the game's Edit Mode has it (the player, 2026-10-03:
    -- "bring the default action bar orientation setting to our unlock
    -- mode"): Horizontal fills each row left to right and Rows is the rows;
    -- Vertical fills each column top to bottom and the same number is the
    -- columns ("# Rows" / "# Columns" in the game's).
    AB.ORIENTATION = {
        { value = "horizontal", label = "Horizontal" },
        { value = "vertical", label = "Vertical" },
    }
    -- GROW (the player, 2026-10-04: "stance bar should grow left to right by
    -- default and should have an option for it"): which way a bar whose
    -- width changes by itself grows - the edge it keeps where it is, placed
    -- or anchored above or below another (Snap's fixedEdge).
    AB.GROW = {
        { value = "right", label = "Left to right" },
        { value = "left", label = "Right to left" },
        { value = "center", label = "From the middle" },
    }
    local FIXED_EDGE = { right = "LEFT", left = "RIGHT", center = "" }
    local GROW_SHIFT = { right = 0, left = 1, center = 0.5 }   -- of a width change, to the left edge
    AB.SIZE_MIN, AB.SIZE_MAX = 16, 64
    AB.SPACING_MAX = 12

    -- Each bar's own settings, and its place. Until a bar has a place it is
    -- given the game's own bar's (Seed) - where it was, as many buttons, as
    -- many rows, shown as it was - at the addon's size: the game's 80%. But
    -- bars 1 to 5: all twelve buttons, in two rows, 2 apart (the player,
    -- 2026-10-03), whatever the game's had.
    AB.SHOWN_ROWS, AB.SHOWN_SPACING = 2, 2
    AB.defaults = { unlocked = false, shownByDefault = false, sizesRestored = false, fixedSizes = false,
                    gameToggles = false,
                    -- The game's Action Bar 2 ... 5 switches turned on, once
                    -- (GAME SWITCHES ON, below).
                    gameBarsOn = false }
    AB.placement = {}
    for _, bar in ipairs(AB.BARS) do
        local k = bar.key
        AB.defaults[k .. "Buttons"] = bar.count
        AB.defaults[k .. "Rows"] = bar.shown and AB.SHOWN_ROWS or 1
        AB.defaults[k .. "Size"] = bar.defaultSize or bar.gameBase or 36   -- (AB.GameSize)
        AB.defaults[k .. "Spacing"] = 2
        AB.defaults[k .. "Show"] = "always"
        AB.defaults[k .. "Orientation"] = "horizontal"
        -- Always Show Buttons, as the game's Edit Mode has it: an empty slot
        -- shown (its empty square) or not there until something is put in it.
        -- On, as the game's default. (The stance and pet bars have none.)
        if not bar.stance and not bar.pet then AB.defaults[k .. "ShowEmpty"] = true end
        if bar.grow then AB.defaults[k .. "Grow"] = "right" end
        AB.placement[k .. "Placed"] = true
        AB.placement[k .. "Left"] = true
        AB.placement[k .. "Top"] = true
    end
    AB.SCALE = 0.8      -- the game's 80% is the addon's 100% (AB.GameSize)

    ---------------------------------------------------------------------------
    -- THE GAME'S BARS, OUT OF SIGHT (EllesmereUI's file-load disposal: before
    -- the game restores combat, so the few calls that would be protected
    -- later run cleanly now). Never a Hide() on a bar the game shows again:
    -- moved under a frame that is never shown instead, or (the main bar,
    -- which the game's vehicle and pet battle code still needs where it is)
    -- held at no opacity.
    ---------------------------------------------------------------------------

    local hidden = CreateFrame("Frame", "DogsForeverUIHiddenBars", UIParent)
    hidden:SetAllPoints(UIParent)       -- full size: what is under it keeps its place
    hidden:Hide()
    AB.hidden = hidden

    -- A button of the game's out of the way without a protected call: no
    -- events, and hidden by the game's own next pass over it.
    local function QuietButton(button)
        if type(button) ~= "table" then return end
        pcall(button.UnregisterAllEvents, button)
        if button.SetAttributeNoHandler then
            pcall(button.SetAttributeNoHandler, button, "statehidden", true)
        end
    end

    -- The main bar's page arrows, invisible but still clickable over the
    -- addon's buttons: taking no mouse.
    local function NoMouse(frame)
        if type(frame) ~= "table" or type(frame.EnableMouse) ~= "function" then return end
        frame:EnableMouse(false)
        if frame.EnableMouseClicks then frame:EnableMouseClicks(false) end
        if frame.EnableMouseMotion then frame:EnableMouseMotion(false) end
    end
    local function NoPagerMouse(bar)
        local pager = type(bar) == "table" and bar.ActionBarPageNumber
        if type(pager) ~= "table" then return end
        NoMouse(pager)
        NoMouse(pager.UpButton)
        NoMouse(pager.DownButton)
    end

    -- A bar of the game's under the hidden frame again whenever the game
    -- shows it (a talent, a spell that changes the bar), out of combat.
    local function KeepHidden(bar)
        bar:HookScript("OnShow", function(self)
            if not InCombatLockdown() then self:SetParent(hidden) end
        end)
    end

    local function DisposeGameBars()
        for _, info in ipairs(AB.BARS) do
            local bar = _G[info.game]
            if type(bar) == "table" then
                if info.main then
                    -- Kept where it is, its events too (the game's vehicle
                    -- and override bars, and the pet battle UI, go through
                    -- it): no opacity, no mouse, its Edit Mode box gone.
                    if bar.HideBase then pcall(bar.HideBase, bar) end
                    hooksecurefunc(bar, "Show", function(self)
                        self:SetAlpha(0)
                        NoPagerMouse(self)
                    end)
                    NoMouse(bar)
                    NoPagerMouse(bar)
                    if bar.Selection then bar.Selection:SetAlpha(0); NoMouse(bar.Selection) end
                    local caps = bar.EndCaps
                    if type(caps) == "table" then
                        for _, cap in ipairs({ caps.LeftEndCap, caps.RightEndCap }) do
                            if type(cap) == "table" and cap.Selection then
                                cap.Selection:SetAlpha(0)
                                NoMouse(cap.Selection)
                            end
                        end
                    end
                    bar:SetAlpha(0)
                else
                    pcall(bar.UnregisterAllEvents, bar)
                    bar:SetParent(hidden)
                    KeepHidden(bar)
                end
                -- The action buttons only: the stance and pet bars' buttons
                -- are taken into the addon's own bars (below).
                if not info.stance and not info.pet and type(bar.actionButtons) == "table" then
                    for _, button in pairs(bar.actionButtons) do QuietButton(button) end
                end
            end
        end
        if type(ActionBarParent) == "table" then
            pcall(ActionBarParent.Hide, ActionBarParent)
            ActionBarParent:SetParent(hidden)
        end
    end

    ---------------------------------------------------------------------------
    -- THE GAME'S BUTTON BROADCASTERS (EllesmereUI's): every event they would
    -- hand to the game's hidden buttons dropped - but the two that keep those
    -- buttons' slots right for the keys (ACTIONBAR_SLOT_CHANGED and
    -- PLAYER_ENTERING_WORLD), left the game's own. The rest come back only
    -- while the game's vehicle bar or the extra action button shows, and the
    -- cooldowns are not secret.
    ---------------------------------------------------------------------------

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
        local buttons = _G.ActionBarButtonEventsFrame
        if type(buttons) == "table" and buttons.UnregisterEvent then
            for _, event in ipairs(QUIET_EVENTS) do pcall(buttons.UnregisterEvent, buttons, event) end
            for _, event in ipairs(TICK_EVENTS) do pcall(buttons.UnregisterEvent, buttons, event) end
        end
        local actions = _G.ActionBarActionEventsFrame
        if type(actions) == "table" and actions.UnregisterAllEvents then
            pcall(actions.UnregisterAllEvents, actions)
        end
    end

    local broadcasting = false
    local function CooldownsSecret()
        local secrets = _G.C_Secrets
        if type(secrets) ~= "table" or type(secrets.ShouldCooldownsBeSecret) ~= "function" then return false end
        local ok, secret = pcall(secrets.ShouldCooldownsBeSecret)
        return ok and secret and true or false
    end
    local function Shown(name)
        local frame = _G[name]
        return type(frame) == "table" and type(frame.IsShown) == "function" and frame:IsShown() and true or false
    end
    function AB.UpdateBroadcasters()
        local want = (Shown("OverrideActionBarButton1") or Shown("ExtraActionButton1")) and not CooldownsSecret()
        if want == broadcasting then return end
        broadcasting = want
        QuietBroadcasters()
        if not want then return end
        local buttons, actions = _G.ActionBarButtonEventsFrame, _G.ActionBarActionEventsFrame
        if type(buttons) == "table" and buttons.RegisterEvent then
            for _, event in ipairs(TICK_EVENTS) do pcall(buttons.RegisterEvent, buttons, event) end
        end
        if type(actions) == "table" and actions.RegisterUnitEvent then
            for _, event in ipairs(CAST_EVENTS) do pcall(actions.RegisterUnitEvent, actions, event, "player") end
        end
    end

    ---------------------------------------------------------------------------
    -- BAR 1'S PAGES, as the game's bar 1 pages on this client: the override
    -- bar and a vehicle or possession first, the page keys (bar 2-6), every
    -- class's stance or form (page 6 + its offset: WoW Forever pages them
    -- all), skyriding, then page 1 (EllesmereUI's IS_FOREVER conditions).
    ---------------------------------------------------------------------------

    -- (C_ActionBar's: the plain globals exist only with the client's
    -- deprecation fallbacks on.)
    local function Index(name, fallback)
        local fn = C_ActionBar[name]
        if type(fn) == "function" then
            local ok, value = pcall(fn)
            if ok and type(value) == "number" then return value end
        end
        return fallback
    end

    function AB.PageConditions()
        local parts = {
            "[overridebar] " .. Index("GetOverrideBarIndex", 14),
            "[vehicleui][possessbar] " .. Index("GetVehicleBarIndex", 12),
        }
        for page = 2, (NUM_ACTIONBAR_PAGES or 6) do parts[#parts + 1] = "[bar:" .. page .. "] " .. page end
        for form = 1, 4 do parts[#parts + 1] = "[bonusbar:" .. form .. "] " .. (6 + form) end
        parts[#parts + 1] = "[bonusbar:5] 11"
        parts[#parts + 1] = "1"
        return table.concat(parts, "; ")
    end

    -- The page keys move the game's page; with the game's bar 1 gone its own
    -- page code would put it back on 1 after every change, so these say which
    -- page to go to themselves (EllesmereUI's).
    local function ReplacePageKeys()
        local pages = NUM_ACTIONBAR_PAGES or 6
        local function Current()
            local frame = AB.frames.bar1
            local page = frame and tonumber(frame:GetAttribute("state-page"))
            if not page or page < 1 or page > pages then
                page = C_ActionBar.GetActionBarPage() or 1
            end
            return page
        end
        ActionBar_PageUp = function()
            local page = Current() + 1
            C_ActionBar.SetActionBarPage(page > pages and 1 or page)
        end
        ActionBar_PageDown = function()
            local page = Current() - 1
            C_ActionBar.SetActionBarPage(page < 1 and pages or page)
        end
    end

    ---------------------------------------------------------------------------
    -- THE ADDON'S BARS AND BUTTONS.
    ---------------------------------------------------------------------------

    AB.frames = {}          -- bar key -> its secure frame
    AB.buttons = {}         -- bar key -> { button }
    AB.all = {}             -- every action button of the addon's (not stance or pet)
    AB.barOf = {}           -- action button -> its bar's key
    AB.commands = setmetatable({}, { __mode = "k" })   -- button -> its binding command

    -- The events each action button hands to its own (the game's) button
    -- code: what it shows besides the icon, the count and the cooldowns,
    -- which Paint.lua paints. Never the slot or the cooldown events: that
    -- code, run from here, would pass secret cooldowns on tainted.
    local BUTTON_EVENTS = {
        "ACTIONBAR_UPDATE_STATE", "ACTIONBAR_UPDATE_USABLE", "PLAYER_ENTERING_WORLD",
        "UPDATE_SHAPESHIFT_FORM", "SPELL_UPDATE_CHARGES", "UPDATE_INVENTORY_ALERTS",
        "PLAYER_EQUIPMENT_CHANGED", "PLAYER_TARGET_CHANGED",
        "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
        "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
    }

    -- Out of the game's broadcaster's list, in place (never table.remove:
    -- that would move the game's own entries, and taint them).
    local function OffBroadcaster(button)
        local buttons = _G.ActionBarButtonEventsFrame
        local list = type(buttons) == "table" and buttons.frames
        if type(list) ~= "table" then return end
        if list[#list] == button then
            list[#list] = nil
            return
        end
        for key, frame in pairs(list) do
            if frame == button then list[key] = nil end
        end
    end

    -- A MOUSE CLICK ACTS ON ITS RELEASE, A KEY ON ITS PRESS - as on the
    -- game's own buttons: its click code (TriggerSecureClick ->
    -- SecureActionButton_OnClick, "isSecureMousePress") turns "cast on key
    -- down" off for a real mouse press. The addon's buttons take the plain
    -- secure click, which knows no such thing, so with that option on a
    -- mouse PRESS cast - and a Shift-drag to move a spell cast it before the
    -- drag began (the player, 2026-10-03). The game's way back: a mouse
    -- click acts as it is let go (a drag never gets there; an ability held
    -- on the cursor is put down, Shift or not), the wheel's "Keybind" click
    -- (a key) as it is pressed. Set in the secure snippet the bar wraps
    -- round the click, so it holds in combat.
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
        button:SetAttribute("useOnKeyDown", GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") or false)
        if info.main then
            button:SetAttribute("_childupdate-page", PAGE_SNIPPET:format(index))
        end
        button.commandName = info.command .. index
        AB.commands[button] = button.commandName
        AB.all[#AB.all + 1] = button
        return button
    end

    -- One of the game's stance or pet buttons, in the addon's bar.
    local STANCE_EVENTS = {
        "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_FORM", "ACTIONBAR_PAGE_CHANGED",
        "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_COOLDOWN",
    }
    local PET_EVENTS = {
        "PET_BAR_UPDATE", "PET_BAR_UPDATE_COOLDOWN", "PET_BAR_UPDATE_USABLE",
        "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_FARSIGHT_FOCUS_CHANGED",
        "PLAYER_ENTERING_WORLD", "PET_BAR_SHOWGRID", "PET_BAR_HIDEGRID",
    }
    -- A game's small button (stance, pet: SmallActionButtonTemplate, 30
    -- across) made an action button's shape (ActionButtonTemplate, 45): its
    -- size, its key text and count where the action buttons have theirs, its
    -- auto-cast ring the button's size. Scaled to the size set like the rest,
    -- it then draws exactly as they do - border, key text and all (the player,
    -- 2026-10-03: "the stance bar is weirdly different from our hotbars").
    -- Methods only, out of combat; no field of the game's written.
    function AB.GameButtonLikeOurs(button)
        if type(button) ~= "table" or InCombatLockdown() then return end
        button:SetSize(BASE, BASE)
        local hotkey, count, autocast = button.HotKey, button.Count, button.AutoCastOverlay
        if type(hotkey) == "table" and hotkey.SetPoint then
            hotkey:ClearAllPoints()
            hotkey:SetPoint("TOPRIGHT", -5, -5)
        end
        if type(count) == "table" and count.SetPoint then
            count:ClearAllPoints()
            count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 5)
        end
        if type(autocast) == "table" and autocast.SetSize then autocast:SetSize(BASE, BASE) end
    end

    local function TakeGameButton(info, index, frame)
        local button = _G[info.prefix .. index]
        if type(button) ~= "table" then return end
        if button.SetAttributeNoHandler then
            button:SetAttributeNoHandler("statehidden", nil)
        end
        for _, event in ipairs(info.stance and STANCE_EVENTS or PET_EVENTS) do
            pcall(button.RegisterEvent, button, event)
        end
        if info.pet then
            pcall(button.RegisterUnitEvent, button, "UNIT_PET", "player")
            pcall(button.RegisterUnitEvent, button, "UNIT_FLAGS", "pet")
        end
        button:SetParent(frame)
        AB.GameButtonLikeOurs(button)
        -- (Its binding command kept on the addon's side: nothing is written
        -- onto the game's button.)
        AB.commands[button] = info.command .. index
        return button
    end

    local function NewBar(info)
        local frame = CreateFrame("Frame", "DogsForeverUIActionBar" .. (info.key:match("%d+") or info.label:gsub(" ", "")),
            UIParent, "SecureHandlerStateTemplate")
        frame:SetSize(1, 1)
        frame:SetPoint("CENTER")
        if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(false) end
        frame:SetClampedToScreen(true)
        frame.info = info
        AB.frames[info.key] = frame

        local buttons = {}
        for index = 1, info.count do
            local button
            if info.stance or info.pet then
                button = TakeGameButton(info, index, frame)
            else
                button = NewActionButton(info, index, frame)
                AB.barOf[button] = info.key
                -- A mouse click on its release, a key on its press, as on the
                -- game's own buttons (AB.CLICK_SNIPPET, above).
                if type(frame.WrapScript) == "function" then
                    frame:WrapScript(button, "OnClick", AB.CLICK_SNIPPET)
                end
            end
            buttons[index] = button
        end
        AB.buttons[info.key] = buttons

        if info.main then
            -- The page, set from the secure driver: on the addon's buttons
            -- (each takes its slot of that page), and on the game's bar 1,
            -- whose hidden buttons the keys press.
            if type(MainActionBar) == "table" then frame:SetFrameRef("gamebar", MainActionBar) end
            frame:SetAttribute("_onstate-page", [[
                local page = tonumber(newstate) or 1
                self:SetAttribute("actionpage", page)
                self:ChildUpdate("page", page)
                local game = self:GetFrameRef("gamebar")
                if game then game:SetAttribute("actionpage", page) end
            ]])
            RegisterStateDriver(frame, "page", AB.PageConditions())
        end
        -- (Paint.lua repaints what a page change put on the buttons.)
        frame:HookScript("OnAttributeChanged", function(_, name)
            if name == "state-page" and AB.PageChanged then AB.PageChanged() end
        end)
        return frame
    end

    ---------------------------------------------------------------------------
    -- WHEN EACH BAR IS THERE: the player's Show, then what the game hides it
    -- for - every bar in a pet battle; all but bar 1 and the stance bar in a
    -- vehicle; all but bar 1 on the override bar; the pet bar without a pet;
    -- the stance bar with no stances. Driven securely, so it holds in combat.
    -- In Unlock Mode every bar is there, to be placed.
    ---------------------------------------------------------------------------

    local SHOW_TAIL = {
        always = "show", combat = "[combat] show; hide",
        nocombat = "[nocombat] show; hide", never = "hide",
    }

    -- THE GAME'S OWN SWITCHES (Options > Action Bars > Action Bar 2 ... 8, the
    -- player, 2026-10-03: "the game's own action bar configuration should
    -- work with dog ui - if hidden in game it shouldn't show"): a bar the
    -- game has switched off is not there at all - not in Unlock Mode either.
    -- Read with the client's own GetActionBarToggles (bars 2 to 8 in order),
    -- again whenever the game says one changed (ActionBarShownSettingUpdated).
    -- Bar 1, the stance and the pet bars have no such switch.
    local TOGGLE = { bar2 = 1, bar3 = 2, bar4 = 3, bar5 = 4, bar6 = 5, bar7 = 6, bar8 = 7 }
    local TOGGLES = 7
    -- What the addon itself just set, trusted over what the client reads
    -- back for a while: the switches are the server's, and the client's copy
    -- catches up a moment later (the game's own options keep a cache for
    -- exactly this: Blizzard_SettingsDefinitions_Frame\ActionBars.lua).
    local written, writtenAt = nil, 0
    local TRUST_WRITTEN = 10

    local function Toggles()
        if written and GetTime() - writtenAt < TRUST_WRITTEN then return written end
        written = nil
        if type(GetActionBarToggles) ~= "function" then return nil end
        local ok, values = pcall(function() return { GetActionBarToggles() } end)
        return ok and values or nil
    end

    function AB.GameShown(info)
        local index = TOGGLE[info.key]
        if not index then return true end
        local toggles = Toggles()
        if not toggles then return true end
        local value = toggles[index]
        if value == nil then return true end
        return value and value ~= 0 and true or false
    end

    -- GAME SWITCHES ON (the player, 2026-10-03: "when our addon is installed,
    -- make it default for action bars 1-2-3-4-5 to be enabled in blizz
    -- settings"): Action Bar 2 ... 5 switched on in the game's own options,
    -- ONCE per character (the switches are the character's, kept by the
    -- server) - switched off there afterwards, they stay off; Reset
    -- everything switches them on again (the flag goes back with it). Bar 1
    -- has no switch. 6 to 8 are left as they are.
    --
    -- Written with the client's own SetActionBarToggles, all seven at once,
    -- the others as they were - out of combat, and only once the saved
    -- settings are in (Core.SettingsTrusted), or the flag reads "not yet" on
    -- every reload and the player's choice would be undone each time. The
    -- game's options read the switches back live, so they show it. Answers
    -- whether there is nothing left to do.
    local ON_BY_DEFAULT = { 1, 2, 3, 4 }       -- bars 2, 3, 4 and 5

    -- Whether the client itself says Action Bars 2 to 5 are on (never the
    -- addon's own note of what it wrote): Core\GameDefaults.lua checks a
    -- write took - the server can hand back the old switches after login.
    function AB.GameBarsAllOn()
        if type(GetActionBarToggles) ~= "function" then return true end
        local ok, values = pcall(function() return { GetActionBarToggles() } end)
        if not ok then return false end
        for _, index in ipairs(ON_BY_DEFAULT) do
            local value = values[index]
            if not value or value == 0 then return false end
        end
        return true
    end

    -- Action Bars 2 to 5 switched on in the game's options, the others as
    -- they are. Out of combat. Answers whether it was done.
    function AB.SwitchGameBarsOn()
        if type(SetActionBarToggles) ~= "function" or type(GetActionBarToggles) ~= "function" then
            return true
        end
        if InCombatLockdown() then return false end
        local now = Toggles()
        if not now then return false end
        local wanted, changed = {}, false
        for index = 1, TOGGLES do wanted[index] = (now[index] and now[index] ~= 0) and true or false end
        for _, index in ipairs(ON_BY_DEFAULT) do
            if not wanted[index] then wanted[index], changed = true, true end
        end
        -- (Written again when the client says they are off, whatever was
        -- noted as written: that note is what hid the switches not taking.)
        if not changed and not AB.GameBarsAllOn() then changed = true end
        if changed then
            local ok = pcall(SetActionBarToggles, unpack(wanted, 1, TOGGLES))
            if not ok then return false end
            written, writtenAt = wanted, GetTime()
        end
        AB.LayOutAll()
        return true
    end

    function AB.GameBarDefaults()
        local db = AB.db
        if not db or db.gameBarsOn then return true end
        if type(SetActionBarToggles) ~= "function" or type(GetActionBarToggles) ~= "function" then
            return true
        end
        if not Core.SettingsTrusted() or InCombatLockdown() then return false end
        if not AB.SwitchGameBarsOn() then return false end
        db.gameBarsOn = true
        return true
    end

    -- Tried until done: a second after the world is up (AB.Ready), as a
    -- fight ends, after a reset - and, for a character with no saved file
    -- yet, again each half second until the settings can be trusted.
    local TryGameBarDefaults = Core.Retry(AB.GameBarDefaults)
    AB.TryGameBarDefaults = TryGameBarDefaults

    function AB.Visibility(info)
        local db = AB.db
        if not AB.GameShown(info) then return "hide" end
        if db.unlocked then return "show" end
        local show = db[info.key .. "Show"]
        local tail = SHOW_TAIL[show] or "show"
        if info.pet then
            local only = show == "combat" and ",combat" or show == "nocombat" and ",nocombat" or ""
            if show == "never" then return "hide" end
            return "[petbattle] hide; [novehicleui,pet,nooverridebar,nopossessbar" .. only .. "] show; hide"
        end
        if info.stance then
            local forms = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
            if (forms or 0) == 0 then return "hide" end
            return "[vehicleui][petbattle] hide; " .. tail
        end
        if info.main then return "[petbattle] hide; " .. tail end
        return "[vehicleui][petbattle][overridebar] hide; " .. tail
    end

    ---------------------------------------------------------------------------
    -- LAID OUT: its buttons in rows, from its top left, each the size set (the
    -- game's button scaled to it, so all its art scales with it), and the bar
    -- where it was put. Out of combat only.
    ---------------------------------------------------------------------------

    local pending = false   -- combat came first: laid out as it ends
    local laidWidth = {}    -- each bar's width as it was last laid out (Grow)

    -- How many buttons a bar shows: its setting - the stance bar never more
    -- than there are stances (at least one while it is being placed).
    function AB.Count(info)
        local db = AB.db
        local count = math.max(1, math.min(info.count, tonumber(db[info.key .. "Buttons"]) or info.count))
        if info.stance then
            local forms = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
            count = math.min(count, math.max(forms or 0, db.unlocked and 1 or 0))
        end
        return count
    end

    -- Its size, in UIParent's units, as Count, Rows, Size and Spacing make it.
    function AB.Shape(info)
        local db = AB.db
        local count = AB.Count(info)
        local size = math.max(AB.SIZE_MIN, math.min(AB.SIZE_MAX, tonumber(db[info.key .. "Size"]) or 36))
        local spacing = math.max(0, math.min(AB.SPACING_MAX, tonumber(db[info.key .. "Spacing"]) or 2))
        local lines = math.max(1, math.min(math.max(count, 1), tonumber(db[info.key .. "Rows"]) or 1))
        local vertical = db[info.key .. "Orientation"] == "vertical"
        local rows, columns
        if vertical then
            columns = lines
            rows = math.max(1, math.ceil(math.max(count, 1) / columns))
            columns = math.max(1, math.ceil(math.max(count, 1) / rows))
        else
            rows = lines
            columns = math.max(1, math.ceil(math.max(count, 1) / rows))
            rows = math.max(1, math.ceil(math.max(count, 1) / columns))
        end
        return {
            count = count, size = size, spacing = spacing, rows = rows, columns = columns,
            vertical = vertical,
            width = columns * size + (columns - 1) * spacing,
            height = rows * size + (rows - 1) * spacing,
        }
    end

    local function LayOut(info)
        local db = AB.db
        local frame, buttons = AB.frames[info.key], AB.buttons[info.key]
        if not (frame and buttons) then return end
        local shape = AB.Shape(info)
        local scale = shape.size / info.base
        for index, button in ipairs(buttons) do
            if index <= shape.count then
                -- As the game lays its bars out (ActionBarMixin:UpdateGridLayout,
                -- EditModeActionBarSystemMixin:UpdateSystemSettingOrientation):
                -- horizontal, each row left to right and the rows added
                -- upwards - the first button at the bottom left, the second
                -- row over it; vertical, each column top to bottom and the
                -- columns added to the right.
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
                button:SetPoint("TOPLEFT", frame, "TOPLEFT",
                    column * (shape.size + shape.spacing) / scale, -row * (shape.size + shape.spacing) / scale)
                if button.SetAttributeNoHandler then button:SetAttributeNoHandler("statehidden", nil) end
                button:Show()
            else
                if button.SetAttributeNoHandler then button:SetAttributeNoHandler("statehidden", true) end
                button:Hide()
            end
        end
        frame:SetSize(math.max(1, shape.width), math.max(1, shape.height))
        -- A bar that grows one way (Grow) wider or narrower than it was laid
        -- out last: its place moved so the edge it grows from stays where it
        -- is (its place is its top left). Anchored, Snap keeps the same edge.
        local wide = laidWidth[info.key]
        laidWidth[info.key] = shape.width
        if info.grow and wide and wide ~= shape.width and db[info.key .. "Left"] then
            db[info.key .. "Left"] = db[info.key .. "Left"] + (wide - shape.width) * (GROW_SHIFT[db[info.key .. "Grow"]] or 0)
        end
        -- (No place yet - the game's bar not laid out to be measured: left
        -- where it is until it is.)
        if db[info.key .. "Placed"] then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db[info.key .. "Left"] or 0, db[info.key .. "Top"] or 0)
        end
        if info.grow then Core.Snap.KeepEdge(AB.entries[info.key]) end
        RegisterAttributeDriver(frame, "state-visibility", AB.Visibility(info))
    end

    function AB.LayOutAll()
        if InCombatLockdown() then
            pending = true
            return false
        end
        pending = false
        for _, info in ipairs(AB.BARS) do LayOut(info) end
        -- In the action buttons' look (Menus\ActionButtons.lua), then painted.
        local look = Core.Menus and Core.Menus.ActionButtons
        if look and look.Apply then look.Apply() end
        if AB.RefreshAll then AB.RefreshAll() end
        return true
    end

    ---------------------------------------------------------------------------
    -- A BAR'S FIRST PLACE: the game's own bar's - where it is (Edit Mode put
    -- it there before it went out of sight: under the hidden frame its place
    -- is still read), as many buttons, as many rows, shown as it was set to
    -- be, at the addon's size. Once each; Reset Position does it again.
    ---------------------------------------------------------------------------

    local function Measure(region)
        if type(region) ~= "table" or type(region.GetLeft) ~= "function" then return end
        local ok, left, right, top, bottom = pcall(function()
            return region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
        end)
        if not ok or type(left) ~= "number" or type(top) ~= "number" or type(right) ~= "number"
           or type(bottom) ~= "number" or right <= left or top <= bottom then
            return
        end
        local k = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
        return left * k, right * k, top * k, bottom * k
    end

    local GAME_SHOW = { InCombat = "combat", OutOfCombat = "nocombat", Hidden = "never" }

    -- A BAR'S BUTTON SIZE, as the addon forced it on the game's bars before
    -- it had bars of its own (Menus\ActionButtons.lua, 2026-09-27; the
    -- player asked for it back, 2026-10-03): the eight action bars at 80% of
    -- the game's button at Edit Mode's Icon Size, the stance and pet bars at
    -- 100% of it.
    function AB.GameSize(info)
        -- A size of its own (the pet bar's 20): that, whatever the game's.
        if info.defaultSize then return info.defaultSize end
        local game = _G[info.game]
        local first = type(game) == "table" and type(game.actionButtons) == "table" and game.actionButtons[1]
        local width
        -- The game's own action button, still the game's: measured.
        if first and not info.stance and not info.pet then
            local l, r = Measure(first)
            if l then width = r - l end
        end
        -- The stance and pet bars' buttons are in the addon's bars, scaled
        -- by them - measured they would shrink by 80% every time - so: the
        -- game's button at Icon Size, the scale Edit Mode puts on its
        -- container (EditModeActionBarSystemMixin:UpdateSystemSettingIconSize).
        if not width then
            local scale = 1
            local container = first and first.container
            if type(container) == "table" and type(container.GetScale) == "function" then
                local ok, value = pcall(container.GetScale, container)
                if ok and type(value) == "number" and value > 0 then scale = value end
            end
            width = (info.gameBase or info.base) * scale
        end
        local factor = (info.stance or info.pet) and 1 or AB.SCALE
        return math.max(AB.SIZE_MIN, math.min(AB.SIZE_MAX, math.floor(width * factor + 0.5)))
    end

    function AB.Seed(info)
        local db = AB.db
        local key = info.key
        local game = _G[info.game]
        local width, height = GetScreenWidth(), GetScreenHeight()
        if info.shown then
            db[key .. "Buttons"], db[key .. "Rows"], db[key .. "Spacing"] = info.count, AB.SHOWN_ROWS, AB.SHOWN_SPACING
        end
        if type(game) == "table" then
            if not info.stance and not info.pet and not info.shown then
                local count = tonumber(game.numButtonsShowable)
                if count then db[key .. "Buttons"] = math.max(1, math.min(BUTTONS, count)) end
                local rows = tonumber(game.numRows)
                if rows then
                    local count = db[key .. "Buttons"]
                    -- A vertical bar of the game's: its rows are columns.
                    if game.isHorizontal == false then rows = math.ceil(count / math.max(1, rows)) end
                    db[key .. "Rows"] = math.max(1, math.min(count, rows))
                end
            end
            db[key .. "Size"] = AB.GameSize(info)
            if not info.main and not info.stance and not info.pet then
                -- (Whether the game shows the bar at all is its own switch,
                -- followed live - AB.GameShown - not copied into Show.)
                db[key .. "Show"] = GAME_SHOW[game.visibility] or "always"
                if db[key .. "Show"] == "never" then db[key .. "Show"] = "always" end
            elseif info.main then
                db[key .. "Show"] = GAME_SHOW[game.visibility] or "always"
            end
            -- Bars 1 to 5 there from the start, the game's turned off or not
            -- (the player, 2026-10-03: "enabled by default").
            if info.shown and db[key .. "Show"] == "never" then db[key .. "Show"] = "always" end
        end
        -- Centred where the game's was, or (none) bars 1 to 3 stacked over
        -- the bottom of the screen and the rest on the right.
        local shape = AB.Shape(info)
        local cx, cy
        local l, r, t, b = Measure(game)
        if l then
            cx, cy = (l + r) / 2, (t + b) / 2
        else
            local n = tonumber(key:match("%d+")) or 1
            if info.stance or info.pet then
                cx, cy = width / 2, 200 + (info.pet and 40 or 0)
            elseif n <= 3 then
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

    -- The game's bars laid out (a moment after the world is up): any bar
    -- without a place takes its game bar's.
    function AB.Ready()
        AB.ready = true
        local any = SeedAll()
        -- Once: every bar's button size back to the forced one (AB.GameSize)
        -- - the stance and pet bars had taken 80% too, and shrank again with
        -- each new first place.
        if not InCombatLockdown() and not AB.db.sizesRestored then
            for _, info in ipairs(AB.BARS) do AB.db[info.key .. "Size"] = AB.GameSize(info) end
            AB.db.sizesRestored = true
            any = true
        end
        -- Once: a bar with a size of its own (the pet bar's 20) given it.
        if not InCombatLockdown() and not AB.db.fixedSizes then
            for _, info in ipairs(AB.BARS) do
                if info.defaultSize then AB.db[info.key .. "Size"] = info.defaultSize end
            end
            AB.db.fixedSizes = true
            any = true
        end
        if any then AB.LayOutAll() end
        TryGameBarDefaults()
    end

    ---------------------------------------------------------------------------
    -- PLACED IN UNLOCK MODE (Core\Snap.lua): where it was dropped, kept.
    ---------------------------------------------------------------------------

    local function SavePlace(info)
        local frame = AB.frames[info.key]
        local left, top = frame:GetLeft(), frame:GetTop()
        if not (left and top) then return end
        local k = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local db = AB.db
        db[info.key .. "Left"] = left * k
        db[info.key .. "Top"] = top * k - GetScreenHeight()
        db[info.key .. "Placed"] = true
        if not InCombatLockdown() then LayOut(info) end
        Core.RefreshOptions()
    end

    ---------------------------------------------------------------------------
    -- Built now, as the file loads.
    ---------------------------------------------------------------------------

    DisposeGameBars()
    QuietBroadcasters()
    AB.entries = {}         -- each bar's Unlock Mode piece (Core\Snap.lua)
    for _, info in ipairs(AB.BARS) do
        local frame = NewBar(info)
        AB.entries[info.key] = Core.Snap.Register(frame, {
            save = function() SavePlace(info) end,
            name = info.label, id = info.id,
            fixedEdge = info.grow and function()
                return FIXED_EDGE[AB.db and AB.db[info.key .. "Grow"]] or FIXED_EDGE.right
            end or nil,
        })
    end
    ReplacePageKeys()

    -- The vehicle bar or the extra action button shown or gone: the game's
    -- broadcasters back for them, or quiet again (a frame later, when it has
    -- shown). And whatever waited for the end of combat.
    -- One of the game's Action Bar 2 ... 8 switches changed (and once as the
    -- game's settings load): every bar shown or not by it again - in combat,
    -- as the fight ends (LayOutAll keeps it for then).
    if type(EventRegistry) == "table" and type(EventRegistry.RegisterCallback) == "function" then
        EventRegistry:RegisterCallback("ActionBarShownSettingUpdated", function()
            if AB.db then AB.LayOutAll() end
        end, AB)
    end

    for _, event in ipairs({ "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_EXTRA_ACTIONBAR",
                             "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                             "UPDATE_SHAPESHIFT_FORMS" }) do
        pcall(AB.RegisterEvent, AB, event)
    end
    -- (The player's vehicle only: the vehicle bar is the player's.)
    for _, event in ipairs({ "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }) do
        pcall(AB.RegisterUnitEvent, AB, event, "player")
    end
    AB:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            AB.UpdateBroadcasters()
            return
        end
        if event == "PLAYER_REGEN_ENABLED" then
            AB.UpdateBroadcasters()
            if AB.ready and SeedAll() then pending = true end
            if pending then AB.LayOutAll() end
            if AB.ready then TryGameBarDefaults() end
            return
        end
        if event == "PLAYER_ENTERING_WORLD" then
            AB.LayOutAll()
            -- A bar without a place takes its game bar's once Edit Mode has
            -- laid that out - a moment after the world is up.
            if C_Timer and C_Timer.After then C_Timer.After(1, AB.Ready) end
        elseif event == "UPDATE_SHAPESHIFT_FORMS" then
            -- Stances learnt or lost: the stance bar laid out for them.
            local stance = AB.byKey.stance
            if not InCombatLockdown() then LayOut(stance) else pending = true end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0, AB.UpdateBroadcasters) else AB.UpdateBroadcasters() end
    end)

    ---------------------------------------------------------------------------
    -- The module.
    ---------------------------------------------------------------------------

    function AB.Normalise(db)
        for _, info in ipairs(AB.BARS) do
            local key = info.key
            local show = db[key .. "Show"]
            if not SHOW_TAIL[show] then db[key .. "Show"] = "always" end
            if db[key .. "Orientation"] ~= "vertical" then db[key .. "Orientation"] = "horizontal" end
            if info.grow and not FIXED_EDGE[db[key .. "Grow"]] then db[key .. "Grow"] = "right" end
            if AB.defaults[key .. "ShowEmpty"] ~= nil and type(db[key .. "ShowEmpty"]) ~= "boolean" then
                db[key .. "ShowEmpty"] = true
            end
            for _, setting in ipairs({ "Buttons", "Rows", "Size", "Spacing" }) do
                if type(db[key .. setting]) ~= "number" then db[key .. setting] = AB.defaults[key .. setting] end
            end
        end
        -- Once: bars 1 to 5 turned on where they took the game's Never
        -- before they were on by default. Never chosen afterwards stays.
        if not db.shownByDefault then
            for _, info in ipairs(AB.BARS) do
                if info.shown and db[info.key .. "Show"] == "never" then db[info.key .. "Show"] = "always" end
            end
            db.shownByDefault = true
        end
        -- Once: whether the game shows a bar at all is its own switch now,
        -- followed live (AB.GameShown) - a bar that took Never from the game's
        -- hidden bar as it was first placed is on again, or switching it on in
        -- the game's options would still have shown nothing.
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

    -- (A reset or a profile: a bar left without a place takes its game
    -- bar's at once - the game's is laid out by then.)
    function AB.Refresh()
        if not AB.db then return end
        if not InCombatLockdown() and AB.ready then SeedAll() end
        AB.LayOutAll()
        -- (After a reset: the game's switches on again, at once.)
        if AB.ready then TryGameBarDefaults() end
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
