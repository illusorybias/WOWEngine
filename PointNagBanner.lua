local addonName, NS = ...
NS.PointNagBanner = {}
local PNB = NS.PointNagBanner
local C = NS.Compat

PNB.frame = nil
PNB.ticker = nil
PNB.lastRoastIdx = 0
PNB.lastDismissIdx = 0
PNB.NAG_INTERVAL = 600     -- 10 minutes
PNB.SNOOZE_SECONDS = 900   -- 15 minutes
PNB.MUTE_24H_SECONDS = 86400 -- 24 hours

-- 100 unique, clean, WoW-humored sarcastic roasts from a friendly guildie
PNB.ROASTS = {
    "Saving those talent points for World of Warcraft 2, or just hoping Hogger takes pity on you?",
    "Bold strategy leaving points unspent—are we speedrunning a grey parse today?",
    "Even Leeroy Jenkins spent his talent points before running into the whelp room.",
    "Fun fact: unspent talent points do NOT gain interest at the Stormwind Bank.",
    "You have unspent points sitting there like a hunter rolling Need on a healing mace.",
    "Are you hoarding those points for retirement, or did you forget what the 'N' key does?",
    "Your raid leader can sense unspent talent points from two continents away.",
    "Standing in fire AND holding unspent points? Truly a pioneer of Hard Mode.",
    "Mankrik's wife was found faster than you spend your talent points.",
    "Legend says if you save enough unspent points, Barrens chat finally becomes helpful. Spoiler: it won't.",
    "Spending those points is free—unlike the repair bill you're about to rack up.",
    "A level 5 Kobold just offered to take your candle AND your unspent points.",
    "Your DPS meter just filed a missing persons report on your talent tree.",
    "Did you also forget to train your new spell ranks, or is this an intentional self-nerf?",
    "Unspent points don't count as bonus stamina, no matter how hard you believe.",
    "Somewhere in Elwynn Forest, a Defias Pillager is laughing at your unspent talent points.",
    "Even a broken hearthstone works harder than those unspent points right now.",
    "Your guild's healers asked me to tell you that spending points reduces incoming embarrassment.",
    "Press 'N'. I promise the talent tree doesn't bite—unlike the boss you're about to pull.",
    "If hoarding unspent points were a profession, you'd already be 300/300 Artisan.",
    "You're basically fighting with one hand tied behind your back and a fishing pole equipped.",
    "Reminder: talent points expire never, but your party's patience expires in about 30 seconds.",
    "Plot twist: the real raid boss was your unopened talent window all along.",
    "That unspent point has been sitting in your tree longer than a DPS waiting in dungeon queue.",
    "Are you doing an 'Ironman No-Talents Challenge', or did you genuinely forget?",
    "Your gear score says 'hero of Azeroth,' your unspent points say 'just left Northshire Abbey.'",
    "Even Peons say 'Work, work' faster than you click a talent node.",
    "Not spending your points is bold—almost as bold as pulling Aggro before the tank lands a Sunder.",
    "The Spirit Healer wants to thank you personally for keeping her business booming.",
    "News flash: unspent points do not unlock the secret cow level.",
    "You've been holding those points for 10 minutes. Did your mouse run out of mana?",
    "Your spellbook called—it's worried you forgot how buttons work.",
    "Leaving points unspent is like bringing Rank 1 Frostbolt to Molten Core.",
    "At this rate, the Zeppelins will arrive on time before you spend a single point.",
    "Your talent tree looks emptier than the Auction House five minutes before server maintenance.",
    "You know you don't get a refund on unused talent points when you hit level 60, right?",
    "A Murloc just yelled 'Mrglgrgl!' which roughly translates to 'Spend your points, noob!'",
    "Friendly guildie check-in: those shiny points aren't decorative.",
    "If you wait any longer to spend those points, they'll turn grey and stop giving skill-ups.",
    "You're leaving free stats on the table—Auctionator would never approve of this inefficiency.",
    "Just checked Warcraft Logs: turns out unspent talent points don't boost your parse.",
    "You've got more unspent points than a Mage has excuses for not making conjured water.",
    "Stop admiring the unspent point counter and actually click a talent, champion.",
    "Even a Rogue in Stealth can't hide those unspent points from this banner.",
    "Did a Warlock cast Curse of Procrastination on your talent tree?",
    "Spend your points before the tank pulls—oh wait, the Hunter's pet already pulled.",
    "Your unspent points are collecting more dust than a Level 12 Enchanter's bank alt.",
    "Not even a Blessing of Wisdom can fix forgetting to spend your points.",
    "You're playing Classic on Nightmare difficulty purely by ignoring your talent window.",
    "The Flight Master flies faster than you click your talent tree.",
    "Think of it this way: every minute those points sit unspent, a Gnome gets punted.",
    "Your talents are crying in the corner like a Paladin whose bubble just expired.",
    "Are those points Soulbound to your procrastination, or can we spend them today?",
    "Even Thrall and Varian agree on one thing: spend your unspent points already.",
    "You've held onto those points longer than someone refusing to vendor grey trash in a full bag.",
    "Pro tip from top guilds: allocating talent points is considered an advanced DPS increase.",
    "Your unspent points have officially gone AFK longer than the raid's off-tank.",
    "Clicking a talent node takes 0.5 seconds and costs 0 copper. Treat yourself.",
    "Did you forget to bind 'N', or are you just testing whether this addon actually works?",
    "At least you're consistent—consistently leaving free character power untouched.",
    "Your damage meter just whispered me: 'Please tell them to open their talent tree.'",
    "Unspent points are like unused health potions—great in theory, useless when you're on the floor.",
    "Somewhere, a Stitches abomination just smelled your unspent points and sped up.",
    "Even a Druid stuck in travel form gets to their talents faster than this.",
    "You're one unspent point away from getting out-DPS'd by a Battle Chicken.",
    "If this were a Raid Ready Check, your talent tree would have clicked 'Not Ready.'",
    "Ten whole minutes! You could have run across the entire Barrens in that time—almost.",
    "The Lich King isn't worried about your threat meter while those points stay unspent.",
    "Your class trainer is shaking their head from across the capital city.",
    "Don't make me summon a Warlock closet just to drag you to your talent tree.",
    "You're saving those points so hard a Goblin in Booty Bay wants to hire you as an accountant.",
    "Check your pulse AND your talent tree—one of them clearly hasn't moved in 10 minutes.",
    "Every time you ignore unspent points, an Engineer's Goblin Jumper Cables fail to rez.",
    "You've got unspent points glowing brighter than a Tier 2 Paladin in Ironforge.",
    "Are you waiting for a 50% off sale on talent points? Because they're already free.",
    "Even Goldshire innkeepers think you've been idling on those points for too long.",
    "Fun fact: spending points increases survival rates against sudden Fel Reaver footsteps.",
    "Your party thinks you're AFK-inspecting gear; little do they know you're hoarding talent points.",
    "A Level 1 Boar in Durotar just looked at your build and felt pretty confident.",
    "Remember that time you forgot to spend your points for 10 minutes? Oh wait, that's right now.",
    "Your talents have more unfulfilled potential than a Shaman begging for a 2H Windfury proc.",
    "Spend your points now and receive a 100% free upgrade from 'Noob' to 'Slightly Less Noob.'",
    "Not spending points is technically a pacifist run, right?",
    "Your keyboard has an 'N' key. It misses you. Give it a quick tap.",
    "Ten minutes with unspent points—at this pace, Ahn'Qiraj gates will open twice first.",
    "Even a Priest out of mana has more active output than those unspent points.",
    "Warning: prolonged exposure to unspent points may result in getting roasted by your guild.",
    "You've been sitting on those points so long they're about to hatch into Onyxia whelps.",
    "Don't be shy—put those points to work before the next boss emote calls you out.",
    "Your alt army is judging you silently from the character select screen.",
    "Spending your points won't fix standing in void zones, but hey, it's a solid start.",
    "The Innkeeper says you're well-rested, so you have zero excuses for those unspent points.",
    "If hesitation dealt damage, you'd be top of the meter right now.",
    "Your talent tree just sent an in-game mail titled: 'Hello? Anybody home?'",
    "Ten minutes without spending points—bold of you to handicap yourself for the content.",
    "Even a freshly tamed Hunter pet remembers to spend its points faster than this.",
    "Open the talent panel, pick a shiny icon, and pretend this friendly roast never happened.",
    "You have unspent points! Spend them before someone screenshots your build for guild Discord.",
    "Legend foretold of a hero who refused to click their talent tree... please don't be that hero.",
    "Last warning before I announce your unspent points in Trade Chat. Just kidding—go spend them!",
}

-- Sarcastic dismissal replies when the user mutes the graphical banner
PNB.DISMISS_REPLIES = {
    "Fine, hide the banner. Hogger sends his regards.",
    "Banner hidden. Don't come crying to me when a Kobold takes your candle.",
    "Alright, alright—banner silenced. I'll just silently judge your parse from chat.",
    "Banner dismissed. May your unspent points bring you warmth on the spirit healer run.",
    "Okay, Mr. 'I Don't Need Talents.' Chat reminders will keep the guild roast alive.",
    "Hiding the banner doesn't spend the points, champion. Just saying.",
    "Banner muted! Leeroy Jenkins approves of this reckless decision.",
    "Poof, banner gone. Your talent tree is still crying in the corner though.",
}

local function GetNagDB()
    if NS and NS.EnsureDB then NS:EnsureDB() end
    WOWEngineDB = WOWEngineDB or {}
    if type(WOWEngineDB.pointNag) ~= "table" then
        WOWEngineDB.pointNag = {
            bannerMutedUntil = 0,
            bannerPermOff = false,
            chatMuted = false,
            byChar = {},
        }
    end
    local db = WOWEngineDB.pointNag
    if db.bannerMutedUntil == nil then db.bannerMutedUntil = 0 end
    if db.bannerPermOff == nil then db.bannerPermOff = false end
    if db.chatMuted == nil then db.chatMuted = false end
    if type(db.byChar) ~= "table" then db.byChar = {} end
    return db
end

local function GetCharNagState()
    local db = GetNagDB()
    local cKey = C.CanonicalCharKey(C.GetPlayerName() or "Player") or "player"
    if type(db.byChar[cKey]) ~= "table" then
        db.byChar[cKey] = {
            firstUnspentAt = nil,
            lastWarnAt = 0,
            snoozeUntil = 0,
        }
    end
    return db.byChar[cKey], db
end

local function PickRandomRoast()
    local n = #PNB.ROASTS
    if n == 0 then return "You have unspent points waiting!" end
    local idx = math.random(1, n)
    if n > 1 and idx == PNB.lastRoastIdx then
        idx = (idx % n) + 1
    end
    PNB.lastRoastIdx = idx
    return PNB.ROASTS[idx]
end

local function PickDismissReply()
    local n = #PNB.DISMISS_REPLIES
    if n == 0 then return "Fine, hide the banner. Hogger sends his regards." end
    local idx = math.random(1, n)
    if n > 1 and idx == PNB.lastDismissIdx then
        idx = (idx % n) + 1
    end
    PNB.lastDismissIdx = idx
    return PNB.DISMISS_REPLIES[idx]
end

-- Nil-safe detection of unspent Talent/Skill Points + WoW Forever Legacy Points
function PNB:GetUnspentPoints()
    local talentPts = 0
    local legacyPts = 0

    -- 1. Classic / WoW Forever UnitCharacterPoints("player")
    if UnitCharacterPoints then
        local ok, pts = pcall(UnitCharacterPoints, "player")
        if ok and type(pts) == "number" and pts > talentPts then
            talentPts = pts
        end
    end

    -- 2. TBC / Wrath / Cata / MoP Classic GetUnspentTalentPoints
    if talentPts == 0 and GetUnspentTalentPoints then
        local ok, pts = pcall(GetUnspentTalentPoints, false, false)
        if ok and type(pts) == "number" and pts > talentPts then
            talentPts = pts
        end
    end

    -- 3. Modern Retail / Dragonflight / TWW / Midnight / WoW Forever C_ClassTalents + C_Traits
    if C_ClassTalents then
        if C_Traits and C_ClassTalents.GetActiveConfigID and C_Traits.GetConfigInfo and C_Traits.GetTreeCurrencyInfo then
            local okCfg, configID = pcall(C_ClassTalents.GetActiveConfigID)
            if okCfg and configID then
                local okInfo, cfgInfo = pcall(C_Traits.GetConfigInfo, configID)
                if okInfo and type(cfgInfo) == "table" and type(cfgInfo.treeIDs) == "table" then
                    local traitSum = 0
                    for _, treeID in ipairs(cfgInfo.treeIDs) do
                        local okCur, curList = pcall(C_Traits.GetTreeCurrencyInfo, configID, treeID, true)
                        if okCur and type(curList) == "table" then
                            for _, cur in ipairs(curList) do
                                if type(cur) == "table" and type(cur.quantity) == "number" and cur.quantity > 0 then
                                    traitSum = traitSum + cur.quantity
                                end
                            end
                        end
                    end
                    if traitSum > talentPts then
                        talentPts = traitSum
                    end
                end
            end
        end
        if talentPts == 0 and C_ClassTalents.HasUnspentTalentPoints then
            local okHas, hasPts = pcall(C_ClassTalents.HasUnspentTalentPoints)
            if okHas and hasPts then
                talentPts = 1
            end
        end
        if talentPts == 0 and C_ClassTalents.HasUnspentHeroTalentPoints then
            local okHero, hasHero = pcall(C_ClassTalents.HasUnspentHeroTalentPoints)
            if okHero and hasHero then
                talentPts = 1
            end
        end
    end

    -- 4. WoW Forever Legacy Points (nil-safe multi-API probe)
    local legacyProbes = {
        function() return _G.C_Legacy and _G.C_Legacy.GetUnspentPoints and _G.C_Legacy.GetUnspentPoints() end,
        function() return _G.C_Legacy and _G.C_Legacy.GetAvailablePoints and _G.C_Legacy.GetAvailablePoints() end,
        function() return _G.C_Legacy and _G.C_Legacy.GetLegacyPoints and _G.C_Legacy.GetLegacyPoints() end,
        function() return _G.C_LegacyTree and _G.C_LegacyTree.GetUnspentPoints and _G.C_LegacyTree.GetUnspentPoints() end,
        function() return _G.C_LegacyTree and _G.C_LegacyTree.GetAvailablePoints and _G.C_LegacyTree.GetAvailablePoints() end,
        function() return _G.C_LegacyTalents and _G.C_LegacyTalents.GetUnspentPoints and _G.C_LegacyTalents.GetUnspentPoints() end,
        function() return _G.GetUnspentLegacyPoints and _G.GetUnspentLegacyPoints() end,
        function() return _G.GetLegacyPoints and _G.GetLegacyPoints() end,
    }
    for _, probe in ipairs(legacyProbes) do
        local ok, val = pcall(probe)
        if ok and type(val) == "number" and val > legacyPts then
            legacyPts = val
            break
        end
    end

    return talentPts, legacyPts
end

function PNB:FormatPointSummary(talentPts, legacyPts)
    local parts = {}
    if talentPts and talentPts > 0 then
        table.insert(parts, string.format("%d Talent %s", talentPts, (talentPts == 1) and "Point" or "Points"))
    end
    if legacyPts and legacyPts > 0 then
        table.insert(parts, string.format("%d Legacy %s", legacyPts, (legacyPts == 1) and "Point" or "Points"))
    end
    if #parts == 0 then
        return "Unspent Points"
    end
    return table.concat(parts, " | ")
end

local function PlayRaidAlertSound()
    if not PlaySound then return end
    local soundID = (SOUNDKIT and (SOUNDKIT.RAID_WARNING or SOUNDKIT.READY_CHECK or SOUNDKIT.TELL_MESSAGE)) or 8959
    pcall(PlaySound, soundID, "Master")
end

local function SetSolidColor(tex, r, g, b, a)
    if tex.SetColorTexture then
        tex:SetColorTexture(r, g, b, a)
    else
        tex:SetTexture("Interface\\Buttons\\WHITE8x8")
        tex:SetVertexColor(r, g, b, a)
    end
end

function PNB:SendChatFallbackReminder(summaryText, roastText)
    local db = GetNagDB()
    if db.chatMuted then return end
    local msg = string.format(
        "|cffff2020[WOWEngine]|r |cffffd100UNSPENT POINTS (%s):|r |cffffffff%s|r |cff00aeff(Type /he nag off to silence chat alerts too)|r",
        tostring(summaryText or "Unspent Points"),
        tostring(roastText or PickRandomRoast())
    )
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    elseif NS and NS.Print then
        NS:Print(msg)
    end
end

function PNB:EnsureBanner()
    if PNB.frame then return PNB.frame end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", "WOWEnginePointNagBanner", UIParent, template)
    f:SetSize(540, 154)
    f:SetPoint("TOP", UIParent, "TOP", 0, -135)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(170)
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
                tile = true, tileSize = 16, edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            f:SetBackdropColor(0.04, 0.09, 0.19, 0.97)
            f:SetBackdropBorderColor(1.0, 0.82, 0.12, 1.0)
        end)
    else
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(f)
        SetSolidColor(bg, 0.04, 0.09, 0.19, 0.97)
    end

    -- Glowing gold inner accent rails (top & bottom) for dramatic Raid-Warning feel
    local topGlow = f:CreateTexture(nil, "BORDER")
    SetSolidColor(topGlow, 1.0, 0.84, 0.10, 0.92)
    topGlow:SetPoint("TOPLEFT", 6, -5)
    topGlow:SetPoint("TOPRIGHT", -6, -5)
    topGlow:SetHeight(2)

    local botGlow = f:CreateTexture(nil, "BORDER")
    SetSolidColor(botGlow, 1.0, 0.84, 0.10, 0.70)
    botGlow:SetPoint("BOTTOMLEFT", 6, 44)
    botGlow:SetPoint("BOTTOMRIGHT", -6, 44)
    botGlow:SetHeight(1)

    local headerBg = f:CreateTexture(nil, "ARTWORK")
    SetSolidColor(headerBg, 0.08, 0.19, 0.40, 0.92)
    headerBg:SetPoint("TOPLEFT", 6, -7)
    headerBg:SetPoint("TOPRIGHT", -6, -7)
    headerBg:SetHeight(42)

    if UISpecialFrames then
        table.insert(UISpecialFrames, "WOWEnginePointNagBanner")
    end

    -- Alert Icon
    local alertIcon = f:CreateTexture(nil, "OVERLAY")
    alertIcon:SetSize(32, 32)
    alertIcon:SetPoint("TOPLEFT", 16, -12)
    alertIcon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    f.alertIcon = alertIcon

    -- Bold THICKOUTLINE Raid Header
    local headerTxt = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    local fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    pcall(headerTxt.SetFont, headerTxt, fontPath, 17, "THICKOUTLINE")
    headerTxt:SetTextColor(1.0, 0.85, 0.10, 1.0)
    headerTxt:SetPoint("TOP", f, "TOP", 6, -11)
    headerTxt:SetText("UNSPENT POINTS DETECTED!")
    f.headerTxt = headerTxt

    -- Unspent Point Type Summary
    local pointsTxt = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pointsTxt:SetPoint("TOP", headerTxt, "BOTTOM", 0, -2)
    pointsTxt:SetTextColor(0.20, 1.0, 0.45, 1.0)
    f.pointsTxt = pointsTxt

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Sarcastic Guildie Roast Body
    local roastTxt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    roastTxt:SetPoint("TOPLEFT", 18, -56)
    roastTxt:SetPoint("TOPRIGHT", -18, -56)
    roastTxt:SetJustifyH("CENTER")
    roastTxt:SetJustifyV("MIDDLE")
    roastTxt:SetHeight(48)
    f.roastTxt = roastTxt

    -- Button 1: Snooze (15m)
    local snoozeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    snoozeBtn:SetSize(148, 26)
    snoozeBtn:SetPoint("BOTTOMLEFT", 18, 12)
    snoozeBtn:SetText("Snooze (15m)")
    snoozeBtn:SetScript("OnClick", function()
        local charState = GetCharNagState()
        charState.snoozeUntil = (time and time() or 0) + PNB.SNOOZE_SECONDS
        f:Hide()
        NS:Print("|cffffd100Point Nag Banner snoozed for 15 minutes.|r Good luck in there—try not to stand in fire!")
    end)

    -- Button 2: Off for 24h
    local mute24Btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    mute24Btn:SetSize(148, 26)
    mute24Btn:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
    mute24Btn:SetText("Off for 24h")
    mute24Btn:SetScript("OnClick", function()
        local db = GetNagDB()
        db.bannerMutedUntil = (time and time() or 0) + PNB.MUTE_24H_SECONDS
        f:Hide()
        local reply = PickDismissReply()
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff2020[WOWEngine]|r |cffffd100" .. reply .. "|r |cff00aeff(Banner muted 24h — chat reminders continue every 10m; type /he nag off to silence chat too)|r")
        else
            NS:Print(reply)
        end
    end)

    -- Button 3: Turn Off (Permanent)
    local permOffBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    permOffBtn:SetSize(148, 26)
    permOffBtn:SetPoint("BOTTOMRIGHT", -18, 12)
    permOffBtn:SetText("Turn Off")
    permOffBtn:SetScript("OnClick", function()
        local db = GetNagDB()
        db.bannerPermOff = true
        f:Hide()
        local reply = PickDismissReply()
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff2020[WOWEngine]|r |cffffd100" .. reply .. "|r |cff00aeff(Banner permanently disabled — chat reminders continue every 10m; type /he nag off to silence chat too)|r")
        else
            NS:Print(reply)
        end
    end)

    f:Hide()
    PNB.frame = f
    return f
end

function PNB:ShowBanner(summaryText, roastText, isPreview)
    local f = PNB:EnsureBanner()
    f.isPreview = isPreview and true or false
    f.pointsTxt:SetText(tostring(summaryText or "Unspent Points"))
    f.roastTxt:SetText('"' .. tostring(roastText or PickRandomRoast()) .. '"')
    PlayRaidAlertSound()
    f:Show()
    f:Raise()
end

function PNB:TestBanner()
    local talentPts, legacyPts = PNB:GetUnspentPoints()
    local summary = nil
    if (talentPts + legacyPts) > 0 then
        summary = PNB:FormatPointSummary(talentPts, legacyPts) .. "  |cffaaaaaa(Preview)|r"
    else
        summary = "2 Talent Points | 1 Legacy Point  |cffaaaaaa(Preview)|r"
    end
    PNB:ShowBanner(summary, PickRandomRoast(), true)
end

function PNB:CheckUnspentPoints()
    local charState, db = GetCharNagState()
    local talentPts, legacyPts = PNB:GetUnspentPoints()
    local total = (talentPts or 0) + (legacyPts or 0)
    local now = time and time() or 0

    if total <= 0 then
        -- Reset timer immediately once points hit 0
        charState.firstUnspentAt = nil
        charState.lastWarnAt = 0
        if PNB.frame and PNB.frame:IsShown() and not PNB.frame.isPreview then
            PNB.frame:Hide()
        end
        return
    end

    if not charState.firstUnspentAt then
        charState.firstUnspentAt = now
        return
    end

    if now < (charState.snoozeUntil or 0) then
        return
    end

    local elapsedFirst = now - charState.firstUnspentAt
    local elapsedWarn = now - (charState.lastWarnAt or 0)
    if elapsedFirst >= PNB.NAG_INTERVAL and elapsedWarn >= PNB.NAG_INTERVAL then
        charState.lastWarnAt = now
        local summary = PNB:FormatPointSummary(talentPts, legacyPts)
        local roast = PickRandomRoast()
        local bannerDisabled = (db.bannerPermOff == true) or (now < (db.bannerMutedUntil or 0))
        if not bannerDisabled then
            PNB:ShowBanner(summary, roast, false)
        elseif not db.chatMuted then
            PNB:SendChatFallbackReminder(summary, roast)
        end
    end
end

function PNB:HandleSlashCommand(arg)
    local sub = string.lower(C.Trim(arg or ""))
    local charState, db = GetCharNagState()

    if sub == "test" or sub == "preview" then
        PNB:TestBanner()
    elseif sub == "off" or sub == "mute" or sub == "disable" then
        db.bannerPermOff = true
        db.chatMuted = true
        if PNB.frame then PNB.frame:Hide() end
        NS:Print("|cffffd100Point Nag Banner AND chat reminders are now completely silenced.|r Type |cff00ff00/he nag on|r anytime to re-enable.")
    elseif sub == "on" or sub == "enable" or sub == "reset" then
        db.bannerPermOff = false
        db.bannerMutedUntil = 0
        db.chatMuted = false
        charState.snoozeUntil = 0
        charState.lastWarnAt = 0
        NS:Print("|cff00ff00Point Nag Banner & chat reminders re-enabled!|r (10-minute unspent point watchdog active)")
        pcall(function() PNB:CheckUnspentPoints() end)
    else
        local now = time and time() or 0
        local bannerState = db.bannerPermOff and "|cffff5555OFF (Permanent)|r"
            or (now < (db.bannerMutedUntil or 0) and "|cffff9900Muted (24h)|r" or "|cff00ff00ON|r")
        local chatState = db.chatMuted and "|cffff5555OFF|r" or "|cff00ff00ON|r"
        local tPts, lPts = PNB:GetUnspentPoints()
        NS:Print(string.format("Point Nag Watchdog — Banner: %s | Chat Fallback: %s | Current Unspent: |cffffd100%s|r",
            bannerState, chatState, ((tPts + lPts) > 0) and PNB:FormatPointSummary(tPts, lPts) or "None"))
        NS:Print("Usage: |cffffd100/he nag test|r (preview banner) | |cffffd100/he nag off|r (silence all) | |cffffd100/he nag on|r (re-enable)")
    end
end

local nagFrame = CreateFrame("Frame")
pcall(nagFrame.RegisterEvent, nagFrame, "PLAYER_LOGIN")
pcall(nagFrame.RegisterEvent, nagFrame, "PLAYER_ENTERING_WORLD")
pcall(nagFrame.RegisterEvent, nagFrame, "PLAYER_LEVEL_UP")
pcall(nagFrame.RegisterEvent, nagFrame, "CHARACTER_POINTS_CHANGED")
pcall(nagFrame.RegisterEvent, nagFrame, "PLAYER_TALENT_UPDATE")
pcall(nagFrame.RegisterEvent, nagFrame, "TRAIT_CONFIG_UPDATED")

local fallbackElapsed = 0
local function StartNagTicker()
    if PNB.ticker then return end
    if C_Timer and C_Timer.NewTicker then
        PNB.ticker = C_Timer.NewTicker(15, function()
            pcall(function() PNB:CheckUnspentPoints() end)
        end)
    else
        nagFrame:SetScript("OnUpdate", function(_, elapsed)
            fallbackElapsed = fallbackElapsed + (elapsed or 0)
            if fallbackElapsed >= 15 then
                fallbackElapsed = 0
                pcall(function() PNB:CheckUnspentPoints() end)
            end
        end)
    end
end

nagFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        StartNagTicker()
    end
    pcall(function() PNB:CheckUnspentPoints() end)
end)
