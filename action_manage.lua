local ButtonDialog = require("ui/widget/buttondialog")
local SortWidget   = require("ui/widget/sortwidget")
local ConfirmBox   = require("ui/widget/confirmbox")

local UIManager    = require("ui/uimanager")

local ActionDefs   = require("action_defs")
local Utils        = require("common/utils")
local Config       = require("config")
local _            = require("common/i18n").gettext

local ActionManage = {}

local WIDTHFACTOR = 0.8

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

local function resetSectionItemsToDefaults(section, defaults)
    if not section or not defaults then return end
    section.items = {}
    if defaults.items then
        for i, v in ipairs(defaults.items) do
            section.items[i] = v
        end
    end
end

-- Dans votre fichier ActionManage
function ActionManage:btnActionManageMenu(ctx, section_name, close, on_refresh)
    local config = ctx.config
    if not config.sections or not config.sections[section_name] then return {} end
    local section = config.sections[section_name]
    local count = #(section.items or {})

    return {
        {{
            text_func = function()
                return _("Select actions") .. " (" .. #(section.items or {}) .. ")\xE2\x80\xA6"
            end,
            callback = close(function()
                self:selectActionManageDialog(ctx, section_name, on_refresh)
            end)
        }},
        {{
            text = _("Sort actions") .. "\xE2\x80\xA6",
            -- don t close : sortWidget don't have a cancel_callback
            -- stay background : no problem sortwidget is fullscreen and there is nothing to refresh
            callback = function()
                self:sortActionManageDialog(ctx, section_name)
            end,
--             callback = close(function()
--                 self:sortActionManageDialog(ctx, section_name)
--             end)
        }},
        {{
            text = _("Reset actions to defaults") .. "\xE2\x80\xA6",
            callback = close(function()
                UIManager:show(ConfirmBox:new{
                    text = _("Reset actions to defaults") .. " ?",
                    ok_text = _("Reset"),
                    ok_callback = function()
                        local defaults = Config.DEFAULTS.sections[section_name]
                        resetSectionItemsToDefaults(section, defaults)
                        Config.saveAndRefresh(ctx)
                        if on_refresh then on_refresh() end
                    end,
                    cancel_callback = function()
                        if on_refresh then on_refresh() end
                    end,
                })
            end)
        }}
    }
end

function ActionManage:showActionManageMenu(ctx, section_name)
    local dialog

    local function close(fn)
        return function()
            if dialog then UIManager:close(dialog) end
            if fn then fn() end
        end
    end

    local function refresh()
        self:showActionManageMenu(ctx, section_name)
    end

    local buttons = self:btnActionManageMenu(ctx, section_name, close, refresh)

    table.insert(buttons, {}) -- separator

    table.insert(buttons, {{
        text = _("Exit"),
        callback = close()
    }})

    dialog = ButtonDialog:new{
        -- dismissable = false,
        title = _("Manage actions") .. " :",
        title_align  = "left",
        width_factor = WIDTHFACTOR,
        buttons = buttons,
        tap_close_callback = close()
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

function getSortedActionList(config)
    local action_defs = ActionDefs.getMerged(config.custom_actions)
    local sorted_list = {}
    for id, def in pairs(action_defs) do
        table.insert(sorted_list, {
            id = id,
            label = def.label or _("None"),
            icon = def.icon or "",
            def = def -- On garde la définition complète au cas où
        })
    end

    -- sort label alphabetical
    table.sort(sorted_list, function(a, b)
        return a.label:lower() < b.label:lower()
    end)

    return sorted_list
end

function ActionManage:selectActionManageDialog(ctx, section_name, on_close)
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

        -- btn doesnt't support svg
        local label = (Utils.get_safe_icon(def.icon) or "") .. " " .. (def.label or _("None")) .. (not is_currently_visible and " (n/a)" or "")

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
                Config.saveAndRefresh(ctx)
                return true
            end
        }})
    end

    table.insert(buttons, {}) -- separator

    table.insert(buttons, {{
        text = _("Exit"),
        callback = function()
            UIManager:close(dialog)
            --return false
            if on_close then on_close() end
        end
    }})

    dialog = ButtonDialog:new{
        title = _("Select actions") .. " :",
        title_align  = "left",
        width_factor = WIDTHFACTOR,
        buttons = buttons,
        tap_close_callback = function()
            if on_close then on_close() end
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

    local action_defs = ActionDefs.getMerged(config.custom_actions)

    local sort_items = {}
    for _, id in ipairs(section.items) do
        local def = action_defs[id]
        if def then
            local is_currently_visible = (not def.visible_func or def.visible_func(ctx))
            -- btn doesnt't support svg
            local label = (Utils.get_safe_icon(def.icon) or "") .. " " .. (def.label or _("None")) .. (not is_currently_visible and " (n/a)" or "")
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
            Config.saveAndRefresh(ctx)
        end
    })
end


return ActionManage
