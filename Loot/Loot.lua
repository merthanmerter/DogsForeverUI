-- Loot: two modules, the game's roll windows placed and a toast for each item looted.

-------------------------------------------------------------------------------
-- MODULE: Loot rolls  (DogsForeverUI.LootRolls, settings section "loot")
-- The game's group loot roll windows on the addon's holder: the first in the
-- middle of the screen by default, more stacked upwards (a post-hook on
-- GroupLootContainer_Update). The managed container itself is never touched.
-------------------------------------------------------------------------------

DogsForeverUI.LootRolls = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.LootRolls
    local Style = DogsForeverUI.Style

    NS.key = "loot"
    NS.title = "Loot rolls"
    NS.defaults = { unlocked = false }
    NS.placement = { barLeft = true, barTop = true, autoPlaced = true }

    local WIDTH, HEIGHT = 277, 67       -- a roll window

    -- One roll window's place: shown in the look while unlocked, hidden otherwise.
    local holder = CreateFrame("Frame", "DogsForeverUILootRolls", UIParent)
    holder:SetFrameStrata("DIALOG")
    holder.bg = holder:CreateTexture(nil, "BACKGROUND")
    holder.bg:SetAllPoints(holder)
    Style.SetBackground(holder.bg)
    holder.border = Style.AddBorder(holder)
    holder:Hide()
    NS.holder = holder

    local function Size()
        local frame = _G.GroupLootFrame1
        if frame then
            local w, h = frame:GetWidth(), frame:GetHeight()
            if w > 0 and h > 0 then return w, h end
        end
        return WIDTH, HEIGHT
    end

    -- The middle of the screen; again on entering the world until the player
    -- places it (UIParent has no real size at ADDON_LOADED).
    local function Place()
        local db = NS.db
        local w, h = Size()
        db.barLeft = (GetScreenWidth() - w) / 2
        db.barTop = -(GetScreenHeight() - h) / 2
        db.autoPlaced = true
    end

    function NS.Normalise(db)
        if db.barLeft == nil or db.barTop == nil then Place() end
    end

    -- Every roll window to the holder: the first centred on it, the rest the game's distance above.
    local function Anchor()
        local container = _G.GroupLootContainer
        if not (container and container.rollFrames) or DogsForeverUI.Call(InputUtil, "IsGamepadUIEnabled") then return end
        for i = 1, container.maxIndex do
            local frame = container.rollFrames[i]
            if frame then
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", holder, "CENTER", 0, container.reservedSize * (i - 1))
            end
        end
    end
    hooksecurefunc("GroupLootContainer_Update", Anchor)

    local function Refresh()
        local db = NS.db
        DogsForeverUI.Snap.Put(holder, db)
        holder:SetSize(Size())
        holder:EnableMouse(db.unlocked)
        holder:SetShown(db.unlocked)
        Anchor()
    end

    DogsForeverUI.Snap.Piece(holder, NS, { name = "Loot Rolls", id = "loot" }, Refresh)

    NS:RegisterEvent("PLAYER_ENTERING_WORLD")
    NS:SetScript("OnEvent", function()
        if NS.db.autoPlaced then Place() end
        Refresh()
    end)

    NS.Init = Refresh
    NS.Refresh = Refresh

    DogsForeverUI:RegisterModule(NS)
end

-------------------------------------------------------------------------------
-- MODULE: Loot toasts  (DogsForeverUI.LootToasts, settings section "toasts")
-- A toast for each item looted (FunLoot's idea): the icon in the game's round
-- ring, its name in its quality's colour (a stack with the bags' count) and
-- what it sells for; money added up on one toast. A roll won is a toast with a
-- larger icon (ROLL_SIZE), "You Won!" and the roll, replacing the game's roll-won alert.
-- A toast stays DURATION seconds (held under the mouse), then fades; the same
-- item again adds to it. Newest at the holder, older pushed up (or down).
-------------------------------------------------------------------------------

DogsForeverUI.LootToasts = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.LootToasts
    local Core = DogsForeverUI
    local Style = Core.Style

    local Layout

    NS.key = "toasts"
    NS.title = "Loot toasts"
    NS.defaults = {
        unlocked = false,
        barWidth = 150,          -- the player frame's width
        barHeight = 28,
        growDirection = "up",
    }
    NS.placement = { barLeft = true, barTop = true, autoPlaced = true }

    local OLD_DEFAULT_WIDTH = 260               -- the first version's default, saved: taken as the default
    local DURATION, MAX = 5, 5
    local GAP = 4                               -- between two toasts
    local ROLL_SIZE = 1.6                       -- a roll won's round piece, of the toasts' height
    -- The game's round button as LibDBIcon draws it (31 across): the ring 50, the icon 24.
    local RING, ICON = 50 / 31, 24 / 31
    local RING_FILE = "Interface\\Minimap\\MiniMap-TrackingBorder"
    local MONEY_KEY, MONEY_ICON = "money", "Interface\\Icons\\INV_Misc_Coin_01"
    -- The game's roll-won alert's icons (LootWonAlertFrame_SetUp): need, greed.
    local ROLL_ICONS = { "Interface\\Buttons\\UI-GroupLoot-Dice-Up", "Interface\\Buttons\\UI-GroupLoot-Coin-Up" }
    local OWNED = " |cff999999(%d)|r"           -- a stackable item: how many are in the bags
    -- Shown while placing: a roll won, money and a stack, bottom-most last.
    local SAMPLES = {
        { key = "item:12784", name = "Arcanite Reaper", quality = 4, icon = "Interface\\Icons\\INV_Axe_09",
          price = 90000, stack = 1, count = 1, roll = 87, rollType = 1 },
        { key = MONEY_KEY, copper = 10203 },
        { key = "item:2589", name = "Linen Cloth", quality = 1, icon = "Interface\\Icons\\INV_Fabric_Linen_01",
          price = 10, stack = 20, count = 2 },
    }

    -- One of the game's chat formats as a pattern: %s and %d captured.
    local function Pattern(text)
        return (text:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0"):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)"))
    end
    local LOOT_MULTIPLE = "^" .. Pattern(LOOT_ITEM_SELF_MULTIPLE) .. "$"
    local LOOT_ONE = "^" .. Pattern(LOOT_ITEM_SELF) .. "$"
    local COINS = { [Pattern(GOLD_AMOUNT)] = 10000, [Pattern(SILVER_AMOUNT)] = 100, [Pattern(COPPER_AMOUNT)] = 1 }

    -- The game's roll-won alert: these toasts are it now (its other alerts stay).
    AlertFrame:UnregisterEvent("LOOT_ITEM_ROLL_WON")

    -- The first toast's place: dragged while unlocked, hidden otherwise.
    local holder = CreateFrame("Frame", "DogsForeverUILootToasts", UIParent)
    holder:Hide()
    NS.holder = holder

    local active, pool = {}, {}         -- on screen newest first; put away
    NS.active = active

    -- Every toast counts down while it shows; one gone out is put away.
    local function Release(i)
        local t = table.remove(active, i)
        Style.HideNow(t)
        t.key, t.count, t.copper, t.roll, t.rollType, t.expected, t.hovered, t.stack, t.sample = nil
        pool[#pool + 1] = t
    end
    local wake = Core.Waker(function(elapsed)
        local released = false
        for i = #active, 1, -1 do
            local t = active[i]
            if not t.hovered then
                t.left = t.left - elapsed
                if t.left <= 0 then
                    if t:IsShown() then
                        Style.FadeOut(t)
                    else
                        Release(i)
                        released = true
                    end
                end
            end
        end
        if released then Layout() end
        return active[1] ~= nil
    end)

    local function Make()
        local t = CreateFrame("Frame", nil, UIParent)
        t:SetMouseMotionEnabled(true)       -- hovered only: clicks go through
        t.icon = t:CreateTexture(nil, "ARTWORK")
        t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local round = t:CreateMaskTexture()
        round:SetAtlas("CircleMask")
        round:SetAllPoints(t.icon)
        t.icon:AddMaskTexture(round)
        t.ring = t:CreateTexture(nil, "OVERLAY")
        t.ring:SetTexture(RING_FILE)
        t.text = t:CreateFontString(nil, "OVERLAY")
        t.text:SetJustifyH("LEFT")
        t.text:SetShadowOffset(0, 0)        -- its outline only (see Style.SingleLine)
        Style.SetFont(holder, t.text)

        t:SetScript("OnEnter", function(self)
            self.hovered = true
            self.left = math.max(self.left, DURATION)
            Style.FadeIn(self)
            if self.key ~= MONEY_KEY then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.key)
                GameTooltip:Show()
            end
        end)
        t:SetScript("OnLeave", function(self)
            self.hovered = false
            GameTooltip:Hide()
        end)
        t:Hide()
        return t
    end

    -- Stacked from the holder: the round piece as high as set (a roll won's
    -- ROLL_SIZE times that), the text in the rest of the width, the toast as high as the taller.
    function Layout()
        local db = NS.db
        local up = db.growDirection ~= "down"
        local point, rel, gap = up and "BOTTOMLEFT" or "TOPLEFT", up and "TOPLEFT" or "BOTTOMLEFT", up and GAP or -GAP
        local w, h = db.barWidth, db.barHeight
        for i, t in ipairs(active) do
            local before = active[i - 1]
            local size = t.roll and math.floor(ROLL_SIZE * h + 0.5) or h
            Style.SetFont(holder, t.text)
            t.text:SetWidth(w - size)
            t:ClearAllPoints()
            if before then t:SetPoint(point, before, rel, 0, gap) else t:SetPoint(point, holder, point) end
            t:SetSize(w, math.max(size, t.text:GetStringHeight()))
            t.icon:SetSize(size * ICON, size * ICON)
            t.icon:SetPoint("CENTER", t, "LEFT", size / 2, 0)
            t.ring:SetSize(size * RING, size * RING)
            t.ring:SetPoint("TOPLEFT", t, "LEFT", 0, size / 2)
            t.text:SetPoint("LEFT", t, "LEFT", size, 0)
        end
    end

    local function Find(key)
        for _, t in ipairs(active) do
            if t.key == key and not t.sample then return t end
        end
    end

    local function New(key)
        local t = table.remove(pool) or Make()
        t.key = key
        table.insert(active, 1, t)
        if #active > MAX then Release(#active) end
        return t
    end

    local function SetItem(t, name, quality, icon, price, stack)
        local c = ITEM_QUALITY_COLORS[quality]
        t.itemName, t.texture, t.price, t.stack = name, icon, price or 0, stack > 1
        t.colour = c and { c.r, c.g, c.b }
    end

    local function Coloured(colour, text)
        return colour and CreateColor(colour[1], colour[2], colour[3]):WrapTextInColorCode(text) or text
    end

    -- Its rows: the name (with how many, and a stack's bag count) or Money,
    -- what it is worth, and a roll won.
    local function Write(t)
        local money = t.key == MONEY_KEY
        local copper = money and t.copper or t.price * t.count
        local rows = {}
        if money then
            rows[1] = Coloured(Style.GOLD, MONEY)
        else
            rows[1] = Coloured(t.colour, t.count > 1 and t.itemName .. " x" .. t.count or t.itemName)
            if t.stack then rows[1] = rows[1] .. OWNED:format(C_Item.GetItemCount(t.key)) end
        end
        if copper > 0 then
            rows[#rows + 1] = C_CurrencyInfo.GetCoinTextureString(copper, select(2, t.text:GetFont()))
        end
        if t.roll then
            local dice = ROLL_ICONS[t.rollType]
            rows[#rows + 1] = Coloured(Style.GOLD, YOU_WON_LABEL) .. " " .. (dice and "|T" .. dice .. ":0|t " or "") .. t.roll
        end
        t.text:SetText(table.concat(rows, "\n"))
    end

    -- Shown, or shown again from the start (fading in from wherever it is).
    local function Paint(t)
        t.icon:SetTexture(t.key == MONEY_KEY and MONEY_ICON or t.texture)
        Write(t)
        t.left = DURATION
        Layout()
        Style.FadeIn(t)
    end

    -- An item looted (`roll`: won with it). A roll won and its own loot line
    -- arrive one after the other, in either order: one toast for both.
    local function Loot(link, count, rollType, roll, waited)
        local name, _, quality, _, _, _, _, stack, _, icon, price = C_Item.GetItemInfo(link)
        if not name then
            -- (Not cached after all: shown once it is.)
            if not waited then
                Item:CreateFromItemLink(link):ContinueOnItemLoad(function() Loot(link, count, rollType, roll, true) end)
            end
            return
        end
        local t = Find(link)
        if roll then
            if not t or t.roll then
                t = New(link)
                t.count, t.expected = count, true
            end
            t.roll, t.rollType = roll, rollType
            PlaySound(SOUNDKIT.UI_EPICLOOT_TOAST)        -- the game's roll-won sound
        elseif t and t.expected then
            t.expected = nil
        elseif t then
            t.count = t.count + count
        else
            t = New(link)
            t.count = count
        end
        SetItem(t, name, quality, icon, price, stack)
        Paint(t)
        wake()
    end

    local function Money(copper)
        local t = Find(MONEY_KEY) or New(MONEY_KEY)
        t.copper = (t.copper or 0) + copper
        Paint(t)
        wake()
    end

    -- The samples while placing, never timed out; taken away after.
    local sampled = false
    local function Samples(on)
        if on == sampled then return end
        sampled = on
        for i = #active, 1, -1 do
            if active[i].sample then Release(i) end
        end
        if not on then return end
        for _, s in ipairs(SAMPLES) do
            local t = New(s.key)
            t.sample, t.count, t.copper, t.roll, t.rollType = true, s.count, s.copper, s.roll, s.rollType
            if s.name then SetItem(t, s.name, s.quality, s.icon, s.price, s.stack) end
            Paint(t)
            t.left = math.huge
        end
    end

    -- Halfway up the screen's left until Core\Defaults.lua puts it over the chat.
    local function Place()
        local db = NS.db
        db.barLeft = Core.DefaultPlaces.EDGE_GAP
        db.barTop = -(GetScreenHeight() - db.barHeight) / 2
        db.autoPlaced = true
    end

    function NS.Normalise(db)
        if db.barWidth == OLD_DEFAULT_WIDTH then db.barWidth = NS.defaults.barWidth end
        if db.barLeft == nil or db.barTop == nil then Place() end
    end

    local function Refresh()
        local db = NS.db
        Core.Snap.Put(holder, db)
        holder:SetSize(db.barWidth, db.barHeight)
        holder:EnableMouse(db.unlocked)
        holder:SetShown(db.unlocked)
        Samples(db.unlocked)
        Layout()
    end

    Core.Snap.Piece(holder, NS, { name = "Loot Toasts", id = "toasts" }, Refresh)

    NS:RegisterEvent("PLAYER_ENTERING_WORLD")
    NS:RegisterEvent("CHAT_MSG_LOOT")
    NS:RegisterEvent("CHAT_MSG_MONEY")
    NS:RegisterEvent("LOOT_ITEM_ROLL_WON")
    NS:RegisterEvent("BAG_UPDATE_DELAYED")
    NS:SetScript("OnEvent", function(_, event, text, ...)
        if event == "BAG_UPDATE_DELAYED" then
            -- (The loot line can arrive before the bags count it.)
            for _, t in ipairs(active) do
                if t.stack then Write(t) end
            end
            Layout()
        elseif event == "LOOT_ITEM_ROLL_WON" then
            local count, rollType, roll = ...
            Loot(text, count, rollType, roll)
        elseif event == "PLAYER_ENTERING_WORLD" then
            if NS.db.autoPlaced then Place() end
            Refresh()
        elseif issecretvalue(text) then
            return
        elseif event == "CHAT_MSG_LOOT" then
            local link, count = text:match(LOOT_MULTIPLE)
            link = link or text:match(LOOT_ONE)
            if link then Loot(link, tonumber(count) or 1) end
        else
            local copper = 0
            for pattern, worth in pairs(COINS) do
                copper = copper + (tonumber(text:match(pattern)) or 0) * worth
            end
            if copper > 0 then Money(copper) end
        end
    end)

    NS.Init = Refresh
    NS.Refresh = Refresh

    Core:RegisterModule(NS)
end
