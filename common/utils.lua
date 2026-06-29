local M = {}

--- Find a section by its ID within the config table.
--- @param config table  The configuration table containing sections.
--- @param id     string  The section ID to look for.
--- @return        table|nil
function M.getSection(config, id)
    if not config or type(config.sections) ~= "table" then
        return nil
    end
    local section = config.sections[id]
    if section then
        section.items = section.items or {}
    end
    return section
end

--- Reset a section to defaults.
--- @param section  table  The section current settings.
--- @param defaults table  The section defaults settings.
function M.resetSectionToDefaults(section, defaults)
    if not section or not defaults then return end
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            section[k] = {}
            for key, val in pairs(v) do
                section[k][key] = val
            end
        else
            section[k] = v
        end
    end
end

--- Verify plugin in present in active instance.
--- @param slot      string  plugin name
--- @return          boolean
function M.hasPlugin(slot)
    local ok_f, FM = pcall(require, "apps/filemanager/filemanager")
    local ok_r, RU = pcall(require, "apps/reader/readerui")
    local ui = (ok_f and FM.instance) or (ok_r and RU.instance)
    return ui == nil or ui[slot] ~= nil
end

--- Resolve an icon name to an absolute file path (checks .svg then .png).
--- @param icons_dir string  absolute path ending with "/"
--- @param name      string  icon name without extension
--- @return          string|nil
function M.resolveLocalIcon(icons_dir, name)
    if not icons_dir or not name then return nil end
    local lfs = require("libs/libkoreader-lfs")
    for _, ext in ipairs({ ".svg", ".png" }) do
        local p = icons_dir .. name .. ext
        if lfs.attributes(p, "mode") == "file" then return p end
    end
    return nil
end

--- Register plugin icons so short names resolve via IconWidget at runtime.
--- Optionally copies files to the user icons dir for cold-start resolution.
---
--- @param icons_dir        string   absolute path to the plugin icons dir, ending with "/"
--- @param icons            table    { [icon_name] = "filename.ext", ... }
--- @param copy_to_user_dir boolean  also copy files to DataStorage icons dir
function M.registerPluginIcons(icons_dir, icons, copy_to_user_dir)
    if not icons_dir or type(icons) ~= "table" then return end
    pcall(function()
        local lfs = require("libs/libkoreader-lfs")
        local user_icons_dir =  nil

        if copy_to_user_dir then
            pcall(function()
                local DataStorage = require("datastorage")
                local ffiutil = require("ffi/util")
                local user_icons_dir = DataStorage:getDataDir() .. "/icons"
                if lfs.attributes(user_icons_dir, "mode") ~= "directory" then
                    lfs.mkdir(user_icons_dir)
                end
                for name, filename in pairs(icons) do
                    -- Use icon short-name as dest so ICONS_DIRS lookup finds it by name
                    local ext = filename:match("%.[^%.]+$") or ".svg"
                    local dst = user_icons_dir .. "/" .. name .. ext
                    if lfs.attributes(dst, "mode") ~= "file" then
                        local src = icons_dir .. filename
                        if lfs.attributes(src, "mode") == "file" then
                            ffiutil.copyFile(src, dst)
                        end
                    end
                end
            end)
        end

        -- Inject into IconWidget's runtime upvalue caches
        local iw = require("ui/widget/iconwidget")
        local iw_init = rawget(iw, "init")
        if type(iw_init) ~= "function" then return end
        local icons_path, icons_dirs
        for i = 1, 64 do
            local uname, uval = debug.getupvalue(iw_init, i)
            if uname == nil then break end
            if uname == "ICONS_PATH" and type(uval) == "table" then
                icons_path = uval
            elseif uname == "ICONS_DIRS" and type(uval) == "table" then
                icons_dirs = uval
            end
            if icons_path and icons_dirs then break end
        end
        -- Ensure user icons dir is in ICONS_DIRS (may have been absent at widget load time)
        if icons_dirs and copy_to_user_dir then
            pcall(function()
                local DataStorage = require("datastorage")
                local user_dir = DataStorage:getDataDir() .. "/icons"
                local found = false
                for _, d in ipairs(icons_dirs) do
                    if d == user_dir then found = true; break end
                end
                if not found then table.insert(icons_dirs, 1, user_dir) end
            end)
        end
        if not icons_path then return end
        for name, filename in pairs(icons) do
            if not icons_path[name] then
                local user_p = user_icons_dir and M.resolveLocalIcon(user_icons_dir, name) or nil
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

--- Fetch system information.
--- @return          table
function M.systemInfo()
    local util = require("util")
    local Device = require("device")
    local result = {}
    do
        local stat = io.open("/proc/stat", "r")
        if stat ~= nil then
            for line in stat:lines() do
                local t = util.splitToArray(line, " ")
                if #t >= 5 and string.lower(t[1]) == "cpu" then
                    local n1, n2, n3, n4
                    n1 = tonumber(t[2]) -- user
                    n2 = tonumber(t[3]) -- nice
                    n3 = tonumber(t[4]) -- system
                    n4 = n1 + n2 + n3 -- used
                    n5 = tonumber(t[5]) -- available
                    n6 = n4 + n5 -- total
                    if n4 ~= nil and n5 ~= nil and n6 ~= nil and n6 ~= 0 then
                        result.cpu = {
                            used = n4,
                            usedpercentage = math.floor((n4 * 100) / n6),
                            available = n5,
                            availablepercentage = math.floor((n5 * 100) / n6),
                            total = n6,
                        }
                        break
                    end
                end
            end
            stat:close()
        end
    end

    do
        local meminfo = io.open("/proc/meminfo", "r")
        if meminfo ~= nil then
            result.memory = {}
            for line in meminfo:lines() do
                local t = util.splitToArray(line, " ")
                if #t >= 2 then
                    if string.lower(t[1]) == "memtotal:" then
                        local n = tonumber(t[2])
                        if n ~= nil then
                            result.memory.total = n
                        end
                    elseif string.lower(t[1]) == "memfree:" then
                        local n = tonumber(t[2])
                        if n ~= nil then
                            result.memory.free = n
                        end
                    elseif string.lower(t[1]) == "memavailable:" then
                        local n = tonumber(t[2])
                        if n ~= nil then
                            result.memory.available = n
                        end
                    end
                end
            end
            meminfo:close()

            if result.memory.total and result.memory.available then
                result.memory.used = result.memory.total - result.memory.available
                if result.memory.total > 0 then
                    result.memory.usedpercentage = math.floor((result.memory.used * 100) / result.memory.total)
                end
            end
        end
    end

    do
        local storage_filter = nil
        if Device:isCervantes() or Device:isPocketBook() then
            storage_filter = "mmcblk"
        elseif Device:isKobo() then
            storage_filter = " /mnt/"
        elseif Device:isKindle() then
            storage_filter = "' /mnt/us$'"
        elseif Device:isSDL() then
            storage_filter = "/dev/sd"
        end

        if storage_filter then
            local std_out = io.popen("df -k | sed -r 's/ +/ /g' | grep " .. storage_filter .. " | sed 's/ /\\t/g' | cut -f 2,4,5,6")
            if std_out then
                result.storage = {}
                for line in std_out:lines() do
                    local t = util.splitToArray(line, "\t")
                    if #t == 4 then
                        local n1, n2, n3, n4
                        n1 = tonumber(t[1]) --total kB
                        n2 = tonumber(t[2]) --available kB
                        -- t[3]: usedpercentage
                        -- t[4]: mountpoint
                        if n1 ~= nil and n2 ~= nil and n1 ~= 0 then
                        result.storage = {
                            available = n2,
                            availablepercentage = math.floor((n2 * 100) / n1),
                            used = n1 - n2,
                            usedpercentage = math.floor(((n1 - n2) * 100) / n1),
                            total = n1,
                        }
                        break
                        end
                    end
                end
            end
            std_out:close()
        end
    end

    return result
end

return M
