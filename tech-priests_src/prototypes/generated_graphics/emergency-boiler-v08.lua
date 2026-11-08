-- Factorio 2.1 BoilerPictureSet; static cold body and conditional working activity.
-- Load after the exact boiler prototype has been declared.
local target = assert(data.raw.boiler["tech-priests-emergency-boiler"], "Missing boiler tech-priests-emergency-boiler")
target.fire_flicker_enabled = false
target.energy_source.smoke = nil -- Steam is authored at the model nozzle.
target.pictures = {
  north = { structure = { filename = "__tech-priests__/graphics/entity/emergency-boiler-v08-cold.png", width = 256, height = 256, frame_count = 1, line_length = 1, x = 0, y = 0, animation_speed = 0.4, scale = 0.418750004524, shift = {2.49594452693e-08, -0.555428090615} }, fire = { filename = "__tech-priests__/graphics/entity/emergency-boiler-v08-activity.png", width = 256, height = 256, frame_count = 96, line_length = 12, x = 0, y = 0, animation_speed = 0.4, scale = 0.418750004524, shift = {2.49594452693e-08, -0.555428090615} } },
  east = { structure = { filename = "__tech-priests__/graphics/entity/emergency-boiler-v08-cold.png", width = 256, height = 256, frame_count = 1, line_length = 1, x = 0, y = 256, animation_speed = 0.4, scale = 0.592201857013, shift = {-0.207106669652, -0.489998669972} }, fire = { filename = "__tech-priests__/graphics/entity/emergency-boiler-v08-activity.png", width = 256, height = 256, frame_count = 96, line_length = 12, x = 0, y = 2048, animation_speed = 0.4, scale = 0.592201857013, shift = {-0.207106669652, -0.489998669972} } },
  south = { structure = { filename = "__tech-priests__/graphics/entity/emergency-boiler-v08-cold.png", width = 256, height = 256, frame_count = 1, line_length = 1, x = 0, y = 512, animation_speed = 0.4, scale = 0.418750004524, shift = {2.49594452693e-08, -0.262534915768} }, fire = { filename = "__tech-priests__/graphics/entity/emergency-boiler-v08-activity.png", width = 256, height = 256, frame_count = 96, line_length = 12, x = 0, y = 4096, animation_speed = 0.4, scale = 0.418750004524, shift = {2.49594452693e-08, -0.262534915768} } },
  west = { structure = { filename = "__tech-priests__/graphics/entity/emergency-boiler-v08-cold.png", width = 256, height = 256, frame_count = 1, line_length = 1, x = 0, y = 768, animation_speed = 0.4, scale = 0.592201857013, shift = {0.207106669652, -0.489998669972} }, fire = { filename = "__tech-priests__/graphics/entity/emergency-boiler-v08-activity.png", width = 256, height = 256, frame_count = 96, line_length = 12, x = 0, y = 6144, animation_speed = 0.4, scale = 0.592201857013, shift = {0.207106669652, -0.489998669972} } }
}
target.water_reflection = nil
-- Match the authored 2x2 body and rear-row circular pipe mouths.
target.collision_box = {{-0.85, -0.85}, {0.85, 0.85}}
target.selection_box = {{-1, -1}, {1, 1}}
target.fluid_box.pipe_connections = {{flow_direction="input-output", direction=defines.direction.west, position={-0.5, -0.5}}}
target.output_fluid_box.pipe_connections = {{flow_direction="output", direction=defines.direction.east, position={0.5, -0.5}}}
local icon = "__tech-priests__/graphics/icons/emergency-boiler-v08.png"
target.icon, target.icons, target.icon_size = icon, nil, 64
for _, kind in ipairs({"item", "recipe"}) do
  local prototype = (data.raw[kind] or {})["tech-priests-emergency-boiler"]
  if prototype then prototype.icon, prototype.icons, prototype.icon_size = icon, nil, 64 end
end

-- Native connector case mounted on the measured fixed cage-top junction.
local circuit_registration = {
  {main_offset={0.667127104978,-1.20232032538},shadow_offset={0.667127104978,-0.606100041727},scale=0.500000005402},
  {main_offset={1.09631860052,0.183945518438},shadow_offset={1.09631860052,1.02712821779},scale=0.707106694941},
  {main_offset={-0.667127055059,0.393998292691},shadow_offset={-0.667127055059,0.990218576348},scale=0.500000005402},
  {main_offset={-1.09631860052,-1.15030846445},shadow_offset={-1.09631860052,-0.307125765088},scale=0.707106694941}
}
local function xy(v) return v.x or v[1], v.y or v[2] end
local function remap(v, origin, destination, factor)
  local x,y=xy(v);local ox,oy=xy(origin)
  return {destination[1]+(x-ox)*factor,destination[2]+(y-oy)*factor}
end
assert(target.circuit_connector and #target.circuit_connector==4, 'Boiler requires native four-way circuit definitions')
for i,registration in ipairs(circuit_registration) do
  local connector=target.circuit_connector[i]
  local origin=table.deepcopy(connector.sprites.connector_main.shift or {0,0})
  for _,sprite in pairs(connector.sprites) do
    if type(sprite)=='table' and sprite.filename then
      sprite.shift=remap(sprite.shift or {0,0},origin,sprite.draw_as_shadow and registration.shadow_offset or registration.main_offset,registration.scale)
      sprite.scale=(sprite.scale or 1)*registration.scale
    end
  end
  for _,key in ipairs({'blue_led_light_offset','red_green_led_light_offset'}) do
    if connector.sprites[key] then connector.sprites[key]=remap(connector.sprites[key],origin,registration.main_offset,registration.scale) end
  end
  connector.sprites.connector_main.tint={r=0.5,g=0.38,b=0.24,a=1}
  for kind,points in pairs(connector.points) do
    local destination=kind=='shadow' and registration.shadow_offset or registration.main_offset
    for color,point in pairs(points) do points[color]=remap(point,origin,destination,registration.scale) end
  end
end
