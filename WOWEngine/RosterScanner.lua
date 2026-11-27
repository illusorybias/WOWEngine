local addonName, NS = ...
NS.Roster = {}
local R = NS.Roster
local C = NS.Compat

local PROF_TO_CATEGORIES = {
    ["Herbalism"] = { "Herb" },
    ["Alchemy"] = { "Herb" },
    ["Inscription"] = { "Herb" },
    ["Enchanting"] = { "Enchanting" },
    ["Mining"] = { "Ore" },
    ["Blacksmithing"] = { "Ore" },
    ["Engineering"] = { "Ore" },
    ["Jewelcrafting"] = { "Ore" },
    ["Leatherworking"] = { "Leather" },
    ["Skinning"] = { "Leather" },
    ["Tailoring"] = { "Cloth" },
}

local function InferCategoriesFromVerifiedName(charName)
    local cats = {}
    if not charName then return cats end
    local n = string.lower(charName)

    if string.find(n, "herb") or string.find(n, "alch") or string.find(n, "insc") then
        table.insert(cats, "Herb")
    end
    if string.find(n, "ench") then
        table.insert(cats, "Enchanting")
    end
    if string.find(n, "min") or string.find(n, "eng") or string.find(n, "bs") or string.find(n, "smith") or string.find(n, "jc") or string.find(n, "jewel") then
        table.insert(cats, "Ore")
    end
    if string.find(n, "leath") or string.find(n, "skin") or string.find(n, "lw") then
        table.insert(cats, "Leather")
    end
    if string.find(n, "tail") or string.find(n, "cloth") then
        table.insert(cats, "Cloth")
    end
    if string.find(n, "bank") or string.find(n, "vault") or string.find(n, "mule") or string.find(n, "ah") then
        table.insert(cats, "BankAlt")
    end
    return cats
end

function R:GetCategoryTargets(catKey)
    local rules = NS:GetActiveRules()
    local val = rules[catKey]
    if type(val) == "table" then
        return val
    elseif type(val) == "string" and val ~= "" then
        rules[catKey] = { val }
        return rules[catKey]
    end
    return {}
end

function R:HasTargetInCategory(catKey, charName)
    local list = R:GetCategoryTargets(catKey)
    for _, existing in ipairs(list) do
        if C.IsSameCharacter(existing, charName) then
            return true
        end
    end
    return false
end

function R:AddTargetToCategory(catKey, charName, isManual)
    local exact = R:FindVerifiedName(charName)
    if not exact then return false, "unverified" end

    local alreadyExists = R:HasTargetInCategory(catKey, exact)
    local rules = NS:GetActiveRules()
    local list = rules[catKey]
    if type(list) ~= "table" then
        list = {}
        rules[catKey] = list
    end
    if not alreadyExists then
        table.insert(list, exact)
    end
    if isManual then
        local manual = NS:GetManualFlags()
        manual[catKey] = true
    end
    return true, exact
end

function R:SetPrimaryTarget(catKey, charName)
    local exact = R:FindVerifiedName(charName)
    if not exact then return false, "unverified" end

    local rules = NS:GetActiveRules()
    local existing = R:GetCategoryTargets(catKey)
    local newList = { exact }
    for i = 2, #existing do
        if not C.IsSameCharacter(existing[i], exact) then
            table.insert(newList, existing[i])
        end
    end
    rules[catKey] = newList
    local manual = NS:GetManualFlags()
    manual[catKey] = true
    return true, exact
end

function R:RemoveTargetFromCategory(catKey, charName, isManual)
    local rules = NS:GetActiveRules()
    local list = rules[catKey]
    if type(list) ~= "table" then return false end

    local newList = {}
    local removed = false
    for _, existing in ipairs(list) do
        if C.IsSameCharacter(existing, charName) then
            removed = true
        else
            table.insert(newList, existing)
        end
    end

    if #newList > 0 then
        rules[catKey] = newList
    else
        rules[catKey] = nil
    end

    if isManual then
        local manual = NS:GetManualFlags()
        manual[catKey] = true
    end
    return removed
end

function R:ClearCategory(catKey)
    local rules = NS:GetActiveRules()
    rules[catKey] = nil
    local manual = NS:GetManualFlags()
    manual[catKey] = true
end

-- Custom per-character item/keyword routing additions (supports itemID + clean item name/keyword)
function R:AddCustomRule(keyword, charName, itemID)
    local kw = C.ExtractItemName(keyword)
    if not kw or kw == "" then return false, "empty keyword" end
    local exact = R:FindVerifiedName(charName)
    if not exact then return false, "unverified character" end

    local custom = NS:GetCustomRules()
    local kwLow = string.lower(kw)
    for _, entry in ipairs(custom) do
        local existingKw = string.lower(C.ExtractItemName(entry.keyword) or "")
        if existingKw == kwLow and C.IsSameCharacter(entry.target, exact) then
            if itemID and not entry.itemID then
                entry.itemID = tonumber(itemID)
            end
            return true, exact, kw
        end
    end
    table.insert(custom, { keyword = kw, target = exact, itemID = tonumber(itemID) })
    return true, exact, kw
end

function R:RemoveCustomRuleByIndex(idx)
    local custom = NS:GetCustomRules()
    if idx and custom[idx] then
        table.remove(custom, idx)
        return true
    end
    return false
end

function R:FindCustomTargetsForItem(itemName, itemID)
    local cleanName = C.ExtractItemName(itemName)
    local lowName = cleanName and string.lower(cleanName) or nil
    local numID = tonumber(itemID)
    if not lowName and not numID then return {}, false, nil end

    local custom = NS:GetCustomRules()
    local eligible = {}
    local isSelfAssigned = false
    local seen = {}
    local matchedKeyword = nil

    for _, entry in ipairs(custom) do
        local matched = false
        if numID and entry.itemID and tonumber(entry.itemID) == numID then
            matched = true
        end
        if not matched and lowName then
            local kw = C.ExtractItemName(entry.keyword)
            if kw and kw ~= "" and string.find(lowName, string.lower(kw), 1, true) then
                matched = true
            end
        end

        if matched then
            matchedKeyword = matchedKeyword or entry.keyword
            local exact = R:FindVerifiedName(entry.target) or C.StripLocalRealm(entry.target)
            if exact then
                if C.IsCurrentPlayer(exact) then
                    isSelfAssigned = true
                else
                    local k = C.CanonicalCharKey(exact)
                    if k and not seen[k] then
                        seen[k] = true
                        table.insert(eligible, exact)
                    end
                end
            end
        end
    end

    if isSelfAssigned and WOWEngineDB and WOWEngineDB.keepOwnCategoryMats then
        return {}, true, matchedKeyword
    end
    return eligible, isSelfAssigned, matchedKeyword
end

function R:ScanCurrentPlayer()
    local roster = NS:GetActiveRoster()
    local name = C.GetPlayerName()
    if not name then return nil end

    local existing = roster[name] or {}
    local profs = C.GetPlayerProfessions()
    existing.name = name
    existing.level = UnitLevel("player") or existing.level or 1
    existing.class = select(2, UnitClass("player")) or existing.class or "UNKNOWN"
    existing.source = "login"
    existing.verified = true
    existing.lastSeen = time()
    existing.professions = profs
    roster[name] = existing
    return existing
end

function R:ScanAltoholic()
    if not (WOWEngineDB and WOWEngineDB.syncAltoholic) then return 0 end
    if not C.IsAltoholicAvailable() then return 0 end

    local realm, faction = NS:GetContextKeys()
    local roster = NS:GetActiveRoster()
    local dsChars = C.GetAltoholicCharacters(realm, faction)
    local imported = 0

    for _, ch in ipairs(dsChars) do
        local name = ch.name
        if name then
            local entry = roster[name]
            if not entry then
                roster[name] = {
                    name = name,
                    level = ch.level or 0,
                    class = ch.class or "UNKNOWN",
                    source = "altoholic",
                    verified = true,
                    lastSeen = time(),
                    professions = ch.professions or {},
                }
                imported = imported + 1
            else
                entry.verified = true
                if ch.level and ch.level > (entry.level or 0) then entry.level = ch.level end
                if ch.class and ch.class ~= "UNKNOWN" then entry.class = ch.class end
                if ch.professions and next(ch.professions) ~= nil then
                    entry.professions = entry.professions or {}
                    for pName, pRank in pairs(ch.professions) do
                        if not entry.professions[pName] then
                            entry.professions[pName] = pRank
                        end
                    end
                end
                if entry.source ~= "login" then
                    entry.source = "altoholic"
                end
                entry.lastSeen = time()
            end

            if ch.copper ~= nil then
                local ledgerKey = name .. " - " .. realm
                if not WOWEngineDB.goldLedger[ledgerKey] then
                    WOWEngineDB.goldLedger[ledgerKey] = {
                        copper = ch.copper,
                        faction = ch.faction or faction,
                        class = ch.class or "UNKNOWN",
                        updated = time(),
                    }
                end
            end
        end
    end

    return imported
end

function R:ScanGuildAndFriends()
    local roster = NS:GetActiveRoster()
    local added = 0

    C.RequestGuildScan()
    for _, m in ipairs(C.GetGuildMemberNames()) do
        local name = m.name
        if name then
            local entry = roster[name]
            if not entry then
                roster[name] = {
                    name = name,
                    level = m.level,
                    class = m.class,
                    source = "guild",
                    verified = true,
                    lastSeen = time(),
                    professions = {},
                }
                added = added + 1
            else
                entry.verified = true
                entry.level = (m.level and m.level > 0) and m.level or entry.level
                entry.lastSeen = time()
            end
        end
    end

    for _, fr in ipairs(C.GetFriendNames()) do
        local name = fr.name
        if name then
            local entry = roster[name]
            if not entry then
                roster[name] = {
                    name = name,
                    level = fr.level,
                    class = fr.class,
                    source = "friend",
                    verified = true,
                    lastSeen = time(),
                    professions = {},
                }
                added = added + 1
            else
                entry.verified = true
                entry.lastSeen = time()
            end
        end
    end

    return added
end

function R:AutoMapVerifiedRoutes(forceRebuild)
    local rules = NS:GetActiveRules()
    local manual = NS:GetManualFlags()

    if forceRebuild then
        for _, cat in ipairs(NS.CATEGORIES) do
            rules[cat.key] = nil
            manual[cat.key] = nil
        end
    else
        for cat, list in pairs(rules) do
            local cleaned = {}
            local seen = {}
            for _, target in ipairs(NS:NormalizeRuleList(list)) do
                local exact = R:FindVerifiedName(target)
                if exact and not seen[string.lower(exact)] then
                    seen[string.lower(exact)] = true
                    table.insert(cleaned, exact)
                end
            end
            rules[cat] = (#cleaned > 0) and cleaned or nil
        end
    end

    local sorted = R:GetSortedVerifiedList()
    for _, info in ipairs(sorted) do
        local exactName = info.name
        local matchedCats = {}

        if info.professions then
            for profName in pairs(info.professions) do
                local cats = PROF_TO_CATEGORIES[profName]
                if cats then
                    for _, catKey in ipairs(cats) do
                        matchedCats[catKey] = true
                    end
                end
            end
        end

        for _, catKey in ipairs(InferCategoriesFromVerifiedName(exactName)) do
            matchedCats[catKey] = true
        end

        for catKey in pairs(matchedCats) do
            if forceRebuild or not manual[catKey] then
                R:AddTargetToCategory(catKey, exactName, false)
            end
        end
    end
end

function R:FindVerifiedName(queryName)
    local key = C.CanonicalCharKey(queryName)
    if not key then return nil end
    local roster = NS:GetActiveRoster()

    for exactName, info in pairs(roster) do
        if info.verified and C.CanonicalCharKey(exactName) == key then
            return exactName
        end
    end
    return nil
end

function R:GetSortedVerifiedList()
    local roster = NS:GetActiveRoster()
    local list = {}
    for _, info in pairs(roster) do
        if info.verified then
            table.insert(list, info)
        end
    end
    table.sort(list, function(a, b)
        return string.lower(a.name or "") < string.lower(b.name or "")
    end)
    return list
end

function R:GetEligibleTargetsForCategory(category)
    if not category then return {}, false end
    local configured = R:GetCategoryTargets(category)
    local eligible = {}
    local isSelfAssigned = false
    local seen = {}

    for _, rawTarget in ipairs(configured) do
        local exact = R:FindVerifiedName(rawTarget)
        if exact then
            if C.IsCurrentPlayer(exact) then
                isSelfAssigned = true
            else
                local k = C.CanonicalCharKey(exact)
                if k and not seen[k] then
                    seen[k] = true
                    table.insert(eligible, exact)
                end
            end
        end
    end

    if isSelfAssigned and WOWEngineDB and WOWEngineDB.keepOwnCategoryMats then
        return {}, true
    end

    return eligible, isSelfAssigned
end

function R:GetVerifiedCount()
    local roster = NS:GetActiveRoster()
    local count = 0
    for _, info in pairs(roster) do
        if info.verified then count = count + 1 end
    end
    return count
end

function R:ScanAll(silent)
    R:ScanCurrentPlayer()
    R:ScanAltoholic()
    R:ScanGuildAndFriends()
    R:AutoMapVerifiedRoutes(false)
    if not silent then
        R:PrintRoster()
    end
    if NS.Onboarding and NS.Onboarding.RefreshIfShown then
        NS.Onboarding:RefreshIfShown()
    end
end

function R:PrintRoster()
    local realm, faction = NS:GetContextKeys()
    local list = R:GetSortedVerifiedList()
    local rules = NS:GetActiveRules()
    local custom = NS:GetCustomRules()

    NS:Print(string.format("=== Verified Characters (%s - %s) [%d found] ===", realm, faction, #list))
    for _, info in ipairs(list) do
        local profList = {}
        if info.professions then
            for p, rank in pairs(info.professions) do
                table.insert(profList, p .. " (" .. tostring(rank) .. ")")
            end
        end
        local profStr = (#profList > 0) and (" | Profs: " .. table.concat(profList, ", ")) or ""
        local selfTag = C.IsCurrentPlayer(info.name) and " |cff00aeff(You)|r" or ""
        NS:Print(string.format("  |cff00ff00%s|r%s [Lv%d %s | via %s]%s",
            info.name, selfTag, info.level or 0, info.class or "?", info.source or "scan", profStr))
    end

    NS:Print("=== Active Mail Routes (Mode: " .. tostring(WOWEngineDB.multiAltMode or "roundrobin") .. ") ===")
    local anyRule = false
    for _, cat in ipairs(NS.CATEGORIES) do
        local targets = rules[cat.key]
        if type(targets) == "table" and #targets > 0 then
            anyRule = true
            NS:Print(string.format("  [%s] -> |cffffd100%s|r", cat.key, table.concat(targets, ", ")))
        end
    end
    if #custom > 0 then
        anyRule = true
        NS:Print("=== Custom Character Additions ===")
        for i, entry in ipairs(custom) do
            NS:Print(string.format("  #%d '%s' -> |cff00ff00%s|r", i, entry.keyword or "?", entry.target or "?"))
        end
    end
    if not anyRule then
        NS:Print("  |cffff9900No routes mapped yet.|r Open |cffffd100/he setup|r -> Step 3.")
    end
end

local scanEvents = CreateFrame("Frame")
scanEvents:RegisterEvent("GUILD_ROSTER_UPDATE")
scanEvents:RegisterEvent("FRIENDLIST_UPDATE")
scanEvents:RegisterEvent("SKILL_LINES_CHANGED")
scanEvents:RegisterEvent("MAIL_SHOW")
scanEvents:SetScript("OnEvent", function(self, event)
    if event == "MAIL_SHOW" then
        R:ScanAll(true)
    elseif event == "GUILD_ROSTER_UPDATE" or event == "FRIENDLIST_UPDATE" then
        R:ScanGuildAndFriends()
        R:AutoMapVerifiedRoutes(false)
        if NS.Onboarding and NS.Onboarding.RefreshIfShown then
            NS.Onboarding:RefreshIfShown()
        end
    elseif event == "SKILL_LINES_CHANGED" then
        R:ScanCurrentPlayer()
        R:AutoMapVerifiedRoutes(false)
    end
end)
