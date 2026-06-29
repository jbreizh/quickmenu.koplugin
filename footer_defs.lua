local Device = require("device")
local NetworkMgr = require("ui/network/manager")
local datetime = require("datetime")
local Utils = require("common/utils")
local Translation = require("i18n/translation")
local _ = Translation._

local FooterDefs = {}

function FooterDefs.get()
    return {
        wifi = {
            unicode = "\u{ECA8}",
            unicode_func =  function()
                if NetworkMgr:isWifiOn() then return "\u{ECA8}" end
                return "\u{ECA9}"
            end,
            label = _("WiFi"),
            render = function()
                return NetworkMgr:isWifiOn() and _("On") or _("Off")
            end
        },
        process = {
            unicode = "\u{E8F9}", -- engine
            label = _("Process") .. " (" .. _("MB") .. ")",
            render = function()
                local statm = io.open("/proc/self/statm", "r")
                if not statm then return "" end
                local ignore, rss = statm:read("*number", "*number")
                statm:close()
                -- we got the nb of 4Kb-pages used, that we convert to MiB
                return ("%d"):format(math.floor(rss * (4096 / 1024 / 1024))) .. _("MB")
            end
        },
        cpupercentage = {
            unicode = "\u{ED19}",
            label = _("CPU") .. " (%)",
            visible_func = function()
                local stat = Utils.systemInfo()
                if stat and stat.cpu and stat.cpu.usedpercentage then
                    return true
                end
                return false
            end,
            render = function()
                local stat = Utils.systemInfo()
                if stat and stat.cpu and stat.cpu.usedpercentage then
                    return string.format("%d%%", stat.cpu.usedpercentage)
                end
                return ""
            end
        },
        mempercentage = {
            unicode = "\u{EA5A}",
            label = _("Memory") .. " (%)",
            visible_func = function()
                local stat = Utils.systemInfo()
                if stat and stat.memory and stat.memory.usedpercentage then
                    return true
                end
                return false
            end,
            render = function()
                local stat = Utils.systemInfo()
                if stat and stat.memory and stat.memory.usedpercentage then
                    return string.format("%d%%", stat.memory.usedpercentage)
                end
                return ""
            end
        },
        mem = {
            unicode = "\u{EA5A}",
            label = _("Memory") .. " (" .. _("MB") .. ")",
            visible_func = function()
                local stat = Utils.systemInfo()
                if stat and stat.memory and stat.memory.used and stat.memory.total then
                    return true
                end
                return false
            end,
            render = function()
                local stat = Utils.systemInfo()
                if stat and stat.memory and stat.memory.used and stat.memory.total then
                    return string.format("%d/%d", math.floor((stat.memory.used) / 1024), math.floor(stat.memory.total / 1024)) .. _("MB") -- convert to MB
                end
                return ""
            end
        },
        storagepercentage = {
            unicode = "\u{F0C7}",
            label = _("Storage") .. " (%)",
            visible_func = function()
                local stat = Utils.systemInfo()
                if stat and stat.storage and stat.storage.usedpercentage then
                    return true
                end
                return false
            end,
            render = function()
                local stat = Utils.systemInfo()
                if stat and stat.storage and stat.storage.usedpercentage then
                    return string.format("%d%%", stat.storage.usedpercentage)
                end
                return ""
            end
        },
        storage = {
            unicode = "\u{F0C7}",
            label = _("Storage") .. " (" .. _("GB") .. ")",
            visible_func = function()
                local stat = Utils.systemInfo()
                if stat and stat.storage and stat.storage.used and stat.storage.total then
                    return true
                end
                return false
            end,
            render = function()
                local stat = Utils.systemInfo()
                if stat and stat.storage and stat.storage.used and stat.storage.total then
                    return string.format("%d/%d", math.floor((stat.storage.used) / 1024 / 1024), math.floor(stat.storage.total / 1024 / 1024)) .. _("GB") -- convert to GB
                end
                return ""
            end
        },
        frontlight = {
            unicode = "\u{EA2B}", -- led-on
            unicode_func = function()
                if Device:getPowerDevice():isFrontlightOn() then return "\u{EA2B}" end -- led-on
                return "\u{EA2D}" -- led-variant-off "\u{EA2A}"
            end,
            label = _("Light"),
            visible_func = function() return Device:hasFrontlight() end,
            render = function()
                local powerd = Device:getPowerDevice()
                if not powerd:isFrontlightOn() then return _("Off") end
                return ("%d%%"):format(powerd:frontlightIntensity())
            end
        },
        warmth = {
            unicode = "\u{F490}", -- flame
            unicode_func = function()
                if Device:getPowerDevice():isFrontlightOn() then return "\u{F490}" end -- flame
                return "\u{F2DC}" -- frozen
            end,
            label = _("Warmth"),
            visible_func = function() return Device:hasFrontlight() and Device:hasNaturalLight() end,
            render = function()
                local powerd = Device:getPowerDevice()
                if not powerd:isFrontlightOn() then return _("Off") end
                return ("%d%%"):format(powerd:frontlightWarmth())
            end
        },
        time = {
            unicode = "\u{F017}",
            label = _("Time"),
            render = function()
                return datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock"))
            end
        },
        battery = {
            unicode = "\u{E790}",
            unicode_func = function()
                local powerd = Device:getPowerDevice()
                local batt_lvl = powerd:getCapacity()
                return "⌁" .. powerd:getBatterySymbol(powerd:isCharged(), powerd:isCharging(), batt_lvl)
            end,
            visible_func = function() return Device:hasBattery() end,
            label = _("Battery") .. " ⌁",
            render = function()
                local powerd = Device:getPowerDevice()
                return ("%d%%"):format(powerd:getCapacity())
            end
        },
        auxbattery = {
            unicode = "\u{E78E}",
            unicode_func = function()
                local powerd = Device:getPowerDevice()
                local aux_batt_lvl = powerd:getAuxCapacity()
                return "+" .. powerd:getBatterySymbol(powerd:isAuxCharged(), powerd:isAuxCharging(), aux_batt_lvl)
            end,
            visible_func = function() return Device:hasAuxBattery() and powerd:isAuxBatteryConnected() end,
            label = _("Battery") .. " +",
            render = function()
                local powerd = Device:getPowerDevice()
                return ("%d%%"):format(powerd:getAuxCapacity())
            end
        }
    }
end

return FooterDefs



