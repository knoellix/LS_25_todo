--[[
    FieldVisit.lua
    Teleport local player to a field center (map visit QoL).
]]

FieldVisit = {}

FieldVisit.TELEPORT_HEIGHT_OFFSET = 0.35

---@param field table|nil engine field or field record with worldX/worldZ
---@return number|nil
---@return number|nil
function FieldVisit.getFieldWorldPosition(field)
    if field == nil then
        return nil, nil
    end

    if field.getCenterOfFieldWorldPosition ~= nil then
        local x, z = field:getCenterOfFieldWorldPosition()
        if x ~= nil and z ~= nil then
            return x, z
        end
    end

    if field.worldX ~= nil and field.worldZ ~= nil then
        return field.worldX, field.worldZ
    end

    if field.posX ~= nil and field.posZ ~= nil then
        return field.posX, field.posZ
    end

    return nil, nil
end

---@return number|nil
function FieldVisit.getTerrainRootNode()
    if g_terrainNode ~= nil and g_terrainNode ~= 0 then
        return g_terrainNode
    end

    if g_currentMission ~= nil and g_currentMission.terrainRootNode ~= nil then
        return g_currentMission.terrainRootNode
    end

    return nil
end

---@param x number
---@param z number
---@return number|nil
function FieldVisit.sampleTerrainHeight(x, z)
    if type(getTerrainHeightAtWorldPos) ~= "function" then
        return nil
    end

    local terrainNode = FieldVisit.getTerrainRootNode()
    if terrainNode == nil then
        return nil
    end

    local success, y = pcall(getTerrainHeightAtWorldPos, terrainNode, x, 0, z)
    if success and y ~= nil and y > -1000 and y < 10000 then
        return y
    end

    success, y = pcall(getTerrainHeightAtWorldPos, terrainNode, x, z)
    if success and y ~= nil and y > -1000 and y < 10000 then
        return y
    end

    return nil
end

---@param x number
---@param z number
---@return number
function FieldVisit.getTerrainY(x, z)
    local y = FieldVisit.sampleTerrainHeight(x, z)

    if y == nil and g_currentMission ~= nil and g_currentMission.getTerrainHeightAtWorldPos ~= nil then
        local success, missionY = pcall(g_currentMission.getTerrainHeightAtWorldPos, g_currentMission, x, z)
        if success and missionY ~= nil and missionY > -1000 and missionY < 10000 then
            y = missionY
        end
    end

    if y == nil then
        y = 0
    end

    return y + FieldVisit.TELEPORT_HEIGHT_OFFSET
end

---@param x number
---@param y number
---@param z number
---@return boolean
function FieldVisit.teleportPlayerTo(x, y, z)
    if g_currentMission ~= nil and g_currentMission.tryExitVehicle ~= nil then
        pcall(g_currentMission.tryExitVehicle, g_currentMission)
    end

    local player = g_localPlayer
    if player == nil and g_currentMission ~= nil then
        player = g_currentMission.player
    end

    if player == nil then
        return false
    end

    if player.teleportTo ~= nil then
        local success, result = pcall(player.teleportTo, player, x, y, z)
        if success and result ~= false then
            return true
        end
    end

    if player.teleportPlayer ~= nil then
        local success, result = pcall(player.teleportPlayer, player, x, y, z)
        if success and result ~= false then
            return true
        end
    end

    if player.setWorldPosition ~= nil then
        local success, result = pcall(player.setWorldPosition, player, x, y, z)
        if success and result ~= false then
            return true
        end
    end

    if player.rootNode ~= nil then
        local success = pcall(setWorldTranslation, player.rootNode, x, y, z)
        if success then
            return true
        end
    end

    return false
end

---@param field table|nil
---@param scanner FieldScanner|nil
---@return boolean
---@return string|nil
function FieldVisit.visitField(field, scanner)
    local engineField = field

    if field ~= nil and field.id ~= nil and scanner ~= nil and scanner.getEngineFieldById ~= nil then
        engineField = scanner:getEngineFieldById(field.id) or field
    end

    local x, z = FieldVisit.getFieldWorldPosition(engineField)
    if x == nil or z == nil then
        return false, "no_position"
    end

    local y = FieldVisit.getTerrainY(x, z)

    if g_gui ~= nil and g_gui.showGui ~= nil then
        pcall(g_gui.showGui, g_gui, "")
    end

    if not FieldVisit.teleportPlayerTo(x, y, z) then
        return false, "teleport_failed"
    end

    return true, nil
end
