-- Actual colony from zero research progress; no forced completion, fabricated
-- research events, recurrent supplies, direct worker commands or task injection.
local Registry=require("scripts.core.runtime_event_registry")
local Colony=require("scripts.core.enemy_colony")
local Notices=require("scripts.core.enemy_research_announcements")
local PREFIX="[TP-ENEMY-FULL-RESEARCH] "
Registry.on_init(function()
 settings.global["tech-priests-enemy-allowed-planets"]={value=""}
 settings.global["tech-priests-enemy-max-priests"]={value=3}
 local surface=game.planets.vulcanus.create_surface()
 local p={x=1536,y=1536}
 surface.request_to_generate_chunks(p,2);surface.force_generate_chunk_requests()
 -- Disposable clear terrain fixture; normal planetary power/day rules remain.
 for _,e in pairs(surface.find_entities_filtered{area={{p.x-20,p.y-20},{p.x+20,p.y+20}}})do e.destroy()end
 local tiles={};for x=-20,20 do for y=-20,20 do
  tiles[#tiles+1]={name="volcanic-soil-dark",position={p.x+x,p.y+y}}
 end end;surface.set_tiles(tiles)
 local colony=assert(Colony.create(surface,p,"vulcanus"),"colony refused")
 local force=game.forces[colony.force]
 assert(force.current_research.name=="automation"and force.research_progress==0,
  "research did not start from zero")
 local initial={}
 for _,e in pairs(surface.find_entities_filtered{force=force})do
  if e.unit_number then initial[e.unit_number]=true end
 end
 storage.full_research_probe={colony=colony,initial=initial,completed=0,
  initial_science=20,initial_player_research=game.forces.player.technologies.automation.researched}
 log(PREFIX.."PASS colony initialized research=automation progress=0 priests=3 finite_science=20")
end,{owner="full_research_probe",route="init",priority=1000000})
Registry.on_event(defines.events.on_research_finished,function(event)
 local s=storage.full_research_probe
 if not s or event.research.force.name~=s.colony.force or event.research.name~="automation"then return end
 assert(not event.by_script,"research completion was scripted")
 assert(Notices.message(event),"real completion produced no intercept")
 s.completed=s.completed+1;s.completed_tick=game.tick
 log(PREFIX.."PASS native paid Automation completion tick="..game.tick)
end,nil,{owner="full_research_probe",route="completion",priority=1000000})
Registry.on_event(defines.events.on_tick,function(event)
 local s=storage.full_research_probe
 if not s then return end
 local force=game.forces[s.colony.force]
 if event.tick%1200==0 then
  log(PREFIX.."PROGRESS tick="..event.tick.." research="
   ..tostring(force.current_research and force.current_research.name)
   .." progress="..force.research_progress.." completed="..s.completed)
 end
 if event.tick~=12000 then return end
 assert(s.completed==1 and force.technologies.automation.researched,"from-zero research did not complete")
 assert(game.forces.player.technologies.automation.researched==s.initial_player_research,
  "enemy research changed player research")
 local surface=s.colony.stations[1].surface
 local stats=force.get_item_production_statistics(surface)
 local built=0
 for _,e in pairs(surface.find_entities_filtered{force=force,
     name={"iron-chest","wooden-chest","burner-mining-drill","electric-mining-drill",
      "assembling-machine-1","stone-furnace","lab","small-electric-pole","pipe"}})do
  if e.unit_number and not s.initial[e.unit_number]then built=built+1 end
 end
 log(PREFIX.."EVIDENCE new_physical_structures="..built
  .." science_produced="..stats.get_input_count("automation-science-pack"))
 assert(built>0,"normal priests did not construct any new physical structure")
 log(PREFIX.."PASS from-zero research, actual construction and native intercept")
end,nil,{owner="full_research_probe",route="verify"})
