-- MODULE: Loot rolls  (DogsForeverUI.LootRolls, settings section "loot")
--
-- Where the game's group loot roll windows appear. By default the first one
-- sits exactly in the middle of the screen; Unlock UI shows a frame of the
-- same size in the addon's look to drag, and the Positions section has its X
-- and Y. More rolls stack upwards from the first, as the game stacks them.
--
-- The windows stay the game's own. The game lays them out in
-- GroupLootContainer_Update, stacked from its container's bottom edge; a
-- post-hook anchors each one to this module's holder instead, with the same
-- spacing. Nothing of the game's is called or replaced, and the container
-- itself - part of the bottom managed-frame layout, beside the protected action
-- bars - is never touched.

DogsForeverUI.LootRolls = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.LootRolls
    local Style = DogsForeverUI.Style

    NS.key = "loot"
    NS.title = "Loot rolls"
    NS.defaults = { unlocked = false }
    NS.placement = { barLeft = true, barTop = true, autoPlaced = true }

    -- The game's roll window, and the distance between two stacked ones
    -- (GroupLootFrameBaseTemplate; GroupLootContainer_OnLoad's reservedSize).
    local WIDTH, HEIGHT, STEP = 277, 67, 100

    -- One roll window's place: what is dragged while unlocked, hidden otherwise.
    local holder = CreateFrame("Frame", "DogsForeverUILootRolls", UIParent)
    holder:SetFrameStrata("DIALOG")
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    holder.bg = holder:CreateTexture(nil, "BACKGROUND")
    holder.bg:SetAllPoints(holder)
    holder.border = Style.AddBorder(holder)
    holder.labels = Style.AddPlacementLabels(holder)
    holder:Hide()
    NS.holder = holder

    local function Size()
        local frame = _G.GroupLootFrame1
        local ok, w, h = pcall(function() return frame:GetSize() end)
        if ok and type(w) == "number" and w > 0 and type(h) == "number" and h > 0 then
            return w, h
        end
        return WIDTH, HEIGHT
    end

    -- The middle of the screen, exactly. Worked out again on entering the
    -- world until the player puts it somewhere (UIParent has no real size at
    -- ADDON_LOADED).
    local function Place()
        local db = NS.db
        local w, h = Size()
        db.barLeft = ((GetScreenWidth() or 0) - w) / 2
        db.barTop = -((GetScreenHeight() or 0) - h) / 2
        db.autoPlaced = true
    end

    function NS.Normalise(db)
        if db.barLeft == nil or db.barTop == nil then Place() end
    end

    -- Every roll window on screen to the holder: the first centred on it, the
    -- rest above, STEP apart, in the game's own order.
    local function Anchor()
        local container = _G.GroupLootContainer
        if type(container) ~= "table" or type(container.rollFrames) ~= "table" then return end
        if InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() then return end
        local step = container.reservedSize or STEP
        for i = 1, container.maxIndex or 0 do
            local frame = container.rollFrames[i]
            if frame then
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", holder, "CENTER", 0, step * (i - 1))
            end
        end
    end
    if type(GroupLootContainer_Update) == "function" then
        hooksecurefunc("GroupLootContainer_Update", Anchor)
    end

    local function Refresh()
        local db = NS.db
        local w, h = Size()
        holder:ClearAllPoints()
        holder:SetSize(w, h)
        holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.barLeft, db.barTop)
        holder:SetUserPlaced(false)
        holder:EnableMouse(db.unlocked)
        Style.SetBackground(holder.bg, true)
        Style.ShowPlacementLabels(holder.labels, holder, "Loot rolls", db.unlocked)
        holder:SetShown(db.unlocked)
        Anchor()
    end

    holder:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and NS.db.unlocked then self:StartMoving() end
    end)
    holder:SetScript("OnMouseUp", function(self, button)
        if DogsForeverUI.RightClickLock(NS, button) then return end
        if button ~= "LeftButton" or not NS.db.unlocked then return end
        self:StopMovingOrSizing()
        local db = NS.db
        db.autoPlaced = false
        db.barLeft = self:GetLeft()
        db.barTop = -(GetScreenHeight() - self:GetTop())
        Refresh()
        DogsForeverUI.RefreshOptions()
    end)

    NS:RegisterEvent("PLAYER_ENTERING_WORLD")
    NS:SetScript("OnEvent", function()
        if NS.db.autoPlaced then Place() end
        Refresh()
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

    DogsForeverUI:RegisterModule(NS)
end
