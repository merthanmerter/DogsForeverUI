-- Taking the game's combo points off the target frame, and giving them back.
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
-- the game shows it while this module is on, it goes straight back down. With
-- the module off the hook does nothing, and the game shows its gems again at
-- the next change. No Blizzard function is replaced and no setting is written.

local BlizzardComboFrame = {}
DogsForeverUI.ComboPoints.BlizzardComboFrame = BlizzardComboFrame

do -- private scope

    local NS = DogsForeverUI.ComboPoints
    local hooked = false

    local function Resolve()
        local frame = _G.ComboFrame
        if type(frame) == "table" and type(frame.Hide) == "function"
           and type(frame.HookScript) == "function" then
            return frame
        end
    end

    local function ShouldHide()
        return NS.db ~= nil
    end

    function BlizzardComboFrame.Refresh()
        local frame = Resolve()
        if not frame then return end

        if not hooked then
            hooked = true
            pcall(frame.HookScript, frame, "OnShow", function(self)
                if ShouldHide() then pcall(self.Hide, self) end
            end)
        end

        -- Nothing in the `else` branch: showing it is the game's decision, and
        -- it makes it at the next change in points.
        if ShouldHide() then pcall(frame.Hide, frame) end
    end
end
