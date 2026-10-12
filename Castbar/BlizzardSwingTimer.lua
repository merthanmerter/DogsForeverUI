-- Taking the game's swing timer bars off screen: the addon's own are always
-- what shows.
--
-- NOT HIDDEN. FADED.
-- The castbar next door is simply hidden, and these cannot be. The game's swing
-- bars inherit BottomManagedFrameTemplate: ManagedFrameMixin:OnHide calls
-- RemoveManagedFrame, which lays out the whole bottom-managed container again -
-- the stack above the action bars. Hiding one from addon code would re-lay that
-- stack from a tainted call, which is exactly where blocked actions and taint
-- errors come from, and mid-fight is when the game shows and hides these.
--
-- So they are faded to nothing instead. Alpha is not protected, is allowed in
-- combat, does not touch the layout, and is undone by setting it back. The
-- frames carry on doing everything they did - they are simply not drawn.
--
-- WHY SetAlpha IS FOLLOWED
-- Fading once is not enough, because four separate pieces of the game write
-- these frames' alpha:
--
--   * Edit Mode's Opacity setting, in EditModeSwingTimerSystemMixin:
--     UpdateSystemSettingOpacity, every time Edit Mode applies its settings;
--   * the managed container, to hide them while the action bar is overridden
--     (UpdateFrameAlphaState);
--   * and its AnimOutManagedFrames / AnimInManagedFrames.
--
-- Chasing each of those would be four hooks that miss the fifth. Every one of
-- them ends in the frame's own SetAlpha, so that is what is followed, with
-- hooksecurefunc: it runs after the game's call has finished and cannot taint
-- it, and puts the alpha straight back to zero. The guard stops the hook
-- answering its own call.
--
-- EDIT MODE
-- The bars are Edit Mode systems. Faded, they could still be clicked and
-- dragged unseen, so their selection boxes are put away too
-- (DogsForeverUI.HoldEditMode: calls only, no field written onto the game's
-- frames). No Edit Mode setting is ever read or written.

local BlizzardSwingTimer = {}
DogsForeverUI.Castbar.BlizzardSwingTimer = BlizzardSwingTimer

do -- private scope

    local FRAMES = { "SwingTimerMainHandFrame", "SwingTimerOffHandFrame", "SwingTimerRangedFrame" }

    local hooked = {}
    local savedEditMode = {}
    local holding = false        -- true while this file is the one calling SetAlpha

    local function Resolve(name)
        local frame = _G[name]
        if type(frame) == "table" and type(frame.SetAlpha) == "function" then
            return frame
        end
    end

    local function Hold(frame)
        holding = true
        pcall(frame.SetAlpha, frame, 0)
        holding = false
    end

    local function Follow(name, frame)
        if hooked[name] or type(hooksecurefunc) ~= "function" then return end
        hooked[name] = true

        pcall(hooksecurefunc, frame, "SetAlpha", function(self)
            if not holding then Hold(self) end
        end)
    end

    function BlizzardSwingTimer.Refresh()
        for _, name in ipairs(FRAMES) do
            local frame = Resolve(name)
            if frame then
                Follow(name, frame)
                DogsForeverUI.HoldEditMode(savedEditMode, frame, true)
                Hold(frame)
            end
        end
    end
end
