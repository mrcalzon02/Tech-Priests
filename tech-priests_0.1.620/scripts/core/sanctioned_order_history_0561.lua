-- 0.1.561 Sanctioned Order History and Authority ledger.
-- Reporter/governance module only: watches completed order-queue history and
-- summarizes each priest's work record. It does not create work, move priests,
-- complete orders, or bypass the dispatcher/order-queue/action-arbiter stack.

local M = {}
M.version = "0.1.562"
M.storage_key = "sanctioned_order_history_0561"
M.authority_thresholds = { 1, 10, 100, 1000, 10000 }
M.audit_interval = 181

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v)
  if v == nil then return "nil" end
  local ok, out = pcall(function() return tostring(v) end)
  return ok and out or "?"
end
local function lower(v) return string.lower(tostring(v or "")) end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    ledgers = {},
    station_to_priest = {},
    stats = {},
  }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  root.ledgers = root.ledgers or {}
  root.station_to_priest = root.station_to_priest or {}
  root.stats = root.stats or {}
  return root
end

local function rank_base(pair)
  local name = lower((pair and pair.station and pair.station.valid and pair.station.name) or (pair and pair.priest and pair.priest.valid and pair.priest.name) or "")
  if name:find("planetary%-magos") or name:find("magos") then return 5, "Planetary Magos" end
  if name:find("senior") then return 3, "Senior Tech-Priest" end
  if name:find("intermediate") then return 2, "Intermediate Tech-Priest" end
  return 1, "Junior Tech-Priest"
end

local function family_for_pair(pair)
  local f = (pair and (pair.doctrine_family or pair.doctrine_camp or pair.camp or pair.doctrine)) or ""
  f = lower(f)
  if f:find("void",1,true) or f:find("space",1,true) then return "space" end
  if f:find("logistic",1,true) or f:find("reliquary",1,true) then return "logistics" end
  if f:find("forge",1,true) or f:find("quality",1,true) or f:find("industry",1,true) then return "industry" end
  if f:find("military",1,true) or f:find("ballistic",1,true) then return "military" end
  if f:find("energy",1,true) or f:find("force",1,true) then return "energy" end
  if f:find("science",1,true) or f:find("noospheric",1,true) then return "science" end
  return "sanctification"
end

local function priest_key(pair)
  if pair and valid(pair.priest) then return safe(pair.priest.unit_number) end
  if pair and valid(pair.station) then return "station:" .. safe(pair.station.unit_number) end
  return nil
end

local function station_key(pair)
  if pair and valid(pair.station) then return safe(pair.station.unit_number) end
  return nil
end

local function ledger_for(pair)
  local key = priest_key(pair)
  if not key then return nil end
  local root = ensure_root()
  local base, rank_label = rank_base(pair)
  local l = root.ledgers[key]
  if not l then
    l = {
      priest_key = key,
      station_unit = station_key(pair),
      first_seen_tick = now(),
      last_seen_tick = now(),
      base_authority = base,
      rank_label = rank_label,
      family = family_for_pair(pair),
      tasks_total = 0,
      consecrations = 0,
      repairs = 0,
      acquisitions = 0,
      logistics = 0,
      emergency_crafts = 0,
      constructions = 0,
      emergency_constructions = 0,
      combat = 0,
      other = 0,
      last_history_index = 0,
      recent = {},
    }
    root.ledgers[key] = l
  end
  l.last_seen_tick = now()
  l.station_unit = station_key(pair) or l.station_unit
  l.base_authority = base
  l.rank_label = rank_label
  l.family = family_for_pair(pair)
  if pair and valid(pair.priest) then l.priest_name = pair.priest.localised_name or pair.priest.name end
  if pair and valid(pair.station) then l.station_name = pair.station.name end
  return l
end

local function authority_points(ledger)
  local total = tonumber(ledger and ledger.tasks_total) or 0
  local points = 0
  for _, threshold in ipairs(M.authority_thresholds or {}) do
    if total >= threshold then points = points + 1 end
  end
  if points > 5 then points = 5 end
  return points
end

local function authority_rank(ledger)
  local base = tonumber(ledger and ledger.base_authority) or 1
  return base + authority_points(ledger)
end

local function note_recent(ledger, entry)
  -- 0.1.562: keep the ledger compact. The Conclave needs proof of service,
  -- not a verbose per-task dossier that bloats save-state and GUI text.
  ledger.recent = ledger.recent or {}
  ledger.recent[#ledger.recent + 1] = {
    tick = entry.tick or now(),
    summary = "sanctioned task completed",
  }
  while #ledger.recent > 8 do table.remove(ledger.recent, 1) end
end

local function classify_history(entry)
  local k = lower(((entry and entry.kind) or "") .. " " .. ((entry and entry.reason) or "") .. " " .. ((entry and entry.finish_reason) or ""))
  if k:find("consecr",1,true) or k:find("sanct",1,true) then return "consecrations" end
  if k:find("repair",1,true) then return "repairs" end
  if (k:find("construct",1,true) or k:find("build",1,true)) and k:find("emergency",1,true) then return "emergency_constructions" end
  if k:find("construct",1,true) or k:find("build",1,true) then return "constructions" end
  if k:find("combat",1,true) or k:find("defense",1,true) then return "combat" end
  if k:find("logistic",1,true) or k:find("supply",1,true) then return "logistics" end
  if k:find("emergency",1,true) or k:find("craft",1,true) then return "emergency_crafts" end
  if k:find("acqui",1,true) or k:find("gather",1,true) or k:find("mine",1,true) or k:find("scavenge",1,true) then return "acquisitions" end
  return "other"
end

local function audit_pair(pair)
  if not (pair and valid(pair.station) and valid(pair.priest)) then return end
  local q = pair.order_queue_0469
  local hist = q and q.history
  if type(hist) ~= "table" then ledger_for(pair); return end
  local l = ledger_for(pair)
  if not l then return end
  local start = tonumber(l.last_history_index) or 0
  if start > #hist then start = 0 end
  for i = start + 1, #hist do
    local entry = hist[i]
    if entry and entry.status == "complete" then
      local bucket = classify_history(entry)
      l.tasks_total = (l.tasks_total or 0) + 1
      l[bucket] = (l[bucket] or 0) + 1
      if bucket == "emergency_constructions" then l.constructions = (l.constructions or 0) + 1 end
      l.last_completed_tick = entry.tick or now()
      note_recent(l, entry)
    end
  end
  l.last_history_index = #hist
  l.authority_points = authority_points(l)
  l.authority_rank = authority_rank(l)
  l.order_capacity = l.authority_rank
end

function M.audit_all()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  local count = 0
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    audit_pair(pair)
    count = count + 1
  end
  local root = ensure_root()
  root.stats.last_audit_tick = now()
  root.stats.last_pair_count = count
end

function M.get_ledgers(force)
  M.audit_all()
  local out = {}
  local root = ensure_root()
  for _, l in pairs(root.ledgers or {}) do
    local include = true
    if force and force.valid and l.station_unit and storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
      include = false
      for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
        if pair and valid(pair.station) and safe(pair.station.unit_number) == safe(l.station_unit) and pair.station.force == force then include = true; break end
      end
    end
    if include then out[#out + 1] = l end
  end
  table.sort(out, function(a,b)
    if (a.base_authority or 0) ~= (b.base_authority or 0) then return (a.base_authority or 0) > (b.base_authority or 0) end
    return tostring(a.station_unit or "") < tostring(b.station_unit or "")
  end)
  return out
end

function M.get_authority(pair)
  local l = ledger_for(pair)
  if not l then return 1 end
  return authority_rank(l)
end

function M.get_order_capacity(pair)
  return M.get_authority(pair)
end

local function print_status(player)
  local ledgers = M.get_ledgers(player and player.force or nil)
  if player and player.valid then
    player.print("[tp-order-history-0561] sanctioned ledgers=" .. tostring(#ledgers) .. " authority thresholds=1/10/100/1000/10000")
    for i=1, math.min(#ledgers, 8) do
      local l = ledgers[i]
      player.print("  " .. tostring(l.rank_label) .. " station=" .. safe(l.station_unit) .. " authority=" .. safe(authority_rank(l)) .. " service=" .. safe(l.tasks_total) .. " authority-points=" .. safe(authority_points(l)) .. "/5")
    end
  end
end

function M.install()
  ensure_root()
  _G.tech_priests_0561_sanctioned_order_history = M
  _G.tech_priests_0561_get_pair_authority = M.get_authority
  _G.tech_priests_0561_get_order_capacity = M.get_order_capacity
  if script and TechPriestsRuntimeEventRegistry and TechPriestsRuntimeEventRegistry.on_nth_tick then
    TechPriestsRuntimeEventRegistry.on_nth_tick(M.audit_interval, M.audit_all, { owner = "sanctioned_order_history_0561", category = "governance" })
  end
  if commands then
    pcall(function() commands.remove_command("tp-order-history-0561") end)
    commands.add_command("tp-order-history-0561", "Tech Priests: show sanctioned order history and authority ledgers.", function(cmd)
      local player = cmd.player_index and game.get_player(cmd.player_index) or nil
      print_status(player)
    end)
  end
  if log then log("[Tech-Priests 0.1.562] sanctioned order history compact authority ledger installed") end
end

return M
