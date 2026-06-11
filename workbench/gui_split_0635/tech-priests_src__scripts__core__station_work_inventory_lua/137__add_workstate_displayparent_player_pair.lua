-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2151-2248
local function add_workstate_display(parent, player, pair)
  if add_boot_display(parent, player, pair) and active_boot(player) then return end

  local task_name, task = task_candidates(pair)
  local superior, juniors, peers = relation_summary(pair)
  local profile = profile_for_pair(pair)

  local overview = parent.add({ type = "table", name = "tech_priests_workstate_summary_table_0494", column_count = 2 })
  apply_screen_table_style_0564(overview)
  overview.style.horizontally_stretchable = true
  pcall(function() overview.style.column_alignments[1] = "left" end)
  pcall(function() overview.style.column_alignments[2] = "left" end)
  local left = overview.add({ type = "flow", direction = "vertical" })
  local right = overview.add({ type = "flow", direction = "vertical" })
  pcall(function() left.style.minimal_width = 360 end)
  pcall(function() left.style.maximal_width = 390 end)
  pcall(function() right.style.minimal_width = 360 end)
  pcall(function() right.style.maximal_width = 430 end)
  left.style.horizontally_stretchable = true
  right.style.horizontally_stretchable = true

  add_identity_plaque_0494(left, pair, profile)
  add_doctrine_plaque_0494(left, pair, profile)
  add_current_rite_plaque_0494(right, pair, task_name, task)
  add_command_plaque_0494(right, pair, superior, juniors, peers)
  add_recent_notes_plaque_0494(right, pair, profile)

  local diag = add_plaque_0494(parent, "Machine-Spirit Augury")
  add_task_memory_display(diag, pair, task_name, task, superior, juniors)
  add_task_transition_governor_display(diag, pair)
  if _G.tech_priests_0361_describe_scheduler_state then
    local ok_sched, sched_lines = pcall(_G.tech_priests_0361_describe_scheduler_state, pair)
    if ok_sched and sched_lines then
      add_label(diag, "Scheduler and executor authority")
      for i, sched_line in ipairs(sched_lines) do
        if i <= 9 then add_label(diag, "  " .. tostring(sched_line)) end
      end
    end
  end

  local facilities = facility_records(pair)
  local facility_panel = add_plaque_0494(parent, "Bound Martian Apparatus")
  add_kv_0494(facility_panel, "Claimed apparatus", tostring(#facilities))
  if #facilities == 0 then add_subtle_note_0494(facility_panel, "no Martian apparatus claimed by this station") end
  for i, rec in ipairs(facilities) do
    if i > M.max_rows then add_label(facility_panel, "  ..." .. tostring(#facilities - M.max_rows) .. " more"); break end
    local e = rec.entity
    local recipe = ""
    if valid(e) and e.get_recipe then local ok, r = pcall(function() return e.get_recipe() end); if ok and r then recipe = " | recipe " .. tostring(r.name or r) end end
    add_label(facility_panel, "  " .. tostring(rec.role or "facility") .. ": " .. tostring(rec.name) .. "#" .. tostring(e and e.unit_number or "?") .. recipe)
  end

  local stock_panel = add_plaque_0494(parent, "Inventory Reliquaries")
  local station_rows, station_total = sorted_items(merged_contents(M.station_sources(pair)), M.max_rows)
  add_items(stock_panel, "Unified station inventory / stash / apparatus contents", station_rows, station_total, "no station-bound stock detected")
  local transient_rows, transient_total = sorted_items(merged_contents(priest_transient_inventories(pair)), M.max_rows)
  add_items(stock_panel, "Priest transient reliquary cargo", transient_rows, transient_total, "none; correct")

  local doctrine = add_plaque_0494(parent, "Operational Catechism")
  add_label(doctrine, "craft: station/stash ingredients -> temporary carry -> station/stash output")
  add_label(doctrine, "place: station/stash item -> temporary carry -> placed entity inherits station")
  add_label(doctrine, "mine/scavenge: result returns to station/stash; no ground spilling")
  add_label(doctrine, "random priest cargo: evacuate to station/stash; never active stock")
end


-- 0.1.482: Diegetic Cogitator GUI shell assets.  The first pass keeps the
-- existing Work State logic intact while giving the panel a dedicated asset
-- frame and stable sprite names for later full custom-screen conversion.
add_gui_sprite_0482 = function(parent, sprite_name, width, height, tooltip)
  if not (parent and parent.valid and sprite_name) then return nil end
  local ok, elem = pcall(function()
    return parent.add({ type = "sprite", sprite = sprite_name, tooltip = tooltip })
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


local GUI_FRAME_0536 = {
  enabled = true,
  corner = 64,
  side_column = 64,
  emblem_w = 96,
  top_bottom_h = 64,
  bezel = 20,
  outer_margin_w = 22,
  outer_margin_h = 52,
}

