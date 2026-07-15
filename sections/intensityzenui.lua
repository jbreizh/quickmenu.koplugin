-- Original idea : AnthonyGress https://github.com/AnthonyGress/zen_ui.koplugin
-- Brightness (frontlight) slider section for the Quick Settings panel.
-- Returns a populated VerticalGroup and registers slider/toggle refs.
--
-- Usage:
--   local build_brightness_slider = require("modules/menu/patches/brightness_slider")
--   local group = build_brightness_slider(touch_menu, {
--       inner_width, slider_width, small_btn_width, toggle_width, slider_gap,
--       medium_font, small_btn_font, powerd, refs,
--   })

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

local Utils            = require("common/utils")
local ZenSlider       = require("widgets/zen_slider")
local Config           = require("config")
local _               = require("common/i18n").gettext

local IntensityZenUI = {
    id = "frontlight"
}

function IntensityZenUI.build(ctx, settings_func)
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

    local section = Utils.getSection(config, IntensityZenUI.id)
    if not section then return nil end
    --
    local show_parent        = touch_menu.show_parent
    local medium_font        = Font:getFace("cfont", btn_font_size)
    local slider_width       = inner_width - 2 * btn_width - 2 * h_gap
    local hasNaturalLight = true --not not device:hasNaturalLight() -- force bool
    --
    local group = VerticalGroup:new{ align = "center" }
    local refs = { buttons = {}, sliders = {}, widgets = {} }
    local update_touch_menu = function() if touch_menu and touch_menu.updateItems then touch_menu:updateItems() end end

    local fl = {
        min = powerd.fl_min,
        max = powerd.fl_max,
        cur = powerd:frontlightIntensity(),
    }

    -- Split label: static prefix + fixed-width number box so the prefix
    -- never shifts when the number changes width (e.g. 9 → 10).
    local fl_drag_prefix
    local fl_drag_prefix_w
    local fl_drag_num
    local fl_drag_max_num_w
    if section.show_title then
        local fl_prefix_text = _("Frontlight") .. " : "
        fl_drag_prefix = TextWidget:new{ text = fl_prefix_text, face = medium_font, bold = true }
        fl_drag_prefix_w = fl_drag_prefix:getSize().w
        fl_drag_num = TextWidget:new{ text = tostring(fl.cur), face = medium_font, bold = true }
        local fl_max_num_sample = TextWidget:new{ text = tostring(fl.max), face = medium_font, bold = true }
        fl_drag_max_num_w = fl_max_num_sample:getSize().w
        fl_max_num_sample:free()

        -- add suffix
        local fl_suffix_text = "%"
        local fl_drag_suffix = TextWidget:new{ text = fl_suffix_text, face = medium_font, bold = true }
        local fl_drag_suffix_w = fl_drag_suffix:getSize().w

        local fl_drag_ref_w = btn_width + fl_drag_prefix_w + fl_drag_max_num_w + fl_drag_suffix_w -- add collapse_btn + suffix

        local fl_label_h = fl_drag_prefix:getSize().h
        local fl_num_box = LeftContainer:new{
            dimen = Geom:new{ w = fl_drag_max_num_w, h = fl_label_h },
            fl_drag_num,
        }
        -- collapse_btn
        local collapse_btn = Button:new{
            text           = section.collapse and "▶" or "▼",
            width          = btn_width,
            radius         = btn_radius,
            bordersize     = 0,
            text_font_size = btn_font_size,
            show_parent    = touch_menu.show_parent,
            callback       = function()
                section.collapse = not section.collapse
                Config.save(config, true) -- no flush
                update_touch_menu()
            end,
            -- hold_callback
        }
        --
        local fl_label_group = HorizontalGroup:new{
            collapse_btn,   -- add collapse_btn
            fl_drag_prefix,
            fl_num_box,
            fl_drag_suffix, -- add suffix
        }
        if section.collapse and hasNaturalLight then
            local nl_label = TextWidget:new{ text = " - " .. _("Warmth") .. " : " .. powerd:frontlightWarmth() .. "%", face = medium_font, bold = true }
            table.insert(fl_label_group, nl_label)
            table.insert(fl_label_group, HorizontalSpan:new{ width = inner_width - fl_drag_ref_w - btn_width -nl_label:getSize().w})
        else
            table.insert(fl_label_group, HorizontalSpan:new{ width = inner_width - fl_drag_ref_w - btn_width})
        end
        -- settings
        local settings_btn = Button:new{
            text           = "\u{EB92}",
            width          = btn_width,
            radius         = btn_radius,
            bordersize     = 0,
            text_font_size = btn_font_size,
            show_parent    = touch_menu.show_parent,
            callback       = function()
                if settings_func then settings_func() end
            end,
            --hold_callback = function() end,
        }
        table.insert(fl_label_group, settings_btn)
        --
        local fl_cap_row = LeftContainer:new{
            dimen = Geom:new{ w = inner_width, h = fl_label_h },
            fl_label_group,
        }
        table.insert(group, fl_cap_row)
        -- collapse break
        if section.collapse then return { widget = group , refs = refs} end
    end

    -- progress bar
    local fl_progress = ZenSlider:new{
        width     = slider_width,
        value     = fl.cur,
        value_min = fl.min,
        value_max = fl.max,
        show_parent = show_parent,
        --knob_radius = screen:scaleBySize(13),
    }

    local fl_row  -- forward-declare for on_change closure

    local function setBrightness(intensity)
        if intensity ~= fl.min and intensity == fl.cur then return end
        intensity = math.max(fl.min, math.min(fl.max, intensity))
        powerd:setIntensity(intensity)
        fl.cur = intensity
        if fl.cur > fl.min then fl.prev_non_min = fl.cur end
        fl_progress:setValue(fl.cur)
        if section.show_title then fl_drag_num:setText(tostring(fl.cur)) end --
        UIManager:setDirty(show_parent, "ui", touch_menu.dimen)
    end

    fl.prev_non_min = fl.cur > fl.min and fl.cur or math.min(fl.max, fl.min + 1)

    -- During drag: paint directly to Screen.bb and push A2 refresh via
    -- setDirty(nil) — bypasses the widget tree entirely, so no competing
    -- GL16 from other widgets can cause flicker.  A2 completes in ~60ms
    -- and renders the pure B/W slider content without ghosting.
    -- On release / tap: full menu GL16 refresh to update label + slider.
    fl_progress.on_change = function(v)
        powerd:setIntensity(v)
        fl.cur = v
        if fl.cur > fl.min then fl.prev_non_min = fl.cur end
        if fl_progress._dragging then
            fl_progress:paintTo(screen.bb, fl_progress.dimen.x, fl_progress.dimen.y)
            -- Only repaint the number — prefix is static in the framebuffer.
            if section.show_title then
                local row_gap_h = 0 -- v_gap
                local lh = fl_drag_prefix:getSize().h
                local row_h = fl_row and fl_row:getSize().h or fl_progress.dimen.h
                local row_top = fl_progress.dimen.y - math.floor((row_h - fl_progress.dimen.h) / 2)
                local label_y = row_top - row_gap_h - lh
                local sx = fl_progress.dimen.x
                local sw = fl_progress.dimen.w
                local num_x = sx - h_gap - btn_width + btn_width + fl_drag_prefix_w
                screen.bb:paintRect(num_x, label_y, fl_drag_max_num_w, lh, Blitbuffer.COLOR_WHITE)
                    fl_drag_num:setText(tostring(fl.cur))
                    fl_drag_num:paintTo(screen.bb, num_x, label_y)
                -- Single A2 covering label + slider (two back-to-back A2 calls
                -- can race on Kobo, causing the second refresh to be dropped).
                UIManager:setDirty(nil, "fast", Geom:new{
                    x = fl_progress.dimen.x,
                    y = label_y,
                    w = fl_progress.dimen.w,
                    h = fl_progress.dimen.y + fl_progress.dimen.h - label_y,
                })
            else
                -- Single A2 covering label + slider (two back-to-back A2 calls
                -- can race on Kobo, causing the second refresh to be dropped).
                UIManager:setDirty(nil, "fast", Geom:new{
                    x = fl_progress.dimen.x,
                    y = fl_progress.dimen.y,
                    w = fl_progress.dimen.w,
                    h = fl_progress.dimen.y + fl_progress.dimen.h,
                })
            end
            -- update touch_menu after dragging
            UIManager:unschedule(update_touch_menu)
            UIManager:scheduleIn(0.5, update_touch_menu)
        else
            if section.show_title then fl_drag_num:setText(tostring(fl.cur)) end
            update_touch_menu()
            --UIManager:setDirty(show_parent, "ui", touch_menu.dimen)
        end
    end

    local fl_minus = Button:new{
        text           = "\u{EA2D}", --"−"
        text_font_size = btn_font_size,
        --text_font_bold = false,
        width          = btn_width,
        bordersize     = 0,
        show_parent    = show_parent,
        callback       = function() setBrightness(fl.cur - 1); update_touch_menu() end,
        hold_callback  = function() setBrightness(fl.min); update_touch_menu() end,
    }

    local fl_plus = Button:new{
        text           = "\u{EA2B}", --"＋"
        text_font_size = btn_font_size,
        --text_font_bold = false,
        width          = btn_width,
        bordersize     = 0,
        show_parent    = show_parent,
        callback       = function() setBrightness(fl.cur + 1) ; update_touch_menu() end,
        hold_callback  = function() setBrightness(fl.max); update_touch_menu() end,
    }


    fl_row = HorizontalGroup:new{
        align = "center",
        fl_minus,
        HorizontalSpan:new{ width = h_gap },
        fl_progress,
        HorizontalSpan:new{ width = h_gap },
        fl_plus,
    }

    refs.fl_progress   = fl_progress
    refs.fl_state      = fl
    refs.setBrightness = setBrightness
    table.insert(refs.sliders, { slider = fl_progress })

    --table.insert(group, VerticalSpan:new{ width = v_gap })
    table.insert(group, fl_row)
    return { widget = group, refs = refs }
end

return IntensityZenUI
