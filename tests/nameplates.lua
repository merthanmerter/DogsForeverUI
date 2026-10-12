-- The game's nameplates in the addon's look: the health bar only, put back
-- after the game's own code puts its art back, never on a plate the game keeps
-- from addons, and with nothing written into the game's tables.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

local GAME_BAR, GAME_BG = "UI-HUD-CoolDownManager-Bar", "UI-HUD-CoolDownManager-Bar-BG"
local FLAT = "Interface\\Buttons\\WHITE8X8"

local function Near(colour, want)
    if type(colour) ~= "table" then return false end
    for i = 1, 3 do
        if math.abs((colour[i] or -1) - want[i]) > 0.005 then return false end
    end
    return true
end

-- A nameplate as the game builds one (Blizzard_NamePlates): a unit frame with
-- its health bar in HealthBarsContainer, the bar's shadowed background in
-- bgTexture, and UpdateAnchors putting the game's art back on both.
local plates = {}         -- unit -> the plate the game has for it
local anchorsRun = {}     -- unit frame -> how often UpdateAnchors ran
local onlyName = {}       -- unit frame -> shows the name only (a friendly player)
local hiddenName = {}     -- unit frame -> the game hides its name (simplified)
local party = {}          -- unit -> in the player's party

local function NewPlate(unit, forbidden)
    local unitFrame = CreateFrame("Button")
    local container = CreateFrame("Frame", nil, unitFrame)
    local bar = CreateFrame("StatusBar", nil, container)
    bar:GetStatusBarTexture():SetAtlas(GAME_BAR)
    bar.bgTexture = bar:CreateTexture(nil, "BACKGROUND")
    bar.selectedBorder = bar:CreateTexture(nil, "OVERLAY")    -- the target's ring
    bar.LeftText = bar:CreateFontString(nil, "OVERLAY")        -- the health numbers
    bar.RightText = bar:CreateFontString(nil, "OVERLAY")
    bar.Text = bar:CreateFontString(nil, "OVERLAY")
    container.healthBar = bar
    unitFrame.HealthBarsContainer = container
    -- Camelot's level box to the bar's right: the box, its ring, the number.
    -- Hung off the bars' container's right end, which the game ends the
    -- box's width short of the plate's (UpdateAnchors).
    local level = CreateFrame("Frame", nil, unitFrame)
    level:SetSize(20, 12)
    level:SetPoint("LEFT", container, "RIGHT", 0, 0)
    level.playerLevelDiffIcon = level:CreateTexture(nil, "BACKGROUND")
    level.selectedBorder = level:CreateTexture(nil, "OVERLAY")
    level.playerLevelDiffText = level:CreateFontString(nil, "OVERLAY")
    level.highLevelTexture = level:CreateTexture(nil, "OVERLAY")
    level.highLevelTexture:Hide()
    level.display = true
    function level:ShouldDisplay(u) return u ~= nil and self.display end
    unitFrame.PlayerLevelDiffFrame = level
    unitFrame.unit = unit
    unitFrame.name = unitFrame:CreateFontString(nil, "OVERLAY")
    function unitFrame:IsShowOnlyName() return onlyName[self] == true end
    -- The plate's cast bar (NamePlateCastingBarTemplate): its background, and
    -- the game's fill art and a white tint put back on every change of kind.
    local casts = CreateFrame("Frame", nil, unitFrame)
    local castBar = CreateFrame("StatusBar", nil, casts)
    castBar.Background = castBar:CreateTexture(nil, "BACKGROUND")
    castBar.barType = "standard"
    castBar.Icon = castBar:CreateTexture(nil, "OVERLAY")
    castBar.Text = castBar:CreateFontString(nil, "OVERLAY")           -- the spell's name
    castBar.CastTargetNameText = castBar:CreateFontString(nil, "OVERLAY")
    castBar.unit = unit
    castBar:GetStatusBarTexture()
    -- Shown and hidden by the game after it sets the cast's flags; and the
    -- interrupt's animation, played only when a cast is cut short.
    function castBar:UpdateIconShown() end
    function castBar:PlayInterruptAnims() end
    function castBar:UpdateBarFillTexture()
        self:GetStatusBarTexture():SetTexture(nil)
        self:GetStatusBarTexture():SetAtlas("ui-castingbar-filling-" .. tostring(self.barType))
        self:SetStatusBarColor(1, 1, 1)
    end
    casts.castBar = castBar
    unitFrame.CastBarsContainer = casts
    function unitFrame:IsForbidden() return forbidden == true end
    function unitFrame:UpdateAnchors()
        anchorsRun[self] = (anchorsRun[self] or 0) + 1
        local fill = bar:GetStatusBarTexture()
        fill:SetTexture(nil)
        fill:SetAtlas(GAME_BAR)
        bar.bgTexture:SetAtlas(GAME_BG)
        -- The bar fills its container; the cast bar sits at its container's
        -- top (the styles without the spell name inside, over the icon).
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
        castBar:ClearAllPoints()
        castBar:SetPoint("BOTTOM", castBar.Icon, "TOP", 0, 0)
        -- The health numbers: above the bar's right end with the name above
        -- it, inside the bar with the name inside it.
        for _, s in ipairs({ bar.LeftText, bar.RightText, bar.Text, self.name }) do s:ClearAllPoints() end
        -- A names-only plate: the name across the plate's width, centred.
        if self:IsShowOnlyName() then
            if NamePlateSetupOptions.unitNameAnchorStyle == NamePlateConstants.NAME_ANCHOR_STYLES.InsideHealthBar then
                self.name:SetPoint("LEFT", container, "LEFT", 4, 0)
                self.name:SetPoint("RIGHT", container, "RIGHT", -4, 0)
            else
                self.name:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 4, 2)
                self.name:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", -4, 2)
            end
        elseif NamePlateSetupOptions.unitNameAnchorStyle == NamePlateConstants.NAME_ANCHOR_STYLES.AboveHealthBar then
            bar.LeftText:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -4, 2)
            self.name:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 4)
        else
            bar.LeftText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
            self.name:SetPoint("LEFT", container, "LEFT", 4, 0)
            self.name:SetPoint("RIGHT", bar.Text, "LEFT", -2, 0)
        end
    end
    -- A plate's regions may not be measured by an addon: the game raises
    -- "Can't measure restricted regions" and blames it.
    local function Refuse() error("Can't measure restricted regions", 2) end
    for _, region in ipairs({ unitFrame, container, bar, level, level.playerLevelDiffIcon,
                              level.playerLevelDiffText, level.highLevelTexture, casts,
                              castBar, castBar.Icon, unitFrame.name }) do
        for _, method in ipairs({ "GetPoint", "GetWidth", "GetHeight", "GetSize",
                                  "GetEffectiveScale", "GetLeft", "GetRight", "GetTop",
                                  "GetBottom", "GetRect", "GetCenter" }) do
            region[method] = Refuse
        end
    end
    local plate = { UnitFrame = unitFrame, forbidden = forbidden }
    plates[unit] = plate
    return plate, bar
end

-- The game's nameplate styles, as far as where the name goes: "Modern" puts it
-- inside the bar, "Default" and "Cast Focus" above it.
NamePlateConstants = { NAME_ANCHOR_STYLES = { InsideHealthBar = 1, AboveHealthBar = 2 } }
NamePlateSetupOptions = { unitNameAnchorStyle = 1, playerLevelDiffWidth = 20, playerLevelDiffHeight = 12,
                          healthBarHeight = 20, levelFontHeight = 9, healthBarFontHeight = 12,
                          castBarFontHeight = 11 }
-- The game's nameplate fonts.
SystemFont_NamePlate = { name = "SystemFont_NamePlate" }
SystemFont_NamePlate_Outlined = { name = "SystemFont_NamePlate_Outlined" }
SystemFont_NamePlateLevel = { name = "SystemFont_NamePlateLevel" }

-- The game's driver: a unit getting a plate sets it up, and the nameplate
-- options changing lays every plate out again.
NamePlateDriverFrame = CreateFrame("Frame", "NamePlateDriverFrame")
function NamePlateDriverFrame:OnNamePlateAdded(unit)
    local plate = plates[unit]
    if plate then plate.UnitFrame:UpdateAnchors() end     -- ("preview": the options' own sample)
end
function NamePlateDriverFrame:UpdateNamePlateOptions()
    for _, plate in pairs(plates) do plate.UnitFrame:UpdateAnchors() end
end
-- The game setting a plate's level (CompactUnitFrame.lua): the number goes
-- back over its box, and the skull shows for a unit too high to tell - with
-- no new layout of the plate.
function CompactUnitFrame_UpdatePlayerLevelDiff(frame)
    local level = frame.PlayerLevelDiffFrame
    level.playerLevelDiffText:SetPoint("CENTER", level.playerLevelDiffIcon, "CENTER", 0, 0)
    level.highLevelTexture:SetShown(level.skull == true)
    level.playerLevelDiffText:SetShown(level.skull ~= true)
end
-- The game setting a plate's name (CompactUnitFrame.lua): hidden on some
-- simplified plates, shown otherwise.
function CompactUnitFrame_UpdateName(frame)
    frame.name:SetShown(hiddenName[frame] ~= true)
end
function UnitInParty(unit) return party[unit] == true end
-- The group icon the Quick Join list draws, 20 wide by 18 high.
atlases["socialqueuing-icon-group"] = { width = 20, height = 18 }
-- An addon asking gets no forbidden plate back, as in game.
C_NamePlate = {
    GetNamePlateForUnit = function(unit)
        -- The target's plate, if a test gave the target one.
        if unit == "target" then return targetPlate end
        -- As in game: anything but a unit token is refused with an error
        -- (the options' sample plate is "preview").
        if type(unit) ~= "string" or not unit:match("^nameplate%d+$") then
            error("Player/pet name are not valid arguments for this call.", 2)
        end
        local plate = plates[unit]
        if plate and not plate.forbidden then return plate end
    end,
    GetNamePlates = function()
        local list = {}
        for _, plate in pairs(plates) do
            if not plate.forbidden then list[#list + 1] = plate end
        end
        return list
    end,
}

-- A plate already on screen before the addon's hooks go on.
local early, earlyBar = NewPlate("nameplate1")
earlyBar:GetStatusBarTexture():SetTexture(nil)

-- Everything the game's objects hold now, so a field added to one shows up.
local function Keys(t)
    local keys = {}
    for k in pairs(t) do keys[k] = true end
    return keys
end
local watchedObjects = {}

LoadAddon()
Login()
local Style, Frames = DogsForeverUI.Style, DogsForeverUI.Frames

local function OurBorder(bar)
    for _, frame in ipairs(allFrames) do
        if frame.parent == bar and frame.lines then return frame end
    end
end
local function OurBackground(bar)
    for _, region in ipairs(bar.regions) do
        if region.layer == "BACKGROUND" and region.sublevel == -8 and region.colorTexture then
            return region
        end
    end
end

Section("the look, on a plate that was already there")
do
    check("always on: there is no setting to switch it off",
        Frames.db.styleNamePlates == nil, tostring(Frames.db.styleNamePlates))
    local fill = earlyBar:GetStatusBarTexture()
    check("styled as the hooks go on", fill.texture == FLAT, tostring(fill.texture))
    check("its shadowed background faded out", earlyBar.bgTexture.alpha == 0)
    check("the addon's border round the bar", OurBorder(earlyBar) ~= nil)
    check("and its black background behind it",
        OurBackground(earlyBar) ~= nil
        and Near(OurBackground(earlyBar).colorTexture, Style.BACKGROUND_COLOR))
end

Section("a plate the game hands out later")
local plate, bar = NewPlate("nameplate2")
for _, object in ipairs({ plate, plate.UnitFrame, plate.UnitFrame.HealthBarsContainer, bar,
                          bar.bgTexture, bar:GetStatusBarTexture() }) do
    watchedObjects[object] = Keys(object)
end
NamePlateDriverFrame:OnNamePlateAdded("nameplate2")
do
    local fill = bar:GetStatusBarTexture()
    check("the game set it up first", anchorsRun[plate.UnitFrame] == 1)
    check("then the flat fill replaced its bar art", fill.texture == FLAT, tostring(fill.texture))
    check("on the same texture object the plate's other parts hang off",
        bar:GetStatusBarTexture() == fill)
    check("with the sheen and shade on it",
        (function()
            local gradients = 0
            for _, region in ipairs(bar.regions) do
                if region.gradient then gradients = gradients + 1 end
            end
            return gradients == 2
        end)())
    check("the game's colour for the bar is left to the game", bar.statusColor == nil)
    check("the game's bright ring round the target's bar faded: it made a second border",
        bar.selectedBorder.alpha == 0)
    check("its border off the plate's own scale, so its lines stay on whole pixels",
        OurBorder(bar).ignoreParentScale == true)
    check("and thin: one real pixel a line, not the frames' two",
        OurBorder(bar).unitPixels == 1)

    local level = plate.UnitFrame.PlayerLevelDiffFrame
    check("the level box and its ring faded, so the level is plain text",
        level.playerLevelDiffIcon.alpha == 0 and level.selectedBorder.alpha == 0)
    check("with the number and the skull left as they are",
        (level.playerLevelDiffText.alpha or 1) == 1 and (level.highLevelTexture.alpha or 1) == 1)
end

Section("the game putting its art back")
plate.UnitFrame:UpdateAnchors()
check("its own layout ran again", anchorsRun[plate.UnitFrame] == 2)
check("and the look is put straight back after it",
    bar:GetStatusBarTexture().texture == FLAT and bar.bgTexture.alpha == 0)
NamePlateDriverFrame:UpdateNamePlateOptions()
check("after the nameplate options change too", bar:GetStatusBarTexture().texture == FLAT)
do
    local borders = 0
    for _, frame in ipairs(allFrames) do
        if frame.parent == bar and frame.lines then borders = borders + 1 end
    end
    check("with one border, however often it is put back", borders == 1, borders)
end

Section("the plate's cast bar")
do
    local castBar = plate.UnitFrame.CastBarsContainer.castBar
    local Style = DogsForeverUI.Style
    castBar:UpdateBarFillTexture()      -- a cast starting
    check("the flat fill, not the game's cast art",
        castBar:GetStatusBarTexture().texture == FLAT, tostring(castBar:GetStatusBarTexture().texture))
    check("in the castbar's colour for a cast",
        Near(castBar.statusColor, Style.CAST_COLOR.casting), tostring(castBar.statusColor[2]))
    local border
    for _, frame in ipairs(allFrames) do
        if frame.parent == castBar and frame.lines then border = frame end
    end
    check("with the thin border, the black background and the sheen",
        border ~= nil and border.unitPixels == 1 and castBar.Background.alpha == 0
        and OurBackground(castBar) ~= nil)
    castBar.barType = "channel"
    castBar:UpdateBarFillTexture()
    check("a channel in the channel colour, after the game repaints it",
        castBar:GetStatusBarTexture().texture == FLAT
        and Near(castBar.statusColor, Style.CAST_COLOR.channel))
    castBar.barType = "uninterruptable"
    castBar:UpdateBarFillTexture()
    check("one that cannot be interrupted in its grey",
        Near(castBar.statusColor, Style.CAST_COLOR.uninterruptible))
    castBar.barType = "interrupted"
    castBar:UpdateBarFillTexture()
    check("an interrupted one in red", Near(castBar.statusColor, Style.CAST_COLOR.failed))

    -- For a unit the client restricts, the kind of cast is a secret, which
    -- may not be tested or used as a key - it raised on every cast in game.
    local secretKind = setmetatable({}, { __tostring = function() return "secret" end })
    secretValues[secretKind] = true
    castBar.barType = secretKind
    -- Whether it can be interrupted is a secret as well.
    local secretLocked = setmetatable({}, { __tostring = function() return "secret" end })
    secretValues[secretLocked] = true
    casting.nameplate2 = { name = "Frostbolt", start = 0, finish = 2, notInterruptible = secretLocked }
    castBar.casting, castBar.channeling = true, nil
    local ok, err = pcall(function()
        castBar:UpdateBarFillTexture()
        castBar:UpdateIconShown()
    end)
    check("a secret kind of cast raises nothing", ok, tostring(err))
    local fill = castBar:GetStatusBarTexture()
    check("and still has the flat fill, not the game's cast art",
        fill.texture == FLAT, tostring(fill.texture))
    check("in the cast's colour, known from the bar's own casting flag",
        Near(castBar.statusColor, Style.CAST_COLOR.casting))
    check("the grey for a cast that can't be interrupted picked by the secret itself, untested",
        fill.vertexFromBoolean ~= nil and fill.vertexFromBoolean.value == secretLocked
        and fill.vertexFromBoolean.ifTrue.g == Style.CAST_COLOR.uninterruptible[2]
        and fill.vertexFromBoolean.ifFalse.g == Style.CAST_COLOR.casting[2])
    casting.nameplate2 = { name = "Blizzard", start = 0, finish = 2, channel = true,
                           notInterruptible = false }
    castBar.casting, castBar.channeling = nil, true
    castBar:UpdateBarFillTexture()
    castBar:UpdateIconShown()
    check("a channel in the channel colour",
        fill.texture == FLAT and Near(castBar.statusColor, Style.CAST_COLOR.channel))
    castBar:UpdateBarFillTexture()
    castBar:PlayInterruptAnims()
    check("cut short: red, known from the game's interrupt animation",
        Near(castBar.statusColor, Style.CAST_COLOR.failed))
    castBar:UpdateBarFillTexture()
    check("and it stays red while the game repaints the finished bar",
        Near(castBar.statusColor, Style.CAST_COLOR.failed))
    casting.nameplate2 = nil
    castBar.casting, castBar.channeling = nil, nil
    secretValues[secretKind] = nil
    secretValues[secretLocked] = nil
    castBar.barType = "standard"
end

Section("a cast bar that has never shown a cast")
do
    -- A name-only plate's cast bar, as in game: no fill texture until the game
    -- draws a cast in it (UpdateBarFillTexture). It raised on the plate's
    -- arrival, in the look's first paint.
    local fresh = NewPlate("nameplate7")
    local castBar = fresh.UnitFrame.CastBarsContainer.castBar
    castBar.statusTexture = nil
    local made = false
    local realFill = castBar.GetStatusBarTexture
    function castBar:GetStatusBarTexture()
        if not made then return nil end
        return realFill(self)
    end
    local ok, err = pcall(NamePlateDriverFrame.OnNamePlateAdded, NamePlateDriverFrame, "nameplate7")
    check("its plate arriving raises nothing", ok, tostring(err))
    made = true
    castBar:UpdateBarFillTexture()      -- its first cast
    check("and the look goes on with its first cast",
        castBar:GetStatusBarTexture().texture == FLAT, tostring(castBar:GetStatusBarTexture().texture))
    plates.nameplate7 = nil
end

Section("the level inside the bar, the bar the plate's width")
do
    local unitFrame = plate.UnitFrame
    local level, container = unitFrame.PlayerLevelDiffFrame, unitFrame.HealthBarsContainer
    local text, skull = level.playerLevelDiffText, level.highLevelTexture
    local function Anchor(region, point)
        for _, a in ipairs(region.anchors or {}) do
            if a[1] == point then return a end
        end
    end
    unitFrame:UpdateAnchors()
    local right = Anchor(bar, "BOTTOMRIGHT")
    check("the bar reaches over the level box's room, by exactly its width",
        right and right[2] == container and right[4] == 20, right and tostring(right[4]))
    check("the level is plain text inside the bar's left end",
        text.points[1] == "LEFT" and text.points[2] == bar and text.points[4] == 4)
    local left = Anchor(unitFrame.name, "LEFT")
    check("the name starts after it", left and left[2] == text and left[3] == "RIGHT")
    check("and still ends short of the health numbers",
        Anchor(unitFrame.name, "RIGHT") and Anchor(unitFrame.name, "RIGHT")[2] == bar.Text)

    CompactUnitFrame_UpdatePlayerLevelDiff(unitFrame)
    check("the game setting the level again puts it back in the bar",
        text.points[1] == "LEFT" and text.points[2] == bar)
    level.skull = true
    CompactUnitFrame_UpdatePlayerLevelDiff(unitFrame)
    check("a unit too high to tell: the skull in the bar, text-sized, the name after it",
        skull.points[2] == bar and skull.width == skull.height
        and Anchor(unitFrame.name, "LEFT")[2] == skull)
    level.skull = nil
    CompactUnitFrame_UpdatePlayerLevelDiff(unitFrame)

    level.display = false
    unitFrame:UpdateAnchors()
    check("no level box: the game left no room for it, so the bar is not widened",
        Anchor(bar, "BOTTOMRIGHT")[4] == 0)
    level.display = true
    unitFrame:UpdateAnchors()

    local castBar = unitFrame.CastBarsContainer.castBar
    local top = Anchor(castBar, "TOPLEFT")
    local spacer = top and top[2]
    check("the cast bar hangs from a spacer of the addon's own under the health bar",
        spacer ~= nil and spacer ~= bar and spacer.parent == bar and spacer.ignoreParentScale == true
        and Anchor(spacer, "TOPLEFT")[2] == bar and Anchor(spacer, "TOPLEFT")[3] == "BOTTOMLEFT")
    check("as tall as both borders and three clear pixels",
        spacer ~= nil and spacer.height == 9, spacer and tostring(spacer.height))
    check("the bar's width: the plate's, as before",
        Anchor(castBar, "TOPRIGHT") and Anchor(castBar, "TOPRIGHT")[2] == spacer
        and Anchor(spacer, "TOPRIGHT")[2] == bar)
    local under = castBar.Icon.points[2]
    check("its icon and spell name hang under it, clear of its border",
        under ~= nil and under ~= castBar and under.parent == castBar
        and castBar.Icon.points[3] == "BOTTOMLEFT" and under.height == 5
        and Anchor(under, "TOPLEFT")[2] == castBar, under and tostring(under.height))

    local outlined, size = SystemFont_NamePlate_Outlined, NamePlateSetupOptions.levelFontHeight
    local sized = true
    for _, label in ipairs({ level.playerLevelDiffText, bar.LeftText, bar.RightText, bar.Text }) do
        sized = sized and label.textHeight == size and label.fontObject == outlined
    end
    check("the level and the health numbers: the level's size, in the name's font",
        sized)
    check("the name and the spell name the level's size too",
        unitFrame.name.textHeight == size and castBar.Text.textHeight == size
        and castBar.CastTargetNameText.textHeight == size)
end

Section("a style with the name above the bar")
check("with the name inside the bar, the numbers are left where the game puts them",
    bar.LeftText.points[1] == "RIGHT" and bar.LeftText.points[2] == bar)
NamePlateSetupOptions.unitNameAnchorStyle = 2
NamePlateDriverFrame:UpdateNamePlateOptions()
check("with the name above, the numbers go inside the bar's right end, off the name's row",
    bar.LeftText.points[1] == "RIGHT" and bar.LeftText.points[2] == bar
    and bar.LeftText.points[4] == -4 and bar.RightText.points[2] == bar.LeftText
    and bar.Text.points[2] == bar.RightText, tostring(bar.LeftText.points[1]))

Section("a plate the game keeps from addons")
local _, forbiddenBar = NewPlate("nameplate3", true)
NamePlateDriverFrame:OnNamePlateAdded("nameplate3")
check("is not asked for, and keeps the game's look",
    forbiddenBar:GetStatusBarTexture().atlas == GAME_BAR
    and forbiddenBar:GetStatusBarTexture().texture == nil
    and OurBorder(forbiddenBar) == nil)

Section("friendly players: names only")
do
    local NAMES_ONLY = "nameplateShowOnlyNameForFriendlyPlayerUnits"
    check("the game's own setting for it is on with the look", cvars[NAMES_ONLY] == true)
    C_CVar.SetCVar(NAMES_ONLY, "0")         -- the game's options turning it off
    check("and held: turned off from the game's options, it comes straight back on",
        cvars[NAMES_ONLY] == true)
    inCombat = true
    C_CVar.SetCVar(NAMES_ONLY, "0")
    check("never changed in combat, where the game may refuse it",
        cvars[NAMES_ONLY] == false and cvarWritesInCombat == 1)
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    check("but as soon as combat ends", cvars[NAMES_ONLY] == true)
end

Section("a party member's plate: the group mark beside the name")
do
    local function Anchor(region, point)
        for _, a in ipairs(region.anchors or {}) do
            if a[1] == point then return a end
        end
    end
    local function Mark(unitFrame)
        for _, region in ipairs(unitFrame.regions) do
            if region.atlas == "socialqueuing-icon-group" then return region end
        end
    end

    NamePlateSetupOptions.unitNameAnchorStyle = 1      -- the name inside the bar
    local friend = NewPlate("nameplate4")
    local unitFrame = friend.UnitFrame
    local name, container = unitFrame.name, unitFrame.HealthBarsContainer
    local row = unitFrame.CastBarsContainer   -- the empty cast bar row: the name stands on its middle
    onlyName[unitFrame] = true
    watchedObjects[unitFrame] = Keys(unitFrame)
    watchedObjects[name] = Keys(name)

    NamePlateDriverFrame:OnNamePlateAdded("nameplate4")
    check("a friendly player not in the party: no mark, the name lowered to the plate's bottom",
        Mark(unitFrame) == nil and #name.anchors == 2
        and Anchor(name, "BOTTOMLEFT") and Anchor(name, "BOTTOMLEFT")[2] == row
        and Anchor(name, "BOTTOMLEFT")[3] == "LEFT" and Anchor(name, "BOTTOMLEFT")[5] == 0
        and Anchor(name, "BOTTOMRIGHT")[4] == -4)

    local NP = DogsForeverUI.Frames.NamePlates
    local size = NamePlateSetupOptions.levelFontHeight
    check("a friendly name a little smaller than the plates' text",
        math.abs(name.textHeight - size * NP.FRIENDLY_NAME) < 1e-9, tostring(name.textHeight))
    -- The client's plate sizes: every plate's, and the target's (its whole size).
    local realCVar = C_CVar
    local scales = { nameplateMaxScale = "1.2", nameplateSelectedScale = "1.32" }
    C_CVar = {
        GetCVar = function(cvar) return scales[cvar] or realCVar.GetCVar(cvar) end,
        SetCVar = function(cvar, value)
            if scales[cvar] then scales[cvar] = tostring(value) return true end
            return realCVar.SetCVar(cvar, value)
        end,
    }
    local function Selected() return tonumber(scales.nameplateSelectedScale) end

    -- A plate with its bars (an enemy's): the game grows the whole plate.
    onlyName[unitFrame] = nil
    targetPlate = friend
    Fire("PLAYER_TARGET_CHANGED")
    check("a new target: its plate starts at the others' size", math.abs(Selected() - 1.2) < 1e-6)
    Tick(NP.GROW_TIME / 2)
    check("growing, not jumping: part way there half way through",
        Selected() > 1.2 and Selected() < 1.2 * NP.TARGET_GROW, tostring(Selected()))
    Tick(NP.GROW_TIME)
    check("then grown: the whole plate TARGET_GROW times the others' (the game's own scale)",
        math.abs(Selected() - 1.2 * NP.TARGET_GROW) < 1e-6 and NP.TARGET_GROW > 1)
    check("its unit frame not scaled: the bar keeps its width", unitFrame.scale == 1)
    targetPlate = nil
    Fire("PLAYER_TARGET_CHANGED")
    Tick(NP.GROW_TIME * 1.5)
    onlyName[unitFrame] = true

    -- A friendly name-only plate: grown more, the unit frame taking on the rest.
    targetPlate = friend
    Fire("PLAYER_TARGET_CHANGED")
    check("targeted: its name's own size kept", math.abs(name.textHeight - size * NP.FRIENDLY_NAME) < 1e-9)
    Tick(NP.GROW_TIME / 2)
    local full = NP.TARGET_NAME_GROW / NP.TARGET_GROW
    local midway = unitFrame.scale
    check("the name growing, not jumping: part way there half way through",
        midway > 1 and midway < full, tostring(midway))
    Tick(NP.GROW_TIME)
    check("then grown: TARGET_NAME_GROW in all, larger than every other name",
        math.abs(unitFrame.scale * Selected() / 1.2 - NP.TARGET_NAME_GROW) < 1e-6)
    targetPlate = nil
    Fire("PLAYER_TARGET_CHANGED")
    Tick(NP.GROW_TIME / 2)
    check("the target moving on: shrinking back smoothly", unitFrame.scale > 1 and unitFrame.scale < full)
    Tick(NP.GROW_TIME)
    check("and back", unitFrame.scale == 1)
    C_CVar = realCVar

    party.nameplate4 = true
    Fire("GROUP_ROSTER_UPDATE")
    local mark = Mark(unitFrame)
    local size = NamePlateSetupOptions.levelFontHeight + 2
    check("joins the party: the game's group icon on their plate", mark ~= nil and mark.shown)
    check("a little taller than the name's text, in the icon's own proportions",
        mark ~= nil and mark.height == size and math.abs(mark.width - size * 20 / 18) < 0.001,
        mark and (tostring(mark.width) .. "x" .. tostring(mark.height)))
    local width = mark and mark.width or 0
    local middle = Anchor(name, "BOTTOM")
    check("the name held by its middle, so it is as wide as its text - lowered too",
        #name.anchors == 1 and middle ~= nil and middle[2] == row and middle[3] == "CENTER")
    check("moved right by half the mark and its gap: the two are centred together",
        middle ~= nil and math.abs(middle[4] - (width + 3) / 2) < 0.001 and middle[5] == 0,
        middle and tostring(middle[4]))
    check("the mark just left of the name",
        mark ~= nil and mark.points[1] == "RIGHT" and mark.points[2] == name
        and mark.points[3] == "LEFT" and mark.points[4] == -3)

    unitFrame:UpdateAnchors()
    check("the game laying the plate out again: the mark and the name put straight back",
        #name.anchors == 1 and Anchor(name, "BOTTOM") ~= nil and Mark(unitFrame).shown)
    local marks = 0
    for _, region in ipairs(unitFrame.regions) do
        if region.atlas == "socialqueuing-icon-group" then marks = marks + 1 end
    end
    check("with one mark, however often it is put back", marks == 1, marks)

    hiddenName[unitFrame] = true
    CompactUnitFrame_UpdateName(unitFrame)
    check("the game hiding the name hides the mark", not Mark(unitFrame).shown)
    hiddenName[unitFrame] = nil
    CompactUnitFrame_UpdateName(unitFrame)
    check("and showing it shows the mark", Mark(unitFrame).shown)

    NamePlateSetupOptions.unitNameAnchorStyle = 2      -- the name above the bar
    NamePlateDriverFrame:UpdateNamePlateOptions()
    local bottom = Anchor(name, "BOTTOM")
    check("with the name above the bar: the same, the name style makes no difference",
        #name.anchors == 1 and bottom ~= nil and bottom[2] == row and bottom[3] == "CENTER"
        and math.abs(bottom[4] - (width + 3) / 2) < 0.001 and bottom[5] == 0)

    party.nameplate4 = nil
    Fire("GROUP_ROSTER_UPDATE")
    check("leaves the party: the mark goes",  not Mark(unitFrame).shown)
    check("and the name is across the plate again, still lowered",
        #name.anchors == 2 and Anchor(name, "BOTTOMLEFT")[2] == row
        and Anchor(name, "BOTTOMLEFT")[4] == 4 and Anchor(name, "BOTTOMRIGHT")[4] == -4)

    local stranger = NewPlate("nameplate5")
    party.nameplate5 = true
    NamePlateDriverFrame:OnNamePlateAdded("nameplate5")
    check("a party member with a full plate (not names only) is left alone",
        Mark(stranger.UnitFrame) == nil and Anchor(stranger.UnitFrame.name, "CENTER") == nil)
    local full = Anchor(stranger.UnitFrame.name, "BOTTOMLEFT")
    check("a full plate (any hostile one) keeps the game's name anchors: never lowered",
        full ~= nil and full[2] == stranger.UnitFrame.HealthBarsContainer and full[3] == "TOPLEFT")
    party.nameplate5 = nil

    local _, lockedBar = NewPlate("nameplate6", true)
    onlyName[plates.nameplate6.UnitFrame] = true
    party.nameplate6 = true
    NamePlateDriverFrame:OnNamePlateAdded("nameplate6")
    Fire("GROUP_ROSTER_UPDATE")
    check("a plate the game keeps from addons (a party member in a dungeon) gets nothing",
        Mark(plates.nameplate6.UnitFrame) == nil)
    party.nameplate6 = nil

    -- A client without the icon: no mark, never a missing texture.
    local saved = atlases["socialqueuing-icon-group"]
    atlases["socialqueuing-icon-group"] = nil
    party.nameplate4 = true
    Fire("GROUP_ROSTER_UPDATE")
    check("no group icon in the client: no mark and the name stays the game's",
        not Mark(unitFrame).shown and #name.anchors == 2)
    atlases["socialqueuing-icon-group"] = saved
    party.nameplate4 = nil
    Fire("GROUP_ROSTER_UPDATE")
end

Section("nothing written into the game's tables")
do
    -- What this harness records of a widget call (SetAtlas, SetAlpha...) is
    -- widget state, not a Lua field the addon wrote.
    local WIDGET_STATE = { atlas = true, alpha = true, texture = true, shown = true,
                           points = true, anchors = true, vertexColor = true,
                           statusColor = true, width = true, height = true,
                           fontObject = true, textHeight = true, vertexFromBoolean = true }
    local added = {}
    for object, before in pairs(watchedObjects) do
        for k in pairs(object) do
            if not before[k] and not WIDGET_STATE[k] then added[#added + 1] = tostring(k) end
        end
    end
    check("no Lua field added to the game's plate, unit frame or bar",
        #added == 0, table.concat(added, ", "))
    check("the game's own methods followed, not replaced: they still run",
        anchorsRun[plate.UnitFrame] >= 3)
end

Section("the game's nameplate options: Large, Health Percentage on - once")
do
    local NP = DogsForeverUI.Frames.NamePlates
    -- The two CVars as the client keeps them: the style a number, the
    -- information a bit field (a version byte, then 6 bits a byte, 0x40 set).
    Enum = Enum or {}
    Enum.NamePlateStyle = Enum.NamePlateStyle or { Thin = 1, Modern = 2, Block = 3 }
    Enum.NamePlateInfoDisplay = Enum.NamePlateInfoDisplay or { CurrentHealthPercent = 1, CurrentHealthValue = 2 }
    local store = { nameplateStyle = "1", nameplateInfoDisplay = string.char(1, 0x40 + 2),   -- Thin; value only
                    nameplateMinScale = "0.8", nameplateMaxScale = "1", nameplateSelectedScale = "1.2" }
    local realCVar = C_CVar
    C_CVar = {
        GetCVar = function(name) return store[name] or realCVar.GetCVar(name) end,
        SetCVar = function(name, value)
            if store[name] ~= nil then store[name] = tostring(value) return true end
            return realCVar.SetCVar(name, value)
        end,
    }
    local db = DogsForeverUI.Frames.db
    local FRIENDLY_BAR, FRIENDLY_NAME = "nameplateShowFriendlyClassColor",
        "nameplateUseClassColorForFriendlyPlayerUnitNames"
    -- No saved file in this session: two seconds after the world is up.
    Tick(2.1)
    db.nameplateDefaults = 0
    cvars[FRIENDLY_BAR], cvars[FRIENDLY_NAME] = false, false
    NP.SetDefaults()
    check("Style: Large", store.nameplateStyle == tostring(Enum.NamePlateStyle.Modern))
    check("Nameplate Information: Health Percentage on, Health Value kept",
        store.nameplateInfoDisplay == string.char(1, 0x40 + 2 + 1))
    check("friendly players in class colours: the bar and the name",
        cvars[FRIENDLY_BAR] == true and cvars[FRIENDLY_NAME] == true)
    check("plates not targeted the size a targeted one was, near or far",
        store.nameplateMinScale == "1.2" and store.nameplateMaxScale == "1.2",
        tostring(store.nameplateMinScale) .. "/" .. tostring(store.nameplateMaxScale))
    check("the targeted one TARGET_GROW times larger (this client takes it as the target's whole size)",
        math.abs(tonumber(store.nameplateSelectedScale) - 1.2 * NP.TARGET_GROW) < 1e-6,
        tostring(store.nameplateSelectedScale))
    check("done once for the character", db.nameplateDefaults == NP.DEFAULT_STEPS)
    store.nameplateStyle, store.nameplateInfoDisplay = "1", string.char(1)
    cvars[FRIENDLY_NAME] = false
    NP.SetDefaults()
    NP.Refresh()
    Fire("PLAYER_ENTERING_WORLD")
    Tick(2.1)
    check("changed in the game's options afterwards: stays changed",
        store.nameplateStyle == "1" and store.nameplateInfoDisplay == string.char(1)
        and cvars[FRIENDLY_NAME] == false)

    DogsForeverUI:ResetAll()
    check("Reset everything: the addon's defaults again, at once",
        store.nameplateStyle == tostring(Enum.NamePlateStyle.Modern)
        and store.nameplateInfoDisplay == string.char(1, 0x41)
        and cvars[FRIENDLY_NAME] == true and db.nameplateDefaults == NP.DEFAULT_STEPS)
    store.nameplateStyle = "1"
    check("an empty field: the bit's byte made", NP.WithBit(string.char(1), 1) == string.char(1, 0x41)
        and NP.WithBit(string.char(1), 8) == string.char(1, 0x40, 0x42))
    db.nameplateDefaults = 0
    inCombat = true
    NP.SetDefaults()
    check("never in combat", store.nameplateStyle == "1" and db.nameplateDefaults == 0)
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    check("but as it ends", store.nameplateStyle == tostring(Enum.NamePlateStyle.Modern) and db.nameplateDefaults == NP.DEFAULT_STEPS)

    -- A character that had the first defaults before class colours came.
    store.nameplateStyle, store.nameplateInfoDisplay = "1", string.char(1)
    cvars[FRIENDLY_BAR], cvars[FRIENDLY_NAME] = false, false
    db.nameplateDefaults = true
    NP.SetDefaults()
    check("set before class colours came: class colours now, once",
        cvars[FRIENDLY_BAR] == true and cvars[FRIENDLY_NAME] == true
        and db.nameplateDefaults == NP.DEFAULT_STEPS)
    check("and the player's style and information left as they are",
        store.nameplateStyle == "1" and store.nameplateInfoDisplay == string.char(1))
    C_CVar = realCVar
end

Section("the options' sample plate: no error")
do
    local ok, err = pcall(NamePlateDriverFrame.OnNamePlateAdded, NamePlateDriverFrame, "preview")
    check("a plate for \"preview\" (the game's options) is left alone, no error", ok, tostring(err))
end

Section("a reload: the saved file late, the player's own choice kept")
do
    local store = { nameplateStyle = "1", nameplateInfoDisplay = string.char(1) }   -- the player's
    local realCVar = C_CVar
    C_CVar = {
        GetCVar = function(name) return store[name] or realCVar.GetCVar(name) end,
        SetCVar = function(name, value)
            if store[name] ~= nil then store[name] = tostring(value) return true end
            return realCVar.SetCVar(name, value)
        end,
    }
    local FRIENDLY_NAME = "nameplateUseClassColorForFriendlyPlayerUnitNames"
    cvars[FRIENDLY_NAME] = false
    Reload(nil)
    -- The file reaches the addon only after the world is up.
    Fire("ADDON_LOADED", "DogsForeverUI")
    Fire("PLAYER_LOGIN")
    Fire("PLAYER_ENTERING_WORLD")
    check("before the file is in, nothing is set",
        store.nameplateStyle == "1" and store.nameplateInfoDisplay == string.char(1)
        and cvars[FRIENDLY_NAME] == false)
    DogsForeverUIDB = { frames = { nameplateDefaults = 2 }, gamedefaults = { done = 1 } }
    Fire("VARIABLES_LOADED")
    Tick(2.1)
    check("and once it is, the defaults are known to be done: still the player's",
        store.nameplateStyle == "1" and store.nameplateInfoDisplay == string.char(1)
        and cvars[FRIENDLY_NAME] == false)
    C_CVar = realCVar
end

Summary()
