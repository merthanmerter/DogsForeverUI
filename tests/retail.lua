-- Retail: the whole addon loaded as the game's "mainline", through a session,
-- the options and Unlock Mode. The harness builds Forever's frames, so this is
-- a smoke test: nothing may raise on retail's code paths.
local ADDON_PATH, TOC_TEXT = ...
WOW_PROJECT_ID = 1
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)
-- Retail's rotation helper (Blizzard_ActionBar Mainline): it shows its ants on a button.
AssistedCombatManager = { SetAssistedHighlightFrameShown = function() end }

LoadAddon()
Login()

local Core = DogsForeverUI

Section("loaded as retail")
check("the addon knows it is on retail", Core.RETAIL == true)

Section("a session")
for _ = 1, 30 do Tick(0.1) end
check("ticking: no error", true)

Section("Forever's classic-only helpers not offered")
check("no double-click fishing", Core.Fishing.FISHING_OFFERED == false)
check("no skinning hints", Core.Skinning.OFFERED == false)

Section("the game's own sizes")
check("the bag bar as the game draws it, not Forever's 75%",
    Core.GameFrames.defaults.bagsSize == 100 and Core.GameFrames.db.bagsSize == 100)

Section("the rotation helper on a stance button")
do
    -- (Blizzard_ActionBar Mainline: the game sizes the ants for its own small
    -- stance buttons; ours have the action buttons' shape.)
    local manager = AssistedCombatManager
    if manager then
        local button = StanceButton1
        local flipbook = CreateFrame("Frame"):CreateTexture()
        button.AssistedCombatHighlightFrame = { Flipbook = flipbook }
        flipbook:SetSize(48, 48)
        manager:SetAssistedHighlightFrameShown(button, true)
        check("the ants the action buttons' size", flipbook.width == 66 and flipbook.height == 66)
        button.AssistedCombatHighlightFrame = nil
    end
end

Section("the options and Unlock Mode")
Core.Options.Open()
Tick(1)
check("the options open", Core.Options.IsShown())
local labels = {}
for key in pairs(Core.Options.controls) do labels[#labels + 1] = key end
local offered = table.concat(labels, "\n")
check("no fishing or skinning rows", not offered:find("Double-click fishing", 1, true)
    and not offered:find("Skinnable on tooltips", 1, true))
Core.SetUnlocked(true)
for _ = 1, 10 do Tick(0.1) end
Core.SetUnlocked(false)
Tick(1)
check("Unlock Mode in and out: no error", true)

Summary()
