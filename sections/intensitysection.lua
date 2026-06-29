local Math          = require("optmath")
local SliderSection = require("sections/slidersection")

local IntensitySection = {}

function IntensitySection.build(opts)
    local touch_menu   = opts.touch_menu
    local powerd       = opts.powerd
    local inner_width  = opts.inner_width
    local screen       = opts.screen
    local theme        = opts.theme or {}

    local min_val    = powerd.fl_min or 0
    local max_val    = powerd.fl_max or 100
    local tick_count = 25
    local step_val   = 1

    local function getValue()
        return powerd:frontlightIntensity()
    end

    local function setValue(value)
        local val = math.max(min_val, math.min(max_val, Math.round(value)))
        powerd:setIntensity(val)
    end

    return SliderSection.build{
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

        text_minus         = "\u{EA2A}", -- led-off
        text_plus          = "\u{EA2B}", -- led-on
    }

end


return IntensitySection
