-- scripts/core/efficiency_economy_0583.lua
-- Tech Priests 0.1.583
--
-- Visual/render economy pass. This is not a behavior controller. It wraps the
-- Factorio runtime rendering API inside this mod's Lua state so transient map
-- visuals are only created when at least one connected player is plausibly able
-- to see the target area. Offscreen work still happens; offscreen decorative
-- beams, status texts, lights, reservation icons, and scan/range helpers simply
-- do not create fresh render objects until observed again.

local M = {}
M.version = "0.1.583"
M.storage_key = "efficiency_economy_0583"
M.observe_radius = 112
M.always_allow_ttl_min = 1
M.cleanup_interval = 60 * 41

local originals = {}
local installed = false

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function dist2(a,b)
  if not (a and b) then return math.huge end
  local dx=(a.x or a[1] or 0)-(b.x or b[1] or 0)
  local dy=(a.y or a[2] or 0)-(b.y or b[2] or 0)
  return dx*dx+dy*dy
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = { version=M.version, enabled=true, skip_unobserved_rendering=true, observe_radius=M.observe_radius, stats={}, recent={} }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.skip_unobserved_rendering == nil then r.skip_unobserved_rendering = true end
  r.observe_radius = tonumber(r.observe_radius) or M.observe_radius
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function remember(action, detail)
  local r=M.root()
  r.recent[#r.recent+1] = { tick=now(), action=tostring(action or "event"), detail=tostring(detail or "") }
  while #r.recent > 40 do table.remove(r.recent, 1) end
end

local function pos_from(v)
  if not v then return nil, nil end
  if valid(v) then return v.position, v.surface end
  if type(v) == "table" then
    if valid(v.entity) then
      local p = v.entity.position
      local off = v.offset
      if type(off) == "table" then p = { x=(p.x or 0)+(off.x or off[1] or 0), y=(p.y or 0)+(off.y or off[2] or 0) } end
      return p, v.entity.surface
    end
    if v.position then return pos_from(v.position) end
    if v.x or v[1] then return { x=v.x or v[1] or 0, y=v.y or v[2] or 0 }, nil end
  end
  return nil, nil
end

local function position_and_surface(params)
  if type(params) ~= "table" then return nil, nil end
  local pos, surf = pos_from(params.target)
  if not pos then pos, surf = pos_from(params.position) end
  if not pos then pos, surf = pos_from(params.left_top) end
  if not pos then pos, surf = pos_from(params.from) end
  if params.from and params.to then
    local a, sa = pos_from(params.from); local b, sb = pos_from(params.to)
    if a and b then pos = { x=((a.x or 0)+(b.x or 0))*0.5, y=((a.y or 0)+(b.y or 0))*0.5 }; surf = sa or sb or surf end
  end
  if not surf then surf = params.surface end
  return pos, surf
end

local function surface_index(surface)
  if type(surface) == "number" then return surface end
  if type(surface) == "string" and game and game.surfaces then local s=game.surfaces[surface]; return s and s.index or nil end
  if surface and surface.valid then return surface.index end
  return nil
end

local function player_list_allows(params)
  -- If a caller already supplied a player filter, keep it. These are usually
  -- explicit player-facing overlays; suppressing them here can make selected
  -- radius/network diagnostics feel broken.
  if type(params) == "table" and params.players ~= nil then return true end
  return false
end

function M.is_observed(params)
  local r = M.root()
  if r.enabled == false or r.skip_unobserved_rendering == false then return true end
  if player_list_allows(params) then return true end
  if type(params) == "table" and tonumber(params.time_to_live or 0) and tonumber(params.time_to_live or 0) <= M.always_allow_ttl_min then return true end
  local pos, surf = position_and_surface(params)
  if not (pos and game and game.connected_players) then return true end
  local si = surface_index(surf)
  local radius = tonumber(r.observe_radius) or M.observe_radius
  local limit = radius * radius
  for _, p in pairs(game.connected_players) do
    if p and p.valid and p.connected then
      local ps = p.surface and p.surface.index or nil
      if (not si) or (not ps) or si == ps then
        if dist2(pos, p.position) <= limit then return true end
      end
    end
  end
  return false
end

local function wrap_render_function(name)
  if not (rendering and type(rendering[name]) == "function") then return false end
  if originals[name] then return true end
  originals[name] = rendering[name]
  rendering[name] = function(params)
    local r = M.root()
    if r.enabled ~= false and r.skip_unobserved_rendering ~= false and not M.is_observed(params) then
      stat("skipped_" .. name)
      return nil
    end
    stat("allowed_" .. name)
    return originals[name](params)
  end
  return true
end

function M.cleanup()
  local r=M.root()
  stat("cleanup_runs")
  while #r.recent > 40 do table.remove(r.recent,1) end
end

local function status(player)
  local r=M.root()
  local lines={}
  lines[#lines+1] = "[tp-efficiency-economy-0583] enabled="..safe(r.enabled).." visual_skip="..safe(r.skip_unobserved_rendering).." radius="..safe(r.observe_radius)
  local keys={"draw_sprite","draw_text","draw_line","draw_circle","draw_light"}
  for _, name in ipairs(keys) do
    lines[#lines+1] = "  "..name.." allowed="..safe(r.stats["allowed_"..name] or 0).." skipped="..safe(r.stats["skipped_"..name] or 0)
  end
  if player and player.valid and player.print then for _,l in ipairs(lines) do player.print(l) end else for _,l in ipairs(lines) do log(l) end end
end

function M.install()
  if installed then return true end
  local wrapped = 0
  for _, name in ipairs({"draw_sprite","draw_text","draw_line","draw_circle","draw_light"}) do if wrap_render_function(name) then wrapped = wrapped + 1 end end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0583") end end)
  commands.add_command("tp-efficiency-economy-0583", "Tech Priests 0.1.583 visual/render economy. Params: on/off/skip-on/skip-off/radius N/status", function(event)
    local player = game and game.get_player(event.player_index)
    local r=M.root()
    local p=tostring(event.parameter or "status")
    local n=tonumber(p:match("radius%s+(%d+)"))
    if p == "on" then r.enabled=true elseif p == "off" then r.enabled=false
    elseif p == "skip-on" then r.skip_unobserved_rendering=true elseif p == "skip-off" then r.skip_unobserved_rendering=false
    elseif n then r.observe_radius=math.max(32, math.min(512, n)); remember("radius", tostring(r.observe_radius)) end
    status(player)
  end)
  local okR, R = pcall(require, "scripts.core.runtime_scheduler")
  if okR and R and R.on_nth_tick then
    R.on_nth_tick(M.cleanup_interval, function() M.cleanup() end, { owner="efficiency_economy_0583", category="visual-economy", priority="last", note="prune visual economy counters" })
  end
  installed = true
  if log then log("[Tech-Priests 0.1.583] visual/render economy installed; wrapped="..safe(wrapped).." rendering functions") end
  return true
end

return M
