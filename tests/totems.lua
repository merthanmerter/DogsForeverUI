-- The totems: the game's own totem buttons, moved into a row under the
-- player's frame and given the action buttons' look, always: there is no
-- switch to hand them back.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

LoadAddon()
Login()

local NS = DogsForeverUI.Frames
local Totems = NS.Totems
local Style = DogsForeverUI.Style
local player = NS.plates.player

local function Shown()
    local list = {}
    for b in TotemFrame.totemPool:EnumerateActive() do
        if b.shown then list[#list + 1] = b end
    end
    table.sort(list, function(a, b) return a.layoutIndex < b.layoutIndex end)
    return list
end

Section("nothing out, nothing drawn")
do
    TotemFrame:Update()
    check("with no totems the game's frame stays hidden", TotemFrame:IsShown() == false)
    check("and the addon has made nothing", next(Totems.looks) == nil)
    check("the addon has the totems while its frames are on", Totems.on == true)
end

Section("the row")
do
    totems[1] = { icon = "fire" }
    totems[2] = { icon = "earth" }
    totems[4] = { icon = "air" }
    TotemFrame:Update()
    local list = Shown()
    check("three totems out, three buttons", #list == 3, #list)

    check("the row hangs under the player's frame, at its right edge",
        Totems.holder.points[1] == "TOPRIGHT" and Totems.holder.points[2] == player
        and Totems.holder.points[3] == "BOTTOMRIGHT" and Totems.holder.points[4] == 0
        and Totems.holder.points[5] == -(Style.BORDER_INSET + 6))

    local ok = true
    for index, b in ipairs(list) do
        local p = b.points
        local fromRight = (#list - index) * (22 + 6) + 11
        ok = ok and p[1] == "CENTER" and p[2] == Totems.holder and p[3] == "TOPRIGHT"
            and p[4] == -fromRight and p[5] == -11
    end
    check("each button moved into it, in the game's order, the last at the edge", ok)
    check("one anchor each, not the game's left behind",
        list[1]:GetNumPoints() == 1, list[1]:GetNumPoints())

    check("the game's own time text still on every button", list[1].Duration.text == "1m")
end

Section("the look")
do
    local b = Shown()[1]
    local look = Totems.looks[b]
    check("every button has it", look ~= nil and look.border ~= nil)
    check("given before the game filled the button", b.lookBeforeFill == true)
    check("the round ring gone", b.Border.alpha == 0)
    check("the icon square: no circle mask", b.Icon.Texture.mask == nil)
    check("its baked-in edge trimmed like the action buttons'",
        b.Icon.Texture.texCoord[1] == 0.08 and b.Icon.Texture.texCoord[2] == 0.92)
    check("the action buttons' border round it",
        look.border.spec == DogsForeverUI.Menus.ActionButtons.BORDER
        and look.border.parent == b.Icon and look.border.unitPixels == 1)
    check("the frames' black behind it", look.bg.colorTexture ~= nil
        and look.bg.colorTexture[4] == Style.BACKGROUND_COLOR[4])
    check("the swipe square, in the template's colour",
        b.Icon.Cooldown.swipeTexture == Style.FLAT_TEXTURE
        and b.Icon.Cooldown.swipeColor[4] == 0.65)
    check("the time under the icon, clear of its border",
        b.Duration.points[1] == "TOP" and b.Duration.points[2] == b.Icon
        and b.Duration.points[3] == "BOTTOM" and b.Duration.points[5] == -3)

    check("the totem frame out of the player frame's scale, at the UI's",
        TotemFrame.ignoreParentScale == true and TotemFrame.scale == UIParent:GetScale())
end

Section("the game changes its totems")
do
    local before = TotemFrame.totemPool.made
    totems[3] = { icon = "water" }
    totems[1] = nil
    TotemFrame:Update()
    local list = Shown()
    check("the row follows: three again", #list == 3, #list)
    check("in the game's order", list[1].layoutIndex == 2 and list[2].layoutIndex == 3
        and list[3].layoutIndex == 4)
    check("every one moved into the row",
        list[3].points[2] == Totems.holder and list[3].points[4] == -11)
    totems[1] = { icon = "fire" }
    TotemFrame:Update()
    local made = TotemFrame.totemPool.made
    check("a fourth button, new from the pool, has the look before it is filled",
        made == before + 1 and Shown()[1].lookBeforeFill == true, made)

    -- In combat the game does all of this itself; moving a plain button is
    -- allowed, and nothing here is protected.
    inCombat = true
    totems[2] = nil
    TotemFrame:Update()
    check("in combat the row still follows", #Shown() == 3
        and Shown()[3].points[2] == Totems.holder)
    check("and nothing was refused", #blocked == 0, #blocked)
    inCombat = false
end

Section("the UI scale")
do
    UIParent:SetScale(0.8)
    Fire("UI_SCALE_CHANGED")
    check("the totem frame follows the UI's scale", TotemFrame.scale == 0.8, TotemFrame.scale)
    UIParent:SetScale(1)
    Fire("UI_SCALE_CHANGED")
end

totems = {}
TotemFrame:Update()
Summary()
