local addonName, NS = ...
NS.BagRouter = {}
local BR = NS.BagRouter
local C = NS.Compat

local SPECIALTY_PROF_MAP = {
    herb        = "Herbalism",
    enchanting  = "Enchanting",
    mining      = "Mining",
    leather     = "Leatherworking",
    gem         = "Jewelcrafting",
    engineering = "Engineering",
    inscription = "Inscription",
}

local bagTip = nil
local function GetBagTooltip()
    if not bagTip then
        bagTip = CreateFrame("GameTooltip", "WOWEngineBagScanTooltip", nil, "GameTooltipTemplate")
        bagTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return bagTip
end

-- Extract numeric slot count (e.g. "10 Slot Bag", "12 Slot Quiver", "16 Slot Reagent Bag") from tooltip
local function ParseSlotCountFromTooltip(bag, slot, itemLink)
    if bag ~= nil and slot ~= nil and C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local tipData = C_TooltipInfo.GetBagItem(bag, slot)
        if tipData and tipData.lines then
            for _, line in ipairs(tipData.lines) do
                local t = line.leftText
                if t and not C.IsSecret(t) then
                    local num = string.match(t, "(%d+)%s+[Ss]lot")
                    if num then return tonumber(num) end
                end
            end
        end
    end

    if itemLink and C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local tipData = C_TooltipInfo.GetHyperlink(itemLink)
        if tipData and tipData.lines then
            for _, line in ipairs(tipData.lines) do
                local t = line.leftText
                if t and not C.IsSecret(t) then
                    local num = string.match(t, "(%d+)%s+[Ss]lot")
                    if num then return tonumber(num) end
                end
            end
        end
    end

    local tip = GetBagTooltip()
    tip:ClearLines()
    if bag ~= nil and slot ~= nil then
        tip:SetBagItem(bag, slot)
    elseif itemLink then
        tip:SetHyperlink(itemLink)
    else
        return nil
    end

    for i = 2, tip:NumLines() do
        local left = _G["WOWEngineBagScanTooltipTextLeft" .. i]
        if left then
            local text = left:GetText()
            if text and not C.IsSecret(text) then
                local num = string.match(text, "(%d+)%s+[Ss]lot")
                if num then return tonumber(num) end
            end
        end
    end
    return nil
end

-- Classify a bag item into { isBag, bagType, slots, name }
function BR:InspectBagItem(itemLink, itemID, bag, slot)
    if not itemLink then return nil end
    local itemName, _, _, _, _, itemType, itemSubType, _, _, _, _, classID, subClassID = C.GetItemInfo(itemLink)
    itemName = itemName or C.ExtractItemName(itemLink)
    if not itemName then return nil end

    local isContainer = (classID == 1) or (itemType == "Container") or (itemType == "Bag")
    local isQuiver = (classID == 11) or (itemType == "Quiver")
    if not isContainer and not isQuiver then
        return nil
    end

    local lowName = string.lower(itemName)
    local lowSub = string.lower(tostring(itemSubType or ""))
    local bagType = "regular"

    if isQuiver or string.find(lowName, "quiver") or string.find(lowName, "ammo") or string.find(lowName, "bandolier") or string.find(lowSub, "quiver") or string.find(lowSub, "ammo") then
        bagType = "quiver"
    elseif (classID == 1 and subClassID == 11) or string.find(lowName, "reagent") or string.find(lowSub, "reagent") then
        bagType = "reagent"
    elseif (classID == 1 and subClassID == 2) or string.find(lowName, "herb") or string.find(lowSub, "herb") then
        bagType = "herb"
    elseif (classID == 1 and subClassID == 3) or string.find(lowName, "enchant") or string.find(lowSub, "enchant") then
        bagType = "enchanting"
    elseif (classID == 1 and subClassID == 4) or string.find(lowName, "engineer") or string.find(lowSub, "engineer") then
        bagType = "engineering"
    elseif (classID == 1 and subClassID == 5) or string.find(lowName, "gem") or string.find(lowSub, "gem") then
        bagType = "gem"
    elseif (classID == 1 and subClassID == 6) or string.find(lowName, "mining") or string.find(lowSub, "mining") then
        bagType = "mining"
    elseif (classID == 1 and subClassID == 7) or string.find(lowName, "leather") or string.find(lowSub, "leather") then
        bagType = "leather"
    elseif (classID == 1 and subClassID == 8) or string.find(lowName, "inscription") or string.find(lowSub, "inscription") then
        bagType = "inscription"
    elseif (classID == 1 and subClassID == 1) or string.find(lowName, "soul") or string.find(lowSub, "soul") then
        bagType = "soul"
    end

    local slots = ParseSlotCountFromTooltip(bag, slot, itemLink)
    if not slots or slots <= 0 then
        return nil
    end

    return {
        isBag = true,
        bagType = bagType,
        slots = slots,
        name = itemName,
        itemID = itemID,
    }
end

local function IsSpecialtyTradeBag(bagType)
    return SPECIALTY_PROF_MAP[bagType] ~= nil
end

-- Scan currently equipped bags (slots 1..4, plus slot 5 if Reagent Bag slot exists) and save to roster
function BR:ScanCurrentPlayerBags()
    local roster = NS:GetActiveRoster()
    local name = C.GetPlayerName()
    if not name or not roster[name] then return end

    local entry = roster[name]
    local equipped = {}
    local totalRegular = 0
    local totalAll = 0

    for bagID = 1, 4 do
        local numSlots = C.GetContainerNumSlots(bagID) or 0
        local invSlot = nil
        if C_Container and C_Container.ContainerIDToInventoryID then
            local ok, id = pcall(C_Container.ContainerIDToInventoryID, bagID)
            if ok then invSlot = id end
        elseif ContainerIDToInventoryID then
            local ok, id = pcall(ContainerIDToInventoryID, bagID)
            if ok then invSlot = id end
        end

        local link = invSlot and GetInventoryItemLink and GetInventoryItemLink("player", invSlot) or nil
        local bType = "empty"
        if numSlots > 0 then
            bType = "regular"
            if link then
                local info = BR:InspectBagItem(link, C.ExtractItemID(link), nil, nil)
                if info and info.bagType then
                    bType = info.bagType
                end
            end
        end

        equipped[bagID] = { slots = numSlots, bagType = bType }
        totalAll = totalAll + numSlots
        if bType ~= "quiver" then
            totalRegular = totalRegular + numSlots
        end
    end

    -- Optional Reagent Bag slot (bag 5 on WoW Forever / Retail)
    local rSlots = C.GetContainerNumSlots(5) or 0
    if rSlots > 0 then
        equipped[5] = { slots = rSlots, bagType = "reagent" }
        totalAll = totalAll + rSlots
    end

    entry.equippedBags = equipped
    entry.totalBagSlots = totalAll
    entry.regularBagSlots = totalRegular
end

-- Check whether a candidate character can equip/upgrade from `bagInfo`.
-- Returns: (canUpgrade, slotGain, targetSlotIndex)
function BR:EvaluateUpgradeForChar(charInfo, bagInfo, overrideBags)
    if not charInfo or not bagInfo or not bagInfo.slots then return false, 0, nil end
    local bags = overrideBags or charInfo.equippedBags
    -- Never assume unscanned characters have 4 empty slots! Require either live login scan or Altoholic/DataStore_Containers data.
    if type(bags) ~= "table" then
        return false, 0, nil
    end

    local charClass = string.upper(charInfo.class or "")
    local isHunter = (charClass == "HUNTER")
    local newType = bagInfo.bagType
    local newSlots = bagInfo.slots

    -- 1. Quiver / Ammo Pouch: Hunters ONLY (upgrades smaller quiver or fills an empty slot if no quiver yet)
    if newType == "quiver" then
        if not isHunter then return false, 0, nil end
        local existingQuiverIdx = nil
        local emptyIdx = nil
        for i = 1, 4 do
            local s = bags[i] or { slots = 0, bagType = "empty" }
            if s.bagType == "quiver" then
                existingQuiverIdx = i
            elseif s.slots == 0 and not emptyIdx then
                emptyIdx = i
            end
        end
        if existingQuiverIdx then
            local cur = bags[existingQuiverIdx].slots or 0
            if newSlots > cur then
                return true, (newSlots - cur), existingQuiverIdx
            end
            return false, 0, nil
        elseif emptyIdx then
            return true, newSlots, emptyIdx
        end
        return false, 0, nil
    end

    -- 2. Soul Bag: Warlocks ONLY
    if newType == "soul" then
        if charClass ~= "WARLOCK" then return false, 0, nil end
    end

    -- 3. Specialty Trade Bags (Herb, Enchanting, Mining, etc.): only characters with that matching profession
    if IsSpecialtyTradeBag(newType) then
        local reqProf = SPECIALTY_PROF_MAP[newType]
        local hasProf = charInfo.professions and charInfo.professions[reqProf] ~= nil
        if not hasProf then return false, 0, nil end
    end

    -- 4. Reagent Bag:
    --    - Can upgrade bag 5 (dedicated Reagent Bag slot) if strictly larger
    --    - Can supersede a specific specialty trade bag ONLY if strictly MORE capacity (e.g. 10-slot Reagent > 8-slot Herb)
    if newType == "reagent" then
        local bestGain = 0
        local bestIdx = nil
        -- Check dedicated reagent slot 5 if present
        if bags[5] then
            local cur5 = bags[5].slots or 0
            if newSlots > cur5 then
                bestGain = newSlots - cur5
                bestIdx = 5
            end
        end
        -- Check specialty trade bags in slots 1..4 (ONLY supersede if strictly more capacity!)
        for i = 1, 4 do
            local s = bags[i] or { slots = 0, bagType = "empty" }
            if IsSpecialtyTradeBag(s.bagType) and newSlots > (s.slots or 0) then
                local gain = newSlots - (s.slots or 0)
                if gain > bestGain then
                    bestGain = gain
                    bestIdx = i
                end
            end
        end
        if bestIdx then
            return true, bestGain, bestIdx
        end
        return false, 0, nil
    end

    -- 5. Regular Bag (or Specialty Trade Bag for matching profession):
    --    - NEVER replace a Hunter's Quiver slot!
    --    - If Hunter has no quiver yet, reserve 1 empty slot for their quiver (so max 3 regular slots)
    local hunterHasQuiver = false
    if isHunter then
        for i = 1, 4 do
            if bags[i] and bags[i].bagType == "quiver" then
                hunterHasQuiver = true
                break
            end
        end
    end

    local emptyCount = 0
    for i = 1, 4 do
        local s = bags[i] or { slots = 0, bagType = "empty" }
        if (s.slots or 0) == 0 then emptyCount = emptyCount + 1 end
    end

    local bestGain = 0
    local bestIdx = nil
    for i = 1, 4 do
        local s = bags[i] or { slots = 0, bagType = "empty" }
        local curSlots = s.slots or 0
        local curType = s.bagType or "empty"

        -- Never replace a Hunter's Quiver with a regular bag
        if curType ~= "quiver" then
            -- If Hunter has no quiver equipped yet, keep at least 1 empty slot reserved for a quiver
            local skipReservedQuiverSlot = (isHunter and not hunterHasQuiver and curSlots == 0 and emptyCount <= 1)
            if not skipReservedQuiverSlot then
                -- Regular bag does not overwrite a larger/equal specialty bag; specialty bag can replace smaller regular/empty/same-specialty
                if newSlots > curSlots then
                    local gain = newSlots - curSlots
                    if gain > bestGain then
                        bestGain = gain
                        bestIdx = i
                    end
                end
            end
        end
    end

    if bestIdx then
        return true, bestGain, bestIdx
    end
    return false, 0, nil
end

-- Pick the highest-priority recipient for a bag upgrade:
--   1. Highest Level
--   2. Most Played Time
--   3. Highest Total Bag Space (completes near-full sets first: 1 empty beats 2 empty; 1x6+3x8 beats 4x6; default-only is lowest)
--   4. Largest Slot Gain (tiebreaker)
local function CloneBagsTable(bags)
    local copy = {}
    for k, v in pairs(bags) do
        if type(v) == "table" then
            copy[k] = { slots = v.slots or 0, bagType = v.bagType or "empty" }
        end
    end
    return copy
end

function BR:FindBestRecipientForBag(bagInfo, simState)
    if not bagInfo or not bagInfo.isBag then return nil, nil end

    local roster = NS:GetActiveRoster()
    local candidates = {}

    for exactName, info in pairs(roster) do
        if info and info.verified and not C.IsCurrentPlayer(exactName) and not NS.Roster:IsExcludedFromMail(info) then
            local isOwn = (info.isOwnAlt == true) or (info.source == "login") or (info.source == "altoholic")
            if isOwn and type(info.equippedBags) == "table" then
                local simBags = (simState and simState[exactName]) or info.equippedBags
                local canUpgrade, gain, slotIdx = BR:EvaluateUpgradeForChar(info, bagInfo, simBags)
                if canUpgrade then
                    local totSpace = 0
                    for _, s in pairs(simBags) do
                        if type(s) == "table" then totSpace = totSpace + (tonumber(s.slots) or 0) end
                    end
                    table.insert(candidates, {
                        name = exactName,
                        level = tonumber(info.level) or 0,
                        played = tonumber(info.playedTime) or 0,
                        totalSpace = totSpace,
                        gain = gain,
                        slotIdx = slotIdx,
                    })
                end
            end
        end
    end

    if #candidates == 0 then return nil, nil end

    table.sort(candidates, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        if a.played ~= b.played then return a.played > b.played end
        if a.totalSpace ~= b.totalSpace then return a.totalSpace > b.totalSpace end
        if a.gain ~= b.gain then return a.gain > b.gain end
        return string.lower(a.name) < string.lower(b.name)
    end)

    local winner = candidates[1]
    -- Record simulated slot fill so multiple bags in the same inventory distribute accurately across alts
    if simState and winner and winner.slotIdx then
        local baseBags = simState[winner.name] or roster[winner.name].equippedBags
        local updated = CloneBagsTable(baseBags)
        updated[winner.slotIdx] = { slots = bagInfo.slots, bagType = bagInfo.bagType }
        simState[winner.name] = updated
    end

    return winner.name, winner
end

function BR:PrintBagStatus()
    BR:ScanCurrentPlayerBags()
    local roster = NS:GetActiveRoster()
    local list = {}
    for _, info in pairs(roster) do
        if info and info.verified and ((info.isOwnAlt == true) or (info.source == "login") or (info.source == "altoholic")) then
            table.insert(list, info)
        end
    end

    table.sort(list, function(a, b)
        local la, lb = tonumber(a.level) or 0, tonumber(b.level) or 0
        if la ~= lb then return la > lb end
        local pa, pb = tonumber(a.playedTime) or 0, tonumber(b.playedTime) or 0
        if pa ~= pb then return pa > pb end
        return (tonumber(a.totalBagSlots) or 0) > (tonumber(b.totalBagSlots) or 0)
    end)

    NS:Print("=== WOWEngine Bag Upgrade Priority (Level -> Played -> Total Space) ===")
    for idx, info in ipairs(list) do
        local slotsStr = "Not scanned yet (log in once)"
        if type(info.equippedBags) == "table" then
            local parts = {}
            for i = 1, 4 do
                local s = info.equippedBags[i] or { slots = 0, bagType = "empty" }
                if s.bagType == "quiver" then
                    table.insert(parts, "Q" .. tostring(s.slots))
                elseif s.slots == 0 then
                    table.insert(parts, "Empty")
                elseif s.bagType ~= "regular" then
                    table.insert(parts, tostring(s.slots) .. "(" .. string.sub(s.bagType, 1, 4) .. ")")
                else
                    table.insert(parts, tostring(s.slots))
                end
            end
            slotsStr = table.concat(parts, " / ") .. " [Total: " .. tostring(info.totalBagSlots or 0) .. "]"
        end
        local hrs = math.floor((tonumber(info.playedTime) or 0) / 3600)
        NS:Print(string.format("  %d. |cffffd100%s|r (Lv%d, %dh) — %s", idx, info.name, tonumber(info.level) or 0, hrs, slotsStr))
    end
end

-- Event listener: keep equipped bags & played time updated automatically
local bagEvents = CreateFrame("Frame")
bagEvents:RegisterEvent("PLAYER_LOGIN")
bagEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
bagEvents:RegisterEvent("BAG_UPDATE_DELAYED")
bagEvents:RegisterEvent("MAIL_SHOW")
bagEvents:RegisterEvent("TIME_PLAYED_MSG")
bagEvents:SetScript("OnEvent", function(self, event, totalPlayed)
    if event == "TIME_PLAYED_MSG" then
        local roster = NS:GetActiveRoster()
        local name = C.GetPlayerName()
        if name and roster[name] and tonumber(totalPlayed) then
            roster[name].playedTime = tonumber(totalPlayed)
        end
    else
        pcall(function() BR:ScanCurrentPlayerBags() end)
    end
end)
