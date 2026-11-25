-- Native Factorio fixture: actual ratio planner, native force recipes and
-- immutable resource prototype membership, including a fresh save reload.
local Policy=require("scripts.core.planning_constraints_0646")
require("scripts.core.prototype_compat")
tech_priests_0255_current_planning_item=function()return "automation-science-pack"end
TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255={
  assemblers={"assembling-machine-1"},smelters={"stone-furnace"},
  miners={"electric-mining-drill"},labs={"lab"},
  power={"small-electric-pole"},chemical={},oil={}}
require("scripts.magos_ratio_planning")
local function check(pair,phase)
  local force=pair.station.force
  force.recipes["automation-science-pack"].enabled=true
  force.recipes["iron-plate"].enabled=true
  local plan=tech_priests_0257_build_ratio_plan(pair,{})
  assert(plan.graph_complete_1189 and plan.recipes["automation-science-pack"]
    and plan.recipes["iron-gear-wheel"] and plan.recipes["iron-plate"]
    and plan.raw_items["iron-ore"]==0.5 and plan.raw_items["copper-ore"]==0.25,
    "native indexed ratio graph changed its actual material demand")
  local recipes=Policy.recipe_names_for_item(force,"iron-plate",true)
  local resources=Policy.resource_names_for_product("iron-ore")
  assert(#recipes>0 and #resources==1 and resources[1]=="iron-ore")
  for _=1,100 do
    local live_force=game.forces.player
    assert(Policy.recipe_names_for_item(live_force,"iron-plate",true)==recipes,
      "native force wrapper rebuilt recipe membership")
    assert(Policy.resource_names_for_product("iron-ore")==resources,
      "native resource membership was rebuilt")
    assert(tech_priests_0257_build_ratio_plan(pair,{}).raw_items["iron-ore"]==0.5)
  end
  force.recipes["iron-plate"].enabled=false
  local locked=tech_priests_0257_build_ratio_plan(pair,{})
  assert(not locked.graph_complete_1189
    and locked.unresolved_reasons_1189["iron-plate"]=="recipe-locked-for-force",
    "native same-tick disablement was hidden by membership")
  force.recipes["iron-plate"].enabled=true
  assert(tech_priests_0257_build_ratio_plan(pair,{}).graph_complete_1189,
    "native same-tick enablement was missed")
  log("[TP-MAGOS-RETAINED-PLANNING] "..helpers.table_to_json({
    passed=true,phase=phase,warm_questions=100,live_force_gates=true,
    native_recipe_membership_reused=true,native_resource_membership_reused=true,
    actual_material_graph=true,observed_spm=plan.observed_spm}))
end
script.on_init(function()
  local surface=game.surfaces[1]
  surface.set_tiles({{name="grass-1",position={0,0}}})
  local station=assert(surface.create_entity{
    name="wooden-chest",position={0,0},force="player"})
  storage.fixture_pair={station=station,science_spm_target_1133=15}
  check(storage.fixture_pair,"create")
end)
script.on_event(defines.events.on_tick,function(event)
  if event.tick==1 then check(storage.fixture_pair,"reload")end
end)
