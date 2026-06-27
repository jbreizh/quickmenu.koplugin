local Device = require("device")
local NetworkMgr = require("ui/network/manager")
local datetime = require("datetime")
local Translation = require("i18n/translation")
local _ = Translation._

local FooterDefs = {}

function FooterDefs.get()
    return {
        wifi = {
            unicode = "",
            unicode_func =  function()
                local NetworkMgr = require("ui/network/manager")
                if NetworkMgr:isWifiOn() then return "" end
                return ""
            end,
            label = _("Wi-Fi"),
            render = function()
                return NetworkMgr:isWifiOn() and _("On") or _("Off")
            end
        },
        mem = {
            unicode = "",
            label = _("Memory"),
            render = function()
                local statm = io.open("/proc/self/statm", "r")
                if not statm then return "" end
                local _, rss = statm:read("*number", "*number")
                statm:close()
                return ("%d MiB"):format(math.floor(rss * 4096 / 1048576))
            end
        },
        frontlight = {
            unicode = "\u{F185}",
            label = _("Light"),
            visible_func = function() return Device:hasFrontlight() end,
            render = function()
                local powerd = Device:getPowerDevice()
                if not powerd:isFrontlightOn() then return _("Off") end
                return ("%d%%"):format(powerd:frontlightIntensity())
            end
        },
        warmth = {
            unicode = "\u{f186}",
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
            unicode = "\u{F240}",
            unicode_func = function()
                local powerd = Device:getPowerDevice()
                local batt_lvl = powerd:getCapacity()
                return powerd:getBatterySymbol(powerd:isCharged(), powerd:isCharging(), batt_lvl)
            end,
            visible_func = function() return Device:hasBattery() end,
            label = _("Battery"),
            render = function()
                local powerd = Device:getPowerDevice()
                return ("%d%%"):format(powerd:getCapacity())
            end
        },
        auxbattery = {
            unicode = "\u{F240}",
            unicode_func = function()
                local powerd = Device:getPowerDevice()
                local aux_batt_lvl = powerd:getAuxCapacity()
                return powerd:getBatterySymbol(powerd:isAuxCharged(), powerd:isAuxCharging(), aux_batt_lvl)
            end,
            visible_func = function() return Device:hasAuxBattery() and powerd:isAuxBatteryConnected() end,
            label = _("Aux battery"),
            render = function()
                local powerd = Device:getPowerDevice()
                return ("%d%%"):format(powerd:getAuxCapacity())
            end
        }
    }
end

return FooterDefs



