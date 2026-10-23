-- What the Frames module does to the game's own frames: its unit and party
-- frames kept off screen, its raid-style frames in the addon's textures, its
-- totem buttons moved under the player plate. No field of the game's is
-- written and no Edit Mode setting touched (taint); hooks are post-hooks.

local BlizzardFrames = {}
local RaidFrames = {}
local Totems = {}
DogsForeverUI.Frames.BlizzardFrames = BlizzardFrames
DogsForeverUI.Frames.RaidFrames = RaidFrames
DogsForeverUI.Frames.Totems = Totems

do -- private scope
    local NS = DogsForeverUI.Frames
    local Core = DogsForeverUI
    local Style = Core.Style
    local Fade, Call = Core.Fade, Core.Call

    ---------------------------------------------------------------------------
    -- UNIT FRAMES. Protected (hiding them in combat is refused), so they are
    -- faded - alpha is allowed in combat - and their mouse turned off out of
    -- combat. PartyFrame alone is reparented, a widget call.
    ---------------------------------------------------------------------------

    -- The target and focus frames' badges; the plate draws its own.
    local CONTEXTUAL_BADGES = {
        "PvpBackgroundCircle", "PvpBackgroundIcon", "PvpIcon", "PrestigePortrait", "PrestigeBadge",
        "HighLevelTexture", "BossIcon", "LeaderIcon", "GuideIcon",
    }

    local function TargetStyleParts()
        local parts = { { "TargetFrameContainer" }, { "TargetFrameContent", "TargetFrameContentMain" } }
        for _, key in ipairs(CONTEXTUAL_BADGES) do
            parts[#parts + 1] = { "TargetFrameContent", "TargetFrameContentContextual", key }
        end
        return parts
    end

    -- Each root takes no mouse; each path under it is faded ({} is the root).
    -- The player frame itself stays: its child lays out the totems (below).
    local FRAMES = {
        { root = "PlayerFrame", parts = { { "PlayerFrameContainer" }, { "PlayerFrameContent" } } },
        { root = "TargetFrame", parts = TargetStyleParts() },
        { root = "FocusFrame", parts = TargetStyleParts() },
        { root = "TargetFrameToT", parts = { {} } },
        { root = "FocusFrameToT", parts = { {} } },
        { root = "PetFrame", parts = { {} } },
        -- Retail shadow's Voidform art, on the player frame's portrait and mana bar spots
        -- (its own strata: the faded player frame's alpha never reached it).
        { root = "InsanityBarFrame", parts = { {} } },
    }

    -- Parts of the aura container can be forbidden objects: even reading a
    -- field of one raises, so the walk is wrapped.
    local function Walk(rootName, path)
        local frame = _G[rootName]
        for _, key in ipairs(path) do
            if type(frame) ~= "table" then return nil end
            frame = frame[key]
        end
        if type(frame) == "table" and type(frame.SetAlpha) == "function" then return frame end
    end

    local resolved = {}          -- path -> its frame, once found

    local function Resolve(rootName, path)
        if resolved[path] == nil then
            local ok, frame = pcall(Walk, rootName, path)
            resolved[path] = ok and frame or nil
        end
        return resolved[path]
    end

    -- The target and focus frames hold the game's aura rows, a forbidden
    -- container nothing may hide: the frames are retired whole - faded and
    -- shrunk to a hundredth, so their auras take no mouse. SetScaleBase skips
    -- Edit Mode's wrapper; scale waits for combat's end.
    local CARRIERS = { "TargetFrame", "FocusFrame" }
    local RETIRED_SCALE = 0.01
    local carrierHooked = {}

    local function Retire(frame)
        Fade(frame)
        if InCombatLockdown() or frame:GetScale() <= RETIRED_SCALE * 2 then return end
        pcall(frame.SetScaleBase or frame.SetScale, frame, RETIRED_SCALE)
    end

    local function RetireCarriers()
        for _, name in ipairs(CARRIERS) do
            local frame = _G[name]
            -- The game resizes them through Edit Mode's Frame Size and the
            -- focus's small/large switch: shrunk again after either.
            if not carrierHooked[name] then
                carrierHooked[name] = true
                for _, method in ipairs({ "UpdateSystemSettingFrameSize", "SetSmallSize" }) do
                    if type(frame[method]) == "function" then
                        hooksecurefunc(frame, method, function() Retire(frame) end)
                    end
                end
            end
            Core.HoldEditMode(frame, true)
            Retire(frame)
        end
    end

    -- The managed-frame container puts the pet frame's alpha back to 1 after
    -- the UI is shown again (AnimInManagedFrames): taken straight down again.
    local petAlphaHooked, refading = false, false

    local function HoldPetParts()
        local frame = PetFrame
        if not petAlphaHooked then
            petAlphaHooked = true
            hooksecurefunc(frame, "SetAlpha", function(self, alpha)
                if refading or alpha == 0 then return end
                refading = true
                Fade(self)
                refading = false
            end)
        end
        Core.HoldEditMode(frame, true)
        -- Its auras and happiness face would take the mouse while invisible.
        Call(frame.AuraFrameContainer, "SetShown", false)
        Call(_G.PetFrameHappiness, "EnableMouse", false)
    end

    -- THE GAME'S PARTY FRAMES, gone: standard and raid-style (CompactPartyFrame,
    -- made under PartyFrame) alike, EllesmereUI's way - their events off and
    -- PartyFrame under a frame that never shows. Done as the file loads (it
    -- holds secure buttons) and on every refresh. The raid frames stay.
    local hiddenParty = CreateFrame("Frame", "DogsForeverUIHiddenParty", UIParent)
    hiddenParty:SetAllPoints(UIParent)
    hiddenParty:Hide()
    BlizzardFrames.hiddenParty = hiddenParty
    local quieted = setmetatable({}, { __mode = "k" })
    local partyFollowed = false

    local PARTS = { "healthBar", "healthbar", "HealthBar", "manabar", "ManaBar", "powerBar",
                    "castBar", "spellbar", "powerBarAlt", "PowerBarAlt", "BuffFrame", "AurasFrame",
                    "DebuffFrame" }

    -- A frame's events off, and its bars'.
    local function Quiet(frame)
        if type(frame) ~= "table" or quieted[frame] then return end
        quieted[frame] = true
        Call(frame, "UnregisterAllEvents")
        for _, key in ipairs(PARTS) do Call(frame[key], "UnregisterAllEvents") end
        local bars = frame.HealthBarsContainer
        if type(bars) == "table" then Call(bars.healthBar, "UnregisterAllEvents") end
    end

    local function QuietList(list)
        if type(list) ~= "table" then return end
        for _, frame in ipairs(list) do Quiet(frame) end
    end

    function BlizzardFrames.RetireParty()
        local party = PartyFrame
        if InCombatLockdown() and party:IsProtected() then return end
        if party:GetParent() ~= hiddenParty then party:SetParent(hiddenParty) end
        Quiet(party)
        for index = 1, 4 do
            local member = party["MemberFrame" .. index]
            Quiet(member)
            if type(member) == "table" then Quiet(member.PetFrame) end
        end
        local pool = party.PartyMemberFramePool
        if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
            for member in pool:EnumerateActive() do Quiet(member) end
        end
        local compact = _G.CompactPartyFrame
        if type(compact) == "table" then
            Quiet(compact)
            QuietList(compact.memberUnitFrames)
            QuietList(compact.petUnitFrames)
        end
        Core.HoldEditMode(party, true)
        -- Put back under a shown frame: straight back (after the fight, in one).
        if not partyFollowed then
            partyFollowed = true
            party:HookScript("OnShow", function(self)
                if self:GetParent() ~= hiddenParty then BlizzardFrames.RetireParty() end
            end)
        end
    end

    BlizzardFrames.RetireParty()

    function BlizzardFrames.Refresh()
        BlizzardFrames.RetireParty()
        for _, entry in ipairs(FRAMES) do
            for _, path in ipairs(entry.parts) do
                local frame = Resolve(entry.root, path)
                if frame then Fade(frame) end
            end
            -- The mouse may be a protected call: asked again as combat ends.
            if not InCombatLockdown() then Call(_G[entry.root], "EnableMouse", false) end
        end
        Core.HoldEditMode(PlayerFrame, true)
        HoldPetParts()
        RetireCarriers()
    end

    ---------------------------------------------------------------------------
    -- RAID-STYLE FRAMES (CompactParty..., CompactRaid...) drawn with the
    -- addon's flat fill, sheen and background - nothing else of theirs
    -- changed. Styled as CompactUnitFrame_SetUpFrame sets each one up, those
    -- made before the addon swept at login. Textures only: fine in combat.
    ---------------------------------------------------------------------------

    local styled = setmetatable({}, { __mode = "k" })   -- frame -> { [bar key] = sheen done }

    -- (A nameplate's compact frame may be forbidden: even its name is asked
    -- under pcall.)
    local function Ours(frame)
        local ok, name = pcall(frame.GetName, frame)
        return ok and type(name) == "string" and (name:find("^CompactParty") or name:find("^CompactRaid")) ~= nil
    end

    -- The bar's own fill texture made flat; answers whether there was one.
    local function Flat(bar)
        local fill = type(bar) == "table" and bar:GetStatusBarTexture()
        if not fill then return false end
        fill:SetTexture(Style.FLAT_TEXTURE)
        fill:SetHorizTile(false)
        fill:SetVertTile(false)
        return true
    end

    local function Background(texture)
        if type(texture) == "table" then Style.SetBackground(texture) end
    end

    local RAID_BARS = { "healthBar", "powerBar" }

    local function StyleRaidFrame(frame)
        if not Ours(frame) then return end
        local parts = styled[frame] or {}
        styled[frame] = parts
        for _, key in ipairs(RAID_BARS) do
            local bar = frame[key]
            if Flat(bar) and not parts[key] then
                Style.MakeSheen(bar)
                parts[key] = true
            end
        end
        Background(frame.background)
        if type(frame.powerBar) == "table" then Background(frame.powerBar.background) end
    end

    function RaidFrames.IsStyled(frame) return styled[frame] ~= nil end

    hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame) pcall(StyleRaidFrame, frame) end)

    -- THE RAID FRAMES' EDIT MODE BOX. The game sizes CompactRaidFrameContainer
    -- from every list it lays out, the party's too, so with raid-style party
    -- frames its box (Selection) stretched across the screen. The box and its
    -- clamp are fitted to what the flow really used (FlowContainer_
    -- GetUsedBounds), from the container's own corners as Edit Mode anchors
    -- it. Only the box: the container and its frames stay the game's.

    -- The box kept for Unlock Mode (ActionBars\GameFrames.lua), measured a
    -- frame later, once the points just set are laid out.
    local rememberRaid = Core.Waker(function()
        local game = Core.GameFrames
        if game and game.RememberEditModeRaid then game.RememberEditModeRaid() end
    end)

    function RaidFrames.FitRaidBox()
        local container = _G.CompactRaidFrameContainer
        local box = type(container) == "table" and container.Selection
        if type(box) ~= "table" or InCombatLockdown() then return end
        local ok, usedX, usedY = pcall(FlowContainer_GetUsedBounds, container)
        if not ok or type(usedX) ~= "number" or type(usedY) ~= "number" or usedX <= 0 or usedY <= 0 then
            return
        end
        local width, height = container:GetWidth(), container:GetHeight()
        if not (width and height) or width <= 0 or height <= 0 then return end
        usedX, usedY = math.min(usedX, width), math.min(usedY, height)
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        box:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", usedX - width, height - usedY)
        container:SetClampRectInsets(0, usedX - width, 0, height - usedY)
        rememberRaid()
    end

    -- Fitted again whenever the game lays it out, works its clamp out again,
    -- resizes it or shows the box (Blizzard_CompactRaidFrames loads on demand).
    local boxHooked = false
    local function HookRaidBox()
        local container = _G.CompactRaidFrameContainer
        if boxHooked or type(container) ~= "table" or type(container.Selection) ~= "table" then return end
        boxHooked = true
        for _, method in ipairs({ "LayoutFrames", "RefreshSize", "AnchorSelectionFrame", "UpdateClampOffsets" }) do
            if type(rawget(container, method)) == "function" then
                hooksecurefunc(container, method, RaidFrames.FitRaidBox)
            end
        end
        container:HookScript("OnSizeChanged", RaidFrames.FitRaidBox)
        container.Selection:HookScript("OnShow", RaidFrames.FitRaidBox)
        RaidFrames.FitRaidBox()
    end

    -- THE GROUP MANAGER (CompactRaidFrameManager, the game's party and raid options
    -- at the screen's left edge): collapsed, its button alone - the strip of its
    -- background left past the edge faded while its options are shut.

    -- Its open and close buttons wear the addon's drawer handle's arrow (Minimap\Buttons.lua),
    -- `rotation` from pointing left, added over itself under the mouse; the game's stone-capped
    -- art faded (its hover swaps only that art's atlas).
    local function Arrow(button, rotation)
        if type(button) ~= "table" then return end
        for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
            Fade(Call(button, getter))
        end
        local arrow = Style.ARROW
        for _, layer in ipairs({ "ARTWORK", "HIGHLIGHT" }) do
            local texture = button:CreateTexture(nil, layer)
            texture:SetAtlas(arrow.atlas)
            texture:SetSize(arrow.width, arrow.height)
            texture:SetPoint("CENTER", button, "CENTER", 0, 0)
            texture:SetRotation(rotation)
            if layer == "HIGHLIGHT" then
                texture:SetBlendMode("ADD")
                texture:SetAlpha(arrow.highlight)
            end
        end
    end

    local managerHooked = false
    local function HookManager()
        local manager = _G.CompactRaidFrameManager
        local options = type(manager) == "table" and manager.displayFrame
        if managerHooked or type(options) ~= "table" then return end
        managerHooked = true
        local function Follow() Call(manager.Background, "SetAlpha", options:IsShown() and 1 or 0) end
        options:HookScript("OnShow", Follow)
        options:HookScript("OnHide", Follow)
        Follow()
        Arrow(manager.toggleButtonForward, math.pi)
        Arrow(manager.toggleButtonBack, 0)
    end

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_LOGIN" then
            for name, frame in pairs(_G) do
                if type(name) == "string" and (name:find("^CompactPartyFrame") or name:find("^CompactRaid"))
                   and type(frame) == "table" and frame.healthBar then
                    pcall(StyleRaidFrame, frame)
                end
            end
        end
        HookRaidBox()
        HookManager()
        if boxHooked and managerHooked then self:UnregisterEvent("ADDON_LOADED") end
    end)
    HookRaidBox()
    HookManager()

    ---------------------------------------------------------------------------
    -- TOTEMS: the game's own buttons (TotemFrame) in a row under the player
    -- plate, in the action buttons' look. The game fills, counts and dismisses
    -- them from data that is secret in combat, none of it read here. A new
    -- button gets the look on the pool's Acquire, before it is filled; the row
    -- is placed after every TotemFrame:Layout.
    ---------------------------------------------------------------------------

    local ICON_CROP = 0.08            -- the edge baked into every icon
    local ICON_SIZE = 22              -- the template's, if the button cannot say
    local TOTEM_SPACING = 6           -- between two icons
    local TOTEM_GAP = 6               -- the player frame's border down to the row
    local TIME_GAP = 3                -- an icon's border down to its time
    local BORDER_PIXELS = 1           -- the action buttons' thin border
    local SWIPE = { 0, 0, 0, 0.65 }   -- TotemButtonTemplate's own swipe colour

    local looks = setmetatable({}, { __mode = "k" })        -- button -> what was made for it
    Totems.looks = looks
    Totems.on = false                 -- whether the addon has the totems yet

    -- The row's top right corner, under the player plate's.
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetSize(1, 1)
    Totems.holder = holder

    local pool = TotemFrame.totemPool

    -- Square icon, thin gold border, square swipe, time under the icon.
    local function SetLook(button)
        if looks[button] then return end
        local icon = button.Icon
        local look = {}
        look.bg = icon:CreateTexture(nil, "BACKGROUND", nil, -8)
        look.bg:SetAllPoints(icon)
        Style.SetBackground(look.bg)
        -- (The action buttons' border, from a file that loads later.)
        local buttons = Core.Menus and Core.Menus.ActionButtons
        look.border = Style.AddBorder(icon, buttons and buttons.BORDER or Style.DEFAULT_BORDER, false, BORDER_PIXELS)
        looks[button] = look

        Call(button.Border, "SetAlpha", 0)
        local texture, mask = icon.Texture, icon.TextureMask
        if mask then Call(texture, "RemoveMaskTexture", mask) end
        Call(texture, "SetTexCoord", ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        Call(icon.Cooldown, "SetSwipeTexture", Style.FLAT_TEXTURE)
        Call(icon.Cooldown, "SetTexCoordRange", { x = 0, y = 0 }, { x = 1, y = 1 })
        Call(icon.Cooldown, "SetSwipeColor", SWIPE[1], SWIPE[2], SWIPE[3], SWIPE[4])
        Call(button.Duration, "ClearAllPoints")
        Call(button.Duration, "SetPoint", "TOP", icon, "BOTTOM", 0, -TIME_GAP)
    end

    local function SetLooks()
        for button in pool:EnumerateActive() do SetLook(button) end
    end

    local function InGameOrder(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end

    -- Right-aligned, in the game's order; a button is placed by its centre.
    local function PlaceTotems()
        local list = {}
        for button in pool:EnumerateActive() do
            if button:IsShown() then list[#list + 1] = button end
        end
        table.sort(list, InGameOrder)
        for index, button in ipairs(list) do
            local size = button.Icon:GetWidth()
            if not size or size <= 0 then size = ICON_SIZE end
            button:ClearAllPoints()
            button:SetPoint("CENTER", holder, "TOPRIGHT",
                -((#list - index) * (size + TOTEM_SPACING) + size / 2), -size / 2)
        end
    end

    -- Out of the player frame's scale, into the UI's; the borders refitted
    -- to the real pixels after.
    local function Rescale()
        Call(TotemFrame, "SetIgnoreParentScale", true)
        Call(TotemFrame, "SetScale", UIParent:GetScale())
        for _, look in pairs(looks) do Style.Refit(look.border) end
    end

    hooksecurefunc(TotemFrame, "Layout", function()
        if Totems.on then PlaceTotems() end
    end)
    hooksecurefunc(pool, "Acquire", function()
        if Totems.on then SetLooks() end
    end)

    -- Out of combat only (a button already made may hold secrets then); the
    -- frames refresh again as combat ends.
    function Totems.Refresh()
        if InCombatLockdown() or not NS.plates then return end
        holder:ClearAllPoints()
        holder:SetPoint("TOPRIGHT", NS.plates.player, "BOTTOMRIGHT", 0, -(Style.BORDER_INSET + TOTEM_GAP))
        Rescale()
        SetLooks()
        PlaceTotems()
        Totems.on = true
    end

    local scaleWatcher = CreateFrame("Frame")
    scaleWatcher:RegisterEvent("UI_SCALE_CHANGED")
    scaleWatcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    scaleWatcher:SetScript("OnEvent", function()
        if Totems.on then Rescale() end
    end)
end
