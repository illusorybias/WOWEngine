local addonName, NS = ...
NS.TalentAdvisor = {}
local TA = NS.TalentAdvisor
local C = NS.Compat

TA.bar = nil
TA.glowFrame = nil
TA.standaloneFrame = nil
TA.currentNextPick = nil
TA.hookedFrames = {}
TA.hookedFuncs = {}
TA.refreshPending = false

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
                -- Tab 2 Protection (39 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (10 pts)
                { 2, "Redoubt", 5 }, { 2, "Divine Intellect", 5 },
                -- Row 2 (5 pts -> 15 total)
                { 2, "Precision", 3 }, { 2, "Sacred Duty", 2 },
                -- Row 3 (8 pts -> 23 total)
                { 2, "Toughness", 5 }, { 2, "Shield Specialization", 2 }, { 2, "Templar's Bulwark", 1 },
                -- Row 4 (8 pts -> 31 total)
                { 2, "Improved Righteous Fury", 3 }, { 2, "Anticipation", 5 },
                -- Row 5 (4 pts -> 35 total)
                { 2, "Holy Shield", 1 }, { 2, "Reckoning", 3 },
                -- Row 6 (3 pts -> 38 total) & Row 7 (1 pt -> 39 total)
                { 2, "Iron Creed", 3 }, { 2, "Shieldsworn", 1 },
                -- Tab 3 Retribution (12 pts): Row 1 -> Row 2
                { 3, "Benediction", 5 }, { 3, "Deflection", 5 }, { 3, "Improved Judgement", 2 },
            },
        },
        {
            id = "ret_lvl", label = "Retribution Leveling (12/8/31)", role = "Melee DPS",
            weapon = "Slow 2H Sword / Mace / Axe",
            priority = "Melee Hit Cap (8%) > Strength > Crit > Attack Power > Stamina",
            caps = { meleeHit = 8, spellHit = 0, critTarget = 20 },
            order = {
                -- Tab 3 Retribution (31 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (10 pts)
                { 3, "Benediction", 5 }, { 3, "Deflection", 5 },
                -- Row 2 (5 pts -> 15 total)
                { 3, "Improved Judgement", 2 }, { 3, "Conviction", 3 },
                -- Row 3 (3 pts -> 18 total)
                { 3, "Seal of Command", 1 }, { 3, "Pursuit of Justice", 2 },
                -- Row 4 (4 pts -> 22 total)
                { 3, "Two-Handed Weapon Specialization", 3 }, { 3, "Sacred Arbiter", 1 },
                -- Row 5 (4 pts -> 26 total)
                { 3, "Vengeance", 3 }, { 3, "Repentance", 1 },
                -- Row 6 (4 pts -> 30 total) & Row 7 (1 pt -> 31 total)
                { 3, "Champion of the Light", 4 }, { 3, "Unsealed Wrath", 1 },
                -- Tab 1 Holy (12 pts): Row 1 -> Row 2
                { 1, "Divine Strength", 5 }, { 1, "Spiritual Focus", 5 }, { 1, "Improved Seals", 2 },
                -- Tab 2 Protection (8 pts): Row 1 -> Row 2
                { 2, "Redoubt", 5 }, { 2, "Precision", 3 },
            },
        },
        {
            id = "pal_pvp", label = "Paladin PvP (Reckoning / Ret 0/25/26)", role = "PvP",
            weapon = "Slow 2H Weapon (or 1H + Shield swap vs Melee)",
            priority = "PvP Hit (5%) > Stamina > Strength > Crit > Intellect",
            caps = { meleeHit = 5, spellHit = 3, critTarget = 20 },
            order = {
                -- Tab 3 Retribution (26 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (10 pts)
                { 3, "Benediction", 5 }, { 3, "Deflection", 5 },
                -- Row 2 (5 pts -> 15 total)
                { 3, "Improved Judgement", 2 }, { 3, "Conviction", 3 },
                -- Row 3 (5 pts -> 20 total)
                { 3, "Seal of Command", 1 }, { 3, "Pursuit of Justice", 2 }, { 3, "Vindication", 2 },
                -- Row 4 (5 pts -> 25 total) & Row 5 (1 pt -> 26 total)
                { 3, "Eye for an Eye", 2 }, { 3, "Two-Handed Weapon Specialization", 3 },
                { 3, "Repentance", 1 },
                -- Tab 2 Protection (25 pts): Row 1 -> Row 5
                -- Row 1 (10 pts)
                { 2, "Redoubt", 5 }, { 2, "Divine Intellect", 5 },
                -- Row 2 (5 pts -> 15 total)
                { 2, "Precision", 3 }, { 2, "Guardian's Favor", 2 },
                -- Row 3 (5 pts -> 20 total) & Row 5 (5 pts -> 25 total)
                { 2, "Improved Hammer of Justice", 3 }, { 2, "Toughness", 2 },
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
                -- Tab 1 Affliction (40 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (12 pts)
                { 1, "Improved Corruption", 5 }, { 1, "Suppression", 5 }, { 1, "Improved Life Tap", 2 },
                -- Row 2 (7 pts -> 19 total)
                { 1, "Improved Drains", 3 }, { 1, "Grim Reach", 2 }, { 1, "Soul Harvest", 2 },
                -- Row 3 (9 pts -> 28 total)
                { 1, "Improved Bane of Agony", 2 }, { 1, "Fel Concentration", 3 },
                { 1, "Amplify Curse", 1 }, { 1, "Pandemic", 3 },
                -- Row 4 (2 pts -> 30 total)
                { 1, "Nightfall", 2 },
                -- Row 5 (4 pts -> 34 total)
                { 1, "Siphon Life", 1 }, { 1, "Soul Siphon", 3 },
                -- Row 6 (5 pts -> 39 total) & Row 7 (1 pt -> 40 total)
                { 1, "Shadow Mastery", 5 }, { 1, "Wrack", 1 },
                -- Tab 2 Demonology (11 pts): Row 1 -> Row 2
                { 2, "Demonic Embrace", 5 }, { 2, "Improved Voidwalker", 3 }, { 2, "Fel Vitality", 3 },
            },
        },
        {
            id = "demo_pve", label = "Demonology PvE / Solo (9/31/11)", role = "Caster DPS",
            weapon = "2H Staff or 1H + Off-Hand (Stamina / Spell Power)",
            priority = "Spell Hit Cap (16%) > Spell Power > Stamina > Intellect > Crit",
            caps = { spellHit = 16, critTarget = 14 },
            order = {
                -- Tab 2 Demonology (31 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (10 pts)
                { 2, "Demonic Embrace", 5 }, { 2, "Unholy Power", 5 },
                -- Row 2 (6 pts -> 16 total)
                { 2, "Fel Vitality", 3 }, { 2, "Improved Voidwalker", 3 },
                -- Row 3 (3 pts -> 19 total)
                { 2, "Master Summoner", 2 }, { 2, "Demonic Sacrifice", 1 },
                -- Row 4 (4 pts -> 23 total)
                { 2, "Fel Domination", 1 }, { 2, "Demonic Brand", 3 },
                -- Row 5 (4 pts -> 27 total)
                { 2, "Soul Link", 1 }, { 2, "Demonic Knowledge", 3 },
                -- Row 6 (3 pts -> 30 total) & Row 7 (1 pt -> 31 total)
                { 2, "Master Demonologist", 3 }, { 2, "Demonic Pact", 1 },
                -- Tab 1 Affliction (9 pts): Row 1 -> Row 2
                { 1, "Improved Corruption", 5 }, { 1, "Improved Life Tap", 2 }, { 1, "Grim Reach", 2 },
                -- Tab 3 Destruction (11 pts): Row 1 -> Row 2
                { 3, "Improved Shadow Bolt", 5 }, { 3, "Bane", 5 }, { 3, "Cataclysm", 1 },
            },
        },
        {
            id = "lock_pvp", label = "Warlock PvP (SL / Nightfall)", role = "PvP",
            weapon = "2H Staff or 1H + Off-Hand (High Stamina + Spell Power)",
            priority = "Spell Hit (3% PvP) > Stamina > Spell Power > Intellect",
            caps = { spellHit = 3, critTarget = 12 },
            order = {
                -- Tab 1 Affliction (20 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (10 pts)
                { 1, "Improved Corruption", 5 }, { 1, "Suppression", 3 }, { 1, "Improved Life Tap", 2 },
                -- Row 2 (5 pts -> 15 total)
                { 1, "Grim Reach", 2 }, { 1, "Improved Drains", 3 },
                -- Row 3 (3 pts -> 18 total) & Row 4 (2 pts -> 20 total)
                { 1, "Fel Concentration", 3 }, { 1, "Nightfall", 2 },
                -- Tab 2 Demonology (31 pts): Row 1 -> Row 6
                -- Row 1 (10 pts)
                { 2, "Demonic Embrace", 5 }, { 2, "Unholy Power", 5 },
                -- Row 2 (5 pts -> 15 total)
                { 2, "Fel Vitality", 3 }, { 2, "Demonic Aegis", 2 },
                -- Row 3 (2 pts -> 17 total)
                { 2, "Master Summoner", 2 },
                -- Row 4 (3 pts -> 20 total)
                { 2, "Fel Domination", 1 }, { 2, "Demonic Brand", 2 },
                -- Row 5 (7 pts -> 27 total)
                { 2, "Soul Link", 1 }, { 2, "Improved Felhunter", 3 }, { 2, "Demonic Knowledge", 3 },
                -- Row 6 (4 pts -> 31 total)
                { 2, "Master Demonologist", 4 },
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
                -- Tab 2 Feral (39 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (10 pts)
                { 2, "Ferocity", 5 }, { 2, "Furor", 5 },
                -- Row 2 (8 pts -> 18 total)
                { 2, "Feral Swiftness", 2 }, { 2, "Thick Hide", 3 }, { 2, "Feral Instinct", 3 },
                -- Row 3 (5 pts -> 23 total)
                { 2, "Sharpened Claws", 2 }, { 2, "Feral Charge", 1 }, { 2, "Savage Fury", 2 },
                -- Row 4 (6 pts -> 29 total)
                { 2, "Predatory Strikes", 3 }, { 2, "Blood Frenzy", 2 }, { 2, "Lacerate", 1 },
                -- Row 5 (3 pts -> 32 total)
                { 2, "Leader of the Pack", 1 }, { 2, "Natural Instinct", 2 },
                -- Row 6 (6 pts -> 38 total) & Row 7 (1 pt -> 39 total)
                { 2, "Rend and Tear", 5 }, { 2, "Natural Reaction", 1 }, { 2, "Primal Bite", 1 },
                -- Tab 3 Restoration (12 pts): Row 1 -> Row 2
                { 3, "Heart of the Wild", 5 }, { 3, "Nature's Focus", 5 },
                { 3, "Natural Shapeshifter", 2 },
            },
        },
        {
            id = "bal_pve", label = "Balance PvE (31/0/20)", role = "Caster DPS",
            weapon = "2H Staff or 1H Mace/Dagger + Off-Hand (Spell Power)",
            priority = "Spell Hit Cap (16%) > Spell Crit > Spell Power > Intellect",
            caps = { spellHit = 16, critTarget = 20 },
            order = {
                -- Tab 1 Balance (31 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (10 pts)
                { 1, "Starlight Wrath", 5 }, { 1, "Genesis", 5 },
                -- Row 2 (5 pts -> 15 total)
                { 1, "Moonglow", 3 }, { 1, "Nature's Majesty", 2 },
                -- Row 3 (1 pt -> 16 total)
                { 1, "Nature's Splendor", 1 },
                -- Row 4 (8 pts -> 24 total)
                { 1, "Vengeance", 5 }, { 1, "Improved Starfire", 2 }, { 1, "Insect Swarm", 1 },
                -- Row 5 (4 pts -> 28 total)
                { 1, "Nature's Grace", 1 }, { 1, "Eclipse", 3 },
                -- Row 6 (2 pts -> 30 total) & Row 7 (1 pt -> 31 total)
                { 1, "Dreamstate", 2 }, { 1, "Moonkin Form", 1 },
                -- Tab 3 Restoration (20 pts): Row 1 -> Row 2 -> Row 3
                { 3, "Heart of the Wild", 5 }, { 3, "Nature's Focus", 5 },
                { 3, "Reflection", 3 }, { 3, "Naturalist", 5 },
                { 3, "Subtlety", 2 },
            },
        },
        {
            id = "druid_pvp", label = "Druid PvP (Hybrid Flag Carrier 0/22/29)", role = "PvP",
            weapon = "2H Staff (Stamina / Intellect / Healing)",
            priority = "Stamina > Intellect > Healing/Spell Power > Armor",
            caps = { meleeHit = 5, spellHit = 3, critTarget = 15 },
            order = {
                -- Tab 2 Feral (22 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (10 pts)
                { 2, "Ferocity", 5 }, { 2, "Furor", 5 },
                -- Row 2 (7 pts -> 17 total)
                { 2, "Feral Swiftness", 2 }, { 2, "Brutal Impact", 2 }, { 2, "Thick Hide", 3 },
                -- Row 3 (5 pts -> 22 total)
                { 2, "Feral Charge", 1 }, { 2, "Sharpened Claws", 2 }, { 2, "Savage Fury", 2 },
                -- Tab 3 Restoration (29 pts): Row 1 -> Row 5
                -- Row 1 (10 pts)
                { 3, "Heart of the Wild", 5 }, { 3, "Nature's Focus", 5 },
                -- Row 2 (6 pts -> 16 total)
                { 3, "Reflection", 3 }, { 3, "Natural Shapeshifter", 3 },
                -- Row 3 (5 pts -> 21 total)
                { 3, "Gift of Nature", 5 },
                -- Row 4 (7 pts -> 28 total) & Row 5 (1 pt -> 29 total)
                { 3, "Improved Rejuvenation", 3 }, { 3, "Swiftmend", 1 }, { 3, "Tranquil Spirit", 3 },
                { 3, "Nature's Swiftness", 1 },
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
                -- Tab 1 Beast Mastery (31 pts): 10 legal points in Rows 1-2 before Row 3 (WoW Forever 16001)
                { 1, "Endurance Training", 5 }, { 1, "Focused Fire", 2 }, { 1, "Improved Aspect of the Monkey", 3 },
                -- Row 3+ (unlocked at 10+ pts in BM)
                { 1, "Pathfinding", 2 }, { 1, "Bestial Swiftness", 1 }, { 1, "Unleashed Fury", 5 },
                { 1, "Ferocity", 5 }, { 1, "Intimidation", 1 },
                { 1, "Bestial Discipline", 2 }, { 1, "Frenzy", 4 }, { 1, "Bestial Wrath", 1 },
                -- Tab 2 Marksmanship (20 pts): Row 1 Lethal Attacks (5/5) before Row 2 Efficiency & Careful Aim
                { 2, "Lethal Attacks", 5 }, { 2, "Efficiency", 5 }, { 2, "Careful Aim", 5 },
                { 2, "Trueshot Aura", 1 }, { 2, "Mortal Shots", 4 },
            },
        },
        {
            id = "mm_pve", label = "Marksmanship Raid (2/31/18)", role = "Ranged DPS",
            weapon = "Slow High-Damage Bow / Crossbow + Agility Stat Stick + Quiver",
            priority = "Ranged Hit Cap (8%) > Agility > Crit > Attack Power",
            caps = { meleeHit = 8, critTarget = 25 },
            order = {
                -- Tab 2 Marksmanship (31 pts): Row 1 Lethal Attacks (5/5) before Row 2 Efficiency & Careful Aim
                { 2, "Lethal Attacks", 5 }, { 2, "Efficiency", 5 }, { 2, "Careful Aim", 5 },
                { 2, "Trueshot Aura", 1 }, { 2, "Mortal Shots", 5 },
                { 2, "Barrage", 3 }, { 2, "Scatter Shot", 1 },
                { 2, "Ranged Weapon Specialization", 5 }, { 2, "Sniper Shot", 1 },
                -- Tab 3 Survival (18 pts): Row 1 Improved Tracking (5/5) before Row 2+
                { 3, "Improved Tracking", 5 }, { 3, "Entrapment", 5 },
                { 3, "Survivalist", 5 }, { 3, "Surefooted", 3 },
                -- Tab 1 Beast Mastery (2 pts)
                { 1, "Endurance Training", 2 },
            },
        },
        {
            id = "hunt_pvp", label = "Hunter PvP (MM / Survival)", role = "PvP",
            weapon = "Slow Bow / Crossbow + Stamina/Agility 2H + Quiver",
            priority = "PvP Hit (5%) > Stamina > Agility > Crit",
            caps = { meleeHit = 5, critTarget = 22 },
            order = {
                -- Tab 2 Marksmanship (21 pts): Row 1 Lethal Attacks (5/5) before Row 2+
                { 2, "Lethal Attacks", 5 }, { 2, "Efficiency", 5 }, { 2, "Careful Aim", 5 },
                { 2, "Mortal Shots", 5 }, { 2, "Scatter Shot", 1 },
                -- Tab 3 Survival (22 pts): Row 1 Deflection (5/5) before Row 2+
                { 3, "Deflection", 5 }, { 3, "Entrapment", 5 }, { 3, "Improved Wing Clip", 3 },
                { 3, "Survivalist", 5 }, { 3, "Surefooted", 3 }, { 3, "Deterrence", 1 },
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
                -- Tab 3 Frost (48 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (8 pts)
                { 3, "Improved Frostbolt", 5 }, { 3, "Precision", 3 },
                -- Row 2 (10 pts -> 18 total)
                { 3, "Ice Shards", 5 }, { 3, "Improved Frost Nova", 2 }, { 3, "Permafrost", 3 },
                -- Row 3 (7 pts -> 25 total)
                { 3, "Improved Blizzard", 3 }, { 3, "Frost Channeling", 3 }, { 3, "Ice Lance", 1 },
                -- Row 4 (6 pts -> 31 total)
                { 3, "Ice Block", 1 }, { 3, "Shatter", 3 }, { 3, "Arctic Reach", 2 },
                -- Row 5 (6 pts -> 37 total)
                { 3, "Cold Snap", 1 }, { 3, "Improved Cone of Cold", 3 }, { 3, "Fingers of Frost", 2 },
                -- Row 6 (5 pts -> 42 total) & Row 7 (1 pt -> 43 total)
                { 3, "Winter's Chill", 5 }, { 3, "Ice Barrier", 1 },
                -- Remaining Frost Row 1-2 picks (5 pts -> 48 total)
                { 3, "Frostbite", 3 }, { 3, "Frost Warding", 2 },
            },
        },
        {
            id = "arc_pve", label = "Arcane / Fire Raid (31/20/0)", role = "Caster DPS",
            weapon = "2H Staff or 1H + Off-Hand (Spell Power / Crit)",
            priority = "Spell Hit Cap (16%) > Spell Power > Spell Crit > Intellect",
            caps = { spellHit = 16, critTarget = 22 },
            order = {
                -- Tab 1 Arcane (31 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (5 pts -> unlocks Row 2)
                { 1, "Improved Channeling", 5 },
                -- Row 2 (9 pts -> 14 total)
                { 1, "Arcane Subtlety", 2 }, { 1, "Arcane Concentration", 5 }, { 1, "Missile Barrage", 2 },
                -- Row 3 (4 pts -> 18 total)
                { 1, "Arcane Impact", 3 }, { 1, "Arcane Blast", 1 },
                -- Row 4 (4 pts -> 22 total)
                { 1, "Arcane Meditation", 3 }, { 1, "Arcane Wrath", 1 },
                -- Row 5 (5 pts -> 27 total)
                { 1, "Presence of Mind", 1 }, { 1, "Arcane Mind", 4 },
                -- Row 6 (3 pts -> 30 total) & Row 7 (1 pt -> 31 total)
                { 1, "Arcane Instability", 3 }, { 1, "Arcane Power", 1 },
                -- Tab 2 Fire (20 pts): Row 1 -> Row 2 -> Row 3
                { 2, "Incineration", 5 }, { 2, "Accelerant", 5 },
                { 2, "Ignite", 5 }, { 2, "Flame Throwing", 2 },
                { 2, "Pyroblast", 1 }, { 2, "Improved Fire Blast", 2 },
            },
        },
        {
            id = "mage_pvp", label = "Mage PvP (Frost / Shatter)", role = "PvP",
            weapon = "2H Staff or 1H + Off-Hand (Stamina / Intellect / Spell Power)",
            priority = "Spell Hit (3% PvP) > Stamina > Intellect > Spell Power > Crit",
            caps = { spellHit = 3, critTarget = 18 },
            order = {
                -- Tab 3 Frost (40 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (8 pts)
                { 3, "Improved Frostbolt", 5 }, { 3, "Precision", 3 },
                -- Row 2 (10 pts -> 18 total)
                { 3, "Ice Shards", 5 }, { 3, "Frostbite", 3 }, { 3, "Improved Frost Nova", 2 },
                -- Row 3 (4 pts -> 22 total)
                { 3, "Ice Lance", 1 }, { 3, "Frost Channeling", 3 },
                -- Row 4 (6 pts -> 28 total)
                { 3, "Ice Block", 1 }, { 3, "Shatter", 3 }, { 3, "Arctic Reach", 2 },
                -- Row 5 (6 pts -> 34 total)
                { 3, "Cold Snap", 1 }, { 3, "Fingers of Frost", 2 }, { 3, "Improved Cone of Cold", 3 },
                -- Row 6 (5 pts -> 39 total) & Row 7 (1 pt -> 40 total)
                { 3, "Winter's Chill", 5 }, { 3, "Ice Barrier", 1 },
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
                -- Tab 3 Shadow (38 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (10 pts)
                { 3, "Spirit Tap", 5 }, { 3, "Shadow Focus", 5 },
                -- Row 2 (9 pts -> 19 total)
                { 3, "Improved Shadow Word: Pain", 2 }, { 3, "Improved Mind Blast", 5 }, { 3, "Shadow Reach", 2 },
                -- Row 3 (3 pts -> 22 total)
                { 3, "Mind Flay", 1 }, { 3, "Improved Mind Flay", 2 },
                -- Row 4 (4 pts -> 26 total)
                { 3, "Vampiric Embrace", 1 }, { 3, "Shadow Weaving", 3 },
                -- Row 5 (2 pts -> 28 total)
                { 3, "Devouring Contagion", 2 },
                -- Row 6 (5 pts -> 33 total) & Row 7 (1 pt -> 34 total)
                { 3, "Darkness", 5 }, { 3, "Shadowform", 1 },
                -- Remaining Shadow points (4 pts -> 38 total)
                { 3, "Dark Inspiration", 4 },
                -- Tab 1 Discipline (13 pts): Row 1 -> Row 2 -> Row 3
                { 1, "Wand Specialization", 2 }, { 1, "Twin Disciplines", 5 },
                { 1, "Silent Resolve", 3 }, { 1, "Meditation", 3 },
            },
        },
        {
            id = "holy_pve", label = "Holy / Disc Raid Healer (21/30/0)", role = "Healer",
            weapon = "1H Mace/Dagger + Off-Hand or 2H Staff (+Healing / MP5)",
            priority = "Bonus Healing > MP5 / Spirit > Intellect > Stamina",
            caps = { spellHit = 0, critTarget = 10 },
            order = {
                -- Tab 1 Discipline (21 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (5 pts)
                { 1, "Twin Disciplines", 5 },
                -- Row 2 (8 pts -> 13 total)
                { 1, "Silent Resolve", 3 }, { 1, "Mental Strength", 5 },
                -- Row 3 (7 pts -> 20 total) & Row 5 (1 pt -> 21 total)
                { 1, "Inner Focus", 1 }, { 1, "Meditation", 3 }, { 1, "Mental Agility", 3 },
                { 1, "Penance", 1 },
                -- Tab 2 Holy (30 pts): Row 1 -> Row 6
                -- Row 1 (8 pts)
                { 2, "Improved Renew", 3 }, { 2, "Holy Specialization", 5 },
                -- Row 2 (5 pts -> 13 total) & Row 3 (3 pts -> 16 total)
                { 2, "Divine Fury", 5 }, { 2, "Inspiration", 3 },
                -- Row 4 (5 pts -> 21 total)
                { 2, "Improved Healing", 3 }, { 2, "Holy Reach", 2 },
                -- Row 5 (6 pts -> 27 total) & Row 6 (3 pts -> 30 total)
                { 2, "Spiritual Guidance", 5 }, { 2, "Spirit of Redemption", 1 },
                { 2, "Spiritual Healing", 3 },
            },
        },
        {
            id = "priest_pvp", label = "Priest PvP (Shadow / Silence)", role = "PvP",
            weapon = "2H Staff or 1H + Off-Hand (Stamina / Shadow Power)",
            priority = "Spell Hit (3% PvP) > Stamina > Shadow Power > Intellect",
            caps = { spellHit = 3, critTarget = 12 },
            order = {
                -- Tab 3 Shadow (36 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (10 pts)
                { 3, "Blackout", 5 }, { 3, "Shadow Focus", 5 },
                -- Row 2 (9 pts -> 19 total)
                { 3, "Improved Shadow Word: Pain", 2 }, { 3, "Improved Mind Blast", 5 }, { 3, "Shadow Reach", 2 },
                -- Row 3 (3 pts -> 22 total)
                { 3, "Mind Flay", 1 }, { 3, "Improved Psychic Scream", 2 },
                -- Row 4 (4 pts -> 26 total)
                { 3, "Vampiric Embrace", 1 }, { 3, "Shadow Weaving", 3 },
                -- Row 5 (3 pts -> 29 total)
                { 3, "Silence", 1 }, { 3, "Devouring Contagion", 2 },
                -- Row 6 (6 pts -> 35 total) & Row 7 (1 pt -> 36 total)
                { 3, "Darkness", 5 }, { 3, "Early Demise", 1 }, { 3, "Shadowform", 1 },
                -- Tab 1 Discipline (15 pts): Row 1 -> Row 2 -> Row 3
                { 1, "Twin Disciplines", 5 },
                { 1, "Martyrdom", 2 }, { 1, "Mental Strength", 3 },
                { 1, "Improved Power Word: Shield", 3 }, { 1, "Inner Focus", 1 }, { 1, "Meditation", 1 },
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
                -- Tab 2 Combat (35 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (5 pts -> unlocks Row 2)
                { 2, "Efficient Strikes", 2 }, { 2, "Coup de Grace", 3 },
                -- Row 2 (6 pts -> 11 total, unlocks Row 3)
                { 2, "Deflection", 3 }, { 2, "Precision", 3 },
                -- Row 3 (4 pts -> 15 total, unlocks Row 4)
                { 2, "Riposte", 1 }, { 2, "Endurance", 2 }, { 2, "Composure", 1 },
                -- Row 4 (6 pts -> 21 total, unlocks Row 5)
                { 2, "Weapon Expertise", 2 }, { 2, "Aggression", 3 }, { 2, "Flawless Execution", 1 },
                -- Row 5 (8 pts -> 29 total, unlocks Row 6)
                { 2, "Dual Wield Specialization", 2 }, { 2, "Blade Flurry", 1 }, { 2, "Hack and Slash", 5 },
                -- Row 6 (5 pts -> 34 total, unlocks Row 7) & Row 7 (1 pt -> 35 total)
                { 2, "Flash of Steel", 5 }, { 2, "Adrenaline Rush", 1 },
                -- Tab 1 Assassination (13 pts): Row 1 Malice (5/5) before Row 2 & Row 3
                { 1, "Malice", 5 }, { 1, "Ruthlessness", 3 }, { 1, "Improved Slice and Dice", 3 },
                { 1, "Lethality", 2 },
            },
        },
        {
            id = "rogue_pvp", label = "Subtlety / Hemo PvP (21/0/30)", role = "PvP",
            weapon = "Slow Main-Hand Sword/Mace + Fast Off-Hand (or Dagger Ambush)",
            priority = "PvP Hit (5%) > Stamina > Agility > Crit > Attack Power",
            caps = { meleeHit = 5, critTarget = 22 },
            order = {
                -- Tab 3 Subtlety (25 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (8 pts -> unlocks Row 2)
                { 3, "Master of Deception", 3 }, { 3, "Opportunity", 3 }, { 3, "Setup", 2 },
                -- Row 2 (5 pts -> 13 total, unlocks Row 3)
                { 3, "Camouflage", 3 }, { 3, "Dirty Deeds", 2 },
                -- Row 3 (7 pts -> 20 total, unlocks Row 4 & Row 5)
                { 3, "Initiative", 3 }, { 3, "Serrated Blades", 3 }, { 3, "Premeditation", 1 },
                -- Row 4 (3 pts -> 23 total)
                { 3, "Elusiveness", 2 }, { 3, "Ghostly Strike", 1 },
                -- Row 5 (2 pts -> 25 total)
                { 3, "Preparation", 1 }, { 3, "Hemorrhage", 1 },
                -- Tab 1 Assassination (16 pts): Row 1 Malice (5/5) before Row 2-4
                { 1, "Malice", 5 }, { 1, "Ruthlessness", 3 }, { 1, "Improved Slice and Dice", 3 },
                { 1, "Vigor", 2 }, { 1, "Lethality", 2 }, { 1, "Cold Blood", 1 },
            },
        },
    },
    SHAMAN = {
        {
            id = "enh_lvl", label = "Enhancement Leveling (0/39/12)", role = "Melee DPS",
            weapon = "Slow 2H Axe/Mace (or Dual-Wield / 1H + Shield vs heavy melee)",
            priority = "Melee Hit Cap (8%) > Strength > Agility > Crit > Intellect",
            caps = { meleeHit = 8, spellHit = 0, critTarget = 20 },
            order = {
                -- Tab 2 Enhancement (39 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (10 pts -> unlocks Row 2 & Row 3)
                { 2, "Thundering Strikes", 5 }, { 2, "Ancestral Knowledge", 5 },
                -- Row 2 (6 pts -> 16 total)
                { 2, "Mental Dexterity", 3 }, { 2, "Improved Lightning Shield", 3 },
                -- Row 3 (4 pts -> 20 total)
                { 2, "Elemental Weapons", 3 }, { 2, "Shamanistic Focus", 1 },
                -- Row 4 (8 pts -> 28 total)
                { 2, "Flurry", 5 }, { 2, "Stormstrike", 1 }, { 2, "Improved Ghost Wolf", 2 },
                -- Row 5 (5 pts -> 33 total)
                { 2, "Spirit Weapons", 1 }, { 2, "Mental Quickness", 2 }, { 2, "Improved Stormstrike", 2 },
                -- Row 6 (5 pts -> 38 total) & Row 7 (1 pt -> 39 total)
                { 2, "Maelstrom Weapon", 5 }, { 2, "Rage of the Farseer", 1 },
                -- Tab 3 Restoration (12 pts): Row 1 -> Row 2 -> Row 3
                { 3, "Tidal Focus", 5 }, { 3, "Mindfulness", 3 }, { 3, "Natural Grace", 3 },
                { 3, "Water Shield", 1 },
            },
        },
        {
            id = "ele_pve", label = "Elemental PvE / PvP (31/0/20)", role = "Caster DPS",
            weapon = "1H Spell Mace/Dagger + Shield (Spell Power / Crit)",
            priority = "Spell Hit Cap (16% Raid / 3% PvP) > Spell Crit > Spell Power > Intellect",
            caps = { spellHit = 16, critTarget = 20 },
            order = {
                -- Tab 1 Elemental (31 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (10 pts)
                { 1, "Concussion", 5 }, { 1, "Convection", 5 },
                -- Row 2 (6 pts -> 16 total)
                { 1, "Elemental Alacrity", 3 }, { 1, "Call of Flame", 3 },
                -- Row 3 (1 pt -> 17 total)
                { 1, "Elemental Focus", 1 },
                -- Row 4 (4 pts -> 21 total)
                { 1, "Trial by Fire", 2 }, { 1, "Eye of the Storm", 2 },
                -- Row 5 (4 pts -> 25 total)
                { 1, "Call of Thunder", 1 }, { 1, "Lightning Overload", 3 },
                -- Row 6 (5 pts -> 30 total) & Row 7 (1 pt -> 31 total)
                { 1, "Elemental Fury", 5 }, { 1, "Lightning Mastery", 1 },
                -- Tab 3 Restoration (20 pts): Row 1 -> Row 2 -> Row 3 -> Row 4
                { 3, "Tidal Focus", 5 }, { 3, "Improved Healing Wave", 5 },
                { 3, "Totemic Focus", 5 }, { 3, "Water Shield", 1 }, { 3, "Healing Focus", 3 },
                { 3, "Tidal Mastery", 1 },
            },
        },
        {
            id = "resto_pve", label = "Restoration Raid Healer (0/5/46)", role = "Healer",
            weapon = "1H Healing Mace + Shield (+Healing / MP5)",
            priority = "Bonus Healing > MP5 > Intellect > Spell Crit",
            caps = { spellHit = 0, critTarget = 12 },
            order = {
                -- Tab 3 Restoration (46 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (10 pts)
                { 3, "Improved Healing Wave", 5 }, { 3, "Tidal Focus", 5 },
                -- Row 2 (10 pts -> 20 total)
                { 3, "Totemic Focus", 4 }, { 3, "Mindfulness", 3 }, { 3, "Natural Grace", 3 },
                -- Row 3 (7 pts -> 27 total)
                { 3, "Ancestral Healing", 3 }, { 3, "Healing Focus", 3 }, { 3, "Water Shield", 1 },
                -- Row 4 (11 pts -> 38 total)
                { 3, "Tidal Mastery", 5 }, { 3, "Restorative Totems", 5 }, { 3, "Mana Tide Totem", 1 },
                -- Row 5 (2 pts -> 40 total)
                { 3, "Healing Way", 1 }, { 3, "Nature's Swiftness", 1 },
                -- Row 6 (5 pts -> 45 total) & Row 7 (1 pt -> 46 total)
                { 3, "Purification", 5 }, { 3, "Riptide", 1 },
                -- Tab 2 Enhancement (5 pts): Row 1
                { 2, "Ancestral Knowledge", 5 },
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
                -- Tab 1 Arms (31 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (8 pts)
                { 1, "Deflection", 5 }, { 1, "Improved Rend", 3 },
                -- Row 2 (5 pts -> 13 total)
                { 1, "Improved Tactical Mastery", 3 }, { 1, "Improved Overpower", 2 },
                -- Row 3 (4 pts -> 17 total)
                { 1, "Anger Management", 1 }, { 1, "Deep Wounds", 3 },
                -- Row 4 (5 pts -> 22 total)
                { 1, "Impale", 2 }, { 1, "Two-Handed Weapon Specialization", 3 },
                -- Row 5 (6 pts -> 28 total)
                { 1, "Sweeping Strikes", 1 }, { 1, "Weaponmaster", 5 },
                -- Row 6 (2 pts -> 30 total) & Row 7 (1 pt -> 31 total)
                { 1, "Improved Hamstring", 2 }, { 1, "Mortal Strike", 1 },
                -- Tab 2 Fury (20 pts): Row 1 -> Row 2 -> Row 3
                { 2, "Cruelty", 5 }, { 2, "Booming Voice", 5 },
                { 2, "Unbridled Wrath", 5 },
                { 2, "Piercing Howl", 1 }, { 2, "Enrage", 4 },
            },
        },
        {
            id = "fury_pve", label = "Fury Raid DPS (17/34/0)", role = "Melee DPS",
            weapon = "Slow Main-Hand + Fast Off-Hand (Swords / Axes / Daggers)",
            priority = "Melee Hit Cap (8% Special) > Weapon Skill > Crit > Strength / AP",
            caps = { meleeHit = 8, critTarget = 26 },
            order = {
                -- Tab 2 Fury (34 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (10 pts)
                { 2, "Cruelty", 5 }, { 2, "Booming Voice", 5 },
                -- Row 2 (5 pts -> 15 total)
                { 2, "Unbridled Wrath", 5 },
                -- Row 3 (5 pts -> 20 total)
                { 2, "Furious Precision", 3 }, { 2, "Enrage", 2 },
                -- Row 4 (7 pts -> 27 total)
                { 2, "Dual Wield Specialization", 5 }, { 2, "Improved Execute", 2 },
                -- Row 5 (1 pt -> 28 total)
                { 2, "Death Wish", 1 },
                -- Row 6 (5 pts -> 33 total) & Row 7 (1 pt -> 34 total)
                { 2, "Flurry", 3 }, { 2, "Improved Whirlwind", 2 }, { 2, "Bloodthirst", 1 },
                -- Tab 1 Arms (17 pts): Row 1 -> Row 2 -> Row 3 -> Row 4
                { 1, "Improved Heroic Strike", 3 }, { 1, "Improved Rend", 3 },
                { 1, "Improved Tactical Mastery", 3 }, { 1, "Improved Charge", 2 },
                { 1, "Anger Management", 1 }, { 1, "Deep Wounds", 3 },
                { 1, "Impale", 2 },
            },
        },
        {
            id = "prot_warr", label = "Protection Raid Tank (11/5/35)", role = "Tank",
            weapon = "Fast 1H Sword/Dagger + High-Armor Shield",
            priority = "Defense Cap (440) > Melee Hit Cap (8%) > Stamina > Dodge/Parry/Block",
            caps = { defense = 440, meleeHit = 8, critTarget = 12 },
            order = {
                -- Tab 3 Protection (35 pts): WoW Forever 16001 legal tier progression (5 pts/row)
                -- Row 1 (10 pts)
                { 3, "Shield Specialization", 5 }, { 3, "Improved Bloodrage", 2 }, { 3, "Iron Will", 3 },
                -- Row 2 (5 pts -> 15 total)
                { 3, "Anticipation", 5 },
                -- Row 3 (6 pts -> 21 total)
                { 3, "Last Stand", 1 }, { 3, "Defiance", 3 }, { 3, "Master of Defense", 2 },
                -- Row 4 (4 pts -> 25 total)
                { 3, "Improved Sunder Armor", 3 }, { 3, "Vanguard", 1 },
                -- Row 5 (4 pts -> 29 total)
                { 3, "Concussion Blow", 1 }, { 3, "Focused Rage", 3 },
                -- Row 6 (5 pts -> 34 total) & Row 7 (1 pt -> 35 total)
                { 3, "Bastion", 5 }, { 3, "Shield Slam", 1 },
                -- Tab 1 Arms (11 pts): Row 1 -> Row 2
                { 1, "Deflection", 5 }, { 1, "Improved Heroic Strike", 3 },
                { 1, "Improved Tactical Mastery", 3 },
                -- Tab 2 Fury (5 pts): Row 1
                { 2, "Cruelty", 5 },
            },
        },
    },
}

function TA:GetPlayerClassBuilds()
    local _, classToken = UnitClass("player")
    return TA.BUILDS[classToken or "WARRIOR"] or TA.BUILDS.WARRIOR, classToken or "WARRIOR"
end

function TA:GetActiveSpecGroup()
    if NS.PlanBuilder and NS.PlanBuilder.GetActiveSpecGroupSafe then
        return NS.PlanBuilder:GetActiveSpecGroupSafe()
    end
    if C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup then
        local ok, g = pcall(C_SpecializationInfo.GetActiveSpecGroup)
        if ok and type(g) == "number" and g >= 1 then return g end
    end
    if GetActiveSpecGroup then
        local ok, g = pcall(GetActiveSpecGroup)
        if ok and type(g) == "number" and g >= 1 then return g end
    end
    if GetActiveTalentGroup then
        local ok, g = pcall(GetActiveTalentGroup)
        if ok and type(g) == "number" and g >= 1 then return g end
    end
    return 1
end

function TA:PickBuildForPlanFocus(builds, specFocus)
    if not builds or #builds == 0 then return nil end
    local focus = string.lower(tostring(specFocus or "pve"))
    if focus == "pvp" then
        for _, b in ipairs(builds) do
            if string.lower(b.role or "") == "pvp" or string.find(string.lower(b.id or ""), "pvp", 1, true) then
                return b
            end
        end
    elseif focus == "raid" then
        for _, b in ipairs(builds) do
            local lbl = string.lower(b.label or "")
            if string.find(lbl, "raid", 1, true) or string.find(lbl, "pve", 1, true) then
                return b
            end
        end
    elseif focus == "pve" or focus == "meta" then
        for _, b in ipairs(builds) do
            if string.lower(b.role or "") ~= "pvp" then
                return b
            end
        end
    end
    return builds[1]
end

function TA:ApplyPlanFocus(specFocus, metaSource, groupNum)
    NS:EnsureDB()
    local builds = TA:GetPlayerClassBuilds()
    local picked = TA:PickBuildForPlanFocus(builds, specFocus)
    if not picked then return end
    local cKey = C.CanonicalCharKey(C.GetPlayerName() or "Player") or "player"
    local grp = tonumber(groupNum) or TA:GetActiveSpecGroup()
    WOWEngineDB.selectedSpecs[cKey .. ":" .. tostring(grp)] = picked.id
    if grp == 1 then
        WOWEngineDB.selectedSpecs[cKey] = picked.id
    end
    TA:UpdateTalentHighlight()
    if TA.fullTreeFrame and TA.fullTreeFrame:IsShown() then
        pcall(function() TA:RefreshFullTreePreview() end)
    end
    if NS.StatCapsUI and NS.StatCapsUI.Refresh then NS.StatCapsUI:Refresh() end
end

function TA:GetSelectedBuild(forGroup)
    NS:EnsureDB()
    local builds = TA:GetPlayerClassBuilds()
    local cKey = C.CanonicalCharKey(C.GetPlayerName() or "Player") or "player"
    local grp = tonumber(forGroup) or TA:GetActiveSpecGroup()
    local savedId = WOWEngineDB.selectedSpecs and (WOWEngineDB.selectedSpecs[cKey .. ":" .. tostring(grp)] or (grp == 1 and WOWEngineDB.selectedSpecs[cKey] or nil))
    if savedId then
        for _, b in ipairs(builds) do
            if b.id == savedId then return b end
        end
    end
    if NS.PlanBuilder and NS.PlanBuilder.GetPlanForGroup then
        local planFocus = NS.PlanBuilder:GetPlanForGroup(grp)
        if planFocus then
            return TA:PickBuildForPlanFocus(builds, planFocus) or builds[1]
        end
    end
    local planFocus = WOWEngineDB.userPlan and WOWEngineDB.userPlan.specFocus
    if planFocus then
        return TA:PickBuildForPlanFocus(builds, planFocus) or builds[1]
    end
    return builds[1]
end

function TA:CycleBuild(delta, forGroup)
    NS:EnsureDB()
    local builds = TA:GetPlayerClassBuilds()
    if #builds == 0 then return end
    local grp = tonumber(forGroup) or TA:GetActiveSpecGroup()
    local cur = TA:GetSelectedBuild(grp)
    local step = delta or 1
    local nextIdx = 1
    for i, b in ipairs(builds) do
        if b.id == cur.id then
            nextIdx = ((i - 1 + step) % #builds) + 1
            break
        end
    end
    local picked = builds[nextIdx]
    local cKey = C.CanonicalCharKey(C.GetPlayerName() or "Player") or "player"
    WOWEngineDB.selectedSpecs[cKey .. ":" .. tostring(grp)] = picked.id
    if grp == 1 then
        WOWEngineDB.selectedSpecs[cKey] = picked.id
    end
    NS:Print("Selected Spec Pre-Load (Group " .. tostring(grp) .. "): |cffffd100" .. picked.label .. "|r (" .. picked.role .. ")")
    TA:UpdateTalentHighlight()
    if TA.fullTreeFrame and TA.fullTreeFrame:IsShown() then
        pcall(function() TA:RefreshFullTreePreview() end)
    end
    if NS.StatCapsUI and NS.StatCapsUI.Refresh then NS.StatCapsUI:Refresh() end
end

function TA:PrevBuild()
    return TA:CycleBuild(-1)
end

function TA:NextBuild()
    return TA:CycleBuild(1)
end

-- Dynamically resolve the active Blizzard talent window across Classic & Modern clients
function TA:GetTalentParentFrame()
    return _G.PlayerSpellsFrame or _G.PlayerTalentFrame or _G.TalentFrame or _G.ClassTalentFrame
end

local function GetSpellNameSafe(spellID)
    if not spellID then return nil end
    local name = nil
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, spellID)
        if ok and n then name = n end
    end
    if not name and GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, spellID)
        if ok and n then name = n end
    end
    if name and C and C.IsSecret and C.IsSecret(name) then
        return nil
    end
    return name
end

local function AddUniqueName(list, seen, rawName)
    if not rawName or type(rawName) ~= "string" or rawName == "" then return end
    if C and C.IsSecret and C.IsSecret(rawName) then return end
    if not seen[rawName] then
        seen[rawName] = true
        table.insert(list, rawName)
    end
end

local function GetNodeNames(configID, nodeInfo)
    local names, seen = {}, {}
    if type(nodeInfo) ~= "table" then return names end

    local function addEntry(entryID)
        if not entryID or not configID or not C_Traits or not C_Traits.GetEntryInfo then return end
        local okE, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
        if okE and type(entryInfo) == "table" and entryInfo.definitionID and C_Traits.GetDefinitionInfo then
            local okD, defInfo = pcall(C_Traits.GetDefinitionInfo, entryInfo.definitionID)
            if okD and type(defInfo) == "table" then
                AddUniqueName(names, seen, defInfo.overrideName)
                if defInfo.spellID then
                    AddUniqueName(names, seen, GetSpellNameSafe(defInfo.spellID))
                end
            end
        end
    end

    if type(nodeInfo.activeEntry) == "table" and nodeInfo.activeEntry.entryID then
        addEntry(nodeInfo.activeEntry.entryID)
    end
    if type(nodeInfo.entryIDs) == "table" then
        for _, eid in ipairs(nodeInfo.entryIDs) do
            addEntry(eid)
        end
    end
    return names
end

local function GetActiveTraitConfigID(talentsFrame)
    if talentsFrame and talentsFrame.GetConfigID then
        local okC, cid = pcall(talentsFrame.GetConfigID, talentsFrame)
        if okC and cid then return cid end
    end
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        local okC, cid = pcall(C_ClassTalents.GetActiveConfigID)
        if okC and cid then return cid end
    end
    return nil
end

local function CollectModernTalentButtons(talentsFrame)
    local buttons, seen = {}, {}
    if not talentsFrame then return buttons end

    if talentsFrame.EnumerateAllTalentButtons then
        pcall(function()
            for btn in talentsFrame:EnumerateAllTalentButtons() do
                if btn and not seen[btn] then
                    seen[btn] = true
                    table.insert(buttons, btn)
                end
            end
        end)
    end
    if #buttons == 0 and type(talentsFrame.nodeIDToButton) == "table" then
        for _, btn in pairs(talentsFrame.nodeIDToButton) do
            if btn and not seen[btn] then
                seen[btn] = true
                table.insert(buttons, btn)
            end
        end
    end
    if #buttons == 0 and talentsFrame.talentButtonCollection and talentsFrame.talentButtonCollection.EnumerateActive then
        pcall(function()
            for btn in talentsFrame.talentButtonCollection:EnumerateActive() do
                if btn and not seen[btn] then
                    seen[btn] = true
                    table.insert(buttons, btn)
                end
            end
        end)
    end
    if #buttons == 0 then
        local container = talentsFrame.ButtonsParent or talentsFrame
        if container and container.GetChildren then
            local okCh, children = pcall(function() return { container:GetChildren() } end)
            if okCh and type(children) == "table" then
                for _, child in ipairs(children) do
                    if child and not seen[child] and (child.GetNodeInfo or child.GetNodeID or child.GetSpellID or child.nodeInfo) then
                        seen[child] = true
                        table.insert(buttons, child)
                    end
                end
            end
        end
    end
    return buttons
end

local function GetButtonTalentMeta(btn, talentsFrame)
    local names, seen = {}, {}
    if not btn then return names, nil, nil end

    if btn.GetSpellID then
        local okS, sid = pcall(btn.GetSpellID, btn)
        if okS and sid then
            AddUniqueName(names, seen, GetSpellNameSafe(sid))
        end
    end
    if btn.GetTalentName then
        local okN, n = pcall(btn.GetTalentName, btn)
        if okN then AddUniqueName(names, seen, n) end
    end

    local nodeInfo = nil
    if btn.GetNodeInfo then
        local okNI, ni = pcall(btn.GetNodeInfo, btn)
        if okNI and type(ni) == "table" then nodeInfo = ni end
    end
    if not nodeInfo and type(btn.nodeInfo) == "table" then
        nodeInfo = btn.nodeInfo
    end

    local nodeID = nil
    if btn.GetNodeID then
        local okID, id = pcall(btn.GetNodeID, btn)
        if okID and id then nodeID = id end
    end
    if not nodeID and nodeInfo and nodeInfo.ID then
        nodeID = nodeInfo.ID
    end
    if not nodeID and btn.nodeID then
        nodeID = btn.nodeID
    end

    local configID = GetActiveTraitConfigID(talentsFrame)
    if not nodeInfo and configID and nodeID and C_Traits and C_Traits.GetNodeInfo then
        local okNI, ni = pcall(C_Traits.GetNodeInfo, configID, nodeID)
        if okNI and type(ni) == "table" then nodeInfo = ni end
    end

    if nodeInfo then
        for _, n in ipairs(GetNodeNames(configID, nodeInfo)) do
            AddUniqueName(names, seen, n)
        end
    end

    if type(btn.entryInfo) == "table" and btn.entryInfo.definitionID and C_Traits and C_Traits.GetDefinitionInfo then
        local okD, defInfo = pcall(C_Traits.GetDefinitionInfo, btn.entryInfo.definitionID)
        if okD and type(defInfo) == "table" then
            AddUniqueName(names, seen, defInfo.overrideName)
            if defInfo.spellID then
                AddUniqueName(names, seen, GetSpellNameSafe(defInfo.spellID))
            end
        end
    end

    return names, nodeID, nodeInfo
end

-- Snapshot a Classic talent tab with exact tier, column, rank, maxRank, pointsSpent, and prerequisite arrows
local function SnapshotClassicTab(tabIdx)
    if not GetNumTalents or not GetTalentInfo then return nil end
    local okN, numTalents = pcall(GetNumTalents, tabIdx)
    if not okN or type(numTalents) ~= "number" or numTalents <= 0 then
        return nil
    end

    local talents = {}
    local byGrid = {}
    local pointsSpent = 0

    for tIdx = 1, numTalents do
        local okT, tName, iconTex, tier, col, curRank, maxRank, _, available = pcall(GetTalentInfo, tabIdx, tIdx)
        if okT and tName and not (C and C.IsSecret and C.IsSecret(tName)) then
            local r = tonumber(curRank) or 0
            local m = tonumber(maxRank) or 1
            local tr = tonumber(tier) or 1
            local cl = tonumber(col) or 1
            pointsSpent = pointsSpent + r

            local prereqs = {}
            if GetTalentPrereqs then
                local okP, p1, p2, p3, p4, p5, p6, p7, p8, p9 = pcall(GetTalentPrereqs, tabIdx, tIdx)
                if okP then
                    local raw = { p1, p2, p3, p4, p5, p6, p7, p8, p9 }
                    for i = 1, #raw, 3 do
                        local reqTier, reqCol = tonumber(raw[i]), tonumber(raw[i + 1])
                        if reqTier and reqCol then
                            table.insert(prereqs, { tier = reqTier, col = reqCol })
                        end
                    end
                end
            end

            local entry = {
                tab = tabIdx,
                index = tIdx,
                name = tName,
                icon = iconTex,
                lower = string.lower(tName),
                tier = tr,
                col = cl,
                curRank = r,
                maxRank = m,
                available = available,
                prereqs = prereqs,
            }
            table.insert(talents, entry)
            byGrid[tr .. ":" .. cl] = entry
        end
    end

    local bgFile = nil
    if GetTalentTabInfo then
        local okTab, r1, r2, r3, r4, r5, r6 = pcall(GetTalentTabInfo, tabIdx)
        if okTab then
            -- Classic: (name, icon, pointsSpent, fileName); Cata/MoP: (id, name, desc, icon, pointsSpent, bg, ...)
            if type(r4) == "string" and r4 ~= "" and not string.find(r4, "\\") and not string.find(r4, "/") then
                bgFile = r4
            elseif type(r6) == "string" and r6 ~= "" then
                bgFile = r6
            end
        end
    end

    return {
        tab = tabIdx,
        talents = talents,
        byGrid = byGrid,
        pointsSpent = pointsSpent,
        bgFile = bgFile,
    }
end

local function MatchClassicTalentByName(tabSnap, wantName)
    if not tabSnap or not wantName then return nil end
    local wantLow = string.lower(wantName)
    local partial = nil
    for _, t in ipairs(tabSnap.talents) do
        if t.lower == wantLow then
            return t
        elseif not partial and string.find(t.lower, wantLow, 1, true) then
            partial = t
        end
    end
    return partial
end

local function AreClassicPrereqsMet(tabSnap, talent)
    if not tabSnap or not talent then return false, nil end
    for _, pr in ipairs(talent.prereqs or {}) do
        local req = tabSnap.byGrid[pr.tier .. ":" .. pr.col]
        if req and req.curRank < req.maxRank then
            return false, req
        end
    end
    return true, nil
end

local function IsClassicTalentUnlocked(tabSnap, talent)
    if not tabSnap or not talent then return false, "missing", nil end
    if talent.curRank >= talent.maxRank then return false, "maxed", nil end
    local reqPoints = (math.max(1, talent.tier) - 1) * 5
    if tabSnap.pointsSpent < reqPoints then
        return false, "tier", reqPoints
    end
    local prereqOk, missingPrereq = AreClassicPrereqsMet(tabSnap, talent)
    if not prereqOk then
        return false, "prereq", missingPrereq
    end
    return true, nil, nil
end

local function IsModernNodeUnlocked(configID, nodeInfo)
    if type(nodeInfo) ~= "table" then return false end
    if nodeInfo.isVisible == false then return false end
    local cur = nodeInfo.activeRank or nodeInfo.currentRank or nodeInfo.ranksPurchased or 0
    local maxR = nodeInfo.maxRanks or 1
    if cur >= maxR then return false end
    if nodeInfo.canPurchaseRank == true then return true end
    if nodeInfo.meetsEdgeRequirements == false then return false end
    if configID and type(nodeInfo.conditionIDs) == "table" and C_Traits and C_Traits.GetConditionInfo then
        for _, cid in ipairs(nodeInfo.conditionIDs) do
            local okC, cInfo = pcall(C_Traits.GetConditionInfo, configID, cid)
            if okC and type(cInfo) == "table" and cInfo.isMet == false then
                return false
            end
        end
    end
    return true
end

local function ClusterSortedCoords(vals, tol)
    local centers = {}
    if #vals == 0 then return centers end
    table.sort(vals)
    local sum, cnt = vals[1], 1
    for i = 2, #vals do
        if (vals[i] - (sum / cnt)) <= tol then
            sum = sum + vals[i]
            cnt = cnt + 1
        else
            table.insert(centers, sum / cnt)
            sum, cnt = vals[i], 1
        end
    end
    table.insert(centers, sum / cnt)
    return centers
end

local function AssignModernNodeTiers(nodes)
    if not nodes or #nodes == 0 then return end

    -- Group nodes by treeID first
    local byTreeID = {}
    local treeOrder = {}
    for _, node in ipairs(nodes) do
        local tid = tonumber(node.treeID) or 0
        if not byTreeID[tid] then
            byTreeID[tid] = {}
            table.insert(treeOrder, tid)
        end
        table.insert(byTreeID[tid], node)
    end
    table.sort(treeOrder)

    -- Split each treeID into visual trees (by subTreeID if present, else by posX horizontal bands)
    local visualTrees = {}
    for _, tid in ipairs(treeOrder) do
        local list = byTreeID[tid]
        local subMap, subOrder = {}, {}
        for _, n in ipairs(list) do
            local st = (n.nodeInfo and tonumber(n.nodeInfo.subTreeID)) or 0
            if st > 0 then
                if not subMap[st] then
                    subMap[st] = { nodes = {}, minX = 999999 }
                    table.insert(subOrder, st)
                end
                table.insert(subMap[st].nodes, n)
                if n.posX and n.posX < subMap[st].minX then subMap[st].minX = n.posX end
            end
        end

        if #subOrder >= 2 then
            table.sort(subOrder, function(a, b) return subMap[a].minX < subMap[b].minX end)
            for _, st in ipairs(subOrder) do
                table.insert(visualTrees, subMap[st].nodes)
            end
            local unassigned = {}
            for _, n in ipairs(list) do
                local st = (n.nodeInfo and tonumber(n.nodeInfo.subTreeID)) or 0
                if st <= 0 then table.insert(unassigned, n) end
            end
            if #unassigned > 0 then table.insert(visualTrees, unassigned) end
        else
            -- Cluster by posX gaps to separate side-by-side Classic trees (e.g. BM / MM / Survival)
            local validX = {}
            for _, n in ipairs(list) do
                if n.posX and n.posX < 99990 then table.insert(validX, n.posX) end
            end
            if #validX > 0 then
                table.sort(validX)
                local xSpan = validX[#validX] - validX[1]
                local xTol = (xSpan <= 50) and 0.4 or math.max(10, xSpan * 0.015)
                local xCenters = ClusterSortedCoords(validX, xTol)

                local gaps = {}
                for i = 1, #xCenters - 1 do
                    local g = xCenters[i + 1] - xCenters[i]
                    if g > 0 then table.insert(gaps, g) end
                end
                local colStep = 0
                if #gaps > 0 then
                    table.sort(gaps)
                    colStep = gaps[math.max(1, math.floor(#gaps * 0.25))]
                end

                local bandSplits = {}
                if colStep > 0 then
                    for i = 1, #xCenters - 1 do
                        if (xCenters[i + 1] - xCenters[i]) > (colStep * 1.65) then
                            table.insert(bandSplits, (xCenters[i] + xCenters[i + 1]) * 0.5)
                        end
                    end
                end

                local bands = {}
                local numBands = #bandSplits + 1
                for b = 1, numBands do bands[b] = {} end
                for _, n in ipairs(list) do
                    local bIdx = 1
                    if n.posX and n.posX < 99990 then
                        for _, splitX in ipairs(bandSplits) do
                            if n.posX > splitX then bIdx = bIdx + 1 end
                        end
                    end
                    table.insert(bands[bIdx], n)
                end
                for b = 1, numBands do
                    if #bands[b] > 0 then table.insert(visualTrees, bands[b]) end
                end
            else
                table.insert(visualTrees, list)
            end
        end
    end

    -- Assign simTreeIdx, simTreeKey, simTier (Row 1..N from posY), and simCol (Col 1..N from posX)
    for tIdx, tNodes in ipairs(visualTrees) do
        local validY, validX = {}, {}
        for _, n in ipairs(tNodes) do
            if n.posY and n.posY < 99990 then table.insert(validY, n.posY) end
            if n.posX and n.posX < 99990 then table.insert(validX, n.posX) end
        end

        local yCenters, rowStep = {}, 0
        if #validY > 0 then
            table.sort(validY)
            local ySpan = validY[#validY] - validY[1]
            local yTol = (ySpan <= 50) and 0.4 or math.max(10, ySpan * 0.03)
            yCenters = ClusterSortedCoords(validY, yTol)
            local yGaps = {}
            for i = 1, #yCenters - 1 do
                local g = yCenters[i + 1] - yCenters[i]
                if g > 0 then table.insert(yGaps, g) end
            end
            if #yGaps > 0 then
                table.sort(yGaps)
                rowStep = yGaps[math.max(1, math.floor(#yGaps * 0.25))]
            end
        end

        local xCenters, colStep = {}, 0
        if #validX > 0 then
            table.sort(validX)
            local xSpan = validX[#validX] - validX[1]
            local xTol = (xSpan <= 50) and 0.4 or math.max(10, xSpan * 0.03)
            xCenters = ClusterSortedCoords(validX, xTol)
            local xGaps = {}
            for i = 1, #xCenters - 1 do
                local g = xCenters[i + 1] - xCenters[i]
                if g > 0 then table.insert(xGaps, g) end
            end
            if #xGaps > 0 then
                table.sort(xGaps)
                colStep = xGaps[math.max(1, math.floor(#xGaps * 0.25))]
            end
        end

        for _, n in ipairs(tNodes) do
            n.simTreeIdx = tIdx
            n.simTreeKey = "tree:" .. tostring(tIdx)
            if n.posY and n.posY < 99990 and #yCenters > 0 then
                if rowStep > 0 then
                    n.simTier = math.max(1, math.floor(((n.posY - yCenters[1]) / rowStep) + 0.5) + 1)
                else
                    n.simTier = 1
                end
            else
                n.simTier = 1
            end
            if n.posX and n.posX < 99990 and #xCenters > 0 then
                if colStep > 0 then
                    n.simCol = math.max(1, math.floor(((n.posX - xCenters[1]) / colStep) + 0.5) + 1)
                else
                    n.simCol = 1
                end
            else
                n.simCol = 1
            end
        end
    end
end

local function CollectModernTreeSnapshot()
    local parent = TA:GetTalentParentFrame()
    local talentsFrame = parent and parent.TalentsFrame
    local configID = GetActiveTraitConfigID(talentsFrame)

    local nodes = {}
    local seenNodes = {}

    if configID and C_Traits and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo then
        local treeIDs = {}
        local seenTrees = {}
        if talentsFrame and talentsFrame.GetTalentTreeID then
            local okT, tid = pcall(talentsFrame.GetTalentTreeID, talentsFrame)
            if okT and tid and not seenTrees[tid] then
                seenTrees[tid] = true
                table.insert(treeIDs, tid)
            end
        end
        if C_Traits.GetConfigInfo then
            local okCI, cfg = pcall(C_Traits.GetConfigInfo, configID)
            if okCI and type(cfg) == "table" and type(cfg.treeIDs) == "table" then
                for _, tid in ipairs(cfg.treeIDs) do
                    if tid and not seenTrees[tid] then
                        seenTrees[tid] = true
                        table.insert(treeIDs, tid)
                    end
                end
            end
        end

        for _, tid in ipairs(treeIDs) do
            local okNodes, nodeIDs = pcall(C_Traits.GetTreeNodes, tid)
            if okNodes and type(nodeIDs) == "table" then
                for _, nodeID in ipairs(nodeIDs) do
                    if nodeID and not seenNodes[nodeID] then
                        local okNI, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                        if okNI and type(nodeInfo) == "table" and nodeInfo.isVisible ~= false then
                            local names = GetNodeNames(configID, nodeInfo)
                            if #names > 0 then
                                seenNodes[nodeID] = true
                                table.insert(nodes, {
                                    treeID = tid,
                                    nodeID = nodeID,
                                    names = names,
                                    curRank = nodeInfo.activeRank or nodeInfo.currentRank or nodeInfo.ranksPurchased or 0,
                                    maxRank = nodeInfo.maxRanks or 1,
                                    posY = tonumber(nodeInfo.posY) or 99999,
                                    posX = tonumber(nodeInfo.posX) or 99999,
                                    unlocked = IsModernNodeUnlocked(configID, nodeInfo),
                                    nodeInfo = nodeInfo,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    if #nodes == 0 and talentsFrame then
        for _, btn in ipairs(CollectModernTalentButtons(talentsFrame)) do
            local names, nodeID, nodeInfo = GetButtonTalentMeta(btn, talentsFrame)
            local key = nodeID or btn
            if #names > 0 and not seenNodes[key] then
                seenNodes[key] = true
                local unlocked = nodeInfo and IsModernNodeUnlocked(configID, nodeInfo) or true
                table.insert(nodes, {
                    treeID = 0,
                    nodeID = nodeID,
                    names = names,
                    curRank = (nodeInfo and (nodeInfo.activeRank or nodeInfo.currentRank or nodeInfo.ranksPurchased)) or 0,
                    maxRank = (nodeInfo and nodeInfo.maxRanks) or 1,
                    posY = (nodeInfo and tonumber(nodeInfo.posY)) or 99999,
                    posX = (nodeInfo and tonumber(nodeInfo.posX)) or 99999,
                    unlocked = unlocked,
                    nodeInfo = nodeInfo,
                })
            end
        end
    end

    AssignModernNodeTiers(nodes)
    return nodes
end

local function MatchModernNodeByName(nodes, wantName, preferredTreeIdx)
    if not nodes or not wantName then return nil, nil end
    local wantLow = string.lower(wantName)
    local exactAnyNode, exactAnyName = nil, nil
    local partialPrefNode, partialPrefName = nil, nil
    local partialAnyNode, partialAnyName = nil, nil
    for _, node in ipairs(nodes) do
        local isPref = (preferredTreeIdx ~= nil and node.simTreeIdx == preferredTreeIdx)
        for _, n in ipairs(node.names) do
            local low = string.lower(n)
            if low == wantLow then
                if isPref or not preferredTreeIdx then
                    return node, n
                elseif not exactAnyNode then
                    exactAnyNode, exactAnyName = node, n
                end
            elseif string.find(low, wantLow, 1, true) then
                if isPref and not partialPrefNode then
                    partialPrefNode, partialPrefName = node, n
                elseif not partialAnyNode then
                    partialAnyNode, partialAnyName = node, n
                end
            end
        end
    end
    if exactAnyNode then return exactAnyNode, exactAnyName end
    if partialPrefNode then return partialPrefNode, partialPrefName end
    return partialAnyNode, partialAnyName
end

local function FindModernRecommendedTalent(build)
    local nodes = CollectModernTreeSnapshot()
    if #nodes == 0 then return nil end

    local sawLockedNeed = false
    local firstLockedTreeKey = nil
    local firstLockedTab = 1
    for stepIdx, step in ipairs(build.order) do
        local tabIdx, wantName, wantRank = step[1], step[2], step[3]
        local node, matchedName = MatchModernNodeByName(nodes, wantName, tabIdx)
        if node then
            local target = math.min(wantRank or node.maxRank or 1, node.maxRank or 1)
            if (node.curRank or 0) < target then
                if node.unlocked then
                    return {
                        tab = tabIdx,
                        nodeID = node.nodeID,
                        name = matchedName or node.names[1],
                        curRank = node.curRank or 0,
                        targetRank = target,
                        stepNum = stepIdx,
                        source = "modern",
                    }
                else
                    if not sawLockedNeed then
                        sawLockedNeed = true
                        firstLockedTreeKey = node.simTreeKey
                        firstLockedTab = tabIdx or 1
                    end
                end
            end
        end
    end

    -- Fallback: if desired build node is locked by row/gate requirements, pick highest-priority unlocked lower-row node in the SAME tree first
    if sawLockedNeed then
        local function pickBest(sameTreeOnly)
            local best = nil
            for _, node in ipairs(nodes) do
                if node.unlocked and (node.curRank or 0) < (node.maxRank or 1) then
                    if not sameTreeOnly or (firstLockedTreeKey and node.simTreeKey == firstLockedTreeKey) then
                        if not best
                            or (node.simTier or 99) < (best.simTier or 99)
                            or ((node.simTier or 99) == (best.simTier or 99) and node.posY < best.posY)
                            or ((node.simTier or 99) == (best.simTier or 99) and node.posY == best.posY and node.posX < best.posX) then
                            best = node
                        end
                    end
                end
            end
            return best
        end

        local bestFallback = pickBest(true) or pickBest(false)
        if bestFallback then
            return {
                tab = firstLockedTab,
                nodeID = bestFallback.nodeID,
                name = bestFallback.names[1],
                curRank = bestFallback.curRank or 0,
                targetRank = bestFallback.maxRank or 1,
                stepNum = 0,
                source = "modern",
                isFallback = true,
            }
        end
    end
    return nil
end

-- Determine next recommended talent button based on LIVE tree existence, tier unlock, and prerequisites
function TA:FindNextRecommendedTalent()
    local build = TA:GetSelectedBuild()
    if not build or not build.order then
        return nil, build
    end

    -- Classic / WoW Forever 3-tab talent API path
    if GetNumTalents and GetTalentInfo then
        local tabSnaps = {}
        local sawAnyClassicTalents = false
        for tabIdx = 1, 3 do
            local snap = SnapshotClassicTab(tabIdx)
            if snap then
                tabSnaps[tabIdx] = snap
                sawAnyClassicTalents = true
            end
        end

        if sawAnyClassicTalents then
            local firstLockedTab = nil
            local firstLockedTier = nil

            for stepIdx, step in ipairs(build.order) do
                local tabIdx, wantName, wantRank = step[1], step[2], step[3]
                local snap = tabSnaps[tabIdx]
                if snap then
                    local t = MatchClassicTalentByName(snap, wantName)
                    if t then
                        local target = math.min(wantRank or t.maxRank or 1, t.maxRank or 1)
                        if t.curRank < target then
                            local unlocked, reason, detail = IsClassicTalentUnlocked(snap, t)
                            if unlocked then
                                return {
                                    tab = tabIdx,
                                    index = t.index,
                                    name = t.name,
                                    curRank = t.curRank,
                                    targetRank = target,
                                    tier = t.tier,
                                    stepNum = stepIdx,
                                    source = "classic",
                                }, build
                            elseif reason == "prereq" and detail then
                                -- If locked by a prerequisite arrow whose own tier is unlocked, recommend that prerequisite!
                                local prUnlocked = IsClassicTalentUnlocked(snap, detail)
                                if prUnlocked then
                                    return {
                                        tab = tabIdx,
                                        index = detail.index,
                                        name = detail.name,
                                        curRank = detail.curRank,
                                        targetRank = detail.maxRank,
                                        tier = detail.tier,
                                        stepNum = stepIdx,
                                        source = "classic",
                                        isFallback = true,
                                    }, build
                                end
                            end

                            if not firstLockedTab then
                                firstLockedTab = tabIdx
                                firstLockedTier = t.tier
                            end
                        end
                    end
                end
            end

            -- Fallback: desired build step is in a locked tier -> pick highest-priority UNLOCKED lower-tier talent
            -- in the SAME tab (Row 1 / Row 2) to legally advance pointsSpent toward (tier - 1) * 5!
            if firstLockedTab and tabSnaps[firstLockedTab] then
                local snap = tabSnaps[firstLockedTab]
                local bestFallback = nil
                for _, t in ipairs(snap.talents) do
                    if t.tier < (firstLockedTier or 99) then
                        local unlocked = IsClassicTalentUnlocked(snap, t)
                        if unlocked then
                            if not bestFallback
                                or t.tier < bestFallback.tier
                                or (t.tier == bestFallback.tier and t.maxRank > bestFallback.maxRank)
                                or (t.tier == bestFallback.tier and t.maxRank == bestFallback.maxRank and t.col < bestFallback.col) then
                                bestFallback = t
                            end
                        end
                    end
                end
                if bestFallback then
                    return {
                        tab = firstLockedTab,
                        index = bestFallback.index,
                        name = bestFallback.name,
                        curRank = bestFallback.curRank,
                        targetRank = bestFallback.maxRank,
                        tier = bestFallback.tier,
                        stepNum = 0,
                        source = "classic",
                        isFallback = true,
                    }, build
                end
            end

            return nil, build
        end
    end

    -- Modern PlayerSpellsFrame / C_Traits talent tree path
    local modernPick = FindModernRecommendedTalent(build)
    if modernPick then
        return modernPick, build
    end

    return nil, build
end

local function GetClassicTabName(tabIdx)
    if GetTalentTabInfo then
        local ok, r1, r2 = pcall(GetTalentTabInfo, tabIdx)
        if ok then
            if type(r1) == "string" and r1 ~= "" and not (C and C.IsSecret and C.IsSecret(r1)) then
                return r1
            elseif type(r2) == "string" and r2 ~= "" and not (C and C.IsSecret and C.IsSecret(r2)) then
                return r2
            end
        end
    end
    return "Tab " .. tostring(tabIdx)
end

-- Scrollable, copyable Blizzard blue-and-gold popup window (matches /he bug EditBox style)
function TA:ShowAuditReportPopup(reportText, classToken)
    if not TA.auditFrame then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local f = CreateFrame("Frame", "WOWEngineTalentAuditFrame", UIParent, template)
        f:SetSize(580, 460)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(150)
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
                f:SetBackdropColor(0.04, 0.09, 0.19, 0.97)
                f:SetBackdropBorderColor(0.95, 0.78, 0.18, 1.0)
            end)
        end

        if UISpecialFrames then
            table.insert(UISpecialFrames, "WOWEngineTalentAuditFrame")
        end

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 14, -12)
        f.title = title

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        hint:SetText("|cffffd100All text is pre-selected — press Ctrl+C to copy both the audit mismatches and full live talent tree dump:|r")

        local scroll = CreateFrame("ScrollFrame", "WOWEngineTalentAuditScroll", f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 14, -56)
        scroll:SetPoint("BOTTOMRIGHT", -34, 46)

        local editBox = CreateFrame("EditBox", "WOWEngineTalentAuditEditBox", scroll)
        editBox:SetMultiLine(true)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetWidth(520)
        editBox:SetHeight(340)
        editBox:SetAutoFocus(false)
        editBox:SetScript("OnEscapePressed", function() f:Hide() end)
        editBox:SetScript("OnTextChanged", function()
            pcall(function()
                if scroll and scroll.UpdateScrollChildRect then
                    scroll:UpdateScrollChildRect()
                end
            end)
        end)
        scroll:SetScrollChild(editBox)
        f.editBox = editBox

        local selectBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        selectBtn:SetSize(156, 24)
        selectBtn:SetPoint("BOTTOMLEFT", 14, 12)
        selectBtn:SetText("Select All (Ctrl+C)")
        selectBtn:SetScript("OnClick", function()
            pcall(function()
                f.editBox:SetFocus()
                f.editBox:HighlightText()
            end)
        end)

        local doneBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        doneBtn:SetSize(84, 24)
        doneBtn:SetPoint("BOTTOMRIGHT", -14, 12)
        doneBtn:SetText("Close")
        doneBtn:SetScript("OnClick", function() f:Hide() end)

        TA.auditFrame = f
    end

    TA.auditFrame.title:SetText("|cff00aeffWOWEngine|r |cffffd100Talent Tree Audit & Dump (" .. tostring(classToken or "?") .. ")|r")
    pcall(function() TA.auditFrame.editBox:SetText(tostring(reportText or "")) end)
    TA.auditFrame:Show()
    TA.auditFrame:Raise()
    pcall(function()
        TA.auditFrame.editBox:SetFocus()
        TA.auditFrame.editBox:HighlightText()
    end)
end

-- Live Tree Audit Command (/he talent audit): checks every saved build for current class against live client tree
-- Prints summary to chat AND opens a copyable popup with (1) Audit Mismatches and (2) Full Live Client Talent Tree Dump
function TA:AuditClassBuilds()
    local builds, classToken = TA:GetPlayerClassBuilds()
    NS:Print("=== WOWEngine Live Talent Tree Audit (" .. tostring(classToken or "?") .. ") ===")

    local ver, buildNum, _, iface = "?", "?", "?", "?"
    if GetBuildInfo then
        local okB, v, b, bd, i = pcall(GetBuildInfo)
        if okB then ver, buildNum, _, iface = v or "?", b or "?", bd or "?", i or "?" end
    end

    local reportLines = {
        "=== WOWEngine Live Talent Tree Audit (" .. tostring(classToken or "?") .. ") ===",
        string.format("Character: %s (Lv%d %s) | Client: %s (%s) | Interface: %s",
            tostring(C.GetPlayerName() or "Player"), tonumber(UnitLevel and UnitLevel("player")) or 0,
            tostring(classToken or "?"), tostring(ver), tostring(buildNum), tostring(iface)),
        "",
        "=== SECTION 1: BUILD AUDIT MISMATCHES ===",
    }

    -- 1. Classic / WoW Forever 3-tab audit
    local tabSnaps = {}
    local hasClassic = false
    if GetNumTalents and GetTalentInfo then
        for tabIdx = 1, 3 do
            local snap = SnapshotClassicTab(tabIdx)
            if snap then
                tabSnaps[tabIdx] = snap
                hasClassic = true
            end
        end
    end

    if hasClassic then
        for _, build in ipairs(builds) do
            local simTabPoints = { [1] = 0, [2] = 0, [3] = 0 }
            local simRanks = {}
            local missingIssues = {}
            local lockedIssues = {}

            for stepIdx, step in ipairs(build.order or {}) do
                local tabIdx, wantName, wantRank = step[1], step[2], step[3]
                local snap = tabSnaps[tabIdx]
                local t = snap and MatchClassicTalentByName(snap, wantName) or nil
                if not t then
                    table.insert(missingIssues, string.format("Step #%d (Tab %d): '%s' does NOT exist in live client", stepIdx, tabIdx or 0, tostring(wantName)))
                else
                    local reqPts = (math.max(1, t.tier) - 1) * 5
                    local curTabPts = simTabPoints[tabIdx] or 0
                    if curTabPts < reqPts then
                        table.insert(lockedIssues, string.format("Step #%d (Tab %d): '%s' is Row %d (needs %d pts, only %d spent so far)", stepIdx, tabIdx, t.name, t.tier, reqPts, curTabPts))
                    end
                    for _, pr in ipairs(t.prereqs or {}) do
                        local req = snap.byGrid[pr.tier .. ":" .. pr.col]
                        if req then
                            local rKey = tabIdx .. ":" .. req.index
                            if (simRanks[rKey] or 0) < req.maxRank then
                                table.insert(lockedIssues, string.format("Step #%d (Tab %d): '%s' missing maxed prereq '%s'", stepIdx, tabIdx, t.name, req.name))
                            end
                        end
                    end
                    local key = tabIdx .. ":" .. t.index
                    local prevSim = simRanks[key] or 0
                    local target = math.min(wantRank or t.maxRank or 1, t.maxRank or 1)
                    local added = math.max(0, target - prevSim)
                    simRanks[key] = prevSim + added
                    simTabPoints[tabIdx] = curTabPts + added
                end
            end

            if #missingIssues == 0 and #lockedIssues == 0 then
                local passLine = string.format("[PASS] %s — All %d steps exist & pass (tier-1)*5 and prereq checks.", build.label, #(build.order or {}))
                NS:Print("  |cff00ff00[PASS]|r |cffffd100" .. build.label .. "|r — All " .. tostring(#(build.order or {})) .. " steps exist & pass (tier-1)*5 and prereq checks.")
                table.insert(reportLines, passLine)
            else
                NS:Print(string.format("  |cffff5555[ISSUES]|r |cffffd100%s|r — %d missing, %d locked-tier/prereq issue(s):", build.label, #missingIssues, #lockedIssues))
                table.insert(reportLines, string.format("[ISSUES] %s — %d missing, %d locked-tier/prereq issue(s):", build.label, #missingIssues, #lockedIssues))
                for _, m in ipairs(missingIssues) do
                    NS:Print("    |cffff5555MISSING:|r " .. m)
                    table.insert(reportLines, "  MISSING: " .. m)
                end
                for _, l in ipairs(lockedIssues) do
                    NS:Print("    |cffff9900LOCKED:|r " .. l)
                    table.insert(reportLines, "  LOCKED: " .. l)
                end
            end
        end

        -- Section 2: Full dump of live client's Classic / WoW Forever talent tree
        table.insert(reportLines, "")
        table.insert(reportLines, "=== SECTION 2: LIVE CLIENT TALENT TREE DUMP ===")
        for tabIdx = 1, 3 do
            local snap = tabSnaps[tabIdx]
            if snap then
                local tabName = GetClassicTabName(tabIdx)
                table.insert(reportLines, string.format("-- Tab %d: %s (%d talents | %d pts spent) --",
                    tabIdx, tabName, #snap.talents, snap.pointsSpent or 0))
                local sorted = {}
                for _, t in ipairs(snap.talents) do table.insert(sorted, t) end
                table.sort(sorted, function(a, b)
                    if a.tier ~= b.tier then return a.tier < b.tier end
                    if a.col ~= b.col then return a.col < b.col end
                    return (a.index or 0) < (b.index or 0)
                end)
                for _, t in ipairs(sorted) do
                    local prereqNote = ""
                    if t.prereqs and #t.prereqs > 0 then
                        local pParts = {}
                        for _, pr in ipairs(t.prereqs) do
                            local req = snap.byGrid[pr.tier .. ":" .. pr.col]
                            table.insert(pParts, string.format("R%dC%d(%s)", pr.tier, pr.col, req and req.name or "?"))
                        end
                        prereqNote = " | Prereq: " .. table.concat(pParts, ", ")
                    end
                    table.insert(reportLines, string.format("Tab %d (%s) | Row %d | Col %d | %s | MaxRank %d (Cur %d)%s",
                        tabIdx, tabName, t.tier, t.col, t.name, t.maxRank, t.curRank, prereqNote))
                end
                table.insert(reportLines, "")
            end
        end

        TA:ShowAuditReportPopup(table.concat(reportLines, "\n"), classToken)
        return
    end

    -- 2. Modern C_Traits tree audit fallback
    local modernNodes = CollectModernTreeSnapshot()
    if #modernNodes == 0 then
        NS:Print("|cffff9900Talent tree data not loaded yet.|r Open your Talent window (press N) once, then re-run |cffffd100/he talent audit|r.")
        table.insert(reportLines, "(Talent tree data not loaded yet — press N to open your Talent window once, then re-run /he talent audit.)")
        TA:ShowAuditReportPopup(table.concat(reportLines, "\n"), classToken)
        return
    end

    -- Simulate spending points in build order per tree using posX/posY tiers (prevents false-positive LOCKED on low-level chars)
    for _, build in ipairs(builds) do
        local simTreePoints = {}
        local simRanks = {}
        local missingIssues = {}
        local lockedIssues = {}
        for stepIdx, step in ipairs(build.order or {}) do
            local tabIdx, wantName, wantRank = step[1], step[2], step[3]
            local node, matchedName = MatchModernNodeByName(modernNodes, wantName, tabIdx)
            if not node then
                table.insert(missingIssues, string.format("Step #%d (Tab %d): '%s' does NOT exist in live modern tree", stepIdx, tabIdx or 0, tostring(wantName)))
            else
                local treeKey = node.simTreeKey or ("tab:" .. tostring(tabIdx or 1))
                local tier = math.max(1, tonumber(node.simTier) or 1)
                local reqPts = (tier - 1) * 5
                local curTreePts = simTreePoints[treeKey] or 0
                if curTreePts < reqPts then
                    table.insert(lockedIssues, string.format("Step #%d (Tab %d / Tree %s): '%s' is Row %d (needs %d pts, only %d simulated pts spent so far)",
                        stepIdx, tabIdx or 0, tostring(node.simTreeIdx or tabIdx or 1), tostring(matchedName or wantName), tier, reqPts, curTreePts))
                end

                local nKey = tostring(node.nodeID or matchedName or wantName)
                local prevSim = simRanks[nKey] or 0
                local maxR = tonumber(node.maxRank) or 1
                local target = math.min(tonumber(wantRank) or maxR, maxR)
                local added = math.max(0, target - prevSim)
                simRanks[nKey] = prevSim + added
                simTreePoints[treeKey] = curTreePts + added
            end
        end
        if #missingIssues == 0 and #lockedIssues == 0 then
            NS:Print(string.format("  |cff00ff00[PASS]|r |cffffd100%s|r — All %d steps verified & pass simulated (tier-1)*5 check.", build.label, #(build.order or {})))
            table.insert(reportLines, string.format("[PASS] %s — All %d steps verified & pass simulated (tier-1)*5 check.", build.label, #(build.order or {})))
        else
            NS:Print(string.format("  |cffff5555[ISSUES]|r |cffffd100%s|r — %d missing, %d locked-tier issue(s):", build.label, #missingIssues, #lockedIssues))
            table.insert(reportLines, string.format("[ISSUES] %s — %d missing, %d locked-tier issue(s):", build.label, #missingIssues, #lockedIssues))
            for _, m in ipairs(missingIssues) do
                NS:Print("    |cffff5555MISSING:|r " .. m)
                table.insert(reportLines, "  MISSING: " .. m)
            end
            for _, l in ipairs(lockedIssues) do
                NS:Print("    |cffff9900LOCKED:|r " .. l)
                table.insert(reportLines, "  LOCKED: " .. l)
            end
        end
    end

    -- Section 2: Full dump of live modern C_Traits tree
    table.insert(reportLines, "")
    table.insert(reportLines, "=== SECTION 2: LIVE CLIENT TALENT TREE DUMP (MODERN C_TRAITS) ===")
    local sortedNodes = {}
    for _, node in ipairs(modernNodes) do table.insert(sortedNodes, node) end
    table.sort(sortedNodes, function(a, b)
        local ta, tb = tonumber(a.simTreeIdx) or 1, tonumber(b.simTreeIdx) or 1
        if ta ~= tb then return ta < tb end
        local ra, rb = tonumber(a.simTier) or 1, tonumber(b.simTier) or 1
        if ra ~= rb then return ra < rb end
        local ca, cb = tonumber(a.simCol) or 1, tonumber(b.simCol) or 1
        if ca ~= cb then return ca < cb end
        if a.posY ~= b.posY then return a.posY < b.posY end
        if a.posX ~= b.posX then return a.posX < b.posX end
        return (a.nodeID or 0) < (b.nodeID or 0)
    end)
    for _, node in ipairs(sortedNodes) do
        local allNames = table.concat(node.names or {}, " / ")
        table.insert(reportLines, string.format("Tree %d | Row %d | Col %d | Node %s | posY=%s | posX=%s | %s | MaxRank %d (Cur %d)",
            tonumber(node.simTreeIdx) or 1, tonumber(node.simTier) or 1, tonumber(node.simCol) or 1,
            tostring(node.nodeID or "?"), tostring(node.posY), tostring(node.posX),
            allNames, tonumber(node.maxRank) or 1, tonumber(node.curRank) or 0))
    end

    TA:ShowAuditReportPopup(table.concat(reportLines, "\n"), classToken)
end

-- Create high-contrast Gold Border + Additive Glow + NEXT Pill around recommended talent button
local function SetSolidColorTexture(tex, r, g, b, a)
    if tex.SetColorTexture then
        tex:SetColorTexture(r, g, b, a)
    else
        tex:SetTexture("Interface\\Buttons\\WHITE8x8")
        tex:SetVertexColor(r, g, b, a)
    end
end

local function EnsureGoldBorder()
    if TA.glowFrame then return TA.glowFrame end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local g = CreateFrame("Frame", "WOWEngineTalentGoldBorder", UIParent, template)
    g:EnableMouse(false)
    g:SetFrameStrata("HIGH")
    g:SetFrameLevel(90)

    -- Thick 3px solid bright gold edge framing the talent icon clearly over Blizzard's green border
    local edgeSize = 3
    local edgeR, edgeG, edgeB, edgeA = 1.0, 0.85, 0.08, 1.0

    local topEdge = g:CreateTexture(nil, "OVERLAY")
    SetSolidColorTexture(topEdge, edgeR, edgeG, edgeB, edgeA)
    topEdge:SetPoint("TOPLEFT", g, "TOPLEFT", 0, 0)
    topEdge:SetPoint("TOPRIGHT", g, "TOPRIGHT", 0, 0)
    topEdge:SetHeight(edgeSize)

    local bottomEdge = g:CreateTexture(nil, "OVERLAY")
    SetSolidColorTexture(bottomEdge, edgeR, edgeG, edgeB, edgeA)
    bottomEdge:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, 0)
    bottomEdge:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", 0, 0)
    bottomEdge:SetHeight(edgeSize)

    local leftEdge = g:CreateTexture(nil, "OVERLAY")
    SetSolidColorTexture(leftEdge, edgeR, edgeG, edgeB, edgeA)
    leftEdge:SetPoint("TOPLEFT", g, "TOPLEFT", 0, -edgeSize)
    leftEdge:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, edgeSize)
    leftEdge:SetWidth(edgeSize)

    local rightEdge = g:CreateTexture(nil, "OVERLAY")
    SetSolidColorTexture(rightEdge, edgeR, edgeG, edgeB, edgeA)
    rightEdge:SetPoint("TOPRIGHT", g, "TOPRIGHT", 0, -edgeSize)
    rightEdge:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", 0, edgeSize)
    rightEdge:SetWidth(edgeSize)

    -- Additive gold action-button glow aura around the border
    local glowTex = g:CreateTexture(nil, "OVERLAY")
    glowTex:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glowTex:SetBlendMode("ADD")
    glowTex:SetVertexColor(1.0, 0.82, 0.0, 0.95)
    glowTex:SetPoint("TOPLEFT", g, "TOPLEFT", -10, 10)
    glowTex:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", 10, -10)
    g.glowTex = glowTex

    -- High-contrast dark pill with thin gold border for the "NEXT" label
    local pill = CreateFrame("Frame", nil, g, template)
    pill:EnableMouse(false)
    pill:SetPoint("BOTTOM", g, "TOP", 0, 3)
    if pill.SetBackdrop then
        pcall(function()
            pill:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false,
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            pill:SetBackdropColor(0.0, 0.0, 0.0, 0.85)
            pill:SetBackdropBorderColor(1.0, 0.82, 0.1, 0.95)
        end)
    else
        local pillBg = pill:CreateTexture(nil, "BACKGROUND")
        SetSolidColorTexture(pillBg, 0.0, 0.0, 0.0, 0.85)
        pillBg:SetAllPoints(pill)
    end

    local badge = pill:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    pcall(badge.SetFont, badge, fontPath, 12, "THICKOUTLINE")
    badge:SetTextColor(1.0, 0.85, 0.1, 1.0)
    badge:SetShadowOffset(1, -1)
    badge:SetShadowColor(0.0, 0.0, 0.0, 0.9)
    badge:SetPoint("CENTER", pill, "CENTER", 0, 0)
    badge:SetText("NEXT")

    local textW = (badge.GetStringWidth and badge:GetStringWidth()) or 36
    pill:SetSize(math.max(math.ceil(textW) + 12, 48), 18)

    g.badgePill = pill
    g.badge = badge
    g:Hide()
    TA.glowFrame = g
    return g
end

local function AnchorTalentBar(bar, parent)
    if not bar or not parent then return end
    if bar:GetParent() ~= parent then
        bar:SetParent(parent)
    end
    bar:ClearAllPoints()
    if parent == _G.PlayerSpellsFrame and parent.TitleContainer then
        bar:SetPoint("BOTTOMLEFT", parent.TitleContainer, "TOPLEFT", 0, 4)
    else
        bar:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 16, 2)
    end
    bar:SetFrameStrata("HIGH")
    local parentLevel = (parent.GetFrameLevel and parent:GetFrameLevel()) or 1
    bar:SetFrameLevel(math.max(parentLevel + 10, 50))
end

-- ============================================================
-- FULL BLIZZARD-GRAPHICS 3-PANEL TALENT TREE POP-OUT PREVIEW
-- ============================================================
TA.fullTreeFrame = nil
TA.fullTreeGroup = nil

local function SetColorTexSafe(tex, r, g, b, a)
    if tex.SetColorTexture then
        tex:SetColorTexture(r, g, b, a)
    else
        tex:SetTexture("Interface\\Buttons\\WHITE8x8")
        tex:SetVertexColor(r, g, b, a)
    end
end

local function ApplyBlizzardTreeBackground(panel, bgFile)
    if not panel or not panel.bgQuads then return end
    if bgFile and type(bgFile) == "string" and bgFile ~= "" then
        local base = "Interface\\TalentFrame\\" .. bgFile
        panel.bgQuads.tl:SetTexture(base .. "-TopLeft")
        panel.bgQuads.tr:SetTexture(base .. "-TopRight")
        panel.bgQuads.bl:SetTexture(base .. "-BottomLeft")
        panel.bgQuads.br:SetTexture(base .. "-BottomRight")
        panel.bgQuads.tl:SetVertexColor(0.85, 0.85, 0.90, 0.88)
        panel.bgQuads.tr:SetVertexColor(0.85, 0.85, 0.90, 0.88)
        panel.bgQuads.bl:SetVertexColor(0.85, 0.85, 0.90, 0.88)
        panel.bgQuads.br:SetVertexColor(0.85, 0.85, 0.90, 0.88)
    else
        SetColorTexSafe(panel.bgQuads.tl, 0.04, 0.08, 0.16, 0.92)
        SetColorTexSafe(panel.bgQuads.tr, 0.04, 0.08, 0.16, 0.92)
        SetColorTexSafe(panel.bgQuads.bl, 0.03, 0.06, 0.13, 0.92)
        SetColorTexSafe(panel.bgQuads.br, 0.03, 0.06, 0.13, 0.92)
    end
end

local function AcquirePreviewArrow(panel, arrowIdx)
    panel.arrows = panel.arrows or {}
    local a = panel.arrows[arrowIdx]
    if not a then
        a = {}
        a.line1 = panel:CreateTexture(nil, "ARTWORK")
        a.line2 = panel:CreateTexture(nil, "ARTWORK")
        a.head = panel:CreateTexture(nil, "OVERLAY")
        a.head:SetSize(8, 8)
        panel.arrows[arrowIdx] = a
    end
    return a
end

local function DrawPreviewPrereqArrow(panel, arrowIdx, x1, y1, x2, y2, r, g, b, alpha)
    local a = AcquirePreviewArrow(panel, arrowIdx)
    a.line1:ClearAllPoints()
    a.line2:ClearAllPoints()
    a.head:ClearAllPoints()
    SetColorTexSafe(a.line1, r, g, b, alpha)
    SetColorTexSafe(a.line2, r, g, b, alpha)
    SetColorTexSafe(a.head, r, g, b, alpha)

    if math.abs(x1 - x2) < 2 then
        -- Straight vertical arrow
        local topY = math.max(y1, y2) - 18
        local botY = math.min(y1, y2) + 18
        local h = math.max(4, topY - botY)
        a.line1:SetSize(4, h)
        a.line1:SetPoint("TOP", panel, "TOPLEFT", x1, topY)
        a.line1:Show()
        a.line2:Hide()
        a.head:SetPoint("CENTER", panel, "TOPLEFT", x2, botY + 2)
        a.head:Show()
    elseif math.abs(y1 - y2) < 2 then
        -- Straight horizontal arrow
        local leftX = math.min(x1, x2) + 18
        local rightX = math.max(x1, x2) - 18
        local w = math.max(4, rightX - leftX)
        a.line1:SetSize(w, 4)
        a.line1:SetPoint("LEFT", panel, "TOPLEFT", leftX, y1)
        a.line1:Show()
        a.line2:Hide()
        a.head:SetPoint("CENTER", panel, "TOPLEFT", (x2 > x1) and (rightX - 2) or (leftX + 2), y2)
        a.head:Show()
    else
        -- L-shaped connector (horizontal then vertical)
        local leftX = math.min(x1, x2)
        local w = math.max(4, math.abs(x2 - x1))
        a.line1:SetSize(w, 4)
        a.line1:SetPoint("LEFT", panel, "TOPLEFT", leftX, y1)
        a.line1:Show()

        local topY = math.max(y1, y2)
        local botY = math.min(y1, y2) + 18
        local h = math.max(4, topY - botY)
        a.line2:SetSize(4, h)
        a.line2:SetPoint("TOP", panel, "TOPLEFT", x2, topY)
        a.line2:Show()

        a.head:SetPoint("CENTER", panel, "TOPLEFT", x2, botY + 2)
        a.head:Show()
    end
end

local function AcquirePreviewSlot(panel, slotIdx)
    panel.slots = panel.slots or {}
    local btn = panel.slots[slotIdx]
    if not btn then
        btn = CreateFrame("Button", nil, panel)
        btn:SetSize(36, 36)

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        btn.icon = icon

        local slotBorder = btn:CreateTexture(nil, "OVERLAY")
        slotBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        slotBorder:SetPoint("TOPLEFT", -11, 11)
        slotBorder:SetPoint("BOTTOMRIGHT", 11, -11)
        btn.slotBorder = slotBorder

        -- Crisp gold/green frame border for planned talents
        local edge = {}
        local function mkEdge()
            local e = btn:CreateTexture(nil, "OVERLAY")
            return e
        end
        edge.t = mkEdge(); edge.t:SetPoint("TOPLEFT", 0, 0); edge.t:SetPoint("TOPRIGHT", 0, 0); edge.t:SetHeight(2)
        edge.b = mkEdge(); edge.b:SetPoint("BOTTOMLEFT", 0, 0); edge.b:SetPoint("BOTTOMRIGHT", 0, 0); edge.b:SetHeight(2)
        edge.l = mkEdge(); edge.l:SetPoint("TOPLEFT", 0, 0); edge.l:SetPoint("BOTTOMLEFT", 0, 0); edge.l:SetWidth(2)
        edge.r = mkEdge(); edge.r:SetPoint("TOPRIGHT", 0, 0); edge.r:SetPoint("BOTTOMRIGHT", 0, 0); edge.r:SetWidth(2)
        btn.edges = edge

        local rankBg = btn:CreateTexture(nil, "OVERLAY")
        SetColorTexSafe(rankBg, 0.0, 0.0, 0.0, 0.88)
        rankBg:SetSize(26, 13)
        rankBg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 4, -3)
        btn.rankBg = rankBg

        local rankTxt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rankTxt:SetPoint("CENTER", rankBg, "CENTER", 0, 0)
        local fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        pcall(rankTxt.SetFont, rankTxt, fontPath, 10, "OUTLINE")
        btn.rankTxt = rankTxt

        btn:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local showedBlizz = false
            if self.classicTab and self.classicIndex and GameTooltip.SetTalent then
                local ok = pcall(GameTooltip.SetTalent, GameTooltip, self.classicTab, self.classicIndex)
                if ok then showedBlizz = true end
            elseif self.spellID and GameTooltip.SetSpellByID then
                local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)
                if ok then showedBlizz = true end
            end
            if not showedBlizz then
                GameTooltip:AddLine(tostring(self.talentName or "Talent"), 1.0, 0.85, 0.1)
                GameTooltip:AddLine(string.format("Live Rank: %d / %d", self.curRank or 0, self.maxRank or 1), 0.9, 0.9, 0.9)
            end
            if self.plannedRank and self.plannedRank > 0 then
                GameTooltip:AddLine(" ")
                local stepStr = (self.planStep and self.planStep > 0) and (" (Step #" .. tostring(self.planStep) .. ")") or ""
                GameTooltip:AddLine(string.format("|cff00aeffWOWEngine Spec Plan:|r Target |cffffd100%d/%d|r%s",
                    self.plannedRank, self.maxRank or 1, stepStr), 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)

        panel.slots[slotIdx] = btn
    end
    return btn
end

function TA:RefreshFullTreePreview(buildOverride, groupOverride)
    local f = TA.fullTreeFrame
    if not f then return end

    local grp = tonumber(groupOverride) or TA.fullTreeGroup or TA:GetActiveSpecGroup()
    TA.fullTreeGroup = grp
    local build = buildOverride or TA:GetSelectedBuild(grp)
    if not build then return end

    local planTag = (NS.PlanBuilder and NS.PlanBuilder.GetPlanDisplayLabel) and NS.PlanBuilder:GetPlanDisplayLabel(grp) or "Spec Pre-Load"
    local grpLabel = (grp == 2) and "Secondary Spec (Group 2)" or "Primary Spec (Group 1)"
    f.title:SetText(string.format("|cff00aeffWOWEngine Full Talent Tree|r — |cffffd100%s|r", tostring(build.label or "Spec")))
    f.sub:SetText(string.format("%s  |  Plan Focus: |cff00ff00%s|r  |  Hover any talent for full Blizzard tooltip", grpLabel, planTag))

    -- Build planned target rank lookup from build.order
    local plannedByTabName = { [1] = {}, [2] = {}, [3] = {} }
    local plannedStepByTabName = { [1] = {}, [2] = {}, [3] = {} }
    for stepIdx, step in ipairs(build.order or {}) do
        local tabIdx, wantName, wantRank = step[1], string.lower(tostring(step[2] or "")), tonumber(step[3]) or 1
        if plannedByTabName[tabIdx] then
            plannedByTabName[tabIdx][wantName] = math.max(plannedByTabName[tabIdx][wantName] or 0, wantRank)
            if not plannedStepByTabName[tabIdx][wantName] then
                plannedStepByTabName[tabIdx][wantName] = stepIdx
            end
        end
    end

    local function lookupPlanned(tabIdx, talentName, maxRank)
        local map = plannedByTabName[tabIdx]
        if not map or not talentName then return 0, nil end
        local low = string.lower(talentName)
        if map[low] then
            return math.min(map[low], maxRank or 1), plannedStepByTabName[tabIdx][low]
        end
        for wantKey, wantVal in pairs(map) do
            if string.find(low, wantKey, 1, true) then
                return math.min(wantVal, maxRank or 1), plannedStepByTabName[tabIdx][wantKey]
            end
        end
        return 0, nil
    end

    local hasClassic = false
    local tabSnaps = {}
    if GetNumTalents and GetTalentInfo then
        for tabIdx = 1, 3 do
            local snap = SnapshotClassicTab(tabIdx)
            if snap then
                tabSnaps[tabIdx] = snap
                hasClassic = true
            end
        end
    end

    local splitCounts = { 0, 0, 0 }

    if hasClassic then
        for tabIdx = 1, 3 do
            local panel = f.panels[tabIdx]
            local snap = tabSnaps[tabIdx]
            ApplyBlizzardTreeBackground(panel, snap and snap.bgFile or nil)

            local slotUsed = 0
            local arrowUsed = 0
            local plannedSum = 0

            if snap then
                local posCache = {}
                for _, t in ipairs(snap.talents) do
                    local plannedR, planStep = lookupPlanned(tabIdx, t.name, t.maxRank)
                    plannedSum = plannedSum + plannedR

                    local cx = 36 + (math.max(1, math.min(4, t.col)) - 1) * 58
                    local cy = -48 - (math.max(1, math.min(7, t.tier)) - 1) * 54
                    posCache[t.tier .. ":" .. t.col] = { x = cx, y = cy, planned = plannedR, cur = t.curRank, max = t.maxRank }

                    slotUsed = slotUsed + 1
                    local btn = AcquirePreviewSlot(panel, slotUsed)
                    btn:ClearAllPoints()
                    btn:SetPoint("CENTER", panel, "TOPLEFT", cx, cy)
                    btn.icon:SetTexture(t.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

                    btn.classicTab = tabIdx
                    btn.classicIndex = t.index
                    btn.spellID = nil
                    btn.talentName = t.name
                    btn.curRank = t.curRank
                    btn.maxRank = t.maxRank
                    btn.plannedRank = plannedR
                    btn.planStep = planStep

                    if plannedR > 0 then
                        if btn.icon.SetDesaturated then btn.icon:SetDesaturated(false) end
                        btn.icon:SetVertexColor(1, 1, 1, 1)
                        local isDone = (t.curRank >= plannedR)
                        local er, eg, eb = isDone and 0.15 or 1.0, isDone and 0.95 or 0.84, isDone and 0.25 or 0.10
                        for _, e in pairs(btn.edges) do SetColorTexSafe(e, er, eg, eb, 1.0); e:Show() end
                        if isDone then
                            btn.rankTxt:SetText(string.format("|cff00ff00%d/%d|r", plannedR, t.maxRank))
                        else
                            btn.rankTxt:SetText(string.format("|cffffd100%d/%d|r", plannedR, t.maxRank))
                        end
                    else
                        if btn.icon.SetDesaturated then btn.icon:SetDesaturated(true) end
                        btn.icon:SetVertexColor(0.55, 0.55, 0.55, 0.85)
                        for _, e in pairs(btn.edges) do e:Hide() end
                        btn.rankTxt:SetText(string.format("|cff777777%d/%d|r", t.curRank, t.maxRank))
                    end
                    btn:Show()
                end

                -- Draw prerequisite arrows
                for _, t in ipairs(snap.talents) do
                    local childPos = posCache[t.tier .. ":" .. t.col]
                    if childPos and t.prereqs then
                        for _, pr in ipairs(t.prereqs) do
                            local parPos = posCache[pr.tier .. ":" .. pr.col]
                            if parPos then
                                arrowUsed = arrowUsed + 1
                                local ar, ag, ab, aa = 0.45, 0.45, 0.45, 0.65
                                if childPos.planned > 0 then
                                    if childPos.cur >= childPos.planned then
                                        ar, ag, ab, aa = 0.15, 0.95, 0.25, 0.95
                                    else
                                        ar, ag, ab, aa = 1.0, 0.84, 0.10, 0.95
                                    end
                                end
                                DrawPreviewPrereqArrow(panel, arrowUsed, parPos.x, parPos.y, childPos.x, childPos.y, ar, ag, ab, aa)
                            end
                        end
                    end
                end
            end

            splitCounts[tabIdx] = plannedSum
            local tabName = GetClassicTabName(tabIdx)
            panel.hdrTxt:SetText(string.format("|cffffd100%s|r  |cff00ff00(%d pts)|r", tabName, plannedSum))

            for i = slotUsed + 1, #(panel.slots or {}) do panel.slots[i]:Hide() end
            for i = arrowUsed + 1, #(panel.arrows or {}) do
                panel.arrows[i].line1:Hide()
                panel.arrows[i].line2:Hide()
                panel.arrows[i].head:Hide()
            end
        end
    else
        -- Modern C_Traits fallback: render build steps cleanly across the 3 panels by step tab
        local modernNodes = CollectModernTreeSnapshot()
        for tabIdx = 1, 3 do
            local panel = f.panels[tabIdx]
            ApplyBlizzardTreeBackground(panel, nil)
            local slotUsed = 0
            local plannedSum = 0
            for stepIdx, step in ipairs(build.order or {}) do
                if step[1] == tabIdx and slotUsed < 28 then
                    local wantName, wantRank = step[2], tonumber(step[3]) or 1
                    local node, matchedName = MatchModernNodeByName(modernNodes, wantName)
                    local maxR = (node and node.maxRank) or wantRank
                    local curR = (node and node.curRank) or 0
                    local plannedR = math.min(wantRank, maxR)
                    plannedSum = plannedSum + plannedR

                    slotUsed = slotUsed + 1
                    local col = ((slotUsed - 1) % 4) + 1
                    local row = math.floor((slotUsed - 1) / 4) + 1
                    local cx = 36 + (col - 1) * 58
                    local cy = -48 - (row - 1) * 54

                    local btn = AcquirePreviewSlot(panel, slotUsed)
                    btn:ClearAllPoints()
                    btn:SetPoint("CENTER", panel, "TOPLEFT", cx, cy)
                    local iconTex = "Interface\\Icons\\INV_Misc_QuestionMark"
                    local sid = nil
                    if node and node.nodeInfo and node.nodeInfo.activeEntry and node.nodeInfo.activeEntry.entryID and C_Traits and C_Traits.GetEntryInfo and C_Traits.GetDefinitionInfo then
                        local cfgID = GetActiveTraitConfigID(nil)
                        local okE, ei = pcall(C_Traits.GetEntryInfo, cfgID, node.nodeInfo.activeEntry.entryID)
                        if okE and ei and ei.definitionID then
                            local okD, di = pcall(C_Traits.GetDefinitionInfo, ei.definitionID)
                            if okD and di and di.spellID then
                                sid = di.spellID
                                if C_Spell and C_Spell.GetSpellTexture then
                                    local okTx, tx = pcall(C_Spell.GetSpellTexture, sid)
                                    if okTx and tx then iconTex = tx end
                                elseif GetSpellTexture then
                                    local okTx, tx = pcall(GetSpellTexture, sid)
                                    if okTx and tx then iconTex = tx end
                                end
                            end
                        end
                    end
                    btn.icon:SetTexture(iconTex)
                    if btn.icon.SetDesaturated then btn.icon:SetDesaturated(false) end
                    btn.icon:SetVertexColor(1, 1, 1, 1)
                    btn.classicTab = nil
                    btn.classicIndex = nil
                    btn.spellID = sid
                    btn.talentName = matchedName or wantName
                    btn.curRank = curR
                    btn.maxRank = maxR
                    btn.plannedRank = plannedR
                    btn.planStep = stepIdx

                    local isDone = (curR >= plannedR)
                    local er, eg, eb = isDone and 0.15 or 1.0, isDone and 0.95 or 0.84, isDone and 0.25 or 0.10
                    for _, e in pairs(btn.edges) do SetColorTexSafe(e, er, eg, eb, 1.0); e:Show() end
                    btn.rankTxt:SetText(string.format("%s%d/%d|r", isDone and "|cff00ff00" or "|cffffd100", plannedR, maxR))
                    btn:Show()
                end
            end
            splitCounts[tabIdx] = plannedSum
            panel.hdrTxt:SetText(string.format("|cffffd100Tree %d|r  |cff00ff00(%d pts)|r", tabIdx, plannedSum))
            for i = slotUsed + 1, #(panel.slots or {}) do panel.slots[i]:Hide() end
            for i = 1, #(panel.arrows or {}) do
                panel.arrows[i].line1:Hide()
                panel.arrows[i].line2:Hide()
                panel.arrows[i].head:Hide()
            end
        end
    end

    f.splitTxt:SetText(string.format("Planned Split: |cffffd100%d / %d / %d|r  (Green = Learned to Target | Gold = Planned Pick)",
        splitCounts[1], splitCounts[2], splitCounts[3]))
end

function TA:OpenFullTreePreview(buildOverride, groupOverride)
    if not TA.fullTreeFrame then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local f = CreateFrame("Frame", "WOWEngineFullTreeFrame", UIParent, template)
        f:SetSize(792, 526)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(152)
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
            table.insert(UISpecialFrames, "WOWEngineFullTreeFrame")
        end

        local headerBg = f:CreateTexture(nil, "ARTWORK")
        headerBg:SetPoint("TOPLEFT", 4, -4)
        headerBg:SetPoint("TOPRIGHT", -4, -4)
        headerBg:SetHeight(46)
        SetColorTexSafe(headerBg, 0.06, 0.16, 0.34, 0.96)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 14, -10)
        f.title = title

        local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
        f.sub = sub

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        -- 3 Side-by-Side Official Blizzard Talent Tree Panels
        f.panels = {}
        for tabIdx = 1, 3 do
            local panel = CreateFrame("Frame", nil, f, template)
            panel:SetSize(248, 424)
            panel:SetPoint("TOPLEFT", 14 + (tabIdx - 1) * 258, -56)
            if panel.SetBackdrop then
                pcall(function()
                    panel:SetBackdrop({
                        edgeFile = "Interface\\Buttons\\WHITE8x8",
                        edgeSize = 1,
                    })
                    panel:SetBackdropBorderColor(0.95, 0.78, 0.18, 0.85)
                end)
            end

            -- 4-quadrant Blizzard talent tree background art
            local tl = panel:CreateTexture(nil, "BACKGROUND")
            tl:SetPoint("TOPLEFT", 1, -24)
            tl:SetSize(196, 256)
            local tr = panel:CreateTexture(nil, "BACKGROUND")
            tr:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
            tr:SetPoint("TOPRIGHT", -1, -24)
            tr:SetHeight(256)
            local bl = panel:CreateTexture(nil, "BACKGROUND")
            bl:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
            bl:SetPoint("BOTTOMLEFT", 1, 1)
            bl:SetWidth(196)
            local br = panel:CreateTexture(nil, "BACKGROUND")
            br:SetPoint("TOPLEFT", bl, "TOPRIGHT", 0, 0)
            br:SetPoint("BOTTOMRIGHT", -1, 1)
            panel.bgQuads = { tl = tl, tr = tr, bl = bl, br = br }

            -- Dark readability veil over background art so icons & arrows pop cleanly
            local veil = panel:CreateTexture(nil, "BORDER")
            SetColorTexSafe(veil, 0.02, 0.05, 0.10, 0.42)
            veil:SetPoint("TOPLEFT", 1, -24)
            veil:SetPoint("BOTTOMRIGHT", -1, 1)

            local hdrBar = panel:CreateTexture(nil, "ARTWORK")
            SetColorTexSafe(hdrBar, 0.06, 0.16, 0.34, 0.96)
            hdrBar:SetPoint("TOPLEFT", 1, -1)
            hdrBar:SetPoint("TOPRIGHT", -1, -1)
            hdrBar:SetHeight(23)

            local hdrTxt = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            hdrTxt:SetPoint("CENTER", hdrBar, "CENTER", 0, 0)
            panel.hdrTxt = hdrTxt

            f.panels[tabIdx] = panel
        end

        -- Footer Controls: [<] [Switch Spec] [>] + Split Summary + Close
        local prevSpecBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        prevSpecBtn:SetSize(24, 24)
        prevSpecBtn:SetPoint("BOTTOMLEFT", 14, 12)
        prevSpecBtn:SetText("<")
        prevSpecBtn:SetScript("OnClick", function() TA:CycleBuild(-1, TA.fullTreeGroup) end)

        local swSpecBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        swSpecBtn:SetSize(96, 24)
        swSpecBtn:SetPoint("LEFT", prevSpecBtn, "RIGHT", 2, 0)
        swSpecBtn:SetText("Switch Spec")
        swSpecBtn:SetScript("OnClick", function() TA:CycleBuild(1, TA.fullTreeGroup) end)

        local nextSpecBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        nextSpecBtn:SetSize(24, 24)
        nextSpecBtn:SetPoint("LEFT", swSpecBtn, "RIGHT", 2, 0)
        nextSpecBtn:SetText(">")
        nextSpecBtn:SetScript("OnClick", function() TA:CycleBuild(1, TA.fullTreeGroup) end)

        local splitTxt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        splitTxt:SetPoint("LEFT", nextSpecBtn, "RIGHT", 14, 0)
        splitTxt:SetJustifyH("LEFT")
        f.splitTxt = splitTxt

        local closeFoot = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeFoot:SetSize(84, 24)
        closeFoot:SetPoint("BOTTOMRIGHT", -14, 12)
        closeFoot:SetText("Close")
        closeFoot:SetScript("OnClick", function() f:Hide() end)

        TA.fullTreeFrame = f
    end

    TA:RefreshFullTreePreview(buildOverride, groupOverride)
    TA.fullTreeFrame:Show()
    TA.fullTreeFrame:Raise()
end

function TA:EnsureTalentBar()
    local parent = TA:GetTalentParentFrame()
    if not parent then return nil end

    if not TA.bar then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local bar = CreateFrame("Frame", "WOWEngineTalentBar", parent, template)
        bar:SetSize(464, 44)
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

        local specPrevBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
        specPrevBtn:SetSize(20, 20)
        specPrevBtn:SetPoint("TOPLEFT", 6, -4)
        specPrevBtn:SetText("<")
        specPrevBtn:SetScript("OnClick", function() TA:CycleBuild(-1) end)
        bar.specPrevBtn = specPrevBtn

        local specBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
        specBtn:SetSize(200, 20)
        specBtn:SetPoint("LEFT", specPrevBtn, "RIGHT", 2, 0)
        specBtn:SetScript("OnClick", function() TA:CycleBuild(1) end)
        bar.specBtn = specBtn

        local specNextBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
        specNextBtn:SetSize(20, 20)
        specNextBtn:SetPoint("LEFT", specBtn, "RIGHT", 2, 0)
        specNextBtn:SetText(">")
        specNextBtn:SetScript("OnClick", function() TA:CycleBuild(1) end)
        bar.specNextBtn = specNextBtn

        local fullTreeBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
        fullTreeBtn:SetSize(94, 20)
        fullTreeBtn:SetPoint("LEFT", specNextBtn, "RIGHT", 6, 0)
        fullTreeBtn:SetText("View Full Tree")
        fullTreeBtn:SetScript("OnClick", function()
            pcall(function() TA:OpenFullTreePreview() end)
        end)
        bar.fullTreeBtn = fullTreeBtn

        local capsBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
        capsBtn:SetSize(100, 20)
        capsBtn:SetPoint("LEFT", fullTreeBtn, "RIGHT", 6, 0)
        capsBtn:SetText("Stat Caps")
        capsBtn:SetScript("OnClick", function()
            if NS.StatCapsUI and NS.StatCapsUI.Toggle then NS.StatCapsUI:Toggle() end
        end)

        local nextTxt = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nextTxt:SetPoint("BOTTOMLEFT", 8, 5)
        nextTxt:SetWidth(448)
        nextTxt:SetJustifyH("LEFT")
        bar.nextTxt = nextTxt

        TA.bar = bar
    end

    AnchorTalentBar(TA.bar, parent)
    return TA.bar
end

local function IsButtonVisible(btn)
    if not btn or not btn:IsShown() then return false end
    if btn.IsVisible and not btn:IsVisible() then return false end
    return true
end

local function FindRecommendedTalentButton(parent, nextPick)
    if not parent or not nextPick then return nil, nil end

    -- Modern PlayerSpellsFrame / ClassTalentFrame TalentsFrame nodes/buttons
    local talentsFrame = parent.TalentsFrame
    if talentsFrame then
        if not talentsFrame:IsShown() then
            return nil, nil
        end

        if nextPick.nodeID then
            if talentsFrame.GetTalentButtonByNodeID then
                local okB, btn = pcall(talentsFrame.GetTalentButtonByNodeID, talentsFrame, nextPick.nodeID)
                if okB and IsButtonVisible(btn) then
                    return btn, talentsFrame
                end
            end
            if type(talentsFrame.nodeIDToButton) == "table" then
                local btn = talentsFrame.nodeIDToButton[nextPick.nodeID]
                if IsButtonVisible(btn) then
                    return btn, talentsFrame
                end
            end
        end

        local wantLower = nextPick.name and string.lower(nextPick.name)
        local partialMatch = nil
        for _, btn in ipairs(CollectModernTalentButtons(talentsFrame)) do
            if IsButtonVisible(btn) then
                local names, btnNodeID = GetButtonTalentMeta(btn, talentsFrame)
                if nextPick.nodeID and btnNodeID and btnNodeID == nextPick.nodeID then
                    return btn, talentsFrame
                end
                if wantLower and names then
                    for _, n in ipairs(names) do
                        local low = string.lower(n)
                        if low == wantLower then
                            return btn, talentsFrame
                        elseif not partialMatch and string.find(low, wantLower, 1, true) then
                            partialMatch = btn
                        end
                    end
                end
            end
        end
        if partialMatch then
            return partialMatch, talentsFrame
        end

        -- Fallback if a hybrid client renders Classic talent buttons inside TalentsFrame
        if nextPick.index then
            local classicBtn = _G["PlayerTalentFrameTalent" .. nextPick.index]
                or _G["TalentFrameTalent" .. nextPick.index]
            if IsButtonVisible(classicBtn) then
                return classicBtn, talentsFrame
            end
        end
        return nil, nil
    end

    -- Classic PlayerTalentFrame / TalentFrame tab & button lookup
    local activeTab = (PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(parent)) or parent.selectedTab or 1
    if nextPick.tab and activeTab ~= nextPick.tab then
        return nil, nil
    end
    if nextPick.index then
        local btn = _G["PlayerTalentFrameTalent" .. nextPick.index]
            or _G["TalentFrameTalent" .. nextPick.index]
            or parent["Talent" .. nextPick.index]
        if IsButtonVisible(btn) then
            return btn, parent
        end
    end
    return nil, nil
end

function TA:ScheduleHighlightRefresh()
    if not (C_Timer and C_Timer.After) then return end
    if TA.refreshPending then return end
    TA.refreshPending = true
    C_Timer.After(0.05, function()
        TA.refreshPending = false
        pcall(function() TA:UpdateTalentHighlight() end)
    end)
end

function TA:UpdateTalentHighlight()
    local nextPick, build = TA:FindNextRecommendedTalent()
    TA.currentNextPick = nextPick

    if TA.fullTreeFrame and TA.fullTreeFrame:IsShown() then
        pcall(function() TA:RefreshFullTreePreview() end)
    end

    local bar = TA:EnsureTalentBar()
    if bar then
        bar.specBtn:SetText(build and build.label or "Select Pre-Load")
        if nextPick then
            if nextPick.source == "modern" then
                bar.nextTxt:SetText(string.format("|cffffd100Next Pick:|r |cff00ff00%s|r (%d/%d)",
                    nextPick.name, nextPick.curRank, nextPick.targetRank))
            else
                bar.nextTxt:SetText(string.format("|cffffd100Next Pick (Tab %d):|r |cff00ff00%s|r (%d/%d)",
                    nextPick.tab, nextPick.name, nextPick.curRank, nextPick.targetRank))
            end
        else
            bar.nextTxt:SetText("|cff00ff00Pre-load core talents complete!|r")
        end
    end

    local glow = EnsureGoldBorder()
    local parent = TA:GetTalentParentFrame()
    if not parent or not parent:IsShown() or not nextPick then
        glow:Hide()
        return
    end

    local btn, host = FindRecommendedTalentButton(parent, nextPick)
    if btn then
        local targetHost = host or parent
        if glow:GetParent() ~= targetHost then
            glow:SetParent(targetHost)
        end
        local strata = (btn.GetFrameStrata and btn:GetFrameStrata()) or "HIGH"
        glow:SetFrameStrata(strata)
        local btnLevel = (btn.GetFrameLevel and btn:GetFrameLevel()) or 10
        local highlightLevel = btnLevel + 10
        glow:SetFrameLevel(highlightLevel)
        if glow.badgePill then
            glow.badgePill:SetFrameStrata(strata)
            glow.badgePill:SetFrameLevel(highlightLevel + 2)
        end
        glow:ClearAllPoints()
        glow:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 3)
        glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 3, -3)
        glow:Show()
        glow:Raise()
    else
        glow:Hide()
    end
end

function TA:HookTalentFrame()
    local parent = TA:GetTalentParentFrame()
    if not parent then return end

    if not TA.hookedFrames[parent] then
        TA.hookedFrames[parent] = true
        parent:HookScript("OnShow", function()
            pcall(function()
                TA:HookTalentFrame()
                TA:EnsureTalentBar()
                TA:UpdateTalentHighlight()
                TA:ScheduleHighlightRefresh()
            end)
        end)
        parent:HookScript("OnHide", function()
            if TA.glowFrame then TA.glowFrame:Hide() end
        end)
        if hooksecurefunc and type(parent.SetTab) == "function" and not TA.hookedFuncs["parent_SetTab"] then
            TA.hookedFuncs["parent_SetTab"] = true
            hooksecurefunc(parent, "SetTab", function()
                pcall(function()
                    TA:HookTalentFrame()
                    TA:UpdateTalentHighlight()
                    TA:ScheduleHighlightRefresh()
                end)
            end)
        end
    end

    local talentsFrame = parent.TalentsFrame
    if talentsFrame and not TA.hookedFrames[talentsFrame] then
        TA.hookedFrames[talentsFrame] = true
        talentsFrame:HookScript("OnShow", function()
            pcall(function()
                TA:EnsureTalentBar()
                TA:UpdateTalentHighlight()
                TA:ScheduleHighlightRefresh()
            end)
        end)
        talentsFrame:HookScript("OnHide", function()
            if TA.glowFrame then TA.glowFrame:Hide() end
        end)
        if hooksecurefunc then
            if type(talentsFrame.LoadTalentTreeInternal) == "function" and not TA.hookedFuncs["LoadTalentTreeInternal"] then
                TA.hookedFuncs["LoadTalentTreeInternal"] = true
                hooksecurefunc(talentsFrame, "LoadTalentTreeInternal", function()
                    pcall(function() TA:ScheduleHighlightRefresh() end)
                end)
            end
            if type(talentsFrame.UpdateAllButtons) == "function" and not TA.hookedFuncs["UpdateAllButtons"] then
                TA.hookedFuncs["UpdateAllButtons"] = true
                hooksecurefunc(talentsFrame, "UpdateAllButtons", function()
                    pcall(function() TA:ScheduleHighlightRefresh() end)
                end)
            end
        end
    end

    if hooksecurefunc then
        if _G.PlayerTalentFrame_Update and not TA.hookedFuncs["PlayerTalentFrame_Update"] then
            TA.hookedFuncs["PlayerTalentFrame_Update"] = true
            hooksecurefunc("PlayerTalentFrame_Update", function()
                pcall(function() TA:UpdateTalentHighlight() end)
            end)
        end
        if _G.TalentFrame_Update and not TA.hookedFuncs["TalentFrame_Update"] then
            TA.hookedFuncs["TalentFrame_Update"] = true
            hooksecurefunc("TalentFrame_Update", function()
                pcall(function() TA:UpdateTalentHighlight() end)
            end)
        end
    end

    if parent:IsShown() then
        TA:EnsureTalentBar()
        TA:UpdateTalentHighlight()
        TA:ScheduleHighlightRefresh()
    end
end

function TA:PrintNextPick()
    local nextPick, build = TA:FindNextRecommendedTalent()
    NS:Print("Active Spec Pre-Load: |cffffd100" .. (build and build.label or "?") .. "|r")
    if nextPick then
        if nextPick.source == "modern" then
            NS:Print(string.format("  Next Recommended Talent: |cff00ff00%s|r (Rank %d/%d)",
                nextPick.name, nextPick.curRank, nextPick.targetRank))
        else
            NS:Print(string.format("  Next Recommended Talent: |cff00ff00%s|r (Tab %d | Rank %d/%d)",
                nextPick.name, nextPick.tab, nextPick.curRank, nextPick.targetRank))
        end
    else
        NS:Print("  Open your Talent Tree (N) to view the docked pre-load bar & gold border highlight.")
    end
end

local taEvents = CreateFrame("Frame")
taEvents:RegisterEvent("ADDON_LOADED")
taEvents:RegisterEvent("PLAYER_LOGIN")
pcall(taEvents.RegisterEvent, taEvents, "CHARACTER_POINTS_CHANGED")
pcall(taEvents.RegisterEvent, taEvents, "PLAYER_LEVEL_UP")
pcall(taEvents.RegisterEvent, taEvents, "PLAYER_TALENT_UPDATE")
pcall(taEvents.RegisterEvent, taEvents, "TRAIT_CONFIG_UPDATED")
pcall(taEvents.RegisterEvent, taEvents, "ACTIVE_TALENT_GROUP_CHANGED")
taEvents:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_PlayerSpells" or arg1 == "Blizzard_TalentUI" or arg1 == "Blizzard_ClassTalentUI" or arg1 == addonName then
            pcall(function() TA:HookTalentFrame() end)
        end
    elseif event == "PLAYER_LOGIN" then
        if _G.PlayerSpellsFrame or TA:GetTalentParentFrame() then
            pcall(function() TA:HookTalentFrame() end)
        end
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        TA.fullTreeGroup = TA:GetActiveSpecGroup()
        pcall(function() TA:UpdateTalentHighlight() end)
        if NS.StatCapsUI and NS.StatCapsUI.Refresh then
            pcall(function() NS.StatCapsUI:Refresh() end)
        end
    else
        pcall(function() TA:UpdateTalentHighlight() end)
    end
end)
