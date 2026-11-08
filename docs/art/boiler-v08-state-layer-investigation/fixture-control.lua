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
    storage.boilers[#storage.boilers+1]=e
  end
end)
script.on_event(defines.events.on_player_created,function(event)
  local p=game.get_player(event.player_index);p.set_controller{type=defines.controllers.god};p.teleport({0,10})
end)
script.on_event(defines.events.on_tick,function()
  if #game.players==0 then return end
  -- Supply visual-state fixtures directly; do not test fuel throughput or economy.
  if game.tick>=300 and game.tick<600 then
    for _,e in ipairs(storage.boilers) do
      if game.tick==300 then e.insert{name='coal',count=5} end
      e.set_fluid(1,{name='water',amount=1000,temperature=15})
      e.clear_fluid(2)
    end
  end
  if game.tick==600 then for _,e in ipairs(storage.boilers) do e.clear_items_inside();e.burner.remaining_burning_fuel=0 end end
  if game.tick~=120 and game.tick~=240 and game.tick~=420 and game.tick~=480 and game.tick~=720 and game.tick~=780 then return end
  local receipt={scope='Cold/working sprite rendering only; direct fixture supply, no behavior assertions',tick=game.tick,entities={}}
  for j,e in ipairs(storage.boilers) do
    local ports={}
    for i in ipairs(e.prototype.fluidbox_prototypes) do
      for _,c in ipairs(e.get_fluid_box_pipe_connections(i)) do ports[#ports+1]={index=i,position=c.position,target_position=c.target_position,connected_position=c.target and c.target.position or nil} end
    end
    receipt.entities[#receipt.entities+1]={direction=e.direction,position=e.position,ports=ports,status=e.status,burning=e.burner.remaining_burning_fuel}
    game.take_screenshot{surface=e.surface,position=e.position,resolution={960,896},zoom=4,daytime=0,
      path='boiler-state-baseline/'..game.tick..'-'..({'north','east','south','west'})[j]..'.png',show_gui=false,show_entity_info=false,hide_clouds=true,hide_fog=true,force_render=true}
  end
  helpers.write_file('boiler-state-baseline/'..game.tick..'-state.json',helpers.table_to_json(receipt))
  if game.tick==780 then game.tick_paused=true end
end)

