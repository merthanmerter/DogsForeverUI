-- Defaults: what a character gets once - the addon's own layout (DogsForeverUI.DefaultPlaces)
-- and the game's own settings the addon wants on (MODULE: Game settings,
-- DogsForeverUI.GameDefaults, settings section "gamedefaults").

local Places = {}
DogsForeverUI.DefaultPlaces = Places

local GameDefaults = {
    key = "gamedefaults",
    title = "Game settings",
    -- installed: the first-start question answered (Options\Panel.lua).
    defaults = { done = 0, installed = false },
    keep = { installed = true },
}
DogsForeverUI.GameDefaults = GameDefaults

do -- private scope
    local Core = DogsForeverUI
    local Snap = Core.Snap

    ---------------------------------------------------------------------------
    -- The layout, worked out from the screen's and the pieces' sizes. Laid out
    -- once per character (placing.defaultPlaces holds the version) and at once
    -- by Reset everything; later versions only patch what changed. Reset
    -- Position puts one piece back.
    ---------------------------------------------------------------------------

    Places.VERSION = 37
    Places.EDGE_GAP = 15            -- the chat and the tooltip from the screen's edges
    Places.CHAT_SIZE = { 502, 200 } -- 400 wide plus the tabs' sidebar (Chat\ChatLook.lua)
    Places.SIDE_GAP = 28            -- the player and target frames from Action Bar 1
    local BAR1_UP = 3               -- Action Bar 1's top above the player frame's
    local BAR3_GAP = 15             -- Action Bar 3 above the XP bar
    local FAR_GAP = 15              -- the focus and target of target from theirs
    local TOAST_GAP = 10            -- the loot toasts above the chat
    local Entry = Snap.EntryById

    local function BoxOf(id)
        local entry = Entry(id)
        return entry and Snap.Box(entry)
    end

    -- The middle of a piece's frame (its bars, not its name row).
    local function Middle(id)
        local l, r, t, b = Snap.FrameRect(Entry(id))
        if l then return (l + r) / 2, (t + b) / 2 end
    end
    local function FrameLeft(id) return (Snap.FrameRect(Entry(id))) end
    local function FrameTop(id) return select(3, Snap.FrameRect(Entry(id))) end

    -- Moved so its box's edge (or middle), or its frame's, is at `x` / `y`.
    local function MoveX(id, how, x)
        local entry, box = Entry(id), BoxOf(id)
        if not (entry and box and x) then return end
        local now = ({ left = box.l, right = box.r, boxmiddle = box.cx,
                       frameleft = FrameLeft(id), middle = Middle(id) })[how]
        if now then Snap.Shift(entry, x - now, 0) end
    end
    local function MoveY(id, how, y)
        local entry, box = Entry(id), BoxOf(id)
        if not (entry and box and y) then return end
        local now = ({ top = box.t, bottom = box.b, boxmiddle = box.cy,
                       frametop = FrameTop(id), middle = select(2, Middle(id)) })[how]
        if now then Snap.Shift(entry, 0, y - now) end
    end

    local function Anchor(id, to)
        local entry, target = Entry(id), Entry(to)
        if entry and target then Snap.AnchorHere(entry, target) end
    end
    local function LetGo(id)
        local entry = Entry(id)
        if entry and Snap.AnchorOf(entry) then Snap.Unanchor(entry) end
    end

    -- Its `side` edge snapped to `to`'s box edge `edge` ("l"/"r"), level with `to`'s middle, anchored to it.
    local function Beside(id, to, side, edge)
        LetGo(id)
        local bar = BoxOf(to)
        if bar then MoveX(id, side, bar[edge]) end
        MoveY(id, "middle", select(2, Middle(to)))
        Anchor(id, to)
    end

    -- Each piece's step, in order: what each needs is laid out before it.
    local STEPS = {
        { "bar1", function()
            LetGo("bar1")
            MoveX("bar1", "boxmiddle", GetScreenWidth() / 2)
            local top = FrameTop("player")
            if top then MoveY("bar1", "frametop", top + BAR1_UP) end
        end },
        { "player", function()
            local bar = BoxOf("bar1")
            if bar then MoveX("player", "right", bar.l - Places.SIDE_GAP) end
        end },
        { "target", function()
            local bar = BoxOf("bar1")
            if bar then MoveX("target", "left", bar.r + Places.SIDE_GAP) end
        end },
        { "focus", function()
            local player = BoxOf("player")
            if player then
                MoveX("focus", "right", player.l - FAR_GAP)
                MoveY("focus", "boxmiddle", player.cy)
            end
            Anchor("focus", "player")
        end },
        { "targettarget", function()
            local target = BoxOf("target")
            if target then
                MoveX("targettarget", "left", target.r + FAR_GAP)
                MoveY("targettarget", "boxmiddle", target.cy)
            end
            Anchor("targettarget", "target")
        end },
        { "bar2", function()
            LetGo("bar2")
            local bar = BoxOf("bar1")
            MoveX("bar2", "boxmiddle", GetScreenWidth() / 2)
            if bar then MoveY("bar2", "top", bar.b) end
            Anchor("bar2", "bar1")
        end },
        { "stance", function()
            LetGo("stance")
            local bar = BoxOf("bar1")
            if bar then
                MoveX("stance", "left", bar.l)
                MoveY("stance", "bottom", bar.t)
            end
            Anchor("stance", "bar1")
        end },
        -- Left edge level with the pet frame's, bottom with Action Bar 2's; anchored to the pet frame.
        { "petbar", function()
            LetGo("petbar")
            local pet, bar = BoxOf("pet"), BoxOf("bar2")
            if pet then MoveX("petbar", "left", pet.l) end
            if bar then MoveY("petbar", "bottom", bar.b) end
            Anchor("petbar", "pet")
        end },
        { "xp", function()
            MoveX("xp", "boxmiddle", GetScreenWidth() / 2)
            MoveY("xp", "bottom", 0)
        end },
        { "bar3", function()
            LetGo("bar3")
            MoveX("bar3", "boxmiddle", GetScreenWidth() / 2)
            local xp = BoxOf("xp")
            if xp then MoveY("bar3", "bottom", xp.t + BAR3_GAP) end
        end },
        { "bar4", function() Beside("bar4", "bar3", "right", "l") end },
        { "bar5", function() Beside("bar5", "bar3", "left", "r") end },
        { "bar6", function()
            LetGo("bar6")
            MoveX("bar6", "right", GetScreenWidth())
            MoveY("bar6", "middle", GetScreenHeight() / 2)
        end },
        { "bar7", function() Beside("bar7", "bar6", "right", "l") end },
        { "bar8", function() Beside("bar8", "bar7", "right", "l") end },
        { "minimap", function()
            MoveX("minimap", "right", GetScreenWidth())
            MoveY("minimap", "top", GetScreenHeight())
        end },
        { "micro", function()
            MoveX("micro", "boxmiddle", GetScreenWidth() / 2)
            MoveY("micro", "top", GetScreenHeight())
        end },
        { "chat", function()
            -- Its size is its whole panel's (ActionBars\GameFrames.lua).
            local game = Core.GameFrames
            for key, size in pairs({ chatWidth = Places.CHAT_SIZE[1], chatHeight = Places.CHAT_SIZE[2] }) do
                Core.NoteEdit(game, key)
                game.db[key] = size
            end
            game.AttachChat()
            MoveX("chat", "left", Places.EDGE_GAP)
            MoveY("chat", "bottom", Places.EDGE_GAP)
        end },
        { "bags", function()
            MoveX("bags", "right", GetScreenWidth())
            MoveY("bags", "bottom", 0)
        end },
        { "party", function()
            -- The whole column of four centred, shown or not; its left edge kept.
            local entry = Entry("party")
            local box = entry and Snap.AnchorBox(entry)
            if not box then return end
            local frames = Core.Frames
            Snap.Shift(entry, 0, (GetScreenHeight() + frames.PartyColumn(frames.db)) / 2 - box.t)
        end },
        { "tooltip", function()
            LetGo("tooltip")
            MoveX("tooltip", "right", GetScreenWidth() - Places.EDGE_GAP)
            MoveY("tooltip", "bottom", Places.EDGE_GAP)
        end },
        -- The castbar at its own default height before the cooldowns take it.
        { "castbar", function()
            MoveX("castbar", "boxmiddle", GetScreenWidth() / 2)
            MoveY("castbar", "frametop", GetScreenHeight() * (1 - Core.Castbar.TOP_SHARE))
        end },
        -- The extra action button's middle on Action Bar 1's bottom edge, anchored to nothing.
        { "extra", function()
            LetGo("extra")
            Core.GameFrames.PlaceExtra()
        end },
        -- The game's class resource frame (runes, holy power...) on the secondary power's spot.
        { "classpower", function()
            LetGo("classpower")
            Core.GameFrames.PlaceClassPower()
        end },
        { "cooldowns", function()
            MoveX("cooldowns", "frameleft", FrameLeft("player"))
            MoveY("cooldowns", "frametop", FrameTop("castbar"))
        end },
        -- Centred on the screen, the first row a row's gap over the secondary power (the
        -- five-second rule; from its saved place: a hidden bar cannot be measured), anchored to nothing.
        { "cooldownicons", function()
            LetGo("cooldownicons")
            local castbar = Core.Castbar
            local _, _, top = castbar.RowPlace(Core.FiveSecondRule)
            MoveX("cooldownicons", "middle", GetScreenWidth() / 2)
            MoveY("cooldownicons", "middle",
                GetScreenHeight() + top + castbar.STACK_GAP + Core.Cooldowns.db.iconSize / 2)
        end },
        { "threat", function()
            MoveX("threat", "frameleft", FrameLeft("target"))
            MoveY("threat", "frametop", FrameTop("castbar"))
        end },
        { "toasts", function()
            -- Over the chat, left edges level, TOAST_GAP clear of it; they grow up.
            LetGo("toasts")
            local chat = BoxOf("chat")
            if chat then
                MoveX("toasts", "left", chat.l)
                MoveY("toasts", "bottom", chat.t + TOAST_GAP)
            end
        end },
    }

    -- Action Bars 1-5 twelve buttons in two rows, 2 apart; 6-8 one button wide ("all": a row each);
    -- the pet bar two rows of 24.
    local TWO_ROWS = { Buttons = 12, Rows = 2, Spacing = 2 }
    local ONE_WIDE = { Rows = "all" }
    local BAR_SETTINGS = {
        bar1 = TWO_ROWS, bar2 = TWO_ROWS, bar3 = TWO_ROWS, bar4 = TWO_ROWS, bar5 = TWO_ROWS,
        bar6 = ONE_WIDE, bar7 = ONE_WIDE, bar8 = ONE_WIDE, pet = { Rows = 2, Size = 24 },
    }
    local BAR_ORDER = { "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8", "pet" }
    -- `ids`: Unlock Mode ids (the pet bar's "petbar"); nil: every bar.
    local function BarSettings(ids)
        local bars = Core.ActionBars
        local any = false
        for _, key in ipairs(BAR_ORDER) do
            if not ids or ids[bars.byKey[key].id] then
                for _, setting in ipairs({ "Buttons", "Rows", "Spacing", "Size" }) do
                    local value = BAR_SETTINGS[key][setting]
                    if value == "all" then value = tonumber(bars.db[key .. "Buttons"]) or 12 end
                    if value ~= nil and bars.db[key .. setting] ~= value then
                        -- (Reset Position in Unlock Mode: an unsaved change.)
                        Core.NoteEdit(bars, key .. setting)
                        bars.db[key .. setting] = value
                        any = true
                    end
                end
            end
        end
        if any then bars.LayOutAll() end
    end

    local function Ready()
        return Snap.db and Entry("player") and Entry("bar1") and Middle("player") ~= nil
            and not InCombatLockdown()
    end

    -- Before version 2 the pet bar and the pet frame shared the id "pet": the
    -- pet frame's anchor remade from where it is, the pet bar back in its place.
    local function Repair()
        local db = Snap.db
        if type(db.snaps) == "table" then db.snaps.pet = nil end
        if type(db.anchoredByDefault) == "table" then db.anchoredByDefault.pet = nil end
        local bars = Core.ActionBars
        bars.db.petPlaced = nil
        bars.ResetPlace("pet")
        if Snap.AnchorDefaults() then Snap.ScheduleDefaults() end
    end

    -- The whole layout. Answers whether it was laid out.
    function Places.Apply()
        if not Ready() then return false end
        Core.Safely(Repair)
        BarSettings()
        for _, step in ipairs(STEPS) do
            if Entry(step[1]) then Core.Safely(step[2]) end
        end
        Snap.db.defaultPlaces = Places.VERSION
        return true
    end

    -- [version] = the change from the version before, for a character that
    -- has the layout already (whatever was moved since stays).
    local function Place(...)
        local ids = { ... }
        return function()
            for _, id in ipairs(ids) do Places.Place(id) end
        end
    end
    local PATCHES = {
        [5] = function()
            local entry = Entry("bar1")
            if entry then Snap.Shift(entry, 0, BAR1_UP) end
        end,
        [6] = function()
            local player, target = Entry("player"), Entry("target")
            if player then Snap.Shift(player, -20, 0) end
            if target then Snap.Shift(target, 20, 0) end
        end,
        [7] = Place("bags"),
        [8] = Place("chat", "bags"),
        [9] = Place("bags"),
        [10] = Place("chat"),
        [11] = Place("chat"),
        [12] = Place("chat"),
        [13] = Place("tooltip"),
        [14] = Place("castbar", "cooldowns"),
        [15] = Place("party"),
        [16] = Place("threat"),
        [17] = Place("tooltip"),
        [18] = Place("chat"),
        [19] = Place("chat"),
        [20] = Place("toasts"),
        [21] = Place("toasts"),
        [22] = function() LetGo("toasts") end,
        -- The cooldown icons' place, and their size and row length the defaults again.
        [23] = function()
            local cooldowns = Core.Cooldowns
            for _, key in ipairs({ "iconSize", "iconsPerRow" }) do cooldowns.db[key] = cooldowns.defaults[key] end
            cooldowns.Refresh()
            Places.Place("cooldownicons")
        end,
        [24] = Place("cooldownicons"),      -- over the bars at their tallest
        [25] = Place("extra"),              -- over the castbar, half size
        [26] = Place("extra"),              -- over the secondary power, let go of the castbar
        -- Retail's bag bar at the game's own size (Forever's 75% kept), in its corner again.
        [27] = function()
            local game = Core.GameFrames
            if Core.RETAIL and game.db.bagsSize == 75 then
                game.db.bagsSize = game.defaults.bagsSize
                game.Refresh()
                Places.Place("bags")
            end
        end,
        [28] = Place("cooldownicons"),      -- over the bars shown, pushed up as more show
        [29] = Place("extra"),              -- Action Bar 1's size and a touch: centred over the row again
        [30] = Place("extra"),              -- Action Bar 1's size: centred over the row again
        -- The extra button on Action Bar 1's bottom; the cooldown icons let go of the bars, over
        -- the secondary power, growing both sides (unless the player picked leftward).
        [31] = function()
            local cooldowns = Core.Cooldowns
            if cooldowns.db.iconGrow == "right" then
                cooldowns.db.iconGrow = cooldowns.defaults.iconGrow
                cooldowns.Refresh()
            end
            Places.Place("extra")
            Places.Place("cooldownicons")
        end,
        [32] = Place("petbar"),             -- two rows of 24, beside Action Bar 2, anchored to the pet frame
        [33] = Place("toasts"),             -- over the chat, left edges level
        [34] = Place("classpower"),         -- the class resource, new: on the secondary power's spot
        -- (35 set them 30 across; 36 replaced it.) The cooldown icons 32 across, from an older default (26, 30); one the player sized stays.
        [36] = function()
            local cooldowns = Core.Cooldowns
            local size = cooldowns.db.iconSize
            if size == 26 or size == 30 then
                cooldowns.db.iconSize = cooldowns.defaults.iconSize
                cooldowns.Refresh()
            end
        end,
        -- The cooldown icons 6 to a row, from the older default 5; one the player set stays.
        [37] = function()
            local cooldowns = Core.Cooldowns
            if cooldowns.db.iconsPerRow == 5 then
                cooldowns.db.iconsPerRow = cooldowns.defaults.iconsPerRow
                cooldowns.Refresh()
            end
        end,
    }

    -- Brought up to date: patched, or (never had, or reset) laid out whole.
    -- Answers whether it was.
    function Places.Update()
        local had = tonumber(Snap.db and Snap.db.defaultPlaces) or 0
        if had < 4 then return Places.Apply() end
        if not Ready() then return false end
        for version = had + 1, Places.VERSION do
            if PATCHES[version] then Core.Safely(PATCHES[version]) end
        end
        Snap.db.defaultPlaces = Places.VERSION
        return true
    end

    -- One piece back in its place in the layout (Reset Position).
    function Places.Place(id)
        if not (id and Ready()) then return false end
        for _, step in ipairs(STEPS) do
            if step[1] == id then
                BarSettings({ [id] = true })
                Core.Safely(step[2])
                return true
            end
        end
        return false
    end

    -- Laid out a couple of seconds after the world is up (the pieces take
    -- their own first places first), out of combat.
    Places.scheduled = false
    function Places.Due()
        local db = Snap.db
        return db ~= nil and (tonumber(db.defaultPlaces) or 0) < Places.VERSION
    end

    function Places.Schedule()
        if Places.scheduled or not Places.Due() then return end
        Places.scheduled = true
        C_Timer.After(2, function()
            Places.scheduled = false
            -- (In combat: again as it ends.)
            if Places.Due() and not Places.Update() and not InCombatLockdown() then Places.Schedule() end
        end)
    end

    ---------------------------------------------------------------------------
    -- Game settings: once per character, in steps (`done` counts them), out of
    -- combat once the saved settings are trusted; read back for half a minute,
    -- as the server may hand old values back. Plain C_CVar calls: Settings
    -- helpers taint.
    ---------------------------------------------------------------------------

    local CHECKS = { 3, 10, 30 }    -- seconds after a step: read back

    -- Equal as written, or as numbers ("2.000000" for "2").
    function GameDefaults.Same(a, b)
        if a == b then return true end
        local x, y = tonumber(a), tonumber(b)
        return x ~= nil and y ~= nil and math.abs(x - y) < 1e-6
    end
    local Same = GameDefaults.Same

    -- Each step: the CVars it sets (an Enum value the client lacks: skipped), and
    -- whether it switches Action Bars 2-5 on. No key is ever bound.
    local CVAR_STEPS = {
        -- Nameplates on and always shown, Large (Camelot's name for Modern),
        -- friendly players class coloured; the damage meter on, reset per instance.
        { bars = true, cvars = {
            { "nameplateShowEnemies", "1" },
            { "nameplateShowAll", "1" },
            { "nameplateShowFriendlyClassColor", "1" },
            { "nameplateUseClassColorForFriendlyPlayerUnitNames", "1" },
            { "damageMeterEnabled", "1" },
            { "damageMeterResetOnNewInstance", "1" },
            { "nameplateStyle", Core.EnumValue("NamePlateStyle", "Modern") },
        } },
        -- Friendly player plates, auto loot, combined bags, the cooldown
        -- manager off, Never Adjust Camera, the farthest camera, soft interact for any input.
        { cvars = {
            { "nameplateShowEnemies", "1" },
            { "nameplateShowFriendlyPlayers", "1" },
            { "autoLootDefault", "1" },
            { "combinedBags", "1" },
            { "cooldownViewerEnabled", "0" },
            { "cameraSmoothStyle", "0" },
            { "cameraDistanceMaxZoomFactor", "2" },
            { "softTargetInteract", Core.EnumValue("SoftTargetEnableFlags", "Any") },
        } },
        -- Show Numbers for Cooldowns (the addon's bars follow it).
        { cvars = { { "countdownForCooldowns", "1" } } },
    }
    GameDefaults.STEPS = CVAR_STEPS

    local watched = {}          -- CVar -> the value written
    local watchBars = false
    local since, nextCheck

    local function Check()
        if InCombatLockdown() then return end
        for name, value in pairs(watched) do
            if not Same(C_CVar.GetCVar(name), value) then pcall(C_CVar.SetCVar, name, value) end
        end
        local bars = Core.ActionBars
        if watchBars and not bars.GameBarsAllOn() then bars.SwitchGameBarsOn() end
    end

    local Watch, checker = Core.Waker(function(elapsed)
        since = since + elapsed
        local at = CHECKS[nextCheck]
        if not at then
            watched = {}
            watchBars = false
            return false
        end
        if since >= at then
            nextCheck = nextCheck + 1
            Check()
        end
        return true
    end)

    function GameDefaults.Watching() return checker:IsShown() end

    local function RunStep(step)
        for _, setting in ipairs(step.cvars) do
            local name, value = setting[1], setting[2] and tostring(setting[2])
            -- (A setting this client does not have is left alone.)
            local now = value and C_CVar.GetCVar(name)
            if now ~= nil then
                watched[name] = value
                if not Same(now, value) then pcall(C_CVar.SetCVar, name, value) end
            end
        end
        if step.bars then
            watchBars = true
            Core.ActionBars.SwitchGameBarsOn()
        end
    end

    -- The steps not yet done, now. Answers whether nothing is left to do.
    function GameDefaults.Apply()
        local db = GameDefaults.db
        local done = tonumber(db.done) or 0
        if done >= #CVAR_STEPS then return true end
        if not Core.SettingsTrusted() or InCombatLockdown() then return false end
        for index = done + 1, #CVAR_STEPS do
            Core.Safely(RunStep, CVAR_STEPS[index])
            db.done = index
        end
        since, nextCheck = 0, 1
        Watch()
        return true
    end

    -- Tried as the world comes up, as a fight ends, after a reset - and each
    -- half second until the settings can be trusted.
    GameDefaults.Try = Core.Retry(GameDefaults.Apply)

    function GameDefaults.Normalise(db)
        db.done = math.max(0, math.floor(tonumber(db.done) or 0))
        db.installed = db.installed == true
    end

    -- First start, and Reset everything (`done` back to 0).
    function GameDefaults.Init()
        if Core.SettingsTrusted() then GameDefaults.Try() end
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function()
        Places.Schedule()
        GameDefaults.Try()
    end)

    Core:RegisterModule(GameDefaults)
end
