-- The options: a window of the addon's own in the frames' look, opened from a
-- button in the micro menu; one page in sections, the sidebar its contents;
-- one unlock and one reset for the whole UI in the header.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

LoadAddon()
Login()

local Core = DogsForeverUI
local Options = Core.Options
local W = Core.Widgets

local function Control(section, label) return Options.controls[section .. "/" .. label] end
local function SectionNamed(title)
    for _, section in ipairs(Options.sections) do
        if section.title == title then return section end
    end
end
local function Click(button, ...) button.scripts.OnClick(button, ...) end

Section("the way in: a button at the end of the micro menu")
local button = _G.DogsForeverUIOptionsButton
check("the game's Settings have no entry for it", #Settings.addOnCategories == 0)
check("there is no command either", next(SlashCmdList) == nil)
do
    local row = Core.Menus.MicroMenu.Row()
    check("the options button is the micro menu's last", button ~= nil and row[#row] == button)
    check("a child of the menu, so it fades and moves with it", button.parent == MicroMenu)
    local parts = Core.Menus.MicroMenu.parts[button]
    check("in the micro buttons' look, with the addon's own icon, whole",
        parts ~= nil and parts.art.texture == Core.MEDIA .. "icon")
    check("its hit box left alone: it is a square already", button.hitRectInsets == nil)
    check("the window is not built until it is first opened", _G.DogsForeverUIOptions == nil)
    button.scripts.OnEnter(button)
    check("its tooltip names the addon", GameTooltip:GetLines():find(Core.TITLE, 1, true) ~= nil)

    Click(button)
    check("a click opens the window", Options.IsShown() and _G.DogsForeverUIOptions:IsShown())
    check("and the button is lit while it is open", parts.isOpen() == true)
    Click(button)
    check("a second click closes it", not Options.IsShown())
    Tick(1)
    check("fading out, then gone", not _G.DogsForeverUIOptions:IsShown() and parts.isOpen() == false)
    Click(button)
    Tick(1)
end

local window = Options.window
local page = window.page

Section("the window, in the frames' look")
check("named, and Esc closes it as it does the game's windows",
    window.name == "DogsForeverUIOptions" and (function()
        for _, name in ipairs(UISpecialFrames) do if name == "DogsForeverUIOptions" then return true end end
    end)())
check("wearing the frames' own border: gold, bevel and black",
    window.border ~= nil and #window.border.lines == 3)
check("over the rest of the UI, and movable", window.strata == "DIALOG" and window.toplevel == true)
check("a header with the unlock, the reset and a close",
    window.unlockButton.label.text == "Unlock UI" and window.resetButton.label.text == "Reset everything"
    and window.closeButton ~= nil)
Click(window.closeButton)
Tick(1)
check("the close button closes it", not window:IsShown())
Options.Open()
Tick(1)

Section("one page, the sidebar its contents")
-- (No Unit frames, Sizes or Positions since 2026-10-03: Unlock Mode has them.)
local TITLES = { "Cooldown manager", "Auto-hide", "Extras", "Party targeting", "Profiles" }
do
    local titles, ordered = {}, true
    for index, section in ipairs(Options.sections) do
        titles[index] = section.title
        if index > 1 then ordered = ordered and section.top > Options.sections[index - 1].top end
    end
    check("sections top to bottom: " .. table.concat(TITLES, ", "),
        table.concat(titles, ",") == table.concat(TITLES, ","), table.concat(titles, ","))
    check("laid out down the one page", ordered)
    local navOk = true
    for _, section in ipairs(Options.sections) do
        navOk = navOk and section.nav ~= nil and section.nav.label.text == section.title
    end
    check("a sidebar entry for each", navOk)
    check("the page is as tall as its sections", page.height > Options.sections[#Options.sections].top)
    check("the first lit to start", Options.Active() == Options.sections[1]
        and Options.sections[1].nav.accent:IsShown())

    local positions = SectionNamed("Profiles")
    Click(positions.nav)
    check("a click lights that entry at once", Options.Active() == positions and positions.nav.selected
        and not Options.sections[1].nav.selected)
    check("and the page heads for that section", Options.scroller.Target() == positions.top - 20,
        tostring(Options.scroller.Target()))
    Tick(0.1)
    local partWay = window.page.parent:GetVerticalScroll()
    check("gliding there, not jumping", partWay > 0 and partWay < positions.top - 20, partWay)
    for _ = 1, 20 do Tick(0.05) end
    check("and arriving", math.abs(window.page.parent:GetVerticalScroll() - (positions.top - 20)) < 1)

    local scroll = window.page.parent
    scroll.scripts.OnMouseWheel(scroll, 1)
    for _, hook in ipairs(scroll.hooks.OnMouseWheel or {}) do hook(scroll, 1) end
    for _ = 1, 20 do Tick(0.05) end
    check("scrolling by hand lights the section being read",
        Options.Active() ~= positions and Options.Active().top <= scroll:GetVerticalScroll() + 28,
        Options.Active().title)
    Options.scroller.ScrollTo(0, true)
    check("back at the top, the first", Options.Active() == Options.sections[1])
end

Section("everything always on: no switch for any part of the UI")
do
    local enabled = {}
    for name in pairs(Options.controls) do
        if name:find("/Enabled$") then enabled[#enabled + 1] = name end
    end
    check("no Enabled anywhere", #enabled == 0, table.concat(enabled, ", "))
    check("no Castbars or XP bar section: nothing left to switch there",
        SectionNamed("Castbars") == nil and SectionNamed("XP bar") == nil)
    for _, gone in ipairs({ "Unit frames/Show level", "Unit frames/Show incoming heals",
                            "Unit frames/Style nameplates", "Castbars/Hold failed casts",
                            "XP bar/Show rested XP" }) do
        check("no " .. gone, Control(gone:match("^(.-)/"), gone:match("/(.*)$")) == nil)
    end
    local toggle = Control("Cooldown manager", "IDs on tooltips")
    check("a switch on a row of its own sits at the right edge",
        toggle.points[1] == "RIGHT" and toggle.points[2] == toggle.row)

    -- Wrapped text pinned at both sides and as tall as its lines, so no last
    -- word can drop out of sight.
    local pinned = true
    for _, section in ipairs(Options.sections) do
        for _, row in ipairs(section.rows) do
            local text = row.description
            if text and not (#text.anchors == 2 and text.height == text:GetStringHeight()) then pinned = false end
        end
        if section.note and not (#section.note.anchors == 2 and section.note.height > 0) then pinned = false end
    end
    check("every description and note pinned both sides, as tall as its lines", pinned)

    -- No drop shadow on any text in the window: a shadow a fraction of a
    -- pixel off smeared the letters.
    local shadowed = 0
    local function InWindow(f)
        while f do
            if f == window then return true end
            f = f.parent
        end
    end
    for _, f in ipairs(allFrames) do
        for _, region in ipairs(InWindow(f) and f.regions or {}) do
            local o = region.shadowOffset
            if region.kind == "FontString" and o and (o[1] ~= 0 or o[2] ~= 0) then shadowed = shadowed + 1 end
        end
    end
    check("no text in the window has a shadow", shadowed == 0, shadowed)
end

Section("switches")
do
    check("no Unit frames switches: their menus in Unlock Mode have them",
        Control("Unit frames", "Health text") == nil)
    local name = Control("Extras", "Hide the Issue Reporter")
    local db = Core.Menus.db
    local was = db.hideIssueReporter and true or false
    check("showing the saved value", name.target == (was and 1 or 0) and name.value == (was and 1 or 0))
    Click(name)
    check("clicking writes the setting", db.hideIssueReporter == not was)
    check("and the switch slides", name.target == (was and 0 or 1) and name.value == (was and 1 or 0))
    Tick(0.05)
    check("part way", name.value > 0 and name.value < 1, name.value)
    Tick(0.2)
    Click(name.row)
    check("its name clicks it too", db.hideIssueReporter == was)
    Tick(0.3)

    local reporter = Control("Extras", "Hide the Issue Reporter")
    check("the Issue Reporter under Extras, its own row with a line under its name; no chat copy switch (always on)",
        reporter ~= nil and reporter.row.description ~= nil and Control("Extras", "Chat copy button") == nil)
    -- (Rows a client does not offer are declared `hidden`: retail has no fishing or skinning ones.)
    local classic = not Core.RETAIL
    check("fishing, skinnable and cloth rows where the client offers them (not retail), camping on both",
        (Control("Extras", "Double-click fishing") ~= nil) == classic and Control("Extras", "Double-click camping") ~= nil
        and (Control("Extras", "Skinnable on tooltips") ~= nil) == classic
        and (Control("Extras", "Cloth on tooltips") ~= nil) == classic)
    local micro = Control("Auto-hide", "Micro Menu")
    check("the micro menu under Auto-hide, a small switch like the bars', first, beside Action Bar 1",
        micro ~= nil and micro.row.description == nil
        and micro.row.parent == Control("Auto-hide", "Action Bar 1").row.parent
        and micro.row.points[4] < Control("Auto-hide", "Action Bar 1").row.points[4])
    Click(micro)
    check("writing its setting", Core.Menus.db.quietMicroMenu == false)
    Click(micro)
    local bar1, bar2, bar3, pet = Control("Auto-hide", "Action Bar 1"), Control("Auto-hide", "Action Bar 2"),
        Control("Auto-hide", "Action Bar 3"), Control("Auto-hide", "Pet Bar")
    check("a small switch per action bar, two to a row",
        bar1 and bar2 and bar3 and pet and bar2.row.parent == bar3.row.parent
        and bar2.row.parent ~= bar1.row.parent and bar3.row.points[4] > bar2.row.points[4])
    check("no bag bar switch: gone until a bag is open is the look", Control("Auto-hide", "Bag Bar") == nil)
    Click(bar1.row)
    check("a small switch's name clicks it too", Core.Menus.db.fadeActionBar1 ~= nil
        and bar1.target == (Core.Menus.db.fadeActionBar1 and 1 or 0))
    Click(bar1.row)
end

Section("no colour settings anywhere")
check("no label mentions colour swatches, alpha or opacity", (function()
    for _, f in ipairs(allFrames) do
        for _, region in ipairs(f.regions) do
            local text = type(region.text) == "string" and region.text:lower()
            if text and (text:find("alpha") or text:find("opacit") or text:find("swatch")) then
                return false
            end
        end
    end
    return true
end)())

Section("choices side by side")
do
    check("no aura choices: the frames' menus in Unlock Mode have them", Control("Unit frames", "Target auras") == nil)
    local grow = Control("Cooldown manager", "Bars grow")
    Click(grow.segments[2])
    check("which way the cooldown bars grow, likewise", Core.Cooldowns.db.growDirection == "down")
    Click(grow.segments[1])
end

Section("sliders")
do
    local fade = Control("Auto-hide", "Hide after")
    check("the auto-hide wait", fade ~= nil)
    local low, high = fade:GetMinMaxValues()
    check("the wait from 0.1 to 3 seconds (0 never showed them)", low == 0.1 and high == 3, low .. ".." .. high)
    check("showing the saved wait, written beside it", fade:GetValue() == 3 and fade.valueText.text == "3.0s")
    check("its bar filled gold up to it", fade.track.value == 3 and fade.track.statusColor[1] == W.GOLD[1])
    fade:SetValue(1.23)
    check("moving it writes the wait, in tenths", math.abs(Core.Menus.db.fadeOutDelay - 1.2) < 1e-9,
        tostring(Core.Menus.db.fadeOutDelay))
    Core.Menus.db.fadeOutDelay = 2.345
    fade.Refresh()
    check("showing a setting never writes it", Core.Menus.db.fadeOutDelay == 2.345)
    fade:SetValue(3)
    -- The knob: a frame over the track and its border, drawn where the value
    -- is; the thumb the mouse drags is invisible under it. (A visible thumb
    -- is the slider's own texture, and the track drew a dark band over it.)
    local knob = fade.knob
    check("the knob is drawn over the track's outline",
        knob ~= nil and knob:GetFrameLevel() > fade.track.border.edge:GetFrameLevel())
    check("the thumb the mouse drags is invisible, the knob's size",
        fade.thumb.colorTexture[4] == 0 and fade.thumb.width == knob.width and fade.thumb.height == knob.height)
    check("at the end of the bar for the most", knob.points[1] == "LEFT"
        and math.abs(knob.points[4] - (fade.width - knob.width)) < 1e-9, knob.points[4])
    fade:SetValue(0.1)
    check("at its start for the least", math.abs(knob.points[4]) < 1e-9)
    fade:SetValue(1.6)
    local share = (fade:GetValue() - 0.1) / 2.9
    check("along the bar as far as the wait is", math.abs(knob.points[4] - (fade.width - knob.width) * share) < 1e-6,
        tostring(fade:GetValue()) .. " " .. tostring(knob.points[4]))
    fade:SetValue(3)
end

-- (The Sizes and Positions sections went to Unlock Mode, 2026-10-03:
-- tests/snap.lua, tests/party.lua, tests/combo.lua, tests/xp.lua.)

Section("one unlock for the whole UI, in the header")
do
    local unlock = window.unlockButton
    check("no grid while locked", Core.grid == nil or not Core.grid:IsShown())
    Click(unlock)
    check("one click unlocks everything that can be placed",
        Core.Frames.db.unlocked == true and Core.Castbar.db.unlocked == true and Core.XPBar.db.unlocked == true)
    check("the button now locks, lit gold", unlock.label.text == "Lock UI" and unlock.style == "active")
    local own = Options.Unlock.bar
    check("Unlock Mode, the addon's own: its bar", own ~= nil and own:IsShown() and own.title.text == "Unlock Mode")
    check("the options make way for it", not Options.IsShown())
    check("the grid on", Core.grid ~= nil and Core.grid:IsShown())
    Click(unlock)
    check("a second click locks everything again", Core.Frames.db.unlocked == false
        and unlock.label.text == "Unlock UI" and not Core.grid:IsShown() and not own:IsShown())
    check("and the options come back", Options.IsShown())
    -- Never opened in combat (EllesmereUI's).
    inCombat = true
    Click(unlock)
    check("not in combat", Core.Frames.db.unlocked == false and Core.Castbar.db.unlocked == false)
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    Click(unlock)
    pendingTimer = nil
    local castbar = Core.Castbar.CastBar.castbar
    castbar.scripts.OnMouseUp(castbar, "RightButton")
    check("right-clicking a piece does not lock the UI: closing Edit Mode does",
        Core.Castbar.db.unlocked == true and pendingTimer == nil)
    Core.SetUnlocked(false)
    Tick(1)
    check("locked again, the header follows", unlock.label.text == "Unlock UI")
end

Section("the cooldown manager: a section like the rest")
do
    local db = Core.Cooldowns.db
    local list = Options.idList
    local box, add = list.box, list.add
    check("a box for the ID and ONE Add button", box == _G.DogsForeverUIOptionsIdBox and add.label.text == "Add")
    check("its hint says what goes in it", box.hint.text == "Spell or item ID")
    check("saying so while the list is empty", list.empty:IsShown() and list.count == 0)
    local before = SectionNamed("Auto-hide").top
    box:SetText("7620")
    Click(add)
    check("a spell's ID adds that spell", #db.tracked == 1 and db.tracked[1].kind == "spell"
        and db.tracked[1].id == 7620)
    check("the box emptied for the next", box:GetText() == "")
    check("a line in place of the empty one", list.count == 1 and not list.empty:IsShown()
        and list.lines[1]:IsShown())
    box:SetText("6256")
    box.scripts.OnEnterPressed(box)
    check("Enter adds too: an item", #db.tracked == 2 and db.tracked[2].kind == "item")
    check("and the list grows, the sections under it moving down",
        list.count == 2 and SectionNamed("Auto-hide").top > before)
    box:SetText("424242")
    Click(add)
    check("an unknown ID is refused, and the toast says why", #db.tracked == 2
        and (function()
            for _, f in ipairs(allFrames) do
                if f.message and f.message:find("424242") and f:IsShown() then return true end
            end
        end)())

    local first, second = list.lines[1], list.lines[2]
    check("a line for each: icon, the name on one line (cut short, never wrapped), the ID alone small under it",
        first.text.text == "Fishing" and first.text.wordWrap == false and tostring(first.id.text) == "7620"
        and first.id.points[2] == first.text and first.id.points[3] == "BOTTOMLEFT", tostring(first.text.text))
    check("a spell with a cooldown, its buff never seen: Cooldown, said in words (no Duration that may not be)",
        not first.choice:IsShown() and first.fixed.text == "Cooldown")
    db.tracked[1].buff = true                 -- its buff seen on the player after a cast
    Core.RefreshOptions()
    check("its buff seen after its cast: Cooldown, Duration or Both",
        first.choice:IsShown() and #first.choice.segments == 3
        and first.choice.segments[1].style == "active")
    Click(first.choice.segments[3])
    check("picking Both sets that spell to both", db.tracked[1].track == "both")
    Click(first.choice.segments[1])
    check("an item has no choice: the word", not second.choice:IsShown() and second.fixed.text == "Cooldown")
    check("each line: Bar or Icon, a bar to start", #first.look.segments == 2
        and first.look.segments[1].label.text == "Bar" and first.look.segments[1].style == "active")
    Click(first.look.segments[2])
    check("Icon picked: that one on the rings, the other still a bar",
        db.tracked[1].display == "icon" and db.tracked[2].display == nil
        and first.look.segments[2].style == "active" and Core.Cooldowns.iconHolder:IsShown())
    Click(first.look.segments[1])
    check("and back to a bar", db.tracked[1].display == nil and not Core.Cooldowns.iconHolder:IsShown())

    -- (The player, 2026-10-20: "show current spec spells first, a divider, then other
    -- added spec spells kinda disabled".)
    check("all of this spec's: no divider, nothing dimmed", not list.divider:IsShown()
        and first.alpha ~= 0.45 and second.alpha ~= 0.45)
    -- The game's spellbook, as it answers on retail: the other specs' spells in it too,
    -- marked off-spec. Fishing (7620) another spec's; 2050 (Holy Word: Serenity, no
    -- cooldown told of out of its spec, never cast) another's too; anything else this spec's,
    -- or not in the book (a buff or proc: 20375).
    local OFF_SPEC = { [7620] = true, [2050] = true }
    local wasBook = C_SpellBook
    C_SpellBook = C_SpellBook or {}
    local wasFind = C_SpellBook.FindSpellBookSlotForSpell
    C_SpellBook.FindSpellBookSlotForSpell = function(id, _, _, _, includeOffSpec)
        if OFF_SPEC[id] then return includeOffSpec and 40 or nil, includeOffSpec and 0 or nil end
        if id ~= 20375 then return 12, 0 end
    end
    Core.RefreshOptions()
    -- (The player, on Forever: "classic has no different spec structure - I DO have these".)
    check("Forever has no specs: never grouped away, nothing dimmed, whatever the game says it knows",
        first.index == 1 and not list.divider:IsShown() and first.alpha ~= 0.45)
    Core.RETAIL = true
    local height = SectionNamed("Auto-hide").top
    Core.RefreshOptions()
    check("this spec's first (the item), a divider, then another spec's, dimmed",
        first.index == 2 and second.index == 1 and list.divider:IsShown()
        and first.alpha == 1 and second.alpha == 0.45 and SectionNamed("Auto-hide").top > height,
        tostring(first.index) .. " " .. tostring(second.alpha) .. " " .. tostring(list.divider:IsShown()))
    check("the saved order left as it is", db.tracked[1].id == 7620 and db.tracked[2].kind == "item")
    -- (The player: what it tracks showed wrong out of its spec.)
    check("another spec's: no choice and no Cooldown or Duration that could be wrong - said so",
        not second.choice:IsShown() and second.fixed:IsShown() and second.fixed.text == "Set in its spec")
    -- (Clearcasting and the like: a buff, no spell in the book - in any spec.)
    check("a buff or proc (not in the spellbook) is never another spec's",
        Core.Cooldowns.IsCurrent({ kind = "spell", id = 20375 }))
    -- (The player, 2026-10-22, in Shadow: "how come i still see holy word spell" - out of
    -- its spec it told of no cooldown and had never been seen cast, so it passed as a proc.)
    local baseCooldown = GetSpellBaseCooldown
    GetSpellBaseCooldown = function() return 0 end
    check("another spec's spell with no cooldown told of, never cast: the spellbook says another spec's",
        not Core.Cooldowns.IsCurrent({ kind = "spell", id = 2050 }))
    GetSpellBaseCooldown = baseCooldown
    Core.RETAIL = false
    C_SpellBook.FindSpellBookSlotForSpell = wasFind
    C_SpellBook = wasBook
    Core.RefreshOptions()
    check("this spec's again: in its place, the divider gone", first.index == 1 and not list.divider:IsShown())

    Click(first.remove)
    check("the cross takes it out", #db.tracked == 1 and db.tracked[1].kind == "item")
    Click(first.remove)
    check("down to nothing, and the lines go", #db.tracked == 0 and not first:IsShown()
        and list.empty:IsShown() and SectionNamed("Auto-hide").top == before)
end

Section("one reset for the whole UI")
do
    local reset = window.resetButton
    Core.Castbar.db.barWidth = 222
    Core.Frames.db.classColors = false
    Core.Menus.db.fadeActionBar3 = false
    Click(reset)
    check("one click only asks, in red", Core.Castbar.db.barWidth == 222
        and reset.label.text == "Really reset?" and reset.style == "armed")
    Click(reset)
    check("the second resets every part at once", Core.Castbar.db.barWidth == 130
        and Core.Frames.db.classColors == true and Core.Menus.db.fadeActionBar3 == true)
    check("and the button is itself again", reset.label.text == "Reset everything" and reset.style == nil)
    Click(reset)
    pendingTimer()
    check("left alone, an armed button calms down", reset.label.text == "Reset everything" and not reset.armed)
    Core.Castbar.db.barWidth = 222
    inCombat = true
    Click(reset)
    Click(reset)
    check("nothing resets in combat", Core.Castbar.db.barWidth == 222)
    inCombat = false
    if reset.armed then pendingTimer() end
    -- (No secure click: the addon writes nothing into the game's Edit Mode.)
    check("the reset never goes through the game's Edit Mode", window.secureReset == nil)
end

Section("party targeting: a key box for next and for previous member")
do
    local box = Control("Party targeting", "Next party member")
    local command = "CLICK DogsForeverUIPartyNext:LeftButton"
    local UNBOUND = NOT_BOUND or "Not bound"
    check("both rows there, unbound to start", box ~= nil and box.label.text == UNBOUND
        and Control("Party targeting", "Previous party member").label.text == UNBOUND)
    -- (The player, 2026-10-17: movement keys were bound just by pressing them with the options open.)
    check("not clicked: taking neither keys nor wheel (setting their scripts turned both on)",
        not box:IsKeyboardEnabled() and not box.wheelEnabled)
    box.scripts.OnKeyDown(box, "W")
    box.scripts.OnMouseWheel(box, 1)
    check("and a key or the wheel reaching it binds nothing", GetBindingKey(command) == nil
        and GetBindingAction("W") == "")
    Click(box)
    box.scripts.OnLeave(box)
    for _, hook in ipairs(box.hooks.OnLeave) do hook(box) end
    check("the mouse gone from the box: it takes no more keys",
        not box.listening and not box:IsKeyboardEnabled() and box.label.text == UNBOUND)
    Click(box)
    check("clicked, it waits for a key, the keyboard taken", box.label.text == "Press a key" and box:IsKeyboardEnabled())
    shiftDown = true
    box.scripts.OnKeyDown(box, "LSHIFT")
    check("a modifier alone binds nothing", box.listening and GetBindingKey(command) == nil)
    box.scripts.OnMouseWheel(box, 1)
    shiftDown = false
    check("Shift+wheel up: bound to a click of the cycle button, saved into the game's bindings",
        GetBindingKey(command) == "SHIFT-MOUSEWHEELUP" and savedBindings[1][#savedBindings[1]][2] == command
        and box.label.text == "SHIFT-MOUSEWHEELUP" and not box:IsKeyboardEnabled())
    SetBinding("G", "JUMP")
    Click(box)
    box.scripts.OnKeyDown(box, "G")
    check("a new key replaces the old one, taken from what had it",
        GetBindingKey(command) == "G" and select("#", GetBindingKey(command)) == 1 and GetBindingKey("JUMP") == nil)
    local function MouseDown(mouse)
        box.scripts.OnMouseDown(box, mouse)
        for _, hook in ipairs(box.hooks.OnMouseDown) do hook(box, mouse) end
    end
    MouseDown("Button4")
    check("a mouse button binds only while it waits", GetBindingKey(command) == "G")
    Click(box)
    MouseDown("Button4")
    check("a mouse button while waiting: bound", GetBindingKey(command) == "BUTTON4")
    Click(box)
    box.scripts.OnKeyDown(box, "ESCAPE")
    check("Escape clears it", GetBindingKey(command) == nil and box.label.text == "Not bound")
    inCombat = true
    Click(box)
    box.scripts.OnKeyDown(box, "H")
    check("nothing bound in combat", GetBindingKey(command) == nil and not box.listening)
    inCombat = false
end

Section("profiles, at the end of the page")
do
    local Profiles = Core.Profiles
    local list = Options.profileList
    local box, save = list.box, list.save
    check("a name box and Save", box == _G.DogsForeverUIOptionsProfileName and save.label.text == "Save")
    check("nothing saved yet: the list says so", list.count == 0 and list.empty:IsShown())

    Core.Castbar.db.barWidth = 175
    box:SetText("Raid")
    box.scripts.OnEnterPressed(box)
    check("Enter saves a new profile at once", Profiles.Exists("Raid") and Profiles.saved.Raid.castbar.barWidth == 175)
    check("and it is listed, with Load and Delete", list.count == 1 and list.lines[1].name.label.text == "Raid"
        and list.lines[1].load.label.text == "Load" and list.lines[1].delete.label.text == "Delete")

    Core.Castbar.db.barWidth = 185
    Click(save)
    check("saving over a profile asks first", save.label.text == "Overwrite?"
        and Profiles.saved.Raid.castbar.barWidth == 175)
    Click(save)
    check("and the second click does it", save.label.text == "Save" and Profiles.saved.Raid.castbar.barWidth == 185)

    box:SetText("Solo")
    Click(save)
    check("a second profile, in name order", list.count == 2 and list.lines[1].name.label.text == "Raid"
        and list.lines[2].name.label.text == "Solo")
    Click(list.lines[1].name)
    check("clicking a name puts it in the box", box:GetText() == "Raid")

    Core.Castbar.db.barWidth = 130
    local load = list.lines[1].load
    Click(load)
    check("Load asks first", load.label.text == "Really load?" and Core.Castbar.db.barWidth == 130)
    Click(load)
    check("then loads it", Core.Castbar.db.barWidth == 185)

    local delete = list.lines[1].delete
    Click(delete)
    check("Delete asks first", delete.label.text == "Really delete?" and Profiles.Exists("Raid"))
    Click(delete)
    check("then deletes it", not Profiles.Exists("Raid") and list.count == 1
        and list.lines[1].name.label.text == "Solo" and not list.lines[2]:IsShown())
end

Section("a dropdown's words never run out of it")
do
    -- (The player, 2026-10-03: "those texts shouldnt overflow out of
    -- comboboxes like that in general".)
    local value = "a"
    local long = string.rep("x", 40)            -- 240 wide in the harness
    local choices = { { value = "a", label = "Short" }, { value = "b", label = long } }
    local dropdown = W.Dropdown(UIParent, 100, choices, function() return value end, function(v) value = v end)
    dropdown.Refresh()
    check("the picked choice's words held inside the button, on one line",
        #dropdown.label.anchors == 2 and dropdown.label.anchors[2][1] == "RIGHT" and dropdown.label.wordWrap == false)
    dropdown.scripts.OnClick(dropdown)
    local list = W.Popup()
    check("the list as wide as its widest choice needs, wider than its button",
        list.width == #long * 6 + 2 * 8 + 4, tostring(list.width))
    local item = list.items[2]
    check("each choice's words held inside its item", #item.label.anchors == 2 and item.label.anchors[2][1] == "RIGHT"
        and item.width == list.width - 4)
    W.ClosePopup()
    choices[2].label = string.rep("x", 100)
    dropdown.scripts.OnClick(dropdown)
    check("never wider than the most it may be: cut short instead", list.width == 320)
    W.ClosePopup()
end

Summary()
