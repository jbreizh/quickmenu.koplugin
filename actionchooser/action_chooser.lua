--[[
Builds the "pick an action" button rows shared by the start menu's Add-to-menu
dialog and the hero Action module's add flow. `close(fn)` is the host's dialog
closer (returns a wrapped callback that closes the host dialog first). `on_pick`
receives the chosen action's FIELDS — { label, icon?, action|plugin|internal } —
without id/type, which the caller stamps on. Plugin glyph default matches the
start menu (issue #140).
]]
local ButtonDialog = require("ui/widget/buttondialog")
local Notification = require("ui/widget/notification")
local UIManager    = require("ui/uimanager")
local _            = require("locale/i18n").gettext

local PLUGIN_DEFAULT_TEXT = "\xEE\xAC\xB0" -- U+EB30 mdi-puzzle (start-menu default)
local PLUGIN_DEFAULT_ICON = "qm_default"
local MENU_DEFAULT_TEXT   = "\xEE\xB5\x84" -- U+ED44 (default for menu shortcuts)
local MENU_DEFAULT_ICON = "qm_default"
local ACTION_DEFAULT_TEXT   = "\xEE\xAD\xA2" -- U+EB62 (default for menu shortcuts)
local ACTION_DEFAULT_ICON = "qm_default"

local Chooser = {}

function Chooser.actionRows(close, on_pick)
    return {
        { { text = _("Plugin") .."\xE2\x80\xA6", callback = close(function()
            local PluginScan = require("actionchooser/plugin_scan")
            local found = PluginScan.scan()
            if #found == 0 then
                UIManager:show(Notification:new{
                    text = _("No launchable plugins found") })
                return
            end
            local MenuHost = require("actionchooser/menu_host")
            local host
            local picker_items = {}
            for _i, p in ipairs(found) do
                local entry_text = p.icon or PLUGIN_DEFAULT_TEXT
                picker_items[#picker_items + 1] = {
                    text = (p.icon and (p.icon .. "  ") or "") .. p.title,
                    callback = function()
                        MenuHost.close(host)
                        on_pick{ label = p.title, text = entry_text, icon = PLUGIN_DEFAULT_ICON, plugin = { key = p.key, method = p.method } }
                    end,
                }
            end
            host = MenuHost.show{ title = _("Choose a plugin"),
                item_table = picker_items }
        end) } },
        { { text = _("System action") .. "\xE2\x80\xA6", callback = close(function()
            local ActionPicker = require("actionchooser/action_picker")
            ActionPicker.show{
                on_pick = function(action, name)
                    on_pick{ label = name, text = ACTION_DEFAULT_TEXT, icon = ACTION_DEFAULT_ICON, action = action }
                end,
            }
        end) } },
        { { text = _("Menu action") .. "\xE2\x80\xA6", callback = close(function()
            local MenuShortcut = require("actionchooser/menu_shortcut")
            MenuShortcut.openCapture(function(picked)
                on_pick{ label = picked.label, text = MENU_DEFAULT_TEXT, icon = MENU_DEFAULT_ICON, menu_path = picked.menu_path, menu_toggle = picked.menu_toggle, menu_page = picked.menu_page }
            end)
        end) } },
    }
end

return Chooser
