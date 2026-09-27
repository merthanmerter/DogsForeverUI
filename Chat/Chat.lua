-- MODULE: Chat  (DogsForeverUI.Chat, settings section "chat")
--
-- A copy of your chat that you can select. The button beside the chat opens a
-- tall window holding the lines the chat tab you are looking at has right now;
-- drag the mouse across them and what you dragged over goes to the clipboard,
-- colour codes and link markup stripped out.
--
-- THE GAME'S OWN CHAT IS NOT TOUCHED. Not a script, not a setting, not the
-- mouse. An earlier version made the chat windows themselves selectable -- the
-- client can do that, `SetTextCopyable` is on the ScrollingMessageFrame secure
-- mixin for exactly that reason -- but selection needs the left mouse button,
-- and a chat window that takes the left button is a chat window you cannot
-- click the world through. Worse, the client freezes a message frame's display
-- while the button is held (see OnPostUpdate in ScrollingMessageFrame.lua), so
-- a selection could never be longer than one screenful and the wheel silently
-- moved the view out from under it. A window of the addon's own has neither
-- problem: it can be as tall as the screen, and scrolling it before the drag
-- costs nothing.
--
-- NO MESSAGE IS EVER READ. On this client a chat message can be a secret value
-- -- a name the game will show but will not let addon code look at -- so the
-- lines are handed straight from the chat frame to the window without being
-- inspected, concatenated or compared. Everything that reads them is the
-- client's own code: the drawing, the selecting and the copying.

DogsForeverUI.Chat = {}

do -- private scope
    local NS = DogsForeverUI.Chat

    NS.key = "chat"
    NS.title = "Chat"

    NS.defaults = {
        -- The icon beside the chat that opens the window - the only way in, so
        -- turning it off turns the copy window off.
        showButton = true,
    }

    function NS.Refresh()
        NS.ChatButton.Refresh()
    end
    NS.Init = NS.Refresh

    DogsForeverUI:RegisterModule(NS)
end
