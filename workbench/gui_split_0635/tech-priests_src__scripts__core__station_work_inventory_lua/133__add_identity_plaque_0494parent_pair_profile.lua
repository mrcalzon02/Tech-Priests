-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2060-2093
local function add_identity_plaque_0494(parent, pair, profile)
  local plaque = add_plaque_0494(parent, "Identity Reliquary")
  local top = plaque.add({ type = "flow", direction = "horizontal" })
  pcall(function() top.style.vertical_align = "center" end)
  local portrait = portrait_record_0520(pair)
  local portrait_box = top.add({ type = "frame", direction = "vertical" })
  pcall(function() portrait_box.style.padding = 2 end)
  add_gui_sprite_0482(portrait_box, portrait and portrait.sprite or "tech-priests-gui-mechanical-skull-gear-emblem", 96, 96, "Assigned priest portrait cell")
  local txt = top.add({ type = "flow", direction = "vertical" })
  style_box_width_0526(txt, 270, 300)
  add_gui_sprite_0482(txt, "tech-priests-gui-mechanical-skull-gear-emblem", 24, 24, "Priest identity seal")
  local station_line = add_label(txt, "Station seal: " .. station_label(pair) .. " | rank " .. tostring(station_rank(pair)))
  style_terminal_label(station_line, 270)
  local priest_line = add_label(txt, "Priest: " .. priest_label(pair) .. " | mode " .. tostring(pair and pair.mode or "idle"))
  style_terminal_label(priest_line, 270)
  if portrait then
    add_kv_0494(plaque, "Portrait seal", tostring(portrait.portrait_id or "unassigned"))
    add_kv_0494(plaque, "Portrait source", tostring(portrait.sheet_label or portrait.sheet or "unknown sheet") .. " cell " .. tostring(portrait.index or "?"))
  end
  if profile then
    add_kv_0494(plaque, "Noospheric ID", tostring(profile.noospheric_id or noospheric_id(pair)))
    add_kv_0494(plaque, "Forge origin", tostring(profile.forge_world or profile.planet_of_origin_0525 or "unknown forge"))
    add_kv_0494(plaque, "Origin class", tostring(profile.origin_world_type_0525 or "unclassified"))
    add_kv_0494(plaque, "Current status", tostring(profile.current_status_0525 or profile.mental_state or "unrecorded"))
    add_kv_0494(plaque, "Former assignment", tostring(profile.former_assignment_0525 or "unrecorded"))
    add_kv_0494(plaque, "Rank attainment", tostring(profile.years_to_rank or "unknown") .. " standard years")
    add_kv_0494(plaque, "Motto", '"' .. tostring(profile.doctrine_motto or "The machine will explain nothing.") .. '"')
  else
    add_kv_0494(plaque, "Noospheric ID", noospheric_id(pair))
    add_subtle_note_0494(plaque, "No priest persona slate is bound to this station yet.")
  end
  return plaque
end

