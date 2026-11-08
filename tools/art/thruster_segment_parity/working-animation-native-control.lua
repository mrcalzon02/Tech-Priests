script.on_init(function()
 local p=assert(game.forces.player.create_space_platform{name='Thetazine V02 actual new model preview',planet='nauvis',starter_pack='space-platform-starter-pack'});p.apply_starter_pack(true);local s=p.surface;storage.surface=s;s.request_to_generate_chunks({0,0},3);s.force_generate_chunk_requests();s.daytime=0;s.freeze_daytime=true
 local tiles={};for x=-8,24 do for y=-12,8 do tiles[#tiles+1]={name='space-platform-foundation',position={x,y}} end end;s.set_tiles(tiles)
 local void={};for x=14,18 do for y=1,100 do void[#void+1]={name='empty-space',position={x,y}} end end;s.set_tiles(void)
 local pos={16.5,.5};assert(s.can_place_entity{name='thetazine-v02-visual-pilot',position=pos,direction=defines.direction.north,force='player'},'New-model native site is not legal')
 local e=assert(s.create_entity{name='thetazine-v02-visual-pilot',position=pos,direction=defines.direction.north,force='player',create_build_effect_smoke=false});storage.entity=e
 for i in ipairs(e.prototype.fluidbox_prototypes) do for _,c in ipairs(e.get_fluid_box_pipe_connections(i) or {}) do local t=c.target_position;local sign=t.x>e.position.x and 1 or -1;for j=0,1 do s.create_entity{name='pipe',position={t.x+j*sign,t.y},force='player',create_build_effect_smoke=false} end end end
 e.set_fluid(1,{name='thetazine-fuel',amount=1000})
 e.set_fluid(2,{name='water',amount=1000})
 game.forces.player.unlock_space_location('vulcanus')
 p.schedule={current=1,records={{station='vulcanus',wait_conditions={{type='time',ticks=3600}}}}}
 p.paused=false
 rendering.draw_text{text='Thetazine V02 — actual new model / mechanical study',surface=s,target={16.5,-4},color={1,1,1},alignment='center',scale=.7}
end)
script.on_event(defines.events.on_player_created,function(event)
 local p=game.get_player(event.player_index);local c=p.character;p.set_controller{type=defines.controllers.god};if c and c.valid then c.destroy() end;p.teleport({16.5,1.5},storage.surface);p.zoom=1.6
end)
script.on_event(defines.events.on_tick,function(event)
 local tick=event.tick
 if tick==55 then storage.surface.platform.destroy_asteroid_chunks{};for _,e in pairs(storage.surface.find_entities_filtered{type='asteroid'}) do e.destroy() end end
 if tick>=180 and tick<=306 and tick%2==0 then game.take_screenshot{player=game.players[1],surface=storage.surface,position={16.5,1.5},resolution={900,1100},zoom=3,daytime=0,show_gui=false,force_render=true,path='thetazine-v02-native-working-loop/frame-'..string.format('%03d',tick)..'.png'} end
 if tick==310 then
  local e=storage.entity;local ports={};for i in ipairs(e.prototype.fluidbox_prototypes) do for _,c in ipairs(e.get_fluid_box_pipe_connections(i) or {}) do ports[#ports+1]={position=c.position,target_position=c.target_position,connected=c.target and c.target.name or false,connected_position=c.target and c.target.position or false} end end
  helpers.write_file('thetazine-v02-native-working-loop/receipt.json',helpers.table_to_json({ports=ports,position=e.position,scope='Review-only actual working display: propellant supplied and an ephemeral route selected solely to view graphics. No fuel-consumption, thrust-performance or behavior assertions. Frame-counter layer is temporary and uses the same 64-frame timing as body. Decode actual screenshots before claiming any native clock progression.'}))
  game.tick_paused=true
 end
end)
