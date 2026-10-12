-- THE QUEST TRACKER  (DogsForeverUI.Objectives)
--
-- The game's objective tracker (Blizzard_ObjectiveTracker) in the addon's
-- look, quieter: the same tracker doing everything it did - collapsing,
-- clicking a quest open, the right-click menu, super-tracking from the quest
-- buttons, quest items, sorting, Edit Mode - only drawn with less. No setting
-- and no command; it is the look.
--
-- WHAT CHANGES:
--
--   * "All Objectives", the tracker's own header: the game's bronze strip
--     gone, and in its place only the gold line of the player frame's NAME
--     BAND (UnitPlate.NAME_BAND's line alpha) under the title, solid, then
--     fading out over the right end (FADE). No black behind it;
--   * each section's header ("Quests", "Achievements"...): its strip, glow and
--     shine gone, only a fainter gold hairline under the title, fading out
--     the same way;
--   * the collapse buttons: the game's red and yellow squares become a flat
--     gold minus outlined in black, a plus while collapsed, white under the
--     mouse - the same buttons, the same clicks;
--   * the quest buttons left of each title (the "?" and "..." that
--     super-track a quest) kept exactly as they are - their art says whether
--     a quest is done and which one is followed - only smaller (POI_SCALE);
--   * no dash before the objectives: the lines keep the dash's indent, so
--     they still sit in under their quest's title;
--   * quest item buttons in the action buttons' look (ActionButtons.Skin):
--     the thin border, the dark slot, the icon trimmed, flat pressed and
--     hover states. Their range dot, count, cooldown and "in the area" glow
--     are the game's still;
--   * progress bars flat with the bars' sheen, the dark background and the
--     action buttons' thin border instead of the skill-bar frame, in the
--     game's own colour;
--   * the background Edit Mode's Opacity setting gives the tracker: the
--     frames' own box and rounded border instead of the game's nine-slice
--     (see THE BACKGROUND).
--
-- Left as the game draws them: the text, its fonts and colours (quest level
-- and difficulty colour included), and everything inside the scenario, bonus
-- and world quest sections.
--
-- "Objectives" is also one of the Auto-hide switches (Menus\ActionBars.lua),
-- with a pin for it left of "All Objectives" (THE PIN).
--
-- HOW. Each section of the tracker lays itself out in its own EndLayout; a
-- secure post-hook on it (hooksecurefunc - it cannot taint the game's code)
-- goes over what that layout uses: the header, every block's quest button
-- and lines, the item buttons and the progress bars. The game pools all of
-- these and hands them round, so each is done once (kept in weak tables on
-- the addon's side) and the cheap parts - the quest button's size, a dash's
-- opacity - checked again each time. The collapse state comes from a
-- post-hook on each header's SetCollapsed.
--
-- Nothing of the game's is given a field, has a script replaced or is moved;
-- its layout values (spacing, offsets) are never written. The game's art is
-- only hidden or faded, its textures given other looks, and regions and
-- frames of the addon's added. The game never sets these regions' opacity
-- or shows the strips again (checked across Blizzard_ObjectiveTracker); the
-- header's appear animation fades the strip in, which is why the strip is
-- hidden rather than faded.

local Objectives = {}
DogsForeverUI.Objectives = Objectives

do -- private scope

    local Style = DogsForeverUI.Style

    Objectives.POI_SCALE = 0.8     -- the quest buttons, of the game's size
    Objectives.FADE = 0.35         -- each header's band and line fade out over this share, at the right
    Objectives.SECTION_LINE = 0.45 -- a section header's hairline, against the name band's gold line
    Objectives.GLYPH = 10          -- the collapse buttons' minus and plus, wide
    Objectives.GLYPH_LINE = 2      -- and thick
    Objectives.GLYPH_OUTLINE = 1   -- the black round each stroke, so it reads on bright ground

    -- The player frame's name band (UnitPlate.NAME_BAND: the black's and the
    -- gold line's alpha) and height (UnitPlate.TopRoom).
    local NameBand = DogsForeverUI.Frames.UnitPlate.NameBand

    local skinned = setmetatable({}, { __mode = "k" })   -- game object -> done
    Objectives.parts = setmetatable({}, { __mode = "k" }) -- game object -> what was made for it

    local function Hidden(region)
        if type(region) == "table" and type(region.Hide) == "function" then
            pcall(region.Hide, region)
        end
    end

    local Faded, Get = DogsForeverUI.Fade, DogsForeverUI.Region

    local function OnePixelTall(region)
        if PixelUtil and PixelUtil.SetHeight then
            PixelUtil.SetHeight(region, 1, 1)
        else
            region:SetHeight(1)
        end
    end

    ---------------------------------------------------------------------------
    -- THE HEADERS
    ---------------------------------------------------------------------------

    -- A strip in two pieces along `header` - solid, then fading to nothing
    -- over the right FADE of its width (a texture fades one way only).
    -- Drawn as the header's own regions, under its title: a frame of the
    -- addon's would be a child, and a child is drawn over all of its
    -- parent's regions, the title included.
    local function Pieces(header, sublevel, colour, alpha)
        local r, g, b = colour[1], colour[2], colour[3]
        local solid = header:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        solid:SetTexture(Style.FLAT_TEXTURE)
        solid:SetVertexColor(r, g, b, alpha)
        local fade = header:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        fade:SetTexture(Style.FLAT_TEXTURE)
        if fade.SetGradient and CreateColor then
            fade:SetGradient("HORIZONTAL", CreateColor(r, g, b, alpha), CreateColor(r, g, b, 0))
        else
            fade:SetVertexColor(r, g, b, alpha / 2)
        end
        return { solid = solid, fade = fade }
    end

    -- The two pieces laid along the header's width. `point` is where the
    -- strip sits (LEFT for the band, BOTTOMLEFT for a hairline), `y` its
    -- offset; the height is the band's, or one real pixel for a line.
    local function LayOut(header, pieces, point, y, height)
        local width = header:GetWidth() or 0
        if width <= 0 then return end
        local fadeWidth = math.floor(width * Objectives.FADE + 0.5)
        local solid, fade = pieces.solid, pieces.fade
        solid:ClearAllPoints()
        solid:SetPoint(point, header, point, 0, y)
        solid:SetWidth(width - fadeWidth)
        fade:ClearAllPoints()
        fade:SetPoint("LEFT", solid, "RIGHT", 0, 0)
        fade:SetWidth(fadeWidth)
        if height then
            solid:SetHeight(height)
            fade:SetHeight(height)
        else
            OnePixelTall(solid)
            OnePixelTall(fade)
        end
    end

    -- The tracker's own header: the name band's gold line, where the band's
    -- foot would be - no black behind the title (the player had it taken
    -- out, 2026-10-01).
    local function TitleStrip(header)
        local look, height = NameBand()
        local strip = { line = Pieces(header, -1, Style.BORDER_COLOR, look.lineAlpha) }
        function strip.Place()
            -- The band's height, centred on the header: its foot.
            local foot = ((header:GetHeight() or height) - height) / 2
            LayOut(header, strip.line, "BOTTOMLEFT", foot, nil)
        end
        return strip
    end

    -- A section's header: the hairline only, along its foot.
    local function SectionStrip(header)
        local strip = { line = Pieces(header, -1, Style.BORDER_COLOR, Objectives.SECTION_LINE) }
        function strip.Place()
            LayOut(header, strip.line, "BOTTOMLEFT", 2, nil)
        end
        return strip
    end

    -- THE COLLAPSE BUTTON: the game's art at no opacity (it only ever swaps
    -- the atlas, in SetCollapsed), and a minus of the addon's over it, with
    -- the plus's upright while collapsed. Gold, white under the mouse, each
    -- stroke on a black one GLYPH_OUTLINE larger all round: the muted border
    -- gold and one pixel were lost against the world (the player, 2026-10-01).
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
        if PixelUtil and PixelUtil.SetSize then
            PixelUtil.SetSize(bar, width, height, 1, 1)
        else
            bar:SetSize(width, height)
        end
        return bar
    end

    local function SkinMinimize(button, collapsed)
        Faded(Get(button, "GetNormalTexture", "NormalTexture"))
        Faded(Get(button, "GetPushedTexture", "PushedTexture"))
        Faded(Get(button, "GetHighlightTexture", "HighlightTexture"))

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

    -- `collapsed`: what the header shows now (the game set it before the
    -- hook went on); after that its SetCollapsed says.
    local function SkinHeader(header, isTitle, collapsed)
        if type(header) ~= "table" or skinned[header] then return end
        skinned[header] = true
        Hidden(header.Background)
        Hidden(header.Glow)
        Hidden(header.Shine)

        local parts = { strip = isTitle and TitleStrip(header) or SectionStrip(header) }
        parts.strip.Place()
        if type(header.MinimizeButton) == "table" then
            parts.glyph = SkinMinimize(header.MinimizeButton, collapsed)
        end
        if type(header.SetCollapsed) == "function" then
            hooksecurefunc(header, "SetCollapsed", function(_, isCollapsed)
                if parts.glyph then
                    parts.glyph.collapsed = isCollapsed and true or false
                    PaintGlyph(parts.glyph)
                end
            end)
        end
        Objectives.parts[header] = parts
    end

    ---------------------------------------------------------------------------
    -- WHAT A SECTION LAYS OUT
    ---------------------------------------------------------------------------

    local function SkinBlock(block)
        local poi = block.poiButton
        if type(poi) == "table" and type(poi.SetScale) == "function" then
            -- (A scale comes back as a 32-bit float: compared with room.)
            local scale = poi:GetScale() or 1
            if math.abs(scale - Objectives.POI_SCALE) > 0.001 then poi:SetScale(Objectives.POI_SCALE) end
        end
        if type(block.usedLines) == "table" then
            for _, line in pairs(block.usedLines) do
                if type(line) == "table" then Faded(line.Dash) end
            end
        end
    end

    -- An item button made in combat waits for the end of it if the game ever
    -- protects it: the look makes frames on it and moves its icon.
    local waiting = setmetatable({}, { __mode = "k" })

    local function SkinItemButton(button)
        if skinned[button] then return end
        local Buttons = DogsForeverUI.Menus and DogsForeverUI.Menus.ActionButtons
        if not (Buttons and Buttons.Skin) then return end
        if InCombatLockdown() and type(button.IsProtected) == "function" and button:IsProtected() then
            waiting[button] = true
            return
        end
        skinned[button] = true
        waiting[button] = nil
        Buttons.Skin(button)
    end

    local function SkinProgressBar(progress)
        local bar = type(progress) == "table" and progress.Bar
        if type(bar) ~= "table" or skinned[bar] then return end
        if type(bar.GetStatusBarTexture) ~= "function" then return end
        skinned[bar] = true

        -- The skill-bar frame round it and the navy behind it (an unnamed
        -- texture: the bar's only background region other than its fill).
        Faded(bar.BorderLeft)
        Faded(bar.BorderRight)
        Faded(bar.BorderMid)
        local fill = bar:GetStatusBarTexture()
        for _, region in ipairs({ bar:GetRegions() }) do
            if region ~= fill and type(region.GetDrawLayer) == "function"
                and region:GetDrawLayer() == "BACKGROUND" then
                Faded(region)
            end
        end

        -- The game's colour, on the flat fill with the sheen.
        local r, g, b, a = bar:GetStatusBarColor()
        Style.SetBarFill(bar)
        if r then bar:SetStatusBarColor(r, g, b, a or 1) end
        local sheen, shade = Style.MakeSheen(bar)

        local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints(bar)
        Style.SetBackground(bg)
        local Buttons = DogsForeverUI.Menus and DogsForeverUI.Menus.ActionButtons
        local border = Style.AddBorder(bar, Buttons and Buttons.BORDER, false,
            Buttons and Buttons.BORDER_PIXELS or 1)
        Objectives.parts[bar] = { sheen = sheen, shade = shade, bg = bg, border = border }
    end

    local ITEM_TEMPLATE = "QuestObjectiveItemButtonTemplate"

    -- One section after its layout.
    local function SkinModule(module)
        if type(module) ~= "table" then return end
        if type(module.usedBlocks) == "table" then
            for _, blocks in pairs(module.usedBlocks) do
                if type(blocks) == "table" then
                    for _, block in pairs(blocks) do
                        if type(block) == "table" then SkinBlock(block) end
                    end
                end
            end
        end
        if type(module.usedRightEdgeFrames) == "table" then
            for _, frame in pairs(module.usedRightEdgeFrames) do
                if type(frame) == "table" and frame.template == ITEM_TEMPLATE then
                    SkinItemButton(frame)
                end
            end
        end
        if type(module.usedProgressBars) == "table" then
            for _, progress in pairs(module.usedProgressBars) do SkinProgressBar(progress) end
        end
    end

    ---------------------------------------------------------------------------
    -- THE BACKGROUND
    ---------------------------------------------------------------------------

    -- Edit Mode's Opacity setting gives the tracker a background: the game's
    -- nine-slice (container.NineSlice, "common-opacity-background"), hung 30
    -- out on the left for retail's quest buttons and down to 10 under the
    -- last section - at full opacity a dark slab with its own corners, out of
    -- line with everything else (the player, 2026-10-01). It is kept at no
    -- opacity, and the setting drives the addon's box instead: the frames'
    -- background and border (Style.BACKGROUND_COLOR, Style.DEFAULT_BORDER,
    -- rounded corners and all), from the tracker's header to under its last
    -- section - only round the header while the tracker is collapsed - and
    -- BOX_LEFT / BOX_RIGHT out from the tracker's sides, so the quest buttons
    -- and the collapse buttons sit inside with room round them. Its opacity
    -- is the setting's, so at 0 nothing shows, as before.
    --
    -- The game writes the nine-slice's opacity in SetBackgroundAlpha (its only
    -- writer); a post-hook fades it again after and passes the value on.
    -- The box is the tracker's child at the tracker's own frame level, under
    -- the sections (one level up), as the nine-slice was.
    Objectives.BOX_LEFT, Objectives.BOX_RIGHT = 14, 8
    Objectives.BOX_BOTTOM = 0      -- from where the game's background ends

    local box

    local function Collapsed(frame)
        if type(frame) == "table" and type(frame.IsCollapsed) == "function" then
            local ok, collapsed = pcall(frame.IsCollapsed, frame)
            return ok and collapsed and true or false
        end
        return false
    end

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
        if not box then return end
        local manager = _G.ObjectiveTrackerManager
        if type(alpha) ~= "number" then
            alpha = type(manager) == "table" and tonumber(manager.backgroundAlpha) or 0
        end
        box:SetAlpha(math.max(0, math.min(1, alpha)))
    end

    local function BuildBox(tracker)
        box = CreateFrame("Frame", nil, tracker)
        local bg = box:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints(box)
        Style.SetBackground(bg)
        local border = Style.AddBorder(box)
        Objectives.box = { frame = box, bg = bg, border = border }

        Faded(tracker.NineSlice)
        if type(tracker.SetBackgroundAlpha) == "function" then
            hooksecurefunc(tracker, "SetBackgroundAlpha", function(_, alpha)
                Faded(tracker.NineSlice)
                BackgroundAlpha(alpha)
            end)
        end
        if type(tracker.SetCollapsed) == "function" then
            hooksecurefunc(tracker, "SetCollapsed", PlaceBox)
        end
        PlaceBox()
        BackgroundAlpha()
    end

    -- What the tracker draws, for the auto-hide's mouse test (ActionBars.lua):
    -- its frame runs far down the screen in its default place.
    function Objectives.HoverFrame() return box end

    -- EDIT MODE'S BOX. The game's (EditModeObjectiveTrackerSystemMixin:
    -- AnchorSelectionFrame) is the tracker's whole frame, 30 out on the left
    -- for retail's quest buttons - and the frame runs down to the bottom of
    -- the free room in its default place, or as tall as Edit Mode's Height
    -- setting once moved: a tall box round a short list (the player,
    -- 2026-10-01). Edit Mode lets a system's box sit inside its frame,
    -- anchored by its TOPLEFT and BOTTOMRIGHT from the frame's own corners
    -- (the unit frames', castbar's and auras' systems do; Edit Mode's
    -- snapping reads those two points' offsets), so it is put round the
    -- addon's box with its border, EDIT_PADDING out - never shorter than the
    -- header. Fitted again after the game anchors it, when it shows, and
    -- whenever the tracker or the box changes size. The Height setting still
    -- limits how much the tracker shows.
    --
    -- The tracker's CLAMP goes with the box (2026-10-02, the raid frames'
    -- bug, Frames\RaidFrames.lua): Edit Mode keeps every system on screen by
    -- its clamp rect, which was still the whole tall frame - so a tracker
    -- whose frame is about the screen's height could hardly be dragged up or
    -- down. Fitted as UpdateClampOffsets would fit it to this box, also after
    -- the game works it out again. (Not in combat while the tracker is
    -- protected - a quest item's secure button makes it so - the next update
    -- after combat fits it.)
    Objectives.EDIT_PADDING = 2

    local function FitEditBox()
        local tracker = _G.ObjectiveTrackerFrame
        local selection = tracker and tracker.Selection
        if not (box and selection and type(selection.SetPoint) == "function") then return end
        local header = tracker.Header or tracker
        local tl, tr, tt, tb = tracker:GetLeft(), tracker:GetRight(), tracker:GetTop(), tracker:GetBottom()
        local bl, br, bt, bb = box:GetLeft(), box:GetRight(), box:GetTop(), box:GetBottom()
        local hb = header:GetBottom()
        if not (tl and tr and tt and tb and bl and br and bt and bb and hb) then return end
        -- All in the tracker's units: the box is its child, never scaled.
        local border = Objectives.box and Objectives.box.border
        local out = ((border and border.out) or Style.BORDER_INSET) + Objectives.EDIT_PADDING
        local bottom = math.min(bb, hb)
        local dl, dr = bl - out - tl, br + out - tr
        local dt, db = bt + out - tt, bottom - out - tb
        selection:ClearAllPoints()
        selection:SetPoint("TOPLEFT", tracker, "TOPLEFT", dl, dt)
        selection:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", dr, db)
        if type(tracker.SetClampRectInsets) == "function"
           and not (InCombatLockdown() and tracker:IsProtected()) then
            tracker:SetClampRectInsets(dl, dr, dt, db)
        end
    end

    local function HookEditBox(tracker)
        -- (The mixin's methods are the frame's own fields: hooked there,
        -- never added to it.)
        for _, method in ipairs({ "AnchorSelectionFrame", "UpdateClampOffsets" }) do
            if type(rawget(tracker, method)) == "function" then hooksecurefunc(tracker, method, FitEditBox) end
        end
        if type(tracker.Selection) == "table" and type(tracker.Selection.HookScript) == "function" then
            tracker.Selection:HookScript("OnShow", FitEditBox)
        end
        if type(tracker.HookScript) == "function" then
            tracker:HookScript("OnSizeChanged", FitEditBox)
        end
        box:SetScript("OnSizeChanged", FitEditBox)
        -- The header (and the box's top with it) moves down for what sits
        -- above it, at the end of every update.
        if type(tracker.UpdateHeaderPosition) == "function" then
            hooksecurefunc(tracker, "UpdateHeaderPosition", FitEditBox)
        end
        FitEditBox()
    end

    ---------------------------------------------------------------------------
    -- THE PIN
    ---------------------------------------------------------------------------

    -- The tracker's Auto-hide switch (fadeObjectives, Menus\ActionBars.lua)
    -- at hand, left of "All Objectives" in the room the box keeps there
    -- (BOX_LEFT) - the title is not moved (the player, 2026-10-04). Pinned,
    -- in its colour: the tracker stays shown. Grey and faint until the mouse
    -- is on it: the tracker auto-hides. Painted again whenever the auto-hide
    -- is refreshed, which every way of changing a setting ends in.
    Objectives.PIN = 14         -- the pin's size
    Objectives.PIN_X = -4       -- its centre, from the header's left (the title starts at 7)
    Objectives.PIN_IDLE = 0.5   -- an unpinned pin's opacity, away from the mouse

    local Menus = DogsForeverUI.Menus
    local pin

    local function Pinned()
        return not (Menus.db and Menus.db.fadeObjectives)
    end

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
            DogsForeverUI.RefreshOptions()
            PinTooltip()
        end)
        pin:SetScript("OnEnter", function() pin.hovered = true; PaintPin(); PinTooltip() end)
        pin:SetScript("OnLeave", function() pin.hovered = false; PaintPin(); GameTooltip:Hide() end)
        hooksecurefunc(Menus.ActionBars, "Refresh", PaintPin)
        PaintPin()
    end

    ---------------------------------------------------------------------------
    -- FINDING THE SECTIONS
    ---------------------------------------------------------------------------

    local hooked = setmetatable({}, { __mode = "k" })

    local function HookModule(module)
        if type(module) ~= "table" or hooked[module] then return end
        if type(module.EndLayout) ~= "function" then return end
        hooked[module] = true
        SkinHeader(module.Header, false, Collapsed(module))
        hooksecurefunc(module, "EndLayout", SkinModule)
        SkinModule(module)
    end

    -- The tracker, once it exists: its own header, every section it has, and
    -- each section added to it later (the game adds them when the world is
    -- first entered).
    local function Apply()
        local tracker = _G.ObjectiveTrackerFrame
        if type(tracker) ~= "table" then return end
        if not hooked[tracker] then
            hooked[tracker] = true
            SkinHeader(tracker.Header, true, Collapsed(tracker))
            BuildPin(tracker.Header)
            BuildBox(tracker)
            HookEditBox(tracker)
            if type(tracker.AddModule) == "function" then
                hooksecurefunc(tracker, "AddModule", function(_, module) HookModule(module) end)
            end
        end
        if type(tracker.modules) == "table" then
            for _, module in ipairs(tracker.modules) do HookModule(module) end
        end
        local parts = Objectives.parts[tracker.Header]
        if parts then parts.strip.Place() end
        PlaceBox()
        BackgroundAlpha()
        FitEditBox()
    end
    Objectives.Apply = Apply
    Apply()

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:SetScript("OnEvent", function(_, event, name)
        if event == "PLAYER_REGEN_ENABLED" then
            for button in pairs(waiting) do SkinItemButton(button) end
            return
        end
        if event == "ADDON_LOADED" and name ~= "Blizzard_ObjectiveTracker" then return end
        Apply()
    end)
end
