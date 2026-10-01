-- The game's nameplates, in the addon's look - style only.
--
-- Only the health bar changes: the flat fill with its sheen and shade, the
-- black background and the addon's border (Core\Style.lua), thin - and the
-- level loses its box beside the bar and is plain text inside it, ahead of
-- the name, the bar taking the box's room (see PlaceBar); and in the styles
-- with the name above the bar, the health numbers move inside it (see
-- HealthTexts). The plate's cast bar wears the castbars' look too, a little
-- apart from the health bar (see StyleCast). This client loads no class bars
-- (combo points and the like) on nameplates. Everything else on a nameplate -
-- its size and place, the auras, the colours - stays the game's. The game
-- still colours the bar itself (class, reaction, threat); on the flat fill
-- that colour is simply drawn plain. The
-- game's bright ring round the target's bar goes: round the addon's border it
-- was a second border. The game still dims the plates that are not the
-- target, so the target keeps standing out.
--
-- WHAT IS AND IS NOT TOUCHED
-- The game builds a nameplate's look in NamePlateUnitFrameMixin:UpdateAnchors
-- (Blizzard_NamePlates\Blizzard_NamePlateUnitFrame.lua), which puts its own
-- bar art (UI-HUD-CoolDownManager-Bar) and shadowed background
-- (UI-HUD-CoolDownManager-Bar-BG) back every time a plate is set up for a unit,
-- and whenever the nameplate options or the screen change. So the look is
-- re-applied after it, from hooksecurefunc post-hooks: on the plate's own
-- UpdateAnchors, on the driver's OnNamePlateAdded, and on its
-- UpdateNamePlateOptions. No function of the game's is replaced or called, and
-- nothing is written into its tables: the game's layout code also sets the
-- plate's click area, which it may only do from untainted code in combat, so
-- this addon never starts that code and never leaves a value of its own where
-- that code reads. What was added to a plate is kept here, keyed by the plate.
--
-- Only widget calls are made on the game's regions: the bar's fill is given
-- the flat texture (the same texture object, which other parts of the plate
-- are anchored to) and the shadowed background is faded to nothing; the
-- background, sheen and border are the addon's own.
--
-- PLATES AN ADDON MAY NOT HAVE
-- The game keeps some nameplates forbidden to addons (in the live game, the
-- friendly ones inside instances). C_NamePlate.GetNamePlateForUnit does not
-- hand those to an addon at all, and they keep the game's look.

local NamePlates = {}
DogsForeverUI.Frames.NamePlates = NamePlates

do -- private scope

    local NS = DogsForeverUI.Frames
    local Style = DogsForeverUI.Style

    -- The game's own bar art, put back when the option is switched off -
    -- exactly as UpdateAnchors sets it for every style this client offers.
    local GAME_BAR_ATLAS = "UI-HUD-CoolDownManager-Bar"

    -- What the addon added to each health bar, and which plates' UpdateAnchors
    -- is already followed. Weak: the game's plates are pooled and reused, and
    -- these go when a plate does.
    local parts = setmetatable({}, { __mode = "k" })
    local followed = setmetatable({}, { __mode = "k" })
    local driverFollowed = false

    local function Wanted()
        return NS.db ~= nil
    end

    local function HealthBar(unitFrame)
        local container = unitFrame.HealthBarsContainer
        return container and container.healthBar
    end

    -- The addon's pieces on one health bar, made the first time it is seen.
    local function Parts(bar)
        local made = parts[bar]
        if made then return made end
        made = {}
        made.background = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
        made.background:SetAllPoints(bar)
        Style.SetBackground(made.background)
        made.sheen, made.shade = Style.MakeSheen(bar)
        -- Not at the plate's scale, which the game changes with distance, so
        -- its lines stay on whole pixels; and thin - one real pixel a line -
        -- since the frames' two-pixel lines are heavy on a bar this small.
        made.border = Style.AddBorder(bar, nil, true, 1)
        parts[bar] = made
        return made
    end

    local function Show(made, shown)
        made.background:SetShown(shown)
        made.sheen:SetShown(shown)
        made.shade:SetShown(shown)
        made.border:SetShown(shown)
    end

    -- The game's own art that goes while the look is on, and comes back with
    -- the game's look: the bar's shadowed background, the bright ring the game
    -- draws round the target's (and focus's) bar - which, round the addon's
    -- border, made a second border - and on the level box to the bar's right,
    -- the box and its own ring, so the level is plain text (moved into the
    -- bar, see PlaceLevel). The level's number and skull stay. The game shows,
    -- hides and places these, but never sets their alpha, so fading them
    -- sticks.
    local function GameArt(unitFrame, bar)
        local art = { bar.bgTexture, bar.selectedBorder }
        local level = unitFrame.PlayerLevelDiffFrame
        if level then
            art[#art + 1] = level.playerLevelDiffIcon
            art[#art + 1] = level.selectedBorder
        end
        return art
    end

    -- THE HEALTH TEXT. In the styles that put the name above the bar (this
    -- client's "Default" and "Cast Focus": NAME_ANCHOR_STYLES.AboveHealthBar),
    -- the game puts the health text in the same row, at the bar's top right,
    -- and centres the name across the row - reaching over to the level box
    -- when that shows - so a long name ran into the numbers. With the look on,
    -- the numbers go inside the bar at its right end, exactly where the game
    -- puts them for the styles with the name inside (UpdateAnchors,
    -- InsideHealthBar), and the name has the row to itself. Off, they go back
    -- to the game's places for that style. Only the three strings are moved;
    -- the style is read, never written.
    local function Setup()
        return type(NamePlateSetupOptions) == "table" and NamePlateSetupOptions or {}
    end

    -- Whether the game's nameplate options are in this name style
    -- (NamePlateConstants.NAME_ANCHOR_STYLES), read and never written.
    local function NameStyle(key)
        if type(NamePlateConstants) ~= "table" then return false end
        local styles = NamePlateConstants.NAME_ANCHOR_STYLES
        return type(styles) == "table" and styles[key] ~= nil
            and Setup().unitNameAnchorStyle == styles[key]
    end

    local function HealthTexts(bar, inside)
        local left, right, text = bar.LeftText, bar.RightText, bar.Text
        if not (left and right and text) then return end
        left:ClearAllPoints()
        right:ClearAllPoints()
        text:ClearAllPoints()
        if inside then
            left:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
            right:SetPoint("RIGHT", left, "LEFT", -2, 0)
            text:SetPoint("RIGHT", right, "LEFT", 2, 0)
        else
            left:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -4, 2)
            right:SetPoint("BOTTOMRIGHT", left, "BOTTOMLEFT", -2, 0)
            text:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 2, 0)
        end
    end

    -- THE CAST BAR under each plate, in the castbars' look: the same flat fill,
    -- sheen, black background and thin border as the health bar, in the
    -- castbar's colours for each kind of cast (Style.CAST_COLOR). The game
    -- puts its own fill art back in CastingBarMixin:UpdateBarFillTexture every
    -- time the bar changes kind - a cast starting, turning uninterruptible,
    -- being interrupted, finishing - so each plate's cast bar has that followed,
    -- once, and the look put back after it. Its height, icon, spark and glows
    -- stay the game's; where it sits is PlaceCast's, and its text's size is
    -- SizeTexts'. Switched off, the addon's parts are hidden and the game's
    -- own fill comes back with the next cast.
    local CAST_KIND = {
        standard = "casting", empowered = "casting",
        applyingcrafting = "casting", applyingtalents = "casting",
        channel = "channel", uninterruptable = "uninterruptible",
        interrupted = "failed",
    }
    local castParts = setmetatable({}, { __mode = "k" })
    local castFollowed = setmetatable({}, { __mode = "k" })
    local castFailed = setmetatable({}, { __mode = "k" })   -- cast bar -> interrupted
    local castLocked = setmetatable({}, { __mode = "k" })   -- cast bar -> can't interrupt

    -- WHEN THE KIND IS A SECRET. What kind of cast it is - castBar.barType -
    -- is a secret for most units on this client (the game wraps it in
    -- WrapValueInSpellCastSecrecy), and a secret may not be tested or used
    -- as a key. So then the kind is put together from what can be known:
    -- the bar's own casting/channeling flags, which the game sets plainly from
    -- the event; the interrupt, which the game marks by playing its interrupt
    -- animation (PlayInterruptAnims, followed); and whether the cast can be
    -- interrupted, which is a secret too - it is asked of UnitCastingInfo /
    -- UnitChannelInfo and handed, untested, to SetVertexColorFromBoolean,
    -- which picks the grey or the kind's colour without anyone looking. The
    -- fill is the addon's flat texture either way.
    local function Colour(key)
        local c = Style.CAST_COLOR[key]
        return c[1], c[2], c[3]
    end

    -- A cast bar that has never shown a cast (a name-only plate's, say) has no
    -- fill yet: the game makes it in UpdateBarFillTexture, which is followed,
    -- so the look goes on with the first cast.
    local function PaintCast(castBar)
        if not Wanted() or not castParts[castBar] then return end
        local fill = castBar:GetStatusBarTexture()
        if not fill then return end
        fill:SetTexture(Style.FLAT_TEXTURE)
        fill:SetHorizTile(false)
        fill:SetVertTile(false)

        local kind = castBar.barType
        if not issecretvalue(kind) then
            castBar:SetStatusBarColor(Colour((kind ~= nil and CAST_KIND[kind]) or "casting"))
            return
        end

        local key = "casting"
        if castFailed[castBar] then
            key = "failed"
        elseif castBar.channeling then
            key = "channel"
        end
        castBar:SetStatusBarColor(Colour(key))
        local locked = castLocked[castBar]
        if key ~= "failed" and issecretvalue(locked)
                and type(fill.SetVertexColorFromBoolean) == "function" and CreateColor then
            local r, g, b = Colour("uninterruptible")
            local r2, g2, b2 = Colour(key)
            fill:SetVertexColorFromBoolean(locked, CreateColor(r, g, b, 1), CreateColor(r2, g2, b2, 1))
        elseif key ~= "failed" and not issecretvalue(locked) and locked == true then
            castBar:SetStatusBarColor(Colour("uninterruptible"))
        end
    end

    -- A cast began, or turned (un)interruptible: the game shows or hides the
    -- icon after setting its flags, in both.
    local function OnCastIcon(castBar)
        castFailed[castBar] = nil
        local unit = castBar.unit
        local locked
        if type(unit) == "string" then
            if castBar.channeling then
                locked = select(7, UnitChannelInfo(unit))
            else
                locked = select(8, UnitCastingInfo(unit))
            end
        end
        castLocked[castBar] = locked
        PaintCast(castBar)
    end

    local function OnCastInterrupted(castBar)
        castFailed[castBar] = true
        PaintCast(castBar)
    end

    local function OnlyName(unitFrame)
        return type(unitFrame.IsShowOnlyName) == "function" and unitFrame:IsShowOnlyName() == true
    end

    -- THE LEVEL AND THE BAR'S WIDTH. The game puts the level in a box to the
    -- right of the health bar and makes the health bar that much narrower
    -- than the plate (UpdateAnchors: the health bars' container ends the
    -- level box's width short of the cast bars' one). With the look on, the
    -- level is plain text inside the bar at its left end, ahead of the name,
    -- and the bar runs the plate's whole width - the cast bar's width. The
    -- game's box frame stays where it was, now over the bar's right end,
    -- with nothing in it: the auras to the right of the plate and the name
    -- above it, both placed off that box, keep their places. Only the bar
    -- inside its container is widened, by exactly what the game took off
    -- (its own test, ShouldDisplay; and the box's width, which it sets from
    -- the options). Off, the game's places come back.
    --
    -- NOTHING ON A PLATE IS MEASURED. An addon may not read where a region of
    -- a nameplate is or how big (GetPoint, GetWidth, GetEffectiveScale...):
    -- the game refuses it ("Can't measure restricted regions") and blames the
    -- addon. So the box's width comes from the options the game sized it by
    -- (ApplyFrameOptions: playerLevelDiffWidth), and on this client the box
    -- always hangs off the bar's right (Camelot\Blizzard_NamePlateLevelFrame
    -- .xml; nothing moves it). Only the addon's own frames are measured.
    local LEVEL_X = 4                   -- the level's inset from the bar's left
    local LEVEL_GAP = 3                 -- from the level to the name

    local function LevelWidth(unitFrame)
        local level = unitFrame.PlayerLevelDiffFrame
        if not level or type(level.ShouldDisplay) ~= "function" then return 0 end
        if not level:ShouldDisplay(unitFrame.unit) then return 0 end
        local width = Setup().playerLevelDiffWidth
        return type(width) == "number" and width or 0
    end

    local function PlaceBar(unitFrame, ours)
        if Setup().useClassicHealthBar then return end
        local bar, container = HealthBar(unitFrame), unitFrame.HealthBarsContainer
        if not bar or not container then return end
        local widen = ours and LevelWidth(unitFrame) or 0
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", widen, 0)
    end

    -- The level's number, or the skull for a unit too high to tell - the game
    -- shows one or the other - and whichever shows, for the name to follow.
    local function PlaceLevel(unitFrame, ours)
        local level, bar = unitFrame.PlayerLevelDiffFrame, HealthBar(unitFrame)
        if not level or not bar then return end
        local text, skull, icon = level.playerLevelDiffText, level.highLevelTexture, level.playerLevelDiffIcon
        if not text or not icon then return end
        local setup = Setup()
        text:ClearAllPoints()
        if skull then skull:ClearAllPoints() end
        if ours then
            text:SetPoint("LEFT", bar, "LEFT", LEVEL_X, 0)
            if skull then
                local size = type(setup.levelFontHeight) == "number" and setup.levelFontHeight or 10
                skull:SetSize(size, size)
                skull:SetPoint("LEFT", bar, "LEFT", LEVEL_X, 0)
            end
        else
            text:SetPoint("CENTER", icon, "CENTER", 0, 0)
            if skull then
                local size = setup.playerLevelDiffHeight
                if type(size) == "number" then skull:SetSize(size, size) end
                skull:SetPoint("CENTER", icon, "CENTER", 0, 0)
            end
        end
    end

    local function ShownLevel(unitFrame)
        local level = unitFrame.PlayerLevelDiffFrame
        if not level or not level:IsShown() then return nil end
        local skull = level.highLevelTexture
        if skull and skull:IsShown() then return skull end
        return level.playerLevelDiffText
    end

    -- In the style with the name inside the bar, the name starts after the
    -- level; its right end stays the game's, short of the health numbers.
    -- Above the bar, the name has its own row and is not moved.
    local function PlaceName(unitFrame, ours)
        if not NameStyle("InsideHealthBar") or OnlyName(unitFrame) then return end
        local name, bar, container = unitFrame.name, HealthBar(unitFrame), unitFrame.HealthBarsContainer
        if not name or not bar or not container or not bar.Text then return end
        local level = ours and ShownLevel(unitFrame)
        name:ClearAllPoints()
        if level then
            name:SetPoint("LEFT", level, "RIGHT", LEVEL_GAP, 0)
        else
            name:SetPoint("LEFT", container, "LEFT", 4, 0)
        end
        name:SetPoint("RIGHT", bar.Text, "LEFT", -2, 0)
    end

    local function PlaceLevelAndName(unitFrame, ours)
        ours = ours and not OnlyName(unitFrame)
        PlaceLevel(unitFrame, ours)
        PlaceName(unitFrame, ours)
    end

    -- THE TEXT SIZE. The game sizes the name and the health numbers
    -- (healthBarFontHeight) and the spell name (castBarFontHeight) larger
    -- than the level (levelFontHeight), in different fonts, so in one row
    -- they sat at different heights. With the look on, every one of them is
    -- the level's size, and the level and the health numbers wear the font
    -- the name wears inside the bar (outlined), so everything in the bar
    -- shares one size, one font and one middle line. Only the strings'
    -- sizes and fonts are set - never the game's font objects themselves.
    -- Off, the game's sizes and fonts come back, as ApplyFrameOptions sets
    -- them.
    local INSIDE_FONT = "SystemFont_NamePlate_Outlined"
    local ABOVE_FONT = "SystemFont_NamePlate"
    local LEVEL_FONT = "SystemFont_NamePlateLevel"

    local function SetText(label, fontName, size)
        if not label then return end
        local font = fontName and _G[fontName]
        if type(font) == "table" then label:SetFontObject(font) end
        if type(size) == "number" then label:SetTextHeight(size) end
    end

    local function SizeTexts(unitFrame, ours)
        local setup = Setup()
        local bar = HealthBar(unitFrame)
        local level = unitFrame.PlayerLevelDiffFrame
        local castBar = unitFrame.CastBarsContainer and unitFrame.CastBarsContainer.castBar
        local numbers = bar and { bar.LeftText, bar.RightText, bar.Text } or {}
        local casts = castBar and { castBar.Text, castBar.CastTargetNameText } or {}

        if ours then
            local size = setup.levelFontHeight
            if type(size) ~= "number" then return end
            if level then SetText(level.playerLevelDiffText, INSIDE_FONT, size) end
            for _, label in pairs(numbers) do SetText(label, INSIDE_FONT, size) end
            SetText(unitFrame.name, nil, size)
            for _, label in pairs(casts) do SetText(label, nil, size) end
        else
            if level then SetText(level.playerLevelDiffText, LEVEL_FONT, setup.levelFontHeight) end
            local numbersFont = (NameStyle("InsideHealthBar") or NameStyle("CenteredAboveHealthBar"))
                and INSIDE_FONT or ABOVE_FONT
            for _, label in pairs(numbers) do SetText(label, numbersFont, setup.healthBarFontHeight) end
            SetText(unitFrame.name, nil, setup.healthBarFontHeight)
            for _, label in pairs(casts) do SetText(label, nil, setup.castBarFontHeight) end
        end
    end

    -- WHERE THE CAST BAR GOES. The game hangs it at the top of a container
    -- under the health bar, a few pixels below it (NamePlateCastingBarMixin:
    -- ApplyStyleAndAnchoring). Framed, the two borders met. With the look on,
    -- it keeps its width - the plate's, which the health bar now has too - and
    -- sits right under the health bar with both borders and CAST_GAP clear
    -- pixels between; the icon and spell-name row, which the game puts under
    -- the bar in the styles without the name inside it, moves down with it.
    -- Its height stays the game's. Off, the game's own places come back - its
    -- non-classic anchoring, as ApplyStyleAndAnchoring has it. This client
    -- offers no classic style; a classic bar is left alone.
    --
    -- The gap is in real pixels, which needs a scale - and the plate's may
    -- not be read (see LevelWidth). So it is the height of a spacer of the
    -- addon's own under the health bar, off the plate's scale like the
    -- borders, whose own scale can be read; the cast bar hangs from it. The
    -- icon and spell-name row under the cast bar hangs from a second one
    -- under the cast bar: straight under the bar, the name's top ran under
    -- the cast bar's border, which is drawn over it, so it showed half.
    local CAST_GAP = 3                  -- clear pixels between the two borders
    local BORDER_PIXELS = 3             -- each thin border's three lines
    local TEXT_GAP = 2                  -- clear pixels from the border to the spell name

    local function Spacer(owner, made, pixels)
        if not made then return nil end
        local spacer = made.spacer
        if not spacer then
            spacer = CreateFrame("Frame", nil, owner)
            spacer:SetIgnoreParentScale(true)
            spacer:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, 0)
            spacer:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, 0)
            made.spacer = spacer
        end
        local px = 1
        if PixelUtil and PixelUtil.GetPixelToUIUnitFactor then
            local scale = spacer:GetEffectiveScale()
            if type(scale) == "number" and scale > 0 then
                px = PixelUtil.GetPixelToUIUnitFactor() / scale
            end
        end
        spacer:SetHeight(pixels * px)
        return spacer
    end

    local function PlaceCast(unitFrame, castBar, ours)
        local setup = Setup()
        if setup.useClassicCastBar then return end
        local bar = HealthBar(unitFrame)
        local parent = unitFrame.CastBarsContainer
        local icon = castBar.Icon
        local spacer = ours and bar and Spacer(bar, parts[bar], 2 * BORDER_PIXELS + CAST_GAP)
        local under = ours and Spacer(castBar, castParts[castBar], BORDER_PIXELS + TEXT_GAP)
        if not bar or not parent or not icon or (ours and not (spacer and under)) then return end

        castBar:ClearAllPoints()
        icon:ClearAllPoints()
        if ours then
            castBar:SetPoint("TOPLEFT", spacer, "BOTTOMLEFT", 0, 0)
            castBar:SetPoint("TOPRIGHT", spacer, "BOTTOMRIGHT", 0, 0)
            if setup.spellNameInsideCastBar then
                icon:SetPoint("LEFT", castBar, "LEFT", 0, 0)
            else
                icon:SetPoint("TOPLEFT", under, "BOTTOMLEFT", 0, 0)
            end
        elseif setup.spellNameInsideCastBar then
            castBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            castBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
            icon:SetPoint("LEFT", castBar, "LEFT", 0, 0)
        else
            icon:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
            castBar:SetPoint("BOTTOM", icon, "TOP", 0, 0)
            castBar:SetPoint("LEFT", parent, "BOTTOMLEFT", 0, 0)
            castBar:SetPoint("RIGHT", parent, "BOTTOMRIGHT", 0, 0)
        end
    end

    local function StyleCast(unitFrame)
        local container = unitFrame.CastBarsContainer
        local castBar = container and container.castBar
        if not castBar then return end

        if Wanted() then
            if not castParts[castBar] then
                local made = {}
                made.background = castBar:CreateTexture(nil, "BACKGROUND", nil, -8)
                made.background:SetAllPoints(castBar)
                Style.SetBackground(made.background)
                made.sheen, made.shade = Style.MakeSheen(castBar)
                made.border = Style.AddBorder(castBar, nil, true, 1)
                castParts[castBar] = made
            end
            if not castFollowed[castBar] and type(castBar.UpdateBarFillTexture) == "function" then
                castFollowed[castBar] = true
                hooksecurefunc(castBar, "UpdateBarFillTexture", PaintCast)
                if type(castBar.UpdateIconShown) == "function" then
                    hooksecurefunc(castBar, "UpdateIconShown", OnCastIcon)
                end
                if type(castBar.PlayInterruptAnims) == "function" then
                    hooksecurefunc(castBar, "PlayInterruptAnims", OnCastInterrupted)
                end
            end
            Show(castParts[castBar], true)
            if castBar.Background then castBar.Background:SetAlpha(0) end
            PaintCast(castBar)
            PlaceCast(unitFrame, castBar, true)
        elseif castParts[castBar] then
            Show(castParts[castBar], false)
            if castBar.Background then castBar.Background:SetAlpha(1) end
            PlaceCast(unitFrame, castBar, false)
        end
    end

    -- Put the look on one plate, or hand the game's back.
    local function Apply(unitFrame)
        if not unitFrame or unitFrame:IsForbidden() then return end
        local bar = HealthBar(unitFrame)
        if not bar then return end
        local fill = bar:GetStatusBarTexture()

        if Wanted() then
            Show(Parts(bar), true)
            fill:SetTexture(Style.FLAT_TEXTURE)
            fill:SetHorizTile(false)
            fill:SetVertTile(false)
            for _, region in pairs(GameArt(unitFrame, bar)) do region:SetAlpha(0) end
            if NameStyle("AboveHealthBar") then HealthTexts(bar, true) end
            PlaceBar(unitFrame, true)
            PlaceLevelAndName(unitFrame, true)
            SizeTexts(unitFrame, true)
        elseif parts[bar] then
            Show(parts[bar], false)
            fill:SetAtlas(GAME_BAR_ATLAS, true)
            for _, region in pairs(GameArt(unitFrame, bar)) do region:SetAlpha(1) end
            if NameStyle("AboveHealthBar") then HealthTexts(bar, false) end
            PlaceBar(unitFrame, false)
            PlaceLevelAndName(unitFrame, false)
            SizeTexts(unitFrame, false)
        end
        StyleCast(unitFrame)
    end

    -- The game puts the level's number back over its box whenever it sets
    -- the level - a new unit, or the unit's level changing - without laying
    -- the plate out again; so that is followed too, for the plates here.
    local function OnLevel(unitFrame)
        if followed[unitFrame] and Wanted() and parts[HealthBar(unitFrame) or false] then
            PlaceLevelAndName(unitFrame, true)
        end
    end

    -- Follow a plate's own UpdateAnchors, once per plate: that is where the
    -- game puts its art back, whatever asked it to.
    local function Follow(unitFrame)
        if followed[unitFrame] or type(unitFrame.UpdateAnchors) ~= "function" then return end
        followed[unitFrame] = true
        hooksecurefunc(unitFrame, "UpdateAnchors", Apply)
    end

    local function Take(plate)
        local unitFrame = plate and plate.UnitFrame
        if not unitFrame or unitFrame:IsForbidden() then return end
        Follow(unitFrame)
        Apply(unitFrame)
    end

    -- A unit got a plate. Asked for the way an addon may ask: a forbidden
    -- plate comes back as nothing, and is left alone.
    local function OnAdded(_, unit)
        if type(C_NamePlate) ~= "table" or not C_NamePlate.GetNamePlateForUnit then return end
        Take(C_NamePlate.GetNamePlateForUnit(unit))
    end

    -- FRIENDLY PLAYERS: NAMES ONLY. Inside instances the game gives friendly
    -- units forbidden plates (ForbiddenNamePlateUnitFrameTemplate), which an
    -- addon can neither get nor touch, so the party's plates there kept the
    -- game's look. With the look on, friendly players' plates are held to
    -- the name alone - the game's own setting for it,
    -- nameplateShowOnlyNameForFriendlyPlayerUnits (Options > Nameplates >
    -- Friendly Player Nameplates > show only name), which the game applies to
    -- forbidden plates too; the name is in the player's font already
    -- (Core\Fonts.lua). It applies everywhere, not only in instances: the
    -- game has no instance-only form of it.
    --
    -- Held: set when the look comes on, at every login and loading screen,
    -- and again whenever anything - the game's options included - turns it
    -- off while the look is on. Never in combat, where the game may refuse
    -- the change; then once combat ends. The game reacts to the change from
    -- its own CVAR_UPDATE event, so none of its plate code runs from here.
    -- Switched off, the setting goes back to the game's default (off) - only
    -- if this addon had been holding it, so a player's own choice with the
    -- look off is never touched.
    local NAMES_ONLY_CVAR = "nameplateShowOnlyNameForFriendlyPlayerUnits"
    local holding = false
    local pending = false

    local function GetSetting()
        if type(C_CVar) == "table" and C_CVar.GetCVar then return C_CVar.GetCVar(NAMES_ONLY_CVAR) end
        if type(GetCVar) == "function" then return GetCVar(NAMES_ONLY_CVAR) end
    end

    local function SetSetting(value)
        if type(C_CVar) == "table" and C_CVar.SetCVar then
            pcall(C_CVar.SetCVar, NAMES_ONLY_CVAR, value)
        elseif type(SetCVar) == "function" then
            pcall(SetCVar, NAMES_ONLY_CVAR, value)
        end
    end

    function NamePlates.HoldNamesOnly()
        if InCombatLockdown() then
            pending = true
            return
        end
        pending = false
        if Wanted() then
            holding = true
            if GetSetting() ~= "1" then SetSetting("1") end
        elseif holding then
            holding = false
            if GetSetting() ~= "0" then SetSetting("0") end
        end
    end

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:RegisterEvent("CVAR_UPDATE")
    watcher:SetScript("OnEvent", function(_, event, name)
        if event == "PLAYER_REGEN_ENABLED" then
            if pending then NamePlates.HoldNamesOnly() end
        elseif event == "CVAR_UPDATE" then
            if name == NAMES_ONLY_CVAR and holding then NamePlates.HoldNamesOnly() end
        elseif NS.db then
            NamePlates.HoldNamesOnly()
        end
    end)

    -- Every plate on screen, after a setting of the addon's or the game's.
    function NamePlates.Refresh()
        if NS.db then NamePlates.HoldNamesOnly() end
        if type(C_NamePlate) ~= "table" or not C_NamePlate.GetNamePlates then return end
        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do Take(plate) end
    end

    -- The game's nameplate driver is there from the start on this client; the
    -- hooks go on it once.
    function NamePlates.Init()
        if driverFollowed or type(NamePlateDriverFrame) ~= "table" then return end
        driverFollowed = true
        hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", OnAdded)
        if type(NamePlateDriverFrame.UpdateNamePlateOptions) == "function" then
            hooksecurefunc(NamePlateDriverFrame, "UpdateNamePlateOptions", NamePlates.Refresh)
        end
        if type(CompactUnitFrame_UpdatePlayerLevelDiff) == "function" then
            hooksecurefunc("CompactUnitFrame_UpdatePlayerLevelDiff", OnLevel)
        end
        NamePlates.Refresh()
    end
end
