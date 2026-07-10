local Button          = require("ui/widget/button")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local TextWidget      = require("ui/widget/textwidget")
local ConfirmBox       = require("ui/widget/confirmbox")
local ButtonDialog    = require("ui/widget/buttondialog")

local Font            = require("ui/font")
local RenderImage     = require("ui/renderimage")

local UIManager       = require("ui/uimanager")

local Config          = require("config")
local InfoSection     = require("sections/infosection")
local SkimSection     = require("sections/skimsection")
local CoverButton     = require("widgets/coverbutton")
local Utils           = require("common/utils")
local _               = require("common/i18n").gettext

local Info = {}

local SECTION = "info"
-- ============================================================
-- Info Builder
-- ============================================================
function Info.build(ctx)
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

    local section      = Utils.getSection(config, SECTION)

    if not section or not section.enabled_r or not reader then return nil end
    local refs = { buttons = {}, sliders = {}, widgets = {} }

    local group = VerticalGroup:new{ align = "center" }

    if section.show_title then
        local label_title = TextWidget:new{
            text = ("Information"),
            face =  Font:getFace("cfont", btn_font_size), bold = true,
            max_width = inner_width - btn_width*2,
        }
        local settings_btn = Button:new{
            text           = "\u{F462}", -- down up \u{EB92}"
            width          = btn_width,
            radius         = btn_radius,
            bordersize     = 0,
            text_font_size = btn_font_size,
            show_parent    = touch_menu.show_parent,
            callback       = function()
                Info.showSettings(ctx)
            end,
            --hold_callback = function() end,
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
                Config.saveAndRefresh(ctx)
            end,
            -- hold_callback
        }
        local row_title = HorizontalGroup:new{
            align = "center",
            label_title,
            HorizontalSpan:new{ width = inner_width - label_title:getSize().w - btn_width*2 },
            settings_btn,
            collapse_btn
        }
        table.insert(group, row_title)
        if section.collapse then  return { widget = group , refs = refs} end
    end

    local info_col = VerticalGroup:new{ align = "center" }
    local infoSection = InfoSection.build(ctx)
    table.insert(info_col, infoSection.widget)

    if section.show_skim then
        local skimSection = SkimSection.build(ctx)
        table.insert(info_col, VerticalSpan:new{ width = v_gap })
        table.insert(info_col, skimSection.widget)
        table.insert(refs.sliders, skimSection.refs.sliders[1])
    end

    --
    local row = HorizontalGroup:new{ align = "center" }

    if section.show_thumbnail then -- TODO
        local cover_h = info_col:getSize().h
        local cover_w = math.floor(2 * cover_h / 3 + 0.5)
        local ok, thumbnail = pcall(function() return reader.bookinfo:getCoverImage(reader.document) end)
        if ok then
            ok, thumbnail = pcall(function() return RenderImage:scaleBlitBuffer(thumbnail, cover_w, cover_h, true) end)
            if ok then
                info_thumbnail = CoverButton:new{
                    image = thumbnail,
                    width = cover_w,
                    height = cover_h,
                    radius = btn_radius,
                    bordersize = btn_bordersize,
                    padding = 0, --h_gap,
                    callback = function()
                        touch_menu:closeMenu()
                        reader.bookinfo:onShowBookCover(reader.document.file)
                    end,
                    hold_callback = function()
                        touch_menu:closeMenu()
                        reader.bookinfo:onShowBookDescription(false, reader.document.file)
                    end
                }
                table.insert(row, info_thumbnail)
                table.insert(row, HorizontalSpan:new{ width = h_gap })

                local opts = {}
                for k, v in pairs(ctx) do opts[k] = v end
                opts.inner_width = inner_width - cover_w - 2 * h_gap

                info_col = VerticalGroup:new{ align = "left" }
                local infoSection = InfoSection.build(opts)
                table.insert(info_col, infoSection.widget)

                if section.show_skim then
                    local skimSection = SkimSection.build(opts)
                    table.insert(info_col, VerticalSpan:new{ width = v_gap })
                    table.insert(info_col, skimSection.widget)
                    table.insert(refs.sliders, skimSection.refs.sliders[1])
                end
            end
        end
    end

    table.insert(row, info_col)
    table.insert(group, row)

    return { widget = group , refs = refs }
end

-- ============================================================
-- Settings Menu Builder
-- ============================================================
function Info.getSettings(ctx, close, refresh)
    -- ctx import
    local config  = ctx.config
    local section = Utils.getSection(config, SECTION)

    if not section then return {} end

    return {
        {
            text = _("Enabled in reader"),
            checked_func = function() return section.enabled_r end,
            callback = function() section.enabled_r = not section.enabled_r; Config.saveAndRefresh(ctx) end
        },
        {
            text = _("Show title"),
            checked_func = function() return section.show_title end,
            callback = function() section.show_title = not section.show_title; Config.saveAndRefresh(ctx) end
        },
        {
            text = _("Show thumbnail"),
            checked_func = function() return section.show_thumbnail end,
            callback = function() section.show_thumbnail = not section.show_thumbnail; Config.saveAndRefresh(ctx) end
        },
        {
            text = _("Show skim"),
            checked_func = function() return section.show_skim end,
            callback = function() section.show_skim = not section.show_skim; Config.saveAndRefresh(ctx) end,
            separator = true
        },
        {
        text = _("Reset to defaults"),
        keep_menu_open = true,
        callback = close(function(touch_menu)
            if touch_menu then ctx.touch_menu = touch_menu end
            UIManager:show(ConfirmBox:new{
                text = _("Are you sure you want to reset to defaults ?"),
                ok_text = _("Reset"),
                ok_callback = function()
                    local defaults = Config.DEFAULTS.sections[SECTION]
                    Utils.resetSectionToDefaults(section, defaults)
                    Config.saveAndRefresh(ctx)
                    if refresh then refresh() end
                end
            })
        end)
        }
    }
end

function Info.showSettings(ctx)
    local dialog

    local function close(fn)
        return function()
            if dialog then UIManager:close(dialog) end
            if fn then fn() end
        end
    end

    local function refresh()
        Info.showSettings(ctx)
    end

    local buttons = Utils.wrap_items(Info.getSettings(ctx, close, refresh))
    if not buttons or #buttons==0 then return end
    dialog = ButtonDialog:new{
        -- dismissable = false,
        title = _("Settings") .. " : " .. SECTION,
        title_align  = "left",
        width_factor = 0.9,
        buttons = buttons,
    }
    UIManager:show(dialog)

end

return Info
