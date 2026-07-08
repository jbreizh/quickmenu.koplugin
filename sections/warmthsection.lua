local Math          = require("optmath")
local SliderSection = require("sections/slidersection")

local WarmthSection = {}

function WarmthSection.build(ctx)
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

    --
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

        btn_width          = btn_width,
        btn_radius         = btn_radius,
        btn_bordersize     = btn_bordersize,
        btn_font_size      = btn_font_size,
        slider_ticks_width = slider_ticks_width,
        h_gap              = h_gap,

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
