--[[
    PrecisionFarmingReader.lua
    Optional read-only access to FS25 Precision Farming pH / nitrogen.
]]

PrecisionFarmingReader = {}

PrecisionFarmingReader.MOD_NAME = "FS25_precisionFarming"

PrecisionFarmingReader.MONTH_NAMES_DE = {
    "Jan", "Feb", "Mär", "Apr", "Mai", "Jun",
    "Jul", "Aug", "Sep", "Okt", "Nov", "Dez",
}

---@param monthIndex number
---@return string
function PrecisionFarmingReader.getMonthName(monthIndex)
    if monthIndex == nil then
        return "-"
    end

    return PrecisionFarmingReader.MONTH_NAMES_DE[monthIndex] or tostring(monthIndex)
end

function PrecisionFarmingReader.isModLoaded()
    if g_modIsLoaded ~= nil and g_modIsLoaded[PrecisionFarmingReader.MOD_NAME] == true then
        return true
    end

    return PrecisionFarmingReader.getInstance() ~= nil
        or (PrecisionFarmingBridge ~= nil and PrecisionFarmingBridge.runtimeReady)
end

---@return boolean
function PrecisionFarmingReader.isRuntimeReady()
    if PrecisionFarmingBridge ~= nil then
        if not PrecisionFarmingBridge.runtimeReady then
            PrecisionFarmingBridge.captureFromNamespace()
        end

        if PrecisionFarmingBridge.runtimeReady then
            return true
        end
    end

    local maps = PrecisionFarmingReader.getMaps()
    return maps ~= nil and maps.pHMap ~= nil and maps.nitrogenMap ~= nil
end

---@return table|nil
function PrecisionFarmingReader.getInstance()
    if type(g_precisionFarming) == "table" then
        return g_precisionFarming
    end

    if g_currentMission ~= nil and type(g_currentMission.g_precisionFarming) == "table" then
        return g_currentMission.g_precisionFarming
    end

    local pfNamespace = rawget(_G, "FS25_precisionFarming")
    if type(pfNamespace) == "table" and type(pfNamespace.g_precisionFarming) == "table" then
        return pfNamespace.g_precisionFarming
    end

    if PrecisionFarmingBridge ~= nil and PrecisionFarmingBridge.pfInstance ~= nil then
        return PrecisionFarmingBridge.pfInstance
    end

    return nil
end

---@param instance table
---@param propertyName string
---@param getterName string
---@return table|nil
function PrecisionFarmingReader.resolveMap(instance, propertyName, getterName)
    if instance == nil then
        return nil
    end

    if instance[propertyName] ~= nil then
        return instance[propertyName]
    end

    local getter = instance[getterName]
    if type(getter) == "function" then
        local success, mapObject = pcall(getter, instance)
        if success and type(mapObject) == "table" then
            return mapObject
        end
    end

    return nil
end

---@return table|nil maps
function PrecisionFarmingReader.getMaps()
    if PrecisionFarmingBridge ~= nil then
        local bridgeMaps = PrecisionFarmingBridge.getMaps()
        if bridgeMaps ~= nil then
            return bridgeMaps
        end
    end

    local instance = PrecisionFarmingReader.getInstance()
    if instance == nil then
        return nil
    end

    local maps = {
        soilMap = PrecisionFarmingReader.resolveMap(instance, "soilMap", "getSoilMap"),
        pHMap = PrecisionFarmingReader.resolveMap(instance, "pHMap", "getPHMap"),
        nitrogenMap = PrecisionFarmingReader.resolveMap(instance, "nitrogenMap", "getNitrogenMap"),
        coverMap = PrecisionFarmingReader.resolveMap(instance, "coverMap", "getCoverMap"),
    }

    if maps.pHMap == nil and maps.nitrogenMap == nil then
        return nil
    end

    return maps
end

---@param map table|nil
---@param level number|nil
---@param usePh boolean
---@return number|nil
function PrecisionFarmingReader.toDisplayValue(map, level, usePh)
    if map == nil or level == nil then
        return nil
    end

    if usePh and map.getPhValueFromInternalValue ~= nil then
        local success, value = pcall(map.getPhValueFromInternalValue, map, level)
        if success and value ~= nil then
            return value
        end
    end

    if not usePh and map.getNitrogenValueFromInternalValue ~= nil then
        local success, value = pcall(map.getNitrogenValueFromInternalValue, map, level)
        if success and value ~= nil then
            return value
        end
    end

    return level
end

---@param field table|nil
---@return table|nil
function PrecisionFarmingReader.getSamplePoints(field, worldX, worldZ)
    if field ~= nil and field.getCenterOfFieldWorldPosition ~= nil then
        local centerX, centerZ = field:getCenterOfFieldWorldPosition()
        if centerX ~= nil and centerZ ~= nil then
            return {
                { x = centerX, z = centerZ },
                { x = centerX + 8, z = centerZ },
                { x = centerX - 8, z = centerZ },
                { x = centerX, z = centerZ + 8 },
                { x = centerX, z = centerZ - 8 },
            }
        end
    end

    if worldX ~= nil and worldZ ~= nil then
        return {
            { x = worldX, z = worldZ },
            { x = worldX + 8, z = worldZ },
            { x = worldX - 8, z = worldZ },
        }
    end

    return nil
end

---@param maps table
---@param phLevel number|nil
---@param nitrogenLevel number|nil
---@return table|nil
function PrecisionFarmingReader.formatSample(maps, phLevel, nitrogenLevel)
    local pHValue = PrecisionFarmingReader.toDisplayValue(maps.pHMap, phLevel, true)
    local nitrogenValue = PrecisionFarmingReader.toDisplayValue(maps.nitrogenMap, nitrogenLevel, false)

    if pHValue == nil and nitrogenValue == nil then
        return nil
    end

    local phLabel = "-"
    if pHValue ~= nil then
        phLabel = string.format("%.1f", pHValue)
    end

    local nitrogenLabel = "-"
    if nitrogenValue ~= nil then
        nitrogenLabel = string.format("%.0f", nitrogenValue)
    end

    return {
        phLabel = phLabel,
        nitrogenLabel = nitrogenLabel,
        pHValue = pHValue,
        nitrogenValue = nitrogenValue,
    }
end

---@param maps table
---@param samplePoints table[]
---@return table|nil
function PrecisionFarmingReader.sampleFromWorldPoints(maps, samplePoints)
    if maps == nil or samplePoints == nil or #samplePoints == 0 then
        return nil
    end

    local phSum, phCount = 0, 0
    local nitrogenSum, nitrogenCount = 0, 0

    for _, point in ipairs(samplePoints) do
        local pointX = point ~= nil and point.x or nil
        local pointZ = point ~= nil and point.z or nil

        if pointX ~= nil and pointZ ~= nil then
            if maps.pHMap ~= nil and maps.pHMap.getLevelAtWorldPos ~= nil then
                local success, pHLevel = pcall(maps.pHMap.getLevelAtWorldPos, maps.pHMap, pointX, pointZ)
                if success and pHLevel ~= nil then
                    local display = PrecisionFarmingReader.toDisplayValue(maps.pHMap, pHLevel, true)
                    if display ~= nil then
                        phSum = phSum + display
                        phCount = phCount + 1
                    end
                end
            end

            if maps.nitrogenMap ~= nil and maps.nitrogenMap.getLevelAtWorldPos ~= nil then
                local success, nitrogenLevel = pcall(maps.nitrogenMap.getLevelAtWorldPos, maps.nitrogenMap, pointX, pointZ)
                if success and nitrogenLevel ~= nil then
                    local display = PrecisionFarmingReader.toDisplayValue(maps.nitrogenMap, nitrogenLevel, false)
                    if display ~= nil then
                        nitrogenSum = nitrogenSum + display
                        nitrogenCount = nitrogenCount + 1
                    end
                end
            end
        end
    end

    local pHValue = phCount > 0 and (phSum / phCount) or nil
    local nitrogenValue = nitrogenCount > 0 and (nitrogenSum / nitrogenCount) or nil

    if pHValue == nil and nitrogenValue == nil then
        return nil
    end

    local phLabel = "-"
    if pHValue ~= nil then
        phLabel = string.format("%.1f", pHValue)
    end

    local nitrogenLabel = "-"
    if nitrogenValue ~= nil then
        nitrogenLabel = string.format("%.0f", nitrogenValue)
    end

    return {
        phLabel = phLabel,
        nitrogenLabel = nitrogenLabel,
        pHValue = pHValue,
        nitrogenValue = nitrogenValue,
    }
end

---@param fieldState table|nil
---@param maps table|nil
---@return table|nil
function PrecisionFarmingReader.sampleFromFieldState(fieldState, maps)
    if fieldState == nil or maps == nil then
        return nil
    end

    local phLevel = fieldState.phState or fieldState.pHState
    local nitrogenLevel = fieldState.nitrogenState

    if phLevel == nil and nitrogenLevel == nil then
        return nil
    end

    return PrecisionFarmingReader.formatSample(maps, phLevel, nitrogenLevel)
end

---@param worldX number|nil
---@param worldZ number|nil
---@param fieldState table|nil
---@param field table|nil
---@return table|nil sample
function PrecisionFarmingReader.sampleField(worldX, worldZ, fieldState, field)
    if not PrecisionFarmingReader.isModLoaded() then
        return nil
    end

    local maps = PrecisionFarmingReader.getMaps()
    if maps == nil then
        return nil
    end

    local sample = PrecisionFarmingReader.sampleFromFieldState(fieldState, maps)
    if sample ~= nil then
        return sample
    end

    local samplePoints = PrecisionFarmingReader.getSamplePoints(field, worldX, worldZ)
    if samplePoints ~= nil then
        sample = PrecisionFarmingReader.sampleFromWorldPoints(maps, samplePoints)
        if sample ~= nil then
            return sample
        end
    end

    if worldX == nil or worldZ == nil then
        return nil
    end

    local pHLevel = nil
    local nitrogenLevel = nil

    if maps.pHMap ~= nil and maps.pHMap.getLevelAtWorldPos ~= nil then
        local success, level = pcall(maps.pHMap.getLevelAtWorldPos, maps.pHMap, worldX, worldZ)
        if success then
            pHLevel = level
        end
    end

    if maps.nitrogenMap ~= nil and maps.nitrogenMap.getLevelAtWorldPos ~= nil then
        local success, level = pcall(maps.nitrogenMap.getLevelAtWorldPos, maps.nitrogenMap, worldX, worldZ)
        if success then
            nitrogenLevel = level
        end
    end

    return PrecisionFarmingReader.formatSample(maps, pHLevel, nitrogenLevel)
end

---@return string
function PrecisionFarmingReader.getCurrentMonthLabel()
    if g_currentMission == nil or g_currentMission.environment == nil then
        return "-"
    end

    local environment = g_currentMission.environment
    local currentDay = environment.currentDay or 1
    local daysPerPeriod = environment.daysPerPeriod or 1
    if daysPerPeriod <= 0 then
        daysPerPeriod = 1
    end

    local periodIndex = math.floor((currentDay - 1) / daysPerPeriod) % 12
    return PrecisionFarmingReader.getMonthName(periodIndex + 1)
end
