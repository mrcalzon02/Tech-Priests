local function levels(amount)
 local e=storage.entity
 if amount==0 then e.clear_fluid_inside();return end
 e.set_fluid(1,{name='thetazine-fuel',amount=e.get_fluid_capacity(1)*amount});e.set_fluid(2,{name='water',amount=e.get_fluid_capacity(2)*amount})
end
script.on_init(function()
 local p=assert(game.forces.player.create_space_platform{name='V04 cold-state graphics fixture',planet='nauvis',starter_pack='space-platform-starter-pack'});p.apply_starter_pack(true);local s=p.surface;storage.surface=s;s.request_to_generate_chunks({0,0},3);s.force_generate_chunk_requests();s.daytime=0;s.freeze_daytime=true
 local tiles={};for x=-8,24 do for y=-12,8 do tiles[#tiles+1]={name='space-platform-foundation',position={x,y}} end end;s.set_tiles(tiles);local void={};for x=14,18 do for y=1,100 do void[#void+1]={name='empty-space',position={x,y}} end end;s.set_tiles(void)
 storage.entity=assert(s.create_entity{name='thetazine-v04-visual-pilot',position={16.5,.5},direction=defines.direction.north,force='player',create_build_effect_smoke=false});storage.entity.destructible=false;storage.pipes={};storage.states={}
 for i in ipairs(storage.entity.prototype.fluidbox_prototypes) do for _,c in ipairs(storage.entity.get_fluid_box_pipe_connections(i) or {}) do local t=c.target_position;local sign=t.x>16.5 and 1 or -1;for j=0,1 do local pipe=assert(s.create_entity{name='pipe',position={t.x+j*sign,t.y},force='player',create_build_effect_smoke=false});pipe.destructible=false;storage.pipes[#storage.pipes+1]=pipe end end end
 levels(.85);game.forces.player.unlock_space_location('vulcanus');p.schedule={current=1,records={{station='vulcanus',wait_conditions={{type='time',ticks=3600}}}}};p.paused=false
end)
script.on_event(defines.events.on_player_created,function(event) local p=game.get_player(event.player_index);local c=p.character;p.set_controller{type=defines.controllers.god};if c and c.valid then c.destroy() end;p.teleport({16.5,1.5},storage.surface);p.zoom=1.4 end)
script.on_event(defines.events.on_tick,function(event)
 local tick=event.tick;local s=storage.surface
 if tick%30==0 then s.platform.destroy_asteroid_chunks{};for _,e in pairs(s.find_entities_filtered{type='asteroid'}) do e.destroy() end end
 if tick==160 then s.platform.paused=true end
 if tick==400 then s.platform.paused=false end
 levels(tick>=160 and tick<400 and 0 or .85)
 if tick==340 then for _,e in ipairs(storage.pipes) do if e.valid then e.destroy() end end end
 local names={[120]='working-connected',[140]='working-connected',[300]='idle-connected',[320]='idle-connected',[360]='idle-disconnected',[380]='idle-disconnected',[540]='restart-disconnected',[560]='restart-disconnected'}
 if names[tick] then
  local ports={};local e=storage.entity;for i in ipairs(e.prototype.fluidbox_prototypes) do for _,c in ipairs(e.get_fluid_box_pipe_connections(i) or {}) do ports[#ports+1]={position=c.position,target_position=c.target_position,connected=c.target and c.target.name or false} end end
  local file='thetazine-v04-states/'..names[tick]..'-'..tick..'.png';game.take_screenshot{player=game.players[1],surface=s,position={16.5,3.583333333333},resolution={1000,1700},zoom=3,daytime=0,show_gui=false,force_render=true,path=file};storage.states[#storage.states+1]={label=names[tick],tick=tick,file=file,entity_status=e.status,ports=ports,fluid1=e.get_fluid(1),fluid2=e.get_fluid(2)}
 end
 if tick==600 then helpers.write_file('thetazine-v04-states/receipt.json',helpers.table_to_json({source_native_sha256='REVIEW_SOURCE_NATIVE_SHA256',states=storage.states,scope='Graphics-only current source: working, stopped/idle, disconnected caps and restart appearance. Review route/fluids are display stimuli, no performance/consumption/behavior assertions.'}));game.tick_paused=true end
end)
