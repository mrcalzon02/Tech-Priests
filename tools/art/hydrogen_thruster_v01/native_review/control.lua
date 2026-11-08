local names={'hydrogen-model-legacy','hydrogen-thruster','hydrogen-model-run'}
local function ports(e)
 local out={}
 for i in ipairs(e.prototype.fluidbox_prototypes) do
  for _,c in ipairs(e.get_fluid_box_pipe_connections(i) or {}) do out[#out+1]={index=i,position=c.position,target_position=c.target_position,connected_name=c.target and c.target.name or nil} end
 end
 return out
end
script.on_init(function()
 local platform=assert(game.forces.player.create_space_platform{name='Hydrogen model visual jig',planet='nauvis',starter_pack='space-platform-starter-pack'});platform.apply_starter_pack(true)
 local s=platform.surface;s.request_to_generate_chunks({0,0},3);s.request_to_generate_chunks({80,0},3);s.force_generate_chunk_requests();s.daytime=0;s.freeze_daytime=true
 for _,e in pairs(s.find_entities_filtered{area={{-25,-10},{25,12}}}) do if e.type~='space-platform-hub' then e.destroy() end end
 local tiles={};for x=-30,130 do for y=-12,12 do tiles[#tiles+1]={name=y<=1 and 'space-platform-foundation' or 'empty-space',position={x,y}} end end;s.set_tiles(tiles)
 storage.entities={};storage.pipes={};storage.surface=s
 for i,name in ipairs(names) do
  local e=assert(s.create_entity{name=name,position={({-21,-9,9})[i],0},direction=defines.direction.north,force='player',create_build_effect_smoke=false});storage.entities[#storage.entities+1]=e
  for _,c in ipairs(ports(e)) do
   local t=c.target_position;local dx=t.x-e.position.x;dx=dx>0 and 1 or -1
   for j=0,1 do local pipe=assert(s.create_entity{name='pipe',position={t.x+j*dx,t.y},force='player',create_build_effect_smoke=false});storage.pipes[#storage.pipes+1]=pipe end
  end
 end
 storage.poses={}
 for i=0,6 do
  local e=assert(s.create_entity{name='hydrogen-model-pose-'..i,position={48+i*12,0},direction=defines.direction.north,force='player',create_build_effect_smoke=false});storage.poses[#storage.poses+1]=e
  for _,c in ipairs(ports(e)) do
   local t=c.target_position;local dx=t.x>e.position.x and 1 or -1
   for j=0,1 do storage.pipes[#storage.pipes+1]=assert(s.create_entity{name='pipe',position={t.x+j*dx,t.y},force='player',create_build_effect_smoke=false}) end
  end
 end
end)
script.on_event(defines.events.on_player_created,function(event)
 local p=game.get_player(event.player_index);local old=p.character;p.set_controller{type=defines.controllers.god};if old and old.valid then old.destroy() end;p.teleport({0,-6},storage.surface)
end)
local function capture(state)
 local p=game.players[1];if not p then return end;local receipt={state=state,tick=game.tick,scope='Graphics-only forced idle/run display clones; no propellant, thrust, travel, consumption or behavior assertions.',entities={}}
 storage.surface.platform.destroy_asteroid_chunks{};for _,e in pairs(storage.surface.find_entities_filtered{type='asteroid'}) do e.destroy() end
 for i,e in ipairs(storage.entities) do
  local label=({'legacy','candidate-idle','candidate-run'})[i]
  game.take_screenshot{player=p,surface=storage.surface,position={e.position.x,1.5},resolution={800,1000},zoom=3,daytime=0,show_gui=false,force_render=true,path='hydrogen-model-review/'..label..'-'..state..'.png'}
  receipt.entities[#receipt.entities+1]={label=label,name=e.name,position=e.position,direction=e.direction,ports=ports(e)}
 end
 helpers.write_file('hydrogen-model-review/'..state..'-receipt.json',helpers.table_to_json(receipt))
end
script.on_event(defines.events.on_tick,function(event)
 if event.tick==60 then
  capture('connected')
  for i,e in ipairs(storage.poses) do game.take_screenshot{player=game.players[1],surface=storage.surface,position={e.position.x,1.5},resolution={800,1000},zoom=3,daytime=0,show_gui=false,force_render=true,path='hydrogen-model-review/frozen-source-pose-'..(i-1)..'.png'} end
 end
 local frames={[60]=1,[66]=2,[71]=3,[77]=4,[82]=5,[88]=6,[93]=7};local idx=frames[event.tick]
 if idx then local e=storage.entities[3];game.take_screenshot{player=game.players[1],surface=storage.surface,position={e.position.x,1.5},resolution={800,1000},zoom=3,daytime=0,show_gui=false,force_render=true,path='hydrogen-model-review/run-loop-'..idx..'.png'} end
 if event.tick==105 then local e=storage.entities[3];game.take_screenshot{player=game.players[1],surface=storage.surface,position={e.position.x,1.5},resolution={800,1000},zoom=3,daytime=.5,show_gui=false,force_render=true,path='hydrogen-model-review/run-night.png'} end
 if event.tick==120 then for _,e in ipairs(storage.pipes) do if e.valid then e.destroy() end end end
 if event.tick==150 then capture('disconnected') end
 if event.tick==180 then game.tick_paused=true end
end)
