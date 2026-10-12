-- What the options window shows, top to bottom. The controls are Widgets.lua's
-- and the layout Panel.lua's.
--
-- Everything the addon draws is always on (the player, 2026-09-29: "if the
-- addon is installed all its features should be enabled"): no Enabled
-- anywhere, and no switches for the castbar group, the XP bar, the level, the
-- incoming heals or the nameplates. What is left is what the player can
-- reasonably want either way (sizes, places and each piece's own settings are
-- in Unlock Mode since 2026-10-03):
--
--   Cooldown manager   its list
--   Auto-hide          the micro menu, the action bars and the XP bar
--   Extras             the chat copy button, the Issue Reporter, double-click
--                      fishing and camping
--   Profiles           all of it saved for other characters
--
-- Small switches whose names say what they do sit two to a row with no line
-- under them; a section's note says anything more. No unlock or reset in any
-- section: those are the two buttons in the window's header, for the whole UI.
--
-- There are no colour settings anywhere: the look is fixed (Core\Style.lua), so
-- every bar in the addon matches every other.

local Options = DogsForeverUI.Options

Options.Describe(function(page)
    local UI = DogsForeverUI
    local Menus, Chat, Cooldowns, Fishing = UI.Menus, UI.Chat, UI.Cooldowns, UI.Fishing

    -- (No Unit frames section since 2026-10-03: every frame's settings are
    -- in its menu in Unlock Mode - Options\Unlock.lua.)

    ---------------------------------------------------------------------------
    -- The cooldown manager: the tooltip IDs to find things by, which way the
    -- bars stack, then the list it tracks. Its size and place are set in
    -- Unlock Mode.
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
    page:Section("Extras", "Small helpers for chat, professions and tooltips.")
    page:Check({ module = Chat, key = "showButton", label = "Chat copy button",
        tooltip = "A button above the chat menu button opens the chat tab you are looking at in a window you can copy from." })
    page:Check({ module = Menus, key = "hideIssueReporter", label = "Hide the Issue Reporter",
        tooltip = "Takes the beta's box and its \"Press F6\" lines off tooltips. F6 still works." })
    page:Check({ module = Fishing, key = "fishing", label = "Double-click fishing",
        tooltip = "Double right-click in the world with a fishing pole in hand to cast Fishing." })
    page:Check({ module = Fishing, key = "camping", label = "Double-click camping",
        tooltip = "Double right-click a Basic Campfire to sit down." })
    page:Check({ module = UI.Skinning, key = "showSkinnable", label = "Skinnable on tooltips",
        tooltip = "Shows the skill a creature takes to skin, coloured like a recipe, once one like it has been confirmed skinnable." })
    page:Check({ module = UI.Skinning, key = "showCloth", label = "Cloth on tooltips",
        tooltip = "Names the cloth a creature drops, once you have seen it in the loot of one like it." })

    -- (No Sizes or Positions sections since 2026-10-03: every size and
    -- place is set in Unlock Mode, in each piece's menu.)

    ---------------------------------------------------------------------------
    page:Section("Profiles",
        "Save every setting on this page under a name, for any of your characters to load. Loading one replaces this character's settings; the cooldown list stays each character's own.")
    page:Profiles()
end)
