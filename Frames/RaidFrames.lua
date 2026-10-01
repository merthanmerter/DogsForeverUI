-- The game's raid-style frames - the raid frames, and the party's when "Use
-- Raid-Style Party Frames" is on - drawn with this addon's textures, and
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
    RaidFrames.Sweep = Sweep

    if type(CompactUnitFrame_SetUpFrame) == "function" then
        hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame)
            pcall(RaidFrames.Style, frame)
        end)
    end

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        Sweep()
    end)
end
