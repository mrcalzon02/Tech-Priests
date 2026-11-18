-- A separate same-mod profile: a raw interval5 probe replaces the canonical
-- handler only in this disposable native test, never in the shipped source.
local Registry=require("scripts.core.runtime_event_registry")
local Economy=require("scripts.core.efficiency_economy_0595")
local function check(ok,text)if not ok then error("[TP-RAW5-REGRESSION] FAIL "..text)end end
Registry.on_init(function()storage.raw5_delivery={calls=0}end,{owner="native_raw5",route="initialize",priority=2000})
script.on_nth_tick(5,function()storage.raw5_delivery.calls=storage.raw5_delivery.calls+1 end)
Registry.on_event(defines.events.on_tick,function(event)
 local t=storage.raw5_delivery;if t.done then return end
 if event.tick>=21 then
  check(not Economy.runtime_active("raw5-native-regression"),"runtime remains dormant")
  check(_G.tech_priests_should_run_nth_tick_0595(5,nil,event)==false,"route-blind gate denies raw5")
  t.done=true
  helpers.write_file("character-skins/raw5-delivery.json",helpers.table_to_json{
   passed=true,tick=event.tick,raw5_calls=t.calls,route_blind_gate=false,
   saved_native_registration=type(rawget(_G,"tech_priests_original_on_nth_tick_0596"))=="function",
   hook_effective=script.on_nth_tick~=rawget(_G,"tech_priests_original_on_nth_tick_0596")},false)
  log("[TP-RAW5-REGRESSION] PASS observed unchanged raw5 delivery with dormant gate denied")
 end
end,nil,{owner="native_raw5",route="observe",priority=3000})
