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
-- THE BARS are the addon's own since 2026-10-03 (ActionBars\ActionBars.lua,
-- EllesmereUI's way), sized in Unlock Mode; this file is only their look - and
-- the game's possess bar's, which the game still shows.
--
-- Styling makes frames on the buttons, so it waits for the end of combat if
-- the UI loads mid-fight.

local Buttons = {}
DogsForeverUI.Menus.ActionButtons = Buttons

do -- private scope

    local Style = DogsForeverUI.Style

    -- The game's bars still the game's: only its possess bar now (the rest
    -- are the addon's own - ActionBars\ActionBars.lua - their size set there).
    Buttons.BARS = { "PossessActionBar" }

    -- The look, shared with the micro menu's buttons (MicroMenu.lua).
    local ICON_CROP = 0.08         -- the edge baked into every icon
    local BUTTON_INSET = 3         -- the border's room inside the button, and the gap
    local BORDER_PIXELS = 1        -- real pixels a line (see above)
    Buttons.ICON_CROP, Buttons.BORDER_PIXELS = ICON_CROP, BORDER_PIXELS
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
    Buttons.HOVER = HOVER
    Buttons.CHECKED = {
        Style.BORDER_COLOR[1], Style.BORDER_COLOR[2], Style.BORDER_COLOR[3], CHECKED_ALPHA,
    }

    local styled = setmetatable({}, { __mode = "k" })
    Buttons.parts = setmetatable({}, { __mode = "k" })   -- button -> what was made for it

    local Fade, Get = DogsForeverUI.Fade, DogsForeverUI.Region

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
    -- The same look for a game button off the action bars (the quest
    -- tracker's item buttons, Objectives.lua).
    Buttons.Skin = StyleButton

    -- Every button of the addon's own bars (ActionBars\ActionBars.lua: its
    -- action buttons, and the game's stance and pet buttons taken into its
    -- bars), and the game's possess bar's, which the game still shows.
    local function EachButton(fn)
        local bars = DogsForeverUI.ActionBars
        if type(bars) == "table" and type(bars.buttons) == "table" then
            for _, info in ipairs(bars.BARS) do
                for _, button in ipairs(bars.buttons[info.key] or {}) do fn(button) end
            end
        end
        for _, name in ipairs(Buttons.BARS) do
            local bar = _G[name]
            if type(bar) == "table" and type(bar.actionButtons) == "table" then
                for _, button in pairs(bar.actionButtons) do fn(button) end
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
