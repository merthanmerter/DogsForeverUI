-- MODULE: Chat  (DogsForeverUI.Chat, settings section "chat")
--
-- A copy window: the button in the chat's header opens the shown tab's lines
-- in a ScrollingMessageFrame of the addon's, where a drag copies (the
-- client's own SetTextCopyable). A snapshot: a line arriving mid-drag would
-- move the text under the selection. The game's chat is never touched.

DogsForeverUI.Chat = {}

do -- private scope
    local NS = DogsForeverUI.Chat
    local Core = DogsForeverUI
    local Style = Core.Style
    local IsSecret = issecretvalue

    NS.key = "chat"
    NS.title = "Chat"

    NS.defaults = {
        chatDefaults = 0,       -- the game chat defaults set so far (ChatLook.lua, DEFAULTS)
    }

    local WINDOW_NAME = "DogsForeverUIChatLog"
    local MAX_LINES = 2000      -- more than a chat window keeps
    local HEADER, FOOTER = 52, 40
    local PAD = 18              -- the window's margins round the card
    local CARD_PAD = 12         -- inside the card, round the text
    local GUTTER = 14           -- the card's right, for the thumb
    local BACKGROUND = { Style.BACKGROUND_COLOR[1], Style.BACKGROUND_COLOR[2], Style.BACKGROUND_COLOR[3], 0.96 }
    local THUMB_WIDTH, MIN_THUMB, WHEEL_LINES = 4, 28, 3     -- as the options page's (W.Scroller)
    local THUMB = Style.BORDER_COLOR

    local ChatLog = {}
    NS.ChatLog = ChatLog

    local window, messages, tabLabel, copied, scroller

    local function ShowCopied(_, _, count)
        if IsSecret(count) or type(count) ~= "number" then
            copied.text:SetText("Copied to clipboard.")
        else
            copied.text:SetFormattedText("%s characters copied to clipboard.", BreakUpLargeNumbers(count))
        end
        copied:SetWidth(copied.text:GetStringWidth() + 40)
        Core.Widgets.SnapBorders()
        copied.anim:Stop()
        copied:Show()
        copied.anim:Play()
    end

    -- Says a copy happened: in quickly, held, then out.
    local function BuildToast(parent)
        local W = Core.Widgets
        local toast = CreateFrame("Frame", nil, parent)
        toast:SetSize(260, 26)
        toast:SetPoint("RIGHT", parent, "BOTTOMRIGHT", -PAD, FOOTER / 2)
        toast:SetFrameLevel(parent:GetFrameLevel() + 40)
        W.Flat(toast, "BACKGROUND", { 0.09, 0.09, 0.09, 0.97 }):SetAllPoints(toast)
        toast.border = W.Border(toast)
        toast.dot = W.Flat(toast, "ARTWORK", W.GOOD)
        toast.dot:SetSize(6, 6)
        toast.dot:SetPoint("LEFT", toast, "LEFT", 12, 0)
        toast.text = W.Text(toast, 12)
        toast.text:SetPoint("LEFT", toast.dot, "RIGHT", 8, 0)
        toast:Hide()

        local anim = toast:CreateAnimationGroup()
        local function Fade(order, delay, duration, from)
            local fade = anim:CreateAnimation("Alpha")
            fade:SetOrder(order)
            fade:SetStartDelay(delay)
            fade:SetDuration(duration)
            fade:SetFromAlpha(from)
            fade:SetToAlpha(1 - from)
        end
        Fade(1, 0, 0.15, 0)
        Fade(2, 1.4, 0.5, 1)
        anim:SetScript("OnFinished", function() toast:Hide() end)
        toast.anim = anim
        return toast
    end

    -- The slim gold thumb. Offset 0 is the newest line. Only read from its own
    -- OnUpdate: nothing of the addon's runs inside the frame's refresh, which
    -- the client's copy runs on.
    local function BuildScroller(card)
        local s = {}
        local track = CreateFrame("Frame", nil, card)
        track:SetPoint("TOPRIGHT", card, "TOPRIGHT", -(GUTTER - THUMB_WIDTH) / 2, -CARD_PAD)
        track:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -(GUTTER - THUMB_WIDTH) / 2, CARD_PAD)
        track:SetWidth(THUMB_WIDTH)
        local groove = track:CreateTexture(nil, "BACKGROUND")
        groove:SetAllPoints(track)
        groove:SetColorTexture(1, 1, 1, 0.04)

        local thumb = CreateFrame("Frame", nil, track)
        thumb:SetSize(THUMB_WIDTH, MIN_THUMB)
        thumb:EnableMouse(true)
        thumb:RegisterForDrag("LeftButton")
        local paint = thumb:CreateTexture(nil, "ARTWORK")
        paint:SetAllPoints(thumb)
        paint:SetColorTexture(THUMB[1], THUMB[2], THUMB[3], 0.7)
        thumb:SetScript("OnEnter", function() paint:SetColorTexture(THUMB[1], THUMB[2], THUMB[3], 1) end)
        thumb:SetScript("OnLeave", function() paint:SetColorTexture(THUMB[1], THUMB[2], THUMB[3], 0.7) end)

        local lastOffset, lastRange, lastVisible, lastHeight

        local function Range() return math.max(0, messages:GetMaxScrollRange() or 0) end

        function s.Update()
            local offset, range = messages:GetScrollOffset() or 0, Range()
            local visible = messages:GetNumVisibleLines() or 0
            local trackHeight = track:GetHeight() or 0
            if offset == lastOffset and range == lastRange and visible == lastVisible
               and trackHeight == lastHeight then return end
            lastOffset, lastRange, lastVisible, lastHeight = offset, range, visible, trackHeight
            if range <= 0 or trackHeight <= 0 then
                track:Hide()
                return
            end
            track:Show()
            local height = trackHeight * (math.max(1, visible) / (range + math.max(1, visible)))
            height = math.min(trackHeight, math.max(MIN_THUMB, height))
            thumb:SetHeight(height)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", track, "TOP", 0, -(trackHeight - height) * ((range - offset) / range))
        end

        -- The next Update draws whatever it finds.
        function s.Reset() lastOffset, lastRange, lastVisible, lastHeight = nil end

        messages:EnableMouseWheel(true)
        messages:SetScript("OnMouseWheel", function(self, delta) self:ScrollByAmount(delta * WHEEL_LINES) end)

        thumb:SetScript("OnDragStart", function(self)
            local startCursor, startOffset = Core.CursorY(self), messages:GetScrollOffset() or 0
            self:SetScript("OnUpdate", function(me)
                local travel, range = track:GetHeight() - me:GetHeight(), Range()
                if travel <= 0 or range <= 0 then return end
                local moved = (startCursor - Core.CursorY(me)) * (range / travel)
                messages:SetScrollOffset(math.floor(startOffset - moved + 0.5))
            end)
        end)
        thumb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

        -- The window's child: runs only while it is up.
        CreateFrame("Frame", nil, window):SetScript("OnUpdate", s.Update)

        s.track, s.thumb = track, thumb
        return s
    end

    local function BuildHeader()
        local W = Core.Widgets
        local header = CreateFrame("Frame", nil, window)
        header:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
        header:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
        header:SetHeight(HEADER)
        header:EnableMouse(true)
        header:RegisterForDrag("LeftButton")
        header:SetScript("OnDragStart", function() window:StartMoving() end)
        header:SetScript("OnDragStop", function()
            window:StopMovingOrSizing()
            W.SnapBorders()
        end)
        local rule = W.Flat(header, "ARTWORK", W.FAINT)
        rule:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
        rule:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
        rule:SetHeight(W.Pixel(header))

        local icon = header:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(Core.MEDIA .. "icon")
        icon:SetSize(24, 24)
        icon:SetPoint("LEFT", header, "LEFT", 18, 0)
        local title = W.Text(header, 16, W.GOLD, true)
        title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
        title:SetText("Chat")

        tabLabel = W.Text(header, 13, W.MUTED)
        tabLabel:SetPoint("LEFT", title, "RIGHT", 10, 0)

        local close = W.IconButton(header, "close", 28, function() ChatLog.Close() end)
        close:SetPoint("RIGHT", header, "RIGHT", -12, 0)
        window.CloseButton = close
    end

    -- In the options window's look (Options\Panel.lua).
    local function Build()
        if window then return end
        local W = Core.Widgets
        window = CreateFrame("Frame", WINDOW_NAME, UIParent)
        window:SetFrameStrata("DIALOG")
        window:SetToplevel(true)
        window:SetMovable(true)
        window:SetClampedToScreen(true)
        window:EnableMouse(true)
        window:SetPoint("CENTER")
        window:Hide()
        W.Flat(window, "BACKGROUND", BACKGROUND):SetAllPoints(window)
        window.border = Style.AddBorder(window)
        W.KeepSnapped(window.border)

        BuildHeader()

        local card = W.Card(window)
        card:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -HEADER - PAD)
        card:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, FOOTER)

        messages = CreateFrame("ScrollingMessageFrame", nil, card)
        messages:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, -CARD_PAD)
        messages:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -GUTTER, CARD_PAD)
        messages:SetFontObject(ChatFontNormal)
        Core.Fonts.Chat(messages)
        messages:SetJustifyH("LEFT")
        messages:SetIndentedWordWrap(true)
        messages:SetFading(false)
        messages:SetMaxLines(MAX_LINES)
        messages:SetTextCopyable(true)
        messages:SetMouseClickEnabled(true)
        messages:SetOnTextCopiedCallback(ShowCopied)
        -- No hyperlinks: a link under the cursor is where a drag would start.

        scroller = BuildScroller(card)

        local hint = W.Text(window, 11, W.DIM)
        hint:SetPoint("LEFT", window, "BOTTOMLEFT", PAD + 2, FOOTER / 2)
        hint:SetText("Drag across the text to copy it.  Esc closes.")

        copied = BuildToast(window)
        tinsert(UISpecialFrames, WINDOW_NAME)

        window:SetScript("OnShow", W.SnapBorders)
        window:SetScript("OnHide", function(self)
            -- (Closed mid-drag by Esc: no drag carries on into the next open.)
            self:StopMovingOrSizing()
            scroller.thumb:SetScript("OnUpdate", nil)
        end)

        window.MessageFrame, window.TabLabel, window.CopiedLine = messages, tabLabel, copied
        window.Card, window.ScrollBar = card, scroller
    end

    local function Open(source)
        Build()
        -- Sized from the screen and centred each time: a UI scale change never leaves it off screen.
        window:SetSize(math.min(900, math.max(UIParent:GetWidth() - 80, 320)), math.max(UIParent:GetHeight() - 140, 240))
        window:ClearAllPoints()
        window:SetPoint("CENTER")

        -- The tab's label: secret for a whisper tab, so only handed to SetText.
        local tab = _G[source:GetName() .. "Tab"]
        local text = tab and tab.Text and tab.Text:GetText()
        if IsSecret(text) or type(text) == "string" then
            tabLabel:SetText(text)
        else
            tabLabel:SetText("")
        end

        -- Oldest first. A secret line is left out: in the addon's frame the
        -- client's selecting runs as the addon's and could not cut it.
        messages:Clear()
        for index = 1, source:GetNumMessages() do
            local line, r, g, b = source:GetMessageInfo(index)
            if not IsSecret(line) then messages:AddMessage(line, r, g, b) end
        end
        messages:ScrollToBottom()
        scroller.Reset()

        copied.anim:Stop()
        copied:Hide()
        window.closing = false
        Style.FadeIn(window)
    end

    function ChatLog.Close()
        if not window or not window:IsShown() then return end
        window.closing = true
        Style.FadeOut(window)
    end

    -- Shown, and not on its way out.
    function ChatLog.IsShown()
        return window ~= nil and window:IsShown() and not window.closing
    end

    -- Open on the tab being looked at, or close.
    function ChatLog.Toggle()
        if ChatLog.IsShown() then return ChatLog.Close() end
        local source = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME or _G.ChatFrame1
        if source then Open(source) end
    end

    -- THE COPY BUTTON: a letter in the chat's header (ChatLook.lua), or before
    -- that above the chat-menu button. UIParent's: the chat is only asked where
    -- it is.
    local button

    local function Button()
        if button then return button end
        button = CreateFrame("Button", "DogsForeverUIChatButton", UIParent)
        button:SetSize(22, 22)
        button:SetFrameStrata("MEDIUM")
        button:SetNormalTexture(Core.MEDIA .. "icon")       -- the icon alone: no highlight
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", ChatLog.Toggle)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Copy Chat")
            GameTooltip:AddLine("Open this chat in a window you can select and copy from.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:Hide()
        return button
    end

    local function RefreshButton()
        local look = NS.Look
        if look.Header() then
            Button():Show()
            look.AddOwn("copy", button)
            return
        end
        local menu = _G.ChatFrameMenuButton
        if not menu then
            if button then button:Hide() end
            return
        end
        Button():ClearAllPoints()
        button:SetPoint("BOTTOM", menu, "TOP", 0, 4)
        local chat = _G.ChatFrame1
        button:SetShown(not chat or chat:IsShown())
    end

    function NS.Refresh()
        RefreshButton()
        NS.Look.TryDefaults()   -- after a reset: the game's chat settings the addon's again
    end
    NS.Init = NS.Refresh

    -- The chat windows rebuilt, docked, moved or hidden.
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("UPDATE_CHAT_WINDOWS")
    events:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
    events:SetScript("OnEvent", RefreshButton)

    DogsForeverUI:RegisterModule(NS)
end
