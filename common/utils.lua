local M = {}

--- Find a section by its ID within the config table.
--- @param config table  The configuration table containing sections.
--- @param id     string  The section ID to look for.
--- @return        table|nil
function M.getSection(config, id)
    if not config or type(config.sections) ~= "table" then
        return nil
    end
    local section = config.sections[id]
    if section then
        section.items = section.items or {}
    end
    return section
end

--- Reset a section to defaults.
--- @param section  table  The section current settings.
--- @param defaults table  The section defaults settings.
function M.resetSectionToDefaults(section, defaults)
    if not section or not defaults then return end
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            section[k] = {}
            for key, val in pairs(v) do
                section[k][key] = val
            end
        else
            section[k] = v
        end
    end
end

--- Verify plugin in present in active instance.
--- @param slot      string  plugin name
--- @return          boolean
function M.hasPlugin(slot)
    local ok_f, FM = pcall(require, "apps/filemanager/filemanager")
    local ok_r, RU = pcall(require, "apps/reader/readerui")
    local ui = (ok_f and FM.instance) or (ok_r and RU.instance)
    return ui == nil or ui[slot] ~= nil
end

return M
