-- Action bars that fade out, and fade back in under the mouse.
--
-- Each of the game's bars is opted in on its own, in the Menus options. An
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
--   * while a spell flyout is open, so moving onto it does not fade its bar.
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
    }

    -- Off, every one: a bar fades only once it is opted in. Added before the
    -- saved settings are read (ADDON_LOADED), so they are kept and not pruned.
    for _, entry in ipairs(Bars.LIST) do NS.defaults[entry.key] = false end

    -- How long, in seconds, a bar stays after the mouse leaves it before it
    -- starts to fade. The fade itself, in and out, does not change.
    NS.defaults.fadeOutDelay = 3
    Bars.MIN_DELAY, Bars.MAX_DELAY = 0, 60

    local function Delay()
        local delay = NS.db.fadeOutDelay
        if type(delay) ~= "number" or delay < Bars.MIN_DELAY then return 3 end
        return math.min(delay, Bars.MAX_DELAY)
    end

    -- How far outside a bar still counts as over it, so its edge does not
    -- flicker. The fade itself is the micro menu's too: NS.Fade in Menus.lua.
    local MARGIN = 4

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
    -- tab. A client with the older stand-alone SpellBookFrame is covered too.
    local function SpellbookOpen()
        local spells = _G.PlayerSpellsFrame
        if Shown(spells) then return Shown(spells.SpellBookFrame) end
        return Shown(_G.SpellBookFrame)
    end

    local function MouseOver(frame)
        if not frame:IsShown() then return false end
        local ok, over = pcall(frame.IsMouseOver, frame, MARGIN, -MARGIN, -MARGIN, MARGIN)
        return ok and over and true or false
    end

    -- One step of every bar towards where it should be. Alpha is written only
    -- while a bar is moving, so a bar at rest costs a comparison.
    function Bars:Update(delta)
        delta = delta or 0
        local db = NS.db
        local everyBar = EditModeOpen() or SpellbookOpen() or CursorHolding()
            or FlyoutOpen()
        local delay = Delay()

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

                NS.Fade(frame, state, everyBar or MouseOver(frame), delta, delay)
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
