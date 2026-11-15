-- Independent Space Age campaign planning. A platform order is unbuilt until
-- a real starter pack arrives through the engine's ordinary rocket/pod cycle.
-- Only original 0710's dispatched physical silo owner calls request_launch.
local ProductionOrder=require("scripts.core.production_order_ownership_0514")
local M={starter_pack="space-platform-starter-pack"}
local function valid(e)return e and e.valid end
local function independent(p)
 local op=p and p.independent_emergency_operation_0184
 return p and valid(p.station)and valid(p.priest)and op and op.enabled==true
  and p.priest.force==p.station.force and p.priest.surface==p.station.surface
end
local function record_for(p)
 local tp=storage and storage.tech_priests
 local root=tp and tp.orbital_campaign_1287
 return root and root.by_force and root.by_force[p.station.force.index]
end
local function planet_for(p)
 local ok,planet=pcall(function()return p.station.surface.planet end)
 return ok and planet and planet.name and planet or nil
end
local function own_platform(p,r)
 if not(r and valid(r.platform))then return nil end
 if r.platform.force~=p.station.force then return nil,"platform-authority-changed"end
 local planet=planet_for(p)
 local location=r.platform.space_location
 if not(planet and location and location.name==planet.name)then return nil,"platform-orbit-changed"end
 return r.platform
end
function M.payload_inventory(report)
 local candidates={report and report.rocket_inventory or false,report and report.attached_cargo_inventory or false}
 for _,inv in ipairs(candidates)do
  if inv and inv.valid then
   local ok,n=pcall(inv.get_item_count,M.starter_pack)
   if ok and(tonumber(n)or 0)>0 then return inv end
  end
 end
 for _,inv in ipairs(candidates)do
  if inv and inv.valid then
   local ok,yes=pcall(inv.can_insert,{name=M.starter_pack,count=1})
   if ok and yes==true then return inv end
  end
 end
 return nil
end
function M.owns_silo(p,report)
 return independent(p)and report and valid(report.silo)and report.silo.type=="rocket-silo"
  and report.silo.force==p.station.force and report.silo.surface==p.station.surface
  and not report.automation_owned and not report.launch_sequence_active or false
end
function M.order_allows(p)
 local order=p.order_queue_0469 and p.order_queue_0469.current or p.active_order_0469
 return not order or order.status~="active"or order.kind=="rocket-silo-logistics"
   or ProductionOrder.matches(p,order,p.emergency_craft)
end
function M.requirement(p,report)
 if not(independent(p)and script and script.active_mods and script.active_mods["space-age"]
   and prototypes and prototypes.item and prototypes.item[M.starter_pack])then return nil,"not-independent-space-age"end
 local ready=defines and defines.rocket_silo_status and defines.rocket_silo_status.rocket_ready
 -- The engine resets rocket_parts when it creates the real rocket, before
 -- launch. Read the native ready state, never infer readiness from a counter.
 if not(M.owns_silo(p,report)and ready~=nil and report.rocket_silo_status==ready)then
  return nil,"native-rocket-not-ready"
 end
 local planet=planet_for(p);if not planet then return nil,"no-native-launch-planet"end
 local existing=record_for(p)
 if existing and valid(existing.platform)then
  local platform,why=own_platform(p,existing);if not platform then return nil,why end
  if valid(platform.hub)then return nil,"owned-platform-built"end
  if existing.launch_requested_tick then return nil,"owned-starter-launch-in-flight"end
 end
 local inv=M.payload_inventory(report)
 if not inv then return nil,"native-payload-inventory-unavailable"end
 local ok,n=pcall(inv.get_item_count,M.starter_pack)
 if not(ok and type(n)=="number")then return nil,"native-payload-unreadable"end
 return{item=M.starter_pack,count=1,inventory=inv,loaded=n>=1,planet=planet.name}
end
function M.request_launch(p,report)
 if not M.order_allows(p)then return false,"foreign-order-owned"end
 local need,why=M.requirement(p,report)
 if not need then return false,why end
 if not need.loaded then return false,"starter-pack-not-physically-loaded"end
 if not(defines and defines.cargo_destination and defines.cargo_destination.space_platform)then
  return false,"native-platform-destination-unavailable"
 end
 local tp=storage.tech_priests
 tp.orbital_campaign_1287=tp.orbital_campaign_1287 or{by_force={}}
 local root=tp.orbital_campaign_1287;root.by_force=root.by_force or{}
 local rec=root.by_force[p.station.force.index]
 if not(rec and valid(rec.platform))then
  local ok,platform=pcall(function()return p.station.force.create_space_platform{
   name="Conclave science "..p.station.force.index,planet=need.planet,starter_pack=need.item}end)
  if not(ok and valid(platform)and platform.force==p.station.force)then return false,"native-platform-order-refused"end
  rec={platform=platform,force_index=p.station.force.index,planet=need.planet,
   starter_pack=need.item,created_tick=game.tick,phase="awaiting-paid-starter-pack"}
  root.by_force[p.station.force.index]=rec
 end
 local platform,reason=own_platform(p,rec);if not platform then return false,reason end
 if valid(platform.hub)then return false,"owned-platform-built"end
 -- This call consumes no scripted inventory and creates no free foundation.
 -- The engine alone decides launch readiness and transports the real payload.
 local ok,launched=pcall(function()return report.silo.launch_rocket{
  type=defines.cargo_destination.space_platform,space_platform=platform}end)
 rec.last_attempt_tick=game.tick;rec.silo=report.silo;rec.station_unit=p.station.unit_number
 if not(ok and launched==true)then rec.phase="awaiting-native-launch";return false,"native-launch-not-ready"end
 rec.phase="launch-requested";rec.launch_requested_tick=game.tick
 return true,"native-launch-requested"
end
function M.observe(p)
 if not independent(p)then return nil end
 local rec=record_for(p);if not rec then return nil end
 local platform,why=own_platform(p,rec)
 if not platform then return nil,why end
 if rec.launch_requested_tick and valid(platform.hub)and platform.hub.force==p.station.force
   and platform.hub.surface==platform.surface then
  rec.phase="starter-pack-delivered";rec.delivered_tick=rec.delivered_tick or game.tick
  return true,"native-platform-starter-delivered"
 end
 return false,rec.phase
end
return M
