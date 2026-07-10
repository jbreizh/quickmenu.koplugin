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

local UIManager     = require("ui/uimanager")
local Event         = require("ui/event")

local FrontlightPreset = require("frontlight_preset")
local ActionCustom     = require("action_custom")
local Config           = require("config")
local Utils            = require("common/utils")
local _                = require("common/i18n").gettext


local QuickMenu = {}

local ORDER = { "actions", "frontlight", "shortcuts", "info", "footer" }

local SECTIONS = {
    actions    = require("sections/actions"),
    frontlight = require("sections/frontlight"),
    shortcuts  = require("sections/shortcuts"),
    info       = require("sections/info"),
    footer     = require("sections/footer")
}

local SECTION_LABELS = {
    actions    = _("Actions"),
    frontlight = _("Frontlight"),
    shortcuts  = _("Shortcuts"),
    info       = _("Informations"),
    footer     = _("Footer")
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

    local panel = VerticalGroup:new{
        align = "center",
        VerticalSpan:new{ width = Screen:scaleBySize( 2 ) } -- to not cover tab menu underline
    }

    local added_count = 0

    for idx, id in ipairs(ORDER) do
        local section_mod = SECTIONS[id]
        if section_mod and type(section_mod.build) == "function" then
            local ok, result = pcall(section_mod.build, ctx)
            if ok and result and result.widget then
                if added_count > 0 then
                    table.insert(panel, VerticalSpan:new{ width = Screen:scaleBySize(config.style.v_gap or 4) })
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

function QuickMenu.buildStyleSubMenu(config, menu_instance)
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
        text = _("Reset to defaults"),
        keep_menu_open = true,
        callback = function(touch_menu)
            UIManager:show(ConfirmBox:new{
                text = _("Are you sure you want to reset to defaults ?"),
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

function QuickMenu.buildSettingsMenu(config, menu_instance)
    local menu_items = {}
    local ctx = buildContext(config, nil)

    -- global
    table.insert(menu_items, {
        text = _("Add exit tab"),
        checked_func = function() return config.add_exit_tab end,
        callback = function(touch_menu)
            config.add_exit_tab = not config.add_exit_tab
            Config.save(config)
            QuickMenu.updateTab(config, menu_instance)
            touch_menu:closeMenu()
        end
    })

    table.insert(menu_items, {
        text = _("Add quick menu tab"),
        checked_func = function() return config.add_quickmenu_tab end,
        callback = function(touch_menu)
            config.add_quickmenu_tab = not config.add_quickmenu_tab
            Config.save(config)
            QuickMenu.updateTab(config, menu_instance)
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
        --separator = true
    })

    -- custom actions
    table.insert(menu_items, {
        text_func = function()
            local count = #(config.custom_actions or {})
            return _("Custom actions") .. " (" .. count .. ")\xE2\x80\xA6"
        end,
        keep_menu_open = true,
        callback = function(touch_menu)
            ctx.touch_menu = touch_menu
            ActionCustom:showActionCustomMenu(ctx)
        end
    })

    -- preset
--     table.insert(menu_items, {
--         text = _("Frontlight presets"),
--         --keep_menu_open = true,
--         help_text = _("Author : peterboda236\nProjet : koreader-user-patches\nhttps://github.com/peterboda236/koreader-user-patches"),
--         callback = function(touch_menu)
--             FrontlightPreset:showFrontlightPresetMenu(config)
--         end
--     })

    -- style
    table.insert(menu_items, {
        text = _("Style"),
        sub_item_table = QuickMenu.buildStyleSubMenu(config, menu_instance),
        separator = true,
    })

    --sections
    for idx, id in ipairs(ORDER) do
        local section_mod = SECTIONS[id]
        if section_mod and section_mod.getSettings then

            local items = section_mod.getSettings(ctx,
                function(fn) return fn end, -- noop_close
                function() end,             -- noop_refresh
                id
            )

            if items and #items > 0 then
                local is_last = (idx == #ORDER)
                table.insert(menu_items, {
                    text = SECTION_LABELS[id] or id,
                    sub_item_table = items,
                    separator = is_last,
                })
            end
        end
    end

    -- reset
    table.insert(menu_items, {
    text = _("Reset to defaults"),
    callback = function()
        UIManager:show(ConfirmBox:new{
            text = _("Are you sure you want to reset to defaults ?"),
            ok_text = _("Reset"),
            ok_callback = function()
                -- global
                config.add_exit_tab = Config.DEFAULTS.add_exit_tab
                config.add_quickmenu_tab = Config.DEFAULTS.add_quickmenu_tab
                config.open_on_start = Config.DEFAULTS.open_on_start
                -- sections
                for index, section_id in ipairs(ORDER) do
                    if Config.DEFAULTS.sections[section_id] then
                        Utils.resetSectionToDefaults(
                            Utils.getSection(config, section_id),
                            Config.DEFAULTS.sections[section_id]
                        )
                    end
                end
                -- style
                config.style = {}
                for key, value in pairs(Config.DEFAULTS.style) do
                    config.style[key] = value
                end
                -- frontlight_preset
                --config.frontlight_presets = {} --TODO
                -- custom_actions
                --config.custom_actions = {} --TODO
                Config.save(config)
                QuickMenu.updateTab(config, menu_instance)
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
