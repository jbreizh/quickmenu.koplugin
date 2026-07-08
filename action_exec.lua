--[[
Executes one "action" entry (the shape the start menu and the hero Action
module share): { internal = "close"|"settings" } | { plugin = {key,method} } |
{ action = <dispatcher table> }. The CALLER closes its own menu/widget first and
wraps this in UIManager:nextTick; dispatch only runs the action. Extracted from
bookshelf_start_menu.lua so the start menu and the Action micro-module share one
execution path.
]]
local _ = require("common/i18n").gettext

local Exec = {}

-- entry: the action entry.
function Exec.dispatch(entry)
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

return Exec
