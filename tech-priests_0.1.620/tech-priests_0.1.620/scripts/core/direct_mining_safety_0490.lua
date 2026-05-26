-- scripts/core/direct_mining_safety_0490.lua
-- Tech Priests 0.1.490
--
-- Hardens the oldest emergency direct-gather path.  That legacy path could
-- choose a primitive source such as stone, label the desired output as ammo, and
-- then deposit the desired output when the mining timer completed.  In the same
-- family of failures, stale current targets could point at stations/priests or
-- other protected entities.  This authority makes direct mining literal: a
-- priest may mine only resource/tree/neutral rock targets, may deposit only the
-- thing actually gathered, and may not spill outputs onto the ground as a normal
-- storage path.

local M = {}
M.version = "0.1.490"
M.storage_key = "direct_mining_safety_0490"

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function item_exists(name) return name and prototypes and prototypes.item and prototypes.item[name] ~= nil end

local function registry()
  local ok, R = pcall(require, "scripts.core.runtime_event_registry")
  return ok and R or nil
end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  local root = storage.tech_priests[M.storage_key] or {}
  storage.tech_priests[M.storage_key] = root
  root.version = M.version
  if root.enabled == nil then root.enabled = true end
  root.stats = root.stats or {}
  root.recent = root.recent or {}
  return root
end

local function record(action, pair, detail)
  local root = ensure_root()
  root.stats[action] = (root.stats[action] or 0) + 1
  local rec = {
    tick = now(),
    action = action,
    station = pair and pair.station and pair.station.valid and pair.station.unit_number or pair and pair.station_unit or nil,
    priest = pair and pair.priest and pair.priest.valid and pair.priest.unit_number or pair and pair.priest_unit or nil,
    detail = tostring(detail or "")
  }
  root.recent[#root.recent + 1] = rec
  while #root.recent > 18 do table.remove(root.recent, 1) end
  if log then log("[Tech-Priests 0.1.490] " .. action .. " station=" .. tostring(rec.station) .. " priest=" .. tostring(rec.priest) .. " " .. rec.detail) end
end

local function entity_name(e)
  return e and e.valid and e.name or "nil"
end

local function is_tech_priest_entity(e)
  if not valid(e) then return false end
  local n = e.name or ""
  return n:find("tech%-priest", 1, false) ~= nil or n:find("cogitator%-station", 1, false) ~= nil
end

local function is_home_station(pair, e)
  return valid(e) and pair and valid(pair.station) and e == pair.station
end

local function is_mineable_world_source(pair, e)
  if not valid(e) then return false end
  if is_home_station(pair, e) or is_tech_priest_entity(e) then return false end
  local t = e.type
  if t == "resource" or t == "tree" then return true end
  if t == "simple-entity" or t == "simple-entity-with-owner" or t == "rock" then
    -- Neutral map rocks are valid.  Owned machines, stations, chests, and
    -- support entities wearing simple-entity-with-owner clothing are not.
    if e.force and pair and valid(pair.station) and e.force == pair.station.force then return false end
    return true
  end
  return false
end

local function direct_actual_item(pair, cur)
  if not cur then return nil end
  if cur.kind == "direct-dirt-0273" or cur.kind == "dirt" then return item_exists("stone") and "stone" or nil end
  if cur.entity and cur.entity.valid then
    local e = cur.entity
    if e.type == "tree" then return item_exists("wood") and "wood" or nil end
    if e.type == "resource" then return item_exists(e.name) and e.name or nil end
    if e.type == "simple-entity" or e.type == "simple-entity-with-owner" or e.type == "rock" then
      -- Rocks and crude scenery are not magic ammo printers.  The only safe
      -- literal output is stone unless a later resource doctrine proves a real
      -- mineable product path.
      return item_exists("stone") and "stone" or nil
    end
  end
  if item_exists(cur.item_name) then return cur.item_name end
  return item_exists("stone") and "stone" or nil
end

local function sanitize_current(pair, task)
  local cur = task and task.current or nil
  if not cur then return true end
  if cur.entity and cur.entity.valid and not is_mineable_world_source(pair, cur.entity) then
    record("blocked-protected-target", pair, "target=" .. entity_name(cur.entity) .. " type=" .. tostring(cur.entity.type))
    task.current = nil
    if pair then pair.target = nil end
    return false
  end
  if cur.entity and cur.entity.valid then
    local actual = direct_actual_item(pair, cur)
    if actual and cur.output_item ~= actual then
      record("blocked-output-transmutation", pair, "wanted=" .. tostring(cur.output_item) .. " actual=" .. tostring(actual) .. " source=" .. entity_name(cur.entity))
      cur.blocked_desired_output_0490 = cur.output_item
      cur.output_item = actual
      cur.item_name = actual
      cur.wanted_item = actual
    end
  elseif cur.kind == "direct-dirt-0273" or cur.kind == "dirt" then
    cur.output_item = "stone"
    cur.item_name = "stone"
    cur.wanted_item = "stone"
  end
  return true
end

local function safe_deposit(pair, item, count, reason)
  if not (pair and valid(pair.station) and item_exists(item)) then return false, "invalid" end
  count = math.max(1, tonumber(count) or 1)
  if _G.tech_priests_safe_deposit_item then
    local ok, why = false, nil
    pcall(function() ok, why = _G.tech_priests_safe_deposit_item(pair, item, count, reason or "direct-mining-safety-0490") end)
    if ok then return true, why or "safe-deposit" end
    record("deposit-blocked", pair, "item=" .. tostring(item) .. " reason=" .. tostring(why))
    return false, why or "deposit-blocked"
  end
  return false, "no-steward"
end

function M.patch_legacy_direct_gather()
  if type(_G.tech_priests_0273_deposit) == "function" and not rawget(_G, "TECH_PRIESTS_0490_PRE_0273_DEPOSIT") then
    _G.TECH_PRIESTS_0490_PRE_0273_DEPOSIT = _G.tech_priests_0273_deposit
    _G.tech_priests_0273_deposit = function(pair, item, count)
      local ok = safe_deposit(pair, item, count, "legacy-direct-gather-0273")
      -- Never report success if the item could not be stored.  Returning false
      -- causes the behavior layer to try again instead of spilling ammunition.
      return ok and true or false
    end
  end

  if type(_G.tech_priests_0273_find_direct_target) == "function" and not rawget(_G, "TECH_PRIESTS_0490_PRE_FIND_DIRECT_TARGET") then
    _G.TECH_PRIESTS_0490_PRE_FIND_DIRECT_TARGET = _G.tech_priests_0273_find_direct_target
    _G.tech_priests_0273_find_direct_target = function(pair, output)
      local cand = _G.TECH_PRIESTS_0490_PRE_FIND_DIRECT_TARGET(pair, output)
      if cand and cand.entity and cand.entity.valid and not is_mineable_world_source(pair, cand.entity) then
        record("rejected-direct-candidate", pair, "output=" .. tostring(output) .. " target=" .. entity_name(cand.entity) .. " type=" .. tostring(cand.entity.type))
        return nil
      end
      if cand and cand.entity and cand.entity.valid then
        local actual = direct_actual_item(pair, cand)
        if actual then
          cand.blocked_desired_output_0490 = cand.output_item
          cand.output_item = actual
          cand.item_name = actual
          cand.wanted_item = actual
        end
      end
      return cand
    end
  end

  if type(_G.tech_priests_0273_service_direct_current) == "function" and not rawget(_G, "TECH_PRIESTS_0490_PRE_SERVICE_DIRECT_CURRENT") then
    _G.TECH_PRIESTS_0490_PRE_SERVICE_DIRECT_CURRENT = _G.tech_priests_0273_service_direct_current
    _G.tech_priests_0273_service_direct_current = function(pair, task)
      if not sanitize_current(pair, task) then return false end
      local cur = task and task.current or nil
      local pos = cur and (cur.position or (cur.entity and cur.entity.valid and cur.entity.position)) or nil
      if pair and pair.priest and pair.priest.valid and pos and task and task.direct_due_tick_0273 and game and game.tick >= task.direct_due_tick_0273 then
        local dx = pair.priest.position.x - pos.x
        local dy = pair.priest.position.y - pos.y
        local close = rawget(_G, "EMERGENCY_CRAFT_PICKUP_DISTANCE_SQ") or 2.25
        if dx * dx + dy * dy <= close then
          local output = direct_actual_item(pair, cur) or "stone"
          local stored, why = safe_deposit(pair, output, 1, "legacy-direct-gather-complete-0490")
          if not stored then
            task.direct_due_tick_0273 = game.tick + 90
            pair.mode = "emergency-gathering-waiting-for-station-space"
            record("direct-completion-paused", pair, "item=" .. tostring(output) .. " reason=" .. tostring(why))
            return true
          end
          if cur and cur.entity and cur.entity.valid then
            pcall(function()
              local e = cur.entity
              if e.valid and e.type == "resource" then
                local amount = tonumber(e.amount) or 0
                if amount > 1 then e.amount = math.max(1, amount - 25) end
              elseif e.valid and e.health and e.health > 0 and is_mineable_world_source(pair, e) then
                local maxh = 100
                pcall(function() maxh = e.prototype and e.prototype.max_health or maxh end)
                e.damage(math.max(25, math.min(125, maxh * 0.35)), pair.station.force, "impact", pair.priest)
                if e.valid and e.health and e.health <= 1 then e.destroy() end
              end
            end)
          end
          record("direct-gather-stored", pair, "item=" .. tostring(output) .. " source=" .. tostring(cur and cur.blocked_desired_output_0490 or cur and cur.item_name))
          pair.emergency_craft = nil
          pair.mode = "returning"
          pair.target = nil
          if _G.return_to_station and pair.priest and pair.station then pcall(function() _G.return_to_station(pair.priest, pair.station) end) end
          return true
        end
      end
      local ok = _G.TECH_PRIESTS_0490_PRE_SERVICE_DIRECT_CURRENT(pair, task)
      return ok
    end
  end

  -- Older dirt-scrape completion had its own spill fallback.  Keep the output
  -- literal and station-bound.
  if type(_G.tech_priests_0269_finish_dirt_scrape) == "function" and not rawget(_G, "TECH_PRIESTS_0490_PRE_FINISH_DIRT") then
    _G.TECH_PRIESTS_0490_PRE_FINISH_DIRT = _G.tech_priests_0269_finish_dirt_scrape
    _G.tech_priests_0269_finish_dirt_scrape = function(pair, task)
      if not (pair and valid(pair.station) and task and task.current and task.current.kind == "dirt") then return false end
      local ok = safe_deposit(pair, "stone", 1, "legacy-dirt-scrape-0269")
      if not ok then return true end
      task.current = nil
      task.dirt_due_tick_0269 = nil
      pair.mode = "returning"
      pair.emergency_craft = nil
      if _G.return_to_station and pair.priest and pair.station then pcall(function() _G.return_to_station(pair.priest, pair.station) end) end
      record("dirt-stored", pair, "stone=1")
      return true
    end
  end
end

function M.rescue_missing_priests()
  local root = ensure_root(); if root.enabled == false then return end
  for _, pair in pairs(pair_map()) do
    if pair and valid(pair.station) and not valid(pair.priest) then
      local re = pair.reimprint_0298
      if re and re.active then
        -- Legitimate re-imprinting: let the lifecycle module finish.
      else
        pair.lost_priest_0490 = pair.lost_priest_0490 or { first = now(), attempts = 0 }
        if now() - (pair.lost_priest_0490.last_attempt or 0) >= 180 then
          pair.lost_priest_0490.last_attempt = now()
          pair.lost_priest_0490.attempts = (pair.lost_priest_0490.attempts or 0) + 1
          pair.target = nil
          pair.combat_target = nil
          pair.active_task = nil
          pair.active_task_0285 = nil
          if pair.emergency_craft and pair.emergency_craft.current and pair.emergency_craft.current.entity and not pair.emergency_craft.current.entity.valid then pair.emergency_craft.current = nil end
          local ok = false
          if type(_G.ensure_pair_priest) == "function" then
            pcall(function() ok = _G.ensure_pair_priest(pair, true, true) end)
          end
          if (not ok) and type(_G.respawn_pair_priest) == "function" then
            pcall(function() ok = _G.respawn_pair_priest(pair, "lost-priest-rescue-0490") end)
          end
          record(ok and "rescued-missing-priest" or "missing-priest-rescue-failed", pair, "attempts=" .. tostring(pair.lost_priest_0490.attempts))
        end
      end
    elseif pair and valid(pair.priest) then
      pair.lost_priest_0490 = nil
    end
  end
end

function M.handle_removed(event)
  local e = event and event.entity
  if not valid(e) then return false end
  if is_tech_priest_entity(e) then
    local found = nil
    for _, pair in pairs(pair_map()) do
      if pair and ((pair.priest == e) or (pair.station == e) or pair.priest_unit == e.unit_number or pair.station_unit == e.unit_number) then found = pair; break end
    end
    record("tracked-entity-removed", found, "entity=" .. entity_name(e) .. " type=" .. tostring(e.type) .. " event=" .. tostring(event.name))
  end
  return false
end

function M.wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.direct_mining_safety_wrapped_0490 then return false end
  local prev = diag.pair_dump_lines
  diag.direct_mining_safety_wrapped_0490 = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local root = ensure_root()
    lines[#lines+1] = "PAIR-DUMP-0468 DIRECT-MINING-SAFETY-0490 BEGIN enabled=" .. tostring(root.enabled)
      .. " protected=" .. tostring(root.stats["blocked-protected-target"] or 0)
      .. " transmute=" .. tostring(root.stats["blocked-output-transmutation"] or 0)
      .. " deposit_blocked=" .. tostring(root.stats["deposit-blocked"] or 0)
      .. " rescued=" .. tostring(root.stats["rescued-missing-priest"] or 0)
    for i = math.max(1, #root.recent - 8), #root.recent do
      local r = root.recent[i]
      if r then lines[#lines+1] = "PAIR-DUMP-0468 safety0490[" .. tostring(i) .. "] tick=" .. tostring(r.tick) .. " action=" .. tostring(r.action) .. " station=" .. tostring(r.station) .. " priest=" .. tostring(r.priest) .. " " .. tostring(r.detail) end
    end
    lines[#lines+1] = "PAIR-DUMP-0468 DIRECT-MINING-SAFETY-0490 END"
    return lines
  end
  return true
end

function M.register_events()
  local R = registry()
  if R and defines and defines.events then
    R.on_event({ defines.events.on_entity_died, defines.events.script_raised_destroy, defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined }, function(event) return M.handle_removed(event) end, nil, { owner = "direct_mining_safety_0490", category = "safety", priority = "normal" })
    R.on_nth_tick(113, function() M.rescue_missing_priests() end, { owner = "direct_mining_safety_0490", category = "safety", priority = "normal" })
  elseif script then
    script.on_nth_tick(113, function() M.rescue_missing_priests() end)
  end
end

function M.register_commands()
  if not commands then return end
  pcall(function() commands.remove_command("tp-direct-mining-safety-0490") end)
  commands.add_command("tp-direct-mining-safety-0490", "Tech Priests 0.1.490: direct-mining safety status. Usage: status|all|rescue|on|off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local root = ensure_root()
    local p = tostring(event.parameter or "status")
    if p == "on" then root.enabled = true end
    if p == "off" then root.enabled = false end
    if p == "rescue" or p == "all" then M.rescue_missing_priests() end
    if player and player.valid then
      player.print("[tp-direct-mining-safety-0490] enabled=" .. tostring(root.enabled)
        .. " protected=" .. tostring(root.stats["blocked-protected-target"] or 0)
        .. " transmute=" .. tostring(root.stats["blocked-output-transmutation"] or 0)
        .. " deposit_blocked=" .. tostring(root.stats["deposit-blocked"] or 0)
        .. " rescued=" .. tostring(root.stats["rescued-missing-priest"] or 0))
    end
  end)
end

function M.install()
  if M.installed then return true end
  M.installed = true
  ensure_root()
  _G.TechPriestsDirectMiningSafety0490 = M
  M.patch_legacy_direct_gather()
  M.wrap_pair_dump()
  M.register_events()
  M.register_commands()
  if log then log("[Tech-Priests 0.1.490] direct-mining safety installed; direct gathering is literal, station-bound, and no-spill") end
  return true
end

return M
