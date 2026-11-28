local addonName, NS = ...
NS.MailRouter = {}
local MR = NS.MailRouter
local C = NS.Compat

MR.isMailboxOpen = false
MR.isSending = false
MR.stagedCount = 0
MR.currentRecipient = nil
MR.pendingRRAdvances = {}
MR.selectedAltCursor = 1
MR.greyOverrides = {}
MR.greyPromptFrame = nil
MR.greyPromptQueue = {}

local mailFrame = CreateFrame("Frame")
mailFrame:RegisterEvent("MAIL_SHOW")
mailFrame:RegisterEvent("MAIL_CLOSED")
mailFrame:RegisterEvent("MAIL_SEND_SUCCESS")
mailFrame:RegisterEvent("MAIL_FAILED")

local scanTip = nil
local function GetScanTooltip()
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "WOWEngineScanTooltip", nil, "GameTooltipTemplate")
        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return scanTip
end

function MR:IsSoulboundOrQuest(bag, slot, isBoundFlag)
    if isBoundFlag == true then
        return true
    end

    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local tipData = C_TooltipInfo.GetBagItem(bag, slot)
        if tipData and tipData.lines then
            for _, line in ipairs(tipData.lines) do
                local t = line.leftText
                if t and not C.IsSecret(t) then
                    if t == ITEM_SOULBOUND or t == ITEM_BIND_ON_PICKUP or t == ITEM_BIND_QUEST or t == ITEM_CONJURED
                        or string.find(t, "Soulbound") or string.find(t, "Quest Item") or string.find(t, "Warbound") then
                        return true
                    end
                end
            end
        end
        return false
    end

    local tip = GetScanTooltip()
    tip:ClearLines()
    tip:SetBagItem(bag, slot)
    for i = 2, tip:NumLines() do
        local left = _G["WOWEngineScanTooltipTextLeft" .. i]
        if left then
            local text = left:GetText()
            if text and (text == ITEM_SOULBOUND or text == ITEM_BIND_ON_PICKUP or text == ITEM_BIND_QUEST or text == ITEM_CONJURED) then
                return true
            end
        end
    end
    return false
end

-- Hard protection (cannot ever be mailed): locked, utility tools, soulbound/quest
function MR:IsHardProtected(itemID, itemLink, bag, slot, isLocked, isBoundFlag)
    if isLocked then
        return true, "locked"
    end

    if itemID == 6948 or itemID == 2901 or itemID == 5956 or itemID == 7005 or itemID == 6218 then
        return true, "utility"
    end

    if MR:IsSoulboundOrQuest(bag, slot, isBoundFlag) then
        return true, "soulbound"
    end

    if itemLink then
        local _, _, _, _, _, _, _, _, _, _, _, _, _, bindType = C.GetItemInfo(itemLink)
        if bindType == 1 or bindType == 4 then
            return true, "soulbound"
        end
    end

    return false, nil
end

-- Soft protection (addon holds): bypassed when user explicitly creates a Custom Addition for the item
function MR:IsAddonHoldProtected(itemID)
    if WOWEngineDB and WOWEngineDB.protectMastercraftQueue and C.IsMastercraftReserved(itemID) then
        return true, "mastercraft"
    end

    if WOWEngineDB and WOWEngineDB.protectAuctionatorPosted and _G.WOWEngine_AuctionatorExclude and _G.WOWEngine_AuctionatorExclude[itemID] then
        return true, "auctionator"
    end

    return false, nil
end

local function ClassifyTradeGoodByName(itemName)
    if not itemName or C.IsSecret(itemName) then return nil end
    local n = string.lower(itemName)

    if string.find(n, "peacebloom") or string.find(n, "silverleaf") or string.find(n, "earthroot")
        or string.find(n, "mageroyal") or string.find(n, "briarthorn") or string.find(n, "stranglekelp")
        or string.find(n, "bruiseweed") or string.find(n, "wild steelbloom") or string.find(n, "grave moss")
        or string.find(n, "kingsblood") or string.find(n, "liferoot") or string.find(n, "fadeleaf")
        or string.find(n, "goldthorn") or string.find(n, "khadgar") or string.find(n, "wintersbite")
        or string.find(n, "firebloom") or string.find(n, "lotus") or string.find(n, "arthas")
        or string.find(n, "sungrass") or string.find(n, "blindweed") or string.find(n, "ghost mushroom")
        or string.find(n, "gromsblood") or string.find(n, "sansam") or string.find(n, "dreamfoil")
        or string.find(n, "silversage") or string.find(n, "plaguebloom") or string.find(n, "icecap")
        or string.find(n, "swiftthistle") or string.find(n, "felweed") or string.find(n, "dreaming glory")
        or string.find(n, "ragveil") or string.find(n, "terocone") or string.find(n, "nightmare vine")
        or string.find(n, "mana thistle") or string.find(n, "herb") or string.find(n, "pigment") then
        return "Herb"
    end

    if string.find(n, "cloth") or string.find(n, "linen") or string.find(n, "wool")
        or string.find(n, "silk") or string.find(n, "mageweave") or string.find(n, "weave")
        or string.find(n, "bolt of ") or string.find(n, "thread") then
        return "Cloth"
    end

    if string.find(n, "dust") or string.find(n, "essence") or string.find(n, "shard")
        or string.find(n, "nexus crystal") or string.find(n, "void crystal") or string.find(n, "abyss crystal")
        or string.find(n, "maelstrom crystal") or string.find(n, "sha crystal") or string.find(n, "refulgent crystal")
        or string.find(n, "resonant crystal") or string.find(n, "vellum") or string.find(n, "pearl")
        or string.find(n, "righteous orb") then
        return "Enchanting"
    end

    if string.find(n, " ore") or string.find(n, " bar") or string.find(n, " stone")
        or string.find(n, "ingot") or string.find(n, "flux") or string.find(n, "coal")
        or string.find(n, "malachite") or string.find(n, "tigerseye") or string.find(n, "shadowgem")
        or string.find(n, "moss agate") or string.find(n, "moonstone") or string.find(n, "jade")
        or string.find(n, "citrine") or string.find(n, "aquamarine") or string.find(n, "star ruby")
        or string.find(n, "opal") or string.find(n, "sapphire") or string.find(n, "diamond")
        or string.find(n, "emerald") or string.find(n, "arcane crystal") then
        return "Ore"
    end

    if string.find(n, "leather") or string.find(n, " hide") or string.find(n, "scale")
        or string.find(n, "pelt") or string.find(n, "carapace") or string.find(n, "chitin") then
        return "Leather"
    end

    return nil
end

local function IsBagOrContainerItem(classID, itemEquipLoc, itemType)
    local containerClassID = (Enum and Enum.ItemClass and Enum.ItemClass.Container) or 1
    local quiverClassID = (Enum and Enum.ItemClass and Enum.ItemClass.Quiver) or 11
    if classID == containerClassID or classID == quiverClassID or itemEquipLoc == "INVTYPE_BAG" then
        return true
    end
    if itemType == "Container" or itemType == "Bag" or itemType == "Quiver" then
        return true
    end
    return false
end

function MR:ResolveCategoryForItem(itemLink, itemID)
    if not itemLink then return nil, nil end
    local itemName, _, quality, _, _, itemType, itemSubType, _, itemEquipLoc, _, _, classID, subClassID = C.GetItemInfo(itemLink)
    if classID == nil or itemEquipLoc == nil or itemEquipLoc == "" then
        local _, instType, instSubType, instEquipLoc, _, instClassID, instSubClassID = C.GetItemInfoInstant(itemLink or itemID)
        itemType = itemType or instType
        itemSubType = itemSubType or instSubType
        if not itemEquipLoc or itemEquipLoc == "" then itemEquipLoc = instEquipLoc end
        if classID == nil then classID = instClassID end
        if subClassID == nil then subClassID = instSubClassID end
    end
    if not itemName then
        if itemID then C.RequestLoadItemDataByID(itemID) end
        itemName = C.ExtractItemName(itemLink)
        if not itemName then
            return nil, nil
        end
    end

    -- Check actual WoW Container / Bag class and equip location FIRST —
    -- BEFORE any item-name keyword matching ("leather", "linen", "wool", "silk", etc.)
    -- so items like "Blue Leather Bag" are always classified as Bags/Containers.
    if IsBagOrContainerItem(classID, itemEquipLoc, itemType) then
        return "Bags", itemName
    end

    if classID == 7 then -- Tradeskill / Trade Goods
        if subClassID == 5 then return "Cloth", itemName end
        if subClassID == 12 then return "Enchanting", itemName end
        if subClassID == 9 or subClassID == 16 then return "Herb", itemName end
        if subClassID == 7 or subClassID == 1 or subClassID == 4 then return "Ore", itemName end
        if subClassID == 6 then return "Leather", itemName end
    end

    local knownSubTypes = {
        ["Cloth"] = "Cloth",
        ["Enchanting"] = "Enchanting",
        ["Herb"] = "Herb",
        ["Inscription"] = "Herb",
        ["Metal & Stone"] = "Ore",
        ["Ore"] = "Ore",
        ["Parts"] = "Ore",
        ["Jewelcrafting"] = "Ore",
        ["Leather"] = "Leather",
    }
    if itemSubType and knownSubTypes[itemSubType] then
        return knownSubTypes[itemSubType], itemName
    end

    local cat = ClassifyTradeGoodByName(itemName)
    if cat then return cat, itemName end

    -- Tradeable Uncommon/Rare/Epic Armor & Weapons (BoEs) -> Enchanter DisenchantBoE if configured, else BankAlt
    if quality and (quality >= 2 and quality <= 4) and (classID == 2 or classID == 4 or itemType == "Armor" or itemType == "Weapon") then
        -- Exclude shirts (INVTYPE_BODY) and tabards (INVTYPE_TABARD) which cannot be disenchanted
        if itemEquipLoc ~= "INVTYPE_BODY" and itemEquipLoc ~= "INVTYPE_TABARD" then
            local deTargets = NS.Roster:GetCategoryTargets("DisenchantBoE")
            if type(deTargets) == "table" and #deTargets > 0 then
                return "DisenchantBoE", itemName
            end
            return "BankAlt", itemName
        end
    end

    return nil, itemName
end

local function HasAttachmentInSlot(i)
    if HasSendMailItem then
        return HasSendMailItem(i)
    elseif GetSendMailItem then
        return GetSendMailItem(i) ~= nil
    end
    return false
end

local function ClearAllStagedMail()
    if CursorHasItem and CursorHasItem() and ClearCursor then
        ClearCursor()
    end
    -- Prefer Blizzard's ClearSendMail() which synchronously unlocks all staged bag slots
    if ClearSendMail then
        pcall(ClearSendMail)
    end
    local maxAttach = ATTACHMENTS_MAX_SEND or 12
    for i = 1, maxAttach do
        if HasAttachmentInSlot(i) then
            ClickSendMailItemButton(i, true)
        end
    end
    if CursorHasItem and CursorHasItem() and ClearCursor then
        ClearCursor()
    end
end

local function FindFirstEmptyMailSlot(maxAttach)
    for i = 1, maxAttach do
        if not HasAttachmentInSlot(i) then
            return i
        end
    end
    return nil
end

-- ============================================================
-- FIRST AID LINEN CLOTH PRIORITY (< 80) & GREY-RECIPE EVALUATOR
-- ============================================================

local CATEGORY_CRAFT_PROFS = {
    Cloth      = { "Tailoring" },
    Herb       = { "Alchemy", "Inscription" },
    Ore        = { "Blacksmithing", "Engineering", "Jewelcrafting", "Mining" },
    Leather    = { "Leatherworking" },
    Enchanting = { "Enchanting" },
}

-- Classic / WoW Forever skill ranks where common crafting reagents turn grey (no skill-up value)
local REAGENT_GREY_SKILL_BY_ID = {
    -- Cloth (Tailoring)
    [2589]  = 100, -- Linen Cloth
    [2592]  = 150, -- Wool Cloth
    [4306]  = 215, -- Silk Cloth
    [4338]  = 275, -- Mageweave Cloth
    -- Ore / Stone / Bars
    [2835]  = 65,  -- Rough Stone
    [2770]  = 100, -- Copper Ore
    [2840]  = 100, -- Copper Bar
    [2836]  = 125, -- Coarse Stone
    [2771]  = 155, -- Tin Ore
    [2841]  = 155, -- Bronze Bar
    [2775]  = 175, -- Silver Ore
    [2842]  = 175, -- Silver Bar
    [2838]  = 185, -- Heavy Stone
    [2772]  = 205, -- Iron Ore
    [3575]  = 205, -- Iron Bar
    [7912]  = 250, -- Solid Stone
    [3858]  = 265, -- Mithril Ore
    [3860]  = 265, -- Mithril Bar
    -- Leather / Hides
    [2934]  = 55,  -- Ruined Leather Scraps
    [2318]  = 115, -- Light Leather
    [783]   = 115, -- Light Hide
    [2319]  = 175, -- Medium Leather
    [4232]  = 175, -- Medium Hide
    [4234]  = 230, -- Heavy Leather
    [4235]  = 230, -- Heavy Hide
    [4304]  = 280, -- Thick Leather
    [8169]  = 280, -- Thick Hide
    -- Herbs (Alchemy)
    [2447]  = 85,  -- Peacebloom
    [765]   = 85,  -- Silverleaf
    [2449]  = 105, -- Earthroot
    [785]   = 135, -- Mageroyal
    [2450]  = 135, -- Briarthorn
    [2453]  = 165, -- Bruiseweed
    [3820]  = 165, -- Stranglekelp
    [3355]  = 200, -- Wild Steelbloom
    [3356]  = 200, -- Kingsblood
    -- Enchanting
    [10940] = 125, -- Strange Dust
    [10938] = 125, -- Lesser Magic Essence
    [11083] = 185, -- Soul Dust
    [10998] = 185, -- Lesser Astral Essence
    [11137] = 235, -- Vision Dust
    [11134] = 235, -- Lesser Mystic Essence
}

local REAGENT_GREY_SKILL_BY_NAME = {
    ["linen cloth"] = 100,
    ["wool cloth"] = 150,
    ["silk cloth"] = 215,
    ["mageweave cloth"] = 275,
    ["rough stone"] = 65,
    ["copper ore"] = 100,
    ["copper bar"] = 100,
    ["coarse stone"] = 125,
    ["tin ore"] = 155,
    ["bronze bar"] = 155,
    ["heavy stone"] = 185,
    ["iron ore"] = 205,
    ["iron bar"] = 205,
    ["solid stone"] = 250,
    ["mithril ore"] = 265,
    ["mithril bar"] = 265,
    ["ruined leather scraps"] = 55,
    ["light leather"] = 115,
    ["light hide"] = 115,
    ["medium leather"] = 175,
    ["medium hide"] = 175,
    ["heavy leather"] = 230,
    ["heavy hide"] = 230,
    ["thick leather"] = 280,
    ["thick hide"] = 280,
    ["peacebloom"] = 85,
    ["silverleaf"] = 85,
    ["earthroot"] = 105,
    ["mageroyal"] = 135,
    ["briarthorn"] = 135,
    ["bruiseweed"] = 165,
    ["stranglekelp"] = 165,
    ["strange dust"] = 125,
    ["soul dust"] = 185,
    ["vision dust"] = 235,
}

local BOLT_OF_CLOTH_IDS = {
    [2996]  = true, -- Bolt of Linen Cloth
    [2997]  = true, -- Bolt of Woolen Cloth
    [4305]  = true, -- Bolt of Silk Cloth
    [4339]  = true, -- Bolt of Mageweave
    [14048] = true, -- Bolt of Runecloth
    [21840] = true, -- Bolt of Netherweave
    [21842] = true, -- Bolt of Imbued Netherweave
    [21844] = true, -- Bolt of Soulcloth
}

-- Bolts of cloth are strictly Tailoring / crafting intermediates and must NEVER be treated as raw cloth for First Aid
function MR:IsBoltOfClothItem(itemID, itemName)
    if itemID and BOLT_OF_CLOTH_IDS[tonumber(itemID)] then
        return true
    end
    if itemName and not C.IsSecret(itemName) then
        local low = string.lower(C.Trim(itemName))
        if string.find(low, "bolt of ", 1, true) then
            return true
        end
    end
    return false
end

function MR:IsLinenClothItem(itemID, itemName)
    if MR:IsBoltOfClothItem(itemID, itemName) then
        return false
    end
    if tonumber(itemID) == 2589 then return true end
    if itemName and not C.IsSecret(itemName) then
        return string.lower(C.Trim(itemName)) == "linen cloth"
    end
    return false
end

-- Check whether targetName is a Tailor (learned or planned) or has a known recipe requiring this bolt
function MR:CanCharacterUseBolts(targetName, itemID)
    if not targetName then return false end
    local roster = NS:GetActiveRoster()
    local exact = NS.Roster:FindVerifiedName(targetName) or targetName
    local info = roster and roster[exact]
    if info and type(info.professions) == "table" then
        for pName in pairs(info.professions) do
            if type(pName) == "string" and string.find(string.lower(pName), "tailor", 1, true) then
                return true
            end
        end
    end
    if NS.Roster and NS.Roster.GetCharacterProfessionProfile then
        local prof = NS.Roster:GetCharacterProfessionProfile(exact)
        if prof then
            if (prof.p1 and prof.p1.name and string.find(string.lower(prof.p1.name), "tailor", 1, true))
                or (prof.p2 and prof.p2.name and string.find(string.lower(prof.p2.name), "tailor", 1, true)) then
                return true
            end
        end
    end
    if itemID and C.GetMastercraftTopProfitReagentInfo then
        local usesInMC = C.GetMastercraftTopProfitReagentInfo(itemID, exact)
        if usesInMC then return true end
    end
    return false
end

function MR:FilterBoltOfClothTargets(candidates, itemID)
    local out = {}
    local seen = {}
    local isSelfTailor = false

    for _, name in ipairs(candidates or {}) do
        if MR:CanCharacterUseBolts(name, itemID) then
            if C.IsCurrentPlayer(name) then
                isSelfTailor = true
            else
                local k = C.CanonicalCharKey(name)
                if k and not seen[k] then
                    seen[k] = true
                    table.insert(out, name)
                end
            end
        end
    end

    -- Fallback: if no configured Cloth recipient was a Tailor, check verified own roster for Tailors
    if #out == 0 then
        local roster = NS:GetActiveRoster()
        for exactName, info in pairs(roster) do
            if info and info.verified and not NS.Roster:IsExcludedFromMail(info) then
                local isOwn = (info.isOwnAlt == true) or (info.source == "login") or (info.source == "altoholic")
                if isOwn and MR:CanCharacterUseBolts(exactName, itemID) then
                    if C.IsCurrentPlayer(exactName) then
                        isSelfTailor = true
                    else
                        local k = C.CanonicalCharKey(exactName)
                        if k and not seen[k] then
                            seen[k] = true
                            table.insert(out, exactName)
                        end
                    end
                end
            end
        end
        table.sort(out, function(a, b) return string.lower(a) < string.lower(b) end)
    end

    if isSelfTailor and WOWEngineDB and WOWEngineDB.keepOwnCategoryMats then
        return {}, true
    end
    return out, isSelfTailor
end

function MR:GetFirstAidSkill(charInfo)
    if type(charInfo) ~= "table" then return nil end
    if type(charInfo.subProfessions) == "table" then
        for k, v in pairs(charInfo.subProfessions) do
            if type(k) == "string" and string.find(string.lower(k), "first aid", 1, true) then
                return tonumber(v) or 0
            end
        end
    end
    if type(charInfo.professions) == "table" then
        for k, v in pairs(charInfo.professions) do
            if type(k) == "string" and string.find(string.lower(k), "first aid", 1, true) then
                return tonumber(v) or 0
            end
        end
    end
    -- Own logged-in character whose subProfessions were scanned without First Aid -> skill 0 (< 80)
    if charInfo.source == "login" or type(charInfo.subProfessions) == "table" then
        return 0
    end
    return nil
end

-- Returns priority recipients needing Linen Cloth for First Aid (skill < 80).
-- Characters at 80+ First Aid are automatically excluded from First Aid Linen priority.
function MR:GetFirstAidLinenPriorityTargets()
    local roster = NS:GetActiveRoster()
    local candidates = {}
    local isSelfNeedsFA = false

    for exactName, info in pairs(roster) do
        if info and info.verified and not NS.Roster:IsExcludedFromMail(info) then
            local isOwn = (info.isOwnAlt == true) or (info.source == "login") or (info.source == "altoholic")
            if isOwn then
                local faSkill = MR:GetFirstAidSkill(info)
                if faSkill ~= nil and faSkill < 80 then
                    if C.IsCurrentPlayer(exactName) then
                        isSelfNeedsFA = true
                    else
                        table.insert(candidates, {
                            name = exactName,
                            faSkill = faSkill,
                            level = tonumber(info.level) or 0,
                        })
                    end
                end
            end
        end
    end

    -- Prioritize characters already training First Aid (1..79) closest to 80, then by level
    table.sort(candidates, function(a, b)
        local aStarted = a.faSkill > 0 and 1 or 0
        local bStarted = b.faSkill > 0 and 1 or 0
        if aStarted ~= bStarted then return aStarted > bStarted end
        if a.faSkill ~= b.faSkill then return a.faSkill > b.faSkill end
        if a.level ~= b.level then return a.level > b.level end
        return string.lower(a.name) < string.lower(b.name)
    end)

    local eligible = {}
    for _, c in ipairs(candidates) do
        table.insert(eligible, c.name)
    end
    if isSelfNeedsFA and WOWEngineDB and WOWEngineDB.keepOwnCategoryMats then
        return {}, true
    end
    return eligible, isSelfNeedsFA
end

-- Checks whether a trade-good reagent's recipes have turned grey (no skill-up value) for targetName
function MR:IsReagentGreyForTarget(itemID, itemName, cat, targetName)
    if not targetName or not cat then return false, nil, nil end
    if cat == "Bags" or cat == "BankAlt" or cat == "DisenchantBoE" then return false, nil, nil end

    -- 1. Check Mastercraft's live recipe difficulty cache if available
    local mcGrey = C.IsMastercraftReagentGrey and C.IsMastercraftReagentGrey(itemID, targetName)
    if mcGrey == false then
        return false, nil, nil
    end

    local roster = NS:GetActiveRoster()
    local exact = NS.Roster:FindVerifiedName(targetName) or targetName
    local info = roster and roster[exact]

    -- Special case: raw Linen Cloth (never Bolts of Cloth!) is not grey if target still needs First Aid < 80
    if not MR:IsBoltOfClothItem(itemID, itemName) and MR:IsLinenClothItem(itemID, itemName) and info then
        local faSkill = MR:GetFirstAidSkill(info)
        if faSkill ~= nil and faSkill < 80 then
            return false, "First Aid", faSkill
        end
    end

    if mcGrey == true then
        return true, cat, nil
    end

    -- 2. Check reagent grey skill-up ceiling against target's crafting profession rank
    local greyAt = (itemID and REAGENT_GREY_SKILL_BY_ID[tonumber(itemID)])
        or (itemName and REAGENT_GREY_SKILL_BY_NAME[string.lower(C.Trim(itemName))])
    if not greyAt or not info or type(info.professions) ~= "table" then
        return false, nil, nil
    end

    local profNames = CATEGORY_CRAFT_PROFS[cat]
    if not profNames then return false, nil, nil end

    local sawProf = false
    local lowestRelevantSkill = nil
    local matchedProf = nil
    for _, pName in ipairs(profNames) do
        local r = tonumber(info.professions[pName])
        if r and r > 0 then
            sawProf = true
            if lowestRelevantSkill == nil or r < lowestRelevantSkill then
                lowestRelevantSkill = r
                matchedProf = pName
            end
        end
    end

    if sawProf and lowestRelevantSkill and lowestRelevantSkill >= greyAt then
        return true, matchedProf, lowestRelevantSkill
    end
    return false, matchedProf, lowestRelevantSkill
end

local function MakeGreyOverrideKey(itemID, itemName, targetName)
    local itemPart = itemID and tostring(itemID) or string.lower(tostring(itemName or "?"))
    local charPart = C.CanonicalCharKey(targetName) or string.lower(tostring(targetName or "?"))
    return itemPart .. "::" .. charPart
end

function MR:ShowNextGreyOverridePopup()
    if not MR.greyPromptQueue or #MR.greyPromptQueue == 0 then return end
    local entry = table.remove(MR.greyPromptQueue, 1)
    if not entry then return end
    MR:ShowGreyOverridePopup(entry)
end

-- Clean Blizzard blue-and-gold popup dialog for grey-recipe reagent overrides (visual routing only; never calls SendMail)
function MR:ShowGreyOverridePopup(entry)
    if not entry then return end
    if not MR.greyPromptFrame then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local f = CreateFrame("Frame", "WOWEngineGreyOverrideFrame", UIParent, template)
        f:SetSize(430, 195)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(160)
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
                f:SetBackdropColor(0.04, 0.09, 0.19, 0.98)
                f:SetBackdropBorderColor(0.95, 0.78, 0.18, 1.0)
            end)
        end

        if UISpecialFrames then
            table.insert(UISpecialFrames, "WOWEngineGreyOverrideFrame")
        end

        local headerBg = f:CreateTexture(nil, "ARTWORK")
        headerBg:SetPoint("TOPLEFT", 4, -4)
        headerBg:SetPoint("TOPRIGHT", -4, -4)
        headerBg:SetHeight(34)
        headerBg:SetColorTexture(0.06, 0.16, 0.34, 0.95)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 14, -11)
        title:SetText("|cff00aeffWOWEngine|r |cffffd100Grey-Recipe Reagent Override|r")

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function()
            f:Hide()
            MR:ShowNextGreyOverridePopup()
        end)

        local itemTxt = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        itemTxt:SetPoint("TOPLEFT", 16, -48)
        itemTxt:SetWidth(398)
        itemTxt:SetJustifyH("LEFT")
        f.itemTxt = itemTxt

        local bodyTxt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        bodyTxt:SetPoint("TOPLEFT", itemTxt, "BOTTOMLEFT", 0, -8)
        bodyTxt:SetWidth(398)
        bodyTxt:SetJustifyH("LEFT")
        f.bodyTxt = bodyTxt

        local overrideBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        overrideBtn:SetSize(148, 24)
        overrideBtn:SetPoint("BOTTOMLEFT", 16, 14)
        overrideBtn:SetText("Override & Send")
        overrideBtn:SetScript("OnClick", function()
            local cur = f.currentEntry
            f:Hide()
            if cur and cur.overrideKey then
                MR.greyOverrides[cur.overrideKey] = "send"
                NS:Print(string.format("Override approved: marked |cffffd100%s|r to stage for |cff00ff00%s|r (click Send manually).",
                    tostring(cur.itemName or "item"), tostring(cur.target or "alt")))
                if #MR.greyPromptQueue > 0 then
                    MR:ShowNextGreyOverridePopup()
                elseif MR.isMailboxOpen or (MailFrame and MailFrame:IsShown()) then
                    pcall(function() MR:StageNextBatch(cur.forcedTarget) end)
                end
            end
        end)
        f.overrideBtn = overrideBtn

        local skipBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        skipBtn:SetSize(104, 24)
        skipBtn:SetPoint("BOTTOMRIGHT", -16, 14)
        skipBtn:SetText("Skip")
        skipBtn:SetScript("OnClick", function()
            local cur = f.currentEntry
            f:Hide()
            if cur and cur.overrideKey then
                MR.greyOverrides[cur.overrideKey] = "skip"
                NS:Print(string.format("Skipped grey-recipe reagent |cffffd100%s|r for |cffaaaaaa%s|r.",
                    tostring(cur.itemName or "item"), tostring(cur.target or "alt")))
            end
            MR:ShowNextGreyOverridePopup()
        end)
        f.skipBtn = skipBtn

        MR.greyPromptFrame = f
    end

    local f = MR.greyPromptFrame
    f.currentEntry = entry
    local profMeta = entry.profName and (entry.skillRank and (entry.profName .. " " .. tostring(entry.skillRank)) or entry.profName) or "Crafting"
    f.itemTxt:SetText(string.format("|cffffd100%s|r  ->  |cff00ff00%s|r (%s)",
        tostring(entry.itemName or "Reagent"), tostring(entry.target or "Alt"), profMeta))

    if entry.isTop3 then
        local craftNote = entry.recipeName and ("\n|cff00aeffTop #" .. tostring(entry.profitRank or 1) .. " Craft:|r " .. tostring(entry.recipeName)) or ""
        f.bodyTxt:SetText("Recipe is grey for skill-ups, but Mastercraft ranks this in the Top 3 for profit. Override and mark to send anyway?" .. craftNote)
    else
        f.bodyTxt:SetText("Recipe is grey for skill-ups for this character and is not in Mastercraft's Top 3 for profit. Override and mark to send anyway?")
    end

    f:Show()
    f:Raise()
end

function MR:BuildShipmentPlan(forcedTarget)
    local maxBags = C.GetMaxBagIndex()
    local mode = (WOWEngineDB and WOWEngineDB.multiAltMode) or "roundrobin"
    local rrCursors = NS:GetRRCursors()
    local localOffset = {}
    local simBagState = {}

    local byRecipient = {}
    local recipientOrder = {}

    local stats = {
        totalScanned = 0,
        skippedBound = 0,
        skippedMC = 0,
        skippedGrey = 0,
        keptForSelf = 0,
        customMatched = 0,
        missingCats = {},
        greyPrompts = {},
    }
    local queuedPromptKeys = {}

    local function queueGreyPrompt(overrideKey, itemID, cleanName, targetName, profName, skillRank, isTop3, recipeName, profitRank, forced)
        if not queuedPromptKeys[overrideKey] then
            queuedPromptKeys[overrideKey] = true
            table.insert(stats.greyPrompts, {
                overrideKey = overrideKey,
                itemID = itemID,
                itemName = cleanName,
                target = targetName,
                profName = profName,
                skillRank = skillRank,
                isTop3 = isTop3 and true or false,
                recipeName = recipeName,
                profitRank = profitRank,
                forcedTarget = forced,
            })
        end
    end

    local function filterGreyTargets(candidates, itemID, cleanName, cat, forced)
        local allowed = {}
        local hadGreySkip = false
        for _, targetName in ipairs(candidates) do
            local isGrey, profName, skillRank = MR:IsReagentGreyForTarget(itemID, cleanName, cat, targetName)
            if not isGrey then
                table.insert(allowed, targetName)
            else
                local oKey = MakeGreyOverrideKey(itemID, cleanName, targetName)
                local decision = MR.greyOverrides[oKey]
                if decision == "send" then
                    table.insert(allowed, targetName)
                elseif decision == "skip" then
                    hadGreySkip = true
                else
                    hadGreySkip = true
                    local isTop3, recipeName, profitRank = C.GetMastercraftTopProfitReagentInfo(itemID, targetName)
                    if isTop3 or forced then
                        queueGreyPrompt(oKey, itemID, cleanName, targetName, profName, skillRank, isTop3, recipeName, profitRank, forced)
                    end
                end
            end
        end
        return allowed, hadGreySkip
    end

    for bag = 0, maxBags do
        local numSlots = C.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local _, _, isLocked, _, link, itemID, isBound = C.GetContainerItemDetails(bag, slot)
            if not link then
                link = C.GetContainerItemLink(bag, slot)
            end
            if link then
                stats.totalScanned = stats.totalScanned + 1
                itemID = itemID or C.ExtractItemID(link)
                local hardProtected = MR:IsHardProtected(itemID, link, bag, slot, isLocked, isBound)
                if hardProtected then
                    stats.skippedBound = stats.skippedBound + 1
                else
                    local dest = nil
                    local cat, itemName = MR:ResolveCategoryForItem(link, itemID)
                    local cleanName = itemName or C.ExtractItemName(link)
                    local routeLabel = cat

                    if forcedTarget then
                        local addonHeld = MR:IsAddonHoldProtected(itemID)
                        if addonHeld then
                            stats.skippedMC = stats.skippedMC + 1
                        else
                            local allowedForced, hadGrey = filterGreyTargets({ forcedTarget }, itemID, cleanName, cat, forcedTarget)
                            if #allowedForced > 0 then
                                dest = allowedForced[1]
                                routeLabel = cat or "Direct"
                            elseif hadGrey then
                                stats.skippedGrey = stats.skippedGrey + 1
                            end
                        end
                    else
                        -- Priority 1: User's explicit Custom Additions (runs BEFORE Mastercraft/Auctionator holds!)
                        local customEligible, customSelf = NS.Roster:FindCustomTargetsForItem(cleanName, itemID)
                        if #customEligible > 0 or customSelf then
                            routeLabel = "Custom"
                            stats.customMatched = stats.customMatched + 1
                            if #customEligible == 0 and customSelf then
                                stats.keptForSelf = stats.keptForSelf + 1
                            elseif #customEligible == 1 or mode == "priority" then
                                dest = customEligible[1]
                            else
                                local baseIdx = tonumber(rrCursors["Custom"]) or 1
                                local off = localOffset["Custom"] or 0
                                local pickIdx = ((baseIdx - 1 + off) % #customEligible) + 1
                                dest = customEligible[pickIdx]
                                localOffset["Custom"] = off + 1
                            end
                        else
                            -- Priority 1.5: Bag / Container Routing (runs BEFORE standard trade-good categories;
                            -- tries smart bag-upgrade recipient first, then Bags / BankAlt fallback for surplus bags)
                            local bagInfo = NS.BagRouter and NS.BagRouter:InspectBagItem(link, itemID, bag, slot) or nil
                            if cat == "Bags" or bagInfo then
                                routeLabel = "Bags"
                                local addonHeld = MR:IsAddonHoldProtected(itemID)
                                if addonHeld then
                                    stats.skippedMC = stats.skippedMC + 1
                                else
                                    local bagDest = bagInfo and NS.BagRouter:FindBestRecipientForBag(bagInfo, simBagState) or nil
                                    if bagDest then
                                        dest = bagDest
                                    else
                                        local bagEligible, bagSelf = NS.Roster:GetEligibleTargetsForCategory("Bags")
                                        if #bagEligible == 0 and not bagSelf then
                                            bagEligible, bagSelf = NS.Roster:GetEligibleTargetsForCategory("BankAlt")
                                        end
                                        if #bagEligible == 0 then
                                            if bagSelf then
                                                stats.keptForSelf = stats.keptForSelf + 1
                                            end
                                        elseif #bagEligible == 1 or mode == "priority" then
                                            dest = bagEligible[1]
                                        else
                                            local baseIdx = tonumber(rrCursors["Bags"]) or 1
                                            local off = localOffset["Bags"] or 0
                                            local pickIdx = ((baseIdx - 1 + off) % #bagEligible) + 1
                                            dest = bagEligible[pickIdx]
                                            localOffset["Bags"] = off + 1
                                        end
                                    end
                                end
                            else
                            -- Priority 2: Standard Category Routing (with First Aid < 80 Linen priority & Grey-Recipe Mastercraft profit check)
                            local addonHeld = MR:IsAddonHoldProtected(itemID)
                            if addonHeld then
                                stats.skippedMC = stats.skippedMC + 1
                            elseif cat then
                                local eligible, isSelfAssigned = NS.Roster:GetEligibleTargetsForCategory(cat)
                                local usedFirstAidPriority = false
                                local isBoltOfCloth = MR:IsBoltOfClothItem(itemID, cleanName)

                                -- Bolts of Cloth (Bolt of Linen/Woolen/Silk/Mageweave/Runecloth, etc.)
                                -- are NEVER routed to First Aid; route strictly to Tailors or characters
                                -- whose profession/recipe specifically requires bolts.
                                if isBoltOfCloth then
                                    eligible, isSelfAssigned = MR:FilterBoltOfClothTargets(eligible, itemID)
                                elseif MR:IsLinenClothItem(itemID, cleanName) then
                                    -- First Aid Linen Cloth Evaluator Priority (raw Linen Cloth ONLY):
                                    -- Automatically include any own character with First Aid < 80 ahead of standard Cloth recipients;
                                    -- once a character hits 80+ First Aid they drop off this priority list automatically.
                                    local faEligible, faSelf = MR:GetFirstAidLinenPriorityTargets()
                                    if faSelf and #faEligible == 0 and WOWEngineDB and WOWEngineDB.keepOwnCategoryMats then
                                        eligible = {}
                                        isSelfAssigned = true
                                    elseif #faEligible > 0 then
                                        local merged = {}
                                        local seenMerge = {}
                                        for _, faTarget in ipairs(faEligible) do
                                            local mk = C.CanonicalCharKey(faTarget)
                                            if mk and not seenMerge[mk] then
                                                seenMerge[mk] = true
                                                table.insert(merged, faTarget)
                                            end
                                        end
                                        for _, stdTarget in ipairs(eligible) do
                                            local mk = C.CanonicalCharKey(stdTarget)
                                            if mk and not seenMerge[mk] then
                                                seenMerge[mk] = true
                                                table.insert(merged, stdTarget)
                                            end
                                        end
                                        eligible = merged
                                        usedFirstAidPriority = true
                                    end
                                end

                                -- Filter out characters whose recipes for this reagent have turned grey
                                -- (unless approved via Mastercraft Top-3 profit override)
                                local hadGreySkip = false
                                if #eligible > 0 then
                                    eligible, hadGreySkip = filterGreyTargets(eligible, itemID, cleanName, cat, nil)
                                end

                                if #eligible == 0 then
                                    if hadGreySkip then
                                        stats.skippedGrey = stats.skippedGrey + 1
                                    elseif isSelfAssigned then
                                        stats.keptForSelf = stats.keptForSelf + 1
                                    else
                                        stats.missingCats[cat] = true
                                    end
                                elseif #eligible == 1 or mode == "priority" then
                                    dest = eligible[1]
                                    if usedFirstAidPriority then
                                        local rInfo = NS:GetActiveRoster()[dest]
                                        local faSk = rInfo and MR:GetFirstAidSkill(rInfo)
                                        if faSk ~= nil and faSk < 80 then
                                            routeLabel = "FirstAid"
                                        end
                                    end
                                else
                                    local rrKey = usedFirstAidPriority and "FirstAid" or cat
                                    local baseIdx = tonumber(rrCursors[rrKey]) or 1
                                    local off = localOffset[rrKey] or 0
                                    local pickIdx = ((baseIdx - 1 + off) % #eligible) + 1
                                    dest = eligible[pickIdx]
                                    localOffset[rrKey] = off + 1
                                    if usedFirstAidPriority then
                                        local rInfo = NS:GetActiveRoster()[dest]
                                        local faSk = rInfo and MR:GetFirstAidSkill(rInfo)
                                        if faSk ~= nil and faSk < 80 then
                                            routeLabel = "FirstAid"
                                        end
                                    end
                                end
                            end
                            end
                        end
                    end

                    -- Final absolute self-mail guard
                    if dest and not C.IsCurrentPlayer(dest) then
                        local rKey = C.CanonicalCharKey(dest)
                        if rKey then
                            if not byRecipient[rKey] then
                                byRecipient[rKey] = {
                                    name = dest,
                                    items = {},
                                    catCounts = {},
                                    rrCats = {},
                                }
                                table.insert(recipientOrder, rKey)
                            end
                            local bucket = byRecipient[rKey]
                            table.insert(bucket.items, { bag = bag, slot = slot, cat = routeLabel or "Item", name = cleanName })
                            bucket.catCounts[routeLabel or "Item"] = (bucket.catCounts[routeLabel or "Item"] or 0) + 1
                            if mode == "roundrobin" and routeLabel and routeLabel ~= "Direct" then
                                bucket.rrCats[routeLabel] = true
                            end
                        end
                    elseif dest and C.IsCurrentPlayer(dest) then
                        stats.keptForSelf = stats.keptForSelf + 1
                    end
                end
            end
        end
    end

    table.sort(recipientOrder, function(a, b)
        return string.lower(byRecipient[a].name) < string.lower(byRecipient[b].name)
    end)

    return byRecipient, recipientOrder, stats
end

-- Diagnostic helper: shows exactly which bag items match each Custom Addition rule
function MR:DiagnoseCustomMatches()
    local custom = NS:GetCustomRules()
    NS:Print("=== Custom Additions Bag Match Test (Bags 0.." .. tostring(C.GetMaxBagIndex()) .. ") ===")
    if #custom == 0 then
        NS:Print("  No custom additions configured yet. Click an item in your bags inside Custom Additions and click + Add.")
        return
    end

    local maxBags = C.GetMaxBagIndex()
    for idx, entry in ipairs(custom) do
        local kw = C.ExtractItemName(entry.keyword) or "?"
        local target = entry.target or "?"
        local isSelf = C.IsCurrentPlayer(target)
        local hits = 0
        local blockedReason = nil

        for bag = 0, maxBags do
            local numSlots = C.GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local _, _, isLocked, _, link, itemID, isBound = C.GetContainerItemDetails(bag, slot)
                if not link then link = C.GetContainerItemLink(bag, slot) end
                if link then
                    itemID = itemID or C.ExtractItemID(link)
                    local cleanName = C.ExtractItemName(link)
                    local matched = false
                    if itemID and entry.itemID and tonumber(entry.itemID) == tonumber(itemID) then
                        matched = true
                    elseif cleanName and string.find(string.lower(cleanName), string.lower(kw), 1, true) then
                        matched = true
                    end
                    if matched then
                        local hardProt, reason = MR:IsHardProtected(itemID, link, bag, slot, isLocked, isBound)
                        if hardProt then
                            blockedReason = reason
                        else
                            hits = hits + 1
                        end
                    end
                end
            end
        end

        if isSelf then
            NS:Print(string.format("  #%d '|cffffd100%s|r' -> |cff00aeff%s (You)|r: %d in bags (kept on self — switch to another alt to mail here)", idx, kw, target, hits))
        elseif hits > 0 then
            NS:Print(string.format("  #%d '|cffffd100%s|r' -> |cff00ff00%s|r: |cff00ff00READY (%d stack(s) in bags)|r", idx, kw, target, hits))
        elseif blockedReason then
            NS:Print(string.format("  #%d '|cffffd100%s|r' -> |cffff9900%s|r: found in bags but blocked (%s)", idx, kw, target, blockedReason))
        else
            NS:Print(string.format("  #%d '|cffffd100%s|r' -> |cffaaaaaa%s|r: 0 matching items currently in bags 0..%d", idx, kw, target, maxBags))
        end
    end
end

-- 1-click staging for ONLY AH / Disenchantable BoEs to your opted-in Enchanter (or BankAlt fallback)
function MR:StageBoEsOnly()
    if MailFrame and MailFrame:IsShown() then
        MR.isMailboxOpen = true
    end
    if not MR.isMailboxOpen then
        NS:Print("|cffff4444Open a mailbox first before staging AH / Disenchantable BoEs.|r")
        return 0
    end
    if MR.isSending then
        NS:Print("|cffffd100Waiting for MAIL_SEND_SUCCESS before staging next batch...|r")
        return 0
    end

    NS.Roster:ScanAll(true)
    local eligible, isSelf = NS.Roster:GetEligibleTargetsForCategory("DisenchantBoE")
    local catUsed = "DisenchantBoE"
    if #eligible == 0 and not isSelf then
        eligible, isSelf = NS.Roster:GetEligibleTargetsForCategory("BankAlt")
        catUsed = "BankAlt"
    end

    if #eligible == 0 then
        if isSelf then
            NS:Print("You are currently logged into the designated AH / Disenchantable BoE recipient (self-mail blocked).")
        else
            NS:Print("|cffff9900No Enchanter or BankAlt assigned for BoEs.|r Open |cffffd100/he setup|r -> Step 3 and check 'Enchanter: Send all AH / Disenchantable BoEs here'.")
        end
        return 0
    end

    local targetRecipient = eligible[1]
    if C.IsCurrentPlayer(targetRecipient) then
        NS:Print("|cffff4444Blocked:|r Refused self-mail to " .. tostring(targetRecipient) .. ".")
        return 0
    end

    if SendMailFrame and not SendMailFrame:IsShown() then
        if MailFrameTab_OnClick and MailFrameTab2 then
            pcall(MailFrameTab_OnClick, MailFrameTab2, 2)
        elseif MailFrameTab2 then
            pcall(function() MailFrameTab2:Click() end)
        end
    end

    ClearAllStagedMail()

    local maxBags = C.GetMaxBagIndex()
    local maxAttach = ATTACHMENTS_MAX_SEND or 12
    local staged = 0

    for bag = 0, maxBags do
        local numSlots = C.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            if staged >= maxAttach then break end
            local _, _, isLocked, _, link, itemID, isBound = C.GetContainerItemDetails(bag, slot)
            if not link then link = C.GetContainerItemLink(bag, slot) end
            if link then
                itemID = itemID or C.ExtractItemID(link)
                local hardProt = MR:IsHardProtected(itemID, link, bag, slot, isLocked, isBound)
                if not hardProt then
                    local cat = MR:ResolveCategoryForItem(link, itemID)
                    if cat == "DisenchantBoE" or cat == "BankAlt" then
                        local emptySlot = FindFirstEmptyMailSlot(maxAttach)
                        if not emptySlot then break end
                        C.PickupContainerItem(bag, slot)
                        ClickSendMailItemButton(emptySlot)
                        if CursorHasItem and CursorHasItem() then
                            ClearCursor()
                        else
                            staged = staged + 1
                        end
                    end
                end
            end
        end
        if staged >= maxAttach then break end
    end

    if staged > 0 then
        MR.currentRecipient = targetRecipient
        MR.stagedCount = staged
        if SendMailNameEditBox then
            SendMailNameEditBox:SetText(targetRecipient)
        end
        if SendMailSubjectEditBox then
            SendMailSubjectEditBox:SetText("WOWEngine: AH/DE BoEs (" .. staged .. ")")
        end
        if SendMailFrame_CanSend then
            pcall(SendMailFrame_CanSend)
        end
        NS:Print(string.format("Staged |cff00ff00%d|r AH / Disenchantable BoE(s) [%s] for |cffffd100%s|r. Click |cff00aeffSend|r.", staged, catUsed, targetRecipient))
    else
        NS:Print("No tradeable AH / Disenchantable BoEs found in bags 0.." .. tostring(maxBags) .. ".")
    end
    return staged
end

function MR:CycleTarget(delta)
    MR.selectedAltCursor = (MR.selectedAltCursor or 1) + (delta or 1)
    return MR:StageNextBatch(nil)
end

function MR:CyclePrevTarget()
    return MR:CycleTarget(-1)
end

function MR:CycleNextTarget()
    return MR:CycleTarget(1)
end

function MR:StageNextBatch(explicitRecipient)
    if MailFrame and MailFrame:IsShown() then
        MR.isMailboxOpen = true
    end

    if not MR.isMailboxOpen then
        NS:Print("|cffff4444Open a mailbox first before staging a shipment.|r")
        return 0
    end
    if MR.isSending then
        NS:Print("|cffffd100Waiting for MAIL_SEND_SUCCESS before staging next batch...|r")
        return 0
    end

    NS.Roster:ScanAll(true)

    local playerName = C.GetPlayerName() or "Current Character"
    local forcedTarget = nil

    if explicitRecipient and C.Trim(explicitRecipient) ~= "" then
        local raw = C.Trim(explicitRecipient)
        local bypass = false
        if string.sub(raw, 1, 1) == "!" then
            bypass = true
            raw = C.Trim(string.sub(raw, 2))
        end

        if C.IsCurrentPlayer(raw) then
            NS:Print("|cffff4444Blocked:|r A character cannot mail items to themselves (" .. playerName .. ").")
            return 0
        end

        local verifiedExact = NS.Roster:FindVerifiedName(raw)
        if verifiedExact then
            forcedTarget = verifiedExact
        elseif bypass then
            forcedTarget = C.NormalizeRecipient(raw)
            NS:Print("|cffff9900Unverified override:|r forcing recipient '" .. tostring(forcedTarget) .. "'.")
        else
            NS:Print("|cffff4444Blocked send:|r '" .. raw .. "' was not found in your verified characters.")
            NS:Print("Open |cffffd100/he setup|r to scan Altoholic/Guild/Friends and verify exact alt names.")
            return 0
        end

        if C.IsCurrentPlayer(forcedTarget) then
            NS:Print("|cffff4444Blocked:|r A character cannot mail items to themselves (" .. playerName .. ").")
            return 0
        end
    end

    -- Switch cleanly to Send Mail tab (Tab 2)
    if SendMailFrame and not SendMailFrame:IsShown() then
        if MailFrameTab_OnClick and MailFrameTab2 then
            pcall(MailFrameTab_OnClick, MailFrameTab2, 2)
        elseif MailFrameTab2 then
            pcall(function() MailFrameTab2:Click() end)
        end
    end

    -- Synchronously clear and unlock any previously staged attachments BEFORE scanning bags
    ClearAllStagedMail()

    local byRecipient, recipientOrder, stats = MR:BuildShipmentPlan(forcedTarget)

    -- Queue any pending grey-recipe Mastercraft Top-3 profit override popups (visual prompt only; no automated SendMail)
    if stats.greyPrompts and #stats.greyPrompts > 0 then
        MR.greyPromptQueue = {}
        for _, gp in ipairs(stats.greyPrompts) do
            table.insert(MR.greyPromptQueue, gp)
        end
        if not (MR.greyPromptFrame and MR.greyPromptFrame:IsShown()) then
            MR:ShowNextGreyOverridePopup()
        end
    end

    if #recipientOrder == 0 then
        MR.currentRecipient = nil
        MR.stagedCount = 0
        MR.pendingRRAdvances = {}

        local missingList = {}
        for k in pairs(stats.missingCats) do table.insert(missingList, k) end
        table.sort(missingList)

        if stats.greyPrompts and #stats.greyPrompts > 0 then
            NS:Print("|cffffd100Grey-recipe reagent override dialog opened.|r Choose |cff00ff00Override & Send|r or |cffaaaaaaSkip|r.")
        elseif stats.skippedGrey and stats.skippedGrey > 0 then
            NS:Print(string.format("Skipped |cffffd100%d|r grey-recipe reagent(s) with no skill-up value.", stats.skippedGrey))
        elseif #missingList > 0 then
            NS:Print("|cffff9900No recipient alt assigned for:|r " .. table.concat(missingList, ", ") .. ". Open |cffffd100/he setup|r -> Step 3 to assign alts.")
        elseif stats.keptForSelf > 0 then
            NS:Print(string.format("Nothing to mail out: kept |cff00aeff%d|r item(s) belonging to |cffffd100%s|r (a character cannot mail to themselves).", stats.keptForSelf, playerName))
        else
            NS:Print(string.format(
                "Scanned %d bag items across bags 0..%d (0 staged: %d soulbound/protected, %d held by Mastercraft). Run |cffffd100/he testcustom|r to inspect custom rules.",
                stats.totalScanned, C.GetMaxBagIndex(), stats.skippedBound, stats.skippedMC
            ))
        end
        return 0
    end

    if MR.selectedAltCursor > #recipientOrder then
        MR.selectedAltCursor = 1
    elseif MR.selectedAltCursor < 1 then
        MR.selectedAltCursor = #recipientOrder
    end
    local pickedKey = recipientOrder[MR.selectedAltCursor]
    local bucket = byRecipient[pickedKey]
    local targetRecipient = bucket.name

    if C.IsCurrentPlayer(targetRecipient) then
        NS:Print("|cffff4444Blocked:|r Refused self-mail to " .. playerName .. ".")
        return 0
    end

    local maxAttach = ATTACHMENTS_MAX_SEND or 12
    local staged = 0
    local stagedByCat = {}
    for _, entry in ipairs(bucket.items) do
        if staged >= maxAttach then break end
        local emptySlot = FindFirstEmptyMailSlot(maxAttach)
        if not emptySlot then break end

        C.PickupContainerItem(entry.bag, entry.slot)
        ClickSendMailItemButton(emptySlot)
        if CursorHasItem and CursorHasItem() then
            ClearCursor()
        else
            staged = staged + 1
            stagedByCat[entry.cat] = (stagedByCat[entry.cat] or 0) + 1
        end
    end

    if staged > 0 then
        MR.currentRecipient = targetRecipient
        MR.stagedCount = staged
        MR.pendingRRAdvances = bucket.rrCats or {}

        local breakdown = {}
        local catNames = {}
        for cName, cnt in pairs(stagedByCat) do
            table.insert(breakdown, cName .. ": " .. cnt)
            table.insert(catNames, cName)
        end
        table.sort(breakdown)
        table.sort(catNames)

        if SendMailNameEditBox then
            SendMailNameEditBox:SetText(targetRecipient)
        end
        if SendMailSubjectEditBox then
            SendMailSubjectEditBox:SetText("WOWEngine: " .. table.concat(catNames, "+") .. " (" .. staged .. ")")
        end
        if SendMailFrame_CanSend then
            pcall(SendMailFrame_CanSend)
        end

        local extraNotes = {}
        if stats.keptForSelf > 0 then
            table.insert(extraNotes, stats.keptForSelf .. " kept for self")
        end
        if stats.skippedMC > 0 then
            table.insert(extraNotes, stats.skippedMC .. " held for Mastercraft")
        end
        if #recipientOrder > 1 then
            local others = {}
            for idx, rk in ipairs(recipientOrder) do
                if idx ~= MR.selectedAltCursor then
                    table.insert(others, byRecipient[rk].name .. " (" .. #byRecipient[rk].items .. ")")
                end
            end
            table.insert(extraNotes, "waiting: " .. table.concat(others, ", "))
        end
        local noteStr = (#extraNotes > 0) and (" [" .. table.concat(extraNotes, " | ") .. "]") or ""

        NS:Print(string.format(
            "Staged |cff00ff00%d|r items (%s) for verified alt |cffffd100%s|r (%d/%d)%s. Click |cff00aeffSend|r.",
            staged, table.concat(breakdown, ", "), targetRecipient, MR.selectedAltCursor, #recipientOrder, noteStr
        ))
    else
        MR.currentRecipient = nil
        MR.stagedCount = 0
        MR.pendingRRAdvances = {}
        NS:Print("|cffff9900Could not attach items to mail slots.|r Make sure items are unlocked and tradeable.")
    end

    return staged
end

mailFrame:SetScript("OnEvent", function(self, event)
    if event == "MAIL_SHOW" then
        MR.isMailboxOpen = true
        MR.isSending = false
        MR.selectedAltCursor = 1
    elseif event == "MAIL_CLOSED" then
        MR.isMailboxOpen = false
        MR.isSending = false
        MR.stagedCount = 0
        MR.currentRecipient = nil
        MR.pendingRRAdvances = {}
    elseif event == "MAIL_SEND_SUCCESS" then
        MR.isSending = false
        if MR.pendingRRAdvances then
            local rrCursors = NS:GetRRCursors()
            for catKey in pairs(MR.pendingRRAdvances) do
                rrCursors[catKey] = (tonumber(rrCursors[catKey]) or 1) + 1
            end
            MR.pendingRRAdvances = {}
        end
        NS:Print("|cff00ff00Batch delivered|r to " .. (MR.currentRecipient or "recipient") .. ". Click Stage Shipment for the next batch.")
        MR.stagedCount = 0
    elseif event == "MAIL_FAILED" then
        MR.isSending = false
        NS:Print("|cffff4444Mail send failed.|r Open |cffffd100/he setup|r to verify exact recipient spelling.")
    end
end)

if SendMail then
    hooksecurefunc("SendMail", function()
        if MR.stagedCount > 0 then
            MR.isSending = true
        end
    end)
end
