local UIManager       = require("ui/uimanager")

local Utils           = require("common/utils")
local _ = require("common/i18n").gettext

local ActionExec = {}

function ActionExec.exec_action(ctx, entry)
    if type(entry) == "function" then -- native
        entry(ctx)
    elseif type(entry) == "table" then -- custom
        -- need to close touch_menu first
        Utils.closeMenu(ctx.touch_menu)
        -- need to wrap in UIManager:nextTick
        UIManager:nextTick(function() ActionExec.dispatch(entry) end)
    end
end

function ActionExec.dispatch(entry)
    if type(entry) ~= "table" then return end
    local logger    = require("logger")

    if type(entry.plugin) == "table" then
        local PluginScan = require("actionchooser/plugin_scan")
        local launch = PluginScan.resolve(entry.plugin.key, entry.plugin.method)
        if launch then
            local ok_l, err = pcall(launch)
            if not ok_l then
                logger.warn("[quickmenu] action plugin launch failed:", entry.plugin.key, err)
            end
        end
    elseif type(entry.menu_path) == "table" then
        local MenuShortcut = require("actionchooser/menu_shortcut")
        if entry.menu_page then
            MenuShortcut.replayPage(entry.menu_path, entry.label)
        else
            MenuShortcut.replay(entry.menu_path)
        end
    elseif type(entry.action) == "table" then
        local ok, Dispatcher = pcall(require, "dispatcher")
        if ok then Dispatcher:execute(entry.action) end
    end
end

return ActionExec
