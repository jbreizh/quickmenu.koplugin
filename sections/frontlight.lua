local Device        = require("device")
local Math          = require("optmath")

local SliderSection = require("sections/slidersection")
local Utils         = require("common/utils")
local Translation   = require("i18n/translation")
local _             = Translation._

local FrontlightSection = {}

function FrontlightSection.build(ctx)
    local config       = ctx.config
    local powerd       = ctx.powerd
    local theme        = ctx.theme or {}

    local section = Utils.getSection(config, "frontlight")
    if not section or not section.enabled or not Device:hasFrontlight() then return nil end

    local min_val    = powerd.fl_min or 0
    local max_val    = powerd.fl_max or 100
    local tick_count = 25

    local function getValue()
        return powerd:frontlightIntensity()
    end

    local function setValue(value)
        local val = math.max(min_val, math.min(max_val, Math.round(value)))
        powerd:setIntensity(val)
    end

    return SliderSection.build{
        touch_menu         = ctx.touch_menu,
        inner_width        = ctx.inner_width,
        screen             = ctx.screen,

        btn_width          = theme.btn_width,
        btn_radius         = theme.btn_radius,
        btn_bordersize     = theme.btn_bordersize,
        btn_font_size      = theme.btn_font_size,
        slider_ticks_width = theme.slider_ticks_width,
        gap                = theme.gap,

        min                = min_val,
        max                = max_val,
        get                = getValue,
        set                = setValue,
        ticks              = SliderSection.buildTicks(min_val, max_val, tick_count),

        text_minus         = "\u{F111}",
        text_plus          = "\u{F185}",
    }
end

function FrontlightSection.getSettings(config, saveConfig, ctx)
    if not Device:hasFrontlight() then return nil end

    local section = Utils.getSection(config, "frontlight")
    if not section then return {} end

    return {
        {
            text = _("Show frontlight controls"),
            checked_func = function() return section.enabled end,
            callback = function()
                section.enabled = not section.enabled
                saveConfig()
            end
        }
    }
end

return FrontlightSection
