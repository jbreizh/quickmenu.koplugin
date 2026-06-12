local InputContainer = require("ui/widget/container/inputcontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local IconWidget = require("ui/widget/iconwidget")
local GestureRange = require("ui/gesturerange")

local CoverButton = InputContainer:extend{
    image = nil,
    width = 0,
    height = 0,
    bordersize = 0,
    padding = 0,
    radius = 0,
    callback = nil,
    hold_callback = nil,
}

function CoverButton:init()
    local image_widget = IconWidget:new{
        image = self.image,
        width = self.width,
        height = self.height,
    }

    self[1] = FrameContainer:new{
        bordersize = self.bordersize,
        padding = self.padding,
        radius = self.radius,
        image_widget,
    }

    self.dimen = self[1]:getSize()

    self.ges_events = {
        TapCover  = { GestureRange:new{ ges = "tap",  range = self.dimen } },
        HoldCover = { GestureRange:new{ ges = "hold", range = self.dimen } }
    }
end

function CoverButton:onTapCover()
    if self.callback then
        self.callback()
        return true
    end
    return false
end

function CoverButton:onHoldCover()
    if self.hold_callback then
        self.hold_callback()
        return true
    end
    return false
end

return CoverButton
