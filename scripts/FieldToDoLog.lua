--[[
    FieldToDoLog.lua
    In-game logging: one info block on savegame load (mods + sidecar data).
    Everything else: warnings and errors only.
]]

FieldToDoLog = {}
FieldToDoLog.PREFIX = "[FS25_FieldToDoList]"

---@param message string
---@param ... any
function FieldToDoLog.info(message, ...)
    if Logging == nil or Logging.info == nil then
        return
    end

    Logging.info("%s %s", FieldToDoLog.PREFIX, string.format(message, ...))
end

---@param message string
---@param ... any
function FieldToDoLog.warning(message, ...)
    if Logging == nil or Logging.warning == nil then
        return
    end

    Logging.warning("%s %s", FieldToDoLog.PREFIX, string.format(message, ...))
end

---@param message string
---@param ... any
function FieldToDoLog.error(message, ...)
    if Logging == nil or Logging.error == nil then
        if Logging ~= nil and Logging.warning ~= nil then
            Logging.warning("%s %s", FieldToDoLog.PREFIX, string.format(message, ...))
        end
        return
    end

    Logging.error("%s %s", FieldToDoLog.PREFIX, string.format(message, ...))
end

---@return number
function FieldToDoLog.countTasks(todoManager)
    if todoManager == nil or todoManager.manualTasks == nil then
        return 0
    end

    local count = 0
    for _ in pairs(todoManager.manualTasks) do
        count = count + 1
    end

    return count
end

---@return number
function FieldToDoLog.countScsFields()
    if SeasonalCropStressReader == nil or not SeasonalCropStressReader.isModLoaded() then
        return 0
    end

    local manager = SeasonalCropStressReader.getManager()
    if manager == nil or manager.soilSystem == nil or manager.soilSystem.fieldData == nil then
        return 0
    end

    local count = 0
    for _ in pairs(manager.soilSystem.fieldData) do
        count = count + 1
    end

    return count
end

---@return string
function FieldToDoLog.describePrecisionFarming()
    if PrecisionFarmingReader == nil or not PrecisionFarmingReader.isModLoaded() then
        return "Precision Farming: not loaded"
    end

    if PrecisionFarmingReader.isRuntimeReady ~= nil and PrecisionFarmingReader.isRuntimeReady() then
        return "Precision Farming: loaded, pH/N maps ready"
    end

    return "Precision Farming: loaded, no map data yet"
end

---@return string
function FieldToDoLog.describeSeasonalCropStress()
    if SeasonalCropStressReader == nil or not SeasonalCropStressReader.isModLoaded() then
        return "Seasonal Crop Stress: not loaded (install FS25_SeasonalCropStress)"
    end

    if SeasonalCropStressReader.ensureInitialized ~= nil then
        SeasonalCropStressReader.ensureInitialized()
    end

    local fieldCount = FieldToDoLog.countScsFields()
    if SeasonalCropStressReader.isRuntimeReady ~= nil and SeasonalCropStressReader.isRuntimeReady() then
        if fieldCount > 0 then
            return string.format("Seasonal Crop Stress: loaded, %d field(s) in soil data", fieldCount)
        end

        return "Seasonal Crop Stress: loaded, runtime ready, no field data"
    end

    if fieldCount > 0 then
        return string.format("Seasonal Crop Stress: loaded, %d field(s), still initializing", fieldCount)
    end

    local manager = SeasonalCropStressReader.getManager ~= nil and SeasonalCropStressReader.getManager() or nil
    if manager == nil then
        return "Seasonal Crop Stress: mod active but mission bridge missing (use g_currentMission.cropStressManager)"
    end

    return "Seasonal Crop Stress: loaded, field data not ready yet (normal right after load — reopen menu or use csStatus)"
end

---@param todoManager ToDoManager|nil
---@param savegameDirectory string|nil
---@param loadStatus string|nil  "missing" | "failed" | "ok"
function FieldToDoLog.logSavegameStartup(todoManager, savegameDirectory, loadStatus)
    local dirLabel = savegameDirectory
    if string.isNilOrWhitespace(dirLabel) then
        dirLabel = "(no savegame directory)"
    end

    FieldToDoLog.info("Savegame load — %s", dirLabel)

    if loadStatus == "missing" then
        FieldToDoLog.info("fieldToDoList.xml: not found (new save, defaults)")
    elseif loadStatus == "failed" then
        FieldToDoLog.error("fieldToDoList.xml: present but could not be loaded")
    else
        local taskCount = FieldToDoLog.countTasks(todoManager)
        local preset = FieldAdvisorSettings ~= nil and FieldAdvisorSettings.getWorkOrderPreset() or "-"
        local organic = FieldAdvisorSettings ~= nil and FieldAdvisorSettings.isOrganicMultiPassEnabled() or false
        FieldToDoLog.info(
            "fieldToDoList.xml: loaded (%d task(s), work order '%s', organic multi-pass %s)",
            taskCount,
            tostring(preset),
            organic and "on" or "off"
        )
    end

    FieldToDoLog.info(FieldToDoLog.describePrecisionFarming())
    FieldToDoLog.info(FieldToDoLog.describeSeasonalCropStress())
end
