-- A thin scrollbar, built by hand rather than taken from
-- UIPanelScrollFrameTemplate: which scroll templates a client ships varies, and
-- a missing one takes the whole options panel down with it.
--
-- Attach() turns a plain ScrollFrame into a scrolling one: mouse wheel, a track
-- and a draggable thumb sized to how much of the content fits, clamped at both
-- ends, and hidden entirely when nothing overflows.

local ScrollBar = {}
DogsForeverUI.ScrollBar = ScrollBar

local WIDTH = 8
local MIN_THUMB = 24
local WHEEL_STEP = 40

local function ContentHeight(scrollFrame)
    local child = scrollFrame:GetScrollChild()
    return child and child:GetHeight() or 0
end

-- Cursor coordinates come back in screen units, so divide by the UI scale to
-- compare them against frame heights.
local function CursorY()
    local _, y = GetCursorPosition()
    return y / UIParent:GetEffectiveScale()
end

-- scrollFrame  a ScrollFrame that already has its scroll child set
--
-- Returns the update function, for a panel to call when it is shown or its
-- content changes.
function ScrollBar.Attach(scrollFrame)
    local track = CreateFrame("Frame", nil, scrollFrame:GetParent())
    track:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 4, 0)
    track:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 4, 0)
    track:SetWidth(WIDTH)

    local trackTexture = track:CreateTexture(nil, "BACKGROUND")
    trackTexture:SetAllPoints()
    trackTexture:SetColorTexture(1, 1, 1, 0.07)

    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetWidth(WIDTH)
    thumb:SetHeight(MIN_THUMB)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb:EnableMouse(true)
    thumb:RegisterForDrag("LeftButton")

    local thumbTexture = thumb:CreateTexture(nil, "ARTWORK")
    thumbTexture:SetAllPoints()
    thumbTexture:SetColorTexture(0.65, 0.65, 0.65, 0.65)

    local function Limit()
        return ContentHeight(scrollFrame) - scrollFrame:GetHeight()
    end

    local function Update()
        local limit = Limit()
        local trackHeight = track:GetHeight()
        if limit <= 0 or trackHeight <= 0 then
            track:Hide()
            return
        end
        track:Show()

        local thumbHeight = trackHeight * (scrollFrame:GetHeight() / ContentHeight(scrollFrame))
        if thumbHeight < MIN_THUMB then thumbHeight = MIN_THUMB end
        if thumbHeight > trackHeight then thumbHeight = trackHeight end
        thumb:SetHeight(thumbHeight)

        local travel = trackHeight - thumbHeight
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0,
            -travel * (scrollFrame:GetVerticalScroll() / limit))
    end

    local function SetScroll(position)
        local limit = Limit()
        if limit <= 0 then
            scrollFrame:SetVerticalScroll(0)
        else
            if position < 0 then position = 0 end
            if position > limit then position = limit end
            scrollFrame:SetVerticalScroll(position)
        end
        Update()
    end

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        SetScroll(self:GetVerticalScroll() - delta * WHEEL_STEP)
    end)

    -- A panel may already resize its scroll child from OnSizeChanged, so chain
    -- rather than replace.
    local previousSizeChanged = scrollFrame:GetScript("OnSizeChanged")
    scrollFrame:SetScript("OnSizeChanged", function(self, ...)
        if previousSizeChanged then previousSizeChanged(self, ...) end
        Update()
    end)

    thumb:SetScript("OnDragStart", function(self)
        self.startCursor = CursorY()
        self.startScroll = scrollFrame:GetVerticalScroll()
        self:SetScript("OnUpdate", function(self)
            local travel = track:GetHeight() - self:GetHeight()
            local limit = Limit()
            if travel <= 0 or limit <= 0 then return end
            -- Dragging down scrolls down, and the cursor axis points up.
            local moved = self.startCursor - CursorY()
            SetScroll(self.startScroll + moved * (limit / travel))
        end)
    end)
    thumb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    Update()
    return Update
end
