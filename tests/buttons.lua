-- The action buttons in the addon's look - the addon's own bars' buttons
-- (ActionBars\), the stance and pet buttons it takes into its bars - the main
-- bar's art and end caps gone, and every game piece the addon replaces gone
-- from Edit Mode too.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

LoadAddon()
Login()

local Style = DogsForeverUI.Style
local Buttons = DogsForeverUI.Menus.ActionButtons
local Bars = DogsForeverUI.ActionBars
local button = _G.DogsForeverUIActionButton1
local parts = Buttons.parts[button]

Section("every button in the frames' look")
do
    local all, count = true, 0
    for _, info in ipairs(Bars.BARS) do
        for _, b in ipairs(Bars.buttons[info.key]) do
            count = count + 1
            all = all and Buttons.parts[b] ~= nil
        end
    end
    -- (Eight bars of twelve, and the harness's three stance and three pet buttons.)
    check("on every bar, the stance and pet bars included", all and count == 102, count)
end
local gold = parts.border and parts.border.spec.lines[1]
check("the frames' border, thinner: a gold line and their black line, no bevel between",
    parts.border ~= nil and #parts.border.spec.lines == 2 and parts.border.spec.lines[2] == Style.DIVIDER_COLOR
    and parts.border.spec.radius == Style.DEFAULT_BORDER.radius)
check("the gold slightly darker than the frames'",
    math.abs(gold[1] - Style.BORDER_COLOR[1] * 0.32) < 1e-9 and math.abs(gold[3] - Style.BORDER_COLOR[3] * 0.32) < 1e-9)
check("one real pixel a line", parts.border.unitPixels == 1)
do
    -- (The player, 2026-10-22: the pet bar's borders smeared once it was made smaller.)
    local pet = Bars.buttons.pet[1]
    local refit, snapped, Refit, SnapBorder = {}, {}, Style.Refit, Style.SnapBorder
    Style.Refit = function(border)
        refit[border] = true
        Refit(border)
    end
    Style.SnapBorder = function(border)
        snapped[border] = true
        SnapBorder(border)
    end
    local border = Buttons.parts[pet].border
    pet.GetEffectiveScale = function() return 0.5 end
    Bars.db.petSize = 20
    Bars.LayOutAll()
    check("a button rescaled: its border drawn again for its new pixels, and put on whole ones",
        refit[border] and snapped[border] and Buttons.parts[pet].scale == 0.5)
    refit, snapped = {}, {}
    Bars.LayOutAll()
    check("laid out again at the same scale: not drawn again, put on whole pixels where it is",
        not refit[border] and snapped[border])
    Style.Refit, Style.SnapBorder, pet.GetEffectiveScale = Refit, SnapBorder, nil
end
do
    -- A slight 3D edge at the same width: the gold lit top and left, shaded
    -- bottom and right; the corners turn between the two round the curve.
    local outer = parts.border.lines[1]
    local top, left = outer.top.vertexColor, outer.left.vertexColor
    local bottom, right = outer.bottom.vertexColor, outer.right.vertexColor
    check("bevelled: the top and left lit, the bottom and right shaded, no line added",
        #parts.border.spec.lines == 2 and top[1] > gold[1] and left[1] > gold[1]
        and bottom[1] < gold[1] and right[1] < gold[1] and math.abs(top[1] - left[1]) < 1e-9)
    local n = #outer.steps / 4
    local function Red(i) return outer.steps[i].vertexColor[1] end
    local topLeftLit, bottomRightShaded, turning = true, true, false
    for i = 1, n do
        topLeftLit = topLeftLit and math.abs(Red(i) - top[1]) < 1e-9
        bottomRightShaded = bottomRightShaded and math.abs(Red(3 * n + i) - bottom[1]) < 1e-9
        if Red(n + i) < top[1] - 1e-9 and Red(n + i) > bottom[1] + 1e-9 then turning = true end
    end
    check("the top left corner lit, the bottom right shaded, the others turning between",
        n > 0 and topLeftLit and bottomRightShaded and turning, n)
    check("and the frames' own border keeps its flat look", Style.DEFAULT_BORDER.bevel == nil)
end
check("inset far enough to leave a very slight gap between buttons",
    parts.inner.anchors[1][4] == 3 and parts.inner.anchors[2][4] == -3)
check("inside the button, round the icon's square",
    parts.inner.parent == button and parts.inner.anchors[1][4] > 0 and parts.inner.anchors[2][4] < 0)
check("on the frames' semi-transparent black",
    parts.bg.layer == "BACKGROUND" and parts.bg.allPointsTo == parts.inner
    and parts.bg.colorTexture[1] == Style.BACKGROUND_COLOR[1]
    and parts.bg.colorTexture[4] == Style.BACKGROUND_COLOR[4])

Section("none of the game's art")
check("no slot background, no slot art, no frame",
    button.SlotBackground.alpha == 0 and button.SlotArt.alpha == 0 and button.NormalTexture.alpha == 0)
check("the icon square: unmasked, its baked-in edge trimmed, filling the square",
    button.icon.mask == nil and button.icon.texCoord[1] == 0.08 and button.icon.texCoord[2] == 0.92
    and button.icon.allPointsTo == parts.inner)
check("the cooldown swipe over exactly the icon", button.cooldown.allPointsTo == parts.inner)
check("the loss of control swipe over exactly the icon",
    button.lossOfControlCooldown.allPointsTo == parts.inner)
check("the charge cooldown over exactly the icon", button.chargeCooldown.allPointsTo == parts.inner)
check("pressed: a flat darkening over the icon, not the game's atlas",
    button.PushedTexture.texture == Style.FLAT_TEXTURE and button.PushedTexture.allPointsTo == parts.inner
    and button.PushedTexture.vertexColor[1] == 0 and button.PushedTexture.vertexColor[4] > 0)
check("hover: a soft light",
    button.HighlightTexture.texture == Style.FLAT_TEXTURE and button.HighlightTexture.blendMode == "ADD"
    and button.HighlightTexture.vertexColor[1] == 1)
check("checked: a wash of the border's gold",
    button.CheckedTexture.texture == Style.FLAT_TEXTURE and button.CheckedTexture.blendMode == "ADD"
    and button.CheckedTexture.vertexColor[1] == Style.BORDER_COLOR[1])
check("the main bar's strip and dividers gone",
    MainActionBar.BorderArt.alpha == 0 and actionBarDividers[1].alpha == 0 and actionBarDividers[2].alpha == 0)
check("and the game's bar 1 itself at no opacity, taking no mouse (the addon's own bar 1 in its place)",
    MainActionBar.alpha == 0 and MainActionBar.mouse == false)
check("nothing written onto the buttons, nothing forbidden called on the game's",
    button.dfuiInner == nil and #forbiddenCalls == 0, table.concat(forbiddenCalls, ", "))

Section("the end caps, always gone")
local left, right = MainActionBar.EndCaps.LeftEndCap, MainActionBar.EndCaps.RightEndCap
check("both gryphons at no opacity", left.alpha == 0 and right.alpha == 0)
check("and out of Edit Mode: their box unseen and unclickable - no field of theirs written",
    left.defaultHideSelection == nil and left.isLocked == nil
    and left.Selection.alpha == 0 and left.Selection.mouseEnabled == false
    and right.Selection.alpha == 0)

Section("the game's bars' sizes are no longer hooked")
ApplyIconSize(MainActionBar, 100)
check("Edit Mode's Icon Size left to the game's own (hidden) bar",
    math.abs(MainActionBar.actionButtons[1].container.scale - 1) < 1e-9)

Section("everything the addon replaces, gone from Edit Mode")
-- (Their box unseen and taking no mouse, by calls alone: no field written
-- onto the game's frame - that tainted the game's Edit Mode.)
local function Held(frame)
    return frame.defaultHideSelection == nil and frame.isLocked == nil
        and frame.Selection.alpha == 0 and frame.Selection.mouseEnabled == false
end
check("the player frame", Held(PlayerFrame))
check("the target and focus frames", Held(TargetFrame) and Held(FocusFrame))
check("the game's castbar", Held(PlayerCastingBarFrame))
check("the XP bar's container, while it shows XP", Held(MainStatusTrackingBarContainer))
check("but not a container showing a bar the addon does not draw (artifact)",
    not Held(SecondaryStatusTrackingBarContainer))

-- Always held: there is no switch to give any of them back.
check("no switch for any of them",
    DogsForeverUI.Frames.db.enabled == nil and DogsForeverUI.Castbar.db.enabled == nil
    and DogsForeverUI.XPBar.db.enabled == nil)

Summary()
