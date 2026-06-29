-- Register all plugin icons into KOReader's icon cache at startup.
-- Copies SVGs to the user icons dir so they resolve on cold starts too.

local utils = require("common/utils")

local _plugin_root = require("common/plugin_root")

if _plugin_root then
    utils.registerPluginIcons(_plugin_root .. "/icons/", {
        ["quickmenu"]           = "quickmenu.svg",
    }, false)
end
