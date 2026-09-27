-- Taking the game's casting bar off screen, and giving it back.
--
-- Two rules shape this file, both learned the hard way on this client.
--
-- Nothing an Edit Mode system owns is written to. The player's casting bar is
-- an Edit Mode frame, and writing Edit Mode's account settings from an addon
-- taints Blizzard's own frames. No setting is read or written here, no Blizzard
-- function is replaced, and nothing is reparented.
--
-- Hiding it is all that happens, and it is completely reversible. The frame's
-- events are left registered and its scripts are left alone, so the game's own
-- bar carries on knowing what it is doing -- it simply is not drawn. Turning
-- this addon off, or unticking the option, shows it again and the game is none
-- the wiser. A hidden frame gets no OnUpdate, so there is no cost to leaving it
-- registered.
--
-- One hook, placed once, does the holding: the game shows its bar again at the
-- start of every cast, so a single Hide() would last until the next one. The
-- hook asks each time whether the addon still wants the bar gone, which is what
-- makes the option take effect immediately in both directions.

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

    -- Whether the game's bar should be off screen right now. Asked afresh every
    -- time rather than remembered, so the option applies the moment it changes.
    --
    -- There is no setting for this any more: two casting bars on screen is not a
    -- configuration anybody wants. The addon being on is what hides the game's
    -- bar, and turning the addon off is what gives it back.
    local function ShouldHide()
        local db = DogsForeverUI.Castbar.db
        return db and db.enabled and true or false
    end

    function BlizzardCastbar.Refresh()
        local bar = Resolve()
        if not bar then return end

        if not hooked then
            hooked = true
            -- Hiding from within OnShow is the standard way to hold a frame
            -- down; the casting bar is not a protected frame, so this is safe in
            -- combat as well.
            pcall(bar.HookScript, bar, "OnShow", function(self)
                if ShouldHide() then pcall(self.Hide, self) end
            end)
        end

        if ShouldHide() then
            pcall(bar.Hide, bar)
        end
        -- Gone from Edit Mode too: Edit Mode shows the bar to be placed, and
        -- its own "Cast Bar" box highlights it directly.
        DogsForeverUI.HoldEditMode(savedEditMode, bar, ShouldHide())
        -- Nothing in the `else` branch: showing the bar is the game's decision,
        -- and it makes it at the start of the next cast. Forcing it visible here
        -- would put an empty casting bar on screen between casts.
    end
end
