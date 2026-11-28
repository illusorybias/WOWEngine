local addonName, NS = ...
NS.PlanBuilder = {}
local PB = NS.PlanBuilder
local C = NS.Compat

PB.frame = nil
PB.secondaryFrame = nil

PB.SPEC_FOCUS_OPTIONS = {
    { id = "PvE",  label = "PvE (Leveling / Solo)", desc = "Prioritizes leveling & solo efficiency builds and hit/crit milestones." },
    { id = "Raid", label = "Raid (Endgame PvE)",    desc = "Prioritizes raid-capped DPS, Tank, and Healer talent builds & stat caps." },
    { id = "PvP",  label = "PvP (Arena / BGs)",     desc = "Prioritizes PvP survivability, burst builds, and PvP hit targets (5%/3%)." },
    { id = "Meta", label = "Meta Website Spec",     desc = "Follows your chosen top community meta spec guide source." },
}

PB.SECONDARY_OPTIONS = {
    { id = "PvE",  label = "PvE (Leveling / Solo)" },
    { id = "Raid", label = "Raid (Endgame PvE)" },
    { id = "PvP",  label = "PvP (Arena / BGs)" },
    { id = "Meta", label = "Meta Website Spec" },
    { id = "none", label = "Not Using Secondary Spec" },
    { id = "ask",  label = "Ask Me When I Unlock Secondary Spec" },
}

PB.META_SOURCES = {
    "Wowhead",
    "Icy Veins",
    "Archon.gg",
    "Murlok.io",
    "Mobalytics",
}

local function ApplyBlueGoldBackdrop(f, alpha)
    if not f then return end
    if f.SetBackdrop then
        local ok = pcall(function()
            f:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 14,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            f:SetBackdropColor(0.04, 0.09, 0.19, alpha or 0.97)
            f:SetBackdropBorderColor(0.95, 0.78, 0.18, 1.0)
        end)
        if ok then return end
    end
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    if bg.SetColorTexture then
        bg:SetColorTexture(0.04, 0.09, 0.19, alpha or 0.97)
    else
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        bg:SetVertexColor(0.04, 0.09, 0.19, alpha or 0.97)
    end
end

-- Cross-client nil-safe helpers for Dual Spec / Spec Groups (WoW Forever 16001, Classic, Retail)
function PB:GetNumSpecGroupsSafe()
    if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecGroups then
        local ok, n = pcall(C_SpecializationInfo.GetNumSpecGroups)
        if ok and type(n) == "number" and n > 0 then return n end
    end
    if GetNumSpecGroups then
        local ok, n = pcall(GetNumSpecGroups)
        if ok and type(n) == "number" and n > 0 then return n end
    end
    if GetNumTalentGroups then
        local ok, n = pcall(GetNumTalentGroups)
        if ok and type(n) == "number" and n > 0 then return n end
    end
    return 1
end

function PB:GetActiveSpecGroupSafe()
    if C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup then
        local ok, g = pcall(C_SpecializationInfo.GetActiveSpecGroup)
        if ok and type(g) == "number" and g >= 1 then return g end
    end
    if GetActiveSpecGroup then
        local ok, g = pcall(GetActiveSpecGroup)
        if ok and type(g) == "number" and g >= 1 then return g end
    end
    if GetActiveTalentGroup then
        local ok, g = pcall(GetActiveTalentGroup)
        if ok and type(g) == "number" and g >= 1 then return g end
    end
    return 1
end

function PB:GetPlan()
    if NS and NS.EnsureDB then NS:EnsureDB() end
    WOWEngineDB = WOWEngineDB or {}
    if type(WOWEngineDB.userPlan) ~= "table" then
        WOWEngineDB.userPlan = {
            completed = false,
            specFocus = "PvE",
            metaSource = "Wowhead",
            secondaryMode = "ask",
            secondaryMetaSource = "Wowhead",
            promptOnDualSpecUnlock = true,
            secondaryConfigured = false,
            useBankAlt = true,
            lastKnownSpecGroupsByChar = {},
            dualSpecPromptedByChar = {},
        }
    end
    local p = WOWEngineDB.userPlan
    if not p.specFocus then p.specFocus = "PvE" end
    if not p.metaSource then p.metaSource = "Wowhead" end
    if not p.secondaryMode then p.secondaryMode = "ask" end
    if not p.secondaryMetaSource then p.secondaryMetaSource = "Wowhead" end
    if p.promptOnDualSpecUnlock == nil then p.promptOnDualSpecUnlock = (p.secondaryMode == "ask") end
    if p.secondaryConfigured == nil then p.secondaryConfigured = (p.secondaryMode ~= "ask") end
    if p.useBankAlt == nil then p.useBankAlt = true end
    if type(p.lastKnownSpecGroupsByChar) ~= "table" then p.lastKnownSpecGroupsByChar = {} end
    if type(p.dualSpecPromptedByChar) ~= "table" then p.dualSpecPromptedByChar = {} end
    return p
end

function PB:GetPlanForGroup(groupNum)
    local p = PB:GetPlan()
    local g = groupNum or PB:GetActiveSpecGroupSafe()
    if g == 2 then
        if p.secondaryMode == "PvE" or p.secondaryMode == "Raid" or p.secondaryMode == "PvP" or p.secondaryMode == "Meta" then
            return p.secondaryMode, p.secondaryMetaSource or "Wowhead", "Secondary"
        end
        return p.specFocus, p.metaSource or "Wowhead", "Secondary (Fallback)"
    end
    return p.specFocus, p.metaSource or "Wowhead", "Primary"
end

function PB:GetPlanDisplayLabel(groupNum)
    local focus, metaSrc, grpTag = PB:GetPlanForGroup(groupNum)
    local core = (focus == "Meta") and ("Meta Spec (" .. tostring(metaSrc or "Wowhead") .. ")") or tostring(focus or "PvE")
    local numGroups = PB:GetNumSpecGroupsSafe()
    if numGroups >= 2 then
        return grpTag .. ": " .. core
    end
    return core
end

function PB:GetSecondaryDisplayLabel()
    local p = PB:GetPlan()
    if p.secondaryMode == "none" then return "Not Using Secondary Spec" end
    if p.secondaryMode == "ask" then return "Ask on Dual Spec Unlock" end
    if p.secondaryMode == "Meta" then return "Meta Spec (" .. tostring(p.secondaryMetaSource or "Wowhead") .. ")" end
    return tostring(p.secondaryMode or "Ask on Dual Spec Unlock")
end

function PB:ShouldUseBankAlt()
    local p = PB:GetPlan()
    return p.useBankAlt ~= false
end

-- Automatically sync Talent Advisor (Primary Group 1 & Secondary Group 2), Stat Caps, and Mail Router
function PB:ApplyPlan(silent)
    local p = PB:GetPlan()
    p.promptOnDualSpecUnlock = (p.secondaryMode == "ask")
    p.secondaryConfigured = (p.secondaryMode ~= "ask")

    -- 1. Sync Primary Spec (group 1) AND Secondary Spec (group 2) into Talent Advisor immediately
    if NS.TalentAdvisor and NS.TalentAdvisor.ApplyPlanFocus then
        pcall(function() NS.TalentAdvisor:ApplyPlanFocus(p.specFocus, p.metaSource, 1) end)
        if p.secondaryMode == "PvE" or p.secondaryMode == "Raid" or p.secondaryMode == "PvP" or p.secondaryMode == "Meta" then
            pcall(function() NS.TalentAdvisor:ApplyPlanFocus(p.secondaryMode, p.secondaryMetaSource, 2) end)
        end
    end

    -- 2. Sync Stat Caps window display
    if NS.StatCapsUI and NS.StatCapsUI.Refresh then
        pcall(function() NS.StatCapsUI:Refresh() end)
    end

    if not silent then
        local routeTxt = (p.useBankAlt == false)
            and "|cff00ff00Direct Between Crafters (No Bank Alt)|r"
            or  "|cff00ff00Dedicated Bank Alt Enabled|r"
        NS:Print(string.format("|cff00aeffPlan Applied:|r Primary = |cffffd100%s|r | Secondary = |cffffd100%s|r | Mail = %s",
            PB:GetPlanDisplayLabel(1), PB:GetSecondaryDisplayLabel(), routeTxt))
    end

    if NS.Onboarding and NS.Onboarding.RefreshIfShown then
        pcall(function() NS.Onboarding:RefreshIfShown() end)
    end
    if NS.WaveTracker and NS.WaveTracker.RefreshUI then
        pcall(function() NS.WaveTracker:RefreshUI() end)
    end
end

local function StyleSelectButton(btn, isSelected, label)
    if not btn then return end
    if isSelected then
        btn:SetText("|cff00ff00[X]|r " .. label)
    else
        btn:SetText("|cffaaaaaa[ ]|r " .. label)
    end
end

function PB:Refresh()
    local f = PB.frame
    if not f then return end
    local p = PB:GetPlan()

    -- Step A: Primary Spec
    local activeDesc = ""
    for _, item in ipairs(f.focusBtns) do
        local isSel = (p.specFocus == item.data.id)
        StyleSelectButton(item.btn, isSel, item.data.label)
        if isSel then activeDesc = item.data.desc end
    end
    f.focusDesc:SetText("|cff00aeffPrimary Focus:|r " .. activeDesc)

    if p.specFocus == "Meta" then
        f.metaBox:Show()
        for _, item in ipairs(f.metaBtns) do
            StyleSelectButton(item.btn, p.metaSource == item.source, item.source)
        end
    else
        f.metaBox:Hide()
    end

    -- Step B: Secondary Spec
    for _, item in ipairs(f.secBtns) do
        StyleSelectButton(item.btn, p.secondaryMode == item.data.id, item.data.label)
    end

    if p.secondaryMode == "Meta" then
        f.secMetaBox:Show()
        for _, item in ipairs(f.secMetaBtns) do
            StyleSelectButton(item.btn, p.secondaryMetaSource == item.source, item.source)
        end
    else
        f.secMetaBox:Hide()
    end

    -- Step C: Bank Alt
    StyleSelectButton(f.bankYesBtn, p.useBankAlt == true, "Yes — Use a Dedicated Bank Alt")
    StyleSelectButton(f.bankNoBtn,  p.useBankAlt == false, "No — No Bank Alt (Route Directly Between Crafters)")

    local bankSummary = (p.useBankAlt == false)
        and "|cff00ff00Direct Crafter-to-Crafter|r"
        or  "|cffffd100Dedicated Bank Alt|r"

    f.summaryTxt:SetText(string.format(
        "|cffffd100Active Plan:|r Primary = |cff00ff00%s|r  |  Secondary = |cff00aeff%s|r  |  Mail = %s",
        (p.specFocus == "Meta") and ("Meta (" .. p.metaSource .. ")") or p.specFocus,
        PB:GetSecondaryDisplayLabel(),
        bankSummary
    ))
end

function PB:Show()
    PB:GetPlan()
    if not PB.frame then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local f = CreateFrame("Frame", "WOWEnginePlanBuilderFrame", UIParent, template)
        f:SetSize(560, 595)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 15)
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(145)
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        ApplyBlueGoldBackdrop(f, 0.98)

        if UISpecialFrames then
            table.insert(UISpecialFrames, "WOWEnginePlanBuilderFrame")
        end

        local headerBg = f:CreateTexture(nil, "ARTWORK")
        headerBg:SetPoint("TOPLEFT", 4, -4)
        headerBg:SetPoint("TOPRIGHT", -4, -4)
        headerBg:SetHeight(44)
        if headerBg.SetColorTexture then
            headerBg:SetColorTexture(0.06, 0.16, 0.34, 0.96)
        else
            headerBg:SetTexture("Interface\\Buttons\\WHITE8x8")
            headerBg:SetVertexColor(0.06, 0.16, 0.34, 0.96)
        end

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -10)
        title:SetText("|cff00aeffWOWEngine|r |cffffd100Playstyle & Roster Plan Builder|r")

        local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
        subtitle:SetText("Configure Primary Spec, Secondary Spec & Mail Strategy (|cffffd100/he plan|r | |cffffd100/he plan secondary|r).")

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        -- ==========================================
        -- STEP A: PRIMARY SPEC FOCUS (GROUP 1)
        -- ==========================================
        local stepALbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        stepALbl:SetPoint("TOPLEFT", 16, -56)
        stepALbl:SetText("|cffffd100Step A — Primary Spec Focus (Spec Group 1):|r")

        f.focusBtns = {}
        for i, opt in ipairs(PB.SPEC_FOCUS_OPTIONS) do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            b:SetSize(258, 22)
            b:SetPoint("TOPLEFT", 16 + col * 268, -76 - row * 26)
            b:SetScript("OnClick", function()
                local plan = PB:GetPlan()
                plan.specFocus = opt.id
                if NS.TalentAdvisor and NS.TalentAdvisor.ApplyPlanFocus then
                    pcall(function() NS.TalentAdvisor:ApplyPlanFocus(plan.specFocus, plan.metaSource, 1) end)
                end
                PB:Refresh()
            end)
            f.focusBtns[i] = { btn = b, data = opt }
        end

        local focusDesc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        focusDesc:SetPoint("TOPLEFT", 16, -130)
        focusDesc:SetWidth(526)
        focusDesc:SetJustifyH("LEFT")
        f.focusDesc = focusDesc

        local metaBox = CreateFrame("Frame", nil, f, template)
        metaBox:SetPoint("TOPLEFT", 16, -148)
        metaBox:SetPoint("TOPRIGHT", -16, -148)
        metaBox:SetHeight(52)
        if metaBox.SetBackdrop then
            pcall(function()
                metaBox:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 },
                })
                metaBox:SetBackdropColor(0.05, 0.13, 0.27, 0.92)
                metaBox:SetBackdropBorderColor(0.95, 0.78, 0.18, 0.75)
            end)
        end

        local metaLbl = metaBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        metaLbl:SetPoint("TOPLEFT", 8, -5)
        metaLbl:SetText("|cffffd100Primary Meta Website Spec Source (Top 5):|r")

        f.metaBtns = {}
        for idx, src in ipairs(PB.META_SOURCES) do
            local mb = CreateFrame("Button", nil, metaBox, "UIPanelButtonTemplate")
            mb:SetSize(98, 22)
            mb:SetPoint("TOPLEFT", 8 + (idx - 1) * 102, -23)
            mb:SetScript("OnClick", function()
                local plan = PB:GetPlan()
                plan.metaSource = src
                if NS.TalentAdvisor and NS.TalentAdvisor.ApplyPlanFocus then
                    pcall(function() NS.TalentAdvisor:ApplyPlanFocus(plan.specFocus, plan.metaSource, 1) end)
                end
                PB:Refresh()
            end)
            f.metaBtns[idx] = { btn = mb, source = src }
        end
        f.metaBox = metaBox

        -- ==========================================
        -- STEP B: SECONDARY SPEC FOCUS (GROUP 2)
        -- ==========================================
        local stepBLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        stepBLbl:SetPoint("TOPLEFT", 16, -210)
        stepBLbl:SetText("|cffffd100Step B — Secondary Spec Focus (Dual Spec / Group 2):|r")

        f.secBtns = {}
        for i, opt in ipairs(PB.SECONDARY_OPTIONS) do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            b:SetSize(258, 22)
            b:SetPoint("TOPLEFT", 16 + col * 268, -230 - row * 26)
            b:SetScript("OnClick", function()
                local plan = PB:GetPlan()
                plan.secondaryMode = opt.id
                plan.promptOnDualSpecUnlock = (opt.id == "ask")
                plan.secondaryConfigured = (opt.id ~= "ask")
                if (opt.id == "PvE" or opt.id == "Raid" or opt.id == "PvP" or opt.id == "Meta")
                    and NS.TalentAdvisor and NS.TalentAdvisor.ApplyPlanFocus then
                    pcall(function() NS.TalentAdvisor:ApplyPlanFocus(opt.id, plan.secondaryMetaSource, 2) end)
                end
                PB:Refresh()
            end)
            f.secBtns[i] = { btn = b, data = opt }
        end

        local secMetaBox = CreateFrame("Frame", nil, f, template)
        secMetaBox:SetPoint("TOPLEFT", 16, -312)
        secMetaBox:SetPoint("TOPRIGHT", -16, -312)
        secMetaBox:SetHeight(52)
        if secMetaBox.SetBackdrop then
            pcall(function()
                secMetaBox:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 },
                })
                secMetaBox:SetBackdropColor(0.05, 0.13, 0.27, 0.92)
                secMetaBox:SetBackdropBorderColor(0.95, 0.78, 0.18, 0.75)
            end)
        end

        local secMetaLbl = secMetaBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        secMetaLbl:SetPoint("TOPLEFT", 8, -5)
        secMetaLbl:SetText("|cffffd100Secondary Meta Website Spec Source (Top 5):|r")

        f.secMetaBtns = {}
        for idx, src in ipairs(PB.META_SOURCES) do
            local mb = CreateFrame("Button", nil, secMetaBox, "UIPanelButtonTemplate")
            mb:SetSize(98, 22)
            mb:SetPoint("TOPLEFT", 8 + (idx - 1) * 102, -23)
            mb:SetScript("OnClick", function()
                local plan = PB:GetPlan()
                plan.secondaryMetaSource = src
                if NS.TalentAdvisor and NS.TalentAdvisor.ApplyPlanFocus then
                    pcall(function() NS.TalentAdvisor:ApplyPlanFocus(plan.secondaryMode, plan.secondaryMetaSource, 2) end)
                end
                PB:Refresh()
            end)
            f.secMetaBtns[idx] = { btn = mb, source = src }
        end
        f.secMetaBox = secMetaBox

        -- ==========================================
        -- STEP C: BANK ALT CHOICE
        -- ==========================================
        local stepCLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        stepCLbl:SetPoint("TOPLEFT", 16, -374)
        stepCLbl:SetText("|cffffd100Step C — Bank Alt Choice (Mail & Shipping Strategy):|r")

        local bankYesBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        bankYesBtn:SetSize(526, 22)
        bankYesBtn:SetPoint("TOPLEFT", 16, -394)
        bankYesBtn:SetScript("OnClick", function()
            local plan = PB:GetPlan()
            plan.useBankAlt = true
            PB:Refresh()
        end)
        f.bankYesBtn = bankYesBtn

        local bankNoBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        bankNoBtn:SetSize(526, 22)
        bankNoBtn:SetPoint("TOPLEFT", 16, -420)
        bankNoBtn:SetScript("OnClick", function()
            local plan = PB:GetPlan()
            plan.useBankAlt = false
            PB:Refresh()
        end)
        f.bankNoBtn = bankNoBtn

        -- Live Plan Summary Box
        local summaryBox = CreateFrame("Frame", nil, f, template)
        summaryBox:SetPoint("TOPLEFT", 16, -452)
        summaryBox:SetPoint("TOPRIGHT", -16, -452)
        summaryBox:SetHeight(42)
        if summaryBox.SetBackdrop then
            pcall(function()
                summaryBox:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 },
                })
                summaryBox:SetBackdropColor(0.03, 0.08, 0.16, 0.92)
                summaryBox:SetBackdropBorderColor(0.35, 0.65, 0.95, 0.65)
            end)
        end

        local summaryTxt = summaryBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        summaryTxt:SetPoint("TOPLEFT", 10, -8)
        summaryTxt:SetPoint("RIGHT", summaryBox, "RIGHT", -10, 0)
        summaryTxt:SetJustifyH("LEFT")
        f.summaryTxt = summaryTxt

        -- Footer Buttons
        local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        saveBtn:SetSize(134, 26)
        saveBtn:SetPoint("BOTTOMLEFT", 16, 14)
        saveBtn:SetText("Save & Apply Plan")
        saveBtn:SetScript("OnClick", function()
            local plan = PB:GetPlan()
            plan.completed = true
            PB:ApplyPlan()
            f:Hide()
        end)

        local treeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        treeBtn:SetSize(118, 26)
        treeBtn:SetPoint("LEFT", saveBtn, "RIGHT", 6, 0)
        treeBtn:SetText("View Full Tree")
        treeBtn:SetScript("OnClick", function()
            PB:ApplyPlan(true)
            if NS.TalentAdvisor and NS.TalentAdvisor.OpenFullTreePreview then
                pcall(function() NS.TalentAdvisor:OpenFullTreePreview() end)
            end
        end)

        local setupBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        setupBtn:SetSize(136, 26)
        setupBtn:SetPoint("LEFT", treeBtn, "RIGHT", 6, 0)
        setupBtn:SetText("Open Setup Wizard")
        setupBtn:SetScript("OnClick", function()
            local plan = PB:GetPlan()
            plan.completed = true
            PB:ApplyPlan()
            f:Hide()
            if NS.Onboarding and NS.Onboarding.Show then
                pcall(function() NS.Onboarding:Show(1) end)
            end
        end)

        local closeFoot = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeFoot:SetSize(74, 26)
        closeFoot:SetPoint("BOTTOMRIGHT", -16, 14)
        closeFoot:SetText("Close")
        closeFoot:SetScript("OnClick", function() f:Hide() end)

        PB.frame = f
    end

    PB:Refresh()
    PB.frame:Show()
    PB.frame:Raise()
end

-- ============================================================
-- STREAMLINED SECONDARY-SPEC-ONLY WIZARD (/he plan secondary)
-- ============================================================

function PB:RefreshSecondaryWizard()
    local sf = PB.secondaryFrame
    if not sf then return end
    local p = PB:GetPlan()

    for _, item in ipairs(sf.secBtns) do
        StyleSelectButton(item.btn, p.secondaryMode == item.data.id, item.data.label)
    end

    if p.secondaryMode == "Meta" then
        sf.secMetaBox:Show()
        for _, item in ipairs(sf.secMetaBtns) do
            StyleSelectButton(item.btn, p.secondaryMetaSource == item.source, item.source)
        end
    else
        sf.secMetaBox:Hide()
    end

    sf.statusTxt:SetText("|cffffd100Selected Secondary Spec:|r |cff00ff00" .. PB:GetSecondaryDisplayLabel() .. "|r")
end

function PB:ShowSecondaryWizard()
    PB:GetPlan()
    if not PB.secondaryFrame then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local sf = CreateFrame("Frame", "WOWEngineSecondarySpecFrame", UIParent, template)
        sf:SetSize(540, 315)
        sf:SetPoint("CENTER", UIParent, "CENTER", 0, 35)
        sf:SetFrameStrata("DIALOG")
        sf:SetFrameLevel(155)
        sf:SetClampedToScreen(true)
        sf:SetMovable(true)
        sf:EnableMouse(true)
        sf:RegisterForDrag("LeftButton")
        sf:SetScript("OnDragStart", function(self) self:StartMoving() end)
        sf:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        ApplyBlueGoldBackdrop(sf, 0.98)

        if UISpecialFrames then
            table.insert(UISpecialFrames, "WOWEngineSecondarySpecFrame")
        end

        local headerBg = sf:CreateTexture(nil, "ARTWORK")
        headerBg:SetPoint("TOPLEFT", 4, -4)
        headerBg:SetPoint("TOPRIGHT", -4, -4)
        headerBg:SetHeight(44)
        if headerBg.SetColorTexture then
            headerBg:SetColorTexture(0.06, 0.16, 0.34, 0.96)
        else
            headerBg:SetTexture("Interface\\Buttons\\WHITE8x8")
            headerBg:SetVertexColor(0.06, 0.16, 0.34, 0.96)
        end

        local title = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -10)
        title:SetText("|cff00aeffWOWEngine|r |cffffd100Secondary Spec Setup Wizard|r")

        local sub = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
        sub:SetText("Dual Spec detected! Choose your Secondary Spec (Group 2) focus below:")

        local closeBtn = CreateFrame("Button", nil, sf, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() sf:Hide() end)

        sf.secBtns = {}
        for i, opt in ipairs(PB.SECONDARY_OPTIONS) do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local b = CreateFrame("Button", nil, sf, "UIPanelButtonTemplate")
            b:SetSize(250, 24)
            b:SetPoint("TOPLEFT", 16 + col * 258, -60 - row * 28)
            b:SetScript("OnClick", function()
                local plan = PB:GetPlan()
                plan.secondaryMode = opt.id
                plan.promptOnDualSpecUnlock = (opt.id == "ask")
                plan.secondaryConfigured = (opt.id ~= "ask")
                if (opt.id == "PvE" or opt.id == "Raid" or opt.id == "PvP" or opt.id == "Meta")
                    and NS.TalentAdvisor and NS.TalentAdvisor.ApplyPlanFocus then
                    pcall(function() NS.TalentAdvisor:ApplyPlanFocus(opt.id, plan.secondaryMetaSource, 2) end)
                end
                PB:RefreshSecondaryWizard()
            end)
            sf.secBtns[i] = { btn = b, data = opt }
        end

        local secMetaBox = CreateFrame("Frame", nil, sf, template)
        secMetaBox:SetPoint("TOPLEFT", 16, -150)
        secMetaBox:SetPoint("TOPRIGHT", -16, -150)
        secMetaBox:SetHeight(56)
        if secMetaBox.SetBackdrop then
            pcall(function()
                secMetaBox:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 },
                })
                secMetaBox:SetBackdropColor(0.05, 0.13, 0.27, 0.92)
                secMetaBox:SetBackdropBorderColor(0.95, 0.78, 0.18, 0.75)
            end)
        end

        local secMetaLbl = secMetaBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        secMetaLbl:SetPoint("TOPLEFT", 8, -6)
        secMetaLbl:SetText("|cffffd100Select Meta Website Spec Source (Top 5):|r")

        sf.secMetaBtns = {}
        for idx, src in ipairs(PB.META_SOURCES) do
            local mb = CreateFrame("Button", nil, secMetaBox, "UIPanelButtonTemplate")
            mb:SetSize(94, 22)
            mb:SetPoint("TOPLEFT", 8 + (idx - 1) * 98, -26)
            mb:SetScript("OnClick", function()
                local plan = PB:GetPlan()
                plan.secondaryMetaSource = src
                if NS.TalentAdvisor and NS.TalentAdvisor.ApplyPlanFocus then
                    pcall(function() NS.TalentAdvisor:ApplyPlanFocus(plan.secondaryMode, plan.secondaryMetaSource, 2) end)
                end
                PB:RefreshSecondaryWizard()
            end)
            sf.secMetaBtns[idx] = { btn = mb, source = src }
        end
        sf.secMetaBox = secMetaBox

        local statusTxt = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statusTxt:SetPoint("TOPLEFT", 16, -218)
        statusTxt:SetWidth(506)
        statusTxt:SetJustifyH("LEFT")
        sf.statusTxt = statusTxt

        local saveBtn = CreateFrame("Button", nil, sf, "UIPanelButtonTemplate")
        saveBtn:SetSize(164, 26)
        saveBtn:SetPoint("BOTTOMLEFT", 16, 14)
        saveBtn:SetText("Save Secondary Spec")
        saveBtn:SetScript("OnClick", function()
            local plan = PB:GetPlan()
            local cKey = C.CanonicalCharKey(C.GetPlayerName() or "Player") or "player"
            plan.dualSpecPromptedByChar[cKey] = true
            PB:ApplyPlan()
            sf:Hide()
        end)

        local treeBtn = CreateFrame("Button", nil, sf, "UIPanelButtonTemplate")
        treeBtn:SetSize(124, 26)
        treeBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
        treeBtn:SetText("View Full Tree")
        treeBtn:SetScript("OnClick", function()
            PB:ApplyPlan(true)
            if NS.TalentAdvisor and NS.TalentAdvisor.OpenFullTreePreview then
                pcall(function() NS.TalentAdvisor:OpenFullTreePreview(nil, 2) end)
            end
        end)

        local closeFoot = CreateFrame("Button", nil, sf, "UIPanelButtonTemplate")
        closeFoot:SetSize(80, 26)
        closeFoot:SetPoint("BOTTOMRIGHT", -16, 14)
        closeFoot:SetText("Close")
        closeFoot:SetScript("OnClick", function() sf:Hide() end)

        PB.secondaryFrame = sf
    end

    PB:RefreshSecondaryWizard()
    PB.secondaryFrame:Show()
    PB.secondaryFrame:Raise()
end

function PB:Toggle()
    if PB.frame and PB.frame:IsShown() then
        PB.frame:Hide()
    else
        PB:Show()
    end
end

-- Monitor Dual Spec unlock transition (1 -> 2 spec groups) across WoW Forever 16001, Classic, and Retail
function PB:CheckDualSpecUnlock()
    local p = PB:GetPlan()
    local cKey = C.CanonicalCharKey(C.GetPlayerName() or "Player") or "player"
    local numGroups = PB:GetNumSpecGroupsSafe()
    local prevGroups = tonumber(p.lastKnownSpecGroupsByChar[cKey])

    if prevGroups == nil then
        p.lastKnownSpecGroupsByChar[cKey] = numGroups
        return
    end

    if prevGroups < 2 and numGroups >= 2 then
        p.lastKnownSpecGroupsByChar[cKey] = numGroups
        if p.promptOnDualSpecUnlock and (not p.secondaryConfigured) and (not p.dualSpecPromptedByChar[cKey]) then
            p.dualSpecPromptedByChar[cKey] = true
            NS:Print("|cff00ff00Dual Spec unlocked!|r Opening the |cffffd100Secondary Spec Setup Wizard|r...")
            PB:ShowSecondaryWizard()
        end
    else
        p.lastKnownSpecGroupsByChar[cKey] = numGroups
    end
end

local pbEvents = CreateFrame("Frame")
pcall(pbEvents.RegisterEvent, pbEvents, "PLAYER_ENTERING_WORLD")
pcall(pbEvents.RegisterEvent, pbEvents, "PLAYER_TALENT_UPDATE")
pcall(pbEvents.RegisterEvent, pbEvents, "ACTIVE_TALENT_GROUP_CHANGED")
pbEvents:SetScript("OnEvent", function(_, event)
    pcall(function()
        PB:CheckDualSpecUnlock()
        if event == "ACTIVE_TALENT_GROUP_CHANGED" then
            if NS.TalentAdvisor and NS.TalentAdvisor.UpdateTalentHighlight then
                NS.TalentAdvisor:UpdateTalentHighlight()
            end
            if NS.StatCapsUI and NS.StatCapsUI.Refresh then
                NS.StatCapsUI:Refresh()
            end
        end
    end)
end)
