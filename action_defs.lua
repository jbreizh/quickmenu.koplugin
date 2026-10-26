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

local Utils            = require("utils")
local _                = require("locale/i18n").gettext

local ActionDefs = {}

local WIDTHFACTOR = 0.5

local category_label = {
    ["system"]   = _("System"),
    ["network"]  = _("Network"),
    ["power"]    = _("Power"),
    ["search"]   = _("Search"),
    ["shortcut"] = _("Shortcut"),
    ["footer"]   = _("Footer"),
    ["custom"]   = _("Custom"),
    ["other"]    = _("Other"),
}

function ActionDefs.getCategoryLabel(category)
    return category_label[category] or _("Other")
end

function ActionDefs.getSorted(action_list)
    local sorted_list = {}

    -- On parcourt directement la table passée en paramètre
    for id, def in pairs(action_list) do
        table.insert(sorted_list, {
            id = id,
            label = def.label or _("None"),
            text = def.text or "",
            icon = def.icon or "",
            def = def
        })
    end

    Utils.sort_by_field(sorted_list, "label", true, true)

    return sorted_list
end

function ActionDefs.getMerged(action_list)
    local action_system = ActionDefs.get()
    if action_list then
        for i, action in ipairs(action_list) do
            if action.id then action_system[action.id] = action end
        end
    end
    return action_system
end

local function is_localsend_active()
    local f = io.open("/tmp/localsend_koreader.pid", "r")
    if f then f:close(); return true end
    return false
end

local function is_calibre_active()
    local CW = package.loaded["wireless"]
    return CW ~= nil and CW.calibre_socket ~= nil
end

local function is_filebrowserplus_active()
    return Util.pathExists("/tmp/filebrowserplus_koreader.pid")
end

local function is_ssh_active()
    return Util.pathExists("/tmp/dropbear_koreader.pid")
end

function ActionDefs.get()
    return {
        wifi = {
            icon = "qm_wifi_on",
            icon_func =  function(ctx)
                if NetworkMgr:isWifiOn() then return "qm_wifi_on" end
                return "qm_wifi_off"
            end,
            text = "\u{ECA8}", --"\u{F1EB}"
            text_func =  function(ctx)
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
            category = "system",
            active_func = function(ctx) return NetworkMgr:isWifiOn() end,
            -- visible_func
            help_text = _("Tap : Toggle wifi\nHold : Show wifi picker"),
            callback = function(ctx)
                if NetworkMgr:isWifiOn() then NetworkMgr:toggleWifiOff()
                else NetworkMgr:toggleWifiOn() end
                Utils.updateMenu(ctx.touch_menu, {delay = 1})
            end,
            hold_callback = function(ctx)
                local function do_connect()
                    NetworkMgr:toggleWifiOn(function()
                        Utils.updateMenu(ctx.touch_menu, {delay = 0.5})
                    end, true, true)
                end
                if NetworkMgr:isWifiOn() then NetworkMgr:toggleWifiOff(do_connect, true)
                else do_connect() end
            end
        },
        night = {
            icon = "qm_night_on",
            icon_func = function(ctx)
                if G_reader_settings:isTrue("night_mode") then return "qm_night_on" end
                return "qm_night_off"
            end,
            text = "\u{EC0D}", -- theme-light-dark
            text_func = function(ctx)
                if G_reader_settings:isTrue("night_mode") then return "\u{EC93}" end -- weather-night
                return "\u{EC98}" -- weather-sunny
            end,
            label = _("Night"),
            label_func = function(ctx)
                if G_reader_settings:isTrue("night_mode") then return _("Night") end
                return _("Day")
            end,
            category = "system",
            active_func = function(ctx) return G_reader_settings:isTrue("night_mode") end,
            -- visible_func
            help_text = _("Tap : Toggle night mode\nHold : Nothing"),
            callback = function(ctx)
                UIManager:broadcastEvent(Event:new("ToggleNightMode"))
                Utils.updateMenu(ctx.touch_menu, {delay = 0})
            end,
            hold_callback = function(ctx) Utils.closeMenu(ctx.touch_menu); UIManager:show(InfoMessage:new{ text =  _("Nothing to do") }) end
        },
        light = {
            icon = "qm_light_on",
            icon_func = function(ctx)
            if ctx.powerd:isFrontlightOn() then return "qm_light_on" end
                return "qm_light_off"
            end,
            text = "\u{EA2B}", -- led-on
            text_func = function(ctx)
            if ctx.powerd:isFrontlightOn() then return "\u{EA2B}" end -- led-on
                return "\u{EA2D}" -- led-variant-off "\u{EA2A}"
            end,
            label = _("Light"),
            label_func = function(ctx)
                if not ctx.powerd:isFrontlightOn() then return _("Off") end
                return ("%d/%d"):format(ctx.powerd:frontlightIntensity(),ctx.powerd.fl_max)
            end,
            category = "system",
            active_func = function(ctx) return ctx.powerd:isFrontlightOn() end,
            visible_func = function(ctx) return ctx.device:hasFrontlight() end,
            help_text = _("Tap : Toggle frontlight\nHold : Show frontlight dialog"),
            callback = function(ctx)
                UIManager:broadcastEvent(Event:new("ToggleFrontlight"))
                Utils.updateMenu(ctx.touch_menu, {delay = 0}) -- need instant update
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowFlDialog"))
            end
        },
        warmth = {
            icon = "qm_warmth_on",
            icon_func = function(ctx)
                if not ctx.powerd:isFrontlightOn() or ctx.powerd:frontlightWarmth() == 0 then return "qm_warmth_on" end
                return "qm_warmth_off"
            end,
            text = "\u{F490}", -- flame
            text_func = function(ctx)
                if not ctx.powerd:isFrontlightOn() or ctx.powerd:frontlightWarmth() == 0 then return "\u{F2DC}" end -- frozen
                return "\u{F490}" -- flamme
            end,
            label = _("Warmth"),
            label_func = function(ctx)
                if not ctx.powerd:isFrontlightOn() or ctx.powerd:frontlightWarmth() == 0 then return _("Off") end
                return ("%d/%d"):format(ctx.powerd:toNativeWarmth(ctx.powerd:frontlightWarmth()), ctx.powerd.fl_warmth_max)
            end,
            category = "system",
            active_func = function(ctx) return ctx.powerd:isFrontlightOn() and ctx.powerd:frontlightWarmth() ~= 0 end,
            visible_func = function(ctx) return ctx.device:hasFrontlight() and ctx.device:hasNaturalLight() end,
            help_text = _("Tap : Nothing\nHold : Show frontlight dialog"),
            callback = function(ctx) Utils.closeMenu(ctx.touch_menu); UIManager:show(InfoMessage:new{ text =  _("Nothing to do") }) end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowFlDialog"))
            end
        },
        rotate = {
            icon = "qm_rotate",
            -- icon_func
            text = "\u{EB74}",
            -- text_func
            label = _("Rotate"),
            label_func =  function(ctx)
                local rot = ctx.device.screen:getRotationMode()
                if     rot == 1 then return "90°" -- 90°
                elseif rot == 2 then return "180°" -- 180°
                elseif rot == 3 then return "270°" -- 270°
                else                 return "0°" -- 0°
                end
            end,
            category = "system",
            -- active_func
            -- visible_func
            help_text = _("Tap : Swap rotation\nHold : Invert rotation"),
            callback = function(ctx) UIManager:broadcastEvent(Event:new("SwapRotation")) end,
            hold_callback = function(ctx) UIManager:broadcastEvent(Event:new("InvertRotation")) end
        },
        lock = {
            icon = "qm_lock_on",
            icon_func =  function(ctx)
                if G_reader_settings:isTrue("input_lock_gsensor") or G_reader_settings:isTrue("input_ignore_gsensor") then return "qm_lock_on" end
                return "qm_lock_off"
            end,
            text = "\u{F023}",
            text_func =  function(ctx)
                if G_reader_settings:isTrue("input_lock_gsensor") or G_reader_settings:isTrue("input_ignore_gsensor") then return "\u{F023}" end
                return "\u{F09C}"
            end,
            label = _("Lock"),
            label_func = function(ctx)
                if G_reader_settings:isTrue("input_lock_gsensor") or G_reader_settings:isTrue("input_ignore_gsensor") then return _("Lock") end
                return _("Unlock")
            end,
            category = "system",
            visible_func = function(ctx) return ctx.device:hasGSensor() end,
            active_func = function(ctx) return G_reader_settings:isTrue("input_lock_gsensor") or G_reader_settings:isTrue("input_ignore_gsensor") end,
            help_text = _("Tap : Toggle lock gsensor\nHold : Toggle ignore gsensor"),
            callback = function(ctx)
                if G_reader_settings:isTrue("input_ignore_gsensor") then
                    UIManager:broadcastEvent(Event:new("ToggleGSensor"))
                    if G_reader_settings:isTrue("input_lock_gsensor") then UIManager:broadcastEvent(Event:new("LockGSensor")) end
                else UIManager:broadcastEvent(Event:new("LockGSensor")) end
                Utils.updateMenu(ctx.touch_menu, {delay = 0})
            end,
            hold_callback = function(ctx)
                if G_reader_settings:isTrue("input_lock_gsensor") then
                    UIManager:broadcastEvent(Event:new("LockGSensor"))
                    if G_reader_settings:isTrue("input_ignore_gsensor") then UIManager:broadcastEvent(Event:new("ToggleGSensor")) end
                else UIManager:broadcastEvent(Event:new("ToggleGSensor")) end
                Utils.updateMenu(ctx.touch_menu, {delay = 0})
            end
        },
        usb = {
            icon = "qm_usb_storage",
            -- icon_func
            text = "\u{F287}",
            -- text_func
            label = _("USB"),
            -- label_func
            category = "system",
            -- active_func
            help_text = _("Tap : Request UBS mass storage\nHold : Nothing"),
            visible_func = function(ctx) return ctx.device.canToggleMassStorage and ctx.device:canToggleMassStorage() end,
            callback = function(ctx) UIManager:broadcastEvent(Event:new("RequestUSBMS")) end,
            hold_callback = function(ctx) Utils.closeMenu(ctx.touch_menu); UIManager:show(InfoMessage:new{ text =  _("Nothing to do") }) end
        },
        restart = {
            icon = "qm_power_restart",
            -- icon_func
            text = "\u{F021}",
            -- text_func
            label = _("Restart"),
            -- label_func
            category = "power",
            -- active_func
            -- visible_func
            help_text = _("Tap : Ask for restart KOreader\nHold : Ask for exit KOreader"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:show(ConfirmBox:new{
                    text = _("Are you sure you want to restart KOReader ?"),
                    ok_text = _("Restart"),
                    ok_callback = function() UIManager:broadcastEvent(Event:new("Restart")) end
                })
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:show(ConfirmBox:new{
                    text = _("Are you sure you want to exit KOReader ?"),
                    ok_text = _("Exit"),
                    ok_callback = function() UIManager:broadcastEvent(Event:new("Exit")) end
                })
            end,
        },
        exit = {
            icon = "qm_power_exit",
            -- icon_func
            text = "\u{274C}",
            -- text_func
            label = _("Exit"),
            -- label_func
            category = "power",
            -- active_func
            -- visible_func
            help_text = _("Tap : Ask for exit KOreader\nHold : Ask for restart KOreader"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:show(ConfirmBox:new{
                    text = _("Are you sure you want to exit KOReader ?"),
                    ok_text = _("Exit"),
                    ok_callback = function() UIManager:broadcastEvent(Event:new("Exit")) end
                })
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:show(ConfirmBox:new{
                    text = _("Are you sure you want to restart KOReader ?"),
                    ok_text = _("Restart"),
                    ok_callback = function() UIManager:broadcastEvent(Event:new("Restart")) end
                })
            end,
        },
        reboot = {
            icon = "qm_power_reboot",
            -- icon_func
            text = "\u{F01E}",
            -- text_func
            label = _("Reboot"),
            -- label_func
            category = "power",
            -- active_func
            visible_func = function(ctx) return ctx.device:canReboot() end,
            help_text = _("Tap : Ask for reboot system\nHold : Ask for power off system"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if ctx.device:canReboot() then
                    UIManager:askForReboot()
                else
                    UIManager:show(InfoMessage:new{ text =  _("Reboot") .. " : " .. _("Not possible") })
                end
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if ctx.device:canPowerOff() then
                    UIManager:askForPowerOff()
                else
                    UIManager:show(InfoMessage:new{ text =  _("Power off") .. " : " .. _("Not possible") })
                end
            end,
        },
        sleep = {
            icon = "qm_power_sleep",
            -- icon_func
            text = "\u{EBB1}", -- sleep
            -- text_func
            label = _("Sleep"),
            -- label_func
            category = "power",
            -- active_func
            visible_func = function(ctx) return ctx.device:canSuspend() end,
            help_text = _("Tap : Suspend system\nHold : Nothing"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if ctx.device:canSuspend() then
                    UIManager:broadcastEvent(Event:new("RequestSuspend"))
                else
                    UIManager:show(InfoMessage:new{ text =  _("Sleep") .. " : " .. _("Not possible") })
                end
            end,
            hold_callback = function(ctx) Utils.closeMenu(ctx.touch_menu); UIManager:show(InfoMessage:new{ text =  _("Nothing to do") }) end
        },
        poweroff = {
            icon = "qm_power",
            -- icon_func
            text = "\u{F011}",
            -- text_func
            label = _("Power off"),
            -- label_func
            category = "power",
            -- active_func
            visible_func = function(ctx) return ctx.device:canPowerOff() end,
            help_text = _("Tap : Ask for power off system\nHold : Ask for reboot system"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if ctx.device:canPowerOff() then
                    UIManager:askForPowerOff()
                else
                    UIManager:show(InfoMessage:new{ text =  _("Power off") .. " : " .. _("Not possible") })
                end
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if ctx.device:canReboot() then
                    UIManager:askForReboot()
                else
                    UIManager:show(InfoMessage:new{ text =  _("Reboot") .. " : " .. _("Not possible") })
                end
            end,
        },
        power = {
            icon = "qm_power",
            -- icon_func
            text = "\u{F011}",
            -- text_func
            label = _("Power"),
            -- label_func
            category = "power",
            -- active_func
            -- visible_func
            help_text = _("Tap : Show power dialog\nHold : Nothing"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                local dialog

                local function close(fn)
                    return function()
                        if dialog then UIManager:close(dialog) end
                        if fn then fn() end
                    end
                end

                local buttons = {}

                if ctx.device:canRestart() then
                    table.insert(buttons, {{
                        text = _("Restart") .. " " .. "KOReader" .. "\xE2\x80\xA6",
                        callback = close(function()
                            UIManager:show(ConfirmBox:new{
                                text = _("Are you sure you want to restart KOReader ?"),
                                ok_text = _("Restart"),
                                ok_callback = function() UIManager:broadcastEvent(Event:new("Restart")) end
                            })
                        end)
                    }})
                end
                table.insert(buttons, {{
                    text = _("Exit") .. " " .. "KOreader" .. "\xE2\x80\xA6",
                    callback = close(function()
                        UIManager:show(ConfirmBox:new{
                            text = _("Are you sure you want to exit KOReader ?"),
                            ok_text = _("Exit"),
                            ok_callback = function() UIManager:broadcastEvent(Event:new("Exit")) end
                        })
                    end)
                }})
                if ctx.device:canReboot() then
                    table.insert(buttons, {{
                        text = _("Reboot") .. "\xE2\x80\xA6",
                        callback = close(function()
                            UIManager:askForReboot()
                        end)
                    }})
                end
                if ctx.device:canSuspend() then
                    table.insert(buttons, {{
                        text = _("Sleep"),
                        callback = close(function()
                            UIManager:suspend()
                        end)
                    }})
                end
                if ctx.device:canPowerOff() then
                    table.insert(buttons, {{
                        text = _("Power off") .. "\xE2\x80\xA6",
                        callback = close(function()
                            UIManager:askForPowerOff()
                        end)
                    }})
                end

                table.insert(buttons, {}) -- separator

                table.insert(buttons, {{
                    text = _("Exit"),
                    callback = close()
                }})

                dialog = ButtonDialog:new{
                    title        = "\u{F011}" .. " " .. _("Power") .. " :",
                    title_align  = "left",
                    width_factor =  WIDTHFACTOR,
                    buttons      = buttons,
                    tap_close_callback = close()
                }
                UIManager:show(dialog)
            end,
            hold_callback = function(ctx) Utils.closeMenu(ctx.touch_menu); UIManager:show(InfoMessage:new{ text =  _("Nothing to do") }) end
        },
        dictionary = {
            icon = "qm_search_dictionary",
            -- icon_func
            text = "\u{F02D}",
            -- text_func
            label = _("Dictionary"),
            -- label_func
            category = "search",
            -- active_func
            -- visible_func
            help_text = _("Tap : Show dictionary search\nHold : Show wikipedia search"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowDictionaryLookup"))
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowWikipediaLookup"))
            end
        },
        wikipedia = {
            icon = "qm_search_wikipedia",
            -- icon_func
            text = "\u{F266}",
            -- text_func
            label = _("Wikipedia"),
            -- label_func
            category = "search",
            -- active_func
            -- visible_func
            help_text = _("Tap : Show wikipedia search\nHold : Show dictionary search"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowWikipediaLookup"))
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowDictionaryLookup"))
            end
        },
        history = {
            icon = "qm_history",
            -- icon_func
            text = "\u{F1DA}",
            -- text_func
            label = _("History"),
            -- label_func
            category = "shortcut",
            -- active_func
            -- visible_func
            help_text = _("Tap : Show history\nHold : Open last book"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowHist"))
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("OpenLastDoc"))
            end
        },
        resume = {
            icon = "qm_resume",
            -- icon_func
            text = "\u{F04B}",
            -- text_func
            label = _("Resume"),
            --  label_func
            category = "shortcut",
            -- active_func
            -- visible_func
            help_text = _("Tap : Open last book\nHold : Show history"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("OpenLastDoc"))
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowHist"))
            end
        },
        collections = {
            icon = "qm_collections",
            -- icon_func
            text = "\u{F0C9}",
            -- text_func
            label = _("Collections"),
            -- label_func
            category = "shortcut",
            -- active_func
            -- visible_func
            help_text = _("Tap : Show collections\nHold : Show favorites"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowCollList"))
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowColl"))
            end
        },
        favorites = {
            icon = "qm_favorites",
            -- icon_func
            text = "\u{F005}",
            -- text_func
            label = _("Favorites"),
            -- label_func
            category = "shortcut",
            -- active_func
            -- visible_func
            help_text = _("Tap : Show favorites\nHold : Show collections"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowColl"))
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowCollList"))
            end
        },
        cloud = {
            icon = "qm_cloud",
            -- icon_func
            text = "\u{F0C2}",
            -- text_func
            label = _("Cloud"),
            -- label_func
            category = "network",
            -- active_func
            -- visible_func
            help_text = _("Tap : Show cloud storage\nHold : Show OPDS catalog"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowCloudStorage"))
                end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if Utils.hasPlugin("opds") then UIManager:broadcastEvent(Event:new("ShowOPDSCatalog"))
                else UIManager:show(InfoMessage:new{ text = "OPDS : " .. _("Plugin not activated.") }) end
            end
        },
        opds = {
            icon = "qm_opds",
            -- icon_func
            text = "\u{F0ED}",
            -- text_func
            label = _("OPDS"),
            -- label_func
            category = "network",
            -- active_func
            help_text = _("Tap : Show OPDS catalog\nHold : Show cloud storage"),
            visible_func = function(ctx) return Utils.hasPlugin("opds") end,
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowOPDSCatalog"))
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowCloudStorage"))
            end
        },
        ssh = {
            icon = "qm_ssh_on", -- lan-connect -- lan-disconnect
            icon_func = function(ctx) return is_ssh_active() and "qm_ssh_on" or "qm_ssh_off" end,
            text = "\u{EA17}", -- lan-connect -- lan-disconnect
            text_func = function(ctx) return is_ssh_active() and "\u{EA17}" or "\u{EA18}" end,
            label = _("SSH"),
            label_func = function(ctx) return is_ssh_active() and _("On") or _("Off") end,
            category = "network",
            active_func = function(ctx) return is_ssh_active() end,
            visible_func = function(ctx) return Utils.hasPlugin("SSH") end,
            help_text = _("Tap : Toggle SSH server\nHold : Nothing"),
            callback = function(ctx)
                UIManager:broadcastEvent(Event:new("ToggleSSHServer")) -- SSH doesn't need connection
                Utils.updateMenu(ctx.touch_menu, {delay = 1})
            end,
            hold_callback = function(ctx) Utils.closeMenu(ctx.touch_menu); UIManager:show(InfoMessage:new{ text =  _("Nothing to do") }) end
        },
        calibre = {
            icon = "qm_calibre_on", -- server-network -- server-network-off
            icon_func = function(ctx) return is_calibre_active() and "qm_calibre_on" or "qm_calibre_off" end,
            text = "\u{EB8C}", -- server-network -- server-network-off
            text_func = function(ctx) return is_calibre_active() and "\u{EB8C}" or "\u{EB8D}" end,
            label = "Calibre",
            label_func = function(ctx) return is_calibre_active() and _("On") or _("Off") end,
            category = "network",
            active_func = function(ctx) return is_calibre_active() end,
            visible_func = function(ctx) return Utils.hasPlugin("calibre") end,
            help_text = _("Tap : Toggle Calibre connection\nHold : Nothing"),
            callback = function(ctx)
                NetworkMgr:runWhenOnline(function() -- check connection
                    local event = is_calibre_active() and "CloseWirelessConnection" or "StartWirelessConnection"
                    UIManager:broadcastEvent(Event:new(event))
                    Utils.updateMenu(ctx.touch_menu, {delay = 2})
                end)
            end,
            hold_callback = function(ctx) Utils.closeMenu(ctx.touch_menu); UIManager:show(InfoMessage:new{ text = _("Nothing to do") }) end
        },
        kosync = {
            icon = "qm_kosync",
            -- icon_func
            text = "\u{ED3E}",
            -- text_func
            label = _("KOSync"),
            -- label_func
            category = "network",
            -- active_func
            visible_func = function(ctx) return Utils.hasPlugin("kosync") end,
            help_text = _("Tap : Push progress to KOSync\nHold : Pull progress from KOSync"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                NetworkMgr:runWhenOnline(function() -- check connection once
                    UIManager:broadcastEvent(Event:new("KOSyncPullProgress"))
                    -- Push after a short delay to let the pull complete first.
                    UIManager:scheduleIn(1, function() UIManager:broadcastEvent(Event:new("KOSyncPushProgress")) end)
                end)
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                local dialog

                local function close(fn)
                    return function()
                        if dialog then UIManager:close(dialog) end
                        if fn then fn() end
                    end
                end

                local buttons = {
                {{
                    text = _("Push progress") .. "\xE2\x80\xA6",
                    callback = close(function()
                        UIManager:broadcastEvent(Event:new("KOSyncPushProgress")) -- already check connection
                    end)
                }},
                {{
                    text = _("Pull progress") .. "\xE2\x80\xA6",
                    callback = close(function()
                        UIManager:broadcastEvent(Event:new("KOSyncPullProgress"))-- already check connection
                    end)
                }},
                {}, -- separator
                {{
                    text = _("Exit"),
                    callback = close()
                }},
                }

                dialog = ButtonDialog:new{
                    title        = "\u{ED3E}" .. " " .. _("KOSync") .. " :",
                    title_align  = "left",
                    width_factor =  WIDTHFACTOR,
                    buttons      = buttons,
                    tap_close_callback = close()
                }
                UIManager:show(dialog)
            end,
        },
        localsend = {
            icon = "qm_localsend_on",
            icon_func = function(ctx) return is_localsend_active() and "qm_localsend_on" or "qm_localsend_off" end,
            text = "\u{F1D8}",
            text_func = function(ctx) return is_localsend_active() and "\u{F1D9}" or "\u{F1D8}" end,
            label = "LocalSend",
            label_func = function(ctx) return is_localsend_active() and _("On") or _("Off") end,
            category = "network",
            visible_func = function(ctx) return Utils.hasPlugin("localsend") end,
            help_text = _("Tap : Toggle LocalSend connection\nHold : Show localSend dialog"),
            active_func = function(ctx) return is_localsend_active() end,
            callback = function(ctx)
                NetworkMgr:runWhenOnline(function() -- check connection
                    UIManager:broadcastEvent(Event:new("ToggleLocalSend"))
                    Utils.updateMenu(ctx.touch_menu, {delay = 1})
                end)
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                local dialog

                local function close(fn)
                    return function()
                        if dialog then UIManager:close(dialog) end
                        if fn then fn() end
                    end
                end

                local buttons = {
                {{
                    text = _("Send file") .. "\xE2\x80\xA6",
                    callback = close(function()
                        UIManager:broadcastEvent(Event:new("ShowLocalSendFileSendFlow"))
                    end)
                }},
                {{
                    text = _("Send current book"),
                    callback = close(function()
                        UIManager:broadcastEvent(Event:new("SendCurrentBookWithLocalSend"))
                    end)
                }},
                {}, -- separator
                {{
                    text = _("Exit"),
                    callback = close()
                }},
                }

                dialog = ButtonDialog:new{
                    title        = "\u{F1D8}" .. " " .. "LocalSend" .. " :",
                    title_align  = "left",
                    width_factor =  WIDTHFACTOR,
                    buttons      = buttons,
                    tap_close_callback = close()
                }
                UIManager:show(dialog)
            end,
        },
        filebrowserplus = {
            icon = "qm_filebrowserplus_on",
            icon_func = function(ctx) return is_filebrowserplus_active() and "qm_filebrowserplus_on" or "qm_filebrowserplus_off" end,
            text = "\u{F15C}",
            text_func = function(ctx) return is_filebrowserplus_active() and "\u{F0F6}" or "\u{F15C}" end,
            label = "FileBrowserPlus",
            label_func = function(ctx) return is_filebrowserplus_active() and _("On") or _("Off") end,
            category = "network",
            visible_func = function() return Utils.hasPlugin("filebrowserplus") end,
            help_text = _("Tap : Toggle FileBrowserPlus connection\nHold : Nothing"),
            active_func = function(ctx) return is_filebrowserplus_active() end,
            callback = function(ctx)
                NetworkMgr:runWhenOnline(function() -- check connection
                    UIManager:broadcastEvent(Event:new("ToggleFilebrowserPlusServer"))
                    Utils.updateMenu(ctx.touch_menu, {delay = 1})
                end)
            end,
            hold_callback = function(ctx) Utils.closeMenu(ctx.touch_menu); UIManager:show(InfoMessage:new{ text = _("Nothing to do") }) end
        },
        search = {
            icon = "qm_search",
            -- icon_func
            text = "\u{F002}",
            -- text_func
            label = _("Search"),
            -- label_func
            category = "search",
            -- active_func
            -- visible_func
            help_text = _("Tap : Show file search\nHold : Show Calibre search"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowFileSearch"))
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if Utils.hasPlugin("calibre") then UIManager:broadcastEvent(Event:new("CalibreSearch"))
                else UIManager:show(InfoMessage:new{ text = "Calibre : " .. _("Plugin not activated.") }) end
            end
        },
        searchcalibre = {
            icon = "qm_search_calibre",
            -- icon_func
            text = "\u{F00E}",
            -- text_func
            label = "Calibre",
            -- label_func
            category = "search",
            -- active_func
            visible_func = function(ctx) return Utils.hasPlugin("calibre") end,
            help_text = _("Tap : Show Calibre search\nHold : Show file search"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("CalibreSearch"))
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowFileSearch"))
                end
        },
        statistics = {
            icon = "qm_statistics",
            -- icon_func
            text = "\u{F200}",
            -- text_func
            label = _("Statistics"),
            -- label_func
            category = "shortcut",
            -- active_func
            visible_func = function(ctx) return Utils.hasPlugin("statistics") end,
            help_text = _("Tap : Show reader statistics\nHold : Show calendar statistics"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowReaderProgress"))
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowCalendarView"))
            end
        },
        statisticscalendar = {
            icon = "qm_statistics_calendar",
            -- icon_func
            text = "\u{F073}",
            -- text_func
            label = _("Calendar"),
            -- label_func
            category = "shortcut",
            -- active_func
            visible_func = function(ctx) return Utils.hasPlugin("statistics") end,
            help_text = _("Tap : Show calendar statistics\nHold : Show reader statistics"),
            callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowCalendarView"))
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                UIManager:broadcastEvent(Event:new("ShowReaderProgress"))
            end
        },
        process = {
            icon = "qm_process",
            --icon_func
            text = "\u{E8F9}", -- engine
            --text_func
            label = _("Process") .. " (" .. _("MB") .. ")",
            label_func = function(ctx)
                local statm = io.open("/proc/self/statm", "r")
                if not statm then return "" end
                local ignore, rss = statm:read("*number", "*number")
                statm:close()
                -- we got the nb of 4Kb-pages used, that we convert to MiB
                return ("%d"):format(math.floor(rss * (4096 / 1024 / 1024))) .. _("MB")
            end,
            category = "footer",
            -- active_func
            -- visible_func
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                local statm = io.open("/proc/self/statm", "r")
                if not statm then return "" end
                local ignore, rss = statm:read("*number", "*number")
                statm:close()
                -- we got the nb of 4Kb-pages used, that we convert to MiB
                local process_memory_p = ("%d"):format(math.floor(rss * (4096 / 1024 / 1024))) .. _("MB")
                UIManager:show(InfoMessage:new{ text = string.format(_("Process memory %s MB"),process_memory_p) })
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        cpuusedp = {
            icon = "qm_cpu",
            --icon_func
            text = "\u{ED19}",
            --text_func
            label = _("CPU") .. " (%)",
            label_func = function(ctx) return ctx.stat and ctx.stat.cpu and ctx.stat.cpu.usedp and string.format("%d%%", ctx.stat.cpu.usedp) or "" end,
            category = "footer",
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.cpu and ctx.stat.cpu.usedp end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.cpu and ctx.stat.cpu.usedp and string.format(_("CPU used %d%%"), ctx.stat.cpu.usedp) or "" })
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        memusedp = {
            icon = "qm_memory",
            --icon_func
            text = "\u{EA5A}",
            --text_func
            label = _("Memory") .. " " .. _("used") .. " (%)",
            label_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.usedp and string.format("%d%%", ctx.stat.memory.usedp) or "" end,
            category = "footer",
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.usedp end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.memory and ctx.stat.memory.usedp and string.format(_("Memory used %d%%"), ctx.stat.memory.usedp) or "" })
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end,
        },
        memavailablep = {
            icon = "qm_memory",
            --icon_func
            text = "\u{EA5A}",
            --text_func
            label = _("Memory") .. " " .. _("available") .. " (%)",
            label_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.availablep and string.format("%d%%", ctx.stat.memory.availablep) or "" end,
            category = "footer",
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.availablep end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.memory and ctx.stat.memory.availablep and string.format(_("Memory available %d%%"), ctx.stat.memory.availablep) or "" })
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        memused = {
            icon = "qm_memory",
            --icon_func
            text = "\u{EA5A}",
            --text_func
            label = _("Memory") .. " " .. _("used") .. " (" .. _("MB") .. ")",
            label_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.used and string.format("%d", math.floor((ctx.stat.memory.used) / 1024)) .. _("MB") or "" end,
            category = "footer",
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.used end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.memory and ctx.stat.memory.used and string.format(_("Memory used %d MB"), math.floor(ctx.stat.memory.used / 1024)) or "" })
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        memavailable = {
            icon = "qm_memory",
            --icon_func
            text = "\u{EA5A}",
            --text_func
            label = _("Memory") .. " " .. _("available") .. " (" .. _("MB") .. ")",
            label_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.available and string.format("%d", math.floor((ctx.stat.memory.available) / 1024)) .. _("MB") or "" end,
            category = "footer",
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.available end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.memory and ctx.stat.memory.available and string.format(_("Memory available %d MB"), math.floor(ctx.stat.memory.available / 1024)) or "" })
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        memtotal = {
            icon = "qm_memory",
            --icon_func
            text = "\u{EA5A}",
            --text_func
            label = _("Memory") .. " " .. _("total") .. " (" .. _("MB") .. ")",
            label_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.total and string.format("%d", math.floor(ctx.stat.memory.total / 1024)) .. _("MB") or "" end,
            category = "footer",
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.memory and ctx.stat.memory.total end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.memory and ctx.stat.memory.total and string.format(_("Memory total %d MB"), math.floor(ctx.stat.memory.total / 1024)) or "" })
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        storageusedp = {
            icon = "qm_storage",
            --icon_func
            text = "\u{F0C7}",
            --text_func
            label = _("Storage") .. " " .. _("used") .. " (%)",
            label_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.usedp and string.format("%d%%", ctx.stat.storage.usedp) or "" end,
            category = "footer",
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.usedp end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.storage and ctx.stat.storage.usedp and string.format(_("Storage used %d%%"), ctx.stat.storage.usedp) or "" })
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        storageavailablep = {
            icon = "qm_storage",
            --icon_func
            text = "\u{F0C7}",
            --text_func
            label = _("Storage") .. " " .. _("available") .. " (%)",
            label_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.availablep and string.format("%d%%", ctx.stat.storage.availablep) or "" end,
            category = "footer",
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.availablep end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.storage and ctx.stat.storage.availablep and string.format(_("Storage available %d%%"), ctx.stat.storage.availablep) or "" })
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        storageused = {
            icon = "qm_storage",
            --icon_func
            text = "\u{F0C7}",
            --text_func
            label = _("Storage") .. " " .. _("used") .. " (" .. _("GB") .. ")",
            label_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.used and string.format("%d", math.floor((ctx.stat.storage.used) / 1024 / 1024)) .. _("GB") or "" end,
            category = "footer",
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.used end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.storage and ctx.stat.storage.used and string.format(_("Storage used %d GB"), math.floor(ctx.stat.storage.used / 1024 / 1024)) or "" })
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        storageavailable = {
            icon = "qm_storage",
            --icon_func
            text = "\u{F0C7}",
            --text_func
            label = _("Storage") .. " " .. _("available") .. " (" .. _("GB") .. ")",
            label_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.available and string.format("%d", math.floor((ctx.stat.storage.available) / 1024 / 1024)) .. _("GB") or "" end,
            category = "footer",
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.available end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.storage and ctx.stat.storage.available and string.format(_("Storage available %d GB"), math.floor(ctx.stat.storage.available / 1024 / 1024)) or "" })
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        storagetotal = {
            icon = "qm_storage",
            --icon_func
            text = "\u{F0C7}",
            --text_func
            label = _("Storage") .. " " .. _("total") .. " (" .. _("GB") .. ")",
            label_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.total and string.format("%d", math.floor(ctx.stat.storage.total / 1024 / 1024)) .. _("GB") or "" end,
            category = "footer",
            -- active_func
            visible_func = function(ctx) return ctx.stat and ctx.stat.storage and ctx.stat.storage.total end,
            help_text = _("Tap : Show value\nHold : Show system statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{ text = ctx.stat and ctx.stat.storage and ctx.stat.storage.total and string.format(_("Storage total %d GB"), math.floor(ctx.stat.storage.total / 1024 / 1024)) or "" })
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if Utils.hasPlugin("systemstat") then UIManager:broadcastEvent(Event:new("ShowSysStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Systemstat : " .. _("Plugin not activated.") }) end
            end
        },
        time = {
            icon = "qm_time",
            -- icon_func
            text = "\u{F017}",
            -- text_func
            label = _("Time"),
            label_func = function(ctx)
                return ctx.datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock"))
            end,
            category = "footer",
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
            icon = "qm_battery",
            -- icon_func
            text = "\u{E790}",
            text_func = function(ctx)
                local batt_lvl = ctx.powerd:getCapacity()
                return ctx.powerd:getBatterySymbol(ctx.powerd:isCharged(), ctx.powerd:isCharging(), batt_lvl)
            end,
            label = _("Battery") .. " ⌁",
            label_func = function(ctx)
                return ("%d%%"):format(ctx.powerd:getCapacity())
            end,
            category = "footer",
            -- active_func
            visible_func = function(ctx) return ctx.device:hasBattery() end,
            help_text = _("Tap : Show value\nHold : Show battery statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{
                    text = ("Main battery %d%%"):format(ctx.powerd:getCapacity())
                })
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if Utils.hasPlugin("batterystat") then UIManager:broadcastEvent(Event:new("ShowBatteryStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Batterystat" .. " : " .. _("Plugin not activated.") }) end
            end
        },
        auxbattery = {
            icon = "qm_battery",
            -- icon_func
            text = "\u{E78E}",
            text_func = function(ctx)
                local aux_batt_lvl = ctx.powerd:getAuxCapacity()
                return ctx.powerd:getBatterySymbol(ctx.powerd:isAuxCharged(), ctx.powerd:isAuxCharging(), aux_batt_lvl)
            end,
            label = _("Battery") .. " +",
            label_func = function(ctx)
                return ("%d%%"):format(ctx.powerd:getAuxCapacity())
            end,
            category = "footer",
            -- active_func
            visible_func = function(ctx)
                return ctx.device:hasAuxBattery() and ctx.powerd:isAuxBatteryConnected()
            end,
            help_text = _("Tap : Show value\nHold : Show battery statistics"),
            callback = function(ctx)
                UIManager:show(InfoMessage:new{
                    text = ("Aux battery %d%%"):format(ctx.powerd:getAuxCapacity())
                })
            end,
            hold_callback = function(ctx)
                Utils.closeMenu(ctx.touch_menu)
                if Utils.hasPlugin("batterystat") then UIManager:broadcastEvent(Event:new("ShowBatteryStatistics"))
                else UIManager:show(InfoMessage:new{ text = "Batterystat" .. " : " .. _("Plugin not activated.") }) end
            end
        }
    }
end

return ActionDefs
