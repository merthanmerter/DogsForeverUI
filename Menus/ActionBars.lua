-- Action bars - and the bag bar - that auto-hide, and fade back in under the
-- mouse.
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
--   * while Edit Mode is open, so the bars can be seen to be placed;
--   * while the spellbook is open, so there is somewhere to see to put a
--     spell from it;
--   * while something is on the cursor - a spell, a macro or an item being
--     dragged - so there is somewhere to see to drop it;
--   * while a spell flyout is open, so moving onto it does not fade its bar;
--   * the bag bar alone: while any bag is open.
--
-- Whether the mouse is over a bar is asked of the bar itself (IsMouseOver is
-- geometry, so it answers the same whether the bar is visible or not), which
-- covers the gaps between buttons and whatever layout Edit Mode gives it.
--
-- Opted out again, a bar's alpha goes straight back to what it was.

local Bars = {}
DogsForeverUI.Menus.ActionBars = Bars

do -- private scope

    local NS = DogsForeverUI.Menus

    -- The bars, in Edit Mode's order and under its names, and the setting for
    -- each. A bar lists every name it has had; the first one this client has
    -- is the one used.
    Bars.LIST = {
        { key = "fadeActionBar1", label = "Action Bar 1", frames = { "MainActionBar", "MainMenuBar" } },
        { key = "fadeActionBar2", label = "Action Bar 2", frames = { "MultiBarBottomLeft" } },
        { key = "fadeActionBar3", label = "Action Bar 3", frames = { "MultiBarBottomRight" } },
        { key = "fadeActionBar4", label = "Action Bar 4", frames = { "MultiBarRight" } },
        { key = "fadeActionBar5", label = "Action Bar 5", frames = { "MultiBarLeft" } },
        { key = "fadeActionBar6", label = "Action Bar 6", frames = { "MultiBar5" } },
        { key = "fadeActionBar7", label = "Action Bar 7", frames = { "MultiBar6" } },
        { key = "fadeActionBar8", label = "Action Bar 8", frames = { "MultiBar7" } },
        { key = "fadeStanceBar",  label = "Stance Bar",   frames = { "StanceBar" } },
        { key = "fadePetBar",     label = "Pet Bar",      frames = { "PetActionBar" } },
        -- The whole bag bar: the backpack, the bag slots and the keyring are
        -- all its children (Camelot\MainMenuBarBagButtons.xml). It replaced a
        -- "collapse" that hid the slots until a bag was open. It also shows
        -- while any bag is open (AnyBagOpen, below).
        { key = "fadeBagBar",     label = "Bag Bar",      frames = { "BagsBar" }, bags = true },
    }

    -- Action Bars 3 to 8 and the bag bar auto-hide to start (the player asked,
    -- 2026-09-27); 1, 2, the stance bar and the pet bar only once ticked. Added before the
    -- saved settings are read (ADDON_LOADED), so they are kept and not pruned.
    Bars.HIDDEN_TO_START = {
        fadeActionBar3 = true, fadeActionBar4 = true, fadeActionBar5 = true,
        fadeActionBar6 = true, fadeActionBar7 = true, fadeActionBar8 = true,
        fadeBagBar = true,
    }
    for _, entry in ipairs(Bars.LIST) do
        NS.defaults[entry.key] = Bars.HIDDEN_TO_START[entry.key] == true
    end

    -- Saved settings from before that default hold all of those off, which the
    -- new default would never reach. So once - and only once, so a bar the
    -- player unticks afterwards stays unticked - they are switched on.
    -- `autoHideDefaults` records that it happened; a fresh or reset section
    -- starts at 0 with the new defaults already in it, so doing it again there
    -- changes nothing.
    NS.defaults.autoHideDefaults = 0
    local AUTO_HIDE_DEFAULTS = 1

    function Bars.Normalise(db)
        if (tonumber(db.autoHideDefaults) or 0) >= AUTO_HIDE_DEFAULTS then return end
        for key in pairs(Bars.HIDDEN_TO_START) do db[key] = true end
        db.autoHideDefaults = AUTO_HIDE_DEFAULTS
    end

    -- How long, in seconds, a bar stays after the mouse leaves it before it
    -- starts to fade. The fade itself, in and out, does not change. Set with a
    -- slider from 0 to 3 in tenths (the player asked for the same as Hold
    -- failed casts); a longer wait saved by the number box it replaced counts
    -- as 3.
    NS.defaults.fadeOutDelay = 3
    Bars.MIN_DELAY, Bars.MAX_DELAY = 0, 3

    local function Delay()
        local delay = NS.db.fadeOutDelay
        if type(delay) ~= "number" or delay < Bars.MIN_DELAY then return 3 end
        return math.min(delay, Bars.MAX_DELAY)
    end

    -- The fade and the mouse test are the micro menu's too: NS.Fade and
    -- NS.MouseOver in Menus.lua.
    local faded = {}       -- [entry] = { before, alpha, away }: bars this module is fading
    local watcher

    local function Frame(entry)
        for _, name in ipairs(entry.frames) do
            local frame = _G[name]
            if type(frame) == "table" and type(frame.SetAlpha) == "function" then
                return frame
            end
        end
    end

    local function EditModeOpen()
        local manager = _G.EditModeManagerFrame
        if type(manager) ~= "table" or type(manager.IsEditModeActive) ~= "function" then
            return false
        end
        local ok, active = pcall(manager.IsEditModeActive, manager)
        return ok and active and true or false
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

    -- Any bag open - one bag, the backpack, the keyring or the combined
    -- window - the way the game counts it itself (ContainerFrame.lua).
    local function AnyBagOpen()
        if type(IsAnyBagOpen) ~= "function" then return false end
        local ok, open = pcall(IsAnyBagOpen)
        return ok and open and true or false
    end

    -- One step of every bar towards where it should be. Alpha is written only
    -- while a bar is moving, so a bar at rest costs a comparison.
    function Bars:Update(delta)
        delta = delta or 0
        local db = NS.db
        local everyBar = EditModeOpen() or SpellbookOpen() or CursorHolding()
            or FlyoutOpen()
        local delay = Delay()
        local bagOpen = AnyBagOpen()

        for _, entry in ipairs(Bars.LIST) do
            local frame = Frame(entry)
            local state = faded[entry]

            if frame and db[entry.key] then
                if not state then
                    -- Starts where it is, and goes the way it would if the
                    -- mouse had just left it: a moment, then the fade.
                    local alpha = frame:GetAlpha()
                    state = { before = alpha, alpha = alpha, away = 0 }
                    faded[entry] = state
                end

                local shown = everyBar or (entry.bags and bagOpen) or NS.MouseOver(frame)
                NS.Fade(frame, state, shown, delta, delay)
            elseif state then
                -- Opted out: handed back as it was.
                faded[entry] = nil
                if frame then frame:SetAlpha(state.before) end
            end
        end
    end

    function Bars:Refresh()
        self:Update(0)
    end

    function Bars:Apply()
        if not watcher then
            watcher = CreateFrame("Frame")
            watcher:SetScript("OnUpdate", function(_, delta) Bars:Update(delta) end)
        end
        self:Refresh()
    end
end
