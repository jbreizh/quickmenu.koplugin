local Config = {}

Config.DEFAULTS = {
    sections = {
        actions = {
            enabled_f = true,
            enabled_r = true,
            collapse = false,
            show_title = true,
            show_label = true,
            fit_ctrl = true,
            justified_ctrl = true,
            items = { "wifi", "night", "light", "rotate", "lock", "usb", "power" }
        },
        frontlight = {
            enabled_f = true,
            enabled_r = true,
            collapse = false,
            show_title = true,
            use_zenslider = false,
        },
        shortcuts = {
            enabled_f = true,
            enabled_r = false,
            collapse = false,
            show_title = true,
            show_label = true,
            max_cols = 3,
            items = { "history", "collections", "statistics", "search", "dictionary", "cloud" }
        },
        info = {
            enabled_r = true,
            show_title = true,
            collapse = false,
            show_thumbnail = true,
            show_skim = true
        },
        footer = {
            enabled_f = true,
            enabled_r = true,
            items = {"memusedp", "storageusedp", "time", "battery", "auxbattery"}
        },
    },
    frontlight_presets = {

    },
    custom_actions = {

    },
    style = {
        padding = 10,
        h_gap = 4,
        v_gap = 4,
        action_size = 64,
        action_radius = 32,
        btn_width = 50,
        btn_radius = 7,
        btn_bordersize = 1.5,
        btn_font_size = 16,
        slider_ticks_width = 1,
    },
    open_on_start = true,
    add_exit_tab = true,
    add_quickmenu_tab = true,
}

local function copyMissing(dst, defaults)
    for key, value in pairs(defaults) do
        if dst[key] == nil then
            if type(value) == "table" then
                local copy = {}
                for k, v in pairs(value) do
                    copy[k] = v
                end
                dst[key] = copy
            else
                dst[key] = value
            end
        end
    end
end

function Config.load()
    local cfg = G_reader_settings:readSetting("quick_menu_panel", {})
    cfg.sections = cfg.sections or {}

    -- sections level 1
    for section_id, section_data in pairs(cfg.sections) do
        if not Config.DEFAULTS.sections[section_id] then cfg.sections[section_id] = nil end
    end

    -- sections level 2
    for section_id, defaults in pairs(Config.DEFAULTS.sections) do
        cfg.sections[section_id] = cfg.sections[section_id] or {}
        for param_key, param_value in pairs(cfg.sections[section_id]) do
            if defaults[param_key] == nil then cfg.sections[section_id][param_key] = nil end
        end
        copyMissing(cfg.sections[section_id], defaults)
    end

    -- global
    for key, value in pairs(cfg) do
        if key ~= "sections" then
            if Config.DEFAULTS[key] == nil then cfg[key] = nil end
        end
    end

    if cfg.open_on_start == nil then cfg.open_on_start = Config.DEFAULTS.open_on_start end
    if cfg.add_exit_tab == nil then cfg.add_exit_tab = Config.DEFAULTS.add_exit_tab end
    if cfg.add_quickmenu_tab == nil then cfg.add_quickmenu_tab = Config.DEFAULTS.add_quickmenu_tab end
    cfg.style = cfg.style or {}
    for key, value in pairs(Config.DEFAULTS.style) do
        if cfg.style[key] == nil then cfg.style[key] = value end
    end

    cfg.frontlight_presets = cfg.frontlight_presets or {}
    cfg.custom_actions = cfg.custom_actions or {}

--     -- Dans Config.load()
--     local ActionDefs = require("action_defs")
--
--     -- 1. Récupération des IDs custom valides
--     local valid_custom_ids = {}
--     for _, action in ipairs(cfg.custom_actions) do
--         if action.id then valid_custom_ids[action.id] = true end
--     end
--
--     -- 2. Nettoyage croisé dans les sections
--     if cfg.sections then
--         for _, section_data in pairs(cfg.sections) do
--             if section_data.items and type(section_data.items) == "table" then
--                 for i = #section_data.items, 1, -1 do
--                     local item_id = section_data.items[i]
--
--                     -- On vérifie : Est-ce une action système OU une action custom valide ?
--                     local is_system = ActionDefs.getMerged()[item_id] ~= nil
--                     local is_custom = valid_custom_ids[item_id] ~= nil
--
--                     if not is_system and not is_custom then
--                         table.remove(section_data.items, i)
--                     end
--                 end
--             end
--         end
--     end

    return cfg
end

function Config.save(cfg)
    G_reader_settings:saveSetting("quick_menu_panel", cfg)
end

function Config.saveAndRefresh(ctx)
    -- save
    local config = ctx.config
    if config then Config.save(config) end
    -- refresh
    local touch_menu = ctx.touch_menu
    if touch_menu and touch_menu.updateItems then touch_menu:updateItems() end
end

return Config
