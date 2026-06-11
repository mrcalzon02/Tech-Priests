-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 473-530
local function add_boot_display(parent, player, pair)
  local stage, total, elapsed = boot_stage(player, pair)
  if not stage then return false end
  local lines, pct = boot_lines_for(pair, player, stage, elapsed)
  play_boot_sound(player, pair, stage)
  local box = parent.add({ type = "frame", name = "tech_priests_dictator_boot_frame_0364", direction = "vertical", caption = "Dictator Display Inception Rite" })
  apply_display_frame_style_0540(box)
  box.style.minimal_width = 560
  box.style.horizontally_stretchable = true
  box.style.minimal_height = 390
  box.style.maximal_height = 450

  local row = box.add({ type = "flow", name = "tech_priests_dictator_boot_row_0526", direction = "horizontal" })
  pcall(function() row.style.horizontally_stretchable = true end)

  local boot_scroll = row.add({ type = "scroll-pane", name = "tech_priests_dictator_boot_scroll_0452", direction = "vertical" })
  apply_screen_scroll_style_0564(boot_scroll)
  boot_scroll.style.minimal_height = 245
  boot_scroll.style.maximal_height = 275
  boot_scroll.style.minimal_width = 600
  boot_scroll.style.horizontally_stretchable = true
  local label = boot_scroll.add({ type = "label", name = "tech_priests_dictator_boot_text_0364", caption = table.concat(lines, "\n") })
  style_terminal_label(label, M.label_wrap_width)
  pcall(function() label.style.minimal_height = 230 end)
  pcall(function() label.style.maximal_height = 255 end)

  local sigil = row.add({ type = "frame", name = "tech_priests_dictator_boot_spinner_frame_0526", direction = "vertical", caption = "Omnissian Chrono-Sigil" })
  apply_display_frame_style_0540(sigil)
  style_box_width_0526(sigil, 132, 144)
  local sprite = sigil.add({ type = "sprite", name = "tech_priests_dictator_boot_spinner_0526", sprite = boot_spinner_sprite_0526(elapsed) })
  pcall(function() sprite.style.width = 96 end)
  pcall(function() sprite.style.height = 96 end)
  local seal = sigil.add({ type = "label", name = "tech_priests_dictator_boot_spinner_caption_0526", caption = dictator_green("rotating skull-gear litany active") })
  style_terminal_label(seal, 118)
  pcall(function() seal.style.font = M.font_small_glyph end)
  local phase = sigil.add({ type = "label", name = "tech_priests_dictator_boot_spinner_phase_0526", caption = dictator_green("rite phase " .. tostring(stage) .. "/" .. tostring(total)) })
  style_terminal_label(phase, 118)
  pcall(function() phase.style.font = M.font_small_glyph end)

  pcall(function() boot_scroll.scroll_to_top() end)
  if stage >= total and elapsed >= (total * boot_stage_ticks() + boot_hold_ticks()) then
    mark_boot_seen(pair, player)
    clear_active_boot(player)
  end
  return true
end

station_rank = function(pair)
  if not pair then return 1 end
  if tonumber(pair.rank) then return tonumber(pair.rank) end
  if pair.station_rank then return tonumber(pair.station_rank) or 1 end
  local name = valid(pair.station) and pair.station.name or ""
  if name:find("planetary%-magos", 1, false) or name:find("void", 1, false) then return 4 end
  if name:find("senior", 1, false) then return 3 end
  if name:find("intermediate", 1, false) then return 2 end
  return 1
end

