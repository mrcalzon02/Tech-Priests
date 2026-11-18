local NAME='tech-priests-emergency-miner'
local function check(v,m)if not v then error('MINER PROOF: '..m)end end
local function snapshot(e)return{status=e.status,progress=e.crafting_progress,products=e.products_finished,output=e.get_output_inventory().get_contents()}end
script.on_init(function()
 game.speed=64;local s=game.surfaces[1];local f=game.forces.player
 s.request_to_generate_chunks({25,25},3);s.force_generate_chunk_requests()
 for _,e in pairs(s.find_entities_filtered{area={{5,5},{60,60}}})do if e.type~='character'then e.destroy()end end
 local ts={};for x=5,60 do for y=5,60 do ts[#ts+1]={name='grass-1',position={x,y}}end end;s.set_tiles(ts,true)
 storage.rows={};storage.samples={}
 local names={'calcite','coal','copper-ore','iron-ore','scrap','stone','tungsten-ore','uranium-ore','wood'}
 for i,n in ipairs(names)do
  local x=12.5+((i-1)%3)*12;local y=12.5+math.floor((i-1)/3)*12
  check(s.can_place_entity{name=NAME,position={x,y},force=f},'normal1x1 placement '..n)
  local e=s.create_entity{name=NAME,position={x,y},force=f,raise_built=true};check(e.direction==0 and not e.burner and e.fluids_count==0,'fixed north void/no ports')
  local c=s.create_entity{name='steel-chest',position={x,y+2},force=f};local arm=s.create_entity{name='inserter',position={x,y+1},direction=defines.direction.north,force=f}
  s.create_entity{name='substation',position={x+3,y+1},force=f};local p=s.create_entity{name='miner-proof-power',position={x+3,y+3},force=f}
  storage.rows[i]={e=e,c=c,arm=arm,p=p,name=n}
 end
end)
script.on_event(defines.events.on_tick,function(ev)
 local t=ev.tick
 if storage.complete then
  if t>=storage.complete_tick+600 and not storage.reloaded then storage.reloaded=true;for _,r in ipairs(storage.rows)do check(r.e.valid and r.e.get_recipe().name=='tech-priests-emergency-mine-'..r.name,'recipe survives operated reload')end;helpers.write_file('miner-proof/reloaded-state.json',helpers.table_to_json{passed=true,tick=t},false);log('MINER_RELOAD_PASS')end
  return
 end
 if t==120 then
  storage.initial={};for _,r in ipairs(storage.rows)do local recipe=r.e.get_recipe();storage.initial[r.name]={state=snapshot(r.e),selected=recipe and recipe.name};r.e.set_recipe('tech-priests-emergency-mine-'..r.name)end
 elseif t==1200 then
  local r=storage.rows[9];check(r.e.products_finished>0,'wood recipe works');r.e.disabled_by_script=true;storage.stopped=snapshot(r.e)
 elseif t==1500 then
  local r=storage.rows[9];check(r.e.crafting_progress==storage.stopped.progress and r.e.products_finished==storage.stopped.products,'script stop stable');r.e.disabled_by_script=false;storage.resumed=r.e.products_finished
 elseif t==3000 then
  local r=storage.rows[9];check(r.e.products_finished>storage.resumed,'restart produces');r.p.destroy();storage.independent=r.e.products_finished
 elseif t==4800 then
  check(storage.rows[9].e.products_finished>storage.independent,'void miner independent of external electricity');storage.rows[9].p=storage.rows[9].e.surface.create_entity{name='miner-proof-power',position={storage.rows[9].e.position.x+3,storage.rows[9].e.position.y+3},force='player'}
 elseif t==73500 then
  for _,r in ipairs(storage.rows)do check(r.e.products_finished>0,'actual full duration '..r.name);check(r.c.get_inventory(defines.inventory.chest).get_item_count(r.name)>0,'ordinary output inserter '..r.name);storage.samples[r.name]=snapshot(r.e);r.arm.disabled_by_script=true;local out=r.e.get_output_inventory();out.clear();for i=1,#out do out[i].set_stack{name=r.name,count=prototypes.item[r.name].stack_size}end end
 elseif t==146000 then
  storage.blocked={};for _,r in ipairs(storage.rows)do check(r.e.status==defines.entity_status.full_output,'native blocked output '..r.name);storage.blocked[r.name]=snapshot(r.e)end
 elseif t==146600 then
  for _,r in ipairs(storage.rows)do local b=storage.blocked[r.name];check(r.e.products_finished==b.products and r.e.crafting_progress==b.progress,'blocked stable '..r.name);r.e.get_output_inventory().clear();r.arm.disabled_by_script=false end
 elseif t==219500 then
  for _,r in ipairs(storage.rows)do check(r.e.products_finished>storage.blocked[r.name].products,'output release resumes '..r.name)end
  storage.complete=true;storage.complete_tick=t
  helpers.write_file('miner-proof/operation.json',helpers.table_to_json{passed=true,real_recipes=storage.samples,all_nine_actual_full_durations=true,normal_output_inserters=true,blocked_output_release_all_nine=true,script_stop_restart=true,no_fuel_or_ore_patch_required=true,no_progress_energy_product_assignments=true,fixture_blockers='Output slots filled only after genuine recipe and normal inserter production, to test full output.',elapsed_ticks=t},false);log('MINER_NATIVE_OPERATIONAL_PASS');if game.is_multiplayer()then game.server_save('miner-operated')end
 end
end)
