-- The chat's look  (DogsForeverUI.Chat.Look)
-- FlareUI's layout built EllesmereUI's way: a panel round each window (Core\Panel.lua),
-- the tabs in a sidebar left of it, the header buttons as letters over its top right.
-- TAINT: hooks on the game's chat or calls into its FCF_* broke whispers (the secret
-- sender name) until a /reload. So nothing of it is hooked or called: its tab row lives
-- out of sight, the sidebar's secure rows click its tabs, every frame of ours is
-- UIParent's, and changes are watched (Watch five times a second, Sync every frame).

local Look = {}
DogsForeverUI.Chat.Look = Look

do -- private scope
    local Core = DogsForeverUI
    local Style, Panel = Core.Style, Core.Panel
    local Secret = issecretvalue
    local Try = Core.Safely

    Look.PAD = 10               -- the panel past the messages
    Look.SCROLL_ROOM = 8        -- the scrollbar, at the messages' right
    Look.GAP = 2                -- the panel to the sidebar, the letters and the edit box
    Look.TAB_IDLE = 0.6         -- a tab not shown
    Look.EDIT_RISE = 30         -- the edit box over the window's last 30
    Look.ICON = 16              -- a header letter
    Look.ICON_GAP = 4
    Look.TOP_ROOM = Look.GAP + Look.ICON    -- the letters' row over the panel
    Look.GREY = { 0.56, 0.51, 0.46 }        -- a tab not shown
    Look.SIDE_WIDTH = 100       -- the tabs' sidebar
    Look.SIDE_PAD = 2           -- its rows in from its edges
    Look.ROW = 20               -- a tab's row in it
    Look.ROW_GAP = 2
    Look.DOCK_AWAY = 200        -- the game's tab row, this far under the screen
    Look.FONT_SIZE = 12         -- the chat's default font size (DEFAULTS)
    Look.WATCH_EVERY = 0.2

    local TAB_INSET = 8         -- an undocked tab's words from its left end, at the least
    local EDIT_INSET = 2        -- the addon's box inside the edit box
    local TAB_FONT_SIZE = 13
    local ROW_INSET = 8         -- a row's words from its left end
    local ROW_HOVER = 0.08      -- a row's light under the mouse
    local ROW_MARK = 2          -- the shown window's gold mark at its row's left
    local STEP = Look.ICON + Look.ICON_GAP  -- a letter's room in the header
    local WHISPER_MODE = "popout"
    local RED = { 1, 0, 0 }     -- a tab flashing for a new message
    local NONE = {}
    local ART = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }
    local EDIT_ART = { "Left", "Right", "Mid", "FocusLeft", "FocusRight", "FocusMid" }
    -- The main chat windows (the old NUM_CHAT_WINDOWS).
    local WINDOWS = Constants and Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows or 10

    local skins = {}            -- chat window -> its panel
    local side                  -- the tabs' sidebar
    local done = {}             -- set up once: object -> true
    local pending = false       -- something waits for the end of combat
    local applied = false       -- Apply has run once
    local SkinLetters           -- below

    local function IsWidget(object, kind)
        return type(object) == "table" and type(object.GetObjectType) == "function"
            and (not kind or object:GetObjectType() == kind)
    end

    local function Shown(frame)
        local shown = frame:IsShown()
        return not Secret(shown) and shown and true or false
    end

    -- Shown or hidden as `want`, touched only when it differs.
    local function ShowAs(frame, want)
        want = want and true or false
        if (frame:IsShown() and true or false) ~= want then frame:SetShown(want) end
    end

    -- A write a game frame may refuse in combat (a whisper window's are
    -- protected then): tried, a refusal left for later.
    local function Quietly(object, method, ...)
        if InCombatLockdown() then return pcall(object[method], object, ...) end
        object[method](object, ...)
    end

    -- At no opacity (set again only when the game raised it).
    local function Unseen(region)
        local alpha = region:GetAlpha()
        if Secret(alpha) or alpha ~= 0 then Quietly(region, "SetAlpha", 0) end
    end

    -- In `owner`'s strata, a level under it.
    local function Beneath(frame, owner)
        local strata = owner:GetFrameStrata()
        if not Secret(strata) and frame:GetFrameStrata() ~= strata then frame:SetFrameStrata(strata) end
        local level = owner:GetFrameLevel()
        if type(level) == "number" and not Secret(level) then
            level = math.max(level - 1, 0)
            if frame:GetFrameLevel() ~= level then frame:SetFrameLevel(level) end
        end
    end

    -- A texture drawn as nothing; `hide`: hidden too (hidden, the game's fade skips it).
    local function Blank(texture, hide)
        texture:SetTexture(nil)
        texture:SetAlpha(0)
        if hide then texture:Hide() end
    end

    -- The game's textures `name` .. each key, blanked and hidden.
    local function BlankNamed(name, keys)
        for _, key in ipairs(keys) do
            local texture = _G[name .. key]
            if IsWidget(texture) then Blank(texture, true) end
        end
    end

    local function Dock() return _G.GeneralDockManager or _G.GENERAL_CHAT_DOCK end

    local function Primary()
        local dock = Dock()
        local primary = IsWidget(dock) and dock.primary
        return IsWidget(primary) and primary or _G.ChatFrame1
    end

    -- The dock's field, read (FCFDock_GetSelectedWindow only returns it).
    local function Selected()
        local dock = Dock()
        local selected = IsWidget(dock) and dock.selected
        return IsWidget(selected) and selected or nil
    end

    -- A button's pictures.
    local function Art(button)
        local art = {}
        for _, get in ipairs(ART) do
            local texture = type(button[get]) == "function" and button[get](button)
            if texture then art[#art + 1] = texture end
        end
        return art
    end

    -- Every chat window once: the main ones, then the game's list (whisper
    -- windows). Five times a second, so a run number marks the windows met.
    local lastRun, run = {}, 0
    local function Visit(frame, fn)
        if IsWidget(frame) and lastRun[frame] ~= run then
            lastRun[frame] = run
            fn(frame)
        end
    end
    local function EachWindow(fn)
        run = run + 1
        for index = 1, WINDOWS do Visit(_G["ChatFrame" .. index], fn) end
        for _, name in ipairs(CHAT_FRAMES or NONE) do Visit(_G[name], fn) end
    end

    -- The panes' titles' font (Core\Panel.lua).
    local tabFont
    local function TabFont()
        if tabFont then return tabFont end
        tabFont = CreateFont("DogsForeverUIChatTabFont")
        local letters = _G[Panel.LETTER_FONT]
        if letters and tabFont.CopyFontObject then
            tabFont:CopyFontObject(letters)
        else
            tabFont:SetFont(Style.FONT, TAB_FONT_SIZE, "")
            tabFont:SetShadowColor(0, 0, 0, 1)
            tabFont:SetShadowOffset(1, -1)
        end
        return tabFont
    end

    ---------------------------------------------------------------------------
    -- The window
    ---------------------------------------------------------------------------

    -- The button column: at no opacity (again every frame, the game fades it
    -- in), deaf, its art gone - never hidden or re-parented, the game moves
    -- it while docking (FCF_SetButtonSide).
    local function ButtonColumn(chatFrame)
        local column = chatFrame.buttonFrame
        if not IsWidget(column) then return end
        Unseen(column)
        if done[column] then return end
        done[column] = true
        column:EnableMouse(false)
        for _, region in ipairs({ column:GetRegions() }) do
            if IsWidget(region, "Texture") then Blank(region) end
        end
    end

    local function Typing(chatFrame)
        local box = chatFrame.editBox
        return IsWidget(box) and box:IsShown() and box:HasFocus() or false
    end

    -- What a panel is laid round: the window, or for a docked one the dock's
    -- main window, so the panel keeps its size from tab to tab (the combat
    -- log lowers its own top for its filter row).
    local function Base(chatFrame, primary)
        primary = primary or Primary()
        if chatFrame.isDocked and IsWidget(primary) and primary ~= chatFrame then return primary end
        return chatFrame
    end

    local function PlaceSkin(chatFrame, primary)
        local skin = skins[chatFrame]
        if not skin then return end
        local base = Base(chatFrame, primary)
        if skin.base == base then return end
        skin.base = base
        skin:ClearAllPoints()
        skin:SetPoint("TOPLEFT", base, "TOPLEFT", -Look.PAD, Look.PAD)
        skin:SetPoint("BOTTOMRIGHT", base, "BOTTOMRIGHT", Look.PAD + Look.SCROLL_ROOM, -Look.PAD)
    end

    -- Shown with its window, a level under it (a hidden one's layer left until it shows).
    local function SyncSkin(chatFrame, skin)
        local shown = chatFrame:IsShown()
        if Secret(shown) then return end
        ShowAs(skin, shown)
        if shown then Beneath(skin, chatFrame) end
    end

    -- The mouse over a panel or the letters' row over it.
    local function OverSkin(skin)
        return skin:IsMouseOver(Look.TOP_ROOM, 0, 0, 0)
    end

    -- (A docked window's panel and the sidebar fade together.)
    local function OverSide(chatFrame)
        return (chatFrame.isDocked or chatFrame == Primary()) and side:IsVisible() and side:IsMouseOver()
    end

    local function SkinFrame(chatFrame)
        local skin = skins[chatFrame]
        if not skin then
            skin = Panel.New(UIParent, {
                active = function()
                    return Typing(chatFrame) or OverSide(chatFrame) or OverSkin(skins[chatFrame])
                end,
                letters = function() return SkinLetters(skins[chatFrame]) end,
            })
            skins[chatFrame] = skin
        end
        PlaceSkin(chatFrame)
        SyncSkin(chatFrame, skin)
    end
    Look.panels = skins

    local own = {}              -- the addon's own header buttons: key -> button
    local ghostLetters = {}     -- a game button -> the ghost drawing its letter
    local lettered = {}         -- every button with a letter -> its key
    Look.ghostLetters = ghostLetters

    -- Right to left (Flare's HEADER_ORDER).
    local ORDER = { "sound", "QuickJoinToastButton", "ChatFrameMenuButton", "ChatFrameChannelButton",
                    "ChatFrameToggleVoiceMuteButton", "ChatFrameToggleVoiceDeafenButton", "copy" }

    local LETTERS = {
        QuickJoinToastButton = "F", ChatFrameMenuButton = "/", ChatFrameChannelButton = "#",
        ChatFrameToggleVoiceMuteButton = "V", ChatFrameToggleVoiceDeafenButton = "D",
        copy = "C", sound = "S",
        filters = "+",          -- the combat log's filters menu
    }

    local function Button(key)
        if own[key] then return own[key] end
        local button = _G[key]
        return IsWidget(button) and button or nil
    end

    -- Whether `frame` has `point` on `relative` at x, y (a secret or a refused
    -- question: taken as yes, left alone).
    local function HasPoint(frame, point, relative, x, y)
        local ok, count = pcall(frame.GetNumPoints, frame)
        if not ok or Secret(count) or type(count) ~= "number" then return true end
        for index = 1, count do
            local fine, at, to, _, px, py = pcall(frame.GetPoint, frame, index)
            if not fine or Secret(px) or Secret(py) then return true end
            if at == point then return to == relative and px == x and py == y end
        end
        return false
    end

    -- THE GAME'S TAB ROW: alive (the sidebar clicks its tabs), unseen under the screen's
    -- bottom edge, as wide as it. Moved out of combat, back whenever the game places it.
    local function AdoptDock()
        local dock = Dock()
        if not IsWidget(dock) then return end
        Unseen(dock)
        if InCombatLockdown() then return end
        local y = -Look.DOCK_AWAY
        if HasPoint(dock, "TOPLEFT", UIParent, 0, y) and HasPoint(dock, "TOPRIGHT", UIParent, 0, y) then return end
        dock:ClearAllPoints()
        dock:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, y)
        dock:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", 0, y)
    end

    ---------------------------------------------------------------------------
    -- A tab's words, on a sidebar row or a ghost over an undocked tab: the shown
    -- window gold, the others grey, red while flashing. Handed on, never
    -- measured (a whisper window's are secret).
    ---------------------------------------------------------------------------

    local function TabOf(frame)
        local tab = IsWidget(frame) and _G[(frame:GetName() or "?") .. "Tab"]
        return IsWidget(tab) and tab or nil
    end

    local function PaintGhost(ghost)
        local colour = ghost.colour
        ghost.text:SetTextColor(colour[1], colour[2], colour[3])
        ghost.text:SetAlpha(ghost.hover and 1 or ghost.restAlpha)
        if ghost.light then ghost.light:SetShown(ghost.hover and ghost.tab ~= nil) end
        if ghost.mark then ghost.mark:SetShown(ghost.isSelected and true or false) end
    end

    local function Hover(self)
        self.hover = true
        PaintGhost(self)
    end

    local function Unhover(self)
        self.hover = false
        PaintGhost(self)
    end

    -- The words `inset` in from the frame's left end, cut before its right.
    local function Inset(ghost, inset)
        if ghost.inset == inset then return end
        ghost.inset = inset
        ghost.text:ClearAllPoints()
        ghost.text:SetPoint("LEFT", ghost, "LEFT", inset, 0)
        ghost.text:SetPoint("RIGHT", ghost, "RIGHT", -2, 0)
    end

    local function AddWords(frame, inset)
        frame.text = frame:CreateFontString(nil, "OVERLAY")
        frame.text:SetFontObject(TabFont())
        frame.text:SetWordWrap(false)
        frame.text:SetJustifyH("LEFT")
        Inset(frame, inset)
        frame.colour, frame.restAlpha = Look.GREY, Look.TAB_IDLE
    end

    -- As far in as the game's own padding on a tab sized to its words.
    local function TabInset(tab)
        local words = tab.GetFontString and tab:GetFontString()
        local width, used = tab:GetWidth(), words and words:GetStringWidth()
        if type(width) ~= "number" or type(used) ~= "number" or Secret(width) or Secret(used) then
            return TAB_INSET
        end
        return math.max(TAB_INSET, math.floor((width - used) / 2 + 0.5))
    end

    -- A secret goes straight to SetText, which takes one.
    local function Words(frame, tab)
        local words = tab:GetText()
        if Secret(words) then return words end
        if type(words) == "string" and words ~= "" then return words end
        local id = frame:GetID()
        local name = GetChatWindowInfo(id)
        if type(name) == "string" and name ~= "" and not Secret(name) then return name end
        return "Chat " .. tostring(id)
    end

    -- The game's flash for a new message, kept off the tab (ChatFrameUtil).
    local function Alerting(tab)
        local util = _G.ChatFrameUtil
        if util and util.IsTabAlerting then
            local ok, alerting = pcall(util.IsTabAlerting, tab)
            if ok and not Secret(alerting) then return alerting and true or false end
        end
        return IsWidget(tab.glow) and tab.glow:IsShown() and true or false
    end

    local function StyleGhost(ghost, frame, tab, selected)
        -- (The tab's own font: its words fit the tab the game measured.)
        local words = tab.GetFontString and tab:GetFontString()
        local file, size, flags
        if words then file, size, flags = words:GetFont() end
        if type(file) == "string" and type(size) == "number" and not Secret(size) then
            ghost.text:SetFont(file, size, flags or "")
            ghost.text:SetShadowColor(0, 0, 0, 1)
            ghost.text:SetShadowOffset(1, -1)
        else
            ghost.text:SetFontObject(TabFont())
        end
        ghost.text:SetText(Words(frame, tab))
        ghost.isSelected = frame == selected
        if not ghost.isSelected and Alerting(tab) then
            ghost.colour, ghost.restAlpha = RED, 1
        elseif frame.isTemporary then
            -- Its chat type's colour, the whisper's when none.
            local info = ChatTypeInfo[frame.chatType] or ChatTypeInfo.WHISPER
            ghost.colour, ghost.restAlpha = { info.r, info.g, info.b }, ghost.isSelected and 1 or Look.TAB_IDLE
        elseif ghost.isSelected then
            ghost.colour, ghost.restAlpha = Panel.LETTER_COLOR, 1
        else
            ghost.colour, ghost.restAlpha = Look.GREY, Look.TAB_IDLE
        end
        PaintGhost(ghost)
    end

    -- AN UNDOCKED WINDOW keeps the game's tab (its drag, its menu), its pictures
    -- unseen, under a ghost of ours drawing its words and taking no click.
    local floats = {}           -- an undocked window -> its tab's ghost
    Look.floats = floats

    local function UpdateFloat(frame, seen)
        local tab, skin = TabOf(frame), skins[frame]
        if not tab or not skin then return end
        for _, region in ipairs({ tab:GetRegions() }) do Unseen(region) end
        local ghost = floats[frame]
        if not ghost then
            ghost = CreateFrame("Frame", nil, skin)
            AddWords(ghost, TAB_INSET)
            ghost:SetScript("OnEnter", Hover)
            ghost:SetScript("OnLeave", Unhover)
            Panel.PassThrough(ghost)
            floats[frame] = ghost
        end
        ghost:ClearAllPoints()
        ghost:SetPoint("TOP", skin, "TOP", 0, Look.TOP_ROOM)
        ghost:SetPoint("BOTTOM", skin, "TOP", 0, Look.GAP)
        ghost:SetPoint("LEFT", tab, "LEFT", 0, 0)
        ghost:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
        Inset(ghost, TabInset(tab))
        StyleGhost(ghost, frame, tab, frame)
        ghost:Show()
        seen[frame] = true
    end

    ---------------------------------------------------------------------------
    -- THE SIDEBAR: GAP left of the docked windows' panel, as tall; a row per
    -- docked window, wheel-scrolled (the shown one kept in view), a thin thumb
    -- red while one out of view flashes. A row is a secure "click" button on
    -- the game's tab, so the tab's click runs untainted. Protected: placed by
    -- numbers on UIParent (anchored, it would protect the chat), given its
    -- tabs out of combat; a row changed in a fight is shielded until it ends.
    ---------------------------------------------------------------------------

    local rows = {}             -- top down
    local top = 0               -- docked windows scrolled past
    local revealed              -- the window last scrolled into view

    -- The docked windows' panel on view.
    local function DockedSkin()
        local skin = skins[Selected() or Primary()]
        return skin and skin:IsVisible() and skin or nil
    end

    local function UpdateSide()
        local dock = Dock()
        if not IsWidget(dock) then return end
        local docked = dock.DOCKED_CHAT_FRAMES or NONE
        local count, fit = #docked, side.capacity or 0
        local selected = Selected()
        if selected ~= revealed then
            revealed = selected
            for index, frame in ipairs(docked) do
                if frame == selected then top = math.max(math.min(top, index - 1), index - fit) end
            end
        end
        top = math.max(0, math.min(top, count - fit))
        local free = not InCombatLockdown()
        for index, row in ipairs(rows) do
            local frame = index <= fit and docked[top + index] or nil
            local tab = TabOf(frame)
            if free then
                ShowAs(row, index <= fit)
                if row.click ~= tab then
                    row:SetAttribute("clickbutton", tab)
                    row.click = tab
                end
            end
            row.tab = tab
            if tab then
                StyleGhost(row, frame, tab, selected)
            else
                row.text:SetText("")
                row.isSelected = false
                PaintGhost(row)
            end
            row.shield:SetShown(row.click ~= tab)
            if row.click ~= tab then pending = true end
        end
        local thumb = side.thumb
        local scrolls = count > fit and fit > 0
        side.track:SetShown(scrolls)
        if not scrolls then
            thumb:Hide()
            return
        end
        local alert = false
        for index, frame in ipairs(docked) do
            local tab = (index <= top or index > top + fit) and TabOf(frame)
            if tab and Alerting(tab) then alert = true end
        end
        local colour = alert and RED or Style.BORDER_COLOR
        thumb:SetColorTexture(colour[1], colour[2], colour[3], 1)
        -- As thick on the screen as the chat's scrollbar.
        local thick = Panel.Pixels(side, Panel.SCROLL_PIXELS)
        side.track:SetWidth(thick)
        thumb:SetWidth(thick)
        local track = side:GetHeight() - 2 * Look.SIDE_PAD
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", side, "TOPRIGHT", -Look.SIDE_PAD, -(Look.SIDE_PAD + track * top / count))
        thumb:SetHeight(track * fit / count)
        thumb:Show()
    end

    local function Wheel(_, delta)
        top = top - delta
        UpdateSide()
    end

    local function NewRow(index)
        local row = CreateFrame("Button", nil, side, "SecureActionButtonTemplate")
        row:RegisterForClicks("AnyUp")
        row:SetAttribute("useOnKeyDown", false)
        row:SetAttribute("type", "click")
        local y = -(Look.SIDE_PAD + (index - 1) * (Look.ROW + Look.ROW_GAP))
        row:SetPoint("TOPLEFT", side, "TOPLEFT", Look.SIDE_PAD, y)
        row:SetPoint("TOPRIGHT", side, "TOPRIGHT", -(Look.SIDE_PAD + Panel.SCROLL_WIDTH), y)
        row:SetHeight(Look.ROW)
        AddWords(row, ROW_INSET)
        row.light = row:CreateTexture(nil, "BACKGROUND")
        row.light:SetAllPoints(row)
        row.light:SetColorTexture(1, 1, 1, ROW_HOVER)
        row.light:Hide()
        local gold = Panel.LETTER_COLOR
        row.mark = row:CreateTexture(nil, "ARTWORK")
        row.mark:SetColorTexture(gold[1], gold[2], gold[3], 1)
        row.mark:SetWidth(ROW_MARK)
        row.mark:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.mark:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        row.mark:Hide()
        row:SetScript("OnEnter", Hover)
        row:SetScript("OnLeave", Unhover)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", Wheel)
        -- Not protected: shown and hidden in combat too.
        local shield = CreateFrame("Frame", nil, row)
        shield:SetAllPoints(row)
        shield:SetFrameLevel(row:GetFrameLevel() + 2)
        shield:EnableMouse(true)
        shield:EnableMouseWheel(true)
        shield:SetScript("OnMouseWheel", Wheel)
        shield:Hide()
        row.shield = shield
        return row
    end

    -- GAP left of `skin`, as tall, as many rows as fit. Out of combat only.
    local function PlaceSide(skin)
        local left, high, low, strata = skin:GetLeft(), skin:GetTop(), skin:GetBottom(), skin:GetFrameStrata()
        if not (left and high and low) then return end
        if side.left == left and side.high == high and side.low == low and side.strata == strata then return end
        side.left, side.high, side.low, side.strata = left, high, low, strata
        side:ClearAllPoints()
        side:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left - Look.GAP, high)
        side:SetSize(Look.SIDE_WIDTH, high - low)
        side:SetFrameStrata(strata)
        local step = Look.ROW + Look.ROW_GAP
        side.capacity = math.max(0, math.floor((high - low - 2 * Look.SIDE_PAD + Look.ROW_GAP) / step))
        for index = #rows + 1, side.capacity do rows[index] = NewRow(index) end
        UpdateSide()
    end

    local function SyncSide()
        if InCombatLockdown() then return end
        local skin = DockedSkin()
        ShowAs(side, skin)
        if skin then PlaceSide(skin) end
    end

    side = Panel.New(UIParent, {
        active = function()
            local skin = DockedSkin()
            return skin ~= nil and (OverSkin(skin) or Typing(Selected() or Primary()))
        end,
    })
    side:EnableMouseWheel(true)
    side:SetScript("OnMouseWheel", Wheel)
    -- The chat scrollbar's look: a thin dark track, the gold thumb on it.
    local tone = Style.BACKGROUND_COLOR
    side.track = side:CreateTexture(nil, "BORDER")
    side.track:SetColorTexture(tone[1], tone[2], tone[3], tone[4])
    side.track:SetPoint("TOPRIGHT", side, "TOPRIGHT", -Look.SIDE_PAD, -Look.SIDE_PAD)
    side.track:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -Look.SIDE_PAD, Look.SIDE_PAD)
    side.track:Hide()
    side.thumb = side:CreateTexture(nil, "ARTWORK")
    side.thumb:Hide()
    side:Hide()
    Look.sidebar, Look.rows = side, rows

    local function UpdateTabs()
        UpdateSide()
        local seen = {}
        EachWindow(function(frame)
            if not frame.isDocked and Shown(frame) then UpdateFloat(frame, seen) end
        end)
        for frame, ghost in pairs(floats) do
            if not seen[frame] then ghost:Hide() end
        end
    end

    ---------------------------------------------------------------------------
    -- THE HEADER: letters right to left over the shown panel's top right, a
    -- hidden button taking no place. The game's buttons stay the game's, moved
    -- in at no opacity under a ghost letter; ours (sound, copy) are on the panel.
    ---------------------------------------------------------------------------

    local function Usable(frame)
        return IsWidget(frame) and skins[frame] and Shown(frame) and frame or nil
    end

    -- The dock's window on view (not SELECTED_CHAT_FRAME, which can be an
    -- undocked window clicked), else the main one, else the first shown.
    local function VisibleSkinHost()
        local host = Usable(Selected()) or Usable(_G.ChatFrame1)
        if host then return host end
        for index = 1, WINDOWS do
            host = Usable(_G["ChatFrame" .. index])
            if host then return host end
        end
        return _G.ChatFrame1
    end

    -- The channels button's glow, or the social button's toast animations.
    local TOAST_ANIMS = { "FriendToToastAnim", "ToastActiveAnim", "ToastToToastAnim" }
    local function Flashing(button)
        if IsWidget(button.Flash) and button.Flash:IsShown() then return true end
        for _, key in ipairs(TOAST_ANIMS) do
            local anim = button[key]
            if anim and anim:IsPlaying() then return true end
        end
        return false
    end

    -- The letter buttons on `skin` now, to fade with it.
    function SkinLetters(skin)
        local list = {}
        if not skin then return list end
        for button in pairs(lettered) do
            local ghost = ghostLetters[button]
            local host = ghost and ghost:GetParent() or button:GetParent()
            if host == skin then list[#list + 1] = button end
        end
        return list
    end

    -- An addon button's letter: on the button itself, its pictures off.
    local function Letter(button, key)
        if lettered[button] then return end
        lettered[button] = key
        Panel.Letter(button, LETTERS[key] or "?", Art(button))
    end

    -- A game button's letter: a ghost on `skin` over it; its toast (a
    -- friend's queue) still shown.
    local function GhostLetter(button, key, skin)
        local ghost = ghostLetters[button]
        if not ghost then
            lettered[button] = key
            local _, frame = Panel.Ghost(skin, button, LETTERS[key] or "?")
            ghost = frame
            ghostLetters[button] = ghost
            for _, part in ipairs({ "Toast", "Toast2" }) do
                if IsWidget(button[part]) then button[part]:SetIgnoreParentAlpha(true) end
            end
        end
        if ghost:GetParent() ~= skin then ghost:SetParent(skin) end
        ghost:SetFrameStrata(skin:GetFrameStrata())
        ghost:SetFrameLevel(skin:GetFrameLevel() + 14)
        return ghost
    end

    -- Each button's bottom right GAP over the panel's top right, `x` left of it; the
    -- game's anchored to the window, PAD + SCROLL_ROOM in and PAD down from the panel's.
    local WINDOW_X, WINDOW_Y = Look.PAD + Look.SCROLL_ROOM, Look.PAD + Look.GAP

    local function Placed(button, base, x)
        return HasPoint(button, "BOTTOMRIGHT", base, x + WINDOW_X, WINDOW_Y)
    end

    -- The main window's button column's: hidden with it when another docked
    -- window shows, so given to UIParent.
    local REPARENT = { ChatFrameMenuButton = true, ChatFrameChannelButton = true }

    -- The addon's frames move in combat too (a tab clicked mid-fight keeps
    -- its letters); the game's buttons only out of it.
    local function LayHeader(host, skin)
        local base, inCombat = Base(host), InCombatLockdown()
        if inCombat then pending = true end
        local x = 0
        for _, key in ipairs(ORDER) do
            local button, mine = Button(key), own[key]
            if button then
                if mine then
                    Letter(button, key)
                    if button:GetParent() ~= skin then button:SetParent(skin) end
                    button:ClearAllPoints()
                    button:SetPoint("BOTTOMRIGHT", skin, "TOPRIGHT", x, Look.GAP)
                else
                    Try(GhostLetter, button, key, skin)
                    if not inCombat then
                        if REPARENT[key] and button:GetParent() ~= UIParent then button:SetParent(UIParent) end
                        if not Placed(button, base, x) then
                            button:ClearAllPoints()
                            button:SetPoint("BOTTOMRIGHT", base, "TOPRIGHT", x + WINDOW_X, WINDOW_Y)
                        end
                        button:SetAlpha(0)
                    end
                end
                if mine or not inCombat then
                    button:SetFrameStrata(skin:GetFrameStrata())
                    button:SetFrameLevel(skin:GetFrameLevel() + 12)
                    button:SetSize(Look.ICON, Look.ICON)
                end
                if Shown(button) then x = x - STEP end
            end
        end
        Panel.Paint(skin)       -- each letter as faded as its panel
    end

    local headerHost
    local styling = false       -- (laying it out leads back here)
    local function StyleHeaderButtons(chatFrame)
        if styling then return end
        local host = Usable(chatFrame) or VisibleSkinHost()
        local skin = host and skins[host]
        if not skin then return end
        headerHost = host
        styling = true
        Try(LayHeader, host, skin)
        styling = false
    end
    Look.Layout = StyleHeaderButtons

    -- Which header buttons show, a bit each in ORDER: nothing built to compare.
    local function HeaderState()
        local state, bit = 0, 1
        for _, key in ipairs(ORDER) do
            local button = Button(key)
            if button and Shown(button) then state = state + bit end
            bit = bit * 2
        end
        return state
    end

    -- A game button the game moved (the social button, by its alert frame) put back.
    local function KeepHeaderButtons()
        local host = headerHost
        if not (host and skins[host]) then return end
        local base, x = Base(host), 0
        for _, key in ipairs(ORDER) do
            local button = Button(key)
            if button and not own[key] then
                if not Placed(button, base, x) then return StyleHeaderButtons(host) end
                Unseen(button)
            end
            if button and Shown(button) then x = x - STEP end
        end
    end

    -- THE GAME'S ALERTS (a friend online...) at the screen's left edge over the letters'
    -- row; one the game stacked on the social button (in the header now) to the stack's foot.
    local function KeepAlerts()
        local alerts, skin = _G.ChatAlertFrame, DockedSkin()
        if not (IsWidget(alerts) and skin) then return end
        local high = skin:GetTop()
        if not high then return end
        local y = high + Look.TOP_ROOM
        if not HasPoint(alerts, "BOTTOMLEFT", UIParent, 0, y) then
            alerts:ClearAllPoints()
            alerts:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, y)
        end
        local social = Button("QuickJoinToastButton")
        if not social then return end
        for _, system in ipairs(alerts.alertFrameSubSystems or NONE) do
            local frame = system.anchorFrame
            if frame ~= social and IsWidget(frame) and Shown(frame) and HasPoint(frame, "BOTTOMLEFT", social, 0, 0) then
                frame:ClearAllPoints()
                frame:SetPoint("BOTTOMLEFT", alerts, "BOTTOMLEFT", 0, 0)
            end
        end
    end

    -- The panel the header is on now (the copy button asks).
    function Look.Header()
        if not applied then return nil end
        local host = VisibleSkinHost()
        return host and skins[host]
    end

    -- The copy button joins the row (Chat.lua).
    function Look.AddOwn(key, button)
        own[key] = button
        if applied then StyleHeaderButtons() end
    end

    ---------------------------------------------------------------------------
    -- THE EDIT BOX: over the window's last EDIT_RISE, its art gone, a box of
    -- ours behind it; the mouse only while typed in (between messages a click
    -- reaches the links under it). Never hooked: the game writes the chat type
    -- right after showing/focusing it, and our closure there taints it. Kept in
    -- step by Sync. The one hook, the Tab key's, is on the main windows' boxes
    -- only (a whisper window's would break its secret name).
    ---------------------------------------------------------------------------

    local backs = {}            -- an edit box -> the addon's box behind it
    Look.backs = backs

    local function IMStyle() return C_CVar.GetCVar("chatStyle") == "im" end

    -- One of the main windows' boxes, not a whisper window's.
    local function Permanent(box)
        local name = box:GetName()
        local index = type(name) == "string" and tonumber(name:match("^ChatFrame(%d+)EditBox$"))
        return index ~= nil and index <= WINDOWS
    end

    -- TAB TAKES THE NAME: after the game's Tab filled in a name after a command
    -- (always the list's first), the cursor to its end. Never SetText: text set
    -- by addon code taints the box, and a /cast after would be blocked.
    local function TabComplete(box)
        local list = _G.AutoCompleteBox
        if not (IsWidget(list) and list:IsShown() and list.parent == box) then return end
        local button = _G.AutoCompleteButton1
        local info = button and button.nameInfo
        if type(info) ~= "table" or type(info.name) ~= "string" then return end
        local text = box:GetText()
        if type(text) ~= "string" or Secret(text) then return end
        local command = text:match("^(/[^%s]+%s+)")
        local name = Ambiguate and Ambiguate(info.name, "all") or info.name
        if not command or text:lower() ~= (command .. name):lower() then return end
        box:SetCursorPosition(#text)
        box:HighlightText(#text, #text)
    end

    -- One box in step: the mouse while typed in, unseen between messages in the
    -- IM style; ours behind it a level under, faded with the panel (whole at its top).
    local function SyncBox(box, back, im)
        local focus = box:HasFocus()
        if Secret(focus) then return end
        focus = focus and true or false
        local mouse = box:IsMouseEnabled()
        if not Secret(mouse) and (mouse and true or false) ~= focus then Quietly(box, "EnableMouse", focus) end
        local shown = box:IsShown()
        if Secret(shown) then return end
        if im and shown and not focus then Unseen(box) end
        local want = shown and (focus or not im)
        ShowAs(back, want)
        if not want then return end
        local skin = back.skin
        local alpha = skin and math.min(1, skin.bgAlpha / Panel.HOVER_ALPHA)
        if alpha and back.bg:GetAlpha() ~= alpha then back.bg:SetAlpha(alpha) end
        Beneath(back, box)
    end

    local function StyleEditBox(chatFrame)
        local box = chatFrame.editBox
        if not IsWidget(box) then return end
        BlankNamed(box:GetName(), EDIT_ART)
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", -2, Look.EDIT_RISE)
        box:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 2, Look.EDIT_RISE)
        if not backs[box] then
            local back = CreateFrame("Frame", nil, UIParent)
            back:SetPoint("TOPLEFT", box, "TOPLEFT", EDIT_INSET, -EDIT_INSET)
            back:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -EDIT_INSET, EDIT_INSET)
            back:EnableMouse(false)
            back.bg = back:CreateTexture(nil, "BACKGROUND", nil, -8)
            back.bg:SetAllPoints(back)
            local tone = Style.WINDOW_BACKGROUND
            back.bg:SetColorTexture(tone[1], tone[2], tone[3], 1)
            backs[box] = back
            if Permanent(box) then box:HookScript("OnTabPressed", TabComplete) end
        end
        backs[box].skin = skins[chatFrame]
        SyncBox(box, backs[box], IMStyle())
    end

    ---------------------------------------------------------------------------
    -- One window: its art stripped, its scrollbar ours, its button column out
    -- of sight, its messages kept (no fading), its panel.
    ---------------------------------------------------------------------------

    -- The jump-to-newest arrow: images cleared (its flash animates its own
    -- opacity) and deaf; the wheel still scrolls.
    local function HideScrollToBottom(chatFrame)
        local arrow = chatFrame.ScrollToBottomButton
        if not IsWidget(arrow) then return end
        local art = Art(arrow)
        if IsWidget(arrow.Flash) then art[#art + 1] = arrow.Flash end
        for _, texture in ipairs(art) do Blank(texture) end
        arrow:EnableMouse(false)
    end

    -- THE COMBAT LOG'S FILTER ROW: hung by the game on the log's tab (out of
    -- sight here), so given to the log window (EllesmereUI's way); its filters a +.
    local function StyleCombatLog()
        local row = _G.CombatLogQuickButtonFrame_Custom
        local log = _G.ChatFrame2 or _G.COMBATLOG
        if not IsWidget(row) or not IsWidget(log) then return end
        if row:GetParent() ~= log then row:SetParent(log) end
        local strip = _G.CombatLogQuickButtonFrame_CustomTexture
        if IsWidget(strip) then strip:SetAlpha(0) end
        local filters = _G.CombatLogQuickButtonFrame_CustomAdditionalFilterButton
        local skin = skins[log]
        if IsWidget(filters) and skin then
            GhostLetter(filters, "filters", skin)
            filters:SetAlpha(0)
            Panel.Paint(skin)
        end
    end

    -- The text's whole height; again whenever the game anchors it, seen by Watch.
    local function PlaceScrollBar(chatFrame)
        local bar = IsWidget(chatFrame) and chatFrame.ScrollBar
        if not IsWidget(bar) or not skins[chatFrame] then return end
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", chatFrame, "TOPRIGHT", 0, 0)
        bar:SetPoint("BOTTOMLEFT", chatFrame, "BOTTOMRIGHT", 0, 0)
    end

    local function KeepScrollBar(chatFrame)
        local bar = chatFrame.ScrollBar
        if not IsWidget(bar) or not Shown(chatFrame) then return end
        local point, relative, relativePoint = bar:GetPoint(2)
        if point ~= "BOTTOMLEFT" or relative ~= chatFrame or relativePoint ~= "BOTTOMRIGHT" then
            PlaceScrollBar(chatFrame)
        end
    end

    local function StyleChatFrame(chatFrame)
        if not IsWidget(chatFrame) or (chatFrame.IsForbidden and chatFrame:IsForbidden()) then return end
        BlankNamed(chatFrame:GetName(), CHAT_FRAME_TEXTURES or NONE)
        local bar = chatFrame.ScrollBar
        if bar and IsWidget(bar.Background) then
            bar.Background:SetAlpha(0)
            bar.Background:Hide()
        end
        Try(Panel.ScrollBar, bar)
        Try(HideScrollToBottom, chatFrame)
        ButtonColumn(chatFrame)
        chatFrame:SetFading(false)
        chatFrame:SetTimeVisible(9999)
        SkinFrame(chatFrame)
        PlaceScrollBar(chatFrame)
    end

    -- The main chat's panel on view and the sidebar beside it (Unlock Mode measures them).
    function Look.ShownPanel()
        local skin = DockedSkin()
        return skin, skin and side:IsVisible() and side or nil
    end

    function Look.Apply()
        if InCombatLockdown() then
            pending = true
            return
        end
        pending = false
        EachWindow(function(frame)
            Try(StyleChatFrame, frame)
            Try(StyleEditBox, frame)
        end)
        applied = true
        Try(Core.Fonts.ApplyChat)      -- a new window in the player's chat font too
        Try(StyleCombatLog)
        Try(StyleHeaderButtons)
        Try(AdoptDock)
        -- The secure rows placed now, not at the first frame: a /reload in
        -- combat locks them from the first frame on.
        Try(SyncSide)
        Try(UpdateTabs)
        Try(Core.Chat.Refresh)      -- the copy button, the defaults
    end

    -- THE SOUND BUTTON: the game's Enable Sound off or on, the wheel the master
    -- volume; its letter grey while the sound is off.

    local function SoundOn() return C_CVar.GetCVar("Sound_EnableAllSound") ~= "0" end
    local function Volume() return tonumber(C_CVar.GetCVar("Sound_MasterVolume")) or 1 end

    local soundLetter
    local function UpdateSound()
        local colour = SoundOn() and Panel.LETTER_COLOR or Panel.MUTED
        soundLetter:SetTextColor(colour[1], colour[2], colour[3])
    end

    local function SoundTooltip(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(SoundOn() and ("Sound: %d%%"):format(math.floor(Volume() * 100 + 0.5)) or "Sound: off", 1, 1, 1)
        GameTooltip:AddLine("Click: all sound off or on. Wheel: volume.", nil, nil, nil, true)
        GameTooltip:Show()
    end

    local sound = CreateFrame("Button", "DogsForeverUIChatSoundButton", UIParent)
    sound:SetSize(Look.ICON, Look.ICON)
    sound:RegisterForClicks("LeftButtonUp")
    sound:SetScript("OnClick", function(self)
        C_CVar.SetCVar("Sound_EnableAllSound", SoundOn() and "0" or "1")
        UpdateSound()
        SoundTooltip(self)
    end)
    sound:EnableMouseWheel(true)
    sound:SetScript("OnMouseWheel", function(self, delta)
        local volume = math.max(0, math.min(1, Volume() + (delta > 0 and 0.05 or -0.05)))
        C_CVar.SetCVar("Sound_MasterVolume", ("%.2f"):format(volume))
        UpdateSound()
        SoundTooltip(self)
    end)
    sound:SetScript("OnEnter", SoundTooltip)
    sound:SetScript("OnLeave", function() GameTooltip:Hide() end)
    sound:RegisterEvent("CVAR_UPDATE")
    sound:SetScript("OnEvent", function(_, _, name)
        if name == "Sound_EnableAllSound" or name == "Sound_MasterVolume" then UpdateSound() end
    end)
    lettered[sound] = "sound"
    soundLetter = Panel.Letter(sound, LETTERS.sound, {})
    UpdateSound()
    own.sound = sound

    ---------------------------------------------------------------------------
    -- DEFAULTS: the game's own chat settings, each step ONCE per character
    -- (chatDefaults counts them; a reset puts it back), once the settings are
    -- trusted and out of combat. Steps 1-3: every window's font size FONT_SIZE
    -- as the game's menu sets it (three: the default went 14, 12, 12 for
    -- everyone). Step 4: New Whispers "New Tab".
    ---------------------------------------------------------------------------

    local function ChatSize()
        for index = 1, WINDOWS do
            local frame = _G["ChatFrame" .. index]
            if IsWidget(frame) then
                local file, _, flags = frame:GetFont()
                if file then frame:SetFont(file, Look.FONT_SIZE, flags or "") end
                if SetChatWindowSize then SetChatWindowSize(index, Look.FONT_SIZE) end
            end
        end
        Core.Fonts.ApplyChat()
    end

    local STEPS = { ChatSize, ChatSize, ChatSize, function() C_CVar.SetCVar("whisperMode", WHISPER_MODE) end }
    Look.DEFAULT_STEPS = #STEPS

    local function Defaults()
        local db = Core.Chat.db
        if db.chatDefaults >= #STEPS then return true end
        if not Core.SettingsTrusted() or InCombatLockdown() then return false end
        for index = db.chatDefaults + 1, #STEPS do STEPS[index]() end
        db.chatDefaults = #STEPS
        return true
    end
    Look.TryDefaults = Core.Retry(Defaults)

    ---------------------------------------------------------------------------
    -- THE WATCHER, in place of every hook (EllesmereUI's). Watch, five times a
    -- second: new windows styled, the tabs and header redone when the dock or
    -- the buttons shown change, whatever the game placed again put back, its
    -- chat font made the player's, flashing buttons blinked. Sync, every
    -- frame: panels, sidebar, letters and edit boxes kept with their owners.
    ---------------------------------------------------------------------------

    -- The dock as a list of values, written into one of two kept lists and
    -- compared value by value: nothing built five times a second.
    local state, last = {}, {}
    local count, lastCount = 0, -1
    local function Put(value)
        count = count + 1
        state[count] = value
    end
    -- A tab's words, "" for a secret, and the tab.
    local function TabWords(frame)
        local tab = TabOf(frame)
        local words = tab and tab:GetText()
        if type(words) ~= "string" or Secret(words) then words = "" end
        return words, tab
    end
    local function PutFloat(frame)
        if not frame.isDocked and Shown(frame) then
            Put(frame)
            Put((TabWords(frame)))
        end
    end

    local function DockChanged()
        count = 0
        Put(CHAT_FRAMES and #CHAT_FRAMES or 0)
        local dock = Dock()
        local docked = IsWidget(dock) and dock.DOCKED_CHAT_FRAMES
        for _, frame in ipairs(docked or NONE) do
            if IsWidget(frame) then
                local words, tab = TabWords(frame)
                Put(frame)
                Put(tab ~= nil and Alerting(tab))
                Put(words)
            end
        end
        Put(Selected() or false)
        EachWindow(PutFloat)
        local changed = count ~= lastCount
        for index = 1, changed and 0 or count do
            if state[index] ~= last[index] then
                changed = true
                break
            end
        end
        state, last, lastCount = last, state, count
        return changed
    end

    -- (A window the game will not let be styled is tried once, not five times a second.)
    local met = {}
    local fresh = false
    local function Meet(frame)
        if not skins[frame] and not met[frame] then fresh = true end
        met[frame] = true
    end

    local lastHeader
    local function Watch()
        if not applied then return end
        for button, key in pairs(lettered) do
            if key ~= "filters" then Panel.Alert(button, Shown(button) and Flashing(button)) end
        end
        if DockChanged() then
            fresh = false
            EachWindow(Meet)
            if fresh then
                Look.Apply()
            else
                Try(StyleHeaderButtons, Selected())
            end
            Try(UpdateTabs)
        end
        local header = HeaderState()
        if header ~= lastHeader then
            lastHeader = header
            Try(StyleHeaderButtons, Selected())
        end
        Try(AdoptDock)
        if InCombatLockdown() then return end
        for frame in pairs(skins) do Try(KeepScrollBar, frame) end
        Try(KeepHeaderButtons)
        Try(Core.Fonts.KeepChat)
    end

    local lastSelected
    local function Sync()
        if not applied then return end
        local primary = Primary()
        for frame, skin in pairs(skins) do
            PlaceSkin(frame, primary)
            SyncSkin(frame, skin)
            ButtonColumn(frame)
        end
        SyncSide()
        KeepAlerts()
        for button, ghost in pairs(ghostLetters) do
            local want = button:IsVisible()
            ShowAs(ghost, not Secret(want) and want)
        end
        local im = IMStyle()
        for box, back in pairs(backs) do SyncBox(box, back, im) end
        -- A tab clicked: gold and the letters on its panel now, not at the next look.
        local selected = Selected()
        if selected ~= lastSelected then
            lastSelected = selected
            StyleHeaderButtons(selected)
            Try(UpdateTabs)
        end
    end

    local sinceWatch = 0
    CreateFrame("Frame"):SetScript("OnUpdate", function(_, elapsed)
        Sync()
        sinceWatch = sinceWatch + elapsed
        if sinceWatch < Look.WATCH_EVERY then return end
        sinceWatch = 0
        Watch()
    end)

    -- Applied AT LOGIN, under the loading screen (as EllesmereUI does): any later and the
    -- game's own chat showed after a reload. The later passes are backstops.
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("LOADING_SCREEN_DISABLED")
    events:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" then
            -- The combat log loads when first wanted: its filter row then.
            if name == "Blizzard_CombatLog" and applied then C_Timer.After(0.2, Look.Apply) end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pending then Look.Apply() end
        else
            Try(Look.Apply)
            C_Timer.After(0.2, Look.Apply)
        end
    end)
end
