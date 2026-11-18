local names={'void-fusion-thruster','large-void-fusion-thruster'}
local reloaded=false
local function write(name,data)helpers.write_file('visual-power-native/'..name..'.json',helpers.table_to_json(data),false)end
local function snapshot(row,t)
 local value=remote.call('tp-visual-power-observer','snapshot',row.unit);value.tick=t;value.engine_tick=game.tick
 return value
end
local function power(row)
 row.power=assert(row.surface.create_entity{name='thruster-proof-power',position={12,-4},force='player'});row.power.energy=100000000
end
local function objects()return remote.call('tp-visual-power-observer','render_objects')end
script.on_load(function()reloaded=storage.saved or false end)
-- Dependency on tech-priests guarantees its on_init completed first. This is
-- an actual addon lifecycle, not a scenario that initializes before the mod.
script.on_init(function()
 if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true);remote.call('freeplay','set_disable_crashsite',true)end
 storage.start=game.tick;storage.rows={};storage.samples={};storage.initialized_after_main=remote.interfaces['tp-visual-power-observer']~=nil
 local force=game.forces.player;force.unlock_space_location('vulcanus')
 for i,name in ipairs(names)do
  local prefix='tp-'..name;assert(helpers.is_valid_animation_path(prefix..'-energy-v01')and helpers.is_valid_animation_path(prefix..'-plume-v01'),'Actual native animation stub unavailable')
  local platform=assert(force.create_space_platform{name='Visual draw proof '..name,planet='nauvis',starter_pack='space-platform-starter-pack'});platform.apply_starter_pack(true)
  local s=platform.surface;s.request_to_generate_chunks({0,0},3);s.force_generate_chunk_requests();local tiles={}
  for x=-4,20 do for y=-5,4 do tiles[#tiles+1]={name='space-platform-foundation',position={x,y}}end end;s.set_tiles(tiles)
  local void={};for x=12,20 do for y=1,100 do void[#void+1]={name='empty-space',position={x,y}}end end;s.set_tiles(void)
  if i==1 then local trim={};for x=-4,20 do for y=-5,4 do
   local hub=x>=-3 and x<=3 and y>=-3 and y<=3;local corridor=x>=4 and x<=16 and y>=-1 and y<=1;local ledges=x>=15 and x<=17 and y>=-4 and y<=0
   if not(hub or corridor or ledges)then trim[#trim+1]={name='empty-space',position={x,y}}end
  end end;s.set_tiles(trim)end
  local pos=i==1 and{16.5,.5}or{16,0};assert(s.can_place_entity{name=name,position=pos,direction=defines.direction.north,force='player'},'Invalid actual fore-ledged drive placement')
  local e=assert(s.create_entity{name=name,position=pos,direction=defines.direction.north,force='player',raise_built=true});e.destructible=false
  assert(s.create_entity{name='substation',position={13,-1},force='player'});local row={name=name,entity=e,unit=e.unit_number,surface=s,platform=platform,samples={}};storage.rows[i]=row
  local initial=snapshot(row,0);assert(initial.registered,'Main-mod initialization erased ordinary registration');row.initial=initial
  platform.schedule={current=1,records={{station='vulcanus',wait_conditions={{type='time',ticks=3600}}}}};platform.paused=false
 end
end)
script.on_event(defines.events.on_tick,function()
 local t=game.tick-storage.start
 if t%30==0 then for _,row in ipairs(storage.rows)do row.platform.destroy_asteroid_chunks{};for _,e in pairs(row.surface.find_entities_filtered{type='asteroid'})do e.destroy()end end end
 if t>=10 and t<=1650 and t%10==0 then for _,row in ipairs(storage.rows)do row.samples[#row.samples+1]=snapshot(row,t)end end
 if t==120 then for _,row in ipairs(storage.rows)do row.unpowered=snapshot(row,t);power(row)end end
 if t==600 then for _,row in ipairs(storage.rows)do row.working=snapshot(row,t)end end
 if t==720 then for _,row in ipairs(storage.rows)do row.precut=snapshot(row,t);row.power.destroy();row.power=nil end end
 if t==1100 then for _,row in ipairs(storage.rows)do row.powercut=snapshot(row,t);row.entity.clear_fluid_inside()end end
 if t==1140 then for _,row in ipairs(storage.rows)do power(row)end end
 if t==1260 then for _,row in ipairs(storage.rows)do row.restored=snapshot(row,t)end end
 if t==1320 then for _,row in ipairs(storage.rows)do row.platform.paused=true end end
 if t==1350 then for _,row in ipairs(storage.rows)do row.paused=snapshot(row,t)end end
 if t==1380 then for _,row in ipairs(storage.rows)do row.platform.paused=false end end
 if t==1440 then for _,row in ipairs(storage.rows)do row.pre_repair=snapshot(row,t);local sink=assert(row.surface.find_entities_filtered{name='void-fusion-thruster-power-sink'}[1]);row.removed_sink=sink.unit_number;sink.destroy{raise_destroy=true}end end
 if t==1470 then for _,row in ipairs(storage.rows)do row.repaired=snapshot(row,t)end end
 if t==1560 then
  storage.saved=true;storage.pre_save_objects=objects();for _,row in ipairs(storage.rows)do row.pre_save=snapshot(row,t)end
  write('pre-save',{rows=storage.rows and{storage.rows[1].pre_save,storage.rows[2].pre_save},render_objects=storage.pre_save_objects});game.auto_save('visual-power-coupling')
 end
 if t==1620 then for _,row in ipairs(storage.rows)do row.post_save_or_reload=snapshot(row,t)end;storage.post_save_objects=objects()end
 if t==1680 then for _,row in ipairs(storage.rows)do row.pre_removal=snapshot(row,t);row.entity.destroy{raise_destroy=true}end end
 if t==1710 then for _,row in ipairs(storage.rows)do row.removed=snapshot(row,t);row.remaining_sinks=#row.surface.find_entities_filtered{name='void-fusion-thruster-power-sink'}end;storage.after_removal_objects=objects()end
 if t==1740 then
  local result={status='ACTUAL_NATIVE_CAPTURE_REQUIRES_EXTERNAL_ASSERTIONS',reloaded=reloaded,initialized_after_main=storage.initialized_after_main,definitions={working_status=defines.entity_status.working,on_the_path=defines.space_platform_state.on_the_path},rows={},render_objects_before_save=storage.pre_save_objects,render_objects_after_save_or_reload=storage.post_save_objects,render_objects_after_removal=storage.after_removal_objects}
  for _,row in ipairs(storage.rows)do local value={};for _,k in ipairs({'name','unit','initial','unpowered','working','precut','powercut','restored','paused','pre_repair','removed_sink','repaired','pre_save','post_save_or_reload','pre_removal','removed','remaining_sinks','samples'})do value[k]=row[k]end;result.rows[#result.rows+1]=value end
  write(reloaded and'reload-results'or'continuous-results',result)
  if game.is_multiplayer()then game.tick_paused=true end
 end
end)
