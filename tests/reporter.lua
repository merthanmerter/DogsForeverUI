-- The beta's Issue Reporter: its box hidden and its tooltip hints dropped while
-- the Menus option is on, F6 still registered, and both back when it is off.
local ADDON_PATH, TOC_TEXT = ...
assert(loadfile(ADDON_PATH .. "/tests/wow.lua"))(ADDON_PATH, TOC_TEXT)

LoadAddon()

Section("no reporter on this client is not an error")
do
    local ok, err = pcall(Login)
    check("login without Blizzard_PTRFeedback", ok, err)
end

-- The reporter, as Blizzard_PTRFeedback builds it: a shown frame, and the
-- function its tooltip hooks ask whether to add the hint. It loads after the
-- addon here, so the addon has to pick it up from ADDON_LOADED.
local reporter = CreateFrame("Frame", "PTR_IssueReporter", UIParent)
local registeredCalls = 0
reporter.CurrentTooltipSurvey = {}
function reporter.SetCurrentTooltipReport(tooltip)
    registeredCalls = registeredCalls + 1
    reporter.CurrentTooltipSurvey = { Frame = tooltip }
    return true
end
local tooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
Fire("ADDON_LOADED", "Blizzard_PTRFeedback")

local DB = DogsForeverUI.Menus.db

Section("hidden by default")
check("the option defaults on", DB.hideIssueReporter == true)
check("the box is hidden", reporter.shown == false)
check("a tooltip gets no hint",
    reporter.SetCurrentTooltipReport(tooltip) == false)
check("but F6 still knows what is under the mouse",
    registeredCalls == 1 and reporter.CurrentTooltipSurvey.Frame == tooltip)

Section("the game showing it again")
reporter:Show()
check("is hidden again at once", reporter.shown == false)

Section("the option off hands it back")
tooltip.shown = true
DB.hideIssueReporter = false
DogsForeverUI.Menus.Refresh()
check("the box is shown", reporter.shown == true)
check("an open tooltip closes so it is rebuilt with its hint", tooltip.shown == false)
check("tooltips get the hint", reporter.SetCurrentTooltipReport(tooltip) == true)
reporter:Hide()
reporter:Show()
check("and the game may show it", reporter.shown == true)

Section("on again")
DB.hideIssueReporter = true
DogsForeverUI.Menus.Refresh()
check("hidden", reporter.shown == false)
check("no hint", reporter.SetCurrentTooltipReport(tooltip) == false)

Section("a reload does not wrap it twice")
Fire("PLAYER_ENTERING_WORLD")
Fire("ADDON_LOADED", "Blizzard_PTRFeedback")
local before = registeredCalls
reporter.SetCurrentTooltipReport(tooltip)
check("the original runs once per call", registeredCalls == before + 1)

Summary()
