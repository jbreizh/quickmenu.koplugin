local Blitbuffer = require("ffi/blitbuffer")


local ShadowDeco = {}

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
            local radius = self.radius or shadow_radius or 0 -- shadow_radius use for widgets that don't expose a plain `radius` field).
            bb:paintRoundedRect(x + offset, y + offset, sz.w, sz.h, color, radius)
        end
        orig_paintTo(self, bb, x, y)
    end
    return widget
end

return ShadowDeco
