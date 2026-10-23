-- The bag bar: hidden whole until a bag is open (or while placing), a bag
-- button second in the micro menu to open them with, and the backpack's icon
-- mask put back after the game dims it.

local Bar = {}
DogsForeverUI.Menus.BagsBar = Bar

do -- private scope
    local NS = DogsForeverUI.Menus
    local Core = DogsForeverUI

    local BACKPACK = 0          -- Enum.BagIndex.Backpack
    -- The backpack's own (Forever's); retail draws its backpack as an atlas: a plain bag.
    local BAG_ICON = { "Interface\\Icons\\ui-hud-actionbar-bag", "Interface\\Icons\\INV_Misc_Bag_08" }

    local hiddenByUs = false    -- a bar the game hid (a gamepad) is the game's to show
    local bagOpen = false       -- as Bar:Update last read it

    -- A protected frame anchored to the bar in Edit Mode makes it protected.
    local function MayChange(bar)
        return not (InCombatLockdown() and bar:IsProtected())
    end

    -- Hidden whole, as the game itself hides it for a gamepad: the slots,
    -- the backpack and the keyring are its children.
    local function UpdateBar()
        local bar = _G.BagsBar
        if not bar then return end
        if bagOpen or Core.EditModeOpen() or Core.IsUnlocked() then
            if hiddenByUs and MayChange(bar) then
                hiddenByUs = false
                bar:Show()
            end
        elseif bar:IsShown() and MayChange(bar) then
            hiddenByUs = true
            bar:Hide()
        end
    end

    -- Name, keybinding and free slots, as the backpack's own tooltip.
    local function BagTooltip(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(MicroButtonTooltipText(BACKPACK_TOOLTIP, "TOGGLEBACKPACK"), 1, 1, 1)
        GameTooltip:AddLine(NUM_FREE_SLOTS:format(C_Container.CalculateTotalNumberOfFreeBagSlots()))
        GameTooltip:Show()
    end

    -- As the backpack clicks (BaseBagSlotButtonMixin:BagSlotOnClick).
    local function BagClick()
        if IsModifiedClick("OPENALLBAGS") then
            ToggleAllBags()
        elseif not PutItemInBackpack() then
            ToggleBag(BACKPACK)
        end
    end

    -- The game re-anchors the square backpack's mask (Forever's; retail's is
    -- round) to a smaller box when it dims it, and never back: centred on the
    -- icon again, as built.
    local function RecentreIconMask(button)
        button.SquareMask:ClearAllPoints()
        button.SquareMask:SetPoint("CENTER", button.icon)
    end

    function Bar:Update()
        bagOpen = IsAnyBagOpen()
        UpdateBar()
    end

    -- The frame after a bag window shows or hides (its OnHide runs while
    -- it is still going), placing, combat ending, or the game showing the bar.
    local Soon, soonFrame = Core.Waker(function() Bar:Update() end)

    function Bar:Apply()
        if not self.button then
            self.button = NS.MicroMenu.NewButton("DogsForeverUIBagButton", BAG_ICON,
                function() return bagOpen end, BagClick, BagTooltip)
            self.button:SetScript("OnReceiveDrag", function() PutItemInBackpack() end)

            local backpack = _G.MainMenuBarBackpackButton
            if backpack.SquareMask then
                hooksecurefunc(backpack, "UpdateItemContextOverlayTextures", RecentreIconMask)
                RecentreIconMask(backpack)
            end

            for _, name in ipairs({ "MainActionBar_InitializeGamepad", "MainActionBar_UnInitializeMKB" }) do
                if _G[name] then hooksecurefunc(name, function() hiddenByUs = false end) end
            end
            for _, name in ipairs({ "OpenBag", "CloseBag", "OpenAllBags", "CloseAllBags" }) do
                EventRegistry:RegisterCallback("ContainerFrame." .. name, Soon, Bar)
            end
            Core.WatchPlacing(Soon)
            soonFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            soonFrame:SetScript("OnEvent", Soon)
            if _G.BagsBar then _G.BagsBar:HookScript("OnShow", Soon) end
        end
        self:Update()
    end
end
