-- 1268: factory doctrine as an EXPLICIT, read-only engineering preference.
-- Existing doctrine_map is social personality metadata, NEVER an authority to
-- override 0338 construction, 0528 material custody or user-built factories.
-- Recipes, belts, input ports and built item flows remain Factorio-native.
local M={version="1268",read_only=true,actuation_enabled=false}
local Doctrine=require("scripts.core.doctrine_map")
local Flow=require("scripts.core.belt_logistics_contract_1266")

-- Each of the 14 registered social camps has a distinct future organization
-- objective. Only short local belt route tie-breaking is active at this stage;
-- advanced topology plans stay DEFERRED until separate native acceptance.
local policies={
 main_bus={topology="shared-parallel-trunks",phase="P2",
   route="rectilinear-with-spare-corridor",turn_penalty=16,
   axis_penalty=4,requires={"verified-shared-intermediates","reserved-trunk-space","physical-splitter-taps"}},
 sushi={topology="filtered-mixed-item-loop",phase="P4",
   route="local-isolated-until-circuit-verified",turn_penalty=2,
   axis_penalty=0,requires={"verified-circuit-wiring","filtered-loading","backpressure-sensor","closed-loop-conservation"}},
 mixed_spaghetti={topology="minimum-material-local-handoffs",phase="P1",
   route="short-obstacle-aware",turn_penalty=0,axis_penalty=0,requires={"native-placement","actual-inserter-handoffs"}},
 city_block={topology="modular-rectangular-blocks",phase="P3",
   route="cardinal-block-boundaries",turn_penalty=14,
   axis_penalty=6,requires={"reserved-block-footprints","verified-rail-or-robot-interface"}},
 rail_megabase={topology="belt-fed-train-interfaces",phase="P3",
   route="local-loading-cell-only",turn_penalty=10,axis_penalty=2,
   requires={"real-rail-stops","verified-train-custody","real-loading-buffer"}},
 bot_mall={topology="native-logistic-cell-buffers",phase="P3",
   route="bulk-items-on-short-belts",turn_penalty=4,axis_penalty=0,
   requires={"powered-native-logistic-cell","real-robots","provider-requester-stock"}},
 direct_insertion={topology="short-machine-to-machine",phase="P1",
   route="avoid-unnecessary-belts",turn_penalty=0,axis_penalty=0,
   requires={"native-source-and-sink-inserter-geometry"}},
 beaconed_modules={topology="repeatable-high-throughput-rows",phase="P3",
   route="high-rate-parallel-feeds",turn_penalty=14,axis_penalty=3,
   requires={"verified-beacon-footprints","real-module-effects","native-power-budget"}},
 belt_balancer={topology="lane-and-belt-ratio-balancers",phase="P3",
   route="lane-isolated-straight-runs",turn_penalty=12,axis_penalty=4,
   requires={"real-splitters","measured-lane-demand","lane-conservation"}},
 rush_bootstrap={topology="small-local-supply-chain",phase="P1",
   route="first-working-short-route",turn_penalty=2,axis_penalty=0,
   requires={"native-placement","counted-stored-items"}},
 distributed_mini_factories={topology="local-pods-with-buffered-interfaces",phase="P2",
   route="pod-local-then-transfer",turn_penalty=7,axis_penalty=1,
   requires={"observed-pod-consumers","physical-buffer-handoffs"}},
 circuit_control={topology="signal-bounded-belt-feeds",phase="P4",
   route="uncontrolled-local-only",turn_penalty=6,axis_penalty=1,
   requires={"live-circuit-connector","native-control-state","anti-overflow-test"}},
 quality_sorting={topology="quality-isolated-filtered-lanes",phase="P4",
   route="unfiltered-local-only",turn_penalty=8,axis_penalty=2,
   requires={"quality-enabled-item-prototypes","observed-filter-controls","quality-receipt"}},
 space_platform={topology="compact-platform-loop-cells",phase="P4",
   route="surface-specific-local-only",turn_penalty=5,axis_penalty=1,
   requires={"verified-space-platform-surface","native-asteroid-handoffs","closed-loop-item-accounting"}},
}
local function copy_array(a)
 local out={}
 for _,v in ipairs(a or{})do out[#out+1]=v end
 return out
end
function M.policy(key)
 if key==nil then
  return {key=nil,name="No engineering doctrine selected",
   topology="local-route-preflight",phase="P1",
   route="neutral-engine-native",turn_penalty=0,axis_penalty=0,
   requirements={},active_scope="native-legal-local-tie-break-only",
   construction_authorized=false,read_only=true},nil
 end
 local camp=type(key)=="string"and Doctrine.by_key[key]or nil
 local p=camp and policies[key]or nil
 if not p then return nil,"unknown-explicit-factory-doctrine"end
 return{key=key,name=camp.display_name,topology=p.topology,
  phase=p.phase,route=p.route,turn_penalty=p.turn_penalty,
  axis_penalty=p.axis_penalty,requirements=copy_array(p.requires),
  active_scope="native-legal-local-tie-break-only",
  -- An intended main bus or sushi belt is NOT a completed factory.
  advanced_topology_verified=false,construction_authorized=false,
  read_only=true},nil
end

local function axis_of(goal,start)
 if not(goal and start)then return nil end
 return math.abs(goal.x-start.x)>=math.abs(goal.y-start.y)
  and"horizontal"or"vertical"
end

function M.route_preference(key,origin,goal,opts)
 local p,why=M.policy(key)
 if not p then return nil,why end
 local axis=opts and opts.preferred_axis or nil
 if axis~=nil and axis~="horizontal"and axis~="vertical"then
  return nil,"invalid-explicit-corridor-axis"
 end
 p.preferred_axis=axis or axis_of(goal,origin)
 return p,nil
end

-- Pure planner cost. All native placement/collision/ownership checks remain
-- independent and mandatory; doctrine only resolves equal-distance choices.
function M.next_step_score(p,node,direction,goal)
 local nx=node.x+direction.dx
 local ny=node.y+direction.dy
 local distance=math.abs(nx-goal.x)+math.abs(ny-goal.y)
 local changed=node.incoming~=nil and node.incoming~=direction.value
 local off_axis=(p.preferred_axis=="horizontal"and direction.dx==0)
  or(p.preferred_axis=="vertical"and direction.dy==0)
 return distance*100+(changed and p.turn_penalty or 0)
  +(off_axis and p.axis_penalty or 0)
end

-- Recipe dependency amounts are BATCH requirements, not items per minute.
-- Shared inputs may SUGGEST a main bus but no material connection is proven.
function M.organize_requirements(pair,plan,key)
 local p,why=M.policy(key)
 if not p then return nil,why end
 local flows,fwhy=Flow.recipe_requirements(pair,plan,key)
 if not flows then return nil,fwhy end
 local indexed,order={},{}
 for _,item in ipairs(flows.demands)do
  local name=item.item
  if not indexed[name]then
   indexed[name]={item=name,planned_batch_units=0,
    consumer_nodes=0,consumers={},potential_shared_trunk=false}
   order[#order+1]=name
  end
  local rec=indexed[name]
  rec.planned_batch_units=rec.planned_batch_units+item.required_amount
  rec.consumer_nodes=rec.consumer_nodes+1
  rec.consumers[#rec.consumers+1]=item.consumer_recipe
 end
 table.sort(order)
 local summaries,shared={},0
 for _,name in ipairs(order)do
  local r=indexed[name]
  r.potential_shared_trunk=r.consumer_nodes>=2
  if r.potential_shared_trunk then shared=shared+1 end
  summaries[#summaries+1]=r
 end
 return{version=M.version,owner_station_unit=flows.owner_station_unit,
  doctrine=p,distinct_item_requirements=#summaries,
  shared_trunk_candidates=shared,batch_inputs=summaries,
  delegated_fluid_edges=flows.fluid_requirements_delegated,
  status="abstract-batch-demand-only",read_only=true,
  native_source_sink_links=0,measured_spm=nil,
  construction_authorized=false,physical_transport_verified=false},nil
end

-- Native 2.0 LuaEntityPrototype.belt_speed is tiles/tick (both lanes).
-- For an *unstacked straight belt*, density is 4 items/tile/lane;
-- 2 lanes*4*60=480. Never use this as actual inserter throughput, proof of
-- delivered inventory, or a stack-belt/Space Age capacity claim.
function M.capacity_preflight(belt_entity_name,rate_per_min)
 if type(belt_entity_name)~="string"or belt_entity_name==""then
  return nil,"belt-prototype-name-required"
 end
 local needed=tonumber(rate_per_min)
 if not(needed and needed>0 and needed<100000000)then
  return nil,"positive-demand-rate-required"
 end
 local proto=prototypes and prototypes.entity
  and prototypes.entity[belt_entity_name]
 if not(proto and proto.type=="transport-belt")then
  return nil,"native-transport-belt-prototype-unavailable"
 end
 local speed=tonumber(proto.belt_speed)
 if not(speed and speed>0 and speed<100)then
  return nil,"native-belt-speed-unobservable"
 end
 local per_min=speed*480*60
 return{version=M.version,belt_entity=belt_entity_name,
  native_speed_tiles_per_tick=speed,
  unstacked_straight_belt_items_per_minute=per_min,
  requested_items_per_minute=needed,
  provisional_belts=math.max(1,math.ceil(needed/per_min)),
  capacity_model="native-prototype-unstacked-straight-two-lane",
  -- Multimachine inserter rates, geometry, stacking and throughput
  -- could still prohibit this path. Do not award throughput from math.
  actual_delivery_proven=false,read_only=true,
  construction_authorized=false},nil
end

return M
