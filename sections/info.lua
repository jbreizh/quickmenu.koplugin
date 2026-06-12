local Blitbuffer      = require("ffi/blitbuffer")

local VerticalGroup   = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local TextBoxWidget   = require("ui/widget/textboxwidget")

local Font            = require("ui/font")
local RenderImage     = require("ui/renderimage")

local UIManager       = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local Event           = require("ui/event")


local CoverButton     = require("widgets/coverbutton")
local ClickableGroup  = require("widgets/clickablegroup")
local Utils           = require("common/utils")
local Translation     = require("i18n/translation")
local _               = Translation._

local InfoSection = {}

function InfoSection.build(ctx)
    local config       = ctx.config
    local touch_menu   = ctx.touch_menu
    local reader       = ctx.reader
    local section      = Utils.getSection(config, "info")

    if not section or not section.enabled or not reader then return nil end

    -- style
    local gap            = ctx.theme.gap or ctx.screen:scaleBySize(4)
    local btn_radius     = ctx.theme.btn_radius or 0
    local btn_bordersize = ctx.theme.btn_bordersize  or 0
    local btn_font_size  = ctx.theme.btn_font_size  or 16
    local color_gray     = ctx.theme.color_gray or Blitbuffer.COLOR_DARK_GRAY

    -- thumbnail
    local info_thumbnail, cover_w = nil, 0
    local ok, thumbnail = pcall(function() return reader.bookinfo:getCoverImage(reader.document) end)
    if not ok or not section.show_thumbnail then thumbnail = nil end

    if thumbnail then
        local max_h = ctx.screen:scaleBySize(100) -- TODO change for a clever value
        local w, h = thumbnail:getWidth(), thumbnail:getHeight()
        if h > max_h then
            w = math.floor(w * max_h / h + 0.5); h = max_h
            thumbnail = RenderImage:scaleBlitBuffer(thumbnail, w, h, true)
        end
        cover_w = w
        info_thumbnail = CoverButton:new{
            image = thumbnail, width = w, height = h, radius = btn_radius, bordersize = btn_bordersize, padding = gap,
            callback = function() reader.bookinfo:onShowBookCover(reader.document.file) end,
            hold_callback = function() reader.bookinfo:onShowBookDescription(false, reader.document.file) end
        }
    end

    -- text
    local txt_w = ctx.inner_width - gap - (info_thumbnail and (cover_w + gap) or 0) - (gap * 2) -- WARNING (gap*2) for padding ClickableGroup
    local info_title = TextBoxWidget:new{
        text = (reader.doc_props or {}).display_title or reader.props.title or _("Unknown title"),
        width = txt_w, alignment = "center", face =  Font:getFace("cfont", btn_font_size), bold = true
    }
    local info_auth = TextBoxWidget:new{
        text = (reader.doc_props or {}).authors or _("Unknown author"),
        width = txt_w, alignment = "center", face = Font:getFace("cfont", btn_font_size)
    }
    local info_chap = TextBoxWidget:new{
        text = reader.toc:getTocTitleByPage(reader:getCurrentPage()) or _("Unknown chapter"),
        width = txt_w, alignment = "center", face = Font:getFace("cfont", btn_font_size)
    }

    -- ClickableGroup
    local col_text = VerticalGroup:new{ align = "center", info_title, info_auth, info_chap }

    local clickable_text_container = ClickableGroup:new{
        col_text,
        radius = btn_radius,
        padding = gap,
        bordersize = btn_bordersize,
        bordercolor = color_gray,
        callback = function() reader.status:onShowBookStatus() end,
        hold_callback = function()
            if Utils.hasPlugin and Utils.hasPlugin("statistics") then
                UIManager:broadcastEvent(Event:new("ShowBookStats"))
            else
                UIManager:show(InfoMessage:new{ text = "Statistics : " .. _("Plugin not activated.") })
            end
        end
    }

    local row = HorizontalGroup:new{ align = "center", clickable_text_container }
    if info_thumbnail then
        table.insert(row, 1, HorizontalSpan:new{ width = gap })
        table.insert(row, 1, info_thumbnail)
    end

    local group = VerticalGroup:new{ align = "center", row }
    return { widget = group }
end

function InfoSection.getSettings(config, saveConfig, ctx)
    local section = Utils.getSection(config, "info")
    if not section then return {} end

    return {
        {
            text = _("Show info controls"),
            checked_func = function() return section.enabled end,
            callback = function() section.enabled = not section.enabled; saveConfig() end
        },
        {
            text = _("Show info thumbnail"),
            checked_func = function() return section.show_thumbnail end,
            callback = function() section.show_thumbnail = not section.show_thumbnail; saveConfig() end
        }
    }
end

return InfoSection
