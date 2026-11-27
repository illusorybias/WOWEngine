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

R.MAX_SHARED_PER_PROF = 10

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
        if #list >= (R.MAX_SHARED_PER_PROF or 10) then
            return false, "limit"
        end
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
            local rInfo = exact and NS:GetActiveRoster()[exact]
            if exact and not R:IsExcludedFromMail(rInfo) then
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

-- Resolve full two-name character when WoW Forever "Hide Second Name" is enabled, and purge duplicate short-name entry
function R:ResolvePlayerFullName(rawName, playerClass, playerLevel, playerGuid)
    if not rawName then return nil end
    local roster = NS:GetActiveRoster()

    -- 1. If rawName already has a space (full two-part name), use it directly
    if string.find(rawName, " ", 1, true) then
        NS.resolvedPlayerFullName = rawName
        return rawName
    end

    -- 2. Check existing roster for exact GUID match with a full two-part name
    if playerGuid then
        for exactName, info in pairs(roster) do
            if info and info.guid == playerGuid and string.find(exactName, " ", 1, true) then
                NS.resolvedPlayerFullName = exactName
                return exactName
            end
        end
    end

    -- 3. Check existing roster for "<rawName> <surname>" matching same class (and closest level)
    local prefixLow = string.lower(rawName) .. " "
    local bestName = nil
    local bestScore = -1

    for exactName, info in pairs(roster) do
        if exactName and string.sub(string.lower(exactName), 1, #prefixLow) == prefixLow then
            local score = 10
            if playerClass and info.class and string.upper(info.class) == string.upper(playerClass) then
                score = score + 50
            end
            if playerLevel and info.level and math.abs((tonumber(info.level) or 0) - playerLevel) <= 2 then
                score = score + 25
            end
            if score > bestScore then
                bestScore = score
                bestName = exactName
            end
        end
    end

    if bestName and bestScore >= 60 then
        NS.resolvedPlayerFullName = bestName
        return bestName
    end

    -- 4. Also check Altoholic/DataStore directly if roster hasn't imported yet
    if C.IsAltoholicAvailable() then
        local realm, faction = NS:GetContextKeys()
        for _, ch in ipairs(C.GetAltoholicCharacters(realm, faction)) do
            if ch.name and string.sub(string.lower(ch.name), 1, #prefixLow) == prefixLow then
                if (not playerClass) or (not ch.class) or string.upper(ch.class) == string.upper(playerClass) then
                    NS.resolvedPlayerFullName = ch.name
                    return ch.name
                end
            end
        end
    end

    return rawName
end

-- Merge & remove any stale short-name duplicate (e.g. "Illusorybias") once full name ("Illusorybias druidherbalc") is known
function R:MergeShortNameDuplicate(shortName, fullName)
    if not shortName or not fullName or C.IsSameCharacter(shortName, fullName) then return end
    local roster = NS:GetActiveRoster()
    local shortEntry = roster[shortName]
    if shortEntry then
        local fullEntry = roster[fullName] or {}
        if shortEntry.excludeFromWave ~= nil and fullEntry.excludeFromWave == nil then
            fullEntry.excludeFromWave = shortEntry.excludeFromWave
        end
        if shortEntry.excludeFromMail ~= nil and fullEntry.excludeFromMail == nil then
            fullEntry.excludeFromMail = shortEntry.excludeFromMail
        end
        roster[fullName] = fullEntry
        roster[shortName] = nil
    end

    -- Migrate any mail routing rules pointing to shortName over to fullName
    local rules = NS:GetActiveRules()
    for catKey, list in pairs(rules) do
        if type(list) == "table" then
            local replaced = false
            local newList = {}
            local seen = {}
            for _, n in ipairs(list) do
                local target = C.IsSameCharacter(n, shortName) and fullName or n
                if C.IsSameCharacter(n, shortName) then replaced = true end
                local k = C.CanonicalCharKey(target)
                if k and not seen[k] then
                    seen[k] = true
                    table.insert(newList, target)
                end
            end
            if replaced then
                rules[catKey] = newList
            end
        end
    end
end

function R:ScanCurrentPlayer()
    local roster = NS:GetActiveRoster()
    local rawName = C.GetRawPlayerName()
    if not rawName then return nil end

    local pLevel = UnitLevel("player") or 1
    local pClass = select(2, UnitClass("player")) or "UNKNOWN"
    local pGuid = nil
    if UnitGUID then
        local okG, g = pcall(UnitGUID, "player")
        if okG and g and not C.IsSecret(g) then pGuid = g end
    end

    local resolvedName = R:ResolvePlayerFullName(rawName, pClass, pLevel, pGuid)
    if resolvedName and resolvedName ~= rawName then
        R:MergeShortNameDuplicate(rawName, resolvedName)
    end

    local name = resolvedName or rawName
    local existing = roster[name] or {}
    local profs = C.GetPlayerProfessions()
    existing.name = name
    existing.shortName = (rawName ~= name) and rawName or existing.shortName
    existing.guid = pGuid or existing.guid
    existing.level = pLevel
    existing.class = pClass
    existing.source = "login"
    existing.verified = true
    existing.isOwnAlt = true
    existing.lastSeen = time()
    if next(profs) ~= nil then
        existing.professions = profs
    else
        existing.professions = existing.professions or {}
    end
    local subs = C.GetPlayerSubProfessions()
    if next(subs) ~= nil then
        existing.subProfessions = subs
    else
        existing.subProfessions = existing.subProfessions or {}
    end
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
                    playedTime = ch.playedTime or 0,
                    equippedBags = ch.equippedBags,
                    totalBagSlots = ch.totalBagSlots or 0,
                    regularBagSlots = ch.regularBagSlots or 0,
                    professions = ch.professions or {},
                }
                imported = imported + 1
            else
                entry.verified = true
                if ch.level and ch.level > (entry.level or 0) then entry.level = ch.level end
                if ch.class and ch.class ~= "UNKNOWN" then entry.class = ch.class end
                if ch.playedTime and ch.playedTime > (entry.playedTime or 0) then entry.playedTime = ch.playedTime end
                if ch.equippedBags and type(entry.equippedBags) ~= "table" then
                    entry.equippedBags = ch.equippedBags
                    entry.totalBagSlots = ch.totalBagSlots or 0
                    entry.regularBagSlots = ch.regularBagSlots or 0
                end
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
        if not R:IsExcludedFromMail(info) then
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

function R:IsIncludedInWave(info)
    if not info or not info.verified then return false end
    if info.excludeFromWave == true then return false end
    if info.includeInWave == true then return true end
    local ws = NS:GetWaveState()
    local allowAlto = (ws and ws.includeAltoholicInWave) and true or false
    local isMine = (info.isOwnAlt == true) or (info.source == "login") or C.IsCurrentPlayer(info.name)
    return isMine or (allowAlto and info.source == "altoholic")
end

function R:SetWaveExcluded(charName, excluded)
    local exact = R:FindVerifiedName(charName)
    if not exact then return false, nil end
    local roster = NS:GetActiveRoster()
    local info = roster[exact]
    if not info then return false, nil end
    if excluded then
        info.excludeFromWave = true
        info.includeInWave = false
    else
        info.excludeFromWave = false
        info.includeInWave = true
    end
    return true, exact
end


function R:IsExcludedFromMail(info)
    if not info then return false end
    return info.excludeFromMail == true
end

function R:SetMailExcluded(charName, excluded)
    local exact = R:FindVerifiedName(charName)
    if not exact then return false, nil end
    local roster = NS:GetActiveRoster()
    local info = roster[exact]
    if not info then return false, nil end
    info.excludeFromMail = excluded and true or false

    -- If excluded from mail, remove from all active mail categories immediately
    if info.excludeFromMail then
        for _, cat in ipairs(NS.CATEGORIES) do
            R:RemoveTargetFromCategory(cat.key, exact, true)
        end
    end
    return true, exact
end

-- Returns ONLY characters included in Wave Leveling Sync (respects per-character Exclude/Include boxes)
function R:GetOwnLevelingRoster()
    local roster = NS:GetActiveRoster()
    local list = {}

    for _, info in pairs(roster) do
        if R:IsIncludedInWave(info) then
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

    local roster = NS:GetActiveRoster()
    for _, rawTarget in ipairs(configured) do
        local exact = R:FindVerifiedName(rawTarget)
        if exact and not R:IsExcludedFromMail(roster[exact]) then
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
    R:ScanAltoholic()
    R:ScanGuildAndFriends()
    R:ScanCurrentPlayer()
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
scanEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
scanEvents:RegisterEvent("TRADE_SKILL_SHOW")
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
    elseif event == "SKILL_LINES_CHANGED" or event == "PLAYER_ENTERING_WORLD" or event == "TRADE_SKILL_SHOW" then
        R:ScanCurrentPlayer()
        R:AutoMapVerifiedRoutes(false)
        if NS.Onboarding and NS.Onboarding.RefreshIfShown then
            NS.Onboarding:RefreshIfShown()
        end
    end
end)


-- Ordered list of primary professions for planning new characters
R.PRIMARY_PROF_LIST = {
    "None",
    "Herbalism",
    "Alchemy",
    "Enchanting",
    "Mining",
    "Blacksmithing",
    "Engineering",
    "Jewelcrafting",
    "Leatherworking",
    "Skinning",
    "Tailoring",
    "Inscription",
}

function R:GetCategoriesForProfession(profName)
    if not profName or profName == "None" then return {} end
    return PROF_TO_CATEGORIES[profName] or {}
end

-- Returns all OTHER verified characters who share a given mail category (no hidden "+1 more")
function R:GetSharedAltsForCategory(catKey, excludeCharName)
    local targets = R:GetCategoryTargets(catKey)
    local others = {}
    for _, name in ipairs(targets) do
        if not excludeCharName or not C.IsSameCharacter(name, excludeCharName) then
            table.insert(others, name)
        end
    end
    return others
end

-- Returns dynamic profession profile for a character:
-- phase 1 = No learned profs yet (Planned), phase 2 = Learned & Auto-Mapped, phase 3 = Learned + Mastercraft Active
function R:GetCharacterProfessionProfile(charName)
    local roster = NS:GetActiveRoster()
    local exact = R:FindVerifiedName(charName) or charName
    local info = (exact and roster[exact]) or {}
    local plans = NS:GetCharPlans()
    local cKey = C.CanonicalCharKey(exact) or string.lower(exact or "unknown")
    local plan = plans[cKey] or {}

    local learnedList = {}
    if info.professions then
        for pName, rank in pairs(info.professions) do
            table.insert(learnedList, { name = pName, rank = tonumber(rank) or 1, learned = true })
        end
        table.sort(learnedList, function(a, b) return a.name < b.name end)
    end

    local p1 = learnedList[1] or (plan.p1 and plan.p1 ~= "None" and { name = plan.p1, rank = 0, learned = false } or nil)
    local p2 = learnedList[2] or (plan.p2 and plan.p2 ~= "None" and { name = plan.p2, rank = 0, learned = false } or nil)

    local learnedCount = #learnedList
    local phase = 1
    if learnedCount > 0 then
        phase = C.IsMastercraftAvailable() and 3 or 2
    end

    local subs = info.subProfessions or {}
    local isBank = R:HasTargetInCategory("BankAlt", exact)

    return {
        name = exact,
        level = tonumber(info.level) or 0,
        class = info.class or "UNKNOWN",
        source = info.source or "scan",
        phase = phase,
        learnedCount = learnedCount,
        p1 = p1,
        p2 = p2,
        subs = subs,
        isBankAlt = isBank,
    }
end

-- Cycle or set planned primary profession (slot 1 or 2) for a character that hasn't learned it yet
function R:CyclePlannedProfession(charName, slotNum)
    local exact = R:FindVerifiedName(charName)
    if not exact then return nil end
    local plans = NS:GetCharPlans()
    local cKey = C.CanonicalCharKey(exact)
    plans[cKey] = plans[cKey] or {}
    local field = (slotNum == 1) and "p1" or "p2"
    local cur = plans[cKey][field] or "None"

    local nextIdx = 1
    for i, pName in ipairs(R.PRIMARY_PROF_LIST) do
        if pName == cur then
            nextIdx = (i % #R.PRIMARY_PROF_LIST) + 1
            break
        end
    end
    local chosen = R.PRIMARY_PROF_LIST[nextIdx]
    plans[cKey][field] = (chosen ~= "None") and chosen or nil

    -- Auto-map material categories if user picks a planned profession
    if chosen ~= "None" then
        for _, catKey in ipairs(R:GetCategoriesForProfession(chosen)) do
            R:AddTargetToCategory(catKey, exact, true)
        end
    end
    return chosen
end


-- Move a character up (-1) or down (+1) in the active priority list for a category
function R:MoveCategoryTarget(catKey, index, delta)
    local rules = NS:GetActiveRules()
    local list = rules[catKey]
    if type(list) ~= "table" then return false end
    local newIndex = index + delta
    if index < 1 or index > #list or newIndex < 1 or newIndex > #list then
        return false
    end
    local tmp = list[index]
    list[index] = list[newIndex]
    list[newIndex] = tmp
    local manual = NS:GetManualFlags()
    manual[catKey] = true
    return true
end

-- Sort active priority list by profession skill rank (highest first) or character level (highest first)
function R:SortCategoryTargets(catKey, profName, sortBy)
    local rules = NS:GetActiveRules()
    local list = rules[catKey]
    if type(list) ~= "table" or #list < 2 then return false end
    local roster = NS:GetActiveRoster()

    table.sort(list, function(a, b)
        local ia = roster[a] or {}
        local ib = roster[b] or {}
        if sortBy == "skill" and profName then
            local sa = (ia.professions and tonumber(ia.professions[profName])) or 0
            local sb = (ib.professions and tonumber(ib.professions[profName])) or 0
            if sa ~= sb then return sa > sb end
        end
        local la = tonumber(ia.level) or 0
        local lb = tonumber(ib.level) or 0
        if la ~= lb then return la > lb end
        return string.lower(a or "") < string.lower(b or "")
    end)

    local manual = NS:GetManualFlags()
    manual[catKey] = true
    return true
end

-- Return all verified characters sharing a profession/category (active top 10 + overflow pool if >10)
function R:GetSharedPoolForProfession(profName, catKey)
    local active = R:GetCategoryTargets(catKey)
    local activeMap = {}
    for _, name in ipairs(active) do
        local k = C.CanonicalCharKey(name)
        if k then activeMap[k] = true end
    end

    local pool = {}
    local plans = NS:GetCharPlans()
    local sorted = R:GetSortedVerifiedList()

    for _, info in ipairs(sorted) do
        local k = C.CanonicalCharKey(info.name)
        if k and not activeMap[k] and not R:IsExcludedFromMail(info) then
            local matchesProf = false
            if profName and info.professions and info.professions[profName] then
                matchesProf = true
            end
            if not matchesProf and profName and plans[k] then
                if plans[k].p1 == profName or plans[k].p2 == profName then
                    matchesProf = true
                end
            end
            if not matchesProf and catKey then
                for _, inferred in ipairs(InferCategoriesFromVerifiedName(info.name)) do
                    if inferred == catKey then
                        matchesProf = true
                        break
                    end
                end
            end
            if matchesProf then
                table.insert(pool, info)
            end
        end
    end

    return active, pool
end
