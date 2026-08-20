--[[
FS25_LooseCargo
Version 1.0.3.0

Inject the specialization into all vehicle types containing FillUnit.
Concrete vehicle filtering is performed in LooseCargo.lua by store category.
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

            local fillUnitTypeCount = 0
            local newlyAddedCount = 0
            local activeCount = 0

            for typeName, typeEntry in pairs(vehicleTypes) do
                local specializations = typeEntry.specializations

                local hasFillUnit =
                    SpecializationUtil.hasSpecialization(FillUnit, specializations)

                if hasFillUnit then
                    fillUnitTypeCount = fillUnitTypeCount + 1

                    local hasLooseCargo =
                        SpecializationUtil.hasSpecialization(
                            FS25LooseCargo,
                            specializations
                        )

                    if not hasLooseCargo then
                        if g_vehicleTypeManager:addSpecialization(typeName, specName) then
                            newlyAddedCount = newlyAddedCount + 1
                        end
                    end

                    -- Count the actual state after the attempted injection.
                    if SpecializationUtil.hasSpecialization(
                        FS25LooseCargo,
                        typeEntry.specializations
                    ) then
                        activeCount = activeCount + 1
                    end
                end
            end

            Logging.info(
                "[%s] FillUnit vehicle types: %d; newly added: %d; specialization active on: %d.",
                modName,
                fillUnitTypeCount,
                newlyAddedCount,
                activeCount
            )
        end

        return originalValidateTypes(self, ...)
    end

    Logging.info("[%s] Specialization injector installed.", modName)
end
