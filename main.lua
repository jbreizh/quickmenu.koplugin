-- Quick Menu tab for KOReader top menu
-- Adds a new tab at the far left with Wi-Fi, action buttons, and frontlight/warmth sliders.
-- Works in both File Manager and Book Reader views.

require("common/inject_icons")

-- ============================================================
-- Definition
-- ============================================================
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local QuickMenu = require("quickmenu")

local QuickMenuPlugin = WidgetContainer:extend{ name = "quickmenu_plugin" }

-- ============================================================
-- Configuration
-- ============================================================
local Config = require("config")

local config = Config.load()
local function saveConfig() Config.save(config) end

-- ============================================================
-- Hook TouchMenu to support panel tabs
-- ============================================================
local UIManager     = require("ui/uimanager")
local Geom          = require("ui/geometry")
local Device        = require("device")
local Screen        = Device.screen
local TouchMenu = require("ui/widget/touchmenu")
local FocusManager = require("ui/widget/focusmanager")
local GestureRange = require("ui/gesturerange")
local datetime = require("datetime")
local BD = require("ui/bidi")


-- Hook init to
local orig_init = TouchMenu.init
function TouchMenu:init(...)

    -- increase menu size to 20
    self.max_per_page_default = config.items_per_page or 20

    -- store orig_page for initial_pos_marker in skim to survive redraw
    self.skim_orig_page = nil

    -- force quick menu first
    if config.open_on_start then
        self.last_index = 1
    end

    orig_init(self, ...)

    -- 3. Ton code de patch Exit Button (Mapping des icon_widgets)
    if self.bar and self.bar.icon_widgets and config.add_exit_tab then
        for i, tab in ipairs(self.tab_item_table) do
            if tab.id == "exit_tab" and tab.hold_callback then
                local icon_button = self.bar.icon_widgets[i]
                if icon_button then
                    icon_button.hold_callback = function(...)
                        tab.hold_callback(...)
                    end
                end
                break
            end
        end
    end

    -- Pre-set image.dimen on bar icon buttons so widgetInvert doesn't crash
    -- if a tap arrives before the first paint (nil dimen on IconWidget).
    if self.bar and type(self.bar.icon_widgets) == "table" then
        for _, btn in ipairs(self.bar.icon_widgets) do
            if btn and btn.image and not btn.image.dimen then
                local ok_sz, sz = pcall(function() return btn.image:getSize() end)
                if ok_sz and sz then
                    btn.image.dimen = Geom:new{ w = sz.w, h = sz.h }
                end
            end
        end
    end
    -- Register a screen-wide hold gesture for panel button hold_callback
    -- screen_size may be nil on some devices (e.g. KindleBasic5)
    local sw = (self.screen_size and self.screen_size.w) or Screen:getWidth()
    local sh = (self.screen_size and self.screen_size.h) or Screen:getHeight()

    self.ges_events.HoldCloseAllMenus = {
        GestureRange:new{
            ges = "hold",
            range = Geom:new{ x = 0, y = 0, w = sw, h = sh },
        }
    }
    self.ges_events.PanCloseAllMenus = {
        GestureRange:new{
            ges = "pan",
            range = Geom:new{ x = 0, y = 0, w = sw, h = sh },
        }
    }
    self.ges_events.PanReleaseCloseAllMenus = {
        GestureRange:new{
            ges = "pan_release",
            range = Geom:new{ x = 0, y = 0, w = sw, h = sh },
        }
    }
    self.ges_events.MultiSwipe = {
        GestureRange:new{
            ges = "multiswipe",
            range = Geom:new{ x = 0, y = 0, w = sw, h = sh },
        }
    }
end

-- Hook updateItems for panel rendering
local orig_updateItems = TouchMenu.updateItems
function TouchMenu:updateItems(target_page, target_item_id)
    if not self.item_table or not self.item_table.panel then
        self._qs_refs = nil -- clear refs when switching away from panel tab
        return orig_updateItems(self, target_page, target_item_id)
    end

    -- Custom panel mode: render the panel widget instead of menu items
    self.item_group:clear()
    self.layout = {}
    table.insert(self.item_group, self.bar)
    table.insert(self.layout, self.bar.icon_widgets)

    -- Build panel (also sets self._qs_refs)
    local panel_fn = self.item_table.panel
    local panel = type(panel_fn) == "function" and panel_fn(self) or panel_fn
    table.insert(self.item_group, panel)

    -- Footer (no pagination, just time/battery)
    table.insert(self.item_group, self.footer_top_margin)
    table.insert(self.item_group, self.footer)
    self.page_info_text:setText("")
    self.page_info_left_chev:showHide(false)
    self.page_info_right_chev:showHide(false)
    self.page_info_left_chev:enableDisable(false)
    self.page_info_right_chev:enableDisable(false)
    self.page_num = 1
    self.page = 1

    -- Update footer
    local time_info_txt = ""
    if config.footer.enabled then -- advance footer
        time_info_txt = QuickMenu.get_footer_text(config)
    else -- default footer
        time_info_txt = datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock"))
        local powerd = Device:getPowerDevice()
        if Device:hasBattery() then
            local batt_lvl = powerd:getCapacity()
            local batt_symbol = powerd:getBatterySymbol(powerd:isCharged(), powerd:isCharging(), batt_lvl)
            time_info_txt = BD.wrap(time_info_txt) .. " " .. BD.wrap("⌁") .. BD.wrap(batt_symbol) ..  BD.wrap(batt_lvl .. "%")
            if Device:hasAuxBattery() and powerd:isAuxBatteryConnected() then
                local aux_batt_lvl = powerd:getAuxCapacity()
                local aux_batt_symbol = powerd:getBatterySymbol(powerd:isAuxCharged(), powerd:isAuxCharging(), aux_batt_lvl)
                time_info_txt = time_info_txt .. " " .. BD.wrap("+") .. BD.wrap(aux_batt_symbol) ..  BD.wrap(aux_batt_lvl .. "%")
            end
        end
    end
    self.time_info:setText(time_info_txt)

    -- Recalculate dimen
    local old_dimen = self.dimen:copy()
    self.dimen.w = self.width
    self.dimen.h = self.item_group:getSize().h + self.bordersize * 2 + self.padding
    self:moveFocusTo(self.cur_tab, 1, FocusManager.NOT_FOCUS)

    local keep_bg = old_dimen and self.dimen.h >= old_dimen.h
    UIManager:setDirty((self.is_fresh or keep_bg) and self.show_parent or "all", function()
        local refresh_dimen = old_dimen and old_dimen:combine(self.dimen) or self.dimen
        local refresh_type = "ui"
        if self.is_fresh then
            refresh_type = "flashui"
            self.is_fresh = false
        end
        return refresh_type, refresh_dimen
    end)
end

-- Gesture handler for panel taps/pans
local function handlePanelGesture(touch_menu, ges, is_hold)
    local refs = touch_menu._qs_refs
    if not refs then return false end

    -- SLIDERS (GENERIC)
    if refs.sliders then
        for _, s in ipairs(refs.sliders) do
            local w = s.widget
            if w and w.dimen and ges.pos:intersectWith(w.dimen) then

                -- preferred API: slider defines its own conversion
                local percent

                if w.getPercentageFromPosition then
                    percent = w:getPercentageFromPosition(ges.pos)
                end

                if percent then
                    local value

                    if s.fromPercent then
                        value = s.fromPercent(percent)
                    else
                        value = math.floor(
                            (s.max - s.min) * percent + s.min + 0.5
                        )
                    end

                    if s.set then
                        s.set(value)
                        return true
                    end
                end
            end
        end
    end

    -- BUTTONS (GENERIC) maybe useful
--    if refs.buttons then
--        for _, b in ipairs(refs.buttons) do
--            local w = b.widget-
--            if w and w.dimen and ges.pos:intersectWith(w.dimen) then
--                if is_hold and b.hold_callback then
--                    b.hold_callback()
--                    return true
--                elseif not is_hold and b.callback then
--                    b.callback(touch_menu)
--                    return true
--                elseif not is_hold then
--                    return true -- swallow tap
--                end
--                return false
--            end
--        end
--    end
    return false
end

-- Hook onTapCloseAllMenus to intercept taps on panel widgets
local orig_onTapCloseAllMenus = TouchMenu.onTapCloseAllMenus
function TouchMenu:onTapCloseAllMenus(arg, ges_ev)
    if self._qs_refs and self.item_table and self.item_table.panel then
        if handlePanelGesture(self, ges_ev, false) then
            return true
        end
    end
    return orig_onTapCloseAllMenus(self, arg, ges_ev)
end

-- Hook onHoldCloseAllMenus to intercept holds on panel buttons
function TouchMenu:onHoldCloseAllMenus(arg, ges_ev)
    if self._qs_refs and self.item_table and self.item_table.panel then
        handlePanelGesture(self, ges_ev, true)
    end
    -- Holds outside the menu do nothing (don't close it)
    return true
end

-- Safety guards: onPrevPage / onNextPage crash when self.page is nil in panel mode (no pagination).  Consume silently.
local orig_onPrevPage = TouchMenu.onPrevPage
if orig_onPrevPage then
    function TouchMenu:onPrevPage()
        if self.item_table and self.item_table.panel then
            return true
        end
        return orig_onPrevPage(self)
    end
end

local orig_onNextPage = TouchMenu.onNextPage
if orig_onNextPage then
    function TouchMenu:onNextPage()
        if self.item_table and self.item_table.panel then
            return true
        end
        return orig_onNextPage(self)
    end
end

-- ============================================================
-- Inject functions
-- ============================================================
local function is_injected(list, id)
    for _, v in ipairs(list) do
        if v == id then return true end
    end
    return false
end

-- ============================================================
-- Inject FileManagerMenu
-- ============================================================
local FileManagerMenu = require("apps/filemanager/filemanagermenu")
local FileManagerMenuOrder = require("ui/elements/filemanager_menu_order")
local BD = require("ui/bidi")

local orig_fm_setUpdateItemTable = FileManagerMenu.setUpdateItemTable

function FileManagerMenu:setUpdateItemTable()
    -- inject settings
    if not is_injected(FileManagerMenuOrder.setting, "quick_menu_config") then
        table.insert(FileManagerMenuOrder.setting, "----------------------------")
        table.insert(FileManagerMenuOrder.setting, "quick_menu_config")
    end
    self.menu_items.quick_menu_config = QuickMenu.buildSettingsMenu(config, saveConfig, self)

    -- inject ori
    orig_fm_setUpdateItemTable(self)

    -- tab
    if self.tab_item_table then
        QuickMenu.updateTab(config, self)
    end
end

-- don't open last tab when exit_tab is insert
function FileManagerMenu:_getTabIndexFromLocation(ges)
    if self.tab_item_table == nil then
        self:setUpdateItemTable()
    end
    local last_tab_index = G_reader_settings:readSetting("filemanagermenu_tab_index") or 1
    -- If exit_tab is present, exclude it from the navigation boundary (-1).
    local nav_limit = config.add_exit_tab and (#self.tab_item_table - 1) or #self.tab_item_table
    if not ges then
        return last_tab_index
    -- if the start position is far right
    elseif ges.pos.x > Screen:getWidth() * (2/3) then
        return BD.mirroredUILayout() and 1 or nav_limit
    -- if the start position is far left
    elseif ges.pos.x < Screen:getWidth() * (1/3) then
        return BD.mirroredUILayout() and nav_limit or 1
    -- if center return the last index
    else
        return last_tab_index
    end
end

-- ============================================================
-- Inject ReaderMenu
-- ============================================================
local ReaderMenu = require("apps/reader/modules/readermenu")
local ReaderMenuOrder = require("ui/elements/reader_menu_order")

local orig_reader_setUpdateItemTable = ReaderMenu.setUpdateItemTable

function ReaderMenu:setUpdateItemTable()
    -- inject settings
    if not is_injected(ReaderMenuOrder.setting, "quick_menu_config") then
        table.insert(ReaderMenuOrder.setting, "quick_menu_config")
    end
    self.menu_items.quick_menu_config = QuickMenu.buildSettingsMenu(config, saveConfig, self)
    -- inject ori
    orig_reader_setUpdateItemTable(self)

    -- tab
    if self.tab_item_table then
        QuickMenu.updateTab(config, self)
    end
end

-- don't open last tab when exit_tab is insert
function ReaderMenu:_getTabIndexFromLocation(ges)
    if self.tab_item_table == nil then
        self:setUpdateItemTable()
    end
    -- If exit_tab is present, exclude it from the navigation boundary (-1).
    local nav_limit = config.add_exit_tab and (#self.tab_item_table - 1) or #self.tab_item_table
    if not ges then
        return self.last_tab_index
    -- if the start position is far right
    elseif ges.pos.x > Screen:getWidth() * (2/3) then
        return BD.mirroredUILayout() and 1 or nav_limit
    -- if the start position is far left
    elseif ges.pos.x < Screen:getWidth() * (1/3) then
        return BD.mirroredUILayout() and nav_limit or 1
    -- if center return the last index
    else
        return self.last_tab_index
    end
end


-- Init Plugin
function QuickMenuPlugin:init()
    self.config = config
end

return QuickMenuPlugin
