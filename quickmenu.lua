local Device        = require("device")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan  = require("ui/widget/verticalspan")
local ReaderUi      = require("apps/reader/readerui")
local FileManager   = require("apps/filemanager/filemanager")
local Screen        = Device.screen
local Size          = require("ui/size")
local UIManager  = require("ui/uimanager")
local ConfirmBox = require("ui/widget/confirmbox")
local Event      = require("ui/event")
local Blitbuffer    = require("ffi/blitbuffer")
local Utils         = require("common/utils")

local Translation = require("i18n/translation")
local _ = Translation._

local QuickMenu = {}

local ORDER = { "actions", "frontlight", "warmth", "shortcuts", "info", "skim" }

local SECTIONS = {
    actions    = require("sections/actions"),
    frontlight = require("sections/frontlight"),
    warmth     = require("sections/warmth"),
    shortcuts  = require("sections/shortcuts"),
    info       = require("sections/info"),
    skim       = require("sections/skim"),
}

local SECTION_LABELS = {
    actions = _("Actions"),
    frontlight = _("Frontlight"),
    warmth = _("Warmth"),
    shortcuts = _("Shortcuts"),
    info = _("Informations"),
    skim = _("Skim"),
}

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


function QuickMenu.buildSettingsMenu(config, saveConfig, menu_instance)
    local menu_items = {}
    local ctx = buildContext(config, nil)

    table.insert(menu_items, {
        text = _("Always start on quick menu tab"),
        checked_func = function() return config.open_on_start end,
        callback = function()
            config.open_on_start = not config.open_on_start
            saveConfig()
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
        text = _("Add exit tab"),
        checked_func = function() return config.add_exit_tab end,
        callback = function(touch_menu)
            config.add_exit_tab = not config.add_exit_tab
            saveConfig()
            QuickMenu.updateTab(config, menu_instance)
            touch_menu:closeMenu()
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

    return {
        text = _("Quick menu"),
        sub_item_table = menu_items,
    }
end

return QuickMenu
