-- A BUTTON FOR THE ADDON IN THE GAME MENU (Esc) (the player, 2026-10-03:
-- "should add a button for Dog's Forever UI in ESC game menu too. It should
-- be same design but only different background color (our yellow)").
--
-- EllesmereUI's way (Ellesmere\EllesmereUI\EllesmereUI.lua, its game menu
-- button): a button of the addon's own on the game menu, from the game's own
-- template (MainMenuFrameButtonTemplate - the same art, size and font as the
-- game's buttons), put under Options (under the Shop when there is one)
-- each time the game lays its menu out (a post-hook on its Layout), the
-- game's buttons under it moved down by its height and the menu made that
-- much taller. Its art the game's red, greyed and made a light gold (Tint),
-- its hover glow the same gold.
-- A click shuts the menu and opens the addon's options.
--
-- Nothing of the game's written to: the button is the addon's; the game's
-- buttons only moved (SetPoint), the menu only made taller (SetHeight).

local GameMenu = {}
DogsForeverUI.Options.GameMenu = GameMenu

do -- private scope
    local Core = DogsForeverUI

    GameMenu.LABEL = Core.TITLE or "Dog's Forever UI"
    GameMenu.GAP = 12          -- above it, as EllesmereUI has it
    GameMenu.ROOM = 40         -- what it adds to the menu: its height and the gap

    local button
    local baseHeight

    -- The game's art in the addon's gold: greyed, then tinted (what the
    -- game sets on it as it is pressed or let go keeps both). Tinted only,
    -- the greyed red art came out a dark, barely visible gold (the player,
    -- 2026-10-03: "should be lighter yellow"), and a colour cannot be raised
    -- past the art's own: so a copy of each piece is laid over it, added
    -- (ADD blend) in the same gold - the art's own shading kept, brighter.
    -- Its highlight (the game's red glow) greyed and tinted the same gold,
    -- so hovering matches. The gold is the addon's own (Style.GOLD, #ffbb20 -
    -- the player, 2026-10-03: "should match our default orangeish yellow";
    -- a paler yellow before).
    GameMenu.LIGHT = Core.Style.GOLD
    GameMenu.LIFT = 0.65                -- how much of it the copy adds
    local PIECES = { "Left", "Center", "Right" }
    local lifts = setmetatable({}, { __mode = "k" })   -- button -> { piece key -> its copy }

    local function Lift(self, key, texture)
        local own = lifts[self]
        if not own then
            own = {}
            lifts[self] = own
        end
        local copy = own[key]
        if not copy then
            copy = self:CreateTexture(nil, "BACKGROUND", nil, 1)
            copy:SetAllPoints(texture)
            if copy.SetBlendMode then copy:SetBlendMode("ADD") end
            own[key] = copy
        end
        local atlas = texture.GetAtlas and texture:GetAtlas()
        if atlas then copy:SetAtlas(atlas) end
        if texture.GetTexCoord then copy:SetTexCoord(texture:GetTexCoord()) end
        if copy.SetDesaturated then copy:SetDesaturated(true) end
        local light = GameMenu.LIGHT
        copy:SetVertexColor(light[1], light[2], light[3], GameMenu.LIFT)
        copy:SetShown(atlas ~= nil)
    end

    local function Tint(self)
        local light = GameMenu.LIGHT
        for _, key in ipairs(PIECES) do
            local texture = self[key]
            if type(texture) == "table" and texture.SetVertexColor then
                if texture.SetDesaturated then texture:SetDesaturated(true) end
                texture:SetVertexColor(light[1], light[2], light[3], 1)
                Lift(self, key, texture)
            end
        end
        local glow = self.GetHighlightTexture and self:GetHighlightTexture()
        if type(glow) == "table" and glow.SetVertexColor then
            if glow.SetDesaturated then glow:SetDesaturated(true) end
            glow:SetVertexColor(light[1], light[2], light[3], 1)
        end
    end
    GameMenu.lifts = lifts

    local function Build(menu)
        if button then return button end
        button = CreateFrame("Button", Core.ADDON_NAME .. "GameMenuButton", menu, "MainMenuFrameButtonTemplate")
        button:SetSize(200, 35)
        button:SetText(GameMenu.LABEL)
        Tint(button)
        if type(button.UpdateButton) == "function" then hooksecurefunc(button, "UpdateButton", Tint) end
        -- (Resized, the template re-cuts its end pieces: the copies follow.)
        button:HookScript("OnSizeChanged", Tint)
        -- In combat too (the player, 2026-10-06: "Dog's Forever UI button
        -- also should be available in combat"): the game menu is not a
        -- protected frame, nor is the button or the options window.
        button:SetScript("OnClick", function()
            if type(HideUIPanel) == "function" then HideUIPanel(menu) else menu:Hide() end
            if Core.Options and Core.Options.Open then Core.Options.Open() end
        end)
        GameMenu.button = button
        return button
    end

    -- Under Options (or the Shop under it), the game's buttons below moved down.
    function GameMenu.Place(menu)
        menu = menu or _G.GameMenuFrame
        if type(menu) ~= "table" or type(menu.buttonPool) ~= "table" then return end
        local own = Build(menu)
        local anchor
        for gameButton in menu.buttonPool:EnumerateActive() do
            local text = gameButton:GetText()
            if text == _G.BLIZZARD_STORE then
                anchor = gameButton
                break
            elseif text == _G.GAMEMENU_OPTIONS then
                anchor = gameButton
            end
        end
        if not anchor then
            own:Hide()
            return
        end
        local width, height = anchor:GetWidth(), anchor:GetHeight()
        if width and width > 0 then own:SetSize(width, height or 35) end
        own:ClearAllPoints()
        own:SetPoint("TOP", anchor, "BOTTOM", 0, -GameMenu.GAP)
        own:Show()
        -- Its art: the template sets it only in its OnShow, which never ran
        -- for a button made inside the menu while the menu showed (the
        -- player, 2026-10-03: "missing background"). Set here, on our own
        -- button, each time the menu is laid out.
        if type(own.UpdateButton) == "function" then own:UpdateButton() end
        Tint(own)

        local bottom = anchor:GetBottom()
        if bottom then
            for gameButton in menu.buttonPool:EnumerateActive() do
                local top = gameButton:GetTop()
                if top and top < bottom + 2 then
                    local point, relative, relativePoint, x, y = gameButton:GetPoint(1)
                    if point then
                        gameButton:ClearAllPoints()
                        gameButton:SetPoint(point, relative, relativePoint, x, (y or 0) - GameMenu.ROOM)
                    end
                end
            end
        end
        baseHeight = baseHeight or menu:GetHeight()
        menu:SetHeight(baseHeight + GameMenu.ROOM)
    end

    local hooked = false
    function GameMenu.Follow()
        local menu = _G.GameMenuFrame
        if hooked or type(menu) ~= "table" or type(menu.Layout) ~= "function" then return end
        hooked = true
        hooksecurefunc(menu, "Layout", function(self)
            -- (The game's own height worked out again for each layout.)
            baseHeight = nil
            GameMenu.Place(self)
        end)
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function() GameMenu.Follow() end)
    GameMenu.Follow()
end
