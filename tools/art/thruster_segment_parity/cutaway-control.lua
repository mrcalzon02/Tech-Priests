local function ports(e)
 local out={}
 for i in ipairs(e.prototype.fluidbox_prototypes) do for _,c in ipairs(e.get_fluid_box_pipe_connections(i) or {}) do out[#out+1]={index=i,position=c.position,target_position=c.target_position,connected=c.target and c.target.name or false,connected_position=c.target and c.target.position or false} end end
 return out
end
script.on_init(function()
 storage.entities={};storage.pipes={};storage.probes={}
 local p=assert(game.forces.player.create_space_platform{name='Custom thruster platform notches',planet='nauvis',starter_pack='space-platform-starter-pack'});p.apply_starter_pack(true);local s=p.surface;storage.surface=s
 s.request_to_generate_chunks({0,0},4);s.force_generate_chunk_requests();s.daytime=0;s.freeze_daytime=true
 local deck={};for x=-7,55 do for y=-12,8 do deck[#deck+1]={name='space-platform-foundation',position={x,y}} end end;s.set_tiles(deck)
 local names={'cutaway-baseline-hydrogen-thruster','hydrogen-thruster','cutaway-baseline-thetazine-thruster','thetazine-thruster'}
 for i,name in ipairs(names) do
  local cx=(i-1)*16;local proto=prototypes.entity[name];local odd=proto.tile_width%2==1;local pos={x=cx+(odd and .5 or 0),y=proto.tile_height%2==1 and .5 or 0}
  local half=proto.tile_width/2;local first=math.floor(pos.x-half);local last=math.ceil(pos.x+half)-1;local baseline=name:find('baseline',1,true)
  local edge=baseline and math.ceil(pos.y+proto.tile_height/2)-1 or 0
  local tiles={};for x=first,last do for y=edge+1,100 do
   tiles[#tiles+1]={name='empty-space',position={x,y}}
  end end;s.set_tiles(tiles)
  local legal=s.can_place_entity{name=name,position=pos,direction=defines.direction.north,force='player'}
  local e=assert(s.create_entity{name=name,position=pos,direction=defines.direction.north,force='player',create_build_effect_smoke=false});storage.entities[#storage.entities+1]=e
  for _,c in ipairs(ports(e)) do local target=c.target_position;local sign=target.x>pos.x and 1 or -1
   for j=0,1 do storage.pipes[#storage.pipes+1]=assert(s.create_entity{name='pipe',position={target.x+j*sign,target.y},force='player',create_build_effect_smoke=false}) end
  end
  storage.probes[#storage.probes+1]={name=name,can_place=legal,position=e.position,notch={first_x=first,last_x=last,first_void_y=edge+1},ports=ports(e)}
 end
 storage.edge_sweep={}
 for index,name in ipairs({'hydrogen-thruster','thetazine-thruster'}) do
  local proto=prototypes.entity[name];local odd=proto.tile_width%2==1;local cx=96+index*20;local pos={cx+(odd and .5 or 0),proto.tile_height%2==1 and .5 or 0}
  for edge=-3,3 do
   local t={};for x=cx-7,cx+7 do for y=-12,100 do t[#t+1]={name=y<=edge and 'space-platform-foundation' or 'empty-space',position={x,y}} end end;storage.surface.set_tiles(t)
   storage.edge_sweep[#storage.edge_sweep+1]={name=name,last_foundation_y=edge,can_place=storage.surface.can_place_entity{name=name,position=pos,direction=defines.direction.north,force='player'}}
  end
 end
end)
script.on_event(defines.events.on_player_created,function(event)
 local p=game.get_player(event.player_index);local c=p.character;p.set_controller{type=defines.controllers.god};if c and c.valid then c.destroy() end;p.teleport({16,1.5},storage.surface);p.zoom=1.25
end)
local function capture(label)
 storage.surface.platform.destroy_asteroid_chunks{};for _,e in pairs(storage.surface.find_entities_filtered{type='asteroid'}) do e.destroy() end
 local receipt={state=label,entities={}}
 for _,e in ipairs(storage.entities) do
  game.take_screenshot{player=game.players[1],surface=storage.surface,position={e.position.x,1.5},resolution={900,1100},zoom=3,daytime=0,show_gui=false,force_render=true,path='custom-thruster-cutaway-v3/'..e.name..'-'..label..'.png'}
  receipt.entities[#receipt.entities+1]={name=e.name,position=e.position,ports=ports(e)}
 end
 helpers.write_file('custom-thruster-cutaway-v3/'..label..'-readback.json',helpers.table_to_json(receipt))
end
script.on_event(defines.events.on_tick,function(event)
 if event.tick==60 then capture('connected');helpers.write_file('custom-thruster-cutaway-v3/placement-probes.json',helpers.table_to_json({actual_sites=storage.probes,edge_sweep=storage.edge_sweep})) end
 if event.tick==90 then for _,e in ipairs(storage.pipes) do if e.valid then e.destroy() end end end
 if event.tick==120 then capture('disconnected') end
 if event.tick==130 then game.auto_save('thruster-edge-quality-seed') end
 if event.tick==145 then game.take_screenshot{player=game.players[1],surface=storage.surface,position={24,0},resolution={1400,1000},zoom=.6,daytime=0,show_gui=false,force_render=true,path='custom-thruster-cutaway-v3/whole-deck.png'} end
 if event.tick==150 then game.tick_paused=true end
end)
