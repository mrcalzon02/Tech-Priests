-- Conditional terrestrial water-route planning. Only original 0338 submits
-- a scoped tree dependency; original 0513 must mine and return real wood.
local Steam=require("scripts.core.steam_outlet_reorientation_1288")
local M={}
local function valid(e)return e and e.valid end
local function d2(a,b)return(a.x-b.x)^2+(a.y-b.y)^2 end
function M.tree_at(p,point)
 local ok,trees=pcall(function()return p.station.surface.find_entities_filtered{
  area={{point.x-.3,point.y-.3},{point.x+.3,point.y+.3}},type="tree",force="neutral",limit=4}end)
 if not ok then return nil end
 for _,tree in pairs(trees)do
  local safe,wood=pcall(function()
   if not(valid(tree)and tree.type=="tree"and tree.force.name=="neutral"and tree.minable~=false)then return false end
   local found=false
   for _,v in pairs(tree.prototype.mineable_properties.products or{})do
    if v.type=="fluid"or v.name~="wood"then return false end
    found=true
   end
   return found
  end)
  if safe and wood and Steam.ignorable_tree_tile(p,point,tree)then return tree end
 end
end
function M.context(p,proposal)
 local a=proposal and proposal.machine;local b=proposal and proposal.source and proposal.source.entity
 return p and valid(p.station)and valid(p.priest)and not p.station.surface.platform
  and proposal.direction=="input"and proposal.fluid=="water"
  and valid(a)and a.type=="boiler"and a.name=="boiler"and a.surface==p.station.surface and a.force==p.station.force
  and valid(b)and b.type=="offshore-pump"and b.name=="offshore-pump"and b.surface==a.surface and b.force==a.force
end
local function funded(p,n)
 local authority=rawget(_G,"TechPriestsStorageRoleAuthority0686")
 local ok,count=pcall(function()return authority.generic_item_count(p,"pipe")end)
 return ok and type(count)=="number"and count>=n and n>0
end
function M.admitted(p,proposal)
 local t=p and p.emergency_craft
 return M.context(p,proposal)and Steam.idle_owner(p)and type(t)=="table"
  and t.strict_recipe_0647==true and t.facility_only_0647==true and t.infrastructure_first_0640==true and funded(p,1)
end
-- Bounded A*; a native tree costs more than any permitted pipe detour.
-- Tree count is a state dimension so a short clearable route is not lost
-- behind a longer dead end. No hypothetical route authorizes any mutation.
function M.search(start,goal,available)
 local heap,best={},{};local cache={};local nodes=0
 local x0,x1=math.min(start.x,goal.x)-8,math.max(start.x,goal.x)+8
 local y0,y1=math.min(start.y,goal.y)-8,math.max(start.y,goal.y)+8
 local function push(v)
  heap[#heap+1]=v;local i=#heap
  while i>1 do local j=math.floor(i/2);if heap[j].score<=v.score then break end;heap[i]=heap[j];i=j end;heap[i]=v
 end
 local function pop()
  local out=heap[1];local last=table.remove(heap)
  if #heap>0 then local i=1
   while i*2<=#heap do local j=i*2;if j<#heap and heap[j+1].score<heap[j].score then j=j+1 end
    if heap[j].score>=last.score then break end;heap[i]=heap[j];i=j end;heap[i]=last
  end
  return out
 end
 local function key(q,n)return q.x..":"..q.y..":"..n end
 local first={position=start,steps=0,trees=0,score=math.abs(start.x-goal.x)+math.abs(start.y-goal.y)}
 first.key=key(start,0);best[first.key]=0;push(first)
 while #heap>0 and nodes<2048 do
  local v=pop()
  if best[v.key]==v.steps then
   nodes=nodes+1
   if d2(v.position,goal)<.01 then
    local route,trees={}, {};local at=v
    while at do table.insert(route,1,at.position)
     if at.tree then
      local seen=false;for _,entry in ipairs(trees)do if entry.tree==at.tree then seen=true;break end end
      if not seen then table.insert(trees,1,{tree=at.tree,position=at.position})end
     end
     at=at.parent
    end
    if #trees>0 and #route<=48 then return route,trees,v.score end
    return nil
   end
   if v.steps<47 then for _,d in ipairs{{1,0},{-1,0},{0,1},{0,-1}}do
    local q={x=v.position.x+d[1],y=v.position.y+d[2]}
    if q.x>=x0 and q.x<=x1 and q.y>=y0 and q.y<=y1 then
     local ck=key(q,0);local c=cache[ck]
     if not c then local allowed,_,tree=available(q);c={allowed=allowed,tree=tree};cache[ck]=c end
     local n=v.trees+(c.tree and 1 or 0);local k=key(q,n);local steps=v.steps+1
     if c.allowed and n<=8 and(not best[k]or steps<best[k])then
      best[k]=steps;push{position=q,key=k,steps=steps,trees=n,tree=c.tree,parent=v,
       score=n*100+steps+math.abs(q.x-goal.x)+math.abs(q.y-goal.y)}
     end
    end
   end end
  end
 end
end
function M.propose(p,proposal,plan,route,trees,new_count)
 if not(M.admitted(p,proposal)and trees and trees[1]and funded(p,new_count))then return nil end
 local old=p.native_fluid_tree_clearance_1298
 if old and M.valid_request(p,old)then return old end
 local r={proposal=proposal,plan=plan,route=route,trees=trees,tree=trees[1].tree,position=trees[1].position,
  pipe_count=new_count,parent_recipe=p.emergency_craft,expires_tick=game.tick+1800,
  machine_direction=proposal.machine.direction,source_direction=proposal.source.entity.direction}
 p.native_fluid_tree_clearance_1298=r;return r
end
local function retained(p,r)
 return r and r==p.native_fluid_tree_clearance_1298 and M.context(p,r.proposal)
  and r.parent_recipe==p.emergency_craft and r.proposal.machine.direction==r.machine_direction
  and r.proposal.source.entity.direction==r.source_direction
end
function M.valid_request(p,r,child)
 return retained(p,r)and r.expires_tick>=game.tick and Steam.idle_owner(p,child)
  and valid(r.tree)and M.tree_at(p,r.position)==r.tree and funded(p,r.pipe_count)
end
function M.authorized_child(p,r,child)
 local c=p.construction_source_clearance_1285
 local o=p.order_queue_0469 and p.order_queue_0469.current or p.active_order_0469
 if not(retained(p,r)and c and c.kind=="fluid-route-clearance-1298"and c.parent==r and c.child==child
  and child==p.direct_acquisition_task_0336 and child.current and child.current.entity==r.tree
  and child.construction_source_clearance_1285 and o and o.status=="active"and o.task==child
  and o.source=="construction-source-clearance-0338")then return false end
 if valid(r.tree)then return Steam.idle_owner(p,child)and M.tree_at(p,r.position)==r.tree end
 local cargo=p.direct_acquisition_custody_0513
 return cargo and cargo.item=="wood"and(tonumber(cargo.count)or 0)>0
  and cargo.native_inventory and cargo.native_inventory.valid or false
end
return M
