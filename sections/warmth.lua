local TextWidget = require("ui/widget/textwidget")
local Font            = require("ui/font")

local Device        = require("device")
local Math          = require("optmath")

local SliderSection = require("sections/slidersection")
local Utils         = require("common/utils")
local Translation   = require("i18n/translation")
local _             = Translation._

local WarmthSection = {}

function WarmthSection.build(ctx)
    local config       = ctx.config
    local touch_menu   = ctx.touch_menu
    local filemanager  = ctx.filemanager
    local reader       = ctx.reader
    local powerd       = ctx.powerd
    local inner_width  = ctx.inner_width
    local screen       = ctx.screen
    local theme        = ctx.theme or {}

    local section = Utils.getSection(config, "warmth")

    if not section or not Device:hasNaturalLight() then return nil end

    if filemanager and not section.enabled_f then return nil end

    if reader and not section.enabled_r then return nil end

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

        text_minus         = "\u{F1DB}",
        text_plus          = "\u{F186}",
    }

    if section.show_title then
        local warmth_label = TextWidget:new{
            text = _("Warmth") .. " : " .. powerd:frontlightWarmth() .. "%",
            face =  Font:getFace("cfont", theme.btn_font_size), bold = true,
            max_width = inner_width,
        }
        table.insert(sliderSection.widget, 1, warmth_label)
    end

    return sliderSection
end

function WarmthSection.getSettings(config, saveConfig, ctx)
    if not Device:hasNaturalLight() then return nil end

    local section = Utils.getSection(config, "warmth")
    if not section then return {} end

    return {
        {
            text = _("Enabled in filemanager"),
            checked_func = function() return section.enabled_f end,
            callback = function() section.enabled_f = not section.enabled_f; saveConfig() end
        },
        {
            text = _("Enabled in reader"),
            checked_func = function() return section.enabled_r end,
            callback = function() section.enabled_r = not section.enabled_r; saveConfig() end
        },
        {
            text = _("Show title"),
            checked_func = function() return section.show_title end,
            callback = function()
                section.show_title = not section.show_title
                saveConfig()
            end
        }
    }
end

return WarmthSection
