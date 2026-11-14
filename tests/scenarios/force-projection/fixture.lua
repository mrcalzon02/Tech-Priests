-- Test-only seeded endurance arena. No recurring supplies, forced research,
-- movement commands, construction, attack orders or fabricated success.
local M={}
local KEY="ci_force_projection_v1"
local PREFIX="[TP-FORCE-PROJECTION] "
local Registry=require("scripts.core.runtime_event_registry")
local function emit(kind,data)
  log(PREFIX..kind.." "..helpers.table_to_json(data))
end
local function state() return storage[KEY] end
local function fail(reason)
  local s=state(); if s then s.failed=true end
  emit("FAIL",{tick=game.tick,reason=tostring(reason)})
end
local function guarded(fn)
  return function(event)
    if state() and state().failed then return end
    local ok,reason=pcall(fn,event)
    if not ok then fail(reason) end
  end
end
local function config() return _G.TP_FORCE_PROJECTION_CONFIG end
local PRESETS={
  ["2p2b"]={"p:left-a","b:bugs-a","p:left-b","b:bugs-b"},
  ["4p-ffa"]={"p:priest-a","p:priest-b","p:priest-c","p:priest-d"},
  ["1v4-bugs"]={"p:priests","b:bugs","b:bugs","b:bugs","b:bugs"},
  ["2v2"]={"p:priests","b:bugs","p:priests","b:bugs"},
  ["3v1"]={"p:priests","p:priests","p:priests","b:bugs"},
  ["4v4-priests"]={"p:left","p:right","p:left","p:right",
    "p:left","p:right","p:left","p:right"},
}
local function init()
  local c=config(); assert(c and PRESETS[c.preset],"missing arena config")
  game.speed=c.game_speed or 1
  local roster=PRESETS[c.preset]
  local side=#roster>4 and 3072 or 2048
  storage[KEY]={phase="terrain",seed=c.seed,preset=c.preset,
    side=side,chunk=0,cell=0,patch=0,tile=0,participants={},
    random=game.create_random_generator(c.seed),
    supply_random=game.create_random_generator(c.seed+100003),
    expansion_random=game.create_random_generator(c.seed+200003),
    started=nil,failed=false,finished=false,census_cursor=0,census={},
    checkpoints=0,setup_entities=0,resource_tiles=0,resource_amount=0}
  local s=state(); local rows=math.ceil(#roster/2)
  for i,entry in ipairs(roster) do
    local force=game.create_force("tp-arena-"..i)
    local position={x=(i%2==1 and -1 or 1)*(side/2-320),
      y=-side/2+320+(math.floor((i-1)/2))*(side-640)/math.max(1,rows-1)}
    local p={force=force.name,kind=entry:sub(1,1),team=entry:sub(3),
      origin=position,built=0,lost=0,research=0,damage_dealt=0,
      damage_received=0,max_build_distance=0,initial={},stock={}}
    s.participants[i]=p
    force.ai_controllable=p.kind=="b"
    force.set_evolution_factor(0,game.surfaces[1])
  end
  for _,a in ipairs(s.participants) do
    for _,b in ipairs(s.participants) do
      if a.force~=b.force then
        local allied=a.team==b.team
        game.forces[a.force].set_friend(b.force,allied)
        game.forces[a.force].set_cease_fire(b.force,allied)
      end
    end
  end
  -- Natural biter expansion, pollution and combat remain engine-owned.
  game.map_settings.enemy_expansion.enabled=true
  game.map_settings.enemy_evolution.time_factor=0
  game.map_settings.enemy_evolution.pollution_factor=0
  game.map_settings.enemy_evolution.destroy_factor=0
  emit("CONFIG",{seed=s.seed,preset=s.preset,side=side,
    active_ticks=c.active_ticks,participants=s.participants,
    novice_evolution=0,fixture_supply_only=true,
    operation_profile="independent-maximum-frustration",
    game_speed=game.speed,
    stock_profile="random-chest-plus-1-to-5-senior-kits"})
end
local function owner(force)
  if not force then return nil end
  for _,p in ipairs(state().participants) do
    if p.force==force.name then return p end
  end
end
local function reserved(x,y)
  for _,p in ipairs(state().participants) do
    if math.abs(x-p.origin.x)<48 and math.abs(y-p.origin.y)<48 then return true end
  end
  return false
end
local function prepare_terrain(s,surface)
  local n=s.side/32
  if s.chunk<n*n then
    local x=s.chunk%n-n/2; local y=math.floor(s.chunk/n)-n/2
    surface.request_to_generate_chunks({x=x*32+16,y=y*32+16},0)
    -- One native chunk, once per five ticks. Never generate the entire map
    -- synchronously in on_init or the first station build event.
    surface.force_generate_chunk_requests()
    s.chunk=s.chunk+1
    if s.chunk%256==0 then emit("SETUP",{tick=game.tick,
      phase=s.phase,chunks=s.chunk,total=n*n}) end
  else s.phase="resources" end
end
local RESOURCE={"iron-ore","copper-ore","coal","stone","crude-oil","water"}
local function seed_resources(s,surface)
  local n=s.side/256
  if s.cell>=n*n then s.phase="participants";s.participant_cursor=1;return end
  if not s.deposit then
    local cx=s.cell%n; local cy=math.floor(s.cell/n)
    local kind=RESOURCE[s.patch+1]
    local offsets={{-64,-64},{64,-64},{-64,64},{64,64},{0,-90},{0,90}}
    local offset=offsets[s.patch+1]
    local x=-s.side/2+cx*256+128+offset[1]+s.random(-18,18)
    local y=-s.side/2+cy*256+128+offset[2]+s.random(-18,18)
    if reserved(x,y) then
      -- Keep every macrocell's six deposits while reserving clear spawn pads.
      x=-s.side/2+cx*256+128;y=-s.side/2+cy*256+128
    end
    local near=false
    for _,p in ipairs(s.participants) do
      if (x-p.origin.x)^2+(y-p.origin.y)^2<200^2 then near=true end
    end
    s.deposit={name=kind,x=x,y=y,radius=s.random(4,8),
      amount=near and s.random(100,400) or s.random(400,1800),cursor=0,placed=0}
  end
  local d=s.deposit; local width=d.radius*2+1
  -- Bound each resource/tile API batch; persist exact cursor across saves.
  for _=1,12 do
    if d.cursor>=width*width then
      emit("DEPOSIT",{cell=s.cell,name=d.name,x=d.x,y=d.y,
        radius=d.radius,entities_or_tiles=d.placed,fixture_authored=true})
      s.deposit=nil;s.patch=s.patch+1
      if s.patch==#RESOURCE then s.patch=0;s.cell=s.cell+1 end
      return
    end
    local x=d.cursor%width-d.radius;local y=math.floor(d.cursor/width)-d.radius
    d.cursor=d.cursor+1
    if x*x+y*y<=d.radius*d.radius and not reserved(d.x+x,d.y+y) then
      local position={x=d.x+x+0.5,y=d.y+y+0.5}
      if d.name=="water" then
        surface.set_tiles({{name="water",position=position}},true)
        d.placed=d.placed+1
      elseif d.name~="crude-oil" or (x%4==0 and y%4==0) then
        local amount=d.name=="crude-oil" and d.amount*100 or d.amount
        local entity=surface.create_entity{name=d.name,position=position,amount=amount}
        assert(entity and entity.valid,"resource placement failed: "..d.name)
        d.placed=d.placed+1;s.resource_tiles=s.resource_tiles+1
        s.resource_amount=s.resource_amount+amount
      end
    end
  end
end
local function supply_pool()
  local names={}
  -- Entire installed game/modpack, including later technologies. Hidden
  -- helpers and planner tools cannot constitute build supplies.
  local excluded={blueprint=true,["blueprint-book"]=true,
    ["deconstruction-item"]=true,["upgrade-item"]=true,
    ["copy-paste-tool"]=true,["selection-tool"]=true}
  for name,p in pairs(prototypes.item) do
    if not p.hidden and p.stack_size>0 and not excluded[p.type] then
      names[#names+1]=name
    end
  end
  table.sort(names);assert(#names>0,"no supply item pool")
  return names
end
local function chest_name()
  local best="steel-chest";local size=0
  for name,p in pairs(prototypes.entity) do
    -- Passive provider exposes stock to normal logistics without exporting
    -- it automatically. Infinite/debug inventories are excluded by type.
    if not p.hidden and (p.type=="container" or
        (p.type=="logistic-container" and p.logistic_mode=="passive-provider")) then
      local slots=p.get_inventory_size(defines.inventory.chest)
      if slots and slots<=256 and (slots>size or (slots==size and name<best)) then
        best=name;size=slots
      end
    end
  end
  assert(size>=48,"no high-capacity supply chest")
  return best
end
local function seed_participant(s,surface)
  local p=s.participants[s.participant_cursor]
  if not p then
    s.phase="active";s.started=game.tick
    emit("READY",{tick=game.tick,resource_entities=s.resource_tiles,
      resource_amount=s.resource_amount,participants=#s.participants})
    return
  end
  local force=game.forces[p.force]
  if p.kind=="p" then
    local station=surface.create_entity{name="planetary-magos-cogitator-station",
      position=p.origin,force=force,raise_built=true}
    assert(station and station.valid,"Magos station creation refused")
    local pair=storage.tech_priests.pairs_by_station[station.unit_number]
    assert(pair and pair.priest and pair.priest.valid,"original Magos pairing absent")
    -- This stress profile starts after the player's patience has run out.
    -- Use the existing production authority; do not drive its planner/tasks.
    pair.emergency_operation_auto_allowed_0190=true
    pair.logistic_frustration_due_tick=game.tick
    assert(tech_priests_set_emergency_operation_0184(pair,true,"arena-independent"),
      "independent operation authorization refused")
    local op=tech_priests_get_emergency_operation_0184(pair)
    assert(op and op.enabled,"independent operation readback absent")
    p.station=station;p.priest=pair.priest
    p.initial[station.unit_number]=true;p.initial[pair.priest.unit_number]=true
    -- Immediate direct subordinates of a Planetary Magos are Seniors. Kits
    -- are real inventory items; canonical expansion still pays and deploys
    -- each station and registers its original priest. No free deployed units.
    local station_inv=station.get_inventory(defines.inventory.chest)
    assert(station_inv and station_inv.valid,"Magos inventory unavailable")
    local kit="senior-cogitator-station"
    assert(prototypes.item[kit],"senior station kit prototype unavailable")
    local wanted=s.expansion_random(1,5)
    local before=station_inv.get_item_count(kit)
    assert(before==0,"unexpected preexisting Magos expansion kits")
    local accepted=station_inv.insert{name=kit,count=wanted}
    local after=station_inv.get_item_count(kit)
    assert(accepted==wanted and after-before==wanted,"Magos expansion kit capacity/debit mismatch")
    p.expansion_stock={name=kit,count=wanted,inserted=accepted,
      native_count=after,quality="normal",location="magos-station",deployed=0}
    local chest=surface.create_entity{name=chest_name(),
      position={x=p.origin.x+8,y=p.origin.y+8},force=force,raise_built=true}
    assert(chest and chest.valid,"supply chest creation refused")
    p.chest=chest;p.initial[chest.unit_number]=true
    local inv=chest.get_inventory(defines.inventory.chest)
    local pool=supply_pool()
    for slot=1,#inv do
      local name=pool[s.supply_random(1,#pool)]
      local count=s.supply_random(1,prototypes.item[name].stack_size)
      assert(inv[slot].set_stack{name=name,count=count},"stock insert failed")
      p.stock[#p.stock+1]={slot=slot,name=name,count=count,quality="normal"}
    end
    emit("SUPPLY",{force=p.force,chest=chest.name,unit=chest.unit_number,
      station=station.unit_number,priest=pair.priest.unit_number,
      stock=p.stock,pool_size=#pool,refills=0,randomized=true,
      expansion_stock=p.expansion_stock})
    force.chart(surface,{{p.origin.x-160,p.origin.y-160},
      {p.origin.x+160,p.origin.y+160}})
  else
    for _,offset in ipairs({{-18,0},{18,0},{0,20}}) do
      local nest=surface.create_entity{name="biter-spawner",force=force,
        position={x=p.origin.x+offset[1],y=p.origin.y+offset[2]}}
      assert(nest and nest.valid,"native spawner creation refused")
      p.initial[nest.unit_number]=true
    end
  end
  s.participant_cursor=s.participant_cursor+1
end
local function damage(event)
  local s=state();if not(s and s.phase=="active") then return end
  local victim=event.entity
  local target=victim and victim.valid and owner(victim.force)
  local cause=event.cause
  local source=owner(event.force or (cause and cause.valid and cause.force))
  local amount=event.final_damage_amount or 0
  if target then target.damage_received=target.damage_received+amount end
  if source then source.damage_dealt=source.damage_dealt+amount end
  if target and source and target.force~=source.force and amount>0 then
    s.contacts=s.contacts or {}
    local key=source.force..">"..target.force
    if not s.contacts[key] then
      s.contacts[key]=game.tick
      emit("CONTACT",{tick=game.tick,attacker=source.force,
        defender=target.force,damage=amount,x=victim.position.x,y=victim.position.y})
    end
  end
end
local function built(event)
  local s=state();if not(s and s.phase=="active") then return end
  local e=event.entity or event.created_entity
  local p=e and e.valid and owner(e.force)
  if p and e.type~="entity-ghost" and e.type~="tile-ghost" then
    p.built=p.built+1
    local dx=e.position.x-p.origin.x;local dy=e.position.y-p.origin.y
    p.max_build_distance=math.max(p.max_build_distance,math.sqrt(dx*dx+dy*dy))
  end
end
local function census(s,surface)
  local n=s.side/32;local i=s.census_cursor
  local x=(i%n-n/2)*32;local y=(math.floor(i/n)-n/2)*32
  local forces={}
  for _,p in ipairs(s.participants)do forces[#forces+1]=p.force end
  -- Exclude neutral ore/decorations before applying the entity limit. Dense
  -- resource blobs previously consumed the entire building census allowance.
  local entities=surface.find_entities_filtered{
    area={{x,y},{x+32,y+32}},force=forces,limit=512}
  if #entities==512 then s.census_saturated=true end
  for _,e in ipairs(entities) do
    -- Entity centers select one chunk, avoiding boundary double counting.
    if e.valid and e.position.x>=x and e.position.x<x+32
        and e.position.y>=y and e.position.y<y+32 then
      local p=owner(e.force)
      if p then
        local c=s.census[p.force] or {live=0,ghosts=0,stations=0,labs=0,powered_labs=0}
        s.census[p.force]=c
        if e.type=="entity-ghost" or e.type=="tile-ghost" then c.ghosts=c.ghosts+1
        else
          c.live=c.live+1
          if e.name:find("cogitator%-station") then c.stations=c.stations+1 end
          if e.type=="lab" then
            c.labs=c.labs+1
            if e.energy>0 then c.powered_labs=c.powered_labs+1 end
          end
        end
      end
    end
  end
  s.census_cursor=i+1
  if s.census_cursor==n*n then
    s.last_census=s.census;s.last_census_tick=game.tick
    s.last_census_saturated=s.census_saturated or false
    s.census={};s.census_cursor=0;s.census_saturated=false
  end
end
local function sample(s,p)
  local force=game.forces[p.force];local surface=game.surfaces[1]
  local stats=force.get_item_production_statistics(surface)
  local mined={}
  for _,name in ipairs({"iron-ore","copper-ore","coal","stone"}) do
    mined[name]=stats.get_input_count(name)
  end
  local pair=p.station and p.station.valid and storage.tech_priests.pairs_by_station[p.station.unit_number]
  local gate=pair and pair.local_infrastructure_gate_0640
  local request=pair and pair.infrastructure_recipe_request_0647
  local task=pair and pair.construction_task_0338
  local dispatch=pair and pair.dispatcher_0510
  local order=pair and pair.order_queue_0469 and pair.order_queue_0469.current
  local fanout=pair and pair.last_recipe_fanout_refusal_0284
  local move=pair and pair.movement_request_0418
  local fetch=pair and pair.logistics_fetch_0527
  local science={};local consumed={}
  for _,name in ipairs({"automation-science-pack","logistic-science-pack",
      "military-science-pack","chemical-science-pack","production-science-pack",
      "utility-science-pack","space-science-pack"}) do
    if prototypes.item[name] then
      science[name]=stats.get_input_count(name)
      consumed[name]=stats.get_output_count(name)
    end
  end
  local research=force.current_research
  local op=pair and pair.independent_emergency_operation_0184
  local combat=pair and pair.combat_target
  local craft=pair and pair.emergency_craft
  local direct=pair and pair.direct_acquisition_task_0336
  local inventory=p.station and p.station.valid
    and p.station.get_inventory(defines.inventory.chest)
  local bootstrap_stock={}
  if inventory then
    for _,name in ipairs({"stone","stone-furnace","iron-ore","iron-plate",
      "copper-ore","copper-plate","coal","tech-priests-emergency-smelter"}) do
      bootstrap_stock[name]=inventory.get_item_count(name)
    end
  end
  emit("SAMPLE",{tick=game.tick,elapsed=game.tick-s.started,force=p.force,
    kind=p.kind,team=p.team,build_events=p.built,lost=p.lost,
    research_finished=p.research,damage_dealt=p.damage_dealt,
    damage_received=p.damage_received,max_build_distance=p.max_build_distance,
    census=(s.last_census or {})[p.force],census_tick=s.last_census_tick,
    census_saturated=s.last_census_saturated,
    ore_production=mined,station_alive=p.station and p.station.valid or false,
    science_production=science,science_consumption=consumed,
    current_research=research and research.name,
    research_progress=research and force.research_progress,
    mode=pair and pair.mode,
    radius=pair and pair.radius,bootstrap_stock=bootstrap_stock,
    bootstrap=pair and pair.bootstrap_mode_0637,
    emergency_craft=craft and {item=craft.item_name or craft.output_item,
      strict=craft.strict_recipe_0647,started_tick=craft.started_tick,
      required_count=craft.required_count,current_kind=craft.current and craft.current.kind},
    direct_acquisition=direct and {item=direct.output_item,
      required_count=direct.required_count,gathered=direct.gathered_units,
      current_kind=direct.current and direct.current.kind},
    independent_operation=op and {enabled=op.enabled,phase=op.phase,
      reason=op.reason,science_item=op.science_item},
    science_planner=pair and pair.magos_science_last_result_1172,
    combat_target=combat and combat.valid and {name=combat.name,
      force=combat.force.name,position=combat.position,health=combat.health},
    infrastructure_plan=pair and pair.master_infrastructure_plan_0644 and {
      stage=pair.master_infrastructure_plan_0644.stage,
      blocker=pair.master_infrastructure_plan_0644.blocker},
    priest_alive=p.priest and p.priest.valid or false,
    current_task=pair and tostring(pair.current_task or pair.task or "unknown") or "none",
    infrastructure_gate=gate and {item=gate.item,state=gate.state,why=gate.why,
      tick=gate.tick,next_retry_tick=gate.next_retry_tick},
    recipe_request=request and {item=request.item,missing=request.missing,
      tick=request.tick,status=request.status},
    construction=task and {item=task.item_name,phase=task.phase,started_tick=task.started_tick},
    dispatcher=dispatch and {tick=dispatch.tick,kind=dispatch.kind,
      action=dispatch.action,detail=dispatch.detail,reason=dispatch.reason},
    requested_item=pair and pair.requested_item,
    active_order=order and {item=order.item,kind=order.kind,status=order.status,
      source=order.source,created_tick=order.created_tick,expires_tick=order.expires_tick},
    fanout_refusal=fanout and {item=fanout.item,missing=fanout.missing,
      reason=fanout.reason,incumbent_item=fanout.incumbent_item,tick=fanout.tick},
    priest_position=p.priest and p.priest.valid and p.priest.position or nil,
    movement=move and {owner=move.owner,reason=move.reason,x=move.x,y=move.y,
      expires_tick=move.expires_tick},
    logistics_fetch=fetch and {phase=fetch.phase,item=fetch.item,
      source_unit=fetch.source_unit,source_name=fetch.source_name,
      x=fetch.x,y=fetch.y,tick=fetch.tick},
    supply_remaining=p.chest and p.chest.valid and p.chest.get_item_count() or 0,
    initial_expansion_kits=p.expansion_stock and p.expansion_stock.count,
    senior_kits_in_magos=p.station and p.station.valid
      and p.station.get_inventory(defines.inventory.chest).get_item_count("senior-cogitator-station") or 0})
end
local function tick(event)
  local s=state();if not s or s.failed or s.finished then return end
  local surface=game.surfaces[1]
  if s.phase=="terrain" then
    if event.tick%5==0 then prepare_terrain(s,surface) end
  elseif s.phase=="resources" then seed_resources(s,surface)
  elseif s.phase=="participants" then
    if event.tick%120==0 then seed_participant(s,surface) end
  else
    census(s,surface)
    local elapsed=game.tick-s.started
    -- One participant sample per tick, one full set per simulation minute.
    local slot=elapsed%3600
    if slot<#s.participants then sample(s,s.participants[slot+1]) end
    if elapsed>0 and elapsed%54000==0 then
      s.checkpoints=s.checkpoints+1
      game.server_save("tp-arena-"..s.preset.."-"..s.seed.."-"..elapsed)
    end
    if elapsed>=config().active_ticks then
      for _,p in ipairs(s.participants) do sample(s,p) end
      s.finished=true
      game.server_save("tp-arena-"..s.preset.."-"..s.seed.."-final")
      emit("COMPLETE",{tick=game.tick,elapsed=elapsed,preset=s.preset,
        seed=s.seed,participants=#s.participants,contacts=s.contacts or {},
        observation_only=true,expansion_success_not_assumed=true})
    end
  end
end
function M.install()
  Registry.on_init(guarded(init),{owner=KEY,route="init",priority=1000})
  local handlers={on_tick=tick,on_entity_damaged=damage,
    on_built_entity=built,on_robot_built_entity=built,
    script_raised_built=built,script_raised_revive=built,
    on_entity_died=function(event)
      if not(state() and state().phase=="active") then return end
      local p=owner(event.entity.force);if p then p.lost=p.lost+1 end
    end,
    on_research_finished=function(event)
      if not(state() and state().phase=="active") then return end
      local p=owner(event.research.force);if p then p.research=p.research+1 end
    end}
  for name,fn in pairs(handlers) do
    assert(Registry.on_event(defines.events[name],guarded(fn),nil,
      {owner=KEY,route=name,priority=1000}),"arena registration failed")
  end
end
return M
