-- Taking the game's XP bar - and its reputation bar, which the addon's bar
-- shows instead while a faction is watched - off screen, and giving them back.
--
-- FADED, AND NOTHING ELSE. The game's XP bar lives in a status-tracking
-- container that is part of the stack the protected action bars are laid out
-- on: showing or hiding a container re-lays that stack, and doing that from
-- addon code is exactly where blocked actions come from. So nothing here is
-- shown, hidden, moved or resized. The parts of the container that belong to
-- the XP bar are faded to nothing instead - the bar, the frame art round it and
-- its segment dividers - which is allowed in combat and undone by setting the
-- alpha back.
--
-- ONLY WHILE IT IS ONE OF THOSE. A container shows one bar at a time and the
-- game chooses which: XP, or the watched reputation (which the addon's bar
-- shows instead, see XPBar.lua), or another bar this client may have, which
-- stays the game's. So this is asked again every time the game
-- changes what a container shows (`ApplyPendingBarToShow`) and every time it
-- re-lays the dividers (`UpdateDividers`, which hands out fresh ones at full
-- opacity). Both are followed with hooksecurefunc: after the game's own code,
-- never instead of it. So are the XP bar's own OnShow and the manager's
-- UpdateBarsShown (every zone change and loading screen), after the game's
-- bar was once seen beside the addon's following a zone change.
--
-- The space the container takes in the stack is the game's to keep; the addon's
-- own bar sits there by default.

local BlizzardXPBar = {}
DogsForeverUI.XPBar.BlizzardXPBar = BlizzardXPBar

do -- private scope

    local NS = DogsForeverUI.XPBar

    local CONTAINERS = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }

    local hooked = {}
    local faded = {}       -- region -> the alpha it had, for everything faded here

    local function BarIndex(key)
        local info = _G.StatusTrackingBarInfo
        return type(info) == "table" and type(info.BarsEnum) == "table"
            and info.BarsEnum[key] or nil
    end

    -- The game's bars this one stands in for: its XP bar, and its reputation
    -- bar - shown only while a faction is watched ("Show as experience bar"),
    -- which is exactly when this bar shows that reputation instead.
    local function Ours(index)
        return index ~= nil and (index == BarIndex("Experience") or index == BarIndex("Reputation"))
    end

    local function Fade(region)
        if not region or type(region.SetAlpha) ~= "function" then return end
        if faded[region] == nil then faded[region] = region:GetAlpha() end
        region:SetAlpha(0)
    end

    local function Restore(region)
        if faded[region] == nil then return end
        region:SetAlpha(faded[region])
        faded[region] = nil
    end

    -- The parts of a container that are the bar's it shows: the bar, the frame
    -- art round it and its dividers.
    local function Parts(container)
        local parts = {}
        local index = container.shownBarIndex
        local bar = Ours(index) and type(container.bars) == "table" and container.bars[index]
        if bar then parts[#parts + 1] = bar end
        if container.BarFrameTexture then parts[#parts + 1] = container.BarFrameTexture end
        local pool = container.HorizontalDividersPool
        if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
            for divider in pool:EnumerateActive() do parts[#parts + 1] = divider end
        end
        return parts
    end

    local function ShouldHide(container)
        return NS.db.enabled and Ours(container.shownBarIndex)
    end

    local editMode = {}

    local function RefreshContainer(container)
        local hide = ShouldHide(container)
        for _, part in ipairs(Parts(container)) do
            if hide then Fade(part) else Restore(part) end
        end
        -- Gone from Edit Mode too while what it shows is ours; a container
        -- showing another bar (honor) is the game's to place as ever.
        DogsForeverUI.HoldEditMode(editMode, container, hide and true or false)
        -- The XP or reputation bar the container no longer shows - the game
        -- has hidden it - is given its alpha back, ready for its next turn.
        for _, key in ipairs({ "Experience", "Reputation" }) do
            local index = BarIndex(key)
            local bar = index and type(container.bars) == "table" and container.bars[index]
            if bar and not (hide and index == container.shownBarIndex) then Restore(bar) end
        end
        -- Something faded earlier that is no longer one of the parts - a
        -- divider the pool has taken back - is given its alpha back too.
        if not hide then
            for region in pairs(faded) do
                if region.GetParent and region:GetParent() == container then Restore(region) end
            end
        end
    end

    local function Hook(container)
        if hooked[container] or type(hooksecurefunc) ~= "function" then return end
        hooked[container] = true

        -- Nothing of the game's writes these parts' alpha (checked across
        -- Blizzard_StatusTrackingBar and Edit Mode), so following what the
        -- container shows and how it lays out its dividers is all it takes.
        for _, method in ipairs({ "ApplyPendingBarToShow", "UpdateDividers" }) do
            if type(container[method]) == "function" then
                pcall(hooksecurefunc, container, method, function() RefreshContainer(container) end)
            end
        end

        -- And the XP bar itself, the moment it is shown, whatever showed it:
        -- a zone change let the game's bar through beside the addon's, so
        -- the fade no longer waits on the container's bookkeeping. A bar that
        -- is being shown and is the XP bar is faded there and then; the rest
        -- of the container follows in the hooks above.
        for _, key in ipairs({ "Experience", "Reputation" }) do
            local index = BarIndex(key)
            local bar = index and type(container.bars) == "table" and container.bars[index]
            if bar and type(bar.HookScript) == "function" then
                bar:HookScript("OnShow", function(self)
                    if NS.db and NS.db.enabled then Fade(self) end
                end)
            end
        end
        if type(container.HookScript) == "function" then
            container:HookScript("OnShow", function() RefreshContainer(container) end)
        end
    end

    local managerFollowed = false

    function BlizzardXPBar.Refresh()
        for _, name in ipairs(CONTAINERS) do
            local container = _G[name]
            if type(container) == "table" and type(container.SetAlpha) == "function" then
                Hook(container)
                RefreshContainer(container)
            end
        end
        -- The game sorting out which container shows which bar - on every
        -- zone change, loading screen and reputation change - is followed as
        -- a whole too.
        local manager = _G.StatusTrackingBarManager
        if not managerFollowed and type(manager) == "table"
           and type(manager.UpdateBarsShown) == "function" then
            managerFollowed = true
            pcall(hooksecurefunc, manager, "UpdateBarsShown", BlizzardXPBar.Refresh)
        end
    end
end
