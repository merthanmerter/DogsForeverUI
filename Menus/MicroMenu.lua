-- The micro menu: each button a square in the action buttons' look with its
-- window's own picture, one row laid out by the addon (the bag button second,
-- the options button last), placed with the rest of the UI, and faded out
-- until the mouse is over it.

local Micro = {}
DogsForeverUI.Menus.MicroMenu = Micro

do -- private scope
    local NS = DogsForeverUI.Menus
    local Style = DogsForeverUI.Style
    local Core = DogsForeverUI

    Micro.SQUARE = 28                   -- a button's square, in the menu's units
    Micro.GAP = 4
    Micro.PITCH = Micro.SQUARE + Micro.GAP
    local GAME_WIDTH, GAME_HEIGHT = 32, 40  -- the game's micro button
    local PORTRAIT_CROP = 0.15          -- zoomed in on the face
    local ROUND_CROP = 0.14             -- past a round portrait's rim
    local WHOLE = { 0, 1, 0, 1 }        -- a file's coords, uncut
    local EMBLEM_HEIGHT = 0.8           -- of the square; the game makes it 7/8 as wide
    local IDLE_STEP = 0.1               -- auto-hide off: looked at ten times a second
    local PORTRAIT = "portrait"
    local ICON = "Interface\\Icons\\"
    Micro.FALLBACK_ICON = ICON .. "INV_Misc_QuestionMark"
    local OPTIONS_ICON = { file = Core.MEDIA .. "icon", own = true, crop = 0 }

    -- The game's art on a button and on the menu, made invisible.
    local ART = {
        "Background", "PushedBackground", "Shadow", "PushedShadow", "Portrait",
        "FlashBorder", "FlashContent", "Emblem", "HighlightEmblem",
    }
    local STATE_TEXTURES = {
        "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture",
    }

    -- Live pictures may change as the game does: talents, spells, a window
    -- loaded, a guild joined or its tabard redone.
    local ICON_EVENTS = {
        "TRAIT_CONFIG_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "ACTIVE_TALENT_GROUP_CHANGED",
        "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED", "ADDON_LOADED", "PLAYER_GUILD_UPDATE",
        "PORTRAITS_UPDATED", "PLAYER_ENTERING_WORLD",
    }

    Micro.parts = setmetatable({}, { __mode = "k" }) -- button -> what was made for it

    local Wake, optionsButton

    ---------------------------------------------------------------------------
    -- The pictures. A live one answers a source, or nil; errors are caught
    -- by Resolve (an API missing before its window loads).

    -- The spellbook window's portrait: the General skill line's icon.
    local function SpellbookIcon()
        local info = C_SpellBook.GetSpellBookSkillLineInfo(Enum.SpellBookSkillLineIndex.General)
        return info and info.iconID
    end

    -- The spec: of the talent tree's three groups, the one with the most
    -- points spent (the first of a tie); none spent, none.
    local function SpecIcon()
        local configID = C_ClassTalents.GetActiveConfigID()
        local config = configID and C_Traits.GetConfigInfo(configID)
        local treeID = config and config.treeIDs[1]
        if not treeID then return end
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
    end

    -- The talents window's portrait without a spec: the class's round icon.
    local function ClassIcon()
        local _, class = UnitClass("player")
        local coords = CLASS_ICON_TCOORDS[class]
        if coords then
            return { file = "Interface/TargetingFrame/UI-Classes-Circles", coords = coords, crop = ROUND_CROP }
        end
    end

    -- Retail's talents and spellbook window's portrait: the spec's icon.
    local function PlayerSpellsIcon()
        local specID = PlayerUtil.GetCurrentSpecID()
        return specID and PlayerUtil.GetSpecIconBySpecID(specID)
    end

    -- In a guild with a designed tabard: the tabard, as the guild window shows it.
    local function GuildTabard()
        if not IsInGuild() then return end
        local tabard = C_GuildInfo.GetGuildTabardInfo("player")
        if tabard and tabard.emblemFileID then return { tabard = tabard } end
    end

    -- The group finder's eye, off its window's first tab once that loads
    -- (on demand), and kept for the next session.
    local function GroupFinderIcon()
        local frame = _G.LFGParentFrame
        local tab = frame and frame.ListingTab
        local icon = tab and (tab.Icon and tab.Icon:GetTexture() or tab.iconTexture)
        if icon then NS.db.groupFinderIcon = icon end
        return NS.db.groupFinderIcon or nil
    end

    -- Per button, its window's own picture first, then the nearest plain
    -- icon. A source: an icon path or file ID, { atlas }, { file, crop },
    -- { file, coords } cut from a sheet, { file, own } (the addon's own
    -- file, unknown to the client's list), or a live picture.
    Micro.ICONS = {
        CharacterMicroButton    = PORTRAIT,
        ProfessionMicroButton   = { "Interface/ICONS/INV_SideTab_Professions_c60", ICON .. "Trade_BlackSmithing" },
        PlayerSpellsMicroButton = { PlayerSpellsIcon, ClassIcon, ICON .. "INV_Misc_Book_09" },
        SpellbookMicroButton    = { SpellbookIcon, ICON .. "INV_Misc_Book_09" },
        TalentMicroButton       = { SpecIcon, ClassIcon, ICON .. "Ability_Marksmanship" },
        AchievementMicroButton  = { ICON .. "Achievement_General" },
        LegacyMicroButton       = { { atlas = "Legacy-up-c60" }, ICON .. "INV_Shield_06" },
        QuestLogMicroButton     = {
            { file = "Interface\\QuestFrame\\UI-QuestLog-BookIcon", crop = ROUND_CROP },
            ICON .. "INV_Misc_Note_01",
        },
        HousingMicroButton      = { ICON .. "INV_Misc_Key_03" },
        GuildMicroButton        = {
            GuildTabard, ICON .. "achievement_guildperk_havegroup willtravel",
            "Interface/ICONS/INV_Shirt_GuildTabard_01",
        },
        LFDMicroButton          = {
            GroupFinderIcon, ICON .. "INV_Misc_GroupLooking", ICON .. "INV_Misc_GroupNeedMore",
        },
        CollectionsMicroButton  = {
            ICON .. "inv_chest_cloth_17", "Interface/ICONS/INV_Horse3Saddle008_Chestnut",
            ICON .. "Ability_Mount_RidingHorse",
        },
        EJMicroButton           = {
            { file = "Interface\\EncounterJournal\\UI-EJ-PortraitIcon", crop = ROUND_CROP },
            ICON .. "INV_Misc_Book_11",
        },
        HelpMicroButton         = { ICON .. "INV_Misc_QuestionMark" },
        StoreMicroButton        = { ICON .. "UI_Shop", ICON .. "WoW_Store" },
        MainMenuMicroButton     = { ICON .. "INV_Misc_QuestionMark" },
    }

    -- Whether the client has the file (a missing one draws solid green).
    -- Trusted only once the lookup knows the question mark every client has.
    local trusted = false
    local function HasFile(path)
        if type(path) == "number" then return true end
        trusted = trusted or GetFileIDFromPath(Micro.FALLBACK_ICON) ~= nil
        return not trusted or GetFileIDFromPath(path) ~= nil
    end

    -- The first source the client can draw; else the question mark.
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
                if source.tabard then return source end
                if source.atlas then
                    if C_Texture.GetAtlasInfo(source.atlas) then return source end
                elseif source.own or HasFile(source.file) then
                    return source
                end
            end
        end
        return { file = Micro.FALLBACK_ICON }
    end

    local function RGB(colour) return ("%.3f,%.3f,%.3f"):format(colour:GetRGB()) end

    -- What a source looks like: drawn again only when this changes.
    local function Key(source)
        local t = source.tabard
        if t then
            return table.concat({ "tabard", tostring(t.emblemFileID), tostring(t.emblemStyle),
                RGB(t.backgroundColor), RGB(t.emblemColor) }, ":")
        end
        if source.atlas then return "atlas:" .. source.atlas end
        local c = source.coords
        return tostring(source.file) .. (c and (":" .. table.concat(c, ",")) or "")
    end

    ---------------------------------------------------------------------------
    -- The look.

    -- Vertex alpha, not alpha or Hide: the game sets those itself.
    local function Invisible(region)
        if not region then return end
        local _, _, _, a = region:GetVertexColor()
        if a ~= 0 then region:SetVertexColor(1, 1, 1, 0) end
    end

    local function HideGameArt(button)
        for _, key in ipairs(ART) do Invisible(button[key]) end
        for _, method in ipairs(STATE_TEXTURES) do
            if button[method] then Invisible(button[method](button)) end
        end
    end

    -- The tabard's cloth and emblem, made the first time one is shown.
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

    -- A file fills the square, trimmed; an atlas is centred at its own
    -- proportions; a tabard is coloured and drawn by the game's own function.
    local function Show(parts, source)
        local art, size = parts.art, Micro.SQUARE
        Tabard(parts, source.tabard ~= nil)
        if source.tabard then
            local emblem = parts.tabard.emblem
            emblem:SetSize(size * EMBLEM_HEIGHT, size * EMBLEM_HEIGHT)
            SetLargeGuildTabardTextures("player", emblem, parts.tabard.cloth, nil, source.tabard)
            return
        end
        art:ClearAllPoints()
        if source.atlas then
            art:SetAtlas(source.atlas)
            local info = C_Texture.GetAtlasInfo(source.atlas)
            local scale = size / math.max(info.width, info.height)
            art:SetSize(info.width * scale, info.height * scale)
            art:SetPoint("CENTER", parts.inner, "CENTER", 0, 0)
        else
            art:SetAllPoints(parts.inner)
            art:SetTexture(source.file)
            local c = source.coords or WHOLE
            local crop = source.crop or NS.ActionButtons.ICON_CROP
            local w, h = c[2] - c[1], c[4] - c[3]
            art:SetTexCoord(c[1] + w * crop, c[2] - w * crop, c[3] + h * crop, c[4] - h * crop)
        end
    end

    local function Draw(parts)
        if parts.kind == PORTRAIT then
            SetPortraitTexture(parts.art, "player")
            return
        end
        local source = Micro.Resolve(parts.kind)
        local key = Key(source)
        if parts.shown ~= key then
            parts.shown = key
            Show(parts, source)
        end
    end

    local function UpdateIcons()
        for _, parts in pairs(Micro.parts) do Draw(parts) end
    end

    -- The look on one button. `kind`: its sources (ICONS) or PORTRAIT.
    -- `isOpen`: whether its window is open, for a button the game does not
    -- hold pushed.
    function Micro.Skin(button, kind, isOpen)
        if Micro.parts[button] then return Micro.parts[button] end
        local Look = NS.ActionButtons

        local inner = CreateFrame("Frame", nil, button)
        inner:SetSize(Micro.SQUARE, Micro.SQUARE)
        inner:SetPoint("CENTER", button, "CENTER", 0, 0)
        inner:SetFrameLevel(button:GetFrameLevel() + 1)

        local bg = inner:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints(inner)
        Style.SetBackground(bg)

        local art = inner:CreateTexture(nil, "ARTWORK")
        art:SetAllPoints(inner)
        if kind == PORTRAIT then
            art:SetTexCoord(PORTRAIT_CROP, 1 - PORTRAIT_CROP, PORTRAIT_CROP, 1 - PORTRAIT_CROP)
        end

        -- The states, as the action buttons draw theirs: hover, window open, alert.
        local function Wash(sublevel, colour)
            local texture = inner:CreateTexture(nil, "OVERLAY", nil, sublevel)
            Look.Flat(texture, inner, colour, "ADD")
            return texture
        end
        local hover, open, alert = Wash(1, Look.HOVER), Wash(2, Look.CHECKED), Wash(3, Look.CHECKED)
        hover:Hide()
        open:Hide()
        alert:SetAlpha(0)

        local parts = {
            kind = kind, inner = inner, bg = bg, art = art, isOpen = isOpen,
            hover = hover, open = open, alert = alert,
            border = Style.AddBorder(inner, Look.BORDER, false, Look.BORDER_PIXELS),
        }
        Micro.parts[button] = parts
        -- The mouse coming onto it wakes the menu, after the game's own OnEnter.
        button:HookScript("OnEnter", Wake)
        Draw(parts)
        return parts
    end

    -- An addon button in the row: a child of the menu, so it fades and moves
    -- with it; no layoutIndex, so the game's own layout never counts it.
    function Micro.NewButton(name, sources, isOpen, onClick, onEnter)
        local button = CreateFrame("Button", name, _G.MicroMenu)
        button:SetSize(Micro.SQUARE, Micro.SQUARE)
        button:RegisterForClicks("AnyUp")
        button:SetScript("OnClick", onClick)
        button:SetScript("OnEnter", onEnter)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        Micro.Skin(button, sources, isOpen)
        return button
    end

    -- Every frame it can be seen: the game's art kept invisible (`art`; the
    -- guild emblem is recoloured with the tabard), and the states.
    local function UpdateButton(button, parts, art)
        if art then HideGameArt(button) end

        local over = parts.inner:IsMouseOver() and button:IsShown() and true or false
        if parts.hover:IsShown() ~= over then parts.hover:SetShown(over) end

        local open
        if parts.isOpen then
            open = parts.isOpen() and true or false
        else
            open = button.GetButtonState and button:GetButtonState() == "PUSHED" or false
        end
        if parts.open:IsShown() ~= open then parts.open:SetShown(open) end

        local enabled = button:IsEnabled() and true or false
        if parts.enabled ~= enabled then
            parts.enabled = enabled
            parts.art:SetDesaturated(not enabled)
            if parts.tabard then parts.tabard.emblem:SetDesaturated(not enabled) end
        end

        local flash = button.FlashBorder
        local flashing = flash and flash:IsShown() and flash:GetAlpha() or 0
        if parts.flashing ~= flashing then
            parts.flashing = flashing
            parts.alert:SetAlpha(flashing)
        end
    end

    ---------------------------------------------------------------------------
    -- The layout and the place.

    local holder = CreateFrame("Frame", "DogsForeverUIMicroMenu", UIParent)
    holder:SetFrameStrata("DIALOG")
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    holder:EnableMouse(false)
    holder:SetSize(Micro.PITCH, Micro.SQUARE)
    Micro.holder = holder

    -- Lent to another bar (a vehicle's, OverrideMicroMenuPosition).
    local function Lent(menu)
        return menu:GetParent() ~= _G.MicroMenuContainer
    end

    local function ByLayoutIndex(a, b) return a.layoutIndex < b.layoutIndex end

    -- The game's shown buttons by layoutIndex, the bag button second, the
    -- options button last.
    function Micro.Row()
        local menu = _G.MicroMenu
        local row = {}
        if not menu then return row end
        for _, child in ipairs({ menu:GetChildren() }) do
            if child.layoutIndex and child:IsShown() then row[#row + 1] = child end
        end
        table.sort(row, ByLayoutIndex)
        local bag = NS.BagsBar.button
        if bag then table.insert(row, math.min(2, #row + 1), bag) end
        if optionsButton then row[#row + 1] = optionsButton end
        return row
    end

    -- After the game's own MicroMenu:Layout: each button anchored to the
    -- holder instead, so a button the game shows or hides closes up the row.
    local laying = false
    local function Layout()
        local menu = _G.MicroMenu
        if laying or not menu then return end
        laying = true

        local scale = menu:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if holder:GetScale() ~= scale then holder:SetScale(scale) end

        local row = Micro.Row()
        local rows = (Lent(menu) and menu.isStacked) and 2 or 1
        local columns = math.max(1, math.ceil(#row / rows))
        local pitch, half = Micro.PITCH, Micro.SQUARE / 2
        local insetX, insetY = (GAME_WIDTH - Micro.SQUARE) / 2, (GAME_HEIGHT - Micro.SQUARE) / 2
        for index, button in ipairs(row) do
            local column, line = (index - 1) % columns, math.floor((index - 1) / columns)
            button:ClearAllPoints()
            button:SetPoint("CENTER", holder, "TOPLEFT", column * pitch + half, -(line * pitch + half))
            if button ~= NS.BagsBar.button and button ~= optionsButton then
                -- The game's taller button takes the mouse on its square only.
                button:SetHitRectInsets(insetX, insetX, insetY, insetY)
            end
        end
        holder:SetSize(math.max(1, columns * pitch - Micro.GAP),
            math.max(1, math.min(rows, #row) * pitch - Micro.GAP))
        laying = false
        Micro.Place()
        Wake()
    end

    -- Until placed by the player: on the game's menu, bottoms level, centred.
    local function DefaultPlace()
        local menu = _G.MicroMenu
        if not menu then return end
        local x, bottom = menu:GetCenter(), menu:GetBottom()
        if not (x and bottom) then return end
        local ratio = menu:GetEffectiveScale() / UIParent:GetEffectiveScale()
        x, bottom = x * ratio, bottom * ratio
        local scale = holder:GetScale()
        local w, h = holder:GetWidth() * scale, holder:GetHeight() * scale
        local db = NS.db
        db.microLeft = math.max(0, math.min(x - w / 2, UIParent:GetWidth() - w))
        db.microTop = (bottom + h) - UIParent:GetHeight()
    end

    function Micro.Normalise(db)
        if db.microLeft == nil or db.microTop == nil then
            db.microLeft, db.microTop, db.microPlaced = 0, 0, nil
        end
    end

    function Micro.Place()
        local menu, db = _G.MicroMenu, NS.db
        local scale = holder:GetScale()
        holder:ClearAllPoints()
        if menu and Lent(menu) then
            holder:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, 0)
        else
            if not db.microPlaced then DefaultPlace() end
            holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.microLeft / scale, db.microTop / scale)
        end
        holder:SetUserPlaced(false)
        holder:EnableMouse(db.unlocked)
    end

    local function SavePlace()
        local db, scale = NS.db, holder:GetScale()
        db.microPlaced = true
        db.microLeft = holder:GetLeft() * scale
        db.microTop = holder:GetTop() * scale - UIParent:GetHeight()
        Micro.Place()
        Core.RefreshOptions()
    end
    Core.Snap.Draggable(holder, NS, SavePlace)
    Core.Snap.Register(holder, { save = SavePlace, name = "Micro Menu", id = "micro" })

    ---------------------------------------------------------------------------
    -- The fade. Awake only while something of the menu can be seen: faded
    -- right out it sleeps until the mouse comes onto a button, a setting or
    -- Unlock Mode changes, or the game lends the menu out or takes it back.

    local fade              -- { alpha, away } while the auto-hide is on
    local lastParent
    local sinceStep = 0

    -- Answers whether to stay awake.
    local function Step(delta)
        local menu = _G.MicroMenu
        if not menu then return end
        if menu:GetParent() ~= lastParent then
            lastParent = menu:GetParent()
            Layout()
        end

        local quiet = NS.db.quietMicroMenu
        local shown = quiet and (NS.db.unlocked or NS.MouseOver(holder))
        -- Faded right out, the art waits for the menu to show again.
        local art = not (quiet and fade and fade.alpha == 0 and not shown)
        if art then
            Invisible(menu.BorderArt)
            Invisible(menu.BackgroundArt)
        end
        for button, parts in pairs(Micro.parts) do UpdateButton(button, parts, art) end

        if not quiet then
            if fade then
                fade = nil
                menu:SetAlpha(1)
            end
            return true
        end
        if not fade then fade = { alpha = menu:GetAlpha(), away = 0 } end
        NS.Fade(menu, fade, shown, delta, NS.ActionBars.Delay())
        return shown or fade.alpha > 0
    end

    local watcher
    Wake, watcher = Core.Waker(function(elapsed)
        if not NS.db.quietMicroMenu then
            sinceStep = sinceStep + elapsed
            if sinceStep < IDLE_STEP and not NS.MouseOver(holder) then return true end
            elapsed, sinceStep = sinceStep, 0
        end
        return Step(elapsed)
    end)

    function Micro:Refresh()
        Wake()
        Step(0)
    end

    local function OptionsOpen() return Core.Options ~= nil and Core.Options.IsShown() end

    local function OptionsTooltip(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(Core.TITLE, 1, 1, 1)
        GameTooltip:AddLine("Settings, sizes, positions and profiles.")
        GameTooltip:Show()
    end

    function Micro:Apply()
        local menu = _G.MicroMenu
        if not menu then return end

        -- The only way into the options: no slash command, no Settings entry.
        optionsButton = Micro.NewButton("DogsForeverUIOptionsButton", { OPTIONS_ICON }, OptionsOpen,
            function() Core.Options.Toggle() end, OptionsTooltip)
        for _, child in ipairs({ menu:GetChildren() }) do
            if child.layoutIndex then
                Micro.Skin(child, Micro.ICONS[child:GetName()] or { Micro.FALLBACK_ICON })
            end
        end
        -- The addon places the menu now: out of the game's Edit Mode.
        Core.HoldEditMode(_G.MicroMenuContainer, true)

        hooksecurefunc(menu, "Layout", Layout)
        -- (Taken back from a bar, the menu may not be laid out again.)
        if menu.ResetMicroMenuPosition then hooksecurefunc(menu, "ResetMicroMenuPosition", Wake) end
        watcher:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")
        for _, event in ipairs(ICON_EVENTS) do watcher:RegisterEvent(event) end
        watcher:SetScript("OnEvent", function(_, event)
            UpdateIcons()
            -- Edit Mode has placed the game's menu by now.
            if event == "PLAYER_ENTERING_WORLD" then Layout() end
        end)

        UpdateIcons()
        Layout()
        self:Refresh()
    end
end
