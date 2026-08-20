--[[
FS25_LooseCargo
Version 1.2.0.0

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
            local activeCount = 0

            for typeName, typeEntry in pairs(g_vehicleTypeManager:getTypes()) do
                local specializations = typeEntry.specializations

                if SpecializationUtil.hasSpecialization(FillUnit, specializations) then
                    if not SpecializationUtil.hasSpecialization(FS25LooseCargo, specializations) then
                        g_vehicleTypeManager:addSpecialization(typeName, specName)
                    end

                    if SpecializationUtil.hasSpecialization(FS25LooseCargo, typeEntry.specializations) then
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
