-- Four orientation sprite-placement review; physical prototype connections are unchanged.
script.on_init(function()
  local s=game.surfaces.nauvis;s.request_to_generate_chunks({0,0},2);s.force_generate_chunk_requests()
  for _,e in pairs(s.find_entities_filtered{area={{-34,-15},{34,15}}}) do e.destroy() end
  local tiles={};for x=-34,34 do for y=-15,15 do tiles[#tiles+1]={name='refined-concrete',position={x,y}} end end
  s.set_tiles(tiles);s.destroy_decoratives{area={{-34,-15},{34,15}}};s.daytime=0;s.freeze_daytime=true
  storage.boilers={}
  for j,d in ipairs({defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west}) do
    local e=assert(s.create_entity{name='tech-priests-emergency-boiler',position={(j-2.5)*12,0},direction=d,force='player',create_build_effect_smoke=false})
    for i in ipairs(e.prototype.fluidbox_prototypes) do
      for _,c in ipairs(e.get_fluid_box_pipe_connections(i)) do
        local target=c.target_position;local dx=target.x-c.position.x;local dy=target.y-c.position.y
        if math.abs(dx)>math.abs(dy) then dx=dx>0 and 1 or -1;dy=0 else dy=dy>0 and 1 or -1;dx=0 end
        s.create_entity{name='pipe',position=target,force='player',snap_to_grid=true}
        s.create_entity{name='pipe',position={target.x+dx,target.y+dy},force='player',snap_to_grid=true}
      end
    end
    local terminal=assert(s.create_entity{name='constant-combinator',position={e.position.x+2.5,e.position.y+2.5},force='player',create_build_effect_smoke=false})
    for _,id in ipairs({defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}) do
      local a=assert(e.get_wire_connector(id,true));local b=assert(terminal.get_wire_connector(id,true));assert(a.connect_to(b,true))
    end
    storage.boilers[#storage.boilers+1]=e
  end
end)
script.on_event(defines.events.on_player_created,function(event)
  local p=game.get_player(event.player_index);p.set_controller{type=defines.controllers.god};p.teleport({0,10})
end)
script.on_event(defines.events.on_tick,function()
  if #game.players==0 then return end
  if game.tick==180 then
    for _,e in ipairs(storage.boilers) do
      for _,id in ipairs({defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}) do e.get_wire_connector(id,false).disconnect_all() end
    end
  end
  if game.tick~=120 and game.tick~=240 then return end
  local state=game.tick==120 and 'connected' or 'disconnected'
  local receipt={scope='Native visible wire attachment review only; no circuit behavior assertions',entities={}}
  for j,e in ipairs(storage.boilers) do
    local ports={}
    for i in ipairs(e.prototype.fluidbox_prototypes) do
      for _,c in ipairs(e.get_fluid_box_pipe_connections(i)) do ports[#ports+1]={index=i,position=c.position,target_position=c.target_position,connected_position=c.target and c.target.position or nil} end
    end
    receipt.entities[#receipt.entities+1]={direction=e.direction,position=e.position,ports=ports,red_connections=e.get_wire_connector(defines.wire_connector_id.circuit_red,false).real_connection_count,green_connections=e.get_wire_connector(defines.wire_connector_id.circuit_green,false).real_connection_count}
    game.take_screenshot{surface=e.surface,position=e.position,resolution={960,896},zoom=4,daytime=0,
      path='boiler-wire-final/'..state..'-'..({'north','east','south','west'})[j]..'.png',show_gui=false,show_entity_info=false,hide_clouds=true,hide_fog=true,force_render=true}
  end
  helpers.write_file('boiler-wire-final/'..state..'-physical-ports.json',helpers.table_to_json(receipt));if game.tick==240 then game.tick_paused=true end
end)
