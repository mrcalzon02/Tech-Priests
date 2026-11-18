-- Native timing-authority proof. No fixtures or engine globals are simulated.
local Registry=require("scripts.core.runtime_event_registry")
local Broker=require("scripts.core.runtime_tick_broker")
local Economy=require("scripts.core.efficiency_economy_0595")
local Picker=require("scripts.core.character_skin_picker")
local Visuals=require("scripts.core.character_visuals")
local function check(ok,message) if not ok then error("[TP-SKIN-BROKER] FAIL "..message) end end
local function state() return storage.skin_broker_test end
Broker.register_service{name="native_skin_broker_background",category="runtime",interval=5,budget=1,dynamic_budget=false,
 fn=function()local t=state();t.background=t.background+1;return true end}
Registry.on_nth_tick(5,function()state().registry5=state().registry5+1 end,
 {owner="native_skin_broker_registry5",route="must-stay-dormant",category="runtime"})
Registry.on_init(function()
 storage.skin_broker_test={background=0,registry5=0,raw5=0,stage=0}
end,{owner="native_skin_broker_test",route="initialize",priority=2000})
Registry.on_configuration_changed(function()
 local t=state();t.configuration=true
 check(Broker.service_count()==t.service_count,"configuration preserves service count")
end,{owner="native_skin_broker_test",route="configuration",priority=2000})
local function runs()local s=Broker.root().service_stats.character_visuals_presentation;return s and s.run or 0 end
Registry.on_event(defines.events.on_tick,function(event)
 local t=state();if not t then return end
 if t.done then
  check(Broker.service_count()==t.service_count,"load preserves service count")
  if not t.reload then
   t.reload=true
   log("[TP-SKIN-BROKER] RELOAD_PASS stable named service count")
  end
  return
 end
 local player=game.get_player(1);if not player then return end
 if t.stage==0 then
  if not player.character then player.set_controller{type=defines.controllers.character,character=player.surface.create_entity{name="character",position={0,0},force=player.force}} end
  check(Picker.choose(player,"vanilla"),"native vanilla transfer")
  t.start=event.tick;t.stage=1
  local count=Broker.service_count()
  check(Visuals.install() and Visuals.install(),"presentation install is idempotent")
  check(Broker.service_count()==count,"repeated install does not duplicate service")
  local found=0
  for _,s in ipairs(Broker.services) do if s.name=="character_visuals_presentation" then
   found=found+1;check(s.interval==5 and s.budget==128 and s.dynamic_budget==false,"five-tick bounded broker service")
  end end
  check(found==1,"one stable presentation service")
  t.service_count=count
 end
 local elapsed=event.tick-t.start
 if elapsed>=10 and t.stage==1 then
  check(not Economy.runtime_active("native-proof"),"no station/runtime asset wakes ordinary work")
  check(not Visuals.needs_dormant_tick(),"vanilla/no pending work is dormant")
  t.empty_pulses=Broker.root().stats.pulses or 0;t.stage=2
 end
 if elapsed>=20 and t.stage==2 then
  check((Broker.root().stats.pulses or 0)==t.empty_pulses,"empty dormant broker receives no pulse")
  check(t.background==0 and t.registry5==0,"ordinary broker and co-scheduled registry5 remain asleep")
  check(Picker.choose(player,"enginseer"),"select custom skin before first station")
  player.walking_state={walking=true,direction=2}
  t.before_runs=runs();t.stage=3
 end
 if elapsed>=30 and t.stage==3 then
  check(not Economy.runtime_active("native-proof"),"avatar does not wake whole runtime")
  check(runs()>t.before_runs,"canonical broker updates presentation while dormant")
  local rec=storage.tech_priests.character_visuals.actors[player.character.unit_number]
  check(rec and rec.state=="walk" and rec.row==1,"native walk state follows broker before first station")
  check(t.background==0 and t.registry5==0,"presentation exception excludes ordinary and co-scheduled callbacks")
  check(_G.tech_priests_should_run_nth_tick_0595(5,nil,event)==false,"raw5 route-blind gate remains closed")
  t.pre_station_runs=runs();t.pre_station_broker=t.background;t.pre_station_registry5=t.registry5
  player.walking_state={walking=false,direction=2}
  t.done=true
  helpers.write_file("character-skins/broker-gating.json",helpers.table_to_json{
   passed=true,interval=5,budget=128,stable_services=t.service_count,
   pre_station_presentation_runs=t.pre_station_runs,empty_dormant_pulses=t.empty_pulses,
   ordinary_broker_runs=t.pre_station_broker,co_scheduled_registry5_runs=t.pre_station_registry5,
   route_blind_raw5_gate=false},false)
  log("[TP-SKIN-BROKER] PASS dormant presentation; ordinary broker/registry5 asleep; raw5 gate contract closed")
  game.auto_save("skin-broker-gating")
 end
end,nil,{owner="native_skin_broker_test",route="assertions",priority=3000})
