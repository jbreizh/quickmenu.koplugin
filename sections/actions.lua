local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local VerticalGroup   = require("ui/widget/verticalgroup")
local TextWidget      = require("ui/widget/textwidget")
local ConfirmBox      = require("ui/widget/confirmbox")

local Font            = require("ui/font")

local UIManager       = require("ui/uimanager")

local Config          = require("config")
local CircleButton    = require("widgets/circlebutton")
local ActionDefs      = require("sections/action_defs")
local Utils           = require("common/utils")
local Translation     = require("i18n/translation")
local _               = Translation._

local Actions = {}

function Actions.build(ctx)
    local config       = ctx.config
    local filemanager  = ctx.filemanager
    local reader       = ctx.reader
    local inner_width  = ctx.inner_width
    local screen       = ctx.screen
    local theme        = ctx.theme or {}
    local section      = Utils.getSection(config, "actions")

    if not section then return nil end

    if filemanager and not section.enabled_f then return nil end

    if reader and not section.enabled_r then return nil end

    section.items = section.items or {}

    -- style
    local gap            = theme.gap or screen:scaleBySize(4)
    local btn_radius     = theme.btn_radius or 0
    local btn_bordersize = theme.btn_bordersize  or 0
    local btn_font_size  = theme.btn_font_size  or 16

    local action_defs = ActionDefs.get()
    local visible_actions = {}

    for _, id in ipairs(section.items) do
        local def = action_defs[id]
        if def and (not def.visible_func or def.visible_func()) then
            table.insert(visible_actions, { id = id, def = def })
        end
    end

    local num_actions = #visible_actions
    if num_actions == 0 then return nil end

    --
    local row = HorizontalGroup:new{ align = "center" }
    local action_btn_size = math.min(math.floor(inner_width / num_actions), screen:scaleBySize(64))
    local ratio = screen:scaleBySize(100) / 100
    local action_icon_size = math.floor((action_btn_size * 0.4) / ratio + 0.5)
    local action_label_size = math.floor((action_btn_size * 0.18) / ratio + 0.5)
    local btn_gap = num_actions > 1 and math.max(0, math.floor((inner_width - num_actions * action_btn_size) / (num_actions - 1))) or 0

    for i, entry in ipairs(visible_actions) do
        local def = entry.def

        -- button
        local btn_widget = CircleButton:new{
            icon = def.unicode_func and def.unicode_func() or (def.unicode or ""),
            size = action_btn_size,
            icon_size = action_icon_size,
            bordersize = btn_bordersize,
            is_active = def.active_func and def.active_func() or false,
            callback = function() if def.callback then def.callback(ctx) end end,
            hold_callback = def.hold_callback and function() def.hold_callback(ctx) end or nil,
        }

        -- label
        local final_widget = btn_widget
        if section.show_label and (def.label_func or def.label) then
            local label_text = def.label_func and def.label_func() or def.label

            final_widget = VerticalGroup:new{
                align = "center",
                btn_widget,
                TextWidget:new{
                    text = label_text,
                    face = Font:getFace("cfont", action_label_size),
                    max_width = action_btn_size,
                }
            }
        end

        table.insert(row, final_widget)
        if i < num_actions and btn_gap > 0 then
            table.insert(row, HorizontalSpan:new{ width = btn_gap })
        end
    end

    local group = VerticalGroup:new{ align = "center", row }

    if section.show_title then
        local actions_label = TextWidget:new{
            text = _("Actions") .. " :",
            face =  Font:getFace("cfont", btn_font_size), bold = true,
            max_width = inner_width,
        }
        table.insert(group, 1, actions_label)
    end

    return { widget = group }
end

function Actions.getSettings(config, saveConfig, ctx)
    local section = Utils.getSection(config, "actions")
    if not section then return {} end
    section.items = section.items or {}

    local action_defs = ActionDefs.get()
    local SortWidget = require("ui/widget/sortwidget")

    -- 1. Récupération et tri des IDs par label
    local sorted_keys = {}
    for id in pairs(action_defs) do
        table.insert(sorted_keys, id)
    end
    table.sort(sorted_keys, function(a, b)
        return action_defs[a].label < action_defs[b].label
    end)

    -- 2. Création des items de sélection
    local select_items = {}
    for i, id in ipairs(sorted_keys) do
        local def = action_defs[id]
        local label = (def.unicode or "") .. " " .. def.label
        local is_currently_visible = (not def.visible_func or def.visible_func())
        if not is_currently_visible then
            label = label .. " (n/a)"
        end

        table.insert(select_items, {
            text = label,
            -- sensitive = is_currently_visible,
            checked_func = function()
                for _, item_id in ipairs(section.items) do
                    if item_id == id then return true end
                end
                return false
            end,
            callback = function()
                local found = false
                for idx, item_id in ipairs(section.items) do
                    if item_id == id then
                        table.remove(section.items, idx)
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(section.items, id)
                end
                saveConfig()
                return true
            end
        })
    end

    return {
        {
            text = _("Enabled in filemanager"),
            checked_func = function() return section.enabled_f end,
            callback = function() section.enabled_f = not section.enabled_f; saveConfig() end
        },
        {
            text = _("Enabled in reader"),
            checked_func = function() return section.enabled_r end,
            callback = function() section.enabled_r = not section.enabled_r; saveConfig() end
        },
        {
            text = _("Show title"),
            checked_func = function() return section.show_title end,
            callback = function() section.show_title = not section.show_title saveConfig() end
        },
        {
            text = _("Show labels"),
            checked_func = function() return section.show_label end,
            callback = function() section.show_label = not section.show_label; saveConfig() end,
            separator = true
        },
        {
            text_func = function()
                local count = #(section.items or {})
                return _("Select controls") .. " (" .. count .. ")"
            end,
            sub_item_table = select_items
        },
        {
            text = _("Arrange controls"),
            keep_menu_open = true,
            callback = function()
                local sort_items = {}
                for idx, id in ipairs(section.items) do
                    local def = action_defs[id]
                    local label = (def.unicode or "") .. " " .. def.label
                    local is_currently_visible = (not def.visible_func or def.visible_func())
                    if not is_currently_visible then
                        label = label .. " (n/a)"
                    end
                    table.insert(sort_items, { text = label, orig_item = id })
                end

                UIManager:show(SortWidget:new{
                    title = _("Arrange controls"),
                    item_table = sort_items,
                    callback = function()
                        section.items = {}
                        for _, item in ipairs(sort_items) do
                            table.insert(section.items, item.orig_item)
                        end
                        saveConfig()
                    end
                })
            end,
            separator = true
        },
        {
            text = _("Reset to defaults"),
            callback = function()
                UIManager:show(ConfirmBox:new{
                    text = _("Are you sure you want to reset to defaults ?"),
                    ok_text = _("Reset"),
                    ok_callback = function()
                        local defaults = Config.DEFAULTS.sections.actions
                        Utils.resetSectionToDefaults(section, defaults)
                        saveConfig()
                    end
                })
            end
        }
    }
end

return Actions
