-- Final alignment and connector-visual pass for custom Space Age thrusters.
-- Loaded after prototypes.compatibility.space-age so all custom prototypes exist.

local HYDROGEN_THRUSTER = "hydrogen-thruster"
local THETAZINE_THRUSTER = "thetazine-thruster"
local VOID_FUSION_THRUSTER = "void-fusion-thruster"
local LARGE_VOID_FUSION_THRUSTER = "large-void-fusion-thruster"

local function vector_xy(value)
  if type(value) ~= "table" then return nil end
  local x = tonumber(value[1] or value.x)
  local y = tonumber(value[2] or value.y)
  if not x or not y then return nil end
  return { x, y }
end

local function first_pipe_position(fluid_box)
  local connections = type(fluid_box) == "table" and fluid_box.pipe_connections or nil
  local connection = type(connections) == "table" and connections[1] or nil
  if type(connection) ~= "table" then return nil end
  return vector_xy(connection.position)
end

local function enabled_visualisation_names(fluid_box)
  local names = {}
  local enabled = type(fluid_box) == "table" and fluid_box.enable_working_visualisations or nil
  if type(enabled) ~= "table" then return names end
  for _, name in pairs(enabled) do
    if type(name) == "string" then names[#names + 1] = name end
  end
  return names
end

local function translate_sprite_shifts(value, delta, seen)
  if type(value) ~= "table" or type(delta) ~= "table" then return end
  seen = seen or {}
  if seen[value] then return end
  seen[value] = true

  local shift = vector_xy(value.shift)
  if shift then
    value.shift = { shift[1] + delta[1], shift[2] + delta[2] }
  end

  for key, child in pairs(value) do
    if key ~= "shift" and type(child) == "table" then
      translate_sprite_shifts(child, delta, seen)
    end
  end
end

local function ensure_flag(entity, flag)
  if type(entity) ~= "table" or type(flag) ~= "string" then return end
  entity.flags = entity.flags or {}
  for _, existing in pairs(entity.flags) do
    if existing == flag then return end
  end
  entity.flags[#entity.flags + 1] = flag
end

local function set_single_input_port(fluid_box, filter, position, direction)
  if type(fluid_box) ~= "table" then return end
  fluid_box.filter = filter or fluid_box.filter
  fluid_box.production_type = "input"
  fluid_box.pipe_connections = {
    {
      flow_direction = "input",
      direction = direction,
      position = { position[1], position[2] }
    }
  }
end

local function copy_optional_graphics_field(target_graphics, source_graphics, field)
  if target_graphics[field] == nil and source_graphics[field] ~= nil then
    target_graphics[field] = table.deepcopy(source_graphics[field])
  end
end

local function restore_enabled_names(target_box, source_box)
  if type(target_box) ~= "table" or type(source_box) ~= "table" then return end
  if type(source_box.enable_working_visualisations) == "table" then
    target_box.enable_working_visualisations = table.deepcopy(source_box.enable_working_visualisations)
    target_box.draw_only_when_connected = true
  end
end

local function copy_vanilla_pipe_visuals(target, source, target_fuel_position, target_oxidizer_position)
  if not (target and source and target.graphics_set and source.graphics_set) then return false end

  local source_visuals = source.graphics_set.working_visualisations
  if type(source_visuals) ~= "table" then return false end

  local mappings = {}
  local function register(fluid_box, target_position)
    local source_position = first_pipe_position(fluid_box)
    if not source_position or not target_position then return end
    local delta = {
      target_position[1] - source_position[1],
      target_position[2] - source_position[2]
    }
    for _, name in pairs(enabled_visualisation_names(fluid_box)) do
      mappings[name] = delta
    end
  end

  register(source.fuel_fluid_box, target_fuel_position)
  register(source.oxidizer_fluid_box, target_oxidizer_position)

  local copied = {}
  local restored = {}
  for _, visual in pairs(source_visuals) do
    local name = type(visual) == "table" and visual.name or nil
    local delta = name and mappings[name] or nil
    if delta and not copied[name] then
      local clone = table.deepcopy(visual)
      translate_sprite_shifts(clone, delta)
      restored[#restored + 1] = clone
      copied[name] = true
    end
  end

  if #restored == 0 then return false end

  target.graphics_set.working_visualisations = restored
  copy_optional_graphics_field(target.graphics_set, source.graphics_set, "status_colors")
  copy_optional_graphics_field(target.graphics_set, source.graphics_set, "default_recipe_tint")
  copy_optional_graphics_field(target.graphics_set, source.graphics_set, "recipe_not_set_tint")
  restore_enabled_names(target.fuel_fluid_box, source.fuel_fluid_box)
  restore_enabled_names(target.oxidizer_fluid_box, source.oxidizer_fluid_box)
  return true
end

local function align_liquid_thrusters()
  local thrusters = data.raw.thruster or {}
  local vanilla = thrusters.thruster
  if not vanilla then return end

  local west = defines.direction.west
  local east = defines.direction.east

  local hydrogen = thrusters[HYDROGEN_THRUSTER]
  if hydrogen then
    local fuel_position = {-1.80, -1.00}
    local oxidizer_position = {1.80, -1.00}
    ensure_flag(hydrogen, "not-rotatable")
    set_single_input_port(hydrogen.fuel_fluid_box, "liquid-hydrogen", fuel_position, west)
    set_single_input_port(hydrogen.oxidizer_fluid_box, "liquid-oxygen", oxidizer_position, east)
    copy_vanilla_pipe_visuals(hydrogen, vanilla, fuel_position, oxidizer_position)
  end

  local thetazine = thrusters[THETAZINE_THRUSTER]
  if thetazine then
    local fuel_position = {-2.10, -1.00}
    local oxidizer_position = {2.10, -1.00}
    ensure_flag(thetazine, "not-rotatable")
    thetazine.collision_box = {{-2.15, -2.35}, {2.15, 2.35}}
    thetazine.selection_box = {{-2.25, -2.50}, {2.25, 2.50}}
    thetazine.drawing_box = {{-3.35, -3.30}, {3.35, 5.70}}
    thetazine.sticker_box = {{-2.15, -2.35}, {2.15, 2.35}}
    thetazine.hit_visualization_box = {{-2.25, -2.50}, {2.25, 2.50}}
    set_single_input_port(thetazine.fuel_fluid_box, "thetazine-fuel", fuel_position, west)
    set_single_input_port(thetazine.oxidizer_fluid_box, "water", oxidizer_position, east)
    copy_vanilla_pipe_visuals(thetazine, vanilla, fuel_position, oxidizer_position)
  end
end

local function align_sealed_void_thrusters()
  local thrusters = data.raw.thruster or {}
  local narrow = thrusters[VOID_FUSION_THRUSTER]
  if narrow then
    ensure_flag(narrow, "not-rotatable")
  end

  local large = thrusters[LARGE_VOID_FUSION_THRUSTER]
  if large then
    ensure_flag(large, "not-rotatable")
    large.drawing_box = {{-2.85, -2.95}, {2.85, 4.55}}
  end
end

align_liquid_thrusters()
align_sealed_void_thrusters()
