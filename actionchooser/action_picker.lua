--[[
Standalone Dispatcher action picker. Calls Dispatcher:addSubMenu into a
holder table and hosts the generated items via MenuHost. As soon as the
user's interaction leaves exactly one action chosen, calls on_pick with
(action_table, display_name) and closes. Single-decision model: first
clean pick wins; toggling something off just resets and waits.
]]
local MenuHost = require("actionchooser/menu_host")
local logger   = require("logger")
local _        = require("common/i18n").gettext

local ActionPicker = {}

local function chosenKey(pick)
    local found
    for k, v in pairs(pick) do
        if k ~= "settings" and v ~= nil then
            if found then return nil end -- more than one: not a clean pick
            found = k
        end
    end
    return found
end

-- opts: { on_pick = function(action_table, name) end }
function ActionPicker.show(opts)
    local ok, Dispatcher = pcall(require, "dispatcher")
    if not ok then
        logger.warn("[quickmenu] action_chooser : dispatcher unavailable", Dispatcher)
        return
    end
    local holder = { pick = {} }
    local caller = {}
    local items  = {}
    Dispatcher:addSubMenu(caller, items, holder, "pick")

    local host
    local done = false
    local function maybeFinish()
        if done or not caller.updated then return end
        local k = chosenKey(holder.pick)
        if not k then
            caller.updated = nil
            return
        end
        done = true
        local action = { [k] = holder.pick[k] }
        local name = Dispatcher:getNameFromItem(k, holder.pick, true) or k
        MenuHost.close(host)
        opts.on_pick(action, name)
    end
    host = MenuHost.show{
        title = _("Choose an action"),
        item_table = items,
        on_item_activated = maybeFinish,
    }
    -- Spike finding: value-typed actions (absolutenumber/incrementalnumber)
    -- commit asynchronously - the SpinWidget OK callback runs Dispatcher's
    -- setValue, which only calls touchmenu_instance:updateItems(); no menu
    -- row tap follows, so on_item_activated alone never sees those picks.
    -- Hook the pick-check onto the shim's updateItems as well; the `done`
    -- guard keeps on_pick single-fire when both paths run for one tap.
    local orig_updateItems = host._shim.updateItems
    host._shim.updateItems = function(...)
        orig_updateItems(...)
        maybeFinish()
    end
    return host
end

return ActionPicker
