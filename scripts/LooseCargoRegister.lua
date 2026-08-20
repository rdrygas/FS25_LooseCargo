--[[
FS25_LooseCargo
Version 1.0.1.0

Global specialization injector.

Important:
The specialization must be added BEFORE TypeManager:validateTypes()
validates the vehicle types. This follows the same lifecycle pattern
used by FS25_NoDriveByFill.
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

            for typeName, typeEntry in pairs(vehicleTypes) do
                local specializations = typeEntry.specializations

                local hasFillUnit =
                    SpecializationUtil.hasSpecialization(FillUnit, specializations)

                local hasTrailer =
                    SpecializationUtil.hasSpecialization(Trailer, specializations)

                local hasPipe =
                    SpecializationUtil.hasSpecialization(Pipe, specializations)

                local hasAttachable =
                    SpecializationUtil.hasSpecialization(Attachable, specializations)

                local alreadyAdded =
                    SpecializationUtil.hasSpecialization(FS25LooseCargo, specializations)

                -- Standard trailers/tippers normally have Trailer.
                -- Pipe + Attachable is an additional fallback for auger-wagon
                -- style implements which may use a different vehicle type.
                local isCargoTrailerType =
                    hasTrailer or (hasPipe and hasAttachable)

                if hasFillUnit
                    and isCargoTrailerType
                    and not alreadyAdded then

                    if g_vehicleTypeManager:addSpecialization(typeName, specName) then
                        addedCount = addedCount + 1
                    end
                end
            end

            Logging.info(
                "[%s] Added specialization to %d bulk-trailer vehicle types.",
                modName,
                addedCount
            )
        end

        return originalValidateTypes(self, ...)
    end

    Logging.info("[%s] Specialization injector installed.", modName)
end
