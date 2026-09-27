-- Taking the game's player, target, focus and target-of-target frames off
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
--     the pet frame is a child of the frame rather than of either of them and
--     has to stay visible.
--   * The target and focus frames' artwork and main content - portrait, bars,
--     name, level - but **not** their *contextual* content, where their buffs
--     and debuffs live. Those are left alone deliberately and always: this
--     client will not let an addon read a unit's auras, so it cannot draw them
--     itself, and fading the only display of them that works would lose them.
--     Instead the target and focus frames are moved to sit on their plates,
--     which brings the auras they carry with them -- see PlaceAuraCarriers.
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
    -- CARRYING THE GAME'S AURAS TO THE PLATE
    --
    -- The target's buffs and debuffs are the game's to draw here - see the
    -- README - and they are drawn where the game's target frame is, which is
    -- nowhere near this addon's plate. They cannot be moved directly: the aura
    -- container is declared inside a
    --
    --     <ScopedModifier useForbiddenObjectTable="true">
    --
    -- in Blizzard_UnitFrame/Shared/TargetFrameAuraContainer.xml, which makes it
    -- a forbidden object. An addon may not anchor one, size one, or even read a
    -- field of one; it also carries a ForbiddenAspect barring untrusted layout
    -- script from running on it at all.
    --
    -- But TargetFrameMixin:AnchorAuraContainer anchors it to
    -- `self.TargetFrameContainer.FrameTexture` - the frame's own artwork. So
    -- the auras go where the *frame* goes, and the frame is an ordinary
    -- protected frame that this addon has already faded to nothing. Moving it
    -- moves the auras with it and shows nothing else, because there is nothing
    -- else left to see. The frame becomes an invisible carrier.
    --
    -- The artwork is far taller than the plate, so it is not simply laid over
    -- it: the auras would float well clear of the bars. Instead the frame is
    -- parked so the aura row itself lands against the plate, the same distance
    -- from its border whichever side the game stacks them on - above with
    -- "Buffs on top", below without - and its left edge on the plate's. That
    -- takes the game's own offsets from the artwork
    -- (TargetFrameMixin:AnchorAuraContainer), mirrored below, and which side it
    -- is on: `buffsOnTop`, a plain field the frame keeps, is only read. The
    -- plate's castbar moves to the other side (see UnitCastbar), so the two
    -- never meet.
    --
    -- Edit Mode's "Frame Size" would scale the carrier, and the auras with it,
    -- so the carrier is held at its own size: after the game scales it, it is
    -- put back to 1. The slider is still there - hiding it would mean replacing
    -- Edit Mode's own code - but it does nothing while this addon carries the
    -- frame, and the game's size is handed back when it stops.
    --
    -- Edit Mode wraps SetPoint, ClearAllPoints and SetScale on its frames with
    -- Lua that also snaps frames and flags the layout as changed. The plain
    -- widget methods it keeps as SetPointBase and the rest are what is called
    -- here, so none of that code runs from this addon.
    --
    -- Moving a protected frame is refused in combat, so it waits; the position
    -- sticks once set, and the original is kept so turning the addon off puts
    -- the frame back where the game had it.
    ---------------------------------------------------------------------------

    -- The two frames that carry auras, and the plate each one is parked on.
    local CARRIERS = {
        { root = "TargetFrame", plate = "target" },
        { root = "FocusFrame", plate = "focus" },
    }

    local carrierHome = {}     -- where the game had each one, before we moved it
    local carrierHooked = {}   -- whose re-anchoring we have already hooked

    local function RememberHome(name, frame)
        if carrierHome[name] ~= nil then return end
        local ok, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, 1)
        if ok and point then
            carrierHome[name] = { point, relativeTo, relativePoint, x, y }
        else
            carrierHome[name] = false    -- it had none; there is nothing to put back
        end
    end

    -- Where the game puts the aura container against the artwork, from
    -- Blizzard_UnitFrame/Mainline/TargetFrame.lua (locals there, so copied):
    -- AURA_START_X in from its left; with buffs on top the row's bottom sits
    -- AURA_MIRRORED_START_Y from the artwork's top (raised by the threat
    -- number's height while that shows), otherwise its top sits AURA_START_Y
    -- above the artwork's bottom.
    local AURA_START_X = 5
    local AURA_START_Y = 9
    local AURA_MIRRORED_START_Y = -6

    -- Daylight between the plate's border (or its name row) and the aura row,
    -- either side. It was 2; the player asked for 5 more.
    local AURA_GAP = 7

    local function ThreatNumberHeight(frame)
        local ok, height = pcall(function()
            local indicator = frame.threatNumericIndicator
            if indicator and indicator:IsShown() then return indicator:GetHeight() end
            return 0
        end)
        return ok and type(height) == "number" and height or 0
    end

    -- A widget method without Edit Mode's wrapper round it, where it has one.
    local function Plain(frame, method)
        return frame[method .. "Base"] or frame[method]
    end

    local parkedAs = {}        -- the layout each carrier was last parked for
    local gameScale = {}       -- the size the game last gave each carrier

    -- Put a carrier back to its own size after the game has scaled it,
    -- remembering the game's size to hand back later. A protected frame's
    -- call, so out of combat only; the end of combat catches it up.
    local function HoldScale(name, frame)
        if InCombatLockdown() then return end
        local ok, scale = pcall(frame.GetScale, frame)
        if not ok or type(scale) ~= "number" or scale == 1 then return end
        gameScale[name] = scale
        pcall(Plain(frame, "SetScale"), frame, 1)
    end

    local function ReleaseScale(name, frame)
        local scale = gameScale[name]
        if scale == nil or InCombatLockdown() then return end
        gameScale[name] = nil
        pcall(Plain(frame, "SetScale"), frame, scale)
    end

    local function ParkOnPlate(name, frame, plate)
        local texture = frame.TargetFrameContainer and frame.TargetFrameContainer.FrameTexture
        if type(texture) ~= "table" or type(texture.GetLeft) ~= "function" then return end

        -- Where the artwork sits inside its own frame. Measured rather than
        -- assumed, so the auras land on the plate whatever the frame's internal
        -- layout is, and asked for fresh each time because a frame that has
        -- never been laid out answers nil.
        local ok, left, top, bottom = pcall(function()
            return texture:GetLeft() - frame:GetLeft(),
                   frame:GetTop() - texture:GetTop(),
                   texture:GetBottom() - frame:GetBottom()
        end)
        if not ok or type(left) ~= "number" or type(top) ~= "number"
           or type(bottom) ~= "number" then
            return
        end

        local onTop = frame.buffsOnTop == true
        local threat = onTop and ThreatNumberHeight(frame) or 0
        -- Below the plate the auras clear its border; above it, its name and
        -- level row, which sits over the border.
        local clear = (onTop and DogsForeverUI.Frames.UnitPlate.TopRoom()
            or DogsForeverUI.Style.BORDER_INSET) + AURA_GAP
        local x = -left - AURA_START_X

        pcall(Plain(frame, "ClearAllPoints"), frame)
        if onTop then
            -- Row bottom = artwork top + MIRRORED_START_Y + threat; wanted
            -- `clear` above the plate's top edge.
            pcall(Plain(frame, "SetPoint"), frame, "TOPLEFT", plate, "TOPLEFT",
                x, clear - AURA_MIRRORED_START_Y - threat + top)
        else
            -- Row top = artwork bottom + START_Y; wanted `clear` under the
            -- plate's bottom edge.
            pcall(Plain(frame, "SetPoint"), frame, "BOTTOMLEFT", plate, "BOTTOMLEFT",
                x, -clear - AURA_START_Y - bottom)
        end
        parkedAs[name] = (onTop and "top" or "bottom") .. ":" .. threat
    end

    -- Whether the plate's auras are stacked under it, which is where its
    -- castbar would otherwise be: the castbar takes the other side.
    local PLATE_CARRIER = { target = "TargetFrame", focus = "FocusFrame" }

    function BlizzardFrames.AurasBelow(unit)
        local name = PLATE_CARRIER[unit]
        local frame = name and _G[name]
        if type(frame) ~= "table" or not BlizzardFrames.ShouldHide() then return false end
        return frame.buffsOnTop ~= true
    end

    -- Edit Mode must not be able to drag a carrier off its plate, and must not
    -- draw its big selection box over one either. Both are plain fields the game
    -- already keeps for exactly this, so neither is a function replaced nor an
    -- Edit Mode setting written:
    --
    --   * `isLocked` - EditModeSystemMixin:CanBeMoved() is
    --     `self.isSelected and not self.isLocked`, and OnDragStart does nothing
    --     when it is false. It is read there and nowhere else: an opt-out with
    --     no setter.
    --   * `defaultHideSelection` - OnEditModeEnter only highlights a system
    --     `if not self.defaultHideSelection`. The pet bar, the stance bar and
    --     the raid frame container all set it in their own XML.
    --
    -- Both are put back as they were when this addon is turned off
    -- (DogsForeverUI.HoldEditMode).
    local carrierEditMode = {}

    local PlaceAuraCarriers    -- forward: the hook below calls it back

    -- Edit Mode owns these frames' positions and re-applies them - on a layout
    -- change, on leaving Edit Mode, and whenever the player drags one. Left
    -- alone, that would walk the auras off the plate. `ApplySystemAnchor` is the
    -- one method every Edit Mode system goes through to position itself, so
    -- following it and parking the frame again afterwards is what makes the
    -- auras stay put.
    --
    -- `hooksecurefunc` runs after the original and cannot taint it, which is why
    -- the frame is followed rather than replaced. There is no recursion: parking
    -- is a SetPoint, and SetPoint does not anchor systems.
    local function HookCarrier(name, frame)
        if carrierHooked[name] or type(frame.ApplySystemAnchor) ~= "function" then
            return
        end
        carrierHooked[name] = true

        pcall(hooksecurefunc, frame, "ApplySystemAnchor", function()
            -- Reached through the table because ShouldHide is defined below
            -- this block; by the time Edit Mode can fire this, it exists.
            if BlizzardFrames.ShouldHide() then PlaceAuraCarriers(true) end
        end)

        -- The game re-anchors the aura row itself whenever its side can have
        -- changed - "Buffs on top" in Edit Mode, the threat number coming or
        -- going. The carrier is parked for one layout, so it is parked again
        -- when that layout is a different one; on every other call (this runs
        -- on aura updates too) nothing is touched.
        if type(frame.AnchorAuraContainer) == "function" then
            pcall(hooksecurefunc, frame, "AnchorAuraContainer", function()
                if not BlizzardFrames.ShouldHide() or InCombatLockdown() then return end
                local onTop = frame.buffsOnTop == true
                local layout = (onTop and "top" or "bottom") .. ":"
                    .. (onTop and ThreatNumberHeight(frame) or 0)
                if layout ~= parkedAs[name] then PlaceAuraCarriers(true) end
            end)
        end

        -- The two ways the game sizes these frames: Edit Mode's "Frame Size"
        -- (both) and the focus frame's small/large switch. After either, the
        -- carrier goes back to its own size and is parked again.
        for _, method in ipairs({ "UpdateSystemSettingFrameSize", "SetSmallSize" }) do
            if type(frame[method]) == "function" then
                pcall(hooksecurefunc, frame, method, function()
                    if BlizzardFrames.ShouldHide() then PlaceAuraCarriers(true) end
                end)
            end
        end
    end

    function PlaceAuraCarriers(hide)
        local plates = DogsForeverUI.Frames.plates

        for _, carrier in ipairs(CARRIERS) do
            local frame = _G[carrier.root]
            if type(frame) == "table" and type(frame.SetPoint) == "function" then
                HookCarrier(carrier.root, frame)
                -- Writing a field is not a protected call, so the two Edit Mode
                -- switches are set whatever else is going on.
                DogsForeverUI.HoldEditMode(carrierEditMode, frame, hide)
            end
        end

        -- Anchoring a protected frame, though, is refused while fighting. The
        -- core file asks again on PLAYER_REGEN_ENABLED.
        if InCombatLockdown() then return end

        for _, carrier in ipairs(CARRIERS) do
            local frame = _G[carrier.root]
            if type(frame) == "table" and type(frame.SetPoint) == "function" then
                RememberHome(carrier.root, frame)

                local home = carrierHome[carrier.root]
                local plate = plates and plates[carrier.plate]

                if hide and plate then
                    HoldScale(carrier.root, frame)
                    ParkOnPlate(carrier.root, frame, plate)
                    -- The castbar sits opposite the auras, and they may just
                    -- have changed sides.
                    if plate.castbar then plate.castbar:Refresh() end
                elseif not hide then
                    ReleaseScale(carrier.root, frame)
                    if type(home) == "table" then
                        pcall(Plain(frame, "ClearAllPoints"), frame)
                        pcall(Plain(frame, "SetPoint"), frame, home[1], home[2], home[3],
                            home[4], home[5])
                    end
                end
            end
        end
    end
    BlizzardFrames.PlaceAuraCarriers = PlaceAuraCarriers

    -- Whether the game's frames should be off screen right now. Asked afresh
    -- every time rather than remembered, so turning the addon off puts them
    -- back at once. There is no setting for it: this addon replaces them.
    local function ShouldHide()
        local db = DogsForeverUI.Frames.db
        return db and db.enabled and true or false
    end
    BlizzardFrames.ShouldHide = ShouldHide

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

        -- The target and focus frames are kept on top of their plates so the
        -- auras they carry land against them. Everything else on them is
        -- already invisible.
        PlaceAuraCarriers(hide)
    end
end
