-- Fine-grained 0644 survey. Selection is the existing doctrine; this module
-- supplies it with incrementally observed world/recipe/inventory inputs.
local Q=require("scripts.core.force_planning_queue")
local Metadata=require("scripts.core.planning_metadata_1507")
local Area=require("scripts.core.bounded_planning_area_1507")
local M={}
local callbacks={}
local TYPES={"resource","mining-drill","furnace","assembling-machine","container",
  "logistic-container","lab","inserter","transport-belt","underground-belt","splitter",
  "car","spider-vehicle"}
local RECEIVER={container=true,["logistic-container"]=true,["transport-belt"]=true,
  ["underground-belt"]=true,splitter=true,furnace=true,["assembling-machine"]=true}
local PRIORITY={["iron-ore"]=10,["copper-ore"]=20,coal=30,stone=40,["uranium-ore"]=90}
local function now()return game and game.tick or 0 end
local function valid(e)return e and e.valid end
local function distance(a,b)local x,y=a.x-b.x,a.y-b.y;return x*x+y*y end
local function done(value)return{processed=1,done=true,result=value}end
local function more()return{processed=1}end
local function pairs_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function pair_for(job)
  local p=job.payload;local pair=pairs_map()[p.station_unit] or pairs_map()[tostring(p.station_unit)]
  if not(pair and valid(pair.station)and valid(pair.priest))then return nil end
  local e=pair.station
  if e~=p.station or pair.priest~=p.priest or e.force~=p.force or e.surface~=p.surface
    or e.position.x~=p.x or e.position.y~=p.y or callbacks.radius(pair)~=p.radius then return nil end
  return pair
end
local function inventory(e,kind)
  if not(valid(e)and e.get_inventory and kind)then return nil end
  local ok,inv=pcall(e.get_inventory,kind)
  return ok and inv and inv.valid and inv or nil
end
local function inventory_id(e)
  local ids=defines and defines.inventory or{}
  if e.type=="car"then return ids.car_trunk end
  if e.type=="spider-vehicle"then return ids.spider_trunk end
  if e.type=="container"or e.type=="logistic-container"then return ids.chest end
end
local function begin_stock(s,item,return_phase,science)
  s.stock={item=item,index=1,total=0,return_phase=return_phase,science=science}
  s.phase="stock"
end
local function stock_step(s,pair)
  local q=s.stock;local source=s.sources[q.index]
  if not source and q.science then source=s.labs[q.index-#s.sources]end
  if not source then
    local counts=q.science and s.science_counts or s.counts
    counts[q.item]=q.total;s.phase=q.return_phase;s.stock=nil;return more()
  end
  q.index=q.index+1
  if valid(source) and source.surface==pair.station.surface and source.force==pair.station.force
    and distance(source.position,pair.station.position)<=s.stock_radius*s.stock_radius then
    local authority=rawget(_G,"TechPriestsStorageRoleAuthority0686")
    local waste=authority and authority.role_for and authority.role_for(source)=="waste"
    if not waste then
      local id=source.type=="lab" and (defines.inventory or{}).lab_input or inventory_id(source)
      local inv=inventory(source,id)
      if inv then q.total=q.total+(tonumber(inv.get_item_count(q.item))or 0)end
    end
  end
  return more()
end
local function world_entity(s,pair,e)
  if not(valid(e)and e.position and e.surface==pair.station.surface)then return end
  local identity=e.unit_number or(e.name..":"..e.position.x..":"..e.position.y)
  if s.seen[identity]then return end;s.seen[identity]=true
  local d=distance(e.position,pair.station.position)
  if e.type=="resource"then
    if d<=s.radius*s.radius and (not e.amount or e.amount>0)then
      local name=e.name;local rec=s.resources[name]or{name=name,count=0,amount=0}
      rec.count,rec.amount=rec.count+1,rec.amount+(tonumber(e.amount)or 0);s.resources[name]=rec
      local first=s.resources.__first
      if not first or(PRIORITY[name]or 1000)<(PRIORITY[first]or 1000)
        or((PRIORITY[name]or 1000)==(PRIORITY[first]or 1000)and name<first)then s.resources.__first=name end
    end
    return
  end
  if e.force~=pair.station.force then return end
  if e~=pair.station and d<=s.stock_radius*s.stock_radius and inventory_id(e)and #s.sources<257 then
    s.sources[#s.sources+1]=e
  end
  if d>s.radius*s.radius then return end
  if e~=pair.station then local role=callbacks.role(e);if role then s.roles[role]=(s.roles[role]or 0)+1 end end
  if e.type=="lab"then s.labs[#s.labs+1]=e end
  if e.type=="mining-drill"then s.drills[#s.drills+1]=e end
  if RECEIVER[e.type]then
    local key=math.floor(e.position.x)..":"..math.floor(e.position.y)
    local bucket=s.receivers[key]or{};s.receivers[key]=bucket;bucket[#bucket+1]=e
  end
end
local function feasible_step(s,pair)
  local f=s.feasible;local item=f.item
  if s.counts[item]==nil then begin_stock(s,item,"feasible");return more()end
  if s.counts[item]>0 then
    s.counts.__feasibility[item]={true,"stocked"};s.feasible=nil;s.phase=f.return_phase;return more()
  end
  if not Metadata.ready(pair.station.force)then return more()end
  if not f.phase then f.phase="unlock";f.index=1 end
  local recipes=pair.station.force.recipes or{}
  if f.phase=="unlock"then
    local names=Metadata.recipe_names(pair.station.force,item,false)
    local name=names[f.index];f.index=f.index+1
    if not name then
      s.counts.__feasibility[item]={false,"technology-locked-or-no-recipe"}
      s.feasible=nil;s.phase=f.return_phase
    elseif recipes[name]and recipes[name].enabled then f.phase="recipe";f.index=1 end
    return more()
  end
  if f.phase=="recipe"then
    local names=Metadata.recipe_names(pair.station.force,item,true)
    local name=names[f.index];f.index=f.index+1
    if not name then
      s.counts.__feasibility[item]={false,"recipe-unavailable"};s.feasible=nil;s.phase=f.return_phase
    elseif recipes[name]and recipes[name].enabled then
      f.recipe=name;f.ingredients=recipes[name].ingredients or{};f.ingredient=1;f.missing="";f.ok=true;f.phase="ingredients"
    end
    return more()
  end
  local ingredient=f.ingredients[f.ingredient]
  if not ingredient then
    -- Recipe availability is mutable while this job is suspended.
    if not(recipes[f.recipe]and recipes[f.recipe].enabled)then f.phase=nil;return more()end
    s.counts.__feasibility[item]={f.ok,f.ok and "ingredients-stocked"or("missing-ingredients:"..f.missing)}
    s.feasible=nil;s.phase=f.return_phase;return more()
  end
  local name=ingredient.name or ingredient[1]
  if ingredient.type~="fluid"and s.counts[name]==nil then begin_stock(s,name,"feasible");return more()end
  if ingredient.type=="fluid"or s.counts[name]<(ingredient.amount or ingredient[2]or 1)then
    f.ok=false;f.missing=f.missing..(f.missing==""and""or",")..(ingredient.type=="fluid"and"fluid:"or"")..name
  end
  f.ingredient=f.ingredient+1;return more()
end
local function ask_choose(s,pair)
  local ok,target=pcall(callbacks.choose,pair,s.resources,s.roles,{},s.counts)
  if ok then s.target=target;s.phase=s.final and "validate-science" or "science-next";return more()end
  if type(target)~="table"then error(target)end
  if target.need=="stock"then begin_stock(s,target.item,"choose")
  elseif target.need=="feasibility"then s.feasible={item=target.item,return_phase="choose"};s.phase="feasible"
  else error("unsupported infrastructure continuation request")end
  return more()
end
local function output_current(pair,witness)
  if not witness then return false end
  local drill=witness.entity
  if not(valid(drill) and drill.force==pair.station.force and drill.surface==pair.station.surface
    and drill.position.x==witness.x and drill.position.y==witness.y)then return false end
  local drop=drill.drop_position
  return drop and drop.x==witness.drop.x and drop.y==witness.drop.y
    and not valid(drill.drop_target)
end
local function output_witness(d)
  return {entity=d.entity,x=d.x,y=d.y,drop={x=d.drop.x,y=d.drop.y},
    position={x=d.position.x,y=d.position.y}}
end
local function drill_step(s,pair)
  if not s.drill then
    local e=s.drills[s.drill_index];s.drill_index=s.drill_index+1
    if not e then s.phase="choose";return more()end
    if not valid(e)then return more()end
    local drop,target=e.drop_position,e.drop_target
    if drop and not valid(target)then
      s.drill={entity=e,x=e.position.x,y=e.position.y,
        drop={x=drop.x,y=drop.y},position={x=math.floor(drop.x)+.5,y=math.floor(drop.y)+.5},
        cell=1,index=1,distance=distance(e.position,pair.station.position)}
    end
    return more()
  end
  local d=s.drill
  if not output_current(pair,d)then return done({stale=true,reason="drill-output-changed"})end
  if d.cell<=9 then
    local x=math.floor(d.drop.x)+((d.cell-1)%3)-1
    local y=math.floor(d.drop.y)+math.floor((d.cell-1)/3)-1
    local bucket=s.receivers[x..":"..y]or{};local e=bucket[d.index]
    if not e then d.cell=d.cell+1;d.index=1
    else d.index=d.index+1;if valid(e)and distance(e.position,d.drop)<1 then s.drill=nil end end
    return more()
  end
  if not d.item then
    local ok,item=pcall(callbacks.receiver_item,pair,s.counts)
    if ok then d.item=item
    elseif type(item)=="table"and item.need=="stock"then begin_stock(s,item.item,"drills")
    elseif type(item)=="table"and item.need=="feasibility"then s.feasible={item=item.item,return_phase="drills"};s.phase="feasible"
    else error(item)end
    return more()
  end
  local policy=rawget(_G,"TechPriestsPlanningConstraints0646")
  local inside=not policy or not policy.interior_position_allowed or policy.interior_position_allowed(pair,d.position)
  local legal=inside and (not pair.station.surface.can_place_entity
    or pair.station.surface.can_place_entity{name=d.item,position=d.position,force=pair.station.force})
  local output=s.counts.__output
  if legal then
    if not output.distance or d.distance<output.distance then
      output.position=d.position;output.drill=d.entity;output.distance=d.distance
      output.witness=output_witness(d)
    end
  elseif not output.deferred_distance or d.distance<output.deferred_distance then
    output.deferred_distance=d.distance
    output.deferred={position=d.position,drill_unit=d.entity.unit_number,
      reason=inside and"fixed-drill-output-position-blocked"or"fixed-drill-output-outside-authority"}
    output.deferred_witness=output_witness(d)
  end
  s.drill=nil;return more()
end
local function science_step(s,pair)
  local force=pair.station.force
  if #s.labs==0 then s.phase="refresh-stock";return more()end
  if s.phase=="science-next"then
    local name,t=Metadata.next_entry(force.technologies or{},s.tech_key);s.tech_key=name
    if not name then s.phase="refresh-stock";return more()end
    if t.enabled and not t.researched then s.tech={name=name,phase="prerequisites",packs={},pack_index=1};s.phase="science"end
    return more()
  end
  local t=s.tech;local live=force.technologies[t.name]
  if not(live and live.enabled and not live.researched)then s.phase="science-next";return more()end
  if t.phase=="prerequisites"then
    local k,p=Metadata.next_entry(live.prerequisites or{},t.key);t.key=k
    if not k then t.ingredients=live.research_unit_ingredients or{};t.count=live.research_unit_count or 0;t.phase="ingredients"
    elseif not p.researched then s.phase="science-next"end
    return more()
  end
  if t.phase=="ingredients"then
    local p=t.ingredients[t.pack_index]
    if not p then t.phase="support";t.lab=1;t.pack=1;t.input=1;return more()end
    local item=p.name or p[1];local amount=p.amount or p[2]or 1
    if s.science_counts[item]==nil then begin_stock(s,item,"science",true);return more()end
    if s.science_counts[item]<amount then s.phase="science-next";return more()end
    t.packs[#t.packs+1]={name=item,amount=amount};t.pack_index=t.pack_index+1;return more()
  end
  local lab=s.labs[t.lab]
  if not lab or #t.packs==0 then s.phase="science-next";return more()end
  if not valid(lab)then t.lab=t.lab+1;t.pack=1;t.input=1;return more()end
  local pack=t.packs[t.pack]
  if not pack then
    local score=#t.packs*100000+t.count
    if not s.science or score<s.science.score or(score==s.science.score and t.name<s.science.name)then
      s.science={name=t.name,score=score,unit_count=t.count,packs=t.packs,lab=lab}
    end
    s.phase="science-next";return more()
  end
  local proto=lab.prototype;local inputs=proto and(proto.lab_inputs or proto.inputs)or{}
  local input=inputs[t.input]
  if not input then t.lab=t.lab+1;t.pack=1;t.input=1
  elseif input==pack.name or(type(input)=="table"and input.name==pack.name)then t.pack=t.pack+1;t.input=1
  else t.input=t.input+1 end
  return more()
end
-- Recount only the items used by the complete proposal, one live inventory
-- per visit. No collection of rolling observations is an atomic reservation.
local function refresh_stock(s)
  if not s.final then
    s.final=true;s.counts.__feasibility={};s.refresh_key=nil
  end
  local key=next(s.counts,s.refresh_key);s.refresh_key=key
  if not key then s.phase="choose"
  elseif key:sub(1,2)~="__" then begin_stock(s,key,"refresh-stock") end
  return more()
end
local function validate_science(s,pair)
  local choice=s.science
  if not choice then s.phase="validate-world";return more()end
  local tech=pair.station.force.technologies[choice.name]
  if not(tech and tech.enabled and not tech.researched and valid(choice.lab))then
    s.science=nil;s.phase="validate-world";return more()
  end
  local check=s.science_check or{phase="prerequisites",pack=1};s.science_check=check
  if check.phase=="prerequisites"then
    local key,value=Metadata.next_entry(tech.prerequisites or{},check.key);check.key=key
    if not key then check.phase="packs"
    elseif not value.researched then s.science=nil;s.phase="validate-world"end
    return more()
  end
  local pack=choice.packs[check.pack]
  if not pack then s.phase="validate-world";return more()end
  if not check.reading then
    check.reading=true;begin_stock(s,pack.name,"validate-science",true);return more()
  end
  if (s.science_counts[pack.name]or 0)<pack.amount then s.science=nil;s.phase="validate-world"
  else check.pack=check.pack+1;check.reading=nil end
  return more()
end
local function step(job)
  local pair=pair_for(job)
  if not pair then return done({stale=true,reason="station-domain-changed"})end
  local s=job.state
  if not s.phase then
    s.phase="world";s.radius=job.payload.radius;s.stock_radius=math.max(s.radius,28)
    s.area=Area.begin(pair,s.stock_radius,TYPES,{force_policy="any"});s.started_tick=now()
    s.metadata_epoch=Metadata.epoch()
    s.resources={__first=false};s.roles={};s.receivers={};s.drills={};s.labs={};s.sources={pair.station};s.seen={}
    s.counts={__async=true,__feasibility={},__output={}};s.science_counts={};s.drill_index=1
    Metadata.ready(pair.station.force);return more()
  end
  if s.metadata_epoch~=Metadata.epoch() or not Area.current(s.area)then
    return done({stale=true,reason="world-or-metadata-changed"})
  end
  if s.phase=="world"then
    local out=Area.step(s.area)
    if out.stale then return done({stale=true,reason=out.reason or"world-changed"})end
    if out.entity then world_entity(s,pair,out.entity)end
    if out.done then s.phase="drills"end
    return more()
  elseif s.phase=="stock"then return stock_step(s,pair)
  elseif s.phase=="feasible"then return feasible_step(s,pair)
  elseif s.phase=="drills"then return drill_step(s,pair)
  elseif s.phase=="choose"then return ask_choose(s,pair)
  elseif s.phase=="science-next"or s.phase=="science"then return science_step(s,pair)
  elseif s.phase=="refresh-stock"then return refresh_stock(s)
  elseif s.phase=="validate-science"then return validate_science(s,pair)
  elseif s.phase=="validate-world"then
    local result=Area.validate(s.area)
    if result.stale then return done({stale=true,reason=result.reason})end
    if result.done then s.phase="publish"end
    return more()
  end
  -- Publication remains advisory. It grants no reservation, custody or site.
  -- The physical/ghost callers recheck live stock and placement before action.
  local target=s.target
  if not target then return done({stale=true,reason="no-complete-proposal"})end
  local witness
  if target.site_position then
    local output=s.counts.__output
    local pos=target.site_position
    if output.position and output.position.x==pos.x and output.position.y==pos.y then witness=output.witness
    elseif output.deferred and output.deferred.position.x==pos.x and output.deferred.position.y==pos.y then
      witness=output.deferred_witness
    end
    if not output_current(pair,witness)then return done({stale=true,reason="drill-output-changed"})end
  end
  local plan={version="0.1.678",tick=now(),observed_since=s.started_tick,
    station=job.payload.station_unit,priest=pair.priest.unit_number,radius=s.radius,
    reason=job.payload.reason,resources=s.resources,roles=s.roles,
    resource_summary=s.resources.__first or"none",role_summary="bounded survey",
    target=target,stage=target.stage,status=target.status,blocker=target.blocker,
    surface_index=pair.station.surface.index,force_index=pair.station.force.index,
    station_position={x=pair.station.position.x,y=pair.station.position.y},
    science=s.science,science_reason=s.science and"affordable-research"or"no-affordable-research",
    output_witness=witness,
    metadata_epoch=s.metadata_epoch,
    world_witness={pair=pair,station=pair.station,force=pair.station.force,surface=pair.station.surface,
      surface_index=s.area.surface_index,x=s.area.x,y=s.area.y,
      coverage=s.area.coverage,tile_epoch=s.area.tile_epoch}}
  if s.science then
    local tech=pair.station.force.technologies[s.science.name]
    if valid(s.science.lab)and tech and tech.enabled and not tech.researched then
      plan.research_candidate=s.science.name
      if plan.stage=="ready"then plan.stage="science-ready"end
    end
  end
  pair.master_infrastructure_plan_0644=plan
  return done({plan=plan})
end
Q.register("infrastructure-survey",step)
function M.configure(value)callbacks=value end
function M.current(pair,plan)
  return pair and valid(pair.station)and valid(pair.priest)
    and plan and plan.metadata_epoch==Metadata.epoch()
    and plan.world_witness and plan.world_witness.pair==pair
    and plan.priest==pair.priest.unit_number and plan.radius==callbacks.radius(pair)
    and Area.current(plan.world_witness)
    and (not(plan.target and plan.target.site_position)
      or (plan.output_witness and plan.output_witness.position.x==plan.target.site_position.x
        and plan.output_witness.position.y==plan.target.site_position.y
        and output_current(pair,plan.output_witness)))
end
function M.request(pair,reason)
  if not(pair and valid(pair.station)and valid(pair.priest))then return nil,"invalid-pair"end
  local e=pair.station;local key=tostring(e.unit_number);local force=e.force.index
  local job,status=Q.peek(force,"infrastructure-survey",key)
  if job and not pair_for(job)then Q.forget(force,"infrastructure-survey",key);job=nil end
  if job and status=="ready"then
    local result=job.result;Q.forget(force,"infrastructure-survey",key)
    if result and result.plan and not job.error and M.current(pair,result.plan)then return result.plan,"planned"end
    job=nil
  end
  if not job then
    job,status=Q.submit(force,"infrastructure-survey",key,{station_unit=e.unit_number,
      station=e,priest=pair.priest,force=e.force,surface=e.surface,x=e.position.x,y=e.position.y,
      radius=callbacks.radius(pair),reason=reason or"survey"})
  end
  return nil,status=="queue-full"and"planning-queue-full"or"planning-pending"
end
function M.install()Area.install();Metadata.install();return Q.install()end
return M
