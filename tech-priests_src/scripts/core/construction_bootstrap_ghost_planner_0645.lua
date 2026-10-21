-- scripts/core/construction_bootstrap_ghost_planner_0645.lua
-- Tech Priests 0.1.653
-- Commandless one-ghost construction bootstrap planner.

local M = {}
M.version = "0.1.653"
M.storage_key = "construction_bootstrap_ghost_planner_0645"
M.tick_interval = 83
M.max_pairs_per_pulse = 16
M.retry_ticks = 60 * 10

local CATEGORY_BY_CLASS = { storage = "storage", ["resource-extraction"] = "miner", smelting = "furnace", crafting = "assembler", research = "lab" }
local ENTITY_CATEGORY_BY_NAME = { ["tech-priests-emergency-smelter"] = "emergency-smelter", ["tech-priests-emergency-miner"] = "emergency-miner", ["tech-priests-emergency-assembler"] = "assembler", ["tech-priests-emergency-laboratorium"] = "lab", ["tech-priests-emergency-power-grid"] = "emergency-power-pole", ["tech-priests-emergency-boiler"] = "emergency-powertrain", ["tech-priests-emergency-steam-engine"] = "emergency-powertrain", ["tech-priests-atmospheric-water-condenser"] = "emergency-powertrain" }

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end

local function planning_constraints() local C = rawget(_G, "TechPriestsPlanningConstraints0646"); if not C then local ok, mod = pcall(require, "scripts.core.planning_constraints_0646"); if ok then C = mod end end; return C end
local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}; r.recent = r.recent or {}
  return r
end
local function stat(name, n) local r = root(); r.stats[name] = (tonumber(r.stats[name]) or 0) + (n or 1) end
local function record(action, pair, detail) local r = root(); stat(action); r.recent[#r.recent + 1] = { tick = now(), action = tostring(action or "event"), station = safe(station_unit(pair)), priest = safe(priest_unit(pair)), detail = tostring(detail or "") }; while #r.recent > 100 do table.remove(r.recent, 1) end end

local function entity_exists(name) return name and prototypes and prototypes.entity and prototypes.entity[name] ~= nil end
local function entity_name_for_item(item)
  if not item then return nil end
  if entity_exists(item) then return item end
  if prototypes and prototypes.item and prototypes.item[item] then local ok, result = pcall(function() local pr = prototypes.item[item].place_result; if pr then return pr.name end return nil end); if ok and result and entity_exists(result) then return result end end
  return nil
end
local function category_for(entity_name, class)
  if ENTITY_CATEGORY_BY_NAME[entity_name] then return ENTITY_CATEGORY_BY_NAME[entity_name] end
  local base = CATEGORY_BY_CLASS[class] or "generic"
  if entity_name and prototypes and prototypes.entity and prototypes.entity[entity_name] then local ok, t = pcall(function() return prototypes.entity[entity_name].type end); if ok then if t == "mining-drill" then return "miner" elseif t == "furnace" then return "furnace" elseif t == "assembling-machine" then return "assembler" elseif t == "container" or t == "logistic-container" then return "storage" elseif t == "lab" then return "lab" elseif t == "electric-pole" then return "emergency-power-pole" end end end
  return base
end

local function build_plan(pair, reason)
  local Plan = rawget(_G, "TechPriestsMasterInfrastructurePlan0644")
  if not Plan then local ok, mod = pcall(require, "scripts.core.master_infrastructure_plan_0644"); if ok then Plan = mod end end
  if Plan and type(Plan.build_plan) == "function" then local ok, plan = pcall(Plan.build_plan, pair, reason or "ghost-planner-0645"); if ok and plan then return plan end end
  return pair and pair.master_infrastructure_plan_0644
end
-- Only physically retrievable station stock can justify replacing a
-- non-obstructed bootstrap ghost. A manufacturing output slot, recipe request
-- or virtual planning count cannot authorize destruction of an existing site.
local function general_item_count(pair,item)
  if not (valid_pair(pair) and type(item)=="string") then return 0 end
  local authority=rawget(_G,"TechPriestsStorageRoleAuthority0686")
    or (package.loaded and package.loaded["scripts.core.storage_role_authority_0686"])
  if authority and type(authority.generic_item_count)=="function" then
    local ok,n=pcall(authority.generic_item_count,pair,item)
    if ok then return math.max(0,tonumber(n) or 0) end
  end
  local count=rawget(_G,"tech_priests_generic_station_item_count_0686")
  if type(count)=="function" then
    local ok,n=pcall(count,pair,item)
    if ok then return math.max(0,tonumber(n) or 0) end
  end
  return 0
end

local function plan_site(pair, entity_name, category)
  local Site = rawget(_G, "TECH_PRIESTS_CONSTRUCTION_SITE_PLANNER_0359")
  if not Site then local ok, mod = pcall(require, "scripts.core.construction_site_planner"); if ok then Site = mod end end
  if Site and type(Site.plan_site) == "function" then local ok, pos, why = pcall(Site.plan_site, pair, { item_name = entity_name, entity_name = entity_name, category = category or "generic", source = "construction-bootstrap-ghost-0645" }); if ok then return pos, why end end
  return nil, "site-planner-unavailable"
end
local function active_ghost(pair)
  local rec = pair and pair.construction_bootstrap_ghost_0645
  if type(rec) ~= "table" then return nil, rec end
  if rec.ghost and rec.ghost.valid then return rec.ghost, rec end
  if rec.unit_number and valid_pair(pair) then local ok, found = pcall(function() return pair.station.surface.find_entity("entity-ghost", rec.position) end); if ok and found and found.valid then rec.ghost = found; return found, rec end end
  return nil, rec
end
-- A previously legal ghost can become obstructed when another real machine
-- is constructed alongside it. Factorio ghosts do not reserve collision space.
-- Detect only overlapping *physical* entities: never treat a ghost, character,
-- dropped item, or temporary moving unit as a permanent site obstruction.
local PHYSICAL_BLOCKERS = {
  ["assembling-machine"]=true,["mining-drill"]=true,furnace=true,
  container=true,["logistic-container"]=true,lab=true,
  ["electric-pole"]=true,inserter=true,["transport-belt"]=true,
  ["underground-belt"]=true,splitter=true,pipe=true,
  ["pipe-to-ground"]=true,boiler=true,generator=true,
  ["storage-tank"]=true,wall=true,gate=true,
  ["simple-entity"]=true,tree=true,cliff=true,
}
local function box_bounds(box)
  if not box then return nil end
  local a,b=box.left_top or box[1],box.right_bottom or box[2]
  if not(a and b and a.x and a.y and b.x and b.y)then return nil end
  return math.min(a.x,b.x),math.min(a.y,b.y),
    math.max(a.x,b.x),math.max(a.y,b.y)
end
local function nearby_physical_entities(pair,position)
  if not (valid_pair(pair) and position) then return {} end
  -- One bounded station-local scan serves physical completion and obsolete
  -- site detection; no second entity query on each periodic planning pulse.
  local ok,entities=pcall(function()
    return pair.station.surface.find_entities_filtered({
      position=position,radius=2.25,force=pair.station.force,limit=48
    })
  end)
  return ok and type(entities)=="table" and entities or {}
end
function M.physical_site_obstruction(pair,ghost,nearby)
  if not(valid_pair(pair) and ghost and ghost.valid)then return false end
  local ok,box=pcall(function()return ghost.selection_box end)
  if not ok then return false end
  local gx0,gy0,gx1,gy1=box_bounds(box)
  if not gx0 then return false end
  for _,entity in pairs(nearby or nearby_physical_entities(pair,ghost.position))do
    if entity~=ghost and entity and entity.valid
      and PHYSICAL_BLOCKERS[entity.type] then
      local valid_box,physical=pcall(function()return entity.bounding_box end)
      if valid_box then
        local x0,y0,x1,y1=box_bounds(physical)
        if x0 and gx0<x1 and x0<gx1 and gy0<y1 and y0<gy1 then
          return true,entity
        end
      end
    end
  end
  return false
end

local function target_complete(pair, rec, nearby)
  if not (valid_pair(pair) and rec and rec.entity_name) then return false end
  for _,entity in pairs(nearby or nearby_physical_entities(pair,rec.position)) do
    if entity and entity.valid and entity.name==rec.entity_name
      and entity.position then
      local dx=entity.position.x-rec.position.x
      local dy=entity.position.y-rec.position.y
      -- Nearby machinery of the same type must not masquerade as the item
      -- actually constructed at the reserved ghost position.
      if dx*dx+dy*dy<=0.6*0.6 then return true end
    end
  end
  return false
end

local function science_pack_name(ingredient) if type(ingredient) == "string" then return ingredient end if type(ingredient) ~= "table" then return nil end return ingredient.name or ingredient[1] end
local function technology_unlocked(tech) local ok, researched = pcall(function() return tech.researched end); return ok and researched == true end
local function prerequisites_met(tech) local ok, prereqs = pcall(function() return tech.prerequisites end); if not ok or type(prereqs) ~= "table" then return true end for _, prereq in pairs(prereqs) do if prereq and not technology_unlocked(prereq) then return false end end return true end
local function next_small_science_objective(pair)
  if not valid_pair(pair) then return nil end
  local force = pair.station.force
  if not (force and force.valid and force.technologies) then return nil end
  local best = nil
  for name, tech in pairs(force.technologies) do
    if tech and tech.valid and not technology_unlocked(tech) and prerequisites_met(tech) then
      local enabled = true; pcall(function() enabled = tech.enabled ~= false end)
      if enabled then
        local unit_count = 0; local ingredients = {}
        pcall(function() unit_count = tonumber(tech.research_unit_count) or 0 end)
        pcall(function() for _, ing in pairs(tech.research_unit_ingredients or {}) do local pack = science_pack_name(ing); if pack then ingredients[#ingredients + 1] = pack end end end)
        local score = unit_count + (#ingredients * 10000)
        if not best or score < best.score or (score == best.score and name < best.name) then table.sort(ingredients); best = { name = name, count = unit_count, packs = ingredients, score = score } end
      end
    end
  end
  return best
end
local function should_bootstrap(pair, plan) return valid_pair(pair) and plan and plan.target and plan.stage ~= "ready" end

local function create_planning_ghost(pair, entity_name, pos)
  if not (valid_pair(pair) and entity_name and pos and pos.x and pos.y) then return nil, "invalid" end
  local ok, ghost = pcall(function() return pair.station.surface.create_entity({ name = "entity-ghost", inner_name = entity_name, position = pos, force = pair.station.force, direction = defines and defines.direction and defines.direction.north or 0, expires = false, raise_built = true }) end)
  if ok and ghost and ghost.valid then return ghost, "ghost-created" end
  return nil, "ghost-create-failed"
end
local function make_record(pair, plan, entity_name, pos, why, ghost)
  local target = plan and plan.target or {}
  local rec = { version = M.version, tick = now(), station = station_unit(pair), entity_name = entity_name, item = target.preferred_item, class = target.class, stage = plan and plan.stage, fallback = target.fallback_item, resource = target.resource, delivery = target.delivery, blocker = target.blocker, reason = target.reason, site_reason = why, position = { x = pos.x, y = pos.y }, status = ghost and "ghosted" or "planned-no-ghost", ghost = ghost, unit_number = ghost and ghost.unit_number or nil, next_science = next_small_science_objective(pair), connection_mode = "manual-priest-transfer", note = "one station-local planning ghost; does not count as completed infrastructure" }
  pair.construction_bootstrap_ghost_0645 = rec
  return rec
end

function M.service_pair(pair, reason, requested_entity)
  local r = root(); if r.enabled == false then return false, "disabled" end
  if not valid_pair(pair) then return false, "invalid-pair" end
  local ghost, rec = active_ghost(pair)
  local nearby=rec and rec.position and nearby_physical_entities(pair,rec.position) or nil
  if rec and target_complete(pair, rec, nearby) then
    -- Physical completion takes precedence over an obsolete planning ghost.
    if ghost and ghost.valid and ghost.ghost_name == rec.entity_name then ghost.destroy({raise_destroy=true}) end
    rec.status = "built"; rec.completed_tick = now(); record("bootstrap-ghost-built-0645", pair, "entity=" .. safe(rec.entity_name)); pair.construction_bootstrap_ghost_0645 = nil
  elseif ghost and rec then
    local occupied,entity=M.physical_site_obstruction(pair,ghost,nearby)
    if occupied then
      -- An in-flight construction task owns the ghost and any removed item.
      -- Wait until it returns custody before retiring the obsolete site.
      if pair.construction_task_0338 or pair.construction_custody_0338 then
        return false,"physical-site-overlap-awaiting-construction-custody"
      end
      local ok,removed=pcall(function()return ghost.destroy({raise_destroy=true})end)
      if not ok or removed==false or ghost.valid then
        return false,"stale-ghost-destroy-refused"
      end
      record("bootstrap-ghost-site-replanned-0645",pair,
        "overlap="..safe(entity and entity.name).." site="..safe(rec.position.x)..","..safe(rec.position.y))
      -- The old discovery candidate belongs to the same superseded
      -- reservation. An unclaimed candidate may be forgotten; a carrying
      -- task has already been excluded above.
      local candidate=pair.construction_candidate_0338
      if type(candidate)=="table"
        and candidate.request_field=="construction_bootstrap_ghost_0645"
        and candidate.entity_name==rec.entity_name
        and candidate.position
        and math.abs(candidate.position.x-rec.position.x)<=0.6
        and math.abs(candidate.position.y-rec.position.y)<=0.6 then
        pair.construction_candidate_0338=nil
      end
      rec.status="retired-overlapped-site"
      pair.construction_bootstrap_ghost_0645=nil
      ghost,rec=nil,nil
    else
      -- An old unfinished mining ghost may outlive the entire research
      -- prerequisite chain. If the current plan names a *different* machine
      -- already physically held in this station's general storage, exchange
      -- only the unclaimed planning ghost. Never discard an in-flight build,
      -- interfere with an explicit reservation, or displace an available
      -- older construction item.
      local plan=not requested_entity and build_plan(pair,
        reason or "superseded-ghost-0645") or nil
      local desired=plan and plan.target and plan.target.preferred_item
      local entity=entity_name_for_item(desired)
      local actionable=entity and entity~=rec.entity_name
        and not pair.construction_task_0338
        and not pair.construction_custody_0338
        and general_item_count(pair,desired)>0
        and general_item_count(pair,rec.item or rec.entity_name)==0
      if actionable then
        local ok,removed=pcall(function()
          return ghost.destroy({raise_destroy=true})
        end)
        if not ok or removed==false or ghost.valid then
          return false,"superseded-ghost-destroy-refused"
        end
        local candidate=pair.construction_candidate_0338
        if type(candidate)=="table"
            and candidate.request_field=="construction_bootstrap_ghost_0645"
            and candidate.entity_name==rec.entity_name
            and candidate.position and rec.position
            and math.abs(candidate.position.x-rec.position.x)<=0.6
            and math.abs(candidate.position.y-rec.position.y)<=0.6 then
          pair.construction_candidate_0338=nil
        end
        record("bootstrap-ghost-physically-stocked-replan-0645",pair,
          "obsolete="..safe(rec.entity_name).." stocked="..safe(entity))
        rec.status="retired-for-stocked-infrastructure"
        pair.construction_bootstrap_ghost_0645=nil
        ghost,rec=nil,nil
      else
        rec.status="ghosted";rec.last_seen_tick=now()
        return false,"active-ghost-present"
      end
    end
  elseif rec and not ghost then local last = tonumber(rec.tick or 0) or 0; if now() - last < M.retry_ticks then return false, "ghost-missing-cooldown" end; record("bootstrap-ghost-lost-0645", pair, "entity=" .. safe(rec.entity_name)); pair.construction_bootstrap_ghost_0645 = nil end
  local plan
  if requested_entity then
    if not entity_exists(requested_entity) then return false, "requested-entity-missing" end
    plan = { stage="emergency-network-recovery", target={
      preferred_item=requested_entity,
      class=category_for(requested_entity),
      reason=reason or "network-reservation"
    } }
  else
    plan = build_plan(pair, reason or "service")
  end
  if not should_bootstrap(pair, plan) then return false, "not-bootstrap" end
  local target = plan.target or {}; local item = target.preferred_item; local entity_name = entity_name_for_item(item)
  if not entity_name then record("bootstrap-ghost-no-entity-0645", pair, "item=" .. safe(item) .. " stage=" .. safe(plan.stage)); return false, "target-not-placeable" end
  local C = planning_constraints(); if C and type(C.entity_unlocked) == "function" then local unlocked, why = C.entity_unlocked(pair, entity_name); if not unlocked then record("bootstrap-ghost-technology-locked-0646", pair, "entity=" .. safe(entity_name) .. " why=" .. safe(why)); return false, why or "technology-locked" end end
  local pos,why
  if type(target.site_position)=="table" then
    -- Resource machines expose the output coordinate themselves. Ordinary
    -- station spiral placement is not a functional drill output connection.
    local fixed=target.site_position
    pos={x=fixed.x,y=fixed.y}
    local legal,allowed=pcall(function()
      return pair.station.surface.can_place_entity({
        name=entity_name,position=pos,force=pair.station.force})
    end)
    local owned=true
    if C and type(C.interior_position_allowed)=="function" then
      owned=C.interior_position_allowed(pair,pos)
    end
    if not (legal and allowed==true and owned==true) then
      pos=nil;why="fixed-drill-output-position-blocked"
    else why="drill-output-verified" end
  else
    pos,why=plan_site(pair,entity_name,category_for(entity_name,target.class))
  end
  if not pos then pair.construction_bootstrap_ghost_0645 = { version = M.version, tick = now(), station = station_unit(pair), entity_name = entity_name, item = item, class = target.class, stage = plan.stage, status = "blocked-no-site", blocker = why or "no-site", next_science = next_small_science_objective(pair) }; record("bootstrap-ghost-no-site-0645", pair, "entity=" .. safe(entity_name) .. " why=" .. safe(why)); return false, why or "no-site" end
  local new_ghost, made = create_planning_ghost(pair, entity_name, pos)
  local new_rec = make_record(pair, plan, entity_name, pos, why, new_ghost)
  if new_ghost then record("bootstrap-ghost-created-0645", pair, "entity=" .. safe(entity_name) .. " stage=" .. safe(plan.stage) .. " science=" .. safe(new_rec.next_science and new_rec.next_science.name)); return true, made end
  record("bootstrap-ghost-create-failed-0645", pair, "entity=" .. safe(entity_name)); return false, made
end

function M.service_all(reason)
  local r = root(); if r.enabled == false then return 0 end
  local n = 0
  for _, pair in pairs(pair_map()) do if n >= M.max_pairs_per_pulse then break end if valid_pair(pair) then local ok, acted = pcall(M.service_pair, pair, reason or "pulse"); if ok and acted then n = n + 1 end end end
  r.last_service_tick = now(); return n
end

function M.install()
  if M.installed then return true end
  local owner = nil
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not broker then
    local ok, found = pcall(require, "scripts.core.runtime_tick_broker")
    if ok then broker = found end
  end
  if broker and type(broker.register_service) == "function" then
    local ok, service = pcall(broker.register_service, {
      name = "construction_bootstrap_ghost_planner_0645",
      category = "construction",
      interval = M.tick_interval,
      priority = 60,
      budget = 6,
      fn = function(event, budget)
        local acted = M.service_all("broker")
        return { processed = acted, acted = acted, detail = "construction bootstrap ghost planning" }
      end,
      note = "one station-local planning ghost at a time from master infrastructure plan"
    })
    if ok and service then owner = "runtime-tick-broker" end
  end
  if not owner then
    local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if not registry then
      local ok, found = pcall(require, "scripts.core.runtime_event_registry")
      if ok then registry = found end
    end
    if registry and type(registry.on_nth_tick) == "function" then
      local cadence = registry.on_nth_tick(M.tick_interval, function()
        M.service_all("nth-tick")
      end, {
        owner = "construction_bootstrap_ghost_planner_0645",
        route = "construction-bootstrap-ghost-fallback",
        category = "construction",
        priority = "early"
      })
      if cadence then owner = "runtime-event-registry" end
    end
  end
  if not owner then return false end
  root()
  _G.TechPriestsConstructionBootstrapGhostPlanner0645 = M
  M.route_owner = owner
  M.installed = true
  if log then log("[Tech-Priests 0.1.653] construction bootstrap ghost planner installed via " .. owner) end
  return true
end

return M
