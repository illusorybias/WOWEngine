local addonName, NS = ...

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    HordeEngineDB = HordeEngineDB or {
        brand = "IllusoryBias",
        rosterPlan = "18-Character / 27-Tree / 4-Wave Horde",
        wave = 1,
    }
    local faction = UnitFactionGroup("player")
    if faction ~= "Horde" then return end

    if _G.WOWEngine then
        _G.WOWEngine:RegisterModule("HordeEngine", {
            version = "1.3.10",
            brand = "IllusoryBias",
            faction = "Horde",
            plan = HordeEngineDB.rosterPlan,
        })
        _G.WOWEngine:Print("HordeEngine v1.3.10 active (IllusoryBias integrated | 4-Wave Horde Suite).")
    end
end)
