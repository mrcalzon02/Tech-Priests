-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2279-2297
local function style_fixed_flow_0536(flow, width, height, direction)
  if not (flow and flow.valid) then return end
  if direction then pcall(function() flow.direction = direction end) end
  pcall(function() flow.style.padding = 0 end)
  pcall(function() flow.style.margin = 0 end)
  pcall(function() flow.style.horizontal_spacing = 0 end)
  pcall(function() flow.style.vertical_spacing = 0 end)
  if width then
    pcall(function() flow.style.width = width end)
    pcall(function() flow.style.minimal_width = width end)
    pcall(function() flow.style.maximal_width = width end)
  end
  if height then
    pcall(function() flow.style.height = height end)
    pcall(function() flow.style.minimal_height = height end)
    pcall(function() flow.style.maximal_height = height end)
  end
end

