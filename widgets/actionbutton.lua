local InputContainer = require("ui/widget/container/inputcontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local TextWidget = require("ui/widget/textwidget")
local IconWidget = require("ui/widget/iconwidget")

local GestureRange = require("ui/gesturerange")
local Geom = require("ui/geometry")

local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local UIManager = require("ui/uimanager")

local CircleButton = InputContainer:extend{
    icon = nil,
    size = 64,
    icon_size = 26,
    radius = 32,
    is_active = false,
    bordersize = 0,
    callback = nil,
    hold_callback = nil,
    bg_active = Blitbuffer.COLOR_LIGHT_GRAY,
    bg_inactive = Blitbuffer.COLOR_WHITE,
}

function CircleButton:init()
    local content_widget
    local icon_val = self.icon or ""

    -- On cherche si la chaîne correspond au format [icon=nom_icone]
    local extracted_icon = icon_val:match("^%[icon=(.+)%]$")

    if extracted_icon then
        content_widget = IconWidget:new{
            icon  = extracted_icon,
            width = self.size * 0.4, -- TODO Hack
            height = self.size * 0.4,
            alpha = true,
        }
    else
        -- Sinon, on traite le contenu comme un caractère Unicode
        content_widget = TextWidget:new{
            text = self.icon or "",
            face = Font:getFace("cfont", self.icon_size),
            color = Blitbuffer.COLOR_BLACK,
        }
    end

    -- Création du cercle (le widget visuel)
    self.circle = FrameContainer:new{
        width = self.size,
        height = self.size,
        radius = self.radius,
        bordersize = self.bordersize,
        background = self.is_active and self.bg_active or self.bg_inactive,
        padding = 0,
        CenterContainer:new{
            dimen = Geom:new{
                w = self.size - (self.bordersize * 2),
                h = self.size - (self.bordersize * 2),
            },
            content_widget
        }
    }

    self[1] = self.circle

    self.dimen = self:getSize()

    self.ges_events = {
        TapSelect = { GestureRange:new{ ges = "tap", range = self.dimen } },
        HoldSelect = { GestureRange:new{ ges = "hold", range = self.dimen } }
    }
end

-- Gestionnaire de clic
function CircleButton:onTapSelect()
    if self.callback then
        self.callback()
        return true
    end
    return false
end

-- Gestionnaire de maintien
function CircleButton:onHoldSelect()
    if self.hold_callback then
        self.hold_callback()
        return true
    end
    return false
end

-- Méthode pour changer l'état dynamiquement
function CircleButton:update_state(is_active)
    self.is_active = is_active
    self.circle.background = self.is_active and self.bg_active or self.bg_inactive
    UIManager:setDirty(self, "ui")
end

return CircleButton
