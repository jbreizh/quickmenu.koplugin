local Math          = require("optmath")
local SliderSection = require("sections/slidersection")

local WarmthSection = {}

function WarmthSection.build(ctx)

    local touch_menu   = ctx.touch_menu
    local powerd       = ctx.powerd
    local inner_width  = ctx.inner_width
    local screen       = ctx.screen
    local theme        = ctx.theme or {}

    local min_val    = powerd.fl_warmth_min or 0
    local max_val    = powerd.fl_warmth_max or 100
    local tick_count = 10
    local step_val   = math.max(1, Math.round((max_val - min_val) / tick_count))

    local function getValue()
        return powerd:toNativeWarmth(powerd:frontlightWarmth())
    end

    local function setValue(value)
        local val = math.max(min_val, math.min(max_val, Math.round(value)))
        powerd:setWarmth(powerd:fromNativeWarmth(val))
    end

    local sliderSection = SliderSection.build{
        touch_menu         = touch_menu,
        inner_width        = inner_width,
        screen             = screen,

        btn_width          = theme.btn_width,
        btn_radius         = theme.btn_radius,
        btn_bordersize     = theme.btn_bordersize,
        btn_font_size      = theme.btn_font_size,
        slider_ticks_width = theme.slider_ticks_width,
        gap                = theme.gap,

        min                = min_val,
        max                = max_val,
        step               = step_val,
        get                = getValue,
        set                = setValue,
        ticks              = SliderSection.buildTicks(min_val, max_val, tick_count),

        text_minus         = "\u{F2DC}", -- frozen,
        text_plus          = "\u{F490}", -- flame,
    }

    return sliderSection
end

return WarmthSection
