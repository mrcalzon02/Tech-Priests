-- scripts/core/proxy_turret_alignment.lua
-- Tech Priests 0.1.674-dev canonical hidden-proxy position authority.
-- Visible priest movement belongs to movement_controller. Proxy ammunition belongs
-- to proxy_ammo_hardener_0649. This module owns only proxy identity, alignment,
-- attachment recovery, and shooting-target sustain through broker services.

local M = {
  version = "0.1.674-dev",
  storage_key = "proxy_turret_alignment_0430",
  heartbeat_interval = 90,
  combat_sustain_interval = 13,
  heartbeat_budget = 24,
  combat_sustain_budget = 12,
  alignment_hold_ticks = 30,
  max_attached_distance_sq = 4.0,
  orphan_search_radius = 20,
  proxy_name = "tech-priest-small-arms-proxy",
  broker_required = true,
  combat_sustain_integrated = true,
}

local CombatSafety = nil
pcall(function() CombatSafety = require("scripts.core.combat_safety") end)

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function distance_sq(a, b)
  if not (a and b) then return math.huge end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end
local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end
local function state()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, stats = {} }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  root.stats = root.stats or {}
  return root
end
local function proxy_name() return rawget(_G, "PROXY_NAME") or M.proxy_name end

function M.align_to_priest(pair, proxy, priest, reason)
  priest = priest or (pair and pair.priest) or nil
  proxy = proxy or (pair and pair.proxy) or nil
  if not (valid(proxy) and valid(priest)) then return false end
  local ok, moved = pcall(function() return proxy.teleport(priest.position) end)
  if ok and moved ~= false then
    if pair then
      pair.last_proxy_alignment_0430 = {
        tick = now(), reason = reason or "proxy-alignment", proxy_unit = proxy.unit_number,
        priest_unit = priest.unit_number, x = priest.position.x, y = priest.position.y,
      }
    end
    return true
  end
  if pair then
    pair.last_proxy_alignment_0430 = {
      tick = now(), reason = reason or "proxy-alignment-failed", failed = true,
      proxy_unit = proxy.unit_number, priest_unit = priest.unit_number,
    }
  end
  return false
end

function M.describe(pair)
  local rec = pair and pair.last_proxy_alignment_0430 or nil
  if not rec then return "no-proxy-alignment-record" end
  return "tick=" .. tostring(rec.tick) .. " reason=" .. tostring(rec.reason) ..
    " failed=" .. tostring(rec.failed or false) .. " proxy=" .. tostring(rec.proxy_unit or "?") ..
    " priest=" .. tostring(rec.priest_unit or "?")
end

local function ensure_proxy(pair)
  if pair and valid(pair.proxy) then return pair.proxy end
  local fn = rawget(_G, "ensure_proxy")
  if type(fn) == "function" then
    local ok, proxy = pcall(fn, pair)
    if ok and valid(proxy) then pair.proxy = proxy; return proxy end
  end
  return nil
end

local function owned_proxy_units()
  local owned, counts = {}, {}
  for _, pair in pairs(pair_map()) do
    if pair and valid(pair.proxy) and pair.proxy.unit_number then
      owned[pair.proxy.unit_number] = true
      counts[pair.proxy.unit_number] = (counts[pair.proxy.unit_number] or 0) + 1
    end
  end
  return owned, counts
end

local function find_unowned_proxy(pair, owned)
  if not (pair and valid(pair.priest) and valid(pair.station)) then return nil end
  local pos, surface = pair.priest.position, pair.priest.surface
  if not surface then return nil end
  local radius = M.orphan_search_radius
  local ok, found = pcall(function()
    return surface.find_entities_filtered({
      name = proxy_name(), force = pair.priest.force,
      area = {{pos.x - radius, pos.y - radius}, {pos.x + radius, pos.y + radius}},
    })
  end)
  if not (ok and found) then return nil end
  local best, best_distance = nil, math.huge
  for _, proxy in ipairs(found) do
    if valid(proxy) and not (proxy.unit_number and owned[proxy.unit_number]) then
      local distance = distance_sq(proxy.position, pos)
      if distance < best_distance then best, best_distance = proxy, distance end
    end
  end
  return best
end

local function current_target(pair)
  if pair and valid(pair.combat_target) then return pair.combat_target end
  if pair and valid(pair.target) then return pair.target end
  return nil
end

local function hostile(pair, target)
  if not (pair and valid(target)) then return false end
  local mutex = rawget(_G, "TECH_PRIESTS_BEHAVIOR_MUTEX_0466")
  if mutex and type(mutex.is_hostile) == "function" then
    local ok, yes = pcall(mutex.is_hostile, pair, target)
    if ok then return yes == true end
  end
  if CombatSafety and type(CombatSafety.is_valid_hostile_target) == "function" then
    local ok, yes = pcall(CombatSafety.is_valid_hostile_target, pair.priest or pair.station or pair, target)
    if ok then return yes == true end
  end
  return false
end

-- 0880: an otherwise idle recovery candidate can retain an obsolete
-- shooting_target on an already ATTACHED proxy. Reattachment alone cannot
-- repair that condition, and 0822 correctly refuses to mine a station whose
-- proxy still points at anything. Clear only after a quiet combat grace
-- period, on an exclusive same-force/surface priest-owned proxy. Never
-- destroy or replace a proxy or its ammunition to make recovery eligible.
local function clear_idle_proxy_target(pair, proxy, owner_count)
  if not (pair and pair.mode == "idle" and not pair.dead
      and not pair.recalling and not pair.deploying
      and valid(pair.priest) and valid(proxy)
      and owner_count == 1 and proxy.unit_number ~= nil
      and proxy.name == proxy_name()
      and proxy.force == pair.priest.force
      and proxy.surface == pair.priest.surface
      and distance_sq(proxy.position, pair.priest.position) <= M.max_attached_distance_sq
      and pair.combat_target == nil and pair.target == nil) then
    return false
  end
  for _, key in ipairs({"active_task", "current_task", "construction_task",
      "build_task", "repair_target", "consecration_target",
      "inventory_transfer_custody_0687", "direct_acquisition_task_0336",
      "active_acquisition_0333"}) do
    if pair[key] ~= nil and pair[key] ~= false then return false end
  end
  local last = pair.last_proxy_combat_sustain_0430
  if type(last) == "table" and type(last.tick) == "number"
      and now() - last.tick < 180 then return false end
  local observed, target = pcall(function() return proxy.shooting_target end)
  if not observed or target == nil then return false end
  local wrote = pcall(function() proxy.shooting_target = nil end)
  local readback, remaining = pcall(function() return proxy.shooting_target end)
  if not (wrote and readback and remaining == nil) then return false end
  pair.last_proxy_idle_target_clear_0880 = {
    tick = now(), proxy_unit = proxy.unit_number,
    priest_unit = pair.priest.unit_number,
  }
  return true
end

function M.heartbeat_service(_, budget)
  local root = state()
  local owned, owner_counts = owned_proxy_units()
  local processed, repaired, blocked, cleared = 0, 0, 0, 0
  local limit = math.max(1, math.min(64, math.floor(tonumber(budget) or M.heartbeat_budget)))
  -- 0879: a fixed-budget map traversal that always starts at the first
  -- pairs starves later priests indefinitely. Rotate deterministically across
  -- all LIVE pairs. This is a hidden-equipment alignment schedule only;
  -- never infer permission to mine or move a staffed station from it.
  local eligible = {}
  for key, pair in pairs(pair_map()) do
    if pair and valid(pair.priest) and valid(pair.station) then
      eligible[#eligible+1] = {key=tostring(key),pair=pair}
    end
  end
  table.sort(eligible,function(a,b) return a.key<b.key end)
  if #eligible==0 then
    root.heartbeat_cursor=0
    return {processed=0,acted=0,blocked=0,exhausted=false,detail="proxy-heartbeat-no-pairs"}
  end
  local start=(math.floor(tonumber(root.heartbeat_cursor) or 0) % #eligible)+1
  for offset=0,math.min(limit,#eligible)-1 do
    local pair=eligible[((start+offset-1) % #eligible)+1].pair
    processed = processed + 1
    do
      local proxy = pair.proxy
      if not valid(proxy) then
        proxy = find_unowned_proxy(pair, owned) or ensure_proxy(pair)
        if valid(proxy) then pair.proxy = proxy; if proxy.unit_number then owned[proxy.unit_number] = true end end
      end
      if valid(proxy) then
        -- An ambiguous shared proxy must never be teleported, destroyed or
        -- silently assigned to whichever priest the heartbeat visits first.
        -- 0822 also refuses station mining until ownership is exclusive.
        if proxy.unit_number and (owner_counts[proxy.unit_number] or 0) > 1 then
          blocked = blocked + 1
        else
        local attached = proxy.surface == pair.priest.surface and distance_sq(proxy.position, pair.priest.position) <= M.max_attached_distance_sq
        if not attached then
          if M.align_to_priest(pair, proxy, pair.priest, "proxy-heartbeat-0555-reattach") then
            repaired = repaired + 1
            pcall(function() proxy.shooting_target = nil end)
            pair.proxy_expires = math.max(pair.proxy_expires or 0, now() + 180)
          else
            blocked = blocked + 1
            pcall(function() proxy.destroy({ raise_destroy = false }) end)
            pair.proxy = nil
            ensure_proxy(pair)
          end
        end
        end
      else
        blocked = blocked + 1
      end
      if clear_idle_proxy_target(pair, proxy,
          proxy and proxy.unit_number and owner_counts[proxy.unit_number] or 0) then
        cleared = cleared + 1
      end
    end
  end
  root.heartbeat_cursor=(start+processed-2) % #eligible + 1
  root.stats.heartbeat_processed = (root.stats.heartbeat_processed or 0) + processed
  root.stats.heartbeat_repaired = (root.stats.heartbeat_repaired or 0) + repaired
  root.stats.heartbeat_blocked = (root.stats.heartbeat_blocked or 0) + blocked
  root.stats.heartbeat_idle_targets_cleared_0880 =
    (root.stats.heartbeat_idle_targets_cleared_0880 or 0) + cleared
  return { processed = processed, acted = repaired + cleared, blocked = blocked, exhausted = processed < #eligible, detail = "proxy-heartbeat" }
end

function M.combat_sustain_service(_, budget)
  local root = state()
  local processed, acted, blocked = 0, 0, 0
  local limit = math.max(1, math.min(32, math.floor(tonumber(budget) or M.combat_sustain_budget)))
  for _, pair in pairs(pair_map()) do
    if processed >= limit then break end
    if pair and valid(pair.priest) and valid(pair.station) then
      processed = processed + 1
      local target = current_target(pair)
      if target and hostile(pair, target) then
        local proxy = ensure_proxy(pair)
        if valid(proxy) then
          if now() >= (pair.next_proxy_alignment_tick_0430 or 0) then
            pair.next_proxy_alignment_tick_0430 = now() + M.alignment_hold_ticks
            M.align_to_priest(pair, proxy, pair.priest, "combat-proxy-sustain-0430")
          end
          pcall(function() proxy.active = true end)
          pcall(function() proxy.operable = false end)
          pcall(function() proxy.destructible = false end)
          pcall(function() proxy.shooting_target = target end)
          pair.proxy_expires = math.max(pair.proxy_expires or 0, now() + 180)
          pair.last_proxy_combat_sustain_0430 = { tick = now(), target_unit = target.unit_number or 0 }
          acted = acted + 1
        else
          blocked = blocked + 1
        end
      end
    end
  end
  root.stats.combat_processed = (root.stats.combat_processed or 0) + processed
  root.stats.combat_acted = (root.stats.combat_acted or 0) + acted
  root.stats.combat_blocked = (root.stats.combat_blocked or 0) + blocked
  return { processed = processed, acted = acted, blocked = blocked, exhausted = processed >= limit, detail = "combat-proxy-sustain" }
end

function M.install()
  if M._installed then return true end
  state()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not broker then pcall(function() broker = require("scripts.core.runtime_tick_broker") end) end
  if not (broker and type(broker.register_service) == "function") then return false end
  local heartbeat = broker.register_service({
    name = "proxy_turret_alignment_0555", category = "recovery", interval = M.heartbeat_interval,
    priority = 42, budget = M.heartbeat_budget, fn = M.heartbeat_service,
    note = "canonical hidden-proxy identity and physical reattachment",
  })
  local combat = broker.register_service({
    name = "combat_proxy_sustain_0472", category = "combat", interval = M.combat_sustain_interval,
    priority = 48, budget = M.combat_sustain_budget, fn = M.combat_sustain_service,
    note = "canonical hidden-proxy target sustain without visible movement ownership",
  })
  if not (heartbeat and combat) then return false end
  _G.tech_priests_align_proxy_to_priest_0430 = M.align_to_priest
  _G.tech_priests_proxy_alignment_summary_0430 = M.describe
  _G.tech_priests_proxy_alignment_heartbeat_0555 = function(event) return M.heartbeat_service(event, M.heartbeat_budget) end
  _G.TECH_PRIESTS_PROXY_TURRET_ALIGNMENT_0430 = M
  M._installed = true
  if log then log("[Tech-Priests 0.1.674-dev] broker-owned hidden-proxy alignment and combat sustain installed") end
  return true
end

return M
