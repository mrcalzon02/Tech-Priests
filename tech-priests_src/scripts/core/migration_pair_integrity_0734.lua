-- Tech Priests 0.1.674-dev migration pair integrity audit.
--
-- Read-only verification for new-save and existing-save migration tests. Unlike
-- behavior audits that intentionally skip invalid pairs, this module inventories
-- every pairs_by_station entry and reports missing, duplicated, mismatched,
-- cross-force, and cross-surface station/priest links. It never repairs, respawns,
-- relinks, teleports, or removes a pair.

local M = {
  version = "0.1.674-dev",
  storage_key = "migration_pair_integrity_0734",
  interval = 607,
  recent_limit = 120,
}

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    read_only = true,
    stats = {},
    recent = {},
    last = {},
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  if state.read_only == nil then state.read_only = true end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.last = state.last or {}
  return state
end

local function stat(state, name, amount)
  state.stats[name] = (state.stats[name] or 0) + (amount or 1)
end

local function pair_map()
  return storage and storage.tech_priests
    and storage.tech_priests.pairs_by_station or {}
end

local function add_issue(snapshot, code, key, detail)
  snapshot.issue_count = snapshot.issue_count + 1
  snapshot.issue_counts[code] = (snapshot.issue_counts[code] or 0) + 1
  if #snapshot.issues < M.recent_limit then
    snapshot.issues[#snapshot.issues + 1] = {
      code = tostring(code),
      key = safe(key),
      detail = tostring(detail or ""),
    }
  end
end

local function unit(entity)
  return valid(entity) and entity.unit_number or nil
end

local function same_object(a, b)
  return a ~= nil and b ~= nil and a == b
end

function M.audit()
  local state = root()
  local snapshot = {
    tick = now(),
    read_only = true,
    total_entries = 0,
    table_entries = 0,
    valid_pairs = 0,
    invalid_pairs = 0,
    stations_seen = 0,
    priests_seen = 0,
    issue_count = 0,
    issue_counts = {},
    issues = {},
  }
  local stations, priests = {}, {}

  for key, pair in pairs(pair_map()) do
    snapshot.total_entries = snapshot.total_entries + 1
    if type(pair) ~= "table" then
      snapshot.invalid_pairs = snapshot.invalid_pairs + 1
      add_issue(snapshot, "pair-not-table", key, type(pair))
    else
      snapshot.table_entries = snapshot.table_entries + 1
      local station = pair.station
      local priest = pair.priest
      local station_valid = valid(station)
      local priest_valid = valid(priest)
      local station_unit = unit(station)
      local priest_unit = unit(priest)

      if not station_valid then add_issue(snapshot, "station-invalid", key, "station missing or invalid") end
      if not priest_valid then add_issue(snapshot, "priest-invalid", key, "priest missing or invalid") end

      if station_valid then
        snapshot.stations_seen = snapshot.stations_seen + 1
        local station_key = safe(station_unit or station)
        if stations[station_key] and not same_object(stations[station_key], pair) then
          add_issue(snapshot, "duplicate-station-link", key, station_key)
        else
          stations[station_key] = pair
        end
        if pair.station_unit ~= nil
          and tostring(pair.station_unit) ~= tostring(station_unit)
        then
          add_issue(snapshot, "station-unit-mismatch", key,
            safe(pair.station_unit) .. "!=" .. safe(station_unit))
        end
        if station_unit ~= nil and tostring(key) ~= tostring(station_unit) then
          add_issue(snapshot, "pair-map-key-mismatch", key,
            "station_unit=" .. safe(station_unit))
        end
      end

      if priest_valid then
        snapshot.priests_seen = snapshot.priests_seen + 1
        local priest_key = safe(priest_unit or priest)
        if priests[priest_key] and not same_object(priests[priest_key], pair) then
          add_issue(snapshot, "duplicate-priest-link", key, priest_key)
        else
          priests[priest_key] = pair
        end
        if pair.priest_unit ~= nil
          and tostring(pair.priest_unit) ~= tostring(priest_unit)
        then
          add_issue(snapshot, "priest-unit-mismatch", key,
            safe(pair.priest_unit) .. "!=" .. safe(priest_unit))
        end
      end

      if station_valid and priest_valid then
        if station.surface ~= priest.surface then
          add_issue(snapshot, "pair-surface-mismatch", key,
            safe(station.surface and station.surface.index)
              .. "!=" .. safe(priest.surface and priest.surface.index))
        end
        if station.force ~= priest.force then
          add_issue(snapshot, "pair-force-mismatch", key,
            safe(station.force and station.force.index)
              .. "!=" .. safe(priest.force and priest.force.index))
        end
      end

      if station_valid and priest_valid and snapshot.issue_count == 0 then
        -- This aggregate branch is corrected below per entry; it is intentionally
        -- not used for validity because snapshot issues include prior entries.
      end
      if station_valid and priest_valid then
        snapshot.valid_pairs = snapshot.valid_pairs + 1
      else
        snapshot.invalid_pairs = snapshot.invalid_pairs + 1
      end
    end
  end

  snapshot.complete = snapshot.issue_count == 0
  state.last = snapshot
  stat(state, "audits")
  stat(state, "entries-seen", snapshot.total_entries)
  stat(state, "issues-seen", snapshot.issue_count)
  if snapshot.complete then stat(state, "complete-observations")
  else stat(state, "incomplete-observations") end

  local signature_parts = {}
  for code, count in pairs(snapshot.issue_counts) do
    signature_parts[#signature_parts + 1] = code .. "=" .. tostring(count)
  end
  table.sort(signature_parts)
  local signature = table.concat(signature_parts, "|")
  if signature ~= (state.last_signature or "") then
    state.last_signature = signature
    for _, issue in ipairs(snapshot.issues) do
      state.recent[#state.recent + 1] = {
        tick = snapshot.tick,
        code = issue.code,
        key = issue.key,
        detail = issue.detail,
      }
    end
    while #state.recent > M.recent_limit do table.remove(state.recent, 1) end
  end
  return snapshot
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then return false end
  if diagnostics.migration_pair_integrity_0734_wrapped then return true end
  diagnostics.migration_pair_integrity_0734_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = root()
    local last = state.last
    if not last or last.tick == nil then last = M.audit() end
    lines[#lines + 1] = "PAIR-DUMP-0468 MIGRATION-PAIR-INTEGRITY-0734 enabled="
      .. safe(state.enabled)
      .. " read_only=true complete=" .. safe(last.complete)
      .. " entries=" .. safe(last.total_entries or 0)
      .. " valid_pairs=" .. safe(last.valid_pairs or 0)
      .. " invalid_pairs=" .. safe(last.invalid_pairs or 0)
      .. " stations=" .. safe(last.stations_seen or 0)
      .. " priests=" .. safe(last.priests_seen or 0)
      .. " issues=" .. safe(last.issue_count or 0)
      .. " mutations=0"
    for index = math.max(1, #state.recent - 12), #state.recent do
      local event = state.recent[index]
      if event then
        lines[#lines + 1] = "PAIR-DUMP-0468 migration-pair.recent["
          .. safe(index) .. "] tick=" .. safe(event.tick)
          .. " code=" .. safe(event.code)
          .. " key=" .. safe(event.key)
          .. " " .. safe(event.detail)
      end
    end
    return lines
  end
  return true
end

local function register_service()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not (broker and type(broker.register_service) == "function") then return false end
  local service = broker.register_service({
    name = "migration_pair_integrity_0734",
    category = "diagnostics",
    interval = M.interval,
    priority = 993,
    budget = 1,
    dynamic_budget = false,
    note = "read-only complete station priest pair migration integrity audit",
    fn = function()
      local snapshot = M.audit()
      return not snapshot.complete, "entries=" .. safe(snapshot.total_entries)
        .. " issues=" .. safe(snapshot.issue_count)
    end,
  })
  return service ~= nil
end

function M.install()
  local diagnostics_ok = patch_diagnostics()
  local broker_ok = register_service()
  _G.TechPriestsMigrationPairIntegrity0734 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] migration pair integrity audit armed diagnostics="
      .. safe(diagnostics_ok) .. " broker=" .. safe(broker_ok)
      .. " control_storage_writes=0 mutations=0")
  end
  return diagnostics_ok and broker_ok
end

return M
