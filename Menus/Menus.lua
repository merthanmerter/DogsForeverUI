-- MODULE: Menus  (DogsForeverUI.Menus, settings section "menus")
--
-- The game's menus and bars, made quieter:
--
--   * the micro menu (character, spellbook, quests, ...) loses its outer frame
--     and plate, keeps its buttons as the game draws them, and is invisible
--     until the mouse is over it;
--   * any action bar ticked - and the bag bar - auto-hides, and fades back in
--     under the mouse (ActionBars.lua); the backpack's icon is repaired
--     (BagsBar.lua);
--   * every action button in the addon's look, the bars at 80% of the game's
--     size and the end caps gone (ActionButtons.lua - the look, no setting);
--   * the beta's Issue Reporter box and its tooltip hints hidden
--     (IssueReporter.lua).
--
-- All but the action button look can be switched off in the options, which
-- hands each straight back.
--
-- No script is replaced, no Lua field is written onto a Blizzard frame, no
-- layout method is called and no Edit Mode setting is touched, so nothing here
-- can taint the menus. (The one exception is the Issue Reporter's own
-- SetCurrentTooltipReport, wrapped to drop its tooltip hints - see that file;
-- the reporter is a beta tool, not part of the menus.) Art and bars are faded,
-- never hidden. `hooksecurefunc` and `HookScript` are the only hooks, and both
-- run after Blizzard's own code rather than instead of it.

DogsForeverUI.Menus = {}

do -- private scope
    local NS = DogsForeverUI.Menus

    NS.key = "menus"
    NS.title = "Menus"

    NS.defaults = {
        quietMicroMenu = true,   -- the micro menu shows only under the mouse
        hideIssueReporter = true, -- the beta's Issue Reporter box and hints
    }
    -- ActionBars.lua adds one switch per bar that can auto-hide.

    -- THE FADE, the one the micro menu and the action bars share: a wait after
    -- the mouse leaves, then a fade out; a quicker fade back in while it is
    -- over. `state` is { alpha, away }; alpha is written only while it is
    -- moving. `hold` is the wait, in seconds: the action bars pass their own
    -- setting, the micro menu keeps HOLD.
    local FADE_IN = 0.2     -- seconds from gone to shown
    local FADE_OUT = 0.4    -- and from shown to gone
    local HOLD = 0.5        -- how long it stays once the mouse has left

    function NS.Fade(frame, state, over, delta, hold)
        delta = delta or 0
        hold = hold or HOLD
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

    -- The menus are the game's, built before any addon runs; the hooks go on
    -- once, at login, when every one of them exists.
    local applied = false

    local function Refresh()
        if not applied then return end
        NS.MicroMenu:Refresh()
        NS.ActionBars:Refresh()
        NS.IssueReporter:Refresh()
    end
    NS.Refresh = Refresh
    NS.Init = Refresh

    -- Once the saved settings are in: see ActionBars.lua.
    function NS.Normalise(db)
        NS.ActionBars.Normalise(db)
    end

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        applied = true
        NS.MicroMenu:Apply()
        NS.BagsBar:Apply()
        NS.ActionBars:Apply()
        NS.IssueReporter:Apply()
    end)

    DogsForeverUI:RegisterModule(NS)
end
