local addonName, NS = ...
NS.Onboarding = {}
local OB = NS.Onboarding
local C = NS.Compat

OB.currentStep = 1
OB.totalSteps = 5
OB.frame = nil
OB.customFrame = nil
OB.customAltIndex = 1
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
            NS:Print("|cffff4444Onboarding UI error:|r " .. tostring(err))
        end
    end)
    return b
end

local function CreateCheckbox(parent, label, getVal, setVal)
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

    cb:SetScript("OnClick", function(self)
        local ok, err = pcall(function()
            setVal(self:GetChecked() and true or false)
            OB:RefreshCurrentStep()
        end)
        if not ok then
            NS:Print("|cffff4444Checkbox error:|r " .. tostring(err))
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

        local altBtn = CreateActionButton(cf, 295, 22, "Select Character", function()
            local list = NS.Roster:GetSortedVerifiedList()
            if #list == 0 then return end
            OB.customAltIndex = OB.customAltIndex + 1
            if OB.customAltIndex > #list then OB.customAltIndex = 1 end
            OB:RefreshCustomPopup()
        end)
        altBtn:SetPoint("LEFT", altLbl, "RIGHT", 10, 0)
        cf.altBtn = altBtn

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
            if OB.customAltIndex > #list then OB.customAltIndex = 1 end
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

function OB:BuildFrame()
    if OB.frame then return OB.frame end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", "WOWEngineOnboardingFrame", UIParent, template)
    f:SetSize(535, 425)
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
    p2Desc:SetText("All IllusoryBias companion tools are built directly into WOWEngine, HordeEngine, and AllianceEngine. Register your bank alt and preview your derivative naming below.")

    local p2BankBtn = CreateActionButton(p2, 235, 26, "Set Current Character as BankAlt", function()
        NS.Roster:ScanCurrentPlayer()
        local exact = C.GetPlayerName()
        if exact then
            NS.Roster:AddTargetToCategory("BankAlt", exact, true)
            NS:Print("Verified BankAlt added: |cff00ff00" .. exact .. "|r (never self-mails).")
            OB:RefreshCurrentStep()
        end
    end)
    p2BankBtn:SetPoint("TOPLEFT", p2Desc, "BOTTOMLEFT", 0, -14)

    local p2Info = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p2Info:SetPoint("TOPLEFT", p2BankBtn, "BOTTOMLEFT", 0, -14)
    p2Info:SetWidth(475)
    p2Info:SetJustifyH("LEFT")
    p2Info:SetText("Loading profile...")
    p2.info = p2Info

    local p2NameBtn = CreateActionButton(p2, 235, 24, "Preview Derivative Alt Name", function()
        local _, classToken = UnitClass("player")
        local profs = C.GetPlayerProfessions()
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
    -- STEP 3: SIMPLE 1-CLICK MAIL ROUTES + OPTIONAL "+Alt" & "Custom Additions"
    -- ==========================================
    local p3 = CreateFrame("Frame", nil, content)
    p3:SetAllPoints()
    OB.stepPanels[3] = p3

    local p3Title = p3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p3Title:SetPoint("TOPLEFT", 14, -12)
    p3Title:SetText("|cffffd100Step 3: Assign Verified Mail Recipients (Simple & Fast)|r")

    local p3Desc = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p3Desc:SetPoint("TOPLEFT", p3Title, "BOTTOMLEFT", 0, -4)
    p3Desc:SetWidth(475)
    p3Desc:SetJustifyH("LEFT")
    p3Desc:SetText("Click any row to pick its alt (assigning the same alt to Cloth + Enchanting bundles them together). Optional: click +Alt to add a 2nd alt, or Custom Additions below.")

    p3.rows = {}
    for idx, cat in ipairs(NS.CATEGORIES) do
        local yOff = -54 - (idx - 1) * 30
        local catKey = cat.key

        local lbl = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("TOPLEFT", 14, yOff - 4)
        lbl:SetWidth(138)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(cat.label .. ":")

        local valBtn = CreateActionButton(p3, 224, 22, "Unassigned (Click to Select)", function()
            OB:CyclePrimaryForCategory(catKey)
        end)
        valBtn:SetPoint("LEFT", lbl, "RIGHT", 6, 0)

        local addAltBtn = CreateActionButton(p3, 46, 22, "+Alt", function()
            OB:AddExtraAltToCategory(catKey)
        end)
        addAltBtn:SetPoint("LEFT", valBtn, "RIGHT", 4, 0)

        local clrBtn = CreateActionButton(p3, 48, 22, "Clear", function()
            NS.Roster:ClearCategory(catKey)
            OB:RefreshCurrentStep()
        end)
        clrBtn:SetPoint("LEFT", addAltBtn, "RIGHT", 4, 0)

        p3.rows[catKey] = valBtn
    end

    local p3AutoBtn = CreateActionButton(p3, 190, 22, "Auto-Map from Professions", function()
        NS.Roster:AutoMapVerifiedRoutes(true)
        OB:RefreshCurrentStep()
        NS:Print("Auto-mapped routes from verified character professions.")
    end)
    p3AutoBtn:SetPoint("BOTTOMLEFT", 14, 10)

    local p3CustomBtn = CreateActionButton(p3, 185, 22, "Custom Additions (0)...", function()
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
    p4Status:SetPoint("TOPLEFT", p4Title, "BOTTOMLEFT", 0, -8)
    p4Status:SetWidth(475)
    p4Status:SetJustifyH("LEFT")
    p4.statusText = p4Status

    local cbAlto = CreateCheckbox(p4, "Sync alts, professions & gold from Altoholic / DataStore",
        function() return WOWEngineDB.syncAltoholic end,
        function(v)
            WOWEngineDB.syncAltoholic = v
            if v then NS.Roster:ScanAll(true) end
        end)
    cbAlto:SetPoint("TOPLEFT", 14, -90)
    p4.cbAlto = cbAlto

    local cbMC = CreateCheckbox(p4, "Protect reagents queued in Mastercraft from being mailed",
        function() return WOWEngineDB.protectMastercraftQueue end,
        function(v) WOWEngineDB.protectMastercraftQueue = v end)
    cbMC:SetPoint("TOPLEFT", cbAlto, "BOTTOMLEFT", 0, -5)
    p4.cbMC = cbMC

    local cbAuc = CreateCheckbox(p4, "Protect items flagged by Auctionator holds",
        function() return WOWEngineDB.protectAuctionatorPosted end,
        function(v) WOWEngineDB.protectAuctionatorPosted = v end)
    cbAuc:SetPoint("TOPLEFT", cbMC, "BOTTOMLEFT", 0, -5)
    p4.cbAuc = cbAuc

    local cbKeepOwn = CreateCheckbox(p4, "Keep mats on this character if it is assigned to that category",
        function() return WOWEngineDB.keepOwnCategoryMats end,
        function(v) WOWEngineDB.keepOwnCategoryMats = v end)
    cbKeepOwn:SetPoint("TOPLEFT", cbAuc, "BOTTOMLEFT", 0, -5)
    p4.cbKeepOwn = cbKeepOwn

    local p4SyncBtn = CreateActionButton(p4, 195, 24, "Sync Altoholic & Re-Check", function()
        local added = NS.Roster:ScanAltoholic()
        NS.Roster:AutoMapVerifiedRoutes(false)
        NS:Print("Altoholic/DataStore sync complete (" .. tostring(added) .. " new alts imported).")
        OB:RefreshCurrentStep()
    end)
    p4SyncBtn:SetPoint("TOPLEFT", cbKeepOwn, "BOTTOMLEFT", 0, -12)

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

    local bNextAlt = CreateActionButton(p5, 222, 26, "2. Cycle Next Waiting Alt", function()
        NS.MailRouter:CycleNextTarget()
    end)
    bNextAlt:SetPoint("LEFT", bStage, "RIGHT", 14, 0)

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
            NS.BugReporter:Show()
        else
            SlashCmdList["WOWENGINEHELP"]("diag")
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
        local bankList = NS.Roster:GetCategoryTargets("BankAlt")
        local bankStr = (#bankList > 0) and table.concat(bankList, ", ") or "|cffff9900Not set yet|r"
        local activeMod = (faction == "Horde" and NS.Modules["HordeEngine"]) and "HordeEngine (Active)"
            or ((faction == "Alliance" and NS.Modules["AllianceEngine"]) and "AllianceEngine (Active)" or "Core WOWEngine")
        p2.info:SetText(string.format(
            "Registered BankAlt(s): |cff00ff00%s|r\nFaction Module: |cff00aeff%s|r\nBrand Handle: |cffffd100%s|r (Integrated across Core + Faction Modules)",
            bankStr, activeMod, WOWEngineDB.brandHandle or "Illusorybias"
        ))

    elseif OB.currentStep == 3 then
        local p3 = OB.stepPanels[3]
        for _, cat in ipairs(NS.CATEGORIES) do
            local targets = NS.Roster:GetCategoryTargets(cat.key)
            local btn = p3.rows[cat.key]
            if btn then
                if #targets == 1 then
                    local name = targets[1]
                    if C.IsCurrentPlayer(name) then
                        btn:SetText("|cff00aeff" .. name .. " (You)|r")
                    else
                        btn:SetText("|cff00ff00" .. name .. "|r")
                    end
                elseif #targets > 1 then
                    btn:SetText(string.format("|cff00ff00%s|r |cffffd100(+%d more)|r", targets[1], #targets - 1))
                else
                    btn:SetText("|cffaaaaaaUnassigned (Click to Select)|r")
                end
            end
        end
        local customCount = #NS:GetCustomRules()
        p3.customBtn:SetText(string.format("Custom Additions (%d)...", customCount))

    elseif OB.currentStep == 4 then
        local p4 = OB.stepPanels[4]
        local alto = C.IsAltoholicAvailable() and "|cff00ff00Connected|r" or "|cffaaaaaaNot Loaded|r"
        local mc = C.IsMastercraftAvailable() and "|cff00ff00Connected|r" or "|cffaaaaaaNot Loaded|r"
        local auc = C.IsAuctionatorAvailable() and "|cff00ff00Connected|r" or "|cffaaaaaaNot Loaded|r"
        p4.statusText:SetText(string.format(
            "Altoholic / DataStore: %s   |   Mastercraft: %s   |   Auctionator: %s\n\nSelf-mailing is permanently blocked. All mail staging requires 1 click per batch (Blizzard TOS compliant).",
            alto, mc, auc
        ))
        p4.cbAlto:Refresh()
        p4.cbMC:Refresh()
        p4.cbAuc:Refresh()
        p4.cbKeepOwn:Refresh()
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
