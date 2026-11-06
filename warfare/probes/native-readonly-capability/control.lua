-- Isolated Warfare interface census. Runtime reads only. No game state mutations.
-- Executed as a diagnostic Factorio --test-scenario, NEVER in shipping control.lua.
local PREFIX = "[WAR-OBS] "

local function clean(v)
  return tostring(v == nil and "nil" or v):gsub("[|\r\n]", " ")
end

local function emit(category, name, value)
  log(PREFIX .. clean(category) .. "|" .. clean(name) .. "|" .. clean(value))
end

local function prop(obj, key)
  if not obj then return nil end
  local ok, value = pcall(function() return obj[key] end)
  return ok and value or nil
end

local function keys(t)
  local arr = {}
  if t then
    for k in pairs(t) do
      if type(k) == "string" then arr[#arr + 1] = k end
    end
  end
  table.sort(arr)
  return arr
end

local function gun_names(p)
  local result = {}
  local guns = prop(p, "indexed_guns")
  if type(guns) == "table" then
    for _, gun in ipairs(guns) do
      result[#result + 1] = clean(prop(gun, "name"))
    end
  end
  return table.concat(result, ",")
end

local function observable_vehicle(name, proto)
  local typ = prop(proto, "type")
  if typ ~= "car" and typ ~= "spider-vehicle" and typ ~= "unit" then
    return false
  end
  if name == "car" or name == "tank" or name == "spidertron" then return true end
  if name:find("kj_", 1, true) or name:find("aai", 1, true)
      or name:find("tank", 1, true) or name:find("spider", 1, true)
      or name:find("dread", 1, true) then return true end
  return false
end

local function inspect()
  emit("STATUS", "phase", "runtime-readonly")
  local mods = script.active_mods
  for _, name in ipairs(keys(mods)) do
    if name == "base" or name == "space-age" or name == "quality"
       or name == "recycler" or name == "tech-priests"
       or name == "aai-programmable-vehicles" or name == "aai-signals"
       or name == "kj_vehicles" or name == "kj_servoskull"
       or name == "tanks_for_bob_fork"
       or name:find("kj_40k", 1, true) then
      emit("MOD", name, mods[name])
    end
  end
  assert(mods and mods["aai-programmable-vehicles"] == "0.9.2",
         "Expected installed AAI Programmable Vehicles 0.9.2")
  assert(mods and mods["kj_40kpredator"] ~= nil,
         "Missing KJ 40K Predator required for read-only census")

  local ri = remote and remote.interfaces
  assert(ri, "Factorio runtime remote.interfaces unavailable")
  local interface_names = keys(ri)
  emit("REMOTE", "registered_count", #interface_names)
  for _, interface_name in ipairs(interface_names) do
    local functions = keys(ri[interface_name])
    emit("INTERFACE", interface_name, table.concat(functions, ","))
  end

  local native = prototypes and prototypes.entity
  assert(native and native["tank"] and native["gun-turret"],
         "Required Factorio native prototype registry unavailable")
  local entities = keys(native)
  emit("PROTOTYPES", "total_entities", #entities)
  local vehicle_count, ai_unit_count = 0, 0
  local observed = 0
  for _, name in ipairs(entities) do
    local p = native[name]
    if observable_vehicle(name, p) then
      local typ = prop(p, "type")
      local guns = (typ == "car" or typ == "spider-vehicle") and gun_names(p) or ""
      local attack = prop(p, "attack_parameters")
      local range = prop(attack, "range")
      local ammo = prop(attack, "ammo_category")
      if type(ammo) == "table" then ammo = prop(ammo, "name") end
      emit("VEHICLE", name,
        clean(typ) .. ";guns=" .. guns ..
        ";attack_range=" .. clean(range) ..
        ";attack_ammo_category=" .. clean(ammo))
      vehicle_count = vehicle_count + 1
      if typ == "unit" then ai_unit_count = ai_unit_count + 1 end
    end
  end
  emit("COUNT", "vehicles_and_ai_units", vehicle_count)
  emit("COUNT", "candidate_ai_units", ai_unit_count)

  for _, name in ipairs({"gun-turret", "laser-turret",
       "flamethrower-turret", "artillery-turret",
       "tech-priest-small-arms-proxy"}) do
    local p = native[name]
    if p then
      local atk = prop(p, "attack_parameters")
      local category = prop(atk, "ammo_category")
      if type(category) == "table" then category = prop(category, "name") end
      emit("TURRET", name, clean(prop(p, "type")) ..
        ";range=" .. clean(prop(atk, "range")) ..
        ";ammo_category=" .. clean(category) ..
        ";rotates=" .. clean(prop(p, "rotation_speed")))
      observed = observed + 1
    else
      emit("TURRET", name, "NOT_PRESENT")
    end
  end

  -- Strictly inspect the schema, not any live player controller or possession.
  for _, name in ipairs({"selected_gun_index", "riding_state",
      "shooting_state", "commandable", "shooting_target", "circuit_connected_entities"}) do
    emit("SCHEMA", name, "engine-2.1-documented;not-invoked")
  end

  assert(vehicle_count >= 4, "Expected modded cars / AI vehicles not found")
  assert(observed >= 4, "Expected vanilla turret prototypes not found")
  emit("STATUS", "phase", "COMPLETE")
end

script.on_nth_tick(30, function()
  local ok, err = pcall(inspect)
  if not ok then
    emit("STATUS", "phase", "FAILED")
    emit("ERROR", "read_only_probe", err)
    script.finish_test(false)
    return
  end
  script.finish_test(true)
end)
