local function status(e) for n,v in pairs(defines.entity_status) do if e.status==v then return n end end end
script.on_init(function()
 local p=assert(prototypes.entity['void-steam-engine']);assert(p.type=='generator');local platform=game.forces.player.create_space_platform{name='Actual Void steam generator contract',planet='nauvis',starter_pack='space-platform-starter-pack'};platform.apply_starter_pack(true);local s=platform.surface;storage.surface=s;storage.units={};storage.samples={};local directions={}
 for i,d in ipairs({0,4,8,12}) do
  local pos={x=i*18,y=20};s.request_to_generate_chunks(pos,1);s.force_generate_chunk_requests();local tiles={};for x=-6,6 do for y=-6,6 do tiles[#tiles+1]={name='space-platform-foundation',position={pos.x+x,pos.y+y}} end end;s.set_tiles(tiles,true)
  local legal=s.can_place_entity{name=p.name,position=pos,direction=d,force='player'};assert(legal,'actual ordinary platform placement');local e=assert(s.create_entity{name=p.name,position=pos,direction=d,force='player'});local u={machine=e,pipes={}};local row={requested=d,placed=e.direction,position=e.position,ordinary_buildable=legal,ports={}}
  for box=1,e.fluids_count do for _,port in ipairs(e.get_fluid_box_pipe_connections(box)) do
   local t=port.target_position;local pt={x=math.floor(t.x)+.5,y=math.floor(t.y)+.5};assert(s.can_place_entity{name='pipe',position=pt,force='player'});local pipe=s.create_entity{name='pipe',position=pt,force='player'};local connected=e.get_fluid_box_pipe_connections(box)[1].target==pipe
   local dx,dy=pt.x-pos.x,pt.y-pos.y;local step=math.abs(dx)>math.abs(dy) and {x=dx<0 and -1 or 1,y=0} or {x=0,y=dy<0 and -1 or 1};local extra=s.create_entity{name='pipe',position={x=pt.x+step.x,y=pt.y+step.y},force='player'};assert(extra);u.pipes={pipe,extra};u.input=pipe
   pipe.set_fluid_segment_fluid(1,{name='steam',amount=200,temperature=165});row.ports[#row.ports+1]={box=box,flow=port.flow_direction,position=port.position,target_position=t,normal_grid_pipe=pt,grid_error={x=pt.x-t.x,y=pt.y-t.y},reported_connected=connected}
  end end
  local accumulator_position={x=pos.x+3,y=pos.y+3};assert(s.can_place_entity{name='accumulator',position=accumulator_position,force='player'});u.accumulator=s.create_entity{name='accumulator',position=accumulator_position,force='player'};assert(u.accumulator.energy==0,'fresh real accumulator empty');u.pole=s.create_entity{name='medium-electric-pole',position={x=pos.x+1.5,y=pos.y+2.5},force='player'};assert(u.pole)
  row.rotate_result=e.rotate();row.after_rotate=e.direction;for _=1,3 do e.rotate() end;assert(e.direction==row.placed);directions[#directions+1]=row;storage.units[#storage.units+1]=u
 end
 local recipe=prototypes.recipe[p.name];local unlocks={};for name,t in pairs(prototypes.technology) do for _,eff in ipairs(t.effects or {}) do if eff.type=='unlock-recipe' and eff.recipe==p.name then local prereq={};for n in pairs(t.prerequisites) do prereq[#prereq+1]=n end;unlocks[#unlocks+1]={name=name,prerequisites=prereq,ingredients=t.research_unit_ingredients,count=t.research_unit_count,ticks=t.research_unit_energy} end end end
 local report={entity={name=p.name,type=p.type,tile_width=p.tile_width,tile_height=p.tile_height,collision_box=p.collision_box,selection_box=p.selection_box,max_power_watts=p.get_max_energy_production()*60,maximum_temperature=p.maximum_temperature,effectivity=p.effectivity,fluid_usage_per_tick=p.get_fluid_usage_per_tick(),burns_fluid=p.burns_fluid,scale_fluid_usage=p.scale_fluid_usage,burner=not not p.burner_prototype,electric=not not p.electric_energy_source_prototype,circuit_wire_reach=p.get_max_circuit_wire_distance(),wire_reach=p.get_max_wire_distance(),surface_conditions=p.surface_conditions},item={name=p.name,place_result=prototypes.item[p.name].place_result.name},building_recipe={name=recipe.name,seconds=recipe.energy,categories=recipe.categories,ingredients=recipe.ingredients,products=recipe.products,enabled=game.forces.player.recipes[p.name].enabled},unlocks=unlocks,directions=directions,steam={heat_capacity=prototypes.fluid.steam.heat_capacity,default_temperature=prototypes.fluid.steam.default_temperature},surface={platform=true,gravity=s.get_property('gravity'),pressure=s.get_property('pressure')},fixture='Exactly200 steam165C seeded through two ordinary pipes; fresh empty native accumulator and normal medium pole are the only electrical load/network. Target energy is never assigned.'}
 helpers.write_file('void-steam-engine/contract.json',helpers.table_to_json(report),false);log('VOID_STEAM_NATIVE_CONTRACT_CAPTURED cases='..#directions)
end)
script.on_nth_tick(60,function(event)
 if event.tick>1200 then return end
 local rows={}
 for _,u in ipairs(storage.units) do
  local e=u.machine;local total=e.get_fluid_count('steam');local pipes={};for _,p in ipairs(u.pipes) do total=total+p.get_fluid_count('steam');pipes[#pipes+1]=p.get_fluid(1) or false end
  rows[#rows+1]={direction=e.direction,status=status(e),steam_remaining=total,steam_consumed=200-total,engine_fluid=e.get_fluid(1) or false,pipe_fluids=pipes,accumulator_joules=u.accumulator.energy,generator_buffer_joules=e.energy,generator_network=e.electric_network_id,accumulator_network=u.accumulator.electric_network_id}
 end
 storage.samples[#storage.samples+1]={tick=event.tick,rows=rows}
 if event.tick==1200 then helpers.write_file('void-steam-engine/operation.json',helpers.table_to_json{samples=storage.samples},false);log('VOID_STEAM_NATIVE_OBSERVATIONS_COMPLETE') end
end)
