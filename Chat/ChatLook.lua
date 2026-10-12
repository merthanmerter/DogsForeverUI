-- THE CHAT'S LOOK: FlareUI's chat layout (Flare\FlareUI\Modules\Chat.lua) -
-- a panel round each window, letter buttons over its top right, the tabs
-- in a sidebar left of it, the box typed into over its last lines - drawn in the addon's own look: its panel
-- (Core\Panel.lua - the dark tone, none of it until the mouse is over the
-- chat or a message is being typed, then at half), the minimap letters'
-- font and gold, letters for the header buttons, the addon's scrollbar.
--
-- BUILT THE WAY ELLESMEREUI BUILDS ITS CHAT (EllesmereUIChat.lua,
-- EllesmereUIChat_Tabs.lua), NOT FLARE'S WAY (the player, 2026-10-03: "my
-- whispers not working ... actually they worked AFTER reloading. SOMETHING IS
-- TERRIBLY WRONG"). Flare's tab row of its own called the game's tab click
-- (FCF_Tab_OnClick) from addon code, and hooked the game's tabs, edit boxes
-- and functions: each of those ran the addon's code inside the game's own
-- chat handling, or left a value written by it where the game reads it. The
-- game makes a whisper window inside its own whisper handling
-- (FloatingChatFrameManager_OnEvent -> FCF_OpenTemporaryWindow ->
-- FCF_DockFrame -> FCFDock_UpdateTabs ...) and hands it the sender's name, a
-- secret value; once that handling ran tainted it failed on the name, and the
-- whisper went nowhere - no tab, no line - until a /reload cleared the taint.
-- Ellesmere measured exactly this ("an insecure FCFDock_SelectWindow call
-- taints dock.selected/isDirty, and the secure whisper-window creation chain
-- reads those slots"). So, here:
--
--   * NO CALL of the game's chat management (select, close, open, dock a
--     window) and NO HOOK of any of its functions, tabs, edit boxes or
--     buttons. Nothing of the addon runs inside the game's chat handling.
--   * THE GAME'S OWN TABS ARE WHAT IS CLICKED. Its tab row (the dock) stays
--     alive, out of sight. The sidebar's rows are secure buttons that click
--     the game's tabs from the game's own secure code: every click,
--     right-click menu (new window, rename, font size ...), middle-click
--     close and the whole life of a whisper window is the game's own,
--     secure.
--   * THE HEADER'S LETTERS ARE GHOSTS: frames of the addon's that take no
--     click, anchored onto the game's buttons (never parented to them).
--   * No frame of the game's is parented to a frame of the addon's, and no
--     frame of the addon's to one of the game's chat frames: the panels, the
--     sidebar, the edit boxes' backs and the ghosts all belong to UIParent.
--     What a parent would have given (shown with the window, drawn under
--     it) the addon keeps itself, every frame (Look.Sync).
--   * What the game changes is seen by watching (Look.Watch, five times a
--     second, and Look.Sync every frame), never by hooking.
--
-- Out of combat for whatever moves the game's frames; the ghosts are the
-- addon's own and follow in combat too.

local Look = {}
DogsForeverUI.Chat.Look = Look

do -- private scope
    local Core = DogsForeverUI
    local Style, Panel = Core.Style, Core.Panel

    Look.PAD = 10               -- Flare's textPadding
    Look.SCROLL_ROOM = 8        -- the addon's scrollbar, at the messages' right
    Look.GAP = 2                -- the panel to the sidebar, the letters and the edit box
    Look.TAB_IDLE = 0.6         -- Flare's TAB_IDLE_ALPHA
    Look.TAB_INSET = 8          -- an undocked tab's words from its left end, at the least
    Look.EDIT_RISE = 30         -- the edit box over the window's last 30 (Flare's)
    Look.EDIT_INSET = 2         -- the addon's box inside the edit box
    Look.ICON = 16              -- a header button (a letter)
    Look.ICON_GAP = 4           -- between two
    Look.TOP_ROOM = Look.GAP + Look.ICON    -- the letters' row over the panel
    Look.TAB_FONT_SIZE = 13
    Look.GREY = { 0.56, 0.51, 0.46 }    -- Flare's tabInactiveColor
    Look.SIDE_WIDTH = 100       -- the tabs' sidebar, left of the panel
    Look.SIDE_PAD = 2           -- its rows in from its edges
    Look.ROW = 20               -- a tab's row in it
    Look.ROW_GAP = 2            -- between two rows
    Look.ROW_INSET = 8          -- a row's words from its left end
    Look.ROW_HOVER = 0.08       -- a row's light under the mouse
    Look.ROW_MARK = 2           -- the window shown: a gold mark at its row's left
    Look.DOCK_AWAY = 200        -- the game's tab row, this far under the screen

    local skins = {}            -- chat window -> its skin (Flare's FlareUI_Skin)
    local side                  -- the tabs' sidebar (THE SIDEBAR)
    local done = {}             -- what was set up once: object -> true
    local pending = false       -- something waits for the end of combat
    local applied = false       -- Apply has run once

    local function IsWidget(object, kind)
        return type(object) == "table" and type(object.GetObjectType) == "function"
            and (not kind or object:GetObjectType() == kind)
    end

    local function Secret(value) return issecretvalue and issecretvalue(value) or false end

    local function Try(fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok and geterrorhandler then geterrorhandler()(err) end
        return ok
    end

    -- A write to one of the game's frames that may be refused in combat (a
    -- whisper window's are protected then): tried, a refusal left for later.
    local function Quietly(object, method, ...)
        if InCombatLockdown() then return pcall(object[method], object, ...) end
        object[method](object, ...)
        return true
    end

    -- The main chat windows, ChatFrame1 to this (the client's constant; the
    -- old NUM_CHAT_WINDOWS global is only a deprecation fallback now).
    local WINDOWS = Constants and Constants.ChatFrameConstants
        and Constants.ChatFrameConstants.MaxChatWindows or 10

    local function Dock() return _G.GeneralDockManager or _G.GENERAL_CHAT_DOCK end

    local function Primary()
        local dock = Dock()
        local primary = IsWidget(dock) and dock.primary
        return IsWidget(primary) and primary or _G.ChatFrame1
    end

    local function Selected()
        local dock = Dock()
        -- (The game's own field, read - its FCFDock_GetSelectedWindow only
        -- returns it, and no FCFDock_ function is called from here.)
        local selected = IsWidget(dock) and dock.selected
        return IsWidget(selected) and selected or nil
    end

    local function CVar(name)
        local ok, value = pcall(C_CVar.GetCVar, name)
        return ok and value or nil
    end

    -- Every chat window once: the main ones, then the game's list (whisper
    -- windows). Run five times a second, so the windows met are marked with
    -- the run's number in one table kept, not a new table each run. (Never
    -- called from inside `fn`.)
    local lastRun, run = {}, 0  -- a window -> the run that last met it
    local NONE = {}
    local function EachWindow(fn)
        run = run + 1
        for index = 1, WINDOWS do
            local frame = _G["ChatFrame" .. index]
            if IsWidget(frame) and lastRun[frame] ~= run then
                lastRun[frame] = run
                fn(frame)
            end
        end
        for _, name in ipairs(CHAT_FRAMES or NONE) do
            local frame = _G[name]
            if IsWidget(frame) and lastRun[frame] ~= run then
                lastRun[frame] = run
                fn(frame)
            end
        end
    end

    local tabFont
    local function TabFont()
        if tabFont then return tabFont end
        tabFont = CreateFont("DogsForeverUIChatTabFont")
        -- The minimap's letters' font, as every pane title (Core\Panel.lua).
        local letters = _G[Panel.LETTER_FONT]
        if type(letters) == "table" and type(tabFont.CopyFontObject) == "function" then
            tabFont:CopyFontObject(letters)
        else
            tabFont:SetFont(Style.FONT, Look.TAB_FONT_SIZE, "")
            tabFont:SetShadowColor(0, 0, 0, 1)
            tabFont:SetShadowOffset(1, -1)
        end
        return tabFont
    end

    ---------------------------------------------------------------------------
    -- StripBlizzardChatBackground: the window's background and border pieces
    -- (CHAT_FRAME_TEXTURES, the button column's with them) drawn as nothing,
    -- at no opacity and hidden - hidden, the game's fade skips them.
    ---------------------------------------------------------------------------

    local PIECES = { "Background", "TopLeftTexture", "TopRightTexture", "BottomLeftTexture",
                     "BottomRightTexture", "TopTexture", "BottomTexture", "LeftTexture", "RightTexture" }

    local function StripBlizzardChatBackground(chatFrame)
        local name = chatFrame:GetName()
        if not name then return end
        for _, list in ipairs({ PIECES, CHAT_FRAME_TEXTURES or {} }) do
            for _, key in ipairs(list) do
                local texture = _G[name .. key]
                if IsWidget(texture) then
                    if texture.SetTexture then texture:SetTexture(nil) end
                    texture:SetAlpha(0)
                    texture:Hide()
                end
            end
        end
        local bar = chatFrame.ScrollBar
        if type(bar) == "table" and IsWidget(bar.Background) then
            bar.Background:SetAlpha(0)
            bar.Background:Hide()
        end
    end

    ---------------------------------------------------------------------------
    -- THE BUTTON COLUMN beside each window (EllesmereUI's way): at no
    -- opacity, deaf to the mouse, its art drawn as nothing - NEVER hidden or
    -- re-parented. The game moves it inside the docking of a window
    -- (FCF_DockFrame -> FCF_SetButtonSide), and fades it in on an undocked
    -- window under the mouse; the opacity is put back to 0 every frame
    -- (Look.Sync), in combat too, so it never shows.
    ---------------------------------------------------------------------------

    local function ButtonColumn(chatFrame)
        local column = chatFrame.buttonFrame
        if not IsWidget(column) then return end
        local alpha = column:GetAlpha()
        if Secret(alpha) or alpha ~= 0 then Quietly(column, "SetAlpha", 0) end
        if done[column] then return end
        done[column] = true
        column:EnableMouse(false)
        for _, region in ipairs({ column:GetRegions() }) do
            if IsWidget(region, "Texture") then
                region:SetTexture(nil)
                region:SetAlpha(0)
            end
        end
    end

    ---------------------------------------------------------------------------
    -- THE SKIN round a window - PAD past the messages (and the scrollbar at
    -- their right). UIParent's child, anchored to the window; shown with it,
    -- drawn just under it (Look.Sync).
    ---------------------------------------------------------------------------

    local function Typing(chatFrame)
        local box = chatFrame.editBox
        return IsWidget(box) and box:IsShown() and box.HasFocus and box:HasFocus() or false
    end

    -- What a skin is laid round: the window itself, or for a docked window
    -- the dock's main window, whose place every docked window shares. The
    -- game moves a docked window's own top at times - the combat log's is
    -- lowered for its filter row - and the panel keeps its size from tab to
    -- tab all the same (the player, 2026-10-03: "when i click combat log the
    -- size of the panel changes in height, the size should stay exactly
    -- same").
    -- (`primary` when the caller has it already: Look.Sync, every frame.)
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

    -- Shown with its window, in its strata, a level under it. (A hidden
    -- one's layer is left until it shows: every docked window but the one
    -- on view is hidden, and this runs every frame.)
    local function SyncSkin(chatFrame, skin)
        local shown = chatFrame:IsShown()
        if Secret(shown) then return end
        if (skin:IsShown() and true or false) ~= (shown and true or false) then skin:SetShown(shown) end
        if not shown then return end
        local strata = chatFrame:GetFrameStrata()
        if not Secret(strata) and skin:GetFrameStrata() ~= strata then skin:SetFrameStrata(strata) end
        local level = chatFrame:GetFrameLevel()
        if type(level) == "number" and not Secret(level) then
            level = math.max(level - 1, 0)
            if skin:GetFrameLevel() ~= level then skin:SetFrameLevel(level) end
        end
    end

    -- The mouse over a skin or the letters' row over it (the letters fade
    -- with the skin).
    local function OverSkin(skin)
        return skin:IsMouseOver(Look.TOP_ROOM, 0, 0, 0)
    end

    -- (A docked window's panel and the sidebar fade in and out together.)
    local function OverSide(chatFrame)
        return (chatFrame.isDocked or chatFrame == Primary()) and side:IsVisible() and side:IsMouseOver()
    end

    local function CreateOrGetSkinFrame(chatFrame)
        local skin = skins[chatFrame]
        if not skin then
            skin = Panel.New(UIParent, {
                active = function()
                    return Typing(chatFrame) or OverSide(chatFrame) or OverSkin(skins[chatFrame])
                end,
                letters = function() return Look.SkinLetters(skins[chatFrame]) end,
            })
            skins[chatFrame] = skin
        end
        PlaceSkin(chatFrame)
        SyncSkin(chatFrame, skin)
        return skin
    end
    Look.panels = skins

    ---------------------------------------------------------------------------
    -- THE HEADER BUTTONS' KEYS AND LETTERS (laid out under
    -- StyleHeaderButtons, further down).
    ---------------------------------------------------------------------------

    local own = {}              -- the addon's own buttons: key -> button
    local ghostLetters = {}     -- a game button -> the ghost drawing its letter
    local lettered = {}         -- every button with a letter -> its key

    -- Right to left (Flare's HEADER_ORDER: volume, social, menu, channel).
    local ORDER = { "sound", "QuickJoinToastButton", "ChatFrameMenuButton", "ChatFrameChannelButton",
                    "ChatFrameToggleVoiceMuteButton", "ChatFrameToggleVoiceDeafenButton", "copy" }

    -- Each button's letter (Core\Panel.lua, Panel.Letter: the minimap
    -- header's letters): F the social window, / the chat menu (its slash commands), # the
    -- channels, V and D the voice chat's microphone and sound, C the copy
    -- window, S the sound.
    Look.LETTERS = {
        QuickJoinToastButton = "F", ChatFrameMenuButton = "/", ChatFrameChannelButton = "#",
        ChatFrameToggleVoiceMuteButton = "V", ChatFrameToggleVoiceDeafenButton = "D",
        copy = "C", sound = "S",
        filters = "+",          -- the combat log's filters menu (StyleCombatLog)
    }

    local function Button(key)
        if own[key] then return own[key] end
        local button = _G[key]
        return IsWidget(button) and button or nil
    end

    local function Shown(button)
        local shown = button:IsShown()
        return not Secret(shown) and shown and true or false
    end

    ---------------------------------------------------------------------------
    -- THE GAME'S TAB ROW (the dock), OUT OF SIGHT: under the screen's bottom
    -- edge, as wide as the screen (the game's own tab sizes, nothing in its
    -- overflow), at no opacity wherever the game puts it. Alive and the
    -- game's: its tabs are what the sidebar's rows click (THE SIDEBAR); the
    -- mouse never reaches them. Moved out of combat, and back whenever the
    -- game places it again.
    ---------------------------------------------------------------------------

    -- Whether `frame` has `point` on `relative` at x, y now (a secret, or a
    -- question the game will not answer: taken as yes, left alone).
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

    function Look.AdoptDock()
        local dock = Dock()
        if not IsWidget(dock) then return end
        local alpha = dock:GetAlpha()
        if Secret(alpha) or alpha ~= 0 then Quietly(dock, "SetAlpha", 0) end
        if InCombatLockdown() then return end
        local y = -Look.DOCK_AWAY
        if HasPoint(dock, "TOPLEFT", UIParent, 0, y) and HasPoint(dock, "TOPRIGHT", UIParent, 0, y) then return end
        dock:ClearAllPoints()
        dock:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, y)
        dock:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", 0, y)
    end

    ---------------------------------------------------------------------------
    -- A TAB'S WORDS, as the addon draws them - on a sidebar row, or on a
    -- ghost over an undocked window's own tab: the window's name, the window
    -- shown gold (a whisper window in its whisper colour), the others grey
    -- at TAB_IDLE, whole under the mouse, red while the game flashes one for
    -- a new message. The words are the game's tab's own, handed on, never
    -- measured (a whisper window's are secret), in the tab's own font.
    ---------------------------------------------------------------------------

    local function TabOf(frame)
        local tab = IsWidget(frame) and _G[(frame:GetName() or "?") .. "Tab"]
        return IsWidget(tab) and tab or nil
    end

    local function PaintGhost(ghost)
        local colour, alpha = ghost.colour, ghost.restAlpha
        ghost.text:SetTextColor(colour[1], colour[2], colour[3])
        ghost.text:SetAlpha(ghost.hover and 1 or alpha)
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

    local RED = { 1, 0, 0 }     -- a tab flashing for a new message

    -- The words from the frame's left end, `inset` in, cut off before its right.
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

    -- An undocked window's tab sized to its words by the game: the words as
    -- far in as the game's own padding (half of what the tab is wider than
    -- its words), as they stood on the game's tab.
    local function TabInset(tab)
        local words = tab.GetFontString and tab:GetFontString()
        local width, used = tab:GetWidth(), words and words:GetStringWidth()
        if type(width) ~= "number" or type(used) ~= "number" or Secret(width) or Secret(used) then
            return Look.TAB_INSET
        end
        return math.max(Look.TAB_INSET, math.floor((width - used) / 2 + 0.5))
    end

    -- The game's tab's words, handed on: a secret (a whisper window's name)
    -- straight to SetText, which takes one; looked at first, never compared.
    local function Words(frame, tab)
        local words = tab.GetText and tab:GetText()
        if Secret(words) then return words end
        if type(words) == "string" and words ~= "" then return words end
        local id = frame:GetID()
        local name = type(GetChatWindowInfo) == "function" and GetChatWindowInfo(id)
        if type(name) == "string" and name ~= "" and not Secret(name) then return name end
        return "Chat " .. tostring(id)
    end

    -- Whether the game flashes `tab` for a new message (its own state, kept
    -- off the tab: ChatFrameUtil.IsTabAlerting).
    local function Alerting(tab)
        local util = _G.ChatFrameUtil
        if type(util) == "table" and type(util.IsTabAlerting) == "function" then
            local ok, alerting = pcall(util.IsTabAlerting, tab)
            if ok and not Secret(alerting) then return alerting and true or false end
        end
        return IsWidget(tab.glow) and tab.glow:IsShown() and true or false
    end

    -- A temporary window's colour, its chat type's as the game's tab has it
    -- (a whisper, a pet battle log ...); the whisper colour when none.
    local function TypeColour(frame)
        local types = type(ChatTypeInfo) == "table" and ChatTypeInfo
        local info = types and (types[frame.chatType] or types.WHISPER)
        if type(info) == "table" and info.r then return { info.r, info.g, info.b } end
        return { 1, 0.5, 1 }
    end

    local function StyleGhost(ghost, frame, tab, selected)
        -- (The tab's own font: its words fit the tab the game measured.)
        local words = tab.GetFontString and tab:GetFontString()
        local file, size, flags
        if type(words) == "table" and words.GetFont then file, size, flags = words:GetFont() end
        if type(file) == "string" and type(size) == "number" and not Secret(size) then
            ghost.text:SetFont(file, size, flags or "")
            ghost.text:SetShadowColor(0, 0, 0, 1)
            ghost.text:SetShadowOffset(1, -1)
        else
            ghost.text:SetFontObject(TabFont())
        end
        ghost.text:SetText(Words(frame, tab))
        ghost.isSelected = frame == selected
        ghost.isFlashing = not ghost.isSelected and Alerting(tab)
        if ghost.isFlashing then
            ghost.colour, ghost.restAlpha = RED, 1
        elseif frame.isTemporary then
            ghost.colour, ghost.restAlpha = TypeColour(frame), ghost.isSelected and 1 or Look.TAB_IDLE
        elseif ghost.isSelected then
            ghost.colour, ghost.restAlpha = Panel.LETTER_COLOR, 1
        else
            ghost.colour, ghost.restAlpha = Look.GREY, Look.TAB_IDLE
        end
        PaintGhost(ghost)
    end

    ---------------------------------------------------------------------------
    -- AN UNDOCKED WINDOW keeps the game's own tab over it (its drag, its
    -- menu): its pictures at no opacity (the tab's own opacity
    -- is the game's, rewritten all the time - its pictures' are not), a
    -- ghost on it drawing its words, on the window's skin, taking no click.
    ---------------------------------------------------------------------------

    local floats = {}           -- an undocked window -> its tab's ghost

    local function SuppressTabRegions(tab)
        for _, region in ipairs({ tab:GetRegions() }) do
            if type(region) == "table" and region.SetAlpha then
                local alpha = region.GetAlpha and region:GetAlpha()
                if Secret(alpha) or alpha ~= 0 then region:SetAlpha(0) end
            end
        end
    end

    local function UpdateFloat(frame, seen)
        local tab = TabOf(frame)
        local skin = skins[frame]
        if not tab or not skin then return end
        SuppressTabRegions(tab)
        local ghost = floats[frame]
        if not ghost then
            ghost = CreateFrame("Frame", nil, skin)
            AddWords(ghost, Look.TAB_INSET)
            ghost:SetScript("OnEnter", Hover)
            ghost:SetScript("OnLeave", Unhover)
            -- (Motion only: the click goes on to the game's tab under it.)
            Panel.PassThrough(ghost)
            floats[frame] = ghost
        end
        ghost:ClearAllPoints()
        -- (In the letters' row over the skin, where the game's tab stands.)
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
    -- THE SIDEBAR (the player, 2026-10-05: "i want all tabs to be in the
    -- sidebar instead of top. the sidebar should be also same background
    -- with 2px spacing between the chat pane. tabs should have a scroll too
    -- and they should grow downwards"): a panel of the addon's (Core\Panel.lua:
    -- the chat panel's background and its fade, the two fading together)
    -- GAP left of the docked windows' panel, as tall as it; a row per
    -- docked window from the top down, the wheel scrolling them, a thin gold
    -- thumb at its right while they do not all fit - red while a window out
    -- of view flashes. The window shown is scrolled into view.
    --
    -- A ROW CLICKS THE GAME'S OWN TAB, SECURELY: a secure action button of
    -- type "click", its `clickbutton` the tab (as Options\Keybinds.lua clicks
    -- the game's keybinding buttons). The game's secure button code clicks
    -- the tab, so the game's tab click runs untainted, as if the tab itself
    -- was clicked: the left button selects its window, the right opens the
    -- game's tab menu, the middle closes a whisper window. No code of the
    -- addon's runs inside the game's chat handling.
    --
    -- Secure, a row is protected: shown, hidden, placed and given its tab
    -- out of combat only. So the sidebar is placed by numbers on UIParent
    -- (anchored to the chat, it would make the chat protected too) and kept
    -- in place every frame out of combat. In combat the words still follow
    -- the dock at once (a whisper's new window, red); a row whose words are
    -- not the tab it clicks (changed in the fight) is covered by a shield
    -- taking its click until the fight ends.
    ---------------------------------------------------------------------------

    local rows = {}             -- the sidebar's rows, top down
    local top = 0               -- docked windows scrolled past, over the first row
    local revealed              -- the window last scrolled into view

    -- The docked windows' panel on view: the window shown's (the docked
    -- windows all lie on the main one).
    local function DockedSkin()
        local skin = skins[Selected() or Primary()]
        return skin and skin:IsVisible() and skin or nil
    end

    -- The rows from the dock as it is now (read only). In combat too: the
    -- words at once, which tab a row clicks only out of it.
    local function UpdateSide()
        local dock = Dock()
        if not IsWidget(dock) then return end
        local docked = type(dock.DOCKED_CHAT_FRAMES) == "table" and dock.DOCKED_CHAT_FRAMES or NONE
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
                if (row:IsShown() and true or false) ~= (index <= fit) then row:SetShown(index <= fit) end
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
            -- (Changed in combat: given its tab as the fight ends.)
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
        -- (As thick on the screen as the chat's - the player, 2026-10-05:
        -- "should be same thickness with chat scrollbar".)
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
        AddWords(row, Look.ROW_INSET)
        -- A light under the mouse; the gold mark of the window shown at its left.
        row.light = row:CreateTexture(nil, "BACKGROUND")
        row.light:SetAllPoints(row)
        row.light:SetColorTexture(1, 1, 1, Look.ROW_HOVER)
        row.light:Hide()
        local gold = Panel.LETTER_COLOR
        row.mark = row:CreateTexture(nil, "ARTWORK")
        row.mark:SetColorTexture(gold[1], gold[2], gold[3], 1)
        row.mark:SetWidth(Look.ROW_MARK)
        row.mark:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.mark:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        row.mark:Hide()
        row:SetScript("OnEnter", Hover)
        row:SetScript("OnLeave", Unhover)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", Wheel)
        -- (Not protected itself: shown and hidden in combat too.)
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

    -- GAP left of `skin`, as tall as it, in its strata; as many rows as
    -- fit. Out of combat only.
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

    -- Every frame: shown with the docked windows' panel and kept beside it.
    local function SyncSide()
        if InCombatLockdown() then return end
        local skin = DockedSkin()
        if (side:IsShown() and true or false) ~= (skin ~= nil) then side:SetShown(skin ~= nil) end
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
    -- The chat's scrollbar's look (Panel.ScrollBar, the player: "apply same
    -- thin scroll of chat to the sidebar"): a thin dark track the rows'
    -- whole height, the gold thumb on it (as thick as the chat's: UpdateSide).
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

    -- The sidebar's rows and the undocked windows' ghosts again, from the
    -- dock as it is now.
    function Look.UpdateTabs()
        UpdateSide()
        local seen = {}
        EachWindow(function(frame)
            if not frame.isDocked and Shown(frame) then UpdateFloat(frame, seen) end
        end)
        for frame, ghost in pairs(floats) do
            if not seen[frame] then ghost:Hide() end
        end
    end
    Look.floats = floats

    ---------------------------------------------------------------------------
    -- StyleHeaderButtons: the header buttons are one set for every window, so
    -- they sit on the skin being looked at (Flare's VisibleSkinHost: the
    -- selected window, else the main one, else the first shown), right to
    -- left over its top right, a hidden one taking no place. Each a letter.
    --
    -- The game's buttons (the social, chat menu, channels and voice buttons)
    -- stay the game's - their parent, their clicks, their menus - moved to
    -- their place in the row (anchored to the window, never to the
    -- addon's frames) at opacity 0. Their letters are ghosts over them. The
    -- addon's own (the sound, the copy) are on the skin.
    ---------------------------------------------------------------------------

    local function Usable(frame)
        return IsWidget(frame) and skins[frame] and Shown(frame) and frame or nil
    end

    -- (The dock's window on view, as everywhere here - not SELECTED_CHAT_FRAME,
    -- which the game also points at an undocked window clicked.)
    local function VisibleSkinHost()
        local host = Usable(Selected()) or Usable(_G.ChatFrame1)
        if host then return host end
        for index = 1, WINDOWS do
            host = Usable(_G["ChatFrame" .. index])
            if host then return host end
        end
        return _G.ChatFrame1
    end

    -- Whether the game is flashing `button` now: the channels button's glow
    -- shown (ChatFrameUtil.StopFlash hides it), or the social button showing
    -- a friend's queue (QuickJoinToastMixin: its toast animations, one after
    -- the other while the toast is up).
    local TOAST_ANIMS = { "FriendToToastAnim", "ToastActiveAnim", "ToastToToastAnim" }
    local function Flashing(button)
        if IsWidget(button.Flash) and button.Flash:IsShown() then return true end
        for _, key in ipairs(TOAST_ANIMS) do
            local anim = button[key]
            if type(anim) == "table" and type(anim.IsPlaying) == "function" and anim:IsPlaying() then return true end
        end
        return false
    end

    -- The letter buttons on `skin` now - the header's (on the skin shown)
    -- and the combat log's filters (on its skin) - to fade with it
    -- (Core\Panel.lua).
    function Look.SkinLetters(skin)
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
        local art = {}
        for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
            local texture = type(button[get]) == "function" and button[get](button)
            if texture then art[#art + 1] = texture end
        end
        Panel.Letter(button, Look.LETTERS[key] or "?", art)
    end

    -- A game button's letter: a ghost on `skin` over it; the button itself
    -- at no opacity - all its pictures with it, whatever the game sets them
    -- to - and its toast (a friend's queue, beside the social button) shown
    -- still.
    local function GhostLetter(button, key, skin)
        local ghost = ghostLetters[button]
        if not ghost then
            lettered[button] = key
            local _, frame = Panel.Ghost(skin, button, Look.LETTERS[key] or "?")
            ghost = frame
            ghostLetters[button] = ghost
            for _, part in ipairs({ "Toast", "Toast2" }) do
                if IsWidget(button[part]) and button[part].SetIgnoreParentAlpha then
                    button[part]:SetIgnoreParentAlpha(true)
                end
            end
        end
        if ghost:GetParent() ~= skin then ghost:SetParent(skin) end
        ghost:SetFrameStrata(skin:GetFrameStrata())
        ghost:SetFrameLevel(skin:GetFrameLevel() + 14)
        return ghost
    end
    Look.ghostLetters = ghostLetters

    -- THE ROW OVER THE PANEL'S TOP RIGHT (the player, 2026-10-05: "move
    -- buttons over the chatbar instead to top right of the frame"): each
    -- button's bottom right corner GAP over the skin's top right, `x` left
    -- of it - the addon's own on the skin; the game's on the window under it,
    -- whose top right the skin's is PAD + SCROLL_ROOM out and PAD up from.
    local WINDOW_X, WINDOW_Y = Look.PAD + Look.SCROLL_ROOM, Look.PAD + Look.GAP

    local function Placed(button, base, x)
        return HasPoint(button, "BOTTOMRIGHT", base, x + WINDOW_X, WINDOW_Y)
    end

    -- The chat menu and channels buttons are the main window's button
    -- column's, hidden with it whenever another docked window is on view:
    -- given to UIParent - a frame of the game's, never one of the addon's.
    local REPARENT = { ChatFrameMenuButton = true, ChatFrameChannelButton = true }

    -- The row on `host`'s skin. The addon's own buttons and the game's
    -- buttons' letters are the addon's frames: moved in combat too, so a tab
    -- clicked mid-fight keeps its letters (they hide with the skin they were
    -- on). The game's buttons themselves only out of combat - anchored to
    -- the dock's main window, every docked window's place, they rarely need
    -- it - the rest left for the fight's end.
    local function LayHeader(host, skin)
        local base, inCombat = Base(host), InCombatLockdown()
        if inCombat then pending = true end
        local x = 0
        for _, key in ipairs(ORDER) do
            local button = Button(key)
            if button and own[key] then
                Letter(button, key)
                if button:GetParent() ~= skin then button:SetParent(skin) end
                button:ClearAllPoints()
                button:SetPoint("BOTTOMRIGHT", skin, "TOPRIGHT", x, Look.GAP)
                button:SetFrameStrata(skin:GetFrameStrata())
                button:SetFrameLevel(skin:GetFrameLevel() + 12)
                button:SetSize(Look.ICON, Look.ICON)
            elseif button then
                Try(GhostLetter, button, key, skin)
                if not inCombat then
                    if REPARENT[key] and button:GetParent() ~= UIParent then button:SetParent(UIParent) end
                    if not Placed(button, base, x) then
                        button:ClearAllPoints()
                        button:SetPoint("BOTTOMRIGHT", base, "TOPRIGHT", x + WINDOW_X, WINDOW_Y)
                    end
                    button:SetAlpha(0)
                    button:SetFrameStrata(skin:GetFrameStrata())
                    button:SetFrameLevel(skin:GetFrameLevel() + 12)
                    button:SetSize(Look.ICON, Look.ICON)
                end
            end
            if button and Shown(button) then x = x - Look.ICON - Look.ICON_GAP end
        end
        -- (Each letter as faded as the skin it is on now.)
        Panel.Paint(skin)
    end

    local headerHost
    local styling = false       -- (laying it out leads back here: once at a time)
    function Look.StyleHeaderButtons(chatFrame)
        if styling then return end
        local host = Usable(chatFrame) or VisibleSkinHost()
        local skin = host and skins[host]
        if not skin then return end
        headerHost = host
        styling = true
        Try(LayHeader, host, skin)
        styling = false
    end
    Look.Layout = Look.StyleHeaderButtons

    -- Which header buttons show now, as one number (a bit each, in ORDER):
    -- looked at five times a second, so nothing is built to compare.
    local function HeaderState()
        local state, bit = 0, 1
        for _, key in ipairs(ORDER) do
            local button = Button(key)
            if button and Shown(button) then state = state + bit end
            bit = bit * 2
        end
        return state
    end

    -- The game's buttons where they belong: a game button the game moved
    -- (the social button, placed by the game's alert frame) put back.
    local function KeepHeaderButtons()
        local host = headerHost
        if not (host and skins[host]) then return end
        local base, x = Base(host), 0
        for _, key in ipairs(ORDER) do
            local button = Button(key)
            if button and not own[key] then
                if not Placed(button, base, x) then return Look.StyleHeaderButtons(host) end
                local alpha = button:GetAlpha()
                if Secret(alpha) or alpha ~= 0 then button:SetAlpha(0) end
            end
            if button and Shown(button) then x = x - Look.ICON - Look.ICON_GAP end
        end
    end

    ---------------------------------------------------------------------------
    -- THE GAME'S ALERTS OVER THE CHAT (ChatAlertFrame: a friend online, a
    -- world switch coming, ...) at the screen's left edge, over the panel
    -- and its letters' row (the player, 2026-10-07: "these notifications
    -- should be placed correctly, snapping to the left of screen"). The game
    -- stacks them on the social button when it shows (AlertContainerMixin:
    -- UpdateAnchors), and that sits in the header now (LayHeader): an alert
    -- put on it goes back to the stack's foot. Every frame, so none is seen
    -- at the header; none of them protected, so in combat too.
    ---------------------------------------------------------------------------

    local function KeepAlerts()
        local alerts, skin = _G.ChatAlertFrame, DockedSkin()
        if not (IsWidget(alerts) and skin) then return end
        local top = skin:GetTop()
        if not top then return end
        local y = top + Look.TOP_ROOM
        if not HasPoint(alerts, "BOTTOMLEFT", UIParent, 0, y) then
            alerts:ClearAllPoints()
            alerts:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, y)
        end
        local social = Button("QuickJoinToastButton")
        if not social then return end
        -- (The game's own list, read.)
        for _, system in ipairs(alerts.alertFrameSubSystems or NONE) do
            local frame = system.anchorFrame
            if frame ~= social and IsWidget(frame) and Shown(frame) and HasPoint(frame, "BOTTOMLEFT", social, 0, 0) then
                frame:ClearAllPoints()
                frame:SetPoint("BOTTOMLEFT", alerts, "BOTTOMLEFT", 0, 0)
            end
        end
    end

    -- The skin the header buttons are on now (the copy button asks).
    function Look.Header()
        if not applied then return nil end
        local host = VisibleSkinHost()
        return host and skins[host]
    end

    -- The addon's copy button joins the row (ChatButton.lua).
    function Look.AddOwn(key, button)
        own[key] = button
        if applied then Look.StyleHeaderButtons() end
    end

    ---------------------------------------------------------------------------
    -- StyleEditBox: over the window's last EDIT_RISE, as wide as the window
    -- (Flare's place - the messages run to the bottom of the panel; under
    -- the panel, tried 2026-10-05, the chat stood further from the screen's
    -- bottom than from its side: "this looks weird"); the game's art (and
    -- its brighter art while typing) gone, a box of the addon's behind it
    -- (the chat panel's colour, no border); in the IM chat style at no
    -- opacity between messages, as Flare's.
    --
    -- THE LINES UNDER IT COME FIRST (the player, 2026-10-03: "the text
    -- should be like old, go until bottom. but when clicked to a person to
    -- reply it should be priority"): unseen between messages, the box still
    -- took the clicks meant for the bottom lines - a name clicked there
    -- opened Say instead of a whisper. So the box takes the mouse only while
    -- it is being typed in; the rest of the time a click there goes through
    -- to the window - its names and links. (Moving the messages up out of
    -- its way instead was rejected.)
    --
    -- NOT ONE HOOK ON THE BOX (EllesmereUI: "an addon closure invoked by a
    -- script dispatch inside a secure execution leaves that execution
    -- tainted"): the game's own chat handling shows, focuses and deactivates
    -- the box and then writes the chat type that every message sent reads
    -- back. Its focus, its opacity and the addon's box behind it are kept
    -- in step every frame instead (Look.Sync). The one hook is the Tab key's
    -- (a key pressed, never inside the game's handling), on the main
    -- windows' boxes only - never a whisper window's (EllesmereUI: hooks on
    -- those break the secret whisper name).
    ---------------------------------------------------------------------------

    local backs = {}            -- an edit box -> the addon's box behind it
    local EDIT_ART = { "Left", "Right", "Mid", "FocusLeft", "FocusRight", "FocusMid" }

    local function IMStyle() return CVar("chatStyle") == "im" end

    -- Whether a box is one of the main windows' (1-10), not a whisper window's.
    local function Permanent(box)
        local name = box:GetName()
        local index = type(name) == "string" and tonumber(name:match("^ChatFrame(%d+)EditBox$"))
        return index ~= nil and index <= WINDOWS
    end

    -- TAB TAKES THE NAME (the player, 2026-10-03: "when i /w and start typing
    -- a name, pressing tab doesnt complete the rest"). As a name is typed
    -- after a command the game fills in the rest of the first name that fits,
    -- selected (ChatFrameEditBoxMixin:OnChar), and lists every name that fits
    -- (AutoCompleteBox); its own Tab only moves the list's highlight, and
    -- Enter takes the name. After the game's Tab, while the box still holds
    -- the name it filled in, the cursor goes to its end: the name taken,
    -- ready for the message. The text itself is never set here - text
    -- set by addon code runs the box's own text handlers as the addon's, and
    -- what the box sends after that (a /cast) would be blocked.
    function Look.TabComplete(box)
        local list = _G.AutoCompleteBox
        if not (IsWidget(list) and list:IsShown() and list.parent == box) then return end
        -- (The name filled in is always the list's first - AutoCompleteEditBox_
        -- AddHighlightedText - whichever one the game's Tab has highlighted.)
        local button = _G.AutoCompleteButton1
        local info = type(button) == "table" and button.nameInfo
        if type(info) ~= "table" or type(info.name) ~= "string" then return end
        local text = box:GetText()
        if type(text) ~= "string" or Secret(text) then return end
        local command = text:match("^(/[^%s]+%s+)")
        local name = type(Ambiguate) == "function" and Ambiguate(info.name, "all") or info.name
        if not command or text:lower() ~= (command .. name):lower() then return end
        box:SetCursorPosition(#text)
        box:HighlightText(#text, #text)
    end

    -- One box in step with its state: the mouse while typed in, at no
    -- opacity between messages in the IM style, the addon's box behind it
    -- shown with it, in its strata, a level under it, faded with its
    -- window's panel - but whole at the top of the fade, where the panel is
    -- at half: over the window's last lines, a box as see-through as the
    -- panel mixed with the text behind it (the player, 2026-10-05: "make the
    -- typebox background more darker").
    local function SyncBox(box, back, im)
        local focus = box.HasFocus and box:HasFocus()
        if Secret(focus) then return end
        focus = focus and true or false
        local mouse = box.IsMouseEnabled and box:IsMouseEnabled()
        if not Secret(mouse) and (mouse and true or false) ~= focus then Quietly(box, "EnableMouse", focus) end
        local shown = box:IsShown()
        if Secret(shown) then return end
        if im and shown and not focus then
            local alpha = box:GetAlpha()
            if Secret(alpha) or alpha ~= 0 then Quietly(box, "SetAlpha", 0) end
        end
        local want = shown and (focus or not im) and true or false
        if (back:IsShown() and true or false) ~= want then back:SetShown(want) end
        if not want then return end
        local skin = back.skin
        local alpha = skin and math.min(1, skin.bgAlpha / Panel.HOVER_ALPHA)
        if alpha and back.bg:GetAlpha() ~= alpha then back.bg:SetAlpha(alpha) end
        local strata = box:GetFrameStrata()
        if not Secret(strata) and back:GetFrameStrata() ~= strata then back:SetFrameStrata(strata) end
        local level = box:GetFrameLevel()
        if type(level) == "number" and not Secret(level) then
            level = math.max(0, level - 1)
            if back:GetFrameLevel() ~= level then back:SetFrameLevel(level) end
        end
    end

    local function StyleEditBox(chatFrame)
        local box = chatFrame.editBox or _G[(chatFrame:GetName() or "") .. "EditBox"]
        if not IsWidget(box) then return end
        local name = box:GetName()
        if name then
            for _, key in ipairs(EDIT_ART) do
                local texture = _G[name .. key]
                if IsWidget(texture) then
                    texture:Hide()
                    texture:SetAlpha(0)
                    if texture.SetTexture then texture:SetTexture(nil) end
                end
            end
        end
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", -2, Look.EDIT_RISE)
        box:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 2, Look.EDIT_RISE)
        if not backs[box] then
            local back = CreateFrame("Frame", nil, UIParent)
            back:SetPoint("TOPLEFT", box, "TOPLEFT", Look.EDIT_INSET, -Look.EDIT_INSET)
            back:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -Look.EDIT_INSET, Look.EDIT_INSET)
            back:EnableMouse(false)
            -- The chat panel's colour (the player, 2026-10-05: "typeing box
            -- same color with chat pane"): the windows' dark tone, fading
            -- with the panel, whole while it is up (SyncBox).
            back.bg = back:CreateTexture(nil, "BACKGROUND", nil, -8)
            back.bg:SetAllPoints(back)
            local tone = Style.WINDOW_BACKGROUND
            back.bg:SetColorTexture(tone[1], tone[2], tone[3], 1)
            backs[box] = back
            if Permanent(box) then box:HookScript("OnTabPressed", Look.TabComplete) end
        end
        backs[box].skin = skins[chatFrame]
        SyncBox(box, backs[box], IMStyle())
    end
    Look.backs = backs

    ---------------------------------------------------------------------------
    -- StyleChatFrame: one window - its art stripped, its scrollbar the
    -- addon's, its button column out of sight, its messages kept (no fading,
    -- as Flare's), its skin.
    ---------------------------------------------------------------------------

    -- The arrow that jumps back to the newest line, under the scrollbar: its
    -- art drawn as nothing - its images cleared, not only made see-through:
    -- its flash (new lines while scrolled up) plays an animation of its own
    -- opacity, which showed it again (the player, 2026-10-03, a screenshot)
    -- - and deaf to the mouse; the wheel still scrolls back down (the
    -- player: "we dont need scroll arrow icons").
    local function HideScrollToBottom(chatFrame)
        local arrow = chatFrame.ScrollToBottomButton
        if not IsWidget(arrow) then return end
        local art = {}
        for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
            local texture = type(arrow[get]) == "function" and arrow[get](arrow)
            if texture then art[#art + 1] = texture end
        end
        if IsWidget(arrow.Flash) then art[#art + 1] = arrow.Flash end
        for _, texture in ipairs(art) do
            if texture.SetTexture then texture:SetTexture(nil) end
            texture:SetAlpha(0)
        end
        arrow:EnableMouse(false)
    end

    -- THE COMBAT LOG'S FILTER ROW (Blizzard_CombatLog: "My actions", "What
    -- happened to me?" ...): the game hangs it on the combat log's tab - at
    -- no opacity here with the whole tab row - so it showed nowhere.
    -- EllesmereUI's way: given to the combat log window itself (ChatFrame2),
    -- the frame its anchors are on already, so it stays the game's frame
    -- under the game's frames; its place is the game's, at the top of the
    -- window where the game keeps room for it. Its dark strip gone, its
    -- filters arrow a letter (+).
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

    -- THE SCROLLBAR THE TEXT'S WHOLE HEIGHT (the player, 2026-10-03: "chat
    -- scrollbar should be full height properly fit the actual text area"):
    -- the window's top right to its bottom right, in the panel's
    -- SCROLL_ROOM - not stopping over the jump-to-newest button (hidden
    -- here) as the game has it. Again whenever the game has anchored it
    -- (FCF_UpdateScrollbarAnchors: a window locked, docked or resized) -
    -- seen by Look.Watch, not hooked.
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
        StripBlizzardChatBackground(chatFrame)
        Try(Panel.ScrollBar, chatFrame.ScrollBar)
        Try(HideScrollToBottom, chatFrame)
        ButtonColumn(chatFrame)
        if chatFrame.SetFading then chatFrame:SetFading(false) end
        if chatFrame.SetTimeVisible then chatFrame:SetTimeVisible(9999) end
        CreateOrGetSkinFrame(chatFrame)
        PlaceScrollBar(chatFrame)
    end

    -- The main chat's skin that shows now and the sidebar beside it, for
    -- Unlock Mode to measure.
    function Look.ShownPanel()
        local skin = DockedSkin()
        return skin, skin and side:IsVisible() and side or nil
    end

    ---------------------------------------------------------------------------
    -- Apply (Flare's Chat:Apply): the dock adopted, every window styled with
    -- its edit box; then the tabs and the header buttons.
    ---------------------------------------------------------------------------

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
        -- (A new window - a whisper window - in the player's chat font too.)
        local fonts = Core.Fonts
        if fonts and fonts.ApplyChat then Try(fonts.ApplyChat) end
        Try(StyleCombatLog)
        Try(Look.StyleHeaderButtons)
        Try(Look.AdoptDock)
        -- (The sidebar's secure rows placed now, not at the first frame: a
        -- /reload in combat locks them from the first frame on, and the
        -- login before it is the last moment they may be - the player,
        -- 2026-10-05: "when i reload during combat no sidebar???".)
        Try(SyncSide)
        Try(Look.UpdateTabs)
        local copy = Core.Chat.ChatButton
        if copy and copy.Refresh then Try(copy.Refresh) end
        Try(Look.TryDefaults)
    end

    ---------------------------------------------------------------------------
    -- THE SOUND BUTTON (Flare's volume button): all of the game's sound off
    -- or on (its own Enable Sound setting); the wheel turns the master
    -- volume. Its letter grey while the sound is off.
    ---------------------------------------------------------------------------

    local function SetCVarValue(name, value) pcall(C_CVar.SetCVar, name, value) end
    local function SoundOn() return CVar("Sound_EnableAllSound") ~= "0" end
    local function Volume() return tonumber(CVar("Sound_MasterVolume")) or 1 end

    local soundLetter
    local function UpdateSound()
        if not soundLetter then return end
        local colour = SoundOn() and Panel.LETTER_COLOR or Panel.MUTED
        soundLetter:SetTextColor(colour[1], colour[2], colour[3])
    end

    local function SoundTooltip(button)
        if not GameTooltip then return end
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(SoundOn() and ("Sound: %d%%"):format(math.floor(Volume() * 100 + 0.5)) or "Sound: off", 1, 1, 1)
        GameTooltip:AddLine("Click: all sound off or on. Wheel: volume.", nil, nil, nil, true)
        GameTooltip:Show()
    end

    local function MakeSound()
        local button = CreateFrame("Button", "DogsForeverUIChatSoundButton", UIParent)
        button:SetSize(Look.ICON, Look.ICON)
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", function(self)
            SetCVarValue("Sound_EnableAllSound", SoundOn() and "0" or "1")
            UpdateSound()
            SoundTooltip(self)
        end)
        button:EnableMouseWheel(true)
        button:SetScript("OnMouseWheel", function(self, delta)
            local volume = math.max(0, math.min(1, Volume() + (delta > 0 and 0.05 or -0.05)))
            SetCVarValue("Sound_MasterVolume", ("%.2f"):format(volume))
            UpdateSound()
            SoundTooltip(self)
        end)
        button:SetScript("OnEnter", function(self) SoundTooltip(self) end)
        button:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
        button:RegisterEvent("CVAR_UPDATE")
        button:SetScript("OnEvent", function(_, _, name)
            if name == "Sound_EnableAllSound" or name == "Sound_MasterVolume" then UpdateSound() end
        end)
        lettered[button] = "sound"
        soundLetter = Panel.Letter(button, Look.LETTERS.sound, {})
        UpdateSound()
        return button
    end
    own.sound = MakeSound()

    ---------------------------------------------------------------------------
    -- DEFAULTS (the player, 2026-10-03: "chat font size should be 14 by
    -- default", then 12): the game's own chat settings, each step set ONCE per
    -- character - changed in the game afterwards, they stay; Reset everything
    -- puts the count back and sets them again. Only once the saved settings
    -- can be trusted (Core.SettingsTrusted) and out of combat; tried again
    -- each half second until done.
    --
    --   1. Every chat window's font size FONT_SIZE: what the game's own Font
    --      Size menu does (FCF_SetChatWindowFontSize) - the window's font at
    --      that size and the size saved with the client's SetChatWindowSize -
    --      done here with those calls, not by running the game's function.
    --   2. The same again at 12 (after 14): a character that had step 1 at
    --      14 gets 12, once.
    ---------------------------------------------------------------------------

    Look.FONT_SIZE = 12

    local function ChatSize()
        for index = 1, WINDOWS do
            local frame = _G["ChatFrame" .. index]
            if IsWidget(frame) and type(frame.GetFont) == "function" then
                local file, _, flags = frame:GetFont()
                if file then frame:SetFont(file, Look.FONT_SIZE, flags or "") end
                if type(SetChatWindowSize) == "function" then pcall(SetChatWindowSize, index, Look.FONT_SIZE) end
            end
        end
        local fonts = Core.Fonts
        if fonts and fonts.ApplyChat then fonts.ApplyChat() end
    end

    -- 3. 12 again, once, for every character (the player, 2026-10-03, again:
    --    "chat and damage meter content text should be 12px by default").
    -- 4. A whisper opens a tab of its own (the player, 2026-10-03: "when I
    --    whisper someone it doesnt create a new whisper tab"): the game's own
    --    Social setting New Whispers, "In-line" out of the box, set to "New
    --    Tab" - the game then opens the tab itself, both for a whisper
    --    received and one sent (FloatingChatFrameManager_OnEvent).
    Look.WHISPER_MODE = "popout"
    local function WhisperTabs() SetCVarValue("whisperMode", Look.WHISPER_MODE) end
    local STEPS = { ChatSize, ChatSize, ChatSize, WhisperTabs }
    Look.DEFAULT_STEPS = #STEPS

    function Look.Defaults()
        local db = Core.Chat.db
        if type(db) ~= "table" then return true end
        local count = tonumber(db.chatDefaults) or 0
        if count >= #STEPS then return true end
        if not Core.SettingsTrusted() or InCombatLockdown() then return false end
        for index = count + 1, #STEPS do STEPS[index]() end
        db.chatDefaults = #STEPS
        return true
    end

    Look.TryDefaults = Core.Retry(Look.Defaults)

    ---------------------------------------------------------------------------
    -- THE WATCHER, IN PLACE OF EVERY HOOK (EllesmereUI's state watcher,
    -- EllesmereUIChat.lua section 4). Five times a second, from the addon's
    -- own frame, outside the game's code:
    --   * a window the addon has not styled yet (a new window, a whisper
    --     window): everything applied (out of combat);
    --   * the dock changed - a window docked, closed, selected, renamed, or
    --     flashed for a new message: every tab again, the header buttons on
    --     the window selected;
    --   * the header buttons the game shows changed (a voice channel joined):
    --     the row laid out again;
    --   * a scrollbar, a header button or the dock the game placed again: put
    --     back; a button column the game faded in: out of sight again;
    --   * a chat font the game set (its Font Size menu): the player's again;
    --   * a header button the game flashes: its letter blinks.
    -- And every frame (Look.Sync): the skins, the sidebar, the letters and
    -- the edit boxes shown, hidden, placed and layered with what they belong
    -- to, and a tab clicked painted gold at once.
    ---------------------------------------------------------------------------

    local function Plain(text)
        if type(text) ~= "string" or Secret(text) then return "" end
        return text
    end

    -- The dock as a list of values: the window count, each docked window,
    -- its tab's words (a secret's left out) and whether it flashes, the
    -- window selected, and the undocked windows shown with their tabs'
    -- words (a rename). Looked at five times a second, so it is written into
    -- one of two lists kept - this look's and the last's - and compared value
    -- by value, nothing built.
    local state, last = {}, {}
    local count, lastCount = 0, -1
    local function Put(value)
        count = count + 1
        state[count] = value
    end
    local function TabWords(frame)
        local tab = TabOf(frame)
        return tab and tab.GetText and Plain(tab:GetText()) or "", tab
    end
    local function PutFloat(frame)
        if not frame.isDocked and Shown(frame) then
            Put(frame)
            Put((TabWords(frame)))
        end
    end

    -- Whether the dock changed since the last look.
    local function DockChanged()
        count = 0
        Put(type(CHAT_FRAMES) == "table" and #CHAT_FRAMES or 0)
        local dock = Dock()
        local docked = IsWidget(dock) and dock.DOCKED_CHAT_FRAMES
        if type(docked) == "table" then
            for _, frame in ipairs(docked) do
                if IsWidget(frame) then
                    local words, tab = TabWords(frame)
                    Put(frame)
                    Put(tab ~= nil and Alerting(tab))
                    Put(words)
                end
            end
        end
        local selected = Selected()
        Put(IsWidget(selected) and selected or false)
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

    -- (Once each: a window the game will not let be styled is not tried
    -- five times a second.)
    local met = {}              -- every window the watcher has seen once
    local fresh = false
    local function Meet(frame)
        if not skins[frame] and not met[frame] then fresh = true end
        met[frame] = true
    end

    local lastHeader
    function Look.Watch()
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
                Try(Look.StyleHeaderButtons, Selected())
            end
            Try(Look.UpdateTabs)
        end
        local header = HeaderState()
        if header ~= lastHeader then
            lastHeader = header
            Try(Look.StyleHeaderButtons, Selected())
        end
        Try(Look.AdoptDock)
        if InCombatLockdown() then return end
        for frame in pairs(skins) do Try(KeepScrollBar, frame) end
        Try(KeepHeaderButtons)
        local fonts = Core.Fonts
        if fonts and fonts.KeepChat then Try(fonts.KeepChat) end
    end

    local lastSelected
    function Look.Sync()
        if not applied then return end
        local primary = Primary()
        for frame, skin in pairs(skins) do
            PlaceSkin(frame, primary)   -- (docked or undocked since)
            SyncSkin(frame, skin)
            ButtonColumn(frame)
        end
        SyncSide()
        KeepAlerts()
        for button, ghost in pairs(ghostLetters) do
            local want = button:IsVisible()
            want = not Secret(want) and want and true or false
            if (ghost:IsShown() and true or false) ~= want then ghost:SetShown(want) end
        end
        local im = IMStyle()
        for box, back in pairs(backs) do SyncBox(box, back, im) end
        -- (A tab clicked: gold now, the header's letters on its skin now -
        -- not at the next look.)
        local selected = Selected()
        if selected ~= lastSelected then
            lastSelected = selected
            Look.StyleHeaderButtons(selected)
            Try(Look.UpdateTabs)
        end
    end

    Look.WATCH_EVERY = 0.2
    local clock = CreateFrame("Frame")
    local sinceWatch = 0
    clock:SetScript("OnUpdate", function(_, elapsed)
        Look.Sync()
        sinceWatch = sinceWatch + (elapsed or 0)
        if sinceWatch < Look.WATCH_EVERY then return end
        sinceWatch = 0
        Look.Watch()
    end)

    ---------------------------------------------------------------------------
    -- Init: everything applied AT LOGIN, under the loading screen
    -- (EllesmereUI skins every chat window inside PLAYER_LOGIN itself):
    -- Flare's 0.2 seconds later let the game's own chat show for a moment
    -- after a reload (the player, 2026-10-03: "After reload, i saw old
    -- default chat for awhile. it wasn't cool!"). The later passes stay as
    -- backstops.
    ---------------------------------------------------------------------------

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_LOGIN")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:RegisterEvent("LOADING_SCREEN_DISABLED")
    watcher:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" then
            -- (The combat log loads when it is first wanted: its filter row then.)
            if name == "Blizzard_CombatLog" and applied then C_Timer.After(0.2, Look.Apply) end
        elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD"
            or event == "LOADING_SCREEN_DISABLED" then
            Try(Look.Apply)
            C_Timer.After(0.2, Look.Apply)
        elseif pending then
            Look.Apply()
        end
    end)
end
