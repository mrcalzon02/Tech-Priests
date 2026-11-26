-- The perimeter executor keeps movement, inventory custody and real builds.
-- This module only proposes work. Each broker visit advances one catalogue
-- entry, wall/slot, native bounded query, returned entity, or search position.
-- No coroutine, iterator function, reservation or timer object is saved.
local Q=require("scripts.core.force_planning_queue")
local Area=require("scripts.core.bounded_planning_area_1507")
local Metadata=require("scripts.core.planning_metadata_1507")
local Territory=require("scripts.core.construction_site_planner")
local M={kind="defense-planning",retry_kind="defense-site-retry",ammo_kind="defense-ammo",live_limit=24}
local A
local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function copy(p) return {x=p.x,y=p.y} end
local function point_key(p) return math.floor(p.x+0.5)..":"..math.floor(p.y+0.5) end
local function root()
  storage.tech_priests=storage.tech_priests or {}
  local r=storage.tech_priests.defense_planning_1507
  if not r then r={};storage.tech_priests.defense_planning_1507=r end
  return r
end
local function pair_live(p)
  local pair=p.pair;local e=pair and pair.station
  return A and A.valid_pair(pair) and e==p.station and e.force==p.force
    and e.surface==p.surface and e.position.x==p.center.x and e.position.y==p.center.y
end
local function outcome(result) return {processed=1,done=true,result=result} end
local function waiting() return {processed=1,waiting=true} end
local function next_map(map,s,field)
  local previous=s[field]
  if previous~=nil and map[previous]==nil then previous=nil end
  local key,value=next(map,previous);s[field]=key
  return key,value
end

-- All station jobs contribute to one immutable catalogue, rather than each
-- rescanning the game's item prototypes or waiting for another ordinary slot.
local preferred={"gun-turret","laser-turret","flamethrower-turret","artillery-turret"}
local function catalog_step()
  local r=root();local epoch=Metadata.epoch();local c=r.catalog
  if not c or c.epoch~=epoch then
    c={epoch=epoch,preferred=1,rows={},seen={}};r.catalog=c
  end
  if c.done then return c.rows end
  local item=preferred[c.preferred]
  if item then
    c.preferred=c.preferred+1
    local entity=A.entity_from_item(item)
    if entity and A.defensive(entity) then
      c.rows[#c.rows+1]={item=item,entity=entity};c.seen[entity]=true
    end
    return nil
  end
  local items=Metadata.item_index()
  if not items then return nil end
  local entity,name=Metadata.next_entry(items,c.key);c.key=entity
  if not entity then c.done=true;return c.rows end
  if not c.seen[entity] and A.defensive(entity) then
    c.rows[#c.rows+1]={item=name,entity=entity};c.seen[entity]=true
  end
  return nil
end

local function ring_begin(center,max_radius,exact,min_radius)
  local r=min_radius or 0
  return {center=copy(center),max=max_radius,r=r,dx=-r,dy=-r,exact=exact}
end
-- Same dx-major/dy-minor perimeter order as the old nested loops, without
-- walking the square's interior for free on every continuation visit.
local function ring_next(c)
  if c.exact then c.exact=nil;c.r=1;c.dx=-1;c.dy=-1;return copy(c.center) end
  if c.r>c.max then return nil end
  local r,dx,dy=c.r,c.dx,c.dy
  local p={x=math.floor(c.center.x)+dx+0.5,y=math.floor(c.center.y)+dy+0.5}
  if r==0 then c.r=1;c.dx=-1;c.dy=-1
  elseif dx==-r or dx==r then
    c.dy=dy+1
    if c.dy>r then c.dx=dx+1;c.dy=-r end
  elseif dy==-r then c.dy=r
  else c.dx=dx+1;c.dy=-r end
  if c.dx>c.r then c.r=c.r+1;c.dx=-c.r;c.dy=-c.r end
  return p
end
local function local_area(pair,center,radius,types)
  -- An immutable geometric anchor is a plain saved table. The real station,
  -- force and priest are checked separately before every broker visit.
  local anchor={valid=true,position=copy(center),surface=pair.station.surface,force=pair.station.force}
  return Area.begin({station=anchor,priest=pair.priest},radius,types)
end
local function admission_begin(pair,position)
  return {position=copy(position),epoch=Territory.territory_epoch(pair),
    radius=Territory.territory_radius(pair),station=pair.station,force=pair.station.force,
    surface=pair.station.surface,center=copy(pair.station.position),phase="local"}
end
local function admission_current(pair,s,position)
  return s and s.approved and valid(pair.station) and pair.station==s.station
    and pair.station.force==s.force and pair.station.surface==s.surface
    and pair.station.position.x==s.center.x and pair.station.position.y==s.center.y
    and Territory.territory_epoch(pair)==s.epoch and Territory.territory_radius(pair)==s.radius
    and position.x==s.position.x and position.y==s.position.y
end
local function admission_step(pair,s)
  if s.epoch~=Territory.territory_epoch(pair) or s.radius~=Territory.territory_radius(pair) then return true,false end
  if s.phase=="local" then
    if not A.allowed(pair,s.position) then return true,false end
    s.phase="neighbor";return false
  end
  local map=storage.tech_priests.pairs_by_station or {}
  local key,other=next_map(map,s,"cursor")
  if not key then s.approved=true;return true,true end
  if other~=pair and other and valid(other.station) and other.station.force==pair.station.force
      and other.station.surface==pair.station.surface then
    local dx,dy=other.station.position.x-s.position.x,other.station.position.y-s.position.y
    local radius=Territory.territory_radius(other)
    if dx*dx+dy*dy<=radius*radius then return true,false end
  end
  return false
end
local function pipe_safety_begin(pair,position)
  return {position=copy(position),planned=A.planned_fluid(pair),proof={},
    area=local_area(pair,position,1.25*math.sqrt(2),{"pipe","pipe-to-ground"})}
end
local function pipe_safety_step(pair,s)
  if s.entity then
    local e=s.entity;local fb=valid(e) and e.fluidbox
    if not fb or s.index>#fb then s.entity=nil;return false end
    local index=s.index;s.index=index+1;local fluid=fb[index]
    local name=fluid and fluid.name or false
    s.proof[#s.proof+1]={entity=e,index=index,name=name}
    if name then
      if s.planned and name~=s.planned or not s.planned and s.first and s.first~=name then return true,false end
      s.first=s.first or name
    end
    return false
  end
  local step=Area.step(s.area)
  if step.stale then return true,false end
  local e=step.entity
  if e and math.abs(e.position.x-s.position.x)<=1.25 and math.abs(e.position.y-s.position.y)<=1.25 then
    local known=A.stored_fluid(e)
    if known and s.planned and known~=s.planned then return true,false end
    local fb=e.fluidbox
    s.proof[#s.proof+1]={entity=e,size=fb and #fb or 0,known=known or false,position=copy(e.position)}
    s.entity=e;s.index=1;s.first=nil
  end
  if step.done then return true,true end
  return false
end
local function pipe_current(pair,scan,proof,planned)
  if not Area.current(scan) or A.planned_fluid(pair)~=planned then return false end
  -- Native pipes have a tiny physical neighborhood, but each live fluidbox
  -- is still charged. A depleted cap retains the proposal instead of giving
  -- a partial safety result permission to take materials.
  for _,rec in ipairs(proof or {}) do
    if not Q.claim_tick("defense-final-check",M.live_limit) then return nil end
    local e=rec.entity
    if not(valid(e) and e.force==pair.station.force and e.surface==pair.station.surface) then return false end
    local fb=e.fluidbox
    if rec.index then
      local fluid=fb and fb[rec.index]
      if (fluid and fluid.name or false)~=rec.name then return false end
    elseif (fb and #fb or 0)~=rec.size or (A.stored_fluid(e) or false)~=rec.known
        or e.position.x~=rec.position.x or e.position.y~=rec.position.y then return false end
  end
  return true
end
local function witness(pair,kind,position,e,entity)
  if not(valid(e) and e.force==pair.station.force and e.surface==pair.station.surface) then return false end
  if kind=="electric" then return A.power_witness(pair,position,e) end
  if kind=="pole" then return A.pole_witness(pair,entity,position,e) end
  if kind=="fluid" then
    return (e.type=="pipe" or e.type=="pipe-to-ground" or e.name=="pipe" or e.name=="pipe-to-ground")
      and math.abs(e.position.x-position.x)<=1.35 and math.abs(e.position.y-position.y)<=1.35
  end
  return true
end
local function site_begin(entity,center,radius,kind)
  kind=kind or A.entity_kind(entity)
  local plain=kind=="ordinary" or kind=="pipe-support"
  return {entity=entity,kind=kind,center=copy(center),radius=radius,
    ring=ring_begin(center,radius,plain),phase=plain and "candidate" or "supports",supports={}}
end
local function site_step(pair,s)
  if s.phase=="supports" then
    local reach=s.kind=="electric" and 24 or (s.kind=="pole" and s.search or 1.35)
    if not s.area then
      s.area=local_area(pair,s.center,math.sqrt(2)*(reach+s.radius),
        s.kind=="fluid" and {"pipe","pipe-to-ground"} or {"electric-pole"})
      return false
    end
    local step=Area.step(s.area)
    if step.stale then s.area=nil;s.supports={};return false end
    if step.entity then s.supports[#s.supports+1]=step.entity end
    if step.done then s.phase="candidate" end
    return false
  elseif s.phase=="candidate" then
    local p=ring_next(s.ring)
    if not p then s.done=true;return true end
    if s.kind=="ordinary" and not A.band_allowed(pair,s.entity,p) then return false end
    if s.kind=="pole" and (math.abs(p.x-s.center.x)>s.supply+0.35
        or math.abs(p.y-s.center.y)>s.supply+0.35) then return false end
    if not A.can_place(pair,s.entity,p) then return false end
    s.position=p;s.authority=admission_begin(pair,p);s.phase="admission"
    return false
  elseif s.phase=="admission" then
    local done,allowed=admission_step(pair,s.authority)
    if not done then return false end
    if not allowed then s.position=nil;s.authority=nil;s.phase="candidate";return false end
    if s.kind=="ordinary" then s.phase="final"
    elseif s.kind=="pipe-support" then s.safety=pipe_safety_begin(pair,s.position);s.phase="pipe-safety"
    else s.cursor=1;s.phase="witness" end
    return false
  elseif s.phase=="pipe-safety" then
    local done,safe=pipe_safety_step(pair,s.safety)
    if done then
      if safe then s.pipe_scan=s.safety.area;s.fluid_proof=s.safety.proof;s.planned_fluid=s.safety.planned;s.phase="final"
      else s.position=nil;s.phase="candidate" end
    end
    return false
  elseif s.phase=="witness" then
    local e=s.supports[s.cursor];s.cursor=s.cursor+1
    if not e then s.position=nil;s.phase="candidate";return false end
    if witness(pair,s.kind,s.position,e,s.entity) then s.witness=e;s.phase="final" end
    return false
  elseif s.phase=="final" then
    -- The selected point can have changed while all the rejected support
    -- candidates were being visited. This is a separately charged live check.
    if not admission_current(pair,s.authority,s.position) or not A.can_place(pair,s.entity,s.position) then
      s.position=nil;s.witness=nil;s.phase="candidate";return false
    end
    if s.kind~="ordinary" and s.kind~="pipe-support" then s.phase="final-witness";return false end
    s.done=true;return true
  elseif s.phase=="final-witness" then
    if not witness(pair,s.kind,s.position,s.witness,s.entity) then
      s.position=nil;s.witness=nil;s.phase="candidate";return false
    end
    s.done=true;return true
  end
end

local function inventory_begin(pair)
  local inv=A.inventory(pair)
  if not(inv and inv.valid) then return {done=true} end
  local ok,size=pcall(function()return #inv end)
  -- Native LuaInventory is visited one slot at a time. Only old lightweight
  -- fixtures lack indexed slots and need the historical contents shape.
  if ok and size>0 then return {inventory=inv,index=1,size=size} end
  return {inventory=inv,contents=inv.get_contents(),key=nil}
end
local function inventory_step(pair,s)
  if s.done then return true,s.ammo end
  if not(s.inventory and s.inventory.valid and s.inventory==A.inventory(pair)) then s.done=true;return true end
  local name,count
  if s.size then
    if s.index>s.size then s.done=true;return true end
    local stack=s.inventory[s.index];s.index=s.index+1
    if stack and stack.valid_for_read then name,count=stack.name,stack.count end
  else
    local key,row=next_map(s.contents or {},s,"key")
    if key==nil then s.done=true;return true end
    if type(row)=="table" then name,count=row.name,row.count
    elseif type(key)=="string" then name,count=key,row end
  end
  local proto=name and A.item_proto(name)
  if proto and proto.type=="ammo" and tonumber(count) and count>0 and A.item_count(pair,name)>0 then
    s.ammo=name;s.done=true;return true,name
  end
  return false
end
local function payload(pair,mode)
  return {pair=pair,station=pair.station,force=pair.station.force,surface=pair.station.surface,
    center=copy(pair.station.position),radius=math.max(8,math.floor(A.radius(pair)-1)),
    epoch=Metadata.epoch(),mode=mode}
end
local function proposal(s,kind,fields)
  local out=fields or {};out.kind=kind;out.threat=s.threat;out.queue_name=s.queue_name
  out.radius=s.radius;out.world=s.world;return outcome(out)
end
local function build_proposal(s,item,entity,position,task_type,key,direction)
  return proposal(s,"build",{item=item,entity=entity,position=position,task_type=task_type,key=key,
    direction=direction,support=s.site and s.site.witness,support_kind=s.site and s.site.kind,
    authority=s.site and s.site.authority,
    responds_to_threat=s.threat and not s.routine or false,
    reason=task_type=="build-turret" and (s.threat and not s.routine and "responding-to-breach-"..(s.site.kind or "ordinary")
      or "placing-mixed-fire-slot-"..tostring(key)) or "placing-perimeter"})
end
local function begin_site(s,entity,position,radius,after)
  s.site=site_begin(entity,position,radius);s.after_site=after;s.phase="site"
end
local function slot_setup(s,rec,mode)
  s.selected=rec;s.slot=1;s.slot_mode=mode
  local range=A.turret_range(rec.entity)
  s.slot_count=math.max(4,math.min(16,math.ceil(2*math.pi*math.max(4,s.radius)/(range*1.5))))
  s.phase="slot"
end
local function threat_same(pair,s)
  if not s.initialized then return true end
  local state=A.state(pair)
  local queue=state.threats and #state.threats>0 and state.threats or state.breaches
  local head=queue and queue[1]
  return head==s.threat and (not head or not s.threat_position
    or head.position.x==s.threat_position.x and head.position.y==s.threat_position.y)
end
local function plan_step(job)
  local p,s=job.payload,job.state
  if not pair_live(p) or p.epoch~=Metadata.epoch() then return outcome({kind="stale"}) end
  local pair,state=p.pair,A.state(p.pair)
  if not A.metadata_ready(pair) then return waiting() end
  if s.territory_epoch and s.territory_epoch~=Territory.territory_epoch(pair) then return outcome({kind="stale"}) end
  if not threat_same(pair,s) then return outcome({kind="stale"}) end
  if not s.phase then
    s.radius=p.radius;s.center=copy(p.center);s.desired={};s.gates={};s.phase="incident"
    s.queue_name=state.threats and #state.threats>0 and "threats" or "breaches"
    s.threat=state[s.queue_name] and state[s.queue_name][1]
    s.threat_position=s.threat and copy(s.threat.position)
    s.world=local_area(pair,p.center,p.radius+100,{"wall"})
    s.territory_epoch=Territory.territory_epoch(pair)
    s.incident=1;s.initialized=true
    return waiting()
  elseif s.phase=="incident" then
    local pending=state.pending_ammo_turret_1507
    if pending and valid(pending) then
      s.ammo_turret=pending;s.inventory=inventory_begin(pair);s.phase="ammo";return waiting()
    end
    local incident=(state.hostile_incidents_0817 or {})[s.incident]
    s.incident=s.incident+1
    if not incident then s.phase=s.threat and "catalog" or "wall-init";return waiting() end
    if incident.needs_ammo and incident.expires_at>now() then s.near_position=copy(incident.defense_position);s.phase="incident-query" end
    return waiting()
  elseif s.phase=="incident-query" then
    s.near=A.turrets_near(pair,s.near_position,9);s.near_index=1;s.phase="incident-turret";return waiting()
  elseif s.phase=="incident-turret" then
    local turret=s.near[s.near_index];s.near_index=s.near_index+1
    if not turret then s.near=nil;s.phase="incident";return waiting() end
    if valid(turret) and turret.type=="ammo-turret" then
      local inv=turret.get_inventory(defines.inventory.turret_ammo)
      if inv and inv.valid and inv.is_empty() then s.ammo_turret=turret;s.inventory=inventory_begin(pair);s.phase="ammo" end
    end
    return waiting()
  elseif s.phase=="ammo" then
    local done,ammo=inventory_step(pair,s.inventory)
    if not done then return waiting() end
    if ammo then return proposal(s,"ammo",{turret=s.ammo_turret,ammo=ammo,reason="remembered-incident-ammo-resupply"}) end
    return proposal(s,"request",{item="firearm-magazine",count=20,request_kind="defense-ammo",reason="awaiting-defense-ammo"})
  elseif s.phase=="catalog" then
    s.candidates=catalog_step()
    if not s.candidates then return waiting() end
    s.candidate=1;s.phase=s.threat and not s.routine and "weapon" or "routine-first";return waiting()
  elseif s.phase=="weapon" then
    local rec=s.candidates[s.candidate];s.candidate=s.candidate+1
    if not rec then
      local selected=s.stocked or s.available or s.unlocked
      if not selected then s.phase="wall-init";return waiting() end
      if s.unsupported then s.selected=s.unsupported;s.phase="support-init";return waiting() end
      s.selected=selected;begin_site(s,selected.entity,s.threat_position,6,"weapon-fallback");return waiting()
    end
    if A.unlocked(pair,rec.entity) then
      s.unlocked=s.unlocked or rec
      local local_stock=A.item_count(pair,rec.item)>0
      if local_stock then s.stocked=s.stocked or rec end
      if local_stock or A.available(pair,rec.item) then
        s.available=s.available or rec;s.selected=rec
        begin_site(s,rec.entity,s.threat_position,6,"weapon")
      end
    end
    return waiting()
  elseif s.phase=="site" then
    if not site_step(pair,s.site) then return waiting() end
    local position=s.site.position;local after=s.after_site
    if position then
      if after=="wall" then return build_proposal(s,s.selected.item,s.selected.entity,position,"build-wall",s.wall_key) end
      if after=="gate" then return build_proposal(s,"gate","gate",position,"build-gate",s.gate_key,s.gate_direction) end
      if after=="slot" and s.slot_mode=="request" then return proposal(s,"request",{item=s.selected.item,count=1,request_kind="defense-turret-ring",reason="awaiting-perimeter-turret"}) end
      if after=="weapon-fallback" and not A.available(pair,s.selected.item) then
        return proposal(s,"request",{item=s.selected.item,count=1,request_kind="defense-turret",reason="requested-"..s.selected.item})
      end
      return build_proposal(s,s.selected.item,s.selected.entity,position,"build-turret",after=="slot" and s.family_key or nil)
    end
    if after=="weapon" then s.unsupported=s.unsupported or s.selected;s.phase="weapon"
    elseif after=="weapon-fallback" then s.phase="support-init"
    elseif after=="wall" then s.phase="missing-wall"
    elseif after=="gate" then s.phase="gate"
    else s.phase="slot" end
    s.site=nil;return waiting()
  elseif s.phase=="support-init" then
    local kind=A.entity_kind(s.selected.entity);s.support_kind=kind
    if kind=="electric" then s.support_index=1;s.phase="support-item"
    elseif kind=="fluid" then s.support_index=1;s.phase="support-pipe"
    else s.phase="wall-init" end
    return waiting()
  elseif s.phase=="support-item" then
    local name=A.power_items[s.support_index];s.support_index=s.support_index+1
    if name then
      local entity=A.entity_from_item(name)
      if entity and A.unlocked(pair,entity) then
        s.support_fallback=s.support_fallback or {item=name,entity=entity}
        if A.available(pair,name) then s.support_item={item=name,entity=entity};s.phase="support-pole-init" end
      end
      return waiting()
    end
    s.support_item=s.support_fallback;s.phase="support-pole-init";return waiting()
  elseif s.phase=="support-pole-init" then
    local rec=s.support_item
    if not rec then s.phase="wall-init";return waiting() end
    local proto=A.entity_proto(rec.entity);local supply=A.pole_range(proto,"get_supply_area_distance");local wire=A.pole_range(proto,"get_max_wire_distance")
    if not(supply and wire) then return proposal(s,"request",{item=rec.item,count=1,request_kind="defense-power-support",reason="requested-power-before-"..s.selected.entity}) end
    s.site=site_begin(rec.entity,s.threat_position,5,"pole");s.site.ring=ring_begin(s.threat_position,5,false,1)
    s.site.supply=supply;s.site.search=math.min(64,math.ceil(wire+8));s.phase="support-pole";return waiting()
  elseif s.phase=="support-pole" then
    if not site_step(pair,s.site) then return waiting() end
    if not s.site.position then return proposal(s,"request",{item=s.support_item.item,count=1,request_kind="defense-power-support",reason="requested-power-before-"..s.selected.entity}) end
    local result=build_proposal(s,s.support_item.item,s.support_item.entity,s.site.position,"build-turret-support")
    result.result.pending_position=copy(s.threat_position);result.result.pending_turret=s.selected.entity
    return result
  elseif s.phase=="support-pipe" then
    local offsets={{1,0},{-1,0},{0,1},{0,-1}};local offset=offsets[s.support_index];s.support_index=s.support_index+1
    if not offset then return proposal(s,"request",{item="pipe",count=2,request_kind="defense-pipe-support",reason="requested-pipe-before-"..s.selected.entity}) end
    local position={x=s.threat_position.x+offset[1],y=s.threat_position.y+offset[2]}
    if A.can_place(pair,"pipe",position) then
      s.pipe_position=position;s.pipe_authority=admission_begin(pair,position);s.phase="support-pipe-admit"
    end
    return waiting()
  elseif s.phase=="support-pipe-admit" then
    local done,allowed=admission_step(pair,s.pipe_authority)
    if done then
      if allowed then s.pipe_safety=pipe_safety_begin(pair,s.pipe_position);s.phase="support-pipe-safety"
      else s.phase="support-pipe" end
    end
    return waiting()
  elseif s.phase=="support-pipe-safety" then
    local done,safe=pipe_safety_step(pair,s.pipe_safety)
    if done and not safe then s.phase="support-pipe";return waiting() end
    if done then
      s.site=nil
      local result=build_proposal(s,"pipe","pipe",s.pipe_position,"build-turret-support")
      result.result.pipe_scan=s.pipe_safety.area;result.result.fluid_proof=s.pipe_safety.proof
      result.result.authority=s.pipe_authority
      result.result.planned_fluid=s.pipe_safety.planned
      result.result.pending_position=copy(s.threat_position);result.result.pending_turret=s.selected.entity
      return result
    end
    return waiting()
  elseif s.phase=="wall-init" then
    if p.mode=="urgent" then return proposal(s,"none",{reason="breach-turret-site-blocked-or-unsupported"}) end
    s.routine=true
    s.wall_count=math.min(96,math.max(12,math.floor(math.max(12,2*math.pi*math.max(4,s.radius))/3)))
    s.wall_index=1;s.gates_unlocked=A.unlocked(pair,"gate");s.phase="wall-point";return waiting()
  elseif s.phase=="wall-point" then
    if s.wall_index>s.wall_count then s.phase="tracked-wall";return waiting() end
    local angle=(s.wall_index-1)*2*math.pi/s.wall_count;s.wall_index=s.wall_index+1
    local pos={x=math.floor(s.center.x+math.cos(angle)*s.radius+0.5)+0.5,y=math.floor(s.center.y+math.sin(angle)*s.radius+0.5)+0.5}
    local gap=false
    if s.gates_unlocked then
      local dx,dy=pos.x-s.center.x,pos.y-s.center.y
      gap=(math.abs(dx)-s.radius)^2+dy*dy<=2.25^2 or dx*dx+(math.abs(dy)-s.radius)^2<=2.25^2
    end
    if not gap and A.allowed(pair,pos) then s.wall_position=pos;s.wall_admission=admission_begin(pair,pos);s.phase="wall-admit" end
    return waiting()
  elseif s.phase=="wall-admit" then
    local done,allowed=admission_step(pair,s.wall_admission)
    if done then
      if allowed then s.desired[point_key(s.wall_position)]=s.wall_position end
      s.phase="wall-point"
    end
    return waiting()
  elseif s.phase=="tracked-wall" then
    local key,rec=next_map(state.walls,s,"tracked_key")
    if key==nil then s.phase="missing-wall";return waiting() end
    if valid(rec.entity) then
      local dx,dy=rec.entity.position.x-s.center.x,rec.entity.position.y-s.center.y
      if not s.desired[key] or math.abs(math.sqrt(dx*dx+dy*dy)-s.radius)>1.75 then
        return proposal(s,"recover",{entity=rec.entity,key=key,reason="coverage-changed"})
      end
    else
      s.tracked_record=rec;s.phase=rec.position and "replacement-query" or "lost-wall"
    end
    return waiting()
  elseif s.phase=="replacement-query" then
    s.replacements=pair.station.surface.find_entities_filtered{position=s.tracked_record.position,type="wall",force=pair.station.force,limit=8}
    s.replacement=1;s.phase="replacement";return waiting()
  elseif s.phase=="replacement" then
    local wall=s.replacements[s.replacement];s.replacement=s.replacement+1
    if not wall then s.phase="lost-wall";return waiting() end
    local rec=s.tracked_record;local branch=wall.name:match("^tech%-priests%-wall%-(%a+)%-[123]$")
    if valid(wall) and (wall.name=="stone-wall" or branch=="bastion" or branch=="ablative" or branch=="warded")
        and wall.position.x==rec.position.x and wall.position.y==rec.position.y then
      rec.entity=wall;rec.item=wall.name;rec.needs_rebuild=nil;s.phase="tracked-wall"
    end
    return waiting()
  elseif s.phase=="lost-wall" then
    local rec=s.tracked_record
    if not rec.needs_rebuild and rec.position then A.queue_breach(state,rec.position,"tracked-wall-destroyed") end
    if s.desired[s.tracked_key] and rec.item and rec.item~="stone-wall" then rec.entity=nil;rec.needs_rebuild=true
    else state.walls[s.tracked_key]=nil end
    -- Restart safely after a deletion. Every revisited record remains charged.
    -- A new breach changes the head and restarts as urgent.
    s.phase="tracked-wall";return waiting()
  elseif s.phase=="missing-wall" then
    if not A.unlocked(pair,"stone-wall") then return proposal(s,"none",{reason="wall-technology-locked"}) end
    local key,pos=next_map(s.desired,s,"wall_key")
    if not key then s.gate_index=1;s.phase="gate";return waiting() end
    local rec=state.walls[key]
    if not(rec and valid(rec.entity)) then
      s.selected={item=rec and rec.item or "stone-wall",entity=rec and rec.item or "stone-wall"}
      begin_site(s,s.selected.entity,rec and rec.position or pos,1,"wall")
    end
    return waiting()
  elseif s.phase=="gate" then
    if not s.gates_unlocked or s.gate_index>4 then s.phase="catalog";return waiting() end
    local offsets={{"east",s.radius,0,defines.direction.north},{"west",-s.radius,0,defines.direction.north},
      {"south",0,s.radius,defines.direction.east},{"north",0,-s.radius,defines.direction.east}}
    local row=offsets[s.gate_index];s.gate_index=s.gate_index+1;s.gate_key=row[1];s.gate_direction=row[4]
    local pos={x=s.center.x+row[2],y=s.center.y+row[3]};local rec=state.gates[s.gate_key]
    if not(rec and valid(rec.entity)) and A.allowed(pair,pos) then begin_site(s,"gate",pos,1,"gate") end
    return waiting()
  elseif s.phase=="routine-first" then
    local rec=s.candidates[s.candidate]
    if rec then
      if rec.entity==state.last_routine_turret_family_1130 then s.first=s.candidate%#s.candidates+1 end
      s.candidate=s.candidate+1;return waiting()
    end
    s.offset=0;s.first=s.first or 1;s.phase="routine-weapon";return waiting()
  elseif s.phase=="routine-weapon" then
    if s.offset>=#s.candidates then
      local rec=s.available or s.unlocked
      if rec and A.item_count(pair,rec.item)==0 then slot_setup(s,rec,"request");return waiting() end
      return proposal(s,"none",{reason="perimeter-satisfied"})
    end
    local rec=s.candidates[(s.first+s.offset-1)%#s.candidates+1];s.offset=s.offset+1
    if A.unlocked(pair,rec.entity) then
      s.unlocked=s.unlocked or rec
      if A.available(pair,rec.item) then s.available=s.available or rec end
      if A.item_count(pair,rec.item)>0 then slot_setup(s,rec,"build") end
    end
    return waiting()
  elseif s.phase=="slot" then
    if s.slot>s.slot_count then
      if s.slot_mode=="request" then return proposal(s,"none",{reason="perimeter-satisfied"}) end
      s.phase="routine-weapon";return waiting()
    end
    local key="slot-"..s.slot;local angle=(s.slot-0.5)*2*math.pi/s.slot_count;s.slot=s.slot+1
    local radius=math.max(6,s.radius-1)
    s.slot_position={x=math.floor(s.center.x+math.cos(angle)*radius+0.5)+0.5,y=math.floor(s.center.y+math.sin(angle)*radius+0.5)+0.5}
    if not A.allowed(pair,s.slot_position) then return waiting() end
    s.slot_key=key;s.slot_admission=admission_begin(pair,s.slot_position);s.phase="slot-admit";return waiting()
  elseif s.phase=="slot-admit" then
    local done,allowed=admission_step(pair,s.slot_admission)
    if not done then return waiting() end
    if not allowed then s.phase="slot";return waiting() end
    local key=s.slot_key
    s.family_key=s.selected.entity..":"..key
    local rec=state.turrets[s.family_key];local legacy=state.turrets[key]
    if not(rec and valid(rec.entity)) and legacy and valid(legacy.entity) and legacy.entity.name==s.selected.entity then
      state.turrets[s.family_key]=legacy;state.turrets[key]=nil;rec=legacy
    end
    s.phase=not(rec and valid(rec.entity) and rec.entity.name==s.selected.entity) and "slot-query" or "slot"
    return waiting()
  elseif s.phase=="slot-query" then
    s.near=A.turrets_near(pair,s.slot_position,2.5);s.near_index=1;s.phase="slot-entity";return waiting()
  elseif s.phase=="slot-entity" then
    local e=s.near[s.near_index];s.near_index=s.near_index+1
    if not e then begin_site(s,s.selected.entity,s.slot_position,6,"slot");return waiting() end
    if valid(e) and e.name==s.selected.entity then
      state.turrets[s.family_key]={entity=e,item=s.selected.item,position=copy(e.position),adopted_tick=now()};s.phase="slot"
    end
    return waiting()
  end
  return outcome({kind="stale",reason="unknown-defense-phase"})
end

Q.register(M.kind,plan_step)
Q.register(M.retry_kind,function(job)
  if not pair_live(job.payload) or job.payload.epoch~=Metadata.epoch() then return outcome({kind="stale"}) end
  if not A.metadata_ready(job.payload.pair) then return waiting() end
  local s=job.state;local task=job.payload.task
  if not s.site then
    if task.support_kind_1507=="pole" then
      local center=task.pending_breach_position_0260 or task.position
      local proto=A.entity_proto(task.entity_name)
      local supply=A.pole_range(proto,"get_supply_area_distance")
      local wire=A.pole_range(proto,"get_max_wire_distance")
      if not(supply and wire) then return outcome({kind="site"}) end
      s.site=site_begin(task.entity_name,center,5,"pole")
      s.site.ring=ring_begin(center,5,false,1);s.site.supply=supply;s.site.search=math.min(64,math.ceil(wire+8))
    else
      s.site=site_begin(task.entity_name,task.position,task.type=="build-turret" and 6 or 1,
        task.type=="build-turret" and A.entity_kind(task.entity_name)
          or (task.type=="build-turret-support" and task.entity_name=="pipe" and "pipe-support" or "ordinary"))
    end
    return waiting()
  end
  if not site_step(job.payload.pair,s.site) then return waiting() end
  return outcome({kind="site",position=s.site.position,support=s.site.witness,support_kind=s.site.kind,entity=task.entity_name,
    pipe_scan=s.site.pipe_scan,fluid_proof=s.site.fluid_proof,planned_fluid=s.site.planned_fluid,authority=s.site.authority})
end)
Q.register(M.ammo_kind,function(job)
  if not pair_live(job.payload) then return outcome({}) end
  local s=job.state
  if not s.inventory then s.inventory=inventory_begin(job.payload.pair);return waiting() end
  local done,ammo=inventory_step(job.payload.pair,s.inventory)
  if done then return outcome({ammo=ammo}) end
  return waiting()
end)
function M.configure(adapter) A=adapter end
function M.install() Q.install();Area.install();return true end
function M.radius(pair) return Territory.territory_radius(pair) end
function M.policy_ready(pair) return A.metadata_ready(pair) end
function M.cached_candidates() local c=root().catalog;return c and c.done and c.rows or {} end
function M.item_for_entity(name) return Metadata.item_for_entity(name) end
function M.ammo(pair)
  if pair.defense_ammo_1507 and A.item_count(pair,pair.defense_ammo_1507)>0 then return pair.defense_ammo_1507,"ready" end
  M.install();local key=tostring(pair.station.unit_number);local force=pair.station.force.index
  local job,status=Q.submit(force,M.ammo_kind,key,payload(pair,"ammo"))
  if status~="ready" then return nil,status end
  local ammo=job.result and job.result.ammo
  Q.forget(force,M.ammo_kind,key)
  if ammo and A.item_count(pair,ammo)>0 then pair.defense_ammo_1507=ammo;return ammo,"ready" end
  return nil,"none"
end
local function live_check(pair,result)
  if not Q.claim_tick("defense-final-check",M.live_limit) then return nil,"pending" end
  if result.kind=="build" or result.kind=="site" then
    if not result.position then return true end
    if not admission_current(pair,result.authority,result.position) then return false,"territory-changed" end
    if not A.can_place(pair,result.entity,result.position) then return false,"site-changed" end
    if result.support then
      if not Q.claim_tick("defense-final-check",M.live_limit) then return nil,"pending" end
      if not witness(pair,result.support_kind,result.position,result.support,result.entity) then return false,"support-changed" end
    end
    if result.pipe_scan then
      local safe=pipe_current(pair,result.pipe_scan,result.fluid_proof,result.planned_fluid)
      if safe==nil then return nil,"pending" end
      if not safe then return false,"pipe-neighborhood-changed" end
    end
    -- The physical caller performs the current one-item availability check
    -- immediately after poll returns; reserve its work before releasing the
    -- ready proposal, so a depleted final budget cannot lose that proposal.
    if result.kind=="build" and not Q.claim_tick("defense-final-check",M.live_limit) then return nil,"pending" end
  elseif result.kind=="recover" then
    if not valid(result.entity) or result.entity.force~=pair.station.force then return false,"wall-changed" end
  elseif result.kind=="ammo" then
    if not valid(result.turret) or result.turret.force~=pair.station.force or A.item_count(pair,result.ammo)<=0 then return false,"ammo-changed" end
  elseif (result.kind=="none" or result.kind=="request") and result.world and not Area.current(result.world) then return false,"world-changed" end
  return true
end
function M.claim_live() return Q.claim_tick("defense-final-check",M.live_limit) end
function M.task_support_current(pair,task)
  if not admission_current(pair,task.authority_1507,task.position) then return false end
  if task.pipe_scan_1507 then
    local safe=pipe_current(pair,task.pipe_scan_1507,task.fluid_proof_1507,task.planned_fluid_1507)
    if safe~=true then return safe end
  end
  return not task.support_witness_1507 or witness(pair,task.support_kind_1507,task.position,
    task.support_witness_1507,task.entity_name)
end
function M.poll(pair,mode)
  M.install();mode=mode or "perimeter"
  local force,key=pair.station.force.index,tostring(pair.station.unit_number)..":"..mode
  local job,status=Q.submit(force,M.kind,key,payload(pair,mode))
  if status~="ready" then return nil,status end
  local result=job.result or {kind="stale"}
  if not pair_live(job.payload) or job.payload.epoch~=Metadata.epoch() or not threat_same(pair,job.state)
      or job.state.territory_epoch~=Territory.territory_epoch(pair)
      or math.max(8,math.floor(A.radius(pair)-1))~=job.payload.radius or result.kind=="stale" then
    Q.forget(force,M.kind,key);return nil,"pending"
  end
  local okay,why=live_check(pair,result)
  if okay==nil then return nil,"pending" end
  Q.forget(force,M.kind,key)
  if not okay then return nil,"pending",why end
  return result,"ready"
end
function M.retry_position(pair,task)
  M.install();local force,key=pair.station.force.index,tostring(pair.station.unit_number)
  local job,status=Q.peek(force,M.retry_kind,key)
  if job and job.payload.task~=task then Q.forget(force,M.retry_kind,key);job=nil end
  if not job then local p=payload(pair,"retry");p.task=task;job,status=Q.submit(force,M.retry_kind,key,p) end
  if status~="ready" then return nil,status end
  local result=job.result or {kind="stale"}
  if result.kind=="stale" then Q.forget(force,M.retry_kind,key);return nil,"pending" end
  local okay=live_check(pair,result)
  if okay==nil then return nil,"pending" end
  Q.forget(force,M.retry_kind,key)
  if not okay then return nil,"pending" end
  if result.position then
    task.support_witness_1507=result.support;task.support_kind_1507=result.support_kind
    task.authority_1507=result.authority
    task.pipe_scan_1507=result.pipe_scan;task.fluid_proof_1507=result.fluid_proof;task.planned_fluid_1507=result.planned_fluid
  end
  return result.position,result.position and "ready" or "none"
end
return M
