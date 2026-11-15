-- Production-facing event adapter. No scenario creation, clearing or test items.
local M=require('decay')
local producers={['tp-mh7-review-crucible']=true}
local function register(event)
 local e=event.created_entity or event.entity or event.destination
 if e and e.valid and producers[e.name] then M.register_producer(e) end
end
local function census()
 for _,surface in pairs(game.surfaces) do
  for name in pairs(producers) do if prototypes.entity[name] then for _,e in pairs(surface.find_entities_filtered{name=name}) do M.register_producer(e) end end end
 end
end
script.on_init(census)
script.on_configuration_changed(census)
script.on_event(defines.events.on_built_entity,register)
script.on_event(defines.events.on_robot_built_entity,register)
script.on_event(defines.events.script_raised_built,register)
script.on_event(defines.events.script_raised_revive,register)
script.on_event(defines.events.on_entity_cloned,register)
script.on_event(defines.events.on_script_trigger_effect,M.on_script_trigger_effect)
script.on_event(defines.events.on_tick,M.on_tick)
script.on_event(defines.events.on_player_main_inventory_changed,M.on_player_inventory_changed)
script.on_event(defines.events.on_player_cursor_stack_changed,M.on_player_inventory_changed)
remote.add_interface('tp-mh7-pellet-decay',{
 register_producer=M.register_producer,
 register_inventory=M.register_inventory,
 initialize_stack=M.touch_stack,
 seal=M.seal,
 unseal=M.unseal,
})
