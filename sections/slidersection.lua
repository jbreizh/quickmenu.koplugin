local Button          = require("ui/widget/button")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local ProgressWidget  = require("ui/widget/progresswidget")

local ShadowDeco      = require("widgets/shadowdeco")
local Utils           = require("common/utils")

local SliderSection = {}

function SliderSection.buildTicks(min, max, count)
    local ticks = {}
    local range = max - min
    for i = 1, count - 1 do
        table.insert(ticks, math.floor(range * i / count + 0.5))
    end
    return ticks
end

function SliderSection.build(opts)
    -- opts import
    local touch_menu         = opts.touch_menu
    local screen             = opts.screen
    local inner_width        = opts.inner_width
    local btn_width          = opts.btn_width or screen:scaleBySize(50)
    local h_gap              = opts.h_gap or screen:scaleBySize(4)
    local btn_radius         = opts.btn_radius or screen:scaleBySize(7)
    local btn_font_size      = opts.btn_font_size or 16
    local btn_bordersize     = opts.btn_bordersize or screen:scaleBySize(1.5)
    local btn_shadow_offset  = opts.btn_shadow_offset or screen:scaleBySize(2)
    local btn_shadow_intensity = opts.btn_shadow_intensity or 0.6
    local btn_shadow_radius    = opts.btn_shadow_radius or screen:scaleBySize(6)
    local slider_ticks_width   = opts.slider_ticks_width or screen:scaleBySize(1)

    local shadow_gap = (opts.show_shadow and btn_shadow_offset or 0)

    -- logic
    local progress

    local function getValue() return opts.get() end

    local function setValue(value)
        value = math.max(opts.min, math.min(opts.max, value))
        opts.set(value)

        if progress then
            local range = opts.max - opts.min
            local pct = (range > 0) and ((value - opts.min) / range) or 0
            progress:setPercentage(pct)
        end

        Utils.updateMenu(touch_menu, {delay = 0})
    end

    -- widgets
    local minus = Button:new{
        text           = opts.text_minus or "−",
        width          = btn_width,
        radius         = btn_radius,
        bordersize     = btn_bordersize,
        text_font_size = btn_font_size,
        show_parent    = touch_menu.show_parent,
        callback       = opts.minus_callback or function() setValue(getValue() - (opts.step or 1)) end,
        hold_callback  = opts.minus_hold_callback or function() setValue(opts.min) end,
    }

    if opts.show_shadow then
        ShadowDeco.attach(minus, btn_shadow_offset, btn_shadow_intensity, btn_shadow_radius)
    end

    progress = ProgressWidget:new{
        width              = inner_width - 2 * btn_width - 2 * h_gap - 3 * shadow_gap,
        height             = minus:getSize().h,
        radius             = btn_radius,
        bordersize         = btn_bordersize,
        percentage         = (getValue() - opts.min) / (opts.max - opts.min),
        ticks              = opts.ticks,
        tick_width         = slider_ticks_width,
        last               = opts.max,
        initial_pos_marker = opts.initial_pos_marker,
    }

    if opts.show_shadow then
        ShadowDeco.attach(progress, btn_shadow_offset, btn_shadow_intensity, btn_shadow_radius)
    end

    local plus = Button:new{
        text           = opts.text_plus or "+",
        width          = btn_width,
        radius         = btn_radius,
        bordersize     = btn_bordersize,
        text_font_size = btn_font_size,
        show_parent    = touch_menu.show_parent,
        callback       = opts.plus_callback or function() setValue(getValue() + (opts.step or 1)) end,
        hold_callback  = opts.plus_hold_callback or function() setValue(opts.max) end,
    }

    if opts.show_shadow then
        ShadowDeco.attach(plus, btn_shadow_offset, btn_shadow_intensity, btn_shadow_radius)
    end

    -- row
    local row = HorizontalGroup:new{
        align = "center",
        minus,
        HorizontalSpan:new{ width = h_gap + shadow_gap },
        progress,
        HorizontalSpan:new{ width = h_gap + shadow_gap },
        plus,
        HorizontalSpan:new{ width = shadow_gap },
    }

    --group
    local group = VerticalGroup:new{
        align = "center",
        row,
        VerticalSpan:new{ width = shadow_gap },
    }

    -- refs
    local refs = { buttons = {}, sliders = {}, widgets = {} }
    table.insert(refs.sliders, {
        widget = progress,
        get    = getValue,
        set    = setValue,
        min    = opts.min,
        max    = opts.max,
    })

    return { widget = group, refs = refs }
end

return SliderSection
