--[[
    SeasonalCropStressReader.lua
    Read-only bridge to FS25_SeasonalCropStress.
    FS25: g_cropStressManager in getfenv(0) is per-mod — use g_currentMission.cropStressManager.
    https://github.com/TheCodingDad-TisonK/FS25_SeasonalCropStress
]]

SeasonalCropStressReader = {}

SeasonalCropStressReader.MOD_NAME = "FS25_SeasonalCropStress"

---@return boolean
function SeasonalCropStressReader.isSaveInProgress()
    if g_currentMission ~= nil then
        if g_currentMission.isSaving == true or g_currentMission.isSavePending == true then
            return true
        end
    end

    if g_savegameController ~= nil then
        if g_savegameController.isSaving == true or g_savegameController.savePending == true then
            return true
        end
    end

    return false
end

---@return table|nil
function SeasonalCropStressReader.getManager()
    if g_currentMission ~= nil and g_currentMission.cropStressManager ~= nil then
        return g_currentMission.cropStressManager
    end

    if type(g_cropStressManager) == "table" then
        return g_cropStressManager
    end

    return nil
end

---@return boolean
function SeasonalCropStressReader.isModLoaded()
    if SeasonalCropStressReader.getManager() ~= nil then
        return true
    end

    if g_modIsLoaded ~= nil and g_modIsLoaded[SeasonalCropStressReader.MOD_NAME] == true then
        return true
    end

    return false
end

---@param fieldData table|nil
---@param farmlandId number|string|nil
---@return any
function SeasonalCropStressReader.lookupFieldData(fieldData, farmlandId)
    if fieldData == nil or farmlandId == nil then
        return nil
    end

    local entry = fieldData[farmlandId]
    if entry ~= nil then
        return entry
    end

    local asNumber = tonumber(farmlandId)
    if asNumber ~= nil then
        entry = fieldData[asNumber]
        if entry ~= nil then
            return entry
        end
    end

    return fieldData[tostring(farmlandId)]
end

--- Read-only: never call SCS buildFieldMap/enumerateFields (touches fields.xml; broke saves after audit).
---@param _force boolean|nil ignored
---@return boolean
function SeasonalCropStressReader.refreshFieldData(_force)
    local manager = SeasonalCropStressReader.getManager()
    if manager == nil or manager.soilSystem == nil or manager.soilSystem.fieldData == nil then
        return false
    end

    return next(manager.soilSystem.fieldData) ~= nil
end

function SeasonalCropStressReader.ensureInitialized()
    local manager = SeasonalCropStressReader.getManager()
    if manager == nil or manager.soilSystem == nil or manager.soilSystem.fieldData == nil then
        return false
    end

    if manager.isInitialized ~= true then
        return false
    end

    return next(manager.soilSystem.fieldData) ~= nil
end

---@return boolean
function SeasonalCropStressReader.isRuntimeReady()
    if not SeasonalCropStressReader.ensureInitialized() then
        return false
    end

    local manager = SeasonalCropStressReader.getManager()
    if manager == nil or manager.soilSystem == nil or manager.soilSystem.fieldData == nil then
        return false
    end

    return next(manager.soilSystem.fieldData) ~= nil
end

---@param field table|nil
---@return number|nil posX
---@return number|nil posZ
function SeasonalCropStressReader.getFieldWorldPosition(field)
    if field == nil then
        return nil, nil
    end

    local posX, posZ = FieldAdvisor.getFieldCenterWorldPosition(field)
    if posX ~= nil and posZ ~= nil then
        return posX, posZ
    end

    if field.posX ~= nil and field.posZ ~= nil then
        return field.posX, field.posZ
    end

    if field.worldX ~= nil and field.worldZ ~= nil then
        return field.worldX, field.worldZ
    end

    return nil, nil
end

---@param posX number|nil
---@param posZ number|nil
---@return number|nil farmlandId
function SeasonalCropStressReader.resolveFarmlandIdAtPosition(posX, posZ)
    if posX == nil or posZ == nil then
        return nil
    end

    if g_farmlandManager ~= nil and g_farmlandManager.getFarmlandAtWorldPosition ~= nil then
        local success, farmland = pcall(g_farmlandManager.getFarmlandAtWorldPosition, g_farmlandManager, posX, posZ)
        if success and farmland ~= nil and farmland.id ~= nil then
            return farmland.id
        end
    end

    return nil
end

---@param fieldData table
---@param posX number
---@param posZ number
---@return number|nil farmlandId
function SeasonalCropStressReader.findFarmlandIdNearPosition(fieldData, posX, posZ)
    local bestId = nil
    local bestDistance = nil

    for farmlandId, entry in pairs(fieldData) do
        if type(entry) == "table" then
            local centerX = tonumber(entry.centerX)
            local centerZ = tonumber(entry.centerZ)
            if centerX ~= nil and centerZ ~= nil then
                local dx = posX - centerX
                local dz = posZ - centerZ
                local distance = dx * dx + dz * dz
                if bestDistance == nil or distance < bestDistance then
                    bestDistance = distance
                    bestId = farmlandId
                end
            end
        end
    end

    if bestDistance ~= nil and bestDistance <= 202500 then
        return bestId
    end

    return nil
end

--- SCS keys soilSystem.fieldData by farmland.id (SoilMoistureSystem:enumerateFields).
---@param field table|nil
---@param manager table|nil
---@return number|nil scsFieldId
function SeasonalCropStressReader.resolveScsFieldId(field, manager)
    if field == nil then
        return nil
    end

    manager = manager or SeasonalCropStressReader.getManager()
    if manager ~= nil then
        SeasonalCropStressReader.ensureInitialized()
    end

    if manager ~= nil and manager.fieldById ~= nil then
        for farmlandId, mappedField in pairs(manager.fieldById) do
            if mappedField == field then
                return farmlandId
            end
        end
    end

    if field.farmland ~= nil and field.farmland.id ~= nil then
        return field.farmland.id
    end

    if field.scsFieldId ~= nil then
        return field.scsFieldId
    end

    if field.farmlandId ~= nil then
        return field.farmlandId
    end

    local posX, posZ = SeasonalCropStressReader.getFieldWorldPosition(field)
    if posX ~= nil and posZ ~= nil then
        local farmlandId = SeasonalCropStressReader.resolveFarmlandIdAtPosition(posX, posZ)
        if farmlandId ~= nil then
            return farmlandId
        end
    end

    if manager ~= nil and manager.soilSystem ~= nil and manager.soilSystem.fieldData ~= nil and posX ~= nil and posZ ~= nil then
        return SeasonalCropStressReader.findFarmlandIdNearPosition(manager.soilSystem.fieldData, posX, posZ)
    end

    return nil
end

---@param field table|nil
---@param manager table|nil
---@return number|nil farmlandId
function SeasonalCropStressReader.resolveFarmlandId(field, manager)
    return SeasonalCropStressReader.resolveScsFieldId(field, manager)
end

---@param manager table
---@param scsFieldId number|string
---@return number|nil
function SeasonalCropStressReader.readFieldMoisture(manager, scsFieldId)
    if manager == nil or manager.soilSystem == nil or scsFieldId == nil then
        return nil
    end

    local soilData = manager.soilSystem.fieldData ~= nil
        and SeasonalCropStressReader.lookupFieldData(manager.soilSystem.fieldData, scsFieldId)
        or nil
    if soilData ~= nil and soilData.moisture ~= nil then
        return tonumber(soilData.moisture)
    end

    if manager.soilSystem.getMoisture ~= nil then
        local success, moisture = pcall(manager.soilSystem.getMoisture, manager.soilSystem, scsFieldId)
        if success and moisture ~= nil then
            return tonumber(moisture)
        end
    end

    return nil
end

---@param manager table
---@param scsFieldId number|string
---@return number|nil
function SeasonalCropStressReader.readFieldStress(manager, scsFieldId)
    if manager == nil or scsFieldId == nil then
        return nil
    end

    if manager.stressModifier ~= nil and manager.stressModifier.fieldStress ~= nil then
        local stress = SeasonalCropStressReader.lookupFieldData(manager.stressModifier.fieldStress, scsFieldId)
        if stress ~= nil then
            return tonumber(stress)
        end
    end

    if manager.stressModifier ~= nil and manager.stressModifier.getStress ~= nil then
        local success, stressValue = pcall(manager.stressModifier.getStress, manager.stressModifier, scsFieldId)
        if success and stressValue ~= nil then
            return tonumber(stressValue)
        end
    end

    return nil
end

---@param scsFieldId number|string
---@return table|nil sample
function SeasonalCropStressReader.sampleFarmlandId(scsFieldId)
    if scsFieldId == nil or not SeasonalCropStressReader.ensureInitialized() then
        return nil
    end

    local manager = SeasonalCropStressReader.getManager()
    local soilData = manager.soilSystem.fieldData ~= nil
        and SeasonalCropStressReader.lookupFieldData(manager.soilSystem.fieldData, scsFieldId)
        or nil
    local moisture = SeasonalCropStressReader.readFieldMoisture(manager, scsFieldId)
    local stress = SeasonalCropStressReader.readFieldStress(manager, scsFieldId)

    if moisture == nil and stress == nil and soilData == nil then
        return nil
    end

    moisture = moisture or 0
    stress = stress or 0

    return {
        moisture = moisture,
        stress = stress,
        moistureLabel = string.format("%d%%", math.floor(moisture * 100 + 0.5)),
        stressLabel = string.format("%d%%", math.floor(stress * 100 + 0.5)),
    }
end

---@param field table|nil
---@return table|nil sample { moistureLabel, stressLabel, moisture, stress }
function SeasonalCropStressReader.sampleField(field)
    if not SeasonalCropStressReader.isModLoaded() then
        return nil
    end

    if not SeasonalCropStressReader.ensureInitialized() then
        return nil
    end

    local manager = SeasonalCropStressReader.getManager()
    local farmlandId = SeasonalCropStressReader.resolveFarmlandId(field, manager)
    if farmlandId == nil then
        return nil
    end

    return SeasonalCropStressReader.sampleFarmlandId(farmlandId)
end

---@param worldX number|nil
---@param worldZ number|nil
---@param engineField table|nil
---@return table|nil
function SeasonalCropStressReader.sampleAtWorldPosition(worldX, worldZ, engineField)
    if engineField ~= nil then
        local sample = SeasonalCropStressReader.sampleField(engineField)
        if sample ~= nil then
            return sample
        end
    end

    if not SeasonalCropStressReader.ensureInitialized() then
        return nil
    end

    local farmlandId = SeasonalCropStressReader.resolveFarmlandIdAtPosition(worldX, worldZ)
    if farmlandId == nil then
        local manager = SeasonalCropStressReader.getManager()
        if manager ~= nil and manager.soilSystem ~= nil and worldX ~= nil and worldZ ~= nil then
            farmlandId = SeasonalCropStressReader.findFarmlandIdNearPosition(manager.soilSystem.fieldData, worldX, worldZ)
        end
    end

    if farmlandId == nil then
        return nil
    end

    return SeasonalCropStressReader.sampleFarmlandId(farmlandId)
end

---@return string
function SeasonalCropStressReader.getIntegrationStatusLabel()
    if not SeasonalCropStressReader.isModLoaded() then
        return FieldToDoL10n.getText("ftdl_scs_off", "SCS: aus")
    end

    local manager = SeasonalCropStressReader.getManager()
    if manager == nil then
        return FieldToDoL10n.getText("ftdl_scs_loading", "SCS: lädt…")
    end

    if manager.isInitialized ~= true then
        return FieldToDoL10n.getText("ftdl_scs_loading", "SCS: lädt…")
    end

    if not SeasonalCropStressReader.isRuntimeReady() then
        return FieldToDoL10n.getText("ftdl_scs_loading", "SCS: lädt…")
    end

    local count = 0
    if manager.soilSystem ~= nil and manager.soilSystem.fieldData ~= nil then
        for _ in pairs(manager.soilSystem.fieldData) do
            count = count + 1
        end
    end

    return FieldToDoL10n.getText("ftdl_scs_fields", "SCS: %d Felder", count)
end
