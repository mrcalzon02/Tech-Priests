-- scripts/core/scan_beam_controller_0529.lua
-- Tech Priests 0.1.529
--
-- Final-loaded scan/beam visual authority.  Older fragments drew several
-- different colored scan/mining/combat lines directly.  This module centralizes
-- those calls behind one controller, preserves the action-arbiter safety checks,
-- and makes mining/tree/rock damage visibly smoky without restoring remote-work
-- behavior.

local M = {}
M.version = "0.1.539"
M.storage_key = "scan_beam_controller_0529"
M.line_ttl = 10
M.circle_ttl = 8
M.scan_ttl = 14
M.max_recent = 140
M.smoke_interval = 9
M.default_width = 2
M.smoke_name = rawget(_G, "MACHINE_DAMAGE_SMOKE_ENTITY_NAME") or "smoke-fast"

local previous_scan_line = nil
local previous_fire_laser = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function lower(v) return string.lower(tostring(v or "")) end
local function safe(v) if v == nil then return "nil" end; local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function dist_sq(a,b) if not (a and b) then return nil end; local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version=M.version, enabled=true, stats={}, recent={}, smoke_cooldowns={} }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.smoke_cooldowns = r.smoke_cooldowns or {}
  return r
end
local function stat(k,n) local r=root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(kind, pair, target, detail)
  local r=root(); stat(kind)
  local rec={tick=now(),kind=tostring(kind or "beam"),station=safe(pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number))),priest=safe(pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number))),target=safe(valid(target) and (target.name .. "#" .. tostring(target.unit_number or "?")) or "none"),detail=tostring(detail or "")}
  r.recent[#r.recent+1]=rec
  while #r.recent>M.max_recent do table.remove(r.recent,1) end
  if pair then pair.scan_beam_0529_last=rec end
  return rec
end

local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function pair_by_priest(priest)
  if not valid(priest) then return nil end
  local tp=storage and storage.tech_priests or nil
  if tp and tp.pairs_by_priest and priest.unit_number then
    local p=tp.pairs_by_priest[priest.unit_number]
    if p then return p end
  end
  for _,p in pairs(pair_map()) do if p and p.priest == priest then return p end end
  return nil
end

local colors = {
  mining = { r=1.00,g=0.32,b=0.04,a=0.88 },
  resource = { r=1.00,g=0.42,b=0.05,a=0.84 },
  world_damage = { r=1.00,g=0.22,b=0.03,a=0.90 },
  inventory = { r=1.00,g=0.72,b=0.16,a=0.78 },
  logistics = { r=0.30,g=1.00,b=0.42,a=0.72 },
  repair = { r=0.25,g=0.85,b=1.00,a=0.72 },
  consecration = { r=0.52,g=1.00,b=0.38,a=0.76 },
  combat = { r=1.00,g=0.07,b=0.04,a=0.88 },
  idle = { r=0.30,g=1.00,b=0.30,a=0.45 },
}

local function classify(target, reason, opts)
  local text = lower((reason or "") .. " " .. (opts and opts.kind or ""))
  if text:find("combat",1,true) or text:find("attack",1,true) or text:find("point%-blank") then return "combat" end
  if text:find("repair",1,true) then return "repair" end
  if text:find("consecr",1,true) or text:find("sanct",1,true) or text:find("rite",1,true) then return "consecration" end
  if text:find("inventory",1,true) or text:find("container",1,true) or text:find("stash",1,true) or text:find("fetch",1,true) then return "inventory" end
  if text:find("logistic",1,true) or text:find("supply",1,true) then return "logistics" end
  if text:find("mine",1,true) or text:find("mining",1,true) or text:find("gather",1,true) or text:find("acquisition",1,true) then
    if valid(target) and target.type == "resource" then return "resource" end
    if valid(target) and (target.type == "tree" or target.type == "simple-entity" or target.type == "simple-entity-with-owner") then return "world_damage" end
    return "mining"
  end
  if valid(target) and target.type == "resource" then return "resource" end
  if valid(target) and (target.type == "tree" or target.type == "simple-entity" or target.type == "simple-entity-with-owner") then return "world_damage" end
  if valid(target) and (target.type == "container" or target.type == "logistic-container") then return "inventory" end
  return "idle"
end

local function origin(priest)
  local off = rawget(_G, "TECH_PRIEST_SCAN_ORIGIN_OFFSET") or {0,-1.45}
  if type(off) == "table" then return { entity=priest, offset=off } end
  return priest.position
end

local function target_pos(target)
  if valid(target) then return target.position end
  if type(target)=="table" and target.x and target.y then return target end
  if type(target)=="table" and target.position then return target.position end
  return nil
end

local function surface_of(priest, target)
  return (valid(priest) and priest.surface) or (valid(target) and target.surface) or nil
end

local function is_work_adjacent(pair, target, kind)
  if not (pair and valid(pair.priest) and valid(target)) then return true end
  if not (kind == "mining" or kind == "resource" or kind == "world_damage") then return true end
  local phase = lower(pair.dispatcher_phase or (pair.dispatcher_direct_0513 and pair.dispatcher_direct_0513.phase) or "")
  local mode = lower(pair.mode or "")
  local d2 = dist_sq(pair.priest.position, target.position) or 999999
  if d2 <= 2.25 and (phase == "work-target" or mode:find("working", 1, true) or mode:find("mining", 1, true)) then return true end
  return false
end

local function action_allows(pair, target, kind)
  if not (pair and valid(pair.priest) and valid(target)) then return true end
  local arb = rawget(_G, "TECH_PRIESTS_ACTION_STATE_ARBITER_0488")
  if arb and type(arb.allow_scan)=="function" and (kind == "inventory" or kind == "logistics" or kind == "mining" or kind == "resource" or kind == "world_damage") then
    local ok,res=pcall(arb.allow_scan,pair,target)
    if ok and res == false then return false end
  end
  return true
end

local function smoke_target(target, strong)
  if not valid(target) then return end
  local surface = target.surface
  local pos = target.position
  if not surface or not pos then return end
  local count = strong and 4 or 2
  for i=1,count do
    local ang=(now()*0.21)+(i*2.399)
    local dist=strong and 0.42 or 0.22
    pcall(function()
      surface.create_entity({ name=M.smoke_name, position={x=pos.x+math.cos(ang)*dist,y=pos.y+math.sin(ang)*dist} })
    end)
  end
end

local function maybe_smoke(pair, target, kind, strong)
  if not valid(target) then return end
  if not (kind == "resource" or kind == "world_damage" or kind == "mining") then return end
  local r=root()
  local key=tostring(valid(pair and pair.station) and pair.station.unit_number or "?") .. ":" .. tostring(target.unit_number or target.name or "target")
  if (r.smoke_cooldowns[key] or 0) > now() then return end
  r.smoke_cooldowns[key] = now() + M.smoke_interval
  smoke_target(target, strong ~= false)
end

function M.draw(pair, target, kind, opts)
  opts = opts or {}
  local priest = pair and pair.priest or opts.priest
  if not (root().enabled ~= false and valid(priest) and target) then return false end
  local pos = target_pos(target)
  local surface = surface_of(priest, target)
  if not (pos and surface and rendering and rendering.draw_line) then return false end
  kind = kind or classify(valid(target) and target or nil, opts.reason, opts)
  -- 0.1.539: final-loaded visual authority must preserve the movement-before-
  -- mining contract.  If the priest is merely walking to a resource/tree/rock,
  -- suppress mining-colored beams and smoke until the direct-acquisition executor
  -- has clamped movement and entered the adjacent work-target phase.
  if valid(target) and not is_work_adjacent(pair, target, kind) then stat("suppressed-remote-mining-visual-0539"); return false end
  if valid(target) and not action_allows(pair, target, kind) then stat("suppressed-by-arbiter"); return false end
  local color = opts.color or colors[kind] or colors.idle
  local width = opts.width or ((kind == "inventory" or kind == "idle") and 1 or M.default_width)
  local old = pair and pair.scan_beam_render_0529
  if old and old.valid then pcall(function() old.destroy() end) end
  local ok,line = pcall(function()
    return rendering.draw_line({ color=color, width=width, from=origin(priest), to=pos, surface=surface, time_to_live=opts.ttl or M.line_ttl, forces=priest.force and { priest.force } or nil })
  end)
  if ok and line and pair then pair.scan_beam_render_0529 = line end
  if valid(target) then
    pcall(function()
      rendering.draw_circle({ color={ r=color.r or 1, g=color.g or 0.4, b=color.b or 0.05, a=0.18 }, radius=opts.radius or 0.28, width=1, filled=true, target=target, surface=surface, time_to_live=opts.circle_ttl or M.circle_ttl, forces=priest.force and { priest.force } or nil })
    end)
  end
  maybe_smoke(pair, valid(target) and target or nil, kind, opts.strong_smoke)
  record(kind, pair, valid(target) and target or nil, opts.reason or "draw")
  return ok and line or true
end

local function apply_damage(priest, target, damage)
  if not (valid(priest) and valid(target)) then return false end
  if target.type == "item-entity" then return false end
  local d = math.max(1, tonumber(damage) or 5)
  local ok = pcall(function()
    if target.valid and target.type == "resource" then
      local amount = tonumber(target.amount) or 0
      if amount > 1 then target.amount = math.max(1, amount - math.max(1, math.floor(d * 0.35))) end
    elseif target.valid and target.health and target.health > 0 then
      target.damage(d, priest.force, "laser", priest)
    end
  end)
  return ok
end

function M.fire_laser(priest, target, damage, reason, color)
  if not (root().enabled ~= false and valid(priest) and valid(target)) then return false end
  local pair = pair_by_priest(priest)
  local arb = rawget(_G, "TECH_PRIESTS_ACTION_STATE_ARBITER_0488")
  if arb and type(arb.allow_laser)=="function" then
    local ok,res=pcall(arb.allow_laser, priest, target, reason)
    if ok and res == false then stat("laser-suppressed-by-arbiter"); return false end
  end
  local kind = classify(target, reason, { color=color })
  local ok_damage = apply_damage(priest, target, damage)
  M.draw(pair or { priest=priest }, target, kind, { reason=reason or "laser", color=color, ttl=7, circle_ttl=6, strong_smoke=(kind=="resource" or kind=="world_damage") })
  return ok_damage
end

function M.wrap_globals()
  if type(_G.draw_emergency_craft_scan_line)=="function" and not previous_scan_line then
    previous_scan_line = _G.draw_emergency_craft_scan_line
    _G.TECH_PRIESTS_0529_PRE_DRAW_SCAN_LINE = previous_scan_line
  end
  _G.draw_emergency_craft_scan_line = function(pair, target_entity)
    return M.draw(pair, target_entity, classify(target_entity, "acquisition-scan", { kind=(pair and pair.emergency_craft and pair.emergency_craft.current and pair.emergency_craft.current.kind) or nil }), { reason="draw_emergency_craft_scan_line", ttl=M.scan_ttl })
  end
  if type(_G.tech_priests_0312_fire_laser)=="function" and not previous_fire_laser then
    previous_fire_laser = _G.tech_priests_0312_fire_laser
    _G.TECH_PRIESTS_0529_PRE_0312_FIRE_LASER = previous_fire_laser
  end
  _G.tech_priests_0312_fire_laser = function(priest, target, damage, reason, color)
    return M.fire_laser(priest, target, damage, reason, color)
  end
  _G.tech_priests_0529_scan_beam = function(pair, target, kind, opts) return M.draw(pair, target, kind, opts) end
  _G.tech_priests_0539_remote_mining_visual_allowed = function(pair, target, kind) return is_work_adjacent(pair, target, kind or classify(target, "acquisition-scan", {})) end
  return true
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok,p=pcall(_G.selected_pair_for_player, player); if ok and p then return p end end
  local selected = player and player.selected
  if selected and selected.valid and storage and storage.tech_priests then
    local tp=storage.tech_priests
    return (tp.pairs_by_station and tp.pairs_by_station[selected.unit_number]) or (tp.pairs_by_priest and tp.pairs_by_priest[selected.unit_number])
  end
  return nil
end

function M.describe_pair(pair)
  if not pair then return "no selected pair" end
  local last=pair.scan_beam_0529_last or {}
  return "last_kind=" .. safe(last.kind) .. " target=" .. safe(last.target) .. " detail=" .. safe(last.detail)
end

local function install_command()
  if not commands then return end
  pcall(function() commands.remove_command("tp-scan-beams-0529") end)
  commands.add_command("tp-scan-beams-0529", "Tech Priests 0.1.529: unified scan/beam diagnostics. Params: on/off/all", function(event)
    local player=event and event.player_index and game.get_player(event.player_index) or nil
    local param=lower(event and event.parameter or "status")
    local r=root()
    if param=="on" then r.enabled=true end
    if param=="off" then r.enabled=false end
    local pair=player and selected_pair(player) or nil
    local msg="[tp-scan-beams-0529] enabled="..safe(r.enabled).." mining="..safe(r.stats.mining or 0).." resource="..safe(r.stats.resource or 0).." smoke="..safe(r.stats.world_damage or 0).." suppressed="..safe(r.stats["suppressed-by-arbiter"] or 0)
    if pair then msg=msg.."\n"..M.describe_pair(pair) end
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

local function wrap_diagnostics()
  local diag = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.scan_beam_0529_wrapped then return false end
  local prev=diag.pair_dump_lines
  diag.scan_beam_0529_wrapped=true
  diag.pair_dump_lines=function(...)
    local lines=prev(...); lines=type(lines)=="table" and lines or {}
    local r=root()
    lines[#lines+1]="PAIR-DUMP-0468 SCAN-BEAMS-0529 BEGIN enabled="..safe(r.enabled).." mining="..safe(r.stats.mining or 0).." resource="..safe(r.stats.resource or 0).." world_damage="..safe(r.stats.world_damage or 0).." inventory="..safe(r.stats.inventory or 0).." combat="..safe(r.stats.combat or 0)
    for _,pair in pairs(pair_map()) do if pair and pair.station and pair.priest then lines[#lines+1]="PAIR-DUMP-0468 scan-beams["..safe(pair.station_unit or (valid(pair.station) and pair.station.unit_number)).."] "..M.describe_pair(pair) end end
    for i=math.max(1,#r.recent-8),#r.recent do local ev=r.recent[i]; if ev then lines[#lines+1]="PAIR-DUMP-0468 scan-beams.recent["..tostring(i).."] tick="..safe(ev.tick).." kind="..safe(ev.kind).." station="..safe(ev.station).." priest="..safe(ev.priest).." target="..safe(ev.target).." "..safe(ev.detail) end end
    lines[#lines+1]="PAIR-DUMP-0468 SCAN-BEAMS-0529 END"
    return lines
  end
  return true
end

function M.install()
  root()
  M.wrap_globals()
  wrap_diagnostics()
  install_command()
  _G.TECH_PRIESTS_SCAN_BEAM_CONTROLLER_0529 = M
  if log then log("[Tech-Priests 0.1.529] unified scan/beam controller loaded; mining/world damage beams now share one smoky authority") end
  return true
end

return M
