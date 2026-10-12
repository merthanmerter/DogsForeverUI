-- The Menus module: a micro menu in the addon's look, in one row with a bag
-- button second, placed with the UI and shown only under the mouse; the bag
-- bar gone until a bag is open; and action bars that auto-hide.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

-- What every Blizzard object held before the addon loaded, so a field it
-- added to one shows up.
local keysBefore = {}
for _, frame in ipairs(blizzardObjects) do
    local keys = {}
    for k in pairs(frame) do keys[k] = true end
    keysBefore[frame] = keys
end

LoadAddon()
Fire("ADDON_LOADED", "DogsForeverUI")

Section("before login nothing is touched")
check("micro menu frame still drawn", MicroMenu.BorderArt.alpha == 1)
check("bag bar still drawn", BagsBar.alpha == 1 and BagsBar.shown == true
    and CharacterBag0Slot.shown == true and #barShowHide == 0)

Fire("VARIABLES_LOADED")
Fire("PLAYER_LOGIN")
Fire("PLAYER_ENTERING_WORLD")

local DB = DogsForeverUI.Menus.db

-- The action bars that auto-hide are the addon's own since 2026-10-03
-- (ActionBars\): under the game's names here, they are those.
local MainActionBar, MultiBarBottomLeft = _G.DogsForeverUIActionBar1, _G.DogsForeverUIActionBar2
local MultiBarBottomRight, MultiBarRight = _G.DogsForeverUIActionBar3, _G.DogsForeverUIActionBar4
local MultiBarLeft, PetActionBar = _G.DogsForeverUIActionBar5, _G.DogsForeverUIActionBarPetBar

local function untouched(button)
    if button.alpha ~= 1 then return false end
    for _, r in ipairs(button.regions) do
        local want = (r == button.highlightTexture) and 0.4 or 1
        if r.alpha ~= want then return false end
    end
    return true
end

local function allDividers(alpha)
    local n, ok = 0, true
    for d in BagsBar.HorizontalDividersPool:EnumerateActive() do
        n = n + 1
        if d.alpha ~= alpha then ok = false end
    end
    return ok and n > 0
end

-- Nothing inside the bag bar is touched: every slot where the game put it,
-- drawn as the game draws it, the bar's own art and dividers as they ship.
local function barInsideUntouched()
    for _, b in ipairs(allBagButtons) do
        if not b.shown or not untouched(b) then return false end
    end
    return BagsBar.BorderArt.alpha == 1 and allDividers(1)
end

-- The micro menu waits the bars' "Hide after" (3s to start) before it fades,
-- so a look at it after the mouse has gone waits that long.
local function Poll() Tick(4) end

local Micro = DogsForeverUI.Menus.MicroMenu
local Look = DogsForeverUI.Menus.ActionButtons
local holder = Micro.holder
local bag = DogsForeverUI.Menus.BagsBar.button
local SQUARE = Micro.SQUARE

-- The mouse coming onto the row, as the game tells it: a button's OnEnter
-- (every hook on it), and the mouse over the row from then on.
local function PointAtMenu()
    mouseOver[holder] = true
    for _, fn in ipairs(QuestLogMicroButton.hooks.OnEnter or {}) do fn(QuestLogMicroButton) end
end

-- The same for a bar (or one of its buttons).
local function PointAt(frame)
    mouseOver[frame] = true
    for _, fn in ipairs(frame.hooks and frame.hooks.OnEnter or {}) do fn(frame) end
end

local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

Section("micro menu: the action buttons' look, with the game's own icons")
check("row frame and plate gone", VertexAlpha(MicroMenu.BorderArt) == 0
    and VertexAlpha(MicroMenu.BackgroundArt) == 0)
check("slightly larger than before: 28 a side", SQUARE == 28)
for _, b in ipairs({ CharacterMicroButton, QuestLogMicroButton, MainMenuMicroButton }) do
    local parts = Micro.parts[b]
    check(b.name .. " has the look", parts ~= nil)
    check(b.name .. ": a square in the middle of the game's button",
        parts.inner.width == SQUARE and parts.inner.height == SQUARE
        and parts.inner.points[1] == "CENTER" and parts.inner.points[2] == b
        and parts.inner.points[4] == 0 and parts.inner.points[5] == 0)
    check(b.name .. ": the frames' background behind it",
        parts.bg.colorTexture[4] == DogsForeverUI.Style.BACKGROUND_COLOR[4]
        and parts.bg.allPointsTo == parts.inner)
    check(b.name .. ": the action buttons' border round it",
        parts.border.spec == Look.BORDER and parts.border.unitPixels == Look.BORDER_PIXELS)
    check(b.name .. ": the icon fills the square, as on an action button",
        parts.art.allPointsTo == parts.inner)
    local art = { b.Background, b.PushedBackground, b.normalTexture, b.pushedTexture,
                  b.disabledTexture, b.highlightTexture, b.FlashBorder, b.FlashContent }
    local gone, alphaKept = true, true
    for _, r in ipairs(art) do
        if VertexAlpha(r) ~= 0 then gone = false end
        if r.alpha ~= 1 then alphaKept = false end
    end
    check(b.name .. ": none of the game's art shows", gone)
    check(b.name .. ": by vertex alpha - the alpha the game sets itself is left to it",
        alphaKept)
end
do
    local parts = Micro.parts[QuestLogMicroButton]
    check("the quest log: its window's round book portrait, trimmed past its rim",
        parts.art.texture == "Interface\\QuestFrame\\UI-QuestLog-BookIcon"
        and near(parts.art.texCoord[1], 0.14) and near(parts.art.texCoord[4], 0.86),
        tostring(parts.art.texture))
    local menuIcon = Micro.parts[MainMenuMicroButton].art
    check("the game menu the red question mark, as the game draws it, trimmed as an icon",
        menuIcon.texture == Micro.ICONS.MainMenuMicroButton[1]
        and menuIcon.texture:find("QuestionMark") ~= nil and menuIcon.texCoord[1] == Look.ICON_CROP)

    -- The windows' own pictures, first; the nearest plain icon when the
    -- client lacks one.
    local function resolved(list) return Micro.Resolve(list) end
    check("professions: the professions window's hammer and axe",
        resolved(Micro.ICONS.ProfessionMicroButton).file == "Interface/ICONS/INV_SideTab_Professions_c60")
    missingFiles["Interface/ICONS/INV_SideTab_Professions_c60"] = true
    check("without it, the next in the list",
        resolved(Micro.ICONS.ProfessionMicroButton).file:find("Trade_BlackSmithing") ~= nil)
    missingFiles["Interface/ICONS/INV_SideTab_Professions_c60"] = nil
    check("collections: the collections window's Appearances portrait",
        resolved(Micro.ICONS.CollectionsMicroButton).file == "Interface\\Icons\\inv_chest_cloth_17")
    check("guild: the Guild & Communities window's portrait",
        resolved(Micro.ICONS.GuildMicroButton).file
            == "Interface\\Icons\\achievement_guildperk_havegroup willtravel")

    -- In a guild: its tabard, drawn by the game's own function on the
    -- addon's textures.
    local function colour(r, g, b) return { GetRGB = function() return r, g, b end } end
    local tabardCalls = {}
    SetLargeGuildTabardTextures = function(unit, emblem, background, border, data)
        tabardCalls[#tabardCalls + 1] = { unit = unit, emblem = emblem, background = background,
                                          border = border, data = data }
        background:SetVertexColor(data.backgroundColor:GetRGB())
        emblem:SetTexture("Interface\\GuildFrame\\GuildEmblemsLG_01")
        emblem:SetWidth(emblem:GetHeight() * 7 / 8)
    end
    local inGuild, tabard = false, {
        emblemFileID = 4001, emblemStyle = 12,
        backgroundColor = colour(0.5, 0.1, 0.1), borderColor = colour(0, 0, 0),
        emblemColor = colour(1, 1, 1),
    }
    IsInGuild = function() return inGuild end
    C_GuildInfo = { GetGuildTabardInfo = function() return tabard end }
    local guild = Micro.Skin(CreateFrame("Button", nil, UIParent), Micro.ICONS.GuildMicroButton)
    check("not in a guild: the window's own portrait", guild.art.shown ~= false
        and guild.art.texture:find("havegroup") ~= nil and guild.tabard == nil)
    inGuild = true
    Fire("PLAYER_GUILD_UPDATE", "player")
    local call = tabardCalls[#tabardCalls]
    check("in a guild: the tabard, by the game's own function",
        call ~= nil and call.unit == "player" and call.data == tabard
        and call.emblem == guild.tabard.emblem and call.background == guild.tabard.cloth
        and call.border == nil)
    check("the cloth fills the square in the tabard's colour",
        guild.tabard.cloth.allPointsTo == guild.inner and guild.tabard.cloth.shown
        and guild.tabard.cloth.vertexColor[1] == 0.5)
    check("the emblem centred on it, the game's width for it",
        guild.tabard.emblem.points[1] == "CENTER" and guild.tabard.emblem.shown
        and near(guild.tabard.emblem.height, SQUARE * 0.8)
        and near(guild.tabard.emblem.width, SQUARE * 0.8 * 7 / 8))
    check("and the portrait hidden under it", guild.art.shown == false)
    local before = #tabardCalls
    Fire("PLAYER_GUILD_UPDATE", "player")
    check("the same tabard is not drawn again", #tabardCalls == before)
    tabard.emblemStyle = 13
    Fire("PLAYER_GUILD_UPDATE", "player")
    check("a redone tabard is", #tabardCalls == before + 1)
    tabard.emblemFileID = nil
    Fire("PLAYER_GUILD_UPDATE", "player")
    check("a tabard never designed: the window's portrait",
        guild.art.shown and not guild.tabard.cloth.shown and not guild.tabard.emblem.shown)
    tabard.emblemFileID = 4001
    inGuild = false
    Fire("PLAYER_GUILD_UPDATE", "player")
    check("leaving the guild: the portrait again",
        guild.art.shown and guild.art.texture:find("havegroup") ~= nil
        and not guild.tabard.cloth.shown)
    IsInGuild, C_GuildInfo, SetLargeGuildTabardTextures = nil, nil, nil
    check("the shop: the shop window's portrait",
        resolved(Micro.ICONS.StoreMicroButton).file:find("UI_Shop") ~= nil)

    -- Legacy: the Progress Track window's portrait, an atlas taller than wide.
    atlases["Legacy-up-c60"] = { width = 45, height = 62 }
    local legacy = Micro.Skin(CreateFrame("Button", nil, UIParent), Micro.ICONS.LegacyMicroButton)
    check("Legacy: the Progress Track window's shield, centred at its own proportions",
        legacy.art.atlas == "Legacy-up-c60" and near(legacy.art.height, SQUARE)
        and near(legacy.art.width, SQUARE * 45 / 62) and legacy.art.points[1] == "CENTER"
        and legacy.art.points[2] == legacy.inner)
    atlases["Legacy-up-c60"] = nil
    check("an atlas the client lacks: the next in the list",
        resolved(Micro.ICONS.LegacyMicroButton).file ~= nil)

    -- The spellbook: its window's portrait, the General skill line's icon.
    local savedBook, savedEnum = C_SpellBook, Enum.SpellBookSkillLineIndex
    C_SpellBook = { GetSpellBookSkillLineInfo = function(index)
        if index == 1 then return { iconID = 777 } end
    end }
    Enum.SpellBookSkillLineIndex = { General = 1 }
    check("the spellbook: its window's portrait",
        resolved(Micro.ICONS.SpellbookMicroButton).file == 777)
    C_SpellBook, Enum.SpellBookSkillLineIndex = savedBook, savedEnum
    check("before the spells are known: a book", resolved(Micro.ICONS.SpellbookMicroButton).file
        :find("Book") ~= nil)

    -- The talents button: the player's spec, the tree with the most points;
    -- without one, the talents window's own class icon.
    local talents = Micro.parts[TalentMicroButton]
    local BULLSEYE = Micro.ICONS.TalentMicroButton[3]
    check("no class icon to be had, no points: the bullseye",
        talents.art.texture == BULLSEYE, tostring(talents.art.texture))
    local _, class = UnitClass("player")
    CLASS_ICON_TCOORDS = { [class or "WARRIOR"] = { 0, 0.25, 0, 0.25 } }
    Fire("PLAYER_TALENT_UPDATE")
    check("no points spent: the talents window's class icon, cut from the class sheet",
        talents.art.texture == "Interface/TargetingFrame/UI-Classes-Circles"
        and talents.art.texCoord[1] > 0 and talents.art.texCoord[2] < 0.25,
        tostring(talents.art.texture))
    CLASS_ICON_TCOORDS = nil
    Fire("PLAYER_TALENT_UPDATE")
    talentTrees[2].spent, talentTrees[3].spent = 31, 5
    Fire("TRAIT_CONFIG_UPDATED", talentConfigID)
    check("points spent: the icon of the tree with the most", talents.art.texture == 1002,
        tostring(talents.art.texture))
    talentTrees[3].spent = 40
    Fire("TRAIT_TREE_CURRENCY_INFO_UPDATED", 55)
    check("followed when the points move", talents.art.texture == 1003)
    talentTrees[1].spent = 40
    Fire("PLAYER_TALENT_UPDATE")
    check("a tie: the first tree in the game's order", talents.art.texture == 1001)
    -- The other spec group of dual spec: its own config, nothing spent there.
    talentConfigID = 8
    for _, tree in ipairs(talentTrees) do tree.spent = 0 end
    Fire("ACTIVE_TALENT_GROUP_CHANGED", 2, 1)
    check("the other spec of dual spec, with no points: back to the fallback",
        talents.art.texture == BULLSEYE)
    talentConfigID = nil  -- no talents yet (under level ten)
    Fire("PLAYER_TALENT_UPDATE")
    check("no talents at all: the fallback, no error", talents.art.texture == BULLSEYE)
    talentConfigID = 7
    for _, tree in ipairs(talentTrees) do tree.spent = 0 end
    Fire("PLAYER_TALENT_UPDATE")

    -- The group finder: its window's eye, read off its first side tab once
    -- the game has loaded it (it loads on first opening), and remembered.
    local lfd = Micro.Skin(CreateFrame("Button", nil, UIParent), Micro.ICONS.LFDMicroButton)
    check("before its window has ever loaded: a group of people",
        lfd.art.texture:find("GroupLooking") ~= nil, tostring(lfd.art.texture))
    local tabIcon = CreateFrame("Frame"):CreateTexture()
    tabIcon.GetTexture = function() return 5550001 end
    LFGParentFrame = { ListingTab = { Icon = tabIcon } }
    Fire("ADDON_LOADED", "Blizzard_GroupFinder_VanillaStyle")
    check("once it loads: the eye off its first tab", lfd.art.texture == 5550001,
        tostring(lfd.art.texture))
    check("remembered for the next session", DB.groupFinderIcon == 5550001)
    LFGParentFrame = nil
    Fire("PLAYER_ENTERING_WORLD")
    check("so a session where the window has not loaded still has it",
        lfd.art.texture == 5550001)

    local me = Micro.parts[CharacterMicroButton]
    check("the character button: the player's portrait, zoomed in, filling the square",
        me.art.portraitOf == "player" and me.art.texCoord[1] > Look.ICON_CROP
        and me.art.allPointsTo == me.inner)
    local before = me.art.portraitDraws
    Fire("UNIT_PORTRAIT_UPDATE", "player")
    check("drawn again when the game redraws portraits", me.art.portraitDraws > before)
    check("its portrait, rim and shadow gone",
        VertexAlpha(CharacterMicroButton.Portrait) == 0 and VertexAlpha(CharacterMicroButton.Shadow) == 0
        and VertexAlpha(CharacterMicroButton.PushedShadow) == 0)
end
check("the latency bar kept", VertexAlpha(MainMenuMicroButton.MainMenuBarPerformanceBar) == 1
    and MainMenuMicroButton.MainMenuBarPerformanceBar.alpha == 1)

-- A file this client does not have would draw solid green.
missingFiles["Interface\\Icons\\Nope"] = true
do
    local parts = Micro.Skin(CreateFrame("Button", nil, UIParent), "Interface\\Icons\\Nope")
    check("an icon the client lacks falls back to the question mark",
        parts.art.texture == Micro.FALLBACK_ICON)
end
missingFiles["Interface\\Icons\\Nope"] = nil

Section("micro menu: the states, as the action buttons draw them")
do
    local b, parts = QuestLogMicroButton, Micro.parts[QuestLogMicroButton]
    Tick(0)
    check("at rest: no light, no wash", not parts.hover.shown and not parts.open.shown
        and parts.alert.alpha == 0)
    mouseOver[parts.inner] = true
    Tick(0)
    check("the mouse over its square: the soft light", parts.hover.shown)
    mouseOver[parts.inner] = nil
    Tick(0)
    check("gone with the mouse", not parts.hover.shown)
    b.buttonState = "PUSHED"
    Tick(0)
    check("its window open (held pushed): the gold wash", parts.open.shown)
    b.buttonState = nil
    Tick(0)
    check("gone once it closes", not parts.open.shown)
    b.enabled = false
    Tick(0)
    check("disabled: the icon greyed", parts.art.desaturated == true)
    b.enabled = nil
    Tick(0)
    check("enabled again: in colour", parts.art.desaturated == false)
    b.FlashBorder.shown, b.FlashBorder.alpha = true, 0.6
    Tick(0)
    check("an alert flashes the wash with the game's flash", parts.alert.alpha == 0.6)
    b.FlashBorder.shown, b.FlashBorder.alpha = false, 1
    Tick(0)
    check("and stops with it", parts.alert.alpha == 0)
    check("the game's own flash still invisible", VertexAlpha(b.FlashBorder) == 0)

    -- The game colouring its art again (the guild emblem with the tabard).
    b.highlightTexture:SetVertexColor(1, 1, 1, 1)
    Tick(0)
    check("art the game colours again is made invisible again", VertexAlpha(b.highlightTexture) == 0)
end

Section("micro menu: one row, the bag button second")
-- A button's one anchor: the game's buttons keep theirs beside them.
local function anchor(b)
    if microPoints[b] then return microPoints[b][#microPoints[b]] end
    return b.points
end
local function inSlot(b, index, line)
    local p = anchor(b)
    return p ~= nil and p[1] == "CENTER" and p[2] == holder and p[3] == "TOPLEFT"
        and p[4] == (index - 1) * Micro.PITCH + SQUARE / 2
        and p[5] == -((line or 0) * Micro.PITCH + SQUARE / 2)
end
do
    local row = Micro.Row()
    local options = DogsForeverUIOptionsButton
    check("character, bag, then the rest in the game's order, and the addon's options last",
        #row == 6 and row[1] == CharacterMicroButton and row[2] == bag
        and row[3] == TalentMicroButton and row[4] == QuestLogMicroButton
        and row[5] == MainMenuMicroButton and row[6] == options)
    check("each in its place on the row, evenly apart",
        inSlot(CharacterMicroButton, 1) and inSlot(bag, 2) and inSlot(TalentMicroButton, 3)
        and inSlot(QuestLogMicroButton, 4) and inSlot(MainMenuMicroButton, 5) and inSlot(options, 6))
    check("the row's frame is exactly the row: six squares and five gaps",
        holder.width == 6 * Micro.PITCH - Micro.GAP and holder.height == SQUARE,
        holder.width .. "x" .. holder.height)
    check("the options button's mouse is its square, as the bag's",
        microHitRects[options] == nil and microHitRects[bag] == nil)
    local hit = microHitRects[QuestLogMicroButton]
    check("a game button takes the mouse on its square only (32x40 less the insets)",
        hit and hit[1] == 2 and hit[2] == 2 and hit[3] == 6 and hit[4] == 6)

    local before = gameLayouts
    MicroMenu:Layout()
    check("the game laying its grid out again changes nothing",
        gameLayouts == before + 1 and inSlot(QuestLogMicroButton, 4) and inSlot(MainMenuMicroButton, 5))
    QuestLogMicroButton.shown = false
    MicroMenu:Layout()
    check("a button the game hides: the row closes up",
        inSlot(MainMenuMicroButton, 4) and holder.width == 5 * Micro.PITCH - Micro.GAP)
    QuestLogMicroButton.shown = true
    MicroMenu:Layout()
    check("and opens again when it is back", inSlot(QuestLogMicroButton, 4)
        and inSlot(MainMenuMicroButton, 5))

    -- Lent to a vehicle's bar in two rows, as the game asks.
    local vehicleBar = CreateFrame("Frame", nil, UIParent)
    MicroMenu.parentFrame, MicroMenu.isStacked = vehicleBar, true
    Tick(0)
    check("lent in two rows: three and three", inSlot(CharacterMicroButton, 1) and inSlot(bag, 2)
        and inSlot(TalentMicroButton, 3) and inSlot(QuestLogMicroButton, 1, 1)
        and inSlot(MainMenuMicroButton, 2, 1) and inSlot(DogsForeverUIOptionsButton, 3, 1))
    check("where the game put the menu",
        holder.points[1] == "TOPLEFT" and holder.points[2] == MicroMenu)
    MicroMenu.parentFrame, MicroMenu.isStacked = MicroMenuContainer, nil
    Tick(0)
    check("given back: one row again, in its own place", inSlot(QuestLogMicroButton, 4)
        and holder.points[2] == UIParent)
end

Section("micro menu: placed with the rest of the UI")
do
    check("out of Edit Mode: the addon places it now - by calls, no field of it written",
        DogsForeverUI.IsHeld(MicroMenuContainer) and MicroMenuContainer.isLocked == nil
        and MicroMenuContainer.defaultHideSelection == nil)
    -- Until placed: where the game has its menu, bottoms level, centred on it.
    local width = 6 * Micro.PITCH - Micro.GAP
    MicroMenu.center, MicroMenu.bottom = { 1700, 40 }, 20
    DogsForeverUI.Menus.Refresh()
    check("centred on the game's menu with its new width, bottoms level",
        DB.microLeft == 1700 - width / 2 and DB.microTop == 20 + SQUARE - 1080
        and not DB.microPlaced, DB.microLeft .. "," .. DB.microTop)
    check("the row's frame there", holder.points[1] == "TOPLEFT" and holder.points[2] == UIParent
        and holder.points[4] == DB.microLeft and holder.points[5] == DB.microTop)
    MicroMenu.center = { 1900, 40 }
    DogsForeverUI.Menus.Refresh()
    check("kept on screen", DB.microLeft == 1920 - width, DB.microLeft)

    check("locked: no mouse, and nothing drawn of its own",
        not holder.mouseEnabled and holder.bg == nil and holder.border == nil)
    DogsForeverUI.SetUnlocked(true)
    check("the one unlock unlocks it: the buttons as they really look, to be dragged",
        DB.unlocked == true and holder.mouseEnabled and holder.bg == nil)
    Tick(4)
    check("and it shows while unlocked", MicroMenu.alpha == 1)
    holder.scripts.OnMouseDown(holder, "LeftButton")
    holder.left, holder.top = 500, 300
    holder.scripts.OnMouseUp(holder, "LeftButton")
    check("dragged: where it was left, and the player's now",
        DB.microPlaced == true and DB.microLeft == 500 and DB.microTop == 300 - 1080
        and holder.points[4] == 500 and holder.points[5] == 300 - 1080)
    MicroMenu.center = { 100, 40 }
    DogsForeverUI.Menus.Refresh()
    check("the game's menu moving no longer moves it", DB.microLeft == 500)
    pendingTimer = nil
    holder.scripts.OnMouseUp(holder, "RightButton")
    check("a right-click does nothing: still unlocked", DB.unlocked and pendingTimer == nil)
    DogsForeverUI.SetUnlocked(false)
    check("locked: no mouse", not DB.unlocked and not holder.mouseEnabled)
    Poll()
    check("and it hides again", MicroMenu.alpha == 0)

    DogsForeverUI:Reset("menus")
    check("a reset puts it back on the game's menu", not DB.microPlaced
        and DB.microLeft == 100 - width / 2)
    check("and keeps the group finder's remembered icon: it is no setting",
        DB.groupFinderIcon == 5550001)
    MicroMenu.center, MicroMenu.bottom = nil, nil
    DogsForeverUI.Menus.Refresh()
end

Section("bag bar: gone until a bag is open, with no setting")
check("hidden at login, whole", BagsBar.shown == false and barShowHide[1] == "Hide")
check("hidden, not faded", BagsBar.alpha == 1)
check("nothing inside it is shown, hidden or faded: the bar goes as one",
    barInsideUntouched() and #slotShowHide == 0, table.concat(slotShowHide, ","))
check("no switch for it, and the old auto-hide one is gone",
    DB.fadeBagBar == nil and DB.collapseBags == nil)
mouseOver[BagsBar] = true
Tick(0.5)
check("the mouse where it was does not bring it back", BagsBar.shown == false)
mouseOver[BagsBar] = nil
BlizzardSetShown(ContainerFrame1, true)
Tick(0)
check("a bag open brings the whole bar back at once", BagsBar.shown == true)
Tick(4)
check("and keeps it while the bag stays open", BagsBar.shown == true)
BlizzardSetShown(ContainerFrame1, false)
BlizzardSetShown(ContainerFrameCombinedBags, true)
Tick(0)
check("the combined bags window counts too", BagsBar.shown == true)
BlizzardSetShown(ContainerFrameCombinedBags, false)
Tick(0)
check("every bag closed, it goes at once", BagsBar.shown == false)
check("nothing inside it was shown or hidden on the way",
    barInsideUntouched() and #slotShowHide == 0)
BlizzardSetShown(ContainerFrame1, true)
Tick(4)
check("an action bar does not come back for an open bag", MultiBarRight.alpha == 0)
BlizzardSetShown(ContainerFrame1, false)
Tick(0)

EditModeManagerFrame.active = true
EventRegistry:TriggerEvent("EditMode.Enter")
Tick(0)
check("Edit Mode shows it, so it can be placed", BagsBar.shown == true)
EditModeManagerFrame.active = false
EventRegistry:TriggerEvent("EditMode.Exit")
Tick(0)
check("and it goes when Edit Mode closes", BagsBar.shown == false)
local shows = #barShowHide
for _ = 1, 20 do Tick(0.1) end
check("nothing changing, it is not looked at", #barShowHide == shows)

-- A gamepad: the game hides the bar itself, and it is the game's to show.
MainActionBar_InitializeGamepad()
BlizzardSetShown(ContainerFrame1, true)
Tick(0)
check("a bar the game hid is not shown for an open bag", BagsBar.shown == false)
BlizzardSetShown(ContainerFrame1, false)
MainActionBar_InitializeMKB()
Tick(0)
check("the game showing it again with the bags shut, it is hidden again",
    BagsBar.shown == false)

Section("bag bar: in combat")
inCombat = true
BlizzardSetShown(ContainerFrame1, true)
Tick(0)
check("not protected, it shows for a bag opened mid-fight", BagsBar.shown == true)
BlizzardSetShown(ContainerFrame1, false)
Tick(0)
check("and goes", BagsBar.shown == false)
-- Anchoring a protected frame to it in Edit Mode would make it protected.
BagsBar.protected = true
local blockedBefore = #blocked
BlizzardSetShown(ContainerFrame1, true)
Tick(0)
check("protected, it is left alone rather than refused",
    BagsBar.shown == false and #blocked == blockedBefore, table.concat(blocked, ","))
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
Tick(0)
check("and shown once combat ends", BagsBar.shown == true)
BlizzardSetShown(ContainerFrame1, false)
Tick(0)
BagsBar.protected = nil

Section("bag bar: the backpack's icon mask put back after the game dims it")
local function maskCentred()
    local points = MainMenuBarBackpackButton.SquareMask.points
    local p = points[1]
    return #points == 1 and p[1] == "CENTER" and p[2] == MainMenuBarBackpackButton.icon
        and p[3] == "CENTER" and p[4] == 0 and p[5] == 0
end
check("centred on the icon at login, as the template builds it", maskCentred())
MainMenuBarBackpackButton:UpdateItemContextOverlay("standard")
check("dimmed by a bag search, the icon is still cut out whole",
    maskCentred() and MainMenuBarBackpackButton.ItemContextOverlay.shown)
MainMenuBarBackpackButton:UpdateItemContextOverlay(nil)
check("and stays whole once the search is cleared",
    maskCentred() and not MainMenuBarBackpackButton.ItemContextOverlay.shown)

Section("micro menu: invisible until the mouse is over it")
check("its switch is on to start", DB.quietMicroMenu == true)
Poll()
check("with the mouse elsewhere the menu is invisible", MicroMenu.alpha == 0)
check("but its buttons still take the mouse, so pointing at them works",
    CharacterMicroButton.mouse and QuestLogMicroButton.mouse)

-- Faded right out, nothing of it is looked at until the mouse comes.
mouseOver[holder] = true
Tick(0.3)
check("asleep: the mouse there without coming onto a button wakes nothing",
    MicroMenu.alpha == 0)
mouseOver[holder] = nil

-- The mouse over the row: over any button, the bag's too, and the gaps.
PointAtMenu()
Tick(0.3)
check("the mouse over it shows it", MicroMenu.alpha == 1)
mouseOver[holder] = nil
Poll()
check("the mouse leaving hides it again", MicroMenu.alpha == 0)

-- The action bars' fade and their wait: two tenths in, "Hide after" (3s to
-- start), four tenths out.
PointAtMenu()
Tick(0.1)
check("it fades in rather than appearing",
    MicroMenu.alpha > 0 and MicroMenu.alpha < 1, MicroMenu.alpha)
Tick(0.1)
check("until it is fully shown", MicroMenu.alpha == 1, MicroMenu.alpha)
mouseOver[holder] = nil
Tick(2.8)
check("leaving it, it stays for the bars' wait", MicroMenu.alpha == 1)
Tick(0.3)
check("then fades out rather than vanishing",
    MicroMenu.alpha > 0 and MicroMenu.alpha < 1, MicroMenu.alpha)
Tick(0.3)
check("until it is gone", MicroMenu.alpha == 0, MicroMenu.alpha)

Section("micro menu: the bag button")
check("the addon's own button, in the menu", bag ~= nil and bag.parent == MicroMenu)
check("left out of the game's own layout", bag.layoutIndex == nil)
check("just its square", bag.width == SQUARE and bag.height == SQUARE)
local bagParts = Micro.parts[bag]
check("in the micro buttons' look: the game's backpack icon filling the square",
    bagParts ~= nil and bagParts.inner.width == SQUARE
    and bagParts.art.texture == "Interface\\Icons\\ui-hud-actionbar-bag"
    and bagParts.art.allPointsTo == bagParts.inner
    and bagParts.art.texCoord[1] == Look.ICON_CROP and bagParts.border.spec == Look.BORDER)
check("it takes clicks", bag.clicks ~= nil and bag.clicks[1] == "AnyUp")

-- Clicks, as the backpack's.
bagCalls = {}
bag.scripts.OnClick(bag, "LeftButton")
check("a click opens the backpack, as the backpack does", bagCalls[1] == "ToggleBag0"
    and #bagCalls == 1)
bagCalls, cursorItem = {}, true
bag.scripts.OnClick(bag, "LeftButton")
check("with an item on the cursor, the item goes in the backpack instead",
    bagCalls[1] == "PutItemInBackpack" and #bagCalls == 1)
bagCalls, modifiedOpenAll = {}, true
bag.scripts.OnClick(bag, "LeftButton")
check("the open-all-bags modifier opens every bag", bagCalls[1] == "ToggleAllBags"
    and #bagCalls == 1)
bagCalls, modifiedOpenAll, cursorItem = {}, false, true
bag.scripts.OnReceiveDrag(bag)
check("an item dropped on it goes in the backpack", bagCalls[1] == "PutItemInBackpack")
cursorItem = false

bag.scripts.OnEnter(bag)
check("its tooltip: name, keybinding, free slots", GameTooltip.owner == bag
    and GameTooltip:GetLines() == "Backpack (B) | (7 free)", GameTooltip:GetLines())
bag.scripts.OnLeave(bag)
check("gone when the mouse leaves", GameTooltip.shown == false)

check("no wash with the bags shut", bagParts.open.shown == false)
PointAtMenu()
BlizzardSetShown(ContainerFrame1, true)
Tick(0); Tick(0)    -- (the bags looked at the frame after the window opens)
check("the gold wash while a bag is open, as a micro button's open window",
    bagParts.open.shown == true)
BlizzardSetShown(ContainerFrame1, false)
Tick(0); Tick(0)
check("and not once it closes", bagParts.open.shown == false)
mouseOver[holder] = nil
Poll()

Section("micro menu: its auto-hide can be switched off")
DB.quietMicroMenu = false
DogsForeverUI.Menus.Refresh()
check("a plain micro menu is visible with the mouse elsewhere", MicroMenu.alpha == 1)
check("still in the look: that is no setting",
    VertexAlpha(MicroMenu.BorderArt) == 0 and VertexAlpha(QuestLogMicroButton.normalTexture) == 0)
Poll()
check("and the mouse timer leaves it alone", MicroMenu.alpha == 1)
DB.quietMicroMenu = true
DogsForeverUI.Menus.Refresh()
Poll()
check("switched back on, it is quiet again", MicroMenu.alpha == 0)

Section("action bars: 3 to 8 and the quest tracker auto-hide to start, the rest only once ticked")
local Bars = DogsForeverUI.Menus.ActionBars
do
    local want = { fadeActionBar3 = true, fadeActionBar4 = true, fadeActionBar5 = true,
                   fadeActionBar6 = true, fadeActionBar7 = true, fadeActionBar8 = true,
                   fadeObjectives = true, fadeStanceBar = true }
    local right = true
    for _, entry in ipairs(Bars.LIST) do
        if DB[entry.key] ~= (want[entry.key] == true) then right = false end
        if entry.frame == "BagsBar" then right = false end
    end
    check("every action bar has its own switch: 3-8 and stance on, 1, 2 and pet off; the bag bar is not one",
        right and #Bars.LIST == 12)
    local xp = Bars.LIST[#Bars.LIST - 1]
    check("and the addon's XP bar is one more, off to start",
        xp.key == "fadeXPBar" and xp.label == "XP Bar" and xp.frame == "DogsForeverUIXPBar"
        and DB.fadeXPBar == false)
    local objectives = Bars.LIST[#Bars.LIST]
    check("and the quest tracker, on to start",
        objectives.key == "fadeObjectives" and objectives.label == "Objectives"
        and objectives.frame == "ObjectiveTrackerFrame" and DB.fadeObjectives == true)
    Tick(4)
    check("so those hide, and the others are left alone",
        MultiBarRight.alpha == 0 and MultiBarBottomRight.alpha == 0
        and MainActionBar:GetAlpha() == 1 and PetActionBar:GetAlpha() == 1,
        tostring(MultiBarRight.alpha) .. " " .. tostring(MainActionBar.alpha) .. " " .. tostring(PetActionBar.alpha))

    -- The quest tracker: hidden at rest, but kept shown while the quest log
    -- is open (the world map's quest panel on this client).
    ObjectiveTrackerFrame = CreateFrame("Frame", "ObjectiveTrackerFrame", UIParent)
    QuestMapFrame = CreateFrame("Frame", "QuestMapFrame", UIParent)
    QuestMapFrame:Hide()
    Tick(4)
    check("the quest tracker hidden at rest", ObjectiveTrackerFrame:GetAlpha() == 0)
    QuestMapFrame:Show()
    Tick(1)
    check("the quest log open: the quest tracker shown", ObjectiveTrackerFrame:GetAlpha() == 1)
    QuestMapFrame:Hide()
    Tick(4)
    check("the quest log shut: hidden again", ObjectiveTrackerFrame:GetAlpha() == 0)

    -- Saved settings from before the new defaults: all off. Switched on
    -- once, and never again - a bar unticked afterwards stays unticked.
    local old = { fadeActionBar3 = false, fadeActionBar8 = false, fadeActionBar1 = false,
                  fadeObjectives = false }
    Bars.Normalise(old)
    check("older saved settings get the six, the quest tracker and the stance bar switched on, once",
        old.fadeActionBar3 == true and old.fadeActionBar8 == true and old.fadeObjectives == true
        and old.fadeStanceBar == true and old.fadeActionBar1 == false and old.autoHideDefaults == 3)
    old.fadeActionBar3 = false
    old.fadeObjectives = false
    Bars.Normalise(old)
    check("and a bar unticked after that stays unticked",
        old.fadeActionBar3 == false and old.fadeObjectives == false)

    -- Settings already past the first step (the six) get only the second.
    local stepOne = { fadeActionBar3 = false, fadeObjectives = false, autoHideDefaults = 1 }
    Bars.Normalise(stepOne)
    check("settings past the first step get only the quest tracker and the stance bar",
        stepOne.fadeActionBar3 == false and stepOne.fadeObjectives == true
        and stepOne.fadeStanceBar == true and stepOne.autoHideDefaults == 3)
    local stepTwo = { fadeStanceBar = false, fadeObjectives = false, autoHideDefaults = 2 }
    Bars.Normalise(stepTwo)
    check("and settings past the second only the stance bar",
        stepTwo.fadeStanceBar == true and stepTwo.fadeObjectives == false and stepTwo.autoHideDefaults == 3)

    -- The rest of these tests start from nothing opted in.
    for key in pairs(want) do DB[key] = false end
    DogsForeverUI.Menus.Refresh()
    check("unticked, a bar comes straight back", MultiBarRight.alpha == 1
        and MultiBarBottomRight.alpha == 1)
end

Section("action bars: an opted-in bar fades out, and back in under the mouse")
check("it waits three seconds before fading, to start with", DB.fadeOutDelay == 3,
    tostring(DB.fadeOutDelay))
DB.fadeActionBar4 = true
DogsForeverUI.Menus.Refresh()
-- Three seconds' wait, then a fade of four tenths out; two tenths back in.
Tick(2.8)
check("it does not vanish at once: it waits", MultiBarRight.alpha == 1)
Tick(0.3)
check("then fades, not jumps", MultiBarRight.alpha > 0 and MultiBarRight.alpha < 1,
    MultiBarRight.alpha)
Tick(0.3)
check("until it is gone", MultiBarRight.alpha == 0, MultiBarRight.alpha)
check("the bars not opted in are left alone",
    MainActionBar:GetAlpha() == 1 and MultiBarLeft:GetAlpha() == 1)

PointAt(MultiBarRight)
Tick(0.1)
check("the mouse over it fades it in, not all at once",
    MultiBarRight.alpha > 0 and MultiBarRight.alpha < 1, MultiBarRight.alpha)
Tick(0.1)
Tick(0.1)
check("until it is fully shown", MultiBarRight.alpha == 1, MultiBarRight.alpha)

mouseOver[MultiBarRight] = nil
Tick(2.8)
check("leaving it, it stays for the wait", MultiBarRight.alpha == 1)
Tick(0.3)
check("then fades out, at the same speed as ever",
    MultiBarRight.alpha > 0 and MultiBarRight.alpha < 1, MultiBarRight.alpha)
Tick(0.5)
check("until it is gone again", MultiBarRight.alpha == 0, MultiBarRight.alpha)

-- The wait is a setting; the fades are not.
DB.fadeOutDelay = 1
PointAt(MultiBarRight)
Tick(0.1)
check("a shorter wait leaves the fade in as it was",
    MultiBarRight.alpha > 0 and MultiBarRight.alpha < 1, MultiBarRight.alpha)
Tick(0.1)
mouseOver[MultiBarRight] = nil
Tick(0.8)
check("and the bar stays for exactly that long", MultiBarRight.alpha == 1)
Tick(0.3)
check("before it fades", MultiBarRight.alpha > 0 and MultiBarRight.alpha < 1,
    MultiBarRight.alpha)
Tick(1)

-- The micro menu is under Auto-hide too, on the same wait.
PointAtMenu()
Tick(0.3)
mouseOver[holder] = nil
Tick(0.8)
check("the micro menu waits the bars' shorter wait too", MicroMenu.alpha == 1, MicroMenu.alpha)
Tick(0.3)
check("and fades after it", MicroMenu.alpha < 1, MicroMenu.alpha)
Tick(1)
DB.fadeOutDelay = 10

-- The wait is set with a slider up to 3s; a longer one saved by the number
-- box it replaced counts as 3.
PointAt(MultiBarRight)
Tick(0.1)
Tick(0.1)
mouseOver[MultiBarRight] = nil
Tick(2.8)
check("a saved wait over 3s holds the bar for 3s", MultiBarRight.alpha == 1, MultiBarRight.alpha)
Tick(0.3)
check("and no longer", MultiBarRight.alpha > 0 and MultiBarRight.alpha < 1, MultiBarRight.alpha)
Tick(1)
DB.fadeOutDelay = 3

PointAt(MultiBarRight)
Tick(0.1)
mouseOver[MultiBarRight] = nil
Tick(0.1)
check("brushing past it still fades it in part-way, from where it was",
    MultiBarRight.alpha > 0 and MultiBarRight.alpha <= 1)
Tick(4)

Section("action bars: every faded bar shows when it has to")
local paints = 0
local update = Bars.Update
Bars.Update = function(...) paints = paints + 1; return update(...) end
Tick(1)
paints = 0
for _ = 1, 20 do Tick(0.1) end
check("every bar faded out, nothing is looked at", paints == 0, paints)
Bars.Update = update

EditModeManagerFrame.active = true
EventRegistry:TriggerEvent("EditMode.Enter")
Tick(0.5)
check("while Edit Mode is open", MultiBarRight.alpha == 1)
EditModeManagerFrame.active = false
EventRegistry:TriggerEvent("EditMode.Exit")
Tick(4)
check("and fades once it closes", MultiBarRight.alpha == 0)

cursorInfo = "spell"
Fire("CURSOR_CHANGED", false, 1, 0)
Tick(0.5)
check("while a spell is being dragged, so it can be dropped on one", MultiBarRight.alpha == 1)
cursorInfo = nil
Fire("CURSOR_CHANGED", true, 0, 1)
Tick(4)

BlizzardSetShown(PlayerSpellsFrame, true)
Tick(0.5)
check("while the spellbook is open", MultiBarRight.alpha == 1)
Tick(4)
check("and stays while it is", MultiBarRight.alpha == 1)
BlizzardSetShown(PlayerSpellsFrame.SpellBookFrame, false)
PlayerSpellsFrame.TalentsFrame.shown = true
Tick(4)
check("but not for the talents tab of the same window", MultiBarRight.alpha == 0)
BlizzardSetShown(PlayerSpellsFrame.SpellBookFrame, true)
PlayerSpellsFrame.TalentsFrame.shown = false
Tick(0.5)
check("back on the spellbook tab, it shows again", MultiBarRight.alpha == 1)
BlizzardSetShown(PlayerSpellsFrame, false)
Tick(4)
check("and fades once the spellbook closes", MultiBarRight.alpha == 0)

BlizzardSetShown(SpellFlyout, true)
Tick(0.5)
check("while a spell flyout is open", MultiBarRight.alpha == 1)
BlizzardSetShown(SpellFlyout, false)
Tick(4)

MultiBarRight.shown = false
PointAt(MultiBarRight)
Tick(0.5)
check("a bar Edit Mode has hidden is not faded in by the mouse", MultiBarRight.alpha == 0)
MultiBarRight.shown = true
mouseOver[MultiBarRight] = nil

Section("action bars: in combat too")
inCombat = true
PointAt(MultiBarRight)
Tick(0.5)
check("alpha is not a protected call, so it fades in mid-fight", MultiBarRight.alpha == 1)
mouseOver[MultiBarRight] = nil
Tick(4)
check("and out", MultiBarRight.alpha == 0)
inCombat = false

Section("action bars: opting out hands the bar back")
DB.fadeActionBar4 = false
DogsForeverUI.Menus.Refresh()
check("it is fully there at once", MultiBarRight.alpha == 1)
Tick(4)
check("and stays", MultiBarRight.alpha == 1)

DB.fadeActionBar1, DB.fadePetBar = true, true
DogsForeverUI.Menus.Refresh()
Tick(4)
check("any bar can be opted in on its own",
    MainActionBar.alpha == 0 and PetActionBar.alpha == 0 and MultiBarBottomLeft:GetAlpha() == 1)
DB.fadeActionBar1, DB.fadePetBar = false, false
DogsForeverUI.Menus.Refresh()
Tick(0)
check("and handed back", MainActionBar.alpha == 1 and PetActionBar.alpha == 1)

Section("missing frames are not an error")
do
    local savedMenu, savedBar = MicroMenu, BagsBar
    MicroMenu, BagsBar = nil, nil
    local savedBar8 = _G.DogsForeverUIActionBar8
    DB.fadeActionBar8 = true
    _G.DogsForeverUIActionBar8 = nil
    local ok, err = pcall(function()
        DogsForeverUI.Menus.MicroMenu:Apply()
        DogsForeverUI.Menus.BagsBar:Apply()
        Tick(1)
    end)
    check("no micro menu, no bag bar, no action bar", ok, err)
    MicroMenu, BagsBar = savedMenu, savedBar
    _G.DogsForeverUIActionBar8 = savedBar8
    DB.fadeActionBar8 = false
    Tick(0)
end

Section("the XP bar auto-hides too, once ticked")
do
    local xp = _G.DogsForeverUIXPBar
    xp:Show()
    xp.alpha = 1
    mouseOver = {}
    Tick(5)
    check("not ticked: left alone", xp.alpha == 1)
    DB.fadeXPBar = true
    DogsForeverUI.Menus.Refresh()
    for _ = 1, 30 do Tick(0.2) end
    check("ticked: it fades away with the mouse elsewhere", xp.alpha == 0)
    DogsForeverUI.SetUnlocked(true)
    for _ = 1, 5 do Tick(0.2) end
    check("shown while the UI is unlocked, to be placed", xp.alpha == 1)
    DogsForeverUI.SetUnlocked(false)
    DB.fadeXPBar = false
    DogsForeverUI.Menus.Refresh()
    Tick(0)
    check("unticked: back as it was", xp.alpha == 1)
end

Section("the bag bar: a piece of Unlock Mode, 75% to start")
do
    local Game = DogsForeverUI.GameFrames
    local entry = DogsForeverUI.Snap.EntryById("bags")
    check("a piece of Unlock Mode, called Bag Bar", entry ~= nil and entry.opts.name == "Bag Bar")
    check("out of the game's Edit Mode boxes", DogsForeverUI.IsHeld(BagsBar))
    check("75% by default, set with the frame's plain SetScale",
        Game.db.bagsSize == 75 and math.abs(BagsBar.scale - 0.75) < 0.001)
    Game.db.bagsSize = 120
    Game.Refresh()
    check("its Size setting applies at once", math.abs(BagsBar.scale - 1.2) < 0.001)
    Game.db.bagsSize = 75
    Game.Ready()        -- (a second after the world is up: first places)
    check("hung from its place, through the plain SetPoint",
        Game.db.bagsPlaced == true and #BagsBar.basePoints == 1
        and BagsBar.basePoints[1][2] == Game.places.bags)
    BagsBar.shown = false
    DogsForeverUI.SetUnlocked(true)
    Tick(0)
    check("shown while Unlock Mode is open, bags shut or not", BagsBar.shown == true)
    DogsForeverUI.SetUnlocked(false)
    Tick(0)
    check("and gone again after", BagsBar.shown == false)
    Game.db.bagsSize = 150
    DogsForeverUI:Reset("gameframes")
    check("a reset: 75% again", Game.db.bagsSize == 75 and math.abs(BagsBar.scale - 0.75) < 0.001)
end

Section("the game's frames were only faded, never driven - but the bag bar, shown and hidden whole")
check("no show/hide/move/layout/script call on a Blizzard frame",
    #forbiddenCalls == 0, table.concat(forbiddenCalls, ", "))
check("the bag bar only shown and hidden", #barShowHide > 0)

local added = {}
for _, frame in ipairs(blizzardObjects) do
    for k in pairs(frame) do
        -- Frames Blizzard made later (fresh dividers) had no "before" to compare.
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
check("no Lua field added to a Blizzard frame", #added == 0, table.concat(added, ", "))

Summary()
