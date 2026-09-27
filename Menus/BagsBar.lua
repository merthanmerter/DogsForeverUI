-- The bag bar as one backpack icon, until a bag is open.
--
-- Closed: only MainMenuBarBackpackButton is on screen. Every other bag slot and
-- the keyring are hidden; the dividers between them and the bar's frame are
-- transparent.
--
-- Open (any bag, the way the game's own IsAnyBagOpen counts them): the slots
-- are shown again, exactly as Blizzard drew them, so bags can be swapped and
-- dragged into them.
--
-- Switched off in the options, the bar is the game's own again, all the time.
--
-- THE SLOTS ARE HIDDEN, THE WAY THE GAME HIDES THEM. The game's own collapse
-- is BaseBagSlotButtonMixin:SetBarExpanded, which is nothing but
-- `self:SetShown(isExpanded)` (Shared\MainMenuBarBagButtons.lua). Camelot
-- switches that collapse off (hideExpandToggle), so this addon does the same
-- thing itself: Hide, and later Show. The slot buttons are not protected, so
-- this is allowed in combat, and a hidden slot takes no mouse and draws
-- nothing - its icon, frame, count and mask all go with it and come back
-- untouched.
--
-- Three earlier versions faded the slots instead (alpha on the button, then on
-- every texture of it, then on every texture but its icon mask). In game each
-- one left something wrong - frames still drawn while closed, or bags missing
-- from their slots when open. Nothing inside a slot is touched any more.
--
-- The slots stay where Blizzard laid them out. The bar grows leftward from the
-- backpack (Camelot\MainMenuBarBagButtons.xml: direction Left, backpack on the
-- RIGHT edge), so the backpack does not move when the rest appears.
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
-- all there is to restore. This is a repair, so it applies whatever the options
-- say.

local Bags = {}
DogsForeverUI.Menus.BagsBar = Bags

-- The slots this addon hid, so opening a bag shows exactly those again and
-- never one the game hid itself (the keyring on a character without one).
-- Kept here, never as fields on Blizzard's frames.
local hiddenByUs = {}
local alphaBefore = {}
local hookedContainers = {}
local hookedButtons = {}

-- For the bar's own frame and its dividers, which are plain art on the bar.
local function Fade(region, faded)
    if not region then return end
    if faded then
        if alphaBefore[region] == nil then
            alphaBefore[region] = region:GetAlpha()
        end
        region:SetAlpha(0)
    elseif alphaBefore[region] ~= nil then
        region:SetAlpha(alphaBefore[region])
        alphaBefore[region] = nil
    end
end

local function EachOtherBagButton(fn)
    if not MainMenuBarBagManager then return end
    for _, button in MainMenuBarBagManager:EnumerateBagButtons() do
        if button ~= MainMenuBarBackpackButton then
            fn(button)
        end
    end
end

local function EachDivider(fn)
    for _, key in ipairs({ "HorizontalDividersPool", "VerticalDividersPool" }) do
        local pool = BagsBar[key]
        if pool then
            for divider in pool:EnumerateActive() do
                fn(divider)
            end
        end
    end
end

function Bags:IsAnyBagOpen()
    return IsAnyBagOpen and IsAnyBagOpen() and true or false
end

function Bags:Refresh()
    if not BagsBar then return end

    -- Switched off in the options, the bar is the game's own all the time.
    local open = self:IsAnyBagOpen() or not DogsForeverUI.Menus.db.collapseBags

    EachOtherBagButton(function(button)
        if open then
            if hiddenByUs[button] then
                hiddenByUs[button] = nil
                button:Show()
            end
        elseif button:IsShown() then
            hiddenByUs[button] = true
            button:Hide()
        end
    end)

    EachDivider(function(divider) Fade(divider, not open) end)
    Fade(BagsBar.BorderArt, not open)
end

local function OnChanged()
    Bags:Refresh()
end

local function HookContainer(frame)
    if frame and not hookedContainers[frame] then
        hookedContainers[frame] = true
        frame:HookScript("OnShow", OnChanged)
        frame:HookScript("OnHide", OnChanged)
    end
end

-- Anything of the game's that shows a slot again while every bag is closed is
-- answered straight away: the slot's own OnShow runs this after it.
local function HookSlot(button)
    if not hookedButtons[button] then
        hookedButtons[button] = true
        button:HookScript("OnShow", OnChanged)
    end
end

local function RecentreIconMask(button)
    local mask, icon = button.SquareMask, button.icon
    if mask and icon then
        mask:ClearAllPoints()
        mask:SetPoint("CENTER", icon)
    end
end

function Bags:Apply()
    if not BagsBar then return end

    local backpack = MainMenuBarBackpackButton
    if backpack and backpack.UpdateItemContextOverlayTextures then
        hooksecurefunc(backpack, "UpdateItemContextOverlayTextures", RecentreIconMask)
        RecentreIconMask(backpack)
    end

    -- Every bag window the game has: one per bag (ContainerFrame1..n, collected
    -- by their template into ContainerFrameContainer.ContainerFrames) plus the
    -- single combined-bags window. All are built from XML before any addon runs.
    if ContainerFrameContainer and ContainerFrameContainer.ContainerFrames then
        for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do
            HookContainer(frame)
        end
    end
    HookContainer(ContainerFrameCombinedBags)

    EachOtherBagButton(HookSlot)

    -- Blizzard re-lays the bar out on Edit Mode changes, and hands out fresh
    -- dividers from its pool each time, which arrive fully opaque.
    hooksecurefunc(BagsBar, "Layout", OnChanged)

    self:Refresh()
end
