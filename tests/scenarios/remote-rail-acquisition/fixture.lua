-- Factorio-native test-only distant-resource TRAIN acceptance, independent
-- of ranked Cogitator relays. Test fixture seeds supply and technology only.
-- It NEVER creates rails, locomotives, wagons, miners or mined cargo.
local M={}
local Frontier=require("scripts.core.rail_track_frontier_0836")
local PREFIX="[TP-REMOTE-RAIL-TEST] "
-- Keep the native target inside the production builder's counted segment
-- budget, using the last REAL item-debited rail, not an unbuilt next step.
local MAX_NATIVE_TARGET_X=math.min(960,
  Frontier.start_offset+Frontier.segment_step*(Frontier.max_segments-1)
  +Frontier.destination_clearance)
local STATION={x=0,y=0}
local ORE -- Selected from pre-existing native world-generated iron ore.
local KEY="ci_remote_rail_acquisition"
local function emit(msg)log(PREFIX..msg)end
local function fail(msg)error(PREFIX.."FAIL "..msg)end
local function root()
  storage.tech_priests=storage.tech_priests or {}
  local s=storage.tech_priests[KEY] or {}
  storage.tech_priests[KEY]=s
  return s
end
local function count(surface,opts)
  return #surface.find_entities_filtered(opts)
end
-- A no-player headless force may retain queued LuaForce.chart requests.
-- Give it a REAL powered vanilla radar close enough for native nearby scans.
-- This is isolated test-world *initial scouting infrastructure*, never a
-- robot/rail builder, resource source, or acceptance credit. Its electricity
-- comes from ordinary engine-operated solar panels on the same copper network.
local function seed_native_radar_chart_infrastructure(surface,force,ore)
  local offsets={{48,48},{72,48},{48,-48},{72,-48},
    {48,72},{72,72},{96,0},{96,48}}
  local panels={{-2,-6},{2,-6},{6,-6},{10,-6},
    {-2,6},{2,6},{6,6},{10,6}}
  for _,offset in ipairs(offsets) do
    local base={x=math.floor(ore.x)+offset[1],
      y=math.floor(ore.y)+offset[2]}
    local area={{base.x-12,base.y-12},{base.x+15,base.y+12}}
    surface.request_to_generate_chunks(base,2)
    surface.force_generate_chunk_requests()
    -- NEVER erase another natural resource as a side effect of choosing a
    -- chart observer. If this pad has ore, try another existing world site.
    if count(surface,{type="resource",area=area})==0 then
      local tiles={}
      for xx=base.x-12,base.x+14 do
        for yy=base.y-12,base.y+11 do
          tiles[#tiles+1]={name="grass-1",position={xx,yy}}
        end
      end
      surface.set_tiles(tiles,true)
      for _,entity in ipairs(surface.find_entities_filtered{area=area}) do
        if entity.valid and (entity.type=="tree" or entity.type=="cliff"
            or entity.type=="simple-entity") then entity.destroy() end
      end
      local entries={{name="radar",position=base},
        {name="substation",position={x=base.x+6,y=base.y}}}
      for _,p in ipairs(panels) do
        entries[#entries+1]={name="solar-panel",
          position={x=base.x+p[1],y=base.y+p[2]}}
      end
      local clear=true
      for _,entry in ipairs(entries) do
        if not surface.can_place_entity{
            name=entry.name,position=entry.position,force=force} then
          clear=false;break
        end
      end
      if clear then
        local radar
        for _,entry in ipairs(entries) do
          local entity=surface.create_entity{
            name=entry.name,position=entry.position,
            force=force,raise_built=true}
          if not (entity and entity.valid) then
            fail("CHART_RADAR_PHYSICAL_INFRASTRUCTURE_PLACEMENT "..entry.name)
          end
          if entry.name=="radar" then radar=entity end
        end
        return radar,base,#panels
      end
    end
  end
  fail("CHART_NATIVE_POWERED_RADAR_SITE_UNAVAILABLE")
end
local function setup()
  local s=root()
  if s.started then return end
  local surface,force=game.surfaces[1],game.forces.player
  local necessary={"planetary-magos-cogitator-station","straight-rail",
    "locomotive","cargo-wagon","burner-mining-drill","iron-ore"}
  for _,n in ipairs(necessary) do
    if not prototypes.entity[n] then fail("MISSING_PROTOTYPE "..n) end
  end
  -- A random map seed need not put natural iron on the arbitrary y=0
  -- latitude. Locate a real generated patch FIRST; center the empty test
  -- station on its railway-compatible latitude, without changing the ore.
  -- The 0835/0836 physical item, chart and rail-graph gates remain intact.
  local function find_natural_patch(min_y,max_y)
    local candidates=surface.find_entities_filtered{
      type="resource",name="iron-ore",
      area={{192,min_y},{MAX_NATIVE_TARGET_X,max_y}}}
    table.sort(candidates,function(a,b)
      return a.position.x<b.position.x or
        (a.position.x==b.position.x
          and math.abs(a.position.y)<math.abs(b.position.y))
    end)
    for _,e in ipairs(candidates) do
      if e.valid and (tonumber(e.amount)or 0)>0 then
        -- The original builder uses an even-tile eastbound rail axis.
        local origin={x=0,y=math.floor(e.position.y/2)*2}
        local needed=Frontier.required_segments_for_target(origin,e.position)
        if needed and needed<=Frontier.max_segments then
          return e,origin
        end
      end
    end
  end
  -- Prefer the original generated band; expand only when it lacks a
  -- reachable natural patch. Chunk requests never manufacture ore entities.
  for x=0,960,64 do surface.request_to_generate_chunks({x=x,y=0},3) end
  surface.force_generate_chunk_requests()
  local natural,origin=find_natural_patch(-96,96)
  if not natural then
    for _,latitude in ipairs({192,-192,384,-384,576,-576}) do
      for x=0,576,192 do
        surface.request_to_generate_chunks({x=x,y=latitude},3)
      end
      surface.force_generate_chunk_requests()
      natural,origin=find_natural_patch(latitude-96,latitude+96)
      if natural then break end
    end
  end
  if not natural then
    fail("NO_NATURALLY_GENERATED_EASTBOUND_IRON_PATCH seed_requires_reselection"..
      " max_reachable_x="..MAX_NATIVE_TARGET_X..
      " searched_generated_latitudes=0,+/-192,+/-384,+/-576")
  end
  STATION.y=origin.y
  ORE={x=natural.position.x,y=natural.position.y}
  local original_amount=natural.amount
  local tiles={}
  for x=-25,ORE.x+28 do for y=STATION.y-16,STATION.y+16 do
    tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
  end end
  surface.set_tiles(tiles,true)
  -- The Magos and build corridor are cleared of unrelated obstacles,
  -- but the real native target iron patch must remain untouched.
  -- This is a controlled isolated test world, not a gameplay cleanup.
  -- Exclude the ENTIRE Magos short-range acquisition footprint; clearing
  -- only the rail corridor left naturally generated ore 20 tiles north
  -- of the station and incorrectly defeated genuine starvation detection.
  local exclusion={{-96,STATION.y-80},{math.max(576,ORE.x+64),STATION.y+80}}
  local area={{-25,STATION.y-16},{ORE.x+28,STATION.y+17}}
  for _,e in ipairs(surface.find_entities_filtered{area=exclusion}) do
    -- Preserve naturally generated target ore, including its surrounding
    -- patch. Other resources here are fixture obstacles, never delivery.
    local target_patch=e.type=="resource" and e.name=="iron-ore"
      and math.abs(e.position.x-ORE.x)<=16
      and math.abs(e.position.y-ORE.y)<=16
    if e.valid and not target_patch
        and (e.type=="resource" or e.type=="tree"
        or e.type=="simple-entity" or e.type=="cliff"
        or e.force==game.forces.enemy) then e.destroy() end
  end
  if not(natural.valid and natural.amount==original_amount) then
    fail("NATURAL_ORE_SOURCE_DAMAGED_DURING_FIXTURE_ISOLATION")
  end
  -- This scenario starts with a NEW original Magos born as a Factorio
  -- character. No historical unit is replaced and no substitute boards.
  -- The user-visible setting is OFF in normal worlds and old saves.
  local option=settings and settings.global
    and settings.global["tech-priests-original-magos-rail-character"]
  if not option then fail("ORIGINAL_CHARACTER_SETTING_MISSING") end
  settings.global["tech-priests-original-magos-rail-character"]={value=true}
  if settings.global["tech-priests-original-magos-rail-character"].value~=true
      or not prototypes.entity["planetary-magos-tech-priest-rail-character"] then
    fail("ORIGINAL_NATIVE_CHARACTER_OPT_IN_REFUSED")
  end
  emit("ORIGINAL_NATIVE_CHARACTER_MODE_ENABLE_BEFORE_FIRST_PAIR")
  local station=surface.create_entity{
    name="planetary-magos-cogitator-station",
    position=STATION,force=force,raise_built=true}
  if not(station and station.valid)then fail("PLANETARY_STATION_PLACEMENT")end
  local inventory=station.get_inventory(defines.inventory.chest)
  if not(inventory and inventory.valid)then fail("STATION_INVENTORY_MISSING")end
  -- Technology is unlocked BY THE FIXTURE, not counted as autonomous science.
  -- This exercise starts after the train research phase.
  for _,name in ipairs({"railway","automated-rail-transportation",
      "engine","electric-energy-distribution-1",
      "automobilism","logistics-2","automation-2"}) do
    local tech=force.technologies[name]
    if tech and tech.enabled~=false then tech.researched=true end
  end
  -- Planetary Magos has seven actual chest slots. Keep 600 rails in
  -- six native stacks plus one free slot. Other physical supplies live in
  -- a nearby steel chest, reachable by the canonical 0686/0338 builder.
  -- The fixture supplies this chest, NEVER rails or rolling stock as entities.
  -- It consumes one of the original 20 steel-chest items in the manifest.
  local depot=surface.create_entity{
    name="steel-chest",position={x=-8,y=STATION.y+8},
    force=force,raise_built=true}
  if not(depot and depot.valid)then fail("SUPPLY_DEPOT_PLACEMENT")end
  local depot_inventory=depot.get_inventory(defines.inventory.chest)
  if not(depot_inventory and depot_inventory.valid)then
    fail("SUPPLY_DEPOT_INVENTORY_MISSING")
  end
  -- Preserve all original rail, fuel, train, drill and auxiliary supply
  -- quantities; every item must fit a REAL engine-managed inventory.
  local stock={{"rail",700},{"locomotive",2},{"cargo-wagon",3},
    {"train-stop",4},{"rail-signal",50},{"rail-chain-signal",30},
    {"burner-mining-drill",12},{"electric-mining-drill",12},
    {"transport-belt",300},{"inserter",40},{"iron-chest",30},
    {"steel-chest",19},{"coal",300},{"solid-fuel",100},
    {"stone-furnace",8},{"iron-plate",400},{"copper-plate",200},
    {"repair-pack",30},{"firearm-magazine",30}}
  for _,item in ipairs(stock) do
    if not prototypes.item[item[1]] then
      fail("REQUIRED_RAIL_SUPPLY_MISSING "..item[1])
    end
    local station_quantity=item[1]=="rail" and 600 or 0
    local depot_quantity=item[2]-station_quantity
    if station_quantity>0 then
      local accepted=inventory.insert{name=item[1],count=station_quantity}
      if accepted~=station_quantity then
        fail("STATION_PRESTOCK_CAPACITY "..item[1].." inserted="..accepted)
      end
    end
    if depot_quantity>0 then
      local accepted=depot_inventory.insert{name=item[1],count=depot_quantity}
      if accepted~=depot_quantity then
        fail("DEPOT_PRESTOCK_CAPACITY "..item[1].." inserted="..accepted)
      end
    end
  end
  if inventory.get_item_count("rail")~=600
      or depot_inventory.get_item_count("rail")~=100
      or depot_inventory.get_item_count("steel-chest")~=19 then
    fail("PHYSICAL_PRESTOCK_RECONCILIATION")
  end
  -- Do not credit test-script materialization of ore as native mining.
  local ore_tiles=count(surface,{type="resource",name="iron-ore",
    position=ORE,radius=16})
  if ore_tiles<1 then fail("NATURAL_REMOTE_ORE_PATCH_MISSING")end
  -- A fresh --create/on_init chart request can remain pending throughout
  -- benchmark execution. Request only the genuine generated target chunk
  -- from a live simulation pulse; never credit a merely pending request.
  -- The independent native is_chunk_charted gate at 1800 ticks remains.
  local target_chunk={x=math.floor(ORE.x/32),y=math.floor(ORE.y/32)}
  s.chart_target_chunk=target_chunk
  -- A native control chunk near the original Magos distinguishes a blocked
  -- chart processor/force from a distant-target-specific chart request.
  -- Both areas are genuinely generated; neither is a synthetic chart flag.
  s.chart_control_chunk={x=0,y=math.floor(STATION.y/32)}
  -- Start at ordinary daylight so the solar array supplies real power
  -- during this bounded 1,800-tick chart-lifecycle gate; time still advances.
  surface.daytime=0.85
  local radar,radar_position,solar_panels=
    seed_native_radar_chart_infrastructure(surface,force,ORE)
  s.chart_radar_position=radar_position
  s.chart_radar_unit=radar.unit_number
  emit("CHART_NATIVE_RADAR_SETUP radar_unit="..radar.unit_number..
    " solar_panels="..solar_panels..
    " x="..radar_position.x.." y="..radar_position.y..
    " daytime="..surface.daytime)
  s.chart_events_total=0
  s.chart_events_target=0
  s.chart_events_control=0
  emit("CHART_PREPARED target_chunk="..target_chunk.x..","..target_chunk.y..
    " generated="..tostring(surface.is_chunk_generated(target_chunk))..
    " charted="..tostring(force.is_chunk_charted(surface,target_chunk))..
    " requested="..tostring(force.is_chunk_requested_for_charting(surface,target_chunk)))
  if count(surface,{type="resource",
      area={{-64,STATION.y-64},{64,STATION.y+64}}})~=0 then
    fail("UNEXPECTED_NEARBY_ORE")
  end
  local rails=count(surface,{type={"straight-rail","half-diagonal-rail",
    "curved-rail-a","curved-rail-b"},area=area})
  if rails~=0 or count(surface,{name={"locomotive","cargo-wagon"},
        area=area})~=0 then
    fail("FIXTURE_PREBUILT_TRAIN_OR_RAIL")
  end
  -- The actual 1x1 vanilla chest center may differ from integer
  -- requested coordinates. Preserve the ORIGINAL physically placed depot
  -- LuaEntity across simulation/save, never select unrelated storage.
  s.depot_entity=depot
  s.depot_unit=depot.unit_number
  s.station_unit=station.unit_number
  s.station_y=STATION.y
  s.started=game.tick
  s.start_ore=inventory.get_item_count("iron-ore")
  s.start_rail=inventory.get_item_count("rail")
   s.start_depot_rail=depot_inventory.get_item_count("rail")
  s.natural_ore_x=ORE.x
  s.natural_ore_y=ORE.y
  s.natural_ore_amount=original_amount
  s.outbound=false;s.returned=false;s.ride_proof=false
  emit("SETUP no_biters=true local_resources=0 natural_iron=true"..
    " station_y="..STATION.y..
    " native_ore_amount="..original_amount..
    " target_x="..ORE.x.." target_y="..ORE.y..
    " rails=700 rails_station=600 rails_depot=100"..
    " locomotives=2 wagons=3"..
    " tech_preset=true track_prebuilt=0 initial_iron="..s.start_ore)
end
-- The last native run built 18 rails in 18k ticks, then only three in
-- the next 24k. Identify the exact PRE-WRIT queue denial while no 0836
-- request exists. Only the existing 0469 owner can answer this read-only
-- question; a fallback "no-pending-original-rail" is NOT a denial receipt.
-- Sample on the EXISTING fixture tick callback, with no new scheduler.
local function trace_uncommitted_rail_gap(s,elapsed)
  local p=storage.tech_priests.pairs_by_station
      and storage.tech_priests.pairs_by_station[s.station_unit]
  if not(p and p.station and p.station.valid)then return end
  local mission=p.remote_rail_outpost_0835
  local frontier=mission and mission.rail_frontier_0836
  local pending=mission and mission.pending_rail_0836
  local order=p.order_queue_0469 and p.order_queue_0469.current
  local candidate=p.construction_candidate_0338
  local authority=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469")
  local allowed,why=false,"queue-authority-unavailable"
  if authority and type(authority.can_yield_uncommitted_rail_0836)
      =="function" then
    local request=pending and pending.request or nil
    -- A nil request checks the authentic planning window, with unchanged
    -- live-order, movement, funding and custody guards.
    local ok,answer,reason=pcall(
      authority.can_yield_uncommitted_rail_0836,p,request)
    allowed=ok and answer==true
    why=ok and tostring(reason) or "queue-read-only-probe-error"
  end
  local item=candidate and candidate.item_name
  local stock=0
  local inv=p.station.get_inventory(defines.inventory.chest)
  if inv and inv.valid and type(item)=="string"then
    stock=inv.get_item_count(item)
  end
  emit("RAIL_PREWRIT_GAP elapsed="..elapsed..
    " segment="..tostring(frontier and frontier.segment)..
    " mission="..tostring(mission and mission.status)..
    " prewrite_refusal="..tostring(mission
      and mission.last_prewrite_refusal_0836
      and mission.last_prewrite_refusal_0836.reason)..
    " prewrite_refusal_tick="..tostring(mission
      and mission.last_prewrite_refusal_0836
      and mission.last_prewrite_refusal_0836.tick)..
    " last_0836_service_tick="..tostring(mission
      and mission.last_service_sample_tick_0836)..
    " last_0836_service_pending="..tostring(mission
      and mission.last_service_sample_pending_0836)..
    " live_incumbent_owner="..tostring(mission
      and mission.last_incumbent_refusal_0836
      and mission.last_incumbent_refusal_0836.reason)..
    " live_incumbent_tick="..tostring(mission
      and mission.last_incumbent_refusal_0836
      and mission.last_incumbent_refusal_0836.tick)..
    " rail_yield_observed="..tostring(p.rail_order_yield_observed_0836~=nil)..
    " expansion_status="..tostring(p.station_expansion_0256
      and p.station_expansion_0256.status)..
    " facility_feed_custody="..tostring(p.emergency_facility_feed_custody_0357~=nil)..
    " defense_task="..tostring(p.defense_task_0259~=nil)..
    " frontier_error="..tostring(p.remote_rail_frontier_failure_0836
      and p.remote_rail_frontier_failure_0836.reason)..
    " transfer_custody_0687="..tostring(p.inventory_transfer_custody_0687~=nil)..
    " construction_task_0340="..tostring(p.construction_task_0340~=nil)..
    " active_acquisition_0333="..tostring(p.active_acquisition_0333~=nil)..
    " direct_task_0336="..tostring(p.direct_acquisition_task_0336~=nil)..
    " generic_construction_task="..tostring(p.construction_task~=nil)..
    " pending="..tostring(pending~=nil)..
    " request="..tostring(p.construction_request~=nil)..
    " queue_gate="..tostring(allowed)..
    " queue_reason="..tostring(why)..
    " order_kind="..tostring(order and order.kind)..
    " order_source="..tostring(order and order.source)..
    " order_item="..tostring(order and order.item)..
    " order_status="..tostring(order and order.status)..
    " active_order_matches="..tostring(order~=nil
      and p.active_order_0469==order)..
    " candidate="..tostring(item)..
    " candidate_field="..tostring(candidate and candidate.request_field)..
    " candidate_site="..tostring(candidate and candidate.site_reason)..
    " candidate_station_count="..tostring(stock)..
    " builder_phase="..tostring(p.construction_task_0338
      and p.construction_task_0338.phase)..
    " construction_custody="..tostring(p.construction_custody_0338~=nil)..
    " active_task="..tostring(p.active_task~=nil)..
    " active_task_0285="..tostring(p.active_task_0285~=nil)..
    " direct_custody="..tostring(p.direct_acquisition_custody_0513~=nil)..
    " machine_custody="..tostring(p.machine_logistics_custody_0528~=nil)..
    " emergency_craft="..tostring(p.emergency_craft~=nil)..
    " active_supply="..tostring(p.active_supply_request~=nil)..
    " supply_source="..tostring(p.active_supply_request
      and p.active_supply_request.source)..
    " move_owner="..tostring(p.movement_request_0418
      and p.movement_request_0418.owner)..
    " blocked_site="..tostring(p.construction_blocked_reason_0338)..
    " dispatcher_refusal="..tostring(p.remote_rail_admission_refusal_0510
      and p.remote_rail_admission_refusal_0510.reason))

  -- Separate broker planning from canonical dispatcher entry/handoff.
  -- These are diagnostic traces, NEVER constructed rails or acceptance proof.
  local plan=mission and mission.last_plan_trace_0836
  local dispatch=mission and mission.last_frontier_dispatch_0510
  emit("RAIL_LIVE_ADMISSION elapsed="..elapsed..
    " plan_tick="..tostring(plan and plan.tick)..
    " plan_result="..tostring(plan and plan.reason)..
    " plan_allowed="..tostring(plan and plan.planned)..
    " plan_segment="..tostring(plan and plan.segment)..
    " plan_pending="..tostring(plan and plan.pending)..
    " plan_request="..tostring(plan and plan.request)..
    " plan_candidate="..tostring(plan and plan.candidate)..
    " dispatcher_entry_tick="..tostring(mission
      and mission.last_dispatch_entry_tick_0510)..
    " dispatcher_frontier_tick="..tostring(dispatch and dispatch.tick)..
    " dispatcher_frontier_active="..tostring(dispatch and dispatch.active)..
    " dispatcher_frontier_result="..tostring(dispatch and dispatch.reason)..
    " dispatcher_pending="..tostring(dispatch and dispatch.pending)..
    " dispatcher_request_matches="..tostring(dispatch
      and dispatch.request_matches)..
    " dispatcher_builder="..tostring(dispatch and dispatch.builder))

  -- Read-only original builder-ownership and genuinely stocked predecessor
  -- evidence during the existing bounded 600-tick native prewrite samples.
  -- A candidate name alone does not establish that funded work may yield.
  local prior=p.construction_requested_item
  local prior_item=type(prior)=="table"
    and (prior.item_name or prior.item or prior.name)
    or (type(prior)=="string" and prior or nil)
  local other=p.structure_construction_requested_item
  local other_item=type(other)=="table"
    and (other.item_name or other.item or other.name)
    or (type(other)=="string" and other or nil)
  local station_inv=p.station.get_inventory(defines.inventory.chest)
  local depot=s.depot_entity
  local depot_inv=depot and depot.valid
    and depot.get_inventory(defines.inventory.chest) or nil
  local refusal=p.construction_site_refusal_0338
  local rtask=p.robot_network_task_0338
  local rrequest=p.robot_network_request_0338
  local previous=p.construction_last_task_0338
  emit("RAIL_PREWRIT_0338_OWNER elapsed="..elapsed..
    " prior_item="..tostring(prior_item)..
    " prior_entity="..tostring(type(prior)=="table"
      and (prior.entity_name or prior.entity))..
    " prior_source="..tostring(type(prior)=="table"
      and (prior.source or prior.owner))..
    " prior_site="..tostring(type(prior)=="table"
      and (prior.position or prior.site_position)~=nil)..
    " prior_station_stock="..tostring(prior_item and station_inv
      and station_inv.get_item_count(prior_item))..
    " prior_depot_stock="..tostring(prior_item and depot_inv
      and depot_inv.get_item_count(prior_item))..
    " structure_item="..tostring(other_item)..
    " structure_station_stock="..tostring(other_item and station_inv
      and station_inv.get_item_count(other_item))..
    " robot_task_phase="..tostring(rtask and rtask.phase)..
    " robot_request_item="..tostring(rrequest and rrequest.item_name)..
    " original_task="..tostring(p.construction_task_0338
      and p.construction_task_0338.phase)..
    " old_task="..tostring(p.construction_task and p.construction_task.phase)..
    " refused_field="..tostring(refusal and refusal.field)..
    " refused_reason="..tostring(refusal and refusal.reason)..
    " refused_matches_prior="..tostring(refusal
      and refusal.request==prior)..
    " refused_age="..tostring(refusal and refusal.tick
      and (game.tick-refusal.tick))..
    " candidate_matches_prior="..tostring(candidate
      and candidate.request_value==prior)..
    " builder_last_field="..tostring(previous and previous.request_field)..
    " builder_last_result="..tostring(previous and previous.result)..
    " cooldown_remaining="..tostring(
      (tonumber(p.construction_cooldown_0338)or 0)-game.tick))
end
local function inspect(s,elapsed)
  local surface=game.surfaces[1]
  local station=surface.find_entities_filtered{
    name="planetary-magos-cogitator-station",
    position={x=0,y=s.station_y or 0},radius=2,
    force=game.forces.player}[1]
  local p=storage.tech_priests.pairs_by_station
      and storage.tech_priests.pairs_by_station[s.station_unit]
  if not(station and station.valid and p and p.priest
      and p.priest.valid) then fail("PLANETARY_MAGOS_PAIR_LOST") end
  local objective=p.remote_rail_outpost_0835
  if elapsed>=1800 and not s.chart_verified then
    local target_chunk=s.chart_target_chunk
    if not (target_chunk and station.force.is_chunk_charted(
        surface,target_chunk)) then
      local pending=target_chunk and
        station.force.is_chunk_requested_for_charting(surface,target_chunk)
      fail("REMOTE_ORE_NOT_CHARTED_AFTER_TICKS="..elapsed..
        " requested="..tostring(pending))
    end
    s.chart_verified=true
    emit("PASS naturally generated ore chunk charted before rail objective")
  end
  if elapsed>=1800 and not (objective
      and (objective.status=="starvation-confirmed"
        or objective.status=="building-physical-rail"
        or objective.status=="rail-track-established"
        or objective.status=="rail-track-blocked")
      and objective.item=="iron-ore" and objective.target
      and objective.target.x>=192
      and math.abs(objective.target.x-s.natural_ore_x)<=16
      and math.abs(objective.target.y-s.natural_ore_y)<=16
      and objective.root_station_unit==s.station_unit
      and objective.created_tick and objective.next_step) then
    fail("STARVATION_DETECTION_DID_NOT_CREATE_PERSISTENT_RAIL_OBJECTIVE")
  end
  if elapsed>=1800 and not s.starvation_verified then
    s.starvation_verified=true
    emit("PASS starvation detected with real supplies, charted target and durable Magos objective")
  end
  local rails=surface.find_entities_filtered{
    type={"straight-rail","half-diagonal-rail",
      "curved-rail-a","curved-rail-b"},
    area={{-25,(s.station_y or 0)-16},
          {s.natural_ore_x+28,(s.station_y or 0)+17}},
    force=station.force}
  local near,far=0,0
  for _,e in ipairs(rails) do
    if e.position.x<=24 then near=near+1 end
    if e.position.x>=s.natural_ore_x-32 then far=far+1 end
  end
  -- Observe the exact 0835 -> 0836 -> 0338 admission state at
  -- existing native checkpoints. No scheduler, inventory or gate changes.
  -- Persist nothing new: this is an immutable evidence readback only.
  local frontier=objective and objective.rail_frontier_0836
  local pending=objective and objective.pending_rail_0836
  local candidate=p.construction_candidate_0338
  local builder=p.construction_task_0338
  local receipt=p.construction_last_task_0338
  local event=p.construction_last_event_0338
  local queue=p.order_queue_0469
  local order=(queue and queue.current)or p.active_order_0469
  local refusal=p.remote_rail_admission_refusal_0510
  local dispatch=p.canonical_action_0744
  local blocked_site=p.construction_site_refusal_0338
  -- Ask the incumbent 0469 owner for its exact READ-ONLY refusal. Do not
  -- clear, pause, mutate or promote a queue order, and do not accept a rail.
  local yield_allowed,yield_reason=false,"no-pending-original-rail"
  if pending and p.construction_request==pending.request then
    local authority=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469")
    if authority and type(authority.can_yield_uncommitted_rail_0836)
        =="function" then
      local ok,allowed,reason=pcall(
        authority.can_yield_uncommitted_rail_0836,p,pending.request)
      yield_allowed=ok and allowed==true
      yield_reason=ok and tostring(reason) or "queue-yield-probe-error"
    else
      yield_reason="queue-owner-unavailable"
    end
  end
  emit("RAIL_ADMISSION_DIAG elapsed="..elapsed..
    " stage="..tostring(objective and objective.stage)..
    " reason="..tostring(objective and objective.last_blocker)..
    " segment="..tostring(frontier and frontier.segment)..
    " pending="..tostring(pending~=nil)..
    " request_matches="..tostring(pending and
      p.construction_request==pending.request)..
    " candidate="..tostring(candidate and candidate.item_name)..
    " candidate_site="..tostring(candidate and candidate.site_reason)..
    " builder_phase="..tostring(builder and builder.phase)..
    " builder_item="..tostring(builder and builder.item_name)..
    " custody="..tostring(p.construction_custody_0338~=nil)..
    " active_task="..tostring(p.active_task~=nil)..
    " current_task="..tostring(p.current_task~=nil)..
    " active_order="..tostring(p.active_order_0469~=nil)..
    " machine_custody="..tostring(p.machine_logistics_custody_0528~=nil)..
    " receipt_phase="..tostring(receipt and receipt.phase)..
    " receipt_result="..tostring(receipt and receipt.result)..
    " last_builder_event="..tostring(event and event.action)..
    " last_builder_detail="..tostring(event and event.detail)..
    " order_kind="..tostring(order and order.kind)..
    " order_source="..tostring(order and order.source)..
    " order_status="..tostring(order and order.status)..
    " order_reason="..tostring(order and order.reason)..
    " order_key="..tostring(order and order.key)..
    " order_queue_current="..tostring(queue and queue.current~=nil)..
    " queue_yield_allowed="..tostring(yield_allowed)..
    " queue_yield_reason="..tostring(yield_reason)..
    " active_supply_source="..tostring(p.active_supply_request
      and p.active_supply_request.source)..
    " active_supply_target="..tostring(p.active_supply_request
      and p.active_supply_request.target)..
    " queue_task_kind="..tostring(order and order.task
      and order.task.type)..
    " dispatch_family="..tostring(dispatch and dispatch.family)..
    " dispatch_detail="..tostring(dispatch and dispatch.detail)..
    " rail_refusal="..tostring(refusal and refusal.reason)..
    " rail_refusal_tick="..tostring(refusal and refusal.tick)..
    " rail_refusal_order_kind="..tostring(refusal and refusal.order_kind)..
    " rail_refusal_order_source="..tostring(refusal and refusal.order_source)..
    " rail_refusal_action="..tostring(refusal and refusal.action_family)..
    " planning_blocker="..tostring(p.construction_blocked_reason_0338)..
    " remote_drill_present="..tostring(p.remote_drill_request_1011~=nil)..
    " remote_drill_positioned="..tostring(p.remote_drill_request_1011
      and p.remote_drill_request_1011.position~=nil)..
    " blocked_site_field="..tostring(blocked_site and blocked_site.field)..
    " blocked_site_reason="..tostring(blocked_site and blocked_site.reason)..
    " blocked_site_matches_remote="..tostring(blocked_site
      and blocked_site.request==p.remote_drill_request_1011)..
    " movement_owner="..tostring(p.movement_request_0418
      and p.movement_request_0418.owner)..
    " source_rail="..station.get_inventory(defines.inventory.chest)
      .get_item_count("rail"))
  -- One real native-source/depot census at the existing strict checkpoints.
  -- A rail returned to the depot is not necessarily missing or spent;
  -- never infer a built rail from one station's inventory decrement.
  local depot=s.depot_entity
  local depot_inv=depot and depot.valid
    and depot.unit_number==s.depot_unit
    and depot.force==station.force
    and depot.surface==surface
    and depot.get_inventory(defines.inventory.chest) or nil
  local depot_rails=depot_inv and depot_inv.valid
    and depot_inv.get_item_count("rail") or nil
  local terminal=pending and pending.original_terminal_trace_0836
  local lost=pending and pending.first_loss_snapshot_0836
  emit("RAIL_ORIGINAL_CUSTODY_DIAG elapsed="..elapsed..
    " station_rail="..station.get_inventory(defines.inventory.chest)
      .get_item_count("rail")..
    " depot_rail="..tostring(depot_rails)..
    " current_request_item="..tostring(p.construction_request
      and p.construction_request.item_name)..
    " current_request_site="..tostring(p.construction_request
      and p.construction_request.site_reason)..
    " last_receipt_item="..tostring(receipt and receipt.item_name)..
    " last_receipt_original="..tostring(receipt and pending
      and receipt.request_value==pending.request)..
    " original_terminal_phase="..tostring(terminal and terminal.phase)..
    " original_terminal_reason="..tostring(terminal and terminal.result)..
    " original_terminal_owned="..tostring(terminal
      and terminal.request_owned_before_clear)..
    " original_debit_before="..tostring(terminal and terminal.source_before)..
    " original_debit_after="..tostring(terminal and terminal.source_after)..
    " original_source_readback="..tostring(terminal
      and terminal.source_readback)..
    " original_held="..tostring(terminal and terminal.carried_remaining)..
    " original_built_name="..tostring(terminal and terminal.built_name)..
    " original_built_unit="..tostring(terminal and terminal.built_unit)..
    " first_loss_tick="..tostring(lost and lost.tick)..
    " first_loss_last_item="..tostring(lost and lost.last_item)..
    " first_loss_last_original="..tostring(lost and lost.last_is_original))
  -- Strict original-material native census: engine inventories and live
   -- 0836-verified rail units, including the one currently in 0338 transit.
   local hold=p.rail_material_cargo_0836
   local live_hold=type(hold)=="table" and hold.inventory
     and hold.inventory.valid==true
   local held_rails=live_hold and hold.inventory.get_item_count("rail") or nil
   local hold_owner=live_hold and not hold.quarantine
     and hold.station_unit==station.unit_number
     and hold.priest_unit==p.priest.unit_number
     and hold.force_index==station.force.index
     and hold.surface_index==surface.index
   local units={}
   for _,rail in ipairs(rails) do
     if rail.valid and rail.unit_number then units[rail.unit_number]=true end
   end
   local segments=frontier and frontier.segment or 0
   local all_real=frontier and type(frontier.built_units)=="table"
   if all_real then for i=1,segments do
     if not units[frontier.built_units[i]] then all_real=false;break end
   end end
   local active_rail=0
   if builder and builder.item_name=="rail" and builder.carried then
     active_rail=tonumber(builder.carried.count)or 0
   elseif not builder and p.construction_custody_0338
     and p.construction_custody_0338.item_name=="rail" then
     active_rail=tonumber(p.construction_custody_0338.count)or 0
   end
   local station_rails=station.get_inventory(defines.inventory.chest)
     .get_item_count("rail")
   local total=held_rails and depot_rails
     and (station_rails+depot_rails+held_rails+segments+active_rail)
     or nil
   local expected=s.start_rail+(s.start_depot_rail or 0)
   emit("RAIL_NATIVE_CUSTODY_LEDGER elapsed="..elapsed..
     " source="..station_rails.." depot="..tostring(depot_rails)..
     " held="..tostring(held_rails).." restocks="..
       tostring(hold and hold.restock_cycles_0836)..
     " native="..segments.." active="..active_rail..
     " live_units="..tostring(all_real).." owner="..tostring(hold_owner)..
     " total="..tostring(total).." expected="..expected)
   -- Reconcile real stock at EVERY late native checkpoint, not only 36k.
   -- A previously passing physical-custody receipt is never permanent proof.
   if elapsed>=36000 then
     if not(hold_owner and all_real and segments>=2
       and total==expected)then
       fail("RAIL_NATIVE_CUSTODY_NOT_CONSERVED expected="..expected..
         " counted="..tostring(total).." elapsed="..elapsed)
     end
     if not s.rail_custody_verified then
       s.rail_custody_verified=true
       emit("PASS original physical rail cargo and native segment census conserved"..
         " total="..total.." held="..held_rails.." built="..segments)
     end
   end
   -- A route objective and even a ghost are not physically placed rail.
  -- The first acceptance requires a real segment with the exact unit
  -- recorded by the 0836 frontier AFTER canonical 0338 construction.
  if elapsed>=18000 and not s.first_physical_rail_verified then
    local frontier=objective and objective.rail_frontier_0836
    local first_unit=frontier and frontier.built_units
      and frontier.built_units[1]
    local first_found=false
    for _,track in ipairs(rails)do
      if track.valid and first_unit and track.unit_number==first_unit
          and track.name=="straight-rail"
          and track.force==station.force then
        first_found=true
        break
      end
    end
    local current_rail=station.get_inventory(defines.inventory.chest)
      .get_item_count("rail")
    if not(frontier and (frontier.segment or 0)>0
        and first_found and current_rail<s.start_rail) then
      fail("RAIL_FIRST_ENGINE_CONSTRUCTION_NOT_PROVEN"..
        " segment="..tostring(frontier and frontier.segment)..
        " physical="..tostring(first_found)..
        " source_rail="..tostring(current_rail))
    end
    s.first_physical_rail_verified=true
    emit("PASS first physical rail built and exact stock debited"..
      " unit="..tostring(first_unit)..
      " station_rail_delta="..tostring(s.start_rail-current_rail))
  end
  -- Distinct native intermediate gate: two original 0338-built rails,
  -- separate real item debits and Factorio's actual graph connectivity.
  if elapsed>=36000 and not s.connected_track_verified then
    local frontier=objective and objective.rail_frontier_0836
    local ids=frontier and frontier.built_units
    local first,second
    for _,track in ipairs(rails) do
      if track.valid and track.name=="straight-rail"
          and track.force==station.force then
        if ids and track.unit_number==ids[1] then first=track end
        if ids and track.unit_number==ids[2] then second=track end
      end
    end
    local connected=false
    if first and second and first~=second
        and type(first.get_connected_rail)=="function" then
      for _,rail_direction in ipairs({
        defines.rail_direction.front,defines.rail_direction.back}) do
        local ok,neighbor=pcall(first.get_connected_rail,{
          rail_direction=rail_direction,
          rail_connection_direction=defines.rail_connection_direction.straight})
        if ok and neighbor==second then connected=true;break end
      end
    end
    local current_rail=station.get_inventory(defines.inventory.chest)
      .get_item_count("rail")
    if not(frontier and frontier.segment>=2 and first and second
        and connected and s.start_rail-current_rail>=2) then
      fail("TWO_NATIVE_CONNECTED_COUNTED_RAILS_NOT_PROVEN"..
        " segment="..tostring(frontier and frontier.segment)..
        " first="..tostring(first and first.unit_number)..
        " second="..tostring(second and second.unit_number)..
        " native_connected="..tostring(connected)..
        " stock_delta="..tostring(s.start_rail-current_rail))
    end
    s.connected_track_verified=true
    emit("PASS two distinct 0338-debited native-connected rails"..
      " first_unit="..first.unit_number..
      " second_unit="..second.unit_number..
      " station_rail_delta="..(s.start_rail-current_rail))
  end
  local locomotives=surface.find_entities_filtered{
    name="locomotive",area={{-25,(s.station_y or 0)-16},
          {s.natural_ore_x+28,(s.station_y or 0)+17}},
    force=station.force}
  local wagons=count(surface,{name="cargo-wagon",
    area={{-25,(s.station_y or 0)-16},
          {s.natural_ore_x+28,(s.station_y or 0)+17}},force=station.force})
  -- Read-only original source-debited native wagon and locomotive coupling.
  -- Do not accept mere wagon counts, ghosts or unverified rolling stock.
  local wagon_state=objective and objective.first_wagon_0836
  local paid=wagon_state and wagon_state.paid_completion_0836
  local loco_state=objective and objective.first_locomotive_0836
  local loco_entity=loco_state and loco_state.built_entity
  local wagon_entity=wagon_state and wagon_state.built_entity
  local coupled=paid and wagon_entity and wagon_entity.valid
    and loco_entity and loco_entity.valid
    and wagon_entity.train and wagon_entity.train.valid
    and loco_entity.train and loco_entity.train.valid
    and wagon_entity.train.id==loco_entity.train.id
  emit("WAGON_NATIVE_0836 elapsed="..elapsed..
    " phase="..tostring(wagon_state and wagon_state.phase)..
    " blocker="..tostring(wagon_state and wagon_state.blocker)..
    " paid="..tostring(paid~=nil)..
    " coupled="..tostring(coupled==true)..
    " unit="..tostring(wagon_entity and wagon_entity.unit_number))
  local first_fuel=objective and objective.first_fuel_0836
  local actual_fuel=0
  if loco_entity and loco_entity.valid and defines and defines.inventory then
    local ok,fuel=pcall(function()
      return loco_entity.get_inventory(defines.inventory.fuel)
    end)
    if ok and fuel and fuel.valid then
      local counted,n=pcall(fuel.get_item_count,"coal")
      if counted and type(n)=="number"then actual_fuel=n end
    end
  end
  -- Read-only physical-duty observability: distinguish a genuinely live
  -- 0528 source/cargo transaction from a completed receipt or an unrelated
  -- reservation. A missing phase is unknown, NOT evidence of zero work.
  local train_machine=p.machine_logistics_0528
  local train_candidate=p.machine_logistics_candidate_0528
  local train_custody=p.machine_logistics_custody_0528
  emit("FUEL_NATIVE_0836 elapsed="..elapsed..
    " phase="..tostring(first_fuel and first_fuel.phase)..
    " fuel_coal="..actual_fuel..
    " receipt_tick="..tostring(first_fuel and first_fuel.receipt_tick)..
    " native_loco_unit="..tostring(loco_entity and loco_entity.unit_number)..
    " native_wagon_unit="..tostring(wagon_entity and wagon_entity.unit_number)..
    " offer_reason="..tostring(first_fuel and first_fuel.last_attempt_reason)..
    " offer_tick="..tostring(first_fuel and first_fuel.last_attempt_tick)..
    " machine_phase="..tostring(train_machine and train_machine.phase)..
    " machine_action="..tostring(train_machine and train_machine.action)..
    " machine_item="..tostring(train_machine and train_machine.item)..
    " machine_unit="..tostring(train_machine and train_machine.machine_unit)..
    " machine_blocker="..tostring(train_machine and train_machine.last_blocker)..
    " machine_started="..tostring(train_machine and train_machine.started_tick)..
    " machine_train_owned="..tostring(train_machine and train_machine.original_train_fuel_0836)..
    " machine_custody="..tostring(train_custody~=nil)..
    " candidate_source="..tostring(train_candidate and train_candidate.source)..
    " candidate_item="..tostring(train_candidate and train_candidate.item)..
    " candidate_expiry="..tostring(train_candidate and train_candidate.expires_tick)..
    " construction_active="..tostring(p.construction_task_0338~=nil)..
    " movement_owner="..tostring(p.movement_request_0418 and p.movement_request_0418.owner))
  local stop_state=objective and objective.first_stop_0836
  local stop_entity=stop_state and stop_state.built_entity
  local stop_rail=stop_entity and stop_entity.valid
    and stop_entity.connected_rail
  emit("STOP_NATIVE_0836 elapsed="..elapsed..
    " phase="..tostring(stop_state and stop_state.phase)..
    " unit="..tostring(stop_entity and stop_entity.valid and stop_entity.unit_number)..
    " rail_unit="..tostring(stop_rail and stop_rail.valid and stop_rail.unit_number)..
    " paid="..tostring(stop_state and stop_state.paid_completion_0836
      and stop_state.paid_completion_0836.native_0338_paid)..
    " blocker="..tostring(stop_state and stop_state.blocker))
  -- The distant stop is a SECOND physically paid 0338 build, with another
  -- actual engine connection to the far end of the original 205-link track.
  -- A second home-side ghost or a cached receipt is not remote access.
  local remote=objective and objective.remote_stop_0836
  local remote_entity=remote and remote.built_entity
  local remote_rail=remote_entity and remote_entity.valid
    and remote_entity.connected_rail
  local remote_receipt=remote and remote.paid_completion_0836
  local far_connected=false
  local track=objective and objective.rail_frontier_0836
  if remote_rail and remote_rail.valid and track
      and type(track.built_units)=="table" then
    for index=math.max(1,#track.built_units-28),#track.built_units do
      if track.built_units[index]==remote_rail.unit_number then
        far_connected=true;break
      end
    end
  end
  emit("REMOTE_STOP_NATIVE_0836 elapsed="..elapsed..
    " phase="..tostring(remote and remote.phase)..
    " role="..tostring(remote and remote.request
      and remote.request.rail_stop_role_0836)..
    " unit="..tostring(remote_entity and remote_entity.valid
      and remote_entity.unit_number)..
    " rail_unit="..tostring(remote_rail and remote_rail.valid
      and remote_rail.unit_number)..
    " far_connected="..tostring(far_connected)..
    " home_separate="..tostring(stop_entity and stop_entity.valid
      and remote_entity and remote_entity.valid
      and stop_entity.unit_number~=remote_entity.unit_number)..
    " paid="..tostring(remote_receipt and remote_receipt.native_0338_paid)..
    " source_debit="..tostring(remote_receipt and
      remote_receipt.before-remote_receipt.after)..
    " blocker="..tostring(remote and remote.blocker))
  if remote and remote.phase=="native-paid-original-train-stop-verified"
      and not(remote.request and remote.request.rail_stop_role_0836=="remote"
        and remote_receipt and remote_receipt.native_0338_paid==true
        and remote_receipt.before-remote_receipt.after==1
        and far_connected and stop_entity and stop_entity.valid
        and remote_entity and remote_entity.valid
        and stop_entity.unit_number~=remote_entity.unit_number)then
    fail("REMOTE_STOP_NATIVE_IDENTITY_DEBIT_OR_FAR_CONNECTION_INVALID")
  end
  -- Read the actual engine driver, not the rail mission's assertion.
  local first_board=objective and objective.first_board_0836
  local native_driver
  local driver_read=false
  if loco_entity and loco_entity.valid then
    driver_read,native_driver=pcall(function()
      return loco_entity.get_driver()
    end)
  end
  local contact_sq
  if loco_entity and loco_entity.valid then
    local x=p.priest.position.x-loco_entity.position.x
    local y=p.priest.position.y-loco_entity.position.y
    contact_sq=x*x+y*y
  end
  emit("BOARD_NATIVE_0836 elapsed="..elapsed..
    " phase="..tostring(first_board and first_board.phase)..
    " priest_type="..tostring(p.priest.type)..
    " priest_unit="..tostring(p.priest.unit_number)..
    " unsupported_priest_type="..tostring(first_board
      and first_board.phase=="native-boarding-unsupported-original-unit")..
    " original_priest_identity_intact="..tostring(p.priest.valid
      and first_board and first_board.priest_unit==p.priest.unit_number)..
    " native_driver_read="..tostring(driver_read)..
    " real_original_driver="..tostring(native_driver==p.priest)..
    " contact_sq="..tostring(contact_sq)..
    " priest_x="..tostring(p.priest.position.x)..
    " priest_y="..tostring(p.priest.position.y)..
    " loco_x="..tostring(loco_entity and loco_entity.valid and loco_entity.position.x)..
    " loco_y="..tostring(loco_entity and loco_entity.valid and loco_entity.position.y)..
    " move_x="..tostring(p.movement_request_0418 and p.movement_request_0418.x)..
    " move_y="..tostring(p.movement_request_0418 and p.movement_request_0418.y)..
    " move_state="..tostring(p.movement_controller_state_0418)..
    " retry_after="..tostring(first_board and first_board.retry_after_tick)..
    " blocker="..tostring(first_board and first_board.last_blocker)..
    " movement_owner="..tostring(p.movement_request_0418 and p.movement_request_0418.owner))
  -- Read actual native locomotive/schedule/stop movement. The persisted
  -- 0836 phase is diagnostic ONLY; train coordinates and original driver
  -- must confirm motion. A route record is never a completed expedition.
  local outbound=objective and objective.first_outbound_0836
  local moving_train=loco_entity and loco_entity.valid and loco_entity.train
  local record_name
  if moving_train and moving_train.valid then
    local observed_schedule,records=pcall(function()
      return moving_train.get_schedule().get_records()
    end)
    if observed_schedule and type(records)=="table" and #records==1 then
      record_name=records[1].station
    end
  end
  emit("OUTBOUND_NATIVE_0836 elapsed="..elapsed..
    " phase="..tostring(outbound and outbound.phase)..
    " original_priest_driver="..tostring(native_driver==p.priest)..
    " train_id="..tostring(moving_train and moving_train.valid
      and moving_train.id)..
    " locomotive_x="..tostring(loco_entity and loco_entity.valid
      and loco_entity.position.x)..
    " origin_x="..tostring(outbound and outbound.origin_x)..
    " highest_x="..tostring(outbound and outbound.highest_x)..
    " speed="..tostring(moving_train and moving_train.valid
      and moving_train.speed)..
    " has_path="..tostring(moving_train and moving_train.valid
      and moving_train.has_path)..
    " path_end_stop_unit="..tostring(moving_train and moving_train.valid
      and moving_train.path_end_stop
      and moving_train.path_end_stop.unit_number)..
    " actual_station_unit="..tostring(moving_train and moving_train.valid
      and moving_train.station and moving_train.station.unit_number)..
    " remote_stop_unit="..tostring(remote_entity and remote_entity.valid
      and remote_entity.unit_number)..
    " schedule_station="..tostring(record_name)..
    " blocked="..tostring(outbound and outbound.last_blocker))
  if outbound and outbound.phase==
      "native-original-outbound-arrived-at-paid-remote-stop"
      and not(moving_train and moving_train.valid
        and moving_train.station==remote_entity
        and native_driver==p.priest)then
    fail("OUTBOUND_CLAIM_WITHOUT_ORIGINAL_NATIVE_TRAIN_ARRIVAL")
  end
  local drills=surface.find_entities_filtered{
    type="mining-drill",
    area={{s.natural_ore_x-32,s.natural_ore_y-24},
          {s.natural_ore_x+32,s.natural_ore_y+24}},
    force=station.force}
  local resource_drills=0
  for _,e in ipairs(drills)do
    if e.valid then resource_drills=resource_drills+1 end
  end
  -- Train position must actually advance to the destination and back.
  -- A train merely spawned next to the station is not remote acquisition.
  for _,loco in ipairs(locomotives) do
    if loco.valid and loco.train and loco.train.valid then
      local train=loco.train
      if loco.position.x>=s.natural_ore_x-37 then s.outbound=true end
      if s.outbound and loco.position.x<=28 then s.returned=true end
      local ride=p.train_transport_rail_0835
      local native_boarded=false
      local observed,actual_driver=pcall(function()return loco.get_driver()end)
      native_boarded=observed and actual_driver==p.priest
      if ride and ride.train_id==train.id
          and ride.boarded_priest_unit==p.priest.unit_number
          and ride.physical_boarding_confirmed==true
          and ride.disembark_confirmed~=true
          and native_boarded then
        -- A valid, matching train lease is recorded, but actual onboard
        -- capability remains an independent requirement of the executor.
        s.ride_proof=true
      end
    end
  end
  local delivered=station.get_inventory(defines.inventory.chest)
      .get_item_count("iron-ore")-s.start_ore
  emit("CHECKPOINT elapsed="..elapsed..
    " starvation="..tostring(objective and objective.status)..
    " natural_target="..tostring(s.natural_ore_x)..
    " target="..tostring(objective and objective.target and objective.target.x)..
    " rail="..#rails..
    " near_rail="..near.." far_rail="..far..
    " locomotives="..#locomotives.." wagons="..wagons..
    " remote_drills="..resource_drills.." outbound="..tostring(s.outbound)..
    " returned="..tostring(s.returned)..
    " board_proof="..tostring(s.ride_proof)..
    " delivered_ore="..delivered)
  if elapsed>=90000 then
    if near<1 or far<1 then fail("RAIL_LINE_NEVER_REACHED_REMOTE_PATCH")end
    if #locomotives<1 or wagons<1 then fail("TRAIN_NEVER_ASSEMBLED")end
    if not(first_fuel and first_fuel.phase=="native-paid-locomotive-fueled"
        and actual_fuel>0)then fail("TRAIN_NOT_NATIVE_FUELED")end
    if not s.ride_proof then fail("MAGOS_PHYSICAL_TRAIN_RIDE_NOT_PROVEN")end
    if not(s.outbound and s.returned)then fail("TRAIN_ROUND_TRIP_NOT_PROVEN")end
    if resource_drills<1 then fail("REMOTE_MINE_NOT_ESTABLISHED")end
    if delivered<=0 then fail("NO_GENUINE_ORE_DELIVERED_BY_RAIL")end
    emit("PASS planetary Magos built rail, rode train, mined and returned real ore")
    s.finished=true
  end
end
local function pulse()
  local s=root()
  if s.finished or s.failed then return {processed=0} end
  local ok,why=pcall(function()
    if not s.started then fail("fixture did not initialize") end
    local elapsed=game.tick-s.started
    -- Start the native chart request only after --benchmark begins ticking.
    -- No map-wide chart backlog; no ghost or artificial intelligence credit.
    if elapsed>=60 and not s.chart_live_request_issued then
      local surface,force=game.surfaces[1],game.forces.player
      local target_chunk=s.chart_target_chunk
      if not (target_chunk and surface.is_chunk_generated(target_chunk)) then
        fail("NATURAL_TARGET_CHUNK_NOT_GENERATED_ON_LIVE_CHART")
      end
      force.chart(surface,{{target_chunk.x*32,target_chunk.y*32},
        {target_chunk.x*32+31,target_chunk.y*32+31}})
      local control=s.chart_control_chunk
      local control_generated=control and surface.is_chunk_generated(control)
      if control_generated then
        force.chart(surface,{{control.x*32,control.y*32},
          {control.x*32+31,control.y*32+31}})
      end
      s.chart_live_request_issued=true
      s.chart_live_request_tick=game.tick
      emit("CHART_LIVE_REQUEST elapsed="..elapsed..
        " control_generated="..tostring(control_generated)..
        " connected_players="..#force.connected_players..
        " generated=true charted="..
          tostring(force.is_chunk_charted(surface,target_chunk))..
        " requested="..
          tostring(force.is_chunk_requested_for_charting(surface,target_chunk)))
    end
    -- Three bounded native snapshots, before the unchanged 1,800-tick
    -- charted-state gate. A requested chunk is NEVER treated as charted.
    for _,mark in ipairs({300,900,1800}) do
      if elapsed>=mark and not s["chart_diag_"..mark] then
        local surface,force=game.surfaces[1],game.forces.player
        local target,control=s.chart_target_chunk,s.chart_control_chunk
        local radar=surface.find_entities_filtered{
          name="radar",position=s.chart_radar_position,
          radius=2,force=force}[1]
        local radar_energy=radar and radar.valid and radar.energy or 0
        local radar_network=radar and radar.valid
          and radar.electric_network_id or nil
        if radar_energy>0 then s.chart_radar_power_observed=true end
        emit("CHART_RADAR_NATIVE_DIAG elapsed="..elapsed..
          " radar_valid="..tostring(not not (radar and radar.valid))..
          " energy_j="..tostring(radar_energy)..
          " electric_network_id="..tostring(radar_network)..
          " ever_powered="..tostring(s.chart_radar_power_observed or false)..
          " daytime="..tostring(surface.daytime))
        emit("CHART_NATIVE_DIAG elapsed="..elapsed..
          " force="..force.name..
          " connected_players="..#force.connected_players..
          " total_players="..#game.players..
          " events_total="..tostring(s.chart_events_total or 0)..
          " events_target="..tostring(s.chart_events_target or 0)..
          " events_control="..tostring(s.chart_events_control or 0)..
          " target_generated="..tostring(surface.is_chunk_generated(target))..
          " target_requested="..tostring(
            force.is_chunk_requested_for_charting(surface,target))..
          " target_charted="..tostring(force.is_chunk_charted(surface,target))..
          " target_raw_chart="..tostring(force.get_chunk_chart(surface,target)~=nil)..
          " control_generated="..tostring(surface.is_chunk_generated(control))..
          " control_requested="..tostring(
            force.is_chunk_requested_for_charting(surface,control))..
          " control_charted="..tostring(force.is_chunk_charted(surface,control))..
          " control_raw_chart="..tostring(force.get_chunk_chart(surface,control)~=nil))
        s["chart_diag_"..mark]=true
      end
    end
    -- Read-only 0469/0338/0836 sampling around the observed 36k-60k stall.
    -- Never plan, yield, cancel, debit or credit work from this diagnostic.
    if elapsed>=36000 and elapsed<=60000 and elapsed%600==0 then
      trace_uncommitted_rail_gap(s,elapsed)
    end
    for _,mark in ipairs({1800,9000,18000,36000,60000,72000,90000}) do
      if elapsed>=mark and not s["checked_"..mark] then
        inspect(s,mark);s["checked_"..mark]=true
      end
    end
  end)
  if not ok then s.failed=tostring(why);emit("FAIL "..s.failed) end
  return {processed=1,failed=s.failed and 1 or 0}
end
function M.install()
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if not(registry and registry.on_init and broker
      and broker.register_service)then
    error(PREFIX.."FAIL canonical test-only lifecycle unavailable")
  end
  -- Observe the engine's actual chart-completion event through the original
  -- event registry; failure to install this diagnostic never blocks gameplay.
  local observed=registry.on_event(defines.events.on_chunk_charted,function(event)
    local s=root()
    if not s.started or s.failed or s.finished
        or not event.force or event.force.index~=game.forces.player.index
        or event.surface_index~=game.surfaces[1].index then return end
    s.chart_events_total=(s.chart_events_total or 0)+1
    local pos,target,control=event.position,s.chart_target_chunk,s.chart_control_chunk
    if target and pos.x==target.x and pos.y==target.y then
      s.chart_events_target=(s.chart_events_target or 0)+1
      emit("CHART_NATIVE_EVENT target tick="..tostring(event.tick))
    end
    if control and pos.x==control.x and pos.y==control.y then
      s.chart_events_control=(s.chart_events_control or 0)+1
      emit("CHART_NATIVE_EVENT control tick="..tostring(event.tick))
    end
  end,nil,{owner="ci_remote_rail_acquisition",route="native-chart-observer",
    category="diagnostics",priority="last"})
  emit("CHART_NATIVE_EVENT_OBSERVER registered="..tostring(not not observed))
  assert(registry.on_init(setup,{owner="ci_remote_rail_acquisition",
    route="initialize",category="diagnostics",priority="last"}))
  assert(broker.register_service{name="ci_remote_rail_acquisition",
    category="diagnostics",interval=60,priority=1100,budget=1,fn=pulse,
    note="isolated 512-tile train and distant ore acceptance"})
  emit("INSTALLED test-only service")
  return true
end
return M
