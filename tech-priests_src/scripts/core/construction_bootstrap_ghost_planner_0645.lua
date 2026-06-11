-- scripts/core/construction_bootstrap_ghost_planner_0645.lua
-- Tech Priests 0.1.645
--
-- One-ghost construction bootstrap planner.
--
-- This is the first concrete step from survey-only infrastructure planning toward
-- station-local construction bootstrap. It reads the 0.1.644 master
-- infrastructure survey and creates at most one planning ghost per station. The
-- ghost is a truthful planning/build target, not proof that the infrastructure
-- exists. Full belt/train/logistics/science decomposition comes later.

local M = {}
M.version = "0.1.645"
M.storage_key = "construction_bootstrap_ghost_planner_0645"
M.tick_interval = 83
M.max_pairs_per_pulse = 16
M.retry_ticks = 60 * 10

local CATEGORY_BY_CLASS = {
  storage = "storage",
  ["resource-extraction"] = "miner",
  smelting = "furnace",
  crafting = "assembler",
  research = "lab",
}

local ENTITY_CATEGORY_BY_NAME = {
  ["tech-priests-emergency-smelter"] = "emergency-smelter",
  ["tech-priests-emergency-miner"] = "emergency-miner",
  ["tech-priests-emergency-assembler"] = "assembler",
  ["tech-priests-emergency-laboratorium"] = "lab",
  ["tech-priests-emergency-power-grid"] = "emergency-power-pole",
  ["tech-priests-emergency-boiler"] = "emergency-powertrain",
  ["tech-priests-emergency-steam-engine"] = "emergency-powertrain",
  ["tech-priests-atmospheric-water-condenser"] = "emergency-powertrain",
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(name, n)
  local r = root()
  r.stats[name] = (tonumber(r.stats[name]) or 0) + (n or 1)
end

local function record(action, pair, detail)
  local r = root()
  stat(action)
  r.recent[#r.recent + 1] = { tick = now(), action = tostring(action or "event"), station = safe(station_unit(pair)), priest = safe(priest_unit(pair)), detail = tostring(detail or "") }
  while #r.recent > 100 do table.remove(r.recent, 1) end
end

local function item_exists(name)
  return name and prototypes and prototypes.item and prototypes.item[name] ~= nil
end

local function entity_exists(name)
  return name and prototypes and prototypes.entity and prototypes.entity[name] ~= nil
end

local function entity_name_for_item(item)
  if not item then return nil end
  if entity_exists(item) then return item end
  if prototypes and prototypes.item and prototypes.item[item] then
    local ok, result = pcall(function()
      local pr = prototypes.item[item].place_result
      if pr then return pr.name end
      return nil
    end)
    if ok and result and entity_exists(result) then return result end
  end
  return nil
end

local function category_for(entity_name, class)
  if ENTITY_CATEGORY_BY_NAME[entity_name] then return ENTITY_CATEGORY_BY_NAME[entity_name] end
  local base = CATEGORY_BY_CLASS[class] or "generic"
  if entity_name and prototypes and prototypes.entity and prototypes.entity[entity_name] then
    local ok, t = pcall(function() return prototypes.entity[entity_name].type end)
    if ok then
      if t == "mining-drill" then return "miner" end
      if t == "furnace" then return "furnace" end
      if t == "assembling-machine" then return "assembler" end
      if t == "container" or t == "logistic-container" then return "storage" end
      if t == "lab" then return "lab" end
      if t == "electric-pole" then return "emergency-power-pole" end
    end
  end
  return base
end

local function build_plan(pair, reason)
  if not valid_pair(pair) then return nil end
  local Plan = rawget(_G, "TechPriestsMasterInfrastructurePlan0644")
  if not Plan then
    local ok, mod = pcall(require, "scripts.core.master_infrastructure_plan_0644")
    if ok then Plan = mod end
  end
  if Plan and type(Plan.build_plan) == "function" then
    local ok, plan = pcall(Plan.build_plan, pair, reason or "ghost-planner-0645")
    if ok and plan then return plan end
  end
  return pair.master_infrastructure_plan_0644
end

local function plan_site(pair, entity_name, category)
  local Site = rawget(_G, "TECH_PRIESTS_CONSTRUCTION_SITE_PLANNER_0359")
  if not Site then
    local ok, mod = pcall(require, "scripts.core.construction_site_planner")
    if ok then Site = mod end
  end
  if Site and type(Site.plan_site) == "function" then
    local ok, pos, why = pcall(Site.plan_site, pair, { item_name = entity_name, entity_name = entity_name, category = category or "generic", source = "construction-bootstrap-ghost-0645" })
    if ok then return pos, why end
  end
  return nil, "site-planner-unavailable"
end

local function active_record(pair)
  local rec = pair and pair.construction_bootstrap_ghost_0645
  if type(rec) ~= "table" then return nil end
  return rec
end

local function active_ghost(pair)
  local rec = active_record(pair)
  if not rec then return nil, rec end
  if rec.ghost and rec.ghost.valid then return rec.ghost, rec end
  if rec.unit_number and valid_pair(pair) then
    local ok, found = pcall(function()
      return pair.station.surface.find_entity("entity-ghost", rec.position)
    end)
    if ok and found and found.valid then rec.ghost = found; return found, rec end
  end
  return nil, rec
end

local function ghost_inner_name(ghost)
  if not valid(ghost) then return nil end
  for _, key in ipairs({ "ghost_name", "inner_name" }) do
    local ok, v = pcall(function() return ghost[key] end)
    if ok and v then return v end
  end
  return nil
end

local function target_complete(pair, rec)
  if not (valid_pair(pair) and rec and rec.entity_name) then return false end
  local r = 2.25
  local ok, ents = pcall(function()
    return pair.station.surface.find_entities_filtered({ position = rec.position, radius = r, name = rec.entity_name, force = pair.station.force })
  end)
  return ok and ents and #ents > 0
end

local function science_pack_name(ingredient)
  if type(ingredient) == "string" then return ingredient end
  if type(ingredient) ~= "table" then return nil end
  return ingredient.name or ingredient[1]
end

local function technology_unlocked(tech)
  local ok, researched = pcall(function() return tech.researched end)
  return ok and researched == true
end

local function prerequisites_met(tech)
  local ok, prereqs = pcall(function() return tech.prerequisites end)
  if not ok or type(prereqs) ~= "table" then return true end
  for _, prereq in pairs(prereqs) do
    if prereq and not technology_unlocked(prereq) then return false end
  end
  return true
end

local function next_small_science_objective(pair)
  if not valid_pair(pair) then return nil end
  local force = pair.station.force
  if not (force and force.valid and force.technologies) then return nil end
  local best = nil
  for name, tech in pairs(force.technologies) do
    if tech and tech.valid and not technology_unlocked(tech) and prerequisites_met(tech) then
      local ok, enabled = pcall(function() return tech.enabled end)
      if ok and enabled ~= false then
        local unit_count = 0
        local ingredients = {}
        pcall(function() unit_count = tonumber(tech.research_unit_count) or 0 end)
        pcall(function()
          for _, ing in pairs(tech.research_unit_ingredients or {}) do
            local pack = science_pack_name(ing)
            if pack then ingredients[#ingredients + 1] = pack end
          end
        end)
        local score = unit_count + (#ingredients * 10000)
        if not best or score < best.score or (score == best.score and name < best.name) then
          table.sort(ingredients)
          best = { name = name, count = unit_count, packs = ingredients, score = score }
        end
      end
    end
  end
  return best
end

local function should_bootstrap(pair, plan)
  if not (valid_pair(pair) and plan and plan.target) then return false end
  if plan.stage == "ready" then return false end
  local mode = lower(pair.mode)
  if mode:find("construction", 1, true) or mode:find("bootstrap", 1, true) or mode:find("infrastructure", 1, true) then return true end
  -- Treat a non-ready infrastructure plan as bootstrap territory, but keep the
  -- one-ghost rule so this cannot spam the map.
  return true
end

local function create_planning_ghost(pair, entity_name, pos, target)
  if not (valid_pair(pair) and entity_name and pos and pos.x and pos.y) then return nil, "invalid" end
  local surface = pair.station.surface
  local force = pair.station.force
  local ok, ghost_or_err = pcall(function()
    return surface.create_entity({
      name = "entity-ghost",
      inner_name = entity_name,
      position = pos,
      force = force,
      direction = defines and defines.direction and defines.direction.north or 0,
      expires = false,
      raise_built = true,
    })
  end)
  if ok and ghost_or_err and ghost_or_err.valid then return ghost_or_err, "ghost-created" end
  ok, ghost_or_err = pcall(function()
    return surface.create_entity({
      name = entity_name,
      position = pos,
      force = force,
      direction = defines and defines.direction and defines.direction.north or 0,
      create_build_effect_smoke = false,
      raise_built = true,
    })
  end)
  -- The fallback is deliberately rejected for now. If ghost creation fails, do
  -- not place a free real entity. Return the error so we can fix prototype/site
  -- handling instead of cheating infrastructure into existence.
  return nil, "ghost-create-failed"
end

local function make_record(pair, plan, entity_name, pos, why, ghost)
  local target = plan and plan.target or {}
  local science = next_small_science_objective(pair)
  local rec = {
    version = M.version,
    tick = now(),
    station = station_unit(pair),
    entity_name = entity_name,
    item = target.preferred_item,
    class = target.class,
    stage = plan and plan.stage,
    fallback = target.fallback_item,
    resource = target.resource,
    delivery = target.delivery,
    blocker = target.blocker,
    reason = target.reason,
    site_reason = why,
    position = { x = pos.x, y = pos.y },
    status = ghost and "ghosted" or "planned-no-ghost",
    ghost = ghost,
    unit_number = ghost and ghost.unit_number or nil,
    next_science = science,
    connection_mode = "manual-priest-transfer",
    note = "one station-local planning ghost; does not count as completed infrastructure",
  }
  pair.construction_bootstrap_ghost_0645 = rec
  return rec
end

function M.service_pair(pair, reason)
  local r = root()
  if r.enabled == false then return false, "disabled" end
  if not valid_pair(pair) then return false, "invalid-pair" end

  local ghost, rec = active_ghost(pair)
  if ghost and rec then
    rec.status = "ghosted"
    rec.last_seen_tick = now()
    return false, "active-ghost-present"
  end
  if rec and target_complete(pair, rec) then
    rec.status = "built"
    rec.completed_tick = now()
    record("bootstrap-ghost-built-0645", pair, "entity=" .. safe(rec.entity_name))
    pair.construction_bootstrap_ghost_0645 = nil
  elseif rec and not ghost then
    local last = tonumber(rec.tick or 0) or 0
    if now() - last < M.retry_ticks then return false, "ghost-missing-cooldown" end
    record("bootstrap-ghost-lost-0645", pair, "entity=" .. safe(rec.entity_name))
    pair.construction_bootstrap_ghost_0645 = nil
  end

  local plan = build_plan(pair, reason or "service")
  if not should_bootstrap(pair, plan) then return false, "not-bootstrap" end
  local target = plan.target or {}
  local item = target.preferred_item
  local entity_name = entity_name_for_item(item)
  if not entity_name then
    record("bootstrap-ghost-no-entity-0645", pair, "item=" .. safe(item) .. " stage=" .. safe(plan.stage))
    return false, "target-not-placeable"
  end

  local category = category_for(entity_name, target.class)
  local pos, why = plan_site(pair, entity_name, category)
  if not pos then
    record("bootstrap-ghost-no-site-0645", pair, "entity=" .. safe(entity_name) .. " category=" .. safe(category) .. " why=" .. safe(why))
    pair.construction_bootstrap_ghost_0645 = {
      version = M.version,
      tick = now(),
      station = station_unit(pair),
      entity_name = entity_name,
      item = item,
      class = target.class,
      stage = plan.stage,
      status = "blocked-no-site",
      blocker = why or "no-site",
      next_science = next_small_science_objective(pair),
    }
    return false, why or "no-site"
  end

  local new_ghost, made = create_planning_ghost(pair, entity_name, pos, target)
  local new_rec = make_record(pair, plan, entity_name, pos, why, new_ghost)
  if new_ghost then
    record("bootstrap-ghost-created-0645", pair, "entity=" .. safe(entity_name) .. " stage=" .. safe(plan.stage) .. " pos=" .. string.format("%.1f,%.1f", pos.x or 0, pos.y or 0) .. " science=" .. safe(new_rec.next_science and new_rec.next_science.name))
    if type(_G.tech_priests_behavior_tree_0642_mark) == "function" then
      pcall(_G.tech_priests_behavior_tree_0642_mark, pair, "BT-280", "planning-ghost-0645", "construction_bootstrap_ghost_planner_0645", { item = item, target = "ghost:" .. entity_name, entry_reason = "construction bootstrap one-ghost plan", ongoing = "awaiting build or item delivery", blocked_reason = target.blocker, next_node = "BT-280/BT-300" })
    end
    return true, made
  end
  record("bootstrap-ghost-create-failed-0645", pair, "entity=" .. safe(entity_name) .. " pos=" .. string.format("%.1f,%.1f", pos.x or 0, pos.y or 0))
  return false, made
end

function M.service_all(reason)
  local r = root()
  if r.enabled == false then return 0 end
  local n = 0
  for _, pair in pairs(pair_map()) do
    if n >= M.max_pairs_per_pulse then break end
    if valid_pair(pair) then
      local ok, acted = pcall(M.service_pair, pair, reason or "pulse")
      if ok and acted then n = n + 1 end
    end
  end
  r.last_service_tick = now()
  return n
end

local function selected_pair(player)
  local selected = player and player.selected
  if selected and selected.valid and storage and storage.tech_priests then
    local unit = selected.unit_number
    if unit and storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[unit] then return storage.tech_priests.pairs_by_station[unit] end
    if unit and storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[unit] then return storage.tech_priests.pairs_by_priest[unit] end
  end
  if selected and selected.valid and type(_G.find_pair_for_entity) == "function" then local ok, pair = pcall(_G.find_pair_for_entity, selected); if ok then return pair end end
  return nil
end

local function science_label(science)
  if type(science) ~= "table" then return "none" end
  return safe(science.name) .. " packs=" .. table.concat(science.packs or {}, ",") .. " count=" .. safe(science.count)
end

function M.status_for_pair(pair)
  if not valid_pair(pair) then return "invalid pair" end
  local rec = pair.construction_bootstrap_ghost_0645
  if not rec then return "station=" .. safe(station_unit(pair)) .. " no bootstrap ghost record" end
  return "station=" .. safe(station_unit(pair))
    .. " status=" .. safe(rec.status)
    .. " stage=" .. safe(rec.stage)
    .. " entity=" .. safe(rec.entity_name)
    .. " item=" .. safe(rec.item)
    .. " pos=" .. safe(rec.position and (string.format("%.1f,%.1f", rec.position.x or 0, rec.position.y or 0)) or "none")
    .. " blocker=" .. safe(rec.blocker)
    .. " delivery=" .. safe(rec.delivery)
    .. " science=" .. science_label(rec.next_science)
end

local function install_command()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-bootstrap-ghost-0645") end end)
  commands.add_command("tp-bootstrap-ghost-0645", "Tech Priests 0.1.645: one-ghost construction bootstrap planner. Params: status/kick/all/on/off/recent/clear", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = root()
    if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false elseif p == "all" then M.service_all("command-all") end
    local pair = selected_pair(player)
    if p == "clear" and pair then pair.construction_bootstrap_ghost_0645 = nil end
    if p == "kick" and pair then M.service_pair(pair, "command-kick") end
    local lines = { "[tp-bootstrap-ghost-0645] enabled=" .. safe(r.enabled) .. " created=" .. safe(r.stats["bootstrap-ghost-created-0645"] or 0) .. " no_site=" .. safe(r.stats["bootstrap-ghost-no-site-0645"] or 0) .. " no_entity=" .. safe(r.stats["bootstrap-ghost-no-entity-0645"] or 0) }
    if pair then lines[#lines + 1] = "  " .. M.status_for_pair(pair) else lines[#lines + 1] = "  select a Cogitator Station or Tech-Priest" end
    if p == "recent" or p == "kick" then
      for i = math.max(1, #r.recent - 8), #r.recent do
        local ev = r.recent[i]
        if ev then lines[#lines + 1] = "  [" .. safe(ev.tick) .. "] " .. safe(ev.action) .. " station=" .. safe(ev.station) .. " " .. safe(ev.detail) end
      end
    end
    if player and player.valid then for _, line in ipairs(lines) do player.print(line) end elseif game and game.print then for _, line in ipairs(lines) do game.print(line) end end
  end)
end

function M.install()
  root()
  _G.TechPriestsConstructionBootstrapGhostPlanner0645 = M
  install_command()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({ name = "construction_bootstrap_ghost_planner_0645", category = "construction", interval = M.tick_interval, priority = 60, budget = 6, fn = function(event, budget) M.service_all("broker") return true end, note = "one station-local planning ghost at a time from master infrastructure plan" })
  else
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick) == "function" then R.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end, { owner = "construction_bootstrap_ghost_planner_0645", category = "construction", priority = "early" })
    elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end) end
  end
  if log then log("[Tech-Priests 0.1.645] construction bootstrap ghost planner installed; one planning ghost per station, science objective noted, no multi-ghost layout yet") end
  return true
end

return M
