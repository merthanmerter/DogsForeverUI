-- Action bars that auto-hide, and fade back in under the mouse. (The bag bar is
-- not one of them: it is gone until a bag is open - BagsBar.lua.)
--
-- Each of the game's bars is ticked on its own, in the Auto-hide bars options. A
-- opted-in bar is transparent until the mouse is over it, fades in while it is,
-- and fades out again once the mouse has been gone for the "Fade out after"
-- setting (3 seconds to start). It is only faded - the bar's
-- own alpha - so it stays where Edit Mode put it, its buttons still take clicks
-- and its keybindings still fire; you just see it only while you point at it.
--
-- Alpha is not a protected call, so this works in combat too, and no Edit Mode
-- setting touches a bar's alpha (there is no action bar opacity setting), so
-- nothing else is writing the value this module writes. No script is replaced,
-- no field is written onto a Blizzard frame, and nothing is shown, hidden or
-- moved, so the bars cannot be tainted from here.
--
-- Every opted-in bar also shows, whatever the mouse is doing:
--
--   * while Edit Mode is open - the game's, or the addon's (the UI
--     unlocked) - so the bars can be seen to be placed;
--   * while the spellbook is open, so there is somewhere to see to put a
--     spell from it;
--   * while something is on the cursor - a spell, a macro or an item being
--     dragged - so there is somewhere to see to drop it;
--   * while a spell flyout is open, so moving onto it does not fade its bar.
--
-- Whether the mouse is over a bar is asked of the bar itself (IsMouseOver is
-- geometry, so it answers the same whether the bar is visible or not), which
-- covers the gaps between buttons and whatever layout Edit Mode gives it.
--
-- Opted out again, a bar's alpha goes straight back to what it was.
--
-- Nothing is looked at while every bar rests faded out: see THE WATCHER.

local Bars = {}
DogsForeverUI.Menus.ActionBars = Bars

do -- private scope

    local NS = DogsForeverUI.Menus

    -- The bars, and the setting for each: the addon's own bars since
    -- 2026-10-03 (ActionBars\ActionBars.lua), the same settings as when they
    -- were the game's. A bar lists every name it has had; the first one this
    -- client has is the one used.
    -- (`bar`: its key in ActionBars\ActionBars.lua, whose buttons wake the
    -- fade - THE WATCHER, below.)
    Bars.LIST = {
        { key = "fadeActionBar1", label = "Action Bar 1", frames = { "DogsForeverUIActionBar1" }, bar = "bar1" },
        { key = "fadeActionBar2", label = "Action Bar 2", frames = { "DogsForeverUIActionBar2" }, bar = "bar2" },
        { key = "fadeActionBar3", label = "Action Bar 3", frames = { "DogsForeverUIActionBar3" }, bar = "bar3" },
        { key = "fadeActionBar4", label = "Action Bar 4", frames = { "DogsForeverUIActionBar4" }, bar = "bar4" },
        { key = "fadeActionBar5", label = "Action Bar 5", frames = { "DogsForeverUIActionBar5" }, bar = "bar5" },
        { key = "fadeActionBar6", label = "Action Bar 6", frames = { "DogsForeverUIActionBar6" }, bar = "bar6" },
        { key = "fadeActionBar7", label = "Action Bar 7", frames = { "DogsForeverUIActionBar7" }, bar = "bar7" },
        { key = "fadeActionBar8", label = "Action Bar 8", frames = { "DogsForeverUIActionBar8" }, bar = "bar8" },
        { key = "fadeStanceBar",  label = "Stance Bar",   frames = { "DogsForeverUIActionBarStanceBar" }, bar = "stance" },
        { key = "fadePetBar",     label = "Pet Bar",      frames = { "DogsForeverUIActionBarPetBar" }, bar = "pet" },
        -- The addon's own XP bar (XPBar\), the same way: off to start (the
        -- player asked, 2026-10-01). Only its alpha, as the game's bars;
        -- nothing of the XP bar's own code sets that.
        { key = "fadeXPBar",      label = "XP Bar",       frames = { "DogsForeverUIXPBar" } },
        -- The quest tracker (the player asked, 2026-10-01), on to start. Its
        -- frame runs far down the screen's right side in its default place
        -- (the game sizes it to the free room), so the mouse is tested
        -- against what is drawn - the addon's background box round the
        -- headers and quests (Objectives.lua) - not the frame. The game sets
        -- its alpha back to 1 when it brings the managed frames in again
        -- (ManagedFrameContainerMixin:AnimInManagedFrames), so `reassert`.
        -- Its quest text takes no mouse (only the titles and headers do), so
        -- nothing tells it the mouse came: it is looked at on a slow beat
        -- while it rests faded (`polled`, THE WATCHER).
        { key = "fadeObjectives", label = "Objectives",   frames = { "ObjectiveTrackerFrame" },
          reassert = true, polled = true,
          -- Kept shown while the quest log is open (the player, 2026-10-03:
          -- "when quest log is open, the objectives shouldn't be hidden"):
          -- on this client the world map's quest panel (QuestMapFrame).
          keep = function()
              local log = _G.QuestMapFrame
              return type(log) == "table" and type(log.IsVisible) == "function" and log:IsVisible() and true or false
          end,
          hover = function()
              local Objectives = DogsForeverUI.Objectives
              return Objectives and Objectives.HoverFrame and Objectives.HoverFrame()
          end },
        -- The bag bar was here too until 2026-09-29, when the player had it
        -- gone for good unless a bag is open (BagsBar.lua). Its saved switch,
        -- fadeBagBar, is no longer a default, so it is pruned.
    }

    -- Action Bars 3 to 8 auto-hide to start (the player asked, 2026-09-27),
    -- the quest tracker too (2026-10-01) and the stance bar (2026-10-03); 1,
    -- 2, the pet bar and the XP bar only once ticked. Added before the saved settings
    -- are read (ADDON_LOADED), so they are kept and not pruned.
    Bars.HIDDEN_TO_START = {
        fadeActionBar3 = true, fadeActionBar4 = true, fadeActionBar5 = true,
        fadeActionBar6 = true, fadeActionBar7 = true, fadeActionBar8 = true,
        fadeObjectives = true,
        fadeStanceBar = true,   -- (the player, 2026-10-03: "stance bar should be auto-hidden by default too")
    }
    for _, entry in ipairs(Bars.LIST) do
        NS.defaults[entry.key] = Bars.HIDDEN_TO_START[entry.key] == true
    end

    -- Saved settings from before a default hold that switch off, which the
    -- new default would never reach. So once - and only once, so a bar the
    -- player unticks afterwards stays unticked - each is switched on, in the
    -- step that brought it: a section already past a step is not touched by
    -- it again. `autoHideDefaults` records the last step done; a fresh or
    -- reset section starts at 0 with the defaults already in it, so doing the
    -- steps there changes nothing.
    NS.defaults.autoHideDefaults = 0
    local AUTO_HIDE_STEPS = {
        { "fadeActionBar3", "fadeActionBar4", "fadeActionBar5",
          "fadeActionBar6", "fadeActionBar7", "fadeActionBar8" },
        { "fadeObjectives" },
        { "fadeStanceBar" },
    }

    function Bars.Normalise(db)
        -- (A wait under the least, saved before there was one: the least.)
        if type(db.fadeOutDelay) == "number" and db.fadeOutDelay < Bars.MIN_DELAY then
            db.fadeOutDelay = Bars.MIN_DELAY
        end
        local done = tonumber(db.autoHideDefaults) or 0
        if done >= #AUTO_HIDE_STEPS then return end
        for step = done + 1, #AUTO_HIDE_STEPS do
            for _, key in ipairs(AUTO_HIDE_STEPS[step]) do db[key] = true end
        end
        db.autoHideDefaults = #AUTO_HIDE_STEPS
    end

    -- How long, in seconds, a bar stays after the mouse leaves it before it
    -- starts to fade. The fade itself, in and out, does not change. Set with a
    -- slider from 0 to 3 in tenths (the player asked for the same as Hold
    -- failed casts); a longer wait saved by the number box it replaced counts
    -- as 3. At least 0.1 (the player, 2026-10-03: "Hide After should be
    -- minimum 0.1s since 0.0 makes them not visible at all"): a 0 saved
    -- before counts as 0.1.
    NS.defaults.fadeOutDelay = 3
    Bars.MIN_DELAY, Bars.MAX_DELAY = 0.1, 3

    -- Also the micro menu's (MicroMenu.lua): it is under Auto-hide too.
    local function Delay()
        local delay = NS.db.fadeOutDelay
        if type(delay) ~= "number" then return 3 end
        return math.max(Bars.MIN_DELAY, math.min(delay, Bars.MAX_DELAY))
    end
    Bars.Delay = Delay

    -- The fade and the mouse test are the micro menu's too: NS.Fade and
    -- NS.MouseOver in Menus.lua.
    local faded = {}       -- [entry] = { before, alpha, away }: bars this module is fading

    local function Frame(entry)
        for _, name in ipairs(entry.frames) do
            local frame = _G[name]
            if type(frame) == "table" and type(frame.SetAlpha) == "function" then
                return frame
            end
        end
    end

    local function CursorHolding()
        if type(GetCursorInfo) ~= "function" then return false end
        local ok, kind = pcall(GetCursorInfo)
        return ok and kind ~= nil
    end

    local function Shown(frame)
        return type(frame) == "table" and type(frame.IsShown) == "function"
            and frame:IsShown() and true or false
    end

    local function FlyoutOpen()
        return Shown(_G.SpellFlyout)
    end

    -- The spellbook, which is where spells are dragged onto the bars from. On
    -- this client it is a tab of PlayerSpellsFrame, beside the talents
    -- (Blizzard_PlayerSpells/Camelot): open means that frame is up on that
    -- tab. (The stand-alone SpellBookFrame is classic-only: Blizzard_UIPanels_Game
    -- never loads it on this client.)
    local function SpellbookOpen()
        local spells = _G.PlayerSpellsFrame
        return Shown(spells) and Shown(spells.SpellBookFrame)
    end

    -- Whether every opted-in bar shows, whatever the mouse is doing.
    -- (The addon's own Edit Mode too: the UI unlocked shows them, so the
    -- XP bar can be seen to be placed.)
    -- (And while keys are being bound, Options\Keybinds.lua: every button
    -- there to point at.)
    local function EveryBar()
        local actionBars = DogsForeverUI.ActionBars
        return (NS.EditModeOpen() or SpellbookOpen() or CursorHolding()
            or FlyoutOpen() or DogsForeverUI.IsUnlocked() or (actionBars and actionBars.keybinding)) and true or false
    end

    ---------------------------------------------------------------------------
    -- THE WATCHER: awake only while a bar can be seen or is fading. Every
    -- opted-in bar faded right out, nothing is done until something says one
    -- may be wanted: the mouse coming onto a bar's button (their OnEnter,
    -- hooked after their own - EllesmereUI's way) or the XP bar, placing,
    -- keys being bound or a setting changed (Refresh), the spellbook or a
    -- spell flyout shown, the cursor picking something up, or the game
    -- bringing its managed frames back up. The quest tracker's text takes no
    -- mouse (`polled`): while it rests faded the watcher only dozes, looking
    -- ten times a second.
    ---------------------------------------------------------------------------

    local DOZE = 0.1
    local dozing, sinceDoze = false, 0

    -- One step of every bar towards where it should be. Alpha is written only
    -- while a bar is moving, so a bar at rest costs a comparison. (EveryBar
    -- asked once a step, and only when a bar is opted in.) Answers whether a
    -- bar can be seen, and whether a polled one is opted in.
    function Bars:Update(delta)
        delta = delta or 0
        local db = NS.db
        local everyBar, delay
        local awake, polled = false, false

        for _, entry in ipairs(Bars.LIST) do
            local frame = Frame(entry)
            local state = faded[entry]
            -- (Dozing for it even before the game has made its frame.)
            if entry.polled and db[entry.key] then polled = true end

            if frame and db[entry.key] then
                if everyBar == nil then everyBar, delay = EveryBar(), Delay() end
                if not state then
                    -- Starts where it is, and goes the way it would if the
                    -- mouse had just left it: a moment, then the fade.
                    local alpha = frame:GetAlpha()
                    state = { before = alpha, alpha = alpha, away = 0 }
                    faded[entry] = state
                end

                local hover = entry.hover and entry.hover() or frame
                local shown = everyBar or (entry.keep and entry.keep()) or NS.MouseOver(hover)
                NS.Fade(frame, state, shown, delta, delay)
                -- The game put it back up while it rests faded: down again.
                -- Only ever lower - a game hiding it (alpha 0) is left alone.
                if entry.reassert and frame:GetAlpha() > state.alpha + 0.01 then
                    frame:SetAlpha(state.alpha)
                end
                if shown or state.alpha > 0 then awake = true end
            elseif state then
                -- Opted out: handed back as it was.
                faded[entry] = nil
                if frame then frame:SetAlpha(state.before) end
            end
        end
        return awake, polled
    end

    local wake, watcher = DogsForeverUI.Waker(function(elapsed)
        if dozing then
            sinceDoze = sinceDoze + elapsed
            if sinceDoze < DOZE then return true end
            sinceDoze = 0
        end
        local awake, polled = Bars:Update(elapsed)
        dozing = not awake
        return awake or polled
    end)
    local function Wake()
        dozing = false
        wake()
    end

    local function HookShown(frame)
        if frame and frame.HookScript then frame:HookScript("OnShow", Wake) end
    end

    -- The spellbook loads only when first opened.
    local function HookSpellbook()
        local spells = _G.PlayerSpellsFrame
        HookShown(spells)
        HookShown(spells and spells.SpellBookFrame)
        return spells ~= nil
    end

    -- A setting, keys being bound: looked at now, awake.
    function Bars:Refresh()
        Wake()
        self:Update(0)
    end

    function Bars:Apply()
        local buttons = DogsForeverUI.ActionBars.buttons
        for _, entry in ipairs(Bars.LIST) do
            local frame = Frame(entry)
            if frame and frame.HookScript and not entry.polled then frame:HookScript("OnEnter", Wake) end
            for _, button in ipairs(buttons[entry.bar] or {}) do button:HookScript("OnEnter", Wake) end
        end
        HookShown(_G.SpellFlyout)
        for _, name in ipairs({ "RightManagedFrameContainer", "BottomManagedFrameContainer" }) do
            local container = _G[name]
            if container and container.AnimInManagedFrames then hooksecurefunc(container, "AnimInManagedFrames", Wake) end
        end
        DogsForeverUI.WatchPlacing(Wake)
        watcher:RegisterEvent("CURSOR_CHANGED")
        if not HookSpellbook() then watcher:RegisterEvent("ADDON_LOADED") end
        watcher:SetScript("OnEvent", function(_, event, name)
            if event ~= "ADDON_LOADED" then return Wake() end
            if name == "Blizzard_PlayerSpells" and HookSpellbook() then watcher:UnregisterEvent("ADDON_LOADED") end
        end)
        self:Refresh()
    end
end
