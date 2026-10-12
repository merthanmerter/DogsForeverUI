-- The threat bar: the player's threat on the target, over the target frame.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

LoadAddon()
Login()

local NS = DogsForeverUI.Threat
local DB, bar = NS.db, NS.bar
local function Settle() for _ = 1, 10 do Tick(0.1) end end

Section("the bar")
check("the target frame's width, the castbar's height", bar.width == 150 and bar.height == 20)
check("its left edge on the target frame's, its top level with the castbar's",
    DB.barLeft == DogsForeverUI.Frames.db.targetLeft and DB.barTop == DogsForeverUI.Castbar.db.barTop,
    tostring(DB.barLeft) .. " " .. tostring(DB.barTop))
check("hidden with no target", not bar:IsShown())
check("takes no mouse while locked", not bar:IsMouseEnabled())

Section("on the threat list")
units.target = { name = "Kobold", level = 10, reaction = 2, health = 1, healthMax = 1, threat = 62.4 }
Fire("PLAYER_TARGET_CHANGED")
Settle()
check("shown, filled to the threat", bar:IsShown() and bar:GetValue() == 62.4, bar:GetValue())
check("the percentage on the right", bar.valueText:GetText() == "62%", bar.valueText:GetText())
check("labelled", bar.nameText:GetText() == "Threat")
check("with its spark", bar.spark.alpha == 1)

units.target.threat = 100
Fire("UNIT_THREAT_LIST_UPDATE", "target")
check("redrawn as the threat list changes", bar:GetValue() == 100 and bar.valueText:GetText() == "100%")
check("no spark against the full bar's end", bar.spark.alpha == 0)

Fire("UNIT_THREAT_LIST_UPDATE", "nameplate3")
check("another mob's list is not listened to", bar:GetValue() == 100)

Section("secret")
local secret = SecretCastValue("threat")
units.target.threat = secret
Fire("UNIT_THREAT_LIST_UPDATE", "target")
check("a secret handed on as it is", bar:GetValue() == secret and bar:IsShown())
check("never read: no spark", bar.spark.alpha == 0)

Section("off the list")
units.target.threat = nil
Fire("UNIT_THREAT_LIST_UPDATE", "target")
Settle()
check("fades out", not bar:IsShown())
units.target = { name = "Dogsfriend", isPlayer = true, reaction = 5, health = 1, healthMax = 1 }
Fire("PLAYER_TARGET_CHANGED")
Settle()
check("a player has no threat list: hidden", not bar:IsShown())

Section("unlock mode")
DogsForeverUI.SetUnlocked(true)
check("shown full to be placed, takes the mouse",
    bar:IsShown() and bar:GetValue() == 100 and bar:IsMouseEnabled())
check("a piece of its own, with a reset", DogsForeverUI.Snap.CanReset(DogsForeverUI.Snap.EntryById("threat")))
DogsForeverUI.SetUnlocked(false)
Settle()
check("gone again when locked, with no threat", not bar:IsShown())

Summary()
