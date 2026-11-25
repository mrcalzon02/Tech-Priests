-- On native clone, ghost revival, and replacement the NEW physical entity
-- receives a new Machine Spirit record. No wear or ID is copied from a source.
-- Execute the actual runtime bridge with the real quality baseline and a
-- bounded canonical-registration fixture. No new tick service or remote runner.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Quality=require("scripts.core.consecration.quality_baseline")
package.preload["scripts.core.consecration.doctrine_effects"]=function()
  return {invalidate=function()return true end,snapshot=function()return {} end,
    snapshot_changed=function()return false end}
end
local routes,scheduled,created,labels={},0,0,0
TechPriestsRuntimeEventRegistry={
  on_event=function(events,callback,filter,options)
    assert(options.owner=="consecration-runtime-bridge")
    routes[options.route]={events=events,callback=callback}
    return true
  end,
  on_nth_tick=function(interval,callback,options)
    assert(interval==89 and options.route=="periodic-target-scan")
    scheduled=scheduled+1
    return true
  end,
  on_configuration_changed=function(callback,options)
    assert(options.owner=="consecration-runtime-bridge")
    routes[options.route]={callback=callback}
    return true
  end
}
defines={events={on_entity_cloned=9,on_built_entity=1,on_robot_built_entity=2,
  script_raised_built=3,script_raised_revive=4,on_entity_died=5,
  on_pre_player_mined_item=6,on_robot_pre_mined=7,script_raised_destroy=8,
  on_gui_closed=10,on_player_fast_transferred=11}}
game={tick=300}
storage={tech_priests={consecration={machines={},next_machine_id_0446=1}}}
local normal_force={index=1,starting=50,maximum=100}
local researched_force={index=2,starting=90,maximum=120}
local function entity(unit,grade,force)
  return {valid=true,unit_number=unit,name="assembling-machine-3",
    type="assembling-machine",force=force or normal_force,
    quality=grade and {name=grade} or nil}
end
is_consecration_target=function(e)
  return e and e.valid and e.unit_number and e.type=="assembling-machine"
end
get_base_sanctification_start=function(force)return force.starting end
get_base_sanctification_max=function(force)return force.maximum end
local function ensure_record(e)
  if not is_consecration_target(e) then return nil end
  local records=storage.tech_priests.consecration.machines
  local rec=records[e.unit_number]
  if not rec then
    local q=Quality.entity_quality_name(e)
    rec={entity=e,unit_number=e.unit_number,max_sanctification=e.force.maximum,
      sanctification=Quality.starting_sanctification(e.force.starting,e.force.maximum,q),
      quality_at_initial_consecration=q,
      machine_id_0446=storage.tech_priests.consecration.next_machine_id_0446}
    storage.tech_priests.consecration.next_machine_id_0446=rec.machine_id_0446+1
    records[e.unit_number]=rec
    created=created+1
  else
    rec.entity=e
  end
  return rec
end
register_consecration_target=function(e)ensure_record(e)end
get_consecration_record=ensure_record
remove_consecration_target=function(e)
  storage.tech_priests.consecration.machines[e.unit_number]=nil
end
tech_priests_0446_refresh_sanctification_label_if_due=function(rec,force)
  assert(force==true and rec.entity.valid)
  labels=labels+1
end
local Bridge=require("scripts.core.consecration.runtime_bridge")
assert(Bridge.install(),"canonical bridge did not install")
local clone_route=assert(routes["register-native-clone"])
local built_route=assert(routes["register-built-entity"])
local remove_route=assert(routes["remove-destroyed-entity"])
assert(#clone_route.events==1 and clone_route.events[1]==9)
assert(#built_route.events==4 and scheduled==1,"new scheduler or missing build route")
local source=entity(101,"normal")
local original=ensure_record(source)
original.sanctification=18
original.max_sanctification=32
original.completed_operations_seen_0417=71
original.machine_spirit_module_snapshot={order=20}
local initial_id=original.machine_id_0446
local tiers={normal=50,uncommon=60,rare=70,epic=85,legendary=100}
local clone_numbers={normal=102,uncommon=103,rare=104,epic=105,legendary=106}
for grade,value in pairs(tiers) do
  local e=entity(clone_numbers[grade],grade)
  clone_route.callback({source=source,destination=e})
  local rec=assert(storage.tech_priests.consecration.machines[e.unit_number])
  assert(rec.sanctification==value and rec.max_sanctification==100,
    "clone inherited source wear or ignored new quality: "..grade)
  assert(rec.machine_id_0446~=initial_id and rec.quality_at_initial_consecration==grade,
    "clone inherited ID or quality: "..grade)
  assert(not rec.completed_operations_seen_0417 and not rec.machine_spirit_module_snapshot,
    "clone inherited history or module cache")
  rec.sanctification=7
  clone_route.callback({source=source,destination=e})
  assert(rec.sanctification==7,"repeated registration healed same physical entity")
end
assert(original.sanctification==18 and original.max_sanctification==32
  and original.machine_id_0446==initial_id,"clone modified old physical machine")
local rclone=entity(110,"epic",researched_force)
clone_route.callback({source=source,destination=rclone})
local rec=assert(storage.tech_priests.consecration.machines[110])
assert(rec.sanctification==111 and rec.max_sanctification==120,
  "clone did not respect destination force's researched baseline")
-- A blueprint ghost is never a Machine Spirit. Only its completed build is.
local ghost={valid=true,type="entity-ghost",name="entity-ghost",force=normal_force}
local before=created
built_route.callback({entity=ghost})
assert(created==before,"unbuilt ghost received a machine record")
local revived=entity(120,"rare")
built_route.callback({destination=revived})
assert(storage.tech_priests.consecration.machines[120].sanctification==70,
  "revived blueprint did not start as new Rare machine")
-- A destroyed machine and later replacement starts from scratch.
remove_route.callback({entity=source})
assert(storage.tech_priests.consecration.machines[101]==nil,
  "obsolete machine record survived destruction")
local replacement=entity(121,"uncommon")
built_route.callback({created_entity=replacement})
local fresh=assert(storage.tech_priests.consecration.machines[121])
assert(fresh.sanctification==60 and fresh.max_sanctification==100
  and fresh.machine_id_0446~=initial_id,
  "replacement inherited wear or old ID")
-- Save/reload of the SAME unit is not a fresh machine.
fresh.sanctification=13
fresh.max_sanctification=45
built_route.callback({entity=replacement})
assert(fresh.sanctification==13 and fresh.max_sanctification==45,
  "existing physical machine healed on re-registration")
local not_created=created
clone_route.callback({source=source,destination={valid=false,unit_number=122}})
clone_route.callback({source=source,destination=nil})
assert(created==not_created and scheduled==1,"invalid clone created a machine or tick service")
assert(labels>0,"new machines did not refresh their original sanctity labels")
print("[machine-spirit-clone-bridge] PASS fresh quality for clones, ghosts and replacements; no inherited wear; save/reload preserves state")
