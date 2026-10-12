-- Taking the game's casting bar off screen: the addon's own is always what
-- shows.
--
-- Nothing an Edit Mode system owns is written to. The player's casting bar is
-- an Edit Mode frame, and writing Edit Mode's account settings from an addon
-- taints Blizzard's own frames. No setting is read or written here, no Blizzard
-- function is replaced, and nothing is reparented.
--
-- Hiding it is all that happens. The frame's events are left registered and
-- its scripts are left alone, so the game's own bar carries on knowing what it
-- is doing -- it simply is not drawn. A hidden frame gets no OnUpdate, so
-- there is no cost to leaving it registered.
--
-- One hook, placed once, does the holding: the game shows its bar again at the
-- start of every cast, so a single Hide() would last until the next one.

local BlizzardCastbar = {}
DogsForeverUI.Castbar.BlizzardCastbar = BlizzardCastbar

do -- private scope

    local hooked = false
    local savedEditMode = {}

    -- The player's casting bar: PlayerCastingBarFrame on this client (the
    -- family's Blizzard_UIPanels_Game CastingBarFrame.xml; the old classic
    -- CastingBarFrame does not exist here). A stray global of the same name
    -- would otherwise take the addon down on the first call, so this checks it
    -- really is a frame before believing it.
    local function Resolve()
        local frame = _G.PlayerCastingBarFrame
        if type(frame) == "table" and type(frame.Hide) == "function"
           and type(frame.HookScript) == "function" then
            return frame
        end
    end

    function BlizzardCastbar.Refresh()
        local bar = Resolve()
        if not bar then return end

        if not hooked then
            hooked = true
            -- Hiding from within OnShow is the standard way to hold a frame
            -- down; the casting bar is not a protected frame, so this is safe in
            -- combat as well.
            pcall(bar.HookScript, bar, "OnShow", function(self) pcall(self.Hide, self) end)
        end

        pcall(bar.Hide, bar)
        -- Gone from Edit Mode too: Edit Mode shows the bar to be placed, and
        -- its own "Cast Bar" box highlights it directly.
        DogsForeverUI.HoldEditMode(savedEditMode, bar, true)
    end
end
