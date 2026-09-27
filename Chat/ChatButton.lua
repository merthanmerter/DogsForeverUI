-- The icon beside the chat that opens the window.
--
-- It sits in the chat's own button column, just above the chat-menu bubble, so
-- it is where a chat button belongs and never covers a line of text. It moves
-- with the chat window because it is anchored to it.
--
-- Anchored to, and not part of. The button belongs to UIParent; all the chat
-- frame is asked for is where it is and whether it is on screen, and being
-- asked changes nothing. That is the same rule the rest of the module keeps:
-- nothing of the game's chat is hooked, re-parented or configured.

local ChatButton = {}
DogsForeverUI.Chat.ChatButton = ChatButton

do -- private scope

    local NS = DogsForeverUI.Chat

    local BUTTON_NAME = "DogsForeverUIChatButton"
    local ICON = DogsForeverUI.MEDIA .. "icon"
    local SIZE = 22

    local button

    -- A stray global of the right name would otherwise take the addon down on
    -- the first call, so anything found by name has to look like a frame first.
    local function IsFrame(frame)
        return type(frame) == "table"
           and type(frame.GetName) == "function"
           and type(frame.IsShown) == "function"
    end

    -- Where the icon hangs: above the chat-menu bubble at the bottom-left of the
    -- chat window, or off the chat window's own top-left corner on a client that
    -- has no such bubble.
    local function Anchor()
        local menu = _G.ChatFrameMenuButton
        if IsFrame(menu) then return menu, "BOTTOM", "TOP", 0, 4 end

        local chat = _G.ChatFrame1
        if IsFrame(chat) then return chat, "BOTTOMLEFT", "TOPLEFT", -26, 6 end

        return nil
    end

    local function OnEnter(self)
        if not GameTooltip then return end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(DogsForeverUI.TITLE)
        GameTooltip:AddLine("Open this chat in a window you can select and copy from.",
            1, 1, 1, true)
        GameTooltip:Show()
    end

    local function OnLeave()
        if GameTooltip then GameTooltip:Hide() end
    end

    local function Build()
        if button then return button end

        button = CreateFrame("Button", BUTTON_NAME, UIParent)
        button:SetSize(SIZE, SIZE)
        button:SetFrameStrata("MEDIUM")
        button:SetNormalTexture(ICON)
        button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", function()
            NS.ChatLog.Toggle()
        end)
        button:SetScript("OnEnter", OnEnter)
        button:SetScript("OnLeave", OnLeave)
        button:Hide()

        return button
    end

    -- Put the icon where the chat window is now, and show it only while it is
    -- wanted and there is a chat window to open. Called again whenever the game
    -- rebuilds its chat windows, which is what moving, docking or hiding one
    -- does.
    function ChatButton.Refresh()
        if not NS.db.showButton then
            if button then button:Hide() end
            return false
        end

        local anchorTo, point, relativePoint, x, y = Anchor()
        if not anchorTo then
            if button then button:Hide() end
            return false
        end

        Build()
        button:ClearAllPoints()
        button:SetPoint(point, anchorTo, relativePoint, x, y)

        local chat = _G.ChatFrame1
        button:SetShown(not IsFrame(chat) or chat:IsShown())
        return true
    end

    -- Entering the world covers login; the module's Init and Refresh (at
    -- ADDON_LOADED and once the saved settings are in) cover the rest.
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- The chat windows being rebuilt, redocked, moved or hidden.
    watcher:RegisterEvent("UPDATE_CHAT_WINDOWS")
    watcher:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
    watcher:SetScript("OnEvent", function()
        ChatButton.Refresh()
    end)
end
