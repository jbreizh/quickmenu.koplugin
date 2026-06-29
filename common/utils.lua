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
