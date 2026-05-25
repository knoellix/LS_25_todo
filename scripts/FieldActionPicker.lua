--[[
    FieldActionPicker.lua
    Shows field action choices via OptionDialog (FS25: title and options order).
]]

FieldActionPicker = {}

---@param action table|nil
---@return string
function FieldActionPicker.getOptionText(action)
    if action == nil then
        return "-"
    end

    if action.pickerLabel ~= nil and action.pickerLabel ~= "" then
        return action.pickerLabel
    end

    if FieldAdvisor ~= nil and FieldAdvisor.getShortActionLabel ~= nil then
        return FieldAdvisor.getShortActionLabel(action)
    end

    return action.label or "-"
end

---@param actions table[]
---@return string[]
function FieldActionPicker.buildOptionTexts(actions)
    local texts = {}

    for _, action in ipairs(actions) do
        texts[#texts + 1] = FieldActionPicker.getOptionText(action)
    end

    return texts
end

--- FS25 OptionDialog.show(callback, target, title, texts, defaultIndex)
---@param target table
---@param callback function
---@param title string
---@param actions table[]
---@param defaultIndex number|nil
---@return boolean
function FieldActionPicker.show(target, callback, title, actions, defaultIndex)
    if actions == nil or #actions == 0 then
        return false
    end

    if OptionDialog == nil or OptionDialog.show == nil then
        return false
    end

    local texts = FieldActionPicker.buildOptionTexts(actions)

    -- OptionDialog callback binding is inconsistent across game versions/mod setups.
    -- Bind target explicitly to avoid "self" becoming a numeric selected index.
    local boundCallback = callback
    if target ~= nil and callback ~= nil then
        boundCallback = function(...)
            return callback(target, ...)
        end
    end

    OptionDialog.show(boundCallback, nil, title, texts, defaultIndex or 1)

    return true
end
