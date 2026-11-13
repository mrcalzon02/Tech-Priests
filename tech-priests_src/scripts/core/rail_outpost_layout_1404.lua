-- 1404: pure capacity sizing for a remote rail outpost.
-- Strategic sizing is NOT site placement, native train proof, inventory custody
-- or an authorization to place ghosts. 0510/0338 retain all physical work.
local M={version="0.1.676.1404",read_only=true,max_wagons=8,max_drills=128}
local function finite(n)
  return type(n)=="number" and n==n and n<math.huge and n>-math.huge
end
local function positive(n)
  return finite(n) and n>0 and n<=100000000
end
local function whole(n,min,max)
  return finite(n) and n==math.floor(n) and n>=min and n<=max
end
local function ceil(n)
  return math.ceil(n-0.000000001)
end
local function fail(reason) return nil,reason end
local function numeric(o,key)
  local value=o[key]
  if not positive(value) then return nil,"missing-or-invalid-"..key end
  return value
end
local function label(name)
  return type(name)=="string" and #name>0 and #name<=100
end

-- Observations are provided by native engine/prototype adapters, never
-- manufactured by this optimizer. "Most efficient" means minimum modeled
-- construction cost among bounded candidates meeting a specified throughput.
-- A live site, actual chest adjacency, drill footprint, inventory counts,
-- signals, train path and unloading physics require separate proof.
function M.plan(o)
  if type(o)~="table" then return fail("invalid-outpost-observations") end
  if not(label(o.item) and o.item_type~="fluid") then
    return fail("item-only-outpost-required")
  end
  local required={
    "demand_items_per_second","drill_items_per_second",
    "train_travel_seconds","loading_seconds","unloading_seconds",
    "belt_items_per_second","inserter_items_per_second",
  }
  for _,key in ipairs(required)do
    local _,err=numeric(o,key)
    if err then return fail(err) end
  end
  if not(whole(o.ore_drill_sites,1,M.max_drills)
      and whole(o.item_stack_size,1,1000000)
      and whole(o.wagon_slots,1,1000)
      and whole(o.chest_slots,1,1000))then
    return fail("native-capacity-or-ore-site-count-invalid")
  end
  local cap=o.max_wagons or M.max_wagons
  if not whole(cap,1,M.max_wagons) then
    return fail("wagon-budget-invalid")
  end
  local max_load=o.max_loaders_per_wagon or 6
  local max_chests=o.max_chests_per_wagon or 6
  if not(whole(max_load,1,12)
    and whole(max_chests,1,12))then
    return fail("loading-footprint-budget-invalid")
  end
  if o.train_direction_policy~="reversible"
      and o.train_direction_policy~="turnaround-loop" then
    return fail("train-return-direction-not-specified")
  end
  local locomotives=o.train_direction_policy=="reversible" and 2 or 1
  local reserve=o.reserve_factor or 1.1
  local efficiency=o.transfer_efficiency or 0.8
  if not(finite(reserve) and reserve>=1 and reserve<=2
      and finite(efficiency) and efficiency>=0.25
      and efficiency<=1)then
    return fail("capacity-margins-invalid")
  end
  local train_limit=o.max_train_vehicles
  if train_limit~=nil and not whole(train_limit,2,20) then
    return fail("native-train-vehicle-clearance-invalid")
  end
  local effective=o.demand_items_per_second*reserve
  local drills=ceil(effective/o.drill_items_per_second)
  if not whole(drills,1,M.max_drills)
      or drills>o.ore_drill_sites then
    return fail("drill-capacity-or-real-sites-insufficient")
  end
  local item_per_chest=o.item_stack_size*o.chest_slots
  local item_per_wagon=o.item_stack_size*o.wagon_slots
  local cycle=o.train_travel_seconds+o.loading_seconds
    +o.unloading_seconds
  local load_batch=effective*cycle
  if not(finite(cycle) and cycle>0 and finite(load_batch)
      and load_batch<=100000000)then
    return fail("train-cycle-unbounded")
  end
  local belt_lanes=ceil(effective/o.belt_items_per_second)
  if not whole(belt_lanes,1,32)then
    return fail("belt-lane-budget-exceeded")
  end
  local best,best_score=nil,nil
  for wagons=1,cap do
    if not train_limit or wagons+locomotives<=train_limit then
      local capacity=wagons*item_per_wagon
      if capacity>=load_batch then
        local per_wagon=load_batch/wagons
        local burst=o.inserter_items_per_second*efficiency
        local loaders=ceil(per_wagon/(o.loading_seconds*burst))
        local unloaders=ceil(per_wagon/(o.unloading_seconds*burst))
        local buffers=math.max(loaders,
          ceil(per_wagon/item_per_chest))
        local feeders=math.max(buffers,
          ceil(effective/wagons/burst))
        local spurs=math.max(1,
          ceil(effective/wagons/o.belt_items_per_second))
        if loaders<=max_load and unloaders<=max_load
          and buffers<=max_chests and feeders<=max_chests
          and spurs<=4 then
          local build={
            locomotives=locomotives,cargo_wagons=wagons,
            drills=drills,loading_train_stops=1,
            home_unloading_train_stops=1,
            loading_buffer_chests=wagons*buffers,
            feed_inserters=wagons*feeders,
            loading_inserters=wagons*loaders,
            home_unloading_inserters=wagons*unloaders,
            belt_trunk_lanes=belt_lanes,
            belt_spur_lanes=wagons*spurs,
            minimum_splitters=math.max(0,wagons-1),
            remote_cogitator_stations=1,
          }
          -- Relative-weight *model*, not universal optimality. Never give
          -- a belt-tile/rail-item bill without path geometry. A larger
          -- train may be cheaper in throughput terms but consumes materials.
          local score=wagons*100+locomotives*60+drills*16
            +build.loading_buffer_chests*8
            +(build.feed_inserters+build.loading_inserters
              +build.home_unloading_inserters)*5
            +(belt_lanes+build.belt_spur_lanes)*9
            +build.minimum_splitters*12
          if not best_score or score<best_score then
            local cells={}
            for i=1,wagons do
              cells[i]={
                wagon_index=i,
                buffer_chests=buffers,
                feed_inserters=feeders,
                loading_inserters=loaders,
                home_unloading_inserters=unloaders,
                belt_spurs=spurs,
                max_buffer_items=buffers*item_per_chest,
                target_batch_items=per_wagon,
                status="virtual-unplaced",
              }
            end
            best={
              version=M.version,read_only=true,ghosts_created=0,
              status="provisional-measured-capacity-layout",
              construction_authorized=false,
              physical_transport_verified=false,
              train_path_verified=false,
              native_site_verified=false,
              item=o.item,
              train_direction_policy=o.train_direction_policy,
              requested_items_per_second=o.demand_items_per_second,
              design_items_per_second=effective,
              expected_train_cycle_seconds=cycle,
              target_batch_items=load_batch,
              full_train_capacity_items=capacity,
              per_wagon_capacity_items=item_per_wagon,
              projected_trips_per_hour=3600/cycle,
              observed_drill_sites=o.ore_drill_sites,
              required_drills=drills,
              train_vehicle_count=wagons+locomotives,
              max_native_site_train_vehicles=train_limit,
              modeled_cost=score,
              cost_model="bounded-material-and-footprint-proxy",
              inventory_items_per_chest=item_per_chest,
              counts=build,cells=cells,
              -- These are build obligations, not placement requests.
              layers={
                {name="site-survey",requires={"charted-natural-resource","native-rail-clearance","station-hierarchy"}},
                {name="track-and-stops",requires={"native-outbound-and-return-route","paid-rails","signals-and-stop-side"}},
                {name="power-and-coverage",requires={"native-power-grid","local-drill-and-inserter-power"}},
                {name="drills",count=drills,requires={"real-ore-drill-sites","physical-stock"}},
                {name="belt-trunks",count=belt_lanes,requires={"native-route","splitter-geometry","physical-stock"}},
                {name="loading-buffers",count=build.loading_buffer_chests,requires={"native-wagon-adjacency","physical-stock"}},
                {name="feed-and-load-inserters",count=build.feed_inserters+build.loading_inserters,requires={"observed-pickup-drop","physical-stock"}},
                {name="rolling-stock",count=wagons+locomotives,requires={"original-0338-debits","native-train-coupling"}},
                {name="home-unloading",count=build.home_unloading_inserters,requires={"verified-home-receivers","native-pickup-drop"}},
                {name="commissioning",requires={"native-train-path-both-directions","mined-ore-receipt","save-reload"}},
              },
              unresolved={
                "precise-native-build-positions","rail-and-belt-tile-quantities",
                "drill-output-to-belt-geometry","wagon-loading-adjacency",
                "power-pole-placements","native-signal-blocks",
                "physical-stock-and-construction-custody",
                "train-ride-out-and-back","continuous-flow-acceptance",
              },
            }
            best_score=score
          end
        end
      end
    end
  end
  if not best then
    return fail("no-feasible-train-and-loader-combination")
  end
  return best,"provisional-layout-computed"
end
return M
