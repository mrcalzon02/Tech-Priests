-- Native starter-pack trigger adapter. No station/item is spawned here;
-- the canonical built-station lifecycle binds its ordinary single priest.
local M={}
function M.on_created(event)
 local station=event and event.entity
 if not(station and station.valid and station.name=="void-cogitator-station")then return false end
 local platform=station.surface.platform
 if not(platform and platform.valid and platform.force==station.force)then return false end
 local built=rawget(_G,"on_built")
 if type(built)~="function"then return false end
 built{entity=station}
 local tp=storage and storage.tech_priests
 local pair=tp and tp.pairs_by_station and tp.pairs_by_station[station.unit_number]
 if not(pair and pair.station==station and pair.priest and pair.priest.valid
   and pair.priest.surface==station.surface and pair.priest.force==station.force)then return false end
 pair.platform_startup_1290=pair.platform_startup_1290 or{platform_index=platform.index,created_tick=game.tick}
 local rec=tp.orbital_campaign_1287 and tp.orbital_campaign_1287.by_force[station.force.index]
 local parent=rec and rec.platform==platform and tp.pairs_by_station[rec.station_unit]
 if parent and parent.independent_emergency_operation_0184 and parent.independent_emergency_operation_0184.enabled==true
   and not(pair.independent_emergency_operation_0184 and pair.independent_emergency_operation_0184.enabled==true)
   and type(tech_priests_set_emergency_operation_0184)=="function"then
  pair.emergency_operation_auto_allowed_0190=true
  tech_priests_set_emergency_operation_0184(pair,true,"independent-platform-void-commissioning")
 end
 return true
end
function M.install()
 if not(script and script.active_mods and script.active_mods["space-age"])then return true end
 local Registry=require("scripts.core.runtime_event_registry")
 return Registry.on_event(defines.events.on_trigger_created_entity,M.on_created,nil,
  {owner="void_platform_startup_1290",route="native-starter-station",category="lifecycle"})~=nil
end
return M
