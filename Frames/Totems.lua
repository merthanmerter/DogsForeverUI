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
-- holding a secret icon, swipe or time. Buttons already made get the look
-- out of combat only, for the same reason.
--
-- Hooks only (hooksecurefunc): no function of the game's is replaced or
-- called, and nothing is written onto its frames but their look and their
-- anchors, none of which its code reads.

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

    local looks = setmetatable({}, { __mode = "k" })        -- button -> what was made for it
    Totems.looks = looks
    Totems.on = false                 -- whether the addon has the totems yet

    local Call = DogsForeverUI.Call

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
        for button in pool:EnumerateActive() do fn(button) end
    end

    -- The addon has the totems once the player's frame is there to hang them
    -- from.
    local function Wanted()
        return NS.plates ~= nil and NS.plates.player ~= nil
    end

    ---------------------------------------------------------------------------
    -- The look.
    ---------------------------------------------------------------------------

    -- The action buttons' border, made later in the load than this file.
    local function BorderSpec()
        local buttons = DogsForeverUI.Menus and DogsForeverUI.Menus.ActionButtons
        return buttons and buttons.BORDER or Style.DEFAULT_BORDER
    end

    local function SetLook(button)
        local icon = type(button) == "table" and button.Icon
        if type(icon) ~= "table" or type(icon.CreateTexture) ~= "function" then return end
        if looks[button] then return end

        local look = {}
        look.bg = icon:CreateTexture(nil, "BACKGROUND", nil, -8)
        look.bg:SetAllPoints(icon)
        Style.SetBackground(look.bg)
        look.border = Style.AddBorder(icon, BorderSpec(), false, BORDER_PIXELS)
        looks[button] = look

        Call(button.Border, "SetAlpha", 0)

        local texture, mask = icon.Texture, icon.TextureMask
        if mask then Call(texture, "RemoveMaskTexture", mask) end
        Call(texture, "SetTexCoord", ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)

        local cooldown = icon.Cooldown
        Call(cooldown, "SetSwipeTexture", Style.FLAT_TEXTURE)
        Call(cooldown, "SetTexCoordRange", { x = 0, y = 0 }, { x = 1, y = 1 })
        Call(cooldown, "SetSwipeColor", SWIPE[1], SWIPE[2], SWIPE[3], SWIPE[4])

        local time = button.Duration
        Call(time, "ClearAllPoints")
        Call(time, "SetPoint", "TOP", icon, "BOTTOM", 0, -TIME_GAP)
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

    -- The game numbers them in its own order (TotemFrameMixin:Update).
    local function ByLayoutIndex(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end

    local function ShownButtons()
        local list = {}
        local pool = Pool()
        if pool then
            for button in pool:EnumerateActive() do
                if button:IsShown() then list[#list + 1] = button end
            end
        end
        table.sort(list, ByLayoutIndex)
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

    -- Out of the player frame's scale, into the UI's.
    local function Rescale(frame)
        Call(frame, "SetIgnoreParentScale", true)
        Call(frame, "SetScale", UIParent:GetScale())
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
        EachActive(SetLook)
    end

    -- The game has just laid its buttons out: move them into the row.
    local function AfterLayout()
        if Totems.on then PlaceButtons() end
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

    -- Take the totems. Out of combat only (see the top); the frames refresh
    -- again as combat ends.
    function Totems.Refresh()
        local frame = TotemFrame()
        if not frame or InCombatLockdown() then return end
        Hook()
        if not Wanted() then return end

        local h = Holder()
        h:ClearAllPoints()
        h:SetPoint("TOPRIGHT", NS.plates.player, "BOTTOMRIGHT", 0, -(Style.BORDER_INSET + GAP))

        Rescale(frame)
        EachActive(SetLook)
        RefitBorders()
        PlaceButtons()
        Totems.on = true
    end

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("UI_SCALE_CHANGED")
    watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    watcher:SetScript("OnEvent", function()
        local frame = TotemFrame()
        if not frame or not Totems.on then return end
        Rescale(frame)
        RefitBorders()
    end)
end