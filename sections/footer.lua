local BD           = require("ui/bidi")
local ConfirmBox   = require("ui/widget/confirmbox")
local UIManager    = require("ui/uimanager")
local SortWidget   = require("ui/widget/sortwidget")
local ButtonDialog = require("ui/widget/buttondialog")
local Button       = require("ui/widget/button")
local HorizontalGroup  = require("ui/widget/horizontalgroup")

local InfoMessage  = require("ui/widget/infomessage")
local UIManager    = require("ui/uimanager")
local Event        = require("ui/event")
local IconButton   = require("ui/widget/iconbutton")

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

    -- footer layout after orig_init: self=touch_menu
    --   footer[1] = LeftContainer  {up_button=btn}
    --   footer[2] = CenterContainer{self.page_info=HGrp{self.page_info_left_chev=btn, self.page_info_text=txtW, self.page_info_right_chev=btn}}
    --   footer[3] = RightContainer {self.device_info=Hgrp{self.time_info=btn}}

    -- clear footer slot but don't clear touch_menu.page_info and touch_menu.device_info
    -- force to clear or btn stay in group
    touch_menu.footer[1][1] = HorizontalGroup:new{}
    touch_menu.footer[2][1] = HorizontalGroup:new{}
    touch_menu.footer[3][1] = HorizontalGroup:new{}
    -- settings_btn
    local settings_btn = Button:new{
        text           = "\u{EB92}",
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
    -- up_button : original is local can't reference it
    local up_button = Button:new{
        icon           = "chevron.up",
        --text           = "▲",
        width          = btn_width,
        radius         = btn_radius,
        bordersize     = 0,
        text_font_size = btn_font_size,
        show_parent    = touch_menu.show_parent,
        callback = function()  touch_menu:backToUpperMenu()
        end,
    }
    -- default footer force to rebuild default footer cause force to clear
    if (filemanager and not section.enabled_f) or (reader and not section.enabled_r) then
        -- insert up_button left
        table.insert(touch_menu.footer[1][1], up_button)
         -- insert page_info center
        table.insert(touch_menu.footer[2][1], touch_menu.page_info)
        -- insert default_footer right
        table.insert(touch_menu.footer[3][1], touch_menu.time_info)
        -- insert settings_btn
        if section.show_title then table.insert(touch_menu.footer[3][1], settings_btn) end
    -- zenFooter
    elseif section.use_zenfooter then
        -- insert up_button center
        table.insert(touch_menu.footer[2][1], up_button)
        -- insert page_info right
        table.insert(touch_menu.footer[3][1], touch_menu.page_info)
        -- insert settings_btn right
        if section.show_title then table.insert(touch_menu.footer[3][1], settings_btn) end
    -- quickmenu footer
    else
        -- insert up_button left
        table.insert(touch_menu.footer[1][1], up_button)
        -- insert page_info_left_chev left
        table.insert(touch_menu.footer[1][1], touch_menu.page_info_left_chev)
        -- create custom footer and insert right
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
        --
        local footer_width = touch_menu.width - touch_menu.padding*2
        local chevron_with = touch_menu.page_info_left_chev:getSize().w + touch_menu.page_info_right_chev:getSize().w
        local max_footer_width = footer_width - btn_width*2 - chevron_with
        --print(footer_width .. ":" .. touch_menu.page_info_left_chev:getSize().w .. ":" .. max_footer_width)
        local current_width = 0
        local has_overflow = false
        local overflow_items = {}

        for index = 1, #section.items do
        local id = section.items[index]
        local item_def = action_defs[id]

            if item_def and (not item_def.visible_func or item_def.visible_func(ctx)) then
                local icon = item_def.icon_func and item_def.icon_func(ctx) or (item_def.icon or "")
                local val = item_def.label_func and item_def.label_func(ctx) or (item_def.label or "")
                -- create btn
                local btn = Button:new{
                    text = Utils.get_safe_icon(icon) .. " " .. val, -- btn doesnt't support svg
                    text_font_bold = false,
                    bordersize = 0,
                    show_parent = touch_menu.show_parent,
                    callback       = item_def.callback and function() exec_action(ctx, item_def.callback) end or nil,
                    hold_callback  = item_def.hold_callback and function() exec_action(ctx, item_def.hold_callback) end or nil,
                }
                -- if item fit then add btn else store hidden items
                local btn_w = btn:getSize().w
                if current_width + btn_w <= max_footer_width then
                    current_width = current_width + btn_w
                    table.insert(touch_menu.footer[3][1], btn)
                else
                    has_overflow = true
                    print("coucou")
                    overflow_icon = table.insert(overflow_items, "• " .. Utils.get_safe_icon(item_def.icon or "") .. " " .. (item_def.label or ""))
                end
            end
        end

        -- settings_btn_overflow
        local settings_btn_overflow = Button:new{
            text           = (has_overflow and "\u{F071}") or "\u{EB92}", -- warning icon if overflow
            width          = btn_width,
            radius         = btn_radius,
            bordersize     = 0,
            text_font_size = btn_font_size,
            show_parent    = touch_menu.show_parent,
            callback       = function()
                if has_overflow then
                    UIManager:show(InfoMessage:new{
                        text = _("Footer overflow !!!!\nHidden actions :\n") .. table.concat(overflow_items, "\n"),
                        icon = "notice-warning"
                    })
                end
                Footer.showSettings(ctx)
            end,
            --hold_callback = function() end,
        }
        -- insert page_info_right_chev right
        table.insert(touch_menu.footer[3][1], touch_menu.page_info_right_chev)
        -- insert settings_btn_overflow right
        if section.show_title then table.insert(touch_menu.footer[3][1], settings_btn_overflow) end
    end
    return {}
end

-- ============================================================
-- Settings Menu Builder
-- ============================================================
function Footer.getSettings(ctx, close, refresh, reload)
    local config = ctx.config
    local section = Utils.getSection(config, SECTION)

    if not section then return {} end

    -- global
    local menu_items = {
        {
            text = _("Enabled in filemanager"),
            checked_func = function() if reload then reload() end return section.enabled_f end,
            callback = function() section.enabled_f = not section.enabled_f; Config.saveAndRefresh(ctx) end
        },
        {
            text = _("Enabled in reader"),
            checked_func = function() if reload then reload() end return section.enabled_r end,
            callback = function() section.enabled_r = not section.enabled_r; Config.saveAndRefresh(ctx) end
        },
        {
            text = _("Show title"),
            checked_func = function() if reload then reload() end return section.show_title end,
            callback = function() section.show_title = not section.show_title; Config.saveAndRefresh(ctx) end
        },
        {
            text = _("Use ZenFooter "),
            checked_func = function() if reload then reload() end return section.use_zenfooter end,
            callback = function() section.use_zenfooter = not section.use_zenfooter; Config.saveAndRefresh(ctx) end
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
        text = _("Reset section to defaults") .. "\xE2\x80\xA6",
        keep_menu_open = true,
        callback = close(function(touch_menu)
            if touch_menu then ctx.touch_menu = touch_menu end
            UIManager:show(ConfirmBox:new{
                text = _("Reset section to defaults") .. " ?",
                ok_text = _("Reset"),
                ok_callback = function()
                    local defaults = Config.DEFAULTS.sections[SECTION]
                    Utils.resetSectionToDefaults(section, defaults)
                    Config.saveAndRefresh(ctx)
                    if refresh then refresh() end
                end,
                cancel_callback = function()
                    if refresh then refresh() end
                end,
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
    -- use to refresh under check btn when dialog is transparent
    -- cost perf so block at openig as dialog never open transparent
    -- only from the dialog from the touch_menu itself it crash koreader
    local is_initializing = true
    local function reload()
        if is_initializing then return end
        local touch_menu = ctx.touch_menu
        if touch_menu and touch_menu.updateItems then touch_menu:updateItems() end
    end

    local buttons = Utils.wrap_items(Footer.getSettings(ctx, close, refresh, reload))
    if not buttons or #buttons==0 then return end

    table.insert(buttons, {}) -- separator

    table.insert(buttons, {{
        text = _("Exit"),
        callback = close()
    }})

    dialog = ButtonDialog:new{
        -- dismissable = false,
        title = _("Settings") .. " : " .. SECTION,
        title_align  = "left",
        width_factor = 0.9,
        buttons = buttons,
    }
    UIManager:show(dialog)
    is_initializing = false -- allow reload after opening
end

return Footer
