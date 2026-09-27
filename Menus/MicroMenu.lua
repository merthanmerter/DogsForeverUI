-- The micro menu, out of sight until the mouse is over it.
--
-- What changes (Blizzard_MicroMenu, Camelot\MainMenuBarMicroMenu.xml):
--
--   MicroMenu.BorderArt      the gold action-bar frame around the whole row - cleared
--   MicroMenu.BackgroundArt  the dark plate behind that frame                - cleared
--
-- Each button's own dark rounded backing (Background / PushedBackground) and
-- the portrait's rim are the game's, and stay: the icons read as buttons.
--
-- MOUSEOVER. The whole menu is transparent until the mouse is over it: it
-- fades in while the mouse is on it and fades out a moment after it leaves,
-- exactly as a faded action bar does (NS.Fade in Menus.lua). It is only faded -
-- the menu's own alpha, which Blizzard never sets (it sets its buttons', to 1
-- or 0.5, and the menu's still covers that) - so it stays where it is, keeps
-- its keybindings and its buttons still work; you just see them only while you
-- are pointing at them. Nothing in it is protected, so this works in combat too.
--
-- Whether the mouse is over it is asked of the menu itself (IsMouseOver, which
-- is geometry, so it answers the same whether the menu is visible or not)
-- every frame, rather than from each button's enter/leave: that way the gaps
-- between buttons, and buttons the game adds or moves later, need no thought.
--
-- Switched off in the options, the art and the menu's alpha go back to what
-- they were.

local Micro = {}
DogsForeverUI.Menus.MicroMenu = Micro

do -- private scope

    local NS = DogsForeverUI.Menus

    local MENU_ART = { "BorderArt", "BackgroundArt" }

    -- How far outside the menu still counts as over it, so the edge does not
    -- flicker.
    local MARGIN = 4

    local watcher
    local fade = nil       -- { alpha, away } while the menu is being faded
    local alphaBefore = {} -- the art's own alpha, to give back

    -- Written on a change only: this runs on the mouse timer.
    local function Fade(region, faded)
        if not region or not region.SetAlpha then return end
        if faded then
            if alphaBefore[region] == nil then
                alphaBefore[region] = region:GetAlpha()
                region:SetAlpha(0)
            end
        elseif alphaBefore[region] ~= nil then
            region:SetAlpha(alphaBefore[region])
            alphaBefore[region] = nil
        end
    end

    local function MouseOverMenu(menu)
        if not menu:IsShown() then return false end
        local ok, over = pcall(menu.IsMouseOver, menu, MARGIN, -MARGIN, -MARGIN, MARGIN)
        return ok and over and true or false
    end

    function Micro:Refresh(delta)
        local menu = _G.MicroMenu
        if not menu then return end

        local quiet = NS.db.quietMicroMenu

        -- The outer frame and plate only; the buttons keep their own
        -- backgrounds. These stay cleared if the game lends the menu to another
        -- parent (vehicles, pet battles): alpha travels with the region.
        for _, key in ipairs(MENU_ART) do Fade(menu[key], quiet) end

        if not quiet then
            -- Switched off: the whole menu, at once.
            if fade then
                fade = nil
                menu:SetAlpha(1)
            end
            return
        end

        -- Starts where it is, as if the mouse had just left it.
        if not fade then fade = { alpha = menu:GetAlpha(), away = 0 } end
        NS.Fade(menu, fade, MouseOverMenu(menu), delta)
    end

    function Micro:Apply()
        local menu = _G.MicroMenu
        if not menu then return end

        if not watcher then
            watcher = CreateFrame("Frame")
            watcher:SetScript("OnUpdate", function(_, delta) Micro:Refresh(delta) end)
        end

        self:Refresh()
    end
end
