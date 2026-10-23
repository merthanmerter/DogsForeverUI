-- The action buttons' look, no setting: every button of the addon's bars
-- (ActionBars\ActionBars.lua) and of the game's possess bar on the frames'
-- background in a thin bevelled gold border, the game's art gone, flat
-- states; the main bar's strip and end caps gone, from Edit Mode too.
-- The micro menu, the minimap drawer and the quest items share the look.

local Buttons = {}
DogsForeverUI.Menus.ActionButtons = Buttons

do -- private scope
    local Style = DogsForeverUI.Style
    local Core = DogsForeverUI

    local GAME_BARS = { "PossessActionBar" }   -- the game's bars it still shows
    local BUTTON_INSET = 3          -- the border's room inside the button, and the gap
    local GOLD_SHADE = 0.32         -- of the frames' border gold
    local CHECKED_ALPHA = 0.35      -- the border's gold, as a wash
    local COOLDOWNS = { "cooldown", "Cooldown", "lossOfControlCooldown", "chargeCooldown" }

    Buttons.ICON_CROP = 0.08        -- the edge baked into every icon
    Buttons.BORDER_PIXELS = 1       -- real pixels a line
    -- The frames' border without its middle line, its gold darker and bevelled.
    Buttons.BORDER = {
        radius = Style.DEFAULT_BORDER.radius, gap = 0,
        lines = {
            { Style.BORDER_COLOR[1] * GOLD_SHADE, Style.BORDER_COLOR[2] * GOLD_SHADE,
              Style.BORDER_COLOR[3] * GOLD_SHADE, 1 },
            Style.DIVIDER_COLOR,
        },
        bevel = { light = 1.6, shade = 0.55 },
    }
    Buttons.PUSHED = { 0, 0, 0, 0.35 }
    Buttons.HOVER = { 1, 1, 1, 0.15 }
    Buttons.CHECKED = { Style.BORDER_COLOR[1], Style.BORDER_COLOR[2], Style.BORDER_COLOR[3], CHECKED_ALPHA }

    Buttons.parts = setmetatable({}, { __mode = "k" })   -- button -> what was made for it

    local Fade, Get = Core.Fade, Core.Region

    -- A texture made a flat colour over `inner`: for a state texture, the
    -- same object the game shows and hides, only drawn differently.
    function Buttons.Flat(texture, inner, colour, blend)
        texture:SetTexture(Style.FLAT_TEXTURE)
        texture:SetVertexColor(colour[1], colour[2], colour[3], colour[4])
        texture:ClearAllPoints()
        texture:SetAllPoints(inner)
        if blend then texture:SetBlendMode(blend) end
    end

    local function FlatState(button, method, key, inner, colour, blend)
        local texture = Get(button, method, key)
        if texture then Buttons.Flat(texture, inner, colour, blend) end
    end

    -- Also a game button off the bars (the quest tracker's items, Objectives.lua).
    function Buttons.Skin(button)
        if Buttons.parts[button] then return end

        local inner = CreateFrame("Frame", nil, button)
        inner:SetPoint("TOPLEFT", button, "TOPLEFT", BUTTON_INSET, -BUTTON_INSET)
        inner:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -BUTTON_INSET, BUTTON_INSET)
        inner:SetFrameLevel(button:GetFrameLevel())

        local bg = button:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints(inner)
        Style.SetBackground(bg)

        Fade(button.SlotBackground)
        Fade(button.SlotArt)
        Fade(Get(button, "GetNormalTexture", "NormalTexture"))

        local icon = button.icon or button.Icon
        if icon then
            if button.IconMask then icon:RemoveMaskTexture(button.IconMask) end
            icon:SetTexCoord(Buttons.ICON_CROP, 1 - Buttons.ICON_CROP, Buttons.ICON_CROP, 1 - Buttons.ICON_CROP)
            icon:ClearAllPoints()
            icon:SetAllPoints(inner)
        end
        -- The template insets them in the icon: a stun's swipe covered only its middle.
        for _, key in ipairs(COOLDOWNS) do
            local cooldown = button[key]
            if cooldown then
                cooldown:ClearAllPoints()
                cooldown:SetAllPoints(inner)
            end
        end

        FlatState(button, "GetPushedTexture", "PushedTexture", inner, Buttons.PUSHED)
        FlatState(button, "GetHighlightTexture", "HighlightTexture", inner, Buttons.HOVER, "ADD")
        FlatState(button, "GetCheckedTexture", "CheckedTexture", inner, Buttons.CHECKED, "ADD")

        Buttons.parts[button] = {
            inner = inner, bg = bg, scale = button:GetEffectiveScale(),
            border = Style.AddBorder(inner, Buttons.BORDER, false, Buttons.BORDER_PIXELS),
        }
    end

    -- A bar's button laid out or moved: its border redrawn on the real pixels of a new
    -- size (one drawn for another scale smears), and its edges put on whole pixels.
    function Buttons.Fit(button)
        local parts = Buttons.parts[button]
        if not parts then return end
        local scale = button:GetEffectiveScale()
        if parts.scale ~= scale then
            parts.scale = scale
            Style.Refit(parts.border)
        end
        pcall(Style.SnapBorder, parts.border)
    end

    -- The main bar's strip, its dividers and the end caps; the caps are Edit
    -- Mode systems of their own, so they are held at no opacity, not hidden.
    local function StripMainBar()
        local bar = _G.MainActionBar
        Fade(bar.BorderArt)
        for _, key in ipairs({ "HorizontalDividersPool", "VerticalDividersPool" }) do
            local pool = bar[key]
            if pool then
                for divider in pool:EnumerateActive() do Fade(divider) end
            end
        end
        for _, key in ipairs({ "LeftEndCap", "RightEndCap" }) do
            local cap = bar.EndCaps[key]
            Fade(cap)
            Core.HoldEditMode(cap, true)
        end
    end

    -- Styling makes frames on the buttons: not in combat.
    function Buttons.Apply()
        if InCombatLockdown() then return false end
        local bars = Core.ActionBars
        for _, info in ipairs(bars.BARS) do
            for _, button in ipairs(bars.buttons[info.key] or {}) do
                Buttons.Skin(button)
                Buttons.Fit(button)
            end
        end
        for _, name in ipairs(GAME_BARS) do
            local bar = _G[name]
            for _, button in pairs(bar and bar.actionButtons or {}) do
                Buttons.Skin(button)
                Buttons.Fit(button)
            end
        end
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
