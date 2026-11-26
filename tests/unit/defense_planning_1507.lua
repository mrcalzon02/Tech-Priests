-- Exercise the real 0259 physical caller and the real shared planner. These
-- contracts do not assert Factorio FPS, native save acceptance or combat.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={}}
game={tick=1}
defines={inventory={chest=1,turret_ammo=2},direction={north=0,east=2},command={go_to_location=1},distraction={by_enemy=1},events={}}
TechPriestsRuntimeTickBroker0600={base_interval=5,register_service=function(spec)return spec end}
TechPriestsRuntimeEventRegistry={on_event=function()end,on_configuration_changed=function()end}
local Q=require("scripts.core.force_planning_queue")
local Area=require("scripts.core.bounded_planning_area_1507")
local Metadata=require("scripts.core.planning_metadata_1507")
local force={valid=true,name="player",index=1,__native=true,recipes={}}
local surface={valid=true,index=1,__native=true}
local types={['gun-turret']='ammo-turret',['laser-turret']='electric-turret',
  ['flamethrower-turret']='fluid-turret',['stone-wall']='wall',gate='gate',
  ['small-electric-pole']='electric-pole',['medium-electric-pole']='electric-pole',pipe='pipe'}
prototypes={item={},entity={}}
for name,kind in pairs(types) do
  prototypes.entity[name]={name=name,type=kind,attack_parameters={range=18},
    get_supply_area_distance=function(quality)return quality=='legendary' and 12 or 6 end,
    get_max_wire_distance=function(quality)return quality=='legendary' and 18 or 9 end}
  prototypes.item[name]={name=name,type='item',place_result=prototypes.entity[name]}
end
prototypes.item['firearm-magazine']={name='firearm-magazine',type='ammo'}
for i=1,180 do prototypes.item['unrelated-'..i]={name='unrelated-'..i,type='item'} end
tech_priests_get_entity_prototype_0440=function(name)return prototypes.entity[name]end
tech_priests_get_entity_prototype_name_from_item_0184=function(name)
  local proto=prototypes.item[name];return proto and proto.place_result and proto.place_result.name
end
tech_priests_get_item_prototype_0440=function(name)return prototypes.item[name]end
tech_priests_prototype_table_0440=function(kind)return prototypes[kind]end
TechPriestsPlanningConstraints0646={entity_unlocked=function(_,name)return name~='gate' end,
  item_for_entity=function(name)return prototypes.item[name] and name end,
  defense_position_allowed=function(pair,pos)
    local dx,dy=pos.x-pair.station.position.x,pos.y-pair.station.position.y
    return dx*dx+dy*dy<=(pair.radius+0.5)^2
  end}
local stock,entities,requests,moves,builds,counts,blocked,next_unit,legacy_calls
local function reset()
  stock={['gun-turret']=3,['firearm-magazine']=100,['stone-wall']=3}
  entities={};requests={};moves={};builds={};counts={place=0,query=0,slot=0,removed=0}
  blocked=function()return false end;next_unit=100;legacy_calls=0
  storage={tech_priests={pairs_by_station={}}};game.tick=game.tick+1
end
local slot_names={}
for i=1,180 do slot_names[i]='unrelated-'..i end
slot_names[181]='firearm-magazine'
local inventory=setmetatable({valid=true,__native=true},{__len=function()return #slot_names end,
  __index=function(_,i)
    if type(i)=='number' then counts.slot=counts.slot+1;local name=slot_names[i]
      return name and {valid_for_read=(stock[name] or 0)>0,name=name,count=stock[name] or 0}
    end
  end})
function inventory.get_item_count(name)return stock[name] or 0 end
function inventory.remove(spec)
  local n=math.min(stock[spec.name] or 0,spec.count);stock[spec.name]=(stock[spec.name] or 0)-n
  counts.removed=counts.removed+n;return n
end
function inventory.insert(spec)stock[spec.name]=(stock[spec.name] or 0)+spec.count;return spec.count end
function inventory.get_contents()error('native inventory scan must visit indexed slots')end
get_station_inventory=function()return inventory end
issue_station_logistic_request=function(_,request)requests[#requests+1]=request;return true end
issue_priest_command=function(priest,command)moves[#moves+1]={priest=priest,command=command};return true end
local function entity(name,pos,extra)
  next_unit=next_unit+1;extra=extra or {}
  local ammo={valid=true,__native=true,count=0}
  function ammo.is_empty()return ammo.count==0 end
  function ammo.insert(spec)ammo.count=ammo.count+spec.count;return spec.count end
  local e={valid=true,__native=true,name=name,type=types[name],surface=surface,force=force,
    unit_number=next_unit,position={x=pos.x,y=pos.y},prototype=prototypes.entity[name],
    electric_network_id=extra.electric_network_id,fluidbox=extra.fluidbox or {},ammo=ammo,
    get_inventory=function(id)if id==defines.inventory.turret_ammo then return ammo end end}
  entities[#entities+1]=e;return e
end
function surface.can_place_entity(spec)
  counts.place=counts.place+1
  return not blocked(spec)
end
function surface.find_entities_filtered(spec)
  counts.query=counts.query+1
  assert(spec.limit and spec.limit<=16,'live defense issued an uncapped or broad support query')
  local out={}
  for _,e in ipairs(entities) do
    local okay=e.valid and (not spec.force or spec.force==e.force)
    if type(spec.type)=='string' then okay=okay and e.type==spec.type
    elseif type(spec.type)=='table' then
      local yes=false;for _,kind in ipairs(spec.type)do if e.type==kind then yes=true end end
      okay=okay and yes
    end
    if spec.area then
      okay=okay and e.position.x>=spec.area[1][1] and e.position.x<=spec.area[2][1]
        and e.position.y>=spec.area[1][2] and e.position.y<=spec.area[2][2]
    elseif spec.position then
      local dx,dy=e.position.x-spec.position.x,e.position.y-spec.position.y
      okay=okay and dx*dx+dy*dy<=(spec.radius or 0)^2
    end
    if okay then out[#out+1]=e;if #out>=spec.limit then break end end
  end
  return out
end
function surface.create_entity(spec)
  assert(not blocked(spec),'stale defense site reached custody/create')
  local e=entity(spec.name,spec.position);builds[#builds+1]=e;Area.note_entity{entity=e};return e
end
local function pair_at(x)
  local station={valid=true,__native=true,name='cogitator-station',unit_number=1000+x,
    position={x=x,y=0},surface=surface,force=force,get_inventory=function()return inventory end}
  local priest={valid=true,__native=true,name='priest',unit_number=2000+x,position={x=x,y=0},surface=surface,force=force}
  local p={station=station,priest=priest,radius=20}
  storage.tech_priests.pairs_by_station[station.unit_number]=p
  return p
end
local function load_executor()
  tick_pair=function()legacy_calls=legacy_calls+1;return false end
  dofile('tech-priests_src/scripts/defense_perimeter.lua')
  return TechPriestsDefensePerimeter0259
end
reset()
local Bridge=load_executor()
local Planner=require('scripts.core.defense_planning_1507')
local function threat(pair,x)
  pair.defense_perimeter_0259={threats={{position={x=x or pair.station.position.x+19,y=0},reason='real-damage'}},next_scan_tick=0}
end
local function pulse(units)
  game.tick=game.tick+1
  local before={place=counts.place,query=counts.query,slot=counts.slot}
  local result=Q.pulse({tick=game.tick},units or 16)
  assert(result.processed<=math.min(units or 16,16),'global planner work budget exceeded')
  assert(counts.place-before.place<=result.processed,'site positions escaped budget')
  assert(counts.query-before.query<=result.processed,'queries escaped budget')
  assert(counts.slot-before.slot<=result.processed,'inventory entries escaped budget')
  assert((result.failed or 0)==0,'planner handler failed: '..tostring(Q.root().stats.failures))
  return result
end
local function until_task(pair,kind,limit)
  for _=1,limit or 3000 do
    pulse();Bridge.service_pair(pair)
    if pair.defense_task_0259 and (not kind or pair.defense_task_0259.type==kind) then return pair.defense_task_0259 end
  end
  error('defense continuation did not complete: '..tostring(pair.defense_perimeter_0259.last_reason))
end
local function until_ready(pair,mode,limit)
  local key=tostring(pair.station.unit_number)..':'..(mode or 'perimeter')
  for _=1,limit or 3000 do
    local job,status=Q.peek(force.index,Planner.kind,key)
    if status=='ready' then return job end
    pulse()
  end
  error('planner result did not become ready')
end
local function authorize_existing(pair,task)
  for _=1,3000 do
    local pos=Planner.retry_position(pair,task)
    if pos then task.position=pos;return end
    pulse()
  end
  error('existing task authority did not finish')
end
local function save_reload()
  local function clone(value,seen)
    if type(value)~='table' then assert(type(value)~='function' and type(value)~='thread','unsafe continuation value');return value end
    if value.__native then return value end
    seen=seen or {};if seen[value]then return seen[value]end
    local out={};seen[value]=out
    for k,v in pairs(value)do out[clone(k,seen)]=clone(v,seen)end
    return out
  end
  storage=clone(storage)
  for _,name in ipairs({'scripts.core.force_planning_queue','scripts.core.planning_metadata_1507',
    'scripts.core.bounded_planning_area_1507','scripts.core.defense_planning_1507'})do package.loaded[name]=nil end
  Q=require('scripts.core.force_planning_queue');Area=require('scripts.core.bounded_planning_area_1507')
  Metadata=require('scripts.core.planning_metadata_1507');Bridge=load_executor();Planner=require('scripts.core.defense_planning_1507')
end

-- Actual caller never advances the catalogue/site walk. Another ordinary
-- owner continues while no physical defense task has been committed.
local p=pair_at(0);threat(p)
local before=stock['gun-turret']
for _=1,50 do
  game.tick=game.tick+1;local result=Bridge.service_pair(p)
  assert((result.acted or 0)==0 and not p.defense_task_0259)
end
assert(counts.place==0 and counts.query==0 and stock['gun-turret']==before,'caller advanced or took stock')
assert(p.defense_perimeter_0259.next_scan_tick==0,'pending applied failure cooldown')
game.tick=game.tick+40;tick_pair(p);assert(legacy_calls>0,'pending monopolized legacy owner')
Q.register('no-action',function(job)job.state.n=(job.state.n or 0)+1;return {processed=0,waiting=true}end)
Q.submit(2,'no-action','other-force')
for _=1,15 do pulse(1) end
save_reload();p=storage.tech_priests.pairs_by_station[1000]
Q.register('no-action',function(job)job.state.n=(job.state.n or 0)+1;return {processed=0,waiting=true}end)
local task=until_task(p,'build-turret')
assert(task.item=='gun-turret' and #p.defense_perimeter_0259.threats==0,'priority weapon changed')
assert(stock['gun-turret']==before and counts.removed==0,'planning claimed materials')
local other=Q.peek(2,'no-action','other-force');assert(other.state.n>10,'no-action force lost fairness')
local original=p.priest
p.priest.position={x=task.position.x,y=task.position.y}
game.tick=game.tick+1;Bridge.service_pair(p)
game.tick=game.tick+60;Bridge.service_pair(p)
assert(#builds==1 and stock['gun-turret']==before-1 and p.priest==original,'paid physical construction changed identity/custody')
assert(not p.defense_task_0259 or p.defense_task_0259.type=='ammo-turret','finished task retained during ammo planning')
local ammo=until_task(p,'ammo-turret')
p.priest.position={x=ammo.position.x,y=ammo.position.y};game.tick=game.tick+1;Bridge.service_pair(p)
assert(builds[1].ammo.count==20 and stock['firearm-magazine']==80,'physical ammo delivery failed')

-- Full queues cause explicit backpressure and ordinary work continues. No
-- negative site, incident consumption, failure cooldown or item custody.
reset();Bridge=load_executor();p=pair_at(0);threat(p)
Q.register('full',function()return {processed=0,waiting=true}end)
for i=1,Q.max_per_force do assert(Q.submit(1,'full',i)) end
game.tick=game.tick+1;local full=Bridge.service_pair(p)
assert(full.waiting==1 and p.defense_perimeter_0259.last_reason=='defense-planning-queue-full')
assert(not p.defense_task_0259 and counts.place==0 and #p.defense_perimeter_0259.threats==1)
assert(p.defense_perimeter_0259.next_scan_tick==0 and counts.removed==0)
local repairs=0
TechPriestsRepairExecutor0516={service_pair=function(owner)
  assert(owner==p);repairs=repairs+1;return {processed=1,acted=1,detail='existing repair continued'}
end}
TECH_PRIESTS_ACTION_STATE_ARBITER_0488={action=function()return {kind='repair'}end}
local Dispatcher=require('scripts.core.single_dispatcher_0510')
game.tick=game.tick+1
local continued=Dispatcher.service_pair(p,'pending-defense-planner')
assert(continued.acted==1 and repairs==1 and p.canonical_action_0744.family=='repair',
  'actual canonical dispatcher idled the priest behind a full defense queue')
TechPriestsRepairExecutor0516=nil;TECH_PRIESTS_ACTION_STATE_ARBITER_0488=nil
Q.forget(1,'full',1)
for i=2,Q.max_per_force do Q.forget(1,'full',i) end
until_task(p,'build-turret')

-- Obstruction and stock mutations after a completed proposal are checked
-- by the real caller before it creates a task or consumes a queued incident.
reset();Bridge=load_executor();p=pair_at(0);threat(p)
Bridge.service_pair(p);local ready=until_ready(p);local pos=ready.result.position
blocked=function(spec)return spec.position.x==pos.x and spec.position.y==pos.y end
game.tick=game.tick+1;local stale=Bridge.service_pair(p)
assert(not p.defense_task_0259 and stale.waiting==1 and counts.removed==0 and #p.defense_perimeter_0259.threats==1)
assert(p.defense_perimeter_0259.next_scan_tick==0,'changed terrain became failure cooldown')
blocked=function()return false end
game.tick=game.tick+1;Bridge.service_pair(p);until_ready(p)
stock['gun-turret']=0;game.tick=game.tick+1;Bridge.service_pair(p)
assert(not p.defense_task_0259 and counts.removed==0 and #p.defense_perimeter_0259.threats==1,'stale stock started build')
stock['gun-turret']=2;until_task(p,'build-turret')

-- An obstructed active task has no material custody yet. Park its exact
-- state while searching, then resume through the same physical executor.
local obstructed=p.defense_task_0259;local old=obstructed.position
blocked=function(spec)return spec.position.x==old.x and spec.position.y==old.y end
game.tick=game.tick+1;Bridge.service_pair(p)
assert(not p.defense_task_0259 and p.defense_perimeter_0259.site_waiting_task_1507==obstructed)
assert(counts.removed==0,'blocked build took materials')
local prior=counts.place
for _=1,30 do game.tick=game.tick+1;Bridge.service_pair(p) end
assert(counts.place==prior,'pending task retry advanced outside broker')
save_reload();p=storage.tech_priests.pairs_by_station[1000]
local resumed=until_task(p,'build-turret')
assert(resumed.position.x~=old.x or resumed.position.y~=old.y,'obstructed position reused')
assert(resumed.item=='gun-turret' and counts.removed==0,'parked task changed custody')

-- Many unsupported poles are charged individually; a late native connected
-- witness is accepted, and losing it before dispatch invalidates the result.
reset();Bridge=load_executor();p=pair_at(0);threat(p);stock['gun-turret']=0;stock['laser-turret']=2
for i=1,55 do entity('small-electric-pole',{x=17+(i%5)*0.2,y=-1+math.floor(i/5)*0.15},{electric_network_id=0}) end
local grid=entity('medium-electric-pole',{x=18,y=0},{electric_network_id=7})
Bridge.service_pair(p)
local phase_seen=false
for _=1,5000 do
  pulse(1)
  local job=Q.peek(1,Planner.kind,'1000:perimeter')
  if job and job.state.site and job.state.site.phase=='witness' then phase_seen=true;break end
end
assert(phase_seen,'did not visit support entities separately')
save_reload();p=storage.tech_priests.pairs_by_station[1000]
ready=until_ready(p,nil,5000)
assert(ready.result.entity=='laser-turret' and ready.result.support==grid,'real connected power witness missing')
grid.electric_network_id=0;game.tick=game.tick+1;Bridge.service_pair(p)
assert(not p.defense_task_0259 and counts.removed==0,'disconnected support accepted')
grid.electric_network_id=7
until_task(p,'build-turret',5000)

-- Connected support-pole sites keep the actual upstream pole as a live
-- witness. Retrying a disconnected support may not become a generic site.
reset();Bridge=load_executor();p=pair_at(0);threat(p)
stock['gun-turret']=0;stock['laser-turret']=1;stock['small-electric-pole']=1
grid=entity('medium-electric-pole',{x=8,y=0},{electric_network_id=7})
grid.prototype={get_supply_area_distance=function()return 3 end,get_max_wire_distance=function()return 9 end}
blocked=function(spec)return spec.name=='laser-turret' and spec.position.x<18 end
task=until_task(p,'build-turret-support',5000)
assert(task.entity_name=='small-electric-pole' and task.support_witness_1507==grid and task.support_kind_1507=='pole')
assert(task.pending_turret_entity_0260=='laser-turret' and counts.removed==0)
grid.electric_network_id=0;game.tick=game.tick+1;Bridge.service_pair(p)
assert(not p.defense_task_0259 and p.defense_perimeter_0259.site_waiting_task_1507==task)
for _=1,10 do pulse(1) end
local retry=Q.peek(1,Planner.retry_kind,'1000')
assert(retry and retry.state.site and retry.state.site.kind=='pole','support retry lost native wire proof')
assert(counts.removed==0 and #builds==0,'disconnected support was paid or placed')

-- A neighboring fluid can change without a terrain event. Recheck the
-- individually charged native fluidbox proof before dispatch AND custody.
reset();Bridge=load_executor();p=pair_at(0);threat(p)
stock['gun-turret']=0;stock['flamethrower-turret']=1;stock.pipe=2
p.independent_emergency_operation_0184={magos_pipe_fluid_0258='light-oil'}
local neighbor=entity('pipe',{x=21,y=0},{fluidbox={{name='light-oil',amount=10}}})
blocked=function(spec)
  return spec.name=='flamethrower-turret' and not(spec.position.x==19.5 and spec.position.y==0.5)
end
Bridge.service_pair(p);ready=until_ready(p,nil,5000)
assert(ready.result.task_type=='build-turret-support' and ready.result.entity=='pipe' and #ready.result.fluid_proof==2)
neighbor.fluidbox[1]={name='water',amount=10};game.tick=game.tick+1;Bridge.service_pair(p)
assert(not p.defense_task_0259 and counts.removed==0,'changed fluid proof reached dispatch')
neighbor.fluidbox[1]={name='light-oil',amount=10}
task=until_task(p,'build-turret-support',5000)
neighbor.fluidbox[1]={name='water',amount=10};game.tick=game.tick+1;Bridge.service_pair(p)
assert(not p.defense_task_0259 and p.defense_perimeter_0259.site_waiting_task_1507==task,'active pipe ignored changed contents')
for _=1,10 do pulse(1) end
retry=Q.peek(1,Planner.retry_kind,'1000')
assert(retry and retry.state.site.kind=='pipe-support' and counts.removed==0,'pipe retry bypassed contamination safety')

-- High priority planning does not park a currently working wall. The exact
-- wall task is suspended only after a live urgent turret proposal is ready.
reset();Bridge=load_executor();p=pair_at(0);threat(p)
p.defense_perimeter_0259.hostile_incidents_0817={{id=5,expires_at=999999,needs_ammo=false}}
TechPriestsCombatDefenseReaction0816={reconcile_pair=function()end}
local wall={type='build-wall',item='stone-wall',entity_name='stone-wall',position={x=19,y=0},key='wall',next_repath_tick=0}
authorize_existing(p,wall)
p.defense_task_0259=wall
for _=1,12 do
  game.tick=game.tick+1;Bridge.service_pair(p)
  assert(p.defense_task_0259==wall and not p.defense_perimeter_0259.suspended_defense_task_0819,'pending urgent plan parked active construction')
end
assert(#moves>0,'original priest stopped moving during urgent planning')
until_task(p,'build-turret')
assert(p.defense_perimeter_0259.suspended_defense_task_0819==wall,'ready urgent action lost exact wall state')
assert(counts.removed==0,'preemption took unearned material custody')

-- Each neighboring station is another charged visit. A newly built station
-- invalidates an already completed permission proof before any custody.
reset();Bridge=load_executor();p=pair_at(0);threat(p)
for i=1,120 do pair_at(200+i*50) end
local neighbor_checks=0
refresh_pair_radius=function(owner)
  if owner~=p then neighbor_checks=neighbor_checks+1 end
  return owner.radius
end
Bridge.service_pair(p)
for _=1,5000 do
  local n=neighbor_checks;pulse(1)
  assert(neighbor_checks-n<=1,'one defense visit scanned multiple neighboring stations')
  local _,status=Q.peek(1,Planner.kind,'1000:perimeter')
  if status=='ready' then break end
end
ready=assert(Q.peek(1,Planner.kind,'1000:perimeter'))
assert(ready.status=='ready' and ready.result.kind=='build' and neighbor_checks>=120)
local neighbor_station=pair_at(19)
require('scripts.core.construction_site_planner').on_station_changed{entity=neighbor_station.station}
game.tick=game.tick+1;Bridge.service_pair(p)
assert(not p.defense_task_0259 and counts.removed==0 and #p.defense_perimeter_0259.threats==1,
  'new neighboring authority was bypassed by a stale defense site')
refresh_pair_radius=nil

-- Cold policy metadata is explicit pending, before an unlock/property
-- helper can fall back to the historical synchronous prototype walks.
reset();Bridge=load_executor();p=pair_at(0);threat(p)
local policy_ready=false
TechPriestsPlanningConstraints0646.request_metadata=function()return policy_ready end
Bridge.service_pair(p)
for _=1,50 do pulse();Bridge.service_pair(p) end
assert(counts.place==0 and counts.query==0 and counts.removed==0 and p.defense_perimeter_0259.next_scan_tick==0)
policy_ready=true;until_task(p,'build-turret')
TechPriestsPlanningConstraints0646.request_metadata=nil

-- Routine wall points are generated inside the broker, not in the legacy
-- caller. An unrelated force still advances when all candidate sites reject.
reset();Bridge=load_executor();p=pair_at(0);blocked=function()return true end
game.tick=game.tick+1;tick_pair(p)
assert(counts.place==0,'legacy perimeter loop ran synchronously')
Q.register('fair',function(job)job.state.n=(job.state.n or 0)+1;return {processed=0,waiting=true}end)
Q.submit(2,'fair','other')
for _=1,100 do pulse(1) end
local fair=Q.peek(2,'fair','other');assert(fair.state.n>=45,'rejected defense sites starved other force')
print('[defense-planning-1507] PASS actual callers, bounded catalogue/site/entity/ammo work, reload, full queues, stock/terrain/support changes, unladen retry, urgent fairness, original physical build/refill')
