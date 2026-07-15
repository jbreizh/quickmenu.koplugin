local Button           = require("ui/widget/button")
local TextWidget       = require("ui/widget/textwidget")
local Font             = require("ui/font")
local VerticalGroup    = require("ui/widget/verticalgroup")
local VerticalSpan     = require("ui/widget/verticalspan")
local HorizontalGroup  = require("ui/widget/horizontalgroup")
local HorizontalSpan   = require("ui/widget/horizontalspan")
local ConfirmBox       = require("ui/widget/confirmbox")
local ButtonDialog    = require("ui/widget/buttondialog")

local Math             = require("optmath")

local UIManager        = require("ui/uimanager")

local IntensitySection = require("sections/intensitysection")
local IntensityZenUI   = require("sections/intensityzenui")
local WarmthSection    = require("sections/warmthsection")
local WarmthZenUI      = require("sections/warmthzenui")

local Config           = require("config")
local Utils            = require("common/utils")
local _                = require("common/i18n").gettext

local Frontlight = {
    id = "frontlight",
    label = _("Frontlight"),
    icon  = "\u{EA2B}" -- led-on
}

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

    local section = Utils.getSection(config, Frontlight.id)
    if not section then return nil end

    if filemanager and not section.enabled_f then return nil end

    if reader and not section.enabled_r then return nil end

    -- record value easy change for testing on emulator
    local hasFrontlight = not not device:hasFrontlight() -- force bool
    local hasNaturalLight = not not device:hasNaturalLight() -- force bool

    if not hasFrontlight then return nil end

    local refs = { buttons = {}, sliders = {}, widgets = {} }

    local group = VerticalGroup:new{ align = "center" }

    if section.use_zenslider then
        -- collapse, label_title, settings and slider
        local function settings_func() -- need to pass settings_func for settings_btn
            Frontlight.showSettings(ctx)
        end
        local intensityZenUI = IntensityZenUI.build(ctx, settings_func)
        table.insert(group, intensityZenUI.widget)
        table.insert(refs.sliders, intensityZenUI.refs.sliders[1])
        -- collapse break
        if section.collapse then return { widget = group , refs = refs} end
    else
        if section.show_title then
            local row_title = HorizontalGroup:new{ align = "center" }
            -- collapse
            local collapse_btn = Button:new{
                text           = section.collapse and "▶" or "▼",
                width          = btn_width,
                radius         = btn_radius,
                bordersize     = 0,
                text_font_size = btn_font_size,
                show_parent    = touch_menu.show_parent,
                callback       = function()
                    section.collapse = not section.collapse
                    Config.saveAndRefresh(ctx, true) -- no flush
                end,
                -- hold_callback
            }
            table.insert(row_title, collapse_btn)
            -- label
            local label = Frontlight.label .. " : " .. powerd:frontlightIntensity() .. "%"
            if  hasNaturalLight and section.collapse then
                label = label .. " - " .._("Warmth") .. " : " .. powerd:frontlightWarmth() .. "%"
            end
            local label_title = TextWidget:new{
                text = label,
                face =  Font:getFace("cfont", btn_font_size), bold = true,
                max_width = inner_width - btn_width*2,
            }
            table.insert(row_title, label_title)
            table.insert(row_title, HorizontalSpan:new{ width = inner_width - label_title:getSize().w - btn_width*2 })
            -- settings
            local settings_btn = Button:new{
                text           = "\u{EB92}",
                width          = btn_width,
                radius         = btn_radius,
                bordersize     = 0,
                text_font_size = btn_font_size,
                show_parent    = touch_menu.show_parent,
                callback       = function()
                    Frontlight.showSettings(ctx)
                end,
                --hold_callback = function() end,
            }
            table.insert(row_title, settings_btn)
            --
            table.insert(group, row_title)
            -- collapse break
            if section.collapse then  return { widget = group , refs = refs} end
        end
        -- slider
        local intensitySection = IntensitySection.build(ctx)
        table.insert(group, intensitySection.widget)
        table.insert(refs.sliders, intensitySection.refs.sliders[1])
    end

    if hasNaturalLight then
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
                HorizontalSpan:new{ width = btn_width},
                label_title,
                HorizontalSpan:new{ width = inner_width - label_title:getSize().w -btn_width}
                }
                table.insert(group, row_title)
            else
                table.insert(group, VerticalSpan:new{ width = v_gap }) -- better for visual
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
function Frontlight.getSettings(ctx, close, refresh, reload)
    -- ctx import
    local device  = ctx.device
    local config  = ctx.config
    local section = Utils.getSection(config, Frontlight.id)

    if not device:hasFrontlight() then return {} end
    if not section then return {} end

    return {
        {
            text = _("Enabled in filemanager"),
            checked_func = function() if reload then reload() end return section.enabled_f end,
            callback = function() section.enabled_f = not section.enabled_f; Config.saveAndRefresh(ctx) end
        },
        {
            text = _("Enabled in reader"),
            checked_func = function() if reload then reload() end return section.enabled_r end,
            callback = function() section.enabled_r = not section.enabled_r; Config.saveAndRefresh(ctx) end
        },
        {
            text = _("Show title"),
            checked_func = function() if reload then reload() end return section.show_title end,
            callback = function() section.show_title = not section.show_title; Config.saveAndRefresh(ctx) end
        },
        {
            text = _("Use ZenSlider"),
            checked_func = function() if reload then reload() end return section.use_zenslider end,
            callback = function() section.use_zenslider = not section.use_zenslider; Config.saveAndRefresh(ctx) end,
            help_text = _("Author : Anthony Gress\nProjet : Zen UI\nhttps://github.com/AnthonyGress/zen_ui.koplugin"),
        },
        {
        text = _("Reset section to defaults") .. "\xE2\x80\xA6",
        keep_menu_open = true,
        callback = close(function(touch_menu)
            if touch_menu then ctx.touch_menu = touch_menu end
            UIManager:show(ConfirmBox:new{
                text = _("Reset section to defaults") .. " ?",
                ok_text = _("Reset"),
                ok_callback = function()
                    local defaults = Config.DEFAULTS.sections[Frontlight.id]
                    Utils.resetSectionToDefaults(section, defaults)
                    Config.saveAndRefresh(ctx)
                    if refresh then refresh() end
                end,
                cancel_callback = function()
                    if refresh then refresh() end
                end,
            })
        end)
        }
    }
end

function Frontlight.showSettings(ctx)
    local dialog

    local function close(fn)
        return function()
            if dialog then UIManager:close(dialog) end
            if fn then fn() end
        end
    end

    local function refresh()
        Frontlight.showSettings(ctx)
    end
    -- use to refresh under check btn when dialog is transparent
    -- cost perf so block at openig as dialog never open transparent
    -- only from the dialog from the touch_menu itself it crash koreader
    local is_initializing = true
    local function reload()
        if is_initializing then return end
        local touch_menu = ctx.touch_menu
        if touch_menu and touch_menu.updateItems then touch_menu:updateItems() end
    end

    local buttons = Utils.wrap_items(Frontlight.getSettings(ctx, close, refresh, reload))
    if not buttons or #buttons==0 then return end

    table.insert(buttons, {}) -- separator

    table.insert(buttons, {{
        text = _("Exit"),
        callback = close()
    }})

    dialog = ButtonDialog:new{
        -- dismissable = false,
        title = Frontlight.icon .. " " .. Frontlight.label .. " :",
        title_align  = "left",
        width_factor = 0.9,
        buttons = buttons,
    }
    UIManager:show(dialog)
    is_initializing = false -- allow reload after opening
end

return Frontlight
