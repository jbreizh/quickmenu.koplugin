-- Register all plugin icons into KOReader's icon cache at startup.
-- Copies SVGs to the user icons dir so they resolve on cold starts too.

function resolveLocalIcon(icons_dir, name)
    if not icons_dir or not name then return nil end
    local lfs = require("libs/libkoreader-lfs")
    for _i, ext in ipairs({ ".svg", ".png" }) do
        local p = icons_dir .. name .. ext
        if lfs.attributes(p, "mode") == "file" then return p end
    end
    return nil
end

function registerPluginIcons(icons_dir, icons)
    if not icons_dir or type(icons) ~= "table" then return end
    pcall(function()
        local lfs = require("libs/libkoreader-lfs")
        local user_icons_dir =  nil

        -- Inject into IconWidget's runtime upvalue caches
        local iw = require("ui/widget/iconwidget")
        local iw_init = rawget(iw, "init")
        if type(iw_init) ~= "function" then return end

        local icons_path, icons_dirs
        for i = 1, 64 do
            local uname, uval = debug.getupvalue(iw_init, i)
            if uname == nil then break end
            if uname == "ICONS_PATH" and type(uval) == "table" then icons_path = uval
            elseif uname == "ICONS_DIRS" and type(uval) == "table" then icons_dirs = uval end
            if icons_path and icons_dirs then break end
        end

        if not icons_path then return end

        for name, filename in pairs(icons) do
            if not icons_path[name] then
                local user_p = user_icons_dir and resolveLocalIcon(user_icons_dir, name) or nil
                if user_p then
                    icons_path[name] = user_p
                else
                    local p = icons_dir .. filename
                    if lfs.attributes(p, "mode") == "file" then
                        icons_path[name] = p
                    end
                end
            end
        end
    end)
end

local src = debug.getinfo(1, "S").source or ""
local path = (src:sub(1, 1) == "@") and src:sub(2):match("^(.*)/icons/[^/]+$") or nil
if path and path:sub(1, 1) ~= "/" then
    local ok, lfs = pcall(require, "libs/libkoreader-lfs")
    local cwd = ok and lfs and lfs.currentdir()
    if cwd then path = cwd .. "/" .. path end
end

if path then
    registerPluginIcons(path .. "/icons/", {
        ["qm_battery"]               = "qm_battery.svg",
        ["qm_bookmark_off"]          = "qm_bookmark_off.svg",
        ["qm_bookmark_on"]           = "qm_bookmark_on.svg",
        ["qm_calibre_off"]           = "qm_calibre_off.svg",
        ["qm_calibre_on"]            = "qm_calibre_on.svg",
        ["qm_chapter"]               = "qm_chapter.svg",
        ["qm_cloud"]                 = "qm_cloud.svg",
        ["qm_collections"]           = "qm_collections.svg",
        ["qm_cpu"]                   = "qm_cpu.svg",
        ["qm_default"]               = "qm_default.svg",
        ["qm_down"]                  = "qm_down.svg",
        ["qm_favorites"]             = "qm_favorites.svg",
        ["qm_filebrowserplus_off"]   = "qm_filebrowserplus_off.svg",
        ["qm_filebrowserplus_on"]    = "qm_filebrowserplus_on.svg",
        ["qm_history"]               = "qm_history.svg",
        ["qm_kosync"]                = "qm_kosync.svg",
        ["qm_left"]                  = "qm_left.svg",
        ["qm_light_off"]             = "qm_light_off.svg",
        ["qm_light_on"]              = "qm_light_on.svg",
        ["qm_localsend_off"]         = "qm_localsend_off.svg",
        ["qm_localsend_on"]          = "qm_localsend_on.svg",
        ["qm_lock_off"]              = "qm_lock_off.svg",
        ["qm_lock_on"]               = "qm_lock_on.svg",
        ["qm_memory"]                = "qm_memory.svg",
        ["qm_minus"]                 = "qm_minus.svg",
        ["qm_night_off"]             = "qm_night_off.svg",
        ["qm_night_on"]              = "qm_night_on.svg",
        ["qm_opds"]                  = "qm_opds.svg",
        ["qm_plus"]                  = "qm_plus.svg",
        ["qm_power"]                 = "qm_power.svg",
        ["qm_power_exit"]            = "qm_power_exit.svg",
        ["qm_power_reboot"]          = "qm_power_reboot.svg",
        ["qm_power_restart"]         = "qm_power_restart.svg",
        ["qm_power_sleep"]           = "qm_power_sleep.svg",
        ["qm_process"]               = "qm_process.svg",
        ["qm_resume"]                = "qm_resume.svg",
        ["qm_right"]                 = "qm_right.svg",
        ["qm_rotate"]                = "qm_rotate.svg",
        ["qm_search"]                = "qm_search.svg",
        ["qm_search_calibre"]        = "qm_search_calibre.svg",
        ["qm_search_dictionary"]     = "qm_search_dictionary.svg",
        ["qm_search_wikipedia"]      = "qm_search_wikipedia.svg",
        ["qm_settings"]              = "qm_settings.svg",
        ["qm_ssh_off"]               = "qm_ssh_off.svg",
        ["qm_ssh_on"]                = "qm_ssh_on.svg",
        ["qm_statistics"]            = "qm_statistics.svg",
        ["qm_statistics_calendar"]   = "qm_statistics_calendar.svg",
        ["qm_storage"]               = "qm_storage.svg",
        ["qm_time"]                  = "qm_time.svg",
        ["qm_usb_storage"]           = "qm_usb_storage.svg",
        ["qm_warning"]               = "qm_warning.svg",
        ["qm_warmth_off"]            = "qm_warmth_off.svg",
        ["qm_warmth_on"]             = "qm_warmth_on.svg",
        ["qm_wifi_off"]              = "qm_wifi_off.svg",
        ["qm_wifi_on"]               = "qm_wifi_on.svg",
    })
end
