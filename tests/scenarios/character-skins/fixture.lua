local Registry=require("scripts.core.runtime_event_registry")
local Picker=require("scripts.core.character_skin_picker")
local Visuals=require("scripts.core.character_visuals")
local Catalog=require("shared.character_skin_catalog")
local mod_gui=require("mod-gui")
local session_completed=false
local graphical_run=false -- runner enables this only for screenshot capture
local function check(ok,message)
  if ok then return end
  storage.skin_test.failed=message
  helpers.write_file("character-skins/result.json",helpers.table_to_json{passed=false,error=message,tick=game.tick},false)
  error("[TP-SKINS-TEST] FAIL "..message)
end
local function close(a,b) return math.abs(a-b)<0.0001 end
local function initialize()
  storage.skin_test={start=nil,stage=0,npcs={}}
  local surface=game.surfaces[1]
  surface.daytime=0;surface.freeze_daytime=true
  surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
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
  log("[TP-SKINS-TEST] INITIALIZED ranks=5 native_units=10")
end
local function setup_player(player)
  local t=storage.skin_test
  if t.start then return end
  if not (player.character and player.character.valid) then
    local body=player.surface.create_entity{name="character",position={0,-8},force=player.force}
    check(body and body.valid,"native test character created")
    player.set_controller{type=defines.controllers.character,character=body}
  end
  check(player.character and player.character.valid,"real native player controls character")
  t.player=player.index;t.start=game.tick
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
    check(player.character.name==Visuals.host_name,"startup uses custom character host")
    check(Picker.choose(player,"vanilla"),"explicit engineer selection")
    Picker.restore_player(player)
    check(Picker.selected(player)=="vanilla" and player.character.name=="character","explicit engineer survives lifecycle restore")
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
  t.original_unit=character.unit_number
  t.main_size=#main
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
  check(player.character.name==Visuals.host_name,"native appearance host controlled")
  check(close(player.character.health,177),"health preserved at transfer commit")
  check(not character.valid,"old empty body retired")
end
local function inventory_checks(player)
  local c=player.character
  local main=c.get_main_inventory()
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
  if elapsed>=10 and t.stage==0 then
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
      for _,skin in ipairs(Catalog.skins) do
        local ok,reason=Picker.choose(player,skin.id)
        if Catalog.allowed(skin.id,settings.startup) then
          check(ok and reason=="applied","available skin selects: "..skin.id)
          check(Picker.selected(player)==skin.id,"selection stored")
          check(player.character.unit_number==unit,"skin change retains physical character")
        else check(not ok and reason=="restricted","startup-restricted skin rejected") end
      end
      inventory_checks(player)
      local car=player.surface.create_entity{name="car",position=player.position,force=player.force}
      check(car and car.valid,"native vehicle created")
      car.set_driver(player)
      check(player.driving,"native vehicle entered")
      local before=player.character.unit_number
      local ok,reason=Picker.choose(player,"vanilla")
      check(ok and reason=="queued" and player.character.unit_number==before,"body transfer deferred while driving")
      car.set_driver(nil)
      local applied,blocked=Picker.try_pending(player)
      check(applied,"queued appearance applies after leaving vehicle: "..tostring(blocked))
      car.destroy()
      check(player.character.name=="character","native original character restored")
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
    if not t.disabled then
      check(Picker.choose(player,"enginseer"),"select persistent appearance")
      if graphical_run then t.stage=4
      else
        player.teleport({20,-20})
        player.walking_state={walking=true,direction=0}
        t.pose_row=0;t.next_pose=elapsed+5;t.stage=3
      end
    else t.stage=4 end
  end
  if t.stage==3 and elapsed>=t.next_pose then
    Visuals.refresh_player(player,"enginseer")
    local rec=storage.tech_priests.character_visuals.actors[player.character.unit_number]
    check(rec.state=="walk" and rec.row==t.pose_row,"native walking row="..t.pose_row.." actual="..rec.row.." state="..rec.state)
    t.pose_row=t.pose_row+1;t.next_pose=elapsed+5
    if t.pose_row==8 then
      player.walking_state={walking=false,direction=0};t.stage=4
    else player.walking_state={walking=true,direction=t.pose_row*2} end
  end
  if t.stage==4 then
    t.saved_unit=game.get_player(t.player).character.unit_number
    t.done=true;session_completed=true
    helpers.write_file("character-skins/result.json",helpers.table_to_json{passed=true,skins=15,ranks=5,forces=2,
      player=t.player,disabled=t.disabled or false,case=settings.startup["tech-priests-skin-allow-canoness"].value and "default" or "restricted"},false)
    log("[TP-SKINS-TEST] PASS player picker, inventory preservation, restrictions and ranked force colours")
    local player=game.get_player(t.player)
    if not t.disabled then Picker.open(player) end
    local frame=player.gui.screen[Picker.frame_name]
    if frame then frame.auto_center=false;frame.location={80,80} end
    t.capture_tick=game.tick+15
    game.auto_save("character-skins")
  end
end
Registry.on_init(initialize,{owner="character-skin-native-test",route="fixture",priority=1000})
Registry.on_event(defines.events.on_tick,tick,nil,{owner="character-skin-native-test",route="native-assertions",priority=2000})
return true
