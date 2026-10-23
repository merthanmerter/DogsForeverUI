-- The addon's own action bars (ActionBars\), EllesmereUI's way: the game's
-- bars out of sight without a protected call, the same action slots on the
-- addon's own buttons, bar 1 paging as the game's, the keys the game's own,
-- each bar a piece of Unlock Mode with its own settings, painted with the
-- client's secret-safe calls.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

LoadAddon()

local Core = DogsForeverUI
local Bars = Core.ActionBars
local Snap = Core.Snap
local extraButton = ExtraActionButton1     -- the game's, as the addon loaded (a later section fakes another)

Section("the game's bars, out of sight as the addon loads")
do
    check("the game's bar 1 kept where it is, at no opacity, taking no mouse",
        MainActionBar.alpha == 0 and MainActionBar.mouse == false and MainActionBar.parent ~= Bars.hidden)
    local leave = MainActionBar.VehicleLeaveButton
    local normal, pushed, highlight = leave:GetNormalTexture(), leave:GetPushedTexture(), leave:GetHighlightTexture()
    check("its Leave Vehicle button still seen", leave.ignoreParentAlpha == true)
    check("an arrow only, whole in its square", normal.atlas == "NPE_ArrowDown" and pushed.atlas == "NPE_ArrowDown"
        and normal.width == 16 and normal.height == 32 and pushed.vertexColor[1] < 1)
    local glow = leave.regions[#leave.regions]
    check("the game's square highlight unseen, an arrow glowing instead", highlight.alpha == 0
        and glow.layer == "HIGHLIGHT" and glow.atlas == "NPE_ArrowDown" and glow.blendMode == "ADD")
    local all = true
    for _, name in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
                            "MultiBar5", "MultiBar6", "MultiBar7" }) do
        all = all and _G[name].parent == Bars.hidden
    end
    check("the other seven under a frame that is never shown - no Hide()", all and Bars.hidden.shown == false
        and #forbiddenCalls == 0)
    check("their buttons left where they are, quiet: the keys still press them",
        MultiBarRight.actionButtons[1].parent ~= Bars.hidden
        and MultiBarRight.actionButtons[1].attributes.statehidden == true)
    local events = ActionBarButtonEventsFrame.events
    check("the game's button broadcaster down to the two that keep its buttons' slots right",
        events.ACTIONBAR_SLOT_CHANGED and events.PLAYER_ENTERING_WORLD and not events.UPDATE_BINDINGS
        and not events.ACTIONBAR_UPDATE_COOLDOWN)
    check("and the action broadcaster quiet", next(ActionBarActionEventsFrame.events) == nil)
end

Section("ten bars of the addon's own, the same action slots")
do
    check("eight action bars, the stance bar and the pet bar", #Bars.BARS == 10)
    local frame = _G.DogsForeverUIActionBar1
    check("each a secure frame of its own", frame and frame.template == "SecureHandlerStateTemplate")
    local b1, b61, b169 = _G.DogsForeverUIActionButton1, _G.DogsForeverUIActionButton61,
        _G.DogsForeverUIActionButton169
    check("its buttons the game's action button, its slots the game's",
        b1 and b1.template:find("ActionBarButtonTemplate") and b1:GetAttribute("action") == 1
        and b61.parent == _G.DogsForeverUIActionBar2 and b169.parent == _G.DogsForeverUIActionBar8
        and b1:GetID() == 0)
    check("off the game's broadcaster: nothing of the game's runs for them from there",
        (function()
            for _, f in pairs(ActionBarButtonEventsFrame.frames) do
                if f == b1 then return false end
            end
            return true
        end)())
    check("their own slot and cooldown events off: painted by the addon",
        not b1.events.ACTIONBAR_SLOT_CHANGED and not b1.events.ACTIONBAR_UPDATE_COOLDOWN
        and b1.events.ACTIONBAR_UPDATE_USABLE and b1.events.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW)
    check("their binding the game's own command", b1.commandName == "ACTIONBUTTON1"
        and b61.commandName == "MULTIACTIONBAR1BUTTON1")
    check("pressed on the key's down or up as the game's are",
        b1.clicks[1] == "AnyDown" and b1.attributes.useOnKeyDown == false)
    check("the stance and pet bars: the game's own buttons, in the addon's bars",
        StanceButton1.parent == _G.DogsForeverUIActionBarStanceBar
        and PetActionButton1.parent == _G.DogsForeverUIActionBarPetBar
        and StanceButton1.attributes.statehidden == nil)
    check("nothing written onto the game's buttons", StanceButton1.commandName == nil
        and Bars.commands[StanceButton1] == "SHAPESHIFTBUTTON1")
end

Section("bar 1 pages as the game's does")
do
    local frame = _G.DogsForeverUIActionBar1
    local driver = stateDriverStrings[frame].page
    check("the vehicle, override and possess bars first",
        driver:find("^%[overridebar%] 14; %[vehicleui%]%[possessbar%] 12") ~= nil, driver)
    check("no retail quest shapeshift page on Forever", driver:find("shapeshift", 1, true) == nil, driver)
    check("then the page keys, every stance or form (6 + its offset), skyriding, then 1",
        driver:find("%[bar:6%] 6") and driver:find("%[bonusbar:1%] 7") and driver:find("%[bonusbar:4%] 10")
        and driver:find("%[bonusbar:5%] 11; 1$"))
    check("the page set on its buttons, and on the game's bar 1 for the keys",
        frame.attributes["_onstate-page"]:find("ChildUpdate") and frame.attributes["_onstate-page"]:find("gamebar")
        and frame:GetFrameRef("gamebar") == MainActionBar)
    check("each button takes its slot of the page",
        _G.DogsForeverUIActionButton5.attributes["_childupdate-page"]
        == "local page = tonumber(message) or 1; self:SetAttribute('action', 5 + (page - 1) * 12)")
    check("the other bars do not page", _G.DogsForeverUIActionButton61.attributes["_childupdate-page"] == nil)
    ActionBar_PageUp()
    ActionBar_PageDown()
    check("the page keys say which page themselves", pages[1] == 2 and pages[2] == 6)
end

Login()
local DB = Bars.db

Section("each bar laid out from its settings")
do
    check("no place before the game's bars are laid out", DB.bar1Placed ~= true)
    Bars.Ready()        -- (a second after the world is up: C_Timer.After(1, Bars.Ready))
    local frame = _G.DogsForeverUIActionBar1
    check("placed once the game's bars are laid out", DB.bar1Placed == true and frame.points[1] == "TOPLEFT")
    -- THE SAME SIZES FOR EVERYONE: never the game's own bars' Icon Size,
    -- which differs between clients and players.
    check("by default: 36 for the action bars, 30 for the stance bar, 20 for the pet bar",
        Bars.defaults.bar1Size == 36 and Bars.defaults.stanceSize == 30 and Bars.defaults.petSize == 20)
    check("laid out at them", DB.bar1Size == 36 and DB.stanceSize == 30 and DB.petSize == 20)
    local stanceButton = StanceBar.actionButtons[1] or StanceButton1
    StanceBar.actionButtons[1] = stanceButton
    stanceButton.container = { GetScale = function() return 1.2 end }   -- Edit Mode's Icon Size: 120%
    local gameButton = MultiBarBottomLeft.actionButtons[1]
    if gameButton then gameButton.left, gameButton.right, gameButton.top, gameButton.bottom = 100, 150, 200, 150 end
    DB.bar2Size, DB.stanceSize, DB.petSize = 50, 50, 33
    Bars.Seed(Bars.byKey.bar2)
    Bars.Seed(Bars.byKey.stance)
    Bars.Seed(Bars.byKey.pet)
    check("a first place (or Reset Position): the default size, whatever the game's buttons",
        DB.bar2Size == 36 and DB.stanceSize == 30 and DB.petSize == 20)
    DB.petSize = 26
    Bars.Ready()
    check("a size chosen afterwards stays", DB.petSize == 26)
    -- The stance and pet bars' buttons (the game's small ones, 30 across)
    -- the action buttons' shape, so the same settings draw the same.
    local hotkey = StanceButton1.HotKey
    check("the stance and pet buttons 45 across, like the action buttons",
        StanceButton1.width == 45 and PetActionButton1.width == 45)
    check("their key text where the action buttons' is",
        not hotkey or (hotkey.points and hotkey.points[1] == "TOPRIGHT"
            and hotkey.points[#hotkey.points - 1] == -5 and hotkey.points[#hotkey.points] == -5))
    DB.petSize, DB.bar2Size = 36, 36
    Bars.LayOutAll()
    check("at the same size, scaled the same as the action buttons",
        math.abs(PetActionButton1.scale - Bars.buttons.bar2[1].scale) < 1e-9)
    DB.petSize = 30
    -- Whether the game shows a bar at all is its own switch, followed live
    -- (below) - never copied into the bar's Show as Never.
    MultiBarRight.shown, MultiBar5.shown = false, false     -- (turned off in the game)
    Bars.Seed(Bars.byKey.bar4)
    Bars.Seed(Bars.byKey.bar6)
    check("a bar the game had hidden: its Show not made Never - the game's switch decides",
        DB.bar4Show == "always" and DB.bar6Show == "always", tostring(DB.bar4Show) .. " " .. tostring(DB.bar6Show))
    check("bars 1 to 5 twelve buttons in two rows, 2 apart, whatever the game's had",
        DB.bar4Buttons == 12 and DB.bar4Rows == 2 and DB.bar4Spacing == 2
        and Bars.defaults.bar1Rows == 2 and Bars.defaults.bar6Rows == 1)
    MultiBarRight.shown, MultiBar5.shown = true, true
    DB.bar6Show = "always"
    local old = { bar2Show = "never", bar7Show = "never" }
    Bars.Normalise(old)
    check("once, on a character from before: the Never the game's hidden bars gave them gone",
        old.bar2Show == "always" and old.bar7Show == "always" and old.gameToggles == true)
    old.bar2Show = "never"
    Bars.Normalise(old)
    check("Never chosen afterwards stays", old.bar2Show == "never")

    -- THE GAME'S OWN SWITCHES (Options > Action Bars > Action Bar 2 ... 8):
    -- a bar switched off there is not there at all - Unlock Mode included -
    -- and comes back as it is switched on, live.
    local toggles = { true, false, true, true, false, false, false }   -- bars 2 ... 8
    GetActionBarToggles = function() return unpack(toggles) end
    DB.bar3Show = "always"
    EventRegistry:TriggerEvent("ActionBarShownSettingUpdated")
    local function Driver(key)
        return attributeDrivers[_G["DogsForeverUIActionBar" .. key:match("%d+")]]["state-visibility"]
    end
    check("switched off in the game: hidden", Driver("bar3") == "hide" and Driver("bar6") == "hide")
    check("switched on: as its own Show has it", Driver("bar2") ~= "hide" and Driver("bar4") ~= "hide")
    check("bar 1 has no switch: always there", Driver("bar1") ~= "hide")
    Core.SetUnlocked(true)
    check("not in Unlock Mode either", Driver("bar3") == "hide" and Driver("bar2") == "show")
    Core.SetUnlocked(false)
    toggles[2] = true
    EventRegistry:TriggerEvent("ActionBarShownSettingUpdated")
    check("switched on in the game: there at once", Driver("bar3") ~= "hide")

    -- GAME SWITCHES ON: Action Bar 2 ... 5 switched on in the game's options,
    -- once per character, and again after Reset everything.
    local sets = {}
    toggles = { false, false, true, false, false, true, false }
    SetActionBarToggles = function(...)
        sets[#sets + 1] = { ... }
        -- (The server's copy comes back a moment later: not yet.)
    end
    local trusted = false
    local realTrusted = Core.SettingsTrusted
    Core.SettingsTrusted = function() return trusted end
    DB.gameBarsOn = false
    check("not before the saved settings are in", Bars.GameBarDefaults() == false and #sets == 0)
    trusted = true
    inCombat = true
    check("not in combat", Bars.GameBarDefaults() == false and #sets == 0)
    inCombat = false
    Bars.GameBarDefaults()
    local set = sets[1]
    check("2, 3, 4 and 5 switched on, 6 to 8 left as they were, all seven at once",
        #sets == 1 and #set == 7 and set[1] and set[2] and set[3] and set[4]
        and set[5] == false and set[6] == true and set[7] == false)
    check("done once for the character", DB.gameBarsOn == true)
    check("the bars there at once, before the client's copy catches up",
        Driver("bar2") ~= "hide" and Driver("bar5") ~= "hide" and Driver("bar6") == "hide")
    now = now + 11
    toggles = { true, false, true, true, false, true, false }    -- bar 3 switched off in the game
    Bars.LayOutAll()
    Bars.GameBarDefaults()
    check("switched off in the game afterwards: stays off", #sets == 1 and Driver("bar3") == "hide")
    DB.gameBarsOn = false        -- (what Reset everything does to the flag)
    Bars.TryGameBarDefaults()
    check("reset: switched on again", #sets == 2 and sets[2][2] == true and DB.gameBarsOn == true)
    now = now + 11
    toggles = { true, true, true, true, false, true, false }
    Core.SettingsTrusted = realTrusted
    SetActionBarToggles = nil
    GetActionBarToggles = nil
    Bars.LayOutAll()
    DB.bar2Buttons, DB.bar2Rows, DB.bar2Size, DB.bar2Spacing = 6, 2, 40, 4
    Bars.Refresh()
    local bar2 = _G.DogsForeverUIActionBar2
    check("six buttons in two rows of three: the bar their size",
        bar2.width == 3 * 40 + 2 * 4 and bar2.height == 2 * 40 + 4)
    local b = Bars.buttons.bar2
    check("each the game's button scaled to the size, its art with it",
        math.abs(b[1].scale - 40 / 45) < 1e-9 and b[4].points[1] == "TOPLEFT"
        and math.abs(b[4].points[5] * b[4].scale) < 1e-9 and b[4].points[4] == 0)
    check("as the game's bars: the first row at the bottom, the second over it (1 under 4)",
        math.abs(b[1].points[5] * b[1].scale - -44) < 1e-9 and b[1].points[4] == 0)
    check("the rest hidden", b[7].shown == false and b[7].attributes.statehidden == true
        and b[6].shown ~= false)
    DB.bar2Show = "combat"
    Bars.Refresh()
    check("Show In combat: driven securely, the vehicle and override bar hiding it too",
        attributeDrivers[bar2]["state-visibility"] == "[vehicleui][petbattle][overridebar] hide; [combat] show; hide")
    check("bar 1 stays for vehicles (it pages to them)",
        attributeDrivers[frame]["state-visibility"] == "[petbattle] hide; show")
    check("the pet bar only with a pet",
        attributeDrivers[_G.DogsForeverUIActionBarPetBar]["state-visibility"]
        == "[petbattle] hide; [novehicleui,pet,nooverridebar,nopossessbar] show; hide")
    check("the stance bar not without stances",
        attributeDrivers[_G.DogsForeverUIActionBarStanceBar]["state-visibility"] == "hide")
    DB.bar2Show = "never"
    Bars.Refresh()
    check("Never: hidden - its keys still the game's", attributeDrivers[bar2]["state-visibility"]
        == "[vehicleui][petbattle][overridebar] hide; hide")
    DB.bar2Show = "always"
    inCombat = true
    DB.bar2Size = 30
    check("never laid out in combat", Bars.LayOutAll() == false and math.abs(b[1].scale - 40 / 45) < 1e-9)
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    check("but as it ends", math.abs(b[1].scale - 30 / 45) < 1e-9)
end

Section("a piece of Unlock Mode")
do
    local entry = Snap.EntryById("bar3")
    check("every bar registered, named", entry and entry.opts.name == "Action Bar 3"
        and Snap.EntryById("stance") and Snap.EntryById("pet"))
    Core.SetUnlocked(true)
    check("unlocked, every bar there to be placed - the stance bar too",
        attributeDrivers[_G.DogsForeverUIActionBarStanceBar]["state-visibility"] == "show"
        and attributeDrivers[_G.DogsForeverUIActionBar3]["state-visibility"] == "show")
    local frame = entry.frame
    frame.left, frame.top = 300, 200
    entry.opts.save()
    check("dropped: its place kept", DB.bar3Left == 300 and DB.bar3Top == 200 - 1080 and DB.bar3Placed == true)
    -- (Then put in its place in the addon's own layout: tests\places.lua.)
    local place = Core.DefaultPlaces.Place
    Core.DefaultPlaces.Place = function() return false end
    Snap.ResetPlace(entry)
    Core.DefaultPlaces.Place = place
    check("Reset Position: the game's bar's place again", DB.bar3Placed == true and DB.bar3Left ~= 300)
    Core.RevertEditMode()
    Core.SetUnlocked(false)
    check("locked: its Show again", attributeDrivers[_G.DogsForeverUIActionBar3]["state-visibility"]
        ~= "show")
end

Section("painted with the client's secret-safe calls")
do
    local cooldowns = {}
    C_ActionBar = {
        HasAction = function(slot) return actionSlots[slot] ~= nil end,
        GetActionTexture = function(slot) return actionSlots[slot] and actionSlots[slot].texture end,
        IsCurrentAction = function() return false end,
        IsAutoRepeatAction = function() return false end,
        IsEquippedAction = function() return false end,
        GetActionCooldown = function(slot) return { isActive = cooldowns[slot] ~= nil } end,
        GetActionCooldownDuration = function(slot) return cooldowns[slot] end,
        GetActionCharges = function(slot) return actionSlots[slot] and actionSlots[slot].charges end,
        GetActionChargeDuration = function() return nil end,
        GetActionLossOfControlCooldownInfo = function() return nil end,
        GetActionLossOfControlCooldownDuration = function() return nil end,
        GetActionDisplayCount = function(slot) return actionSlots[slot] and actionSlots[slot].count end,
        UsesActionText = function() return false end,
        GetActionText = function() return nil end,
        IsUsableAction = function(slot) return actionSlots[slot] ~= nil, false end,
    }
    local button = _G.DogsForeverUIActionButton2
    actionSlots[2] = { texture = 135274, count = "5" }
    cooldowns[2] = { duration = "secret" }
    Fire("ACTIONBAR_SLOT_CHANGED", 2)
    Tick(0)
    check("a slot changed: its icon, its count", button.icon.texture == 135274 and button.icon.shown ~= false
        and button.Count.text == "5")
    -- (The player, 2026-10-21, Midnight: a proc glow errored on "AssistedCombatRotationFrame
    -- (a nil value)"; a rotation frame made for our button then refreshed it tainted - and a
    -- stand-in field tainted every page change: "secret values only allowed ...", by the hundred.)
    check("no rotation frame of ours on the button, nothing the game's refresh would read",
        rawget(button, "AssistedCombatRotationFrame") == nil)
    local wasAssisted = C_ActionBar.IsAssistedCombatAction
    C_ActionBar.IsAssistedCombatAction = function(slot) return slot == 2 end
    Fire("ACTIONBAR_SLOT_CHANGED", 2)
    Tick(0)
    check("holding the one-button rotation action: no proc glow events (the game would error)",
        not button.events.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW and not button.events.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE)
    C_ActionBar.IsAssistedCombatAction = wasAssisted
    Fire("ACTIONBAR_SLOT_CHANGED", 2)
    Tick(0)
    check("an ordinary spell there again: its glow events back", button.events.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW
        and button.events.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE)
    check("its cooldown from the client's duration object", button.cooldown.durationObject == cooldowns[2])
    cooldowns[2] = nil
    Fire("ACTIONBAR_UPDATE_COOLDOWN")
    Fire("SPELL_UPDATE_COOLDOWN")
    Tick(0)
    check("the cooldowns changed: cleared, once a frame", button.cooldown.durationObject == nil)
    -- (The player, 2026-10-20: a full stack's count went missing.)
    actionSlots[2].count = "2"
    Fire("ACTIONBAR_UPDATE_COOLDOWN")
    Tick(0)
    check("a charge back - a full stack - comes as a cooldown: its count with it", button.Count.text == "2")
    actionSlots[2].count = "3"
    Fire("SPELL_UPDATE_USES", 123)
    Tick(0)
    check("a use count's own event too", button.Count.text == "3")
    -- (Live retail gives no display count for a spell's charges once all are back.)
    actionSlots[2].count = ""
    actionSlots[2].charges = { currentCharges = 2, maxCharges = 2, isActive = false }
    Fire("SPELL_UPDATE_CHARGES")
    Tick(0)
    check("all charges back, the client's count empty: the charges shown", button.Count.text == 2)
    actionSlots[2].charges = { currentCharges = 1, maxCharges = 1, isActive = false }
    Fire("SPELL_UPDATE_CHARGES")
    Tick(0)
    check("a spell of one charge: nothing", button.Count.text == "")
    actionSlots[2].charges = nil
    actionSlots[2] = nil
    Fire("ACTIONBAR_SLOT_CHANGED", 2)
    Tick(0)
    check("emptied: no icon, no count", button.icon.shown == false and button.Count.text == "")

    -- The game's own extra action and vehicle buttons: their broadcaster is
    -- quiet while cooldowns are secret, so painted here (EllesmereUI's
    -- ForceCooldownPaint) - the slot by GetAttribute, the duration object.
    local function GameButton(name, slot)
        local b = CreateFrame("Button", name, UIParent)
        b.cooldown = CreateFrame("Cooldown", nil, b)
        b.HotKey = b:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmallGray")
        b.Count = b:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
        b:SetAttribute("action", slot)
        return b
    end
    local extra = GameButton("ExtraActionButton1", 169)
    local vehicle = GameButton("OverrideActionBarButton1", 133)
    actionSlots[169], actionSlots[133] = { texture = 1 }, { texture = 2 }
    cooldowns[169], cooldowns[133] = { duration = "extra" }, { duration = "vehicle" }
    bindings.ACTIONBUTTON1 = "1"
    Fire("UPDATE_VEHICLE_ACTIONBAR")
    Tick(0)
    check("the extra action button's cooldown painted from its slot's duration object",
        extra.cooldown.durationObject == cooldowns[169])
    check("a vehicle button's too, and its key", vehicle.cooldown.durationObject == cooldowns[133]
        and vehicle.HotKey.text == "1")
    cooldowns[169] = nil
    Fire("ACTIONBAR_UPDATE_COOLDOWN")
    Tick(0)
    check("its cooldown over: cleared", extra.cooldown.durationObject == nil)
    check("nothing written onto the game's buttons", rawget(extra, "chargeCooldown") == nil)
    extra:Hide()
    vehicle:Hide()
    actionSlots[169], actionSlots[133], cooldowns[133] = nil, nil, nil

    bindings.ACTIONBUTTON2 = "2"
    Fire("UPDATE_BINDINGS")
    Tick(0)
    check("the keys rebound: its hotkey, as the game writes it", button.HotKey.text == "2"
        and button.HotKey.shown ~= false)
    bindings.SHAPESHIFTBUTTON1 = "Q"
    Fire("UPDATE_BINDINGS")
    Tick(0)
    check("on the stance bar's too", StanceButton1.HotKey == nil or StanceButton1.HotKey.text == "Q")

    shapeshiftForms[1] = { texture = 132115, active = true }
    Fire("UPDATE_SHAPESHIFT_FORMS")
    Tick(0)
    check("a stance learnt: its icon, checked while in it, the bar laid out for it",
        StanceButton1.icon.texture == 132115 and StanceButton1.checked == true
        and attributeDrivers[_G.DogsForeverUIActionBarStanceBar]["state-visibility"] == "[vehicleui][petbattle] hide; show")
    petActions[1] = { name = "Attack", texture = 132152 }
    local before = petBarUpdates
    Fire("PET_BAR_UPDATE")
    Tick(0)
    -- By hand: the game's PetActionBar:Update run from the addon tainted the
    -- game's Edit Mode as it opened (ActionBars.lua, PaintPets).
    check("the pet bar painted by hand - never the game's own update",
        petBarUpdates == before and PetActionButton1.icon.texture == 132152)
end

Section("the stance bar grows one way as stances are learnt (Grow)")
do
    local frame = _G.DogsForeverUIActionBarStanceBar
    check("left to right by default", Bars.defaults.stanceGrow == "right" and DB.stanceGrow == "right")
    DB.stanceRows = 1
    Bars.LayOutAll()
    local left, width = DB.stanceLeft, frame.width
    shapeshiftForms[2] = { texture = 132116 }
    Fire("UPDATE_SHAPESHIFT_FORMS")
    check("a stance learnt: wider, its left edge where it was", frame.width > width and DB.stanceLeft == left,
        tostring(DB.stanceLeft) .. " " .. tostring(left))
    DB.stanceGrow = "left"
    left, width = DB.stanceLeft, frame.width
    shapeshiftForms[3] = { texture = 132117 }
    Fire("UPDATE_SHAPESHIFT_FORMS")
    check("right to left: its right edge where it was",
        frame.width > width and math.abs(DB.stanceLeft + frame.width - (left + width)) < 1e-6)
    DB.stanceGrow = "center"
    left, width = DB.stanceLeft, frame.width
    shapeshiftForms[3] = nil
    Fire("UPDATE_SHAPESHIFT_FORMS")
    check("from the middle: its middle where it was",
        frame.width < width and math.abs(DB.stanceLeft + frame.width / 2 - (left + width / 2)) < 1e-6)

    -- Anchored on top of Action Bar 1 (by default): hung by the edge it
    -- grows from, not its middle, so the anchor keeps that edge too.
    local entry, bar1 = Snap.EntryById("stance"), Snap.EntryById("bar1")
    bar1.frame.left, bar1.frame.right, bar1.frame.top, bar1.frame.bottom = 800, 1100, 200, 150
    frame.left, frame.right, frame.top, frame.bottom = 800, 860, 230, 205
    if not Snap.LinkOf(entry) then Snap.AnchorHere(entry, bar1) end
    DB.stanceGrow = "right"
    Bars.LayOutAll()
    local link = Snap.LinkOf(entry)
    check("anchored, left to right: hung by its left edge", link and link.point:find("LEFT$") ~= nil
        and link.rel:find("LEFT$") ~= nil, link and link.point)
    DB.stanceGrow = "left"
    Bars.LayOutAll()
    check("right to left: by its right edge", link and Snap.LinkOf(entry).point:find("RIGHT$") ~= nil)
    DB.stanceGrow = "center"
    Bars.LayOutAll()
    check("from the middle: by its middle, as other pieces",
        link and (Snap.LinkOf(entry).point == "BOTTOM" or Snap.LinkOf(entry).point == "TOP"))
    DB.stanceGrow = "right"
    Bars.LayOutAll()
    shapeshiftForms[2] = nil
    Fire("UPDATE_SHAPESHIFT_FORMS")
end

Section("the minimap, the chat and the extra action button: pieces of Unlock Mode too")
do
    local Game = Core.GameFrames
    -- (The minimap and the chat are the game's frames modelled in their own
    -- tests: minimap.lua, chat.lua. Here, the extra action button.)
    local entry = Snap.EntryById("extra")
    check("the extra action button a piece, named", entry and entry.opts.name == "Extra Action Button")
    local holder = Game.places.extra
    -- (No field written onto it: those tainted the game's Edit Mode.)
    -- (The player, 2026-10-20: "same size as the hotbars", after larger, smaller
    -- and round tries.) In a frame of the addon's scaled to Action Bar 1's
    -- buttons, the game's own scale (its Edit Mode's size) left on it and undone.
    local scaler = ExtraAbilityContainer.parentFrame
    local onScreen = Bars.ButtonSize("bar1") / 52
    check("the game's container moved into a holder of the addon's, no field of it written",
        scaler ~= nil and scaler.parent == holder and ExtraAbilityContainer.ignoreFramePositionManager == nil
        and ExtraAbilityContainer.ignoreInLayout == nil)
    check("Action Bar 1's buttons' size, the game's own scale untouched",
        math.abs(scaler.scale - onScreen) < 1e-9 and ExtraAbilityContainer:GetScale() == 1
        and math.abs(holder.width - 64 * onScreen) < 1e-9)
    DB.bar1Size = 44
    Bars.LayOutAll()
    check("Action Bar 1 resized: the button with it", math.abs(scaler.scale - 44 / 52) < 1e-9)
    -- (The player, 2026-10-20, after the game's frame, the hotbars' and a round
    -- one: "make it square again ... bordered like our frames ... add the
    -- effect behind it back".)
    local icon, border = extraButton.icon, nil
    for _, child in ipairs({ extraButton:GetChildren() }) do
        if child.spec == Core.Style.DEFAULT_BORDER then border = child end
    end
    check("square in our frames' border: the icon whole and cropped, the game's mask off",
        border ~= nil and icon.mask == nil and icon.texCoord and icon.texCoord[1] == 0.08)
    -- (The player: "when hovered the hover is square??" - the game's is a rim.)
    local hover, press = extraButton.HighlightTexture, extraButton.PushedTexture
    check("its hover and press the hotbars' flat washes",
        hover.texture == Core.Style.FLAT_TEXTURE and press.texture == Core.Style.FLAT_TEXTURE)
    check("the game's skin art (its effects) behind the button: on the bar under it, shown",
        extraButton.style.parent == ExtraActionBarFrame and extraButton.style.alpha ~= 0)
    check("its key and count over the icon", extraButton.HotKey.layer == "OVERLAY"
        and extraButton.Count.layer == "OVERLAY")
    DB.bar1Size = 36
    Bars.LayOutAll()
    check("and out of the game's Edit Mode", ExtraAbilityContainer.isLocked == nil
        and Core.IsHeld(ExtraAbilityContainer))
    ExtraAbilityContainer:SetParent(UIParent)
    check("taken back by the game: put in its holder again", ExtraAbilityContainer.parentFrame == scaler)
    Game.Ready()
    check("its first place, on Action Bar 1's bottom edge", Game.db.extraPlaced == true
        and holder.points[1] == "TOPLEFT")
end

Section("the bars' settings in their Unlock Mode menu")
do
    Core.SetUnlocked(true)
    local entry = Snap.EntryById("bar2")
    Snap.OpenCog(entry, Snap.movers[entry])
    local menu = Core.Options.Unlock.menu
    local labels = {}
    for index, row in ipairs(menu.block.rows) do labels[index] = row.label.text end
    check("Buttons, Orientation, Rows, Button size, Spacing, Show, Always show buttons, Auto-hide",
        table.concat(labels, ",") == "Buttons,Orientation,Rows,Button size,Spacing,Show,Always show buttons,Auto-hide",
        table.concat(labels, ","))
    -- A size typed for an exact number (the player, 2026-10-03: "the sizes
    -- also should have inputs for precise editing").
    local size = menu.block.rows[4].control
    local input = size.input
    check("Button size: its value a box to type into", input ~= nil and input.text == tostring(DB.bar2Size),
        input and input.text)
    input:SetText("41")
    input.scripts.OnEnterPressed(input)
    check("a number typed and Enter: the size", DB.bar2Size == 41 and input.text == "41", tostring(DB.bar2Size))
    input:SetText("999")
    input.scripts.OnEnterPressed(input)
    check("too big: the largest there is", DB.bar2Size == Bars.SIZE_MAX)
    input:SetText("abc")
    input.scripts.OnEnterPressed(input)
    check("not a number: nothing changed, shown again", DB.bar2Size == Bars.SIZE_MAX
        and input.text == tostring(Bars.SIZE_MAX))
    input:SetText("30")
    input.scripts.OnEscapePressed(input)
    check("Esc: the old one back", DB.bar2Size == Bars.SIZE_MAX and input.text == tostring(Bars.SIZE_MAX))
    DB.bar2Size = 36
    Bars.LayOutAll()
    menu:Hide()

    -- Vertical: the same number is the columns, each filled top to bottom.
    DB.bar2Buttons, DB.bar2Rows, DB.bar2Size, DB.bar2Spacing = 6, 2, 40, 4
    DB.bar2Orientation = "vertical"
    Bars.LayOutAll()
    local bar2 = _G.DogsForeverUIActionBar2
    check("vertical, 2: two columns of three", bar2.width == 2 * 40 + 4 and bar2.height == 3 * 40 + 2 * 4)
    local second, fourth = Bars.buttons.bar2[2], Bars.buttons.bar2[4]
    check("filled top to bottom first", second.points[4] == 0 and second.points[5] < 0
        and fourth.points[4] > 0 and fourth.points[5] == 0)
    Snap.OpenCog(entry, Snap.movers[entry])
    check("its menu says Columns", menu.block.rows[3].label.text == "Columns")
    menu:Hide()
    DB.bar2Orientation = "horizontal"
    Bars.LayOutAll()
    Core.SetUnlocked(false)

    -- Always Show Buttons off: an empty slot not there, a filled one is.
    local empty, filled = Bars.buttons.bar2[1], Bars.buttons.bar2[2]
    hasAction = hasAction or {}
    DB.bar2ShowEmpty = false
    Bars.PaintEmpty(empty, false)
    Bars.PaintEmpty(filled, true)
    check("Always show buttons off: an empty slot at no opacity, a filled one there",
        empty.alpha == 0 and filled.alpha == 1)
    Fire("ACTIONBAR_SHOWGRID")
    Bars.PaintEmpty(empty, false)
    check("while an action is dragged, the empty slots are there to drop on", empty.alpha == 1)
    Fire("ACTIONBAR_HIDEGRID")
    Bars.PaintEmpty(empty, false)
    check("and gone again after", empty.alpha == 0)
    DB.bar2ShowEmpty = true
    Bars.PaintEmpty(empty, false)
    check("on (the game's default): every slot there", empty.alpha == 1)

    -- A MOUSE CLICK ON ITS RELEASE, A KEY ON ITS PRESS, as on the game's own
    -- buttons (the player, 2026-10-03: Shift-moving cast spells; then, with
    -- a guard against that, an ability in hand could not be put down with
    -- Shift held). The snippet the bar wraps round each click, run as the
    -- secure environment runs it.
    local button = Bars.buttons.bar1[1]
    local snippet = _G.DogsForeverUIActionBar1.wrapped[button].OnClick
    check("one snippet, passing the game's own checks: no function keyword, no table braces",
        snippet == Bars.CLICK_SNIPPET and not snippet:match("function") and not snippet:match("[{}]"))
    local attributes = {}
    local handle = {
        SetAttribute = function(_, name, value) attributes[name] = value end,
        GetAttribute = function(_, name) return attributes[name] end,
    }
    local function Run(mouse, down)
        local chunk = assert(load("local self, button, down = ...\n" .. snippet, "click", "t", {}))
        return chunk(handle, mouse, down)
    end
    check("a mouse click: never stopped - it acts as it is let go (a drag never gets there)",
        Run("LeftButton", true) ~= false and attributes.useOnKeyDown == false)
    check("the right button too", Run("RightButton", true) ~= false and attributes.useOnKeyDown == false)
    check("a wheel bound to the button (a key): acts as it is pressed",
        Run("Keybind", true) ~= false and attributes.useOnKeyDown == true)
    check("nothing else wrapped round the button: no drag or drop guard",
        _G.DogsForeverUIActionBar1.wrapped[button].OnDragStart == nil
        and _G.DogsForeverUIActionBar1.wrapped[button].OnReceiveDrag == nil)
end

Section("the game's Show Numbers for Cooldowns, followed")
do
    local button = DogsForeverUIActionButton1
    C_CVar.SetCVar("countdownForCooldowns", "0")
    check("off: no numbers on the addon's buttons", button.cooldown.hideNumbers == true)
    C_CVar.SetCVar("countdownForCooldowns", "1")
    check("on: numbers shown, at once", button.cooldown.hideNumbers == false)
    inCombat = true
    C_CVar.SetCVar("countdownForCooldowns", "0")
    check("in combat too", button.cooldown.hideNumbers == true)
    inCombat = false
end

Summary()
