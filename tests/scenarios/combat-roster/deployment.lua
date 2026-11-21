-- Native Factorio 2.1 recruitment acceptance, not a source-only simulation.
-- Scenario setup gives TECHNOLOGY and starting raw ingredients as test inputs,
-- never completed combat actors. Actual faction assemblers must craft items.
-- Only canonical 0338 may build the Guardsman from a debited physical item;
-- only 0702 and native AAI may fuel, arm, move and attack with that actor.
local Registry=require("scripts.core.runtime_event_registry")
local Catalog=require("shared.combat_roster_catalog")
local Orders=require("scripts.core.combat_roster_orders")
local Bridge=require("scripts.core.combat_roster_bridge")
local PREFIX="[TP-COMBAT-DEPLOY] "
local function check(ok,reason) assert(ok,PREFIX.."FAIL "..tostring(reason)) end
local examples={
 {id="skitarii-ranger",factory="tech-priests-martian-manufactorum",x=-60},
 {id="guardsman",factory="tech-priests-guard-muster-hall",x=0},
 {id="battle-sister",factory="tech-priests-sororitas-convent",x=60},
}
local INPUT=defines.inventory.assembling_machine_input
local OUTPUT=defines.inventory.assembling_machine_output
local function initial()
 local s=game.create_surface("tech-priests-physical-muster-proof",{
  water=0,starting_area=0,default_enable_all_autoplace_controls=false,
  autoplace_settings={entity={treat_missing_as_default=false,settings={}}}})
 s.always_day=true;s.peaceful_mode=false
 s.request_to_generate_chunks({x=0,y=20},5);s.force_generate_chunk_requests()
 for _,e in pairs(s.find_entities())do if e.valid then e.destroy()end end
 local tiles={}
 for x=-92,92 do for y=-30,92 do
  tiles[#tiles+1]={name="refined-concrete",position={x=x,y=y}}
 end end
 s.set_tiles(tiles)
 local force=game.forces.player
 for _,name in ipairs({"tech-priests-guard-muster","tech-priests-militant-orders",
                         "tech-priests-bolt-armaments"})do
  check(force.technologies[name],"test technology missing "..name)
  force.technologies[name].researched=true
 end
 storage.combat_deploy={start=game.tick,stage=0,entries={},surface=s.index,
   native_hits=0,damage=0,initial_stock={},fixture_unlocks_only=true}
 local t=storage.combat_deploy
 for _,entry in ipairs(examples)do
  local unit=Catalog.by_id[entry.id]
  check(unit and force.recipes[unit.name] and force.recipes[unit.name].enabled,
    "unit not unlocked by faction research "..entry.id)
  local position={x=entry.x,y=0}
  local machine=s.create_entity{name=entry.factory,position=position,force=force,
    direction=defines.direction.north}
  check(machine and machine.valid,"missing native faction assembly "..entry.factory)
  check(machine.prototype.crafting_categories[
    "tech-priests-recruit-"..(unit.faction=="astra-militarum"and"guard"
      or unit.faction=="sororitas"and"sororitas"or"mechanicus")],
    "wrong native faction recipe category "..entry.id)
  check(machine.set_recipe(unit.name)==true or machine.get_recipe().name==unit.name,
    "cannot set combat actor recipe "..entry.id)
  local inv=machine.get_inventory(INPUT)
  check(inv and inv.valid,"native assembler input missing "..entry.id)
  for _,row in ipairs(unit.ingredients)do
   check(inv.insert{name=row[1],count=row[2]}==row[2],
     "cannot stock real actor ingredient "..entry.id.." item="..row[1])
  end
  local generator=s.create_entity{name="electric-energy-interface",
    position={x=entry.x+8,y=8},force=force}
  local pole=s.create_entity{name="substation",
    position={x=entry.x+5,y=4},force=force}
  check(generator and pole,"test-only physical power interface unavailable")
  generator.power_production=1000000000
  generator.electric_buffer_size=1000000000
  t.entries[#t.entries+1]={id=entry.id,unit=unit,machine=machine,
    output=machine.get_inventory(OUTPUT),input=inv}
 end
 -- The canonical event handler owns the actual paired Senior, not this
 -- fixture. A flat generated surface leaves legal original spawn tiles.
 local station=s.create_entity{name="senior-cogitator-station",
   position={x=0,y=40},force=force,raise_built=true}
 check(station and station.valid,"original Senior Cogitator placement failed")
 t.station=station
 local enemy=game.forces.enemy
 local target=s.create_entity{name="tech-priests-combat-test-target",
   position={x=28,y=53},force=enemy}
 check(target and target.valid,"native hostile target missing")
 target.disabled_by_script=true
 t.target=target;t.target_initial_health=target.health
 local friendly=s.create_entity{name="tech-priests-combat-test-target",
   position={x=8,y=60},force=force}
 check(friendly and friendly.valid,"friendly test target missing")
 friendly.disabled_by_script=true;t.friendly=friendly;t.friendly_initial_health=friendly.health
 t.deployment_position={x=12,y=53}
 t.rally_position={x=26,y=53}
 log(PREFIX.."INIT three original electrically powered recruitment buildings; raw recipe ingredients supplied only by fixture")
end
local function sample(event)
 local t=storage.combat_deploy;if not t or t.done then return end
 local elapsed=game.tick-t.start
 if t.stage==0 and elapsed>=3600 then
  for _,entry in ipairs(t.entries)do
   check(entry.machine.valid and entry.machine.energy>0,"native power not supplied "..entry.id)
   check(entry.output.get_item_count(entry.unit.name)>=1,
     "faction building did not craft combat unit "..entry.id)
   for _,row in ipairs(entry.unit.ingredients)do
    check(entry.input.get_item_count(row[1])==0,
      "combat actor recipe did not debit ingredient "..entry.id.."/"..row[1])
   end
  end
  local pair=storage.tech_priests and storage.tech_priests.pairs_by_station
    and storage.tech_priests.pairs_by_station[t.station.unit_number]
  check(pair and pair.priest and pair.priest.valid,
    "original Senior Cogitator not canonically paired")
  local station_stock=t.station.get_inventory(defines.inventory.chest)
  check(station_stock and station_stock.valid,"original Cogitator native inventory unavailable")
  local guard=Catalog.by_id.guardsman
  local guard_output=t.entries[2].output
  -- Fixture handoff is counted physical inventory removal and insertion.
  -- It is NOT credited as autonomous logistics or real machine transport.
  check(guard_output.remove{name=guard.name,count=1}==1,
    "cannot debit actually crafted Guardsman item")
  check(station_stock.insert{name=guard.name,count=1}==1,
    "actually produced Guardsman not retained at Cogitator")
  local ammo=Catalog.ammo[guard.ammo_family].name
  check(station_stock.insert{name=ammo,count=5}==5,
    "test ammo starting stock not physically inserted")
  check(station_stock.insert{name="tech-priests-field-supply-pack",count=5}==5,
    "test field fuel starting stock not physically inserted")
  t.initial_stock={actor=station_stock.get_item_count(guard.name),
    ammo=station_stock.get_item_count(ammo),
    fuel=station_stock.get_item_count("tech-priests-field-supply-pack")}
  check(t.initial_stock.actor==1 and t.initial_stock.ammo==5
    and t.initial_stock.fuel==5,"starting custody readback mismatch")
  local accepted,token=Orders.request(pair,"guardsman",
    t.deployment_position,t.rally_position,"normal")
  check(accepted==true,"canonical physical muster refused "..tostring(token))
  t.pair_unit=t.station.unit_number;t.token=token;t.stage=1
  log(PREFIX.."FACTORIES_PASS three real faction recipes and original Guardsman item debit, canonical request="..tostring(token))
 elseif t.stage==1 and elapsed>=23000 then
  local pair=storage.tech_priests.pairs_by_station[t.pair_unit]
  check(pair and pair.priest and pair.priest.valid,"original builder vanished")
  local receipt=pair.combat_muster_build_receipt
  check(receipt and receipt.accepted==true,"no original counted 0338 combat build receipt")
  local order=pair.combat_muster_last
  check(order and order.id==t.token and order.phase=="commanded",
    "AAI fuel/munition/rally command not physically completed")
  local actor=order.actor
  check(actor and actor.valid and Catalog.for_entity_name(actor.name).id=="guardsman",
    "built actor identity missing after native AAI mode changes")
  check(actor.force==t.station.force and actor.surface==t.station.surface,
    "AAI actor force or surface identity changed")
  local aai=Bridge.unit(actor)
  check(aai and aai.unit_id,"native AAI does not manage built Guardsman")
  local inv=t.station.get_inventory(defines.inventory.chest)
  check(inv.get_item_count("tech-priests-combat-guardsman")==0,
    "physically crafted unit was not spent by original builder")
  check(inv.get_item_count("tech-priests-las-charge-cell")<t.initial_stock.ammo,
    "no real ammunition withdrawal for Guardsman")
  check(inv.get_item_count("tech-priests-field-supply-pack")<t.initial_stock.fuel,
    "no real field-fuel withdrawal for Guardsman")
  check(t.native_hits>0 and t.target.health<t.target_initial_health,
    "native AAI Guardsman did not damage actual enemy force")
  check(t.friendly.health==t.friendly_initial_health,
    "friendly construction/force target was attacked")
  local proof={passed=true,units_physically_crafted=3,types=3,
    original_build_receipt=receipt,original_builder_unit=t.pair_unit,
    actor_unit=actor.unit_number,aai_unit=aai.unit_id,
    native_hostile_hits=t.native_hits,real_hostile_damage=t.damage,
    ammo_source_before=t.initial_stock.ammo,
    ammo_source_after=inv.get_item_count("tech-priests-las-charge-cell"),
    fuel_source_before=t.initial_stock.fuel,
    fuel_source_after=inv.get_item_count("tech-priests-field-supply-pack"),
    fixture_technology_unlocks=true,
    fixture_ingredient_supply=true,
    fixture_stock_handoff=true,
    independently_generated_units=false}
  helpers.write_file("combat-roster/deployment.json",helpers.table_to_json(proof),false)
  t.done=true
  log(PREFIX.."PASS native faction buildings, original paid 0338 Guardsman, 0702 material transfer and real AAI combat")
 end
end
local function damaged(event)
 local t=storage.combat_deploy
 if t and t.target and event.entity==t.target
    and event.final_damage_amount and event.final_damage_amount>0 then
  t.native_hits=t.native_hits+1;t.damage=t.damage+event.final_damage_amount
 end
end
Registry.on_init(initial,{owner="combat-recruitment-proof",route="setup",priority=2100})
Registry.on_event(defines.events.on_tick,sample,nil,
  {owner="combat-recruitment-proof",route="native-observation",priority=2100})
Registry.on_event(defines.events.on_entity_damaged,damaged,nil,
  {owner="combat-recruitment-proof",route="damage-receipt",priority=2100})
