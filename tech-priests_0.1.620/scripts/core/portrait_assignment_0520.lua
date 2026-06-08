-- scripts/core/portrait_assignment_0520.lua
-- Tech Priests 0.1.520
-- Persistent Cogitator/Tech-Priest portrait assignment for the Work State identity box.
-- This is a UI identity pass only: it does not create orders, move priests, or alter behavior.

local M = {}
M.version = "0.1.560"

M.pools = {
  junior = {
    key = "alternative-human-augmented-c",
    label = "Alternative Augmented Sheet C",
    prefix = "tech-priests-portrait-cell-alternative-human-augmented-c",
    count = 315,
  },
  intermediate = {
    key = "augmented-a",
    label = "Augmented Tech-Priest Sheet A",
    prefix = "tech-priests-portrait-cell-augmented-a",
    count = 64,
  },
  senior = {
    key = "augmented-a",
    label = "Augmented Tech-Priest Sheet A",
    prefix = "tech-priests-portrait-cell-augmented-a",
    count = 64,
  },
  planetary_magos = {
    key = "planetary-magos-a",
    label = "Planetary Magos Sheet A",
    prefix = "tech-priests-portrait-cell-planetary-magos-a",
    count = 63, -- 0.1.560 trimmed sheet is 9x7; old bottom row is no longer valid.
  },
}

local function valid(e) return e and e.valid end
local function safe(v) return tostring(v == nil and "nil" or v) end
local function now() return game and game.tick or 0 end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end

local function root()
  if not storage then return nil end
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests.portrait_assignment_0520
  if not r then
    r = { version = M.version, by_station = {}, stats = { assigned = 0, reused = 0, rerolled = 0 } }
    storage.tech_priests.portrait_assignment_0520 = r
  end
  r.version = M.version
  r.by_station = r.by_station or {}
  r.stats = r.stats or { assigned = 0, reused = 0, rerolled = 0 }
  return r
end

local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end

local function priest_unit(pair)
  return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil
end

local function station_rank(pair)
  if not pair then return 1 end
  if tonumber(pair.rank) then return tonumber(pair.rank) end
  if tonumber(pair.station_rank) then return tonumber(pair.station_rank) end
  local name = valid(pair.station) and tostring(pair.station.name or "") or ""
  if name:find("planetary%-magos", 1, false) or name:find("void", 1, false) then return 4 end
  if name:find("senior", 1, false) then return 3 end
  if name:find("intermediate", 1, false) then return 2 end
  return 1
end

local function rank_key(pair)
  local rank = station_rank(pair)
  if rank >= 4 then return "planetary_magos" end
  if rank >= 3 then return "senior" end
  if rank >= 2 then return "intermediate" end
  return "junior"
end

local function hash_text(text)
  text = tostring(text or "")
  local n = 0
  for i = 1, #text do
    n = (n * 33 + string.byte(text, i)) % 2147483647
  end
  return n
end

local function sprite_name(pool, index)
  return tostring(pool.prefix) .. string.format("-%03d", tonumber(index) or 1)
end

local function portrait_id(pool, index)
  return tostring(pool.key) .. ":" .. string.format("%03d", tonumber(index) or 1)
end

local function sync_pair(pair, rec)
  if not (pair and rec) then return rec end
  pair.portrait_id_0520 = rec.portrait_id
  pair.portrait_sprite_0520 = rec.sprite
  pair.portrait_sheet_0520 = rec.sheet
  pair.portrait_cell_0520 = rec.index
  pair.portrait_rank_key_0520 = rec.rank_key
  return rec
end

function M.assign_pair_portrait(pair, opts)
  opts = opts or {}
  local r = root()
  local su = station_unit(pair)
  if not (r and su) then return nil end
  local key = tostring(su)
  local rk = rank_key(pair)
  local pool = M.pools[rk] or M.pools.junior
  local existing = r.by_station[key]
  if existing and existing.sprite and existing.pool_key == pool.key and not opts.reroll then
    r.stats.reused = (r.stats.reused or 0) + 1
    return sync_pair(pair, existing)
  end

  local salt = tostring(su) .. ":" .. tostring(priest_unit(pair) or "?") .. ":" .. tostring(rk) .. ":" .. tostring(valid(pair and pair.station) and pair.station.name or "station")
  if opts.reroll then salt = salt .. ":reroll:" .. tostring(now()) .. ":" .. tostring(r.stats.rerolled or 0) end
  local index = (hash_text(salt) % pool.count) + 1
  local rec = {
    version = M.version,
    station_unit = su,
    priest_unit = priest_unit(pair),
    rank = station_rank(pair),
    rank_key = rk,
    sheet = pool.key,
    sheet_label = pool.label,
    pool_key = pool.key,
    index = index,
    portrait_id = portrait_id(pool, index),
    sprite = sprite_name(pool, index),
    created_tick = now(),
    source = opts.reroll and "manual-reroll-0520" or "deterministic-assignment-0520",
  }
  r.by_station[key] = rec
  r.stats.assigned = (r.stats.assigned or 0) + 1
  if opts.reroll then r.stats.rerolled = (r.stats.rerolled or 0) + 1 end
  return sync_pair(pair, rec)
end

function M.ensure_pair_portrait(pair)
  return M.assign_pair_portrait(pair, nil)
end

function M.portrait_for_pair(pair)
  return M.ensure_pair_portrait(pair)
end

local function selected_pair(player)
  if not (player and player.valid) then return nil end
  local selected = player.selected
  if selected and selected.valid and _G.find_pair_for_entity then
    local ok, pair = pcall(_G.find_pair_for_entity, selected)
    if ok and pair then return pair end
  end
  for _, pair in pairs(pair_map()) do
    if pair and (pair.station == selected or pair.priest == selected) then return pair end
  end
  return nil
end

local function line_for(pair)
  local rec = M.ensure_pair_portrait(pair)
  if not rec then return "portrait0520 station=nil no assignment" end
  return "portrait0520 station=" .. safe(station_unit(pair)) .. " priest=" .. safe(priest_unit(pair)) .. " rank=" .. safe(rec.rank_key) .. " id=" .. safe(rec.portrait_id) .. " sprite=" .. safe(rec.sprite)
end

function M.describe_pair(pair)
  return line_for(pair)
end

function M.ensure_all()
  local n = 0
  for _, pair in pairs(pair_map()) do
    if pair and valid(pair.station) then
      M.ensure_pair_portrait(pair)
      n = n + 1
    end
  end
  return n
end

function M.patch_create_pair()
  if rawget(_G, "TECH_PRIESTS_0520_PRE_CREATE_PAIR") or type(_G.create_pair) ~= "function" then return false end
  local prev = _G.create_pair
  _G.TECH_PRIESTS_0520_PRE_CREATE_PAIR = prev
  _G.create_pair = function(station, ...)
    local result = prev(station, ...)
    local pair = nil
    if station and station.valid and storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
      pair = storage.tech_priests.pairs_by_station[station.unit_number] or storage.tech_priests.pairs_by_station[tostring(station.unit_number)]
    end
    if pair then pcall(M.ensure_pair_portrait, pair) end
    return result
  end
  return true
end

function M.patch_pair_dump()
  local diag = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.portrait_assignment_0520_wrapped then return false end
  local prev = diag.pair_dump_lines
  diag.portrait_assignment_0520_wrapped = true
  diag.pair_dump_lines = function(...)
    local lines = prev(...)
    lines[#lines + 1] = "PAIR-DUMP-0468 PORTRAIT-ASSIGNMENT-0520 BEGIN"
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 portrait0520 assigned=" .. safe(r and r.stats and r.stats.assigned or 0) .. " reused=" .. safe(r and r.stats and r.stats.reused or 0) .. " rerolled=" .. safe(r and r.stats and r.stats.rerolled or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then lines[#lines + 1] = "PAIR-DUMP-0468 " .. line_for(pair) end
    end
    lines[#lines + 1] = "PAIR-DUMP-0468 PORTRAIT-ASSIGNMENT-0520 END"
    return lines
  end
  return true
end

local function print_lines(player, lines)
  if player and player.valid then for _, l in ipairs(lines) do player.print(l) end else for _, l in ipairs(lines) do log(l) end end
end

function M.install_commands()
  if not commands then return end
  pcall(function() commands.remove_command("tp-portrait-assignment-0520") end)
  commands.add_command("tp-portrait-assignment-0520", "Tech Priests 0.1.520: inspect or reroll persistent portrait assignment.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = tostring(event and event.parameter or "")
    local lines = { "PORTRAIT ASSIGNMENT 0520" }
    if param == "all" then
      M.ensure_all()
      for _, pair in pairs(pair_map()) do if pair and valid(pair.station) then lines[#lines + 1] = line_for(pair) end end
    elseif param == "reroll" then
      local pair = selected_pair(player)
      if pair then
        M.assign_pair_portrait(pair, { reroll = true })
        lines[#lines + 1] = line_for(pair)
      else
        lines[#lines + 1] = "Select a Cogitator Station or Tech-Priest before rerolling."
      end
    else
      local pair = selected_pair(player)
      if pair then lines[#lines + 1] = line_for(pair) else lines[#lines + 1] = "Use 'all' to assign/report every station, or select a pair and use 'reroll'." end
    end
    print_lines(player, lines)
  end)
end

function M.install()
  _G.TECH_PRIESTS_PORTRAIT_ASSIGNMENT_0520 = M
  _G.tech_priests_portrait_assignment_0520 = M
  root()
  pcall(M.ensure_all)
  M.patch_create_pair()
  M.patch_pair_dump()
  M.install_commands()
  if log then log("[Tech-Priests 0.1.520] persistent portrait assignment installed; portrait cells now bind to Cogitator identity plaques") end
  return true
end

return M
