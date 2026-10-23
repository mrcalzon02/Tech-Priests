-- Hostile-damage wake signal for the canonical defensive perimeter owner.
-- No inventory, entity placement, technology or task ownership is changed here.
-- 60 simulation ticks = one second. A quiet site remains recorded for a
-- full 24 hours; a fresh attack renews a separate ten-minute hot period.
-- Only the canonical perimeter planner is allowed to assign construction.
local M={version="0.1.674-dev",max_incidents=8,repeat_window=240,
  incident_lifetime_ticks=60*60*60*24,
  incident_decay_ticks=60*60*10,
  incident_merge_distance_sq=144,max_anchor_drift_sq=576,
  center_sample_interval_ticks=60,center_smoothing=0.25,
  wake_interval_ticks=300,center_replan_distance_sq=4,
  reconcile_interval_ticks=180}

local function enemy_force(victim,attacker)
  if not (victim and attacker and victim~=attacker) then return false end
  local ok,result=pcall(function() return victim.is_enemy(attacker) end)
  if ok and result==true then return true end
  ok,result=pcall(function() return attacker.is_enemy(victim) end)
  return ok and result==true
end
local function dist2(a,b)
  local dx=(a.x or 0)-(b.x or 0)
  local dy=(a.y or 0)-(b.y or 0)
  return dx*dx+dy*dy
end


-- Incident records contain primitives and plain position tables only. All
-- construction and entity ownership remain with defense_perimeter_0259.
local function forget_pending(state,id)
  for i=#(state.threats or {}),1,-1 do
    if state.threats[i].incident_id_0817==id then
      table.remove(state.threats,i)
    end
  end
end
local function queue_incident(state,incident,allow_new)
  state.threats=state.threats or {}
  for _,threat in ipairs(state.threats) do
    if threat.incident_id_0817==incident.id then
      -- Slide the ONE pending order's target as the site center migrates.
      -- Already-started construction is never retargeted here.
      threat.position={x=incident.defense_position.x,y=incident.defense_position.y}
      threat.damage_position={x=incident.position.x,y=incident.position.y}
      threat.tick=incident.last_tick
      return false
    end
  end
  if allow_new==false or #state.threats>=M.max_incidents then return false end
  state.threats[#state.threats+1]={
    position={x=incident.defense_position.x,y=incident.defense_position.y},
    damage_position={x=incident.position.x,y=incident.position.y},
    tick=incident.last_tick,incident_id_0817=incident.id,
    reason="persistent-hostile-incident",
    victim=incident.victim,attacker=incident.attacker,
  }
  incident.status="defense-requested"
  return true
end

local function normalize_incident(incident,tick)
  -- Upgrade persisted 0817 records from older saves lazily. No engine objects
  -- or new global lifecycle handlers are required.
  local last=tonumber(incident.last_tick)
      or tonumber(incident.first_tick) or tick
  incident.first_tick=tonumber(incident.first_tick) or last
  incident.last_tick=last
  incident.expires_at=math.max(tonumber(incident.expires_at) or 0,
    last+M.incident_lifetime_ticks)
  incident.active_until=tonumber(incident.active_until)
      or last+M.incident_decay_ticks
  incident.position=incident.position or incident.damage_position
      or incident.defense_position or {x=0,y=0}
  incident.origin_position=incident.origin_position or {
    x=incident.position.x,y=incident.position.y}
  incident.approach_position=incident.approach_position or {
    x=incident.defense_position and incident.defense_position.x or incident.position.x,
    y=incident.defense_position and incident.defense_position.y or incident.position.y}
  incident.last_center_tick=tonumber(incident.last_center_tick) or last
  incident.last_wake_tick=tonumber(incident.last_wake_tick) or last
  incident.waves=tonumber(incident.waves) or 1
  incident.hit_count=tonumber(incident.hit_count) or 0
  incident.total_damage=tonumber(incident.total_damage) or 0
end

local function project_perimeter(station,radius,approach)
  local dx=approach.x-station.position.x
  local dy=approach.y-station.position.y
  local length=math.sqrt(dx*dx+dy*dy)
  if length<0.01 then dx=1;dy=0;length=1 end
  return {x=station.position.x+radius*dx/length,
    y=station.position.y+radius*dy/length}
end

-- This bounded service is invoked by the EXISTING perimeter tick authority.
-- Memory survives an enemy disappearing, task interruption and save/load.
function M.reconcile_pair(pair, find_turrets)
  if not (pair and pair.station and pair.station.valid and game) then return 0 end
  local state=pair.defense_perimeter_0259
  if not (state and state.hostile_incidents_0817) then return 0 end
  local tick=game.tick
  if tick<(state.next_incident_review_0817 or 0) then
    return state.unresolved_incidents_0817 or 0
  end
  state.next_incident_review_0817=tick+M.reconcile_interval_ticks
  local pending_count=0
  local active=pair.defense_task_0259
  for i=#state.hostile_incidents_0817,1,-1 do
    local incident=state.hostile_incidents_0817[i]
    normalize_incident(incident,tick)
    -- Timer boundaries are exact even when they fall between the usual
    -- 180-tick reviews. Scheduling only an earlier review remains UPS-bounded.
    if incident.active_until>tick then
      state.next_incident_review_0817=math.min(
        state.next_incident_review_0817,incident.active_until)
    end
    if incident.expires_at>tick then
      state.next_incident_review_0817=math.min(
        state.next_incident_review_0817,incident.expires_at)
    end
    incident.urgency_phase=tick<incident.active_until and "hot" or "cooling"
    incident.effective_priority=incident.urgency_phase=="hot"
      and (incident.priority or 1)
      or math.max(1,math.floor((incident.priority or 1)/4))
    if tick>=(incident.expires_at or 0)
        and not (active and active.incident_id_0817==incident.id) then
      forget_pending(state,incident.id)
      incident.status="expired"
      table.remove(state.hostile_incidents_0817,i)
      state.expired_incidents_0817=(state.expired_incidents_0817 or 0)+1
    else
      -- Reuse the perimeter owner's bounded observation, not a second scan.
      -- Unit tests pass an injected read-only physical-turret lookup.
      local found=(find_turrets and find_turrets(
        pair,incident.defense_position,9)) or {}
      local armed,covered,needs_ammo=false,false,false
      for _,turret in ipairs(found) do
        if turret.valid then
          covered=true
          if turret.type=="ammo-turret" then
            local inv=turret.get_inventory(defines.inventory.turret_ammo)
            if inv and inv.valid and not inv.is_empty() then armed=true
            else needs_ammo=true end
          else
            -- Energy/fluid readiness belongs to the existing support planners.
            armed=true
          end
        end
      end
      incident.covered=covered
      incident.needs_ammo=needs_ammo
      if covered then
        incident.status=armed and "defended" or "resupply-required"
        forget_pending(state,incident.id)
      elseif active and active.incident_id_0817==incident.id then
        incident.status="construction-underway"
        pending_count=pending_count+1
      else
        pending_count=pending_count+1
        queue_incident(state,incident)
      end
    end
  end
  state.unresolved_incidents_0817=pending_count
  return pending_count
end

function M.record_damage(event, supplied_pairs)
  local victim=event and event.entity
  local cause=event and event.cause
  local source=event and event.source
  local damage=tonumber(event and (event.final_damage_amount or event.damage_amount)) or 0
  -- Factorio 2.x identifies the attacking force independently from the
  -- optional LuaEntity cause/source. A genuine biter/projectile hit can carry
  -- event.force even when the original attacker is no longer a valid entity.
  local attacker_force=event and event.force
  if not attacker_force and cause and cause.valid then
    attacker_force=cause.force
  end
  if not attacker_force and source and source.valid then
    attacker_force=source.force
  end
  if damage<=0 or not (victim and victim.valid and victim.force
      and victim.surface and attacker_force)
      or not enemy_force(victim.force,attacker_force) then
    return false,"not-hostile-damage"
  end
  local attacker_name=(cause and cause.valid and cause.name)
      or (source and source.valid and source.name)
      or (attacker_force.name and "force:"..attacker_force.name)
      or "hostile-unknown"
  local pair_map=supplied_pairs or
    (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) or {}
  local selected,selected_dist=nil,nil
  for _,pair in pairs(pair_map) do
    local station=pair and pair.station
    if station and station.valid and pair.priest and pair.priest.valid
        and station.force==victim.force and station.surface==victim.surface then
      local radius=math.max(12,math.min(96,tonumber(pair.radius or pair.base_radius) or 30))
      local d=dist2(station.position,victim.position)
      if d<=radius*radius and (not selected_dist or d<selected_dist) then
        selected=pair;selected_dist=d
      end
    end
  end
  if not selected then return false,"no-local-cogitator" end
  selected.defense_perimeter_0259=selected.defense_perimeter_0259 or {}
  local state=selected.defense_perimeter_0259
  state.threats=state.threats or {}
  local tick=(game and game.tick) or 0
  local pos={x=victim.position.x,y=victim.position.y}
  state.hostile_hits_0816=(state.hostile_hits_0816 or 0)+1
  if state.turrets_built_at_first_hostile_hit_0816==nil then
    state.turrets_built_at_first_hostile_hit_0816=state.turrets_built or 0
  end
  state.last_hostile_damage_0816={
    tick=tick,victim=victim.name,attacker=attacker_name,
    position=pos,damage=damage,
  }
  local station=selected.station
  local radius=tonumber(selected.radius or selected.base_radius) or 20
  if type(_G.refresh_pair_radius)=="function" then
    local ok,r=pcall(_G.refresh_pair_radius,selected)
    if ok and tonumber(r) then radius=tonumber(r) end
  elseif type(_G.get_station_operating_radius)=="function" then
    local ok,r=pcall(_G.get_station_operating_radius,station)
    if ok and tonumber(r) then radius=tonumber(r) end
  end
  radius=math.max(8,math.min(96,radius))-1
  local approach=victim.position
  if cause and cause.valid and cause.surface==victim.surface then
    approach=cause.position
  elseif source and source.valid and source.surface==victim.surface then
    approach=source.position
  end
  local incidents=state.hostile_incidents_0817 or {}
  state.hostile_incidents_0817=incidents
  local incident,best_dist=nil,nil
  for _,candidate in ipairs(incidents) do
    normalize_incident(candidate,tick)
    local distance=dist2(candidate.position,pos)
    if candidate.expires_at>tick
        and candidate.surface_index==victim.surface.index
        and candidate.force_name==victim.force.name
        and candidate.station_unit==station.unit_number
        and distance<=M.incident_merge_distance_sq
        and dist2(candidate.origin_position,pos)<=M.max_anchor_drift_sq
        and (not best_dist or distance<best_dist) then
      incident=candidate;best_dist=distance
    end
  end
  local repeat_hit=incident~=nil
  if not incident then
    if #incidents>=M.max_incidents then
      -- Keep unresolved/hot locations. Reclaim only expired or cooled
      -- and defended records; do not evict active construction ownership.
      local index,best_age=nil,nil
      for i,entry in ipairs(incidents) do
        local in_progress=selected.defense_task_0259
            and selected.defense_task_0259.incident_id_0817==entry.id
        local reclaimable=not in_progress
            and (entry.expires_at<=tick
              or (entry.covered and entry.active_until<=tick))
        if reclaimable and (not best_age or entry.last_tick<best_age) then
          index=i;best_age=entry.last_tick
        end
      end
      if not index then
        state.suppressed_new_incidents_0817=
            (state.suppressed_new_incidents_0817 or 0)+1
        return true,"capacity-suppressed"
      end
      forget_pending(state,incidents[index].id)
      table.remove(incidents,index)
    end
    local max_id=state.hostile_incident_sequence_0817 or 0
    for _,entry in ipairs(incidents) do
      max_id=math.max(max_id,tonumber(entry.id) or 0)
    end
    state.hostile_incident_sequence_0817=max_id+1
    incident={
      id=state.hostile_incident_sequence_0817,
      station_unit=station.unit_number,
      surface_index=victim.surface.index,
      force_name=victim.force.name,
      position=pos,origin_position={x=pos.x,y=pos.y},
      approach_position={x=approach.x,y=approach.y},
      defense_position=project_perimeter(station,radius,approach),
      victim=victim.name,attacker=attacker_name,
      first_tick=tick,last_tick=tick,last_center_tick=tick,
      hit_count=0,total_damage=0,waves=1,
      active_until=tick+M.incident_decay_ticks,
      expires_at=tick+M.incident_lifetime_ticks,
      status="detected",covered=false,
      repairs_required=true,walls_required=true,
      ammo_resupply_required=false,
    }
    incidents[#incidents+1]=incident
  end
  local new_wave=repeat_hit and tick>=incident.active_until
  local old_defense=incident.defense_position
  local center_moved=false
  if repeat_hit and tick-incident.last_center_tick
      >=M.center_sample_interval_ticks then
    local alpha=M.center_smoothing
    incident.position={
      x=incident.position.x+alpha*(pos.x-incident.position.x),
      y=incident.position.y+alpha*(pos.y-incident.position.y)}
    incident.approach_position={
      x=incident.approach_position.x+
        alpha*(approach.x-incident.approach_position.x),
      y=incident.approach_position.y+
        alpha*(approach.y-incident.approach_position.y)}
    incident.defense_position=project_perimeter(
      station,radius,incident.approach_position)
    incident.last_center_tick=tick
    center_moved=dist2(old_defense,incident.defense_position)
        >=M.center_replan_distance_sq
  end
  if new_wave then incident.waves=incident.waves+1 end
  incident.hit_count=incident.hit_count+1
  incident.total_damage=incident.total_damage+damage
  incident.last_tick=tick
  incident.attacker=attacker_name
  incident.victim=victim.name
  incident.active_until=tick+M.incident_decay_ticks
  incident.expires_at=tick+M.incident_lifetime_ticks
  incident.urgency_phase="hot"
  incident.priority=math.min(100,
    incident.hit_count*3+math.ceil(incident.total_damage/25))
  incident.effective_priority=incident.priority
  incident.repairs_required=true
  -- Never discard last-observed physical coverage on every damage event.
  -- The bounded perimeter review is the authority that may decide a turret
  -- was destroyed, uncovered or needs resupply.
  local wake=not repeat_hit or new_wave
      or (center_moved and tick-(incident.last_wake_tick or 0)
         >=M.wake_interval_ticks)
  if wake then
    incident.last_wake_tick=tick
    state.next_incident_review_0817=0
    state.next_scan_tick=0
    state.last_reason=new_wave and "hostile-incident-reactivated"
      or (repeat_hit and "hostile-incident-center-shifted"
        or "hostile-incident-remembered")
  end
  -- Only the first hit may immediately create a new construction notice.
  -- Subsequent hits slide an existing notice, but the bounded physical
  -- coverage reviewer alone may requeue a consumed/defended incident.
  -- This prevents damage bursts from spawning duplicate turret orders.
  if not (selected.defense_task_0259
      and selected.defense_task_0259.incident_id_0817==incident.id) then
    queue_incident(state,incident,not repeat_hit)
  end
  return true,repeat_hit and "refreshed" or "queued"
end

function M.install()
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  if not (registry and type(registry.on_event)=="function" and defines
      and defines.events and defines.events.on_entity_damaged) then
    error("canonical hostile-damage event registry unavailable")
  end
  local registered=registry.on_event(defines.events.on_entity_damaged,
    M.record_damage,nil,{
      owner="combat_defense_reaction_0816",route="hostile-entity-damaged",
      category="combat",priority=50,
      note="wake existing physical defense planner on real hostile damage",
    })
  if not registered then error("hostile-damage route registration failed") end
  return true
end

return M
