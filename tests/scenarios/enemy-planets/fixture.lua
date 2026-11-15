local Registry=require("scripts.core.runtime_event_registry")
local Seeder=require("scripts.core.enemy_planetary_seeding")
local Colony=require("scripts.core.enemy_colony")
local Options=require("scripts.core.enemy_colony_options")
Registry.on_init(function()
 storage.colony_probe={sites={}}
 for _,planet in ipairs{"fulgora","vulcanus","nauvis","gleba"}do
  local surface=game.surfaces[planet]or game.planets[planet].create_surface()
  surface.peaceful_mode=false;surface.freeze_daytime=true;surface.daytime=0
  local size=(planet=="fulgora"or planet=="vulcanus")and 16 or 24
  local hash=(5*73856093+5*19349663+surface.map_gen_settings.seed)%2147483647
  local c={x=5*size+hash%size,y=5*size+math.floor(hash/size)%size}
  local p={x=c.x*32+16,y=c.y*32+16}
  settings.global["tech-priests-enemy-planetary-spawning"]={value=false}
  surface.request_to_generate_chunks(p,2);surface.force_generate_chunk_requests()
  for _,e in pairs(surface.find_entities_filtered{force="player",position=p,radius=96})do e.destroy()end
  for _,e in pairs(surface.find_entities_filtered{area={{p.x-16,p.y-16},{p.x+16,p.y+16}}})do e.destroy()end
  local tiles={};for x=-16,15 do for y=-16,15 do
   tiles[#tiles+1]={name="grass-1",position={p.x+x,p.y+y}}
  end end;surface.set_tiles(tiles)
  settings.global["tech-priests-enemy-planetary-spawning"]={value=true}
  assert(Colony.can_place(surface,p),"cluster footprint blocked")
  local function setting(key,value)
   local name="tech-priests-enemy-"..key
   local old=settings.global[name].value
   settings.global[name]={value=value}
   return old
  end
  local old=setting("allowed-planets","")
  assert(not Seeder.seed_chunk(surface,c),"empty planet list allowed seeding")
  setting("allowed-planets",old)
  old=setting("max-priests",2)
  assert(not Seeder.seed_chunk(surface,c),"seed exceeded global priest cap")
  setting("max-priests",old)
  old=setting("max-priests-per-planet",2)
  assert(not Seeder.seed_chunk(surface,c),"seed exceeded planetary priest cap")
  setting("max-priests-per-planet",old)
  assert(Seeder.seed_chunk(surface,c),"colony seed failed")
  assert(not Seeder.seed_chunk(surface,c),"duplicate colony")
  local colony=storage.tech_priests.enemy_planetary_seeding[surface.index][c.x..":"..c.y]
  local force=game.forces[colony.force]
  assert(force~=game.forces.enemy and not force.get_friend(game.forces.player),"colony force isolation failed")
  assert(#colony.stations==3,"missing station cluster")
  old=setting("max-colonies",1)
  assert(not Options.admit_colony(surface,planet),"global colony cap ignored")
  setting("max-colonies",old)
  old=setting("max-colonies-per-planet",1)
  assert(not Options.admit_colony(surface,planet),"planetary colony cap ignored")
  setting("max-colonies-per-planet",old)
  old=setting("max-priests-per-planet",3)
  assert(not Options.admit_priests(force.name,1),"normal expansion admission exceeded cap")
  local extra=surface.create_entity{name="junior-cogitator-station",position={p.x,p.y-13},force=force}
  assert(extra and extra.valid,"extra station test placement failed")
  on_built{entity=extra,created_entity=extra}
  assert(not storage.tech_priests.pairs_by_station[extra.unit_number],"canonical pair creator bypassed cap")
  extra.destroy()
  setting("max-priests-per-planet",old)
  old=setting("max-priests",1)
  assert(not Options.admit_priests(force.name,1),"global expansion cap ignored")
  setting("max-priests",0)
  local planet_old=setting("max-priests-per-planet",0)
  assert(Options.admit_priests(force.name,100000),"zero priest limits did not mean unlimited")
  setting("max-priests-per-planet",planet_old);setting("max-priests",old)
  log("[TP-ENEMY-COLONIES] PASS settings and canonical expansion cap "..planet)
  for _,station in ipairs(colony.stations)do
   local pair=storage.tech_priests.pairs_by_station[station.unit_number]
   assert(pair and pair.priest.valid and pair.priest.force==force,"normal pair not bound")
  end
  assert(surface.count_entities_filtered{force=force,type="assembling-machine"}==2,"assemblers missing")
  assert(surface.count_entities_filtered{force=force,type="ammo-turret"}>=2,"turrets missing")
  assert(surface.count_entities_filtered{area={{p.x-14,p.y-14},{p.x+14,p.y+14}},type="resource"}==36,"ore patches missing")
  storage.colony_probe.sites[#storage.colony_probe.sites+1]=colony
  log("[TP-ENEMY-COLONIES] PASS bound cluster "..planet)
 end
end,{owner="colony_probe",route="init",priority=1000000})
Registry.on_event(defines.events.on_tick,function(event)
 if event.tick~=1200 then return end
 for _,colony in ipairs(storage.colony_probe.sites)do
  local force=game.forces[colony.force]
  local surface=colony.stations[1].surface
  local stats=force.get_item_production_statistics(surface)
  assert(stats.get_input_count("iron-gear-wheel")>0,"colony production absent")
  local lab=surface.find_entities_filtered{force=force,type="lab"}[1]
  assert(force.technologies.automation.researched or force.research_progress>0,"colony native research absent: "..force.name
    .." current="..tostring(force.current_research and force.current_research.name)
    .." lab-energy="..tostring(lab and lab.energy))
  for _,station in ipairs(colony.stations)do
   local pair=storage.tech_priests.pairs_by_station[station.unit_number]
   assert(pair and pair.priest.valid and pair.priest.force==force,"pair lost after load")
  end
  log("[TP-ENEMY-COLONIES] PASS native production research and original pairs "..force.name)
 end
end,nil,{owner="colony_probe",route="verify"})
