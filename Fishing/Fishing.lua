-- MODULE: Fishing  (DogsForeverUI.Fishing, settings section "fishing")
--
-- Double right-clicks in the world:
--   * with a fishing pole in hand, a double right-click casts Fishing;
--   * on a Basic Campfire, a double right-click sits the character down.
-- Each is a switch under Extras, both on by default (the player, 2026-10-03).
--
-- HOW. Casting a spell, or sitting, takes a secure button and a real click. So
-- the action is a secure action button of the addon's own (type "spell",
-- Fishing; or type "macro", /sit - sitting down is protected,
-- SitStandOrDescendStart, so a plain call would not do), and the click is the
-- player's: on the second right-click of a double-click, while that button is
-- still held, the right mouse button is bound to the secure button - an
-- override binding, the way the game's own gamepad code clicks buttons
-- (SetOverrideBindingClick) - and letting go of it is the click that acts.
-- Straight after, the binding comes off and the right mouse button is the
-- game's again.
--
-- Holding the right button in the world turns on mouse-look, and while it is
-- on, letting go of the button goes to the camera and never to a binding - the
-- first version missed exactly that, so the cast often did not come until some
-- later click let go of a binding still left on. So mouse-look is stopped the
-- moment the binding goes on, the way the long-standing fishing addons do it.
--
-- THE CAMPFIRE. What is under the mouse in the world is what the game's own
-- world tooltip shows: C_TooltipInfo.GetWorldCursor (GameTooltip.lua,
-- SetWorldCursor). A campfire is an object whose name is the Basic Campfire
-- spell's (818), so the match holds in every language. Mouse-look hides the
-- world cursor, so the first click of the pair may be the last moment the
-- fire was seen: it is remembered until the mouse is seen over something else.
--
-- WHAT IT LEAVES ALONE. A single right-click is never touched: looting the
-- bobber, talking to someone and turning the camera work as ever. And nothing
-- is ever armed while a line is out: a double-click on the bobber, or clicks
-- carrying on across the catch, are the bobber's, never a new cast that throws
-- the catch away. A pair of clicks has to begin after the line came in, and not
-- while the loot window is open. Nothing is armed in combat either (bindings
-- cannot be changed there), while mounted, swimming or casting, with the mouse
-- over a unit, or with something on the cursor. Any binding not let go of by
-- its own click comes off at the very next right-click, before that click can
-- use it, on the way into combat, or after half a second.

DogsForeverUI.Fishing = {}

do -- private scope
    local NS = DogsForeverUI.Fishing

    NS.key = "fishing"
    NS.title = "Double-click"

    NS.defaults = {
        fishing = true,     -- double right-click with a pole casts Fishing
        camping = true,     -- double right-click on a Basic Campfire sits down
    }

    local BUTTON_NAME = "DogsForeverUIFishingButton"

    -- Fishing (Apprentice). Only its name is used: cast by name, the spell is
    -- the rank the player has.
    local FISHING_SPELL_ID = 7620
    -- Basic Campfire: the spell and the object it makes share the name.
    local CAMPFIRE_SPELL_ID = 818
    local CAMPFIRE_NAME = "Basic Campfire"

    -- The item class and subclass of a fishing pole (ItemConstants), with the
    -- values they have always had where the client does not name them.
    local WEAPON = Enum.ItemClass and Enum.ItemClass.Weapon or 2
    local FISHING_POLE = Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole or 20
    local MAIN_HAND = INVSLOT_MAINHAND or 16
    local OBJECT = Enum.TooltipDataType and Enum.TooltipDataType.Object or 4

    local DOUBLE_CLICK = 0.4    -- seconds between the two right-clicks
    local ARMED_FOR = 0.5       -- how long an unused binding is left before it comes off

    local IsSecret = issecretvalue

    local button
    -- Takes an unused binding off after ARMED_FOR: a plain frame of its own,
    -- shown only while a binding is on (the secure button cannot be shown or
    -- hidden in combat, so it does not carry the timer).
    local expiry
    local lastRightClick = nil
    local armedAt = nil
    local campfireSeen = false

    -- The Fishing spell's name, if the player knows it: looked up by name, a
    -- spell answers only when it is in the player's spellbook.
    local function KnownFishing()
        if type(C_Spell) ~= "table" or type(C_Spell.GetSpellName) ~= "function" then return nil end
        local name = C_Spell.GetSpellName(FISHING_SPELL_ID)
        if type(name) ~= "string" then return nil end
        if type(C_Spell.GetSpellInfo) ~= "function" or not C_Spell.GetSpellInfo(name) then
            return nil
        end
        return name
    end

    local function CampfireName()
        if type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function" then
            local name = C_Spell.GetSpellName(CAMPFIRE_SPELL_ID)
            if type(name) == "string" and not IsSecret(name) then
                return name
            end
        end
        return CAMPFIRE_NAME
    end

    -- What the world cursor is over: true for a campfire, false for anything
    -- else (a name the client will not describe included), nil for nothing.
    local function OverCampfire()
        if type(C_TooltipInfo) ~= "table" or type(C_TooltipInfo.GetWorldCursor) ~= "function" then
            return nil
        end
        local data = C_TooltipInfo.GetWorldCursor()
        if type(data) ~= "table" then return nil end
        if IsSecret(data.type) or IsSecret(data.lines) or data.type ~= OBJECT then return false end
        local line = type(data.lines) == "table" and data.lines[1]
        local name = type(line) == "table" and line.leftText or nil
        if name == nil or IsSecret(name) then return false end
        return name == CampfireName()
    end

    -- Remember a campfire under the mouse until the mouse is seen over
    -- something else, or over nothing while it is not mouse-look hiding it.
    local function LookUnderMouse()
        local over = OverCampfire()
        if over ~= nil then
            campfireSeen = over
        elseif not (type(IsMouselooking) == "function" and IsMouselooking()) then
            campfireSeen = false
        end
    end

    local function PoleInHand()
        local itemID = GetInventoryItemID("player", MAIN_HAND)
        if not itemID then return false end
        local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
        return classID == WEAPON and subClassID == FISHING_POLE
    end

    -- Whether the player is casting or channelling anything - a line out
    -- above all. A secret answer is taken as "busy": nothing is armed over
    -- something the client will not describe.
    local function Busy()
        for _, info in ipairs({ UnitChannelInfo, UnitCastingInfo }) do
            if type(info) == "function" then
                local name = info("player")
                if IsSecret(name) then return true end
                if name ~= nil then return true end
            end
        end
        return false
    end

    local function LootOpen()
        local loot = _G.LootFrame
        return type(loot) == "table" and type(loot.IsShown) == "function" and loot:IsShown()
    end

    -- Whether now is a moment an action could be meant.
    local function Ready()
        if InCombatLockdown() then return false end
        if Busy() or LootOpen() then return false end
        if IsMounted and IsMounted() then return false end
        if IsSwimming and IsSwimming() then return false end
        if UnitExists("mouseover") then return false end
        if GetCursorInfo and GetCursorInfo() then return false end
        return true
    end

    local function Disarm()
        if not armedAt or InCombatLockdown() then return end
        armedAt = nil
        ClearOverrideBindings(button)
        expiry:Hide()
    end

    local function Arm(kind, value)
        if kind == "spell" then
            button:SetAttribute("type", "spell")
            button:SetAttribute("spell", value)
            button:SetAttribute("macrotext", nil)
        else
            button:SetAttribute("type", "macro")
            button:SetAttribute("macrotext", value)
            button:SetAttribute("spell", nil)
        end
        SetOverrideBindingClick(button, true, "BUTTON2", BUTTON_NAME)
        armedAt = GetTime()
        expiry:Show()
        -- Let go of mouse-look, or the release goes to the camera and not to
        -- the binding.
        if type(IsMouselooking) == "function" and IsMouselooking()
           and type(MouselookStop) == "function" then
            MouselookStop()
        end
    end

    -- What a double-click right now would do, if anything.
    local function Action()
        if not Ready() then return nil end
        if NS.db.camping and campfireSeen then return "macro", "/sit" end
        if NS.db.fishing and PoleInHand() then
            local spell = KnownFishing()
            if spell then return "spell", spell end
        end
        return nil
    end

    local function OnWorldMouseDown(_, mouseButton)
        if mouseButton ~= "RightButton" then return end

        -- A binding still on from before would take this click's release:
        -- it comes off first, whatever this click turns out to be.
        Disarm()
        LookUnderMouse()

        local now = GetTime()
        local double = lastRightClick ~= nil and now - lastRightClick <= DOUBLE_CLICK
        -- A third click starts a new pair rather than making another double.
        lastRightClick = (not double) and now or nil
        if not double then return end

        local kind, value = Action()
        if kind then Arm(kind, value) end
    end

    -- The line going out or coming in. Casting takes the binding off; the line
    -- coming in forgets any click made while it was out, so a double-click
    -- on the bobber - the first click catches, the second lands after - is not
    -- taken for the start of a new cast.
    local function OnSpellcast(event)
        if event == "UNIT_SPELLCAST_CHANNEL_START" then
            Disarm()
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            lastRightClick = nil
        end
    end

    local function Build()
        button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
        button:SetSize(1, 1)
        button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        button:SetAlpha(0)
        button:EnableMouse(false)
        button:SetAttribute("type", "spell")
        -- Act on letting go of the button, whatever the key-down setting is:
        -- the binding goes on while the button is already down.
        button:SetAttribute("useOnKeyDown", false)
        button:RegisterForClicks("AnyUp")
        -- Runs after the secure click itself, so the action is already made.
        button:SetScript("PostClick", Disarm)

        -- Taken off on the way into combat, while that is still allowed, and
        -- after half a second if it was never used - the second click let go
        -- of over a window, say.
        button:RegisterEvent("PLAYER_REGEN_DISABLED")
        -- The mouse moving onto or off something in the world.
        button:RegisterEvent("WORLD_CURSOR_TOOLTIP_UPDATE")
        -- The player's own line only; nobody else's channel reaches here.
        button:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
        button:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
        button:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_REGEN_DISABLED" then
                Disarm()
            elseif event == "WORLD_CURSOR_TOOLTIP_UPDATE" then
                LookUnderMouse()
            else
                OnSpellcast(event)
            end
        end)
        expiry = CreateFrame("Frame")
        expiry:Hide()
        expiry:SetScript("OnUpdate", function(self)
            if not armedAt then self:Hide()
            elseif GetTime() - armedAt > ARMED_FOR then Disarm() end
        end)

        WorldFrame:HookScript("OnMouseDown", OnWorldMouseDown)
    end

    -- The switches are read at each click: nothing to redraw.
    function NS.Refresh() end
    NS.Init = NS.Refresh

    DogsForeverUI:RegisterModule(NS)

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        if type(WorldFrame) == "table" and type(SetOverrideBindingClick) == "function" then
            Build()
        end
    end)
end
