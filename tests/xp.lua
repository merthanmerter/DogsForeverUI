-- The XP bar module: an XP bar of the addon's own at any size, and the game's
-- own XP bar faded out - only while it is the XP bar - and given back.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

local function Near(colour, want)
    if type(colour) ~= "table" then return false end
    for i = 1, 3 do
        if type(colour[i]) ~= "number" or math.abs(colour[i] - want[i]) > 0.002 then
            return false
        end
    end
    return true
end

-- What every Blizzard object held before the addon loaded, so a field it added
-- to one shows up.
local keysBefore = {}
for _, frame in ipairs(blizzardObjects) do
    local keys = {}
    for k in pairs(frame) do keys[k] = true end
    keysBefore[frame] = keys
end

LoadAddon()
Login()

local NS = DogsForeverUI.XPBar
local Style = DogsForeverUI.Style
local DB = NS.db
local bar, rested = NS.bar, NS.rested
local main, second = MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer
local XP, REP = StatusTrackingBarInfo.BarsEnum.Experience, StatusTrackingBarInfo.BarsEnum.Reputation
local HONOR = StatusTrackingBarInfo.BarsEnum.Honor
local ARTIFACT = StatusTrackingBarInfo.BarsEnum.Artifact
local honorBar = NS.honor

local function MainFaded()
    if main.bars[XP].alpha ~= 0 or main.BarFrameTexture.alpha ~= 0 then return false end
    for divider in main.HorizontalDividersPool:EnumerateActive() do
        if divider.alpha ~= 0 then return false end
    end
    return true
end
local function MainDrawn()
    if main.bars[XP].alpha ~= 1 or main.BarFrameTexture.alpha ~= 1 then return false end
    for divider in main.HorizontalDividersPool:EnumerateActive() do
        if divider.alpha ~= 1 then return false end
    end
    return true
end

Section("the bar")
check("always on, with no switch", DB.enabled == nil and DB.showRested == nil and bar:IsShown())
check("smaller than the game's by default", DB.barWidth == 300 and DB.barHeight == 10)
check("centred", DB.barLeft == (1920 - 300) / 2, DB.barLeft)
check("over where the game's XP bar is",
    math.abs(DB.barTop - -(1080 - 70 - 5)) < 0.001, DB.barTop)
check("and placed by the addon, so a new resolution may move it", DB.autoPlaced == true)
check("exactly its settings' size", bar.width == 300 and bar.height == 10)

check("filled to the XP the player has",
    select(2, bar:GetMinMaxValues()) == 10000 and bar:GetValue() == 2500)
check("with the rested XP shaded in beyond it",
    rested:GetValue() == 4000 and (rested.alpha or 1) == 1, rested:GetValue())
do
    local texts = 0
    for _, region in ipairs(bar.regions) do
        if region.kind == "FontString" then texts = texts + 1 end
    end
    check("and no text on it at all", bar.label == nil and texts == 0, texts)
end
check("just the spark at the end of the XP, as on the castbar",
    bar.spark ~= nil and bar.spark.texture == DogsForeverUI.Style.SPARK
    and bar.spark.points[2] == bar:GetStatusBarTexture() and bar.spark.points[3] == "RIGHT"
    and bar.spark.alpha == 1)
check("nor a setting for any", DB.showText == nil and DB.textPadding == nil)

Section("the look")
check("the flat fill with its sheen, in the classic XP bar's own purple",
    bar:GetStatusBarTexture().texture == Style.FLAT_TEXTURE and bar.sheen ~= nil
    and Near(bar.statusColor, { 0.58, 0.0, 0.55 }))
check("the rested XP solid, in the classic bar's own rested blue",
    Near(rested.statusColor, { 0.0, 0.39, 0.88 }) and (rested.alpha or 1) == 1)
check("on the black background, at half",
    bar.bg.colorTexture ~= nil and Near(bar.bg.colorTexture, Style.BACKGROUND_COLOR) and bar.bg.colorTexture[4] == 0.5)
check("under the rested shading, not over it", bar.bg.parent == rested)
check("and the border every bar wears", bar.border ~= nil)

Section("it follows the XP")
xp.current, xp.rested = 9000, 5000
Fire("PLAYER_XP_UPDATE", "player")
check("more XP fills it further", bar:GetValue() == 9000)
check("rested XP never runs past the end of the bar", rested:GetValue() == 10000)

NS.Refresh()
check("rested XP is always shaded in", rested:GetValue() > bar:GetValue())

xp.canShow = false
Fire("PLAYER_LEVEL_UP", 60)
check("gone at the level cap, as the game's is", bar:IsShown() == false)
xp.canShow = true
Fire("PLAYER_XP_UPDATE", "player")
check("and back when there is XP to show", bar:IsShown() == true)

-- XP is not secret on this client, but it is asked about anyway: a value that
-- cannot be read goes straight to the bar with nothing worked out from it.
do
    local hidden, hiddenMax = Unreadable("the player's XP"), Unreadable("the XP for the level")
    xp.current, xp.max = hidden, hiddenMax
    local ok, err = pcall(Fire, "PLAYER_XP_UPDATE", "player")
    check("XP the client will not let us read does not throw", ok, err)
    check("it reaches the bar untouched",
        bar:GetValue() == hidden and select(2, bar:GetMinMaxValues()) == hiddenMax)
    xp.current, xp.max = 2500, 10000
    Fire("PLAYER_XP_UPDATE", "player")
end

Section("any size")
-- As its Unlock Mode menu sets it (the options' Sizes rows went there, 2026-10-03).
local xpEntry = DogsForeverUI.Snap.EntryById("xp")
check("a width and a height of its own in Unlock Mode",
    DogsForeverUI.Snap.SizeOf(xpEntry, "w") ~= nil and DogsForeverUI.Snap.SizeOf(xpEntry, "h") ~= nil)
DogsForeverUI.Snap.SetSize(xpEntry, "w", 120)
DogsForeverUI.Snap.SetSize(xpEntry, "h", 3)
check("a tiny bar is just that", bar.width == 120 and bar.height == 3,
    bar.width .. "x" .. bar.height)
check("and a typed size is the player's from then on", DB.autoPlaced == false)

Section("placing it")
check("no placement label: Edit Mode's box names it", bar.placementLabels == nil)
DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
check("unlocked, it shows as it really looks: the real XP, on its own background",
    DB.unlocked == true and bar:IsShown() and bar:GetValue() == 2500
    and not PlacingLook(bar.bg) and bar.bg:GetEffectiveAlpha() == 1)
bar.left, bar.top = 500, 200
bar.scripts.OnMouseUp(bar, "LeftButton")
check("a drag saves where it was put", DB.barLeft == 500 and DB.barTop == -880)
DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
check("and again puts it back to work", DB.unlocked == false and bar:GetValue() == 2500)

DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
pendingTimer = nil
bar.scripts.OnMouseUp(bar, "RightButton")
check("a right-click on the placed bar does nothing: still unlocked, still there",
    pendingTimer == nil and DB.unlocked == true and DB.barLeft == 500)
DogsForeverUI.SetUnlocked(not DogsForeverUI.IsUnlocked())
check("locked, back to work", DB.unlocked == false and bar:GetValue() == 2500)
Fire("PLAYER_ENTERING_WORLD")
check("and a placed bar is never moved again", DB.barLeft == 500)

Section("the numbers are on hover")
bar.scripts.OnEnter(bar)
check("hovering shows them in the tooltip",
    GameTooltip.owner == bar and GameTooltip:GetLines():find("2500 / 10000", 1, true) ~= nil,
    GameTooltip:GetLines())
bar.scripts.OnLeave(bar)

Section("the game's own XP bar")
check("is faded out: the bar, its frame and its dividers", MainFaded())
check("while another bar of the game's, the artifact bar, is left alone",
    second.bars[ARTIFACT].alpha == 1 and second.BarFrameTexture.alpha == 1)

main:UpdateDividers()
check("fresh dividers from a re-layout are faded too", MainFaded())

-- The same container can show another bar of the game's instead: that is the
-- game's, and must be drawn.
main.pendingBarToShowIndex = ARTIFACT
main:ApplyPendingBarToShow()
check("when the container switches to another bar of the game's it is drawn again",
    main.bars[ARTIFACT].alpha == 1 and main.BarFrameTexture.alpha == 1 and main.bars[XP].alpha == 1)
main.pendingBarToShowIndex = XP
main:ApplyPendingBarToShow()
check("and when it switches back to XP it is faded again", MainFaded())

-- "Show as experience bar" ticked for a faction: the game shows it in its
-- own bar (in the main container, XP pushed to the second); this bar shows it
-- instead.
watchedFaction = { factionID = 530, name = "Darkspear Trolls", reaction = 5,
                   currentReactionThreshold = 3000, nextReactionThreshold = 9000,
                   currentStanding = 3592 }
Fire("UPDATE_FACTION")
check("a watched reputation is shown in this bar instead of the XP",
    select(2, bar:GetMinMaxValues()) == 6000 and bar:GetValue() == 592, bar:GetValue())
check("in the colour of the standing: friendly green",
    Near(bar.statusColor, { 0.2, 0.8, 0.2 }))
check("with no rested XP shaded in", rested:GetValue() == 0)
main.pendingBarToShowIndex = REP
main:ApplyPendingBarToShow()
check("and the game's reputation bar faded out like its XP bar",
    main.bars[REP].alpha == 0 and main.BarFrameTexture.alpha == 0)
bar.scripts.OnEnter(bar)
check("the faction, the numbers and the standing are in the tooltip",
    GameTooltip:GetLines():find("Darkspear Trolls", 1, true) ~= nil
    and GameTooltip:GetLines():find("592 / 6000", 1, true) ~= nil
    and GameTooltip:GetLines():find("Friendly", 1, true) ~= nil, GameTooltip:GetLines())
bar.scripts.OnLeave(bar)
watchedFaction = nil
Fire("UPDATE_FACTION")
check("unwatched, the bar is the XP bar again, in its purple",
    bar:GetValue() == xp.current and Near(bar.statusColor, { 0.58, 0.0, 0.55 }), bar:GetValue())
main.pendingBarToShowIndex = XP
main:ApplyPendingBarToShow()

Section("the honor bar")
check("hidden while the game would not show its own", not honorBar:IsShown())
honor.canShow = true
Fire("ZONE_CHANGED_NEW_AREA")
check("shown where the game would show its own (a battleground)", honorBar:IsShown())
check("as wide as the XP bar, two thirds as tall",
    honorBar.width == bar.width and honorBar.height == math.max(1, math.floor(bar.height * 2 / 3 + 0.5)),
    honorBar.width .. "x" .. honorBar.height)
check("stacked over it, two pixels between their borders",
    honorBar.points[2] == bar and honorBar.points[3] == "TOPLEFT"
    and honorBar.points[5] == 2 + 2 * Style.BORDER_INSET)
check("in the game's honor orange, with the border every bar wears",
    Near(honorBar.statusColor, Style.HONOR_COLOR) and honorBar.border ~= nil)
check("filled to the player's honor",
    select(2, honorBar:GetMinMaxValues()) == 1000 and honorBar:GetValue() == 300)
honor.current = 650
Fire("HONOR_XP_UPDATE", "player")
check("and following it", honorBar:GetValue() == 650)
honorBar.scripts.OnEnter(honorBar)
check("the numbers and the honor level on hover",
    GameTooltip:GetLines():find("650 / 1000", 1, true) ~= nil
    and GameTooltip:GetLines():find("Honor level 4", 1, true) ~= nil, GameTooltip:GetLines())
honorBar.scripts.OnLeave(honorBar)
main.pendingBarToShowIndex = HONOR
main:ApplyPendingBarToShow()
check("the game's honor bar faded out like its XP bar",
    main.bars[HONOR].alpha == 0 and main.BarFrameTexture.alpha == 0)
xp.canShow = false
Fire("PLAYER_LEVEL_UP", 60)
check("at the level cap it takes the XP bar's place",
    not bar:IsShown() and honorBar:IsShown() and honorBar.points[3] == "BOTTOMLEFT"
    and honorBar.points[5] == 0)
xp.canShow, honor.canShow = true, false
Fire("ZONE_CHANGED_NEW_AREA")
check("and gone again when the game would hide its own", not honorBar:IsShown() and bar:IsShown())
main.pendingBarToShowIndex = XP
main:ApplyPendingBarToShow()

-- A zone change let the game's bar through beside the addon's. Whatever the
-- path, the bar being shown, or the game sorting its bars out again, fades it.
local xpBar = main.bars[XP]
xpBar.alpha = 1
for _, hook in ipairs(xpBar.hooks.OnShow or {}) do hook(xpBar) end
check("the game's XP bar is faded the moment it is shown, whatever showed it",
    xpBar.alpha == 0)
xpBar.alpha, main.BarFrameTexture.alpha = 1, 1
StatusTrackingBarManager:UpdateBarsShown()
check("and after the game sorts out its bars - a zone change, a loading screen",
    MainFaded())

NS.Refresh()
check("a refresh keeps the game's faded and this bar up", MainFaded() and bar:IsShown())

check("nothing of the game's was shown, hidden, moved or resized",
    #forbiddenCalls == 0, table.concat(forbiddenCalls, ", "))
local added = {}
for _, frame in ipairs(blizzardObjects) do
    for k in pairs(frame) do
        -- Edit Mode's two opt-outs (DogsForeverUI.HoldEditMode) are the one
        -- exception: plain fields the game keeps for exactly this, read by Edit
        -- Mode alone, set on the pieces the addon takes out of it.
        -- (The game's action bars are the addon's own bars' to take over.)
        if keysBefore[frame] and not keysBefore[frame][k] and not frame.takenOver
           and k ~= "isLocked" and k ~= "defaultHideSelection" then
            table.insert(added, tostring(frame.name) .. "." .. tostring(k))
        end
    end
end
check("and no Lua field was added to a Blizzard frame", #added == 0, table.concat(added, ", "))

Section("resetting it")
DB.barWidth = 999
DogsForeverUI:Reset("xp")
check("a reset puts the defaults back", DB.barWidth == 300 and DB.autoPlaced == true)

Summary()
