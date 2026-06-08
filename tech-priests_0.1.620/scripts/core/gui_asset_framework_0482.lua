-- scripts/core/gui_asset_framework_0482.lua
-- Tech Priests 0.1.487
-- Retained GUI asset registry.  The experimental outer frame kit was removed;
-- only the skull emblem, controls/lights/switches, and portrait sheets remain.

local M = {}
M.version = "0.1.536"

M.sprites = {
  cog_skull = "tech-priests-gui-mechanical-skull-gear-emblem",
  lamp_off = "tech-priests-gui-controls-normal-11-warning-lamp-off",
  lamp_on = "tech-priests-gui-controls-normal-12-warning-lamp-on",
  toggle_off = "tech-priests-gui-controls-normal-05-toggle-switch-off",
  toggle_on = "tech-priests-gui-controls-normal-06-toggle-switch-on",
  lever_off = "tech-priests-gui-controls-normal-09-lever-switch-off",
  lever_on = "tech-priests-gui-controls-normal-10-lever-switch-on",
}


M.frame_0536 = {
  corner_top_left = "tech-priests-gui-frame-0536-corner-top-left",
  top_rail_left = "tech-priests-gui-frame-0536-top-rail-left",
  top_center_emblem = "tech-priests-gui-frame-0536-top-center-emblem",
  top_rail_right = "tech-priests-gui-frame-0536-top-rail-right",
  corner_top_right = "tech-priests-gui-frame-0536-corner-top-right",
  left_column = "tech-priests-gui-frame-0536-left-column",
  right_column = "tech-priests-gui-frame-0536-right-column",
  corner_bottom_left = "tech-priests-gui-frame-0536-corner-bottom-left",
  bottom_rail_left = "tech-priests-gui-frame-0536-bottom-rail-left",
  bottom_center_emblem = "tech-priests-gui-frame-0536-bottom-center-emblem",
  bottom_rail_right = "tech-priests-gui-frame-0536-bottom-rail-right",
  corner_bottom_right = "tech-priests-gui-frame-0536-corner-bottom-right",
  inner_bezel_tl = "tech-priests-gui-frame-0536-inner-bezel-tl",
  inner_bezel_t = "tech-priests-gui-frame-0536-inner-bezel-t",
  inner_bezel_tr = "tech-priests-gui-frame-0536-inner-bezel-tr",
  inner_bezel_l = "tech-priests-gui-frame-0536-inner-bezel-l",
  inner_display_center = "tech-priests-gui-frame-0536-inner-display-center",
  inner_bezel_r = "tech-priests-gui-frame-0536-inner-bezel-r",
  inner_bezel_bl = "tech-priests-gui-frame-0536-inner-bezel-bl",
  inner_bezel_b = "tech-priests-gui-frame-0536-inner-bezel-b",
  inner_bezel_br = "tech-priests-gui-frame-0536-inner-bezel-br",
}

M.frame_metrics_0536 = {
  corner = 64,
  side_column = 64,
  center_emblem_w = 96,
  top_bottom_h = 64,
  inner_bezel = 20,
}

M.portraits = {
  augmented_a = "tech-priests-portrait-tech-priest-augmented-sheet-a",
  baseline_human = "tech-priests-portrait-baseline-human-sheet",
  alternative_human_augmented_c = "tech-priests-portrait-alternative-human-augmented-sheet-c",
  planetary_magos_a = "tech-priests-portrait-planetary-magos-sheet-a",
}

function M.install()
  _G.tech_priests_gui_assets_0482 = M
  _G.TECH_PRIESTS_GUI_ASSETS_0482 = M
  if log then log("[Tech-Priests 0.1.487] retained GUI utility/portrait asset registry installed; sliced Cogitator frame 0.1.536 registered") end
  return true
end

return M
