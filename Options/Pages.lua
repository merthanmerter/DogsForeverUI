-- What the options window shows, top to bottom. The controls are Widgets.lua's
-- and the layout Panel.lua's.
--
-- Everything the addon draws is always on (the player, 2026-09-29: "if the
-- addon is installed all its features should be enabled"): no Enabled
-- anywhere, and no switches for the castbar group, the XP bar, the level, the
-- incoming heals or the nameplates. What is left is what the player can
-- reasonably want either way, and where things go:
--
--   Unit frames        what the frames show, where their auras go
--   Cooldown manager   its list
--   Auto-hide          the micro menu and the action bars
--   Extras             the chat copy button, the Issue Reporter
--   Sizes, Positions   every size and every place, in one section each
--   Profiles           all of it saved for other characters
--
-- Small switches whose names say what they do sit two to a row with no line
-- under them; a section's note says anything more. No unlock or reset in any
-- section: those are the two buttons in the window's header, for the whole UI.
--
-- There are no colour settings anywhere: the look is fixed (Core\Style.lua), so
-- every bar in the addon matches every other.

local Options = DogsForeverUI.Options

-- For a centred bar's width box: a new width moves the bar by half the change,
-- so it grows or shrinks on both sides instead of out to the right.
local function KeepCentred(module)
    return function(old, new)
        local db = module.db
        if type(old) == "number" and type(new) == "number" and db.barLeft then
            db.barLeft = db.barLeft + (old - new) / 2
        end
    end
end

Options.Describe(function(page)
    local UI = DogsForeverUI
    local Frames, Castbar, XP = UI.Frames, UI.Castbar, UI.XPBar
    local Menus, Chat, Cooldowns = UI.Menus, UI.Chat, UI.Cooldowns

    ---------------------------------------------------------------------------
    page:Section("Unit frames",
        "Each frame's buffs and debuffs go below it, above it, or nowhere; its castbar takes the other side. The party's four frames are a column placed as one; with the game's \"Use Raid-Style Party Frames\" (Edit Mode, Party Frames) on, its raid-style frames show instead, in this look's bar textures.")
    for _, entry in ipairs({
        { key = "classColors",    label = "Class and reaction colours" },
        { key = "showCastbar",    label = "Target and focus casts" },
        { key = "showHealthText", label = "Health text" },
        { key = "showPowerText",  label = "Resource text" },
    }) do
        page:Check({ module = Frames, key = entry.key, label = entry.label, compact = true })
    end
    page:EndRow()
    -- Where each frame's buffs and debuffs go. They were Edit Mode's "Buffs on
    -- top" until the frames left Edit Mode; the rows are the addon's own now.
    -- The party's four frames share one setting (beside them, or none).
    local seen = {}
    for _, entry in ipairs(Frames.UnitAuras.UNITS) do
        if not seen[entry.key] then
            seen[entry.key] = true
            page:Choice({
                module = Frames, key = entry.key, label = entry.label,
                choices = entry.choices or Frames.UnitAuras.CHOICES,
            })
        end
    end

    ---------------------------------------------------------------------------
    -- The cooldown manager: the tooltip IDs to find things by, which way the
    -- bars stack, then the list it tracks. Its size and place are with
    -- everything else's under Sizes and Positions.
    page:Section("Cooldown manager",
        "Bars for the spells and items you add by ID - hover anything to see its ID. A spell tracks its cooldown, or the duration of its buff while it is on you (any rank); once you have cast it out of combat and its buff was seen, a spell with both lets you pick. Items track their cooldown. The bars sit in line with the castbar, over the player frame.")
    page:Check({ module = Cooldowns, key = "showTooltipIDs", label = "IDs on tooltips" })
    page:Choice({
        module = Cooldowns, key = "growDirection", label = "Bars grow",
        choices = Cooldowns.GROW, segmentWidth = 84,
    })
    page:IdList({
        title = "Spell or item ID",
        empty = "Nothing tracked yet. Type an ID above - Add works out whether it is a spell or an item.",
        addLabel = "Add",
        add = Cooldowns.AddID,
        entries = function() return Cooldowns.db.tracked end,
        describe = function(entry)
            local name, icon = Cooldowns.Describe(entry)
            return name, icon, entry.kind .. " " .. entry.id
        end,
        -- What each row tracks: a choice when the spell has a cooldown and
        -- leaves a buff, otherwise the one thing it can.
        choices = Cooldowns.TRACK,
        getChoice = function(index)
            local entry = Cooldowns.db.tracked[index]
            return entry and Cooldowns.TrackOf(entry)
        end,
        setChoice = Cooldowns.SetTrack,
        hasChoice = Cooldowns.HasChoice,
        fixedChoice = function(entry)
            local track = Cooldowns.TrackOf(entry)
            if track == "buff" then return "Duration" end
            if track == "cooldown" then return "Cooldown" end
            return "Nothing to track"
        end,
        remove = Cooldowns.Remove,
    })

    ---------------------------------------------------------------------------
    -- The micro menu, then a switch per action bar under the names Edit Mode
    -- gives them, and how long each waits before it hides.
    local Bars = Menus.ActionBars
    page:Section("Auto-hide",
        "Each of these stays out of sight until the mouse is over it. Buttons and keybindings work as always, and the bars show while Edit Mode is open or something is on the cursor.")
    -- The micro menu is one more bar here, a small switch like theirs, first.
    page:Check({ module = Menus, key = "quietMicroMenu", label = "Micro Menu", compact = true })
    for _, entry in ipairs(Bars.LIST) do
        page:Check({ module = Menus, key = entry.key, label = entry.label, compact = true })
    end
    page:EndRow()
    page:Slider({
        module = Menus, key = "fadeOutDelay", label = "Hide after",
        description = "How long after the mouse leaves before it fades out.",
        min = Bars.MIN_DELAY, max = Bars.MAX_DELAY, step = 0.1, text = Options.Seconds,
    })

    ---------------------------------------------------------------------------
    page:Section("Extras",
        "The chat copy button sits above the chat menu button and opens the chat tab you are looking at in a window you can select and copy from. Hiding the Issue Reporter takes the beta's box and its \"Press F6\" lines off tooltips; F6 still works.")
    page:Check({ module = Chat, key = "showButton", label = "Chat copy button", compact = true })
    page:Check({ module = Menus, key = "hideIssueReporter", label = "Hide the Issue Reporter", compact = true })
    page:EndRow()

    ---------------------------------------------------------------------------
    -- Every size in one place: a row per element, and the text padding. The
    -- castbar group's bars each have their own - the castbar, the swing bars
    -- (as one group), the countdown and the combo points (the player,
    -- 2026-09-29: "all castbars managed individually").
    local FSR, Combo = UI.FiveSecondRule, UI.ComboPoints
    local function Own(module) return function() return module.db end end
    page:Section("Sizes",
        "Type a number and press Enter or Tab. The layer decides what a piece is drawn over. Each bar of the castbar group has its own size; the swing timers' is all three of theirs.")
    page:SizeRow({
        module = Frames, label = "Unit frames",
        boxes = {
            { key = "barWidth",      title = "Width" },
            { key = "barHeight",     title = "Health" },
            { key = "powerHeight",   title = "Power" },
            { key = "castbarHeight", title = "Cast" },
        },
    })
    -- The party's four frames, all the same size; a new height moves the ones
    -- below up or down with it, the column's top staying put.
    page:SizeRow({
        module = Frames, label = "Party frames", layerKey = "partyStrata",
        boxes = {
            { key = "partyWidth",  title = "Width" },
            { key = "partyHealth", title = "Health" },
            { key = "partyPower",  title = "Power" },
        },
    })
    page:SizeRow({
        module = Castbar, label = "Castbar",
        boxes = {
            -- A new width keeps the castbar centred where it was.
            { key = "barWidth",  title = "Width", onChange = Castbar.WidthChanged },
            { key = "barHeight", title = "Height" },
        },
    })
    -- A bar still in the group is centred over the castbar whatever its
    -- width; one placed on its own keeps its centre (KeepCentred). A size is
    -- not a place: the castbar stays the addon's to centre (keepsPlacement).
    page:SizeRow({
        module = Castbar, label = "Swing timers", layerKey = "swingStrata",
        boxes = {
            { key = "swingWidth",  title = "Width", keepsPlacement = true,
              onChange = Castbar.KeepCentred(Own(Castbar), "swingPlaced", "swingLeft") },
            { key = "swingHeight", title = "Height", keepsPlacement = true },
        },
    })
    page:SizeRow({
        module = FSR, label = "Five second rule",
        boxes = {
            { key = "barWidth",  title = "Width", onChange = Castbar.KeepCentred(Own(FSR), "placed", "barLeft") },
            { key = "barHeight", title = "Height" },
        },
    })
    page:SizeRow({
        module = Combo, label = "Combo points",
        boxes = {
            { key = "barWidth",  title = "Width", onChange = Castbar.KeepCentred(Own(Combo), "placed", "barLeft") },
            { key = "barHeight", title = "Height" },
        },
    })
    page:SizeRow({
        module = XP, label = "XP bar",
        boxes = {
            { key = "barWidth",  title = "Width", onChange = KeepCentred(XP) },
            { key = "barHeight", title = "Height" },
        },
    })
    page:SizeRow({
        module = Cooldowns, label = "Cooldowns",
        boxes = {
            -- A size is not a place: bars still in line with the castbar and
            -- the player frame stay there (keepsPlacement). The left edge is
            -- the anchor, so a new width grows rightward.
            { key = "barWidth",  title = "Width", keepsPlacement = true },
            { key = "barHeight", title = "Height", keepsPlacement = true },
        },
    })
    for _, entry in ipairs({
        { module = Frames,  label = "Unit frames text padding" },
        { module = Castbar, label = "Castbars text padding" },
    }) do
        page:Slider({
            module = entry.module, key = "textPadding", label = entry.label,
            description = "Room above and below the text; more padding, smaller text.",
            min = 0, max = UI.Style.MAX_TEXT_PADDING, step = 0.01, text = Options.Percent,
        })
    end

    ---------------------------------------------------------------------------
    -- Every position in one place: a row per piece that can be placed, its X
    -- from the left of the screen and its Y from the top (negative, going
    -- down), the same numbers dragging it on the grid writes. A typed position
    -- is the player's: a unit frame is marked placed, and a bar the addon was
    -- centring itself is left where it is put.
    page:Section("Positions",
        "X from the left edge of the screen, Y from the top (negative, going down) - the same numbers dragging with Unlock UI writes.")
    for _, unit in ipairs({
        { key = "player",       label = "Player" },
        { key = "target",       label = "Target" },
        { key = "focus",        label = "Focus" },
        { key = "targettarget", label = "Target of target" },
        { key = "pet",          label = "Pet" },
        { key = "party",        label = "Party" },      -- the column's top, party1's
    }) do
        local placed = unit.key .. "Placed"
        page:Row({
            module = Frames, label = unit.label,
            boxes = {
                { key = unit.key .. "Left", title = "X", placed = placed },
                { key = unit.key .. "Top",  title = "Y", placed = placed },
            },
        })
    end
    page:Row({
        module = Castbar, label = "Castbar",
        boxes = { { key = "barLeft", title = "X" }, { key = "barTop", title = "Y" } },
    })
    -- The swing bars grow upwards from their bottom edge, which is what is
    -- kept (from the bottom of the screen); the box says where that edge is
    -- from the top, like every other Y here. Typed, they are placed on their
    -- own - the castbar stays the addon's to centre (keepsPlacement).
    page:Row({
        module = Castbar, label = "Swing timers",
        boxes = {
            { key = "swingLeft", title = "X", placed = "swingPlaced", keepsPlacement = true },
            { key = "swingY", title = "Y (bottom)", placed = "swingPlaced", keepsPlacement = true,
              get = function(db) return db.swingBottom and db.swingBottom - GetScreenHeight() end,
              set = function(db, value) db.swingBottom = GetScreenHeight() + value end },
        },
    })
    page:Row({
        module = FSR, label = "Five second rule",
        boxes = {
            { key = "barLeft", title = "X", placed = "placed" },
            { key = "barTop",  title = "Y", placed = "placed" },
        },
    })
    page:Row({
        module = Combo, label = "Combo points",
        boxes = {
            { key = "barLeft", title = "X", placed = "placed" },
            { key = "barTop",  title = "Y", placed = "placed" },
        },
    })
    page:Row({
        module = XP, label = "XP bar",
        boxes = { { key = "barLeft", title = "X" }, { key = "barTop", title = "Y" } },
    })
    page:Row({
        module = Cooldowns, label = "Cooldowns",
        boxes = { { key = "barLeft", title = "X" }, { key = "barTop", title = "Y" } },
    })
    page:Row({
        module = UI.LootRolls, label = "Loot rolls",
        boxes = { { key = "barLeft", title = "X" }, { key = "barTop", title = "Y" } },
    })
    page:Row({
        module = Menus, label = "Micro menu",
        boxes = {
            { key = "microLeft", title = "X", placed = "microPlaced" },
            { key = "microTop",  title = "Y", placed = "microPlaced" },
        },
    })

    ---------------------------------------------------------------------------
    page:Section("Profiles",
        "Save every setting on this page under a name, for any of your characters to load. Loading one replaces this character's settings; the cooldown list stays each character's own.")
    page:Profiles()
end)
