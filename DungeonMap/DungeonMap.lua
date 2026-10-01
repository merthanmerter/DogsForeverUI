-- Dungeon map: in a dungeon, the world map shows that dungeon's map - the
-- game's own art, with its floors to pick from. No setting and no command.
--
-- WHY IT IS NEEDED. The world map is retail's and would show a dungeon's
-- floors itself, but this client has no maps for its dungeons (probed in game
-- 2026-09-29): C_Map.GetMapInfo knows none of retail's dungeon maps, and
-- C_Map.GetBestMapForUnit("player") is nil inside one, so the world map falls
-- back to a map of the world.
--
-- WHERE THE ART COMES FROM. The dungeon maps from before retail's map system
-- are still in the game's files, under their old names (probed 2026-09-30:
-- Interface\WorldMap\WailingCaverns\WailingCaverns1_1 and others resolve): a
-- folder per dungeon, and per floor twelve 256-pixel tiles, four across and
-- three down, of which the old map frame showed 1002 x 668 pixels. They are
-- drawn here exactly so, over the world map's canvas.
--
-- WHICH DUNGEON. Nothing in the client links an instance to its map, so the
-- folder is found from the instance's name: its words run together
-- ("The Deadmines" -> TheDeadmines, "Zul'Farrak" -> ZulFarrak), and if no
-- such map exists, shorter runs of its words, longest first ("Ragefire
-- Chasm" -> Ragefire). A dungeon's folder holds a floor's first tile
-- (Name1_1); the floors are every NameN_1 that exists. When the instance's
-- name leads nowhere - a dungeon of this client's that was never one before,
-- like Ruins of Lordaeron - the zone's and subzone's names are tried the same
-- way, and a zone's old map (Name1..Name12, one floor) is taken too. Names
-- are in the client's language, so on a client not in English they do not
-- match the folders and the world map is left as it was. Each name is looked
-- up once and kept.
--
-- WHAT IT CANNOT DO. Show where anyone is: inside an instance the game gives
-- addons no position (UnitPosition returns only the instance's ID), so there
-- is no arrow and no party. Nor which floor you are on: the first floor shows
-- until another is picked, and the pick is kept for the session. Tried and
-- dropped on the way here: a second minimap cannot be made ("Unable to create
-- frame type: Minimap"), and moving the game's own minimap into the map left
-- it broken when it was handed back.

local DungeonMap = {}
DogsForeverUI.DungeonMap = DungeonMap

do -- private scope

    local Style = DogsForeverUI.Style

    local ROOT = "Interface\\WorldMap\\"
    local TILE = 256
    local COLUMNS, ROWS = 4, 3
    local WIDTH, HEIGHT = 1002, 668       -- what the old map frame showed of the tiles
    local MAX_FLOORS = 20
    local PAD = 10
    local FLOOR_BUTTON = 24

    local view, image, title
    local tiles, buttons = {}, {}
    local found = {}      -- a name -> { folder =, floors =, zone = } or false
    local picked = {}     -- a map's folder -> the floor last picked
    local shown = nil     -- the map on show

    local function Exists(path)
        local ok, id = pcall(GetFileIDFromPath, path)
        return ok and id ~= nil
    end

    -- A dungeon's tile: its folder, floor and tile number. A zone's map is
    -- the same twelve tiles with no floor.
    local function FloorTile(folder, floor, tile)
        return ROOT .. folder .. "\\" .. folder .. floor .. "_" .. tile
    end
    local function ZoneTile(folder, tile)
        return ROOT .. folder .. "\\" .. folder .. tile
    end
    local function Tile(map, floor, tile)
        if map.zone then return ZoneTile(map.folder, tile) end
        return FloorTile(map.folder, floor, tile)
    end

    -- The instance's name as words: apostrophes dropped inside a word
    -- (Zul'Farrak is one word), everything else not a letter or digit a gap.
    local function Words(name)
        local words = {}
        for word in name:gsub("'", ""):gmatch("%w+") do words[#words + 1] = word end
        return words
    end

    -- Retail's scenario maps are named the same way with "Scenario" after the
    -- place: the Battle for Lordaeron's is RuinsofLordaeronScenario1..12
    -- (probed 2026-09-30: the client knows it, file 1710785), and it is the
    -- only map of Ruins of Lordaeron there is.
    local SUFFIXES = { "", "Scenario" }

    -- The first run of the name's words that is a map's folder - a dungeon's
    -- (with floors) or a zone's - longest runs first, and left to right among
    -- runs of a length. Answers the folder and whether it is a zone's.
    local function FindFolder(name)
        local words = Words(name)
        for length = #words, 1, -1 do
            for first = 1, #words - length + 1 do
                local run = table.concat(words, "", first, first + length - 1)
                for _, suffix in ipairs(SUFFIXES) do
                    local folder = run .. suffix
                    if Exists(FloorTile(folder, 1, 1)) then return folder, false end
                    if Exists(ZoneTile(folder, 1)) then return folder, true end
                end
            end
        end
        return nil
    end

    local function Find(name)
        if found[name] == nil then
            local folder, zone = FindFolder(name)
            if folder then
                local floors = 1
                while not zone and floors < MAX_FLOORS and Exists(FloorTile(folder, floors + 1, 1)) do
                    floors = floors + 1
                end
                found[name] = { folder = folder, floors = floors, zone = zone }
            else
                found[name] = false
            end
        end
        return found[name] or nil
    end

    -- The names the game gives the place, most particular first: the
    -- instance's, then the zone's and the subzone's. Some of this client's
    -- dungeons were never dungeons before (Ruins of Lordaeron), so no old
    -- dungeon map carries their name - but a zone's name can lead to the old
    -- map of the place.
    local function Names()
        local names = { (GetInstanceInfo()) }
        for _, get in ipairs({ GetRealZoneText, GetZoneText, GetSubZoneText, GetMinimapZoneText }) do
            if type(get) == "function" then names[#names + 1] = get() end
        end
        return names
    end

    -- The map for where the player is: in an instance the world map has no map
    -- for, one of the old maps its names lead to.
    local function Current()
        if type(IsInInstance) ~= "function" or not IsInInstance() then return nil end
        if C_Map.GetBestMapForUnit("player") ~= nil then return nil end
        for _, name in ipairs(Names()) do
            if type(name) == "string" and name ~= "" then
                local map = Find(name)
                if map then return map, name end
            end
        end
        return nil
    end

    -- The world map is on the map it opened at for the player, not one the
    -- player turned to.
    local function OnPlayersMap()
        local mapID = WorldMapFrame:GetMapID()
        if type(MapUtil) == "table" and type(MapUtil.GetDisplayableMapForPlayer) == "function" then
            return mapID == MapUtil.GetDisplayableMapForPlayer()
        end
        return mapID == C_Map.GetFallbackWorldMapID()
    end

    local function PaintButtons(map)
        local W = DogsForeverUI.Widgets
        for floor, button in ipairs(buttons) do
            button:SetShown(map.floors > 1 and floor <= map.floors)
            W.SetStyle(button, floor == picked[map.folder] and "active" or nil)
        end
    end

    local function ShowFloor(map, floor)
        picked[map.folder] = floor
        for index, tile in ipairs(tiles) do
            tile:SetTexture(Tile(map, floor, index))
        end
        PaintButtons(map)
    end

    local function MakeButtons(count)
        local W = DogsForeverUI.Widgets
        for floor = #buttons + 1, count do
            local button = W.Button(view, tostring(floor), FLOOR_BUTTON, function()
                if shown then ShowFloor(shown, floor) end
            end)
            button:SetSize(FLOOR_BUTTON, FLOOR_BUTTON)
            if floor == 1 then
                button:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
            else
                button:SetPoint("LEFT", buttons[floor - 1], "RIGHT", 4, 0)
            end
            buttons[floor] = button
        end
    end

    -- The map as big as the canvas holds, its shape kept.
    local function Fit()
        local w, h = view:GetWidth() or 0, view:GetHeight() or 0
        if w <= 0 or h <= 0 then return end
        image:SetScale(math.min(w / WIDTH, h / HEIGHT))
    end

    local function Open(map, name)
        -- Over the canvas and the game's pins on it, in the map's border's
        -- layer; re-read each time, as the map is raised when clicked.
        local border = WorldMapFrame.BorderFrame or WorldMapFrame
        view:SetFrameStrata(border:GetFrameStrata())
        view:SetFrameLevel(border:GetFrameLevel() + 1)
        if shown ~= map then
            shown = map
            MakeButtons(map.floors)
            ShowFloor(map, picked[map.folder] or 1)
        end
        title:SetText(name or "")
        view:Show()
        Fit()
    end

    local function Update()
        local map, name
        if WorldMapFrame:IsShown() and OnPlayersMap() then map, name = Current() end
        if map then
            if not view:IsShown() or shown ~= map then Open(map, name) end
        else
            view:Hide()
        end
    end

    local function Build()
        view = CreateFrame("Frame", "DogsForeverUIDungeonMap", WorldMapFrame)
        view:SetAllPoints(WorldMapFrame.ScrollContainer)
        view:EnableMouse(true)           -- no clicks through to the world map behind
        view:SetScript("OnSizeChanged", Fit)
        view:Hide()

        view.bg = view:CreateTexture(nil, "BACKGROUND")
        view.bg:SetAllPoints(view)
        view.bg:SetColorTexture(0, 0, 0, 1)

        image = CreateFrame("Frame", nil, view)
        image:SetSize(WIDTH, HEIGHT)
        image:SetPoint("CENTER", view, "CENTER", 0, 0)
        for index = 1, COLUMNS * ROWS do
            local column, row = (index - 1) % COLUMNS, math.floor((index - 1) / COLUMNS)
            -- The last column and row are cut to what the old frame showed.
            local w = math.min(TILE, WIDTH - column * TILE)
            local h = math.min(TILE, HEIGHT - row * TILE)
            local tile = image:CreateTexture(nil, "ARTWORK")
            tile:SetSize(w, h)
            tile:SetTexCoord(0, w / TILE, 0, h / TILE)
            tile:SetPoint("TOPLEFT", image, "TOPLEFT", column * TILE, -row * TILE)
            tiles[index] = tile
        end

        title = view:CreateFontString(nil, "OVERLAY")
        Style.SingleLine(title)
        Style.SetBoldFont(title, 14)
        title:SetTextColor(1, 1, 1)
        title:SetJustifyH("LEFT")
        title:SetPoint("TOPLEFT", view, "TOPLEFT", PAD, -PAD)

        -- Runs while the world map is shown: it is the watcher's parent. The
        -- view cannot watch for itself: it is hidden while not wanted.
        local watcher = CreateFrame("Frame", nil, WorldMapFrame)
        watcher:SetScript("OnShow", Update)
        watcher:SetScript("OnUpdate", Update)

        DungeonMap.view, DungeonMap.tiles, DungeonMap.buttons = view, tiles, buttons
    end

    DungeonMap.Update = function() if view then Update() end end

    -- The world map loads with the game's own UI; it is looked for again as
    -- addons load in case it comes later.
    local function Take()
        if view then return end
        if type(WorldMapFrame) ~= "table" or not WorldMapFrame.ScrollContainer then return end
        if type(C_Map) ~= "table" or type(C_Map.GetBestMapForUnit) ~= "function" then return end
        if type(GetFileIDFromPath) ~= "function" or type(GetInstanceInfo) ~= "function" then return end
        Build()
    end

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", Take)
end
