-- Hostile-damage wake signal for the canonical defensive perimeter owner.
-- No inventory, entity placement, technology or task ownership is changed here.
local M={version="0.1.674-dev",max_incidents=8,repeat_window=240}

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
  local last=state.last_hostile_damage_0816
  state.hostile_hits_0816=(state.hostile_hits_0816 or 0)+1
  if state.turrets_built_at_first_hostile_hit_0816==nil then
    state.turrets_built_at_first_hostile_hit_0816=state.turrets_built or 0
  end
  state.last_hostile_damage_0816={tick=tick,
    victim=victim.name,attacker=cause.name,
    position=pos,damage=damage}
  if last and tick-last.tick<M.repeat_window
      and dist2(last.position,pos)<36 then
    return true,"coalesced"
  end
  if #state.threats>=M.max_incidents then table.remove(state.threats,1) end
  state.threats[#state.threats+1]={
    position=pos,tick=tick,reason="hostile-entity-damaged",
    victim=victim.name,attacker=cause.name,
  }
  state.last_reason="hostile-attack-detected"
  return true,"queued"
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
