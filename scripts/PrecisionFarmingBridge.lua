--[[
    PrecisionFarmingBridge.lua
    Hooks PrecisionFarming.loadMap/initTerrain so g_precisionFarming and map objects stay reachable.
    Pattern from FS25_fieldCalculator PF bridge.
]]

PrecisionFarmingBridge = {}

PrecisionFarmingBridge.MOD_NAME = "FS25_precisionFarming"
PrecisionFarmingBridge.hooksInstalled = false
PrecisionFarmingBridge.loadMapHookInstalled = false
PrecisionFarmingBridge.initTerrainHookInstalled = false
PrecisionFarmingBridge.runtimeReady = false
PrecisionFarmingBridge.pfClass = nil
PrecisionFarmingBridge.pfInstance = nil
PrecisionFarmingBridge.soilMap = nil
PrecisionFarmingBridge.pHMap = nil
PrecisionFarmingBridge.nitrogenMap = nil
PrecisionFarmingBridge.coverMap = nil

local function safeGlobal(name)
    local ok, value = pcall(function()
        return _G[name]
    end)

    if ok then
        return value
    end

    return nil
end

local function getPFNamespace()
    local pfNamespace = safeGlobal("FS25_precisionFarming")
    if type(pfNamespace) == "table" then
        return pfNamespace
    end

    return nil
end

local function getPFClass()
    local pfClass = safeGlobal("PrecisionFarming")
    if type(pfClass) == "table" then
        return pfClass
    end

    local pfNamespace = getPFNamespace()
    if type(pfNamespace) == "table" and type(pfNamespace.PrecisionFarming) == "table" then
        return pfNamespace.PrecisionFarming
    end

    return nil
end

local function getPFInstance()
    local pfInstance = safeGlobal("g_precisionFarming")
    if type(pfInstance) == "table" then
        return pfInstance
    end

    if g_currentMission ~= nil and type(g_currentMission.g_precisionFarming) == "table" then
        return g_currentMission.g_precisionFarming
    end

    local pfNamespace = getPFNamespace()
    if type(pfNamespace) == "table" and type(pfNamespace.g_precisionFarming) == "table" then
        return pfNamespace.g_precisionFarming
    end

    return nil
end

---@param instance table
---@return boolean
function PrecisionFarmingBridge.updateAliases(instance)
    if type(instance) ~= "table" then
        return false
    end

    PrecisionFarmingBridge.pfInstance = instance
    PrecisionFarmingBridge.soilMap = instance.soilMap
    PrecisionFarmingBridge.pHMap = instance.pHMap
    PrecisionFarmingBridge.nitrogenMap = instance.nitrogenMap
    PrecisionFarmingBridge.coverMap = instance.coverMap
    PrecisionFarmingBridge.runtimeReady = PrecisionFarmingBridge.pHMap ~= nil
        and PrecisionFarmingBridge.nitrogenMap ~= nil

    _G.g_precisionFarming = instance

    if PrecisionFarmingBridge.pfClass ~= nil then
        _G.PrecisionFarming = PrecisionFarmingBridge.pfClass
    end

    if g_currentMission ~= nil then
        g_currentMission.g_precisionFarming = instance
    end

  local pfNamespace = getPFNamespace()
    if pfNamespace ~= nil then
        pfNamespace.g_precisionFarming = instance
    end

    return PrecisionFarmingBridge.runtimeReady
end

function PrecisionFarmingBridge.captureFromNamespace()
    PrecisionFarmingBridge.pfClass = getPFClass()

    if PrecisionFarmingBridge.pfClass ~= nil then
        _G.PrecisionFarming = PrecisionFarmingBridge.pfClass
    end

    local pfInstance = getPFInstance()
    if pfInstance ~= nil then
        return PrecisionFarmingBridge.updateAliases(pfInstance)
    end

    return false
end

function PrecisionFarmingBridge.pfLoadMapHook(self, superFunc, filename)
    local result
    if superFunc ~= nil then
        result = superFunc(self, filename)
    end

    PrecisionFarmingBridge.updateAliases(self)
    return result
end

function PrecisionFarmingBridge.pfInitTerrainHook(self, superFunc, mission, terrainId, filename)
    local result
    if superFunc ~= nil then
        result = superFunc(self, mission, terrainId, filename)
    end

    PrecisionFarmingBridge.updateAliases(self)
    return result
end

function PrecisionFarmingBridge.installHooks()
    if PrecisionFarmingBridge.hooksInstalled then
        return true
    end

    local pfClass = getPFClass()
    PrecisionFarmingBridge.pfClass = pfClass

    if type(pfClass) ~= "table" then
        return false
    end

    if not PrecisionFarmingBridge.loadMapHookInstalled and type(pfClass.loadMap) == "function" then
        pfClass.loadMap = Utils.overwrittenFunction(
            pfClass.loadMap,
            PrecisionFarmingBridge.pfLoadMapHook
        )
        PrecisionFarmingBridge.loadMapHookInstalled = true
    end

    if not PrecisionFarmingBridge.initTerrainHookInstalled and type(pfClass.initTerrain) == "function" then
        pfClass.initTerrain = Utils.overwrittenFunction(
            pfClass.initTerrain,
            PrecisionFarmingBridge.pfInitTerrainHook
        )
        PrecisionFarmingBridge.initTerrainHookInstalled = true
    end

    PrecisionFarmingBridge.hooksInstalled = PrecisionFarmingBridge.loadMapHookInstalled
        and PrecisionFarmingBridge.initTerrainHookInstalled

    return PrecisionFarmingBridge.hooksInstalled
end

---@return table|nil
function PrecisionFarmingBridge.getMaps()
    if not PrecisionFarmingBridge.runtimeReady then
        PrecisionFarmingBridge.captureFromNamespace()
    end

    if not PrecisionFarmingBridge.runtimeReady then
        return nil
    end

    return {
        soilMap = PrecisionFarmingBridge.soilMap,
        pHMap = PrecisionFarmingBridge.pHMap,
        nitrogenMap = PrecisionFarmingBridge.nitrogenMap,
        coverMap = PrecisionFarmingBridge.coverMap,
    }
end

function PrecisionFarmingBridge.update(dt)
    if not PrecisionFarmingBridge.hooksInstalled then
        PrecisionFarmingBridge.installHooks()
    end

    if not PrecisionFarmingBridge.runtimeReady then
        PrecisionFarmingBridge.captureFromNamespace()
    end
end

function PrecisionFarmingBridge.deleteMap()
    PrecisionFarmingBridge.runtimeReady = false
    PrecisionFarmingBridge.pfInstance = nil
    PrecisionFarmingBridge.soilMap = nil
    PrecisionFarmingBridge.pHMap = nil
    PrecisionFarmingBridge.nitrogenMap = nil
    PrecisionFarmingBridge.coverMap = nil
end

PrecisionFarmingBridge.installHooks()
PrecisionFarmingBridge.captureFromNamespace()
addModEventListener(PrecisionFarmingBridge)
