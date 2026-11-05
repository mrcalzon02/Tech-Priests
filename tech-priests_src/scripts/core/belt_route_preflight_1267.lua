-- 1267: bounded, read-only native belt candidate route search.
-- Route endpoints come from REAL engine drill/inserter handoffs. A checked
-- candidate is not a built, connected, supplied or authorized transport.
-- Never spawn ghosts, insert items, claim 0338 work or change the world.
local M={version="1267",read_only=true,actuation_enabled=false,
 max_nodes=640,max_tiles=32,max_radius=72}
local Contract=require("scripts.core.belt_logistics_contract_1266")
local function valid(e)return e and e.valid==true end
local function point(p)
 if p and type(p.x)=="number"and type(p.y)=="number"
     and p.x==p.x and p.y==p.y then return{x=p.x,y=p.y}end
 return nil
end
local function tile(p)
 p=point(p)
 if not p then return nil end
 return{x=math.floor(p.x),y=math.floor(p.y)}
end
local function center(p)return{x=p.x+.5,y=p.y+.5}end
local function key(p,d)return p.x..","..p.y..":"..(d or "start")end
local function d2(a,b)local x=a.x-b.x;local y=a.y-b.y;return x*x+y*y end
local function owned(pair,e)
 return valid(e)and valid(pair.station)
  and e.force==pair.station.force and e.surface==pair.station.surface
  and type(e.unit_number)=="number"
end
local function read_property(e,k)
 local value
 local ok=pcall(function()value=e[k]end)
 return ok and value or nil
end
local function limit(pair)
 local r=tonumber(pair.radius)
 local f=rawget(_G,"get_station_operating_radius")
 if type(f)=="function"then
  local ok,x=pcall(f,pair.station)
  if ok and tonumber(x)then r=tonumber(x)end
 end
 if not(r and r>=4)then return nil end
 return math.min(r,M.max_radius)
end
local function directions()
 local d=defines and defines.direction
 if not d or type(d.north)~="number"
    or type(d.east)~="number"or type(d.south)~="number"
    or type(d.west)~="number"then return nil end
 return{
  {dx=0,dy=-1,value=d.north,name="north"},
  {dx=1,dy=0,value=d.east,name="east"},
  {dx=0,dy=1,value=d.south,name="south"},
  {dx=-1,dy=0,value=d.west,name="west"}
 }
end
local function item_places_belt(name)
 local item=prototypes and prototypes.item and prototypes.item[name]
 if not item then return nil,"native-belt-item-unavailable"end
 local result=read_property(item,"place_result")
 local entity=result and result.name and result.name or result
 if type(entity)~="string"then return nil,"native-belt-place-result-unavailable"end
 local ep=prototypes and prototypes.entity and prototypes.entity[entity]
 if not ep or read_property(ep,"type")~="transport-belt"then
  return nil,"native-transport-belt-prototype-unavailable"
 end
 return entity,nil
end
local function start_handoff(pair,spec)
 local e=spec.source
 local arm=spec.source_inserter
 if arm then
  if not(owned(pair,arm)and arm.type=="inserter"
    and arm~=spec.sink_inserter)then
   return nil,"source-inserter-not-native-or-foreign"
  end
  if read_property(arm,"pickup_target")~=e then
   return nil,"source-inserter-not-picking-from-source"
  end
  local pos=point(read_property(arm,"drop_position"))
  return pos,pos and"native-source-inserter-drop"
    or"native-source-inserter-drop-unobservable"
 end
 -- Direct drill output is a native drop point; a chest or furnace may not
 -- be treated as an imaginary inserter without a real handoff.
 if e.type~="mining-drill"then
  return nil,"source-needs-observed-output-inserter"
 end
 local pos=point(read_property(e,"drop_position"))
 return pos,pos and"native-mining-drill-drop"
   or"native-mining-drill-drop-unobservable"
end
local function end_handoff(pair,spec)
 local arm=spec.sink_inserter
 if not(owned(pair,arm)and arm.type=="inserter")then
  return nil,"sink-inserter-not-native-or-foreign"
 end
 if read_property(arm,"drop_target")~=spec.sink then
  return nil,"sink-inserter-not-feeding-sink"
 end
 local pos=point(read_property(arm,"pickup_position"))
 return pos,pos and"native-sink-inserter-pickup"
   or"native-sink-inserter-pickup-unobservable"
end
local function reconstruct(goal)
 local reverse,next_node={},nil
 local node=goal
 while node do
  local dir=next_node and next_node.incoming or node.incoming
  reverse[#reverse+1]={position=center(node),direction=dir}
  next_node=node
  node=node.previous
 end
 local result={}
 for i=#reverse,1,-1 do result[#result+1]=reverse[i]end
 return result
end

function M.plan(pair,spec,options)
 local requirement,why=Contract.demand(pair,spec)
 if not requirement then return nil,why end
 if not(owned(pair,spec.source)and owned(pair,spec.sink))then
  return nil,"native-endpoint-lost"
 end
 local surface=pair.station.surface
 if not(surface and type(surface.can_place_entity)=="function")then
  return nil,"native-belt-placement-api-unavailable"
 end
 local radius=limit(pair)
 if not radius then return nil,"station-operating-radius-unobservable"end
 local dirs=directions()
 if not dirs then return nil,"native-direction-constants-unavailable"end
 local belt_name,proto_why=item_places_belt(
    type(options)=="table"and options.belt_item or"transport-belt")
 if not belt_name then return nil,proto_why end
 local source_pos,source_kind=start_handoff(pair,spec)
 if not source_pos then return nil,source_kind end
 local sink_pos,sink_kind=end_handoff(pair,spec)
 if not sink_pos then return nil,sink_kind end
 local begin=tile(source_pos)
 local finish=tile(sink_pos)
 if begin.x==finish.x and begin.y==finish.y then
  return nil,"same-tile-requires-direct-handoff-not-belt"
 end
 local station_pos=point(pair.station.position)
 if not station_pos then return nil,"native-station-position-unobservable"end
 local r2=radius*radius
 local function allowed_territory(p)
  return d2(center(p),station_pos)<=r2
 end
 if not(allowed_territory(begin)and allowed_territory(finish))then
  return nil,"endpoints-outside-station-planning-area"
 end
 local max_tiles=math.min(M.max_tiles,math.max(2,
    math.floor(tonumber(options and options.max_tiles)or M.max_tiles)))
 local max_nodes=math.min(M.max_nodes,math.max(1,
    math.floor(tonumber(options and options.max_nodes)or M.max_nodes)))
 local observed_calls,first_api_error=0,false
 local function native_legal(p,direction)
  observed_calls=observed_calls+1
  local ok,accepted=pcall(function()
   return surface.can_place_entity{name=belt_name,position=center(p),
     direction=direction,force=pair.station.force}
  end)
  if not ok then first_api_error=true end
  return ok and accepted==true
 end
 local queue={{x=begin.x,y=begin.y,depth=1,incoming=nil,previous=nil}}
 local visited={[key(begin)]=true}
 local cursor,expanded=1,0
 while cursor<=#queue and expanded<max_nodes do
  local node=queue[cursor];cursor=cursor+1;expanded=expanded+1
  if node.depth<max_tiles then
   local choices={}
   for _,direction in ipairs(dirs)do
    local p={x=node.x+direction.dx,y=node.y+direction.dy}
    local cost=math.abs(p.x-finish.x)+math.abs(p.y-finish.y)
    choices[#choices+1]={p=p,d=direction,score=cost}
   end
   table.sort(choices,function(a,b)
    if a.score~=b.score then return a.score<b.score end
    return a.d.value<b.d.value
   end)
   for _,entry in ipairs(choices)do
    local next_pos,dir=entry.p,entry.d
    -- Avoid same-tile turns/U-turns masquerading as forward transport.
    local reverse=node.incoming and
     ((node.incoming==dirs[1].value and dir.value==dirs[3].value)
     or(node.incoming==dirs[3].value and dir.value==dirs[1].value)
     or(node.incoming==dirs[2].value and dir.value==dirs[4].value)
     or(node.incoming==dirs[4].value and dir.value==dirs[2].value))
    local id=key(next_pos,dir.value)
    if not reverse and not visited[id]and allowed_territory(next_pos)
      and native_legal(node,dir.value)then
     local next_node={x=next_pos.x,y=next_pos.y,
       incoming=dir.value,previous=node,depth=node.depth+1}
     if next_pos.x==finish.x and next_pos.y==finish.y then
      if native_legal(next_pos,dir.value)then
       local tiles=reconstruct(next_node)
       -- Recheck EVERY exact oriented site. This remains only a
       -- candidate and is subject to revalidation by original 0338.
       for _,v in ipairs(tiles)do
        if not native_legal(tile(v.position),v.direction)then
         return nil,"native-belt-route-recheck-refused"
        end
       end
       return{version=M.version,status="native-sites-candidate-only",
        item=requirement.item,rate_per_min=requirement.rate_per_min,
        belt_entity=belt_name,owner_station_unit=requirement.owner_station_unit,
        source_unit=requirement.source.unit,sink_unit=requirement.sink.unit,
        source_inserter_unit=spec.source_inserter and spec.source_inserter.unit_number,
        sink_inserter_unit=spec.sink_inserter.unit_number,
        source_handoff=source_kind,sink_handoff=sink_kind,
        doctrine_key=requirement.doctrine_key,
        tiles=tiles,required_belt_items=#tiles,expanded_nodes=expanded,
        native_placement_checks=observed_calls,
        physical_transport_verified=false,construction_authorized=false,
        custody_acquired=false,read_only=true},nil
      end
     else
      visited[id]=true;queue[#queue+1]=next_node
     end
    end
   end
  end
 end
 if first_api_error then return nil,"native-belt-placement-query-failed"end
 if expanded>=max_nodes then return nil,"native-belt-search-budget-exhausted"end
 return nil,"no-native-placeable-belt-route"
end
return M
