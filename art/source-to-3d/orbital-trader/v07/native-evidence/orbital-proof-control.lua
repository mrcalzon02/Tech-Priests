-- Focused actual-mod operating proof: all seven real recipes and native pod reuse.
local function check(x,m)if not x then error('ORBITAL_PROOF: '..m)end end
local function snap(u)local e=u.machine;return{recipe=u.recipe,products=e.products_finished,progress=e.crafting_progress,status=e.status,energy=e.energy,input=e.get_inventory(defines.inventory.crafter_input).get_contents(),output=e.get_output_inventory().get_contents(),health=e.health}end
local function ground(s,p)local t={};s.request_to_generate_chunks(p,2);s.force_generate_chunk_requests();for x=-10,30 do for y=-12,16 do t[#t+1]={name='grass-1',position={p.x+x,p.y+y}}end end;s.set_tiles(t,true);for _,e in pairs(s.find_entities_filtered{area={{p.x-10,p.y-12},{p.x+30,p.y+16}},type={'tree','simple-entity','cliff'}})do e.destroy()end end
local function record(label)local a={};for _,u in ipairs(storage.units)do a[#a+1]=snap(u)end;storage.samples[label]=a end
local function move_all(from,to)for _,v in pairs(from.get_contents())do check(to.insert(v)==v.count,'retain actual stock');check(from.remove(v)==v.count,'transfer actual stock exactly')end end
local function same(a,b)return a.products==b.products and math.abs(a.progress-b.progress)<.001 end
script.on_init(function()
 game.speed=16;local f=game.forces.player;local s=game.surfaces[1];s.daytime=0;s.freeze_daytime=true;storage.units={};storage.samples={};local p=prototypes.entity['orbital-trader'];check(p.type=='assembling-machine'and p.tile_width==6 and p.tile_height==6 and math.abs(p.get_max_energy_usage()*60-750000)<.01,'actual native contract retained')
 local wanted={};for n,r in pairs(prototypes.recipe)do if not r.parameter then for _,cat in pairs(r.categories)do if cat=='orbital-trader'then wanted[n]=r end end end end
 local unlocks={};for n,t in pairs(prototypes.technology)do for _,ef in pairs(t.effects or{})do if ef.type=='unlock-recipe'and(wanted[ef.recipe]or ef.recipe=='orbital-trader')then unlocks[n]=true end end end
 check(not f.recipes['orbital-trader'].enabled,'actual building recipe initially locked');for n in pairs(unlocks)do f.technologies[n].researched=true end;check(f.recipes['orbital-trader'].enabled,'actual technology unlock')
 local names={};for n in pairs(wanted)do names[#names+1]=n end;table.sort(names);check(#names==7,'all actual trade/cargo recipes')
 for i,n in ipairs(names)do
  check(f.recipes[n].enabled,'actual processing unlock '..n);local r=wanted[n];local pos={x=20+(i-1)*60,y=20};ground(s,pos);check(s.can_place_entity{name=p.name,position=pos,direction=4,force=f},'normal player-grid placement '..helpers.table_to_json((function()local q={};for _,b in pairs(s.find_entities_filtered{area={{pos.x-2.7,pos.y-2.7},{pos.x+2.7,pos.y+2.7}}})do q[#q+1]={name=b.name,position=b.position}end;return q end)()));local e=assert(s.create_entity{name=p.name,position=pos,direction=4,force=f,raise_built=true});check(e.direction==0 and not e.rotate(),'actual fixed north retained');e.set_recipe(n);check(e.fluids_count==0 and #e.get_module_inventory()==0,'no active fluid ports or modules')
  local u={machine=e,position=pos,recipe=n,sides={},health=e.health,wraps=0,last_progress=0};storage.units[#storage.units+1]=u
  for _,dx in ipairs({-4.5,4.5})do for _,dy in ipairs({-4.5,4.5})do check(s.create_entity{name='medium-electric-pole',position={pos.x+dx,pos.y+dy},force=f},'ordinary pole coverage')end end
  u.power=assert(s.create_entity{name='orbital-proof-power',position={pos.x+7.5,pos.y+7.5},force=f});u.hold=assert(s.create_entity{name='steel-chest',position={pos.x+6.5,pos.y+6.5},force=f})
  local defs={{'north',-1.5,-3.5,0,1.5,-3.5,8},{'east',3.5,-1.5,4,3.5,1.5,12},{'south',1.5,3.5,8,-1.5,3.5,0},{'west',-3.5,1.5,12,-3.5,-1.5,4}}
  for _,v in ipairs(defs)do
   local function put(name,x,y,d)local q={x=pos.x+x,y=pos.y+y};check(s.can_place_entity{name=name,position=q,direction=d or 0,force=f},'normal grid '..name..' '..v[1]);return assert(s.create_entity{name=name,position=q,direction=d or 0,force=f})end
   local input=put('fast-inserter',v[2],v[3],v[4]);local output=put('fast-inserter',v[5],v[6],v[7]);input.disabled_by_script=true;output.disabled_by_script=true
   local dx,dy=v[2]/math.abs(v[2]),v[3]/math.abs(v[3]);if math.abs(v[2])>math.abs(v[3])then dy=0 else dx=0 end
   local source=put('steel-chest',v[2]+dx,v[3]+dy);local sink=put('steel-chest',v[5]+dx,v[6]+dy)
   for _,it in ipairs(r.ingredients)do check(it.type=='item'and source.insert{name=it.name,count=it.amount*8}==it.amount*8,'real finite ingredient stock')end
   u.sides[#u.sides+1]={name=v[1],input=input,output=output,source=source,sink=sink}
  end
  local c=assert(s.create_entity{name='constant-combinator',position={pos.x+5.5,pos.y+3.5},force=f});local b=c.get_or_create_control_behavior();u.section=b.get_section(1)or b.add_section()
  for _,id in ipairs({defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green})do local a=e.get_wire_connector(id,true);local z=c.get_wire_connector(id,true);check(a.can_wire_reach(z)and a.connect_to(z,true,defines.wire_origin.player),'ordinary reach-checked red/green wires')end
 end
 record('empty-idle')
end)
script.on_event(defines.events.on_tick,function(ev)
 local t=ev.tick
 if storage.complete then
  if t>=storage.complete_tick+360 and not storage.persistence_reported then storage.persistence_reported=true;for _,u in ipairs(storage.units)do check(u.machine.valid and u.machine.health==u.health,'operated entities persist without pod damage')end;helpers.write_file('orbital-proof/reloaded-state.json',helpers.table_to_json{passed=true,tick=t,visuals=remote.call('tp_orbital_visuals','inspect')},false);log('ORBITAL_PERSISTENT_STATE_PASS')end;return
 end
 for _,u in ipairs(storage.units)do local p=u.machine.crafting_progress;if p<u.last_progress-.01 and u.last_progress>.5 then u.wraps=u.wraps+1 end;u.last_progress=p end
 if t==120 then
  for _,u in ipairs(storage.units)do check(not u.machine.is_crafting(),'empty idle');for _,v in ipairs(u.sides)do v.input.disabled_by_script=false;v.output.disabled_by_script=false end end
 elseif t==180 then
  for _,u in ipairs(storage.units)do for _,v in ipairs(u.sides)do check(v.input.drop_target==u.machine and v.output.pickup_target==u.machine,'actual normal four-sided inserter targets '..v.name..' '..helpers.table_to_json{input_pickup=v.input.pickup_position,input_drop=v.input.drop_position,output_pickup=v.output.pickup_position,output_drop=v.output.drop_position})end end
 elseif t==3300 then
  for _,u in ipairs(storage.units)do check(u.machine.products_finished>0 or u.wraps>0,'actual recipe completed '..u.recipe);check(u.machine.health==u.health,'native pods do not damage facility');u.machine.disabled_by_script=true;u.stopped=snap(u)end;record('working-real-products')
  local v=remote.call('tp_orbital_visuals','inspect');local machines={};for _,u in ipairs(storage.units)do machines[#machines+1]=snap(u)end;helpers.write_file('orbital-proof/visual-diagnostic.json',helpers.table_to_json{visuals=v,machines=machines},false);check(v.native_arrivals>=7,'existing native cargo pod arrivals');for _,r in ipairs(v.machines)do check(r.render_objects_valid and not r.spawn_failed,'actual hatch layers and native pod controller')end;storage.arrivals=v
 elseif t==3420 then for _,u in ipairs(storage.units)do check(same(snap(u),u.stopped),'script stop holds recipe');u.machine.disabled_by_script=false end;record('stop-restart')
 elseif t==3600 then for _,u in ipairs(storage.units)do for _,v in ipairs(u.sides)do v.output.disabled_by_script=true end;u.machine.disabled_by_script=true;move_all(u.machine.get_output_inventory(),u.hold.get_inventory(defines.inventory.chest));local inv=u.machine.get_output_inventory();local products={};for _,v in pairs(prototypes.recipe[u.recipe].products)do products[v.name]=true end;for _,v in ipairs(prototypes.recipe[u.recipe].products)do if v.type=='item'and(v.independent_probability or v.probability or 1)>0 then u.blocker=v.name;break end end;check(u.blocker,'real output blocking stock');for k=1,#inv do inv[k].set_stack{name=u.blocker,count=prototypes.item[u.blocker].stack_size}end;u.machine.disabled_by_script=false end
 elseif t==6480 then for _,u in ipairs(storage.units)do u.blocked=snap(u)end
 elseif t==6600 then local rows={};for _,u in ipairs(storage.units)do local now=snap(u);rows[#rows+1]={recipe=u.recipe,before=u.blocked,now=now,same=same(now,u.blocked),is_crafting=u.machine.is_crafting(),blocker=u.blocker}end;helpers.write_file('orbital-proof/blocked-diagnostic.json',helpers.table_to_json(rows),false);for _,u in ipairs(storage.units)do check(same(snap(u),u.blocked)and u.machine.status==defines.entity_status.full_output,'full output blocks actual recipe');u.machine.get_output_inventory().clear();for _,v in ipairs(u.sides)do v.output.disabled_by_script=false end end;record('blocked-output-release')
 elseif t==6900 then for _,u in ipairs(storage.units)do u.power.destroy()end
 elseif t==7140 then for _,u in ipairs(storage.units)do u.unpowered=snap(u)end
 elseif t==7260 then for _,u in ipairs(storage.units)do check(same(snap(u),u.unpowered)and u.machine.energy<.01,'actual grid power starvation');u.power=assert(u.machine.surface.create_entity{name='orbital-proof-power',position={u.position.x+7.5,u.position.y+7.5},force='player'})end;record('power-starvation-resupply')
 elseif t==7500 then for _,u in ipairs(storage.units)do for _,v in ipairs(u.sides)do v.input.disabled_by_script=true end end
 elseif t==7560 then for _,u in ipairs(storage.units)do move_all(u.machine.get_inventory(defines.inventory.crafter_input),u.hold.get_inventory(defines.inventory.chest))end
 elseif t==10380 then for _,u in ipairs(storage.units)do u.starved=snap(u)end
 elseif t==10500 then for _,u in ipairs(storage.units)do check(same(snap(u),u.starved)and not u.machine.is_crafting(),'real ingredient starvation');for _,v in ipairs(u.sides)do v.input.disabled_by_script=false end end;record('ingredient-starvation-resupply')
 elseif t==10800 then for _,u in ipairs(storage.units)do check(u.machine.is_crafting(),'real ingredient resupply restarts');local b=u.machine.get_or_create_control_behavior();b.circuit_enable_disable=true;b.circuit_condition={comparator='>',first_signal={type='virtual',name='signal-A'},constant=0}end
 elseif t==10920 then for _,u in ipairs(storage.units)do check(u.machine.get_control_behavior().disabled,'native circuit disables');u.circuit_stop=snap(u)end
 elseif t==11040 then for _,u in ipairs(storage.units)do check(same(snap(u),u.circuit_stop),'circuit stop holds');u.section.set_slot(1,{value={type='virtual',name='signal-A',quality='normal'},min=1})end;record('native-circuit-restart')
 elseif t==11280 then
  for _,u in ipairs(storage.units)do check(not u.machine.get_control_behavior().disabled and u.machine.is_crafting(),'native signal restarts actual recipe')end
  local u=storage.units[1];local s=u.machine.surface;storage.builder=assert(s.create_entity{name='assembling-machine-3',position={u.position.x+10.5,u.position.y+1.5},force='player'});s.create_entity{name='medium-electric-pole',position={u.position.x+10.5,u.position.y+4.5},force='player'};storage.builder.set_recipe('orbital-trader');for _,it in ipairs(prototypes.recipe['orbital-trader'].ingredients)do check(storage.builder.insert{name=it.name,count=it.amount}==it.amount,'actual building ingredient')end
 elseif t==12000 then
  local inv=storage.builder.get_output_inventory();check(inv.get_item_count('orbital-trader')==1,'real building recipe completed');check(inv.remove{name='orbital-trader',count=1}==1,'consume crafted placeable item');local u=storage.units[1];local s=u.machine.surface;local pos={u.position.x+22,u.position.y+10};check(s.can_place_entity{name='orbital-trader',position=pos,force='player'},'crafted normal placement');local e=assert(s.create_entity{name='orbital-trader',position=pos,force='player',raise_built=true});local hold=u.hold.get_inventory(defines.inventory.chest);check(e.mine{inventory=hold,raise_destroyed=true}and hold.get_item_count('orbital-trader')==1,'native mining returns crafted item')
  record('completed');storage.complete=true;storage.complete_tick=t;helpers.write_file('orbital-proof/operation.json',helpers.table_to_json{passed=true,actual_seven_recipes=true,ordinary_four_sided_inserters=true,normal_red_green_wires=true,actual_building_recipe_place_mine=true,no_target_or_accumulator_energy_assignments=true,power_fixture='External test-only 50MW electric-energy-interface through ordinary poles; actual target electrical demand and all gameplay fields retained.',samples=storage.samples,visuals=remote.call('tp_orbital_visuals','inspect')},false);log('ORBITAL_NATIVE_OPERATIONAL_PASS');if game.is_multiplayer()then game.server_save('orbital-operated')end
 end
end)

remote.add_interface('orbital_proof',{layout=function()local rows={};for _,u in ipairs(storage.units or{})do rows[#rows+1]={entity=u.machine,position=u.position,surface=u.machine.surface.index,recipe=u.recipe}end;return rows end})
