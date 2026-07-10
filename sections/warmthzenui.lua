-- Original idea : AnthonyGress https://github.com/AnthonyGress/zen_ui.koplugin
-- Warmth (natural light) slider section for the Quick Settings panel.
-- Returns a populated VerticalGroup and registers slider/toggle refs.
-- The caller is responsible for checking Device:hasNaturalLight() before calling.
--
-- Usage:
--   local build_warmth_slider = require("modules/menu/patches/warmth_slider")
--   if config.show_warmth and Device:hasNaturalLight() then
--       warmth_group = build_warmth_slider(touch_menu, { ... })
--   end

local Blitbuffer      = require("ffi/blitbuffer")
local Button          = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font            = require("ui/font")
local Geom            = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local LeftContainer   = require("ui/widget/container/leftcontainer")
local TextWidget      = require("ui/widget/textwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local ZenSlider       = require("widgets/zen_slider")
local _               = require("common/i18n").gettext

local WarmthZenUI = {}

function WarmthZenUI.build(ctx)
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

    --
    local label_center       = false
    local show_parent        = touch_menu.show_parent
    local medium_font        = Font:getFace("cfont", btn_font_size)
    local slider_width       = inner_width - 2 * btn_width - 2 * h_gap

    local nl = {
        min = powerd.fl_warmth_min,
        max = powerd.fl_warmth_max,
        cur = powerd:toNativeWarmth(powerd:frontlightWarmth()),
    }

    -- Split label: static prefix + fixed-width number box so the prefix
    -- never shifts when the number changes width (e.g. 9 → 10).
    local nl_prefix_text = _("Warmth") .. " : "
    local nl_drag_prefix = TextWidget:new{ text = nl_prefix_text, face = medium_font, bold = true }
    local nl_drag_prefix_w = nl_drag_prefix:getSize().w
    local nl_drag_num = TextWidget:new{ text = tostring(nl.cur), face = medium_font, bold = true }
    local nl_max_num_sample = TextWidget:new{ text = tostring(nl.max), face = medium_font, bold = true }
    local nl_drag_max_num_w = nl_max_num_sample:getSize().w
    nl_max_num_sample:free()

        -- add suffix
    local nl_suffix_text = "%"
    local nl_drag_suffix = TextWidget:new{ text = nl_suffix_text, face = medium_font, bold = true }
    local nl_drag_suffix_w = nl_drag_suffix:getSize().w

    local nl_drag_ref_w = nl_drag_prefix_w + nl_drag_max_num_w + nl_drag_suffix_w
    local nl_label_h = nl_drag_prefix:getSize().h
    local nl_num_box = LeftContainer:new{
        dimen = Geom:new{ w = nl_drag_max_num_w, h = nl_label_h },
        nl_drag_num,
    }

    local nl_label_group = HorizontalGroup:new{
        nl_drag_prefix,
        nl_num_box,
        nl_drag_suffix -- add suffix
    }

    local nl_progress = ZenSlider:new{
        width     = slider_width,
        value     = nl.cur,
        value_min = nl.min,
        value_max = nl.max,
        show_parent = show_parent,
        knob_radius = screen:scaleBySize(13),
    }

    local nl_row  -- forward-declare for on_change closure

    local function setWarmth(warmth)
        if warmth == nl.cur then return end
        warmth = math.max(nl.min, math.min(nl.max, warmth))
        powerd:setWarmth(powerd:fromNativeWarmth(warmth))
        nl.cur = warmth
        if nl.cur > nl.min then nl.prev_non_min = nl.cur end
        nl_progress:setValue(nl.cur)
        nl_drag_num:setText(tostring(nl.cur))
        UIManager:setDirty(show_parent, "ui", touch_menu.dimen)
    end

    nl.prev_non_min = nl.cur > nl.min and nl.cur or math.min(nl.max, nl.min + 1)

    -- During drag: paint directly to Screen.bb and push A2 refresh via
    -- setDirty(nil) — bypasses the widget tree entirely, so no competing
    -- GL16 from other widgets can cause flicker.  A2 completes in ~60ms
    -- and renders the pure B/W slider content without ghosting.
    -- On release / tap: full menu GL16 refresh to update label + slider.

    local update_touch_menu = function() if touch_menu and touch_menu.updateItems then touch_menu:updateItems() end end

    nl_progress.on_change = function(v)
        powerd:setWarmth(powerd:fromNativeWarmth(v))
        nl.cur = v
        if nl.cur > nl.min then nl.prev_non_min = nl.cur end
        if nl_progress._dragging then
            nl_progress:paintTo(screen.bb, nl_progress.dimen.x, nl_progress.dimen.y)
            -- Only repaint the number — prefix is static in the framebuffer.
            local row_gap_h = 0 -- v_gap
            local lh = nl_drag_prefix:getSize().h
            local row_h = nl_row and nl_row:getSize().h or nl_progress.dimen.h
            local row_top = nl_progress.dimen.y - math.floor((row_h - nl_progress.dimen.h) / 2)
            local label_y = row_top - row_gap_h - lh
            local sx = nl_progress.dimen.x
            local sw = nl_progress.dimen.w
            local num_x
            if label_center then
                num_x = sx + math.floor((sw - nl_drag_ref_w) / 2) + nl_drag_prefix_w
            else
                num_x = sx - h_gap - btn_width + nl_drag_prefix_w
            end
            screen.bb:paintRect(num_x, label_y, nl_drag_max_num_w, lh, Blitbuffer.COLOR_WHITE)
            nl_drag_num:setText(tostring(nl.cur))
            nl_drag_num:paintTo(screen.bb, num_x, label_y)
            -- Single A2 covering label + slider (two back-to-back A2 calls
            -- can race on Kobo, causing the second refresh to be dropped).
            UIManager:setDirty(nil, "fast", Geom:new{
                x = nl_progress.dimen.x,
                y = label_y,
                w = nl_progress.dimen.w,
                h = nl_progress.dimen.y + nl_progress.dimen.h - label_y,
            })
            -- update touch_menu after dragging
            UIManager:unschedule(update_touch_menu)
            UIManager:scheduleIn(0.5, update_touch_menu)
        else
            nl_drag_num:setText(tostring(nl.cur))
            update_touch_menu()
            --UIManager:setDirty(show_parent, "ui", touch_menu.dimen)
        end
    end

    local nl_minus = Button:new{
        text           = "−",
        text_font_size = btn_font_size,
        --text_font_bold = false,
        width          = btn_width,
        bordersize     = 0,
        show_parent    = show_parent,
        callback       = function() setWarmth(nl.cur - 1); update_touch_menu() end,
        hold_callback  = function() setWarmth(nl.min); update_touch_menu() end,
    }

    local nl_plus = Button:new{
        text           = "＋",
        text_font_size = btn_font_size,
        --text_font_bold = false,
        width          = btn_width,
        bordersize     = 0,
        show_parent    = show_parent,
        callback       = function() setWarmth(nl.cur + 1); update_touch_menu() end,
        hold_callback  = function() setWarmth(nl.max); update_touch_menu() end,
    }

    local nl_cap_row
    if label_center then
        nl_cap_row = CenterContainer:new{
            dimen = Geom:new{ w = inner_width, h = nl_label_h },
            nl_label_group,
        }
    else
        nl_cap_row = LeftContainer:new{
            dimen = Geom:new{ w = inner_width, h = nl_label_h },
            nl_label_group,
        }
    end

    nl_row = HorizontalGroup:new{
        align = "center",
        nl_minus,
        HorizontalSpan:new{ width = h_gap },
        nl_progress,
        HorizontalSpan:new{ width = h_gap },
        nl_plus,
    }
    local refs = { buttons = {}, sliders = {}, widgets = {} }
    refs.nl_progress = nl_progress
    refs.nl_state    = nl
    refs.setWarmth   = setWarmth
    table.insert(refs.sliders, { slider = nl_progress })

    local group = VerticalGroup:new{ align = "center" }
    table.insert(group, nl_cap_row)
    -- table.insert(group, VerticalSpan:new{ width = v_gap })
    table.insert(group, nl_row)
    return { widget = group, refs = refs }
end

return WarmthZenUI
