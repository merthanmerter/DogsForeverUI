-- Taking the game's player, target, focus, target-of-target and pet frames off
-- screen, and giving them back.
--
-- The game's unit frames are protected: showing or hiding one from addon code is
-- refused while the player is in combat, and the target frame is shown again on
-- every target change - including mid-fight. Hiding them would therefore mean a
-- stream of blocked actions exactly when it matters, so nothing here is hidden.
--
-- Their artwork is faded to nothing instead. Alpha is not protected, so it is
-- allowed in combat, it is undone instantly by setting it back, and the frames
-- themselves carry on knowing what they are doing - they simply are not drawn.
-- Their mouse is turned off as well, so an invisible frame does not swallow
-- clicks; that one *may* be protected, so it waits for the end of combat.
--
-- What is faded, and what is deliberately not:
--
--   * The player frame's two content frames, and not the frame itself, because
--     the totem icons live in a child of the frame (the frame the game lays
--     its pet and totems out in) and have to stay visible - see Totems.lua.
--   * The pet frame whole - it is drawn by the addon's pet plate now - with
--     its two parts that take the mouse on their own: its aura row, hidden
--     (a plain frame nothing of the game's shows again), and its happiness
--     face, which the plate carries a copy of, with its mouse off. The game
--     puts the pet frame's alpha back itself (the managed-frame container's
--     AnimInManagedFrames, after anything that hides the whole UI), so it is
--     taken down again the moment it does - see HookPetAlpha.
--   * The target and focus frames' artwork and main content - portrait, bars,
--     name, level - and the badges in their contextual content. Their buffs
--     and debuffs, also in there, are the addon's own now (UnitAuras.lua); the
--     game's rows are retired with the frame that holds them -- see
--     RetireCarriers.
--   * The two target-of-target frames whole: they are frames of their own,
--     children of the target and focus frames rather than of their content, and
--     nothing else lives inside them.
--
-- The game's own cast bars for the target and the focus are not faded at all -
-- they undo it themselves - but switched off through the field they keep for
-- exactly that. See SilenceCastbars.
--
-- No Edit Mode setting is read or written, no Blizzard function is replaced, and
-- nothing is reparented: any of those would taint the game's own frames.

local BlizzardFrames = {}
DogsForeverUI.Frames.BlizzardFrames = BlizzardFrames

do -- private scope

    -- Each entry is a frame to take the mouse off, and the paths inside it whose
    -- alpha is turned down. An empty path is the frame itself. Paths are walked
    -- rather than assumed: a client without one of them loses that part, not the
    -- addon.
    -- The badges in the target and focus frames' contextual content. That
    -- content stays (it holds the auras), so these are faded one by one: the
    -- plate draws its own level, elite and PvP badges in a row beside the bars
    -- instead - see UnitPlate's UpdateBadges.
    --
    -- Camelot draws its PvP badge into PvpBackgroundCircle/PvpBackgroundIcon
    -- (Blizzard_UnitFrame/Camelot/TargetFrame.lua, ShowPvPIcon); PvpIcon and
    -- the Prestige pair are the Mainline ones, faded too in case a build uses
    -- them. HighLevelTexture is the skull over the level, BossIcon the rare
    -- star.
    --
    -- LeaderIcon and GuideIcon are the game's crown and guide mark: the plate
    -- draws its own crown after the level, and the game's showed through on
    -- its own, up by the auras.
    local CONTEXTUAL_BADGES = {
        "PvpBackgroundCircle", "PvpBackgroundIcon",
        "PvpIcon", "PrestigePortrait", "PrestigeBadge",
        "HighLevelTexture", "BossIcon",
        "LeaderIcon", "GuideIcon",
    }

    local function TargetStyleParts()
        local parts = {
            { "TargetFrameContainer" },
            { "TargetFrameContent", "TargetFrameContentMain" },
        }
        for _, key in ipairs(CONTEXTUAL_BADGES) do
            parts[#parts + 1] = { "TargetFrameContent", "TargetFrameContentContextual", key }
        end
        return parts
    end

    local FRAMES = {
        {
            root = "PlayerFrame",
            parts = {
                { "PlayerFrameContainer" },
                { "PlayerFrameContent" },
            },
        },
        { root = "TargetFrame", parts = TargetStyleParts() },
        { root = "FocusFrame", parts = TargetStyleParts() },
        { root = "TargetFrameToT", parts = { {} } },
        { root = "FocusFrameToT", parts = { {} } },
        { root = "PetFrame", parts = { {} } },
    }

    -- The cast bars the game draws for the target and the focus, which this
    -- addon draws itself now.
    --
    -- Alpha is the wrong lever for these two and fading them did not work: a
    -- casting bar runs its own fade animations and calls ApplyAlpha(1.0) at the
    -- start of every cast, putting itself straight back. They have a switch of
    -- their own instead - `showCastbar`, which CastingBarMixin:ShouldShowCastBar
    -- reads every time it decides whether to appear, and which the game itself
    -- sets to false when its rules say a target cast bar is not wanted.
    --
    -- Writing that field is not a protected call, so it is safe in combat; the
    -- Hide beside it is, so that one waits.
    local CASTBARS = { "TargetFrameSpellBar", "FocusFrameSpellBar" }

    local function SilenceCastbars(silence)
        for _, name in ipairs(CASTBARS) do
            local bar = _G[name]
            if type(bar) == "table" then
                bar.showCastbar = not silence
                if silence and not InCombatLockdown() then pcall(bar.Hide, bar) end
            end
        end
    end

    -- The aura container is a managed widget the client owns, and on a build
    -- with the restricted aura API its parts can be forbidden objects: even
    -- looking at a field of one is an error, not a nil. So the walk itself is
    -- wrapped, and a frame this addon is not allowed to touch is simply not
    -- one of the frames it touches.
    local function ResolveUnsafe(rootName, path)
        local frame = _G[rootName]
        if type(frame) ~= "table" then return nil end

        for _, key in ipairs(path) do
            frame = frame[key]
            if type(frame) ~= "table" then return nil end
        end

        if type(frame.SetAlpha) ~= "function" then return nil end
        return frame
    end

    local function Resolve(rootName, path)
        local ok, frame = pcall(ResolveUnsafe, rootName, path)
        return ok and frame or nil
    end

    local function Fade(frame, hidden)
        pcall(frame.SetAlpha, frame, hidden and 0 or 1)
    end

    ---------------------------------------------------------------------------
    -- RETIRING THE GAME'S AURA ROWS
    --
    -- The target's and the focus's buffs and debuffs are drawn by the addon's
    -- own rows now (UnitAuras.lua), each with its Below / Above / Off setting.
    -- The game's rows are still there, in the target and focus frames'
    -- contextual content, and cannot be switched off directly: the aura
    -- container is declared inside a
    --
    --     <ScopedModifier useForbiddenObjectTable="true">
    --
    -- in Blizzard_UnitFrame/Shared/TargetFrameAuraContainer.xml, which makes it
    -- a forbidden object - an addon may not hide it, anchor it or even read a
    -- field of it.
    --
    -- So the frame that holds it is retired: faded to nothing and shrunk to a
    -- hundredth of its size. Faded alone, its auras would still take the mouse
    -- and pop tooltips up over empty screen; shrunk, they are a pixel wide.
    -- Alpha and scale are the frame's own - the container is not touched - and
    -- the game sets neither on these frames except through Edit Mode's "Frame
    -- Size" and the focus frame's small/large switch, both followed below.
    --
    -- Until 2026-09-27 the frames were parked on the plates instead, so the
    -- game's rows landed against them. But which side they went on was then
    -- Edit Mode's "Buffs on top" alone, and the frames are out of Edit Mode;
    -- writing the field it sets from an addon would taint the game's aura code.
    --
    -- Edit Mode wraps SetScale on its frames with Lua that also flags the
    -- layout as changed; the plain widget method it keeps as SetScaleBase is
    -- what is called here. Scale is a protected call on these frames, so it
    -- waits for the end of combat (the core file asks again then); alpha does
    -- not. Both are handed back when the addon's frames are switched off.
    ---------------------------------------------------------------------------

    local CARRIERS = { "TargetFrame", "FocusFrame" }
    local RETIRED_SCALE = 0.01

    local gameScale = {}       -- the size the game last gave each frame
    local carrierHooked = {}   -- whose resizing we have already hooked

    -- A widget method without Edit Mode's wrapper round it, where it has one.
    local function Plain(frame, method)
        return frame[method .. "Base"] or frame[method]
    end

    local function Retire(name, frame)
        pcall(frame.SetAlpha, frame, 0)
        if InCombatLockdown() then return end
        local ok, scale = pcall(frame.GetScale, frame)
        -- Anything clearly above the retired size is the game's own.
        if ok and type(scale) == "number" and scale > RETIRED_SCALE * 2 then
            gameScale[name] = scale
            pcall(Plain(frame, "SetScale"), frame, RETIRED_SCALE)
        end
    end

    local function Release(name, frame)
        pcall(frame.SetAlpha, frame, 1)
        local scale = gameScale[name]
        if scale == nil or InCombatLockdown() then return end
        gameScale[name] = nil
        pcall(Plain(frame, "SetScale"), frame, scale)
    end

    -- Whether the plate's auras are stacked under it, which is where its
    -- castbar would otherwise be: the castbar takes the other side.
    function BlizzardFrames.AurasBelow(unit)
        local auras = DogsForeverUI.Frames.UnitAuras
        return auras ~= nil and auras.Side(unit) == "below"
    end

    -- Edit Mode must not be able to drag these frames or draw its selection
    -- box where the plates are (DogsForeverUI.HoldEditMode: plain fields the
    -- game keeps for exactly this, put back when the addon is turned off).
    local carrierEditMode = {}
    local playerEditMode = {}

    -- The two ways the game sizes these frames: Edit Mode's "Frame Size" (both)
    -- and the focus frame's small/large switch. After either, the frame is
    -- shrunk again.
    local function HookCarrier(name, frame)
        if carrierHooked[name] then return end
        carrierHooked[name] = true
        for _, method in ipairs({ "UpdateSystemSettingFrameSize", "SetSmallSize" }) do
            if type(frame[method]) == "function" then
                pcall(hooksecurefunc, frame, method, function()
                    if BlizzardFrames.ShouldHide() then Retire(name, frame) end
                end)
            end
        end
    end

    local function RetireCarriers(hide)
        for _, name in ipairs(CARRIERS) do
            local frame = _G[name]
            if type(frame) == "table" and type(frame.SetAlpha) == "function" then
                HookCarrier(name, frame)
                -- Writing a field is not a protected call, so the two Edit Mode
                -- switches are set whatever else is going on.
                DogsForeverUI.HoldEditMode(carrierEditMode, frame, hide)
                if hide then Retire(name, frame) else Release(name, frame) end
            end
        end

        -- The castbars sit opposite the auras, which may just have changed
        -- sides.
        local plates = DogsForeverUI.Frames.plates
        if plates then
            for _, unit in ipairs({ "target", "focus" }) do
                local plate = plates[unit]
                if plate and plate.castbar then plate.castbar:Refresh() end
            end
        end
    end

    -- Whether the game's frames should be off screen right now. Asked afresh
    -- every time rather than remembered, so turning the addon off puts them
    -- back at once. There is no setting for it: this addon replaces them.
    local function ShouldHide()
        local db = DogsForeverUI.Frames.db
        return db and db.enabled and true or false
    end
    BlizzardFrames.ShouldHide = ShouldHide

    ---------------------------------------------------------------------------
    -- THE PET FRAME'S OWN PARTS. The frame is faded with the others (FRAMES);
    -- this is what fading alone does not cover.
    ---------------------------------------------------------------------------

    local petEditMode = {}
    local petAlphaHooked, refading = false, false

    -- The managed-frame container sets the alpha of every frame it lays out
    -- back to 1 whenever the whole UI comes back (ManagedFrameSystem.lua:
    -- AnimInManagedFrames), and the pet frame is one of them. A post-hook
    -- takes it straight down again; it changes nothing the game reads.
    local function HookPetAlpha(frame)
        if petAlphaHooked or type(frame.SetAlpha) ~= "function" then return end
        petAlphaHooked = true
        hooksecurefunc(frame, "SetAlpha", function(self, alpha)
            if refading or alpha == 0 or not ShouldHide() then return end
            refading = true
            pcall(self.SetAlpha, self, 0)
            refading = false
        end)
    end

    local function HoldPetParts(hide)
        local frame = _G.PetFrame
        if type(frame) ~= "table" then return end
        HookPetAlpha(frame)

        -- Out of Edit Mode as well: the pet plate is what shows, and it is
        -- placed with the rest of the UI.
        DogsForeverUI.HoldEditMode(petEditMode, frame, hide)

        -- Its aura buttons take the mouse, and pop tooltips up over empty
        -- screen when their frame is invisible. The row is a plain frame (the
        -- pet frame lays it out, and never shows or hides it), so it is simply
        -- hidden - allowed in combat.
        local auras = frame.AuraFrameContainer
        if type(auras) == "table" and type(auras.SetShown) == "function" then
            pcall(auras.SetShown, auras, not hide)
        end

        -- The happiness face shows and hides itself; only its mouse is ours.
        local happiness = _G.PetFrameHappiness
        if type(happiness) == "table" and type(happiness.EnableMouse) == "function" then
            pcall(happiness.EnableMouse, happiness, not hide)
        end
    end

    function BlizzardFrames.Refresh()
        local hide = ShouldHide()

        for _, entry in ipairs(FRAMES) do
            for _, path in ipairs(entry.parts) do
                local frame = Resolve(entry.root, path)
                if frame then Fade(frame, hide) end
            end

            -- The mouse, which may be a protected call on a protected frame.
            -- Combat is the one place that is refused, and the core file asks
            -- again the moment it ends.
            local root = _G[entry.root]
            if type(root) == "table" and type(root.EnableMouse) == "function"
               and not InCombatLockdown() then
                pcall(root.EnableMouse, root, not hide)
            end
        end

        SilenceCastbars(hide and DogsForeverUI.Frames.db.showCastbar and true or false)

        -- Gone from Edit Mode as well: no box to see or drag where the plate
        -- is. (The pet frame is an Edit Mode system of its own, held with its
        -- parts; target and focus are held below, with the auras they carry.)
        if type(PlayerFrame) == "table" then
            DogsForeverUI.HoldEditMode(playerEditMode, PlayerFrame, hide)
        end
        HoldPetParts(hide)

        -- The target and focus frames, retired whole with the game's aura rows
        -- they carry; the addon's own rows are drawn instead (UnitAuras.lua).
        RetireCarriers(hide)
    end
end
