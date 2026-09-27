-- Spell and item IDs at the foot of tooltips - "Spell ID 2983", "Item ID
-- 6948" - small and grey, under everything else, so an ID can be read off
-- whatever is hovered and typed into the cooldown manager's list. The option
-- "Show IDs on tooltips" switches it.
--
-- How: one TooltipDataProcessor post-call for every kind of tooltip - the
-- same hook Blizzard's own add-ons use. The game calls it securely, so nothing
-- of this reaches the game's own tooltip code. What the ID is depends on the
-- kind of tooltip (Resolve):
--
--   * a spell, an aura on a unit: the tooltip data's own `id`, as
--     TooltipUtil.GetDisplayedSpell reads it; an item or a toy likewise;
--   * a mount: its data carries the mount's ID, not its spell's, so the spell
--     is looked up in the mount journal;
--   * everything else is worked out from what the tooltip was built from (its
--     getter): an action button (a spell, an item, or a macro's spell), a pet
--     bar button, a stance. The first version read `id` for five kinds only,
--     and a pet's abilities, stances and macros on the bars came up with none.
--
-- An ID the client keeps secret is never looked at: no line then.
--
-- The hook goes on at the first PLAYER_ENTERING_WORLD, after the game's other
-- post-calls (the beta Issue Reporter adds its lines at that point too), so the
-- line comes last.
--
-- The line is made small by giving that one line of the tooltip the game's
-- small tooltip font; its old font is put back the moment the tooltip is
-- cleared, so the next tooltip to use that line is its normal size again.

local IDs = {}
DogsForeverUI.Cooldowns.TooltipIDs = IDs

do -- private scope
    local Cooldowns = DogsForeverUI.Cooldowns
    local IsSecret = issecretvalue or function() return false end

    local GREY = { 0.55, 0.55, 0.55 }
    local SPELL, ITEM = "Spell ID", "Item ID"

    -- Per tooltip: the lines this made small and the font each had, and the
    -- line it was given since it was last cleared, so a tooltip processed
    -- twice (the game does, for some) gets one line.
    local restore = setmetatable({}, { __mode = "k" })
    local added = setmetatable({}, { __mode = "k" })
    local hooked = setmetatable({}, { __mode = "k" })

    local function Cleared(tooltip)
        added[tooltip] = nil
        local lines = restore[tooltip]
        if not lines then return end
        restore[tooltip] = nil
        for line, font in pairs(lines) do
            pcall(line.SetFontObject, line, font)
        end
    end

    local function LastLine(tooltip)
        local name = tooltip.GetName and tooltip:GetName()
        local count = tooltip.NumLines and tooltip:NumLines()
        if IsSecret(name) or IsSecret(count) then return nil end
        if type(name) ~= "string" or type(count) ~= "number" or count < 1 then return nil end
        return _G[name .. "TextLeft" .. count]
    end

    -- A plain, positive number, or nothing.
    local function Number(value)
        if IsSecret(value) or type(value) ~= "number" or value <= 0 then return nil end
        return value
    end

    -- Every return of a call, or nothing if it failed or does not exist.
    local function Returns(fn, ...)
        if type(fn) ~= "function" then return end
        local results = { pcall(fn, ...) }
        if not results[1] then return end
        return select(2, unpack(results))
    end

    -- From what the tooltip was built from: C_TooltipInfo's getter and the
    -- arguments it was called with (TooltipDataHandler keeps both).
    local function FromGetter(tooltip)
        if type(tooltip.GetPrimaryTooltipInfo) ~= "function" then return end
        local ok, info = pcall(tooltip.GetPrimaryTooltipInfo, tooltip)
        if not ok or type(info) ~= "table" or type(info.getterArgs) ~= "table" then return end
        local getter, first = info.getterName, info.getterArgs[1]
        if IsSecret(getter) or IsSecret(first) or first == nil then return end

        if getter == "GetAction" then
            local kind, id, subType = Returns(_G.GetActionInfo, first)
            if IsSecret(kind) or IsSecret(subType) then return end
            if kind == "spell" then return SPELL, Number(id) end
            if kind == "item" then return ITEM, Number(id) end
            if kind == "macro" then
                -- A macro showing a spell or an item (#showtooltip, or its
                -- first line) hands that spell's or item's own ID back, with
                -- the subtype saying which - the way the game's action
                -- buttons read it (ActionButton.lua). Otherwise the ID is the
                -- macro's index, and the macro is asked for its spell.
                if subType == "spell" then return SPELL, Number(id) end
                if subType == "item" then return ITEM, Number(id) end
                return SPELL, Number((Returns(_G.GetMacroSpell, id)))
            end
        elseif getter == "GetPetAction" then
            return SPELL, Number((select(7, Returns(_G.GetPetActionInfo, first))))
        elseif getter == "GetShapeshift" then
            return SPELL, Number((select(4, Returns(_G.GetShapeshiftFormInfo, first))))
        end
    end

    -- Answers the line's label and the ID, or nothing.
    function IDs.Resolve(tooltip, data)
        local kinds = type(Enum) == "table" and Enum.TooltipDataType or {}
        local kind = type(data) == "table" and data.type or nil
        local id = type(data) == "table" and Number(data.id) or nil
        if kind ~= nil and not IsSecret(kind) then
            if id and (kind == kinds.Spell or kind == kinds.UnitAura) then return SPELL, id end
            if id and (kind == kinds.Item or kind == kinds.Toy) then return ITEM, id end
            if id and kind == kinds.Mount then
                local journal = _G.C_MountJournal
                local spell = type(journal) == "table"
                    and Number((select(2, Returns(journal.GetMountInfoByID, id))))
                if spell then return SPELL, spell end
            end
        end
        local label, fromGetter = FromGetter(tooltip)
        if label and fromGetter then return label, fromGetter end
    end

    function IDs.Add(tooltip, data)
        if not Cooldowns.db.showTooltipIDs then return end
        if type(tooltip) ~= "table" or type(tooltip.AddLine) ~= "function" then return end
        local label, id = IDs.Resolve(tooltip, data)
        if not id then return end

        local text = label .. " " .. id
        if added[tooltip] == text then return end
        added[tooltip] = text

        if not hooked[tooltip] and type(tooltip.HookScript) == "function" then
            hooked[tooltip] = true
            tooltip:HookScript("OnTooltipCleared", Cleared)
        end

        tooltip:AddLine(text, GREY[1], GREY[2], GREY[3])
        local line = LastLine(tooltip)
        local small = _G.GameTooltipTextSmall
        if line and small and type(line.SetFontObject) == "function" then
            local lines = restore[tooltip] or {}
            restore[tooltip] = lines
            if lines[line] == nil then
                lines[line] = (line.GetFontObject and line:GetFontObject()) or _G.GameTooltipText
            end
            line:SetFontObject(small)
        end
        if type(tooltip.Show) == "function" then tooltip:Show() end
    end

    local function Install()
        local processor = _G.TooltipDataProcessor
        if type(processor) ~= "table" or type(processor.AddTooltipPostCall) ~= "function" then
            return
        end
        processor.AddTooltipPostCall(processor.AllTypes, IDs.Add)
    end

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_ENTERING_WORLD")
    loader:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        Install()
    end)
end
