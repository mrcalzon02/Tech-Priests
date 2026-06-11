-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 151-167
local function add_gui_sprite_0567(parent, sprite_name, width, height, tooltip)
  if not (parent and parent.valid and sprite_name) then return nil end
  local ok, elem = pcall(function()
    return parent.add{ type = "sprite", sprite = sprite_name, tooltip = tooltip }
  end)
  if not (ok and elem and elem.valid) then return nil end
  pcall(function() elem.style.width = width end)
  pcall(function() elem.style.height = height end)
  pcall(function() elem.style.minimal_width = width end)
  pcall(function() elem.style.minimal_height = height end)
  pcall(function() elem.style.maximal_width = width end)
  pcall(function() elem.style.maximal_height = height end)
  pcall(function() elem.style.stretch_image_to_widget_size = true end)
  pcall(function() elem.ignored_by_interaction = true end)
  return elem
end

