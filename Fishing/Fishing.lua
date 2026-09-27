-- Fishing with the mouse: with a fishing pole in hand, a double right-click in
-- the world casts Fishing. No setting and no command - it does nothing at all
-- unless a pole is equipped.
--
-- HOW. Casting a spell takes a secure button and a real click. So the cast is a
-- secure action button of the addon's own (type "spell", Fishing), and the click
-- is the player's: on the second right-click of a double-click, while that
-- button is still held, the right mouse button is bound to the secure button -
-- an override binding, the way the game's own gamepad code clicks buttons
-- (SetOverrideBindingClick) - and letting go of it is the click that casts.
-- Straight after, the binding comes off and the right mouse button is the
-- game's again.
--
-- Holding the right button in the world turns on mouse-look, and while it is
-- on, letting go of the button goes to the camera and never to a binding - the
-- first version missed exactly that, so the cast often did not come until some
-- later click let go of a binding still left on. So mouse-look is stopped the
-- moment the binding goes on, the way the long-standing fishing addons do it.
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

local Fishing = {}
DogsForeverUI.Fishing = Fishing

do -- private scope

    local BUTTON_NAME = "DogsForeverUIFishingButton"

    -- Fishing (Apprentice). Only its name is used: cast by name, the spell is
    -- the rank the player has.
    local FISHING_SPELL_ID = 7620

    -- The item class and subclass of a fishing pole (ItemConstants), with the
    -- values they have always had where the client does not name them.
    local WEAPON = Enum.ItemClass and Enum.ItemClass.Weapon or 2
    local FISHING_POLE = Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole or 20
    local MAIN_HAND = INVSLOT_MAINHAND or 16

    local DOUBLE_CLICK = 0.4    -- seconds between the two right-clicks
    local ARMED_FOR = 0.5       -- how long an unused binding is left before it comes off

    local button
    local lastRightClick = nil
    local armedAt = nil

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

    local function PoleInHand()
        local itemID = GetInventoryItemID("player", MAIN_HAND)
        if not itemID then return false end
        local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
        return classID == WEAPON and subClassID == FISHING_POLE
    end

    -- Whether the player is casting or channelling anything - a line out
    -- above all. A secret answer is taken as "busy": no cast is armed over
    -- something the client will not describe.
    local function Busy()
        for _, info in ipairs({ UnitChannelInfo, UnitCastingInfo }) do
            if type(info) == "function" then
                local name = info("player")
                if issecretvalue and issecretvalue(name) then return true end
                if name ~= nil then return true end
            end
        end
        return false
    end

    local function LootOpen()
        local loot = _G.LootFrame
        return type(loot) == "table" and type(loot.IsShown) == "function" and loot:IsShown()
    end

    -- Whether now is a moment a cast could be meant.
    local function Ready()
        if InCombatLockdown() then return false end
        if Busy() or LootOpen() then return false end
        if IsMounted and IsMounted() then return false end
        if IsSwimming and IsSwimming() then return false end
        if UnitExists("mouseover") then return false end
        if GetCursorInfo and GetCursorInfo() then return false end
        return PoleInHand()
    end

    local function Disarm()
        if not armedAt or InCombatLockdown() then return end
        armedAt = nil
        ClearOverrideBindings(button)
    end

    local function Arm(spell)
        button:SetAttribute("spell", spell)
        SetOverrideBindingClick(button, true, "BUTTON2", BUTTON_NAME)
        armedAt = GetTime()
        -- Let go of mouse-look, or the release goes to the camera and not to
        -- the binding.
        if type(IsMouselooking) == "function" and IsMouselooking()
           and type(MouselookStop) == "function" then
            MouselookStop()
        end
    end

    local function OnWorldMouseDown(_, mouseButton)
        if mouseButton ~= "RightButton" then return end

        -- A binding still on from before would take this click's release:
        -- it comes off first, whatever this click turns out to be.
        Disarm()

        local now = GetTime()
        local double = lastRightClick ~= nil and now - lastRightClick <= DOUBLE_CLICK
        -- A third click starts a new pair rather than making another double.
        lastRightClick = (not double) and now or nil
        if not double or not Ready() then return end

        local spell = KnownFishing()
        if spell then Arm(spell) end
    end

    -- The line going out or coming in. Casting takes the binding off; the line
    -- coming in forgets any click made while it was out, so a double-click
    -- on the bobber - the first click catches, the second lands after - is not
    -- taken for the start of a new cast.
    local function OnSpellcast(event, unit)
        if unit ~= "player" then return end
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
        -- Cast on letting go of the button, whatever the key-down setting is:
        -- the binding goes on while the button is already down.
        button:SetAttribute("useOnKeyDown", false)
        button:RegisterForClicks("AnyUp")
        -- Runs after the secure click itself, so the cast is already made.
        button:SetScript("PostClick", Disarm)

        -- Taken off on the way into combat, while that is still allowed, and
        -- after half a second if it was never used - the second click let go
        -- of over a window, say.
        button:RegisterEvent("PLAYER_REGEN_DISABLED")
        button:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
        button:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
        button:SetScript("OnEvent", function(_, event, unit)
            if event == "PLAYER_REGEN_DISABLED" then Disarm() else OnSpellcast(event, unit) end
        end)
        button:SetScript("OnUpdate", function()
            if armedAt and GetTime() - armedAt > ARMED_FOR then Disarm() end
        end)

        WorldFrame:HookScript("OnMouseDown", OnWorldMouseDown)
    end

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        if type(WorldFrame) == "table" and type(SetOverrideBindingClick) == "function" then
            Build()
        end
    end)
end
