-- Native mining, normal-control pickup and genuine 1.0.0 save migration.
-- Fixture entities/items are explicit test inputs; this is not an AI economy test.
local M={}
local Registry=require("scripts.core.runtime_event_registry")
local Catalog=require("shared.combat_roster_catalog")
local Bridge=require("scripts.core.combat_roster_bridge")
local PREFIX="[TP-UNIT-BEHAVIOR] "
local function check(value,message) assert(value,PREFIX.."FAIL "..message) end
local function valid(entity) return entity and entity.valid end
local function near(a,b) return math.abs(a-b)<0.001 end
local function state() return storage.unit_behavior_test end
local function seed()
  if script.active_mods["tech-priests"]~="1.0.0" then return end
  if remote.interfaces.freeplay and remote.interfaces.freeplay.set_skip_intro then
    remote.call("freeplay","set_skip_intro",true)
    remote.call("freeplay","set_disable_crashsite",true)
  end
  local surface=game.create_surface("unit-behavior-native",{width=256,height=256,water=0,
    default_enable_all_autoplace_controls=false})
  surface.request_to_generate_chunks({0,0},4);surface.force_generate_chunk_requests()
  local tiles={}
  for x=-80,80 do for y=-80,80 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
  surface.set_tiles(tiles)
  local actor=surface.create_entity{name=Catalog.units[1].name,position={-50,-50},force="player"}
  local machine=surface.create_entity{name="assembling-machine-1",position={-60,-50},force="player"}
  local record=get_consecration_record(actor)
  check(record,"original released mod must exhibit the unit-consecration bug")
  record.sanctification=96;record.max_sanctification=120
  local machinery=get_consecration_record(machine);check(machinery,"machine spirit missing")
  machinery.sanctification=37
  local label=rendering.draw_text{text="TP-M0026",surface=surface,target=actor,color={1,1,0}}
  local glow=rendering.draw_circle{surface=surface,target=actor,color={1,1,0},radius=1,filled=false}
  local c=storage.tech_priests.consecration
  c.renders[actor.unit_number]={label_current=label}
  c.overlays[actor.unit_number]={object=glow}
  storage.unit_behavior_test={surface=surface.index,legacy_unit=actor.unit_number,legacy_actor=actor,
    legacy_label=label,legacy_glow=glow,machine=machine,machine_id=machinery.machine_id_0446,
    phase="upgrade",managed={},old_workers={},prototype_forms_mined=0,worker_cells_redeployed=0}
  log(PREFIX.."LEGACY_SAVE_SEEDED version=1.0.0 unit_sanctification=96/120")
end
local function stock_actor(actor,u)
  actor.health=actor.max_health*.75
  actor.get_inventory(defines.inventory.car_trunk).insert{name="iron-plate",count=7}
  local ammo=actor.get_inventory(defines.inventory.car_ammo)
  check(ammo.insert{name=Catalog.ammo[u.ammo_family].name,count=1}==1,"stock ammunition")
  ammo[1].ammo=3
  check(actor.get_fuel_inventory().insert{name="tech-priests-field-supply-pack",count=2}==2,"stock field supply")
end
local function check_product(player,u)
  local inv=player.get_main_inventory()
  check(inv.get_item_count(u.name)==1,"one unit item after mining "..u.id)
  check(inv.get_item_count("iron-plate")==7,"trunk contents retained "..u.id)
  local ammo=Catalog.ammo[u.ammo_family].name
  check(inv.get_item_count(ammo)==1,"ammunition retained "..u.id)
  local partial=false
  for i=1,#inv do local stack=inv[i]
    if stack.valid_for_read and stack.name==ammo then partial=stack.ammo==3 end
  end
  check(partial,"partial ammunition retained "..u.id)
end
local function worker_round_trip(player,surface,name,index)
  local inv=player.get_main_inventory();inv.clear()
  local station=surface.create_entity{name=name,position={-35+index*16,45},force=player.force,raise_built=true}
  check(valid(station),"worker station created "..name)
  local pair=find_pair_for_entity(station)
  check(pair and valid(pair.priest),"worker canonically paired "..name)
  local priest=pair.priest
  check(priest.minable,"worker mineable "..name)
  check(not is_consecration_target(priest),"worker excluded from consecration")
  pair.persistent_id_0301="pickup-native-"..name
  local persistent=pair.persistent_id_0301
  local old_priest,old_station=priest.unit_number,station.unit_number
  station.get_inventory(defines.inventory.chest).insert{name="copper-plate",count=9}
  station.health=station.max_health*.8;priest.health=priest.max_health*.6
  local bag=game.create_inventory(1)
  bag.insert{name="junior-cogitator-station",count=1}
  bag[1].tags={pickup_cargo="preserve-original-tags"}
  storage.tech_priests.station_cargo_0824=storage.tech_priests.station_cargo_0824 or {}
  local cargo_id="native-pickup-"..index
  storage.tech_priests.station_cargo_0824[cargo_id]={station_unit=old_station,priest_unit=old_priest,inventory=bag}
  player.teleport({priest.position.x,priest.position.y+1},surface)
  check(player.mine_entity(priest),"native player mines worker "..name)
  check(not priest.valid and not station.valid,"original worker and cell removed once")
  check(storage.tech_priests.pairs_by_station[old_station]==nil
    and storage.tech_priests.station_by_priest[old_priest]==nil
    and (not storage.tech_priests.pairs_by_priest or storage.tech_priests.pairs_by_priest[old_priest]==nil),"pair indexes retired")
  check(not bag.valid and storage.tech_priests.station_cargo_0824[cargo_id]==nil,"carried inventory retired")
  local packed,cargo
  for i=1,#inv do local stack=inv[i]
    if stack.valid_for_read and stack.name==name and stack.tags
      and stack.tags.tech_priests_preserved_cell_0301 then packed=stack end
    if stack.valid_for_read and stack.name=="junior-cogitator-station"
      and stack.tags and stack.tags.pickup_cargo=="preserve-original-tags" then cargo=stack end
  end
  check(packed and cargo,"packed cell and distinct tagged cargo preserved")
  check(packed.tags.tech_priests_preserved_cell_0301.persistent_id_0301==persistent,"persistent priest identity retained")
  check(player.clear_cursor(),"clear cursor for actual redeployment")
  check(player.cursor_stack.swap_stack(packed),"move real packed cell to cursor")
  local pos={x=-35+index*16,y=53}
  player.teleport({pos.x,pos.y+2},surface)
  player.build_from_cursor{position=pos,direction=defines.direction.north}
  local rebuilt=surface.find_entities_filtered{name=name,position=pos}[1]
  check(valid(rebuilt),"native cursor redeploys packed cell")
  local restored=find_pair_for_entity(rebuilt)
  check(restored and valid(restored.priest) and restored.persistent_id_0301==persistent,"redeployed priest identity")
  check(rebuilt.get_inventory(defines.inventory.chest).get_item_count("copper-plate")==9,"station inventory restored once")
  check(near(rebuilt.health/rebuilt.max_health,.8) and near(restored.priest.health/restored.priest.max_health,.6),"independent damaged health retained")
  state().old_workers[#state().old_workers+1]={station=old_station,priest=old_priest}
  state().worker_cells_redeployed=state().worker_cells_redeployed+1
end
local function start(player)
  local t=state();local surface=game.surfaces[t.surface];local inv=player.get_main_inventory()
  local c=storage.tech_priests.consecration
  check(not c.machines[t.legacy_unit] and not c.renders[t.legacy_unit] and not c.overlays[t.legacy_unit],"real configuration migration clears old unit state")
  check(not t.legacy_label.valid and not t.legacy_glow.valid,"real migration destroys old unit render objects")
  local machinery=get_consecration_record(t.machine)
  check(machinery and machinery.machine_id_0446==t.machine_id and machinery.sanctification==37,"existing machinery consecration retained")
  t.legacy_migration=true
  if valid(t.legacy_actor) then t.legacy_actor.destroy{raise_destroy=true} end
  for _,u in ipairs(Catalog.units) do
    for _,suffix in ipairs({"","-_-solid","-_-ghost"}) do
      inv.clear();player.teleport({0,2},surface)
      local actor=surface.create_entity{name=u.name..suffix,position={0,0},force=player.force}
      check(valid(actor),"native actor form exists "..u.id..suffix)
      check(actor.minable,"physical actor form mineable "..u.id..suffix)
      check(not is_consecration_target(actor) and get_consecration_record(actor)==nil,"actor has no consecration "..u.id..suffix)
      local oil=inv.insert{name="sacred-machine-oil",count=1}
      check(not apply_consecration_item(player,actor,"sacred-machine-oil"),"oil rejected on unit")
      check(inv.get_item_count("sacred-machine-oil")==oil,"unit rite consumes no oil")
      stock_actor(actor,u)
      check(player.mine_entity(actor),"native player mines physical form "..u.id..suffix)
      check(not actor.valid,"mined form destroyed")
      check_product(player,u)
      t.prototype_forms_mined=t.prototype_forms_mined+1
    end
  end
  for i,u in ipairs(Catalog.units) do
    local actor=surface.create_entity{name=u.name,position={-48+(i%5)*18,-20+math.floor((i-1)/5)*15},force=player.force,raise_built=true}
    check(valid(actor),"native managed actor spawned")
    local unit=Bridge.unit(actor);check(unit,"actual AAI manages unit "..u.id)
    stock_actor(unit.vehicle,u)
    check(Bridge.command(unit.vehicle,player.force,{position={x=unit.vehicle.position.x+5,y=unit.vehicle.position.y}}),"actual AAI movement command")
    t.managed[#t.managed+1]={id=u.id,aai_id=unit.unit_id}
  end
  inv.clear()
  for i,name in ipairs({"junior-cogitator-station","intermediate-cogitator-station","senior-cogitator-station","planetary-magos-cogitator-station"}) do
    worker_round_trip(player,surface,name,i)
  end
  t.phase="managed";t.start_tick=game.tick
  log(PREFIX.."MIGRATION_AND_FORMS_PASS forms="..t.prototype_forms_mined.." worker_cells="..t.worker_cells_redeployed)
end
local function finish_managed(player)
  local t=state();local inv=player.get_main_inventory()
  local units=remote.call("aai-programmable-vehicles","get_units")
  local n=0
  for i,row in ipairs(t.managed) do
    local unit=units[row.aai_id];check(unit and valid(unit.vehicle),"original managed actor remains")
    local actor=unit.vehicle;local u=Catalog.by_id[row.id]
    player.teleport({actor.position.x,actor.position.y+1},actor.surface);inv.clear()
    check(not is_consecration_target(actor),"AI mode does not restore consecration")
    if i==1 then
      for j=1,#inv do inv[j].set_stack{name="stone",count=prototypes.item.stone.stack_size} end
      local driver=actor.get_driver()
      check(not Bridge.pick_up(player,actor),"full inventory refuses pickup")
      check(actor.valid and actor.get_driver()==driver,"failed pickup retains actor and AI driver")
      inv.clear()
    end
    check(Bridge.pick_up(player,actor),"normal mine-control handler picks up AI unit "..u.id)
    check(not actor.valid,"managed actor removed exactly once")
    check_product(player,u);n=n+1
  end
  t.managed_units_picked_up=n;t.phase="settle";t.settle_tick=game.tick
  log(PREFIX.."MANAGED_PICKUP_PASS units="..n.." inventory_full_refusal=true")
end
local function tick()
  local t=state();if not t or t.done then return end
  local player=game.get_player(1)
  if not(player and player.valid and player.get_main_inventory()) then return end
  if t.phase=="upgrade" and game.tick>=60 then start(player)
  elseif t.phase=="managed" and game.tick-t.start_tick>=60 then finish_managed(player)
  elseif t.phase=="settle" and game.tick-t.settle_tick>=60 then
    local units=remote.call("aai-programmable-vehicles","get_units")
    for _,row in ipairs(t.managed) do check(not units[row.aai_id],"AAI record retired after pickup") end
    for _,row in ipairs(t.old_workers) do
      check(not storage.tech_priests.pairs_by_station[row.station],"packed worker not recreated at old station")
    end
    t.done=true
    log(PREFIX.."PASS "..helpers.table_to_json({combat_types=#Catalog.units,
      prototype_forms_mined=t.prototype_forms_mined,managed_units_picked_up=t.managed_units_picked_up,
      worker_cells_redeployed=t.worker_cells_redeployed,legacy_migration=t.legacy_migration,
      actual_player_mining=true,inventory_full_refusal=true,machinery_consecration_preserved=true}))
  end
end
function M.install()
  Registry.on_init(seed,{owner="unit-behavior-native",route="legacy-save-seed"})
  -- This fixture starts before any Cogitator is placed. The production nth-tick
  -- idle gate correctly sleeps then; use the established combat-test on_tick
  -- route so the test can perform its first native player placement.
  Registry.on_event(defines.events.on_tick,function()
    local ok,err=pcall(tick)
    if not ok then if state() then state().done=true end;log(PREFIX.."FAIL "..tostring(err)) end
  end,nil,{owner="unit-behavior-native",route="native-player-pickup",priority=2000})
end
return M
