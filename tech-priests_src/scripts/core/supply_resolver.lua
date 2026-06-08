-- scripts/core/supply_resolver.lua
-- Tech Priests 0.1.321 unified supply acquisition resolver migration pass 1.
--
-- Consolidates station cram, local scavenge, inventory scan, logistics request,
-- and emergency craft acquisition into one named decision point. Observe-only by
-- default; active acquisition is enabled only with /tp-supply-0321 enable.

local Resolver = {}
Resolver.version = "0.1.321"
Resolver.storage_key = "tech_priests_supply_resolver_0319"
Resolver.phase = {
  station_cram = "station-cram",
  scavenge = "scavenge",
  inventory_scan = "inventory-scan",
  logistics_request = "logistics-request",
  emergency_craft = "emergency-craft",
  no_request = "no-request"
}


-- 0.1.321 migration note:
-- The resolver now owns the public supply-facing compatibility symbols, while
-- the historical control.lua implementations are captured here as legacy
-- delegates. This keeps old call sites alive while giving future passes one
-- canonical module surface to move real bodies into.
Resolver.legacy = Resolver.legacy or {}
Resolver.shim_names = {
  "build_supply_request",
  "maybe_start_supply_scavenge",
  "issue_station_logistic_request",
  "handle_logistic_inventory_scan",
  "handle_priest_cram_task",
  "maybe_start_cram_mode",
  "handle_priest_scavenge_task",
  "start_logistic_scavenge_inventory_scan",
  "find_scavenge_source_for_request",
  "tech_priests_clear_interruptible_supply_work",
  "tech_priests_abort_if_supply_request_obsolete",
  "tech_priests_station_inventory_has_requested_supply_0173",
  "tech_priests_clear_supply_search_because_station_was_supplied_0173",
  "tech_priests_interrupt_supply_search_if_station_supplied_0173",
  "tech_priests_interrupt_cram_if_station_item_removed_0174"
}

function Resolver.capture_legacy_symbol(name, fn)
  if type(name) ~= "string" or type(fn) ~= "function" then return false end
  if Resolver.legacy[name] == nil then
    Resolver.legacy[name] = fn
    return true
  end
  return false
end

function Resolver.legacy_call(name, ...)
  local fn = Resolver.legacy and Resolver.legacy[name] or nil
  if type(fn) ~= "function" then return false, nil end
  return pcall(fn, ...)
end

function Resolver.call_legacy_or_false(name, ...)
  local ok, result = Resolver.legacy_call(name, ...)
  if ok then return result end
  return false
end

function Resolver.install_legacy_shims(legacy)
  legacy = legacy or {}
  for name, fn in pairs(legacy) do
    Resolver.capture_legacy_symbol(name, fn)
  end

  -- Shims deliberately remain tiny. The behavior still delegates to the captured
  -- historical body unless or until that body is migrated into this module.
  _G.build_supply_request = function(pair, kind, target)
    return Resolver.build_supply_request_shim(pair, kind, target)
  end
  _G.maybe_start_supply_scavenge = function(pair, kind, target)
    return Resolver.maybe_start_supply_scavenge_shim(pair, kind, target)
  end
  _G.issue_station_logistic_request = function(pair, request)
    return Resolver.issue_station_logistic_request_shim(pair, request)
  end
  _G.handle_logistic_inventory_scan = function(pair)
    return Resolver.handle_logistic_inventory_scan_shim(pair)
  end
  _G.handle_priest_cram_task = function(pair)
    return Resolver.handle_priest_cram_task_shim(pair)
  end
  _G.maybe_start_cram_mode = function(pair, request)
    return Resolver.maybe_start_cram_mode_shim(pair, request)
  end
  _G.handle_priest_scavenge_task = function(pair)
    return Resolver.handle_priest_scavenge_task_shim(pair)
  end
  _G.tech_priests_clear_interruptible_supply_work = function(pair)
    return Resolver.clear_interruptible_supply_work_shim(pair)
  end

  local root = Resolver.ensure_root()
  root.shims_installed = true
  root.shims_installed_tick = game and game.tick or 0
  root.shim_count = 8
  return true
end

function Resolver.build_supply_request_shim(pair, kind, target)
  if kind == "repair-pack" then kind = "repair" end
  local ok, request = Resolver.legacy_call("build_supply_request", pair, kind, target)
  if ok then return Resolver.sanitize_request(request) end
  return nil
end

function Resolver.maybe_start_supply_scavenge_shim(pair, kind, target)
  if kind == "repair-pack" then kind = "repair" end
  if pair then Resolver.sanitize_pair(pair) end
  local state = Resolver.ensure_pair_state(pair)
  if state then
    state.last_public_call = "maybe_start_supply_scavenge"
    state.last_public_call_tick = game and game.tick or 0
    state.last_public_kind = kind
  end
  local ok, result = Resolver.legacy_call("maybe_start_supply_scavenge", pair, kind, target)
  if ok then return result end
  return false
end

function Resolver.issue_station_logistic_request_shim(pair, request)
  request = Resolver.sanitize_request(request)
  local state = Resolver.ensure_pair_state(pair)
  if state then
    state.last_public_call = "issue_station_logistic_request"
    state.last_public_call_tick = game and game.tick or 0
    state.last_public_kind = request and request.kind or nil
  end
  local ok, result = Resolver.legacy_call("issue_station_logistic_request", pair, request)
  if ok then return result end
  return false
end

function Resolver.handle_logistic_inventory_scan_shim(pair)
  if pair then Resolver.sanitize_pair(pair) end
  local state = Resolver.ensure_pair_state(pair)
  if state then
    state.last_public_call = "handle_logistic_inventory_scan"
    state.last_public_call_tick = game and game.tick or 0
  end
  local ok, result = Resolver.legacy_call("handle_logistic_inventory_scan", pair)
  if ok then return result end
  return false
end

function Resolver.handle_priest_cram_task_shim(pair)
  local ok, result = Resolver.legacy_call("handle_priest_cram_task", pair)
  if ok then return result end
  return false
end

function Resolver.maybe_start_cram_mode_shim(pair, request)
  request = Resolver.sanitize_request(request)
  local ok, result = Resolver.legacy_call("maybe_start_cram_mode", pair, request)
  if ok then return result end
  return false
end

function Resolver.handle_priest_scavenge_task_shim(pair)
  if pair then Resolver.sanitize_pair(pair) end
  local ok, result = Resolver.legacy_call("handle_priest_scavenge_task", pair)
  if ok then return result end
  return false
end

function Resolver.clear_interruptible_supply_work_shim(pair)
  local ok, result = Resolver.legacy_call("tech_priests_clear_interruptible_supply_work", pair)
  if ok then return result end
  return Resolver.clear_interruptible(pair, "shim-fallback")
end

local function g(name) return rawget(_G, name) end
local function callable(name) local fn = g(name); if type(fn) == "function" then return fn end; return nil end
local function safe_call(name, ...) local fn = callable(name); if not fn then return false, nil end; return pcall(fn, ...) end
local function now() return game and game.tick or 0 end
local function valid_entity(entity) return entity and entity.valid end
local function valid_pair(pair) return pair and valid_entity(pair.station) and valid_entity(pair.priest) end
local function pair_unit(pair) return pair and pair.station and pair.station.valid and pair.station.unit_number or "?" end

function Resolver.ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Resolver.storage_key] = storage.tech_priests[Resolver.storage_key] or {
    version = Resolver.version,
    enabled = false,
    dry_run = true,
    created_tick = now(),
    stats = {}
  }
  local root = storage.tech_priests[Resolver.storage_key]
  root.version = Resolver.version
  root.stats = root.stats or {}
  return root
end

function Resolver.is_enabled() return Resolver.ensure_root().enabled == true end
function Resolver.set_enabled(value)
  local root = Resolver.ensure_root()
  root.enabled = value == true
  root.dry_run = not root.enabled
  root.changed_tick = now()
  return root.enabled
end

function Resolver.ensure_pair_state(pair)
  if not pair then return nil end
  pair.supply_resolver_0319 = pair.supply_resolver_0319 or {}
  local state = pair.supply_resolver_0319
  state.version = Resolver.version
  state.last_seen_tick = now()
  return state
end

function Resolver.sanitize_pair(pair)
  if not pair then return end
  local fn = callable("tech_priests_0296_sanitize_pair_supply_state")
  if fn then pcall(fn, pair) end
end

function Resolver.sanitize_request(request)
  if not request then return nil end
  local fn = callable("tech_priests_0296_sanitize_request")
  if fn then
    local ok, result = pcall(fn, request)
    if ok and result then return result end
  end
  return request
end

function Resolver.build_request(pair, kind, target)
  if not valid_pair(pair) then return nil end
  local request = pair.active_supply_request
  if request and kind and request.kind ~= kind then request = nil end
  if not request then
    local ok, result = safe_call("build_supply_request", pair, kind, target)
    if ok then request = result end
  end
  request = Resolver.sanitize_request(request)
  if request then
    request.kind = request.kind or kind
    pair.active_supply_request = request
  end
  return request
end

function Resolver.request_obsolete(pair, request)
  if not (pair and request) then return true end
  local fn = callable("tech_priests_abort_if_supply_request_obsolete")
  if fn then
    local ok, obsolete = pcall(fn, pair, request)
    if ok then return obsolete == true end
  end
  return false
end

function Resolver.classify(pair)
  local state = Resolver.ensure_pair_state(pair)
  if not state then return nil end
  Resolver.sanitize_pair(pair)
  local phase, item, kind = Resolver.phase.no_request, nil, nil
  if pair.cram then
    phase = Resolver.phase.station_cram; item = pair.cram.item_name or pair.cram.item; kind = "supply"
  elseif pair.scavenge then
    phase = Resolver.phase.scavenge; item = pair.scavenge.item_name or pair.scavenge.item; kind = pair.scavenge.kind or "supply"
  elseif pair.inventory_scan then
    phase = Resolver.phase.inventory_scan; item = pair.inventory_scan.item_name or (pair.inventory_scan.request and pair.inventory_scan.request.item_name); kind = pair.inventory_scan.kind or (pair.inventory_scan.request and pair.inventory_scan.request.kind) or "supply"
  elseif pair.logistic_requested_item then
    phase = Resolver.phase.logistics_request; item = pair.logistic_requested_item; kind = pair.active_supply_request and pair.active_supply_request.kind or "supply"
  elseif pair.emergency_craft then
    phase = Resolver.phase.emergency_craft; item = pair.emergency_craft.item_name or pair.emergency_craft.output_item or pair.emergency_craft.item; kind = "emergency"
  elseif pair.active_supply_request then
    phase = "request-pending"; item = pair.active_supply_request.item_name or (pair.active_supply_request.candidates and pair.active_supply_request.candidates[1] and pair.active_supply_request.candidates[1].name); kind = pair.active_supply_request.kind
  end
  state.last_phase = phase
  state.last_item = item
  state.last_kind = kind
  state.last_classify_tick = now()
  return phase, item, kind
end

function Resolver.clear_interruptible(pair, reason)
  if not pair then return end
  local ok = false
  ok = Resolver.legacy_call and select(1, Resolver.legacy_call("tech_priests_clear_interruptible_supply_work", pair)) or false
  if ok then
    local state = Resolver.ensure_pair_state(pair)
    if state then state.last_clear_reason = reason or "resolver-clear" end
    return
  end
  pair.inventory_scan = nil
  pair.scavenge = nil
  pair.cram = nil
  pair.logistic_requested_item = nil
  pair.logistic_requested_count = nil
  local state = Resolver.ensure_pair_state(pair)
  if state then state.last_clear_reason = reason or "resolver-clear-fallback" end
end

function Resolver.service_existing(pair)
  if not valid_pair(pair) then return false, "invalid-pair" end
  Resolver.sanitize_pair(pair)
  if pair.cram then local ok, handled = Resolver.legacy_call("handle_priest_cram_task", pair); if ok and handled then return true, Resolver.phase.station_cram end end
  if pair.scavenge then local ok, handled = Resolver.legacy_call("handle_priest_scavenge_task", pair); if ok and handled then return true, Resolver.phase.scavenge end end
  if pair.inventory_scan then local ok, handled = Resolver.legacy_call("handle_logistic_inventory_scan", pair); if ok and handled then return true, Resolver.phase.inventory_scan end end
  if pair.logistic_requested_item then local ok, handled = Resolver.legacy_call("handle_logistic_inventory_scan", pair); if ok and handled then return true, Resolver.phase.logistics_request end end
  if pair.emergency_craft then local ok, handled = safe_call("handle_emergency_desperation_craft", pair); if ok and handled then return true, Resolver.phase.emergency_craft end end
  return false, "no-active-supply-state"
end

function Resolver.try_station_already_supplied(pair, request)
  local fn = callable("tech_priests_station_inventory_has_requested_supply_0173")
  if not fn then return false end
  local ok, supplied = pcall(fn, pair, request)
  if ok and supplied then
    pair.last_supply_resolver_already_supplied_0319 = supplied
    local clear = callable("tech_priests_clear_supply_search_because_station_was_supplied_0173")
    if clear then pcall(clear, pair, supplied) end
    return true, supplied
  end
  return false
end

function Resolver.start_ground_or_inventory_scavenge(pair, request)
  local find = callable("find_scavenge_source_for_request")
  if find then
    local ok, source = pcall(find, pair, request)
    if ok and source then
      pair.active_supply_request = request
      pair.inventory_scan = nil
      pair.scavenge = source
      pair.target = source.source
      pair.mode = "scavenging-supplies"
      local handled_ok, handled = safe_call("handle_priest_scavenge_task", pair)
      if handled_ok and handled then return true, Resolver.phase.scavenge end
      return true, "scavenge-started"
    end
  end
  local scan = callable("start_logistic_scavenge_inventory_scan")
  if scan then local ok, started = pcall(scan, pair, request); if ok and started then return true, Resolver.phase.inventory_scan end end
  return false
end

function Resolver.start_logistics(pair, request)
  local fn = callable("issue_station_logistic_request")
  if not fn then return false end
  local ok, started = pcall(fn, pair, request)
  if ok and started then return true, Resolver.phase.logistics_request end
  return false
end

function Resolver.start_emergency(pair, request)
  if not (pair and request) then return false end
  local allowed = callable("tech_priests_pair_allows_emergency_desperation")
  if allowed then local ok, result = pcall(allowed, pair); if ok and result == false then return false end end
  local fn = callable("start_emergency_desperation_craft")
  if not fn then return false end
  local ok, started = pcall(fn, pair, request)
  if ok and started then return true, Resolver.phase.emergency_craft end
  return false
end

function Resolver.start_cram(pair, request)
  local fn = callable("maybe_start_cram_mode")
  if not fn then return false end
  local ok, started = pcall(fn, pair, request)
  if ok and started then return true, Resolver.phase.station_cram end
  return false
end

function Resolver.start_acquisition(pair, kind, target)
  if not valid_pair(pair) then return false, "invalid-pair" end
  Resolver.sanitize_pair(pair)
  local request = Resolver.build_request(pair, kind, target)
  if not request then return false, "no-request" end
  if Resolver.request_obsolete(pair, request) then return false, "obsolete-request" end
  local already = Resolver.try_station_already_supplied(pair, request)
  if already then return true, "already-supplied" end
  if request.kind == "cram" or request.kind == "trash" then local ok, phase = Resolver.start_cram(pair, request); if ok then return true, phase end end
  local ok, phase = Resolver.start_ground_or_inventory_scavenge(pair, request); if ok then return true, phase end
  ok, phase = Resolver.start_logistics(pair, request); if ok then return true, phase end
  ok, phase = Resolver.start_emergency(pair, request); if ok then return true, phase end
  return false, "no-acquisition-path"
end

function Resolver.try_supply(pair, kind, target)
  if not valid_pair(pair) then return false, "invalid-pair" end
  local state = Resolver.ensure_pair_state(pair)
  Resolver.classify(pair)
  local handled, phase = Resolver.service_existing(pair)
  if handled then
    if state then state.last_claim = phase; state.last_claim_tick = now() end
    return true, phase
  end
  if not Resolver.is_enabled() then
    if state then state.last_claim = "observe-only"; state.last_claim_tick = now() end
    return false, "observe-only"
  end
  local started, start_phase = Resolver.start_acquisition(pair, kind, target)
  if state then state.last_claim = start_phase; state.last_claim_tick = now() end
  return started, start_phase
end

function Resolver.command_status(player)
  local root = Resolver.ensure_root()
  local msg = "[Tech Priests 0.1.321] supply-resolver=" .. (root.enabled and "enabled" or "observe-only") .. " dry_run=" .. tostring(root.dry_run)
  if player and player.valid and player.print then player.print(msg) elseif game and game.print then game.print(msg) end
end

function Resolver.command_inspect(player)
  if not (player and player.valid) then return end
  local pair = nil
  local selected = player.selected
  local selected_pair = callable("selected_pair_for_player")
  if selected_pair then local ok, result = pcall(selected_pair, player); if ok then pair = result end end
  if not pair and selected and storage and storage.tech_priests then
    if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then pair = storage.tech_priests.pairs_by_station[selected.unit_number] end
    if (not pair) and storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then pair = storage.tech_priests.pairs_by_priest[selected.unit_number] end
  end
  if not pair then player.print("[Tech Priests 0.1.321] select a Cogitator Station or Tech-Priest."); return end
  local phase, item, kind = Resolver.classify(pair)
  player.print("[Tech Priests 0.1.321] pair=" .. tostring(pair_unit(pair)) .. " phase=" .. tostring(phase) .. " kind=" .. tostring(kind or "nil") .. " item=" .. tostring(item or "nil") .. " mode=" .. tostring(pair.mode or "nil"))
end

function Resolver.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function()
    commands.add_command("tp-supply-0321", "Tech Priests: inspect or enable the 0.1.321 unified supply resolver. Usage: /tp-supply-0321 status|enable|disable|inspect", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      local parameter = tostring(event and event.parameter or "status")
      if parameter == "enable" then Resolver.set_enabled(true); Resolver.command_status(player)
      elseif parameter == "disable" then Resolver.set_enabled(false); Resolver.command_status(player)
      elseif parameter == "inspect" then Resolver.command_inspect(player)
      else Resolver.command_status(player) end
    end)
  end)
end

return Resolver
