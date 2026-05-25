--[[
    FieldScanner.lua
    Data acquisition layer: reads owned field fruit types, growth stages, and conditions.
]]

---@class FieldScanner
---@field mission table
---@field modDirectory string
FieldScanner = {}
local FieldScanner_mt = Class(FieldScanner)

---@param mission table
---@param modDirectory string
---@return FieldScanner
function FieldScanner.new(mission, modDirectory)
    local self = setmetatable({}, FieldScanner_mt)

    self.mission = mission
    self.modDirectory = modDirectory

    return self
end

function FieldScanner:delete()
    self.mission = nil
end

---@param field table
---@return string
function FieldScanner:getFruitName(field)
    local fieldState = FieldAdvisor.getFieldState(field)

    if fieldState ~= nil and fieldState.fruitTypeIndex ~= nil then
        if fieldState.fruitTypeIndex == FruitType.UNKNOWN then
            return "-"
        end

        local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(fieldState.fruitTypeIndex)
        if fruitDesc ~= nil then
            local fillType = g_fillTypeManager:getFillTypeByIndex(fruitDesc.fillType)
            if fillType ~= nil then
                return fillType.title or fillType.name or "-"
            end

            return fruitDesc.name or "-"
        end
    end

    if field.fieldState == nil or field.fieldState.fruitTypeIndex == nil then
        return "-"
    end

    if field.fieldState.fruitTypeIndex == FruitType.UNKNOWN then
        return "-"
    end

    local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(field.fieldState.fruitTypeIndex)
    if fruitDesc == nil then
        return "-"
    end

    local fillType = g_fillTypeManager:getFillTypeByIndex(fruitDesc.fillType)
    if fillType ~= nil then
        return fillType.title or fillType.name or "-"
    end

    return fruitDesc.name or "-"
end

---@param field table
---@return string
function FieldScanner:getGrowthLabel(field)
    local fieldState = FieldAdvisor.getFieldState(field)
    if fieldState ~= nil then
        return FieldAdvisor.formatGrowthLabel(fieldState)
    end

    return "-"
end

---@param field table
---@return boolean
function FieldScanner:isPlayerOwnedField(field)
    if field == nil then
        return false
    end

    if field.getHasOwner ~= nil and field:getHasOwner() then
        return true
    end

    if field.fieldState ~= nil and self.mission ~= nil and field.fieldState.ownerFarmId ~= nil then
        local farmId = self.mission:getFarmId()
        if farmId ~= nil and field.fieldState.ownerFarmId == farmId then
            return true
        end
    end

    return false
end

---@param field table
---@return table|nil fieldRecord
function FieldScanner:normalizeField(field)
    if field == nil or not self:isPlayerOwnedField(field) then
        return nil
    end

    local posX, posZ = field:getCenterOfFieldWorldPosition()
    if posX ~= nil and posZ ~= nil and field.fieldState ~= nil and field.fieldState.update ~= nil then
        field.fieldState:update(posX, posZ)
    end

    local fieldState = FieldAdvisor.getFieldState(field)
    local labels = FieldAdvisor.buildFieldLabels(field, fieldState, posX, posZ)

    local fieldId = field.getId ~= nil and field:getId() or 0
    local fieldName = field.name
    if string.isNilOrWhitespace(fieldName) then
        fieldName = string.format("Feld %d", fieldId)
    end

    local scsFieldId = nil
    if SeasonalCropStressReader ~= nil then
        scsFieldId = SeasonalCropStressReader.resolveScsFieldId(field, nil)
    end

    return {
        id = fieldId,
        farmlandId = scsFieldId,
        scsFieldId = scsFieldId,
        name = fieldName,
        worldX = posX,
        worldZ = posZ,
        fruit = labels.fruit or self:getFruitName(field),
        growthState = self:getGrowthLabel(field),
        expectedHarvest = labels.expectedHarvest or "-",
        cropPhase = labels.cropPhase,
        areaHa = field.areaHa or 0,
        weed = labels.weed,
        stones = labels.stones,
        lime = labels.lime,
        roller = labels.roller,
        ph = labels.ph,
        nitrogen = labels.nitrogen,
        moisture = labels.moisture,
        stress = labels.stress,
        suggestion = labels.suggestion,
        suggestionDetails = labels.suggestionDetails,
        actionType = labels.actionType,
        autoComplete = labels.autoComplete,
        isGrass = labels.isGrass == true,
        showPrecisionFarming = labels.showPrecisionFarming,
        showCropStress = labels.showCropStress,
    }
end

---@param fieldId number
---@return table|nil
function FieldScanner:getEngineFieldById(fieldId)
    if fieldId == nil or g_fieldManager == nil then
        return nil
    end

    local allFields = g_fieldManager.fields
    if allFields == nil and g_fieldManager.getFields ~= nil then
        allFields = g_fieldManager:getFields()
    end

    if allFields == nil then
        return nil
    end

    for _, field in pairs(allFields) do
        local currentId = field.getId ~= nil and field:getId() or nil
        if currentId == fieldId then
            return field
        end
    end

    return nil
end

---Collects owned fields for the overview panel.
---@return table[] fields
function FieldScanner:scanOwnedFields()
    local fields = {}

    if g_fieldManager == nil then
        return fields
    end

    -- Same source as SeasonalCropStress (g_fieldManager.fields); fallback to getFields().
    local allFields = g_fieldManager.fields
    if allFields == nil and g_fieldManager.getFields ~= nil then
        allFields = g_fieldManager:getFields()
    end

    if allFields == nil then
        return fields
    end

    for _, field in pairs(allFields) do
        local ok, record = pcall(function()
            return self:normalizeField(field)
        end)

        if ok and record ~= nil then
            table.insert(fields, record)
        end
    end

    table.sort(fields, function(a, b)
        if a.id == b.id then
            return a.name < b.name
        end
        return a.id < b.id
    end)

    return fields
end

---@param fieldId number
---@return table|nil field
function FieldScanner:getFieldById(fieldId)
    for _, field in ipairs(self:scanOwnedFields()) do
        if field.id == fieldId then
            return field
        end
    end

    return nil
end
