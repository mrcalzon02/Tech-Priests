-- Pure graphical load fixture. Freeze displayed units; do not issue AI orders.
local ranks={'junior','intermediate','senior','planetary-magos','void'}
script.on_init(function()
 local s=game.surfaces.nauvis;s.request_to_generate_chunks({14,30},3);s.force_generate_chunk_requests()
 for _,e in pairs(s.find_entities_filtered{area={{-5,-5},{36,69}}}) do e.destroy() end
 local tiles={};for x=-5,36 do for y=-5,69 do tiles[#tiles+1]={name='refined-concrete',position={x,y}} end end
 s.set_tiles(tiles);s.destroy_decoratives{area={{-5,-5},{36,69}}};s.daytime=0;s.freeze_daytime=true
 storage.displayed={}
 for row=1,10 do
  local rank=ranks[(row-1)%5+1];local name=rank..'-tech-priest'..(row>5 and '-belt-immune' or '')
  for col=0,7 do
   local e=assert(s.create_entity{name=name,position={col*4,(row-1)*5},direction=col*2,force='player',create_build_effect_smoke=false})
   e.orientation=col/8;e.disabled_by_script=true
   storage.displayed[#storage.displayed+1]=e
  end
 end
 for i,rank in ipairs(ranks) do s.create_entity{name=rank..'-tech-priest-corpse',position={(i-1)*4,55},force='player'} end
 for i,d in ipairs({0,4,8,12}) do
  local e=assert(s.create_entity{name='tech-priests-emergency-boiler',position={2+(i-1)*6,62},direction=d,force='player',create_build_effect_smoke=false})
  for index in ipairs(e.prototype.fluidbox_prototypes) do
   for _,connection in ipairs(e.get_fluid_box_pipe_connections(index)) do s.create_entity{name='pipe',position=connection.target_position,force='player',snap_to_grid=true} end
  end
 end
end)
script.on_event(defines.events.on_player_created,function(event)
 local p=game.get_player(event.player_index);local avatar=p.character;p.set_controller{type=defines.controllers.god};if avatar and avatar.valid then avatar.destroy() end;p.teleport({14,30})
end)
script.on_event(defines.events.on_tick,function()
 if storage.done or game.tick<10 or #game.players==0 then return end
 storage.done=true;local s=game.surfaces.nauvis
 for row=1,10 do
  local rank=ranks[(row-1)%5+1];local name=rank..'-tech-priest'..(row>5 and '-belt-immune' or '')
  game.take_screenshot{surface=s,position={14,(row-1)*5},resolution={2048,420},zoom=2,daytime=0,path='priest-sprite-import/'..name..'.png',show_gui=false,show_entity_info=false,hide_clouds=true,hide_fog=true,force_render=true}
 end
 game.take_screenshot{surface=s,position={8,55},resolution={1600,420},zoom=2,daytime=0,path='priest-sprite-import/corpses.png',show_gui=false,show_entity_info=false,hide_clouds=true,hide_fog=true,force_render=true}
 game.take_screenshot{surface=s,position={11,62},resolution={2048,720},zoom=2,daytime=0,path='priest-sprite-import/boiler-four-directions.png',show_gui=false,show_entity_info=false,hide_clouds=true,hide_fog=true,force_render=true}
 local poses={};for _,e in ipairs(storage.displayed) do poses[#poses+1]={name=e.name,position=e.position,direction=e.direction,orientation=e.orientation} end
 helpers.write_file('priest-sprite-import/load-receipt.json',helpers.table_to_json{scope='Native graphics/asset loading only; frozen displayed units, no behavior assertions',active_mods=script.active_mods,tick=game.tick,displayed_unit_count=#storage.displayed,poses=poses})
 game.tick_paused=true
end)
