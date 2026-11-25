-- Infantry are implemented as AAI cars, but must never inherit Machine Spirit
-- mechanics. Exercise production admission, item/queue rejection and old-save
-- cleanup; normal factory machinery and vehicles retain their existing state.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Catalog=require("shared.combat_roster_catalog")
require("scripts.core.consecration.registry")
require("scripts.core.consecration.overlays")
require("scripts.core.consecration.decay")
require("scripts.core.consecration.api")
local Executor=require("scripts.core.consecration_executor_0515")

storage={tech_priests={consecration={machines={},renders={},overlays={}}}}
game={tick=100,surfaces={}}
ensure_storage=function()end
normalise_consecration_record=function(record)return record end
get_base_sanctification_start=function()return 50 end
get_base_sanctification_max=function()return 100 end
get_current_consecration_config_snapshot=function()return {base_max=100,base_start=50} end
local destroyed=0
destroy_render_objects=function(render)
  assert(not render.destroyed,"render destroyed twice")
  render.destroyed=true;destroyed=destroyed+1
end
local consumed=0
consume_consecration_item_from_player=function()consumed=consumed+1;return true end
consume_consecration_item_from_station=function()consumed=consumed+1;return true end
local force={valid=true,index=1}
local next_unit=0
local function entity(name,kind)
  next_unit=next_unit+1
  return setmetatable({valid=true,name=name,type=kind,unit_number=next_unit,force=force,
    position={x=0,y=0},health=75,disabled_by_script=false,custom_status="AAI status"}, {
      __index=function(e,k) if k=="active" then return not e.disabled_by_script end end,
      __newindex=function(e,k,v) assert(k~="active","active is read-only in 2.1");rawset(e,k,v) end
    })
end
local pair={station=entity("junior-cogitator-station","container"),
  priest=entity("junior-tech-priest","unit")}
local actor_forms={}
for _,unit in ipairs(Catalog.units) do
  for _,form in ipairs({{"","car"},{"-_-solid","car"},{"-_-ghost","car"},
    {"-_-driver","character"},{"-_-navigator","unit"},{"-_-buffer","simple-entity"}}) do
    local actor=entity(unit.name..form[1],form[2])
    actor_forms[#actor_forms+1]=actor
    assert(not is_consecration_target(actor),"infantry admitted: "..actor.name)
    register_consecration_target(actor)
    assert(get_consecration_record(actor)==nil,"infantry acquired machine record")
    assert(not apply_consecration_item(nil,actor,"sacred-machine-oil"),"infantry accepted oil")
    local admitted,reason=Executor.submit_or_assign_consecration_task(pair,actor,"test")
    assert(not admitted and reason=="ineligible:not-target","infantry accepted a consecration order")
  end
end
assert(consumed==0,"rejected infantry consumed consecration supplies")
assert(#collect_consecration_targets_from_entities(actor_forms)==0,"area rite includes infantry")

-- Neither a name allowlist nor a unit's LuaEntity.unit_number grants sanctity.
CONSECRATION_TARGET_NAME_SET={["junior-tech-priest"]=true,["character"]=true}
assert(not is_consecration_target(pair.priest))
assert(not is_consecration_target(entity("character","character")))
local machine=entity("assembling-machine-2","assembling-machine")
local machine_record=get_consecration_record(machine)
machine_record.sanctification=23
machine_record.max_sanctification=80
for _,kind in ipairs({"car","spider-vehicle","locomotive"}) do
  assert(is_consecration_target(entity("ordinary-"..kind,kind)),"ordinary vehicle excluded: "..kind)
end

local state=storage.tech_priests.consecration
local function stale_record(actor)
  local rec={entity=actor,unit_number=actor.unit_number,sanctification=1,max_sanctification=80,
    control_malfunction_until_tick=500,control_malfunction_original_disabled_by_script=false}
  actor.disabled_by_script=true;actor.custom_status="consecration malfunction"
  state.machines[actor.unit_number]=rec
  state.renders[actor.unit_number]={}
  state.overlays[actor.unit_number]={}
  return rec
end
local actor=actor_forms[1]
local rec=stale_record(actor)
assert(not apply_completed_sanctification_operation(rec),"infantry completed a sanctity operation")
assert(rec.sanctification==1 and actor.health==75,"infantry suffered sanctity decay/damage")
assert(not update_machine_sanctification(rec),"stale infantry record serviced")
assert(not state.machines[actor.unit_number] and destroyed==2 and actor.active,
  "service did not clear stale unit effects")
assert(actor.custom_status==nil and actor.health==75,"cleanup changed health or left ritual status")
draw_sanctification_label(stale_record(actor))
update_sanctification_overlay(stale_record(actor),true)
assert(destroyed==6 and state.renders[actor.unit_number]==nil
  and state.overlays[actor.unit_number]==nil,"stale infantry bar/overlay was redrawn")

for _,e in ipairs(actor_forms) do stale_record(e) end
local redraws=0
draw_sanctification_label=function(r)
  assert(r==machine_record,"configuration redraw includes infantry")
  redraws=redraws+1
end
update_sanctification_overlay=function(r)assert(r==machine_record)end
apply_consecration_config_change_to_existing_machines()
assert(redraws==1 and state.machines[machine.unit_number]==machine_record,
  "configuration cleanup removed real machinery")
assert(machine_record.sanctification==23 and machine_record.max_sanctification==80,
  "configuration cleanup reset machinery wear")
for _,e in ipairs(actor_forms) do
  assert(not state.machines[e.unit_number] and not state.renders[e.unit_number]
    and not state.overlays[e.unit_number],"old-save unit record/render survived")
  assert(e.active and e.health==75,"old-save unit malfunction not released")
end
-- Scanning an already-clean excluded actor must preserve unrelated AAI state.
actor.custom_status="AAI status"
remove_consecration_target(actor)
assert(actor.custom_status=="AAI status","cleanup altered an untracked unit")
-- Restore our script flag exactly, including an already-disabled prior state.
local disabled_record=stale_record(actor)
disabled_record.control_malfunction_original_disabled_by_script=true
prune_ineligible_consecration_targets()
assert(actor.disabled_by_script,"cleanup enabled a previously disabled actor")
local legacy_record=stale_record(actor)
legacy_record.control_malfunction_original_disabled_by_script=nil
legacy_record.control_malfunction_original_active=true
prune_ineligible_consecration_targets()
assert(actor.disabled_by_script,"legacy cleanup guessed and changed an unknown script flag")
-- Exercise real lifecycle dispatch. Two anonymous legacy callbacks collide in
-- the registry; our explicit migration route must survive them and run even
-- if the general config-refresh function and periodic services never execute.
local configuration_handler
script={on_event=function()end,on_nth_tick=function()end,
  on_configuration_changed=function(handler)configuration_handler=handler end}
defines={events={on_built_entity=1,on_robot_built_entity=2,script_raised_built=3,
  script_raised_revive=4,on_entity_cloned=5,on_entity_died=6,
  on_pre_player_mined_item=7,on_robot_pre_mined=8,script_raised_destroy=9,
  on_player_fast_transferred=10,on_gui_closed=11}}
local Registry=require("scripts.core.runtime_event_registry")
TechPriestsRuntimeEventRegistry=Registry
Registry.on_configuration_changed(function()end)
assert(require("scripts.core.consecration.runtime_bridge").install())
Registry.on_configuration_changed(function()end)
stale_record(actor)
assert(type(configuration_handler)=="function","native configuration callback missing")
configuration_handler({mod_changes={["tech-priests"]={old_version="1.0.0",new_version="1.0.1"}}})
assert(not state.machines[actor.unit_number] and not state.renders[actor.unit_number]
  and not state.overlays[actor.unit_number],"named upgrade route did not prune stale infantry")
assert(state.machines[machine.unit_number]==machine_record and machine_record.sanctification==23,
  "named upgrade route changed real machinery")
print("[combat-unit-consecration-exclusion] PASS "..#Catalog.units.." actors, AAI forms, oil/orders, old-save cleanup, machinery preservation")
