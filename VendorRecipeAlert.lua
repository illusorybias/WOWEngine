local addonName, NS = ...
NS.VendorRecipeAlert = {}
local VRA = NS.VendorRecipeAlert
local C = NS.Compat

VRA.frame = nil
VRA.npcCooldowns = {}
VRA.mutedNPCs = {}
VRA.COOLDOWN_SECONDS = 120
VRA.currentVendor = nil

-- Curated Classic / WoW Forever Vendor Recipe Catalog keyed by NPC ID
-- Triggers on mouseover & target BEFORE opening the merchant window
-- (Live MERCHANT_SHOW scanning also catches ANY vendor & custom WoW Forever vendors automatically)
VRA.VENDOR_RECIPES = {
    -- First Aid Manuals
    [12941] = {
        name = "Deneb Walker", zone = "Arathi Highlands", x = 27.0, y = 58.8, faction = "Alliance",
        recipes = {
            { name = "Expert First Aid - Under Wraps", prof = "First Aid" },
            { name = "Manual: Heavy Silk Bandage",     prof = "First Aid" },
            { name = "Manual: Mageweave Bandage",      prof = "First Aid" },
        },
    },
    [12956] = {
        name = "Balai Lok'Wein", zone = "Dustwallow Marsh", x = 36.4, y = 30.4, faction = "Horde",
        recipes = {
            { name = "Expert First Aid - Under Wraps", prof = "First Aid" },
            { name = "Manual: Heavy Silk Bandage",     prof = "First Aid" },
            { name = "Manual: Mageweave Bandage",      prof = "First Aid" },
        },
    },
    -- Tailoring Vendors
    [3364] = {
        name = "Borya", zone = "Orgrimmar", x = 63.0, y = 51.2, faction = "Horde",
        recipes = {
            { name = "Pattern: Red Woolen Bag",     prof = "Tailoring" },
            { name = "Pattern: Heavy Woolen Cloak", prof = "Tailoring" },
            { name = "Pattern: Azure Silk Cloak",   prof = "Tailoring" },
        },
    },
    [1318] = {
        name = "Elynna", zone = "Darnassus", x = 64.4, y = 21.6, faction = "Alliance",
        recipes = {
            { name = "Pattern: Green Silk Armor",   prof = "Tailoring" },
            { name = "Pattern: Azure Silk Pants",   prof = "Tailoring" },
        },
    },
    [8681] = {
        name = "Outfitter Eric", zone = "Ironforge", x = 43.2, y = 29.2, faction = "Alliance",
        recipes = {
            { name = "Pattern: Tuxedo Shirt",       prof = "Tailoring" },
            { name = "Pattern: Tuxedo Pants",       prof = "Tailoring" },
            { name = "Pattern: Tuxedo Jacket",      prof = "Tailoring" },
        },
    },
    [11189] = {
        name = "Qia", zone = "Winterspring", x = 61.2, y = 37.2, faction = "Neutral",
        recipes = {
            { name = "Pattern: Runecloth Bag",      prof = "Tailoring" },
            { name = "Pattern: Runecloth Gloves",   prof = "Tailoring" },
        },
    },
    -- Alchemy Vendors
    [3346] = {
        name = "Kulwia", zone = "Stonetalon Mountains", x = 45.4, y = 59.4, faction = "Horde",
        recipes = {
            { name = "Recipe: Shadow Oil",          prof = "Alchemy" },
            { name = "Recipe: Great Rage Potion",   prof = "Alchemy" },
        },
    },
    [4610] = {
        name = "Algernon", zone = "Undercity", x = 51.6, y = 74.6, faction = "Horde",
        recipes = {
            { name = "Recipe: Elixir of Shadow Power", prof = "Alchemy" },
            { name = "Recipe: Shadow Protection Potion", prof = "Alchemy" },
        },
    },
    [5178] = {
        name = "Soolie Berryfizz", zone = "Ironforge", x = 66.6, y = 55.2, faction = "Alliance",
        recipes = {
            { name = "Recipe: Free Action Potion",  prof = "Alchemy" },
            { name = "Recipe: Rage Potion",         prof = "Alchemy" },
        },
    },
    [4229] = {
        name = "Dalria", zone = "Ashenvale", x = 35.0, y = 52.0, faction = "Alliance",
        recipes = {
            { name = "Recipe: Shadow Oil",          prof = "Alchemy" },
            { name = "Recipe: Great Rage Potion",   prof = "Alchemy" },
        },
    },
    -- Engineering Vendors
    [3413] = {
        name = "Sovik", zone = "Orgrimmar", x = 75.6, y = 25.2, faction = "Horde",
        recipes = {
            { name = "Schematic: Deadly Scope",     prof = "Engineering" },
            { name = "Schematic: Mithril Tube",     prof = "Engineering" },
        },
    },
    [5175] = {
        name = "Gearcutter Cogspinner", zone = "Ironforge", x = 67.8, y = 43.2, faction = "Alliance",
        recipes = {
            { name = "Schematic: Gnomish Universal Remote", prof = "Engineering" },
            { name = "Schematic: Bright-Eye Goggles",       prof = "Engineering" },
        },
    },
    [3537] = {
        name = "Zixil", zone = "Hillsbrad Foothills", x = 53.0, y = 56.0, faction = "Neutral",
        recipes = {
            { name = "Schematic: EZ-Thro Dynamite", prof = "Engineering" },
            { name = "Pattern: Shadowskin Gloves",  prof = "Leatherworking" },
        },
    },
    -- Enchanting Vendors
    [4228] = {
        name = "Mythrin'dir", zone = "Darnassus", x = 61.0, y = 17.6, faction = "Alliance",
        recipes = {
            { name = "Formula: Enchant Bracer - Lesser Strength", prof = "Enchanting" },
            { name = "Formula: Enchant Shield - Lesser Stamina",  prof = "Enchanting" },
        },
    },
    [12022] = {
        name = "Lorelae Wintersong", zone = "Moonglade", x = 48.6, y = 40.2, faction = "Neutral",
        recipes = {
            { name = "Formula: Enchant Cloak - Superior Defense", prof = "Enchanting" },
            { name = "Pattern: Felcloth Robe",                    prof = "Tailoring" },
        },
    },
    [15419] = {
        name = "Kania", zone = "Silithus", x = 52.0, y = 39.6, faction = "Neutral",
        recipes = {
            { name = "Formula: Enchant Chest - Major Mana",       prof = "Enchanting" },
        },
    },
    -- Leatherworking Vendors
    [3550] = {
        name = "George Candarte", zone = "Hillsbrad Foothills", x = 61.6, y = 19.2, faction = "Horde",
        recipes = {
            { name = "Pattern: Hillman's Belt",     prof = "Leatherworking" },
            { name = "Pattern: Dark Leather Shoulders", prof = "Leatherworking" },
        },
    },
    [2819] = {
        name = "Harklan Moongrove", zone = "Ashenvale", x = 50.8, y = 67.0, faction = "Alliance",
        recipes = {
            { name = "Pattern: Fine Leather Gloves",prof = "Leatherworking" },
            { name = "Pattern: Herbalist's Gloves", prof = "Leatherworking" },
        },
    },
    [12958] = {
        name = "Nergal", zone = "Un'Goro Crater", x = 43.2, y = 7.8, faction = "Neutral",
        recipes = {
            { name = "Pattern: Devilsaur Gauntlets",prof = "Leatherworking" },
            { name = "Pattern: Devilsaur Leggings", prof = "Leatherworking" },
        },
    },
    -- Blacksmithing Vendors
    [12943] = {
        name = "Jase Farlane", zone = "Eastern Plaguelands", x = 74.8, y = 51.8, faction = "Neutral",
        recipes = {
            { name = "Plans: Thorium Boots",        prof = "Blacksmithing" },
            { name = "Plans: Thorium Helm",         prof = "Blacksmithing" },
        },
    },
    [1685] = {
        name = "Xandar Goodbeard", zone = "Loch Modan", x = 82.6, y = 63.0, faction = "Alliance",
        recipes = {
            { name = "Plans: Iron Shield Spike",    prof = "Blacksmithing" },
            { name = "Plans: Solid Iron Maul",      prof = "Blacksmithing" },
        },
    },
    -- Cooking & Fishing Vendors
    [4617] = {
        name = "Ronald Burch", zone = "Undercity", x = 62.4, y = 43.2, faction = "Horde",
        recipes = {
            { name = "Recipe: Crispy Bat Wing",     prof = "Cooking" },
            { name = "Recipe: Lean Wolf Steak",     prof = "Cooking" },
        },
    },
    [3027] = {
        name = "Wulan", zone = "Desolace", x = 26.2, y = 69.8, faction = "Horde",
        recipes = {
            { name = "Recipe: Mithril Head Trout",  prof = "Cooking" },
            { name = "Recipe: Rockscale Cod",       prof = "Cooking" },
        },
    },
    [3029] = {
        name = "Naal Mistrunner", zone = "Thunder Bluff", x = 51.0, y = 52.2, faction = "Horde",
        recipes = {
            { name = "Recipe: Spiced Wolf Meat",    prof = "Cooking" },
            { name = "Recipe: Longjaw Mud Snapper", prof = "Cooking" },
        },
    },
    [2626] = {
        name = "Old Man Heming", zone = "Stranglethorn", x = 27.4, y = 77.0, faction = "Neutral",
        recipes = {
            { name = "Expert Fishing - The Bass and You", prof = "Fishing" },
        },
    },
}

local RECIPE_PREFIXES = {
    "pattern:", "plans:", "schematic:", "formula:", "recipe:", "manual:",
    "design:", "technique:", "expert first aid", "expert fishing", "expert cookbook",
}

local KNOWN_PROFS_LOWER = {
    ["herbalism"] = "Herbalism",
    ["alchemy"] = "Alchemy",
    ["enchanting"] = "Enchanting",
    ["mining"] = "Mining",
    ["blacksmithing"] = "Blacksmithing",
    ["engineering"] = "Engineering",
    ["jewelcrafting"] = "Jewelcrafting",
    ["leatherworking"] = "Leatherworking",
    ["skinning"] = "Skinning",
    ["tailoring"] = "Tailoring",
    ["inscription"] = "Inscription",
    ["cooking"] = "Cooking",
    ["fishing"] = "Fishing",
    ["first aid"] = "First Aid",
}

local function ApplyAlertBackdrop(f)
    if not f then return end
    if f.SetBackdrop then
        local ok = pcall(function()
            f:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 14,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            f:SetBackdropColor(0.04, 0.09, 0.19, 0.97)
            f:SetBackdropBorderColor(0.95, 0.78, 0.18, 1.0)
        end)
        if ok then return end
    end
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    if bg.SetColorTexture then
        bg:SetColorTexture(0.04, 0.09, 0.19, 0.97)
    else
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        bg:SetVertexColor(0.04, 0.09, 0.19, 0.97)
    end
end

local function NormalizeRecipeKey(name)
    if not name or C.IsSecret(name) then return nil, nil end
    local clean = string.lower(C.Trim(tostring(name)))
    if clean == "" then return nil, nil end
    local stripped = string.gsub(clean, "^[a-z]+:%s*", "")
    return clean, stripped
end

local function GetCharLearnedTable()
    if NS and NS.EnsureDB then NS:EnsureDB() end
    WOWEngineDB = WOWEngineDB or {}
    WOWEngineDB.learnedRecipesByChar = WOWEngineDB.learnedRecipesByChar or {}
    local cKey = C.CanonicalCharKey(C.GetPlayerName() or "Player") or "player"
    WOWEngineDB.learnedRecipesByChar[cKey] = WOWEngineDB.learnedRecipesByChar[cKey] or {}
    return WOWEngineDB.learnedRecipesByChar[cKey]
end

local function GetPlayerAllProfessions()
    local all = {}
    local prim = (C and C.GetPlayerProfessions) and C.GetPlayerProfessions() or {}
    local subs = (C and C.GetPlayerSubProfessions) and C.GetPlayerSubProfessions() or {}
    for k, v in pairs(prim) do all[k] = tonumber(v) or 1 end
    for k, v in pairs(subs) do all[k] = tonumber(v) or 1 end
    return all
end

local function IsRecipeLearned(recipeName)
    local fullKey, strippedKey = NormalizeRecipeKey(recipeName)
    if not fullKey then return false end
    local tbl = GetCharLearnedTable()
    if tbl[fullKey] or (strippedKey and tbl[strippedKey]) then
        return true
    end
    return false
end

local function RecordLearnedRecipeName(recipeName)
    local fullKey, strippedKey = NormalizeRecipeKey(recipeName)
    if not fullKey then return end
    local tbl = GetCharLearnedTable()
    tbl[fullKey] = true
    if strippedKey and strippedKey ~= "" then
        tbl[strippedKey] = true
    end
end

-- Scan currently open TradeSkill / Craft window to persist learned recipes per character
function VRA:ScanOpenTradeSkill()
    -- 1. Modern C_TradeSkillUI (Retail / Mainline 12.x / WoW Forever)
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeInfo then
        local okIds, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
        if okIds and type(ids) == "table" and #ids > 0 then
            for _, rid in ipairs(ids) do
                local okInfo, info = pcall(C_TradeSkillUI.GetRecipeInfo, rid)
                if okInfo and type(info) == "table" and info.learned and info.name then
                    RecordLearnedRecipeName(info.name)
                end
            end
        end
    end

    -- 2. Classic TradeSkill API
    if GetNumTradeSkills and GetTradeSkillInfo then
        local okN, num = pcall(GetNumTradeSkills)
        if okN and type(num) == "number" and num > 0 then
            for i = 1, num do
                local okI, skillName, skillType = pcall(GetTradeSkillInfo, i)
                if okI and skillName and skillType ~= "header" and skillType ~= "subheader" then
                    RecordLearnedRecipeName(skillName)
                end
            end
        end
    end

    -- 3. Classic Craft API (Enchanting, etc.)
    if GetNumCrafts and GetCraftInfo then
        local okN, num = pcall(GetNumCrafts)
        if okN and type(num) == "number" and num > 0 then
            for i = 1, num do
                local okI, craftName, _, craftType = pcall(GetCraftInfo, i)
                if okI and craftName and craftType ~= "header" then
                    RecordLearnedRecipeName(craftName)
                end
            end
        end
    end
end

local function ExtractNPCID(unit)
    if not unit or not UnitExists or not UnitExists(unit) then return nil end
    if UnitIsPlayer and UnitIsPlayer(unit) then return nil end
    if UnitIsDead and UnitIsDead(unit) then return nil end
    if not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or not guid or C.IsSecret(guid) or type(guid) ~= "string" then
        return nil
    end
    local npcID = string.match(guid, "Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)")
        or string.match(guid, "Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    return tonumber(npcID)
end

local function IsRecipeItemName(name)
    if not name or C.IsSecret(name) then return false end
    local low = string.lower(C.Trim(tostring(name)))
    for _, prefix in ipairs(RECIPE_PREFIXES) do
        if string.sub(low, 1, #prefix) == prefix then
            return true
        end
    end
    return false
end

local scanTip = nil
local function GetVendorScanTooltip()
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "WOWEngineVendorRecipeScanTip", nil, "GameTooltipTemplate")
        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return scanTip
end

-- Inspect merchant slot tooltip for "Already known" and "Requires <Profession>"
local function InspectMerchantSlotTooltip(slotIdx)
    local alreadyKnown = false
    local reqProf = nil
    local knownConst = ITEM_SPELL_KNOWN and string.lower(ITEM_SPELL_KNOWN) or "already known"

    local function checkLine(rawText)
        if not rawText or C.IsSecret(rawText) then return end
        local low = string.lower(tostring(rawText))
        if string.find(low, knownConst, 1, true) or string.find(low, "already known", 1, true) then
            alreadyKnown = true
        end
        if not reqProf and string.find(low, "requires ", 1, true) then
            for pLow, pCanon in pairs(KNOWN_PROFS_LOWER) do
                if string.find(low, "requires " .. pLow, 1, true) then
                    reqProf = pCanon
                    break
                end
            end
        end
    end

    if C_TooltipInfo and C_TooltipInfo.GetMerchantItem then
        local ok, tipData = pcall(C_TooltipInfo.GetMerchantItem, slotIdx)
        if ok and type(tipData) == "table" and type(tipData.lines) == "table" then
            for _, line in ipairs(tipData.lines) do
                checkLine(line.leftText)
                checkLine(line.rightText)
            end
            return alreadyKnown, reqProf
        end
    end

    local tip = GetVendorScanTooltip()
    tip:ClearLines()
    local okSet = pcall(tip.SetMerchantItem, tip, slotIdx)
    if okSet then
        for i = 2, tip:NumLines() do
            local left = _G["WOWEngineVendorRecipeScanTipTextLeft" .. i]
            if left then checkLine(left:GetText()) end
        end
    end
    return alreadyKnown, reqProf
end

local function PlaySubtleAlertSound()
    if not PlaySound then return end
    local soundID = (SOUNDKIT and (SOUNDKIT.TELL_MESSAGE or SOUNDKIT.MAP_PING or SOUNDKIT.IG_QUEST_LIST_COMPLETE or SOUNDKIT.READY_CHECK)) or 3081
    pcall(PlaySound, soundID, "Master")
end

local function GetCurrentZoneAndCoords()
    local zoneName = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "Current Zone"
    local mapID, px, py = nil, nil, nil
    if C_Map and C_Map.GetBestMapForUnit then
        local okM, mid = pcall(C_Map.GetBestMapForUnit, "player")
        if okM and mid then
            mapID = mid
            if C_Map.GetMapInfo then
                local okI, info = pcall(C_Map.GetMapInfo, mid)
                if okI and type(info) == "table" and info.name then
                    zoneName = info.name
                end
            end
            if C_Map.GetPlayerMapPosition then
                local okP, pos = pcall(C_Map.GetPlayerMapPosition, mid, "player")
                if okP and pos and pos.GetXY then
                    local x, y = pos:GetXY()
                    if x and y then px, py = x * 100, y * 100 end
                end
            end
        end
    end
    return mapID, px, py, zoneName
end

-- RareScanner-style Blizzard blue-and-gold alert frame (visual guidance only; zero automated purchasing)
function VRA:EnsureAlertFrame()
    if VRA.frame then return VRA.frame end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", "WOWEngineVendorRecipeAlertFrame", UIParent, template)
    f:SetSize(410, 176)
    f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 145)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(150)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    ApplyAlertBackdrop(f)

    if UISpecialFrames then
        table.insert(UISpecialFrames, "WOWEngineVendorRecipeAlertFrame")
    end

    -- Top Banner Bar
    local headerBg = f:CreateTexture(nil, "ARTWORK")
    headerBg:SetPoint("TOPLEFT", 4, -4)
    headerBg:SetPoint("TOPRIGHT", -4, -4)
    headerBg:SetHeight(32)
    if headerBg.SetColorTexture then
        headerBg:SetColorTexture(0.06, 0.17, 0.36, 0.96)
    else
        headerBg:SetTexture("Interface\\Buttons\\WHITE8x8")
        headerBg:SetVertexColor(0.06, 0.17, 0.36, 0.96)
    end

    -- Recipe Scroll Icon Marker
    local icon = f:CreateTexture(nil, "OVERLAY")
    icon:SetSize(22, 22)
    icon:SetPoint("TOPLEFT", 10, -9)
    icon:SetTexture("Interface\\Icons\\INV_Scroll_03")
    f.icon = icon

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", icon, "RIGHT", 6, 4)
    title:SetPoint("RIGHT", f, "RIGHT", -32, 0)
    title:SetJustifyH("LEFT")
    if title.SetWordWrap then title:SetWordWrap(false) end
    f.title = title

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -1)
    sub:SetPoint("RIGHT", f, "RIGHT", -32, 0)
    sub:SetJustifyH("LEFT")
    if sub.SetWordWrap then sub:SetWordWrap(false) end
    f.sub = sub

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -3, -3)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Left Column: 3D PlayerModel Portrait Container
    local modelBox = CreateFrame("Frame", nil, f, template)
    modelBox:SetSize(96, 124)
    modelBox:SetPoint("TOPLEFT", 10, -42)
    if modelBox.SetBackdrop then
        pcall(function()
            modelBox:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            modelBox:SetBackdropColor(0.02, 0.05, 0.12, 0.92)
            modelBox:SetBackdropBorderColor(0.95, 0.78, 0.18, 0.85)
        end)
    end

    local fallbackIcon = modelBox:CreateTexture(nil, "ARTWORK")
    fallbackIcon:SetSize(56, 56)
    fallbackIcon:SetPoint("CENTER", modelBox, "CENTER", 0, 0)
    fallbackIcon:SetTexture("Interface\\Icons\\INV_Scroll_03")
    f.fallbackIcon = fallbackIcon

    local okM, model = pcall(CreateFrame, "PlayerModel", "WOWEngineVendorAlertModel", modelBox)
    if okM and model then
        model:SetPoint("TOPLEFT", 2, -2)
        model:SetPoint("BOTTOMRIGHT", -2, 2)
        f.model = model
    end

    -- Right Column: Scrollable Unlearned Recipes List
    local scroll = CreateFrame("ScrollFrame", "WOWEngineVendorAlertScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", modelBox, "TOPRIGHT", 10, -2)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 38)

    local listChild = CreateFrame("Frame", nil, scroll)
    listChild:SetSize(256, 120)
    scroll:SetScrollChild(listChild)

    local listTxt = listChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    listTxt:SetPoint("TOPLEFT", 2, -2)
    listTxt:SetWidth(250)
    listTxt:SetJustifyH("LEFT")
    f.listChild = listChild
    f.listTxt = listTxt
    f.scroll = scroll

    -- Bottom Action Buttons: "Pin Vendor" + "Mute NPC"
    local pinBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    pinBtn:SetSize(110, 22)
    pinBtn:SetPoint("BOTTOMLEFT", modelBox, "BOTTOMRIGHT", 10, 0)
    pinBtn:SetText("Pin Vendor")
    pinBtn:SetScript("OnClick", function()
        local v = VRA.currentVendor
        if not v then return end
        local pinTitle = string.format("%s (Unlearned Recipes)", v.name or "Vendor")
        if NS.WaveTracker and NS.WaveTracker.PlaceMapPin then
            NS.WaveTracker:PlaceMapPin(v.mapID, v.x, v.y, v.zone, pinTitle, "|cffffd100" .. (v.name or "Vendor") .. "|r (Recipe Vendor)")
        else
            NS:Print(string.format("|cffffd100Recipe Vendor:|r %s (%s, %.1f, %.1f)",
                v.name or "Vendor", v.zone or "Current Zone", v.x or 0, v.y or 0))
        end
    end)
    f.pinBtn = pinBtn

    local muteBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    muteBtn:SetSize(86, 22)
    muteBtn:SetPoint("LEFT", pinBtn, "RIGHT", 6, 0)
    muteBtn:SetText("Mute NPC")
    muteBtn:SetScript("OnClick", function()
        if VRA.currentVendor and VRA.currentVendor.npcID then
            VRA.mutedNPCs[VRA.currentVendor.npcID] = true
            NS:Print("Muted recipe alerts for |cffffd100" .. tostring(VRA.currentVendor.name or "vendor") .. "|r for this session.")
        end
        f:Hide()
    end)
    f.muteBtn = muteBtn

    f:Hide()
    VRA.frame = f
    return f
end

function VRA:ShowAlert(vendorData, unlearnedList, unit)
    if not vendorData or not unlearnedList or #unlearnedList == 0 then return end
    if WOWEngineDB and WOWEngineDB.vendorRecipeAlertEnabled == false then return end

    local f = VRA:EnsureAlertFrame()
    VRA.currentVendor = vendorData

    f.title:SetText("|cff00aeffUnlearned Recipes:|r |cffffd100" .. tostring(vendorData.name or "Vendor") .. "|r")
    local locStr = vendorData.zone or "Current Zone"
    if vendorData.x and vendorData.y then
        locStr = string.format("%s (%.1f, %.1f)", locStr, vendorData.x, vendorData.y)
    end
    f.sub:SetText(string.format("|cff00ff00%d unlearned|r  —  %s", #unlearnedList, locStr))

    -- Render 3D PlayerModel (nil-safe across WoW Forever 16001, Classic, and Retail)
    local modelRendered = false
    if f.model then
        pcall(function()
            if f.model.ClearModel then f.model:ClearModel() end
            if unit and UnitExists and UnitExists(unit) and f.model.SetUnit then
                f.model:SetUnit(unit)
                modelRendered = true
            elseif vendorData.npcID and f.model.SetCreature then
                f.model:SetCreature(vendorData.npcID)
                modelRendered = true
            end
            if modelRendered then
                if f.model.SetPortraitZoom then f.model:SetPortraitZoom(0.6) end
                if f.model.SetFacing then f.model:SetFacing(0.35) end
            end
        end)
    end
    if f.fallbackIcon then
        if modelRendered then f.fallbackIcon:Hide() else f.fallbackIcon:Show() end
    end

    local lines = {}
    for _, rec in ipairs(unlearnedList) do
        local profTag = rec.prof and (" |cff00aeff[" .. rec.prof .. "]|r") or ""
        table.insert(lines, "|cffffd100•|r " .. tostring(rec.name) .. profTag)
    end
    f.listTxt:SetText(table.concat(lines, "\n"))
    local textH = (f.listTxt.GetStringHeight and f.listTxt:GetStringHeight()) or (#lines * 14)
    f.listChild:SetHeight(math.max(96, math.ceil(textH) + 10))
    if f.scroll and f.scroll.UpdateScrollChildRect then
        pcall(f.scroll.UpdateScrollChildRect, f.scroll)
    end

    PlaySubtleAlertSound()
    f:Show()
    f:Raise()
end

-- Scan mouseover or target NPC against curated vendor recipe database
function VRA:CheckUnitVendor(unit)
    if WOWEngineDB and WOWEngineDB.vendorRecipeAlertEnabled == false then return end
    local npcID = ExtractNPCID(unit)
    if not npcID then return end
    if VRA.mutedNPCs[npcID] then return end

    local catalogEntry = VRA.VENDOR_RECIPES[npcID]
    if not catalogEntry or type(catalogEntry.recipes) ~= "table" then return end

    -- Respect faction filter (neutral vendors alert everyone)
    local _, playerFaction = NS:GetContextKeys()
    if catalogEntry.faction and catalogEntry.faction ~= "Neutral" and playerFaction and catalogEntry.faction ~= playerFaction then
        return
    end

    -- Per-NPC cooldown to avoid hover/target spam
    local now = time and time() or 0
    local lastSeen = VRA.npcCooldowns[npcID] or 0
    if (now - lastSeen) < VRA.COOLDOWN_SECONDS then return end

    local playerProfs = GetPlayerAllProfessions()
    local unlearned = {}
    for _, rec in ipairs(catalogEntry.recipes) do
        local hasProf = (not rec.prof) or (playerProfs[rec.prof] ~= nil)
        if hasProf and not IsRecipeLearned(rec.name) then
            table.insert(unlearned, rec)
        end
    end
    if #unlearned == 0 then return end

    VRA.npcCooldowns[npcID] = now
    local liveMapID, liveX, liveY, liveZone = GetCurrentZoneAndCoords()
    local unitName = (UnitName and C.SafeStr(UnitName(unit))) or catalogEntry.name
    VRA:ShowAlert({
        npcID = npcID,
        name = unitName or catalogEntry.name,
        zone = liveZone or catalogEntry.zone,
        mapID = liveMapID,
        x = liveX or catalogEntry.x,
        y = liveY or catalogEntry.y,
    }, unlearned, unit)
end

-- Live scan of open merchant inventory on MERCHANT_SHOW (detects ANY vendor recipe via tooltip "Already known")
function VRA:ScanOpenMerchant()
    if WOWEngineDB and WOWEngineDB.vendorRecipeAlertEnabled == false then return end
    if not GetMerchantNumItems then return end

    local okNum, numItems = pcall(GetMerchantNumItems)
    if not okNum or type(numItems) ~= "number" or numItems <= 0 then return end

    local unit = (UnitExists and UnitExists("npc")) and "npc" or "target"
    local npcID = ExtractNPCID(unit)
    if npcID and VRA.mutedNPCs[npcID] then return end

    local playerProfs = GetPlayerAllProfessions()
    local recipeClassID = (Enum and Enum.ItemClass and Enum.ItemClass.Recipe) or 9
    local unlearned = {}
    local seenNames = {}

    for i = 1, numItems do
        local itemName = nil
        if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
            local okM, info = pcall(C_MerchantFrame.GetItemInfo, i)
            if okM and type(info) == "table" then itemName = info.name end
        elseif GetMerchantItemInfo then
            local okM, n = pcall(GetMerchantItemInfo, i)
            if okM then itemName = n end
        end

        local link = GetMerchantItemLink and select(2, pcall(GetMerchantItemLink, i)) or nil
        if not itemName and link then
            itemName = C.ExtractItemName(link)
        end

        if itemName and not C.IsSecret(itemName) then
            local isRecipe = IsRecipeItemName(itemName)
            if not isRecipe and link then
                local _, instType, _, _, _, classID = C.GetItemInfoInstant(link)
                if classID == recipeClassID or instType == "Recipe" then
                    isRecipe = true
                end
            end

            if isRecipe then
                local alreadyKnown, reqProf = InspectMerchantSlotTooltip(i)
                if alreadyKnown then
                    RecordLearnedRecipeName(itemName)
                elseif not IsRecipeLearned(itemName) then
                    local matchesProf = (not reqProf) or (playerProfs[reqProf] ~= nil)
                    if matchesProf and not seenNames[itemName] then
                        seenNames[itemName] = true
                        table.insert(unlearned, { name = itemName, prof = reqProf })
                    end
                end
            end
        end
    end

    if #unlearned == 0 then return end

    local now = time and time() or 0
    if npcID then VRA.npcCooldowns[npcID] = now end

    local liveMapID, liveX, liveY, liveZone = GetCurrentZoneAndCoords()
    local vendorName = (UnitName and UnitExists and UnitExists(unit) and C.SafeStr(UnitName(unit)))
        or (npcID and VRA.VENDOR_RECIPES[npcID] and VRA.VENDOR_RECIPES[npcID].name)
        or "Merchant"

    VRA:ShowAlert({
        npcID = npcID,
        name = vendorName,
        zone = liveZone,
        mapID = liveMapID,
        x = liveX,
        y = liveY,
    }, unlearned, unit)
end

local vraEvents = CreateFrame("Frame")
pcall(vraEvents.RegisterEvent, vraEvents, "UPDATE_MOUSEOVER_UNIT")
pcall(vraEvents.RegisterEvent, vraEvents, "PLAYER_TARGET_CHANGED")
pcall(vraEvents.RegisterEvent, vraEvents, "MERCHANT_SHOW")
pcall(vraEvents.RegisterEvent, vraEvents, "TRADE_SKILL_SHOW")
pcall(vraEvents.RegisterEvent, vraEvents, "TRADE_SKILL_DATA_SOURCE_READY")
pcall(vraEvents.RegisterEvent, vraEvents, "CRAFT_SHOW")
pcall(vraEvents.RegisterEvent, vraEvents, "NEW_RECIPE_LEARNED")
vraEvents:SetScript("OnEvent", function(self, event)
    local ok, err = pcall(function()
        if event == "UPDATE_MOUSEOVER_UNIT" then
            VRA:CheckUnitVendor("mouseover")
        elseif event == "PLAYER_TARGET_CHANGED" then
            VRA:CheckUnitVendor("target")
        elseif event == "MERCHANT_SHOW" then
            VRA:ScanOpenMerchant()
        else
            VRA:ScanOpenTradeSkill()
        end
    end)
    if not ok and NS and NS.RecordError then
        NS:RecordError("VendorRecipeAlert:" .. tostring(event), err)
    end
end)
