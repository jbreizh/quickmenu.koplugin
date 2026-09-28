local ProgressWidget = require("ui/widget/progresswidget")

local QmSlider = ProgressWidget:extend{
    min = 0,
    max = 100,
    fromPercent = nil,
    set = nil,
    get = nil,
    hold_callback = nil,
}

-- tap
function QmSlider:handleTap(ges)
    if self.dimen and ges.pos:intersectWith(self.dimen) then
        local percent = self.getPercentageFromPosition and self:getPercentageFromPosition(ges.pos)
        if percent then
            local value
            if self.fromPercent then value = self.fromPercent(percent)
            else value = math.floor((self.max - self.min) * percent + self.min + 0.5) end
            if self.set then self.set(value) return true
            end
        end
    end
    return false
end

-- hold
function QmSlider:handleHold(ges)
    if self.dimen and ges.pos:intersectWith(self.dimen) then
        if self.hold_callback then
            self.hold_callback()
            return true
        end
    end
    return false
end

return QmSlider
