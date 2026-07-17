-- style_manage.lua
local UIManager = require("ui/uimanager")
local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")

local Utils      = require("common/utils")
local Config  = require("config")
local _ = require("common/i18n").gettext

local StyleManage = {}

function StyleManage:buildStyleSubMenu(plugin, on_close, on_refresh)
    --
    local config = plugin.config
    local menu_instance = plugin.menu_instance
    local is_filemanager = plugin.is_filemanager
    -- style
    local style_keys = {}
    for key in pairs(Config.DEFAULTS.style) do
        table.insert(style_keys, key)
    end
    table.sort(style_keys)
    --
    local style_items = {}
    for i, key in ipairs(style_keys) do
        table.insert(style_items, {
            text_func = function() return key .. " (" .. tostring(config.style[key]) .. ")"  end,
            keep_menu_open = true,
            callback = on_close(function()
                local original = config.style[key]
                local function getValue() return config.style[key] end
                local function setValue(v) config.style[key] = math.max(0, math.min(150, v)); Config.saveAndRefresh(plugin) end
                local function rebuild()
                    UIManager:setDirty("all", "ui") -- WARNING touch_menu only repaint touch_menu... dialog outside touch_menu need repaint
                end

                local dialog
                local function nudge(delta)
                    local newVal = getValue() + delta
                    newVal = math.floor(newVal * 10 + 0.5) / 10
                    setValue(newVal)
                    dialog:reinit()
                    rebuild()
                end

                local function close() UIManager:close(dialog); if on_refresh then on_refresh() end end
                local function revert() setValue(original); rebuild() end

                dialog = ButtonDialog:new{
                    dismissable = false,
                    title = key,
                    buttons = {
                        {
                            { text = "-10",  callback = function() nudge(-10) end },
                            { text = "-1",   callback = function() nudge(-1)  end },
                            { text = "-0.1", callback = function() nudge(-0.1) end },
                            { text_func = function() return tostring(getValue()) end, enabled = false },
                            { text = "+0.1", callback = function() nudge(0.1)   end },
                            { text = "+1",   callback = function() nudge(1)   end },
                            { text = "+10",  callback = function() nudge(10)  end },
                        },
                        {
                            { text = _("Cancel"), callback = function() revert(); close() end },
                            { text = _("Default"),callback = function() setValue(Config.DEFAULTS.style[key]); rebuild(); dialog:reinit() end },
                            { text = _("Apply"), is_enter_default = true, callback = close },
                        },
                    },
                    tap_close_callback = revert
                }
                UIManager:show(dialog)
            end),
            separator = (i == #style_keys),
        })
    end

    -- reset
    table.insert(style_items, {
        text = _("Reset style to defaults"),
        keep_menu_open = true,
        callback = on_close(function(touch_menu)
            UIManager:show(ConfirmBox:new{
                text = _("Reset style to defaults") .. " ?",
                ok_text = _("Reset"),
                ok_callback = function()
                    config.style = {}
                    for key, value in pairs(Config.DEFAULTS.style) do
                        config.style[key] = value
                    end
                    Config.saveAndRefresh(plugin)
                    if on_refresh then on_refresh() end
                end,
                cancel_callback = function()
                    if on_refresh then on_refresh() end
                end,
            })
        end),
    })

    return style_items
end


function StyleManage:showStyleDialog(plugin, refresh)
    local dialog

    local function on_close(fn)
        return function()
            if dialog then UIManager:close(dialog) end
            if fn then fn() end
        end
    end

    local function on_refresh()
        self:showStyleDialog(plugin, refresh)
    end

    local style_items = self:buildStyleSubMenu(plugin, on_close, on_refresh)
    local buttons = Utils.wrap_items(style_items)

    -- Bouton de fermeture
    table.insert(buttons, {})
    table.insert(buttons, {{
        text = _("Close"),
        callback = function()
            UIManager:close(dialog)
            if refresh then refresh() end
        end
    }})

    dialog = ButtonDialog:new{
        title = "\u{EAD7}" .. " " .. _("Style") .. " :",
        buttons = buttons,
        tap_close_callback = function()
            if refresh then refresh() end
        end,
    }

    UIManager:show(dialog)
end

return StyleManage
