local addonName, NS = ...

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    AllianceEngineDB = AllianceEngineDB or {
        brand = "IllusoryBias",
        rosterPlan = "26-Race / 13-Class Zero-Duplicate Alliance",
        wave = 1,
    }
    local faction = UnitFactionGroup("player")
    if faction ~= "Alliance" then return end

    if _G.WOWEngine then
        _G.WOWEngine:RegisterModule("AllianceEngine", {
            version = "1.3.10",
            brand = "IllusoryBias",
            faction = "Alliance",
            plan = AllianceEngineDB.rosterPlan,
        })
        _G.WOWEngine:Print("AllianceEngine v1.3.10 active (IllusoryBias integrated | Zero-Duplicate Alliance Suite).")
    end
end)
