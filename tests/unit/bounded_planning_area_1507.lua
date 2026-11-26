package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local Area=require("scripts.core.bounded_planning_area_1507")
local function check(v,message) assert(v,"bounded-area: "..message) end
game={tick=50};storage={tech_priests={}}
local force={valid=true,index=1,name="player",object_name="LuaForce"}
local neutral={valid=true,index=3,name="neutral",object_name="LuaForce"}
local surface={valid=true,index=1,object_name="LuaSurface"}
local pair={station={valid=true,object_name="LuaEntity",unit_number=1,force=force,surface=surface,position={x=0,y=0}},priest={valid=true,object_name="LuaEntity"}}
local entities={}
for i=1,45 do entities[#entities+1]={valid=true,object_name="LuaEntity",type="furnace",name="stone-furnace",unit_number=100+i,force=force,surface=surface,position={x=(i%9)*2+0.5,y=math.floor(i/9)*2+0.5}} end
local ore={valid=true,object_name="LuaEntity",type="resource",name="iron-ore",unit_number=999,force=neutral,surface=surface,position={x=3,y=3}}
entities[#entities+1]=ore
local queries=0
surface.find_entities_filtered=function(q)
  queries=queries+1;check(q.limit==16 and q.area,"query had no small cap")
  local types={};for _,t in ipairs(q.type) do types[t]=true end
  local out={};local a,b=q.area[1],q.area[2]
  for _,e in ipairs(entities) do
    if e.valid and types[e.type] and (not q.force or e.force==q.force) and e.position.x>=a[1] and e.position.x<b[1] and e.position.y>=a[2] and e.position.y<b[2] then
      out[#out+1]=e;if #out>=q.limit then break end
    end
  end
  return out
end
local function copy(v,seen)
  if type(v)~="table" or v.object_name then return v end
  seen=seen or {};if seen[v] then return seen[v] end;local out={};seen[v]=out
  for k,x in pairs(v) do check(type(x)~="function" and type(x)~="thread","saved iterator/closure");out[copy(k,seen)]=copy(x,seen) end
  return out
end
local function drain(s)
  local seen={};local count=0
  for i=1,10000 do
    local before=queries;game.tick=game.tick+1;local r=Area.step(s)
    check(r.processed==1 and queries-before<=1,"a step hid a multi-query scan")
    if r.entity then check(not seen[r.entity.unit_number],"duplicate yielded");seen[r.entity.unit_number]=true;count=count+1 end
    if r.done then check(not r.stale,"fresh scan failed:"..tostring(r.reason));return count,seen end
  end
  error("area did not finish")
end
-- Cold saturation subdivides and charges every returned candidate. Reload
-- midway through a native result keeps progress, dedup and query bounds.
local s=assert(Area.begin(pair,25,{"furnace"}))
for _=1,7 do game.tick=game.tick+1;Area.step(s) end
s=copy(s);storage=copy(storage)
package.loaded["scripts.core.bounded_planning_area_1507"]=nil;Area=require("scripts.core.bounded_planning_area_1507")
local count=drain(s)
check(count==45 and s.work>45 and queries>4,"saturated discovery lost entities or bypassed candidate accounting")
check(Area.current(s),"finished fresh view became stale")
local unrelated={valid=true,force=force,surface=surface,position={x=4000,y=4000}}
Area.note_entity({entity=unrelated});check(Area.current(s),"unrelated world edit invalidated this area")
Area.note_entity({entity=entities[1]});check(not Area.current(s),"new local obstruction remained fresh after completed cell pass")
local rejected=Area.validate(s);check(rejected.done and rejected.stale,"late edit was reused")
-- Neutral resources are supported without granting another force's inventory.
local resources=assert(Area.begin(pair,25,{"resource"},{force_policy="any"}))
local resource_count,found=drain(resources)
check(resource_count==1 and found[999],"native neutral resource was filtered out")
-- Warm raw cells require no filtered/copying catalog call. Invalid, duplicate,
-- foreign and irrelevant retained rows still consume separate work steps.
local cells={}
for x=-1,0 do for y=-1,0 do cells[x..":"..y]={known_tick=game.tick,entities={}} end end
cells["0:0"].entities={first=entities[1],duplicate=entities[1],ore=ore,invalid={valid=false},foreign={valid=true,type="furnace",name="stone-furnace",unit_number=998,force=neutral,surface=surface,position={x=2,y=2}}}
storage.tech_priests.efficiency_economy_0579={surfaces={["1"]={cells=cells,dirty={}}}}
local warm=Area.begin(pair,20,{"furnace"});local before=queries
local n=drain(warm)
check(n==1 and queries==before and warm.work>=5,"raw retained row accounting/filtering failed")
-- Explicit bounded cell revalidation catches ownership replacing a raw index
-- even if a compatibility provider omitted its usual entity event.
cells["0:0"].entities={}
local validation
for _=1,20 do validation=Area.validate(warm);if validation.done then break end end
check(validation and validation.stale,"replaced cell membership escaped final validation")
local tile=Area.begin(pair,20,{"furnace"});Area.note_tiles({surface_index=1,tiles={}})
check(not Area.current(tile),"tile event did not invalidate planning observation")
print("[bounded-planning-area-1507] PASS capped cold subdivision, every candidate charged, reload, raw retained membership, neutral resources, late local edits and unrelated-region reuse")
