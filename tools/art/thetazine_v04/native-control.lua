local function supplied_levels(fuel,water)
 local e=storage.entity
 e.set_fluid(1,{name='thetazine-fuel',amount=e.get_fluid_capacity(1)*fuel})
 e.set_fluid(2,{name='water',amount=e.get_fluid_capacity(2)*water})
end
script.on_init(function()
 local p=assert(game.forces.player.create_space_platform{name='Thetazine V04 - real native flame review',planet='nauvis',starter_pack='space-platform-starter-pack'});p.apply_starter_pack(true);local s=p.surface;storage.surface=s;s.request_to_generate_chunks({0,0},3);s.force_generate_chunk_requests();s.daytime=0;s.freeze_daytime=true
 local tiles={};for x=-8,24 do for y=-12,8 do tiles[#tiles+1]={name='space-platform-foundation',position={x,y}} end end;s.set_tiles(tiles)
 local void={};for x=14,18 do for y=1,100 do void[#void+1]={name='empty-space',position={x,y}} end end;s.set_tiles(void)
 local pos={16.5,.5};assert(s.can_place_entity{name='thetazine-v04-visual-pilot',position=pos,direction=defines.direction.north,force='player'},'V04 native site illegal')
 local e=assert(s.create_entity{name='thetazine-v04-visual-pilot',position=pos,direction=defines.direction.north,force='player',create_build_effect_smoke=false});storage.entity=e
 for i in ipairs(e.prototype.fluidbox_prototypes) do for _,c in ipairs(e.get_fluid_box_pipe_connections(i) or {}) do local t=c.target_position;local sign=t.x>e.position.x and 1 or -1;for j=0,1 do s.create_entity{name='pipe',position={t.x+j*sign,t.y},force='player',create_build_effect_smoke=false} end end end
 supplied_levels(.85,.85);game.forces.player.unlock_space_location('vulcanus');p.schedule={current=1,records={{station='vulcanus',wait_conditions={{type='time',ticks=3600}}}}};p.paused=false
 storage.samples={};rendering.draw_text{text='Thetazine V04 - joined pipes / real native flame',surface=s,target={16.5,-4.5},color={1,1,1},alignment='center',scale=.6}
end)
script.on_event(defines.events.on_player_created,function(event)
 local p=game.get_player(event.player_index);local c=p.character;p.set_controller{type=defines.controllers.god};if c and c.valid then c.destroy() end;p.teleport({16.5,1.5},storage.surface);p.zoom=1.4
end)
script.on_event(defines.events.on_tick,function(event)
 local tick=event.tick;local fuel,water=.85,.85;local label='balanced'
 if tick>=360 and tick<480 then fuel=.85;water=.25;label='fuel-heavy' elseif tick>=480 and tick<600 then fuel=.25;water=.85;label='water-heavy' elseif tick>=600 then label='night';storage.surface.daytime=.5 end
 supplied_levels(fuel,water)
 if tick==55 then storage.surface.platform.destroy_asteroid_chunks{};for _,e in pairs(storage.surface.find_entities_filtered{type='asteroid'}) do e.destroy() end end
 if tick>=180 and tick<=306 and tick%2==0 then game.take_screenshot{player=game.players[1],surface=storage.surface,position={16.5,3.583333333333},resolution={1000,1700},zoom=3,daytime=0,show_gui=false,force_render=true,path='thetazine-v04-native/body-loop/frame-'..string.format('%03d',tick)..'.png'} end
 if (tick>=320 and tick<=334 or tick>=420 and tick<=434 or tick>=540 and tick<=554 or tick>=650 and tick<=664) and tick%2==0 then
  game.take_screenshot{player=game.players[1],surface=storage.surface,position={16.5,12.5},resolution={1100,1800},zoom=1.1,daytime=label=='night' and .5 or 0,show_gui=false,force_render=true,path='thetazine-v04-native/'..label..'/frame-'..string.format('%03d',tick)..'.png'}
  storage.samples[#storage.samples+1]={tick=tick,label=label,requested_fuel_fraction=fuel,requested_water_fraction=water,fluid1=storage.entity.get_fluid(1),fluid2=storage.entity.get_fluid(2),fuel_capacity=storage.entity.get_fluid_capacity(1),water_capacity=storage.entity.get_fluid_capacity(2)}
 end
 if tick==670 then
  local e=storage.entity;local ports={};for i in ipairs(e.prototype.fluidbox_prototypes) do for _,c in ipairs(e.get_fluid_box_pipe_connections(i) or {}) do ports[#ports+1]={position=c.position,target_position=c.target_position,connected=c.target and c.target.name or false,connected_position=c.target and c.target.position or false} end end
  helpers.write_file('thetazine-v04-native/receipt.json',helpers.table_to_json({ports=ports,position=e.position,samples=storage.samples,scope='Isolated visual review only. Native shader receives actual game thrust/fuel/oxidizer uniforms; source fluid levels supplied solely to view colours. No force, consumption, performance or behavior assertions. Body/glow counters must be independently decoded.'}));game.tick_paused=true
 end
end)
