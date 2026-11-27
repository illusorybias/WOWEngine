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
        keptForSelf = 0,
        customMatched = 0,
        missingCats = {},
    }

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
                            dest = forcedTarget
                            routeLabel = cat or "Direct"
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
                            -- Priority 2: Standard Category Routing (respects Mastercraft & Auctionator holds)
                            local addonHeld = MR:IsAddonHoldProtected(itemID)
                            if addonHeld then
                                stats.skippedMC = stats.skippedMC + 1
                            elseif cat then
                                local eligible, isSelfAssigned = NS.Roster:GetEligibleTargetsForCategory(cat)
                                if #eligible == 0 then
                                    if isSelfAssigned then
                                        stats.keptForSelf = stats.keptForSelf + 1
                                    else
                                        stats.missingCats[cat] = true
                                    end
                                elseif #eligible == 1 or mode == "priority" then
                                    dest = eligible[1]
                                else
                                    local baseIdx = tonumber(rrCursors[cat]) or 1
                                    local off = localOffset[cat] or 0
                                    local pickIdx = ((baseIdx - 1 + off) % #eligible) + 1
                                    dest = eligible[pickIdx]
                                    localOffset[cat] = off + 1
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

function MR:CycleNextTarget()
    MR.selectedAltCursor = (MR.selectedAltCursor or 1) + 1
    return MR:StageNextBatch(nil)
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

    if #recipientOrder == 0 then
        MR.currentRecipient = nil
        MR.stagedCount = 0
        MR.pendingRRAdvances = {}

        local missingList = {}
        for k in pairs(stats.missingCats) do table.insert(missingList, k) end
        table.sort(missingList)

        if #missingList > 0 then
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
