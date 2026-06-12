local InputContainer = require("ui/widget/container/inputcontainer")
local GestureRange = require("ui/gesturerange")
local FrameContainer = require("ui/widget/container/framecontainer")

local ClickableGroup = InputContainer:extend{
    callback = nil,
    hold_callback = nil,
    padding = 0,
    bordersize = 0,
    bordercolor = nil,
    background = nil,
    radius = 0,
}

function ClickableGroup:init()
    self.frame = FrameContainer:new{
        padding = self.padding,
        background = self.background,
        radius = self.radius,
        bordersize = self.bordersize,
        color = self.bordercolor,
        unpack(self) -- Contient votre VerticalGroup
    }

    self.dimen = self.frame:getSize()
    self[1] = self.frame

    self.ges_events = {
        TapSelect = { GestureRange:new{ ges = "tap", range = self.dimen } },
        HoldSelect = { GestureRange:new{ ges = "hold", range = self.dimen } }
    }
end

function ClickableGroup:onTapSelect()
    if self.callback then
        self.callback()
        return true
    end
    return false
end

function ClickableGroup:onHoldSelect()
    if self.hold_callback then
        self.hold_callback()
        return true
    end
    return false
end

return ClickableGroup
