local addonName, NS = ...
NS.Onboarding = {}
local OB = NS.Onboarding
local C = NS.Compat

OB.currentStep = 1
OB.totalSteps = 5
OB.frame = nil
OB.customFrame = nil
OB.customAltIndex = 1
OB.step2CharIndex = 1
OB.step3CharIndex = 1
OB.sharedFrame = nil
OB.sharedProfName = nil
OB.sharedCatKey = nil
OB.sharedPoolIndex = 1
OB.stepPanels = {}

local cbCounter = 0

local function ApplyBlizzardBlueBackdrop(f, bgAlpha)
    local alpha = bgAlpha or 0.96
    if f.SetBackdrop then
        local ok = pcall(function()
            f:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 14,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            f:SetBackdropColor(0.04, 0.09, 0.19, alpha)
            f:SetBackdropBorderColor(0.95, 0.78, 0.18, 1.0)
        end)
        if ok then return end
    end

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetColorTexture(0.04, 0.09, 0.19, alpha)

    local edges = {
        { "TOPLEFT", "TOPRIGHT", 2, nil },
        { "BOTTOMLEFT", "BOTTOMRIGHT", 2, nil },
        { "TOPLEFT", "BOTTOMLEFT", nil, 2 },
        { "TOPRIGHT", "BOTTOMRIGHT", nil, 2 },
    }
    for _, e in ipairs(edges) do
        local line = f:CreateTexture(nil, "BORDER")
        line:SetPoint(e[1], f, e[1], 0, 0)
        line:SetPoint(e[2], f, e[2], 0, 0)
        if e[3] then line:SetHeight(e[3]) end
        if e[4] then line:SetWidth(e[4]) end
        line:SetColorTexture(0.95, 0.78, 0.18, 1.0)
    end
end

local function CreateActionButton(parent, width, height, text, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, height)
    b:SetText(text)
    b:SetScript("OnClick", function()
        local ok, err = pcall(onClick)
        if not ok then
            if NS.RecordError then NS:RecordError("OnboardingButton:" .. tostring(text or "?"), err) end
            NS:Print("|cffff4444Onboarding UI error:|r " .. tostring(err) .. " (Type |cffffd100/he bug|r to copy report)")
        end
    end)
    return b
end

local function CreateCheckbox(parent, label, getVal, setVal, tooltipText)
    cbCounter = cbCounter + 1
    local cbName = "WOWEngineOnboardCB" .. cbCounter
    local cb = CreateFrame("CheckButton", cbName, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)

    local builtInText = _G[cbName .. "Text"] or cb.Text
    if builtInText and builtInText.SetText then
        builtInText:SetText("")
    end

    local txt = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    txt:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    txt:SetText(label)
    cb.labelText = txt

    if tooltipText then
        cb:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label, 1.0, 0.85, 0.1)
            GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
    end

    cb:SetScript("OnClick", function(self)
        local ok, err = pcall(function()
            setVal(self:GetChecked() and true or false)
            OB:RefreshCurrentStep()
        end)
        if not ok then
            if NS.RecordError then NS:RecordError("OnboardingCheckbox", err) end
            NS:Print("|cffff4444Checkbox error:|r " .. tostring(err) .. " (Type |cffffd100/he bug|r to copy report)")
        end
    end)
    cb.Refresh = function(self)
        self:SetChecked(getVal() and true or false)
    end
    return cb
end

-- Simple 1-click cycle for the primary alt on a category row (just like v1.3.5!)
function OB:CyclePrimaryForCategory(catKey)
    NS.Roster:ScanAll(true)
    local list = NS.Roster:GetSortedVerifiedList()
    if #list == 0 then
        NS:Print("|cffff9900No verified characters scanned yet.|r Click Scan Characters in Step 1 first.")
        return
    end

    local targets = NS.Roster:GetCategoryTargets(catKey)
    local current = targets[1]
    local nextIndex = 1
    if current then
        for i, info in ipairs(list) do
            if C.IsSameCharacter(info.name, current) then
                if i < #list then
                    nextIndex = i + 1
                else
                    NS.Roster:ClearCategory(catKey)
                    OB:RefreshCurrentStep()
                    return
                end
                break
            end
        end
    end
    NS.Roster:SetPrimaryTarget(catKey, list[nextIndex].name)
    OB:RefreshCurrentStep()
end

-- Optional "+Alt" button on a category row: adds the next unassigned verified alt to that same mat
function OB:AddExtraAltToCategory(catKey)
    NS.Roster:ScanAll(true)
    local list = NS.Roster:GetSortedVerifiedList()
    if #list < 2 then
        NS:Print("|cffff9900Need at least 2 verified characters|r to assign a second alt to [" .. catKey .. "].")
        return
    end

    for _, info in ipairs(list) do
        if not NS.Roster:HasTargetInCategory(catKey, info.name) then
            NS.Roster:AddTargetToCategory(catKey, info.name, true)
            NS:Print("Added extra alt |cff00ff00" .. info.name .. "|r to [" .. catKey .. "].")
            OB:RefreshCurrentStep()
            return
        end
    end
    NS:Print("All verified characters are already assigned to [" .. catKey .. "]. Click Clear to reset.")
end

-- ==========================================
-- OPTIONAL POPUP: CUSTOM ADDITIONS PER CHARACTER (WITH CLICK-ITEM QUICK-FILL)
-- ==========================================
OB.customPage = 1
OB.pendingCustomItemID = nil
OB.itemHooksInstalled = false

function OB:PopulateCustomFromItem(itemLink, itemID, clearCursorAfter)
    local cf = OB.customFrame
    if not cf or not cf:IsShown() then return false end

    local name = nil
    if itemLink then
        name = C.ExtractItemName(itemLink)
        itemID = itemID or C.ExtractItemID(itemLink)
    end
    if (not name or name == "") and itemID then
        local fetched = C.GetItemInfo(itemID)
        name = C.ExtractItemName(fetched)
    end
    if not name or name == "" then return false end

    cf.editBox:SetText(name)
    cf.editBox:HighlightText(0, 0)
    OB.pendingCustomItemID = tonumber(itemID)
    if cf.statusHint then
        cf.statusHint:SetText("|cff00ff00Captured:|r |cffffd100" .. name .. "|r — click |cff00aeff+ Add|r (or press Enter) to save.")
    end
    if clearCursorAfter and ClearCursor then
        ClearCursor()
    end
    return true
end

function OB:InstallItemClickHooks()
    if OB.itemHooksInstalled then return end
    OB.itemHooksInstalled = true

    -- 1. Left-Clicking an item in bags/bank (triggers CURSOR_CHANGED while Custom Additions is open)
    local cursorWatch = CreateFrame("Frame")
    cursorWatch:RegisterEvent("CURSOR_CHANGED")
    cursorWatch:SetScript("OnEvent", function()
        if not (OB.customFrame and OB.customFrame:IsShown()) then return end
        if not GetCursorInfo then return end
        local infoType, itemID, itemLink = GetCursorInfo()
        if infoType == "item" then
            OB:PopulateCustomFromItem(itemLink, itemID, true)
        end
    end)

    -- 2. Shift-Clicking an item in bags/bank/chat/professions/Auctionator/Mastercraft
    if ChatEdit_InsertLink then
        hooksecurefunc("ChatEdit_InsertLink", function(link)
            if not (OB.customFrame and OB.customFrame:IsShown()) then return end
            -- Only capture if the user isn't actively typing in chat
            if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then return end
            if link and string.find(tostring(link), "Hitem:") then
                OB:PopulateCustomFromItem(link, nil, false)
            end
        end)
    end

    if HandleModifiedItemClick then
        hooksecurefunc("HandleModifiedItemClick", function(link)
            if not (OB.customFrame and OB.customFrame:IsShown()) then return end
            if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then return end
            if link and string.find(tostring(link), "Hitem:") then
                OB:PopulateCustomFromItem(link, nil, false)
            end
        end)
    end
end

function OB:OpenCustomAdditionsPopup()
    OB:InstallItemClickHooks()

    if not OB.customFrame then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local cf = CreateFrame("Frame", "WOWEngineCustomAdditionsFrame", UIParent, template)
        cf:SetSize(455, 365)
        cf:SetPoint("CENTER", UIParent, "CENTER", 45, 10)
        cf:SetFrameStrata("DIALOG")
        cf:SetFrameLevel(130)
        cf:SetClampedToScreen(true)
        cf:SetMovable(true)
        cf:EnableMouse(true)
        cf:RegisterForDrag("LeftButton")
        cf:SetScript("OnDragStart", function(self) self:StartMoving() end)
        cf:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        ApplyBlizzardBlueBackdrop(cf, 0.98)

        if UISpecialFrames then
            table.insert(UISpecialFrames, "WOWEngineCustomAdditionsFrame")
        end

        local title = cf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetText("|cff00aeffCustom Character Additions|r |cffffd100(Quick Add)|r")

        local closeBtn = CreateFrame("Button", nil, cf, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() cf:Hide() end)

        local desc = cf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        desc:SetWidth(420)
        desc:SetJustifyH("LEFT")
        desc:SetText("Pick a character, then |cff00ff00click (or Shift-Click) any item in your bags|r to auto-fill its name — or type any keyword (e.g. Cerulean Dye, Potion, Fish) and click + Add.")

        local altLbl = cf:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        altLbl:SetPoint("TOPLEFT", 14, -76)
        altLbl:SetText("Character:")

        local function StepCustomAlt(delta)
            local list = NS.Roster:GetSortedVerifiedList()
            if #list == 0 then return end
            OB.customAltIndex = ((OB.customAltIndex - 1 + (delta or 1)) % #list) + 1
            OB:RefreshCustomPopup()
        end

        local altPrevBtn = CreateActionButton(cf, 22, 22, "<", function() StepCustomAlt(-1) end)
        altPrevBtn:SetPoint("LEFT", altLbl, "RIGHT", 10, 0)
        cf.altPrevBtn = altPrevBtn

        local altBtn = CreateActionButton(cf, 245, 22, "Select Character", function() StepCustomAlt(1) end)
        altBtn:SetPoint("LEFT", altPrevBtn, "RIGHT", 3, 0)
        cf.altBtn = altBtn

        local altNextBtn = CreateActionButton(cf, 22, 22, ">", function() StepCustomAlt(1) end)
        altNextBtn:SetPoint("LEFT", altBtn, "RIGHT", 3, 0)
        cf.altNextBtn = altNextBtn

        local kwLbl = cf:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        kwLbl:SetPoint("TOPLEFT", 14, -108)
        kwLbl:SetText("Item / Keyword:")

        local editBox = CreateFrame("EditBox", "WOWEngineCustomKeywordBox", cf, "InputBoxTemplate")
        editBox:SetSize(205, 22)
        editBox:SetPoint("LEFT", kwLbl, "RIGHT", 12, 0)
        editBox:SetAutoFocus(false)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        editBox:SetScript("OnTextChanged", function(self, userInput)
            if userInput then
                OB.pendingCustomItemID = nil
            end
        end)

        -- Allow dropping or clicking an item directly onto the input box too
        local function HandleBoxDrop()
            if GetCursorInfo then
                local infoType, itemID, itemLink = GetCursorInfo()
                if infoType == "item" then
                    OB:PopulateCustomFromItem(itemLink, itemID, true)
                end
            end
        end
        editBox:SetScript("OnReceiveDrag", HandleBoxDrop)
        editBox:HookScript("OnMouseDown", HandleBoxDrop)
        cf.editBox = editBox

        local function DoAddCustomRule()
            local list = NS.Roster:GetSortedVerifiedList()
            if #list == 0 then
                NS:Print("|cffff9900Scan characters in Step 1 first.|r")
                return
            end
            if OB.customAltIndex > #list or OB.customAltIndex < 1 then OB.customAltIndex = 1 end
            local target = list[OB.customAltIndex].name
            local rawKw = cf.editBox:GetText() or ""
            local cleanKw = C.ExtractItemName(rawKw)
            if not cleanKw or cleanKw == "" then
                NS:Print("|cffff9900Click an item in your bags or type a keyword first|r (e.g. Cerulean Dye).")
                return
            end
            local ok, res, savedKw = NS.Roster:AddCustomRule(cleanKw, target, OB.pendingCustomItemID)
            if ok then
                cf.editBox:SetText("")
                cf.editBox:ClearFocus()
                OB.pendingCustomItemID = nil
                if cf.statusHint then
                    if C.IsCurrentPlayer(res) then
                        cf.statusHint:SetText("|cff00aeffSaved for (You):|r '" .. tostring(savedKw) .. "' — other alts will mail this here.")
                    else
                        cf.statusHint:SetText("|cff00ff00Saved:|r '" .. tostring(savedKw) .. "' -> |cffffd100" .. tostring(res) .. "|r (ready to stage at mailbox)")
                    end
                end
                NS:Print("Added custom route: '" .. tostring(savedKw) .. "' -> |cff00ff00" .. tostring(res) .. "|r")
                OB:RefreshCustomPopup()
                OB:RefreshCurrentStep()
            end
        end

        editBox:SetScript("OnEnterPressed", function()
            DoAddCustomRule()
        end)

        local addBtn = CreateActionButton(cf, 68, 22, "+ Add", DoAddCustomRule)
        addBtn:SetPoint("LEFT", editBox, "RIGHT", 8, 0)

        local statusHint = cf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statusHint:SetPoint("TOPLEFT", 14, -134)
        statusHint:SetWidth(425)
        statusHint:SetJustifyH("LEFT")
        statusHint:SetText("|cffaaaaaaTip: Open your bags and left-click any item to fill the box automatically.|r")
        cf.statusHint = statusHint

        local listHeader = cf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        listHeader:SetPoint("TOPLEFT", 14, -156)
        listHeader:SetText("Active Custom Additions:")

        cf.entryRows = {}
        for i = 1, 7 do
            local rowY = -178 - (i - 1) * 22
            local rowTxt = cf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rowTxt:SetPoint("TOPLEFT", 16, rowY - 3)
            rowTxt:SetWidth(355)
            rowTxt:SetJustifyH("LEFT")

            local delBtn = CreateActionButton(cf, 54, 18, "Remove", function()
                local realIdx = ((OB.customPage - 1) * 7) + i
                NS.Roster:RemoveCustomRuleByIndex(realIdx)
                OB:RefreshCustomPopup()
                OB:RefreshCurrentStep()
            end)
            delBtn:SetPoint("TOPRIGHT", -14, rowY)

            cf.entryRows[i] = { txt = rowTxt, delBtn = delBtn }
        end

        local prevPageBtn = CreateActionButton(cf, 60, 22, "< Prev", function()
            if OB.customPage > 1 then
                OB.customPage = OB.customPage - 1
                OB:RefreshCustomPopup()
            end
        end)
        prevPageBtn:SetPoint("BOTTOMLEFT", 14, 10)
        cf.prevPageBtn = prevPageBtn

        local nextPageBtn = CreateActionButton(cf, 60, 22, "Next >", function()
            local totalPages = math.max(1, math.ceil(#NS:GetCustomRules() / 7))
            if OB.customPage < totalPages then
                OB.customPage = OB.customPage + 1
                OB:RefreshCustomPopup()
            end
        end)
        nextPageBtn:SetPoint("LEFT", prevPageBtn, "RIGHT", 6, 0)
        cf.nextPageBtn = nextPageBtn

        local pageTxt = cf:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        pageTxt:SetPoint("LEFT", nextPageBtn, "RIGHT", 10, 0)
        cf.pageTxt = pageTxt

        local doneBtn = CreateActionButton(cf, 72, 24, "Done", function()
            cf:Hide()
        end)
        doneBtn:SetPoint("BOTTOMRIGHT", -14, 10)

        local testBagsBtn = CreateActionButton(cf, 86, 24, "Test Bags", function()
            NS.MailRouter:DiagnoseCustomMatches()
        end)
        testBagsBtn:SetPoint("RIGHT", doneBtn, "LEFT", -6, 0)

        OB.customFrame = cf
    end

    -- Default selector to a non-self alt so testing from current character works immediately
    local list = NS.Roster:GetSortedVerifiedList()
    if #list > 0 then
        local curEntry = list[OB.customAltIndex]
        if (not curEntry) or C.IsCurrentPlayer(curEntry.name) then
            for i, info in ipairs(list) do
                if not C.IsCurrentPlayer(info.name) then
                    OB.customAltIndex = i
                    break
                end
            end
        end
    end

    OB:RefreshCustomPopup()
    OB.customFrame:Show()
    OB.customFrame:Raise()
end

function OB:RefreshCustomPopup()
    local cf = OB.customFrame
    if not cf then return end

    local list = NS.Roster:GetSortedVerifiedList()
    if #list > 0 then
        if OB.customAltIndex < 1 or OB.customAltIndex > #list then
            OB.customAltIndex = 1
        end
        local name = list[OB.customAltIndex].name
        local tag = C.IsCurrentPlayer(name) and " (You)" or ""
        cf.altBtn:SetText("|cff00ff00" .. name .. "|r" .. tag)
    else
        cf.altBtn:SetText("|cffaaaaaaNo characters scanned|r")
    end

    local custom = NS:GetCustomRules()
    local perPage = 7
    local totalPages = math.max(1, math.ceil(#custom / perPage))
    if OB.customPage > totalPages then OB.customPage = totalPages end
    if OB.customPage < 1 then OB.customPage = 1 end

    for i = 1, perPage do
        local row = cf.entryRows[i]
        local realIdx = ((OB.customPage - 1) * perPage) + i
        local entry = custom[realIdx]
        if entry then
            row.txt:SetText(string.format("%d. '|cffffd100%s|r' -> |cff00ff00%s|r", realIdx, entry.keyword or "?", entry.target or "?"))
            row.txt:Show()
            row.delBtn:Show()
        else
            if i == 1 and #custom == 0 then
                row.txt:SetText("|cff888888No custom additions yet. Click an item in your bags or type above.|r")
                row.txt:Show()
            else
                row.txt:Hide()
            end
            row.delBtn:Hide()
        end
    end

    if cf.prevPageBtn then
        if OB.customPage > 1 then cf.prevPageBtn:Enable() else cf.prevPageBtn:Disable() end
    end
    if cf.nextPageBtn then
        if OB.customPage < totalPages then cf.nextPageBtn:Enable() else cf.nextPageBtn:Disable() end
    end
    if cf.pageTxt then
        cf.pageTxt:SetText(string.format("Page %d/%d (%d total)", OB.customPage, totalPages, #custom))
    end
end


-- ==========================================
-- POPUP: SHARED PROFESSION CHARACTERS & PRIORITY (MAX 10 PER PROFESSION)
-- ==========================================
function OB:OpenSharedPriorityPopup(profName, catKey)
    if not catKey then return end
    OB.sharedProfName = profName or catKey
    OB.sharedCatKey = catKey
    OB.sharedPoolIndex = 1

    if not OB.sharedFrame then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local sf = CreateFrame("Frame", "WOWEngineSharedPriorityFrame", UIParent, template)
        sf:SetSize(485, 420)
        sf:SetPoint("CENTER", UIParent, "CENTER", 55, 10)
        sf:SetFrameStrata("DIALOG")
        sf:SetFrameLevel(135)
        sf:SetClampedToScreen(true)
        sf:SetMovable(true)
        sf:EnableMouse(true)
        sf:RegisterForDrag("LeftButton")
        sf:SetScript("OnDragStart", function(self) self:StartMoving() end)
        sf:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        ApplyBlizzardBlueBackdrop(sf, 0.98)

        if UISpecialFrames then
            table.insert(UISpecialFrames, "WOWEngineSharedPriorityFrame")
        end

        local headerBg = sf:CreateTexture(nil, "ARTWORK")
        headerBg:SetPoint("TOPLEFT", 4, -4)
        headerBg:SetPoint("TOPRIGHT", -4, -4)
        headerBg:SetHeight(42)
        headerBg:SetColorTexture(0.06, 0.16, 0.34, 0.95)

        local title = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 14, -10)
        sf.title = title

        local subtitle = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
        sf.subtitle = subtitle

        local closeBtn = CreateFrame("Button", nil, sf, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() sf:Hide() end)

        local hint = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 14, -52)
        hint:SetWidth(455)
        hint:SetJustifyH("LEFT")
        hint:SetText("Up to |cffffd10010 characters|r per profession receive mats in priority order (#1 highest). Use Up/Dn to sort visually, or swap characters from the pool below.")

        -- 10 Priority Slots (#1 .. #10)
        sf.rows = {}
        for i = 1, 10 do
            local rowY = -86 - (i - 1) * 24

            local rankTxt = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            rankTxt:SetPoint("TOPLEFT", 14, rowY - 4)
            rankTxt:SetWidth(26)
            rankTxt:SetJustifyH("LEFT")
            rankTxt:SetText("#" .. i)

            local nameTxt = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameTxt:SetPoint("LEFT", rankTxt, "RIGHT", 4, 0)
            nameTxt:SetWidth(275)
            nameTxt:SetJustifyH("LEFT")

            local upBtn = CreateActionButton(sf, 36, 20, "Up", function()
                if NS.Roster:MoveCategoryTarget(OB.sharedCatKey, i, -1) then
                    OB:RefreshSharedPriorityPopup()
                    OB:RefreshCurrentStep()
                end
            end)
            upBtn:SetPoint("TOPRIGHT", -114, rowY)

            local dnBtn = CreateActionButton(sf, 36, 20, "Dn", function()
                if NS.Roster:MoveCategoryTarget(OB.sharedCatKey, i, 1) then
                    OB:RefreshSharedPriorityPopup()
                    OB:RefreshCurrentStep()
                end
            end)
            dnBtn:SetPoint("LEFT", upBtn, "RIGHT", 4, 0)

            local remBtn = CreateActionButton(sf, 56, 20, "Remove", function()
                local active = NS.Roster:GetCategoryTargets(OB.sharedCatKey)
                if active[i] then
                    NS.Roster:RemoveTargetFromCategory(OB.sharedCatKey, active[i], true)
                    OB:RefreshSharedPriorityPopup()
                    OB:RefreshCurrentStep()
                end
            end)
            remBtn:SetPoint("LEFT", dnBtn, "RIGHT", 4, 0)

            sf.rows[i] = { rankTxt = rankTxt, nameTxt = nameTxt, upBtn = upBtn, dnBtn = dnBtn, remBtn = remBtn }
        end

        -- Divider line above Add/Swap Pool
        local div = sf:CreateTexture(nil, "ARTWORK")
        div:SetPoint("TOPLEFT", 14, -332)
        div:SetPoint("TOPRIGHT", -14, -332)
        div:SetHeight(1)
        div:SetColorTexture(0.95, 0.78, 0.18, 0.5)

        local poolLbl = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        poolLbl:SetPoint("TOPLEFT", 14, -340)
        sf.poolLbl = poolLbl

        local function StepSharedPool(delta)
            local _, pool = NS.Roster:GetSharedPoolForProfession(OB.sharedProfName, OB.sharedCatKey)
            if #pool == 0 then return end
            OB.sharedPoolIndex = ((OB.sharedPoolIndex - 1 + (delta or 1)) % #pool) + 1
            OB:RefreshSharedPriorityPopup()
        end

        local poolPrevBtn = CreateActionButton(sf, 22, 22, "<", function() StepSharedPool(-1) end)
        poolPrevBtn:SetPoint("TOPLEFT", 14, -358)
        sf.poolPrevBtn = poolPrevBtn

        local poolCycleBtn = CreateActionButton(sf, 212, 22, "Select Character to Add", function() StepSharedPool(1) end)
        poolCycleBtn:SetPoint("LEFT", poolPrevBtn, "RIGHT", 3, 0)
        sf.poolCycleBtn = poolCycleBtn

        local poolNextBtn = CreateActionButton(sf, 22, 22, ">", function() StepSharedPool(1) end)
        poolNextBtn:SetPoint("LEFT", poolCycleBtn, "RIGHT", 3, 0)
        sf.poolNextBtn = poolNextBtn

        local poolAddBtn = CreateActionButton(sf, 108, 22, "+ Add to Top 10", function()
            local active, pool = NS.Roster:GetSharedPoolForProfession(OB.sharedProfName, OB.sharedCatKey)
            if #active >= (NS.Roster.MAX_SHARED_PER_PROF or 10) then
                NS:Print("|cffff9900Limit reached (10/10):|r Remove a character above before adding another to " .. tostring(OB.sharedProfName) .. ".")
                return
            end
            if #pool == 0 then return end
            if OB.sharedPoolIndex > #pool or OB.sharedPoolIndex < 1 then OB.sharedPoolIndex = 1 end
            local pick = pool[OB.sharedPoolIndex]
            if pick then
                local ok, res = NS.Roster:AddTargetToCategory(OB.sharedCatKey, pick.name, true)
                if ok then
                    NS:Print("Added |cff00ff00" .. tostring(res) .. "|r to " .. tostring(OB.sharedProfName) .. " priority list.")
                    OB:RefreshSharedPriorityPopup()
                    OB:RefreshCurrentStep()
                end
            end
        end)
        poolAddBtn:SetPoint("LEFT", poolNextBtn, "RIGHT", 6, 0)
        sf.poolAddBtn = poolAddBtn

        -- Bottom Utility Row: Auto-Sort + Done
        local sortSkillBtn = CreateActionButton(sf, 110, 22, "Sort by Skill", function()
            NS.Roster:SortCategoryTargets(OB.sharedCatKey, OB.sharedProfName, "skill")
            OB:RefreshSharedPriorityPopup()
            OB:RefreshCurrentStep()
        end)
        sortSkillBtn:SetPoint("BOTTOMLEFT", 14, 12)

        local sortLvlBtn = CreateActionButton(sf, 110, 22, "Sort by Level", function()
            NS.Roster:SortCategoryTargets(OB.sharedCatKey, OB.sharedProfName, "level")
            OB:RefreshSharedPriorityPopup()
            OB:RefreshCurrentStep()
        end)
        sortLvlBtn:SetPoint("LEFT", sortSkillBtn, "RIGHT", 6, 0)

        local doneBtn = CreateActionButton(sf, 84, 22, "Done", function()
            sf:Hide()
        end)
        doneBtn:SetPoint("BOTTOMRIGHT", -14, 12)

        OB.sharedFrame = sf
    end

    OB:RefreshSharedPriorityPopup()
    OB.sharedFrame:Show()
    OB.sharedFrame:Raise()
end

function OB:RefreshSharedPriorityPopup()
    local sf = OB.sharedFrame
    if not sf or not OB.sharedCatKey then return end

    local active, pool = NS.Roster:GetSharedPoolForProfession(OB.sharedProfName, OB.sharedCatKey)
    local roster = NS:GetActiveRoster()
    local maxSlots = NS.Roster.MAX_SHARED_PER_PROF or 10

    sf.title:SetText(string.format("|cff00aeffShared %s|r |cffffd100Priority (%d/%d)|r",
        tostring(OB.sharedProfName), #active, maxSlots))
    sf.subtitle:SetText(string.format("Category: %s  |  Active: %d/%d  |  Waiting in Pool: %d",
        tostring(OB.sharedCatKey), #active, maxSlots, #pool))

    for i = 1, 10 do
        local row = sf.rows[i]
        local charName = active[i]
        if charName then
            local info = roster[charName] or {}
            local lv = tonumber(info.level) or 0
            local sk = (info.professions and OB.sharedProfName and tonumber(info.professions[OB.sharedProfName])) or nil
            local skStr = sk and (" | Skill " .. sk) or ""
            local selfTag = C.IsCurrentPlayer(charName) and " |cff00aeff(You)|r" or ""
            row.rankTxt:SetText("|cffffd100#" .. i .. "|r")
            row.nameTxt:SetText(string.format("|cff00ff00%s|r%s  |cffaaaaaa[Lv%d%s]|r", charName, selfTag, lv, skStr))
            row.rankTxt:Show()
            row.nameTxt:Show()
            row.upBtn:Show()
            row.dnBtn:Show()
            row.remBtn:Show()
            if i == 1 then row.upBtn:Disable() else row.upBtn:Enable() end
            if i == #active then row.dnBtn:Disable() else row.dnBtn:Enable() end
        else
            row.rankTxt:SetText("|cff666666#" .. i .. "|r")
            row.nameTxt:SetText("|cff666666(Open Priority Slot)|r")
            row.rankTxt:Show()
            row.nameTxt:Show()
            row.upBtn:Hide()
            row.dnBtn:Hide()
            row.remBtn:Hide()
        end
    end

    if #pool > 0 then
        if OB.sharedPoolIndex < 1 or OB.sharedPoolIndex > #pool then
            OB.sharedPoolIndex = 1
        end
        local pick = pool[OB.sharedPoolIndex]
        sf.poolLbl:SetText(string.format("|cffffd100Additional Shared Characters (%d available to swap into Top 10):|r", #pool))
        sf.poolCycleBtn:SetText(string.format("[%d/%d] %s (Lv%d)", OB.sharedPoolIndex, #pool, pick.name, tonumber(pick.level) or 0))
        sf.poolCycleBtn:Enable()
        if #active >= maxSlots then
            sf.poolAddBtn:SetText("Full (10/10)")
            sf.poolAddBtn:Disable()
        else
            sf.poolAddBtn:SetText("+ Add to Top 10")
            sf.poolAddBtn:Enable()
        end
    else
        sf.poolLbl:SetText("|cff888888All detected characters for this profession are shown above.|r")
        sf.poolCycleBtn:SetText("|cff888888No extra characters in pool|r")
        sf.poolCycleBtn:Disable()
        sf.poolAddBtn:SetText("+ Add to Top 10")
        sf.poolAddBtn:Disable()
    end
end

function OB:BuildFrame()
    if OB.frame then return OB.frame end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", "WOWEngineOnboardingFrame", UIParent, template)
    f:SetSize(535, 530)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    ApplyBlizzardBlueBackdrop(f, 0.96)

    if UISpecialFrames then
        local found = false
        for _, n in ipairs(UISpecialFrames) do
            if n == "WOWEngineOnboardingFrame" then found = true break end
        end
        if not found then
            table.insert(UISpecialFrames, "WOWEngineOnboardingFrame")
        end
    end

    -- Header Bar
    local headerBg = f:CreateTexture(nil, "ARTWORK")
    headerBg:SetPoint("TOPLEFT", 4, -4)
    headerBg:SetPoint("TOPRIGHT", -4, -4)
    headerBg:SetHeight(46)
    headerBg:SetColorTexture(0.06, 0.16, 0.34, 0.95)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -12)
    title:SetText("|cff00aeffWOWEngine|r |cffffd100Setup & Onboarding Wizard|r")

    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    f.subtitle = subtitle

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Step Indicator Tabs (Clickable 1..5)
    f.stepTabs = {}
    local tabNames = { "1. Scan Alts", "2. Bank & Brand", "3. Mail Routes", "4. Addons", "5. Test & Finish" }
    for i = 1, OB.totalSteps do
        local tab = CreateActionButton(f, 97, 22, tabNames[i], function()
            OB:SetStep(i)
        end)
        tab:SetPoint("TOPLEFT", 14 + (i - 1) * 102, -56)
        f.stepTabs[i] = tab
    end

    -- Content Container
    local content = CreateFrame("Frame", nil, f, template)
    content:SetPoint("TOPLEFT", 14, -86)
    content:SetPoint("BOTTOMRIGHT", -14, 48)
    ApplyBlizzardBlueBackdrop(content, 0.88)
    f.content = content

    -- ==========================================
    -- STEP 1: SCAN VERIFIED CHARACTERS
    -- ==========================================
    local p1 = CreateFrame("Frame", nil, content)
    p1:SetAllPoints()
    OB.stepPanels[1] = p1

    local p1Title = p1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p1Title:SetPoint("TOPLEFT", 14, -12)
    p1Title:SetText("|cffffd100Step 1: Verify Real Character Names Before Mailing|r")

    local p1Desc = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p1Desc:SetPoint("TOPLEFT", p1Title, "BOTTOMLEFT", 0, -6)
    p1Desc:SetWidth(475)
    p1Desc:SetJustifyH("LEFT")
    p1Desc:SetText("WOWEngine never guesses alt names. Click Scan Now to collect exact server names and professions from this character, Guild, Friends, and Altoholic/DataStore.")

    local p1ScanBtn = CreateActionButton(p1, 180, 26, "Scan Verified Characters", function()
        NS.Roster:ScanAll(false)
        OB:RefreshCurrentStep()
    end)
    p1ScanBtn:SetPoint("TOPLEFT", p1Desc, "BOTTOMLEFT", 0, -10)

    local p1LogBtn = CreateActionButton(p1, 165, 26, "Print Full Roster to Chat", function()
        NS.Roster:PrintRoster()
    end)
    p1LogBtn:SetPoint("LEFT", p1ScanBtn, "RIGHT", 10, 0)

    local p1Summary = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p1Summary:SetPoint("TOPLEFT", p1ScanBtn, "BOTTOMLEFT", 0, -12)
    p1Summary:SetWidth(475)
    p1Summary:SetJustifyH("LEFT")
    p1.summary = p1Summary

    local p1List = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p1List:SetPoint("TOPLEFT", p1Summary, "BOTTOMLEFT", 0, -8)
    p1List:SetWidth(475)
    p1List:SetJustifyH("LEFT")
    p1.rosterList = p1List

    -- ==========================================
    -- STEP 2: BANK ALT & INTEGRATED ILLUSORYBIAS BRANDING
    -- ==========================================
    local p2 = CreateFrame("Frame", nil, content)
    p2:SetAllPoints()
    OB.stepPanels[2] = p2

    local p2Title = p2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p2Title:SetPoint("TOPLEFT", 14, -12)
    p2Title:SetText("|cffffd100Step 2: Register Bank Alt & IllusoryBias Naming Profile|r")

    local p2Desc = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p2Desc:SetPoint("TOPLEFT", p2Title, "BOTTOMLEFT", 0, -6)
    p2Desc:SetWidth(475)
    p2Desc:SetJustifyH("LEFT")
    p2Desc:SetText("WOWEngine v1.6.0 is now a single unified addon for both Horde & Alliance with integrated IllusoryBias tools. Register your bank alt and preview your derivative naming below.")

    local function StepStep2Char(delta)
        local list = NS.Roster:GetSortedVerifiedList()
        if #list == 0 then return end
        OB.step2CharIndex = ((OB.step2CharIndex - 1 + (delta or 1)) % #list) + 1
        OB:RefreshCurrentStep()
    end

    local p2CharPrev = CreateActionButton(p2, 24, 24, "<", function() StepStep2Char(-1) end)
    p2CharPrev:SetPoint("TOPLEFT", p2Desc, "BOTTOMLEFT", 0, -12)
    p2.charPrevBtn = p2CharPrev

    local p2CharBtn = CreateActionButton(p2, 226, 24, "Select Character", function() StepStep2Char(1) end)
    p2CharBtn:SetPoint("LEFT", p2CharPrev, "RIGHT", 3, 0)
    p2.charBtn = p2CharBtn

    local p2CharNext = CreateActionButton(p2, 24, 24, ">", function() StepStep2Char(1) end)
    p2CharNext:SetPoint("LEFT", p2CharBtn, "RIGHT", 3, 0)
    p2.charNextBtn = p2CharNext

    local p2BankBtn = CreateActionButton(p2, 188, 24, "Set Selected as BankAlt", function()
        NS.Roster:ScanCurrentPlayer()
        local list = NS.Roster:GetSortedVerifiedList()
        local picked = (list and list[OB.step2CharIndex] and list[OB.step2CharIndex].name) or C.GetPlayerName()
        if picked then
            if NS.Roster:HasTargetInCategory("BankAlt", picked) then
                NS.Roster:RemoveTargetFromCategory("BankAlt", picked, true)
                NS:Print("Removed BankAlt: |cffff9900" .. picked .. "|r.")
            else
                NS.Roster:AddTargetToCategory("BankAlt", picked, true)
                NS:Print("Verified BankAlt added: |cff00ff00" .. picked .. "|r (never self-mails).")
            end
            OB:RefreshCurrentStep()
        end
    end)
    p2BankBtn:SetPoint("LEFT", p2CharNext, "RIGHT", 8, 0)
    p2.bankBtn = p2BankBtn

    local p2Info = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p2Info:SetPoint("TOPLEFT", p2CharPrev, "BOTTOMLEFT", 0, -14)
    p2Info:SetWidth(475)
    p2Info:SetJustifyH("LEFT")
    p2Info:SetText("Loading profile...")
    p2.info = p2Info

    local p2NameBtn = CreateActionButton(p2, 245, 24, "Preview Derivative Alt Name", function()
        local list = NS.Roster:GetSortedVerifiedList()
        local picked = list and list[OB.step2CharIndex]
        local classToken = (picked and picked.class) or select(2, UnitClass("player"))
        local profs = (picked and picked.professions) or C.GetPlayerProfessions()
        local plist = {}
        for p in pairs(profs) do table.insert(plist, p) end
        local suggestion = NS:SuggestDerivativeName(classToken, plist[1], plist[2])
        NS:Print("IllusoryBias Derivative Name Preview: |cffffd100" .. suggestion .. "|r")
        p2.preview:SetText("Suggested Derivative Name: |cffffd100" .. suggestion .. "|r")
    end)
    p2NameBtn:SetPoint("TOPLEFT", p2, "TOPLEFT", 14, -185)

    local p2Preview = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p2Preview:SetPoint("TOPLEFT", p2NameBtn, "BOTTOMLEFT", 0, -8)
    p2Preview:SetWidth(475)
    p2Preview:SetJustifyH("LEFT")
    p2.preview = p2Preview

    -- ==========================================
    -- STEP 3: CHARACTER-FIRST DYNAMIC PROFESSION & MAIL SETUP
    -- ==========================================
    local p3 = CreateFrame("Frame", nil, content)
    p3:SetAllPoints()
    OB.stepPanels[3] = p3

    local p3Title = p3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p3Title:SetPoint("TOPLEFT", 14, -10)
    p3Title:SetText("|cffffd100Step 3: Character Profession Profile & Dynamic Mail Routing|r")

    -- Character Selector Bar with "<" [Character Name] ">" buttons
    local function StepStep3Char(delta)
        local list = NS.Roster:GetSortedVerifiedList()
        if #list > 0 then
            OB.step3CharIndex = ((OB.step3CharIndex - 1 + (delta or 1)) % #list) + 1
            OB:RefreshCurrentStep()
        end
    end

    local cPrevBtn = CreateActionButton(p3, 26, 24, "<", function() StepStep3Char(-1) end)
    cPrevBtn:SetPoint("TOPLEFT", 14, -34)
    p3.cPrevBtn = cPrevBtn

    local cNextBtn = CreateActionButton(p3, 26, 24, ">", function() StepStep3Char(1) end)
    cNextBtn:SetPoint("TOPRIGHT", -14, -34)
    p3.cNextBtn = cNextBtn

    local charBtn = CreateActionButton(p3, 412, 24, "Select Character", function() StepStep3Char(1) end)
    charBtn:ClearAllPoints()
    charBtn:SetPoint("LEFT", cPrevBtn, "RIGHT", 4, 0)
    charBtn:SetPoint("RIGHT", cNextBtn, "LEFT", -4, 0)
    local charFS = charBtn:GetFontString()
    if charFS then
        charFS:ClearAllPoints()
        charFS:SetPoint("LEFT", charBtn, "LEFT", 8, 0)
        charFS:SetPoint("RIGHT", charBtn, "RIGHT", -8, 0)
        charFS:SetJustifyH("CENTER")
        if charFS.SetWordWrap then charFS:SetWordWrap(false) end
    end
    p3.charBtn = charBtn
    p3.charBanner = charBtn

    -- Dynamic Phase Status Line
    local phaseTxt = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    phaseTxt:SetPoint("TOPLEFT", 14, -62)
    phaseTxt:SetWidth(478)
    phaseTxt:SetJustifyH("LEFT")
    p3.phaseTxt = phaseTxt

    -- Primary Profession 1 Row
    local p1Lbl = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p1Lbl:SetPoint("TOPLEFT", 14, -88)
    p1Lbl:SetWidth(102)
    p1Lbl:SetJustifyH("LEFT")
    p1Lbl:SetText("Primary Prof 1:")

    local p1Btn = CreateActionButton(p3, 215, 22, "No Profession (Click to Plan)", function()
        local list = NS.Roster:GetSortedVerifiedList()
        if #list == 0 then return end
        local info = list[OB.step3CharIndex]
        if not info then return end
        local prof = NS.Roster:GetCharacterProfessionProfile(info.name)
        if prof.p1 and prof.p1.learned then
            NS:Print(info.name .. " already learned |cff00ff00" .. prof.p1.name .. "|r (auto-detected).")
        else
            NS.Roster:CyclePlannedProfession(info.name, 1)
            OB:RefreshCurrentStep()
        end
    end)
    p1Btn:SetPoint("LEFT", p1Lbl, "RIGHT", 4, 0)
    p3.p1Btn = p1Btn

    local p1ShareBtn = CreateActionButton(p3, 156, 22, "Shared / Set Priority", function()
        if p3.p1SharedProf and p3.p1SharedCat then
            OB:OpenSharedPriorityPopup(p3.p1SharedProf, p3.p1SharedCat)
        end
    end)
    p1ShareBtn:SetPoint("LEFT", p1Btn, "RIGHT", 8, 0)
    p1ShareBtn:Hide()
    p3.p1ShareBtn = p1ShareBtn

    local p1Share = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p1Share:SetPoint("LEFT", p1Btn, "RIGHT", 8, 0)
    p1Share:SetWidth(156)
    p1Share:SetJustifyH("LEFT")
    p3.p1Share = p1Share

    -- Primary Profession 2 Row
    local p2Lbl = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p2Lbl:SetPoint("TOPLEFT", 14, -118)
    p2Lbl:SetWidth(102)
    p2Lbl:SetJustifyH("LEFT")
    p2Lbl:SetText("Primary Prof 2:")

    local p2Btn = CreateActionButton(p3, 215, 22, "No Profession (Click to Plan)", function()
        local list = NS.Roster:GetSortedVerifiedList()
        if #list == 0 then return end
        local info = list[OB.step3CharIndex]
        if not info then return end
        local prof = NS.Roster:GetCharacterProfessionProfile(info.name)
        if prof.p2 and prof.p2.learned then
            NS:Print(info.name .. " already learned |cff00ff00" .. prof.p2.name .. "|r (auto-detected).")
        else
            NS.Roster:CyclePlannedProfession(info.name, 2)
            OB:RefreshCurrentStep()
        end
    end)
    p2Btn:SetPoint("LEFT", p2Lbl, "RIGHT", 4, 0)
    p3.p2Btn = p2Btn

    local p2ShareBtn = CreateActionButton(p3, 156, 22, "Shared / Set Priority", function()
        if p3.p2SharedProf and p3.p2SharedCat then
            OB:OpenSharedPriorityPopup(p3.p2SharedProf, p3.p2SharedCat)
        end
    end)
    p2ShareBtn:SetPoint("LEFT", p2Btn, "RIGHT", 8, 0)
    p2ShareBtn:Hide()
    p3.p2ShareBtn = p2ShareBtn

    local p2Share = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p2Share:SetPoint("LEFT", p2Btn, "RIGHT", 8, 0)
    p2Share:SetWidth(156)
    p2Share:SetJustifyH("LEFT")
    p3.p2Share = p2Share

    -- Sub-Professions Display
    local subTxt = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subTxt:SetPoint("TOPLEFT", 14, -148)
    subTxt:SetWidth(478)
    subTxt:SetJustifyH("LEFT")
    p3.subTxt = subTxt

    -- Bank / AH Vault Toggle for Selected Character
    local cbBank = CreateCheckbox(p3, "Assign this character as a Bank / BoE Vault recipient",
        function()
            local list = NS.Roster:GetSortedVerifiedList()
            local info = list[OB.step3CharIndex]
            return info and NS.Roster:HasTargetInCategory("BankAlt", info.name) or false
        end,
        function(v)
            local list = NS.Roster:GetSortedVerifiedList()
            local info = list[OB.step3CharIndex]
            if not info then return end
            if v then
                NS.Roster:AddTargetToCategory("BankAlt", info.name, true)
            else
                NS.Roster:RemoveTargetFromCategory("BankAlt", info.name, true)
            end
        end)
    cbBank:SetPoint("TOPLEFT", 14, -166)
    p3.cbBank = cbBank

    -- Enchanter Option: Send all Auction House / Disenchantable BoEs to this character
    local cbDisenchantBoE = CreateCheckbox(p3, "|cffffd100Enchanter:|r Send all AH / Disenchantable BoEs here",
        function()
            local list = NS.Roster:GetSortedVerifiedList()
            local info = list[OB.step3CharIndex]
            return info and NS.Roster:HasTargetInCategory("DisenchantBoE", info.name) or false
        end,
        function(v)
            local list = NS.Roster:GetSortedVerifiedList()
            local info = list[OB.step3CharIndex]
            if not info then return end
            if v then
                NS.Roster:AddTargetToCategory("DisenchantBoE", info.name, true)
                NS:Print("All AH / Disenchantable BoEs will now route to |cff00ff00" .. info.name .. "|r.")
            else
                NS.Roster:RemoveTargetFromCategory("DisenchantBoE", info.name, true)
                NS:Print("Removed |cffff9900" .. info.name .. "|r from AH / Disenchantable BoE routing.")
            end
        end)
    cbDisenchantBoE:SetPoint("TOPLEFT", 14, -188)
    p3.cbDisenchantBoE = cbDisenchantBoE

    -- Exclude / Include Character from Wave Leveling Sync (keeps them available for Mail)
    local cbExcludeWave = CreateCheckbox(p3, "Exclude this character from Wave Leveling Sync (keep for Mail only)",
        function()
            local list = NS.Roster:GetSortedVerifiedList()
            local info = list[OB.step3CharIndex]
            if not info then return false end
            return not NS.Roster:IsIncludedInWave(info)
        end,
        function(excluded)
            local list = NS.Roster:GetSortedVerifiedList()
            local info = list[OB.step3CharIndex]
            if not info then return end
            NS.Roster:SetWaveExcluded(info.name, excluded)
            if NS.WaveTracker then
                if NS.WaveTracker.RefreshUI then NS.WaveTracker:RefreshUI() end
                if NS.WaveTracker.RefreshQuestieDock then NS.WaveTracker:RefreshQuestieDock() end
            end
        end)
    cbExcludeWave:SetPoint("TOPLEFT", 14, -210)
    p3.cbExcludeWave = cbExcludeWave

    -- Exclude Character from Mail Routing completely
    local cbExcludeMail = CreateCheckbox(p3, "Exclude this character from Mail Routing (never send mail here)",
        function()
            local list = NS.Roster:GetSortedVerifiedList()
            local info = list[OB.step3CharIndex]
            return info and NS.Roster:IsExcludedFromMail(info) or false
        end,
        function(excluded)
            local list = NS.Roster:GetSortedVerifiedList()
            local info = list[OB.step3CharIndex]
            if not info then return end
            NS.Roster:SetMailExcluded(info.name, excluded)
            if excluded then
                NS:Print("Excluded |cffff9900" .. info.name .. "|r from all Mail Routing.")
            else
                NS:Print("Re-enabled |cff00ff00" .. info.name .. "|r for Mail Routing.")
            end
        end)
    cbExcludeMail:SetPoint("TOPLEFT", 14, -232)
    p3.cbExcludeMail = cbExcludeMail

    -- Mastercraft Guidance & Shared Alts Summary Box
    local mcTxt = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mcTxt:SetPoint("TOPLEFT", 14, -258)
    mcTxt:SetWidth(478)
    mcTxt:SetJustifyH("LEFT")
    p3.mcTxt = mcTxt

    -- Bottom Action Buttons
    local p3McBtn = CreateActionButton(p3, 175, 22, "Mastercraft: Leveling Use", function()
        if WOWEngineDB.mastercraftPriority == "leveling" then
            WOWEngineDB.mastercraftPriority = "profit"
        else
            WOWEngineDB.mastercraftPriority = "leveling"
        end
        OB:RefreshCurrentStep()
    end)
    p3McBtn:SetPoint("BOTTOMLEFT", 14, 10)
    p3.mcBtn = p3McBtn

    local p3TrainBtn = CreateActionButton(p3, 105, 22, "Trainer Coords", function()
        if NS.WaveTracker and NS.WaveTracker.PrintTrainerLookup then
            NS.WaveTracker:PrintTrainerLookup("")
        end
    end)
    p3TrainBtn:SetPoint("LEFT", p3McBtn, "RIGHT", 6, 0)

    local p3CustomBtn = CreateActionButton(p3, 175, 22, "Custom Additions (0)...", function()
        OB:OpenCustomAdditionsPopup()
    end)
    p3CustomBtn:SetPoint("BOTTOMRIGHT", -14, 10)
    p3.customBtn = p3CustomBtn

    -- ==========================================
    -- STEP 4: ALTOHOLIC, MASTERCRAFT & SAFEGUARDS
    -- ==========================================
    local p4 = CreateFrame("Frame", nil, content)
    p4:SetAllPoints()
    OB.stepPanels[4] = p4

    local p4Title = p4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p4Title:SetPoint("TOPLEFT", 14, -12)
    p4Title:SetText("|cffffd100Step 4: Addon Bridges & Blizzard TOS Safeguards|r")

    local p4Status = p4:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p4Status:SetPoint("TOPLEFT", p4Title, "BOTTOMLEFT", 0, -6)
    p4Status:SetWidth(480)
    p4Status:SetJustifyH("LEFT")
    p4.statusText = p4Status

    local cbAlto = CreateCheckbox(p4, "Sync alts, professions, bags & gold from Altoholic / DataStore",
        function() return WOWEngineDB.syncAltoholic end,
        function(v)
            WOWEngineDB.syncAltoholic = v
            if v then NS.Roster:ScanAll(true) end
        end)
    cbAlto:SetPoint("TOPLEFT", 14, -196)
    p4.cbAlto = cbAlto

    local cbMC = CreateCheckbox(p4, "Protect reagents queued in Mastercraft from being mailed",
        function() return WOWEngineDB.protectMastercraftQueue end,
        function(v) WOWEngineDB.protectMastercraftQueue = v end)
    cbMC:SetPoint("TOPLEFT", cbAlto, "BOTTOMLEFT", 0, -2)
    p4.cbMC = cbMC

    local cbAuc = CreateCheckbox(p4, "Protect items flagged by Auctionator holds",
        function() return WOWEngineDB.protectAuctionatorPosted end,
        function(v) WOWEngineDB.protectAuctionatorPosted = v end)
    cbAuc:SetPoint("TOPLEFT", cbMC, "BOTTOMLEFT", 0, -2)
    p4.cbAuc = cbAuc

    local cbKeepOwn = CreateCheckbox(p4, "Keep mats on this character if it is assigned to that category",
        function() return WOWEngineDB.keepOwnCategoryMats end,
        function(v) WOWEngineDB.keepOwnCategoryMats = v end)
    cbKeepOwn:SetPoint("TOPLEFT", cbAuc, "BOTTOMLEFT", 0, -2)
    p4.cbKeepOwn = cbKeepOwn

    local cbMailEqBoE = CreateCheckbox(p4, "Include Equippable Disenchantable BoEs in Mailer",
        function() return not (WOWEngineDB and WOWEngineDB.mailEquippableDisenchantableBoEs == false) end,
        function(v) WOWEngineDB.mailEquippableDisenchantableBoEs = v end,
        "When enabled, all disenchantable BoE gear (Uncommon, Rare, and Epic armor/weapons) is routed to your Enchanter/Bank Alt even if your current character can equip it. When disabled, BoEs equippable by the current character are skipped.")
    cbMailEqBoE:SetPoint("TOPLEFT", cbKeepOwn, "BOTTOMLEFT", 0, -2)
    p4.cbMailEqBoE = cbMailEqBoE

    local p4SyncBtn = CreateActionButton(p4, 195, 24, "Sync Altoholic & Re-Check", function()
        local added = NS.Roster:ScanAltoholic()
        NS.Roster:AutoMapVerifiedRoutes(false)
        NS:Print("Altoholic/DataStore sync complete (" .. tostring(added) .. " new alts imported).")
        OB:RefreshCurrentStep()
    end)
    p4SyncBtn:SetPoint("TOPLEFT", cbMailEqBoE, "BOTTOMLEFT", 0, -8)

    local p4ModeBtn = CreateActionButton(p4, 215, 24, "Multi-Alt: Round-Robin", function()
        if WOWEngineDB.multiAltMode == "roundrobin" then
            WOWEngineDB.multiAltMode = "priority"
        else
            WOWEngineDB.multiAltMode = "roundrobin"
        end
        OB:RefreshCurrentStep()
    end)
    p4ModeBtn:SetPoint("LEFT", p4SyncBtn, "RIGHT", 10, 0)
    p4.modeBtn = p4ModeBtn

    -- ==========================================
    -- STEP 5: LIVE TEST & FINISH
    -- ==========================================
    local p5 = CreateFrame("Frame", nil, content)
    p5:SetAllPoints()
    OB.stepPanels[5] = p5

    local p5Title = p5:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p5Title:SetPoint("TOPLEFT", 14, -12)
    p5Title:SetText("|cffffd100Step 5: Run Live Step 1 Verification Tests|r")

    local p5Desc = p5:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p5Desc:SetPoint("TOPLEFT", p5Title, "BOTTOMLEFT", 0, -6)
    p5Desc:SetWidth(475)
    p5Desc:SetJustifyH("LEFT")
    p5Desc:SetText("Stand at a Mailbox or Bank and click below to test bundled shipments (e.g. Cloth + Enchanting together), self-mail blocking, and sorting. Each batch requires 1 click on Send.")

    local bStage = CreateActionButton(p5, 222, 26, "1. Stage Mailbox Shipment", function()
        NS.MailRouter:StageNextBatch(nil)
    end)
    bStage:SetPoint("TOPLEFT", p5Desc, "BOTTOMLEFT", 0, -14)

    local bPrevAlt = CreateActionButton(p5, 24, 26, "<", function()
        if NS.MailRouter.CyclePrevTarget then
            NS.MailRouter:CyclePrevTarget()
        else
            NS.MailRouter:CycleNextTarget()
        end
    end)
    bPrevAlt:SetPoint("LEFT", bStage, "RIGHT", 14, 0)

    local bNextAlt = CreateActionButton(p5, 168, 26, "2. Switch Waiting Alt", function()
        NS.MailRouter:CycleNextTarget()
    end)
    bNextAlt:SetPoint("LEFT", bPrevAlt, "RIGHT", 3, 0)

    local bNextAltR = CreateActionButton(p5, 24, 26, ">", function()
        NS.MailRouter:CycleNextTarget()
    end)
    bNextAltR:SetPoint("LEFT", bNextAlt, "RIGHT", 3, 0)

    local bBags = CreateActionButton(p5, 222, 26, "3. Sort Bags (/hordeship bags)", function()
        NS.BankSorter:RunSort("bags")
    end)
    bBags:SetPoint("TOPLEFT", bStage, "BOTTOMLEFT", 0, -10)

    local bBank = CreateActionButton(p5, 222, 26, "4. Sort Bank (/hordeship bank)", function()
        NS.BankSorter:RunSort("bank")
    end)
    bBank:SetPoint("LEFT", bBags, "RIGHT", 14, 0)

    local bLedger = CreateActionButton(p5, 222, 26, "5. Wealth Ledger (/hordebank)", function()
        NS.BankSorter:PrintGoldLedger()
    end)
    bLedger:SetPoint("TOPLEFT", bBags, "BOTTOMLEFT", 0, -10)

    local bDiag = CreateActionButton(p5, 222, 26, "6. Copy Bug Report (/he bug)", function()
        if NS.BugReporter and NS.BugReporter.Show then
            local ok, err = pcall(function() NS.BugReporter:Show() end)
            if not ok then
                if NS.RecordError then NS:RecordError("CopyBugReport", err) end
                NS:Print("|cffff4444Bug Reporter error:|r " .. tostring(err))
            end
        else
            NS:Print("|cffff9900BugReporter module not loaded.|r Type |cffffd100/he diag|r to print diagnostics.")
        end
    end)
    bDiag:SetPoint("LEFT", bLedger, "RIGHT", 14, 0)

    local p5Ready = p5:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p5Ready:SetPoint("TOPLEFT", bLedger, "BOTTOMLEFT", 0, -14)
    p5Ready:SetWidth(475)
    p5Ready:SetJustifyH("LEFT")
    p5.readyText = p5Ready

    -- ==========================================
    -- FOOTER NAVIGATION BAR
    -- ==========================================
    local prevBtn = CreateActionButton(f, 92, 26, "< Back", function()
        if OB.currentStep > 1 then
            OB:SetStep(OB.currentStep - 1)
        end
    end)
    prevBtn:SetPoint("BOTTOMLEFT", 14, 14)
    f.prevBtn = prevBtn

    local nextBtn = CreateActionButton(f, 130, 26, "Next >", function()
        if OB.currentStep < OB.totalSteps then
            OB:SetStep(OB.currentStep + 1)
        else
            WOWEngineDB.onboardingCompleted = true
            NS:Print("|cff00ff00Onboarding completed!|r Re-open anytime via |cffffd100/he setup|r or the Minimap button.")
            f:Hide()
        end
    end)
    nextBtn:SetPoint("BOTTOMRIGHT", -14, 14)
    f.nextBtn = nextBtn

    local footerNote = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footerNote:SetPoint("BOTTOM", 0, 21)
    footerNote:SetText("IllusoryBias | Blizzard TOS Compliant | /he setup")

    OB.frame = f
    return f
end

function OB:RefreshCurrentStep()
    if not OB.frame then return end
    local realm, faction = NS:GetContextKeys()
    local player = C.GetPlayerName() or "Player"
    OB.frame.subtitle:SetText(string.format("v%s | %s (%s - %s) | Step %d of %d",
        NS.Version, player, realm, faction, OB.currentStep, OB.totalSteps))

    for i = 1, OB.totalSteps do
        local tab = OB.frame.stepTabs[i]
        if i == OB.currentStep then
            tab:Disable()
            OB.stepPanels[i]:Show()
        else
            tab:Enable()
            OB.stepPanels[i]:Hide()
        end
    end

    if OB.currentStep > 1 then
        OB.frame.prevBtn:Enable()
    else
        OB.frame.prevBtn:Disable()
    end

    if OB.currentStep == OB.totalSteps then
        OB.frame.nextBtn:SetText("Finish Setup")
    else
        OB.frame.nextBtn:SetText("Next >")
    end

    if OB.currentStep == 1 then
        local p1 = OB.stepPanels[1]
        local list = NS.Roster:GetSortedVerifiedList()
        local altoStr = C.IsAltoholicAvailable() and "|cff00ff00Detected|r" or "|cffff9900Not Installed|r"
        p1.summary:SetText(string.format("Verified Characters on %s (%s): |cff00ff00%d|r  |  Altoholic/DataStore: %s",
            realm, faction, #list, altoStr))
        local lines = {}
        for idx, info in ipairs(list) do
            if idx <= 9 then
                local profs = {}
                if info.professions then
                    for pn in pairs(info.professions) do table.insert(profs, pn) end
                end
                local ps = (#profs > 0) and (" [" .. table.concat(profs, ", ") .. "]") or ""
                local selfTag = C.IsCurrentPlayer(info.name) and " |cff00aeff(You)|r" or ""
                table.insert(lines, string.format("- |cffffd100%s|r%s (Lv%d %s, via %s)%s",
                    info.name, selfTag, info.level or 0, info.class or "?", info.source or "scan", ps))
            end
        end
        if #list > 9 then
            table.insert(lines, string.format("...and %d more (click Print Full Roster to Chat).", #list - 9))
        end
        if #lines == 0 then
            table.insert(lines, "Click 'Scan Verified Characters' above to begin.")
        end
        p1.rosterList:SetText(table.concat(lines, "\n"))

    elseif OB.currentStep == 2 then
        local p2 = OB.stepPanels[2]
        local list = NS.Roster:GetSortedVerifiedList()
        if #list == 0 then
            if p2.charBtn then p2.charBtn:SetText("|cffff9900No characters — run Step 1 Scan|r") end
            if p2.bankBtn then p2.bankBtn:SetText("Set Current as BankAlt") end
        else
            if OB.step2CharIndex < 1 or OB.step2CharIndex > #list then
                OB.step2CharIndex = 1
            end
            local picked = list[OB.step2CharIndex]
            local selfTag = C.IsCurrentPlayer(picked.name) and " (You)" or ""
            if p2.charBtn then
                p2.charBtn:SetText(string.format("[%d/%d] %s%s", OB.step2CharIndex, #list, picked.name, selfTag))
            end
            if p2.bankBtn then
                if NS.Roster:HasTargetInCategory("BankAlt", picked.name) then
                    p2.bankBtn:SetText("Remove BankAlt Role")
                else
                    p2.bankBtn:SetText("Set Selected as BankAlt")
                end
            end
        end
        local bankList = NS.Roster:GetCategoryTargets("BankAlt")
        local bankStr = (#bankList > 0) and table.concat(bankList, ", ") or "|cffff9900Not set yet|r"
        local fp = NS:GetFactionProfile()
        local activeMod = fp.suiteName .. " (" .. fp.plan .. ")"
        p2.info:SetText(string.format(
            "Registered BankAlt(s): |cff00ff00%s|r\nFaction Module: |cff00aeff%s|r\nBrand Handle: |cffffd100%s|r (Integrated across Core + Faction Modules)",
            bankStr, activeMod, WOWEngineDB.brandHandle or "Illusorybias"
        ))

    elseif OB.currentStep == 3 then
        local p3 = OB.stepPanels[3]
        local list = NS.Roster:GetSortedVerifiedList()
        if #list == 0 then
            p3.charBanner:SetText("|cffff9900No verified characters — run Step 1 Scan|r")
            p3.phaseTxt:SetText("Click Step 1 -> Scan Verified Characters first.")
            p3.p1Btn:SetText("Unscanned")
            p3.p2Btn:SetText("Unscanned")
            p3.p1Share:SetText("")
            p3.p2Share:SetText("")
            p3.p1ShareBtn:Hide()
            p3.p2ShareBtn:Hide()
            p3.subTxt:SetText("")
            p3.mcTxt:SetText("")
        else
            if OB.step3CharIndex < 1 or OB.step3CharIndex > #list then
                OB.step3CharIndex = 1
            end
            local info = list[OB.step3CharIndex]
            local prof = NS.Roster:GetCharacterProfessionProfile(info.name)
            local selfTag = C.IsCurrentPlayer(info.name) and " |cff00aeff(You)|r" or ""
            p3.charBanner:SetText(string.format("[%d/%d] |cff00ff00%s|r%s (Lv%d %s)",
                OB.step3CharIndex, #list, info.name, selfTag, prof.level, prof.class))

            if prof.phase == 1 then
                p3.phaseTxt:SetText("|cffff9900Phase 1 (New / Unlearned):|r No professions detected yet. Click Primary Prof 1 or 2 to pick what you plan to learn.")
            elseif prof.phase == 2 then
                p3.phaseTxt:SetText("|cff00ff00Phase 2 (Learned & Auto-Mapped):|r Professions detected and mapped to mail routing automatically.")
            else
                p3.phaseTxt:SetText("|cff00aeffPhase 3 (Mastercraft Guided):|r Learned professions synced with Mastercraft for leveling use & profitability.")
            end

            local function applyProfSlot(slotData, mainBtn, shareBtn, shareLbl, slotNum)
                if not slotData then
                    mainBtn:SetText("|cffaaaaaaNone Detected (Click to Plan)|r")
                    shareBtn:Hide()
                    shareLbl:SetText("")
                    shareLbl:Show()
                    if slotNum == 1 then p3.p1SharedProf, p3.p1SharedCat = nil, nil else p3.p2SharedProf, p3.p2SharedCat = nil, nil end
                    return
                end

                if slotData.learned then
                    mainBtn:SetText(string.format("|cff00ff00%s|r |cffffd100(%d)|r", slotData.name, slotData.rank))
                else
                    mainBtn:SetText(string.format("|cffff9900Planned: %s|r", slotData.name))
                end

                local cats = NS.Roster:GetCategoriesForProfession(slotData.name)
                local primaryCat = cats[1]
                local active, pool = {}, {}
                if primaryCat then
                    active, pool = NS.Roster:GetSharedPoolForProfession(slotData.name, primaryCat)
                end
                local totalShared = #active + #pool

                if slotNum == 1 then
                    p3.p1SharedProf, p3.p1SharedCat = slotData.name, primaryCat
                else
                    p3.p2SharedProf, p3.p2SharedCat = slotData.name, primaryCat
                end

                if primaryCat and totalShared > 1 then
                    -- Shared profession: show ONLY the button to view shared characters & set priority
                    shareLbl:Hide()
                    shareBtn:SetText(string.format("Shared (%d) - Priority", totalShared))
                    shareBtn:Show()
                else
                    shareBtn:Hide()
                    shareLbl:SetText("|cff888888Primary owner|r")
                    shareLbl:Show()
                end
            end

            applyProfSlot(prof.p1, p3.p1Btn, p3.p1ShareBtn, p3.p1Share, 1)
            applyProfSlot(prof.p2, p3.p2Btn, p3.p2ShareBtn, p3.p2Share, 2)

            local subParts = {}
            for _, sName in ipairs({ "Cooking", "Fishing", "First Aid" }) do
                local r = prof.subs and prof.subs[sName]
                if r then
                    table.insert(subParts, "|cff00ff00" .. sName .. " (" .. tostring(r) .. ")|r")
                else
                    table.insert(subParts, "|cff888888" .. sName .. " (Not Learned)|r")
                end
            end
            p3.subTxt:SetText("Sub-Professions: " .. table.concat(subParts, "  |  "))
            p3.cbBank:Refresh()
            p3.cbDisenchantBoE:Refresh()
            p3.cbExcludeWave:Refresh()
            p3.cbExcludeMail:Refresh()

            local mcAvail = C.IsMastercraftAvailable()
            local mcMode = (WOWEngineDB.mastercraftPriority == "profit") and "Profitability (AH Value)" or "Leveling Use (Skill-Up)"
            p3.mcBtn:SetText("Mastercraft: " .. ((WOWEngineDB.mastercraftPriority == "profit") and "Profitability" or "Leveling Use"))
            p3.mcTxt:SetText(string.format(
                "|cff00aeffMastercraft Bridge:|r %s  |  Focus: |cffffd100%s|r\nTip: Once learned, mats route automatically to this character. Use Custom Additions for extra items (e.g. Dyes, Potions).",
                mcAvail and "|cff00ff00Connected|r" or "|cffaaaaaaInstall Mastercraft for 1-300 profit guidance|r",
                mcMode
            ))
        end

        local customCount = #NS:GetCustomRules()
        p3.customBtn:SetText(string.format("Custom Additions (%d)...", customCount))

    elseif OB.currentStep == 4 then
        local p4 = OB.stepPanels[4]
        local hasAlto, hasMC, hasQst, hasAuc = NS:GetCompanionAddonStatus()
        local alto = hasAlto and "|cff00ff00Connected|r" or "|cffff5555Missing|r"
        local mc = hasMC and "|cff00ff00Connected|r" or "|cffff5555Missing|r"
        local qst = hasQst and "|cff00ff00Connected|r" or "|cffff5555Missing|r"
        local auc = hasAuc and "|cff00ff00Connected|r" or "|cffff5555Missing|r"
        p4.statusText:SetText(string.format(
            "|cffffd100Requires Altoholic (+ DataStore), Mastercraft, Questie & Auctionator:|r\n" ..
            "Altoholic: %s  |  Mastercraft: %s  |  Questie: %s  |  Auctionator: %s\n\n" ..
            "|cffff9900What will not work well without them:|r\n" ..
            "- |cffffd100Without Altoholic:|r Offline alt bag upgrade routing, played-time priority, offline gold ledger & automatic roster/profession sync require logging into every alt manually.\n" ..
            "- |cffffd100Without Mastercraft:|r Phase 3 leveling/profitability guidance & queued crafting reagent mail protection are disabled.\n" ..
            "- |cffffd100Without Questie:|r Docked Wave Heading on the Questie Quest List falls back to Blizzard's default tracker or standalone HUD.\n" ..
            "- |cffffd100Without Auctionator:|r Auction hold protection (preventing AH-flagged items from being mailed) & live AH price/profitability checks are disabled.",
            alto, mc, qst, auc
        ))
        p4.cbAlto:Refresh()
        p4.cbMC:Refresh()
        p4.cbAuc:Refresh()
        p4.cbKeepOwn:Refresh()
        if p4.cbMailEqBoE then p4.cbMailEqBoE:Refresh() end
        if WOWEngineDB.multiAltMode == "roundrobin" then
            p4.modeBtn:SetText("Multi-Alt: Round-Robin (Split)")
        else
            p4.modeBtn:SetText("Multi-Alt: Priority (Alt #1)")
        end

    elseif OB.currentStep == 5 then
        local p5 = OB.stepPanels[5]
        local rules = NS:GetActiveRules()
        local mappedCats = 0
        for _, cat in ipairs(NS.CATEGORIES) do
            local t = rules[cat.key]
            if type(t) == "table" and #t > 0 then
                mappedCats = mappedCats + 1
            end
        end
        local customCount = #NS:GetCustomRules()
        p5.readyText:SetText(string.format(
            "Status: |cff00ff00%d|r verified alts | |cff00ff00%d|r categories mapped | |cff00ff00%d|r custom additions.\nClick |cffffd100Finish Setup|r once your mailbox test sends cleanly.",
            NS.Roster:GetVerifiedCount(), mappedCats, customCount
        ))
    end
end

function OB:SetStep(stepNum)
    OB.currentStep = math.max(1, math.min(OB.totalSteps, stepNum or 1))
    OB:RefreshCurrentStep()
end

function OB:Show(stepNum)
    local f = OB:BuildFrame()
    if stepNum then
        OB.currentStep = stepNum
    end
    NS.Roster:ScanAll(true)
    -- Default Step 2 & Step 3 character selectors to the currently logged-in character
    local list = NS.Roster:GetSortedVerifiedList()
    for i, info in ipairs(list) do
        if C.IsCurrentPlayer(info.name) then
            OB.step2CharIndex = i
            OB.step3CharIndex = i
            break
        end
    end
    OB:RefreshCurrentStep()
    f:Show()
    f:Raise()
end

function OB:Toggle()
    local f = OB:BuildFrame()
    if f:IsShown() then
        f:Hide()
    else
        OB:Show(OB.currentStep)
    end
end

function OB:RefreshIfShown()
    if OB.frame and OB.frame:IsShown() then
        OB:RefreshCurrentStep()
    end
end
