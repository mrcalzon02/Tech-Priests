script.on_init(function()
 local name='sterling-steam-catalyzer';local p=assert(prototypes.entity[name],'actual boiler absent');local platform=assert(game.forces.player.create_space_platform{name='Sterling actual placement and fluid proof',planet='nauvis',starter_pack='space-platform-starter-pack'});platform.apply_starter_pack(true);local s=platform.surface;storage.platform_surface=s;local directions={};storage.units={};storage.samples={}
 for i,d in ipairs({0,4,8,12}) do
  local pos={x=i*18+(p.tile_width%2)/2,y=20+(p.tile_height%2)/2};s.request_to_generate_chunks(pos,1);s.force_generate_chunk_requests();for _,e in pairs(s.find_entities_filtered{area={{pos.x-5,pos.y-5},{pos.x+5,pos.y+5}}}) do e.destroy() end;local tiles={};for x=-5,5 do for y=-5,5 do tiles[#tiles+1]={name='space-platform-foundation',position={pos.x+x,pos.y+y}} end end;s.set_tiles(tiles,true)
  local legal=s.can_place_entity{name=name,position=pos,direction=d,force='player'};assert(legal,'ordinary platform placement rejected direction '..d);local e=s.create_entity{name=name,position=pos,direction=d,force='player'};assert(e);local u={machine=e,direction=d,pipes={}};local row={requested=d,placed=e.direction,position=e.position,ordinary_buildable=legal,ports={}}
  for box=1,e.fluids_count do
   for _,port in ipairs(e.get_fluid_box_pipe_connections(box)) do
    local t=port.target_position;local grid={x=math.floor(t.x)+.5,y=math.floor(t.y)+.5};local pipe=s.find_entity('pipe',grid)
    if not pipe and s.can_place_entity{name='pipe',position=grid,force='player'} then pipe=s.create_entity{name='pipe',position=grid,force='player'} end
    local connected=false;for _,actual in ipairs(e.get_fluid_box_pipe_connections(box)) do if actual.target==pipe and pipe then connected=true end end
    u[port.flow_direction]=pipe;u.pipes[#u.pipes+1]=pipe
    row.ports[#row.ports+1]={box=box,flow=port.flow_direction,position=port.position,target_position=t,ordinary_grid_pipe=grid,grid_error={x=grid.x-t.x,y=grid.y-t.y},normal_grid_pipe_connected=connected}
   end
  end
  row.rotate_result=e.rotate();row.after_rotate=e.direction;directions[#directions+1]=row
  for _=1,3 do e.rotate() end;assert(e.direction==d)
  for _,flow in ipairs({'input','output'}) do local pp=u[flow].position;local dx,dy=pp.x-e.position.x,pp.y-e.position.y;local step=math.abs(dx)>math.abs(dy) and {x=dx<0 and -1 or 1,y=0} or {x=0,y=dy<0 and -1 or 1};local ext=s.create_entity{name='pipe',position={x=pp.x+step.x,y=pp.y+step.y},force='player'};assert(ext);u.pipes[#u.pipes+1]=ext end
  assert(u.input.get_fluid_segment_capacity(1)==200);u.input.set_fluid_segment_fluid(1,{name='water',amount=200,temperature=15});assert(e.get_fuel_inventory().insert{name='coal',count=20}==20);storage.units[#storage.units+1]=u
 end
 local b=assert(prototypes.recipe[name]);local unlocks={};for n,t in pairs(prototypes.technology) do for _,eff in ipairs(t.effects or {}) do if eff.type=='unlock-recipe' and eff.recipe==name then unlocks[#unlocks+1]={name=n,ingredients=t.research_unit_ingredients,count=t.research_unit_count,time=t.research_unit_energy} end end end
 local report={surface={name=s.name,platform=not not s.platform,gravity=s.get_property('gravity'),pressure=s.get_property('pressure')},entity={name=name,type=p.type,tile_width=p.tile_width,tile_height=p.tile_height,surface_conditions=p.surface_conditions,tile_buildability_rules=p.tile_buildability_rules,collision_box=p.collision_box,selection_box=p.selection_box,burner=not not p.burner_prototype,electric=not not p.electric_energy_source_prototype,max_energy_usage_per_tick=p.get_max_energy_usage(),target_temperature=p.target_temperature,burner_details=p.burner_prototype and {effectivity=p.burner_prototype.effectivity,fuel_categories=p.burner_prototype.fuel_categories,fuel_inventory_size=p.burner_prototype.fuel_inventory_size} or false},item={name=name,place_result=prototypes.item[name].place_result.name},building_recipe={name=b.name,categories=b.categories,ingredients=b.ingredients,products=b.products,energy=b.energy,enabled=game.forces.player.recipes[name].enabled},unlocks=unlocks,directions=directions,processing='Native boiler fluid conversion, not an assembler recipe category',water={default_temperature=prototypes.fluid.water.default_temperature,heat_capacity=prototypes.fluid.water.heat_capacity},steam={default_temperature=prototypes.fluid.steam.default_temperature,heat_capacity=prototypes.fluid.steam.heat_capacity}}
 helpers.write_file('tp-sterling-contract/contract.json',helpers.table_to_json(report),false);log('TP_STERLING_NATIVE_CONTRACT_CAPTURED directions='..#directions)
end)

script.on_nth_tick(600,function(event)
 local rows={}
 for _,u in ipairs(storage.units) do
  local e=u.machine;local water=e.get_fluid_count('water');local steam=e.get_fluid_count('steam')
  for _,pipe in ipairs(u.pipes) do water=water+pipe.get_fluid_count('water');steam=steam+pipe.get_fluid_count('steam') end
  local available=e.get_fuel_inventory().get_item_count('coal')*prototypes.item.coal.fuel_value+e.burner.remaining_burning_fuel
  rows[#rows+1]={direction=e.direction,status=e.status,status_name=(function()for n,v in pairs(defines.entity_status)do if v==e.status then return n end end end)(),disabled=e.disabled_by_script,water=water,steam=steam,coal_available_energy=available,fuel_used=20*prototypes.item.coal.fuel_value-available,boiler_energy_buffer=e.energy,fluid_states=(function()local d={};for box=1,e.fluids_count do d[#d+1]=e.get_fluid(box) or false end;return d end)()}
 end
 storage.samples[#storage.samples+1]={tick=event.tick,rows=rows}
 if event.tick==7200 then
  helpers.write_file('tp-sterling-contract/actual-operation-observations.json',helpers.table_to_json{samples=storage.samples},false)
  for _,row in ipairs(rows) do assert(row.steam>100,'ordinary-grid native flow absent');assert(math.abs(row.water+row.steam/(prototypes.fluid.water.heat_capacity/prototypes.fluid.steam.heat_capacity)-200)<.01,'actual thermal fluid ratio not conserved');assert(row.status==defines.entity_status.full_output,'natural output capacity not reached');assert(row.fuel_used>0,'real chemical fuel not consumed') end
  helpers.write_file('tp-sterling-contract/actual-operation.json',helpers.table_to_json{passed=true,samples=storage.samples,scope='200 water at15C supplied through two ordinary pipes and coal20. Native600kW boiler produces400 steam165C from40 water, then naturally blocks on full200-machine+200-pipe output storage. Water/steam heat-capacity ratio10 is native. Real space-platform foundation with ordinary can_place_entity PASS in four directions. Controlled port-position repair only; no rate/power/recipe/footprint overrides.'},false);log('TP_STERLING_ACTUAL_BOILER_OPERATION_PASS directions=4')
 end
end)
