local Event      = require("ui/event")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local NetworkMgr = require("ui/network/manager")
local Device     = require("device")
local UIManager  = require("ui/uimanager")
local Util       = require("util")
local Utils      = require("common/utils")
local Translation = require("i18n/translation")
local _          = Translation._

local ActionDefs = {}

function ActionDefs.get()
    return {
        wifi = {
            unicode = "\u{F1EB}",
            label = _("Wi-Fi"),
            label_func = function()
                if NetworkMgr:isWifiOn() then
                    local net = NetworkMgr:getCurrentNetwork()
                    if net and net.ssid then return net.ssid end
                end
                return _("Wi-Fi")
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
            unicode = "\u{F186}",
            label = _("Night"),
            active_func = function() return G_reader_settings:isTrue("night_mode") end,
            callback = function(ctx)
                UIManager:broadcastEvent(Event:new("ToggleNightMode"))
                ctx.touch_menu:updateItems(1)
            end,
        },
        light = {
            unicode = "\u{F185}",
            label = _("Light"),
            visible_func = function() return Device:hasFrontlight() end,
            active_func = function() return Device:getPowerDevice():isFrontlightOn() end,
            callback = function(ctx)
                Device:getPowerDevice():toggleFrontlight()
                ctx.touch_menu:updateItems(1)
            end,
        },
        rotate = {
            unicode = "\u{F01E}",
            label = _("Rotate"),
            callback = function(ctx) UIManager:broadcastEvent(Event:new("SwapRotation")) end,
            hold_callback = function(ctx) UIManager:broadcastEvent(Event:new("InvertRotation")) end
        },
        lock = {
            unicode = "\u{F023}",
            label = _("Lock"),
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
            unicode = "\u{F0E2}",
            label = _("Restart"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:show(ConfirmBox:new{
                    text = _("Are you sure you want to restart KOReader ?"),
                    ok_text = _("Restart"),
                    ok_callback = function() UIManager:broadcastEvent(Event:new("Restart")) end
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
        },
        sleep = {
            unicode = "\u{F04C}",
            label = _("Sleep"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Device:canSuspend() then UIManager:broadcastEvent(Event:new("RequestSuspend"))
                elseif Device:canPowerOff() then UIManager:broadcastEvent(Event:new("RequestPowerOff")) end
            end,
        },
        ssh = {
            unicode = "\u{F120}",
            label = _("SSH"),
            visible_func = function() return Utils.hasPlugin("SSH") end,
            active_func = function() return Util.pathExists("/tmp/dropbear_koreader.pid") end,
            callback = function(ctx)
                if Utils.hasPlugin and Utils.hasPlugin("SSH") then
                    UIManager:broadcastEvent(Event:new("ToggleSSHServer"))
                    UIManager:scheduleIn(2, function() ctx.touch_menu:updateItems(1) end)
                else UIManager:show(InfoMessage:new{ text = "Calibre : " .. _("Plugin not activated.") }) end
            end,
        },
        calibre = {
            unicode = "\u{F0EA}",
            label = _("Calibre"),
            visible_func = function() return Utils.hasPlugin("calibre") end,
            active_func = function()
                local CW = package.loaded["wireless"]
                return CW ~= nil and CW.calibre_socket ~= nil
            end,
            callback = function(ctx)
                if Utils.hasPlugin and Utils.hasPlugin("calibre") then
                    local CW = package.loaded["wireless"]
                    if CW and CW.calibre_socket ~= nil then UIManager:broadcastEvent(Event:new("CloseWirelessConnection"))
                    else UIManager:broadcastEvent(Event:new("StartWirelessConnection")) end
                    UIManager:scheduleIn(1, function() ctx.touch_menu:updateItems(1) end)
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
        search2 = {
            unicode = "\u{F00E}",
            label = _("Search in Calibre"),
            visible_func = function() return Utils.hasPlugin("calibre") end,
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
            visible_func = function() return Utils.hasPlugin("opds") end,
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
        statistics2 = {
            unicode = "\u{F073}",
            label = _("Statistics"),
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
        }
    }
end

return ActionDefs
