-- ADDON BUTTONS  (DogsForeverUI.Minimap.Buttons)
-- Other addons' minimap buttons, and the game's AddOns menu, gathered into a
-- drawer beside the map behind a handle (the game's gold collapse arrow) at
-- the map's bottom corner, facing the screen's middle. Each button sits in a
-- slot in the action buttons' look. No setting; no buttons, no handle.

local Buttons = {}
DogsForeverUI.Minimap.Buttons = Buttons

do -- private scope
    local Style = DogsForeverUI.Style
    local Core = DogsForeverUI
    local MinimapLook = DogsForeverUI.Minimap
    local Look = DogsForeverUI.Menus.ActionButtons

    Buttons.SLOT = 28               -- a slot, border included
    Buttons.INSET = 3               -- the slot's border room, and the gap between slots
    Buttons.PAD = 4                 -- inside the drawer, round the slots
    Buttons.GAP = 6                 -- between the handle and the drawer's border
    Buttons.HANDLE_GAP = 2          -- between the handle and the map's border
    Buttons.PUSHED_OFFSET = 1       -- the arrow nudged while pressed
    Buttons.SCAN = 2                -- seconds between looks for new buttons
    Buttons.STRATA = "MEDIUM"       -- LibDBIcon's own
    Buttons.NAME = "DogsForeverUIAddonButtons"

    local COLUMNS = 6
    local SCANS = 5                 -- looks after an addon loads or a login
    local EDGE = 0.75               -- out from the map's centre, of its half width
    local MIN_SIZE, MAX_SIZE = 14, 48
    local ARROW = Style.ARROW
    local HANDLE_WIDTH, HANDLE_HEIGHT = 15, 30
    local TITLE = "Addons"
    local ADDON = Core.ADDON_NAME

    -- A minimap button's round art (the ring, the backing, the hover glow),
    -- by file ID and by path.
    local ART = {
        [136430] = true, [136467] = true, [136477] = true,
        ["interface\\minimap\\minimap-trackingborder"] = true,
        ["interface\\minimap\\ui-minimap-background"] = true,
        ["interface\\minimap\\ui-minimap-zoombutton-highlight"] = true,
    }

    -- Frames other addons put on the map that are map pins, not buttons.
    local NOT_BUTTONS = {
        "^GatherMate", "^GatherNote", "^HandyNotes", "^QuestieFrame", "^HBD",
        "^Routes", "^TTMinimapButton", "Pin%d*$", "POI", "Note%d+$", "Node%d+$", "Arrow",
    }

    local drawer, handle, border
    local open = false
    local count = 0                 -- the buttons shown in it
    local collected = setmetatable({}, { __mode = "k" })   -- button -> its entry
    local list = {}                                         -- the entries, by name
    Buttons.list = list

    function Buttons.Has(frame) return collected[frame] ~= nil end
    function Buttons.IsOpen() return open end

    ---------------------------------------------------------------------------
    -- FINDING THEM: LibDBIcon's, and any other named, clickable, button-sized
    -- frame an addon put on the map's edge. Never the game's (secure),
    -- never a protected one, never a map pin.

    local function IsTexture(region)
        return type(region) == "table" and region.GetObjectType ~= nil and region:GetObjectType() == "Texture"
    end

    -- The addon that made the global `name`; nil for the game's own.
    local function Owner(name)
        local secure, taint = issecurevariable(name)
        if not secure then return taint or "?" end
    end

    local function OnTheEdge(frame, map)
        local x, y = frame:GetCenter()
        local mx, my = map:GetCenter()
        if not (x and y and mx and my) then return false end
        local fs, ms = frame:GetEffectiveScale(), map:GetEffectiveScale()
        local dx, dy = x * fs - mx * ms, y * fs - my * ms
        local half = (map:GetWidth() or 0) / 2 * ms
        return half > 0 and math.sqrt(dx * dx + dy * dy) >= half * EDGE
    end

    -- Turned down for good by name alone (a map can hold hundreds of pins).
    local notButtons = setmetatable({}, { __mode = "k" })

    local function Wanted(frame, map, lib)
        if collected[frame] or notButtons[frame] then return false end
        if frame.IsForbidden and frame:IsForbidden() then return false end
        if frame:IsProtected() then return false end
        if MinimapLook.MadeBy(lib, frame) then return true end
        local name = frame:GetName()
        if not name then
            notButtons[frame] = true
            return false
        end
        local owner = Owner(name)
        -- Made to look like LibDBIcon's by an addon placing it itself.
        if name:find("^LibDBIcon10_") then return owner ~= ADDON end
        if not owner or owner == ADDON then
            notButtons[frame] = true
            return false
        end
        for _, pattern in ipairs(NOT_BUTTONS) do
            if name:find(pattern) then
                notButtons[frame] = true
                return false
            end
        end
        if frame:GetObjectType() ~= "Button" and frame:GetScript("OnMouseUp") == nil then return false end
        local w, h = frame:GetWidth(), frame:GetHeight()
        if not (w and h) or w < MIN_SIZE or w > MAX_SIZE or h < MIN_SIZE or h > MAX_SIZE then return false end
        return OnTheEdge(frame, map)
    end

    ---------------------------------------------------------------------------
    -- THE LOOK OF ONE: its picture square, filling the slot; round art faded.

    local function IsArt(texture)
        if not IsTexture(texture) then return false end
        local file = texture:GetTexture()
        if type(file) == "string" then file = file:lower():gsub("/", "\\") end
        return file ~= nil and ART[file] == true
    end

    local function StateTexture(button, method)
        local texture = button[method] and button[method](button)
        if IsTexture(texture) then return texture end
    end

    -- LibDBIcon's `icon`, else its normal texture, else the largest of its
    -- textures that is neither round art nor a state's.
    local function Icon(button, states)
        for _, key in ipairs({ "icon", "Icon" }) do
            if IsTexture(button[key]) then return button[key] end
        end
        local normal = states.normal
        if normal and not IsArt(normal) then return normal end
        local best, area = nil, 0
        for _, region in ipairs({ button:GetRegions() }) do
            if IsTexture(region) and not IsArt(region) and region ~= states.highlight
                and region ~= states.pushed and region ~= normal then
                local size = (region:GetWidth() or 0) * (region:GetHeight() or 0)
                if size > area then best, area = region, size end
            end
        end
        return best
    end

    local function Square(texture, button)
        texture:ClearAllPoints()
        texture:SetAllPoints(button)
        if texture.GetNumMaskTextures then
            for index = texture:GetNumMaskTextures(), 1, -1 do
                local mask = texture:GetMaskTexture(index)
                if mask then texture:RemoveMaskTexture(mask) end
            end
        end
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
            -- LibDBIcon crops its pictures itself; others as the action buttons'.
            if not icon.UpdateCoord then
                icon:SetTexCoord(Look.ICON_CROP, 1 - Look.ICON_CROP, Look.ICON_CROP, 1 - Look.ICON_CROP)
            end
        end
        if states.highlight then Look.Flat(states.highlight, button, Look.HOVER, "ADD") end
        if states.pushed and states.pushed ~= icon then
            if IsArt(states.pushed) then
                Look.Flat(states.pushed, button, Look.PUSHED)
            else
                Square(states.pushed, button)
            end
        end
        -- LibDBIcon's "show on mouseover": in the drawer, always shown.
        local fade = button.fadeOut
        if type(fade) == "table" and fade.Stop then
            fade:Stop()
            fade:HookScript("OnPlay", function(self)
                self:Stop()
                button:SetAlpha(1)
            end)
        end
        button:SetAlpha(1)
    end

    -- KEPT IN: an addon may place its button on the map again (LibDBIcon at
    -- every refresh and drag step): back into its slot right after.
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
    -- THE DRAWER AND ITS HANDLE

    -- Towards the middle of the screen.
    local function OpensLeft()
        local map = _G.Minimap
        local x = map and map:GetCenter()
        local width = UIParent:GetWidth()
        if not (x and width) then return true end
        return x * map:GetEffectiveScale() > width * UIParent:GetEffectiveScale() / 2
    end

    -- The arrow points where a click moves the drawer (the atlas points left).
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

    -- The handle's foot level with the map border's, the drawer's border on
    -- the same line, growing up. Laid out again only when the side or a
    -- border's reach changed.
    local placedLeft, placedMapOut, placedOut
    function Buttons.Place()
        local map = _G.Minimap
        if not (handle and map) then return end
        local left = OpensLeft()
        local mapOut = MinimapLook.BorderOut(handle)
        local out = border.out or Style.BORDER_INSET
        if left == placedLeft and mapOut == placedMapOut and out == placedOut then return end
        placedLeft, placedMapOut, placedOut = left, mapOut, out
        local fromMap = mapOut + Buttons.HANDLE_GAP
        local fromHandle = Buttons.GAP + out
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

    function Buttons.Close(now)
        open = false
        if drawer then
            if now then Style.HideNow(drawer) else Style.FadeOut(drawer) end
        end
        PaintHandle()
    end

    function Buttons.Open()
        if not drawer or count == 0 then return end
        open = true
        Buttons.Place()
        for _, entry in ipairs(list) do entry.button:SetAlpha(1) end
        Style.FadeIn(drawer)
        PaintHandle()
    end

    local function Toggle()
        if open then Buttons.Close() else Buttons.Open() end
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
        -- Esc closes it, and so does a click anywhere else.
        table.insert(UISpecialFrames, Buttons.NAME)
        drawer:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
        drawer:SetScript("OnHide", function(self)
            self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
            open = false
            PaintHandle()
        end)
        drawer:SetScript("OnEvent", function(self)
            if open and not (self:IsMouseOver() or handle:IsMouseOver()) then Buttons.Close() end
        end)

        -- Built as the buff frame's toggle (BuffFrame.xml): the arrow, and
        -- the same arrow added over it under the mouse.
        handle = CreateFrame("Button", nil, cluster)
        handle:SetSize(HANDLE_WIDTH, HANDLE_HEIGHT)
        handle:SetFrameLevel(_G.Minimap:GetFrameLevel() + 2)
        handle:RegisterForClicks("LeftButtonUp")
        handle:Hide()
        local arrow = handle:CreateTexture(nil, "ARTWORK")
        arrow:SetAtlas(ARROW.atlas)
        arrow:SetSize(ARROW.width, ARROW.height)
        local glow = handle:CreateTexture(nil, "OVERLAY")
        glow:SetAtlas(ARROW.atlas)
        glow:SetSize(ARROW.width, ARROW.height)
        glow:SetPoint("CENTER", arrow, "CENTER", 0, 0)
        glow:SetAlpha(ARROW.highlight)
        glow:SetBlendMode("ADD")
        glow:Hide()
        handle.glow, handle.arrows = glow, { arrow, glow }
        handle:SetScript("OnMouseDown", function(self)
            self.pressed = true
            PaintHandle()
        end)
        handle:SetScript("OnMouseUp", function(self)
            self.pressed = false
            PaintHandle()
        end)
        handle:SetScript("OnClick", Toggle)
        handle:SetScript("OnEnter", function(self)
            self.hovered = true
            PaintHandle()
            GameTooltip:SetOwner(self, self.onLeft == false and "ANCHOR_RIGHT" or "ANCHOR_LEFT")
            GameTooltip:SetText(TITLE, 1, 1, 1)
            GameTooltip:Show()
        end)
        handle:SetScript("OnLeave", function(self)
            self.hovered, self.pressed = false, false
            PaintHandle()
            GameTooltip:Hide()
        end)
        Buttons.handle = handle
        PaintHandle()
        return true
    end

    -- The slots in rows of COLUMNS, in name order; a button its addon hid
    -- takes none. The game's AddOns menu is brought in first.
    local Menu
    local function Layout()
        Menu()
        if not drawer then return end
        local SLOT, PAD = Buttons.SLOT, Buttons.PAD
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
        count = shown
        handle:SetShown(shown > 0)
        if shown == 0 and open then Buttons.Close(true) end
        Buttons.Place()
    end

    -- The title of the addon a button is for: LibDBIcon's are named after it.
    local function Title(button)
        local name = button:GetName()
        local addon = name and (name:match("^LibDBIcon10_(.+)") or Owner(name))
        if addon and C_AddOns.DoesAddOnExist(addon) then return C_AddOns.GetAddOnTitle(addon) end
    end

    local function ByName(a, b) return a.name < b.name end

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
            button = button, slot = slot, inner = inner, title = Title(button),
            name = name or (button:GetName() or ""):gsub("^LibDBIcon10_", ""):lower(),
            border = Style.AddBorder(inner, Look.BORDER, false, Look.BORDER_PIXELS),
        }
        collected[button] = entry
        list[#list + 1] = entry
        table.sort(list, ByName)

        Restyle(button)
        Pin(button)
        hooksecurefunc(button, "SetPoint", Pin)
        hooksecurefunc(button, "SetParent", Pin)
        for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
            if button[method] then hooksecurefunc(button, method, Layout) end
        end
    end

    ---------------------------------------------------------------------------
    -- THE GAME'S ADDONS MENU (AddonCompartmentFrame): an entry whose addon's
    -- button is in the drawer is that button already (LibDBIcon's entry, or
    -- one bearing its addon's title); any other gets a button of its own
    -- there. The game's button is parked on a hidden frame, as EllesmereUI does.

    local made = {}             -- a menu entry -> the button made for it
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

    -- Called as the game's menu calls its entries (AddonCompartment.lua).
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
        Look.Flat(button:CreateTexture(nil, "HIGHLIGHT"), button, Look.HOVER, "ADD")
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
        if not (game and game.registeredAddons) then return end
        -- (Shown or hidden only on a change: each lays the drawer out.)
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
    local function Scan()
        local map = _G.Minimap
        if not (map and map.GetChildren) then return end
        local lib = MinimapLook.LibDBIcon()
        if lib and lib.RegisterCallback and not listening then
            listening = true
            lib.RegisterCallback(Buttons, "LibDBIcon_IconCreated", Scan)
        end
        local found, seen = {}, {}
        local function Consider(frame)
            if not seen[frame] and Wanted(frame, map, lib) then
                seen[frame] = true
                found[#found + 1] = frame
            end
        end
        for _, holder in ipairs({ map, _G.MinimapBackdrop }) do
            for _, child in ipairs({ holder:GetChildren() }) do Consider(child) end
        end
        -- LibDBIcon's wherever they are: one may not be on the map.
        for _, object in pairs(lib and lib.objects or {}) do Consider(object) end
        if #found == 0 or not Build() then return end
        for _, button in ipairs(found) do Collect(button) end
        Layout()
    end

    -- Looked for the frame after an addon loads or a login, then every SCAN
    -- seconds, SCANS times. (LibDBIcon's say so themselves: Listen.)
    local waited, scans = 0, 0
    local Soon, watcher = Core.Waker(function(elapsed)
        waited = waited + elapsed
        if scans == SCANS or waited >= Buttons.SCAN then
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
        -- The screen changed: the map may be on its other half.
        if event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then return Buttons.Place() end
        if event == "PLAYER_ENTERING_WORLD" then
            Scan()
            Buttons.Place()
        end
        waited, scans = 0, SCANS
        Soon()
    end)
    Core.WatchPlacing(Buttons.Place)
    -- The game's AddOns menu gaining or losing an entry: brought in again.
    if _G.AddonCompartmentFrame then hooksecurefunc(_G.AddonCompartmentFrame, "UpdateDisplay", Layout) end
end
