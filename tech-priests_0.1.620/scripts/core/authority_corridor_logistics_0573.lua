-- scripts/core/authority_corridor_logistics_0573.lua
-- Tech Priests 0.1.573 authority-corridor logistics/crafting scaffold.
--
-- This is not a task selector and not a movement controller.  It teaches the
-- existing inventory/crafting source resolvers the same doctrine as the planned
-- path corridor system: a subordinate may borrow a superior station's supply
-- authority only while carrying an active writ/order.  Idle local service still
-- uses the home station only.

local M = {}
M.version = "0.1.573"
M.storage_key = "authority_corridor_logistics_0573"
M.max_superior_depth = 5

local pre = {}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = { version = M.version, enabled = true, borrow_inputs = true, deposit_home_only = true, stats = {}, recent = {} }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.borrow_inputs == nil then r.borrow_inputs = true end
  if r.deposit_home_only == nil then r.deposit_home_only = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function remember(action, detail)
  local r=M.root()
  r.recent[#r.recent+1] = { tick=now(), action=tostring(action or "event"), detail=tostring(detail or "") }
  while #r.recent > 60 do table.remove(r.recent,1) end
end

local function hierarchy()
  local ok,H = pcall(require, "scripts.core.command_hierarchy_0480")
  if ok and type(H) == "table" then return H end
  return rawget(_G, "TECH_PRIESTS_COMMAND_HIERARCHY_0480")
end

local function rank(pair)
  local H = hierarchy()
  if H and H.rank then local ok,r=pcall(H.rank,pair); if ok and tonumber(r) then return tonumber(r) end end
  return 0
end

local function pair_by_station(unit)
  if not unit then return nil end
  local H = hierarchy()
  if H and H.pair_by_station_unit then local ok,p=pcall(H.pair_by_station_unit,unit); if ok and p then return p end end
  local map = storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
  return map[unit] or map[tostring(unit)]
end

local function superior(pair)
  local H = hierarchy()
  if H and H.superior then local ok,p=pcall(H.superior,pair); if ok and p then return p end end
  local h = pair and pair.command_hierarchy_0480
  return h and h.superior_unit and pair_by_station(h.superior_unit) or nil
end

local function current_order(pair)
  local q = pair and pair.order_queue_0469
  return q and q.current or pair and pair.active_order_0469 or nil
end

local function order_kind(order)
  return lower(order and (order.kind or order.type or order.reason or order.source))
end

local function order_is_work_writ(pair, order)
  if not (valid_pair(pair) and order and order.status ~= "complete" and order.status ~= "failed" and order.status ~= "cancelled") then return false end
  if order.expires_tick and now() > order.expires_tick then return false end
  local k = order_kind(order) .. " " .. lower(order.reason) .. " " .. lower(order.source)
  if k:find("combat",1,true) or k:find("retreat",1,true) or k:find("conversation",1,true) then return false end
  if k:find("logistic",1,true) or k:find("acqui",1,true) or k:find("gather",1,true) or k:find("mine",1,true) or k:find("scavenge",1,true) then return true end
  if k:find("craft",1,true) or k:find("construction",1,true) or k:find("build",1,true) or k:find("assignment",1,true) then return true end
  return order.item ~= nil and tonumber(order.priority or 0) >= 500
end

local function active_writ(pair)
  local order = current_order(pair)
  if order_is_work_writ(pair, order) then return order, "order-queue" end
  if pair and pair.emergency_cascade_0326 then return { reason = "emergency-cascade", priority = 600, status = "active" }, "emergency-cascade" end
  if pair and (pair.emergency_craft or pair.direct_acquisition_task_0336 or pair.scavenge or pair.inventory_scan or pair.construction_task_0338 or pair.construction_task_0340 or pair.construction_task_0342 or pair.construction_task_0357) then
    return { reason = "legacy-active-work", priority = 550, status = "active" }, "legacy-surface"
  end
  return nil, "none"
end

local function parse_issuer_unit(order)
  if type(order) ~= "table" then return nil end
  local direct = order.issuer_station_unit or order.issuing_station_unit or order.parent_station_unit or order.superior_station_unit or order.source_station_unit
  if tonumber(direct) then return tonumber(direct) end
  local text = lower(order.reason) .. " " .. lower(order.source) .. " " .. lower(order.key)
  local s = text:match("cascade%-from%-(%d+)") or text:match("issuer[:%-](%d+)") or text:match("superior[:%-](%d+)")
  return s and tonumber(s) or nil
end

function M.authorized_pairs(pair)
  local out = {}
  local seen = {}
  local function add(p, role)
    if valid_pair(p) then
      local u = station_unit(p)
      if u and not seen[u] then
        seen[u] = true
        out[#out+1] = { pair = p, role = role or "home", station_unit = u }
      end
    end
  end
  if not valid_pair(pair) then return out, nil, "invalid-pair" end
  add(pair, "home")
  local root = M.root()
  if root.enabled == false or root.borrow_inputs == false then return out, nil, "disabled" end
  local order, source = active_writ(pair)
  if not order then return out, nil, "no-active-writ" end

  local home_rank = rank(pair)
  local issuer_unit = parse_issuer_unit(order)
  local issuer_seen = false
  local p = superior(pair)
  local depth = 0
  while valid_pair(p) and depth < M.max_superior_depth do
    depth = depth + 1
    if p.station.surface == pair.station.surface and p.station.force == pair.station.force and rank(p) > home_rank then
      add(p, "borrowed-superior")
      if issuer_unit and station_unit(p) == issuer_unit then issuer_seen = true; break end
    end
    p = superior(p)
  end
  if issuer_unit and not issuer_seen then
    local ip = pair_by_station(issuer_unit)
    if valid_pair(ip) and rank(ip) > home_rank and ip.station.surface == pair.station.surface and ip.station.force == pair.station.force then add(ip, "borrowed-issuer") end
  end
  return out, order, source
end

local function source_identity(src)
  if type(src) ~= "table" then return tostring(src) end
  local e = src.entity
  local inv = src.inv or src.inventory
  return tostring(e and valid(e) and (e.unit_number or e.name) or "noentity") .. ":" .. tostring(inv or "noinv") .. ":" .. tostring(src.source or src.inventory_id or "?")
end

local function merge_sources_for_pair(pair, original_func, label)
  local out = {}
  local seen = {}
  local auth, order, source = M.authorized_pairs(pair)
  for _, rec in ipairs(auth or {}) do
    local p = rec.pair
    local ok, list = pcall(original_func, p)
    if ok and type(list) == "table" then
      for _, src in ipairs(list) do
        if type(src) == "table" then
          local id = source_identity(src)
          if not seen[id] then
            seen[id] = true
            src.authority_corridor_0573 = rec.role
            src.authority_home_station_0573 = station_unit(pair)
            src.authority_source_station_0573 = station_unit(p)
            out[#out+1] = src
          end
        end
      end
    end
  end
  if #out > 0 and #auth > 1 then stat("borrowed_source_lists") end
  return out
end

local function inv_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok,c=pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(c) or 0) or 0
end

local function inv_remove(inv, item, count)
  if not (inv and inv.valid and item and count and count > 0) then return 0 end
  local ok,c=pcall(function() return inv.remove({name=item,count=count}) end)
  return ok and (tonumber(c) or 0) or 0
end

local function slot_inv(slot)
  return type(slot) == "table" and (slot.inv or slot.inventory) or nil
end

function M.authorized_item_count(pair, item)
  local n = 0
  local f = pre.station_sources or pre.steward_sources
  if not f then return 0 end
  for _, src in ipairs(merge_sources_for_pair(pair, f, "count")) do n = n + inv_count(slot_inv(src), item) end
  if n > 0 then stat("authorized_counts") end
  return n
end

function M.authorized_remove(pair, item, count, reason)
  local need = math.max(0, tonumber(count) or 0)
  local removed = 0
  if need <= 0 or not item then return 0 end
  local f = pre.station_sources or pre.steward_sources
  if not f then return 0 end
  for _, src in ipairs(merge_sources_for_pair(pair, f, "remove")) do
    if need <= 0 then break end
    local got = inv_remove(slot_inv(src), item, need)
    if got > 0 then
      need = need - got
      removed = removed + got
      if src.authority_corridor_0573 and src.authority_corridor_0573 ~= "home" then stat("borrowed_items_removed", got) end
    end
  end
  if removed > 0 then remember("remove", "station="..safe(station_unit(pair)).." item="..safe(item).." count="..safe(removed).." reason="..safe(reason)) end
  return removed
end

local function wrap_inventory_sources()
  if type(_G.tech_priests_inventory_steward_sources_for_pair) == "function" and not pre.steward_sources then
    pre.steward_sources = _G.tech_priests_inventory_steward_sources_for_pair
    _G.tech_priests_inventory_steward_sources_for_pair = function(pair)
      return merge_sources_for_pair(pair, pre.steward_sources, "steward")
    end
  end
  if type(_G.tech_priests_0358_station_sources_for_pair) == "function" and not pre.station_sources then
    pre.station_sources = _G.tech_priests_0358_station_sources_for_pair
    _G.tech_priests_0358_station_sources_for_pair = function(pair)
      return merge_sources_for_pair(pair, pre.station_sources, "workstate")
    end
  end
  if type(_G.tech_priests_0358_station_item_count) == "function" and not pre.station_item_count then
    pre.station_item_count = _G.tech_priests_0358_station_item_count
    _G.tech_priests_0358_station_item_count = function(pair, item)
      local n = M.authorized_item_count(pair, item)
      if n and n > 0 then return n end
      return pre.station_item_count(pair, item)
    end
  end
  if type(_G.tech_priests_0358_try_remove_from_station) == "function" and not pre.try_remove then
    pre.try_remove = _G.tech_priests_0358_try_remove_from_station
    _G.tech_priests_0358_try_remove_from_station = function(pair, item, count, reason)
      local removed = M.authorized_remove(pair, item, count, reason or "authority-corridor-0573")
      if removed > 0 then return removed end
      return pre.try_remove(pair, item, count, reason)
    end
  end
  -- Deposits deliberately remain home-station-first.  Borrowed superior sources
  -- are supply authority, not a reason to scatter outputs through the hierarchy.
end

local function selected_pair(player)
  if not (player and player.valid) then return nil end
  local selected = player.selected
  if not (selected and selected.valid) then return nil end
  local map = storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
  for _, pair in pairs(map) do
    if pair and ((valid(pair.station) and pair.station == selected) or (valid(pair.priest) and pair.priest == selected)) then return pair end
  end
  return nil
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() commands.remove_command("tp-authority-corridors-0573") end)
  commands.add_command("tp-authority-corridors-0573", "Tech Priests: inspect authority corridor logistics/crafting supply borrowing.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    if not player then return end
    local root = M.root()
    local param = lower(event.parameter or "status")
    if param == "on" then root.enabled = true end
    if param == "off" then root.enabled = false end
    local pair = selected_pair(player)
    player.print("[tp-authority-corridors-0573] enabled="..safe(root.enabled).." borrowed_lists="..safe(root.stats.borrowed_source_lists or 0).." borrowed_items="..safe(root.stats.borrowed_items_removed or 0).." selected="..safe(station_unit(pair)))
    if pair then
      local auth, order, source = M.authorized_pairs(pair)
      player.print("  writ="..safe(source).." order="..safe(order and (order.key or order.reason) or "none").." authorized-stations="..safe(#auth))
      for _, rec in ipairs(auth) do player.print("  - "..safe(rec.role).." station#"..safe(rec.station_unit).." rank="..safe(rank(rec.pair))) end
    end
  end)
end

function M.install()
  M.root()
  wrap_inventory_sources()
  _G.TECH_PRIESTS_AUTHORITY_CORRIDOR_LOGISTICS_0573 = M
  _G.tech_priests_0573_authorized_pairs = M.authorized_pairs
  _G.tech_priests_0573_authorized_item_count = M.authorized_item_count
  _G.tech_priests_0573_authorized_remove = M.authorized_remove
  install_command()
  remember("install", "authority corridor logistics/crafting scaffold installed")
  if log then log("[Tech-Priests 0.1.573] authority corridor logistics/crafting scaffold loaded") end
  return true
end

return M
