-- The bags' Clean Up button sorts the addon's way (the player asked,
-- 2026-10-10): partial stacks joined, then every item in order - by one of
-- the picks below first, the others after it in this order. A left-click
-- sorts by the last pick; a right-click opens a small menu to pick from (the
-- player, same day: on the button, not in the options). The pick is Menus'
-- "bagSort", kept per character.
--
--   Type          the game's item classes in their own order (Enum.ItemClass),
--                 each class's subclasses in theirs
--   Rarity        the best first; within one, the higher item level
--   Unit Value    what one sells to a vendor for, the dearest first (saved as
--                 "value", its name before Stack Value came, same day)
--   Stack Value   what the whole stack sells for, the dearest first
--   Name          A to Z
--
-- Copies of one item stay together, the fullest stack first (Stack Value
-- alone can part them), and junk (Poor, grey) always comes last, as the
-- game's own Clean Up leaves it (the player, 2026-10-10).
--
-- THE BUTTON is the addon's own, laid exactly over the game's
-- (BagItemAutoSortButton, Mainline\ContainerFrame.xml) as its child and in its
-- art, so it goes wherever the game puts that button and shows only when the
-- game shows it (the backpack or the combined bags, not on a gamepad). The
-- game's button underneath is never touched; it is simply never clicked, so
-- the game's own sort (C_Container.SortBags - the server's, in its own order)
-- is never asked for.
-- It is lifted RAISE levels above the game's button every time it shows: the
-- client's own gamepad bag bar (GamepadBagBar, Camelot\MainMenuBarBagButtons.xml,
-- 215x50 at the combined window's top right) lies over that corner at the
-- button's level and took its clicks (the player, 2026-10-10: "not
-- clickable"). Shown again, the button is levelled again, wherever the game
-- has hung its parent by then.
--
-- THE ORDER is the one the player reads: the slots as the combined bags window
-- draws them, top row first, left to right (its grid fills from the bottom
-- right, so the bags' own numbering is no guide); the empty slots end up last.
-- Taken once as a run starts. Separate bag windows: the bags' own order.
--
-- THE SORT moves items as EllesmereUI Bags' does (DoPhysicalSort): the item
-- picked up and put down on another slot, which swaps the two or, on a stack
-- of its own kind, tops that up. A slot moved stays locked until the server
-- answers, so it can move once a batch; every move of a batch goes out at
-- once, and the next batch waits until the server has answered for all of
-- them (looking every BEAT). The stacks are joined first, then the order takes
-- two batches however mixed the bags are (Order). The player saw it trickle
-- in one item at a time (2026-10-10, twice): first from a planner that settled
-- one slot a pass, then from passes that went out before the server had
-- answered the last, while most slots were still locked. Copies of one item
-- are one kind: any of them will do in a slot, so two are never swapped (which
-- would join them instead).
--
-- WHICH BAGS: the backpack, always, and every bag any item fits in - not a
-- quiver, an ammo pouch or a soul bag (one kind only: its family is not 0).
-- Neither the backpack's family nor the game's "Ignore" flags for Clean Up
-- are asked: while they were, the backpack was left out on this client (the
-- player, 2026-10-10: "sort never touches the Backpack").
--
-- A RUN STOPS when nothing is left to move, when the player takes something
-- onto the cursor (it is theirs), after GIVE_UP looks in which nothing could
-- be sent (a slot a trade or the mail holds locked never frees), or after
-- MAX_TICKS whatever happens. A batch the server is slow to answer is waited
-- for PATIENCE looks at most; then the next is planned around the slots still
-- locked, rather than the run sitting on them. Until 2026-10-11 a run simply
-- ended after ten seconds and waited on every lock, and the player found
-- items left behind ("some items stuck"). Another click starts a new run.

local Sort = {}
DogsForeverUI.Menus.BagSort = Sort

do -- private scope

    local NS = DogsForeverUI.Menus

    local BACKPACK = 0          -- Enum.BagIndex.Backpack
    local BEAT = 0.1            -- seconds between looks at the bags
    local PATIENCE = 10         -- looks to wait for the server to answer a batch
    local GIVE_UP = 50          -- looks with nothing sent before a run ends
    local MAX_TICKS = 600       -- looks a run may take at all: a minute
    local RAISE = 100           -- frame levels over the game's button: above all else in the bag window

    -- The picks; the first is the default.
    local SORTS = {
        { value = "type",   label = "Type" },
        { value = "rarity", label = "Rarity" },
        { value = "value",  label = "Unit Value" },
        { value = "stack",  label = "Stack Value" },
        { value = "name",   label = "Name" },
    }

    -- Each criterion: true when a goes first, false when b does, nil on a tie.
    local COMPARE = {
        type = function(a, b)
            if a.class ~= b.class then return a.class < b.class end
            if a.subclass ~= b.subclass then return a.subclass < b.subclass end
        end,
        rarity = function(a, b)
            if a.quality ~= b.quality then return a.quality > b.quality end
            if a.level ~= b.level then return a.level > b.level end
        end,
        value = function(a, b)
            if a.price ~= b.price then return a.price > b.price end
        end,
        stack = function(a, b)
            local worthA, worthB = a.price * a.count, b.price * b.count
            if worthA ~= worthB then return worthA > worthB end
        end,
        name = function(a, b)
            if a.name ~= b.name then return a.name < b.name end
        end,
    }

    -- The player's pick first, the others after it.
    local function Criteria()
        local order = {}
        for _, sort in ipairs(SORTS) do
            if sort.value == NS.db.bagSort then
                table.insert(order, 1, sort)
            else
                order[#order + 1] = sort
            end
        end
        return order
    end

    local function Sorted(items)
        local order = Criteria()
        table.sort(items, function(a, b)
            local junkA, junkB = a.quality == Enum.ItemQuality.Poor, b.quality == Enum.ItemQuality.Poor
            if junkA ~= junkB then return junkB end
            for _, sort in ipairs(order) do
                local first = COMPARE[sort.value](a, b)
                if first ~= nil then return first end
            end
            if a.kind ~= b.kind then return a.kind < b.kind end
            if a.count ~= b.count then return a.count > b.count end
            return a.at < b.at
        end)
    end

    ---------------------------------------------------------------------------
    -- The bags.

    local function Sortable(bag)
        if bag == BACKPACK then return true end
        local _, family = C_Container.GetContainerNumFreeSlots(bag)
        return family == 0
    end

    -- Every slot the sort may use, in the order the player reads them.
    local function Slots()
        local slots, window = {}, _G.ContainerFrameCombinedBags
        if window and window:IsShown() then
            for _, button in window:EnumerateValidItems() do
                slots[#slots + 1] = { bag = button:GetBagID(), slot = button:GetID(),
                                      top = math.floor(button:GetTop() + 0.5), left = button:GetLeft() }
            end
            table.sort(slots, function(a, b)
                if a.top ~= b.top then return a.top > b.top end
                return a.left < b.left
            end)
        else
            for bag = BACKPACK, Constants.InventoryConstants.NumBagSlots do
                for slot = 1, C_Container.GetContainerNumSlots(bag) do
                    slots[#slots + 1] = { bag = bag, slot = slot }
                end
            end
        end
        local sortable, kept = {}, {}
        for _, place in ipairs(slots) do
            if sortable[place.bag] == nil then sortable[place.bag] = Sortable(place.bag) end
            if sortable[place.bag] then kept[#kept + 1] = place end
        end
        return kept
    end

    -- The items in the slots (`at`: the item's place in that list). `kind`
    -- names the item, `key` the item and its count: stacks with one key are
    -- interchangeable.
    local function Scan(slots)
        local items = {}
        for at, place in ipairs(slots) do
            local info = C_Container.GetContainerItemInfo(place.bag, place.slot)
            if info then
                local _, _, _, level, _, _, _, stack, _, _, price = C_Item.GetItemInfo(info.hyperlink)
                local _, _, _, _, _, class, subclass = C_Item.GetItemInfoInstant(info.itemID)
                local kind = info.itemID .. ":" .. info.itemName
                items[#items + 1] = {
                    at = at, id = info.itemID, kind = kind, key = kind .. ":" .. info.stackCount,
                    locked = info.isLocked, count = info.stackCount, stack = stack or 1,
                    class = class, subclass = subclass, quality = info.quality or 0,
                    level = level or 0, price = price or 0, name = info.itemName,
                }
            end
        end
        return items
    end

    local function Move(from, to)
        C_Container.PickupContainerItem(from.bag, from.slot)
        C_Container.PickupContainerItem(to.bag, to.slot)
        ClearCursor()
    end

    -- Partial stacks of one item put onto one another, two by two; what does
    -- not fit stays behind. The slots moved, or nil when none were.
    local function Stack(slots, items)
        local open, moved = {}, nil
        for _, item in ipairs(items) do
            if item.count < item.stack and not item.locked then
                local other = open[item.id]
                if other then
                    Move(slots[item.at], slots[other.at])
                    open[item.id] = nil
                    moved = moved or {}
                    moved[item.at], moved[other.at] = true, true
                else
                    open[item.id] = item
                end
            end
        end
        return moved
    end

    -- THE ORDER IN TWO BATCHES. Each slot out of place is given the slot its
    -- item goes to (a copy of the same item, or an empty slot, will do
    -- anywhere its kind is wanted), preferring the one whose own item belongs
    -- where this one is - a swap that settles both. That makes cycles: the
    -- item in c[0] goes to c[1], c[1]'s to c[2], ... and the last's to c[0].
    -- Every cycle is two reflections: swapping c[k] with c[L-k] leaves only
    -- pairs to swap, which the next batch does. So every slot moves at most
    -- once a batch, and the whole order takes two. The slots moved, and
    -- whether anything is still out of place.
    -- Two stacks of one item cannot be swapped: put down on each other they
    -- join. But the stacks are joined first, so two left out of place are a
    -- full one and a partial one, and the full one put down on the partial
    -- fills it and keeps the rest - their counts swapped.
    local EMPTY = ""

    local function Order(slots, items)
        Sorted(items)
        -- A locked slot (a batch not yet answered, a trade, the mail) stays
        -- as it is; the rest are sorted around it, and the run goes on
        -- looking until it frees.
        local locked = {}
        for _, item in ipairs(items) do
            if item.locked then locked[item.at] = true end
        end
        local open, want, have, held = {}, {}, {}, {}
        for i = 1, #slots do
            if not locked[i] then
                open[#open + 1] = i
                want[i], have[i] = EMPTY, EMPTY
            end
        end
        local n = 0
        for _, item in ipairs(items) do
            if not item.locked then
                n = n + 1
                want[open[n]] = item.key
                have[item.at], held[item.at] = item.key, item
            end
        end
        local wanting = {}      -- kind -> the slots out of place that want it
        for _, i in ipairs(open) do
            if have[i] ~= want[i] then
                wanting[want[i]] = wanting[want[i]] or {}
                table.insert(wanting[want[i]], i)
            end
        end
        local to, taken = {}, {}
        local function Send(i, both)
            for _, j in ipairs(wanting[have[i]]) do
                if not taken[j] and (not both or (have[j] == want[i] and not to[j] and not taken[i])) then
                    to[i], taken[j] = j, true
                    if both then to[j], taken[i] = i, true end
                    return
                end
            end
        end
        for _, both in ipairs({ true, false }) do
            for _, i in ipairs(open) do
                if have[i] ~= want[i] and not to[i] then Send(i, both) end
            end
        end

        local moved, pending, seen = {}, next(locked) ~= nil, {}
        local function Swap(a, b)
            if have[a] == have[b] then return end   -- the same kind: as good as swapped
            local x, y = held[a], held[b]
            if not x or (y and x.id == y.id and x.count < y.count) then a, b = b, a end
            Move(slots[a], slots[b])
            moved[a], moved[b] = true, true
        end
        for _, i in ipairs(open) do
            if to[i] and not seen[i] then
                pending = true
                local cycle, j = {}, i
                repeat
                    seen[j] = true
                    cycle[#cycle + 1] = j
                    j = to[j]
                until j == i
                local length = #cycle
                if length == 2 then
                    Swap(cycle[1], cycle[2])
                else
                    for k = 1, math.floor((length - 1) / 2) do
                        Swap(cycle[k + 1], cycle[length - k + 1])
                    end
                end
            end
        end
        return moved, pending
    end

    ---------------------------------------------------------------------------
    -- A run: a batch, then - once the server has answered for every slot it
    -- moved - the next.

    local run = 0

    local function Answered(slots, moved)
        for at in pairs(moved) do
            local info = C_Container.GetContainerItemInfo(slots[at].bag, slots[at].slot)
            if info and info.isLocked then return false end
        end
        return true
    end

    -- `idle`: looks since the last batch went out.
    local function Pass(id, slots, ticks, idle, moved)
        if id ~= run or ticks > MAX_TICKS or idle > GIVE_UP or GetCursorInfo() then return end
        local pending = true
        if idle >= PATIENCE or Answered(slots, moved) then
            local items = Scan(slots)
            local sent = Stack(slots, items)
            if not sent then sent, pending = Order(slots, items) end
            if next(sent) then moved, idle = sent, 0 end
        end
        if pending then
            C_Timer.After(BEAT, function() Pass(id, slots, ticks + 1, idle + 1, moved) end)
        end
    end

    local function Run()
        if GetCursorInfo() then return end
        PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
        run = run + 1
        Pass(run, Slots(), 1, 0, {})
    end

    ---------------------------------------------------------------------------
    -- The button.

    local function ShowTooltip(button)
        GameTooltip:SetOwner(button)
        GameTooltip:SetText(BAG_CLEANUP_BAGS, 1, 1, 1)
        local names = {}
        for i, sort in ipairs(Criteria()) do names[i] = sort.label:lower() end
        local last = table.remove(names)
        GameTooltip:AddLine(("Joins stacks, then sorts by %s, then %s and %s. Junk goes last."):format(
            table.remove(names, 1), table.concat(names, ", "), last), nil, nil, nil, true)
        GameTooltip:AddLine("Right-click to choose what it sorts by.", 1, 1, 1)
        GameTooltip:Show()
    end

    -- The pick, in the game's own context menu (as the bag's gear menu).
    local function IsPicked(value) return NS.db.bagSort == value end
    local function Pick(value) NS.db.bagSort = value end

    local function SortMenu(_, root)
        root:CreateTitle("Sort bags by")
        for _, sort in ipairs(SORTS) do
            root:CreateRadio(sort.label, IsPicked, Pick, sort.value):SetResponse(MenuResponse.Close)
        end
    end

    local function OnClick(button, mouseButton)
        if mouseButton == "RightButton" then
            GameTooltip:Hide()
            MenuUtil.CreateContextMenu(button, SortMenu)
        else
            Run()
        end
    end

    function Sort:Apply()
        local game = _G.BagItemAutoSortButton
        if not game then return end
        local button = CreateFrame("Button", nil, game)
        button:SetAllPoints(game)
        button:SetNormalAtlas("bags-button-autosort-up")
        button:SetPushedAtlas("bags-button-autosort-down")
        local glow = button:CreateTexture(nil, "HIGHLIGHT")
        glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        glow:SetBlendMode("ADD")
        glow:SetSize(24, 23)
        glow:SetPoint("CENTER")
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnShow", function() button:SetFrameLevel(game:GetFrameLevel() + RAISE) end)
        button:SetScript("OnClick", OnClick)
        button:SetScript("OnEnter", ShowTooltip)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.button = button
    end
end
