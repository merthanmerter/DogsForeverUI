-- The action bars in the addon's look, and at its size.
--
-- WHAT CHANGES. Every button on every action bar (the eight bars, the stance
-- bar, the pet bar, the possess bar):
--
--   * the unit frames' border round it (Style.AddBorder), thinner: their gold
--     line and black inner line with the rounded corners, one real pixel a
--     line - no bevel between (the player asked for it thinner). At the
--     frames' own thickness every border is some 250 textures, and there are
--     over 130 buttons. Drawn inside the button, the icon inset BUTTON_INSET
--     within it, which also leaves a very slight gap between neighbouring
--     buttons (the player asked for one) without touching the bar's layout;
--   * the frames' semi-transparent black behind it (Style.SetBackground),
--     which is what an empty slot shows;
--   * none of the game's art: the slot background, the slot art and the frame
--     (the "normal" texture) at no opacity; the pressed, hover and checked
--     states flat - a darkening, a soft light, a gold wash - in the icon's
--     square instead of the game's atlases; the icon square, unmasked, its
--     baked-in edge trimmed off (texcoords 0.08-0.92) and all three cooldowns
--     (normal, loss of control, charge) laid over exactly it.
--
-- The main bar's own art goes too - the strip behind it (BorderArt) and the
-- dividers between its buttons - and so do the end caps, the gryphons at
-- either end: always, whatever Edit Mode's "Hide Bar Art" says, and gone from
-- Edit Mode as well (they are Edit Mode systems of their own on this client,
-- which it shows whenever it is open, so they are held at no opacity rather
-- than hidden, and taken out of Edit Mode with DogsForeverUI.HoldEditMode).
--
-- Nothing re-sets any of this: this client does not load the Mainline
-- UpdateButtonArt override (Blizzard_ActionBar.toc, [AllowLoadGameType
-- mainline]), and nothing else touches these textures' alpha, atlas or crop.
-- The state indicators the game draws over a button - the proc glow, the
-- equipped-item border, the attack flash, auto-cast - are left as they are:
-- they say something.
--
-- THE SIZE, of the eight action bars (not stance, pet or possess, which stay
-- the game's size). The game's 80% is this addon's 100%. Edit Mode's Icon Size setting
-- scales each button's container (EditModeActionBarSystemMixin:
-- UpdateSystemSettingIconSize: container:SetScale(iconScale), then the bar's
-- own Layout). A secure post-hook on each container's SetScale sets it to 0.8
-- of that at once, before the game's Layout runs - so the game lays the bar
-- out at the smaller size itself, in its own secure code, and the Icon Size
-- slider still works, from 80% of whatever it says. The addon never calls a
-- layout, never writes an Edit Mode setting and never replaces a function; a
-- hooksecurefunc hook cannot taint the code that called it.
--
-- The hooks go on as the addon loads, before Edit Mode applies its layout
-- after login, so the first layout is already at the addon's size. There is
-- no setting: this is the look.
--
-- Styling makes frames on the buttons, so it waits for the end of combat if
-- the UI loads mid-fight.

local Buttons = {}
DogsForeverUI.Menus.ActionButtons = Buttons

do -- private scope

    local Style = DogsForeverUI.Style

    Buttons.BARS = {
        "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
        "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7",
        "StanceBar", "PetActionBar", "PossessActionBar",
    }

    Buttons.SCALE = 0.8            -- the game's 80% is the addon's 100%
    -- Only the eight action bars are made smaller. The stance, pet and possess
    -- bars keep the look but stay exactly the game's size (the player asked).
    Buttons.SCALED = {
        MainActionBar = true, MultiBarBottomLeft = true, MultiBarBottomRight = true,
        MultiBarRight = true, MultiBarLeft = true, MultiBar5 = true, MultiBar6 = true,
        MultiBar7 = true,
    }
    local ICON_CROP = 0.08         -- the edge baked into every icon
    local BUTTON_INSET = 3         -- the border's room inside the button, and the gap
    local BORDER_PIXELS = 1        -- real pixels a line (see above)
    -- The frames' border with its middle (bevel) line taken out, and its gold
    -- darker (the player asked five times: 85%, 75%, 60%, 45%, then "just too
    -- gold" with the bevel on): the frames' 178,142,97 at 32%.
    local GOLD_SHADE = 0.32
    Buttons.GOLD = {
        Style.BORDER_COLOR[1] * GOLD_SHADE, Style.BORDER_COLOR[2] * GOLD_SHADE,
        Style.BORDER_COLOR[3] * GOLD_SHADE, 1,
    }
    -- The gold line bevelled for a slight 3D edge at the same thin width (the
    -- player asked): lit along the top and left, shaded along the bottom and
    -- right.
    Buttons.BORDER = {
        radius = Style.DEFAULT_BORDER.radius, gap = 0,
        lines = { Buttons.GOLD, Style.DIVIDER_COLOR },
        bevel = { light = 1.6, shade = 0.55 },
    }
    local PUSHED = { 0, 0, 0, 0.35 }
    local HOVER = { 1, 1, 1, 0.15 }
    local CHECKED_ALPHA = 0.35     -- the border's gold, as a wash

    local styled = setmetatable({}, { __mode = "k" })
    Buttons.parts = setmetatable({}, { __mode = "k" })   -- button -> what was made for it

    local function Fade(region)
        if type(region) == "table" and type(region.SetAlpha) == "function" then
            pcall(region.SetAlpha, region, 0)
        end
    end

    local function Get(button, method, key)
        if type(button[method]) == "function" then
            local ok, region = pcall(button[method], button)
            if ok and region then return region end
        end
        return button[key]
    end

    -- One of the button's state textures made a flat colour over the icon's
    -- square: the same texture object the game shows and hides for the state,
    -- only drawn differently.
    local function Flat(texture, inner, colour, blend)
        if type(texture) ~= "table" or type(texture.SetTexture) ~= "function" then return end
        texture:SetTexture(Style.FLAT_TEXTURE)
        texture:SetVertexColor(colour[1], colour[2], colour[3], colour[4])
        texture:ClearAllPoints()
        texture:SetAllPoints(inner)
        if blend then texture:SetBlendMode(blend) end
    end

    local function StyleButton(button)
        if styled[button] or type(button) ~= "table" then return end
        styled[button] = true
        local inset = BUTTON_INSET

        -- The icon's square, inside the border.
        local inner = CreateFrame("Frame", nil, button)
        inner:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
        inner:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
        inner:SetFrameLevel(button:GetFrameLevel())

        local bg = button:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints(inner)
        Style.SetBackground(bg)
        local border = Style.AddBorder(inner, Buttons.BORDER, false, BORDER_PIXELS)

        -- The game's art, gone.
        Fade(button.SlotBackground)
        Fade(button.SlotArt)
        Fade(Get(button, "GetNormalTexture", "NormalTexture"))

        local icon = button.icon or button.Icon
        if type(icon) == "table" then
            if button.IconMask and type(icon.RemoveMaskTexture) == "function" then
                pcall(icon.RemoveMaskTexture, icon, button.IconMask)
            end
            icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
            icon:ClearAllPoints()
            icon:SetAllPoints(inner)
        end
        -- All three of the button's cooldowns: the normal one, the loss of
        -- control one (stuns, sleeps: dark red with a lit edge) and the charge
        -- one. The template anchors them 3 and 2 inside the icon; left there,
        -- the stun swipe covered only the middle, ringed by lit icon.
        for _, key in ipairs({ "cooldown", "Cooldown", "lossOfControlCooldown", "chargeCooldown" }) do
            local cooldown = button[key]
            if type(cooldown) == "table" and type(cooldown.SetAllPoints) == "function" then
                cooldown:ClearAllPoints()
                cooldown:SetAllPoints(inner)
            end
        end

        Flat(Get(button, "GetPushedTexture", "PushedTexture"), inner, PUSHED)
        Flat(Get(button, "GetHighlightTexture", "HighlightTexture"), inner, HOVER, "ADD")
        local gold = Style.BORDER_COLOR
        Flat(Get(button, "GetCheckedTexture", "CheckedTexture"), inner,
            { gold[1], gold[2], gold[3], CHECKED_ALPHA }, "ADD")

        -- Kept on the addon's side: nothing is written onto the game's button.
        Buttons.parts[button] = { inner = inner, bg = bg, border = border }
    end

    local function EachButton(fn)
        for _, name in ipairs(Buttons.BARS) do
            local bar = _G[name]
            if type(bar) == "table" and type(bar.actionButtons) == "table" then
                for _, button in pairs(bar.actionButtons) do fn(button, bar, name) end
            end
        end
    end

    ---------------------------------------------------------------------------
    -- The main bar's art and the end caps.
    ---------------------------------------------------------------------------

    local endCapEditMode = {}

    local function FadeDividers(bar)
        for _, key in ipairs({ "HorizontalDividersPool", "VerticalDividersPool" }) do
            local pool = bar[key]
            if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
                for divider in pool:EnumerateActive() do Fade(divider) end
            end
        end
    end

    local function StripMainBar()
        local bar = _G.MainActionBar
        if type(bar) ~= "table" then return end
        Fade(bar.BorderArt)
        FadeDividers(bar)
        local caps = bar.EndCaps
        if type(caps) == "table" then
            for _, key in ipairs({ "LeftEndCap", "RightEndCap" }) do
                local cap = caps[key]
                if type(cap) == "table" then
                    Fade(cap)
                    DogsForeverUI.HoldEditMode(endCapEditMode, cap, true)
                end
            end
        end
    end

    ---------------------------------------------------------------------------
    -- The size: 0.8 of whatever Edit Mode's Icon Size says.
    ---------------------------------------------------------------------------

    local scaling = false
    local hookedContainers = setmetatable({}, { __mode = "k" })

    local function ScaleContainer(container, scale)
        if scaling or type(scale) ~= "number" or InCombatLockdown() then return end
        scaling = true
        pcall(container.SetScale, container, scale * Buttons.SCALE)
        scaling = false
    end

    local function HookScale(button, _, barName)
        if not Buttons.SCALED[barName] then return end
        local container = button.container
        if type(container) ~= "table" or hookedContainers[container]
           or type(container.SetScale) ~= "function" then
            return
        end
        hookedContainers[container] = true
        hooksecurefunc(container, "SetScale", ScaleContainer)
    end

    -- Now, at load: the containers exist (Blizzard_ActionBar loads before any
    -- addon) and Edit Mode has not laid anything out yet.
    EachButton(HookScale)

    local mainBar = _G.MainActionBar
    if type(mainBar) == "table" and type(mainBar.UpdateDividers) == "function" then
        hooksecurefunc(mainBar, "UpdateDividers", FadeDividers)
    end

    ---------------------------------------------------------------------------

    function Buttons.Apply()
        if InCombatLockdown() then return false end
        EachButton(StyleButton)
        StripMainBar()
        return true
    end

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function(self, event)
        if Buttons.Apply() then
            self:UnregisterAllEvents()
        elseif event == "PLAYER_LOGIN" then
            self:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
    end)
end
