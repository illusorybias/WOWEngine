local addonName, NS = ...
local C = NS.Compat

local function SafeOpenOnboarding(mode, stepNum)
    if not (NS.Onboarding and NS.Onboarding.Show) then
        NS:Print("|cffff4444Setup Wizard module is not loaded.|r Ensure all files in WOWEngine/ were extracted cleanly.")
        return
    end
    local ok, err = pcall(function()
        if mode == "toggle" then
            NS.Onboarding:Toggle()
        else
            NS.Onboarding:Show(stepNum or 1)
        end
    end)
    if not ok then
        if NS.RecordError then NS:RecordError("SetupWizard", err) end
        NS:Print("|cffff4444Setup Wizard error:|r " .. tostring(err))
    end
end

local function PrintHelp()
    NS:Print("=== WOWEngine v" .. NS.Version .. " (IllusoryBias) Command Reference ===")
    NS:Print("|cffffd100/he|r or |cffffd100/he setup|r (also |cffffd100/we|r, |cffffd100/wowengine|r) - Open 5-step Onboarding Wizard")
    NS:Print("|cffffd100/he scan|r / |cffffd100/he roster|r - Scan current char, Altoholic/DataStore, guild & friends")
    NS:Print("|cffffd100/he rules|r - View active multi-alt mail routing rules")
    NS:Print("|cffffd100/he addrule <Category> <AltName>|r - Add verified alt to a category (supports multiple alts!)")
    NS:Print("|cffffd100/he delrule <Category> <AltName>|r - Remove an alt from a category")
    NS:Print("|cffffd100/he setbank|r - Add current character as a verified BankAlt")
    NS:Print("|cffffd100/he mode|r - Toggle Multi-Alt Mode (Round-Robin Split vs Priority)")
    NS:Print("|cffffd100/he name|r - Generate IllusoryBias derivative name for current class/profs")
    NS:Print("|cffffd100/hordeship|r [AltName | next] - Stage up to 12 items (bundles all mats for same alt; blocks self-mail)")
    NS:Print("|cffffd100/hordeship bank|r / |cffffd100bags|r - Sort bank or bag containers")
    NS:Print("|cffffd100/hordebank|r - Display cross-character gold ledger")
    NS:Print("|cffffd100/he minimap|r - Toggle minimap button visibility")
    NS:Print("|cffffd100/he diag|r - Print live client, Altoholic & Mastercraft diagnostic check")
    NS:Print("|cffffd100/he bugreport|r - Open copy-pasteable Error Report for GitHub Triage Agent")
end

-- Slash Commands: Shipment & Sorting
SLASH_WOWENGINESHIP1 = "/hordeship"
SLASH_WOWENGINESHIP2 = "/allianceship"
SLASH_WOWENGINESHIP3 = "/wowship"
SlashCmdList["WOWENGINESHIP"] = function(msg)
    local ok, err = pcall(function()
        local cmd = C.Trim(msg)
        local lower = string.lower(cmd)
        if lower == "bank" then
            NS.BankSorter:RunSort("bank")
        elseif lower == "bags" or lower == "sort" then
            NS.BankSorter:RunSort("bags")
        elseif lower == "next" then
            NS.MailRouter:CycleNextTarget()
        elseif cmd ~= "" then
            NS.MailRouter:StageNextBatch(cmd)
        else
            NS.MailRouter:StageNextBatch(nil)
        end
    end)
    if not ok then
        if NS.RecordError then NS:RecordError("/hordeship", err) end
        NS:Print("|cffff4444Error in /hordeship:|r " .. tostring(err))
    end
end

-- Slash Commands: Wealth Ledger
SLASH_WOWENGINEBANK1 = "/hordebank"
SLASH_WOWENGINEBANK2 = "/alliancebank"
SLASH_WOWENGINEBANK3 = "/wowbank"
SlashCmdList["WOWENGINEBANK"] = function()
    local ok, err = pcall(function()
        NS.BankSorter:PrintGoldLedger()
    end)
    if not ok then
        NS:Print("|cffff4444Error in /hordebank:|r " .. tostring(err))
    end
end

-- Slash Commands: Main Hub (/he, /we, /wowengine, /hordeengine, /allianceengine)
SLASH_WOWENGINEHELP1 = "/he"
SLASH_WOWENGINEHELP2 = "/we"
SLASH_WOWENGINEHELP3 = "/wowengine"
SLASH_WOWENGINEHELP4 = "/hordeengine"
SLASH_WOWENGINEHELP5 = "/allianceengine"
SlashCmdList["WOWENGINEHELP"] = function(msg)
    local ok, err = pcall(function()
        local raw = C.Trim(msg)
        local cmd, rest = string.match(raw, "^(%S+)%s*(.*)$")
        cmd = string.lower(cmd or "")

        if cmd == "setup" or cmd == "wizard" or cmd == "onboard" or cmd == "ui" or cmd == "" then
            SafeOpenOnboarding("show", 1)
        elseif cmd == "help" or cmd == "?" then
            PrintHelp()
        elseif cmd == "scan" or cmd == "roster" then
            NS.Roster:ScanAll(false)
        elseif cmd == "rules" then
            NS.Roster:ScanAll(true)
            local rules = NS:GetActiveRules()
            NS:Print("=== Active Multi-Alt Mail Routes (Mode: " .. tostring(WOWEngineDB.multiAltMode) .. ") ===")
            local count = 0
            for _, cat in ipairs(NS.CATEGORIES) do
                local t = rules[cat.key]
                if type(t) == "table" and #t > 0 then
                    count = count + 1
                    NS:Print("  [" .. cat.key .. "] -> |cff00ff00" .. table.concat(t, ", ") .. "|r")
                end
            end
            if count == 0 then
                NS:Print("  No verified routes mapped yet. Open |cffffd100/he setup|r -> Step 3.")
            end
        elseif cmd == "setbank" then
            NS.Roster:ScanCurrentPlayer()
            local exact = C.GetPlayerName()
            if exact then
                NS.Roster:AddTargetToCategory("BankAlt", exact, true)
                NS:Print("Added verified BankAlt: |cff00ff00" .. exact .. "|r")
            end
        elseif cmd == "name" then
            local _, classToken = UnitClass("player")
            local profs = C.GetPlayerProfessions()
            local plist = {}
            for p in pairs(profs) do table.insert(plist, p) end
            NS:Print("IllusoryBias Derivative Name: |cffffd100" .. NS:SuggestDerivativeName(classToken, plist[1], plist[2]) .. "|r")
        elseif cmd == "addrule" or cmd == "setrule" then
            local cat, alt = string.match(rest or "", "^(%S+)%s+(.+)$")
            if cat and alt then
                NS.Roster:ScanAll(true)
                local added, res = NS.Roster:AddTargetToCategory(cat, alt, true)
                if added then
                    NS:Print("Added verified route: [" .. cat .. "] += |cff00ff00" .. res .. "|r")
                else
                    NS:Print("|cffff4444Rejected:|r '" .. alt .. "' is not in your verified character roster. Open |cffffd100/he setup|r.")
                end
            else
                NS:Print("Usage: |cffffd100/he addrule Cloth ExactAltName|r")
            end
        elseif cmd == "delrule" then
            local cat, alt = string.match(rest or "", "^(%S+)%s+(.+)$")
            if cat and alt then
                if NS.Roster:RemoveTargetFromCategory(cat, alt, true) then
                    NS:Print("Removed [" .. alt .. "] from [" .. cat .. "].")
                else
                    NS:Print("'" .. alt .. "' was not assigned to [" .. cat .. "].")
                end
            else
                NS:Print("Usage: |cffffd100/he delrule Cloth ExactAltName|r")
            end
        elseif cmd == "testcustom" then
            NS.MailRouter:DiagnoseCustomMatches()
        elseif cmd == "custom" then
            if NS.Onboarding and NS.Onboarding.OpenCustomAdditionsPopup then
                NS.Onboarding:OpenCustomAdditionsPopup()
            end
        elseif cmd == "mode" then
            if WOWEngineDB.multiAltMode == "roundrobin" then
                WOWEngineDB.multiAltMode = "priority"
            else
                WOWEngineDB.multiAltMode = "roundrobin"
            end
            NS:Print("Multi-Alt Distribution Mode set to: |cffffd100" .. WOWEngineDB.multiAltMode .. "|r")
        elseif cmd == "ship" then
            NS.MailRouter:StageNextBatch(C.Trim(rest))
        elseif cmd == "bank" then
            NS.BankSorter:RunSort("bank")
        elseif cmd == "bags" or cmd == "sort" then
            NS.BankSorter:RunSort("bags")
        elseif cmd == "gold" or cmd == "ledger" then
            NS.BankSorter:PrintGoldLedger()
        elseif cmd == "minimap" then
            WOWEngineDB.minimapHide = not WOWEngineDB.minimapHide
            if not _G.WOWEngineMinimapButton then
                NS:InitMinimapButton()
            end
            if _G.WOWEngineMinimapButton then
                if WOWEngineDB.minimapHide then
                    _G.WOWEngineMinimapButton:Hide()
                    NS:Print("Minimap button hidden. Type |cffffd100/he minimap|r to restore.")
                else
                    _G.WOWEngineMinimapButton:Show()
                    NS:Print("Minimap button shown.")
                end
            end
        elseif cmd == "bugreport" or cmd == "bug" or cmd == "report" then
            if NS.BugReporter and NS.BugReporter.Show then
                NS.BugReporter:Show()
            end
        elseif cmd == "diag" then
            local ver, build, _, iface = GetBuildInfo()
            local realm, faction = NS:GetContextKeys()
            NS:Print("=== WOWEngine v" .. NS.Version .. " Diagnostic ===")
            NS:Print("Client: " .. tostring(ver) .. " (" .. tostring(build) .. ") | Interface: " .. tostring(iface))
            NS:Print("Context: " .. realm .. " (" .. faction .. ") | Verified Alts: " .. tostring(NS.Roster:GetVerifiedCount()) .. " | Mode: " .. tostring(WOWEngineDB.multiAltMode))
            NS:Print("KeepOwnMats: " .. tostring(WOWEngineDB.keepOwnCategoryMats) .. " | Onboarding: " .. tostring(NS.Onboarding ~= nil))
            NS:Print("Bridges -> Altoholic: " .. tostring(C.IsAltoholicAvailable()) .. " | Mastercraft: " .. tostring(C.IsMastercraftAvailable()) .. " | Auctionator: " .. tostring(C.IsAuctionatorAvailable()))
            NS:Print("MinimapButton: " .. tostring(_G.WOWEngineMinimapButton ~= nil) .. " (Shown: " .. tostring(_G.WOWEngineMinimapButton and _G.WOWEngineMinimapButton:IsShown()) .. ")")
        else
            NS:Print("|cffff9900Unknown /he command:|r '" .. cmd .. "'. Available commands:")
            PrintHelp()
        end
    end)
    if not ok then
        if NS.RecordError then NS:RecordError("/he", err) end
        NS:Print("|cffff4444Error in /he command:|r " .. tostring(err))
    end
end

-- Mailbox UI Buttons: Strictly parented to SendMailFrame (NEVER shown on Inbox Tab 1)
local function EnsureMailButtons()
    if not SendMailFrame then return end

    local btn = _G.WOWEngineMailButton
    if not btn then
        btn = CreateFrame("Button", "WOWEngineMailButton", SendMailFrame, "UIPanelButtonTemplate")
        btn:SetSize(112, 24)
        btn:SetFrameStrata("HIGH")
        btn:SetText("Stage Shipment")
        btn:SetScript("OnClick", function()
            local ok, err = pcall(function()
                NS.MailRouter:StageNextBatch(nil)
            end)
            if not ok then
                NS:Print("|cffff4444Stage Shipment error:|r " .. tostring(err))
            end
        end)
    end
    btn:ClearAllPoints()
    if MailFrameTab2 then
        btn:SetPoint("LEFT", MailFrameTab2, "RIGHT", 8, 2)
    else
        btn:SetPoint("BOTTOMRIGHT", SendMailFrame, "BOTTOMRIGHT", -10, -28)
    end

    local nextBtn = _G.WOWEngineMailNextAltButton
    if not nextBtn then
        nextBtn = CreateFrame("Button", "WOWEngineMailNextAltButton", SendMailFrame, "UIPanelButtonTemplate")
        nextBtn:SetSize(64, 24)
        nextBtn:SetFrameStrata("HIGH")
        nextBtn:SetText("Next Alt")
        nextBtn:SetScript("OnClick", function()
            local ok, err = pcall(function()
                NS.MailRouter:CycleNextTarget()
            end)
            if not ok then
                NS:Print("|cffff4444Next Alt error:|r " .. tostring(err))
            end
        end)
    end
    nextBtn:ClearAllPoints()
    nextBtn:SetPoint("LEFT", btn, "RIGHT", 4, 0)

    local setupBtn = _G.WOWEngineMailSetupButton
    if not setupBtn then
        setupBtn = CreateFrame("Button", "WOWEngineMailSetupButton", SendMailFrame, "UIPanelButtonTemplate")
        setupBtn:SetSize(52, 24)
        setupBtn:SetFrameStrata("HIGH")
        setupBtn:SetText("Setup")
        setupBtn:SetScript("OnClick", function()
            SafeOpenOnboarding("show", 3)
        end)
    end
    setupBtn:ClearAllPoints()
    setupBtn:SetPoint("LEFT", nextBtn, "RIGHT", 4, 0)
end

local btnHook = CreateFrame("Frame")
btnHook:RegisterEvent("MAIL_SHOW")
btnHook:SetScript("OnEvent", function()
    EnsureMailButtons()
end)

-- Native WoW Forever / Mainline 12.x Minimap Addon Compartment callback
function _G.WOWEngine_OnAddonCompartmentClick(addon, buttonName)
    if buttonName == "RightButton" then
        if NS.MailRouter.isMailboxOpen or (MailFrame and MailFrame:IsShown()) then
            NS.MailRouter:StageNextBatch(nil)
        elseif NS.BankSorter.isBankOpen or (BankFrame and BankFrame:IsShown()) then
            NS.BankSorter:RunSort("bank")
        else
            NS.BankSorter:RunSort("bags")
        end
    else
        SafeOpenOnboarding("toggle")
    end
end

-- Draggable Minimap Button (Left-Click: Setup Popup, Right-Click: Stage/Sort)
function NS:InitMinimapButton()
    if not Minimap then return end
    local mm = _G.WOWEngineMinimapButton
    if not mm then
        mm = CreateFrame("Button", "WOWEngineMinimapButton", Minimap)
        mm:SetSize(32, 32)
        mm:SetFrameStrata("HIGH")
        mm:SetFrameLevel(20)
        mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

        local bg = mm:CreateTexture(nil, "BACKGROUND")
        bg:SetSize(22, 22)
        bg:SetTexture(133633)
        bg:SetPoint("CENTER", 0, 0)
        if bg.SetMask then
            bg:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        end

        local border = mm:CreateTexture(nil, "OVERLAY")
        border:SetSize(54, 54)
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetPoint("TOPLEFT", 0, 0)

        local function UpdatePosition()
            local angle = math.rad((WOWEngineDB and WOWEngineDB.minimapAngle) or 215)
            local w = Minimap:GetWidth() or 140
            local radius = (w / 2) + 8
            local x = math.cos(angle) * radius
            local y = math.sin(angle) * radius
            mm:ClearAllPoints()
            mm:SetPoint("CENTER", Minimap, "CENTER", x, y)
        end

        mm.UpdatePosition = UpdatePosition
        mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        mm:RegisterForDrag("LeftButton")

        mm:SetScript("OnDragStart", function(self)
            self:SetScript("OnUpdate", function()
                local mx, my = Minimap:GetCenter()
                local cx, cy = GetCursorPosition()
                local scale = Minimap:GetEffectiveScale()
                cx, cy = cx / scale, cy / scale
                WOWEngineDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
                UpdatePosition()
            end)
        end)
        mm:SetScript("OnDragStop", function(self)
            self:SetScript("OnUpdate", nil)
        end)

        mm:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                SafeOpenOnboarding("toggle")
            elseif button == "RightButton" then
                local ok, err = pcall(function()
                    if NS.MailRouter.isMailboxOpen or (MailFrame and MailFrame:IsShown()) then
                        NS.MailRouter:StageNextBatch(nil)
                    elseif NS.BankSorter.isBankOpen or (BankFrame and BankFrame:IsShown()) then
                        NS.BankSorter:RunSort("bank")
                    else
                        NS.BankSorter:RunSort("bags")
                    end
                end)
                if not ok then
                    NS:Print("|cffff4444Minimap action error:|r " .. tostring(err))
                end
            end
        end)

        mm:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("|cff00aeffWOWEngine v" .. NS.Version .. "|r (IllusoryBias)")
            GameTooltip:AddLine("|cffffffffLeft-Click:|r Open Setup & Onboarding Wizard", 0.85, 0.85, 0.85)
            GameTooltip:AddLine("|cffffffffRight-Click:|r Stage Mail (at Mailbox) / Sort Bank or Bags", 0.85, 0.85, 0.85)
            GameTooltip:AddLine("|cffffffffDrag:|r Reposition around Minimap", 0.65, 0.65, 0.65)
            GameTooltip:Show()
        end)
        mm:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    mm.UpdatePosition()
    if WOWEngineDB and WOWEngineDB.minimapHide then
        mm:Hide()
    else
        mm:Show()
    end
end
