local TextWidget       = require("ui/widget/textwidget")
local Font             = require("ui/font")
local VerticalGroup    = require("ui/widget/verticalgroup")
local VerticalSpan     = require("ui/widget/verticalspan")
local ConfirmBox       = require("ui/widget/confirmbox")

local Device           = require("device")
local Math             = require("optmath")

local UIManager       = require("ui/uimanager")

local IntensitySection = require("sections/intensitysection")
local WarmthSection    = require("sections/warmthsection")

local Config           = require("config")
local Utils            = require("common/utils")
local Translation      = require("i18n/translation")
local _                = Translation._

local Frontlight = {}

function Frontlight.build(ctx)
    local config       = ctx.config
    local touch_menu   = ctx.touch_menu
    local filemanager  = ctx.filemanager
    local reader       = ctx.reader
    local powerd       = ctx.powerd
    local inner_width  = ctx.inner_width
    local screen       = ctx.screen
    local theme        = ctx.theme or {}

    local section = Utils.getSection(config, "frontlight")

    if not section then return nil end

    if filemanager and not section.enabled_f then return nil end

    if reader and not section.enabled_r then return nil end

    if not Device:hasFrontlight() then return nil end

    local refs = { buttons = {}, sliders = {}, widgets = {} }
    local group = VerticalGroup:new{ align = "center" }

    if section.show_title then
        local label = _("Frontlight") .. " : " .. powerd:frontlightIntensity() .. "%"
        if  Device:hasNaturalLight() then label = label .. " - " .._("Warmth") .. " : " .. powerd:frontlightWarmth() .. "%" end
        local frontlight_label = TextWidget:new{
            text = label,
            face =  Font:getFace("cfont", theme.btn_font_size), bold = true,
            max_width = inner_width,
        }
        table.insert(group, frontlight_label)
    end

    if section.split_title then
        local intensity_label = TextWidget:new{
            text = _("Frontlight") .. " : " .. powerd:frontlightIntensity() .. "%",
            face =  Font:getFace("cfont", theme.btn_font_size), bold = true,
            max_width = inner_width,
        }
        table.insert(group, intensity_label)
    end

    local intensitySection = IntensitySection.build(ctx)
    table.insert(group, intensitySection.widget)
    table.insert(refs.sliders, intensitySection.refs.sliders[1])

    if section.split_title and Device:hasNaturalLight() then
        local warmth_label = TextWidget:new{
            text = _("Warmth") .. " : " .. powerd:frontlightWarmth() .. "%",
            face =  Font:getFace("cfont", theme.btn_font_size), bold = true,
            max_width = inner_width,
        }
        table.insert(group, warmth_label)
    end

    if Device:hasNaturalLight() then
        local warmthSection = WarmthSection.build(ctx)
        if not section.split_title then table.insert(group, VerticalSpan:new{ width = theme.vgap }) end
        table.insert(group, warmthSection.widget)
        table.insert(refs.sliders, warmthSection.refs.sliders[1])
    end

    return { widget = group , refs = refs }
end

function Frontlight.getSettings(config, saveConfig, ctx)
    if not Device:hasFrontlight() then return nil end

    local section = Utils.getSection(config, "frontlight")
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
        },
        {
            text = _("Split title"),
            checked_func = function() return section.split_title end,
            callback = function()
                section.split_title = not section.split_title
                saveConfig()
            end,
            separator = true
        },
        {
            text = _("Reset to defaults"),
            callback = function()
                UIManager:show(ConfirmBox:new{
                    text = _("Are you sure you want to reset to defaults ?"),
                    ok_text = _("Reset"),
                    ok_callback = function()
                        local defaults = Config.DEFAULTS.sections.frontlight
                        Utils.resetSectionToDefaults(section, defaults)
                        saveConfig()
                    end
                })
            end
        }
    }
end

return Frontlight
