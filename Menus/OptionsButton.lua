-- The way into the addon's options: a button of its own at the end of the
-- micro menu, with the addon's icon, that opens and shuts the options window
-- (Options\Panel.lua). There is no other way in - no slash command, no entry
-- under the game's Settings.
--
-- Made like the bag button (BagsBar.lua): a child of MicroMenu with no
-- layoutIndex, so the game's own layout never counts it; it takes the menu's
-- scale and fade, wears the micro buttons' look (MicroMenu.lua), and the
-- addon's row puts it last. Lit, as a micro button is while its window is
-- open, while the options window is.

local OptionsButton = {}
DogsForeverUI.Menus.OptionsButton = OptionsButton

do -- private scope

    local NS = DogsForeverUI.Menus
    local Core = DogsForeverUI

    -- The addon's own icon (the .toc's IconTexture), whole: it has no baked-in
    -- edge to trim.
    OptionsButton.ICON = { file = Core.MEDIA .. "icon", own = true, crop = 0 }

    local function IsOpen()
        return Core.Options ~= nil and Core.Options.IsShown()
    end

    local function ShowTooltip(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(Core.TITLE, 1, 1, 1)
        GameTooltip:AddLine("Settings, sizes, positions and profiles.")
        GameTooltip:Show()
    end

    function OptionsButton:Apply()
        if self.button or not _G.MicroMenu then return end
        local button = CreateFrame("Button", "DogsForeverUIOptionsButton", _G.MicroMenu)
        button:SetSize(NS.MicroMenu.SQUARE, NS.MicroMenu.SQUARE)
        button:RegisterForClicks("AnyUp")
        button:SetScript("OnClick", function() Core.Options.Toggle() end)
        button:SetScript("OnEnter", ShowTooltip)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        NS.MicroMenu.Skin(button, { OptionsButton.ICON }, IsOpen)
        self.button = button
    end
end
