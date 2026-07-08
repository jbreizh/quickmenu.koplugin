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
local _               = require("common/i18n").gettext

local InfoSection = {}

function InfoSection.build(ctx)
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

    if not reader then return nil end
    -- text
    local txt_w = inner_width - 2 * h_gap -- WARNING (h_gap*2) for padding clickable_text_container
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
        padding = h_gap,
        bordersize = btn_bordersize,
        bordercolor = Blitbuffer.COLOR_DARK_GRAY,
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
