-- scripts/core/master_infrastructure_plan_0644.lua
-- Tech Priests 0.1.644
--
-- Survey-only master infrastructure planner skeleton.
--
-- This module does not place entities, create ghosts, move priests, mutate active
-- work, or claim construction authority. It builds a station-local diagnostic
-- plan so we can see the industrial ladder the Cogitator should be pursuing:
-- resources -> normal mining -> smelting -> storage -> crafting -> power -> lab.

local M = {}
M.version = "0.1.644"
M.storage_key = "master_infrastructure_plan_0644"
M.tick_interval = 97
M.max_pairs_per_pulse = 24
M.default_radius = 36

local RESOURCE_PRIORITY = {
  ["iron-ore"] = 10,
  ["copper-ore"] = 20,
  coal = 30,
  stone = 40,
  ["uranium-ore"] = 90,
}

local NORMAL_MINER_ITEMS = {
  "burner-mining-drill",
  "electric-mining-drill",
  "big-mining-drill",
}

local NORMAL_FURNACE_ITEMS = {
  "stone-furnace",
  "steel-furnace",
  "electric-furnace",
}

local NORMAL_ASSEMBLER_ITEMS = {
  "assembling-machine-1",
  "assembling-machine-2",
  "assembling-machine-3",
}

local NORMAL_STORAGE_ITEMS = {
  "wooden-chest",
  "iron-chest",
  "steel-chest",
  "passive-provider-chest",
  "storage-chest",
}

local NORMAL_LAB_ITEMS = {
  "lab",
}

local EMERGENCY_BY_ROLE = {
  miner = "tech-priests-emergency-miner",
  smelter = "tech-priests-emergency-smelter",
  assembler = "tech-priests-emergency-assembler",
  lab = "tech-priests-emergency-laboratorium",
  power = "tech-priests-emergency-power-grid",
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function dist_sq(a, b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function lower(v) return string.lower(tostring(v or "")) end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    recent = {},
  }
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
  r.recent[#r.recent + 1] = { tick = now(), action = tostring(action or "event"), station = safe(station_unit(pair)), detail = tostring(detail or "") }
  while #r.recent > 80 do table.remove(r.recent, 1) end
end

local function item_exists(name)
  return name and prototypes and prototypes.item and prototypes.item[name] ~= nil
end

local function entity_exists(name)
  return name and prototypes and prototypes.entity and prototypes.entity[name] ~= nil
end

local function first_existing_item(list)
  for _, name in ipairs(list or {}) do
    if item_exists(name) then return name end
  end
  return nil
end

local function radius_for(pair)
  if not valid_pair(pair) then return M.default_radius end
  if type(_G.get_station_operating_radius) == "function" then
    local ok, r = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(r) then return math.max(8, math.min(96, tonumber(r))) end
  end
  if tonumber(pair.radius) then return math.max(8, math.min(96, tonumber(pair.radius))) end
  return M.default_radius
end

local function safe_inventory(entity, id)
  if not (valid(entity) and entity.get_inventory and id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end

local function inv_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, n = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(n) or 0) or 0
end

local function station_sources(pair)
  if not valid_pair(pair) then return {} end
  if type(_G.tech_priests_inventory_steward_sources_for_pair) == "function" then
    local ok, sources = pcall(_G.tech_priests_inventory_steward_sources_for_pair, pair)
    if ok and type(sources) == "table" and #sources > 0 then return sources end
  end
  local out = {}
  if defines and defines.inventory then
    local inv = safe_inventory(pair.station, defines.inventory.chest)
    if inv then out[#out + 1] = { inv = inv, source = "station-chest", entity = pair.station } end
  end
  return out
end

local function station_count(pair, item)
  local n = 0
  for _, src in ipairs(station_sources(pair)) do
    if src and src.inv and src.inv.valid then n = n + inv_count(src.inv, item) end
  end
  return n
end

local function scan_resources(pair)
  local out = {}
  if not valid_pair(pair) then return out end
  local r = radius_for(pair)
  local ok, ents = pcall(function()
    return pair.station.surface.find_entities_filtered({ position = pair.station.position, radius = r, type = "resource" })
  end)
  if ok and ents then
    for _, e in pairs(ents) do
      if valid(e) and dist_sq(e.position, pair.station.position) <= r * r and (not e.amount or e.amount > 0) then
        local name = e.name
        out[name] = out[name] or { name = name, count = 0, amount = 0, nearest_d2 = nil }
        out[name].count = out[name].count + 1
        out[name].amount = out[name].amount + (tonumber(e.amount) or 0)
        local d2 = dist_sq(e.position, pair.station.position)
        if not out[name].nearest_d2 or d2 < out[name].nearest_d2 then
          out[name].nearest_d2 = d2
          out[name].nearest = { x = e.position.x, y = e.position.y }
        end
      end
    end
  end
  return out
end

local function entity_role(e)
  if not valid(e) then return nil end
  if e.type == "mining-drill" then
    if e.name == "tech-priests-emergency-miner" then return "emergency-miner" end
    return "normal-miner"
  end
  if e.type == "furnace" then return "normal-smelter" end
  if e.type == "assembling-machine" then
    if e.name == "tech-priests-emergency-smelter" then return "emergency-smelter" end
    if e.name == "tech-priests-emergency-miner" then return "emergency-miner" end
    if e.name == "tech-priests-emergency-assembler" then return "emergency-assembler" end
    if e.name == "tech-priests-atmospheric-water-condenser" then return "emergency-power" end
    return "normal-assembler"
  end
  if e.type == "container" or e.type == "logistic-container" then return "storage" end
  if e.type == "electric-pole" or e.type == "boiler" or e.type == "generator" then return "power" end
  if e.type == "lab" then return "lab" end
  return nil
end

local function scan_entities(pair)
  local roles = { counts = {}, names = {} }
  if not valid_pair(pair) then return roles end
  local r = radius_for(pair)
  local ok, ents = pcall(function()
    return pair.station.surface.find_entities_filtered({ position = pair.station.position, radius = r, force = pair.station.force })
  end)
  if ok and ents then
    for _, e in pairs(ents) do
      if valid(e) and dist_sq(e.position, pair.station.position) <= r * r then
        local role = entity_role(e)
        if role then
          roles.counts[role] = (roles.counts[role] or 0) + 1
          roles.names[role] = roles.names[role] or {}
          roles.names[role][e.name] = (roles.names[role][e.name] or 0) + 1
        end
      end
    end
  end
  return roles
end

local function resource_count(resources)
  local n = 0
  for _ in pairs(resources or {}) do n = n + 1 end
  return n
end

local function sorted_resource_names(resources)
  local names = {}
  for name in pairs(resources or {}) do names[#names + 1] = name end
  table.sort(names, function(a, b)
    local pa = RESOURCE_PRIORITY[a] or 1000
    local pb = RESOURCE_PRIORITY[b] or 1000
    if pa ~= pb then return pa < pb end
    return a < b
  end)
  return names
end

local function has_role(roles, role)
  return roles and roles.counts and (tonumber(roles.counts[role] or 0) or 0) > 0
end

local function choose_next_target(pair, resources, roles)
  local target = {
    status = "planned",
    class = "idle",
    stage = "ready",
    preferred_item = nil,
    fallback_item = nil,
    resource = nil,
    blocker = nil,
    delivery = "none",
    reason = "local plan appears stable enough for later work",
  }

  local storage_item = first_existing_item(NORMAL_STORAGE_ITEMS)
  local miner_item = first_existing_item(NORMAL_MINER_ITEMS)
  local furnace_item = first_existing_item(NORMAL_FURNACE_ITEMS)
  local assembler_item = first_existing_item(NORMAL_ASSEMBLER_ITEMS)
  local lab_item = first_existing_item(NORMAL_LAB_ITEMS)
  local resource_names = sorted_resource_names(resources)
  local has_resources = #resource_names > 0

  if not has_role(roles, "storage") and storage_item then
    target.class = "storage"
    target.stage = "minimum-storage"
    target.preferred_item = storage_item
    target.fallback_item = nil
    target.blocker = station_count(pair, storage_item) > 0 and nil or ("missing " .. storage_item)
    target.delivery = "place-near-station"
    target.reason = "station needs safe external storage before machine loops scale"
    return target
  end

  if has_resources and not has_role(roles, "normal-miner") then
    target.class = "resource-extraction"
    target.stage = "normal-mining"
    target.preferred_item = miner_item
    target.fallback_item = EMERGENCY_BY_ROLE.miner
    target.resource = resource_names[1]
    target.blocker = miner_item and (station_count(pair, miner_item) > 0 and nil or ("missing " .. miner_item)) or "no normal mining drill item prototype"
    target.delivery = "direct-service-until-belts"
    target.reason = "resource patch exists in station range; normal mining should precede emergency miner"
    return target
  end

  if not has_resources and not has_role(roles, "emergency-miner") then
    target.class = "resource-extraction"
    target.stage = "emergency-mining"
    target.preferred_item = EMERGENCY_BY_ROLE.miner
    target.fallback_item = nil
    target.blocker = station_count(pair, EMERGENCY_BY_ROLE.miner) > 0 and nil or ("missing " .. EMERGENCY_BY_ROLE.miner)
    target.delivery = "slow-patchless-output"
    target.reason = "no local resource patches found; emergency miner is allowed"
    return target
  end

  if not (has_role(roles, "normal-smelter") or has_role(roles, "emergency-smelter")) then
    target.class = "smelting"
    target.stage = "plate-production"
    target.preferred_item = furnace_item
    target.fallback_item = EMERGENCY_BY_ROLE.smelter
    if furnace_item and station_count(pair, furnace_item) > 0 then target.blocker = nil else target.blocker = "missing smelter or furnace item" end
    target.delivery = "direct-ore-and-fuel-service"
    target.reason = "ore must become plates before higher infrastructure requests"
    return target
  end

  if station_count(pair, "iron-plate") < 4 then
    target.class = "production"
    target.stage = "iron-plates"
    target.preferred_item = "iron-plate"
    target.fallback_item = nil
    target.blocker = station_count(pair, "iron-ore") > 0 and nil or "missing iron ore input"
    target.delivery = "machine-specific-smelting-service"
    target.reason = "minimum iron plate reserve not met"
    return target
  end

  if not (has_role(roles, "normal-assembler") or has_role(roles, "emergency-assembler")) then
    target.class = "crafting"
    target.stage = "basic-crafting"
    target.preferred_item = assembler_item
    target.fallback_item = EMERGENCY_BY_ROLE.assembler
    if assembler_item and station_count(pair, assembler_item) > 0 then target.blocker = nil else target.blocker = "missing assembler item" end
    target.delivery = "place-near-storage"
    target.reason = "station needs local crafting after mining and smelting"
    return target
  end

  if not has_role(roles, "lab") then
    target.class = "research"
    target.stage = "research-readiness"
    target.preferred_item = lab_item
    target.fallback_item = EMERGENCY_BY_ROLE.lab
    if lab_item and station_count(pair, lab_item) > 0 then target.blocker = nil else target.blocker = "missing lab item" end
    target.delivery = "place-after-basic-crafting"
    target.reason = "research should follow basic mining, smelting, storage, and crafting"
    return target
  end

  return target
end

local function summary_counts(resources, roles)
  local res_bits = {}
  for _, name in ipairs(sorted_resource_names(resources)) do
    local rec = resources[name]
    res_bits[#res_bits + 1] = name .. ":" .. tostring(rec.count)
  end
  local role_bits = {}
  for role, count in pairs(roles.counts or {}) do role_bits[#role_bits + 1] = role .. ":" .. tostring(count) end
  table.sort(role_bits)
  return table.concat(res_bits, ","), table.concat(role_bits, ",")
end

function M.build_plan(pair, reason)
  if not valid_pair(pair) then return nil, "invalid-pair" end
  local resources = scan_resources(pair)
  local roles = scan_entities(pair)
  local target = choose_next_target(pair, resources, roles)
  local res_summary, role_summary = summary_counts(resources, roles)
  local plan = {
    version = M.version,
    tick = now(),
    station = station_unit(pair),
    priest = priest_unit(pair),
    radius = radius_for(pair),
    reason = reason or "survey",
    resources = resources,
    roles = roles.counts or {},
    resource_summary = res_summary,
    role_summary = role_summary,
    target = target,
    stage = target.stage,
    status = target.status,
    blocker = target.blocker,
  }
  pair.master_infrastructure_plan_0644 = plan
  return plan, "planned"
end

function M.service_pair(pair, reason)
  local r = root()
  if r.enabled == false then return false, "disabled" end
  local plan, why = M.build_plan(pair, reason or "service")
  if plan then
    stat("plans_built")
    record("plan-built-0644", pair, "stage=" .. safe(plan.stage) .. " target=" .. safe(plan.target and plan.target.preferred_item) .. " blocker=" .. safe(plan.blocker))
    return true, why
  end
  stat("plans_failed")
  return false, why
end

function M.service_all(reason)
  local r = root()
  if r.enabled == false then return 0 end
  local n = 0
  for _, pair in pairs(pair_map()) do
    if n >= M.max_pairs_per_pulse then break end
    if valid_pair(pair) then
      local ok = pcall(M.service_pair, pair, reason or "pulse")
      if ok then n = n + 1 end
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

local function plan_lines(plan)
  if not plan then return { "  no plan" } end
  local t = plan.target or {}
  return {
    "  station=" .. safe(plan.station) .. " radius=" .. safe(plan.radius) .. " stage=" .. safe(plan.stage) .. " status=" .. safe(plan.status),
    "  resources=" .. safe(plan.resource_summary ~= "" and plan.resource_summary or "none"),
    "  roles=" .. safe(plan.role_summary ~= "" and plan.role_summary or "none"),
    "  next class=" .. safe(t.class) .. " preferred=" .. safe(t.preferred_item) .. " fallback=" .. safe(t.fallback_item) .. " resource=" .. safe(t.resource),
    "  delivery=" .. safe(t.delivery) .. " blocker=" .. safe(t.blocker),
    "  reason=" .. safe(t.reason),
  }
end

function M.status_for_pair(pair)
  if not valid_pair(pair) then return { "invalid pair" } end
  local plan = pair.master_infrastructure_plan_0644
  if not plan then plan = M.build_plan(pair, "status") end
  return plan_lines(plan)
end

local function install_command()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-infra-plan-0644") end end)
  commands.add_command("tp-infra-plan-0644", "Tech Priests 0.1.644: survey-only master infrastructure plan. Params: status/kick/all/on/off/recent", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = root()
    if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false elseif p == "all" then M.service_all("command-all") end
    local pair = selected_pair(player)
    if p == "kick" and pair then M.service_pair(pair, "command-kick") end
    local lines = { "[tp-infra-plan-0644] enabled=" .. safe(r.enabled) .. " built=" .. safe(r.stats.plans_built or 0) .. " failed=" .. safe(r.stats.plans_failed or 0) }
    if pair then for _, line in ipairs(M.status_for_pair(pair)) do lines[#lines + 1] = line end else lines[#lines + 1] = "  select a Cogitator Station or Tech-Priest" end
    if p == "recent" then
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
  _G.TechPriestsMasterInfrastructurePlan0644 = M
  install_command()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({ name = "master_infrastructure_plan_0644", category = "diagnostics", interval = M.tick_interval, priority = 980, budget = 8, fn = function(event, budget) M.service_all("broker") return true end, note = "survey-only station infrastructure plan diagnostics" })
  else
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick) == "function" then R.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end, { owner = "master_infrastructure_plan_0644", category = "diagnostics", priority = "late" })
    elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end) end
  end
  if log then log("[Tech-Priests 0.1.644] master infrastructure planner skeleton installed; survey-only /tp-infra-plan-0644 reports resources, roles, next target, and blocker") end
  return true
end

return M
