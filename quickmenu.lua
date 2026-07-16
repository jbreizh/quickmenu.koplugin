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

local ActionCustom  = require("action_custom")
local Config        = require("config")
local Utils         = require("common/utils")
local _             = require("common/i18n").gettext


local QuickMenu = {
    label = _("Quick menu")
}

-- ============================================================
-- Shared Context Builder
-- ============================================================
local function buildContext(config, touch_menu)
    local panel_width = touch_menu and touch_menu.item_width or 0
    local padding = Screen:scaleBySize(config.style.padding or 10)
    local inner_width = panel_width - padding * 2

    return {
        config      = config,
        touch_menu  = touch_menu,
        reader      = ReaderUi.instance,
        filemanager = FileManager.instance,
        device      = Device,
        powerd      = Powerd,
        screen      = Screen,
        datetime    = Datetime,
        stat        = Utils.systemInfo(),
        panel_width = panel_width,
        inner_width = inner_width,
    }
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

function QuickMenu.createPanel(config, touch_menu)
    local refs = { buttons = {}, sliders = {}, widgets = {} }
    local ctx = buildContext(config, touch_menu)

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
            local ok_build, result = pcall(section_mod.build, ctx)
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


function QuickMenu.updateTab(config, menu_instance, is_filemanager)
    if not (menu_instance and menu_instance.tab_item_table)  then return end
    local tabs = menu_instance.tab_item_table
    --local is_filemanager = (type(menu_instance.onCloseFileManagerMenu) == "function")

    -- quick_menu_tab
    manage_tab(tabs, "quick_menu_tab", {
        id = "quick_menu_tab",
        icon = "home",
        remember = function() return not config.open_on_start end,
        callback = function()
            print("callback")
        end,
        hold_callback = function()
            menu_instance:onCloseFileManagerMenu()
            print("hold_callback")
        end,
        panel = function(touch_menu) print("panel"); return QuickMenu.createPanel(config, touch_menu) end,
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

function QuickMenu.buildStyleSubMenu(config)
    local style_items = {}

    -- style
    local style_keys = {}
    for key in pairs(Config.DEFAULTS.style) do
        table.insert(style_keys, key)
    end
    table.sort(style_keys)

    for i, key in ipairs(style_keys) do
        table.insert(style_items, {
            text_func = function() return key .. " (" .. tostring(config.style[key]) .. ")"  end,
            keep_menu_open = true,
            callback = function(touch_menu)
                local original = config.style[key]
                local function getValue() return config.style[key] end
                local function setValue(v) config.style[key] = math.max(0, math.min(150, v)); Config.save(config) end
                local function rebuild() if touch_menu and touch_menu.updateItems then touch_menu:updateItems() end end

                local dialog
                local function nudge(delta)
                    local newVal = getValue() + delta
                    newVal = math.floor(newVal * 10 + 0.5) / 10
                    setValue(newVal)
                    rebuild()
                    dialog:reinit()
                end

                local function close() UIManager:close(dialog) end
                local function revert() setValue(original); rebuild() end

                dialog = ButtonDialog:new{
                    dismissable = false,
                    title = key,
                    buttons = {
                        {
                            { text = "-10",  callback = function() nudge(-10) end },
                            { text = "-1",   callback = function() nudge(-1)  end },
                            { text = "-0.1", callback = function() nudge(-0.1) end },
                            { text_func = function() return tostring(getValue()) end, enabled = false },
                            { text = "+0.1", callback = function() nudge(0.1)   end },
                            { text = "+1",   callback = function() nudge(1)   end },
                            { text = "+10",  callback = function() nudge(10)  end },
                        },
                        {
                            { text = _("Cancel"), callback = function() revert(); close() end },
                            { text = _("Default"),callback = function() setValue(Config.DEFAULTS.style[key]); rebuild(); dialog:reinit() end },
                            { text = _("Apply"), is_enter_default = true, callback = close },
                        },
                    },
                    tap_close_callback = revert
                }
                UIManager:show(dialog)
            end,
            separator = (i == #style_keys),
        })
    end

    -- reset
    table.insert(style_items, {
        text = _("Reset style to defaults"),
        keep_menu_open = true,
        callback = function(touch_menu)
            UIManager:show(ConfirmBox:new{
                text = _("Reset style to defaults") .. " ?",
                ok_text = _("Reset"),
                ok_callback = function()
                    config.style = {}
                    for key, value in pairs(Config.DEFAULTS.style) do
                        config.style[key] = value
                    end
                    Config.save(config)
                    if touch_menu and touch_menu.updateItems then touch_menu:updateItems() end
                end
            })
        end,
    })


    return style_items
end

function QuickMenu.buildSettingsMenu(config, menu_instance, is_filemanager)
    local menu_items = {}
    if not config.sections or type(config.sections) ~= "table" then
        logger.err("[QuickMenu] config.sections is missing or invalid in QuickMenu.buildSettingsMenu.")
        return { text = QuickMenu.label, sub_item_table = {} }
    end

    local ctx = buildContext(config, nil)

    -- global
    table.insert(menu_items, {
        text = _("Add exit tab"),
        checked_func = function() return config.add_exit_tab end,
        callback = function(touch_menu)
            config.add_exit_tab = not config.add_exit_tab
            -- save and refresh need to force close touch_menu
            Config.save(config)
            QuickMenu.updateTab(config, menu_instance, is_filemanager)
            touch_menu:closeMenu()
        end
    })

    table.insert(menu_items, {
        text = _("Add quick menu tab"),
        checked_func = function() return config.add_quickmenu_tab end,
        callback = function(touch_menu)
            config.add_quickmenu_tab = not config.add_quickmenu_tab
            -- save and refresh need to force close touch_menu
            Config.save(config)
            QuickMenu.updateTab(config, menu_instance, is_filemanager)
            touch_menu:closeMenu()
        end
    })

    table.insert(menu_items, {
        text = _("Always start on quick menu tab"),
        checked_func = function() return config.open_on_start end,
        callback = function()
            config.open_on_start = not config.open_on_start
            Config.save(config)
        end,
    })

    -- style
    table.insert(menu_items, {
        text = _("Style"),
        sub_item_table = QuickMenu.buildStyleSubMenu(config),
        separator = true,
    })

    -- sections order
    table.insert(menu_items, {
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
                    Config.save(config)
                end
            })
        end,
    })

    -- reset sections order
    table.insert(menu_items, {
        text = _("Reset sections order to default") .. "\xE2\x80\xA6",
        keep_menu_open = true,
        callback = function()
            UIManager:show(ConfirmBox:new{
                text = _("Reset sections order to defaults") .. " ?",
                ok_text = _("Reset"),
                ok_callback = function()
                    config.section_order = {}
                    for position, section_id in ipairs(Config.DEFAULTS.section_order) do
                        table.insert(config.section_order, section_id)
                    end
                    Config.save(config)
                end
            })
        end,
        separator = true
    })

    -- custom actions
    table.insert(menu_items, {
        text_func = function()
            local count = #(config.custom_actions or {})
            return _("Custom actions") .. " (" .. count .. ")\xE2\x80\xA6"
        end,
        keep_menu_open = true,
        callback = function(touch_menu)
            if touch_menu then ctx.touch_menu = touch_menu end
            ActionCustom:showActionCustomMenu(ctx)
        end
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
                return section_mod.getSettings(ctx,
                    function(fn) return fn end, -- noop_close
                    function() end,             -- noop_refresh
                    function() end              -- noop_reload
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

    -- reset quickmenu
    table.insert(menu_items, {
        text = _("Reset quick menu to defaults") .. "\xE2\x80\xA6",
        keep_menu_open = true,
        callback = function(touch_menu)
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
                    -- save and refresh need to force close touch_menu
                    Config.save(config)
                    QuickMenu.updateTab(config, menu_instance, is_filemanager)
                    touch_menu:closeMenu()
                end
            })
        end
    })

    return {
        text = QuickMenu.label,
        sorting_hint = "setting",
        sub_item_table = menu_items,
    }
end

return QuickMenu
