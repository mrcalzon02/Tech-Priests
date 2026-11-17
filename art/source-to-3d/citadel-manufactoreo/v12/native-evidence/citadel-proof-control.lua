-- Native final-art proof. Actual recipes, normal item inserters and pole coverage.
-- Fixture electricity is supplied by EEIs; target energy is never assigned.
local loaded=false
script.on_load(function()loaded=true end)
local function check(x,m)if not x then error('CITADEL_PROOF: '..m)end end
local function status(e)for n,v in pairs(defines.entity_status)do if e.status==v then return n end end end
local function contents(inv)local a={};if inv then for i=1,#inv do local s=inv[i];a[i]=s.valid_for_read and{name=s.name,count=s.count,quality=s.quality.name}or false end end;return a end
local function same(a,b)
 if type(a)~=type(b)then return false end
 if type(a)=='number'then return math.abs(a-b)<.001 end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function snap(u)
 local e=u.machine
 return {direction=e.direction,recipe=e.get_recipe().name,disabled=e.disabled_by_script,progress=e.crafting_progress,products=e.products_finished,input=contents(e.get_inventory(defines.inventory.crafter_input)),output=contents(e.get_output_inventory()),modules=contents(e.get_module_inventory())}
end
local function ground(s,p)
 s.request_to_generate_chunks(p,2);s.force_generate_chunk_requests();local t={}
 for x=-12,22 do for y=-12,12 do t[#t+1]={name='space-platform-foundation',position={p.x+x,p.y+y}}end end;s.set_tiles(t,true)
end
local function power(s,p)return assert(s.create_entity{name='citadel-proof-power',position={p.x+6,p.y+6},force='player'})end
local function direct(u,batches)
 local inv=u.machine.get_inventory(defines.inventory.crafter_input)
 for _,v in ipairs(u.ingredients)do local n=inv.insert{name=v.name,count=v.amount*batches};check(n>0,'real fixture ingredient inserted '..v.name)end
end
local function select_side(u,n)
 for i,side in ipairs(u.sides)do side.input.disabled_by_script=i~=n;side.output.disabled_by_script=i~=n end
end
local function belt_items(belts)
 local a={};for _,e in ipairs(belts)do for lane=1,2 do for _,stack in pairs(e.get_transport_line(lane).get_contents())do a[stack.name]=(a[stack.name]or 0)+stack.count end end end;return a
end
local function total(items)local n=0;for _,v in pairs(items)do n=n+v end;return n end
local function record(label)
 local r={tick=game.tick,label=label,units={}}
 for _,u in ipairs(storage.units)do
  local sides={};for _,s in ipairs(u.sides)do sides[#sides+1]={name=s.name,input=belt_items(s.source),output=belt_items(s.sink),input_drop=s.input.drop_position,output_pickup=s.output.pickup_position}end
  r.units[#r.units+1]={recipe=u.recipe,surface=u.surface.index,status=status(u.machine),energy=u.machine.energy,snapshot=snap(u),sides=sides}
 end
 storage.samples[#storage.samples+1]=r;helpers.write_file('citadel-v1/samples.json',helpers.table_to_json(storage.samples),false);log('CITADEL_PHASE '..label..' tick='..game.tick)
end
script.on_init(function()
 if remote.interfaces.freeplay and remote.interfaces.freeplay.set_skip_intro then remote.call('freeplay','set_skip_intro',true)end
 local f=game.forces.player;local p=prototypes.entity['citadel-manufactoreo'];check(p.type=='assembling-machine'and p.tile_width==5 and p.tile_height==5,'real 5x5 assembler')
 check(math.abs(p.get_max_energy_usage()*60-2000000)<.01 and p.electric_energy_source_prototype and not p.burner_prototype and p.get_max_circuit_wire_distance()==9,'real electrical and native circuit contract')
 check(not f.recipes[p.name].enabled,'real locked building recipe');f.technologies['blackstone-citadel-manufacture'].researched=true;check(f.recipes[p.name].enabled,'real technology unlock')
 local recipes={};for n,r in pairs(prototypes.recipe)do if not r.parameter then for _,cat in pairs(r.categories)do if cat=='citadel-manufactoreo'then recipes[#recipes+1]=r;break end end end end
 table.sort(recipes,function(a,b)return a.name<b.name end);check(#recipes==3,'all three real processes')
 storage.units={};storage.samples={}
 for i,r in ipairs(recipes)do
  local platform=f.create_space_platform{name='Citadel native '..r.name,planet='nauvis',starter_pack='space-platform-starter-pack'};platform.apply_starter_pack(true);local s=platform.surface;local pos={x=20.5,y=20.5};ground(s,pos);s.daytime=0;s.freeze_daytime=true
  check(s.can_place_entity{name=p.name,position=pos,direction=4,force='player'},'normal grid platform placement');local e=s.create_entity{name=p.name,position=pos,direction=4,force='player'};check(e.direction==0 and not e.rotate(),'single actual fixed-north facing');check(e.fluids_count==0 and not e.get_fuel_inventory(),'no fluid ports or burner')
  check(e.set_recipe(r.name)~=false and e.get_recipe().name==r.name,'real recipe selection');local modules=e.get_module_inventory();check(#modules==2 and modules.insert{name='speed-module',count=2}==2,'two real module slots accept modules');check(modules.remove{name='speed-module',count=2}==2,'module test restored unmodified crafting speed')
  local u={machine=e,surface=s,position=pos,recipe=r.name,ingredients=r.ingredients,sides={},primary=nil};for _,v in ipairs(r.products)do if v.type=='item'and(v.independent_probability or v.probability or 1)>0 then u.primary=v.name;break end end;check(u.primary,'real output item')
  for _,dx in ipairs({-3,3})do for _,dy in ipairs({-3,3})do check(s.create_entity{name='medium-electric-pole',position={pos.x+dx,pos.y+dy},force='player'},'normal pole coverage')end end;u.power=power(s,pos)
  local defs={{'north',-1,-3,0,1,-3,8},{'east',3,-1,4,3,1,12},{'south',1,3,8,-1,3,0},{'west',-3,1,12,-3,-1,4}}
  for _,v in ipairs(defs)do
   local function put(n,dx,dy,d)local q={x=pos.x+dx,y=pos.y+dy};local can=s.can_place_entity{name=n,position=q,direction=d or 0,force='player'};if not can then local blockers={};for _,b in ipairs(s.find_entities_filtered{area={{q.x-.48,q.y-.48},{q.x+.48,q.y+.48}}})do blockers[#blockers+1]={name=b.name,position=b.position,direction=b.direction}end;log('CITADEL_PLACEMENT_DIAGNOSTIC '..helpers.table_to_json{entity=n,position=q,direction=d,side=v[1],blockers=blockers,tile=s.get_tile(q).name})end;check(can,'ordinary grid '..n..' '..v[1]);return assert(s.create_entity{name=n,position=q,direction=d or 0,force='player'})end
   local input=put('fast-inserter',v[2],v[3],v[4]);local output=put('fast-inserter',v[5],v[6],v[7]);input.disabled_by_script=true;output.disabled_by_script=true
   log('CITADEL_INSERTER_ENDPOINTS '..helpers.table_to_json{input_position=input.position,input_direction=input.direction,pickup=input.pickup_position,drop=input.drop_position,output_pickup=output.pickup_position,output_drop=output.drop_position})
   local ip=input.pickup_position;local drop=output.drop_position;local op={x=math.floor(drop.x)+.5,y=math.floor(drop.y)+.5};local source={};local sink={};local dx=v[1]=='east'and 1 or(v[1]=='west'and-1 or 0);local dy=v[1]=='south'and 1 or(v[1]=='north'and-1 or 0)
   log('CITADEL_NORMAL_PLATFORM_CHEST_PLACEABILITY '..tostring(s.can_place_entity{name='steel-chest',position=ip,force='player'}))
   for k=0,7 do source[#source+1]=put('transport-belt',ip.x-pos.x+dx*k,ip.y-pos.y+dy*k,(v[4]+8)%16);sink[#sink+1]=put('transport-belt',op.x-pos.x+dx*k,op.y-pos.y+dy*k,(v[7]+8)%16)end
   local sequence={};for _=1,4 do for _,ingredient in ipairs(r.ingredients)do check(ingredient.type=='item','actual item recipe');for _=1,ingredient.amount do sequence[#sequence+1]=ingredient.name end end end
   local initial=#sequence;local cursor=1
   for _,belt in ipairs(source)do for lane=1,2 do for slot=0,3 do if sequence[cursor]then check(belt.get_transport_line(lane).insert_at(.125+slot*.25,{name=sequence[cursor],count=1}),'finite real ingredient on ordinary belt');cursor=cursor+1 end end end end;check(cursor==initial+1,'entire finite stock fits normal belts')
   u.sides[#u.sides+1]={name=v[1],input=input,output=output,source=source,sink=sink,initial_input=initial}
  end
  local c=s.create_entity{name='constant-combinator',position={pos.x-5,pos.y-3},force='player'};check(c,'real constant combinator');u.combinator=c;local b=c.get_or_create_control_behavior();u.section=b.get_section(1)or b.add_section()
  for _,id in ipairs({defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green})do local a=e.get_wire_connector(id,true);local z=c.get_wire_connector(id,true);check(a and z and a.can_wire_reach(z)and a.connect_to(z,true,defines.wire_origin.player),'normal player red/green wire reach')end
  storage.units[#storage.units+1]=u
 end
 local platform=f.create_space_platform{name='Citadel native actual building recipe',planet='nauvis',starter_pack='space-platform-starter-pack'};platform.apply_starter_pack(true);local s=platform.surface;local pos={x=20.5,y=20.5};ground(s,pos)
 local builder=s.create_entity{name='assembling-machine-3',position=pos,force='player'};check(builder and builder.set_recipe(p.name)~=false,'real building recipe');for _,v in ipairs(prototypes.recipe[p.name].ingredients)do check(builder.get_inventory(defines.inventory.crafter_input).insert{name=v.name,count=v.amount}==v.amount,'actual building ingredient '..v.name)end
 s.create_entity{name='medium-electric-pole',position={pos.x+2,pos.y+2},force='player'};power(s,{x=pos.x-2,y=pos.y-2});storage.builder=builder;storage.build_surface=s
 record('empty-idle-before-supply')
end)
script.on_event(defines.events.on_tick,function(ev)
 if loaded then
  loaded=false
  if storage.complete then
   check(storage.saved,'completed state has actual operated save snapshot');for i,u in ipairs(storage.units)do check(same(snap(u),storage.saved[i]),'operated machine recipe/inventory/module/progress/direction state persists')end
   storage.reload_tick=ev.tick;helpers.write_file('citadel-v1/reload.json',helpers.table_to_json{passed=true,actual_operated_state_verified=true,units=#storage.units,tick=ev.tick},false);log('CITADEL_OPERATED_RELOAD_PASS')
  end
 end
 if storage.reload_tick then if ev.tick==storage.reload_tick+299 then for i,u in ipairs(storage.units)do check(same(snap(u),storage.saved[i]),'reloaded stopped state holds300ticks')end;helpers.write_file('citadel-v1/reload-300ticks.json',helpers.table_to_json{passed=true,ticks=300},false);log('CITADEL_RELOAD_300_TICKS_PASS')end;return end
 if storage.complete then
  if not storage.saved and ev.tick>=33960 then storage.saved={};for _,u in ipairs(storage.units)do storage.saved[#storage.saved+1]=snap(u)end;game.auto_save('citadel-v1-operated');log('CITADEL_OPERATED_SAVE_REQUESTED')end
  return
 end
 local t=ev.tick
 if t==120 then for _,u in ipairs(storage.units)do select_side(u,1)end;record('north-inserters-enabled')
 elseif t==3600 or t==7200 or t==10800 then local n=t/3600+1;for _,u in ipairs(storage.units)do select_side(u,n)end;record('side-'..n..'-inserters-enabled')
 elseif t==14400 then
  for _,u in ipairs(storage.units)do
   for _,side in ipairs(u.sides)do check(total(belt_items(side.source))<side.initial_input,'real input from '..side.name..' '..u.recipe);check(total(belt_items(side.sink))>0,'real output to '..side.name..' '..u.recipe)end
   check(u.machine.products_finished>=4,'four sided real crafting');select_side(u,0);u.machine.get_inventory(defines.inventory.crafter_input).clear();direct(u,2)
  end;record('all-four-side-item-logistics-pass')
 elseif t==14700 then for _,u in ipairs(storage.units)do check(u.machine.is_crafting(),'working before stop');u.machine.disabled_by_script=true end;record('script-stop')
 elseif t==14760 then for _,u in ipairs(storage.units)do u.stopped=snap(u)end;record('stopped-settled')
 elseif t==15000 then for _,u in ipairs(storage.units)do check(same(snap(u),u.stopped),'stop holds native production/inventory/progress');u.machine.disabled_by_script=false end;record('script-restart')
 elseif t==17400 then
  for _,u in ipairs(storage.units)do check(u.machine.products_finished>u.stopped.products,'real restart output');local out=u.machine.get_output_inventory();for i=1,#out do out[i].set_stack{name=u.primary,count=prototypes.item[u.primary].stack_size}end;u.machine.get_inventory(defines.inventory.crafter_input).clear();direct(u,2)end;record('output-filled')
 elseif t==19800 then for _,u in ipairs(storage.units)do check(u.machine.status==defines.entity_status.full_output,'native full output '..status(u.machine));u.blocked=snap(u)end;record('blocked-output-settled')
 elseif t==20100 then for _,u in ipairs(storage.units)do check(same(snap(u),u.blocked),'blocked output holds native state');u.machine.get_output_inventory().clear();direct(u,1)end;record('output-released')
 elseif t==22500 then for _,u in ipairs(storage.units)do check(u.machine.products_finished>u.blocked.products,'real output release restart');u.machine.get_inventory(defines.inventory.crafter_input).clear();direct(u,2);check(u.power.destroy(),'normal fixture power removal')end;record('power-removed')
 elseif t==22800 then for _,u in ipairs(storage.units)do check(u.machine.status==defines.entity_status.no_power,'real electrical starvation '..status(u.machine));u.unpowered=snap(u)end;record('unpowered-settled')
 elseif t==23100 then for _,u in ipairs(storage.units)do check(same(snap(u),u.unpowered),'power starvation holds native progress');u.power=power(u.surface,u.position)end;record('power-restored')
 elseif t==25500 then for _,u in ipairs(storage.units)do check(u.machine.products_finished>u.unpowered.products,'power resupply real output');u.machine.get_inventory(defines.inventory.crafter_input).clear()end;record('ingredients-removed')
 elseif t==27900 then for _,u in ipairs(storage.units)do check(not u.machine.is_crafting()and u.machine.get_inventory(defines.inventory.crafter_input).is_empty(),'ingredient empty native idle');u.empty=snap(u)end;record('ingredient-starved-settled')
 elseif t==28200 then for _,u in ipairs(storage.units)do check(same(snap(u),u.empty),'empty idle holds production');direct(u,2)end;record('ingredients-resupplied')
 elseif t==30600 then for _,u in ipairs(storage.units)do check(u.machine.products_finished>u.empty.products,'ingredient resupply real output');u.machine.get_inventory(defines.inventory.crafter_input).clear();direct(u,2);local b=u.machine.get_or_create_control_behavior();b.circuit_enable_disable=true;b.circuit_condition={comparator='>',first_signal={type='virtual',name='signal-A'},constant=0}end;record('native-circuit-disable')
 elseif t==30720 then for _,u in ipairs(storage.units)do check(u.machine.get_control_behavior().disabled,'native circuit actually disables');u.circuit_stopped=snap(u)end;record('circuit-disabled-settled')
 elseif t==31020 then for _,u in ipairs(storage.units)do check(same(snap(u),u.circuit_stopped),'circuit disabled holds production');u.section.set_slot(1,{value={type='virtual',name='signal-A',quality='normal'},min=1})end;record('native-circuit-signal-enable')
 elseif t==33420 then
  for _,u in ipairs(storage.units)do check(not u.machine.get_control_behavior().disabled and u.machine.products_finished>u.circuit_stopped.products,'real red/green signal restarts recipe')end
  local out=storage.builder.get_output_inventory();check(out.get_item_count('citadel-manufactoreo')==1 and storage.builder.get_inventory(defines.inventory.crafter_input).is_empty(),'real building recipe consumed exact ingredients')
  local p={x=34.5,y=20.5};check(storage.build_surface.can_place_entity{name='citadel-manufactoreo',position=p,force='player'},'ordinary crafted-item 5x5 placement');storage.placed=storage.build_surface.create_entity{name=prototypes.item['citadel-manufactoreo'].place_result.name,position=p,force='player'};check(storage.placed and out.remove{name='citadel-manufactoreo',count=1}==1,'actual crafted item consumed by scripted placement');storage.placed.disabled_by_script=true
  local inv=game.create_inventory(1);check(storage.placed.mine{inventory=inv}and inv.get_item_count('citadel-manufactoreo')==1,'actual mining recovers placeable item');inv.destroy()
  record('all-operational-gates-pass');for _,u in ipairs(storage.units)do u.machine.disabled_by_script=true end;storage.builder.disabled_by_script=true;storage.complete=true
  helpers.write_file('citadel-v1/native-runtime.json',helpers.table_to_json{passed=true,actual_current_mod=true,independent_recipe_platforms=3,all_actual_processing_recipes=3,fixed_north_5x5_normal_player_grid=true,normal_item_input_and_output_from_all_four_sides=true,real_two_module_slot_insert_remove=true,real_red_and_green_wires_with_reach_check=true,native_circuit_signal_stop_hold_restart=true,electric_supply_starvation_hold_resupply=true,script_stop_hold_restart=true,full_output_hold_release=true,ingredient_starvation_hold_resupply=true,actual_building_recipe_unlock_craft_consumed_item_placement_and_mining=true,target_energy_assignments=false,target_gameplay_overrides=false,fluid_ports=0,burner=false,operated_save_and_reload_pending=true},false);log('CITADEL_NATIVE_OPERATIONAL_PASS recipes=3 four_side_inserters=24')
 end
end)
remote.add_interface('citadel_proof',{layout=function()local r={units={}};for _,u in ipairs(storage.units)do r.units[#r.units+1]={surface=u.surface.index,position=u.machine.position,recipe=u.recipe,direction=u.machine.direction}end;return r end})
