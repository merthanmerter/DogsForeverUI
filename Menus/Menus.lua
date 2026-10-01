-- MODULE: Menus  (DogsForeverUI.Menus, settings section "menus")
--
-- The game's menus and bars, made quieter:
--
--   * the micro menu (character, spellbook, quests, ...) in the action
--     buttons' look - square, the addon's border and background, the game's
--     icon centred - laid out in one row by the addon and placed with the rest
--     of the UI (MicroMenu.lua - the look, no setting), and invisible until the
--     mouse is over it;
--   * the bag bar is gone until a bag is open, and a bag button second in the
--     micro menu opens the bags instead (BagsBar.lua - the look, no setting);
--     the backpack's icon is repaired there too;
--   * any action bar ticked auto-hides, and fades back in under the mouse
--     (ActionBars.lua);
--   * every action button in the addon's look, the bars at 80% of the game's
--     size and the end caps gone (ActionButtons.lua - the look, no setting);
--   * the beta's Issue Reporter box and its tooltip hints hidden
--     (IssueReporter.lua).
--
-- All but the button looks and the bags can be switched off in the options,
-- which hands each straight back.
--
-- No script is replaced, no Lua field is written onto a Blizzard frame (but
-- Edit Mode's two opt-outs, DogsForeverUI.HoldEditMode, on the micro menu), no
-- layout method is called and no Edit Mode setting is touched, so nothing here
-- can taint the menus. (The one exception is the Issue Reporter's own
-- SetCurrentTooltipReport, wrapped to drop its tooltip hints - see that file;
-- the reporter is a beta tool, not part of the menus.) Art and bars are faded
-- (the micro buttons' art by vertex alpha), never hidden - except the bag bar, which is hidden and shown whole, the way
-- the game itself hides it for a gamepad (BagsBar.lua). `hooksecurefunc` and
-- `HookScript` are the only hooks, and both run after Blizzard's own code
-- rather than instead of it.

DogsForeverUI.Menus = {}

do -- private scope
    local NS = DogsForeverUI.Menus

    NS.key = "menus"
    NS.title = "Menus"

    NS.defaults = {
        unlocked = false,        -- the micro menu is placed with the rest of the UI
        quietMicroMenu = true,   -- the micro menu shows only under the mouse
        hideIssueReporter = true, -- the beta's Issue Reporter box and hints
        -- The group finder's icon, once read off its window (MicroMenu.lua):
        -- that window loads only when first opened. Not a setting, so a reset
        -- keeps it.
        groupFinderIcon = false,
    }
    NS.keep = { groupFinderIcon = true }
    -- ActionBars.lua adds one switch per bar that can auto-hide.

    -- The micro menu's place (MicroMenu.lua): its top left from the screen's,
    -- and whether the player put it there.
    NS.placement = { microLeft = true, microTop = true, microPlaced = true }

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

    -- Whether the mouse is over a faded frame, asked of the frame itself:
    -- IsMouseOver is geometry, so it answers the same whether the frame is
    -- visible or not. MARGIN outside still counts, so the edge does not
    -- flicker; a frame the game has hidden is never "under the mouse".
    local MARGIN = 4

    function NS.MouseOver(frame)
        if not frame:IsShown() then return false end
        local ok, over = pcall(frame.IsMouseOver, frame, MARGIN, -MARGIN, -MARGIN, MARGIN)
        return ok and over and true or false
    end

    -- Whether Edit Mode is open: the faded bars and the bag bar all show then,
    -- so they can be seen to be placed.
    function NS.EditModeOpen()
        local manager = _G.EditModeManagerFrame
        if type(manager) ~= "table" or type(manager.IsEditModeActive) ~= "function" then
            return false
        end
        local ok, active = pcall(manager.IsEditModeActive, manager)
        return ok and active and true or false
    end

    -- The menus are the game's, built before any addon runs; the hooks go on
    -- once, at login, when every one of them exists.
    local applied = false

    local function Refresh()
        if not applied then return end
        NS.MicroMenu.Place()
        NS.MicroMenu:Refresh()
        NS.ActionBars:Refresh()
        NS.IssueReporter:Refresh()
    end
    NS.Refresh = Refresh
    NS.Init = Refresh

    -- The micro menu is dragged with the rest of the UI (the one unlock).
    function NS.Unlock()
        NS.db.unlocked = true
        Refresh()
    end

    function NS.Lock()
        NS.db.unlocked = false
        NS.MicroMenu.holder:StopMovingOrSizing()
        Refresh()
    end

    -- Once the saved settings are in: see ActionBars.lua and MicroMenu.lua.
    function NS.Normalise(db)
        NS.ActionBars.Normalise(db)
        NS.MicroMenu.Normalise(db)
    end

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        applied = true
        NS.BagsBar:Apply()      -- first: its bag button is one of the menu's row,
        NS.OptionsButton:Apply() -- and so is the options button
        NS.MicroMenu:Apply()
        NS.ActionBars:Apply()
        NS.IssueReporter:Apply()
    end)

    DogsForeverUI:RegisterModule(NS)
end
