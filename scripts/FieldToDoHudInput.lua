--[[
    FieldToDoHudInput.lua
    Registers Left Ctrl + F5 to toggle the in-world To-Do HUD.
]]

FieldToDoHudInput = {}
FieldToDoHudInput.ACTION_NAME = "FTDTL_TOGGLE_TODO_HUD"

local function ftdlToggleHudCallback(_, _, inputValue)
    if (inputValue or 0) <= 0 then
        return
    end

    if FieldToDoHudOverlay.instance ~= nil then
        FieldToDoHudOverlay.instance:toggle()
    end
end

local function registerHudAction(actionId, callback, labelKey, labelFallback)
    if actionId == nil or g_inputBinding == nil then
        return
    end

    local target = FieldToDoHudOverlay.instance or FieldToDoHudOverlay
    local ok, eventId = g_inputBinding:registerActionEvent(
        actionId,
        target,
        callback,
        false,
        true,
        false,
        false,
        nil,
        true
    )

    if ok and eventId ~= nil then
        g_inputBinding:setActionEventActive(eventId, true)
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_NORMAL)
        local label = FieldToDoL10n.getText(labelKey, labelFallback)
        g_inputBinding:setActionEventText(eventId, label)
        FieldToDoHudInput.lastEventId = eventId
    end
end

---@return string|nil
function FieldToDoHudInput.getBindingDisplayText()
    if g_inputDisplayManager == nil or InputAction == nil or InputAction.FTDTL_TOGGLE_TODO_HUD == nil then
        return nil
    end

    local ok, helpElement = pcall(
        g_inputDisplayManager.getControllerSymbolOverlays,
        g_inputDisplayManager,
        InputAction.FTDTL_TOGGLE_TODO_HUD,
        "",
        "",
        false
    )

    if not ok or helpElement == nil or helpElement.buttons == nil then
        return nil
    end

    local parts = {}
    for _, button in ipairs(helpElement.buttons) do
        if button.text ~= nil and button.text ~= "" then
            parts[#parts + 1] = button.text
        end
    end

    if #parts == 0 then
        return nil
    end

    return table.concat(parts, " + ")
end

function FieldToDoHudInput.install()
    if PlayerInputComponent ~= nil and PlayerInputComponent.registerActionEvents ~= nil then
        PlayerInputComponent.registerActionEvents = Utils.appendedFunction(
            PlayerInputComponent.registerActionEvents,
            function(inputComponent)
                if inputComponent.player == nil or not inputComponent.player.isOwner then
                    return
                end

                if g_inputBinding == nil or InputAction == nil or InputAction.FTDTL_TOGGLE_TODO_HUD == nil then
                    return
                end

                g_inputBinding:beginActionEventsModification(PlayerInputComponent.INPUT_CONTEXT_NAME)
                registerHudAction(
                    InputAction.FTDTL_TOGGLE_TODO_HUD,
                    ftdlToggleHudCallback,
                    "input_FTDTL_TOGGLE_TODO_HUD",
                    "To-Do HUD ein/aus"
                )
                g_inputBinding:endActionEventsModification()
            end
        )
    end

    if Vehicle ~= nil and Vehicle.registerActionEvents ~= nil then
        Vehicle.registerActionEvents = Utils.appendedFunction(
            Vehicle.registerActionEvents,
            function(vehicle, isActiveForInput)
                if not isActiveForInput or g_inputBinding == nil or InputAction == nil then
                    return
                end

                if InputAction.FTDTL_TOGGLE_TODO_HUD == nil then
                    return
                end

                registerHudAction(
                    InputAction.FTDTL_TOGGLE_TODO_HUD,
                    ftdlToggleHudCallback,
                    "input_FTDTL_TOGGLE_TODO_HUD",
                    "To-Do HUD ein/aus"
                )
            end
        )
    end
end

FieldToDoHudInput.install()
