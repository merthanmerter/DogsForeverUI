-- The beta's Issue Reporter box, and the "Press F6 to submit an issue" hints it
-- adds to tooltips, hidden while the Menus option says so.
--
-- The reporter ships in the client as the Blizzard_PTRFeedback addon. Its
-- global frame PTR_IssueReporter is created shown and no in-game code hides it.
-- Blizzard re-parents the frame while the barbershop or the house editor is
-- open (Blizzard_PTRFeedback_Events.lua), so parking it under a hidden frame
-- would not stick; hiding it does. A post-hook on Show() hides it again when
-- the game shows it later.
--
-- THE HINTS. PTR_IssueReporter.HookIntoTooltip adds a blank line and the hint
-- only when SetCurrentTooltipReport returns true (Blizzard_PTRFeedback_Frames
-- .lua). A post-hook cannot take lines out of a tooltip, so that one function is
-- wrapped: the original still runs, so F6 still reports on whatever is under the
-- mouse, and only its answer is changed to "nothing added". The reporter's
-- tooltip hooks are TooltipDataProcessor post-calls and hooksecurefunc hooks,
-- both called securely, so the wrapper's taint stays inside them.
--
-- F6 and the pop-up surveys keep working while hidden. The box's own Bug button
-- goes with it; switching the option off brings it and the hints back.

local Reporter = {}
DogsForeverUI.Menus.IssueReporter = Reporter

local REPORTER_ADDON = "Blizzard_PTRFeedback"

local ready = false        -- set at login, when the settings are in
local showHooked = false
local tooltipHooked = false

local function Hidden()
    return DogsForeverUI.Menus.db.hideIssueReporter and true or false
end

local function GetReporter()
    local reporter = _G.PTR_IssueReporter
    if type(reporter) == "table" and type(reporter.Hide) == "function" then
        return reporter
    end
    return nil
end

local function Hook(reporter)
    if not tooltipHooked and type(reporter.SetCurrentTooltipReport) == "function" then
        tooltipHooked = true
        local original = reporter.SetCurrentTooltipReport
        reporter.SetCurrentTooltipReport = function(...)
            local registered = original(...)
            if Hidden() then return false end
            return registered
        end
    end
    if not showHooked then
        showHooked = true
        hooksecurefunc(reporter, "Show", function(self)
            if Hidden() then self:Hide() end
        end)
    end
end

function Reporter:Refresh()
    if not ready then return end
    local reporter = GetReporter()
    if not reporter then return end
    Hook(reporter)

    local hidden = Hidden()
    if hidden == reporter:IsShown() then
        -- An open tooltip keeps the hint it was built with until it is hovered
        -- again, so close the one the reporter is tracking.
        local current = reporter.CurrentTooltipSurvey
        local tooltip = type(current) == "table" and current.Frame
        if tooltip and tooltip.Hide then tooltip:Hide() end
    end
    if hidden then
        reporter:Hide()
    elseif not reporter:IsShown() then
        reporter:Show()
    end
end

function Reporter:Apply()
    ready = true
    self:Refresh()
end

-- The reporter may load after this addon; it builds its box when the world is
-- entered.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name ~= REPORTER_ADDON then return end
    Reporter:Refresh()
end)
