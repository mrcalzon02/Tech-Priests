-- scripts/core/emergency_cascade.lua
-- Tech Priests 0.1.326 emergency-mode cascade doctrine.
--
-- When a senior-or-better station enters emergency mode, nearby lower-rank
-- subordinate stations should also enter emergency mode and receive immediate
-- acquisition pressure instead of politely waiting around the blasted rock garden.

local Cascade = {}

Cascade.version = "0.1.617"
Cascade.storage_key = "emergency_cascade_0326"
Cascade.radius_multiplier = 3
Cascade.max_radius = 96
Cascade.bootstrap_items = { "iron-ore", "coal", "stone", "wood" }

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Cascade.storage_key] = storage.tech_priests[Cascade.storage_key] or { version = Cascade.version, stats = {} }
  local root = storage.tech_priests[Cascade.storage_key]
  root.version = Cascade.version
  root.stats = root.stats or {}
  return root
end

local function valid_pair(pair) return pair and pair.station and pair.station.valid end
local function station_unit(pair) return pair and (pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number)) or nil end

local function rank(pair)
  if _G.tech_priests_get_pair_tier_rank then local ok, r = pcall(_G.tech_priests_get_pair_tier_rank, pair); if ok and tonumber(r) then return tonumber(r) end end
  local name = pair and pair.station and pair.station.valid and pair.station.name or tostring(pair and pair.tier or "")
  if name:find("void", 1, true) then return 5 end
  if name:find("planetary", 1, true) or name:find("magos", 1, true) then return 4 end
  if name:find("senior", 1, true) then return 3 end
  if name:find("intermediate", 1, true) then return 2 end
  return 1
end

local function distance_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or a[1] or 0) - (b.x or b[1] or 0)
  local dy = (a.y or a[2] or 0) - (b.y or b[2] or 0)
  return dx * dx + dy * dy
end

local function radius_for(pair)
  if valid_pair(pair) and _G.get_station_operating_radius then local ok, r = pcall(_G.get_station_operating_radius, pair.station); if ok and tonumber(r) then return math.min(Cascade.max_radius, math.max(24, tonumber(r) * Cascade.radius_multiplier)) end end
  return 72
end

local function pairs_table()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

function Cascade.find_subordinates(leader)
  local out = {}
  if not valid_pair(leader) then return out end
  local leader_rank = rank(leader)
  if leader_rank < 3 then return out end

  -- 0.1.617: emergency cascade is a consumer of the command hierarchy, not
  -- a competing subordinate-discovery authority. Prefer the distributed direct
  -- subordinate slate so one senior does not emergency-claim every nearby lower
  -- rank unit that should belong to another eligible superior.
  local h = rawget(_G, "tech_priests_0480_direct_subordinates")
  if type(h) == "function" then
    local ok, direct = pcall(h, leader)
    if ok and type(direct) == "table" and #direct > 0 then
      for _, pair in ipairs(direct) do
        if valid_pair(pair) and rank(pair) < leader_rank then out[#out + 1] = pair end
      end
      table.sort(out, function(a, b) return rank(a) > rank(b) end)
      return out
    end
  end

  local r = radius_for(leader)
  local r2 = r * r
  for unit, pair in pairs(pairs_table()) do
    if unit ~= station_unit(leader) and valid_pair(pair) and pair.station.force == leader.station.force and pair.station.surface == leader.station.surface then
      if rank(pair) < leader_rank and distance_sq(pair.station.position, leader.station.position) <= r2 then
        out[#out + 1] = pair
      end
    end
  end
  table.sort(out, function(a, b) return rank(a) > rank(b) end)
  return out
end

local function show(pair, text)
  if _G.tech_priests_draw_emergency_operation_status_0184 then pcall(_G.tech_priests_draw_emergency_operation_status_0184, pair, text) end
end

local function issue_acquisition(pair)
  if not valid_pair(pair) then return end
  local op = _G.tech_priests_get_emergency_operation_0184 and _G.tech_priests_get_emergency_operation_0184(pair) or pair.independent_emergency_operation_0184 or {}
  pair.emergency_cascade_0326 = { tick = game and game.tick or 0, order = "bootstrap-acquisition" }
  for _, item in ipairs(Cascade.bootstrap_items) do
    if _G.tech_priests_emergency_operation_acquire_item_0185 then
      local ok, result = pcall(_G.tech_priests_emergency_operation_acquire_item_0185, pair, item, op or {}, 1, 0)
      if ok and result then show(pair, "[item=" .. item .. "] cascade acquisition order accepted"); return true end
    end
  end
  show(pair, "[virtual-signal=signal-alert] emergency cascade active; awaiting source doctrine")
  return false
end

function Cascade.cascade_from(leader, reason)
  if not valid_pair(leader) then return 0 end
  local root = ensure_root()
  local list = Cascade.find_subordinates(leader)
  local count = 0
  for _, child in ipairs(list) do
    if _G.TECH_PRIESTS_0326_PRE_SET_EMERGENCY_OPERATION then
      pcall(_G.TECH_PRIESTS_0326_PRE_SET_EMERGENCY_OPERATION, child, true, "cascade-from-" .. tostring(station_unit(leader)) .. ":" .. tostring(reason or "emergency"))
    end
    issue_acquisition(child)
    count = count + 1
  end
  root.stats.cascades = (root.stats.cascades or 0) + 1
  root.stats.children_activated = (root.stats.children_activated or 0) + count
  show(leader, "[virtual-signal=signal-alert] emergency cascade propagated to " .. tostring(count) .. " subordinate stations")
  return count
end

function Cascade.wrap_setter()
  local prev = rawget(_G, "tech_priests_set_emergency_operation_0184")
  if type(prev) ~= "function" or rawget(_G, "TECH_PRIESTS_0326_PRE_SET_EMERGENCY_OPERATION") then return end
  _G.TECH_PRIESTS_0326_PRE_SET_EMERGENCY_OPERATION = prev
  _G.tech_priests_set_emergency_operation_0184 = function(pair, enabled, reason)
    local result = _G.TECH_PRIESTS_0326_PRE_SET_EMERGENCY_OPERATION(pair, enabled, reason)
    if enabled and not Cascade._in_cascade and valid_pair(pair) and rank(pair) >= 3 then
      Cascade._in_cascade = true
      pcall(Cascade.cascade_from, pair, reason or "setter")
      Cascade._in_cascade = false
    end
    return result
  end
end

function Cascade.install()
  ensure_root()
  Cascade.wrap_setter()
  if commands and commands.add_command then
    pcall(function()
      commands.add_command("tp-emergency-cascade-0326", "Tech Priests: inspect or force selected senior emergency cascade. Usage: /tp-emergency-cascade-0326 status|force", function(event)
        local player = event and event.player_index and game.get_player(event.player_index) or nil
        local param = tostring(event and event.parameter or "status")
        local root = ensure_root()
        local pair = nil
        if player and _G.selected_pair_for_player then local ok, found = pcall(_G.selected_pair_for_player, player); if ok then pair = found end end
        if player and player.valid then
          if param == "force" and pair then Cascade.cascade_from(pair, "manual-command") end
          player.print("[Tech Priests 0.1.326] emergency cascade stats: cascades=" .. tostring(root.stats.cascades or 0) .. " children=" .. tostring(root.stats.children_activated or 0) .. " selected=" .. tostring(pair and station_unit(pair) or "none") .. " rank=" .. tostring(pair and rank(pair) or "n/a"))
        end
      end)
    end)
  end
  if log then log("[Tech-Priests 0.1.326] emergency cascade doctrine installed") end
  return true
end

return Cascade
