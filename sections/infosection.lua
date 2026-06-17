local Blitbuffer      = require("ffi/blitbuffer")

local VerticalGroup   = require("ui/widget/verticalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local TextWidget      = require("ui/widget/textwidget")

local Font            = require("ui/font")

local UIManager       = require("ui/uimanager")
local InfoMessage     = require("ui/widget/infomessage")
local Event           = require("ui/event")

local ClickableGroup  = require("widgets/clickablegroup")
local Utils           = require("common/utils")
local Translation     = require("i18n/translation")
local _               = Translation._

local InfoSection = {}

function InfoSection.build(opts)
    local touch_menu   = opts.touch_menu
    local reader       = opts.reader
    local inner_width  = opts.inner_width
    local screen       = opts.screen
    local theme        = opts.theme or {}

    -- style
    local gap            = theme.gap or screen:scaleBySize(4)
    local vgap           = theme.vgap or screen:scaleBySize(4)
    local btn_radius     = theme.btn_radius or 0
    local btn_bordersize = theme.btn_bordersize  or 0
    local btn_font_size  = theme.btn_font_size  or 16
    local color_gray     = theme.color_gray or Blitbuffer.COLOR_DARK_GRAY

    if not reader then return nil end
    -- text
    local txt_w = inner_width - 2 * gap -- WARNING (gap*2) for padding clickable_text_container
    local info_title = TextWidget:new{
        text = (reader.doc_props or {}).display_title or reader.props.title or _("Unknown title"),
        max_width = txt_w,
        face =  Font:getFace("cfont", btn_font_size),
        bold = true
    }
    local info_auth = TextWidget:new{
        text = (reader.doc_props or {}).authors or _("Unknown author"),
        max_width = txt_w,
        face = Font:getFace("cfont", btn_font_size)
    }
    local info_chap = TextWidget:new{
        text = reader.toc:getTocTitleByPage(reader:getCurrentPage()) or _("Unknown chapter"),
        max_width = txt_w,
        face = Font:getFace("cfont", btn_font_size)
    }

    -- clickableGroup
    local col_text = VerticalGroup:new{ align = "left", info_title, info_auth, info_chap, HorizontalSpan:new{ width = txt_w } }
    local clickable_text_container = ClickableGroup:new{
        col_text,
        radius = btn_radius,
        padding = gap,
        bordersize = btn_bordersize,
        bordercolor = color_gray,
        callback = function()
            touch_menu:closeMenu()
            reader.status:onShowBookStatus()
            end,
        hold_callback = function()
            touch_menu:closeMenu()
            if Utils.hasPlugin and Utils.hasPlugin("statistics") then
                UIManager:broadcastEvent(Event:new("ShowBookStats"))
            else
                UIManager:show(InfoMessage:new{ text = "Statistics : " .. _("Plugin not activated.") })
            end
        end
    }

    return { widget = clickable_text_container }
end

return InfoSection
