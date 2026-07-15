local ButtonDialog = require("ui/widget/buttondialog")
local InputDialog  = require("ui/widget/inputdialog")

local UIManager    = require("ui/uimanager")

local IconsLibrary  = require("iconchooser/icons_library")
local ActionExec    = require("action_exec")
local ActionChooser = require("actionchooser/action_chooser")
local Utils         = require("common/utils")
local Config        = require("config")
local _             = require("common/i18n").gettext

local ActionCustom = {}

local WIDTHFACTOR = 0.8

-- ============================================================
-- Menu
-- ============================================================
function ActionCustom:showActionCustomMenu(ctx)
    local dialog
    local buttons = {}

    -- existing action
    local config = ctx.config
    if config.custom_actions and #config.custom_actions > 0 then
        for i, action in ipairs(config.custom_actions) do
            buttons[#buttons + 1] = {
                {
                text = (Utils.get_safe_icon(action.icon) or _("None")) .. " " ..(action.label or _("None")), -- btn doesnt't support svg
                -- update action
                callback = function()
                    UIManager:close(dialog)
                    self:updateActionCustomDialog(ctx, action, i)
                end,
                -- apply action
                hold_callback = function()
                    UIManager:close(dialog)
                    self:applyActionCustomDialog(ctx, action)
                end,
                }
            }
        end
    else
        buttons[#buttons + 1] = {
            {
                text = _("No custom action") .. "\xE2\x80\xA6",
                enabled = false -- Rend le bouton non cliquable
            }
        }
    end

    table.insert(buttons, {}) -- separator

    -- new action
    buttons[#buttons + 1] = {
        {
        text = _("Add"),
        -- add action
        callback = function()
            UIManager:close(dialog)
            self:addActionCustomDialog(ctx)
        end
        },
        {
        text = _("Exit"),
        callback = function()
            UIManager:close(dialog)
        end
        },
    }

    dialog = ButtonDialog:new{
        -- dismissable = false,
        title = "\u{E8B6}" .. " " ..  _("Custom actions") .. " :",
        title_align  = "left",
        width_factor = WIDTHFACTOR,
        buttons = buttons,
    }
    UIManager:show(dialog)
end

-- ============================================================
-- Apply
-- ============================================================
function ActionCustom:applyActionCustom(ctx, callback)
    -- need to close touch_menu first -> see action_exec.lua
    local touch_menu = ctx.touch_menu
    if touch_menu and touch_menu.updateItems then touch_menu:closeMenu() end
    -- apply
    UIManager:nextTick(function() ActionExec.dispatch(callback) end)
end

function ActionCustom:applyActionCustomDialog(ctx, action)
    local dialog
    local is_callback = not not (action.callback and action.callback.label and action.callback.label ~= "") --force boolean
    local is_hold_callback = not not (action.hold_callback and action.hold_callback.label and action.hold_callback.label~="") -- force boolean

    local buttons = {
        {{
            text = _("Label") .. " : " .. (action.label or _("None")),
            callback = function()
            end
        }},
        {{
            text = _("Icon") .. " : " .. (Utils.get_safe_icon(action.icon) or _("None")), -- btn doesnt't support svg
            callback = function()
            end
        }},
        {{
            text = _("Tap") .. " : " .. (action.callback.label or _("None")),
            callback = function()
                if is_callback then
                    UIManager:close(dialog)
                    self:applyActionCustom(ctx, action.callback)
                end
            end
        }},
        {{
            text = _("Hold") .. " : " .. (action.hold_callback.label or _("None")),
            callback = function()
                if is_hold_callback then
                    UIManager:close(dialog)
                    self:applyActionCustom(ctx, action.hold_callback)
                end
            end
        }},
        {
           -- separator
        },
        {{
            text = _("Exit"),
            callback = function()
                UIManager:close(dialog)
                self:showActionCustomMenu(ctx)
            end
        }}
    }

    dialog = ButtonDialog:new{
        -- dismissable = false,
        title = "\u{ED67}" .. " " .. _("Apply") .. " :",
        title_align  = "left",
        width_factor = WIDTHFACTOR,
        buttons = buttons,
        tap_close_callback = function()
            self:showActionCustomMenu(ctx)
        end
    }
    UIManager:show(dialog)
end

-- ============================================================
-- Add
-- ============================================================
function ActionCustom:addActionCustom(ctx, fields)
    local action = {
        id         = os.time() .. math.random(100, 999),
        category   = "custom",
        label      = fields.label or "",
        icon       = fields.icon or "",
        callback   = {
            label       = fields.label,
            icon        = fields.icon,
            plugin      = fields.plugin,
            action      = fields.action,
            menu_path   = fields.menu_path,
            menu_toggle = fields.menu_toggle,
            menu_page   = fields.menu_page
        },
        hold_callback = {}
    }

    for k, v in pairs(action.callback) do
        if (type(v) ~= "table" and (v == nil or v == "")) then
            action.callback[k] = nil
        end
    end

    local config = ctx.config
    config.custom_actions = config.custom_actions or {}
    table.insert(config.custom_actions, action)
    Config.saveAndRefresh(ctx)
end

function ActionCustom:addActionCustomDialog(ctx)
    local dialog
--     local function close(fn)
--         return function()
--             UIManager:close(dialog)
--             if fn then fn() end
--         end
--     end

    local no_close = function(fn) return fn end

    local buttons = ActionChooser.actionRows(no_close, function(fields)
        UIManager:close(dialog)
        self:addActionCustom(ctx, fields)
        self:showActionCustomMenu(ctx)
    end)

    table.insert(buttons, {}) -- separator

    buttons[#buttons + 1] = {
        {
        text = _("Exit"),
        callback = function()
            UIManager:close(dialog)
            self:showActionCustomMenu(ctx)
        end
        },
    }
    dialog = ButtonDialog:new{
        title        = "\u{E8B6}" .. " " .. _("Add new action") .. " :",
        title_align  = "left",
        width_factor = WIDTHFACTOR,
        buttons      = buttons,
        tap_close_callback = function()
            self:showActionCustomMenu(ctx)
        end
    }
    UIManager:show(dialog)
end

-- ============================================================
-- callback
-- ============================================================
function ActionCustom:callbackActionCustom(action, fields, is_hold_callback)
    local target_key = is_hold_callback and "hold_callback" or "callback"
    action[target_key] = {
        label       = fields.label,
        icon        = fields.icon,
        plugin      = fields.plugin,
        action      = fields.action,
        menu_path   = fields.menu_path,
        menu_toggle = fields.menu_toggle,
        menu_page   = fields.menu_page
    }
    for k, v in pairs(action[target_key]) do
        if (type(v) ~= "table" and (v == nil or v == "")) then
            action[target_key][k] = nil
        end
    end
end

function ActionCustom:callbackActionCustomDialog(ctx, action, index, is_hold_callback)
    local dialog

--     local function close(fn)
--         return function()
--             UIManager:close(dialog)
--             if fn then fn() end
--         end
--     end

    local no_close = function(fn) return fn end

    local buttons = ActionChooser.actionRows(no_close, function(fields)
        UIManager:close(dialog)
        self:callbackActionCustom(action, fields, is_hold_callback)
        self:updateActionCustomDialog(ctx, action, index)
    end)

    table.insert(buttons, {}) -- separator

    buttons[#buttons + 1] = {
        {
            text = _("Delete"),
            callback = function()
                UIManager:close(dialog)
                local target_key = is_hold_callback and "hold_callback" or "callback"
                action[target_key] = {}
                self:updateActionCustomDialog(ctx, action, index)
            end
        },
        {
            text = _("Exit"),
            callback = function()
                UIManager:close(dialog)
                self:updateActionCustomDialog(ctx, action, index)
            end
        }
    }

    dialog = ButtonDialog:new{
        title        = "\u{E8B6}" .. " " .. ((is_hold_callback and _("Select hold")) or _("Select tap")) .. " :",
        title_align  = "left",
        width_factor = WIDTHFACTOR,
        buttons      = buttons,
        tap_close_callback = function()
            self:updateActionCustomDialog(ctx, action, index)
        end
    }
    UIManager:show(dialog)
end

-- ============================================================
-- Update
-- ============================================================
function ActionCustom:updateActionCustom(ctx, action, index)
    local config = ctx.config
    if config and config.custom_actions and config.custom_actions[index] then
        config.custom_actions[index] = action
        Config.saveAndRefresh(ctx)
    end
end

function ActionCustom:deleteActionCustom(ctx, action)
    local config = ctx.config
    if not config or not config.custom_actions then return end
    local id_to_remove = action.id
    -- delete in config.custom_actions
    for i, act in ipairs(config.custom_actions) do
        if act.id == id_to_remove then
            table.remove(config.custom_actions, i)
            break
        end
    end
    -- delete in all config.sections.items
    if config.sections then
        for _k, section_data in pairs(config.sections) do
            if section_data.items and type(section_data.items) == "table" then
                for i = #section_data.items, 1, -1 do
                    if section_data.items[i] == id_to_remove then
                        table.remove(section_data.items, i)
                    end
                end
            end
        end
    end

    Config.saveAndRefresh(ctx)
end

local function tableCopy(orig)
    local orig_type = type(orig)
    local copy

    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[tableCopy(orig_key)] = tableCopy(orig_value)
        end
        setmetatable(copy, tableCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function ActionCustom:updateActionCustomDialog(ctx, action, index)
    local dialog
    local temp_action = tableCopy(action)
    local buttons = {
        {{
            text = _("Label") .. " : " .. (temp_action.label or _("None")),
            callback = function()
                UIManager:close(dialog)
                local label_dialog
                label_dialog = InputDialog:new{
                    title = _("Select label") .. " :",
                    input = temp_action.label,
                    buttons = {
                        {
                            {
                                text = _("Save"),
                                is_enter_default = true,
                                callback = function()
                                    temp_action.label = label_dialog:getInputText()
                                    UIManager:close(label_dialog)
                                    self:updateActionCustomDialog(ctx, temp_action, index)
                                end
                            },
                            {
                                text = _("Exit"),
                                callback = function()
                                    UIManager:close(label_dialog)
                                    self:updateActionCustomDialog(ctx, temp_action, index)
                                end

                            }
                        }
                    }
                }
                UIManager:show(label_dialog)
            end
        }},
        {{
            text = _("Icon") .. " : " .. (Utils.get_safe_icon(temp_action.icon) or _("None")), -- btn doesnt't support svg
            callback = function()
                IconsLibrary:show(function(glyph)
                    if glyph and glyph ~= "" then
                        temp_action.icon = glyph
                        UIManager:close(dialog)
                        self:updateActionCustomDialog(ctx, temp_action, index)
                    end
                end, { dynamic = false, svg = true})
                --UIManager:close(dialog)
            end
        }},
        {{
            text = _("Tap") .. " : " .. ((temp_action.callback and temp_action.callback.label) or _("None")),
            callback = function()
                UIManager:close(dialog)
                self:callbackActionCustomDialog(ctx, temp_action, index, false)
            end
        }},
        {{
            text = _("Hold") .. " : " .. ((temp_action.hold_callback and temp_action.hold_callback.label) or _("None")),
            callback = function()
                UIManager:close(dialog)
                self:callbackActionCustomDialog(ctx, temp_action, index, true)
            end
        }},
        {
          --separator
        },
        {
            {
                text = _("Save"),
                callback = function()
                    self:updateActionCustom(ctx, temp_action, index)
                    UIManager:close(dialog)
                    self:showActionCustomMenu(ctx)
                end
            },
            {
                text = _("Delete"),
                callback = function()
                    self:deleteActionCustom(ctx, action)
                    UIManager:close(dialog)
                    self:showActionCustomMenu(ctx)
                end,
            },
            {
                text = _("Exit"),
                callback = function()
                    UIManager:close(dialog)
                    self:showActionCustomMenu(ctx)
                end
            }
        }
    }

    dialog = ButtonDialog:new{
        title = "\u{F044}" .. " " .. _("Edit") .. " :",
        title_align = "left",
        width_factor = WIDTHFACTOR,
        buttons = buttons,
        tap_close_callback = function()
            self:showActionCustomMenu(ctx)
        end
    }
    UIManager:show(dialog)
end

return ActionCustom

