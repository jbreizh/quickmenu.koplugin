local Event        = require("ui/event")
local ConfirmBox   = require("ui/widget/confirmbox")
local ButtonDialog = require("ui/widget/buttondialog")
local InfoMessage  = require("ui/widget/infomessage")
local NetworkMgr   = require("ui/network/manager")
local Menu         = require("ui/widget/menu")

local Device       = require("device")

local UIManager    = require("ui/uimanager")

local Util         = require("util")
local Utils        = require("common/utils")
local Translation  = require("i18n/translation")
local _            = Translation._

local ActionDefs = {}

function ActionDefs.get()
    return {
        wifi = {
            unicode = "\u{ECA8}", --"\u{F1EB}"
            unicode_func =  function()
                if NetworkMgr:isWifiOn() then return "\u{ECA8}" end
                return "\u{ECA9}"
            end,
            label = _("WiFi"),
            label_func = function()
                if NetworkMgr:isWifiOn() then
                    local net = NetworkMgr:getCurrentNetwork()
                    if net and net.ssid then return net.ssid end
                end
                return _("WiFi")
            end,
            active_func = function() return NetworkMgr:isWifiOn() end,
            callback = function(ctx)
                if NetworkMgr:isWifiOn() then NetworkMgr:toggleWifiOff()
                else NetworkMgr:toggleWifiOn() end
                UIManager:scheduleIn(1, function() ctx.touch_menu:updateItems(1) end)
            end,
            hold_callback = function(ctx)
                local function do_connect()
                    NetworkMgr:toggleWifiOn(function()
                        UIManager:scheduleIn(0.5, function() ctx.touch_menu:updateItems(1) end)
                    end, true, true)
                end
                if NetworkMgr:isWifiOn() then NetworkMgr:toggleWifiOff(do_connect, true)
                else do_connect() end
            end
        },
        night = {
            unicode = "\u{EC0D}", -- theme-light-dark
            label = _("Night"),
            unicode_func = function()
                if G_reader_settings:isTrue("night_mode") then return "\u{EC93}" end -- weather-night
                return "\u{EC98}" -- weather-sunny
            end,
            label_func = function()
                if G_reader_settings:isTrue("night_mode") then return _("Night") end
                return _("Day")
            end,
            active_func = function() return G_reader_settings:isTrue("night_mode") end,
            callback = function(ctx)
                UIManager:broadcastEvent(Event:new("ToggleNightMode"))
                ctx.touch_menu:updateItems(1)
            end,
        },
        light = {
            unicode = "\u{EA2B}", -- led-on
            unicode_func = function()
            if Device:getPowerDevice():isFrontlightOn() then return "\u{EA2B}" end -- led-on
                return "\u{EA2D}" -- led-variant-off "\u{EA2A}"
            end,
            label = _("Light"),
            visible_func = function() return Device:hasFrontlight() end,
            active_func = function() return Device:getPowerDevice():isFrontlightOn() end,
            callback = function(ctx)
                Device:getPowerDevice():toggleFrontlight()
                ctx.touch_menu:updateItems(1)
            end,
        },
        rotate = {
            unicode = "\u{EB74}",
            label = _("Rotate"),
            label_func =  function()
                local rot = Device.screen:getRotationMode()
                if     rot == 1 then return "90°" -- 90°
                elseif rot == 2 then return "180°" -- 180°
                elseif rot == 3 then return "270°" -- 270°
                else                 return "0°" -- 0°
                end
            end,
            callback = function(ctx) UIManager:broadcastEvent(Event:new("SwapRotation")) end,
            hold_callback = function(ctx) UIManager:broadcastEvent(Event:new("InvertRotation")) end
        },
        lock = {
            unicode = "\u{F023}",
            unicode_func =  function()
                if G_reader_settings:isTrue("input_lock_gsensor") or G_reader_settings:isTrue("input_ignore_gsensor") then return "\u{F023}" end
                return "\u{F09C}"
            end,
            label = _("Lock"),
            label_func = function()
                if G_reader_settings:isTrue("input_lock_gsensor") or G_reader_settings:isTrue("input_ignore_gsensor") then return _("Lock") end
                return _("Unlock")
            end,
            visible_func = function() return Device:hasGSensor() end,
            active_func = function() return G_reader_settings:isTrue("input_lock_gsensor") or G_reader_settings:isTrue("input_ignore_gsensor") end,
            callback = function(ctx)
                if G_reader_settings:isTrue("input_ignore_gsensor") then
                    UIManager:broadcastEvent(Event:new("ToggleGSensor"))
                    if G_reader_settings:isTrue("input_lock_gsensor") then UIManager:broadcastEvent(Event:new("LockGSensor")) end
                else UIManager:broadcastEvent(Event:new("LockGSensor")) end
                ctx.touch_menu:updateItems(1)
            end,
            hold_callback = function(ctx)
                if G_reader_settings:isTrue("input_lock_gsensor") then
                    UIManager:broadcastEvent(Event:new("LockGSensor"))
                    if G_reader_settings:isTrue("input_ignore_gsensor") then UIManager:broadcastEvent(Event:new("ToggleGSensor")) end
                else UIManager:broadcastEvent(Event:new("ToggleGSensor")) end
                ctx.touch_menu:updateItems(1)
            end
        },
        usb = {
            unicode = "\u{F287}",
            label = _("USB"),
            visible_func = function() return Device.canToggleMassStorage and Device:canToggleMassStorage() end,
            callback = function(ctx) UIManager:broadcastEvent(Event:new("RequestUSBMS")) end,
        },
        restart = {
            unicode = "\u{F021}",
            label = _("Restart"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:show(ConfirmBox:new{
                    text = _("Are you sure you want to restart KOReader ?"),
                    ok_text = _("Restart"),
                    ok_callback = function() UIManager:broadcastEvent(Event:new("Restart")) end
                })
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:show(ConfirmBox:new{
                    text = _("Are you sure you want to exit KOReader ?"),
                    ok_text = _("Exit"),
                    ok_callback = function() UIManager:broadcastEvent(Event:new("Exit")) end
                })
            end,
        },
        exit = {
            unicode = "\u{274C}",
            label = _("Exit"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:show(ConfirmBox:new{
                    text = _("Are you sure you want to exit KOReader ?"),
                    ok_text = _("Exit"),
                    ok_callback = function() UIManager:broadcastEvent(Event:new("Exit")) end
                })
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:show(ConfirmBox:new{
                    text = _("Are you sure you want to restart KOReader ?"),
                    ok_text = _("Restart"),
                    ok_callback = function() UIManager:broadcastEvent(Event:new("Restart")) end
                })
            end,
        },
        reboot = {
            unicode = "\u{F01E}",
            label = _("Reboot"),
            visible_func = function() return Device:canReboot() end,
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Device:canReboot() then
                    UIManager:askForReboot()
                else
                    UIManager:show(InfoMessage:new{ text =  _("Reboot") .. " : " .. _("Not possible") })
                end
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Device:canPowerOff() then
                    UIManager:askForPowerOff()
                else
                    UIManager:show(InfoMessage:new{ text =  _("Power off") .. " : " .. _("Not possible") })
                end
            end,
        },
        sleep = {
            unicode = "\u{EBB1}", -- sleep
            label = _("Sleep"),
            visible_func = function() return Device:canSuspend() end,
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Device:canSuspend() then
                    UIManager:broadcastEvent(Event:new("RequestSuspend"))
                else
                    UIManager:show(InfoMessage:new{ text =  _("Sleep") .. " : " .. _("Not possible") })
                end
            end,
        },
        poweroff = {
            unicode = "\u{F011}",
            label = _("Power off"),
            visible_func = function() return Device:canPowerOff() end,
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Device:canPowerOff() then
                    UIManager:askForPowerOff()
                else
                    UIManager:show(InfoMessage:new{ text =  _("Power off") .. " : " .. _("Not possible") })
                end
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Device:canReboot() then
                    UIManager:askForReboot()
                else
                    UIManager:show(InfoMessage:new{ text =  _("Reboot") .. " : " .. _("Not possible") })
                end
            end,
        },
        power = {
            unicode = "\u{F011}",
            label = _("Power"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()

                local buttons = {}
                if Device:canRestart() then
                    buttons[#buttons + 1] = {{
                        text = "\u{F021}" .. " " ..  _("Restart") .. " " .. "KOReader",
                        callback = function()
                            local d = power_dialog
                            power_dialog = nil
                            UIManager:close(d)
                            UIManager:show(ConfirmBox:new{
                                text = _("Are you sure you want to restart KOReader ?"),
                                ok_text = _("Restart"),
                                ok_callback = function() UIManager:broadcastEvent(Event:new("Restart")) end
                            })
                        end
                    }}
                end
                buttons[#buttons + 1] = {{
                    text = "\u{274C}" .. " " ..  _("Exit") .. " " .. "KOreader",
                    callback = function()
                        local d = power_dialog
                        power_dialog = nil
                        UIManager:close(d)
                        UIManager:show(ConfirmBox:new{
                            text = _("Are you sure you want to exit KOReader ?"),
                            ok_text = _("Exit"),
                            ok_callback = function() UIManager:broadcastEvent(Event:new("Exit")) end
                        })
                    end
                }}
                if Device:canReboot() then
                    buttons[#buttons + 1] = {{
                        text = "\u{F01E}" .. " " ..  _("Reboot"),
                        callback = function()
                            local d = power_dialog
                            power_dialog = nil
                            UIManager:close(d)
                            UIManager:askForReboot()
                        end
                    }}
                end
                if Device:canSuspend() then
                    buttons[#buttons + 1] = {{
                        text = "\u{EBB1}" .. " " ..  _("Sleep"),
                        callback = function()
                            local d = power_dialog
                            power_dialog = nil
                            UIManager:close(d)
                            UIManager:suspend()
                        end
                    }}
                end
                if Device:canPowerOff() then
                    buttons[#buttons + 1] = {{
                        text = "\u{F011}" .. " " ..  _("Power off"),
                        callback = function()
                            local d = power_dialog
                            power_dialog = nil
                            UIManager:close(d)
                            UIManager:askForPowerOff()
                        end
                    }}
                end

                power_dialog = ButtonDialog:new{
                    width              = math.floor(ctx.screen:getWidth() * 0.5),
                    buttons            = buttons,
                }
                UIManager:show(power_dialog)
            end,
        },
        dictionary = {
            unicode = "\u{F02D}",
            label = _("Dictionary"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ShowDictionaryLookup"))
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ShowWikipediaLookup"))
            end
        },
        wikipedia = {
            unicode = "\u{F266}",
            label = _("Wikipedia"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ShowWikipediaLookup"))
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ShowDictionaryLookup"))
            end
        },
        history = {
            unicode = "\u{F1DA}",
            label = _("History"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if ctx.filemanager and ctx.filemanager.history then ctx.filemanager.history:onShowHist()
                elseif ctx.reader and ctx.reader.history then ctx.reader.history:onShowHist() end
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if ctx.filemanager and ctx.filemanager.menu then ctx.filemanager.menu:onOpenLastDoc()
                elseif ctx.reader then ctx.reader:onOpenLastDoc() end
            end
        },
        resume = {
            unicode = "\u{F04B}",
            label = _("Resume"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if ctx.filemanager and ctx.filemanager.menu then ctx.filemanager.menu:onOpenLastDoc()
                elseif ctx.reader then ctx.reader:onOpenLastDoc() end
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if ctx.filemanager and ctx.filemanager.history then ctx.filemanager.history:onShowHist()
                elseif ctx.reader and ctx.reader.history then ctx.reader.history:onShowHist() end
            end
        },
        collections = {
            unicode = "\u{F0C9}",
            label = _("Collections"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if ctx.filemanager and ctx.filemanager.collections then ctx.filemanager.collections:onShowCollList()
                elseif ctx.reader and ctx.reader.collections then ctx.reader.collections:onShowCollList() end
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if ctx.filemanager and ctx.filemanager.collections then ctx.filemanager.collections:onShowColl()
                elseif ctx.reader and ctx.reader.collections then ctx.reader.collections:onShowColl() end
            end
        },
        favorites = {
            unicode = "\u{F005}",
            label = _("Favorites"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if ctx.filemanager and ctx.filemanager.collections then ctx.filemanager.collections:onShowColl()
                elseif ctx.reader and ctx.reader.collections then ctx.reader.collections:onShowColl() end
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if ctx.filemanager and ctx.filemanager.collections then ctx.filemanager.collections:onShowCollList()
                elseif ctx.reader and ctx.reader.collections then ctx.reader.collections:onShowCollList() end
            end
        },
        -- core plugin
        cloud = {
            unicode = "\u{F0C2}",
            label = _("Cloud"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ShowCloudStorage"))
                end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("opds") then UIManager:broadcastEvent(Event:new("ShowOPDSCatalog"))
                else UIManager:show(InfoMessage:new{ text = "OPDS : " .. _("Plugin not activated.") }) end
            end
        },
        opds = {
            unicode = "\u{F0ED}",
            label = _("OPDS"),
            visible_func = function() return Utils.hasPlugin and Utils.hasPlugin("opds") end,
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("opds") then UIManager:broadcastEvent(Event:new("ShowOPDSCatalog"))
                else UIManager:show(InfoMessage:new{ text = "OPDS : " .. _("Plugin not activated.") }) end
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ShowCloudStorage"))
            end
        },
        ssh = {
            unicode = "\u{EA17}", -- lan-connect
            unicode_func = function()
                if Util.pathExists("/tmp/dropbear_koreader.pid") then return "\u{EA17}" end -- lan-connect
                return "\u{EA18}" -- lan-disconnect
            end,
            label = _("SSH"),
            visible_func = function() return Utils.hasPlugin and Utils.hasPlugin("SSH") end,
            active_func = function() return Util.pathExists("/tmp/dropbear_koreader.pid") end,
            callback = function(ctx)
                if Utils.hasPlugin and Utils.hasPlugin("SSH") then
                    UIManager:broadcastEvent(Event:new("ToggleSSHServer"))
                    UIManager:scheduleIn(2, function() ctx.touch_menu:updateItems(1) end)
                else UIManager:show(InfoMessage:new{ text = "SSH : " .. _("Plugin not activated.") }) end
            end,
        },
        calibre = {
            unicode = "\u{EB8C}", -- server-network
            unicode_func = function()
                local CW = package.loaded["wireless"]
                if CW ~= nil and CW.calibre_socket ~= nil then return "\u{EB8C}" end -- server-network
                return "\u{EB8D}" -- server-network-off
            end,
            label = "Calibre",
            visible_func = function() return Utils.hasPlugin and Utils.hasPlugin("calibre") end,
            active_func = function()
                local CW = package.loaded["wireless"]
                return CW ~= nil and CW.calibre_socket ~= nil
            end,
            callback = function(ctx)
                if Utils.hasPlugin and Utils.hasPlugin("calibre") then
                    local CW = package.loaded["wireless"]
                    if CW and CW.calibre_socket ~= nil then UIManager:broadcastEvent(Event:new("CloseWirelessConnection"))
                    else UIManager:broadcastEvent(Event:new("StartWirelessConnection")) end
                    UIManager:scheduleIn(2, function() ctx.touch_menu:updateItems(1) end)
                else UIManager:show(InfoMessage:new{ text = "Calibre : " .. _("Plugin not activated.") }) end
            end,
        },
        search = {
            unicode = "\u{F002}",
            label = _("Search"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ShowFileSearch"))
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("calibre") then UIManager:broadcastEvent(Event:new("CalibreSearch"))
                else UIManager:show(InfoMessage:new{ text = "Calibre : " .. _("Plugin not activated.") }) end
            end
        },
        searchcalibre = {
            unicode = "\u{F00E}",
            label = "Calibre",
            visible_func = function() return Utils.hasPlugin and Utils.hasPlugin("calibre") end,
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("calibre") then UIManager:broadcastEvent(Event:new("CalibreSearch"))
                else UIManager:show(InfoMessage:new{ text = "Calibre : " .. _("Plugin not activated.") }) end
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ShowFileSearch"))
                end
        },
        statistics = {
            unicode = "\u{F200}",
            label = _("Statistics"),
            visible_func = function() return Utils.hasPlugin and Utils.hasPlugin("statistics") end,
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("statistics") then UIManager:broadcastEvent(Event:new("ShowReaderProgress"))
                else UIManager:show(InfoMessage:new{ text = "Statistics : " .. _("Plugin not activated.") }) end
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("statistics") then UIManager:broadcastEvent(Event:new("ShowCalendarView"))
                else UIManager:show(InfoMessage:new{ text = "Statistics : " .. _("Plugin not activated.") }) end
            end
        },
        statisticscalendar = {
            unicode = "\u{F073}",
            label = _("Calendar"),
            visible_func = function() return Utils.hasPlugin and Utils.hasPlugin("statistics") end,
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("statistics") then  UIManager:broadcastEvent(Event:new("ShowCalendarView"))
                else UIManager:show(InfoMessage:new{ text = "Statistics : " .. _("Plugin not activated.") }) end
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("statistics") then UIManager:broadcastEvent(Event:new("ShowReaderProgress"))
                else UIManager:show(InfoMessage:new{ text = "Statistics : " .. _("Plugin not activated.") }) end
            end
        },
        kosync = {
            unicode = "\u{E866}",
            label = _("KOSync"),
            visible_func = function() return Utils.hasPlugin and Utils.hasPlugin("kosync") end,
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                NetworkMgr:runWhenOnline(function()
                    UIManager:broadcastEvent(Event:new("KOSyncPushProgress"))
                end)
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                NetworkMgr:runWhenOnline(function()
                    UIManager:broadcastEvent(Event:new("KOSyncPullProgress"))
                end)
            end,
        },
        -- other plugin
        zlibrary = {
            unicode = "\u{005A}",
            label = _("Z-Lib"),
            visible_func = function() return Utils.hasPlugin and Utils.hasPlugin("zlibrary") end,
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ZlibrarySearch"))
            end,
        },
    }
end

return ActionDefs
