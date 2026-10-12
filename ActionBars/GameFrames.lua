-- MODULE: the game's frames placed in Unlock Mode  (DogsForeverUI.GameFrames,
-- settings section "gameframes") - EllesmereUI's way (the player, 2026-10-03:
-- "port all of them like ellesmere"): the minimap, the chat, the extra
-- action button and the bag bar are pieces of the addon's Unlock Mode, moved,
-- snapped and anchored like its own, and out of the game's Edit Mode.
--
--   * THE MINIMAP and THE CHAT stay the game's frames, where they are in the
--     game's UI: each is hung from a frame of the addon's (its "place"),
--     exactly over what shows of it - the map with its title and border, the
--     chat window - and that place is what Unlock Mode moves. Hung with the
--     frame's own plain methods (the Base ones Edit Mode keeps), never Edit
--     Mode's; whenever Edit Mode puts the frame back on its own anchor (a
--     layout applied), it is hung from its place again, a frame later
--     (EllesmereUI's chat). The minimap's size and the chat's width and
--     height are set in their menus, kept over Edit Mode's.
--   * THE EXTRA ACTION BUTTON (and the zone ability beside it): the game's
--     container moved into a holder of the addon's, out of the game's
--     managed-frame layout - EllesmereUI's SetupBlizzardMovableFrame. Out of
--     combat only (the button is secure); again as combat ends.

local GF = CreateFrame("Frame")
DogsForeverUI.GameFrames = GF

do -- private scope
    local Core = DogsForeverUI
    local Style = Core.Style
    local BORDER = Style.BORDER_INSET

    GF.key = "gameframes"
    GF.title = "Game frames"
    GF.defaults = {
        unlocked = false,
        minimapSize = 0,        -- the minimap's size, percent of the game's (0: as the game has it)
        chatWidth = 0,          -- the chat window's size (0: as the game has it)
        chatHeight = 0,
        minimapHeaderBelow = true,  -- the minimap's title under it (Minimap\Minimap.lua, HeaderBelow)
        minimapRotate = false,      -- the minimap turning with the player (MinimapRotate); the game's default
        bagsSize = 75,              -- the bag bar's size, percent (the player, 2026-10-03: 75%)
        raidWidth = 0,              -- what the raid frames took when last seen (THE RAID FRAMES)
        raidHeight = 0,
        -- The raid frames' box as the game's own Edit Mode last showed it
        -- (its left, top, width, height in UIParent's units; width 0: never seen).
        raidEditLeft = 0, raidEditTop = 0, raidEditWidth = 0, raidEditHeight = 0,
    }
    GF.placement = {}
    GF.KEYS = { "minimap", "chat", "extra", "bags", "tooltip" }
    for _, key in ipairs(GF.KEYS) do
        GF.placement[key .. "Placed"] = true
        GF.placement[key .. "Left"] = true
        GF.placement[key .. "Top"] = true
    end
    GF.SIZE_MIN, GF.SIZE_MAX = 50, 200
    GF.CHAT_MIN, GF.CHAT_MAX = 150, 1000

    local held = {}             -- what Core.HoldEditMode keeps of each frame
    GF.places = {}              -- key -> the addon's frame it hangs from

    local function UI(region)
        return region:GetEffectiveScale() / UIParent:GetEffectiveScale()
    end

    -- A region's rectangle in UIParent's units.
    local function Rect(region)
        if type(region) ~= "table" or type(region.GetLeft) ~= "function" then return end
        local l, r, t, b = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
        if not (l and r and t and b) or r <= l or t <= b then return end
        local k = UI(region)
        return l * k, r * k, t * k, b * k
    end

    local function NewPlace(key, name)
        local place = CreateFrame("Frame", "DogsForeverUIPlace" .. name, UIParent)
        place:SetSize(1, 1)
        place:SetPoint("CENTER")
        place:EnableMouse(false)
        place:SetClampedToScreen(true)
        GF.places[key] = place
        return place
    end

    -- Its place, where it was kept.
    local function Put(key)
        local db, place = GF.db, GF.places[key]
        if not (db and place) or not db[key .. "Placed"] then return end
        if place:IsProtected() and InCombatLockdown() then return end
        place:ClearAllPoints()
        place:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db[key .. "Left"] or 0, db[key .. "Top"] or 0)
    end

    -- Kept where Unlock Mode dropped it (Core\Snap.lua).
    local function Save(key)
        local place = GF.places[key]
        local l, _, t = Rect(place)
        if not l then return end
        local db = GF.db
        db[key .. "Left"], db[key .. "Top"], db[key .. "Placed"] = l, t - GetScreenHeight(), true
        Put(key)
        Core.RefreshOptions()
    end

    -- A frame of the game's hung from a place: its top left `dx`, `dy`
    -- (UIParent's units) from the place's, through its own plain methods.
    local function Hang(frame, place, dx, dy)
        if frame:IsProtected() and InCombatLockdown() then return false end
        local clear = frame.ClearAllPointsBase or frame.ClearAllPoints
        local set = frame.SetPointBase or frame.SetPoint
        local k = UI(frame)
        clear(frame)
        set(frame, "TOPLEFT", place, "TOPLEFT", dx / k, dy / k)
        return true
    end

    -- Put back on its place whenever Edit Mode re-anchors it (EllesmereUI's
    -- ApplySystemAnchor post-hook) - AT ONCE, in the same moment, and again
    -- a frame later once the game's whole pass is done.
    --
    -- WHY AT ONCE (the player, 2026-10-03: "When I exit Edit Mode some
    -- elements are jumping around to different positions for a second ...
    -- those positions are their default positions"): leaving its Edit Mode,
    -- the game puts every one of its frames at the screen's top left, then
    -- where its own layout has it (RevertAllChanges -> UpdateLayoutInfo ->
    -- InitSystemAnchors, UpdateSystems -> ApplySystemAnchor). Put back only
    -- a frame later, the minimap, the chat, the bag bar, the tooltip and
    -- the extra button were drawn at the game's places in
    -- between - for as long as that frame took, in the hitch Edit Mode's
    -- closing costs. A post-hook runs after the game's own code, and its
    -- taint stays with it, so moving them back there is safe. (The
    -- deferred pass stays: the game sets a frame's size after its anchor,
    -- in the same update.) And once more at the very end of the game's
    -- leaving (EditMode.Exit, below).
    local function NowAndNext(fn)
        local ok, err = pcall(fn)
        if not ok and geterrorhandler then geterrorhandler()(err) end
        if C_Timer and C_Timer.After then C_Timer.After(0, fn) end
    end
    GF.NowAndNext = NowAndNext

    local function AfterAnchor(frame, fn)
        if type(frame.ApplySystemAnchor) == "function" then
            hooksecurefunc(frame, "ApplySystemAnchor", function() NowAndNext(fn) end)
        end
    end

    ---------------------------------------------------------------------------
    -- THE MINIMAP: the place over the map, its title band and its border
    -- (Minimap\Minimap.lua); the game's cluster hung so that is where they are.
    ---------------------------------------------------------------------------

    local function MinimapArea()
        local map, look = _G.Minimap, Core.Minimap
        local l, r, t, b = Rect(map)
        if not l then return end
        local out = ((look and look.border and look.border.out) or BORDER) * UI(map)
        l, r, t, b = l - out, r + out, t + out, b - out
        local bl, br, bt, bb = Rect(look and look.band)
        if bl then l, r, t, b = math.min(l, bl), math.max(r, br), math.max(t, bt), math.min(b, bb) end
        return l, r, t, b
    end

    local function MinimapSize()
        local cluster, db = _G.MinimapCluster, GF.db
        local size = db and tonumber(db.minimapSize) or 0
        if not (cluster and size > 0) or type(cluster.SetEditModeScale) ~= "function" then return end
        local scale = math.max(GF.SIZE_MIN, math.min(GF.SIZE_MAX, size)) / 100
        if type(cluster.GetEditModeScale) == "function" and math.abs((cluster:GetEditModeScale() or 1) - scale) < 0.001 then
            return
        end
        cluster:SetEditModeScale(scale)
    end

    function GF.AttachMinimap()
        local cluster, place = _G.MinimapCluster, GF.places.minimap
        if not (cluster and place) then return end
        local l, r, t, b = MinimapArea()
        local cl, _, ct = Rect(cluster)
        if not (l and cl) then return end
        place:SetSize(r - l, t - b)
        if not GF.db or not GF.db.minimapPlaced then return end
        Put("minimap")
        -- The place laid out, and the cluster hung so the area is on it.
        if not Rect(place) then return end
        Hang(cluster, place, cl - l, ct - t)
    end

    local function SetUpMinimap()
        local cluster = _G.MinimapCluster
        if not (cluster and _G.Minimap) then return end
        local place = NewPlace("minimap", "Minimap")
        Core.HoldEditMode(held, cluster, true)
        Core.SetHeld(cluster, true)
        AfterAnchor(cluster, GF.AttachMinimap)
        -- Its size: the game putting its own back (a layout applied), ours
        -- after it; and the area again whenever the map is rescaled or its
        -- title moves.
        if type(cluster.UpdateSystemSettingSize) == "function" then
            hooksecurefunc(cluster, "UpdateSystemSettingSize", function()
                if C_Timer and C_Timer.After then C_Timer.After(0, function() MinimapSize(); GF.AttachMinimap() end) end
            end)
        end
        if type(cluster.SetHeaderUnderneath) == "function" then
            hooksecurefunc(cluster, "SetHeaderUnderneath", function()
                NowAndNext(GF.AttachMinimap)
            end)
        end
        -- (After the minimap's own callback, which refits its border and title.)
        if type(EventRegistry) == "table" and type(EventRegistry.RegisterCallback) == "function" then
            EventRegistry:RegisterCallback("Minimap.OnScaleUpdated", GF.AttachMinimap, GF)
        end
        Core.Snap.Register(place, {
            save = function() Save("minimap") end,
            name = "Minimap", id = "minimap",
            -- The place is the area itself, border included.
            extra = function() return -BORDER, -BORDER, -BORDER, -BORDER end,
            -- (Its settings - Size, Header below, Rotate minimap - are the
            -- addon's own, applied at once: Options\Unlock.lua.)
        })
        -- The game's layout applying its own Rotate Minimap (as it loads, or
        -- a layout chosen): the addon's put straight back after it.
        if type(cluster.SetRotateMinimap) == "function" then
            hooksecurefunc(cluster, "SetRotateMinimap", function() GF.MinimapRotate() end)
        end
    end

    -- ROTATE MINIMAP, the addon's own setting (the player, 2026-10-03: "why
    -- do I need reload for rotate minimap?"): applied at once through the
    -- client's own rotateMinimap CVar - which is all the game's setting does
    -- (MinimapClusterMixin:SetRotateMinimap) - and again whenever the game's
    -- layout sets its own over it. Off by default, as the game's is; Reset
    -- everything puts it back off. Out of combat; as it ends (GF.Apply).
    function GF.MinimapRotate()
        local db = GF.db
        if not db or InCombatLockdown() then return end
        local get = (type(C_CVar) == "table" and C_CVar.GetCVar) or GetCVar
        local set = (type(C_CVar) == "table" and C_CVar.SetCVar) or SetCVar
        if type(get) ~= "function" or type(set) ~= "function" then return end
        local ok, now = pcall(get, "rotateMinimap")
        if not ok then return end
        local want = db.minimapRotate and "1" or "0"
        if now ~= want then pcall(set, "rotateMinimap", want) end
    end

    ---------------------------------------------------------------------------
    -- THE CHAT: the place over the main chat window; the window hung on it.
    ---------------------------------------------------------------------------

    -- THE CHAT'S WIDTH AND HEIGHT ARE ITS WHOLE PANEL'S (Chat\ChatLook.lua:
    -- the tabs' sidebar, the letters' row over it, the messages and the box
    -- typed into over their last lines), in UIParent's units. The window
    -- inside is that less the panel's own room round it.
    GF.CHAT_WINDOW_MIN = 40         -- the messages' own least size
    local function PanelRoom()
        local look = Core.Chat and Core.Chat.Look
        if not (look and look.PAD) then return 0, 0 end
        return 2 * look.PAD + look.SCROLL_ROOM + look.GAP + look.SIDE_WIDTH, 2 * look.PAD + look.TOP_ROOM
    end

    local function ChatSize()
        local chat, db = _G.ChatFrame1, GF.db
        if not (chat and db) then return end
        local width, height = tonumber(db.chatWidth) or 0, tonumber(db.chatHeight) or 0
        if width <= 0 and height <= 0 then return end
        if chat:IsProtected() and InCombatLockdown() then return end
        local k = UI(chat)
        local roomW, roomH = PanelRoom()
        local w = width > 0 and math.max(GF.CHAT_WINDOW_MIN,
            math.max(GF.CHAT_MIN, math.min(GF.CHAT_MAX, width)) / k - roomW) or chat:GetWidth()
        local h = height > 0 and math.max(GF.CHAT_WINDOW_MIN,
            math.max(GF.CHAT_MIN / 2, math.min(GF.CHAT_MAX, height)) / k - roomH) or chat:GetHeight()
        if math.abs((chat:GetWidth() or 0) - w) > 0.5 or math.abs((chat:GetHeight() or 0) - h) > 0.5 then
            chat:SetSize(w, h)
        end
    end

    function GF.AttachChat()
        local chat, place = _G.ChatFrame1, GF.places.chat
        if not (chat and place) then return end
        ChatSize()
        if not GF.db or not GF.db.chatPlaced then return end
        Put("chat")
        Hang(chat, place, 0, 0)
    end

    -- THE GAME'S CHAT SYSTEM KEEPS ITS OWN ANCHOR: right after it re-anchors
    -- the window or sets its size, it reads where the window hangs and
    -- writes that into its saved layout (EditModeChatFrameSystemMixin:
    -- RefreshSystemPosition). Hung from the place then, the layout named a
    -- frame that is gone with the addon off (the player, 2026-10-10:
    -- "Couldn't find region named 'DogsForeverUIPlaceChat'"). So at that
    -- moment the window is put on the same spot from UIParent, whatever it
    -- hung from - the place, or the place the game's layout still names
    -- before the addon's settings are in; NowAndNext's pass a frame later
    -- hangs it on the place again, so Unlock Mode still carries it.
    local function ChatFromUIParent()
        local chat = _G.ChatFrame1
        local l, _, t = Rect(chat)
        if not l or (chat:IsProtected() and InCombatLockdown()) then return end
        local clear = chat.ClearAllPointsBase or chat.ClearAllPoints
        local set = chat.SetPointBase or chat.SetPoint
        local k = UI(chat)
        clear(chat)
        set(chat, "TOPLEFT", UIParent, "TOPLEFT", l / k, (t - UIParent:GetTop()) / k)
    end

    -- A STORED LAYOUT STILL NAMING A FRAME OF THE ADDON'S (kept before
    -- ChatFromUIParent - the player, 2026-10-10, choosing the "Dog's Forever
    -- UI" layout with the addon off): that system is given back the game's
    -- default spot, and the layouts stored the way the game itself does it
    -- (ReconcileLayoutsWithModern: C_EditMode.SaveLayouts, saved layouts
    -- only). Whenever the game reads its layouts, and after it saves them -
    -- its copy of the inactive ones may still be the old one.
    local function MendLayouts()
        local edit, presets = _G.C_EditMode, _G.EditModePresetLayoutManager
        if type(edit) ~= "table" or type(edit.GetLayouts) ~= "function" or type(edit.SaveLayouts) ~= "function"
            or type(presets) ~= "table" or type(presets.GetDefaultSystemAnchorInfo) ~= "function" then return end
        local info = edit.GetLayouts()
        local mended = false
        for _, layout in ipairs(type(info) == "table" and info.layouts or {}) do
            for _, system in ipairs(layout.systems or {}) do
                local to = system.anchorInfo and system.anchorInfo.relativeTo
                if type(to) == "string" and to:find("^DogsForeverUI") then
                    local ok, anchor = pcall(presets.GetDefaultSystemAnchorInfo, presets, system.system, system.systemIndex)
                    if ok and type(anchor) == "table" then
                        system.anchorInfo, system.isInDefaultPosition = anchor, true
                        mended = true
                    end
                end
            end
        end
        if mended then edit.SaveLayouts(info) end
    end
    if type(EventRegistry) == "table" and type(EventRegistry.RegisterCallback) == "function" then
        EventRegistry:RegisterCallback("EditMode.SavedLayouts", MendLayouts, MendLayouts)
    end

    local function SetUpChat()
        local chat = _G.ChatFrame1
        if not chat then return end
        local place = NewPlace("chat", "Chat")
        Core.HoldEditMode(held, chat, true)
        Core.SetHeld(chat, true)
        for _, method in ipairs({ "ApplySystemAnchor", "UpdateSystemSettingWidth", "UpdateSystemSettingHeight" }) do
            if type(chat[method]) == "function" then
                hooksecurefunc(chat, method, function()
                    NowAndNext(GF.AttachChat)
                    pcall(ChatFromUIParent)
                end)
            end
        end
        -- The place is the window's top left corner; what shows of it, the
        -- chat's panel and the tabs' sidebar beside it (Chat\ChatLook.lua) -
        -- no border round them; reaching up to the letters' row over them,
        -- which comes and goes - or without them the window itself, whatever
        -- size the game gives it.
        local function Panel()
            local look = Core.Chat and Core.Chat.Look
            if look and look.ShownPanel then return look.ShownPanel() end
        end
        Core.Snap.Register(place, {
            save = function() Save("chat") end,
            name = "Chat", id = "chat",
            parts = function()
                local panel, side = Panel()
                return { panel or chat, side }
            end,
            extra = function()
                if not Panel() then return -BORDER, -BORDER, -BORDER, -BORDER end
                local look = Core.Chat.Look
                return -BORDER, -BORDER, look.TOP_ROOM - BORDER, -BORDER
            end,
        })
    end

    ---------------------------------------------------------------------------
    -- THE EXTRA ACTION BUTTON (EllesmereUI's SetupBlizzardMovableFrame): the
    -- game's container in a holder of the addon's, centred, out of the game's
    -- managed-frame layout; put back in whenever the game takes it out.
    ---------------------------------------------------------------------------

    local EXTRA_SIZE = 64
    local extraPending = false

    local function IntoHolder()
        local container, holder = _G.ExtraAbilityContainer, GF.places.extra
        if not (container and holder) then return end
        if InCombatLockdown() then
            extraPending = true
            return
        end
        extraPending = false
        -- (No field written onto it - `ignoreInLayout`, `ignoreFramePositionManager`
        -- were, until 2026-10-03: the game's Edit Mode read them as it applied
        -- its layout, tainted. Taken into the game's managed layout, it is
        -- reparented there - and the SetParent hook below brings it straight
        -- back into the holder, out of that layout.)
        if container.SetIsLayoutFrame then pcall(container.SetIsLayoutFrame, container, false) end
        if container:GetParent() ~= holder then container:SetParent(holder) end
        local clear = container.ClearAllPointsBase or container.ClearAllPoints
        local set = container.SetPointBase or container.SetPoint
        clear(container)
        set(container, "CENTER", holder, "CENTER", 0, 0)
    end
    GF.ExtraIntoHolder = IntoHolder

    -- Its hotkey: the game's button broadcaster no longer hands it the
    -- bindings (ActionBars\ActionBars.lua), so it is written here.
    local function ExtraHotkey()
        local button = _G.ExtraActionButton1
        local hotkey = button and button.HotKey
        if not hotkey then return end
        local key = GetBindingKey("EXTRAACTIONBUTTON1")
        if key then
            hotkey:SetText(GetBindingText and GetBindingText(key, 1) or key)
            hotkey:Show()
        end
    end

    local function SetUpExtra()
        local container = _G.ExtraAbilityContainer
        if not container then return end
        local holder = NewPlace("extra", "ExtraAction")
        holder:SetSize(EXTRA_SIZE, EXTRA_SIZE)
        Core.HoldEditMode(held, container, true)
        Core.SetHeld(container, true)
        if container.Selection and container.Selection.HookScript then
            hooksecurefunc(container.Selection, "Show", function(self) self:SetAlpha(0) end)
        end
        -- The game's managed layout reaches it through these: no more.
        container:SetScript("OnShow", nil)
        container:SetScript("OnHide", nil)
        if type(container.AddFrame) == "function" then
            hooksecurefunc(container, "AddFrame", function(_, frame)
                if frame and frame.EnableMouse and not InCombatLockdown() then frame:EnableMouse(true) end
                if C_Timer and C_Timer.After then C_Timer.After(0, ExtraHotkey) end
            end)
        end
        AfterAnchor(container, IntoHolder)
        hooksecurefunc(container, "Show", function()
            if container:GetParent() ~= holder then IntoHolder() end
            ExtraHotkey()
        end)
        hooksecurefunc(container, "SetParent", function(_, parent)
            if parent ~= holder then IntoHolder() end
        end)
        IntoHolder()
        Core.Snap.Register(holder, {
            save = function() Save("extra") end,
            name = "Extra Action Button", id = "extra",
        })
    end

    ---------------------------------------------------------------------------
    -- THE BAG BAR (the player, 2026-10-03: "if possible this should be
    -- managed from dogui unlock mode too"): the place the size of the bar;
    -- the game's bar hung on it like the minimap, and sized by the addon's
    -- own setting (75% to start) with the frame's plain SetScale (the Base
    -- one Edit Mode keeps - its own override re-anchors the frame). The bar
    -- still shows only while a bag is open, or while Unlock Mode or Edit
    -- Mode is (Menus\BagsBar.lua); the place is moved either way.
    ---------------------------------------------------------------------------

    local function BagsScale()
        local db = GF.db
        local size = db and tonumber(db.bagsSize) or 100
        return math.max(GF.SIZE_MIN, math.min(GF.SIZE_MAX, size)) / 100
    end

    local function BagsSize()
        local bar = _G.BagsBar
        if not bar or (bar:IsProtected() and InCombatLockdown()) then return end
        local scale = BagsScale()
        if math.abs((bar:GetScale() or 1) - scale) < 0.001 then return end
        local set = bar.SetScaleBase or bar.SetScale
        set(bar, scale)
    end

    function GF.AttachBags()
        local bar, place = _G.BagsBar, GF.places.bags
        if not (bar and place) then return end
        BagsSize()
        local k = UI(bar)
        local w, h = (bar:GetWidth() or 0) * k, (bar:GetHeight() or 0) * k
        if w > 0 and h > 0 then place:SetSize(w, h) end
        if not GF.db or not GF.db.bagsPlaced then return end
        Put("bags")
        Hang(bar, place, 0, 0)
    end

    local function SetUpBags()
        local bar = _G.BagsBar
        if not bar then return end
        local place = NewPlace("bags", "Bags")
        Core.HoldEditMode(held, bar, true)
        Core.SetHeld(bar, true)
        AfterAnchor(bar, GF.AttachBags)
        -- The game's size put back (a layout applied), ours after it; and the
        -- place resized whenever the bar is laid out again (a bag added).
        for _, method in ipairs({ "UpdateSystemSettingSize", "Layout" }) do
            if type(bar[method]) == "function" then
                hooksecurefunc(bar, method, function()
                    NowAndNext(GF.AttachBags)
                end)
            end
        end
        Core.Snap.Register(place, {
            save = function() Save("bags") end,
            name = "Bag Bar", id = "bags",
        })
    end

    ---------------------------------------------------------------------------
    -- THE TOOLTIP (the player, 2026-10-03: "make the tooltip our style. the
    -- hp bar under it our texture").
    --
    -- Where: the game puts its tooltip in the corner its Edit Mode frame for
    -- it (GameTooltipDefaultContainer, "HUD Tooltip") is anchored by
    -- (GameTooltip_SetDefaultAnchor). That frame is hung on a place of the
    -- addon's by its BOTTOMRIGHT, so the tooltip grows up and to the left
    -- from the place's bottom right corner - the health bar's room above it
    -- (TooltipBarRoom), so a unit's bar ends at the place's bottom. The place is moved in Unlock
    -- Mode; the addon's layout puts it in the bottom right corner
    -- (Core\DefaultPlaces.lua).
    --
    -- Its look: the game's nine-slice art at no opacity (again each time the
    -- game sets its style), the addon's background (25% see-through) and border in
    -- its place; the health bar under it, the addon's flat fill with its
    -- sheen and background - the game's colour kept. Widget
    -- calls and post-hooks only: nothing written on the game's tooltips.
    ---------------------------------------------------------------------------

    GF.TOOLTIP_BAR_HEIGHT = 8
    GF.TOOLTIP_BAR_GAP = 2      -- the health bar under the tooltip's border
    local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }
    local styledTips = setmetatable({}, { __mode = "k" })

    local function NoNineSlice(tip)
        if styledTips[tip] and type(tip.NineSlice) == "table" and tip.NineSlice.SetAlpha then
            tip.NineSlice:SetAlpha(0)
        end
    end

    -- THE HEALTH BAR UNDER THE TOOLTIP, clear of its border, as wide as the
    -- tooltip: the addon's flat fill with its sheen and background, no
    -- border of its own. (Inside the tooltip it sometimes lay over the last
    -- line - the room made for it under the text did not always hold - the
    -- player, 2026-10-03: "sometimes the tooltip healthbar is broken it
    -- overlapse with text so we can move the hp bar below the tooltip again
    -- but no border etc is needed".)
    local function StyleHealthBar(bar, tip)
        if type(bar) ~= "table" or type(bar.SetStatusBarTexture) ~= "function" then return end
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

    ---------------------------------------------------------------------------
    -- A UNIT'S TOOLTIP (the player, 2026-10-03: "with player names in tooltip
    -- we can use class colors"): a player's name, its first line, in their
    -- class colour - over the game's raid and party frames too, where the
    -- unit is secret, by the tooltip's plain GUID (ClassOf). A class the
    -- client keeps secret: left as the game has it. (The health bar coloured red to green by the unit's health
    -- was tried and taken out the same day - it did not work in game; the
    -- bar keeps the game's colour.)
    ---------------------------------------------------------------------------

    local function Plain(value) return value ~= nil and not (issecretvalue and issecretvalue(value)) end

    -- The class: from the tooltip's own GUID first (EllesmereUI's
    -- _resolveTipIdentity, EllesmereUIBlizzardSkin.lua) - over the game's raid
    -- and party frames the unit the tooltip answers is secret, but the GUID
    -- the game stamped into its data is plain, and GetPlayerInfoByGUID gives
    -- a player's class from it (none for a creature); then from the unit.
    local function ClassOf(data, unit)
        local guid = type(data) == "table" and data.guid
        if Plain(guid) and type(GetPlayerInfoByGUID) == "function" then
            local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
            if ok and Plain(class) and class ~= "" then return class end
        end
        if not Plain(unit) then return nil end
        local isPlayer = UnitIsPlayer(unit)
        if not (Plain(isPlayer) and isPlayer) then return nil end
        local _, class = UnitClass(unit)
        if Plain(class) then return class end
    end

    local function ClassName(tip, unit, data)
        local class = ClassOf(data, unit)
        if not class then return end
        local colours = _G.C_ClassColor
        local colour = (type(colours) == "table" and type(colours.GetClassColor) == "function"
            and colours.GetClassColor(class)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
        local name = tip:GetName()
        local line = Plain(name) and _G[name .. "TextLeft1"]
        if colour and line then line:SetTextColor(colour.r, colour.g, colour.b) end
    end

    -- The game has built a unit's tooltip (TooltipDataProcessor's post-call).
    local function UnitTooltip(tip, data)
        if not styledTips[tip] or type(tip.GetUnit) ~= "function" then return end
        local ok, _, unit = pcall(tip.GetUnit, tip)
        if not ok then unit = nil end
        pcall(ClassName, tip, unit, data)
    end
    GF.UnitTooltip = UnitTooltip

    -- How far the health bar reaches under the tooltip: the tooltip's corner
    -- stands that much above its place's, so the bar ends at the place's
    -- bottom.
    function GF.TooltipBarRoom()
        return BORDER + GF.TOOLTIP_BAR_GAP + GF.TOOLTIP_BAR_HEIGHT
    end

    -- The background's opacity (the player, 2026-10-04: "make tooltip
    -- background 25% transparent").
    GF.TOOLTIP_BACKGROUND_ALPHA = 0.75

    -- AN EMPTY TOOLTIP SHOWS NOTHING (the player, 2026-10-06: "sometimes the
    -- tooltip shows completely empty (happened to me when hovering a dead
    -- player) ... at first it was only border and background"): the game
    -- shows its tooltip before a unit's data has come, no line on it yet.
    -- Until a line has text, the addon's background, border and the health
    -- bar under it are see-through; the tooltip itself is left to the game
    -- (hiding it would drop its owner, and the lines would never come).
    local function HasText(tip)
        local name = tip:GetName()
        local count = type(tip.NumLines) == "function" and tip:NumLines() or 0
        if not Plain(name) or not Plain(count) then return true end
        for i = 1, count do
            local line = _G[name .. "TextLeft" .. i]
            local text = line and line:IsShown() and line:GetText()
            if not Plain(text) or (text and text ~= "") then return true end
            line = _G[name .. "TextRight" .. i]
            text = line and line:IsShown() and line:GetText()
            if not Plain(text) or (text and text ~= "") then return true end
        end
        return false
    end

    local function ShowBacking(tip)
        local parts = styledTips[tip]
        if type(parts) ~= "table" then return end
        local ok, filled = pcall(HasText, tip)
        local a = (not ok or filled) and 1 or 0
        parts.back:SetAlpha(a)
        if parts.border then parts.border:SetAlpha(a) end
        if parts.bar then parts.bar:SetAlpha(a) end
    end

    function GF.StyleTooltip(tip)
        if type(tip) ~= "table" or styledTips[tip] or type(tip.CreateTexture) ~= "function" then return end
        local back = tip:CreateTexture(nil, "BACKGROUND", nil, -8)
        back:SetAllPoints(tip)
        local tone = Style.BACKGROUND_COLOR
        back:SetColorTexture(tone[1], tone[2], tone[3], GF.TOOLTIP_BACKGROUND_ALPHA)
        local parts = { back = back, border = Style.AddBorder(tip) }
        styledTips[tip] = parts
        NoNineSlice(tip)
        tip:HookScript("OnShow", NoNineSlice)
        if tip == _G.GameTooltip then
            parts.bar = tip.StatusBar or _G.GameTooltipStatusBar
            StyleHealthBar(parts.bar, tip)
        end
        -- The game calls Show again each time it has laid the lines out.
        tip:HookScript("OnShow", ShowBacking)
        tip:HookScript("OnSizeChanged", ShowBacking)
        tip:HookScript("OnTooltipCleared", ShowBacking)
        hooksecurefunc(tip, "Show", ShowBacking)
    end

    -- ALL ITS TEXT 12 (the player, 2026-10-03: "ALL text should be 12pt"):
    -- the tooltips' three fonts - the first line's, the rest's and the small
    -- one's (GameTooltipHeaderText, GameTooltipText, GameTooltipTextSmall) -
    -- at TOOLTIP_TEXT, their faces as they are (the addon's own, from
    -- Core\Fonts.lua, which keeps a font's size).
    GF.TOOLTIP_TEXT = 12
    GF.TOOLTIP_FONTS = { "GameTooltipHeaderText", "GameTooltipText", "GameTooltipTextSmall" }
    local function TooltipFonts()
        for _, name in ipairs(GF.TOOLTIP_FONTS) do
            local font = _G[name]
            if type(font) == "table" and type(font.GetFont) == "function" then
                local file, size, flags = font:GetFont()
                if file and size ~= GF.TOOLTIP_TEXT then font:SetFont(file, GF.TOOLTIP_TEXT, flags or "") end
            end
        end
    end

    local function StyleTooltips()
        for _, name in ipairs(TOOLTIPS) do GF.StyleTooltip(_G[name]) end
        TooltipFonts()
    end
    for _, name in ipairs({ "SharedTooltip_SetBackdropStyle", "GameTooltip_SetBackdropStyle" }) do
        if type(_G[name]) == "function" then hooksecurefunc(name, NoNineSlice) end
    end

    function GF.AttachTooltip()
        local holder, place = _G.GameTooltipDefaultContainer, GF.places.tooltip
        if not (holder and place) then return end
        local k = UI(holder)
        local w, h = (holder:GetWidth() or 0) * k, (holder:GetHeight() or 0) * k
        if w > 0 and h > 0 then place:SetSize(w, h) end
        if not GF.db or not GF.db.tooltipPlaced then return end
        Put("tooltip")
        if holder:IsProtected() and InCombatLockdown() then return end
        local clear = holder.ClearAllPointsBase or holder.ClearAllPoints
        local set = holder.SetPointBase or holder.SetPoint
        clear(holder)
        set(holder, "BOTTOMRIGHT", place, "BOTTOMRIGHT", 0, GF.TooltipBarRoom() / k)
    end

    local function SetUpTooltip()
        StyleTooltips()
        local processor = _G.TooltipDataProcessor
        local kinds = type(Enum) == "table" and Enum.TooltipDataType
        if type(processor) == "table" and type(processor.AddTooltipPostCall) == "function" and kinds and kinds.Unit then
            processor.AddTooltipPostCall(kinds.Unit, UnitTooltip)
        end
        local holder = _G.GameTooltipDefaultContainer
        if not holder then return end
        local place = NewPlace("tooltip", "Tooltip")
        Core.HoldEditMode(held, holder, true)
        Core.SetHeld(holder, true)
        AfterAnchor(holder, GF.AttachTooltip)
        Core.Snap.Register(place, {
            save = function() Save("tooltip") end,
            name = "Tooltip", id = "tooltip",
        })
    end

    ---------------------------------------------------------------------------
    -- THE RAID FRAMES are the game's, placed and set in the game's own Edit
    -- Mode (the player, 2026-10-03: "in raid frames make it similar to
    -- objectives when i click them in our unlock mode, forward user to blizz
    -- edit mode" - for a day they were a piece of Unlock Mode of their own).
    -- Unlock Mode shows the handover box over them ("Edit from Blizzard",
    -- Options\Unlock.lua) - outside a raid too, where the game has them, at
    -- the size they took when last seen: GF.RaidBox. That size is what the
    -- raid frames take (FlowContainer_GetUsedBounds, the game's own measure
    -- - Frames\RaidFrames.lua fits their Edit Mode box to it), kept in the
    -- settings; RAID_SIZE before a raid was ever seen. Nothing of theirs is
    -- moved or held here.
    ---------------------------------------------------------------------------

    GF.RAID_SIZE = { 360, 180 }     -- before a raid was ever seen: 5 x 5 frames of the game's 72 x 36

    -- What the raid frames take now, in UIParent's units: shown only.
    local function RaidUsed()
        local container = _G.CompactRaidFrameContainer
        if not (container and container:IsShown()) or type(FlowContainer_GetUsedBounds) ~= "function" then return end
        local ok, w, h = pcall(FlowContainer_GetUsedBounds, container)
        if not ok or type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then return end
        local k = UI(container)
        return w * k, h * k
    end

    -- Kept: what they take, while shown.
    function GF.RememberRaid()
        local db = GF.db
        local w, h = RaidUsed()
        if db and w then db.raidWidth, db.raidHeight = math.floor(w + 0.5), math.floor(h + 0.5) end
    end

    -- THE SAME BOX AS THE GAME'S EDIT MODE (the player, 2026-10-03: "the raid
    -- frames in our unlock mode and blizz edit mode doesnt match"). Out of a
    -- raid the game's Edit Mode shows a preview of its own - as many groups
    -- as its View Raid Size says (10: 2, 25: 5, 40: 8), laid out by its own
    -- settings, the container hung off its raid manager (which slides in and
    -- out) - while this box was guessed from where the container sits now
    -- and the size of the last real raid. Instead, the box the game's Edit
    -- Mode itself draws round them (their Selection, fitted to what they use
    -- - Frames\RaidFrames.lua) is measured whenever the game lays them out
    -- with its Edit Mode open, and kept; out of a raid, Unlock Mode shows
    -- exactly that. Only measured, nothing of theirs touched.
    function GF.RememberEditModeRaid()
        local container, db = _G.CompactRaidFrameContainer, GF.db
        local manager = _G.EditModeManagerFrame
        local box = type(container) == "table" and container.Selection
        if not (db and box and manager) then return end
        local active = Core.Call(manager, "IsEditModeActive")
        local shown = Core.Call(container, "IsVisible")
        if not (active and shown) then return end
        local ok, l, r, t, b = pcall(Rect, box)
        if not (ok and l and r - l > 0 and t - b > 0) then return end
        db.raidEditLeft, db.raidEditTop = l, t
        db.raidEditWidth, db.raidEditHeight = r - l, t - b
    end

    -- Their box while no raid is up: the one the game's Edit Mode last showed
    -- (above); before it ever has, from the container's top left (where the
    -- game has them) at the size they took when last seen. UIParent's units:
    -- left, right, top, bottom.
    function GF.RaidBox()
        local container, db = _G.CompactRaidFrameContainer, GF.db
        local w, h = tonumber(db and db.raidEditWidth) or 0, tonumber(db and db.raidEditHeight) or 0
        if w > 0 and h > 0 then
            local l, t = db.raidEditLeft, db.raidEditTop
            return l, l + w, t, t - h
        end
        if type(container) ~= "table" or type(container.GetLeft) ~= "function" then return end
        local ok, left, top = pcall(function() return container:GetLeft(), container:GetTop() end)
        if not (ok and left and top) then return end
        local k = UI(container)
        left, top = left * k, top * k
        local w, h = tonumber(db and db.raidWidth) or 0, tonumber(db and db.raidHeight) or 0
        if w <= 0 or h <= 0 then w, h = GF.RAID_SIZE[1], GF.RAID_SIZE[2] end
        return left, left + w, top, top - h
    end

    local raidFollowed = false
    local function SetUpRaid()
        local container = _G.CompactRaidFrameContainer
        if raidFollowed or type(container) ~= "table" or type(container.HookScript) ~= "function" then return end
        raidFollowed = true
        local function Later()
            if C_Timer and C_Timer.After then C_Timer.After(0, GF.RememberRaid) else GF.RememberRaid() end
        end
        container:HookScript("OnSizeChanged", Later)
        container:HookScript("OnShow", Later)
        GF.RememberRaid()
    end
    GF.SetUpRaid = SetUpRaid

    ---------------------------------------------------------------------------
    -- FIRST PLACES: where the game has each now (the extra action button, out
    -- of its layout from the start: above the action bars, in the middle; the
    -- bag bar in the screen's bottom right corner, which the addon's layout
    -- snaps it into - Core\DefaultPlaces.lua).
    ---------------------------------------------------------------------------

    function GF.Seed(key)
        local db = GF.db
        local height = GetScreenHeight()
        local l, t
        if key == "minimap" then
            l, _, t = MinimapArea()
        elseif key == "chat" then
            l, _, t = Rect(_G.ChatFrame1)
        elseif key == "bags" then
            local place = GF.places.bags
            local w, h = place:GetWidth() or 0, place:GetHeight() or 0
            l, t = GetScreenWidth() - w - BORDER, h + BORDER
        elseif key == "tooltip" then
            -- (Where the game's Edit Mode has its frame; the addon's layout
            -- then puts it in the corner.)
            l, _, t = Rect(_G.GameTooltipDefaultContainer)
            if not l then
                local place = GF.places.tooltip
                l, t = GetScreenWidth() - (place:GetWidth() or 0) - BORDER, (place:GetHeight() or 0) + 85
            end
        else
            l, t = GetScreenWidth() / 2 - EXTRA_SIZE / 2, 260 + EXTRA_SIZE
        end
        if not l then return false end
        db[key .. "Left"], db[key .. "Top"], db[key .. "Placed"] = l, t - height, true
        if key == "minimap" and (tonumber(db.minimapSize) or 0) <= 0 then
            local cluster = _G.MinimapCluster
            local scale = cluster and type(cluster.GetEditModeScale) == "function" and cluster:GetEditModeScale()
            db.minimapSize = math.floor((tonumber(scale) or 1) * 100 + 0.5)
        end
        if key == "chat" and (tonumber(db.chatWidth) or 0) <= 0 then
            -- (The panel's size: the window's and the room round it.)
            local chat = _G.ChatFrame1
            local k, roomW, roomH = UI(chat), PanelRoom()
            db.chatWidth = math.floor(((chat:GetWidth() or 430) + roomW) * k + 0.5)
            db.chatHeight = math.floor(((chat:GetHeight() or 120) + roomH) * k + 0.5)
        end
        return true
    end

    function GF.Apply()
        if not GF.db then return end
        -- (The bag bar's place sized first: its first place is worked out
        -- from its size.)
        if GF.places.bags and not GF.db.bagsPlaced then GF.AttachBags() end
        for _, key in ipairs(GF.KEYS) do
            if GF.places[key] and not GF.db[key .. "Placed"] and GF.ready then GF.Seed(key) end
        end
        MinimapSize()
        if GF.ready then GF.MinimapRotate() end
        -- (The title above or below the map as the setting has it, then the
        -- map hung by both.)
        local look = Core.Minimap
        if look and look.PlaceHeader then look.PlaceHeader() end
        GF.AttachMinimap()
        GF.AttachChat()
        GF.AttachBags()
        GF.AttachTooltip()
        Put("extra")
        if extraPending then IntoHolder() end
    end

    ---------------------------------------------------------------------------
    -- Set up as the file loads (before the game restores combat on a reload),
    -- placed once the world is up and the game has laid its frames out.
    ---------------------------------------------------------------------------

    SetUpMinimap()
    SetUpChat()
    SetUpExtra()
    SetUpBags()
    SetUpTooltip()
    SetUpRaid()

    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "UPDATE_BINDINGS", "ADDON_LOADED",
                             "EDIT_MODE_LAYOUTS_UPDATED" }) do
        pcall(GF.RegisterEvent, GF, event)
    end
    GF:SetScript("OnEvent", function(_, event, name)
        if event == "EDIT_MODE_LAYOUTS_UPDATED" then
            MendLayouts()
            return
        end
        if event == "UPDATE_BINDINGS" then
            ExtraHotkey()
            return
        end
        if event == "ADDON_LOADED" then
            if name == "Blizzard_CompactRaidFrames" then SetUpRaid() end
            return
        end
        if event == "PLAYER_ENTERING_WORLD" and C_Timer and C_Timer.After then
            C_Timer.After(1, GF.Ready)
        end
        GF.Apply()
    end)

    function GF.Ready()
        GF.ready = true
        GF.Apply()
    end

    function GF.Normalise(db)
        for _, key in ipairs({ "minimapSize", "chatWidth", "chatHeight", "raidWidth", "raidHeight",
                               "raidEditLeft", "raidEditTop", "raidEditWidth", "raidEditHeight" }) do
            if type(db[key]) ~= "number" then db[key] = 0 end
        end
        if type(db.bagsSize) ~= "number" then db.bagsSize = GF.defaults.bagsSize end
    end

    function GF.Refresh()
        GF.Apply()
    end
    GF.Init = GF.Refresh

    -- (Unlock Mode moves the places; nothing changes in them while it is open.)
    function GF.Unlock() GF.db.unlocked = true end
    function GF.Lock() GF.db.unlocked = false end

    ---------------------------------------------------------------------------
    -- THE GAME'S EDIT MODE CLOSED: everything the addon places put back on
    -- its place at the very end of the game's leaving, in the same moment -
    -- after every re-anchoring the game does on the way out (its layout
    -- applied again, its account settings, every frame told anchors
    -- changed), so nothing is drawn where the game's own layout has it (see
    -- AfterAnchor). The game calls its listeners through securecallfunction,
    -- so nothing of the addon's reaches its code.
    ---------------------------------------------------------------------------

    function GF.Reattach()
        for _, attach in ipairs({ GF.AttachMinimap, GF.AttachChat, GF.AttachBags, GF.AttachTooltip,
                                  GF.ExtraIntoHolder }) do
            local ok, err = pcall(attach)
            if not ok and geterrorhandler then geterrorhandler()(err) end
        end
    end

    if type(EventRegistry) == "table" and type(EventRegistry.RegisterCallback) == "function" then
        EventRegistry:RegisterCallback("EditMode.Exit", function() NowAndNext(GF.Reattach) end, GF.Reattach)
    end

    Core:RegisterModule(GF)
end
