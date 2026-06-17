local Config = {}

local DEFAULTS = {
    sections = {
        actions = {
            enabled_f = true,
            enabled_r = true,
            show_title = false,
            show_label = true,
            items = { "wifi", "night", "light", "rotate", "lock", "usb", "restart" }
        },
        frontlight = {
            enabled_f = true,
            enabled_r = true,
            show_title = true
        },
        warmth = {
            enabled_f = true,
            enabled_r = true,
            show_title = true
        },
        shortcuts = {
            enabled_f = true,
            enabled_r = false,
            show_title = true,
            show_label = true,
            max_cols = 3,
            items = { "history", "collections", "statistics", "search", "dictionary", "cloud" }
        },
        info = {
            enabled_r = true,
            show_title = true,
            show_thumbnail = true,
            show_skim = true
        },
        skim = {
            enabled_r = false,
            show_title = false
        },
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

    -- 1. Nettoyage du 1er niveau (les sections)
    -- On utilise 'section_id' et 'section_data' pour rendre la boucle explicite
    for section_id, section_data in pairs(cfg.sections) do
        if not DEFAULTS.sections[section_id] then
            cfg.sections[section_id] = nil
        end
    end

    -- 2. Nettoyage et Remplissage du 2ème niveau
    for section_id, defaults in pairs(DEFAULTS.sections) do
        cfg.sections[section_id] = cfg.sections[section_id] or {}

        -- Nettoyage des paramètres obsolètes dans cette section
        -- 'param_key' remplace l'itérateur anonyme
        for param_key, param_value in pairs(cfg.sections[section_id]) do
            if defaults[param_key] == nil then
                cfg.sections[section_id][param_key] = nil
            end
        end

        copyMissing(cfg.sections[section_id], defaults)
        cfg.sections[section_id].label = nil
    end

    -- 3. Initialisation des paramètres globaux
    if cfg.open_on_start == nil then cfg.open_on_start = DEFAULTS.open_on_start end
    if cfg.add_exit_tab == nil then cfg.add_exit_tab = DEFAULTS.add_exit_tab end

    return cfg
end

function Config.save(cfg)
    G_reader_settings:saveSetting("quick_menu_panel", cfg)
end

return Config
