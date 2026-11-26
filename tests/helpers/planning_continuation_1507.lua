-- Native-shaped fixture helpers for the public asynchronous planner callers.
-- Tests retain their doctrine assertions; only scheduling/engine shapes live here.
local M={}
function M.pulse(budget)
  local Q=require("scripts.core.force_planning_queue")
  game.tick=game.tick+1
  local offered=budget or 16
  local out=Q.pulse({tick=game.tick},offered)
  assert(out.processed<=offered,"planner exceeded offered work")
  return out
end
function M.plan(owner,pair,reason,limit)
  local pending=false
  for _=1,limit or 30000 do
    local plan,why=owner.build_plan(pair,reason)
    if plan then return plan end
    assert(why=="planning-pending" or why=="planning-queue-full",
      "unexpected plan result: "..tostring(why))
    pending=true;M.pulse()
    local Q=require("scripts.core.force_planning_queue")
    local j=Q.peek(pair.station.force.index,"infrastructure-survey",tostring(pair.station.unit_number))
    assert(not(j and j.error),j and j.error)
  end
  error("planner did not finish "..tostring(reason).." pending="..tostring(pending))
end
function M.service(owner,pair,reason,limit)
  for _=1,limit or 30000 do
    local ok,why=owner.service_pair(pair,reason)
    if ok then return ok,why end
    assert(why=="planning-pending" or why=="planning-queue-full",
      "unexpected service result: "..tostring(why))
    M.pulse()
  end
  error("planner service did not finish: "..tostring(reason))
end
function M.ghost(owner,pair,reason,limit)
  for _=1,limit or 30000 do
    local ok,why=owner.service_pair(pair,reason)
    if ok or type(why)~="string" or not(why:find("placement-pending",1,true)==1 or why:find("planning-pending",1,true)==1) then return ok,why end
    M.pulse()
  end
  error("ghost caller did not settle: "..tostring(reason))
end
function M.discover(owner,pair,force,limit)
  for _=1,limit or 30000 do
    local candidate=owner.discover_pair(pair,force)
    if candidate then return candidate end
    local why=pair.construction_pending_0359
    if type(why)~="string" or why:sub(1,17)~="placement-pending"then return nil end
    M.pulse()
  end
  error("construction discovery did not settle")
end
function M.construct(owner,pair,reason,limit)
  for _=1,limit or 30000 do
    local result=owner.service_pair(pair,reason)
    local why=result and result.detail
    if why=="no-candidate"then why=pair.construction_pending_0359 end
    if type(why)~="string"or why:sub(1,17)~="placement-pending"then return result end
    M.pulse()
  end
  error("physical construction admission did not settle: "..tostring(reason))
end
function M.wrap_queries(surface,force)
  local original=surface.find_entities_filtered
  surface.find_entities_filtered=function(query)
    return M.query(original(query) or {},query,surface,force)
  end
end
function M.ordered(map,order,on_start,on_visit)
  local positions={}
  for i,key in ipairs(order) do positions[key]=i end
  return setmetatable(map,{__pairs=function(t)
    if on_start then on_start() end
    return function(_,key)
      local index=key and (assert(positions[key],"unknown saved registry key")+1) or 1
      local name=order[index]
      if name then if on_visit then on_visit(name) end;return name,t[name] end
    end,t,nil
  end})
end
function M.query(entities,query,surface,default_force)
  local types={}
  if type(query.type)=="table" then for _,kind in ipairs(query.type) do types[kind]=true end
  elseif query.type then types[query.type]=true end
  local names={}
  if type(query.name)=="table" then for _,name in ipairs(query.name) do names[name]=true end
  elseif query.name then names[query.name]=true end
  local out={}
  for _,entity in ipairs(entities) do
    -- Old fixtures omitted native domain fields; supply them explicitly from
    -- the fixture's declared surface/force without altering physical stock.
    if entity.surface==nil then entity.surface=surface end
    if entity.force==nil then entity.force=default_force end
    local p=entity.position
    local inside=p~=nil
    if inside and query.area then
      local a,b=query.area[1],query.area[2]
      inside=p.x>=(a.x or a[1]) and p.x<(b.x or b[1]) and p.y>=(a.y or a[2]) and p.y<(b.y or b[2])
    elseif inside and query.position and query.radius then
      local dx,dy=p.x-query.position.x,p.y-query.position.y
      inside=dx*dx+dy*dy<=query.radius*query.radius
    end
    if entity.valid and inside and (not query.type or types[entity.type])
      and (not query.name or names[entity.name]) and (not query.force or query.force==entity.force) then
      out[#out+1]=entity
      if query.limit and #out>=query.limit then break end
    end
  end
  return out
end
return M
