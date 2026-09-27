-- The bag bar: a repair to the game's backpack icon. Hiding the bar until the
-- mouse is over it is the action bars' auto-hide (ActionBars.lua, "Bag Bar").
--
-- Until 2026-09-27 the bar was "collapsed" here: every bag slot hidden and its
-- frame faded until a bag was opened. The player had that taken out for the
-- auto-hide every other bar has.
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
-- all there is to restore. This is a repair, so there is no setting for it.
--
-- `hooksecurefunc` is the only hook: it runs after Blizzard's code rather than
-- instead of it, and nothing is written onto a Blizzard frame.

local Bags = {}
DogsForeverUI.Menus.BagsBar = Bags

local function RecentreIconMask(button)
    local mask, icon = button.SquareMask, button.icon
    if mask and icon then
        mask:ClearAllPoints()
        mask:SetPoint("CENTER", icon)
    end
end

local applied = false

function Bags:Apply()
    if applied then return end
    local backpack = MainMenuBarBackpackButton
    if backpack and backpack.UpdateItemContextOverlayTextures then
        applied = true
        hooksecurefunc(backpack, "UpdateItemContextOverlayTextures", RecentreIconMask)
        RecentreIconMask(backpack)
    end
end
