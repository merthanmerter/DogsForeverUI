-- The game's raid-style frames - the raid frames, and the party's raid-style
-- ones, which are retired out of sight (BlizzardFrames.lua) - drawn with this
-- addon's textures, and
-- nothing else of them changed: their size, layout, colours, text, icons,
-- auras and behaviour all stay the game's.
--
--   * the health and resource fills: the flat fill with its sheen and shade,
--     as on every bar of the addon's, in whatever colour the game gives them
--     (class colours and so on);
--   * the backgrounds behind them: the frames' own dark background.
--
-- The game makes these frames as it needs them and sets each one up through
-- CompactUnitFrame_SetUpFrame, again whenever its settings change; a post-hook
-- (hooksecurefunc - nothing replaced) gives a frame the textures right after,
-- and the frames already made are gone over at login. Only frames named for
-- the party or the raid (CompactParty..., CompactRaid...) are touched: the
-- same setup also builds other compact frames (the arena's), which keep the
-- game's look.
--
-- Textures only: the fill is swapped on the very texture object the game
-- draws (the way the nameplates are styled - NamePlates.lua), the sheen is
-- two textures of the addon's own laid over it, and no field of the game's
-- is written. None of these calls is protected, so this works in combat too.

local RaidFrames = {}
DogsForeverUI.Frames.RaidFrames = RaidFrames

do -- private scope
    local Style = DogsForeverUI.Style

    local done = setmetatable({}, { __mode = "k" })   -- frame -> its sheens

    local function Ours(frame)
        if type(frame) ~= "table" or type(frame.GetName) ~= "function" then return false end
        local ok, name = pcall(frame.GetName, frame)
        if not ok or type(name) ~= "string" then return false end
        return name:find("^CompactParty") ~= nil or name:find("^CompactRaid") ~= nil
    end

    local function Flat(bar)
        if type(bar) ~= "table" or type(bar.GetStatusBarTexture) ~= "function" then return nil end
        local fill = bar:GetStatusBarTexture()
        if not fill then return nil end
        fill:SetTexture(Style.FLAT_TEXTURE)
        fill:SetHorizTile(false)
        fill:SetVertTile(false)
        return fill
    end

    local function Background(texture)
        if type(texture) == "table" and type(texture.SetColorTexture) == "function" then
            Style.SetBackground(texture)
        end
    end

    function RaidFrames.Style(frame)
        if not Ours(frame) then return end
        local health, power = frame.healthBar, frame.powerBar
        local parts = done[frame]
        if not parts then
            parts = {}
            done[frame] = parts
        end
        if Flat(health) and not parts.health then
            parts.health = { Style.MakeSheen(health) }
        end
        if Flat(power) and not parts.power then
            parts.power = { Style.MakeSheen(power) }
        end
        Background(frame.background)
        if type(power) == "table" then Background(power.background) end
    end

    function RaidFrames.IsStyled(frame) return done[frame] ~= nil end

    -- Every party and raid frame the game has made so far.
    local function Sweep()
        for name, frame in pairs(_G) do
            if type(name) == "string" and (name:find("^CompactPartyFrame") or name:find("^CompactRaid"))
               and type(frame) == "table" and frame.healthBar then
                pcall(RaidFrames.Style, frame)
            end
        end
    end

    if type(CompactUnitFrame_SetUpFrame) == "function" then
        hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame)
            pcall(RaidFrames.Style, frame)
        end)
    end

    ---------------------------------------------------------------------------
    -- THE RAID FRAMES' EDIT MODE BOX, fitted to the raid frames (the player
    -- saw it cover the whole screen, 2026-10-02). The game's own bug: after
    -- laying the raid frames out, CompactRaidFrameContainer sizes itself
    -- (RefreshSize -> GetBounds) from EVERY list in its frameUpdateList - and
    -- those include the party's own group (AddGroup("PARTY") in OnLoad). With
    -- raid-style party frames on, the "raid" box then stretches from the raid
    -- groups to wherever the party frames are: across the screen.
    --
    -- What the raid frames really take is what the flow layout used,
    -- FlowContainer_GetUsedBounds - the game's own measure, the one its raid
    -- border is drawn from (UpdateBorder). The box (its Selection) is put
    -- round exactly that, anchored from the container's own TOPLEFT and
    -- BOTTOMRIGHT as Edit Mode anchors it, so its offsets and snapping read
    -- right; fitted again whenever the container is laid out or resized and
    -- whenever the box shows. Only the box: the container, its frames and its
    -- settings stay the game's. Out of combat only.
    --
    -- AND ITS CLAMP (the player, 2026-10-02: turning the raid frames on and
    -- off made them jump about, and dragged they moved left and right only).
    -- Every Edit Mode frame is kept on screen (EditModeSystemTemplate,
    -- clampedToScreen) by its clamp rect, which the game fits to the box
    -- (UpdateClampOffsets) - the box as it was BEFORE it was fitted here: the
    -- whole stretched container, or the 3000 x 3000 LayoutFrames gives it for
    -- a frame. Kept on screen whole, the container was shoved about whenever
    -- its size changed, and one about as tall as the screen could only slide
    -- sideways. So the clamp is fitted to the same box, as UpdateClampOffsets
    -- would fit it, every time the box is - and after every time the game
    -- works its clamp out again.
    ---------------------------------------------------------------------------

    local function FitRaidBox()
        local container = _G.CompactRaidFrameContainer
        local box = type(container) == "table" and container.Selection
        if type(box) ~= "table" or InCombatLockdown() or type(FlowContainer_GetUsedBounds) ~= "function" then
            return
        end
        local ok, usedX, usedY = pcall(FlowContainer_GetUsedBounds, container)
        if not ok or type(usedX) ~= "number" or type(usedY) ~= "number" or usedX <= 0 or usedY <= 0 then
            return
        end
        local width, height = container:GetWidth(), container:GetHeight()
        if not (width and height) or width <= 0 or height <= 0 then return end
        -- Never larger than the container itself.
        usedX, usedY = math.min(usedX, width), math.min(usedY, height)
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        box:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", usedX - width, height - usedY)
        -- UpdateClampOffsets' insets for that box: its offsets from the
        -- container's own corners.
        if type(container.SetClampRectInsets) == "function" then
            container:SetClampRectInsets(0, usedX - width, 0, height - usedY)
        end
        -- The box as the game's Edit Mode shows it, kept for Unlock Mode
        -- (ActionBars\GameFrames.lua, RememberEditModeRaid) - measured a
        -- frame later, once the points just set are laid out.
        local game = DogsForeverUI.GameFrames
        if game and game.RememberEditModeRaid then
            if C_Timer and C_Timer.After then
                C_Timer.After(0, game.RememberEditModeRaid)
            else
                game.RememberEditModeRaid()
            end
        end
    end
    RaidFrames.FitRaidBox = FitRaidBox

    local boxHooked = false
    local function HookRaidBox()
        local container = _G.CompactRaidFrameContainer
        if boxHooked or type(container) ~= "table" or type(container.Selection) ~= "table" then return end
        boxHooked = true
        for _, method in ipairs({ "LayoutFrames", "RefreshSize", "AnchorSelectionFrame", "UpdateClampOffsets" }) do
            if type(rawget(container, method)) == "function" then
                hooksecurefunc(container, method, FitRaidBox)
            end
        end
        container:HookScript("OnSizeChanged", FitRaidBox)
        container.Selection:HookScript("OnShow", FitRaidBox)
        FitRaidBox()
    end

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_LOGIN" then Sweep() end
        HookRaidBox()
        -- (Every addon's loading is waited on only until the box is hooked.)
        if boxHooked then self:UnregisterEvent("ADDON_LOADED") end
    end)
    HookRaidBox()
end
