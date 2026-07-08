-- Original idea : peterboda236 https://github.com/peterboda236/koreader-user-patches/blob/main/2-frontlight-widget-profiles.lua
local ButtonDialog = require("ui/widget/buttondialog")
local InputDialog  = require("ui/widget/inputdialog")
local Notification = require("ui/widget/notification")

local UIManager    = require("ui/uimanager")
local Event        = require("ui/event")
local Device       = require("device")
local power        = Device:getPowerDevice()

local Config       = require("config")
local _            = require("common/i18n").gettext


local FrontlightPreset = {}

-- Selection/gestion menu of frontlight_presets
function FrontlightPreset:showFrontlightPresetMenu(config)
    local dialog
    local buttons = {}

    -- Add existing preset
    if config.frontlight_presets then
        for i, preset in ipairs(config.frontlight_presets) do
            buttons[#buttons + 1] = {{
                text = preset.name,
                -- apply preset
                callback = function()
                    self:applyFrontLightPreset(preset)
                    --UIManager:close(dialog)
                    UIManager:show(Notification:new{text = _("Apply preset '%s'"):format(preset.name)})
                end,
                -- update preset
                hold_callback = function()
                    UIManager:close(dialog)
                    self:updateFrontLightPresetDialog(config, preset.name, i)
                end
            }}
        end
    end

    -- create new preset
    buttons[#buttons + 1] = {
        {
        text = _("Add"),
        callback = function()
            UIManager:close(dialog)
            self:addFrontLightPresetDialog(config)
        end
        },
        {
        text = _("Close"),
        callback = function()
            UIManager:close(dialog)
            --self:addFrontLightPresetDialog(config)
        end
        },
    }

    dialog = ButtonDialog:new{
        -- dismissable = false,
        title = _("Frontlight preset") .. " :",
        --width_factor = 0.5,
        buttons = buttons,
    }
    UIManager:show(dialog)
end

function FrontlightPreset:applyFrontLightPreset(preset)
    if preset.intensity and Device:hasFrontlight() then power:setIntensity(preset.intensity) end
    if preset.warmth and Device:hasNaturalLight() then power:setWarmth(preset.warmth) end
    if preset.night_mode ~= G_reader_settings:isTrue("night_mode") then UIManager:broadcastEvent(Event:new("ToggleNightMode")) end

end

function FrontlightPreset:deleteFrontLightPreset(config, index)
    table.remove(config.frontlight_presets, index)
    Config.save(config)
end

function FrontlightPreset:addFrontLightPreset(config, name)
    local preset = {}
    preset.name = name
    preset.night_mode = G_reader_settings:isTrue("night_mode")
    if Device:hasFrontlight() then preset.intensity = power:frontlightIntensity() end
    if Device:hasNaturalLight() then preset.warmth = power:frontlightWarmth() end
    config.frontlight_presets = config.frontlight_presets or {}
    table.insert(config.frontlight_presets, preset)
    Config.save(config)
end

function FrontlightPreset:updateFrontLightPreset(config, name, index)
    if config and config.frontlight_presets and config.frontlight_presets[index] then
        local preset = config.frontlight_presets[index]
        preset.name = name
        preset.night_mode = G_reader_settings:isTrue("night_mode")
        if Device:hasFrontlight() then preset.intensity = power:frontlightIntensity() end
        if Device:hasNaturalLight() then preset.warmth = power:frontlightWarmth() end
        Config.save(config)
    end
end

function FrontlightPreset:renameFrontLightPreset(config, name, index)
    if config and config.frontlight_presets and config.frontlight_presets[index] then
        local preset = config.frontlight_presets[index]
        preset.name = name
        Config.save(config)
    end
end

function FrontlightPreset:addFrontLightPresetDialog(config)
    local status = {}
    status[#status + 1] = _("Night mode : %s"):format(G_reader_settings:isTrue("night_mode") and _("Yes") or _("No"))
    if Device:hasFrontlight() then status[#status + 1] = _("Intensity : %d%%"):format(power:frontlightIntensity()) end
    if Device:hasNaturalLight() then status[#status + 1] = _("Warmth : %d%%"):format(power:frontlightWarmth()) end
    status[#status + 1] = _("Name :")

    local add_dialog
    add_dialog = InputDialog:new{
        title = _("Add new preset"),
        description = table.concat(status, "\r"),
        input = _("New"),
        buttons = {
            {
                {
                    text = _("Save"),
                    is_enter_default = true,
                    callback = function()
                        self:addFrontLightPreset(config, add_dialog:getInputText())
                        UIManager:show(Notification:new{text = _("Save preset '%s'"):format(add_dialog:getInputText())})
                        UIManager:close(add_dialog)
                        self:showFrontlightPresetMenu(config)
                    end,
                },
                {
                    text = _("Close"),
                    id = "close",
                    callback = function()
                        UIManager:close(add_dialog)
                        self:showFrontlightPresetMenu(config)
                    end,
                },
            },
        },
    }
    UIManager:show(add_dialog)
end

function FrontlightPreset:updateFrontLightPresetDialog(config, name, index)
    local preset = (config and config.frontlight_presets) and config.frontlight_presets[index] or {}
    local status = {}
    local old_nm = preset.night_mode and _("Yes") or _("No")
    local new_nm = G_reader_settings:isTrue("night_mode") and _("Yes") or _("No")
    status[#status + 1] = _("Night mode : %s -> %s"):format(old_nm, new_nm)
    if Device:hasFrontlight() then
        local old_i = preset.intensity or 0
        local new_i = power:frontlightIntensity()
        status[#status + 1] = _("Intensity : %d%% -> %d%%"):format(old_i, new_i)
    end
    if Device:hasNaturalLight() then
        local old_w = preset.warmth or 0
        local new_w = power:frontlightWarmth()
        status[#status + 1] = _("Warmth : %d%% -> %d%%"):format(old_w, new_w)
    end
    local old_n = preset.name or ""
    status[#status + 1] = _("Name :")

    local add_dialog
    add_dialog = InputDialog:new{
        title = _("Update preset '%s'"):format(name),
        description = table.concat(status, "\r"),
        input = name,
        buttons = {
            {
                {
                    text = _("Save"),
                    is_enter_default = true,
                    callback = function()
                        self:updateFrontLightPreset(config, add_dialog:getInputText(), index)
                        UIManager:show(Notification:new{text = _("Save preset '%s'"):format(name)})
                        UIManager:close(add_dialog)
                        self:showFrontlightPresetMenu(config)
                    end,
                },
                {
                    text = _("Rename"),
                    callback = function()
                        self:renameFrontLightPreset(config, add_dialog:getInputText(), index)
                        UIManager:show(Notification:new{text = _("Rename preset '%s' to '%s'"):format(name, add_dialog:getInputText())})
                        UIManager:close(add_dialog)
                        self:showFrontlightPresetMenu(config)
                    end,
                },
                {
                    text = _("Delete"),
                    callback = function()
                        self:deleteFrontLightPreset(config,index)
                        UIManager:show(Notification:new{text = _("Delete preset '%s'"):format(name)})
                        UIManager:close(add_dialog)
                        self:showFrontlightPresetMenu(config)
                    end,
                },
                {
                    text = _("Close"),
                    id = "close",
                    callback = function()
                        UIManager:close(add_dialog)
                        self:showFrontlightPresetMenu(config)
                    end,
                },
            },
        },
    }
    UIManager:show(add_dialog)
end

return FrontlightPreset

