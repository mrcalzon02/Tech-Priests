-- 1266: read-only boundary between arterial recipe demands and future
-- physical belt/inserter routing. No registration, world writes or custody.
-- Factorio native state is the sole authority for transport observations.
local M={version="1266",read_only=true,actuation_enabled=false}
local DoctrineMap=require("scripts.core.doctrine_map")
local function valid(e)return e and e.valid==true end
local function point(p)
 if not(p and type(p.x)=="number"and type(p.y)=="number")then return nil end
 return{x=p.x,y=p.y}
end
local function ref(e)
 if not(valid(e)and type(e.unit_number)=="number"and point(e.position))then return nil end
 return{unit=e.unit_number,name=e.name,position=point(e.position)}
end
local function station(pair)
 return pair and valid(pair.station)and ref(pair.station)
end
local function same_scope(pair,e)
 return valid(e)and valid(pair.station)
  and e.force==pair.station.force and e.surface==pair.station.surface
end
local function block(reason)return nil,reason end

function M.doctrine_profile(key)
 if key==nil then return nil,"no-explicit-engineering-doctrine"end
 local camp=type(key)=="string"and DoctrineMap.by_key[key]or nil
 if not camp then return nil,"unknown-engineering-doctrine"end
 return{key=camp.key,name=camp.display_name,style=camp.factorio_style,
  role="advisory-planning-classification-only",
  physical_authority=false},nil
end

-- Recipe nodes are abstract: NEVER manufacture an endpoint from their
-- machine NAME or a ghost. These outputs are unfulfilled obligations only.
function M.recipe_requirements(pair,plan,doctrine_key)
 local home=station(pair)
 if not home then return block("unverified-station-identity")end
 if type(plan)~="table"or type(plan.nodes)~="table"
    or plan.owner_station_unit~=home.unit then
  return block("missing-or-foreign-arterial-plan")
 end
 local profile,why=M.doctrine_profile(doctrine_key)
 if doctrine_key~=nil and not profile then return block(why)end
 local demands,fluid_delegated={},0
 for i,node in ipairs(plan.nodes)do
  if type(node)=="table"and node.kind=="recipe"then
   for _,ingredient in ipairs(node.ingredients or{})do
    if type(ingredient)=="table"and type(ingredient.name)=="string"
       and ingredient.name~=""and tonumber(ingredient.amount)
       and tonumber(ingredient.amount)>0 then
     if ingredient.type=="fluid"then
      fluid_delegated=fluid_delegated+1
     elseif ingredient.type==nil or ingredient.type=="item"then
      demands[#demands+1]={version=M.version,item=ingredient.name,
       item_type="item",required_amount=tonumber(ingredient.amount),
       consumer_recipe=node.recipe,
       consumer_node=i,owner_station_unit=home.unit,
       status="physical-source-and-sink-unresolved",
       doctrine_key=profile and profile.key or nil,
       physical_transport_verified=false}
     end
    end
   end
  end
 end
 return{version=M.version,owner_station_unit=home.unit,
  status="requirements-only",read_only=true,
  physical_transport_verified=false,
  demands=demands,fluid_requirements_delegated=fluid_delegated,
  doctrine_key=profile and profile.key or nil},nil
end

-- Endpoints are actual native entities, not prototype names, ghosts or
-- machine icons. This is deliberately NOT a route or a construction order.
function M.demand(pair,spec)
 local home=station(pair)
 if not home then return block("unverified-station-identity")end
 if type(spec)~="table"then return block("invalid-demand")end
 local item=spec.item
 if type(item)~="string"or item==""then return block("item-not-specified")end
 local fluid=prototypes and prototypes.fluid and prototypes.fluid[item]
 local item_proto=prototypes and prototypes.item and prototypes.item[item]
 if not item_proto then
  return block(fluid and"fluid-requires-existing-fluid-planner"
    or"native-item-prototype-unavailable")
 end
 local rate=tonumber(spec.rate_per_min)
 if not(rate and rate>0 and rate<100000000)then
  return block("positive-material-rate-required")
 end
 local source,sink=spec.source,spec.sink
 local a,b=ref(source),ref(sink)
 if not(a and b)then return block("physical-source-or-sink-unresolved")end
 if not(same_scope(pair,source)and same_scope(pair,sink))then
  return block("foreign-surface-or-force")
 end
 if a.unit==b.unit then return block("identical-transport-endpoints")end
 local profile,why=M.doctrine_profile(spec.doctrine_key)
 if spec.doctrine_key~=nil and not profile then return block(why)end
 local quality=spec.quality
 if quality~=nil then
  if type(quality)~="string"or not(prototypes and prototypes.quality
      and prototypes.quality[quality])then
   return block("quality-prototype-unavailable")
  end
 end
 return{version=M.version,read_only=true,
  owner_station_unit=home.unit,source=a,sink=b,item=item,
  rate_per_min=rate,quality=quality,
  doctrine_key=profile and profile.key or nil,
  status="requires-native-route-preflight",
  physical_transport_verified=false,
  construction_authorized=false,
  custody_acquired=false},nil
end

-- Native belt lane observations: a stationary item does not prove that
-- any particular source produced it or any sink received it.
function M.inspect_belt(entity,item)
 if not valid(entity)then return block("invalid-belt")end
 local kind=entity.type
 local accepted={["transport-belt"]=true,["underground-belt"]=true,
   splitter=true,loader=true,["loader-1x1"]=true,["linked-belt"]=true}
 if not accepted[kind]then return block("not-a-belt-connectable")end
 if type(entity.get_max_transport_line_index)~="function"
   or type(entity.get_transport_line)~="function"then
  return block("native-transport-line-query-unavailable")
 end
 local ok,n=pcall(function()return entity.get_max_transport_line_index()end)
 if not(ok and type(n)=="number"and n>=1 and n<=32)then
  return block("native-transport-line-count-unobservable")
 end
 local observed,total={},0
 for index=1,n do
  local read,line=pcall(function()return entity.get_transport_line(index)end)
  if not(read and line and type(line.get_item_count)=="function")then
   return block("native-transport-line-unobservable:"..index)
  end
  local counted,count=pcall(function()return line.get_item_count(item)end)
  if not(counted and type(count)=="number"and count>=0)then
   return block("native-transport-items-unobservable:"..index)
  end
  observed[index]=count;total=total+count
 end
 return{version=M.version,entity=ref(entity),read_only=true,
  item=item,lines=observed,item_count=total,
  status="native-belt-items-observed",
  physical_transport_verified=false},nil
end

-- After placement, the engine decides the real pickup/drop geometry. This
-- never edits inserter vectors/filters or assumes a working transfer.
function M.inspect_inserter(entity)
 if not(valid(entity)and entity.type=="inserter")then
  return block("not-a-valid-physical-inserter")
 end
 local pickup,drop,target_in,target_out
 pcall(function()pickup=point(entity.pickup_position)end)
 pcall(function()drop=point(entity.drop_position)end)
 pcall(function()target_in=ref(entity.pickup_target)end)
 pcall(function()target_out=ref(entity.drop_target)end)
 if not(pickup and drop)then return block("native-inserter-geometry-unobservable")end
 return{version=M.version,entity=ref(entity),pickup_position=pickup,
  drop_position=drop,pickup_target=target_in,drop_target=target_out,
  read_only=true,status="native-inserter-geometry-observed",
  physical_transport_verified=false},nil
end
return M
