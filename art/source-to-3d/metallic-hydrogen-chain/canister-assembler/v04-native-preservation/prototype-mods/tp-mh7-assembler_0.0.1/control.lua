-- Production event adapter: no world creation, clearing, test stock or screenshots.
local A=require('assembler')
local function register(event)A.register(event.created_entity or event.entity or event.destination);A.invalidate(event) end
local function census()
 for _,surface in pairs(game.surfaces) do for _,e in pairs(surface.find_entities_filtered{name='tp-mh7-canister-assembler'}) do A.register(e) end end
end
script.on_init(census);script.on_configuration_changed(census)
script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity,defines.events.script_raised_built,defines.events.script_raised_revive,defines.events.on_entity_cloned},register)
script.on_event(defines.events.on_tick,A.on_tick)
script.on_event({defines.events.on_pre_player_mined_item,defines.events.on_robot_pre_mined,defines.events.on_entity_died,defines.events.script_raised_destroy},function(event)
 if event.entity and event.entity.valid and event.entity.name=='tp-mh7-canister-assembler' then A.release(event.entity) end;A.invalidate(event)
end)
script.on_event(defines.events.on_player_rotated_entity,A.invalidate)
remote.add_interface('tp-mh7-assembler',{register=A.register,inspect=A.inspect})
