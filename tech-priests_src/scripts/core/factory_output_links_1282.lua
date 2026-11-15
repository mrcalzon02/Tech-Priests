-- Paid native assembler output links. This coordinator publishes exact 0338
-- requests; only that original builder removes stock and creates entities.
local M={}
local function valid(e)return e and e.valid end
local function now()return game and game.tick or 0 end
local function scope(p,e)return valid(e)and e.force==p.station.force and e.surface==p.station.surface end
local function near(a,b)return(a.x-b.x)^2+(a.y-b.y)^2<.04 end
local function stock(p,item)
 local a=rawget(_G,"TechPriestsStorageRoleAuthority0686")
 if not(a and a.generic_item_count)then return 0 end
 local ok,n=pcall(a.generic_item_count,p,item);return ok and tonumber(n)or 0
end
local function connected(p,r)
 if not(r and scope(p,r.machine)and scope(p,r.chest)and scope(p,r.inserter))then return false end
 local ok,yes=pcall(function()return r.machine.get_recipe().name==r.recipe
   and r.inserter.pickup_target==r.machine
   and r.inserter.drop_target==r.chest end)
 return ok and yes==true
end
function M.owns_output_inserter(p,e,machine)
 local op=p and p.independent_emergency_operation_0184
 local r=p and p.factory_output_links_1282 and p.factory_output_links_1282[machine.unit_number]
 return op and op.enabled==true and r and r.inserter==e and connected(p,r)or false
end
function M.output_automated(p,machine)
 local op=p and p.independent_emergency_operation_0184
 if not(op and op.enabled==true)then return false end
 local r=p and p.factory_output_links_1282 and p.factory_output_links_1282[machine.unit_number]
 if not connected(p,r)then return false end
 local ok,powered=pcall(function()
  if r.inserter.energy<=0 then return false end
  local inv=r.chest.get_inventory(defines.inventory.chest)
  return inv and inv.valid and inv.get_insertable_count(r.output)>0
 end)
 return ok and powered==true
end
local function clear(p,item,pos,direction)
 local r=math.max(8,tonumber(p.radius)or 28)-2
 if(pos.x-p.station.position.x)^2+(pos.y-p.station.position.y)^2>r*r then return false end
 local ok,yes=pcall(function()return p.station.surface.can_place_entity{
  name=item,position=pos,direction=direction,force=p.station.force,
  build_check_type=defines and defines.build_check_type and defines.build_check_type.manual}end)
 return ok and yes==true
end
local function external_connection(p,machine)
 local ok,entities=pcall(function()return p.station.surface.find_entities_filtered{
  position=machine.position,radius=4,force=p.station.force,
  type={"inserter","loader","loader-1x1"},limit=32}end)
 if not ok then return true end
 for _,e in pairs(entities or{})do
  local read,linked=pcall(function()
   if e.type=="inserter"then return e.pickup_target==machine or e.drop_target==machine end
   return e.loader_container==machine
  end)
  if read and linked then return true end
 end
 return false
end
local function owned(p,machine,plan)
 if not(scope(p,machine)and machine.type=="assembling-machine"
   and(machine.name=="assembling-machine-1"or machine.name=="assembling-machine-2"
     or machine.name=="assembling-machine-3"))then return nil end
 local ok,recipe=pcall(function()return machine.get_recipe()end)
 local job=ok and recipe and plan and plan.factory_component_jobs_1150
   and plan.factory_component_jobs_1150[recipe.name]
 if not(job and job.researched==true and job.output_item)then return nil end
 return recipe,job
end
local function busy(p)
 for _,key in ipairs{"emergency_craft","direct_acquisition_task_0336","direct_acquisition_custody_0513",
  "construction_task_0338","construction_custody_0338","machine_logistics_custody_0528",
  "energy_family_custody_0707","item_family_custody_0702","inventory_transfer_custody_0687",
  "repair_pack_custody_0516","station_cargo_custody_0824","defense_task_0259",
  "emergency_production_custody_0514","emergency_facility_feed_custody_0357",
  "consecration_refund_custody_0515","rocket_silo_custody_0710",
  "artillery_custody_0713","roboport_repair_custody_0715"}do
  if p[key]then return true end
 end
 if p.machine_logistics_0528 and p.machine_logistics_0528.custody then return true end
 if valid(p.combat_target)then return true end
 local order=p.order_queue_0469 and p.order_queue_0469.current or p.active_order_0469
 return order and order.status=="active"or false
end
local function request(p,link,item,pos,direction,phase)
 if stock(p,item)<1 or not clear(p,item,pos,direction)then return false end
 local req={item_name=item,entity_name=item,position={x=pos.x,y=pos.y},direction=direction,
  category="material-transfer",source="factory-output-links-1282",
  site_reason="physical-recipe-output-"..phase..":"..link.recipe}
 link.request=req;link.phase=phase;p.construction_requested_item=req
 return true
end
local function fail(p,link,reason)
 if p.construction_requested_item==link.request then p.construction_requested_item=nil end
 p.factory_output_link_failure_1282={tick=now(),unit=link.machine_unit,reason=reason}
 local refused=p.factory_output_link_refusals_1282 or{}
 refused[link.machine_unit]=now()+3600;p.factory_output_link_refusals_1282=refused
 p.factory_output_link_plan_1282=nil
 return false,reason
end
function M.service(p,plan)
 local op=p and p.independent_emergency_operation_0184
 if not(op and op.enabled==true and valid(p.station)and valid(p.priest))then return false,"not-independent"end
 if busy(p)then return false,"physical-owner-busy"end
 local link=p.factory_output_link_plan_1282
 if link then
  local recipe=owned(p,link.machine,plan)
  if not(recipe and recipe.name==link.recipe)then return fail(p,link,"recipe-or-domain-changed")end
  local receipt=link.receipt or p.construction_last_task_0338
  if link.request then
   if p.construction_requested_item==link.request then return true,"original-builder-request-pending"end
   if not(receipt and receipt.phase=="complete" and receipt.request_value==link.request and scope(p,receipt.built_entity))then
    return fail(p,link,"original-construction-receipt-missing")
   end
   local built=receipt.built_entity
   local expected=link.phase=="chest"and link.chest_position or link.inserter_position
   if built.name~=link.request.entity_name or not near(built.position,expected)then
    return fail(p,link,"original-built-entity-mismatch")
   end
   if link.phase=="chest"then link.chest=built else link.inserter=built end
   link.request=nil;link.receipt=nil
  end
  if link.inserter then
   if not connected(p,link)then return fail(p,link,"native-pickup-drop-targets-disconnected")end
   p.factory_output_links_1282=p.factory_output_links_1282 or{}
   p.factory_output_links_1282[link.machine.unit_number]=link
   p.factory_output_link_plan_1282=nil
   return true,"native-recipe-output-connected"
  end
  if p.construction_requested_item or p.construction_request or p.structure_construction_requested_item then
   return false,"foreign-construction-request"
  end
  if not(scope(p,link.chest)and request(p,link,"inserter",link.inserter_position,link.direction,"inserter"))then
   if scope(p,link.chest)and now()-(tonumber(link.site_blocked_since)or now())<3600 then
    link.site_blocked_since=link.site_blocked_since or now()
    return false,"paid-chest-awaiting-clear-funded-inserter-site"
   end
   return fail(p,link,"funded-inserter-site-unavailable")
  end
  return true,"paid-output-inserter-requested"
 end
 if p.construction_requested_item or p.construction_request or p.structure_construction_requested_item
   or stock(p,"inserter")<1 then return false,"request-or-kit-unavailable"end
 local chest_item
 for _,item in ipairs{"wooden-chest","iron-chest","steel-chest"}do
  if stock(p,item)>0 then chest_item=item;break end
 end
 if not chest_item then return false,"no-paid-output-chest"end
 local ledger=storage and storage.tech_priests and storage.tech_priests.emergency_facility_doctrine_0343
 local records=ledger and ledger.by_station and ledger.by_station[p.station.unit_number]
 local candidates={}
 local seen={}
 local function candidate(machine,expected_recipe)
  local recipe,job=owned(p,machine,plan)
  if not recipe or(expected_recipe and recipe.name~=expected_recipe)then return end
  local unit=machine.unit_number
  local refused=p.factory_output_link_refusals_1282 and p.factory_output_link_refusals_1282[unit]
  if not seen[unit]and not(refused and refused>now())and not external_connection(p,machine)then
   seen[unit]=true
   candidates[#candidates+1]={machine=machine,recipe=recipe.name,output=job.output_item}
  end
 end
 for key in pairs(records or{})do
  local record=ledger.facilities and ledger.facilities[key]
  local machine=record and record.entity
  if record and record.station_unit==p.station.unit_number and record.role=="assembler"then
   candidate(machine)
  end
 end
 local function paid_receipt(r)
  if r and r.configured==true and r.station_unit==p.station.unit_number
    and valid(r.built_entity)and r.entity_unit==r.built_entity.unit_number then
   candidate(r.built_entity,r.recipe)
  end
 end
 for _,r in pairs(p.factory_component_receipts_1282 or{})do paid_receipt(r)end
 paid_receipt(p.factory_component_last_receipt_1150)
 table.sort(candidates,function(a,b)return a.machine.unit_number<b.machine.unit_number end)
 -- Vanilla inserter prototype picks north and drops south at direction 0.
 -- Every final link still requires actual native pickup/drop target equality.
 local sides={{x=0,y=1,direction=0},{x=0,y=-1,direction=8},
  {x=1,y=0,direction=12},{x=-1,y=0,direction=4}}
 for _,candidate in ipairs(candidates)do
  for _,side in ipairs(sides)do for _,lateral in ipairs{0,1,-1}do
   local m=candidate.machine.position
   local shift={x=side.y*lateral,y=side.x*lateral}
   local extent=1.5
   local box=candidate.machine.bounding_box
   if box then
    if side.x>0 then extent=box.right_bottom.x-m.x
    elseif side.x<0 then extent=m.x-box.left_top.x
    elseif side.y>0 then extent=box.right_bottom.y-m.y
    else extent=m.y-box.left_top.y end
   end
   local function grid(v,d)
    if d>0 then return math.ceil(v-.5)+.5 end
    if d<0 then return math.floor(v-.5)+.5 end
    return math.floor(v)+.5
   end
   local a={x=grid(m.x+side.x*(extent+.5)+shift.x,side.x),
    y=grid(m.y+side.y*(extent+.5)+shift.y,side.y)}
   local b={x=a.x+side.x,y=a.y+side.y}
   if clear(p,"inserter",a,side.direction)and clear(p,chest_item,b,nil)then
    local chosen={machine=candidate.machine,machine_unit=candidate.machine.unit_number,recipe=candidate.recipe,output=candidate.output,
     chest_position=b,inserter_position=a,direction=side.direction,started_tick=now()}
    if request(p,chosen,chest_item,b,nil,"chest")then
     p.factory_output_link_plan_1282=chosen
     return true,"paid-recipe-output-chest-requested"
    end
   end
  end end
 end
 return false,"no-owned-output-link-site"
end
return M
