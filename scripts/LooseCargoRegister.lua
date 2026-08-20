--[[
FS25_LooseCargo
Version 1.0.5.0

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

            local activeCount = 0

            for typeName, typeEntry in pairs(vehicleTypes) do
                local specializations = typeEntry.specializations

                local hasFillUnit =
                    SpecializationUtil.hasSpecialization(FillUnit, specializations)

                if hasFillUnit then
                    local hasLooseCargo =
                        SpecializationUtil.hasSpecialization(
                            FS25LooseCargo,
                            specializations
                        )

                    if not hasLooseCargo then
                        g_vehicleTypeManager:addSpecialization(typeName, specName)
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
                "[%s] Active on %d FillUnit vehicle types; monitoring TRAILERS, TRAILERSSEMI and AUGERWAGONS.",
                modName,
                activeCount
            )
        end

        return originalValidateTypes(self, ...)
    end

end
