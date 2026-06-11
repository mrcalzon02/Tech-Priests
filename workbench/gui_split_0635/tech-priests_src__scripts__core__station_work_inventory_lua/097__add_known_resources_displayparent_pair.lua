-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1503-1560
local function add_known_resources_display(parent, pair)
  local cat = catalog_for_pair(pair, true)
  if not cat then
    add_label(parent, "Auspex ledger awaits first sweep; no local resource catechism has been sealed yet.")
    return
  end
  add_summary_table_0521(parent, "Auspex Command Seal", {
    { "Station seal", tostring(cat.station_backer_name or cat.station_name or cat.station_unit or station_label(pair)) },
    { "Surface", tostring(cat.surface or (valid(pair.station) and pair.station.surface and pair.station.surface.name) or "unknown") },
    { "Sweep radius", tostring(math.floor(tonumber(cat.radius) or 0)) .. " tiles" },
    { "Last rite tick", tostring(cat.tick or 0) },
    { "Doctrine", "Known storage is a fetch source; it does not count as station inventory until a priest physically retrieves it." },
  })
  parent.add({ type = "button", name = "tech_priests_workstate_refresh_known_resources_0467", caption = "Renew Auspex Sweep" })
  add_catalog_section(parent, "Active resource omens", cat.resources, 10, "no active ore/fluid resources cataloged")
  add_catalog_section(parent, "Harvestable salvage omens", cat.mineable_products, 10, "no mineable rocks/trees/products cataloged")
  add_catalog_section(parent, "Station-bound tithe stock", cat.storage_items, 12, "no station-bound stored items cataloged")
  add_label(parent, "Subordinate command lattice")
  if #(cat.subordinate_stations or {}) == 0 then
    add_label(parent, "  no lower-rank subordinate stations sealed into the lattice")
  else
    for i, sub in ipairs(cat.subordinate_stations) do
      if i > 12 then add_label(parent, "  ..." .. tostring(#cat.subordinate_stations - 12) .. " more subordinate stations"); break end
      add_label(parent, "  rank " .. tostring(sub.rank) .. " | " .. tostring(sub.backer_name or sub.name or sub.unit) .. " | mode " .. tostring(sub.mode or "idle") .. " | emergency " .. tostring(sub.emergency))
    end
  end
end


add_table_cell_0521 = function(table_el, value, width, header)
  local label = table_el.add({ type = "label", caption = dictator_green(tostring(value or "—")) })
  pcall(function() label.style.single_line = false end)
  if width then
    pcall(function() label.style.maximal_width = width end)
    pcall(function() label.style.minimal_width = math.min(width, 260) end)
  end
  if header then
    pcall(function() label.style.font = M.font_header end)
    pcall(function() label.style.font_color = { r = 0.74, g = 1.00, b = 0.62 } end)
  else
    pcall(function() label.style.font_color = { r = 0.20, g = 1.00, b = 0.22 } end)
  end
  return label
end

add_summary_table_0521 = function(parent, caption, rows)
  local frame = parent.add({ type = "frame", caption = caption, direction = "vertical" })
  apply_display_frame_style_0540(frame)
  local t = frame.add({ type = "table", column_count = 2 })
  apply_screen_table_style_0564(t)
  pcall(function() t.style.horizontally_stretchable = true end)
  for _, row in ipairs(rows or {}) do
    add_table_cell_0521(t, row[1] or "datum", 180, true)
    add_table_cell_0521(t, row[2] or "—", 360, false)
  end
  return frame
end

