local addonName, NS = ...
NS.PlanBuilder = {}
local PB = NS.PlanBuilder
local C = NS.Compat

PB.frame = nil

PB.SPEC_FOCUS_OPTIONS = {
    { id = "PvE",  label = "PvE (Leveling / Solo)", desc = "Prioritizes leveling & solo efficiency builds and hit/crit milestones." },
    { id = "Raid", label = "Raid (Endgame PvE)",    desc = "Prioritizes raid-capped DPS, Tank, and Healer talent builds & stat caps." },
    { id = "PvP",  label = "PvP (Arena / BGs)",     desc = "Prioritizes PvP survivability, burst builds, and PvP hit targets (5%/3%)." },
    { id = "Meta", label = "Meta Website Spec",     desc = "Follows your chosen top community meta spec guide source." },
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

function PB:GetPlan()
    if NS and NS.EnsureDB then NS:EnsureDB() end
    WOWEngineDB = WOWEngineDB or {}
    if type(WOWEngineDB.userPlan) ~= "table" then
        WOWEngineDB.userPlan = {
            completed = false,
            specFocus = "PvE",
            metaSource = "Wowhead",
            useBankAlt = true,
        }
    end
    local p = WOWEngineDB.userPlan
    if not p.specFocus then p.specFocus = "PvE" end
    if not p.metaSource then p.metaSource = "Wowhead" end
    if p.useBankAlt == nil then p.useBankAlt = true end
    return p
end

function PB:GetPlanDisplayLabel()
    local p = PB:GetPlan()
    if p.specFocus == "Meta" then
        return "Meta Spec (" .. tostring(p.metaSource or "Wowhead") .. ")"
    end
    return tostring(p.specFocus or "PvE")
end

function PB:ShouldUseBankAlt()
    local p = PB:GetPlan()
    return p.useBankAlt ~= false
end

-- Automatically sync Talent Advisor, Stat Caps, and Mail Router to the saved Plan Builder choices
function PB:ApplyPlan()
    local p = PB:GetPlan()

    -- 1. Sync Talent Advisor default build to match Spec Focus (PvP / PvE / Raid / Meta)
    if NS.TalentAdvisor and NS.TalentAdvisor.ApplyPlanFocus then
        pcall(function() NS.TalentAdvisor:ApplyPlanFocus(p.specFocus, p.metaSource) end)
    end

    -- 2. Sync Stat Caps window display
    if NS.StatCapsUI and NS.StatCapsUI.Refresh then
        pcall(function() NS.StatCapsUI:Refresh() end)
    end

    -- 3. Sync Mail Router BankAlt setting (if user chose No Bank Alt, clear BankAlt fallback automatically)
    if p.useBankAlt == false then
        NS:Print("|cff00aeffPlan Applied:|r Spec Focus = |cffffd100" .. PB:GetPlanDisplayLabel() .. "|r | Routing = |cff00ff00Direct Between Crafters (No Bank Alt)|r.")
    else
        NS:Print("|cff00aeffPlan Applied:|r Spec Focus = |cffffd100" .. PB:GetPlanDisplayLabel() .. "|r | Routing = |cff00ff00Dedicated Bank Alt Enabled|r.")
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

    local activeDesc = ""
    for _, item in ipairs(f.focusBtns) do
        local isSel = (p.specFocus == item.data.id)
        StyleSelectButton(item.btn, isSel, item.data.label)
        if isSel then activeDesc = item.data.desc end
    end
    f.focusDesc:SetText("|cff00aeffFocus:|r " .. activeDesc)

    -- Show Meta Website Spec Source selector ONLY when "Meta Website Spec" is selected
    if p.specFocus == "Meta" then
        f.metaBox:Show()
        for _, item in ipairs(f.metaBtns) do
            local isSel = (p.metaSource == item.source)
            StyleSelectButton(item.btn, isSel, item.source)
        end
    else
        f.metaBox:Hide()
    end

    StyleSelectButton(f.bankYesBtn, p.useBankAlt == true, "Yes — Use a Dedicated Bank Alt")
    StyleSelectButton(f.bankNoBtn,  p.useBankAlt == false, "No — No Bank Alt (Route Directly Between Crafters)")

    local bankSummary = (p.useBankAlt == false)
        and "|cff00ff00Direct Crafter-to-Crafter|r (BankAlt fallback disabled)"
        or  "|cffffd100Dedicated Bank Alt|r (overflow BoEs, surplus bags & vault items route to BankAlt)"

    f.summaryTxt:SetText(string.format(
        "|cffffd100Active Plan Summary:|r\n  Spec Focus: |cff00ff00%s|r  ->  Syncs Talent Advisor & Stat Caps\n  Mail Strategy: %s",
        PB:GetPlanDisplayLabel(), bankSummary
    ))
end

function PB:Show()
    local p = PB:GetPlan()
    if not PB.frame then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local f = CreateFrame("Frame", "WOWEnginePlanBuilderFrame", UIParent, template)
        f:SetSize(535, 420)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 25)
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

        -- Header Banner
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
        subtitle:SetText("Configure your leveling focus and mail strategy (re-open anytime via |cffffd100/he plan|r).")

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        -- ==========================================
        -- STEP A: PRIMARY SPEC FOCUS
        -- ==========================================
        local stepALbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        stepALbl:SetPoint("TOPLEFT", 16, -58)
        stepALbl:SetText("|cffffd100Step A — Primary Spec Focus:|r")

        f.focusBtns = {}
        for i, opt in ipairs(PB.SPEC_FOCUS_OPTIONS) do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            b:SetSize(246, 24)
            b:SetPoint("TOPLEFT", 16 + col * 255, -80 - row * 28)
            b:SetScript("OnClick", function()
                local plan = PB:GetPlan()
                plan.specFocus = opt.id
                PB:Refresh()
            end)
            f.focusBtns[i] = { btn = b, data = opt }
        end

        local focusDesc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        focusDesc:SetPoint("TOPLEFT", 16, -138)
        focusDesc:SetWidth(500)
        focusDesc:SetJustifyH("LEFT")
        f.focusDesc = focusDesc

        -- Conditional Meta Website Spec Source Box (Top 5 sources)
        local metaBox = CreateFrame("Frame", nil, f, template)
        metaBox:SetPoint("TOPLEFT", 16, -156)
        metaBox:SetPoint("TOPRIGHT", -16, -156)
        metaBox:SetHeight(56)
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
        metaLbl:SetPoint("TOPLEFT", 8, -6)
        metaLbl:SetText("|cffffd100Select Meta Website Spec Source (Top 5):|r")

        f.metaBtns = {}
        for idx, src in ipairs(PB.META_SOURCES) do
            local mb = CreateFrame("Button", nil, metaBox, "UIPanelButtonTemplate")
            mb:SetSize(94, 22)
            mb:SetPoint("TOPLEFT", 8 + (idx - 1) * 98, -26)
            mb:SetScript("OnClick", function()
                local plan = PB:GetPlan()
                plan.metaSource = src
                PB:Refresh()
            end)
            f.metaBtns[idx] = { btn = mb, source = src }
        end
        f.metaBox = metaBox

        -- ==========================================
        -- STEP B: BANK ALT CHOICE
        -- ==========================================
        local stepBLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        stepBLbl:SetPoint("TOPLEFT", 16, -222)
        stepBLbl:SetText("|cffffd100Step B — Bank Alt Choice (Mail & Shipping Strategy):|r")

        local bankYesBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        bankYesBtn:SetSize(503, 24)
        bankYesBtn:SetPoint("TOPLEFT", 16, -244)
        bankYesBtn:SetScript("OnClick", function()
            local plan = PB:GetPlan()
            plan.useBankAlt = true
            PB:Refresh()
        end)
        f.bankYesBtn = bankYesBtn

        local bankNoBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        bankNoBtn:SetSize(503, 24)
        bankNoBtn:SetPoint("TOPLEFT", 16, -272)
        bankNoBtn:SetScript("OnClick", function()
            local plan = PB:GetPlan()
            plan.useBankAlt = false
            PB:Refresh()
        end)
        f.bankNoBtn = bankNoBtn

        -- Live Plan Summary Box
        local summaryBox = CreateFrame("Frame", nil, f, template)
        summaryBox:SetPoint("TOPLEFT", 16, -306)
        summaryBox:SetPoint("TOPRIGHT", -16, -306)
        summaryBox:SetHeight(58)
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
        saveBtn:SetSize(156, 26)
        saveBtn:SetPoint("BOTTOMLEFT", 16, 14)
        saveBtn:SetText("Save & Apply Plan")
        saveBtn:SetScript("OnClick", function()
            local plan = PB:GetPlan()
            plan.completed = true
            PB:ApplyPlan()
            f:Hide()
        end)

        local setupBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        setupBtn:SetSize(152, 26)
        setupBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
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
        closeFoot:SetSize(84, 26)
        closeFoot:SetPoint("BOTTOMRIGHT", -16, 14)
        closeFoot:SetText("Close")
        closeFoot:SetScript("OnClick", function() f:Hide() end)

        PB.frame = f
    end

    PB:Refresh()
    PB.frame:Show()
    PB.frame:Raise()
end

function PB:Toggle()
    if PB.frame and PB.frame:IsShown() then
        PB.frame:Hide()
    else
        PB:Show()
    end
end
