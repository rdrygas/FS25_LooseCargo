--[[
FS25_LooseCargo
Version 1.0.2.0

The specialization is injected into every vehicle type containing FillUnit.
The final scope (trailers / semi-trailers / auger wagons) is determined
per concrete vehicle from its store category in LooseCargo.lua.

This deliberately avoids relying on Trailer / Pipe specializations because
those did not identify FS25's actual vehicle types reliably.
]]

local modName = g_currentModName or "FS25_LooseCargo"
local specName = modName .. ".looseCargo"
local guardName = modName .. "_looseCargoSpecInjected"

if not _G[guardName] then
    _G[guardName] = true

    local originalValidateTypes = TypeManager.validateTypes

    TypeManager.validateTypes = function(self, ...)
        if self.typeName == "vehicle" then
            local vehicleTypes = g_vehicleTypeManager:getTypes()
            local addedCount = 0
            local fillUnitTypeCount = 0

            for typeName, typeEntry in pairs(vehicleTypes) do
                local specializations = typeEntry.specializations

                local hasFillUnit =
                    SpecializationUtil.hasSpecialization(FillUnit, specializations)

                local alreadyAdded =
                    SpecializationUtil.hasSpecialization(FS25LooseCargo, specializations)

                if hasFillUnit then
                    fillUnitTypeCount = fillUnitTypeCount + 1

                    if not alreadyAdded then
                        if g_vehicleTypeManager:addSpecialization(typeName, specName) then
                            addedCount = addedCount + 1
                        end
                    end
                end
            end

            Logging.info(
                "[%s] Found %d vehicle types with FillUnit; added specialization to %d types.",
                modName,
                fillUnitTypeCount,
                addedCount
            )
        end

        return originalValidateTypes(self, ...)
    end

    Logging.info("[%s] Specialization injector installed.", modName)
end
