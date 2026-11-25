-- Use the real registry, bridge and bootstrap watchdog body. Full-world
-- membership discovery is initial/configuration/manual work, not a timer.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={consecration={machines={},renders={},overlays={}}}}
game={tick=1,surfaces={},connected_players={}}
defines={events={}}
local event_names={"on_built_entity","on_robot_built_entity","script_raised_built",
  "script_raised_revive","on_entity_cloned","on_entity_died","on_pre_player_mined_item",
  "on_robot_pre_mined","script_raised_destroy","on_player_fast_transferred","on_gui_closed",
  "on_chunk_generated","on_space_platform_built_entity","on_space_platform_mined_entity"}
for id,name in ipairs(event_names)do defines.events[name]=id end
local routes={}
TechPriestsRuntimeEventRegistry={
  on_event=function(_,callback,_,opts)routes[opts.route]=callback;return true end,
  on_nth_tick=function(_,callback,opts)routes[opts.route]=callback;return true end,
  on_configuration_changed=function(callback,opts)routes[opts.route]=callback;return true end}
ensure_storage=function()end
normalise_consecration_record=function(record)return record end
get_base_sanctification_start=function()return 50 end
get_base_sanctification_max=function()return 100 end
clear_sanctification_overlay=function()end
destroy_render_objects=function()end
tech_priests_0446_refresh_sanctification_label_if_due=function()end
CONSECRATION_TARGET_NAME_LIST={"special-machine"}
CONSECRATION_TARGET_NAME_SET={["special-machine"]=true}
local entities,queries,full_queries={},0,0
local function make_surface(index)
  local surface={valid=true,index=index}
  surface.find_entities_filtered=function(filter)
    queries=queries+1
    if not filter.area then full_queries=full_queries+1 end
    local found={}
    for _,entity in ipairs(entities)do
      local named=false
      for _,name in ipairs(filter.name or {})do if name==entity.name then named=true end end
      local p,area=entity.position,filter.area
      local inside=not area or (p.x>=area[1][1] and p.x<=area[2][1]
        and p.y>=area[1][2] and p.y<=area[2][2])
      if entity.valid and entity.surface==surface and inside
        and (named or filter.type==entity.type) then found[#found+1]=entity end
    end
    return found
  end
  game.surfaces[index]=surface
  return surface
end
local surface,other_surface=make_surface(1),make_surface(2)
local next_unit=10
local function machine(kind,x,world)
  next_unit=next_unit+1
  local entity={valid=true,type=kind,name=kind,unit_number=next_unit,
    position={x=x,y=x},surface=world or surface,force={valid=true,index=1}}
  entities[#entities+1]=entity
  return entity
end
local existing=machine("assembling-machine",1)
local remote=machine("furnace",1,other_surface)
require("scripts.core.consecration.registry")
local original=get_consecration_record(existing)
original.sanctification=12;original.max_sanctification=37
original.completed_operations_seen_0417=81
local original_id=original.machine_id_0446
local bridge_file=os.getenv("TP_CONSECRATION_BRIDGE_FILE")
local function install_bridge()
  package.loaded["scripts.core.consecration.runtime_bridge"]=nil
  local Bridge=bridge_file and assert(loadfile(bridge_file))()
    or require("scripts.core.consecration.runtime_bridge")
  assert(Bridge.install())
end
install_bridge()
local bootstrap_file=os.getenv("TP_BOOTSTRAP_FILE") or "tech-priests_src/scripts/core/bootstrap_runtime.lua"
local file=assert(io.open(bootstrap_file));local text=file:read("*a");file:close()
local body=assert(text:match('tech_priests_0810_register_tick%(149, function%(%)\n(.-)\n  end, "consecration%-watchdog"'),
  "actual bootstrap visibility callback not found")
local watchdog=assert(load("return function()\n"..body.."\nend"))()
local visual_refreshes=0
game.connected_players={{valid=true,selected=existing}}
tech_priests_0409_refresh_selected_consecration_for_player=function(player)
  assert(player.selected==existing);visual_refreshes=visual_refreshes+1
end
routes["periodic-target-scan"]()
local seed_queries=queries
assert(seed_queries>0 and storage.tech_priests.consecration.machines[remote.unit_number],
  "initial registry seed did not discover pre-existing machines on every surface")
for tick=2,12000 do
  game.tick=tick
  if tick%89==0 then routes["periodic-target-scan"]() end
  if tick%149==0 then watchdog() end
end
assert(queries==seed_queries,"bridge/watchdog repeatedly rediscovered existing surfaces")
assert(visual_refreshes>50,"selected-machine visibility stopped refreshing")
assert(original==storage.tech_priests.consecration.machines[existing.unit_number]
  and original.machine_id_0446==original_id and original.sanctification==12
  and original.max_sanctification==37 and original.completed_operations_seen_0417==81,
  "retained registry changed machine identity, wear or operation history")
local built=machine("lab",3)
routes["register-built-entity"]({entity=built})
assert(storage.tech_priests.consecration.machines[built.unit_number] and queries==seed_queries,
  "exact build event required another area scan")
local cloned=machine("mining-drill",5)
routes["register-native-clone"]({source=built,destination=cloned})
assert(storage.tech_priests.consecration.machines[cloned.unit_number] and queries==seed_queries,
  "clone event failed to register the new physical machine")
routes["remove-destroyed-entity"]({entity=built})
built.valid=false
assert(not storage.tech_priests.consecration.machines[built.unit_number],
  "pre-removal event retained the physical machine")
local generated=machine("reactor",70)
local full_before=full_queries
routes["register-generated-chunk"]({surface=surface,area={{64,64},{96,96}}})
assert(storage.tech_priests.consecration.machines[generated.unit_number]
  and full_queries==full_before,"new-chunk admission rescanned an existing whole surface")
local before=queries
install_bridge();game.tick=15000
routes["periodic-target-scan"]();watchdog()
assert(queries==before,"reload forgot the durable initial seed")
routes["prune-ineligible-records-on-configuration"]()
routes["periodic-target-scan"]()
assert(queries==before+seed_queries,"configuration did not perform exactly one fresh seed")
before=queries;game.tick=18000
routes["periodic-target-scan"]();watchdog()
assert(queries==before,"configuration seed restarted periodic rediscovery")
scan_existing_consecration_targets()
assert(queries==before+seed_queries,"explicit manual recovery lost its full registration scan")
local retry_target=machine("lab",200)
local original_query=surface.find_entities_filtered
local fail_once=true
surface.find_entities_filtered=function(filter)
  if fail_once and filter.type=="lab" then fail_once=false;error("transient native query failure") end
  return original_query(filter)
end
routes["prune-ineligible-records-on-configuration"]()
game.tick=19000;routes["periodic-target-scan"]()
assert(storage.tech_priests.consecration.discovery_seeded_0446==false
  and not storage.tech_priests.consecration.machines[retry_target.unit_number],
  "incomplete seed was incorrectly treated as complete membership")
before=queries;game.tick=19001;routes["periodic-target-scan"]()
assert(queries==before,"failed seed retried without its existing retry interval")
game.tick=19600;routes["periodic-target-scan"]()
assert(storage.tech_priests.consecration.discovery_seeded_0446==true
  and storage.tech_priests.consecration.machines[retry_target.unit_number],
  "incomplete initial membership did not recover")
print("[consecration-retained-registry] PASS initial/config/manual seed;12000ticks without rediscovery; selected visuals and event/chunk membership preserved")
