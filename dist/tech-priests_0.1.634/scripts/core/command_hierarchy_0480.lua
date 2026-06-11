-- scripts/core/command_hierarchy_0480.lua
-- Tech Priests 0.1.480
--
-- Strict command-hierarchy authority for station/priest networks.
-- 0.1.617: distributed-subordinate fairness prevents one superior from hoarding all eligible subordinates when peer superiors are in range.
-- Direct command capacity is intentionally narrow:
--   Planetary Magos -> 2 Senior subordinates
--   Senior          -> 4 Intermediate subordinates
--   Intermediate    -> 8 Junior subordinates
--   Junior          -> no lower-rank subordinates; up to 16 peer links
--
-- The goal is not to make the network cleverer.  The goal is to stop every
-- higher station from treating every lower station as an eligible helper at
-- once.  One superior owns a direct subordinate; subordinate scheduling,
-- subordinate-area movement authority, diagnostics, and Work State display can
-- all read the same command slate.

local M = {}
M.version = "0.1.624"
M.storage_key = "command_hierarchy_0480"
M.rebuild_interval = 300
M.max_link_distance = 220
M.default_peer_limit = 16

M.direct_limits = {
  [4] = 2, -- planetary magos
  [3] = 4, -- senior
  [2] = 8, -- intermediate
  [1] = 0  -- junior
}

M.peer_limits = {
  [4] = 0,
  [3] = 0,
  [2] = 0,
  [1] = 16
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function topology_signature()
  -- 0.1.624: command hierarchy is based on mostly-static station topology
  -- (station unit, force, surface, rank, and station position). Rebuilding the
  -- distributed slate is O(domain pairs * eligible candidates); computing this
  -- compact signature is O(pairs). Periodic pulses can therefore skip the
  -- expensive rebuild when the command topology has not changed.
  local rows = {}
  for _, pair in pairs(pair_map()) do
    if valid(pair and pair.station) and valid(pair and pair.priest) then
      local st = pair.station
      local pos = st.position or {}
      rows[#rows + 1] = table.concat({
        tostring(st.unit_number or "?"),
        tostring(st.surface and st.surface.index or st.surface and st.surface.name or "?"),
        tostring(st.force and st.force.index or st.force and st.force.name or "?"),
        tostring(M.rank(pair)),
        tostring(math.floor((pos.x or 0) * 10 + 0.5)),
        tostring(math.floor((pos.y or 0) * 10 + 0.5))
      }, ":")
    end
  end
  table.sort(rows)
  return table.concat(rows, "|")
end

local function station_unit(pair)
  return pair and pair.station and pair.station.valid and pair.station.unit_number or nil
end

local function dist_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function same_domain(a, b)
  return valid(a and a.station) and valid(b and b.station)
     and a.station.surface == b.station.surface
     and a.station.force == b.station.force
end

function M.rank(pair)
  if not pair then return 0 end
  if _G.tech_priests_get_pair_tier_rank then
    local ok, r = pcall(_G.tech_priests_get_pair_tier_rank, pair)
    if ok and tonumber(r) then return tonumber(r) end
  end
  if _G.tech_priests_pair_rank_value_0188 then
    local ok, r = pcall(_G.tech_priests_pair_rank_value_0188, pair)
    if ok and tonumber(r) then return tonumber(r) end
  end
  local n = tostring(pair.tier or pair.rank or "") .. " " .. tostring(pair.station and pair.station.valid and pair.station.name or "") .. " " .. tostring(pair.priest and pair.priest.valid and pair.priest.name or "")
  n = string.lower(n)
  if n:find("void", 1, true) then return 5 end
  if n:find("planetary%-magos", 1, false) or n:find("magos", 1, true) then return 4 end
  if n:find("senior", 1, true) then return 3 end
  if n:find("intermediate", 1, true) then return 2 end
  if n:find("junior", 1, true) then return 1 end
  return 0
end

function M.rank_name(rank)
  rank = tonumber(rank) or 0
  if rank >= 5 then return "Void Command" end
  if rank == 4 then return "Planetary Magos" end
  if rank == 3 then return "Senior Magos" end
  if rank == 2 then return "Intermediate Adept" end
  if rank == 1 then return "Junior Tech-Priest" end
  return "Unranked Servitor-Noise"
end

function M.direct_limit_for(pair_or_rank)
  local rank = type(pair_or_rank) == "table" and M.rank(pair_or_rank) or tonumber(pair_or_rank) or 0
  return tonumber(M.direct_limits[rank]) or 0
end

function M.peer_limit_for(pair_or_rank)
  local rank = type(pair_or_rank) == "table" and M.rank(pair_or_rank) or tonumber(pair_or_rank) or 0
  return tonumber(M.peer_limits[rank]) or 0
end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {} }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  root.stats = root.stats or {}
  return root
end

local function clear_pair(pair)
  if not pair then return end
  local rank = M.rank(pair)
  pair.command_hierarchy_0480 = {
    version = M.version,
    tick = now(),
    rank = rank,
    rank_name = M.rank_name(rank),
    direct_limit = M.direct_limit_for(rank),
    peer_limit = M.peer_limit_for(rank),
    superior_unit = nil,
    superior_rank = nil,
    direct_subordinate_units = {},
    peer_units = {},
    refused_subordinates = {},
    root_unit = station_unit(pair),
    doctrine = "strict-command-slate"
  }
end

local function groups_by_domain()
  local domains = {}
  for _, pair in pairs(pair_map()) do
    if valid(pair and pair.station) and valid(pair and pair.priest) then
      local force_name = pair.station.force and pair.station.force.name or "?"
      local surface_name = pair.station.surface and pair.station.surface.name or "?"
      local key = force_name .. "::" .. surface_name
      domains[key] = domains[key] or {}
      domains[key][#domains[key] + 1] = pair
      clear_pair(pair)
    end
  end
  return domains
end

local function sorted_by_distance(parent, children)
  table.sort(children, function(a, b)
    local da = dist_sq(parent.station.position, a.station.position)
    local db = dist_sq(parent.station.position, b.station.position)
    if da ~= db then return da < db end
    return (station_unit(a) or 0) < (station_unit(b) or 0)
  end)
end

local function direct_distance_ok(parent, child)
  if not same_domain(parent, child) then return false end
  local d = math.sqrt(dist_sq(parent.station.position, child.station.position))
  if d <= M.max_link_distance then return true end
  return false
end

local function direct_load(parent)
  local h = parent and parent.command_hierarchy_0480 or nil
  return #(h and h.direct_subordinate_units or {})
end

local function direct_fill_ratio(parent, rank)
  local limit = M.direct_limit_for(rank or M.rank(parent))
  if limit <= 0 then return 999999 end
  return direct_load(parent) / limit
end

local function assign_direct_subordinates(domain_pairs)
  local root = ensure_root()
  local assigned = {}
  local stats = root.stats or {}
  root.stats = stats
  stats.distributed_subordinate_candidates = 0
  stats.distributed_subordinate_load_balanced = 0
  stats.distributed_subordinate_assignments = 0

  for parent_rank = 4, 2, -1 do
    local child_rank = parent_rank - 1
    local parents, children = {}, {}
    for _, pair in ipairs(domain_pairs) do
      local r = M.rank(pair)
      if r == parent_rank then parents[#parents + 1] = pair end
      if r == child_rank then children[#children + 1] = pair end
    end
    table.sort(parents, function(a, b) return (station_unit(a) or 0) < (station_unit(b) or 0) end)
    table.sort(children, function(a, b) return (station_unit(a) or 0) < (station_unit(b) or 0) end)

    for _, child in ipairs(children) do
      if not assigned[station_unit(child)] then
        local candidates = {}
        for _, parent in ipairs(parents) do
          local current = direct_load(parent)
          if current < M.direct_limit_for(parent_rank) and direct_distance_ok(parent, child) then
            candidates[#candidates + 1] = parent
          end
        end
        if #candidates > 1 then stats.distributed_subordinate_candidates = (stats.distributed_subordinate_candidates or 0) + 1 end
        table.sort(candidates, function(a, b)
          -- Distributed-subordinate doctrine: when multiple peer superiors can take
          -- the same child, prefer the least-loaded command chain first, then use
          -- proximity as the tie-breaker. This prevents the nearest/first senior
          -- from hoarding all available intermediates while another eligible senior
          -- stands empty inside the same noospheric range.
          local fa = direct_fill_ratio(a, parent_rank)
          local fb = direct_fill_ratio(b, parent_rank)
          if fa ~= fb then return fa < fb end
          local la = direct_load(a)
          local lb = direct_load(b)
          if la ~= lb then return la < lb end
          local da = dist_sq(a.station.position, child.station.position)
          local db = dist_sq(b.station.position, child.station.position)
          if da ~= db then return da < db end
          return (station_unit(a) or 0) < (station_unit(b) or 0)
        end)
        local parent = candidates[1]
        if parent then
          if #candidates > 1 and direct_load(parent) > 0 then
            stats.distributed_subordinate_load_balanced = (stats.distributed_subordinate_load_balanced or 0) + 1
          end
          local ph = parent.command_hierarchy_0480
          local ch = child.command_hierarchy_0480
          ph.direct_subordinate_units[#ph.direct_subordinate_units + 1] = station_unit(child)
          ch.superior_unit = station_unit(parent)
          ch.superior_rank = parent_rank
          ch.root_unit = (parent.command_hierarchy_0480 and parent.command_hierarchy_0480.root_unit) or station_unit(parent)
          assigned[station_unit(child)] = station_unit(parent)
          stats.distributed_subordinate_assignments = (stats.distributed_subordinate_assignments or 0) + 1
        else
          child.command_hierarchy_0480.refused_reason = "no superior of next rank had an open command socket within noospheric range"
        end
      end
    end
  end
end

local function assign_junior_peers(domain_pairs)
  local juniors = {}
  for _, pair in ipairs(domain_pairs) do
    if M.rank(pair) == 1 then juniors[#juniors + 1] = pair end
  end
  for _, pair in ipairs(juniors) do
    local h = pair.command_hierarchy_0480
    local candidates = {}
    for _, other in ipairs(juniors) do
      if other ~= pair and same_domain(pair, other) and direct_distance_ok(pair, other) then candidates[#candidates + 1] = other end
    end
    sorted_by_distance(pair, candidates)
    for i = 1, math.min(#candidates, M.peer_limit_for(pair)) do
      h.peer_units[#h.peer_units + 1] = station_unit(candidates[i])
    end
  end
end

function M.rebuild(reason)
  local root = ensure_root()
  if not root.enabled then return false end
  root.stats = root.stats or {}
  local sig = topology_signature()
  if reason ~= "command" and reason ~= "install" and reason ~= "forced" and root.last_topology_signature == sig then
    root.last_rebuild_tick = now()
    root.last_rebuild_reason = reason or "periodic-skip"
    root.stats.rebuild_skips_same_topology = (root.stats.rebuild_skips_same_topology or 0) + 1
    return false
  end
  local domains = groups_by_domain()
  local pairs_seen = 0
  for _, list in pairs(domains) do
    pairs_seen = pairs_seen + #list
    assign_direct_subordinates(list)
    assign_junior_peers(list)
  end
  root.last_rebuild_tick = now()
  root.last_rebuild_reason = reason or "periodic"
  root.last_topology_signature = sig
  root.stats.rebuilds = (root.stats.rebuilds or 0) + 1
  root.stats.last_pairs_seen = pairs_seen
  return true
end

local function maybe_rebuild(reason)
  local root = ensure_root()
  if not root.enabled then return false end
  if now() >= (root.next_rebuild_tick or 0) then
    root.next_rebuild_tick = now() + M.rebuild_interval
    return M.rebuild(reason)
  end
  root.stats = root.stats or {}
  root.stats.rebuild_skips_not_due = (root.stats.rebuild_skips_not_due or 0) + 1
  return false
end

function M.hierarchy(pair)
  if not pair then return nil end
  maybe_rebuild("query")
  if not pair.command_hierarchy_0480 then clear_pair(pair) end
  return pair.command_hierarchy_0480
end

function M.pair_by_station_unit(unit)
  if not unit then return nil end
  local map = pair_map()
  return map[unit] or map[tostring(unit)]
end

function M.superior(pair)
  local h = M.hierarchy(pair)
  return h and M.pair_by_station_unit(h.superior_unit) or nil
end

function M.direct_subordinates(pair)
  local out = {}
  local h = M.hierarchy(pair)
  if not h then return out end
  for _, unit in ipairs(h.direct_subordinate_units or {}) do
    local p = M.pair_by_station_unit(unit)
    if p and valid(p.station) and valid(p.priest) then out[#out + 1] = p end
  end
  return out
end

function M.peers(pair)
  local out = {}
  local h = M.hierarchy(pair)
  if not h then return out end
  for _, unit in ipairs(h.peer_units or {}) do
    local p = M.pair_by_station_unit(unit)
    if p and valid(p.station) and valid(p.priest) then out[#out + 1] = p end
  end
  return out
end

function M.is_direct_subordinate(parent, child)
  if not (parent and child) then return false end
  local ch = M.hierarchy(child)
  return ch and ch.superior_unit == station_unit(parent)
end

function M.available_for_subordinate_writ(parent, child)
  if not M.is_direct_subordinate(parent, child) then return false end
  if not (valid(child.station) and valid(child.priest) and same_domain(parent, child)) then return false end
  if child.dead or child.recalling or child.deploying then return false end
  if child.emergency_assist_job_0187 or child.emergency_craft or child.scavenge or child.inventory_scan then return false end
  if child.repair_target or child.consecration_target or child.combat_target then return false end
  return true
end

function M.available_direct_subordinates(parent, limit)
  local out = {}
  for _, child in ipairs(M.direct_subordinates(parent)) do
    if M.available_for_subordinate_writ(parent, child) then
      out[#out + 1] = { pair = child, dist = dist_sq(parent.station.position, child.station.position), rank = M.rank(child) }
    end
  end
  table.sort(out, function(a, b)
    if a.rank ~= b.rank then return a.rank > b.rank end
    return (a.dist or 0) < (b.dist or 0)
  end)
  while limit and #out > limit do table.remove(out) end
  return out
end

function M.direct_capacity_remaining(pair)
  local h = M.hierarchy(pair)
  if not h then return 0 end
  local used = #(h.direct_subordinate_units or {})
  local cap = tonumber(h.direct_limit or 0) or 0
  return math.max(0, cap - used)
end

function M.patch_subordinate_scheduler()
  local ok, Sub = pcall(require, "scripts.core.subordinate_scheduler")
  if not (ok and type(Sub) == "table") then return false end
  if Sub.command_hierarchy_wrapped_0480 then return true end
  Sub.command_hierarchy_wrapped_0480 = true
  local old_queue = Sub.queue
  local old_has_capacity = Sub.has_capacity
  local old_is_available = Sub.is_subordinate_available
  local old_find = Sub.find_subordinates

  Sub.queue = function(pair)
    local q = old_queue and old_queue(pair) or nil
    if q then
      local h = M.hierarchy(pair)
      q.limit = h and tonumber(h.direct_limit or 0) or q.limit or 0
      if (q.count or 0) > (q.limit or 0) then q.over_limit_0480 = true end
    end
    return q
  end

  Sub.has_capacity = function(pair)
    local h = M.hierarchy(pair)
    if h then
      local q = Sub.queue(pair)
      return q and (q.count or 0) < (h.direct_limit or 0)
    end
    return old_has_capacity and old_has_capacity(pair) or false
  end

  Sub.is_subordinate_available = function(lead_pair, candidate)
    return M.available_for_subordinate_writ(lead_pair, candidate)
  end

  Sub.find_subordinates = function(pair, limit)
    local h = M.hierarchy(pair)
    local cap = h and tonumber(h.direct_limit or 0) or 0
    if cap <= 0 then return {} end
    local q = Sub.queue(pair)
    local remaining = math.max(0, math.min(limit or cap, cap - (q and q.count or 0)))
    if remaining <= 0 then return {} end
    return M.available_direct_subordinates(pair, remaining)
  end

  local root = ensure_root()
  root.stats.subordinate_scheduler_wrapped = true
  root.stats.old_scheduler_present = old_find ~= nil or old_is_available ~= nil
  return true
end

function M.patch_magos_authority()
  local ok, Authority0472 = pcall(require, "scripts.core.combat_magos_movement_authority_0472")
  if not (ok and type(Authority0472) == "table") then return false end
  if Authority0472.command_hierarchy_wrapped_0480 then return true end
  Authority0472.command_hierarchy_wrapped_0480 = true
  local prev_position = Authority0472.position_in_authority
  if type(prev_position) == "function" then
    Authority0472.position_in_authority = function(pair, pos)
      local ok_primary, yes, anchor = pcall(prev_position, pair, pos)
      if ok_primary and yes and anchor and anchor.role == "primary" then return true, anchor end
      if not (pair and valid(pair.station) and valid(pair.priest) and pos) then return false, nil end
      for _, sub in ipairs(M.direct_subordinates(pair)) do
        if valid(sub.station) then
          local r = 30
          if _G.refresh_pair_radius then local okr, got = pcall(_G.refresh_pair_radius, sub); if okr and tonumber(got) then r = tonumber(got) end end
          if dist_sq(sub.station.position, pos) <= r * r then
            return true, { pair = sub, role = "strict-subordinate", station_unit = station_unit(sub), radius = r }
          end
        end
      end
      return false, nil
    end
  end
  ensure_root().stats.magos_authority_wrapped = true
  return true
end

local function describe_pair_line(pair)
  local h = M.hierarchy(pair)
  if not h then return "no command slate" end
  local superior = M.superior(pair)
  return "station#" .. safe(station_unit(pair)) .. " " .. safe(h.rank_name) .. " superior=" .. safe(superior and station_unit(superior) or "none") .. " subordinates=" .. safe(#(h.direct_subordinate_units or {})) .. "/" .. safe(h.direct_limit or 0) .. " peers=" .. safe(#(h.peer_units or {})) .. "/" .. safe(h.peer_limit or 0)
end

function M.describe_pair(pair)
  local lines = {}
  local h = M.hierarchy(pair)
  if not h then return { "No command slate has been stamped for this station." } end
  lines[#lines + 1] = describe_pair_line(pair)
  local superior = M.superior(pair)
  lines[#lines + 1] = "Superior seal: " .. safe(superior and ((superior.station and superior.station.valid and superior.station.name or "station") .. "#" .. tostring(station_unit(superior) or "?")) or "none")
  lines[#lines + 1] = "Direct subordinate sockets: " .. safe(#(h.direct_subordinate_units or {})) .. "/" .. safe(h.direct_limit or 0)
  for i, child in ipairs(M.direct_subordinates(pair)) do
    lines[#lines + 1] = "  " .. safe(i) .. ". station#" .. safe(station_unit(child)) .. " " .. safe(M.rank_name(M.rank(child))) .. " mode=" .. safe(child.mode or "idle")
  end
  if (h.peer_limit or 0) > 0 then
    lines[#lines + 1] = "Peer communion sockets: " .. safe(#(h.peer_units or {})) .. "/" .. safe(h.peer_limit or 0)
    for i, peer in ipairs(M.peers(pair)) do
      if i > 16 then lines[#lines + 1] = "  ...additional peer echoes sealed"; break end
      lines[#lines + 1] = "  peer " .. safe(i) .. ": station#" .. safe(station_unit(peer)) .. " mode=" .. safe(peer.mode or "idle")
    end
  end
  if h.refused_reason then lines[#lines + 1] = "Unclaimed note: " .. safe(h.refused_reason) end
  return lines
end

function M.describe_all()
  M.rebuild("describe-all")
  local out = {}
  local list = {}
  for _, pair in pairs(pair_map()) do if valid(pair and pair.station) then list[#list + 1] = pair end end
  table.sort(list, function(a, b)
    local ra, rb = M.rank(a), M.rank(b)
    if ra ~= rb then return ra > rb end
    return (station_unit(a) or 0) < (station_unit(b) or 0)
  end)
  for _, pair in ipairs(list) do out[#out + 1] = describe_pair_line(pair) end
  return out
end

function M.patch_diagnostics()
  local diag = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diag and type(diag.pair_dump_lines) == "function") then return false end
  if diag.command_hierarchy_wrapped_0480 then return true end
  local prev = diag.pair_dump_lines
  diag.command_hierarchy_wrapped_0480 = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local root = ensure_root()
    maybe_rebuild("diagnostics")
    lines[#lines + 1] = "COMMAND-HIERARCHY-0480 BEGIN enabled=" .. safe(root.enabled) .. " rebuilds=" .. safe(root.stats.rebuilds or 0) .. " last_pairs=" .. safe(root.stats.last_pairs_seen or 0)
    for _, line in ipairs(M.describe_all()) do lines[#lines + 1] = "COMMAND-HIERARCHY-0480 " .. line end
    lines[#lines + 1] = "COMMAND-HIERARCHY-0480 END"
    return lines
  end
  return true
end

local function selected_pair(player)
  if not (player and player.valid) then return nil end
  local selected = player.selected
  if selected and selected.valid and storage and storage.tech_priests then
    return (storage.tech_priests.pairs_by_station or {})[selected.unit_number]
        or (storage.tech_priests.pairs_by_priest or {})[selected.unit_number]
  end
  return nil
end

function M.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-command-hierarchy-0480") end end)
  commands.add_command("tp-command-hierarchy-0480", "Tech Priests 0.1.480: inspect/toggle strict command hierarchy. Usage: status|all|on|off|rebuild", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = string.lower(tostring(event and event.parameter or "status"))
    local root = ensure_root()
    if param == "off" or param == "disable" then root.enabled = false end
    if param == "on" or param == "enable" then root.enabled = true end
    if param == "rebuild" then M.rebuild("command") end
    if player and player.valid then
      if param == "all" then
        for _, line in ipairs(M.describe_all()) do player.print("[tp-command-hierarchy-0480] " .. line) end
      else
        local pair = selected_pair(player)
        if pair then for _, line in ipairs(M.describe_pair(pair)) do player.print("[tp-command-hierarchy-0480] " .. line) end
        else
          player.print("[tp-command-hierarchy-0480] enabled=" .. safe(root.enabled) .. " rebuilds=" .. safe(root.stats.rebuilds or 0) .. " topology_skips=" .. safe(root.stats.rebuild_skips_same_topology or 0) .. " not_due_skips=" .. safe(root.stats.rebuild_skips_not_due or 0) .. " limits: planetary=2 senior=4 intermediate=8 junior-peer=16 distributed_assignments=" .. safe(root.stats.distributed_subordinate_assignments or 0) .. " multi_candidate=" .. safe(root.stats.distributed_subordinate_candidates or 0))
          player.print("[tp-command-hierarchy-0480] select a station/priest or use /tp-command-hierarchy-0480 all")
        end
      end
    end
  end)
end


function M.report_lines()
  local r = ensure_root()
  local st = r.stats or {}
  return { "[tp-runtime-report] command-hierarchy-0480 rebuilds=" .. safe(st.rebuilds or 0) .. " topology_skips=" .. safe(st.rebuild_skips_same_topology or 0) .. " not_due_skips=" .. safe(st.rebuild_skips_not_due or 0) .. " last_pairs=" .. safe(st.last_pairs_seen or 0) .. " distributed_assignments=" .. safe(st.distributed_subordinate_assignments or 0) .. " multi_candidate=" .. safe(st.distributed_subordinate_candidates or 0) .. " load_balanced=" .. safe(st.distributed_subordinate_load_balanced or 0) }
end

function M.tick()
  maybe_rebuild("periodic")
end

function M.install()
  if M._installed then return true end
  M._installed = true
  ensure_root()
  M.rebuild("install")
  M.patch_subordinate_scheduler()
  M.patch_magos_authority()
  M.patch_diagnostics()
  _G.TECH_PRIESTS_COMMAND_HIERARCHY_0480 = M
  _G.tech_priests_0480_command_hierarchy_for_pair = M.hierarchy
  _G.tech_priests_0480_direct_subordinates = M.direct_subordinates
  _G.tech_priests_0480_superior = M.superior
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(M.rebuild_interval, function() M.tick() end, { owner = "command_hierarchy_0480", category = "scheduler", priority = "late" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(M.rebuild_interval, function() M.tick() end) end)
  end
  M.register_commands()
  if log then log("[Tech-Priests 0.1.624] strict distributed command hierarchy installed: 2/4/8 direct subordinate sockets, junior peer communion only") end
  return true
end

return M
