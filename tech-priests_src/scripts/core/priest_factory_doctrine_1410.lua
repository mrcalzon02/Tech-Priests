-- 1410: the *actual planning priest's* live doctrine is advisory geometry.
-- A priest may prefer a main bus, compact direct insertion or rail frontage,
-- but personality NEVER bypasses native placement, stock, ownership, 0338,
-- pending construction, player-built structures or the one-object JIT gate.
local M={version="0.1.681.1410",read_only=true,max_candidates=6}
local Map=require("scripts.core.doctrine_map")
local Policy=require("scripts.core.factory_doctrine_organization_1268")
local function finite(n)
  return type(n)=="number" and n==n and n<math.huge and n>-math.huge
end
local function point(p)
  return type(p)=="table" and finite(p.x) and finite(p.y)
    and math.abs(p.x)<1000000 and math.abs(p.y)<1000000
end
local function valid(e) return e and e.valid==true end
local function pair_identity(pair)
  local station=pair and pair.station
  local priest=pair and pair.priest
  local tp=storage and storage.tech_priests
  if not(valid(station) and valid(priest)
    and station.unit_number and priest.unit_number
    and station.force and priest.force==station.force
    and station.surface and priest.surface==station.surface
    and type(tp)=="table"
    and type(tp.pairs_by_station)=="table"
    and tp.pairs_by_station[station.unit_number]==pair)then
    return nil,"unregistered-or-foreign-planning-priest"
  end
  return tp,nil
end
function M.active_policy(pair)
  local tp,why=pair_identity(pair)
  if not tp then return nil,why end
  local station_unit=pair.station.unit_number
  local profile_source="no-established-priest-doctrine"
  local key=nil
  -- Conclave alignment is the live doctrine, not the ORIGINAL random school.
  -- Read current_camp without causing alignment decay or starting an argument.
  local alignment=tp.doctrine_argument_0370
  local row=alignment and alignment.by_station
    and alignment.by_station[tostring(station_unit)]
  if type(row)=="table" and row.current_camp~=nil then
    if not Map.by_key[row.current_camp]then
      return nil,"unknown-live-priest-doctrine"
    end
    key=row.current_camp
    profile_source="live-priest-alignment-0370"
  else
    local memory=tp.station_work_state_memory_0366
    local profile=memory and memory.by_station
      and memory.by_station[tostring(station_unit)]
    profile=profile and profile.priest_profile_0367
    if type(profile)=="table"then
      local school=profile.doctrine
      local candidate=profile.current_doctrine_camp_0370
        or profile.doctrine_camp
      if candidate~=nil then
        if not Map.by_key[candidate] then
          return nil,"unknown-priest-dossier-doctrine"
        end
        key=candidate
        profile_source="existing-priest-dossier-0367"
      elseif type(school)=="string"and Map.by_school[school]then
        key=Map.by_school[school].camp
        profile_source="existing-priest-school-0367"
      elseif school~=nil then
        return nil,"unknown-priest-school"
      end
    end
  end
  local profile,error=Policy.policy(key)
  if not profile then return nil,error end
  profile.owner_station_unit=station_unit
  profile.planning_priest_unit=pair.priest.unit_number
  profile.source=profile_source
  profile.read_only=true
  profile.construction_authorized=false
  return profile,nil
end
local function distance(a,b)
  local dx=a.x-b.x
  local dy=a.y-b.y
  return math.sqrt(dx*dx+dy*dy)
end
local function line_offset(p,ref,axis)
  if axis=="horizontal"then return math.abs(p.y-ref.y)end
  if axis=="vertical"then return math.abs(p.x-ref.x)end
  return 0
end
local function grid_offset(p,ref)
  -- A proposed 8-tile block grid is a preference only. No rail, pole,
  -- platform clearance or completed block is inferred from this score.
  local dx=math.abs(p.x-ref.x)%8
  local dy=math.abs(p.y-ref.y)%8
  return math.min(dx,8-dx)+math.min(dy,8-dy)
end
local function candidate_score(profile,p,candidate,options)
  local key=profile.key
  local anchor=options.anchor
  local dist=distance(anchor,p)
  local axis=options.preferred_axis
  local score=dist
  if key=="main_bus"then
    score=dist+8*line_offset(p,anchor,axis)
  elseif key=="city_block"then
    score=dist+5*grid_offset(p,options.grid_origin or anchor)
  elseif key=="belt_balancer"then
    score=dist+7*line_offset(p,anchor,axis)
  elseif key=="direct_insertion"then
    -- A short verified native pickup/drop can be preferred; an unobserved
    -- machine adjacency never becomes a physical handoff.
    if candidate.native_direct_handoff_verified==true then
      score=score-12
    end
  elseif key=="rail_megabase"then
    if options.native_train_stop_verified==true
      and point(options.train_stop_position)then
      score=0.35*dist+0.65*distance(p,options.train_stop_position)
    end
  elseif key=="distributed_mini_factories"then
    if options.native_local_pod_verified==true
      and point(options.local_pod_position)then
      score=0.4*dist+0.6*distance(p,options.local_pod_position)
    end
  elseif key=="bot_mall"then
    if candidate.native_logistic_network_verified==true then
      score=score-6
    end
  elseif key=="beaconed_modules"then
    if candidate.native_beacon_and_power_verified==true then
      score=score-6
    end
  elseif key=="circuit_control"or key=="sushi"or key=="quality_sorting"then
    -- Advanced loops and filtering need actual native control/quality proof.
    -- Until then this doctrine uses the safe local geometric candidate.
    if candidate.native_advanced_topology_verified==true then
      score=score-4
    end
  elseif key=="space_platform"then
    if candidate.native_platform_surface_verified==true then
      score=score-4
    end
  end
  -- Rush-bootstrap and mixed-spaghetti favor the shortest legal local
  -- candidate. No recipe tree, route-wide A* or entity-ghost created here.
  return score
end

-- Rank only a handful of ALREADY native-verified sites for the SAME immediate
-- object; no multi-object blueprint, expensive surface scan, or future stage.
function M.select_immediate_site(pair,stage,candidates,options)
  local profile,why=M.active_policy(pair)
  if not profile then return nil,why end
  options=options or{}
  if type(stage)~="table" or type(stage.key)~="string"
    or type(stage.name)~="string" or type(candidates)~="table"
    or #candidates<1 or #candidates>M.max_candidates
    or not point(options.anchor)then
    return nil,"invalid-or-unbounded-current-object-sites"
  end
  if options.preferred_axis~=nil
    and options.preferred_axis~="horizontal"
    and options.preferred_axis~="vertical"then
    return nil,"invalid-doctrinal-factory-axis"
  end
  local radius=options.radius or 96
  if not(finite(radius) and radius>0 and radius<=96)then
    return nil,"invalid-native-local-site-envelope"
  end
  local best,best_score=nil,nil
  for index=1,#candidates do
    local c=candidates[index]
    local p=c and c.position
    if type(c)=="table" and c.role==stage.key
      and c.entity_name==stage.name
      and point(p) and c.native_site_verified==true
      and c.real_item_available==true
      and distance(options.anchor,p)<=radius then
      local score=candidate_score(profile,p,c,options)
      if best_score==nil or score<best_score-0.000001
        or (math.abs(score-best_score)<0.000001
           and (p.x<best.position.x
             or(p.x==best.position.x and p.y<best.position.y)))then
        best,best_score=c,score
      end
    end
  end
  if not best then return nil,"no-native-verified-current-object-site"end
  return{
    role=stage.key,entity_name=stage.name,
    item_name=best.item_name or stage.name,
    position={x=best.position.x,y=best.position.y},
    direction=best.direction,
    native_site_verified=true,real_item_available=true,
    doctrine_key=profile.key,
    doctrine_source=profile.source,
    planning_priest_unit=profile.planning_priest_unit,
    native_site_choice_only=true,
    candidate_count_examined=#candidates,
    physically_built=false,construction_authorized=false,
    physical_transport_verified=false,read_only=true,
  },"priest-doctrine-ranked-current-object"
end
return M
