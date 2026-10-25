-- Standalone, test-only Factorio 2.0 scenario. Never shipped with the mod.
-- Install into an isolated Tech-Priests control.lua at PARSE TIME.
-- Four live paired ranks; two rows of genuinely crafting vanilla assemblers
-- per rank. No fabricated production, consecration completion or repair.
local M={}
local PREFIX="[TP-CONSECRATION-TEST] "
local SPECS={
  {name="junior-cogitator-station",x=0},
  {name="intermediate-cogitator-station",x=72},
  {name="senior-cogitator-station",x=144},
  {name="planetary-magos-cogitator-station",x=216},
}
local STATE_KEY="ci_consecration_maintenance"
local function emit(msg) log(PREFIX..msg) end
local function fail(msg) error(PREFIX.."FAIL "..msg) end
local function root()
  storage.tech_priests=storage.tech_priests or {}
  local s=storage.tech_priests[STATE_KEY] or {}
  storage.tech_priests[STATE_KEY]=s
  return s
end
local function safe_create(surface,opts)
  if not (prototypes.entity[opts.name] and
      surface.can_place_entity{name=opts.name,position=opts.position,force=opts.force}) then
    fail("cannot physically place "..opts.name)
  end
  local e=surface.create_entity(opts)
  if not (e and e.valid) then fail("engine refused "..opts.name) end
  return e
end
local function inv(e,id)
  local i=e.get_inventory(id)
  if not (i and i.valid) then fail("missing inventory for "..e.name) end
  return i
end
local function setup()
  local s=root()
  if s.started then return end
  local surface,force=game.surfaces[1],game.forces.player
  if not (prototypes.entity["electric-energy-interface"]
      and prototypes.entity["substation"]
      and prototypes.entity["assembling-machine-1"]) then
    fail("fixture needs vanilla electricity and assembler prototypes")
  end
  for _,rank in ipairs(SPECS) do
    surface.request_to_generate_chunks({x=rank.x,y=12},2)
  end
  surface.force_generate_chunk_requests()
  local tiles={}
  for x=-25,243 do for y=-16,34 do
    tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
  end end
  surface.set_tiles(tiles,true)
  -- Only remove unwanted random terrain/resources/enemies inside the
  -- reserved fixture rectangle; never clear player machines on live maps.
  for _,e in ipairs(surface.find_entities_filtered{
      area={{-25,-16},{244,35}}}) do
    if e.valid and (e.type=="resource" or e.type=="tree"
        or e.type=="simple-entity" or e.type=="cliff"
        or e.force==game.forces.enemy) then e.destroy() end
  end
  s.ranks={}
  for _,rank in ipairs(SPECS) do
    local st=safe_create(surface,{
      name=rank.name,position={x=rank.x,y=0},force=force,raise_built=true})
    local chest=inv(st,defines.inventory.chest)
    local supplies={{"repair-pack",16},{"firearm-magazine",24},
      {"sacred-machine-oil",16},{"machine-maintenance-litany",8}}
    for _,item in ipairs(supplies) do
      if not prototypes.item[item[1]] or chest.insert{name=item[1],count=item[2]}~=item[2] then
        fail("prestock denied "..item[1].." at "..rank.name)
      end
    end
    local generator=safe_create(surface,{name="electric-energy-interface",
      position={x=rank.x,y=24},force=force})
    generator.power_production=10*1000*1000
    generator.energy=10*1000*1000
    for _,xoffset in ipairs({-7,7}) do
      safe_create(surface,{name="substation",
        position={x=rank.x+xoffset,y=12},force=force})
    end
    local rec={station_unit=st.unit_number,machines={},supplies={}}
    for _,item in ipairs(supplies) do rec.supplies[item[1]]=item[2] end
    for _,y in ipairs({7,17}) do
      for _,offset in ipairs({-10,-4,4,10}) do
        local machine=safe_create(surface,{
          name="assembling-machine-1",position={x=rank.x+offset,y=y},
          force=force,raise_built=true})
        if not machine.set_recipe("iron-gear-wheel") then
          fail("assembler refused vanilla engine recipe")
        end
        if inv(machine,defines.inventory.assembling_machine_input)
            .insert{name="iron-plate",count=30}~=30 then
          fail("assembler ingredient insertion refused")
        end
        if not is_consecration_target(machine) then
          fail("vanilla machine not registered as consecration target")
        end
        local ledger=get_consecration_record(machine)
        if not ledger then fail("consecration ledger missing") end
        -- Some machines enter the test already worn. This represents a
        -- pre-aged test specimen, NOT a performed rite or earned repair.
        -- Real assembly still drives further operation-dependent decay.
        ledger.sanctification=math.floor(
          (tonumber(ledger.max_sanctification) or 100)*.38)
        rec.machines[#rec.machines+1]={
          unit=machine.unit_number,entity=machine,
          initial_purity=ledger.sanctification,
          initial_health=machine.health,
        }
      end
    end
    s.ranks[rank.name]=rec
    emit("SETUP rank="..rank.name.." station="..st.unit_number..
      " assemblers="..#rec.machines.." repair=16 oil=16 litany=8 ammo=24")
  end
  s.started=game.tick;s.damaged=false
end
local function checkpoint(s,elapsed)
  local tp=storage.tech_priests
  local all_operating,all_repaired,all_consecrated=0,0,0
  for _,rank in ipairs(SPECS) do
    local r=s.ranks[rank.name]
    local pair=tp.pairs_by_station and tp.pairs_by_station[r.station_unit]
    if not (pair and pair.priest and pair.priest.valid) then
      fail("NO_LIVE_PRIEST_PAIR rank="..rank.name)
    end
    local produced,repaired,consecrated=0,0,0
    for _,m in ipairs(r.machines) do
      if not (m.entity and m.entity.valid) then
        fail("MACHINE_DISAPPEARED rank="..rank.name.." unit="..m.unit)
      end
      local recipe=m.entity.get_recipe()
      if not (recipe and recipe.name=="iron-gear-wheel") then
        fail("MACHINE_RECIPE_LOST rank="..rank.name)
      end
      produced=produced+inv(m.entity,defines.inventory.assembling_machine_output)
        .get_item_count("iron-gear-wheel")
      local ledger=get_consecration_record(m.entity)
      if not ledger then fail("MACHINE_SPIRIT_LOST rank="..rank.name) end
      local history=ledger.consecration_history_0422 or {}
      for _,event in ipairs(history) do
        if event.source=="priest-capsule-rite"
          or (event.source and event.source:find("tech-priest",1,true)) then
          consecrated=consecrated+1;break
        end
      end
      if m.damaged_health and m.entity.health>m.damaged_health then
        repaired=repaired+1
      end
    end
    emit("CHECKPOINT elapsed="..elapsed.." rank="..rank.name..
      " produced="..produced.." repaired="..repaired..
      " rites="..consecrated.." order="..
      tostring(pair.order_queue_0469 and pair.order_queue_0469.current
        and pair.order_queue_0469.current.kind).. " consecration="..
      tostring(pair.consecration_0515 and pair.consecration_0515.phase)..
      " repair="..tostring(pair.repair_0516 and pair.repair_0516.phase))
    if produced==0 then fail("ASSEMBLERS_NEVER_CRAFTED rank="..rank.name) end
    all_operating=all_operating+1
    if repaired>0 then all_repaired=all_repaired+1 end
    if consecrated>0 then all_consecrated=all_consecrated+1 end
  end
  if elapsed>=24000 then
    if all_consecrated~=4 then fail("CONSECRATION_NOT_SERVICED_ALL_RANKS "..all_consecrated.."/4") end
    if all_repaired~=4 then fail("REPAIR_NOT_SERVICED_ALL_RANKS "..all_repaired.."/4") end
    emit("PASS active machine consecration and repair from real stocked items ranks=4")
    s.finished=true
  end
end
local function pulse()
  local s=root()
  if s.finished or s.failed then return {processed=0} end
  local ok,err=pcall(function()
    if not s.started then fail("fixture did not initialize") end
    local elapsed=game.tick-s.started
    if elapsed>=900 and not s.damaged then
      for _,r in pairs(s.ranks) do
        for _,m in ipairs(r.machines) do
          if not m.entity.valid then fail("machine vanished before damage") end
          local prior=m.entity.health
          m.entity.damage(60,game.forces.neutral,"physical")
          m.damaged_health=m.entity.health
          if not (m.damaged_health<prior) then
            fail("ENGINE_DAMAGE_NOT_APPLIED unit="..m.unit)
          end
        end
      end
      s.damaged=true
      emit("PASS actual Factorio machine damage triggered across all four ranks")
    end
    for _,mark in ipairs({600,3600,12000,24000}) do
      if elapsed>=mark and not s["checked_"..mark] then
        checkpoint(s,mark)
        s["checked_"..mark]=true
      end
    end
  end)
  if not ok then s.failed=tostring(err);emit("FAIL "..s.failed) end
  return {processed=1,failed=s.failed and 1 or 0}
end
function M.install()
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if not (registry and registry.on_init and broker and broker.register_service) then
    error(PREFIX.."FAIL missing canonical lifecycle/broker")
  end
  assert(registry.on_init(setup,{owner="ci_consecration_maintenance",
    route="initialize",category="diagnostics",priority="last"}))
  assert(broker.register_service{name="ci_consecration_maintenance",
    category="diagnostics",interval=60,priority=1100,budget=1,fn=pulse,
    note="isolated four-rank running-assembler maintenance acceptance"})
  emit("INSTALLED test-only service")
  return true
end
return M
