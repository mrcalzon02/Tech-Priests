-- Tech Priests 0.1.674-dev planning constraints and phased hardener installation.
-- The canonical registry-backed broker is installed before any hardener prearm.
-- Every hardener install must return literal true. Final broker failure prevents
-- periodic hardeners from installing through direct timing fallbacks.

local M={version="0.1.674-dev",perimeter_band=4.0,perimeter_tolerance=2.25,
 install_results={},install_failures={},prearm_results={},prearm_failures={},
 install_complete=false,install_phase="unarmed",degraded_families={},broker_prearm={}}
local item_by_entity,unlock_cache_tick,unlock_cache={},-1,{}
local function valid(e)return e and e.valid end
local function safe(v)local ok,s=pcall(tostring,v);return ok and s or"?"end
local function dist_sq(a,b)local x=(a.x or 0)-(b.x or 0);local y=(a.y or 0)-(b.y or 0);return x*x+y*y end
local function pair_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function radius_for(pair)
 if not(pair and valid(pair.station))then return 0 end
 if type(_G.refresh_pair_radius)=="function"then local ok,r=pcall(_G.refresh_pair_radius,pair);if ok and tonumber(r)then return math.max(8,tonumber(r))end end
 if type(_G.get_station_operating_radius)=="function"then local ok,r=pcall(_G.get_station_operating_radius,pair.station);if ok and tonumber(r)then return math.max(8,tonumber(r))end end
 return math.max(8,tonumber(pair.radius or pair.base_radius)or 20)
end
local function recipe_produces(recipe,item)
 local products;pcall(function()products=recipe.products end)
 for _,p in pairs(products or{})do local n;pcall(function()n=p.name or p[1]end);if n==item then return true end end
 local main;pcall(function()main=recipe.main_product end);return main and(main.name or main)==item or false
end
function M.item_for_entity(entity_name)
 if not(entity_name and prototypes and prototypes.item)then return nil end
 if item_by_entity[entity_name]~=nil then return item_by_entity[entity_name]or nil end
 for item_name,item in pairs(prototypes.item)do local place;pcall(function()place=item.place_result end);if place and place.name==entity_name then item_by_entity[entity_name]=item_name;return item_name end end
 item_by_entity[entity_name]=false;return nil
end
function M.item_unlocked(force,item_name)
 if not(force and force.valid and item_name and force.recipes)then return false,"invalid-force-or-item"end
 local tick=game and game.tick or 0;if unlock_cache_tick~=tick then unlock_cache_tick,unlock_cache=tick,{}end
 local key=tostring(force.index or force.name or"?")..":"..item_name
 if unlock_cache[key]~=nil then return unlock_cache[key],unlock_cache[key]and"enabled-recipe"or"technology-locked-or-no-enabled-recipe"end
 for _,recipe in pairs(force.recipes)do local enabled=false;pcall(function()enabled=recipe.enabled==true end);if enabled and recipe_produces(recipe,item_name)then unlock_cache[key]=true;return true,"enabled-recipe"end end
 unlock_cache[key]=false;return false,"technology-locked-or-no-enabled-recipe"
end
function M.entity_unlocked(pair,entity_name)
 if not(pair and valid(pair.station)and entity_name)then return false,"invalid-pair-or-entity"end
 local item=M.item_for_entity(entity_name);if not item then return false,"no-placeable-item"end
 local unlocked,why=M.item_unlocked(pair.station.force,item);return unlocked,why,item
end
function M.interior_position_allowed(pair,position,margin)
 if not(pair and valid(pair.station)and position)then return false,"invalid"end
 local radius=radius_for(pair);local interior=math.max(3,radius-(tonumber(margin)or M.perimeter_band))
 if dist_sq(pair.station.position,position)>interior*interior then return false,"reserved-defense-perimeter"end
 return true,"interior-owned"
end
function M.defense_position_allowed(pair,position,tolerance)
 if not(pair and valid(pair.station)and position)then return false,"invalid"end
 local radius=radius_for(pair);local distance=math.sqrt(dist_sq(pair.station.position,position))
 if math.abs(distance-radius)>(tonumber(tolerance)or M.perimeter_tolerance)then return false,"outside-defense-perimeter-band"end
 for _,other in pairs(pair_map())do
  if other~=pair and other and valid(other.station)and other.station.surface==pair.station.surface and other.station.force==pair.station.force then
   local other_radius=radius_for(other);if dist_sq(other.station.position,position)<=other_radius*other_radius then return false,"overlaps-station-control:"..tostring(other.station.unit_number or"?")end
  end
 end
 return true,"defense-territory-owned"
end

local FAMILY_TARGETS={
 direct={"scripts.core.direct_acquisition_executor_0513"},
 movement={"scripts.core.direct_acquisition_executor_0513","scripts.core.consecration_executor_0515","scripts.core.repair_executor_0516","scripts.core.logistics_machine_fulfillment_0528"},
 repair={"scripts.core.repair_executor_0516","scripts.core.combat_repair_doctrine_0517"},
 machine={"scripts.core.logistics_machine_fulfillment_0528"},
 storage={"scripts.core.logistics_machine_fulfillment_0528","scripts.core.item_family_logistics_0702","scripts.core.energy_family_logistics_0707","scripts.core.rocket_silo_logistics_0710","scripts.core.artillery_logistics_0713","scripts.core.roboport_repair_pack_logistics_0715"},
 fluid={"scripts.core.fluid_connection_planner_0691","scripts.core.fluid_output_connection_planner_0696","scripts.core.fluid_turret_connection_planner_0719"},
 item={"scripts.core.item_family_logistics_0702"},energy={"scripts.core.energy_family_logistics_0707"},
 silo={"scripts.core.rocket_silo_logistics_0710"},artillery={"scripts.core.artillery_logistics_0713"},
 roboport={"scripts.core.roboport_repair_pack_logistics_0715"},turret={"scripts.core.fluid_turret_connection_planner_0719"},
 runtime={"scripts.core.single_dispatcher_0510"},
}
local function family_for(label)
 label=tostring(label or"")
 if label:find("direct_acquisition",1,true)then return"direct"end
 if label:find("movement_",1,true)then return"movement"end
 if label:find("combat_repair",1,true)or label:find("repair_executor",1,true)then return"repair"end
 if label:find("machine_logistics",1,true)then return"machine"end
 if label:find("storage_role",1,true)or label:find("inventory_transfer",1,true)then return"storage"end
 if label:find("fluid_turret",1,true)then return"turret"end
 if label:find("fluid_",1,true)or label:find("reservation_position",1,true)then return"fluid"end
 if label:find("item_family",1,true)then return"item"end
 if label:find("energy_",1,true)or label:find("fusion_reactor",1,true)then return"energy"end
 if label:find("rocket_silo",1,true)then return"silo"end
 if label:find("artillery",1,true)then return"artillery"end
 if label:find("roboport",1,true)then return"roboport"end
 return"runtime"
end
local function disable_target(module_name,family,reason)
 local ok,mod=pcall(require,module_name);if not(ok and mod)then return false end
 local disabled=false
 if type(mod.root)=="function"then local ok_root,state=pcall(mod.root);if ok_root and type(state)=="table"then state.enabled=false;state.recovery_degraded_0744=true;state.recovery_degraded_reason_0744=tostring(reason);disabled=true end end
 if mod.enabled~=nil then mod.enabled=false;disabled=true end
 mod.recovery_degraded_0744=true;mod.recovery_degraded_reason_0744=tostring(reason);return disabled
end
local function degrade_failure(failure)
 local family=family_for(failure.label);M.degraded_families[family]=M.degraded_families[family]or{family=family,failures={},targets_disabled=0}
 local rec=M.degraded_families[family];rec.failures[#rec.failures+1]={label=failure.label,module=failure.module,reason=failure.reason}
 for _,module_name in ipairs(FAMILY_TARGETS[family]or{})do if disable_target(module_name,family,failure.label..":"..failure.reason)then rec.targets_disabled=rec.targets_disabled+1 end end
 return family
end
local function ensure_broker(phase)
 local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
 if not broker then local ok,loaded=pcall(require,"scripts.core.runtime_tick_broker");if ok then broker=loaded else return false,"broker-require-failed:"..safe(loaded)end end
 if not(broker and type(broker.install)=="function")then return false,"broker-install-unavailable"end
 local ok,result=pcall(broker.install);if not(ok and result==true)then return false,ok and("broker-install-return:"..safe(result))or("broker-install-error:"..safe(result))end
 local summary=type(broker.installation_summary)=="function"and broker.installation_summary()or nil
 if not(summary and summary.complete==true and summary.installed==true and summary.route_registered==true and summary.route_id=="runtime_tick_broker_0600:central-pulse")then return false,"broker-route-incomplete"end
 M.broker_prearm={phase=phase,complete=true,reason="canonical-broker-ready",route_id=summary.route_id};return true,"canonical-broker-ready"
end
local function install_hardener(module_name,label)
 local ok,mod=pcall(require,module_name)
 if not(ok and mod and type(mod.install)=="function")then return false,ok and"module missing install()"or tostring(mod)end
 local ok_install,result=pcall(mod.install)
 if not ok_install then return false,tostring(result)end
 if result~=true then return false,"install must return literal true; received "..tostring(result)end
 return true,"installed"
end
local function attempt_all(phase)
 local results,failures,attempted,passed={},{},0,0
 local function install(module_name,label)
  attempted=attempted+1;local ok,reason=install_hardener(module_name,label)
  results[label]={module=module_name,ok=ok==true,reason=tostring(reason or""),phase=phase}
  if ok then passed=passed+1 else failures[#failures+1]={module=module_name,label=label,reason=tostring(reason or"unknown")}end
  return ok
 end
 install("scripts.core.direct_acquisition_physical_guard_0649","direct_acquisition_physical_guard_0649")
 install("scripts.core.proxy_ammo_hardener_0649","proxy_ammo_hardener_0649")
 install("scripts.core.direct_acquisition_movement_lock_0650","direct_acquisition_movement_lock_0650")
 install("scripts.core.movement_target_reconciler_0652","movement_target_reconciler_0652")
 install("scripts.core.movement_intent_authority_0654","movement_intent_authority_0654")
 install("scripts.core.construction_placement_authority_0656","construction_placement_authority_0656")
 install("scripts.core.active_leaf_task_truth_0655","active_leaf_task_truth_0655")
 install("scripts.core.logistics_mineable_source_bridge_0657","logistics_mineable_source_bridge_0657")
 install("scripts.core.visual_intent_line_authority_0657","visual_intent_line_authority_0657")
 install("scripts.core.repair_executor_integrity_0673","repair_executor_integrity_0673")
 install("scripts.core.combat_repair_integrity_0676","combat_repair_integrity_0676")
 install("scripts.core.combat_repair_terminal_cleanup_0677","combat_repair_terminal_cleanup_0677")
 install("scripts.core.machine_logistics_integrity_0682","machine_logistics_integrity_0682")
 install("scripts.core.machine_logistics_candidate_recovery_0683","machine_logistics_candidate_recovery_0683")
 install("scripts.core.machine_logistics_final_authority_0684","machine_logistics_final_authority_0684")
 install("scripts.core.storage_role_authority_0686","storage_role_authority_0686")
 install("scripts.core.inventory_transfer_integrity_0687","inventory_transfer_integrity_0687")
 install("scripts.core.fluid_network_doctrine_0689","fluid_network_doctrine_0689")
 install("scripts.core.fluid_output_sink_doctrine_0694","fluid_output_sink_doctrine_0694")
 install("scripts.core.reservation_position_scope_0697","reservation_position_scope_0697")
 install("scripts.core.fluid_connection_planner_0691","fluid_connection_planner_0691")
 install("scripts.core.fluid_connection_execution_guard_0692","fluid_connection_execution_guard_0692")
 install("scripts.core.fluid_output_connection_planner_0696","fluid_output_connection_planner_0696")
 install("scripts.core.fluid_port_collision_validator_0699","fluid_port_collision_validator_0699")
 install("scripts.core.fluid_port_context_guard_0700","fluid_port_context_guard_0700")
 install("scripts.core.item_family_logistics_0702","item_family_logistics_0702")
 install("scripts.core.item_family_integrity_0703","item_family_integrity_0703")
 install("scripts.core.energy_family_readiness_0705","energy_family_readiness_0705")
 install("scripts.core.fusion_reactor_readiness_guard_0727","fusion_reactor_readiness_guard_0727")
 install("scripts.core.energy_readiness_diagnostics_0711","energy_readiness_diagnostics_0711")
 install("scripts.core.energy_family_logistics_0707","energy_family_logistics_0707")
 install("scripts.core.energy_item_automation_guard_0722","energy_item_automation_guard_0722")
 install("scripts.core.energy_automation_guard_install_assertion_0726","energy_automation_guard_install_assertion_0726")
 install("scripts.core.rocket_silo_readiness_0709","rocket_silo_readiness_0709")
 install("scripts.core.rocket_silo_logistics_0710","rocket_silo_logistics_0710")
 install("scripts.core.rocket_silo_live_ownership_guard_0728","rocket_silo_live_ownership_guard_0728")
 install("scripts.core.artillery_readiness_0712","artillery_readiness_0712")
 install("scripts.core.artillery_logistics_0713","artillery_logistics_0713")
 install("scripts.core.artillery_train_validity_guard_0724","artillery_train_validity_guard_0724")
 install("scripts.core.roboport_readiness_0714","roboport_readiness_0714")
 install("scripts.core.roboport_repair_pack_logistics_0715","roboport_repair_pack_logistics_0715")
 install("scripts.core.fluid_turret_readiness_0716","fluid_turret_readiness_0716")
 install("scripts.core.fluid_turret_internal_buffer_guard_0731","fluid_turret_internal_buffer_guard_0731")
 install("scripts.core.fluid_turret_connection_proposals_0717","fluid_turret_connection_proposals_0717")
 install("scripts.core.fluid_turret_proposal_integrity_0718","fluid_turret_proposal_integrity_0718")
 install("scripts.core.fluid_turret_connection_planner_0719","fluid_turret_connection_planner_0719")
 install("scripts.core.fluid_turret_planner_integrity_0730","fluid_turret_planner_integrity_0730")
 install("scripts.core.movement_vector_enforcer_0651","movement_vector_enforcer_0651")
 install("scripts.core.development_integration_audit_0721","development_integration_audit_0721")
 install("scripts.core.runtime_command_cleanup_0720","runtime_command_cleanup_0720")
 install("scripts.core.migration_pair_integrity_0734","migration_pair_integrity_0734")
 install("scripts.core.development_lifecycle_checkpoint_0733","development_lifecycle_checkpoint_0733")
 install("scripts.core.broker_registry_integrity_0725","broker_registry_integrity_0725")
 install("scripts.core.migration_lifecycle_assertion_0735","migration_lifecycle_assertion_0735")
 install("scripts.core.hardener_installation_audit_0723","hardener_installation_audit_0723")
 return{phase=phase,results=results,failures=failures,attempted=attempted,passed=passed,complete=#failures==0}
end
local function broker_failure_snapshot(phase,reason)
 return{phase=phase,results={},failures={{module="scripts.core.runtime_tick_broker",label="runtime_tick_broker_0600",reason=tostring(reason)}},attempted=0,passed=0,complete=false}
end
function M.finalize_installation(reason)
 M.install_phase="finalizing";local broker_ok,broker_reason=ensure_broker("post-loader");local snapshot=broker_ok and attempt_all("post-loader")or broker_failure_snapshot("post-loader",broker_reason)
 M.install_results=snapshot.results;M.install_failures=snapshot.failures;M.install_attempted=snapshot.attempted;M.install_passed=snapshot.passed;M.install_complete=snapshot.complete
 M.install_phase=snapshot.complete and"complete"or"degraded";M.finalized_reason=tostring(reason or"post-loader");M.degraded_families={}
 if not snapshot.complete then for _,failure in ipairs(snapshot.failures)do degrade_failure(failure)end end
 storage.tech_priests=storage.tech_priests or{};storage.tech_priests.recovery_installation_0744={version=M.version,phase=M.install_phase,complete=M.install_complete,attempted=M.install_attempted,passed=M.install_passed,failed=#M.install_failures,reason=M.finalized_reason,broker=M.broker_prearm,degraded_families=M.degraded_families}
 if log then log("[Tech-Priests recovery] final hardener installation attempted="..M.install_attempted.." passed="..M.install_passed.." failed="..#M.install_failures.." phase="..M.install_phase.." broker="..safe(M.broker_prearm.reason))end
 return M.install_complete
end
function M.installation_summary()return{version=M.version,phase=M.install_phase,complete=M.install_complete==true,attempted=M.install_attempted or 0,passed=M.install_passed or 0,failed=#(M.install_failures or{}),failures=M.install_failures or{},prearm_failed=#(M.prearm_failures or{}),broker=M.broker_prearm,degraded_families=M.degraded_families or{}}end
function M.feature_available(family)return M.install_complete==true or M.degraded_families[tostring(family or"runtime")]==nil end
function M.install()
 _G.TechPriestsPlanningConstraints0646=M;local broker_ok,broker_reason=ensure_broker("prearm")
 if not broker_ok then M.install_phase="broker-unavailable";M.broker_prearm={phase="prearm",complete=false,reason=tostring(broker_reason)};M.prearm_results={};M.prearm_failures={{module="scripts.core.runtime_tick_broker",label="runtime_tick_broker_0600",reason=tostring(broker_reason)}};M.prearm_attempted=0;M.prearm_passed=0;return false end
 local snapshot=attempt_all("prearm");M.prearm_results=snapshot.results;M.prearm_failures=snapshot.failures;M.prearm_attempted=snapshot.attempted;M.prearm_passed=snapshot.passed;M.install_phase="prearmed";return true
end
return M
