local Blitbuffer      = require("ffi/blitbuffer")

local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local TextWidget      = require("ui/widget/textwidget")

local Font            = require("ui/font")
local RenderImage     = require("ui/renderimage")

local InfoSection     = require("sections/infosection")
local SkimSection     = require("sections/skimsection")
local CoverButton     = require("widgets/coverbutton")
local Utils           = require("common/utils")
local Translation     = require("i18n/translation")
local _               = Translation._

local Info = {}

function Info.build(ctx)
    local config       = ctx.config
    local touch_menu   = ctx.touch_menu
    local filemanager  = ctx.filemanager
    local reader       = ctx.reader
    local inner_width  = ctx.inner_width
    local screen       = ctx.screen
    local theme        = ctx.theme or {}
    local section      = Utils.getSection(config, "info")

    if not section or not section.enabled_r or not reader then return nil end
    local refs = { buttons = {}, sliders = {}, widgets = {} }

    -- style
    local gap            = theme.gap or screen:scaleBySize(4)
    local vgap           = theme.vgap or screen:scaleBySize(4)
    local btn_radius     = theme.btn_radius or 0
    local btn_bordersize = theme.btn_bordersize  or 0
    local btn_font_size  = theme.btn_font_size  or 16
    local color_gray     = theme.color_gray or Blitbuffer.COLOR_DARK_GRAY

    local info_col = VerticalGroup:new{ align = "center" }
    local infoSection = InfoSection.build(ctx)
    table.insert(info_col, infoSection.widget)

    if section.show_skim then
        local skimSection = SkimSection.build(ctx)
        table.insert(info_col, VerticalSpan:new{ width = vgap })
        table.insert(info_col, skimSection.widget)
        table.insert(refs.sliders, skimSection.refs.sliders[1])
    end

    --
    local row = HorizontalGroup:new{ align = "center" }

    if section.show_thumbnail then
        local cover_h = info_col:getSize().h
        local cover_w = math.floor(2 * cover_h / 3 + 0.5)
        local ok, thumbnail = pcall(function() return reader.bookinfo:getCoverImage(reader.document) end)

        if ok then
            thumbnail = RenderImage:scaleBlitBuffer(thumbnail, cover_w, cover_h, true)
            info_thumbnail = CoverButton:new{
                image = thumbnail,
                width = cover_w,
                height = cover_h,
                radius = btn_radius,
                bordersize = btn_bordersize,
                padding = 0, --gap,
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
            table.insert(row, HorizontalSpan:new{ width = gap })

            local opts = {}
            for k, v in pairs(ctx) do opts[k] = v end
            opts.inner_width = inner_width - cover_w - 2 * gap

            info_col = VerticalGroup:new{ align = "left" }
            local infoSection = InfoSection.build(opts)
            table.insert(info_col, infoSection.widget)

            if section.show_skim then
                local skimSection = SkimSection.build(opts)
                table.insert(info_col, VerticalSpan:new{ width = vgap })
                table.insert(info_col, skimSection.widget)
                table.insert(refs.sliders, skimSection.refs.sliders[1])
            end
        end
    end

    table.insert(row, info_col)

    local group = VerticalGroup:new{ align = "center", row }

    if section.show_title then
        local info_label = TextWidget:new{
            text = _("Informations") .. " :",
            face =  Font:getFace("cfont", btn_font_size), bold = true,
            max_width = inner_width,
        }
        table.insert(group, 1, info_label)
    end

    return { widget = group , refs = refs }
end

function Info.getSettings(config, saveConfig, ctx)
    local section = Utils.getSection(config, "info")
    if not section then return {} end

    return {
        {
            text = _("Enabled in reader"),
            checked_func = function() return section.enabled_r end,
            callback = function() section.enabled_r = not section.enabled_r; saveConfig() end
        },
        {
            text = _("Show title"),
            checked_func = function() return section.show_title end,
            callback = function() section.show_title = not section.show_title; saveConfig() end
        },
        {
            text = _("Show thumbnail"),
            checked_func = function() return section.show_thumbnail end,
            callback = function() section.show_thumbnail = not section.show_thumbnail; saveConfig() end
        },
        {
            text = _("Show skim"),
            checked_func = function() return section.show_skim end,
            callback = function() section.show_skim = not section.show_skim; saveConfig() end
        },
    }
end

return Info
