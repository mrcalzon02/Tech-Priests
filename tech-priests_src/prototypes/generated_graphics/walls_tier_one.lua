local manifest = require("prototypes.generated_graphics.walls_tier_one_manifest")

local function sprite(filename, geometry, shadow)
  return {
    filename = filename, priority = "extra-high", width = geometry[1], height = geometry[2],
    shift = geometry[3], scale = 0.5, draw_as_shadow = shadow,
  }
end

for branch, slots in pairs(manifest) do
  local root = "__tech-priests__/graphics/entity/walls-tier-one/" .. branch .. "/"
  local pictures = {}
  for name, entry in pairs(slots) do
    local count, geometry, shadow_geometry = table.unpack(entry)
    local body = sprite(root .. name .. ".png", geometry)
    if name == "water_connection_patch" or name == "gate_connection_patch" then
      local shadow = sprite(root .. name .. "-shadow.png", shadow_geometry, true)
      pictures[name] = {sheets = {body, shadow}}
    else
      body.variation_count, body.line_length = count, count
      if shadow_geometry then
        local shadow = sprite(root .. name .. "-shadow.png", shadow_geometry, true)
        shadow.repeat_count = count
        pictures[name] = {layers = {body, shadow}}
      else
        pictures[name] = body
      end
    end
  end
  for tier = 1, 3 do
    local name = "tech-priests-wall-" .. branch .. "-" .. tier
    local wall = data.raw.wall[name]
    wall.pictures = table.deepcopy(pictures)
    for _, prototype in ipairs({wall, data.raw.item[name], data.raw.technology[name]}) do
      prototype.icons = nil
      prototype.icon = root .. "icon.png"
      prototype.icon_size = 128
    end
  end
end
