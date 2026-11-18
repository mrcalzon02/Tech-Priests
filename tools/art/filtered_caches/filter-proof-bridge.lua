-- PRIVATE PROFILE ONLY: invoke the installed production steward in its own mod
-- context with real entities/inventories. No replacement filter or mock deposit.
remote.add_interface('filtered_cache_native_proof',{
 test=function(key,index)
  local M=assert(rawget(_G,'tech_priests_stone_cache_filter_0534'))
  local surface=game.surfaces['filtered-cache-proof'] or game.create_surface('filtered-cache-proof',{peaceful_mode=true,autoplace_controls={['enemy-base']={frequency='none',size='none',richness='none'}}})
  local x=index*160;surface.request_to_generate_chunks({x,0},1);surface.force_generate_chunk_requests()
  for _,e in pairs(surface.find_entities_filtered{area={{x-8,-8},{x+20,10}},type={'tree','simple-entity','cliff'}})do e.destroy()end
  local e=surface.create_entity{name='tech-priests-stone-cache-'..key,position={x,0},force='player'};local wrong=key=='copper-plate' and 'coal' or 'copper-plate';e.insert{name=key,count=1};e.insert{name=wrong,count=7};M.register_entity(e)
  local r={actual_installed_module=true,wrong_item=wrong};M.sweep_entity(e);r.no_pair_retains_wrong=e.get_item_count(wrong)==7 and e.get_item_count(key)==1
  local station=surface.create_entity{name='junior-cogitator-station',position={x+8,0},force='player'};local priest=surface.create_entity{name='junior-tech-priest',position={x+10,1},force='player'}
  local sink=surface.create_entity{name='steel-chest',position={x+4.5,3.5},force='player'}
  for _,entity in ipairs{station,sink}do local inv=entity.get_inventory(defines.inventory.chest);for i=1,#inv do inv[i].set_stack{name='uranium-238',count=prototypes.item['uranium-238'].stack_size}end end
  storage.tech_priests=storage.tech_priests or {};local tp=storage.tech_priests;tp.pairs_by_station=tp.pairs_by_station or {};tp.pairs_by_priest=tp.pairs_by_priest or {};tp.station_by_priest=tp.station_by_priest or {}
  local pair={station=station,priest=priest,station_unit=station.unit_number,priest_unit=priest.unit_number,tier='junior',enabled=false};tp.pairs_by_station[station.unit_number]=pair;tp.pairs_by_priest[priest.unit_number]=pair;tp.station_by_priest[priest.unit_number]=station.unit_number
  M.sweep_entity(e);r.blocked_restores_without_loss=e.get_item_count(wrong)==7 and e.get_item_count(key)==1 and sink.get_item_count(wrong)==0 and station.get_item_count(wrong)==0
  local before=storage.tech_priests_stone_cache_filter_0534.stats.rerouted or 0;sink.get_inventory(defines.inventory.chest)[1].clear();local changed=M.sweep_entity(e)
  r.actual_reroute=changed==true and e.get_item_count(wrong)==0 and e.get_item_count(key)==1 and sink.get_item_count(wrong)==7
  r.conserved=e.get_item_count(wrong)+sink.get_item_count(wrong)+station.get_item_count(wrong)==7
  r.allowed_retained=e.get_item_count(key)==1;r.no_spill=#surface.find_entities_filtered{type='item-entity',area={{x-8,-8},{x+20,10}}}==0
  r.reroute_stat=(storage.tech_priests_stone_cache_filter_0534.stats.rerouted or 0)-before;r.no_custody=true
  for _,v in pairs(storage.tech_priests_stone_cache_filter_0534.custody or {})do if v.entity==e and v.count>0 then r.no_custody=false end end
  tp.pairs_by_station[station.unit_number]=nil;tp.pairs_by_priest[priest.unit_number]=nil;tp.station_by_priest[priest.unit_number]=nil
  r.passed=r.no_pair_retains_wrong and r.blocked_restores_without_loss and r.actual_reroute and r.conserved and r.allowed_retained and r.no_spill and r.no_custody and r.reroute_stat>=7
  return r
 end
})
