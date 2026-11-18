local names=CAPTURE_FAMILIES_LUA
local binding_json=[==[CAPTURE_BINDINGS_JSON]==]
local function snapshot(row)
 local e=row.entity
 local sinks=row.surface.find_entities_filtered{name='void-fusion-thruster-power-sink'}
 local value={game_tick=game.tick,name=e.name,position=e.position,status=e.status,fluid1=e.get_fluid(1),fluid2=e.get_fluid(2),
  platform_speed=row.platform.speed,platform_state=row.platform.state,platform_paused=row.platform.paused,
  power_watts=sinks[1]and sinks[1].power_usage*60 or 0}
 if remote.interfaces['tp-fusion-capture-observer']then
  value.visuals=remote.call('tp-fusion-capture-observer','snapshot',e.unit_number)
 end
 return value
end
local function shot(row,tick,label,zoom,resolution)
 local e=row.entity
 local file='fusion-capture-native/'..e.name..'/'..label..'/frame-'..string.format('%04d',tick)..'.png'
 game.take_screenshot{player=game.players[1],surface=row.surface,
  position={e.position.x,e.position.y+2.5},resolution=resolution or{640,1100},zoom=zoom or 2,
  daytime=label=='night'and .5 or 0,show_gui=false,force_render=true,path=file}
 row.shots[#row.shots+1]={tick=tick,label=label,file=file,snapshot=snapshot(row)}
end
local function setup()
 storage.rows={};storage.start=game.tick
 if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true);remote.call('freeplay','set_disable_crashsite',true)end
 local force=game.forces.player;force.unlock_space_location('vulcanus')
 for _,name in ipairs(names)do
  local p=assert(force.create_space_platform{name='Fusion capture '..name,planet='nauvis',starter_pack='space-platform-starter-pack'})
  p.apply_starter_pack(true);local s=p.surface;s.request_to_generate_chunks({0,0},3);s.force_generate_chunk_requests();s.daytime=0;s.freeze_daytime=true
  local tiles={};for x=-4,20 do for y=-5,4 do tiles[#tiles+1]={name='space-platform-foundation',position={x,y}}end end;s.set_tiles(tiles)
  local void={};for x=12,20 do for y=1,100 do void[#void+1]={name='empty-space',position={x,y}}end end;s.set_tiles(void)
  if name=='void-fusion-thruster'then
   local trim={};for x=-4,20 do for y=-5,4 do
    local hub=x>=-3 and x<=3 and y>=-3 and y<=3
    local corridor=x>=4 and x<=16 and y>=-1 and y<=1
    local ledges=x>=15 and x<=17 and y>=-4 and y<=0
    if not(hub or corridor or ledges)then trim[#trim+1]={name='empty-space',position={x,y}}end
   end end;s.set_tiles(trim)
  end
  local pos=name=='void-fusion-thruster'and{16.5,.5}or{16,0}
  assert(s.can_place_entity{name=name,position=pos,direction=defines.direction.north,force='player'},'Illegal native capture mount '..name)
  local e=assert(s.create_entity{name=name,position=pos,direction=defines.direction.north,force='player',raise_built=true,create_build_effect_smoke=false});e.destructible=false
  local sub=assert(s.create_entity{name='substation',position={13,-1},force='player'});sub.destructible=false
  local power=assert(s.create_entity{name='thruster-proof-power',position={12,-4},force='player'});power.energy=100000000;power.destructible=false
  local row={entity=e,surface=s,platform=p,power=power,shots={}};storage.rows[#storage.rows+1]=row
  p.schedule={current=1,records={{station='vulcanus',wait_conditions={{type='time',ticks=60}}},
   {station='nauvis',wait_conditions={{type='time',ticks=60}}}}};p.paused=false
 end
 -- Scenario on_init runs before some mod initialization. Place entities only
 -- after all on_init handlers so the ordinary build registry keeps its records.
 for _,player in pairs(game.players)do
  local character=player.character;player.set_controller{type=defines.controllers.god}
  if character and character.valid then character.destroy()end
  local row=storage.rows[1];player.teleport(row.entity.position,row.surface);player.zoom=1
 end
end
script.on_init(function()storage.pending_setup=true end)
script.on_event(defines.events.on_player_created,function(event)
 local player=game.get_player(event.player_index);local character=player.character
 player.set_controller{type=defines.controllers.god};if character and character.valid then character.destroy()end
 local row=storage.rows and storage.rows[1]
 if row then player.teleport(row.entity.position,row.surface);player.zoom=1 end
end)
script.on_event(defines.events.on_tick,function(event)
 if storage.pending_setup then storage.pending_setup=false;setup()end
 local t=event.tick-storage.start
 if t%30==0 then for _,row in ipairs(storage.rows)do
  row.platform.destroy_asteroid_chunks{};for _,e in pairs(row.surface.find_entities_filtered{type='asteroid'})do e.destroy()end
 end end
 if t>=480 and t<=735 then for _,row in ipairs(storage.rows)do shot(row,t,'clock')end end
 local states={[90]='startup',[750]='working',[780]='night',[810]='paused-powered',[1180]='idle',[1420]='restart'}
 if states[t]then for _,row in ipairs(storage.rows)do shot(row,t,states[t],3,{1000,1650})end end
 if t==800 then for _,row in ipairs(storage.rows)do row.platform.paused=true end end
 if t==820 then for _,row in ipairs(storage.rows)do row.platform.paused=false end end
 if t==830 then for _,row in ipairs(storage.rows)do row.platform.paused=true;row.power.destroy();row.power=nil;row.entity.clear_fluid_inside()end end
 -- The real sink can retain30MJ; wait longer than its300tick worst-case
 -- drain at6MW before observing idle or restoring the actual supply.
 if t==1220 then for _,row in ipairs(storage.rows)do
  row.power=assert(row.surface.create_entity{name='thruster-proof-power',position={12,-4},force='player'});row.power.energy=100000000;row.platform.paused=false
 end end
 if t==1460 then
  local result={status='CAPTURED_REQUIRES_CLOCK_DECODE_AND_ACTUAL_IMAGE_REVIEW',bindings=helpers.json_to_table(binding_json),rows={}}
  for _,row in ipairs(storage.rows)do result.rows[#result.rows+1]={name=row.entity.name,shots=row.shots,final=snapshot(row),native_cut_y=row.entity.name=='void-fusion-thruster'and .5 or 1}end
  helpers.write_file('fusion-capture-native/receipt.json',helpers.table_to_json(result),false);game.tick_paused=true
 end
end)
