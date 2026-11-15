-- Production-facing event adapter. No scenario creation, clearing or test items.
local M=require('decay')
local F=require('forge')
local producers={['tp-mh7-review-crucible']=true}
local function register(event)
 local e=event.created_entity or event.entity or event.destination
 if e and e.valid and producers[e.name] then M.register_producer(e) end
 if e and e.valid and e.name=='tp-mh7-review-forge' then F.register(e) end
 F.invalidate_intakes(event)
end
local function census()
 for _,surface in pairs(game.surfaces) do
  for name in pairs(producers) do if prototypes.entity[name] then for _,e in pairs(surface.find_entities_filtered{name=name}) do M.register_producer(e) end end end
  if prototypes.entity['tp-mh7-review-forge'] then for _,e in pairs(surface.find_entities_filtered{name='tp-mh7-review-forge'}) do F.register(e) end end
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
script.on_event(defines.events.on_tick,function(event)M.on_tick(event);F.on_tick(event) end)
script.on_event({defines.events.on_pre_player_mined_item,defines.events.on_robot_pre_mined,defines.events.on_entity_died,defines.events.script_raised_destroy},function(event)
 if event.entity and event.entity.valid and event.entity.name=='tp-mh7-review-forge' then F.release(event.entity) end
 F.invalidate_intakes(event)
end)
script.on_event(defines.events.on_player_rotated_entity,F.invalidate_intakes)
script.on_event(defines.events.on_player_main_inventory_changed,M.on_player_inventory_changed)
script.on_event(defines.events.on_player_cursor_stack_changed,M.on_player_inventory_changed)
remote.add_interface('tp-mh7-pellet-decay',{
 register_producer=M.register_producer,
 register_inventory=M.register_inventory,
 initialize_stack=M.touch_stack,
 seal=M.seal,
 unseal=M.unseal,
 form=M.form,
 register_forge=F.register,
 inspect_forge=F.inspect,
 forge_player_view=F.player_view,
 forge_player_transfer=F.player_transfer,
})
