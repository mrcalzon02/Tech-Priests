-- Four orientation sprite-placement review; physical prototype connections are unchanged.
script.on_init(function()
  local s=game.surfaces.nauvis;s.request_to_generate_chunks({0,0},2);s.force_generate_chunk_requests()
  for _,e in pairs(s.find_entities_filtered{area={{-34,-15},{34,15}}}) do e.destroy() end
  local tiles={};for x=-34,34 do for y=-15,15 do tiles[#tiles+1]={name='refined-concrete',position={x,y}} end end
  s.set_tiles(tiles);s.destroy_decoratives{area={{-34,-15},{34,15}}};s.daytime=0;s.freeze_daytime=true
  storage.boilers={}
  for j,d in ipairs({defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west}) do
    local e=assert(s.create_entity{name='boiler-layer-reference',position={(j-2.5)*12,0},direction=d,force='player',create_build_effect_smoke=false})
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
  if game.tick==180 then
    for j,old in ipairs(storage.boilers) do
      local surface,position,direction=old.surface,old.position,old.direction
      old.destroy()
      storage.boilers[j]=assert(surface.create_entity{name='boiler-layer-candidate',position=position,direction=direction,force='player',create_build_effect_smoke=false})
    end
  end
  for _,e in ipairs(storage.boilers) do
    if game.tick==1 or game.tick==180 then e.insert{name='coal',count=5} end
    e.set_fluid(1,{name='water',amount=1000,temperature=15});e.clear_fluid(2)
  end
  if #game.players==0 or (game.tick~=120 and game.tick~=300) then return end
  local label=game.tick==120 and 'reference' or 'candidate'
  local receipt={scope='Fixed-pose native sprite composition only, no behavior assertions',tick=game.tick,entities={}}
  for j,e in ipairs(storage.boilers) do
    receipt.entities[#receipt.entities+1]={name=e.name,direction=e.direction,position=e.position,status=e.status}
    game.take_screenshot{surface=e.surface,position=e.position,resolution={960,896},zoom=4,daytime=0,
      path='boiler-layer-fixed-pose/'..label..'-'..({'north','east','south','west'})[j]..'.png',show_gui=false,show_entity_info=false,hide_clouds=true,hide_fog=true,force_render=true}
  end
  helpers.write_file('boiler-layer-fixed-pose/'..label..'-state.json',helpers.table_to_json(receipt))
  if game.tick==300 then game.tick_paused=true end
end)
