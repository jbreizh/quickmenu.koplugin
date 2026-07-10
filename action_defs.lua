local Event         = require("ui/event")

local TextWidget    = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local Font            = require("ui/font")

local ConfirmBox   = require("ui/widget/confirmbox")
local ButtonDialog = require("ui/widget/buttondialog")
local InfoMessage  = require("ui/widget/infomessage")
local NetworkMgr   = require("ui/network/manager")
local Menu         = require("ui/widget/menu")

local UIManager    = require("ui/uimanager")

local Util         = require("util")

local Utils            = require("common/utils")
local FrontlightPreset = require("frontlight_preset")
local _                = require("common/i18n").gettext

local ActionDefs = {}

function ActionDefs.getMerged(custom_actions)
    local all = ActionDefs.get()
    if custom_actions then
        for i, custom in ipairs(custom_actions) do
            if custom.id then all[custom.id] = custom end
        end
    end
    return all
end

function ActionDefs.get()
    return {
        wifi = {
            icon = "\u{ECA8}", --"\u{F1EB}"
            icon_func =  function(ctx)
                if NetworkMgr:isWifiOn() then return "\u{ECA8}" end
                return "\u{ECA9}"
            end,
            label = _("WiFi"),
            label_func = function(ctx)
                if NetworkMgr:isWifiOn() then
                    local net = NetworkMgr:getCurrentNetwork()
                    if net and net.ssid then return net.ssid else return _("On") end
                end
                return _("Off")
            end,
            active_func = function(ctx) return NetworkMgr:isWifiOn() end,
            -- visible_func
            help_text = _("Tap : Toggle wifi\nHold : Show wifi picker"),
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
            icon = "\u{EC0D}", -- theme-light-dark
            icon_func = function(ctx)
                if G_reader_settings:isTrue("night_mode") then return "\u{EC93}" end -- weather-night
                return "\u{EC98}" -- weather-sunny
            end,
            label = _("Night"),
            label_func = function(ctx)
                if G_reader_settings:isTrue("night_mode") then return _("Night") end
                return _("Day")
            end,
            active_func = function(ctx) return G_reader_settings:isTrue("night_mode") end,
            -- visible_func
            help_text = _("Tap : Toggle night mode\nHold : Show frontlight preset dialog"),
            callback = function(ctx)
                UIManager:broadcastEvent(Event:new("ToggleNightMode"))
                ctx.touch_menu:updateItems(1)
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                FrontlightPreset:showFrontlightPresetMenu(ctx.config)
            end
        },
        light = {
            icon = "\u{EA2B}", -- led-on
            icon_func = function(ctx)
            if ctx.powerd:isFrontlightOn() then return "\u{EA2B}" end -- led-on
                return "\u{EA2D}" -- led-variant-off "\u{EA2A}"
            end,
            label = _("Light"),
            label_func = function(ctx)
                if not ctx.powerd:isFrontlightOn() then return _("Off") end
                return ("%d%%"):format(ctx.powerd:frontlightIntensity())
            end,
            active_func = function(ctx) return ctx.powerd:isFrontlightOn() end,
            visible_func = function(ctx) return ctx.device:hasFrontlight() end,
            help_text = _("Tap : Toggle frontlight\nHold : Show frontlight dialog"),
            callback = function(ctx)
                UIManager:broadcastEvent(Event:new("ToggleFrontlight"))
                ctx.touch_menu:updateItems(1)
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ShowFlDialog"))
            end
        },
        warmth = {
            icon = "\u{F490}", -- flame
            icon_func = function(ctx)
                if not ctx.powerd:isFrontlightOn() or ctx.powerd:frontlightWarmth() == 0 then return "\u{F2DC}" end -- frozen
                return "\u{F490}" -- flamme
            end,
            label = _("Warmth"),
            label_func = function(ctx)
                if not ctx.powerd:isFrontlightOn() or ctx.powerd:frontlightWarmth() == 0 then return _("Off") end
                return ("%d%%"):format(ctx.powerd:frontlightWarmth())
            end,
            active_func = function(ctx) return ctx.powerd:isFrontlightOn() and ctx.powerd:frontlightWarmth() ~= 0 end,
            visible_func = function(ctx) return ctx.device:hasFrontlight() and ctx.device:hasNaturalLight() end,
            help_text = _("Tap : Show frontlight preset dialog\nHold : Show frontlight dialog"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                FrontlightPreset:showFrontlightPresetMenu(ctx.config)
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ShowFlDialog"))
            end
        },
        rotate = {
            icon = "\u{EB74}",
            -- icon_func
            label = _("Rotate"),
            label_func =  function(ctx)
                local rot = ctx.device.screen:getRotationMode()
                if     rot == 1 then return "90°" -- 90°
                elseif rot == 2 then return "180°" -- 180°
                elseif rot == 3 then return "270°" -- 270°
                else                 return "0°" -- 0°
                end
            end,
            -- active_func
            -- visible_func
            help_text = _("Tap : Swap rotation\nHold : Invert rotation"),
            callback = function(ctx) UIManager:broadcastEvent(Event:new("SwapRotation")) end,
            hold_callback = function(ctx) UIManager:broadcastEvent(Event:new("InvertRotation")) end
        },
        lock = {
            icon = "\u{F023}",
            icon_func =  function(ctx)
                if G_reader_settings:isTrue("input_lock_gsensor") or G_reader_settings:isTrue("input_ignore_gsensor") then return "\u{F023}" end
                return "\u{F09C}"
            end,
            label = _("Lock"),
            label_func = function(ctx)
                if G_reader_settings:isTrue("input_lock_gsensor") or G_reader_settings:isTrue("input_ignore_gsensor") then return _("Lock") end
                return _("Unlock")
            end,
            visible_func = function(ctx) return ctx.device:hasGSensor() end,
            active_func = function(ctx) return G_reader_settings:isTrue("input_lock_gsensor") or G_reader_settings:isTrue("input_ignore_gsensor") end,
            help_text = _("Tap : Toggle lock gsensor\nHold : Toggle ignore gsensor"),
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
            icon = "\u{F287}",
            -- icon_func
            label = _("USB"),
            -- label_func
            -- active_func
            help_text = _("Tap : Request UBS mass storage\nHold : Nothing"),
            visible_func = function(ctx) return ctx.device.canToggleMassStorage and ctx.device:canToggleMassStorage() end,
            callback = function(ctx) UIManager:broadcastEvent(Event:new("RequestUSBMS")) end,
            hold_callback = function(ctx) ctx.touch_menu:closeMenu(); UIManager:show(InfoMessage:new{ text =  _("Nothing to do") }) end
        },
        restart = {
            icon = "\u{F021}",
            -- icon_func
            label = _("Restart"),
            -- label_func
            -- active_func
            -- visible_func
            help_text = _("Tap : Ask for restart KOreader\nHold : Ask for exit KOreader"),
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
            icon = "\u{274C}",
            -- icon_func
            label = _("Exit"),
            -- label_func
            -- active_func
            -- visible_func
            help_text = _("Tap : Ask for exit KOreader\nHold : Ask for restart KOreader"),
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
            icon = "\u{F01E}",
            -- icon_func
            label = _("Reboot"),
            -- label_func
            -- active_func
            visible_func = function(ctx) return ctx.device:canReboot() end,
            help_text = _("Tap : Ask for reboot system\nHold : Ask for power off system"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if ctx.device:canReboot() then
                    UIManager:askForReboot()
                else
                    UIManager:show(InfoMessage:new{ text =  _("Reboot") .. " : " .. _("Not possible") })
                end
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if ctx.device:canPowerOff() then
                    UIManager:askForPowerOff()
                else
                    UIManager:show(InfoMessage:new{ text =  _("Power off") .. " : " .. _("Not possible") })
                end
            end,
        },
        sleep = {
            icon = "\u{EBB1}", -- sleep
            -- icon_func
            label = _("Sleep"),
            -- label_func
            -- active_func
            visible_func = function(ctx) return ctx.device:canSuspend() end,
            help_text = _("Tap : Suspend system\nHold : Nothing"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if ctx.device:canSuspend() then
                    UIManager:broadcastEvent(Event:new("RequestSuspend"))
                else
                    UIManager:show(InfoMessage:new{ text =  _("Sleep") .. " : " .. _("Not possible") })
                end
            end,
            hold_callback = function(ctx) ctx.touch_menu:closeMenu(); UIManager:show(InfoMessage:new{ text =  _("Nothing to do") }) end
        },
        poweroff = {
            icon = "\u{F011}",
            -- icon_func
            label = _("Power off"),
            -- label_func
            -- active_func
            visible_func = function(ctx) return ctx.device:canPowerOff() end,
            help_text = _("Tap : Ask for power off system\nHold : Ask for reboot system"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if ctx.device:canPowerOff() then
                    UIManager:askForPowerOff()
                else
                    UIManager:show(InfoMessage:new{ text =  _("Power off") .. " : " .. _("Not possible") })
                end
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if ctx.device:canReboot() then
                    UIManager:askForReboot()
                else
                    UIManager:show(InfoMessage:new{ text =  _("Reboot") .. " : " .. _("Not possible") })
                end
            end,
        },
        power = {
            icon = "\u{F011}",
            -- icon_func
            label = _("Power"),
            -- label_func
            -- active_func
            -- visible_func
            help_text = _("Tap : Show power dialog\nHold : Nothing"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                local buttons = {}
                if ctx.device:canRestart() then
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
                if ctx.device:canReboot() then
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
                if ctx.device:canSuspend() then
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
                if ctx.device:canPowerOff() then
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
                    title        = _("Power"),
                    width_factor =  0.5,
                    buttons      = buttons,
                }
                UIManager:show(power_dialog)
            end,
            hold_callback = function(ctx) ctx.touch_menu:closeMenu(); UIManager:show(InfoMessage:new{ text =  _("Nothing to do") }) end
        },
        dictionary = {
            icon = "\u{F02D}",
            -- icon_func
            label = _("Dictionary"),
            -- label_func
            -- active_func
            -- visible_func
            help_text = _("Tap : Show dictionary search\nHold : Show wikipedia search"),
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
            icon = "\u{F266}",
            -- icon_func
            label = _("Wikipedia"),
            -- label_func
            -- active_func
            -- visible_func
            help_text = _("Tap : Show wikipedia search\nHold : Show dictionary search"),
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
            icon = "\u{F1DA}",
            -- icon_func
            label = _("History"),
            -- label_func
            -- active_func
            -- visible_func
            help_text = _("Tap : Show history\nHold : Open last book"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ShowHist"))
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("OpenLastDoc"))
            end
        },
        resume = {
            icon = "\u{F04B}",
            -- icon_func
            label = _("Resume"),
            label_func = function(ctx)
                return G_reader_settings:readSetting("lastfile") --TODO find title
            end,
            -- active_func
            -- visible_func
            help_text = _("Tap : Open last book\nHold : Show history"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("OpenLastDoc"))
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ShowHist"))
            end
        },
        collections = {
            icon = "\u{F0C9}",
            -- icon_func
            label = _("Collections"),
            -- label_func
            -- active_func
            -- visible_func
            help_text = _("Tap : Show collections\nHold : Show favorites"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ShowCollList"))
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ShowColl"))
            end
        },
        favorites = {
            icon = "\u{F005}",
            -- icon_func
            label = _("Favorites"),
            -- label_func
            -- active_func
            -- visible_func
            help_text = _("Tap : Show favorites\nHold : Show collections"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ShowColl"))
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ShowCollList"))
            end
        },
        -- core plugin
        cloud = {
            icon = "\u{F0C2}",
            -- icon_func
            label = _("Cloud"),
            -- label_func
            -- active_func
            -- visible_func
            help_text = _("Tap : Show cloud storage\nHold : Show OPDS catalog"),
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
            icon = "\u{F0ED}",
            -- icon_func
            label = _("OPDS"),
            -- label_func
            -- active_func
            help_text = _("Tap : Show OPDS catalog\nHold : Show cloud storage"),
            visible_func = function(ctx) return Utils.hasPlugin and Utils.hasPlugin("opds") end,
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
            icon = "\u{EA17}", -- lan-connect
            icon_func = function(ctx)
                if Util.pathExists("/tmp/dropbear_koreader.pid") then return "\u{EA17}" end -- lan-connect
                return "\u{EA18}" -- lan-disconnect
            end,
            label = _("SSH"),
            -- label_func TODO
            active_func = function(ctx) return Util.pathExists("/tmp/dropbear_koreader.pid") end,
            visible_func = function(ctx) return Utils.hasPlugin and Utils.hasPlugin("SSH") end,
            help_text = _("Tap : Toggle SSH server\nHold : Nothing"),
            callback = function(ctx)
                if Utils.hasPlugin and Utils.hasPlugin("SSH") then
                    UIManager:broadcastEvent(Event:new("ToggleSSHServer"))
                    UIManager:scheduleIn(2, function() ctx.touch_menu:updateItems(1) end)
                else UIManager:show(InfoMessage:new{ text = "SSH : " .. _("Plugin not activated.") }) end
            end,
            hold_callback = function(ctx) ctx.touch_menu:closeMenu(); UIManager:show(InfoMessage:new{ text =  _("Nothing to do") }) end
        },
        calibre = {
            icon = "\u{EB8C}", -- server-network
            icon_func = function(ctx)
                local CW = package.loaded["wireless"]
                if CW ~= nil and CW.calibre_socket ~= nil then return "\u{EB8C}" end -- server-network
                return "\u{EB8D}" -- server-network-off
            end,
            label = "Calibre",
            -- label_func TODO
            active_func = function(ctx)
                local CW = package.loaded["wireless"]
                return CW ~= nil and CW.calibre_socket ~= nil
            end,
            visible_func = function(ctx) return Utils.hasPlugin and Utils.hasPlugin("calibre") end,
            help_text = _("Tap : Toggle Calibre connection\nHold : Nothing"),
            callback = function(ctx)
                if Utils.hasPlugin and Utils.hasPlugin("calibre") then
                    local CW = package.loaded["wireless"]
                    if CW and CW.calibre_socket ~= nil then UIManager:broadcastEvent(Event:new("CloseWirelessConnection"))
                    else UIManager:broadcastEvent(Event:new("StartWirelessConnection")) end
                    UIManager:scheduleIn(2, function() ctx.touch_menu:updateItems(1) end)
                else UIManager:show(InfoMessage:new{ text = "Calibre : " .. _("Plugin not activated.") }) end
            end,
            hold_callback = function(ctx) ctx.touch_menu:closeMenu(); UIManager:show(InfoMessage:new{ text =  _("Nothing to do") }) end
        },
        search = {
            icon = "\u{F002}",
            -- icon_func
            label = _("Search"),
            -- label_func
            -- active_func
            -- visible_func
            help_text = _("Tap : Show file search\nHold : Show Calibre search"),
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
            icon = "\u{F00E}",
            -- icon_func
            label = "Calibre",
            -- label_func
            -- active_func
            visible_func = function(ctx) return Utils.hasPlugin and Utils.hasPlugin("calibre") end,
            help_text = _("Tap : Show Calibre search\nHold : Show file search"),
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
            icon = "\u{F200}",
            -- icon_func
            label = _("Statistics"),
            -- label_func
            -- active_func
            visible_func = function(ctx) return Utils.hasPlugin and Utils.hasPlugin("statistics") end,
            help_text = _("Tap : Show reader statistics\nHold : Show calendar statistics"),
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
            icon = "\u{F073}",
            -- icon_func
            label = _("Calendar"),
            -- label_func
            -- active_func
            visible_func = function(ctx) return Utils.hasPlugin and Utils.hasPlugin("statistics") end,
            help_text = _("Tap : Show calendar statistics\nHold : Show reader statistics"),
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
            icon = "\u{E866}",
            -- icon_func
            label = _("KOSync"),
            -- label_func
            -- active_func
            visible_func = function(ctx) return Utils.hasPlugin and Utils.hasPlugin("kosync") end,
            help_text = _("Tap : Push progress to KOSync\nHold : Pull progress from KOSync"),
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
            icon = "\u{005A}",
            -- icon_func
            label = _("Z-Lib"),
            -- label_func
            -- active_func
            visible_func = function(ctx) return Utils.hasPlugin and Utils.hasPlugin("zlibrary") end,
            help_text = _("Tap : Show Z-lib search\nHold : Nothing"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                UIManager:broadcastEvent(Event:new("ZlibrarySearch"))
            end,
            hold_callback = function(ctx) ctx.touch_menu:closeMenu(); UIManager:show(InfoMessage:new{ text =  _("Nothing to do") }) end
        },
        process = {
            icon = "\u{E8F9}", -- engine
            --icon_func
            label = _("Process") .. " (" .. _("MB") .. ")",
            label_func = function(ctx)
                local statm = io.open("/proc/self/statm", "r")
                if not statm then return "" end
                local ignore, rss = statm:read("*number", "*number")
                statm:close()
                -- we got the nb of 4Kb-pages used, that we convert to MiB
                return ("%d"):format(math.floor(rss * (4096 / 1024 / 1024))) .. _("MB")
            end,
            -- active_func
            -- visible_func
            help_text = _("Tap : Nothing\nHold : Nothing"),
            -- callback
            -- hold_callback
        },
        cpuusedp = {
            icon = "\u{ED19}",
            --icon_func
            label = _("CPU") .. " (%)",
            label_func = function(ctx) return ctx.stat and ctx.stat.cpu and ctx.stat.cpu.usedp and string.format("%d%%", ctx.stat.cpu.usedp) or "" end,
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.cpu and ctx.stat.cpu.usedp end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.cpu and ctx.stat.cpu.usedp and string.format(_("CPU used %d%%"), ctx.stat.cpu.usedp) or "" })
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        memusedp = {
            icon = "\u{EA5A}",
            --icon_func
            label = _("Memory") .. " " .. _("used") .. " (%)",
            label_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.usedp and string.format("%d%%", ctx.stat.memory.usedp) or "" end,
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.usedp end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.memory and ctx.stat.memory.usedp and string.format(_("Memory used %d%%"), ctx.stat.memory.usedp) or "" })
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end,
        },
        memavailablep = {
            icon = "\u{EA5A}",
            --icon_func
            label = _("Memory") .. " " .. _("available") .. " (%)",
            label_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.availablep and string.format("%d%%", ctx.stat.memory.availablep) or "" end,
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.availablep end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.memory and ctx.stat.memory.availablep and string.format(_("Memory available %d%%"), ctx.stat.memory.availablep) or "" })
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        memused = {
            icon = "\u{EA5A}",
            --icon_func
            label = _("Memory") .. " " .. _("used") .. " (" .. _("MB") .. ")",
            label_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.used and string.format("%d", math.floor((ctx.stat.memory.used) / 1024)) .. _("MB") or "" end,
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.used end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.memory and ctx.stat.memory.used and string.format(_("Memory used %d MB"), math.floor(ctx.stat.memory.used / 1024)) or "" })
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        memavailable = {
            icon = "\u{EA5A}",
            --icon_func
            label = _("Memory") .. " " .. _("available") .. " (" .. _("MB") .. ")",
            label_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.available and string.format("%d", math.floor((ctx.stat.memory.available) / 1024)) .. _("MB") or "" end,
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.available end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.memory and ctx.stat.memory.available and string.format(_("Memory available %d MB"), math.floor(ctx.stat.memory.available / 1024)) or "" })
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        memtotal = {
            icon = "\u{EA5A}",
            --icon_func
            label = _("Memory") .. " " .. _("total") .. " (" .. _("MB") .. ")",
            label_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.total and string.format("%d", math.floor(ctx.stat.memory.total / 1024)) .. _("MB") or "" end,
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.total end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.memory and ctx.stat.memory.total and string.format(_("Memory total %d MB"), math.floor(ctx.stat.memory.total / 1024)) or "" })
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        storageusedp = {
            icon = "\u{F0C7}",
            --icon_func
            label = _("Storage") .. " " .. _("used") .. " (%)",
            label_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.usedp and string.format("%d%%", ctx.stat.storage.usedp) or "" end,
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.usedp end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.storage and ctx.stat.storage.usedp and string.format(_("Storage used %d%%"), ctx.stat.storage.usedp) or "" })
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        storageavailablep = {
            icon = "\u{F0C7}",
            --icon_func
            label = _("Storage") .. " " .. _("available") .. " (%)",
            label_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.availablep and string.format("%d%%", ctx.stat.storage.availablep) or "" end,
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.availablep end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.storage and ctx.stat.storage.availablep and string.format(_("Storage available %d%%"), ctx.stat.storage.availablep) or "" })
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        storageused = {
            icon = "\u{F0C7}",
            --icon_func
            label = _("Storage") .. " " .. _("used") .. " (" .. _("GB") .. ")",
            label_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.used and string.format("%d", math.floor((ctx.stat.storage.used) / 1024 / 1024)) .. _("GB") or "" end,
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.used end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.storage and ctx.stat.storage.used and string.format(_("Storage used %d GB"), math.floor(ctx.stat.storage.used / 1024 / 1024)) or "" })
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        storageavailable = {
            icon = "\u{F0C7}",
            --icon_func
            label = _("Storage") .. " " .. _("available") .. " (" .. _("GB") .. ")",
            label_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.available and string.format("%d", math.floor((ctx.stat.storage.available) / 1024 / 1024)) .. _("GB") or "" end,
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.available end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.storage and ctx.stat.storage.available and string.format(_("Storage available %d GB"), math.floor(ctx.stat.storage.available / 1024 / 1024)) or "" })
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        storagetotal = {
            icon = "\u{F0C7}",
            --icon_func
            label = _("Storage") .. " " .. _("total") .. " (" .. _("GB") .. ")",
            label_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.total and string.format("%d", math.floor(ctx.stat.storage.total / 1024 / 1024)) .. _("GB") or "" end,
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.total end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.storage and ctx.stat.storage.total and string.format(_("Storage total %d GB"), math.floor(ctx.stat.storage.total / 1024 / 1024)) or "" })
            end,
            hold_callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        time = {
            icon = "\u{F017}",
            -- icon_func
            label = _("Time"),
            label_func = function(ctx)
                return ctx.datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock"))
            end,
            -- active_func
            -- visible_func
            help_text = _("Tap : Show time\nHold : Nothing"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{
                    text = ctx.datetime.secondsToDateTime(nil, nil, true),
                })
            end,
            -- hold_callback
        },
        battery = {
            icon = "\u{E790}",
            icon_func = function(ctx)
                local batt_lvl = ctx.powerd:getCapacity()
                return ctx.powerd:getBatterySymbol(ctx.powerd:isCharged(), ctx.powerd:isCharging(), batt_lvl)
            end,
            label = _("Battery") .. " ⌁",
            label_func = function(ctx)
                return ("%d%%"):format(ctx.powerd:getCapacity())
            end,
            -- active_func
            visible_func = function(ctx) return ctx.device:hasBattery() end,
            help_text = _("Tap : Show battery statistics\nHold : Nothing"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("batterystat") then UIManager:broadcastEvent(Event:new("ShowBatteryStatistics"))
                else UIManager:show(InfoMessage:new{ text = _("batterystat)") .. " : " .. _("Plugin not activated.") }) end
            end
            -- hold_callback
        },
        auxbattery = {
            icon = "\u{E78E}",
            icon_func = function(ctx)
                local aux_batt_lvl = ctx.powerd:getAuxCapacity()
                return ctx.powerd:getBatterySymbol(ctx.powerd:isAuxCharged(), ctx.powerd:isAuxCharging(), aux_batt_lvl)
            end,
            label = _("Battery") .. " +",
            label_func = function(ctx)
                return ("%d%%"):format(ctx.powerd:getAuxCapacity())
            end,
            -- active_func
            visible_func = function(ctx)
                return ctx.device:hasAuxBattery() and ctx.powerd:isAuxBatteryConnected()
            end,
            help_text = _("Tap : Show battery statistics\nHold : Nothing"),
            callback = function(ctx)
                ctx.touch_menu:closeMenu()
                if Utils.hasPlugin and Utils.hasPlugin("batterystat") then UIManager:broadcastEvent(Event:new("ShowBatteryStatistics"))
                else UIManager:show(InfoMessage:new{ text = _("batterystat)") .. " : " .. _("Plugin not activated.") }) end
            end
            -- hold_callback
        }
    }
end

return ActionDefs
