local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan  = require("ui/widget/verticalspan")

local ReaderUi      = require("apps/reader/readerui")
local FileManager   = require("apps/filemanager/filemanager")
local Device        = require("device")
local Powerd        = Device:getPowerDevice()
local Screen        = Device.screen
local Datetime      = require("datetime")

local ConfirmBox    = require("ui/widget/confirmbox")
local InputDialog   = require("ui/widget/inputdialog")
local ButtonDialog  = require("ui/widget/buttondialog")
local SortWidget    = require("ui/widget/sortwidget")

local UIManager     = require("ui/uimanager")
local Event         = require("ui/event")

local logger        = require("logger")

local StyleManage   = require("style_manage")
local ActionCustom  = require("action_custom")
local Config        = require("config")
local Utils         = require("common/utils")
local _             = require("common/i18n").gettext


local QuickMenu = {
    id    = "quickmenu",
    label = _("Quick menu"),
    icon  = "\u{ED9F}" -- home-outline
}

-- ============================================================
-- Shared Context Builder
-- ============================================================
function QuickMenu.updatePlugin(plugin)
    plugin.reader      = ReaderUi.instance
    plugin.filemanager = FileManager.instance
    plugin.device      = Device
    plugin.powerd      = Device:getPowerDevice()
    plugin.screen      = Screen
    plugin.datetime    = Datetime
    plugin.stat        = Utils.systemInfo()
    plugin.panel_width = (plugin.touch_menu and plugin.touch_menu.item_width) or 0
    local padding      = Screen:scaleBySize(plugin.config.style.padding or 10)
    plugin.inner_width = plugin.panel_width - padding * 2
end


-- ============================================================
-- Panel Builder
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

function QuickMenu.createPanel(plugin)
    local refs = { buttons = {}, sliders = {}, widgets = {} }
    QuickMenu.updatePlugin(plugin) -- update plugin = ctx in section
    --
    local config = plugin.config
    local touch_menu = plugin.touch_menu

    if not config.section_order or type(config.section_order) ~= "table" then
        logger.err("[QuickMenu] config.section_order is missing or invalid in QuickMenu.createPanel.")
        return VerticalGroup:new{}
    end

    local panel = VerticalGroup:new{
        align = "center",
        VerticalSpan:new{ width = Screen:scaleBySize( 2 ) } -- to not cover tab menu underline
    }

    local added_count = 0
    -- Utilisation de l'ordre défini dans le fichier de config
    for idx, id in ipairs(config.section_order) do
        local ok, section_mod = pcall(require, "sections/" .. id)
        if ok and section_mod and type(section_mod.build) == "function" then
            local ok_build, result = pcall(section_mod.build, plugin)
            if ok_build then
                if result and result.widget then
                    if added_count > 0 then
                        table.insert(panel, VerticalSpan:new{ width = Screen:scaleBySize(config.style.v_gap or 4) })
                    end
                    table.insert(panel, result.widget)
                    mergeRefs(refs, result.refs)
                    added_count = added_count + 1
                end
            else
                logger.err("[QuickMenu] Failed building section panel in section [" .. tostring(id) .. "]: " .. tostring(result))
            end
        else
            logger.err("[QuickMenu] Failed to load section module or missing 'build' method: " .. tostring(id))
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

local function manage_tab(tab_list, tab_id, tab_data, enabled, index)
    local current_idx = find_tab_index(tab_list, tab_id) -- search if tab is inserted
    if enabled then
        if not current_idx then
            local target = index or (#tab_list + 1)                     -- no index insert at the end
            if target < 0 then target = #tab_list + 1 + target end      -- begin at the end for neg index
            if target > #tab_list + 1 then target = #tab_list + 1 end   -- secure big index
            if target < 1 then target = 1 end                           -- secure small index
            table.insert(tab_list, target, tab_data)
        end
    else
        if current_idx then
            table.remove(tab_list, current_idx)
        end
    end
end

function QuickMenu.updateTab(plugin)
    --
    local config         = plugin.config
    local menu_instance  = plugin.menu_instance
    local is_filemanager = plugin.is_filemanager
    --
    if not (menu_instance and menu_instance.tab_item_table)  then
        logger.err("[QuickMenu] updateTab: menu_instance or tab_item_table not ready yet.")
        return
    end
    local tabs = menu_instance.tab_item_table
    -- quick_menu_tab
    manage_tab(tabs, "quick_menu_tab", {
        id = "quick_menu_tab",
        icon = "home",
        remember = function() return not config.open_on_start end,
        -- callback
        hold_callback = function() QuickMenu.showSettings(plugin) end,
        panel = function() return QuickMenu.createPanel(plugin) end,
    }, config.add_quickmenu_tab, config.idx_quickmenu_tab or 1) -- when add_quickmenu_tab -> first position

    -- exit_tab
    manage_tab(tabs, "exit_tab", {
        id = "exit_tab",
        icon = "exit",
        remember = false,
        callback = function()
            if is_filemanager then menu_instance:onCloseFileManagerMenu() else menu_instance:onTapCloseMenu() end
        end,
        hold_callback = function()
            if is_filemanager then
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
    }, config.add_exit_tab) -- when add_exit_tab -> last position

    -- filemanager_tab
    manage_tab(tabs, "filemanager", {
        id = "filemanager",
        icon = "appbar.filebrowser",
        remember = false,
        callback = function()
            menu_instance:onTapCloseMenu()
            local file = menu_instance.ui.document and menu_instance.ui.document.file
            menu_instance.ui:onClose()
            if file then menu_instance.ui:showFileManager(file) end
        end
    }, (not config.add_exit_tab and not is_filemanager), -1) -- not add_exit_tab and not fm -> last position - 1
end

function QuickMenu.buildGlobalSubmenu(plugin, close, refresh)
    --
    local config         = plugin.config
    local menu_instance  = plugin.menu_instance
    local is_filemanager = plugin.is_filemanager
    --
    local global_items = {}
    table.insert(global_items, {
        text = _("Add exit tab"),
        checked_func = function() return config.add_exit_tab end,
        callback = close(function()
            config.add_exit_tab = not config.add_exit_tab
            Config.save(config)
            QuickMenu.updateTab(plugin)
            -- close touch_menu
            if plugin.is_filemanager then  plugin.menu_instance:onCloseFileManagerMenu()
            else plugin.menu_instance:onCloseReaderMenu() end
            -- open touch_menu
            UIManager:nextTick(function()
                plugin.menu_instance:onShowMenu()
                if refresh then refresh() end
            end)
        end),
    })

    table.insert(global_items, {
        text = _("Add quick menu tab"),
        checked_func = function() return config.add_quickmenu_tab end,
        callback = close(function()
            config.add_quickmenu_tab = not config.add_quickmenu_tab
            Config.save(config)
            QuickMenu.updateTab(plugin)
            -- close touch_menu
            if plugin.is_filemanager then  plugin.menu_instance:onCloseFileManagerMenu()
            else plugin.menu_instance:onCloseReaderMenu() end
            -- open touch_menu
            UIManager:nextTick(function()
                plugin.menu_instance:onShowMenu()
                if refresh then refresh() end
            end)

        end),
    })

    table.insert(global_items, {
        text = _("Always start on quick menu tab"),
        checked_func = function() return config.open_on_start end,
        callback = function()
            config.open_on_start = not config.open_on_start
            --Config.save(config)
            Config.saveAndRefresh(plugin) -- WARNING plugin remplace ctx
        end,
    })

    -- style
    table.insert(global_items, {
        text = _("Style") .. "\xE2\x80\xA6",
        keep_menu_open = true,
        callback = close(function()
            StyleManage:showStyleDialog(plugin, refresh) -- WARNING plugin remplace ctx
        end),
    })

    -- custom actions
    table.insert(global_items, {
        text_func = function()
            local count = #(config.custom_actions or {})
            return _("Custom actions") .. " (" .. count .. ")\xE2\x80\xA6"
        end,
        keep_menu_open = true,
        callback = close(function()
            ActionCustom:showActionCustomMenu(plugin, refresh) -- WARNING plugin remplace ctx
        end),

    })

    -- sections order
    table.insert(global_items, {
        text = _("Sort sections") .. "\xE2\x80\xA6",
        keep_menu_open = true,
        callback = function()
            local sort_sections = {}
            for index, section_id in ipairs(config.section_order) do
                local ok, section_mod = pcall(require, "sections/" .. section_id)
                local icon = (ok and section_mod.icon) and (section_mod.icon .. " ") or ""
                local label = (ok and section_mod.label) and section_mod.label or section_id
                table.insert(sort_sections, { text = icon .. " " .. label, id = section_id })
            end

            UIManager:show(SortWidget:new{
                title = _("Sort sections") .. " :",
                item_table = sort_sections,
                callback = function()
                    config.section_order = {}
                    for index, section in ipairs(sort_sections) do
                        table.insert(config.section_order, section.id)
                    end
                    -- Config.save(config)
                    Config.saveAndRefresh(plugin) -- WARNING plugin remplace ctx
                end
            })
        end,
    })

    -- reset sections order
    table.insert(global_items, {
        text = _("Reset sections order to default") .. "\xE2\x80\xA6",
        keep_menu_open = true,
        callback = close(function()
            UIManager:show(ConfirmBox:new{
                text = _("Reset sections order to defaults") .. " ?",
                ok_text = _("Reset"),
                ok_callback = function()
                    config.section_order = {}
                    for position, section_id in ipairs(Config.DEFAULTS.section_order) do
                        table.insert(config.section_order, section_id)
                    end
                    --Config.save(config)
                    Config.saveAndRefresh(plugin) -- WARNING plugin remplace ctx
                    if refresh then refresh() end
                end,
                cancel_callback = function()
                    if refresh then refresh() end
                end,
            })
        end),
        separator = true,
    })

        -- reset quickmenu
    table.insert(global_items, {
        text = _("Reset quick menu to defaults") .. "\xE2\x80\xA6",
        keep_menu_open = true,
        callback = close(function()
            UIManager:show(ConfirmBox:new{
                text = _("Reset quick menu to defaults") .. " ?",
                ok_text = _("Reset"),
                ok_callback = function()
                    -- global
                    config.add_exit_tab = Config.DEFAULTS.add_exit_tab
                    config.add_quickmenu_tab = Config.DEFAULTS.add_quickmenu_tab
                    config.open_on_start = Config.DEFAULTS.open_on_start

                    -- section order
                    config.section_order = {}
                    for index, section_id in ipairs(Config.DEFAULTS.section_order) do
                        table.insert(config.section_order, section_id)
                    end

                    -- sections
                    for section_id, section_default in pairs(Config.DEFAULTS.sections) do
                        local section_config = Utils.getSection(config, section_id)
                        if section_config then
                            Utils.resetSectionToDefaults(section_config, section_default)
                        end
                    end

                    -- style
                    config.style = {}
                    for key, value in pairs(Config.DEFAULTS.style) do
                        config.style[key] = value
                    end
                    -- custom_actions
                    --config.custom_actions = {} --TODO don't reset custom_actions ??????
                    Config.save(config)
                    QuickMenu.updateTab(plugin)
                    -- close touch_menu
                    if plugin.is_filemanager then  plugin.menu_instance:onCloseFileManagerMenu()
                    else plugin.menu_instance:onCloseReaderMenu() end
                    -- open touch_menu
                    UIManager:nextTick(function()
                        plugin.menu_instance:onShowMenu()
                        if refresh then refresh() end
                    end)
                end,
                cancel_callback = function()
                    if refresh then refresh() end
                end,
            })
        end),
    })

    return global_items
end

function QuickMenu.buildSettingsMenu(plugin)
    --
    local config         = plugin.config
    local menu_instance  = plugin.menu_instance
    local is_filemanager = plugin.is_filemanager
    --
    if not config.sections or type(config.sections) ~= "table" then
        logger.err("[QuickMenu] config.sections is missing or invalid in QuickMenu.buildSettingsMenu.")
        return { text = QuickMenu.label, sub_item_table = {} }
    end

    -- global
    local menu_items = {}
    table.insert(menu_items, {
        text = QuickMenu.label,
        sub_item_table = QuickMenu.buildGlobalSubmenu(plugin,
            function(fn) return fn end, -- noop_close
            function() end             -- noop_refresh
        ),
    })

    --sections :grab sections list, sort it and build menu
    local sort_sections = {}
    for section_id, section_data in pairs(config.sections) do
        local ok, section_mod = pcall(require, "sections/" .. section_id)
        if ok and section_mod then
            table.insert(sort_sections, {id = section_id, label = section_mod.label or section_id})
        else
            logger.err("[QuickMenu] Failed to load section : " .. tostring(section_id))
        end
    end
    Utils.sort_by_field(sort_sections, "label", true, true) --natural sort taking care of accent

    for idx, section in ipairs(sort_sections) do
        local ok, section_mod = pcall(require, "sections/" .. section.id)

        if ok and section_mod and section_mod.getSettings then
            local success, items = pcall(function()
                QuickMenu.updatePlugin(plugin) -- need to update or device won't be set for frontlight
                return section_mod.getSettings(plugin, -- WARNING need complete plugin/ctx
                    function(fn) return fn end, -- noop_close
                    function() end             -- noop_refresh
                )
            end)

            if success then
                if items and #items > 0 then
                    table.insert(menu_items, {
                        text = section.label,
                        sub_item_table = items,
                        separator = (idx == #sort_sections),
                    })
                end
            elseif not success then
                logger.err("[QuickMenu] Failed building settings in section [" .. tostring(section.id) .. "]: " .. tostring(items))
            end
        else
            logger.err("[QuickMenu] Failed to load section : " .. tostring(section.id))
        end
    end

    return {
        text = QuickMenu.label,
        sorting_hint = "setting",
        sub_item_table = menu_items,
    }
end

function QuickMenu.showSettings(plugin)
    --
    local config         = plugin.config
    local menu_instance  = plugin.menu_instance
    local is_filemanager = plugin.is_filemanager
    --
    local dialog

    local function close(fn)
        return function()
            if dialog then UIManager:close(dialog) end
            if fn then fn() end
        end
    end

    local function refresh()
        QuickMenu.showSettings(plugin)
    end

    local buttons = Utils.wrap_items(QuickMenu.buildGlobalSubmenu(plugin, close, refresh))

    -- Ajout du bouton de sortie en bas
    table.insert(buttons, {}) -- séparateur
    table.insert(buttons, {{
        text = _("Exit"),
        callback = close()
    }})

    dialog = ButtonDialog:new{
        title = QuickMenu.icon .. " " .. QuickMenu.label .. " :",
        title_align  = "left",
        width_factor = 0.9,
        buttons = buttons,
        tap_close_callback = close()
    }

    UIManager:show(dialog)
end

return QuickMenu
