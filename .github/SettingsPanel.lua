local addonName, NS = ...
NS.SettingsPanel = {}
local SP = NS.SettingsPanel

local spCbCounter = 0

local function CreateOptCheckbox(parent, label, getVal, setVal)
    spCbCounter = spCbCounter + 1
    local cbName = "WOWEngineOptCB" .. spCbCounter
    local cb = CreateFrame("CheckButton", cbName, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    local builtIn = _G[cbName .. "Text"] or cb.Text
    if builtIn and builtIn.SetText then builtIn:SetText("") end

    local txt = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    txt:SetText(label)

    cb:SetScript("OnClick", function(self)
        pcall(function()
            setVal(self:GetChecked() and true or false)
        end)
    end)
    cb.Refresh = function(self)
        self:SetChecked(getVal() and true or false)
    end
    return cb
end

function SP:Open()
    if not SP.panel then
        SP:Init()
    end
    if Settings and Settings.OpenToCategory then
        local catID = SP.categoryID
        if not catID and SP.category and SP.category.GetID then
            catID = SP.category:GetID()
        end
        if catID then
            local ok = pcall(Settings.OpenToCategory, catID)
            if ok then return end
        end
    end
    if InterfaceOptionsFrame_OpenToCategory and SP.panel then
        pcall(InterfaceOptionsFrame_OpenToCategory, SP.panel)
        pcall(InterfaceOptionsFrame_OpenToCategory, SP.panel)
        return
    end
    if NS.Onboarding and NS.Onboarding.Show then
        NS.Onboarding:Show(1)
    end
end

function SP:Init()
    if SP.panel then return end

    local panel = CreateFrame("Frame", "WOWEngineOptionsPanel", UIParent)
    panel.name = "WOWEngine"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("|cff00aeffWOWEngine|r |cffffd100v" .. tostring(NS.Version) .. " — Quick Config (IllusoryBias)|r")

    local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText("Unified Horde & Alliance suite: Blizzard TOS mail & bag routing, dynamic professions, Questie wave sync, and bug reporter.")

    -- Row 1: Quick Launch Buttons
    local bSetup = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    bSetup:SetSize(132, 24)
    bSetup:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -12)
    bSetup:SetText("Setup Wizard")
    bSetup:SetScript("OnClick", function()
        if NS.Onboarding and NS.Onboarding.Show then NS.Onboarding:Show(1) end
    end)

    local bWave = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    bWave:SetSize(136, 24)
    bWave:SetPoint("LEFT", bSetup, "RIGHT", 8, 0)
    bWave:SetText("Questie & Wave")
    bWave:SetScript("OnClick", function()
        if NS.WaveTracker and NS.WaveTracker.ShowUI then NS.WaveTracker:ShowUI() end
    end)

    local bAlts = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    bAlts:SetSize(124, 24)
    bAlts:SetPoint("LEFT", bWave, "RIGHT", 8, 0)
    bAlts:SetText("Manage Alts")
    bAlts:SetScript("OnClick", function()
        if NS.WaveTracker and NS.WaveTracker.OpenManageAltsPopup then NS.WaveTracker:OpenManageAltsPopup() end
    end)

    local bBug = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    bBug:SetSize(118, 24)
    bBug:SetPoint("LEFT", bAlts, "RIGHT", 8, 0)
    bBug:SetText("Bug Report")
    bBug:SetScript("OnClick", function()
        if NS.BugReporter and NS.BugReporter.Show then NS.BugReporter:Show() end
    end)

    -- Section 1: UI, Minimap & Wave Toggles
    local uiHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    uiHeader:SetPoint("TOPLEFT", bSetup, "BOTTOMLEFT", 0, -14)
    uiHeader:SetText("|cffffd100Interface, Minimap & Wave Sync:|r")

    local cbMinimap = CreateOptCheckbox(panel, "Show Minimap Button (Left-Click: Setup | Right-Click: Quick Menu)",
        function() return not (WOWEngineDB and WOWEngineDB.minimapHide) end,
        function(show)
            WOWEngineDB.minimapHide = not show
            if NS.InitMinimapButton then NS:InitMinimapButton() end
        end)
    cbMinimap:SetPoint("TOPLEFT", uiHeader, "BOTTOMLEFT", 0, -6)

    local cbLock = CreateOptCheckbox(panel, "Lock Minimap Button position (prevent accidental dragging)",
        function() return WOWEngineDB and WOWEngineDB.minimapLock end,
        function(v) WOWEngineDB.minimapLock = v end)
    cbLock:SetPoint("TOPLEFT", cbMinimap, "BOTTOMLEFT", 0, -2)

    local cbDock = CreateOptCheckbox(panel, "Dock WOWEngine Wave Heading onto Questie Quest List",
        function()
            local ws = NS:GetWaveState()
            return ws and ws.dockQuestieHeader
        end,
        function(v)
            local ws = NS:GetWaveState()
            ws.dockQuestieHeader = v
            if NS.WaveTracker then
                if v then NS.WaveTracker:InitQuestieDock()
                elseif NS.WaveTracker.questieDock then NS.WaveTracker.questieDock:Hide() end
            end
        end)
    cbDock:SetPoint("TOPLEFT", cbLock, "BOTTOMLEFT", 0, -2)

    local cbPrompt = CreateOptCheckbox(panel, "Auto-prompt Wave Gate alert on level-up / login when cap is reached",
        function()
            local ws = NS:GetWaveState()
            return ws and ws.autoPromptEnabled
        end,
        function(v)
            local ws = NS:GetWaveState()
            ws.autoPromptEnabled = v
        end)
    cbPrompt:SetPoint("TOPLEFT", cbDock, "BOTTOMLEFT", 0, -2)

    -- Section 2: Mail Routing & Companion Safeguards
    local mailHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mailHeader:SetPoint("TOPLEFT", cbPrompt, "BOTTOMLEFT", 0, -12)
    mailHeader:SetText("|cffffd100Mail Routing & Safeguards:|r")

    local cbAlto = CreateOptCheckbox(panel, "Sync alts, professions, equipped bags & gold from Altoholic / DataStore",
        function() return WOWEngineDB and WOWEngineDB.syncAltoholic end,
        function(v)
            WOWEngineDB.syncAltoholic = v
            if v and NS.Roster and NS.Roster.ScanAll then NS.Roster:ScanAll(true) end
        end)
    cbAlto:SetPoint("TOPLEFT", mailHeader, "BOTTOMLEFT", 0, -6)

    local cbKeepOwn = CreateOptCheckbox(panel, "Keep mats on this character if it is assigned to that profession/category",
        function() return WOWEngineDB and WOWEngineDB.keepOwnCategoryMats end,
        function(v) WOWEngineDB.keepOwnCategoryMats = v end)
    cbKeepOwn:SetPoint("TOPLEFT", cbAlto, "BOTTOMLEFT", 0, -2)

    local cbMC = CreateOptCheckbox(panel, "Protect reagents queued in Mastercraft from being mailed",
        function() return WOWEngineDB and WOWEngineDB.protectMastercraftQueue end,
        function(v) WOWEngineDB.protectMastercraftQueue = v end)
    cbMC:SetPoint("TOPLEFT", cbKeepOwn, "BOTTOMLEFT", 0, -2)

    local cbAuc = CreateOptCheckbox(panel, "Protect items flagged by Auctionator holds",
        function() return WOWEngineDB and WOWEngineDB.protectAuctionatorPosted end,
        function(v) WOWEngineDB.protectAuctionatorPosted = v end)
    cbAuc:SetPoint("TOPLEFT", cbMC, "BOTTOMLEFT", 0, -2)

    -- Quick Mode Toggle Buttons
    local bMultiMode = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    bMultiMode:SetSize(215, 22)
    bMultiMode:SetPoint("TOPLEFT", cbAuc, "BOTTOMLEFT", 0, -8)

    local bMcMode = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    bMcMode:SetSize(215, 22)
    bMcMode:SetPoint("LEFT", bMultiMode, "RIGHT", 10, 0)

    local function RefreshModeButtons()
        if WOWEngineDB and WOWEngineDB.multiAltMode == "priority" then
            bMultiMode:SetText("Multi-Alt: Priority (Alt #1)")
        else
            bMultiMode:SetText("Multi-Alt: Round-Robin (Split)")
        end
        if WOWEngineDB and WOWEngineDB.mastercraftPriority == "profit" then
            bMcMode:SetText("Mastercraft: Profitability (AH)")
        else
            bMcMode:SetText("Mastercraft: Leveling Use")
        end
    end

    bMultiMode:SetScript("OnClick", function()
        WOWEngineDB.multiAltMode = (WOWEngineDB.multiAltMode == "roundrobin") and "priority" or "roundrobin"
        RefreshModeButtons()
    end)

    bMcMode:SetScript("OnClick", function()
        WOWEngineDB.mastercraftPriority = (WOWEngineDB.mastercraftPriority == "leveling") and "profit" or "leveling"
        RefreshModeButtons()
    end)

    -- Section 3: Companion Addon Requirements & Live Status
    local reqHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reqHeader:SetPoint("TOPLEFT", bMultiMode, "BOTTOMLEFT", 0, -14)
    reqHeader:SetText("|cffffd100Required Companion Addons for Optimal Functionality:|r")

    local reqBody = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    reqBody:SetPoint("TOPLEFT", reqHeader, "BOTTOMLEFT", 0, -6)
    reqBody:SetWidth(545)
    reqBody:SetJustifyH("LEFT")

    local function RefreshReqStatus()
        local hasAlto, hasMC, hasQst, hasAuc = NS:GetCompanionAddonStatus()
        local alto = hasAlto and "|cff00ff00Connected|r" or "|cffff5555Missing|r"
        local mc = hasMC and "|cff00ff00Connected|r" or "|cffff5555Missing|r"
        local qst = hasQst and "|cff00ff00Connected|r" or "|cffff5555Missing|r"
        local auc = hasAuc and "|cff00ff00Connected|r" or "|cffff5555Missing|r"
        reqBody:SetText(string.format(
            "WOWEngine requires |cffffd100Altoholic (+ DataStore)|r, |cffffd100Mastercraft|r, |cffffd100Questie|r, and |cffffd100Auctionator|r to work optimally.\n" ..
            "Live Status -> Altoholic: %s  |  Mastercraft: %s  |  Questie: %s  |  Auctionator: %s\n" ..
            "  * |cffffd100Without Altoholic:|r Offline alt bag upgrade routing, played-time priority & offline roster/gold sync are limited.\n" ..
            "  * |cffffd100Without Mastercraft:|r Phase 3 leveling/profitability guidance & queued reagent mail protection are disabled.\n" ..
            "  * |cffffd100Without Questie:|r Docked Wave Heading falls back to Blizzard's default tracker or standalone HUD.\n" ..
            "  * |cffffd100Without Auctionator:|r Auction hold protection (keeping AH-flagged items from being mailed) & live AH price/profit checks are disabled.",
            alto, mc, qst, auc
        ))
    end

    panel:SetScript("OnShow", function()
        cbMinimap:Refresh()
        cbLock:Refresh()
        cbDock:Refresh()
        cbPrompt:Refresh()
        cbAlto:Refresh()
        cbKeepOwn:Refresh()
        cbMC:Refresh()
        cbAuc:Refresh()
        RefreshModeButtons()
        RefreshReqStatus()
    end)

    -- Register with modern Settings API (NEVER overwrite category.ID; keep Blizzard's numeric ID for OpenToCategory!)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name, panel.name)
        if ok and category then
            pcall(Settings.RegisterAddOnCategory, category)
            SP.category = category
            if category.GetID then
                SP.categoryID = category:GetID()
            elseif category.ID then
                SP.categoryID = category.ID
            end
        end
    elseif InterfaceOptions_AddCategory then
        pcall(InterfaceOptions_AddCategory, panel)
    end

    SP.panel = panel
end

local spInit = CreateFrame("Frame")
spInit:RegisterEvent("ADDON_LOADED")
spInit:RegisterEvent("PLAYER_LOGIN")
spInit:SetScript("OnEvent", function(self, event, arg1)
    if (event == "ADDON_LOADED" and arg1 == addonName) or event == "PLAYER_LOGIN" then
        pcall(function() SP:Init() end)
    end
end)
