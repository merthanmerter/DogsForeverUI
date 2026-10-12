-- The chat in the addon's panel (Core\Panel.lua, Chat\ChatLook.lua -
-- Flare's layout, built EllesmereUI's way): the game's windows stripped, a
-- skin round each, the game's own tab row alive but invisible in the
-- skin's header with ghosts of the addon's drawing its tabs, the header
-- buttons letters - and NOTHING of the game's chat hooked, called or
-- re-parented to the addon's frames (the whisper windows broke on that
-- until a /reload). And the tooltip in the addon's look.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

-- Timers: queued, run by Flush (a backstop 0.2 seconds after login, ...).
local timers = {}
C_Timer = { After = function(_, func) timers[#timers + 1] = func end }
local function Flush()
    for _ = 1, 20 do
        if #timers == 0 then return end
        local list = timers
        timers = {}
        for _, func in ipairs(list) do func() end
    end
end

-- The game's frames, as the game hands them out: each says what it is.
local function Game(kind, name, parent)
    local frame = CreateFrame(kind, name, parent or UIParent)
    frame.GetObjectType = function() return kind end
    return frame
end
local function Tex(parent, name, file)
    local texture = parent:CreateTexture(name)
    texture.GetObjectType = function() return "Texture" end
    texture:SetTexture(file or "art")
    if name then _G[name] = texture end
    return texture
end
local function GameButton(name, parent)
    local button = Game("Button", name, parent)
    for _, state in ipairs({ "Normal", "Pushed", "Highlight", "Disabled" }) do
        local texture = Tex(button, nil, state)
        button["Get" .. state .. "Texture"] = function() return texture end
    end
    local text = button:CreateFontString(nil, "OVERLAY")
    button.GetFontString = function() return text end
    return button
end

-- The game's minimal scrollbar (MinimalScrollBar.xml): its track, thumb and
-- arrows, each with their art.
local function ScrollBar(parent)
    local bar = Game("EventFrame", nil, parent)
    bar.Track = Game("Frame", nil, bar)
    bar.Track.Thumb = Game("Button", nil, bar.Track)
    for _, key in ipairs({ "Begin", "Middle", "End" }) do
        bar.Track[key] = Tex(bar.Track, nil, "track")
        bar.Track.Thumb[key] = Tex(bar.Track.Thumb, nil, "thumb")
    end
    for _, key in ipairs({ "Back", "Forward" }) do
        bar[key] = Game("Button", nil, bar)
        bar[key].Texture = Tex(bar[key], nil, "arrow")
    end
    return bar
end

-- A chat window as FloatingChatFrame.xml makes it: its art, its button
-- column, its edit box (with the game's own Deactivate), its scrollbar, its
-- tab.
CHAT_FRAME_TEXTURES = { "Background", "TopLeftTexture", "ButtonFrameBackground" }
NUM_CHAT_WINDOWS = 3
local gameDeactivate = function() end
local function Window(index, tabText)
    local name = "ChatFrame" .. index
    local frame = Game("ScrollingMessageFrame", name)
    frame:SetFrameLevel(5)
    frame:SetID(index)
    frame.Background = Tex(frame, name .. "Background")
    Tex(frame, name .. "TopLeftTexture")
    Tex(frame, name .. "ButtonFrameBackground")
    frame.buttonFrame = Game("Frame", name .. "ButtonFrame", frame)
    Tex(frame.buttonFrame, nil, "column")
    frame.editBox = Game("EditBox", name .. "EditBox", frame)
    frame.editBox.HasFocus = function(self) return self.focus == true end
    frame.editBox.Deactivate = gameDeactivate
    Tex(frame.editBox, name .. "EditBoxLeft")
    Tex(frame.editBox, name .. "EditBoxFocusMid")
    frame.ScrollBar = ScrollBar(frame)
    frame.ScrollToBottomButton = GameButton(nil, frame)
    frame.ScrollToBottomButton.Flash = Tex(frame.ScrollToBottomButton, nil, "returntobottom")
    frame.SetTimeVisible = function(self, v) self.timeVisible = v end
    local tab = GameButton(name .. "Tab")
    tab:SetID(index)
    tab.GetText = function() return tabText end
    frame.isDocked = 1
    return frame, tab
end
local chat, tab = Window(1, "General")
chat.isStaticDocked = true
CHAT_FRAMES = { "ChatFrame1" }
SELECTED_CHAT_FRAME = chat
ChatTypeInfo = { WHISPER = { r = 1, g = 0.5, b = 1 }, BN_WHISPER = { r = 0, g = 1, b = 0.96 } }

-- The combat log (Blizzard_CombatLog): ChatFrame2, docked, its filter row
-- hung on its tab by the game.
local combatLog, combatTab = Window(2, "Combat Log")
combatLog.isStaticDocked = true
COMBATLOG = combatLog
local filterRow = Game("Frame", "CombatLogQuickButtonFrame_Custom", combatTab)
Tex(filterRow, "CombatLogQuickButtonFrame_CustomTexture", "strip")
local moreFilters = GameButton("CombatLogQuickButtonFrame_CustomAdditionalFilterButton", filterRow)

-- The game's name list for the box typed into (Blizzard_AutoComplete).
AutoCompleteBox = Game("Frame", "AutoCompleteBox")
AutoCompleteBox:Hide()
local nameButton = GameButton("AutoCompleteButton1", AutoCompleteBox)

-- The game's dock (FloatingChatFrame.xml): anchored to the main window's
-- background, its scrolling part with its scroll child, its overflow button
-- and the list it opens; its own scripts.
GENERAL_CHAT_DOCK = Game("Frame", "GeneralDockManager")
GENERAL_CHAT_DOCK.primary = chat
GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES = { chat }
GENERAL_CHAT_DOCK.scrollFrame = Game("ScrollFrame", "GeneralDockManagerScrollFrame", GENERAL_CHAT_DOCK)
local scrollChild = Game("Frame", nil, GENERAL_CHAT_DOCK.scrollFrame)
GENERAL_CHAT_DOCK.scrollFrame:SetScrollChild(scrollChild)
GENERAL_CHAT_DOCK.overflowButton = GameButton(nil, GENERAL_CHAT_DOCK)
GENERAL_CHAT_DOCK.overflowButton:Hide()
GENERAL_CHAT_DOCK.overflowButton.list = Game("Frame", nil, GENERAL_CHAT_DOCK.overflowButton)
GENERAL_CHAT_DOCK.overflowButton.list:Hide()
GENERAL_CHAT_DOCK.overflowButton.list:SetPoint("LEFT", GENERAL_CHAT_DOCK.overflowButton, "RIGHT")
GENERAL_CHAT_DOCK.selected = chat
GENERAL_CHAT_DOCK:SetPoint("BOTTOMLEFT", chat.Background, "TOPLEFT")
GENERAL_CHAT_DOCK:SetPoint("BOTTOMRIGHT", chat.Background, "TOPRIGHT")
local dockScript = function() end
GENERAL_CHAT_DOCK:SetScript("OnUpdate", dockScript)
function FCFDock_GetSelectedWindow(dock) return dock.selected end
-- The game's own tab click: the addon must never call it (recorded).
tabClicks = {}
function FCF_Tab_OnClick(chatTab, mouse) tabClicks[#tabClicks + 1] = { chatTab, mouse } end
-- The game laying its docked tabs out in its dock (FCFDock_UpdateTabs): the
-- main window's and the combat log's on the dock, the rest on its scroll child.
function FCFDock_UpdateTabs(dock)
    for _, frame in ipairs(dock.DOCKED_CHAT_FRAMES) do
        local chatTab = _G[frame:GetName() .. "Tab"]
        chatTab:SetParent(frame.isStaticDocked and dock or scrollChild)
        chatTab:Show()
    end
end
FCFDock_UpdateTabs(GENERAL_CHAT_DOCK)
function FCFTab_UpdateAlpha(chatFrame) _G[chatFrame:GetName() .. "Tab"]:SetAlpha(1) end
function FCF_OpenTemporaryWindow() end
function FCF_OpenNewWindow() end
function FCF_Close() end
function FCF_SelectDockFrame(frame) SELECTED_CHAT_FRAME = frame end

-- The game's functions a whisper window is made in: kept, to see that none
-- is hooked.
local FCF_NAMES = { "FCF_OpenTemporaryWindow", "FCF_OpenNewWindow", "FCF_Close", "FCF_SelectDockFrame",
                    "FCFDock_UpdateTabs", "FCFTab_UpdateAlpha", "FCF_UpdateScrollbarAnchors",
                    "FCF_StartAlertFlash", "FCF_StopAlertFlash", "FCF_SetWindowName",
                    "FCF_SetChatWindowFontSize", "FCF_Tab_OnClick", "FCFDock_GetSelectedWindow" }
function FCF_UpdateScrollbarAnchors() end
function FCF_StartAlertFlash() end
function FCF_StopAlertFlash() end
function FCF_SetWindowName() end
function FCF_SetChatWindowFontSize(_, frame, size) frame:SetFont("Fonts\\ARIALN.TTF", size, "") end
local gameFCF = {}
for _, name in ipairs(FCF_NAMES) do gameFCF[name] = _G[name] end

-- The header buttons: the chat menu and channels in the main window's
-- button column, the social and voice buttons UIParent's.
local menu = GameButton("ChatFrameMenuButton", chat.buttonFrame)
local channel = GameButton("ChatFrameChannelButton", chat.buttonFrame)
channel.Icon = Tex(channel, nil, "chatframe-button-icon-voicechat")
-- Its glow, which the game flashes (ChannelFrameButtonMixin, ChatFrameUtil.StartFlash).
channel.Flash = Tex(channel, nil, "chatframe-button-highlightalert")
channel.Flash:Hide()
local social = GameButton("QuickJoinToastButton")
social.FriendsButton = Tex(social, nil, "friends")
social.Toast = Game("Frame", nil, social)
-- Its toast's pulse while a friend's queue is shown (QuickJoinToastMixin).
social.ToastActiveAnim = { playing = false, IsPlaying = function(self) return self.playing end }
local deafen = GameButton("ChatFrameToggleVoiceDeafenButton")
deafen:Hide()
cvars.Sound_EnableAllSound = true
-- The chat's font, and the size the client keeps for each window.
chat:SetFont("Fonts\\ARIALN.TTF", 18, "")
chatWindowSizes = {}
function SetChatWindowSize(index, size) chatWindowSizes[index] = size end

-- The game's tooltip (SharedTooltipTemplate): its nine-slice art, its health
-- bar; the Edit Mode frame it is put in the corner of.
GameTooltip.GetObjectType = function() return "GameTooltip" end
GameTooltip.NineSlice = Game("Frame", nil, GameTooltip)
GameTooltip.StatusBar = Game("StatusBar", "GameTooltipStatusBar", GameTooltip)
GameTooltip.StatusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
function SharedTooltip_SetBackdropStyle(self) self.NineSlice:SetAlpha(1) end
-- Its first line (a unit's name), the unit it shows, and the game's
-- post-calls for each kind of tooltip.
GameTooltip.name = GameTooltip.name or "GameTooltip"
GameTooltipTextLeft1 = GameTooltip:CreateFontString()
tooltipUnit = nil
function GameTooltip:GetUnit() if tooltipUnit then return "someone", tooltipUnit end end
Enum = Enum or {}
Enum.TooltipDataType = Enum.TooltipDataType or { Item = 0, Spell = 1, Unit = 2 }
postCalls = {}
TooltipDataProcessor = TooltipDataProcessor or {
    AllTypes = "all",
    AddTooltipPostCall = function(kind, fn)
        postCalls[kind] = postCalls[kind] or {}
        table.insert(postCalls[kind], fn)
    end,
}
-- Its fonts, at the game's sizes.
for name, size in pairs({ GameTooltipHeaderText = 14, GameTooltipText = 12, GameTooltipTextSmall = 10 }) do
    CreateFont(name):SetFont("Fonts\\FRIZQT__.TTF", size, "")
end
GameTooltipDefaultContainer = Game("Frame", "GameTooltipDefaultContainer")
GameTooltipDefaultContainer:SetSize(250, 150)

LoadAddon()
Login()

local Core = DogsForeverUI
local Look, Style, Panel = Core.Chat.Look, Core.Style, Core.Panel

-- The watcher's next look (Look.Watch, five times a second), and what it
-- set going.
local function Watch()
    Tick(Look.WATCH_EVERY)
    Flush()
end

-- Whether `frame` has `point` on `relative` at x, y.
local function Anchored(frame, point, relative, x, y)
    for _, anchor in ipairs(frame.anchors or {}) do
        if anchor[1] == point then
            return anchor[2] == relative and (x == nil or anchor[4] == x) and (y == nil or anchor[5] == y)
        end
    end
    return false
end

local function Hooks(object)
    local count = 0
    for _, list in pairs(object.hooks or {}) do count = count + #list end
    return count
end

Section("applied AT login, under the loading screen (EllesmereUI's timing): the game's chat never shows")
do
    check("every window skinned at login itself, not a moment later", Look.panels[chat] ~= nil
        and ChatFrame1Background.texture == nil)
    Flush()
    check("and the later passes change nothing twice", Look.panels[chat] ~= nil)
end

local skin = Look.panels[chat]
local step = Look.ICON + Look.ICON_GAP

Section("the window's own art gone; its button column out of sight, never hidden")
do
    check("the window's background and border pieces drawn as nothing, hidden",
        ChatFrame1Background.texture == nil and ChatFrame1TopLeftTexture.texture == nil
        and ChatFrame1ButtonFrameBackground.texture == nil and ChatFrame1Background.shown == false)
    check("the button column at no opacity, deaf to the mouse, its art drawn as nothing",
        chat.buttonFrame.alpha == 0 and chat.buttonFrame.mouseEnabled == false
        and chat.buttonFrame.regions[1].texture == nil)
    check("never hidden, never hooked (the game moves it inside the docking of a window)",
        chat.buttonFrame.shown ~= false and Hooks(chat.buttonFrame) == 0)
    chat.buttonFrame:SetAlpha(1)            -- (the game fading it in)
    Watch()
    check("faded in by the game: out of sight again at the next look", chat.buttonFrame.alpha == 0)
    check("the messages kept, as Flare's: no fading", chat.fading == false and chat.timeVisible == 9999)
end

Section("the skin: the addon's panel round the window, UIParent's, never the window's child")
do
    check("UIParent's own, not the window's", skin.parent == UIParent)
    check("drawn a level under the window, in its strata", skin.frameLevel == 4
        and skin:GetFrameStrata() == chat:GetFrameStrata())
    check("PAD past the messages all round: no header row",
        skin.anchors[1][1] == "TOPLEFT" and skin.anchors[1][2] == chat and skin.anchors[1][4] == -Look.PAD
        and skin.anchors[1][5] == Look.PAD
        and skin.anchors[2][1] == "BOTTOMRIGHT" and skin.anchors[2][5] == -Look.PAD)
    chat:Hide()
    Tick(0)
    check("shown with its window: the window hidden, the skin with it", skin.shown == false)
    chat:Show()
    Tick(0)
    check("and back with it", skin.shown == true)
    check("no border, no line", skin.border == nil and skin.divider == nil and #skin.regions == 1)
    check("the background at no opacity to start", skin.bg.colorTexture[4] == 0)
    check("taking no mouse: clicks go through it", skin.mouseEnabled == false)

    mouseOver[skin] = true
    Tick(0.1)
    check("the mouse over it: fading in", math.abs(skin.bg.colorTexture[4] - 0.25) < 0.001)
    Tick(0.2)
    check("to half", skin.bg.colorTexture[4] == Panel.HOVER_ALPHA)
    mouseOver[skin] = nil
    Tick(0.3)
    check("the mouse away: back to none", skin.bg.colorTexture[4] == 0)
    chat.editBox.focus = true
    Tick(0.3)
    check("a message being typed keeps it at half", skin.bg.colorTexture[4] == Panel.HOVER_ALPHA)
    chat.editBox.focus = false
    Tick(0.3)
end

Section("the scrollbar in the addon's look, no arrows; the edit box, not one hook on it")
do
    local bar = chat.ScrollBar
    check("the scrollbar's art at no opacity: track, thumb",
        bar.Track.Middle.alpha == 0 and bar.Track.Thumb.Begin.alpha == 0)
    check("no arrows: each arrow button invisible, deaf to the mouse",
        bar.Back.alpha == 0 and bar.Forward.alpha == 0 and bar.Back.mouseEnabled == false)
    local arrow = chat.ScrollToBottomButton
    check("the jump-to-newest arrow's art at no opacity, deaf to the mouse",
        arrow:GetNormalTexture().alpha == 0 and arrow.Flash.alpha == 0 and arrow.mouseEnabled == false)
    local gold = bar.Track.Thumb.regions[#bar.Track.Thumb.regions]
    check("a gold thumb of the addon's on the game's", gold.colorTexture
        and gold.colorTexture[1] == Style.BORDER_COLOR[1] and gold.width == Panel.SCROLL_PIXELS)
    local track = bar.Track
    check("the track the bar's whole height: no room kept for the arrows",
        track.anchors[1][1] == "TOP" and track.anchors[1][2] == bar and track.anchors[1][5] == 0
        and track.anchors[2][1] == "BOTTOM" and track.anchors[2][2] == bar and track.anchors[2][5] == 0)
    check("the bar the text's whole height: the window's top right to its bottom right",
        bar.anchors[1][1] == "TOPLEFT" and bar.anchors[1][2] == chat and bar.anchors[1][3] == "TOPRIGHT"
        and bar.anchors[2][1] == "BOTTOMLEFT" and bar.anchors[2][2] == chat and bar.anchors[2][3] == "BOTTOMRIGHT"
        and bar.anchors[2][5] == 0)

    local box = chat.editBox
    check("the box's own art drawn as nothing",
        ChatFrame1EditBoxLeft.texture == nil and ChatFrame1EditBoxFocusMid.texture == nil)
    local back = Look.backs[box]
    check("a box of the addon's behind it - UIParent's, anchored to it: the windows' tone",
        back ~= nil and back.parent == UIParent and back.anchors[1][2] == box
        and back.bg.colorTexture[1] == Style.WINDOW_BACKGROUND[1])
    box.focus = true
    Tick(0.3)
    Tick(0)                                 -- (the panel's fade, then the box's: a frame apart)
    check("typed in: the panel up at half, the box behind the text whole - not mixing with the lines under it",
        skin.bg.colorTexture[4] == Panel.HOVER_ALPHA and back.bg.alpha == 1)
    box.focus = false
    Tick(0.3)
    Tick(0)
    check("done: faded out with the panel", back.bg.alpha == 0 and skin.bgAlpha == 0)
    local ownBorder = false
    for _, child in ipairs(allFrames) do
        if child.parent == back and child.lines then ownBorder = true end
    end
    check("no border round it", not ownBorder)
    check("over the window's last lines, as Flare's",
        box.anchors[1][1] == "TOPLEFT" and box.anchors[1][2] == chat and box.anchors[1][3] == "BOTTOMLEFT"
        and box.anchors[1][4] == -2 and box.anchors[1][5] == Look.EDIT_RISE
        and box.anchors[2][1] == "TOPRIGHT" and box.anchors[2][4] == 2)
    check("not typed in: deaf to the mouse - a name in the lines under it takes the click",
        box.mouseEnabled == false)
    box.focus = true
    Tick(0)
    check("typed in: it takes the mouse, the next frame", box.mouseEnabled == true)
    box.focus = false
    Tick(0)
    check("done typing: deaf again", box.mouseEnabled == false)
    check("NO hook on the box's focus, showing or Deactivate (the game writes the chat type after them)",
        box.hooks.OnEditFocusGained == nil and box.hooks.OnEditFocusLost == nil and box.hooks.OnShow == nil
        and box.Deactivate == gameDeactivate)
    check("the Tab key's the one hook, on a main window's box", #(box.hooks.OnTabPressed or {}) == 1)

    -- The IM chat style: the box stays up between messages; at no opacity here.
    local getCVar = C_CVar.GetCVar
    C_CVar.GetCVar = function(name) if name == "chatStyle" then return "im" end return getCVar(name) end
    box:SetAlpha(0.35)                      -- (the game's Deactivate)
    Tick(0)
    check("IM style, not typed in: the box at no opacity, the addon's box behind it hidden",
        box.alpha == 0 and back.shown == false)
    box.focus = true
    box:SetAlpha(1)
    Tick(0)
    check("typed in: the addon's box behind it", back.shown == true)
    box.focus = false
    C_CVar.GetCVar = getCVar
    Tick(0)
end

Section("the game's tab row: alive, out of sight under the screen - nothing of it hooked")
do
    local dock = GENERAL_CHAT_DOCK
    check("the dock at no opacity, shown, its mouse its own",
        dock.alpha == 0 and dock.shown ~= false and dock.mouseEnabled == nil)
    check("under the screen's bottom edge, as wide as the screen",
        Anchored(dock, "TOPLEFT", UIParent, 0, -Look.DOCK_AWAY) and Anchored(dock, "TOPRIGHT", UIParent, 0, -Look.DOCK_AWAY))
    check("its own scripts kept", dock.scripts.OnUpdate == dockScript)
    check("the game's tab: shown, its opacity the game's, the mouse its own, nothing hooked",
        tab.shown ~= false and tab.alpha ~= 0 and tab.mouseEnabled == nil and Hooks(tab) == 0)
    dock:ClearAllPoints()
    dock:SetPoint("BOTTOMLEFT", chat.Background, "TOPLEFT")    -- (the game: FCFDock_SetPrimary)
    dock:SetPoint("BOTTOMRIGHT", chat.Background, "TOPRIGHT")
    Watch()
    check("placed by the game again: out of sight again at the next look",
        Anchored(dock, "TOPLEFT", UIParent, 0, -Look.DOCK_AWAY))
    local hooked = {}
    for _, name in ipairs(FCF_NAMES) do
        if _G[name] ~= gameFCF[name] then hooked[#hooked + 1] = name end
    end
    check("none of the game's FCF_ functions hooked: a whisper window is made in them",
        #hooked == 0, table.concat(hooked, ", "))
end

-- Every docked window's panel where the game lays them out, all in one
-- place: 200 high, as many rows as fit in it.
local function PlacePanels()
    for _, panel in pairs(Look.panels) do panel.left, panel.top, panel.bottom = 120, 400, 200 end
end
PlacePanels()
local side, rows = Look.sidebar, Look.rows
local FIT = math.floor((200 - 2 * Look.SIDE_PAD + Look.ROW_GAP) / (Look.ROW + Look.ROW_GAP))
local function RowY(index) return -(Look.SIDE_PAD + (index - 1) * (Look.ROW + Look.ROW_GAP)) end

Section("the sidebar: the panel's background, GAP left of it, as tall")
do
    Tick(0)
    check("UIParent's, shown with the docked windows' panel", side.parent == UIParent and side.shown ~= false)
    check("placed by numbers on UIParent (anchored to the chat it would make the chat protected)",
        Anchored(side, "TOPRIGHT", UIParent, 120 - Look.GAP, 400) and #side.anchors == 1
        and side.width == Look.SIDE_WIDTH and side.height == 200)
    check("in the panel's strata", side:GetFrameStrata() == skin:GetFrameStrata())
    check("the panel's background, no border",
        side.bg.colorTexture[1] == Style.WINDOW_BACKGROUND[1] and side.border == nil)
    check("as many rows as fit, top down", #rows == FIT and Anchored(rows[1], "TOPLEFT", side, Look.SIDE_PAD, RowY(1))
        and Anchored(rows[FIT], "TOPLEFT", side, Look.SIDE_PAD, RowY(FIT)) and rows[1].height == Look.ROW)

    mouseOver[side] = true
    Tick(0.3)
    check("the mouse over the sidebar: the panel fades in with it",
        side.bg.colorTexture[4] == Panel.HOVER_ALPHA and skin.bg.colorTexture[4] == Panel.HOVER_ALPHA)
    mouseOver[side] = nil
    mouseOver[skin] = true
    Tick(0.3)
    check("over the panel: the sidebar with it", side.bg.colorTexture[4] == Panel.HOVER_ALPHA)
    mouseOver[skin] = nil
    Tick(0.3)
    check("away from both: both at rest", side.bg.colorTexture[4] == 0 and skin.bg.colorTexture[4] == 0)

    skin.top = 420
    Tick(0)
    check("the panel moved: the sidebar with it", Anchored(side, "TOPRIGHT", UIParent, 120 - Look.GAP, 420)
        and side.height == 220)
    skin.top = 400
    Tick(0)
    chat:Hide()
    Tick(0)
    check("the docked windows hidden: hidden with them", side.shown == false)
    chat:Show()
    Tick(0)
    check("and back", side.shown ~= false)
end

Section("a row per docked window: the game's own tab clicked by a secure button, words of the addon's")
do
    local first = rows[1]
    check("a secure button of type click, its clickbutton the game's tab",
        first.template == "SecureActionButtonTemplate" and first:GetAttribute("type") == "click"
        and first:GetAttribute("clickbutton") == tab and first:GetAttribute("useOnKeyDown") == false
        and first.clicks[1] == "AnyUp")
    check("the window's name on it, the window shown: gold, whole, marked",
        first.text.text == "General" and first.text.textColor[1] == Panel.LETTER_COLOR[1]
        and first.text.alpha == 1 and first.mark.shown ~= false)
    check("a row with no window: no words, clicking nothing",
        rows[2].text.text == "" and rows[2]:GetAttribute("clickbutton") == nil and rows[2].shown ~= false)

    local guild, guildTab = Window(3, "Guild")
    local dock = GENERAL_CHAT_DOCK
    dock.DOCKED_CHAT_FRAMES = { chat, guild }
    FCFDock_UpdateTabs(dock)
    Watch()
    PlacePanels()
    local second = rows[2]
    check("a second docked window: the next row down, the game's words, its tab",
        second.text.text == "Guild" and second:GetAttribute("clickbutton") == guildTab)
    check("not shown: grey, at TAB_IDLE, unmarked", second.text.textColor[1] == Look.GREY[1]
        and second.text.alpha == Look.TAB_IDLE and second.mark.shown == false)
    second.scripts.OnEnter(second)
    check("whole and lit with the mouse on it", second.text.alpha == 1 and second.light.shown ~= false)
    second.scripts.OnLeave(second)
    check("and not after", second.light.shown == false)
    rows[3].scripts.OnEnter(rows[3])
    check("an empty row: never lit", rows[3].light.shown == false)
    rows[3].scripts.OnLeave(rows[3])

    guildTab.glow = Game("Frame", nil, guildTab)
    FCF_StartAlertFlash(guild)              -- (the game's: nothing hooked)
    Watch()
    check("a window flashing for a new message: red", second.text.textColor[1] == 1 and second.text.textColor[2] == 0)
    guildTab.glow:Hide()
    Watch()
    check("and no longer: grey again", second.text.textColor[1] == Look.GREY[1])

    dock.selected = guild                   -- (the row clicked: the game selects)
    Tick(0)
    check("another window selected: gold the next frame, the first grey",
        second.text.textColor[1] == Panel.LETTER_COLOR[1] and first.text.textColor[1] == Look.GREY[1])
    dock.selected = chat
    Tick(0)
    check("the game's tab click never called by the addon", #tabClicks == 0)
    local guildSkin = Look.panels[guild]
    check("a docked window's skin laid round the dock's main window: the same size from tab to tab",
        guildSkin ~= nil and guildSkin.anchors[1][2] == chat and guildSkin.anchors[2][2] == chat)

    dock.DOCKED_CHAT_FRAMES = { chat }
    Watch()
    check("a window gone from the dock: its row empty, clicking nothing",
        second.text.text == "" and second:GetAttribute("clickbutton") == nil)

    -- An undocked window keeps the game's tab over it: its pictures off, a ghost.
    guild.isDocked = nil
    Watch()
    local float = Look.floats[guild]
    check("an undocked window: a ghost on its own tab, on its skin, its tab's pictures at no opacity",
        float ~= nil and float.shown ~= false and float.parent == Look.panels[guild]
        and Anchored(float, "LEFT", guildTab, 0, 0) and guildTab:GetNormalTexture().alpha == 0)
    check("taking no click: the game's tab under it takes it", float.mouseClicks == false
        and float.propagateClicks == true)
    guild:Hide()
    Watch()
    check("hidden: its ghost with it", float.shown == false)
    _G.ChatFrame3 = nil
end

Section("more windows than rows: the wheel scrolls them, a thumb shows where")
do
    local dock = GENERAL_CHAT_DOCK
    local many, tabs = { chat }, { tab }
    for index = 1, FIT + 2 do
        local frame, frameTab = Window(20 + index, "Chat " .. index)
        many[#many + 1], tabs[#tabs + 1] = frame, frameTab
    end
    dock.DOCKED_CHAT_FRAMES = many
    Watch()
    local thumb = side.thumb
    check("the first FIT windows in the rows, the thumb shown at the top",
        rows[FIT]:GetAttribute("clickbutton") == tabs[FIT] and thumb.shown ~= false
        and Anchored(thumb, "TOPRIGHT", side, -Look.SIDE_PAD, -Look.SIDE_PAD))
    local track = side.track
    check("on the chat scrollbar's thin dark track, the rows' whole height",
        track.shown ~= false and track.colorTexture[1] == Style.BACKGROUND_COLOR[1]
        and Anchored(track, "TOPRIGHT", side, -Look.SIDE_PAD, -Look.SIDE_PAD)
        and Anchored(track, "BOTTOMRIGHT", side, -Look.SIDE_PAD, Look.SIDE_PAD))
    -- A real screen: a pixel half a UI unit, the sidebar drawn at 0.8.
    PixelUtil = { GetPixelToUIUnitFactor = function() return 0.5 end }
    side.GetEffectiveScale = function() return 0.8 end
    rows[1].scripts.OnMouseWheel(rows[1], 0)
    local function OnScreen(width) return width * 0.8 / 0.5 end
    check("as thick on the screen as the chat's scrollbar: SCROLL_PIXELS real pixels, whatever its scale",
        math.abs(OnScreen(track.width) - Panel.SCROLL_PIXELS) < 1e-9
        and math.abs(OnScreen(thumb.width) - Panel.SCROLL_PIXELS) < 1e-9)
    PixelUtil, side.GetEffectiveScale = nil, nil
    rows[1].scripts.OnMouseWheel(rows[1], -1)
    check("the wheel down: every row a window further, each clicking its own",
        rows[1].text.text == "Chat 1" and rows[1]:GetAttribute("clickbutton") == tabs[2]
        and rows[FIT]:GetAttribute("clickbutton") == tabs[FIT + 1])
    side.scripts.OnMouseWheel(side, -5)
    check("never past the last window", rows[FIT]:GetAttribute("clickbutton") == tabs[#tabs])
    tabs[1].glow = Game("Frame", nil, tabs[1])
    Watch()
    check("a window out of view flashing: the thumb red", thumb.colorTexture[1] == 1 and thumb.colorTexture[2] == 0)
    tabs[1].glow:Hide()
    Watch()
    check("and gold again", thumb.colorTexture[1] == Style.BORDER_COLOR[1])
    dock.selected = many[5]
    Tick(0)
    check("a window in view selected: left where it is", rows[1]:GetAttribute("clickbutton") == tabs[4])
    dock.selected = many[2]
    Tick(0)
    check("another window selected out of view: scrolled into view",
        rows[1]:GetAttribute("clickbutton") == tabs[2] and rows[1].text.textColor[1] == Panel.LETTER_COLOR[1])
    dock.selected = chat
    dock.DOCKED_CHAT_FRAMES = { chat }
    Watch()
    check("all fitting again: back to the top, no thumb, no track",
        rows[1]:GetAttribute("clickbutton") == tab and thumb.shown == false and track.shown == false)
end

Section("a whisper window: made by the game, styled after, nothing of it hooked")
do
    -- The game's whisper handling opens a window of its own (ChatFrame11),
    -- docked and selected (FCF_OpenTemporaryWindow, "New Tab" mode); its
    -- tab's words are the sender's name - a secret value.
    local secretName = {}
    secretValues[secretName] = true
    local whisper, whisperTab = Window(11, "")
    whisper.chatType, whisper.chatTarget, whisper.isTemporary = "WHISPER", secretName, true
    whisperTab.GetText = function() return secretName end
    CHAT_FRAMES = { "ChatFrame1", "ChatFrame11" }
    GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES = { chat, whisper }
    FCFDock_UpdateTabs(GENERAL_CHAT_DOCK)
    GENERAL_CHAT_DOCK.selected = whisper
    local ok, err = pcall(Watch)
    check("styled at the next look, nothing failing on the secret name", ok and Look.panels[whisper] ~= nil
        and ChatFrame11Background.texture == nil, tostring(err))
    PlacePanels()
    Tick(0)
    local row = rows[2]
    check("a row clicking its tab, the secret name handed on to the words unlooked-at",
        row.shown ~= false and row.text.text == secretName and row:GetAttribute("clickbutton") == whisperTab)
    check("in the whisper colour", row.text.textColor[1] == ChatTypeInfo.WHISPER.r
        and row.text.textColor[2] == ChatTypeInfo.WHISPER.g)
    check("its tab, its box, its window: nothing hooked, its tab still the game's",
        Hooks(whisperTab) == 0 and Hooks(whisper.editBox) == 0 and Hooks(whisper) == 0
        and whisperTab.shown ~= false and whisperTab.mouseEnabled == nil)
    CHAT_FRAMES = { "ChatFrame1" }
    GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES = { chat }
    GENERAL_CHAT_DOCK.selected = chat
    Watch()
end

Section("the scrollbar anchored again by the game: the text's height again")
do
    local bar = chat.ScrollBar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", chat, "TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", chat.ScrollToBottomButton, "TOPLEFT", 0, 2)
    Watch()
    local point, relative, relativePoint = bar:GetPoint(2)
    check("back to the window's bottom right", point == "BOTTOMLEFT" and relative == chat
        and relativePoint == "BOTTOMRIGHT")
end

Section("the game's font size menu: seen, not hooked - the player's font again")
do
    FCF_SetChatWindowFontSize(nil, chat, 14)
    Watch()
    local file, size = chat:GetFont()
    check("the game's face set by its menu: the player's again, at the game's new size",
        file == Style.FONT and size == 14, tostring(file))
    FCF_SetChatWindowFontSize(nil, chat, 12)
    Watch()
end

Section("the header buttons: letters on the skin shown, right to left; the game's stay the game's")
do
    local ghosts = Look.ghostLetters
    check("no game button given to a frame of the addon's: the menu and channels UIParent's (shown whichever window is)",
        menu.parent == UIParent and channel.parent == UIParent and social.parent == UIParent)
    check("the game's buttons at no opacity, every picture with them",
        menu.alpha == 0 and channel.alpha == 0 and social.alpha == 0)
    check("its toast (a friend's queue) still shown beside it", social.Toast.ignoreParentAlpha == true)
    check("not one hook on a game button", Hooks(menu) == 0 and Hooks(channel) == 0 and Hooks(social) == 0)
    local function Letter(button) return ghosts[button] and ghosts[button].regions[1].text end
    check("a ghost letter over each, on the skin: M the menu, # the channels, F the social",
        Letter(menu) == "/" and Letter(channel) == "#" and Letter(social) == "F"
        and ghosts[menu].parent == skin and ghosts[menu].allPointsTo == menu)
    check("taking no click: the game's button under it takes it",
        ghosts[menu].mouseClicks == false and ghosts[menu].propagateClicks == true)
    check("the letters gone at rest, with the background and border",
        ghosts[menu].alpha == 0 and ghosts[channel].alpha == 0)
    mouseOver[skin] = true
    Tick(0.3)
    check("shown with them under the mouse, dimmed until on one", ghosts[menu].alpha == Panel.LETTER_ALPHA)
    ghosts[menu].scripts.OnEnter(ghosts[menu])
    check("whole with the mouse on it", ghosts[menu].alpha == 1)
    ghosts[menu].scripts.OnLeave(ghosts[menu])
    mouseOver[skin] = nil
    Tick(0.3)
    check("and gone again as the mouse leaves", ghosts[menu].alpha == 0)

    -- The game flashing the channels button (a group joined, its tutorial).
    channel.Flash:Show()
    Watch()
    local low = ghosts[channel].alpha
    check("flashed: its letter shown, the panel at rest", low ~= nil and low > 0 and ghosts[menu].alpha == 0)
    local peak = low
    for _ = 1, 10 do
        Tick(Panel.BLINK_TIME / 10)
        peak = math.max(peak, ghosts[channel].alpha)
    end
    check("blinking: up to whole within a second", math.abs(peak - 1) < 0.01, tostring(peak))
    local least = 1
    for _ = 1, 10 do
        Tick(Panel.BLINK_TIME / 10)
        least = math.min(least, ghosts[channel].alpha)
    end
    check("and down to BLINK_LOW within the next", math.abs(least - Panel.BLINK_LOW) < 0.01, tostring(least))
    channel.Flash:Hide()                    -- (ChatFrameUtil.StopFlash: clicked)
    Watch()
    check("the flash stopped: gone with the panel again", ghosts[channel].alpha == 0)
    social.ToastActiveAnim.playing = true
    Watch()
    check("the social button showing a friend's queue: its letter blinks too", ghosts[social].alpha > 0)
    social.ToastActiveAnim.playing = false
    Watch()
    check("the toast gone: gone again", ghosts[social].alpha == 0)

    local sound = _G.DogsForeverUIChatSoundButton
    check("a sound button of the addon's, rightmost, over the skin's top right, GAP above it",
        sound ~= nil and sound.parent == skin and sound.points[1] == "BOTTOMRIGHT" and sound.points[2] == skin
        and sound.points[3] == "TOPRIGHT" and sound.points[4] == 0 and sound.points[5] == Look.GAP)
    -- (A game button anchored to the window, where the skin's corner is.)
    local dx, dy = Look.PAD + Look.SCROLL_ROOM, Look.PAD + Look.GAP
    local function At(button, n)
        return Anchored(button, "BOTTOMRIGHT", chat, -n * step + dx, dy)
    end
    check("then the social, the menu, the channels, each a step left - anchored to the window, not the panel",
        At(social, 1) and At(menu, 2) and At(channel, 3))
    local copy = _G.DogsForeverUIChatButton
    check("the copy button joins the row, a C", copy ~= nil and copy.parent == skin
        and copy.points[4] == -4 * step)
    mouseOver[skin] = true                  -- (the harness: over the skin or the letters' row)
    Tick(0.3)
    check("the mouse over the panel or the letters' row over it: the letters shown",
        ghosts[menu].alpha == Panel.LETTER_ALPHA)
    mouseOver[skin] = nil
    Tick(0.3)
    check("the header the copy button asks for: the skin shown", Look.Header() == skin)

    sound.scripts.OnClick(sound)
    check("the sound button: all sound off", cvars.Sound_EnableAllSound == false)
    sound.scripts.OnClick(sound)
    check("and on again", cvars.Sound_EnableAllSound == true)

    -- The hidden voice button takes no room; shown, it takes the next place.
    deafen:Show()
    Watch()
    check("a voice button the game shows takes its place in the row (before the copy button)",
        At(deafen, 4) and copy.points[4] == -5 * step)
    deafen:Hide()
    Watch()

    -- The game placing the social button itself (its alert frame).
    social:ClearAllPoints()
    social:SetPoint("BOTTOMLEFT", chat, "TOPLEFT", 0, 30)
    Watch()
    check("a game button the game moved: back in the row at the next look", At(social, 1))
end

Section("the game's alerts (a friend online, a world switch): at the screen's left edge over the panel")
do
    -- The game's alert container over the chat (FloatingChatFrameAlertFrame.xml)
    -- and a friend's toast it stacked on the social button (AlertContainerMixin).
    local alerts = Game("Frame", "ChatAlertFrame")
    alerts:SetPoint("BOTTOMLEFT", chat.buttonFrame, "TOPLEFT", 0, 27)
    local toast = Game("Button", "BNToastFrame")
    toast:Show()
    toast:SetPoint("BOTTOMLEFT", social, "TOPLEFT", 0, 0)
    alerts.alertFrameSubSystems = { { anchorFrame = social }, { anchorFrame = toast } }
    Tick(0)
    check("the container at the screen's left edge, over the panel's letters' row",
        Anchored(alerts, "BOTTOMLEFT", UIParent, 0, skin.top + Look.TOP_ROOM) and #alerts.anchors == 1)
    check("a toast the game put on the social button (in the header): at the stack's foot",
        Anchored(toast, "BOTTOMLEFT", alerts, 0, 0) and #toast.anchors == 1)
    check("the social button left in the header", Anchored(social, "BOTTOMRIGHT", chat))
    local top = skin.top
    skin.top = top + 20
    Tick(0)
    check("the panel moved: the alerts with it", Anchored(alerts, "BOTTOMLEFT", UIParent, 0, top + 20 + Look.TOP_ROOM))
    skin.top = top
    Tick(0)
end

Section("the combat log: its filter row the combat log window's, the panel its size")
do
    local skin2 = Look.panels[combatLog]
    check("the combat log's skin laid round the main window, as every docked one",
        skin2 ~= nil and skin2.anchors[1][2] == chat)
    check("its filter row given to the combat log window itself - the game's frame, not the addon's",
        filterRow.parent == combatLog)
    check("the row's dark strip gone", CombatLogQuickButtonFrame_CustomTexture.alpha == 0)
    local ghost = Look.ghostLetters[moreFilters]
    check("its filters arrow a ghost letter, the button at no opacity",
        moreFilters.alpha == 0 and ghost ~= nil and ghost.parent == skin2 and ghost.regions[1].text == "+")
end

Section("Tab takes the name the game filled in")
do
    local box = chat.editBox
    box.SetCursorPosition = function(self, at) self.cursor = at end
    box.HighlightText = function(self, from, to) self.highlight = { from, to } end
    AutoCompleteBox:Show()
    AutoCompleteBox.parent = box
    AutoCompleteBox.selectedIndex = 1
    nameButton.nameInfo = { name = "Merthan" }
    box:SetText("/w Merthan")
    for _, hook in ipairs(box.hooks.OnTabPressed or {}) do hook(box) end
    check("the cursor at the name's end, nothing selected", box.cursor == #"/w Merthan"
        and box.highlight[1] == box.highlight[2])
    check("the text itself never set by the addon", box:GetText() == "/w Merthan")
    -- Two names fit: the game filled in the first, its Tab moved the
    -- highlight to the second (AutoComplete_IncrementSelection).
    box.cursor = nil
    AutoCompleteBox.selectedIndex = 2
    for _, hook in ipairs(box.hooks.OnTabPressed or {}) do hook(box) end
    check("two names fit: the one filled in is still taken", box.cursor == #"/w Merthan")
    box.cursor = nil
    box:SetText("/w Mer")
    for _, hook in ipairs(box.hooks.OnTabPressed or {}) do hook(box) end
    check("no name filled in: left to the game", box.cursor == nil)
    AutoCompleteBox:Hide()
end

Section("the chat's font size 12 by default, once")
do
    local db = Core.Chat.db
    Tick(2.1)       -- (no saved file here: trusted two seconds after the world is up)
    Tick(0.6)
    check("every chat window at 12, kept by the client for it",
        Look.FONT_SIZE == 12 and select(2, chat:GetFont()) == 12 and chatWindowSizes[1] == 12)
    check("done once for the character", db.chatDefaults == Look.DEFAULT_STEPS)
    check("a whisper opens a tab of its own: the game's New Whispers set to New Tab",
        cvarText.whisperMode == "popout")
    cvarText.whisperMode = "inline"         -- (the player choosing In-line in the game)
    Look.TryDefaults()
    check("chosen otherwise in the game afterwards: stays", cvarText.whisperMode == "inline")
    db.chatDefaults = 3                     -- a character from before this default
    Look.TryDefaults()
    check("a character from before: New Tab, once", cvarText.whisperMode == "popout"
        and db.chatDefaults == Look.DEFAULT_STEPS)
    chat:SetFont("Fonts\\ARIALN.TTF", 16, "")
    Look.TryDefaults()
    Fire("PLAYER_ENTERING_WORLD")
    Flush()
    check("changed in the game afterwards: stays changed", select(2, chat:GetFont()) == 16)
    db.chatDefaults = 1         -- a character that had the first default (14)
    Look.TryDefaults()
    check("had 14 from before: 12 now, once", select(2, chat:GetFont()) == 12
        and db.chatDefaults == Look.DEFAULT_STEPS)
    chat:SetFont("Fonts\\ARIALN.TTF", 16, "")
    Core:Reset("chat")
    check("a reset: 12 again", select(2, chat:GetFont()) == 12 and db.chatDefaults == Look.DEFAULT_STEPS)
end

Section("in combat: nothing secure or of the game's moved; the words follow at once, a changed row shielded")
do
    inCombat = true
    Look.Apply()
    check("Apply waits", true)
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    check("and runs as combat ends", Look.panels[chat] == skin)

    -- A /reload in combat: the login is let through, locked from the first
    -- frame on.
    skin.top = 430
    Fire("PLAYER_LOGIN")
    inCombat = true
    Tick(0)
    check("a reload in combat: the sidebar placed at the login itself, not left for the fight's end",
        side.shown ~= false and Anchored(side, "TOPRIGHT", UIParent, 120 - Look.GAP, 430) and side.height == 230)
    inCombat = false
    skin.top = 400
    Tick(0)

    local refused = #blocked
    local guild, guildTab = Window(3, "Guild")
    inCombat = true
    GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES = { chat, guild }
    FCFDock_UpdateTabs(GENERAL_CHAT_DOCK)
    guildTab.glow = Game("Frame", nil, guildTab)
    Watch()
    local row = rows[2]
    check("a window docked in combat (a whisper's): its row's words at once, red",
        row.text.text == "Guild" and row.text.textColor[1] == 1 and row.text.textColor[2] == 0)
    check("but its click not given in combat: shielded, nothing refused",
        row:GetAttribute("clickbutton") == nil and row.shield.shown ~= false and #blocked == refused)
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    check("the fight over: the row clicks its tab, the shield gone",
        row:GetAttribute("clickbutton") == guildTab and row.shield.shown == false)

    inCombat = true
    GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES = { chat }
    Watch()
    check("a window gone in combat: its row empty, still clicking its old tab - shielded",
        row.text.text == "" and row:GetAttribute("clickbutton") == guildTab and row.shield.shown ~= false
        and #blocked == refused)
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    check("and clicking nothing once the fight is over", row:GetAttribute("clickbutton") == nil
        and row.shield.shown == false)
    guildTab.glow:Hide()
    check("and the game's tab click never called, all along", #tabClicks == 0)
    _G.ChatFrame3 = nil
end

Section("the tooltip in the addon's look, its health bar too, in a place of Unlock Mode")
do
    local tip, GF = GameTooltip, Core.GameFrames
    check("the game's nine-slice art at no opacity", tip.NineSlice.alpha == 0)
    SharedTooltip_SetBackdropStyle(tip)
    check("and again whenever the game sets its style", tip.NineSlice.alpha == 0)
    local back
    for _, region in ipairs(tip.regions) do
        if region.layer == "BACKGROUND" and region.colorTexture then back = region end
    end
    check("the addon's background behind it, 25% see-through, the addon's border round it",
        back ~= nil and back.colorTexture[1] == Style.BACKGROUND_COLOR[1] and back.colorTexture[4] == 0.75)
    local sizes = true
    for _, name in ipairs(GF.TOOLTIP_FONTS) do
        if select(2, _G[name]:GetFont()) ~= 12 then sizes = false end
    end
    check("all its text 12: the first line's, the rest's and the small font", sizes)
    local bar = tip.StatusBar
    check("its health bar the addon's flat fill", bar:GetStatusBarTexture().texture == Style.FLAT_TEXTURE)
    check("under the tooltip, clear of its border, as wide as it",
        bar.anchors[1][1] == "TOPLEFT" and bar.anchors[1][2] == tip and bar.anchors[1][3] == "BOTTOMLEFT"
        and bar.anchors[1][5] == -(Style.BORDER_INSET + GF.TOOLTIP_BAR_GAP)
        and bar.anchors[2][3] == "BOTTOMRIGHT" and bar.height == GF.TOOLTIP_BAR_HEIGHT)
    local ownBorder = false
    for _, child in ipairs(allFrames) do
        if child.parent == bar and child.lines then ownBorder = true end
    end
    check("no border of its own", not ownBorder)

    -- A unit's tooltip: a player's name in their class colour; the health
    -- bar keeps the game's colour.
    local function Shown(unit)
        tooltipUnit = unit
        for _, fn in ipairs(postCalls[Enum.TooltipDataType.Unit] or {}) do fn(tip, {}) end
    end
    units.mouseover = { name = "Dorit", class = "WARRIOR", isPlayer = true, health = 2500, healthMax = 10000 }
    GameTooltipTextLeft1:SetTextColor(1, 1, 1)
    bar:SetStatusBarColor(0, 1, 0)      -- (the game's green)
    Shown("mouseover")
    local name, warrior = GameTooltipTextLeft1.textColor, RAID_CLASS_COLORS.WARRIOR
    check("a player's name in their class colour",
        name[1] == warrior.r and name[2] == warrior.g and name[3] == warrior.b)
    check("the health bar keeps the game's colour",
        bar.statusColor[1] == 0 and bar.statusColor[2] == 1 and #(bar.hooks.OnValueChanged or {}) == 0)
    units.mouseover = { name = "Troll", isPlayer = false, health = 100, healthMax = 100 }
    GameTooltipTextLeft1:SetTextColor(1, 1, 0)
    Shown("mouseover")
    check("not a player: the name as the game has it", GameTooltipTextLeft1.textColor[3] == 0
        and GameTooltipTextLeft1.textColor[1] == 1)
    -- Over the game's raid or party frames: the unit secret, the GUID in the
    -- tooltip's data plain (EllesmereUI's way).
    local secretUnit = {}
    secretValues[secretUnit] = true
    tooltipUnit = secretUnit
    function GetPlayerInfoByGUID(guid)
        if guid == "Player-Tessa" then return "Priest", "PRIEST" end
    end
    GameTooltipTextLeft1:SetTextColor(1, 1, 1)
    local ok = pcall(function()
        for _, fn in ipairs(postCalls[Enum.TooltipDataType.Unit] or {}) do fn(tip, { guid = "Player-Tessa" }) end
    end)
    local priest = RAID_CLASS_COLORS.PRIEST
    check("the unit secret (the game's raid frames): the class from the tooltip's own GUID",
        ok and GameTooltipTextLeft1.textColor[1] == priest.r and GameTooltipTextLeft1.textColor[3] == priest.b)
    GetPlayerInfoByGUID = nil
    units.mouseover, tooltipUnit = nil, nil

    Flush()                     -- (the game frames placed a moment after the world is up)
    local holder, place = GameTooltipDefaultContainer, GF.places.tooltip
    check("a Tooltip piece in Unlock Mode", Core.Snap.EntryById("tooltip") ~= nil and place ~= nil)
    check("the game's tooltip corner hung on it by its bottom right, the health bar's room above it",
        holder.points[1] == "BOTTOMRIGHT" and holder.points[2] == place and holder.points[3] == "BOTTOMRIGHT"
        and holder.points[5] == GF.TooltipBarRoom())
end

Summary()
