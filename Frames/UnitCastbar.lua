-- A thin casting bar for the target's and focus's plates: under the plate, or
-- over it when the unit's auras are below. Polled every frame while shown
-- (Frames.lua); only the interrupt comes as an event. A unit whose casting is
-- secret is drawn without being read: SetTimerDuration runs the bar, the name
-- goes to the label untouched, SetVertexColorFromBoolean picks the grey.

local UnitCastbar = {}
DogsForeverUI.Frames.UnitCastbar = UnitCastbar

do -- private scope
    local NS = DogsForeverUI.Frames
    local Style = DogsForeverUI.Style
    local IsSecret = issecretvalue

    local BORDER_INSET = Style.BORDER_INSET
    local VISIBLE_GAP = 4
    local PLATE_GAP = VISIBLE_GAP + 2 * BORDER_INSET
    local INTERRUPT_HOLD = 0.6        -- an interrupted cast stays this long, in red
    -- Floors under the text and the bar: the shared rule would size a thin
    -- bar's labels away.
    local TEXT_MIN = 10
    local HEIGHT_MIN = TEXT_MIN + 2

    local STATE_COLOR = {
        casting         = Style.CAST_COLOR.casting,
        channel         = Style.CAST_COLOR.channel,
        uninterruptible = Style.CAST_COLOR.uninterruptible,
        interrupted     = Style.CAST_COLOR.failed,
    }

    local IMMEDIATE = Enum.StatusBarInterpolation.Immediate
    local ELAPSED = Enum.StatusBarTimerDirection.ElapsedTime
    local REMAINING = Enum.StatusBarTimerDirection.RemainingTime

    local function Present(value)
        return IsSecret(value) or value ~= nil
    end

    -- (Never `text or ""`: a secret may not be tested.)
    local function SetLabel(label, text)
        if Present(text) then label:SetText(text) else label:SetText("") end
    end

    -- name, start, end, not interruptible, channel, display text. The text is
    -- what the game's castbar shows: some spells' names are "No Text".
    local function ReadCast(unit)
        local name, text, _, startMS, endMS, _, _, notInterruptible = UnitCastingInfo(unit)
        if name then return name, startMS, endMS, notInterruptible, false, text end
        local cname, ctext, _, cstartMS, cendMS, _, cnotInterruptible = UnitChannelInfo(unit)
        if cname then return cname, cstartMS, cendMS, cnotInterruptible, true, ctext end
    end

    -- duration object, text, not interruptible, channel - none of it read.
    local function ReadSecretCast(unit)
        local duration = UnitCastingDuration(unit)
        if Present(duration) then
            local _, text, _, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
            return duration, text, notInterruptible, false
        end
        duration = UnitChannelDuration(unit)
        if Present(duration) then
            local _, text, _, _, _, _, notInterruptible = UnitChannelInfo(unit)
            return duration, text, notInterruptible, true
        end
    end

    local function Remaining(duration) return duration:GetRemainingDuration() end

    local methods = {}
    methods.__index = methods

    function UnitCastbar.New(plate)
        local self = setmetatable({ plate = plate, unit = plate.unit, interruptedUntil = 0 }, methods)

        -- A child of the plate: hidden with it, in its strata.
        local bar = CreateFrame("StatusBar", nil, plate)
        bar:SetFrameLevel(plate:GetFrameLevel() + 4)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        bar:Hide()
        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints(true)
        bar.border = Style.AddBorder(bar)
        bar.spellText = bar:CreateFontString(nil, "OVERLAY")
        bar.timeText = bar:CreateFontString(nil, "OVERLAY")
        bar.spark = Style.AddSpark(bar)
        self.bar = bar
        return self
    end

    function methods:Interrupted()
        if not self.bar:IsShown() then return end
        self.interruptedUntil = GetTime() + INTERRUPT_HOLD
        self:Paint("interrupted")
        self.bar:SetMinMaxValues(0, 1)
        self.bar:SetValue(1)
        self.bar.timeText:SetText("")
        self.bar.spark:SetAlpha(0)
    end

    -- Painted only when the state changes; the spark pinned to the new fill.
    function methods:Paint(state)
        if self.painted == state then return end
        self.painted = state
        Style.Paint(self.bar, STATE_COLOR[state] or STATE_COLOR.casting)
        Style.PinSpark(self.bar.spark, self.bar)
    end

    function methods:Refresh()
        local db = NS.db
        local plate, bar = self.plate, self.bar
        local scale = plate.scale

        bar:ClearAllPoints()
        bar:SetSize(math.floor(db.barWidth * scale + 0.5),
            math.max(HEIGHT_MIN, math.floor(db.castbarHeight * scale + 0.5)))
        self.painted = nil          -- the spark's height follows the bar's

        if NS.UnitAuras.Side(plate.unit) == "below" then
            bar:SetPoint("BOTTOMLEFT", plate, "TOPLEFT", 0, NS.UnitPlate.TopRoom() + VISIBLE_GAP + BORDER_INSET)
        else
            bar:SetPoint("TOPLEFT", plate, "BOTTOMLEFT", 0, -PLATE_GAP)
        end

        Style.SetBackground(bar.bg)
        Style.BarLabels(bar, bar.spellText, bar.timeText, db.textPadding, TEXT_MIN)

        self:OnUpdate()
    end

    -- Nothing cast: an interrupted one is held a moment, then the bar fades.
    function methods:Stop()
        if GetTime() < self.interruptedUntil then return end
        Style.FadeOut(self.bar)
    end

    -- Forwards for a cast, backwards for a channel, as the plain one.
    function methods:ShowSecretCast()
        local bar = self.bar
        local ok, duration, name, notInterruptible, channel = pcall(ReadSecretCast, self.unit)
        if not ok or not Present(duration) then return self:Stop() end
        self.interruptedUntil = 0

        local state = channel and "channel" or "casting"
        if IsSecret(notInterruptible) then
            self:Paint(state)
            local grey, own = STATE_COLOR.uninterruptible, STATE_COLOR[state]
            bar:GetStatusBarTexture():SetVertexColorFromBoolean(notInterruptible,
                CreateColor(grey[1], grey[2], grey[3], 1), CreateColor(own[1], own[2], own[3], 1))
            self.painted = nil
        else
            self:Paint(notInterruptible == true and "uninterruptible" or state)
        end

        bar:SetTimerDuration(duration, IMMEDIATE, channel and REMAINING or ELAPSED)
        bar.spark:SetAlpha(1)       -- where the edge is cannot be judged
        SetLabel(bar.spellText, name)
        bar.timeText:SetText("")
        local okLeft, left = pcall(Remaining, duration)
        if okLeft and (IsSecret(left) or type(left) == "number") then
            bar.timeText:SetFormattedText("%.1f", left)
        end
        Style.FadeIn(bar)
    end

    -- Read afresh every tick; nothing remembered in between.
    function methods:OnUpdate()
        local db, bar = NS.db, self.bar
        if not db.showCastbar or db.unlocked or not self.plate:ShouldShow() then
            Style.HideNow(bar)
            return
        end
        if C_Secrets.ShouldUnitSpellCastingBeSecret(self.unit) then return self:ShowSecretCast() end

        local ok, name, startMS, endMS, notInterruptible, channel, text = pcall(ReadCast, self.unit)
        if not ok or not name or IsSecret(startMS) or IsSecret(endMS) then return self:Stop() end
        self.interruptedUntil = 0

        local startTime = startMS / 1000
        local length = endMS / 1000 - startTime
        if length <= 0 then
            Style.FadeOut(bar)
            return
        end
        local elapsed = math.min(math.max(GetTime() - startTime, 0), length)

        self:Paint(notInterruptible and "uninterruptible" or (channel and "channel" or "casting"))
        local value = channel and (length - elapsed) or elapsed
        bar:SetMinMaxValues(0, length)
        bar:SetValue(value)
        bar.spark:SetAlpha(Style.SparkAlpha(value, length))
        SetLabel(bar.spellText, text)
        bar.timeText:SetFormattedText("%.1f", length - elapsed)
        Style.FadeIn(bar)
    end
end
