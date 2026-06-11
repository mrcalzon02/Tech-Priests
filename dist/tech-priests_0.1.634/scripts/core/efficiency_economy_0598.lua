-- Tech Priests 0.1.598: cooperative parallelization standards/economy shim.
-- This is not true multithreading. Factorio runtime Lua is deterministic and
-- single-threaded. The practical equivalent is cooperative parallelization:
-- spread non-critical service routes across ticks and categories so hundreds of
-- priests do not wake every background helper at once.

local M = { version = "0.1.598", storage_key = "efficiency_economy_0598" }

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if not r then
    r = { version = M.version, enabled = true, stats = {}, buckets = {}, last_report_tick = 0 }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  r.stats = r.stats or {}
  r.buckets = r.buckets or {}
  if r.enabled == nil then r.enabled = true end
  return r
end

local function inc(key, n)
  local r = root()
  r.stats[key] = (r.stats[key] or 0) + (n or 1)
end

local function pair_count()
  local tp = storage and storage.tech_priests
  local map = tp and tp.pairs_by_station
  if type(map) ~= "table" then return 0 end
  local n = 0
  for _, pair in pairs(map) do
    if pair and ((pair.station and pair.station.valid) or (pair.priest and pair.priest.valid)) then
      n = n + 1
      if n > 500 then break end
    end
  end
  return n
end

local critical_categories = {
  lifecycle = true,
  dispatcher = true,
  combat = true,
  movement = true,
  recovery = true,
  safety = true,
  acquisition = true,
  crafting = true,
  construction = true,
  repair = true,
  consecration = true,
  inventory = true,
  authority = true,
}

local background_categories = {
  diagnostics = true,
  visual = true,
  visuals = true,
  gui = true,
  audio = true,
  chatter = true,
  conversation = true,
  scheduler = true,
  doctrine = true,
  background = true,
}

local function stable_hash(text)
  text = tostring(text or "")
  local h = 0
  for i = 1, #text do
    h = (h * 33 + string.byte(text, i)) % 9973
  end
  return h
end

local function window_for_load(n)
  if n <= 0 then return 1 end
  if n < 10 then return 2 end
  if n < 40 then return 4 end
  if n < 100 then return 6 end
  if n < 250 then return 10 end
  return 15
end

function M.route_budget(entry, event, cadence)
  local r = root()
  if not r.enabled then return true end
  if type(entry) ~= "table" then return true end
  local category = tostring(entry.category or "")
  if critical_categories[category] then return true end
  if not background_categories[category] then return true end

  local count = pair_count()
  if count <= 0 then
    -- Dormant gate should already catch the fully idle case, but keep this
    -- secondary defense cheap and explicit for old raw handlers.
    inc("skipped_no_pairs")
    return false
  end

  local window = window_for_load(count)
  if window <= 1 then return true end
  local tick = (event and event.tick) or (game and game.tick) or 0
  local owner = tostring(entry.owner or "legacy")
  local phase = stable_hash(owner .. ":" .. category .. ":" .. tostring(cadence or "")) % window
  if (tick % window) ~= phase then
    inc("deferred_" .. category)
    return false
  end
  inc("allowed_" .. category)
  return true
end

function M.install()
  root()
  _G.tech_priests_route_budget_0598 = function(entry, event, cadence)
    return M.route_budget(entry, event, cadence)
  end
  if commands and commands.add_command then
    pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0598") end end)
    commands.add_command("tp-efficiency-economy-0598", "Report/toggle Tech Priests cooperative parallelization route economy. Params: on/off/status", function(cmd)
      local r = root()
      local p = cmd and cmd.parameter or ""
      if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false end
      local player = cmd and cmd.player_index and game and game.get_player(cmd.player_index) or nil
      local lines = {
        "[tp-efficiency-economy-0598] enabled=" .. tostring(r.enabled) .. " pairs=" .. tostring(pair_count()),
      }
      local stats = r.stats or {}
      local keys = {}
      for k in pairs(stats) do keys[#keys+1] = k end
      table.sort(keys)
      for i = 1, math.min(#keys, 20) do
        lines[#lines+1] = "  " .. keys[i] .. "=" .. tostring(stats[keys[i]])
      end
      local msg = table.concat(lines, "\n")
      if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
    end)
  end
end

return M
