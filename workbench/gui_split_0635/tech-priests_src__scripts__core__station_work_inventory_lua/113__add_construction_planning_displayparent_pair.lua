-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1749-1819
local function add_construction_planning_display(parent, pair)
  add_label(parent, "Forge Slate: planetary construction augury and placement mandates")
  local rank = station_rank(pair)
  local q = pair and pair.magos_planning_queue_0471 or nil
  local cur = q and (q.current or pair.magos_current_plan_0471) or (pair and pair.magos_current_plan_0471)
  add_summary_table_0521(parent, "Forge Augury", {
    { "Planning seal", rank >= 4 and "Planetary Magos authoring enabled" or "receiver-only; no planetary planning seal" },
    { "Current plan", cur and (cur.key or cur.id or "unsealed") or "none" },
    { "Pending plans", q and tostring(#(q.pending or {})) or "0" },
    { "Duplicate omens refused", q and tostring(q.stats and q.stats.duplicates_blocked or 0) or "0" },
    { "Technology gate", "plans should use only unlocked or station-known production chains" },
    { "Placement doctrine", "ghost/structure placement is deferred until the item exists or is currently producible" },
  })
  if not q then
    add_label(parent, "  No strategic construction slate is present on this cogitator.")
    return
  end

  local current_frame = parent.add({ type = "frame", caption = "Active Forge Mandate", direction = "vertical" })
  pcall(function() current_frame.style.horizontally_stretchable = true end)
  local current_table = current_frame.add({ type = "table", column_count = 8 })
  apply_screen_table_style_0564(current_table)
  add_plan_table_header_0521(current_table)
  if cur then add_plan_table_row_0521(current_table, cur, "current", "▶") else add_table_cell_0521(current_table, "—", 34, false); add_table_cell_0521(current_table, "No active forge mandate", 760, false) end

  local pending_frame = parent.add({ type = "frame", caption = "Sealed Forge Mandates", direction = "vertical" })
  pcall(function() pending_frame.style.horizontally_stretchable = true end)
  local pending = q.pending or {}
  if #pending == 0 then
    add_label(pending_frame, "  No queued forge mandates are waiting beneath the active plan.")
  else
    local pending_table = pending_frame.add({ type = "table", column_count = 8 })
    apply_screen_table_style_0564(pending_table)
    add_plan_table_header_0521(pending_table)
    for i, rec in ipairs(pending) do
      if i > 14 then add_label(pending_frame, "  …" .. tostring(#pending - 14) .. " deeper auguries remain sealed"); break end
      add_plan_table_row_0521(pending_table, rec, "queued", i)
    end
  end

  local hist_frame = parent.add({ type = "frame", caption = "Archived Forge Seals", direction = "vertical" })
  pcall(function() hist_frame.style.horizontally_stretchable = true end)
  local hist = q.history or {}
  if #hist == 0 then
    add_label(hist_frame, "  No construction seals have yet been archived.")
  else
    local hist_table = hist_frame.add({ type = "table", column_count = 8 })
    apply_screen_table_style_0564(hist_table)
    add_plan_table_header_0521(hist_table)
    local first = math.max(1, #hist - 13)
    local row_no = 1
    for i = #hist, first, -1 do
      add_plan_table_row_0521(hist_table, hist[i], hist[i] and hist[i].status or "mark", row_no)
      row_no = row_no + 1
    end
  end

  local doctrine = parent.add({ type = "frame", caption = "Construction Catechism Gates", direction = "vertical" })
  pcall(function() doctrine.style.horizontally_stretchable = true end)
  local gate_table = doctrine.add({ type = "table", column_count = 2 })
  apply_screen_table_style_0564(gate_table)
  add_table_cell_0521(gate_table, "Resource expansion", 220, true)
  add_table_cell_0521(gate_table, "deferred until the required station/item exists or has an unlocked production chain", 540, false)
  add_table_cell_0521(gate_table, "Nested ghost placement", 220, true)
  add_table_cell_0521(gate_table, "allowed only after the item source can be proven by station inventory or current technology", 540, false)
  add_table_cell_0521(gate_table, "Physical placement", 220, true)
  add_table_cell_0521(gate_table, "priest must acquire the structure and go to the site before it becomes real", 540, false)
  add_table_cell_0521(gate_table, "Deferred arterial rites", 220, true)
  add_table_cell_0521(gate_table, "belt paths, pipe paths, and pylon chains remain awaiting later sanction", 540, false)
end

