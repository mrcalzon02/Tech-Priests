-- Direct Machine Spirit cache invalidation and source-level Factorio event wiring.
-- No native Factorio runner, workflow trigger, or global machine scan.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Doctrine=require("scripts.core.consecration.doctrine_effects")
local Bridge=require("scripts.core.consecration.runtime_bridge")
local function near(actual,expected,why)
  assert(math.abs(actual-expected)<0.000001,why..": "..tostring(actual).." vs "..tostring(expected))
end
local reads=0
local items={{name="tech-priests-order-module-2",quality="legendary",count=1}}
local broken=false
local entity={valid=true,unit_number=101}
function entity.get_module_inventory()
  reads=reads+1
  if broken then error("transient native inventory fault") end
  return {get_contents=function() return items end}
end
game={tick=100}
local record={entity=entity,sanctification=50,max_sanctification=100}
local first=Doctrine.snapshot(record)
near(first.order,30,"Legendary Order II")
near(Doctrine.effective_value(record),80,"original effective sanctity")
assert(reads==1,"one engine inventory read per cache interval")
items={{name="tech-priests-chaos-module-2",quality="normal",count=1}}
game.tick=110
near(Doctrine.snapshot(record).order,30,"cache must remain bounded until targeted invalidation")
assert(Doctrine.invalidate(record),"cannot invalidate selected record")
local second=Doctrine.snapshot(record)
near(second.chaos,22,"fresh Chaos inventory not read")
near(second.order,0,"removed Order module not cleared")
near(Doctrine.effective_value(record),28,"effective sanctity after module swap")
assert(Doctrine.snapshot_changed(first,second),"real module edit not detected")
assert(not Doctrine.snapshot_changed(second,second),"identical module inventory flagged as change")
assert(not Doctrine.snapshot_changed(nil,{order=0,chaos=0,resilience=0,waste=0,extraction=0}),
  "empty inventory must not force graphics redraw")
assert(reads==2,"invalidation did not produce exactly one fresh read")
local second_record={entity=entity,sanctification=50,max_sanctification=100}
Doctrine.snapshot(second_record)
local second_deadline=second_record.machine_spirit_module_resample_tick
Doctrine.invalidate(record)
assert(second_record.machine_spirit_module_resample_tick==second_deadline,
  "invalidating one machine touched an unrelated record")
broken=true
game.tick=111
local cached=Doctrine.snapshot(record)
assert(cached==second,"transient API fault discarded last good paid-module state")
assert(record.machine_spirit_module_sample_error:find("transient native inventory fault",1,true),
  "transient API fault not reported")
assert(record.machine_spirit_module_resample_tick==126,"bounded error retry deadline incorrect")
local count=reads
game.tick=125
assert(Doctrine.snapshot(record)==second and reads==count,"read failure caused repeated inventory polling")
broken=false
items={{name="tech-priests-order-module-1",quality="normal",count=1}}
game.tick=126
near(Doctrine.snapshot(record).order,10,"failed module read did not recover")
assert(record.machine_spirit_module_sample_error==nil,"recovered inventory error remained stale")
assert(record.sanctification==50,"module refresh changed stored machine condition")
assert(not Doctrine.invalidate(nil),"nil invalidation should not report success")
-- A first-ever read failure must be throttled just like a failed resample.
local cold_reads=0
local cold_fault=true
local cold={entity={valid=true,get_module_inventory=function()
  cold_reads=cold_reads+1
  if cold_fault then error("first read blocked") end
  return {get_contents=function() return {{name="tech-priests-order-module-1",count=1}} end}
end}}
game.tick=200
assert(Doctrine.snapshot(cold).order==0 and cold_reads==1,"cold error fallback incorrect")
game.tick=210
assert(Doctrine.snapshot(cold).order==0 and cold_reads==1,"cold error repeated hotpath reads")
cold_fault=false
game.tick=215
assert(Doctrine.snapshot(cold).order==10 and cold_reads==2,"cold error retry did not recover")

-- Test that the already-installed canonical registry scopes two player events
-- to just the tracked entity, with no new scan, scheduler or independent writer.
local routes={};local scans=0;local redraws=0
TechPriestsRuntimeEventRegistry={
  on_event=function(events,callback,filter,opts)
    routes[opts.route]={events=events,callback=callback,options=opts}
    return true
  end,
  on_nth_tick=function(tick,callback,options)
    scans=scans+1
    return true
  end,
  on_configuration_changed=function(callback,opts)
    routes[opts.route]={callback=callback,options=opts}
    return true
  end
}
defines={events={
  on_built_entity=1,on_robot_built_entity=2,script_raised_built=3,
  script_raised_revive=4,on_entity_died=5,on_pre_player_mined_item=6,
  on_robot_pre_mined=7,script_raised_destroy=8,on_player_fast_transferred=9,
  on_gui_closed=10
}}
storage={tech_priests={consecration={machines={[101]=record}}}}
tech_priests_0446_refresh_sanctification_label_if_due=function(actual,forced)
  assert(actual==record and forced==true,"wrong record or non-forced label refresh")
  redraws=redraws+1
end
assert(Bridge.install(),"existing runtime bridge did not install")
local route=assert(routes["refresh-machine-modules-on-player-interaction"])
assert(#route.events==2 and route.events[1]==9 and route.events[2]==10,
  "invalid event-specific refresh registrations")
assert(route.options.owner=="consecration-runtime-bridge","new runtime authority created")
assert(scans==1,"unexpected new periodic scan added")
local first_event_reads=reads
route.callback({entity={valid=true,unit_number=999}})
route.callback({entity={valid=false,unit_number=101}})
route.callback({})
assert(reads==first_event_reads and redraws==0,"untracked/invalid entity caused inventory access")
-- Simulate a native GUI-close after inserting new modules at the same tick.
items={{name="tech-priests-order-module-2",quality="normal",count=2}}
game.tick=130
route.callback({entity=entity,name=10})
near(Doctrine.effective_value(record),90,"GUI close failed to refresh Order bonuses")
assert(redraws==1,"changed Order module inventory did not refresh label exactly once")
route.callback({entity=entity,name=10})
assert(redraws==1,"unchanged GUI close caused needless redraw")
items={{name="tech-priests-chaos-module-1",quality="normal",count=1}}
game.tick=131
route.callback({entity=entity,name=9,from_player=true})
near(Doctrine.effective_value(record),38,"fast transfer failed to refresh Chaos bonuses")
assert(redraws==2,"changed fast transfer did not refresh label")
assert(record.sanctification==50,"interactive module edits healed/degraded stored sanctity")
assert(scans==1,"interactive edits added a periodic scan")
print("[machine-spirit-module-refresh] PASS targeted events, cache, error retry, persistence, no excess redraw")
