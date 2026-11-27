local addonName, NS = ...
NS.BankSorter = {}
local BS = NS.BankSorter
local C = NS.Compat

BS.isBankOpen = false

local bankFrame = CreateFrame("Frame")
bankFrame:RegisterEvent("BANKFRAME_OPENED")
bankFrame:RegisterEvent("BANKFRAME_CLOSED")

bankFrame:SetScript("OnEvent", function(self, event)
    if event == "BANKFRAME_OPENED" then
        BS.isBankOpen = true
    elseif event == "BANKFRAME_CLOSED" then
        BS.isBankOpen = false
    end
end)

function BS:RunSort(mode)
    if BankFrame and BankFrame:IsShown() then
        BS.isBankOpen = true
    end
    if mode == "bank" then
        if not BS.isBankOpen then
            NS:Print("|cffff4444Open your bank frame first to sort bank containers.|r")
            return
        end
        if C.SortBankBags() then
            NS:Print("Sorted bank containers via Blizzard container API.")
        else
            NS:Print("Native bank sort unavailable; running stack consolidation.")
            BS:ConsolidateStacks(true)
        end
    else
        if C.SortBags() then
            NS:Print("Sorted backpack & bag containers via Blizzard container API.")
        else
            NS:Print("Native bag sort unavailable; running stack consolidation.")
            BS:ConsolidateStacks(false)
        end
    end
end

function BS:ConsolidateStacks(includeBank)
    local bags = {0, 1, 2, 3, 4}
    if includeBank and BS.isBankOpen then
        table.insert(bags, -1)
        for b = 5, 11 do table.insert(bags, b) end
    end

    local seen = {}
    local merges = 0
    for _, bag in ipairs(bags) do
        local slots = C.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local _, count, locked, _, link = C.GetContainerItemDetails(bag, slot)
            if link and not locked and count then
                local _, _, _, _, _, _, _, maxStack = C.GetItemInfo(link)
                if maxStack and maxStack > 1 and count < maxStack then
                    if seen[link] then
                        local prev = seen[link]
                        C.PickupContainerItem(bag, slot)
                        C.PickupContainerItem(prev.bag, prev.slot)
                        if CursorHasItem and CursorHasItem() then ClearCursor() end
                        merges = merges + 1
                        seen[link] = nil
                    else
                        seen[link] = { bag = bag, slot = slot }
                    end
                end
            end
        end
    end
    NS:Print("Consolidated |cff00ff00" .. merges .. "|r partial item stacks.")
end

function BS:PrintGoldLedger()
    NS:UpdateGoldLedger()
    if NS.Roster and NS.Roster.ScanAltoholic then
        NS.Roster:ScanAltoholic()
    end
    NS:Print("=== IllusoryBias Cross-Character Wealth Ledger ===")
    local total = 0
    for charKey, data in pairs(WOWEngineDB.goldLedger or {}) do
        local copper = data.copper or 0
        total = total + copper
        NS:Print(string.format("  |cffffd100%s|r (%s): %s", charKey, data.faction or "?", C.FormatMoney(copper)))
    end
    NS:Print("Total Account Wealth: " .. C.FormatMoney(total))
end
