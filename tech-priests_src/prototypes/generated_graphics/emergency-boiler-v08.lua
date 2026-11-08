-- Factorio 2.1 BoilerPictureSet; complete frames, no duplicate body overlays.
-- Load after the exact boiler prototype has been declared.
local target = assert(data.raw.boiler["tech-priests-emergency-boiler"], "Missing boiler tech-priests-emergency-boiler")
target.pictures = {
  north = { structure = { filename = "__tech-priests__/graphics/entity/emergency-boiler-v08-working.png", width = 256, height = 256, frame_count = 96, line_length = 12, x = 0, y = 0, animation_speed = 0.4, scale = 0.418750004524, shift = {2.49594452693e-08, -0.555428090615} } },
  east = { structure = { filename = "__tech-priests__/graphics/entity/emergency-boiler-v08-working.png", width = 256, height = 256, frame_count = 96, line_length = 12, x = 0, y = 2048, animation_speed = 0.4, scale = 0.592201857013, shift = {-0.207106669652, -0.489998669972} } },
  south = { structure = { filename = "__tech-priests__/graphics/entity/emergency-boiler-v08-working.png", width = 256, height = 256, frame_count = 96, line_length = 12, x = 0, y = 4096, animation_speed = 0.4, scale = 0.418750004524, shift = {2.49594452693e-08, -0.262534915768} } },
  west = { structure = { filename = "__tech-priests__/graphics/entity/emergency-boiler-v08-working.png", width = 256, height = 256, frame_count = 96, line_length = 12, x = 0, y = 6144, animation_speed = 0.4, scale = 0.592201857013, shift = {0.207106669652, -0.489998669972} } }
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
