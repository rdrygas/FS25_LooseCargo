--[[
FS25_LooseCargo

Registers the LooseCargo specialization for vehicle types that behave like
bulk trailers/tippers. This includes the standard trailer and auger-wagon
family because auger wagons inherit the trailer/tipper specializations.
]]

FS25LooseCargoRegister = {}

FS25LooseCargoRegister.MOD_NAME = g_currentModName
FS25LooseCargoRegister.MOD_DIR = g_currentModDirectory
FS25LooseCargoRegister.SPEC_NAME = FS25LooseCargoRegister.MOD_NAME .. ".looseCargo"

local specializationFilename = Utils.getFilename("LooseCargo.lua", FS25LooseCargoRegister.MOD_DIR)

g_specializationManager:addSpecialization(
    FS25LooseCargoRegister.SPEC_NAME,
    "FS25LooseCargo",
    specializationFilename,
    nil
)

function FS25LooseCargoRegister.injectSpecialization(typeManager)
    if typeManager ~= g_vehicleTypeManager then
        return
    end

    local addedCount = 0

    for typeName, typeEntry in pairs(typeManager:getTypes()) do
        local specializations = typeEntry.specializations

        local hasFillUnit = SpecializationUtil.hasSpecialization(FillUnit, specializations)
        local hasTrailer = SpecializationUtil.hasSpecialization(Trailer, specializations)
        local hasPipe = SpecializationUtil.hasSpecialization(Pipe, specializations)
        local hasAttachable = SpecializationUtil.hasSpecialization(Attachable, specializations)

        -- Normal trailers/tippers are selected by Trailer.
        -- Pipe + Attachable is a fallback for auger-wagon style implements
        -- that may use a pipe but are not based on exactly the same trailer type.
        local isCargoTrailerType = hasTrailer or (hasPipe and hasAttachable)

        if hasFillUnit and isCargoTrailerType then
            if typeEntry.specializationsByName[FS25LooseCargoRegister.SPEC_NAME] == nil then
                if typeManager:addSpecialization(typeName, FS25LooseCargoRegister.SPEC_NAME) then
                    addedCount = addedCount + 1
                end
            end
        end
    end

    Logging.info(
        "[FS25_LooseCargo] Added specialization to %d bulk-trailer vehicle types.",
        addedCount
    )
end

-- Types have already been loaded when finalizeTypes() starts, but their
-- specialization event listeners have not yet been finalized. This is the
-- correct moment to inject our specialization.
TypeManager.finalizeTypes = Utils.prependedFunction(
    TypeManager.finalizeTypes,
    FS25LooseCargoRegister.injectSpecialization
)
