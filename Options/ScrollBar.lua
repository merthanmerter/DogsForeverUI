-- Scrolling for the options window's page, built by hand rather than taken
-- from a scroll template (which templates a client ships varies, and a
-- missing one would take the whole window down with it).
--
-- Smooth: the wheel and ScrollTo set where the page is heading, and it eases
-- there over a few frames rather than jumping. A slim thumb in the border's
-- gold shows where you are and can be dragged; there is no track to speak of,
-- and nothing at all when the page fits.

local ScrollBar = {}
DogsForeverUI.ScrollBar = ScrollBar

do -- private scope
    local Style = DogsForeverUI.Style

    local WIDTH = 4
    local MIN_THUMB = 28
    local WHEEL_STEP = 70
    local EASE = 14        -- per second: how quickly the page catches up
    local THUMB = { Style.BORDER_COLOR[1], Style.BORDER_COLOR[2], Style.BORDER_COLOR[3] }

    -- Cursor coordinates come back in screen units.
    local function CursorY(frame)
        local _, y = GetCursorPosition()
        return y / frame:GetEffectiveScale()
    end

    -- scrollFrame: a ScrollFrame with its scroll child set. `onScroll(y)` is
    -- told every time the page moves. Answers the scroller:
    --   Update()            fit the thumb to the content (after it changed)
    --   ScrollTo(y, now)    head for `y` (clamped); `now` jumps there
    --   Limit()             how far the page can scroll
    function ScrollBar.Attach(scrollFrame, onScroll)
        local scroller = {}
        local target = 0

        local track = CreateFrame("Frame", nil, scrollFrame:GetParent())
        track:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 6, -4)
        track:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 6, 4)
        track:SetWidth(WIDTH)
        -- What runs the easing: always shown, unlike the track.
        local driver = CreateFrame("Frame", nil, scrollFrame:GetParent())
        local groove = track:CreateTexture(nil, "BACKGROUND")
        groove:SetAllPoints(track)
        groove:SetColorTexture(1, 1, 1, 0.04)

        local thumb = CreateFrame("Frame", nil, track)
        thumb:SetWidth(WIDTH)
        thumb:SetHeight(MIN_THUMB)
        thumb:EnableMouse(true)
        thumb:RegisterForDrag("LeftButton")
        local thumbTexture = thumb:CreateTexture(nil, "ARTWORK")
        thumbTexture:SetAllPoints(thumb)
        thumbTexture:SetColorTexture(THUMB[1], THUMB[2], THUMB[3], 0.7)
        thumb:SetScript("OnEnter", function() thumbTexture:SetColorTexture(THUMB[1], THUMB[2], THUMB[3], 1) end)
        thumb:SetScript("OnLeave", function() thumbTexture:SetColorTexture(THUMB[1], THUMB[2], THUMB[3], 0.7) end)

        local function ContentHeight()
            local child = scrollFrame:GetScrollChild()
            return child and child:GetHeight() or 0
        end

        function scroller.Limit()
            return math.max(0, ContentHeight() - scrollFrame:GetHeight())
        end

        local function Clamp(y)
            return math.max(0, math.min(y, scroller.Limit()))
        end

        function scroller.Update()
            local limit = scroller.Limit()
            local trackHeight = track:GetHeight()
            if limit <= 0 or trackHeight <= 0 then
                track:Hide()
                return
            end
            track:Show()
            local height = trackHeight * (scrollFrame:GetHeight() / ContentHeight())
            height = math.min(trackHeight, math.max(MIN_THUMB, height))
            thumb:SetHeight(height)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", track, "TOP", 0,
                -(trackHeight - height) * (scrollFrame:GetVerticalScroll() / limit))
        end

        local function Set(y)
            scrollFrame:SetVerticalScroll(y)
            scroller.Update()
            if onScroll then onScroll(y) end
        end

        local function Ease(self, elapsed)
            local y = scrollFrame:GetVerticalScroll()
            local gap = target - y
            if math.abs(gap) < 0.5 then
                self:SetScript("OnUpdate", nil)
                Set(target)
            else
                Set(y + gap * (1 - math.exp(-EASE * elapsed)))
            end
        end

        function scroller.ScrollTo(y, now)
            target = Clamp(y)
            if now then
                driver:SetScript("OnUpdate", nil)
                Set(target)
            else
                driver:SetScript("OnUpdate", Ease)
            end
        end

        function scroller.Target() return target end

        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(_, delta)
            scroller.ScrollTo(target - delta * WHEEL_STEP)
        end)
        scrollFrame:HookScript("OnSizeChanged", function()
            target = Clamp(target)
            scroller.Update()
        end)

        thumb:SetScript("OnDragStart", function(self)
            local startCursor, startScroll = CursorY(self), scrollFrame:GetVerticalScroll()
            self:SetScript("OnUpdate", function(me)
                local travel = track:GetHeight() - me:GetHeight()
                local limit = scroller.Limit()
                if travel <= 0 or limit <= 0 then return end
                -- Dragging down scrolls down, and the cursor axis points up.
                scroller.ScrollTo(startScroll + (startCursor - CursorY(me)) * (limit / travel), true)
            end)
        end)
        thumb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

        scroller.Update()
        return scroller
    end
end
