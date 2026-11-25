-- Native strategic reconnaissance and resource seizure for a Magos.
-- Called by 0259 only. No tick registration, spawned units, stock grants,
-- enemy orders, damage injection or new movement/custody authority.
local Catalog=require("shared.combat_roster_catalog")
local M={max_actors=24,scout_radius=40,margin=1.35,interval=300}
local function valid(e)return e and e.valid end
local function copy(p)return {x=p.x,y=p.y} end
local function d2(a,b)return (a.x-b.x)^2+(a.y-b.y)^2 end
local function state(pair)
  pair.strategic_resource_campaign=pair.strategic_resource_campaign or {actors={},cursor=0}
  return pair.strategic_resource_campaign
end
local function orders()return rawget(_G,"TechPriestsCombatRosterOrders")end
local function read(f,default)local ok,v=pcall(f);if ok and v~=nil then return v end;return default end
local function inv_count(inv,item)
  return valid(inv) and read(function()return inv.get_item_count(item)end,0) or 0
end
local function stock(pair,item)
  return inv_count(pair.station.get_inventory(defines.inventory.chest),item)
end
local function busy(pair)
  return pair.active_task or pair.current_task or pair.emergency_craft or pair.scavenge
    or pair.direct_acquisition_task_0336 or pair.direct_acquisition_custody_0513
    or pair.construction_task_0338 or pair.construction_custody_0338
    or pair.construction_task_0340 or pair.inventory_transfer_custody_0687
    or pair.machine_logistics_custody_0528 or pair.item_family_custody_0702
    or pair.energy_family_custody_0707 or pair.emergency_facility_feed_custody_0357
    or pair.defense_task_0259 or valid(pair.combat_target)
    or pair.active_order_0469 or (pair.order_queue_0469 and pair.order_queue_0469.current)
end
local function ask(pair,s,item)
  s.required_item=item
  if busy(pair) or pair.combat_muster_order then return false end
  local op=pair.independent_emergency_operation_0184
  local acquire=rawget(_G,"tech_priests_emergency_operation_acquire_item_0185")
  if op and op.enabled==true and type(acquire)=="function"
      and game.tick>=(s.next_supply_tick or 0) then
    s.next_supply_tick=game.tick+1200
    return acquire(pair,item,op,1,0)==true
  end
  return false
end
-- Positive ore quantity and real drill coverage, not simply an ore tile.
-- Bounded sample saturation never constitutes proof of depletion.
function M.local_supply(pair,names,item,rate,radius)
  local s=state(pair);s.local_supply=s.local_supply or {}
  local previous=s.local_supply[item]
  if previous and game.tick-previous.tick<1200 then return previous end
  local station=pair.station
  local surface=station.surface
  local ores=surface.find_entities_filtered{type="resource",name=names,
    position=station.position,radius=radius,limit=128}
  local drills=surface.find_entities_filtered{type="mining-drill",force=station.force,
    position=station.position,radius=radius,limit=96}
  local total,uncovered,active=0,0,0
  local candidate=nil
  local candidates={}
  local mining={}
  for _,drill in ipairs(drills)do
    if valid(drill) then
      local r=read(function()return drill.prototype.get_mining_drill_radius(drill.quality)end,2)
      mining[#mining+1]={entity=drill,radius=r}
      local target=read(function()return drill.mining_target end,nil)
      if valid(target) then
        for _,name in ipairs(names)do if target.name==name
            and drill.status==defines.entity_status.working then active=active+1;break end end
      end
    end
  end
  for _,ore in ipairs(ores)do
    if valid(ore) and (ore.amount or 0)>0 then
      total=total+ore.amount
      local covered=false
      for _,drill in ipairs(mining)do
        local p=drill.entity.position
        if math.abs(p.x-ore.position.x)<=drill.radius+0.5
            and math.abs(p.y-ore.position.y)<=drill.radius+0.5 then
          covered=true;break
        end
      end
      if not covered then
        uncovered=uncovered+1
        if not candidate then candidate=copy(ore.position)end
        if #candidates<16 then candidates[#candidates+1]=copy(ore.position) end
      end
    end
  end
  local target=math.max(1,(tonumber(rate) or 0)*60)
  local flow=read(function()
    local stats=prototypes.item[item] and station.force.get_item_production_statistics(surface)
      or station.force.get_fluid_production_statistics(surface)
    return stats.get_flow_count{name=item,category="input",
      precision_index=defines.flow_precision_index.one_minute}
  end,nil)
  local reserve=target*5
  local saturated=#ores==128 or #drills==96
  local phase
  if total==0 and not saturated then
    phase=flow and flow>=target and "supplied-from-existing-network" or "no-local-resource"
  elseif total<reserve and not saturated then phase="local-reserve-low"
  elseif uncovered>0 and (not flow or flow<target) then phase="unexploited-local-resource"
  elseif flow and flow>=target then phase="production-sufficient"
  elseif active==0 then phase="local-extraction-stalled"
  else phase="local-output-below-demand" end
  local result={tick=game.tick,phase=phase,remaining_sample=total,uncovered_sample=uncovered,
    active_drills=active,required_per_minute=target,observed_force_per_minute=flow,
    saturated=saturated,candidate=candidate,candidates=candidates}
  s.local_supply[item]=result
  return result
end
function M.offer_local_drill(pair,assessment,item,radius)
  if item=="crude-oil" or not assessment.candidate or busy(pair) or pair.combat_muster_order
      or pair.structure_construction_requested_item or pair.construction_request
      or pair.construction_requested_item then return false end
  local name="burner-mining-drill"
  if stock(pair,name)<1 then return false end
  local pos=nil
  for _,candidate in ipairs(assessment.candidates or {assessment.candidate})do
    local p={x=math.floor(candidate.x),y=math.floor(candidate.y)}
    if d2(p,pair.station.position)<=radius^2
        and pair.station.surface.can_place_entity{name=name,position=p,
          direction=defines.direction.north,force=pair.station.force} then pos=p;break end
  end
  if not pos then return false end
  pair.structure_construction_requested_item={item_name=name,entity_name=name,
    category="mining",position=pos,direction=defines.direction.north,
    site_reason="strategic-local-unexploited-resource",source="strategic-resource-campaign"}
  return true
end
local function collect(pair,s)
  local last=pair.combat_muster_last
  if s.pending and last and last.id==s.pending then
    if last.phase=="commanded" and valid(last.actor)
        and last.actor.force==pair.station.force and last.actor.surface==pair.station.surface then
      s.actors[#s.actors+1]={actor=last.actor,unit_id=last.unit_id}
      s.recruited=(s.recruited or 0)+1
    end
    s.pending=nil
  elseif s.pending and not pair.combat_muster_order then s.pending=nil end
  local kept={}
  for _,a in ipairs(s.actors)do
    if valid(a.actor) and a.actor.force==pair.station.force and a.actor.surface==pair.station.surface then
      kept[#kept+1]=a
    else s.lost=(s.lost or 0)+1 end
  end
  s.actors=kept
end
function M.replaced(pair,old,new)
  local s=pair and pair.strategic_resource_campaign
  if not s or not valid(new) then return end
  for _,a in ipairs(s.actors)do if a.actor==old then a.actor=new end end
end
local function ready(a)
  local u=Catalog.by_id[a.unit_id];local e=a.actor
  if not u or not valid(e) then return 0,0 end
  local ammo=Catalog.ammo[u.ammo_family]
  local mags=inv_count(e.get_inventory(defines.inventory.car_ammo),ammo.name)
  local fuel=inv_count(e.get_fuel_inventory(),"tech-priests-field-supply-pack")
  local burning=read(function()return e.burner.remaining_burning_fuel end,0)
  if mags<1 or (fuel<1 and burning<=0) then return 0,mags end
  local hp=tonumber(e.health) or 0
  local score=hp/200+(u.damage*60/math.max(1,u.cooldown))/28
  -- Conservative effectiveness; short magazines reduce useful combat power.
  return score*0.75*math.min(1,mags/2),mags
end
local function command(pair,a,pos)
  if not valid(a.actor) or not orders() then return false end
  if a.last_goal and d2(a.last_goal,pos)<1 and game.tick-(a.command_tick or 0)<600 then return true end
  local ok=orders().command_owned(pair,a.actor,{position=copy(pos)})
  if ok then a.last_goal=copy(pos);a.command_tick=game.tick end
  return ok
end
local function rally(pair,s)
  local home=pair.station.position
  for i,a in ipairs(s.actors)do
    local angle=i*2.399963
    command(pair,a,{x=home.x+8*math.cos(angle),y=home.y+8*math.sin(angle)})
  end
end
local function muster(pair,s)
  if #s.actors>=M.max_actors then s.phase="army-capacity-limited";return false end
  if s.pending or pair.combat_muster_order or pair.combat_construction_request then
    s.phase="waiting-paid-reinforcements";return false
  end
  local chosen,available=nil,false
  for _,u in ipairs(Catalog.units)do
    local enabled=pair.station.force.recipes[u.name]
    local allow=settings.startup["tech-priests-combat-allow-"..u.faction]
    if enabled and enabled.enabled and (not allow or allow.value) then
      local in_stock=stock(pair,u.name)>0
      if not chosen or (in_stock and not available)
          or (in_stock==available and u.stage<chosen.stage) then chosen=u;available=in_stock end
    end
  end
  if not chosen then s.phase="no-unlocked-offensive-unit";return false end
  local ammo=Catalog.ammo[chosen.ammo_family].name
  if stock(pair,ammo)<2 then s.phase="awaiting-offensive-ammunition";return ask(pair,s,ammo)end
  if stock(pair,"tech-priests-field-supply-pack")<2 then
    s.phase="awaiting-offensive-fuel";return ask(pair,s,"tech-priests-field-supply-pack")
  end
  if not available then s.phase="awaiting-offensive-unit";return ask(pair,s,chosen.name)end
  if busy(pair) or not orders() then s.phase="waiting-free-construction-owner";return false end
  local station=pair.station
  local pos=station.surface.find_non_colliding_position(chosen.name,station.position,16,0.5)
  if not pos then s.phase="no-safe-muster-site";return false end
  local ok,token=orders().request(pair,chosen.id,copy(pos),copy(pos),"normal")
  if ok then s.pending=token;s.required_item=nil;s.phase="paid-muster-requested" end
  return ok
end
local function observable(pair,s,pos)
  local station=pair.station
  if d2(station.position,pos)<=M.scout_radius^2 or d2(pair.priest.position,pos)<=M.scout_radius^2 then return true end
  for _,a in ipairs(s.actors)do if d2(a.actor.position,pos)<=M.scout_radius^2 then return true end end
  return station.force.is_chunk_visible(station.surface,{x=math.floor(pos.x/32),y=math.floor(pos.y/32)})
end
local function inspect(pair,s,pos)
  if not observable(pair,s,pos) then return nil end
  local station=pair.station
  local enemies={}
  for _,f in pairs(game.forces)do
    if f~=station.force and f.name~="neutral" and not station.force.get_friend(f)
        and not station.force.get_cease_fire(f) then enemies[#enemies+1]=f.name end
  end
  local points,count,spawners=0,0,0
  local contacts={}
  if #enemies>0 then
    contacts=station.surface.find_entities_filtered{position=pos,radius=36,force=enemies,
      type={"unit","unit-spawner","turret","ammo-turret","electric-turret","fluid-turret",
        "artillery-turret","car","character","spider-vehicle","combat-robot","mining-drill"},limit=128}
    for _,e in ipairs(contacts)do
      if valid(e) and observable(pair,s,e.position) then
        local u=Catalog.for_entity_name(e.name)
        local ap=read(function()return e.prototype.attack_parameters end,nil)
        local offense=u and (u.damage*60/math.max(1,u.cooldown))/28
          or (ap and (1+(tonumber(ap.range) or 0)/24)*math.min(3,60/math.max(1,tonumber(ap.cooldown) or 60)) or 0)
        if e.type=="unit-spawner" then
          spawners=spawners+1
          offense=offense+3+4*read(function()return e.force.get_evolution_factor(station.surface)end,0)
        elseif e.type=="unit" then offense=math.max(0.35,offense) end
        points=points+math.max(0.1,(tonumber(e.health) or 0)/200)+offense
        count=count+1
      end
    end
  end
  return {tick=game.tick,position=copy(pos),hostiles=count,spawners=spawners,
    expected_power=points,upper_power=count>0 and points*M.margin+1 or 0,
    saturated=#contacts==128}
end
local function chart_scouts(pair,s)
  for _,a in ipairs(s.actors)do
    local pos=a.actor.position
    if not a.charted or d2(a.charted,pos)>=16^2 then
      pair.station.force.chart(pair.station.surface,{{pos.x-24,pos.y-24},{pos.x+24,pos.y+24}})
      a.charted=copy(pos)
    end
  end
end
local function service_threat(pair,s,point,intel)
  local power,ready_count,assembled=0,0,0
  for _,a in ipairs(s.actors)do
    local value=ready(a)
    if value>0 then
      power=power+value;ready_count=ready_count+1
      if d2(a.actor.position,pair.station.position)<=24^2 then assembled=assembled+1 end
    end
  end
  s.assessment={tick=game.tick,enemy_count=intel.hostiles,enemy_expected=intel.expected_power,
    enemy_upper=intel.upper_power,friendly_lower=power,ready_units=ready_count,
    reserve_margin=M.margin,target=copy(point),saturated=intel.saturated}
  if intel.saturated or power<intel.upper_power or ready_count<2 then
    s.phase="reinforce-before-assault";s.attack_in_progress=false;rally(pair,s)
    if not intel.saturated then
      -- Refill existing actors at the friendly rally rather than build a
      -- growing army of empty vehicles. Never send a priest into enemy fire.
      local logistics=package.loaded["scripts.core.item_family_logistics_0702"]
      local supplied=false
      if logistics and not busy(pair) and not pair.item_family_logistics_0702 then
        for _,a in ipairs(s.actors)do
          local u=Catalog.by_id[a.unit_id]
          if u and d2(a.actor.position,pair.station.position)<=16^2 and ready(a)<=0 then
            local ammo=Catalog.ammo[u.ammo_family].name
            local item=inv_count(a.actor.get_inventory(defines.inventory.car_ammo),ammo)<1
              and ammo or "tech-priests-field-supply-pack"
            local family=item==ammo and "ammo" or "supply"
            if stock(pair,item)>0 then
              logistics.offer_combat_supply(pair,a.actor,item,family,2)
              supplied=true
            else supplied=ask(pair,s,item) end
            if supplied then break end
          end
        end
      end
      if not supplied then muster(pair,s)end
    end
    return false
  end
  if not s.attack_in_progress and assembled<ready_count then
    s.phase="assemble-offensive-force";rally(pair,s);return false
  end
  -- Only the units paid for by this campaign receive native AAI attack moves.
  if not s.attack_in_progress then
    s.assaults=(s.assaults or 0)+1;s.attack_in_progress=true;s.attack_started_tick=game.tick
  end
  s.phase="assault-authorized"
  for i,a in ipairs(s.actors)do
    if ready(a)>0 then
      local angle=i*2.399963
      command(pair,a,{x=point.x+5*math.cos(angle),y=point.y+5*math.sin(angle)})
    end
  end
  return false
end
-- Route reconnaissance is incremental: at most four 32-tile waypoints per
-- service. No remote scans of hidden enemy forces. Unknown never means safe.
function M.admit(pair,need,target)
  local s=state(pair);collect(pair,s);chart_scouts(pair,s)
  if not s.route or s.route.need~=need or d2(s.route.target,target)>32^2 then
    s.route={need=need,target=copy(target),index=1,clear=0}
    s.attack_in_progress=false
  end
  local route=s.route;local home=pair.station.position
  local distance=math.sqrt(d2(home,target));local steps=math.max(1,math.ceil(distance/32))
  for _=1,4 do
    local i=math.min(route.index,steps)
    local point={x=home.x+(target.x-home.x)*i/steps,y=home.y+(target.y-home.y)*i/steps}
    local intel=inspect(pair,s,point)
    if not intel then
      -- A withdrawal must not erase the known garrison or send the same lone
      -- scout repeatedly to its death. Retain the observed threat until a
      -- native friendly observation confirms clearance.
      if route.threat and d2(route.threat.position,point)<1 then
        return service_threat(pair,s,point,route.threat)
      end
      s.phase="scouting-unknown-corridor";s.scout_target=copy(point)
      local scout=nil
      for _,a in ipairs(s.actors)do if ready(a)>0 then scout=a;break end end
      if scout then command(pair,scout,point)else muster(pair,s)end
      return false
    end
    s.last_intel=intel
    if intel.hostiles>0 or intel.saturated then
      route.clear=0;route.threat=intel
      return service_threat(pair,s,point,intel)
    end
    -- Re-observe a previously contested waypoint on the next pulse.
    if s.assessment and d2(s.assessment.target,point)<1 and route.clear<1 then
      route.clear=route.clear+1;s.phase="confirming-clearance";return false
    end
    route.threat=nil;s.attack_in_progress=false
    if i==steps then s.phase="corridor-observed-clear";s.cleared_tick=game.tick;return true end
    route.index=i+1;route.clear=0
  end
  s.phase="surveying-corridor";return false
end
function M.explore(pair,need)
  local s=state(pair)
  if not s.explore or s.explore.need~=need then
    s.explore={need=need,cursor=s.cursor or 0}
  end
  local e=s.explore
  local slot=e.cursor%8
  local radius=96+96*math.floor(e.cursor/8)
  if radius>2048 then e.cursor=0;radius=96 end
  local angle=slot*math.pi/4
  local pos={x=pair.station.position.x+radius*math.cos(angle),
    y=pair.station.position.y+radius*math.sin(angle)}
  if M.admit(pair,need,pos) then
    e.cursor=e.cursor+1;s.cursor=e.cursor;s.route=nil
  end
  return false
end
return M
