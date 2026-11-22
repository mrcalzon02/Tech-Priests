-- Execute the actual event bridge and real clone_condition.lua, not copied logic.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
package.preload["scripts.core.consecration.doctrine_effects"]=function()
  return {invalidate=function() return true end,snapshot=function() return {} end,
    snapshot_changed=function() return false end}
end
local routes, scheduled = {}, 0
TechPriestsRuntimeEventRegistry={
  on_event=function(events,callback,filter,options)
    routes[options.route]={events=events,callback=callback,options=options}
    return true
  end,
  on_nth_tick=function(n,callback,options)
    assert(n==89 and options.route=="periodic-target-scan")
    scheduled=scheduled+1
    return true
  end
}
defines={events={on_entity_cloned=9,on_built_entity=1,on_robot_built_entity=2,
  script_raised_built=3,script_raised_revive=4,on_entity_died=5,
  on_pre_player_mined_item=6,on_robot_pre_mined=7,script_raised_destroy=8,
  on_gui_closed=10,on_player_fast_transferred=11}}
game={tick=300}
storage={tech_priests={consecration={machines={}}}}
local count,labels,new_ids=0,0,200
local force={index=1}
local function e(unit,grade,group,name)
  return {valid=true,unit_number=unit,force=group or force,
    name=name or "assembling-machine-3",type="assembling-machine",quality={name=grade or "normal"}}
end
is_consecration_target=function(entity) return entity.valid and entity.type=="assembling-machine" end
register_consecration_target=function(entity)
  if is_consecration_target(entity) and not storage.tech_priests.consecration.machines[entity.unit_number] then
    new_ids=new_ids+1
    count=count+1
    storage.tech_priests.consecration.machines[entity.unit_number]={
      entity=entity,unit_number=entity.unit_number,sanctification=100,max_sanctification=100,
      machine_id_0446=new_ids,quality_at_initial_consecration=entity.quality.name
    }
  end
end
local function normalize(rec)
  -- Keep the legacy-cap trap that production has for old 50-point saves.
  if not rec.legacy_50_cap_migrated and rec.max_sanctification<=50 then
    local f=rec.sanctification/rec.max_sanctification
    rec.max_sanctification=100
    rec.sanctification=f*100
    rec.legacy_50_cap_migrated=true
  end
end
get_consecration_record=function(entity)
  local rec=storage.tech_priests.consecration.machines[entity.unit_number]
  if rec then normalize(rec) end
  return rec
end
clamp_machine_sanctification=normalize
tech_priests_0446_refresh_sanctification_label_if_due=function(rec,forced)
  assert(forced and rec.entity.valid)
  labels=labels+1
end
local source=e(101,"normal")
local source_rec={entity=source,unit_number=101,sanctification=18,max_sanctification=32,
  machine_id_0446=111,legacy_50_cap_migrated=true,completed_operations_seen_0417=41}
storage.tech_priests.consecration.machines[101]=source_rec
local Bridge=require("scripts.core.consecration.runtime_bridge")
assert(Bridge.install(),"bridge installation failed")
local route=assert(routes["register-native-clone"])
assert(#route.events==1 and route.events[1]==9 and route.options.owner=="consecration-runtime-bridge")
assert(scheduled==1,"clone support installed a second periodic scan")
local clone=e(102,"legendary")
route.callback({source=source,destination=clone})
local cloned=get_consecration_record(clone)
assert(cloned and cloned.sanctification==18 and cloned.max_sanctification==32,
  "real runtime clone callback failed to preserve wear")
assert(cloned.legacy_50_cap_migrated and cloned.machine_id_0446~=111,
  "clone ID duplicated or 50-point scar wrongly migrated")
assert(cloned.quality_at_initial_consecration=="legendary", "clone quality overridden")
assert(labels==1 and count==1,"event caused duplicate registration/label")
cloned.sanctification=6
route.callback({source=source,destination=clone})
assert(cloned.sanctification==6 and count==1,"replayed clone event healed existing machine")
local foreign=e(103,"normal",{index=2})
route.callback({source=source,destination=foreign})
assert(get_consecration_record(foreign).sanctification==100,
  "cross-force clone incorrectly imported worn sanctity")
local unknown=e(104,"uncommon")
route.callback({source=e(999),destination=unknown})
assert(get_consecration_record(unknown).sanctification==100,
  "untracked clone invented source wear")
local prior=count
route.callback({source=source,destination={valid=false,unit_number=105}})
assert(count==prior and scheduled==1,"invalid clone caused extra registration or scan")
assert(source_rec.sanctification==18 and source_rec.machine_id_0446==111,
  "clone modified original condition")
print("[machine-spirit-clone-bridge] PASS event installation, wear custody, idempotence, quality, isolation")
