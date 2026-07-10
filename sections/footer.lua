local BD           = require("ui/bidi")
local ConfirmBox   = require("ui/widget/confirmbox")
local UIManager    = require("ui/uimanager")
local SortWidget   = require("ui/widget/sortwidget")
local ButtonDialog = require("ui/widget/buttondialog")
local Button          = require("ui/widget/button")

local InfoMessage  = require("ui/widget/infomessage")
local UIManager    = require("ui/uimanager")
local Event        = require("ui/event")

local ActionExec      = require("action_exec")
local ActionDefs   = require("action_defs")
local ActionManage = require("action_manage")
local Config       = require("config")
local Utils        = require("common/utils")
local _            = require("common/i18n").gettext

local Footer = {}

local SECTION = "footer"
-- ============================================================
-- Footer Builder
-- ============================================================
local function default_footer(ctx)
    local default_footer = ctx.datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock"))
    if ctx.device:hasBattery() then
        local batt_lvl = ctx.powerd:getCapacity()
        local batt_symbol = ctx.powerd:getBatterySymbol(ctx.powerd:isCharged(), ctx.powerd:isCharging(), batt_lvl)
        default_footer = BD.wrap(default_footer) .. " " .. BD.wrap("⌁") .. BD.wrap(batt_symbol) ..  BD.wrap(batt_lvl .. "%")
        if ctx.device:hasAuxBattery() and ctx.powerd:isAuxBatteryConnected() then
            local aux_batt_lvl = ctx.powerd:getAuxCapacity()
            local aux_batt_symbol = ctx.powerd:getBatterySymbol(ctx.powerd:isAuxCharged(), ctx.powerd:isAuxCharging(), aux_batt_lvl)
            default_footer = default_footer .. " " .. BD.wrap("+") .. BD.wrap(aux_batt_symbol) ..  BD.wrap(aux_batt_lvl .. "%")
        end
    end
    return default_footer
end

function Footer.build(ctx)
    -- ctx import
    local config             = ctx.config
    local touch_menu         = ctx.touch_menu
    local reader             = ctx.reader
    local filemanager        = ctx.filemanager
    local device             = ctx.device
    local powerd             = ctx.powerd
    local screen             = ctx.screen
    local datetime           = ctx.datetime
    local stat               = ctx.stat
    local panel_width        = ctx.panel_width
    local inner_width        = ctx.inner_width
    local h_gap              = screen:scaleBySize(config.style.h_gap or 4)
    local v_gap              = screen:scaleBySize(config.style.v_gap or 4)
    local btn_width          = screen:scaleBySize(config.style.btn_width or 50)
    local btn_radius         = screen:scaleBySize(config.style.btn_radius or 7)
    local btn_bordersize     = screen:scaleBySize(config.style.btn_bordersize or 1.5)
    local btn_font_size      = config.style.btn_font_size or 16
    local slider_ticks_width = screen:scaleBySize(config.style.slider_ticks_width or 1)
    local section            = Utils.getSection(config, SECTION)

    if not section then return nil end
    touch_menu.page_info:clear()
    touch_menu.device_info:clear()

    if (filemanager and not section.enabled_f) or (reader and not section.enabled_r) then
        local time_info = Button:new{
            text = default_footer(ctx),
            text_font_bold = false,
            callback = function()
                UIManager:show(InfoMessage:new{
                    text = datetime.secondsToDateTime(nil, nil, true),
                })
            end,
            hold_callback = function()
                UIManager:broadcastEvent(Event:new("ShowBatteryStatistics"))
            end,
            bordersize = 0,
            touch_menu.show_parent,
        }
        table.insert(touch_menu.device_info, time_info)
        return nil
    end

    section.items = section.items or {}

    -- actions system and custom
    local action_defs = ActionDefs.getMerged(config.custom_actions)

    local function exec_action(ctx, action_data)
        if type(action_data) == "function" then
            action_data(ctx)
        elseif type(action_data) == "table" then
            ctx.touch_menu:closeMenu()
            UIManager:nextTick(function() ActionExec.dispatch(action_data) end)
        end
    end

    for index = 1, #section.items do
    local id = section.items[index]
    local item_def = action_defs[id]

    if item_def and (not item_def.visible_func or item_def.visible_func(ctx)) then
        local icon = item_def.icon_func and item_def.icon_func(ctx) or (item_def.icon or "")
        local val = item_def.label_func and item_def.label_func(ctx) or (item_def.label or "")

        -- Création d'un bouton spécifique pour cette action
        local btn = Button:new{
            text = Utils.get_safe_icon(icon) .. " " .. val, -- btn doesnt't support svg
            text_font_bold = false,
            bordersize = 0,
            show_parent = touch_menu.show_parent,
            callback       = item_def.callback and function() exec_action(ctx, item_def.callback) end or nil,
            hold_callback  = item_def.hold_callback and function() exec_action(ctx, item_def.hold_callback) end or nil,

        }

        -- Ajout direct au groupe
        table.insert(touch_menu.device_info, btn)

    end
end



    local settings_btn = Button:new{
        text           = "\u{F462}", -- down up \u{EB92}"
        width          = btn_width,
        radius         = btn_radius,
        bordersize     = 0,
        text_font_size = btn_font_size,
        show_parent    = touch_menu.show_parent,
        callback       = function()
            Footer.showSettings(ctx)
        end,
        --hold_callback = function() end,
    }

    table.insert(touch_menu.device_info, settings_btn)
    --ctx.touch_menu.time_info:setText(table.concat(parts, sep))
    return {}
end

-- ============================================================
-- Settings Menu Builder
-- ============================================================
function Footer.getSettings(ctx, close, refresh)
    local config = ctx.config
    local section = Utils.getSection(config, SECTION)

    if not section then return {} end

    -- global
    local menu_items = {
        {
            text = _("Enabled in filemanager"),
            checked_func = function() return section.enabled_f end,
            callback = function() section.enabled_f = not section.enabled_f; Config.saveAndRefresh(ctx) end
        },
        {
            text = _("Enabled in reader"),
            checked_func = function() return section.enabled_r end,
            callback = function() section.enabled_r = not section.enabled_r; Config.saveAndRefresh(ctx) end
        }
    }

    local action_buttons = ActionManage:btnActionManageMenu(ctx, SECTION, close, refresh)
    -- convert {{...}} in {}
    local flat_buttons = Utils.unwrap_items(action_buttons)
    for i, btn in ipairs(flat_buttons) do
        -- keep_menu_open
        btn.keep_menu_open = true
        -- add touch_menu to ctx
        local original_callback = btn.callback
        btn.callback = function(touch_menu)
            if touch_menu then ctx.touch_menu = touch_menu end
            if original_callback then return original_callback() end
        end
        -- add separator for last item
        btn.separator = (i == #flat_buttons)
        table.insert(menu_items, btn)
    end

    -- reset
    table.insert(menu_items, {
        text = _("Reset to defaults"),
        keep_menu_open = true,
        callback = close(function(touch_menu)
            if touch_menu then ctx.touch_menu = touch_menu end
            UIManager:show(ConfirmBox:new{
                text = _("Are you sure you want to reset to defaults ?"),
                ok_text = _("Reset"),
                ok_callback = function()
                    local defaults = Config.DEFAULTS.sections[SECTION]
                    Utils.resetSectionToDefaults(section, defaults)
                    Config.saveAndRefresh(ctx)
                    if refresh then refresh() end
                end
            })
        end)
    })

    return menu_items
end

function Footer.showSettings(ctx)
    local dialog

    local function close(fn)
        return function()
            if dialog then UIManager:close(dialog) end
            if fn then fn() end
        end
    end

    local function refresh()
        Footer.showSettings(ctx)
    end

    local buttons = Utils.wrap_items(Footer.getSettings(ctx, close, refresh))
    if not buttons or #buttons==0 then return end
    dialog = ButtonDialog:new{
        -- dismissable = false,
        title = _("Settings") .. " : " .. SECTION,
        title_align  = "left",
        width_factor = 0.9,
        buttons = buttons,
    }
    UIManager:show(dialog)

end

return Footer
