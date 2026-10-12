-- Taking the game's combo points off the target frame: the addon's own bar is
-- always what shows.
--
-- The game draws them in ComboFrame, a plain frame on UIParent pinned to the
-- target frame's top-right corner (Blizzard_UnitFrame/Camelot/
-- ComboFrameOverrides.lua). It is not the target frame's child, so fading the
-- target frame away (the Frames module) leaves the gems showing. ComboFrame is not a
-- protected frame and nothing is laid out around it, so it is simply hidden,
-- in or out of combat.
--
-- The game shows it again every time the points change, so one Hide would
-- last until the next point. Its OnShow is followed instead, once: whenever
-- the game shows it, it goes straight back down. No Blizzard function is
-- replaced and no setting is written.

local BlizzardComboFrame = {}
DogsForeverUI.ComboPoints.BlizzardComboFrame = BlizzardComboFrame

do -- private scope

    local hooked = false

    local function Resolve()
        local frame = _G.ComboFrame
        if type(frame) == "table" and type(frame.Hide) == "function"
           and type(frame.HookScript) == "function" then
            return frame
        end
    end

    function BlizzardComboFrame.Refresh()
        local frame = Resolve()
        if not frame then return end

        if not hooked then
            hooked = true
            pcall(frame.HookScript, frame, "OnShow", function(self) pcall(self.Hide, self) end)
        end

        pcall(frame.Hide, frame)
    end
end
