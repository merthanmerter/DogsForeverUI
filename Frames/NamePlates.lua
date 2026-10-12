-- The game's nameplates, in the addon's look - style only.
--
-- Only the health bar changes: the flat fill with its sheen and shade, the
-- black background and the addon's border (Core\Style.lua), thin - and the
-- level loses its box beside the bar and is plain text inside it, ahead of
-- the name, the bar taking the box's room (see PlaceBar); and in the styles
-- with the name above the bar, the health numbers move inside it (see
-- HealthTexts). The plate's cast bar wears the castbars' look too, a little
-- apart from the health bar (see StyleCast). A party member's plate carries
-- the game's group icon beside the name (see PlaceMark). This client loads no class bars
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

    local Style = DogsForeverUI.Style

    -- What the addon added to each health bar, and which plates' UpdateAnchors
    -- is already followed. Weak: the game's plates are pooled and reused, and
    -- these go when a plate does.
    local parts = setmetatable({}, { __mode = "k" })
    local followed = setmetatable({}, { __mode = "k" })
    local driverFollowed = false

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

    local function Show(made)
        made.background:Show()
        made.sheen:Show()
        made.shade:Show()
        made.border:Show()
    end

    -- The game's own art that goes: the bar's shadowed background, the bright ring the game
    -- draws round the target's (and focus's) bar - which, round the addon's
    -- border, made a second border - and on the level box to the bar's right,
    -- the box and its own ring, so the level is plain text (moved into the
    -- bar, see PlaceLevel). The level's number and skull stay. The game shows,
    -- hides and places these, but never sets their alpha, so fading them
    -- sticks.
    local function Fade(region)
        if region then region:SetAlpha(0) end
    end

    local function FadeGameArt(unitFrame, bar)
        Fade(bar.bgTexture)
        Fade(bar.selectedBorder)
        local level = unitFrame.PlayerLevelDiffFrame
        if level then
            Fade(level.playerLevelDiffIcon)
            Fade(level.selectedBorder)
        end
    end

    -- THE HEALTH TEXT. In the styles that put the name above the bar (this
    -- client's "Default" and "Cast Focus": NAME_ANCHOR_STYLES.AboveHealthBar),
    -- the game puts the health text in the same row, at the bar's top right,
    -- and centres the name across the row - reaching over to the level box
    -- when that shows - so a long name ran into the numbers. So the numbers
    -- go inside the bar at its right end, exactly where the game puts them
    -- for the styles with the name inside (UpdateAnchors, InsideHealthBar),
    -- and the name has the row to itself. Only the three strings are moved;
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

    local function HealthTexts(bar)
        local left, right, text = bar.LeftText, bar.RightText, bar.Text
        if not (left and right and text) then return end
        left:ClearAllPoints()
        right:ClearAllPoints()
        text:ClearAllPoints()
        left:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        right:SetPoint("RIGHT", left, "LEFT", -2, 0)
        text:SetPoint("RIGHT", right, "LEFT", 2, 0)
    end

    -- THE CAST BAR under each plate, in the castbars' look: the same flat fill,
    -- sheen, black background and thin border as the health bar, in the
    -- castbar's colours for each kind of cast (Style.CAST_COLOR). The game
    -- puts its own fill art back in CastingBarMixin:UpdateBarFillTexture every
    -- time the bar changes kind - a cast starting, turning uninterruptible,
    -- being interrupted, finishing - so each plate's cast bar has that followed,
    -- once, and the look put back after it. Its height, icon, spark and glows
    -- stay the game's; where it sits is PlaceCast's, and its text's size is
    -- SizeTexts'.
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
        if not castParts[castBar] then return end
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
    -- level box's width short of the cast bars' one). Here the level is plain
    -- text inside the bar at its left end, ahead of the name, and the bar
    -- runs the plate's whole width - the cast bar's width. The game's box
    -- frame stays where it was, now over the bar's right end, with nothing in
    -- it: the auras to the right of the plate and the name above it, both
    -- placed off that box, keep their places. Only the bar inside its
    -- container is widened, by exactly what the game took off (its own test,
    -- ShouldDisplay; and the box's width, which it sets from the options). A
    -- names-only plate keeps the game's places for the level.
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
    -- The skull's art has empty margins round it, so at the font's height it
    -- reads far smaller than the digits it stands in for.
    local SKULL_SCALE = 1.6

    local function LevelWidth(unitFrame)
        local level = unitFrame.PlayerLevelDiffFrame
        if not level or type(level.ShouldDisplay) ~= "function" then return 0 end
        if not level:ShouldDisplay(unitFrame.unit) then return 0 end
        local width = Setup().playerLevelDiffWidth
        return type(width) == "number" and width or 0
    end

    local function PlaceBar(unitFrame)
        if Setup().useClassicHealthBar then return end
        local bar, container = HealthBar(unitFrame), unitFrame.HealthBarsContainer
        if not bar or not container then return end
        local widen = LevelWidth(unitFrame)
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
                size = size * SKULL_SCALE
                -- Never taller than the bar it sits in: the thin bars (Cast
                -- Focus) are shorter than the scaled skull. The bar's height
                -- is the option the game sizes it by, never measured.
                local barHeight = setup.healthBarHeight
                if type(barHeight) == "number" and barHeight > 0 then
                    size = math.min(size, barHeight)
                end
                skull:SetSize(size, size)
                -- Snapped to the pixel grid on its own, a texture taller
                -- than its bar jumped a pixel up and down as the plate
                -- scaled with distance; it moves with the bar instead.
                if skull.SetSnapToPixelGrid then
                    skull:SetSnapToPixelGrid(false)
                    skull:SetTexelSnappingBias(0)
                end
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
    local function PlaceName(unitFrame)
        if not NameStyle("InsideHealthBar") or OnlyName(unitFrame) then return end
        local name, bar, container = unitFrame.name, HealthBar(unitFrame), unitFrame.HealthBarsContainer
        if not name or not bar or not container or not bar.Text then return end
        local level = ShownLevel(unitFrame)
        name:ClearAllPoints()
        if level then
            name:SetPoint("LEFT", level, "RIGHT", LEVEL_GAP, 0)
        else
            name:SetPoint("LEFT", container, "LEFT", 4, 0)
        end
        name:SetPoint("RIGHT", bar.Text, "LEFT", -2, 0)
    end

    local function PlaceLevelAndName(unitFrame)
        PlaceLevel(unitFrame, not OnlyName(unitFrame))
        PlaceName(unitFrame)
    end

    -- THE TEXT SIZE. The game sizes the name and the health numbers
    -- (healthBarFontHeight) and the spell name (castBarFontHeight) larger
    -- than the level (levelFontHeight), in different fonts, so in one row
    -- they sat at different heights. Here every one of them is the level's
    -- size, and the level and the health numbers wear the font the name
    -- wears inside the bar (outlined), so everything in the bar shares one
    -- size, one font and one middle line. Only the strings' sizes and fonts
    -- are set - never the game's font objects themselves.
    local INSIDE_FONT = "SystemFont_NamePlate_Outlined"

    local function SetText(label, fontName, size)
        if not label then return end
        local font = fontName and _G[fontName]
        if type(font) == "table" then label:SetFontObject(font) end
        if type(size) == "number" then label:SetTextHeight(size) end
    end

    -- A FRIENDLY NAME'S SIZE (the player, 2026-10-03: "friendly names should
    -- be slightly smaller"): a plate showing the name only (a friendly
    -- player's) writes it at FRIENDLY_NAME of the plates' text size. Larger
    -- while targeted: THE TARGET GROWN, below.
    NamePlates.FRIENDLY_NAME = 0.85

    -- The target's plate's unit frame, or nil: asked once, compared as a frame.
    local function TargetFrame()
        if type(C_NamePlate) ~= "table" or not C_NamePlate.GetNamePlateForUnit then return nil end
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
        return ok and type(plate) == "table" and plate.UnitFrame or nil
    end

    function NamePlates.NameSize(unitFrame, size)
        if not OnlyName(unitFrame) then return size end
        return size * NamePlates.FRIENDLY_NAME
    end

    ---------------------------------------------------------------------------
    -- THE TARGET GROWN, SMOOTHLY (the player, 2026-10-03: "enemy name plates
    -- should be smaller when not targeted, larger when targeted. right now
    -- its vice versa" - "the transition from small to large in all
    -- nameplates including friendly names should be smoother"). This client
    -- takes nameplateSelectedScale as the target's whole size, not a factor
    -- on the others' (set to 1.1 with the others at 1.2, the target came out
    -- the smallest), and snaps a plate to its size at once.
    --
    -- So the target's plate is grown by the game itself - the whole plate,
    -- as the game scales it - with nameplateSelectedScale taken from the
    -- others' size up to TARGET_GROW times it over GROW_TIME as a new target
    -- is taken, eased, quick at first. (Not the plate's unit frame's own
    -- scale: the game pins that frame to fill its plate, so scaling it kept
    -- the outline and grew what is inside, the gaps at the sides too - the
    -- bar came out NARROWER, the player, 2026-10-03: "hostile nameplates are
    -- being smaller in width when targ selected".)
    --
    -- A friendly name-only plate grows more (TARGET_NAME_GROW in all): its
    -- unit frame takes the rest on, smoothly the same way - it has no bar to
    -- narrow, only its name. Which plate is the target's is asked the way the
    -- game hands plates out and compared as a frame: no unit is read, nothing
    -- of the plate measured. A plate the game gives a new unit takes its size
    -- at once.
    ---------------------------------------------------------------------------

    NamePlates.TARGET_GROW = 1.1
    NamePlates.TARGET_NAME_GROW = 1.25
    NamePlates.GROW_TIME = 0.15
    NamePlates.SELECTED_DEFAULT = 1.2   -- the game's selected size, should the client not say
    local SELECTED_CVAR, OTHERS_CVAR = "nameplateSelectedScale", "nameplateMaxScale"

    -- The game's settings, read and written with the client's own calls
    -- (see DEFAULTS, below, for why never the game's helpers).
    local function ReadCVar(name)
        local ok, value = pcall(C_CVar.GetCVar, name)
        return ok and value or nil
    end

    local function WriteCVar(name, value)
        return pcall(C_CVar.SetCVar, name, value)
    end

    local function SetScaleCVar(name, value)
        WriteCVar(name, (("%.4f"):format(value):gsub("0+$", ""):gsub("%.$", "")))
    end

    -- Every plate's size as the game has it (the defaults' step 3 sets it).
    function NamePlates.OthersScale()
        local size = tonumber(ReadCVar(OTHERS_CVAR))
        if not size or size <= 0 then size = NamePlates.SELECTED_DEFAULT end
        return size
    end

    local plateScale = setmetatable({}, { __mode = "k" })   -- unit frame -> its scale now
    local growing = setmetatable({}, { __mode = "k" })      -- unit frame -> { from, to, time }
    local selectedGrow                                      -- { time } while the target's grows

    -- A unit frame's own scale: more than 1 only for a targeted name-only
    -- plate. `target` is TargetFrame().
    local function WantedScale(unitFrame, target)
        if not (target == unitFrame and OnlyName(unitFrame)) then return 1 end
        return NamePlates.TARGET_NAME_GROW / NamePlates.TARGET_GROW
    end

    local function SetPlateScale(unitFrame, scale)
        if plateScale[unitFrame] == scale then return end
        if pcall(unitFrame.SetScale, unitFrame, scale) then plateScale[unitFrame] = scale end
    end

    local function Eased(time)
        local k = math.min(1, time / NamePlates.GROW_TIME)
        return 1 - (1 - k) * (1 - k), k >= 1
    end

    local grower = CreateFrame("Frame")
    grower:Hide()
    grower:SetScript("OnUpdate", function(self, elapsed)
        local any = false
        if selectedGrow then
            selectedGrow.time = selectedGrow.time + (elapsed or 0)
            local eased, done = Eased(selectedGrow.time)
            SetScaleCVar(SELECTED_CVAR, NamePlates.OthersScale() * (1 + (NamePlates.TARGET_GROW - 1) * eased))
            if done then selectedGrow = nil else any = true end
        end
        for unitFrame, grow in pairs(growing) do
            grow.time = grow.time + (elapsed or 0)
            local eased, done = Eased(grow.time)
            SetPlateScale(unitFrame, grow.from + (grow.to - grow.from) * eased)
            if done then growing[unitFrame] = nil else any = true end
        end
        if not any then self:Hide() end
    end)

    -- A new target: its plate grown from the others' size, smoothly.
    function NamePlates.GrowTarget()
        selectedGrow = { time = 0 }
        SetScaleCVar(SELECTED_CVAR, NamePlates.OthersScale())
        grower:Show()
    end

    -- A unit frame grown (or shrunk) to its own scale, smoothly.
    local function Grow(unitFrame, target)
        local to = WantedScale(unitFrame, target)
        local now = plateScale[unitFrame] or 1
        local going = growing[unitFrame]
        if (going and going.to == to) or (not going and now == to) then return end
        growing[unitFrame] = { from = now, to = to, time = 0 }
        grower:Show()
    end

    -- Its size at once (the game laying the plate out for a unit) - unless
    -- it is growing now.
    local function SizeNow(unitFrame)
        if growing[unitFrame] then return end
        SetPlateScale(unitFrame, WantedScale(unitFrame, TargetFrame()))
    end

    local function SizeTexts(unitFrame)
        local size = Setup().levelFontHeight
        if type(size) ~= "number" then return end
        local bar = HealthBar(unitFrame)
        local level = unitFrame.PlayerLevelDiffFrame
        local castBar = unitFrame.CastBarsContainer and unitFrame.CastBarsContainer.castBar
        if level then SetText(level.playerLevelDiffText, INSIDE_FONT, size) end
        if bar then
            SetText(bar.LeftText, INSIDE_FONT, size)
            SetText(bar.RightText, INSIDE_FONT, size)
            SetText(bar.Text, INSIDE_FONT, size)
        end
        SetText(unitFrame.name, nil, NamePlates.NameSize(unitFrame, size))
        if castBar then
            SetText(castBar.Text, nil, size)
            SetText(castBar.CastTargetNameText, nil, size)
        end
    end

    -- WHERE THE CAST BAR GOES. The game hangs it at the top of a container
    -- under the health bar, a few pixels below it (NamePlateCastingBarMixin:
    -- ApplyStyleAndAnchoring). Framed, the two borders met. So it keeps its
    -- width - the plate's, which the health bar now has too - and sits right
    -- under the health bar with both borders and CAST_GAP clear pixels
    -- between; the icon and spell-name row, which the game puts under the
    -- bar in the styles without the name inside it, moves down with it. Its
    -- height stays the game's. This client offers no classic style; a
    -- classic bar is left alone.
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

    local function PlaceCast(unitFrame, castBar)
        local setup = Setup()
        if setup.useClassicCastBar then return end
        local bar = HealthBar(unitFrame)
        local icon = castBar.Icon
        local spacer = bar and Spacer(bar, parts[bar], 2 * BORDER_PIXELS + CAST_GAP)
        local under = Spacer(castBar, castParts[castBar], BORDER_PIXELS + TEXT_GAP)
        if not icon or not spacer or not under then return end

        castBar:ClearAllPoints()
        icon:ClearAllPoints()
        castBar:SetPoint("TOPLEFT", spacer, "BOTTOMLEFT", 0, 0)
        castBar:SetPoint("TOPRIGHT", spacer, "BOTTOMRIGHT", 0, 0)
        if setup.spellNameInsideCastBar then
            icon:SetPoint("LEFT", castBar, "LEFT", 0, 0)
        else
            icon:SetPoint("TOPLEFT", under, "BOTTOMLEFT", 0, 0)
        end
    end

    local function StyleCast(unitFrame)
        local container = unitFrame.CastBarsContainer
        local castBar = container and container.castBar
        if not castBar then return end

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
        Show(castParts[castBar])
        if castBar.Background then castBar.Background:SetAlpha(0) end
        PaintCast(castBar)
        PlaceCast(unitFrame, castBar)
    end

    -- THE PARTY MARK. A party member's plate carries the game's group icon
    -- (socialqueuing-icon-group, as the Quick Join list draws it) just left of
    -- their name. Friendly players' plates show the name only (see
    -- HoldNamesOnly), and there the game stretches the name across the
    -- plate's width, centred (UpdateAnchors, IsShowOnlyName): a mark on the
    -- name's left end would sit far from the text, and how wide the text is
    -- may not be read (see LevelWidth). So on a party member's plate the name
    -- is held by its middle instead - its width is then its text's - moved
    -- right by half the mark and its gap, and the mark hangs off the name's
    -- left end: mark and name together are centred where the name was. The
    -- mark shows while the name does (the game hides it on some simplified
    -- plates, CompactUnitFrame_UpdateName, which is followed). Off the party,
    -- the name is stretched across the plate again (lowered: below).
    --
    -- Inside instances the game keeps friendly plates from addons (see PLATES
    -- AN ADDON MAY NOT HAVE), so there the party's plates carry no mark. If
    -- the client has neither icon, there is no mark rather than a missing
    -- texture.
    local MARK_ATLASES = { "socialqueuing-icon-group", "groupfinder-icon-friend" }
    local MARK_GAP = 3                  -- from the mark to the name
    local MARK_GROW = 2                 -- the mark this much taller than the text
    local marks = setmetatable({}, { __mode = "k" })       -- unit frame -> its mark
    local heldName = setmetatable({}, { __mode = "k" })    -- unit frame -> name held by its middle

    local function MarkAtlas()
        if type(C_Texture) ~= "table" or not C_Texture.GetAtlasInfo then return nil end
        for _, atlas in ipairs(MARK_ATLASES) do
            local info = C_Texture.GetAtlasInfo(atlas)
            if info then return atlas, info end
        end
    end

    -- UnitInParty is plain on this client; the player is in their own party,
    -- and has no such plate, but is ruled out all the same.
    local function InParty(unit)
        if type(unit) ~= "string" or type(UnitInParty) ~= "function" then return false end
        local inParty = UnitInParty(unit)
        if issecretvalue(inParty) or inParty ~= true then return false end
        local me = UnitIsUnit(unit, "player")
        return issecretvalue(me) or me ~= true
    end

    -- A NAMES-ONLY PLATE'S NAME, LOWERED (the player, 2026-10-03: "friendly
    -- nameplates distance from their character is too much"). The game
    -- lays a plate out from its bottom - just over the unit's head - up: the
    -- cast bar's row, the health bar's, then the name (UpdateAnchors). On a
    -- plate that shows the name only, both rows are empty, yet the name still
    -- sits over them, a bar and a cast bar too high. So there the name
    -- stands on the middle of the empty cast bar row. The player, all
    -- 2026-10-03: too far up as the game had it; too close to the head at
    -- the plate's very bottom; too far again on the health bar row's bottom
    -- (with the plates grown to the selected size) - "it should be same as
    -- game default", the game's own names over friendly NPCs. Half a cast
    -- bar row over the plate's bottom is between the last two.
    --
    -- Only names-only plates - friendly players' (HoldNamesOnly): every
    -- other plate, the hostile ones included, keeps the game's anchors. A
    -- names-only plate takes no clicks (the game clears its hit area,
    -- UpdateHitTestArea), so moving its name moves nothing clickable; the
    -- raid icon over it comes down with it. Done after each of the game's
    -- own layouts (the UpdateAnchors post-hook), which put the name back
    -- first; a plate the game reuses for anyone else is laid out by the game.
    local NAME_LIFT = 0                 -- the name's bottom above the row's middle

    local function NameOnlyAnchors(unitFrame, name, shift)
        local row = unitFrame.CastBarsContainer or unitFrame
        name:ClearAllPoints()
        if shift then
            name:SetPoint("BOTTOM", row, "CENTER", shift, NAME_LIFT)
        else
            name:SetPoint("BOTTOMLEFT", row, "LEFT", 4, NAME_LIFT)
            name:SetPoint("BOTTOMRIGHT", row, "RIGHT", -4, NAME_LIFT)
        end
    end

    local function PlaceMark(unitFrame)
        local name, container = unitFrame.name, unitFrame.HealthBarsContainer
        if not name or not container then return end
        local atlas, info = MarkAtlas()
        local mark = marks[unitFrame]
        if atlas and OnlyName(unitFrame) and InParty(unitFrame.unit) then
            if not mark then
                mark = unitFrame:CreateTexture(nil, "OVERLAY")
                marks[unitFrame] = mark
            end
            local size = Setup().levelFontHeight
            local height = (type(size) == "number" and size or 10) + MARK_GROW
            local aspect = (type(info) == "table" and type(info.width) == "number"
                and type(info.height) == "number" and info.height > 0) and info.width / info.height or 1
            local width = height * aspect
            mark:SetAtlas(atlas)
            mark:SetSize(width, height)

            local shift = (width + MARK_GAP) / 2
            NameOnlyAnchors(unitFrame, name, shift)
            heldName[unitFrame] = true
            mark:ClearAllPoints()
            mark:SetPoint("RIGHT", name, "LEFT", -MARK_GAP, 0)
            mark:SetShown(name:IsShown())
        else
            if mark then mark:Hide() end
            heldName[unitFrame] = nil
            if OnlyName(unitFrame) then NameOnlyAnchors(unitFrame, name) end
        end
    end

    -- Put the look on one plate.
    local function Apply(unitFrame)
        if not unitFrame or unitFrame:IsForbidden() then return end
        local bar = HealthBar(unitFrame)
        if not bar then return end
        local fill = bar:GetStatusBarTexture()

        Show(Parts(bar))
        fill:SetTexture(Style.FLAT_TEXTURE)
        fill:SetHorizTile(false)
        fill:SetVertTile(false)
        FadeGameArt(unitFrame, bar)
        if NameStyle("AboveHealthBar") then HealthTexts(bar) end
        PlaceBar(unitFrame)
        PlaceLevelAndName(unitFrame)
        SizeTexts(unitFrame)
        PlaceMark(unitFrame)
        StyleCast(unitFrame)
        SizeNow(unitFrame)
    end

    -- The game puts the level's number back over its box whenever it sets
    -- the level - a new unit, or the unit's level changing - without laying
    -- the plate out again; so that is followed too, for the plates here.
    local function OnLevel(unitFrame)
        if followed[unitFrame] and parts[HealthBar(unitFrame) or false] then
            PlaceLevelAndName(unitFrame)
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
    -- plate comes back as nothing, and is left alone. Only a nameplate's own
    -- unit: the game's options show a sample plate for "preview", which the
    -- call refuses with an error ("Player/pet name are not valid arguments").
    local function OnAdded(_, unit)
        if type(C_NamePlate) ~= "table" or not C_NamePlate.GetNamePlateForUnit then return end
        if issecretvalue and issecretvalue(unit) then return end
        if type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
        Take(C_NamePlate.GetNamePlateForUnit(unit))
    end

    -- FRIENDLY PLAYERS: NAMES ONLY. Inside instances the game gives friendly
    -- units forbidden plates (ForbiddenNamePlateUnitFrameTemplate), which an
    -- addon can neither get nor touch, so the party's plates there kept the
    -- game's look. So friendly players' plates are held to the name alone -
    -- the game's own setting for it,
    -- nameplateShowOnlyNameForFriendlyPlayerUnits (Options > Nameplates >
    -- Friendly Player Nameplates > show only name), which the game applies to
    -- forbidden plates too; the name is in the player's font already
    -- (Core\Fonts.lua). It applies everywhere, not only in instances: the
    -- game has no instance-only form of it.
    --
    -- Held: set at every login and loading screen, and again whenever
    -- anything - the game's options included - turns it off. Never in
    -- combat, where the game may refuse the change; then once combat ends.
    -- The game reacts to the change from its own CVAR_UPDATE event, so none
    -- of its plate code runs from here.
    local NAMES_ONLY_CVAR = "nameplateShowOnlyNameForFriendlyPlayerUnits"
    local pending = false

    function NamePlates.HoldNamesOnly()
        if InCombatLockdown() then
            pending = true
            return
        end
        pending = false
        if ReadCVar(NAMES_ONLY_CVAR) ~= "1" then WriteCVar(NAMES_ONLY_CVAR, "1") end
    end

    ---------------------------------------------------------------------------
    -- DEFAULTS (the player, 2026-10-03: "when our addon is loaded the default
    -- nameplate style should be Large and Health Percentage should be active
    -- by default"; and "make friendly nameplates class colored"): the game's
    -- own nameplate options, set ONCE per character - Options > Nameplates >
    -- Style: Large (Enum.NamePlateStyle.Modern on this client:
    -- Camelot\NameplatesOverrides.lua), Nameplate Information: Health
    -- Percentage on (the first bit of nameplateInfoDisplay, whatever else is
    -- ticked kept), and friendly players in class colours - the bar
    -- (nameplateShowFriendlyClassColor) and the name, which is all a friendly
    -- player's plate shows (nameplateUseClassColorForFriendlyPlayerUnitNames,
    -- Blizzard_NamePlateUnitFrame.lua UpdateNameClassColor).
    --
    -- Changed in the options afterwards, they stay changed (the player,
    -- 2026-10-03: "shouldn't reset again to our defaults on reload"); Reset
    -- everything puts the count back and so sets them again, at once. The count
    -- is only trusted once the saved file is read in: this client can hand
    -- the file over after the world is up, and until then the flag reads as
    -- the default "not yet" - which reset the player's choices on every
    -- reload. So nothing is set until the file is in, or two seconds after
    -- the world is up for a character that has no file yet.
    --
    -- Written with the client's own SetCVar - never the game's
    -- CVarCallbackRegistry helpers, whose cache the addon's call would taint.
    -- Out of combat.
    ---------------------------------------------------------------------------

    local STYLE_CVAR, INFO_CVAR = "nameplateStyle", "nameplateInfoDisplay"
    local CLASS_COLOUR_CVARS = {
        "nameplateShowFriendlyClassColor",
        "nameplateUseClassColorForFriendlyPlayerUnitNames",
    }
    local DISTANCE_CVARS = { "nameplateMinScale", "nameplateMaxScale" }
    NamePlates.SELECTED_GROW = 1.1
    local waited = false     -- two seconds since the world came up
    local running = false    -- the steps being set now
    local CVAR_DATA_MARK = 0x40          -- every data byte: 0b01xxxxxx (CvarUtil.lua)

    -- A bit field CVar's value with bit `index` (an enum value, from 1) on:
    -- its version byte, then six bits a byte (CVarCallbackRegistry's format).
    function NamePlates.WithBit(value, index)
        if type(value) ~= "string" or #value < 1 then return nil end
        local at = 2 + math.floor((index - 1) / 6)
        local bitValue = 2 ^ ((index - 1) % 6)
        local bytes = { value:byte(1, -1) }
        for i = #bytes + 1, at do bytes[i] = CVAR_DATA_MARK end
        local byte = bytes[at]
        if math.floor(byte / bitValue) % 2 == 0 then byte = byte + bitValue end
        bytes[at] = byte
        return string.char((table.unpack or unpack)(bytes))
    end

    -- The defaults, in the order they were added. A character that had the
    -- first ones before a later one came still gets the later one, once
    -- (friendly class colours stayed off on the player's character for
    -- exactly that: its single "done" flag was already set).
    local STEPS = {
        -- 1: Large, Health Percentage.
        function()
            local large = type(Enum) == "table" and Enum.NamePlateStyle and Enum.NamePlateStyle.Modern
            if large and ReadCVar(STYLE_CVAR) ~= nil then WriteCVar(STYLE_CVAR, tostring(large)) end
            local percent = type(Enum) == "table" and Enum.NamePlateInfoDisplay
                and Enum.NamePlateInfoDisplay.CurrentHealthPercent
            local info = ReadCVar(INFO_CVAR)
            if percent and info ~= nil then
                if #info < 1 and type(GetCVarDefault) == "function" then info = GetCVarDefault(INFO_CVAR) end
                local wanted = NamePlates.WithBit(info, percent)
                if wanted and wanted ~= info then WriteCVar(INFO_CVAR, wanted) end
            end
        end,
        -- 2: friendly players in class colours.
        function()
            for _, name in ipairs(CLASS_COLOUR_CVARS) do
                local value = ReadCVar(name)
                if value ~= nil and value ~= "1" then WriteCVar(name, "1") end
            end
        end,
        -- 3: the plates not targeted the size the targeted one was, at any
        -- distance, and the targeted one a little larger still (the
        -- player, 2026-10-03: "the non-selected plates should be the size of
        -- selected frames, and selected frames slightly larger"). The game's
        -- own scales: nameplateMinScale and nameplateMaxScale (the plates
        -- from far to near) both the game's default selected scale, and
        -- nameplateSelectedScale - on top of those - SELECTED_GROW.
        function()
            local selected = ReadCVar(SELECTED_CVAR)
            if selected == nil then return end
            -- (The game's own default selected size - not the value now,
            -- which after a first run is SELECTED_GROW: Reset everything
            -- would shrink the plates each time.)
            local size = type(GetCVarDefault) == "function" and tonumber(GetCVarDefault(SELECTED_CVAR))
            if not size or size <= 0 then size = NamePlates.SELECTED_DEFAULT end
            for _, name in ipairs(DISTANCE_CVARS) do
                if ReadCVar(name) ~= nil then WriteCVar(name, tostring(size)) end
            end
            WriteCVar(SELECTED_CVAR, tostring(NamePlates.SELECTED_GROW))
        end,
        -- 4: the target TARGET_GROW times the others' size - this client
        -- takes the selected scale as the target's whole size, so step 3's
        -- 1.1 made it the smallest plate (the player, 2026-10-03: "right
        -- now its vice versa"). Grown to it smoothly as each new target is
        -- taken (THE TARGET GROWN).
        function()
            if ReadCVar(SELECTED_CVAR) == nil then return end
            local size = type(GetCVarDefault) == "function" and tonumber(GetCVarDefault(SELECTED_CVAR))
            if not size or size <= 0 then size = NamePlates.SELECTED_DEFAULT end
            WriteCVar(SELECTED_CVAR, tostring(size * NamePlates.TARGET_GROW))
        end,
    }
    NamePlates.DEFAULT_STEPS = #STEPS

    local function StepsDone(db)
        local done = db.nameplateDefaults
        if done == true then return 1 end
        return tonumber(done) or 0
    end

    function NamePlates.SetDefaults()
        local frames = DogsForeverUI.Frames
        local db = frames and frames.db
        if type(db) ~= "table" then return true end
        local done = StepsDone(db)
        if done >= #STEPS then return true end
        local settled = DogsForeverUI.SettingsSettled
        if not waited and not (settled and settled()) then return false end
        if InCombatLockdown() or running then return false end
        -- (A setting written makes the game lay its plates out again, which
        -- comes back here: each step counted as done the moment it is, and
        -- nothing begun again while one runs - step 3 read its own
        -- selected scale back the second time.)
        running = true
        for index = done + 1, #STEPS do
            local ok, err = pcall(STEPS[index])
            if not ok and geterrorhandler then geterrorhandler()(err) end
            db.nameplateDefaults = index
        end
        running = false
        return true
    end

    -- Someone joined or left the party: every plate the addon has is marked
    -- again (a plate with no unit just loses its mark).
    local function MarkAll()
        for unitFrame in pairs(followed) do PlaceMark(unitFrame) end
    end

    -- The game showed or hid a plate's name; the mark goes with it. Only
    -- that: the game runs this on every health change of every compact
    -- frame (CompactUnitFrame_UpdateHealth), and it never moves the name -
    -- the plate's layout (UpdateAnchors -> Apply), a new unit and the roster
    -- (MarkAll) are where the mark is placed.
    local function OnName(frame)
        local mark = marks[frame]
        if mark and heldName[frame] then mark:SetShown(frame.name:IsShown()) end
    end

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:RegisterEvent("CVAR_UPDATE")
    watcher:RegisterEvent("GROUP_ROSTER_UPDATE")
    watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
    watcher:SetScript("OnEvent", function(_, event, name)
        if event == "GROUP_ROSTER_UPDATE" then
            MarkAll()
        elseif event == "PLAYER_TARGET_CHANGED" then
            -- The new target's plate grown, the old one's back (THE TARGET GROWN).
            NamePlates.GrowTarget()
            local target = TargetFrame()
            for unitFrame in pairs(followed) do
                if parts[HealthBar(unitFrame) or false] then Grow(unitFrame, target) end
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pending then NamePlates.HoldNamesOnly() end
            NamePlates.SetDefaults()
        elseif event == "CVAR_UPDATE" then
            if name == NAMES_ONLY_CVAR then NamePlates.HoldNamesOnly() end
        else
            NamePlates.HoldNamesOnly()
            NamePlates.SetDefaults()
            if not waited then
                -- Two seconds on, the file is in if there is one (counted
                -- here rather than on a timer, then let go of).
                local elapsed = 0
                watcher:SetScript("OnUpdate", function(self, step)
                    elapsed = elapsed + (step or 0)
                    if elapsed < 2 then return end
                    self:SetScript("OnUpdate", nil)
                    waited = true
                    NamePlates.SetDefaults()
                end)
            end
        end
    end)

    -- Every plate on screen, after a setting of the addon's or the game's -
    -- and after the saved file is read in, or a reset (the defaults then).
    function NamePlates.Refresh()
        NamePlates.HoldNamesOnly()
        NamePlates.SetDefaults()
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
        if type(CompactUnitFrame_UpdateName) == "function" then
            hooksecurefunc("CompactUnitFrame_UpdateName", OnName)
        end
        NamePlates.Refresh()
    end
end
