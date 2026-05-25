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
}

FieldAdvisor.JOB_COMPLETION_THRESHOLD = 0.98
FieldAdvisor.JOB_SAMPLE_GRID_STEPS = 2

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

    if field.groundType == "HARVEST_READY" then
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
---@return boolean
function FieldAdvisor.isGrassCrop(fruitTypeIndex)
    local fruitName = FieldAdvisor.getFruitTypeName(fruitTypeIndex)
    if fruitName == nil then
        return false
    end

    return FieldAdvisor.GRASS_FRUIT_NAMES[string.upper(fruitName)] == true
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
---@return boolean
function FieldAdvisor.isFieldUnsown(fieldState)
    local fruitTypeIndex = FieldAdvisor.getFruitTypeIndex(fieldState)
    if fruitTypeIndex == nil then
        return true
    end

    if FruitType ~= nil and fruitTypeIndex == FruitType.UNKNOWN then
        return true
    end

    return FieldAdvisor.getGrowthState(fieldState) <= 0
end

---@param fieldState table|nil
---@return boolean
function FieldAdvisor.hasActiveCrop(fieldState)
    if FieldAdvisor.isFieldUnsown(fieldState) then
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
    local growthState = FieldAdvisor.getGrowthState(fieldState)
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

---@param field table
---@param fieldState table|nil
---@return string
function FieldAdvisor.getCropPhase(field, fieldState)
    if FieldAdvisor.isHarvestReady(field, fieldState) then
        return "harvest_ready"
    end

    if FieldAdvisor.isWithered(fieldState) then
        return "withered"
    end

    if FieldAdvisor.hasActiveCrop(fieldState) then
        return "growing"
    end

    if FieldAdvisor.isFieldUnsown(fieldState) then
        return "empty"
    end

    return "post_harvest"
end

---@param field table
---@param fieldState table|nil
---@return string
function FieldAdvisor.getExpectedHarvestLabel(field, fieldState)
    if FieldAdvisor.isFieldUnsown(fieldState) then
        return "-"
    end

    if FieldAdvisor.isWithered(fieldState) then
        return FieldAdvisor.text("ftdl_action_withered", "Verdorrt")
    end

    if FieldAdvisor.isHarvestReady(field, fieldState) then
        return FieldAdvisor.text(
            "ftdl_action_harvest_now_short",
            "Jetzt (%s)",
            PrecisionFarmingReader.getCurrentMonthLabel()
        )
    end

    local fruitTypeIndex = FieldAdvisor.getFruitTypeIndex(fieldState)
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
        local parts = {}
        for _, monthIndex in ipairs(fruitDesc.harvestMonths) do
            local monthLabel = PrecisionFarmingReader.getMonthName(monthIndex)
            parts[#parts + 1] = monthLabel
        end

        return table.concat(parts, "-")
    end

    if fruitDesc.harvestMonthIndices ~= nil and type(fruitDesc.harvestMonthIndices) == "table" then
        return FieldAdvisor.text("ftdl_val_month_count", "%d Mon.", #fruitDesc.harvestMonthIndices)
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
    if SeasonalCropStressReader.isModLoaded() then
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

---@param field table
---@param fieldState table|nil
---@param pfSample table|nil
---@param scsSample table|nil
---@param rules table|nil
---@return table[] actions
function FieldAdvisor.resolveActionCandidates(field, fieldState, pfSample, scsSample, rules)
    rules = rules or FieldGameRules.get()
    local actions = {}

    local fruitTypeIndex = FieldAdvisor.getFruitTypeIndex(fieldState)
    local isGrass = FieldAdvisor.isGrassCrop(fruitTypeIndex)
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
        if rules.weedsEnabled and weedState >= 3 then
            FieldAdvisor_addAction(actions, {
                actionType = "weed_combat",
                label = FieldAdvisor.text("ftdl_action_weed_combat_long", "Unkraut bekämpfen"),
                autoComplete = true,
            })
        elseif rules.weedsEnabled and weedState > 0 then
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

        if scsSample ~= nil and scsSample.moisture ~= nil and scsSample.moisture < 0.25 then
            FieldAdvisor_addAction(actions, {
                actionType = "scs_moisture",
                label = FieldAdvisor.text("ftdl_action_irrigate_dry", "Bewässern (trocken)"),
                autoComplete = true,
            })
        end

        if scsSample ~= nil and scsSample.stress ~= nil and scsSample.stress >= 0.6 then
            FieldAdvisor_addAction(actions, {
                actionType = "scs_stress_high",
                label = FieldAdvisor.text("ftdl_action_stress_high", "Pflanzenstress hoch"),
                autoComplete = true,
            })
        elseif scsSample ~= nil and scsSample.stress ~= nil and scsSample.stress >= 0.35 then
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

---@param actions table[]
---@return string
function FieldAdvisor.formatSuggestionList(actions)
    return FieldAdvisor.formatSuggestionColumn(actions, nil)
end

---@param actionType string
---@param context table
---@param actionMeta table|nil
---@return boolean
function FieldAdvisor.isActionComplete(actionType, context, actionMeta)
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

        return not context.needsPlowing and context.plowLevel <= 0
    end

    if actionType == "cultivate" then
        if FieldAdvisor.isWithered(fieldState) then
            return false
        end

        if FieldAdvisor.hasActiveCrop(fieldState) then
            return false
        end

        local groundType = string.lower(tostring(fieldState ~= nil and fieldState.groundType or ""))
        if string.find(groundType, "cultivat", 1, true) ~= nil
            or string.find(groundType, "seedbed", 1, true) ~= nil
            or string.find(groundType, "plow", 1, true) ~= nil then
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

    if actionType == "weed_combat" then
        if not rules.weedsEnabled then
            return true
        end

        return context.weedState < 3
    end

    if actionType == "weed_watch" then
        if not rules.weedsEnabled then
            return true
        end

        return context.weedState <= 0
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

        return not context.needsRolling and context.rollerLevel <= 0
    end

    if actionType == "pf_ph" then
        return pfSample == nil or pfSample.pHValue == nil or pfSample.pHValue >= 6.0
    end

    if actionType == "pf_n" then
        if pfSample == nil or pfSample.nitrogenValue == nil then
            return true
        end

        local nitrogen = tonumber(pfSample.nitrogenValue) or 0
        if actionMeta ~= nil and actionMeta.fertPass ~= nil then
            local passTotal = tonumber(actionMeta.fertPassTotal) or 1
            local target = FieldAdvisor.getOrganicFertilizerPassTarget(actionMeta.fertPass, passTotal, 80)
            return nitrogen >= target
        end

        return nitrogen >= 80
    end

    if actionType == "scs_moisture" then
        return scsSample == nil or scsSample.moisture == nil or scsSample.moisture >= 0.25
    end

    if actionType == "scs_stress_high" then
        return scsSample == nil or scsSample.stress == nil or scsSample.stress < 0.6
    end

    if actionType == "scs_stress_watch" then
        return scsSample == nil or scsSample.stress == nil or scsSample.stress < 0.35
    end

    if actionType == "withered" then
        return not FieldAdvisor.isWithered(fieldState)
    end

    if actionType == "sow" then
        return FieldAdvisor.hasActiveCrop(fieldState) and not FieldAdvisor.isWithered(fieldState)
    end

    return false
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

---@param field table
---@param centerX number
---@param centerZ number
---@return table[]
function FieldAdvisor.collectFieldSamplePoints(field, centerX, centerZ)
    local points = {}
    points[#points + 1] = { x = centerX, z = centerZ }

    local areaHa = tonumber(field ~= nil and field.areaHa) or 0
    if areaHa <= 0 then
        return points
    end

    local areaM2 = areaHa * 10000
    local halfExtent = math.max(8, math.sqrt(areaM2) * 0.45)
    local steps = math.max(1, FieldAdvisor.JOB_SAMPLE_GRID_STEPS)

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
function FieldAdvisor.getActionCompletionRatio(field, task, centerX, centerZ)
    if field == nil or task == nil or field.fieldState == nil or field.fieldState.update == nil then
        return nil
    end

    local points = FieldAdvisor.collectFieldSamplePoints(field, centerX, centerZ)
    if points == nil or #points == 0 then
        return nil
    end

    local total = 0
    local completed = 0

    for _, point in ipairs(points) do
        field.fieldState:update(point.x, point.z)
        local sampleState = FieldAdvisor.getFieldState(field)
        local sampleContext = FieldAdvisor.buildFieldContext(field, sampleState, point.x, point.z)

        total = total + 1
        if FieldAdvisor.isActionComplete(task.actionType, sampleContext, task) then
            completed = completed + 1
        end
    end

    field.fieldState:update(centerX, centerZ)

    if total <= 0 then
        return nil
    end

    return completed / total
end

---@param task table
---@param scanner FieldScanner
---@return boolean
function FieldAdvisor.isFieldTaskComplete(task, scanner)
    if task == nil or task.source ~= "field" or task.completed or task.autoComplete ~= true then
        return false
    end

    if task.actionType == nil
        or task.actionType == "none"
        or task.actionType == "harvest_info"
        or task.actionType == "growing"
        or task.actionType == "custom" then
        return false
    end

    local field = scanner:getEngineFieldById(task.fieldId)
    if field == nil then
        return false
    end

    local posX, posZ = field:getCenterOfFieldWorldPosition()
    if posX ~= nil and posZ ~= nil and field.fieldState ~= nil and field.fieldState.update ~= nil then
        field.fieldState:update(posX, posZ)
    end

    local fieldState = FieldAdvisor.getFieldState(field)
    local context = FieldAdvisor.buildFieldContext(field, fieldState, posX, posZ)
    local completionRatio = FieldAdvisor.getActionCompletionRatio(field, task, posX, posZ)
    if completionRatio ~= nil then
        return completionRatio >= FieldAdvisor.JOB_COMPLETION_THRESHOLD
    end

    return FieldAdvisor.isActionComplete(task.actionType, context, task)
end

---@param field table
---@param fieldState table|nil
---@param pfSample table|nil
---@param scsSample table|nil
---@param rules table|nil
---@return string suggestion
function FieldAdvisor.buildSuggestion(field, fieldState, pfSample, scsSample, rules)
    return FieldAdvisor.resolvePrimaryAction(field, fieldState, pfSample, scsSample, rules).label
end

---@param field table
---@param fieldState table|nil
---@param worldX number|nil
---@param worldZ number|nil
---@return table labels
function FieldAdvisor.buildFieldLabels(field, fieldState, worldX, worldZ)
    local rules = FieldGameRules.get()

    local weedState = FieldAdvisor.getStateNumber(fieldState, "weedState")
    local stoneLevel = FieldAdvisor.getStateNumber(fieldState, "stoneLevel")
    local limeLevel = FieldAdvisor.getStateNumber(fieldState, "limeLevel")
    local rollerLevel = FieldAdvisor.getStateNumber(fieldState, "rollerLevel")
    local plowLevel = FieldAdvisor.getStateNumber(fieldState, "plowLevel")

    local needsRolling = FieldAdvisor.getStateBool(fieldState, "needsRolling")
    local needsPlowing = FieldAdvisor.getStateBool(fieldState, "needsPlowing")

    local context = FieldAdvisor.buildFieldContext(field, fieldState, worldX, worldZ)
    local actions = FieldAdvisor.resolveActionCandidates(
        field,
        fieldState,
        context.pfSample,
        context.scsSample,
        context.rules
    )
    local action = FieldAdvisor.resolvePrimaryAction(
        field,
        fieldState,
        context.pfSample,
        context.scsSample,
        context.rules
    )
    local fruitTypeIndex = FieldAdvisor.getFruitTypeIndex(fieldState)

    return {
        weed = FieldAdvisor.formatWeedLabel(weedState, rules),
        stones = FieldAdvisor.formatStoneLabel(stoneLevel, rules),
        lime = FieldAdvisor.formatLimeLabel(limeLevel, rules),
        roller = FieldAdvisor.formatRollerLabel(rollerLevel, needsRolling),
        plow = FieldAdvisor.formatPlowLabel(plowLevel, needsPlowing, rules),
        ph = context.pfSample ~= nil and context.pfSample.phLabel or nil,
        nitrogen = context.pfSample ~= nil and context.pfSample.nitrogenLabel or nil,
        moisture = context.scsSample ~= nil and context.scsSample.moistureLabel or nil,
        stress = context.scsSample ~= nil and context.scsSample.stressLabel or nil,
        fruit = FieldAdvisor.getLocalizedFruitTitle(fruitTypeIndex),
        cropPhase = FieldAdvisor.getCropPhase(field, fieldState),
        expectedHarvest = FieldAdvisor.getExpectedHarvestLabel(field, fieldState),
        suggestion = FieldAdvisor.formatSuggestionColumn(actions, FieldAdvisor.getExpectedHarvestLabel(field, fieldState)),
        suggestionDetails = actions,
        actionType = action.actionType,
        autoComplete = action.autoComplete,
        isGrass = FieldAdvisor.isGrassCrop(fruitTypeIndex),
        showPrecisionFarming = PrecisionFarmingReader.isRuntimeReady(),
        showCropStress = SeasonalCropStressReader.isModLoaded(),
    }
end
