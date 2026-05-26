--[[
    FieldAdvisor.lua
    Human-readable field condition labels and next-step suggestions (respects career rules).
]]

FieldAdvisor = {}

FieldAdvisor.WEED_LABELS = {
    [0] = "kein",
    [1] = "leicht",
    [2] = "mittel",
    [3] = "stark",
    [4] = "stark",
    [5] = "stark",
}

-- Internal fruit names that behave like grass (no plowing, usually no mineral fertilizing).
FieldAdvisor.GRASS_FRUIT_NAMES = {
    GRASS = true,
    MEADOW = true,
    PASTURE = true,
    GREENRYE = true,
    FIELDGRASS = true,
    ALFALFA = true,
    CLOVER = true,
    LUCERNE = true,
    MEDICK = true,
}
FieldAdvisor._defaultGrassFruitTypeIndex = nil
FieldAdvisor._defaultGrassFruitTypeResolved = false

FieldAdvisor.JOB_COMPLETION_THRESHOLD = FieldTaskCompletion ~= nil
    and FieldTaskCompletion.COMPLETION_THRESHOLD
    or 0.98
FieldAdvisor.JOB_SAMPLE_GRID_STEPS = FieldTaskCompletion ~= nil
    and FieldTaskCompletion.SAMPLE_GRID_STEPS
    or 5
FieldAdvisor.WEED_FACTOR_COMBAT_THRESHOLD = 0.05
FieldAdvisor.WEED_FACTOR_COMPLETE_THRESHOLD = 0.02
-- FS25 save/field state: high weed levels are dead/sprayed weeds on the map (brown), not live weeds.
FieldAdvisor.WEED_STATE_DEAD_MIN = 7

FieldAdvisor.SOIL_WORK_GROUND_TYPES = {
    "CULTIVATED",
    "SEEDBED",
    "PLOWED",
    "SOWN",
    "PLANTED",
    "RIDGE_SOWN",
}
FieldAdvisor.NON_GRASS_GROUND_TYPES = {
    "CULTIVATED",
    "SEEDBED",
    "PLOWED",
}

---@param fieldState table|nil
---@return boolean
function FieldAdvisor.isNonGrassSoilState(fieldState)
    if fieldState == nil then
        return false
    end

    local groundTypeName = FieldAdvisor.getGroundTypeName(fieldState)
    if FieldAdvisor.groundTypeIsOneOf(groundTypeName, FieldAdvisor.NON_GRASS_GROUND_TYPES) then
        return true
    end

    if FieldAdvisor.groundTypeIsOneOf(groundTypeName, { "SOWN", "PLANTED", "RIDGE_SOWN", "ROLLER_LINES" }) then
        local fruitTypeIndex = FieldAdvisor.getFruitTypeIndex(fieldState)
        if fruitTypeIndex ~= nil and fruitTypeIndex > 0 then
            if FruitType == nil or fruitTypeIndex ~= FruitType.UNKNOWN then
                return not FieldAdvisor.isGrassCrop(fruitTypeIndex)
            end
        end
    end

    return false
end

---@param fieldState table|nil
function FieldAdvisor.clearStaleGrassMetadata(fieldState)
    if fieldState == nil then
        return
    end

    local grassNameFields = {
        "fruitTypeName",
        "fruitType",
        "plannedFruit",
        "currentFruitType",
        "fruit",
    }

    for _, key in ipairs(grassNameFields) do
        local rawName = fieldState[key]
        if rawName ~= nil and rawName ~= ""
            and FieldAdvisor.GRASS_FRUIT_NAMES[string.upper(tostring(rawName))] == true then
            fieldState[key] = nil
        end
    end

    if FieldAdvisor.isGrassGroundType(FieldAdvisor.getGroundTypeName(fieldState)) then
        fieldState.groundType = nil
    end
end

---@param value any
---@return number
function FieldAdvisor.toNumber(value)
    local numberValue = tonumber(value)
    if numberValue == nil then
        return 0
    end

    return numberValue
end

---@param field table
---@return table|nil
function FieldAdvisor.getFieldState(field)
    if field == nil then
        return nil
    end

    if field.fieldState ~= nil then
        return field.fieldState
    end

    if field.getFieldState ~= nil then
        local success, fieldState = pcall(field.getFieldState, field)
        if success and type(fieldState) == "table" then
            return fieldState
        end
    end

    return nil
end

---@param worldX number|nil
---@param worldZ number|nil
---@return table|nil
function FieldAdvisor.getLiveFieldState(worldX, worldZ)
    if worldX == nil or worldZ == nil or FieldState == nil or FieldState.new == nil then
        return nil
    end

    local ok, liveState = pcall(FieldState.new)
    if not ok or liveState == nil or liveState.update == nil then
        return nil
    end

    local updated, _ = pcall(liveState.update, liveState, worldX, worldZ)
    if not updated then
        return nil
    end

    return liveState
end

---@param fieldState table|nil
---@param key string
---@return number
function FieldAdvisor.getStateNumber(fieldState, key)
    if fieldState == nil or fieldState[key] == nil then
        return 0
    end

    return FieldAdvisor.toNumber(fieldState[key])
end

---@param fieldState table|nil
---@param key string
---@return boolean
function FieldAdvisor.getStateBool(fieldState, key)
    if fieldState == nil or fieldState[key] == nil then
        return false
    end

    return fieldState[key] == true
end

FieldAdvisor.groundTypeNameByValue = nil

---@param raw any
---@return string
function FieldAdvisor.resolveGroundTypeName(raw)
    if raw == nil then
        return ""
    end

    if type(raw) == "string" then
        local name = string.upper(raw)
        if name ~= "" and not string.match(name, "^%d+$") then
            return name
        end
    end

    local value = tonumber(raw)
    if value == nil then
        return ""
    end

    if value == 0 then
        return "NONE"
    end

    if FieldGroundType ~= nil then
        if FieldAdvisor.groundTypeNameByValue == nil then
            FieldAdvisor.groundTypeNameByValue = {}

            for name, enumValue in pairs(FieldGroundType) do
                if type(name) == "string" and type(enumValue) == "number" then
                    FieldAdvisor.groundTypeNameByValue[enumValue] = name
                elseif type(enumValue) == "string" and FieldGroundType.getValueByType ~= nil then
                    local ok, resolvedValue = pcall(FieldGroundType.getValueByType, FieldGroundType, enumValue)
                    if ok and resolvedValue ~= nil then
                        FieldAdvisor.groundTypeNameByValue[resolvedValue] = enumValue
                    end
                end
            end
        end

        local resolvedName = FieldAdvisor.groundTypeNameByValue[value]
        if resolvedName ~= nil then
            return resolvedName
        end
    end

    return ""
end

---@param fieldState table|nil
---@return string
function FieldAdvisor.getGroundTypeName(fieldState)
    if fieldState == nil then
        return ""
    end

    local raw = fieldState.groundType
    if raw == nil and type(fieldState.getGroundType) == "function" then
        local ok, groundType = pcall(fieldState.getGroundType, fieldState)
        if ok then
            raw = groundType
        end
    end

    return FieldAdvisor.resolveGroundTypeName(raw)
end

---@param groundType string
---@param candidates string[]
---@return boolean
function FieldAdvisor.groundTypeIsOneOf(groundType, candidates)
    for _, candidate in ipairs(candidates) do
        if groundType == candidate then
            return true
        end
    end

    return false
end

---@param fruitName string|nil
---@return number|nil
function FieldAdvisor.getFruitTypeIndexByName(fruitName)
    if string.isNilOrWhitespace(fruitName) or g_fruitTypeManager == nil then
        return nil
    end

    local candidates = { tostring(fruitName) }
    local upperName = string.upper(tostring(fruitName))
    local lowerName = string.lower(tostring(fruitName))
    if upperName ~= candidates[1] then
        candidates[#candidates + 1] = upperName
    end
    if lowerName ~= candidates[1] and lowerName ~= upperName then
        candidates[#candidates + 1] = lowerName
    end

    if g_fruitTypeManager.getFruitTypeIndexByName ~= nil then
        for _, candidate in ipairs(candidates) do
            local ok, fruitTypeIndex = pcall(g_fruitTypeManager.getFruitTypeIndexByName, g_fruitTypeManager, candidate)
            if ok and fruitTypeIndex ~= nil and fruitTypeIndex > 0 then
                return fruitTypeIndex
            end
        end
    end

    if g_fruitTypeManager.getFruitTypes ~= nil then
        local ok, fruitTypes = pcall(g_fruitTypeManager.getFruitTypes, g_fruitTypeManager)
        if ok and fruitTypes ~= nil then
            for _, fruitDesc in ipairs(fruitTypes) do
                if fruitDesc ~= nil and fruitDesc.index ~= nil and fruitDesc.index > 0 then
                    for _, candidate in ipairs(candidates) do
                        if fruitDesc.name == candidate then
                            return fruitDesc.index
                        end
                    end
                end
            end
        end
    end

    return nil
end

---@param groundType string|nil
---@return boolean
function FieldAdvisor.isGrassGroundType(groundType)
    if groundType == nil or groundType == "" then
        return false
    end

    if groundType == "GRASS" or groundType == "MEADOW" then
        return true
    end

    return string.find(groundType, "GRASS", 1, true) ~= nil
end

---@return number|nil
function FieldAdvisor.getDefaultGrassFruitTypeIndex()
    if FieldAdvisor._defaultGrassFruitTypeResolved then
        return FieldAdvisor._defaultGrassFruitTypeIndex
    end

    FieldAdvisor._defaultGrassFruitTypeResolved = true
    FieldAdvisor._defaultGrassFruitTypeIndex = nil

    if g_fruitTypeManager ~= nil and g_fruitTypeManager.getFruitTypes ~= nil then
        local ok, fruitTypes = pcall(g_fruitTypeManager.getFruitTypes, g_fruitTypeManager)
        if ok and fruitTypes ~= nil then
            for _, fruitDesc in ipairs(fruitTypes) do
                if fruitDesc ~= nil and fruitDesc.index ~= nil and fruitDesc.index > 0 then
                    if FieldAdvisor.isGrassCrop(fruitDesc.index) then
                        FieldAdvisor._defaultGrassFruitTypeIndex = fruitDesc.index
                        return FieldAdvisor._defaultGrassFruitTypeIndex
                    end
                end
            end
        end
    end

    local candidates = {
        "GRASS",
        "MEADOW",
        "FIELDGRASS",
        "ALFALFA",
        "CLOVER",
        "LUCERNE",
        "MEDICK",
    }

    for _, name in ipairs(candidates) do
        local fruitTypeIndex = FieldAdvisor.getFruitTypeIndexByName(name)
        if fruitTypeIndex ~= nil then
            FieldAdvisor._defaultGrassFruitTypeIndex = fruitTypeIndex
            break
        end
    end

    return FieldAdvisor._defaultGrassFruitTypeIndex
end

---@param field table|nil
---@param fieldState table|nil
function FieldAdvisor.enrichFieldStateFromField(field, fieldState)
    if field == nil or fieldState == nil then
        return
    end

    local function assignFruitIndex(value)
        local fruitTypeIndex = tonumber(value)
        if fruitTypeIndex ~= nil and fruitTypeIndex > 0 then
            if fieldState.fruitTypeIndex == nil or fieldState.fruitTypeIndex <= 0 then
                fieldState.fruitTypeIndex = fruitTypeIndex
            end
        end
    end

    assignFruitIndex(field.fruitTypeIndex)
    assignFruitIndex(field.currentFruitTypeIndex)

    local fieldProbes = {
        "getFruitTypeIndex",
        "getCurrentFruitTypeIndex",
        "getFruitType",
    }

    for _, probe in ipairs(fieldProbes) do
        if field[probe] ~= nil then
            local ok, value = pcall(field[probe], field)
            if ok then
                if type(value) == "number" then
                    assignFruitIndex(value)
                elseif type(value) == "string" and value ~= "" and value ~= "UNKNOWN" then
                    if fieldState.fruitType == nil then
                        fieldState.fruitType = value
                    end
                end
            end
        end
    end

    if fieldState.groundType == nil and field.groundType ~= nil then
        fieldState.groundType = field.groundType
    end

    if fieldState.groundType == nil and field.getGroundType ~= nil then
        local ok, groundType = pcall(field.getGroundType, field)
        if ok and groundType ~= nil then
            fieldState.groundType = groundType
        end
    end
end

---@param fieldState table|nil
---@param field table|nil
---@return boolean
function FieldAdvisor.isGrassFieldState(fieldState, field)
    if fieldState == nil and field == nil then
        return false
    end

    if FieldAdvisor.isNonGrassSoilState(fieldState) then
        return false
    end

    local groundTypeName = FieldAdvisor.getGroundTypeName(fieldState)

    local fruitTypeIndex = FieldAdvisor.getFruitTypeIndex(fieldState)
    if fruitTypeIndex ~= nil and fruitTypeIndex > 0 then
        if FruitType == nil or fruitTypeIndex ~= FruitType.UNKNOWN then
            if FieldAdvisor.isGrassCrop(fruitTypeIndex) then
                return true
            end
        end
    end

    if fieldState ~= nil then
        local fruitNameFields = {
            "fruitTypeName",
            "fruitType",
            "currentFruitType",
            "fruit",
        }

        for _, key in ipairs(fruitNameFields) do
            local rawName = fieldState[key]
            if rawName ~= nil and rawName ~= "" and rawName ~= "UNKNOWN" then
                if FieldAdvisor.GRASS_FRUIT_NAMES[string.upper(tostring(rawName))] == true then
                    return true
                end
            end
        end

        if FieldAdvisor.isGrassGroundType(groundTypeName) then
            return true
        end

        if fieldState.isGrass == true or fieldState.isGrassCrop == true or fieldState.isGrassland == true then
            return true
        end
    end

    return false
end

---@param fieldState table|nil
---@return number
function FieldAdvisor.getEffectiveGrowthState(fieldState)
    local growthState = FieldAdvisor.getGrowthState(fieldState)
    if growthState > 0 then
        return growthState
    end

    return FieldAdvisor.getLastGrowthState(fieldState)
end

---@param fieldState table|nil
---@param field table|nil
---@return number|nil
function FieldAdvisor.resolveFruitTypeIndex(fieldState, field)
    local fruitTypeIndex = FieldAdvisor.getFruitTypeIndex(fieldState)
    if fruitTypeIndex ~= nil and fruitTypeIndex > 0 then
        if FruitType == nil or fruitTypeIndex ~= FruitType.UNKNOWN then
            return fruitTypeIndex
        end
    end

    if fieldState ~= nil then
        local fruitNameFields = {
            "fruitTypeName",
            "fruitType",
            "plannedFruit",
            "currentFruitType",
            "fruit",
        }

        for _, key in ipairs(fruitNameFields) do
            local rawName = fieldState[key]
            if rawName ~= nil and rawName ~= "" and rawName ~= "UNKNOWN" then
                fruitTypeIndex = FieldAdvisor.getFruitTypeIndexByName(rawName)
                if fruitTypeIndex ~= nil then
                    return fruitTypeIndex
                end
            end
        end

        if FieldAdvisor.isGrassFieldState(fieldState, field) then
            return FieldAdvisor.getDefaultGrassFruitTypeIndex()
        end
    end

    return nil
end

---@param field table|nil
---@param fieldId number|nil
---@param worldX number|nil
---@param worldZ number|nil
---@return table|nil
function FieldAdvisor.getEnrichedFieldState(field, fieldId, worldX, worldZ)
    -- Prefer a fresh density-map sample. field:getFieldState() may be stale/cached on some maps.
    local fieldState = FieldAdvisor.getLiveFieldState(worldX, worldZ)
    if fieldState == nil then
        fieldState = FieldAdvisor.getFieldState(field)
        if fieldState ~= nil and fieldState.update ~= nil and worldX ~= nil and worldZ ~= nil then
            fieldState:update(worldX, worldZ)
        end
    end

    if fieldState == nil then
        fieldState = {}
    else
        local cloned = setmetatable({}, getmetatable(fieldState))
        for key, value in pairs(fieldState) do
            cloned[key] = value
        end
        fieldState = cloned
    end

    FieldAdvisor.enrichFieldStateFromField(field, fieldState)

    local saveAttrs = FieldSavegameReader ~= nil and FieldSavegameReader.getFieldAttributes(fieldId) or nil
    if saveAttrs == nil then
        return fieldState
    end

    local engineGroundType = FieldAdvisor.getGroundTypeName(fieldState)
    local blockGrassOverlay = FieldAdvisor.isNonGrassSoilState(fieldState)

    if saveAttrs.groundType ~= nil
        and saveAttrs.groundType ~= "NONE"
        and FieldAdvisor.groundTypeIsOneOf(saveAttrs.groundType, FieldAdvisor.NON_GRASS_GROUND_TYPES)
        and FieldAdvisor.isGrassGroundType(engineGroundType) then
        fieldState.groundType = saveAttrs.groundType
        blockGrassOverlay = true
    end

    if not blockGrassOverlay then
        if fieldState.plannedFruit == nil and saveAttrs.plannedFruit ~= nil then
            fieldState.plannedFruit = saveAttrs.plannedFruit
        end

        if fieldState.fruitType == nil and saveAttrs.fruitType ~= nil then
            fieldState.fruitType = saveAttrs.fruitType
        end
    end

    local engineFruitIndex = FieldAdvisor.getFruitTypeIndex(fieldState)
    if (engineFruitIndex == nil or (FruitType ~= nil and engineFruitIndex == FruitType.UNKNOWN))
        and saveAttrs.fruitType ~= nil
        and saveAttrs.fruitType ~= "UNKNOWN"
        and not blockGrassOverlay then
        fieldState.fruitTypeName = saveAttrs.fruitType
    end

    local groundTypeName = FieldAdvisor.getGroundTypeName(fieldState)
    if saveAttrs.groundType ~= nil
        and saveAttrs.groundType ~= "NONE"
        and (groundTypeName == "" or groundTypeName == "NONE")
        and not (FieldAdvisor.isGrassGroundType(saveAttrs.groundType) and blockGrassOverlay) then
        fieldState.groundType = saveAttrs.groundType
    end

    if FieldAdvisor.isNonGrassSoilState(fieldState) then
        FieldAdvisor.clearStaleGrassMetadata(fieldState)
    end

    -- Never overlay save weedState: stale values keep "spray weeds" after spraying (dead weeds stay weedState 8–9).

    if FieldAdvisor.getLastGrowthState(fieldState) <= 0 and (saveAttrs.lastGrowthState or 0) > 0 then
        fieldState.lastGrowthState = saveAttrs.lastGrowthState
    end

    local saveGrowth = saveAttrs.growthState or 0
    if saveGrowth > 0 and FieldAdvisor.getGrowthState(fieldState) <= 0
        and not FieldAdvisor.isNonGrassSoilState(fieldState) then
        local saveFruit = saveAttrs.fruitType ~= nil and string.upper(tostring(saveAttrs.fruitType)) or ""
        if FieldAdvisor.isGrassGroundType(saveAttrs.groundType)
            or FieldAdvisor.GRASS_FRUIT_NAMES[saveFruit] == true then
            fieldState.growthState = saveGrowth
        end
    end

    return fieldState
end

---@param actions table[]|nil
---@return table action
function FieldAdvisor.selectPrimaryAction(actions)
    if actions == nil or #actions == 0 then
        return {
            actionType = "none",
            label = FieldAdvisor.text("ftdl_action_all_ok", "Alles ok"),
            autoComplete = false,
        }
    end

    for _, action in ipairs(actions) do
        if action.autoComplete == true then
            return action
        end
    end

    for _, action in ipairs(actions) do
        if action.actionType ~= "harvest_info" and action.actionType ~= "growing" and action.actionType ~= "none" then
            return action
        end
    end

    return actions[1]
end

---@param level number
---@param rules table
---@return string
function FieldAdvisor.formatStoneLabel(level, rules)
    local label = level <= 0
        and FieldAdvisor.text("ftdl_val_none", "kein")
        or FieldAdvisor.text("ftdl_val_growth_stage", "St.%d", level)
    if not rules.stonesEnabled then
        return string.format("%s %s", label, FieldAdvisor.text("ftdl_val_disabled", "(aus)"))
    end

    return label
end

---@param level number
---@param rules table
---@return string
function FieldAdvisor.formatLimeLabel(level, rules)
    if not rules.limeRequired then
        local base = level <= 0
            and FieldAdvisor.text("ftdl_val_ok", "ok")
            or FieldAdvisor.text("ftdl_val_lime_level", "K%d", level)
        return string.format("%s %s", base, FieldAdvisor.text("ftdl_val_disabled", "(aus)"))
    end

    if level <= 0 then
        return FieldAdvisor.text("ftdl_val_ok", "ok")
    end

    return FieldAdvisor.text("ftdl_val_lime_level", "K%d", level)
end

---@param weedState number
---@param rules table
---@return string
function FieldAdvisor.formatWeedLabel(weedState, rules)
    local label = FieldAdvisor.WEED_LABELS[weedState]
    if label == nil then
        label = weedState <= 0
            and FieldAdvisor.text("ftdl_val_none", "kein")
            or string.format("%d", weedState)
    else
        local weedKeys = {
            kein = { "ftdl_val_none", "kein" },
            leicht = { "ftdl_weed_light", "leicht" },
            mittel = { "ftdl_weed_medium", "mittel" },
            stark = { "ftdl_weed_heavy", "stark" },
        }
        local weedEntry = weedKeys[label]
        if weedEntry ~= nil then
            label = FieldAdvisor.text(weedEntry[1], weedEntry[2])
        end
    end

    if not rules.weedsEnabled then
        return string.format("%s %s", label, FieldAdvisor.text("ftdl_val_disabled", "(aus)"))
    end

    return label
end

---@param fieldState table|nil
---@return number
function FieldAdvisor.getWeedFactor(fieldState)
    return FieldAdvisor.getStateNumber(fieldState, "weedFactor")
end

---@param fieldState table|nil
---@return number
function FieldAdvisor.getWeedStateLevel(fieldState)
    return FieldAdvisor.getStateNumber(fieldState, "weedState")
end

---@param fieldState table|nil
---@return boolean
function FieldAdvisor.hasWeedFactorReading(fieldState)
    return fieldState ~= nil and fieldState.weedFactor ~= nil
end

---@param fieldState table|nil
---@return boolean
function FieldAdvisor.isWeedDeadOrSprayed(fieldState)
    if fieldState == nil then
        return false
    end

    if FieldAdvisor.getWeedStateLevel(fieldState) >= FieldAdvisor.WEED_STATE_DEAD_MIN then
        return true
    end

    if FieldAdvisor.hasWeedFactorReading(fieldState) then
        return FieldAdvisor.getWeedFactor(fieldState) <= FieldAdvisor.WEED_FACTOR_COMPLETE_THRESHOLD
    end

    return FieldAdvisor.getWeedStateLevel(fieldState) <= 0
end

---@param fieldState table|nil
---@return number
function FieldAdvisor.getEffectiveWeedPressure(fieldState)
    if FieldAdvisor.isWeedDeadOrSprayed(fieldState) then
        return 0
    end

    if FieldAdvisor.hasWeedFactorReading(fieldState) then
        return FieldAdvisor.getWeedFactor(fieldState)
    end

    local weedState = FieldAdvisor.getWeedStateLevel(fieldState)
    if weedState <= 0 then
        return 0
    end

    return math.min(1, weedState / 9)
end

---@param fieldState table|nil
---@param rules table
---@return string
function FieldAdvisor.formatWeedDisplayLabel(fieldState, rules)
    if not rules.weedsEnabled then
        return FieldAdvisor.formatWeedLabel(FieldAdvisor.getWeedStateLevel(fieldState), rules)
    end

    if FieldAdvisor.isWeedDeadOrSprayed(fieldState) then
        return FieldAdvisor.text("ftdl_weed_dead", "tot")
    end

    local pressure = FieldAdvisor.getEffectiveWeedPressure(fieldState)
    if pressure > 0.001 then
        local percent = math.floor(pressure * 100 + 0.5)
        if percent <= 2 then
            return FieldAdvisor.text("ftdl_val_none", "kein")
        end

        return string.format("%d%%", percent)
    end

    return FieldAdvisor.formatWeedLabel(FieldAdvisor.getWeedStateLevel(fieldState), rules)
end

---@param fieldState table|nil
---@param rules table
---@return boolean
function FieldAdvisor.fieldNeedsWeedCombat(fieldState, rules)
    if not rules.weedsEnabled or FieldAdvisor.isWeedDeadOrSprayed(fieldState) then
        return false
    end

    return FieldAdvisor.getEffectiveWeedPressure(fieldState) >= FieldAdvisor.WEED_FACTOR_COMBAT_THRESHOLD
end

---@param fieldState table|nil
---@param rules table
---@return boolean
function FieldAdvisor.fieldNeedsWeedWatch(fieldState, rules)
    if not rules.weedsEnabled or FieldAdvisor.isWeedDeadOrSprayed(fieldState) then
        return false
    end

    if FieldAdvisor.fieldNeedsWeedCombat(fieldState, rules) then
        return false
    end

    local pressure = FieldAdvisor.getEffectiveWeedPressure(fieldState)
    return pressure > FieldAdvisor.WEED_FACTOR_COMPLETE_THRESHOLD
        and pressure < FieldAdvisor.WEED_FACTOR_COMBAT_THRESHOLD
end

---@param period number
---@return string
function FieldAdvisor.getEnvironmentPeriodLabel(period)
    if g_currentMission ~= nil and g_currentMission.environment ~= nil then
        local environment = g_currentMission.environment

        if environment.getPeriodName ~= nil then
            local ok, periodName = pcall(environment.getPeriodName, environment, period)
            if ok and not string.isNilOrWhitespace(periodName) then
                return periodName
            end
        end

        if environment.periodNames ~= nil and environment.periodNames[period] ~= nil then
            return tostring(environment.periodNames[period])
        end
    end

    return PrecisionFarmingReader.getMonthName(period)
end

---@param fruitDesc table|nil
---@return string|nil
function FieldAdvisor.collectHarvestablePeriodLabels(fruitDesc)
    if fruitDesc == nil or fruitDesc.getIsHarvestableInPeriod == nil then
        return nil
    end

    local labels = {}
    local maxPeriod = 12

    if g_currentMission ~= nil and g_currentMission.environment ~= nil then
        local environment = g_currentMission.environment
        if environment.periodsPerYear ~= nil then
            maxPeriod = math.max(1, math.floor(tonumber(environment.periodsPerYear) or 12))
        end
    end

    for period = 1, maxPeriod do
        local ok, harvestable = pcall(fruitDesc.getIsHarvestableInPeriod, fruitDesc, period)
        if ok and harvestable == true then
            labels[#labels + 1] = FieldAdvisor.getEnvironmentPeriodLabel(period)
        end
    end

    if #labels == 0 then
        return nil
    end

    -- Prefer the first harvestable period label. Showing a pure count ("11 Mon.") reads like
    -- "wait 11 months", which is misleading; the list describes the harvest window across the year.
    return labels[1]
end

---@param rollerLevel number
---@param needsRolling boolean
---@return string
function FieldAdvisor.formatRollerLabel(rollerLevel, needsRolling)
    if needsRolling or rollerLevel > 0 then
        return FieldAdvisor.text("ftdl_val_yes", "ja")
    end

    return FieldAdvisor.text("ftdl_val_no", "nein")
end

---@param plowLevel number
---@param needsPlowing boolean
---@param rules table
---@return string
function FieldAdvisor.formatPlowLabel(plowLevel, needsPlowing, rules)
    if not rules.plowingRequiredEnabled then
        local value = needsPlowing
            and FieldAdvisor.text("ftdl_val_yes", "ja")
            or FieldAdvisor.text("ftdl_val_no", "nein")
        return string.format("%s %s", value, FieldAdvisor.text("ftdl_val_disabled", "(aus)"))
    end

    if needsPlowing or plowLevel > 0 then
        return FieldAdvisor.text("ftdl_val_yes", "ja")
    end

    return FieldAdvisor.text("ftdl_val_no", "nein")
end

---@param field table
---@param fieldState table|nil
---@return boolean
function FieldAdvisor.isHarvestReady(field, fieldState)
    if fieldState ~= nil then
        if fieldState.groundType == "HARVEST_READY" then
            return true
        end

        if fieldState.isHarvestReady == true then
            return true
        end
    end

    if field ~= nil and field.groundType == "HARVEST_READY" then
        return true
    end

    return false
end

---@param key string|nil
---@return string|nil
function FieldAdvisor.translateKey(key)
    if key == nil or key == "" or g_i18n == nil or g_i18n.hasText == nil then
        return nil
    end

    if g_i18n:hasText(key) then
        return g_i18n:getText(key)
    end

    return nil
end

---@param key string|nil
---@param fallback string|nil
---@return string
function FieldAdvisor.text(key, fallback, ...)
    if FieldToDoL10n ~= nil then
        return FieldToDoL10n.getText(key, fallback, ...)
    end

    if select("#", ...) > 0 and fallback ~= nil then
        return string.format(fallback, ...)
    end

    return fallback or key or ""
end

---@param fillType table|nil
---@return string|nil
function FieldAdvisor.getLocalizedFillTypeTitle(fillType)
    if fillType == nil then
        return nil
    end

    if fillType.title ~= nil and fillType.title ~= "" then
        local title = tostring(fillType.title)
        local translated = FieldAdvisor.translateKey(title)
        if translated ~= nil then
            return translated
        end

        if not string.match(title, "^[A-Z0-9_]+$") then
            return title
        end
    end

    if fillType.name ~= nil then
        local translated = FieldAdvisor.translateKey("fillType_" .. fillType.name)
        if translated ~= nil then
            return translated
        end

        return fillType.name
    end

    return nil
end

---@param fruitTypeIndex number|nil
---@return string|nil
function FieldAdvisor.getFruitTypeName(fruitTypeIndex)
    if fruitTypeIndex == nil or fruitTypeIndex <= 0 or g_fruitTypeManager == nil then
        return nil
    end

    local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
    if fruitDesc == nil then
        return nil
    end

    return fruitDesc.name
end

---@param fruitTypeIndex number|nil
---@return string
function FieldAdvisor.getLocalizedFruitTitle(fruitTypeIndex)
    if fruitTypeIndex == nil or fruitTypeIndex <= 0 then
        return "-"
    end

    if FruitType ~= nil and fruitTypeIndex == FruitType.UNKNOWN then
        return "-"
    end

    local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
    if fruitDesc == nil then
        return "-"
    end

    if fruitDesc.fillType ~= nil and g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeByIndex ~= nil then
        local fillType = g_fillTypeManager:getFillTypeByIndex(fruitDesc.fillType)
        local title = FieldAdvisor.getLocalizedFillTypeTitle(fillType)
        if title ~= nil and title ~= "" then
            return title
        end
    end

    if fruitDesc.name ~= nil and g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeByName ~= nil then
        local fillType = g_fillTypeManager:getFillTypeByName(fruitDesc.name)
        local title = FieldAdvisor.getLocalizedFillTypeTitle(fillType)
        if title ~= nil and title ~= "" then
            return title
        end

        local translated = FieldAdvisor.translateKey("fillType_" .. fruitDesc.name)
        if translated ~= nil then
            return translated
        end

        translated = FieldAdvisor.translateKey("fruitType_" .. fruitDesc.name)
        if translated ~= nil then
            return translated
        end
    end

    return fruitDesc.name or "-"
end

---@param fruitTypeIndex number|nil
---@return table|nil
function FieldAdvisor.getFruitTypeDesc(fruitTypeIndex)
    if fruitTypeIndex == nil or fruitTypeIndex <= 0 or g_fruitTypeManager == nil then
        return nil
    end

    return g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
end

---@param fruitTypeIndex number|nil
---@return boolean
function FieldAdvisor.isGrassCrop(fruitTypeIndex)
    local fruitName = FieldAdvisor.getFruitTypeName(fruitTypeIndex)
    if fruitName ~= nil and FieldAdvisor.GRASS_FRUIT_NAMES[string.upper(fruitName)] == true then
        return true
    end

    local fruitDesc = FieldAdvisor.getFruitTypeDesc(fruitTypeIndex)
    if fruitDesc == nil then
        return false
    end

    for _, flagName in ipairs({ "isGrassland", "isGrass", "isGrassCrop" }) do
        if fruitDesc[flagName] == true then
            return true
        end
    end

    if fruitDesc.getNeedsPlowing ~= nil then
        local ok, needsPlowing = pcall(fruitDesc.getNeedsPlowing, fruitDesc)
        if ok and needsPlowing == false and fruitDesc.minHarvestingGrowthState ~= nil then
            local minHarvest = tonumber(fruitDesc.minHarvestingGrowthState) or 0
            local maxHarvest = tonumber(fruitDesc.maxHarvestingGrowthState) or 0
            if maxHarvest > minHarvest and minHarvest >= 0 then
                return true
            end
        end
    end

    return false
end

---@param fieldState table|nil
---@param field table|nil
---@return boolean
function FieldAdvisor.isGrassHarvestable(fieldState, field)
    if not FieldAdvisor.isGrassFieldState(fieldState, field) then
        return false
    end

    if FieldAdvisor.isHarvestReady(field, fieldState) then
        return true
    end

    if FieldAdvisor.isGrassCut(fieldState, field) then
        return false
    end

    local growthState = FieldAdvisor.getGrowthState(fieldState)
    if growthState <= 0 then
        return false
    end

    local fruitTypeIndex = FieldAdvisor.resolveFruitTypeIndex(fieldState, field)
    if fruitTypeIndex ~= nil then
        local fruitDesc = FieldAdvisor.getFruitTypeDesc(fruitTypeIndex)
        if fruitDesc ~= nil and fruitDesc.getIsHarvestable ~= nil then
            local ok, isHarvestable = pcall(fruitDesc.getIsHarvestable, fruitDesc, growthState)
            if ok and isHarvestable == true then
                return true
            end
        end
    end

    return false
end

---@param fieldState table|nil
---@param field table|nil
---@return boolean
function FieldAdvisor.isGrassCut(fieldState, field)
    if not FieldAdvisor.isGrassFieldState(fieldState, field) then
        return false
    end

    local growthState = FieldAdvisor.getGrowthState(fieldState)
    local fruitTypeIndex = FieldAdvisor.resolveFruitTypeIndex(fieldState, field)
    local fruitDesc = FieldAdvisor.getFruitTypeDesc(fruitTypeIndex)
    if fruitDesc == nil or fruitDesc.getIsCut == nil then
        return false
    end

    local ok, isCut = pcall(fruitDesc.getIsCut, fruitDesc, growthState)
    return ok and isCut == true
end

---@param fieldState table|nil
---@return number
function FieldAdvisor.getLastGrowthState(fieldState)
    return FieldAdvisor.getStateNumber(fieldState, "lastGrowthState")
end

---@param fieldState table|nil
---@param baseline table|nil
---@param field table|nil
---@return boolean
function FieldAdvisor.isGrassPostCutCleared(fieldState, baseline, field)
    if fieldState == nil or baseline == nil then
        return false
    end

    if FieldAdvisor.isGrassCut(fieldState, field) or FieldAdvisor.isGrassHarvestable(fieldState, field) then
        return false
    end

    if baseline.wasGrassCut == true and FieldAdvisor.getGrowthState(fieldState) <= 0 then
        return true
    end

    local fruitTypeIndex = FieldAdvisor.resolveFruitTypeIndex(fieldState, field)
    local fruitDesc = FieldAdvisor.getFruitTypeDesc(fruitTypeIndex)
    if fruitDesc ~= nil and fruitDesc.getIsGrowing ~= nil then
        local ok, isGrowing = pcall(fruitDesc.getIsGrowing, fruitDesc, FieldAdvisor.getGrowthState(fieldState))
        if ok and isGrowing == true and baseline.wasGrassCut == true then
            return true
        end
    end

    if baseline.wasGrassCut == true
        and FieldAdvisor.getLastGrowthState(fieldState) ~= (baseline.lastGrowthState or -1) then
        return true
    end

    return false
end

---@param fieldState table|nil
---@return number|nil
function FieldAdvisor.getFruitTypeIndex(fieldState)
    if fieldState == nil then
        return nil
    end

    if fieldState.fruitTypeIndex ~= nil and fieldState.fruitTypeIndex > 0 then
        return fieldState.fruitTypeIndex
    end

    if fieldState.currentFruitTypeIndex ~= nil and fieldState.currentFruitTypeIndex > 0 then
        return fieldState.currentFruitTypeIndex
    end

    return nil
end

---@param fieldState table|nil
---@return number
function FieldAdvisor.getGrowthState(fieldState)
    return FieldAdvisor.getStateNumber(fieldState, "growthState")
end

---@param fieldState table|nil
---@param field table|nil
---@return boolean
function FieldAdvisor.isFieldUnsown(fieldState, field)
    if FieldAdvisor.isGrassFieldState(fieldState, field) then
        return false
    end

    if fieldState == nil then
        return true
    end

    local growthState = FieldAdvisor.getGrowthState(fieldState)
    local groundType = FieldAdvisor.getGroundTypeName(fieldState)
    local fruitTypeIndex = FieldAdvisor.resolveFruitTypeIndex(fieldState, field)

    if FieldAdvisor.groundTypeIsOneOf(groundType, { "SOWN", "PLANTED", "RIDGE_SOWN", "ROLLER_LINES" }) then
        return growthState <= 0
    end

    if fruitTypeIndex == nil then
        return growthState <= 0
    end

    if FruitType ~= nil and fruitTypeIndex == FruitType.UNKNOWN then
        return growthState <= 0
            and not FieldAdvisor.groundTypeIsOneOf(groundType, { "CULTIVATED", "PLOWED", "SEEDBED" })
    end

    return growthState <= 0
end

---@param fieldState table|nil
---@return boolean
function FieldAdvisor.isFieldSown(fieldState)
    if fieldState == nil then
        return false
    end

    local growthState = FieldAdvisor.getGrowthState(fieldState)
    local groundType = FieldAdvisor.getGroundTypeName(fieldState)

    if FieldAdvisor.groundTypeIsOneOf(groundType, { "SOWN", "PLANTED", "RIDGE_SOWN" }) then
        return true
    end

    if growthState > 0 and FieldAdvisor.resolveFruitTypeIndex(fieldState, nil) ~= nil then
        return true
    end

    return false
end

---@param fieldState table|nil
---@return boolean
function FieldAdvisor.hasActiveCrop(fieldState)
    if fieldState == nil then
        return false
    end

    if FieldAdvisor.isFieldSown(fieldState) then
        return true
    end

    local fruitTypeIndex = FieldAdvisor.resolveFruitTypeIndex(fieldState, nil)
    if fruitTypeIndex == nil then
        return false
    end

    if FruitType ~= nil and fruitTypeIndex == FruitType.UNKNOWN then
        return false
    end

    return FieldAdvisor.getGrowthState(fieldState) > 0
end

---@param fieldState table|nil
---@return boolean
function FieldAdvisor.isWithered(fieldState)
    if fieldState == nil then
        return false
    end

    local growthState = FieldAdvisor.getGrowthState(fieldState)
    if growthState <= 0 then
        return false
    end

    local fruitTypeIndex = FieldAdvisor.getFruitTypeIndex(fieldState)
    if fruitTypeIndex == nil or fruitTypeIndex <= 0 or g_fruitTypeManager == nil then
        return false
    end

    local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
    if fruitDesc == nil then
        return false
    end

    if fruitDesc.getIsWithered ~= nil then
        local success, isWithered = pcall(fruitDesc.getIsWithered, fruitDesc, growthState)
        if success and isWithered == true then
            return true
        end
    end

    if fruitDesc.witheredState ~= nil and growthState == fruitDesc.witheredState then
        return true
    end

    return false
end

---@param fieldState table|nil
---@return string
function FieldAdvisor.formatGrowthLabel(fieldState)
    local growthState = FieldAdvisor.getEffectiveGrowthState(fieldState)
    if growthState <= 0 then
        return "-"
    end

    if FieldAdvisor.isWithered(fieldState) then
        return string.format("V%d", growthState)
    end

    return tostring(growthState)
end

---@param field table
---@param fieldState table|nil
---@return boolean
function FieldAdvisor.isPostHarvestSoilWorkPhase(field, fieldState)
    if FieldAdvisor.isWithered(fieldState) then
        return true
    end

    if FieldAdvisor.hasActiveCrop(fieldState) then
        return false
    end

    if FieldAdvisor.isHarvestReady(field, fieldState) then
        return false
    end

    return true
end

---@param field table|nil
---@param fieldId number|nil
---@param fieldState table|nil
---@param worldX number|nil
---@param worldZ number|nil
---@return boolean
function FieldAdvisor.fieldHasPartialSoilWork(field, fieldId, fieldState, worldX, worldZ)
    if field == nil or fieldState == nil then
        return false
    end

    if worldX == nil or worldZ == nil then
        if field.getCenterOfFieldWorldPosition ~= nil then
            worldX, worldZ = field:getCenterOfFieldWorldPosition()
        end
    end

    if worldX == nil or worldZ == nil then
        return false
    end

    local centerIndex = FieldAdvisor.resolveFruitTypeIndex(fieldState, field)
    local centerGrass = FieldAdvisor.isGrassFieldState(fieldState, field)

    if not centerGrass then
        return false
    end

    local points = {}
    if FieldTaskCompletion ~= nil and FieldTaskCompletion.collectSamplePoints ~= nil then
        points = FieldTaskCompletion.collectSamplePoints(field, worldX, worldZ)
    else
        points[#points + 1] = { x = worldX, z = worldZ }
    end

    for _, point in ipairs(points) do
        local sampleState = FieldAdvisor.getEnrichedFieldState(field, fieldId, point.x, point.z)
        local groundType = FieldAdvisor.getGroundTypeName(sampleState)
        if FieldAdvisor.groundTypeIsOneOf(groundType, FieldAdvisor.SOIL_WORK_GROUND_TYPES) then
            return true
        end
    end

    return false
end

---@param field table|nil
---@param fieldId number|nil
---@param fieldState table|nil
---@param worldX number|nil
---@param worldZ number|nil
---@return string
function FieldAdvisor.getFieldFruitDisplayLabel(field, fieldId, fieldState, worldX, worldZ)
    if FieldAdvisor.isGrassFieldState(fieldState, field) then
        local fruitTypeIndex = FieldAdvisor.resolveFruitTypeIndex(fieldState, field)
        local label = FieldAdvisor.getLocalizedFruitTitle(fruitTypeIndex)
        if label ~= "-" then
            if not FieldAdvisor.fieldHasPartialSoilWork(field, fieldId, fieldState, worldX, worldZ) then
                return label
            end
        else
            if not FieldAdvisor.fieldHasPartialSoilWork(field, fieldId, fieldState, worldX, worldZ) then
                return FieldAdvisor.text("ftdl_fruit_grass", "Gras")
            end
        end
    end

    local fruitTypeIndex = FieldAdvisor.resolveFruitTypeIndex(fieldState, field)
    local centerLabel = FieldAdvisor.getLocalizedFruitTitle(fruitTypeIndex)

    if not FieldAdvisor.fieldHasPartialSoilWork(field, fieldId, fieldState, worldX, worldZ) then
        return centerLabel
    end

    local planned = fieldState ~= nil and fieldState.plannedFruit or nil
    if planned == "FALLOW" then
        return FieldAdvisor.text("ftdl_fruit_partial_fallow", "Brache (teilw.)")
    end

    return FieldAdvisor.text("ftdl_fruit_partial_grass", "Gras (teilw. bearb.)")
end

---@param field table
---@param fieldState table|nil
---@return string
function FieldAdvisor.getCropPhase(field, fieldState)
    local fieldId = field.getId ~= nil and field:getId() or nil

    if FieldAdvisor.isGrassFieldState(fieldState, field) then
        if FieldAdvisor.fieldHasPartialSoilWork(field, fieldId, fieldState) then
            return "growing"
        end

        if FieldAdvisor.isGrassHarvestable(fieldState, field) then
            return "harvest_ready"
        end
        return "growing"
    end

    if FieldAdvisor.fieldHasPartialSoilWork(field, fieldId, fieldState) then
        return "empty"
    end

    if FieldAdvisor.isHarvestReady(field, fieldState) or FieldAdvisor.isGrassHarvestable(fieldState, field) then
        return "harvest_ready"
    end

    if FieldAdvisor.isWithered(fieldState) then
        return "withered"
    end

    if FieldAdvisor.hasActiveCrop(fieldState) then
        return "growing"
    end

    if FieldAdvisor.isFieldUnsown(fieldState, field) then
        return "empty"
    end

    return "post_harvest"
end

---@param field table
---@param fieldState table|nil
---@return string
function FieldAdvisor.getExpectedHarvestLabel(field, fieldState)
    if FieldAdvisor.isGrassFieldState(fieldState, field) then
        if FieldAdvisor.isGrassHarvestable(fieldState, field) then
            return FieldAdvisor.text("ftdl_action_grass_mow_short", "Mähen")
        end

        if FieldAdvisor.isGrassCut(fieldState, field) then
            return FieldAdvisor.text("ftdl_action_growing", "Wächst")
        end

        local harvestWindow = FieldAdvisor.getHarvestWindowHint(FieldAdvisor.resolveFruitTypeIndex(fieldState, field))
        if harvestWindow ~= "-" then
            return FieldAdvisor.text("ftdl_action_harvest_window", "Ernte %s", harvestWindow)
        end

        if FieldAdvisor.getEffectiveGrowthState(fieldState) > 0 then
            return FieldAdvisor.text("ftdl_action_growing", "Wächst")
        end

        return FieldAdvisor.text("ftdl_fruit_grass", "Gras")
    end

    if FieldAdvisor.isFieldUnsown(fieldState, field) then
        return "-"
    end

    if FieldAdvisor.isWithered(fieldState) then
        return FieldAdvisor.text("ftdl_action_withered", "Verdorrt")
    end

    if FieldAdvisor.isGrassHarvestable(fieldState, field) then
        return FieldAdvisor.text("ftdl_action_grass_mow_short", "Mähen")
    end

    if FieldAdvisor.isHarvestReady(field, fieldState) then
        return FieldAdvisor.text(
            "ftdl_action_harvest_now_short",
            "Jetzt (%s)",
            PrecisionFarmingReader.getCurrentMonthLabel()
        )
    end

    local fruitTypeIndex = FieldAdvisor.resolveFruitTypeIndex(fieldState, field)
    local harvestWindow = FieldAdvisor.getHarvestWindowHint(fruitTypeIndex)
    if harvestWindow ~= "-" then
        return harvestWindow
    end

    if FieldAdvisor.hasActiveCrop(fieldState) then
        return FieldAdvisor.text("ftdl_action_growing", "Wächst")
    end

    return "-"
end

---@param fruitTypeIndex number|nil
---@return string
function FieldAdvisor.getHarvestWindowHint(fruitTypeIndex)
    if fruitTypeIndex == nil or fruitTypeIndex <= 0 or g_fruitTypeManager == nil then
        return "-"
    end

    if g_fruitTypeManager.getFruitTypeByIndex == nil then
        return "-"
    end

    local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
    if fruitDesc == nil then
        return "-"
    end

    if fruitDesc.harvestMonths ~= nil and type(fruitDesc.harvestMonths) == "table" and #fruitDesc.harvestMonths > 0 then
        -- Show the first month in the harvest window (short, stable label).
        local first = fruitDesc.harvestMonths[1]
        return PrecisionFarmingReader.getMonthName(first)
    end

    if fruitDesc.harvestMonthIndices ~= nil and type(fruitDesc.harvestMonthIndices) == "table" then
        local first = fruitDesc.harvestMonthIndices[1]
        if first ~= nil then
            return PrecisionFarmingReader.getMonthName(first)
        end
    end

    local periodLabels = FieldAdvisor.collectHarvestablePeriodLabels(fruitDesc)
    if periodLabels ~= nil then
        return periodLabels
    end

    return "-"
end

---@param field table
---@param fieldState table|nil
---@param worldX number|nil
---@param worldZ number|nil
---@return table context
function FieldAdvisor.buildFieldContext(field, fieldState, worldX, worldZ)
    local rules = FieldGameRules.get()

    local pfSample = nil
    if PrecisionFarmingReader.isModLoaded() then
        pfSample = PrecisionFarmingReader.sampleField(worldX, worldZ, fieldState, field)
    end

    local scsSample = nil
    if SeasonalCropStressReader.isRuntimeReady ~= nil and SeasonalCropStressReader.isRuntimeReady() then
        scsSample = SeasonalCropStressReader.sampleField(field)
    end

    return {
        field = field,
        fieldState = fieldState,
        rules = rules,
        pfSample = pfSample,
        scsSample = scsSample,
        needsPlowing = FieldAdvisor.getStateBool(fieldState, "needsPlowing"),
        needsLime = FieldAdvisor.getStateBool(fieldState, "needsLime"),
        needsRolling = FieldAdvisor.getStateBool(fieldState, "needsRolling"),
        plowLevel = FieldAdvisor.getStateNumber(fieldState, "plowLevel"),
        limeLevel = FieldAdvisor.getStateNumber(fieldState, "limeLevel"),
        weedState = FieldAdvisor.getStateNumber(fieldState, "weedState"),
        weedFactor = FieldAdvisor.getWeedFactor(fieldState),
        stoneLevel = FieldAdvisor.getStateNumber(fieldState, "stoneLevel"),
        rollerLevel = FieldAdvisor.getStateNumber(fieldState, "rollerLevel"),
    }
end

---@param actions table[]
---@param action table
local function FieldAdvisor_addAction(actions, action)
    if action == nil then
        return
    end

    for _, existing in ipairs(actions) do
        if existing.actionType == action.actionType then
            return
        end
    end

    actions[#actions + 1] = action
end

---@param pass number
---@param passTotal number
---@return string
function FieldAdvisor.getOrganicFertilizerPassLabel(pass, passTotal)
    local safePass = math.max(1, math.floor(tonumber(pass) or 1))
    local safeTotal = math.max(safePass, math.floor(tonumber(passTotal) or safePass))

    return FieldAdvisor.text("ftdl_action_organic_pass", "Mist/Gülle %d/%d", safePass, safeTotal)
end

---@param actions table[]
---@param pfSample table|nil
---@return table[]
function FieldAdvisor.expandOrganicFertilizerPasses(actions, pfSample)
    if actions == nil or not FieldAdvisorSettings.isOrganicMultiPassEnabled() then
        return actions
    end

    local nitrogen = pfSample ~= nil and tonumber(pfSample.nitrogenValue) or nil
    local passCount = FieldAdvisor.getOrganicFertilizerPassCount(nitrogen)
    if passCount <= 1 then
        return actions
    end

    local expanded = {}
    for _, action in ipairs(actions) do
        if action.actionType == "pf_n" then
            for pass = 1, passCount do
                expanded[#expanded + 1] = {
                    actionType = "pf_n",
                    fertPass = pass,
                    fertPassTotal = passCount,
                    label = FieldAdvisor.getOrganicFertilizerPassLabel(pass, passCount),
                    autoComplete = true,
                }
            end
        else
            expanded[#expanded + 1] = action
        end
    end

    return expanded
end

---@param nitrogen number|nil
---@return number
function FieldAdvisor.getOrganicFertilizerPassCount(nitrogen)
    if nitrogen == nil or nitrogen >= 80 then
        return 1
    end

    if nitrogen < 45 then
        return 3
    end

    if nitrogen < 65 then
        return 2
    end

    return 2
end

---@param pass number
---@param passTotal number
---@param targetN number
---@return number
function FieldAdvisor.getOrganicFertilizerPassTarget(pass, passTotal, targetN)
    local safePass = math.max(1, math.floor(tonumber(pass) or 1))
    local safeTotal = math.max(safePass, math.floor(tonumber(passTotal) or safePass))
    local safeTarget = tonumber(targetN) or 80

    return math.floor(safeTarget * (safePass / safeTotal))
end

--- Boden-Schritte zwischen Mist/Gülle-Durchgängen (nie zwei Düngungen direkt hintereinander).
---@param soilActions table[]
---@return table[]
function FieldAdvisor.collectOrganicInterleaveSlots(soilActions)
    local slots = {}
    local slotOrder = { "plow", "cultivate", "lime", "sow", "roller" }

    for _, slotType in ipairs(slotOrder) do
        for _, action in ipairs(soilActions) do
            if action.actionType == slotType then
                slots[#slots + 1] = action
                break
            end
        end
    end

    return slots
end

---@param action table|nil
---@return boolean
function FieldAdvisor.isOrganicInterleavePrefixSoil(action)
    if action == nil then
        return false
    end

    local actionType = action.actionType
    return actionType == "stones"
        or actionType == "weed_combat"
        or actionType == "weed_watch"
        or actionType == "pf_ph"
        or actionType == "harvest"
        or actionType == "harvest_info"
        or actionType == "growing"
        or actionType == "withered"
        or actionType == "grass_mow"
        or actionType == "grass_swath"
        or actionType == "grass_collect"
        or actionType == "grass_bale"
        or actionType == "grass_silage_bale"
        or actionType == "scs_moisture"
        or actionType == "scs_stress_high"
        or actionType == "scs_stress_watch"
        or actionType == "none"
end

---@param actions table[]
---@return table[]
function FieldAdvisor.interleaveFertilizerPasses(actions)
    if actions == nil or #actions <= 1 or not FieldAdvisorSettings.isOrganicMultiPassEnabled() then
        return actions
    end

    local soilActions = {}
    local fertActions = {}

    for _, action in ipairs(actions) do
        if action.actionType == "pf_n" and action.fertPass ~= nil then
            fertActions[#fertActions + 1] = action
        else
            soilActions[#soilActions + 1] = action
        end
    end

    if #fertActions <= 1 then
        return actions
    end

    table.sort(fertActions, function(a, b)
        return (tonumber(a.fertPass) or 0) < (tonumber(b.fertPass) or 0)
    end)

    local prefixSoil = {}
    local interleaveSlots = FieldAdvisor.collectOrganicInterleaveSlots(soilActions)
    local slotted = {}

    for _, action in ipairs(interleaveSlots) do
        slotted[action] = true
    end

    for _, action in ipairs(soilActions) do
        if FieldAdvisor.isOrganicInterleavePrefixSoil(action) then
            prefixSoil[#prefixSoil + 1] = action
        elseif not slotted[action] then
            prefixSoil[#prefixSoil + 1] = action
        end
    end

    -- Mist/Gülle passes between soil work (user picks manure or slurry each time).
    local maxPasses = #interleaveSlots + 1
    while #fertActions > maxPasses do
        table.remove(fertActions)
    end

    for index, action in ipairs(fertActions) do
        action.fertPass = index
        action.fertPassTotal = #fertActions
        action.label = FieldAdvisor.getOrganicFertilizerPassLabel(index, #fertActions)
    end

    if #fertActions == 0 then
        return actions
    end

    local interleaved = {}

    if #interleaveSlots == 0 then
        -- No plow/sow/lime/roller/cultivate on this field: at most one Mist/Gülle pass.
        fertActions[1].fertPass = 1
        fertActions[1].fertPassTotal = 1
        fertActions[1].label = FieldAdvisor.getOrganicFertilizerPassLabel(1, 1)
        interleaved[#interleaved + 1] = fertActions[1]
    else
        for fertIndex = 1, #fertActions do
            interleaved[#interleaved + 1] = fertActions[fertIndex]
            if fertIndex < #fertActions then
                local separator = interleaveSlots[fertIndex]
                if separator == nil then
                    break
                end
                interleaved[#interleaved + 1] = separator
            end
        end
    end

    local result = {}
    for _, action in ipairs(prefixSoil) do
        result[#result + 1] = action
    end
    for _, action in ipairs(interleaved) do
        result[#result + 1] = action
    end

    return result
end

---@param actions table[]
---@param pfSample table|nil
---@return table[]
function FieldAdvisor.finishActionCandidates(actions, pfSample)
    actions = FieldAdvisor.expandOrganicFertilizerPasses(actions, pfSample)

    if FieldAdvisorSettings.isOrganicMultiPassEnabled() then
        return FieldAdvisor.interleaveFertilizerPasses(actions)
    end

    return FieldAdvisorSettings.sortActions(actions)
end

---@param actions table[]
---@param fieldState table|nil
function FieldAdvisor.addGrassWorkActions(actions, fieldState, field)
    if FieldAdvisor.isGrassHarvestable(fieldState, field) then
        FieldAdvisor_addAction(actions, {
            actionType = "grass_mow",
            label = FieldAdvisor.text("ftdl_action_grass_mow", "Mähen"),
            pickerLabel = FieldAdvisor.text("ftdl_action_grass_mow", "Mähen"),
            autoComplete = true,
        })
        return
    end

    if FieldAdvisor.isGrassCut(fieldState, field) then
        -- Keep follow-up grass logistics visible, but do not auto-track for now.
        FieldAdvisor_addAction(actions, {
            actionType = "grass_swath",
            label = FieldAdvisor.text("ftdl_action_grass_swath", "Schwaden"),
            pickerLabel = FieldAdvisor.text("ftdl_action_grass_swath", "Schwaden"),
            autoComplete = false,
        })
        FieldAdvisor_addAction(actions, {
            actionType = "grass_collect",
            label = FieldAdvisor.text("ftdl_action_grass_collect", "Einsammeln / Laden"),
            pickerLabel = FieldAdvisor.text("ftdl_action_grass_collect", "Einsammeln / Laden"),
            autoComplete = false,
        })
        FieldAdvisor_addAction(actions, {
            actionType = "grass_bale",
            label = FieldAdvisor.text("ftdl_action_grass_bale", "Ballen pressen"),
            pickerLabel = FieldAdvisor.text("ftdl_action_grass_bale", "Ballen pressen"),
            autoComplete = false,
        })
        FieldAdvisor_addAction(actions, {
            actionType = "grass_silage_bale",
            label = FieldAdvisor.text("ftdl_action_grass_silage_bale", "Silageballen pressen"),
            pickerLabel = FieldAdvisor.text("ftdl_action_grass_silage_bale", "Silageballen pressen"),
            autoComplete = false,
        })
    end
end

---@param field table
---@param fieldState table|nil
---@param pfSample table|nil
---@param scsSample table|nil
---@param rules table|nil
---@return table[] actions
function FieldAdvisor.resolveActionCandidates(field, fieldState, pfSample, scsSample, rules)
    rules = rules or FieldGameRules.get()
    local actions = {}

    local fruitTypeIndex = FieldAdvisor.resolveFruitTypeIndex(fieldState, field)
    local isGrass = FieldAdvisor.isGrassFieldState(fieldState, field)
    local cropPhase = FieldAdvisor.getCropPhase(field, fieldState)
    local growthState = FieldAdvisor.getGrowthState(fieldState)
    local postHarvestSoilWork = FieldAdvisor.isPostHarvestSoilWorkPhase(field, fieldState)

    local needsPlowing = FieldAdvisor.getStateBool(fieldState, "needsPlowing")
    local needsLime = FieldAdvisor.getStateBool(fieldState, "needsLime")
    local needsRolling = FieldAdvisor.getStateBool(fieldState, "needsRolling")
    local plowLevel = FieldAdvisor.getStateNumber(fieldState, "plowLevel")
    local limeLevel = FieldAdvisor.getStateNumber(fieldState, "limeLevel")
    local weedState = FieldAdvisor.getStateNumber(fieldState, "weedState")
    local stoneLevel = FieldAdvisor.getStateNumber(fieldState, "stoneLevel")
    local rollerLevel = FieldAdvisor.getStateNumber(fieldState, "rollerLevel")

    if cropPhase == "harvest_ready" then
        if isGrass then
            FieldAdvisor.addGrassWorkActions(actions, fieldState, field)
        else
            FieldAdvisor_addAction(actions, {
                actionType = "harvest",
                label = FieldAdvisor.text(
                    "ftdl_action_harvest_now",
                    "Jetzt ernten (%s)",
                    PrecisionFarmingReader.getCurrentMonthLabel()
                ),
                autoComplete = true,
            })
        end
    end

    if cropPhase == "withered" then
        if rules.stonesEnabled and stoneLevel > 0 then
            FieldAdvisor_addAction(actions, {
                actionType = "stones",
                label = FieldAdvisor.text("ftdl_action_stones_pick", "Steine lesen"),
                autoComplete = true,
            })
        end

        if not isGrass then
            FieldAdvisor_addAction(actions, {
                actionType = "cultivate",
                label = FieldAdvisor.text("ftdl_action_cultivate", "Grubbern"),
                pickerLabel = FieldAdvisor.text("ftdl_action_cultivate", "Grubbern"),
                autoComplete = true,
            })

            if rules.plowingRequiredEnabled then
                FieldAdvisor_addAction(actions, {
                    actionType = "plow",
                    label = FieldAdvisor.text("ftdl_action_plow", "Pflügen"),
                    pickerLabel = FieldAdvisor.text("ftdl_action_plow", "Pflügen"),
                    autoComplete = true,
                })
            end

            FieldAdvisor_addAction(actions, {
                actionType = "roller",
                label = FieldAdvisor.text("ftdl_action_roller", "Walzen"),
                pickerLabel = FieldAdvisor.text("ftdl_action_roller", "Walzen"),
                autoComplete = true,
            })
        end

        if rules.limeRequired and not isGrass and (needsLime or limeLevel > 0) then
            FieldAdvisor_addAction(actions, {
                actionType = "lime",
                label = FieldAdvisor.text("ftdl_action_lime", "Kalken"),
                autoComplete = true,
            })
        end

        if not isGrass then
            FieldAdvisor_addAction(actions, {
                actionType = "sow",
                label = FieldAdvisor.text("ftdl_action_resow", "Neu ansäen"),
                autoComplete = true,
            })
        end

        return FieldAdvisor.finishActionCandidates(actions, pfSample)
    end

    if cropPhase == "growing" then
        if isGrass then
            FieldAdvisor.addGrassWorkActions(actions, fieldState, field)
        end

        if FieldAdvisor.fieldNeedsWeedCombat(fieldState, rules) then
            FieldAdvisor_addAction(actions, {
                actionType = "weed_combat",
                label = FieldAdvisor.text("ftdl_action_weed_combat_long", "Unkraut bekämpfen"),
                autoComplete = true,
            })
        elseif FieldAdvisor.fieldNeedsWeedWatch(fieldState, rules) then
            FieldAdvisor_addAction(actions, {
                actionType = "weed_watch",
                label = FieldAdvisor.text("ftdl_action_weed_watch_long", "Unkraut beobachten"),
                autoComplete = true,
            })
        end

        if rules.stonesEnabled and stoneLevel > 0 then
            FieldAdvisor_addAction(actions, {
                actionType = "stones",
                label = FieldAdvisor.text("ftdl_action_stones_pick", "Steine lesen"),
                autoComplete = true,
            })
        end

        if not isGrass and (needsRolling or rollerLevel > 0) then
            FieldAdvisor_addAction(actions, {
                actionType = "roller",
                label = FieldAdvisor.text("ftdl_action_roller", "Walzen"),
                pickerLabel = FieldAdvisor.text("ftdl_action_roller", "Walzen"),
                autoComplete = true,
            })
        end

        if not isGrass and pfSample ~= nil and pfSample.pHValue ~= nil and pfSample.pHValue < 6.0 then
            FieldAdvisor_addAction(actions, {
                actionType = "pf_ph",
                label = FieldAdvisor.text("ftdl_action_raise_ph", "pH anheben (Kalk)"),
                autoComplete = true,
            })
        end

        if not isGrass and pfSample ~= nil and pfSample.nitrogenValue ~= nil and pfSample.nitrogenValue < 80 then
            FieldAdvisor_addAction(actions, {
                actionType = "pf_n",
                label = FieldAdvisor.text("ftdl_action_fert_n", "Düngen (N)"),
                autoComplete = true,
            })
        end

        if SeasonalCropStressReader.isRuntimeReady()
            and scsSample ~= nil
            and scsSample.moisture ~= nil
            and scsSample.moisture < 0.25 then
            FieldAdvisor_addAction(actions, {
                actionType = "scs_moisture",
                label = FieldAdvisor.text("ftdl_action_irrigate_dry", "Bewässern (trocken)"),
                autoComplete = true,
            })
        end

        if SeasonalCropStressReader.isRuntimeReady()
            and scsSample ~= nil
            and scsSample.stress ~= nil
            and scsSample.stress >= 0.6 then
            FieldAdvisor_addAction(actions, {
                actionType = "scs_stress_high",
                label = FieldAdvisor.text("ftdl_action_stress_high", "Pflanzenstress hoch"),
                autoComplete = true,
            })
        elseif SeasonalCropStressReader.isRuntimeReady()
            and scsSample ~= nil
            and scsSample.stress ~= nil
            and scsSample.stress >= 0.35 then
            FieldAdvisor_addAction(actions, {
                actionType = "scs_stress_watch",
                label = FieldAdvisor.text("ftdl_action_stress_watch", "Stress beobachten"),
                autoComplete = true,
            })
        end

        local harvestWindow = FieldAdvisor.getHarvestWindowHint(fruitTypeIndex)
        local growingLabel = harvestWindow ~= "-"
            and harvestWindow
            or FieldAdvisor.text("ftdl_action_growing", "Wächst")
        if harvestWindow ~= "-" then
            FieldAdvisor_addAction(actions, {
                actionType = "harvest_info",
                label = FieldAdvisor.text("ftdl_action_harvest_window", "Ernte %s", harvestWindow),
                pickerLabel = FieldAdvisor.text("ftdl_action_harvest_window", "Ernte %s", harvestWindow),
                autoComplete = false,
            })
        end

        FieldAdvisor_addAction(actions, {
            actionType = "growing",
            label = growingLabel,
            pickerLabel = growingLabel,
            autoComplete = false,
        })

        return FieldAdvisor.finishActionCandidates(actions, pfSample)
    end

    if cropPhase == "empty" or cropPhase == "post_harvest" then
        if rules.stonesEnabled and stoneLevel > 0 then
            FieldAdvisor_addAction(actions, {
                actionType = "stones",
                label = FieldAdvisor.text("ftdl_action_stones_pick", "Steine lesen"),
                autoComplete = true,
            })
        end

        if postHarvestSoilWork and not isGrass then
            if rules.plowingRequiredEnabled and (needsPlowing or plowLevel > 0) then
                FieldAdvisor_addAction(actions, {
                    actionType = "plow",
                    label = FieldAdvisor.text("ftdl_action_plow_after_harvest", "Pflügen (nach Ernte)"),
                    autoComplete = true,
                })
            else
                FieldAdvisor_addAction(actions, {
                    actionType = "cultivate",
                    label = FieldAdvisor.text("ftdl_action_cultivate_after_harvest", "Grubbern (nach Ernte)"),
                    autoComplete = true,
                })
            end
        end

        if postHarvestSoilWork and rules.limeRequired and not isGrass and (needsLime or limeLevel > 0) then
            FieldAdvisor_addAction(actions, {
                actionType = "lime",
                label = FieldAdvisor.text("ftdl_action_lime", "Kalken"),
                autoComplete = true,
            })
        end

        if cropPhase == "empty" and not isGrass and pfSample ~= nil and pfSample.pHValue ~= nil and pfSample.pHValue < 6.0 then
            FieldAdvisor_addAction(actions, {
                actionType = "pf_ph",
                label = FieldAdvisor.text("ftdl_action_raise_ph", "pH anheben (Kalk)"),
                autoComplete = true,
            })
        end

        if cropPhase == "empty" then
            FieldAdvisor_addAction(actions, {
                actionType = "sow",
                label = FieldAdvisor.text("ftdl_action_sow_empty", "Ansäen"),
                autoComplete = false,
            })
        end

        if postHarvestSoilWork and (needsRolling or rollerLevel > 0) then
            FieldAdvisor_addAction(actions, {
                actionType = "roller",
                label = FieldAdvisor.text("ftdl_action_roller", "Walzen"),
                pickerLabel = FieldAdvisor.text("ftdl_action_roller", "Walzen"),
                autoComplete = true,
            })
        end
    end

    if #actions == 0 then
        actions[1] = {
            actionType = "none",
            label = FieldAdvisor.text("ftdl_action_all_ok", "Alles ok"),
            autoComplete = false,
        }
    end

    return FieldAdvisor.finishActionCandidates(actions, pfSample)
end

---@param field table
---@param fieldState table|nil
---@param pfSample table|nil
---@param scsSample table|nil
---@param rules table|nil
---@return table action { actionType: string, label: string, autoComplete: boolean }
function FieldAdvisor.resolvePrimaryAction(field, fieldState, pfSample, scsSample, rules)
    local actions = FieldAdvisor.resolveActionCandidates(field, fieldState, pfSample, scsSample, rules)
    return FieldAdvisor.selectPrimaryAction(actions)
end

---@param action table|nil
---@return string
function FieldAdvisor.getShortActionLabel(action)
    if action == nil then
        return "-"
    end

    local shortLabels = {
        harvest = { "ftdl_action_harvest", "Ernten" },
        withered = { "ftdl_action_withered", "Verdorrt" },
        stones = { "ftdl_action_stones", "Steine" },
        cultivate = { "ftdl_action_cultivate", "Grubbern" },
        plow = { "ftdl_action_plow", "Pflügen" },
        lime = { "ftdl_action_lime", "Kalken" },
        sow = { "ftdl_action_sow", "Säen" },
        roller = { "ftdl_action_roller", "Walzen" },
        weed_combat = { "ftdl_action_weed_combat", "Unkraut" },
        weed_watch = { "ftdl_action_weed_watch", "Unkraut?" },
        pf_ph = { "ftdl_action_pf_ph", "Kalk/pH" },
        pf_n = { "ftdl_action_pf_n", "Düngen" },
        scs_moisture = { "ftdl_action_scs_moisture", "Bewässern" },
        scs_stress_high = { "ftdl_action_scs_stress_high", "Stress!" },
        scs_stress_watch = { "ftdl_action_scs_stress_watch", "Stress" },
        harvest_info = { "ftdl_action_harvest_info", "Ernte" },
        growing = { "ftdl_action_growing", "Wächst" },
        none = { "ftdl_action_none", "Ok" },
    }

    if action.actionType == "pf_n" and action.fertPass ~= nil and action.fertPassTotal ~= nil then
        return FieldAdvisor.getOrganicFertilizerPassLabel(action.fertPass, action.fertPassTotal)
    end

    local short = shortLabels[action.actionType]
    if short ~= nil then
        return FieldAdvisor.text(short[1], short[2])
    end

    local label = action.label or "-"
    label = string.gsub(label, " / gruppieren", "")
    label = string.gsub(label, "Wachsen lassen %(St%. %d+%)", FieldAdvisor.text("ftdl_action_growing", "Wächst"))
    return label
end

---@param actions table[]|nil
---@return table[]
function FieldAdvisor.getCycleableActions(actions)
    local cycleable = {}

    if actions == nil then
        return cycleable
    end

    for _, action in ipairs(actions) do
        if action.actionType ~= "none"
            and action.actionType ~= "growing"
            and action.actionType ~= "harvest_info"
            and action.actionType ~= "withered" then
            cycleable[#cycleable + 1] = action
        end
    end

    return cycleable
end

---@param action table|nil
---@param other table|nil
---@return boolean
function FieldAdvisor.isSameCycleableAction(action, other)
    if action == nil or other == nil then
        return false
    end

    if action.actionType ~= other.actionType then
        return false
    end

    if action.actionType == "pf_n" then
        return (tonumber(action.fertPass) or 1) == (tonumber(other.fertPass) or 1)
    end

    return true
end

---@param actions table[]|nil
---@param index number
---@return table|nil
function FieldAdvisor.getCycleableActionAt(actions, index)
    local cycleable = FieldAdvisor.getCycleableActions(actions)
    if #cycleable == 0 then
        return nil
    end

    local safeIndex = math.floor(tonumber(index) or 1)
    if safeIndex < 1 then
        safeIndex = 1
    end

    safeIndex = ((safeIndex - 1) % #cycleable) + 1
    return cycleable[safeIndex], safeIndex, #cycleable
end

---@param action table|nil
---@param index number
---@param total number
---@return string
function FieldAdvisor.formatCycledSuggestionLabel(action, index, total)
    if action == nil then
        return FieldAdvisor.text("ftdl_action_all_ok", "Alles ok")
    end

    local label = FieldAdvisor.getShortActionLabel(action)
    if action.fertPass ~= nil and action.fertPassTotal ~= nil then
        return label
    end

    if total <= 1 then
        return label
    end

    return string.format("%s  %d/%d", label, index, total)
end

---@param actions table[]|nil
---@param maxSteps number|nil
---@return string|nil
function FieldAdvisor.formatWorkOrderSuggestionPreview(actions, maxSteps)
    local cycleable = FieldAdvisor.getCycleableActions(actions)
    if #cycleable == 0 then
        return nil
    end

    local stepLimit = math.max(1, tonumber(maxSteps) or 4)
    if #cycleable == 1 then
        return FieldAdvisor.getShortActionLabel(cycleable[1])
    end

    local parts = {}
    for index = 1, math.min(#cycleable, stepLimit) do
        parts[#parts + 1] = FieldAdvisor.getShortActionLabel(cycleable[index])
    end

    local preview = table.concat(parts, " → ")
    if #cycleable > stepLimit then
        preview = FieldAdvisor.text("ftdl_action_preview_more", "%s (+%d)", preview, #cycleable - stepLimit)
    end

    return preview
end

---@param actions table[]|nil
---@param expectedHarvest string|nil
---@return string
function FieldAdvisor.formatSuggestionColumn(actions, expectedHarvest)
    if actions == nil or #actions == 0 then
        return FieldAdvisor.text("ftdl_action_all_ok", "Alles ok")
    end

    local workOrderPreview = FieldAdvisor.formatWorkOrderSuggestionPreview(actions, 4)
    if workOrderPreview ~= nil then
        return workOrderPreview
    end

    local displayLabels = {}
    for _, action in ipairs(actions) do
        if action.actionType ~= "none"
            and action.actionType ~= "growing"
            and action.actionType ~= "harvest_info" then
            displayLabels[#displayLabels + 1] = FieldAdvisor.getShortActionLabel(action)
        end
    end

    if #displayLabels == 0 then
        if expectedHarvest ~= nil and expectedHarvest ~= "" and expectedHarvest ~= "-" then
            return expectedHarvest
        end

        for _, action in ipairs(actions) do
            if action.actionType == "harvest_info" then
                local template = FieldAdvisor.text("ftdl_action_harvest_window", "Ernte %s", "___")
                local prefix = string.gsub(template, "%%s", "")
                local label = action.label or ""
                if prefix ~= "" and string.sub(label, 1, #prefix) == prefix then
                    return string.sub(label, #prefix + 1)
                end
                if label ~= "" then
                    return label
                end
            end
        end

        return FieldAdvisor.text("ftdl_action_growing", "Wächst")
    end

    local primary = displayLabels[1]
    if #displayLabels > 1 then
        return FieldAdvisor.text("ftdl_action_preview_more", "%s (+%d)", primary, #displayLabels - 1)
    end

    return primary
end

---@param actionType string
---@param context table
---@param actionMeta table|nil
---@return boolean
function FieldAdvisor.isActionComplete(actionType, context, actionMeta)
    return FieldTaskCompletion.isActionComplete(actionType, context, actionMeta)
end

---@param field table
---@param x number
---@param z number
---@return boolean
function FieldAdvisor.isPositionInsideField(field, x, z)
    local probes = {
        "isWorldPositionInField",
        "isWorldPositionInsideField",
        "isWorldPositionInside",
        "containsWorldPosition",
    }

    for _, probe in ipairs(probes) do
        local fn = field ~= nil and field[probe] or nil
        if type(fn) == "function" then
            local ok, result = pcall(fn, field, x, z)
            if ok and type(result) == "boolean" then
                return result
            end

            ok, result = pcall(fn, x, z)
            if ok and type(result) == "boolean" then
                return result
            end
        end
    end

    return true
end

---@param field table|nil
---@param fieldId number|nil
---@param worldX number|nil
---@param worldZ number|nil
---@return table|nil
function FieldAdvisor.captureTaskBaseline(field, fieldId, worldX, worldZ)
    local fieldState = FieldAdvisor.getEnrichedFieldState(field, fieldId, worldX, worldZ)
    if fieldState == nil then
        return nil
    end

    local context = FieldAdvisor.buildFieldContext(field, fieldState, worldX, worldZ)

    return {
        growthState = FieldAdvisor.getGrowthState(fieldState),
        lastGrowthState = FieldAdvisor.getLastGrowthState(fieldState),
        groundType = FieldAdvisor.getGroundTypeName(fieldState),
        fruitTypeIndex = FieldAdvisor.resolveFruitTypeIndex(fieldState, field),
        weedState = context.weedState,
        weedFactor = context.weedFactor,
        needsPlowing = context.needsPlowing,
        needsLime = context.needsLime,
        needsRolling = context.needsRolling,
        plowLevel = context.plowLevel,
        limeLevel = context.limeLevel,
        rollerLevel = context.rollerLevel,
        stoneLevel = context.stoneLevel,
        stubbleShredLevel = FieldAdvisor.getStateNumber(fieldState, "stubbleShredLevel"),
        wasGrassCut = FieldAdvisor.isGrassCut(fieldState, field),
        wasGrassHarvestable = FieldAdvisor.isGrassHarvestable(fieldState, field),
        phValue = context.pfSample ~= nil and context.pfSample.pHValue or nil,
        nitrogenValue = context.pfSample ~= nil and context.pfSample.nitrogenValue or nil,
    }
end

---@param task table
---@param scanner FieldScanner
---@return boolean
function FieldAdvisor.isFieldTaskComplete(task, scanner)
    if FieldTaskCompletion == nil then
        return false
    end

    return FieldTaskCompletion.isTaskComplete(task, scanner)
end

---@param field table
---@param fieldId number|nil
---@param fieldState table|nil
---@param worldX number|nil
---@param worldZ number|nil
---@return table|nil
function FieldAdvisor.resolveRepresentativeFieldState(field, fieldId, fieldState, worldX, worldZ)
    if field == nil then
        return fieldState
    end

    -- Fast path: center sample already provides usable crop information.
    if fieldState ~= nil then
        if FieldAdvisor.isGrassFieldState(fieldState, field) then
            return fieldState
        end
        if FieldAdvisor.isGrassHarvestable(fieldState, field) then
            return fieldState
        end
        if FieldAdvisor.resolveFruitTypeIndex(fieldState, field) ~= nil then
            return fieldState
        end
    end

    if worldX == nil or worldZ == nil then
        if field.getCenterOfFieldWorldPosition ~= nil then
            worldX, worldZ = field:getCenterOfFieldWorldPosition()
        end
    end

    if worldX == nil or worldZ == nil then
        return fieldState
    end

    local points = {}
    if FieldTaskCompletion ~= nil and FieldTaskCompletion.collectSamplePoints ~= nil then
        points = FieldTaskCompletion.collectSamplePoints(field, worldX, worldZ)
    end

    if points == nil or #points == 0 then
        return fieldState
    end

    local grassCandidate = nil
    local grassGrowth = -1
    local cropCandidate = nil
    for _, point in ipairs(points) do
        local sampleState = FieldAdvisor.getEnrichedFieldState(field, fieldId, point.x, point.z)
        if sampleState ~= nil then
            if FieldAdvisor.isGrassHarvestable(sampleState, field) then
                return sampleState
            end

            if FieldAdvisor.isGrassFieldState(sampleState, field) then
                local growth = FieldAdvisor.getEffectiveGrowthState(sampleState)
                if grassCandidate == nil or growth > grassGrowth then
                    grassCandidate = sampleState
                    grassGrowth = growth
                end
            end

            local sampleFruit = FieldAdvisor.resolveFruitTypeIndex(sampleState, field)
            if sampleFruit ~= nil and cropCandidate == nil and FieldAdvisor.hasActiveCrop(sampleState) then
                cropCandidate = sampleState
            end
        end
    end

    if grassCandidate ~= nil then
        return grassCandidate
    end
    if cropCandidate ~= nil then
        return cropCandidate
    end

    return fieldState
end

---@param task table
---@param context table
---@return boolean
function FieldAdvisor.hasCompletionProgress(task, context)
    local baseline = task ~= nil and task.completionBaseline or nil
    if baseline == nil or context == nil or context.fieldState == nil then
        return false
    end

    local fieldState = context.fieldState
    local actionType = task.actionType

    if FieldTaskCompletion ~= nil and FieldTaskCompletion.requiresCoverageOnly(FieldTaskCompletion.getEntry(actionType)) then
        return false
    end

    if actionType == "weed_combat" or actionType == "weed_watch" then
        if FieldAdvisor.isWeedDeadOrSprayed(fieldState) then
            return true
        end

        if FieldAdvisor.hasWeedFactorReading(fieldState) and baseline.weedFactor ~= nil then
            return FieldAdvisor.getWeedFactor(fieldState) < baseline.weedFactor - 0.01
        end

        return FieldAdvisor.getWeedStateLevel(fieldState) < (baseline.weedState or 0)
    end

    if actionType == "pf_ph" and context.pfSample ~= nil and context.pfSample.pHValue ~= nil and baseline.phValue ~= nil then
        return tonumber(context.pfSample.pHValue) > tonumber(baseline.phValue)
    end

    if actionType == "pf_n" and context.pfSample ~= nil and context.pfSample.nitrogenValue ~= nil and baseline.nitrogenValue ~= nil then
        return tonumber(context.pfSample.nitrogenValue) > tonumber(baseline.nitrogenValue)
    end

    return false
end

---@param field table
---@param fieldState table|nil
---@param worldX number|nil
---@param worldZ number|nil
---@return table labels
function FieldAdvisor.buildFieldLabels(field, fieldState, worldX, worldZ)
    local rules = FieldGameRules.get()
    local fieldId = field.getId ~= nil and field:getId() or nil
    local effectiveFieldState = FieldAdvisor.resolveRepresentativeFieldState(field, fieldId, fieldState, worldX, worldZ)

    local weedState = FieldAdvisor.getStateNumber(effectiveFieldState, "weedState")
    local stoneLevel = FieldAdvisor.getStateNumber(effectiveFieldState, "stoneLevel")
    local limeLevel = FieldAdvisor.getStateNumber(effectiveFieldState, "limeLevel")
    local rollerLevel = FieldAdvisor.getStateNumber(effectiveFieldState, "rollerLevel")
    local plowLevel = FieldAdvisor.getStateNumber(effectiveFieldState, "plowLevel")

    local needsRolling = FieldAdvisor.getStateBool(effectiveFieldState, "needsRolling")
    local needsPlowing = FieldAdvisor.getStateBool(effectiveFieldState, "needsPlowing")

    local context = FieldAdvisor.buildFieldContext(field, effectiveFieldState, worldX, worldZ)
    local actions = FieldAdvisor.resolveActionCandidates(
        field,
        effectiveFieldState,
        context.pfSample,
        context.scsSample,
        context.rules
    )
    local action = FieldAdvisor.selectPrimaryAction(actions)
    local fruitTypeIndex = FieldAdvisor.resolveFruitTypeIndex(effectiveFieldState, field)
    local partialSoilWork = FieldAdvisor.fieldHasPartialSoilWork(field, fieldId, effectiveFieldState, worldX, worldZ)

    return {
        weed = FieldAdvisor.formatWeedDisplayLabel(effectiveFieldState, rules),
        stones = FieldAdvisor.formatStoneLabel(stoneLevel, rules),
        lime = FieldAdvisor.formatLimeLabel(limeLevel, rules),
        roller = FieldAdvisor.formatRollerLabel(rollerLevel, needsRolling),
        plow = FieldAdvisor.formatPlowLabel(plowLevel, needsPlowing, rules),
        ph = context.pfSample ~= nil and context.pfSample.phLabel or nil,
        nitrogen = context.pfSample ~= nil and context.pfSample.nitrogenLabel or nil,
        moisture = context.scsSample ~= nil and context.scsSample.moistureLabel or nil,
        stress = context.scsSample ~= nil and context.scsSample.stressLabel or nil,
        fruit = FieldAdvisor.getFieldFruitDisplayLabel(field, fieldId, effectiveFieldState, worldX, worldZ),
        cropPhase = FieldAdvisor.getCropPhase(field, effectiveFieldState),
        expectedHarvest = FieldAdvisor.getExpectedHarvestLabel(field, effectiveFieldState),
        suggestion = FieldAdvisor.formatSuggestionColumn(actions, FieldAdvisor.getExpectedHarvestLabel(field, effectiveFieldState)),
        suggestionDetails = actions,
        actionType = action.actionType,
        autoComplete = action.autoComplete,
        isGrass = FieldAdvisor.isGrassFieldState(effectiveFieldState, field) and not partialSoilWork,
        showPrecisionFarming = PrecisionFarmingReader.isRuntimeReady(),
        showCropStress = SeasonalCropStressReader.isRuntimeReady(),
    }
end
