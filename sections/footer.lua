local BD          = require("ui/bidi")
local ConfirmBox  = require("ui/widget/confirmbox")
local UIManager   = require("ui/uimanager")
local SortWidget  = require("ui/widget/sortwidget")

local ActionDefs   = require("action_defs")
local ActionManage = require("action_manage")
local Config       = require("config")
local Utils        = require("common/utils")
local _            = require("common/i18n").gettext

local Footer = {}

local SECTION = "footer"
-- ============================================================
-- Footer Builder
-- ============================================================
local function default_footer(ctx)
    local default_footer = ctx.datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock"))
    if ctx.device:hasBattery() then
        local batt_lvl = ctx.powerd:getCapacity()
        local batt_symbol = ctx.powerd:getBatterySymbol(ctx.powerd:isCharged(), ctx.powerd:isCharging(), batt_lvl)
        default_footer = BD.wrap(default_footer) .. " " .. BD.wrap("⌁") .. BD.wrap(batt_symbol) ..  BD.wrap(batt_lvl .. "%")
        if ctx.device:hasAuxBattery() and ctx.powerd:isAuxBatteryConnected() then
            local aux_batt_lvl = ctx.powerd:getAuxCapacity()
            local aux_batt_symbol = ctx.powerd:getBatterySymbol(ctx.powerd:isAuxCharged(), ctx.powerd:isAuxCharging(), aux_batt_lvl)
            default_footer = default_footer .. " " .. BD.wrap("+") .. BD.wrap(aux_batt_symbol) ..  BD.wrap(aux_batt_lvl .. "%")
        end
    end
    return default_footer
end

function Footer.build(ctx)
    local config       = ctx.config
    local filemanager  = ctx.filemanager
    local reader       = ctx.reader
    local section      = Utils.getSection(config, SECTION)

    if not section then return nil end

    if filemanager and not section.enabled_f then return default_footer(ctx) end

    if reader and not section.enabled_r then return default_footer(ctx) end

    section.items = section.items or {}

    -- actions system and custom
    local action_defs = ActionDefs.getMerged(config.custom_actions)
    local sep = section.separator or ""

    local parts = {}
    for index = 1, #section.items do
        local id = section.items[index]
        local item_def = action_defs[id]

        if item_def and (not item_def.visible_func or item_def.visible_func(ctx)) then
            local icon = item_def.icon_func and item_def.icon_func(ctx) or (item_def.icon or "")
            local val = item_def.label_func and item_def.label_func(ctx) or (item_def.label or "")
            local entry = BD.wrap(icon) .. " " .. BD.wrap(val)
            table.insert(parts, entry)
        end
    end
    return table.concat(parts, sep)
end

-- ============================================================
-- Settings Menu Builder
-- ============================================================
function Footer.getSettings(ctx)
    -- ctx import
    local config  = ctx.config
    local section = Utils.getSection(config, SECTION)

    if not section then return {} end

    -- separator
    local sep_options = {" • ", " | ", " - ", " "}
    local sep_items = {}
    for _, s in ipairs(sep_options) do
        table.insert(sep_items, {
            text = "'" .. s .. "'",
            checked_func = function() return (section.separator or " • ") == s end,
            callback = function() section.separator = s; Config.save(config); return true end
        })
    end

    return {
        {
            text = _("Enabled in filemanager"),
            checked_func = function() return section.enabled_f end,
            callback = function() section.enabled_f = not section.enabled_f; Config.save(config) end
        },
        {
            text = _("Enabled in reader"),
            checked_func = function() return section.enabled_r end,
            callback = function() section.enabled_r = not section.enabled_r; Config.save(config) end
        },

        {
            text_func = function()
                local sep = section.separator or ""
                return _("Separator") .. " (" .. sep .. ")"
            end,
            sub_item_table = sep_items,
        },
        {
            text_func = function()
                local count = #(section.items or {})
                return _("Manage actions") .. " (" .. count .. ")\xE2\x80\xA6"
            end,
            keep_menu_open = true,
            callback = function(touch_menu)
                ctx.touch_menu = touch_menu
                ActionManage:showActionManageMenu(ctx, SECTION)
            end,
            separator = true
        },
        {
            text = _("Reset to defaults"),
            keep_menu_open = true,
            callback = function(touch_menu)
                UIManager:show(ConfirmBox:new{
                    text = _("Are you sure you want to reset to defaults ?"),
                    ok_text = _("Reset"),
                    ok_callback = function()
                        local defaults = Config.DEFAULTS.sections[SECTION]
                        Utils.resetSectionToDefaults(section, defaults)
                        Config.save(config)
                        if touch_menu and touch_menu.updateItems then touch_menu:updateItems() end
                    end
                })
            end
        }
    }
end

return Footer
