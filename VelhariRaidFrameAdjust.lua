-- VelhariRaidFrameAdjust
-- Copyright (C) 2015 David H. Wei
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

local in_encounter = false
local run_hook = false
local update_ticker
local frame = CreateFrame("Frame")

local function CompactUnitFrame_UpdateMaxHealthHook(frame)
    if run_hook then
        local auraMaxPc = select(15, UnitAura("boss1", GetSpellInfo(179986)))
        local maxHealth = UnitHealthMax(frame.displayedUnit)
        frame.healthBar:SetMinMaxValues(0, maxHealth * (auraMaxPc / 100))
    end
end

local function CompactUnitFrame_Update()
    local auraMaxPc = select(15, UnitAura("boss1", GetSpellInfo(179986)))
    for i = 1, 40 do
        local frame = _G["CompactRaidFrame"..i]
        if frame and frame.displayedUnit then
            local maxHealth = UnitHealthMax(frame.displayedUnit)
            frame.healthBar:SetMinMaxValues(0, maxHealth * (auraMaxPc / 100))
        end
    end
end

local function CompactUnitFrame_Enable()
    hooksecurefunc("CompactUnitFrame_UpdateMaxHealth", CompactUnitFrame_UpdateMaxHealthHook)
    update_ticker = C_Timer.NewTicker(1.5, CompactUnitFrame_Update)
end

local function CompactUnitFrame_Disable()
    update_ticker:Cancel()
    for i = 1, 40 do
        local frame = _G["CompactRaidFrame"..i]
        if frame and frame.displayedUnit then
            local maxHealth = UnitHealthMax(frame.displayedUnit)
            frame.healthBar:SetMinMaxValues(0, maxHealth)
        end
    end
end

local Grid_raid_guids = {}
local Grid_old_SetStatus = {}

local function Grid_Hook()
    for _, frame in pairs(Grid:GetModule("GridFrame").registeredFrames) do
        local guid = frame.unitGUID
        if Grid_raid_guids[guid] then
            Grid_old_SetStatus[guid] = frame.indicators.bar.SetStatus
            function frame.indicators.bar:SetStatus(...)
                local color, text, value, maxValue, texture, texCoords, count, start, duration = ...
                -- Shouldn't need to check run_hook
                local auraMaxPc = select(15, UnitAura("boss1", GetSpellInfo(179986)))
                Grid_old_SetStatus[guid](self, color, text, value, maxValue * (auraMaxPc / 100), texture, texCoords, count, start, duration)
            end
        end
    end
end

local function Grid_Unhook()
    for _, frame in pairs(Grid:GetModule("GridFrame").registeredFrames) do
        local guid = frame.unitGUID
        if Grid_raid_guids[guid] then
            frame.indicators.bar.SetStatus = Grid_old_SetStatus[guid]
        end
    end
end

local function Grid_Update()
    local auraMaxPc = select(15, UnitAura("boss1", GetSpellInfo(179986)))
    for _, frame in pairs(Grid:GetModule("GridFrame").registeredFrames) do
        local guid = frame.unitGUID
        if Grid_raid_guids[guid] then
            local maxHealth = UnitHealthMax(frame.unit)
            frame.indicators.bar:SetMinMaxValues(0, maxHealth * (auraMaxPc / 100))
        end
    end
end

local function Grid_Enable()
    for i = 1, 40 do
        if UnitGUID("raid"..i) then
            Grid_raid_guids[UnitGUID("raid"..i)] = true
        end
    end
    Grid_Hook()
    update_ticker = C_Timer.NewTicker(1.5, Grid_Update)
end

local function Grid_Disable()
    update_ticker:Cancel()
    Grid_Unhook()
    for _, frame in pairs(Grid:GetModule("GridFrame").registeredFrames) do
        local guid = frame.unitGUID
        if Grid_raid_guids[guid] then
            local maxHealth = UnitHealthMax(frame.unit)
            frame.indicators.bar:SetMinMaxValues(0, maxHealth)
        end
    end
end

local function VUHDO_setHealthHook(aUnit, aMode)
    -- Hook never executes?
    if run_hook then
        local vuhdo_raid = _G["VUHDO_RAID"]
        local auraMaxPc = select(15, UnitAura("boss1", GetSpellInfo(179986)))
        local tInfo = vuhdo_raid[aUnit]
        local maxHealth = UnitHealthMax(aUnit)
        tInfo["healthmax"] = maxHealth * (auraMaxPc / 100)
    end
end

local function VuhDo_Update()
    local vuhdo_raid = _G["VUHDO_RAID"]
    local auraMaxPc = select(15, UnitAura("boss1", GetSpellInfo(179986)))
    for i = 1, 40 do
        local tInfo = vuhdo_raid["raid"..i]
        local maxHealth = UnitHealthMax("raid"..i)
        if tInfo then
            tInfo["healthmax"] = maxHealth * (auraMaxPc / 100)
        end
    end
    vuhdo_raid["player"]["healthmax"] = UnitHealthMax("player") * (auraMaxPc / 100)
end

local function VuhDo_Enable()
    hooksecurefunc("VUHDO_setHealth", VUHDO_setHealthHook)
    update_ticker = C_Timer.NewTicker(1.5, VuhDo_Update)
end

local function VuhDo_Disable()
    update_ticker:Cancel()
    local vuhdo_raid = _G["VUHDO_RAID"]
    for i = 1, 40 do
        local tInfo = vuhdo_raid["raid"..i]
        if tInfo then
            tInfo["healthmax"] = UnitHealthMax("raid"..i)
        end
    end
    vuhdo_raid["player"]["healthmax"] = UnitHealthMax("player")
end

local Velhari_Enable
local Velhari_Disable

-- Credit to Aleaa @ MMO-C forums
local function UnitAuraHandler(unitID)
    if unitID ~= "boss1" then return end
    local auraMaxPc = select(15, UnitAura(unitID, GetSpellInfo(179986)))
    if auraMaxPc then
        if not run_hook then
            run_hook = true
            Velhari_Enable()
        end
    else
        if run_hook then
            run_hook = false
            Velhari_Disable()
        end
    end
end

local function EventHandler(self, event, ...)
    local encounterID = ...
    if event == "PLAYER_ENTERING_WORLD" then
        print("VelhariFix loaded")
        if _G["VUHDO_RAID"] then
            print("VuhDo detected")
            Velhari_Enable = VuhDo_Enable
            Velhari_Disable = VuhDo_Disable
        elseif _G["Grid"] then
            print("Grid detected")
            Velhari_Enable = Grid_Enable
            Velhari_Disable = Grid_Disable
        else
            print("Default raid frames detected")
            Velhari_Enable = CompactUnitFrame_Enable
            Velhari_Disable = CompactUnitFrame_Disable
        end
    elseif event == "ENCOUNTER_START" and encounterID == 1784 then
        in_encounter = true
    elseif event == "ENCOUNTER_END" and encounterID == 1784 then
        in_encounter = false
        run_hook = false
        Velhari_Disable()
    elseif in_encounter and (event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA") then
        -- Did you just hearth?!
        in_encounter = false
        run_hook = false
        Velhari_Disable()
    elseif in_encounter and event == "UNIT_AURA" then
        UnitAuraHandler(...)
    end
end

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("UNIT_AURA")

frame:SetScript("OnEvent", EventHandler)
