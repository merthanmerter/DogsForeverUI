-- THE GAME'S FONTS, in the player's own: Media\Dog.ttf, and Media\Dog-Bold.ttf
-- for headings and titles - everywhere, not only on the addon's bars. Chat,
-- tooltips, menus, quest text, nameplates, the options panel...
--
-- HOW. The game's text takes its font from shared font objects (GameFontNormal,
-- ChatFontNormal, SystemFont_NamePlate and hundreds more), and GetFonts() lists
-- every one there is. Each is given the player's font with SetFont, keeping its
-- own size and outline. That is a widget call on the font object and nothing
-- more: the game's font variables (STANDARD_TEXT_FONT and the rest) are not
-- written, since the game's own code reads them and a value an addon wrote
-- there would taint it.
--
-- WHICH. Only fonts in the game's Latin faces - Friz Quadrata, Arial Narrow,
-- Morpheus, Skurri - are replaced. The Cyrillic, Chinese and Korean faces are
-- left alone: the player's font need not have those letters, and text in them
-- would come out as boxes. Morpheus and Skurri are the game's display faces
-- (book and quest titles, big numbers), and fonts named as headings or titles
-- are headings: those take the bold cut.
--
-- WHEN. Now, for every font the game has built already, and again whenever an
-- addon loads, for the fonts it brings. A font already in the player's face is
-- no longer in a Latin one, so going over them again changes nothing.
--
-- WHAT IT DOES NOT REACH. Text the game gives a font file directly rather than
-- a font object keeps the game's font, and so does the world's floating combat
-- text, which the game reads from a font variable at login.
--
-- WHAT IT LEAVES ALONE. The combat text - the scrolling text over you (hits
-- taken, heals and the rest; Blizzard_CombatText) and the numbers over the
-- units you hit and heal - stays in the game's own font, as the player asked. Its font, CombatTextFont, is a 64px font drawn at a fixed size
-- and shrunk with SetTextHeight; given the player's font with SetFont it lost
-- that, and its letters came out spaced wrong.

local Fonts = {}
DogsForeverUI.Fonts = Fonts

do -- private scope

    local REGULAR = DogsForeverUI.MEDIA .. "Dog.ttf"
    local BOLD = DogsForeverUI.MEDIA .. "Dog-Bold.ttf"

    -- The game's Latin faces, by file name, and whether each is a display face
    -- that takes the bold cut.
    local LATIN_FACES = {
        ["frizqt__.ttf"] = false,
        ["arialn.ttf"] = false,
        ["morpheus.ttf"] = true,
        ["skurri.ttf"] = true,
    }

    -- Font objects named as headings or titles take the bold cut too.
    local HEADING_NAMES = { "header", "title", "huge" }

    -- Font objects kept in the game's font (see WHAT IT LEAVES ALONE). The two
    -- SystemFont_World fonts are what the combat text fonts inherit from, and
    -- a font object passes a change on to the fonts that inherit it - so
    -- keeping only the children still left them in the player's font. The
    -- client draws its own floating numbers over units (heals, hits) in the
    -- same fixed-size world font.
    local KEPT = {
        SystemFont_World = true,
        SystemFont_World_ThickOutline = true,
        CombatTextFont = true,
        CombatTextFontOutline = true,
    }

    local function Face(file)
        if type(file) ~= "string" then return nil end
        local name = file:match("([^\\/]+)$")
        return name and name:lower()
    end

    local function IsHeading(name)
        local lower = name:lower()
        for _, word in ipairs(HEADING_NAMES) do
            if lower:find(word, 1, true) then return true end
        end
        return false
    end

    -- One font object into the player's face, keeping its size and outline.
    -- The bold cut may not load (a file added while the game was running is
    -- only found after a restart): then the regular one.
    local function Replace(name, font)
        local ok, file, size, flags = pcall(font.GetFont, font)
        if not ok then return end
        local display = LATIN_FACES[Face(file)]
        if display == nil or type(size) ~= "number" or size <= 0 then return end

        local wanted = (display or IsHeading(name)) and BOLD or REGULAR
        if not font:SetFont(wanted, size, flags or "") and wanted == BOLD then
            font:SetFont(REGULAR, size, flags or "")
        end
    end

    function Fonts.Apply()
        if type(GetFonts) ~= "function" then return end
        for _, name in ipairs(GetFonts() or {}) do
            local font = _G[name]
            if not KEPT[name] and type(font) == "table" and type(font.GetFont) == "function"
               and type(font.SetFont) == "function" then
                Replace(name, font)
            end
        end
    end

    -- THE CHAT WINDOWS. They do not keep to their font object: when the
    -- windows are set up (UPDATE_CHAT_WINDOWS) and whenever their font size
    -- is chosen (FCF_SetChatWindowFontSize), the game reads the window's
    -- current font file and sets it on the window itself, with the size -
    -- which happens before this addon can reach the font object, so the chat
    -- stayed in the game's Arial Narrow, a condensed face that looked
    -- squeezed tall beside the player's font everywhere else. So each chat
    -- window, and the box you type into, is given the player's font directly,
    -- at the size the game chose, after each of those; and its lines a little
    -- more room between them (CHAT_SPACING), for reading. A window whose font
    -- is not one of the game's Latin faces is left in it.
    local CHAT_SPACING = 3

    local function ChatFont(frame)
        if type(frame) ~= "table" or type(frame.GetFont) ~= "function" then return end
        local ok, file, size, flags = pcall(frame.GetFont, frame)
        if ok and type(size) == "number" and size > 0
           and (LATIN_FACES[Face(file)] ~= nil or file == REGULAR) then
            frame:SetFont(REGULAR, size, flags or "")
        end
    end

    -- One message frame: a chat window, or the addon's copy of one.
    function Fonts.Chat(frame)
        ChatFont(frame)
        if type(frame) == "table" and type(frame.SetSpacing) == "function" then
            frame:SetSpacing(CHAT_SPACING)
        end
    end

    function Fonts.ApplyChat()
        -- A list of our own: the game's CHAT_FRAMES is read, never added to.
        local names = {}
        if type(CHAT_FRAMES) == "table" then
            for _, name in ipairs(CHAT_FRAMES) do names[#names + 1] = name end
        end
        if #names == 0 then
            -- NUM_CHAT_WINDOWS is deprecated; this is what it now points at.
            local max = Constants and Constants.ChatFrameConstants
                and Constants.ChatFrameConstants.MaxChatWindows or 10
            for i = 1, max do names[#names + 1] = "ChatFrame" .. i end
        end
        for _, name in ipairs(names) do
            local frame = _G[name]
            if type(frame) == "table" then
                Fonts.Chat(frame)
                ChatFont(frame.editBox or _G[name .. "EditBox"])
            end
        end
    end

    -- The game's own fonts, now; each addon's, as it loads. The chat windows
    -- after the game sets theirs.
    Fonts.Apply()
    Fonts.ApplyChat()
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:RegisterEvent("UPDATE_CHAT_WINDOWS")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:SetScript("OnEvent", function(_, event)
        if event == "ADDON_LOADED" then Fonts.Apply() end
        Fonts.ApplyChat()
    end)
    if type(FCF_SetChatWindowFontSize) == "function" then
        hooksecurefunc("FCF_SetChatWindowFontSize", Fonts.ApplyChat)
    end
    if type(FCF_OpenTemporaryWindow) == "function" then
        hooksecurefunc("FCF_OpenTemporaryWindow", Fonts.ApplyChat)
    end
end
