local NAME='tech-priests-emergency-laboratorium'
local function check(v,m)if not v then error('LABORATORIUM PROOF: '..m)end end
local function chest(e)return e.get_inventory(defines.inventory.chest)end
local function progress()return game.forces.player.current_research and game.forces.player.research_progress or 0 end
local function snap()local e=storage.lab;local status_name;for n,id in pairs(defines.entity_status)do if id==e.status then status_name=n;break end end;return{status_name=status_name,research=game.forces.player.current_research and game.forces.player.current_research.name,progress=progress(),status=e.status,fuel=e.burner.remaining_burning_fuel,energy=e.energy,science=e.get_inventory(defines.inventory.lab_input).get_contents()}end
local function record(n)storage.samples[n]=snap()end
local function same(a,b)return a.research==b.research and math.abs(a.progress-b.progress)<1e-8 end
local function move(a,b)for i=1,#a do if a[i].valid_for_read then local n=b.insert(a[i]);check(n==a[i].count,'physical stock conserved');a[i].clear()end end end
local function prereqs(name)
 for n,t in pairs(game.forces.player.technologies[name].prerequisites)do prereqs(n);t.researched=true;storage.prerequisites[n]=true end
end
script.on_init(function()
 local f=game.forces.player;local s=game.surfaces[1];game.speed=20;s.request_to_generate_chunks({20,20},2);s.force_generate_chunk_requests();local tiles={};for x=5,40 do for y=5,45 do tiles[#tiles+1]={name='grass-1',position={x,y}}end end;s.set_tiles(tiles,true)
 for _,e in pairs(s.find_entities_filtered{area={{5,5},{40,45}},type={'tree','simple-entity','cliff'}})do e.destroy()end
 storage.samples={};storage.prerequisites={};local x,y=20.5,20.5;local e=assert(s.create_entity{name=NAME,position={x,y},force=f,raise_built=true});storage.lab=e;storage.position={x=x,y=y};storage.health=e.health
 check(e.prototype.tile_width==1 and e.prototype.tile_height==1 and e.prototype.get_researching_speed()==.33,'real1x1/.33speed');check(math.abs(e.prototype.get_max_energy_usage()*60-20000)<.01 and e.prototype.burner_prototype.effectivity==.75,'real20kW/.75 burner');check(e.fluids_count==0 and #e.get_fuel_inventory()==1,'no fluids/single chemical fuel slot');check(#e.get_inventory(defines.inventory.lab_input)==12,'all12science filters')
 storage.hold=s.create_entity{name='steel-chest',position={x+4,y+4},force=f};local input=e.get_inventory(defines.inventory.lab_input);storage.accepted={}
 for _,name in pairs(e.prototype.lab_inputs)do check(input.insert{name=name,count=3}==3,'actual accepted science '..name);storage.accepted[#storage.accepted+1]=name end;check(input.insert{name='stone',count=1}==0,'non-science rejected');move(input,chest(storage.hold))
 storage.feeds={};local sides={{0,-1,0,'spoilage'},{1,0,4,'automation-science-pack'},{0,1,8,'automation-science-pack'},{-1,0,12,'automation-science-pack'}}
 for k,v in ipairs(sides)do local box=s.create_entity{name='steel-chest',position={x+2*v[1],y+2*v[2]},force=f};chest(box).insert{name=v[4],count=k==1 and 1 or 20};local arm=s.create_entity{name='fast-inserter',position={x+v[1],y+v[2]},direction=v[3],force=f};arm.disabled_by_script=true;storage.feeds[k]={box=box,arm=arm}end
 storage.power=s.create_entity{name='laboratorium-proof-power',position={x+3,y-3},force=f};s.create_entity{name='medium-electric-pole',position={x+2,y-2},force=f};s.create_entity{name='medium-electric-pole',position={x-2,y+2},force=f}
 storage.circuit=s.create_entity{name='constant-combinator',position={x+3,y+1},force=f};storage.section=storage.circuit.get_or_create_control_behavior().add_section()
 for _,id in ipairs({defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green})do local a=e.get_wire_connector(id,true);local b=storage.circuit.get_wire_connector(id,true);check(a.can_wire_reach(b)and a.connect_to(b,true,defines.wire_origin.player),'native red/green reach-checked connections')end
 local b=e.get_or_create_control_behavior();b.read_contents=true;b.read_fuel=true;prereqs('automation');check(not f.technologies.automation.researched and f.add_research('automation'),'real automation research queued');record('empty-idle')
end)
script.on_event(defines.events.on_research_finished,function(ev)
 if ev.research.name=='automation'and ev.research.force==game.forces.player then storage.actual_research_completed_tick=game.tick;check(game.forces.player.recipes['assembling-machine-1'].enabled,'actual research unlock applied');record('actual-automation-completed')end
end)
script.on_event(defines.events.on_tick,function(ev)
 local t=ev.tick;local e=storage.lab;local f=game.forces.player
 if storage.complete then
  if t>=storage.complete_tick+360 and not storage.reloaded then storage.reloaded=true;check(e.valid and e.health==storage.health and f.technologies.automation.researched,'actual completed research and entity persist');check(f.current_research and f.current_research.name=='gun-turret'and progress()>0,'actual ongoing research survives reload');helpers.write_file('laboratorium-proof/reloaded-state.json',helpers.table_to_json{passed=true,snapshot=snap()},false);log('LABORATORIUM_PERSISTENT_STATE_PASS')end;return
 end
 if t==120 then for _,r in ipairs(storage.feeds)do r.arm.disabled_by_script=false end
 elseif t==240 then for _,r in ipairs(storage.feeds)do check(r.arm.drop_target==e,'normal four-sided inserter drop targets')end;record('native-working')
 elseif t==1000 then storage.nofuel=snap()
 elseif t==1120 then helpers.write_file('laboratorium-proof/fuel-diagnostic.json',helpers.table_to_json{before=storage.nofuel,now=snap(),inventory=e.get_fuel_inventory().get_contents(),fuel_chest=chest(storage.feeds[1].box).get_contents()},false);check(same(snap(),storage.nofuel)and e.status==defines.entity_status.no_power and e.burner.remaining_burning_fuel<.01 and e.energy<.01,'real spoilage fuel naturally exhausts');chest(storage.feeds[1].box).insert{name='coal',count=10};record('fuel-starvation-resupply')
 elseif t==1500 then check(progress()>storage.nofuel.progress,'real coal resupply resumes research');e.disabled_by_script=true;storage.stopped=snap()
 elseif t==1620 then check(same(snap(),storage.stopped),'script stop holds actual research');e.disabled_by_script=false;record('script-stop-restart')
 elseif t==2000 then
  local n=e.get_circuit_network(defines.wire_type.red);check(n and n.get_signal{type='item',name='automation-science-pack',quality='normal'}==e.get_inventory(defines.inventory.lab_input).get_item_count('automation-science-pack'),'native circuit reads actual science stock');helpers.write_file('laboratorium-proof/circuit-diagnostic.json',helpers.table_to_json{network_coal=n.get_signal{type='item',name='coal',quality='normal'},inventory_coal=e.get_fuel_inventory().get_item_count('coal'),burning=e.burner.currently_burning and e.burner.currently_burning.name.name,burning_joules=e.burner.remaining_burning_fuel},false);check(n.get_signal{type='item',name='coal',quality='normal'}==e.get_fuel_inventory().get_item_count('coal')+((e.burner.currently_burning and e.burner.currently_burning.name.name=='coal'and e.burner.remaining_burning_fuel>0)and 1 or 0),'native circuit reads fuel stock plus burning coal');record('native-circuit-contents')
 elseif t==2500 then for k=2,4 do storage.feeds[k].arm.disabled_by_script=true end;move(e.get_inventory(defines.inventory.lab_input),chest(storage.hold))
 elseif t==5000 then storage.starved=snap()
 elseif t==5120 then check(same(snap(),storage.starved)and e.status==defines.entity_status.missing_science_packs,'real science starvation blocks');for k=2,4 do storage.feeds[k].arm.disabled_by_script=false end;record('science-starvation-resupply')
 elseif t==5600 then check(progress()>storage.starved.progress,'science resupply resumes research')
 elseif t==6000 then storage.saved_progress=progress();f.cancel_current_research();record('no-current-research')
 elseif t==6120 then check(not f.current_research and e.status==defines.entity_status.no_research_in_progress,'native no-research idle');storage.idle_fuel=e.burner.remaining_burning_fuel
 elseif t==6240 then
  check(not f.current_research and e.burner.remaining_burning_fuel==storage.idle_fuel,'idle research does not burn fuel');local b=e.get_control_behavior();b.set_research=true;b.research_conditions={{condition={comparator='>',first_signal={type='virtual',name='signal-A'},constant=0},name='automation'}}
 elseif t==6360 then check(not f.current_research,'zero circuit signal does not select research');storage.section.set_slot(1,{value={type='virtual',name='signal-A',quality='normal'},min=1})
 elseif t==6600 then check(f.current_research and f.current_research.name=='automation'and progress()>=storage.saved_progress,'native circuit selects and resumes saved research');e.get_control_behavior().set_research=false;record('native-circuit-research-selection')
 end
 if storage.actual_research_completed_tick and not storage.finishing then
  storage.finishing=true;storage.finish_start=t;prereqs('gun-turret');check(f.add_research('gun-turret'),'next actual research queued');local s=e.surface;storage.builder=s.create_entity{name='assembling-machine-3',position={x=24.5,y=28.5},force=f};s.create_entity{name='medium-electric-pole',position={x=24.5,y=25.5},force=f};storage.builder.set_recipe(NAME);check(storage.builder.insert{name='iron-plate',count=1}==1 and storage.builder.insert{name='copper-plate',count=1}==1,'actual building ingredients')
 end
 if storage.finishing and t==storage.finish_start+600 then
  check(progress()>0 and f.current_research.name=='gun-turret','new research actually advances');local out=storage.builder.get_output_inventory();check(out.remove{name=NAME,count=1}==1,'actual4s building recipe completed and item consumed');local pos={x=25.5,y=31.5};check(e.surface.can_place_entity{name=NAME,position=pos,force=f},'normal crafted placement');local made=e.surface.create_entity{name=NAME,position=pos,force=f,raise_built=true};check(made.mine{inventory=chest(storage.hold),raise_destroyed=true}and chest(storage.hold).get_item_count(NAME)==1,'native mining returns crafted item');check(e.health==storage.health,'health retained');record('completed');storage.complete=true;storage.complete_tick=t
  helpers.write_file('laboratorium-proof/operation.json',helpers.table_to_json{passed=true,accepted_actual_science_inputs=storage.accepted,actual_automation_research_completed=true,actual_automation_unlock=true,actual_next_gun_turret_research_advancing=true,research_progress_never_assigned=true,prerequisites_granted_only_for_fixture=storage.prerequisites,normal_four_sided_inserters=true,native_red_green_science_fuel_contents=true,native_circuit_research_selection_and_saved_resume=true,actual_fuel_exhaustion_and_resupply=true,actual_science_starvation_and_resupply=true,script_stop_restart=true,no_current_research_idle=true,actual_building_craft_place_mine=true,no_target_or_accumulator_energy_assignments=true,power_fixture='External test-only EEI powers ordinary inserters and the construction assembler. Actual lab uses its own20kW chemical burner. No lab/accumulator energy or research progress assigned.',blocked_output='Not applicable: native lab has science inputs and research progress, no crafting output inventory.',samples=storage.samples},false);log('LABORATORIUM_NATIVE_OPERATIONAL_PASS');if game.is_multiplayer()then game.server_save('laboratorium-operated')end
 end
 if t>45000 and not storage.complete then error('LABORATORIUM PROOF: actual research did not complete within expected native time')end
end)
remote.add_interface('laboratorium_proof',{layout=function()return{{entity=storage.lab,position=storage.position,surface=storage.lab.surface.index}}end})
