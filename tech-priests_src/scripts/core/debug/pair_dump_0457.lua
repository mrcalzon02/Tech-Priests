-- Tech Priests 0.1.457 - Pair dump + debug command executive smoke test.
-- Purpose:
--   The development plan referenced /tp-pair-dump, but the command did not yet
--   exist in the shipped runtime. This module installs the missing command and
--   a small command-executive health probe early enough to verify future debug
--   command registration failures without relying on the larger GUI stack.

local M = {}
M.version = "0.1.463"
M.installed = false
M.commands = {
  ["tp-pair-dump"] = true,
  ["tp-debug-commands-0457"] = true,
}

local function valid(e)
  return e and e.valid
end

local function safe(v)
  if v == nil then return "nil" end
  local ok, out = pcall(function() return tostring(v) end)
  if ok then return out end
  return "?"
end

local function pos_text(entity)
  if not valid(entity) then return "nil" end
  local p = entity.position
  if not p then return "nil" end
  return string.format("%.2f, %.2f", tonumber(p.x) or 0, tonumber(p.y) or 0)
end

local function surface_name(entity)
  if not valid(entity) then return "nil" end
  return entity.surface and entity.surface.name or "nil"
end

local function entity_label(entity)
  if not valid(entity) then return "invalid" end
  return safe(entity.name) .. "#" .. safe(entity.unit_number) .. " @ " .. pos_text(entity) .. " surface=" .. surface_name(entity)
end

local function player_from_event(event)
  if not (event and event.player_index and game and game.players) then return nil end
  return game.players[event.player_index]
end

local function print_line(player, line)
  if player and player.valid then player.print(line) elseif game and game.print then game.print(line) end
end

local function safe_write_file_0462(filename, data, append, for_player)
  if helpers then
    local ok_get, writer = pcall(function() return helpers.write_file end)
    if ok_get and writer then
      local ok_write = pcall(function() writer(filename, data, append or false, for_player) end)
      if ok_write then return true end
    end
  end
  if game then
    local ok_get, writer = pcall(function() return game.write_file end)
    if ok_get and writer then
      local ok_write = pcall(function() writer(filename, data, append or false, for_player) end)
      if ok_write then return true end
    end
  end
  return false
end

local function safe_valid(obj)
  if obj == nil then return false end
  local ok, v = pcall(function() return obj.valid end)
  return ok and v == true
end

local function safe_name(obj)
  if obj == nil then return nil end
  local ok, n = pcall(function() return obj.name end)
  if ok then return n end
  return nil
end

local function safe_tags(obj)
  if obj == nil then return nil end
  local ok, tags = pcall(function() return obj.tags end)
  if ok then return tags end
  return nil
end

local function safe_prop(obj, prop)
  if obj == nil or prop == nil then return nil end
  local ok, value = pcall(function() return obj[prop] end)
  if ok then return value end
  return nil
end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  return storage.tech_priests
end

local function pair_maps()
  local root = ensure_root()
  root.pairs_by_station = root.pairs_by_station or {}
  root.pairs_by_priest = root.pairs_by_priest or {}
  root.station_by_priest = root.station_by_priest or {}
  return root.pairs_by_station, root.pairs_by_priest, root.station_by_priest
end

local function find_pair_for_entity(entity)
  if not valid(entity) then return nil, "no-valid-selection" end
  local pairs_by_station, pairs_by_priest, station_by_priest = pair_maps()
  local unit = entity.unit_number
  if unit then
    if pairs_by_station[unit] then return pairs_by_station[unit], "pairs_by_station" end
    if pairs_by_priest[unit] then return pairs_by_priest[unit], "pairs_by_priest" end
    local station_unit = station_by_priest[unit]
    if station_unit and pairs_by_station[station_unit] then return pairs_by_station[station_unit], "station_by_priest" end
  end
  for _, pair in pairs(pairs_by_station) do
    if pair then
      if valid(pair.station) and pair.station == entity then return pair, "scan-station-entity" end
      if valid(pair.priest) and pair.priest == entity then return pair, "scan-priest-entity" end
      if unit and pair.station_unit == unit then return pair, "scan-station-unit" end
      if unit and pair.priest_unit == unit then return pair, "scan-priest-unit" end
    end
  end
  return nil, "not-found"
end

local function find_pair_for_station_unit(station_unit)
  if station_unit == nil then return nil, "no-station-unit" end
  local pairs_by_station = pair_maps()
  local key_num = tonumber(station_unit)
  if key_num and pairs_by_station[key_num] then return pairs_by_station[key_num], "station-unit-number" end
  local key_str = tostring(station_unit)
  if pairs_by_station[key_str] then return pairs_by_station[key_str], "station-unit-string" end
  for _, pair in pairs(pairs_by_station or {}) do
    if pair and tostring(pair.station_unit or (valid(pair.station) and pair.station.unit_number) or "") == key_str then
      return pair, "station-unit-scan"
    end
  end
  return nil, "station-unit-not-found"
end

local function pair_from_recent_opened_0461(player)
  if not (player and player.valid and storage and storage.tech_priests) then return nil, "no-recent-open-store" end
  local bucket = storage.tech_priests.last_opened_pair_by_player_0461
  local rec = bucket and bucket[tostring(player.index)] or nil
  if not rec then return nil, "no-recent-opened-pair" end
  local age = (game and game.tick or 0) - (tonumber(rec.tick) or 0)
  if age > (60 * 20) then return nil, "recent-opened-expired:" .. safe(age) end
  local pair, source = find_pair_for_station_unit(rec.station_unit)
  if pair then return pair, "recent-opened-0461:" .. tostring(source) .. ":" .. safe(rec.reason) end
  return nil, source or "recent-opened-pair-not-found"
end

local function pair_from_object_tags_0461(obj, prefix)
  local tags = safe_tags(obj) or {}
  if tags.station_unit then
    local pair, tag_source = find_pair_for_station_unit(tags.station_unit)
    if pair then return pair, tostring(prefix or "tags") .. ":" .. tostring(tag_source) end
  end
  return nil, tostring(prefix or "tags") .. "-no-station-unit"
end

local function pair_from_opened_owner_0461(opened)
  local owner_props = {
    "entity_owner", "owner", "parent", "associated_entity", "inventory_owner",
    "equipment_owner", "entity", "target", "source", "player"
  }
  for _, prop in ipairs(owner_props) do
    local owner = safe_prop(opened, prop)
    if owner ~= nil and owner ~= opened then
      if safe_valid(owner) then
        local pair, source = find_pair_for_entity(owner)
        if pair then return pair, "opened-owner-" .. prop .. ":" .. tostring(source) end
      end
      local tag_pair, tag_source = pair_from_object_tags_0461(owner, "opened-owner-" .. prop .. "-tags")
      if tag_pair then return tag_pair, tag_source end
    end
  end
  return nil, "opened-owner-not-found"
end

local function pair_from_workstate_frame(player)
  if not (player and player.valid and player.gui and player.gui.screen) then return nil, "no-player-screen" end
  local ok, frame = pcall(function() return player.gui.screen["tech_priests_station_workstate_0358"] end)
  if not (ok and frame and frame.valid) then return nil, "no-workstate-frame" end
  local tags = safe_tags(frame) or {}
  local station_unit = tags.station_unit
  if not station_unit then return nil, "workstate-frame-no-station-unit" end
  local pair, source = find_pair_for_station_unit(station_unit)
  if pair then return pair, "workstate-frame:" .. tostring(source) end
  return nil, source or "workstate-frame-pair-not-found"
end

local function pair_from_opened(player)
  if not (player and player.valid) then return nil, "no-player" end
  local ok, opened = pcall(function() return player.opened end)
  if not (ok and opened ~= nil) then return nil, "no-opened-object" end
  if safe_valid(opened) then
    local pair, source = find_pair_for_entity(opened)
    if pair then return pair, "opened-entity:" .. tostring(source) end
    local tag_pair, tag_source = pair_from_object_tags_0461(opened, "opened-tags")
    if tag_pair then return tag_pair, tag_source end
    local owner_pair, owner_source = pair_from_opened_owner_0461(opened)
    if owner_pair then return owner_pair, owner_source end
    return nil, "opened-valid-but-untracked:" .. tostring(safe_name(opened) or "?") .. "; " .. tostring(owner_source)
  end
  local tag_pair, tag_source = pair_from_object_tags_0461(opened, "opened-gui-tags")
  if tag_pair then return tag_pair, tag_source end
  local owner_pair, owner_source = pair_from_opened_owner_0461(opened)
  if owner_pair then return owner_pair, owner_source end
  return nil, "opened-object-not-valid-entity; " .. tostring(tag_source) .. "; " .. tostring(owner_source)
end

local function scalar(pair, key)
  if not pair then return "nil" end
  local value = pair[key]
  if value == nil then return "nil" end
  return safe(value)
end

local function movement_summary(pair)
  if not pair then return "nil" end
  local target = pair.movement_target or pair.move_target or pair.target_position or pair.destination
  local target_text = "nil"
  if type(target) == "table" then
    target_text = string.format("%.2f, %.2f", tonumber(target.x) or 0, tonumber(target.y) or 0)
  elseif target ~= nil then
    target_text = safe(target)
  end
  return "mode=" .. scalar(pair, "mode") ..
    " movement_mode=" .. scalar(pair, "movement_mode") ..
    " target=" .. target_text ..
    " moving=" .. scalar(pair, "moving") ..
    " locked_until=" .. scalar(pair, "movement_locked_until") ..
    " task_lock=" .. scalar(pair, "task_switch_locked_until")
end

local function task_summary(pair)
  if not pair then return "nil" end
  return "priority=" .. scalar(pair, "current_priority") ..
    " task=" .. scalar(pair, "current_task") ..
    " mode=" .. scalar(pair, "mode") ..
    " reason=" .. scalar(pair, "reason") ..
    " phase=" .. scalar(pair, "phase") ..
    " craft=" .. scalar(pair, "craft") ..
    " scavenge=" .. scalar(pair, "scavenge") ..
    " last_item=" .. scalar(pair, "last_item") ..
    " blocker=" .. scalar(pair, "blocker")
end

local function count_pairs()
  local pairs_by_station = pair_maps()
  local total, valid_station, valid_priest = 0, 0, 0
  for _, pair in pairs(pairs_by_station or {}) do
    total = total + 1
    if pair and valid(pair.station) then valid_station = valid_station + 1 end
    if pair and valid(pair.priest) then valid_priest = valid_priest + 1 end
  end
  return total, valid_station, valid_priest
end

local function describe_pair(pair, source)
  local lines = {}
  lines[#lines + 1] = "[tp-pair-dump] source=" .. safe(source) .. " tick=" .. safe(game and game.tick)
  if not pair then
    local total, valid_station, valid_priest = count_pairs()
    lines[#lines + 1] = "No selected/hovered/opened pair found. pair_count=" .. total .. " valid_stations=" .. valid_station .. " valid_priests=" .. valid_priest
    return lines
  end
  lines[#lines + 1] = "station=" .. entity_label(pair.station) .. " stored_unit=" .. safe(pair.station_unit)
  lines[#lines + 1] = "priest=" .. entity_label(pair.priest) .. " stored_unit=" .. safe(pair.priest_unit)
  lines[#lines + 1] = "rank=" .. scalar(pair, "rank") .. " tier=" .. scalar(pair, "tier") .. " station_rank=" .. scalar(pair, "station_rank")
  lines[#lines + 1] = "task: " .. task_summary(pair)
  lines[#lines + 1] = "movement: " .. movement_summary(pair)
  lines[#lines + 1] = "emergency=" .. scalar(pair, "emergency") .. " independent=" .. scalar(pair, "independent") .. " order_source=" .. scalar(pair, "last_order_source")
  if pair.task_governor_0445 then
    local g = pair.task_governor_0445
    lines[#lines + 1] = "governor0445: locked_until=" .. safe(g.locked_until) .. " pending=" .. safe(g.pending_mode) .. " reason=" .. safe(g.reason) .. " churn=" .. safe(g.churn_count)
  end
  if pair.last_movement_authority_0429 then
    local m = pair.last_movement_authority_0429
    lines[#lines + 1] = "movement-authority0429: tick=" .. safe(m.tick) .. " reason=" .. safe(m.reason) .. " target=" .. safe(m.target)
  end
  return lines
end

local function compact_pair_line(pair, index)
  if not pair then return "pair[" .. safe(index) .. "]=nil" end
  local station_valid = valid(pair.station)
  local priest_valid = valid(pair.priest)
  local station_unit = pair.station_unit or (station_valid and pair.station.unit_number) or "nil"
  local priest_unit = pair.priest_unit or (priest_valid and pair.priest.unit_number) or "nil"
  return "pair[" .. safe(index) .. "] station=" .. safe(station_valid and pair.station.name or "invalid") .. "#" .. safe(station_unit)
    .. " priest=" .. safe(priest_valid and pair.priest.name or "invalid") .. "#" .. safe(priest_unit)
    .. " tier=" .. scalar(pair, "tier")
    .. " rank=" .. scalar(pair, "rank")
    .. " mode=" .. scalar(pair, "mode")
    .. " task=" .. scalar(pair, "current_task")
    .. " movement_mode=" .. scalar(pair, "movement_mode")
end

local function append_all_pair_fallback(lines)
  local pairs_by_station = pair_maps()
  local rows = {}
  for key, pair in pairs(pairs_by_station or {}) do
    rows[#rows + 1] = { key = tostring(key), pair = pair }
  end
  table.sort(rows, function(a, b) return tostring(a.key) < tostring(b.key) end)
  lines[#lines + 1] = "[tp-pair-dump] all-pairs fallback rows=" .. safe(#rows)
  if #rows == 0 then return lines end
  for i, row in ipairs(rows) do
    lines[#lines + 1] = compact_pair_line(row.pair, row.key)
    if i >= 48 then
      lines[#lines + 1] = "[tp-pair-dump] all-pairs fallback truncated at 48 rows"
      break
    end
  end
  return lines
end

local function write_dump(player, pair, source)
  local lines = describe_pair(pair, source)
  if not pair then append_all_pair_fallback(lines) end
  local text = table.concat(lines, "\n") .. "\n"
  local ok = safe_write_file_0462("tech-priests-pair-dump-0457.txt", text, false)
  if ok then
    print_line(player, "[tp-pair-dump] wrote script-output/tech-priests-pair-dump-0457.txt")
  else
    print_line(player, "[tp-pair-dump] failed to write script-output/tech-priests-pair-dump-0457.txt; file writer unavailable")
  end
end

local function handle_pair_dump(event)
  local player = player_from_event(event)
  local param = tostring(event and event.parameter or "")
  local selected = player and player.valid and player.selected or nil
  local pair, source = find_pair_for_entity(selected)
  if not pair then
    local opened_pair, opened_source = pair_from_opened(player)
    if opened_pair then pair, source = opened_pair, opened_source else source = source .. "; " .. tostring(opened_source) end
  end
  if not pair then
    local frame_pair, frame_source = pair_from_workstate_frame(player)
    if frame_pair then pair, source = frame_pair, frame_source else source = source .. "; " .. tostring(frame_source) end
  end
  if not pair then
    local recent_pair, recent_source = pair_from_recent_opened_0461(player)
    if recent_pair then pair, source = recent_pair, recent_source else source = source .. "; " .. tostring(recent_source) end
  end
  if param == "write" then write_dump(player, pair, source); return end
  if param == "all" then
    local pairs_by_station = pair_maps()
    local n = 0
    for _, p in pairs(pairs_by_station) do
      n = n + 1
      for _, line in ipairs(describe_pair(p, "all")) do print_line(player, line) end
    end
    if n == 0 then print_line(player, "[tp-pair-dump] no pair records found.") end
    return
  end
  for _, line in ipairs(describe_pair(pair, source)) do print_line(player, line) end
end

local function handle_debug_commands(event)
  local player = player_from_event(event)
  local total, valid_station, valid_priest = count_pairs()
  print_line(player, "[tp-debug-commands-0457] command executive smoke test online.")
  print_line(player, "[tp-debug-commands-0457] installed aliases: /tp-pair-dump, /tp-debug-commands-0457")
  print_line(player, "[tp-debug-commands-0457] pair_count=" .. total .. " valid_stations=" .. valid_station .. " valid_priests=" .. valid_priest)
  if TechPriestsDebugCommandRegistry and TechPriestsDebugCommandRegistry.count then
    print_line(player, "[tp-debug-commands-0457] central registry recorded=" .. safe(TechPriestsDebugCommandRegistry.count()) .. " entries. Note: many legacy commands still register directly and will not appear there.")
  else
    print_line(player, "[tp-debug-commands-0457] central registry unavailable; direct command registration still reached this handler.")
  end
end

local function register_command(name, help, handler)
  if not (commands and commands.add_command) then return false, "commands-api-unavailable" end
  pcall(function() if commands.remove_command then commands.remove_command(name) end end)
  local ok, err = pcall(function()
    if TechPriestsDebugCommandRegistry and TechPriestsDebugCommandRegistry.add then
      TechPriestsDebugCommandRegistry.add(name, help, handler)
    else
      commands.add_command(name, help, handler)
    end
  end)
  if not ok then return false, err end
  return true
end

function M.install()
  if M.installed then return true end
  local ok1, err1 = register_command("tp-pair-dump", "Tech Priests 0.1.463: dump selected, hovered, opened, Work State-framed, or all-pairs fallback Cogitator Station/Tech-Priest pair state. Usage: /tp-pair-dump [all|write]", handle_pair_dump)
  local ok2, err2 = register_command("tp-debug-commands-0457", "Tech Priests 0.1.463: debug command executive smoke test.", handle_debug_commands)
  M.installed = ok1 and ok2
  _G.TECH_PRIESTS_PAIR_DUMP_0457 = M
  if log then
    log("[Tech-Priests 0.1.463] pair dump command install ok1=" .. safe(ok1) .. " err1=" .. safe(err1) .. " ok2=" .. safe(ok2) .. " err2=" .. safe(err2))
  end
  return M.installed
end

return M
