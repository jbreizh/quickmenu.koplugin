-- Quick Menu tab for KOReader top menu
-- Adds a new tab at the far left with Wi-Fi, action buttons, and frontlight/warmth sliders.
-- Works in both File Manager and Book Reader views.

require("common/inject_icons")

-- ============================================================
-- Definition
-- ============================================================
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local QuickMenuPlugin = WidgetContainer:extend{ name = "quickmenu_plugin" }

-- ============================================================
-- Configuration
-- ============================================================
local Config = require("config")
local config = Config.load()

-- ============================================================
-- Hook TouchMenu to support panel tabs
-- ============================================================
local UIManager     = require("ui/uimanager")
local Geom          = require("ui/geometry")
local TouchMenu = require("ui/widget/touchmenu")
local FocusManager = require("ui/widget/focusmanager")
local GestureRange = require("ui/gesturerange")
local Device        = require("device")
local Screen        = Device.screen
local powerd = Device:getPowerDevice()
local datetime = require("datetime")
local BD = require("ui/bidi")
local QuickMenu = require("quickmenu")

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

local function default_footer()
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

-- Hook updateItems for panel rendering
local orig_updateItems = TouchMenu.updateItems
function TouchMenu:updateItems(target_page, target_item_id)
    if not self.item_table or not self.item_table.panel then
        self._qs_refs = nil -- clear refs when switching away from panel tab
        return orig_updateItems(self, target_page, target_item_id)
    end
    
    -- zenui
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

-- hook for zenslider
local function get_sliders(touch_menu)
    local refs = touch_menu._qs_refs
    if not refs then return {} end
    local sliders = {}
    for idx, sr in ipairs(refs.sliders or {}) do
        table.insert(sliders, sr.slider)
    end
    return sliders
end

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
local ReaderMenu = require("apps/reader/modules/readermenu")
local BD = require("ui/bidi")
local ConfirmBox    = require("ui/widget/confirmbox")
local _                = require("common/i18n").gettext
local UIManager     = require("ui/uimanager")
local Event         = require("ui/event")

function printTableLevel1(t)
    if type(t) ~= "table" then
        print("L'argument fourni n'est pas une table.")
        return
    end

    print("--- Contenu de la table (niveau 1) ---")
    for key, value in pairs(t) do
        -- On vérifie le type pour afficher une représentation lisible
        local displayValue = (type(value) == "table") and "[Table]" or tostring(value)
        print(string.format("[%s] => %s", tostring(key), displayValue))
    end
end



local orig_fm_setUpdateItemTable = FileManagerMenu.setUpdateItemTable
function FileManagerMenu:setUpdateItemTable()

    print("fm : setUpdateItemTable")

    self.menu_items.quick_menu_tab = {
        icon = "home",
        remember = function() return not config.open_on_start end,-- Dynamique : si l'option est décochée, on autorise la mémorisation
        panel = function(touch_menu) return QuickMenu.createPanel(config, touch_menu) end
    }

    self.menu_items.exit_tab = {
        icon = "exit",
        remember = false,
        callback = function()
            self:onCloseFileManagerMenu()
        end,
        hold_callback = function()
            self:onCloseFileManagerMenu()
            UIManager:show(ConfirmBox:new{
                text = _("Are you sure you want to exit KOReader ?"),
                ok_text = _("Exit"),
                ok_callback = function() UIManager:broadcastEvent(Event:new("Exit")) end
            })
        end
    }

    orig_fm_setUpdateItemTable(self)
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
local orig_reader_setUpdateItemTable = ReaderMenu.setUpdateItemTable

function ReaderMenu:setUpdateItemTable()
    print("rd : setUpdateItemTable")

    self.menu_items.quick_menu_tab = {
        icon = "home",
        remember = function() return not config.open_on_start end,-- Dynamique : si l'option est décochée, on autorise la mémorisation
        panel = function(touch_menu) return QuickMenu.createPanel(config, touch_menu) end
    }

    self.menu_items.exit_tab = {
        icon = "exit",
        remember = false,
        callback = function()
            self:onTapCloseMenu()
        end,
        hold_callback = function()
            self:onTapCloseMenu()
            UIManager:show(ConfirmBox:new{
                text = _("Are you sure you want to exit book ?"),
                ok_text = _("Exit"),
                ok_callback = function()
                    local file = self.ui.document and self.ui.document.file
                    self.ui:onClose()
                    if file then self.ui:showFileManager(file) end
                end
            })
        end
    }
    orig_reader_setUpdateItemTable(self)
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
    self.ui.menu:registerToMainMenu(self)
    print("quickmenu : init")
    local fm_order   = require("ui/elements/filemanager_menu_order")
    local rd_order   = require("ui/elements/reader_menu_order")
    if config.add_quickmenu_tab then
        fm_order.quick_menu_tab = {}
        table.insert(fm_order["KOMenu:menu_buttons"], 1, "quick_menu_tab")
        rd_order.quick_menu_tab = {}
        table.insert(rd_order["KOMenu:menu_buttons"], 1, "quick_menu_tab")
    end

    if config.add_exit_tab then
        fm_order.exit_tab = {}
        table.insert(fm_order["KOMenu:menu_buttons"], "exit_tab")
        rd_order.exit_tab = {}
        table.insert(rd_order["KOMenu:menu_buttons"], "exit_tab")
        for i, value in ipairs(rd_order["KOMenu:menu_buttons"]) do
            if value == "filemanager" then
                table.remove(rd_order["KOMenu:menu_buttons"], i)
                break -- On arrête la boucle une fois l'élément trouvé et supprimé
            end
        end
    end
end

function QuickMenuPlugin:addToMainMenu(menu_items)
    menu_items.quick_menu_config = QuickMenu.buildSettingsMenu(config)
end

function QuickMenuPlugin:onFlushSettings()
    Config.save(self.config)
end

return QuickMenuPlugin
