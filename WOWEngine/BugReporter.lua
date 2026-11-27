local addonName, NS = ...
NS.BugReporter = {}
local BR = NS.BugReporter
local C = NS.Compat

BR.recentErrors = {}
BR.maxErrors = 12
BR.frame = nil

-- Record internal pcall-caught errors cleanly (no taint, never overrides Blizzard error handler)
function NS:RecordError(context, errMsg)
    local entry = {
        time = date("%Y-%m-%d %H:%M:%S"),
        context = tostring(context or "runtime"),
        message = tostring(errMsg or "unknown error"),
    }
    table.insert(BR.recentErrors, 1, entry)
    while #BR.recentErrors > BR.maxErrors do
        table.remove(BR.recentErrors)
    end
end

-- Pull any WOWEngine/HordeEngine/AllianceEngine errors from BugGrabber if installed
local function CollectBugGrabberErrors()
    local found = {}
    if _G.BugGrabber and _G.BugGrabber.GetDB then
        local ok, db = pcall(_G.BugGrabber.GetDB, _G.BugGrabber)
        if ok and type(db) == "table" then
            for i = #db, math.max(1, #db - 15), -1 do
                local err = db[i]
                if type(err) == "table" and type(err.message) == "string" then
                    local m = err.message
                    if string.find(m, "WOWEngine") or string.find(m, "HordeEngine") or string.find(m, "AllianceEngine") then
                        local stack = type(err.stack) == "string" and ("\n" .. err.stack) or ""
                        table.insert(found, string.format("[%s] %s%s", tostring(err.time or "?"), m, stack))
                        if #found >= 5 then break end
                    end
                end
            end
        end
    end
    return found
end

function BR:GenerateReportText()
    local ver, build, buildDate, iface = GetBuildInfo()
    local realm, faction = NS:GetContextKeys()
    local rules = NS:GetActiveRules()
    local custom = NS:GetCustomRules()

    local mappedCats = 0
    for _, cat in ipairs(NS.CATEGORIES) do
        local t = rules[cat.key]
        if type(t) == "table" and #t > 0 then
            mappedCats = mappedCats + 1
        end
    end

    local lines = {
        "```text",
        "=== WOWEngine Diagnostic & Error Report ===",
        "Addon Version: " .. tostring(NS.Version),
        "Client Build: " .. tostring(ver) .. " (" .. tostring(build) .. ") | Date: " .. tostring(buildDate),
        "Interface: " .. tostring(iface),
        "Context: " .. tostring(realm) .. " (" .. tostring(faction) .. ")",
        "Verified Alts: " .. tostring(NS.Roster and NS.Roster:GetVerifiedCount() or 0)
            .. " | Mapped Categories: " .. tostring(mappedCats)
            .. " | Custom Additions: " .. tostring(#custom),
        "Multi-Alt Mode: " .. tostring(WOWEngineDB and WOWEngineDB.multiAltMode or "roundrobin")
            .. " | KeepOwnMats: " .. tostring(WOWEngineDB and WOWEngineDB.keepOwnCategoryMats),
        "Max Bag Index: " .. tostring(C.GetMaxBagIndex()),
        "Bridges: Altoholic=" .. tostring(C.IsAltoholicAvailable())
            .. " | Mastercraft=" .. tostring(C.IsMastercraftAvailable())
            .. " | Auctionator=" .. tostring(C.IsAuctionatorAvailable())
            .. " | Questie=" .. tostring(C.IsAddOnLoaded("Questie")),
        "",
        "--- Captured WOWEngine Errors ---",
    }

    local anyErr = false
    for idx, e in ipairs(BR.recentErrors) do
        anyErr = true
        table.insert(lines, string.format("#%d [%s] (%s): %s", idx, e.time, e.context, e.message))
    end

    local bgErrors = CollectBugGrabberErrors()
    if #bgErrors > 0 then
        anyErr = true
        table.insert(lines, "")
        table.insert(lines, "--- BugGrabber Stack Traces ---")
        for _, trace in ipairs(bgErrors) do
            table.insert(lines, trace)
        end
    end

    if not anyErr then
        table.insert(lines, "(No Lua errors captured in this session. Paste any additional error text below.)")
    end
    table.insert(lines, "```")

    return table.concat(lines, "\n")
end

function BR:Show()
    if not BR.frame then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local f = CreateFrame("Frame", "WOWEngineBugReportFrame", UIParent, template)
        f:SetSize(540, 390)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(140)
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

        if f.SetBackdrop then
            pcall(function()
                f:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 14,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 },
                })
                f:SetBackdropColor(0.04, 0.09, 0.19, 0.97)
                f:SetBackdropBorderColor(0.95, 0.78, 0.18, 1.0)
            end)
        end

        if UISpecialFrames then
            table.insert(UISpecialFrames, "WOWEngineBugReportFrame")
        end

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetText("|cff00aeffWOWEngine|r |cffffd100Bug Report & Log Exporter|r")

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        hint:SetWidth(500)
        hint:SetJustifyH("LEFT")
        hint:SetText("Press |cffffd100Ctrl+C|r to copy this report, then paste it into a new GitHub Issue so the WOWEngine Error-Triage Agent can diagnose and patch it automatically.")

        local scroll = CreateFrame("ScrollFrame", "WOWEngineBugReportScroll", f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 14, -68)
        scroll:SetPoint("BOTTOMRIGHT", -34, 44)

        local editBox = CreateFrame("EditBox", "WOWEngineBugReportEditBox", scroll)
        editBox:SetMultiLine(true)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetWidth(480)
        editBox:SetAutoFocus(false)
        editBox:SetScript("OnEscapePressed", function() f:Hide() end)
        scroll:SetScrollChild(editBox)
        f.editBox = editBox

        local selectBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        selectBtn:SetSize(130, 24)
        selectBtn:SetPoint("BOTTOMLEFT", 14, 12)
        selectBtn:SetText("Select All (Ctrl+C)")
        selectBtn:SetScript("OnClick", function()
            f.editBox:SetFocus()
            f.editBox:HighlightText()
        end)

        local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        clearBtn:SetSize(115, 24)
        clearBtn:SetPoint("LEFT", selectBtn, "RIGHT", 8, 0)
        clearBtn:SetText("Clear Log Buffer")
        clearBtn:SetScript("OnClick", function()
            BR.recentErrors = {}
            f.editBox:SetText(BR:GenerateReportText())
            NS:Print("Cleared in-session error log buffer.")
        end)

        local doneBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        doneBtn:SetSize(80, 24)
        doneBtn:SetPoint("BOTTOMRIGHT", -14, 12)
        doneBtn:SetText("Close")
        doneBtn:SetScript("OnClick", function() f:Hide() end)

        BR.frame = f
    end

    local text = BR:GenerateReportText()
    BR.frame.editBox:SetText(text)
    BR.frame:Show()
    BR.frame:Raise()
    BR.frame.editBox:SetFocus()
    BR.frame.editBox:HighlightText()
end
