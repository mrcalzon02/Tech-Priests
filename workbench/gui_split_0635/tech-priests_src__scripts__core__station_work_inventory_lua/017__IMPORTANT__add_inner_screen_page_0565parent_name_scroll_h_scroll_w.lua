-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 145-161
local function add_inner_screen_page_0565(parent, name, scroll_h, scroll_w)
  local screen = parent.add({ type = "frame", name = tostring(name or "tech_priests_inner_screen") .. "_screen_0565", direction = "vertical" })
  apply_display_frame_style_0540(screen)
  pcall(function() screen.style.horizontally_stretchable = true end)
  pcall(function() screen.style.vertically_stretchable = true end)
  pcall(function() screen.style.minimal_height = scroll_h end)
  pcall(function() screen.style.maximal_height = scroll_h end)
  pcall(function() screen.style.minimal_width = math.max(560, scroll_w or 560) end)
  local scroll = screen.add({ type = "scroll-pane", name = name, direction = "vertical" })
  apply_screen_scroll_style_0564(scroll)
  pcall(function() scroll.style.minimal_height = math.max(120, (scroll_h or 400) - 18) end)
  pcall(function() scroll.style.maximal_height = math.max(120, (scroll_h or 400) - 18) end)
  pcall(function() scroll.style.minimal_width = math.max(540, (scroll_w or 560) - 20) end)
  pcall(function() scroll.style.horizontally_stretchable = true end)
  return scroll, screen
end

