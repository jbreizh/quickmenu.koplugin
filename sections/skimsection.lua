local Button          = require("ui/widget/button")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan  = require("ui/widget/verticalspan")

local Math            = require("optmath")
local Event           = require("ui/event")

local SliderSection   = require("sections/slidersection")

local SkimSection = {}

function SkimSection.build(ctx)
    -- ctx import
    local config             = ctx.config
    local touch_menu         = ctx.touch_menu
    local reader             = ctx.reader
    local filemanager        = ctx.filemanager
    local device             = ctx.device
    local powerd             = ctx.powerd
    local screen             = ctx.screen
    local datetime           = ctx.datetime
    local stat               = ctx.stat
    local panel_width        = ctx.panel_width
    local inner_width        = ctx.inner_width
    local h_gap              = screen:scaleBySize(config.style.h_gap or 4)
    local v_gap              = screen:scaleBySize(config.style.v_gap or 4)
    local btn_width          = screen:scaleBySize(config.style.btn_width or 50)
    local btn_radius         = screen:scaleBySize(config.style.btn_radius or 7)
    local btn_bordersize     = screen:scaleBySize(config.style.btn_bordersize or 1.5)
    local btn_font_size      = config.style.btn_font_size or 16
    local slider_ticks_width = screen:scaleBySize(config.style.slider_ticks_width or 1)


    local refs = { buttons = {}, sliders = {}, widgets = {} }
    local group = VerticalGroup:new{ align = "center" }

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
        screen             = screen,

        btn_width          = btn_width,
        btn_radius         = btn_radius,
        btn_bordersize     = btn_bordersize,
        btn_font_size      = btn_font_size,
        slider_ticks_width = slider_ticks_width,
        h_gap              = h_gap,

        min                = 1,
        max                = skim.page_count,
        get                = function() return skim.curr_page end,
        set                = goToPage,
        text_minus         = "\u{F056}",
        text_plus          = "\u{F055}",
        initial_pos_marker = true,
    }

    local progress = row1.refs.sliders[1].widget
    progress.ticks              = reader.toc:getTocTicksFlattened()
    progress.tick_width         = slider_ticks_width
    progress.alt                = reader.document.flows
    progress.initial_percentage = (touch_menu.skim_orig_page or skim.curr_page) / skim.page_count

    -- Row 2: Navigation
    local function createBtn(props)
        props.width = btn_width
        props.radius = btn_radius
        props.bordersize = btn_bordersize
        props.text_font_size = btn_font_size
        props.show_parent = touch_menu.show_parent
        return Button:new(props)
    end

    local h_gap2 = Math.round((inner_width - 7 * btn_width - 4 * h_gap) / 2)
    local row2 = HorizontalGroup:new{ align = "center" }

    table.insert(row2, createBtn{ text = "\u{25C0}", callback = function() local p = reader.toc:getPreviousChapter(skim.curr_page); if p then goToPage(p) end; refreshMenu() end, hold_callback = function() goToPage(1); refreshMenu() end })
    table.insert(row2, HorizontalSpan:new{ width = h_gap })
    table.insert(row2, createBtn{ text = "\u{F0C9}", callback = function() closeMenu(); goEvent("ShowToc") end, hold_callback = function() closeMenu(); goEvent("ShowBookMap") end })
    table.insert(row2, HorizontalSpan:new{ width = h_gap })
    table.insert(row2, createBtn{ text = "\u{25B6}", callback = function() local p = reader.toc:getNextChapter(skim.curr_page); if p then goToPage(p) end; refreshMenu() end, hold_callback = function() goToPage(skim.page_count); refreshMenu() end })

    table.insert(row2, HorizontalSpan:new{ width = h_gap2 })
    table.insert(row2, createBtn{ text_func = function() return tostring(skim.curr_page) end, callback = function() closeMenu(); goEvent("ShowGotoDialog") end, hold_callback = function() goToOrig() end })
    table.insert(row2, HorizontalSpan:new{ width = h_gap2 })

    table.insert(row2, createBtn{ text = "\u{25C0}", callback = function() goEvent("GotoPreviousBookmarkFromPage"); refreshMenu() end })
    table.insert(row2, HorizontalSpan:new{ width = h_gap })
    table.insert(row2, createBtn{ text_func = function() return reader.view.dogear_visible and "\u{F02E}" or "\u{F097}" end, callback = function() goEvent("ToggleBookmark"); refreshMenu() end, hold_callback = function() closeMenu(); goEvent("ShowBookmark") end })
    table.insert(row2, HorizontalSpan:new{ width = h_gap })
    table.insert(row2, createBtn{ text = "\u{25B6}", callback = function() goEvent("GotoNextBookmarkFromPage"); refreshMenu() end })

    table.insert(group, row1.widget)
    table.insert(group, VerticalSpan:new{ width = v_gap })
    table.insert(group, row2)

    table.insert(refs.sliders, row1.refs.sliders[1])

    return { widget = group, refs = refs }
end

return SkimSection
