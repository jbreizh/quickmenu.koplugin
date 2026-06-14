local Blitbuffer      = require("ffi/blitbuffer")

local VerticalGroup   = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local TextBoxWidget   = require("ui/widget/textboxwidget")
local TextWidget      = require("ui/widget/textwidget")

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
    local filemanager  = ctx.filemanager
    local reader       = ctx.reader
    local inner_width  = ctx.inner_width
    local screen       = ctx.screen
    local theme        = ctx.theme or {}
    local section      = Utils.getSection(config, "info")

    if not section or not section.enabled_r or not reader then return nil end

    -- style
    local gap            = theme.gap or screen:scaleBySize(4)
    local btn_radius     = theme.btn_radius or 0
    local btn_bordersize = theme.btn_bordersize  or 0
    local btn_font_size  = theme.btn_font_size  or 16
    local color_gray     = theme.color_gray or Blitbuffer.COLOR_DARK_GRAY

    -- thumbnail
    local info_thumbnail, cover_w = nil, 0
    local ok, thumbnail = pcall(function() return reader.bookinfo:getCoverImage(reader.document) end)
    if not ok or not section.show_thumbnail then thumbnail = nil end

    if thumbnail then
        local max_h = screen:scaleBySize(100) -- TODO change for a clever value
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
    local txt_w = inner_width - 2 * gap - (info_thumbnail and (cover_w + 3 * gap) or 0) -- WARNING (gap*2) for padding clickable_text_container and (gap*2) for padding info_thumbnail
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

    if section.show_title then
        local info_label = TextWidget:new{
            text = _("Informations") .. " :",
            face =  Font:getFace("cfont", btn_font_size), bold = true,
            max_width = inner_width,
        }
        table.insert(group, 1, info_label)
    end

    return { widget = group }
end

function InfoSection.getSettings(config, saveConfig, ctx)
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
            callback = function()
                section.show_title = not section.show_title
                saveConfig()
            end
        },
        {
            text = _("Show thumbnail"),
            checked_func = function() return section.show_thumbnail end,
            callback = function() section.show_thumbnail = not section.show_thumbnail; saveConfig() end
        }
    }
end

return InfoSection
