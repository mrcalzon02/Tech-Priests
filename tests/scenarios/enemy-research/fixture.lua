local Registry=require("scripts.core.runtime_event_registry")
local Notices=require("scripts.core.enemy_research_announcements")
Registry.on_init(function()
 storage.intercept_probe={observed=0}
 settings.global["tech-priests-enemy-allowed-planets"]={value=""}
 local force=game.create_force("tech-priests-renegades-fulgora")
 for _,name in ipairs{"steam-power","electronics","automation-science-pack"}do
  force.technologies[name].researched=true
 end
 local tech=force.technologies.automation
 assert(not Notices.message{research=tech,by_script=true},"scripted grant announced")
 local event={research=tech,by_script=false}
 settings.global["tech-priests-enemy-research-announcements"]={value="off"}
 assert(not Notices.message(event),"disabled notices leaked")
 settings.global["tech-priests-enemy-research-announcements"]={value="milestones"}
 assert(Notices.message(event),"automation milestone missing")
 assert(not Notices.message{research=force.technologies.logistics,by_script=false},
  "ordinary logistics was treated as milestone")
 settings.global["tech-priests-enemy-research-announcements"]={value="all"}
 assert(Notices.message{research=force.technologies.logistics,by_script=false},"all mode filtered research")
 assert(not Notices.message{research=game.forces.player.technologies.automation,by_script=false},
  "friendly research announced as hostile")
 local allied=game.create_force("tp-intercept-allied")
 allied.set_friend(force,true)
 local truce=game.create_force("tp-intercept-truce")
 truce.set_cease_fire(force,true)
 local delivered=0
 local function recipient(f)
  return {valid=true,force=f,print=function(message,options)
   assert(type(message)=="table"and message[1]:find("enemy%-research%-announcement%.intercept%-"),
    "missing gothic localised transmission")
   assert(options.color.r==1,"missing chat color")
   delivered=delivered+1
  end}
 end
 assert(Notices.notify(event,{recipient(game.forces.player),recipient(allied),recipient(truce),recipient(force)})==1
  and delivered==1,"hostile recipient filtering failed")
 local surface=game.surfaces.nauvis
 surface.freeze_daytime=true;surface.daytime=0
 surface.request_to_generate_chunks({32,0},1);surface.force_generate_chunk_requests()
 for _,e in pairs(surface.find_entities_filtered{area={{26,-10},{40,5}}})do e.destroy()end
 local tiles={};for x=26,40 do for y=-10,5 do tiles[#tiles+1]={name="grass-1",position={x,y}}end end
 surface.set_tiles(tiles)
 local lab=surface.create_entity{name="lab",position={32,0},force=force}
 assert(lab and lab.insert{name="automation-science-pack",count=2}==2,"lab fixture failed")
 assert(surface.create_entity{name="solar-panel",position={32,-5},force=force})
 assert(surface.create_entity{name="substation",position={37,0},force=force})
 assert(force.add_research("automation"),"native research queue refused")
 -- Accelerate this observer-only test to the final fraction. The completion
 -- still comes from a real powered lab consuming physical science, not an event raise.
 force.research_progress=0.999
 log("[TP-ENEMY-RESEARCH] PASS settings, grants, milestone and recipient filters")
end,{owner="intercept_probe",route="init",priority=1000000})
Registry.on_event(defines.events.on_research_finished,function(event)
 if event.research.force.name~="tech-priests-renegades-fulgora"or event.by_script then return end
 assert(Notices.message(event),"native completion produced no transmission")
 storage.intercept_probe.observed=storage.intercept_probe.observed+1
 log("[TP-ENEMY-RESEARCH] PASS native completion event technology="..event.research.name)
end,nil,{owner="intercept_probe",route="native-event",priority=1000000})
Registry.on_event(defines.events.on_tick,function(event)
 if event.tick==600 then
  assert(storage.intercept_probe.observed==1,"native completion missing or duplicated")
  assert(game.get_player(1),"native player missing")
  log("[TP-ENEMY-RESEARCH] PASS loaded native player session and exactly one completion")
 end
end,nil,{owner="intercept_probe",route="verify"})
