-- THE ADDON'S OWN DEFAULT LAYOUT (the player, 2026-10-03), laid on top of
-- each piece's own first place once every piece has one:
--
--   * Action Bar 1 centred left to right, its Y 3 above the player frame's
--     (the player: -897 for -900); the player and target frames moved out to either
--     side of it, 28 clear of it (it is wider than the gap they had - the
--     player chose to move them apart);
--   * Action Bar 2 snapped under Action Bar 1, centred, anchored to it;
--   * Action Bars 1 to 5 twelve buttons in two rows, 2 apart;
--   * Action Bar 3 centred, 15 above the XP bar at the bottom of the
--     screen; Action Bars 4 and 5 snapped to its left and right, anchored
--     to it;
--   * the stance bar snapped on top of Action Bar 1 at its left edge,
--     anchored to it; the
--     pet bar snapped under Action Bar 2, centred on it, anchored to it;
--   * the minimap snapped into the screen's top right corner; the micro
--     menu centred, snapped to the top of the screen; the chat's panel 400
--     wide, 200 high, 15 in from the bottom left corner; the tooltip 15 in
--     from the bottom right one; the bag bar (at 75%:
--     ActionBars\GameFrames.lua) in the bottom right corner;
--   * Action Bars 6, 7 and 8 one button wide (12 rows): 6 against the
--     screen's right edge, centred top to bottom; 7 snapped to 6's left, 8 to
--     7's left, each anchored to the one before;
--   * the XP bar centred, on the screen's bottom edge;
--   * the focus frame 15 left of the player frame, the target of target 15
--     right of the target frame, each centred on it top to bottom (the
--     whole of it, name row included: the player measured -903 for a target
--     at -900 on their screen) and anchored to it;
--   * the castbar centred left to right at its own default height, the row
--     over the unit frames (its group comes along: the countdown and the
--     swing bars are anchored to it); the cooldowns at the player frame's X
--     (their left edges level), the same Y as the castbar; the threat bar
--     the same at the target frame's X;
--   * the loot toasts over the focus frame, left edges level, the bottom
--     level with the cooldowns', anchored to nothing;
--   * the party's column exactly centred top to bottom.
--
-- Everything worked out from the screen's size and the pieces' own, so it
-- fits any resolution. "Snapped" and "apart" as Unlock Mode has them: the two
-- pieces' boxes (border included) touching, or that far between them. Laid
-- out ONCE per character (placing.defaultPlaces holds the version), and at
-- once by Reset everything (not a moment later: everything showed in the
-- wrong place first); Reset Position puts that one piece back in it.
-- Anything moved afterwards stays where it is put.

local Places = {}
DogsForeverUI.DefaultPlaces = Places

do -- private scope
    local Core = DogsForeverUI
    local Snap = Core.Snap

    Places.VERSION = 22        -- (laid out again for each change: 3 - bars 1 to 5
                                --  in two rows, focus and ToT 15 off and centred,
                                --  the castbar centred; 4 - bar 3 over the XP bar,
                                --  the stance and pet bars, minimap, micro menu;
                                --  5 - bar 1 3 higher; 6 - the player and target
                                --  frames 20 further out; 7 - the bag bar in the
                                --  bottom right corner; 8 - the chat and the
                                --  damage meter in the bottom corners; 9 - the
                                --  bag bar in the bottom right corner again,
                                --  over the meter; 10 - the meter at the game's
                                --  size and the chat at the meter's, both 15 in
                                --  from their corners; 11 - both 150 high; 12 -
                                --  both 200 high; 13 - the tooltip snapped to the
                                --  meter's left side; 14 - the castbar and the
                                --  cooldowns back over the unit frames - only
                                --  those: PATCHES; 15 - the party's column
                                --  exactly centred top to bottom; 16 - the
                                --  threat bar, new; 17 - the damage meter gone
                                --  back to the game: the tooltip into the
                                --  bottom right corner; 18 - the chat's
                                --  tabs in a sidebar left of it: the chat
                                --  that much wider, back in its corner; 19 -
                                --  its letters over it, the box typed into
                                --  under it: back in its corner; 20 - the
                                --  loot toasts, new: over the chat; 21 - the
                                --  loot toasts over the focus frame; 22 -
                                --  anchored to nothing)
    Places.EDGE_GAP = 15        -- the chat and the tooltip from the screen's edges
    -- The chat panel's default size (the player, 2026-10-03: "make chat ...
    -- height 200 units by default"; 150 before) - 400 wide and the tabs'
    -- sidebar beside it (Chat\ChatLook.lua: SIDE_WIDTH and GAP).
    Places.CHAT_SIZE = { 502, 200 }
    Places.SIDE_GAP = 28        -- the player and target frames from Action Bar 1
                                -- (the player, 2026-10-03: 770, not 790 - it was 8)
    Places.BAR1_UP = 3          -- Action Bar 1's top above the player frame's (the
                                -- player, 2026-10-03: -897 for a player frame at -900)
    Places.BAR3_GAP = 15        -- Action Bar 3 above the XP bar
    Places.FAR_GAP = 15         -- the focus and target of target from theirs

    local function Entry(id) return Snap.EntryById(id) end
    local function BoxOf(id) local entry = Entry(id); return entry and Snap.Box(entry) end
    -- The middle of a piece's frame (its bars, not its name row), in
    -- UIParent's units.
    local function Middle(id)
        local l, r, t, b = Snap.FrameRect(Entry(id))
        if l then return (l + r) / 2, (t + b) / 2 end
    end

    -- Moved so its box's (left, right, top or bottom) edge or its frame's
    -- middle is where it is asked; nil leaves that axis as it is.
    local function MoveX(id, how, x)
        local entry, box = Entry(id), BoxOf(id)
        if not (entry and box and x) then return end
        local now
        if how == "left" then now = box.l elseif how == "right" then now = box.r
        elseif how == "boxmiddle" then now = box.cx
        elseif how == "frameleft" then now = Snap.FrameRect(entry)
        else now = Middle(id) end
        if now then Snap.Shift(entry, x - now, 0) end
    end
    local function MoveY(id, how, y)
        local entry, box = Entry(id), BoxOf(id)
        if not (entry and box and y) then return end
        local now
        if how == "top" then now = box.t elseif how == "bottom" then now = box.b
        elseif how == "boxmiddle" then now = box.cy
        elseif how == "frametop" then now = select(3, Snap.FrameRect(entry))
        else now = select(2, Middle(id)) end
        if now then Snap.Shift(entry, 0, y - now) end
    end
    -- A frame's own left and top (the X and Y Unlock Mode shows for it).
    local function FrameLeft(id) return (Snap.FrameRect(Entry(id))) end
    local function FrameTop(id) return select(3, Snap.FrameRect(Entry(id))) end

    local function Anchor(id, to)
        local entry, target = Entry(id), Entry(to)
        if entry and target then Snap.AnchorHere(entry, target) end
    end
    local function LetGo(id)
        local entry = Entry(id)
        if entry and Snap.AnchorOf(entry) then Snap.Unanchor(entry) end
    end

    -- Each piece's step, in the order they are laid out: what each needs is
    -- laid out before it.
    local W, H = function() return GetScreenWidth() end, function() return GetScreenHeight() end
    local STEPS = {
        { "bar1", function()
            LetGo("bar1")
            MoveX("bar1", "boxmiddle", W() / 2)
            local top = FrameTop("player")
            if top then MoveY("bar1", "frametop", top + Places.BAR1_UP) end
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
                MoveX("focus", "right", player.l - Places.FAR_GAP)
                MoveY("focus", "boxmiddle", player.cy)
            end
            Anchor("focus", "player")
        end },
        { "targettarget", function()
            local target = BoxOf("target")
            if target then
                MoveX("targettarget", "left", target.r + Places.FAR_GAP)
                MoveY("targettarget", "boxmiddle", target.cy)
            end
            Anchor("targettarget", "target")
        end },
        { "bar2", function()
            LetGo("bar2")
            local bar = BoxOf("bar1")
            MoveX("bar2", "boxmiddle", W() / 2)
            if bar then MoveY("bar2", "top", bar.b) end
            Anchor("bar2", "bar1")
        end },
        { "stance", function()
            -- Snapped on top of Action Bar 1, at its left edge, anchored to it.
            LetGo("stance")
            local bar = BoxOf("bar1")
            if bar then
                MoveX("stance", "left", bar.l)
                MoveY("stance", "bottom", bar.t)
            end
            Anchor("stance", "bar1")
        end },
        { "petbar", function()
            -- Snapped under Action Bar 2, centred on it, anchored to it.
            LetGo("petbar")
            local bar = BoxOf("bar2")
            if bar then
                MoveX("petbar", "boxmiddle", bar.cx)
                MoveY("petbar", "top", bar.b)
            end
            Anchor("petbar", "bar2")
        end },
        { "xp", function()
            MoveX("xp", "boxmiddle", W() / 2)
            MoveY("xp", "bottom", 0)
        end },
        { "bar3", function()
            -- 15 above the XP bar, at the bottom of the screen.
            LetGo("bar3")
            MoveX("bar3", "boxmiddle", W() / 2)
            local xp = BoxOf("xp")
            if xp then MoveY("bar3", "bottom", xp.t + Places.BAR3_GAP) end
        end },
        { "bar4", function()
            LetGo("bar4")
            local bar = BoxOf("bar3")
            if bar then MoveX("bar4", "right", bar.l) end
            MoveY("bar4", "middle", select(2, Middle("bar3")))
            Anchor("bar4", "bar3")
        end },
        { "bar5", function()
            LetGo("bar5")
            local bar = BoxOf("bar3")
            if bar then MoveX("bar5", "left", bar.r) end
            MoveY("bar5", "middle", select(2, Middle("bar3")))
            Anchor("bar5", "bar3")
        end },
        { "bar6", function()
            LetGo("bar6")
            MoveX("bar6", "right", W())
            MoveY("bar6", "middle", H() / 2)
        end },
        { "bar7", function()
            LetGo("bar7")
            local bar = BoxOf("bar6")
            if bar then MoveX("bar7", "right", bar.l) end
            MoveY("bar7", "middle", select(2, Middle("bar6")))
            Anchor("bar7", "bar6")
        end },
        { "bar8", function()
            LetGo("bar8")
            local bar = BoxOf("bar7")
            if bar then MoveX("bar8", "right", bar.l) end
            MoveY("bar8", "middle", select(2, Middle("bar7")))
            Anchor("bar8", "bar7")
        end },
        { "minimap", function()
            -- Snapped into the screen's top right corner.
            MoveX("minimap", "right", W())
            MoveY("minimap", "top", H())
        end },
        { "micro", function()
            -- Centred, snapped to the top of the screen.
            MoveX("micro", "boxmiddle", W() / 2)
            MoveY("micro", "top", H())
        end },
        { "chat", function()
            -- The chat's panel (Chat\ChatLook.lua: the tabs, the messages and
            -- the box typed into) at CHAT_SIZE, EDGE_GAP in from the bottom
            -- left corner (the player, 2026-10-03: "can leave same spacing
            -- from bottom and side a little bit like 15 units").
            -- (Its Width and Height are its whole panel's: ActionBars\GameFrames.lua.)
            local game = Core.GameFrames
            if game and game.db then
                for key, size in pairs({ chatWidth = Places.CHAT_SIZE[1], chatHeight = Places.CHAT_SIZE[2] }) do
                    if Core.NoteEdit then Core.NoteEdit(game, key) end
                    game.db[key] = size
                end
                if game.AttachChat then game.AttachChat() end
            end
            MoveX("chat", "left", Places.EDGE_GAP)
            MoveY("chat", "bottom", Places.EDGE_GAP)
        end },
        { "bags", function()
            -- Snapped into the screen's bottom right corner (it shows only
            -- while a bag is open).
            MoveX("bags", "right", W())
            MoveY("bags", "bottom", 0)
        end },
        { "party", function()
            -- The party's column exactly centred top to bottom (the player,
            -- 2026-10-03), its left edge where it is. The whole column of
            -- four, whether or not the other three show now (out of a group
            -- they do not): measured from the first frame's box down.
            local frames = Core.Frames
            local entry = Entry("party")
            local box = entry and Snap.AnchorBox(entry)
            if not (box and frames and frames.PartyColumn and frames.db) then return end
            local column = frames.PartyColumn(frames.db)
            Snap.Shift(entry, 0, (H() + column) / 2 - box.t)
        end },
        { "tooltip", function()
            -- EDGE_GAP in from the screen's bottom right corner. (Anchored to
            -- the damage meter until it went back to the game: let go of.)
            LetGo("tooltip")
            MoveX("tooltip", "right", W() - Places.EDGE_GAP)
            MoveY("tooltip", "bottom", Places.EDGE_GAP)
        end },
        -- The castbar first, at its own default height (Castbar.lua,
        -- TOP_SHARE: the row over the unit frames), centred; then the
        -- cooldowns at the player frame's left edge, level with it. (The
        -- castbar used to take the cooldowns' height - and the cooldowns,
        -- put back before the castbar on Reset everything, had guessed one
        -- near the top of the screen: both ended up there, 2026-10-03.)
        { "castbar", function()
            MoveX("castbar", "boxmiddle", W() / 2)
            local castbar = Core.Castbar
            local share = castbar and castbar.TOP_SHARE
            if share then MoveY("castbar", "frametop", H() * (1 - share)) end
        end },
        { "cooldowns", function()
            MoveX("cooldowns", "frameleft", FrameLeft("player"))
            MoveY("cooldowns", "frametop", FrameTop("castbar"))
        end },
        { "threat", function()
            MoveX("threat", "frameleft", FrameLeft("target"))
            MoveY("threat", "frametop", FrameTop("castbar"))
        end },
        { "toasts", function()
            -- Over the focus frame, left edges level, the bottom level with
            -- the cooldowns' (the player, 2026-10-11), anchored to nothing;
            -- the toasts grow up from there.
            LetGo("toasts")
            local focus, cooldowns = BoxOf("focus"), BoxOf("cooldowns")
            if focus then MoveX("toasts", "left", focus.l) end
            if cooldowns then MoveY("toasts", "bottom", cooldowns.b) end
        end },
    }

    -- The settings the layout needs: Action Bars 1 to 5 twelve buttons in two
    -- rows, 2 apart (the player, 2026-10-03); 6 to 8 one button wide ("all":
    -- as many rows as buttons).
    local TWO_ROWS = { Buttons = 12, Rows = 2, Spacing = 2 }
    local BAR_SETTINGS = {
        bar1 = TWO_ROWS, bar2 = TWO_ROWS, bar3 = TWO_ROWS, bar4 = TWO_ROWS, bar5 = TWO_ROWS,
        bar6 = { Rows = "all" }, bar7 = { Rows = "all" }, bar8 = { Rows = "all" },
    }
    local BAR_ORDER = { "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8" }
    local function BarSettings(ids)
        local bars = Core.ActionBars
        if not (bars and bars.db) then return end
        local any = false
        for _, key in ipairs(BAR_ORDER) do
            if not ids or ids[key] then
                for _, setting in ipairs({ "Buttons", "Rows", "Spacing" }) do
                    local value = BAR_SETTINGS[key][setting]
                    if value == "all" then value = tonumber(bars.db[key .. "Buttons"]) or 12 end
                    if value ~= nil and bars.db[key .. setting] ~= value then
                        -- (Reset Position in Unlock Mode: an unsaved change.)
                        if Core.NoteEdit then Core.NoteEdit(bars, key .. setting) end
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

    -- (Before version 2 the pet bar and the pet's unit frame were both "pet"
    -- in Unlock Mode: the pet bar was made to hang from the player frame
    -- with the pet frame's anchor. That anchor made again, from where the
    -- pet frame is; the pet bar back in the game's pet bar's place.)
    local function Repair()
        local db = Snap.db
        if type(db.snaps) == "table" then db.snaps.pet = nil end
        if type(db.anchoredByDefault) == "table" then db.anchoredByDefault.pet = nil end
        local bars = Core.ActionBars
        if bars and bars.db and bars.ResetPlace then
            bars.db.petPlaced = nil
            bars.ResetPlace("pet")
        end
        if Snap.AnchorDefaults() then Snap.ScheduleDefaults() end
    end

    -- The whole layout. Answers whether it was laid out.
    function Places.Apply()
        if not Ready() then return false end
        local ok, err = pcall(Repair)
        if not ok and geterrorhandler then geterrorhandler()(err) end
        BarSettings()
        for _, step in ipairs(STEPS) do
            if Entry(step[1]) then
                local ok, err = pcall(step[2])
                if not ok and geterrorhandler then geterrorhandler()(err) end
            end
        end
        Snap.db.defaultPlaces = Places.VERSION
        return true
    end

    -- PATCHES: a small change to the layout, for a character that has the
    -- layout already - only that change made, nothing else laid out again
    -- (whatever the player has moved since stays). [version] = what takes a
    -- character from the version before to this one.
    Places.PATCHES = {
        -- Action Bar 1 3 higher (what hangs from it comes along); the stance
        -- bar's anchor to it is a default anchor (Core\Snap.lua).
        [5] = function()
            local entry = Entry("bar1")
            if entry then Snap.Shift(entry, 0, Places.BAR1_UP) end
        end,
        -- The player frame 20 further left, the target 20 further right
        -- (the focus and target of target, anchored to them, come along).
        [6] = function()
            local player, target = Entry("player"), Entry("target")
            if player then Snap.Shift(player, -20, 0) end
            if target then Snap.Shift(target, 20, 0) end
        end,
        -- The bag bar, new to Unlock Mode: into the bottom right corner.
        [7] = function() Places.Place("bags") end,
        -- The chat into the bottom left corner, the bag bar into the bottom
        -- right one.
        [8] = function()
            Places.Place("chat")
            Places.Place("bags")
        end,
        -- The bag bar back in the bottom right corner.
        [9] = function() Places.Place("bags") end,
        -- The chat 15 in from its corner.
        [10] = function() Places.Place("chat") end,
        -- 150 high, its size now its whole panel's.
        [11] = function() Places.Place("chat") end,
        -- 200 high.
        [12] = function() Places.Place("chat") end,
        -- The tooltip, new to Unlock Mode.
        [13] = function() Places.Place("tooltip") end,
        -- The castbar and the cooldowns back over the unit frames (they had
        -- been laid out near the top of the screen).
        [14] = function()
            Places.Place("castbar")
            Places.Place("cooldowns")
        end,
        -- The party's column exactly centred top to bottom.
        [15] = function() Places.Place("party") end,
        -- The threat bar, new: over the target frame.
        [16] = function() Places.Place("threat") end,
        -- The damage meter gone back to the game: the tooltip, anchored to
        -- it until now, into the bottom right corner.
        [17] = function() Places.Place("tooltip") end,
        -- The chat's tabs in a sidebar left of it: wider, back in its corner.
        [18] = function() Places.Place("chat") end,
        -- Its letters over it, the box typed into under it: back in its corner.
        [19] = function() Places.Place("chat") end,
        -- The loot toasts, new: over the chat.
        [20] = function() Places.Place("toasts") end,
        -- The loot toasts over the focus frame, level with the cooldowns.
        [21] = function() Places.Place("toasts") end,
        -- The loot toasts anchored to nothing (21 anchored them to the focus
        -- frame): let go of, where they are.
        [22] = function() LetGo("toasts") end,
    }

    -- The layout brought up to date: patched from where it was, or (never
    -- had, or reset) laid out whole. Answers whether it was.
    function Places.Update()
        local had = tonumber(Snap.db and Snap.db.defaultPlaces) or 0
        if had < 4 then return Places.Apply() end
        if not Ready() then return false end
        for version = had + 1, Places.VERSION do
            local patch = Places.PATCHES[version]
            if patch then
                local ok, err = pcall(patch)
                if not ok and geterrorhandler then geterrorhandler()(err) end
            end
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
                local ok, err = pcall(step[2])
                if not ok and geterrorhandler then geterrorhandler()(err) end
                return true
            end
        end
        return false
    end

    -- Laid out once every piece has its own first place: a couple of
    -- seconds after the world is up (the action bars take theirs after one),
    -- out of combat. Not again once done, unless the settings were reset.
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
            -- (In combat: again as it ends, PLAYER_REGEN_ENABLED.)
            if Places.Due() and not Places.Update() and not InCombatLockdown() then Places.Schedule() end
        end)
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function() Places.Schedule() end)
end
