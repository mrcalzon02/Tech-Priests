-- scripts/core/efficiency_economy_0576.lua
-- Tech Priests 0.1.576
--
-- Diagnostics-off + global budget scaffold + emergency-machine recipe claim
-- economy.  This module is a governor only.  It does not choose work, move a
-- priest, complete a recipe, mine, repair, or consecrate.  It clamps repeated
-- legacy churn and provides a visible reservation marker for machines a priest
-- has temporarily claimed for emergency production.

local M = {}
M.version = "0.1.576"
M.storage_key = "efficiency_economy_0576"
M.claim_ttl_ticks = 60 * 10
M.claim_icon_sprite = "virtual-signal/signal-T"
M.claim_icon_scale = 0.65
M.budget_defaults = {
  priests_per_tick = 8,
  scans_per_tick = 3,
  path_corrections_per_tick = 2,
  sanctity_checks_per_tick = 10,
  recipe_claims_per_tick = 4,
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function pair_key(pair) return tostring(station_unit(pair) or "?") .. ":" .. tostring(priest_unit(pair) or "?") end
local function entity_key(entity)
  if not valid(entity) then return nil end
  return tostring(entity.surface and entity.surface.index or "?") .. ":" .. tostring(entity.unit_number or (math.floor((entity.position.x or 0)*32) .. ":" .. math.floor((entity.position.y or 0)*32)))
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = {
      version = M.version,
      enabled = true,
      diagnostics_quiet_default = true,
      budget_enabled = true,
      machine_claims_enabled = true,
      micro_miner_runtime_doctrine_gui_enabled = false,
      budgets = {},
      budget_window = {},
      machine_claims = {},
      stats = {},
      recent = {},
    }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.diagnostics_quiet_default == nil then r.diagnostics_quiet_default = true end
  if r.budget_enabled == nil then r.budget_enabled = true end
  if r.machine_claims_enabled == nil then r.machine_claims_enabled = true end
  if r.micro_miner_runtime_doctrine_gui_enabled == nil then r.micro_miner_runtime_doctrine_gui_enabled = false end
  r.budgets = r.budgets or {}
  for k,v in pairs(M.budget_defaults) do if r.budgets[k] == nil then r.budgets[k] = v end end
  r.budget_window = r.budget_window or {}
  r.machine_claims = r.machine_claims or {}
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function remember(action, detail)
  local r=M.root(); r.recent[#r.recent+1]={tick=now(), action=tostring(action or "event"), detail=tostring(detail or "")}
  while #r.recent > 48 do table.remove(r.recent, 1) end
end

local function cleanup_claims(r)
  local t = now()
  for k,c in pairs(r.machine_claims or {}) do
    if type(c) ~= "table" or (tonumber(c.until_tick or 0) or 0) <= t or (c.entity and not valid(c.entity)) then
      if c and c.sprite and c.sprite.valid then pcall(function() c.sprite.destroy() end) end
      r.machine_claims[k] = nil
      stat("machine_claims_pruned")
    end
  end
end

local function draw_claim_icon(entity, claim)
  if not (valid(entity) and rendering and rendering.draw_sprite) then return nil end
  if claim.sprite and claim.sprite.valid then return claim.sprite end
  local ok,obj = pcall(function()
    return rendering.draw_sprite{
      sprite = M.claim_icon_sprite,
      surface = entity.surface,
      target = { entity = entity, offset = { 0, -0.85 } },
      x_scale = M.claim_icon_scale,
      y_scale = M.claim_icon_scale,
      tint = { r = 0.1, g = 1.0, b = 0.25, a = 0.82 },
      render_layer = "entity-info-icon",
      only_in_alt_mode = false,
    }
  end)
  if ok then return obj end
  return nil
end

function M.claim_machine_for_recipe(pair, entity, recipe, reason)
  local r = M.root()
  if r.enabled == false or r.machine_claims_enabled == false then return true, "claims-disabled" end
  if not valid(entity) then return false, "invalid-entity" end
  cleanup_claims(r)
  local key = entity_key(entity)
  if not key then return false, "no-key" end
  local owner = pair_key(pair)
  local claim = r.machine_claims[key]
  if claim and claim.owner and claim.owner ~= owner and (tonumber(claim.until_tick or 0) or 0) > now() then
    stat("recipe_claim_rejected_owned")
    return false, "reserved-by:" .. safe(claim.owner)
  end
  claim = claim or { entity = entity }
  claim.entity = entity
  claim.owner = owner
  claim.station = station_unit(pair)
  claim.priest = priest_unit(pair)
  claim.recipe = recipe
  claim.reason = tostring(reason or "recipe-claim")
  claim.until_tick = now() + M.claim_ttl_ticks
  claim.sprite = draw_claim_icon(entity, claim)
  r.machine_claims[key] = claim
  entity.tech_priests_recipe_claim_0576 = { owner=owner, recipe=recipe, until_tick=claim.until_tick }
  stat("recipe_claims")
  return true, "claimed"
end

function M.release_machine_claim(pair, entity, reason)
  local r=M.root(); local key=entity_key(entity); if not key then return false end
  local c=r.machine_claims[key]
  if not c then return false end
  if pair and c.owner ~= pair_key(pair) then return false end
  if c.sprite and c.sprite.valid then pcall(function() c.sprite.destroy() end) end
  r.machine_claims[key]=nil
  stat("recipe_claim_released")
  return true
end

function M.budget_take(bucket, amount)
  local r=M.root()
  if r.enabled == false or r.budget_enabled == false then return true end
  bucket = tostring(bucket or "generic")
  amount = tonumber(amount or 1) or 1
  local limit = tonumber(r.budgets[bucket] or M.budget_defaults[bucket] or 0) or 0
  if limit <= 0 then return true end
  local tick = now()
  local w = r.budget_window[bucket]
  if type(w) ~= "table" or w.tick ~= tick then w = { tick=tick, used=0 }; r.budget_window[bucket]=w end
  if (w.used or 0) + amount > limit then stat("budget_deferred_"..bucket); stat("budget_deferred_total"); return false end
  w.used = (w.used or 0) + amount
  stat("budget_used_"..bucket, amount)
  return true
end

local function install_diagnostics_quiet_default()
  local diag = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if diag and type(diag.root) ~= "function" and type(diag.write_pair_dump)=="function" then
    -- Existing command/settings path remains authoritative; this only nudges old
    -- saves/modules that have nil override but old true fallback behavior.
  end
  local r=M.root()
  if r.diagnostics_quiet_default then
    local droot = storage.tech_priests and storage.tech_priests.diagnostics_behavior_authority_0468
    if type(droot)=="table" and droot.enabled == nil then droot.enabled = false; stat("diagnostics_defaulted_off") end
  end
end

local function disable_micro_miner_doctrine_gui()
  -- Runtime doctrine popup is retired. The Micro-Miner is an assembling machine
  -- with a normal recipe selector; the extra doctrine GUI only confused the
  -- player and encouraged legacy recipe churn.
  if rawget(_G,"TECH_PRIESTS_0576_MICRO_MINER_GUI_PATCHED") then return false end
  _G.TECH_PRIESTS_0576_MICRO_MINER_GUI_PATCHED = true
  if type(_G.tech_priests_show_emergency_miner_gui_0183)=="function" then
    _G.TECH_PRIESTS_0576_PRE_SHOW_EMERGENCY_MINER_GUI = _G.tech_priests_show_emergency_miner_gui_0183
    _G.tech_priests_show_emergency_miner_gui_0183 = function(player, entity) return false end
  end
  if type(_G.tech_priests_on_gui_opened_0183)=="function" then
    _G.TECH_PRIESTS_0576_PRE_MINER_GUI_OPENED = _G.tech_priests_on_gui_opened_0183
    _G.tech_priests_on_gui_opened_0183 = function(event)
      local entity = event and event.entity
      if entity and entity.valid and entity.name == "tech-priests-emergency-miner" then return false end
      return _G.TECH_PRIESTS_0576_PRE_MINER_GUI_OPENED(event)
    end
  end
  remember("micro-miner-gui-retired", "normal assembling-machine recipe selector now owns output choice")
  return true
end

function M.service_cleanup()
  local r=M.root(); if r.enabled == false then return end
  cleanup_claims(r)
end

function M.install_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0576") end end)
  commands.add_command("tp-efficiency-economy-0576", "Tech Priests 0.1.576 diagnostics/budget/machine-reservation economy. Params: on/off/status/claims/quiet-on/quiet-off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = string.lower(tostring(event and event.parameter or "status"))
    local r=M.root()
    if param=="on" then r.enabled=true elseif param=="off" then r.enabled=false
    elseif param=="quiet-on" then r.diagnostics_quiet_default=true; local d=storage.tech_priests and storage.tech_priests.diagnostics_behavior_authority_0468; if type(d)=="table" then d.enabled=false end
    elseif param=="quiet-off" then r.diagnostics_quiet_default=false
    elseif param=="claims" then cleanup_claims(r) end
    if player and player.valid then
      local c=0; for _ in pairs(r.machine_claims or {}) do c=c+1 end
      player.print("[tp-efficiency-economy-0576] enabled="..safe(r.enabled).." quiet_default="..safe(r.diagnostics_quiet_default).." budget="..safe(r.budget_enabled).." claims="..safe(c).." rejected="..safe(r.stats.recipe_claim_rejected_owned or 0).." deferred="..safe(r.stats.budget_deferred_total or 0).." diag_off="..safe(r.stats.diagnostics_defaulted_off or 0))
    end
  end)
end

function M.install()
  M.root()
  install_diagnostics_quiet_default()
  disable_micro_miner_doctrine_gui()
  _G.tech_priests_0576_budget_take = M.budget_take
  _G.tech_priests_0576_claim_machine_for_recipe = M.claim_machine_for_recipe
  _G.tech_priests_0576_release_machine_claim = M.release_machine_claim
  M.install_commands()
  local R = rawget(_G,"TechPriestsRuntimeEventRegistry")
  if R and R.on_nth_tick then
    R.on_nth_tick(257, function() M.service_cleanup() end, { owner="efficiency_economy_0576", category="economy", priority="last", note="machine recipe claim cleanup and budget stats" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(257, function() M.service_cleanup() end)
  end
  if defines and defines.events then
    local function on_settings_changed(event)
      if event and (event.setting == "tech-priests-enable-emergency-diagnostics" or event.setting == "tech-priests-enable-full-priority-diagnostics") then install_diagnostics_quiet_default() end
    end
    if R and R.on_event then
      pcall(function() R.on_event(defines.events.on_runtime_mod_setting_changed, on_settings_changed, nil, { owner="efficiency_economy_0576", category="economy" }) end)
    elseif script and script.on_event then
      pcall(function() script.on_event(defines.events.on_runtime_mod_setting_changed, on_settings_changed) end)
    end
  end
  remember("install", "diagnostics quiet default + budget scaffold + machine recipe claims installed")
  if log then log("[Tech-Priests 0.1.576] diagnostics quiet default + budget scaffold + machine recipe claims installed") end
  return true
end

return M
