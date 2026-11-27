local addonName, NS = ...
NS.StatCapsUI = {}
local SC = NS.StatCapsUI

SC.frame = nil
SC.charBtn = nil

local function GetLivePlayerStats()
    local meleeHit = (GetHitModifier and GetHitModifier()) or 0
    local spellHit = (GetSpellHitModifier and GetSpellHitModifier()) or 0
    local meleeCrit = (GetCritChance and GetCritChance()) or 0
    local spellCrit = 0
    if GetSpellCritChance then
        for school = 2, 7 do
            local ok, v = pcall(GetSpellCritChance, school)
            if ok and type(v) == "number" and v > spellCrit then spellCrit = v end
        end
    end
    local spellPower = 0
    if GetSpellBonusDamage then
        for school = 2, 7 do
            local ok, v = pcall(GetSpellBonusDamage, school)
            if ok and type(v) == "number" and v > spellPower then spellPower = v end
        end
    end
    local healPower = (GetSpellBonusHealing and GetSpellBonusHealing()) or 0
    local baseDef, modDef = 0, 0
    if UnitDefense then
        local ok, b, m = pcall(UnitDefense, "player")
        if ok then baseDef, modDef = b or 0, m or 0 end
    end
    local totalDef = baseDef + modDef

    local apBase, apPos, apNeg = 0, 0, 0
    if UnitAttackPower then
        local ok, b, p, n = pcall(UnitAttackPower, "player")
        if ok then apBase, apPos, apNeg = b or 0, p or 0, n or 0 end
    end
    local totalAP = apBase + apPos + apNeg

    return {
        meleeHit = meleeHit,
        spellHit = spellHit,
        meleeCrit = meleeCrit,
        spellCrit = spellCrit,
        spellPower = spellPower,
        healPower = healPower,
        defense = totalDef,
        ap = totalAP,
    }
end

local function FitSpecButtonText(btn, padX)
    if not btn or not btn.GetFontString then return end
    local fs = btn:GetFontString()
    if not fs then return end
    padX = padX or 10
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", btn, "LEFT", padX, 0)
    fs:SetPoint("RIGHT", btn, "RIGHT", -padX, 0)
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    if fs.SetMaxLines then fs:SetMaxLines(1) end

    local btnW = (btn.GetWidth and btn:GetWidth()) or 0
    local maxW = (btnW > 0 and btnW or 343) - (padX * 2)
    if maxW <= 0 then return end

    local fontPath, _, fontFlags = fs:GetFont()
    fontPath = fontPath or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    for _, size in ipairs({ 12, 11, 10, 9 }) do
        pcall(fs.SetFont, fs, fontPath, size, fontFlags)
        local textW = (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()) or (fs.GetStringWidth and fs:GetStringWidth()) or 0
        if textW <= maxW then
            break
        end
    end
end

function SC:BuildFrame()
    if SC.frame then return SC.frame end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", "WOWEngineStatCapsFrame", UIParent, template)
    f:SetSize(375, 295)
    f:SetPoint("CENTER", UIParent, "CENTER", 240, 20)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(130)
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
        table.insert(UISpecialFrames, "WOWEngineStatCapsFrame")
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -12)
    title:SetText("|cff00aeffWOWEngine|r |cffffd100Stat Caps & Targets|r")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local specBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    specBtn:SetHeight(24)
    specBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -42)
    specBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -42)
    specBtn:SetText("")
    FitSpecButtonText(specBtn, 10)
    specBtn:SetScript("OnClick", function()
        if NS.TalentAdvisor and NS.TalentAdvisor.CycleBuild then
            NS.TalentAdvisor:CycleBuild()
        end
    end)
    f.specBtn = specBtn

    local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", specBtn, "BOTTOMLEFT", 0, -10)
    body:SetPoint("TOPRIGHT", specBtn, "BOTTOMRIGHT", 0, -10)
    body:SetJustifyH("LEFT")
    f.body = body

    local closeFoot = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeFoot:SetSize(80, 22)
    closeFoot:SetPoint("BOTTOMRIGHT", -16, 10)
    closeFoot:SetText("Close")
    closeFoot:SetScript("OnClick", function() f:Hide() end)

    SC.frame = f
    return f
end

function SC:Refresh()
    if not SC.frame or not SC.frame:IsShown() then return end
    local build = NS.TalentAdvisor and NS.TalentAdvisor:GetSelectedBuild()
    local stats = GetLivePlayerStats()
    if not build then return end

    SC.frame.specBtn:SetText(build.label .. " (Click to Switch)")
    FitSpecButtonText(SC.frame.specBtn, 10)
    local caps = build.caps or {}
    local lines = {
        "|cffffd100Role:|r " .. tostring(build.role or "DPS"),
        "|cffffd100Weapon Type:|r " .. tostring(build.weapon or "Class Standard"),
        "|cffffd100Stat Priority:|r " .. tostring(build.priority or ""),
        "",
        "|cff00aeffLive Caps vs. Targets:|r",
    }

    if caps.defense and caps.defense > 0 then
        local okDef = stats.defense >= caps.defense
        table.insert(lines, string.format("  Defense: %s%d / %d (%s)|r",
            okDef and "|cff00ff00" or "|cffff9900", stats.defense, caps.defense, okDef and "CAPPED" or "Under Cap"))
    end
    if caps.meleeHit and caps.meleeHit > 0 then
        local okHit = stats.meleeHit >= caps.meleeHit
        table.insert(lines, string.format("  Melee/Ranged Hit: %s%.1f%% / %d%% (%s)|r",
            okHit and "|cff00ff00" or "|cffff9900", stats.meleeHit, caps.meleeHit, okHit and "CAPPED" or "Under Cap"))
    end
    if caps.spellHit and caps.spellHit > 0 then
        local okSH = stats.spellHit >= caps.spellHit
        table.insert(lines, string.format("  Spell Hit: %s%.1f%% / %d%% (%s)|r",
            okSH and "|cff00ff00" or "|cffff9900", stats.spellHit, caps.spellHit, okSH and "CAPPED" or "Under Cap"))
    end
    local liveCrit = (caps.spellHit and caps.spellHit > 0) and stats.spellCrit or stats.meleeCrit
    if caps.critTarget and caps.critTarget > 0 then
        local okC = liveCrit >= caps.critTarget
        table.insert(lines, string.format("  Crit Target: %s%.1f%% / %d%%|r",
            okC and "|cff00ff00" or "|cffffd100", liveCrit, caps.critTarget))
    end
    table.insert(lines, string.format("  Attack Power: |cffffd100%d|r   |   Spell Power: |cffffd100%d|r   |   Healing: |cffffd100%d|r",
        stats.ap, stats.spellPower, stats.healPower))

    SC.frame.body:SetText(table.concat(lines, "\n"))
end

function SC:Toggle()
    local f = SC:BuildFrame()
    if f:IsShown() then
        f:Hide()
    else
        if _G.CharacterFrame and _G.CharacterFrame:IsShown() then
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", _G.CharacterFrame, "TOPRIGHT", 6, -12)
        end
        f:Show()
        f:Raise()
        SC:Refresh()
    end
end

function SC:AttachCharacterButton()
    if SC.charBtn or not _G.CharacterFrame then return end
    local btn = CreateFrame("Button", "WOWEngineCharStatCapsBtn", _G.CharacterFrame, "UIPanelButtonTemplate")
    btn:SetSize(84, 22)
    btn:SetPoint("TOPRIGHT", _G.CharacterFrame, "TOPRIGHT", -34, -36)
    btn:SetFrameStrata("HIGH")
    btn:SetText("Stat Caps")
    btn:SetScript("OnClick", function() SC:Toggle() end)
    SC.charBtn = btn
end

local scEvents = CreateFrame("Frame")
scEvents:RegisterEvent("PLAYER_LOGIN")
scEvents:RegisterEvent("UNIT_STATS")
scEvents:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
scEvents:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        pcall(function() SC:AttachCharacterButton() end)
    else
        pcall(function() SC:Refresh() end)
    end
end)
