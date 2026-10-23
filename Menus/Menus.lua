-- MODULE: Menus  (DogsForeverUI.Menus, settings section "menus")
-- The game's menus and bars, quieter: the micro menu in the action buttons'
-- look, the bag bar hidden until a bag is open, auto-hiding bars, and the
-- beta's Issue Reporter hidden. Hooks run after the
-- game's own code; no field is written onto a game frame.

DogsForeverUI.Menus = { ActionBars = {} }

do -- private scope
    local NS = DogsForeverUI.Menus
    local Bars = NS.ActionBars
    local Core = DogsForeverUI

    local FADE_IN = 0.2         -- seconds from gone to shown
    local FADE_OUT = 0.4        -- and from shown to gone
    local MARGIN = 4            -- round a faded frame, still "under the mouse"
    local DOZE = 0.1            -- a resting quest tracker is looked at ten times a second
    local REPORTER_ADDON = "Blizzard_PTRFeedback"

    NS.key = "menus"
    NS.title = "Menus"

    NS.defaults = {
        unlocked = false,
        quietMicroMenu = true,
        hideIssueReporter = true,
        groupFinderIcon = false, -- read off its window once loaded (MicroMenu.lua): no setting
        fadeOutDelay = 3,
        autoHideDefaults = 0,   -- the last of AUTO_HIDE_STEPS done
    }
    NS.keep = { groupFinderIcon = true }
    NS.placement = { microLeft = true, microTop = true, microPlaced = true }

    local applied = false       -- the game's menus are hooked once, at login

    -- The fade the micro menu and the auto-hidden bars share: `hold` seconds
    -- after the mouse leaves, then out. Alpha is written only while it moves.
    function NS.Fade(frame, state, over, delta, hold)
        if over then state.away = 0 else state.away = state.away + delta end
        local target = state.away < hold and 1 or 0
        if state.alpha == target then return end
        if target > state.alpha then
            state.alpha = math.min(target, state.alpha + delta / FADE_IN)
        else
            state.alpha = math.max(target, state.alpha - delta / FADE_OUT)
        end
        frame:SetAlpha(state.alpha)
    end

    -- Geometry, so it answers the same while faded out; never for a hidden frame.
    function NS.MouseOver(frame)
        if not frame:IsShown() then return false end
        -- (pcall: a frame anchored to a secret rect cannot answer.)
        local ok, over = pcall(frame.IsMouseOver, frame, MARGIN, -MARGIN, -MARGIN, MARGIN)
        return ok and over == true
    end

    ---------------------------------------------------------------------------
    -- Auto-hide: each bar ticked is faded out (its alpha only, so it keeps its
    -- clicks and keybindings, in combat too) and fades back in under the mouse,
    -- "Hide after" seconds after the mouse leaves. Every one shows while placing,
    -- binding keys, the spellbook or a spell flyout is open, or the cursor holds
    -- something. Unticked, a bar's alpha goes straight back.

    -- `bar`: its key in ActionBars\ActionBars.lua, whose buttons wake the fade.
    Bars.LIST = {}
    for i = 1, 8 do
        Bars.LIST[i] = { key = "fadeActionBar" .. i, label = "Action Bar " .. i,
                         frame = "DogsForeverUIActionBar" .. i, bar = "bar" .. i, on = i >= 3 }
    end
    table.insert(Bars.LIST, { key = "fadeStanceBar", label = "Stance Bar",
                              frame = "DogsForeverUIActionBarStanceBar", bar = "stance", on = true })
    table.insert(Bars.LIST, { key = "fadePetBar", label = "Pet Bar", frame = "DogsForeverUIActionBarPetBar", bar = "pet" })
    table.insert(Bars.LIST, { key = "fadeXPBar", label = "XP Bar", frame = "DogsForeverUIXPBar" })
    -- The quest tracker's frame runs far down the screen: the mouse is tested
    -- against the addon's box round its text. Its text takes no mouse, so it
    -- is `polled`; the game puts its alpha back when it brings it in again
    -- (`reassert`); and it stays while the quest log is open.
    table.insert(Bars.LIST, {
        key = "fadeObjectives", label = "Objectives", frame = "ObjectiveTrackerFrame", on = true,
        reassert = true, polled = true,
        keep = function()
            local log = _G.QuestMapFrame
            return log ~= nil and log:IsVisible()
        end,
        hover = function()
            local Objectives = Core.Objectives
            return Objectives and Objectives.HoverFrame and Objectives.HoverFrame()
        end,
    })
    for _, entry in ipairs(Bars.LIST) do NS.defaults[entry.key] = entry.on == true end

    -- Defaults that came later, switched on once in saved settings that predate them.
    local AUTO_HIDE_STEPS = {
        { "fadeActionBar3", "fadeActionBar4", "fadeActionBar5",
          "fadeActionBar6", "fadeActionBar7", "fadeActionBar8" },
        { "fadeObjectives" },
        { "fadeStanceBar" },
    }

    Bars.MIN_DELAY, Bars.MAX_DELAY = 0.1, 3

    function Bars.Normalise(db)
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

    -- "Hide after": the micro menu's too. A longer wait saved before counts as 3.
    function Bars.Delay()
        local delay = NS.db.fadeOutDelay
        if type(delay) ~= "number" then return Bars.MAX_DELAY end
        return math.max(Bars.MIN_DELAY, math.min(delay, Bars.MAX_DELAY))
    end

    local faded = {}            -- [entry] = { before, alpha, away }

    local function Shown(frame)
        return frame ~= nil and frame.IsShown ~= nil and frame:IsShown()
    end

    -- The spellbook is a tab of PlayerSpellsFrame on this client.
    local function SpellbookOpen()
        local spells = _G.PlayerSpellsFrame
        return Shown(spells) and Shown(spells.SpellBookFrame)
    end

    local function EveryBar()
        return Core.EditModeOpen() or Core.IsUnlocked() or Core.ActionBars.keybinding
            or SpellbookOpen() or GetCursorInfo() ~= nil or Shown(_G.SpellFlyout)
    end

    -- One step of every bar; alpha is written only while a bar moves.
    -- Answers whether one can be seen, and whether a polled one is ticked.
    function Bars:Update(delta)
        delta = delta or 0
        local db = NS.db
        local everyBar, delay
        local awake, polled = false, false

        for _, entry in ipairs(Bars.LIST) do
            local frame = _G[entry.frame]
            local state = faded[entry]
            if entry.polled and db[entry.key] then polled = true end

            if frame and db[entry.key] then
                if everyBar == nil then everyBar, delay = EveryBar() and true or false, Bars.Delay() end
                if not state then
                    local alpha = frame:GetAlpha()
                    state = { before = alpha, alpha = alpha, away = 0 }
                    faded[entry] = state
                end
                local shown = everyBar or (entry.keep and entry.keep())
                    or NS.MouseOver(entry.hover and entry.hover() or frame)
                NS.Fade(frame, state, shown, delta, delay)
                -- Put back up by the game while it rests faded: down again.
                -- Only ever lower - a game hiding it (alpha 0) is left alone.
                if entry.reassert and frame:GetAlpha() > state.alpha + 0.01 then
                    frame:SetAlpha(state.alpha)
                end
                if shown or state.alpha > 0 then awake = true end
            elseif state then
                faded[entry] = nil
                if frame then frame:SetAlpha(state.before) end
            end
        end
        return awake, polled
    end

    -- Awake only while a bar can be seen or is fading; else asleep until
    -- the mouse comes onto a bar's button, the cursor or placing changes, a
    -- setting changes, or the spellbook or a flyout shows. Only a polled
    -- quest tracker keeps it dozing.
    local dozing, sinceDoze = false, 0
    local wake, watcher = Core.Waker(function(elapsed)
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

    function Bars:Refresh()
        Wake()
        self:Update(0)
    end

    function Bars:Apply()
        local buttons = Core.ActionBars.buttons
        for _, entry in ipairs(Bars.LIST) do
            local frame = _G[entry.frame]
            if frame and not entry.polled then frame:HookScript("OnEnter", Wake) end
            for _, button in ipairs(buttons[entry.bar] or {}) do button:HookScript("OnEnter", Wake) end
        end
        HookShown(_G.SpellFlyout)
        for _, name in ipairs({ "RightManagedFrameContainer", "BottomManagedFrameContainer" }) do
            local container = _G[name]
            if container then hooksecurefunc(container, "AnimInManagedFrames", Wake) end
        end
        Core.WatchPlacing(Wake)
        watcher:RegisterEvent("CURSOR_CHANGED")
        if not HookSpellbook() then watcher:RegisterEvent("ADDON_LOADED") end
        watcher:SetScript("OnEvent", function(_, event, name)
            if event ~= "ADDON_LOADED" then return Wake() end
            if name == "Blizzard_PlayerSpells" and HookSpellbook() then watcher:UnregisterEvent("ADDON_LOADED") end
        end)
        self:Refresh()
    end

    ---------------------------------------------------------------------------
    -- The Issue Reporter's box, and the "Press F6" hints it adds to tooltips.

    local reporterHooked = false

    local function HideReporter() return NS.db.hideIssueReporter == true end

    local function RefreshReporter()
        local reporter = _G.PTR_IssueReporter
        if not (applied and reporter) then return end
        if not reporterHooked then
            reporterHooked = true
            -- A post-hook cannot take lines out of a tooltip: wrapped, the
            -- original still runs, so F6 still reports what is under the mouse.
            local original = reporter.SetCurrentTooltipReport
            reporter.SetCurrentTooltipReport = function(...)
                local registered = original(...)
                if HideReporter() then return false end
                return registered
            end
            hooksecurefunc(reporter, "Show", function(self)
                if HideReporter() then self:Hide() end
            end)
        end
        local hidden = HideReporter()
        if hidden == reporter:IsShown() then
            -- An open tooltip keeps the hint it was built with: closed.
            local current = reporter.CurrentTooltipSurvey
            local tooltip = type(current) == "table" and current.Frame
            if tooltip then tooltip:Hide() end
        end
        if hidden then reporter:Hide() else reporter:Show() end
    end

    ---------------------------------------------------------------------------
    -- The module.

    local function Refresh()
        if not applied then return end
        NS.MicroMenu.Place()
        NS.MicroMenu:Refresh()
        Bars:Refresh()
        RefreshReporter()
    end
    NS.Refresh = Refresh
    NS.Init = Refresh

    function NS.Unlock()
        NS.db.unlocked = true
        Refresh()
    end

    function NS.Lock()
        NS.db.unlocked = false
        NS.MicroMenu.holder:StopMovingOrSizing()
        Refresh()
    end

    function NS.Normalise(db)
        Bars.Normalise(db)
        NS.MicroMenu.Normalise(db)
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ADDON_LOADED")
    events:SetScript("OnEvent", function(_, event, name)
        if event == "PLAYER_LOGIN" then
            applied = true
            NS.BagsBar:Apply()      -- first: its bag button is in the micro menu's row
            NS.MicroMenu:Apply()
            Bars:Apply()
        elseif event == "ADDON_LOADED" then
            if name ~= REPORTER_ADDON then return end
            events:UnregisterEvent("ADDON_LOADED")
        end
        RefreshReporter()
    end)

    DogsForeverUI:RegisterModule(NS)
end
