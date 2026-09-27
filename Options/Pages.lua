-- What each tab of the options shows, in tab order. The widgets and the tabs
-- are Panel.lua's.
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

-------------------------------------------------------------------------------
-- Frames
-------------------------------------------------------------------------------

Options.AddPage("frames", function(page)
    page:LeftHeading("Frames")
    page:Check({
        label = "Enabled",
        tooltip = "Draw the player, target, focus and target-of-target frames. Off, the game's own frames come straight back.",
        key = "enabled",
    })
    page:Check({
        label = "Class and reaction colours",
        tooltip = "Colour the health bar by the unit's class, or by how it feels about you. Untick it and every health bar is the plain green.",
        key = "classColors",
    })
    page:Check({
        label = "Show name",
        tooltip = "Show the unit's name above the frame.",
        key = "showName",
    })
    page:Check({
        label = "Show health",
        tooltip = "Show the health remaining and its share, on the health bar.",
        key = "showHealthText",
    })
    page:Check({
        label = "Show resource",
        tooltip = "Show the resource remaining and its share, on the lower bar.",
        key = "showPowerText",
    })
    page:Check({
        label = "Show level",
        tooltip = "Show the unit's level above the frame's left end.",
        key = "showLevel",
    })
    page:Check({
        label = "Show incoming heals",
        tooltip = "Shade the health bar out to where the heals already on their way will take it.",
        key = "showHealPrediction",
    })
    page:Check({
        label = "Show cast bars",
        tooltip = "Show a thin bar under the target and focus frames for what they are casting.",
        key = "showCastbar",
    })
    page:Check({
        label = "Style nameplates",
        tooltip = "Give the game's nameplates this look: the flat bar, the black background, the border, the level inside the bar and one text size. Friendly players' nameplates show their name only - the game keeps those inside dungeons from addons, so they could not be styled.",
        key = "styleNamePlates",
    })

    page:RightHeading("Size and position")
    page:Boxes({
        { key = "barWidth",    title = "Width" },
        { key = "barHeight",   title = "Health height" },
        { key = "powerHeight", title = "Power height" },
        { key = "castbarHeight", title = "Cast bar height" },
        { key = "playerLeft",  title = "Player X", placed = "playerPlaced" },
        { key = "playerTop",   title = "Player Y", placed = "playerPlaced" },
        { key = "targetLeft",  title = "Target X", placed = "targetPlaced" },
        { key = "targetTop",   title = "Target Y", placed = "targetPlaced" },
        { key = "focusLeft",   title = "Focus X", placed = "focusPlaced" },
        { key = "focusTop",    title = "Focus Y", placed = "focusPlaced" },
        { key = "targettargetLeft", title = "ToT X", placed = "targettargetPlaced" },
        { key = "targettargetTop",  title = "ToT Y", placed = "targettargetPlaced" },
    })
    page:Strata()

    page:TextPadding()
    page:Actions("Lock the frames")
    page:Note("Unlocking turns the frames' clicking off while you place them, so it waits until you are out of combat. Right-click a frame to lock them again.")
end)

-------------------------------------------------------------------------------
-- Castbar
-------------------------------------------------------------------------------

Options.AddPage("castbar", function(page)
    local fsr = DogsForeverUI.FiveSecondRule

    page:LeftHeading("Castbars")
    page:Check({
        label = "Enabled",
        tooltip = "Draw the castbar and the swing bars. Off, the game's own come straight back.",
        key = "enabled",
    })
    page:Check({
        label = "Show spell name",
        tooltip = "Show the name of the spell being cast, on the left of the bar.",
        key = "showText",
    })
    page:Check({
        label = "Show time left",
        tooltip = "Show the seconds remaining on every bar that counts down: the castbar, the swing bars, the five-second countdown, and the target's and focus's castbars.",
        key = "showTime",
    })
    page:Check({
        label = "Show spark",
        tooltip = "Show a glowing spark at the leading edge of every bar: the castbars, the swing bars, the five-second countdown, the unit frames' health and resource, and the XP bar.",
        key = "showSpark",
    })
    page:Check({
        label = "Enable swing timers",
        tooltip = "Draw the auto-attack swing bars above the castbar. Off, the game's own swing timer comes straight back.",
        key = "showSwing",
    })
    -- The countdown's and the combo points' one switch each: everything else
    -- about them - size, look, placing - is the castbar's.
    page:Check({
        label = "Enable five second rule",
        tooltip = "Count down the five-second rule after you spend mana, on a bar just above the castbar.",
        key = "enabled",
        module = fsr,
    })
    page:Check({
        label = "Enable combo points",
        tooltip = "For rogues, and druids in cat form: combo points as a bar of segments just above the castbar, where the five-second countdown goes for everyone else, and the game's taken off the target frame. Off, the game's come straight back.",
        key = "enabled",
        module = DogsForeverUI.ComboPoints,
    })

    page:RightHeading("Size and position")
    page:Boxes({
        -- A new width keeps the group centred where it was.
        { key = "barWidth",  title = "Width", onChange = DogsForeverUI.Castbar.WidthChanged },
        { key = "barHeight", title = "Height" },
        { key = "barLeft",   title = "X (from left)" },
        { key = "barTop",    title = "Y (from top)" },
    })
    page:Strata()

    page:TextPadding()
    -- How long a cast that failed stays on screen in its own colour. A cast that
    -- simply finished is not held at all - it is gone the moment it is done.
    page:Slider({
        key = "failedHold", label = "Hold failed casts",
        min = 0, max = 2, step = 0.1,
        lowText = "0s", highText = "2s", text = Options.Seconds,
    })
    page:Actions("Lock the bars", { "fsr", "combo" })
    page:Note("From the bottom up: the castbar, while something is casting; the five-second countdown after you spend mana, or a rogue's combo points, in the one row above it; and the swing bars at the top while you swing. They share the castbar's size and go wherever it goes. Unlock to place them - drag any but the castbar to put it somewhere of its own - and right-click one to lock them again.")
end)

-------------------------------------------------------------------------------
-- XP bar
-------------------------------------------------------------------------------

Options.AddPage("xp", function(page)
    page:LeftHeading("XP bar")
    page:Check({
        label = "Enabled",
        tooltip = "Draw the addon's own XP bar and fade the game's out. Off, the game's XP bar comes straight back.",
        key = "enabled",
    })
    page:Check({
        label = "Show rested XP",
        tooltip = "Shade in how far the rested bonus reaches beyond your XP.",
        key = "showRested",
    })

    page:RightHeading("Size and position")
    page:Boxes({
        { key = "barWidth",  title = "Width", onChange = KeepCentred(DogsForeverUI.XPBar) },
        { key = "barHeight", title = "Height" },
        { key = "barLeft",   title = "X (from left)" },
        { key = "barTop",    title = "Y (from top)" },
    })
    page:Strata()

    page:Actions("Lock the bar")
    page:Note("Any width and height, as small as you like. No text on it: hover it for the numbers. The bar is hidden at the level cap, as the game's is. Unlock it to drag it; right-click it to lock it again.")
end)

-------------------------------------------------------------------------------
-- Chat
-------------------------------------------------------------------------------

Options.AddPage("chat", function(page)
    page:LeftHeading("Chat")
    page:Intro("The button above the chat menu button opens the chat tab you are looking at in a window you can select and copy from. Drag across the text to copy it; the button or Esc closes the window. The game's own chat windows are never touched.")
    page:Check({
        label = "Show the chat button",
        tooltip = "Show the small icon above the chat menu button that opens the copy window. It is the only way to open it, so without it there is no copy window.",
        key = "showButton",
    })
end)

-------------------------------------------------------------------------------
-- Menus
-------------------------------------------------------------------------------

Options.AddPage("menus", function(page)
    page:LeftHeading("Menus")
    page:Check({
        label = "Quiet micro menu",
        tooltip = "Take the frame off the micro menu (character, spellbook, quests...) and hide it until the mouse is over it. Its buttons and keybindings work as always.",
        key = "quietMicroMenu",
    })
    page:Check({
        label = "Collapse the bag bar",
        tooltip = "Show only the backpack until a bag is open, then the whole bag bar as the game draws it.",
        key = "collapseBags",
    })

    -- Beside them: one box per action bar, under the names Edit Mode gives
    -- them, and how long a bar waits before it fades.
    local Bars = DogsForeverUI.Menus.ActionBars
    page:RightHeading("Fade action bars")
    for _, entry in ipairs(Bars.LIST) do
        page:Check({
            label = entry.label,
            tooltip = "Fade " .. entry.label .. " out, and back in while the mouse is over it. Its buttons and keybindings work as always, and it shows while Edit Mode is open or something is on the cursor.",
            key = entry.key,
            right = true,
        })
    end
    page:RightSpace(20)
    page:Boxes({
        { key = "fadeOutDelay", title = "Fade out after (s)",
          min = Bars.MIN_DELAY, max = Bars.MAX_DELAY, decimals = true },
    })
end)
