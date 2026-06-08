-- Tech Priests — hidden proxy turret alignment authority.
-- 0.1.430: owns the legitimate proxy.teleport exception.  The invisible proxy
-- turret is not the visible priest.  It may be aligned to the priest so the
-- station's real bullet-category ammunition can be used without giving the
-- priest direct weapon prototype behavior.

local ProxyTurretAlignment = {}

local function now()
  return (game and game.tick) or 0
end

local function valid_entity(entity)
  return entity and entity.valid
end

function ProxyTurretAlignment.align_to_priest(pair, proxy, priest, reason)
  priest = priest or (pair and pair.priest) or nil
  proxy = proxy or (pair and pair.proxy) or nil
  if not (valid_entity(proxy) and valid_entity(priest)) then return false end
  local ok, moved = pcall(function() return proxy.teleport(priest.position) end)
  if ok and moved ~= false then
    if pair then
      pair.last_proxy_alignment_0430 = {
        tick = now(),
        reason = reason or "proxy turret alignment",
        proxy_unit = proxy.unit_number,
        priest_unit = priest.unit_number,
        x = priest.position.x,
        y = priest.position.y
      }
    end
    return true
  end
  if pair then
    pair.last_proxy_alignment_0430 = {
      tick = now(),
      reason = reason or "proxy turret alignment failed",
      failed = true,
      proxy_unit = proxy.unit_number,
      priest_unit = priest.unit_number
    }
  end
  return false
end

function ProxyTurretAlignment.describe(pair)
  local rec = pair and pair.last_proxy_alignment_0430 or nil
  if not rec then return "no-proxy-alignment-record" end
  return "tick=" .. tostring(rec.tick)
    .. " reason=" .. tostring(rec.reason)
    .. " failed=" .. tostring(rec.failed or false)
    .. " proxy=" .. tostring(rec.proxy_unit or "?")
    .. " priest=" .. tostring(rec.priest_unit or "?")
end


-- 0.1.555: heartbeat fail-safe for detached hidden proxy turrets.
-- This is recovery/identity protection only. It does not choose targets, issue
-- combat work, or move visible Tech-Priests. The hidden proxy is the one
-- documented teleport exception: it must remain physically attached to the
-- visible priest shell or be deactivated/recreated.
ProxyTurretAlignment.heartbeat_interval_0555 = 90
ProxyTurretAlignment.max_attached_distance_sq_0555 = 4.0
ProxyTurretAlignment.orphan_search_radius_0555 = 20
ProxyTurretAlignment.proxy_name_0555 = "tech-priest-small-arms-proxy"

local function distance_sq(a, b)
  if not (a and b) then return 1/0 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function pairs_root()
  if storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
    return storage.tech_priests.pairs_by_station
  end
  return nil
end

local function proxy_name()
  return rawget(_G, "PROXY_NAME") or ProxyTurretAlignment.proxy_name_0555
end

local function ensure_pair_proxy(pair)
  if pair and pair.proxy and pair.proxy.valid then return pair.proxy end
  local fn = rawget(_G, "ensure_proxy")
  if type(fn) == "function" then
    local ok, proxy = pcall(fn, pair)
    if ok and proxy and proxy.valid then
      pair.proxy = proxy
      return proxy
    end
  end
  return nil
end

local function owned_proxy_units(root)
  local owned = {}
  for _, pair in pairs(root or {}) do
    if pair and pair.proxy and pair.proxy.valid and pair.proxy.unit_number then
      owned[pair.proxy.unit_number] = true
    end
  end
  return owned
end

local function find_unowned_proxy_for_pair(pair, owned)
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid) then return nil end
  local surface = pair.priest.surface
  if not surface then return nil end
  local radius = ProxyTurretAlignment.orphan_search_radius_0555
  local pos = pair.priest.position
  local ok, found = pcall(function()
    return surface.find_entities_filtered({
      name = proxy_name(),
      force = pair.priest.force,
      area = {{pos.x - radius, pos.y - radius}, {pos.x + radius, pos.y + radius}}
    })
  end)
  if not (ok and found) then return nil end
  local best, best_d = nil, 1/0
  for _, proxy in ipairs(found) do
    if proxy and proxy.valid and not (proxy.unit_number and owned[proxy.unit_number]) then
      local d = distance_sq(proxy.position, pos)
      if d < best_d then
        best = proxy
        best_d = d
      end
    end
  end
  return best
end

function ProxyTurretAlignment.heartbeat(event)
  local root = pairs_root()
  if not root then return end
  local owned = owned_proxy_units(root)
  local repaired = 0
  for _, pair in pairs(root) do
    if pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid then
      local proxy = pair.proxy
      if not (proxy and proxy.valid) then
        proxy = find_unowned_proxy_for_pair(pair, owned) or ensure_pair_proxy(pair)
        if proxy and proxy.valid then
          pair.proxy = proxy
          if proxy.unit_number then owned[proxy.unit_number] = true end
        end
      end
      if proxy and proxy.valid then
        local same_surface = proxy.surface == pair.priest.surface
        local d = same_surface and distance_sq(proxy.position, pair.priest.position) or 1/0
        if (not same_surface) or d > ProxyTurretAlignment.max_attached_distance_sq_0555 then
          local ok = ProxyTurretAlignment.align_to_priest(pair, proxy, pair.priest, "proxy-heartbeat-0555-reattach")
          if ok then
            repaired = repaired + 1
            pcall(function() proxy.shooting_target = nil end)
            pair.proxy_expires = math.max(pair.proxy_expires or 0, now() + 180)
          else
            pcall(function() proxy.destroy({ raise_destroy = false }) end)
            pair.proxy = nil
            ensure_pair_proxy(pair)
          end
        end
      end
    end
  end
  if repaired > 0 and storage and storage.tech_priests then
    storage.tech_priests.proxy_reattach_count_0555 = (storage.tech_priests.proxy_reattach_count_0555 or 0) + repaired
    storage.tech_priests.last_proxy_reattach_tick_0555 = now()
  end
end

function ProxyTurretAlignment.register_heartbeat()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(ProxyTurretAlignment.heartbeat_interval_0555, function(event)
      ProxyTurretAlignment.heartbeat(event)
    end, {
      owner = "proxy_turret_alignment_0555",
      category = "recovery",
      note = "Reattach hidden proxy turrets to their visible Tech-Priest shells."
    })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(ProxyTurretAlignment.heartbeat_interval_0555, function(event)
      ProxyTurretAlignment.heartbeat(event)
    end)
  end
end

function ProxyTurretAlignment.install()
  _G.tech_priests_align_proxy_to_priest_0430 = function(pair, proxy, priest, reason)
    return ProxyTurretAlignment.align_to_priest(pair, proxy, priest, reason)
  end
  _G.tech_priests_proxy_alignment_summary_0430 = function(pair)
    return ProxyTurretAlignment.describe(pair)
  end
  _G.tech_priests_proxy_alignment_heartbeat_0555 = function(event)
    return ProxyTurretAlignment.heartbeat(event)
  end
  ProxyTurretAlignment.register_heartbeat()
end

return ProxyTurretAlignment
