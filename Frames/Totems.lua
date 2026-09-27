-- The player's totems, in a row under the player's frame and in the addon's
-- look.
--
-- WHOSE THEY ARE. The icons are the game's own totem buttons (TotemFrame,
-- Blizzard_UnitFrame/Mainline/TotemFrame.lua), not copies. The game fills
-- them, counts them down, shows their tooltips and dismisses a totem on a
-- right-click, all in its own code - code that reads totem slots an addon only
-- gets as secrets in combat (GetTotemInfo and GetTotemTimeLeft are
-- SecretWhenTotemSlotSecret). The addon reads none of that. What it changes is
-- where the buttons sit and what they look like:
--
--   * WHERE. In a row under the addon's player frame, lined up with its right
--     edge - towards the middle of the screen, away from the pet's frame on
--     the left - in the game's order. The game lays the buttons out in its
--     totem frame (TotemFrame:Layout, after every totem change) under its own
--     player frame, which is not drawn any more; a post-hook on that layout
--     moves each shown button into the row straight after it. The totem frame
--     itself stays where the game keeps it and shows and hides as the game
--     says, and with it the row.
--   * SIZE. The game's. The totem frame is taken out of the player frame's
--     scale - Edit Mode's "Frame Size" for a frame that is not on screen - and
--     drawn at the UI's own.
--   * LOOK. The action buttons' (Menus\ActionButtons.lua): the round ring
--     gone, the icon square with its baked-in edge trimmed, the thin gold
--     border and the black behind it; the time-left swipe square as well, in
--     the template's own colour; the time under the icon.
--
-- The buttons come from a pool, each made the first time it is needed. A
-- post-hook on the pool's Acquire gives a new one the look before the game
-- first fills it, so nothing is ever changed on a button that may already be
-- holding a secret icon, swipe or time. Switching the look on and off for
-- buttons already made waits for the end of combat, for the same reason.
--
-- Hooks only (hooksecurefunc): no function of the game's is replaced or
-- called, and nothing is written onto its frames but their look and their
-- anchors, none of which its code reads. With the unit frames off, all of it
-- is handed back: every button to the anchors the game gave it, and the look
-- the template made.

local Totems = {}
DogsForeverUI.Frames.Totems = Totems

do -- private scope
    local NS = DogsForeverUI.Frames
    local Style = DogsForeverUI.Style

    local ICON_CROP = 0.08            -- the edge baked into every icon
    local ICON_SIZE = 22              -- the template's, if the button cannot say
    local SPACING = 6                 -- between two icons
    local GAP = 6                     -- the player frame's border down to the row
    local TIME_GAP = 3                -- an icon's border down to its time
    local BORDER_PIXELS = 1           -- the action buttons' thin border
    local SWIPE = { 0, 0, 0, 0.65 }   -- TotemButtonTemplate's own swipe colour
    -- Where the template puts the time: under the button, 5 up into it.
    local GAME_TIME_Y = 5

    local looks = setmetatable({}, { __mode = "k" })        -- button -> what was made for it
    local gamePoints = setmetatable({}, { __mode = "k" })   -- button -> the game's anchors
    Totems.looks = looks
    Totems.on = false                 -- whether the addon has the totems now
    local gameScale                   -- the totem frame's scale before the addon's

    local function Call(object, method, ...)
        if type(object) ~= "table" or type(object[method]) ~= "function" then return end
        pcall(object[method], object, ...)
    end

    local function TotemFrame()
        local frame = _G.TotemFrame
        if type(frame) == "table" then return frame end
    end

    local function Pool()
        local frame = TotemFrame()
        local pool = frame and frame.totemPool
        if type(pool) == "table" and type(pool.EnumerateActive) == "function" then return pool end
    end

    local function EachActive(fn)
        local pool = Pool()
        if not pool then return end
        local list = {}
        for button in pool:EnumerateActive() do list[#list + 1] = button end
        for _, button in ipairs(list) do fn(button) end
    end

    -- The addon has the totems while its frames are on and the player's is
    -- there to hang them from.
    local function Wanted()
        local db = NS.db
        return db ~= nil and db.enabled == true and NS.plates ~= nil
            and NS.plates.player ~= nil
    end

    ---------------------------------------------------------------------------
    -- The look.
    ---------------------------------------------------------------------------

    -- The action buttons' border, made later in the load than this file.
    local function BorderSpec()
        local buttons = DogsForeverUI.Menus and DogsForeverUI.Menus.ActionButtons
        return buttons and buttons.BORDER or Style.DEFAULT_BORDER
    end

    -- The round swipe, exactly as TotemButtonMixin:OnLoad sets it up.
    local function RoundSwipe(cooldown)
        local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("CircleMask")
        if type(info) ~= "table" then return end
        Call(cooldown, "SetSwipeTexture", info.file or info.filename)
        Call(cooldown, "SetTexCoordRange", { x = info.leftTexCoord, y = info.topTexCoord },
            { x = info.rightTexCoord, y = info.bottomTexCoord })
    end

    local function SetLook(button, on)
        local icon = type(button) == "table" and button.Icon
        if type(icon) ~= "table" or type(icon.CreateTexture) ~= "function" then return end

        local look = looks[button]
        if not look then
            if not on then return end
            look = { on = false }
            look.bg = icon:CreateTexture(nil, "BACKGROUND", nil, -8)
            look.bg:SetAllPoints(icon)
            Style.SetBackground(look.bg)
            look.border = Style.AddBorder(icon, BorderSpec(), false, BORDER_PIXELS)
            looks[button] = look
        end
        if look.on == on then return end
        look.on = on

        look.bg:SetShown(on)
        look.border:SetShown(on)
        Call(button.Border, "SetAlpha", on and 0 or 1)

        local texture, mask = icon.Texture, icon.TextureMask
        if on then
            if mask then Call(texture, "RemoveMaskTexture", mask) end
            Call(texture, "SetTexCoord", ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        else
            if mask then Call(texture, "AddMaskTexture", mask) end
            Call(texture, "SetTexCoord", 0, 1, 0, 1)
        end

        local cooldown = icon.Cooldown
        if on then
            Call(cooldown, "SetSwipeTexture", Style.FLAT_TEXTURE)
            Call(cooldown, "SetTexCoordRange", { x = 0, y = 0 }, { x = 1, y = 1 })
        else
            RoundSwipe(cooldown)
        end
        Call(cooldown, "SetSwipeColor", SWIPE[1], SWIPE[2], SWIPE[3], SWIPE[4])

        local time = button.Duration
        Call(time, "ClearAllPoints")
        if on then
            Call(time, "SetPoint", "TOP", icon, "BOTTOM", 0, -TIME_GAP)
        else
            Call(time, "SetPoint", "TOP", button, "BOTTOM", 0, GAME_TIME_Y)
        end
    end

    ---------------------------------------------------------------------------
    -- The place.
    ---------------------------------------------------------------------------

    -- The row's top right corner, under the player frame's.
    local holder
    local function Holder()
        if not holder then
            holder = CreateFrame("Frame", nil, UIParent)
            holder:SetSize(1, 1)
            Totems.holder = holder
        end
        return holder
    end

    local function IconSize(button)
        local ok, size = pcall(button.Icon.GetWidth, button.Icon)
        if ok and type(size) == "number" and size > 0 then return size end
        return ICON_SIZE
    end

    local function ShownButtons()
        local list = {}
        EachActive(function(button)
            if button:IsShown() then list[#list + 1] = button end
        end)
        -- The game numbers them in its own order (TotemFrameMixin:Update).
        table.sort(list, function(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end)
        return list
    end

    -- Right-aligned: the last one at the player frame's right edge. A button
    -- is centred on its icon, so it is placed by its centre.
    local function PlaceButtons()
        local list = ShownButtons()
        for index, button in ipairs(list) do
            local size = IconSize(button)
            local fromRight = (#list - index) * (size + SPACING) + size / 2
            button:ClearAllPoints()
            button:SetPoint("CENTER", Holder(), "TOPRIGHT", -fromRight, -size / 2)
        end
    end

    local function SaveGamePoints(button)
        local points = {}
        local count = type(button.GetNumPoints) == "function" and button:GetNumPoints() or 0
        for index = 1, count do points[index] = { button:GetPoint(index) } end
        gamePoints[button] = points
    end

    local function RestoreGamePoints(button)
        local points = gamePoints[button]
        if not points then return end
        button:ClearAllPoints()
        for _, point in ipairs(points) do button:SetPoint(unpack(point)) end
    end

    -- Out of the player frame's scale, into the UI's; and back.
    local function Rescale(frame, on)
        if on then
            if gameScale == nil then gameScale = frame:GetScale() end
            Call(frame, "SetIgnoreParentScale", true)
            Call(frame, "SetScale", UIParent:GetScale())
        elseif gameScale ~= nil then
            Call(frame, "SetIgnoreParentScale", false)
            Call(frame, "SetScale", gameScale)
            gameScale = nil
        end
    end

    -- The borders are laid on the real pixels, which the scale just moved.
    local function RefitBorders()
        for _, look in pairs(looks) do Style.Refit(look.border) end
    end

    ---------------------------------------------------------------------------
    -- Following the game.
    ---------------------------------------------------------------------------

    -- A new button, before the game fills it.
    local function AfterAcquire()
        if not Totems.on then return end
        EachActive(function(button) SetLook(button, true) end)
    end

    -- The game has just laid its buttons out: note where it put them, for
    -- handing them back, and move them into the row.
    local function AfterLayout()
        if not Totems.on then return end
        EachActive(function(button)
            if button:IsShown() then SaveGamePoints(button) end
        end)
        PlaceButtons()
    end

    local hooked = false
    local function Hook()
        local frame = TotemFrame()
        if hooked or not frame then return end
        hooked = true
        if type(frame.Layout) == "function" then
            hooksecurefunc(frame, "Layout", AfterLayout)
        end
        local pool = Pool()
        if pool and type(pool.Acquire) == "function" then
            hooksecurefunc(pool, "Acquire", AfterAcquire)
        end
    end
    -- Now, as the addon loads: the game fills its totem frame for the first
    -- time on entering the world, after this.
    Hook()

    ---------------------------------------------------------------------------

    -- Take the totems, or hand them back. Out of combat only (see the top);
    -- the frames refresh again as combat ends.
    function Totems.Refresh()
        local frame = TotemFrame()
        if not frame or InCombatLockdown() then return end
        Hook()

        local on = Wanted()
        local was = Totems.on

        if on then
            local h = Holder()
            h:ClearAllPoints()
            h:SetPoint("TOPRIGHT", NS.plates.player, "BOTTOMRIGHT",
                0, -(Style.BORDER_INSET + GAP))
            -- Buttons on screen right now still sit where the game put them.
            if not was then
                EachActive(function(button)
                    if button:IsShown() then SaveGamePoints(button) end
                end)
            end
        end

        Rescale(frame, on)
        for button in pairs(looks) do SetLook(button, on) end
        if on then EachActive(function(button) SetLook(button, true) end) end
        RefitBorders()

        if on then
            PlaceButtons()
        elseif was then
            for _, button in ipairs(ShownButtons()) do RestoreGamePoints(button) end
        end
        Totems.on = on
    end

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("UI_SCALE_CHANGED")
    watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    watcher:SetScript("OnEvent", function()
        local frame = TotemFrame()
        if not frame or not Totems.on then return end
        Rescale(frame, true)
        RefitBorders()
    end)
end
