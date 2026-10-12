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
-- AN ID THE CLIENT KEEPS SECRET - an aura it restricts (some buffs always,
-- procs like Clearcasting among them; more in combat), whose tooltip data
-- comes back secret - is never looked at, but it is still shown: the line is
-- added with room for a number, then its text set by the line's own
-- SetFormattedText, which the client lets addon code hand a secret to (the
-- unit frames' health text does the same). The kind of tooltip may be secret
-- with it; then the getter it was built from says it was an aura's.
--
-- The hook goes on at the first PLAYER_ENTERING_WORLD, after the game's other
-- post-calls (the beta Issue Reporter adds its lines at that point too), so the
-- line comes last.
--
-- The line is made small by giving that one line of the tooltip a font of the
-- addon's own, the tooltips' face at TEXT_SIZE (not the game's small tooltip
-- font: the tooltips' text is all 12 since 2026-10-03, that one included -
-- ActionBars\GameFrames.lua - and the player asked for the ID smaller); its
-- old font is put back the moment the tooltip is cleared, so the next tooltip
-- to use that line is its normal size again.

local IDs = {}

do -- private scope
    local Cooldowns = DogsForeverUI.Cooldowns
    local IsSecret = issecretvalue

    local GREY = { 0.55, 0.55, 0.55 }
    local SPELL, ITEM = "Spell ID", "Item ID"
    IDs.TEXT_SIZE = 10

    -- The ID line's own font: the tooltips' face (the addon's), smaller.
    local idFont
    local function IDFont()
        if idFont then return idFont end
        local base = _G.GameTooltipTextSmall or _G.GameTooltipText
        if type(base) ~= "table" or type(base.GetFont) ~= "function" then return base end
        idFont = CreateFont("DogsForeverUITooltipIDFont")
        local file, _, flags = base:GetFont()
        if file then idFont:SetFont(file, IDs.TEXT_SIZE, flags or "") end
        return idFont
    end
    -- What a secret ID's line says until its number is put in: as wide as
    -- one, so the tooltip leaves room for it.
    local SECRET_ROOM = "000000"

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

    -- The C_TooltipInfo getters of a unit's aura.
    local AURA_GETTERS = {
        GetUnitAura = true, GetUnitAuraByAuraInstanceID = true,
        GetUnitBuff = true, GetUnitBuffByAuraInstanceID = true,
        GetUnitDebuff = true, GetUnitDebuffByAuraInstanceID = true,
    }

    local function BuiltFromAura(tooltip)
        if type(tooltip.GetPrimaryTooltipInfo) ~= "function" then return false end
        local ok, info = pcall(tooltip.GetPrimaryTooltipInfo, tooltip)
        if not ok or type(info) ~= "table" then return false end
        local getter = info.getterName
        return not IsSecret(getter) and AURA_GETTERS[getter] == true
    end

    -- A field of the tooltip data, which may be a secret table (its fields
    -- can be read, each comes back secret).
    local function Field(data, key)
        local plain = type(data) == "table"
        local secretTable = type(issecrettable) == "function" and issecrettable(data)
        if not (plain or secretTable) then return nil end
        local ok, value = pcall(function() return data[key] end)
        if ok then return value end
    end

    -- A secret ID: the label for it, if what it is can be told.
    local function SecretLabel(tooltip, kind, kinds)
        if kind ~= nil and not IsSecret(kind) then
            if kind == kinds.Spell or kind == kinds.UnitAura then return SPELL end
            if kind == kinds.Item or kind == kinds.Toy then return ITEM end
            return nil
        end
        if BuiltFromAura(tooltip) then return SPELL end
    end

    -- Answers the line's label and the ID, or nothing; a third answer, true,
    -- when the ID is secret (to be handed on, never read).
    function IDs.Resolve(tooltip, data)
        local kinds = type(Enum) == "table" and Enum.TooltipDataType or {}
        local kind = Field(data, "type")
        local raw = Field(data, "id")
        if raw ~= nil and IsSecret(raw) then
            local label = SecretLabel(tooltip, kind, kinds)
            if label then return label, raw, true end
            return
        end
        local id = Number(raw)
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
        local label, id, secret = IDs.Resolve(tooltip, data)
        if id == nil then return end

        -- A secret ID can only be shown through the line itself: without a
        -- line to reach, no line at all rather than one with no number.
        local line
        if secret then
            local name = tooltip.GetName and tooltip:GetName()
            if IsSecret(name) or type(name) ~= "string" then return end
        end
        local text = secret and (label .. " " .. SECRET_ROOM) or (label .. " " .. id)
        if added[tooltip] == text then return end
        added[tooltip] = text

        if not hooked[tooltip] and type(tooltip.HookScript) == "function" then
            hooked[tooltip] = true
            tooltip:HookScript("OnTooltipCleared", Cleared)
        end

        tooltip:AddLine(text, GREY[1], GREY[2], GREY[3])
        line = LastLine(tooltip)
        if secret and line and type(line.SetFormattedText) == "function" then
            line:SetFormattedText(label .. " %d", id)
        end
        local small = IDFont()
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

-------------------------------------------------------------------------------
-- TALENT RANKS: "1/5" on a talent button rather than the game's bare "1"
-- (the player asked, 2026-10-02). The game writes a button's rank with TalentButtonUtil.SetSpendText
-- - the current rank only (TalentButtonBaseMixin:GetSpendText), and nothing
-- else ever writes that label; a post-hook (hooksecurefunc - the game's own
-- code runs untouched first) writes the same rank with the most there is
-- beside it, on the class talents only and only where the game shows a number
-- at all. A talent with one rank keeps the game's text.
-------------------------------------------------------------------------------

do -- private scope
    -- Whether `button` is one of the class talents' (PlayerSpellsFrame's).
    local function ClassTalent(button)
        local spells = _G.PlayerSpellsFrame
        local talents = type(spells) == "table" and spells.TalentsFrame
        if not talents or type(button.GetTalentFrame) ~= "function" then return false end
        local ok, frame = pcall(button.GetTalentFrame, button)
        return ok and frame == talents
    end

    -- The text the button should show instead of `text`, or nil to keep it.
    local function RankText(button, text)
        if type(button) ~= "table" or type(text) ~= "string" or text == "" then return end
        local info = button.nodeInfo
        if type(info) ~= "table" then return end
        local current, max = info.currentRank, info.maxRanks
        if type(current) ~= "number" or type(max) ~= "number" or max <= 1 then return end
        return current .. "/" .. max
    end

    local function AfterSpendText(button, text)
        if type(button) ~= "table" or not ClassTalent(button) then return end
        local shown = RankText(button, text ~= nil and tostring(text) or nil)
        if not shown then return end
        local label = button.SpendText
        if type(label) == "table" and type(label.SetText) == "function" then label:SetText(shown) end
        if type(button.spendTextShadows) == "table" then
            for _, shadow in ipairs(button.spendTextShadows) do
                if type(shadow.SetText) == "function" then shadow:SetText(shown) end
            end
        end
    end

    local hooked = false
    local function Hook()
        local util = _G.TalentButtonUtil
        if hooked or type(util) ~= "table" or type(util.SetSpendText) ~= "function" then return end
        hooked = true
        hooksecurefunc(util, "SetSpendText", AfterSpendText)
    end

    -- The talent window loads when it is first opened.
    local talentLoader = CreateFrame("Frame")
    talentLoader:RegisterEvent("ADDON_LOADED")
    talentLoader:RegisterEvent("PLAYER_LOGIN")
    talentLoader:SetScript("OnEvent", function(self)
        Hook()
        if hooked then self:UnregisterAllEvents() end
    end)
    Hook()
end
