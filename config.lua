local Config = {}

local DEFAULTS = {
    sections = {
        actions = {
            enabled = true,
            show_label = true,
            items = { "wifi", "night", "light", "rotate", "lock", "usb", "restart" }
        },
        frontlight = {
            enabled = true
        },
        warmth = {
            enabled = true
        },
        shortcuts = {
            enabled = true,
            show_label = true,
            max_cols = 3,
            items = { "history", "collections", "statistics", "search", "dictionary", "cloud" }
        },
        info = {
            enabled = true,
            show_thumbnail = true
        },
        skim = {
            enabled = true
        },
    },

    open_on_start = true,
    add_exit_tab = true,
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

    for id, defaults in pairs(DEFAULTS.sections) do
        if not cfg.sections[id] then
            cfg.sections[id] = {}
        end

        copyMissing(cfg.sections[id], defaults)
        cfg.sections[id].label = nil
    end

    if cfg.open_on_start == nil then
        cfg.open_on_start = DEFAULTS.open_on_start
    end

    if cfg.add_exit_tab == nil then
        cfg.add_exit_tab = DEFAULTS.add_exit_tab
    end

    return cfg
end

function Config.save(cfg)
    G_reader_settings:saveSetting("quick_menu_panel", cfg)
end

return Config
