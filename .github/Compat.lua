local addonName, NS = ...
NS.Compat = {}
local C = NS.Compat

function C.Trim(s)
    if type(s) ~= "string" then return "" end
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

-- Safe secret-value check (Midnight 12.x / WoW Forever 1.60.1)
function C.IsSecret(val)
    if issecretvalue then
        return issecretvalue(val)
    end
    return false
end

function C.SafeStr(val)
    if val == nil or C.IsSecret(val) then return nil end
    return tostring(val)
end

function C.IsAddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        if ok and loaded then return true end
    elseif IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, name)
        if ok and loaded then return true end
    end
    return false
end

-- Cross-client Item Info (WoW Forever 1.60.1 & Mainline 12.x removed global GetItemInfo)
function C.GetItemInfo(item)
    if not item then return nil end
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(item)
    elseif GetItemInfo then
        return GetItemInfo(item)
    end
    return nil
end

function C.GetItemInfoInstant(item)
    if not item then return nil end
    if C_Item and C_Item.GetItemInfoInstant then
        return C_Item.GetItemInfoInstant(item)
    elseif GetItemInfoInstant then
        return GetItemInfoInstant(item)
    end
    return nil
end

function C.RequestLoadItemDataByID(itemID)
    if itemID and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

-- Cross-client Container API shim
function C.GetContainerNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    elseif GetContainerNumSlots then
        return GetContainerNumSlots(bag) or 0
    end
    return 0
end

function C.GetContainerItemLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bag, slot)
    elseif GetContainerItemLink then
        return GetContainerItemLink(bag, slot)
    end
    return nil
end

-- Returns: icon, count, isLocked, quality, hyperlink, itemID, isBound
function C.GetContainerItemDetails(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
            return info.iconFileID, info.stackCount, info.isLocked, info.quality, info.hyperlink, info.itemID, info.isBound
        end
        return nil
    elseif GetContainerItemInfo then
        local icon, count, locked, quality, _, _, link, _, _, itemID = GetContainerItemInfo(bag, slot)
        return icon, count, locked, quality, link, itemID, nil
    end
    return nil
end

function C.PickupContainerItem(bag, slot)
    if C_Container and C_Container.PickupContainerItem then
        return C_Container.PickupContainerItem(bag, slot)
    elseif PickupContainerItem then
        return PickupContainerItem(bag, slot)
    end
end

function C.SortBags()
    if C_Container and C_Container.SortBags then
        C_Container.SortBags()
        return true
    elseif SortBags then
        SortBags()
        return true
    end
    return false
end

function C.SortBankBags()
    if C_Container and C_Container.SortBankBags then
        C_Container.SortBankBags()
        return true
    elseif SortBankBags then
        SortBankBags()
        return true
    end
    return false
end

function C.FormatMoney(copper)
    copper = tonumber(copper) or 0
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(copper)
    elseif GetCoinTextureString then
        return GetCoinTextureString(copper)
    end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    return string.format("|cffffd100%dg|r |cffc0c0c0%ds|r |cffeda55f%dc|r", g, s, c)
end

-- Preserve single space for WoW Forever two-name characters and hyphens for cross-realm
function C.NormalizeRecipient(rawName)
    if not rawName or C.IsSecret(rawName) then return nil end
    local trimmed = C.Trim(tostring(rawName))
    if trimmed == "" then return nil end
    trimmed = string.gsub(trimmed, "%s+", " ")
    return trimmed
end

function C.StripLocalRealm(fullName)
    local clean = C.NormalizeRecipient(fullName)
    if not clean then return nil end
    local realm = C.SafeStr(GetRealmName())
    if not realm or realm == "" then return clean end

    local namePart, realmPart = string.match(clean, "^(.-)%-([^%-]+)$")
    if namePart and realmPart then
        local normCur = string.lower(string.gsub(realm, "[%s%-']", ""))
        local normPart = string.lower(string.gsub(realmPart, "[%s%-']", ""))
        if normCur == normPart then
            return C.NormalizeRecipient(namePart)
        end
    end
    return clean
end

-- Canonical comparison key for character names (handles local realm suffix, spacing, and case)
function C.CanonicalCharKey(name)
    local stripped = C.StripLocalRealm(name)
    if not stripped then return nil end
    return string.lower(stripped)
end

function C.IsSameCharacter(nameA, nameB)
    local kA = C.CanonicalCharKey(nameA)
    local kB = C.CanonicalCharKey(nameB)
    if not kA or not kB then return false end
    return kA == kB
end

function C.GetRawPlayerName()
    local name = C.SafeStr(UnitName("player"))
    return C.StripLocalRealm(name)
end

-- Returns the canonical full name of the logged-in character (resolves WoW Forever "Hide Second Name")
function C.GetPlayerName()
    if NS and NS.resolvedPlayerFullName and NS.resolvedPlayerFullName ~= "" then
        return NS.resolvedPlayerFullName
    end
    return C.GetRawPlayerName()
end

-- Strict self-mail guard: matches both resolved full two-part name AND short "Hide Second Name" display name
function C.IsCurrentPlayer(candidateName)
    if not candidateName then return false end
    local resolved = NS and NS.resolvedPlayerFullName
    if resolved and C.IsSameCharacter(candidateName, resolved) then
        return true
    end
    local rawName = C.GetRawPlayerName()
    if rawName and C.IsSameCharacter(candidateName, rawName) then
        return true
    end
    if UnitFullName then
        local ok, fn, fr = pcall(UnitFullName, "player")
        if ok and fn and not C.IsSecret(fn) then
            if C.IsSameCharacter(candidateName, fn) then return true end
            if fr and not C.IsSecret(fr) and fr ~= "" then
                if C.IsSameCharacter(candidateName, fn .. "-" .. fr) then return true end
            end
        end
    end
    -- Also match by saved UnitGUID if available in active roster
    if UnitGUID and NS and NS.GetActiveRoster then
        local okG, pGuid = pcall(UnitGUID, "player")
        if okG and pGuid and not C.IsSecret(pGuid) then
            local roster = NS:GetActiveRoster()
            local key = C.CanonicalCharKey(candidateName)
            for exactName, info in pairs(roster) do
                if info and info.guid == pGuid and C.CanonicalCharKey(exactName) == key then
                    return true
                end
            end
        end
    end
    return false
end

local KNOWN_PRIMARY_PROFS = {
    "Herbalism", "Alchemy", "Enchanting", "Mining", "Blacksmithing",
    "Engineering", "Jewelcrafting", "Leatherworking", "Skinning",
    "Tailoring", "Inscription",
}

local KNOWN_SUB_PROFS = {
    "Cooking", "Fishing", "First Aid",
}

local function MatchCanonicalProf(rawName, list)
    if not rawName or C.IsSecret(rawName) then return nil end
    local low = string.lower(tostring(rawName))
    for _, canonical in ipairs(list) do
        if low == string.lower(canonical) or string.find(low, string.lower(canonical), 1, true) then
            return canonical
        end
    end
    return nil
end

local function PlayerKnowsAnySpell(spellIDs)
    for _, sid in ipairs(spellIDs) do
        if IsPlayerSpell then
            local ok, known = pcall(IsPlayerSpell, sid)
            if ok and known then return true end
        end
        if IsSpellKnown then
            local ok, known = pcall(IsSpellKnown, sid)
            if ok and known then return true end
        end
    end
    return false
end

local PRIMARY_PROF_SPELLS = {
    Herbalism      = { 2366, 2368, 3570, 11993, 28695, 2383 },
    Alchemy        = { 2259, 3101, 3464, 11611, 28596 },
    Enchanting     = { 7411, 7412, 7413, 13920, 28029, 13262 },
    Mining         = { 2575, 2576, 3564, 10248, 29354, 2656, 2580 },
    Blacksmithing  = { 2018, 3100, 3538, 9785, 29844 },
    Engineering    = { 4036, 4037, 4038, 12656, 30350 },
    Jewelcrafting  = { 25229, 25230, 28894, 28895, 28897, 31252 },
    Leatherworking = { 2108, 3104, 3811, 10662, 32549 },
    Skinning       = { 8613, 8617, 8618, 10768, 32678 },
    Tailoring      = { 3908, 3909, 3910, 12180, 26790 },
    Inscription    = { 45357, 45358, 45359, 45360, 45361, 51005 },
}

local SUB_PROF_SPELLS = {
    Cooking       = { 2550, 3102, 3413, 18260, 33359 },
    Fishing       = { 7620, 7731, 7732, 18248, 33095 },
    ["First Aid"] = { 3273, 3274, 7924, 10846, 27028 },
}

-- Scan current character's learned primary professions across Retail/Forever/MoP/TBC/Classic
function C.GetPlayerProfessions()
    local profs = {}

    -- Method 1: Modern GetProfessions() (use explicit array + numeric loop so nil slot 1 never skips slot 2)
    if GetProfessions and GetProfessionInfo then
        local okG, p1, p2 = pcall(GetProfessions)
        if okG then
            local slots = { [1] = p1, [2] = p2 }
            for i = 1, 2 do
                local idx = slots[i]
                if idx then
                    local ok, name, _, rank = pcall(GetProfessionInfo, idx)
                    if ok and name and not C.IsSecret(name) then
                        local canon = MatchCanonicalProf(name, KNOWN_PRIMARY_PROFS) or name
                        profs[canon] = tonumber(rank) or 1
                    end
                end
            end
        end
    end

    -- Method 2: Classic / WoW Forever Skill Lines (handles expansion prefixes & partial matches)
    if GetNumSkillLines and GetSkillLineInfo then
        local okN, num = pcall(GetNumSkillLines)
        if okN and type(num) == "number" and num > 0 then
            for i = 1, num do
                local ok, skillName, isHeader, _, skillRank = pcall(GetSkillLineInfo, i)
                if ok and not isHeader and skillName and not C.IsSecret(skillName) then
                    local canon = MatchCanonicalProf(skillName, KNOWN_PRIMARY_PROFS)
                    if canon then
                        profs[canon] = tonumber(skillRank) or profs[canon] or 1
                    end
                end
            end
        end
    end

    -- Method 3: Spellbook fallback (detects professions even if Classic Skill header is collapsed or uncached)
    for profName, spellList in pairs(PRIMARY_PROF_SPELLS) do
        if not profs[profName] and PlayerKnowsAnySpell(spellList) then
            profs[profName] = 1
        end
    end

    return profs
end

function C.RequestGuildScan()
    if not IsInGuild or not IsInGuild() then return end
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        pcall(C_GuildInfo.GuildRoster)
    elseif GuildRoster then
        pcall(GuildRoster)
    end
end

function C.GetGuildMemberNames()
    local members = {}
    if not IsInGuild or not IsInGuild() then return members end
    local total = 0
    if GetNumGuildMembers then
        local ok, n = pcall(GetNumGuildMembers)
        if ok and n then total = n end
    end
    for i = 1, total do
        local ok, fullName, _, _, level, classDisplay, _, _, _, _, _, classFile = pcall(GetGuildRosterInfo, i)
        if ok and fullName and not C.IsSecret(fullName) then
            local clean = C.StripLocalRealm(fullName)
            if clean then
                table.insert(members, {
                    name = clean,
                    level = level or 0,
                    class = classFile or classDisplay or "UNKNOWN",
                })
            end
        end
    end
    return members
end

function C.GetFriendNames()
    local friends = {}
    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        local ok, num = pcall(C_FriendList.GetNumFriends)
        if ok and num then
            for i = 1, num do
                local okInfo, info = pcall(C_FriendList.GetFriendInfoByIndex, i)
                if okInfo and info and info.name and not C.IsSecret(info.name) then
                    local clean = C.StripLocalRealm(info.name)
                    if clean then
                        table.insert(friends, {
                            name = clean,
                            level = info.level or 0,
                            class = info.className or "UNKNOWN",
                        })
                    end
                end
            end
        end
    elseif GetNumFriends and GetFriendInfo then
        local ok, num = pcall(GetNumFriends)
        if ok and num then
            for i = 1, num do
                local okInfo, name, level, className = pcall(GetFriendInfo, i)
                if okInfo and name and not C.IsSecret(name) then
                    local clean = C.StripLocalRealm(name)
                    if clean then
                        table.insert(friends, {
                            name = clean,
                            level = level or 0,
                            class = className or "UNKNOWN",
                        })
                    end
                end
            end
        end
    end
    return friends
end

-- ============================================================
-- EXTERNAL ADDON BRIDGES: ALTOHOLIC/DATASTORE, MASTERCRAFT, AUCTIONATOR
-- ============================================================

function C.IsAltoholicAvailable()
    return (_G.DataStore ~= nil) or (_G.Altoholic ~= nil) or C.IsAddOnLoaded("Altoholic") or C.IsAddOnLoaded("DataStore")
end

function C.IsMastercraftAvailable()
    return (_G.Mastercraft ~= nil) or (_G.MasterCraft ~= nil) or (_G.MastercraftDB ~= nil) or C.IsAddOnLoaded("Mastercraft")
end

function C.IsAuctionatorAvailable()
    return (_G.Auctionator ~= nil) or C.IsAddOnLoaded("Auctionator")
end


local function ClassifyAltoBagType(link, bagObj)
    if type(bagObj) == "table" and bagObj.bagtype ~= nil then
        local bt = tonumber(bagObj.bagtype) or 0
        if bt == 0 then return "regular" end
        if bt == 1 or bt == 2 then return "quiver" end
        if bt == 4 then return "soul" end
        if bt == 8 then return "leather" end
        if bt == 16 then return "inscription" end
        if bt == 32 then return "herb" end
        if bt == 64 then return "enchanting" end
        if bt == 128 then return "engineering" end
        if bt == 512 then return "gem" end
        if bt == 1024 then return "mining" end
        if bt == 2048 then return "reagent" end
    end
    if link and type(link) == "string" then
        local containerClassID = (Enum and Enum.ItemClass and Enum.ItemClass.Container) or 1
        local quiverClassID = (Enum and Enum.ItemClass and Enum.ItemClass.Quiver) or 11
        local _, _, _, _, _, classID, subClassID = C.GetItemInfoInstant(link)
        if classID == quiverClassID then return "quiver" end
        if classID == containerClassID and subClassID ~= nil then
            if subClassID == 0 then return "regular" end
            if subClassID == 1 then return "soul" end
            if subClassID == 2 then return "herb" end
            if subClassID == 3 then return "enchanting" end
            if subClassID == 4 then return "engineering" end
            if subClassID == 5 then return "gem" end
            if subClassID == 6 then return "mining" end
            if subClassID == 7 then return "leather" end
            if subClassID == 8 then return "inscription" end
            if subClassID == 11 then return "reagent" end
            return "regular"
        end
        local low = string.lower(link)
        if string.find(low, "quiver") or string.find(low, "ammo") or string.find(low, "bandolier") then return "quiver" end
        if string.find(low, "reagent") then return "reagent" end
        if string.find(low, "herb") then return "herb" end
        if string.find(low, "enchant") then return "enchanting" end
        if string.find(low, "engineer") then return "engineering" end
        if string.find(low, "gem") then return "gem" end
        if string.find(low, "mining") then return "mining" end
        if string.find(low, "leatherwork") or string.find(low, "trapper") or string.find(low, "many hides") then return "leather" end
        if string.find(low, "inscription") then return "inscription" end
        if string.find(low, "soul") then return "soul" end
    end
    return "regular"
end

function C.GetAltoholicEquippedBags(charKey)
    local DS = _G.DataStore
    if not DS or not charKey then return nil, 0, 0 end

    local equipped = {}
    local foundAnyData = false
    local totalAll = 0
    local totalRegular = 0

    for bagID = 1, 5 do
        local slots = nil
        local link = nil
        local bagObj = nil

        if DS.GetContainer then
            local okB, b = pcall(DS.GetContainer, DS, charKey, "Bag" .. bagID)
            if okB and type(b) == "table" then
                bagObj = b
                slots = tonumber(b.size) or tonumber(b.Size)
                link = b.link or b.Link
            end
        end
        if slots == nil and DS.GetContainerSize then
            local okS, s = pcall(DS.GetContainerSize, DS, charKey, bagID)
            if okS and type(s) == "number" then
                slots = s
            end
        end

        if slots ~= nil then
            foundAnyData = true
            local bType = "empty"
            if slots > 0 then
                bType = (bagID == 5) and "reagent" or ClassifyAltoBagType(link, bagObj)
            end
            if bagID <= 4 or slots > 0 then
                equipped[bagID] = { slots = slots, bagType = bType }
                totalAll = totalAll + slots
                if bType ~= "quiver" and bagID <= 4 then
                    totalRegular = totalRegular + slots
                end
            end
        elseif bagID <= 4 then
            equipped[bagID] = { slots = 0, bagType = "empty" }
        end
    end

    if not foundAnyData then
        return nil, 0, 0
    end
    return equipped, totalAll, totalRegular
end

function C.GetAltoholicCharacters(targetRealm, targetFaction)
    local results = {}
    local DS = _G.DataStore
    if not DS then return results end

    local realm = targetRealm or C.SafeStr(GetRealmName())
    local faction = targetFaction or C.SafeStr(UnitFactionGroup("player"))
    if not realm then return results end

    local okChars, chars = pcall(function()
        if DS.GetCharacters then
            return DS:GetCharacters(realm)
        end
        return nil
    end)

    if okChars and type(chars) == "table" then
        for charName, charKey in pairs(chars) do
            local cleanName = C.StripLocalRealm(charName)
            if cleanName then
                local charFaction = nil
                if DS.GetCharacterFaction then
                    local okF, f = pcall(DS.GetCharacterFaction, DS, charKey)
                    if okF then charFaction = f end
                end

                if (not charFaction) or (not faction) or (string.lower(tostring(charFaction)) == string.lower(tostring(faction))) then
                    local level = 0
                    if DS.GetCharacterLevel then
                        local okL, lv = pcall(DS.GetCharacterLevel, DS, charKey)
                        if okL and type(lv) == "number" then level = lv end
                    end

                    local classFile = "UNKNOWN"
                    if DS.GetCharacterClass then
                        local okC, locClass, engClass = pcall(DS.GetCharacterClass, DS, charKey)
                        if okC then classFile = engClass or locClass or "UNKNOWN" end
                    end

                    local copper = nil
                    if DS.GetMoney then
                        local okM, m = pcall(DS.GetMoney, DS, charKey)
                        if okM and type(m) == "number" then copper = m end
                    end

                    local profs = {}
                    if DS.GetProfession1 then
                        local okP1, rank1, _, name1 = pcall(DS.GetProfession1, DS, charKey)
                        if okP1 and name1 and type(name1) == "string" and name1 ~= "" then
                            profs[name1] = tonumber(rank1) or 1
                        end
                    end
                    if DS.GetProfession2 then
                        local okP2, rank2, _, name2 = pcall(DS.GetProfession2, DS, charKey)
                        if okP2 and name2 and type(name2) == "string" and name2 ~= "" then
                            profs[name2] = tonumber(rank2) or 1
                        end
                    end
                    if next(profs) == nil and DS.GetProfessions then
                        local okP, pTbl = pcall(DS.GetProfessions, DS, charKey)
                        if okP and type(pTbl) == "table" then
                            for pName, pData in pairs(pTbl) do
                                if type(pName) == "string" and pName ~= "" then
                                    local r = (type(pData) == "table" and (pData.Rank or pData.rank)) or tonumber(pData) or 1
                                    profs[pName] = r
                                end
                            end
                        end
                    end

                    local playedTime = nil
                    if DS.GetPlayTime then
                        local okPT, pt = pcall(DS.GetPlayTime, DS, charKey)
                        if okPT and type(pt) == "number" then playedTime = pt end
                    end

                    local eqBags, totBags, regBags = C.GetAltoholicEquippedBags(charKey)

                    table.insert(results, {
                        name = cleanName,
                        level = level,
                        class = classFile,
                        faction = charFaction or faction,
                        copper = copper,
                        playedTime = playedTime,
                        equippedBags = eqBags,
                        totalBagSlots = totBags,
                        regularBagSlots = regBags,
                        professions = profs,
                    })
                end
            end
        end
    end

    return results
end

function C.IsMastercraftReserved(itemID)
    if not itemID then return false end
    local MC = _G.Mastercraft or _G.MasterCraft
    if MC then
        if type(MC.IsReagentReserved) == "function" then
            local ok, res = pcall(MC.IsReagentReserved, MC, itemID)
            if ok and res then return true end
        end
        if type(MC.IsItemInQueue) == "function" then
            local ok, res = pcall(MC.IsItemInQueue, MC, itemID)
            if ok and res then return true end
        end
        if type(MC.reservedReagents) == "table" and MC.reservedReagents[itemID] then
            return true
        end
        if type(MC.shoppingList) == "table" and MC.shoppingList[itemID] then
            return true
        end
    end

    local db = _G.MastercraftDB or _G.MasterCraftDB
    if type(db) == "table" then
        if type(db.reservedReagents) == "table" and db.reservedReagents[itemID] then
            return true
        end
        if type(db.shoppingList) == "table" and db.shoppingList[itemID] then
            return true
        end
        if type(db.queue) == "table" then
            for _, entry in pairs(db.queue) do
                if type(entry) == "table" then
                    if entry.itemID == itemID then return true end
                    if type(entry.reagents) == "table" and entry.reagents[itemID] then
                        return true
                    end
                end
            end
        end
    end

    return false
end


-- Extract clean plain item name from a WoW hyperlink, bracketed text, or plain string
function C.ExtractItemName(raw)
    if not raw or C.IsSecret(raw) then return nil end
    local s = tostring(raw)
    -- If it is a WoW hyperlink |c...|Hitem:...|h[Cerulean Dye]|h|r, grab the bracketed name
    local bracketed = string.match(s, "%[(.-)%]")
    if bracketed and bracketed ~= "" then
        s = bracketed
    end
    -- Strip any remaining WoW color/escape codes
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    s = string.gsub(s, "|H.-|h", "")
    s = string.gsub(s, "|h", "")
    s = C.Trim(s)
    if s == "" then return nil end
    return s
end

function C.ExtractItemID(link)
    if not link or C.IsSecret(link) then return nil end
    return tonumber(string.match(tostring(link), "item:(%d+)"))
end


-- Return highest equipped bag index (includes Reagent Bag = 5 on WoW Forever 1.60.1 / Mainline 12.x)
function C.GetMaxBagIndex()
    local maxBag = NUM_BAG_SLOTS or 4
    if NUM_TOTAL_EQUIPPED_BAG_SLOTS and NUM_TOTAL_EQUIPPED_BAG_SLOTS > maxBag then
        maxBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS
    end
    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag and Enum.BagIndex.ReagentBag > maxBag then
        maxBag = Enum.BagIndex.ReagentBag
    end
    -- Also check if bag 5 has slots even if constants aren't exposed
    if maxBag < 5 and C.GetContainerNumSlots(5) > 0 then
        maxBag = 5
    end
    return maxBag
end


-- Scan current character's learned secondary/sub-professions (Cooking, Fishing, First Aid)
function C.GetPlayerSubProfessions()
    local subs = {}

    if GetProfessions and GetProfessionInfo then
        local okG, _, _, arch, fish, cook, fa = pcall(GetProfessions)
        if okG then
            local slots = { [1] = fish, [2] = cook, [3] = fa, [4] = arch }
            for i = 1, 4 do
                local idx = slots[i]
                if idx then
                    local ok, name, _, rank = pcall(GetProfessionInfo, idx)
                    if ok and name and not C.IsSecret(name) then
                        local canon = MatchCanonicalProf(name, KNOWN_SUB_PROFS)
                        if canon then
                            subs[canon] = tonumber(rank) or 1
                        end
                    end
                end
            end
        end
    end

    if GetNumSkillLines and GetSkillLineInfo then
        local okN, num = pcall(GetNumSkillLines)
        if okN and type(num) == "number" and num > 0 then
            for i = 1, num do
                local ok, skillName, isHeader, _, skillRank = pcall(GetSkillLineInfo, i)
                if ok and not isHeader and skillName and not C.IsSecret(skillName) then
                    local canon = MatchCanonicalProf(skillName, KNOWN_SUB_PROFS)
                    if canon then
                        subs[canon] = tonumber(skillRank) or subs[canon] or 1
                    end
                end
            end
        end
    end

    for subName, spellList in pairs(SUB_PROF_SPELLS) do
        if not subs[subName] and PlayerKnowsAnySpell(spellList) then
            subs[subName] = 1
        end
    end

    return subs
end
