-- scripts/core/construction_site_planner.lua
-- Tech Priests 0.1.359 station-bound construction site planner.
--
-- Owns the physical placement scan for station-led construction.  The planner
-- intentionally keeps inventory ownership out of the placement algorithm: the
-- Cogitator Station/work-inventory layer decides what exists, this module only
-- decides where a thing can safely go.
--
-- Placement doctrine:
--   * generic machines use a deterministic spiral scan around the station
--   * the scan starts at the top/north center of the station and prefers the
--     left/west side before the right/east side on each ring
--   * placement candidates must pass Factorio can_place_entity and a one-tile
--     buffer/clearance check where possible
--   * assemblers require a wider service buffer and at least one open side
--   * normal miners prefer actual resource patches; Martian emergency miners
--     are patchless and use the station spiral instead

local Planner = {}
Planner.version = "0.1.359"
Planner.default_radius = 36
Planner.max_radius = 40
Planner.min_radius = 3
Planner.max_candidates_per_ring = 4096

local function valid(e) return e and e.valid end
local function routed_find(surface, filters, category, negative_key, ttl)
  local Scan = rawget(_G, "TechPriestsScanRouting0610")
  if not Scan then local okS, mod = pcall(require, "scripts.core.scan_routing_0610"); if okS then Scan = mod end end
  if Scan and type(Scan.find_entities) == "function" then
    local ents = select(1, Scan.find_entities(surface, filters, { category = category or "construction", negative_key = negative_key, negative_ttl = ttl or 60 * 4 }))
    return ents or {}
  end
  local ok, ents = pcall(function() return surface.find_entities_filtered(filters) end)
  return (ok and ents) or {}
end
local function dist_sq(a, b)
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function proto_entity(name)
  if not name or not prototypes or not prototypes.entity then return nil end
  local ok, proto = pcall(function() return prototypes.entity[name] end)
  if ok then return proto end
  return nil
end

local function entity_type(entity_name)
  local p = proto_entity(entity_name)
  if not p then return nil end
  local ok, t = pcall(function() return p.type end)
  return ok and t or nil
end

local function radius_for(pair)
  if not (pair and valid(pair.station)) then return Planner.default_radius end
  if _G.refresh_pair_radius then
    local ok, r = pcall(_G.refresh_pair_radius, pair)
    if ok and tonumber(r) then return math.max(8, math.min(96, tonumber(r))) end
  end
  if _G.get_station_operating_radius then
    local ok, r = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(r) then return math.max(8, math.min(96, tonumber(r))) end
  end
  return Planner.default_radius
end

local function as_xy(pos)
  if not pos then return { x = 0, y = 0 } end
  return { x = pos.x or pos[1] or 0, y = pos.y or pos[2] or 0 }
end

local function box_for(entity_name)
  local ep = proto_entity(entity_name)
  if not ep then return nil end
  local ok, box = pcall(function() return ep.collision_box end)
  if not ok or not box then return nil end
  local lt = box.left_top or box[1] or box.lt
  local rb = box.right_bottom or box[2] or box.rb
  if not lt or not rb then return nil end
  lt, rb = as_xy(lt), as_xy(rb)
  return { left_top = lt, right_bottom = rb, width = math.abs((rb.x or 0) - (lt.x or 0)), height = math.abs((rb.y or 0) - (lt.y or 0)) }
end

local function buffer_for(entity_name, category)
  if category == "assembler" then return 2.0 end
  if category == "emergency-powertrain" then return 1.25 end
  if category == "emergency-smelter" or category == "furnace" then return 1.0 end
  if category == "emergency-miner" then return 1.0 end
  if category == "miner" then return 1.0 end
  if category == "lab" then return 1.0 end
  local box = box_for(entity_name)
  if box and math.max(box.width or 1, box.height or 1) >= 3 then return 1.5 end
  return 1.0
end

local function footprint_area(entity_name, pos, buffer)
  local box = box_for(entity_name)
  buffer = buffer or 1
  if box then
    return {
      { pos.x + box.left_top.x - buffer, pos.y + box.left_top.y - buffer },
      { pos.x + box.right_bottom.x + buffer, pos.y + box.right_bottom.y + buffer }
    }
  end
  return { { pos.x - buffer, pos.y - buffer }, { pos.x + buffer, pos.y + buffer } }
end

local ignored_clearance_types = {
  corpse = true,
  ["particle-source"] = true,
  ["highlight-box"] = true,
  ["simple-entity-with-owner"] = true,
  ["entity-ghost"] = true,
  ["tile-ghost"] = true,
}

local function area_clear(surface, entity_name, pos, buffer, ignore_resources)
  if not (surface and entity_name and pos) then return false end
  local area = footprint_area(entity_name, pos, buffer)
  local ents = routed_find(surface, { area = area }, "construction-clearance", nil, 60 * 2)
  if not ents then return false end
  for _, e in pairs(ents) do
    if valid(e) then
      local t = e.type
      if not ignored_clearance_types[t] then
        if not (ignore_resources and t == "resource") then
          return false
        end
      end
    end
  end
  return true
end

local function can_place(surface, force, entity_name, pos)
  if not (surface and force and entity_name and pos) then return false end
  local ok, result = pcall(function()
    return surface.can_place_entity({ name = entity_name, position = pos, force = force, build_check_type = defines.build_check_type.manual })
  end)
  if ok then return result == true end
  ok, result = pcall(function()
    return surface.can_place_entity({ name = entity_name, position = pos, force = force })
  end)
  return ok and result == true
end

local function open_side_clear(surface, entity_name, pos, buffer)
  local box = box_for(entity_name)
  local side = 3
  if box then side = math.max(2.5, math.max(box.width or 2, box.height or 2) * 0.75 + 1.5) end
  local checks = {
    { x = pos.x - side, y = pos.y }, -- west/left first
    { x = pos.x, y = pos.y - side }, -- north/top second
    { x = pos.x + side, y = pos.y },
    { x = pos.x, y = pos.y + side },
  }
  for _, p in ipairs(checks) do
    if area_clear(surface, entity_name, p, buffer or 1, true) then return true end
  end
  return false
end

local function has_existing_miner_near(surface, pos)
  local ents = routed_find(surface, { position = pos, radius = 4.25, type = "mining-drill" }, "construction-miner", nil, 60 * 3)
  return ents and #ents > 0
end

local function plan_resource_miner(pair, entity_name)
  local station = pair and pair.station
  if not valid(station) then return nil, "invalid-station" end
  local surface, force = station.surface, station.force
  local r = radius_for(pair)
  local resources = routed_find(surface, { position = station.position, radius = r, type = "resource" }, "construction-resource", "construction-resource:" .. tostring(surface.index) .. ":" .. tostring(force.index) .. ":" .. tostring(station.unit_number or "?"), 60 * 6)
  if not resources then return nil, "no-resource-list" end

  local best, best_d2
  for _, res in pairs(resources) do
    if valid(res) and (not res.amount or res.amount > 0) then
      local pos = { x = res.position.x, y = res.position.y }
      if dist_sq(pos, station.position) <= r * r and not has_existing_miner_near(surface, pos)
          and can_place(surface, force, entity_name, pos)
          and area_clear(surface, entity_name, pos, buffer_for(entity_name, "miner"), true) then
        local d2 = dist_sq(pos, station.position)
        if not best_d2 or d2 < best_d2 then best, best_d2 = pos, d2 end
      end
    end
  end
  if best then return best, "resource-patch-buffered" end
  return nil, "no-miner-site"
end

local function x_order_for_ring(r)
  local xs = { 0 }
  for n = 1, r do
    xs[#xs+1] = -n -- left/west preference
    xs[#xs+1] = n
  end
  return xs
end

local function spiral_offsets(r)
  local out, seen = {}, {}
  local function add(dx, dy)
    local key = tostring(dx) .. ":" .. tostring(dy)
    if not seen[key] then seen[key] = true; out[#out+1] = { dx = dx, dy = dy } end
  end

  -- Start top/north center, then walk outward left/west before right/east.
  for _, dx in ipairs(x_order_for_ring(r)) do add(dx, -r) end
  -- Then continue the left side downward, giving the station's left working yard priority.
  for dy = -r + 1, r do add(-r, dy) end
  -- Then bottom, still left-to-right.
  for dx = -r + 1, r do add(dx, r) end
  -- Then right side upward.
  for dy = r - 1, -r + 1, -1 do add(r, dy) end
  return out
end

local function grid_position(origin, dx, dy)
  return { x = origin.x + dx, y = origin.y + dy }
end

function Planner.plan_spiral(pair, entity_name, category)
  local station = pair and pair.station
  if not valid(station) then return nil, "invalid-station" end
  local surface, force = station.surface, station.force
  local max_r = math.min(radius_for(pair), Planner.max_radius)
  local buffer = buffer_for(entity_name, category)
  local ignore_resources = category == "miner" or category == "emergency-miner"

  for r = Planner.min_radius, max_r do
    local tested = 0
    for _, off in ipairs(spiral_offsets(r)) do
      tested = tested + 1
      if tested > Planner.max_candidates_per_ring then break end
      local pos = grid_position(station.position, off.dx, off.dy)
      if can_place(surface, force, entity_name, pos)
          and area_clear(surface, entity_name, pos, buffer, ignore_resources) then
        if category ~= "assembler" or open_side_clear(surface, entity_name, pos, 1.0) then
          return pos, "station-spiral-top-left-buffered"
        end
      end
    end
  end
  return nil, "no-spiral-site"
end

function Planner.plan_site(pair, placeable)
  if not (pair and valid(pair.station) and placeable and placeable.entity_name) then return nil, "invalid" end
  local category = placeable.category or "generic"
  if category == "deferred-network" then return nil, "deferred-network-submodule" end

  -- Ordinary miners use resources.  The Martian emergency miner is patchless and
  -- must use the spiral station yard instead.
  if category == "miner" then return plan_resource_miner(pair, placeable.entity_name) end
  if category == "emergency-miner" then return Planner.plan_spiral(pair, placeable.entity_name, category) end
  if category == "emergency-power-pole" or category == "emergency-powertrain" or category == "emergency-smelter" then
    return Planner.plan_spiral(pair, placeable.entity_name, category)
  end
  if entity_type(placeable.entity_name) == "mining-drill" and category ~= "emergency-miner" then
    return plan_resource_miner(pair, placeable.entity_name)
  end
  return Planner.plan_spiral(pair, placeable.entity_name, category)
end

function Planner.debug_sequence(pair, entity_name, limit)
  local station = pair and pair.station
  if not valid(station) then return {} end
  local out = {}
  limit = limit or 24
  for r = Planner.min_radius, math.min(Planner.min_radius + 4, Planner.max_radius) do
    for _, off in ipairs(spiral_offsets(r)) do
      out[#out+1] = { x = station.position.x + off.dx, y = station.position.y + off.dy, ring = r }
      if #out >= limit then return out end
    end
  end
  return out
end

return Planner
