-- The Chat module: a window to select and copy chat from, opened by an icon
-- beside the chat. The game's own chat windows are never touched, and no chat
-- message is ever read.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

local function Window() return _G.DogsForeverUIChatLog end

-- Three ordinary lines and one the addon is not allowed to look at.
local hidden = Unreadable("a chat message")
local general = {
    { "Dog says: woof", 1, 1, 1 },
    { "Cat says: no", 1, 0.5, 0.5 },
    { hidden, 1, 1, 1 },
}
local whispers = { { "To Someone: hello", 1, 1, 1 } }
local hiddenTabName = Unreadable("a chat tab's name")

NewChatWindow("ChatFrame1", general, "General")
NewChatWindow("ChatFrame2", whispers, hiddenTabName)
SELECTED_CHAT_FRAME = _G.ChatFrame1
DEFAULT_CHAT_FRAME = _G.ChatFrame1

-- The chat-menu bubble at the bottom-left of the chat window, which is what the
-- addon's icon hangs above.
local menuButton = CreateFrame("Button", "ChatFrameMenuButton", UIParent)

LoadAddon()
Login()

local icon = _G.DogsForeverUIChatButton

Section("the icon beside the chat")

check("there is an icon", icon ~= nil and icon:IsShown())
check("hanging above the chat-menu bubble",
    icon.points[1] == "BOTTOM" and icon.points[2] == menuButton and icon.points[3] == "TOP")
check("wearing the addon's own icon",
    icon.normalTexture == "Interface\\AddOns\\DogsForeverUI\\Media\\icon", icon.normalTexture)
check("with no highlight of the game's over it", icon.highlightTexture == nil)

icon.scripts.OnEnter(icon)
check("it says what it does", GameTooltip.owner == icon
    and GameTooltip:GetLines():find("select and copy", 1, true) ~= nil,
    GameTooltip:GetLines())
check("and names no command, there being none",
    GameTooltip:GetLines():find("/", 1, true) == nil, GameTooltip:GetLines())
check("and no hover effect runs", icon.scripts.OnUpdate == nil
    and icon:GetWidth() == 22 and icon:GetHeight() == 22)
icon.scripts.OnLeave(icon)
check("and puts the tooltip away", not GameTooltip:IsShown())

Section("opening the window")

icon:Click()

check("clicking the icon opens a window", Window() ~= nil and Window():IsShown())
check("sized from the screen", Window():GetWidth() == 900 and Window():GetHeight() == 940,
    Window():GetWidth() .. "x" .. Window():GetHeight())
check("its text is selectable", Window().MessageFrame:IsTextCopyable())
check("and it takes the mouse", Window().MessageFrame:IsMouseClickEnabled())
check("it does not fade what it is holding", Window().MessageFrame.fading == false)
check("Escape closes it", UISpecialFrames[#UISpecialFrames] == "DogsForeverUIChatLog")
check("opened at the newest line", Window().MessageFrame.scrollOffset == 0)
check("the tab's name is on it", Window().TabLabel:GetText() == "General",
    Window().TabLabel:GetText())

Section("in the options window's look")

check("a gold drawn border, as the options window's", Window().border ~= nil)
check("the text sits on a card", Window().MessageFrame.parent == Window().Card)
check("a drawn cross closes it, not the game's red button",
    Window().CloseButton ~= nil and Window().CloseButton.glyph ~= nil)
check("no game template anywhere on it",
    Window().template == nil and Window().CloseButton.template == nil)
check("it can be dragged by its header", Window().CloseButton.parent.scripts.OnDragStart ~= nil)

Section("scrolling")

local scroller = Window().ScrollBar
scroller.track.height = 400
Tick(0.05)
check("with everything in view there is no thumb", not scroller.track:IsShown())

local smf = Window().MessageFrame
smf.visibleLines = 1
scroller.Reset()
Tick(0.05)
check("with more lines than fit, the thumb shows", scroller.track:IsShown())
local bottomAt = scroller.thumb.points[5]
smf.scripts.OnMouseWheel(smf, 1)
check("the wheel scrolls back through the history", smf:GetScrollOffset() == smf:GetMaxScrollRange(),
    smf:GetScrollOffset())
Tick(0.05)
check("and the thumb follows it up", scroller.thumb.points[5] > bottomAt,
    tostring(scroller.thumb.points[5]) .. " vs " .. tostring(bottomAt))
smf.scripts.OnMouseWheel(smf, -1)
check("and back down to the newest", smf:GetScrollOffset() == 0)
smf.visibleLines = nil
scroller.Reset()
Tick(0.05)

Section("the game's chat is not touched")

check("not one call was made that would change a chat window",
    #chatEdits == 0, table.concat(chatEdits, ", "))

Section("the lines are passed through, never read")

local held = Window().MessageFrame.lines
check("in the order they were said, oldest first",
    held[1].message == general[1][1] and held[2].message == general[2][1])
check("with their colours", held[2].r == 1 and held[2].g == 0.5 and held[2].b == 0.5)
-- (The client's selecting code runs as the addon's in this window, and
-- would have to measure and cut a secret line: a drag across it would throw.)
check("a line that cannot be read is left out, every other line in",
    #held == #general - 1 and held[3] == nil, #held)

local readIt = pcall(function() return hidden .. "" end)
check("and reading one really would have raised", not readIt)

Section("copying")

local copiedOk = Window().MessageFrame:Copy("Dog says: woof\nCat says: no", 28)
check("a drag across the window copies", copiedOk and clipboard == "Dog says: woof\nCat says: no")
check("and says how much was copied",
    Window().CopiedLine.text:GetText() == "28 characters copied to clipboard.",
    Window().CopiedLine.text:GetText())
check("in a line that fades itself out",
    Window().CopiedLine:IsShown() and Window().CopiedLine.animationGroup:IsPlaying())

Window().CopiedLine.animationGroup:Finish()
check("and takes itself off screen when it has", not Window().CopiedLine:IsShown())

-- A count this client will not let an addon read must not stop the line.
local hiddenCount = Unreadable("the number of characters copied")
Window().MessageFrame:Copy("some text", hiddenCount)
check("a character count that is a secret value is left out of the sentence",
    Window().CopiedLine.text:GetText() == "Copied to clipboard.",
    Window().CopiedLine.text:GetText())

Section("which window, and closing it")

icon:Click()
check("clicking the icon again closes it", not DogsForeverUI.Chat.ChatLog.IsShown())
check("fading out, as the options window does", Window():IsShown())
Tick(0.5)
check("and gone once faded", not Window():IsShown())

-- The tab the player is looking at is the one copied.
SELECTED_CHAT_FRAME = _G.ChatFrame2
icon:Click()
check("with another tab in front, that tab is the one opened", Window():IsShown()
    and #Window().MessageFrame.lines == 1
    and Window().MessageFrame.lines[1].message == whispers[1][1])
check("a tab name that cannot be read is shown without being read",
    Window().TabLabel:GetText() == hiddenTabName)
check("and the copied line starts hidden", not Window().CopiedLine:IsShown())
icon:Click()
Tick(0.5)
SELECTED_CHAT_FRAME = _G.ChatFrame1

Section("it is a snapshot, taken again each time")

table.insert(general, { "Dog says: still here", 1, 1, 1 })
icon:Click()
local lines = Window().MessageFrame.lines
check("reopening picks up what has been said since (the secret line still left out)",
    #lines == #general - 1 and lines[#lines].message == "Dog says: still here")
check("and the game's chat is still untouched", #chatEdits == 0, table.concat(chatEdits, ", "))
DogsForeverUI.Chat.ChatLog.Close()
Tick(0.5)

Section("the icon comes and goes with the chat, and with its setting")

-- The chat window being hidden takes the icon with it, because an icon for a
-- window that is not there is an icon that does nothing.
_G.ChatFrame1.shown = false
Fire("UPDATE_CHAT_WINDOWS")
check("a hidden chat window takes the icon with it", not icon:IsShown())

_G.ChatFrame1.shown = true
Fire("UPDATE_CHAT_WINDOWS")
check("and brings it back", icon:IsShown())

-- The one setting: the icon, which is the only way in.
DogsForeverUI.Chat.db.showButton = false
DogsForeverUI.Chat.Refresh()
check("switching the button off takes the icon away", not icon:IsShown())
Fire("UPDATE_CHAT_WINDOWS")
check("and a chat rebuild does not bring it back", not icon:IsShown())
DogsForeverUI.Chat.db.showButton = true
DogsForeverUI.Chat.Refresh()
check("switching it back on brings it back", icon:IsShown())

check("and none of that touched the chat", #chatEdits == 0, table.concat(chatEdits, ", "))

Section("without a chat window at all")

SELECTED_CHAT_FRAME, DEFAULT_CHAT_FRAME = nil, nil
_G.ChatFrame1, _G.ChatFrame2 = nil, nil
local ok, err = pcall(DogsForeverUI.Chat.ChatLog.Toggle)
check("asking for the window does not throw", ok, err)
check("and no window is left on screen", not Window():IsShown())

Summary()
