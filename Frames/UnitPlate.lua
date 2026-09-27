-- One unit's frame: a health bar over a resource bar, one border round the pair
-- and a hairline between them. Above the frame, in the bold font: the unit's
-- level at the left, its name in the middle and at the right a crown when it
-- leads the group, or its elite, rare or boss emblem. On the bars, in white: "505K | 100%" and the same for the
-- resource.
--
-- Five of them are built: the player and the focus, whose badges sit on their
-- left, and the target and the target's target, whose badges sit on their
-- right, so the row reads outwards from the middle of the screen; and the pet,
-- under the player's. The target's target and the pet are drawn at a fraction
-- of the size, as the game draws them. A hunter's pet wears the game's own
-- happiness face on its right (see New).
--
-- Drawn in the addon's one look (Core\Style.lua): a flat fill with a soft
-- sheen and shade, the black background, the rounded gold border and the
-- palette. The player chose it from a preview, after the game's bar art.
--
-- SECRET VALUES
-- Health is always secret on this client and power usually is, so no number here
-- is ever read: they are handed to SetMinMaxValues, SetValue and
-- SetFormattedText, which take a secret and draw it. The one value that must be
-- read - the unit's class, because it is used as a table key - is checked with
-- issecretvalue first and given a plain colour when it cannot be.
--
-- CLICKING
-- The clicking is a real SecureUnitButton laid over the plate, carrying the
-- same attributes the game's own unit frames carry, which is what makes
-- left-click target and right-click open the unit menu while fighting. That
-- button is anchored once, when it is built, and never touched again in combat.
--
-- It also makes the plate protected: a frame that is the parent or the anchor
-- of a protected frame is protected itself. So the plate is never shown,
-- hidden, moved or resized in combat by this addon - the game's secure unit
-- watch shows and hides it (see New), and a layout change waits for the end
-- of combat. An earlier version believed the plate was an ordinary frame and
-- showed and hid it by hand; see ApplyVisibility for what that cost.

local UnitPlate = {}
DogsForeverUI.Frames.UnitPlate = UnitPlate

do -- private scope

    local NS = DogsForeverUI.Frames
    local Style = DogsForeverUI.Style
    local IsSecret = issecretvalue

    local Tone = Style.Tone
    local HEALTH_COLOR = Style.HEALTH_COLOR
    local MANA_COLOR = Style.MANA_COLOR
    local HEALTH_TONE = Style.HEALTH_TONE
    local POWER_TONE = Style.POWER_TONE

    -- The heal shading over the missing health. Fixed, like the rest of the
    -- palette: there are no colour settings.
    local HEAL_COLOR = { 0.5, 0.9, 0.6, 0.45 }

    local BORDER_COLOR = Style.BORDER_COLOR
    -- The hairline between the two bars, which belongs to the same piece of
    -- framing as the border round the pair: it carries on the border's inner
    -- black line, in exactly its colour.
    local DIVIDER = 1
    local DIVIDER_COLOR = Style.DIVIDER_COLOR
    -- The resource bar is short by design - ten pixels - and the shared text
    -- rule would size its label to four, which is not text any more. This is the
    -- floor under it.
    local POWER_TEXT_MIN = 9
    local CIRCLE_GAP = 8       -- clear space between the bars and a badge
    local CIRCLE_MIN, CIRCLE_MAX = 14, 30

    -- THE ROW ABOVE THE FRAME: the level at the left end, the crown at the
    -- right end, the name centred, their bottoms NAME_Y over the bars - clear of
    -- the border, which reaches BORDER_INSET out. Sizes are the full-size
    -- frames'; the small one takes its fraction of them, down to a floor. The
    -- name keeps NAME_SIDE clear at either end, the same both sides so it
    -- stays centred, which leaves room for the level and the crown.
    local NAME_Y = 6
    local NAME_SIZE, LEVEL_SIZE, CROWN_SIZE = 13, 11, 12
    -- The elite emblem, in the crown's corner: a little larger than the crown
    -- (the player asked), and smaller than the PvP circle.
    local ELITE_SIZE = 15
    local NAME_SIDE = 34
    local SMALLEST_TEXT = 8
    local LEADER_ICON = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
    local GUIDE_ATLAS = "UI-HUD-UnitFrame-Player-Group-GuideIcon"
    -- Behind that row, the NAME BAND, picked in game from a preview of drawn
    -- ones: black, fading out to both ends, under a thin line in the border's
    -- gold along its top that fades the same way. No line along its bottom:
    -- the frame's own border is there already. A texture fades one way only,
    -- so each of the two is three pieces: a fade in over the outer NAME_FADE
    -- of the width, solid, a fade out.
    local NAME_BAND_ALPHA = 0.55
    local NAME_LINE_ALPHA = 0.9
    local NAME_FADE = 0.35
    -- The name's letters sit in the top of its text box, so the band reaches
    -- this much higher than the text for them to look centred in it.
    local NAME_BAND_EXTRA = 3

    -- How far above the bars that row and its band reach, for what is placed
    -- over a frame - the target's castbar, its auras - to clear it rather than
    -- the border.
    function UnitPlate.TopRoom()
        return NAME_Y + NAME_SIZE + 2 + NAME_BAND_EXTRA
    end

    -- How much smaller the target's target is drawn than the rest.
    UnitPlate.SMALL_SCALE = 0.6

    -- The game's own setting for whether a target's target is shown at all,
    -- under Options > Combat. Reading a CVar is free and does not taint; the
    -- game caches this one for the same reason.
    local TOT_CVAR = "showTargetOfTarget"

    local function CVarOn(name)
        if type(GetCVarBool) ~= "function" then return true end
        local ok, value = pcall(GetCVarBool, name)
        if not ok then return true end
        return value and true or false
    end

    -- The target's target changes with no event worth the name behind it -
    -- Blizzard's own compact frames poll it and say so in a comment - so who it
    -- is gets re-read on this slower beat of the same timer that draws the bars.
    local IDENTITY_INTERVAL = 0.25

    -- The badge's size for a plate of this total height, and the room it takes
    -- up beside the bars. The default placement asks for the second one so the
    -- frame beyond a plate does not land on top of its badge.
    local function Diameter(height)
        return math.max(CIRCLE_MIN, math.min(CIRCLE_MAX, math.floor(height * 0.85)))
    end

    -- THE BADGES. PvP is a circle, a little shorter than the plate and centred
    -- on its height, on the plate's outer side - the target's right, the
    -- focus's left:
    --
    --     [bars]  (pvp)
    --
    -- The elite emblem is not a circle any more: it is the bare emblem at the
    -- top right corner, where the crown goes (see UpdateBadges). Each appears
    -- only when it applies.
    --
    -- The room a plate's badges take on either side, which is what the default
    -- placement leaves between frames: one circle and its gap.
    function UnitPlate.SideRoom()
        local db = DogsForeverUI.Frames.db or {}
        local height = (db.barHeight or 30) + DIVIDER + (db.powerHeight or 10)
        return CIRCLE_GAP + Diameter(height)
    end

    -- THE PVP BADGE, the game's own art and the game's own rule for it, as
    -- Camelot draws it (TargetFrameMixin:ShowPvPIcon/CheckFaction in
    -- Blizzard_UnitFrame/Camelot/TargetFrame.lua): the round SmallCircle
    -- emblems, free-for-all winning over the unit's faction.
    local FFA_ATLAS = "UI-HUD-UnitFrame-Player-PVP-FFAIcon"
    local FACTION_ATLAS = {
        Horde = "UI-HUD-UnitFrame-SmallCircle-Horde",
        Alliance = "UI-HUD-UnitFrame-SmallCircle-Alliance",
    }

    -- THE ELITE BADGE, with the game's own nameplate art and rule
    -- (NamePlateClassificationFrameMixin:GetClassificationAtlasElement).
    local ELITE_ATLAS = {
        elite = "nameplates-icon-elite-gold",
        worldboss = "nameplates-icon-elite-gold",
        rareelite = "nameplates-icon-elite-silver",
        rare = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star",
    }

    local function EliteBadge(unit)
        local classification = UnitClassification(unit)
        if classification == nil or IsSecret(classification) then return nil end
        return ELITE_ATLAS[classification]
    end

    local function PvPBadgesDisabled()
        local rule = Enum and Enum.GameRule and Enum.GameRule.UnitFramePvPContextualDisabled
        if not rule or not C_GameRules or not C_GameRules.IsGameRuleActive then return false end
        local ok, active = pcall(C_GameRules.IsGameRuleActive, rule)
        return ok and active == true
    end

    -- The badge's art, and whether it is on. The second value may be a secret
    -- boolean - UnitIsPVP is SecretWhenUnitIdentityRestricted - so it is never
    -- tested here, only handed to SetAlphaFromBoolean, which accepts one.
    local function FactionBadge(unit)
        if PvPBadgesDisabled() then return nil end

        local ffa = UnitIsPVPFreeForAll(unit)
        if not IsSecret(ffa) and ffa then return FFA_ATLAS, true end

        local faction = UnitFactionGroup(unit)
        if faction == nil or IsSecret(faction) then return nil end
        local atlas = FACTION_ATLAS[faction]
        if not atlas then return nil end

        return atlas, UnitIsPVP(unit)
    end

    -- What every bar shows while it is unlocked: which frame it is, where the
    -- name goes, and the word, where the health goes.
    local PLACEMENT_LABEL = Style.PLACEMENT_LABEL
    local PLACEMENT_NAMES = {
        player = "Player",
        target = "Target",
        focus = "Focus",
        targettarget = "ToT",   -- the small frame: the short name the game's players use
        pet = "Pet",
    }

    local function Options()
        return DogsForeverUI.Frames.db
    end

    ---------------------------------------------------------------------------
    -- Reading a unit without reading anything the client will not let us.
    ---------------------------------------------------------------------------

    -- A unit's name comes back as a secret string whenever the client restricts
    -- it (UnitName is SecretWhenUnitNameIdentityRestricted) - which is most NPCs
    -- inside a dungeon. A secret may be passed to SetText and drawn
    -- (FontString:SetText is AllowedWhenTainted), but not tested, compared or
    -- joined, so the name goes straight from UnitName to the font string and is
    -- never looked at: not even `name or ""`, which is a test.
    --
    -- It used to go through `scrub`, the client's helper that turns a secret
    -- into nil. That blanked the name on exactly the units that have one worth
    -- showing - "I can't see some NPC names, in a dungeon".
    local function ShowName(fontString, unit)
        fontString:SetText(UnitName(unit))
    end

    -- The health bar's colour: the unit's class, its reaction to the player, or
    -- the plain health colour.
    --
    -- The option is called "Class and reaction colours" and turns off both. With
    -- it unticked every bar wears the plain colour, which is what the checkbox
    -- says and what it is for; an earlier version sent players through
    -- UnitSelectionColor even then, so unticking it turned a class colour into a
    -- reaction colour.
    local function GameHealthColour(unit)
        if UnitIsPlayer(unit) then
            -- A player wears its class, and the plain colour when the client
            -- will not say what that class is - never a reaction colour, which
            -- would read as "this player is an enemy".
            local _, class = UnitClass(unit)
            if class ~= nil and not IsSecret(class) then
                local colour = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
                if colour then return colour.r, colour.g, colour.b, true end
            end
            return nil
        end

        -- Everything else wears the colour the game would give it:
        -- UnitSelectionColor is the call its own frames use - green for a
        -- friend, yellow for a neutral, red for an enemy, grey for a kill
        -- somebody else has tapped.
        if type(UnitSelectionColor) == "function" then
            local ok, r, g, b = pcall(UnitSelectionColor, unit)
            if ok and type(r) == "number" and not IsSecret(r) and not IsSecret(g)
               and not IsSecret(b) then
                return r, g, b
            end
        end

        local reaction = UnitReaction(unit, "player")
        if reaction ~= nil and not IsSecret(reaction) then
            local colour = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
            if colour then return colour.r, colour.g, colour.b end
        end
        return nil
    end

    local function HealthColour(unit)
        if Options().classColors then
            -- A class wears the game's own class colour, exactly as
            -- RAID_CLASS_COLORS gives it - not toned: every class should look
            -- the way the game has always shown it. Reactions are toned to the
            -- palette.
            local r, g, b, isClass = GameHealthColour(unit)
            if r and isClass then return r, g, b end
            if r then return Tone(r, g, b, HEALTH_TONE) end
        end
        return HEALTH_COLOR[1], HEALTH_COLOR[2], HEALTH_COLOR[3]
    end

    -- A resource bar's colour: mana is MANA_COLOR, and every other resource is
    -- the colour the game lists for it in PowerBarColor - rage red, energy
    -- yellow, focus orange - toned to mana's depth. A resource the client will
    -- not name wears mana's.
    --
    -- There is no option for any of this: a resource bar that is not the
    -- resource's colour is a puzzle rather than a setting.
    local function PowerColour(unit)
        local _, token = UnitPowerType(unit)
        if token == nil or IsSecret(token) or token == "MANA" then
            return MANA_COLOR[1], MANA_COLOR[2], MANA_COLOR[3]
        end

        local info = PowerBarColor and PowerBarColor[token]
        if type(info) ~= "table" or type(info.r) ~= "number" then
            return MANA_COLOR[1], MANA_COLOR[2], MANA_COLOR[3]
        end
        return Tone(info.r, info.g, info.b, POWER_TONE)
    end

    -- The level before the name, and what colour to write it in. A target the
    -- game will not put a number on is "??", its skull.
    --
    -- The docs give UnitLevel no secrecy predicate, but they are not exhaustive
    -- on this client, so a secret level is not compared either: it is handed to
    -- the font string to format, which it may be.
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

    -- THE VALUES on the bars: "505K | 100%". Health and power are secret, so
    -- neither number is read or worked on here. The game shortens a secret
    -- itself - AbbreviateNumbers takes one and hands back a secret string - and
    -- works the percentage out itself, through its ScaleTo100 curve
    -- (CurveConstants, Blizzard_SharedXMLBase); both go straight to the font
    -- string, which may draw them. A client without these gets the plain
    -- number, as before.
    local function ScaleTo100()
        return type(CurveConstants) == "table" and CurveConstants.ScaleTo100 or nil
    end

    local function HealthPercent(unit)
        local curve = ScaleTo100()
        if curve and type(UnitHealthPercent) == "function" then
            return UnitHealthPercent(unit, false, curve)
        end
    end

    local function PowerPercent(unit)
        local curve = ScaleTo100()
        if curve and type(UnitPowerPercent) == "function" then
            return UnitPowerPercent(unit, nil, false, curve)
        end
    end

    local function ShowValue(label, value, percent)
        if type(AbbreviateNumbers) ~= "function" then
            label:SetFormattedText("%.0f", value)
            return
        end
        local short = AbbreviateNumbers(value)
        -- Secret first: nothing may be compared to a secret, not even nil.
        if not IsSecret(percent) and percent == nil then
            label:SetText(short)
        else
            label:SetFormattedText("%s | %d%%", short, percent)
        end
    end

    -- The difficulty colour for anything else, and the frames' own text colour
    -- for the player and for a level that cannot be judged.
    local function PlainText()
        local colour = Style.GOLD
        return colour[1], colour[2], colour[3]
    end

    local function LevelColour(unit)
        -- UnitIsUnit is SecretWhenUnitComparisonRestricted: a secret answer
        -- cannot be tested, and a restricted unit is not the player anyway.
        local isPlayer = UnitIsUnit(unit, "player")
        if not IsSecret(isPlayer) and isPlayer then return PlainText() end

        local level = UnitLevel(unit)
        if IsSecret(level) then return PlainText() end

        local difficulty = GetCreatureDifficultyColor or GetQuestDifficultyColor
        if type(difficulty) == "function" then
            local ok, colour = pcall(difficulty, level)
            if ok and type(colour) == "table" and colour.r then
                return colour.r, colour.g, colour.b
            end
        end

        return PlainText()
    end

    ---------------------------------------------------------------------------
    -- Building one.
    ---------------------------------------------------------------------------

    -- A bar in the frames' flat fill. `sheen` adds the soft shading, made once
    -- and pinned to the fill; the heal shading goes without it.
    local function NewBar(parent, level, sheen)
        local bar = CreateFrame("StatusBar", nil, parent)
        bar:SetFrameLevel(level)
        Style.SetBarFill(bar)
        if sheen then Style.AddSheen(bar) end
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        return bar
    end

    -- The crown shows while the unit leads a group, asked exactly as the game
    -- asks for its own (TargetFrameMixin:CheckPartyLeader): UnitLeadsAnyGroup,
    -- which counts the instance group the dungeon finder or a battleground
    -- makes as well as the player's own party - UnitIsGroupLeader, asked
    -- before, counts only the own party, so an instance group's leader had
    -- no crown. In a group the dungeon finder made, the game marks its leader
    -- with the guide mark instead of the crown, and so does this. Whether a
    -- unit leads can be a secret for a unit the client restricts, which is
    -- drawn from with SetAlphaFromBoolean and never tested.
    local function ShowLeader(texture, unit)
        local guide = type(HasLFGRestrictions) == "function" and HasLFGRestrictions() == true
            and Style:HasAtlas(GUIDE_ATLAS)
        if guide then
            texture:SetAtlas(GUIDE_ATLAS)
        else
            texture:SetTexture(LEADER_ICON)
        end
        local leads
        if type(UnitLeadsAnyGroup) == "function" then
            leads = UnitLeadsAnyGroup(unit)
        elseif type(UnitIsGroupLeader) == "function" then
            leads = UnitIsGroupLeader(unit)
        end
        if IsSecret(leads) then
            if type(texture.SetAlphaFromBoolean) == "function" then
                texture:SetAlphaFromBoolean(leads, 1, 0)
            else
                texture:SetAlpha(0)
            end
        else
            texture:SetAlpha(leads and 1 or 0)
        end
    end

    -- A filled circle, drawn as a plain colour behind a circular mask. The mask
    -- is asked for rather than assumed: without it the badge is a square, which
    -- is a smaller loss than the whole frame failing to build.
    local function NewCircle(parent, layer, r, g, b, a)
        local texture = parent:CreateTexture(nil, layer)
        texture:SetColorTexture(r, g, b, a)

        if type(parent.CreateMaskTexture) == "function" then
            local ok, mask = pcall(parent.CreateMaskTexture, parent)
            if ok and mask then
                local applied = pcall(mask.SetAtlas, mask, "CircleMask")
                if applied then
                    mask:SetAllPoints(texture)
                    pcall(texture.AddMaskTexture, texture, mask)
                end
            end
        end

        return texture
    end

    -- One badge in the row: a frame of its own, so the whole thing - ring, dark
    -- middle, emblem - can be shown or faded as one, drawn exactly like the
    -- level circle with the game's emblem inside.
    local function NewBadge(plate)
        local badge = CreateFrame("Frame", nil, plate)
        badge:SetFrameLevel(plate:GetFrameLevel() + 2)
        badge.ring = NewCircle(badge, "ARTWORK",
            BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], 1)
        badge.ring:SetAllPoints(badge)
        badge.disc = NewCircle(badge, "OVERLAY", 0, 0, 0, 0.85)
        badge.disc:SetPoint("TOPLEFT", 1, -1)
        badge.disc:SetPoint("BOTTOMRIGHT", -1, 1)
        badge.icon = badge:CreateTexture(nil, "OVERLAY", nil, 2)
        badge.icon:SetPoint("CENTER", badge, "CENTER", 0, 0)
        badge:Hide()
        return badge
    end

    -- unit   the unit token this plate draws
    -- label  "Player", "Target", "Focus", "TargetOfTarget": the frame's name
    -- scale  a fraction of the configured size, for the small frames
    function UnitPlate.New(unit, label, scale)
        local plate = CreateFrame("Frame", "DogsForeverUI.Frames" .. label, UIParent)
        local base = plate:GetFrameLevel()

        plate.unit = unit
        plate.key = unit                    -- playerLeft, targetTop and so on
        plate.scale = scale or 1
        -- Whose badge sits on which side: the two frames left of the middle of
        -- the screen wear theirs on the left, the two right of it on the right.
        plate.badgeOnLeft = (unit == "player" or unit == "focus")
        plate.pollsIdentity = (unit == "targettarget")
        -- The game hides its target-of-target frame when this is off, so this
        -- one goes with it: the setting is the player's answer to the question,
        -- not something for this addon to ask again.
        plate.cvar = (unit == "targettarget") and TOT_CVAR or nil
        plate:SetMovable(true)
        plate:SetClampedToScreen(true)

        -- WHO SHOWS AND HIDES IT: the game, not this addon.
        --
        -- The plate holds a secure click button, anchored to it, and a frame
        -- that is the parent of - or the anchor of - a protected frame is
        -- protected itself (IsProtected answers "isProtected,
        -- isProtectedExplicitly" for exactly this reason). So Show, Hide and
        -- SetPoint on the plate are refused in combat. An earlier version
        -- showed and hid it by hand from a 0.05s timer; in combat every one of
        -- those calls was blocked, the plate did not change, and the timer
        -- tried again twenty times a second - thousands of "interface action
        -- failed" against this addon in one evening.
        --
        -- RegisterUnitWatch is the game's own answer, and what its target frame
        -- uses: the secure state driver shows the frame while its unit exists
        -- and hides it when it does not, in combat or out, reading the unit
        -- from this attribute. See ApplyVisibility.
        plate:SetAttribute("unit", unit)
        -- The driver shows it when a unit arrives; that is when it is repainted.
        plate:SetScript("OnShow", function(self) self:Update() end)

        -- BACKGROUND, one for each bar so they can be tinted apart.
        plate.healthBG = plate:CreateTexture(nil, "BACKGROUND")
        plate.powerBG = plate:CreateTexture(nil, "BACKGROUND")

        -- BARS. The prediction bar covers the *missing* health - it starts where
        -- the health bar's fill ends - and is filled with the incoming heal out
        -- of what is missing. See OnUpdate: that is what lets a heal be drawn
        -- without ever adding it to anything.
        plate.prediction = NewBar(plate, base + 1)
        plate.health = NewBar(plate, base + 2, true)
        plate.power = NewBar(plate, base + 2, true)

        -- SPARKS at the end of each bar's fill, as on the castbar.
        plate.healthSpark = Style.AddSpark(plate.health)
        plate.powerSpark = Style.AddSpark(plate.power)

        -- THE HAIRLINE between the two bars.
        plate.divider = plate:CreateTexture(nil, "OVERLAY")

        -- BORDER, as on every bar.
        plate.border = Style.AddBorder(plate)

        -- TEXT. The level is its own string, so it can wear the difficulty
        -- colour while the name stays white; both sit above the frame.
        plate.levelText = plate.health:CreateFontString(nil, "OVERLAY")
        plate.nameText = plate.health:CreateFontString(nil, "OVERLAY")
        plate.healthText = plate.health:CreateFontString(nil, "OVERLAY")
        plate.powerText = plate.power:CreateFontString(nil, "OVERLAY")

        -- THE CROWN, above the frame's right end, while the unit leads.
        plate.leader = plate.health:CreateTexture(nil, "OVERLAY")
        plate.leader:SetTexture(LEADER_ICON)
        plate.leader:SetAlpha(0)

        -- THE NAME BAND behind the row above the frame: the black, then its
        -- line over it, each three pieces (see NAME_FADE). Under everything;
        -- the border is drawn over it. Placed in Layout.
        local function Faded(sub, colour, alpha)
            local pieces = {}
            local r, g, b = colour[1], colour[2], colour[3]
            for i = 1, 3 do
                local piece = plate:CreateTexture(nil, "BACKGROUND", nil, sub)
                piece:SetTexture(Style.FLAT_TEXTURE)
                if i == 2 or not (piece.SetGradient and CreateColor) then
                    piece:SetVertexColor(r, g, b, i == 2 and alpha or alpha / 2)
                elseif i == 1 then
                    piece:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, alpha))
                else
                    piece:SetGradient("HORIZONTAL", CreateColor(r, g, b, alpha), CreateColor(r, g, b, 0))
                end
                pieces[i] = piece
            end
            return pieces
        end
        plate.nameBand = Faded(-8, { 0, 0, 0 }, NAME_BAND_ALPHA)
        plate.nameLineTop = Faded(-7, Style.BORDER_COLOR, NAME_LINE_ALPHA)

        -- THE ELITE AND PVP BADGES, for the two frames whose game counterparts
        -- show them: the target's and the focus's.
        if unit == "target" or unit == "focus" then
            plate.eliteBadge = NewBadge(plate)
            plate.pvpBadge = NewBadge(plate)
        end

        -- THE PET'S HAPPINESS: the game's own indicator (PetFrameHappiness-
        -- Template, Blizzard_FrameXML/PetHappiness.xml), made on this plate
        -- rather than the game's pet frame, which is not drawn any more. It
        -- brings its face, its tooltip (mood, damage, loyalty, diet), its
        -- events and its rule - it shows only for a hunter's pet - so nothing
        -- here decides any of that. Not a secure frame, so the game may show
        -- and hide it in combat.
        if unit == "pet" then
            local ok, happiness = pcall(CreateFrame, "Frame", nil, plate,
                "PetFrameHappinessTemplate")
            if ok and happiness then
                happiness:SetFrameLevel(base + 4)
                plate.happiness = happiness
            end
        end

        -- CLICKING. A real secure unit button, carrying what the game's own unit
        -- frames carry: left-click targets, right-click opens the unit menu.
        -- `togglemenu` is the action the game keeps for exactly this - see
        -- SECURE_ACTIONS.togglemenu in Blizzard_FrameXML/SecureTemplates.lua,
        -- which works out which menu the unit wants by itself.
        local click = CreateFrame("Button", "DogsForeverUI.Frames" .. label .. "Click",
            plate, "SecureUnitButtonTemplate")
        click:SetAllPoints(plate)
        click:SetFrameLevel(base + 3)
        click:RegisterForClicks("AnyUp")
        click:SetAttribute("unit", unit)
        click:SetAttribute("*type1", "target")
        click:SetAttribute("*type2", "togglemenu")
        plate.click = click

        click:SetScript("OnEnter", function()
            if Options().unlocked then return end
            GameTooltip:SetOwner(click, "ANCHOR_RIGHT")
            GameTooltip:SetUnit(unit)
            GameTooltip:Show()
        end)
        click:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Dragging, while unlocked, and a right-click to lock the frames again
        -- when they are placed. The plate is the frame that moves, and it is an
        -- ordinary one, so this is allowed whenever the button is.
        click:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" and Options().unlocked then plate:StartMoving() end
        end)
        click:SetScript("OnMouseUp", function(_, button)
            if DogsForeverUI.RightClickLock(NS, button) then return end
            if button ~= "LeftButton" or not Options().unlocked then return end
            plate:StopMovingOrSizing()
            plate:SavePosition()
        end)

        for name, method in pairs(UnitPlate.methods) do plate[name] = method end

        -- What the target and the focus are casting. No auras: this client does
        -- not let an addon read a unit's, so the game keeps drawing those.
        if unit == "target" or unit == "focus" then
            plate.castbar = NS.UnitCastbar.New(plate)
        end

        return plate
    end

    ---------------------------------------------------------------------------
    -- What a plate can do.
    ---------------------------------------------------------------------------

    UnitPlate.methods = {}
    local methods = UnitPlate.methods

    -- Everything that follows a setting: size, position, colours, fonts.
    function methods:Refresh()
        local db = Options()
        -- One size setting for all four frames; the small ones take a fraction
        -- of it, so there is one width to change rather than four.
        local scale = self.scale or 1
        local width = math.floor(db.barWidth * scale + 0.5)
        local healthHeight = math.max(4, math.floor(db.barHeight * scale + 0.5))
        local powerHeight = math.max(3, math.floor(db.powerHeight * scale + 0.5))

        -- POSITION, SIZE. The plate is protected (see New), so moving or
        -- resizing it is refused in combat. A setting changed then is laid out
        -- when combat ends: the core refreshes every plate on
        -- PLAYER_REGEN_ENABLED.
        if not InCombatLockdown() then
            self:ClearAllPoints()
            self:SetFrameStrata(db.frameStrata or "MEDIUM")
            self:SetWidth(width)
            self:SetHeight(healthHeight + DIVIDER + powerHeight)
            self:SetPoint("TOPLEFT", db[self.key .. "Left"] or 0, db[self.key .. "Top"] or 0)
        end

        -- CLICKING. While a frame is being placed its click actions come off, so
        -- dragging it does not also target the unit or open its menu. Writing a
        -- secure attribute is refused in combat, which is why unlocking is too -
        -- see Unlock in the core file.
        if not InCombatLockdown() then
            if db.unlocked then
                self.click:SetAttribute("*type1", nil)
                self.click:SetAttribute("*type2", nil)
            else
                self.click:SetAttribute("*type1", "target")
                self.click:SetAttribute("*type2", "togglemenu")
            end
        end

        -- The client caches named, user-placed frames in layout-local.txt and
        -- restores them at login, after this addon has already positioned the
        -- frame from its own saved settings. StartMoving sets that flag on every
        -- drag, so clear it here - the position saved on mouse-up is the one
        -- that should win. A protected frame's call, so out of combat only.
        if not InCombatLockdown() then self:SetUserPlaced(false) end

        self.health:ClearAllPoints()
        self.health:SetPoint("TOPLEFT", 0, 0)
        self.health:SetSize(width, healthHeight)

        -- The bars' own fill textures, set before anything is anchored to one of
        -- them: the heal shading hangs off the health bar's fill, and asking for
        -- that texture before the bar has been given one would anchor to
        -- whatever it had before. The resource bar is painted in Update, where
        -- the unit says which resource it is.
        Style.SetBarFill(self.health)
        Style.SetBarFill(self.prediction)

        -- The gap the health bar has not filled, anchored to the fill itself so
        -- it follows the bar without anything being measured or worked out.
        self.prediction:ClearAllPoints()
        self.prediction:SetPoint("TOPLEFT", self.health:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
        self.prediction:SetPoint("BOTTOMRIGHT", self.health, "BOTTOMRIGHT", 0, 0)

        self.divider:ClearAllPoints()
        self.divider:SetPoint("TOPLEFT", 0, -healthHeight)
        self.divider:SetSize(width, DIVIDER)
        self.divider:SetColorTexture(DIVIDER_COLOR[1], DIVIDER_COLOR[2],
            DIVIDER_COLOR[3], DIVIDER_COLOR[4])

        self.power:ClearAllPoints()
        self.power:SetPoint("TOPLEFT", 0, -(healthHeight + DIVIDER))
        self.power:SetSize(width, powerHeight)

        -- The sparks ride the end of each fill: pinned to the fill texture
        -- itself, so they follow the secret values without reading them.
        Style.PinSpark(self.healthSpark, self.health)
        Style.PinSpark(self.powerSpark, self.power)

        self.healthBG:ClearAllPoints()
        self.healthBG:SetAllPoints(self.health)
        self.powerBG:ClearAllPoints()
        self.powerBG:SetAllPoints(self.power)

        -- BACKGROUNDS: plain black while the frames are being placed.
        Style.SetBackground(self.healthBG, db.unlocked)
        Style.SetBackground(self.powerBG, db.unlocked)

        -- TEXT
        for _, label in ipairs({ self.levelText, self.nameText, self.healthText,
                                 self.powerText }) do
            label:ClearAllPoints()
            Style.SingleLine(label)
        end

        -- THE ROW ABOVE: level at the left end, name centred between equal
        -- margins - the second point is also what gives it a width to be cut
        -- short against - and the crown at the right end.
        local function Sized(size)
            return math.max(SMALLEST_TEXT, math.floor(size * scale + 0.5))
        end
        local y, side = NAME_Y * scale, NAME_SIDE * scale

        self.levelText:SetJustifyH("LEFT")
        self.levelText:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 2, y)
        Style.SetBoldFont(self.levelText, Sized(LEVEL_SIZE))

        self.nameText:SetJustifyH("CENTER")
        self.nameText:SetPoint("BOTTOMLEFT", self, "TOPLEFT", side, y)
        self.nameText:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -side, y)
        Style.SetBoldFont(self.nameText, Sized(NAME_SIZE))
        self.nameText:SetTextColor(1, 1, 1)

        -- The name band: the black from the frame's top edge up, the line
        -- along its top, one real pixel tall at any scale.
        local band = UnitPlate.TopRoom() * scale
        local edge = math.floor(width * NAME_FADE + 0.5)
        local from, to = { 0, edge, width - edge }, { edge, width - edge, width }
        local function Across(pieces, point, y, height)
            for i, piece in ipairs(pieces) do
                piece:ClearAllPoints()
                piece:SetPoint(point, self, "TOPLEFT", from[i], y)
                piece:SetWidth(to[i] - from[i])
                if height then
                    piece:SetHeight(height)
                elseif PixelUtil and PixelUtil.SetHeight then
                    PixelUtil.SetHeight(piece, 1, 1)
                else
                    piece:SetHeight(1)
                end
            end
        end
        Across(self.nameBand, "BOTTOMLEFT", 0, band)
        Across(self.nameLineTop, "TOPLEFT", band)

        -- At the right end, the level's mirror: as far in from the frame's
        -- right edge as the level is from its left, on the same line.
        local crown = Sized(CROWN_SIZE)
        self.leader:ClearAllPoints()
        self.leader:SetSize(crown, crown)
        self.leader:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -2, y)
        -- The elite emblem takes the same corner, a little larger (UpdateBadges).
        self.eliteSize, self.cornerY = Sized(ELITE_SIZE), y

        -- THE VALUES, centred on their bars, in white.
        self.healthText:SetJustifyH("CENTER")
        self.healthText:SetPoint("CENTER", self.health, "CENTER", 0, 0)
        self.powerText:SetJustifyH("CENTER")
        self.powerText:SetPoint("CENTER", self.power, "CENTER", 0, 0)

        Style.SetFont(self.health, self.healthText, db.textPadding)

        -- The resource label follows the same rule, with a floor under it:
        -- sized to a ten-pixel bar it came out at four, which is why the "show
        -- resource" option looked like it did nothing at all.
        Style.SetFont(self.power, self.powerText, db.textPadding, POWER_TEXT_MIN)

        -- THE BADGES are laid out in UpdateBadges, because which of them show
        -- depends on the unit. A little shorter than the bars they sit beside
        -- rather than as tall as them: a badge that matches the frame's full
        -- height reads as a third bar on the end of it.
        self.badgeDiameter = Diameter(healthHeight + DIVIDER + powerHeight)

        -- The pet's happiness, on its outer side like a PvP badge, at the
        -- game's own size - about the small plate's height.
        if self.happiness then
            self.happiness:ClearAllPoints()
            self.happiness:SetPoint("LEFT", self, "RIGHT",
                Style.BORDER_INSET + math.floor(CIRCLE_GAP * scale + 0.5), 0)
        end

        self:Update()
    end

    -- Hidden, shown for placing, or left to the game to show whenever its unit
    -- exists.
    local function WantedVisibility(plate)
        local db = Options()
        if not db.enabled then return "hidden" end
        if db.unlocked then return "shown" end
        if plate.cvar and not CVarOn(plate.cvar) then return "hidden" end
        return "watch"
    end

    -- Put the plate in the state it should be in. Every call in here is a
    -- protected frame's, so in combat nothing happens and the plate keeps the
    -- state it had - which, in the usual case, is the game showing and hiding
    -- it for its unit, and that goes on working in combat. Anything that
    -- changed is caught up here the moment combat ends, since OnUpdate asks
    -- again every frame.
    function methods:ApplyVisibility()
        local wanted = WantedVisibility(self)
        if wanted == self.visibility or InCombatLockdown() then return end

        -- Recorded first: showing the plate runs OnShow, which runs Update,
        -- which comes back here, and must find the work already done.
        self.visibility = wanted

        if wanted == "watch" then
            if RegisterUnitWatch then RegisterUnitWatch(self) end
        else
            if UnregisterUnitWatch then UnregisterUnitWatch(self) end
            if wanted == "shown" then self:Show() else self:Hide() end
        end
    end

    -- Whether this plate has anything to draw at all.
    function methods:ShouldShow()
        local wanted = WantedVisibility(self)
        if wanted == "watch" then return UnitExists(self.unit) and true or false end
        return wanted == "shown"
    end

    -- Everything that follows the unit rather than the settings: who it is, what
    -- colour it is, and whether it is on screen at all.
    function methods:Update()
        local db = Options()

        -- The cast bar asks the same questions again for itself - it is on
        -- screen, or empty, in exactly the cases this function is - so it is
        -- brought up to date before any of the early returns below. This is
        -- also how Refresh reaches it.
        if self.castbar then self.castbar:Refresh() end

        -- Never Show or Hide here: that is ApplyVisibility's, out of combat,
        -- and the game's in it. This only paints.
        self:ApplyVisibility()

        if not db.enabled then return end

        if db.unlocked then
            -- Placement mode: empty bars with the one word on them, exactly as
            -- every other bar shows while it is being placed.
            self.health:SetMinMaxValues(0, 1)
            self.health:SetValue(0)
            self.power:SetMinMaxValues(0, 1)
            self.power:SetValue(0)
            self.prediction:SetValue(0)
            self.nameText:SetText(PLACEMENT_NAMES[self.unit] or self.unit)
            self.healthText:SetText(PLACEMENT_LABEL)
            self.powerText:SetText("")
            self.levelText:SetText("")
            self.leader:SetAlpha(0)
            self.healthSpark:SetAlpha(0)
            self.powerSpark:SetAlpha(0)
            if self.eliteBadge then self.eliteBadge:Hide() end
            if self.pvpBadge then self.pvpBadge:Hide() end
            return
        end

        -- No unit: the game has hidden it, and there is nothing to paint.
        if not self:ShouldShow() then return end

        local r, g, b = HealthColour(self.unit)
        self.health:SetStatusBarColor(r, g, b, 1)

        local heal = HEAL_COLOR
        self.prediction:SetStatusBarColor(heal[1], heal[2], heal[3], heal[4])

        self.power:SetStatusBarColor(PowerColour(self.unit))

        -- An if, not `showName and name or ""`: that form tests the name.
        if db.showName then
            ShowName(self.nameText, self.unit)
        else
            self.nameText:SetText("")
        end

        if db.showLevel then
            ShowLevel(self.levelText, self.unit)
            self.levelText:SetTextColor(LevelColour(self.unit))
        else
            self.levelText:SetText("")
        end

        ShowLeader(self.leader, self.unit)
        self:UpdateBadges()
        -- Its own events keep it right from here on; this is for a pet that
        -- arrived before it was made, or while the plate was hidden.
        if self.happiness and type(self.happiness.UpdateHappiness) == "function" then
            pcall(self.happiness.UpdateHappiness, self.happiness)
        end
    end

    -- The emblem inside a badge: the game's art, fitted inside `size` in its
    -- own proportions.
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

    -- The badges beside the plate. Repainted with everything else on a unit
    -- change, and on UNIT_FACTION (the PvP flag) and
    -- UNIT_CLASSIFICATION_CHANGED (elite, rare).
    function methods:UpdateBadges()
        if not self.pvpBadge then return end

        local diameter = self.badgeDiameter or CIRCLE_MIN
        local outside = self.badgeOnLeft and "LEFT" or "RIGHT"
        local inside = self.badgeOnLeft and "RIGHT" or "LEFT"

        -- ELITE - elite, rare, rare elite, boss: the bare emblem, no ring and
        -- no disc, in the name row at the frame's top right corner, in the
        -- crown's place and a little larger than it (the player asked: the
        -- circle beside the bars did not fit the look). A unit that is elite never
        -- leads a group, so the two never meet.
        local elite = EliteBadge(self.unit)
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

        -- PVP, on the plate's outer side, CIRCLE_GAP from the bars. Whether it
        -- is on may be a secret - UnitIsPVP is SecretWhenUnitIdentityRestricted
        -- - which is drawn from with SetAlphaFromBoolean and never looked at.
        local badge = self.pvpBadge
        local atlas, flagged = FactionBadge(self.unit)
        if not atlas or not Style:HasAtlas(atlas) then
            badge:Hide()
            return
        end

        badge:ClearAllPoints()
        badge:SetSize(diameter, diameter)
        badge:SetPoint(inside, self, outside,
            self.badgeOnLeft and -CIRCLE_GAP or CIRCLE_GAP, 0)
        SetEmblem(badge, atlas, diameter * 0.72)
        if type(badge.SetAlphaFromBoolean) == "function" then
            badge:SetAlphaFromBoolean(flagged, 1, 0)
        elseif IsSecret(flagged) then
            badge:Hide()
            return
        else
            badge:SetAlpha(flagged and 1 or 0)
        end
        badge:Show()
    end

    -- The bars themselves, repainted on a timer. Every value here is secret and
    -- none of them is read: they go straight to the widget, which draws what
    -- this addon may never see.
    function methods:OnUpdate(elapsed)
        -- A setting, or the target-of-target option, can change with no event
        -- and in combat; the plate is put right here as soon as it may be.
        self:ApplyVisibility()

        local db = Options()
        if not db.enabled or db.unlocked then return end

        -- Whether the unit is there is the game's to answer now, and it shows
        -- or hides the plate itself - see New. Hidden, there is nothing to
        -- paint; OnShow repaints it when it comes back. This used to call
        -- Update to show or hide the plate from here, which in combat was
        -- blocked, and retried, twenty times a second.
        if not self:IsShown() or not self:ShouldShow() then return end

        -- The target's target can become somebody else with no event of its
        -- own, so who it is gets re-read on a slower beat.
        if self.pollsIdentity then
            self.sinceIdentity = (self.sinceIdentity or 0) + (elapsed or 0)
            if self.sinceIdentity >= IDENTITY_INTERVAL then
                self.sinceIdentity = 0
                self:Update()
            end
        end

        local unit = self.unit
        local maxHealth = UnitHealthMax(unit)

        self.health:SetMinMaxValues(0, maxHealth)
        self.health:SetValue(UnitHealth(unit, false))

        -- The incoming heal, drawn without ever being worked out.
        --
        -- The bar covers the *missing* health - its left edge is anchored to the
        -- end of the health bar's own fill, so it starts exactly where health
        -- stops - and it is scaled to the missing health and filled with the
        -- heals on their way. Its width is then the heal's share of the missing
        -- health, of the missing health's share of the bar: the right answer,
        -- arrived at without this addon adding, dividing or reading anything.
        -- All three numbers are secret and all three are only ever passed on.
        --
        -- An earlier version drew UnitHealth(unit, true) - "predicted" health -
        -- on a bar behind the health bar and showed nothing at all in game.
        if db.showHealPrediction and UnitHealthMissing and UnitGetIncomingHeals then
            local incoming = UnitGetIncomingHeals(unit)
            -- Secret first: nothing may be compared to a secret, not even nil.
            if not IsSecret(incoming) and incoming == nil then incoming = 0 end

            self.prediction:SetMinMaxValues(0, UnitHealthMissing(unit, false))
            self.prediction:SetValue(incoming)
            self.prediction:Show()
        else
            self.prediction:Hide()
        end

        self.power:SetMinMaxValues(0, UnitPowerMax(unit))
        self.power:SetValue(UnitPower(unit))

        -- Each spark shows only between empty and full, which the game works
        -- out from the secret values and hands straight to the spark.
        self.healthSpark:SetAlpha(Style.HealthSparkAlpha(unit))
        self.powerSpark:SetAlpha(Style.PowerSparkAlpha(unit))

        if db.showHealthText then
            ShowValue(self.healthText, UnitHealth(unit, false), HealthPercent(unit))
        else
            self.healthText:SetText("")
        end

        if db.showPowerText then
            ShowValue(self.powerText, UnitPower(unit), PowerPercent(unit))
        else
            self.powerText:SetText("")
        end

    end

    -- A dragged position is the player's, and is never recomputed by the addon.
    -- Only the position is written: dragging cannot resize a plate, and reading
    -- the size back would round it a little on every drag and quietly overwrite
    -- a size typed into the options panel.
    function methods:SavePosition()
        local db = Options()
        db[self.key .. "Placed"] = true
        db[self.key .. "Left"] = self:GetLeft()
        db[self.key .. "Top"] = -1 * (GetScreenHeight() - self:GetTop())

        NS.Refresh()
        DogsForeverUI.RefreshOptions()
    end
end
