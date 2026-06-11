-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2015-2026
local function add_kv_0494(parent, key, value)
  local t = parent.add({ type = "table", column_count = 2 })
  apply_screen_table_style_0564(t)
  pcall(function() t.style.horizontally_stretchable = true end)
  local k = t.add({ type = "label", caption = dictator_green(tostring(key or "datum")) })
  style_terminal_label(k, 145)
  pcall(function() k.style.font = M.font_header end)
  local v = t.add({ type = "label", caption = dictator_green(tostring(value or "none")) })
  style_terminal_label(v, 230)
  return v
end

