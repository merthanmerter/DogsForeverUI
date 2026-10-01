-- The micro menu: in the addon's look, laid out by the addon, placed with the
-- rest of the UI, and out of sight until the mouse is over it.
--
-- THE LOOK (no setting: it is the look, like the action buttons'). Every
-- button is drawn exactly as an action button is (ActionButtons.lua): a
-- SQUARE with the frames' semi-transparent black behind it, the thin bevelled
-- gold border round it, and a square icon filling it, its baked-in edge
-- trimmed off.
--
-- The pictures (ICONS) are, as far as there is one, the one the game itself
-- gives each button's window - its portrait, or the icon of its side tab: the
-- professions window's hammer and axe, the Progress Track window's shield,
-- the group finder's eye, the collections window's Appearances portrait, the
-- Guild & Communities window's portrait, the spellbook's portrait, the shop's. The talents button shows the player's spec (the talent
-- tree with the most points), else the talents window's class icon; the
-- character button the player's portrait; the bag button (BagsBar.lua) the
-- game's own backpack icon. The game's micro menu pictures themselves cannot
-- be drawn this way: on this client each one (UI-HUD-MicroMenu-*-Up) is an
-- atlas with a tall bronze frame baked round a narrow plate, and cut out of it
-- (2026-09-29) the plates stood as thin grey strips inside the squares. What
-- this client does not have falls back to the next in its list, then the
-- question mark, rather than draw solid green.
--
-- The game's own art is made invisible by vertex alpha, not alpha or Hide: the
-- game sets the alpha of some of it itself (the icon on hover, the highlight
-- when a window is open, the alert flash) and shows and hides the rest, but
-- never its vertex colour's alpha - except the guild emblem, coloured with the
-- tabard, which is why it is checked again every frame. The game's button
-- stays: its clicks, its keybinding, its tooltip, its enabled state (a
-- disabled one is at half alpha, as the game has it, and its icon greyed) and
-- the notification badge and latency bar it draws over itself. Its hit box is
-- the square (SetHitRectInsets), so neighbours do not overlap.
--
-- The states, drawn as the action buttons draw theirs, in the square:
--   * the mouse over it: a soft light;
--   * its window open (the game holds the button pushed): the border's gold as
--     a wash, as a checked action button;
--   * an alert (the game flashes FlashBorder: talent points to spend, say):
--     that wash again, flashing with the game's flash.
--
-- THE LAYOUT. One row, PITCH apart, in the game's order with the bag button
-- second, after the character, and the addon's own options button last
-- (OptionsButton.lua) - on the addon's own frame (the holder), which
-- is what is placed. The game lays its buttons out in MicroMenu:Layout (a grid
-- anchored to the menu); a post-hook anchors each one to the holder instead,
-- right after, every time - so a button the game shows or hides later closes
-- up the row as the game's own layout would. Only positions are set: no
-- layout of the game's is called, no field written on its frames. The menu
-- frame itself stays where Edit Mode puts it, and is taken out of Edit Mode
-- (HoldEditMode) since the addon places it now.
--
-- When the game lends the menu to another bar (OverrideMicroMenuPosition: a
-- vehicle's bar, in one row or two) the holder goes where the game put the
-- menu, in as many rows as the game asked for.
--
-- THE PLACE. Unlock UI shows the holder in the addon's placement look to
-- drag; Positions has its X and Y. Until the player places it, it sits where
-- the game's menu sits - bottom edges level, and centred on the game's menu's
-- centre, so the row, one button longer than the game's with the bag in it,
-- grows evenly both ways (kept on screen).
--
-- MOUSEOVER ("Micro Menu" under Auto-hide). The whole menu is transparent
-- until the mouse is over the row, then fades in, and fades out once the mouse
-- has been gone for the bars' "Hide after" - exactly as an auto-hidden action
-- bar (NS.Fade in Menus.lua). It is only the menu's alpha, which Blizzard
-- never sets (it sets its buttons', to 1 or 0.5), so its buttons still work.
-- Nothing in it is protected, so this works in combat too. It shows while the
-- UI is unlocked.

local Micro = {}
DogsForeverUI.Menus.MicroMenu = Micro

do -- private scope

    local NS = DogsForeverUI.Menus
    local Style = DogsForeverUI.Style

    Micro.SQUARE = 28             -- a button's square, in the menu's units
    Micro.GAP = 4                 -- between two squares
    Micro.PITCH = Micro.SQUARE + Micro.GAP
    -- The game's button (MainMenuBarMicroButton, Blizzard_MicroMenu\Mainline).
    local GAME_WIDTH, GAME_HEIGHT = 32, 40

    -- The portrait is a picture of a face, not an icon: zoomed in on it. So
    -- are the round portrait pictures some windows wear, past their rim.
    local PORTRAIT_CROP = 0.15
    local ROUND_CROP = 0.14

    local ICON = "Interface\\Icons\\"
    Micro.FALLBACK_ICON = ICON .. "INV_Misc_QuestionMark"
    Micro.PORTRAIT = "portrait"

    -- Live pictures, worked out when asked (see ICONS). Each answers a source,
    -- or nil when it has nothing to show yet.

    -- The spellbook window's own portrait: the General skill line's icon
    -- (Blizzard_PlayerSpells\Camelot\Blizzard_PlayerSpellsFrame.lua,
    -- SetSpellBookPortrait). Known once the spells are.
    function Micro.SpellbookIcon()
        if not (C_SpellBook and C_SpellBook.GetSpellBookSkillLineInfo
                and Enum and Enum.SpellBookSkillLineIndex) then
            return nil
        end
        local ok, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo,
            Enum.SpellBookSkillLineIndex.General)
        return ok and info and info.iconID or nil
    end

    -- THE PLAYER'S SPEC, for the talents button. On this client the talents
    -- are one trait tree split in the classic three (Blizzard_PlayerSpells\
    -- Camelot\ClassTalents: RefreshTreeHeaders): each is a group of the active
    -- config's tree with its own name, icon and points spent - the headers the
    -- talents window draws. The spec is the tree with the most points (the
    -- first of a tie, in the game's order); with none spent there is no spec.
    -- The active config follows dual spec.
    function Micro.SpecIcon()
        if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits) then return nil end
        local ok, icon = pcall(function()
            local configID = C_ClassTalents.GetActiveConfigID()
            local config = configID and C_Traits.GetConfigInfo(configID)
            local treeID = config and config.treeIDs and config.treeIDs[1]
            if not treeID then return nil end
            local trees = C_Traits.GetGroupDisplayInfoByTreeID(treeID) or {}
            local groupIDs = {}
            for i, tree in ipairs(trees) do groupIDs[i] = tree.groupID end
            local spent = {}
            for _, group in ipairs(C_Traits.GetGroupCurrencyInfo(configID, groupIDs) or {}) do
                local currency = group.currencyInfos and group.currencyInfos[1]
                spent[group.traitNodeGroupID] = currency and currency.spent or 0
            end
            local best, most = nil, 0
            for _, tree in ipairs(trees) do
                local points = spent[tree.groupID] or 0
                if points > most then best, most = tree, points end
            end
            return best and best.icon
        end)
        if ok then return icon end
    end

    -- The talents window's own portrait without a spec: the class's round
    -- icon, cut from the class sheet (PortraitFrameMixin:SetPortraitToClassIcon).
    function Micro.ClassIcon()
        if type(UnitClass) ~= "function" or type(CLASS_ICON_TCOORDS) ~= "table" then return nil end
        local _, class = UnitClass("player")
        local coords = class and CLASS_ICON_TCOORDS[class]
        if not coords then return nil end
        return { file = "Interface/TargetingFrame/UI-Classes-Circles", coords = coords,
                 crop = ROUND_CROP }
    end

    -- The guild's tabard, as the Guild & Communities window shows it with the
    -- guild picked (CommunitiesFrameMixin:UpdatePortrait): only in a guild
    -- whose tabard has been designed. Drawn by Show as the tabard's colour
    -- filling the square and the emblem on it.
    function Micro.GuildTabard()
        if type(IsInGuild) ~= "function" or not IsInGuild() then return nil end
        if not (C_GuildInfo and C_GuildInfo.GetGuildTabardInfo) then return nil end
        local ok, tabard = pcall(C_GuildInfo.GetGuildTabardInfo, "player")
        if not (ok and type(tabard) == "table" and tabard.emblemFileID) then return nil end
        return { tabard = tabard }
    end

    -- The Looking For Group window's first side tab: its eye. That window is
    -- loaded only when first opened (Blizzard_GroupFinder_VanillaStyle is load
    -- on demand), so its icon is read off the tab once it is there, and kept
    -- in the saved settings so the next session starts with it.
    function Micro.GroupFinderIcon()
        local frame = _G.LFGParentFrame
        local tab = type(frame) == "table" and frame.ListingTab
        local icon
        if type(tab) == "table" then
            if type(tab.Icon) == "table" and type(tab.Icon.GetTexture) == "function" then
                local ok, texture = pcall(tab.Icon.GetTexture, tab.Icon)
                if ok then icon = texture end
            end
            icon = icon or tab.iconTexture
        end
        local db = NS.db
        if icon then
            db.groupFinderIcon = icon
            return icon
        end
        return db.groupFinderIcon or nil
    end

    -- One list per button, by the game's name for it, tried in order: the
    -- first the client has is shown. Each is, as far as there is one, the
    -- picture the game itself gives that window - its portrait or the icon of
    -- its side tab - and after it the nearest plain icon. A source is:
    --   "path"                          an icon file
    --   { atlas = name }                an atlas, at its own proportions
    --   { file = path, crop = n }       a file trimmed by its own amount
    --   { file = path, coords = {...} } a picture cut from a sheet
    --   { file = path, own = true }     a file of the addon's own, which the
    --                                   client's file list does not know
    --   a function                      one of the live pictures above
    Micro.ICONS = {
        CharacterMicroButton    = Micro.PORTRAIT,
        ProfessionMicroButton   = {    -- the professions window's portrait and tab
            "Interface/ICONS/INV_SideTab_Professions_c60", ICON .. "Trade_BlackSmithing",
        },
        PlayerSpellsMicroButton = { Micro.SpellbookIcon, ICON .. "INV_Misc_Book_09" },
        SpellbookMicroButton    = { Micro.SpellbookIcon, ICON .. "INV_Misc_Book_09" },
        TalentMicroButton       = {    -- the spec, else the talents window's class icon
            Micro.SpecIcon, Micro.ClassIcon, ICON .. "Ability_Marksmanship",
        },
        AchievementMicroButton  = { ICON .. "Achievement_General" },
        LegacyMicroButton       = {    -- the Progress Track window's portrait
            { atlas = "Legacy-up-c60" }, ICON .. "INV_Shield_06",
        },
        QuestLogMicroButton     = {    -- the quest log's portrait
            { file = "Interface\\QuestFrame\\UI-QuestLog-BookIcon", crop = ROUND_CROP },
            ICON .. "INV_Misc_Note_01",
        },
        HousingMicroButton      = { ICON .. "INV_Misc_Key_03" },
        GuildMicroButton        = {    -- the Guild & Communities window's portrait:
            Micro.GuildTabard,         -- the guild's tabard in a guild, else its own
            ICON .. "achievement_guildperk_havegroup willtravel",
            "Interface/ICONS/INV_Shirt_GuildTabard_01",
        },
        LFDMicroButton          = {    -- the group finder's eye, else a group
            Micro.GroupFinderIcon, ICON .. "INV_Misc_GroupLooking",
            ICON .. "INV_Misc_GroupNeedMore",
        },
        CollectionsMicroButton  = {    -- the collections window's Appearances portrait
            ICON .. "inv_chest_cloth_17",
            "Interface/ICONS/INV_Horse3Saddle008_Chestnut", ICON .. "Ability_Mount_RidingHorse",
        },
        EJMicroButton           = {    -- the adventure guide's portrait
            { file = "Interface\\EncounterJournal\\UI-EJ-PortraitIcon", crop = ROUND_CROP },
            ICON .. "INV_Misc_Book_11",
        },
        HelpMicroButton         = { ICON .. "INV_Misc_QuestionMark" },
        StoreMicroButton        = { ICON .. "UI_Shop", ICON .. "WoW_Store" },  -- the shop's portrait
        MainMenuMicroButton     = { ICON .. "INV_Misc_QuestionMark" },         -- the red "?"
    }

    -- The game's art on a button, made invisible (see above).
    local ART = {
        "Background", "PushedBackground", "Shadow", "PushedShadow", "Portrait",
        "FlashBorder", "FlashContent", "Emblem", "HighlightEmblem",
    }
    local STATE_TEXTURES = {
        "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture",
    }

    Micro.parts = setmetatable({}, { __mode = "k" }) -- button -> what was made for it

    ---------------------------------------------------------------------------
    -- The holder: the row's place.

    local holder = CreateFrame("Frame", "DogsForeverUIMicroMenu", UIParent)
    holder:SetFrameStrata("DIALOG")
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    holder:EnableMouse(false)
    holder:SetSize(Micro.PITCH, Micro.SQUARE)
    holder.bg = holder:CreateTexture(nil, "BACKGROUND")
    holder.bg:SetAllPoints(holder)
    holder.border = Style.AddBorder(holder)
    holder.labels = Style.AddPlacementLabels(holder)
    Micro.holder = holder

    ---------------------------------------------------------------------------
    -- The look.

    local function Invisible(region)
        if type(region) ~= "table" or type(region.SetVertexColor) ~= "function" then return end
        local _, _, _, a = region:GetVertexColor()
        if a ~= 0 then region:SetVertexColor(1, 1, 1, 0) end
    end

    local function HideGameArt(button)
        for _, key in ipairs(ART) do Invisible(button[key]) end
        for _, method in ipairs(STATE_TEXTURES) do
            if type(button[method]) == "function" then Invisible(button[method](button)) end
        end
    end

    local function Flat(parent, layer, sublevel, colour)
        local texture = parent:CreateTexture(nil, layer, nil, sublevel)
        texture:SetTexture(Style.FLAT_TEXTURE)
        texture:SetVertexColor(colour[1], colour[2], colour[3], colour[4])
        return texture
    end

    -- Whether this client has the file. The check is only trusted if it knows
    -- the question mark, which every client has.
    local function HasFile(path)
        if type(path) == "number" then return true end   -- a file ID the game gave
        if type(GetFileIDFromPath) ~= "function" then return true end
        local okFallback, fallbackID = pcall(GetFileIDFromPath, Micro.FALLBACK_ICON)
        if not (okFallback and fallbackID) then return true end
        local ok, id = pcall(GetFileIDFromPath, path)
        return ok and id ~= nil
    end

    local function HasAtlas(name)
        if not (C_Texture and C_Texture.GetAtlasInfo) then return true end
        local ok, info = pcall(C_Texture.GetAtlasInfo, name)
        return ok and info ~= nil
    end

    -- The first source in `sources` the client can draw, as { file, crop,
    -- coords } or { atlas }; the question mark if none.
    function Micro.Resolve(sources)
        if type(sources) ~= "table" then sources = { sources } end
        for _, source in ipairs(sources) do
            if type(source) == "function" then
                local ok, live = pcall(source)
                source = ok and live or nil
            end
            if type(source) == "string" or type(source) == "number" then
                if HasFile(source) then return { file = source } end
            elseif type(source) == "table" then
                if source.tabard then
                    return source
                elseif source.atlas then
                    if HasAtlas(source.atlas) then return source end
                elseif source.file and (source.own or HasFile(source.file)) then
                    return source
                end
            end
        end
        return { file = Micro.FALLBACK_ICON }
    end

    local function RGB(colour)
        if type(colour) == "table" and type(colour.GetRGB) == "function" then
            return string.format("%.3f,%.3f,%.3f", colour:GetRGB())
        end
        return ""
    end

    local function Key(source)
        if source.tabard then
            local t = source.tabard
            return table.concat({ "tabard", tostring(t.emblemFileID), tostring(t.emblemStyle),
                RGB(t.backgroundColor), RGB(t.emblemColor) }, ":")
        end
        if source.atlas then return "atlas:" .. source.atlas end
        local c = source.coords
        return tostring(source.file) .. (c and (":" .. table.concat(c, ",")) or "")
    end

    -- Draw one source in a button's square: a file filling it, trimmed; an
    -- atlas centred at its own proportions, as big as the square allows.
    local EMBLEM_HEIGHT = 0.8   -- of the square; the game's own sets its width to 7/8 of it

    -- The tabard's two textures, made the first time a tabard is shown.
    local function Tabard(parts, shown)
        if not parts.tabard then
            if not shown then return end
            local cloth = parts.inner:CreateTexture(nil, "ARTWORK", nil, 1)
            cloth:SetTexture(Style.FLAT_TEXTURE)
            cloth:SetAllPoints(parts.inner)
            local emblem = parts.inner:CreateTexture(nil, "ARTWORK", nil, 2)
            emblem:SetPoint("CENTER", parts.inner, "CENTER", 0, 0)
            parts.tabard = { cloth = cloth, emblem = emblem }
        end
        parts.tabard.cloth:SetShown(shown)
        parts.tabard.emblem:SetShown(shown)
        parts.art:SetShown(not shown)
    end

    local function Show(parts, source)
        local art, size = parts.art, Micro.SQUARE
        if source.tabard then
            -- The game's own colouring and emblem (GuildUtil.lua), on the
            -- addon's textures: the cloth takes the tabard's colour, the
            -- emblem its picture, colour and width.
            Tabard(parts, true)
            local emblem = parts.tabard.emblem
            emblem:SetSize(size * EMBLEM_HEIGHT, size * EMBLEM_HEIGHT)
            if type(SetLargeGuildTabardTextures) == "function" then
                pcall(SetLargeGuildTabardTextures, "player", emblem, parts.tabard.cloth, nil,
                    source.tabard)
            end
            return
        end
        Tabard(parts, false)
        art:ClearAllPoints()
        if source.atlas then
            art:SetAtlas(source.atlas)
            local w, h = 1, 1
            local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(source.atlas)
            if info and (info.width or 0) > 0 and (info.height or 0) > 0 then
                w, h = info.width, info.height
            end
            local scale = size / math.max(w, h)
            art:SetSize(w * scale, h * scale)
            art:SetPoint("CENTER", parts.inner, "CENTER", 0, 0)
        else
            art:SetAllPoints(parts.inner)
            art:SetTexture(source.file)
            local c = source.coords or { 0, 1, 0, 1 }
            local crop = source.crop or NS.ActionButtons.ICON_CROP
            local w, h = c[2] - c[1], c[4] - c[3]
            art:SetTexCoord(c[1] + w * crop, c[2] - w * crop, c[3] + h * crop, c[4] - h * crop)
        end
    end

    local function UpdatePortrait(parts)
        if parts.kind == Micro.PORTRAIT and type(SetPortraitTexture) == "function" then
            SetPortraitTexture(parts.art, "player")
        end
    end

    -- Every button's picture, worked out again: a live one (the spec, a
    -- window's icon) changes as the game does. Drawn only when it changed.
    local function UpdateIcons()
        for _, parts in pairs(Micro.parts) do
            if parts.kind ~= Micro.PORTRAIT then
                local source = Micro.Resolve(parts.kind)
                local key = Key(source)
                if parts.shown ~= key then
                    parts.shown = key
                    Show(parts, source)
                end
            end
        end
    end
    Micro.UpdateIcons = UpdateIcons

    -- When a live picture may have changed: talents spent, refunded or
    -- swapped; the spells known; a window of the game's loaded; a guild
    -- joined, left or its tabard redone.
    local ICON_EVENTS = {
        "TRAIT_CONFIG_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
        "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED",
        "ADDON_LOADED", "PLAYER_GUILD_UPDATE",
    }

    -- The look on one button. `kind`: its sources (see ICONS), or
    -- Micro.PORTRAIT. `isOpen`, optional: whether its window is open, for a
    -- button the game does not hold pushed.
    function Micro.Skin(button, kind, isOpen)
        if Micro.parts[button] then return Micro.parts[button] end
        local Look = NS.ActionButtons
        local size = Micro.SQUARE

        local inner = CreateFrame("Frame", nil, button)
        inner:SetSize(size, size)
        inner:SetPoint("CENTER", button, "CENTER", 0, 0)
        inner:SetFrameLevel(button:GetFrameLevel() + 1)

        local bg = inner:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints(inner)
        Style.SetBackground(bg)

        -- The picture fills the square, as an action button's icon.
        local art = inner:CreateTexture(nil, "ARTWORK")
        art:SetAllPoints(inner)
        if kind == Micro.PORTRAIT then
            art:SetTexCoord(PORTRAIT_CROP, 1 - PORTRAIT_CROP, PORTRAIT_CROP, 1 - PORTRAIT_CROP)
        end

        local hover = Flat(inner, "OVERLAY", 1, Look.HOVER)
        hover:SetAllPoints(inner)
        hover:SetBlendMode("ADD")
        hover:Hide()
        local open = Flat(inner, "OVERLAY", 2, Look.CHECKED)
        open:SetAllPoints(inner)
        open:SetBlendMode("ADD")
        open:Hide()
        local alert = Flat(inner, "OVERLAY", 3, Look.CHECKED)
        alert:SetAllPoints(inner)
        alert:SetBlendMode("ADD")
        alert:SetAlpha(0)

        local border = Style.AddBorder(inner, Look.BORDER, false, Look.BORDER_PIXELS)

        local parts = {
            kind = kind, inner = inner, bg = bg, art = art, border = border,
            hover = hover, open = open, alert = alert, isOpen = isOpen,
        }
        Micro.parts[button] = parts
        if kind == Micro.PORTRAIT then
            UpdatePortrait(parts)
        else
            local source = Micro.Resolve(kind)
            parts.shown = Key(source)
            Show(parts, source)
        end
        return parts
    end

    -- Every frame: the game's art kept invisible (the bag button has none),
    -- and the states.
    local function UpdateButton(button, parts)
        HideGameArt(button)

        local over = parts.inner:IsMouseOver() and button:IsShown() and true or false
        if parts.hover:IsShown() ~= over then parts.hover:SetShown(over) end

        local open
        if parts.isOpen then
            open = parts.isOpen() and true or false
        else
            open = button.GetButtonState and button:GetButtonState() == "PUSHED" or false
        end
        if parts.open:IsShown() ~= open then parts.open:SetShown(open) end

        local enabled = not button.IsEnabled or button:IsEnabled() and true or false
        if parts.enabled ~= enabled then
            parts.enabled = enabled
            parts.art:SetDesaturated(not enabled)
            if parts.tabard then parts.tabard.emblem:SetDesaturated(not enabled) end
        end

        local flash = button.FlashBorder
        local flashing = 0
        if type(flash) == "table" and flash:IsShown() then flashing = flash:GetAlpha() or 0 end
        if parts.flashing ~= flashing then
            parts.flashing = flashing
            parts.alert:SetAlpha(flashing)
        end
    end

    local function SkinMenu(menu)
        for _, child in ipairs({ menu:GetChildren() }) do
            if child.layoutIndex then
                local name = child.GetName and child:GetName()
                Micro.Skin(child, Micro.ICONS[name] or { Micro.FALLBACK_ICON })
            end
        end
    end

    ---------------------------------------------------------------------------
    -- The layout.

    local function Lent(menu)
        local container = _G.MicroMenuContainer
        return container ~= nil and menu:GetParent() ~= container
    end

    -- The addon's own buttons in the row: they are squares already, with no
    -- game art round them.
    local function Own(button)
        return button == NS.BagsBar.button
            or (NS.OptionsButton ~= nil and button == NS.OptionsButton.button)
    end

    -- The buttons in the row, in order: the game's shown ones by layoutIndex,
    -- the bag button after the first, and the addon's options button last.
    function Micro.Row()
        local menu = _G.MicroMenu
        local row = {}
        if not menu then return row end
        for _, child in ipairs({ menu:GetChildren() }) do
            if child.layoutIndex and child:IsShown() then row[#row + 1] = child end
        end
        table.sort(row, function(a, b) return a.layoutIndex < b.layoutIndex end)
        local bag = NS.BagsBar.button
        if bag then table.insert(row, math.min(2, #row + 1), bag) end
        local options = NS.OptionsButton and NS.OptionsButton.button
        if options then row[#row + 1] = options end
        return row
    end

    local laying = false

    local function Layout()
        local menu = _G.MicroMenu
        if laying or not menu then return end
        laying = true

        -- The holder takes the menu's scale, so its units are the buttons'.
        local scale = menu:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if holder:GetScale() ~= scale then holder:SetScale(scale) end

        local row = Micro.Row()
        local rows = (Lent(menu) and menu.isStacked) and 2 or 1
        local columns = math.max(1, math.ceil(#row / rows))
        local pitch, half = Micro.PITCH, Micro.SQUARE / 2
        for index, button in ipairs(row) do
            local column, line = (index - 1) % columns, math.floor((index - 1) / columns)
            button:ClearAllPoints()
            button:SetPoint("CENTER", holder, "TOPLEFT", column * pitch + half, -(line * pitch + half))
            if not Own(button) then
                -- The game's 32x40 button takes the mouse on its square only.
                local x, y = (GAME_WIDTH - Micro.SQUARE) / 2, (GAME_HEIGHT - Micro.SQUARE) / 2
                button:SetHitRectInsets(x, x, y, y)
            end
        end
        holder:SetSize(math.max(1, columns * pitch - Micro.GAP),
            math.max(1, math.min(rows, #row) * pitch - Micro.GAP))
        laying = false
        Micro.Place()
    end
    Micro.Layout = Layout

    ---------------------------------------------------------------------------
    -- The place.

    -- The holder's size in UIParent units.
    local function Size()
        local scale = holder:GetScale()
        return holder:GetWidth() * scale, holder:GetHeight() * scale
    end

    -- Where the game has its menu: bottom edges level, centred on its centre.
    local function DefaultPlace()
        local menu = _G.MicroMenu
        if not menu then return end
        local x = menu:GetCenter()
        local bottom = menu:GetBottom()
        if type(x) ~= "number" or type(bottom) ~= "number" then return end
        local ratio = menu:GetEffectiveScale() / UIParent:GetEffectiveScale()
        x, bottom = x * ratio, bottom * ratio
        local w, h = Size()
        local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
        local left = math.max(0, math.min(x - w / 2, screenW - w))
        local db = NS.db
        db.microLeft = left
        db.microTop = (bottom + h) - screenH
    end

    function Micro.Normalise(db)
        if db.microLeft == nil or db.microTop == nil then
            db.microLeft, db.microTop, db.microPlaced = 0, 0, nil
        end
    end

    function Micro.Place()
        local menu = _G.MicroMenu
        local db = NS.db
        local scale = holder:GetScale()
        holder:ClearAllPoints()
        if menu and Lent(menu) then
            holder:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, 0)
        else
            if not db.microPlaced then DefaultPlace() end
            holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.microLeft / scale, db.microTop / scale)
        end
        holder:SetUserPlaced(false)

        local unlocked = db.unlocked and true or false
        holder:EnableMouse(unlocked)
        holder.bg:SetShown(unlocked)
        holder.border:SetShown(unlocked)
        -- Striped only while it is being placed (its stripes are a texture
        -- of their own, which the background's hiding does not take along).
        Style.SetBackground(holder.bg, unlocked)
        Style.ShowPlacementLabels(holder.labels, holder, "Micro menu", unlocked)
    end

    holder:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and NS.db.unlocked then self:StartMoving() end
    end)
    holder:SetScript("OnMouseUp", function(self, button)
        if DogsForeverUI.RightClickLock(NS, button) then return end
        if button ~= "LeftButton" or not NS.db.unlocked then return end
        self:StopMovingOrSizing()
        local db, scale = NS.db, self:GetScale()
        db.microPlaced = true
        db.microLeft = self:GetLeft() * scale
        db.microTop = self:GetTop() * scale - UIParent:GetHeight()
        Micro.Place()
        DogsForeverUI.RefreshOptions()
    end)

    ---------------------------------------------------------------------------
    -- The fade, and the frame.

    local watcher
    local fade = nil       -- { alpha, away } while the menu is being faded
    local heldEditMode = {}
    local lastParent

    function Micro:Refresh(delta)
        local menu = _G.MicroMenu
        if not menu then return end

        -- Lent to another bar or given back: laid out again where it went.
        if menu:GetParent() ~= lastParent then
            lastParent = menu:GetParent()
            Layout()
        end

        -- The frame and plate, always: they are no part of the look.
        for _, key in ipairs({ "BorderArt", "BackgroundArt" }) do Invisible(menu[key]) end
        for button, parts in pairs(Micro.parts) do UpdateButton(button, parts) end

        if not NS.db.quietMicroMenu then
            -- Switched off: the whole menu, at once.
            if fade then
                fade = nil
                menu:SetAlpha(1)
            end
            return
        end

        -- Starts where it is, as if the mouse had just left it.
        if not fade then fade = { alpha = menu:GetAlpha(), away = 0 } end
        local shown = NS.db.unlocked or NS.MouseOver(holder)
        NS.Fade(menu, fade, shown, delta, NS.ActionBars.Delay())
    end

    function Micro:Apply()
        local menu = _G.MicroMenu
        if not menu then return end

        SkinMenu(menu)
        if _G.MicroMenuContainer then
            DogsForeverUI.HoldEditMode(heldEditMode, _G.MicroMenuContainer, true)
        end

        if not watcher then
            hooksecurefunc(menu, "Layout", Layout)
            watcher = CreateFrame("Frame")
            watcher:SetScript("OnUpdate", function(_, delta) Micro:Refresh(delta) end)
            -- The player's portrait, whenever the game redraws portraits; the
            -- live pictures (ICON_EVENTS); and the game's menu placed by Edit
            -- Mode on entering the world.
            watcher:RegisterEvent("PORTRAITS_UPDATED")
            watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
            watcher:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")
            for _, event in ipairs(ICON_EVENTS) do pcall(watcher.RegisterEvent, watcher, event) end
            watcher:SetScript("OnEvent", function(_, event)
                for _, parts in pairs(Micro.parts) do UpdatePortrait(parts) end
                UpdateIcons()
                if event == "PLAYER_ENTERING_WORLD" then Layout() end
            end)
        end

        UpdateIcons()
        Layout()
        self:Refresh()
    end
end
