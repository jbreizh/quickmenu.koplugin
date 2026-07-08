local ButtonDialog = require("ui/widget/buttondialog")
local SortWidget      = require("ui/widget/sortwidget")
local ConfirmBox      = require("ui/widget/confirmbox")

local UIManager    = require("ui/uimanager")

local Config        = require("config")
local _             = require("common/i18n").gettext
local ActionDefs = require("action_defs")

local ActionManage = {}

-- ============================================================
-- Menu
-- ============================================================
local function resetSectionToDefaults(section, defaults)
    if not section or not defaults then return end
    for k in pairs(section) do
        section[k] = nil
    end
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            section[k] = {}
            for key, val in pairs(v) do
                section[k][key] = val
            end
        else
            section[k] = v
        end
    end
end

function ActionManage:showActionManageMenu(ctx, section_name)
    local config = ctx.config
    if not config.sections or not config.sections[section_name] then return end
    local section = config.sections[section_name]
    local count = #(section.items or {})

    local dialog
    local buttons = {}

    -- new action
    local buttons = {
        -- select action
        {{
        text = _("Select actions") .. " (" .. count .. ")",
        callback = function()
            UIManager:close(dialog)
            self:selectActionManageDialog(ctx, section_name)

        end
        }},
        -- sort
        {{
        text = _("Sort actions"),
        callback = function()
            --UIManager:close(dialog)
            self:sortActionManageDialog(ctx, section_name)
        end
        }},
        -- reset
        {{
            text = _("Reset actions"),
            callback = function()
                UIManager:close(dialog)
                UIManager:show(ConfirmBox:new{
                    text = _("Reset actions to defaults?"),
                    ok_text = _("Reset"),
                    ok_callback = function()
                        local defaults = Config.DEFAULTS.sections[section_name]
                        resetSectionToDefaults(section, defaults)
                        Config.save(config)
                        self:showActionManageMenu(ctx, section_name)
                    end,
                    cancel_callback = function()
                        self:showActionManageMenu(ctx, section_name)
                    end,
                })
            end
        }},
        -- exit
        {{
        text = _("Exit"),
        callback = function()
            UIManager:close(dialog)
        end
        }},
    }

    dialog = ButtonDialog:new{
        -- dismissable = false,
        title = _("Manage actions") .. " :",
        title_align  = "left",
        buttons = buttons,
    }
    UIManager:show(dialog)
end

-- ============================================================
-- Select
-- ============================================================
local function table_contains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end

local function table_remove(tbl, val)
    for i, v in ipairs(tbl) do
        if v == val then
            table.remove(tbl, i)
            return true
        end
    end
    return false
end

function getMerged(custom_actions)
    local all = ActionDefs.get()
    if custom_actions then
        for i, custom in ipairs(custom_actions) do
            if custom.id then all[custom.id] = custom end
        end
    end
    return all
end

function getSortedActionList(config)
    -- 1. Récupération des définitions fusionnées
    local action_defs = getMerged(config.custom_actions)

    -- 2. Création de la liste triée
    local sorted_list = {}
    for id, def in pairs(action_defs) do
        table.insert(sorted_list, {
            id = id,
            label = def.label or _("None"),
            icon = def.icon or "",
            def = def -- On garde la définition complète au cas où
        })
    end

    -- 3. Tri alphabétique par label
    table.sort(sorted_list, function(a, b)
        return a.label:lower() < b.label:lower()
    end)

    return sorted_list
end

function ActionManage:selectActionManageDialog(ctx, section_name)
    local config = ctx.config
    local section = config.sections[section_name]
    if not section or not section.items then return end

    local all_actions = getSortedActionList(config)

    local buttons = {}
    local dialog
    -- On construit la liste directement sous forme de boutons
    for i, action in ipairs(all_actions) do
        local def = action.def
        local is_currently_visible = (not def.visible_func or def.visible_func(ctx))
        local label = (def.icon or "") .. " " .. (def.label or _("None")) .. (not is_currently_visible and " (n/a)" or "")

        table.insert(buttons, {{
            text = label,
            --enabled = is_currently_visible,
            checked_func = function()
                return table_contains(section.items, action.id)
            end,
            callback = function()
                --if not is_currently_visible then return true end
                if table_contains(section.items, action.id) then
                    table_remove(section.items, action.id)
                else
                    table.insert(section.items, action.id)
                end
                Config.save(config)
                return true
            end
        }})
    end

    table.insert(buttons, {{
        text = _("Close"),
        callback = function()
            UIManager:close(dialog)
            --return false
            self:showActionManageMenu(ctx, section_name)
        end
    }})

    dialog = ButtonDialog:new{
        title = _("Select actions") .. " :",
        title_align  = "left",
        buttons = buttons,
        tap_close_callback = function()
            self:showActionManageMenu(ctx, section_name)
        end,
    }
    UIManager:show(dialog)
end

-- ============================================================
-- Sort
-- ============================================================
function ActionManage:sortActionManageDialog(ctx, section_name)
    local config = ctx.config
    local section = config.sections[section_name]
    if not section or not section.items then return end

    local action_defs = getMerged(config.custom_actions)

    local sort_items = {}
    for _, id in ipairs(section.items) do
        local def = action_defs[id]
        if def then
            local is_currently_visible = (not def.visible_func or def.visible_func(ctx))
            local label = (def.icon or "") .. " " .. (def.label or _("None")) .. (not is_currently_visible and " (n/a)" or "")
            table.insert(sort_items, { text = label, orig_item = id })
        end
    end

    UIManager:show(SortWidget:new{
        title = _("Sort actions") .. " :",
        item_table = sort_items,
        sort_disabled = false,
        callback = function()
            section.items = {}
            for _, item in ipairs(sort_items) do
                table.insert(section.items, item.orig_item)
            end
            Config.save(config)
        end
    })
end


return ActionManage
