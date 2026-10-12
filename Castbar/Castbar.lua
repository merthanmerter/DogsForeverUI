-- MODULE: Castbar  (DogsForeverUI.Castbar, settings section "castbar")
-- The player's casting bar, in place of the game's (hidden, never edited).
-- Casts and channels only: a GCD bar would have to branch on a secret boolean.
-- Leads the castbar group: the row (Rows.lua) and the swing bars sit above it.

DogsForeverUI.Castbar = CreateFrame("Frame")

do -- private scope
    local NS = DogsForeverUI.Castbar
    local Style = DogsForeverUI.Style
    local Core = DogsForeverUI
    local Snap = Core.Snap
    local IsSecret = issecretvalue

    local Refresh, Redraw, Draw, EndCast

    NS.key = "castbar"
    NS.title = "Castbars"

    NS.defaults = {
        unlocked = false,
        barWidth = 130,
        barHeight = 20,
        textPadding = 0.15,       -- the whole group's
        frameStrata = "MEDIUM",
        -- The swing bars' own; `swingSized`: the castbar's copied over once.
        swingWidth = 130,
        swingHeight = 20,
        swingStrata = "MEDIUM",
        swingSized = false,
    }
    NS.placement = {
        barLeft = true, barTop = true, autoPlaced = true,
        swingLeft = true, swingBottom = true, swingPlaced = true,
    }

    NS.FAILED_HOLD = 0.6                     -- seconds a failed cast stays up
    NS.TOP_SHARE = 830 / 1200                -- the default top, as a share of the screen
    -- Borders sit 3px outside each bar: 6px of daylight between two of the group.
    NS.STACK_GAP = 6 + 2 * Style.BORDER_INSET

    -- Times kept as they arrived: seconds when plain, raw ms when secret.
    local cast = { active = false, channel = false, plain = false, startTime = 0, endTime = 0 }
    local holdUntil, holdFailed = 0, false
    local settled = false                    -- the castbar has its final place this session
    local rows = {}                          -- the row's modules (JoinRow)

    local castbar = CreateFrame("StatusBar", "DogsForeverUICastBar", UIParent)
    castbar:Hide()
    castbar.bg = castbar:CreateTexture(nil, "BACKGROUND")
    castbar.bg:SetAllPoints(castbar)
    castbar.border = Style.AddBorder(castbar)
    castbar.spark = Style.AddSpark(castbar)
    castbar.spellText = castbar:CreateFontString(nil, "OVERLAY")
    castbar.timeText = castbar:CreateFontString(nil, "OVERLAY")
    NS.CastBar = { castbar = castbar }

    -- A width box's onChange that keeps a bar centred: its left moves by half
    -- the change. With `placedKey`, only while that says it is placed on its own.
    function NS.KeepCentred(db, placedKey, leftKey)
        return function(old, new)
            local t = db()
            if type(old) == "number" and type(new) == "number"
               and (placedKey == nil or t[placedKey]) and t[leftKey] then
                t[leftKey] = t[leftKey] + (old - new) / 2
            end
        end
    end
    NS.WidthChanged = NS.KeepCentred(function() return NS.db end, nil, "barLeft")

    function NS.DefaultTop()
        local height = GetScreenHeight()
        if height > 0 then return -height * NS.TOP_SHARE end
    end

    -- Where a bar of the group goes by default: centred over the castbar,
    -- `above` its top. Taken once; nothing moves with the castbar after.
    function NS.OverCastbar(width, height, above)
        local db = NS.db
        return db.barLeft + (db.barWidth - width) / 2, db.barTop + above + height
    end

    function NS.GroupSettled() return settled end

    local function CenterBar()
        local db, width, top = NS.db, GetScreenWidth(), NS.DefaultTop()
        if not top or width <= 0 then
            db.barLeft, db.barTop = 90, -68      -- screen not known yet: any place beats none
            return
        end
        db.barLeft, db.barTop = (width - db.barWidth) / 2, top
        db.autoPlaced = true                     -- worked out again until dragged
    end

    function NS.Normalise(db)
        if db.barLeft == nil or db.barTop == nil then CenterBar() end
        if not db.swingSized then
            db.swingWidth, db.swingHeight, db.swingStrata = db.barWidth, db.barHeight, db.frameStrata
            db.swingSized = true
        end
    end

    -- THE ROW over the castbar, shared by the 5SR and combo bars (a rogue has
    -- no mana). Each has its own size - the castbar's, copied once (`sized`) -
    -- and its place there worked out once (`placed`); dragged, its own. Placed
    -- and locked with the castbar. Answers the bar's Place().
    function NS.JoinRow(module, frame, name)
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        rows[#rows + 1] = module

        module.defaults = { barWidth = 130, barHeight = 20, frameStrata = "MEDIUM", sized = false }
        module.placement = { barLeft = true, barTop = true, placed = true }
        -- A change can give the row to, or take it from, the swing bars above.
        module.Refresh = Refresh

        function module.Normalise(db)
            if db.sized then return end
            local group = NS.db
            db.barWidth, db.barHeight, db.frameStrata = group.barWidth, group.barHeight, group.frameStrata
            db.sized = true
        end

        local function Place()
            local db = module.db
            frame:SetSize(db.barWidth, db.barHeight)
            frame:SetFrameStrata(db.frameStrata)
            if not db.placed and settled then
                db.barLeft, db.barTop = NS.OverCastbar(db.barWidth, db.barHeight, NS.STACK_GAP)
                db.placed = true
            end
            if db.placed then
                Snap.Put(frame, db)
            else
                frame:ClearAllPoints()
                frame:SetPoint("BOTTOM", castbar, "TOP", 0, NS.STACK_GAP)
                frame:SetUserPlaced(false)
            end
            frame:EnableMouse(NS.db.unlocked)
        end

        -- A drag's end, a nudge, or following its anchor (Core\Snap.lua).
        local function SavePlace()
            local db = module.db
            db.placed = true
            db.barLeft, db.barTop = frame:GetLeft(), frame:GetTop() - GetScreenHeight()
            module.Redraw()
            Core.RefreshOptions()
        end
        Snap.Draggable(frame, NS, SavePlace)
        Snap.Register(frame, { save = SavePlace, name = name, id = module.key })
        return Place
    end

    local function Paint()
        local state = holdFailed and "failed" or cast.notInterruptible and "uninterruptible"
            or cast.channel and "channel" or "casting"
        Style.Paint(castbar, Style.CAST_COLOR[state])
    end

    -- Full, with no time or spark: the preview and a failed cast.
    local function ShowFull()
        Paint()
        castbar:SetMinMaxValues(0, 1)
        castbar:SetValue(1)
        castbar.timeText:SetText("")
        castbar.spark:Hide()
    end

    function Draw()
        if NS.db.unlocked then
            -- As it really looks, named where the spell goes.
            Style.ShowNow(castbar)
            ShowFull()
            castbar.spellText:SetText("Castbar")
            return
        end
        if not cast.active then
            -- A failed cast is held for a moment; anything else fades out.
            if GetTime() >= holdUntil then Style.FadeOut(castbar) end
            return
        end
        if not cast.plain then
            -- Secret times go straight to the bar: no time, spark or drain.
            castbar:SetMinMaxValues(cast.startTime, cast.endTime)
            castbar:SetValue(GetTime() * 1000)
            castbar.timeText:SetText("")
            return
        end
        local length = cast.endTime - cast.startTime
        local elapsed = GetTime() - cast.startTime
        -- Done: gone at once, not stuck at 0.0 waiting for the stop event.
        if length <= 0 or elapsed >= length then
            EndCast(false)
            return
        end
        local value = cast.channel and length - elapsed or elapsed   -- a channel drains
        castbar:SetMinMaxValues(0, length)
        castbar:SetValue(value)
        castbar.timeText:SetFormattedText("%.1f", length - elapsed)
        castbar.spark:SetPoint("CENTER", castbar, "LEFT", NS.db.barWidth * value / length, 0)
    end

    -- The cast now, asked of the game (the event only says that it changed),
    -- with its display text, as the game's bar shows: "No Text" is a name.
    local function ReadCast()
        local name, text, _, startMS, endMS, _, castID, notInterruptible = UnitCastingInfo("player")
        if name then return name, startMS, endMS, notInterruptible, false, castID, text end
        -- A channel has no cast ID: its flag sits one place earlier.
        name, text, _, startMS, endMS, _, notInterruptible = UnitChannelInfo("player")
        if name then return name, startMS, endMS, notInterruptible, true, nil, text end
    end

    -- Whether a stop or failure is about the cast on the bar: a refused second
    -- spell sends the same FAILED. By cast ID when both can be read; else the
    -- game clears a cast before its end event, so one still running is not it.
    local function EventIsOurs(eventCastID)
        local mine = cast.castID
        if not (IsSecret(mine) or IsSecret(eventCastID)) and mine ~= nil and eventCastID ~= nil then
            return mine == eventCastID
        end
        return ReadCast() == nil
    end

    local function BeginCast()
        local name, startMS, endMS, notInterruptible, channel, castID, text = ReadCast()
        if not name then
            EndCast(false)
            return
        end
        cast.active, cast.channel, cast.castID = true, channel, castID
        cast.notInterruptible = notInterruptible and true or false
        cast.plain = not (IsSecret(startMS) or IsSecret(endMS))
        if cast.plain then startMS, endMS = startMS / 1000, endMS / 1000 end
        cast.startTime, cast.endTime = startMS, endMS
        holdUntil, holdFailed = 0, false
        if NS.db.unlocked then return end

        Paint()
        -- A secret text is passed on as it is; a missing one leaves no name.
        if not IsSecret(text) and type(text) ~= "string" then text = "" end
        castbar.spellText:SetText(text)
        castbar.spark:SetShown(cast.plain)
        -- Drawn before it is seen: no frame of the last cast's end.
        Draw()
        if cast.active then Style.FadeIn(castbar) end
    end

    -- A finished cast is gone at once; a failed one is held, full, in its colour.
    function EndCast(failed)
        if not cast.active then return end
        cast.active, cast.castID = false, nil
        holdFailed = failed
        holdUntil = failed and GetTime() + NS.FAILED_HOLD or 0
        if NS.db.unlocked then return end
        if not failed then
            Style.FadeOut(castbar)
            return
        end
        ShowFull()
        Style.FadeIn(castbar)
    end

    local function OnCastEvent(event, ...)
        local _, castID, _, interruptedBy = ...
        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
           or event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
            BeginCast()   -- a pushback or tick is re-read too
        elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET"
               or event == "UNIT_SPELLCAST_INTERRUPTED" then
            -- A channel's interruption comes as CHANNEL_STOP.
            if not cast.channel and EventIsOurs(castID) then EndCast(true) end
        elseif event == "UNIT_SPELLCAST_STOP" then
            if EventIsOurs(castID) then EndCast(false) end
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            -- Nil when it ran its course; a secret interrupter is still one.
            EndCast(IsSecret(interruptedBy) or interruptedBy ~= nil)
        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            cast.notInterruptible = event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE"
            Paint()
        end
    end

    -- The bar alone, from the settings.
    function Redraw()
        local db = NS.db
        Snap.Put(castbar, db)
        castbar:SetSize(db.barWidth, db.barHeight)
        castbar:SetFrameStrata(db.frameStrata)
        castbar:EnableMouse(db.unlocked)
        Paint()
        Style.SetBackground(castbar.bg)
        Style.BarLabels(castbar, castbar.spellText, castbar.timeText, db.textPadding)
        castbar.spark:SetHeight(db.barHeight * Style.SPARK_HEIGHT)
        Draw()
    end

    -- The game's casting bar shows itself at every cast: held down from its
    -- OnShow too. Not a protected frame, so safe in combat.
    PlayerCastingBarFrame:HookScript("OnShow", function(self) self:Hide() end)

    function Refresh()
        Redraw()
        PlayerCastingBarFrame:Hide()
        Core.HoldEditMode(PlayerCastingBarFrame, true)
        NS.SwingBars.Refresh()
        for _, row in ipairs(rows) do row.Redraw() end
        NS:Show()
    end

    -- Only the position is saved: reading the size back rounded it a little on every drag.
    Snap.Piece(castbar, NS, { name = "Castbar", id = "castbar" }, Redraw)

    function NS.Unlock()
        NS.db.unlocked = true
        Refresh()
    end

    function NS.Lock()
        NS.db.unlocked = false
        -- The preview goes at once, not faded like a finished cast.
        if not cast.active then Style.HideNow(castbar) end
        Refresh()
    end

    for _, event in ipairs({
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
        "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
        "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    }) do
        NS:RegisterUnitEvent(event, "player")
    end
    NS:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- Every event shows the frame: its OnUpdate runs only while there is
    -- something to draw (a cast, a hold, a swing bar busy, the group placed).
    NS:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            -- UIParent is unscaled at ADDON_LOADED: only the addon's own place is worked out again.
            if NS.db.autoPlaced then CenterBar() end
            settled = true
            Refresh()
        elseif not NS.SwingBars.OnEvent(event, ...) then
            OnCastEvent(event, ...)
        end
        NS:Show()
    end)
    NS:SetScript("OnUpdate", function()
        Draw()
        NS.SwingBars.OnUpdate()
        if not (NS.db.unlocked or cast.active or GetTime() < holdUntil or NS.SwingBars.Busy()) then
            NS:Hide()
        end
    end)

    NS.Init = Refresh
    NS.Refresh = Refresh

    DogsForeverUI:RegisterModule(NS)
end
