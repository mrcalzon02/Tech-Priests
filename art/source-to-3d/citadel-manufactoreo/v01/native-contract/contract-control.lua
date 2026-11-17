-- Read actual final prototypes and run each supported process, before modeling.
local function check(x,m)if not x then error('CITADEL_CONTRACT: '..m)end end
local function status(e)for n,v in pairs(defines.entity_status)do if e.status==v then return n end end end
local function inventory(inv)local t={};if inv then for _,r in ipairs(inv.get_contents())do t[#t+1]=r end end;return t end
local function area(s,p,tile)
 s.request_to_generate_chunks(p,1);s.force_generate_chunk_requests();local t={};for x=-6,6 do for y=-6,6 do t[#t+1]={name=tile,position={p.x+x,p.y+y}}end end;s.set_tiles(t,true)
end
local function optional(fn)local ok,r=pcall(fn);return ok and r or {unavailable=tostring(r)}end
script.on_init(function()
 if remote.interfaces.freeplay and remote.interfaces.freeplay.set_skip_intro then remote.call('freeplay','set_skip_intro',true)end
 local name='citadel-manufactoreo';local p=prototypes.entity[name];check(p,'actual prototype')
 local force=game.forces.player;local processes={};local excluded_parameters={};local supported={}
 for category in pairs(p.crafting_categories)do supported[category]=true end
 for n,r in pairs(prototypes.recipe)do
  local accepts=false;for _,cat in pairs(r.categories)do if supported[cat]then accepts=true end end
  if accepts and r.parameter then excluded_parameters[#excluded_parameters+1]=n end
  if accepts and not r.parameter then processes[#processes+1]={name=n,seconds=r.energy,ingredients=r.ingredients,products=r.products,categories=r.categories,enabled_before=force.recipes[n].enabled}end
 end
 table.sort(processes,function(a,b)return a.name<b.name end);check(#processes>0,'actual process list')
 local unlocks={};for n,t in pairs(prototypes.technology)do local effects={};for _,effect in ipairs(t.effects or {})do if effect.type=='unlock-recipe'then
  local match=effect.recipe==name;for _,r in ipairs(processes)do if r.name==effect.recipe then match=true end end
  if match then effects[#effects+1]=effect end
 end end
 if #effects>0 then local prereq={};for n in pairs(t.prerequisites)do prereq[#prereq+1]=n end;unlocks[#unlocks+1]={name=n,prerequisites=prereq,ingredients=t.research_unit_ingredients,count=t.research_unit_count,ticks=t.research_unit_energy,effects=effects}end end
 local build=prototypes.recipe[name];local gated=not force.recipes[name].enabled;force.technologies['blackstone-citadel-manufacture'].researched=true
 check(force.recipes[name].enabled,'actual building unlock');for _,r in ipairs(processes)do r.enabled_after=force.recipes[r.name].enabled;check(r.enabled_after,'actual process unlock')end
 local platform=force.create_space_platform{name='Citadel current native contract',planet='nauvis',starter_pack='space-platform-starter-pack'};platform.apply_starter_pack(true);storage.surface=platform.surface;storage.units={};storage.samples={};local directions={};local s=storage.surface
 for j,d in ipairs({0,4,8,12})do
  for i,recipe in ipairs(processes)do
   local pos={x=20.5+i*18,y=20.5+j*18};area(s,pos,'space-platform-foundation')
   check(s.can_place_entity{name=name,position=pos,direction=d,force='player'},'ordinary platform build at half grid');local e=s.create_entity{name=name,position=pos,direction=d,force='player'};check(e,'created actual machine')
   local u={machine=e,recipe=recipe.name,requested_direction=d};local row={requested=d,placed=e.direction,position=e.position,fluid_boxes=e.fluids_count,ports={}}
   for box=1,e.fluids_count do row.ports[#row.ports+1]={box=box,connections=e.get_fluid_box_pipe_connections(box)}end
   row.rotate_result=e.rotate();row.direction_after_rotation=e.direction;for _=1,3 do e.rotate()end;row.direction_after_four_rotations=e.direction
   if i==1 then directions[#directions+1]=row end
   local accepted=e.set_recipe(recipe.name);u.recipe_set_result=accepted;check(e.get_recipe() and e.get_recipe().name==recipe.name,'actual process accepted '..recipe.name)
   local input=e.get_inventory(defines.inventory.crafter_input);for _,v in ipairs(recipe.ingredients)do check(v.type=='item','all actual process ingredients are items');check(input.insert{name=v.name,count=v.amount}==v.amount,'real process ingredient '..v.name)end
   u.initial_input=inventory(input);u.input_slots=#input;u.output_slots=#e.get_output_inventory();u.module_slots=#e.get_module_inventory();check(not e.get_fuel_inventory(),'no burner fuel inventory')
   local power=s.create_entity{name='citadel-contract-power',position={pos.x+4.5,pos.y+4.5},force='player'};local pole=s.create_entity{name='medium-electric-pole',position={pos.x+2,pos.y+3},force='player'};check(power and pole,'isolated fixture electrical supply');storage.units[#storage.units+1]=u
  end
 end
 local planet=game.surfaces[1];area(planet,{x=20.5,y=20.5},'grass-1')
 local e=storage.units[1].machine;local connector_ids={};for id in pairs(e.get_wire_connectors(true))do connector_ids[#connector_ids+1]=id end
 local report={entity={name=p.name,type=p.type,footprint={p.tile_width,p.tile_height},collision_box=p.collision_box,selection_box=p.selection_box,crafting_speed=p.get_crafting_speed(),crafting_categories=p.crafting_categories,maximum_energy_usage_watts=p.get_max_energy_usage()*60,electric=not not p.electric_energy_source_prototype,burner=not not p.burner_prototype,drain_joules_per_tick=optional(function()return p.electric_energy_source_prototype.drain end),surface_conditions=p.surface_conditions,circuit_wire_reach=p.get_max_circuit_wire_distance(),maximum_supported_wire_reach=p.get_max_wire_distance(),fluid_boxes=e.fluids_count,module_slots=#e.get_module_inventory(),native_wire_connector_ids=connector_ids},item={name=name,place_result=prototypes.item[name].place_result.name,stack_size=prototypes.item[name].stack_size,weight=optional(function()return prototypes.item[name].weight end)},building_recipe={name=name,seconds=build.energy,categories=build.categories,ingredients=build.ingredients,products=build.products,initially_locked=gated},processing_recipes=processes,excluded_blueprint_parameter_placeholders=excluded_parameters,technology_unlocks=unlocks,directions=directions,ordinary_platform_placement=true,ordinary_nauvis_placement=planet.can_place_entity{name=name,position={20.5,20.5},force='player'},actual_platform_properties={gravity=s.get_property('gravity'),pressure=s.get_property('pressure')},sacred_machine_oil_is_item=not not prototypes.item['sacred-machine-oil'],sacred_machine_oil_is_fluid=not not prototypes.fluid['sacred-machine-oil'],fixture='One real batch of each actual processing recipe supplied to each requested direction. Existing current production machine, no recipe/power/surface overrides. Fixture electrical source only, target energy never assigned. Full blocked/starved/reload/art completion is separate.'}
 helpers.write_file('citadel-contract/contract.json',helpers.table_to_json(report),false);log('CITADEL_CURRENT_CONTRACT_CAPTURED recipes='..#processes..' cases='..#storage.units)
end)
script.on_event(defines.events.on_tick,function(ev)
 if ev.tick%300~=0 and ev.tick~=1900 then return end
 local rows={};for _,u in ipairs(storage.units)do local e=u.machine;rows[#rows+1]={recipe=u.recipe,requested_direction=u.requested_direction,direction=e.direction,status=status(e),crafting_progress=e.crafting_progress,products_finished=e.products_finished,energy=e.energy,input=inventory(e.get_inventory(defines.inventory.crafter_input)),output=inventory(e.get_output_inventory()),input_slots=u.input_slots,output_slots=u.output_slots,module_slots=u.module_slots}end
 storage.samples[#storage.samples+1]={tick=ev.tick,rows=rows};helpers.write_file('citadel-contract/operation.json',helpers.table_to_json{samples=storage.samples},false)
 if ev.tick==1900 then for _,u in ipairs(storage.units)do check(u.machine.products_finished>=1,'real native output '..u.recipe);check(u.machine.get_inventory(defines.inventory.crafter_input).is_empty(),'actual ingredients consumed '..u.recipe)end;log('CITADEL_BASELINE_ALL_NATIVE_RECIPES_PASS cases='..#storage.units)end
end)
