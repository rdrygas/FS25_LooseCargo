--[[
FS25_LooseCargo
Version 1.0.2.0

High-speed bulk cargo loss for uncovered:
  - trailers
  - semi-trailers
  - auger wagons

The specialization itself is installed on FillUnit vehicle types.
Concrete vehicles are filtered by their store category on load.
]]

FS25LooseCargo = {}

-- -------------------------------------------------------------------------
-- TUNING
-- -------------------------------------------------------------------------

FS25LooseCargo.MIN_SPEED_KMH = 25.0
FS25LooseCargo.REFERENCE_SPEED_KMH = 50.0
FS25LooseCargo.BASE_LOSS_PER_MINUTE = 0.01
FS25LooseCargo.MAX_LOSS_PER_MINUTE = 0.12

FS25LooseCargo.MIN_DENSITY_FACTOR = 0.50
FS25LooseCargo.MAX_DENSITY_FACTOR = 2.50

FS25LooseCargo.UPDATE_INTERVAL_MS = 1000

-- Store categories accepted by the mod.
-- StoreManager stores category names in upper case.
FS25LooseCargo.ALLOWED_CATEGORIES = {
    TRAILERS = true,
    TRAILERSSEMI = true,
    AUGERWAGONS = true
}

FS25LooseCargo.SPEC_NAME =
    string.format("spec_%s.looseCargo", g_currentModName or "FS25_LooseCargo")

-- -------------------------------------------------------------------------
-- SPECIALIZATION
-- -------------------------------------------------------------------------

function FS25LooseCargo.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(FillUnit, specializations)
end

function FS25LooseCargo.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", FS25LooseCargo)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", FS25LooseCargo)
end

local function joinCategoryNames(categoryNames)
    if categoryNames == nil or #categoryNames == 0 then
        return "<none>"
    end

    return table.concat(categoryNames, ",")
end

function FS25LooseCargo:isEligibleCargoVehicle()
    local storeItem = nil

    if g_storeManager ~= nil and self.configFileName ~= nil then
        storeItem = g_storeManager:getItemByXMLFilename(self.configFileName)
    end

    if storeItem == nil then
        return false, nil, nil
    end

    local categoryNames = storeItem.categoryNames or {}

    for _, categoryName in ipairs(categoryNames) do
        if FS25LooseCargo.ALLOWED_CATEGORIES[string.upper(categoryName)] then
            return true, storeItem, categoryNames
        end
    end

    return false, storeItem, categoryNames
end

function FS25LooseCargo:onLoad(savegame)
    local spec = self[FS25LooseCargo.SPEC_NAME]
    if spec == nil then
        return
    end

    spec.timer = 0

    local eligible, storeItem, categoryNames =
        FS25LooseCargo.isEligibleCargoVehicle(self)

    spec.isEligible = eligible

    -- Useful diagnostic while the mod is being tested. It is printed once
    -- for every loaded FillUnit vehicle, not every frame.
    local vehicleName = "<unknown>"
    if storeItem ~= nil and storeItem.name ~= nil then
        vehicleName = storeItem.name
    elseif self.getName ~= nil then
        vehicleName = self:getName()
    end

    Logging.info(
        "[FS25_LooseCargo] Vehicle='%s', categories='%s', eligible=%s",
        tostring(vehicleName),
        joinCategoryNames(categoryNames),
        tostring(eligible)
    )
end

-- -------------------------------------------------------------------------
-- COVER
-- -------------------------------------------------------------------------

-- A vehicle with no cover assigned to this fill unit is considered exposed.
-- Cover state 0 means all covers are closed. A state equal to cover.index
-- means that particular cover is open.
function FS25LooseCargo.isFillUnitExposed(vehicle, fillUnitIndex)
    local coverSpec = vehicle.spec_cover

    if coverSpec == nil or not coverSpec.hasCovers then
        return true
    end

    local fillUnitCovers =
        coverSpec.fillUnitIndexToCovers
        and coverSpec.fillUnitIndexToCovers[fillUnitIndex]

    if fillUnitCovers == nil or #fillUnitCovers == 0 then
        return true
    end

    for _, cover in ipairs(fillUnitCovers) do
        if coverSpec.state == cover.index then
            return true
        end
    end

    return false
end

-- -------------------------------------------------------------------------
-- FILL TYPES / DENSITY
-- -------------------------------------------------------------------------

function FS25LooseCargo.isBulkFillType(fillTypeIndex)
    if fillTypeIndex == nil or fillTypeIndex == FillType.UNKNOWN then
        return false
    end

    local desc = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
    if desc == nil then
        return false
    end

    return desc.isBulkType == true
       and desc.isPalletType ~= true
       and desc.isBaleType ~= true
end

function FS25LooseCargo.getDensityFactor(fillTypeIndex)
    local desc = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)

    if desc == nil
        or desc.massPerLiter == nil
        or desc.massPerLiter <= 0 then
        return 1.0
    end

    local referenceMass = desc.massPerLiter

    if FillType.WHEAT ~= nil then
        local wheatDesc = g_fillTypeManager:getFillTypeByIndex(FillType.WHEAT)

        if wheatDesc ~= nil
            and wheatDesc.massPerLiter ~= nil
            and wheatDesc.massPerLiter > 0 then
            referenceMass = wheatDesc.massPerLiter
        end
    end

    local factor = math.sqrt(referenceMass / desc.massPerLiter)

    return math.max(
        FS25LooseCargo.MIN_DENSITY_FACTOR,
        math.min(FS25LooseCargo.MAX_DENSITY_FACTOR, factor)
    )
end

function FS25LooseCargo.getLossRatePerMinute(speedKmh, densityFactor)
    if speedKmh <= FS25LooseCargo.MIN_SPEED_KMH then
        return 0
    end

    local speedRange =
        FS25LooseCargo.REFERENCE_SPEED_KMH
        - FS25LooseCargo.MIN_SPEED_KMH

    if speedRange <= 0 then
        return 0
    end

    local speedFactor =
        (speedKmh - FS25LooseCargo.MIN_SPEED_KMH) / speedRange

    local lossRate =
        FS25LooseCargo.BASE_LOSS_PER_MINUTE
        * speedFactor * speedFactor
        * densityFactor

    return math.min(FS25LooseCargo.MAX_LOSS_PER_MINUTE, lossRate)
end

-- -------------------------------------------------------------------------
-- UPDATE
-- -------------------------------------------------------------------------

function FS25LooseCargo:onUpdateTick(
    dt,
    isActiveForInput,
    isActiveForInputIgnoreSelection,
    isSelected
)
    local modSpec = self[FS25LooseCargo.SPEC_NAME]

    if modSpec == nil or not modSpec.isEligible then
        return
    end

    if not self.isServer then
        return
    end

    modSpec.timer = (modSpec.timer or 0) + dt

    if modSpec.timer < FS25LooseCargo.UPDATE_INTERVAL_MS then
        return
    end

    local elapsedMs = math.min(modSpec.timer, 5000)
    modSpec.timer = 0

    local rootVehicle = self:getRootVehicle()
    if rootVehicle == nil then
        return
    end

    -- Player-controlled vehicle only.
    if rootVehicle.getIsControlled == nil
        or not rootVehicle:getIsControlled() then
        return
    end

    -- Hired worker / AI excluded explicitly.
    if rootVehicle.getIsAIActive ~= nil
        and rootVehicle:getIsAIActive() then
        return
    end

    local speedKmh = nil

    if rootVehicle.getLastSpeed ~= nil then
        speedKmh = rootVehicle:getLastSpeed()
    elseif self.getLastSpeed ~= nil then
        speedKmh = self:getLastSpeed()
    end

    if speedKmh == nil then
        return
    end

    speedKmh = math.abs(speedKmh)

    if speedKmh <= FS25LooseCargo.MIN_SPEED_KMH then
        return
    end

    -- Do not add artificial cargo loss during intentional unloading.
    if self.getDischargeState ~= nil
        and Dischargeable ~= nil
        and self:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF then
        return
    end

    local fillUnits = self:getFillUnits()
    if fillUnits == nil then
        return
    end

    for fillUnitIndex, _ in ipairs(fillUnits) do
        local fillLevel = self:getFillUnitFillLevel(fillUnitIndex)

        if fillLevel ~= nil and fillLevel > 0.01 then
            local fillTypeIndex =
                self:getFillUnitFillType(fillUnitIndex)

            if FS25LooseCargo.isBulkFillType(fillTypeIndex)
                and FS25LooseCargo.isFillUnitExposed(
                    self,
                    fillUnitIndex
                ) then

                local densityFactor =
                    FS25LooseCargo.getDensityFactor(fillTypeIndex)

                local lossRatePerMinute =
                    FS25LooseCargo.getLossRatePerMinute(
                        speedKmh,
                        densityFactor
                    )

                if lossRatePerMinute > 0 then
                    local lossLiters =
                        fillLevel
                        * lossRatePerMinute
                        * (elapsedMs / 60000.0)

                    lossLiters = math.min(lossLiters, fillLevel)

                    if lossLiters > 0.001 then
                        self:addFillUnitFillLevel(
                            self:getOwnerFarmId(),
                            fillUnitIndex,
                            -lossLiters,
                            fillTypeIndex,
                            ToolType.UNDEFINED,
                            nil
                        )
                    end
                end
            end
        end
    end
end
