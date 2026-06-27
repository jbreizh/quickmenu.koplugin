local Button          = require("ui/widget/button")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local ProgressWidget  = require("ui/widget/progresswidget")

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
    local touch_menu   = opts.touch_menu
    local screen       = opts.screen
    local inner_width  = opts.inner_width

    -- style
    local btn_width          = opts.btn_width    or screen:scaleBySize(50)
    local gap                = opts.gap          or screen:scaleBySize(4)
    local btn_radius         = opts.btn_radius   or 0
    local btn_font_size      = opts.btn_font_size or 16
    local btn_bordersize     = opts.btn_bordersize or 0
    local slider_ticks_width = opts.slider_ticks_width or 2
    local slider_width       = inner_width - 2 * btn_width - 2 * gap

    local refs = { buttons = {}, sliders = {}, widgets = {} }

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

        if touch_menu and touch_menu.updateItems then
            touch_menu:updateItems(1)
        end
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

    progress = ProgressWidget:new{
        width              = slider_width,
        height             = minus:getSize().h,
        radius             = btn_radius,
        bordersize         = btn_bordersize,
        percentage         = (getValue() - opts.min) / (opts.max - opts.min),
        ticks              = opts.ticks,
        tick_width         = slider_ticks_width,
        last               = opts.max,
        initial_pos_marker = opts.initial_pos_marker,
    }

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

    -- group
    local row = HorizontalGroup:new{
        align = "center",
        minus,
        HorizontalSpan:new{ width = gap },
        progress,
        HorizontalSpan:new{ width = gap },
        plus,
    }

    table.insert(refs.sliders, {
        widget = progress,
        get    = getValue,
        set    = setValue,
        min    = opts.min,
        max    = opts.max,
    })

    return { widget = row, refs = refs }
end

return SliderSection
