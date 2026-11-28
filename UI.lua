local addonName, NS = ...
local C = NS.Compat

local function SafeOpenOnboarding(mode, stepNum)
    if not (NS.Onboarding and NS.Onboarding.Show) then
        NS:Print("|cffff4444Setup Wizard module is not loaded.|r Ensure all files in WOWEngine/ were extracted cleanly.")
        return
    end
    local ok, err = pcall(function()
        if mode == "toggle" then
            NS.Onboarding:Toggle()
        else
            NS.Onboarding:Show(stepNum or 1)
        end
    end)
    if not ok then
        if NS.RecordError then NS:RecordError("SetupWizard", err) end
        NS:Print("|cffff4444Setup Wizard error:|r " .. tostring(err))
    end
end

local function PrintHelp()
    NS:Print("=== WOWEngine v" .. NS.Version .. " (IllusoryBias) Command Reference ===")
    NS:Print("|cffffd100/he|r or |cffffd100/he setup|r (also |cffffd100/we|r, |cffffd100/wowengine|r) - Open 5-step Onboarding Wizard")
    NS:Print("|cffffd100/he scan|r / |cffffd100/he roster|r - Scan current char, Altoholic/DataStore, guild & friends")
    NS:Print("|cffffd100/he rules|r - View active multi-alt mail routing rules")
    NS:Print("|cffffd100/he addrule <Category> <AltName>|r - Add verified alt to a category (supports multiple alts!)")
    NS:Print("|cffffd100/he delrule <Category> <AltName>|r - Remove an alt from a category")
    NS:Print("|cffffd100/he setbank|r - Add current character as a verified BankAlt")
    NS:Print("|cffffd100/he mode|r - Toggle Multi-Alt Mode (Round-Robin Split vs Priority)")
    NS:Print("|cffffd100/he name|r - Generate IllusoryBias derivative name for current class/profs")
    NS:Print("|cffffd100/hordeship|r [AltName | next] - Stage up to 12 items (bundles all mats for same alt; blocks self-mail)")
    NS:Print("|cffffd100/hordeship bank|r / |cffffd100bags|r - Sort bank or bag containers")
    NS:Print("|cffffd100/hordebank|r - Display cross-character gold ledger")
    NS:Print("|cffffd100/he minimap|r - Toggle minimap button visibility")
    NS:Print("|cffffd100/he diag|r - Print live client, Altoholic & Mastercraft diagnostic check")
    NS:Print("|cffffd100/he wave|r (or |cffffd100/he questie|r) - Open Questie Checklist & Wave Gate Sync")
    NS:Print("|cffffd100/he trainer [prof|all]|r - Show faction profession trainer coordinates")
    NS:Print("|cffffd100/he dock|r - Toggle or re-snap WOWEngine heading onto Questie quest list")
    NS:Print("|cffffd100/he snooze [mins]|r - Snooze Wave Gate alert on this character")
    NS:Print("|cffffd100/he bugreport|r - Open copy-pasteable Error Report for GitHub Triage Agent")
end

-- Slash Commands: Shipment & Sorting
SLASH_WOWENGINESHIP1 = "/hordeship"
SLASH_WOWENGINESHIP2 = "/allianceship"
SLASH_WOWENGINESHIP3 = "/wowship"
SlashCmdList["WOWENGINESHIP"] = function(msg)
    local ok, err = pcall(function()
        local cmd = C.Trim(msg)
        local lower = string.lower(cmd)
        if lower == "bank" then
            NS.BankSorter:RunSort("bank")
        elseif lower == "bags" or lower == "sort" then
            NS.BankSorter:RunSort("bags")
        elseif lower == "next" then
            NS.MailRouter:CycleNextTarget()
        elseif lower == "boe" or lower == "boes" or lower == "de" then
            NS.MailRouter:StageBoEsOnly()
        elseif cmd ~= "" then
            NS.MailRouter:StageNextBatch(cmd)
        else
            NS.MailRouter:StageNextBatch(nil)
        end
    end)
    if not ok then
        if NS.RecordError then NS:RecordError("/hordeship", err) end
        NS:Print("|cffff4444Error in /hordeship:|r " .. tostring(err))
    end
end

-- Slash Commands: Wealth Ledger
SLASH_WOWENGINEBANK1 = "/hordebank"
SLASH_WOWENGINEBANK2 = "/alliancebank"
SLASH_WOWENGINEBANK3 = "/wowbank"
SlashCmdList["WOWENGINEBANK"] = function()
    local ok, err = pcall(function()
        NS.BankSorter:PrintGoldLedger()
    end)
    if not ok then
        NS:Print("|cffff4444Error in /hordebank:|r " .. tostring(err))
    end
end

-- Slash Commands: Main Hub (/he, /we, /wowengine, /hordeengine, /allianceengine)
SLASH_WOWENGINEHELP1 = "/he"
SLASH_WOWENGINEHELP2 = "/we"
SLASH_WOWENGINEHELP3 = "/wowengine"
SLASH_WOWENGINEHELP4 = "/hordeengine"
SLASH_WOWENGINEHELP5 = "/allianceengine"
SlashCmdList["WOWENGINEHELP"] = function(msg)
    local ok, err = pcall(function()
        local raw = C.Trim(msg)
        local cmd, rest = string.match(raw, "^(%S+)%s*(.*)$")
        cmd = string.lower(cmd or "")

        if cmd == "setup" or cmd == "wizard" or cmd == "onboard" or cmd == "ui" or cmd == "" then
            SafeOpenOnboarding("show", 1)
        elseif cmd == "help" or cmd == "?" then
            PrintHelp()
        elseif cmd == "scan" or cmd == "roster" then
            NS.Roster:ScanAll(false)
        elseif cmd == "rules" then
            NS.Roster:ScanAll(true)
            local rules = NS:GetActiveRules()
            NS:Print("=== Active Multi-Alt Mail Routes (Mode: " .. tostring(WOWEngineDB.multiAltMode) .. ") ===")
            local count = 0
            for _, cat in ipairs(NS.CATEGORIES) do
                local t = rules[cat.key]
                if type(t) == "table" and #t > 0 then
                    count = count + 1
                    NS:Print("  [" .. cat.key .. "] -> |cff00ff00" .. table.concat(t, ", ") .. "|r")
                end
            end
            if count == 0 then
                NS:Print("  No verified routes mapped yet. Open |cffffd100/he setup|r -> Step 3.")
            end
        elseif cmd == "setbank" then
            NS.Roster:ScanCurrentPlayer()
            local exact = C.GetPlayerName()
            if exact then
                NS.Roster:AddTargetToCategory("BankAlt", exact, true)
                NS:Print("Added verified BankAlt: |cff00ff00" .. exact .. "|r")
            end
        elseif cmd == "name" then
            local _, classToken = UnitClass("player")
            local profs = C.GetPlayerProfessions()
            local plist = {}
            for p in pairs(profs) do table.insert(plist, p) end
            NS:Print("IllusoryBias Derivative Name: |cffffd100" .. NS:SuggestDerivativeName(classToken, plist[1], plist[2]) .. "|r")
        elseif cmd == "addrule" or cmd == "setrule" then
            local cat, alt = string.match(rest or "", "^(%S+)%s+(.+)$")
            if cat and alt then
                NS.Roster:ScanAll(true)
                local added, res = NS.Roster:AddTargetToCategory(cat, alt, true)
                if added then
                    NS:Print("Added verified route: [" .. cat .. "] += |cff00ff00" .. res .. "|r")
                else
                    NS:Print("|cffff4444Rejected:|r '" .. alt .. "' is not in your verified character roster. Open |cffffd100/he setup|r.")
                end
            else
                NS:Print("Usage: |cffffd100/he addrule Cloth ExactAltName|r")
            end
        elseif cmd == "delrule" then
            local cat, alt = string.match(rest or "", "^(%S+)%s+(.+)$")
            if cat and alt then
                if NS.Roster:RemoveTargetFromCategory(cat, alt, true) then
                    NS:Print("Removed [" .. alt .. "] from [" .. cat .. "].")
                else
                    NS:Print("'" .. alt .. "' was not assigned to [" .. cat .. "].")
                end
            else
                NS:Print("Usage: |cffffd100/he delrule Cloth ExactAltName|r")
            end
        elseif cmd == "testcustom" then
            NS.MailRouter:DiagnoseCustomMatches()
        elseif cmd == "custom" then
            if NS.Onboarding and NS.Onboarding.OpenCustomAdditionsPopup then
                NS.Onboarding:OpenCustomAdditionsPopup()
            end
        elseif cmd == "mode" then
            if WOWEngineDB.multiAltMode == "roundrobin" then
                WOWEngineDB.multiAltMode = "priority"
            else
                WOWEngineDB.multiAltMode = "roundrobin"
            end
            NS:Print("Multi-Alt Distribution Mode set to: |cffffd100" .. WOWEngineDB.multiAltMode .. "|r")
        elseif cmd == "talent" or cmd == "talents" or cmd == "spec" then
            local sub = string.lower(C.Trim(rest or ""))
            if sub == "audit" then
                if NS.TalentAdvisor and NS.TalentAdvisor.AuditClassBuilds then
                    NS.TalentAdvisor:AuditClassBuilds()
                end
            elseif NS.TalentAdvisor and NS.TalentAdvisor.PrintNextPick then
                NS.TalentAdvisor:PrintNextPick()
            end
        elseif cmd == "stats" or cmd == "caps" or cmd == "statcaps" then
            if NS.StatCapsUI and NS.StatCapsUI.Toggle then NS.StatCapsUI:Toggle() end
        elseif cmd == "plan" or cmd == "planbuilder" then
            local sub = string.lower(C.Trim(rest or ""))
            if sub == "secondary" or sub == "dual" or sub == "2" then
                if NS.PlanBuilder and NS.PlanBuilder.ShowSecondaryWizard then
                    NS.PlanBuilder:ShowSecondaryWizard()
                end
            elseif NS.PlanBuilder and NS.PlanBuilder.Show then
                NS.PlanBuilder:Show()
            end
        elseif cmd == "nag" or cmd == "pointnag" then
            if NS.PointNagBanner and NS.PointNagBanner.HandleSlashCommand then
                NS.PointNagBanner:HandleSlashCommand(rest)
            end
        elseif cmd == "wavewizard" or cmd == "wizard" then
            if NS.WaveTracker and NS.WaveTracker.OpenWaveWizard then NS.WaveTracker:OpenWaveWizard() end
        elseif cmd == "options" or cmd == "config" or cmd == "settings" then
            if NS.SettingsPanel and NS.SettingsPanel.Open then NS.SettingsPanel:Open() end
        elseif cmd == "bagstatus" or cmd == "bagpriority" then
            if NS.BagRouter and NS.BagRouter.PrintBagStatus then NS.BagRouter:PrintBagStatus() end
        elseif cmd == "boe" or cmd == "boes" then
            NS.MailRouter:StageBoEsOnly()
        elseif cmd == "ship" then
            NS.MailRouter:StageNextBatch(C.Trim(rest))
        elseif cmd == "bank" then
            NS.BankSorter:RunSort("bank")
        elseif cmd == "bags" or cmd == "sort" then
            NS.BankSorter:RunSort("bags")
        elseif cmd == "gold" or cmd == "ledger" then
            NS.BankSorter:PrintGoldLedger()
        elseif cmd == "minimap" then
            WOWEngineDB.minimapHide = not WOWEngineDB.minimapHide
            if not _G.WOWEngineMinimapButton then
                NS:InitMinimapButton()
            end
            if _G.WOWEngineMinimapButton then
                if WOWEngineDB.minimapHide then
                    _G.WOWEngineMinimapButton:Hide()
                    NS:Print("Minimap button hidden. Type |cffffd100/he minimap|r to restore.")
                else
                    _G.WOWEngineMinimapButton:Show()
                    NS:Print("Minimap button shown.")
                end
            end
        elseif cmd == "wave" or cmd == "questie" or cmd == "checklist" then
            if NS.WaveTracker and NS.WaveTracker.ShowUI then
                NS.WaveTracker:ShowUI()
            end
        elseif cmd == "trainer" or cmd == "trainers" then
            if NS.WaveTracker and NS.WaveTracker.PrintTrainerLookup then
                NS.WaveTracker:PrintTrainerLookup(rest)
            end
        elseif cmd == "dock" then
            local ws = NS:GetWaveState()
            ws.dockQuestieHeader = not ws.dockQuestieHeader
            if ws.dockQuestieHeader then
                NS.WaveTracker:InitQuestieDock()
                NS:Print("WOWEngine heading docked onto Questie quest list.")
            else
                if NS.WaveTracker.questieDock then NS.WaveTracker.questieDock:Hide() end
                NS:Print("WOWEngine Questie heading hidden. Type |cffffd100/he dock|r to restore.")
            end
        elseif cmd == "exclude" then
            local target = C.Trim(rest or "")
            if target ~= "" then
                local okEx, exact = NS.Roster:SetWaveExcluded(target, true)
                if okEx then
                    NS:Print("Excluded |cffff9900" .. exact .. "|r from Wave Leveling Sync (kept for Mail).")
                    if NS.WaveTracker then NS.WaveTracker:RefreshUI(); NS.WaveTracker:RefreshQuestieDock() end
                else
                    NS:Print("Character '" .. target .. "' not found in verified roster.")
                end
            else
                if NS.WaveTracker and NS.WaveTracker.OpenManageAltsPopup then NS.WaveTracker:OpenManageAltsPopup() end
            end
        elseif cmd == "include" then
            local target = C.Trim(rest or "")
            if target ~= "" then
                local okIn, exact = NS.Roster:SetWaveExcluded(target, false)
                if okIn then
                    NS:Print("Included |cff00ff00" .. exact .. "|r in Wave Leveling Sync.")
                    if NS.WaveTracker then NS.WaveTracker:RefreshUI(); NS.WaveTracker:RefreshQuestieDock() end
                else
                    NS:Print("Character '" .. target .. "' not found in verified roster.")
                end
            else
                if NS.WaveTracker and NS.WaveTracker.OpenManageAltsPopup then NS.WaveTracker:OpenManageAltsPopup() end
            end
        elseif cmd == "excludemail" then
            local target = C.Trim(rest or "")
            if target ~= "" then
                local okEx, exact = NS.Roster:SetMailExcluded(target, true)
                if okEx then
                    NS:Print("Excluded |cffff9900" .. exact .. "|r from Mail Routing.")
                else
                    NS:Print("Character '" .. target .. "' not found in verified roster.")
                end
            else
                NS:Print("Usage: |cffffd100/he excludemail CharacterName|r")
            end
        elseif cmd == "includemail" then
            local target = C.Trim(rest or "")
            if target ~= "" then
                local okIn, exact = NS.Roster:SetMailExcluded(target, false)
                if okIn then
                    NS:Print("Re-enabled |cff00ff00" .. exact .. "|r for Mail Routing.")
                else
                    NS:Print("Character '" .. target .. "' not found in verified roster.")
                end
            else
                NS:Print("Usage: |cffffd100/he includemail CharacterName|r")
            end
        elseif cmd == "snooze" then
            if NS.WaveTracker and NS.WaveTracker.Snooze then
                NS.WaveTracker:Snooze(tonumber(rest) or 30)
            end
        elseif cmd == "setbugurl" then
            local newUrl = C.Trim(rest or "")
            if newUrl ~= "" then
                WOWEngineDB.bugReportUrl = newUrl
                NS:Print("Bug submission URL updated to: |cff00ff00" .. newUrl .. "|r")
            else
                NS:Print("Current Bug URL: |cffffd100" .. (NS.BugReporter and NS.BugReporter:GetSubmissionURL() or "?") .. "|r")
                NS:Print("Usage: |cffffd100/he setbugurl https://github.com/YOUR_USER/WOWEngine/issues/new?template=bug_report.yml|r")
            end
        elseif cmd == "bugreport" or cmd == "bug" or cmd == "report" then
            if NS.BugReporter and NS.BugReporter.Show then
                NS.BugReporter:Show()
            end
        elseif cmd == "diag" then
            local ver, build, _, iface = GetBuildInfo()
            local realm, faction = NS:GetContextKeys()
            NS:Print("=== WOWEngine v" .. NS.Version .. " Diagnostic ===")
            NS:Print("Client: " .. tostring(ver) .. " (" .. tostring(build) .. ") | Interface: " .. tostring(iface))
            NS:Print("Context: " .. realm .. " (" .. faction .. ") | Verified Alts: " .. tostring(NS.Roster:GetVerifiedCount()) .. " | Mode: " .. tostring(WOWEngineDB.multiAltMode))
            NS:Print("KeepOwnMats: " .. tostring(WOWEngineDB.keepOwnCategoryMats) .. " | Onboarding: " .. tostring(NS.Onboarding ~= nil))
            NS:Print("Bridges -> Altoholic: " .. tostring(C.IsAltoholicAvailable()) .. " | Mastercraft: " .. tostring(C.IsMastercraftAvailable()) .. " | Auctionator: " .. tostring(C.IsAuctionatorAvailable()))
            NS:Print("MinimapButton: " .. tostring(_G.WOWEngineMinimapButton ~= nil) .. " (Shown: " .. tostring(_G.WOWEngineMinimapButton and _G.WOWEngineMinimapButton:IsShown()) .. ")")
        else
            NS:Print("|cffff9900Unknown /he command:|r '" .. cmd .. "'. Available commands:")
            PrintHelp()
        end
    end)
    if not ok then
        if NS.RecordError then NS:RecordError("/he", err) end
        NS:Print("|cffff4444Error in /he command:|r " .. tostring(err))
    end
end

-- Mailbox UI Buttons: Strictly parented to SendMailFrame (NEVER shown on Inbox Tab 1)
local function EnsureMailButtons()
    if not SendMailFrame then return end

    local btn = _G.WOWEngineMailButton
    if not btn then
        btn = CreateFrame("Button", "WOWEngineMailButton", SendMailFrame, "UIPanelButtonTemplate")
        btn:SetSize(112, 24)
        btn:SetFrameStrata("HIGH")
        btn:SetText("Stage Shipment")
        btn:SetScript("OnClick", function()
            local ok, err = pcall(function()
                NS.MailRouter:StageNextBatch(nil)
            end)
            if not ok then
                NS:Print("|cffff4444Stage Shipment error:|r " .. tostring(err))
            end
        end)
    end
    btn:ClearAllPoints()
    if MailFrameTab2 then
        btn:SetPoint("LEFT", MailFrameTab2, "RIGHT", 8, 2)
    else
        btn:SetPoint("BOTTOMRIGHT", SendMailFrame, "BOTTOMRIGHT", -10, -28)
    end

    local prevAltBtn = _G.WOWEngineMailPrevAltButton
    if not prevAltBtn then
        prevAltBtn = CreateFrame("Button", "WOWEngineMailPrevAltButton", SendMailFrame, "UIPanelButtonTemplate")
        prevAltBtn:SetSize(22, 24)
        prevAltBtn:SetFrameStrata("HIGH")
        prevAltBtn:SetText("<")
        prevAltBtn:SetScript("OnClick", function()
            local ok, err = pcall(function()
                if NS.MailRouter.CyclePrevTarget then
                    NS.MailRouter:CyclePrevTarget()
                else
                    NS.MailRouter:CycleNextTarget()
                end
            end)
            if not ok then
                NS:Print("|cffff4444Prev Alt error:|r " .. tostring(err))
            end
        end)
    end
    prevAltBtn:ClearAllPoints()
    prevAltBtn:SetPoint("LEFT", btn, "RIGHT", 4, 0)

    local nextBtn = _G.WOWEngineMailNextAltButton
    if not nextBtn then
        nextBtn = CreateFrame("Button", "WOWEngineMailNextAltButton", SendMailFrame, "UIPanelButtonTemplate")
        nextBtn:SetSize(64, 24)
        nextBtn:SetFrameStrata("HIGH")
        nextBtn:SetText("Next Alt")
        nextBtn:SetScript("OnClick", function()
            local ok, err = pcall(function()
                NS.MailRouter:CycleNextTarget()
            end)
            if not ok then
                NS:Print("|cffff4444Next Alt error:|r " .. tostring(err))
            end
        end)
    end
    nextBtn:ClearAllPoints()
    nextBtn:SetPoint("LEFT", prevAltBtn, "RIGHT", 2, 0)

    local nextAltArrowBtn = _G.WOWEngineMailNextAltArrowButton
    if not nextAltArrowBtn then
        nextAltArrowBtn = CreateFrame("Button", "WOWEngineMailNextAltArrowButton", SendMailFrame, "UIPanelButtonTemplate")
        nextAltArrowBtn:SetSize(22, 24)
        nextAltArrowBtn:SetFrameStrata("HIGH")
        nextAltArrowBtn:SetText(">")
        nextAltArrowBtn:SetScript("OnClick", function()
            local ok, err = pcall(function()
                NS.MailRouter:CycleNextTarget()
            end)
            if not ok then
                NS:Print("|cffff4444Next Alt error:|r " .. tostring(err))
            end
        end)
    end
    nextAltArrowBtn:ClearAllPoints()
    nextAltArrowBtn:SetPoint("LEFT", nextBtn, "RIGHT", 2, 0)

    local setupBtn = _G.WOWEngineMailSetupButton
    if not setupBtn then
        setupBtn = CreateFrame("Button", "WOWEngineMailSetupButton", SendMailFrame, "UIPanelButtonTemplate")
        setupBtn:SetSize(52, 24)
        setupBtn:SetFrameStrata("HIGH")
        setupBtn:SetText("Setup")
        setupBtn:SetScript("OnClick", function()
            SafeOpenOnboarding("show", 3)
        end)
    end
    setupBtn:ClearAllPoints()
    setupBtn:SetPoint("LEFT", nextAltArrowBtn, "RIGHT", 4, 0)
end

local btnHook = CreateFrame("Frame")
btnHook:RegisterEvent("MAIL_SHOW")
btnHook:SetScript("OnEvent", function()
    EnsureMailButtons()
end)

-- Native WoW Forever / Mainline 12.x Minimap Addon Compartment callback
function _G.WOWEngine_OnAddonCompartmentClick(addon, buttonName)
    if buttonName == "RightButton" then
        if NS.MailRouter.isMailboxOpen or (MailFrame and MailFrame:IsShown()) then
            NS.MailRouter:StageNextBatch(nil)
        elseif NS.BankSorter.isBankOpen or (BankFrame and BankFrame:IsShown()) then
            NS.BankSorter:RunSort("bank")
        else
            NS.BankSorter:RunSort("bags")
        end
    else
        SafeOpenOnboarding("toggle")
    end
end

-- Blizzard Blue & Gold Right-Click Quick Actions Menu for Minimap Button
local function ToggleMinimapQuickMenu(anchorBtn)
    local menu = _G.WOWEngineMinimapMenu
    if menu and menu:IsShown() then
        menu:Hide()
        return
    end

    if not menu then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        menu = CreateFrame("Frame", "WOWEngineMinimapMenu", UIParent, template)
        menu:SetSize(208, 396)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(160)
        menu:SetClampedToScreen(true)
        menu:EnableMouse(true)

        if menu.SetBackdrop then
            pcall(function()
                menu:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 12,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 },
                })
                menu:SetBackdropColor(0.04, 0.09, 0.19, 0.97)
                menu:SetBackdropBorderColor(0.95, 0.78, 0.18, 1.0)
            end)
        end

        if UISpecialFrames then
            table.insert(UISpecialFrames, "WOWEngineMinimapMenu")
        end

        local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetPoint("TOPLEFT", 10, -8)
        title:SetText("|cff00aeffWOWEngine|r |cffffd100Quick Menu|r")

        local closeBtn = CreateFrame("Button", nil, menu, "UIPanelCloseButton")
        closeBtn:SetSize(20, 20)
        closeBtn:SetPoint("TOPRIGHT", -2, -2)
        closeBtn:SetScript("OnClick", function() menu:Hide() end)

        local actions = {
            { label = "Plan Builder (/he plan)", fn = function() if NS.PlanBuilder then NS.PlanBuilder:Show() end end },
            { label = "Open Setup Wizard",       fn = function() SafeOpenOnboarding("show", 1) end },
            { label = "AddOn Options (Quick)",   fn = function() if NS.SettingsPanel then NS.SettingsPanel:Open() end end },
            { label = "Questie & Wave Sync",     fn = function() if NS.WaveTracker then NS.WaveTracker:ShowUI() end end },
            { label = "Wave Setup Wizard",       fn = function() if NS.WaveTracker then NS.WaveTracker:OpenWaveWizard() end end },
            { label = "Stat Caps & Targets",     fn = function() if NS.StatCapsUI then NS.StatCapsUI:Toggle() end end },
            { label = "Manage Wave Alts",        fn = function() if NS.WaveTracker then NS.WaveTracker:OpenManageAltsPopup() end end },
            { label = "Stage Mail / Sort Bags",  fn = function()
                if NS.MailRouter.isMailboxOpen or (MailFrame and MailFrame:IsShown()) then
                    NS.MailRouter:StageNextBatch(nil)
                elseif NS.BankSorter.isBankOpen or (BankFrame and BankFrame:IsShown()) then
                    NS.BankSorter:RunSort("bank")
                else
                    NS.BankSorter:RunSort("bags")
                end
            end },
            { label = "Stage AH / DE BoEs",     fn = function() NS.MailRouter:StageBoEsOnly() end },
            { label = "Bag Upgrade Priority",   fn = function() if NS.BagRouter then NS.BagRouter:PrintBagStatus() end end },
            { label = "Wealth Ledger (/hordebank)", fn = function() NS.BankSorter:PrintGoldLedger() end },
            { label = "Toggle Questie Heading",  fn = function() SlashCmdList["WOWENGINEHELP"]("dock") end },
            { label = "Copy Bug Report",         fn = function() if NS.BugReporter then NS.BugReporter:Show() end end },
            { label = "Lock / Unlock Minimap",   fn = function()
                WOWEngineDB.minimapLock = not WOWEngineDB.minimapLock
                NS:Print("Minimap button " .. (WOWEngineDB.minimapLock and "|cffffd100Locked|r." or "|cff00ff00Unlocked|r (drag to move)."))
            end },
            { label = "Hide Minimap Button",     fn = function() SlashCmdList["WOWENGINEHELP"]("minimap") end },
        }

        for idx, act in ipairs(actions) do
            local b = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
            b:SetSize(188, 22)
            b:SetPoint("TOPLEFT", 10, -28 - (idx - 1) * 24)
            b:SetText(act.label)
            b:SetScript("OnClick", function()
                menu:Hide()
                local ok, err = pcall(act.fn)
                if not ok then
                    if NS.RecordError then NS:RecordError("MinimapMenu", err) end
                    NS:Print("|cffff4444Quick Menu error:|r " .. tostring(err))
                end
            end)
        end
    end

    menu:ClearAllPoints()
    if anchorBtn then
        menu:SetPoint("TOPRIGHT", anchorBtn, "BOTTOMLEFT", 0, -2)
    else
        menu:SetPoint("CENTER", UIParent, "CENTER")
    end
    menu:Show()
    menu:Raise()
end

-- Draggable Minimap Button (Left-Click: Setup, Shift+Left-Click: Wave Sync, Right-Click: Quick Menu)
function NS:InitMinimapButton()
    if not Minimap then return end
    local mm = _G.WOWEngineMinimapButton
    if not mm then
        mm = CreateFrame("Button", "WOWEngineMinimapButton", Minimap)
        mm:SetSize(32, 32)
        mm:SetFrameStrata("HIGH")
        mm:SetFrameLevel(20)
        mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

        local bg = mm:CreateTexture(nil, "BACKGROUND")
        bg:SetSize(22, 22)
        bg:SetTexture(133633)
        bg:SetPoint("CENTER", 0, 0)
        if bg.SetMask then
            bg:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        end

        local border = mm:CreateTexture(nil, "OVERLAY")
        border:SetSize(54, 54)
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetPoint("TOPLEFT", 0, 0)

        local function UpdatePosition()
            local angle = math.rad((WOWEngineDB and WOWEngineDB.minimapAngle) or 215)
            local w = Minimap:GetWidth() or 140
            local radius = (w / 2) + 8
            local x = math.cos(angle) * radius
            local y = math.sin(angle) * radius
            mm:ClearAllPoints()
            mm:SetPoint("CENTER", Minimap, "CENTER", x, y)
        end

        mm.UpdatePosition = UpdatePosition
        mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        mm:RegisterForDrag("LeftButton")

        mm:SetScript("OnDragStart", function(self)
            if WOWEngineDB and WOWEngineDB.minimapLock then return end
            self:SetScript("OnUpdate", function()
                local mx, my = Minimap:GetCenter()
                local cx, cy = GetCursorPosition()
                local scale = Minimap:GetEffectiveScale()
                cx, cy = cx / scale, cy / scale
                WOWEngineDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
                UpdatePosition()
            end)
        end)
        mm:SetScript("OnDragStop", function(self)
            self:SetScript("OnUpdate", nil)
        end)

        mm:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                if IsShiftKeyDown and IsShiftKeyDown() then
                    if NS.WaveTracker and NS.WaveTracker.ShowUI then
                        NS.WaveTracker:ShowUI()
                    end
                else
                    SafeOpenOnboarding("toggle")
                end
            elseif button == "RightButton" then
                ToggleMinimapQuickMenu(self)
            end
        end)

        mm:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("|cff00aeffWOWEngine v" .. NS.Version .. "|r (IllusoryBias)")
            GameTooltip:AddLine("|cffffffffLeft-Click:|r Open Setup & Onboarding Wizard", 0.85, 0.85, 0.85)
            GameTooltip:AddLine("|cffffffffShift + Left-Click:|r Open Questie & Wave Sync", 0.85, 0.85, 0.85)
            GameTooltip:AddLine("|cffffffffRight-Click:|r Open Quick Actions & Toggles Menu", 0.85, 0.85, 0.85)
            GameTooltip:AddLine("|cffffffffDrag:|r Reposition around Minimap" .. ((WOWEngineDB and WOWEngineDB.minimapLock) and " (Locked)" or ""), 0.65, 0.65, 0.65)
            GameTooltip:Show()
        end)
        mm:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    mm.UpdatePosition()
    if WOWEngineDB and WOWEngineDB.minimapHide then
        mm:Hide()
    else
        mm:Show()
    end
end
