--[[
FS25_LooseCargo

High-speed bulk cargo loss for uncovered trailers / auger wagons.
]]

FS25LooseCargo = {}

-- -------------------------------------------------------------------------
-- TUNING
-- -------------------------------------------------------------------------

-- No cargo loss at or below this speed.
FS25LooseCargo.MIN_SPEED_KMH = 25.0

-- At this speed wheat loses BASE_LOSS_PER_MINUTE of the CURRENT load
-- during one minute of continuous driving with an uncovered cargo area.
FS25LooseCargo.REFERENCE_SPEED_KMH = 50.0

-- 0.01 = 1% of current load per minute at REFERENCE_SPEED_KMH for wheat.
FS25LooseCargo.BASE_LOSS_PER_MINUTE = 0.01

-- Safety cap: maximum fraction of current load that may be lost per minute.
-- 0.12 = 12% per minute.
FS25LooseCargo.MAX_LOSS_PER_MINUTE = 0.12

-- Density modifier limits. A very light custom fillType will therefore not
-- produce absurdly high loss rates.
FS25LooseCargo.MIN_DENSITY_FACTOR = 0.50
FS25LooseCargo.MAX_DENSITY_FACTOR = 2.50

-- Cargo loss is calculated once per second instead of every frame.
FS25LooseCargo.UPDATE_INTERVAL_MS = 1000

-- -------------------------------------------------------------------------
-- SPECIALIZATION
-- -------------------------------------------------------------------------

function FS25LooseCargo.prerequisitesPresent(specializations)
    local hasFillUnit = SpecializationUtil.hasSpecialization(FillUnit, specializations)
    local hasTrailer = SpecializationUtil.hasSpecialization(Trailer, specializations)
    local hasPipe = SpecializationUtil.hasSpecialization(Pipe, specializations)
    local hasAttachable = SpecializationUtil.hasSpecialization(Attachable, specializations)

    return hasFillUnit and (hasTrailer or (hasPipe and hasAttachable))
end

function FS25LooseCargo.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", FS25LooseCargo)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", FS25LooseCargo)
end

FS25LooseCargo.SPEC_NAME =
    string.format("spec_%s.looseCargo", g_currentModName or "FS25_LooseCargo")

function FS25LooseCargo:onLoad(savegame)
    local spec = self[FS25LooseCargo.SPEC_NAME]
    if spec ~= nil then
        spec.timer = 0
    end
end

-- Returns true if the cargo in this fill unit is exposed to the air.
--
-- Cover specialization convention in FS25:
--   state == 0          -> all covers closed
--   state == cover.index -> that cover is open
--
-- A vehicle without a cover, or a fill unit that has no assigned cover,
-- is treated as uncovered.
function FS25LooseCargo.isFillUnitExposed(vehicle, fillUnitIndex)
    local coverSpec = vehicle.spec_cover

    if coverSpec == nil or not coverSpec.hasCovers then
        return true
    end

    local fillUnitCovers = coverSpec.fillUnitIndexToCovers
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

-- Only real bulk materials are handled.
-- This automatically follows base-game and mod/map fillTypes that correctly
-- mark themselves as bulk, rather than relying on a hard-coded list.
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

-- Lighter cargo is lost faster.
--
-- We normalize density against wheat, so the calculation does not depend on
-- the absolute internal mass unit. sqrt() keeps differences noticeable but
-- not excessively strong:
--
--     factor = sqrt(wheatDensity / cargoDensity)
--
-- Examples:
--   same density as wheat -> 1.0
--   4x lighter            -> 2.0
--   4x heavier            -> 0.5
function FS25LooseCargo.getDensityFactor(fillTypeIndex)
    local desc = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
    if desc == nil or desc.massPerLiter == nil or desc.massPerLiter <= 0 then
        return 1.0
    end

    local referenceMass = desc.massPerLiter

    if FillType.WHEAT ~= nil then
        local wheatDesc = g_fillTypeManager:getFillTypeByIndex(FillType.WHEAT)
        if wheatDesc ~= nil and wheatDesc.massPerLiter ~= nil and wheatDesc.massPerLiter > 0 then
            referenceMass = wheatDesc.massPerLiter
        end
    end

    local factor = math.sqrt(referenceMass / desc.massPerLiter)

    return math.max(
        FS25LooseCargo.MIN_DENSITY_FACTOR,
        math.min(FS25LooseCargo.MAX_DENSITY_FACTOR, factor)
    )
end

-- Returns the fraction of the current load lost per minute.
function FS25LooseCargo.getLossRatePerMinute(speedKmh, densityFactor)
    if speedKmh <= FS25LooseCargo.MIN_SPEED_KMH then
        return 0
    end

    local speedRange = FS25LooseCargo.REFERENCE_SPEED_KMH
                     - FS25LooseCargo.MIN_SPEED_KMH

    if speedRange <= 0 then
        return 0
    end

    local speedFactor = (speedKmh - FS25LooseCargo.MIN_SPEED_KMH) / speedRange

    -- Quadratic curve:
    -- 25 km/h -> 0
    -- 50 km/h -> 1.00 x base rate
    -- 75 km/h -> 4.00 x base rate
    local lossRate = FS25LooseCargo.BASE_LOSS_PER_MINUTE
                   * speedFactor * speedFactor
                   * densityFactor

    return math.min(FS25LooseCargo.MAX_LOSS_PER_MINUTE, lossRate)
end

function FS25LooseCargo:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    -- Fill-level changes must be performed by the server side of the vehicle.
    if not self.isServer then
        return
    end

    local modSpec = self[FS25LooseCargo.SPEC_NAME]
    if modSpec == nil then
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

    -- Player-controlled vehicles only.
    if rootVehicle.getIsControlled == nil or not rootVehicle:getIsControlled() then
        return
    end

    -- Explicitly exclude hired workers / AI jobs.
    if rootVehicle.getIsAIActive ~= nil and rootVehicle:getIsAIActive() then
        return
    end

    local speedKmh
    if rootVehicle.getLastSpeed ~= nil then
        speedKmh = rootVehicle:getLastSpeed()
    elseif self.getLastSpeed ~= nil then
        speedKmh = self:getLastSpeed()
    else
        return
    end

    speedKmh = math.abs(speedKmh or 0)

    if speedKmh <= FS25LooseCargo.MIN_SPEED_KMH then
        return
    end

    -- Do not add our artificial loss while the trailer is deliberately
    -- discharging through its normal discharge system.
    if self.getDischargeState ~= nil
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
            local fillTypeIndex = self:getFillUnitFillType(fillUnitIndex)

            if FS25LooseCargo.isBulkFillType(fillTypeIndex)
               and FS25LooseCargo.isFillUnitExposed(self, fillUnitIndex) then

                local densityFactor = FS25LooseCargo.getDensityFactor(fillTypeIndex)
                local lossRatePerMinute =
                    FS25LooseCargo.getLossRatePerMinute(speedKmh, densityFactor)

                if lossRatePerMinute > 0 then
                    local lossLiters =
                        fillLevel * lossRatePerMinute * (elapsedMs / 60000.0)

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
