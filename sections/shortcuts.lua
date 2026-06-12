local Button          = require("ui/widget/button")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local VerticalGroup   = require("ui/widget/verticalgroup")

local Math            = require("optmath")
local UIManager       = require("ui/uimanager")

local ActionDefs      = require("sections/action_defs")
local Utils           = require("common/utils")
local Translation     = require("i18n/translation")
local _               = Translation._

local Shortcuts = {}

function Shortcuts.build(ctx)
    local config = ctx.config
    local section = Utils.getSection(config, "shortcuts")

    if not section or not section.enabled then return nil end
    section.items = section.items or {}

    -- style
    local gap            = ctx.theme.gap or ctx.screen:scaleBySize(4)
    local btn_radius     = ctx.theme.btn_radius or 0
    local btn_bordersize = ctx.theme.btn_bordersize  or 0
    local btn_font_size  = ctx.theme.btn_font_size  or 16

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

    local max_cols =  section.max_cols or 3
    local btn_width = Math.round((ctx.inner_width  - gap * (max_cols - 1)) / max_cols)

    local main_container = VerticalGroup:new{ align = "center" }
    local refs = { buttons = {}, sliders = {}, widgets = {} }

    local function createButton(def)
        local icon = def.unicode or ""
        local label = def.label_func and def.label_func() or def.label
        local btn_text = section.show_label and (icon .. " " .. _(label)) or icon

        return Button:new{
            text           = btn_text,
            width          = btn_width,
            radius         = btn_radius,
            bordersize     = btn_bordersize,
            text_font_size = btn_font_size,
            show_parent    = ctx.touch_menu.show_parent,
            callback       = function()
                ctx.touch_menu:updateItems(1)
                if def.callback then def.callback(ctx) end
            end,
            hold_callback  = def.hold_callback and function()
                ctx.touch_menu:updateItems(1)
                def.hold_callback(ctx)
            end or nil,
        }
    end

    for i = 1, num_actions, max_cols do
        local row = HorizontalGroup:new{ align = "center" }

        for j = i, math.min(i + max_cols - 1, num_actions) do
            local entry = visible_actions[j]
            local btn_widget = createButton(entry.def)

            table.insert(refs.buttons, {
                widget = btn_widget,
                callback = btn_widget.callback,
                hold_callback = btn_widget.hold_callback,
            })

            table.insert(row, btn_widget)

            if j < math.min(i + max_cols - 1, num_actions) then
                table.insert(row, HorizontalSpan:new{ width = gap })
            end
        end

        table.insert(main_container, row)

        if i + max_cols <= num_actions then
            table.insert(main_container, ctx.section_span)
        end
    end

    return { widget = main_container, refs = refs }
end


function Shortcuts.getSettings(config, saveConfig, ctx)
    local section = Utils.getSection(config, "shortcuts")
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

        -- Indicateur visuel si l'action n'est pas disponible actuellement
        local label = (def.unicode or "") .. " " .. def.label
        local is_currently_visible = (not def.visible_func or def.visible_func())
        if not is_currently_visible then
            label = label .. " (n/a)"
        end

        table.insert(select_items, {
            text = label,
            checked_func = function()
                -- Retourne true si l'ID est dans la table section.items
                for index, item_id in ipairs(section.items) do
                    if item_id == id then return true end
                end
                return false
            end,
            callback = function()
                -- Bascule : si présent, on supprime ; sinon, on ajoute
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
            text = _("Show shortcuts controls"),
            checked_func = function() return section.enabled end,
            callback = function() section.enabled = not section.enabled; saveConfig() end
        },
        {
            text = _("Show shortcuts controls labels"),
            checked_func = function() return section.show_label end,
            callback = function() section.show_label = not section.show_label; saveConfig() end
        },
        {
            text_func = function() return _("Columns of shortcuts") .. " (" .. (section.max_cols or 3) .. ")" end,
            sub_item_table = {
                {
                    text = "1",
                    checked_func = function() return section.max_cols == 1 end,
                    callback = function()
                        section.max_cols = 1
                        saveConfig()
                    end
                },
                {
                    text = "2",
                    checked_func = function() return section.max_cols == 2 end,
                    callback = function()
                        section.max_cols = 2
                        saveConfig()
                    end
                },
                {
                    text = "3",
                    checked_func = function() return section.max_cols == 3 end,
                    callback = function()
                        section.max_cols = 3
                        saveConfig()
                    end
                },
                {
                    text = "4",
                    checked_func = function() return section.max_cols == 4 end,
                    callback = function()
                        section.max_cols = 4
                        saveConfig()
                    end
                },
                {
                    text = "5",
                    checked_func = function() return section.max_cols == 5 end,
                    callback = function()
                        section.max_cols = 5
                        saveConfig()
                    end
                },
                {
                    text = "6",
                    checked_func = function() return section.max_cols == 6 end,
                    callback = function()
                        section.max_cols = 6
                        saveConfig()
                    end
                },
            }
        },
        {
            text_func = function()
                local count = #(section.items or {})
                return _("Select shortcuts controls") .. " (" .. count .. ")"
            end,
            sub_item_table = select_items
        },
        {
            text = _("Arrange shortcuts controls"),
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
                    title = _("Arrange shortcuts controls"),
                    item_table = sort_items,
                    callback = function()
                        section.items = {}
                        for idx, item in ipairs(sort_items) do
                            table.insert(section.items, item.orig_item)
                        end
                        saveConfig()
                    end
                })
            end,
            separator = true
        }
    }
end

return Shortcuts
