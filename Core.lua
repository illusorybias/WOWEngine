local addonName, NS = ...
_G.WOWEngine = NS

NS.Version = "1.6.0"
NS.Brand = "IllusoryBias"
NS.Modules = {}

-- Clean 6-row core routing categories (matches the simple v1.3.5 layout)
NS.CATEGORIES = {
    { key = "Herb",       label = "Herbs / Alchemy" },
    { key = "Enchanting", label = "Enchanting Mats" },
    { key = "Ore",        label = "Ore / Stone / Bars" },
    { key = "Leather",    label = "Leather / Hides" },
    { key = "Cloth",      label = "Cloth / Tailoring" },
    { key = "DisenchantBoE", label = "AH / Disenchantable BoEs" },
    { key = "BankAlt",       label = "BoEs / Bank Vault" },
}

local LEGACY_PLACEHOLDERS = {
    ["illusorybias mageherbench"] = true,
    ["illusorybias warmineng"] = true,
    ["illusorybias rogueleathskin"] = true,
    ["illusorybias priesttailench"] = true,
    ["illusorybias bankvault"] = true,
}

local CLASS_SHORT = {
    ["WARRIOR"] = "war", ["PALADIN"] = "pal", ["HUNTER"] = "hunt",
    ["ROGUE"] = "rog", ["PRIEST"] = "pri", ["DEATHKNIGHT"] = "dk",
    ["SHAMAN"] = "sha", ["MAGE"] = "mage", ["WARLOCK"] = "lock",
    ["MONK"] = "monk", ["DRUID"] = "dru", ["DEMONHUNTER"] = "dh",
    ["EVOKER"] = "evo",
}

local PROF_SHORT = {
    ["Herbalism"] = "herb", ["Alchemy"] = "alch", ["Enchanting"] = "ench",
    ["Mining"] = "min", ["Blacksmithing"] = "bs", ["Engineering"] = "eng",
    ["Jewelcrafting"] = "jc", ["Leatherworking"] = "lw", ["Skinning"] = "skin",
    ["Tailoring"] = "tail", ["Inscription"] = "insc",
}

function NS:SuggestDerivativeName(classToken, prof1, prof2)
    local base = (WOWEngineDB and WOWEngineDB.brandHandle) or "Illusorybias"
    local c = CLASS_SHORT[string.upper(classToken or "")] or string.lower(string.sub(classToken or "alt", 1, 4))
    local p1 = PROF_SHORT[prof1 or ""] or ""
    local p2 = PROF_SHORT[prof2 or ""] or ""
    local suffix = c .. p1 .. p2
    if suffix == "" then suffix = "alt" end
    return base .. " " .. suffix
end

function NS:RegisterModule(modName, modData)
    NS.Modules[modName] = modData
end

-- Unified Faction Profile (replaces separate HordeEngine & AllianceEngine addons)
function NS:GetFactionProfile()
    local _, faction = NS:GetContextKeys()
    if faction == "Horde" then
        return {
            faction = "Horde",
            suiteName = "Horde 4-Wave Suite",
            plan = "18-Character / 27-Tree / 4-Wave Horde",
            defaultWaves = {
                { wave = 1, name = "Wave 1 (Starter & Hubs)",   targetLevel = 20 },
                { wave = 2, name = "Wave 2 (Mount & Mid-Zone)", targetLevel = 40 },
                { wave = 3, name = "Wave 3 (Pre-Endgame)",      targetLevel = 50 },
                { wave = 4, name = "Wave 4 (Max Level Cap)",    targetLevel = 60 },
            },
        }
    elseif faction == "Alliance" then
        return {
            faction = "Alliance",
            suiteName = "Alliance Zero-Duplicate Suite",
            plan = "26-Race / 13-Class Zero-Duplicate Alliance",
            defaultWaves = {
                { wave = 1, name = "Wave 1 (Starter & Hubs)",   targetLevel = 20 },
                { wave = 2, name = "Wave 2 (Mount & Mid-Zone)", targetLevel = 40 },
                { wave = 3, name = "Wave 3 (Pre-Endgame)",      targetLevel = 50 },
                { wave = 4, name = "Wave 4 (Max Level Cap)",    targetLevel = 60 },
            },
        }
    end
    return {
        faction = faction or "Neutral",
        suiteName = "Neutral Core Suite",
        plan = "Multi-Version Roster",
        defaultWaves = {
            { wave = 1, name = "Wave 1", targetLevel = 20 },
            { wave = 2, name = "Wave 2", targetLevel = 40 },
            { wave = 3, name = "Wave 3", targetLevel = 50 },
            { wave = 4, name = "Wave 4", targetLevel = 60 },
        },
    }
end


local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

function NS:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00aeff[WOWEngine]|r " .. tostring(msg))
end

function NS:GetContextKeys()
    local realm = NS.Compat.SafeStr(GetRealmName()) or "UnknownRealm"
    local faction = NS.Compat.SafeStr(UnitFactionGroup("player")) or "Neutral"
    return realm, faction
end

function NS:NormalizeRuleList(val)
    local out = {}
    local seen = {}
    local function addOne(raw)
        if type(raw) ~= "string" then return end
        local clean = NS.Compat.StripLocalRealm(raw)
        if not clean or clean == "" then return end
        local low = string.lower(clean)
        if LEGACY_PLACEHOLDERS[low] then return end
        if not seen[low] then
            seen[low] = true
            table.insert(out, clean)
        end
    end

    if type(val) == "string" then
        addOne(val)
    elseif type(val) == "table" then
        for _, v in ipairs(val) do
            addOne(v)
        end
    end
    return out
end

local migratedContexts = {}

function NS:EnsureDB()
    WOWEngineDB = WOWEngineDB or {}
    WOWEngineDB.roster = WOWEngineDB.roster or {}
    WOWEngineDB.rulesByRealm = WOWEngineDB.rulesByRealm or {}
    WOWEngineDB.customRulesByRealm = WOWEngineDB.customRulesByRealm or {}
    WOWEngineDB.manualCatsByRealm = WOWEngineDB.manualCatsByRealm or {}
    WOWEngineDB.rrCursorByRealm = WOWEngineDB.rrCursorByRealm or {}
    WOWEngineDB.goldLedger = WOWEngineDB.goldLedger or {}
    WOWEngineDB.waveByRealm = WOWEngineDB.waveByRealm or {}
    WOWEngineDB.charPlansByRealm = WOWEngineDB.charPlansByRealm or {}
    WOWEngineDB.selectedSpecs = WOWEngineDB.selectedSpecs or {}
    WOWEngineDB.learnedRecipesByChar = WOWEngineDB.learnedRecipesByChar or {}
    if WOWEngineDB.vendorRecipeAlertEnabled == nil then WOWEngineDB.vendorRecipeAlertEnabled = true end
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
    if type(WOWEngineDB.pointNag) ~= "table" then
        WOWEngineDB.pointNag = {
            bannerMutedUntil = 0,
            bannerPermOff = false,
            chatMuted = false,
            byChar = {},
        }
    end
    WOWEngineDB.brandHandle = WOWEngineDB.brandHandle or "Illusorybias"
    WOWEngineDB.bugReportUrl = WOWEngineDB.bugReportUrl or "https://github.com/IllusoryBias/WOWEngine/issues/new?template=bug_report.yml"

    if WOWEngineDB.minimapAngle == nil then WOWEngineDB.minimapAngle = 215 end
    if WOWEngineDB.minimapHide == nil then WOWEngineDB.minimapHide = false end
    if WOWEngineDB.minimapLock == nil then WOWEngineDB.minimapLock = false end
    if WOWEngineDB.protectMastercraftQueue == nil then WOWEngineDB.protectMastercraftQueue = true end
    if WOWEngineDB.protectAuctionatorPosted == nil then WOWEngineDB.protectAuctionatorPosted = true end
    if WOWEngineDB.syncAltoholic == nil then WOWEngineDB.syncAltoholic = true end
    if WOWEngineDB.onboardingCompleted == nil then WOWEngineDB.onboardingCompleted = false end
    if WOWEngineDB.multiAltMode == nil then WOWEngineDB.multiAltMode = "roundrobin" end
    if WOWEngineDB.mastercraftPriority == nil then WOWEngineDB.mastercraftPriority = "leveling" end
    if WOWEngineDB.keepOwnCategoryMats == nil then WOWEngineDB.keepOwnCategoryMats = true end

    WOWEngineDB.routingRules = nil

    local realm, faction = NS:GetContextKeys()
    WOWEngineDB.roster[realm] = WOWEngineDB.roster[realm] or {}
    WOWEngineDB.roster[realm][faction] = WOWEngineDB.roster[realm][faction] or {}

    WOWEngineDB.rulesByRealm[realm] = WOWEngineDB.rulesByRealm[realm] or {}
    WOWEngineDB.rulesByRealm[realm][faction] = WOWEngineDB.rulesByRealm[realm][faction] or {}

    WOWEngineDB.customRulesByRealm[realm] = WOWEngineDB.customRulesByRealm[realm] or {}
    WOWEngineDB.customRulesByRealm[realm][faction] = WOWEngineDB.customRulesByRealm[realm][faction] or {}

    WOWEngineDB.manualCatsByRealm[realm] = WOWEngineDB.manualCatsByRealm[realm] or {}
    WOWEngineDB.manualCatsByRealm[realm][faction] = WOWEngineDB.manualCatsByRealm[realm][faction] or {}

    WOWEngineDB.rrCursorByRealm[realm] = WOWEngineDB.rrCursorByRealm[realm] or {}
    WOWEngineDB.rrCursorByRealm[realm][faction] = WOWEngineDB.rrCursorByRealm[realm][faction] or {}

    WOWEngineDB.charPlansByRealm[realm] = WOWEngineDB.charPlansByRealm[realm] or {}
    WOWEngineDB.charPlansByRealm[realm][faction] = WOWEngineDB.charPlansByRealm[realm][faction] or {}

    WOWEngineDB.waveByRealm[realm] = WOWEngineDB.waveByRealm[realm] or {}
    if not WOWEngineDB.waveByRealm[realm][faction] then
        WOWEngineDB.waveByRealm[realm][faction] = {
            currentWave = 1,
            gates = { 25, 45, 60 },
            snoozedUntilByChar = {},
            completedChecklist = {},
            autoPromptEnabled = true,
            includeAltoholicInWave = false,
            dockQuestieHeader = true,
            questieHeaderCollapsed = false,
        }
    end
    local ws = WOWEngineDB.waveByRealm[realm][faction]
    if ws.includeAltoholicInWave == nil then ws.includeAltoholicInWave = false end
    if ws.dockQuestieHeader == nil then ws.dockQuestieHeader = true end
    if ws.questieHeaderCollapsed == nil then ws.questieHeaderCollapsed = false end
    if ws.intent == nil then ws.intent = "economy" end
    if ws.waveAssignments == nil then ws.waveAssignments = {} end
    if ws.wizardCompleted == nil then ws.wizardCompleted = false end
    if not ws.gates or #ws.gates == 4 then ws.gates = { 25, 45, 60 } end

    -- Run one-time migration per realm/faction context (never mutates active tables mid-write!)
    local ctxKey = realm .. "|" .. faction
    if not migratedContexts[ctxKey] then
        migratedContexts[ctxKey] = true
        local scopedRules = WOWEngineDB.rulesByRealm[realm][faction]
        if scopedRules["Metal & Stone"] then
            local msList = NS:NormalizeRuleList(scopedRules["Metal & Stone"])
            local oreList = NS:NormalizeRuleList(scopedRules["Ore"])
            for _, n in ipairs(msList) do table.insert(oreList, n) end
            scopedRules["Ore"] = NS:NormalizeRuleList(oreList)
            scopedRules["Metal & Stone"] = nil
        end
        for cat, val in pairs(scopedRules) do
            local list = NS:NormalizeRuleList(val)
            if #list > 0 then
                scopedRules[cat] = list
            else
                scopedRules[cat] = nil
            end
        end
    end
end

function NS:GetActiveRoster()
    NS:EnsureDB()
    local realm, faction = NS:GetContextKeys()
    return WOWEngineDB.roster[realm][faction]
end

function NS:GetActiveRules()
    NS:EnsureDB()
    local realm, faction = NS:GetContextKeys()
    return WOWEngineDB.rulesByRealm[realm][faction]
end

-- Custom per-character item/keyword additions: { { keyword = "Silk", target = "AltName" }, ... }
function NS:GetCustomRules()
    NS:EnsureDB()
    local realm, faction = NS:GetContextKeys()
    return WOWEngineDB.customRulesByRealm[realm][faction]
end

function NS:GetManualFlags()
    NS:EnsureDB()
    local realm, faction = NS:GetContextKeys()
    return WOWEngineDB.manualCatsByRealm[realm][faction]
end

function NS:GetRRCursors()
    NS:EnsureDB()
    local realm, faction = NS:GetContextKeys()
    return WOWEngineDB.rrCursorByRealm[realm][faction]
end

function NS:GetWaveState()
    NS:EnsureDB()
    local realm, faction = NS:GetContextKeys()
    return WOWEngineDB.waveByRealm[realm][faction]
end

function NS:GetCharPlans()
    NS:EnsureDB()
    local realm, faction = NS:GetContextKeys()
    return WOWEngineDB.charPlansByRealm[realm][faction]
end

function NS:UpdateGoldLedger()
    NS:EnsureDB()
    local name = NS.Compat.GetPlayerName()
    if not name then return end
    local realm, faction = NS:GetContextKeys()
    local key = name .. " - " .. realm
    WOWEngineDB.goldLedger[key] = {
        copper = GetMoney() or 0,
        faction = faction,
        class = select(2, UnitClass("player")) or "UNKNOWN",
        updated = time(),
    }
end

local function SafeShowOnboarding(stepNum)
    if NS.Onboarding and NS.Onboarding.Show then
        local ok, err = pcall(function()
            NS.Onboarding:Show(stepNum or 1)
        end)
        if not ok then
            NS:Print("|cffff4444Failed to open Setup Wizard:|r " .. tostring(err))
        end
    else
        NS:Print("|cffff4444Setup Wizard module failed to load.|r Run /console scriptErrors 1 and /reload.")
    end
end


-- Check optimal companion addons (Altoholic, Mastercraft, Questie, Auctionator)
function NS:GetCompanionAddonStatus()
    local C = NS.Compat
    local hasAlto = C and C.IsAltoholicAvailable and C.IsAltoholicAvailable() or false
    local hasMC = C and C.IsMastercraftAvailable and C.IsMastercraftAvailable() or false
    local hasQuestie = (NS.WaveTracker and NS.WaveTracker.IsQuestieLoaded and NS.WaveTracker:IsQuestieLoaded())
        or (_G.Questie ~= nil) or (_G.QuestieLoader ~= nil) or (C and C.IsAddOnLoaded and C.IsAddOnLoaded("Questie")) or false
    local hasAuc = C and C.IsAuctionatorAvailable and C.IsAuctionatorAvailable() or false
    local missing = {}
    if not hasAlto then table.insert(missing, "Altoholic (+ DataStore)") end
    if not hasMC then table.insert(missing, "Mastercraft") end
    if not hasQuestie then table.insert(missing, "Questie") end
    if not hasAuc then table.insert(missing, "Auctionator") end
    return hasAlto, hasMC, hasQuestie, hasAuc, missing
end

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        NS:EnsureDB()
        local ver, _, _, iface = GetBuildInfo()
        local fp = NS:GetFactionProfile()
        NS:Print("v" .. NS.Version .. " Unified (" .. NS.Brand .. " | " .. fp.suiteName .. " | Client " .. tostring(ver) .. " / Interface " .. tostring(iface) .. "). Type |cffffd100/he setup|r or |cffffd100/he wave|r.")
    elseif event == "PLAYER_LOGIN" then
        NS:EnsureDB()
        if NS.Roster and NS.Roster.ScanAll then
            pcall(function() NS.Roster:ScanAll(true) end)
        end
        if NS.InitMinimapButton then
            local okMM, errMM = pcall(function() NS:InitMinimapButton() end)
            if not okMM then
                NS:Print("|cffff4444Minimap button error:|r " .. tostring(errMM))
            end
        end
        NS:UpdateGoldLedger()
        if NS.WaveTracker and NS.WaveTracker.OnLogin then
            pcall(function() NS.WaveTracker:OnLogin() end)
        end
        local _, _, _, _, missingAddons = NS:GetCompanionAddonStatus()
        if #missingAddons > 0 then
            NS:Print("|cffff9900Optimal Setup Notice:|r Missing " .. table.concat(missingAddons, ", ") .. ". Some features are limited — open |cffffd100/he setup|r (Step 4) or |cffffd100Options -> AddOns -> WOWEngine|r for details.")
        end
        if not (WOWEngineDB.userPlan and WOWEngineDB.userPlan.completed) and NS.PlanBuilder and NS.PlanBuilder.Show then
            if C_Timer and C_Timer.After then
                C_Timer.After(1.0, function()
                    if not (WOWEngineDB.userPlan and WOWEngineDB.userPlan.completed) and NS.PlanBuilder and NS.PlanBuilder.Show then
                        pcall(function() NS.PlanBuilder:Show() end)
                    end
                end)
            else
                pcall(function() NS.PlanBuilder:Show() end)
            end
        elseif not WOWEngineDB.onboardingCompleted then
            if C_Timer and C_Timer.After then
                C_Timer.After(1.0, function()
                    if not WOWEngineDB.onboardingCompleted then
                        SafeShowOnboarding(1)
                    end
                end)
            else
                SafeShowOnboarding(1)
            end
        end
    elseif event == "PLAYER_MONEY" or event == "PLAYER_ENTERING_WORLD" then
        NS:UpdateGoldLedger()
        if NS.WaveTracker and NS.WaveTracker.OnLogin then
            pcall(function() NS.WaveTracker:OnLogin() end)
        end
    end
end)
