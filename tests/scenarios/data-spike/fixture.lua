local R=TechPriestsRuntimeEventRegistry
local Picker=DATA_SPIKE_FULL_TEST and require("scripts.core.character_skin_picker")
local function check(ok,message)
  if not ok then storage.spike_test.failed=message;error("[TP-SPIKE] FAIL "..message) end
end
local function pending()
  local root=storage.tech_priests.conclave_center_0558
  return root and root.data_spike_pending_0591 or {}
end
local function claim(entity)
  for _,entry in pairs(pending()) do if entry.target==entity then return entry end end
end
local function launch(player,target)
  player.cursor_stack.set_stack{name="tech-priests-data-spike",count=1}
  player.update_selected_entity(target.position)
  local created=player.cursor_stack.use_capsule(player.character,target.position)
  log("[TP-SPIKE] USE source="..player.character.name.." unit="..player.character.unit_number.." target="..target.name)
  check(#created>0,"actual capsule creates projectile")
  check(not player.cursor_stack.valid_for_read,"actual capsule consumes one item")
  return created
end
local function setup(player)
  if storage.spike_test.started then return end
  local t=storage.spike_test;t.started=true;t.start=game.tick;t.player=player.index
  local surface=game.surfaces[1]
  surface.request_to_generate_chunks({0,0},1);surface.force_generate_chunk_requests()
  local tiles={};for x=-20,20 do for y=-20,20 do tiles[#tiles+1]={name="landfill",position={x,y}} end end;surface.set_tiles(tiles)
  for _,entity in pairs(surface.find_entities_filtered{area={{-20,-20},{20,20}}}) do if entity.type~="character" then entity.destroy() end end
  if not player.character then
    local body=surface.create_entity{name="character",position={0,0},force=player.force}
    player.set_controller{type=defines.controllers.character,character=body}
  end
  if Picker then Picker.restore_player(player) end
  player.teleport({0,0});player.character.destructible=false
  t.enemy=game.create_force("spike-defender")
  t.unresearched=surface.create_entity{name="steel-chest",position={3,0},force=t.enemy}
  launch(player,t.unresearched)
  log("[TP-SPIKE] START real engine projectile")
end
R.on_init(function()
  storage.tech_priests=storage.tech_priests or {pairs_by_station={},pairs_by_priest={}}
  storage.spike_test={stage=0}
end,{owner="spike-test",priority=10000})
R.on_event(defines.events.on_script_trigger_effect,function(event)
  if event.effect_id~="tech-priests-data-spike-impact" then return end
  local source=event.source_entity;local cause=event.cause_entity
  local p=game.get_player(storage.spike_test.player)
  log("[TP-SPIKE] IMPACT player_index="..tostring(event.source_player_index).." source="..tostring(source and source.name).." cause="..tostring(cause and cause.name).." current_character="..tostring(p and p.character and p.character.name).." current_unit="..tostring(p and p.character and p.character.unit_number))
  storage.spike_test.impacts=(storage.spike_test.impacts or 0)+1
end,nil,{owner="spike-test",route="impact",priority=1000})
R.on_event(defines.events.on_tick,function()
  local t=storage.spike_test
  if not t.started then local p=game.players[1];if p then setup(p) end;return end
  if t.done or t.failed then return end
  local p=game.get_player(t.player);local s=p.surface;local elapsed=game.tick-t.start
  if t.stage==0 and elapsed>=25 then
    check(t.impacts and t.impacts>=1,"projectile produced actual script trigger")
    check(not next(pending()),"unresearched player cannot capture")
    p.force.technologies["tech-priests-data-spike-reclamation-1"].researched=true
    check(p.force.recipes["tech-priests-data-spike"].enabled,"research unlocks actual recipe")
    t.station=s.create_entity{name="senior-cogitator-station",position={7,0},force=t.enemy,raise_built=DATA_SPIKE_FULL_TEST or false}
    if DATA_SPIKE_FULL_TEST then
      t.pair=storage.tech_priests.pairs_by_station[t.station.unit_number]
      check(t.pair and t.pair.priest and t.pair.priest.valid,"production station placement creates actual priest pair")
      t.priest=t.pair.priest
      check(ensure_pair_logistic_caches(t.pair),"production logistic support caches created")
      t.support={t.pair.logistic_requester,t.pair.logistic_return_cache}
      t.support_units={t.support[1].unit_number,t.support[2].unit_number}
      check(t.support[1].insert{name="tech-priests-data-spike",count=1}==1,"stock real support inventory")
    else
      t.priest=s.create_entity{name="small-biter",position={9,0},force=t.enemy}
      t.priest.commandable.set_command{type=defines.command.stop}
      t.pair={station=t.station,priest=t.priest,mode="idle"}
      storage.tech_priests.pairs_by_station[t.station.unit_number]=t.pair
      storage.tech_priests.pairs_by_priest[t.priest.unit_number]=t.pair
    end
    t.station.destructible=false;t.priest.destructible=false
    t.priest_unit=t.priest.unit_number;t.station_unit=t.station.unit_number
    t.pair.rogue_doctrine_0588=true;t.pair.rogue_original_force_0588=p.force.name
    launch(p,t.station)
    t.machine=s.create_entity{name="assembling-machine-1",position={0,6},force=t.enemy};launch(p,t.machine)
    t.removed=s.create_entity{name="steel-chest",position={-5,0},force=t.enemy};launch(p,t.removed)
    t.friendly=s.create_entity{name="steel-chest",position={0,-5},force=p.force};launch(p,t.friendly)
    t.ai=s.create_entity{name="steel-chest",position={-5,-5},force=t.enemy}
    s.create_entity{name="tech-priests-data-spike-projectile",position={-7,-5},target=t.ai,force=p.force,speed=0.65}
    t.ally=game.create_force("spike-ally");p.force.set_friend(t.ally,true)
    t.allied=s.create_entity{name="steel-chest",position={-10,-5},force=t.ally};launch(p,t.allied)
    t.neutral=s.create_entity{name="steel-chest",position={-10,0},force="neutral"};launch(p,t.neutral)
    t.close_enemy=s.create_entity{name="steel-chest",position={4,-6},force=t.enemy}
    t.close_friend=s.create_entity{name="steel-chest",position={3,-6},force=p.force};launch(p,t.close_friend)
    t.diplomatic_force=game.create_force("spike-diplomatic")
    t.diplomatic=s.create_entity{name="steel-chest",position={-10,5},force=t.diplomatic_force};launch(p,t.diplomatic)
    t.bulk={}
    for i=0,31 do
      local entity=s.create_entity{name="steel-chest",position={-18+(i%8)*4,10+math.floor(i/8)*3},force=t.enemy}
      check(entity,"create concurrent capture target")
      entity.destructible=false;t.bulk[#t.bulk+1]=entity;launch(p,entity)
    end
    t.stage=1
  elseif t.stage==1 and elapsed>=65 then
    check(claim(t.station),"player projectile schedules station capture")
    check(claim(t.machine),"player projectile schedules machine capture")
    for _,entity in ipairs({t.station,t.machine,t.removed}) do
      local c=claim(entity);check(c and c.ends_tick-c.started_tick==90*60,"tier-one countdown is 90 seconds")
    end
    check(not claim(t.friendly) and not claim(t.ai),"friendly and unowned projectiles rejected")
    check(not claim(t.allied) and not claim(t.neutral),"allied and neutral structures rejected")
    check(not claim(t.close_enemy) and not claim(t.close_friend),"friendly aim does not capture adjacent enemy")
    check(claim(t.diplomatic),"hostile diplomatic target initially accepted")
    p.force.set_cease_fire(t.diplomatic_force,true)
    for _,entity in ipairs(t.bulk) do check(claim(entity),"all 32 concurrent claims scheduled") end
    t.station_deadline=claim(t.station).ends_tick;t.machine_deadline=claim(t.machine).ends_tick
    t.removed.destroy{raise_destroy=true}
    t.enemy.technologies["tech-priests-data-spike-defense"].researched=true
    for level=2,4 do p.force.technologies["tech-priests-data-spike-reclamation-"..level].researched=true end
    t.fast=s.create_entity{name="steel-chest",position={5,6},force=t.enemy};launch(p,t.fast)
    -- Re-spiking replaces the existing timer with current research modifiers.
    launch(p,t.machine);t.stage=2
  elseif t.stage==2 and elapsed>=145 then
    check(t.enemy.technologies["tech-priests-data-spike-defense"].level==2,"one completed infinite defense level")
    local seconds=40 -- tier four: 30 seconds, plus one completed defense level
    for _,entity in ipairs({t.machine,t.fast}) do
      local c=claim(entity);check(c and c.ends_tick-c.started_tick==seconds*60,"reclamation and defense timing expected="..seconds.." actual="..tostring(c and (c.ends_tick-c.started_tick)/60).." defense_level="..t.enemy.technologies["tech-priests-data-spike-defense"].level.." researched="..tostring(t.enemy.technologies["tech-priests-data-spike-defense"].researched))
    end
    check(claim(t.machine).ends_tick<t.machine_deadline,"replacement claim uses new timer")
    t.fast_deadline=claim(t.fast).ends_tick;t.machine_deadline=claim(t.machine).ends_tick
    local count=0;for _ in pairs(pending()) do count=count+1 end
    check(not claim(t.diplomatic) and t.diplomatic.force==t.diplomatic_force,"ending hostilities cancels pending capture")
    check(count==35,"removed and nonhostile targets cleared; 35 live claims")
    t.stage=3;t.save_tick=game.tick
    log("[TP-SPIKE] PENDING timers="..count.." station_deadline="..t.station_deadline)
    game.auto_save("data-spike-pending")
  elseif t.stage==3 then
    if game.tick<t.station_deadline then check(t.station.force==t.enemy and t.priest.force==t.enemy,"station pair not captured early") end
    if game.tick<t.machine_deadline then check(t.machine.force==t.enemy,"machine not captured early") end
    if game.tick<t.fast_deadline then check(t.fast.force==t.enemy,"improved claim not captured early") end
    if game.tick>=t.fast_deadline+60 then check(t.fast.force==p.force,"short claim serviced on time with more than 24 active claims") end
    if game.tick>=t.station_deadline+60 then
      check(t.station.force==p.force and t.priest.force==p.force,"station and priest captured together")
      check(t.machine.force==p.force and t.fast.force==p.force,"ordinary structures captured")
      check(t.ai.force==t.enemy and t.unresearched.force==t.enemy,"rejected targets unchanged")
      for _,entity in ipairs(t.bulk) do check(entity.force==p.force,"all concurrent captures completed") end
      check(not t.pair.rogue_doctrine_0588,"pair allegiance reset")
      check(t.priest.unit_number==t.priest_unit and t.station.unit_number==t.station_unit,"capture preserves original entity identity")
      if t.support then
        check(t.pair.force==p.force.name,"pair's recorded force updated")
        local stock=t.station.get_item_count("tech-priests-data-spike")
        for i,entity in ipairs(t.support) do
          check(entity.valid and entity.unit_number==t.support_units[i] and entity.force==p.force,"support custody transfers without replacing entities")
          stock=stock+entity.get_item_count("tech-priests-data-spike")
        end
        check(stock==1,"physical support inventory conserved")
      end
      check(next(pending())==nil,"finished claims cleaned up")
      t.done=true
      helpers.write_file("data-spike/result.json",helpers.table_to_json{passed=true,full_mod=DATA_SPIKE_FULL_TEST or false,actual_capsule=true,concurrent_claims=35,impacts=t.impacts,save_tick=t.save_tick,finish_tick=game.tick},false)
      log("[TP-SPIKE] PASS native projectile, research, timers, save/reload, pair/machine capture, removal, replacement")
    end
  end
end,nil,{owner="spike-test",route="assertions",priority=2000})
