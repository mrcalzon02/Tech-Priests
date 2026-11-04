-- Factorio 2.0.77 native test: stocked *station items*, not minted priests.
-- Every expansion must pay a real engine inventory debit and become a paired
-- physical Cogitator. No prebuilt child stations or synthetic range bonuses.
local M={}
local PREFIX="[TP-SURPLUS-COVERAGE] "
local KEY="ci_surplus_station_coverage_1207"
local Cargo=require("scripts.core.station_cargo_0824")
local RANKS={
  {name="junior-cogitator-station",x=0,stock="junior-cogitator-station"},
  {name="intermediate-cogitator-station",x=24,
    stock="intermediate-cogitator-station"},
  {name="senior-cogitator-station",x=48,stock="senior-cogitator-station"},
  {name="planetary-magos-cogitator-station",x=72,
    stock="senior-cogitator-station"},
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
    local inserted=inv.insert{name=row.stock,count=2}
    if inserted~=2 or inv.get_item_count(row.stock)~=2 then
      fail("PARENT_PHYSICAL_SURPLUS_NOT_STOCKED "..row.name)
    end
    -- Lua-local RANKS are reset on benchmark save/reload; persist identities.
    s.units[index]=built.unit_number
    s.initial[built.unit_number]=true
    s.stock[built.unit_number]={item=row.stock,initial=2}
    emit("PHYSICAL_DEPOT rank="..row.name.." unit="..built.unit_number..
      " spare="..row.stock.." count=2")
  end
  s.initial_count=#RANKS
  emit("SETUP original_stations=4 stocked_stations=4 physical_spares=8"..
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
  -- The existing 0256 station builder owns the planning ghost and the real
  -- priest-carried engine inventory. West is deliberately outside the
  -- original junior territory; nothing is spawned by this fixture.
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
  if remaining<0 or remaining>2 then
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
  local carried=0
  if rec then
    local cargo=Cargo.get(junior,rec)
    if cargo and cargo.inventory and cargo.inventory.valid then
      carried=cargo.inventory.get_item_count(RANKS[1].stock)
    end
  end
  emit("CHECKPOINT elapsed="..elapsed.." paired="..pairs_count..
    " source_stock="..remaining.." carried="..carried..
    " writ="..tostring(s.writ_id or "none")..
    " phase="..tostring(rec and rec.phase or "none")..
    " status="..tostring(rec and rec.status or "none")..
    " real_west_child="..tostring(child and child.station.unit_number or "none")..
    " frontier_x="..tostring(child and child.station.position.x or "none"))
  if rec and rec.status=="complete" and child
      and rec.ghost_position
      and math.abs(child.station.position.x-rec.ghost_position.x)<0.1
      and math.abs(child.station.position.y-rec.ghost_position.y)<0.1
      and remaining==1 and pairs_count>=5 then
    s.completed=true;s.child_unit=child.station.unit_number
    emit("PASS original Junior physically spent one station item"..
      " and built a new living paired Junior beyond initial western coverage"..
      " new_unit="..s.child_unit.." source_remaining="..remaining)
    return
  end
  if elapsed>=72000 then
    fail("COVERAGE_SURPLUS_NOT_PHYSICALLY_DEPLOYED"..
      " source_remaining="..remaining..
      " phase="..tostring(rec and rec.phase)..
      " paired="..pairs_count)
  end
end
local function pulse()
  local s=state()
  if s.completed or s.failed then return {processed=0} end
  local ok,why=pcall(function()
    if not s.started then fail("SETUP_NOT_RUN") end
    if game.tick-s.started>=300 then issue_first() end
    for _,mark in ipairs(CHECKPOINTS)do
      if game.tick-s.started>=mark and not s["checked_"..mark] then
        inspect(mark);s["checked_"..mark]=true
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
    error(PREFIX.."FAIL canonical isolated-test lifecycle unavailable")
  end
  assert(registry.on_init(setup,{
    owner="ci_surplus_station_coverage_1207",
    route="initialize",category="diagnostics",priority="last"}))
  assert(broker.register_service{
    name="ci_surplus_station_coverage_1207",category="diagnostics",
    interval=60,priority=1100,budget=1,fn=pulse,
    note="original paired Junior pays stocked station item for physical westward coverage"})
  emit("INSTALLED independent stock-fed priest coverage acceptance")
  return true
end
return M
