-- Taking the game's swing timer bars off screen, and giving them back.
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
-- it, and while the addon wants the bars gone it puts the alpha straight back
-- to zero. The guard stops the hook answering its own call.
--
-- EDIT MODE
-- The bars are Edit Mode systems. Faded, their selection box is invisible too,
-- but they could still be clicked and dragged unseen, so the two opt-outs the
-- game keeps for this are set: `isLocked`, which EditModeSystemMixin:CanBeMoved
-- reads and nothing else does, and `defaultHideSelection`, which stops Edit
-- Mode highlighting them. Both are put back as they were when the addon is
-- turned off, and no Edit Mode setting is ever read or written.

local BlizzardSwingTimer = {}
DogsForeverUI.Castbar.BlizzardSwingTimer = BlizzardSwingTimer

do -- private scope

    local FRAMES = { "SwingTimerMainHandFrame", "SwingTimerOffHandFrame", "SwingTimerRangedFrame" }

    local hooked = {}
    local savedEditMode = {}
    local holding = false        -- true while this file is the one calling SetAlpha

    -- The game's swing bars are this addon's to replace only while its own are
    -- on: the castbar enabled, and the swing timers with it.
    local function ShouldHide()
        local db = DogsForeverUI.Castbar.db
        return db and db.enabled and db.showSwing and true or false
    end

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
            if not holding and ShouldHide() then Hold(self) end
        end)
    end

    -- Given back at the opacity Edit Mode says, by the frame's own method. A
    -- frame that cannot answer - not initialised yet, or from a client without
    -- the method - gets full opacity rather than staying invisible.
    local function Restore(frame)
        if type(frame.UpdateSystemSettingOpacity) == "function"
           and pcall(frame.UpdateSystemSettingOpacity, frame) then
            return
        end
        pcall(frame.SetAlpha, frame, 1)
    end

    function BlizzardSwingTimer.Refresh()
        local hide = ShouldHide()

        for _, name in ipairs(FRAMES) do
            local frame = Resolve(name)
            if frame then
                Follow(name, frame)
                DogsForeverUI.HoldEditMode(savedEditMode, frame, hide)
                if hide then Hold(frame) else Restore(frame) end
            end
        end
    end
end
