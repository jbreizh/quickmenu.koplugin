--[[
    widgets/shadow_deco.lua

    Reusable bottom-right drop-shadow for any bordered widget (buttons,
    sliders, cover cards). Call ShadowDeco.attach(widget[, radius]) right
    after creating the widget (a FrameContainer, or anything else with
    getSize() and paintTo(bb, x, y)): it wraps that specific instance's
    paintTo to draw an offset, rounded shadow rectangle first, then calls
    the original draw unchanged on top of it. Nothing about the widget's
    size, padding, border, or content positioning is touched.

    Uses bb:paintRoundedRect(x, y, w, h, color, radius), the same core
    KOReader Blitbuffer method FrameContainer itself uses to draw rounded
    backgrounds, so corner rounding matches exactly.
--]]

local Blitbuffer = require("ffi/blitbuffer")


local ShadowDeco = {}

-- radius_override: use this radius for the shadow shape instead of
-- widget.radius (needed for widgets, like ZenSlider, that don't expose
-- a plain `radius` field).
function ShadowDeco.attach(widget, shadow_offset, shadow_intensity, shadow_radius)
    if not widget or widget._qs_btn_shadow then return widget end
    widget._qs_btn_shadow = true
    local orig_paintTo = widget.paintTo
    if not orig_paintTo then return widget end
    widget.paintTo = function(self, bb, x, y)
        local ok, sz = pcall(function() return self:getSize() end)
        if ok and sz and sz.w and sz.h and sz.w > 0 and sz.h > 0 then
            local offset = shadow_offset or 0
            local color = Blitbuffer.gray(shadow_intensity or 0)
            local radius = self.radius or shadow_radius or 0
            bb:paintRoundedRect(x + offset, y + offset, sz.w, sz.h, color, radius)
        end
        orig_paintTo(self, bb, x, y)
    end
    return widget
end

return ShadowDeco
