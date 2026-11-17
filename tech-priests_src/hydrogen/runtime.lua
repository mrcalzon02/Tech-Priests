local decay = require("hydrogen.decay")
local forge = require("hydrogen.forge")
local assembler = require("hydrogen.assembler")
local gui = require("hydrogen.player-controls")
local registry = require("scripts.core.runtime_event_registry")

-- Already-installed prototype add-ons retain ownership of their private jobs
-- and LuaInventories. New installs use the exact same IDs and interfaces here.
local own_decay = not script.active_mods["tp-mh7-pellet-decay"]
local own_machines = not script.active_mods["tp-hydrogen-production"]

if own_decay then
  remote.add_interface("tp-mh7-pellet-decay", {
    register_producer = decay.register_producer,
    register_inventory = decay.register_inventory,
    initialize_stack = decay.touch_stack,
    seal = decay.seal,
    unseal = decay.unseal,
    form = decay.form,
    register_forge = forge.register,
    inspect_forge = forge.inspect,
    forge_player_view = forge.player_view,
    forge_player_transfer = forge.player_transfer,
  })
end

if own_machines then
  remote.add_interface("tp-mh7-assembler", {register = assembler.register, inspect = assembler.inspect})
  remote.add_interface("tp-hydrogen-player-controls", {open = gui.open, inspect = gui.inspect, interact = gui.on_click})
end

if not own_decay and not own_machines then return end

local crucible_name = "tp-mh7-review-crucible"
local forge_name = "tp-mh7-review-forge"
local fabricator_name = "tp-mh7-review-fabricator"
local assembler_name = "tp-mh7-canister-assembler"

local function configure(entity)
  if not (entity and entity.valid) then return end
  if own_decay then
    if entity.name == crucible_name then decay.register_producer(entity) end
    if entity.name == forge_name then forge.register(entity) end
  end
  if own_machines then
    if entity.name == fabricator_name and not entity.get_recipe() then
      entity.set_recipe("tp-mh7-review-hydroform")
    elseif entity.name == assembler_name then
      assembler.register(entity)
    end
  end
end

-- Factorio transfers private script inventories and GUI ownership together
-- with the old mod's storage. Restore the original jobs before discovering
-- entities, so registering the same forge cannot create empty replacement stock.
local function adopt_storage(previous_mod, fields)
  local migrated = storage._migrated
  local previous = migrated and migrated[previous_mod]
  if not previous then return end
  for _, field in ipairs(fields) do
    if previous[field] then
      storage[field] = previous[field]
      previous[field] = nil
    end
  end
  if not next(previous) then migrated[previous_mod] = nil end
end

local function census()
  if own_decay then
    adopt_storage("tp-mh7-pellet-decay", {"mh7_pellet_decay", "mh7_forges"})
  end
  if own_machines then
    adopt_storage("tp-hydrogen-production", {"mh7_assemblers", "hydrogen_player_controls"})
  end
  for _, surface in pairs(game.surfaces) do
    local machines = surface.find_entities_filtered{name = {crucible_name, forge_name, assembler_name, fabricator_name}}
    for _, entity in pairs(machines) do configure(entity) end
  end
end

local function invalidate(event)
  if own_decay and storage.mh7_forges then forge.invalidate_intakes(event) end
  if own_machines and storage.mh7_assemblers then assembler.invalidate(event) end
end

local function built(event)
  configure(event.destination or event.entity or event.created_entity)
  invalidate(event)
end

local function removed(event)
  local entity = event.entity
  if entity and entity.valid then
    if own_decay and entity.name == forge_name then forge.release(entity) end
    if own_machines and entity.name == assembler_name then assembler.release(entity) end
  end
  invalidate(event)
end

local function tick(event)
  if own_decay then
    if storage.mh7_pellet_decay then decay.on_tick(event) end
    if storage.mh7_forges then forge.on_tick(event) end
  end
  if own_machines then
    if storage.mh7_assemblers then assembler.on_tick(event) end
    if storage.hydrogen_player_controls then gui.on_tick(event) end
  end
end

local function options(route)
  return {owner = "metallicized-hydrogen", route = route, category = "production", priority = 100}
end

local function on(ids, callback, route)
  assert(registry.on_event(ids, callback, nil, options(route)), "Cannot register hydrogen event " .. route)
end

local events = defines.events
registry.on_init(census, options("initialize"))
registry.on_configuration_changed(census, options("update"))
on({events.on_built_entity, events.on_robot_built_entity, events.script_raised_built,
    events.script_raised_revive, events.on_entity_cloned}, built, "build")
on({events.on_pre_player_mined_item, events.on_robot_pre_mined,
    events.on_entity_died, events.script_raised_destroy}, removed, "remove")
on(events.on_player_rotated_entity, invalidate, "rotate")
on(events.on_tick, tick, "produce")
if own_decay then
  on(events.on_script_trigger_effect, decay.on_script_trigger_effect, "pellet-decay")
  on({events.on_player_main_inventory_changed, events.on_player_cursor_stack_changed},
     decay.on_player_inventory_changed, "player-stock")
end
if own_machines then
  on(events.on_gui_opened, gui.on_opened, "open")
  on(events.on_gui_closed, gui.on_closed, "close")
  on(events.on_gui_click, gui.on_click, "click")
end
