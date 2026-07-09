local Button           = require("ui/widget/button")
local TextWidget       = require("ui/widget/textwidget")
local Font             = require("ui/font")
local VerticalGroup    = require("ui/widget/verticalgroup")
local VerticalSpan     = require("ui/widget/verticalspan")
local HorizontalGroup  = require("ui/widget/horizontalgroup")
local HorizontalSpan   = require("ui/widget/horizontalspan")
local ConfirmBox       = require("ui/widget/confirmbox")

local Math             = require("optmath")

local UIManager        = require("ui/uimanager")

local IntensitySection = require("sections/intensitysection")
local IntensityZenUI   = require("sections/intensityzenui")
local WarmthSection    = require("sections/warmthsection")
local WarmthZenUI      = require("sections/warmthzenui")

local Config           = require("config")
local Utils            = require("common/utils")
local _                = require("common/i18n").gettext

local Frontlight = {}

local SECTION = "frontlight"
-- ============================================================
-- Frontlight Builder
-- ============================================================
function Frontlight.build(ctx)
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

    local section = Utils.getSection(config, SECTION)

    if not section then return nil end

    if filemanager and not section.enabled_f then return nil end

    if reader and not section.enabled_r then return nil end

    if not device:hasFrontlight() then return nil end

    local refs = { buttons = {}, sliders = {}, widgets = {} }

    local group = VerticalGroup:new{ align = "center" }


    if section.use_zenslider then
        local intensityZenUI= IntensityZenUI.build(ctx)
        table.insert(group, intensityZenUI.widget)
        table.insert(refs.sliders, intensityZenUI.refs.sliders[1])
        if section.collapse then return { widget = group , refs = refs} end
    else
        if section.show_title then
            local label = _("Frontlight") .. " : " .. powerd:frontlightIntensity() .. "%"
            local label_title = TextWidget:new{
                text = label,
                face =  Font:getFace("cfont", btn_font_size), bold = true,
                max_width = inner_width - btn_width,
            }
            local collapse_btn = Button:new{
                text           = section.collapse and "\u{F078}" or "\u{F077}", -- down up
                width          = btn_width,
                radius         = btn_radius,
                bordersize     = 0,
                text_font_size = btn_font_size,
                show_parent    = touch_menu.show_parent,
                callback       = function()
                    section.collapse = not section.collapse
                    Config.save(config)
                    touch_menu:updateItems(1)
                end,
                -- hold_callback
            }
            local row_title = HorizontalGroup:new{
                align = "center",
                label_title,
                HorizontalSpan:new{ width = inner_width - label_title:getSize().w - btn_width},
                collapse_btn
            }
            table.insert(group, row_title)
            if section.collapse then  return { widget = group , refs = refs} end
        end
        local intensitySection = IntensitySection.build(ctx)
        table.insert(group, intensitySection.widget)
        table.insert(refs.sliders, intensitySection.refs.sliders[1])
    end

    if device:hasNaturalLight() then
        if section.use_zenslider then
            local warmthZenUI = WarmthZenUI.build(ctx)
            table.insert(group, warmthZenUI.widget)
            table.insert(refs.sliders, warmthZenUI.refs.sliders[1])
        else
           if section.show_title then
                local label_title = TextWidget:new{
                    text = _("Warmth") .. " : " .. powerd:frontlightWarmth() .. "%",
                    face =  Font:getFace("cfont", btn_font_size), bold = true,
                    max_width = inner_width,
                }
                local row_title = HorizontalGroup:new{
                align = "center",
                label_title,
                HorizontalSpan:new{ width = inner_width - label_title:getSize().w}
            }
                table.insert(group, row_title)
            else
                table.insert(group, VerticalSpan:new{ width = v_gap })
            end
            local warmthSection = WarmthSection.build(ctx)
            table.insert(group, warmthSection.widget)
            table.insert(refs.sliders, warmthSection.refs.sliders[1])
        end
    end

    return { widget = group , refs = refs }
end

-- ============================================================
-- Settings Menu Builder
-- ============================================================
function Frontlight.getSettings(ctx)
    -- ctx import
    local device  = ctx.device
    local config  = ctx.config
    local section = Utils.getSection(config, SECTION)

    --if not device:hasFrontlight() then return nil end
    if not section then return {} end

    return {
        {
            text = _("Enabled in filemanager"),
            checked_func = function() return section.enabled_f end,
            callback = function() section.enabled_f = not section.enabled_f; Config.save(config) end
        },
        {
            text = _("Enabled in reader"),
            checked_func = function() return section.enabled_r end,
            callback = function() section.enabled_r = not section.enabled_r; Config.save(config) end
        },
        {
            text = _("Show title"),
            enabled_func = function() return not section.use_zenslider end, --do nothing on ZenSlider
            checked_func = function() return section.show_title end,
            callback = function() section.show_title = not section.show_title; Config.save(config) end
        },
        {
            text = _("Use ZenSlider"),
            checked_func = function() return section.use_zenslider end,
            callback = function() section.use_zenslider = not section.use_zenslider; Config.save(config) end,
            help_text = _("Author : Anthony Gress\nProjet : Zen UI\nhttps://github.com/AnthonyGress/zen_ui.koplugin"),
            separator = true
        },
        {
            text = _("Reset to defaults"),
            keep_menu_open = true,
            callback = function(touch_menu)
                UIManager:show(ConfirmBox:new{
                    text = _("Are you sure you want to reset to defaults ?"),
                    ok_text = _("Reset"),
                    ok_callback = function()
                        local defaults = Config.DEFAULTS.sections[SECTION]
                        Utils.resetSectionToDefaults(section, defaults)
                        Config.save(config)
                        if touch_menu and touch_menu.updateItems then touch_menu:updateItems() end
                    end
                })
            end
        }
    }
end

return Frontlight
