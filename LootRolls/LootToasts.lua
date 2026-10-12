-- MODULE: Loot toasts  (DogsForeverUI.LootToasts, settings section "toasts")
--
-- What the player loots, a toast each (FunLoot's idea): the item's icon cut
-- round in the game's own round-button ring, and right beside it a block of
-- left-aligned rows, wrapping when a row is too long - its name in its
-- quality's colour (a stackable one with how many the bags now hold, in
-- grey) and what it sells for; money added up on one toast. While placing
-- (Unlock Mode, and its Preview) samples show: a stack, money and a roll won.
-- A roll won is a toast twice as large with a row more - "You Won!" and the
-- roll - and the game's own roll-won alert is switched off (AlertFrame's
-- LOOT_ITEM_ROLL_WON; its other alerts stay the game's).
--
-- Shown the moment the loot line arrives: the item was just looted, so the
-- client has it cached and everything is read at once (FunLoot waited on an
-- item load every time). A toast stays DURATION seconds - held while the
-- mouse is over it, its tooltip shown - then fades; the same item or money
-- again adds to the toast on screen. Nothing runs while no toast shows.
--
-- By default over the focus frame, left edges level, the bottom level with
-- the cooldowns' (Core\DefaultPlaces.lua), anchored to nothing; the newest
-- toast at the bottom, older ones pushed up (or down: its Grow setting).

DogsForeverUI.LootToasts = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.LootToasts
    local Core = DogsForeverUI
    local Style = Core.Style

    local Layout, Refresh

    NS.key = "toasts"
    NS.title = "Loot toasts"
    NS.defaults = {
        unlocked = false,
        barWidth = 150,          -- the player frame's width
        barHeight = 28,
        growDirection = "up",
    }
    NS.placement = { barLeft = true, barTop = true, autoPlaced = true }

    -- The width the first version had as its default and saved into the
    -- player's settings: taken as "the default", which is the player frame's.
    local OLD_DEFAULT_WIDTH = 260
    local DURATION, MAX = 5, 5
    local GAP = 4                               -- daylight between two toasts
    -- The game's round button, as LibDBIcon draws it (31 across): the ring 50
    -- across from its top left, the round backing - the icon here - 24
    -- across in its middle.
    local RING, ICON = 50 / 31, 24 / 31
    local RING_FILE = "Interface\\Minimap\\MiniMap-TrackingBorder"
    local MONEY_KEY, MONEY_ICON = "money", "Interface\\Icons\\INV_Misc_Coin_01"
    -- The game's roll-won alert's icons (LootWonAlertFrame_SetUp): need, greed.
    local ROLL_ICONS = { "Interface\\Buttons\\UI-GroupLoot-Dice-Up", "Interface\\Buttons\\UI-GroupLoot-Coin-Up" }
    local OWNED = " |cff999999(%d)|r"           -- a stackable item: how many are in the bags
    -- Shown while placing (Unlock Mode, and its Preview): a roll won, money
    -- and a stack, bottom-most last.
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

    -- The game's alert for a roll won: these toasts are it now.
    AlertFrame:UnregisterEvent("LOOT_ITEM_ROLL_WON")

    -- The first toast's place: what is dragged while unlocked (a sample
    -- toast on it), hidden otherwise.
    local holder = CreateFrame("Frame", "DogsForeverUILootToasts", UIParent)
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
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

    -- The toasts stacked from the holder, sized and lettered as set: the
    -- round piece as high as set (a won roll's twice that), the text block
    -- right against it in the rest of the width, both centred on the toast,
    -- which is as high as the taller of the two.
    function Layout()
        local db = NS.db
        local up = db.growDirection ~= "down"
        local point, rel, gap = up and "BOTTOMLEFT" or "TOPLEFT", up and "TOPLEFT" or "BOTTOMLEFT", up and GAP or -GAP
        local w, h = db.barWidth, db.barHeight
        for i, t in ipairs(active) do
            local before = active[i - 1]
            local size = t.roll and 2 * h or h
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

    -- Its rows: the name (an item's with how many, and - a stackable one -
    -- how many the bags hold) or Money, what it is worth, and a roll won.
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

    -- Over the left of the screen, halfway up, until the addon's layout puts
    -- it over the focus frame (Core\DefaultPlaces.lua).
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

    function Refresh()
        local db = NS.db
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.barLeft, db.barTop)
        holder:SetSize(db.barWidth, db.barHeight)
        holder:SetUserPlaced(false)
        holder:EnableMouse(db.unlocked)
        holder:SetShown(db.unlocked)
        Samples(db.unlocked)
        Layout()
    end

    holder:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and NS.db.unlocked then Core.Snap.Start(self) end
    end)
    -- Where it is now, kept: a drag's end, a nudge, or - locked or not -
    -- following what it is anchored to (Core\Snap.lua).
    local function SavePlace()
        local db = NS.db
        db.autoPlaced = false
        db.barLeft = holder:GetLeft()
        db.barTop = -(GetScreenHeight() - holder:GetTop())
        Refresh()
        Core.RefreshOptions()
    end
    holder:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" or not NS.db.unlocked then return end
        Core.Snap.Stop(self)
        SavePlace()
    end)
    Core.Snap.Register(holder, { save = SavePlace, name = "Loot Toasts", id = "toasts" })

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

    function NS.Unlock()
        NS.db.unlocked = true
        Refresh()
    end

    function NS.Lock()
        NS.db.unlocked = false
        holder:StopMovingOrSizing()
        Refresh()
    end

    NS.Init = Refresh
    NS.Refresh = Refresh

    Core:RegisterModule(NS)
end
