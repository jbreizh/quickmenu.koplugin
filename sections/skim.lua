local Button          = require("ui/widget/button")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local VerticalGroup   = require("ui/widget/verticalgroup")

local Math            = require("optmath")
local Size            = require("ui/size")
local Event           = require("ui/event")
local UIManager       = require("ui/uimanager")

local SliderSection   = require("sections/slidersection")
local Utils           = require("common/utils")
local Translation     = require("i18n/translation")
local _               = Translation._

local SkimSection = {}

function SkimSection.build(ctx)
    local config       = ctx.config
    local touch_menu   = ctx.touch_menu
    local reader       = ctx.reader
    local inner_width  = ctx.inner_width
    local section_span = ctx.section_span
    local theme        = ctx.theme or {}

    local section = Utils.getSection(config, "skim")
    if not section or not section.enabled or not reader then return nil end

    local refs = { buttons = {}, sliders = {}, widgets = {} }
    local group = VerticalGroup:new{ align = "center" }

    -- style
    local gap            = theme.gap or ctx.screen:scaleBySize(4)
    local btn_width      = theme.btn_width or ctx.screen:scaleBySize(50)
    local btn_radius     = theme.btn_radius or Size.radius.button
    local btn_bordersize = theme.btn_bordersize  or 0
    local btn_font       = theme.btn_font_size or 16
    local ticks_width    = theme.slider_ticks_width or Size.line.medium

    -- Utilitaires de gestion du menu
    local function closeMenu()
        if touch_menu and touch_menu.closeMenu then
            touch_menu:closeMenu()
        end
    end

    local function refreshMenu()
        if touch_menu and touch_menu.updateItems then
            touch_menu:updateItems(1)
        end
    end

    local skim = {
        curr_page  = reader:getCurrentPage(),
        page_count = reader.document:getPageCount()
    }

    -- Logique de Navigation
    local function addOrigin()
        if not touch_menu.skim_orig_page then
            reader.link:addCurrentLocationToStack()
            touch_menu.skim_orig_page = reader:getCurrentPage()
        end
    end

    local function goToPage(page)
        local new_page = math.max(1, math.min(skim.page_count, page))
        if skim.curr_page == new_page then return end
        skim.curr_page = new_page
        addOrigin()
        reader:handleEvent(Event:new("GotoPage", skim.curr_page))
    end

    local function goToOrig()
        if touch_menu.skim_orig_page then
            reader.link:onGoBackLink()
            touch_menu.skim_orig_page = nil
            refreshMenu()
        end
    end

    local function goEvent(name)
        addOrigin()
        reader:handleEvent(Event:new(name, false))
    end

    -- Row 1: Slider
    local row1 = SliderSection.build{
        touch_menu         = touch_menu,
        inner_width        = inner_width,
        screen             = ctx.screen,
        min                = 1,
        max                = skim.page_count,
        get                = function() return skim.curr_page end,
        set                = goToPage,
        text_minus         = "\u{F056}",
        text_plus          = "\u{F055}",
        initial_pos_marker = true,
        btn_width          = btn_width,
        btn_radius         = btn_radius,
        btn_bordersize     = btn_bordersize,
        btn_font_size      = btn_font,
        slider_ticks_width = ticks_width
    }

    local progress = row1.refs.sliders[1].widget
    progress.ticks              = reader.toc:getTocTicksFlattened()
    progress.tick_width         = ticks_width
    progress.alt                = reader.document.flows
    progress.initial_percentage = (touch_menu.skim_orig_page or skim.curr_page) / skim.page_count

    -- Row 2: Navigation
    local function createBtn(props)
        props.width = btn_width
        props.radius = btn_radius
        props.bordersize = btn_bordersize
        props.text_font_size = btn_font
        props.show_parent = touch_menu.show_parent
        return Button:new(props)
    end

    local gap2 = Math.round((inner_width - 7 * btn_width - 4 * gap) / 2)
    local row2 = HorizontalGroup:new{ align = "center" }

    table.insert(row2, createBtn{ text = "\u{25C0}", callback = function() local p = reader.toc:getPreviousChapter(skim.curr_page); if p then goToPage(p); refreshMenu() end end, hold_callback = function() goToPage(1); refreshMenu() end })
    table.insert(row2, HorizontalSpan:new{ width = gap })
    table.insert(row2, createBtn{ text = "\u{F0C9}", callback = function() closeMenu(); goEvent("ShowToc") end, hold_callback = function() closeMenu(); goEvent("ShowBookMap") end })
    table.insert(row2, HorizontalSpan:new{ width = gap })
    table.insert(row2, createBtn{ text = "\u{25B6}", callback = function() local p = reader.toc:getNextChapter(skim.curr_page); if p then goToPage(p); refreshMenu() end end, hold_callback = function() goToPage(skim.page_count); refreshMenu() end })

    table.insert(row2, HorizontalSpan:new{ width = gap2 })
    table.insert(row2, createBtn{ text_func = function() return tostring(skim.curr_page) end, callback = function() closeMenu(); goEvent("ShowGotoDialog") end, hold_callback = function() goToOrig() end })
    table.insert(row2, HorizontalSpan:new{ width = gap2 })

    table.insert(row2, createBtn{ text = "\u{25C0}", callback = function() goEvent("GotoPreviousBookmarkFromPage"); refreshMenu() end })
    table.insert(row2, HorizontalSpan:new{ width = gap })
    table.insert(row2, createBtn{ text_func = function() return reader.view.dogear_visible and "\u{F02E}" or "\u{F097}" end, callback = function() goEvent("ToggleBookmark"); refreshMenu() end, hold_callback = function() closeMenu(); goEvent("ShowBookmark") end })
    table.insert(row2, HorizontalSpan:new{ width = gap })
    table.insert(row2, createBtn{ text = "\u{25B6}", callback = function() goEvent("GotoNextBookmarkFromPage"); refreshMenu() end })

    table.insert(group, row1.widget)
    table.insert(group, section_span)
    table.insert(group, row2)

    table.insert(refs.sliders, row1.refs.sliders[1])

    return { widget = group, refs = refs }
end

function SkimSection.getSettings(config, saveConfig, ctx)
    local section = Utils.getSection(config, "skim")
    if not section then return {} end

    return {
        {
            text = _("Show skim controls"),
            checked_func = function() return section.enabled end,
            callback = function() section.enabled = not section.enabled; saveConfig() end
        }
    }
end

return SkimSection
