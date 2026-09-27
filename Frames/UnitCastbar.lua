-- A unit's casting bar: a thin one beside its plate, for the target and the
-- focus - under it, or over it when the game stacks the unit's auras under it.
--
-- It is drawn in the same style as the plate: the flat fill with its sheen, in
-- the castbar colour for each state.
--
-- POLLED, NOT EVENTED
-- The player's own castbar has to be exact to the frame, because it is what the
-- player is watching while they press things; a target's does not. This one is
-- read from UnitCastingInfo on the same timer that repaints the bars, which is
-- twenty times a second and needs no event bookkeeping, no cast IDs and no
-- guarding against a spell queued on top of another. The one thing polling
-- cannot see is *why* a cast ended, so the interrupt is an event.
--
-- WHEN THE CLIENT WILL NOT SAY
-- A unit whose spellcasting is restricted - most other players, on this
-- client - hands back secret values, and a secret may not be tested or worked
-- out with: `if name then` on one is an error, not a nil. The client answers
-- that in advance with a plain boolean (ShouldUnitSpellCastingBeSecret). Such
-- a unit's cast is shown all the same, the way the game shows it: the cast's
-- time comes as a duration object (UnitCastingDuration / UnitChannelDuration)
-- that the bar runs by itself (SetTimerDuration), the spell's name is handed
-- to the label untouched, and whether it can be interrupted picks the grey by
-- SetVertexColorFromBoolean - nothing of it looked at. Before, such a unit
-- simply had no cast bar, which is why other players' casts never showed.

local UnitCastbar = {}
DogsForeverUI.Frames.UnitCastbar = UnitCastbar

do -- private scope

    local NS = DogsForeverUI.Frames
    local Style = DogsForeverUI.Style
    local IsSecret = issecretvalue

    -- Daylight between the plate and the bar, and what it takes to get it: both
    -- draw their border on a frame three pixels outside themselves.
    local BORDER_INSET = Style.BORDER_INSET
    local VISIBLE_GAP = 4
    local PLATE_GAP = VISIBLE_GAP + 2 * BORDER_INSET

    -- How long an interrupted cast is held on screen, in its own colour, so it can
    -- be read at all.
    local INTERRUPT_HOLD = 0.6

    -- The name and the timer are drawn inside the bar, so the bar has to have
    -- room for them. The shared font rule sizes text from the bar's height and
    -- would put 4px letters on a thin one, so there is a floor under the text -
    -- and, because text that overflows its bar reads as a mistake, a floor
    -- under the bar as well. A taller bar is still whatever the setting says.
    local TEXT_MIN = 10
    local HEIGHT_MIN = TEXT_MIN + 2

    -- One colour per state, the same as the player's castbar: Style.CAST_COLOR,
    -- the game's own classic castbar colours.
    -- An interrupted cast wears the failed colour.
    local STATE_COLOR = {
        casting         = Style.CAST_COLOR.casting,
        channel         = Style.CAST_COLOR.channel,
        uninterruptible = Style.CAST_COLOR.uninterruptible,
        interrupted     = Style.CAST_COLOR.failed,
    }

    local function Options()
        return DogsForeverUI.Frames.db
    end

    -- Whether this client will talk about what a unit is casting at all.
    local function CastingIsSecret(unit)
        if type(C_Secrets) == "table"
           and type(C_Secrets.ShouldUnitSpellCastingBeSecret) == "function" then
            local ok, secret = pcall(C_Secrets.ShouldUnitSpellCastingBeSecret, unit)
            if ok then return secret and true or false end
        end
        return false
    end

    -- What the unit is casting right now, asked of the game rather than pieced
    -- together from events: name, start, end, whether it can be interrupted, and
    -- whether it is a channel. Channels report the same values without the cast
    -- ID, so the not-interruptible flag sits one place earlier.
    local function ReadCast(unit)
        local name, _, _, startMS, endMS, _, _, notInterruptible = UnitCastingInfo(unit)
        if name then return name, startMS, endMS, notInterruptible, false end

        local cname, _, _, cstartMS, cendMS, _, cnotInterruptible = UnitChannelInfo(unit)
        if cname then return cname, cstartMS, cendMS, cnotInterruptible, true end
    end

    -- The same for a unit whose casting is secret: the cast's time as a
    -- duration object, the spell's name and whether it can be interrupted as
    -- they come, and whether it is a channel. Nothing is tested but whether
    -- there is a duration at all - a secret one counts as there.
    local function Present(value)
        return IsSecret(value) or value ~= nil
    end

    local function ReadSecretCast(unit)
        if type(UnitCastingDuration) == "function" then
            local duration = UnitCastingDuration(unit)
            if Present(duration) then
                local name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
                return duration, name, notInterruptible, false
            end
        end
        if type(UnitChannelDuration) == "function" then
            local duration = UnitChannelDuration(unit)
            if Present(duration) then
                local name, _, _, _, _, _, notInterruptible = UnitChannelInfo(unit)
                return duration, name, notInterruptible, true
            end
        end
    end

    local function EnumValue(group, key, fallback)
        local enum = type(Enum) == "table" and Enum[group]
        return type(enum) == "table" and enum[key] or fallback
    end
    local IMMEDIATE = EnumValue("StatusBarInterpolation", "Immediate", 0)
    local ELAPSED = EnumValue("StatusBarTimerDirection", "ElapsedTime", 0)
    local REMAINING = EnumValue("StatusBarTimerDirection", "RemainingTime", 1)

    ---------------------------------------------------------------------------

    local methods = {}

    -- plate  the unit plate this bar belongs under
    function UnitCastbar.New(plate)
        local self = { plate = plate, unit = plate.unit, interruptedUntil = 0 }

        -- A child of the plate, so it is hidden with it and inherits its strata.
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

        -- The spark at the end of the fill, as on the player's castbar.
        bar.spark = Style.AddSpark(bar)

        self.bar = bar

        for name, method in pairs(methods) do self[name] = method end
        return self
    end

    -- The cast was interrupted: the one thing polling cannot see, since a cast
    -- that ended and a cast that was stopped both simply stop being reported.
    function methods:Interrupted()
        if not self.bar:IsShown() then return end

        self.interruptedUntil = GetTime() + INTERRUPT_HOLD
        self:Paint("interrupted")
        self.bar:SetMinMaxValues(0, 1)
        self.bar:SetValue(1)
        self.bar.timeText:SetText("")
        -- A full red bar has no moving edge to mark.
        self.bar.spark:SetAlpha(0)
    end

    function methods:Paint(state)
        Style.Paint(self.bar, STATE_COLOR[state] or STATE_COLOR.casting)
    end

    -- Size, position and fonts: everything that follows a setting.
    function methods:Refresh()
        local db = Options()
        local plate = self.plate
        local scale = plate.scale or 1
        local width = math.floor(db.barWidth * scale + 0.5)
        local height = math.max(HEIGHT_MIN,
            math.floor(db.castbarHeight * scale + 0.5))
        local bar = self.bar

        bar:ClearAllPoints()
        bar:SetSize(width, height)

        -- Under the plate, which is where the game puts a target's cast bar -
        -- unless the game's auras are stacked under it (Edit Mode's "Buffs on
        -- top" off; see BlizzardFrames), when it goes over it, so the auras sit
        -- the same distance from the plate either way and never meet the bar.
        -- Above, it clears the plate's name and level row rather than its border.
        if NS.BlizzardFrames.AurasBelow(plate.unit) then
            bar:SetPoint("BOTTOMLEFT", plate, "TOPLEFT", 0,
                NS.UnitPlate.TopRoom() + VISIBLE_GAP + BORDER_INSET)
        else
            bar:SetPoint("TOPLEFT", plate, "BOTTOMLEFT", 0, -PLATE_GAP)
        end

        Style.SetBackground(bar.bg)

        for _, label in ipairs({ bar.spellText, bar.timeText }) do
            label:ClearAllPoints()
            Style.SingleLine(label)
        end

        bar.spellText:SetJustifyH("LEFT")
        bar.spellText:SetPoint("LEFT", bar, "LEFT", 4, 0)
        -- The name gives way to the timer rather than running under it, and this
        -- second point is what gives it a width to be truncated against.
        bar.spellText:SetPoint("RIGHT", bar.timeText, "LEFT", -6, 0)
        bar.timeText:SetJustifyH("RIGHT")
        bar.timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)

        -- The shared text rule, with a floor under it: this bar is thin by
        -- design and the rule alone would size the labels out of existence.
        for _, label in ipairs({ bar.spellText, bar.timeText }) do
            Style.SetFont(bar, label, db.textPadding, TEXT_MIN)
        end

        self:OnUpdate()
    end

    -- A cast the client keeps secret, drawn without being looked at: the bar
    -- runs itself from the duration, forwards for a cast and backwards for a
    -- channel, as the plain one does. Handed over afresh each tick, like
    -- everything here.
    function methods:ShowSecretCast()
        local bar = self.bar
        local ok, duration, name, notInterruptible, channel = pcall(ReadSecretCast, self.unit)
        if not ok or not Present(duration) or type(bar.SetTimerDuration) ~= "function" then
            if GetTime() < self.interruptedUntil then return end
            Style.FadeOut(bar)
            return
        end
        self.interruptedUntil = 0

        local state = channel and "channel" or "casting"
        self:Paint(state)
        local fill = bar:GetStatusBarTexture()
        if IsSecret(notInterruptible) then
            if fill and type(fill.SetVertexColorFromBoolean) == "function" and CreateColor then
                local grey, own = STATE_COLOR.uninterruptible, STATE_COLOR[state]
                fill:SetVertexColorFromBoolean(notInterruptible,
                    CreateColor(grey[1], grey[2], grey[3], 1), CreateColor(own[1], own[2], own[3], 1))
            end
        elseif notInterruptible == true then
            self:Paint("uninterruptible")
        end

        bar:SetTimerDuration(duration, IMMEDIATE, channel and REMAINING or ELAPSED)
        Style.PinSpark(bar.spark, bar)
        -- Where the edge is cannot be judged, so the spark is simply there.
        bar.spark:SetAlpha(1)

        if Present(name) then bar.spellText:SetText(name) else bar.spellText:SetText("") end
        bar.timeText:SetText("")
        local okLeft, left = pcall(function() return duration:GetRemainingDuration() end)
        if okLeft and (IsSecret(left) or type(left) == "number") then
            bar.timeText:SetFormattedText("%.1f", left)
        end
        Style.FadeIn(bar)
    end

    -- Read afresh every tick: what is being cast, how far along it is, and
    -- nothing remembered in between.
    function methods:OnUpdate()
        local db = Options()
        local bar = self.bar

        -- Switched off, being placed, or no unit: gone at once.
        if not db.enabled or not db.showCastbar or db.unlocked
           or not self.plate:ShouldShow() then
            Style.HideNow(bar)
            return
        end

        if CastingIsSecret(self.unit) then
            self:ShowSecretCast()
            return
        end

        local ok, name, startMS, endMS, notInterruptible, channel =
            pcall(ReadCast, self.unit)

        if not ok or not name or IsSecret(startMS) or IsSecret(endMS) then
            -- Nothing being cast. An interrupted one is held for a moment so it
            -- can be read, and then the bar fades away.
            if GetTime() < self.interruptedUntil then return end
            Style.FadeOut(bar)
            return
        end

        self.interruptedUntil = 0

        local startTime, endTime = startMS / 1000, endMS / 1000
        local length = endTime - startTime
        if length <= 0 then
            Style.FadeOut(bar)
            return
        end

        local elapsed = GetTime() - startTime
        if elapsed < 0 then elapsed = 0 end
        if elapsed > length then elapsed = length end

        self:Paint(notInterruptible and "uninterruptible"
            or (channel and "channel" or "casting"))

        local value = channel and (length - elapsed) or elapsed
        bar:SetMinMaxValues(0, length)
        bar:SetValue(value)
        -- Pinned after the paint, which sets the fill it hangs off.
        Style.PinSpark(bar.spark, bar)
        bar.spark:SetAlpha(Style.SparkAlpha(value, length))
        bar.spellText:SetText(name)
        bar.timeText:SetFormattedText("%.1f", length - elapsed)
        -- Everything is set before the bar is seen, and it fades in.
        Style.FadeIn(bar)
    end
end
