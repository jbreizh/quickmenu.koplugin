local Button          = require("ui/widget/button")
local ButtonDialog    = require("ui/widget/buttondialog")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local TextWidget      = require("ui/widget/textwidget")
local ConfirmBox      = require("ui/widget/confirmbox")

local Font            = require("ui/font")

local UIManager       = require("ui/uimanager")

local ActionExec      = require("action_exec")
local ActionDefs      = require("action_defs")
local ActionManage    = require("action_manage")
local Config          = require("config")
local ActionButton    = require("widgets/actionbutton")
local Utils           = require("common/utils")
local _               = require("common/i18n").gettext

local Actions = {
    id = "actions",
    label = _("Actions"),
    icon  = "\u{E767}" --auto fix
}

-- ============================================================
-- Actions Builder
-- ============================================================
function Actions.build(ctx)
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

    local section = Utils.getSection(config, Actions.id)

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

    -- title
    if section.show_title then
        -- collapse
        local collapse_btn = Button:new{
            text           = section.collapse and "▶" or "▼",
            width          = btn_width,
            radius         = btn_radius,
            bordersize     = 0,
            text_font_size = btn_font_size,
            show_parent    = touch_menu.show_parent,
            callback       = function()
                section.collapse = not section.collapse
                Config.saveAndRefresh(ctx, true) -- no flush
            end,
            --hold_callback = function() end,
        }
        -- add icon near section name when collapse
        local label_icon = ""
        if section.collapse then
            for _, entry in ipairs(visible_actions) do
                local def = entry.def
                local icon = def.icon_func and def.icon_func(ctx) or (def.icon or "")
                label_icon = label_icon .. " " .. Utils.get_safe_icon(icon)
            end
        end
        -- section name
        local label_title = TextWidget:new{
            text = Actions.label .. " : " .. label_icon,
            face =  Font:getFace("cfont", btn_font_size), bold = true,
            max_width = inner_width - btn_width*2,
        }
        local settings_btn = Button:new{
            text           = "\u{EB92}",
            width          = btn_width,
            radius         = btn_radius,
            bordersize     = 0,
            text_font_size = btn_font_size,
            show_parent    = touch_menu.show_parent,
            callback       = function()
                Actions.showSettings(ctx)
            end,
            --hold_callback = function() end,
        }
        --
        local row_title = HorizontalGroup:new{
            collapse_btn,
            align = "center",
            label_title,
            HorizontalSpan:new{ width = inner_width - label_title:getSize().w - btn_width*2 },
            settings_btn,
        }
        --
        table.insert(group, row_title)
        -- stop render if section is collapse
        if section.collapse then  return { widget = group } end
    else
        table.insert(group, VerticalSpan:new{ width = screen:scaleBySize( 10 ) }) -- better for visual
    end

    -- utils to exec actions
    local function exec_action(ctx, action_data)
        if type(action_data) == "function" then -- native
            action_data(ctx)
        elseif type(action_data) == "table" then -- custom
            ctx.touch_menu:closeMenu()
            UIManager:nextTick(function() ActionExec.dispatch(action_data) end)
        end
    end

    -- Logique de calcul selon le mode
    local action_radius_ratio = action_radius / action_size -- 0 square 0.5 circle
    local action_btn_size = action_size
    local ratio = screen:scaleBySize(100) / 100

    if section.fit_ctrl then
        action_btn_size = math.min(math.floor( (inner_width - (num_actions - 1) * h_gap ) / math.max(1, num_actions)), action_btn_size)
    end
    local action_btn_radius = math.floor(action_btn_size * action_radius_ratio)
    local action_icon_size = math.floor((action_btn_size * 0.4) / ratio + 0.5)
    local action_label_size = math.floor((action_btn_size * 0.18) / ratio + 0.5)

    -- Construction des boutons
    local function create_btn(entry)
        local def = entry.def
        local btn = ActionButton:new{
            icon          = def.icon_func and def.icon_func(ctx) or (def.icon or ""),
            size          = action_btn_size,
            radius        = action_btn_radius,
            icon_size     = action_icon_size,
            bordersize    = btn_bordersize,
            is_active     = def.active_func and def.active_func(ctx) or false,
            callback      = def.callback and function() exec_action(ctx, def.callback) end or nil,
            hold_callback = def.hold_callback and function() exec_action(ctx, def.hold_callback) end or nil,
        }
        if section.show_label and (def.label_func or def.label) then
            return VerticalGroup:new{
                align = "center",
                btn,
                TextWidget:new{
                    text = def.label_func and def.label_func(ctx) or def.label,
                    face = Font:getFace("cfont", action_label_size),
                    max_width = action_btn_size,
                }
            }
        end
        return btn
    end

    -- action btn placement
    local i = 1
    while i <= num_actions do
        local row_actions = {}
        local current_row_w = 0
        local start_i = i

        -- fill the line till the line is full
        while i <= num_actions do
            local next_w = current_row_w + (i > start_i and h_gap or 0) + action_btn_size
            if not section.fit_ctrl and i > start_i and next_w > inner_width then break end

            table.insert(row_actions, visible_actions[i])
            current_row_w = next_w
            i = i + 1
        end

        -- gap
        local n = #row_actions
        local gap = h_gap
        if section.justified_ctrl and n > 1 then
            gap = math.floor((inner_width - (n * action_btn_size)) / (n - 1))
        end

        -- store the line
        local row = HorizontalGroup:new{ align = "center" }
        for j, entry in ipairs(row_actions) do
            if j > 1 then
                table.insert(row, HorizontalSpan:new{ width = gap })
            end
            table.insert(row, create_btn(entry))
        end
        table.insert(group, row)
    end

    return { widget = group }
end

-- ============================================================
-- Settings Menu Builder
-- ============================================================
function Actions.getSettings(ctx, close, refresh, reload)
    local config = ctx.config
    local section = Utils.getSection(config, Actions.id)
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
            checked_func = function() if reload then reload() end  return section.show_title end,
            callback = function() section.show_title = not section.show_title; Config.saveAndRefresh(ctx) end
        },
        {
            text = _("Show labels"),
            checked_func = function() if reload then reload() end return section.show_label end,
            callback = function() section.show_label = not section.show_label; Config.saveAndRefresh(ctx) end
        },
        {
            text = _("Fit controls"),
            checked_func = function() if reload then reload() end  return section.fit_ctrl end,
            callback = function() section.fit_ctrl = not section.fit_ctrl; Config.saveAndRefresh(ctx) end
        },
        {
            text = _("Justify controls"),
            checked_func = function() if reload then reload() end  return section.justified_ctrl end,
            callback = function() section.justified_ctrl = not section.justified_ctrl; Config.saveAndRefresh(ctx) end,
            separator= true
        },
    }

    local action_buttons = ActionManage:btnActionManageMenu(ctx, Actions.id, close, refresh)
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
                    local defaults = Config.DEFAULTS.sections[Actions.id]
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

function Actions.showSettings(ctx)
    local dialog

    local function close(fn)
        return function()
            if dialog then UIManager:close(dialog) end
            if fn then fn() end
        end
    end

    local function refresh()
        Actions.showSettings(ctx)
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

    local buttons = Utils.wrap_items(Actions.getSettings(ctx, close, refresh, reload))
    if not buttons or #buttons==0 then return end

    table.insert(buttons, {}) -- separator

    table.insert(buttons, {{
        text = _("Exit"),
        callback = close()
    }})

    dialog = ButtonDialog:new{
        -- dismissable = false,
        title = Actions.icon .. " " .. Actions.label .. " :",
        title_align  = "left",
        width_factor = 0.9,
        buttons = buttons,
        tap_close_callback = close()
    }
    UIManager:show(dialog)
    is_initializing = false -- allow reload after opening
end

return Actions
