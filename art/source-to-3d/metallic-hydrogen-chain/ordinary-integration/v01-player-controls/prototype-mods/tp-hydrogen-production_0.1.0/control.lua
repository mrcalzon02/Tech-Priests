-- Production event adapter: no world creation, clearing, test stock or screenshots.
local A=require('assembler');local U=require('player-controls')
local function configure(e)
 if e and e.valid and e.name=='tp-mh7-review-fabricator' and not e.get_recipe() then e.set_recipe('tp-mh7-review-hydroform') end
 A.register(e)
end
local function register(event)configure(event.created_entity or event.entity or event.destination);A.invalidate(event) end
local function census()
 for _,surface in pairs(game.surfaces) do for _,e in pairs(surface.find_entities_filtered{name={'tp-mh7-canister-assembler','tp-mh7-review-fabricator'}}) do configure(e) end end
end
script.on_init(census);script.on_configuration_changed(census)
script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity,defines.events.script_raised_built,defines.events.script_raised_revive,defines.events.on_entity_cloned},register)
script.on_event(defines.events.on_tick,function(event)A.on_tick(event);U.on_tick(event) end)
script.on_event({defines.events.on_pre_player_mined_item,defines.events.on_robot_pre_mined,defines.events.on_entity_died,defines.events.script_raised_destroy},function(event)
 if event.entity and event.entity.valid and event.entity.name=='tp-mh7-canister-assembler' then A.release(event.entity) end;A.invalidate(event)
end)
script.on_event(defines.events.on_player_rotated_entity,A.invalidate)
remote.add_interface('tp-mh7-assembler',{register=A.register,inspect=A.inspect})

script.on_event(defines.events.on_gui_opened,U.on_opened)
script.on_event(defines.events.on_gui_closed,U.on_closed)
script.on_event(defines.events.on_gui_click,U.on_click)
remote.add_interface('tp-hydrogen-player-controls',{open=U.open,inspect=U.inspect,interact=U.on_click})
