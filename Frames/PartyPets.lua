-- The party members' pets (the player, 2026-10-07: "show pets on the left
-- side of owners. same height with the party frames but width very small like
-- 1/5 of party frames and no name/power etc needed only box with a pet icon
-- center of it ... only show heal (vertical grow)", then "the texture should
-- be not flat ... the pet icons can be circle. and our buffs heals can be
-- show inside their frame but tiny"): a narrow box left of each member's
-- party frame, as tall as its bars and WIDTH of its width, in the frames'
-- background, border and shaded fill - its health a fill growing from the
-- bottom, in the frames' health green, the shading turned with it (Style
-- SheenOver), the heals on their way shaded above it (the player, 2026-10-09:
-- "we need to show preheals in party frame pet frames too") and the heal
-- absorbs darkened over it, its shields lit as on the plates (UnitPlate
-- AddShields), and your own buffs on it (your heals over time) as tiny icons
-- from its bottom up (UnitAuras NewMineRow). No portrait and no icon (the
-- player, 2026-10-07: "remove pet portrait"; a pet icon drawn like the role
-- icons was tried, then "maybe no icon at all was better"). Left-click
-- targets the pet, right-click opens its menu, hovering shows its tooltip, as
-- on every frame.
--
-- A child of its owner's frame, hung off its left edge: it goes wherever the
-- column lays that frame out - in combat too. Its fade is its own, though: the
-- pet's range, not its owner's (the player, 2026-10-07: "make the pet boxes
-- fade when out of range too"), read every frame with its health, as the
-- party frames read theirs (UnitPlate.ShowRange). Shown by the game's secure driver while the pet
-- exists (never in a raid); hidden while placing and with Show pets off
-- (partyShowPets). The column's frames keep its room clear of the screen's
-- left edge (their clamp rect, UnitPlate.lua Refresh), so it is never pushed
-- onto its owner.
--
-- Health is secret: handed to the bar, never read (UnitPlate.lua, SECRET
-- VALUES), every frame by Frames.lua's timer, as the plates' are.

local PartyPets = {}
DogsForeverUI.Frames.PartyPets = PartyPets

do -- private scope
    local NS = DogsForeverUI.Frames
    local Style = DogsForeverUI.Style

    PartyPets.WIDTH = 0.2           -- of a party frame's width
    local AURA_MARGIN = 3           -- the buffs to the box's edges
    PartyPets.AURA_SIZE = 8         -- your buffs on it, tiny
    local AURA_COUNT = 4
    local Call = DogsForeverUI.Call
    local CONDITION = "[group:raid] hide; [@%s,exists] show; hide"

    -- The box's width and height: WIDTH of a party frame's, and its bars'.
    function PartyPets.Size(db)
        local width, health, power = NS.UnitPlate.Size(db, { partyIndex = 1 })
        return math.max(8, math.floor(width * PartyPets.WIDTH + 0.5)), health + 1 + power
    end

    -- The gap between the box's border and its owner's.
    local function Gap() return 2 * Style.BORDER_INSET + NS.UnitPlate.PARTY_GAP end

    -- How far left of its owner's frame a box reaches, its border too: the
    -- room the column keeps clear of the screen's edge.
    function PartyPets.Room(db)
        return Gap() + PartyPets.Size(db) + Style.BORDER_INSET
    end

    local methods = {}

    function PartyPets.New(index)
        local unit = "partypet" .. index
        local owner = NS.plates["party" .. index]
        local box = CreateFrame("Frame", "DogsForeverUI.FramesPartyPet" .. index, owner)
        box.unit, box.owner = unit, owner
        -- (Its own fade, not its owner's: see above.)
        box:SetIgnoreParentAlpha(true)

        box.background = box:CreateTexture(nil, "BACKGROUND")
        box.background:SetAllPoints(box)
        Style.SetBackground(box.background)

        box.health = CreateFrame("StatusBar", nil, box)
        box.health:SetAllPoints(box)
        box.health:SetOrientation("VERTICAL")
        Style.Paint(box.health, Style.HEALTH_COLOR)
        box.health:SetMinMaxValues(0, 1)
        box.health:SetValue(0)

        -- The heals on their way, over the missing health above the fill, and
        -- the heal absorbs, over the fill from its top down, as on the plates
        -- (UnitPlate.ShowHeals).
        local fill = box.health:GetStatusBarTexture()
        box.prediction = CreateFrame("StatusBar", nil, box)
        box.prediction:SetOrientation("VERTICAL")
        Style.SetBarFill(box.prediction)
        box.prediction:SetStatusBarColor(unpack(NS.UnitPlate.HEAL_COLOR))
        box.prediction:SetPoint("BOTTOMLEFT", fill, "TOPLEFT")
        box.prediction:SetPoint("TOPRIGHT", box.health, "TOPRIGHT")

        box.healAbsorb = CreateFrame("StatusBar", nil, box)
        box.healAbsorb:SetFrameLevel(box.health:GetFrameLevel() + 1)
        box.healAbsorb:SetOrientation("VERTICAL")
        box.healAbsorb:SetReverseFill(true)
        Style.SetBarFill(box.healAbsorb)
        box.healAbsorb:SetStatusBarColor(unpack(NS.UnitPlate.HEAL_ABSORB_COLOR))
        box.healAbsorb:SetPoint("BOTTOMLEFT", box.health, "BOTTOMLEFT")
        box.healAbsorb:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
        -- And the shields, in both.
        NS.UnitPlate.AddShields(box, true)

        box.border = Style.AddBorder(box)

        -- Your buffs on it, over the fill and the absorbs and under the click.
        box.auras = NS.UnitAuras.NewMineRow(box, unit, PartyPets.AURA_SIZE, AURA_COUNT)
        if box.auras then
            local flow = type(AnchorUtil) == "table" and AnchorUtil.FlowDirection or {}
            Call(box.auras, "SetFrameLevel", box.health:GetFrameLevel() + 3)
            Call(box.auras, "SetFlowLayoutAnchorPoint", "BOTTOMLEFT")
            Call(box.auras, "SetFlowLayoutGrowthDirection", flow.Right, flow.Up)
            Call(box.auras, "SetPoint", "BOTTOMLEFT", box, "BOTTOMLEFT", AURA_MARGIN, AURA_MARGIN)
        end

        -- CLICKING, as on the plates (UnitPlate.lua, CLICKING).
        local click = CreateFrame("Button", "DogsForeverUI.FramesPartyPet" .. index .. "Click",
            box, "SecureUnitButtonTemplate")
        click:SetAllPoints(box)
        click:SetFrameLevel(box:GetFrameLevel() + 5)
        click:RegisterForClicks("AnyUp")
        click:SetAttribute("unit", unit)
        click:SetAttribute("*type1", "target")
        click:SetAttribute("*type2", "togglemenu")
        click:SetScript("OnEnter", function()
            GameTooltip_SetDefaultAnchor(GameTooltip, click)
            GameTooltip:SetUnit(unit)
            GameTooltip:Show()
        end)
        click:SetScript("OnLeave", function() GameTooltip:Hide() end)
        box.click = click

        -- The driver shows it when a pet arrives: painted, and Frames.lua's
        -- timer woken to keep its health drawn.
        box:SetScript("OnShow", function(self)
            self:Update()
            NS:Show()
        end)

        for name, method in pairs(methods) do box[name] = method end
        return box
    end

    -- Size and place: out of combat only (it holds a secure button).
    function methods:Refresh()
        local db = NS.db
        local width, height = PartyPets.Size(db)
        if not InCombatLockdown() then
            self:SetSize(width, height)
            self:ClearAllPoints()
            self:SetPoint("TOPRIGHT", self.owner, "TOPLEFT", -Gap(), 0)
        end
        -- Rows as wide as the box inside its margins.
        if self.auras then Call(self.auras, "SetFlowLayoutMaximumLineSize", width - 2 * AURA_MARGIN) end
        self:Update()
    end

    -- Left to the game's driver, or hidden. Shown: its health.
    function methods:Update()
        local db = NS.db
        local wanted = db.partyShowPets and not db.unlocked and true or false
        if wanted ~= self.driven and not InCombatLockdown() then
            -- (Recorded first: the driver's Show runs OnShow, which comes back here.)
            self.driven = wanted
            if wanted then
                RegisterStateDriver(self, "visibility", CONDITION:format(self.unit))
            else
                UnregisterStateDriver(self, "visibility")
                self:Hide()
            end
        end
        if not self:IsShown() then return end
        -- (A new pet behind the same token: its auras asked for again.)
        if self.auras then Call(self.auras, "UpdateAllAuras") end
        self:OnUpdate()
    end

    function methods:OnUpdate()
        local health, most = UnitHealth(self.unit, true), UnitHealthMax(self.unit)
        self.health:SetMinMaxValues(0, most)
        self.health:SetValue(health)
        NS.UnitPlate.ShowHeals(self, self.unit, health, most)
        NS.UnitPlate.ShowRange(self, self.unit)
    end
end
