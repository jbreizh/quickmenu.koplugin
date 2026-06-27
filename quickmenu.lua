local Device        = require("device")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan  = require("ui/widget/verticalspan")
local ReaderUi      = require("apps/reader/readerui")
local FileManager   = require("apps/filemanager/filemanager")
local Screen        = Device.screen
local Size          = require("ui/size")
local UIManager     = require("ui/uimanager")
local ConfirmBox    = require("ui/widget/confirmbox")
local Event         = require("ui/event")
local Blitbuffer    = require("ffi/blitbuffer")
local BD            = require("ui/bidi")

local FooterDefs    = require("footer_defs")
local Config        = require("config")
local Utils         = require("common/utils")
local Translation   = require("i18n/translation")
local _             = Translation._

local QuickMenu = {}

local ORDER = { "actions", "frontlight", "shortcuts", "info" }

local SECTIONS = {
    actions    = require("sections/actions"),
    frontlight = require("sections/frontlight"),
    shortcuts  = require("sections/shortcuts"),
    info       = require("sections/info"),
}

local SECTION_LABELS = {
    actions    = _("Actions"),
    frontlight = _("Frontlight"),
    shortcuts  = _("Shortcuts"),
    info       = _("Informations"),
}


function QuickMenu.get_footer_text(config)
    local footer_cfg = config.footer or Config.DEFAULTS.footer
    local sep = footer_cfg.separator or ""
    local footer_defs = FooterDefs.get()
    local parts = {}

    for index = 1, #footer_cfg.items do
        local id = footer_cfg.items[index]
        local item_def = footer_defs[id]

        if item_def and (not item_def.visible_func or item_def.visible_func()) then
            local icon = item_def.unicode_func and item_def.unicode_func() or (item_def.unicode or "")
            local val = item_def.render and item_def.render() or ""
            local entry = BD.wrap(icon) .. " " .. BD.wrap(val)
            table.insert(parts, entry)
        end
    end

    return table.concat(parts, sep)
end


-- ============================================================
-- Helpers
-- ============================================================

local function mergeRefs(dst, src)
    if type(src) ~= "table" then return end
    for category, items in pairs(src) do
        if type(items) == "table" then
            dst[category] = dst[category] or {}
            for idx, item in ipairs(items) do
                table.insert(dst[category], item)
            end
        end
    end
end

-- ============================================================
-- Shared Context Builder
-- ============================================================
local function buildContext(config, touch_menu)
    local panel_width = touch_menu and touch_menu.item_width or 0
    local padding = Screen:scaleBySize(10)
    local inner_width = panel_width - padding * 2

    return {
        config = config,
        touch_menu = touch_menu,
        reader = ReaderUi.instance,
        filemanager = FileManager.instance,
        powerd = Device:getPowerDevice(),
        screen = Screen,
        panel_width = panel_width,
        inner_width = inner_width,
        theme = {
            gap = Screen:scaleBySize(4),
            vgap = Screen:scaleBySize(4),
            btn_width = Screen:scaleBySize(50),
            btn_radius = Size.radius.button,
            btn_bordersize = Size.border.button,
            btn_font_size = 16,
            slider_ticks_width = Size.line.medium,
            color_white = Blitbuffer.COLOR_WHITE,
            color_black = Blitbuffer.COLOR_BLACK,
            color_gray = Blitbuffer.COLOR_LIGHT_GRAY,
        }
    }
end

-- ============================================================
-- Panel Builder
-- ============================================================

function QuickMenu.createPanel(config, touch_menu)
    local refs = { buttons = {}, sliders = {}, widgets = {} }
    local ctx = buildContext(config, touch_menu)

    local panel = VerticalGroup:new{
        align = "center",
       VerticalSpan:new{ width = Screen:scaleBySize(12) }
    }

    local added_count = 0

    for idx, id in ipairs(ORDER) do
        local section_mod = SECTIONS[id]
        if section_mod and type(section_mod.build) == "function" then
            local ok, result = pcall(section_mod.build, ctx)
            if ok and result and result.widget then
                if added_count > 0 then
                    table.insert(panel, VerticalSpan:new{ width = Screen:scaleBySize(4) })
                end

                table.insert(panel, result.widget)
                mergeRefs(refs, result.refs)
                added_count = added_count + 1
            end
        end
    end

    touch_menu._qs_refs = refs
    return panel
end

-- ============================================================
-- Settings Menu Builder
-- ============================================================
local function find_tab_index(tab_list, id)
    for i, tab in ipairs(tab_list) do
        if tab.id == id then return i end
    end
    return nil
end

function QuickMenu.updateTab(config, menu_instance)
    if not menu_instance.tab_item_table then return end
    -- Déterminer le type de menu pour adapter le callback
    local is_fm = (type(menu_instance.onCloseFileManagerMenu) == "function")

    -- insert/remove quickmenu tab
    local quick_menu_idx = find_tab_index(menu_instance.tab_item_table, "quick_menu_tab")
    if config.add_quickmenu_tab and not quick_menu_idx then
         local quick_menu_tab = {
            id = "quick_menu_tab",
            icon = "home",
            remember = function() return not config.open_on_start end,-- Dynamique : si l'option est décochée, on autorise la mémorisation
            panel = function(touch_menu) return QuickMenu.createPanel(config, touch_menu) end
        }
        table.insert(menu_instance.tab_item_table, 1, quick_menu_tab)
    elseif not config.add_quickmenu_tab and quick_menu_idx then
            table.remove(menu_instance.tab_item_table, quick_menu_idx)
    end

    -- insert/remove exit tab
    local exit_idx = find_tab_index(menu_instance.tab_item_table, "exit_tab")
    if config.add_exit_tab and not exit_idx then
        table.insert(menu_instance.tab_item_table, {
            id = "exit_tab",
            icon = "exit",
            remember = false,
            callback = function()
                if is_fm then menu_instance:onCloseFileManagerMenu()
                else menu_instance:onTapCloseMenu() end
            end,
            hold_callback = function()
                if is_fm then
                    menu_instance:onCloseFileManagerMenu()
                    UIManager:show(ConfirmBox:new{
                        text = _("Are you sure you want to exit KOReader ?"),
                        ok_text = _("Exit"),
                        ok_callback = function() UIManager:broadcastEvent(Event:new("Exit")) end
                    })
                else
                    menu_instance:onTapCloseMenu()
                    UIManager:show(ConfirmBox:new{
                        text = _("Are you sure you want to exit book ?"),
                        ok_text = _("Exit"),
                        ok_callback = function()
                            local file = menu_instance.ui.document and menu_instance.ui.document.file
                            menu_instance.ui:onClose()
                            if file then menu_instance.ui:showFileManager(file) end
                        end
                    })
                end
            end
        })
    elseif not config.add_exit_tab and exit_idx then
        table.remove(menu_instance.tab_item_table, exit_idx)
    end

    -- insert/remove filemanager tab
    local fm_idx = find_tab_index(menu_instance.tab_item_table, "filemanager")
    if config.add_exit_tab and fm_idx then
        table.remove(menu_instance.tab_item_table, fm_idx)
    elseif not config.add_exit_tab and not fm_idx and not is_fm then
        table.insert(menu_instance.tab_item_table, #menu_instance.tab_item_table ,{
            id = "filemanager",
            icon = "appbar.filebrowser",
            remember = false,
            callback = function()
                menu_instance:onTapCloseMenu()
                local file = menu_instance.ui.document and menu_instance.ui.document.file
                menu_instance.ui:onClose()
                if file then menu_instance.ui:showFileManager(file) end
            end
        })
    end

end

-- Fonction locale pour remplacer Utils.contains
local function table_contains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end

-- Fonction locale pour remplacer Utils.removeElement
local function table_remove(tbl, val)
    for i, v in ipairs(tbl) do
        if v == val then
            table.remove(tbl, i)
            return true
        end
    end
    return false
end

function QuickMenu.getFooterSettings(config, saveConfig)
    local footer_defs = FooterDefs.get()
    config.footer = config.footer or {}
    config.footer.items = config.footer.items or {}
    local SortWidget = require("ui/widget/sortwidget")

-- 1. Créer une liste des IDs pour pouvoir les trier
    local sorted_ids = {}
    for id in pairs(footer_defs) do
        table.insert(sorted_ids, id)
    end

    -- Trier les IDs par le label correspondant dans footer_defs
    table.sort(sorted_ids, function(a, b)
        return footer_defs[a].label < footer_defs[b].label
    end)

    -- 2. Construire select_items en suivant l'ordre des IDs triés
    local select_items = {}
    for _, id in ipairs(sorted_ids) do
        local def = footer_defs[id]
        local is_currently_visible = (not def.visible_func or def.visible_func())
        local label = (def.unicode or "") .. " " .. def.label
        if not is_currently_visible then
            label = label .. " (n/a)"
        end

        table.insert(select_items, {
            text = label,
            -- sensitive = is_currently_visible,
            checked_func = function()
                return table_contains(config.footer.items, id)
            end,
            callback = function()
                if table_contains(config.footer.items, id) then
                    table_remove(config.footer.items, id)
                else
                    table.insert(config.footer.items, id)
                end
                saveConfig()
                return true
            end
        })
    end

    -- 2. Configuration du séparateur
    local sep_options = {" • ", " | ", " - ", " "}
    local sep_items = {}
    for _, s in ipairs(sep_options) do
        table.insert(sep_items, {
            text = "'" .. s .. "'",
            checked_func = function() return (config.footer.separator or " • ") == s end,
            callback = function() config.footer.separator = s; saveConfig(); return true end
        })
    end

    return {
        {
            text_func = function()
                local sep = config.footer.separator or ""
                return _("Separator") .. " (" .. sep .. ")"
            end,
            sub_item_table = sep_items,
            separator = true
        },
        {
            text_func = function()
                local count = #(config.footer.items or {})
                return _("Select controls") .. " (" .. count .. ")"
            end,
            sub_item_table = select_items
        },
        {
            text = _("Arrange controls"),
            keep_menu_open = true,
            callback = function()
                local sort_items = {}
                for _, id in ipairs(config.footer.items) do
                    local def = footer_defs[id]
                    local label = (def.unicode or "") .. " " .. def.label
                    local is_currently_visible = (not def.visible_func or def.visible_func())
                    if not is_currently_visible then
                        label = label .. " (n/a)"
                    end
                    if def then
                        table.insert(sort_items, { text = label, orig_item = id })
                    end
                end
                UIManager:show(SortWidget:new{
                    title = _("Arrange controls"),
                    item_table = sort_items,
                    callback = function()
                        config.footer.items = {}
                        for _, item in ipairs(sort_items) do
                            table.insert(config.footer.items, item.orig_item)
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
                        -- On écrase avec les valeurs par défaut
                        config.footer = {
                            items = Config.DEFAULTS.footer.items,
                            separator = Config.DEFAULTS.footer.separator
                        }
                        saveConfig()
                    end
                })
            end
        }
    }
end

function QuickMenu.buildSettingsMenu(config, saveConfig, menu_instance)
    local menu_items = {}
    local ctx = buildContext(config, nil)

    table.insert(menu_items, {
        text = _("Add exit tab"),
        checked_func = function() return config.add_exit_tab end,
        callback = function(touch_menu)
            config.add_exit_tab = not config.add_exit_tab
            saveConfig()
            QuickMenu.updateTab(config, menu_instance)
            touch_menu:closeMenu()
        end
    })

    table.insert(menu_items, {
        text = _("Add quick menu tab"),
        checked_func = function() return config.add_quickmenu_tab end,
        callback = function(touch_menu)
            config.add_quickmenu_tab = not config.add_quickmenu_tab
            saveConfig()
            QuickMenu.updateTab(config, menu_instance)
            touch_menu:closeMenu()
        end
    })

    table.insert(menu_items, {
        text = _("Always start on quick menu tab"),
        checked_func = function() return config.open_on_start end,
        callback = function()
            config.open_on_start = not config.open_on_start
            saveConfig()
        end,
        separator = true
    })

    for idx, id in ipairs(ORDER) do
        local section_mod = SECTIONS[id]
        if section_mod and section_mod.getSettings then

            local items = section_mod.getSettings(config, saveConfig, ctx)

            if items and #items > 0 then
                table.insert(menu_items, {
                    text = SECTION_LABELS[id] or id,
                    sub_item_table = items,
                })
            end
        end
    end

    table.insert(menu_items, {
        text = _("Footer"),
        sub_item_table = QuickMenu.getFooterSettings(config, saveConfig),
        separator = true
    })

    table.insert(menu_items, {
    text = _("Reset to defaults"),
    callback = function()
        UIManager:show(ConfirmBox:new{
            text = _("Are you sure you want to reset to defaults ?"),
            ok_text = _("Reset"),
            ok_callback = function()
                config.add_exit_tab = Config.DEFAULTS.add_exit_tab
                config.add_quickmenu_tab = Config.DEFAULTS.add_quickmenu_tab
                config.open_on_start = Config.DEFAULTS.open_on_start

                for index, section_id in ipairs(ORDER) do
                    if Config.DEFAULTS.sections[section_id] then
                        Utils.resetSectionToDefaults(
                            Utils.getSection(config, section_id),
                            Config.DEFAULTS.sections[section_id]
                        )
                    end
                end

                QuickMenu.updateTab(config, menu_instance)
                saveConfig()
            end
        })
    end
    })

    return {
        text = _("Quick menu"),
        sub_item_table = menu_items,
    }
end

return QuickMenu
