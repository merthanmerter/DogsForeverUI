-- What the options page shows, top to bottom. The widgets and the layout are
-- Panel.lua's.
--
-- One page, in sections by what a setting is about - each part of the UI, then
-- the settings every bar shares, then all the sizes together, then all the
-- positions together (the cooldown manager is a tab of its own, at the end
-- of this file) - with no unlock or reset in any section: those are the
-- two buttons at the top of the panel, for the whole UI at once. A position
-- can be typed in its box or set by dragging on the grid with the UI
-- unlocked; the box follows the drag.
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
    page:Section("Unit frames")
    page:Check({
        module = Frames, key = "enabled", label = "Enabled",
        tooltip = "Draw the player, target, focus, target-of-target and pet frames, with your totems in a row under the player frame. Off, the game's own frames and totems come straight back.",
    })
    page:Check({
        module = Frames, key = "classColors", label = "Class and reaction colours",
        tooltip = "Colour the health bar by the unit's class, or by how it feels about you. Untick it and every health bar is the plain green.",
    })
    page:Check({
        module = Frames, key = "showName", label = "Show name",
        tooltip = "Show the unit's name above the frame.",
    })
    page:Check({
        module = Frames, key = "showLevel", label = "Show level",
        tooltip = "Show the unit's level above the frame's left end.",
    })
    page:Check({
        module = Frames, key = "showHealthText", label = "Show health",
        tooltip = "Show the health remaining and its share, on the health bar.",
    })
    page:Check({
        module = Frames, key = "showPowerText", label = "Show resource",
        tooltip = "Show the resource remaining and its share, on the lower bar.",
    })
    page:Check({
        module = Frames, key = "showHealPrediction", label = "Show incoming heals",
        tooltip = "Shade the health bar out to where the heals already on their way will take it.",
    })
    page:Check({
        module = Frames, key = "showCastbar", label = "Show target and focus casts",
        tooltip = "Show a thin bar under the target and focus frames for what they are casting.",
    })
    page:Check({
        module = Frames, key = "styleNamePlates", label = "Style nameplates",
        tooltip = "Give the game's nameplates this look: the flat bar, the black background, the border, the level inside the bar and one text size. Friendly players' nameplates show their name only - the game keeps those inside dungeons from addons, so they could not be styled.",
    })
    -- Where each frame's buffs and debuffs go. They were Edit Mode's "Buffs on
    -- top" until the frames left Edit Mode; the rows are the addon's own now.
    page:EndRow()
    for _, entry in ipairs(Frames.UnitAuras.UNITS) do
        page:Choice({
            module = Frames, key = entry.key, label = entry.label,
            choices = Frames.UnitAuras.CHOICES,
            tooltip = "Where this frame's buffs and debuffs go: under it, over it (clear of the name), or nowhere. Its castbar takes the other side. Hover an aura for its tooltip.",
        })
    end

    ---------------------------------------------------------------------------
    -- The castbar and everything that stacks on it: the countdown and the
    -- combo points in the row above it, the swing bars over them. Each has a
    -- switch of its own - Castbar is the castbar alone - and everything else
    -- about them (size, layer, placing) is the castbar's.
    page:Section("Castbars")
    page:Check({
        module = Castbar, key = "enabled", label = "Castbar",
        tooltip = "Draw your castbar. Off, the game's own castbar comes straight back. Only the castbar: the swing timers, the five second rule and the combo points each have their own box.",
    })
    page:Check({
        module = Castbar, key = "showText", label = "Show spell name",
        tooltip = "Show the name of the spell being cast, on the left of the bar.",
    })
    page:Check({
        module = Castbar, key = "showSwing", label = "Swing timers",
        tooltip = "Draw the auto-attack swing bars above the castbar. Off, the game's own swing timer comes straight back.",
    })
    page:Check({
        module = UI.FiveSecondRule, key = "enabled", label = "Five second rule",
        tooltip = "Count down the five-second rule after you spend mana, on a bar just above the castbar.",
    })
    page:Check({
        module = UI.ComboPoints, key = "enabled", label = "Combo points",
        tooltip = "For rogues, and druids in cat form: combo points as a bar of segments just above the castbar, where the five-second countdown goes for everyone else, and the game's taken off the target frame. Off, the game's come straight back.",
    })
    page:EndRow()
    -- How long a cast that failed stays on screen in its own colour. A cast
    -- that simply finished is not held at all.
    page:Slider({
        module = Castbar, key = "failedHold", label = "Hold failed casts",
        min = 0, max = 2, step = 0.1,
        lowText = "0s", highText = "2s", text = Options.Seconds,
    })

    ---------------------------------------------------------------------------
    page:Section("XP bar")
    page:Check({
        module = XP, key = "enabled", label = "Enabled",
        tooltip = "Draw the addon's own XP bar and fade the game's out. No text on it: hover it for the numbers. Hidden at the level cap, as the game's is. Off, the game's XP bar comes straight back.",
    })
    page:Check({
        module = XP, key = "showRested", label = "Show rested XP",
        tooltip = "Shade in how far the rested bonus reaches beyond your XP.",
    })

    ---------------------------------------------------------------------------
    page:Section("Menus and chat")
    page:Check({
        module = Menus, key = "quietMicroMenu", label = "Quiet micro menu",
        tooltip = "Take the frame off the micro menu (character, spellbook, quests...) and hide it until the mouse is over it. Its buttons and keybindings work as always.",
    })
    page:Check({
        module = Menus, key = "hideIssueReporter", label = "Hide the Issue Reporter",
        tooltip = "Hide the beta's Issue Reporter box and the \"Press F6 to submit an issue\" lines it adds to tooltips. F6 still reports whatever is under the mouse, and pop-up surveys still appear.",
    })
    page:Check({
        module = Chat, key = "showButton", label = "Chat copy button",
        tooltip = "Show the small icon above the chat menu button. It opens the chat tab you are looking at in a window you can select and copy from - drag across the text to copy it; the icon or Esc closes it. It is the only way to open that window. The game's own chat windows are never touched.",
    })

    ---------------------------------------------------------------------------
    -- One box per action bar, under the names Edit Mode gives them, and how
    -- long a bar waits before it hides.
    local Bars = Menus.ActionBars
    page:Section("Auto-hide bars")
    for _, entry in ipairs(Bars.LIST) do
        page:Check({
            module = Menus, key = entry.key, label = entry.label,
            tooltip = "Hide " .. entry.label .. " until the mouse is over it. Its buttons and keybindings work as always, and it shows while Edit Mode is open or something is on the cursor.",
        })
    end
    page:EndRow()
    page:Slider({
        module = Menus, key = "fadeOutDelay", label = "Hide after",
        min = Bars.MIN_DELAY, max = Bars.MAX_DELAY, step = 0.1,
        lowText = "0s", highText = "3s", text = Options.Seconds,
    })

    ---------------------------------------------------------------------------
    -- Every size in one place: a row per element, and the text padding. The
    -- castbar's size is the whole group's - the countdown, the combo points
    -- and the swing bars take it.
    page:Section("Sizes")
    page:SizeRow({
        module = Frames, label = "Unit frames",
        boxes = {
            { key = "barWidth",      title = "Width" },
            { key = "barHeight",     title = "Health height" },
            { key = "powerHeight",   title = "Power height" },
            { key = "castbarHeight", title = "Cast height" },
        },
    })
    page:SizeRow({
        module = Castbar, label = "Castbars",
        boxes = {
            -- A new width keeps the group centred where it was.
            { key = "barWidth",  title = "Width", onChange = Castbar.WidthChanged },
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
    local padding = {
        min = 0, max = UI.Style.MAX_TEXT_PADDING, step = 0.01,
        lowText = "0%", highText = "40%", text = Options.Percent,
    }
    for _, entry in ipairs({
        { module = Frames,  label = "Unit frames text padding" },
        { module = Castbar, label = "Castbars text padding" },
    }) do
        local spec = { module = entry.module, key = "textPadding", label = entry.label }
        for name, value in pairs(padding) do spec[name] = value end
        page:Slider(spec)
    end

    ---------------------------------------------------------------------------
    -- Every position in one place: a row per piece that can be placed, its X
    -- from the left of the screen and its Y from the top (negative, going
    -- down), the same numbers dragging it on the grid writes. A typed position
    -- is the player's: a unit frame is marked placed, and a bar the addon was
    -- centring itself is left where it is put.
    page:Section("Positions")
    for _, unit in ipairs({
        { key = "player",       label = "Player" },
        { key = "target",       label = "Target" },
        { key = "focus",        label = "Focus" },
        { key = "targettarget", label = "Target of target" },
        { key = "pet",          label = "Pet" },
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
        module = Castbar, label = "Castbars",
        boxes = { { key = "barLeft", title = "X" }, { key = "barTop", title = "Y" } },
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
end)

-------------------------------------------------------------------------------
-- THE COOLDOWN MANAGER, a tab of its own under the addon in Settings > AddOns.
-- Its size and place are with everything else's on the main page (Sizes,
-- Positions), and the unlock that moves it is the main page's one.
-------------------------------------------------------------------------------
Options.DescribeTab("Cooldowns", "Cooldown manager",
    "Bars for the spells and items you add by ID - hover anything to see its ID. A spell tracks its Cooldown (a bar while it cools down) or its Duration (a bar while its buff is on you, any rank). Whether a spell leaves a buff is learned from casting it: once you have cast it out of combat and its buff was on you, a spell with a cooldown lets you pick Cooldown, Duration or Both. Items track their cooldown. The bars sit in line with the castbar over the player frame; their size and place are on the main page, under Sizes and Positions, and Unlock UI there moves them.",
    function(page)
        local Cooldowns = DogsForeverUI.Cooldowns
        page:Check({
            module = Cooldowns, key = "enabled", label = "Enabled",
            tooltip = "Show a bar for each spell and item in the list below while it is on cooldown: its icon, its name and the time left.",
        })
        page:Check({
            module = Cooldowns, key = "showTooltipIDs", label = "Show IDs on tooltips",
            tooltip = "Add the spell or item ID, small and grey, at the bottom of the tooltip of anything you hover - spells, items, buffs and debuffs, pet and stance buttons, macros, toys and mounts - so it can be typed in below.",
        })
        page:Choice({
            module = Cooldowns, key = "growDirection", label = "Bars grow",
            choices = Cooldowns.GROW,
            tooltip = "Which way more cooldown bars stack from the first one. The first bar sits in line with the castbar either way.",
        })
        page:IdList({
            title = "Spell or item ID",
            empty = "Nothing tracked yet.",
            buttons = { { kind = "spell", label = "Add spell" }, { kind = "item", label = "Add item" } },
            add = Cooldowns.Add,
            entries = function() return Cooldowns.db.tracked end,
            describe = function(entry)
                local name, icon = Cooldowns.Describe(entry)
                return name, icon, entry.kind .. " " .. entry.id
            end,
            -- What each row tracks: a choice when the spell has a cooldown and
            -- can have a buff, otherwise the one thing it can.
            column = "Tracks",
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
                return "|cff999999Nothing|r"
            end,
            remove = Cooldowns.Remove,
        })
    end)
