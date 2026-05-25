--[[
    FieldToDoL10n.lua
    Shared g_i18n helper for mod UI strings (translations/translation_*.xml).
]]

FieldToDoL10n = {}

---@param key string|nil
---@param fallback string|nil
---@return string
function FieldToDoL10n.getText(key, fallback, ...)
    if key == nil or key == "" then
        if select("#", ...) > 0 and fallback ~= nil then
            return string.format(fallback, ...)
        end
        return fallback or ""
    end

    local template = fallback or key

    if g_i18n ~= nil and g_i18n.getText ~= nil then
        local hasKey = g_i18n.hasText == nil or g_i18n:hasText(key)
        if hasKey then
            template = g_i18n:getText(key)
        end
    end

    if select("#", ...) > 0 then
        return string.format(template, ...)
    end

    return template
end
