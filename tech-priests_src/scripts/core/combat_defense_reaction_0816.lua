-- Hostile-damage wake signal for the canonical defensive perimeter owner.
-- No inventory, entity placement, technology or task ownership is changed here.
local M={version="0.1.674-dev",max_incidents=8,repeat_window=240,
  incident_lifetime_ticks=216000,incident_merge_distance_sq=144,
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
local function pending_for(state,id)
  for _,threat in ipairs(state.threats or {}) do
    if threat.incident_id_0817==id then return true end
  end
  return false
end
local function queue_incident(state,incident)
  state.threats=state.threats or {}
  if pending_for(state,incident.id) then return end
  if #state.threats>=M.max_incidents then return end
  state.threats[#state.threats+1]={
    position={x=incident.defense_position.x,y=incident.defense_position.y},
    damage_position={x=incident.position.x,y=incident.position.y},
    tick=incident.last_tick,incident_id_0817=incident.id,
    reason="persistent-hostile-incident",
    victim=incident.victim,attacker=incident.attacker,
  }
  incident.status="defense-requested"
end
local function forget_pending(state,id)
  for i=#(state.threats or {}),1,-1 do
    if state.threats[i].incident_id_0817==id then
      table.remove(state.threats,i)
    end
  end
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
  local damage=tonumber(event and (event.final_damage_amount or event.damage_amount)) or 0
  if damage<=0 or not (victim and victim.valid and cause and cause.valid
      and victim.force and cause.force and victim.surface)
      or not enemy_force(victim.force,cause.force) then
    return false,"not-hostile-damage"
  end
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
    tick=tick,victim=victim.name,attacker=cause.name,
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
  local approach=cause.position or victim.position
  local dx=approach.x-station.position.x
  local dy=approach.y-station.position.y
  local length=math.sqrt(dx*dx+dy*dy)
  if length<0.01 then dx=1;dy=0;length=1 end
  local perimeter={
    x=station.position.x+radius*dx/length,
    y=station.position.y+radius*dy/length,
  }
  local incidents=state.hostile_incidents_0817 or {}
  state.hostile_incidents_0817=incidents
  local incident=nil
  for _,candidate in ipairs(incidents) do
    if candidate.expires_at>tick
        and candidate.surface_index==victim.surface.index
        and candidate.force_name==victim.force.name
        and dist2(candidate.position,pos)<=M.incident_merge_distance_sq then
      incident=candidate
      break
    end
  end
  local repeat_hit=incident~=nil
  if not incident then
    if #incidents>=M.max_incidents then
      -- Evict lowest-value completed history first, never alter live tasks.
      local index=nil
      for i,entry in ipairs(incidents) do
        local in_progress=selected.defense_task_0259
            and selected.defense_task_0259.incident_id_0817==entry.id
        if not in_progress and (entry.covered or entry.expires_at<=tick) then
          index=i
          break
        end
      end
      if not index then
        for i,entry in ipairs(incidents) do
          local active=selected.defense_task_0259
              and selected.defense_task_0259.incident_id_0817==entry.id
          if not active then index=i;break end
        end
      end
      if not index then return true,"capacity-active-jobs" end
      forget_pending(state,incidents[index].id)
      table.remove(incidents,index)
    end
    state.hostile_incident_sequence_0817=
        (state.hostile_incident_sequence_0817 or 0)+1
    incident={
      id=state.hostile_incident_sequence_0817,
      station_unit=station.unit_number,
      surface_index=victim.surface.index,
      force_name=victim.force.name,
      position=pos,defense_position=perimeter,
      victim=victim.name,attacker=cause.name,
      first_tick=tick,last_tick=tick,hit_count=0,total_damage=0,
      expires_at=tick+M.incident_lifetime_ticks,
      status="detected",covered=false,
      repairs_required=true,walls_required=true,
      ammo_resupply_required=false,
    }
    incidents[#incidents+1]=incident
  end
  incident.hit_count=incident.hit_count+1
  incident.total_damage=incident.total_damage+damage
  incident.last_tick=tick
  incident.attacker=cause.name
  incident.victim=victim.name
  incident.defense_position=perimeter
  incident.expires_at=tick+M.incident_lifetime_ticks
  incident.priority=math.min(100,
    incident.hit_count*3+math.ceil(incident.total_damage/25))
  incident.repairs_required=true
  incident.covered=false
  state.next_incident_review_0817=0
  state.next_scan_tick=0
  -- One actionable request per locality, regardless of repeated hits.
  if not (selected.defense_task_0259
      and selected.defense_task_0259.incident_id_0817==incident.id) then
    queue_incident(state,incident)
  end
  state.last_reason="hostile-incident-remembered"
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
