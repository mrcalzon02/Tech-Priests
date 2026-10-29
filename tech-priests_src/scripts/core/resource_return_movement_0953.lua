-- 0953: read-only authority for a real 0837 ore courier's movement.
-- Never mines, changes custody, changes hierarchy or overrides active work.
local Chain=require("scripts.core.resource_station_chain_0820")
local M={}
local function valid(e) return e and e.valid end
local function dist2(a,b)
  if not(a and b and type(a.x)=="number" and type(a.y)=="number"
      and type(b.x)=="number" and type(b.y)=="number") then
    return math.huge
  end
  local x,y=a.x-b.x,a.y-b.y
  return x*x+y*y
end
local function count(inv,item)
  if not(valid(inv) and type(inv.get_item_count)=="function") then return nil,nil end
  local ok,n,total=pcall(function()
    return inv.get_item_count(item),inv.get_item_count()
  end)
  if not ok then return nil,nil end
  return tonumber(n),tonumber(total)
end
local reasons={
  ["to-natural-ore"]="resource-return-natural-ore-0953",
  ["to-upstream-pickup"]="resource-return-upstream-pickup-0953",
  carrying="resource-return-upstream-delivery-0953",
}
function M.authorized(pair,request)
  if not(type(request)=="table" and
      (request.owner=="resource-return-courier-0953"
        or request.owner=="movement-controller-enforcement-0566")
      and valid(pair and pair.station) and valid(pair.priest)
      and pair.station.unit_number and pair.priest.unit_number
      and not(pair.dead or pair.recalling or pair.deploying
        or pair.active_task or pair.current_task or pair.combat_target
        or pair.repair_target or pair.construction_task
        or pair.construction_task_0338 or pair.construction_task_0340
        or pair.direct_acquisition_task_0336 or pair.active_acquisition_0333
        or pair.direct_acquisition_custody_0513
        or pair.machine_logistics_custody_0528
        or pair.inventory_transfer_custody_0687)) then return false end
  local tp=storage and storage.tech_priests
  local pairs=tp and tp.pairs_by_station
  if not(type(pairs)=="table" and
      (pairs[pair.station.unit_number]==pair
        or pairs[tostring(pair.station.unit_number)]==pair)) then return false end
  local assignment=pair.remote_resource_assignment_0820
  local root_id=type(assignment)=="table" and assignment.root_station_unit
  local magos=root_id and (pairs[root_id] or pairs[tostring(root_id)])
  local mission=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  local state=type(mission)=="table" and mission.return_courier_0837
  if not(type(state)=="table" and mission.status=="reached-resource"
      and mission.root_station_unit==root_id
      and valid(magos.station) and valid(magos.priest)
      and magos.station.unit_number==root_id
      and pair.station.force==magos.station.force
      and pair.station.surface==magos.station.surface
      and pair.priest.force==pair.station.force
      and pair.priest.surface==pair.station.surface
      and state.carrier_priest_unit==pair.priest.unit_number
      and state.source_station_unit==pair.station.unit_number
      and state.item==mission.need) then return false end
  local ok,route=pcall(Chain.return_route,magos)
  local hop=state.hop_index or 1
  if not(ok and type(route)=="table" and #route>=2
      and type(hop)=="number" and hop==math.floor(hop)
      and hop>=1 and hop<#route
      and route[hop]==pair.station.unit_number
      and route[hop+1]==state.destination_station_unit) then return false end
  local dest=pairs[route[hop+1]] or pairs[tostring(route[hop+1])]
  if not(valid(dest and dest.station) and valid(dest.priest)
      and dest.station.surface==pair.station.surface
      and dest.station.force==pair.station.force) then return false end
  local goal,reason
  if state.phase=="to-natural-ore" and hop==1
      and state.inventory==nil and state.quantity==0 then
    goal=mission.target
    reason=reasons[state.phase]
    local radius=type(Chain.operating_radius)=="function"
      and Chain.operating_radius(pair)
      or tonumber(pair.radius) or 20
    if not(type(radius)=="number" and radius>0
        and dist2(pair.station.position,goal)<=radius*radius) then return false end
  elseif state.phase=="to-upstream-pickup" and hop>1
      and state.inventory==nil
      -- 0970: the ore remains in this relay's REAL station inventory
      -- until its original priest walks home and physically debits it.
      -- Requiring nil custody rejected every valid first-hop receipt.
      and state.station_custody_unit==pair.station.unit_number
      and state.delivered_station_unit==pair.station.unit_number
      and state.delivered_count==1 and state.quantity==1
      and state.receipt_hop==hop-1 and state.hops_completed==hop-1 then
    local get=rawget(_G,"get_station_inventory")
    if type(get)~="function" then return false end
    local ok,inv=pcall(get,pair.station)
    if not(ok and valid(inv)) then return false end
    local held=count(inv,state.item)
    if held==nil or held<1 then return false end
    goal=pair.station.position
    reason=reasons[state.phase]
  elseif state.phase=="carrying" and state.quantity==1 then
    local held,total=count(state.inventory,state.item)
    if held~=1 or total~=1 then return false end
    goal=dest.station.position
    reason=reasons[state.phase]
  else
    return false
  end
  local final=request.ground_route_final_destination or request
  if request.owner=="movement-controller-enforcement-0566" then
    return request.reason=="movement-enforcement-overleash-return-0566"
      and (tonumber(request.priority) or 0)>=840
      and (tonumber(request.expires_tick) or 0)>=(game and game.tick or 0)
      and dist2(final,pair.station.position)<=0.04
  end
  if request.reason~=reason or (tonumber(request.priority) or 0)~=72
      or (request.expires_tick and request.expires_tick<(game and game.tick or 0)) then
    return false
  end
  -- Ore may be one of several real entities inside the 8x8 fresh scan area.
  if state.phase=="to-natural-ore" then
    return dist2(final,goal)<=32
  end
  return dist2(final,goal)<=0.04
end
return M
