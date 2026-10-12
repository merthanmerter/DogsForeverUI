-- Unlock Mode, the player's list of 2026-10-02: the pieces anchored to start
-- with, each piece's own settings in its cog menu, and no Default Preset
-- (gone 2026-10-03) (Core\Snap.lua, Options\Unlock.lua).
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

LoadAddon()
Login()

local Core = DogsForeverUI
local Snap = Core.Snap
local Unlock = Core.Options.Unlock
local W = Core.Widgets
local db = Snap.db
local plates = Core.Frames.plates

local function Put(frame, left, bottom, width, height)
    frame.left, frame.bottom, frame.width, frame.height = left, bottom, width, height
    frame.top = bottom + height
    frame.right = nil
end
local function Clear(frame) Put(frame, -10000, -10000, 1, 1) end
local function Near(a, b) return a and b and math.abs(a - b) < 0.05 end
local function Click(button, ...) button.scripts.OnClick(button, ...) end
local function Same(a, b)
    return a and b and Near(a[1], b[1]) and Near(a[2], b[2]) and Near(a[3], b[3])
end
local function Frame(id) return Snap.EntryById(id).frame end
local function LinkTo(id)
    local link = Snap.LinkOf(Snap.EntryById(id))
    return link and link.to, link
end
-- An item of the dropdown list open now.
local function Pick(dropdown, index)
    Click(dropdown)
    Click(W.Popup().items[index])
end

---------------------------------------------------------------------------
Section("anchored to start with: focus, pet, cooldowns to the player; ToT to the target; 5SR to the castbar; swing to the 5SR")
do
    for _, entry in ipairs(Snap.entries) do Clear(entry.frame) end
    Put(Frame("player"), 700, 300, 150, 40)
    Put(Frame("focus"), 500, 300, 150, 40)
    Put(Frame("pet"), 700, 240, 100, 20)
    Put(Frame("cooldowns"), 700, 360, 150, 20)
    Put(Frame("target"), 1100, 300, 150, 40)
    Put(Frame("targettarget"), 1300, 300, 100, 30)
    Put(Frame("castbar"), 900, 400, 130, 20)
    Put(Frame("fsr"), 900, 432, 130, 20)
    Put(Frame("swing"), 900, 464, 130, 20)
    db.snaps, db.anchoredByDefault = {}, nil

    local waiting = Snap.AnchorDefaults()
    check("every one anchored, none left waiting", not waiting)
    local wanted = { focus = "player", pet = "player", cooldowns = "player", targettarget = "target",
                     fsr = "castbar", swing = "fsr" }
    for id, to in pairs(wanted) do
        local got, link = LinkTo(id)
        check(id .. " anchored to " .. to .. ", on purpose", got == to and link.explicit == true)
    end
    local _, focus = LinkTo("focus")
    local gap = Snap.Box(Snap.EntryById("focus")).r - Snap.Box(Snap.EntryById("player")).l
    check("from where they are: the focus on the player's left, as far off as it is",
        focus.point == "RIGHT" and focus.rel == "LEFT" and gap < 0
        and Near(focus.x, gap) and Near(focus.y, 0),
        tostring(focus.point) .. " " .. tostring(focus.x) .. " " .. tostring(focus.y))
    local _, pet = LinkTo("pet")
    check("the pet under the player", pet.point == "TOP" and pet.rel == "BOTTOM")
    local _, swing = LinkTo("swing")
    check("the swing timers over the 5SR", swing.point == "BOTTOM" and swing.rel == "TOP")
    check("nothing else anchored", LinkTo("player") == nil and LinkTo("castbar") == nil and LinkTo("target") == nil)

    -- Once only.
    Core.SetUnlocked(true)
    Snap.Unanchor(Snap.EntryById("focus"))
    Snap.AnchorDefaults()
    check("let go of: stays let go, never anchored again by itself", LinkTo("focus") == nil)
    Core.RevertEditMode()
    Core.SetUnlocked(false)

    -- An anchor of the player's own is kept.
    db.snaps, db.anchoredByDefault = {}, nil
    db.snaps.pet = { to = "target", point = "LEFT", rel = "RIGHT", x = 0, y = 0, explicit = true }
    Snap.AnchorDefaults()
    check("one anchored already: left as it is", LinkTo("pet") == "target")

    -- One not laid out yet waits.
    db.snaps, db.anchoredByDefault = {}, nil
    Put(Frame("swing"), 0, 0, 0, 0)
    check("one with no place yet: waited for", Snap.AnchorDefaults() == true and LinkTo("swing") == nil)
    Put(Frame("swing"), 900, 464, 130, 20)
    check("then anchored", Snap.AnchorDefaults() == false and LinkTo("swing") == "fsr")

    -- Reset: anchored again.
    Snap.Unanchor(Snap.EntryById("focus"))
    Snap.ReanchorAfterReset(Snap.EntryById("focus"))
    check("Reset To Default Position: anchored again", LinkTo("focus") == "player")
    check("kept with the places (saved, reverted, in profiles)",
        Snap.placement.anchoredByDefault == true)
    db.snaps = {}
end

---------------------------------------------------------------------------
Section("a piece's own settings in its cog menu: auras above or below, castbar, texts")
do
    for _, entry in ipairs(Snap.entries) do Clear(entry.frame) end
    Core.SetUnlocked(true)
    Put(plates.target, 1100, 300, 150, 40)
    plates.target.shown = true
    Tick(0.02)
    local target = Snap.EntryOf(plates.target)
    Snap.OpenCog(target, Snap.movers[target])
    local menu = Unlock.menu
    local rows = menu.block and menu.block.rows or {}
    local labels = {}
    for index, row in ipairs(rows) do labels[index] = row.label.text end
    -- (The options' Unit frames and Sizes sections came here, 2026-10-03.)
    check("the target's: Auras, Castbar, texts, colours, then the frames' sizes and layer",
        table.concat(labels, ",") == "Auras,Castbar,Health text,Resource text,Class colours,"
            .. "Width,Health height,Power height,Cast height,Text padding,Layer",
        table.concat(labels, ","))
    check("no heading, no note over them", menu.block.title == nil and menu.block.note == nil)
    local fdb = Core.Frames.db
    check("as the settings are", rows[1].control.label.text == "Below" and rows[2].control.target == 1)
    Pick(rows[1].control, 2)
    check("Auras: Above - kept, at once", fdb.targetAuras == "above" and rows[1].control.label.text == "Above")
    Click(rows[2].control)
    check("Castbar off - kept, at once, the switch showing it", fdb.showCastbar == false
        and rows[2].control.target == 0)
    check("each an unsaved change of Unlock Mode's, like a move", Core.EditModePending())
    Core.RevertEditMode()
    check("Exit Without Saving: the settings back as they were",
        fdb.targetAuras == "below" and fdb.showCastbar == true and not Core.EditModePending())
    local width = rows[6].control
    width:SetText("170")
    width.scripts.OnEnterPressed(width)
    check("a size typed: the frames' width, a change to save", fdb.barWidth == 170 and Core.EditModePending())
    Core.CommitEditMode()
    check("saved: kept", fdb.barWidth == 170 and not Core.EditModePending())
    fdb.barWidth = 150

    local holder = Core.Cooldowns.holder
    Put(holder, 700, 360, 150, 20)
    holder.shown = true
    Tick(0.02)
    local cooldowns = Snap.EntryOf(holder)
    Snap.OpenCog(cooldowns, Snap.movers[cooldowns])
    rows = menu.block.rows
    check("the cooldowns': their layer, Bars grow and IDs on tooltips",
        #rows == 3 and rows[1].label.text == "Layer" and rows[2].label.text == "Bars grow"
        and rows[3].label.text == "IDs on tooltips")

    menu:Hide()
    Core.SetUnlocked(false)
    Clear(plates.target)
    Clear(holder)
end

---------------------------------------------------------------------------
Section("no Default Preset any more: the addon places its pieces itself")
do
    -- (Gone 2026-10-03, the player: "since we control everything from DogUI
    -- settings I shouldnt need this Default Preset anymore".)
    check("no layout of the addon's in the game's Edit Mode, nothing to set up",
        Core.DEFAULT_LAYOUT == nil and Core.Layouts == nil and Snap.placement.layoutsReady == nil)
    check("and nothing written to the game's layouts as the character loaded",
        C_EditMode.lastSave == nil)
end

---------------------------------------------------------------------------
Section("a stored layout naming a frame of the addon's: the game's default spot back")
do
    -- (The player, 2026-10-10, the "Dog's Forever UI" layout chosen with the
    -- addon off: "Couldn't find region named 'DogsForeverUIPlaceChat'".)
    local CHAT = 3
    EditModePresetLayoutManager.defaults[CHAT] =
        { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", offsetX = 35, offsetY = 50 }
    local function Stale()
        return { system = CHAT, isInDefaultPosition = false, anchorInfo =
            { point = "TOPLEFT", relativeTo = "DogsForeverUIPlaceChat", relativePoint = "TOPLEFT", offsetX = 0, offsetY = 0 } }
    end
    C_EditMode.saved = { activeLayout = 3, layouts = { { layoutName = "Dog's Forever UI", layoutType = 1, systems = {
        Stale(),
        { system = 4, isInDefaultPosition = false, anchorInfo =
            { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", offsetX = 1, offsetY = 2 } },
    } } } }
    Fire("EDIT_MODE_LAYOUTS_UPDATED")
    local systems = C_EditMode.saved.layouts[1].systems
    check("the game reading its layouts: the chat's anchor is the game's default one, stored",
        systems[1].anchorInfo.relativeTo == "UIParent" and systems[1].anchorInfo.offsetX == 35
        and systems[1].isInDefaultPosition == true)
    check("every other system as it was",
        systems[2].anchorInfo.offsetX == 1 and systems[2].isInDefaultPosition == false)

    C_EditMode.lastSave = nil
    Fire("EDIT_MODE_LAYOUTS_UPDATED")
    check("nothing naming the addon: nothing stored", C_EditMode.lastSave == nil)

    -- (The game's own save writes its copy, which may still be the old one.)
    C_EditMode.saved.layouts[1].systems[1] = Stale()
    EventRegistry:TriggerEvent("EditMode.SavedLayouts")
    check("after the game saves its layouts: mended again",
        C_EditMode.saved.layouts[1].systems[1].anchorInfo.relativeTo == "UIParent")
    EditModePresetLayoutManager.defaults[CHAT] = nil
end

Summary()
