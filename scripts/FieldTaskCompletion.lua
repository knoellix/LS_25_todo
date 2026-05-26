--[[
    FieldTaskCompletion.lua
    Modular auto-complete: vanilla-style field coverage (98%) vs point/grass-specific handlers.
]]

FieldTaskCompletion = {}

FieldTaskCompletion.COMPLETION_THRESHOLD = 0.98
FieldTaskCompletion.SAMPLE_GRID_STEPS = 5

--- Registry entry:
---   strategy = "coverage" | "sample" | "grass" | "point" | "none"
---   densityTargets = string[]  (FieldGroundType names, vanilla contract density map)
---   grassStep = "mow" | "swath" | "collect"  (grass strategy only)
---   coverageOnly = true  -> task completes only when ratio >= threshold (no center shortcut)
FieldTaskCompletion.REGISTRY = {
    plow = {
        strategy = "coverage",
        densityTargets = { "PLOWED" },
        coverageOnly = true,
    },
    cultivate = {
        strategy = "coverage",
        densityTargets = { "CULTIVATED", "SEEDBED" },
        coverageOnly = true,
    },
    roller = {
        strategy = "coverage",
        densityTargets = { "ROLLER_LINES" },
        coverageOnly = true,
    },
    sow = {
        strategy = "coverage",
        densityTargets = { "SOWN", "PLANTED", "RIDGE_SOWN" },
        coverageOnly = true,
    },
    stones = {
        strategy = "sample",
        coverageOnly = true,
    },
    lime = {
        strategy = "sample",
        coverageOnly = true,
    },
    -- grass_swath / grass_collect: no windrow in fieldState; 98% grid + baseline heuristics in isActionComplete.
    grass_mow = {
        strategy = "grass",
        grassStep = "mow",
        coverageOnly = true,
    },
    grass_swath = {
        strategy = "grass",
        grassStep = "swath",
        coverageOnly = true,
    },
    grass_collect = {
        strategy = "grass",
        grassStep = "collect",
        coverageOnly = true,
    },
    harvest = { strategy = "point" },
    weed_combat = { strategy = "point" },
    weed_watch = { strategy = "point" },
    pf_ph = { strategy = "point" },
    pf_n = { strategy = "point" },
    scs_moisture = { strategy = "point" },
    scs_stress_high = { strategy = "point" },
    scs_stress_watch = { strategy = "point" },
    withered = { strategy = "point" },
    grass_bale = { strategy = "none" },
    grass_silage_bale = { strategy = "none" },
}

--- Register or override a completion strategy (e.g. mod extensions, new fruit workflows).
---@param actionType string
---@param entry table
function FieldTaskCompletion.registerEntry(actionType, entry)
    if string.isNilOrWhitespace(actionType) or entry == nil then
        return
    end

    FieldTaskCompletion.REGISTRY[actionType] = entry
end

---@param actionType string|nil
---@return table|nil
function FieldTaskCompletion.getEntry(actionType)
    if actionType == nil then
        return nil
    end

    return FieldTaskCompletion.REGISTRY[actionType]
end

---@param actionType string|nil
---@return boolean
function FieldTaskCompletion.isAutoTrackable(actionType)
    local entry = FieldTaskCompletion.getEntry(actionType)
    return entry ~= nil and entry.strategy ~= "none"
end

---@param entry table|nil
---@return boolean
function FieldTaskCompletion.requiresCoverageOnly(entry)
    return entry ~= nil and entry.coverageOnly == true
end

---@return number
function FieldTaskCompletion.getThreshold()
    return FieldTaskCompletion.COMPLETION_THRESHOLD
end

---@return number
function FieldTaskCompletion.getSampleGridSteps()
    return FieldTaskCompletion.SAMPLE_GRID_STEPS
end

---@param field table
---@param groundTypeName string
---@return number|nil
function FieldTaskCompletion.getDensityMapGroundRatio(field, groundTypeName)
    if field == nil
        or string.isNilOrWhitespace(groundTypeName)
        or g_currentMission == nil
        or g_currentMission.fieldGroundSystem == nil
        or FieldGroundType == nil
        or FieldDensityMap == nil
        or DensityMapModifier == nil
        or DensityMapFilter == nil
        or DensityValueCompareType == nil
        or field.densityMapPolygon == nil then
        return nil
    end

    local targetValue = nil
    if FieldGroundType.getValueByType ~= nil then
        local ok, value = pcall(FieldGroundType.getValueByType, FieldGroundType, groundTypeName)
        if ok then
            targetValue = value
        end
    end

    if targetValue == nil and FieldGroundType[groundTypeName] ~= nil then
        targetValue = FieldGroundType[groundTypeName]
    end

    if targetValue == nil then
        return nil
    end

    local ok, _sumPixels, completedArea, totalArea = pcall(function()
        local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels =
            g_currentMission.fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)

        local modifier = DensityMapModifier.new(
            groundTypeMapId,
            groundTypeFirstChannel,
            groundTypeNumChannels,
            g_terrainNode
        )
        local filter = DensityMapFilter.new(modifier)
        filter:setValueCompareParams(DensityValueCompareType.EQUAL, targetValue)

        field.densityMapPolygon:applyToModifier(modifier)
        return modifier:executeGet(filter)
    end)

    if not ok or totalArea == nil or totalArea <= 0 then
        return nil
    end

    local doneArea = completedArea or 0
    return math.min(1, doneArea / totalArea)
end

---@param field table
---@param densityTargets string[]|nil
---@return number|nil
function FieldTaskCompletion.getDensityCoverageRatio(field, densityTargets)
    if densityTargets == nil or #densityTargets == 0 then
        return nil
    end

    local bestRatio = nil
    for _, groundTypeName in ipairs(densityTargets) do
        local ratio = FieldTaskCompletion.getDensityMapGroundRatio(field, groundTypeName)
        if ratio ~= nil and (bestRatio == nil or ratio > bestRatio) then
            bestRatio = ratio
        end
    end

    return bestRatio
end

---@param field table
---@param centerX number
---@param centerZ number
---@return table[]
function FieldTaskCompletion.collectSamplePoints(field, centerX, centerZ)
    local points = {}
    points[#points + 1] = { x = centerX, z = centerZ }

    local areaHa = tonumber(field ~= nil and field.areaHa) or 0
    if areaHa <= 0 then
        return points
    end

    local areaM2 = areaHa * 10000
    local halfExtent = math.max(8, math.sqrt(areaM2) * 0.45)
    local steps = math.max(1, FieldTaskCompletion.getSampleGridSteps())

    for ix = -steps, steps do
        for iz = -steps, steps do
            if not (ix == 0 and iz == 0) then
                local sampleX = centerX + (ix / steps) * halfExtent
                local sampleZ = centerZ + (iz / steps) * halfExtent
                if FieldAdvisor.isPositionInsideField(field, sampleX, sampleZ) then
                    points[#points + 1] = { x = sampleX, z = sampleZ }
                end
            end
        end
    end

    return points
end

---@param field table
---@param task table
---@param centerX number
---@param centerZ number
---@return number|nil
function FieldTaskCompletion.getSampleGridRatio(field, task, centerX, centerZ)
    if field == nil or task == nil or FieldAdvisor == nil then
        return nil
    end

    local points = FieldTaskCompletion.collectSamplePoints(field, centerX, centerZ)
    if #points == 0 then
        return nil
    end

    local total = 0
    local completed = 0

    for _, point in ipairs(points) do
        local sampleState = FieldAdvisor.getEnrichedFieldState(field, task.fieldId, point.x, point.z)
        local sampleContext = FieldAdvisor.buildFieldContext(field, sampleState, point.x, point.z)

        total = total + 1
        if FieldTaskCompletion.isActionComplete(task.actionType, sampleContext, task) then
            completed = completed + 1
        end
    end

    if field.fieldState ~= nil and field.fieldState.update ~= nil then
        field.fieldState:update(centerX, centerZ)
    end

    if total <= 0 then
        return nil
    end

    return completed / total
end

--- Standard field work (plow, sow, roller, …): density map like vanilla contracts, else 98% sample grid.
---@param field table
---@param task table
---@param centerX number
---@param centerZ number
---@param entry table
---@return number|nil
function FieldTaskCompletion.getCoverageStrategyRatio(field, task, centerX, centerZ, entry)
    local densityRatio = FieldTaskCompletion.getDensityCoverageRatio(field, entry.densityTargets)
    if densityRatio ~= nil then
        return densityRatio
    end

    return FieldTaskCompletion.getSampleGridRatio(field, task, centerX, centerZ)
end

--- Grass uses no reliable ground-type density target; 98% grid with grass-specific point checks only.
---@param field table
---@param task table
---@param centerX number
---@param centerZ number
---@param entry table
---@return number|nil
function FieldTaskCompletion.getGrassStrategyRatio(field, task, centerX, centerZ, entry)
    if entry.grassStep == nil then
        return nil
    end

    return FieldTaskCompletion.getSampleGridRatio(field, task, centerX, centerZ)
end

---@param field table
---@param task table
---@param centerX number
---@param centerZ number
---@return number|nil
function FieldTaskCompletion.getCompletionRatio(field, task, centerX, centerZ)
    if field == nil or task == nil then
        return nil
    end

    local entry = FieldTaskCompletion.getEntry(task.actionType)
    if entry == nil then
        return nil
    end

    if entry.strategy == "coverage" then
        return FieldTaskCompletion.getCoverageStrategyRatio(field, task, centerX, centerZ, entry)
    end

    if entry.strategy == "grass" then
        return FieldTaskCompletion.getGrassStrategyRatio(field, task, centerX, centerZ, entry)
    end

    if entry.strategy == "sample" then
        return FieldTaskCompletion.getSampleGridRatio(field, task, centerX, centerZ)
    end

    return nil
end

---@param actionType string
---@param context table
---@param actionMeta table|nil
---@return boolean
function FieldTaskCompletion.isActionComplete(actionType, context, actionMeta)
    if actionType == nil or actionType == "none" or context == nil then
        return false
    end

    local field = context.field
    local fieldState = context.fieldState
    local rules = context.rules or FieldGameRules.get()
    local pfSample = context.pfSample
    local scsSample = context.scsSample

    if actionType == "harvest" then
        return not FieldAdvisor.isHarvestReady(field, fieldState)
    end

    if actionType == "plow" then
        if FieldAdvisor.isWithered(fieldState) then
            return false
        end

        if not rules.plowingRequiredEnabled then
            return true
        end

        if FieldAdvisor.getGroundTypeName(fieldState) == "PLOWED" and not context.needsPlowing then
            return true
        end

        return false
    end

    if actionType == "cultivate" then
        if FieldAdvisor.isWithered(fieldState) then
            return false
        end

        if FieldAdvisor.hasActiveCrop(fieldState) then
            return false
        end

        local groundType = FieldAdvisor.getGroundTypeName(fieldState)
        if FieldAdvisor.groundTypeIsOneOf(groundType, { "CULTIVATED", "SEEDBED" }) then
            return true
        end

        local isCultivated = FieldAdvisor.getStateBool(fieldState, "isCultivated")
            or FieldAdvisor.getStateBool(fieldState, "cultivated")
            or FieldAdvisor.getStateBool(fieldState, "seedbed")
            or FieldAdvisor.getStateBool(fieldState, "isSeedbed")

        if isCultivated then
            return true
        end

        return false
    end

    if actionType == "lime" then
        if not rules.limeRequired then
            return true
        end

        return not context.needsLime and context.limeLevel <= 0
    end

    if actionType == "weed_combat" or actionType == "weed_watch" then
        if not rules.weedsEnabled then
            return true
        end

        return FieldAdvisor.isWeedDeadOrSprayed(fieldState)
            or FieldAdvisor.getEffectiveWeedPressure(fieldState) <= FieldAdvisor.WEED_FACTOR_COMPLETE_THRESHOLD
    end

    if actionType == "stones" then
        if not rules.stonesEnabled then
            return true
        end

        return context.stoneLevel <= 0
    end

    if actionType == "roller" then
        if FieldAdvisor.isWithered(fieldState) then
            return false
        end

        if FieldAdvisor.getGroundTypeName(fieldState) == "ROLLER_LINES" then
            return true
        end

        return not context.needsRolling and context.rollerLevel <= 0
    end

    if actionType == "pf_ph" then
        if not PrecisionFarmingReader.isRuntimeReady() then
            return true
        end

        if pfSample == nil or pfSample.pHValue == nil then
            return false
        end

        return tonumber(pfSample.pHValue) >= 6.0
    end

    if actionType == "pf_n" then
        if not PrecisionFarmingReader.isRuntimeReady() then
            return true
        end

        if pfSample == nil or pfSample.nitrogenValue == nil then
            return false
        end

        local nitrogen = tonumber(pfSample.nitrogenValue) or 0
        if actionMeta ~= nil and actionMeta.fertPass ~= nil then
            local passTotal = tonumber(actionMeta.fertPassTotal) or 1
            local target = FieldAdvisor.getOrganicFertilizerPassTarget(actionMeta.fertPass, passTotal, 80)
            return nitrogen >= target
        end

        return nitrogen >= 80
    end

    if actionType == "scs_moisture" or actionType == "scs_stress_high" or actionType == "scs_stress_watch" then
        if SeasonalCropStressReader == nil
            or SeasonalCropStressReader.isRuntimeReady == nil
            or not SeasonalCropStressReader.isRuntimeReady() then
            return false
        end
    end

    if actionType == "scs_moisture" then
        if scsSample == nil or scsSample.moisture == nil then
            return false
        end

        return scsSample.moisture >= 0.25
    end

    if actionType == "scs_stress_high" then
        if scsSample == nil or scsSample.stress == nil then
            return false
        end

        return scsSample.stress < 0.6
    end

    if actionType == "scs_stress_watch" then
        if scsSample == nil or scsSample.stress == nil then
            return false
        end

        return scsSample.stress < 0.35
    end

    if actionType == "withered" then
        return not FieldAdvisor.isWithered(fieldState)
    end

    if actionType == "sow" then
        return FieldAdvisor.isFieldSown(fieldState) and not FieldAdvisor.isWithered(fieldState)
    end

    if actionType == "grass_mow" then
        return FieldAdvisor.isGrassCut(fieldState)
    end

    -- No reliable windrow marker in fieldState; baseline heuristics only.
    if actionType == "grass_swath" then
        if not FieldAdvisor.isGrassCut(fieldState) then
            return false
        end

        local stubbleShredLevel = FieldAdvisor.getStateNumber(fieldState, "stubbleShredLevel")
        local baseline = actionMeta ~= nil and actionMeta.completionBaseline or nil
        if baseline ~= nil and stubbleShredLevel > (baseline.stubbleShredLevel or 0) then
            return true
        end

        if baseline ~= nil then
            if FieldAdvisor.getLastGrowthState(fieldState) ~= (baseline.lastGrowthState or -1) then
                return true
            end

            if FieldAdvisor.getGrowthState(fieldState) ~= (baseline.growthState or -1) then
                return true
            end
        end

        return false
    end

    -- No reliable windrow marker in fieldState; baseline heuristics only.
    if actionType == "grass_collect" then
        local baseline = actionMeta ~= nil and actionMeta.completionBaseline or nil
        return FieldAdvisor.isGrassPostCutCleared(fieldState, baseline)
    end

    if actionType == "grass_bale" or actionType == "grass_silage_bale" then
        return false
    end

    return false
end

---@param task table
---@param context table
---@return boolean
function FieldTaskCompletion.hasPointProgress(task, context)
    if FieldAdvisor == nil or FieldAdvisor.hasCompletionProgress == nil then
        return false
    end

    return FieldAdvisor.hasCompletionProgress(task, context)
end

---@param task table
---@param scanner table
---@return boolean
function FieldTaskCompletion.isTaskComplete(task, scanner)
    if task == nil or task.source ~= "field" or task.completed or task.autoComplete ~= true then
        return false
    end

    local entry = FieldTaskCompletion.getEntry(task.actionType)
    if entry == nil or entry.strategy == "none" then
        return false
    end

    if task.actionType == "harvest_info" or task.actionType == "growing" or task.actionType == "custom" then
        return false
    end

    if scanner == nil or scanner.getEngineFieldById == nil then
        return false
    end

    local field = scanner:getEngineFieldById(task.fieldId)
    if field == nil or field.getCenterOfFieldWorldPosition == nil then
        return false
    end

    local posX, posZ = field:getCenterOfFieldWorldPosition()
    local threshold = FieldTaskCompletion.getThreshold()
    local ratio = FieldTaskCompletion.getCompletionRatio(field, task, posX, posZ)

    if FieldTaskCompletion.requiresCoverageOnly(entry) then
        return ratio ~= nil and ratio >= threshold
    end

    if ratio ~= nil then
        return ratio >= threshold
    end

    if entry.strategy ~= "point" or FieldAdvisor == nil then
        return false
    end

    local fieldState = FieldAdvisor.getEnrichedFieldState(field, task.fieldId, posX, posZ)
    local context = FieldAdvisor.buildFieldContext(field, fieldState, posX, posZ)

    if FieldTaskCompletion.isActionComplete(task.actionType, context, task) then
        return true
    end

    return FieldTaskCompletion.hasPointProgress(task, context)
end
