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
  assembler = { class = "crafting", stage = "basic-crafting", item = "tech-priests-emergency-assembler", fallback = "assembling-machine-1", delivery = "place-near-storage" },
  lab = { class = "research", stage = "research-readiness", item = "tech-priests-emergency-laboratorium", fallback = "lab", delivery = "place-after-basic-crafting" },
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
  local n = 0
  if type(_G.tech_priests_inventory_steward_sources_for_pair) == "function" then local ok, sources = pcall(_G.tech_priests_inventory_steward_sources_for_pair, pair); if ok and type(sources) == "table" then for _, src in ipairs(sources) do if src and src.inv and src.inv.valid then n = n + inv_count(src.inv, item) end end end end
  if defines and defines.inventory then local inv = safe_inventory(pair.station, defines.inventory.chest); n = n + inv_count(inv, item) end
  return n
end
local function item_available(pair, preferred, fallback)
  if preferred and station_count(pair, preferred) > 0 then return preferred, nil end
  if fallback and station_count(pair, fallback) > 0 then return fallback, preferred end
  return preferred or fallback, preferred and fallback or nil
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
  return nil
end
local function scan_roles(pair)
  local roles = {}; if not valid_pair(pair) then return roles end
  local r = radius_for(pair); local ok, ents = pcall(function() return pair.station.surface.find_entities_filtered({ position = pair.station.position, radius = r, force = pair.station.force }) end)
  if ok and ents then for _, e in pairs(ents) do local role = entity_role(e); if role and e ~= pair.station then roles[role] = (roles[role] or 0) + 1 end end end
  return roles
end
local function has_role(roles, a, b) return (tonumber(roles[a] or 0) > 0) or (b and tonumber(roles[b] or 0) > 0) end
local function first_resource(resources) local names = {}; for name in pairs(resources or {}) do names[#names+1]=name end; table.sort(names, function(a,b) return (RESOURCE_PRIORITY[a] or 1000) < (RESOURCE_PRIORITY[b] or 1000) end); return names[1] end
local function choose(pair, resources, roles)
  local t
  if not has_role(roles, "emergency-smelter", "normal-smelter") then t = TARGETS.smelter
  elseif not has_role(roles, "storage") then t = TARGETS.storage
  elseif first_resource(resources) and not has_role(roles, "emergency-miner", "normal-miner") then t = TARGETS.miner
  elseif not has_role(roles, "emergency-assembler", "normal-assembler") then t = TARGETS.assembler
  elseif not has_role(roles, "lab") then t = TARGETS.lab
  else return { status = "planned", class = "idle", stage = "ready", delivery = "none", reason = "local bootstrap spine appears present" } end
  local item, fallback = item_available(pair, t.item, t.fallback)
  return { status = "planned", class = t.class, stage = t.stage, preferred_item = item, fallback_item = fallback, resource = first_resource(resources), blocker = item and station_count(pair, item) > 0 and nil or ("missing " .. safe(item)), delivery = t.delivery, reason = t.stage }
end
local function summarize(t) local bits = {}; for k,v in pairs(t or {}) do bits[#bits+1]=k..":"..tostring(type(v)=="table" and (v.count or 1) or v) end; table.sort(bits); return table.concat(bits, ",") end
function M.build_plan(pair, reason)
  if not valid_pair(pair) then return nil, "invalid-pair" end
  local resources = scan_resources(pair); local roles = scan_roles(pair); local target = choose(pair, resources, roles)
  local plan = { version = M.version, tick = now(), station = station_unit(pair), priest = priest_unit(pair), radius = radius_for(pair), reason = reason or "survey", resources = resources, roles = roles, resource_summary = summarize(resources), role_summary = summarize(roles), target = target, stage = target.stage, status = target.status, blocker = target.blocker }
  pair.master_infrastructure_plan_0644 = plan
  return plan, "planned"
end
function M.service_pair(pair, reason) local r = root(); if r.enabled == false then return false, "disabled" end; local plan, why = M.build_plan(pair, reason or "service"); if plan then stat("plans_built"); record("plan-built-0644", pair, "stage=" .. safe(plan.stage)); return true, why end; stat("plans_failed"); return false, why end
function M.service_all(reason) local r=root(); if r.enabled == false then return 0 end; local n=0; for _, pair in pairs(pair_map()) do if n>=M.max_pairs_per_pulse then break end if valid_pair(pair) then local ok=pcall(M.service_pair, pair, reason or "pulse"); if ok then n=n+1 end end end; return n end
local function install_bootstrap() local ok, mod = pcall(require, "scripts.core.construction_bootstrap_ghost_planner_0645"); if ok and mod and type(mod.install)=="function" then pcall(mod.install) end end
function M.install()
  root(); _G.TechPriestsMasterInfrastructurePlan0644 = M; install_bootstrap()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service)=="function" then broker.register_service({ name="master_infrastructure_plan_0644", category="diagnostics", interval=M.tick_interval, priority=980, budget=8, fn=function(event,budget) M.service_all("broker"); return true end, note="station infrastructure survey plan" })
  else local R=rawget(_G,"TechPriestsRuntimeEventRegistry"); if R and type(R.on_nth_tick)=="function" then R.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end, { owner="master_infrastructure_plan_0644", category="diagnostics", priority="late" }) elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end) end end
  if log then log("[Tech-Priests 0.1.653] master infrastructure planner installed") end
  return true
end
return M
