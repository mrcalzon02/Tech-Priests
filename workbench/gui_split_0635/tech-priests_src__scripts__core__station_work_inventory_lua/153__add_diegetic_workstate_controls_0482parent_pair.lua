-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2445-2456
local function add_diegetic_workstate_controls_0482(parent, pair)
  local rail = parent.add({ type = "flow", name = "tech_priests_workstate_control_rail_0482", direction = "horizontal" })
  rail.style.horizontally_stretchable = true
  pcall(function() rail.style.vertical_align = "center" end)
  add_gui_sprite_0482(rail, "tech-priests-gui-mechanical-skull-gear-emblem", 28, 28, "Command seal")
  local refresh_button = rail.add({ type = "button", name = "tech_priests_workstate_refresh_0358", caption = "Recast Work-State Auspex" })
  apply_gui_style_0532(refresh_button, "tech_priests_cogitator_button_0532")
  local hint = rail.add({ type = "label", caption = dictator_green("  Cogitator reliquary awake. Select a slate to inspect memory, writs, vox, command lattice, or forge mandates.") })
  style_terminal_label(hint, 660)
  return rail
end

