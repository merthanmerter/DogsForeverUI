-- One unit's plate: a health bar over a resource bar, one border round the
-- pair, a hairline between. Above it, in bold: the level, the name centred, a
-- crown or elite emblem at the right; on the bars "505K | 100%". The party's
-- are compact (name inside the bar) in a column, each member's pet in a box
-- beside it (PARTY PETS).
--
-- Health is always secret and power usually: no value is read, only handed
-- to SetValue/SetFormattedText. A secure click button over the plate makes it
-- protected: the game's unit watch or a state driver shows and hides it, and
-- moving or resizing waits for the end of combat.

local UnitPlate = {}
DogsForeverUI.Frames.UnitPlate = UnitPlate

do -- private scope
    local NS = DogsForeverUI.Frames
    local Style = DogsForeverUI.Style
    local Snap = DogsForeverUI.Snap
    local Call = DogsForeverUI.Call
    local IsSecret = issecretvalue

    local HEALTH_COLOR = Style.HEALTH_COLOR
    local HEAL_COLOR = { 0.5, 0.9, 0.6, 0.45 }          -- incoming heals over the missing health
    local HEAL_ABSORB_COLOR = { 0.15, 0, 0, 0.6 }       -- the health a heal absorb will eat
    UnitPlate.HEAL_COLOR = HEAL_COLOR
    UnitPlate.HEAL_ABSORB_COLOR = HEAL_ABSORB_COLOR
    local OFFLINE_COLOR = { 0.5, 0.5, 0.5 }

    local DIVIDER = 1                 -- the hairline, in the border's inner black
    local POWER_TEXT_MIN = 9          -- a floor under the short resource bar's label
    local CIRCLE_GAP = 8              -- the bars to a badge
    local CIRCLE_MIN, CIRCLE_MAX = 14, 30

    -- The row above: its bottom NAME_Y over the bars, clear of the border; the
    -- name keeps NAME_SIDE clear at both ends, so it stays centred.
    local NAME_Y = 6
    local NAME_SIZE, LEVEL_SIZE, CROWN_SIZE = 13, 11, 12
    local ROLE_SIZE = 16
    local ELITE_SIZE = 15
    local NAME_SIDE = 34
    local SMALLEST_TEXT = 8
    local LEADER_ICON = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
    local GUIDE_ATLAS = "UI-HUD-UnitFrame-Player-Group-GuideIcon"
    -- The game's drifting "Zzz" (a 7 x 6 flipbook of 42 frames over 1.5s), or
    -- its older still icon.
    local REST_ATLAS = "UI-HUD-UnitFrame-Player-Rest-Flipbook"
    local REST_ROWS, REST_COLUMNS, REST_FRAMES, REST_TIME = 7, 6, 42, 1.5
    local REST_ICON = "Interface\\CharacterFrame\\UI-StateIcon"
    local REST_ICON_COORDS = { 0, 0.5, 0, 0.421875 }
    local REST_SIZE = 22
    -- The name band behind the row: black, under a gold line, each fading out
    -- over the outer `fade` at both ends (three pieces each). It reaches
    -- NAME_BAND_EXTRA over the text, whose letters sit in its top.
    local NAME_BAND = { alpha = 0.55, lineAlpha = 0.9, fade = 0.35 }
    -- The targeted party member's: the frames' border in white.
    local TARGET_BORDER = {
        radius = Style.DEFAULT_BORDER.radius, gap = 0,
        lines = { { 1, 1, 1, 1 }, { 0.6, 0.6, 0.6, 1 }, Style.DIVIDER_COLOR },
    }
    local NAME_BAND_EXTRA = 3
    UnitPlate.NAME_BAND = NAME_BAND

    -- How far the row and its band reach above the bars.
    function UnitPlate.TopRoom()
        return NAME_Y + NAME_SIZE + 2 + NAME_BAND_EXTRA
    end

    -- The band's look and height, for the titles that wear it (minimap, quests).
    function UnitPlate.NameBand()
        return NAME_BAND, UnitPlate.TopRoom()
    end

    UnitPlate.SMALL_SCALE = 0.6       -- the target's target and the pet

    -- THE PARTY: four frames in a column, party1 on top - or a row, party1 at
    -- the left (Layout) - placed and dragged as one; the name inside the health
    -- bar (over its value on a tall bar, beside it on a short one), the role
    -- and crown in its corners.
    UnitPlate.PARTY_SCALE = 0.8       -- their text, of the unit frames'
    UnitPlate.PARTY_GAP = 2           -- between two frames' borders
    UnitPlate.PARTY_SIZE = 5          -- four members and the player's own
    local PARTY_TALL = 28             -- a bar this tall: the name over its value
    local PARTY_INSET = 4             -- the text from the bar's ends
    -- Shown while the unit exists, never in a raid (the game's raid frames
    -- are the group's there); the player's own (Show self) while there is a party1.
    local EXISTS_CONDITION = "[group:raid] hide; [@%s,exists] show; hide"

    local methods = {}

    -- The party's frames, the player's own (Show self) last.
    local function PartyPlates()
        local plates = NS.plates
        return { plates.party1, plates.party2, plates.party3, plates.party4, plates.partyplayer }
    end

    local function PartyId(plate)
        return plate.isSelf and UnitPlate.PARTY_SIZE or plate.partyIndex
    end

    -- A plate's width, health and power heights: the party's own sizes, the
    -- others the unit frames' at their scale. Never too thin to draw.
    function UnitPlate.Size(db, plate)
        local width, health, power, scale
        if plate.partyIndex then
            width, health, power, scale = db.partyWidth, db.partyRaidHealth, db.partyPower, 1
        else
            width, health, power, scale = db.barWidth, db.barHeight, db.powerHeight, plate.scale or 1
        end
        return math.floor(width * scale + 0.5),
            math.max(4, math.floor(health * scale + 0.5)),
            math.max(3, math.floor(power * scale + 0.5))
    end

    -- What a party frame shows above its bars: nothing (its name is inside).
    function UnitPlate.PartyTopRoom() return 0 end

    local ANY_PARTY = { partyIndex = 1 }    -- any party frame, for its sizes

    UnitPlate.LAYOUTS = {
        { value = "column", label = "Column" },
        { value = "row", label = "Row" },
    }

    -- The party side by side: its pets over each frame, its auras under it.
    function UnitPlate.InRow(db) return db.partyLayout == "row" end

    -- One party frame's top to the next one's, or its left in a row.
    function UnitPlate.PartyStep(db)
        local width, health, power = UnitPlate.Size(db, ANY_PARTY)
        local across = UnitPlate.InRow(db) and width or health + 1 + power + UnitPlate.PartyTopRoom()
        return across + 2 * Style.BORDER_INSET + UnitPlate.PARTY_GAP
    end

    ---------------------------------------------------------------------------
    -- SORTING THE COLUMN, the game's three orders (CRFSort_*): role (tank,
    -- healer, damage, none; then by name), group (the player, then party1-4),
    -- alphabetical. Members first, then the empty places. A frame keeps its
    -- unit and changes its slot - never in combat; sorted again as it ends. A
    -- secret role or name sorts as none.
    ---------------------------------------------------------------------------

    UnitPlate.SORTS = {
        { value = "role", label = "Role" },
        { value = "group", label = "Group" },
        { value = "alphabetical", label = "Alphabetical" },
    }
    local ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3 }    -- none: 4

    local function Plain(value)
        if not IsSecret(value) then return value end
    end

    local function RoleRank(unit)
        return ROLE_ORDER[Plain(UnitGroupRolesAssigned(unit)) or ""] or 4
    end

    local function NameOf(unit)
        local name = Plain(UnitName(unit))
        return type(name) == "string" and name ~= "" and name or nil
    end

    local function GroupRank(plate) return plate.isSelf and 0 or plate.partyIndex end

    local function ByName(a, b)
        local nameA, nameB = NameOf(a.unit), NameOf(b.unit)
        if nameA and nameB and nameA ~= nameB then return nameA < nameB end
        if (nameA == nil) ~= (nameB == nil) then return nameA ~= nil end
        return GroupRank(a) < GroupRank(b)
    end

    local ORDERS = {
        group = function(a, b) return GroupRank(a) < GroupRank(b) end,
        alphabetical = ByName,
        role = function(a, b)
            local rankA, rankB = RoleRank(a.unit), RoleRank(b.unit)
            if rankA ~= rankB then return rankA < rankB end
            return ByName(a, b)
        end,
    }

    -- Whether a plate has someone to show in the column now.
    local function Present(plate, db)
        if plate.isSelf then
            return db.partyShowSelf and (db.unlocked or Plain(UnitExists("party1"))) and true or false
        end
        return Plain(UnitExists(plate.unit)) and true or false
    end

    -- THE COLUMN IN COMBAT: the plates are protected, but a secure handler
    -- may move them. It watches the member count (party1..N fill in order) and
    -- lays the column out again - members first in the order last sorted,
    -- then the empty ones - so a member joining mid-fight leaves no hole.
    local COLUMN_STATE = "[group:raid] 0; [@party4,exists] 4; [@party3,exists] 3; "
        .. "[@party2,exists] 2; [@party1,exists] 1; 0"
    -- (Run with the member count; "plate1".."plate5" the frames, "order1".."order5"
    -- their column order; "across": a row, each a step right of the last.)
    UnitPlate.COLUMN_LAYOUT = [[
        local count = tonumber(...) or 0
        local left, top, step = self:GetAttribute("left"), self:GetAttribute("top"), self:GetAttribute("step")
        if not (left and top and step) then return end
        local showSelf, unlocked = self:GetAttribute("showself"), self:GetAttribute("unlocked")
        local across = self:GetAttribute("across")
        local slot = 0
        for pass = 1, 2 do
            for index = 1, 5 do
                local id = self:GetAttribute("order" .. index)
                local plate = id and self:GetFrameRef("plate" .. id)
                if plate then
                    local here
                    if id == 5 then
                        here = showSelf and (unlocked or count > 0)
                    else
                        here = id <= count
                    end
                    if (pass == 1) == (here and true or false) then
                        local along = slot * step
                        slot = slot + 1
                        plate:ClearAllPoints()
                        if across then
                            plate:SetPoint("TOPLEFT", "$parent", "TOPLEFT", left + along, top)
                        else
                            plate:SetPoint("TOPLEFT", "$parent", "TOPLEFT", left, top - along)
                        end
                    end
                end
            end
        end
    ]]

    -- Who is offline, for the party cycle to pass over (the secure side cannot
    -- ask). Out of combat only, so a change in a fight counts as it ends.
    local function SyncOffline()
        local column = UnitPlate.column
        if not column or InCombatLockdown() then return end
        for index = 1, 4 do
            column:SetAttribute("offline" .. index, Plain(UnitIsConnected("party" .. index)) == false)
        end
    end

    -- What the secure layout needs, out of combat (a protected frame's
    -- attributes), laid out at once so it never disagrees with SortParty.
    local function SyncColumn(db)
        local column = UnitPlate.column
        if InCombatLockdown() then return end
        SyncOffline()
        local order = PartyPlates()
        table.sort(order, function(a, b) return a.partySlot < b.partySlot end)
        for index, plate in ipairs(order) do column:SetAttribute("order" .. index, PartyId(plate)) end
        column:SetAttribute("left", db.partyLeft or 0)
        column:SetAttribute("top", db.partyTop or 0)
        column:SetAttribute("step", UnitPlate.PartyStep(db))
        column:SetAttribute("across", UnitPlate.InRow(db))
        column:SetAttribute("showself", db.partyShowSelf and true or false)
        column:SetAttribute("unlocked", db.unlocked and true or false)
        column:Execute([[ self:RunAttribute("_layout", self:GetAttribute("state-roster")) ]])
    end

    -- CYCLING THE PARTY: a key bound in the options clicks one of these, which
    -- targets the next or previous member down the column as shown. Wrapped
    -- by the column, so it reads its order and member count in combat too;
    -- "cycled" is the id last targeted. The dead and offline are passed over.
    UnitPlate.CYCLE = {
        { name = "DogsForeverUIPartyNext", step = 1, label = "Next party member" },
        { name = "DogsForeverUIPartyPrevious", step = -1, label = "Previous party member" },
    }
    for _, entry in ipairs(UnitPlate.CYCLE) do entry.command = "CLICK " .. entry.name .. ":LeftButton" end
    UnitPlate.CYCLE_SNIPPET = [[
        local count = tonumber(owner:GetAttribute("state-roster")) or 0
        local showSelf, last, step = owner:GetAttribute("showself"), owner:GetAttribute("cycled"), self:GetAttribute("step")
        local first, final, pick, seen
        for index = 1, 5 do
            local id = owner:GetAttribute("order" .. index)
            if id and (id <= count or id == 5 and showSelf and count > 0) then
                local unit = id == 5 and "player" or "party" .. id
                if step < 0 and id == last then pick = final end
                if not (UnitIsDead(unit) or UnitIsGhost(unit) or owner:GetAttribute("offline" .. id)) then
                    first = first or id
                    if step > 0 and seen and not pick then pick = id end
                    final = id
                end
                seen = seen or id == last
            end
        end
        if not first then return false end
        pick = pick or (step > 0 and first or final)
        owner:SetAttribute("cycled", pick)
        self:SetAttribute("unit", pick == 5 and "player" or "party" .. pick)
    ]]

    local function BuildCycle(column)
        for _, entry in ipairs(UnitPlate.CYCLE) do
            local button = CreateFrame("Button", entry.name, UIParent, "SecureActionButtonTemplate")
            button:RegisterForClicks("AnyDown")
            button:SetAttribute("useOnKeyDown", true)
            button:SetAttribute("type", "target")
            button:SetAttribute("step", entry.step)
            column:WrapScript(button, "OnClick", UnitPlate.CYCLE_SNIPPET)
        end
    end

    -- The targeted member's frame in its white border, in combat too; out of
    -- combat the cycle goes on from whoever is targeted now.
    function UnitPlate.FollowTarget()
        local cycled
        for _, plate in ipairs(PartyPlates()) do
            local targeted = Plain(UnitIsUnit(plate.unit, "target")) == true
            if plate.targetBorder then plate.targetBorder:SetShown(targeted) end
            if targeted then cycled = PartyId(plate) end
        end
        local column = UnitPlate.column
        if column and not InCombatLockdown() then column:SetAttribute("cycled", cycled) end
    end

    -- Once, out of combat, as the plates are built (Frames.lua).
    function UnitPlate.BuildColumn()
        local column = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
        for _, plate in ipairs(PartyPlates()) do column:SetFrameRef("plate" .. PartyId(plate), plate) end
        column:SetAttribute("_layout", UnitPlate.COLUMN_LAYOUT)
        column:SetAttribute("_onstate-roster", [[ self:RunAttribute("_layout", newstate) ]])
        UnitPlate.column = column
        RegisterStateDriver(column, "roster", COLUMN_STATE)
        BuildCycle(column)
        SyncColumn(NS.db)
    end

    -- Each party frame's slot for `db.partySort`. Answers true when one moved,
    -- false when none did, nil when combat stopped it.
    function UnitPlate.SortParty(db)
        local here, away = {}, {}
        for _, plate in ipairs(PartyPlates()) do
            if Present(plate, db) then here[#here + 1] = plate else away[#away + 1] = plate end
        end
        table.sort(here, ORDERS[db.partySort] or ORDERS.role)
        table.sort(away, function(a, b) return PartyId(a) < PartyId(b) end)
        for _, plate in ipairs(away) do here[#here + 1] = plate end
        local changed = false
        for slot, plate in ipairs(here) do
            if plate.partySlot ~= slot then changed = true end
        end
        if changed then
            if InCombatLockdown() then return nil end
            for slot, plate in ipairs(here) do plate.partySlot = slot end
        end
        SyncColumn(db)
        return changed
    end

    ---------------------------------------------------------------------------
    -- Reading a unit.
    ---------------------------------------------------------------------------

    -- The badge's size for a plate this tall.
    local function Diameter(height)
        return math.max(CIRCLE_MIN, math.min(CIRCLE_MAX, math.floor(height * 0.85)))
    end

    -- The room a plate's PvP badge takes beside it, for the default placement.
    function UnitPlate.SideRoom()
        local db = NS.db
        return CIRCLE_GAP + Diameter(db.barHeight + DIVIDER + db.powerHeight)
    end

    -- The PvP badge, the game's art and rule (TargetFrameMixin:ShowPvPIcon,
    -- each client's UnitFramePvPIndicatorStyle): free-for-all over the unit's faction.
    local FFA_ATLAS = "UI-HUD-UnitFrame-Player-PVP-FFAIcon"
    local FACTION_ATLAS = DogsForeverUI.RETAIL and {
        Horde = "UI-HUD-UnitFrame-Player-PVP-HordeIcon",
        Alliance = "UI-HUD-UnitFrame-Player-PVP-AllianceIcon",
    } or {
        Horde = "UI-HUD-UnitFrame-SmallCircle-Horde",
        Alliance = "UI-HUD-UnitFrame-SmallCircle-Alliance",
    }
    -- The elite emblem, the nameplates' art; bosses wear the target frame's
    -- skull, by its own boss test.
    local BOSS_ATLAS = "UI-HUD-UnitFrame-Target-HighLevelTarget_Icon"
    local ELITE_ATLAS = {
        elite = "nameplates-icon-elite-gold",
        worldboss = BOSS_ATLAS,
        rareelite = "nameplates-icon-elite-silver",
        rare = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star",
    }

    local function EliteBadge(unit)
        local boss = UnitIsBossMob(unit)
        if not IsSecret(boss) and boss then return BOSS_ATLAS end
        local classification = UnitClassification(unit)
        if IsSecret(classification) or classification == nil then return nil end
        return ELITE_ATLAS[classification]
    end

    -- The art, and whether it is on - possibly a secret (UnitIsPVP), only
    -- ever handed to SetAlphaFromBoolean.
    local function FactionBadge(unit)
        if C_GameRules.IsGameRuleActive(Enum.GameRule.UnitFramePvPContextualDisabled) then return nil end
        local ffa = UnitIsPVPFreeForAll(unit)
        if not IsSecret(ffa) and ffa then return FFA_ATLAS, true end
        local faction = UnitFactionGroup(unit)
        if IsSecret(faction) or faction == nil then return nil end
        local atlas = FACTION_ATLAS[faction]
        if not atlas then return nil end
        return atlas, UnitIsPVP(unit)
    end

    -- Each frame's name while it is being placed.
    local PLACEMENT_NAMES = {
        player = "Player", target = "Target", focus = "Focus", targettarget = "ToT", pet = "Pet",
        party1 = "Party 1", party2 = "Party 2", party3 = "Party 3", party4 = "Party 4",
    }

    -- Shown as a player: a follower dungeon's NPCs too, as the game's raid frames
    -- class-colour them (CompactUnitFrame_UpdateHealthColor).
    local function AsPlayer(unit)
        if UnitIsPlayer(unit) then return true end
        local treated = UnitTreatAsPlayerForDisplay and UnitTreatAsPlayerForDisplay(unit)
        return not IsSecret(treated) and treated == true
    end

    -- A player wears its class (a secret one through C_ClassColor, never
    -- read), never a reaction; a friendly pet the plain colour; anything else
    -- the game's selection colour. The class flag says "do not tone".
    local function GameHealthColour(unit)
        if AsPlayer(unit) then
            local _, class = UnitClass(unit)
            if IsSecret(class) then
                local ok, colour = pcall(C_ClassColor.GetClassColor, class)
                if ok and type(colour) == "table" then return colour.r, colour.g, colour.b, true end
                return nil
            end
            local colour = class ~= nil and RAID_CLASS_COLORS[class]
            if colour then return colour.r, colour.g, colour.b, true end
            return nil
        end
        if UnitPlayerControlled(unit) and UnitIsFriend("player", unit) then return nil end

        local r, g, b = UnitSelectionColor(unit)
        if not IsSecret(r) and not IsSecret(g) and not IsSecret(b) and type(r) == "number" then
            return r, g, b
        end
        local reaction = UnitReaction(unit, "player")
        if not IsSecret(reaction) and reaction ~= nil then
            local colour = FACTION_BAR_COLORS[reaction]
            if colour then return colour.r, colour.g, colour.b end
        end
        return nil
    end

    -- An offline unit grey and full, a dead one empty, as the raid frames
    -- draw them. UnitIsConnected and UnitIsDeadOrGhost are never secret.
    local function Offline(unit) return not UnitIsConnected(unit) end

    -- The word in place of the health value, or nil.
    local function Status(unit)
        if Offline(unit) then return PLAYER_OFFLINE end
        if UnitIsDeadOrGhost(unit) then return DEAD end
    end

    local function HealthColour(unit)
        if Offline(unit) then return unpack(OFFLINE_COLOR) end
        if NS.db.classColors then
            local r, g, b, isClass = GameHealthColour(unit)
            if isClass then return r, g, b end       -- (asked of the flag: r may be secret)
            if r then return Style.Tone(r, g, b, Style.HEALTH_TONE) end
        end
        return unpack(HEALTH_COLOR)
    end

    -- Retail: a spec whose own power is not mana (shadow, balance, elemental)
    -- keeps its mana under the player's health, the game's second bar; its own
    -- power has the castbar group's row (Castbar\Rows.lua). Nil: the unit's power.
    local SecondaryPower = DogsForeverUI.RETAIL and GetUnitSecondaryPowerInfo
    local function ShownPower(unit)
        if SecondaryPower and unit == "player" then return SecondaryPower(unit) end
    end

    -- Mana in MANA_COLOR, every other resource exactly the game's
    -- PowerBarColor, untoned (toning read focus as rage).
    local function PowerColour(unit)
        if Offline(unit) then return unpack(OFFLINE_COLOR) end
        local powerType, token = ShownPower(unit)
        if powerType then return Style.PowerColour(powerType, token) end
        return Style.PowerColour(UnitPowerType(unit))
    end

    -- "??" where the game will not put a number on it; a secret level is
    -- only formatted.
    local function ShowLevel(fontString, unit)
        local level = UnitLevel(unit)
        if IsSecret(level) then
            fontString:SetFormattedText("%d", level)
        elseif type(level) ~= "number" or level < 0 then
            fontString:SetText("??")
        else
            fontString:SetText(tostring(level))
        end
    end

    -- "505K | 100%": shortened and scaled by the game, both secret.
    local function ShowValue(label, value, percent)
        local short = AbbreviateNumbers(value)
        if not IsSecret(percent) and percent == nil then
            label:SetText(short)
        else
            label:SetFormattedText("%s | %d%%", short, percent)
        end
    end

    -- The difficulty colour; gold for the player and a secret level.
    local function LevelColour(unit)
        local isPlayer = UnitIsUnit(unit, "player")
        local level = UnitLevel(unit)
        if (IsSecret(isPlayer) or not isPlayer) and not IsSecret(level) then
            local colour = GetCreatureDifficultyColor(level)
            if type(colour) == "table" and colour.r then return colour.r, colour.g, colour.b end
        end
        return unpack(Style.GOLD)
    end

    ---------------------------------------------------------------------------
    -- Building one.
    ---------------------------------------------------------------------------

    -- A bar in the flat fill; `sheen` adds the soft shading.
    local function NewBar(parent, level, sheen)
        local bar = CreateFrame("StatusBar", nil, parent)
        bar:SetFrameLevel(level)
        Style.SetBarFill(bar)
        if sheen then Style.AddSheen(bar) end
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        return bar
    end

    -- Round `frame.health` (a plate's or a pet box's): incoming heals past the
    -- fill (at `level`), heal absorbs back over it, and EllesmereUI's two
    -- health-sized shield bars - one on from the fill inside the heal box, one
    -- back from the far end inside the heal absorb's. Laid out by TurnHeals.
    local function AddHeals(frame, level)
        local health = frame.health
        frame.prediction = NewBar(frame, level, false)
        frame.prediction:SetStatusBarColor(unpack(HEAL_COLOR))
        frame.healAbsorb = NewBar(frame, health:GetFrameLevel() + 1, false)
        frame.healAbsorb:SetReverseFill(true)
        frame.healAbsorb:SetStatusBarColor(unpack(HEAL_ABSORB_COLOR))

        local function Shield(box, reverse)
            box:SetClipsChildren(true)
            local bar = NewBar(box, box:GetFrameLevel() + 1, false)
            Style.ShieldArt(bar:GetStatusBarTexture(), Style.SHIELD_FILL)
            bar:SetReverseFill(reverse)
            local lines = bar:CreateTexture(nil, "OVERLAY")
            Style.ShieldArt(lines, Style.SHIELD_LINES)
            lines:SetAllPoints(bar:GetStatusBarTexture())
            return bar
        end
        frame.shield = Shield(frame.prediction, false)
        frame.overShield = Shield(frame.healAbsorb, true)
        health:SetScript("OnSizeChanged", function(_, width, height)
            frame.shield:SetSize(width, height)
            frame.overShield:SetSize(width, height)
        end)
    end

    -- `frame`'s health and heals filling upwards (`vertical`) or rightwards,
    -- the health's sheen and shade turned with them.
    local function TurnHeals(frame, vertical)
        local health = frame.health
        local fill = health:GetStatusBarTexture()
        local start = vertical and "BOTTOMLEFT" or "TOPLEFT"
        local finish = vertical and "TOPRIGHT" or "BOTTOMRIGHT"
        local edge = vertical and "TOPLEFT" or "TOPRIGHT"      -- the fill's far end
        for _, bar in ipairs({ health, frame.prediction, frame.healAbsorb, frame.shield, frame.overShield }) do
            bar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
        end
        if health.sheen then Style.TurnSheen(health.sheen, health.shade, fill, vertical) end
        frame.prediction:ClearAllPoints()
        frame.prediction:SetPoint(start, fill, edge)
        frame.prediction:SetPoint(finish, health, finish)
        frame.healAbsorb:ClearAllPoints()
        frame.healAbsorb:SetPoint(start, health, start)
        frame.healAbsorb:SetPoint(finish, fill, finish)
        frame.shield:ClearAllPoints()
        frame.shield:SetPoint(start, frame.prediction, start)
        frame.overShield:ClearAllPoints()
        frame.overShield:SetPoint(edge, health, edge)
    end

    -- A secure unit button over `owner` with the game's own attributes
    -- (togglemenu picks the unit's menu itself); the unit's tooltip while not placing.
    local function NewClick(owner, name, unit, level)
        local click = CreateFrame("Button", name, owner, "SecureUnitButtonTemplate")
        click:SetAllPoints(owner)
        click:SetFrameLevel(level)
        click:RegisterForClicks("AnyUp")
        click:SetAttribute("unit", unit)
        click:SetAttribute("*type1", "target")
        click:SetAttribute("*type2", "togglemenu")
        click:SetScript("OnEnter", function()
            if NS.db.unlocked then return end
            GameTooltip_SetDefaultAnchor(GameTooltip, click)
            GameTooltip:SetUnit(unit)
            GameTooltip:Show()
        end)
        click:SetScript("OnLeave", function() GameTooltip:Hide() end)
        owner.click = click
        return click
    end

    -- A party member's role, the game's raid-frame icon (or the older tiny
    -- one); none, or a secret, is no icon.
    local ROLE_ICONS = {
        TANK = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder",
        HEALER = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
        DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder",
    }
    local ROLE_FALLBACK = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }
    UnitPlate.ROLE_ICONS = ROLE_ICONS

    -- Its own size at PARTY_SCALE, or the health bar less a margin.
    local function PartyRoleSize(healthHeight)
        local role = math.floor(ROLE_SIZE * UnitPlate.PARTY_SCALE + 0.5)
        return math.max(SMALLEST_TEXT, math.min(role, healthHeight - 4))
    end

    local function ShowRole(texture, unit)
        local role = UnitGroupRolesAssigned(unit)
        local atlas = not IsSecret(role) and ROLE_ICONS[role]
        if atlas and not Style:HasAtlas(atlas) then atlas = ROLE_FALLBACK[role] end
        if not atlas or not Style:HasAtlas(atlas) then
            texture:Hide()
            return
        end
        texture:SetAtlas(atlas)
        texture:Show()
    end

    -- The crown while the unit leads any group (the instance group too), the
    -- guide mark in a dungeon finder group. A secret answer goes to
    -- SetAlphaFromBoolean. The player's crown needs a group: this client says
    -- the player leads while solo.
    local function IsMe(unit)
        if unit == "player" then return true end
        local same = UnitIsUnit(unit, "player")
        return not IsSecret(same) and same == true
    end

    local function ShowLeader(texture, unit)
        if IsMe(unit) and not IsInGroup() then
            texture:SetAlpha(0)
            return
        end
        if HasLFGRestrictions() == true and Style:HasAtlas(GUIDE_ATLAS) then
            texture:SetAtlas(GUIDE_ATLAS)
        else
            texture:SetTexture(LEADER_ICON)
        end
        local leads = UnitLeadsAnyGroup(unit)
        if IsSecret(leads) then
            texture:SetAlphaFromBoolean(leads, 1, 0)
        else
            texture:SetAlpha(leads and 1 or 0)
        end
    end

    -- A filled circle: a plain colour behind a circular mask.
    local function NewCircle(parent, layer, r, g, b, a)
        local texture = parent:CreateTexture(nil, layer)
        texture:SetColorTexture(r, g, b, a)
        local mask = parent:CreateMaskTexture()
        mask:SetAtlas("CircleMask")
        mask:SetAllPoints(texture)
        texture:AddMaskTexture(mask)
        return texture
    end

    -- A badge: ring, dark middle and emblem, shown or faded as one.
    local function NewBadge(plate)
        local badge = CreateFrame("Frame", nil, plate)
        badge:SetFrameLevel(plate:GetFrameLevel() + 2)
        local border = Style.BORDER_COLOR
        badge.ring = NewCircle(badge, "ARTWORK", border[1], border[2], border[3], 1)
        badge.ring:SetAllPoints(badge)
        badge.disc = NewCircle(badge, "OVERLAY", 0, 0, 0, 0.85)
        badge.disc:SetPoint("TOPLEFT", 1, -1)
        badge.disc:SetPoint("BOTTOMRIGHT", -1, 1)
        badge.icon = badge:CreateTexture(nil, "OVERLAY", nil, 2)
        badge.icon:SetPoint("CENTER", badge, "CENTER", 0, 0)
        badge:Hide()
        return badge
    end

    -- Shown by its alpha, as the crown: the plate is protected.
    local function NewRest(plate)
        local rest = plate.words:CreateTexture(nil, "OVERLAY")
        rest:SetAlpha(0)
        if Style:HasAtlas(REST_ATLAS) then
            rest:SetAtlas(REST_ATLAS)
            local loop = rest:CreateAnimationGroup()
            loop:SetLooping("REPEAT")
            local book = loop:CreateAnimation("FlipBook")
            book:SetDuration(REST_TIME)
            book:SetOrder(1)
            book:SetFlipBookRows(REST_ROWS)
            book:SetFlipBookColumns(REST_COLUMNS)
            book:SetFlipBookFrames(REST_FRAMES)
            book:SetFlipBookFrameWidth(0)
            book:SetFlipBookFrameHeight(0)
            rest.loop = loop
        else
            rest:SetTexture(REST_ICON)
            rest:SetTexCoord(unpack(REST_ICON_COORDS))
        end
        return rest
    end

    local function ShowRest(rest)
        local resting = IsResting()
        local on = not IsSecret(resting) and resting and true or false
        rest:SetAlpha(on and 1 or 0)
        if not rest.loop then return end
        if on and not rest.loop:IsPlaying() then
            rest.loop:Play()
        elseif not on and rest.loop:IsPlaying() then
            rest.loop:Stop()
        end
    end

    -- A band texture in three pieces: fading in, solid, fading out.
    local function Faded(plate, sub, colour, alpha, shown)
        local pieces = {}
        local r, g, b = colour[1], colour[2], colour[3]
        for i = 1, 3 do
            local piece = plate:CreateTexture(nil, "BACKGROUND", nil, sub)
            piece:SetTexture(Style.FLAT_TEXTURE)
            if i == 2 then
                piece:SetVertexColor(r, g, b, alpha)
            elseif i == 1 then
                piece:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, alpha))
            else
                piece:SetGradient("HORIZONTAL", CreateColor(r, g, b, alpha), CreateColor(r, g, b, 0))
            end
            piece:SetShown(shown)
            pieces[i] = piece
        end
        return pieces
    end

    -- One line, cut with an ellipsis.
    local function NewLabel(parent)
        local label = parent:CreateFontString(nil, "OVERLAY")
        Style.SingleLine(label)
        return label
    end

    -- unit        the unit token this plate draws
    -- label       its frame name's end: "Player", "Target", "Party1"...
    -- scale       of the configured size, for the small frames
    -- partyIndex  0 for the player's own frame in the party's column
    function UnitPlate.New(unit, label, scale, partyIndex)
        local plate = CreateFrame("Frame", "DogsForeverUI.Frames" .. label, UIParent)
        local base = plate:GetFrameLevel()

        plate.unit = unit
        plate.key = unit                    -- playerLeft, targetTop...
        plate.scale = scale or 1
        plate.partyIndex = partyIndex or tonumber(unit:match("^party(%d)$"))
        plate.isSelf = plate.partyIndex == 0
        local party = plate.partyIndex ~= nil
        if party then
            plate.key = "party"
            plate.partySlot = PartyId(plate)
        end
        -- Badges outwards from the middle of the screen.
        plate.badgeOnLeft = not party and (unit == "player" or unit == "focus")
        -- The target's target can change with no event: read every frame.
        plate.pollsIdentity = unit == "targettarget"
        plate:SetMovable(true)
        plate:SetClampedToScreen(true)

        -- Shown and hidden by the game (ApplyVisibility), from this attribute;
        -- repainted as it shows, the frames' timer woken.
        plate:SetAttribute("unit", unit)
        plate:SetScript("OnShow", function(self)
            self:Update()
            NS:Show()
        end)
        -- A party member's range on its own events.
        if party then
            local listener = CreateFrame("Frame")
            listener:RegisterUnitEvent("UNIT_IN_RANGE_UPDATE", unit)
            listener:RegisterUnitEvent("UNIT_DISTANCE_CHECK_UPDATE", unit)
            listener:SetScript("OnEvent", function() plate:UpdateRange(NS.db.unlocked) end)
        end

        plate.health = NewBar(plate, base + 2, true)
        plate.power = NewBar(plate, base + 2, true)
        AddHeals(plate, base + 1)
        TurnHeals(plate, false)
        plate.healthBG = Style.SetBackground(plate:CreateTexture(nil, "BACKGROUND"))
        plate.healthBG:SetAllPoints(plate.health)
        plate.powerBG = Style.SetBackground(plate:CreateTexture(nil, "BACKGROUND"))
        plate.powerBG:SetAllPoints(plate.power)

        plate.healthSpark = Style.AddSpark(plate.health)
        plate.powerSpark = Style.AddSpark(plate.power)
        plate.divider = plate:CreateTexture(nil, "OVERLAY")
        plate.divider:SetColorTexture(unpack(Style.DIVIDER_COLOR))
        plate.border = Style.AddBorder(plate)
        -- A party member targeted: a white border over the gold (FollowTarget).
        if party then
            plate.targetBorder = Style.AddBorder(plate, TARGET_BORDER)
            plate.targetBorder:SetFrameLevel(plate.border:GetFrameLevel() + 1)
            plate.targetBorder:Hide()
        end

        -- The words and icons on a frame of their own, over the bars and a
        -- party frame's dispel wash (UnitAuras.lua). Takes no mouse.
        plate.words = CreateFrame("Frame", nil, plate)
        plate.words:SetAllPoints(plate)
        plate.words:SetFrameLevel(base + 6)
        plate.levelText = NewLabel(plate.words)
        plate.levelText:SetAlpha(party and 0 or 1)
        plate.nameText = NewLabel(plate.words)
        plate.nameText:SetTextColor(1, 1, 1)
        plate.healthText = NewLabel(plate.words)
        plate.powerText = NewLabel(plate.words)
        plate.leader = plate.words:CreateTexture(nil, "OVERLAY")
        plate.leader:SetTexture(LEADER_ICON)
        plate.leader:SetAlpha(0)
        if unit == "player" and not party then plate.rest = NewRest(plate) end
        if party then
            plate.roleIcon = plate.words:CreateTexture(nil, "OVERLAY")
            plate.roleIcon:Hide()
        end

        -- The name band, under everything; the border is drawn over it.
        plate.nameBand = Faded(plate, -8, { 0, 0, 0 }, NAME_BAND.alpha, not party)
        plate.nameLineTop = Faded(plate, -7, Style.BORDER_COLOR, NAME_BAND.lineAlpha, not party)

        if unit == "target" or unit == "focus" then
            plate.eliteBadge = NewBadge(plate)
            plate.pvpBadge = NewBadge(plate)
            plate.castbar = NS.UnitCastbar.New(plate)
        end

        -- The pet's happiness: the game's own indicator, with its tooltip,
        -- events and rule (hunters' pets only; Classic's, none on retail). Not secure.
        if unit == "pet" and not DogsForeverUI.RETAIL then
            plate.happiness = CreateFrame("Frame", nil, plate, "PetFrameHappinessTemplate")
            plate.happiness:SetFrameLevel(base + 4)
        end

        -- Snapped by the bars and the name row over them. The party is one
        -- column: any frame dragged takes the others along, and they never
        -- snap to one another.
        local function Save() plate:SavePosition() end
        local function PartyOthers()
            local list = {}
            for _, other in ipairs(PartyPlates()) do
                if other ~= plate then list[#list + 1] = other end
            end
            return list
        end
        Snap.Register(plate, {
            group = party and "party" or nil,
            extra = function()
                return 0, 0, party and UnitPlate.PartyTopRoom() or UnitPlate.TopRoom() * plate.scale, 0
            end,
            parts = party and PartyOthers or nil,
            moveWith = party and PartyOthers or nil,
            save = Save,
            name = function() return PLACEMENT_NAMES[plate.unit] or plate.unit end,
            id = party and "party" or unit,
        })
        local click = NewClick(plate, "DogsForeverUI.Frames" .. label .. "Click", unit, base + 3)
        Snap.Draggable(click, NS, Save, plate)

        for name, method in pairs(methods) do plate[name] = method end
        return plate
    end

    ---------------------------------------------------------------------------
    -- What a plate can do.
    ---------------------------------------------------------------------------

    -- How far a party frame's slot is from party1's: down the column, or
    -- right along the row.
    function methods:SlotOffset(db)
        local along = (self.partySlot - 1) * UnitPlate.PartyStep(db)
        if UnitPlate.InRow(db) then return along, 0 end
        return 0, -along
    end

    -- Its own saved place, or the party's moved on to its slot.
    function methods:PlaceOf(db)
        local left, top = db[self.key .. "Left"] or 0, db[self.key .. "Top"] or 0
        if not self.partyIndex then return left, top end
        local x, y = self:SlotOffset(db)
        return left + x, top + y
    end

    -- THE ROW ABOVE: the level, the name centred between equal margins, the
    -- crown at the right end; the band from the frame's top up, its line one
    -- real pixel tall.
    function methods:LayoutRow(width, Sized)
        local scale = self.scale
        local y, side = NAME_Y * scale, NAME_SIDE * scale
        self.levelText:SetJustifyH("LEFT")
        self.levelText:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 2, y)
        self.nameText:SetJustifyH("CENTER")
        self.nameText:SetPoint("BOTTOMLEFT", self, "TOPLEFT", side, y)
        self.nameText:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -side, y)
        Style.SetBoldFont(self.nameText, Sized(NAME_SIZE))
        self.leader:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -2, y)

        local band = UnitPlate.TopRoom() * scale
        local edge = math.floor(width * NAME_BAND.fade + 0.5)
        local from, to = { 0, edge, width - edge }, { edge, width - edge, width }
        local function Across(pieces, point, top, height)
            for i, piece in ipairs(pieces) do
                piece:ClearAllPoints()
                piece:SetPoint(point, self, "TOPLEFT", from[i], top)
                piece:SetWidth(to[i] - from[i])
                if height then
                    piece:SetHeight(height)
                elseif PixelUtil then
                    PixelUtil.SetHeight(piece, 1, 1)
                else
                    piece:SetHeight(1)
                end
            end
        end
        Across(self.nameBand, "BOTTOMLEFT", 0, band)
        Across(self.nameLineTop, "TOPLEFT", band)

        if self.rest then
            local rest = Sized(REST_SIZE)
            self.rest:ClearAllPoints()
            self.rest:SetSize(rest, rest)
            self.rest:SetPoint("BOTTOMLEFT", self.levelText, "TOPLEFT", -2, 0)
        end
        -- The elite emblem takes the crown's corner (UpdateBadges).
        self.eliteSize, self.cornerY = Sized(ELITE_SIZE), y
        self.healthText:SetJustifyH("CENTER")
        self.healthText:SetPoint("CENTER", self.health, "CENTER", 0, 0)
    end

    -- Text measured off screen in a label's font: the labels' own texts are secret.
    local measure = UIParent:CreateFontString(nil, "OVERLAY")
    measure:Hide()
    local function TextWidth(label, text)
        measure:SetFont(label:GetFont())
        measure:SetText(text)
        return measure:GetUnboundedStringWidth()
    end
    local NAME_LEAST = "W..."           -- the least name worth drawing: a letter and the dots
    local VALUE_MOST = "888K | 100%"    -- the widest value (ShowValue)

    -- A party frame: no row above, the name inside the health bar - none at
    -- all where not even a letter of it fits (the game would draw "..").
    function methods:LayoutParty(db, healthHeight, Sized)
        local inset = PARTY_INSET
        -- "Offline" or "Dead" takes the value's place even with the value off.
        local valued = (db.showHealthText or self.status) and true or false
        local tall = healthHeight >= PARTY_TALL
        local role = PartyRoleSize(healthHeight)
        Style.SetBoldFont(self.nameText, math.max(SMALLEST_TEXT,
            math.min(Sized(NAME_SIZE), math.floor(healthHeight * (valued and tall and 0.4 or 0.6)))))
        -- The role in the bar's top left corner (its left end on a short
        -- bar), the crown its mirror on the right.
        local side, y = tall and "TOP" or "", tall and -2 or 0
        local room = self.health:GetWidth() - 2 * (inset + role)
        if valued and not tall then
            room = room - inset - TextWidth(self.healthText, self.status or VALUE_MOST)
        end
        self.nameText:SetShown(room >= TextWidth(self.nameText, NAME_LEAST))
        self.roleIcon:ClearAllPoints()
        self.roleIcon:SetSize(role, role)
        self.roleIcon:SetPoint(side .. "LEFT", self.health, side .. "LEFT", 2, y)
        self.leader:SetPoint(side .. "RIGHT", self.health, side .. "RIGHT", -2, y)
        if valued and tall then
            local off = math.floor(healthHeight * 0.12 + 0.5)
            self.nameText:SetJustifyH("CENTER")
            self.nameText:SetPoint("TOPLEFT", self.health, "TOPLEFT", inset + role, -off)
            self.nameText:SetPoint("TOPRIGHT", self.health, "TOPRIGHT", -(inset + role), -off)
            self.healthText:SetJustifyH("CENTER")
            self.healthText:SetPoint("BOTTOM", self.health, "BOTTOM", 0, off)
        elseif valued then
            self.healthText:SetJustifyH("RIGHT")
            self.healthText:SetPoint("RIGHT", self.health, "RIGHT", -(inset + role), 0)
            self.nameText:SetJustifyH("LEFT")
            self.nameText:SetPoint("LEFT", self.health, "LEFT", inset + role, 0)
            self.nameText:SetPoint("RIGHT", self.healthText, "LEFT", -inset, 0)
        else
            self.nameText:SetJustifyH("CENTER")
            self.nameText:SetPoint("LEFT", self.health, "LEFT", inset + role, 0)
            self.nameText:SetPoint("RIGHT", self.health, "RIGHT", -(inset + role), 0)
        end
    end

    -- Everything that follows a setting: size, place, look, fonts.
    function methods:Refresh()
        local db = NS.db
        local scale = self.scale
        local width, healthHeight, powerHeight = UnitPlate.Size(db, self)

        -- A protected frame's calls: laid out as combat ends (Frames.lua).
        if not InCombatLockdown() then
            self:ClearAllPoints()
            self:SetFrameStrata((self.partyIndex and db.partyStrata or db.frameStrata) or "MEDIUM")
            self:SetWidth(width)
            self:SetHeight(healthHeight + DIVIDER + powerHeight)
            self:SetPoint("TOPLEFT", self:PlaceOf(db))
            -- The party keeps its pets' room clear of the screen's edge.
            if self.partyIndex then
                local room = db.partyShowPets and NS.PartyPets.Room(db) or 0
                if UnitPlate.InRow(db) then
                    self:SetClampRectInsets(0, 0, room, 0)
                else
                    self:SetClampRectInsets(-room, 0, 0, 0)
                end
            end
            -- No click actions while placing, so a drag does not target.
            self.click:SetAttribute("*type1", not db.unlocked and "target" or nil)
            self.click:SetAttribute("*type2", not db.unlocked and "togglemenu" or nil)
            -- StartMoving sets it; the client's layout cache must not win
            -- over the place saved here.
            self:SetUserPlaced(false)
        end

        self.health:ClearAllPoints()
        self.health:SetPoint("TOPLEFT", 0, 0)
        self.health:SetSize(width, healthHeight)
        self.divider:ClearAllPoints()
        self.divider:SetPoint("TOPLEFT", 0, -healthHeight)
        self.divider:SetSize(width, DIVIDER)
        self.power:ClearAllPoints()
        self.power:SetPoint("TOPLEFT", 0, -(healthHeight + DIVIDER))
        self.power:SetSize(width, powerHeight)
        Style.PinSpark(self.healthSpark, self.health)
        Style.PinSpark(self.powerSpark, self.power)

        local function Sized(size)
            return math.max(SMALLEST_TEXT, math.floor(size * scale + 0.5))
        end
        for _, label in ipairs({ self.levelText, self.nameText, self.healthText, self.powerText }) do
            label:ClearAllPoints()
        end
        Style.SetBoldFont(self.levelText, Sized(LEVEL_SIZE))
        local crown = Sized(CROWN_SIZE)
        self.leader:ClearAllPoints()
        self.leader:SetSize(crown, crown)
        self.powerText:SetJustifyH("CENTER")
        self.powerText:SetPoint("CENTER", self.power, "CENTER", 0, 0)
        -- (The value's font first: a party frame's name room is measured with it.)
        Style.SetFont(self.health, self.healthText, db.textPadding)
        Style.SetFont(self.power, self.powerText, db.textPadding, POWER_TEXT_MIN)
        if self.partyIndex then
            self:LayoutParty(db, healthHeight, Sized)
        else
            self:LayoutRow(width, Sized)
        end

        -- A little shorter than the bars: as tall, it reads as a third bar.
        self.badgeDiameter = Diameter(healthHeight + DIVIDER + powerHeight)

        if self.happiness then
            self.happiness:ClearAllPoints()
            self.happiness:SetPoint("LEFT", self, "RIGHT", Style.BORDER_INSET + math.floor(CIRCLE_GAP * scale + 0.5), 0)
        end

        self:Update()
    end

    local function WantedVisibility(plate)
        local db = NS.db
        if plate.isSelf and not db.partyShowSelf then return "hidden" end
        if db.unlocked then return "shown" end
        -- The game's Target of Target switch, which its own frame follows.
        if plate.unit == "targettarget" and not GetCVarBool("showTargetOfTarget") then return "hidden" end
        if plate.partyIndex then return "driver" end
        return "watch"
    end

    -- Protected calls only: in combat the plate keeps its state (the game's
    -- watch goes on working), caught up as combat ends.
    function methods:ApplyVisibility()
        local wanted = WantedVisibility(self)
        if wanted == self.visibility or InCombatLockdown() then return end
        -- Recorded first: a Show runs OnShow, which comes back here.
        local driven = self.driven
        self.visibility = wanted

        if wanted ~= "driver" and driven then
            UnregisterStateDriver(self, "visibility")
            self.driven = false
        end
        if wanted == "watch" then
            RegisterUnitWatch(self)
        elseif wanted == "driver" then
            UnregisterUnitWatch(self)
            RegisterStateDriver(self, "visibility", EXISTS_CONDITION:format(self.isSelf and "party1" or self.unit))
            self.driven = true
        else
            UnregisterUnitWatch(self)
            if wanted == "shown" then self:Show() else self:Hide() end
        end
    end

    function methods:ShouldShow()
        local wanted = WantedVisibility(self)
        if wanted == "watch" then return UnitExists(self.unit) and true or false end
        if wanted == "driver" then
            return UnitExists(self.isSelf and "party1" or self.unit) and not IsInRaid() and true or false
        end
        return wanted == "shown"
    end

    -- While placing, a frame without its unit is painted as the player.
    function methods:PaintUnit()
        if Style.Previewing() and not UnitExists(self.unit) then return "player" end
        return self.unit
    end

    -- Everything that follows the unit. Never Show/Hide here: only paints.
    function methods:Update()
        -- The cast bar first: it asks the same questions, and Refresh reaches
        -- it this way.
        if self.castbar then self.castbar:Refresh() end
        self:ApplyVisibility()
        self:UpdateRange(NS.db.unlocked)
        if not self:ShouldShow() then return end

        local unit = self:PaintUnit()
        local r, g, b = HealthColour(unit)
        self.health:SetStatusBarColor(r, g, b, 1)
        self.power:SetStatusBarColor(PowerColour(unit))

        -- A secret name may be drawn but never tested: straight to the label.
        self.nameText:SetText(UnitName(unit))
        ShowLevel(self.levelText, unit)
        self.levelText:SetTextColor(LevelColour(unit))
        ShowLeader(self.leader, unit)
        if self.rest then ShowRest(self.rest) end
        if self.roleIcon then ShowRole(self.roleIcon, unit) end
        self:UpdateBadges()
        -- For a pet that arrived before the plate was made, or while hidden.
        if self.happiness then Call(self.happiness, "UpdateHappiness") end
        self:PaintBars()
    end

    -- The game's emblem fitted inside `size`, in its own proportions.
    local function SetEmblem(badge, atlas, size)
        badge.icon:SetAtlas(atlas)
        local info = C_Texture.GetAtlasInfo(atlas)
        local w, h = 1, 1
        if info and info.width and info.height and info.width > 0 and info.height > 0 then
            w, h = info.width, info.height
        end
        local scale = size / math.max(w, h)
        badge.icon:SetSize(w * scale, h * scale)
    end

    -- The elite emblem bare in the crown's corner (an elite never leads);
    -- PvP a circle on the outer side, CIRCLE_GAP from the bars.
    function methods:UpdateBadges()
        if not self.pvpBadge then return end
        local unit = self:PaintUnit()

        local elite = EliteBadge(unit)
        if elite and Style:HasAtlas(elite) then
            local badge = self.eliteBadge
            local size = self.eliteSize or ELITE_SIZE
            badge:ClearAllPoints()
            badge:SetSize(size, size)
            badge:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -2, self.cornerY or NAME_Y)
            badge.ring:SetAlpha(0)
            badge.disc:SetAlpha(0)
            SetEmblem(badge, elite, size)
            badge:SetAlpha(1)
            badge:Show()
        else
            self.eliteBadge:Hide()
        end

        local badge = self.pvpBadge
        local atlas, flagged = FactionBadge(unit)
        if not atlas or not Style:HasAtlas(atlas) then
            badge:Hide()
            return
        end
        local diameter = self.badgeDiameter or CIRCLE_MIN
        badge:ClearAllPoints()
        badge:SetSize(diameter, diameter)
        badge:SetPoint(self.badgeOnLeft and "RIGHT" or "LEFT", self, self.badgeOnLeft and "LEFT" or "RIGHT",
            self.badgeOnLeft and -CIRCLE_GAP or CIRCLE_GAP, 0)
        SetEmblem(badge, atlas, diameter * 0.72)
        badge:SetAlphaFromBoolean(flagged, 1, 0)
        badge:Show()
    end

    local function Shade(bar, whole, part)
        -- Secret first: nothing may be compared to a secret, not even nil.
        if not IsSecret(part) and part == nil then part = 0 end
        bar:SetMinMaxValues(0, whole)
        bar:SetValue(part)
        bar:Show()
    end

    -- The heals on `frame` (a plate or a pet's box), `health` already read,
    -- nothing added up: incoming heals over the missing health, heal absorbs
    -- over the health from its far end, shields both shield bars (AddHeals).
    -- Every number secret, only passed on.
    local function ShowHeals(frame, unit, health, most)
        Shade(frame.prediction, UnitHealthMissing(unit, true), UnitGetIncomingHeals(unit))
        Shade(frame.healAbsorb, health, UnitGetTotalHealAbsorbs(unit))
        local shield = UnitGetTotalAbsorbs(unit)
        Shade(frame.shield, most, shield)
        Shade(frame.overShield, most, shield)
    end

    -- A party member (or its pet) out of range see-through, as the game's
    -- party frames (out when it could be checked and is not). A secret answer
    -- goes to SetAlphaFromBoolean; alpha is allowed in combat.
    UnitPlate.OUT_OF_RANGE_ALPHA = 0.55

    local function ShowRange(frame, unit)
        local inRange, checked = UnitInRange(unit)
        if IsSecret(inRange) then
            frame:SetAlphaFromBoolean(inRange, 1, UnitPlate.OUT_OF_RANGE_ALPHA)
        elseif IsSecret(checked) then
            frame:SetAlpha(1)
        else
            frame:SetAlpha(checked and not inRange and UnitPlate.OUT_OF_RANGE_ALPHA or 1)
        end
    end

    function methods:UpdateRange(placing)
        if not self.partyIndex then return end
        if placing then
            self:SetAlpha(1)
            return
        end
        ShowRange(self, self.unit)
    end

    -- Every frame a plate is on screen, as the game's own frames read health
    -- (UNIT_HEALTH comes late on this client); the target's target whole.
    function methods:OnUpdate()
        if self.pollsIdentity then self:Update() else self:PaintBars() end
    end

    -- THE BARS: every value secret, straight to the widget, nothing compared.
    function methods:PaintBars()
        if not self:IsShown() or not self:ShouldShow() then return end
        local db = NS.db
        local unit = self:PaintUnit()
        -- Offline, dead or back: laid out again (no event for a death here).
        local status = Status(unit)
        if status ~= self.status then
            self.status = status
            if self.partyIndex then SyncOffline() end
            self:Refresh()
            return
        end
        -- Offline both bars full (grey), dead both empty - a ghost still
        -- reports health.
        if status then
            local fill = status == PLAYER_OFFLINE and 1 or 0
            self.health:SetMinMaxValues(0, 1)
            self.health:SetValue(fill)
            self.power:SetMinMaxValues(0, 1)
            self.power:SetValue(fill)
            self.prediction:Hide()
            self.healAbsorb:Hide()
            self.healthSpark:SetAlpha(0)
            self.powerSpark:SetAlpha(0)
            self.healthText:SetText(status)
            self.powerText:SetText("")
            return
        end
        -- The predicted health, as the game's frames read it: the confirmed
        -- one trailed every heal.
        local shown = ShownPower(unit)
        local health, most, power = UnitHealth(unit, true), UnitHealthMax(unit), UnitPower(unit, shown)
        self.health:SetMinMaxValues(0, most)
        self.health:SetValue(health)
        ShowHeals(self, unit, health, most)
        self.power:SetMinMaxValues(0, UnitPowerMax(unit, shown))
        self.power:SetValue(power)
        self.healthSpark:SetAlpha(Style.HealthSparkAlpha(unit))
        self.powerSpark:SetAlpha(Style.PowerSparkAlpha(unit))

        local scaleTo100 = CurveConstants.ScaleTo100
        if db.showHealthText then
            ShowValue(self.healthText, health, UnitHealthPercent(unit, true, scaleTo100))
        else
            self.healthText:SetText("")
        end
        if db.showPowerText then
            ShowValue(self.powerText, power, UnitPowerPercent(unit, shown, false, scaleTo100))
        else
            self.powerText:SetText("")
        end
    end

    -- A drag's place is the player's. Only the place is written (reading the
    -- size back would round it); a party frame's moves the party.
    function methods:SavePosition()
        local db = NS.db
        local left, top = self:GetLeft(), self:GetTop() - GetScreenHeight()
        if self.partyIndex then
            local x, y = self:SlotOffset(db)
            left, top = left - x, top - y
        end
        db[self.key .. "Placed"] = true
        db[self.key .. "Left"] = left
        db[self.key .. "Top"] = top
        NS.Refresh()
        DogsForeverUI.RefreshOptions()
    end

    ---------------------------------------------------------------------------
    -- PARTY PETS: a narrow box left of each member's frame, as tall as its
    -- bars - a vertical health fill with the heals, heal absorbs and shields,
    -- your own buffs as tiny icons; no name, power or icon. In a row it is
    -- turned: over the frame, as wide, filling rightwards. A child of its
    -- owner (the column moves it, in combat too) but faded for the pet's own
    -- range. Shown by a secure driver while the pet exists, never in a raid;
    -- while placing on some members only (PREVIEW_PETS), painted as the
    -- player; hidden with Show pets off.
    ---------------------------------------------------------------------------

    local PartyPets = {}
    NS.PartyPets = PartyPets
    PartyPets.AURA_SIZE = 8
    local PET_WIDTH = 0.2             -- of a party frame's width
    local PET_AURA_MARGIN = 3         -- the buffs to the box's edges
    local PET_AURA_COUNT = 4
    local PET_GAP = 2 * Style.BORDER_INSET + UnitPlate.PARTY_GAP     -- its border to its owner's
    local PREVIEW_PETS = { [1] = true, [3] = true }                   -- the members with one while placing

    -- Its width and height, and whether it is over its owner (a row).
    local function PetSize(db)
        local width, health, power = UnitPlate.Size(db, ANY_PARTY)
        local narrow = math.max(8, math.floor(width * PET_WIDTH + 0.5))
        if UnitPlate.InRow(db) then return width, narrow, true end
        return narrow, health + 1 + power, false
    end

    -- How far left of (in a row: over) its owner a box reaches, border
    -- included: the room the party keeps clear of the screen's edge.
    function PartyPets.Room(db)
        local width, height, over = PetSize(db)
        return PET_GAP + (over and height or width) + Style.BORDER_INSET
    end

    local petMethods = {}

    function PartyPets.New(index)
        local unit = "partypet" .. index
        local owner = NS.plates["party" .. index]
        local box = CreateFrame("Frame", "DogsForeverUI.FramesPartyPet" .. index, owner)
        local level = box:GetFrameLevel()
        box.unit, box.owner, box.index = unit, owner, index
        box:SetIgnoreParentAlpha(true)

        box.background = Style.SetBackground(box:CreateTexture(nil, "BACKGROUND"))
        box.background:SetAllPoints(box)
        box.health = NewBar(box, level + 1, true)
        box.health:SetAllPoints(box)
        box.health:SetStatusBarColor(HEALTH_COLOR[1], HEALTH_COLOR[2], HEALTH_COLOR[3], 1)
        AddHeals(box, level + 1)
        box.border = Style.AddBorder(box)

        -- Your buffs, over the fills and under the click, from the bottom up.
        box.auras = NS.UnitAuras.NewMineRow(box, unit, PartyPets.AURA_SIZE, PET_AURA_COUNT)
        if box.auras then
            local flow = AnchorUtil.FlowDirection
            Call(box.auras, "SetFrameLevel", box.health:GetFrameLevel() + 3)
            Call(box.auras, "SetFlowLayoutAnchorPoint", "BOTTOMLEFT")
            Call(box.auras, "SetFlowLayoutGrowthDirection", flow.Right, flow.Up)
            Call(box.auras, "SetPoint", "BOTTOMLEFT", box, "BOTTOMLEFT", PET_AURA_MARGIN, PET_AURA_MARGIN)
        end
        NewClick(box, "DogsForeverUI.FramesPartyPet" .. index .. "Click", unit, level + 5)

        -- The driver shows it: painted, and the frames' timer woken.
        box:SetScript("OnShow", function(self)
            self:Update()
            NS:Show()
        end)

        for name, method in pairs(petMethods) do box[name] = method end
        return box
    end

    -- Size, place and fill out of combat only (it holds a secure button).
    function petMethods:Refresh()
        local width, height, over = PetSize(NS.db)
        if not InCombatLockdown() then
            self:SetSize(width, height)
            self:ClearAllPoints()
            if over then
                self:SetPoint("BOTTOMLEFT", self.owner, "TOPLEFT", 0, PET_GAP)
            else
                self:SetPoint("TOPRIGHT", self.owner, "TOPLEFT", -PET_GAP, 0)
            end
            TurnHeals(self, not over)
        end
        if self.auras then Call(self.auras, "SetFlowLayoutMaximumLineSize", width - 2 * PET_AURA_MARGIN) end
        self:Update()
    end

    function petMethods:Update()
        local db = NS.db
        local wanted = db.partyShowPets and not db.unlocked and true or false
        if wanted ~= self.driven and not InCombatLockdown() then
            -- (Recorded first: the driver's Show runs OnShow, which comes back here.)
            self.driven = wanted
            if wanted then
                RegisterStateDriver(self, "visibility", EXISTS_CONDITION:format(self.unit))
            else
                UnregisterStateDriver(self, "visibility")
            end
        end
        if not (self.driven or InCombatLockdown()) then
            self:SetShown(db.partyShowPets and db.unlocked and PREVIEW_PETS[self.index] or false)
        end
        if not self:IsShown() then return end
        -- (A new pet behind the same token: its auras asked for again.)
        if self.auras then Call(self.auras, "UpdateAllAuras") end
        self:OnUpdate()
    end

    petMethods.PaintUnit = methods.PaintUnit

    -- Every frame while shown: health is secret, handed on, never read.
    function petMethods:OnUpdate()
        local unit = self:PaintUnit()
        local health, most = UnitHealth(unit, true), UnitHealthMax(unit)
        self.health:SetMinMaxValues(0, most)
        self.health:SetValue(health)
        ShowHeals(self, unit, health, most)
        ShowRange(self, unit)
    end
end
