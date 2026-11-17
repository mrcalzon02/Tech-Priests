-- Read the actual current Entropic generator before authoring any replacement.
local function check(x,m)if not x then error('ENTROPIC_CONTRACT: '..m)end end
local function optional(fn)local ok,v=pcall(fn);return ok and v or{unavailable=tostring(v)}end
local function ground(s,p,tile)
 s.request_to_generate_chunks(p,1);s.force_generate_chunk_requests();local t={};for x=-7,7 do for y=-7,7 do t[#t+1]={name=tile,position={p.x+x,p.y+y}}end end;s.set_tiles(t,true)
end
local function snap(u)
 local e=u.machine;local b=e.burner
 return{requested_direction=u.requested,direction=e.direction,energy=e.energy,fuel=e.get_fuel_inventory().get_contents(),currently_burning=b.currently_burning or false,remaining_fuel=b.remaining_burning_fuel,accumulator_joules=u.accumulator.energy,status=e.status,generator_network=e.electric_network_id,accumulator_network=u.accumulator.electric_network_id}
end
script.on_init(function()
 if remote.interfaces.freeplay and remote.interfaces.freeplay.set_skip_intro then remote.call('freeplay','set_skip_intro',true)end
 local name='entropic-extractor';local p=assert(prototypes.entity[name]);check(p.type=='burner-generator','actual burner generator')
 local f=game.forces.player;local recipe=prototypes.recipe[name];local locked=not f.recipes[name].enabled;f.technologies['blackstone-citadel-manufacture'].researched=true;check(f.recipes[name].enabled,'actual unlock')
 storage.units={};local directions={};local accepts={};local wires={};local fuel_items={'blackstone-fragment','blackstone-asteroid-chunk','blackstone-slab','coal','wood','solid-fuel','nuclear-fuel'}
 for _,d in ipairs({0,4,8,12})do
  local platform=f.create_space_platform{name='Entropic actual native contract '..d,planet='nauvis',starter_pack='space-platform-starter-pack'};platform.apply_starter_pack(true);local s=platform.surface;local pos={x=20.5,y=20.5};ground(s,pos,'space-platform-foundation')
  check(s.can_place_entity{name=name,position=pos,direction=d,force='player'},'normal platform placement');local e=assert(s.create_entity{name=name,position=pos,direction=d,force='player'});local row={requested=d,placed=e.direction,rotation_results={},directions_after_rotation={}}
  for _=1,4 do row.rotation_results[#row.rotation_results+1]=e.rotate();row.directions_after_rotation[#row.directions_after_rotation+1]=e.direction end;directions[#directions+1]=row
  local inv=e.get_fuel_inventory();check(inv and #inv==1 and e.burner,'real single fuel inventory')
  if d==0 then
   for _,fuel in ipairs(fuel_items)do
    local n=inv.insert{name=fuel,count=1};accepts[fuel]={inserted=n,fuel_value=prototypes.item[fuel].fuel_value,fuel_categories=optional(function()return prototypes.item[fuel].fuel_categories end)}
    if n>0 then check(inv.remove{name=fuel,count=n}==n,'restore empty native fuel slot')end
   end
   for id in pairs(e.get_wire_connectors(true)or{})do wires[#wires+1]=id end
  end
  local pole=s.create_entity{name='medium-electric-pole',position={22.5,22.5},force='player'};local a=s.create_entity{name='accumulator',position={24,20},force='player'};check(pole and a,'normal grid and accumulator')
  storage.units[#storage.units+1]={machine=e,accumulator=a,surface=s,requested=d,position=pos}
 end
 check(accepts['blackstone-fragment'].inserted==1,'actual refined fragment accepted')
 for _,n in ipairs({'blackstone-asteroid-chunk','blackstone-slab','coal','wood','solid-fuel','nuclear-fuel'})do check(accepts[n].inserted==0,'other fuel rejected '..n)end
 local planet=game.surfaces[1];ground(planet,{x=20.5,y=20.5},'grass-1')
 local t=prototypes.technology['blackstone-citadel-manufacture'];local prerequisites={};for n in pairs(t.prerequisites)do prerequisites[#prerequisites+1]=n end
 local report={entity={name=p.name,type=p.type,footprint={p.tile_width,p.tile_height},collision_box=p.collision_box,selection_box=p.selection_box,max_power_watts=p.get_max_energy_production()*60,burner=not not p.burner_prototype,burner_categories=optional(function()return p.burner_prototype.fuel_categories end),electric_buffer_joules=optional(function()return p.electric_energy_source_prototype.buffer_capacity end),native_wire_connector_ids=wires,circuit_reach=p.get_max_circuit_wire_distance(),supported_wire_reach=p.get_max_wire_distance(),fluid_boxes=storage.units[1].machine.fluids_count,fuel_inventory_slots=#storage.units[1].machine.get_fuel_inventory(),burnt_inventory=optional(function()local v=storage.units[1].machine.get_burnt_result_inventory();return v and #v or 0 end),surface_conditions=p.surface_conditions},item={name=name,place_result=prototypes.item[name].place_result.name,stack_size=prototypes.item[name].stack_size,weight=prototypes.item[name].weight},building_recipe={name=name,seconds=recipe.energy,categories=recipe.categories,ingredients=recipe.ingredients,products=recipe.products,initially_locked=locked,unlocked_after_actual_technology=f.recipes[name].enabled},technology={name=t.name,prerequisites=prerequisites,count=t.research_unit_count,ticks=t.research_unit_energy,ingredients=t.research_unit_ingredients},processing_recipes={},processing_scope='Native burner-generator produces electricity; the building recipe is manufactured by Citadel. No crafting operation is invented inside this generator.',fuel_acceptance=accepts,directions=directions,normal_platform_placement=true,normal_nauvis_placement=planet.can_place_entity{name=name,position={20.5,20.5},force='player'},target_energy_assignments=false,source_comment_correction='The actual current fuel is processed blackstone-fragment1PJ. Raw asteroid chunks are rejected despite the older comment in the entity definition.'}
 helpers.write_file('entropic-contract/contract.json',helpers.table_to_json(report),false);log('ENTROPIC_ACTUAL_CONTRACT_CAPTURED')
end)
script.on_event(defines.events.on_tick,function(ev)
 if ev.tick==120 then
  storage.empty={};for _,u in ipairs(storage.units)do check(not u.machine.burner.currently_burning and u.accumulator.energy==0,'empty cold generator idle');storage.empty[#storage.empty+1]=snap(u);check(u.machine.get_fuel_inventory().insert{name='blackstone-fragment',count=1}==1,'real refined blackstone fuel inserted')end
 elseif ev.tick==600 then
  local rows={};for _,u in ipairs(storage.units)do rows[#rows+1]=snap(u)end;helpers.write_file('entropic-contract/observed-power.json',helpers.table_to_json{rows=rows},false)
  for _,u in ipairs(storage.units)do check(u.machine.burner.remaining_burning_fuel>0,'actual fuel energy loaded');check(u.accumulator.energy>0,'real native electricity charges ordinary accumulator')end
  helpers.write_file('entropic-contract/operation.json',helpers.table_to_json{passed=true,empty_idle=storage.empty,real_fragment_power=rows,no_target_or_load_energy_assignments=true},false);log('ENTROPIC_FRAGMENT_NATIVE_POWER_PASS')
 end
end)
