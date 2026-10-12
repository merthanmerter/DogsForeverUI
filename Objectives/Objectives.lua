-- The quest tracker and quest rewards  (DogsForeverUI.Objectives, no settings)
--
-- The game's objective tracker in the addon's look, doing all it did: the
-- headers' strips replaced by a gold line fading out at the right, the
-- collapse buttons a flat gold minus/plus, the quest buttons smaller, no
-- dashes, item buttons and progress bars in the bars' look, and the Edit
-- Mode opacity background the frames' box. Text and the scenario, bonus and
-- world quest sections stay the game's. And reputation rows in quest rewards.
--
-- Secure post-hooks on each section's EndLayout go over what it laid out
-- (pooled, so each is done once, kept in weak tables). Nothing of the game's
-- is given a field or moved; its art is only hidden or faded (hidden where
-- the header's appear animation would fade it back in).

local Objectives = {}
DogsForeverUI.Objectives = Objectives

do -- private scope
    local Core = DogsForeverUI
    local Style = Core.Style
    local Faded, Get = Core.Fade, Core.Region
    local NONE = {}

    Objectives.POI_SCALE = 0.8     -- the quest buttons, of the game's size
    Objectives.FADE = 0.35         -- each header's line fades out over this share, at the right
    Objectives.SECTION_LINE = 0.45 -- a section header's hairline alpha
    Objectives.GLYPH = 10          -- the collapse buttons' minus and plus, wide
    Objectives.GLYPH_LINE = 2      -- and thick
    Objectives.GLYPH_OUTLINE = 1   -- the black round each stroke, to read on bright ground

    -- The player frame's name band: its gold line's alpha and its height.
    local NameBand = Core.Frames.UnitPlate.NameBand

    local skinned = setmetatable({}, { __mode = "k" })   -- game object -> done
    Objectives.parts = setmetatable({}, { __mode = "k" }) -- game object -> what was made for it

    local function OnePixelTall(region)
        if PixelUtil then PixelUtil.SetHeight(region, 1, 1) else region:SetHeight(1) end
    end

    ---------------------------------------------------------------------------
    -- Headers
    ---------------------------------------------------------------------------

    -- A line in two pieces - solid, then fading over the right FADE (a texture
    -- fades one way only). The header's own regions, under its title: a child
    -- frame would draw over the title.
    local function Pieces(header, sublevel, colour, alpha)
        local r, g, b = colour[1], colour[2], colour[3]
        local solid = header:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        solid:SetTexture(Style.FLAT_TEXTURE)
        solid:SetVertexColor(r, g, b, alpha)
        local fade = header:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        fade:SetTexture(Style.FLAT_TEXTURE)
        fade:SetGradient("HORIZONTAL", CreateColor(r, g, b, alpha), CreateColor(r, g, b, 0))
        return { solid = solid, fade = fade }
    end

    -- One real pixel tall along the header's foot, `y` up.
    local function LayOut(header, pieces, y)
        local width = header:GetWidth() or 0
        if width <= 0 then return end
        local fadeWidth = math.floor(width * Objectives.FADE + 0.5)
        local solid, fade = pieces.solid, pieces.fade
        solid:ClearAllPoints()
        solid:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, y)
        solid:SetWidth(width - fadeWidth)
        fade:ClearAllPoints()
        fade:SetPoint("LEFT", solid, "RIGHT", 0, 0)
        fade:SetWidth(fadeWidth)
        OnePixelTall(solid)
        OnePixelTall(fade)
    end

    -- The tracker's own header: the name band's gold line where the band's
    -- foot would be. A section's: a fainter hairline along its foot.
    local function Strip(header, isTitle)
        local look, height = NameBand()
        local alpha = isTitle and look.lineAlpha or Objectives.SECTION_LINE
        local strip = { line = Pieces(header, -1, Style.BORDER_COLOR, alpha) }
        function strip.Place()
            LayOut(header, strip.line, isTitle and ((header:GetHeight() or height) - height) / 2 or 2)
        end
        return strip
    end

    -- THE COLLAPSE BUTTON: the game's art at no opacity (it only swaps the
    -- atlas), a minus of the addon's over it, the plus's upright while
    -- collapsed; gold, white under the mouse, each stroke on a black one.
    local IDLE, HOVER = Style.GOLD, Style.TEXT_COLOR

    local function PaintGlyph(glyph)
        local c = glyph.hovered and HOVER or IDLE
        glyph.across:SetVertexColor(c[1], c[2], c[3], 1)
        glyph.upright:SetVertexColor(c[1], c[2], c[3], 1)
        local plus = glyph.collapsed and true or false
        glyph.upright:SetShown(plus)
        glyph.uprightOutline:SetShown(plus)
    end

    local function Bar(frame, width, height, sublevel, r, g, b)
        local bar = frame:CreateTexture(nil, "OVERLAY", nil, sublevel)
        bar:SetTexture(Style.FLAT_TEXTURE)
        if r then bar:SetVertexColor(r, g, b, 1) end
        bar:SetPoint("CENTER", frame, "CENTER", 0, 0)
        if PixelUtil then PixelUtil.SetSize(bar, width, height, 1, 1) else bar:SetSize(width, height) end
        return bar
    end

    local function SkinMinimize(button, collapsed)
        for _, state in ipairs({ "Normal", "Pushed", "Highlight" }) do
            Faded(Get(button, "Get" .. state .. "Texture", state .. "Texture"))
        end

        local frame = CreateFrame("Frame", nil, button)
        frame:SetAllPoints(button)
        local size, thick = Objectives.GLYPH, Objectives.GLYPH_LINE
        local o = Objectives.GLYPH_OUTLINE * 2
        local glyph = {
            frame = frame,
            acrossOutline = Bar(frame, size + o, thick + o, 1, 0, 0, 0),
            uprightOutline = Bar(frame, thick + o, size + o, 1, 0, 0, 0),
            across = Bar(frame, size, thick, 2),
            upright = Bar(frame, thick, size, 2),
            collapsed = collapsed,
        }
        button:HookScript("OnEnter", function() glyph.hovered = true; PaintGlyph(glyph) end)
        button:HookScript("OnLeave", function() glyph.hovered = false; PaintGlyph(glyph) end)
        PaintGlyph(glyph)
        return glyph
    end

    -- `collapsed`: what the header shows now; after that its SetCollapsed says.
    local function SkinHeader(header, isTitle, collapsed)
        if not header or skinned[header] then return end
        skinned[header] = true
        for _, key in ipairs({ "Background", "Glow", "Shine" }) do
            if header[key] then header[key]:Hide() end
        end

        local parts = { strip = Strip(header, isTitle) }
        parts.strip.Place()
        if header.MinimizeButton then parts.glyph = SkinMinimize(header.MinimizeButton, collapsed) end
        hooksecurefunc(header, "SetCollapsed", function(_, isCollapsed)
            if not parts.glyph then return end
            parts.glyph.collapsed = isCollapsed and true or false
            PaintGlyph(parts.glyph)
        end)
        Objectives.parts[header] = parts
    end

    ---------------------------------------------------------------------------
    -- What a section lays out
    ---------------------------------------------------------------------------

    local function SkinBlock(block)
        local poi = block.poiButton
        -- (A scale comes back as a 32-bit float: compared with room.)
        if poi and math.abs((poi:GetScale() or 1) - Objectives.POI_SCALE) > 0.001 then
            poi:SetScale(Objectives.POI_SCALE)
        end
        for _, line in pairs(block.usedLines or NONE) do Faded(line.Dash) end
    end

    -- An item button the game protects waits out combat: the look makes frames on it.
    local waiting = setmetatable({}, { __mode = "k" })

    local function SkinItemButton(button)
        if skinned[button] then return end
        if InCombatLockdown() and button:IsProtected() then
            waiting[button] = true
            return
        end
        skinned[button] = true
        waiting[button] = nil
        Core.Menus.ActionButtons.Skin(button)
    end

    -- Flat with the sheen, the dark background and the action buttons' thin
    -- border, in the game's colour.
    local function SkinProgressBar(progress)
        local bar = progress.Bar
        if not bar or skinned[bar] then return end
        skinned[bar] = true

        -- The skill-bar frame, and the navy behind it (its only other background region).
        for _, key in ipairs({ "BorderLeft", "BorderRight", "BorderMid" }) do Faded(bar[key]) end
        local fill = bar:GetStatusBarTexture()
        for _, region in ipairs({ bar:GetRegions() }) do
            if region ~= fill and region:GetDrawLayer() == "BACKGROUND" then Faded(region) end
        end

        local r, g, b, a = bar:GetStatusBarColor()
        Style.SetBarFill(bar)
        if r then bar:SetStatusBarColor(r, g, b, a or 1) end
        local sheen, shade = Style.MakeSheen(bar)

        local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints(bar)
        Style.SetBackground(bg)
        local Buttons = Core.Menus.ActionButtons
        local border = Style.AddBorder(bar, Buttons.BORDER, false, Buttons.BORDER_PIXELS)
        Objectives.parts[bar] = { sheen = sheen, shade = shade, bg = bg, border = border }
    end

    local ITEM_TEMPLATE = "QuestObjectiveItemButtonTemplate"

    local function SkinModule(module)
        for _, blocks in pairs(module.usedBlocks or NONE) do
            for _, block in pairs(blocks) do SkinBlock(block) end
        end
        for _, frame in pairs(module.usedRightEdgeFrames or NONE) do
            if frame.template == ITEM_TEMPLATE then SkinItemButton(frame) end
        end
        for _, progress in pairs(module.usedProgressBars or NONE) do SkinProgressBar(progress) end
    end

    ---------------------------------------------------------------------------
    -- THE BACKGROUND: Edit Mode's Opacity drives the frames' box (background,
    -- rounded border) instead of the game's nine-slice, which is kept at no
    -- opacity (a post-hook on SetBackgroundAlpha, its only writer). From the
    -- header to under the last section (only the header while collapsed),
    -- BOX_LEFT / BOX_RIGHT out from the sides. The tracker's child at its own
    -- level, under the sections.
    ---------------------------------------------------------------------------

    Objectives.BOX_LEFT, Objectives.BOX_RIGHT = 14, 8
    Objectives.BOX_BOTTOM = 0      -- from where the game's background ends

    local box

    local function Collapsed(frame) return frame:IsCollapsed() and true or false end

    local function PlaceBox()
        local tracker = _G.ObjectiveTrackerFrame
        if not (box and tracker) then return end
        local header, slice = tracker.Header, tracker.NineSlice
        box:ClearAllPoints()
        box:SetPoint("TOP", header or tracker, "TOP", 0, 0)
        box:SetPoint("LEFT", tracker, "LEFT", -Objectives.BOX_LEFT, 0)
        box:SetPoint("RIGHT", tracker, "RIGHT", Objectives.BOX_RIGHT, 0)
        if Collapsed(tracker) or not slice then
            box:SetPoint("BOTTOM", header or tracker, "BOTTOM", 0, 0)
        else
            box:SetPoint("BOTTOM", slice, "BOTTOM", 0, Objectives.BOX_BOTTOM)
        end
        box:SetFrameLevel(tracker:GetFrameLevel())
    end

    local function BackgroundAlpha(alpha)
        alpha = alpha or ObjectiveTrackerManager.backgroundAlpha or 0
        box:SetAlpha(math.max(0, math.min(1, alpha)))
    end

    local function BuildBox(tracker)
        box = CreateFrame("Frame", nil, tracker)
        local bg = box:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints(box)
        Style.SetBackground(bg)
        Objectives.box = { frame = box, bg = bg, border = Style.AddBorder(box) }

        Faded(tracker.NineSlice)
        hooksecurefunc(tracker, "SetBackgroundAlpha", function(_, alpha)
            Faded(tracker.NineSlice)
            BackgroundAlpha(alpha)
        end)
        hooksecurefunc(tracker, "SetCollapsed", PlaceBox)
        PlaceBox()
        BackgroundAlpha()
    end

    -- What the tracker draws, for the auto-hide's mouse test (Menus\Menus.lua):
    -- its frame runs far down the screen.
    function Objectives.HoverFrame() return box end

    -- EDIT MODE'S BOX is the tracker's whole tall frame: put round the
    -- addon's box instead, EDIT_PADDING out, never shorter than the header,
    -- by its TOPLEFT and BOTTOMRIGHT from the frame's corners (as Edit Mode's
    -- snapping reads them). The CLAMP goes with it, or a screen-tall frame
    -- could hardly be dragged (not in combat while a quest item protects it).
    Objectives.EDIT_PADDING = 2

    local function FitEditBox()
        local tracker = _G.ObjectiveTrackerFrame
        local selection = tracker and tracker.Selection
        if not (box and selection) then return end
        local header = tracker.Header or tracker
        local tl, tr, tt, tb = tracker:GetLeft(), tracker:GetRight(), tracker:GetTop(), tracker:GetBottom()
        local bl, br, bt, bb = box:GetLeft(), box:GetRight(), box:GetTop(), box:GetBottom()
        local hb = header:GetBottom()
        if not (tl and tr and tt and tb and bl and br and bt and bb and hb) then return end
        -- All in the tracker's units: the box is its child, never scaled.
        local border = Objectives.box.border
        local out = ((border and border.out) or Style.BORDER_INSET) + Objectives.EDIT_PADDING
        local dl, dr = bl - out - tl, br + out - tr
        local dt, db = bt + out - tt, math.min(bb, hb) - out - tb
        selection:ClearAllPoints()
        selection:SetPoint("TOPLEFT", tracker, "TOPLEFT", dl, dt)
        selection:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", dr, db)
        if not (InCombatLockdown() and tracker:IsProtected()) then
            tracker:SetClampRectInsets(dl, dr, dt, db)
        end
    end

    -- Fitted again after the game anchors it, when it shows, on any size
    -- change, and after the header moves (every update's end).
    local function HookEditBox(tracker)
        -- (The mixin's methods are the frame's own fields: hooked there.)
        for _, method in ipairs({ "AnchorSelectionFrame", "UpdateClampOffsets" }) do
            if type(rawget(tracker, method)) == "function" then hooksecurefunc(tracker, method, FitEditBox) end
        end
        if tracker.Selection then tracker.Selection:HookScript("OnShow", FitEditBox) end
        tracker:HookScript("OnSizeChanged", FitEditBox)
        box:SetScript("OnSizeChanged", FitEditBox)
        hooksecurefunc(tracker, "UpdateHeaderPosition", FitEditBox)
        FitEditBox()
    end

    ---------------------------------------------------------------------------
    -- THE PIN: the tracker's Auto-hide switch (fadeObjectives, Menus\Menus.lua)
    -- left of "All Objectives", in the room BOX_LEFT keeps. Pinned: in colour,
    -- always shown. Grey and faint: auto-hides. Painted on every auto-hide refresh.
    ---------------------------------------------------------------------------

    Objectives.PIN = 14         -- its size
    Objectives.PIN_X = -4       -- its centre, from the header's left
    Objectives.PIN_IDLE = 0.5   -- unpinned, away from the mouse

    local Menus = Core.Menus
    local pin

    local function Pinned() return not Menus.db.fadeObjectives end

    local function PaintPin()
        local pinned = Pinned()
        pin.icon:SetDesaturated(not pinned)
        pin:SetAlpha((pinned or pin.hovered) and 1 or Objectives.PIN_IDLE)
    end

    local function PinTooltip()
        GameTooltip:SetOwner(pin, "ANCHOR_LEFT")
        if Pinned() then
            GameTooltip:SetText("Pinned", 1, 1, 1)
            GameTooltip:AddLine("Always shown. Click to auto-hide.")
        else
            GameTooltip:SetText("Auto-hide", 1, 1, 1)
            GameTooltip:AddLine("Shown under the mouse. Click to pin.")
        end
        GameTooltip:Show()
    end

    local function BuildPin(header)
        pin = CreateFrame("Button", nil, header)
        pin:SetSize(Objectives.PIN, Objectives.PIN)
        pin:SetPoint("CENTER", header, "LEFT", Objectives.PIN_X, 0)
        pin.icon = pin:CreateTexture(nil, "ARTWORK")
        pin.icon:SetAllPoints(pin)
        pin.icon:SetAtlas("friendslist-recentallies-pin-yellow")
        pin:SetScript("OnClick", function()
            Menus.db.fadeObjectives = Pinned()
            Menus.Refresh()
            Core.RefreshOptions()
            PinTooltip()
        end)
        pin:SetScript("OnEnter", function() pin.hovered = true; PaintPin(); PinTooltip() end)
        pin:SetScript("OnLeave", function() pin.hovered = false; PaintPin(); GameTooltip:Hide() end)
        hooksecurefunc(Menus.ActionBars, "Refresh", PaintPin)
        PaintPin()
    end

    ---------------------------------------------------------------------------
    -- Finding the sections
    ---------------------------------------------------------------------------

    local hooked = setmetatable({}, { __mode = "k" })

    local function HookModule(module)
        if hooked[module] then return end
        hooked[module] = true
        SkinHeader(module.Header, false, Collapsed(module))
        hooksecurefunc(module, "EndLayout", SkinModule)
        SkinModule(module)
    end

    -- The tracker once it exists: its header, its sections, and each added later.
    local function Apply()
        local tracker = _G.ObjectiveTrackerFrame
        if not tracker then return end
        if not hooked[tracker] then
            hooked[tracker] = true
            SkinHeader(tracker.Header, true, Collapsed(tracker))
            BuildPin(tracker.Header)
            BuildBox(tracker)
            HookEditBox(tracker)
            hooksecurefunc(tracker, "AddModule", function(_, module) HookModule(module) end)
        end
        for _, module in ipairs(tracker.modules) do HookModule(module) end
        local parts = Objectives.parts[tracker.Header]
        if parts then parts.strip.Place() end
        PlaceBox()
        BackgroundAlpha()
        FitEditBox()
    end
    Objectives.Apply = Apply
    Apply()

    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event, name)
        if event == "PLAYER_REGEN_ENABLED" then
            for button in pairs(waiting) do SkinItemButton(button) end
        elseif event ~= "ADDON_LOADED" or name == "Blizzard_ObjectiveTracker" then
            Apply()
        end
    end)

    ---------------------------------------------------------------------------
    -- REPUTATION IN THE QUEST REWARDS: a row per faction, in the quest log,
    -- the quest window and the hand-in window, red for a loss. The game's own
    -- rows read only renown factions; GetQuestLogRewardFactionInfo (after
    -- ProcessQuestLogRewardFactions) still has Classic's, in hundredths, for
    -- the log's selected quest. A post-hook on QuestInfo_Display
    -- (QuestInfo_ShowRewards sits in the template tables, unhookable) adds
    -- rows from the game's reputation template after the last reward and
    -- grows the panel; its height is all of the game's that is written.
    ---------------------------------------------------------------------------

    local REP_ICON = "Interface\\Icons\\Achievement_Reputation_01"
    -- The game's REWARDS_ROW_OFFSET and REWARDS_SECTION_OFFSET (locals of QuestInfo.lua).
    local ROW_OFFSET, SECTION_OFFSET = 2, 5

    local repRows = {}          -- panel -> its rows

    -- Each faction the selected quest gives reputation with, the amount whole
    -- as the server gives it (37.5 is 37); one with no name left out.
    local function Rewards()
        local list = {}
        for i = 1, GetNumQuestLogRewardFactions() do
            local factionID, amount = GetQuestLogRewardFactionInfo(i)
            local faction = factionID and C_Reputation.GetFactionDataByID(factionID)
            amount = amount and (amount < 0 and math.ceil(amount / 100) or math.floor(amount / 100))
            if faction and faction.name and amount and amount ~= 0 then
                list[#list + 1] = { factionID = factionID, name = faction.name, amount = amount }
            end
        end
        return list
    end

    -- The quest handed in is in the log: selected for the read, then the
    -- selection put back (as the game's Abandon does). An offered quest has none.
    local function HandInRewards()
        local questID = GetQuestID()
        if not C_QuestLog.GetLogIndexForQuestID(questID) then return {} end
        local selected = C_QuestLog.GetSelectedQuest()
        C_QuestLog.SetSelectedQuest(questID)
        ProcessQuestLogRewardFactions()
        local list = Rewards()
        C_QuestLog.SetSelectedQuest(selected)
        return list
    end

    -- The map's small rows or the windows' large ones, as wide as the
    -- panel's item rewards, so the right-hand column lines up.
    local function RepRow(panel, i)
        repRows[panel] = repRows[panel] or {}
        local row = repRows[panel][i]
        if not row then
            local template = panel == MapQuestInfoRewardsFrame and "SmallQuestInfoRewardReputationTemplate"
                or "LargeQuestInfoRewardReputationTemplate"
            row = CreateFrame("Button", nil, panel, template)
            row:SetSize(panel.RewardButtons[1]:GetSize())
            row.Icon:SetTexture(REP_ICON)
            repRows[panel][i] = row
        end
        return row
    end

    -- `read` answers the rewards, asked only while the panel shows.
    local function PlaceRewards(panel, template, read)
        local shown = 0
        local elements = read and panel:IsShown() and panel.activeRewardElements
        if elements and #elements > 0 then
            -- In the items' section, two to a row as the game's (beside a lone
            -- item); after anything else, a section of its own. `left` starts
            -- the last reward's row.
            local last = elements[#elements]
            local _, rowStart, relativePoint = last:GetPoint(1)
            local inItems = last.type == "reward"
            local left, free = last, inItems
            if relativePoint == "TOPRIGHT" then left, free = rowStart, false end

            local gap, height = template.horizontalRewardSeparation or 1, panel:GetHeight()
            local spacing = inItems and ROW_OFFSET or SECTION_OFFSET
            for _, reward in ipairs(read()) do
                shown = shown + 1
                local row = RepRow(panel, shown)
                -- The fields the template's tooltip reads (QuestInfoReputationRewardButtonMixin).
                row.factionID, row.factionName, row.rewardAmount = reward.factionID, reward.name, reward.amount
                row.Name:SetText(QUEST_REPUTATION_REWARD_TITLE:format(reward.name))
                row.RewardAmount:SetText(reward.amount)
                row.RewardAmount:SetTextColor((reward.amount < 0 and RED_FONT_COLOR or HIGHLIGHT_FONT_COLOR):GetRGB())
                row:ClearAllPoints()
                if free then
                    row:SetPoint("TOPLEFT", left, "TOPRIGHT", gap, 0)
                else
                    row:SetPoint("TOPLEFT", left, "BOTTOMLEFT", 0, -spacing)
                    height = height + row:GetHeight() + spacing
                    left, spacing = row, ROW_OFFSET
                end
                free = not free
                row:Show()
            end
            if shown > 0 then panel:SetHeight(height) end
        end
        local made = repRows[panel] or NONE
        for i = shown + 1, #made do made[i]:Hide() end
    end

    hooksecurefunc("QuestInfo_Display", function(template)
        local read = template.questLog and Rewards or template == QUEST_TEMPLATE_REWARD and HandInRewards or nil
        PlaceRewards(QuestInfoFrame.rewardsFrame, template, read)
    end)
end
