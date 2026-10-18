-- scripts/core/priest_recovery_safety_0503.lua
-- Broker-owned controlled missing-priest recovery only. This module does not
-- wrap lifecycle globals, recall or teleport valid priests, perform mobility
-- swaps, issue movement commands, create entities directly, or own a timer.
-- one-shot 0499 lease recovery for ordinary missing priests and completed intentional re-imprints.
-- The lifecycle authority grants the lease; canonical respawn consumes it.

local M = {
  version = "0.1.674-dev",
  storage_key = "priest_recovery_safety_0503",
  service_name = "priest_missing_recovery_0503",
  service_interval = 43,
  service_budget = 8,
  recovery_reason = "controlled-missing-recovery-0503",
  recovery_owner = "priest_recovery_safety_0503",
  recovery_kind = "missing-priest-recovery",
  broker_required = true,
  movement_ownership_retired = true,
  recall_ownership_retired = true,
  mobility_ownership_retired = true,
  reimprint_completion_integrated = true,
}

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function safe(value) if value == nil then return "nil" end local ok, out = pcall(tostring, value); return ok and out or "?" end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version, enabled = true, stats = {}, recent = {},
  }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  if root.enabled == nil then root.enabled = true end
  root.stats = root.stats or {}
  root.recent = root.recent or {}
  root.recovery_teleports = nil
  root.authorized_mobility_swap = nil
  root.restore_watchdogs = nil
  return root
end

local function stat(name, amount)
  local root = M.root()
  root.stats[name] = (root.stats[name] or 0) + (amount or 1)
end

local function record(action, pair, detail)
  local root = M.root()
  stat(action)
  root.recent[#root.recent + 1] = {
    tick = now(), action = tostring(action), station = station_unit(pair), detail = tostring(detail or ""),
  }
  while #root.recent > 96 do table.remove(root.recent, 1) end
end

local function lifecycle_authority()
  return rawget(_G, "TechPriestsPriestLifecycleAuthority0499")
end

function M.service_pair(pair)
  if not (pair and valid(pair.station)) then return false, "invalid-pair" end
  local lifecycle = lifecycle_authority()
  if not (lifecycle and type(lifecycle.service_pair) == "function"
    and type(lifecycle.authorize_missing_recovery) == "function")
  then return false, "lifecycle-authority-unavailable" end

  lifecycle.service_pair(pair)
  if valid(pair.priest) then return false, "valid-or-rebound" end
  local state = pair.lifecycle_0499
  if not (state and state.missing_since) then return false, "missing-not-observed" end
  local reimprint = pair.reimprint_0298
  if reimprint and reimprint.active == true then
    local finish_tick = tonumber(reimprint.finish_tick) or 0
    if now() < finish_tick then return false, "reimprint-in-progress" end
    if not state.reimprint_ready_observed_0503 then state.reimprint_ready_observed_0503=now();record("reimprint-ready-for-controlled-recovery-0503",pair,"finish="..safe(finish_tick)) end
  end

  local options = {
    owner = M.recovery_owner,
    kind = M.recovery_kind,
    request_missing_recovery = true,
  }
  local authorized, why = lifecycle.authorize_missing_recovery(pair, M.recovery_reason, options)
  if not authorized then return false, why or "lease-denied" end

  local canonical_respawn = rawget(_G, "tech_priests_canonical_respawn_pair_priest_0503")
  if type(canonical_respawn) ~= "function" then
    record("canonical-respawn-unavailable-0503", pair, "lease-issued")
    return false, "canonical-respawn-unavailable"
  end
  local ok, recovered = pcall(canonical_respawn, pair, M.recovery_reason)
  if ok and recovered == true and valid(pair.priest) then
    record("controlled-missing-recovery-complete-0503", pair, "priest=" .. safe(pair.priest.unit_number))
    return true, "recovered"
  end
  record("controlled-missing-recovery-failed-0503", pair, "ok=" .. safe(ok) .. " result=" .. safe(recovered))
  return false, "canonical-respawn-failed"
end

-- Discover Cogitators created by scripts, map loading or migrations without
-- an accompanying registration event. Existing pair records remain exclusively
-- owned by canonical lifecycle 0499; this only creates a missing FIRST pair.
local function recover_unpaired_stations(limit)
  local root = M.root()
  if now() < (tonumber(root.next_orphan_probe_tick) or 0) then return 0, 0 end
  root.next_orphan_probe_tick = now() + 60 * 5
  if not (game and game.surfaces and type(TIER_CONFIGS) == "table") then return 0, 0 end
  local names = {}
  for name in pairs(TIER_CONFIGS) do names[#names + 1] = name end
  if #names == 0 then return 0, 0 end
  root.orphan_first_seen = root.orphan_first_seen or {}
  root.orphan_retry_after = root.orphan_retry_after or {}
  local seen, processed, acted = {}, 0, 0
  for _, surface in pairs(game.surfaces) do
    local ok, stations = pcall(function() return surface.find_entities_filtered({ name = names }) end)
    if ok and stations then
      for _, station in pairs(stations) do
        local unit = station and station.unit_number
        if valid(station) and unit then
          seen[unit] = true
          if pair_map()[unit] then
            root.orphan_first_seen[unit] = nil
            root.orphan_retry_after[unit] = nil
          elseif not root.orphan_first_seen[unit] then
            root.orphan_first_seen[unit] = now()
          elseif now() - root.orphan_first_seen[unit] >= 60 * 10
            and now() >= (root.orphan_retry_after[unit] or 0)
            and processed < limit then
            processed = processed + 1
            root.orphan_retry_after[unit] = now() + 60 * 10
            local force = station.force
            if force and force.valid and force.name == "neutral" then
              local default_force = game.forces.player
              if default_force and default_force.valid then
                local changed = pcall(function() station.force = default_force end)
                if changed and log then
                  log("[Tech-Priests][ORPHAN_FORCE_DEFAULT] station="..safe(unit).." force=player")
                end
              end
            end
            force = station.force
            if not (force and force.valid) or force.name == "neutral" or force.name == "enemy" then
              record("orphan-station-force-blocked-0503", {station=station}, safe(force and force.name))
            else
              local creator = rawget(_G, "create_pair")
              local created, why = false, "canonical-creator-unavailable"
              if type(creator) == "function" then
                created, why = pcall(creator, station)
              end
              local pair = pair_map()[unit]
              if created and pair and valid(pair.station) and valid(pair.priest) then
                acted = acted + 1
                root.orphan_first_seen[unit] = nil
                root.orphan_retry_after[unit] = nil
                record("orphan-station-pair-restored-0503", pair, "canonical-create-pair")
                if log then log("[Tech-Priests][ORPHAN_PAIR_RESTORED] station="..safe(unit).." force="..safe(force.name)) end
              else
                record("orphan-station-pair-blocked-0503", {station=station}, safe(why))
                if log then log("[Tech-Priests][ORPHAN_PAIR_BLOCKED] station="..safe(unit).." reason="..safe(why)) end
              end
            end
          end
        end
      end
    end
  end
  for unit in pairs(root.orphan_first_seen) do
    if not seen[unit] then
      root.orphan_first_seen[unit] = nil
      root.orphan_retry_after[unit] = nil
    end
  end
  return processed, acted
end

function M.service(_, budget)
  local root = M.root()
  if root.enabled == false then return { processed = 0, acted = 0, detail = "disabled" } end
  local limit = math.max(1, math.min(64, math.floor(tonumber(budget) or M.service_budget)))
  local processed, acted = 0, 0
  for _, pair in pairs(pair_map()) do
    if processed >= limit then break end
    if pair and valid(pair.station) and not valid(pair.priest) then
      processed = processed + 1
      local recovered = M.service_pair(pair)
      if recovered then acted = acted + 1 end
    end
  end
  local orphan_processed, orphan_acted = recover_unpaired_stations(math.max(1, limit - processed))
  processed = processed + orphan_processed
  acted = acted + orphan_acted
  root.stats.service_processed = (root.stats.service_processed or 0) + processed
  root.stats.service_acted = (root.stats.service_acted or 0) + acted
  return { processed = processed, acted = acted, exhausted = processed >= limit, detail = "controlled-missing-priest-recovery" }
end

function M.install()
  if M._installed then return true end
  M.root()
  local lifecycle = lifecycle_authority()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not (lifecycle and type(lifecycle.authorize_missing_recovery) == "function"
    and type(rawget(_G, "tech_priests_canonical_respawn_pair_priest_0503")) == "function"
    and broker and type(broker.register_service) == "function")
  then return false end
  local registered = broker.register_service({
    name = "priest_missing_recovery_0503",
    category = "pair-lifecycle",
    interval = M.service_interval,
    priority = 26,
    budget = M.service_budget,
    fn = M.service,
    note = "0499 lease missing-priest recovery plus delayed canonical registration of orphan stations",
  })
  if not registered then return false end
  _G.TechPriestsPriestRecoverySafety0503 = M
  M._installed = true
  if log then log("[Tech-Priests 0.1.674-dev] broker-owned controlled missing-priest and completed re-imprint recovery installed") end
  return true
end

return M
