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

function C.GetPlayerName()
    local name = C.SafeStr(UnitName("player"))
    return C.StripLocalRealm(name)
end

-- Strict self-mail guard: returns true if candidateName is the currently logged-in character
function C.IsCurrentPlayer(candidateName)
    if not candidateName then return false end
    local pName = C.GetPlayerName()
    if pName and C.IsSameCharacter(candidateName, pName) then
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
    return false
end

-- Scan current character's learned primary professions across Retail/Forever/MoP/TBC/Classic
function C.GetPlayerProfessions()
    local profs = {}
    local known = {
        ["Herbalism"] = true, ["Alchemy"] = true, ["Enchanting"] = true,
        ["Mining"] = true, ["Blacksmithing"] = true, ["Engineering"] = true,
        ["Jewelcrafting"] = true, ["Leatherworking"] = true, ["Skinning"] = true,
        ["Tailoring"] = true, ["Inscription"] = true,
    }

    if GetProfessions and GetProfessionInfo then
        local p1, p2 = GetProfessions()
        for _, idx in ipairs({ p1, p2 }) do
            if idx then
                local ok, name, _, rank = pcall(GetProfessionInfo, idx)
                if ok and name and not C.IsSecret(name) then
                    profs[name] = rank or 1
                end
            end
        end
        if next(profs) ~= nil then
            return profs
        end
    end

    if GetNumSkillLines and GetSkillLineInfo then
        local num = GetNumSkillLines() or 0
        for i = 1, num do
            local ok, skillName, isHeader, _, skillRank = pcall(GetSkillLineInfo, i)
            if ok and not isHeader and skillName and known[skillName] then
                profs[skillName] = skillRank or 1
            end
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

                    table.insert(results, {
                        name = cleanName,
                        level = level,
                        class = classFile,
                        faction = charFaction or faction,
                        copper = copper,
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
