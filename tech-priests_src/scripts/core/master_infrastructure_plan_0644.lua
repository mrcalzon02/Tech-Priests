-- scripts/core/master_infrastructure_plan_0644.lua
-- Tech Priests 0.1.653
-- Commandless station-local infrastructure survey planner.

local M = {}
M.version = "0.1.653"
M.storage_key = "master_infrastructure_plan_0644"
M.tick_interval = 97
M.max_pairs_per_pulse = 24
M.default_radius = 36

local RESOURCE_PRIORITY = { ["iron-ore"] = 10, ["copper-ore"] = 20, coal = 30, stone = 40, ["uranium-ore"] = 90 }
local TARGETS = {
  smelter = { class = "smelting", stage = "bootstrap-smelting", item = "tech-priests-emergency-smelter", fallback = "stone-furnace", delivery = "direct-ore-and-fuel-service" },
  storage = { class = "storage", stage = "bootstrap-storage", item = "tech-priests-martian-stone-cache", fallback = "wooden-chest", delivery = "place-near-station" },
  miner = { class = "resource-extraction", stage = "bootstrap-mining", item = "tech-priests-emergency-miner", fallback = "burner-mining-drill", delivery = "direct-service-until-belts" },
  drill_receiver = { class = "storage", stage = "mining-output-buffer", item = "iron-chest", fallback = "wooden-chest", delivery = "build-at-drill-drop-position" },
  assembler = { class = "crafting", stage = "basic-crafting", item = "tech-priests-emergency-assembler", fallback = "assembling-machine-1", delivery = "place-near-storage" },
  lab = { class = "research", stage = "research-readiness", item = "tech-priests-emergency-laboratorium", fallback = "lab", delivery = "place-after-basic-crafting" },
  inserter = { class = "material-transfer", stage = "automation-inserters", item = "burner-inserter", fallback = "inserter", delivery = "orient-pickup-and-drop-between-verified-machines" },
  belt = { class = "material-transport", stage = "automation-belts", item = "transport-belt", delivery = "route-between-verified-source-and-consumer" },
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function dist_sq(a, b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

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
local function record(action, pair, detail) local r = root(); stat(action); r.recent[#r.recent + 1] = { tick = now(), action = tostring(action or "event"), station = safe(station_unit(pair)), detail = tostring(detail or "") }; while #r.recent > 80 do table.remove(r.recent, 1) end end

local function radius_for(pair)
  if not valid_pair(pair) then return M.default_radius end
  if type(_G.get_station_operating_radius) == "function" then local ok, r = pcall(_G.get_station_operating_radius, pair.station); if ok and tonumber(r) then return math.max(8, math.min(96, tonumber(r))) end end
  return math.max(8, math.min(96, tonumber(pair.radius) or M.default_radius))
end
local function safe_inventory(entity, id) if not (valid(entity) and entity.get_inventory and id) then return nil end local ok, inv = pcall(function() return entity.get_inventory(id) end); if ok and inv and inv.valid then return inv end return nil end
local function inv_count(inv, item) if not (inv and inv.valid and item) then return 0 end local ok, n = pcall(function() return inv.get_item_count(item) end); return ok and (tonumber(n) or 0) or 0 end
local function station_count(pair, item)
  local n, station_in_sources = 0, false
  if type(_G.tech_priests_inventory_steward_sources_for_pair) == "function" then
    local ok, sources = pcall(_G.tech_priests_inventory_steward_sources_for_pair, pair)
    if ok and type(sources) == "table" then
      for _, src in ipairs(sources) do
        if src and src.inv and src.inv.valid then
          n = n + inv_count(src.inv, item)
          if src.entity == pair.station then station_in_sources = true end
        end
      end
    end
  end
  -- The steward's generic sources already include the station chest.
  -- Counting it again invents apparent ingredients and misroutes crafting.
  if not station_in_sources and defines and defines.inventory then
    n = n + inv_count(safe_inventory(pair.station, defines.inventory.chest), item)
  end
  return n
end
local function unlocked_recipe(pair, item)
  local policy = rawget(_G, "TechPriestsPlanningConstraints0646")
  if not policy then local ok, mod = pcall(require, "scripts.core.planning_constraints_0646"); if ok then policy = mod end end
  if not (policy and type(policy.item_unlocked) == "function") then return false end
  local ok, allowed = pcall(policy.item_unlocked, pair.station.force, item)
  return ok and allowed == true
end
local function craft_feasibility(pair, item)
  if not item then return false, "no-item" end
  if station_count(pair, item) > 0 then return true, "stocked" end
  if not unlocked_recipe(pair, item) then return false, "technology-locked-or-no-recipe" end
  local recipes = pair.station.force.recipes
  for _, recipe in pairs(recipes or {}) do
    local enabled, produces = false, false
    pcall(function()
      enabled = recipe.enabled == true
      for _, product in pairs(recipe.products or {}) do if product.name == item then produces = true end end
    end)
    if enabled and produces then
      local missing = {}
      local craftable = true
      pcall(function()
        for _, ingredient in pairs(recipe.ingredients or {}) do
          if ingredient.type == "fluid" then
            craftable = false; missing[#missing+1] = "fluid:" .. ingredient.name
          elseif station_count(pair, ingredient.name) < (ingredient.amount or 1) then
            craftable = false; missing[#missing+1] = ingredient.name
          end
        end
      end)
      if craftable then return true, "ingredients-stocked" end
      return false, "missing-ingredients:" .. table.concat(missing, ",")
    end
  end
  return false, "recipe-unavailable"
end
local function item_available(pair, emergency, standard)
  local standard_ok, standard_why = craft_feasibility(pair, standard)
  if standard_ok then return standard, emergency, standard_why end
  local emergency_ok, emergency_why = craft_feasibility(pair, emergency)
  if emergency_ok then return emergency, standard, "emergency-scarcity:" .. standard_why end
  -- If neither device can be crafted yet, the cheap, enabled emergency recipe
  -- is the bootstrap material goal. Selecting the standard recipe here creates
  -- a burner-drill ghost before the priest can afford gears and a furnace.
  -- Once an emergency miner actually exists, choose() separately pursues the
  -- normal drill; neither machine is deleted or counted as the other.
  if emergency and type(emergency_why) == "string"
      and emergency_why:find("^missing%-ingredients:")
      and not emergency_why:find("fluid:", 1, true) then
    return emergency, standard, "emergency-bootstrap:" .. emergency_why
      .. ";standard:" .. standard_why
  end
  -- A locked, absent, or unsupported emergency recipe must not bypass real
  -- technology and ingredient requirements for standard machinery.
  return standard or emergency, emergency, "standard:" .. standard_why .. ";emergency:" .. emergency_why
end
local function scan_resources(pair)
  local out = {}; if not valid_pair(pair) then return out end
  local r = radius_for(pair); local ok, ents = pcall(function() return pair.station.surface.find_entities_filtered({ position = pair.station.position, radius = r, type = "resource" }) end)
  if ok and ents then for _, e in pairs(ents) do if valid(e) and dist_sq(e.position, pair.station.position) <= r*r and (not e.amount or e.amount > 0) then local name=e.name; out[name]=out[name] or { name=name, count=0, amount=0 }; out[name].count=out[name].count+1; out[name].amount=out[name].amount+(tonumber(e.amount) or 0) end end end
  return out
end
local function entity_role(e)
  if not valid(e) then return nil end
  if e.type == "mining-drill" then return e.name == "tech-priests-emergency-miner" and "emergency-miner" or "normal-miner" end
  if e.type == "furnace" then return "normal-smelter" end
  if e.type == "assembling-machine" then if e.name == "tech-priests-emergency-smelter" then return "emergency-smelter" elseif e.name == "tech-priests-emergency-miner" then return "emergency-miner" elseif e.name == "tech-priests-emergency-assembler" then return "emergency-assembler" end return "normal-assembler" end
  if e.type == "container" or e.type == "logistic-container" then return "storage" end
  if e.type == "lab" then return "lab" end
  if e.type == "inserter" then return "inserter" end
  if e.type == "transport-belt" then return "belt" end
  return nil
end
local function scan_roles(pair)
  local roles = {}; if not valid_pair(pair) then return roles end
  local r = radius_for(pair); local ok, ents = pcall(function() return pair.station.surface.find_entities_filtered({ position = pair.station.position, radius = r, force = pair.station.force, type = { "mining-drill", "furnace", "assembling-machine", "container", "logistic-container", "lab", "inserter", "transport-belt" } }) end)
  if ok and ents then for _, e in pairs(ents) do local role = entity_role(e); if role and e ~= pair.station then roles[role] = (roles[role] or 0) + 1 end end end
  return roles, ok and ents or {}
end
local function has_role(roles, a, b) return (tonumber(roles[a] or 0) > 0) or (b and tonumber(roles[b] or 0) > 0) end
local function first_resource(resources) local names = {}; for name in pairs(resources or {}) do names[#names+1]=name end; table.sort(names, function(a,b) return (RESOURCE_PRIORITY[a] or 1000) < (RESOURCE_PRIORITY[b] or 1000) end); return names[1] end
local function uncovered_drill_output(pair,entities)
  if not valid_pair(pair) then return nil end
  local drills={}
  for _,entity in pairs(entities or {}) do
    if valid(entity) and entity.type=="mining-drill" then
      drills[#drills+1]=entity
    end
  end
  table.sort(drills,function(a,b)
    return dist_sq(a.position,pair.station.position)<dist_sq(b.position,pair.station.position)
  end)
  for _,drill in ipairs(drills) do
    local drop,target=nil,nil
    pcall(function()drop=drill.drop_position;target=drill.drop_target end)
    if drop and not valid(target) then
      local pos={x=math.floor(drop.x)+0.5,y=math.floor(drop.y)+0.5}
      local receiver=false
      for _,entity in pairs(entities or {}) do
        local kind=valid(entity) and entity.type or ""
        if entity~=drill and (kind=="container" or kind=="logistic-container"
          or kind=="transport-belt" or kind=="underground-belt"
          or kind=="splitter" or kind=="furnace" or kind=="assembling-machine")
          and entity.position and dist_sq(entity.position,drop)<1
        then receiver=true;break end
      end
      if not receiver then
        local policy=rawget(_G,"TechPriestsPlanningConstraints0646")
        if not policy or type(policy.interior_position_allowed)~="function"
          or policy.interior_position_allowed(pair,pos) then
          -- Keep the real receiver obligation even if the output tile is
          -- currently obstructed. Ghost placement will fail closed and report
          -- that blocker instead of silently advancing to unrelated industry.
          return pos,drill
        end
      end
    end
  end
  return nil
end
local function choose(pair, resources, roles, entities)
  local t,site_position
  if not has_role(roles, "emergency-smelter", "normal-smelter") then t = TARGETS.smelter
  elseif not has_role(roles, "storage") then t = TARGETS.storage
  elseif first_resource(resources) and not has_role(roles, "emergency-miner", "normal-miner") then
    -- Install a physically craftable emergency miner first when ordinary
    -- equipment still lacks materials. It supplies the bootstrap income.
    t=TARGETS.miner
  else
    -- A running emergency miner supplies a real early income stream. Establish
    -- a small workshop before asking it to fund the costlier standard drill:
    -- the emergency assembler costs one gear and one plate, while a burner
    -- drill additionally demands a furnace and multiple gears/plates.
    -- This is staged progression, not retirement of the emergency miner.
    if has_role(roles, "emergency-miner")
      and not has_role(roles, "emergency-assembler", "normal-assembler") then
      local ready,why=craft_feasibility(pair,TARGETS.assembler.item)
      local fallback_ready,fallback_why=craft_feasibility(pair,TARGETS.assembler.fallback)
      local reachable=ready or fallback_ready
        or (type(why)=="string" and why:find("^missing%-ingredients:")
          and not why:find("fluid:",1,true))
        or (type(fallback_why)=="string" and fallback_why:find("^missing%-ingredients:")
          and not fallback_why:find("fluid:",1,true))
      if reachable then t=TARGETS.assembler end
    end
    -- A physically completed first circuit proves the basic workshop has
    -- started its copper/iron recipe chain. The inexpensive emergency lab may
    -- now be built before waiting on the far costlier burner-drill dependency.
    -- The following standard-drill stage remains mandatory and does not
    -- retire the existing emergency miner or assembler.
    if not t and station_count(pair,"electronic-circuit")>0
        and has_role(roles,"emergency-miner")
        and has_role(roles,"emergency-assembler","normal-assembler")
        and not has_role(roles,"lab") then
      t=TARGETS.lab
    end
    -- An installed emergency miner is an assistant, not proof that normal
    -- mining is finished. After the low-cost workshop/lab bootstrap, continue
    -- pursuing the physical standard drill and its output receiver.
    if not t and first_resource(resources) and has_role(roles, "emergency-miner")
      and not has_role(roles, "normal-miner") then
      local ready,why=craft_feasibility(pair,"burner-mining-drill")
      local materials=type(why)=="string"
        and why:find("^missing%-ingredients:")~=nil
        and why:find("fluid:",1,true)==nil
      if ready or materials then
        t={class="resource-extraction",stage="bootstrap-normal-mining",
          item=nil,fallback="burner-mining-drill",
          delivery="standard-drill-with-emergency-miner-assistance"}
      end
    end
    if not t then
      site_position=uncovered_drill_output(pair,entities)
      if site_position then t=TARGETS.drill_receiver end
    end
  end
  if t then
    local item,fallback,feasibility=item_available(pair,t.item,t.fallback)
    return {status="planned",class=t.class,stage=t.stage,preferred_item=item,
      fallback_item=fallback,site_position=site_position,
      blocker=item and station_count(pair,item)>0 and nil or feasibility,
      delivery=t.delivery,feasibility=feasibility,reason=t.stage}
  end
  if not has_role(roles, "emergency-assembler", "normal-assembler") then t = TARGETS.assembler
  elseif not has_role(roles, "lab") then t = TARGETS.lab
  elseif not has_role(roles, "inserter") then t = TARGETS.inserter
  elseif not has_role(roles, "belt") then t = TARGETS.belt
  else return { status = "planned", class = "idle", stage = "ready", delivery = "none", reason = "local bootstrap spine appears present" } end
  local item, fallback, feasibility = item_available(pair, t.item, t.fallback)
  return { status = "planned", class = t.class, stage = t.stage, preferred_item = item, fallback_item = fallback, resource = first_resource(resources), blocker = item and station_count(pair, item) > 0 and nil or feasibility, delivery = t.delivery, feasibility = feasibility, reason = t.stage }
end
local function cheapest_available_science(pair)
  local force = pair.station.force
  local labs = pair.station.surface.find_entities_filtered({
    position = pair.station.position, radius = radius_for(pair),
    force = force, type = "lab"
  })
  if not labs or #labs == 0 then return nil, "no-laboratory" end
  local best
  for name, tech in pairs(force.technologies or {}) do
    local enabled, researched, prerequisites, ingredients, count = false, true, {}, {}, 0
    pcall(function()
      enabled = tech.enabled == true; researched = tech.researched == true
      prerequisites = tech.prerequisites or {}
      ingredients = tech.research_unit_ingredients or {}
      count = tech.research_unit_count or 0
    end)
    if enabled and not researched then
      local ready = true
      for _, prerequisite in pairs(prerequisites) do if not prerequisite.researched then ready = false; break end end
      local packs, affordable = {}, true
      for _, ingredient in pairs(ingredients) do
        local item = ingredient.name or ingredient[1]
        local amount = ingredient.amount or ingredient[2] or 1
        packs[#packs+1] = {name=item, amount=amount}
        -- Lab inputs are real, engine-owned inventory. Once a pack has
        -- physically moved out of general storage it remains a legitimate
        -- research prerequisite, not a missing or synthetically granted item.
        local available=station_count(pair,item)
        if defines and defines.inventory and defines.inventory.lab_input then
          for _,lab in pairs(labs) do
            available=available+inv_count(
              safe_inventory(lab,defines.inventory.lab_input),item)
          end
        end
        if available < amount then affordable = false end
      end
      if ready and affordable and #packs > 0 then
        local supported = false
        for _, lab in pairs(labs) do
          local accepts = true
          local inputs = lab.prototype.inputs or {}
          for _, pack in ipairs(packs) do
            local found = false
            for _, input in pairs(inputs) do if input.name == pack.name then found = true; break end end
            if not found then accepts = false; break end
          end
          if accepts then supported = true; break end
        end
        if supported then
          local score = #packs * 100000 + count
          if not best or score < best.score or (score == best.score and name < best.name) then
            best = {name=name, score=score, unit_count=count, packs=packs}
          end
        end
      end
    end
  end
  return best, best and "affordable-research" or "no-affordable-research"
end
local function summarize(t) local bits = {}; for k,v in pairs(t or {}) do bits[#bits+1]=k..":"..tostring(type(v)=="table" and (v.count or 1) or v) end; table.sort(bits); return table.concat(bits, ",") end
function M.build_plan(pair, reason)
  if not valid_pair(pair) then return nil, "invalid-pair" end
  local resources = scan_resources(pair); local roles,entities = scan_roles(pair); local target = choose(pair, resources, roles, entities)
  local plan = { version = M.version, tick = now(), station = station_unit(pair), priest = priest_unit(pair), radius = radius_for(pair), reason = reason or "survey", resources = resources, roles = roles, resource_summary = summarize(resources), role_summary = summarize(roles), target = target, stage = target.stage, status = target.status, blocker = target.blocker }
  -- A physically built lab with actual science is eligible for its
  -- cheapest compatible, prerequisite-complete research now. Do not postpone
  -- research behind unrelated drill, inserter or belt construction. Keep
  -- those target/stage obligations intact so the master planner still
  -- proceeds with the rest of the industrial infrastructure.
  plan.science, plan.science_reason = cheapest_available_science(pair)
  if plan.science then
    plan.research_candidate=plan.science.name
    if plan.stage=="ready" then plan.stage="science-ready" end
  end
  pair.master_infrastructure_plan_0644 = plan
  return plan, "planned"
end
local function service_science(pair, plan)
  if not (plan and plan.research_candidate and valid_pair(pair)) then return false, "no-science-candidate" end
  local force = pair.station.force
  local tech = force.technologies and force.technologies[plan.research_candidate]
  if not (tech and tech.valid and tech.enabled and not tech.researched) then return false, "research-not-eligible" end
  -- Never seize a player's or another station's active research.
  if force.current_research or (force.research_queue and #force.research_queue > 0) then return false, "research-already-assigned" end
  local ok, why = pcall(function() force.current_research = tech end)
  if not ok then return false, "research-assignment-failed:" .. safe(why) end
  record("research-assigned-0644", pair, "technology=" .. tech.name)
  return true, "research-assigned"
end
function M.service_pair(pair, reason) local r = root(); if r.enabled == false then return false, "disabled" end; local plan, why = M.build_plan(pair, reason or "service"); if plan then stat("plans_built"); record("plan-built-0644", pair, "stage=" .. safe(plan.stage)); if plan.research_candidate then service_science(pair, plan) end; return true, why end; stat("plans_failed"); return false, why end
function M.service_all(reason) local r=root(); if r.enabled == false then return 0 end; local n=0; for _, pair in pairs(pair_map()) do if n>=M.max_pairs_per_pulse then break end if valid_pair(pair) then local ok=pcall(M.service_pair, pair, reason or "pulse"); if ok then n=n+1 end end end; return n end
local function install_bootstrap() local ok, mod = pcall(require, "scripts.core.construction_bootstrap_ghost_planner_0645"); if ok and mod and type(mod.install)=="function" then pcall(mod.install) end end
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
      name = "master_infrastructure_plan_0644",
      category = "diagnostics",
      interval = M.tick_interval,
      priority = 980,
      budget = 8,
      fn = function(event, budget)
        local acted = M.service_all("broker")
        return { processed = acted, acted = acted, detail = "station infrastructure survey plan" }
      end,
      note = "station infrastructure survey plan"
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
        owner = "master_infrastructure_plan_0644",
        route = "master-infrastructure-plan-fallback",
        category = "diagnostics",
        priority = "late"
      })
      if cadence then owner = "runtime-event-registry" end
    end
  end
  if not owner then
    if log then log("[Tech-Priests 0.1.653] master infrastructure planner not installed: broker and registry ownership unavailable") end
    return false
  end
  root()
  _G.TechPriestsMasterInfrastructurePlan0644 = M
  install_bootstrap()
  M.route_owner = owner
  M.installed = true
  if log then log("[Tech-Priests 0.1.653] master infrastructure planner installed via " .. owner) end
  return true
end
return M
