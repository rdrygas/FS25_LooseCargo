--[[
FS25_LooseCargo
Version 1.2.0.0

High-speed bulk cargo loss for uncovered:
  - trailers
  - semi-trailers
  - auger wagons

The specialization itself is installed on FillUnit vehicle types.
Concrete vehicles are filtered by their store category on load.
]]

FS25LooseCargo = {}

-- Configuration
FS25LooseCargo.MIN_SPEED_KMH = 25.0
FS25LooseCargo.REFERENCE_SPEED_KMH = 50.0
FS25LooseCargo.BASE_LOSS_PER_MINUTE = 0.01
FS25LooseCargo.MAX_LOSS_PER_MINUTE = 0.12
FS25LooseCargo.MIN_EXPOSED_FILL_PERCENT = 0.25
FS25LooseCargo.MIN_DENSITY_FACTOR = 0.50
FS25LooseCargo.MAX_DENSITY_FACTOR = 2.50
FS25LooseCargo.UPDATE_INTERVAL_MS = 1000
FS25LooseCargo.WARNING_DURATION_MS = 3000
FS25LooseCargo.WARNING_COOLDOWN_MS = 5000

FS25LooseCargo.ALLOWED_CATEGORIES = {
    TRAILERS = true,
    TRAILERSSEMI = true,
    AUGERWAGONS = true
}

FS25LooseCargo.SPEC_NAME =
    string.format("spec_%s.looseCargo", g_currentModName or "FS25_LooseCargo")

-- Determine if the vehicle has the prerequisites for the LooseCargo specialization.
function FS25LooseCargo.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(FillUnit, specializations)
end

-- Register the LooseCargo specialization for vehicles that have FillUnit.
function FS25LooseCargo.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", FS25LooseCargo)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", FS25LooseCargo)
end

-- Determine if the vehicle is eligible for loose cargo loss based on its store category.
function FS25LooseCargo:isEligibleCargoVehicle()
    if g_storeManager == nil or self.configFileName == nil then
        return false
    end

    local storeItem = g_storeManager:getItemByXMLFilename(self.configFileName)
    if storeItem == nil then
        return false
    end

    for _, categoryName in ipairs(storeItem.categoryNames or {}) do
        if FS25LooseCargo.ALLOWED_CATEGORIES[string.upper(categoryName)] then
            return true
        end
    end

    return false
end

-- Initialize the specialization.
function FS25LooseCargo:onLoad(savegame)
    local spec = self[FS25LooseCargo.SPEC_NAME]
    if spec == nil then
        return
    end

    spec.timer = 0
    spec.isEligible = FS25LooseCargo.isEligibleCargoVehicle(self)
    spec.wasLosingCargo = false
end

-- Determine if the fill unit is exposed to the environment based on cover state.
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

-- Determine if the fill type is considered "loose cargo" based on its category or properties.
function FS25LooseCargo.isLooseCargoFillType(fillTypeIndex)
    if fillTypeIndex == nil or fillTypeIndex == FillType.UNKNOWN then
        return false
    end

    local desc = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
    if desc == nil then
        return false
    end

    return g_fillTypeManager:getIsFillTypeInCategory(fillTypeIndex, "BULK")
        or desc.isBulkType == true
end

-- Calculate the density factor based on the fill type's mass per liter relative to wheat.
function FS25LooseCargo.getDensityFactor(fillTypeIndex)
    local desc = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)

    if desc == nil or desc.massPerLiter == nil or desc.massPerLiter <= 0 then
        return 1.0
    end

    local referenceMass = desc.massPerLiter
    local wheatDesc = nil

    if FillType.WHEAT ~= nil then
        wheatDesc = g_fillTypeManager:getFillTypeByIndex(FillType.WHEAT)
    end

    if wheatDesc ~= nil
        and wheatDesc.massPerLiter ~= nil
        and wheatDesc.massPerLiter > 0 then
        referenceMass = wheatDesc.massPerLiter
    end

    local factor = math.sqrt(referenceMass / desc.massPerLiter)

    return math.max(
        FS25LooseCargo.MIN_DENSITY_FACTOR,
        math.min(FS25LooseCargo.MAX_DENSITY_FACTOR, factor)
    )
end

-- Calculate the exposure factor based on the fill level percentage of the fill unit.
function FS25LooseCargo.getExposureFactor(vehicle, fillUnitIndex)
    local fillPct = vehicle:getFillUnitFillLevelPercentage(fillUnitIndex)

    if fillPct == nil then
        return 1.0
    end

    if fillPct <= FS25LooseCargo.MIN_EXPOSED_FILL_PERCENT then
        return 0.0
    end

    local range = 1.0 - FS25LooseCargo.MIN_EXPOSED_FILL_PERCENT
    local factor =
        (fillPct - FS25LooseCargo.MIN_EXPOSED_FILL_PERCENT) / range

    return math.max(0.0, math.min(1.0, factor))
end

-- Calculate the loss rate per minute based on speed and density factor.
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

-- Show a warning to the player when cargo is being lost.
function FS25LooseCargo.showCargoLossWarning(rootVehicle)
    if g_currentMission == nil
        or g_currentMission.showBlinkingWarning == nil
        or g_i18n == nil then
        return
    end

    local currentTime = g_currentMission.time or 0
    local lastWarningTime = rootVehicle.fs25LooseCargoLastWarningTime

    if lastWarningTime ~= nil
        and currentTime - lastWarningTime < FS25LooseCargo.WARNING_COOLDOWN_MS then
        return
    end

    rootVehicle.fs25LooseCargoLastWarningTime = currentTime

    g_currentMission:showBlinkingWarning(
        g_i18n:getText("FS25_LooseCargo_warningCargoLoss"),
        FS25LooseCargo.WARNING_DURATION_MS
    )
end

-- Update function for the LooseCargo specialization.
function FS25LooseCargo:onUpdateTick(
    dt,
    isActiveForInput,
    isActiveForInputIgnoreSelection,
    isSelected
)
    local spec = self[FS25LooseCargo.SPEC_NAME]

    if spec == nil or not spec.isEligible or not self.isServer then
        return
    end

    spec.timer = (spec.timer or 0) + dt

    if spec.timer < FS25LooseCargo.UPDATE_INTERVAL_MS then
        return
    end

    local elapsedMs = math.min(spec.timer, 5000)
    spec.timer = 0

    local rootVehicle = self:getRootVehicle()
    if rootVehicle == nil then
        spec.wasLosingCargo = false
        return
    end

    -- Only process if the vehicle is controlled by the player and not AI.
    if rootVehicle.getIsControlled == nil or not rootVehicle:getIsControlled() then
        spec.wasLosingCargo = false
        return
    end

    -- Skip processing if the vehicle is AI-controlled.
    if rootVehicle.getIsAIActive ~= nil and rootVehicle:getIsAIActive() then
        spec.wasLosingCargo = false
        return
    end

    local speedKmh = nil

    -- Determine the vehicle's speed in km/h using available methods.
    if rootVehicle.getLastSpeed ~= nil then
        speedKmh = rootVehicle:getLastSpeed()
    elseif self.getLastSpeed ~= nil then
        speedKmh = self:getLastSpeed()
    end

    -- Skip processing if the speed is not available.
    if speedKmh == nil then
        spec.wasLosingCargo = false
        return
    end

    speedKmh = math.abs(speedKmh)

    -- Skip processing if the vehicle is moving below the minimum speed threshold.
    if speedKmh <= FS25LooseCargo.MIN_SPEED_KMH then
        spec.wasLosingCargo = false
        return
    end

    -- Skip processing if the vehicle is currently discharging.
    if self.getDischargeState ~= nil
        and Dischargeable ~= nil
        and self:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF then
        spec.wasLosingCargo = false
        return
    end

    local fillUnits = self:getFillUnits()
    if fillUnits == nil then
        spec.wasLosingCargo = false
        return
    end

    local isLosingCargo = false

    -- Iterate over all fill units and calculate cargo loss for eligible loose cargo fill types.
    for fillUnitIndex, _ in ipairs(fillUnits) do
        local fillLevel = self:getFillUnitFillLevel(fillUnitIndex)

        if fillLevel ~= nil and fillLevel > 0.01 then
            local fillTypeIndex = self:getFillUnitFillType(fillUnitIndex)

            if FS25LooseCargo.isLooseCargoFillType(fillTypeIndex)
                and FS25LooseCargo.isFillUnitExposed(self, fillUnitIndex) then
                local densityFactor =
                    FS25LooseCargo.getDensityFactor(fillTypeIndex)

                local exposureFactor =
                    FS25LooseCargo.getExposureFactor(self, fillUnitIndex)

                local lossRatePerMinute =
                    FS25LooseCargo.getLossRatePerMinute(
                        speedKmh,
                        densityFactor
                    ) * exposureFactor

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

                        isLosingCargo = true
                    end
                end
            end
        end
    end

    -- Show a warning if cargo is being lost and it wasn't losing cargo in the previous update.
    if isLosingCargo and not spec.wasLosingCargo then
        FS25LooseCargo.showCargoLossWarning(rootVehicle)
    end

    spec.wasLosingCargo = isLosingCargo
end
