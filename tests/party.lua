-- The party: four frames in the target frame's design, a little smaller, a
-- column placed as one; the game's party frames faded while they show, and
-- its raid-style frames too when its "Use Raid-Style Party Frames" is on
-- (they wear this addon's bar textures all the same); the addon's own raid
-- style, switched at once.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

local function Member(name, class)
    return { name = name, level = 60, class = class or "WARRIOR", isPlayer = true, reaction = 5,
             health = 5000, healthMax = 9000, incoming = 0,
             power = 40, powerMax = 100, powerToken = "RAGE" }
end

-- A raid-style frame the game made before the addon was there.
local earlyRaidFrame = NewCompactFrame("CompactRaidFrame1")

LoadAddon()
Login()

local Core = DogsForeverUI
local NS = Core.Frames
local UnitPlate = NS.UnitPlate
local Style = Core.Style
local DB = NS.db

Section("Show self on to start (the player, 2026-10-03)")
check("the player's own frame in the column by default", DB.partyShowSelf == true)
-- (The four members' column first, as it was; Show self on again further down.)
DB.partyShowSelf = false
NS.Refresh()

Section("four party frames, one compact style")
local plates = {}
for index = 1, 4 do plates[index] = NS.plates["party" .. index] end
check("a frame for each of party1 to party4", plates[1] and plates[2] and plates[3] and plates[4]
    and plates[3].unit == "party3")
check("bars, border and click, the name inside the health bar",
    plates[1].health and plates[1].power and plates[1].border and plates[1].click
    and plates[1].click:GetAttribute("unit") == "party1" and plates[1].nameText.anchors[1][2] == plates[1].health)
check("no name row above: no band, no level", not plates[1].nameBand[1].shown
    and plates[1].levelText.alpha == 0 and UnitPlate.PartyTopRoom() == 0)
check("a size of their own: the health bar 40 to start (the player, 2026-10-03)",
    plates[1].width == DB.partyWidth and DB.partyRaidHealth == 40 and plates[1].health.height == 40
    and plates[1].height == 40 + 1 + DB.partyPower)
check("no switch between two styles any more", DB.partyRaidStyle == nil and DB.partyHealth == nil)
do
    -- (The player, 2026-10-22: a short narrow frame drew its name as "..".)
    check("a name with room: shown", plates[1].nameText.shown ~= false)
    local width, health = DB.partyWidth, DB.partyRaidHealth
    DB.partyWidth, DB.partyRaidHealth = 90, 20
    NS.Refresh()
    check("short and narrow, no room for a letter beside the value: no name at all",
        plates[1].nameText.shown == false)
    DB.partyWidth, DB.partyRaidHealth = width, health
    NS.Refresh()
    check("room again: back", plates[1].nameText.shown ~= false)
end
check("left-click targets, right-click the unit menu",
    plates[2].click:GetAttribute("*type1") == "target" and plates[2].click:GetAttribute("*type2") == "togglemenu")

Section("one column, placed as one")
local step = UnitPlate.PartyStep(DB)
do
    -- The column as Unlock Mode boxes it: party1's border down to party4's.
    local nameRow = UnitPlate.PartyTopRoom()
    local plateHeight = DB.partyRaidHealth + 1 + DB.partyPower
    local visibleTop = DB.partyTop + nameRow + Style.BORDER_INSET
    local visibleBottom = DB.partyTop - 3 * step - plateHeight - Style.BORDER_INSET
    local above, below = -visibleTop, GetScreenHeight() + visibleBottom
    check("against the left edge to start, just its border's width in",
        DB.partyLeft == Style.BORDER_INSET + 1 and DB.partyPlaced == nil)
    check("and centred top to bottom: as much screen above the column as below it",
        math.abs(above - below) < 1e-6, above .. " / " .. below)
    DB.partyRaidHealth = DB.partyRaidHealth + 20
    NS.Refresh()
    local grown = DB.partyTop
    DB.partyRaidHealth = DB.partyRaidHealth - 20
    NS.Refresh()
    check("until placed, centred again when the party frames' size changes", grown > DB.partyTop)
end
check("party1 at the column's place", plates[1].points[4] == DB.partyLeft and plates[1].points[5] == DB.partyTop)
check("each next one a step lower: its bars, border and a small gap",
    plates[2].points[5] == DB.partyTop - step and plates[4].points[5] == DB.partyTop - 3 * step
    and plates[4].points[4] == DB.partyLeft
    and step == plates[1].height + 2 * Style.BORDER_INSET + UnitPlate.PARTY_GAP and UnitPlate.PARTY_GAP == 2)

Section("shown as the game shows its party frames")
Fire("GROUP_ROSTER_UPDATE")
check("alone: none", not plates[1].shown and not plates[2].shown)
check("left to the game's secure driver, not shown by hand",
    stateDrivers[plates[1]] ~= nil and stateDrivers[plates[1]]:find("@party1,exists") ~= nil
    and stateDrivers[plates[1]]:find("group:raid") ~= nil)
inGroup = true
units.party1, units.party2 = Member("Grumbo"), Member("Tessa", "PRIEST")
Fire("GROUP_ROSTER_UPDATE")
check("in a party: one for each member there is", plates[1].shown and plates[2].shown
    and not plates[3].shown and not plates[4].shown)
check("each drawing its member", plates[1].nameText.text == "Grumbo" and plates[2].nameText.text == "Tessa")
inRaid = true
Fire("GROUP_ROSTER_UPDATE")
check("in a raid: none - the game's raid frames are the group's there",
    not plates[1].shown and not plates[2].shown)
inRaid = false
Fire("GROUP_ROSTER_UPDATE")
check("back in a party: back", plates[1].shown and plates[2].shown)

Section("a heal on a member shows the next frame, with no event")
do
    -- As the game's own unit frames read it (UNIT_HEALTH comes late here).
    units.party2.health = 8000
    Tick(0.01)
    check("the bar has it", plates[2].health:GetValue() == 8000, plates[2].health:GetValue())
    units.party2.health = 5000
    Tick(0.01)
end

Section("a member offline: grey and full, \"Offline\" on the bar")
do
    units.party2.offline = true
    Fire("UNIT_CONNECTION", "party2", false)
    Tick(0.01)
    local health, power = plates[2].health, plates[2].power
    check("both bars grey, as the game's raid frames draw one",
        health.statusColor[1] == 0.5 and health.statusColor[2] == 0.5 and power.statusColor[3] == 0.5)
    check("both full", health:GetValue() == 1 and select(2, health:GetMinMaxValues()) == 1
        and power:GetValue() == 1)
    check("\"Offline\" in place of the health value", plates[2].healthText.text == "Offline"
        and plates[2].powerText.text == "")
    check("the others untouched", plates[1].healthText.text ~= "Offline" and plates[1].health.statusColor[1] ~= 0.5)
    units.party2.offline = nil
    Fire("UNIT_CONNECTION", "party2", true)
    Tick(0.01)
    check("back online: class colour and health again",
        plates[2].health.statusColor[1] ~= 0.5 and plates[2].health:GetValue() == 5000)

    DB.showHealthText = false
    NS.Refresh()
    check("health text off: no value, the name centred alone",
        plates[2].healthText.text == "" and #plates[2].healthText.anchors == 0)
    units.party2.offline = true
    Fire("UNIT_CONNECTION", "party2", false)
    Tick(0.01)
    check("still \"Offline\", given the value's place",
        plates[2].healthText.text == "Offline" and #plates[2].healthText.anchors > 0)
    units.party2.offline = nil
    Fire("UNIT_CONNECTION", "party2", true)
    Tick(0.01)
    check("back online: no value again", plates[2].healthText.text == "" and #plates[2].healthText.anchors == 0)
    DB.showHealthText = true
    NS.Refresh()
end

Section("a member dead: \"Dead\" on the bar, no event needed")
do
    -- (A ghost, or a body out of range, can still report health.)
    units.party2.dead, units.party2.health = true, 2500
    Tick(0.01)
    check("\"Dead\" in place of the health value", plates[2].healthText.text == "Dead")
    check("the bar empty though health is reported, in its own colour (the game greys only the offline)",
        plates[2].health:GetValue() == 0 and plates[2].health.statusColor[1] ~= 0.5)
    check("the power bar empty too, no power value",
        plates[2].power:GetValue() == 0 and plates[2].powerText.text == "")
    DB.showHealthText = false
    NS.Refresh()
    check("health text off: still \"Dead\", given the value's place",
        plates[2].healthText.text == "Dead" and #plates[2].healthText.anchors > 0)
    units.party2.dead, units.party2.health = nil, 5000
    Tick(0.01)
    check("alive again: no value, the name alone", plates[2].healthText.text == ""
        and #plates[2].healthText.anchors == 0)
    DB.showHealthText = true
    NS.Refresh()
    Tick(0.01)
    check("and its value back with health text on", plates[2].healthText.text ~= "" and plates[2].healthText.text ~= "Dead")
end

Section("a party frame's tooltip in the game's default place")
do
    plates[1].click:GetScript("OnEnter")(plates[1].click)
    check("as the game's own unit frames put it", GameTooltip.defaultAnchor == true
        and GameTooltip.owner == plates[1].click)
    plates[1].click:GetScript("OnLeave")(plates[1].click)
end

Section("a party member's role, in the health bar's corner")
do
    -- The game's own role icons, as its raid-style frames draw them.
    for _, atlas in pairs(UnitPlate.ROLE_ICONS) do atlases[atlas] = true end
    function UnitGroupRolesAssigned(unit)
        local u = units[unit]
        return u and u.role or "NONE"
    end
    local role = plates[1].roleIcon
    check("each party frame has a place for it, the bar's top left corner",
        role ~= nil and role.points[1] == "TOPLEFT" and role.points[2] == plates[1].health)
    check("square", role.width == role.height)
    local crown = plates[1].leader
    check("the leader's crown its mirror: the bar's top right corner, as far in",
        crown.points[1] == "TOPRIGHT" and crown.points[2] == plates[1].health
        and crown.points[4] == -role.points[4] and crown.points[5] == role.points[5])
    check("the others' frames do not", NS.plates.target.roleIcon == nil and NS.plates.player.roleIcon == nil)
    check("no role chosen: no icon", not role.shown)
    units.party1.role, units.party2.role = "TANK", "HEALER"
    Fire("PLAYER_ROLES_ASSIGNED")
    check("a tank's shield", role.shown and role.atlas == "UI-LFG-RoleIcon-Tank-Micro-GroupFinder")
    check("a healer's cross", plates[2].roleIcon.shown
        and plates[2].roleIcon.atlas == "UI-LFG-RoleIcon-Healer-Micro-GroupFinder")
    units.party2.role = "DAMAGER"
    Fire("GROUP_ROSTER_UPDATE")
    check("a damage dealer's sword", plates[2].roleIcon.atlas == "UI-LFG-RoleIcon-DPS-Micro-GroupFinder")
    local secretRole = {}
    secretValues[secretRole] = true
    units.party2.role = secretRole
    local ok = pcall(Fire, "PLAYER_ROLES_ASSIGNED")
    check("a role the client keeps secret: no error, and no icon rather than a guess",
        ok and not plates[2].roleIcon.shown)
    units.party2.role = "HEALER"
    atlases["UI-LFG-RoleIcon-Healer-Micro-GroupFinder"] = nil
    atlases["roleicon-tiny-healer"] = true
    Fire("PLAYER_ROLES_ASSIGNED")
    check("a client without those icons: the older tiny ones", plates[2].roleIcon.atlas == "roleicon-tiny-healer")
    atlases["UI-LFG-RoleIcon-Healer-Micro-GroupFinder"] = true
    check("and the name keeps clear of it, still centred: equal margins both sides",
        plates[1].nameText.anchors[1][4] >= role.width
        and plates[1].nameText.anchors[1][4] == -plates[1].nameText.anchors[2][4])
end

Section("a member out of range: see-through")
do
    -- As the client answers it: in range or not, and whether it could check.
    function UnitInRange(unit)
        local u = units[unit]
        if not u then return false, false end
        if u.rangeSecret then return u.rangeSecret, u.rangeSecret end
        return u.inRange ~= false, u.rangeChecked ~= false
    end
    Tick(0.1)
    check("in range: fully drawn", plates[1].alpha == 1 and plates[2].alpha == 1)
    units.party2.inRange = false
    Fire("UNIT_IN_RANGE_UPDATE", "party2")
    Tick(0.1)
    check("out of range: see-through, as the game's party frames draw one",
        plates[2].alpha == UnitPlate.OUT_OF_RANGE_ALPHA and plates[2].alpha < 1 and plates[1].alpha == 1)
    units.party2.rangeChecked = false
    Fire("UNIT_DISTANCE_CHECK_UPDATE", "party2")
    Tick(0.1)
    check("a range the client could not check: not taken as out of range", plates[2].alpha == 1)
    units.party2.rangeChecked = nil
    local secretFalse = setmetatable({}, { __tostring = function() return "<secret false>" end })
    secretValues[secretFalse] = true
    units.party2.rangeSecret = secretFalse
    Fire("UNIT_IN_RANGE_UPDATE", "party2")
    local ok = pcall(Tick, 0.1)
    check("a secret answer: no error, handed untested to the client to pick the alpha",
        ok and plates[2].alphaFrom == secretFalse and plates[2].alpha == UnitPlate.OUT_OF_RANGE_ALPHA)
    units.party2.rangeSecret = nil
    Core.SetUnlocked(true)
    Tick(0.1)
    check("placing the frames: fully drawn, whatever the range", plates[2].alpha == 1)
    Core.SetUnlocked(false)
    Tick(0.1)
    check("locked again: see-through again", plates[2].alpha == UnitPlate.OUT_OF_RANGE_ALPHA)
    check("only the party's frames fade: the others keep the game's own rules",
        NS.plates.target.alpha == nil or NS.plates.target.alpha == 1)
    units.party2.inRange = nil
    Tick(0.1)
end

Section("the game's party frames: taken away whole")
local hiddenParty = Core.Frames.BlizzardFrames.hiddenParty
check("PartyFrame under a frame of the addon's that never shows: its members, pets and background with it",
    hiddenParty ~= nil and PartyFrame.parentFrame == hiddenParty and not hiddenParty:IsShown())
check("its box in the game's Edit Mode: none (no box in Unlock Mode either)", Core.IsHeld(PartyFrame))
check("no field written onto its frames, nothing else of the game's moved", (function()
    for _, m in ipairs({ PartyFrame.MemberFrame1, PartyFrame.MemberFrame1.PetFrame, PartyFrame }) do
        if rawget(m, "SetAlpha") ~= nil or rawget(m, "Show") ~= nil or rawget(m, "SetParent") ~= nil then return false end
    end
    return true
end)() and PartyFrame.isLocked == nil and PartyFrame.defaultHideSelection == nil
    and #forbiddenCalls == 0, table.concat(forbiddenCalls, ", "))
-- Something putting it back under a shown frame: it shows, and goes back.
PartyFrame.parent, PartyFrame.parentFrame = UIParent, UIParent
for _, hook in ipairs(PartyFrame.hooks.OnShow or {}) do hook(PartyFrame) end
check("put back under a shown frame: straight back under the hidden one", PartyFrame.parentFrame == hiddenParty)

Section("the game's raid-style party frames: gone with it, these stay the party's")
-- The game's raid-style party frames, as CompactPartyFrame_Generate makes
-- them: under PartyFrame, so under the hidden frame too.
local compactParty = CreateFrame("Frame", "CompactPartyFrame", PartyFrame)
compactParty.memberUnitFrames = { CreateFrame("Button", nil, compactParty) }
compactParty.memberUnitFrames[1]:RegisterEvent("UNIT_HEALTH")
compactParty.petUnitFrames = {}
compactParty:RegisterEvent("GROUP_ROSTER_UPDATE")
EditModeManagerFrame.raidStyleParty = true
NS.Refresh()
check("these stay: the addon's column is the party's", plates[1].shown and plates[2].shown
    and stateDrivers[plates[1]] ~= nil)
check("the game's raid-style frames' events off: none of their code runs",
    next(compactParty.events) == nil and next(compactParty.memberUnitFrames[1].events) == nil)
local compact = NewCompactFrame("CompactPartyFrameMember1")
CompactUnitFrame_SetUpFrame(compact, function() end)
local fill = compact.healthBar:GetStatusBarTexture()
check("its frames' health fill: this addon's flat fill", fill.texture == Style.FLAT_TEXTURE)
check("with the sheen and shade over it", Core.Frames.RaidFrames.IsStyled(compact) and (function()
    for _, region in ipairs(compact.healthBar.regions) do
        if region.gradient then return true end
    end
end)())
check("the resource fill too", compact.powerBar:GetStatusBarTexture().texture == Style.FLAT_TEXTURE)
local bg = Style.BACKGROUND_COLOR
check("and the frames' dark background behind them",
    compact.background.colorTexture[1] == bg[1] and compact.background.colorTexture[4] == bg[4]
    and compact.powerBar.background.colorTexture[1] == bg[1])
check("nothing else of theirs changed: the colour is still the game's to set",
    compact.healthBar.statusColor == nil)
local raidFill = earlyRaidFrame.healthBar:GetStatusBarTexture()
check("a raid frame made before the addon loaded is given it at login", raidFill.texture == Style.FLAT_TEXTURE)
local arena = NewCompactFrame("CompactArenaFrameMember1")
CompactUnitFrame_SetUpFrame(arena, function() end)
check("other compact frames (the arena's) keep the game's look",
    arena.healthBar:GetStatusBarTexture().texture == "RaidFrame-Hp-Fill")
EditModeManagerFrame.raidStyleParty = false
NS.Refresh()
check("the game's switch off: these still the party's", plates[1].shown)

Section("placing the column")
Core.SetUnlocked(true)
-- As the game's party frames in Edit Mode: shown, members or not, painted
-- as they really look (the player, where there is no member).
check("unlocked: all four shown as they really look, members or not",
    plates[3].shown and plates[4].shown and plates[4].nameText.text ~= ""
    and not PlacingLook(plates[4].healthBG))
plates[3].left, plates[3].top = 120, 700
plates[3].click.scripts.OnMouseDown(plates[3].click, "LeftButton")
plates[3].click.scripts.OnMouseUp(plates[3].click, "LeftButton")
local top = -1 * (GetScreenHeight() - 700)
check("dragging any of them moves the column: its top worked back from where that one went",
    DB.partyPlaced == true and DB.partyLeft == 120 and math.abs(DB.partyTop - (top + 2 * step)) < 1e-9)
check("and they all follow", plates[1].points[4] == 120 and math.abs(plates[3].points[5] - top) < 1e-9)
Core.SetUnlocked(false)
check("locked: only members that exist", plates[1].shown and not plates[3].shown)

Section("the column sorted as the game sorts its party frames: by role to start")
do
    -- Which frame is at which place: the place's number, from its top.
    local function Place(plate)
        return math.floor((DB.partyTop - plate.points[5]) / step + 0.5) + 1
    end
    check("role by default", DB.partySort == "role")
    units.party1.role, units.party2.role = "DAMAGER", "HEALER"
    units.party3 = Member("Aldo")
    units.party3.role = "TANK"
    Fire("GROUP_ROSTER_UPDATE")
    check("the tank on top, the healer next, damage after",
        Place(plates[3]) == 1 and Place(plates[2]) == 2 and Place(plates[1]) == 3,
        Place(plates[3]) .. Place(plates[2]) .. Place(plates[1]))
    check("the empty place last", Place(plates[4]) == 4)
    units.party4 = Member("Bram")
    units.party4.role = "DAMAGER"
    Fire("GROUP_ROSTER_UPDATE")
    check("one role: by name (Bram before Grumbo)", Place(plates[4]) == 3 and Place(plates[1]) == 4)
    check("each frame keeps its member: only its place moves",
        plates[4].click:GetAttribute("unit") == "party4" and plates[4].nameText.text == "Bram")

    DB.partySort = "group"
    NS.Refresh()
    check("by group: party1 to party4", Place(plates[1]) == 1 and Place(plates[2]) == 2
        and Place(plates[3]) == 3 and Place(plates[4]) == 4)
    DB.partySort = "alphabetical"
    NS.Refresh()
    check("alphabetical: Aldo, Bram, Grumbo, Tessa", Place(plates[3]) == 1 and Place(plates[4]) == 2
        and Place(plates[1]) == 3 and Place(plates[2]) == 4)

    DB.partySort = "role"
    NS.Refresh()
    inCombat = true
    units.party1.role = "TANK"
    units.party3.role = "DAMAGER"
    local ok = pcall(Fire, "PLAYER_ROLES_ASSIGNED")
    check("a role given in combat: nothing moved then (the game refuses it), no error",
        ok and Place(plates[3]) == 1 and #blocked == 0, tostring(#blocked))
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    check("sorted as combat ends", Place(plates[1]) == 1)

    local secretRole = {}
    secretValues[secretRole] = true
    units.party1.role = secretRole
    ok = pcall(Fire, "PLAYER_ROLES_ASSIGNED")
    check("a role the client keeps secret: no error, sorted as having none (last)",
        ok and Place(plates[1]) == 4)
    units.party1.role = "TANK"
    Fire("PLAYER_ROLES_ASSIGNED")
end

Section("Show self: the player's own frame in the column")
do
    local mine = NS.plates.partyplayer
    check("a frame for it, the party's look, the player's unit",
        mine ~= nil and mine.unit == "player" and mine.click:GetAttribute("unit") == "player"
        and mine.width == DB.partyWidth and mine.roleIcon ~= nil)
    check("off (switched off above): not shown", DB.partyShowSelf == false and not mine.shown)
    local column = NS.PartyColumn(DB)
    DB.partyShowSelf = true
    NS.Refresh()
    Tick(0.1)
    check("on: shown in a party, by the game's driver (never in a raid)", mine.shown
        and stateDrivers[mine]:find("group:raid") ~= nil and stateDrivers[mine]:find("@party1,exists") ~= nil)
    local party1 = units.party1
    units.party1 = nil
    Tick(0.1)
    check("nobody else there (the group's flag up or not): not shown", not mine.shown)
    units.party1 = party1
    Tick(0.1)
    check("the column a frame taller", NS.PartyColumn(DB) == column + step)
    units.player.role = "HEALER"
    Fire("PLAYER_ROLES_ASSIGNED")
    local function Place(plate)
        return math.floor((DB.partyTop - plate.points[5]) / step + 0.5) + 1
    end
    check("sorted with the members: a healer after the tank", Place(plates[1]) == 1 and Place(mine) == 2)
    DB.partySort = "group"
    NS.Refresh()
    check("by group: the player first", Place(mine) == 1 and Place(plates[1]) == 2)
    local Auras = NS.UnitAuras
    check("its own auras row, on this frame - not on the player frame",
        Auras.containers.player ~= nil and Auras.containers.player.parent == mine)
    inGroup = false
    units.party1, units.party2, units.party3, units.party4 = nil, nil, nil, nil
    Fire("GROUP_ROSTER_UPDATE")
    check("alone: not shown", not mine.shown)
    -- Joined in a fight (the player, 2026-10-05): the column may not be moved
    -- by addon code then, so the secure layout closes it up.
    local column = UnitPlate.column
    check("a secure handler watches the member count",
        column ~= nil and stateDriverStrings[column].roster:find("@party3,exists") ~= nil
        and column:GetFrameRef("plate5") == mine and column:GetFrameRef("plate2") == plates[2])
    check("alone: the player's own frame last in the order", column:GetAttribute("order5") == 5)
    local function RunLayout(count)
        -- (Secure code: allowed in combat, as the game allows its own.)
        local was = inCombat
        inCombat = false
        assert(load("return function(self, ...) " .. UnitPlate.COLUMN_LAYOUT .. " end"))()(column, tostring(count))
        inCombat = was
    end
    inCombat = true
    inGroup = true
    units.party1, units.party2, units.party3 = Member("Grumbo"), Member("Tessa"), Member("Aldo")
    blocked = {}
    Fire("GROUP_ROSTER_UPDATE")
    check("in combat the addon moves nothing itself", #blocked == 0 and Place(mine) == 5)
    RunLayout(3)
    check("the secure layout: no hole, the player right under the three",
        Place(plates[1]) == 1 and Place(plates[2]) == 2 and Place(plates[3]) == 3 and Place(mine) == 4,
        Place(plates[1]) .. Place(plates[2]) .. Place(plates[3]) .. Place(mine))
    units.party3 = nil
    RunLayout(2)
    check("one leaves in combat: closed up again", Place(mine) == 3)
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    check("combat over: sorted for real (by group: the player first), the order handed to the secure layout",
        Place(mine) == 1 and Place(plates[1]) == 2 and column:GetAttribute("order1") == 5)
    units.party2 = nil
    Fire("GROUP_ROSTER_UPDATE")
    DB.partyShowSelf = false
    DB.partySort = "role"
    NS.Refresh()
    Tick(0.1)
    check("off again: gone, its auras with it", not mine.shown and not Auras.containers.player.shown)
    units.player.role = nil
end

Section("next and previous party member by key, down the column as shown")
do
    local column = UnitPlate.column
    local nextButton, previous = _G.DogsForeverUIPartyNext, _G.DogsForeverUIPartyPrevious
    local snippet = UnitPlate.CYCLE_SNIPPET
    check("two secure buttons that target on a key's press, wrapped by the column",
        nextButton and previous and nextButton.template == "SecureActionButtonTemplate"
        and nextButton:GetAttribute("type") == "target" and nextButton:GetAttribute("useOnKeyDown") == true
        and column.wrapped[nextButton].OnClick == snippet and column.wrapped[previous].OnClick == snippet)
    check("the snippet as the game takes it: no function, no braces",
        not snippet:match("function") and not snippet:match("[{}]"))
    -- (Secure code, run as the game would: the unit it leaves is the one targeted.)
    local function Press(button)
        local chunk = assert(load("local self, button, down = ...\n" .. snippet, "cycle", "t",
            { owner = column, tonumber = tonumber, UnitIsDead = UnitIsDeadOrGhost, UnitIsGhost = UnitIsDeadOrGhost }))
        if chunk(button, "LeftButton", true) == false then return "nothing" end
        return button:GetAttribute("unit")
    end
    local was = { units.party1, units.party2, units.party3, units.target, inGroup, DB.partyShowSelf, DB.partySort }
    inGroup = true
    units.party1, units.party2, units.party3 = Member("Grumbo"), Member("Tessa"), Member("Aldo")
    DB.partyShowSelf, DB.partySort = true, "group"
    NS.Refresh()
    column:SetAttribute("state-roster", "3")
    local seen = {}
    for index = 1, 5 do seen[index] = Press(nextButton) end
    check("next: down the column (by group, the player first), round to the top",
        table.concat(seen, ",") == "player,party1,party2,party3,player", table.concat(seen, ","))
    check("previous: back up, round to the bottom", Press(previous) == "party3" and Press(previous) == "party2")
    units.target = units.party1
    Fire("PLAYER_TARGET_CHANGED")
    check("goes on from whoever was targeted another way", Press(nextButton) == "party2")
    units.target = Member("Stranger")
    Fire("PLAYER_TARGET_CHANGED")
    check("someone outside the party targeted: next starts at the top", Press(nextButton) == "player")
    units.party1.dead = true
    check("a dead member passed over, both ways", Press(nextButton) == "party2" and Press(previous) == "player")
    Press(nextButton)
    units.party2.dead = true
    check("from a member who died meanwhile, on to the next one", Press(nextButton) == "party3")
    units.party1.dead, units.party2.dead = nil, nil
    DB.partyShowSelf = false
    NS.Refresh()
    check("Show self off: the player left out, as in the column", Press(previous) == "party2"
        and Press(nextButton) == "party3" and Press(nextButton) == "party1")
    units.party2.offline = true
    NS.Refresh()
    check("an offline member passed over", column:GetAttribute("offline2") == true and Press(nextButton) == "party3")
    inCombat = true
    units.party2.offline = nil
    check("back online in a fight: still passed over until it ends (the secure side cannot ask)",
        Press(previous) == "party1")
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    check("the fight over: in the cycle again", Press(nextButton) == "party2")
    column:SetAttribute("state-roster", "0")
    check("no party: nothing targeted", Press(nextButton) == "nothing")
    units.party1, units.party2, units.party3, units.target, inGroup, DB.partyShowSelf, DB.partySort = unpack(was, 1, 7)
    NS.Refresh()
    Fire("GROUP_ROSTER_UPDATE")
end

Section("the members' pets: a box left of each")
do
    local Pets = NS.PartyPets
    local pets = {}
    for index = 1, 4 do pets[index] = NS.plates["partypet" .. index] end
    local function Pet(name)
        local pet = Member(name)
        pet.isPlayer, pet.class = false, nil
        return pet
    end
    local gap = 2 * Style.BORDER_INSET + UnitPlate.PARTY_GAP
    check("a box for each of partypet1 to partypet4, on to start", pets[1] and pets[4]
        and pets[2].unit == "partypet2" and DB.partyShowPets == true)
    check("a child of its owner's frame, hung off its left edge, its border clear of the owner's",
        pets[1].parent == plates[1] and pets[1].points[1] == "TOPRIGHT" and pets[1].points[2] == plates[1]
        and pets[1].points[3] == "TOPLEFT" and pets[1].points[4] == -gap and pets[1].points[5] == 0)
    check("as tall as its owner's bars, a fifth of its width",
        pets[1].height == plates[1].height and pets[1].width == math.floor(DB.partyWidth / 5 + 0.5))
    check("no name, no power, no portrait, no icon: a health fill in the frames' shaded look",
        pets[1].nameText == nil and pets[1].power == nil and pets[1].paw == nil and pets[1].badge == nil
        and pets[1].health.sheen ~= nil and pets[1].health.statusTexture.texture == Style.FLAT_TEXTURE)
    check("its shading turned with the bar: the sheen down its left half, the shade its right",
        pets[1].health.sheen.gradient.orientation == "HORIZONTAL"
        and pets[1].health.sheen.gradient.from.a > 0 and pets[1].health.sheen.gradient.to.a == 0
        and pets[1].health.shade.gradient.from.a == 0 and pets[1].health.shade.gradient.to.a > 0)
    local row = pets[1].auras
    check("your own buffs on it, tiny, from its bottom up, inside it",
        row ~= nil and row.unit == "partypet1" and row.parent == pets[1]
        and row.auraGroups.mybuffs.filter == "HELPFUL|PLAYER"
        and row.auraGroups.mybuffs.sample.width == Pets.AURA_SIZE
        and row.points[1] == "BOTTOMLEFT" and row.points[2] == pets[1])
    check("left-click targets the pet, right-click its menu",
        pets[1].click:GetAttribute("unit") == "partypet1" and pets[1].click:GetAttribute("*type1") == "target"
        and pets[1].click:GetAttribute("*type2") == "togglemenu")
    check("left to the game's driver: its pet there, never in a raid",
        stateDrivers[pets[1]] ~= nil and stateDrivers[pets[1]]:find("@partypet1,exists") ~= nil
        and stateDrivers[pets[1]]:find("group:raid") ~= nil)
    check("not a piece of its own in Unlock Mode", Core.Snap.EntryOf(pets[1]) == nil)
    check("no pet: not shown", units.party1 ~= nil and not pets[1].shown)

    units.partypet1 = Pet("Wolf")
    units.partypet1.health, units.partypet1.healthMax = 300, 1200
    Tick(0.1)
    check("a member's pet: shown", pets[1].shown)
    check("its health handed to the fill", pets[1].health.max == 1200 and pets[1].health.value == 300)
    units.partypet1.incoming = 500
    Tick(0.1)
    local heals = pets[1].prediction
    check("the heals on their way over its missing health, from the fill's top up, as on the plates",
        heals.shown and heals.orientation == "VERTICAL" and heals.max == 900 and heals.value == 500
        and heals.anchors[1][2] == pets[1].health:GetStatusBarTexture()
        and heals.statusColor[4] == UnitPlate.HEAL_COLOR[4])
    units.partypet1.incoming = nil
    units.partypet1.healAbsorb = 200
    Tick(0.1)
    local absorb = pets[1].healAbsorb
    check("its heal absorbs over its health, from the fill's top down",
        absorb.shown and absorb.orientation == "VERTICAL" and absorb.reverseFill == true
        and absorb.max == 300 and absorb.value == 200
        and absorb.anchors[2][2] == pets[1].health:GetStatusBarTexture())
    units.partypet1.healAbsorb = nil
    units.partypet1.shield = 400
    Tick(0.1)
    local shield, over = pets[1].shield, pets[1].overShield
    check("its shields: up from the fill's top, and down from the box's top over its health",
        shield.orientation == "VERTICAL" and shield:GetParent() == pets[1].prediction
        and shield.anchors[1][1] == "BOTTOMLEFT" and shield.value == 400 and shield.max == 1200
        and over.orientation == "VERTICAL" and over:GetParent() == pets[1].healAbsorb
        and over.anchors[1][1] == "TOPLEFT" and over.reverseFill == true and over.value == 400)
    units.partypet1.shield = nil
    local fill = pets[1].health.statusColor
    check("its health in the frames' health green",
        fill[1] == Style.HEALTH_COLOR[1] and fill[2] == Style.HEALTH_COLOR[2] and fill[3] == Style.HEALTH_COLOR[3])
    units.partypet1.inRange = false
    Tick(0.1)
    check("the pet out of range: see-through, as the party frames", pets[1].alpha == UnitPlate.OUT_OF_RANGE_ALPHA)
    units.partypet1.inRange, units.party1.inRange = nil, false
    Tick(0.1)
    check("its owner out of range, the pet not: its own fade, not its owner's",
        pets[1].ignoreParentAlpha == true and pets[1].alpha == 1)
    units.party1.inRange = nil

    local room = Pets.Room(DB)
    check("room for it kept clear of the screen's left edge, by every frame of the column alike",
        room == gap + pets[1].width + Style.BORDER_INSET
        and plates[1].clampInsets[1] == -room and plates[4].clampInsets[1] == -room
        and NS.plates.partyplayer.clampInsets[1] == -room)

    DB.partyShowPets = false
    NS.Refresh()
    Tick(0.1)
    check("Show pets off: none, and no room kept", not pets[1].shown and plates[1].clampInsets[1] == 0)
    DB.partyShowPets = true
    NS.Refresh()
    Tick(0.1)
    check("on again", pets[1].shown)
    Core.SetUnlocked(true)
    -- (The player, 2026-10-22: some of the column's frames show one while placing.)
    check("placing: shown off the driver on some members only, a missing pet painted as the player",
        pets[1].shown and not pets[2].shown and pets[3].shown and not pets[4].shown
        and pets[1]:PaintUnit() == "partypet1" and pets[3]:PaintUnit() == "player",
        string.format("%s %s %s %s", tostring(pets[1].shown), tostring(pets[2].shown),
            tostring(pets[3].shown), tostring(pets[4].shown)))
    Core.SetUnlocked(false)
    Tick(0.1)
    check("back after", pets[1].shown)

    units.partypet1 = nil
    Tick(0.1)
    check("dismissed: gone", not pets[1].shown)
end

Section("party auras, beside each frame")
local Auras = NS.UnitAuras
check("on to start, to the right", DB.partyAuras == "right" and Auras.Side("party1") == "right")
local row = Auras.containers.party1
check("each member's own row, hung off its frame's right edge",
    row ~= nil and row.unit == "party1" and row.parent == plates[1]
    and row.points[1] == "TOPLEFT" and row.points[2] == plates[1] and row.points[3] == "TOPRIGHT")
check("your own buffs a group of their own, larger (19 to the others' 15), edged in gold",
    row.auraGroups.mybuffs.filter == "HELPFUL|PLAYER" and row.auraGroups.buffs.filter:find("HELPFUL|!PLAYER", 1, true) == 1
    and row.auraGroups.mybuffs.sample.width == 19 and row.auraGroups.buffs.sample.width == 15)

local Changed, styles = AuraUtil.AuraUpdateChangedType, Enum.CustomAuraButtonDispelTypeTextureStyle
check("sorted by the game's own rule: the container's ProcessAura policy",
    row.policy == CustomAuraContainerAuraProcessingPolicy.ProcessAura)
-- (The player, 2026-10-05: "why not important buffs in party frames too".)
check("everyone else's important buffs: external defensives, important, raid HoTs, the ones you could cast",
    row.auraGroups.external.filter == "HELPFUL|!PLAYER|EXTERNAL_DEFENSIVE"
    and row.auraGroups.important.filter == "HELPFUL|!PLAYER|!EXTERNAL_DEFENSIVE|IMPORTANT"
    and row.auraGroups.hots.filter == "HELPFUL|!PLAYER|!EXTERNAL_DEFENSIVE|!IMPORTANT|RAID_IN_COMBAT"
    and row.auraGroups.buffs.filter == "HELPFUL|!PLAYER|!EXTERNAL_DEFENSIVE|!IMPORTANT|!RAID_IN_COMBAT|RAID")
check("never by the aura's any-player field (true for every player's buff), nor the game's Buff class",
    row.auraGroups.mybuffs.candidateFilters.isFromPlayerOrPlayerPet == true
    and row.auraGroups.buffs.candidateFilters == nil and row.auraGroups.external.candidateFilters == nil)
check("yours first, then the others' in that order, on one row",
    row.auraGroups.mybuffs.layout.layoutIndex == 1 and row.auraGroups.external.layout.layoutIndex == 2
    and row.auraGroups.buffs.layout.layoutIndex == 5 and row.auraGroups.buffs.layout.forceNewLine == false)
check("the debuffs you can dispel first, on a row of their own, in the game's border with its type icon",
    row.auraGroups.dispel.filter == "HARMFUL|RAID" and row.auraGroups.dispel.layout.forceNewLine == true
    and row.auraGroups.dispel.layout.layoutIndex == 6
    and row.auraGroups.dispel.sample.dispelOptions.style == styles.BorderWithIcon)
-- (The player, 2026-10-22: no glow on the icons - "seriously very bad".)
check("the icons wear nothing more: their one dispel border, no glow",
    #row.auraGroups.dispel.sample.dispels == 1 and #row.auraGroups.debuffs.sample.dispels == 1)
farUnits.party1 = true
Auras.Poll(nil, 1)
check("a member too far away to be seen: every buff and debuff once, in two plain groups",
    row.auraGroups.farbuffs.enabled == true and row.auraGroups.fardebuffs.enabled == true
    and row.auraGroups.mybuffs.enabled == false and row.auraGroups.important.enabled == false
    and row.auraGroups.dispel.enabled == false)
farUnits.party1 = nil
Auras.Poll(nil, 1)
check("seen again: the full row", row.auraGroups.farbuffs.enabled == false and row.auraGroups.important.enabled == true)
check("then the other debuffs the game shows, in its plain border",
    row.auraGroups.debuffs.filter == "HARMFUL"
    and row.auraGroups.debuffs.candidateFilters.processedAuraType == Changed.Debuff
    and row.auraGroups.debuffs.sample.dispelOptions.style == styles.Border)
check("the two debuff rows split by the game's classification, one value per aura: never both",
    row.auraGroups.dispel.candidateFilters.processedAuraType == Changed.Dispel)
check("no enemy's order for a party member: no 'mine'/'others' groups",
    row.auraGroups.mine == nil and row.auraGroups.others == nil)

local marks = Auras.indicators.party1
check("on the frame itself: a second container, its top right, growing left",
    marks ~= nil and marks.parent == plates[1] and marks.points[1] == "TOPRIGHT"
    and marks.points[2] == plates[1] and marks.flowPoint == "TOPRIGHT"
    and marks.flowH == AnchorUtil.FlowDirection.Left)
local types, oneEach = 0, true
for _, kind in ipairs(Auras.DISPEL_TYPES) do
    local group = marks.auraGroups[kind]
    if group then
        types = types + 1
        if group.options.maxFrameCount ~= 1 or group.filter ~= "HARMFUL|RAID"
            or not group.candidateFilters.includeDispelTypes[kind]
            or group.sample.dispelOptions.style ~= styles.Icon or group.sample.width ~= 14
            or group.sample.mouseEnabled ~= false then oneEach = false end
    end
end
check("the type of each debuff you can dispel: the game's icon, one per type, 14 across, no mouse",
    types == 5 and oneEach)
-- The dispel wash, EllesmereUI's: a slot per type, its own colour, over the
-- health bar's fill only, under the frame's words.
local magic = marks.auraSlots.washMagic
local washes = 0
for _, kind in ipairs(Auras.DISPEL_TYPES) do
    if marks.auraSlots["wash" .. kind] then washes = washes + 1 end
end
local washTexture, shines = nil, 0
for _, region in ipairs(magic and magic.sample.regions or {}) do
    if region.vertexColor and region.anchors and region.anchors[1] and region.anchors[1][2] == plates[1].health then
        washTexture = region
    end
    if region.gradient then shines = shines + 1 end
end
local blue = { Auras.DispelColour("Magic") }
check("a wash per dispel type, each only for its own type",
    washes == 5 and magic.filter == "HARMFUL|RAID" and magic.candidateFilters.includeDispelTypes.Magic == true)
check("in that type's colour, laid over the health bar's FILL only (the health still reads)",
    washTexture ~= nil and washTexture.vertexColor[1] == blue[1] and washTexture.vertexColor[3] == blue[3]
    and washTexture.anchors[2][2] == plates[1].health:GetStatusBarTexture())
check("in the bars' own look: their flat texture, with the sheen and shade over it - never a plain square",
    washTexture.texture == Style.FLAT_TEXTURE and washTexture.colorTexture == nil and shines == 2)
do
    -- (The player, 2026-10-22: the colour over the health bar should move, to stand out in a fight.)
    local pulse = washTexture.animationGroup
    local fade = pulse and pulse.animations[1]
    check("pulsing for good, as the game's raid frames' dispel overlay: half to full and back, half a second",
        pulse ~= nil and pulse.looping == "BOUNCE" and pulse.playing and fade.kind == "Alpha"
        and fade.fromAlpha == 0.5 and fade.toAlpha == 1 and fade.duration == 0.5)
end
check("one level over the health bar, under the frame's words (name, health): never covering them",
    magic.sample.frameLevel == plates[1].health:GetFrameLevel() + 1
    and plates[1].words:GetFrameLevel() > magic.sample.frameLevel
    and plates[1].nameText.parent == plates[1].words and plates[1].healthText.parent == plates[1].words)
check("and the frame still clicks through it", magic.sample.mouseEnabled == false)
local defensive = marks.auraSlots.defensive
check("a big defensive in the middle of the frame, taking no mouse",
    defensive ~= nil and defensive.filter == "HELPFUL|BIG_DEFENSIVE"
    and defensive.options.sortMethod == AuraContainerSortMethod.BigDefensive
    and defensive.sample.points[1] == "CENTER" and defensive.sample.points[2] == plates[1]
    and defensive.sample.mouseEnabled == false)
check("the target keeps an enemy's order: no dispel row, no frame marks",
    Auras.containers.target == nil or (Auras.containers.target.auraGroups.dispel == nil
    and Auras.indicators.target == nil))
DB.partyAuras = "off"
NS.Refresh()
check("off: none", not Auras.containers.party1.shown and not Auras.indicators.party1.shown)
DB.partyAuras = "right"
NS.Refresh()

Section("the same dispel marks on the player frame, on by default")
do
    local player = NS.plates.player
    local own = Auras.PlayerMarks()
    check("on to start", DB.playerDispel == true)
    check("on the player frame, its top right, shown",
        own ~= nil and own ~= false and own.parent == player and own.points[1] == "TOPRIGHT"
        and own.points[2] == player and own.shown ~= false)
    local kinds, washed = 0, 0
    for _, kind in ipairs(Auras.DISPEL_TYPES) do
        if own.auraGroups[kind] and own.auraGroups[kind].filter == "HARMFUL|RAID" then kinds = kinds + 1 end
        if own.auraSlots["wash" .. kind] then washed = washed + 1 end
    end
    check("a type icon and a wash per dispel type", kinds == 5 and washed == 5)
    check("no big defensive, no aura row of its own", own.auraSlots.defensive == nil)
    DB.playerDispel = false
    NS.Refresh()
    check("off: hidden", not own.shown)
    DB.playerDispel = true
    NS.Refresh()
    check("and back", own.shown)
end

Section("in Unlock Mode: a few made-up buffs and debuffs beside each frame")
do
    Core.SetUnlocked(true)
    local preview = Auras.previews.party1
    local function Shown(row)
        local buffs, debuffs = 0, 0
        for _, button in ipairs(row.buttons) do
            if button:IsShown() then
                if button.aura.kind then debuffs = debuffs + 1 else buffs = buffs + 1 end
            end
        end
        return buffs, debuffs
    end
    local buffs, debuffs = Shown(preview)
    check("where the auras go: off the frame's right edge", preview ~= nil and preview:IsShown()
        and preview.points[1] == "TOPLEFT" and preview.points[2] == plates[1] and preview.points[3] == "TOPRIGHT")
    check("2 to 4 buffs, 1 or 2 debuffs", buffs >= 2 and buffs <= 4 and debuffs >= 1 and debuffs <= 2,
        buffs .. " / " .. debuffs)
    local first, firstDebuff
    for _, button in ipairs(preview.buttons) do
        if button:IsShown() then
            first = first or button
            if button.aura.kind and not firstDebuff then firstDebuff = button end
        end
    end
    check("the debuffs on a row of their own, under the buffs", firstDebuff.points[4] == 0
        and firstDebuff.points[5] < first.points[5])
    check("a debuff's edge in its dispel type's colour",
        (firstDebuff.edge.colorTexture[1] + firstDebuff.edge.colorTexture[2] + firstDebuff.edge.colorTexture[3]) > 0,
        table.concat(firstDebuff.edge.colorTexture, ","))
    local gold = DogsForeverUI.Style.GOLD
    local yoursFirst, yoursLook, othersLook, seenOther = true, true, true, false
    for _, button in ipairs(preview.buttons) do
        if button:IsShown() and not button.aura.kind then
            if button.aura.mine then
                if seenOther then yoursFirst = false end
                if button.edge.colorTexture[1] ~= gold[1] or button.width <= 15 then yoursLook = false end
            else
                seenOther = true
                if button.edge.colorTexture[1] ~= 0 or button.width ~= 15 then othersLook = false end
            end
        end
    end
    check("your own buffs first, larger, edged in gold; everyone else's at 15, edged black",
        first.aura.mine == true and yoursFirst and yoursLook and othersLook)
    local marks = preview.marks
    local firstKind, iconsShown = firstDebuff.aura.kind, 0
    for _, icon in ipairs(marks.icons) do if icon:IsShown() then iconsShown = iconsShown + 1 end end
    check("on the frame: the made-up debuffs' types at its top right, the frame washed in the first's colour",
        marks:IsShown() and marks.allPointsTo == plates[1] and iconsShown >= 1 and iconsShown <= 2
        and marks.icons[1].kind == firstKind and marks.icons[1].points[1] == "TOPRIGHT"
        and marks.wash.vertexColor[1] == select(1, Auras.DispelColour(firstKind))
        and marks.wash.texture == Style.FLAT_TEXTURE
        and marks.wash.anchors[2][2] == plates[1].health:GetStatusBarTexture()
        and marks.washFrame:GetFrameLevel() < plates[1].words:GetFrameLevel())
    check("every party frame its own", Auras.previews.party4 ~= nil and Auras.previews.party4:IsShown())
    check("the real row out of the way meanwhile", not Auras.containers.party1.shown
        and not Auras.indicators.party1.shown)
    DB.partyAuras = "off"
    NS.Refresh()
    check("auras off: none made up either", not preview:IsShown())
    DB.partyAuras = "right"
    NS.Refresh()
    Core.SetUnlocked(false)
    check("Unlock Mode closed: gone, the real row back", not preview:IsShown() and Auras.containers.party1.shown)
end

Section("its settings in its Unlock Mode menu (the options' sections went there, 2026-10-03)")
Core.SetUnlocked(true)
local Snap, Unlock = Core.Snap, Core.Options.Unlock
local partyEntry = Snap.EntryOf(plates[1])
Snap.OpenCog(partyEntry, Snap.movers[partyEntry])
local menu = Unlock.menu
local function MenuRow(label)
    for _, row in ipairs(menu.block.rows) do
        if row.label.text == label then return row end
    end
end
local auras = MenuRow("Auras")
check("one Auras choice for the party: On (beside a column's frames, under a row's) or Off",
    auras ~= nil and #auras.control.choices == 2 and auras.control.choices[1].label == "On")
local layoutRow = MenuRow("Layout")
check("Layout: Column or Row, Column to start", layoutRow ~= nil and #layoutRow.control.choices == 2
    and layoutRow.control.choices[1].label == "Column" and layoutRow.control.choices[2].label == "Row"
    and DB.partyLayout == "column")
do
    -- (The player, 2026-10-23: Layout, Sort by, Auras, Show self, Show pets first.)
    local first = {}
    for index = 1, 5 do first[index] = menu.block.rows[index].label.text end
    check("Layout, Sort by, Auras, Show self, Show pets: the menu's first five",
        table.concat(first, ",") == "Layout,Sort by,Auras,Show self,Show pets", table.concat(first, ","))
end
check("no style switch: one standard", MenuRow("Raid-style frames") == nil)
local sortRow, selfRow = MenuRow("Sort by"), MenuRow("Show self")
check("Sort by: the game's three, Role first", sortRow ~= nil and #sortRow.control.choices == 3
    and sortRow.control.choices[1].label == "Role" and sortRow.control.choices[2].label == "Group"
    and sortRow.control.choices[3].label == "Alphabetical")
check("and Show self", selfRow ~= nil)
local petsRow = MenuRow("Show pets")
check("and Show pets, on to start", petsRow ~= nil and DB.partyShowPets == true)
petsRow.control.scripts.OnClick(petsRow.control)
check("switched off there: kept", DB.partyShowPets == false)
petsRow.control.scripts.OnClick(petsRow.control)
check("and on again", DB.partyShowPets == true)
sortRow.control.scripts.OnClick(sortRow.control)
local sortPopup
for _, f in ipairs(allFrames) do if f.owner == sortRow.control and f:IsShown() then sortPopup = f end end
for _, item in ipairs(sortPopup.items) do if item.label.text == "Group" then item.scripts.OnClick(item) end end
check("a sort picked there: kept, the column sorted at once", DB.partySort == "group"
    and plates[1].points[5] == DB.partyTop)
for _, item in ipairs(sortPopup.items) do if item.label.text == "Role" then item.scripts.OnClick(item) end end
-- The player frame's own menu: no party setting brought over by Show self's row.
Snap.OpenCog(Snap.EntryOf(NS.plates.player), Snap.movers[Snap.EntryOf(NS.plates.player)])
check("the player frame's menu: no Auras choice (the party's Show self row is the party's)",
    MenuRow("Auras") == nil)
Snap.OpenCog(partyEntry, Snap.movers[partyEntry])
local x = menu.xRow.box
local before4 = plates[4].points[4]
x:SetText("300")
x.scripts.OnEnterPressed(x)
check("a typed X moves the whole column, as a change to save",
    plates[4].points[4] ~= before4 and Core.EditModePending(), tostring(plates[4].points[4]))

local unitWidth = DB.barWidth
local width = menu.wRow.box
width:SetText("180")
width.scripts.OnEnterPressed(width)
check("its width is the column's alone", plates[1].width == 180 and plates[4].width == 180
    and DB.barWidth == unitWidth and NS.plates.target.width == unitWidth)
local health = MenuRow("Health height").control
Unlock.RefreshMenu()
check("Health height shows the party's 40 to start", health:GetText() == "40", health:GetText())
health:SetText("50")
health.scripts.OnEnterPressed(health)
check("a new height, and the column steps with it", DB.partyRaidHealth == 50
    and plates[1].health.height == 50 and plates[1].height == 50 + 1 + DB.partyPower
    and plates[2].points[5] == DB.partyTop - UnitPlate.PartyStep(DB))
local layer = MenuRow("Layer").control
layer.scripts.OnClick(layer)
local popup
for _, f in ipairs(allFrames) do if f.owner == layer and f:IsShown() then popup = f end end
for _, item in ipairs(popup.items) do if item.label.text == "High" then item.scripts.OnClick(item) end end
check("and a layer of their own", DB.partyStrata == "HIGH" and plates[1].strata == "HIGH"
    and NS.plates.player.strata ~= "HIGH")
check("each an unsaved change of Unlock Mode's", Core.EditModePending())
Core.CommitEditMode()
Core.SetUnlocked(false)

Section("a row: the party side by side, its pets over each frame, its auras under it")
do
    local Pets, Auras = NS.PartyPets, NS.UnitAuras
    local pet, row = NS.plates.partypet1, Auras.containers.party1
    DB.partyLayout = "row"
    NS.Refresh()
    local across = UnitPlate.PartyStep(DB)
    local function InRow()
        for _, plate in ipairs(plates) do
            if plate.points[4] ~= DB.partyLeft + (plate.partySlot - 1) * across
               or plate.points[5] ~= DB.partyTop then return false end
        end
        return true
    end
    check("each next one a step right: its width, border and the same gap",
        across == DB.partyWidth + 2 * Style.BORDER_INSET + UnitPlate.PARTY_GAP and InRow())
    check("the box one frame tall", NS.PartyColumn(DB) == DB.partyRaidHealth + 1 + DB.partyPower
        + 2 * Style.BORDER_INSET)
    local gap = 2 * Style.BORDER_INSET + UnitPlate.PARTY_GAP
    -- (The player, 2026-10-23: the pets above the frames, the buffs right below.)
    check("each pet over its owner, as wide, a fifth of that tall, its border clear of the owner's",
        pet.points[1] == "BOTTOMLEFT" and pet.points[2] == plates[1] and pet.points[3] == "TOPLEFT"
        and pet.points[4] == 0 and pet.points[5] == gap
        and pet.width == plates[1].width and pet.height == math.floor(DB.partyWidth / 5 + 0.5))
    check("its fill turned: rightwards, the heals and shields with it, the sheen over its top half",
        pet.health.orientation == "HORIZONTAL" and pet.prediction.orientation == "HORIZONTAL"
        and pet.healAbsorb.orientation == "HORIZONTAL" and pet.shield.orientation == "HORIZONTAL"
        and pet.prediction.anchors[1][1] == "TOPLEFT" and pet.prediction.anchors[1][3] == "TOPRIGHT"
        and pet.overShield.anchors[1][1] == "TOPRIGHT"
        and pet.health.sheen.gradient.orientation == "VERTICAL")
    local room = Pets.Room(DB)
    check("room for the pets kept clear of the screen's top edge instead",
        room == gap + pet.height + Style.BORDER_INSET and plates[1].clampInsets[1] == 0
        and plates[1].clampInsets[3] == room)
    check("the auras right under each frame", Auras.Side("party1") == "below" and DB.partyAuras == "right"
        and row.points[1] == "TOPLEFT" and row.points[2] == plates[1] and row.points[3] == "BOTTOMLEFT"
        and row.points[5] > -room)

    local column = UnitPlate.column
    check("the secure layout told", column:GetAttribute("across") == true
        and column:GetAttribute("step") == across)
    -- (Secure code: allowed in combat, as the game allows its own.)
    for _, plate in ipairs(plates) do plate:ClearAllPoints() end
    assert(load("return function(self, ...) " .. UnitPlate.COLUMN_LAYOUT .. " end"))()(column, "4")
    check("so a member joining in combat is laid out along the row too", InRow())

    Core.SetUnlocked(true)
    check("placing: the made-up auras under the frames too",
        Auras.previews.party1.points[3] == "BOTTOMLEFT" and Auras.previews.party1.points[2] == plates[1])
    plates[2].left, plates[2].top = 300, 500
    plates[2].click.scripts.OnMouseDown(plates[2].click, "LeftButton")
    plates[2].click.scripts.OnMouseUp(plates[2].click, "LeftButton")
    check("dragging any of them moves the row: party1's place worked back along it",
        DB.partyLeft == 300 - (plates[2].partySlot - 1) * across
        and math.abs(DB.partyTop - (500 - GetScreenHeight())) < 1e-9 and InRow())
    Core.SetUnlocked(false)

    DB.partyLayout = "column"
    NS.Refresh()
    check("a column again: the pets left of their owners, filling upwards, the auras to the right",
        pet.points[1] == "TOPRIGHT" and pet.points[3] == "TOPLEFT" and pet.height == plates[1].height
        and pet.health.orientation == "VERTICAL" and pet.health.sheen.gradient.orientation == "HORIZONTAL"
        and plates[1].clampInsets[1] == -Pets.Room(DB) and plates[1].clampInsets[3] == 0
        and Auras.Side("party1") == "right" and row.points[3] == "TOPRIGHT"
        and column:GetAttribute("across") == false)
end

Section("the targeted member: a white border over the gold")
do
    local first, second = NS.plates.party1, NS.plates.party2
    units.party2 = units.party2 or Member("Tessa", "PRIEST")
    units.target = units.party2
    Fire("PLAYER_TARGET_CHANGED")
    check("on the targeted member's frame alone",
        second.targetBorder:IsShown() and not first.targetBorder:IsShown()
        and second.targetBorder:GetFrameLevel() > second.border:GetFrameLevel())
    local white = second.targetBorder.lines[1].colour
    check("white, plain to tell from the gold", white[1] == 1 and white[2] == 1 and white[3] == 1)
    units.target = units.party1
    Fire("PLAYER_TARGET_CHANGED")
    check("another member targeted: it moves", first.targetBorder:IsShown() and not second.targetBorder:IsShown())
    units.target = nil
    Fire("PLAYER_TARGET_CHANGED")
    check("nobody in the party targeted: none", not first.targetBorder:IsShown())
    check("the other unit frames have none", NS.plates.target.targetBorder == nil)
end

Section("a follower dungeon's NPC in the party: its class colour, as the game's raid frames")
do
    -- (The player, 2026-10-22: Valeera's frame was the game's blue party selection colour.)
    local was = units.party3
    units.party3 = Member("Valeera", "ROGUE")
    units.party3.isPlayer, units.party3.asPlayer = false, true
    Fire("GROUP_ROSTER_UPDATE")
    Tick(0.1)
    local rogue, colour = RAID_CLASS_COLORS.ROGUE, NS.plates.party3.health.statusColor
    check("the rogue's yellow, untoned", colour and colour[1] == rogue.r and colour[2] == rogue.g
        and colour[3] == rogue.b, colour and table.concat(colour, ","))
    units.party3 = was
    Fire("GROUP_ROSTER_UPDATE")
end

Section("the game's group manager, collapsed: its button alone")
do
    -- (The player, 2026-10-22: the strip of its side showed past the screen's edge.)
    local manager = CreateFrame("Frame", "CompactRaidFrameManager", UIParent)
    manager.Background = manager:CreateTexture()
    manager.displayFrame = CreateFrame("Frame", nil, manager)
    manager.displayFrame:Hide()
    -- (The game's button, its art from its template.)
    local button = CreateFrame("Button", nil, manager)
    local normal, pushed = button:CreateTexture(nil, "OVERLAY"), button:CreateTexture(nil, "OVERLAY")
    function button:GetNormalTexture() return normal end
    function button:GetPushedTexture() return pushed end
    manager.toggleButtonForward = button
    Fire("ADDON_LOADED", "Blizzard_CompactRaidFrames")
    check("collapsed (its options shut): its background gone", manager.Background:GetAlpha() == 0)
    -- (The player, 2026-10-22: "use a better arrow. this looks broken in style".)
    local forward = manager.toggleButtonForward
    local arrow, hover
    for _, region in ipairs(forward.regions or {}) do
        if region.atlas == Core.Style.ARROW.atlas then
            if region.layer == "HIGHLIGHT" then hover = region else arrow = region end
        end
    end
    check("its button the drawer handle's gold arrow, pointing right, the game's stone art faded",
        arrow ~= nil and arrow.rotation == math.pi and forward:GetNormalTexture():GetAlpha() == 0
        and forward:GetPushedTexture():GetAlpha() == 0)
    check("lit under the mouse as the handle is: the arrow added over itself",
        hover ~= nil and hover.blendMode == "ADD" and hover:GetAlpha() == Core.Style.ARROW.highlight)
    manager.displayFrame:Show()
    check("opened: back", manager.Background:GetAlpha() == 1)
    manager.displayFrame:Hide()
    check("shut again: gone again", manager.Background:GetAlpha() == 0)
end

Summary()
