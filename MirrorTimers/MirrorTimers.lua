-- MODULE: Mirror timers  (DogsForeverUI.MirrorTimers)
--
-- The breath bar in the addon's one look - and the game's other timer bars,
-- fatigue and feign death, which are the same bars. No setting and no command.
--
-- WHERE. The game's timer bars live in MirrorTimerContainer, an Edit Mode
-- system ("Timer Bars") that lays out one bar per running timer
-- (Blizzard_MirrorTimer). Each of the addon's bars is a child of one of the
-- game's, centred on it: so it sits wherever the game puts that bar - its
-- default place, or wherever Edit Mode moved it - is scaled with it, and is
-- shown exactly while the game shows it (a timer running, or Edit Mode showing
-- where the bars sit). Nothing about the place is worked out here.
--
-- THE GAME'S BARS are faded, not hidden: every part of each - its bar, the box
-- its label sits in, the label, the frame art - at no opacity. Nothing of the
-- game's is shown, hidden, moved or given a field, and it goes on running its
-- timers exactly as before; nothing of the game's writes those parts' alpha
-- (checked across Blizzard_MirrorTimer and Edit Mode).
--
-- WHAT IT SHOWS is the game's own bar, read off it every frame and handed on
-- untouched: its range and value, and its label (Breath, Fatigue...). The
-- value is only looked at for the time left and the spark, and not at all
-- when it is a secret.

local MirrorTimers = {}
DogsForeverUI.MirrorTimers = MirrorTimers

do -- private scope

    local Style = DogsForeverUI.Style
    local IsSecret = issecretvalue or function() return false end

    -- The game's bar's width (MirrorTimer.xml), and the castbar's height, so
    -- the label fits inside the bar rather than in a box under it.
    local WIDTH, HEIGHT = 195, 20
    local TEXT_PADDING = 0.15

    -- Edit Mode shows the bars with no timer running, to say where they sit.
    local IDLE_NAME = "Timer bar"

    -- The classic timer bars' own colours (MirrorTimerColors).
    local COLOURS = {
        BREATH     = { 0.0, 0.5, 1.0 },
        EXHAUSTION = { 1.0, 0.9, 0.0 },
        DEATH      = { 1.0, 0.7, 0.0 },
        FEIGNDEATH = { 1.0, 0.7, 0.0 },
    }
    local OTHER_COLOUR = COLOURS.EXHAUSTION

    local ours = {}   -- the game's timer frame -> the addon's bar on it
    MirrorTimers.bars = ours

    local function FadeGame(timer)
        if timer.StatusBar then timer.StatusBar:SetAlpha(0) end
        if type(timer.GetRegions) == "function" then
            for _, region in ipairs({ timer:GetRegions() }) do region:SetAlpha(0) end
        end
    end

    local function Update(bar)
        local timer = bar.timer
        local kind = timer.timer

        if bar.kind ~= kind then
            bar.kind = kind
            local c = COLOURS[kind] or OTHER_COLOUR
            bar:SetStatusBarColor(c[1], c[2], c[3], 1)
        end

        if not kind then
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            bar.nameText:SetText(IDLE_NAME)
            bar.timeText:SetText("")
            bar.spark:SetAlpha(0)
            return
        end

        local game = timer.StatusBar
        local low, high = game:GetMinMaxValues()
        local value = game:GetValue()
        bar:SetMinMaxValues(low, high)
        bar:SetValue(value)
        bar.nameText:SetText(timer.Text and timer.Text:GetText() or "")

        if IsSecret(value) or IsSecret(low) or IsSecret(high) then
            bar.timeText:SetFormattedText("%.1f", value)
            bar.spark:SetAlpha(0)
        else
            bar.timeText:SetFormattedText("%.1f", math.max(0, value))
            bar.spark:SetAlpha(Style.SparkAlpha(value - low, high - low))
        end
    end

    local function Make(timer)
        local bar = CreateFrame("StatusBar", nil, timer)
        bar:SetSize(WIDTH, HEIGHT)
        bar:SetPoint("CENTER", timer, "CENTER", 0, 0)
        bar:SetFrameLevel(timer:GetFrameLevel() + 2)
        bar.timer = timer

        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints(bar)
        Style.SetBackground(bar.bg)
        Style.Paint(bar, OTHER_COLOUR)
        bar.border = Style.AddBorder(bar)
        bar.spark = Style.AddSpark(bar)
        Style.PinSpark(bar.spark, bar)

        -- The castbar's two labels: the timer's name on the left, the time
        -- left on the right.
        bar.nameText = bar:CreateFontString(nil, "OVERLAY")
        bar.timeText = bar:CreateFontString(nil, "OVERLAY")
        Style.SingleLine(bar.nameText)
        Style.SingleLine(bar.timeText)
        bar.timeText:SetJustifyH("RIGHT")
        bar.timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        bar.nameText:SetJustifyH("LEFT")
        bar.nameText:SetPoint("LEFT", bar, "LEFT", 4, 0)
        bar.nameText:SetPoint("RIGHT", bar.timeText, "LEFT", -6, 0)
        Style.SetFont(bar, bar.nameText, TEXT_PADDING)
        Style.SetFont(bar, bar.timeText, TEXT_PADDING)

        -- Runs only while the game's bar is shown: it is the parent.
        bar:SetScript("OnUpdate", Update)

        ours[timer] = bar
        FadeGame(timer)
        Update(bar)
    end

    -- The game's three timer bars, once each. Blizzard_MirrorTimer loads with
    -- the game's own UI, before this addon on every client seen; the events
    -- are there in case one loads it later.
    local function Take()
        local container = _G.MirrorTimerContainer
        if type(container) ~= "table" or type(container.mirrorTimers) ~= "table" then return end
        for _, timer in ipairs(container.mirrorTimers) do
            if type(timer) == "table" and timer.StatusBar and not ours[timer] then Make(timer) end
        end
    end

    Take()
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:SetScript("OnEvent", Take)
end
