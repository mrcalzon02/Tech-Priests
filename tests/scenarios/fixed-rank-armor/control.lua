-- Native fixture uses the actual generated owners and recipe authority.
TechPriestsRuntimeEventRegistry=require("scripts.core.runtime_event_registry")
TechPriestsGuiRouter=require("scripts.gui.gui_router")
local Policy=require("scripts.core.planning_constraints_0646")
TechPriestsPlanningConstraints0646=Policy
function ensure_storage()
  storage.tech_priests=storage.tech_priests or {pairs_by_station={}}
  storage.tech_priests.pairs_by_station=storage.tech_priests.pairs_by_station or {}
end
function tech_priests_0293_log()end
require("scripts.generated.control_legacy_part_019")
require("scripts.generated.control_legacy_part_020")
find_pair_for_entity=function(entity)
  local pair=storage.armor_probe and storage.armor_probe.pair
  if pair and (entity==pair.priest or entity==pair.station)then return pair end
end
local function check_routes()
  local routes=TechPriestsRuntimeEventRegistry.nth_tick_routes
  assert(not routes["811"] or #routes["811"]==0,"retired force armor timer installed")
  assert(routes["887"] and #routes["887"]>0,"fixed-rank armor service missing")
end
local function check_live_gates(force)
  force.recipes["heavy-armor"].enabled=false
  force.recipes["native-armor-alias"].enabled=false
  assert(not tech_priests_0302_force_can_use_armor(force,"heavy-armor"))
  local names=Policy.recipe_names_for_item(force,"heavy-armor",true)
  for _=1,100 do
    assert(not tech_priests_0302_force_can_use_armor(game.forces.player,"heavy-armor"))
    assert(Policy.recipe_names_for_item(game.forces.player,"heavy-armor",true)==names,
      "native force wrapper rebuilt recipe membership")
  end
  force.recipes["native-armor-alias"].enabled=true
  assert(tech_priests_0302_force_can_use_armor(force,"heavy-armor"),"live alias unlock missed")
  force.recipes["native-armor-alias"].enabled=false
  assert(not tech_priests_0302_force_can_use_armor(force,"heavy-armor"),"live disable missed")
  force.recipes["native-armor-alias"].enabled=true
end
script.on_init(function()
  ensure_storage();check_routes();check_live_gates(game.forces.player)
  local surface=game.surfaces[1]
  surface.set_tiles({{name="grass-1",position={0,0}},{name="grass-1",position={4,0}}})
  local priest=assert(surface.create_entity{name="junior-tech-priest",position={0,0},force="player"})
  local station=assert(surface.create_entity{name="wooden-chest",position={4,0},force="player"})
  local pair={priest=priest,station=station,station_unit=station.unit_number}
  storage.tech_priests.pairs_by_station[station.unit_number]=pair
  storage.armor_probe={pair=pair}
  local profile=tech_priests_0297_apply_profile_to_pair(pair,"native-build-chain")
  assert(profile and profile.name=="heavy-armor" and pair.fixed_armor_profile_0302==profile)
  assert(not storage.tech_priests.armor_profiles_0297,"retired force profile was rebuilt")
  log("[TP-ARMOR-NATIVE-CREATE] "..helpers.table_to_json({passed=true,
    retired811=true,kept887=true,live_alias_gate=true,native_force_membership_reused=true,
    fixed_rank_compatibility=true,warm_questions=100}))
end)
TechPriestsRuntimeEventRegistry.on_event(defines.events.on_tick,function(event)
  if event.tick~=1 then return end
  check_routes();check_live_gates(game.forces.player)
  local pair=storage.armor_probe.pair
  local profile=tech_priests_0297_apply_profile_to_pair(pair,"native-reload")
  assert(profile and profile.name=="heavy-armor")
  pair.priest.health=200
  pair.priest.damage(100,game.forces.enemy,"physical")
  assert(pair.priest.health>100 and pair.priest.health<=200,"native armor mitigation failed")
  assert(pair.last_armor_mitigation_0302 and pair.last_armor_mitigation_0302.fixed_rank,
    "native damage event did not reach fixed-rank owner")
  assert(not storage.tech_priests.armor_profiles_0297,"reload recreated retired force armor")
  assert((TechPriestsRuntimeEventRegistry.stats.handler_errors or 0)==0,"native event handler failed")
  log("[TP-ARMOR-NATIVE-PASS] "..helpers.table_to_json({passed=true,tick=event.tick,
    reload=true,live_alias_gate=true,native_damage=true,health=pair.priest.health,
    armor=pair.fixed_armor_profile_0302.name,retired811=true,kept887=true}))
end,nil,{owner="native-armor-fixture",route="verify",priority=1000000})
