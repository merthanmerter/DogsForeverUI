-- The bag bar: hidden whole until a bag is open (or while placing), a bag
-- button second in the micro menu to open them with, and the backpack's icon
-- mask put back after the game dims it. And the Clean Up button, reachable.

local Bar, Sort = {}, {}
DogsForeverUI.Menus.BagsBar = Bar
DogsForeverUI.Menus.BagSort = Sort

do -- private scope
    local NS = DogsForeverUI.Menus
    local Core = DogsForeverUI

    local BACKPACK = 0          -- Enum.BagIndex.Backpack
    local BAG_ICON = "Interface\\Icons\\ui-hud-actionbar-bag"   -- the backpack's own

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

    -- The game re-anchors the backpack's mask to a smaller box when it dims
    -- it, and never back: centred on the icon again, as built.
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
            hooksecurefunc(backpack, "UpdateItemContextOverlayTextures", RecentreIconMask)
            RecentreIconMask(backpack)

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

    ---------------------------------------------------------------------------
    -- Clean Up: the game's own button lies under Camelot's gamepad bag bar,
    -- which hides and eats it. Ours, in its art over it, does what it does:
    -- the server's sort, instant. The game's button itself is never touched.

    local RAISE = 100           -- levels over the game's button: over the gamepad bag bar

    local function SortClick()
        PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
        C_Container.SortBags()
    end

    local function SortTooltip(button)
        GameTooltip:SetOwner(button)
        GameTooltip_SetTitle(GameTooltip, BAG_CLEANUP_BAGS, HIGHLIGHT_FONT_COLOR)
        GameTooltip_AddNormalLine(GameTooltip, BAG_CLEANUP_BAGS_DESCRIPTION)
        GameTooltip:Show()
    end

    -- A child of the game's button: shown only where and when it is.
    function Sort:Apply()
        local game = _G.BagItemAutoSortButton
        if not game or self.button then return end
        local button = CreateFrame("Button", nil, game)
        button:SetAllPoints(game)
        button:SetNormalAtlas("bags-button-autosort-up")
        button:SetPushedAtlas("bags-button-autosort-down")
        local glow = button:CreateTexture(nil, "HIGHLIGHT")
        glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        glow:SetBlendMode("ADD")
        glow:SetSize(24, 23)
        glow:SetPoint("CENTER")
        button:SetScript("OnShow", function() button:SetFrameLevel(game:GetFrameLevel() + RAISE) end)
        button:SetScript("OnClick", SortClick)
        button:SetScript("OnEnter", SortTooltip)
        button:SetScript("OnLeave", GameTooltip_Hide)
        self.button = button
    end
end
