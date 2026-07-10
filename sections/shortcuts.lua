local Button          = require("ui/widget/button")
local ButtonDialog    = require("ui/widget/buttondialog")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local TextWidget      = require("ui/widget/textwidget")
local ConfirmBox      = require("ui/widget/confirmbox")

local Font            = require("ui/font")

local Math            = require("optmath")
local UIManager       = require("ui/uimanager")

local ActionExec      = require("action_exec")
local ActionDefs      = require("action_defs")
local ActionManage    = require("action_manage")
local Config          = require("config")
local Utils           = require("common/utils")
local _               = require("common/i18n").gettext

local Shortcuts = {}

local SECTION = "shortcuts"
-- ============================================================
-- Shortcuts Builder
-- ============================================================
function Shortcuts.build(ctx)
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
    local action_size        = screen:scaleBySize(config.style.action_size or 64)
    local action_radius      = screen:scaleBySize(config.style.action_radius or 32)
    local btn_width          = screen:scaleBySize(config.style.btn_width or 50)
    local btn_radius         = screen:scaleBySize(config.style.btn_radius or 7)
    local btn_bordersize     = screen:scaleBySize(config.style.btn_bordersize or 1.5)
    local btn_font_size      = config.style.btn_font_size or 16
    local slider_ticks_width = screen:scaleBySize(config.style.slider_ticks_width or 1)

    local section = Utils.getSection(config, SECTION)

    if not section then return nil end

    if filemanager and not section.enabled_f then return nil end

    if reader and not section.enabled_r then return nil end

    section.items = section.items or {}

    -- actions system and custom
    local action_defs = ActionDefs.getMerged(config.custom_actions)

    local visible_actions = {}
    for i, id in ipairs(section.items) do
        local def = action_defs[id]
        if def and (not def.visible_func or def.visible_func(ctx)) then
            table.insert(visible_actions, { id = id, def = def })
        end
    end

    local num_actions = #visible_actions
    if num_actions == 0 then return nil end

    local group = VerticalGroup:new{ align = "center" }

    if section.show_title then
        local label_title = TextWidget:new{
            text = _("Shortcuts") .. " :",
            face =  Font:getFace("cfont", btn_font_size), bold = true,
            max_width = inner_width - btn_width*2,
        }
        local settings_btn = Button:new{
            text           = "\u{F462}", -- down up \u{EB92}"
            width          = btn_width,
            radius         = btn_radius,
            bordersize     = 0,
            text_font_size = btn_font_size,
            show_parent    = touch_menu.show_parent,
            callback       = function()
                Shortcuts.showSettings(ctx)
            end,
            --hold_callback = function() end,
        }
        local collapse_btn = Button:new{
            text           = section.collapse and "\u{F078}" or "\u{F077}", -- down up
            width          = btn_width,
            radius         = btn_radius,
            bordersize     = 0,
            text_font_size = btn_font_size,
            show_parent    = touch_menu.show_parent,
            callback       = function()
                section.collapse = not section.collapse
                Config.saveAndRefresh(ctx)
            end,
            --hold_callback = function() end,
        }
        local row_title = HorizontalGroup:new{
            align = "center",
            label_title,
            HorizontalSpan:new{ width = inner_width - label_title:getSize().w - btn_width*2 },
            settings_btn,
            collapse_btn
        }
        table.insert(group, row_title)

        if section.collapse then  return { widget = group } end
    end

    local max_cols =  section.max_cols or 3
    local shortcuts_width = Math.round((inner_width  - h_gap * (max_cols - 1)) / max_cols)

    --
    local function exec_action(ctx, action_data)
        if type(action_data) == "function" then
            action_data(ctx)
        elseif type(action_data) == "table" then
            ctx.touch_menu:closeMenu()
            UIManager:nextTick(function() ActionExec.dispatch(action_data) end)
        end
    end

    local function createButton(def)
        local icon = def.icon_func and def.icon_func(ctx) or (def.icon or "")
        local label = def.label_func and def.label_func(ctx) or (def.label or "")
        local shortcuts_text = section.show_label and (Utils.get_safe_icon(def.icon) .. " " .. _(label)) or Utils.get_safe_icon(def.icon) -- btn doesnt't support svg
        return Button:new{
            text           = shortcuts_text,
            width          = shortcuts_width,
            radius         = btn_radius,
            bordersize     = btn_bordersize,
            text_font_size = btn_font_size,
            show_parent    = touch_menu.show_parent,
            callback       = def.callback and function() exec_action(ctx, def.callback) end or nil,
            hold_callback  = def.hold_callback and function() exec_action(ctx, def.hold_callback) end or nil,
        }
    end

    for i = 1, num_actions, max_cols do
        local row = HorizontalGroup:new{ align = "center" }

        for j = i, math.min(i + max_cols - 1, num_actions) do
            local entry = visible_actions[j]
            local btn_widget = createButton(entry.def)

            table.insert(row, btn_widget)

            if j < math.min(i + max_cols - 1, num_actions) then
                table.insert(row, HorizontalSpan:new{ width = h_gap })
            end
        end

        table.insert(group, row)

        if i + max_cols <= num_actions then
            table.insert(group, VerticalSpan:new{ width = h_gap })
        end
    end

    return { widget = group }
end

-- ============================================================
-- Settings Menu Builder
-- ============================================================
function Shortcuts.getSettings(ctx, close, refresh)
    local config  = ctx.config
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
        },
        {
            text = _("Show title"),
            checked_func = function() return section.show_title end,
            callback = function() section.show_title = not section.show_title; Config.saveAndRefresh(ctx) end
        },
        {
            text = _("Show labels"),
            checked_func = function() return section.show_label end,
            callback = function() section.show_label = not section.show_label; Config.saveAndRefresh(ctx) end
        },
        {
            text_func = function() return _("Columns") .. " (" .. section.max_cols .. ")\xE2\x80\xA6" end,
            keep_menu_open = true,
            callback = close(function(touch_menu)
                if touch_menu then ctx.touch_menu = touch_menu end
                local original = section.max_cols
                local function getValue() return section.max_cols end
                local function setValue(v) section.max_cols = math.max(1, math.min(15, v)); Config.saveAndRefresh(ctx) end
                local function rebuild()  end -- nothing saveAndRefresh refresh the touchmenu

                local dialog
                local function nudge(delta)
                    setValue(getValue() + delta)
                    rebuild()
                    dialog:reinit()
                end

                local function close() UIManager:close(dialog); refresh() end
                local function revert() setValue(original); rebuild() end

                dialog = ButtonDialog:new{
                    dismissable = false,
                    title = _("Columns"),
                    buttons = {
                        {
                            { text = "-1",   callback = function() nudge(-1)  end },
                            { text_func = function() return tostring(getValue()) end, enabled = false },
                            { text = "+1",   callback = function() nudge(1)   end },
                        },
                        {
                            { text = _("Cancel"), callback = function() revert(); close() end },
                            { text = _("Default"),callback = function() setValue(Config.DEFAULTS.sections.shortcuts.max_cols); rebuild(); dialog:reinit() end },
                            { text = _("Apply"), is_enter_default = true, callback = close },
                        },
                    },
                    tap_close_callback = revert
                }
                UIManager:show(dialog)
            end),
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

function Shortcuts.showSettings(ctx)
    local dialog

    local function close(fn)
        return function()
            if dialog then UIManager:close(dialog) end
            if fn then fn() end
        end
    end

    local function refresh()
        Shortcuts.showSettings(ctx)
    end

    local buttons = Utils.wrap_items(Shortcuts.getSettings(ctx, close, refresh))
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

return Shortcuts
