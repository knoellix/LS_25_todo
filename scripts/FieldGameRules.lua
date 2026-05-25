--[[
    FieldGameRules.lua
    Reads savegame / career rules (stones, weeds, lime, plowing) from the active mission.
]]

FieldGameRules = {}

---@return table rules
function FieldGameRules.get()
    local rules = {
        stonesEnabled = true,
        weedsEnabled = true,
        limeRequired = true,
        plowingRequiredEnabled = true,
    }

    if g_currentMission == nil or g_currentMission.missionInfo == nil then
        return rules
    end

    local missionInfo = g_currentMission.missionInfo

    if missionInfo.stonesEnabled ~= nil then
        rules.stonesEnabled = missionInfo.stonesEnabled
    end

    if missionInfo.weedsEnabled ~= nil then
        rules.weedsEnabled = missionInfo.weedsEnabled
    end

    if missionInfo.limeRequired ~= nil then
        rules.limeRequired = missionInfo.limeRequired
    end

    if missionInfo.plowingRequiredEnabled ~= nil then
        rules.plowingRequiredEnabled = missionInfo.plowingRequiredEnabled
    end

    return rules
end
