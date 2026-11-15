-- Actual pipes, electricity and inserters; only water, steel and power supplied.
local c=require('__tp-mh7-pellet-decay__/config');local specs=require('__tp-hydrogen-production__/specs')
local function check(ok,message)if not ok then error('HYDROGEN_CHAIN_FAIL '..message,0) end end
local function write(name,value)helpers.write_file('tp-hydrogen-chain-review/'..name..'.json',helpers.table_to_json(value),false) end
local function snapshot(s)
 if not s or not s.valid_for_read then return {empty=true} end
 return {name=s.name,count=s.count,quality=s.quality.name,health=s.health,spoil_tick=s.spoil_tick,tags=s.is_item_with_tags and s.tags or nil}
end
local dirs={defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west}
local function machine(surface,name,x,y,dir)
 return assert(surface.create_entity{name=name,position={x,y},direction=dir or defines.direction.north,force='player',raise_built=true})
end
local function line(surface,points)
 local seen={};local pipes={}
 local function add(x,y)
  local key=x..':'..y;if seen[key] then return end;seen[key]=true
  local p=surface.find_entity('pipe',{x,y}) or assert(surface.create_entity{name='pipe',position={x,y},force='player'})
  pipes[#pipes+1]=p
 end
 for i=1,#points-1 do local a,b=points[i],points[i+1];local dx=b[1]-a[1];local dy=b[2]-a[2]
  check(dx==0 or dy==0,'fixture pipe diagonal');local n=math.abs(dx)+math.abs(dy)
  for j=0,n do add(a[1]+(dx==0 and 0 or dx/math.abs(dx)*j),a[2]+(dy==0 and 0 or dy/math.abs(dy)*j)) end
 end
 return pipes
end
local function snap_machine(e)
 local inv=e.get_output_inventory();local items={};if inv then for i=1,#inv do if inv[i].valid_for_read then items[#items+1]=snapshot(inv[i]) end end end
 return {name=e.name,energy=e.energy,status=e.status,crafting=e.is_crafting(),progress=e.crafting_progress,finished=e.products_finished,fluids=e.get_fluid_contents(),output=items}
end
script.on_event(defines.events.on_player_joined_game,function(event)
 game.tick_paused=false;game.speed=1;local p=game.get_player(event.player_index)
 if p then p.set_controller{type=defines.controllers.god};p.teleport({5,4},game.surfaces[1]);p.zoom=.7 end
end)
script.on_init(function()
 local surface=game.surfaces[1];surface.peaceful_mode=true;surface.always_day=true;surface.request_to_generate_chunks({4,10},6);surface.force_generate_chunk_requests()
 for _,e in pairs(surface.find_entities_filtered{area={{-28,-16},{56,48}}}) do e.destroy() end
 local tiles={};for x=-28,56 do for y=-16,48 do tiles[#tiles+1]={name='concrete',position={x,y}} end end;surface.set_tiles(tiles,true)
 local force=game.forces.player;check(not force.recipes['tp-hydrogen-build-purifier'].enabled,'construction unlocked before research');force.technologies['tp-metallicized-hydrogen-production'].researched=true
 for _,key in ipairs{'purifier','electrolyzer','compressor','crucible','forge','fabricator','assembler'} do check(force.recipes['tp-hydrogen-build-'..key].enabled,'research failed to unlock '..key) end
 storage.hydrogen_chain={machines={},pipes={},history={},shots={},unseal={},forge_seen={},assembler_seen={}};local p=storage.hydrogen_chain
 p.machines.purifier=machine(surface,'tp-mh7-review-purifier',-18.5,.5)
 p.machines.electrolyzer=machine(surface,'tp-mh7-review-electrolyzer',-8.5,0)
 p.machines.compressor=machine(surface,'tp-mh7-review-compressor',2.5,0)
 p.machines.crucible=machine(surface,'tp-mh7-review-crucible',14.5,.5)
 p.machines.forge=machine(surface,'tp-mh7-review-forge',19.5,.5)
 p.machines.fabricator=machine(surface,'tp-mh7-review-fabricator',24,5)
 p.machines.assembler=machine(surface,'tp-mh7-canister-assembler',24,0)
 for key,e in pairs(p.machines) do check(e.prototype.electric_energy_source_prototype,'void source remains '..key) end
 p.pipes.raw=line(surface,{{-21.5,.5},{-20.5,.5}})
 p.pipes.purified=line(surface,{{-16.5,.5},{-16.5,3.5},{-8.5,3.5},{-8.5,2.5}})
 p.pipes.hydrogen=line(surface,{{-10.5,-.5},{-11.5,-.5},{-11.5,-4.5},{.5,-4.5},{.5,-.5}})
 p.pipes.oxygen=line(surface,{{-6.5,-.5},{-3.5,-.5}})
 p.pipes.compressed=line(surface,{{4.5,-.5},{10.5,-.5},{10.5,.5},{11.5,.5}})
 p.pipes.forming=line(surface,{{20.5,4.5},{21.5,4.5}})
 p.steel=machine(surface,'steel-chest',24.5,8.5);p.steel.insert{name='steel-plate',count=100}
 p.output=machine(surface,'steel-chest',27.5,.5);p.backup=game.create_inventory(48)
 p.inserters={machine(surface,'inserter',17.5,.5,defines.direction.west),machine(surface,'inserter',21.5,.5,defines.direction.west),machine(surface,'inserter',24.5,2.5,defines.direction.south),machine(surface,'inserter',24.5,7.5,defines.direction.south),machine(surface,'inserter',26.5,.5,defines.direction.west)}
 p.power=machine(surface,'tp-hydrogen-fixture-power',-18,-10)
 p.poles={};for _,x in ipairs{-16,-8,0,8,16,24} do p.poles[#p.poles+1]=machine(surface,'substation',x,-7) end
 p.poles[#p.poles+1]=machine(surface,'substation',29,7)
 p.purifier_probes={}
 for r=0,3 do
  local center={x=-18.5+r*12,y=26.5};local e=machine(surface,'tp-mh7-review-purifier',center.x,center.y,dirs[r+1]);local function rotate(x,y)for _=1,r do x,y=-y,x end;return {center.x+x,center.y+y} end
  local input=rotate(-2,0);local output=rotate(2,0);local raw=machine(surface,'pipe',input[1],input[2]);local clean=machine(surface,'pipe',output[1],output[2])
  local power=machine(surface,'tp-hydrogen-fixture-power',center.x,center.y+5);machine(surface,'substation',center.x,center.y+4)
  check(e.direction==dirs[r+1],'purifier rotation discarded')
  p.purifier_probes[#p.purifier_probes+1]={entity=e,input=raw,output=clean,power=power,r=r}
 end
 p.clocks={};for index,spec in ipairs(specs) do
  local e=machine(surface,'tp-hydrogen-clock-'..spec.key,-22+index*10,42);e.set_recipe('tp-hydrogen-clock-'..spec.key);p.clocks[#p.clocks+1]={entity=e,key=spec.key}
 end
 -- A separate waste probe starts as a real critical pellet, then expires in
 -- its chest before the feeder is enabled. No live intermediates enter the
 -- seven-machine production line above.
 p.waste={forge=machine(surface,'tp-mh7-review-forge',36.5,24.5),assembler=machine(surface,'tp-mh7-canister-assembler',41,24),source=machine(surface,'steel-chest',33.5,24.5),output=machine(surface,'steel-chest',44.5,24.5),shells=machine(surface,'steel-chest',41.5,20.5)}
 local raw=p.waste.source.get_inventory(defines.inventory.chest)[1];raw.set_stack{name=c.stages[4].name,count=1,quality='legendary',health=.11};remote.call('tp-mh7-pellet-decay','initialize_stack',raw);raw.spoil_tick=200
 p.waste.shells.insert{name=c.shell,count=1,quality='uncommon',health=.77}
 p.waste.feeder=machine(surface,'inserter',34.5,24.5,defines.direction.west);p.waste.feeder.disabled_by_script=true
 machine(surface,'inserter',38.5,24.5,defines.direction.west);machine(surface,'inserter',43.5,24.5,defines.direction.west);machine(surface,'inserter',41.5,21.5,defines.direction.north)
 machine(surface,'tp-hydrogen-fixture-power',41,30);machine(surface,'substation',41,28)
end)
script.on_event(defines.events.on_tick,function(event)
 local p=storage.hydrogen_chain;if not p then return end
 if event.tick==1 then game.surfaces[1].destroy_decoratives{area={{-28,-16},{56,48}}} end
 if event.tick==1 or event.tick==60 then
  for _,e in pairs(game.surfaces[1].find_entities_filtered{area={{-28,-16},{56,48}}}) do
   if e.name:find('^crash%-site%-') or e.name=='compilatron' then e.destroy() end
  end
 end
 if event.tick==240 then check(p.waste.source.get_item_count(c.inert)==1,'waste probe did not actually expire');p.waste.feeder.disabled_by_script=false end
 if event.tick%30==0 then
  -- Only the external raw water and forming-water supply are replenished.
  p.pipes.raw[1].set_fluid(1,{name='water',amount=100});p.pipes.forming[1].set_fluid(1,{name='water',amount=100})
  for _,probe in ipairs(p.purifier_probes) do probe.input.set_fluid(1,{name='water',amount=100}) end
 end
 if event.tick>=4000 and event.tick<4600 then p.power.power_production=0;p.power.energy=0 elseif event.tick==4600 then p.power.power_production=100000000/60 end
 if event.tick==4200 or event.tick==4500 then
  local snapshot={};for key,e in pairs(p.machines) do snapshot[key]=snap_machine(e) end
  if event.tick==4200 then p.power_off=snapshot else
   for key,row in pairs(snapshot) do check(row.finished==p.power_off[key].finished and math.abs(row.progress-p.power_off[key].progress)<1e-8,'machine progressed without electricity '..key) end
   p.power_pause_verified=true
  end
 end
 if event.tick==6000 then
  local inv=p.output.get_inventory(defines.inventory.chest);for i=1,#inv do if inv[i].valid_for_read then check(p.backup[i].transfer_stack(inv[i]),'could not preserve existing output before blockage') end;inv[i].set_stack{name='stone',count=100} end
 end
 if event.tick==7000 then p.blocked=remote.call('tp-mh7-assembler','inspect',p.machines.assembler) end
 if event.tick==7200 then local inv=p.output.get_inventory(defines.inventory.chest);for i=1,#inv do if inv[i].valid_for_read and inv[i].name=='stone' then inv[i].clear() end end end
 if event.tick%60==0 then
  local row={tick=event.tick,machines={},collected=p.output.get_inventory(defines.inventory.chest).get_contents()}
  for key,e in pairs(p.machines) do row.machines[key]=snap_machine(e) end
  local forge=remote.call('tp-mh7-pellet-decay','inspect_forge',p.machines.forge);local assembler=remote.call('tp-mh7-assembler','inspect',p.machines.assembler)
  if forge.last_conversion then p.forge_seen[tostring(forge.last_conversion.tick)]=forge.last_conversion end
  for _,r in ipairs(assembler.conversions) do p.assembler_seen[tostring(r.tick)..':'..r.station]=r end
  row.forge_completed=forge.completed;row.assembler_completed=assembler.completed;p.history[#p.history+1]=row
 end
 if event.tick==1800 or event.tick==3600 or event.tick==4440 or event.tick==7800 then
  for key,e in pairs(p.machines) do
   local path='tp-hydrogen-chain-review/'..key..'-tick'..event.tick..'.png';game.take_screenshot{player=game.players[1],surface=e.surface,position=e.position,resolution={900,900},zoom=3,daytime=0,show_gui=false,force_render=true,path=path};p.shots[#p.shots+1]={path=path,tick=event.tick,machine=key}
  end
  if event.tick==1800 then for _,probe in ipairs(p.purifier_probes) do
   local path='tp-hydrogen-chain-review/purifier-rotation-'..probe.r..'.png';game.take_screenshot{player=game.players[1],surface=probe.entity.surface,position=probe.entity.position,resolution={900,900},zoom=3,daytime=0,show_gui=false,force_render=true,path=path};p.shots[#p.shots+1]={path=path,tick=event.tick,rotation=probe.r}
  end end
 end
 if event.tick>=180 and event.tick<=2100 and (event.tick-180)%30==0 then
  local index=(event.tick-180)/30
  for _,site in ipairs(p.clocks) do
   if site.key~='purifier' then local path='tp-hydrogen-chain-review/clock-'..site.key..'-frame'..index..'.png';game.take_screenshot{player=game.players[1],surface=site.entity.surface,position=site.entity.position,resolution={900,900},zoom=3,daytime=0,show_gui=false,force_render=true,path=path};p.shots[#p.shots+1]={path=path,tick=event.tick,machine=site.key,kind='clock',crafting=site.entity.is_crafting()} end
  end
 end
 -- Probe the purifier eight ticks off the previous near-boundary phase. The
 -- cadence gate is unchanged; the failed boundary study remains preserved.
 if event.tick>=188 and event.tick<=2108 and (event.tick-188)%30==0 then
  local index=(event.tick-188)/30
  for _,site in ipairs(p.clocks) do if site.key=='purifier' then
   local path='tp-hydrogen-chain-review/clock-purifier-frame'..index..'.png';game.take_screenshot{player=game.players[1],surface=site.entity.surface,position=site.entity.position,resolution={900,900},zoom=3,daytime=0,show_gui=false,force_render=true,path=path};p.shots[#p.shots+1]={path=path,tick=event.tick,machine=site.key,kind='clock',crafting=site.entity.is_crafting()}
  end end
 end
 if event.tick==10000 then
  write('diagnostic',{history=p.history,forge_seen=p.forge_seen,assembler_seen=p.assembler_seen,blocked=p.blocked})
  for key,e in pairs(p.machines) do check(e.products_finished>0,'no actual production '..key) end
  local targets={{p.machines.crucible,p.machines.forge},{p.machines.forge,p.machines.assembler},{p.machines.fabricator,p.machines.assembler},{p.steel,p.machines.fabricator},{p.machines.assembler,p.output}}
  for i,e in ipairs(p.inserters) do check(e.pickup_target==targets[i][1] and e.drop_target==targets[i][2],'wrong actual inserter handoff '..i) end
  local amount=p.output.get_item_count(c.contained)+p.backup.get_item_count(c.contained);check(amount>=3,'no end-to-end contained stock');check(p.power_pause_verified,'power interruption not observed')
  local inv=p.output.get_inventory(defines.inventory.chest)
  for i=1,#inv do if inv[i].valid_for_read and inv[i].name==c.contained then
   local before=snapshot(inv[i]);local test=game.create_inventory(2);check(remote.call('tp-mh7-pellet-decay','unseal',inv[i],test[1],test[2]),'chain product would not unseal')
   local raw=snapshot(test[1]);local shell=snapshot(test[2]);check(raw.name==before.tags.mh7_raw_name and raw.quality==before.quality and math.abs(raw.health-before.health)<1e-6 and raw.spoil_tick-game.tick==before.tags.mh7_remaining_ticks,'chain product repaired/refreshed')
   p.unseal[#p.unseal+1]={before=before,raw=raw,shell=shell};test.destroy();break
  end end
  check(#p.unseal==1,'no final output available for state check')
  check(p.waste.output.get_item_count(c.inert)==1 and p.waste.output.get_item_count(c.contained)==0,'inert material jammed or was revived in real logistics')
  local waste=remote.call('tp-mh7-assembler','inspect',p.waste.assembler);local shells=0;for _,s in ipairs(waste.stock) do if s.name==c.shell then shells=shells+s.count end end
  shells=shells+p.waste.shells.get_item_count(c.shell);check(shells==1 and waste.completed==0,'inert disposal consumed a shell')
  local probes={};for _,probe in ipairs(p.purifier_probes) do check(probe.entity.products_finished>0 and probe.output.get_fluid_count('tp-mh7-review-purified-water')>0,'rotated purifier failed actual fluid handoff');probes[#probes+1]={rotation=probe.r,finished=probe.entity.products_finished,direction=probe.entity.direction} end
  write('production',{passed=true,external_inputs={'water','steel-plate','electricity'},intermediate_stock_injected_into_production_line=false,real_seven_machine_chain=true,contained_output_before_unseal=amount,history=p.history,forge_conversions=p.forge_seen,assembler_conversions=p.assembler_seen,power_pause_verified=true,blocked=p.blocked,unseal=p.unseal,purifier_rotations=probes,separate_native_expiration_and_inert_logistics_probe_passed=true,research_unlocks_verified=true,economy_balance_final=false})
  write('screenshots',{requested=p.shots,decoded=false});p.complete=true
 end
end)
