local VerticalGroup   = require("ui/widget/verticalgroup")
local TextWidget      = require("ui/widget/textwidget")

local Font            = require("ui/font")

local SkimSection     = require("sections/skimsection")
local Utils           = require("common/utils")
local Translation     = require("i18n/translation")
local _               = Translation._

local Skim = {}

function Skim.build(ctx)

    local section = Utils.getSection(ctx.config, "skim")
    if not section or not section.enabled_r or not ctx.reader then return nil end

    local skimSection = SkimSection.build(ctx)

    local group = VerticalGroup:new{ align = "center", skimSection.widget }

    if section.show_title then
        local info_label = TextWidget:new{
            text = _("Skim") .. " :",
            face =  Font:getFace("cfont", ctx.theme.btn_font_size), bold = true,
            max_width = inner_width,
        }
        table.insert(group, 1, info_label)
    end

    return { widget = group , refs = skimSection.refs }
end

function Skim.getSettings(config, saveConfig, ctx)
    local section = Utils.getSection(config, "skim")
    if not section then return {} end

    return {
        {
            text = _("Enabled in reader"),
            checked_func = function() return section.enabled_r end,
            callback = function() section.enabled_r = not section.enabled_r; saveConfig() end
        },
        {
            text = _("Show title"),
            checked_func = function() return section.show_title end,
            callback = function()
                section.show_title = not section.show_title
                saveConfig()
            end
        }
    }
end

return Skim
