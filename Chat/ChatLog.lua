-- The window you copy from.
--
-- One ScrollingMessageFrame of this addon's own, as tall as the screen, filled
-- from a chat tab when it opens. It is the same widget the chat windows are
-- built on, so the selecting, the highlighting, the markup stripping and the
-- clipboard are all the client's own code -- see SetTextCopyable and
-- OnPostMouseUp in Blizzard_SharedXML/ScrollingMessageFrame.lua, which is what
-- Blizzard's developer console and the Communities chat window use.
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

    local WINDOW_NAME = "DogsForeverUIChatLog"

    -- Room for far more than a chat window keeps, so opening this never loses
    -- the oldest lines the tab still has.
    local MAX_LINES = 2000

    -- This client hands addon code values it may store and pass on but may not
    -- read. Anything that might be one is asked about before it is used.
    local IsSecret = issecretvalue or function() return false end

    local window, messages, tabLabel, copied

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

    -- The short line that says a copy happened. Copying is otherwise silent:
    -- the highlight is gone the moment the button comes up.
    local function ShowCopied(_messageFrame, _text, numCharacters)
        if IsSecret(numCharacters) or type(numCharacters) ~= "number" then
            copied:SetText("Copied to clipboard.")
        else
            copied:SetFormattedText("%s characters copied to clipboard.",
                BreakUpLargeNumbers and BreakUpLargeNumbers(numCharacters) or numCharacters)
        end

        copied.anim:Stop()
        copied:Show()
        copied.anim:Play()
    end

    local function BuildCopiedLine(parent)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 12)
        label:SetTextColor(1, 0.82, 0)
        label:SetJustifyH("RIGHT")
        label:Hide()

        -- In quickly, held long enough to read, then out. The next copy plays it
        -- again from the top, which is what puts the alpha back.
        local anim = label:CreateAnimationGroup()

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

        anim:SetScript("OnFinished", function() label:Hide() end)

        label.anim = anim
        return label
    end

    local function Build()
        if window then return window end

        window = CreateFrame("Frame", WINDOW_NAME, UIParent)
        window:SetFrameStrata("DIALOG")
        window:SetToplevel(true)
        -- A window, not a hole in the screen: clicks stop here rather than
        -- landing on whatever is behind it.
        window:EnableMouse(true)
        window:SetPoint("CENTER")
        window:Hide()

        local border = CreateFrame("Frame", nil, window, "DialogBorderTemplate")
        border:SetAllPoints()

        local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 18, -16)
        title:SetText(DogsForeverUI.TITLE .. " - Chat")

        tabLabel = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        tabLabel:SetPoint("LEFT", title, "RIGHT", 8, 0)

        local hint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("BOTTOMLEFT", 18, 12)
        hint:SetText("Drag across the text to copy it.  Esc closes.")

        copied = BuildCopiedLine(window)

        local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -6, -6)
        close:SetScript("OnClick", function() ChatLog.Close() end)

        messages = CreateFrame("ScrollingMessageFrame", nil, window)
        messages:SetPoint("TOPLEFT", 18, -42)
        messages:SetPoint("BOTTOMRIGHT", -34, 32)
        messages:SetFontObject(ChatFontNormal)
        DogsForeverUI.Fonts.Chat(messages)      -- the player's font, spaced like the chat
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

        local scrollBar = CreateFrame("EventFrame", nil, window, "MinimalScrollBar")
        scrollBar:SetPoint("TOPLEFT", messages, "TOPRIGHT", 8, 0)
        scrollBar:SetPoint("BOTTOMLEFT", messages, "BOTTOMRIGHT", 8, 0)
        -- The game's own wiring: the wheel, the bar and the frame's scroll
        -- offset all agreeing with each other.
        ScrollUtil.InitScrollingMessageFrameWithScrollBar(messages, scrollBar)

        -- Escape closes it, the way it closes the game's own windows.
        if type(UISpecialFrames) == "table" then
            tinsert(UISpecialFrames, WINDOW_NAME)
        end

        -- Named the way the game names the parts of its own frames, so anything
        -- holding the window can reach them.
        window.MessageFrame = messages
        window.TabLabel = tabLabel
        window.CopiedLine = copied
        window.Hint = hint
        window.ScrollBar = scrollBar

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
        -- never leaves a window that no longer fits.
        local width = math.min(900, math.max(UIParent:GetWidth() - 80, 320))
        local height = math.max(UIParent:GetHeight() - 140, 240)
        window:SetSize(width, height)

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

        copied:Hide()
        window:Show()
        return true
    end

    function ChatLog.Close()
        if window then window:Hide() end
    end

    function ChatLog.IsShown()
        return window ~= nil and window:IsShown() and true or false
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
