-- The window you copy from.
--
-- One ScrollingMessageFrame of this addon's own, as tall as the screen, filled
-- from a chat tab when it opens. It is the same widget the chat windows are
-- built on, so the selecting, the highlighting, the markup stripping and the
-- clipboard are all the client's own code -- see SetTextCopyable and
-- OnPostMouseUp in Blizzard_SharedXML/ScrollingMessageFrame.lua, which is what
-- Blizzard's developer console and the Communities chat window use.
--
-- It wears the options window's look (Options\Panel.lua), so the addon's two
-- windows read as one: the same dark flat window in the frames' gold border,
-- a header with the icon, a gold title and a drawn cross, the text on a card,
-- the slim gold scroll thumb, and a toast for what a copy did.
--
--   +------------------------------------------------------------------+
--   | [icon] Chat  General                                         [x] |  header: drag to move
--   +------------------------------------------------------------------+
--   |  +------------------------------------------------------------+  |
--   |  | the tab's lines                                          | |  |  a card; the thumb
--   |  | ...                                                        |  |  on its right edge
--   |  +------------------------------------------------------------+  |
--   |  Drag across the text to copy it.  Esc closes.   [* 28 copied]   |
--   +------------------------------------------------------------------+
--
-- What it is filled with is never looked at. `GetMessageInfo` hands back a
-- message and its colour and they go straight into AddMessage; on this client
-- that message may be a secret value, which addon code is allowed to hold and
-- pass on but not read, so nothing here indexes, concatenates or compares one.
-- The same goes for the tab's name, which is secret for a whisper tab.
--
-- The window is a snapshot, deliberately. It does not follow the chat while it
-- is open: a line arriving mid-drag would move the text out from under the
-- selection. Close it and open it again for what has been said since.

local ChatLog = {}
DogsForeverUI.Chat.ChatLog = ChatLog

do -- private scope

    local Core = DogsForeverUI
    local Style = Core.Style

    local WINDOW_NAME = "DogsForeverUIChatLog"

    -- Room for far more than a chat window keeps, so opening this never loses
    -- the oldest lines the tab still has.
    local MAX_LINES = 2000

    local HEADER = 52
    local FOOTER = 40
    local PAD = 18                  -- the window's margins round the card
    local CARD_PAD = 12             -- inside the card, round the text
    local GUTTER = 14               -- room on the card's right for the thumb
    local BACKGROUND = { Style.BACKGROUND_COLOR[1], Style.BACKGROUND_COLOR[2],
                         Style.BACKGROUND_COLOR[3], 0.96 }

    -- The scroll thumb, as the options page's (Options\ScrollBar.lua).
    local THUMB_WIDTH = 4
    local MIN_THUMB = 28
    local WHEEL_LINES = 3
    local THUMB = { Style.BORDER_COLOR[1], Style.BORDER_COLOR[2], Style.BORDER_COLOR[3] }

    -- This client hands addon code values it may store and pass on but may not
    -- read. Anything that might be one is asked about before it is used.
    local IsSecret = issecretvalue or function() return false end

    local window, messages, tabLabel, copied, scroller

    -- A stray global of the right name would otherwise take the addon down on
    -- the first call, so a chat window has to answer to the two calls that
    -- matter before it is believed.
    local function IsChatWindow(frame)
        return type(frame) == "table"
           and type(frame.GetNumMessages) == "function"
           and type(frame.GetMessageInfo) == "function"
    end

    -- The tab's own label, which is what the player calls that window. It can be
    -- a secret value, so it is passed to SetText without being looked at.
    local function TabText(source)
        local name = type(source.GetName) == "function" and source:GetName()
        if type(name) ~= "string" then return nil end

        local tab = _G[name .. "Tab"]
        if type(tab) ~= "table" then return nil end

        local label = tab.Text
        if type(label) == "table" and type(label.GetText) == "function" then
            local ok, text = pcall(label.GetText, label)
            if ok then return text end
        end
        return nil
    end

    ---------------------------------------------------------------------------
    -- THE TOAST: says a copy happened. Copying is otherwise silent: the
    -- highlight is gone the moment the button comes up.
    ---------------------------------------------------------------------------

    local function ShowCopied(_messageFrame, _text, numCharacters)
        local W = Core.Widgets
        if IsSecret(numCharacters) or type(numCharacters) ~= "number" then
            copied.text:SetText("Copied to clipboard.")
        else
            copied.text:SetFormattedText("%s characters copied to clipboard.",
                BreakUpLargeNumbers and BreakUpLargeNumbers(numCharacters) or numCharacters)
        end
        local width = copied.text.GetStringWidth and copied.text:GetStringWidth() or 220
        copied:SetWidth((width or 220) + 40)
        W.SnapBorders()

        copied.anim:Stop()
        copied:Show()
        copied.anim:Play()
    end

    local function BuildToast(parent)
        local W = Core.Widgets
        local toast = CreateFrame("Frame", nil, parent)
        toast:SetSize(260, 26)
        toast:SetPoint("RIGHT", parent, "BOTTOMRIGHT", -PAD, FOOTER / 2)
        toast:SetFrameLevel(parent:GetFrameLevel() + 40)
        local bg = W.Flat(toast, "BACKGROUND", { 0.09, 0.09, 0.09, 0.97 })
        bg:SetAllPoints(toast)
        toast.border = W.Border(toast)
        toast.dot = W.Flat(toast, "ARTWORK", W.GOOD)
        toast.dot:SetSize(6, 6)
        toast.dot:SetPoint("LEFT", toast, "LEFT", 12, 0)
        toast.text = W.Text(toast, 12)
        toast.text:SetPoint("LEFT", toast.dot, "RIGHT", 8, 0)
        toast:Hide()

        -- In quickly, held long enough to read, then out. The next copy plays it
        -- again from the top, which is what puts the alpha back.
        local anim = toast:CreateAnimationGroup()

        local fadeIn = anim:CreateAnimation("Alpha")
        fadeIn:SetOrder(1)
        fadeIn:SetDuration(0.15)
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(1)

        local fadeOut = anim:CreateAnimation("Alpha")
        fadeOut:SetOrder(2)
        fadeOut:SetStartDelay(1.4)
        fadeOut:SetDuration(0.5)
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0)

        anim:SetScript("OnFinished", function() toast:Hide() end)

        toast.anim = anim
        return toast
    end

    ---------------------------------------------------------------------------
    -- THE SCROLL THUMB: the options page's slim gold one, on a message frame.
    --
    -- A message frame scrolls by lines, counted up from the newest (offset 0
    -- is the bottom). The thumb only READS where the frame is, from its own
    -- OnUpdate while the window is up: nothing of the addon's is put inside
    -- the frame's refresh, which is the path the client's copy runs on.
    ---------------------------------------------------------------------------

    local function CursorY(frame)
        local _, y = GetCursorPosition()
        return y / frame:GetEffectiveScale()
    end

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
        thumb:SetWidth(THUMB_WIDTH)
        thumb:SetHeight(MIN_THUMB)
        thumb:EnableMouse(true)
        thumb:RegisterForDrag("LeftButton")
        local thumbTexture = thumb:CreateTexture(nil, "ARTWORK")
        thumbTexture:SetAllPoints(thumb)
        thumbTexture:SetColorTexture(THUMB[1], THUMB[2], THUMB[3], 0.7)
        thumb:SetScript("OnEnter", function() thumbTexture:SetColorTexture(THUMB[1], THUMB[2], THUMB[3], 1) end)
        thumb:SetScript("OnLeave", function() thumbTexture:SetColorTexture(THUMB[1], THUMB[2], THUMB[3], 0.7) end)

        local lastOffset, lastRange, lastVisible, lastHeight

        local function Range()
            return math.max(0, messages:GetMaxScrollRange() or 0)
        end

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
            -- The top of the history is the most scrolled, so the thumb's
            -- distance from the top is how far from it the view is.
            thumb:SetPoint("TOP", track, "TOP", 0, -(trackHeight - height) * ((range - offset) / range))
        end

        -- Forget what was drawn, so the next Update draws it whatever it is.
        function s.Reset()
            lastOffset, lastRange, lastVisible, lastHeight = nil, nil, nil, nil
        end

        messages:EnableMouseWheel(true)
        messages:SetScript("OnMouseWheel", function(self, delta)
            self:ScrollByAmount(delta * WHEEL_LINES)
        end)

        thumb:SetScript("OnDragStart", function(self)
            local startCursor, startOffset = CursorY(self), messages:GetScrollOffset() or 0
            self:SetScript("OnUpdate", function(me)
                local travel = track:GetHeight() - me:GetHeight()
                local range = Range()
                if travel <= 0 or range <= 0 then return end
                -- Dragging down goes towards the newest line, offset 0.
                local moved = (startCursor - CursorY(me)) * (range / travel)
                messages:SetScrollOffset(math.floor(startOffset - moved + 0.5))
            end)
        end)
        thumb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

        -- Runs only while the window is up, since it is the window's child.
        local driver = CreateFrame("Frame", nil, window)
        driver:SetScript("OnUpdate", s.Update)

        s.track, s.thumb = track, thumb
        return s
    end

    ---------------------------------------------------------------------------
    -- THE WINDOW
    ---------------------------------------------------------------------------

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

    local function Build()
        if window then return window end
        local W = Core.Widgets

        window = CreateFrame("Frame", WINDOW_NAME, UIParent)
        window:SetFrameStrata("DIALOG")
        window:SetToplevel(true)
        window:SetMovable(true)
        window:SetClampedToScreen(true)
        -- A window, not a hole in the screen: clicks stop here rather than
        -- landing on whatever is behind it.
        window:EnableMouse(true)
        window:SetPoint("CENTER")
        window:Hide()
        local bg = W.Flat(window, "BACKGROUND", BACKGROUND)
        bg:SetAllPoints(window)
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
        Core.Fonts.Chat(messages)               -- the player's font, spaced like the chat
        messages:SetJustifyH("LEFT")
        messages:SetIndentedWordWrap(true)
        -- A copy window that faded its own text out would be a poor one.
        messages:SetFading(false)
        messages:SetMaxLines(MAX_LINES)
        messages:SetTextCopyable(true)
        messages:SetMouseClickEnabled(true)
        messages:SetOnTextCopiedCallback(ShowCopied)
        -- Hyperlinks are deliberately left off. This is a window for copying
        -- text out of, and a link under the cursor is a link the drag starts on.

        scroller = BuildScroller(card)

        local hint = W.Text(window, 11, W.DIM)
        hint:SetPoint("LEFT", window, "BOTTOMLEFT", PAD + 2, FOOTER / 2)
        hint:SetText("Drag across the text to copy it.  Esc closes.")

        copied = BuildToast(window)

        -- Escape closes it, the way it closes the game's own windows.
        if type(UISpecialFrames) == "table" then
            tinsert(UISpecialFrames, WINDOW_NAME)
        end

        window:SetScript("OnShow", function(self)
            self.closing = false
            W.SnapBorders()
        end)
        window:SetScript("OnHide", function(self)
            self.closing = false
        end)

        -- Named the way the game names the parts of its own frames, so anything
        -- holding the window can reach them.
        window.MessageFrame = messages
        window.TabLabel = tabLabel
        window.CopiedLine = copied
        window.Hint = hint
        window.Card = card
        window.ScrollBar = scroller

        return window
    end

    -- The chat window to copy from: the tab the player is looking at.
    function ChatLog.Source()
        for _, candidate in ipairs({ SELECTED_CHAT_FRAME, DEFAULT_CHAT_FRAME, _G.ChatFrame1 }) do
            if IsChatWindow(candidate) then return candidate end
        end
        return nil
    end

    function ChatLog.Open(source)
        if not IsChatWindow(source) then return false end

        Build()

        -- Sized from the screen every time, so a resolution or UI-scale change
        -- never leaves a window that no longer fits; and centred again, since
        -- a window dragged last time and grown this time could reach off it.
        local width = math.min(900, math.max(UIParent:GetWidth() - 80, 320))
        local height = math.max(UIParent:GetHeight() - 140, 240)
        window:SetSize(width, height)
        window:ClearAllPoints()
        window:SetPoint("CENTER")

        local text = TabText(source)
        if IsSecret(text) or type(text) == "string" then
            tabLabel:SetText(text)
        else
            tabLabel:SetText("")
        end

        messages:Clear()
        -- Index 1 is the oldest line the tab still holds, so this puts them back
        -- in the order they were said. Nothing in between looks at them: what
        -- GetMessageInfo returns goes straight into AddMessage.
        for index = 1, source:GetNumMessages() do
            messages:AddMessage(source:GetMessageInfo(index))
        end
        messages:ScrollToBottom()
        scroller.Reset()

        copied.anim:Stop()
        copied:Hide()
        window.closing = false
        Style.FadeIn(window)
        return true
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

    -- The chat button's click: open on the tab being looked at, or close.
    -- With no chat window to copy from, nothing opens.
    function ChatLog.Toggle()
        if ChatLog.IsShown() then
            ChatLog.Close()
            return
        end

        local source = ChatLog.Source()
        if source then ChatLog.Open(source) end
    end
end
