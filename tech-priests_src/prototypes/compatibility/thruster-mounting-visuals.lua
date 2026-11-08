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

local function pipe_connection_for_direction(fluid_box, direction)
  local connections = type(fluid_box) == "table" and fluid_box.pipe_connections or nil
  for _, connection in pairs(connections or {}) do
    if connection.direction == direction and vector_xy(connection.position) then
      return connection
    end
  end
end

local function enabled_visualisation_names(connection)
  local names = {}
  -- Native gates belong to each PipeConnectionDefinition, not the FluidBox.
  local enabled = type(connection) == "table" and connection.enable_working_visualisations or nil
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

local function fit_platform_edge_rules(thruster, vanilla, supported_front_rows)
  if not (thruster and vanilla and vanilla.tile_buildability_rules) then return end
  local rules = table.deepcopy(vanilla.tile_buildability_rules)
  local support, exhaust
  for _, rule in pairs(rules) do
    local layers = rule.required_tiles and rule.required_tiles.layers
    if layers and layers.ground_tile then support = rule end
    if layers and layers.empty_space then exhaust = rule end
  end
  if not (support and exhaust) then return end
  local half_width = thruster.tile_width / 2
  local half_height = thruster.tile_height / 2
  -- Keep the native supported-body / clear-aft doctrine, fitted to this
  -- body's real grid. The 4x5 donor areas contradict an integer 4x4 origin
  -- and intersect the lower body of the 1x9 spine.
  support.area = {{-half_width + 0.2, -half_height + 0.2},
                  {half_width - 0.2, half_height - 0.2}}
  -- Authored liquid mounts, their fixed pipe cells and the required entity
  -- origin are on three fore rows. Keep those supported; the vessel/bell
  -- overhang a native empty-space notch rather than solid foundation.
  -- Sealed bodies retain the existing full-body rule until modeled.
  local clear_start = half_height
  if supported_front_rows then
    clear_start = -half_height + supported_front_rows
    support.area[2][2] = clear_start - 0.2
  end
  local far_edge = exhaust.area[2][2]
  exhaust.area = {{-half_width + 0.2, clear_start + 0.2},
                  {half_width - 0.2, far_edge}}
  thruster.tile_buildability_rules = rules
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

local function copy_vanilla_pipe_visuals(target, source, target_fuel_position, target_oxidizer_position)
  if not (target and source and target.graphics_set and source.graphics_set) then return false end

  local source_visuals = source.graphics_set.working_visualisations
  if type(source_visuals) ~= "table" then return false end

  local mappings = {}
  local function register(source_box, target_box, target_position)
    local target_connection = target_box and target_box.pipe_connections and target_box.pipe_connections[1]
    if not target_connection then return end
    local source_connection = pipe_connection_for_direction(source_box, target_connection.direction)
    local source_position = source_connection and vector_xy(source_connection.position)
    if not source_position or not target_position then return end
    local delta = {
      target_position[1] - source_position[1],
      target_position[2] - source_position[2]
    }
    for _, name in pairs(enabled_visualisation_names(source_connection)) do
      mappings[name] = { delta = delta, connection = target_connection }
    end
  end

  register(source.fuel_fluid_box, target.fuel_fluid_box, target_fuel_position)
  register(source.oxidizer_fluid_box, target.oxidizer_fluid_box, target_oxidizer_position)

  local copied = {}
  local restored = {}
  for _, visual in pairs(source_visuals) do
    local name = type(visual) == "table" and visual.name or nil
    local mapping = name and mappings[name] or nil
    if mapping and not copied[name] then
      local clone = table.deepcopy(visual)
      translate_sprite_shifts(clone, mapping.delta)
      restored[#restored + 1] = clone
      copied[name] = true
      local connection = mapping.connection
      connection.enable_working_visualisations = connection.enable_working_visualisations or {}
      connection.enable_working_visualisations[#connection.enable_working_visualisations + 1] = name
    end
  end

  if #restored == 0 then return false end

  target.graphics_set.working_visualisations = restored
  copy_optional_graphics_field(target.graphics_set, source.graphics_set, "status_colors")
  copy_optional_graphics_field(target.graphics_set, source.graphics_set, "default_recipe_tint")
  copy_optional_graphics_field(target.graphics_set, source.graphics_set, "recipe_not_set_tint")
  target.fuel_fluid_box.draw_only_when_connected = true
  target.oxidizer_fluid_box.draw_only_when_connected = true
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
    -- The even 4x4 body has an integer origin: half-tile socket centres
    -- meet normal pipe centres exactly, rather than drawing half a row high.
    local fuel_position = {-1.50, -0.50}
    local oxidizer_position = {1.50, -0.50}
    ensure_flag(hydrogen, "not-rotatable")
    fit_platform_edge_rules(hydrogen, vanilla, 3)
    set_single_input_port(hydrogen.fuel_fluid_box, "liquid-hydrogen", fuel_position, west)
    set_single_input_port(hydrogen.oxidizer_fluid_box, "liquid-oxygen", oxidizer_position, east)
    hydrogen.collision_box = {{-1.85, -1.85}, {1.85, 0}}
    copy_vanilla_pipe_visuals(hydrogen, vanilla, fuel_position, oxidizer_position)
  end

  local thetazine = thrusters[THETAZINE_THRUSTER]
  if thetazine then
    -- The odd 5x5 body has a half-tile origin, so integer local sockets
    -- place the adjacent pipe centres on the same normal half-tile grid.
    local fuel_position = {-2.00, -1.00}
    local oxidizer_position = {2.00, -1.00}
    ensure_flag(thetazine, "not-rotatable")
    fit_platform_edge_rules(thetazine, vanilla, 3)
    thetazine.collision_box = {{-2.15, -2.35}, {2.15, 2.35}}
    thetazine.selection_box = {{-2.25, -2.50}, {2.25, 2.50}}
    thetazine.drawing_box = {{-3.35, -3.30}, {3.35, 5.70}}
    thetazine.sticker_box = {{-2.15, -2.35}, {2.15, 2.35}}
    thetazine.hit_visualization_box = {{-2.25, -2.50}, {2.25, 2.50}}
    set_single_input_port(thetazine.fuel_fluid_box, "thetazine-fuel", fuel_position, west)
    set_single_input_port(thetazine.oxidizer_fluid_box, "water", oxidizer_position, east)
    thetazine.collision_box = {{-2.15, -2.35}, {2.15, 0}}
    copy_vanilla_pipe_visuals(thetazine, vanilla, fuel_position, oxidizer_position)
  end
end

local function align_sealed_void_thrusters()
  local thrusters = data.raw.thruster or {}
  local vanilla = thrusters.thruster
  local narrow = thrusters[VOID_FUSION_THRUSTER]
  if narrow then
    ensure_flag(narrow, "not-rotatable")
    fit_platform_edge_rules(narrow, vanilla)
  end

  local large = thrusters[LARGE_VOID_FUSION_THRUSTER]
  if large then
    ensure_flag(large, "not-rotatable")
    fit_platform_edge_rules(large, vanilla)
    large.drawing_box = {{-2.85, -2.95}, {2.85, 4.55}}
  end
end

align_liquid_thrusters()
align_sealed_void_thrusters()

-- A static service cradle is independent of the body and working glow.
-- ThrusterGraphicsSet in native 2.1 exposes WorkingVisualisation layers,
-- not the old integration_patch field. Reference the installed vanilla
-- machinery without copying Wube PNGs into this mod.
local function add_platform_service_underlay()
  local thrusters = data.raw.thruster or {}
  local vanilla = thrusters.thruster
  local patch = vanilla and vanilla.graphics_set and vanilla.graphics_set.integration_patch
  if not patch then return end
  for _, name in ipairs({HYDROGEN_THRUSTER, THETAZINE_THRUSTER}) do
    local p = thrusters[name]
    if p and p.graphics_set then
      local animation = table.deepcopy(patch)
      local donor_height = vanilla.tile_height or math.ceil(
        vanilla.collision_box[2][2] - vanilla.collision_box[1][2])
      translate_sprite_shifts(animation, {0, (donor_height - p.tile_height) / 2})
      local visual = {name="platform-service-underlay", always_draw=true,
        render_layer="floor", animation=animation}
      p.graphics_set.working_visualisations = p.graphics_set.working_visualisations or {}
      local replaced = false
      for i, existing in ipairs(p.graphics_set.working_visualisations) do
        if existing.name == visual.name then
          p.graphics_set.working_visualisations[i] = visual
          replaced = true
          break
        end
      end
      if not replaced then table.insert(p.graphics_set.working_visualisations, visual) end
    end
  end
end
add_platform_service_underlay()
