-- The game's nameplates in the addon's look (DogsForeverUI.Frames.NamePlates): flat
-- bars, the level inside, a party mark, the target grown, the game's options set once.
-- Post-hooks only; nothing written on game tables; plate regions never measured.

local NamePlates = {}
DogsForeverUI.Frames.NamePlates = NamePlates

do -- private scope
    local Style = DogsForeverUI.Style
    local Core = DogsForeverUI

    local WEAK = { __mode = "k" }

    -- Plates are pooled by the game; these go with them.
    local parts = setmetatable({}, WEAK)      -- health bar -> the addon's pieces
    local followed = setmetatable({}, WEAK)   -- unit frame -> its UpdateAnchors hooked
    local driverFollowed = false

    local function HealthBar(unitFrame)
        return unitFrame.HealthBarsContainer.healthBar
    end

    local function NameStyle(key)
        return NamePlateSetupOptions.unitNameAnchorStyle == NamePlateConstants.NAME_ANCHOR_STYLES[key]
    end

    -- Background, sheen, shade and a thin border off the plate's scale (whole pixels).
    local function MakeParts(bar)
        local made = { background = bar:CreateTexture(nil, "BACKGROUND", nil, -8) }
        made.background:SetAllPoints(bar)
        Style.SetBackground(made.background)
        made.sheen, made.shade = Style.MakeSheen(bar)
        made.border = Style.AddBorder(bar, nil, true, 1)
        return made
    end

    local function Show(made)
        made.background:Show()
        made.sheen:Show()
        made.shade:Show()
        made.border:Show()
    end

    -- The same texture object: other plate parts are anchored to it.
    local function FlatFill(fill)
        fill:SetTexture(Style.FLAT_TEXTURE)
        fill:SetHorizTile(false)
        fill:SetVertTile(false)
    end

    -- The game never sets these alphas, so fading them sticks.
    local function FadeGameArt(unitFrame, bar)
        local level = unitFrame.PlayerLevelDiffFrame
        Core.Fade(bar.bgTexture)
        Core.Fade(bar.selectedBorder)          -- a second border round ours
        Core.Fade(level.playerLevelDiffIcon)   -- the level's box: plain text instead
        Core.Fade(level.selectedBorder)
    end

    -- Name above the bar: the health numbers move inside its right end, where
    -- the game puts them for the inside style, so a long name never runs into them.
    local function HealthTexts(bar)
        local left, right, text = bar.LeftText, bar.RightText, bar.Text
        left:ClearAllPoints()
        right:ClearAllPoints()
        text:ClearAllPoints()
        left:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        right:SetPoint("RIGHT", left, "LEFT", -2, 0)
        text:SetPoint("RIGHT", right, "LEFT", 2, 0)
    end

    ---------------------------------------------------------------------------
    -- Cast bar
    ---------------------------------------------------------------------------

    local CAST_KIND = {
        standard = "casting", empowered = "casting",
        applyingcrafting = "casting", applyingtalents = "casting",
        channel = "channel", uninterruptable = "uninterruptible",
        interrupted = "failed",
    }
    local castParts = setmetatable({}, WEAK)
    local castFailed = setmetatable({}, WEAK)   -- cast bar -> interrupted
    local castLocked = setmetatable({}, WEAK)   -- cast bar -> can't be interrupted (may be secret)

    local function Colour(key)
        local c = Style.CAST_COLOR[key]
        return c[1], c[2], c[3], 1
    end

    -- barType is usually secret: then the kind comes from the bar's own flags,
    -- the interrupt animation, and the secret "locked" handed untested to
    -- SetVertexColorFromBoolean. A bar that never cast has no fill yet.
    local function PaintCast(castBar)
        local fill = castBar:GetStatusBarTexture()
        if not fill then return end
        FlatFill(fill)

        local kind = castBar.barType
        if not issecretvalue(kind) then
            castBar:SetStatusBarColor(Colour(CAST_KIND[kind] or "casting"))
            return
        end

        local key = castFailed[castBar] and "failed" or castBar.channeling and "channel" or "casting"
        castBar:SetStatusBarColor(Colour(key))
        if key == "failed" then return end
        local locked = castLocked[castBar]
        if issecretvalue(locked) then
            fill:SetVertexColorFromBoolean(locked, CreateColor(Colour("uninterruptible")), CreateColor(Colour(key)))
        elseif locked == true then
            castBar:SetStatusBarColor(Colour("uninterruptible"))
        end
    end

    -- The game sets the cast's flags, then shows or hides the icon.
    local function OnCastIcon(castBar)
        castFailed[castBar] = nil
        local unit, locked = castBar.unit, nil
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

    ---------------------------------------------------------------------------
    -- Level, name, bar width
    ---------------------------------------------------------------------------

    -- The level is plain text at the bar's left; the bar takes the level box's
    -- room (the box's width from the options, never measured). The box itself
    -- stays put, so the auras and the name placed off it keep their places.
    local LEVEL_X = 4           -- the level's inset from the bar's left
    local LEVEL_GAP = 3         -- from the level to the name
    local SKULL_SCALE = 1.6     -- the skull art has empty margins

    local function PlaceBar(unitFrame)
        if NamePlateSetupOptions.useClassicHealthBar then return end
        local bar, container = HealthBar(unitFrame), unitFrame.HealthBarsContainer
        local widen = unitFrame.PlayerLevelDiffFrame:ShouldDisplay(unitFrame.unit)
            and NamePlateSetupOptions.playerLevelDiffWidth or 0
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", widen, 0)
    end

    local function PlaceLevel(unitFrame, ours)
        local level, setup = unitFrame.PlayerLevelDiffFrame, NamePlateSetupOptions
        local text, skull, icon = level.playerLevelDiffText, level.highLevelTexture, level.playerLevelDiffIcon
        text:ClearAllPoints()
        skull:ClearAllPoints()
        if not ours then
            text:SetPoint("CENTER", icon, "CENTER", 0, 0)
            skull:SetSize(setup.playerLevelDiffHeight, setup.playerLevelDiffHeight)
            skull:SetPoint("CENTER", icon, "CENTER", 0, 0)
            return
        end
        local bar = HealthBar(unitFrame)
        -- Never taller than the bar (the thin Cast Focus bars).
        local size = math.min(setup.levelFontHeight * SKULL_SCALE, setup.healthBarHeight)
        skull:SetSize(size, size)
        -- Off the pixel grid it moves with the bar instead of jumping a pixel as the plate scales.
        skull:SetSnapToPixelGrid(false)
        skull:SetTexelSnappingBias(0)
        text:SetPoint("LEFT", bar, "LEFT", LEVEL_X, 0)
        skull:SetPoint("LEFT", bar, "LEFT", LEVEL_X, 0)
    end

    -- The level's number, or the skull for a unit too high to tell.
    local function ShownLevel(unitFrame)
        local level = unitFrame.PlayerLevelDiffFrame
        if not level:IsShown() then return nil end
        if level.highLevelTexture:IsShown() then return level.highLevelTexture end
        return level.playerLevelDiffText
    end

    -- Name inside the bar: it starts after the level, ends short of the numbers.
    local function PlaceName(unitFrame)
        if not NameStyle("InsideHealthBar") or unitFrame:IsShowOnlyName() then return end
        local name, level = unitFrame.name, ShownLevel(unitFrame)
        name:ClearAllPoints()
        if level then
            name:SetPoint("LEFT", level, "RIGHT", LEVEL_GAP, 0)
        else
            name:SetPoint("LEFT", unitFrame.HealthBarsContainer, "LEFT", 4, 0)
        end
        name:SetPoint("RIGHT", HealthBar(unitFrame).Text, "LEFT", -2, 0)
    end

    local function PlaceLevelAndName(unitFrame)
        PlaceLevel(unitFrame, not unitFrame:IsShowOnlyName())
        PlaceName(unitFrame)
    end

    ---------------------------------------------------------------------------
    -- Text size: every string the level's size, the bar's outlined, so they share
    -- one middle line. Only the strings are set, never the game's font objects.
    ---------------------------------------------------------------------------

    NamePlates.FRIENDLY_NAME = 0.85     -- a names-only plate's name, of the text size

    local function SizeText(label, size, font)
        if font then label:SetFontObject(font) end
        label:SetTextHeight(size)
    end

    local function SizeTexts(unitFrame)
        local size, outlined = NamePlateSetupOptions.levelFontHeight, SystemFont_NamePlate_Outlined
        local bar, castBar = HealthBar(unitFrame), unitFrame.CastBarsContainer.castBar
        SizeText(unitFrame.PlayerLevelDiffFrame.playerLevelDiffText, size, outlined)
        SizeText(bar.LeftText, size, outlined)
        SizeText(bar.RightText, size, outlined)
        SizeText(bar.Text, size, outlined)
        SizeText(unitFrame.name, unitFrame:IsShowOnlyName() and size * NamePlates.FRIENDLY_NAME or size)
        SizeText(castBar.Text, size)
        SizeText(castBar.CastTargetNameText, size)
    end

    ---------------------------------------------------------------------------
    -- The target grown, smoothly: nameplateSelectedScale (the target's whole size)
    -- eased from the others' size to TARGET_GROW times it. A names-only target grows
    -- further on its unit frame's scale (scaling a full plate narrowed its bar).
    ---------------------------------------------------------------------------

    NamePlates.TARGET_GROW = 1.1
    NamePlates.TARGET_NAME_GROW = 1.25
    NamePlates.GROW_TIME = 0.15
    local SELECTED_DEFAULT = 1.2        -- the game's selected size, should the client not say
    local SELECTED_CVAR, OTHERS_CVAR = "nameplateSelectedScale", "nameplateMaxScale"

    -- Never the game's CVarCallbackRegistry helpers: our call would taint their cache.
    local function ReadCVar(name)
        return C_CVar.GetCVar(name)
    end

    local function WriteCVar(name, value)
        return pcall(C_CVar.SetCVar, name, value)
    end

    local function SetScaleCVar(name, value)
        WriteCVar(name, (("%.4f"):format(value):gsub("0+$", ""):gsub("%.$", "")))
    end

    local function OthersScale()
        local size = tonumber(ReadCVar(OTHERS_CVAR))
        return (size and size > 0) and size or SELECTED_DEFAULT
    end

    -- The target's plate's unit frame, compared as a frame: no unit is read.
    local function TargetFrame()
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
        return ok and type(plate) == "table" and plate.UnitFrame or nil
    end

    local plateScale = setmetatable({}, WEAK)   -- unit frame -> its scale now
    local growing = setmetatable({}, WEAK)      -- unit frame -> { from, to, time }
    local selectedTime          -- seconds into the target's growth, while it grows

    local function WantedScale(unitFrame, target)
        if target == unitFrame and unitFrame:IsShowOnlyName() then
            return NamePlates.TARGET_NAME_GROW / NamePlates.TARGET_GROW
        end
        return 1
    end

    local function SetPlateScale(unitFrame, scale)
        if plateScale[unitFrame] == scale then return end
        if pcall(unitFrame.SetScale, unitFrame, scale) then plateScale[unitFrame] = scale end
    end

    -- Eased out: quick at first.
    local function Eased(time)
        local k = math.min(1, time / NamePlates.GROW_TIME)
        return 1 - (1 - k) * (1 - k), k >= 1
    end

    local WakeGrower = Core.Waker(function(elapsed)
        local any = false
        if selectedTime then
            selectedTime = selectedTime + elapsed
            local eased, done = Eased(selectedTime)
            SetScaleCVar(SELECTED_CVAR, OthersScale() * (1 + (NamePlates.TARGET_GROW - 1) * eased))
            if done then selectedTime = nil else any = true end
        end
        for unitFrame, grow in pairs(growing) do
            grow.time = grow.time + elapsed
            local eased, done = Eased(grow.time)
            SetPlateScale(unitFrame, grow.from + (grow.to - grow.from) * eased)
            if done then growing[unitFrame] = nil else any = true end
        end
        return any
    end)

    local function GrowTarget()
        selectedTime = 0
        SetScaleCVar(SELECTED_CVAR, OthersScale())
        WakeGrower()
    end

    local function Grow(unitFrame, target)
        local to = WantedScale(unitFrame, target)
        local now = plateScale[unitFrame] or 1
        local going = growing[unitFrame]
        if (going and going.to == to) or (not going and now == to) then return end
        growing[unitFrame] = { from = now, to = to, time = 0 }
        WakeGrower()
    end

    -- A plate laid out for a unit takes its size at once, unless growing.
    local function SizeNow(unitFrame)
        if growing[unitFrame] then return end
        SetPlateScale(unitFrame, WantedScale(unitFrame, TargetFrame()))
    end

    ---------------------------------------------------------------------------
    -- The cast bar right under the health bar, the icon and spell name under it.
    -- The gaps are real pixels: spacers of our own off the plate's scale.
    ---------------------------------------------------------------------------

    local CAST_GAP = 3          -- clear pixels between the two borders
    local BORDER_PIXELS = 3     -- each thin border's three lines
    local TEXT_GAP = 2          -- clear pixels from the border to the spell name

    local function Spacer(owner, made, pixels)
        local spacer = made.spacer
        if not spacer then
            spacer = CreateFrame("Frame", nil, owner)
            spacer:SetIgnoreParentScale(true)
            spacer:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, 0)
            spacer:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, 0)
            made.spacer = spacer
        end
        spacer:SetHeight(pixels * Style.PixelSize(spacer))
        return spacer
    end

    local function PlaceCast(unitFrame, castBar)
        if NamePlateSetupOptions.useClassicCastBar then return end
        local bar, icon = HealthBar(unitFrame), castBar.Icon
        local spacer = Spacer(bar, parts[bar], 2 * BORDER_PIXELS + CAST_GAP)
        local under = Spacer(castBar, castParts[castBar], BORDER_PIXELS + TEXT_GAP)
        castBar:ClearAllPoints()
        icon:ClearAllPoints()
        castBar:SetPoint("TOPLEFT", spacer, "BOTTOMLEFT", 0, 0)
        castBar:SetPoint("TOPRIGHT", spacer, "BOTTOMRIGHT", 0, 0)
        if NamePlateSetupOptions.spellNameInsideCastBar then
            icon:SetPoint("LEFT", castBar, "LEFT", 0, 0)
        else
            icon:SetPoint("TOPLEFT", under, "BOTTOMLEFT", 0, 0)
        end
    end

    -- The game puts its fill art back on every change of kind: followed once per cast bar.
    local function StyleCast(unitFrame)
        local castBar = unitFrame.CastBarsContainer.castBar
        if not castParts[castBar] then
            castParts[castBar] = MakeParts(castBar)
            hooksecurefunc(castBar, "UpdateBarFillTexture", PaintCast)
            hooksecurefunc(castBar, "UpdateIconShown", OnCastIcon)
            hooksecurefunc(castBar, "PlayInterruptAnims", OnCastInterrupted)
        end
        Show(castParts[castBar])
        castBar.Background:SetAlpha(0)
        PaintCast(castBar)
        PlaceCast(unitFrame, castBar)
    end

    ---------------------------------------------------------------------------
    -- Names-only plates: the name on the middle of the empty cast bar row. A party
    -- member's name and the group icon left of it are centred together (the
    -- text's width can't be measured).
    ---------------------------------------------------------------------------

    local MARK_ATLASES = { "socialqueuing-icon-group", "groupfinder-icon-friend" }
    local MARK_GAP = 3          -- from the mark to the name
    local MARK_GROW = 2         -- the mark this much taller than the text
    local NAME_LIFT = 0         -- the name's bottom above the row's middle
    local marks = setmetatable({}, WEAK)      -- unit frame -> its mark
    local heldName = setmetatable({}, WEAK)   -- unit frame -> name held by its middle

    local function MarkAtlas()
        for _, atlas in ipairs(MARK_ATLASES) do
            local info = C_Texture.GetAtlasInfo(atlas)
            if info then return atlas, info end
        end
    end

    local function InParty(unit)
        if not unit then return false end
        local inParty = UnitInParty(unit)
        if issecretvalue(inParty) or inParty ~= true then return false end
        local me = UnitIsUnit(unit, "player")
        return issecretvalue(me) or me ~= true
    end

    local function NameOnlyAnchors(unitFrame, name, shift)
        local row = unitFrame.CastBarsContainer
        name:ClearAllPoints()
        if shift then
            name:SetPoint("BOTTOM", row, "CENTER", shift, NAME_LIFT)
        else
            name:SetPoint("BOTTOMLEFT", row, "LEFT", 4, NAME_LIFT)
            name:SetPoint("BOTTOMRIGHT", row, "RIGHT", -4, NAME_LIFT)
        end
    end

    local function PlaceMark(unitFrame)
        local name, mark = unitFrame.name, marks[unitFrame]
        local atlas, info = MarkAtlas()
        if not (atlas and unitFrame:IsShowOnlyName() and InParty(unitFrame.unit)) then
            if mark then mark:Hide() end
            heldName[unitFrame] = nil
            if unitFrame:IsShowOnlyName() then NameOnlyAnchors(unitFrame, name) end
            return
        end
        if not mark then
            mark = unitFrame:CreateTexture(nil, "OVERLAY")
            marks[unitFrame] = mark
        end
        local height = NamePlateSetupOptions.levelFontHeight + MARK_GROW
        local width = height * info.width / info.height
        mark:SetAtlas(atlas)
        mark:SetSize(width, height)
        NameOnlyAnchors(unitFrame, name, (width + MARK_GAP) / 2)
        heldName[unitFrame] = true
        mark:ClearAllPoints()
        mark:SetPoint("RIGHT", name, "LEFT", -MARK_GAP, 0)
        mark:SetShown(name:IsShown())
    end

    ---------------------------------------------------------------------------
    -- Plates
    ---------------------------------------------------------------------------

    local function Apply(unitFrame)
        local bar = HealthBar(unitFrame)
        parts[bar] = parts[bar] or MakeParts(bar)
        Show(parts[bar])
        FlatFill(bar:GetStatusBarTexture())
        FadeGameArt(unitFrame, bar)
        if NameStyle("AboveHealthBar") then HealthTexts(bar) end
        PlaceBar(unitFrame)
        PlaceLevelAndName(unitFrame)
        SizeTexts(unitFrame)
        PlaceMark(unitFrame)
        StyleCast(unitFrame)
        SizeNow(unitFrame)
    end

    local function Take(plate)
        local unitFrame = plate and plate.UnitFrame
        if not unitFrame or unitFrame:IsForbidden() then return end
        if not followed[unitFrame] then
            followed[unitFrame] = true
            hooksecurefunc(unitFrame, "UpdateAnchors", Apply)
        end
        Apply(unitFrame)
    end

    -- Only a nameplate token: the options' sample plate ("preview") is refused with an error.
    local function OnAdded(_, unit)
        if issecretvalue(unit) or type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
        Take(C_NamePlate.GetNamePlateForUnit(unit))
    end

    -- The game puts the level back over its box without a new layout.
    local function OnLevel(unitFrame)
        if followed[unitFrame] then PlaceLevelAndName(unitFrame) end
    end

    -- Runs on every health change of every compact frame: the mark only follows the name's shown state.
    local function OnName(frame)
        local mark = marks[frame]
        if mark and heldName[frame] then mark:SetShown(frame.name:IsShown()) end
    end

    ---------------------------------------------------------------------------
    -- Friendly players: names only (the game's setting, so instance plates too).
    -- Set again whenever anything turns it off, never in combat.
    ---------------------------------------------------------------------------

    local NAMES_ONLY_CVAR = "nameplateShowOnlyNameForFriendlyPlayerUnits"
    local pending = false

    local function HoldNamesOnly()
        pending = InCombatLockdown()
        if pending then return end
        if ReadCVar(NAMES_ONLY_CVAR) ~= "1" then WriteCVar(NAMES_ONLY_CVAR, "1") end
    end

    ---------------------------------------------------------------------------
    -- The game's nameplate options, set ONCE per character, step by step (a later
    -- step still reaches a character that had the early ones); Reset everything
    -- sets them again. Not before the saved file is in, or two seconds without one.
    ---------------------------------------------------------------------------

    local STYLE_CVAR, INFO_CVAR = "nameplateStyle", "nameplateInfoDisplay"
    local CLASS_COLOUR_CVARS = { "nameplateShowFriendlyClassColor", "nameplateUseClassColorForFriendlyPlayerUnitNames" }
    local DISTANCE_CVARS = { "nameplateMinScale", "nameplateMaxScale" }
    local CVAR_DATA_MARK = 0x40     -- every data byte: 0b01xxxxxx (CvarUtil.lua)
    local waited = false            -- two seconds since the world came up
    local running = false           -- a write lays the plates out, which comes back here

    -- A bit field CVar's value with bit `index` (from 1) on: a version byte, then six bits a byte.
    function NamePlates.WithBit(value, index)
        if (value or "") == "" then return nil end
        local at = 2 + math.floor((index - 1) / 6)
        local bitValue = 2 ^ ((index - 1) % 6)
        value = value .. string.rep(string.char(CVAR_DATA_MARK), at - #value)
        local byte = value:byte(at)
        if math.floor(byte / bitValue) % 2 == 1 then return value end
        return value:sub(1, at - 1) .. string.char(byte + bitValue) .. value:sub(at + 1)
    end

    -- The game's default, not the value now: a reset must not compound it.
    local function GameSelectedScale()
        local size = tonumber((Core.Try(C_CVar.GetCVarDefault, SELECTED_CVAR)))
        return (size and size > 0) and size or SELECTED_DEFAULT
    end

    local STEPS = {
        function() -- Large, Health Percentage (whatever else is ticked kept)
            local large = Core.EnumValue("NamePlateStyle", "Modern")
            if large and ReadCVar(STYLE_CVAR) ~= nil then WriteCVar(STYLE_CVAR, tostring(large)) end
            local percent = Core.EnumValue("NamePlateInfoDisplay", "CurrentHealthPercent")
            local info = ReadCVar(INFO_CVAR)
            if not percent or info == nil then return end
            if info == "" then info = Core.Try(C_CVar.GetCVarDefault, INFO_CVAR) end
            local wanted = NamePlates.WithBit(info, percent)
            if wanted and wanted ~= info then WriteCVar(INFO_CVAR, wanted) end
        end,
        function() -- friendly players in class colours: the bar and the name
            for _, name in ipairs(CLASS_COLOUR_CVARS) do
                local value = ReadCVar(name)
                if value ~= nil and value ~= "1" then WriteCVar(name, "1") end
            end
        end,
        function() -- plates near and far the game's selected size
            if ReadCVar(SELECTED_CVAR) == nil then return end
            local size = tostring(GameSelectedScale())
            for _, name in ipairs(DISTANCE_CVARS) do
                if ReadCVar(name) ~= nil then WriteCVar(name, size) end
            end
        end,
        function() -- the target larger still
            if ReadCVar(SELECTED_CVAR) == nil then return end
            WriteCVar(SELECTED_CVAR, tostring(GameSelectedScale() * NamePlates.TARGET_GROW))
        end,
    }
    NamePlates.DEFAULT_STEPS = #STEPS

    function NamePlates.SetDefaults()
        local db = Core.Frames.db
        if not db then return true end
        local done = db.nameplateDefaults == true and 1 or tonumber(db.nameplateDefaults) or 0
        if done >= #STEPS then return true end
        if not (waited or Core.SettingsSettled()) or InCombatLockdown() or running then return false end
        running = true
        for index = done + 1, #STEPS do
            Core.Safely(STEPS[index])
            db.nameplateDefaults = index
        end
        running = false
        return true
    end

    local since = 0
    local WakeWait = Core.Waker(function(elapsed)
        since = since + elapsed
        if since < 2 then return true end
        waited = true
        NamePlates.SetDefaults()
        return false
    end)

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:RegisterEvent("CVAR_UPDATE")
    watcher:RegisterEvent("GROUP_ROSTER_UPDATE")
    watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
    watcher:SetScript("OnEvent", function(_, event, name)
        if event == "GROUP_ROSTER_UPDATE" then
            for unitFrame in pairs(followed) do PlaceMark(unitFrame) end
        elseif event == "PLAYER_TARGET_CHANGED" then
            GrowTarget()
            local target = TargetFrame()
            for unitFrame in pairs(followed) do Grow(unitFrame, target) end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pending then HoldNamesOnly() end
            NamePlates.SetDefaults()
        elseif event == "CVAR_UPDATE" then
            if name == NAMES_ONLY_CVAR then HoldNamesOnly() end
        else
            HoldNamesOnly()
            NamePlates.SetDefaults()
            if not waited then
                since = 0
                WakeWait()
            end
        end
    end)

    -- Every plate on screen, after a setting changed, the saved file came in, or a reset.
    function NamePlates.Refresh()
        HoldNamesOnly()
        NamePlates.SetDefaults()
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do Take(plate) end
    end

    function NamePlates.Init()
        if driverFollowed then return end
        driverFollowed = true
        hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", OnAdded)
        hooksecurefunc(NamePlateDriverFrame, "UpdateNamePlateOptions", NamePlates.Refresh)
        hooksecurefunc("CompactUnitFrame_UpdatePlayerLevelDiff", OnLevel)
        hooksecurefunc("CompactUnitFrame_UpdateName", OnName)
    end
end
