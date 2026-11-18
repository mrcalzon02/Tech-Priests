local pods={};local results={events={}}
local function note(kind,e)
 local p=e.cargo_pod;if not(p and p.valid and p.name=='tp-orbital-native-cargo-pod')then return end
 results.events[#results.events+1]={kind=kind,tick=game.tick,state=p.cargo_pod_state,position=p.position}
 if e.spawned_container and e.spawned_container.valid then
  assert(e.spawned_container.get_item_count()==0,'cosmetic pod must never add items');e.spawned_container.destroy();results.empty_owned_container_removed=true
 end
end
script.on_init(function()
 game.speed=16;storage.units={}
 local f=game.forces.player
 for _,platform in ipairs({false,true})do
  local s=game.surfaces[1]
  if platform then local p=f.create_space_platform{name='Orbital existing native pod reuse probe',planet='nauvis',starter_pack='space-platform-starter-pack'};p.apply_starter_pack(true);s=p.surface end
  local pos={x=40,y=40};s.request_to_generate_chunks(pos,1);s.force_generate_chunk_requests();local tiles={};for x=32,48 do for y=32,48 do tiles[#tiles+1]={name=platform and'space-platform-foundation'or'grass-1',position={x,y}}end end;s.set_tiles(tiles,true)
  local target=assert(s.create_entity{name='orbital-trader',position=pos,force=f});local pod=assert(s.create_entity{name='tp-orbital-native-cargo-pod',position={pos.x-.65,pos.y+1},force=f})
  storage.units[#storage.units+1]={target=target,pod=pod,platform=platform,health=target.health};pod.cargo_pod_destination={type=defines.cargo_destination.surface,surface=s,position={pos.x-.65,pos.y+1},land_at_exact_position=true};pod.force_finish_ascending()
 end
end)
script.on_event(defines.events.on_cargo_pod_finished_descending,function(e)note('native finished descending',e)end)
script.on_event(defines.events.on_cargo_pod_delivered_cargo,function(e)note('native delivered cargo',e)end)
script.on_event(defines.events.on_tick,function(e)
 if e.tick%60==0 then
  local rows={};for _,u in ipairs(storage.units)do rows[#rows+1]={platform=u.platform,target_health=u.target.health,original_health=u.health,pod_valid=u.pod.valid,pod_state=u.pod.valid and u.pod.cargo_pod_state or'destroyed',position=u.pod.valid and u.pod.position or false};assert(u.target.health==u.health,'cosmetic native pod may not damage target')end
  results.rows=rows;helpers.write_file('orbital-native-pod-reuse/probe.json',helpers.table_to_json(results),false)
 end
end)
