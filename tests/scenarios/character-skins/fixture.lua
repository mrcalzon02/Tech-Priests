local Registry=require("scripts.core.runtime_event_registry")
local Broker=require("scripts.core.runtime_tick_broker")
local Picker=require("scripts.core.character_skin_picker")
local Visuals=require("scripts.core.character_visuals")
local Engineer=require("scripts.core.engineer_visuals")
local Catalog=require("shared.character_skin_catalog")
local PriestMovement=require("priest-movement")
local mod_gui=require("mod-gui")
local session_completed=false
local graphical_run=false -- runner enables this only for screenshot capture
local legacy_case=false -- runner initializes the previously shipped character host
local function check(ok,message)
  if ok then return end
  storage.skin_test.failed=message
  helpers.write_file("character-skins/result.json",helpers.table_to_json{passed=false,error=message,tick=game.tick},false)
  error("[TP-SKINS-TEST] FAIL "..message)
end
local function close(a,b) return math.abs(a-b)<0.0001 end
local function start_mech_test(player)
  local t=storage.skin_test
  if not prototypes.item["mech-armor"] then
    t.mech={done=true,result={skipped="Space Age Mech armor unavailable"}}
    return
  end
  local surface=player.surface
  local tiles={}
  for x=-8,4 do for y=22,30 do tiles[#tiles+1]={name="water",position={x,y}} end end
  surface.set_tiles(tiles)
  local actor=surface.create_entity{name="character",position={-20,24},force=player.force,raise_built=true}
  local reference=surface.create_entity{name="tp-skin-reference-character",position={-20,28},force=player.force}
  check(actor and reference,"native Mech appearance and reference actors created")
  for _,entity in ipairs({actor,reference}) do
    entity.get_inventory(defines.inventory.character_armor)[1].set_stack{name="mech-armor",count=1}
    entity.destructible=false
    check(entity.get_inventory(defines.inventory.character_guns).is_empty(),"Mech pose test is genuinely unarmed")
  end
  local source=Engineer.catalog()
  local variant=source.armor_to_variant["mech-armor"]
  check(variant and source.variants[variant].states.running_with_gun.directions==40,"native Mech ground bank has forty directions")
  check(source.variants[variant].states.idle_with_gun_in_air.directions==8,"native Mech air bank has eight directions")
  t.mech={entity=actor,reference=reference,unit=actor.unit_number,variant=variant,start=game.tick,
    result={armor="mech-armor",overlay=Engineer.needed(actor),ground=nil,flight_samples={}}}
end
local function mech_pose(mech,state,directions)
  local entity=mech.entity
  local rec=storage.tech_priests.character_visuals.actors[entity.unit_number]
  if mech.result.overlay then
    check(rec and rec.model=="vanilla" and rec.engineer_variant==mech.variant,"Mech uses its own Engineer armor variant")
    check(rec.state==state,"native Mech pose selects "..state..", received "..tostring(rec.state))
    if state=="running_with_gun" then
      -- The independent native 40-row oracle resolves east aim + east walk
      -- to zero-based row 10, with neither reflection nor reverse playback.
      check(rec.row==10 and rec.mirrored==false and rec.reversed==false,"unarmed Mech uses the native aim-equals-walk row")
    end
    local clip=Engineer.catalog().variants[mech.variant].states[state]
    check(clip.directions==directions,"Mech selected native direction bank")
    local render=rendering.get_object_by_id(rec.renders[1])
    check(render and render.valid and render.animation==clip.layers[1].animations[rec.row%clip.layers[1].directions+1],"Mech native animation renders selected pose row")
  end
  return {tick=game.tick-mech.start,x=entity.position.x,height=entity.flight_height,
    reference_height=mech.reference.flight_height,is_flying=entity.is_flying,
    variant=mech.variant,state=mech.result.overlay and rec.state or "native-visible",row=rec and rec.row,
    mirrored=rec and rec.mirrored,reversed=rec and rec.reversed,directions=directions}
end
local function tick_mech_test(player)
  local mech=storage.skin_test.mech
  if not mech or mech.done then return end
  local actor,reference=mech.entity,mech.reference
  check(actor.valid and reference.valid and actor.unit_number==mech.unit,"Mech keeps its real native body")
  check(close(actor.position.x,reference.position.x) and close(actor.flight_height,reference.flight_height)
    and actor.is_flying==reference.is_flying,"Mech overlay follows native movement and flight without changing either")
  local elapsed=game.tick-mech.start
  local function screenshot(name)
    if graphical_run then
      game.take_screenshot{player=player,surface=actor.surface,
        position={x=actor.position.x,y=(actor.position.y+reference.position.y)/2},resolution={1200,1000},zoom=4,
        path="character-skins/mech-"..name..".png",show_gui=false,daytime=0,force_render=true}
    end
  end
  if elapsed>=30 and not mech.result.ground then
    check(not actor.is_flying and actor.position.x>-18,"unarmed Mech physically walks on land before native takeoff")
    mech.result.ground=mech_pose(mech,"running_with_gun",40)
    screenshot("walking")
  end
  -- Both rising and falling hover bob occur over this water span after the
  -- real takeoff animation finishes. Height delta alone is not a flight phase.
  if actor.position.x>=-2.5 and actor.position.x<=4 and game.tick%5==0 then
    check(actor.is_flying and actor.flight_height>=1,"native armor actually flies over impassable water")
    local samples=mech.result.flight_samples
    if #samples>0 then
      if actor.flight_height>samples[#samples].height then mech.result.hover_rose=true end
      if actor.flight_height<samples[#samples].height then mech.result.hover_fell=true end
    end
    samples[#samples+1]=mech_pose(mech,"idle_with_gun_in_air",8)
    if actor.position.x>=0 and not mech.captured_flight then screenshot("flying");mech.captured_flight=true end
  end
  local moving=actor.position.x<18
  for _,entity in ipairs({actor,reference}) do entity.walking_state={walking=moving,direction=defines.direction.east} end
  if not moving then
    check(not actor.is_flying and actor.flight_height==0,"Mech lands through native armor behavior")
    check(mech.result.ground and #mech.result.flight_samples>=6 and mech.captured_flight,"Mech ground and sustained flight poses observed")
    check(mech.result.hover_rose and mech.result.hover_fell,"native hover bob rose and fell without selecting takeoff or landing")
    mech.result.passed=true;mech.result.distance=actor.position.x+20;mech.result.ticks=elapsed
    mech.done=true
    log("[TP-SKINS-TEST] MECH_PASS native ground walk, water-triggered flight, hover pose and landing; samples="..#mech.result.flight_samples)
  end
  check(elapsed<320 or mech.done,"native Mech water crossing completed within its observed travel time")
end
local function initialize()
  storage.skin_test={start=nil,stage=0,npcs={},broker_service_count=Broker.service_count()}
  local surface=game.surfaces[1]
  surface.daytime=0;surface.freeze_daytime=true
  surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
  for _,entity in pairs(surface.find_entities_filtered{area={{-30,-30},{30,30}},type={"tree","simple-entity","cliff","resource"}}) do entity.destroy() end
  local tiles={}
  for x=-30,30 do for y=-30,30 do tiles[#tiles+1]={name="landfill",position={x,y}} end end
  surface.set_tiles(tiles)
  local red=game.forces["skin-test-red"] or game.create_force("skin-test-red")
  local blue=game.forces["skin-test-blue"] or game.create_force("skin-test-blue")
  red.custom_color={r=.8,g=.12,b=.06,a=1};blue.custom_color={r=.08,g=.28,b=.9,a=1}
  for _,force in ipairs({red,blue}) do force.set_cease_fire(game.forces.player,true);game.forces.player.set_cease_fire(force,true) end
  red.set_cease_fire(blue,true);blue.set_cease_fire(red,true)
  storage.tech_priests=storage.tech_priests or {}
  local tp=storage.tech_priests
  tp.pairs_by_station={};tp.pairs_by_priest={}
  local n=0
  for _,rank in ipairs({"junior","intermediate","senior","planetary-magos","void"}) do
    local model=Catalog.ranks[rank]
    if prototypes.entity[rank.."-tech-priest"] then
    for _,force in ipairs({red,blue}) do
      n=n+1
      local position={x=-12+math.ceil(n/2)*4,y=6+((n-1)%2)*6}
      local station=surface.create_entity{name="steel-chest",position={position.x,position.y+3},force=force}
      local priest=surface.create_entity{name=rank.."-tech-priest",position=position,force=force}
      check(priest and station,"native ranked entities created")
      priest.commandable.set_command{type=defines.command.stop}
      local pair={station=station,priest=priest,station_unit=station.unit_number,mode="idle"}
      tp.pairs_by_station[station.unit_number]=pair;tp.pairs_by_priest[priest.unit_number]=pair
      storage.skin_test.npcs[#storage.skin_test.npcs+1]={entity=priest,model=model,unit=priest.unit_number,health=priest.health}
    end
    end
  end
  log("[TP-SKINS-TEST] INITIALIZED native_units="..#storage.skin_test.npcs)
end
local function setup_player(player)
  local t=storage.skin_test
  if t.start then return end
  -- Freeplay creates its crash site after on_init. Remove just those fixtures
  -- so unrelated wreck smoke cannot contaminate the player appearance proof.
  for _,entity in pairs(player.surface.find_entities_filtered{area={{-30,-30},{30,30}}}) do
    if entity.valid and entity.name:find("^crash%-site%-") then entity.destroy() end
  end
  if not (player.character and player.character.valid) then
    local body=player.surface.create_entity{name="character",position={0,-8},force=player.force}
    check(body and body.valid,"native test character created")
    player.set_controller{type=defines.controllers.character,character=body}
  end
  check(player.character and player.character.valid,"real native player controls character")
  if legacy_case then
    local previous=player.character
    local legacy=player.surface.create_entity{name=Visuals.host_name,position=player.position,force=player.force}
    check(legacy and legacy.valid,"existing-save character host created")
    player.character=legacy
    previous.destroy() -- isolated fixture setup, never a picker action
  end
  t.player=player.index;t.start=game.tick
  PriestMovement.start()
  player.teleport({0,-8})
  player.clear_items_inside()
  local character=player.character
  -- Exercise the same lifecycle route used by first joins and old-save upgrades.
  local picker_state=storage.tech_priests.character_skin_picker
  picker_state.selected[player.index]=nil;picker_state.pending[player.index]=nil
  -- Exercise the public entry point shared with the registered lifecycle route.
  Picker.restore_player(player)
  check(Picker.selected(player)==Picker.default_skin(),"first-use startup appearance applies")
  if Picker.enabled() then
    check(player.character==character and character.name==(legacy_case and Visuals.host_name or "character"),"startup keeps original native character")
    check(Picker.choose(player,"vanilla"),"explicit engineer selection")
    Picker.restore_player(player)
    check(Picker.selected(player)=="vanilla" and player.character==character,"explicit engineer survives lifecycle restore")
  end
  character=player.character
  character.health=177
  character.character_running_speed_modifier=.17
  character.character_inventory_slots_bonus=5
  character.get_inventory(defines.inventory.character_armor)[1].set_stack{name="power-armor",count=1}
  local armor=character.get_inventory(defines.inventory.character_armor)[1]
  local battery=armor.grid.put{name="battery-equipment",position={0,0}}
  battery.energy=12345
  local main=character.get_main_inventory()
  main[1].set_stack{name="iron-plate",count=37}
  main[2].set_stack{name="copper-plate",count=19}
  main[3].set_stack{name="blueprint",count=1}
  main[3].set_blueprint_entities{{entity_number=1,name="stone-furnace",position={0,0}}}
  main[#main].set_stack{name="steel-plate",count=11}
  character.get_inventory(defines.inventory.character_guns)[1].set_stack{name="pistol",count=1}
  character.get_inventory(defines.inventory.character_ammo)[1].set_stack{name="firearm-magazine",count=7}
  character.get_inventory(defines.inventory.character_ammo)[1].ammo=3
  player.cursor_stack.set_stack{name="copper-cable",count=13}
  t.original_character=character
  t.original_unit=character.unit_number
  t.main_inventory=main
  t.armor_inventory=character.get_inventory(defines.inventory.character_armor)
  t.armor_grid=armor.grid
  t.main_size=#main
  t.logistic_sections=character.get_logistic_sections()
  t.character_name=character.name
  t.reference=player.surface.create_entity{name="tp-skin-reference-character",position={-20,-24},force=player.force}
  check(t.reference and t.reference.valid,"unmodified native reference character created")
  t.reference.character_running_speed_modifier=.17
  t.reference.get_inventory(defines.inventory.character_armor)[1].set_stack{name="power-armor",count=1}
  check(close(character.prototype.running_speed,t.reference.prototype.running_speed),"native prototype running speed is unchanged")
  check(character.prototype.character_corpse==t.reference.prototype.character_corpse,"player and legacy host retain the standard visible native corpse")
  start_mech_test(player)
  if not Picker.enabled() then
    check(not player.gui.screen[Picker.button_name],"disabled picker has no button")
    local ok,reason=Picker.choose(player,"enginseer")
    check(not ok and reason=="restricted","disabled picker rejects direct request")
    t.disabled=true
    return
  end
  local button=player.gui.screen[Picker.button_name]
  check(button.valid,"right-side picker button exists")
  check(not mod_gui.get_button_flow(player)[Picker.button_name],"old upper-left button removed")
  check(button.location.x>player.display_resolution.width/2,"picker button on right")
  script.get_event_handler(Picker.input_name)({name=Picker.input_name,player_index=player.index,tick=game.tick})
  check(player.gui.screen[Picker.frame_name] and player.opened==player.gui.screen[Picker.frame_name],"custom input opens picker")
  Picker.close(player)
  script.get_event_handler(defines.events.on_gui_click)({name=defines.events.on_gui_click,player_index=player.index,element=button,button=defines.mouse_button_type.left,tick=game.tick})
  check(player.gui.screen[Picker.frame_name] and player.opened==player.gui.screen[Picker.frame_name],"right button opens picker")
  Picker.close(player)
  check(Picker.open(player),"native picker frame opens")
  check(player.gui.screen[Picker.frame_name].valid,"native GUI frame exists")
  local ok,reason=Picker.choose(player,"enginseer")
  check(ok and reason=="applied","first appearance selection applies: "..tostring(reason))
  check(player.character==character and character.valid,"appearance retains original native character")
  check(close(player.character.health,177),"appearance leaves current health untouched")
end
local function inventory_checks(player)
  local c=player.character
  local t=storage.skin_test
  check(c==t.original_character and c.unit_number==t.original_unit and c.name==t.character_name,"original character identity and prototype retained")
  local main=c.get_main_inventory()
  check(main==t.main_inventory and c.get_inventory(defines.inventory.character_armor)==t.armor_inventory and t.armor_inventory[1].grid==t.armor_grid,"inventory and equipment objects retained")
  check(c.get_logistic_sections()==t.logistic_sections,"native logistic sections retained")
  check(#main==storage.skin_test.main_size,"inventory capacity preserved")
  check(main.get_item_count("iron-plate")==37,"main stack count preserved")
  check(main.get_item_count("steel-plate")==11,"last bonus slot item preserved")
  local blueprint=main.find_item_stack("blueprint")
  check(blueprint and blueprint.is_blueprint and #blueprint.get_blueprint_entities()==1,"blueprint entity data preserved")
  check(c.get_inventory(defines.inventory.character_ammo)[1].count==7 and c.get_inventory(defines.inventory.character_ammo)[1].ammo==3,"ammo count and partial magazine preserved")
  local armor=c.get_inventory(defines.inventory.character_armor)[1]
  check(armor.name=="power-armor" and close(armor.grid.get{0,0}.energy,12345),"armour grid and battery energy preserved")
  check(player.cursor_stack.name=="copper-cable" and player.cursor_stack.count==13,"cursor item preserved")
  check(c.health>=177 and close(c.character_running_speed_modifier,.17),"health regeneration and modifiers preserved")
end
local function tick(event)
  if storage.skin_test and storage.skin_test.done then
    local t=storage.skin_test
    if graphical_run and session_completed and not t.capture_done and game.tick>=t.capture_tick then
      t.capture_done=true
      local player=game.get_player(t.player)
      game.take_screenshot{player=player,surface=player.surface,position={0,9},resolution={1920,1080},zoom=2,
        path="character-skins/native-ranks.png",show_gui=false,daytime=0,force_render=true}
      game.take_screenshot{player=player,resolution={1920,1080},zoom=2,
        path="character-skins/native-picker.png",show_gui=true,daytime=0,force_render=true}
    end
    if not session_completed then
      local t=storage.skin_test
      local player=game.get_player(t.player)
      check(player.character.unit_number==t.saved_unit,"physical character identity survives separate-process reload")
      check(Broker.service_count()==t.broker_service_count,"broker service count survives separate-process reload")
      local found=0
      for _,service in ipairs(Broker.services) do if service.name=="character_visuals_presentation" then found=found+1 end end
      check(found==1,"exactly one named presentation service survives reload")
      inventory_checks(player)
      if not t.disabled then
        check(Picker.selected(player)=="enginseer","selected appearance survives reload")
        local rec=storage.tech_priests.character_visuals.actors[t.saved_unit]
        check(rec and rendering.get_object_by_id(rec.renders.mask).valid,"mask rendering survives reload")
      end
      log("[TP-SKINS-TEST] RELOAD_PASS character, selection, items and render objects")
      session_completed=true
    end
    return
  end
  local t=storage.skin_test
  if not t or t.failed or t.done then return end
  if not t.start then
    local player=game.get_player(1)
    if player then setup_player(player) end
    return
  end
  local elapsed=event.tick-t.start
  local player=game.get_player(t.player)
  PriestMovement.tick(event,player,graphical_run)
  tick_mech_test(player)
  if elapsed>=10 and t.stage==0 then
    local detached=player.surface.create_entity{name="character",position={-25,-6},force=player.force,raise_built=true}
    check(detached and detached.valid,"detached native body created")
    local clone=detached.clone{position={-25,-3},create_build_effect_smoke=false}
    check(clone and clone.valid,"native body cloned")
    if Picker.enabled() then
      for _,body in ipairs({detached,clone}) do
        local rec=storage.tech_priests.character_visuals.actors[body.unit_number]
        check(rec and rec.model=="vanilla" and next(rec.renders)~=nil,"raised-build and clone lifecycle preserve visible detached Engineers")
      end
    end
    t.lifecycle_checked=true
    local death_probe=player.surface.create_entity{name=Visuals.host_name,position={-25,0},force=player.force}
    check(death_probe and death_probe.valid,"legacy death probe created")
    death_probe.get_main_inventory()[1].set_stack{name="copper-plate",count=9}
    check(death_probe.die(game.forces.enemy),"native legacy-host death occurred")
    local corpse=player.surface.find_entities_filtered{name="character-corpse",position={-25,0},radius=1}[1]
    check(corpse and corpse.valid,"legacy host leaves the unchanged visible Engineer corpse")
    check(corpse.get_inventory(defines.inventory.character_corpse).get_item_count("copper-plate")==9,"legacy corpse preserves recoverable inventory")
    t.legacy_corpse_checked=true
    for _,npc in ipairs(t.npcs) do
      local rec=storage.tech_priests.character_visuals.actors[npc.unit]
      check(rec and rec.model==npc.model,"rank model mapping")
      check(npc.entity.unit_number==npc.unit and npc.entity.health==npc.health,"native priest identity and health unchanged")
      local mask=rendering.get_object_by_id(rec.renders.mask)
      local body=rendering.get_object_by_id(rec.renders.base)
      check(mask and mask.valid and body and body.valid,"three native render layers exist")
      check(close(mask.color.r,npc.entity.force.color.r) and close(mask.color.g,npc.entity.force.color.g),"native force colour reaches mask")
      check(close(body.color.r,1) and close(body.color.g,1),"unmasked body remains white-tinted")
    end
    if not t.disabled then
      inventory_checks(player)
      local unit=player.character.unit_number
      local speed=player.character_running_speed
      for _,skin in ipairs(Catalog.skins) do
        local ok,reason=Picker.choose(player,skin.id)
        if Catalog.allowed(skin.id,settings.startup) then
          check(ok and reason=="applied","available skin selects: "..skin.id)
          check(Picker.selected(player)==skin.id,"selection stored")
          check(player.character.unit_number==unit,"skin change retains physical character")
          check(close(player.character_running_speed,speed),"effective movement speed unchanged: "..skin.id)
          inventory_checks(player)
        else check(not ok and reason=="restricted","startup-restricted skin rejected") end
      end
      inventory_checks(player)
      local before_health=player.character.health
      local before_attack=player.character.tick_of_last_attack
      player.character.tick_of_last_attack=game.tick
      local ok,reason=Picker.choose(player,"vanilla")
      check(ok and reason=="applied" and player.character.tick_of_last_attack==game.tick,"Engineer restores immediately in combat without changing attack state")
      check(close(player.character.health,before_health),"Engineer selection leaves current health untouched")
      player.character.tick_of_last_attack=before_attack
      check(player.begin_crafting{count=1,recipe="iron-gear-wheel",silent=true}==1,"native crafting queue started")
      player.crafting_queue_progress=.25
      local queue=helpers.table_to_json(player.crafting_queue)
      local progress=player.crafting_queue_progress
      check(Picker.choose(player,"enginseer"),"appearance changes while crafting")
      ok,reason=Picker.choose(player,"vanilla")
      check(ok and reason=="applied","Engineer restores immediately while crafting")
      check(helpers.table_to_json(player.crafting_queue)==queue and player.crafting_queue_progress==progress,"crafting queue and progress unchanged")
      player.cancel_crafting{index=1,count=1}
      inventory_checks(player)
      check(Picker.choose(player,"enginseer"),"custom appearance before vehicle restoration")
      local car=player.surface.create_entity{name="car",position=player.position,force=player.force}
      check(car and car.valid,"native vehicle created")
      car.set_driver(player)
      check(player.driving,"native vehicle entered")
      local before=player.character.unit_number
      local ok,reason=Picker.choose(player,"vanilla")
      check(ok and reason=="applied" and player.character.unit_number==before,"Engineer restores immediately while driving without replacing character")
      check(not storage.tech_priests.character_skin_picker.pending[player.index],"cosmetic selection has no deferred transfer")
      car.set_driver(nil)
      car.destroy()
      check(player.character==t.original_character and Picker.selected(player)=="vanilla","Engineer restored on original character")
      inventory_checks(player)
    end
    game.forces["skin-test-red"].custom_color={r=.2,g=.8,b=.3,a=1}
    t.stage=1
  end
  if elapsed>=25 and t.stage==1 then
    for _,npc in ipairs(t.npcs) do
      local rec=storage.tech_priests.character_visuals.actors[npc.unit]
      local tint=rendering.get_object_by_id(rec.renders.mask).color
      check(close(tint.r,npc.entity.force.color.r) and close(tint.g,npc.entity.force.color.g),"force colour change propagates")
    end
    if t.npcs[1] then
      t.dead_model=t.npcs[1].model
      check(t.npcs[1].entity.die(game.forces.enemy),"native ranked death")
    end
    t.stage=2
  end
  if elapsed>=40 and t.stage==2 then
    if t.dead_model then
      local found=false
      for _,rec in pairs(storage.tech_priests.character_visuals.actors) do
        if rec.dead and rec.model==t.dead_model then
          check(rec.state=="death" and rendering.get_object_by_id(rec.renders.mask).valid,"native corpse animation and mask")
          found=true
        end
      end
      check(found,"ranked corpse presentation attached after native death")
    end
    Picker.close(player)
    t.walk_skins={"vanilla"}
    if not t.disabled then
      for _,skin in ipairs(Catalog.skins) do if Picker.allowed(skin.id) then t.walk_skins[#t.walk_skins+1]=skin.id end end
    end
    t.walk_index=0;t.movement={};t.stage=3
  end
  if t.stage==3 then
    if t.walk_started and game.tick-t.walk_started>=60 then
      local tested=player.position.x-t.walk_start.x
      local reference=t.reference.position.x-t.reference_start.x
      player.walking_state={walking=false,direction=defines.direction.east}
      t.reference.walking_state={walking=false,direction=defines.direction.east}
      check(reference>1,"native reference physically walked")
      check(math.abs(tested-reference)<=1/256,"actual walking distance matches native Engineer for "..t.walk_skin..": "..tested.." vs "..reference)
      check(close(player.character_running_speed,t.reference.character_running_speed),"effective native movement speed matches for "..t.walk_skin)
      inventory_checks(player)
      t.movement[#t.movement+1]={skin=t.walk_skin,ticks=60,distance=tested,reference_distance=reference,
        effective_speed=player.character_running_speed,reference_speed=t.reference.character_running_speed}
      log("[TP-SKINS-TEST] WALK skin="..t.walk_skin.." ticks=60 distance="..tested.." native="..reference.." unit="..player.character.unit_number)
      t.walk_started=nil
    end
    if not t.walk_started then
      t.walk_index=t.walk_index+1
      if t.walk_index>#t.walk_skins then
        if not t.disabled then check(Picker.choose(player,"enginseer"),"select persistent appearance") end
        player.teleport({0,-8});t.reference.teleport({8,-8})
        t.stage=4
      else
        t.walk_skin=t.walk_skins[t.walk_index]
        local ok,reason=Picker.choose(player,t.walk_skin)
        check(ok and reason=="applied","walking appearance applies immediately: "..t.walk_skin)
        player.teleport({-20,-18});t.reference.teleport({-20,-24})
        player.character.tick_of_last_attack=t.reference.tick_of_last_attack
        player.character.tick_of_last_damage=t.reference.tick_of_last_damage
        t.walk_start={x=player.position.x,y=player.position.y}
        t.reference_start={x=t.reference.position.x,y=t.reference.position.y}
        t.walk_started=game.tick
        player.walking_state={walking=true,direction=defines.direction.east}
        t.reference.walking_state={walking=true,direction=defines.direction.east}
      end
    end
    if t.walk_started then
      -- The native --test-save test player refreshes input each tick.
      player.walking_state={walking=true,direction=defines.direction.east}
      t.reference.walking_state={walking=true,direction=defines.direction.east}
    end
    if graphical_run and t.walk_started and game.tick-t.walk_started==30
      and (t.walk_skin=="vanilla" or t.walk_skin=="enginseer") then
      game.take_screenshot{player=player,surface=player.surface,
        position={x=player.position.x,y=-21},resolution={1600,1000},zoom=3,show_gui=false,daytime=0,force_render=true,
        path="character-skins/"..(t.walk_skin=="vanilla" and "engineer" or t.walk_skin).."-walking.png"}
    end
  end
  if t.stage==4 and PriestMovement.done() and t.mech.done then
    t.saved_unit=game.get_player(t.player).character.unit_number
    t.done=true;session_completed=true
    helpers.write_file("character-skins/result.json",helpers.table_to_json{passed=true,skins=15,ranks=#t.npcs/2,forces=2,
      player=t.player,original_unit=t.original_unit,saved_unit=t.saved_unit,character_name=player.character.name,movement=t.movement,priest_movement=PriestMovement.results(),mech=t.mech.result,lifecycle=t.lifecycle_checked,legacy_corpse_inventory=t.legacy_corpse_checked,disabled=t.disabled or false,case=legacy_case and "legacy" or t.disabled and "disabled" or settings.startup["tech-priests-skin-allow-canoness"].value and "default" or "restricted"},false)
    log("[TP-SKINS-TEST] PASS same native character, actual movement parity, immediate Engineer restore, inventory/crafting preservation, restrictions and ranked force colours")
    local player=game.get_player(t.player)
    if not t.disabled then Picker.open(player) end
    local frame=player.gui.screen[Picker.frame_name]
    if frame then frame.auto_center=false;frame.location={80,80} end
    t.capture_tick=game.tick+15
    game.auto_save("character-skins")
  end
end
Registry.on_configuration_changed(function()
  local t=storage.skin_test
  if t then
    check(Broker.service_count()==t.broker_service_count,"configuration preserves broker service count")
    log("[TP-SKIN-BROKER] CONFIG_PASS stable service count="..Broker.service_count())
  end
end,{owner="character-skin-native-test",route="broker-configuration",priority=2000})
Registry.on_init(initialize,{owner="character-skin-native-test",route="fixture",priority=1000})
Registry.on_event(defines.events.on_tick,tick,nil,{owner="character-skin-native-test",route="native-assertions",priority=2000})
return true
