-- The game's fonts in the player's own: every shared font object in a Latin
-- face, keeping its size and outline; headings in the bold cut; the other
-- alphabets' faces left alone; fonts an addon brings later caught as it loads.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

local REGULAR = "Interface\\AddOns\\DogsForeverUI\\Media\\Dog.ttf"
local BOLD = "Interface\\AddOns\\DogsForeverUI\\Media\\Dog-Bold.ttf"

-- The game's shared font objects, as GetFonts lists them.
local fontNames = {}
local function NewFont(name, file, size, flags)
    local font = { file = file, size = size, flags = flags, loads = true }
    function font:GetFont() return self.file, self.size, self.flags end
    function font:SetFont(path, px, fl)
        if path == BOLD and not self.loads then return false end
        self.file, self.size, self.flags = path, px, fl
        return true
    end
    _G[name] = font
    fontNames[#fontNames + 1] = name
    return font
end
function GetFonts()
    local list = {}
    for i, name in ipairs(fontNames) do list[i] = name end
    return list
end

local normal = NewFont("GameFontNormal", "Fonts\\FRIZQT__.TTF", 12, "")
local chat = NewFont("ChatFontNormal", "Fonts\\ARIALN.TTF", 14, "")
local outlined = NewFont("NumberFontNormal", "Fonts\\ARIALN.TTF", 14, "OUTLINE")
local quest = NewFont("QuestTitleFont", "Fonts\\MORPHEUS.TTF", 18, "")
local header = NewFont("GameFontNormalHuge", "Fonts\\FRIZQT__.TTF", 20, "")
local cyrillic = NewFont("SystemFont_Cyr", "Fonts\\FRIZQT___CYR.TTF", 12, "")
local chinese = NewFont("SystemFont_ZH", "Fonts\\ARKai_T.ttf", 12, "")

-- The chat windows: each set to a font file directly by the game, at the size
-- chosen for it, rather than following ChatFontNormal (FloatingChatFrame.lua).
function Widget:SetSpacing(v) self.spacing = v end
local function NewChatWindow(name, size)
    local frame = CreateFrame("ScrollingMessageFrame", name, UIParent)
    frame:SetFont("Fonts\\ARIALN.TTF", size, "")
    frame.editBox = CreateFrame("EditBox", name .. "EditBox", frame)
    frame.editBox:SetFont("Fonts\\ARIALN.TTF", 14, "")
    return frame
end
local chat1, chat2 = NewChatWindow("ChatFrame1", 14), NewChatWindow("ChatFrame2", 12)
CHAT_FRAMES = { "ChatFrame1", "ChatFrame2" }
-- Choosing a window's font size: the game takes the window's font file as it
-- is and sets it back with the new size.
function FCF_SetChatWindowFontSize(_, chatFrame, fontSize)
    local file, _, flags = chatFrame:GetFont()
    chatFrame:SetFont(file, fontSize, flags)
end

-- The combat text's fonts (Blizzard_Fonts_Shared): the world fonts the client
-- draws its floating numbers in and the scrolling text's fonts inherit, the
-- scrolling text's own, and the game's variable for the numbers over the
-- units - all to stay the game's own.
DAMAGE_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local world = NewFont("SystemFont_World", "Fonts\\FRIZQT__.TTF", 64, "")
local worldOutline = NewFont("SystemFont_World_ThickOutline", "Fonts\\FRIZQT__.TTF", 64, "THICKOUTLINE")
local combatFont = NewFont("CombatTextFont", "Fonts\\FRIZQT__.TTF", 64, "")
local combatOutline = NewFont("CombatTextFontOutline", "Fonts\\FRIZQT__.TTF", 64, "THICKOUTLINE")

LoadAddon()
Login()

Section("the combat text")
check("the world fonts the combat text inherits left in the game's font",
    world.file == "Fonts\\FRIZQT__.TTF" and world.size == 64
    and worldOutline.file == "Fonts\\FRIZQT__.TTF", tostring(world.file))
check("the scrolling combat and heal text left in the game's font",
    combatFont.file == "Fonts\\FRIZQT__.TTF" and combatFont.size == 64
    and combatOutline.file == "Fonts\\FRIZQT__.TTF", tostring(combatFont.file))
check("the numbers over the units left in the game's font",
    DAMAGE_TEXT_FONT == "Fonts\\FRIZQT__.TTF", tostring(DAMAGE_TEXT_FONT))
Fire("ADDON_LOADED", "Blizzard_CombatText")
check("and still after the combat text loads", combatFont.file == "Fonts\\FRIZQT__.TTF")

Section("the chat windows")
check("each chat window in the player's font, at the size the game chose for it",
    chat1.font[1] == REGULAR and chat1.font[2] == 14 and chat2.font[1] == REGULAR
    and chat2.font[2] == 12, tostring(chat1.font[1]))
check("and the box you type into", chat1.editBox.font[1] == REGULAR)
check("with a little more room between the lines", chat1.spacing == 3 and chat2.spacing == 3)
chat1:SetFont("Fonts\\ARIALN.TTF", 14, "")      -- the game setting the windows up again
Fire("UPDATE_CHAT_WINDOWS")
check("put back after the game sets the windows up again", chat1.font[1] == REGULAR)
FCF_SetChatWindowFontSize(nil, chat1, 16)
check("and after a new font size is chosen, at that size",
    chat1.font[1] == REGULAR and chat1.font[2] == 16)
check("the game's list of chat windows read, not added to", #CHAT_FRAMES == 2)

Section("the game's own fonts")
check("general text in the player's font, at its own size",
    normal.file == REGULAR and normal.size == 12, tostring(normal.file))
check("chat too", chat.file == REGULAR and chat.size == 14)
check("an outline kept", outlined.file == REGULAR and outlined.flags == "OUTLINE")
check("the game's display face (quest and book titles) in the bold cut",
    quest.file == BOLD and quest.size == 18, tostring(quest.file))
check("and a heading in the bold cut", header.file == BOLD, tostring(header.file))
check("the Cyrillic and Chinese faces left alone",
    cyrillic.file == "Fonts\\FRIZQT___CYR.TTF" and chinese.file == "Fonts\\ARKai_T.ttf")

Section("an addon loading later, with fonts of its own")
local later = NewFont("SomeAddonTitleFont", "Fonts\\MORPHEUS.TTF", 16, "")
local laterBody = NewFont("SomeAddonBodyFont", "Fonts\\FRIZQT__.TTF", 11, "")
later.loads = false     -- as if the bold file was added after the game started
Fire("ADDON_LOADED", "SomeAddon")
check("its fonts are given the player's face as it loads", laterBody.file == REGULAR)
check("a bold cut that will not load falls back to the regular one, not to nothing",
    later.file == REGULAR and later.size == 16, tostring(later.file))

Section("a font object's SetFont answers nothing, as in game (SimpleFontAPI)")
local silent = NewFont("SilentAddonHeaderFont", "Fonts\\FRIZQT__.TTF", 14, "")
local silentMissing = NewFont("SilentAddonTitleFont", "Fonts\\MORPHEUS.TTF", 16, "")
silentMissing.loads = false
for _, font in ipairs({ silent, silentMissing }) do
    function font:SetFont(path, px, fl)
        if path == BOLD and not self.loads then return end
        self.file, self.size, self.flags = path, px, fl
    end
end
Fire("ADDON_LOADED", "SilentAddon")
check("a heading still takes the bold cut", silent.file == BOLD, tostring(silent.file))
check("and a bold cut that will not load still falls back to the regular one",
    silentMissing.file == REGULAR and silentMissing.size == 16, tostring(silentMissing.file))

Section("going over them again")
Fire("ADDON_LOADED", "AnotherAddon")
check("changes nothing", normal.file == REGULAR and quest.file == BOLD
    and normal.size == 12 and quest.size == 18)

Summary()
