-- 0.1.586 optional lean GUI sprite mode.
-- Startup setting driven: swaps oversized GUI SpritePrototypes to half-resolution copies and doubles scale.
if settings and settings.startup and settings.startup["tech-priests-use-lean-gui-sprites"] and settings.startup["tech-priests-use-lean-gui-sprites"].value then
  local replacements = {
    ["tech-priests-gui-controls-normal-01-round-button-off"] = { filename = "__tech-priests__/graphics/lean/gui/01_round_button_off__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-normal-02-round-button-on"] = { filename = "__tech-priests__/graphics/lean/gui/02_round_button_on__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-normal-03-rect-button-off"] = { filename = "__tech-priests__/graphics/lean/gui/03_rect_button_off__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-normal-04-rect-button-on"] = { filename = "__tech-priests__/graphics/lean/gui/04_rect_button_on__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-normal-05-toggle-switch-off"] = { filename = "__tech-priests__/graphics/lean/gui/05_toggle_switch_off__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-normal-06-toggle-switch-on"] = { filename = "__tech-priests__/graphics/lean/gui/06_toggle_switch_on__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-normal-07-rotary-knob-off"] = { filename = "__tech-priests__/graphics/lean/gui/07_rotary_knob_off__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-normal-08-rotary-knob-on"] = { filename = "__tech-priests__/graphics/lean/gui/08_rotary_knob_on__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-normal-09-lever-switch-off"] = { filename = "__tech-priests__/graphics/lean/gui/09_lever_switch_off__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-normal-10-lever-switch-on"] = { filename = "__tech-priests__/graphics/lean/gui/10_lever_switch_on__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-normal-11-warning-lamp-off"] = { filename = "__tech-priests__/graphics/lean/gui/11_warning_lamp_off__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-normal-12-warning-lamp-on"] = { filename = "__tech-priests__/graphics/lean/gui/12_warning_lamp_on__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-normal-13-slider-off"] = { filename = "__tech-priests__/graphics/lean/gui/13_slider_off__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-normal-14-slider-on"] = { filename = "__tech-priests__/graphics/lean/gui/14_slider_on__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-normal-15-gauge-off"] = { filename = "__tech-priests__/graphics/lean/gui/15_gauge_off__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-normal-16-gauge-on"] = { filename = "__tech-priests__/graphics/lean/gui/16_gauge_on__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-disabled-01-round-button-off"] = { filename = "__tech-priests__/graphics/lean/gui/01_round_button_off__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-disabled-02-round-button-on"] = { filename = "__tech-priests__/graphics/lean/gui/02_round_button_on__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-disabled-03-rect-button-off"] = { filename = "__tech-priests__/graphics/lean/gui/03_rect_button_off__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-disabled-04-rect-button-on"] = { filename = "__tech-priests__/graphics/lean/gui/04_rect_button_on__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-disabled-05-toggle-switch-off"] = { filename = "__tech-priests__/graphics/lean/gui/05_toggle_switch_off__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-disabled-06-toggle-switch-on"] = { filename = "__tech-priests__/graphics/lean/gui/06_toggle_switch_on__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-disabled-07-rotary-knob-off"] = { filename = "__tech-priests__/graphics/lean/gui/07_rotary_knob_off__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-disabled-08-rotary-knob-on"] = { filename = "__tech-priests__/graphics/lean/gui/08_rotary_knob_on__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-disabled-09-lever-switch-off"] = { filename = "__tech-priests__/graphics/lean/gui/09_lever_switch_off__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-disabled-10-lever-switch-on"] = { filename = "__tech-priests__/graphics/lean/gui/10_lever_switch_on__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-disabled-11-warning-lamp-off"] = { filename = "__tech-priests__/graphics/lean/gui/11_warning_lamp_off__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-disabled-12-warning-lamp-on"] = { filename = "__tech-priests__/graphics/lean/gui/12_warning_lamp_on__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-disabled-13-slider-off"] = { filename = "__tech-priests__/graphics/lean/gui/13_slider_off__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-disabled-14-slider-on"] = { filename = "__tech-priests__/graphics/lean/gui/14_slider_on__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-disabled-15-gauge-off"] = { filename = "__tech-priests__/graphics/lean/gui/15_gauge_off__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-controls-disabled-16-gauge-on"] = { filename = "__tech-priests__/graphics/lean/gui/16_gauge_on__lean50.png", width = 168, height = 132, scale = 2.0 },
    ["tech-priests-gui-boot-spinner-0526-01"] = { filename = "__tech-priests__/graphics/lean/gui/boot_spinner_01__lean50.png", width = 64, height = 64, scale = 2.0 },
    ["tech-priests-gui-boot-spinner-0526-02"] = { filename = "__tech-priests__/graphics/lean/gui/boot_spinner_02__lean50.png", width = 64, height = 64, scale = 2.0 },
    ["tech-priests-gui-boot-spinner-0526-03"] = { filename = "__tech-priests__/graphics/lean/gui/boot_spinner_03__lean50.png", width = 64, height = 64, scale = 2.0 },
    ["tech-priests-gui-boot-spinner-0526-04"] = { filename = "__tech-priests__/graphics/lean/gui/boot_spinner_04__lean50.png", width = 64, height = 64, scale = 2.0 },
    ["tech-priests-gui-boot-spinner-0526-05"] = { filename = "__tech-priests__/graphics/lean/gui/boot_spinner_05__lean50.png", width = 64, height = 64, scale = 2.0 },
    ["tech-priests-gui-boot-spinner-0526-06"] = { filename = "__tech-priests__/graphics/lean/gui/boot_spinner_06__lean50.png", width = 64, height = 64, scale = 2.0 },
    ["tech-priests-gui-boot-spinner-0526-07"] = { filename = "__tech-priests__/graphics/lean/gui/boot_spinner_07__lean50.png", width = 64, height = 64, scale = 2.0 },
    ["tech-priests-gui-boot-spinner-0526-08"] = { filename = "__tech-priests__/graphics/lean/gui/boot_spinner_08__lean50.png", width = 64, height = 64, scale = 2.0 },
    ["tech-priests-gui-boot-spinner-0526-09"] = { filename = "__tech-priests__/graphics/lean/gui/boot_spinner_09__lean50.png", width = 64, height = 64, scale = 2.0 },
    ["tech-priests-gui-boot-spinner-0526-10"] = { filename = "__tech-priests__/graphics/lean/gui/boot_spinner_10__lean50.png", width = 64, height = 64, scale = 2.0 },
    ["tech-priests-gui-boot-spinner-0526-11"] = { filename = "__tech-priests__/graphics/lean/gui/boot_spinner_11__lean50.png", width = 64, height = 64, scale = 2.0 },
    ["tech-priests-gui-boot-spinner-0526-12"] = { filename = "__tech-priests__/graphics/lean/gui/boot_spinner_12__lean50.png", width = 64, height = 64, scale = 2.0 },
    ["tech-priests-gui-mechanical-skull-gear-emblem"] = { filename = "__tech-priests__/graphics/lean/gui/mechanical_skull_gear_emblem__lean50.png", width = 508, height = 517, scale = 2.0 },
    ["tech-priests-portrait-tech-priest-augmented-sheet-a"] = { filename = "__tech-priests__/graphics/lean/gui/tech_priest_augmented_portrait_sheet_a__lean50.png", width = 617, height = 616, scale = 2.0 },
    ["tech-priests-portrait-baseline-human-sheet"] = { filename = "__tech-priests__/graphics/lean/gui/baseline_human_portrait_sheet__lean50.png", width = 621, height = 617, scale = 2.0 },
    ["tech-priests-gui-portraits-alternative-human-augmented-portrait-sheet-c"] = { filename = "__tech-priests__/graphics/lean/gui/alternative_human_augmented_portrait_sheet_c__lean50.png", width = 624, height = 615, scale = 2.0 },
    ["tech-priests-portrait-alternative-human-augmented-sheet-c"] = { filename = "__tech-priests__/graphics/lean/gui/alternative_human_augmented_portrait_sheet_c__lean50.png", width = 624, height = 615, scale = 2.0 },
    ["tech-priests-gui-portraits-planetary-magos-portrait-sheet-a"] = { filename = "__tech-priests__/graphics/lean/gui/planetary_magos_portrait_sheet_a__lean50.png", width = 656, height = 500, scale = 2.0 },
    ["tech-priests-portrait-planetary-magos-sheet-a"] = { filename = "__tech-priests__/graphics/lean/gui/planetary_magos_portrait_sheet_a__lean50.png", width = 656, height = 500, scale = 2.0 },
    ["tech-priests-gui-frame-0536-left-column"] = { filename = "__tech-priests__/graphics/lean/gui/left_column__lean50.png", width = 32, height = 128, scale = 2.0 },
    ["tech-priests-gui-frame-0536-right-column"] = { filename = "__tech-priests__/graphics/lean/gui/right_column__lean50.png", width = 32, height = 128, scale = 2.0 },
    ["tech-priests-gui-frame-0536-inner-bezel-t"] = { filename = "__tech-priests__/graphics/lean/gui/inner_bezel_t__lean50.png", width = 108, height = 10, scale = 2.0 },
    ["tech-priests-gui-frame-0536-inner-bezel-l"] = { filename = "__tech-priests__/graphics/lean/gui/inner_bezel_l__lean50.png", width = 10, height = 108, scale = 2.0 },
    ["tech-priests-gui-frame-0536-inner-display-center"] = { filename = "__tech-priests__/graphics/lean/gui/inner_display_center__lean50.png", width = 108, height = 108, scale = 2.0 },
    ["tech-priests-gui-frame-0536-inner-bezel-r"] = { filename = "__tech-priests__/graphics/lean/gui/inner_bezel_r__lean50.png", width = 10, height = 108, scale = 2.0 },
    ["tech-priests-gui-frame-0536-inner-bezel-b"] = { filename = "__tech-priests__/graphics/lean/gui/inner_bezel_b__lean50.png", width = 108, height = 10, scale = 2.0 },
    ["tech-priests-gui-frame-0536-inner-bezel-full"] = { filename = "__tech-priests__/graphics/lean/gui/inner_bezel_full__lean50.png", width = 128, height = 128, scale = 2.0 },
    ["tech-priests-gui-frame-0540-left-column-mid"] = { filename = "__tech-priests__/graphics/lean/gui/left_column_mid__lean50.png", width = 32, height = 64, scale = 2.0 },
    ["tech-priests-gui-frame-0540-right-column-mid"] = { filename = "__tech-priests__/graphics/lean/gui/right_column_mid__lean50.png", width = 32, height = 64, scale = 2.0 },
    ["tech-priests-gui-frame-0536-source-384"] = { filename = "__tech-priests__/graphics/lean/gui/gui_frame_clean_source_384__lean50.png", width = 192, height = 192, scale = 2.0 },
  }
  for name, patch in pairs(replacements) do
    local sprite = data.raw.sprite and data.raw.sprite[name]
    if sprite then
      sprite.filename = patch.filename
      sprite.width = patch.width
      sprite.height = patch.height
      sprite.scale = (sprite.scale or 1) * patch.scale
    end
  end
end
