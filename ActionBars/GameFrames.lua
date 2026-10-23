-- MODULE: Game frames  (DogsForeverUI.GameFrames, settings section "gameframes")
-- The game's minimap, chat, extra action button, bag bar and tooltip as Unlock Mode pieces
-- (EllesmereUI's way): each hung from a "place" of ours by its plain Base methods, held out of Edit
-- Mode and hung again after each re-anchor. Also the tooltip's look and the raid frames' box.

local GF = CreateFrame("Frame")
DogsForeverUI.GameFrames = GF

do -- private scope
    local Core = DogsForeverUI
    local Style = Core.Style
    local BORDER = Style.BORDER_INSET
    local KEYS = { "minimap", "chat", "extra", "bags", "tooltip", "classpower" }
    local EXTRA_BUTTON, EXTRA_SIZE = 52, 64     -- the game's extra action button; its frame included
    local CHAT_WINDOW_MIN = 40          -- the messages' own least size
    local RAID_SIZE = { 360, 180 }      -- before a raid was ever seen: 5 x 5 of the game's 72 x 36
    local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }
    local TOOLTIP_TEXT = 12
    local TOOLTIP_BACKGROUND_ALPHA = 0.75

    GF.key = "gameframes"
    GF.title = "Game frames"
    GF.defaults = {
        unlocked = false,
        minimapSize = 0,            -- percent of the game's (0: as the game has it)
        chatWidth = 0,              -- the chat's whole panel (0: as the game has it)
        chatHeight = 0,
        minimapHeaderBelow = true,  -- Minimap\Minimap.lua
        minimapRotate = false,
        bagsSize = Core.RETAIL and 100 or 75,   -- percent; retail's as the game draws it
        raidWidth = 0,              -- what the raid frames took when last seen
        raidHeight = 0,
        -- Their box as the game's Edit Mode last showed it (width 0: never seen).
        raidEditLeft = 0, raidEditTop = 0, raidEditWidth = 0, raidEditHeight = 0,
    }
    GF.placement = {}
    for _, key in ipairs(KEYS) do
        for _, suffix in ipairs({ "Placed", "Left", "Top" }) do GF.placement[key .. suffix] = true end
    end
    GF.SIZE_MIN, GF.SIZE_MAX = 50, 200
    GF.CHAT_MIN, GF.CHAT_MAX = 150, 1000
    GF.TOOLTIP_BAR_HEIGHT = 8
    GF.TOOLTIP_BAR_GAP = 2      -- the health bar under the tooltip's border
    GF.TOOLTIP_FONTS = { "GameTooltipHeaderText", "GameTooltipText", "GameTooltipTextSmall" }

    local ready = false         -- the game has laid its frames out: first places can be taken
    GF.places = {}              -- key -> the frame of ours it hangs from

    local function UI(region)
        return region:GetEffectiveScale() / UIParent:GetEffectiveScale()
    end

    -- A region's rectangle in UIParent's units.
    local function Rect(region)
        if not (region and region.GetLeft) then return end
        local l, r, t, b = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
        if not (l and r and t and b) or r <= l or t <= b then return end
        local k = UI(region)
        return l * k, r * k, t * k, b * k
    end

    local function Put(key)
        local db, place = GF.db, GF.places[key]
        if not (db and place and db[key .. "Placed"]) then return end
        if place:IsProtected() and InCombatLockdown() then return end
        place:ClearAllPoints()
        place:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db[key .. "Left"] or 0, db[key .. "Top"] or 0)
    end

    -- Kept where Unlock Mode dropped it (Core\Snap.lua).
    local function Save(key)
        local l, _, t = Rect(GF.places[key])
        if not l then return end
        local db = GF.db
        db[key .. "Left"], db[key .. "Top"], db[key .. "Placed"] = l, t - GetScreenHeight(), true
        Put(key)
        Core.RefreshOptions()
    end

    -- The place of `key` (named DogsForeverUIPlace<name>), a piece of Unlock Mode; `frame`, the
    -- game's, held out of its Edit Mode.
    local function NewPlace(key, name, frame, opts, size)
        local place = CreateFrame("Frame", "DogsForeverUIPlace" .. name, UIParent)
        place:SetSize(size or 1, size or 1)
        place:SetPoint("CENTER")
        place:EnableMouse(false)
        place:SetClampedToScreen(true)
        GF.places[key] = place
        Core.HoldEditMode(frame, true)
        opts.id, opts.save = key, function() Save(key) end
        Core.Snap.Register(place, opts)
        return place
    end

    -- A place sized as the game frame on it.
    local function FitTo(place, frame)
        local k = UI(frame)
        local w, h = (frame:GetWidth() or 0) * k, (frame:GetHeight() or 0) * k
        if w > 0 and h > 0 then place:SetSize(w, h) end
    end

    -- A game frame anchored with its plain Base methods (Edit Mode's own re-anchor it); x, y in
    -- UIParent's units.
    local function Anchor(frame, point, to, x, y)
        if frame:IsProtected() and InCombatLockdown() then return end
        local k = UI(frame)
        local clear = frame.ClearAllPointsBase or frame.ClearAllPoints
        local set = frame.SetPointBase or frame.SetPoint
        clear(frame)
        set(frame, point, to, point, x / k, y / k)
    end

    -- A game frame hung on its place, once that has one.
    local function Hang(key, frame, point, x, y)
        if not (GF.db and GF.db[key .. "Placed"]) then return end
        Put(key)
        Anchor(frame, point, GF.places[key], x, y)
    end

    -- At once - leaving Edit Mode re-anchors every frame, and put back only a frame later they
    -- were drawn at the game's places in between - and again a frame later, as the game sets
    -- sizes after anchors. A post-hook runs after the game's code, so this taints nothing.
    local function NowAndNext(fn)
        Core.Safely(fn)
        C_Timer.After(0, fn)
    end

    -- Hung again whenever Edit Mode re-anchors it (EllesmereUI's ApplySystemAnchor post-hook),
    -- and after each of the game's other `...` methods.
    local function AfterAnchor(frame, fn, ...)
        for _, method in ipairs({ "ApplySystemAnchor", ... }) do
            if frame[method] then hooksecurefunc(frame, method, function() NowAndNext(fn) end) end
        end
    end

    ---------------------------------------------------------------------------
    -- The minimap: the place over the map, its title band and its border (Minimap\Minimap.lua);
    -- the game's cluster hung so that is where they are.
    ---------------------------------------------------------------------------

    local function MinimapArea()
        local look = Core.Minimap
        local l, r, t, b = Rect(Minimap)
        if not l then return end
        local out = ((look.border and look.border.out) or BORDER) * UI(Minimap)
        l, r, t, b = l - out, r + out, t + out, b - out
        local bl, br, bt, bb = Rect(look.band)
        if bl then l, r, t, b = math.min(l, bl), math.max(r, br), math.max(t, bt), math.min(b, bb) end
        return l, r, t, b
    end

    local function MinimapSize()
        local cluster, db = MinimapCluster, GF.db
        local size = db and tonumber(db.minimapSize) or 0
        if not (cluster and size > 0 and cluster.SetEditModeScale) then return end
        local scale = Clamp(size, GF.SIZE_MIN, GF.SIZE_MAX) / 100
        if cluster.GetEditModeScale and math.abs((cluster:GetEditModeScale() or 1) - scale) < 0.001 then return end
        cluster:SetEditModeScale(scale)
    end

    local function AttachMinimap()
        local place = GF.places.minimap
        if not place then return end
        local l, r, t, b = MinimapArea()
        local cl, _, ct = Rect(MinimapCluster)
        if not (l and cl) then return end
        place:SetSize(r - l, t - b)
        if not (GF.db and GF.db.minimapPlaced) then return end
        Put("minimap")
        if Rect(place) then Anchor(MinimapCluster, "TOPLEFT", place, cl - l, ct - t) end
    end

    -- Rotate Minimap, ours: the rotateMinimap CVar the game's setting writes, set at once and
    -- again whenever the game's layout sets its own. Out of combat.
    local function MinimapRotate()
        local db = GF.db
        if not db or InCombatLockdown() then return end
        local want = db.minimapRotate and "1" or "0"
        if C_CVar.GetCVar("rotateMinimap") ~= want then pcall(C_CVar.SetCVar, "rotateMinimap", want) end
    end

    local function SetUpMinimap()
        local cluster = MinimapCluster
        if not (cluster and Minimap) then return end
        NewPlace("minimap", "Minimap", cluster, {
            name = "Minimap",
            extra = function() return -BORDER, -BORDER, -BORDER, -BORDER end,   -- the area, border included
        })
        -- Hung again as the title moves, the cluster lays itself out or resizes the map's frame
        -- (Rotate Minimap), and when the map is rescaled (after the minimap's own callback
        -- refits its border and title); our size after the game's (a layout applied).
        AfterAnchor(cluster, AttachMinimap, "SetHeaderUnderneath", "Layout", "UpdateMinimapConfig")
        EventRegistry:RegisterCallback("Minimap.OnScaleUpdated", AttachMinimap, GF)
        if cluster.UpdateSystemSettingSize then
            hooksecurefunc(cluster, "UpdateSystemSettingSize", function()
                C_Timer.After(0, function() MinimapSize(); AttachMinimap() end)
            end)
        end
        if cluster.SetRotateMinimap then hooksecurefunc(cluster, "SetRotateMinimap", MinimapRotate) end
    end

    ---------------------------------------------------------------------------
    -- The chat: the place over the main window's top left; the window hung on it. Width and
    -- height are the whole panel's (Chat\ChatLook.lua): the window is that less the room round it.
    ---------------------------------------------------------------------------

    local function PanelRoom()
        local look = Core.Chat.Look
        return 2 * look.PAD + look.SCROLL_ROOM + look.GAP + look.SIDE_WIDTH, 2 * look.PAD + look.TOP_ROOM
    end

    local function ChatSize()
        local chat, db = ChatFrame1, GF.db
        if not (chat and db) then return end
        local width, height = tonumber(db.chatWidth) or 0, tonumber(db.chatHeight) or 0
        if (width <= 0 and height <= 0) or (chat:IsProtected() and InCombatLockdown()) then return end
        local k = UI(chat)
        local roomW, roomH = PanelRoom()
        local w = width > 0 and math.max(CHAT_WINDOW_MIN, Clamp(width, GF.CHAT_MIN, GF.CHAT_MAX) / k - roomW)
            or chat:GetWidth()
        local h = height > 0 and math.max(CHAT_WINDOW_MIN, Clamp(height, GF.CHAT_MIN / 2, GF.CHAT_MAX) / k - roomH)
            or chat:GetHeight()
        if math.abs(chat:GetWidth() - w) > 0.5 or math.abs(chat:GetHeight() - h) > 0.5 then chat:SetSize(w, h) end
    end

    function GF.AttachChat()
        if not GF.places.chat then return end
        ChatSize()
        Hang("chat", ChatFrame1, "TOPLEFT", 0, 0)
    end

    -- The game's chat system writes the window's live anchor into its saved layout right after
    -- it moves or sizes it; a layout naming our place breaks with the addon off. So at that
    -- moment the window hangs from UIParent on the same spot; NowAndNext's next pass re-hangs it.
    local function ChatFromUIParent()
        local l, _, t = Rect(ChatFrame1)
        if l then Anchor(ChatFrame1, "TOPLEFT", UIParent, l, t - UIParent:GetTop()) end
    end

    -- A stored layout still naming a frame of ours (written before ChatFromUIParent): that system
    -- given back the game's default spot, saved as the game itself does (saved layouts only).
    local function MendLayouts()
        local info = C_EditMode.GetLayouts()
        local mended = false
        for _, layout in ipairs(info.layouts) do
            for _, system in ipairs(layout.systems or {}) do
                local to = system.anchorInfo and system.anchorInfo.relativeTo
                if type(to) == "string" and to:find("^DogsForeverUI") then
                    local ok, anchor = pcall(EditModePresetLayoutManager.GetDefaultSystemAnchorInfo,
                        EditModePresetLayoutManager, system.system, system.systemIndex)
                    if ok and type(anchor) == "table" then
                        system.anchorInfo, system.isInDefaultPosition = anchor, true
                        mended = true
                    end
                end
            end
        end
        if mended then C_EditMode.SaveLayouts(info) end
    end
    EventRegistry:RegisterCallback("EditMode.SavedLayouts", MendLayouts, MendLayouts)

    local function SetUpChat()
        local chat = ChatFrame1
        if not chat then return end
        -- What shows: the chat's panel and the tabs' sidebar (Chat\ChatLook.lua), up to the
        -- letters' row over them - or without them the window itself.
        local Panel = Core.Chat.Look.ShownPanel
        NewPlace("chat", "Chat", chat, {
            name = "Chat",
            parts = function()
                local panel, side = Panel()
                return { panel or chat, side }
            end,
            extra = function()
                if not Panel() then return -BORDER, -BORDER, -BORDER, -BORDER end
                return -BORDER, -BORDER, Core.Chat.Look.TOP_ROOM - BORDER, -BORDER
            end,
        })
        for _, method in ipairs({ "ApplySystemAnchor", "UpdateSystemSettingWidth", "UpdateSystemSettingHeight" }) do
            if chat[method] then
                hooksecurefunc(chat, method, function()
                    NowAndNext(GF.AttachChat)
                    pcall(ChatFromUIParent)
                end)
            end
        end
    end

    ---------------------------------------------------------------------------
    -- The extra action button (EllesmereUI's SetupBlizzardMovableFrame): the game's container
    -- centred in a holder of ours, out of the game's managed layout; put back whenever the game
    -- takes it out. Out of combat only (the button is secure).
    ---------------------------------------------------------------------------

    local extraPending = false
    local scaler                -- a frame of ours in the holder, the container's parent: it sizes it

    -- The button's whole scale on screen, of the game's: Action Bar 1's size.
    local function ExtraScale()
        return Core.ActionBars.ButtonSize("bar1") / EXTRA_BUTTON
    end

    local function IntoHolder()
        local container, holder = ExtraAbilityContainer, GF.places.extra
        if not holder then return end
        if InCombatLockdown() then
            extraPending = true
            return
        end
        extraPending = false
        -- (No field written on it - Edit Mode read those, tainted: the SetParent hook below
        -- brings it straight back out of the managed layout.)
        if container.SetIsLayoutFrame then pcall(container.SetIsLayoutFrame, container, false) end
        if container:GetParent() ~= scaler then container:SetParent(scaler) end
        -- The game's own scale (its Edit Mode's size) left on it, undone by ours.
        local game = container:GetScale()
        scaler:SetScale(ExtraScale() / (game and game > 0 and game or 1))
        Anchor(container, "CENTER", scaler, 0, 0)
        local size = EXTRA_SIZE * ExtraScale()
        holder:SetSize(size, size)
    end

    -- Its middle on Action Bar 1's bottom edge, centred under the bar.
    function GF.PlaceExtra()
        local place, db, snap = GF.places.extra, GF.db, Core.Snap
        local entry = snap.EntryById("bar1")
        local bar = entry and snap.Box(entry)
        if not (place and db and bar) then return end
        local w, h = place:GetWidth(), place:GetHeight()
        db.extraLeft, db.extraTop, db.extraPlaced = bar.cx - w / 2, bar.b + h / 2 - GetScreenHeight(), true
        Put("extra")
    end

    -- Square in our frames' border, the icon whole (its baked-in edge cropped, the game's mask
    -- off), its hover and press the hotbars' flat washes (the game's are square rims), its flash
    -- and cooldowns over the whole icon; the game's wide skin art - its effects - drawn behind it
    -- from the bar under it (still centred on the button); its texts over the icon.
    local function ExtraLook()
        local button = ExtraActionButton1
        if not button then return end
        local Buttons, icon = Core.Menus.ActionButtons, button.icon
        local crop = Buttons.ICON_CROP
        if button.IconMask then icon:RemoveMaskTexture(button.IconMask) end
        icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
        icon:ClearAllPoints()
        icon:SetAllPoints(button)
        Style.AddBorder(button)
        Buttons.Flat(button:GetHighlightTexture(), icon, Buttons.HOVER, "ADD")
        Buttons.Flat(button:GetPushedTexture(), icon, Buttons.PUSHED)
        for _, key in ipairs({ "Flash", "cooldown", "chargeCooldown", "lossOfControlCooldown" }) do
            local part = button[key]
            if part then
                part:ClearAllPoints()
                part:SetAllPoints(icon)
            end
        end
        button.style:SetParent(button:GetParent())
        button.HotKey:SetDrawLayer("OVERLAY", 7)
        button.Count:SetDrawLayer("OVERLAY", 7)
    end

    -- Its hotkey: the game's broadcaster no longer hands it the bindings (ActionBars.lua).
    -- Written and drawn as Action Bar 1's: their font, corner and size on screen, whole; its
    -- count at their size too.
    local function ExtraHotkey()
        local button = ExtraActionButton1
        if not button then return end
        local bars = Core.ActionBars
        local scale = bars.ButtonScale("bar1") / ExtraScale()
        button.Count:SetTextScale(scale)
        local hotkey, key = button.HotKey, GetBindingKey("EXTRAACTIONBUTTON1")
        if not (hotkey and key) then return end
        hotkey:SetFontObject(NumberFontNormalSmallGray)
        hotkey:SetTextScale(scale)
        hotkey:SetWidth(0)
        hotkey:ClearAllPoints()
        hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -5, -5)
        hotkey:SetText(bars.KeyText(key))
        hotkey:Show()
    end

    local function SetUpExtra()
        local container = ExtraAbilityContainer
        if not container then return end
        local holder = NewPlace("extra", "ExtraAction", container, { name = "Extra Action Button" }, EXTRA_SIZE)
        scaler = CreateFrame("Frame", nil, holder)
        scaler:SetSize(1, 1)
        scaler:SetPoint("CENTER")
        ExtraLook()
        -- Action Bar 1 resized: the button with it.
        hooksecurefunc(Core.ActionBars, "LayOutAll", function()
            IntoHolder()
            ExtraHotkey()
        end)
        if container.Selection then
            hooksecurefunc(container.Selection, "Show", function(self) self:SetAlpha(0) end)
        end
        -- The game's managed layout reaches it through these: no more.
        container:SetScript("OnShow", nil)
        container:SetScript("OnHide", nil)
        if container.AddFrame then
            hooksecurefunc(container, "AddFrame", function(_, frame)
                if frame and frame.EnableMouse and not InCombatLockdown() then frame:EnableMouse(true) end
                C_Timer.After(0, ExtraHotkey)
            end)
        end
        AfterAnchor(container, IntoHolder)
        hooksecurefunc(container, "Show", function()
            if container:GetParent() ~= scaler then IntoHolder() end
            ExtraHotkey()
        end)
        hooksecurefunc(container, "SetParent", function(_, parent)
            if parent ~= scaler then IntoHolder() end
        end)
        IntoHolder()
    end

    ---------------------------------------------------------------------------
    -- The class resource (EllesmereUI's EUI_ResourceBars_BlizzClassArt): the game's own frame
    -- for the class's points - runes, essence, arcane charges, chi, holy power, soul shards -
    -- centred on a place of ours, on the secondary power's spot to start. The player frame's
    -- managed layout takes it back on every show and as the UI shows again (UpdateFrame): put
    -- back after each, post-hooks. No field is written on it (the game's player frame is live
    -- and would read one tainted); it is never shown or hidden here - the game decides. Rogues'
    -- and cat druids' combo points are the addon's own (Castbar\Rows.lua). Retail: Forever has
    -- none of these frames.
    ---------------------------------------------------------------------------

    local CLASS_FRAMES = {
        DEATHKNIGHT = "RuneFrame", EVOKER = "EssencePlayerFrame", MAGE = "MageArcaneChargesFrame",
        MONK = "MonkHarmonyBarFrame", PALADIN = "PaladinPowerBarFrame", WARLOCK = "WarlockPowerFrame",
    }
    local classPower                -- the game's frame for this class's points, or nil

    local function SeatClassPower()
        local bar, place = classPower, GF.places.classpower
        if not (bar and place) or (bar:IsProtected() and InCombatLockdown()) then return end
        if bar:GetParent() ~= place then bar:SetParent(place) end
        bar:ClearAllPoints()
        bar:SetPoint("CENTER", place, "CENTER", 0, 0)
        FitTo(place, bar)
    end

    -- Its middle on the secondary power's (from that bar's saved place: shown or not).
    function GF.PlaceClassPower()
        local place, db = GF.places.classpower, GF.db
        if not (place and db) then return end
        local castbar, row = Core.Castbar, Core.FiveSecondRule
        local left, width, top = castbar.RowPlace(row)
        local w, h = place:GetWidth(), place:GetHeight()
        db.classpowerLeft = left + (width - w) / 2
        db.classpowerTop = top - (row.db.barHeight - h) / 2
        db.classpowerPlaced = true
        Put("classpower")
    end

    local function SetUpClassPower()
        local name = CLASS_FRAMES[select(2, UnitClass("player")) or ""]
        classPower = name and _G[name]
        local home = classPower and classPower.layoutParent
        if not home then
            classPower = nil
            return
        end
        NewPlace("classpower", "ClassPower", classPower, { name = "Class Resource" })
        classPower:HookScript("OnShow", SeatClassPower)
        if home.UpdateFrame then
            hooksecurefunc(home, "UpdateFrame", function(_, frame)
                if frame == classPower then SeatClassPower() end
            end)
        end
        SeatClassPower()
    end

    ---------------------------------------------------------------------------
    -- The bag bar: hung on a place its size, scaled by our setting with its plain SetScaleBase
    -- (Edit Mode's override re-anchors it). It shows only while a bag is open (Menus\Bags.lua).
    ---------------------------------------------------------------------------

    local function AttachBags()
        local bar, place = BagsBar, GF.places.bags
        if not place then return end
        if not (bar:IsProtected() and InCombatLockdown()) then
            local db = GF.db
            local scale = Clamp(db and tonumber(db.bagsSize) or 100, GF.SIZE_MIN, GF.SIZE_MAX) / 100
            if math.abs((bar:GetScale() or 1) - scale) >= 0.001 then (bar.SetScaleBase or bar.SetScale)(bar, scale) end
        end
        FitTo(place, bar)
        Hang("bags", bar, "TOPLEFT", 0, 0)
    end

    local function SetUpBags()
        local bar = BagsBar
        if not bar then return end
        NewPlace("bags", "Bags", bar, { name = "Bag Bar" })
        -- Our size after the game's (a layout applied); the place resized as the bar is laid out.
        AfterAnchor(bar, AttachBags, "UpdateSystemSettingSize", "Layout")
    end

    ---------------------------------------------------------------------------
    -- The tooltip: its Edit Mode frame (GameTooltipDefaultContainer) hung by its bottom right on our
    -- place, the health bar's room above it. Its look: the game's nine-slice at no opacity, our
    -- background and border, the health bar under it in our fill. Widget calls and post-hooks only.
    ---------------------------------------------------------------------------

    local styledTips = setmetatable({}, { __mode = "k" })

    local function Plain(value) return not issecretvalue(value) and value ~= nil end

    local function NoNineSlice(tip)
        if styledTips[tip] and tip.NineSlice then tip.NineSlice:SetAlpha(0) end
    end

    -- Under the tooltip, clear of its border, as wide as it (inside, it sometimes covered the
    -- last line); no border of its own.
    local function StyleHealthBar(bar, tip)
        if not (bar and bar.SetStatusBarTexture) then return end
        Style.SetBarFill(bar)
        Style.MakeSheen(bar)
        local back = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
        back:SetAllPoints(bar)
        Style.SetBackground(back)
        local below = -(BORDER + GF.TOOLTIP_BAR_GAP)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 0, below)
        bar:SetPoint("TOPRIGHT", tip, "BOTTOMRIGHT", 0, below)
        bar:SetHeight(GF.TOOLTIP_BAR_HEIGHT)
    end

    -- A player's class: from the tooltip's own GUID first, plain even where the unit is secret
    -- (over the game's raid and party frames - EllesmereUI's _resolveTipIdentity), then the unit.
    local function ClassOf(data, unit)
        local guid = type(data) == "table" and data.guid
        if Plain(guid) and GetPlayerInfoByGUID then
            local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
            if ok and Plain(class) and class ~= "" then return class end
        end
        if not Plain(unit) then return end
        local isPlayer = UnitIsPlayer(unit)
        if not (Plain(isPlayer) and isPlayer) then return end
        local _, class = UnitClass(unit)
        if Plain(class) then return class end
    end

    -- A unit's tooltip built (TooltipDataProcessor's post-call): a player's name in class colour;
    -- a class the client keeps secret is left as the game has it.
    local function UnitTooltip(tip, data)
        if not styledTips[tip] or not tip.GetUnit then return end
        local ok, _, unit = pcall(tip.GetUnit, tip)
        if not ok then unit = nil end
        local class = ClassOf(data, unit)
        if not class then return end
        local colour = C_ClassColor.GetClassColor(class) or RAID_CLASS_COLORS[class]
        local name = tip:GetName()
        local line = Plain(name) and _G[name .. "TextLeft1"]
        if colour and line then line:SetTextColor(colour.r, colour.g, colour.b) end
    end

    -- How far the health bar reaches under the tooltip: the tooltip stands that much above its
    -- place, so the bar ends at the place's bottom.
    function GF.TooltipBarRoom()
        return BORDER + GF.TOOLTIP_BAR_GAP + GF.TOOLTIP_BAR_HEIGHT
    end

    -- The game shows its tooltip before a unit's data comes: until a line has text, our backing
    -- and bar are see-through (hiding the tooltip would drop its owner, and the lines with it).
    local SIDES = { "TextLeft", "TextRight" }
    local function HasText(tip)
        local name = tip:GetName()
        local count = tip.NumLines and tip:NumLines() or 0
        if not Plain(name) or not Plain(count) then return true end
        for i = 1, count do
            for _, side in ipairs(SIDES) do
                local line = _G[name .. side .. i]
                local text = line and line:IsShown() and line:GetText()
                if not Plain(text) or (text and text ~= "") then return true end
            end
        end
        return false
    end

    local function ShowBacking(tip)
        local parts = styledTips[tip]
        if not parts then return end
        local ok, filled = pcall(HasText, tip)
        local a = (not ok or filled) and 1 or 0
        parts.back:SetAlpha(a)
        if parts.border then parts.border:SetAlpha(a) end
        if parts.bar then parts.bar:SetAlpha(a) end
    end

    local function StyleTooltip(tip)
        if not (tip and tip.CreateTexture) or styledTips[tip] then return end
        local back = tip:CreateTexture(nil, "BACKGROUND", nil, -8)
        back:SetAllPoints(tip)
        local tone = Style.BACKGROUND_COLOR
        back:SetColorTexture(tone[1], tone[2], tone[3], TOOLTIP_BACKGROUND_ALPHA)
        local parts = { back = back, border = Style.AddBorder(tip) }
        styledTips[tip] = parts
        NoNineSlice(tip)
        tip:HookScript("OnShow", NoNineSlice)
        if tip == GameTooltip then
            parts.bar = tip.StatusBar or GameTooltipStatusBar
            StyleHealthBar(parts.bar, tip)
        end
        -- The game calls Show again each time it has laid the lines out.
        tip:HookScript("OnShow", ShowBacking)
        tip:HookScript("OnSizeChanged", ShowBacking)
        tip:HookScript("OnTooltipCleared", ShowBacking)
        hooksecurefunc(tip, "Show", ShowBacking)
    end

    -- Every tooltip font at TOOLTIP_TEXT, its face kept (ours, from Core\Style.lua).
    local function TooltipFonts()
        for _, name in ipairs(GF.TOOLTIP_FONTS) do
            local font = _G[name]
            if font and font.GetFont then
                local file, size, flags = font:GetFont()
                if file and size ~= TOOLTIP_TEXT then font:SetFont(file, TOOLTIP_TEXT, flags or "") end
            end
        end
    end
    hooksecurefunc("SharedTooltip_SetBackdropStyle", NoNineSlice)

    local function AttachTooltip()
        local place = GF.places.tooltip
        if not place then return end
        FitTo(place, GameTooltipDefaultContainer)
        Hang("tooltip", GameTooltipDefaultContainer, "BOTTOMRIGHT", 0, GF.TooltipBarRoom())
    end

    local function SetUpTooltip()
        for _, name in ipairs(TOOLTIPS) do StyleTooltip(_G[name]) end
        TooltipFonts()
        if TooltipDataProcessor then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tip, data)
                pcall(UnitTooltip, tip, data)
            end)
        end
        local holder = GameTooltipDefaultContainer
        if not holder then return end
        NewPlace("tooltip", "Tooltip", holder, { name = "Tooltip" })
        AfterAnchor(holder, AttachTooltip)
    end

    ---------------------------------------------------------------------------
    -- The raid frames stay the game's; Unlock Mode's handover box over them (Options\Unlock.lua),
    -- outside a raid at the box Edit Mode last drew (Frames\BlizzardFrames.lua) or their last size.
    ---------------------------------------------------------------------------

    local function RaidUsed()
        local container = CompactRaidFrameContainer
        if not (container and container:IsShown() and FlowContainer_GetUsedBounds) then return end
        local ok, w, h = pcall(FlowContainer_GetUsedBounds, container)
        if not ok or type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then return end
        local k = UI(container)
        return w * k, h * k
    end

    local function RememberRaid()
        local db = GF.db
        local w, h = RaidUsed()
        if db and w then db.raidWidth, db.raidHeight = math.floor(w + 0.5), math.floor(h + 0.5) end
    end

    -- Their Edit Mode box (its preview out of a raid), measured while the game's Edit Mode lays them out.
    function GF.RememberEditModeRaid()
        local container, db = CompactRaidFrameContainer, GF.db
        local box = container and container.Selection
        if not (db and box and EditModeManagerFrame) then return end
        if not (Core.Call(EditModeManagerFrame, "IsEditModeActive") and Core.Call(container, "IsVisible")) then return end
        local ok, l, r, t, b = pcall(Rect, box)
        if not (ok and l and r - l > 0 and t - b > 0) then return end
        db.raidEditLeft, db.raidEditTop = l, t
        db.raidEditWidth, db.raidEditHeight = r - l, t - b
    end

    -- Their box while no raid is up, in UIParent's units: left, right, top, bottom.
    function GF.RaidBox()
        local container, db = CompactRaidFrameContainer, GF.db
        local w, h = tonumber(db and db.raidEditWidth) or 0, tonumber(db and db.raidEditHeight) or 0
        if w > 0 and h > 0 then
            local l, t = db.raidEditLeft, db.raidEditTop
            return l, l + w, t, t - h
        end
        if not (container and container.GetLeft) then return end
        local ok, left, top = pcall(function() return container:GetLeft(), container:GetTop() end)
        if not (ok and left and top) then return end
        local k = UI(container)
        left, top = left * k, top * k
        w, h = tonumber(db and db.raidWidth) or 0, tonumber(db and db.raidHeight) or 0
        if w <= 0 or h <= 0 then w, h = RAID_SIZE[1], RAID_SIZE[2] end
        return left, left + w, top, top - h
    end

    local raidFollowed = false
    local function SetUpRaid()
        local container = CompactRaidFrameContainer
        if raidFollowed or not (container and container.HookScript) then return end
        raidFollowed = true
        local function Later() C_Timer.After(0, RememberRaid) end
        container:HookScript("OnSizeChanged", Later)
        container:HookScript("OnShow", Later)
        RememberRaid()
    end

    ---------------------------------------------------------------------------
    -- First places: where the game has each now; the extra button on Action Bar 1's bottom, the
    -- bag bar in the bottom right corner (Core\Defaults.lua snaps it there).
    ---------------------------------------------------------------------------

    local function Seed(key)
        local db = GF.db
        local l, _, t
        if key == "minimap" then
            l, _, t = MinimapArea()
        elseif key == "chat" then
            l, _, t = Rect(ChatFrame1)
        elseif key == "bags" then
            local place = GF.places.bags
            l, t = GetScreenWidth() - (place:GetWidth() or 0) - BORDER, (place:GetHeight() or 0) + BORDER
        elseif key == "tooltip" then
            l, _, t = Rect(GameTooltipDefaultContainer)
            if not l then
                local place = GF.places.tooltip
                l, t = GetScreenWidth() - (place:GetWidth() or 0) - BORDER, (place:GetHeight() or 0) + 85
            end
        elseif key == "classpower" then
            GF.PlaceClassPower()
            return
        else
            GF.PlaceExtra()
            return
        end
        if not l then return end
        db[key .. "Left"], db[key .. "Top"], db[key .. "Placed"] = l, t - GetScreenHeight(), true
        if key == "minimap" and (tonumber(db.minimapSize) or 0) <= 0 then
            local cluster = MinimapCluster
            local scale = cluster and cluster.GetEditModeScale and cluster:GetEditModeScale()
            db.minimapSize = math.floor((tonumber(scale) or 1) * 100 + 0.5)
        end
        if key == "chat" and (tonumber(db.chatWidth) or 0) <= 0 then
            -- (The panel's size: the window's and the room round it.)
            local chat = ChatFrame1
            local k, roomW, roomH = UI(chat), PanelRoom()
            db.chatWidth = math.floor(((chat:GetWidth() or 430) + roomW) * k + 0.5)
            db.chatHeight = math.floor(((chat:GetHeight() or 120) + roomH) * k + 0.5)
        end
    end

    local function Apply()
        local db = GF.db
        if not db then return end
        -- (The bag bar's place sized first: its first place comes from its size.)
        if GF.places.bags and not db.bagsPlaced then AttachBags() end
        if ready then
            for _, key in ipairs(KEYS) do
                if GF.places[key] and not db[key .. "Placed"] then Seed(key) end
            end
        end
        MinimapSize()
        if ready then MinimapRotate() end
        -- (The title above or below the map as set, then the map hung by both.)
        Core.Minimap.PlaceHeader()
        AttachMinimap()
        GF.AttachChat()
        AttachBags()
        AttachTooltip()
        Put("extra")
        if extraPending then IntoHolder() end
        Put("classpower")
        SeatClassPower()
    end

    -- Everything put back at the very end of leaving the game's Edit Mode, after every re-anchor
    -- on the way out (its listeners run through securecallfunction).
    local function Reattach()
        for _, attach in ipairs({ AttachMinimap, GF.AttachChat, AttachBags, AttachTooltip, IntoHolder, SeatClassPower }) do
            Core.Safely(attach)
        end
    end
    EventRegistry:RegisterCallback("EditMode.Exit", function() NowAndNext(Reattach) end, Reattach)

    ---------------------------------------------------------------------------
    -- Set up as the file loads (before the game restores combat on a reload), placed once the
    -- world is up and the game has laid its frames out.
    ---------------------------------------------------------------------------

    SetUpMinimap()
    SetUpChat()
    SetUpExtra()
    SetUpClassPower()
    SetUpBags()
    SetUpTooltip()
    SetUpRaid()

    function GF.Ready()
        ready = true
        Apply()
    end

    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "UPDATE_BINDINGS", "ADDON_LOADED",
                             "EDIT_MODE_LAYOUTS_UPDATED" }) do
        pcall(GF.RegisterEvent, GF, event)
    end
    GF:SetScript("OnEvent", function(_, event, name)
        if event == "EDIT_MODE_LAYOUTS_UPDATED" then
            MendLayouts()
        elseif event == "UPDATE_BINDINGS" then
            ExtraHotkey()
        elseif event == "ADDON_LOADED" then
            if name == "Blizzard_CompactRaidFrames" then SetUpRaid() end
        else
            if event == "PLAYER_ENTERING_WORLD" then C_Timer.After(1, GF.Ready) end
            Apply()
        end
    end)

    function GF.Normalise(db)
        for key, value in pairs(GF.defaults) do
            if type(value) == "number" and type(db[key]) ~= "number" then db[key] = value end
        end
    end

    GF.Refresh = Apply
    GF.Init = Apply

    -- (Unlock Mode moves the places; nothing in them changes while it is open.)
    function GF.Unlock() GF.db.unlocked = true end
    function GF.Lock() GF.db.unlocked = false end

    Core:RegisterModule(GF)
end
