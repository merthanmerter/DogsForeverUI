-- ADDON BUTTONS  (DogsForeverUI.Minimap.Buttons)
--
-- Other addons' minimap buttons, taken off the map's edge and kept in a
-- drawer beside the map, behind a HANDLE on the map's side: the game's own
-- gold collapse and expand arrow (the buff frame's and the bag bar's), just
-- off the map's border at its bottom corner, facing the middle of the screen. It
-- points where a click moves the drawer. A click on the handle slides the
-- drawer out of it, another click (or a
-- click anywhere else, or Esc) closes it. The handle and the drawer belong to
-- the map's side alone, so wherever Edit Mode puts the title - on top or
-- underneath - they stay where they are. No setting and no command: when no
-- addon has a button, there is no handle.
--
-- THE LOOK: the drawer is a dark panel in the map's border, and each button
-- sits in a slot drawn like an action button (the
-- thin bevelled gold line, the dark square behind) with its picture square
-- and filling the slot - the round ring and the round backing every
-- LibDBIcon button wears are faded, its round hover glow made the action
-- buttons' flat light.
--
-- WHICH BUTTONS. Every button the LibDBIcon library made (most addons'),
-- and every other one an addon put on the minimap's edge itself: a named
-- frame on the map (or its backdrop) that an addon made - never Blizzard's,
-- which the game knows as secure (issecurevariable) - that can be clicked,
-- is button sized and sits out on the edge rather than inside the map, and
-- is not named like a map pin (gathering nodes, notes, quest markers).
-- Protected frames are left alone. They are looked for at login, after each
-- addon loads, when LibDBIcon says it made one, and every SCAN seconds.
--
-- KEPT IN: an addon may place its button on the map again (LibDBIcon does
-- whenever it refreshes, and at every step of a drag), so each button is
-- put back into its slot right after (a post-hook on its SetPoint and
-- SetParent). One the addon hides (its "hide minimap button" option) leaves
-- the drawer; shown again, it comes back.
--
-- THE GAME'S ADDONS MENU comes into the drawer too, and the game's own
-- AddOns button is put away (see below); nothing else of Blizzard's is touched. The
-- other addons' buttons are moved, sized and restyled - that is the point -
-- but given no field.

local Buttons = {}
DogsForeverUI.Minimap.Buttons = Buttons

do -- private scope

    local Style = DogsForeverUI.Style
    local MinimapLook = DogsForeverUI.Minimap
    local Look = DogsForeverUI.Menus.ActionButtons     -- the action buttons' look

    Buttons.SLOT = 28              -- a slot, border included
    Buttons.INSET = 3              -- the slot's border room, and the gap between slots
    Buttons.COLUMNS = 6
    Buttons.PAD = 4                -- inside the drawer, round the slots
    Buttons.GAP = 6                -- daylight between the handle's border and the drawer's
    -- The handle: the game's own collapse and expand arrow - the gold
    -- "bag-arrow" the buff frame's and the bag bar's toggles wear - at their
    -- sizes (a 15x30 button, the arrow 10x16), HANDLE_GAP of daylight from
    -- the map's border.
    Buttons.ARROW = "bag-arrow"
    Buttons.HANDLE_WIDTH, Buttons.HANDLE_HEIGHT = 15, 30
    Buttons.ARROW_WIDTH, Buttons.ARROW_HEIGHT = 10, 16
    Buttons.HANDLE_GAP = 2
    Buttons.HIGHLIGHT_ALPHA = 0.4  -- the game's
    Buttons.PUSHED_OFFSET = 1      -- the arrow nudged while pressed
    Buttons.SCAN = 2               -- seconds between looks for new buttons,
    Buttons.SCANS = 5              -- this many after an addon loads or a login
    Buttons.STRATA = "MEDIUM"      -- LibDBIcon's own
    Buttons.EDGE = 0.75            -- out from the map's centre, of its half width
    Buttons.MIN_SIZE, Buttons.MAX_SIZE = 14, 48
    Buttons.NAME = "DogsForeverUIAddonButtons"

    local ADDON = "DogsForeverUI"
    local PUSHED = { 0, 0, 0, 0.35 }

    -- The round art of a minimap button (LibDBIcon's, and every button made
    -- to look like one): the ring, the backing and the round hover glow - by
    -- file ID, as the game reports a texture set from a path, and by path.
    Buttons.ART = {
        [136430] = true, [136467] = true, [136477] = true,
        ["interface\\minimap\\minimap-trackingborder"] = true,
        ["interface\\minimap\\ui-minimap-background"] = true,
        ["interface\\minimap\\ui-minimap-zoombutton-highlight"] = true,
    }

    -- Frames other addons put on the map that are not buttons: map pins.
    Buttons.NOT_BUTTONS = {
        "^GatherMate", "^GatherNote", "^HandyNotes", "^QuestieFrame", "^HBD",
        "^Routes", "^TTMinimapButton", "Pin%d*$", "POI", "Note%d+$", "Node%d+$", "Arrow",
    }

    local drawer, handle, border
    local open = false
    local collected = setmetatable({}, { __mode = "k" })   -- button -> its entry
    local list = {}                                         -- the entries, in order
    Buttons.list = list

    function Buttons.Has(frame) return collected[frame] ~= nil end
    function Buttons.IsOpen() return open end

    ---------------------------------------------------------------------------
    -- FINDING THEM
    ---------------------------------------------------------------------------

    local function Named(frame)
        local name = type(frame.GetName) == "function" and frame:GetName()
        return type(name) == "string" and name or nil
    end

    local function Kind(region)
        if type(region) ~= "table" or type(region.GetObjectType) ~= "function" then return nil end
        return region:GetObjectType()
    end

    local function LibDBIcon()
        local stub = _G.LibStub
        if type(stub) ~= "table" and type(stub) ~= "function" then return nil end
        local ok, lib = pcall(stub, "LibDBIcon-1.0", true)
        if ok and type(lib) == "table" then return lib end
    end

    -- The addon that made the global `name`, or nil for the game's own.
    local function Owner(name)
        if type(issecurevariable) ~= "function" then return nil end
        local ok, secure, taint = pcall(issecurevariable, name)
        if not ok or secure then return nil end
        return taint or "?"
    end

    local function Clickable(frame)
        if Kind(frame) == "Button" then return true end
        local ok, script = pcall(frame.GetScript, frame, "OnMouseUp")
        return ok and script ~= nil
    end

    local function OnTheEdge(frame, map)
        local x, y = frame:GetCenter()
        local mx, my = map:GetCenter()
        if not (x and y and mx and my) then return false end
        local fs, ms = frame:GetEffectiveScale(), map:GetEffectiveScale()
        local dx, dy = x * fs - mx * ms, y * fs - my * ms
        local half = (map:GetWidth() or 0) / 2 * ms
        return half > 0 and math.sqrt(dx * dx + dy * dy) >= half * Buttons.EDGE
    end

    -- Frames turned down for good by their name alone - none, the game's or
    -- this addon's, a map pin's - so the look every SCAN seconds does not
    -- ask about each again (a map can hold hundreds of pins). A name and
    -- whose it is never change.
    local notButtons = setmetatable({}, { __mode = "k" })

    local function Wanted(frame, map, lib)
        if collected[frame] or type(frame) ~= "table" or notButtons[frame] then return false end
        if frame.IsForbidden and frame:IsForbidden() then return false end
        if frame.IsProtected and frame:IsProtected() then return false end
        if lib and type(lib.objects) == "table" then
            for _, object in pairs(lib.objects) do
                if object == frame then return true end
            end
        end
        local name = Named(frame)
        if not name then
            notButtons[frame] = true
            return false
        end
        local owner = Owner(name)
        -- A button made to look like LibDBIcon's, by an addon that places
        -- it itself when the library is missing (the Dungeon Journal does).
        if name:find("^LibDBIcon10_") then return owner ~= ADDON end
        if not owner or owner == ADDON then
            notButtons[frame] = true
            return false
        end
        for _, pattern in ipairs(Buttons.NOT_BUTTONS) do
            if name:find(pattern) then
                notButtons[frame] = true
                return false
            end
        end
        if not Clickable(frame) then return false end
        local w, h = frame:GetWidth(), frame:GetHeight()
        local low, high = Buttons.MIN_SIZE, Buttons.MAX_SIZE
        if not (w and h) or w < low or w > high or h < low or h > high then return false end
        return OnTheEdge(frame, map)
    end

    ---------------------------------------------------------------------------
    -- THE LOOK OF ONE
    ---------------------------------------------------------------------------

    local function IsArt(texture)
        if Kind(texture) ~= "Texture" then return false end
        local file = texture:GetTexture()
        if type(file) == "string" then file = (file:lower():gsub("/", "\\")) end
        return file ~= nil and Buttons.ART[file] == true
    end

    local function StateTexture(button, method)
        if type(button[method]) ~= "function" then return nil end
        local ok, texture = pcall(button[method], button)
        if ok and Kind(texture) == "Texture" then return texture end
    end

    -- Its picture: LibDBIcon's `icon`, else its normal texture, else the
    -- largest of its textures that is not round art or a state's.
    local function Icon(button, states)
        for _, key in ipairs({ "icon", "Icon" }) do
            if Kind(button[key]) == "Texture" then return button[key] end
        end
        local normal = states.normal
        if normal and not IsArt(normal) then return normal end
        local best, area = nil, 0
        for _, region in ipairs({ button:GetRegions() }) do
            if Kind(region) == "Texture" and not IsArt(region) and region ~= states.highlight
                and region ~= states.pushed and region ~= normal then
                local size = (region:GetWidth() or 0) * (region:GetHeight() or 0)
                if size > area then best, area = region, size end
            end
        end
        return best
    end

    local function Unmasked(texture)
        if type(texture.GetNumMaskTextures) ~= "function" then return end
        for index = texture:GetNumMaskTextures(), 1, -1 do
            local mask = texture:GetMaskTexture(index)
            if mask then texture:RemoveMaskTexture(mask) end
        end
    end

    local function Square(texture, button)
        texture:ClearAllPoints()
        texture:SetAllPoints(button)
        Unmasked(texture)
    end

    local function Flat(texture, button, colour, blend)
        texture:SetTexture(Style.FLAT_TEXTURE)
        texture:SetVertexColor(colour[1], colour[2], colour[3], colour[4])
        texture:ClearAllPoints()
        texture:SetAllPoints(button)
        if blend then texture:SetBlendMode(blend) end
    end

    local function Restyle(button)
        local size = Buttons.SLOT - 2 * Buttons.INSET
        button:SetScale(1)
        button:SetSize(size, size)
        local states = {
            normal = StateTexture(button, "GetNormalTexture"),
            pushed = StateTexture(button, "GetPushedTexture"),
            highlight = StateTexture(button, "GetHighlightTexture"),
        }
        local icon = Icon(button, states)
        for _, region in ipairs({ button:GetRegions() }) do
            if region ~= icon and IsArt(region) then region:SetAlpha(0) end
        end
        if icon then
            Square(icon, button)
            -- LibDBIcon crops its pictures itself (and a little less while
            -- pressed); others get the action buttons' crop.
            if type(icon.UpdateCoord) ~= "function" then
                local crop = Look.ICON_CROP
                icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
            end
        end
        if states.highlight then Flat(states.highlight, button, Look.HOVER, "ADD") end
        if states.pushed and states.pushed ~= icon then
            if IsArt(states.pushed) then
                Flat(states.pushed, button, PUSHED)
            else
                Square(states.pushed, button)
            end
        end
        -- LibDBIcon's "show on mouseover": in the drawer it is always shown.
        local fade = button.fadeOut
        if type(fade) == "table" and type(fade.Stop) == "function" then
            fade:Stop()
            if type(fade.HookScript) == "function" then
                fade:HookScript("OnPlay", function(self)
                    self:Stop()
                    button:SetAlpha(1)
                end)
            end
        end
        button:SetAlpha(1)
    end

    ---------------------------------------------------------------------------
    -- KEEPING THEM IN
    ---------------------------------------------------------------------------

    local pinning = false
    local function Pin(button)
        local entry = collected[button]
        if pinning or not entry then return end
        local slot = entry.slot
        if button:GetParent() == slot and button:GetNumPoints() == 1 then
            local point, relative, _, x, y = button:GetPoint(1)
            if point == "CENTER" and relative == slot and x == 0 and y == 0 then return end
        end
        pinning = true
        button:SetParent(slot)
        button:SetFrameStrata(Buttons.STRATA)
        button:SetFrameLevel(slot:GetFrameLevel() + 2)
        button:ClearAllPoints()
        button:SetPoint("CENTER", slot, "CENTER", 0, 0)
        pinning = false
    end

    ---------------------------------------------------------------------------
    -- THE DRAWER AND ITS TOGGLE
    ---------------------------------------------------------------------------

    -- Which way the drawer opens: towards the middle of the screen.
    local function OpensLeft()
        local map = _G.Minimap
        local x = map and map:GetCenter()
        local width = UIParent and UIParent:GetWidth()
        if not (x and width) then return true end
        return x * map:GetEffectiveScale() > width * UIParent:GetEffectiveScale() / 2
    end

    -- The arrow points where a click moves the drawer: out to where it opens
    -- while it is shut, back in while it is open. The atlas points left as
    -- drawn (the bag bar turns it by pi to point right).
    local function PaintHandle()
        if not handle then return end
        local left = handle.onLeft ~= false
        if open then left = not left end
        local rotation = left and 0 or math.pi
        for _, arrow in ipairs(handle.arrows) do arrow:SetRotation(rotation) end
        handle.pointsLeft = left
        local push = handle.pressed and Buttons.PUSHED_OFFSET or 0
        local arrow = handle.arrows[1]
        arrow:ClearAllPoints()
        arrow:SetPoint("CENTER", handle, "CENTER", push, -push)
        handle.glow:SetShown(handle.hovered == true)
    end

    -- The handle against the map's side at its BOTTOM corner (the player
    -- asked, 2026-10-01: same X, moved down from halfway), its foot level
    -- with the foot of the map's border, HANDLE_GAP of daylight between it and
    -- the map's border; the drawer out of it, GAP between their borders, its
    -- border's foot on the same line, growing up. On the side facing the
    -- middle of the screen; laid out again only when that side or the
    -- borders' reach has changed (Edit Mode moves the map, or rescales it).
    local placedLeft, placedMapOut, placedOut
    local function Place()
        local map = _G.Minimap
        if not (handle and map) then return end
        local left = OpensLeft()
        local mapOut = MinimapLook.BorderOut(handle)
        local handleOut = 0                -- the arrow wears no border
        local out = (border and border.out) or Style.BORDER_INSET
        if left == placedLeft and mapOut == placedMapOut and out == placedOut then return end
        placedLeft, placedMapOut, placedOut = left, mapOut, out
        local fromMap = mapOut + Buttons.HANDLE_GAP + handleOut
        local fromHandle = handleOut + Buttons.GAP + out
        handle:ClearAllPoints()
        drawer:ClearAllPoints()
        if left then
            handle:SetPoint("BOTTOMRIGHT", map, "BOTTOMLEFT", -fromMap, -mapOut)
            drawer:SetPoint("BOTTOMRIGHT", handle, "BOTTOMLEFT", -fromHandle, out)
        else
            handle:SetPoint("BOTTOMLEFT", map, "BOTTOMRIGHT", fromMap, -mapOut)
            drawer:SetPoint("BOTTOMLEFT", handle, "BOTTOMRIGHT", fromHandle, out)
        end
        handle.onLeft = left
        PaintHandle()
    end
    Buttons.Place = Place

    local function Close(now)
        open = false
        if drawer then
            if now then Style.HideNow(drawer) else Style.FadeOut(drawer) end
        end
        PaintHandle()
    end
    Buttons.Close = Close

    local function Open()
        if not drawer or (Buttons.count or 0) == 0 then return end
        open = true
        Place()
        for _, entry in ipairs(list) do entry.button:SetAlpha(1) end
        Style.FadeIn(drawer)
        PaintHandle()
    end
    Buttons.Open = Open

    function Buttons.Toggle()
        if open then Close() else Open() end
    end

    local function Build()
        local cluster = _G.MinimapCluster
        if drawer or not (cluster and _G.Minimap) then return drawer ~= nil end

        drawer = CreateFrame("Frame", Buttons.NAME, cluster)
        drawer:SetFrameStrata(Buttons.STRATA)
        drawer:SetClampedToScreen(true)
        drawer:EnableMouse(true)
        drawer:Hide()
        local bg = drawer:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints(drawer)
        local dark = Style.WINDOW_BACKGROUND
        bg:SetColorTexture(dark[1], dark[2], dark[3], dark[4])
        border = Style.AddBorder(drawer)
        Buttons.drawer, Buttons.border = drawer, border
        -- Esc closes it, as it does the game's windows.
        if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, Buttons.NAME) end
        -- A click anywhere else closes it too.
        drawer:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
        drawer:SetScript("OnHide", function(self)
            self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
            open = false
            PaintHandle()
        end)
        drawer:SetScript("OnEvent", function(self)
            if open and not (self:IsMouseOver() or handle:IsMouseOver()) then Close() end
        end)

        -- The handle: the game's collapse and expand arrow, built as the buff
        -- frame's toggle is (BuffFrame.xml): the arrow, and the same arrow
        -- added over it at HIGHLIGHT_ALPHA under the mouse. No box, no border.
        handle = CreateFrame("Button", nil, cluster)
        handle:SetSize(Buttons.HANDLE_WIDTH, Buttons.HANDLE_HEIGHT)
        handle:SetFrameLevel(_G.Minimap:GetFrameLevel() + 2)
        handle:RegisterForClicks("LeftButtonUp")
        handle:Hide()
        local arrow = handle:CreateTexture(nil, "ARTWORK")
        arrow:SetAtlas(Buttons.ARROW)
        arrow:SetSize(Buttons.ARROW_WIDTH, Buttons.ARROW_HEIGHT)
        handle.glow = handle:CreateTexture(nil, "OVERLAY")
        handle.glow:SetAtlas(Buttons.ARROW)
        handle.glow:SetSize(Buttons.ARROW_WIDTH, Buttons.ARROW_HEIGHT)
        handle.glow:SetPoint("CENTER", arrow, "CENTER", 0, 0)
        handle.glow:SetAlpha(Buttons.HIGHLIGHT_ALPHA)
        handle.glow:SetBlendMode("ADD")
        handle.glow:Hide()
        handle.arrows = { arrow, handle.glow }
        handle:SetScript("OnMouseDown", function(self)
            self.pressed = true
            PaintHandle()
        end)
        handle:SetScript("OnMouseUp", function(self)
            self.pressed = false
            PaintHandle()
        end)
        handle:SetScript("OnClick", Buttons.Toggle)
        handle:SetScript("OnEnter", function(self)
            self.hovered = true
            PaintHandle()
            if GameTooltip then
                GameTooltip:SetOwner(self, self.onLeft == false and "ANCHOR_RIGHT" or "ANCHOR_LEFT")
                GameTooltip:SetText(Buttons.TITLE, 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        handle:SetScript("OnLeave", function(self)
            self.hovered, self.pressed = false, false
            PaintHandle()
            if GameTooltip then GameTooltip:Hide() end
        end)
        Buttons.handle = handle
        PaintHandle()
        return true
    end
    Buttons.TITLE = "Addons"

    -- The slots in rows of COLUMNS, in name order, the drawer sized round
    -- them; a button its addon has hidden takes no slot. No buttons: no
    -- handle. The game's AddOns menu is brought in first (see Menu).
    local Menu
    local function Layout()
        Menu()
        if not drawer then return end
        local SLOT, PAD, COLUMNS = Buttons.SLOT, Buttons.PAD, Buttons.COLUMNS
        local shown = 0
        for _, entry in ipairs(list) do
            if entry.button:IsShown() then
                local column, row = shown % COLUMNS, math.floor(shown / COLUMNS)
                entry.slot:ClearAllPoints()
                entry.slot:SetPoint("TOPLEFT", drawer, "TOPLEFT", PAD + column * SLOT, -(PAD + row * SLOT))
                entry.slot:Show()
                shown = shown + 1
            else
                entry.slot:Hide()
            end
        end
        local columns, rows = math.min(shown, COLUMNS), math.ceil(shown / COLUMNS)
        drawer:SetSize(2 * PAD + math.max(columns, 1) * SLOT, 2 * PAD + math.max(rows, 1) * SLOT)
        Buttons.count = shown
        handle:SetShown(shown > 0)
        if shown == 0 and open then Close(true) end
        Place()
    end
    Buttons.Layout = Layout

    local function SortName(button)
        local name = Named(button) or ""
        return (name:gsub("^LibDBIcon10_", "")):lower()
    end

    -- The title of the addon a button is for: LibDBIcon's are made under the
    -- addon's name, any other by the addon itself.
    local function Title(button)
        local name = Named(button)
        local addon = name and (name:match("^LibDBIcon10_(.+)") or Owner(name))
        if addon and C_AddOns.DoesAddOnExist(addon) then return C_AddOns.GetAddOnTitle(addon) end
    end

    local function Collect(button, name)
        local slot = CreateFrame("Frame", nil, drawer)
        slot:SetSize(Buttons.SLOT, Buttons.SLOT)
        local inset = Buttons.INSET
        local inner = CreateFrame("Frame", nil, slot)
        inner:SetPoint("TOPLEFT", slot, "TOPLEFT", inset, -inset)
        inner:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -inset, inset)
        local bg = slot:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints(inner)
        Style.SetBackground(bg)
        local entry = {
            button = button, slot = slot, inner = inner, name = name or SortName(button), title = Title(button),
            border = Style.AddBorder(inner, Look.BORDER, false, Look.BORDER_PIXELS),
        }
        collected[button] = entry
        list[#list + 1] = entry
        table.sort(list, function(a, b) return a.name < b.name end)

        Restyle(button)
        Pin(button)
        hooksecurefunc(button, "SetPoint", Pin)
        hooksecurefunc(button, "SetParent", Pin)
        for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
            if type(button[method]) == "function" then hooksecurefunc(button, method, Layout) end
        end
    end

    ---------------------------------------------------------------------------
    -- THE GAME'S ADDONS MENU (AddonCompartmentFrame, the "AddOns" button by
    -- the map, its count under it): the addons that asked for a place in it.
    -- The drawer is the one place for them all: an entry whose addon has its
    -- button shown in the drawer is that button already - LibDBIcon made the
    -- entry for it, or it bears the title of the button's addon (the TOC's
    -- AddonCompartmentFunc ones) - and any other gets a button of the
    -- addon's own in the drawer: the entry's picture, its title (or the
    -- addon's own tooltip) under the mouse, a click doing what the entry
    -- does. The game's button is then parked on a hidden frame of the
    -- addon's, as EllesmereUI parks it.
    ---------------------------------------------------------------------------
    local made = {}     -- an entry of the game's menu -> the button made for it
    local parking

    local function InDrawer(item)
        for _, entry in ipairs(list) do
            local button = entry.button
            if button:IsShown() and (button.compartmentData == item
                or (entry.title ~= nil and entry.title == item.text)) then
                return true
            end
        end
        return false
    end

    local function MenuButton(item)
        local button = CreateFrame("Button", nil, drawer)
        button:RegisterForClicks("AnyUp")
        local icon = button:CreateTexture(nil, "ARTWORK")
        if item.icon and C_Texture.GetAtlasInfo(item.icon) then
            icon:SetAtlas(item.icon)
        else
            icon:SetTexture(item.icon or QUESTION_MARK_ICON)
        end
        button.icon = icon
        Flat(button:CreateTexture(nil, "HIGHLIGHT"), button, Look.HOVER, "ADD")
        -- As the game's menu calls them (AddonCompartment.lua): the hover
        -- ones are also handed the entry, which LibDBIcon reads its name from.
        button:SetScript("OnClick", function(self, mouseButton)
            if item.func then item.func(nil, { buttonName = mouseButton }, self) end
        end)
        button:SetScript("OnEnter", function(self)
            if item.funcOnEnter then return item.funcOnEnter(self, item) end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(item.text, 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function(self)
            if item.funcOnLeave then return item.funcOnLeave(self, item) end
            GameTooltip:Hide()
        end)
        made[item] = button
        Collect(button, tostring(item.text or ""):lower())
    end

    function Menu()
        local game = _G.AddonCompartmentFrame
        if not (game and type(game.registeredAddons) == "table") then return end
        -- (Shown or hidden only when that changes: each lays the drawer out.)
        local listed = {}
        for _, item in ipairs(game.registeredAddons) do
            listed[item] = true
            local needed, button = not InDrawer(item), made[item]
            if button then
                if button:IsShown() ~= needed then button:SetShown(needed) end
            elseif needed and Build() then
                MenuButton(item)
            end
        end
        for item, button in pairs(made) do
            if not listed[item] and button:IsShown() then button:Hide() end
        end
        if not parking then
            parking = CreateFrame("Frame")
            parking:Hide()
        end
        if game:GetParent() ~= parking then game:SetParent(parking) end
    end

    local listening = false
    local Scan
    local function Listen(lib)
        if listening or type(lib.RegisterCallback) ~= "function" then return end
        listening = true
        pcall(lib.RegisterCallback, Buttons, "LibDBIcon_IconCreated", function() Scan() end)
    end

    local found = {}                -- one look's finds (emptied as each begins)

    local function ScanChildren(holder, map, lib)
        if type(holder) ~= "table" or type(holder.GetChildren) ~= "function" then return end
        for _, child in ipairs({ holder:GetChildren() }) do
            if Wanted(child, map, lib) then found[#found + 1] = child end
        end
    end

    function Scan()
        local map = _G.Minimap
        if not map then return end
        local lib = LibDBIcon()
        if lib then Listen(lib) end
        for index = #found, 1, -1 do found[index] = nil end
        ScanChildren(map, map, lib)
        ScanChildren(_G.MinimapBackdrop, map, lib)
        -- LibDBIcon's buttons wherever they are (one may not be on the map).
        if lib and type(lib.objects) == "table" then
            for _, object in pairs(lib.objects) do
                if type(object) == "table" and not collected[object] then
                    local seen = false
                    for _, f in ipairs(found) do if f == object then seen = true end end
                    if not seen and Wanted(object, map, lib) then found[#found + 1] = object end
                end
            end
        end
        if #found == 0 then return end
        if not Build() then return end
        for _, button in ipairs(found) do Collect(button) end
        Layout()
    end

    -- Addons make their buttons as they load and at login, some a moment
    -- after: looked for the frame after (once every addon so far has had its
    -- turn), then every SCAN seconds, SCANS times - and no more until another
    -- loads. (LibDBIcon's say so themselves: Listen.)
    local waited, scans = 0, 0
    local Look, watcher = DogsForeverUI.Waker(function(elapsed)
        waited = waited + elapsed
        if scans == Buttons.SCANS or waited >= Buttons.SCAN then
            waited, scans = 0, scans - 1
            Scan()
        end
        return scans > 0
    end)
    watcher:RegisterEvent("PLAYER_LOGIN")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    watcher:RegisterEvent("UI_SCALE_CHANGED")
    watcher:SetScript("OnEvent", function(_, event)
        -- (The screen changed: the map may be on its other half.)
        if event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then return Place() end
        if event == "PLAYER_ENTERING_WORLD" then
            Scan()
            Place()
        end
        waited, scans = 0, Buttons.SCANS
        Look()
    end)
    -- Placed (Unlock Mode, Edit Mode): the map may be on the other half now.
    DogsForeverUI.WatchPlacing(Place)
    -- The game's AddOns menu gains or loses an entry (at login, or an addon
    -- adding or taking away its own): brought in again.
    if _G.AddonCompartmentFrame then hooksecurefunc(_G.AddonCompartmentFrame, "UpdateDisplay", Layout) end
end
