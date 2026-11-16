-- Independent Space Age campaign planning. A platform order is unbuilt until
-- a real starter pack arrives through the engine's ordinary rocket/pod cycle.
-- Only original 0710's dispatched physical silo owner calls request_launch.
local ProductionOrder=require("scripts.core.production_order_ownership_0514")
local VoidConstruction=require("scripts.core.void_orbital_construction_1292")
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
function M.payload_inventory(report,item)
 item=item or M.starter_pack
 local candidates={report and report.rocket_inventory or false,report and report.attached_cargo_inventory or false}
 for _,inv in ipairs(candidates)do
  if inv and inv.valid then
   local ok,n=pcall(inv.get_item_count,item)
   if ok and(tonumber(n)or 0)>0 then return inv end
  end
 end
 for _,inv in ipairs(candidates)do
  if inv and inv.valid then
   local ok,yes=pcall(inv.can_insert,{name=item,count=1})
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
  if valid(platform.hub)then
   if valid(existing.silo)and existing.silo~=report.silo then return nil,"force-orbital-supply-silo-owned"end
   local flight=existing.void_supply_flight_1292
   if flight and not flight.ended_tick then return nil,"native-void-supply-flight-pending"end
   local request=VoidConstruction.material_request(platform)
   if not request then return nil,"local-void-no-material-request"end
   local inv=M.payload_inventory(report,request.item)
   if not inv then return nil,"native-void-cargo-inventory-unavailable"end
   for _,stack in pairs(inv.get_contents())do
    if stack.name~=request.item then return nil,"foreign-native-rocket-cargo"end
   end
   local held=inv.get_item_count(request.item)
   return{kind="local-void-supply",item=request.item,count=math.max(0,request.count-held),
    inventory=inv,loaded=held>=request.count,manager_station=request.manager_station}
  end
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
 if valid(platform.hub)and need.kind~="local-void-supply"then return false,"owned-platform-built"end
 -- This call consumes no scripted inventory and creates no free foundation.
 -- The engine alone decides launch readiness and transports the real payload.
 local destination={type=defines.cargo_destination.space_platform,space_platform=platform}
 if need.kind=="local-void-supply"then
  if not defines.cargo_destination.station then return false,"native-hub-destination-unavailable"end
  destination={type=defines.cargo_destination.station,station=platform.hub}
 end
 local ok,launched=pcall(function()return report.silo.launch_rocket(destination)end)
 rec.last_attempt_tick=game.tick;rec.silo=report.silo;rec.station_unit=p.station.unit_number
 if not(ok and launched==true)then rec.phase="awaiting-native-launch";return false,"native-launch-not-ready"end
 if need.kind=="local-void-supply"then
  rec.void_supply_flight_1292={silo=report.silo,requested_tick=game.tick}
  rec.void_supply_launches_1292=(rec.void_supply_launches_1292 or 0)+1
  rec.phase="void-supply-launch-requested"
 else rec.phase="launch-requested";rec.launch_requested_tick=game.tick end
 return true,"native-launch-requested"
end
function M.observe(p)
 if not independent(p)then return nil end
 local rec=record_for(p);if not rec then return nil end
 local platform,why=own_platform(p,rec)
 if not platform then return nil,why end
 local flight=rec.void_supply_flight_1292
 if flight and not flight.ended_tick then
  if flight.pod then
   if not flight.pod.valid then flight.ended_tick=game.tick end
  elseif valid(flight.silo)then
   local ok,pod=pcall(function()local rocket=flight.silo.rocket;return valid(rocket)and rocket.attached_cargo_pod end)
   if ok and valid(pod)then flight.pod=pod end
  end
 end
 if rec.launch_requested_tick and valid(platform.hub)and platform.hub.force==p.station.force
   and platform.hub.surface==platform.surface then
  if not flight or flight.ended_tick then rec.phase="starter-pack-delivered"end
  rec.delivered_tick=rec.delivered_tick or game.tick
  return true,"native-platform-starter-delivered"
 end
 return false,rec.phase
end
return M
