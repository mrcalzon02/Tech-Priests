-- Tech Priests 0.1.447 consecration settings and decay audit.
-- This module intentionally changes no balance. It reports what the consecration
-- system is actually reading and which runtime settings still have live owners.

local M = {}

local CONSECRATION_AUDIT_SETTINGS_0353 = {
  { name = "tech-priests-base-max-sanctification", owner = "registry/state", reader = "get_base_sanctification_max", enforced_by = "record creation, normalization, research/config rebasing" },
  { name = "tech-priests-starting-sanctification", owner = "registry/state", reader = "get_base_sanctification_start", enforced_by = "record creation and normalization" },
  { name = "tech-priests-minimum-sanctification-percent", owner = "registry/state", reader = "get_minimum_sanctification_value_fraction", enforced_by = "normalization and per-operation decay floor" },
  { name = "tech-priests-min-degraded-max-sanctification", owner = "effects/state", reader = "get_min_degraded_sanctification_max", enforced_by = "maximum-sanctity damage clamp" },
  { name = "tech-priests-sacred-oil-restore-amount", owner = "api", reader = "get_sacred_oil_restore_amount", enforced_by = "oil application; litany/appeasement use fixed constants" },
  { name = "tech-priests-min-sanctification-decay-per-operation", owner = "decay", reader = "get_sanctification_decay_min_max", enforced_by = "operation completion decay roll" },
  { name = "tech-priests-max-sanctification-decay-per-operation", owner = "decay", reader = "get_sanctification_decay_min_max", enforced_by = "operation completion decay roll" },
  { name = "tech-priests-sanctification-decay-random-jitter-percent", owner = "decay", reader = "get_sanctification_decay_random_jitter_fraction", enforced_by = "operation completion decay jitter" },
  { name = "tech-priests-show-sanctification-decay-floaters", owner = "decay/ui", reader = "get_show_sanctification_decay_floaters", enforced_by = "per-operation floating activation text" },
  { name = "tech-priests-sanctification-decay-floater-min-amount", owner = "decay/ui", reader = "get_sanctification_decay_floater_min_amount", enforced_by = "per-operation floating activation text threshold" },
  { name = "tech-priests-physical-damage-threshold", owner = "effects", reader = "get_physical_damage_config", enforced_by = "apply_operation_degradation" },
  { name = "tech-priests-physical-damage-max-chance-percent", owner = "effects", reader = "get_physical_damage_config", enforced_by = "apply_operation_degradation" },
  { name = "tech-priests-physical-damage-min-health-percent", owner = "effects", reader = "get_physical_damage_config", enforced_by = "entity.damage amount range" },
  { name = "tech-priests-physical-damage-max-health-percent", owner = "effects", reader = "get_physical_damage_config", enforced_by = "entity.damage amount range" },
  { name = "tech-priests-max-sanctification-damage-threshold", owner = "effects", reader = "get_max_sanctification_degradation_config", enforced_by = "max-sanctification capacity damage" },
  { name = "tech-priests-max-sanctification-damage-max-chance-percent", owner = "effects", reader = "get_max_sanctification_degradation_config", enforced_by = "max-sanctification capacity damage" },
  { name = "tech-priests-max-sanctification-damage-min-amount", owner = "effects", reader = "get_max_sanctification_degradation_config", enforced_by = "max-sanctification capacity damage amount range" },
  { name = "tech-priests-max-sanctification-damage-max-amount", owner = "effects", reader = "get_max_sanctification_degradation_config", enforced_by = "max-sanctification capacity damage amount range" }
}

local function setting_value_text(name)
  if not (settings and settings.global and settings.global[name]) then return "<missing>" end
  local ok, value = pcall(function() return settings.global[name].value end)
  if not ok then return "<error>" end
  return tostring(value)
end

local function selected_entity_for_player(player)
  if not (player and player.valid) then return nil end
  if player.selected and player.selected.valid then return player.selected end
  return nil
end

local function progress_sensor_for_entity(entity)
  if not (entity and entity.valid) then return "none", "invalid entity" end
  if is_sanctification_distance_operated_entity and is_sanctification_distance_operated_entity(entity) then
    return "distance", "vehicle-like entity decays per travelled distance"
  end
  local ok, progress = pcall(function() return entity.crafting_progress end)
  if ok and progress ~= nil then
    return "crafting-progress", "decays when crafting_progress wraps after a completed operation"
  end
  local ok_recipe, recipe = pcall(function() return entity.get_recipe and entity.get_recipe() or nil end)
  if ok_recipe and recipe then
    return "recipe-without-progress", "recipe exists, but crafting_progress was not readable"
  end
  return "passive/unsupported", "no crafting_progress sensor; use is currently not counted as an operation"
end

local function audit_selected_entity(player, lines)
  local entity = selected_entity_for_player(player)
  if not entity then
    table.insert(lines, "selected: <none>")
    return
  end
  table.insert(lines, "selected: " .. entity.name .. " type=" .. tostring(entity.type) .. " unit=" .. tostring(entity.unit_number or "none"))
  local target = is_consecration_target and is_consecration_target(entity) or false
  table.insert(lines, "consecration-target: " .. tostring(target))
  local sensor, sensor_note = progress_sensor_for_entity(entity)
  table.insert(lines, "operation-sensor: " .. sensor .. " — " .. sensor_note)
  if target and get_consecration_record then
    local record = get_consecration_record(entity)
    if record then
      local ratio = get_sanctification_ratio and get_sanctification_ratio(record) or 0
      table.insert(lines, string.format("sanctity: %.2f / %.2f (%.1f%%)", tonumber(record.sanctification) or 0, tonumber(record.max_sanctification) or 0, ratio * 100))
      table.insert(lines, "last_progress: " .. tostring(record.last_progress) .. " waste_jammed=" .. tostring(record.waste_jammed == true))
    end
  end
end

local function add_live_config(lines)
  local min_decay, max_decay = get_sanctification_decay_min_max()
  local pth, pchance, pmin, pmax = get_physical_damage_config()
  local mth, mchance, mmin, mmax = get_max_sanctification_degradation_config()
  local jitter_percent = (get_sanctification_decay_random_jitter_fraction and get_sanctification_decay_random_jitter_fraction() or 0) * 100
  local floaters = get_show_sanctification_decay_floaters and get_show_sanctification_decay_floaters() or false
  local floater_min = get_sanctification_decay_floater_min_amount and get_sanctification_decay_floater_min_amount() or 0
  table.insert(lines, string.format("decay per operation: %.3f to %.3f + jitter %.1f%%; floaters=%s min=%.3f", min_decay or 0, max_decay or 0, jitter_percent, tostring(floaters), floater_min))
  table.insert(lines, string.format("physical damage: threshold=%.3f chance<=%.1f%% health=%.3f%%..%.3f%%", pth or 0, (pchance or 0) * 100, (pmin or 0) * 100, (pmax or 0) * 100))
  table.insert(lines, string.format("max-sanctity damage: threshold=%.3f chance<=%.1f%% amount=%.3f..%.3f", mth or 0, (mchance or 0) * 100, mmin or 0, mmax or 0))
  table.insert(lines, string.format("base/start/min floor/min degraded max/oil: %.3f / %.3f / %.1f%% / %.3f / %.3f", get_base_sanctification_max(), get_base_sanctification_start(), get_minimum_sanctification_value_fraction() * 100, get_min_degraded_sanctification_max(), get_sacred_oil_restore_amount()))
end

function M.build_report(player)
  local lines = {}
  table.insert(lines, "[Tech Priests 0.1.447] Consecration settings/attachment audit")
  add_live_config(lines)
  audit_selected_entity(player, lines)
  table.insert(lines, "live consecration settings:")
  for _, spec in ipairs(CONSECRATION_AUDIT_SETTINGS_0353) do
    table.insert(lines, " - " .. spec.name .. "=" .. setting_value_text(spec.name) .. " -> " .. spec.owner .. "/" .. spec.reader)
  end
  return lines
end

function M.print_report(player)
  local lines = M.build_report(player)
  if player and player.valid then
    for _, line in ipairs(lines) do player.print(line) end
  else
    for _, line in ipairs(lines) do log(line) end
  end
  return lines
end


local function safe_write_file_0462(filename, data, append, for_player)
  if helpers then
    local ok_get, writer = pcall(function() return helpers.write_file end)
    if ok_get and writer then
      local ok_write = pcall(function() writer(filename, data, append or false, for_player) end)
      if ok_write then return true end
    end
  end
  if game then
    local ok_get, writer = pcall(function() return game.write_file end)
    if ok_get and writer then
      local ok_write = pcall(function() writer(filename, data, append or false, for_player) end)
      if ok_write then return true end
    end
  end
  return false
end

function M.write_report(player)
  local lines = M.build_report(player)
  local text = table.concat(lines, "\n") .. "\n"
  local file_name = "tech-priests-consecration-settings-audit-0447.txt"
  local ok = safe_write_file_0462(file_name, text, false)
  if player and player.valid then
    if ok then player.print("Wrote script-output/" .. file_name)
    else player.print("Failed to write script-output/" .. file_name .. "; file writer unavailable") end
  end
  return text
end

if commands and commands.add_command then
  pcall(function() commands.remove_command("tp-consecration-audit-0353") end)
  commands.add_command("tp-consecration-audit-0353", "Audit live consecration decay/damage settings and selected target operation sensor. Use 'write' to emit script-output report.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local parameter = event and event.parameter or ""
    if parameter == "write" then
      M.write_report(player)
    else
      M.print_report(player)
    end
  end)

  pcall(function() commands.remove_command("tp-consecration-settings-0447") end)
  commands.add_command("tp-consecration-settings-0447", "Tech Priests 0.1.447: audit consecration setting attachment, jitter, floaters, selected-machine sensor. Use 'write' to emit script-output report.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local parameter = event and event.parameter or ""
    if parameter == "write" then
      M.write_report(player)
    else
      M.print_report(player)
    end
  end)
end

_G.TECH_PRIESTS_CONSECRATION_AUDIT_SETTINGS_0353 = CONSECRATION_AUDIT_SETTINGS_0353
return { name = 'scripts.core.consecration.audit', version = '0.1.447', build_report = M.build_report, print_report = M.print_report, write_report = M.write_report }
