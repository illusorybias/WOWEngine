local addonName, NS = ...
NS.TalentAdvisor = {}
local TA = NS.TalentAdvisor
local C = NS.Compat

TA.bar = nil
TA.glowFrame = nil
TA.standaloneFrame = nil
TA.currentNextPick = nil

-- WoW Forever Class & Spec Pre-Loads (PvE Leveling, PvE Raid, PvP)
-- Each order entry: { tabIndex, talentNameSubstring, targetRank }
TA.BUILDS = {
    PALADIN = {
        {
            id = "prot_pve", label = "Protection PvE (0/39/12)", role = "Tank",
            weapon = "1H Fast Weapon + Shield (Spell Power / Tanking)",
            priority = "Defense Cap > Spell/Melee Hit Cap > Stamina > Intellect/Spell Power > Block/Mitigation",
            caps = { defense = 440, meleeHit = 8, spellHit = 16, critTarget = 10 },
            order = {
                { 2, "Redoubt", 5 }, { 2, "Precision", 3 }, { 2, "Toughness", 5 },
                { 2, "Blessing of Kings", 1 }, { 2, "Improved Righteous Fury", 3 }, { 2, "Shield Specialization", 3 },
                { 2, "Anticipation", 5 }, { 2, "Blessing of Sanctuary", 1 }, { 2, "Reckoning", 5 },
                { 2, "One-Handed Weapon Specialization", 5 }, { 2, "Holy Shield", 1 },
                { 3, "Benediction", 5 }, { 3, "Deflection", 5 }, { 3, "Seal of Command", 1 },
            },
        },
        {
            id = "ret_lvl", label = "Retribution Leveling (12/8/31)", role = "Melee DPS",
            weapon = "Slow 2H Sword / Mace / Axe",
            priority = "Melee Hit Cap (8%) > Strength > Crit > Attack Power > Stamina",
            caps = { meleeHit = 8, spellHit = 0, critTarget = 20 },
            order = {
                { 3, "Benediction", 5 }, { 3, "Improved Judgement", 2 }, { 3, "Deflection", 3 },
                { 3, "Seal of Command", 1 }, { 3, "Pursuit of Justice", 2 }, { 3, "Conviction", 5 },
                { 3, "Two-Handed Weapon Specialization", 3 }, { 3, "Sanctity Aura", 1 }, { 3, "Vengeance", 5 },
                { 3, "Repentance", 1 }, { 2, "Redoubt", 5 }, { 2, "Precision", 3 },
                { 1, "Divine Strength", 5 }, { 1, "Divine Intellect", 5 },
            },
        },
        {
            id = "pal_pvp", label = "Paladin PvP (Reckoning / Ret)", role = "PvP",
            weapon = "Slow 2H Weapon (or 1H + Shield swap vs Melee)",
            priority = "PvP Hit (5%) > Stamina > Strength > Crit > Intellect",
            caps = { meleeHit = 5, spellHit = 3, critTarget = 20 },
            order = {
                { 3, "Benediction", 5 }, { 3, "Deflection", 5 }, { 3, "Seal of Command", 1 },
                { 3, "Pursuit of Justice", 2 }, { 3, "Conviction", 5 }, { 3, "Repentance", 1 },
                { 2, "Redoubt", 5 }, { 2, "Precision", 3 }, { 2, "Guardian's Favor", 2 },
                { 2, "Reckoning", 5 },
            },
        },
    },
    WARLOCK = {
        {
            id = "aff_lvl", label = "Affliction Leveling (40/11/0)", role = "Caster DPS",
            weapon = "2H Staff or 1H Dagger/Sword + Off-Hand (+ Wand)",
            priority = "Spell Hit Cap (16% Raid / 3% PvP) > Shadow Spell Power > Stamina > Intellect > Spirit",
            caps = { spellHit = 16, critTarget = 12 },
            order = {
                { 1, "Improved Corruption", 5 }, { 1, "Suppression", 5 }, { 1, "Improved Life Tap", 2 },
                { 1, "Improved Drain Soul", 2 }, { 1, "Improved Curse of Agony", 3 }, { 1, "Fel Concentration", 5 },
                { 1, "Grim Reach", 2 }, { 1, "Nightfall", 2 }, { 1, "Siphon Life", 1 },
                { 1, "Shadow Mastery", 5 }, { 1, "Dark Pact", 1 },
                { 2, "Improved Healthstone", 2 }, { 2, "Demonic Embrace", 5 }, { 2, "Improved Voidwalker", 3 },
            },
        },
        {
            id = "demo_pve", label = "Demonology PvE / Solo (9/31/11)", role = "Caster DPS",
            weapon = "2H Staff or 1H + Off-Hand (Stamina / Spell Power)",
            priority = "Spell Hit Cap (16%) > Spell Power > Stamina > Intellect > Crit",
            caps = { spellHit = 16, critTarget = 14 },
            order = {
                { 2, "Demonic Embrace", 5 }, { 2, "Improved Voidwalker", 3 }, { 2, "Fel Intellect", 5 },
                { 2, "Fel Domination", 1 }, { 2, "Fel Stamina", 5 }, { 2, "Master Summoner", 2 },
                { 2, "Unholy Power", 5 }, { 2, "Demonic Sacrifice", 1 }, { 2, "Master Demonologist", 5 },
                { 2, "Soul Link", 1 }, { 1, "Improved Corruption", 5 },
            },
        },
        {
            id = "lock_pvp", label = "Warlock PvP (SL / Nightfall)", role = "PvP",
            weapon = "2H Staff or 1H + Off-Hand (High Stamina + Spell Power)",
            priority = "Spell Hit (3% PvP) > Stamina > Spell Power > Intellect",
            caps = { spellHit = 3, critTarget = 12 },
            order = {
                { 1, "Improved Corruption", 5 }, { 1, "Fel Concentration", 5 }, { 1, "Nightfall", 2 },
                { 2, "Demonic Embrace", 5 }, { 2, "Fel Domination", 1 }, { 2, "Master Summoner", 2 },
                { 2, "Unholy Power", 5 }, { 2, "Soul Link", 1 },
            },
        },
    },
    DRUID = {
        {
            id = "feral_lvl", label = "Feral Druid Leveling / Tank (0/39/12)", role = "Feral DPS / Tank",
            weapon = "2H Staff / Polearm / 2H Mace (High Feral AP / Agility / Stamina — NO Shield)",
            priority = "Melee Hit Cap (8%) > Agility > Strength > Stamina > Armor (Bear)",
            caps = { meleeHit = 8, defense = 415, critTarget = 25 },
            order = {
                { 2, "Ferocity", 5 }, { 2, "Feral Swiftness", 2 }, { 2, "Feral Aggression", 3 },
                { 2, "Sharpened Claws", 3 }, { 2, "Feral Charge", 1 }, { 2, "Predatory Strikes", 3 },
                { 2, "Blood Frenzy", 2 }, { 2, "Savage Fury", 2 }, { 2, "Faerie Fire (Feral)", 1 },
                { 2, "Heart of the Wild", 5 }, { 2, "Leader of the Pack", 1 },
                { 3, "Furor", 5 }, { 3, "Natural Weapons", 5 }, { 3, "Omen of Clarity", 1 },
            },
        },
        {
            id = "bal_pve", label = "Balance PvE (31/0/20)", role = "Caster DPS",
            weapon = "2H Staff or 1H Mace/Dagger + Off-Hand (Spell Power)",
            priority = "Spell Hit Cap (16%) > Spell Crit > Spell Power > Intellect",
            caps = { spellHit = 16, critTarget = 20 },
            order = {
                { 1, "Improved Wrath", 5 }, { 1, "Improved Moonfire", 5 }, { 1, "Vengeance", 5 },
                { 1, "Nature's Reach", 2 }, { 1, "Moonfury", 5 }, { 1, "Moonkin Form", 1 },
            },
        },
        {
            id = "druid_pvp", label = "Druid PvP (Hybrid Flag Carrier)", role = "PvP",
            weapon = "2H Staff (Stamina / Intellect / Healing)",
            priority = "Stamina > Intellect > Healing/Spell Power > Armor",
            caps = { meleeHit = 5, spellHit = 3, critTarget = 15 },
            order = {
                { 2, "Feral Swiftness", 2 }, { 2, "Feral Charge", 1 }, { 3, "Furor", 5 },
                { 3, "Nature's Swiftness", 1 }, { 1, "Nature's Grasp", 1 },
            },
        },
    },
    HUNTER = {
        {
            id = "bm_lvl", label = "Beast Mastery Leveling (31/20/0)", role = "Ranged DPS",
            weapon = "Slow Bow / Gun / Crossbow + 2H Stat Stick (Agility/AP) + Quiver",
            priority = "Ranged Hit Cap (8%) > Agility > Attack Power > Crit > Intellect",
            caps = { meleeHit = 8, critTarget = 22 },
            order = {
                { 1, "Improved Aspect of the Hawk", 5 }, { 1, "Endurance Training", 5 },
                { 1, "Unleashed Fury", 5 }, { 1, "Ferocity", 5 }, { 1, "Intimidation", 1 },
                { 1, "Bestial Discipline", 2 }, { 1, "Frenzy", 5 }, { 1, "Bestial Wrath", 1 },
                { 2, "Efficiency", 5 }, { 2, "Lethal Shots", 5 }, { 2, "Aimed Shot", 1 },
                { 2, "Hawk Eye", 3 }, { 2, "Mortal Shots", 5 },
            },
        },
        {
            id = "mm_pve", label = "Marksmanship Raid (2/31/18)", role = "Ranged DPS",
            weapon = "Slow High-Damage Bow / Crossbow + Agility Stat Stick + Quiver",
            priority = "Ranged Hit Cap (8%) > Agility > Crit > Attack Power",
            caps = { meleeHit = 8, critTarget = 25 },
            order = {
                { 2, "Efficiency", 5 }, { 2, "Lethal Shots", 5 }, { 2, "Aimed Shot", 1 },
                { 2, "Mortal Shots", 5 }, { 2, "Barrage", 3 }, { 2, "Ranged Weapon Specialization", 5 },
                { 2, "Trueshot Aura", 1 }, { 3, "Monster Slaying", 3 }, { 3, "Surefooted", 3 },
            },
        },
        {
            id = "hunt_pvp", label = "Hunter PvP (MM / Survival)", role = "PvP",
            weapon = "Slow Bow / Crossbow + Stamina/Agility 2H + Quiver",
            priority = "PvP Hit (5%) > Stamina > Agility > Crit",
            caps = { meleeHit = 5, critTarget = 22 },
            order = {
                { 2, "Lethal Shots", 5 }, { 2, "Aimed Shot", 1 }, { 2, "Scatter Shot", 1 },
                { 2, "Mortal Shots", 5 }, { 3, "Entrapment", 5 }, { 3, "Surefooted", 3 },
            },
        },
    },
    MAGE = {
        {
            id = "frost_lvl", label = "Frost Leveling / AoE (0/0/51)", role = "Caster DPS",
            weapon = "2H Staff or 1H Sword/Dagger + Off-Hand (+ Wand)",
            priority = "Spell Hit Cap (16% Raid / 6% Solo) > Frost Spell Power > Intellect > Crit",
            caps = { spellHit = 16, critTarget = 18 },
            order = {
                { 3, "Improved Frostbolt", 5 }, { 3, "Elemental Precision", 3 }, { 3, "Ice Shards", 5 },
                { 3, "Frostbite", 3 }, { 3, "Piercing Ice", 3 }, { 3, "Cold Snap", 1 },
                { 3, "Shatter", 5 }, { 3, "Ice Block", 1 }, { 3, "Winter's Chill", 5 },
                { 3, "Ice Barrier", 1 },
            },
        },
        {
            id = "arc_pve", label = "Arcane / Fire Raid", role = "Caster DPS",
            weapon = "2H Staff or 1H + Off-Hand (Spell Power / Crit)",
            priority = "Spell Hit Cap (16%) > Spell Power > Spell Crit > Intellect",
            caps = { spellHit = 16, critTarget = 22 },
            order = {
                { 1, "Arcane Subtlety", 2 }, { 1, "Arcane Focus", 5 }, { 1, "Arcane Concentration", 5 },
                { 1, "Arcane Mind", 5 }, { 1, "Presence of Mind", 1 }, { 1, "Arcane Power", 1 },
            },
        },
        {
            id = "mage_pvp", label = "Mage PvP (Frost / Shatter)", role = "PvP",
            weapon = "2H Staff or 1H + Off-Hand (Stamina / Intellect / Spell Power)",
            priority = "Spell Hit (3% PvP) > Stamina > Intellect > Spell Power > Crit",
            caps = { spellHit = 3, critTarget = 18 },
            order = {
                { 3, "Improved Frostbolt", 5 }, { 3, "Ice Shards", 5 }, { 3, "Frostbite", 3 },
                { 3, "Cold Snap", 1 }, { 3, "Shatter", 5 }, { 3, "Ice Block", 1 }, { 3, "Ice Barrier", 1 },
            },
        },
    },
    PRIEST = {
        {
            id = "shadow_lvl", label = "Shadow Leveling (13/0/38)", role = "Caster DPS",
            weapon = "High-DPS Wand + 2H Staff (Spirit / Shadow Power)",
            priority = "Spell Hit Cap (16% Raid / 10% Shadow Focus) > Shadow Power > Spirit > Intellect",
            caps = { spellHit = 16, critTarget = 12 },
            order = {
                { 1, "Wand Specialization", 5 }, { 3, "Spirit Tap", 5 }, { 3, "Shadow Focus", 5 },
                { 3, "Mind Flay", 1 }, { 3, "Improved Shadow Word: Pain", 2 }, { 3, "Shadow Reach", 3 },
                { 3, "Shadow Weaving", 5 }, { 3, "Vampiric Embrace", 1 }, { 3, "Darkness", 5 },
                { 3, "Shadowform", 1 },
            },
        },
        {
            id = "holy_pve", label = "Holy / Disc Raid Healer (21/30/0)", role = "Healer",
            weapon = "1H Mace/Dagger + Off-Hand or 2H Staff (+Healing / MP5)",
            priority = "Bonus Healing > MP5 / Spirit > Intellect > Stamina",
            caps = { spellHit = 0, critTarget = 10 },
            order = {
                { 1, "Unbreakable Will", 5 }, { 1, "Silent Resolve", 5 }, { 1, "Meditation", 3 },
                { 1, "Inner Focus", 1 }, { 1, "Divine Spirit", 1 },
                { 2, "Improved Renew", 3 }, { 2, "Holy Specialization", 5 }, { 2, "Spiritual Healing", 5 },
            },
        },
        {
            id = "priest_pvp", label = "Priest PvP (Shadow / Silence)", role = "PvP",
            weapon = "2H Staff or 1H + Off-Hand (Stamina / Shadow Power)",
            priority = "Spell Hit (3% PvP) > Stamina > Shadow Power > Intellect",
            caps = { spellHit = 3, critTarget = 12 },
            order = {
                { 3, "Blackout", 5 }, { 3, "Shadow Focus", 5 }, { 3, "Mind Flay", 1 },
                { 3, "Silence", 1 }, { 3, "Shadowform", 1 },
            },
        },
    },
    ROGUE = {
        {
            id = "combat_lvl", label = "Combat Swords Leveling (16/35/0)", role = "Melee DPS",
            weapon = "Slow Main-Hand Sword + Fast Off-Hand Sword/Dagger",
            priority = "Melee Hit Cap (8% Special) > Weapon Skill > Agility > Crit > Attack Power",
            caps = { meleeHit = 8, critTarget = 24 },
            order = {
                { 2, "Improved Sinister Strike", 2 }, { 2, "Lightning Reflexes", 3 }, { 2, "Precision", 5 },
                { 2, "Deflection", 5 }, { 2, "Riposte", 1 }, { 2, "Dual Wield Specialization", 5 },
                { 2, "Blade Flurry", 1 }, { 2, "Sword Specialization", 5 }, { 2, "Weapon Expertise", 2 },
                { 2, "Adrenaline Rush", 1 }, { 1, "Malice", 5 }, { 1, "Lethality", 5 },
            },
        },
        {
            id = "rogue_pvp", label = "Subtlety / Hemo PvP (21/0/30)", role = "PvP",
            weapon = "Slow Main-Hand Sword/Mace + Fast Off-Hand (or Dagger Ambush)",
            priority = "PvP Hit (5%) > Stamina > Agility > Crit > Attack Power",
            caps = { meleeHit = 5, critTarget = 22 },
            order = {
                { 3, "Master of Deception", 5 }, { 3, "Camouflage", 5 }, { 3, "Elusiveness", 2 },
                { 3, "Ghostly Strike", 1 }, { 3, "Hemorrhage", 1 }, { 3, "Preparation", 1 },
                { 1, "Malice", 5 }, { 1, "Cold Blood", 1 },
            },
        },
    },
    SHAMAN = {
        {
            id = "enh_lvl", label = "Enhancement Leveling (7/33/11)", role = "Melee DPS",
            weapon = "Slow 2H Axe/Mace (or 1H + Shield vs heavy melee)",
            priority = "Melee Hit Cap (8%) > Strength > Agility > Crit > Intellect",
            caps = { meleeHit = 8, spellHit = 0, critTarget = 20 },
            order = {
                { 2, "Ancestral Knowledge", 5 }, { 2, "Thundering Strikes", 5 }, { 2, "Improved Ghost Wolf", 2 },
                { 2, "Two-Handed Axes and Maces", 1 }, { 2, "Flurry", 5 }, { 2, "Parry", 1 },
                { 2, "Weapon Mastery", 5 }, { 2, "Stormstrike", 1 },
                { 3, "Nature's Guidance", 3 }, { 1, "Concussion", 5 },
            },
        },
        {
            id = "ele_pve", label = "Elemental PvE / PvP (31/0/20)", role = "Caster DPS",
            weapon = "1H Spell Mace/Dagger + Shield (Spell Power / Crit)",
            priority = "Spell Hit Cap (16% Raid / 3% PvP) > Spell Crit > Spell Power > Intellect",
            caps = { spellHit = 16, critTarget = 20 },
            order = {
                { 1, "Concussion", 5 }, { 1, "Call of Flame", 3 }, { 1, "Elemental Focus", 1 },
                { 1, "Call of Thunder", 5 }, { 1, "Elemental Fury", 1 }, { 1, "Lightning Mastery", 5 },
                { 1, "Elemental Mastery", 1 }, { 3, "Nature's Guidance", 3 },
            },
        },
        {
            id = "resto_pve", label = "Restoration Raid Healer (0/5/46)", role = "Healer",
            weapon = "1H Healing Mace + Shield (+Healing / MP5)",
            priority = "Bonus Healing > MP5 > Intellect > Spell Crit",
            caps = { spellHit = 0, critTarget = 12 },
            order = {
                { 3, "Improved Healing Wave", 5 }, { 3, "Tidal Focus", 5 }, { 3, "Tidal Mastery", 5 },
                { 3, "Nature's Swiftness", 1 }, { 3, "Purification", 5 }, { 3, "Mana Tide Totem", 1 },
            },
        },
    },
    WARRIOR = {
        {
            id = "arms_lvl", label = "Arms Leveling / PvP (31/20/0)", role = "Melee DPS",
            weapon = "Slow 2H Axe / Sword / Polearm (Highest Top-End Damage)",
            priority = "Melee Hit Cap (8% PvE / 5% PvP) > Strength > Crit > Stamina",
            caps = { meleeHit = 8, critTarget = 22 },
            order = {
                { 1, "Improved Heroic Strike", 3 }, { 1, "Deflection", 2 }, { 1, "Tactical Mastery", 5 },
                { 1, "Anger Management", 1 }, { 1, "Deep Wounds", 3 }, { 1, "Impale", 2 },
                { 1, "Sweeping Strikes", 1 }, { 1, "Axe Specialization", 5 }, { 1, "Mortal Strike", 1 },
                { 2, "Cruelty", 5 }, { 2, "Unbridled Wrath", 5 }, { 2, "Enrage", 5 },
            },
        },
        {
            id = "fury_pve", label = "Fury Raid DPS (17/34/0)", role = "Melee DPS",
            weapon = "Slow Main-Hand + Fast Off-Hand (Swords / Axes / Daggers)",
            priority = "Melee Hit Cap (8% Special) > Weapon Skill > Crit > Strength / AP",
            caps = { meleeHit = 8, critTarget = 26 },
            order = {
                { 2, "Cruelty", 5 }, { 2, "Unbridled Wrath", 5 }, { 2, "Improved Battle Shout", 5 },
                { 2, "Enrage", 5 }, { 2, "Death Wish", 1 }, { 2, "Flurry", 5 }, { 2, "Bloodthirst", 1 },
                { 1, "Tactical Mastery", 5 }, { 1, "Anger Management", 1 }, { 1, "Impale", 2 },
            },
        },
        {
            id = "prot_warr", label = "Protection Raid Tank (11/5/35)", role = "Tank",
            weapon = "Fast 1H Sword/Dagger + High-Armor Shield",
            priority = "Defense Cap (440) > Melee Hit Cap (8%) > Stamina > Dodge/Parry/Block",
            caps = { defense = 440, meleeHit = 8, critTarget = 12 },
            order = {
                { 3, "Shield Specialization", 5 }, { 3, "Anticipation", 5 }, { 3, "Toughness", 5 },
                { 3, "Last Stand", 1 }, { 3, "Defiance", 5 }, { 3, "Improved Sunder Armor", 3 },
                { 3, "Concussion Blow", 1 }, { 3, "One-Handed Weapon Specialization", 5 },
                { 3, "Shield Slam", 1 }, { 2, "Cruelty", 5 },
            },
        },
    },
}

function TA:GetPlayerClassBuilds()
    local _, classToken = UnitClass("player")
    return TA.BUILDS[classToken or "WARRIOR"] or TA.BUILDS.WARRIOR, classToken or "WARRIOR"
end

function TA:GetSelectedBuild()
    NS:EnsureDB()
    local builds = TA:GetPlayerClassBuilds()
    local cKey = C.CanonicalCharKey(C.GetPlayerName() or "Player") or "player"
    local savedId = WOWEngineDB.selectedSpecs and WOWEngineDB.selectedSpecs[cKey]
    if savedId then
        for _, b in ipairs(builds) do
            if b.id == savedId then return b end
        end
    end
    return builds[1]
end

function TA:CycleBuild()
    NS:EnsureDB()
    local builds = TA:GetPlayerClassBuilds()
    local cur = TA:GetSelectedBuild()
    local nextIdx = 1
    for i, b in ipairs(builds) do
        if b.id == cur.id then
            nextIdx = (i % #builds) + 1
            break
        end
    end
    local picked = builds[nextIdx]
    local cKey = C.CanonicalCharKey(C.GetPlayerName() or "Player") or "player"
    WOWEngineDB.selectedSpecs[cKey] = picked.id
    NS:Print("Selected Spec Pre-Load: |cffffd100" .. picked.label .. "|r (" .. picked.role .. ")")
    TA:UpdateTalentHighlight()
    if NS.StatCapsUI and NS.StatCapsUI.Refresh then NS.StatCapsUI:Refresh() end
end

-- Determine next recommended talent button based on current learned ranks
function TA:FindNextRecommendedTalent()
    local build = TA:GetSelectedBuild()
    if not build or not build.order or not GetNumTalents or not GetTalentInfo then
        return nil, build
    end

    for stepIdx, step in ipairs(build.order) do
        local tabIdx, wantName, wantRank = step[1], string.lower(step[2]), step[3]
        local okN, numTalents = pcall(GetNumTalents, tabIdx)
        if okN and type(numTalents) == "number" then
            for tIdx = 1, numTalents do
                local okT, tName, _, _, _, curRank, maxRank = pcall(GetTalentInfo, tabIdx, tIdx)
                if okT and tName and string.find(string.lower(tName), wantName, 1, true) then
                    local target = math.min(wantRank or maxRank or 1, maxRank or 1)
                    if (curRank or 0) < target then
                        return {
                            tab = tabIdx,
                            index = tIdx,
                            name = tName,
                            curRank = curRank or 0,
                            targetRank = target,
                            stepNum = stepIdx,
                        }, build
                    end
                end
            end
        end
    end
    return nil, build
end

-- Create WoW-style Gold Border around recommended next talent button
local function EnsureGoldBorder()
    if TA.glowFrame then return TA.glowFrame end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local g = CreateFrame("Frame", "WOWEngineTalentGoldBorder", UIParent, template)
    g:SetFrameStrata("HIGH")
    g:SetFrameLevel(90)
    if g.SetBackdrop then
        pcall(function()
            g:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 14,
            })
            g:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0)
        end)
    end
    local badge = g:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badge:SetPoint("BOTTOM", g, "TOP", 0, 2)
    badge:SetText("|cffffd100NEXT|r")
    g.badge = badge
    g:Hide()
    TA.glowFrame = g
    return g
end

function TA:EnsureTalentBar()
    local parent = _G.PlayerTalentFrame
    if not parent then return nil end

    if not TA.bar then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local bar = CreateFrame("Frame", "WOWEngineTalentBar", parent, template)
        bar:SetSize(340, 44)
        bar:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 16, 2)
        bar:SetFrameStrata("HIGH")
        if bar.SetBackdrop then
            pcall(function()
                bar:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 12,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 },
                })
                bar:SetBackdropColor(0.04, 0.09, 0.19, 0.96)
                bar:SetBackdropBorderColor(0.95, 0.78, 0.18, 1.0)
            end)
        end

        local specBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
        specBtn:SetSize(198, 20)
        specBtn:SetPoint("TOPLEFT", 6, -4)
        specBtn:SetScript("OnClick", function() TA:CycleBuild() end)
        bar.specBtn = specBtn

        local capsBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
        capsBtn:SetSize(124, 20)
        capsBtn:SetPoint("LEFT", specBtn, "RIGHT", 6, 0)
        capsBtn:SetText("Stat Caps")
        capsBtn:SetScript("OnClick", function()
            if NS.StatCapsUI and NS.StatCapsUI.Toggle then NS.StatCapsUI:Toggle() end
        end)

        local nextTxt = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nextTxt:SetPoint("BOTTOMLEFT", 8, 5)
        nextTxt:SetWidth(324)
        nextTxt:SetJustifyH("LEFT")
        bar.nextTxt = nextTxt

        TA.bar = bar
    end
    return TA.bar
end

function TA:UpdateTalentHighlight()
    local nextPick, build = TA:FindNextRecommendedTalent()
    TA.currentNextPick = nextPick

    local bar = TA:EnsureTalentBar()
    if bar then
        bar.specBtn:SetText(build and build.label or "Select Pre-Load")
        if nextPick then
            bar.nextTxt:SetText(string.format("|cffffd100Next Pick (Tab %d):|r |cff00ff00%s|r (%d/%d)",
                nextPick.tab, nextPick.name, nextPick.curRank, nextPick.targetRank))
        else
            bar.nextTxt:SetText("|cff00ff00Pre-load core talents complete!|r")
        end
    end

    local glow = EnsureGoldBorder()
    local parent = _G.PlayerTalentFrame
    if not parent or not parent:IsShown() or not nextPick then
        glow:Hide()
        return
    end

    local activeTab = (PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(parent)) or parent.selectedTab or 1
    if activeTab ~= nextPick.tab then
        glow:Hide()
        return
    end

    local btn = _G["PlayerTalentFrameTalent" .. nextPick.index]
    if btn and btn:IsShown() then
        glow:SetParent(parent)
        glow:ClearAllPoints()
        glow:SetPoint("TOPLEFT", btn, "TOPLEFT", -4, 4)
        glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 4, -4)
        glow:Show()
        glow:Raise()
    else
        glow:Hide()
    end
end

function TA:HookTalentFrame()
    local parent = _G.PlayerTalentFrame
    if not parent or TA.hooked then return end
    TA.hooked = true
    parent:HookScript("OnShow", function()
        TA:EnsureTalentBar()
        TA:UpdateTalentHighlight()
    end)
    parent:HookScript("OnHide", function()
        if TA.glowFrame then TA.glowFrame:Hide() end
    end)
    if hooksecurefunc and _G.PlayerTalentFrame_Update then
        hooksecurefunc("PlayerTalentFrame_Update", function()
            pcall(function() TA:UpdateTalentHighlight() end)
        end)
    end
end

function TA:PrintNextPick()
    local nextPick, build = TA:FindNextRecommendedTalent()
    NS:Print("Active Spec Pre-Load: |cffffd100" .. (build and build.label or "?") .. "|r")
    if nextPick then
        NS:Print(string.format("  Next Recommended Talent: |cff00ff00%s|r (Tab %d | Rank %d/%d)",
            nextPick.name, nextPick.tab, nextPick.curRank, nextPick.targetRank))
    else
        NS:Print("  Open your Talent Tree (N) to view the docked pre-load bar & gold border highlight.")
    end
end

local taEvents = CreateFrame("Frame")
taEvents:RegisterEvent("ADDON_LOADED")
taEvents:RegisterEvent("PLAYER_LOGIN")
taEvents:RegisterEvent("CHARACTER_POINTS_CHANGED")
taEvents:RegisterEvent("PLAYER_LEVEL_UP")
taEvents:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and (arg1 == "Blizzard_TalentUI" or arg1 == addonName) then
        pcall(function() TA:HookTalentFrame() end)
    elseif event == "PLAYER_LOGIN" then
        pcall(function() TA:HookTalentFrame() end)
    else
        pcall(function() TA:UpdateTalentHighlight() end)
    end
end)
