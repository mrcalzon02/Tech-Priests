-- Factorio 2.0.77 native test: stocked *station items*, not minted priests.
-- Every expansion must pay a real engine inventory debit and become a paired
-- physical Cogitator. No prebuilt child stations or synthetic range bonuses.
local M={}
local PREFIX="[TP-SURPLUS-COVERAGE] "
local KEY="ci_surplus_station_coverage_1207"
local Cargo=require("scripts.core.station_cargo_0824")
local RANKS={
  -- Junior is deliberately EMPTY: no source inventory, no free deployed unit.
  {name="junior-cogitator-station",x=0,
    stock="junior-cogitator-station",count=0},
  -- Neighboring Intermediate donates one of three REAL Junior kits;
  -- it retains at least one physical reserve for its own work.
  {name="intermediate-cogitator-station",x=24,
    stock="junior-cogitator-station",count=3},
  {name="senior-cogitator-station",x=48,
    stock="intermediate-cogitator-station",count=2},
  {name="planetary-magos-cogitator-station",x=72,
    stock="senior-cogitator-station",count=2},
}
local CHECKPOINTS={900,3600,9000,18000,36000,72000}
local function emit(msg) log(PREFIX..msg) end
local function fail(msg) error(PREFIX.."FAIL "..msg) end
local function state()
  storage.tech_priests=storage.tech_priests or {}
  local tp=storage.tech_priests
  tp[KEY]=tp[KEY] or {}
  return tp[KEY]
end
local function live_pair(station_unit)
  local tp=storage and storage.tech_priests
  local pair=tp and tp.pairs_by_station and tp.pairs_by_station[station_unit]
  if pair and pair.station and pair.station.valid
      and pair.priest and pair.priest.valid then return pair end
end
local function station_inv(pair)
  if not pair then return nil end
  local ok,inv=pcall(function()
    return pair.station.get_inventory(defines.inventory.chest)
  end)
  return ok and inv and inv.valid and inv or nil
end
local function setup()
  local s=state()
  if s.started then return end
  local surface,force=game.surfaces[1],game.forces.player
  for x=-64,128,32 do
    surface.request_to_generate_chunks({x=x,y=0},2)
  end
  surface.force_generate_chunk_requests()
  local area={{-64,-44},{130,45}}
  for _,entity in ipairs(surface.find_entities_filtered{area=area}) do
    if entity.valid and (entity.type=="resource"
        or entity.type=="tree" or entity.type=="simple-entity"
        or entity.type=="cliff" or entity.force==game.forces.enemy) then
      entity.destroy()
    end
  end
  local tiles={}
  for x=-64,129 do for y=-43,44 do
    tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
  end end
  surface.set_tiles(tiles,true)
  s.initial={};s.stock={};s.units={};s.started=game.tick
  for index,row in ipairs(RANKS) do
    if not(prototypes.entity[row.name] and prototypes.item[row.stock]) then
      fail("MISSING_STATION_PROTOTYPE "..row.name.."/"..row.stock)
    end
    local position={x=row.x,y=0}
    if not surface.can_place_entity{name=row.name,position=position,
        force=force} then fail("PARENT_PLACEMENT_BLOCKED "..row.name) end
    local built=surface.create_entity{
      name=row.name,position=position,force=force,raise_built=true}
    if not(built and built.valid) then fail("PARENT_CREATE_FAILED "..row.name)end
    local inv=built.get_inventory(defines.inventory.chest)
    if not(inv and inv.valid) then fail("PARENT_CHEST_MISSING "..row.name)end
    local required=row.count or 0
    local inserted=required>0
      and inv.insert{name=row.stock,count=required} or 0
    if inserted~=required or inv.get_item_count(row.stock)~=required then
      fail("PARENT_PHYSICAL_SURPLUS_NOT_STOCKED "..row.name)
    end
    -- Lua-local RANKS are reset on benchmark save/reload; persist identities.
    s.units[index]=built.unit_number
    s.initial[built.unit_number]=true
    s.stock[built.unit_number]={item=row.stock,initial=required}
    emit("PHYSICAL_DEPOT rank="..row.name.." unit="..built.unit_number..
      " spare="..row.stock.." count="..required)
  end
  s.initial_count=#RANKS
  emit("SETUP original_stations=4 stocked_stations=3 physical_spares=7"..
    " receiver_junior_initial=0 intermediate_donor_juniors=3"..
    " child_stations=0 fixture_inserts_only=true")
end
local function issue_first()
  local s=state()
  if s.issued then return end
  local junior=live_pair(s.units and s.units[1])
  if not junior then return end
  local Expansion=rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_0256")
  if not(Expansion and type(Expansion.request_station_expansion)=="function") then
    fail("CANONICAL_STATION_EXPANSION_UNAVAILABLE")
  end
  -- 0256 owns the ghost/physical construction; 1208 must first move ONE
  -- real kit from the Intermediate donor into the Junior's own stock.
  -- West is outside the original Junior territory. No priest is spawned
  -- or credited by this fixture after setup.
  local accepted=Expansion.request_station_expansion(
    junior,"coverage-surplus-test",nil,
    "physically-stocked-peer-relay",math.pi)
  if not accepted then return end
  local root=storage.tech_priests
  for _,rec in pairs(root.station_expansion_0256 or {}) do
    if rec.requester_station_unit==junior.station.unit_number
        and rec.blocked_item=="coverage-surplus-test"
        and rec.status=="active" and rec.station_item==RANKS[1].stock
        and rec.worker_station_unit==junior.station.unit_number then
      s.writ_id=rec.id
      s.issued=game.tick
      emit("REAL_EXPANSION_REQUEST writ="..rec.id..
        " worker="..junior.station.unit_number..
        " item="..rec.station_item..
        " ghost_x="..tostring(rec.ghost_position.x))
      return
    end
  end
  fail("REQUEST_ACCEPTED_WITHOUT_OWNED_PHYSICAL_WRIT")
end
local function inspect(elapsed)
  local s=state()
  local root=storage.tech_priests
  local junior=live_pair(s.units and s.units[1])
  local inv=station_inv(junior)
  if not inv then
    local tp=storage and storage.tech_priests
    local id=s.units and s.units[1]
    local p=tp and tp.pairs_by_station and tp.pairs_by_station[id]
    fail("ORIGINAL_JUNIOR_OR_INVENTORY_LOST stored_unit="..tostring(id)..
      " pair="..tostring(p~=nil)..
      " station_valid="..tostring(p and p.station and p.station.valid)..
      " priest_valid="..tostring(p and p.priest and p.priest.valid))
  end
  local remaining=inv.get_item_count(RANKS[1].stock)
  local donor=live_pair(s.units and s.units[2])
  local donor_inv=station_inv(donor)
  if not donor_inv then fail("NEARBY_INTERMEDIATE_DONOR_INVENTORY_LOST") end
  local donor_remaining=donor_inv.get_item_count(RANKS[1].stock)
  if remaining<0 or remaining>1 then
    fail("INVALID_PHYSICAL_STATION_ITEM_COUNT "..remaining)
  end
  local rec=s.writ_id and root.station_expansion_0256
    and root.station_expansion_0256[s.writ_id]
  local pairs_count,child=nil,nil
  pairs_count=0
  for unit,pair in pairs(root.pairs_by_station or {})do
    if pair.station and pair.station.valid and pair.priest and pair.priest.valid
        and pair.station.force==junior.station.force
        and pair.station.surface==junior.station.surface then
      pairs_count=pairs_count+1
      if not s.initial[unit] and pair.station.name==RANKS[1].stock
          and pair.station.position.x < -4 then
        child=pair
      end
    end
  end
  local relay=junior.station_surplus_resupply_1208
  local receipt=junior.station_surplus_last_receipt_1208
  local relay_carried=relay and relay.bag and relay.bag.valid
    and relay.bag.get_item_count(RANKS[1].stock) or 0
  local carried=0
  if rec then
    local cargo=Cargo.get(junior,rec)
    if cargo and cargo.inventory and cargo.inventory.valid then
      carried=cargo.inventory.get_item_count(RANKS[1].stock)
    end
  end
  emit("CHECKPOINT elapsed="..elapsed.." paired="..pairs_count..
    " source_stock="..remaining.." donor_junior_stock="..donor_remaining..
    " carried="..carried.." surplus_carried="..relay_carried..
    " surplus_phase="..tostring(relay and relay.phase or "none")..
    " surplus_receipt="..tostring(receipt and receipt.quantity or "none")..
    " donor_before="..tostring(receipt and receipt.donor_readback_before or "none")..
    " donor_after="..tostring(receipt and receipt.donor_readback_after or "none")..
    " writ="..tostring(s.writ_id or "none")..
    " phase="..tostring(rec and rec.phase or "none")..
    " status="..tostring(rec and rec.status or "none")..
    " real_west_child="..tostring(child and child.station.unit_number or "none")..
    " frontier_x="..tostring(child and child.station.position.x or "none"))
  if rec and rec.status=="complete" and child
      and rec.ghost_position
      and math.abs(child.station.position.x-rec.ghost_position.x)<0.1
      and math.abs(child.station.position.y-rec.ghost_position.y)<0.1
      and remaining==0 and pairs_count>=5
      and receipt and receipt.record_id==rec.id
      and receipt.item==RANKS[1].stock
      and receipt.donor_unit==s.units[2]
      and receipt.destination_unit==s.units[1]
      and receipt.quantity==1
      and receipt.picked_tick and receipt.delivered_tick
      and receipt.delivered_tick>=receipt.picked_tick
      and type(receipt.donor_readback_before)=="number"
      and type(receipt.donor_readback_after)=="number"
      and receipt.donor_readback_before-receipt.donor_readback_after==1
      and receipt.destination_readback>=1
      and donor_remaining<=2 then
    s.completed=true;s.child_unit=child.station.unit_number
    emit("PASS original Junior physically spent one station item"..
      " after its own priest collected the donor's real surplus"..
      " and returned it to the Junior before building a new living paired"..
      " station beyond initial western coverage"..
      " new_unit="..s.child_unit.." source_remaining="..remaining..
      " donor_delta="..(receipt.donor_readback_before-
        receipt.donor_readback_after)..
      " donor_current="..donor_remaining..
      " receipt_pickup="..receipt.picked_tick..
      " receipt_delivery="..receipt.delivered_tick)
    return
  end
  if elapsed>=72000 then
    fail("COVERAGE_SURPLUS_NOT_PHYSICALLY_DEPLOYED"..
      " source_remaining="..remaining..
      " donor_remaining="..donor_remaining..
      " relay="..tostring(relay and relay.phase).. 
      " receipt="..tostring(receipt and receipt.quantity)..
      " phase="..tostring(rec and rec.phase)..
      " paired="..pairs_count)
  end
end
-- Second physical tier: the original Senior must donate one real
-- Intermediate kit to its original Intermediate worker. That worker
-- must carry it home, spend it at a separate real ghost and receive a
-- second living paired station. This is not a fixture-granted kit.
local function issue_second()
  local s=state()
  if not(s.completed and not s.tier2_issued) then return end
  local senior=live_pair(s.units and s.units[3])
  local intermediate=live_pair(s.units and s.units[2])
  if not(senior and intermediate) then return end
  local Expansion=rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_0256")
  if not(Expansion and type(Expansion.request_station_expansion)=="function") then
    fail("CANONICAL_TIER2_EXPANSION_UNAVAILABLE")
  end
  -- The Senior constructs a lower-ranked Intermediate via the actual
  -- Intermediate priest (never a CI-created second worker).
  local accepted=Expansion.request_station_expansion(
    senior,"coverage-surplus-tier2",nil,
    "real-senior-to-intermediate-surplus-kit",math.pi/2)
  if not accepted then return end
  local root=storage.tech_priests
  for _,rec in pairs(root.station_expansion_0256 or {}) do
    if rec.requester_station_unit==senior.station.unit_number
        and rec.blocked_item=="coverage-surplus-tier2"
        and rec.status=="active"
        and rec.worker_station_unit==intermediate.station.unit_number
        and rec.station_item=="intermediate-cogitator-station" then
      s.tier2_writ_id=rec.id
      s.tier2_issued=game.tick
      emit("REAL_TIER2_EXPANSION_REQUEST writ="..rec.id..
        " requester="..senior.station.unit_number..
        " worker="..intermediate.station.unit_number..
        " item="..rec.station_item..
        " ghost_x="..tostring(rec.ghost_position.x)..
        " ghost_y="..tostring(rec.ghost_position.y))
      return
    end
  end
  fail("TIER2_REQUEST_WITHOUT_OWNED_INTERMEDIATE_WRIT")
end
local function inspect_second(elapsed)
  local s=state()
  if not s.tier2_issued then return end
  local root=storage.tech_priests
  local senior=live_pair(s.units and s.units[3])
  local intermediate=live_pair(s.units and s.units[2])
  local senior_inv=station_inv(senior)
  local worker_inv=station_inv(intermediate)
  if not(senior_inv and worker_inv) then fail("TIER2_ORIGINAL_DEPOT_LOST") end
  local item="intermediate-cogitator-station"
  local donor_remaining=senior_inv.get_item_count(item)
  local worker_remaining=worker_inv.get_item_count(item)
  local rec=root.station_expansion_0256
    and root.station_expansion_0256[s.tier2_writ_id]
  local receipt=intermediate.station_surplus_last_receipt_1208
  local child=nil
  local paired=0
  for unit,pair in pairs(root.pairs_by_station or {}) do
    if pair.station and pair.station.valid and pair.priest and pair.priest.valid
        and pair.station.force==senior.station.force
        and pair.station.surface==senior.station.surface then
      paired=paired+1
      if not s.initial[unit] and pair.station.name==item
          and rec and rec.ghost_position
          and (pair.station.position.x-rec.ghost_position.x)^2+
              (pair.station.position.y-rec.ghost_position.y)^2<0.05 then
        child=pair
      end
    end
  end
  if rec and rec.status=="complete" and child and paired>=6
      and worker_remaining==0 and donor_remaining==1
      and receipt and receipt.record_id==rec.id
      and receipt.item==item and receipt.quantity==1
      and receipt.donor_unit==s.units[3]
      and receipt.destination_unit==s.units[2]
      and receipt.donor_readback_before==2
      and receipt.donor_readback_after==1
      and receipt.destination_readback>=1
      and receipt.picked_tick and receipt.delivered_tick
      and receipt.delivered_tick>=receipt.picked_tick
      and live_pair(s.child_unit)
      and station_inv(live_pair(s.units[2]))
        .get_item_count("junior-cogitator-station")==2 then
    s.tier2_completed=true
    s.tier2_child_unit=child.station.unit_number
    emit("PASS second ranked physical coverage expansion"..
      " original Senior donated one exact Intermediate kit"..
      " original Intermediate priest carried and spent it"..
      " new_unit="..s.tier2_child_unit..
      " original_junior_child="..s.child_unit..
      " paired="..paired.." senior_remaining="..donor_remaining..
      " intermediate_remaining="..worker_remaining..
      " donor_delta="..(receipt.donor_readback_before-
        receipt.donor_readback_after)..
      " pickup="..receipt.picked_tick..
      " delivery="..receipt.delivered_tick)
    return
  end
  if elapsed>=72000 then
    fail("TIER2_STOCKED_EXPANSION_TIMEOUT"..
      " status="..tostring(rec and rec.status)..
      " phase="..tostring(rec and rec.phase)..
      " paired="..paired.." donor="..donor_remaining..
      " worker_stock="..worker_remaining..
      " receipt="..tostring(receipt and receipt.quantity))
  end
end
local function pulse()
  local s=state()
  if s.tier2_completed or s.failed then return {processed=0} end
  local ok,why=pcall(function()
    if not s.started then fail("SETUP_NOT_RUN") end
    if game.tick-s.started>=300 then issue_first() end
    for _,mark in ipairs(CHECKPOINTS)do
      if not s.completed
          and game.tick-s.started>=mark
          and not s["checked_"..mark] then
        inspect(mark);s["checked_"..mark]=true
      end
    end
    if s.completed then
      issue_second()
      inspect_second(game.tick-s.started)
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
    error(PREFIX.."FAIL canonical isolated-test lifecycle unavailable")
  end
  assert(registry.on_init(setup,{
    owner="ci_surplus_station_coverage_1207",
    route="initialize",category="diagnostics",priority="last"}))
  assert(broker.register_service{
    name="ci_surplus_station_coverage_1207",category="diagnostics",
    interval=60,priority=1100,budget=1,fn=pulse,
    note="two ranked physical station-item relays, counted stock, paired frontier builds"})
  emit("INSTALLED independent stock-fed priest coverage acceptance")
  return true
end
return M
