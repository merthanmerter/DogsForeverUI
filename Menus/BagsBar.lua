-- The bags: the bag bar out of sight until a bag is open, a bag button second
-- in the micro menu to open them with, and a repair to the backpack's icon.
-- It is the look, so there is no setting for any of it (the player asked,
-- 2026-09-29).
--
-- History: until 2026-09-27 the bar was "collapsed" (its bag slots hidden until
-- a bag was open); then it auto-hid under the mouse like the action bars
-- (ActionBars.lua, "Bag Bar"). Now it is gone altogether while the bags are
-- shut, and the micro menu carries the one button the bar was needed for.
--
-- THE BAR IS HIDDEN, whole. BagsBar is the parent of the backpack, the bag
-- slots and the keyring (Camelot\MainMenuBarBagButtons.xml), so hiding it takes
-- all of them, mouse and all - nothing inside it is touched. It is exactly what
-- the game does itself when a gamepad takes over (MainActionBar_InitializeGamepad,
-- Blizzard_ActionBar\Shared\MainActionBar.lua). It shows again while any bag is
-- open - one bag, the backpack, the keyring or the combined window, the game's
-- own IsAnyBagOpen - and while Edit Mode is open, so it can still be placed.
-- Only a bar hidden here is shown again here: if the game hid it (a gamepad),
-- the game shows it. BagsBar is not protected, but a protected frame anchored to
-- it in Edit Mode would make it so, and then it is left as it is until combat
-- ends rather than have the game refuse the call.
--
-- THE BAG BUTTON is the addon's own, a child of MicroMenu so it takes the
-- menu's scale and fade and goes wherever the game lends the menu (vehicles).
-- It wears the micro buttons' look (MicroMenu.lua): the game's own backpack
-- icon filling the square, as an action button's. It clicks as the
-- backpack does (BaseBagSlotButtonMixin:BagSlotOnClick): an item on the cursor
-- goes into the backpack, the open-all-bags modifier opens every bag, and a
-- plain click opens or shuts the backpack. It has no layoutIndex, so the game's
-- own layout never counts it (BaseLayoutMixin:GetLayoutChildren); the addon's
-- row puts it second, after the character (MicroMenu.lua).
--
-- THE BACKPACK'S ICON MASK IS PUT BACK. The icon is cut out by SquareMask,
-- which the template centres on the icon (Camelot\MainMenuBarBagButtons.xml).
-- Whenever the game dims the backpack (a bag search it has no match in, or a
-- window that greys out items that do not apply),
-- MainMenuBarBackpackMixin:UpdateItemContextOverlayTextures
-- (Shared\MainMenuBarBagButtons.lua) re-anchors that mask to a smaller box off
-- to the top left of the button, and nothing ever anchors it back: the icon
-- stays shrunk and cut until a /reload. The other bag slots do not have this
-- override. Right after it runs, the mask is centred on the icon again, as it
-- was built. Its size is its own and survives the re-anchoring, so the anchor is
-- all there is to restore.
--
-- `hooksecurefunc` is the only hook: it runs after Blizzard's code rather than
-- instead of it, and nothing is written onto a Blizzard frame.

local Bags = {}
DogsForeverUI.Menus.BagsBar = Bags

do -- private scope

    local NS = DogsForeverUI.Menus

    -- The game's own backpack icon (Camelot\MainMenuBarBagButtons.xml, bagIcon).
    Bags.ICON = "Interface\\Icons\\ui-hud-actionbar-bag"
    local BAG_ICON = Bags.ICON
    local BACKPACK = 0 -- Enum.BagIndex.Backpack

    ---------------------------------------------------------------------------
    -- The bar.

    local function AnyBagOpen()
        if type(IsAnyBagOpen) ~= "function" then return false end
        local ok, open = pcall(IsAnyBagOpen)
        return ok and open and true or false
    end

    local hiddenByUs = false

    -- A protected frame may not be shown or hidden from here in combat.
    local function MayChange(bar)
        if not InCombatLockdown() then return true end
        return not (bar.IsProtected and bar:IsProtected())
    end

    local function UpdateBar(bagOpen)
        local bar = _G.BagsBar
        if not bar then return end
        if bagOpen or NS.EditModeOpen() then
            if hiddenByUs and MayChange(bar) then
                hiddenByUs = false
                bar:Show()
            end
        elseif bar:IsShown() and MayChange(bar) then
            hiddenByUs = true
            bar:Hide()
        end
    end

    ---------------------------------------------------------------------------
    -- The bag button.

    local function FreeSlots()
        if not (C_Container and C_Container.CalculateTotalNumberOfFreeBagSlots) then return nil end
        local ok, free = pcall(C_Container.CalculateTotalNumberOfFreeBagSlots)
        if ok then return free end
    end

    -- Name, keybinding and free slots, as the backpack's own tooltip has them.
    local function ShowTooltip(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        local title = BACKPACK_TOOLTIP or "Backpack"
        if type(MicroButtonTooltipText) == "function" then
            title = MicroButtonTooltipText(title, "TOGGLEBACKPACK")
        end
        GameTooltip:SetText(title, 1, 1, 1)
        local free = FreeSlots()
        if free and NUM_FREE_SLOTS then
            GameTooltip:AddLine(NUM_FREE_SLOTS:format(free))
        end
        GameTooltip:Show()
    end

    local function OnClick()
        if IsModifiedClick("OPENALLBAGS") then
            ToggleAllBags()
        elseif not PutItemInBackpack() then
            ToggleBag(BACKPACK)
        end
    end

    -- The micro buttons' own look (MicroMenu.lua), lit while any bag is open
    -- as a micro button is while its window is. Just its square: the menu's
    -- row places it (second, after the character).
    local function MakeButton(menu)
        local button = CreateFrame("Button", "DogsForeverUIBagButton", menu)
        button:SetSize(NS.MicroMenu.SQUARE, NS.MicroMenu.SQUARE)
        button:RegisterForClicks("AnyUp")
        button:SetScript("OnClick", OnClick)
        button:SetScript("OnReceiveDrag", function() PutItemInBackpack() end)
        button:SetScript("OnEnter", ShowTooltip)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        NS.MicroMenu.Skin(button, BAG_ICON, AnyBagOpen)
        return button
    end

    function Bags:Update()
        UpdateBar(AnyBagOpen())
    end

    ---------------------------------------------------------------------------
    -- The backpack's mask.

    local function RecentreIconMask(button)
        local mask, icon = button.SquareMask, button.icon
        if mask and icon then
            mask:ClearAllPoints()
            mask:SetPoint("CENTER", icon)
        end
    end

    local watcher
    local maskRepaired = false

    function Bags:Apply()
        local backpack = _G.MainMenuBarBackpackButton
        if not maskRepaired and backpack and backpack.UpdateItemContextOverlayTextures then
            maskRepaired = true
            hooksecurefunc(backpack, "UpdateItemContextOverlayTextures", RecentreIconMask)
            RecentreIconMask(backpack)
        end

        if not self.button and _G.MicroMenu then
            self.button = MakeButton(_G.MicroMenu)
        end

        if not watcher then
            -- The game hiding the bar for a gamepad is the game's to undo.
            for _, name in ipairs({ "MainActionBar_InitializeGamepad", "MainActionBar_UnInitializeMKB" }) do
                if type(_G[name]) == "function" then
                    hooksecurefunc(name, function() hiddenByUs = false end)
                end
            end
            watcher = CreateFrame("Frame")
            watcher:SetScript("OnUpdate", function() Bags:Update() end)
        end

        self:Update()
    end
end
