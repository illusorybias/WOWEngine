local addonName, NS = ...
NS.WaveTracker = {}
local WT = NS.WaveTracker
local C = NS.Compat

WT.frame = nil
WT.gatePrompt = nil
WT.questieDock = nil
WT.manageFrame = nil
WT.managePage = 1

-- Cross-client Quest Completion Check
function WT:IsQuestCompleted(questID)
    if not questID then return false end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
        if ok and done then return true end
    elseif IsQuestFlaggedCompleted then
        local ok, done = pcall(IsQuestFlaggedCompleted, questID)
        if ok and done then return true end
    end
    return false
end

function WT:IsQuestieLoaded()
    return (_G.Questie ~= nil) or (_G.QuestieLoader ~= nil) or (_G.Questie_BaseFrame ~= nil) or C.IsAddOnLoaded("Questie")
end

-- Locate Questie's live Quest Tracker frame (which replaces Blizzard's quest list), with clean fallback
function WT:FindQuestTrackerAnchor()
    local candidates = {
        { frame = _G.Questie_HeaderFrame, name = "Questie Tracker" },
        { frame = _G.Questie_BaseFrame,   name = "Questie Tracker" },
        { frame = _G.QuestieTracker,      name = "Questie Tracker" },
        { frame = _G.ObjectiveTrackerFrame, name = "Objective Tracker" },
        { frame = _G.QuestWatchFrame,     name = "Quest Watch" },
    }
    for _, c in ipairs(candidates) do
        if c.frame and c.frame.IsShown and c.frame:IsShown() then
            return c.frame, c.name
        end
    end
    -- Second pass: return Questie_BaseFrame even if currently collapsed/empty
    for _, c in ipairs(candidates) do
        if c.frame then
            return c.frame, c.name
        end
    end
    return nil, "HUD"
end

function WT:GetActiveQuestCount()
    local active = 0
    local completedInLog = 0

    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local okNum, numEntries = pcall(C_QuestLog.GetNumQuestLogEntries)
        if okNum and numEntries then
            for i = 1, numEntries do
                local okInfo, info = pcall(C_QuestLog.GetInfo, i)
                if okInfo and info and not info.isHeader and not info.isHidden then
                    active = active + 1
                    if info.questID and C_QuestLog.IsComplete then
                        local okDone, isDone = pcall(C_QuestLog.IsComplete, info.questID)
                        if okDone and isDone then
                            completedInLog = completedInLog + 1
                        end
                    end
                end
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        local okNum, numEntries = pcall(GetNumQuestLogEntries)
        if okNum and numEntries then
            for i = 1, numEntries do
                local okT, _, _, _, isHeader, _, isComplete = pcall(GetQuestLogTitle, i)
                if okT and not isHeader then
                    active = active + 1
                    if isComplete == 1 then
                        completedInLog = completedInLog + 1
                    end
                end
            end
        end
    end

    return active, completedInLog
end

WT.TRAINERS = {
    Horde = {
        Herbalism      = "Orgrimmar (The Drag 55.6, 39.6) — Jandi | Thunder Bluff (49.8, 39.8) — Komin Winterhoof",
        Alchemy        = "Orgrimmar (The Drag 56.6, 33.4) — Yelmak | Undercity (Apothecarium 47.6, 73.2) — Doctor Herbert Halsey",
        Enchanting     = "Orgrimmar (The Drag 53.8, 38.2) — Godan | Undercity (Magic Quarter 61.8, 61.2) — Lavinia Crowe",
        Mining         = "Orgrimmar (Valley of Honor 73.0, 26.8) — Makaru | Thunder Bluff (34.6, 57.6) — Brek Stonehoof",
        Blacksmithing  = "Orgrimmar (Valley of Honor 81.2, 22.8) — Saru Steelfury | Thunder Bluff (39.4, 55.6) — Karn Stonehoof",
        Engineering    = "Orgrimmar (Valley of Honor 75.8, 25.0) — Roxxik | Undercity (Rogues' Quarter 76.0, 73.8) — Graham Van Talen",
        Leatherworking = "Orgrimmar (The Drag 63.2, 44.6) — Karolek | Thunder Bluff (41.8, 42.6) — Una",
        Skinning       = "Orgrimmar (The Drag 63.2, 45.2) — Thuwd | Thunder Bluff (44.4, 43.2) — Mooranta",
        Tailoring      = "Orgrimmar (The Drag 63.4, 50.0) — Magar | Undercity (Magic Quarter 70.6, 30.2) — Josef Gregorian",
        Jewelcrafting  = "Silvermoon City (Bazaar 90.4, 73.8) — Kalinda | Orgrimmar (The Drag 72.2, 34.4)",
        Cooking        = "Orgrimmar (The Drag 57.4, 53.6) — Zamja | Thunder Bluff (51.0, 52.8) — Aska Mistrunner",
        Fishing        = "Orgrimmar (Valley of Honor 69.8, 29.6) — Lumak | Thunder Bluff (55.8, 46.8) — Kah Mistrunner",
        ["First Aid"]  = "Orgrimmar (Valley of Spirits 34.2, 84.4) — Arnok | Undercity (Rogues' Quarter 73.4, 55.6) — Mary Edras",
    },
    Alliance = {
        Herbalism      = "Stormwind (Mage Quarter 44.6, 77.6) — Tannysa | Ironforge (Mystic Ward 55.6, 58.6) — Reyna Stonebranch",
        Alchemy        = "Stormwind (Mage Quarter 46.6, 79.4) — Lilyssia Nightbreeze | Ironforge (Tinker Town 66.6, 55.2) — Tally Berryfizz",
        Enchanting     = "Stormwind (Mage Quarter 43.2, 64.2) — Lucan Cordell | Ironforge (Hall of Explorers 60.0, 45.4) — Gimble Thistlefuzz",
        Mining         = "Stormwind (Dwarven District 51.2, 17.2) — Gelman Stonehand | Ironforge (Great Forge 50.4, 26.8) — Geofram Bouldertoe",
        Blacksmithing  = "Stormwind (Dwarven District 56.2, 17.0) — Therum Deepforge | Ironforge (Great Forge 52.4, 41.8) — Bengus Deepforge",
        Engineering    = "Stormwind (Dwarven District 55.2, 8.2) — Lilliam Sparkspindle | Ironforge (Tinker Town 67.8, 42.8) — Springspindle Fizzlegear",
        Leatherworking = "Stormwind (Old Town 67.4, 49.4) — Simon Tanner | Ironforge (Great Forge 40.4, 33.4) — Fimble Finespindle",
        Skinning       = "Stormwind (Old Town 67.6, 49.2) — Maris Granger | Ironforge (Great Forge 40.0, 32.6) — Balthus Stoneflayer",
        Tailoring      = "Stormwind (Mage Quarter 43.4, 73.6) — Georgio Bolero | Ironforge (Great Forge 43.8, 29.2) — Jormund Stonebrow",
        Jewelcrafting  = "Exodar (Trader's Tier 45.0, 24.4) — Farii | Stormwind (Trade District 63.4, 61.6)",
        Cooking        = "Stormwind (Old Town 77.6, 53.2) — Stephen Ryback | Ironforge (Great Forge 60.0, 36.8) — Daryl Riknussun",
        Fishing        = "Stormwind (Canals 45.8, 58.4) — Arnold Leland | Ironforge (Forlorn Cavern 48.0, 6.4) — Grimnur Stonebrand",
        ["First Aid"]  = "Stormwind (Cathedral Square 43.2, 26.2) — Shaina Fuller | Ironforge (Great Forge 54.8, 58.6) — Nissa Firestone",
    },
}

WT.CHECKLIST = {
    { id = "lv5_profs",      wave = 1, minLevel = 5,  autoType = "profs2",   label = "[Lv 5] Learn 2 Primary Profs + Sub-Profs & Verify Mail Routes" },
    { id = "lv10_class",     wave = 1, minLevel = 10, autoType = "prof50",   label = "[Lv 10] Spend Talents, Class Quest & Raise Profs to 50+" },
    { id = "lv15_novice",    wave = 1, minLevel = 15, autoType = "prof75",   label = "[Lv 15] Capital Flight Paths & Start Novice Spelunker (RFC/WC/DM/SFK/RoL)" },
    { id = "lv20_craft",     wave = 1, minLevel = 20, autoType = "prof125",  label = "[Lv 20] Journeyman Profs (125+) & Bag Upgrade Check (/he bagstatus)" },
    { id = "lv25_legacy",    wave = 1, minLevel = 25, autoType = "legacy25", label = "[Lv 25 WAVE 1 GATE] Class Legacy Pt + Crafting 150 Pt + Finish Novice Spelunker" },
    { id = "lv35_exp",       wave = 2, minLevel = 35, autoType = "prof200",  label = "[Lv 35] Artisan Profs (200+) & Experienced Spelunker Dungeons (Lv26-45)" },
    { id = "lv45_legacy",    wave = 2, minLevel = 45, autoType = "legacy45", label = "[Lv 45 WAVE 2 GATE] Mount + Class Legacy Pt + Crafting 225 Pt + Exp. Spelunker" },
    { id = "lv60_legacy",    wave = 3, minLevel = 60, autoType = "legacy60", label = "[Lv 60 WAVE 3 CAP] Class Legacy Pt + Crafting 300 Pt + Master Spelunker & Raids" },
}

-- Auto-evaluate whether a 5-level milestone is already satisfied on the current character
function WT:IsMilestoneAutoDone(item)
    if not item or not item.autoType then return false end
    local lv = UnitLevel("player") or 1
    local profs = C.GetPlayerProfessions()
    local pCount, maxRank = 0, 0
    for _, r in pairs(profs) do
        pCount = pCount + 1
        local nr = tonumber(r) or 0
        if nr > maxRank then maxRank = nr end
    end
    if item.autoType == "profs2" then return pCount >= 2 end
    if item.autoType == "prof50" then return lv >= 10 and maxRank >= 50 end
    if item.autoType == "prof75" then return lv >= 15 and maxRank >= 75 end
    if item.autoType == "prof125" then return lv >= 20 and maxRank >= 125 end
    if item.autoType == "legacy25" then return lv >= 25 and maxRank >= 150 end
    if item.autoType == "prof200" then return lv >= 35 and maxRank >= 200 end
    if item.autoType == "legacy45" then return lv >= 45 and maxRank >= 225 end
    if item.autoType == "legacy60" then return lv >= 60 and maxRank >= 300 end
    return false
end

function WT:GetCurrentWaveInfo()
    local ws = NS:GetWaveState()
    local waveIdx = tonumber(ws.currentWave) or 1
    local gates = ws.gates or { 20, 40, 50, 60 }
    if waveIdx < 1 then waveIdx = 1 end
    if waveIdx > #gates then waveIdx = #gates end
    local targetLevel = tonumber(gates[waveIdx]) or 20
    return waveIdx, targetLevel, gates
end

function WT:GetCharKey()
    local name = C.GetPlayerName() or "Player"
    return C.CanonicalCharKey(name) or string.lower(name)
end

function WT:IsSnoozed()
    local ws = NS:GetWaveState()
    local key = WT:GetCharKey()
    local untilTs = ws.snoozedUntilByChar and tonumber(ws.snoozedUntilByChar[key]) or 0
    if untilTs > time() then
        return true, math.ceil((untilTs - time()) / 60)
    end
    return false, 0
end

function WT:Snooze(minutes)
    local mins = tonumber(minutes) or 30
    local ws = NS:GetWaveState()
    ws.snoozedUntilByChar = ws.snoozedUntilByChar or {}
    local key = WT:GetCharKey()
    ws.snoozedUntilByChar[key] = time() + (mins * 60)
    if WT.gatePrompt and WT.gatePrompt:IsShown() then
        WT.gatePrompt:Hide()
    end
    NS:Print(string.format("Wave Gate prompt snoozed for |cffffd100%d minutes|r on %s.", mins, C.GetPlayerName() or "Player"))
end

function WT:ClearSnooze()
    local ws = NS:GetWaveState()
    if ws.snoozedUntilByChar then
        ws.snoozedUntilByChar[WT:GetCharKey()] = nil
    end
end

-- Uses ONLY your own leveling characters (excludes non-yours Altoholic/Guild/Friends characters!)
function WT:GetWaveRosterStatus()
    local waveIdx, targetLevel = WT:GetCurrentWaveInfo()
    local list = NS.Roster:GetOwnLevelingRoster()
    local ready = {}
    local behind = {}

    for _, info in ipairs(list) do
        local lv = tonumber(info.level) or 0
        if lv >= targetLevel then
            table.insert(ready, info)
        else
            table.insert(behind, info)
        end
    end

    return waveIdx, targetLevel, ready, behind
end

function WT:AdvanceWave()
    local ws = NS:GetWaveState()
    local gates = ws.gates or { 20, 40, 50, 60 }
    local nextWave = (tonumber(ws.currentWave) or 1) + 1
    if nextWave > #gates then
        nextWave = 1
    end
    ws.currentWave = nextWave
    ws.snoozedUntilByChar = {}
    NS:Print(string.format("Active leveling wave set to |cff00ff00Wave %d|r (Target Level: |cffffd100%d|r).", nextWave, gates[nextWave]))
    WT:RefreshUI()
    WT:RefreshQuestieDock()
end

function WT:PrintTrainerLookup(query)
    local _, faction = NS:GetContextKeys()
    local tableForFaction = WT.TRAINERS[faction] or WT.TRAINERS.Horde
    local q = string.lower(C.Trim(query or ""))

    if q == "" then
        local profs = C.GetPlayerProfessions()
        NS:Print("=== " .. faction .. " Profession Trainer Coordinates ===")
        local printed = false
        for pName in pairs(profs) do
            if tableForFaction[pName] then
                printed = true
                NS:Print("  |cffffd100" .. pName .. ":|r " .. tableForFaction[pName])
            end
        end
        if not printed then
            NS:Print("  No primary professions detected yet. Type |cffffd100/he trainer <profession>|r (e.g. /he trainer herb, /he trainer ench, /he trainer all).")
        end
        return
    end

    if q == "all" then
        NS:Print("=== All " .. faction .. " Capital Trainer Coordinates ===")
        for pName, loc in pairs(tableForFaction) do
            NS:Print("  |cffffd100" .. pName .. ":|r " .. loc)
        end
        return
    end

    local hits = 0
    for pName, loc in pairs(tableForFaction) do
        if string.find(string.lower(pName), q, 1, true) then
            hits = hits + 1
            NS:Print("  |cffffd100" .. pName .. " (" .. faction .. "):|r " .. loc)
        end
    end
    if hits == 0 then
        NS:Print("No trainer match for '" .. q .. "'. Try: herb, alch, ench, min, bs, eng, lw, skin, tail, jc, cook, fish, first aid, or all.")
    end
end

local function ApplyBlueGoldBackdrop(f, alpha)
    if f.SetBackdrop then
        local ok = pcall(function()
            f:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            f:SetBackdropColor(0.04, 0.09, 0.19, alpha or 0.94)
            f:SetBackdropBorderColor(0.95, 0.78, 0.18, 0.95)
        end)
        if ok then return end
    end
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetColorTexture(0.04, 0.09, 0.19, alpha or 0.94)
end

-- ==========================================
-- DOCKED QUESTIE TRACKER HEADING (Replaces/Extends Questie Quest List Header)
-- ==========================================
local dockCbCounter = 0

function WT:AttachQuestieDockPosition()
    local dock = WT.questieDock
    if not dock then return end

    local anchorFrame, anchorLabel = WT:FindQuestTrackerAnchor()
    dock.anchorLabel = anchorLabel
    dock:ClearAllPoints()

    if anchorFrame then
        local w = anchorFrame.GetWidth and anchorFrame:GetWidth() or 240
        if w < 220 then w = 240 end
        if w > 320 then w = 300 end
        dock:SetWidth(w)
        dock:SetPoint("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", 0, 4)
    else
        dock:SetWidth(245)
        dock:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -220)
    end
end

function WT:InitQuestieDock()
    local ws = NS:GetWaveState()
    if not ws.dockQuestieHeader then
        if WT.questieDock then WT.questieDock:Hide() end
        return
    end

    if not WT.questieDock then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local dock = CreateFrame("Frame", "WOWEngineQuestieHeading", UIParent, template)
        dock:SetSize(248, 26)
        dock:SetFrameStrata("MEDIUM")
        dock:SetFrameLevel(30)
        dock:SetClampedToScreen(true)
        dock:EnableMouse(true)
        ApplyBlueGoldBackdrop(dock, 0.90)

        -- Clickable Header Bar ("WOWEngine: Wave X (Lv Y)")
        local hdrBtn = CreateFrame("Button", nil, dock)
        hdrBtn:SetPoint("TOPLEFT", 2, -2)
        hdrBtn:SetPoint("TOPRIGHT", -2, -2)
        hdrBtn:SetHeight(22)
        hdrBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local hdrBg = hdrBtn:CreateTexture(nil, "BACKGROUND")
        hdrBg:SetAllPoints(hdrBtn)
        hdrBg:SetColorTexture(0.06, 0.17, 0.36, 0.92)

        local hdrTxt = hdrBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hdrTxt:SetPoint("LEFT", 8, 0)
        hdrTxt:SetJustifyH("LEFT")
        dock.hdrTxt = hdrTxt

        local toggleTxt = hdrBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        toggleTxt:SetPoint("RIGHT", -8, 0)
        dock.toggleTxt = toggleTxt

        hdrBtn:SetScript("OnClick", function(self, btn)
            if btn == "RightButton" then
                WT:ShowUI()
            else
                local curWs = NS:GetWaveState()
                curWs.questieHeaderCollapsed = not curWs.questieHeaderCollapsed
                WT:RefreshQuestieDock()
            end
        end)

        hdrBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("|cff00aeffWOWEngine|r Questie Tracker Heading")
            GameTooltip:AddLine("|cffffffffLeft-Click:|r Expand / Collapse Wave Milestones", 0.85, 0.85, 0.85)
            GameTooltip:AddLine("|cffffffffRight-Click:|r Open Full Wave & Questie Checklist", 0.85, 0.85, 0.85)
            GameTooltip:Show()
        end)
        hdrBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Collapsible Body (shows top 3 active wave milestones + quick buttons)
        local body = CreateFrame("Frame", nil, dock)
        body:SetPoint("TOPLEFT", 4, -26)
        body:SetPoint("BOTTOMRIGHT", -4, 4)
        dock.body = body

        dock.miniRows = {}
        for i = 1, 3 do
            dockCbCounter = dockCbCounter + 1
            local cbName = "WOWEngineDockCB" .. dockCbCounter
            local cb = CreateFrame("CheckButton", cbName, body, "UICheckButtonTemplate")
            cb:SetSize(18, 18)
            cb:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 20)

            local builtIn = _G[cbName .. "Text"] or cb.Text
            if builtIn and builtIn.SetText then builtIn:SetText("") end

            local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
            lbl:SetPoint("RIGHT", body, "RIGHT", -2, 0)
            lbl:SetJustifyH("LEFT")
            lbl:SetWordWrap(false)
            cb.lbl = lbl

            cb:SetScript("OnClick", function(self)
                if self.itemId then
                    local curWs = NS:GetWaveState()
                    curWs.completedChecklist = curWs.completedChecklist or {}
                    local cKey = WT:GetCharKey()
                    curWs.completedChecklist[cKey] = curWs.completedChecklist[cKey] or {}
                    curWs.completedChecklist[cKey][self.itemId] = self:GetChecked() and true or false
                    WT:RefreshQuestieDock()
                    WT:RefreshUI()
                end
            end)

            dock.miniRows[i] = cb
        end

        local bFull = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
        bFull:SetSize(74, 18)
        bFull:SetPoint("BOTTOMLEFT", 2, 2)
        bFull:SetText("Checklist")
        bFull:SetScript("OnClick", function() WT:ShowUI() end)

        local bTrain = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
        bTrain:SetSize(68, 18)
        bTrain:SetPoint("LEFT", bFull, "RIGHT", 4, 0)
        bTrain:SetText("Trainers")
        bTrain:SetScript("OnClick", function() WT:PrintTrainerLookup("") end)

        local bSetup = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
        bSetup:SetSize(56, 18)
        bSetup:SetPoint("BOTTOMRIGHT", -2, 2)
        bSetup:SetText("Setup")
        bSetup:SetScript("OnClick", function()
            if NS.Onboarding and NS.Onboarding.Show then NS.Onboarding:Show(1) end
        end)

        WT.questieDock = dock
    end

    WT:AttachQuestieDockPosition()
    WT:RefreshQuestieDock()
    WT.questieDock:Show()
end

function WT:RefreshQuestieDock()
    local ws = NS:GetWaveState()
    if not ws.dockQuestieHeader then
        if WT.questieDock then WT.questieDock:Hide() end
        return
    end
    if not WT.questieDock then return end

    WT:AttachQuestieDockPosition()
    local dock = WT.questieDock
    local waveIdx, targetLevel, ready, behind = WT:GetWaveRosterStatus()
    local pLevel = UnitLevel("player") or 1
    local collapsed = ws.questieHeaderCollapsed and true or false

    dock.hdrTxt:SetText(string.format("|cff00aeffWOWEngine|r |cffffd100Wave %d|r (Lv%d/%d | %d/%d Alts)",
        waveIdx, pLevel, targetLevel, #ready, #ready + #behind))
    dock.toggleTxt:SetText(collapsed and "|cffffd100[+]|r" or "|cffaaaaaa[-]|r")

    if collapsed then
        dock.body:Hide()
        dock:SetHeight(26)
        return
    end

    dock.body:Show()
    local cKey = WT:GetCharKey()
    local charChecks = (ws.completedChecklist and ws.completedChecklist[cKey]) or {}

    -- Show up to 3 relevant milestones (prioritizing unchecked items in current or earlier wave)
    local displayItems = {}
    for _, item in ipairs(WT.CHECKLIST) do
        if not charChecks[item.id] and item.wave <= waveIdx then
            table.insert(displayItems, item)
            if #displayItems >= 3 then break end
        end
    end
    if #displayItems < 3 then
        for _, item in ipairs(WT.CHECKLIST) do
            if not charChecks[item.id] and item.wave > waveIdx then
                table.insert(displayItems, item)
                if #displayItems >= 3 then break end
            end
        end
    end

    local shownRows = 0
    for i = 1, 3 do
        local cb = dock.miniRows[i]
        local item = displayItems[i]
        if item then
            shownRows = shownRows + 1
            cb.itemId = item.id
            cb:SetChecked(false)
            cb.lbl:SetText(string.format("|cffffd100[Lv%d]|r %s", item.minLevel, item.label))
            cb:Show()
        else
            cb.itemId = nil
            cb:Hide()
        end
    end

    if shownRows == 0 then
        dock.miniRows[1].itemId = nil
        dock.miniRows[1]:SetChecked(true)
        dock.miniRows[1].lbl:SetText("|cff00ff00All Wave milestones checked!|r")
        dock.miniRows[1]:Show()
        shownRows = 1
    end

    dock:SetHeight(56 + (shownRows * 20))
end

-- ==========================================
-- WAVE GATE SNOOZE POPUP
-- ==========================================
function WT:ShowGatePrompt(forceShow)
    local waveIdx, targetLevel, ready, behind = WT:GetWaveRosterStatus()
    local playerLevel = UnitLevel("player") or 1
    if not forceShow then
        if playerLevel < targetLevel then return end
        local snoozed = WT:IsSnoozed()
        if snoozed then return end
    end

    if not WT.gatePrompt then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local f = CreateFrame("Frame", "WOWEngineWaveGatePrompt", UIParent, template)
        f:SetSize(430, 215)
        f:SetPoint("TOP", UIParent, "TOP", 0, -110)
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(150)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        ApplyBlueGoldBackdrop(f, 0.97)

        if UISpecialFrames then
            table.insert(UISpecialFrames, "WOWEngineWaveGatePrompt")
        end

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetText("|cff00aeffWOWEngine|r |cffffd100Wave Gate Reached!|r")

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
        body:SetWidth(398)
        body:SetJustifyH("LEFT")
        f.body = body

        local bSnooze30 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        bSnooze30:SetSize(96, 24)
        bSnooze30:SetPoint("BOTTOMLEFT", 14, 14)
        bSnooze30:SetText("Snooze 30m")
        bSnooze30:SetScript("OnClick", function() WT:Snooze(30) end)

        local bSnooze120 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        bSnooze120:SetSize(96, 24)
        bSnooze120:SetPoint("LEFT", bSnooze30, "RIGHT", 6, 0)
        bSnooze120:SetText("Snooze 2h")
        bSnooze120:SetScript("OnClick", function() WT:Snooze(120) end)

        local bOpenWave = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        bOpenWave:SetSize(110, 24)
        bOpenWave:SetPoint("LEFT", bSnooze120, "RIGHT", 6, 0)
        bOpenWave:SetText("Open Checklist")
        bOpenWave:SetScript("OnClick", function()
            f:Hide()
            WT:ShowUI()
        end)

        local bNextWave = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        bNextWave:SetSize(92, 24)
        bNextWave:SetPoint("BOTTOMRIGHT", -14, 14)
        bNextWave:SetText("Next Wave")
        bNextWave:SetScript("OnClick", function()
            WT:AdvanceWave()
            f:Hide()
        end)

        WT.gatePrompt = f
    end

    local nextAltHint = "All of your tracked alts have reached Wave " .. waveIdx .. "! Click Next Wave to advance."
    if #behind > 0 then
        local names = {}
        for i = 1, math.min(4, #behind) do
            table.insert(names, string.format("%s (Lv%d)", behind[i].name, behind[i].level or 0))
        end
        nextAltHint = "Your alts still leveling in Wave " .. waveIdx .. " (" .. #behind .. "): |cffffd100" .. table.concat(names, ", ") .. "|r"
    end

    WT.gatePrompt.body:SetText(string.format(
        "|cff00ff00%s|r reached |cffffd100Level %d|r (Wave %d Gate: Lv %d).\n\nYour Own Alts Progress: |cff00ff00%d Ready|r / |cffff9900%d Remaining|\n%s\n\nTip: Visit a mailbox to run |cffffd100/hordeship|r before rotating to your next alt.",
        C.GetPlayerName() or "Player", playerLevel, waveIdx, targetLevel, #ready, #behind, nextAltHint
    ))

    WT.gatePrompt:Show()
    WT.gatePrompt:Raise()
end

-- ==========================================
-- FULL QUESTIE CHECKLIST & WAVE SYNC WINDOW (/he wave)
-- ==========================================
local wtCbCounter = 0

function WT:ShowUI()
    NS.Roster:ScanAll(true)
    if not WT.frame then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local f = CreateFrame("Frame", "WOWEngineWaveTrackerFrame", UIParent, template)
        f:SetSize(555, 540)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(115)
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        ApplyBlueGoldBackdrop(f, 0.96)

        if UISpecialFrames then
            table.insert(UISpecialFrames, "WOWEngineWaveTrackerFrame")
        end

        local headerBg = f:CreateTexture(nil, "ARTWORK")
        headerBg:SetPoint("TOPLEFT", 4, -4)
        headerBg:SetPoint("TOPRIGHT", -4, -4)
        headerBg:SetHeight(46)
        headerBg:SetColorTexture(0.06, 0.16, 0.34, 0.95)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -12)
        title:SetText("|cff00aeffWOWEngine|r |cffffd100Questie Checklist & Wave Gate Sync|r")

        local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
        f.subtitle = subtitle

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        local statusTxt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        statusTxt:SetPoint("TOPLEFT", 16, -60)
        statusTxt:SetWidth(510)
        statusTxt:SetJustifyH("LEFT")
        f.statusTxt = statusTxt

        local bAdvance = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        bAdvance:SetSize(130, 24)
        bAdvance:SetPoint("TOPLEFT", 16, -104)
        bAdvance:SetText("Advance Wave >")
        bAdvance:SetScript("OnClick", function() WT:AdvanceWave() end)

        local bTestGate = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        bTestGate:SetSize(130, 24)
        bTestGate:SetPoint("LEFT", bAdvance, "RIGHT", 8, 0)
        bTestGate:SetText("Test Gate Prompt")
        bTestGate:SetScript("OnClick", function() WT:ShowGatePrompt(true) end)

        local bTrainers = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        bTrainers:SetSize(135, 24)
        bTrainers:SetPoint("LEFT", bTestGate, "RIGHT", 8, 0)
        bTrainers:SetText("My Prof Trainers")
        bTrainers:SetScript("OnClick", function() WT:PrintTrainerLookup("") end)

        local bSnooze = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        bSnooze:SetSize(78, 24)
        bSnooze:SetPoint("LEFT", bTrainers, "RIGHT", 6, 0)
        bSnooze:SetText("Snooze")
        bSnooze:SetScript("OnClick", function()
            WT:Snooze(30)
            WT:RefreshUI()
        end)

        local bManage = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        bManage:SetSize(96, 24)
        bManage:SetPoint("BOTTOMLEFT", 14, 12)
        bManage:SetText("Manage Alts")
        bManage:SetScript("OnClick", function()
            WT:OpenManageAltsPopup()
        end)

        local bWizard = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        bWizard:SetSize(112, 24)
        bWizard:SetPoint("LEFT", bManage, "RIGHT", 6, 0)
        bWizard:SetText("Wave Setup Wizard")
        bWizard:SetScript("OnClick", function()
            WT:OpenWaveWizard()
        end)

        local bProcess = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        bProcess:SetSize(108, 24)
        bProcess:SetPoint("LEFT", bWizard, "RIGHT", 6, 0)
        bProcess:SetText("Wave Process")
        bProcess:SetScript("OnClick", function()
            WT:ShowWaveProcessPopup()
        end)

        -- Toggle 1: Dock Heading on Questie Tracker
        wtCbCounter = wtCbCounter + 1
        local cbDock = CreateFrame("CheckButton", "WOWEngineWaveCB" .. wtCbCounter, f, "UICheckButtonTemplate")
        cbDock:SetSize(22, 22)
        cbDock:SetPoint("TOPLEFT", 16, -134)
        local cbDockOld = _G["WOWEngineWaveCB" .. wtCbCounter .. "Text"] or cbDock.Text
        if cbDockOld and cbDockOld.SetText then cbDockOld:SetText("") end
        local cbDockLbl = cbDock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cbDockLbl:SetPoint("LEFT", cbDock, "RIGHT", 4, 0)
        cbDockLbl:SetText("Dock WOWEngine Heading onto Questie Quest List (HUD)")
        cbDock:SetScript("OnClick", function(self)
            local ws = NS:GetWaveState()
            ws.dockQuestieHeader = self:GetChecked() and true or false
            if ws.dockQuestieHeader then
                WT:InitQuestieDock()
            elseif WT.questieDock then
                WT.questieDock:Hide()
            end
            WT:RefreshUI()
        end)
        f.cbDock = cbDock

        -- Toggle 2: Own Logged-In Characters ONLY vs Include Altoholic
        wtCbCounter = wtCbCounter + 1
        local cbAltoWave = CreateFrame("CheckButton", "WOWEngineWaveCB" .. wtCbCounter, f, "UICheckButtonTemplate")
        cbAltoWave:SetSize(22, 22)
        cbAltoWave:SetPoint("TOPLEFT", cbDock, "BOTTOMLEFT", 0, -2)
        local cbAltoOld = _G["WOWEngineWaveCB" .. wtCbCounter .. "Text"] or cbAltoWave.Text
        if cbAltoOld and cbAltoOld.SetText then cbAltoOld:SetText("") end
        local cbAltoLbl = cbAltoWave:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cbAltoLbl:SetPoint("LEFT", cbAltoWave, "RIGHT", 4, 0)
        cbAltoLbl:SetText("Also include Altoholic alts in Wave Sync (OFF = Only alts you logged into; Mailing keeps all)")
        cbAltoWave:SetScript("OnClick", function(self)
            local ws = NS:GetWaveState()
            ws.includeAltoholicInWave = self:GetChecked() and true or false
            WT:RefreshUI()
            WT:RefreshQuestieDock()
        end)
        f.cbAltoWave = cbAltoWave

        local chkHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        chkHeader:SetPoint("TOPLEFT", 16, -186)
        chkHeader:SetText("|cffffd100Wave & Questie Milestone Checklist (Per Character):|r")

        f.checkRows = {}
        for idx, item in ipairs(WT.CHECKLIST) do
            wtCbCounter = wtCbCounter + 1
            local cbName = "WOWEngineWaveCB" .. wtCbCounter
            local cb = CreateFrame("CheckButton", cbName, f, "UICheckButtonTemplate")
            cb:SetSize(22, 22)
            cb:SetPoint("TOPLEFT", 16, -206 - (idx - 1) * 24)

            local builtInText = _G[cbName .. "Text"] or cb.Text
            if builtInText and builtInText.SetText then
                builtInText:SetText("")
            end

            local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
            lbl:SetWidth(480)
            lbl:SetJustifyH("LEFT")
            cb.lbl = lbl

            cb:SetScript("OnClick", function(self)
                local ws = NS:GetWaveState()
                ws.completedChecklist = ws.completedChecklist or {}
                local cKey = WT:GetCharKey()
                ws.completedChecklist[cKey] = ws.completedChecklist[cKey] or {}
                ws.completedChecklist[cKey][item.id] = self:GetChecked() and true or false
                WT:RefreshUI()
                WT:RefreshQuestieDock()
            end)

            f.checkRows[idx] = { cb = cb, item = item }
        end

        local rosterTxt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rosterTxt:SetPoint("TOPLEFT", 16, -408)
        rosterTxt:SetWidth(510)
        rosterTxt:SetJustifyH("LEFT")
        f.rosterTxt = rosterTxt

        local doneBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        doneBtn:SetSize(90, 24)
        doneBtn:SetPoint("BOTTOMRIGHT", -14, 12)
        doneBtn:SetText("Close")
        doneBtn:SetScript("OnClick", function() f:Hide() end)

        WT.frame = f
    end

    WT:RefreshUI()
    WT.frame:Show()
    WT.frame:Raise()
end

function WT:RefreshUI()
    if not WT.frame then return end
    local fp = NS:GetFactionProfile()
    local realm = NS:GetContextKeys()
    local player = C.GetPlayerName() or "Player"
    local pLevel = UnitLevel("player") or 1
    local waveIdx, targetLevel, ready, behind = WT:GetWaveRosterStatus()
    local activeQ, doneQ = WT:GetActiveQuestCount()
    local questieStr = WT:IsQuestieLoaded() and "|cff00ff00Connected|r" or "|cffaaaaaaNot Loaded|r"
    local snoozed, minsLeft = WT:IsSnoozed()
    local snoozeStr = snoozed and ("|cffff9900Snoozed (" .. minsLeft .. "m)|r") or "|cff00ff00Armed|r"
    local ws = NS:GetWaveState()

    WT.frame.subtitle:SetText(string.format("%s (%s) | %s (Lv%d) | %s",
        fp.suiteName, realm, player, pLevel, fp.plan))

    WT.frame.statusTxt:SetText(string.format(
        "Active Wave: |cff00ff00Wave %d|r (Gate Lv |cffffd100%d|r)   |   Gate Alert: %s\nQuestie Bridge: %s   |   Active Quests: |cffffd100%d|r (%d ready to turn in)",
        waveIdx, targetLevel, snoozeStr, questieStr, activeQ, doneQ
    ))

    WT.frame.cbDock:SetChecked(ws.dockQuestieHeader and true or false)
    WT.frame.cbAltoWave:SetChecked(ws.includeAltoholicInWave and true or false)

    local cKey = WT:GetCharKey()
    local charChecks = (ws.completedChecklist and ws.completedChecklist[cKey]) or {}

    for _, row in ipairs(WT.frame.checkRows) do
        local item = row.item
        local autoDone = WT:IsMilestoneAutoDone(item)
        local checked = (charChecks[item.id] or autoDone) and true or false
        row.cb:SetChecked(checked)
        local overdue = (not checked) and (pLevel >= item.minLevel)
        local color = checked and "|cff00ff00" or (overdue and "|cffff6633" or "|cffaaaaaa")
        local tag = overdue and " [OVERDUE]" or (autoDone and " [AUTO]" or "")
        row.cb.lbl:SetText(string.format("%s[W%d] %s%s|r", color, item.wave, item.label, tag))
    end

    local filterMode = ws.includeAltoholicInWave and "Own + Altoholic" or "My Logged-In Alts Only"
    local profCapByWave = { [1] = 150, [2] = 225, [3] = 300, [4] = 300 }
    local stageNameByWave = {
        [1] = "Wave 1 Gate (Lv20 + Journeyman 150)",
        [2] = "Wave 2 Gate (Lv40 + Mount + Artisan 225)",
        [3] = "Wave 3 Gate (Lv50 + Master 300)",
        [4] = "Wave 4 Cap (Lv60 + Pre-BiS)",
    }
    local targetProfCap = profCapByWave[waveIdx] or 150
    local nextStageLabel = stageNameByWave[waveIdx] or ("Wave " .. waveIdx .. " Gate")

    -- Sort remaining alts by lowest level first so the 4 most behind appear at the top
    table.sort(behind, function(a, b)
        local la = tonumber(a.level) or 0
        local lb = tonumber(b.level) or 0
        if la ~= lb then return la < lb end
        return string.lower(a.name or "") < string.lower(b.name or "")
    end)

    local lines = {
        string.format("|cff00aeffNext 4 Characters to Progress (%s):|r |cff00ff00%d Ready|r | |cffff9900%d Remaining|r",
            filterMode, #ready, #behind)
    }

    if #behind == 0 then
        table.insert(lines, "|cff00ff00All tracked characters reached Wave " .. waveIdx .. "! Click Advance Wave > for the next tier.|r")
    else
        for i = 1, math.min(4, #behind) do
            local ch = behind[i]
            local lv = tonumber(ch.level) or 1
            local profSummary = "Learn 2 Profs"
            if ch.professions and next(ch.professions) ~= nil then
                local pParts = {}
                for pn, pr in pairs(ch.professions) do
                    table.insert(pParts, string.format("%s %d/%d", string.sub(pn, 1, 4), tonumber(pr) or 1, targetProfCap))
                end
                table.sort(pParts)
                profSummary = table.concat(pParts, ", ")
            end
            table.insert(lines, string.format("  %d. |cffffd100%s|r — Lv%d -> |cff00ff00Lv%d|r | Profs: |cff00aeff%s|r | %s",
                i, ch.name or "?", lv, targetLevel, profSummary, nextStageLabel))
        end
    end

    WT.frame.rosterTxt:SetText(table.concat(lines, "\n"))
end

function WT:OnLogin()
    -- Delay dock init slightly so Questie has finished creating Questie_BaseFrame
    if C_Timer and C_Timer.After then
        C_Timer.After(2.0, function()
            pcall(function() WT:InitQuestieDock() end)
        end)
        C_Timer.After(5.0, function()
            pcall(function() WT:RefreshQuestieDock() end)
        end)
    else
        pcall(function() WT:InitQuestieDock() end)
    end

    local ws = NS:GetWaveState()
    if ws.autoPromptEnabled then
        local _, targetLevel = WT:GetCurrentWaveInfo()
        local pLevel = UnitLevel("player") or 1
        if pLevel >= targetLevel and not WT:IsSnoozed() then
            if C_Timer and C_Timer.After then
                C_Timer.After(2.5, function()
                    WT:ShowGatePrompt(false)
                end)
            end
        end
    end
end

local levelWatch = CreateFrame("Frame")
levelWatch:RegisterEvent("PLAYER_LEVEL_UP")
levelWatch:RegisterEvent("QUEST_LOG_UPDATE")
levelWatch:SetScript("OnEvent", function(self, event, newLevel)
    if event == "PLAYER_LEVEL_UP" then
        if NS.Roster and NS.Roster.ScanCurrentPlayer then
            NS.Roster:ScanCurrentPlayer()
        end
        local _, targetLevel = WT:GetCurrentWaveInfo()
        local lv = tonumber(newLevel) or UnitLevel("player") or 1
        if lv >= targetLevel then
            WT:ClearSnooze()
            WT:ShowGatePrompt(false)
        end
        if WT.frame and WT.frame:IsShown() then
            WT:RefreshUI()
        end
        WT:RefreshQuestieDock()
    elseif event == "QUEST_LOG_UPDATE" then
        WT:RefreshQuestieDock()
    end
end)


-- ==========================================
-- INCLUDE / EXCLUDE CHARACTERS POPUP (Wave Leveling Roster Filter)
-- ==========================================
local manageCbCounter = 0

function WT:OpenManageAltsPopup()
    NS.Roster:ScanAll(true)
    if not WT.manageFrame then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local mf = CreateFrame("Frame", "WOWEngineManageAltsFrame", UIParent, template)
        mf:SetSize(440, 355)
        mf:SetPoint("CENTER", UIParent, "CENTER", 40, 10)
        mf:SetFrameStrata("DIALOG")
        mf:SetFrameLevel(145)
        mf:SetClampedToScreen(true)
        mf:SetMovable(true)
        mf:EnableMouse(true)
        mf:RegisterForDrag("LeftButton")
        mf:SetScript("OnDragStart", function(self) self:StartMoving() end)
        mf:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        ApplyBlueGoldBackdrop(mf, 0.98)

        if UISpecialFrames then
            table.insert(UISpecialFrames, "WOWEngineManageAltsFrame")
        end

        local title = mf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetText("|cff00aeffManage Wave Alts|r |cffffd100(Include / Exclude)|r")

        local closeBtn = CreateFrame("Button", nil, mf, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() mf:Hide() end)

        local desc = mf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        desc:SetWidth(410)
        desc:SetJustifyH("LEFT")
        desc:SetText("Checked = Included in Wave Leveling Sync. Unchecked = Excluded from Wave Sync (still available for Mail Routing).")

        mf.rows = {}
        for i = 1, 9 do
            manageCbCounter = manageCbCounter + 1
            local cbName = "WOWEngineManageAltCB" .. manageCbCounter
            local cb = CreateFrame("CheckButton", cbName, mf, "UICheckButtonTemplate")
            cb:SetSize(22, 22)
            cb:SetPoint("TOPLEFT", 14, -74 - (i - 1) * 24)

            local builtIn = _G[cbName .. "Text"] or cb.Text
            if builtIn and builtIn.SetText then builtIn:SetText("") end

            local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lbl:SetPoint("LEFT", cb, "RIGHT", 6, 0)
            lbl:SetWidth(375)
            lbl:SetJustifyH("LEFT")
            cb.lbl = lbl

            cb:SetScript("OnClick", function(self)
                if self.charName then
                    local includeNow = self:GetChecked() and true or false
                    NS.Roster:SetWaveExcluded(self.charName, not includeNow)
                    WT:RefreshManageAltsPopup()
                    WT:RefreshUI()
                    WT:RefreshQuestieDock()
                    if NS.Onboarding and NS.Onboarding.RefreshIfShown then
                        NS.Onboarding:RefreshIfShown()
                    end
                end
            end)

            mf.rows[i] = cb
        end

        local prevBtn = CreateFrame("Button", nil, mf, "UIPanelButtonTemplate")
        prevBtn:SetSize(64, 22)
        prevBtn:SetPoint("BOTTOMLEFT", 14, 12)
        prevBtn:SetText("< Prev")
        prevBtn:SetScript("OnClick", function()
            if WT.managePage > 1 then
                WT.managePage = WT.managePage - 1
                WT:RefreshManageAltsPopup()
            end
        end)
        mf.prevBtn = prevBtn

        local nextBtn = CreateFrame("Button", nil, mf, "UIPanelButtonTemplate")
        nextBtn:SetSize(64, 22)
        nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0)
        nextBtn:SetText("Next >")
        nextBtn:SetScript("OnClick", function()
            local total = #NS.Roster:GetSortedVerifiedList()
            local maxPage = math.max(1, math.ceil(total / 9))
            if WT.managePage < maxPage then
                WT.managePage = WT.managePage + 1
                WT:RefreshManageAltsPopup()
            end
        end)
        mf.nextBtn = nextBtn

        local pageTxt = mf:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        pageTxt:SetPoint("LEFT", nextBtn, "RIGHT", 10, 0)
        mf.pageTxt = pageTxt

        local doneBtn = CreateFrame("Button", nil, mf, "UIPanelButtonTemplate")
        doneBtn:SetSize(74, 22)
        doneBtn:SetPoint("BOTTOMRIGHT", -14, 12)
        doneBtn:SetText("Done")
        doneBtn:SetScript("OnClick", function() mf:Hide() end)

        WT.manageFrame = mf
    end

    WT:RefreshManageAltsPopup()
    WT.manageFrame:Show()
    WT.manageFrame:Raise()
end

function WT:RefreshManageAltsPopup()
    local mf = WT.manageFrame
    if not mf then return end
    local list = NS.Roster:GetSortedVerifiedList()
    local perPage = 9
    local totalPages = math.max(1, math.ceil(#list / perPage))
    if WT.managePage > totalPages then WT.managePage = totalPages end
    if WT.managePage < 1 then WT.managePage = 1 end

    for i = 1, perPage do
        local cb = mf.rows[i]
        local idx = ((WT.managePage - 1) * perPage) + i
        local info = list[idx]
        if info then
            local included = NS.Roster:IsIncludedInWave(info)
            cb.charName = info.name
            cb:SetChecked(included)
            local statusColor = included and "|cff00ff00" or "|cff888888"
            local srcTag = info.source or "scan"
            cb.lbl:SetText(string.format("%s%s|r  [Lv%d %s | via %s]",
                statusColor, info.name, tonumber(info.level) or 0, info.class or "?", srcTag))
            cb:Show()
        else
            cb.charName = nil
            cb:Hide()
        end
    end

    if WT.managePage > 1 then mf.prevBtn:Enable() else mf.prevBtn:Disable() end
    if WT.managePage < totalPages then mf.nextBtn:Enable() else mf.nextBtn:Disable() end
    mf.pageTxt:SetText(string.format("Page %d/%d (%d alts)", WT.managePage, totalPages, #list))
end


-- ==========================================
-- SELF-SUFFICIENT WAVE INTENT WIZARD & WAVE PROCESS POP-UP
-- ==========================================
WT.INTENTS = {
    { id = "economy",    label = "Self-Sustaining Economy", desc = "Wave 1 prioritizes Gatherers, Tailor (Bags) & Enchanter to feed all later waves." },
    { id = "raidpvp",    label = "Main + Endgame Raid/PvP", desc = "Wave 1 pushes your top 1-2 highest level mains; Waves 2-3 group support alts." },
    { id = "allclass",   label = "All-Class Legacy Rotation", desc = "Spreads unique classes across waves to unlock 27 Class Legacy Points (Lv 25/45/60)." },
    { id = "goldhub",    label = "Gold & AH Hub Focus",     desc = "Keeps Bank/AH alt parked at hub while prioritizing farming & crafting alts first." },
}

function WT:AutoMapWavesByIntent(intentId)
    local ws = NS:GetWaveState()
    ws.intent = intentId or ws.intent or "economy"
    ws.waveAssignments = {}
    local list = NS.Roster:GetOwnLevelingRoster()

    table.sort(list, function(a, b)
        local la, lb = tonumber(a.level) or 0, tonumber(b.level) or 0
        if ws.intent == "economy" then
            local aEcon = (a.professions and (a.professions.Tailoring or a.professions.Enchanting or a.professions.Herbalism)) and 1 or 0
            local bEcon = (b.professions and (b.professions.Tailoring or b.professions.Enchanting or b.professions.Herbalism)) and 1 or 0
            if aEcon ~= bEcon then return aEcon > bEcon end
        end
        if la ~= lb then return la > lb end
        return string.lower(a.name or "") < string.lower(b.name or "")
    end)

    for idx, info in ipairs(list) do
        local cKey = C.CanonicalCharKey(info.name)
        local waveNum = math.min(3, math.ceil(idx / 4))
        if ws.intent == "raidpvp" and idx <= 2 then waveNum = 1 end
        ws.waveAssignments[cKey] = waveNum
    end
    ws.wizardCompleted = true
end

function WT:OpenWaveWizard()
    if not WT.wizardFrame then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local wf = CreateFrame("Frame", "WOWEngineWaveWizardFrame", UIParent, template)
        wf:SetSize(490, 390)
        wf:SetPoint("CENTER", UIParent, "CENTER", 30, 15)
        wf:SetFrameStrata("DIALOG")
        wf:SetFrameLevel(148)
        wf:SetMovable(true)
        wf:EnableMouse(true)
        wf:RegisterForDrag("LeftButton")
        wf:SetScript("OnDragStart", function(self) self:StartMoving() end)
        wf:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        ApplyBlueGoldBackdrop(wf, 0.98)

        if UISpecialFrames then table.insert(UISpecialFrames, "WOWEngineWaveWizardFrame") end

        local title = wf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetText("|cff00aeffWOWEngine|r |cffffd100Leveling Intent & Wave Map Wizard|r")

        local closeBtn = CreateFrame("Button", nil, wf, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() wf:Hide() end)

        local q1 = wf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        q1:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
        q1:SetText("|cffffd1001. Choose Roster Intent (auto-maps your alts into WoW Forever Legacy Waves):|r")

        wf.intentBtns = {}
        for i, intent in ipairs(WT.INTENTS) do
            local b = CreateFrame("Button", nil, wf, "UIPanelButtonTemplate")
            b:SetSize(222, 22)
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            b:SetPoint("TOPLEFT", 14 + col * 234, -58 - row * 26)
            b:SetText(intent.label)
            b:SetScript("OnClick", function()
                WT:AutoMapWavesByIntent(intent.id)
                WT:RefreshWaveWizard()
                WT:RefreshUI()
            end)
            wf.intentBtns[i] = { btn = b, data = intent }
        end

        local descTxt = wf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        descTxt:SetPoint("TOPLEFT", 14, -114)
        descTxt:SetWidth(460)
        descTxt:SetJustifyH("LEFT")
        wf.descTxt = descTxt

        local q2 = wf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        q2:SetPoint("TOPLEFT", 14, -144)
        q2:SetText("|cffffd1002. Wave Map (click W1/W2/W3 to reassign any character):|r")

        wf.altRows = {}
        for i = 1, 8 do
            local rowY = -166 - (i - 1) * 22
            local nameTxt = wf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameTxt:SetPoint("TOPLEFT", 16, rowY - 4)
            nameTxt:SetWidth(330)
            nameTxt:SetJustifyH("LEFT")

            local wBtn = CreateFrame("Button", nil, wf, "UIPanelButtonTemplate")
            wBtn:SetSize(92, 20)
            wBtn:SetPoint("TOPRIGHT", -14, rowY)
            wBtn:SetScript("OnClick", function(self)
                if not self.cKey then return end
                local ws = NS:GetWaveState()
                ws.waveAssignments = ws.waveAssignments or {}
                local cur = tonumber(ws.waveAssignments[self.cKey]) or 1
                ws.waveAssignments[self.cKey] = (cur % 3) + 1
                WT:RefreshWaveWizard()
                WT:RefreshUI()
            end)
            wf.altRows[i] = { nameTxt = nameTxt, wBtn = wBtn }
        end

        local bProcess = CreateFrame("Button", nil, wf, "UIPanelButtonTemplate")
        bProcess:SetSize(165, 24)
        bProcess:SetPoint("BOTTOMLEFT", 14, 12)
        bProcess:SetText("Open Wave Process Guide")
        bProcess:SetScript("OnClick", function() WT:ShowWaveProcessPopup() end)

        local bDone = CreateFrame("Button", nil, wf, "UIPanelButtonTemplate")
        bDone:SetSize(120, 24)
        bDone:SetPoint("BOTTOMRIGHT", -14, 12)
        bDone:SetText("Confirm Wave Map")
        bDone:SetScript("OnClick", function()
            local ws = NS:GetWaveState()
            ws.wizardCompleted = true
            wf:Hide()
            WT:RefreshUI()
            WT:RefreshQuestieDock()
        end)

        WT.wizardFrame = wf
    end

    local ws = NS:GetWaveState()
    if not ws.wizardCompleted then
        WT:AutoMapWavesByIntent(ws.intent or "economy")
    end
    WT:RefreshWaveWizard()
    WT.wizardFrame:Show()
    WT.wizardFrame:Raise()
end

function WT:RefreshWaveWizard()
    local wf = WT.wizardFrame
    if not wf then return end
    local ws = NS:GetWaveState()
    local activeIntent = ws.intent or "economy"
    for _, item in ipairs(wf.intentBtns) do
        if item.data.id == activeIntent then
            wf.descTxt:SetText("|cff00ff00Selected Intent:|r " .. item.data.desc)
        end
    end

    local list = NS.Roster:GetOwnLevelingRoster()
    for i = 1, 8 do
        local row = wf.altRows[i]
        local info = list[i]
        if info then
            local cKey = C.CanonicalCharKey(info.name)
            local wNum = (ws.waveAssignments and ws.waveAssignments[cKey]) or 1
            row.nameTxt:SetText(string.format("|cffffd100%s|r (Lv%d %s)", info.name, tonumber(info.level) or 0, info.class or "?"))
            row.wBtn.cKey = cKey
            row.wBtn:SetText("Wave " .. tostring(wNum))
            row.nameTxt:Show()
            row.wBtn:Show()
        else
            row.nameTxt:Hide()
            row.wBtn:Hide()
        end
    end
end

function WT:ShowWaveProcessPopup()
    if not WT.processFrame then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local pf = CreateFrame("Frame", "WOWEngineWaveProcessFrame", UIParent, template)
        pf:SetSize(460, 290)
        pf:SetPoint("CENTER", UIParent, "CENTER", -40, 20)
        pf:SetFrameStrata("DIALOG")
        pf:SetFrameLevel(152)
        pf:SetMovable(true)
        pf:EnableMouse(true)
        pf:RegisterForDrag("LeftButton")
        pf:SetScript("OnDragStart", function(self) self:StartMoving() end)
        pf:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        ApplyBlueGoldBackdrop(pf, 0.98)

        if UISpecialFrames then table.insert(UISpecialFrames, "WOWEngineWaveProcessFrame") end

        local title = pf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetText("|cff00aeffWOWEngine|r |cffffd100WoW Forever Wave Process Guide|r")

        local closeBtn = CreateFrame("Button", nil, pf, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() pf:Hide() end)

        local body = pf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
        body:SetWidth(430)
        body:SetJustifyH("LEFT")
        pf.body = body

        local closeFoot = CreateFrame("Button", nil, pf, "UIPanelButtonTemplate")
        closeFoot:SetSize(84, 22)
        closeFoot:SetPoint("BOTTOMRIGHT", -14, 12)
        closeFoot:SetText("Got It")
        closeFoot:SetScript("OnClick", function() pf:Hide() end)

        WT.processFrame = pf
    end

    local waveIdx, targetLevel = WT:GetCurrentWaveInfo()
    local pLevel = UnitLevel("player") or 1
    local nextStep = math.min(60, (math.floor(pLevel / 5) + 1) * 5)

    WT.processFrame.body:SetText(string.format(
        "|cffffd100Current Character:|r %s (Lv%d)   |   |cff00ff00Active Wave %d (Gate Lv%d)|r\n" ..
        "|cffffd100Next 5-Level Checkpoint:|r Lv %d\n\n" ..
        "|cff00aeffWoW Forever Wave & Legacy Process:|r\n" ..
        "1. |cffffd100Lv 1 -> 5:|r Clear starter zone, mail starter bags, learn 2 Primary Profs + Sub-Profs.\n" ..
        "2. |cffffd100Lv 5 -> 25 (Wave 1 Gate):|r Hit Lv 25 for Class Legacy Point (+1), train Crafting to 150 (+1), and finish Novice Spelunker dungeons (RFC, WC, Deadmines, SFK, Ruins of Lordaeron, Excavation Site) before outleveling!\n" ..
        "3. |cffffd100Lv 26 -> 45 (Wave 2 Gate):|r Buy Mount at Lv 40, hit Lv 45 for Class Legacy Point (+1), raise Crafting to 225 (+1), and finish Experienced Spelunker dungeons.\n" ..
        "4. |cffffd100Lv 46 -> 60 (Wave 3 Cap):|r Hit Lv 60 (+1), Crafting 300 (+1), Master Spelunker dungeons, and Onyxia / Barrow Deeps / Hyjal Summit raids.",
        C.GetPlayerName() or "Player", pLevel, waveIdx, targetLevel, nextStep
    ))
    WT.processFrame:Show()
    WT.processFrame:Raise()
end
