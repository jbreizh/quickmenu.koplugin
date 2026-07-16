-- Quick Menu tab for KOReader top menu
-- Adds a new tab at the far left with Wi-Fi, action buttons, and frontlight/warmth sliders.
-- Works in both File Manager and Book Reader views.
-- require("common/inject_icons") can be use to inject svg icon (not use now)

-- ============================================================
-- Definition
-- ============================================================
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local QuickMenuPlugin = WidgetContainer:extend{
    config = nil,
    touch_menu = nil,
    menu_instance = nil,
    is_filemanager = nil,
}

-- touch_menu default_footer
local function default_footer()
    local BD = require("ui/bidi")
    local Device        = require("device")
    local Screen        = Device.screen
    local powerd = Device:getPowerDevice()
    local datetime = require("datetime")
    local default_footer = datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock"))
    if Device:hasBattery() then
        local batt_lvl = powerd:getCapacity()
        local batt_symbol = powerd:getBatterySymbol(powerd:isCharged(), powerd:isCharging(), batt_lvl)
        default_footer = BD.wrap(default_footer) .. " " .. BD.wrap("⌁") .. BD.wrap(batt_symbol) ..  BD.wrap(batt_lvl .. "%")
        if Device:hasAuxBattery() and powerd:isAuxBatteryConnected() then
            local aux_batt_lvl = powerd:getAuxCapacity()
            local aux_batt_symbol = powerd:getBatterySymbol(powerd:isAuxCharged(), powerd:isAuxCharging(), aux_batt_lvl)
            default_footer = default_footer .. " " .. BD.wrap("+") .. BD.wrap(aux_batt_symbol) ..  BD.wrap(aux_batt_lvl .. "%")
        end
    end
    return default_footer
end

-- grab zenslider
local function get_sliders(touch_menu)
    local refs = touch_menu._qs_refs
    if not refs then return {} end
    local sliders = {}
    for idx, sr in ipairs(refs.sliders or {}) do
        table.insert(sliders, sr.slider)
    end
    return sliders
end

-- Gesture handler for panel taps/pans
local function handlePanelGesture(touch_menu, ges, is_hold)
    local refs = touch_menu._qs_refs
    if not refs then return false end
    if not is_hold then
        for _i, sr in ipairs(refs.sliders or {}) do
            -- zen_slider
            if sr.slider and sr.slider:handleTap(ges) then return true end
            -- generic slider
            local w = sr.widget
            if w and w.dimen and ges.pos:intersectWith(w.dimen) then

                -- preferred API: slider defines its own conversion
                local percent

                if w.getPercentageFromPosition then percent = w:getPercentageFromPosition(ges.pos) end

                if percent then
                    local value

                    if sr.fromPercent then value = sr.fromPercent(percent)
                    else value = math.floor((sr.max - sr.min) * percent + sr.min + 0.5) end

                    if sr.set then sr.set(value) return true  end
                end
            end
        end
    end
    return false
end

-- ============================================================
-- Hook TouchMenu to support panel tabs
-- ============================================================
local function patchTouchMenu(plugin)
    local TouchMenu    = require("ui/widget/touchmenu")
    local UIManager    = require("ui/uimanager")
    local Geom         = require("ui/geometry")
    local FocusManager = require("ui/widget/focusmanager")
    local GestureRange = require("ui/gesturerange")
    local config       = plugin.config

    -- Hook init to
    local orig_init = TouchMenu.init
    function TouchMenu:init(...)
        --
        plugin.touch_menu = self

        -- increase menu size to 20
        self.max_per_page_default = config.items_per_page or 20

        -- store orig_page for initial_pos_marker in skim to survive redraw
        self.skim_orig_page = nil

        -- force quick menu first
        if config.open_on_start then
            self.last_index = config.idx_quickmenu_tab
        end

        orig_init(self, ...)

        -- add hold_callback on quick_menu_tab and exit_tab
        if self.bar and self.bar.icon_widgets then
            for i, tab in ipairs(self.tab_item_table) do
                local icon_button = self.bar.icon_widgets[i]

                if icon_button and tab.hold_callback then
                    -- On vérifie l'option pour l'exit_tab
                    if tab.id == "exit_tab" and config.add_exit_tab then
                        icon_button.hold_callback = function(...) tab.hold_callback(...) end
                    elseif tab.id == "quick_menu_tab" and config.add_quickmenu_tab then
                        icon_button.hold_callback = function(...) tab.hold_callback(...) end
                    end
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

        -- zenSlider
        if not self._qs_refs then
            self._qs_slider_locked = true
            UIManager:scheduleIn(0.35, function() self._qs_slider_locked = false end)
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
        self.time_info:setText(default_footer())

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

    -- Hook for zenSlider
    function TouchMenu:onPanCloseAllMenus(arg, ges_ev)
        if not (self._qs_refs and self.item_table and self.item_table.panel) then return end -- not in the panel
        if self._qs_slider_locked then self._qs_opening_pan = true; return end -- slider lock
        self._qs_opening_pan = false
        for _i, sl in ipairs(get_sliders(self)) do
            if sl:handlePan(ges_ev) then return true end
        end
    end

    function TouchMenu:onPanReleaseCloseAllMenus(arg, ges_ev)
        if not (self._qs_refs and self.item_table and self.item_table.panel) then return end -- not in the panel
        if self._qs_slider_locked or self._qs_opening_pan then self._qs_opening_pan = false; return end --slider lock
        for _i, sl in ipairs(get_sliders(self)) do
            if sl:handlePanRelease(ges_ev, self.show_parent, self.dimen) then return true end
        end
    end

    local orig_onSwipe = TouchMenu.onSwipe
    function TouchMenu:onSwipe(arg, ges_ev)
        if self._qs_refs and self.item_table and self.item_table.panel then -- in the panel
            if not self._qs_slider_locked then --slider lock
                for _i, sl in ipairs(get_sliders(self)) do
                    if sl:handleSwipe(ges_ev, self.show_parent, self.dimen) then return true end
                end
            end
            return true
        end
        if orig_onSwipe then return orig_onSwipe(self, arg, ges_ev) end
    end

    local orig_onMultiSwipe = TouchMenu.onMultiSwipe
    function TouchMenu:onMultiSwipe(arg, ges_ev)
        if self._qs_refs and self.item_table and self.item_table.panel then -- in the panel
            for _i, sl in ipairs(get_sliders(self)) do
                if sl:handleMultiSwipe(ges_ev, self.show_parent, self.dimen) then return true end
            end
            return true
        end
        if orig_onMultiSwipe then return orig_onMultiSwipe(self, arg, ges_ev) end
    end

    -- Hook onTapCloseAllMenus to intercept taps on panel widgets
    local orig_onTapCloseAllMenus = TouchMenu.onTapCloseAllMenus
    function TouchMenu:onTapCloseAllMenus(arg, ges_ev)
        if self._qs_refs and self.item_table and self.item_table.panel then
            if self._qs_slider_locked then return true end
            if handlePanelGesture(self, ges_ev, false) then return true end
        end
        return orig_onTapCloseAllMenus(self, arg, ges_ev)
    end

    -- Hook onHoldCloseAllMenus to intercept holds on panel buttons
    function TouchMenu:onHoldCloseAllMenus(arg, ges_ev)
        if self._qs_refs and self.item_table and self.item_table.panel then
            if not self._qs_slider_locked then handlePanelGesture(self, ges_ev, true) end
        end
        -- Holds outside the menu do nothing (don't close it)
        return true
    end

    -- Safety guards: onPrevPage / onNextPage crash when self.page is nil in panel mode (no pagination).  Consume silently.
    local orig_onPrevPage = TouchMenu.onPrevPage
    if orig_onPrevPage then
        function TouchMenu:onPrevPage()
            if self.item_table and self.item_table.panel then return true end
            return orig_onPrevPage(self)
        end
    end

    local orig_onNextPage = TouchMenu.onNextPage
    if orig_onNextPage then
        function TouchMenu:onNextPage()
            if self.item_table and self.item_table.panel then return true end
            return orig_onNextPage(self)
        end
    end
end

-- ============================================================
-- Patch FileManagerMenu
-- ============================================================
local function patchFileManagerMenu(plugin)
    local FileManagerMenu = require("apps/filemanager/filemanagermenu")
    local QuickMenu       = require("quickmenu")
    local config          = plugin.config
    --
    local orig_fm_setUpdateItemTable = FileManagerMenu.setUpdateItemTable
    function FileManagerMenu:setUpdateItemTable()
        plugin.menu_instance = self -- critical : need to be before orig or addToMainMenu will get nil
        plugin.is_filemanager = true -- critical : need to be before orig or addToMainMenu will get nil
        orig_fm_setUpdateItemTable(self) -- orig
        QuickMenu.updateTab(plugin)-- tab
    end

    -- don't open last tab when exit_tab is insert
    local _getTabIndexFromLocation_orig = FileManagerMenu._getTabIndexFromLocation
    function FileManagerMenu:_getTabIndexFromLocation(ges)
        local index = _getTabIndexFromLocation_orig(self, ges) -- run ori
        if config.add_exit_tab and index == #self.tab_item_table then -- exclude exit tab
            index = #self.tab_item_table - 1
        end
        return index
    end
end

-- ============================================================
-- Patch ReaderMenu
-- ============================================================
local function patchReaderMenu(plugin)
    local ReaderMenu = require("apps/reader/modules/readermenu")
    local QuickMenu  = require("quickmenu")
    local config     = plugin.config
    --
    local orig_reader_setUpdateItemTable = ReaderMenu.setUpdateItemTable
    function ReaderMenu:setUpdateItemTable()
        plugin.menu_instance = self -- critical : need to be before orig or addToMainMenu will get nil
        plugin.is_filemanager = false -- critical : need to be before orig or addToMainMenu will get nil
        orig_reader_setUpdateItemTable(self) -- orig
        QuickMenu.updateTab(plugin) -- tab
    end

    -- don't open last tab when exit_tab is insert
    local _getTabIndexFromLocation_reader_orig = ReaderMenu._getTabIndexFromLocation
    function ReaderMenu:_getTabIndexFromLocation(ges)
        local index = _getTabIndexFromLocation_reader_orig(self, ges) -- run ori
        if config.add_exit_tab and index == #self.tab_item_table then -- exclude exit tab
            index = #self.tab_item_table - 1
        end
        return index
    end
end

-- ============================================================
-- Init
-- ============================================================
local logger = require("logger")
--logger:setLevel(logger.levels.info)

function QuickMenuPlugin:init()
    local status, err = pcall(function()
        local Config = require("config")
        self.config = Config.load()
        patchTouchMenu(self)
        patchFileManagerMenu(self)
        patchReaderMenu(self)
        self.ui.menu:registerToMainMenu(self)
        self.config.idx_quickmenu_tab = 1
        logger.info("[QuickMenu] Initialized successfully.")
    end)

    if not status then
        logger.err("[QuickMenu] Failed to init: " .. tostring(err))
    end
end

function QuickMenuPlugin:addToMainMenu(menu_items)
    local QuickMenu = require("quickmenu")
    local status, result = pcall(function()
        return QuickMenu.buildSettingsMenu(self)
    end)

    if status and result then  menu_items.quick_menu = result
    else logger.err("[QuickMenu] Failed to build settings menu: " .. tostring(result)) end
end

function QuickMenuPlugin:onFlushSettings()
    local Config = require("config")
    Config.save(self.config)
end

return QuickMenuPlugin
