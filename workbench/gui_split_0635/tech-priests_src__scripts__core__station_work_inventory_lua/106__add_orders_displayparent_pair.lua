-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1628-1685
local function add_orders_display(parent, pair)
  add_label(parent, "Writ Reliquary: active mandate, sealed queue, and archived writs")
  local q = pair and pair.order_queue_0469 or nil
  if not q then
    add_label(parent, "  No writ slate has yet been bound to this station-priest pair.")
    return
  end
  local cur = q.current or (pair and pair.active_order_0469)
  local w = pair and pair.execution_watchdog_0477 or nil
  add_summary_table_0521(parent, "Writ Auspex", {
    { "Active writ", cur and (cur.key or cur.id or "unsealed") or "none" },
    { "Pending writs", tostring(#(q.pending or {})) },
    { "Duplicate echoes refused", tostring(q.stats and q.stats.duplicates_blocked or q.duplicates or 0) },
    { "Promoted rites", tostring(q.stats and q.stats.promotions or 0) },
    { "Preemptions", tostring(q.stats and q.stats.preemptions or q.preemptions or 0) },
    { "Executor cherubim", w and ("last " .. tostring(w.last_key or "none") .. " | finding " .. tostring(w.last_result or w.last_reason or "silent") .. " | re-arm " .. tostring(w.attempts or 0)) or "no watchdog seal visible" },
  })

  local current_frame = parent.add({ type = "frame", caption = "Active Writ", direction = "vertical" })
  pcall(function() current_frame.style.horizontally_stretchable = true end)
  local current_table = current_frame.add({ type = "table", column_count = 8 })
  apply_screen_table_style_0564(current_table)
  add_order_table_header_0495(current_table)
  if cur then add_order_table_row_0495(current_table, cur, "active", "▶") else add_table_cell_0521(current_table, "—", 34, false); add_table_cell_0521(current_table, "No active writ sealed", 760, false) end

  local pending_frame = parent.add({ type = "frame", caption = "Sealed Pending Writs", direction = "vertical" })
  pcall(function() pending_frame.style.horizontally_stretchable = true end)
  local pending = q.pending or {}
  if #pending == 0 then
    add_label(pending_frame, "  No pending writs are waiting beneath the active rite.")
  else
    local pending_table = pending_frame.add({ type = "table", column_count = 8 })
    apply_screen_table_style_0564(pending_table)
    add_order_table_header_0495(pending_table)
    for i, order in ipairs(pending) do
      if i > 14 then add_label(pending_frame, "  …" .. tostring(#pending - 14) .. " sealed writs remain below the fold"); break end
      add_order_table_row_0495(pending_table, order, "queued", i)
    end
  end

  local hist_frame = parent.add({ type = "frame", caption = "Archived Writ Seals", direction = "vertical" })
  pcall(function() hist_frame.style.horizontally_stretchable = true end)
  local hist = q.history or {}
  if #hist == 0 then
    add_label(hist_frame, "  No completed, failed, promoted, or paused writs have been recorded.")
  else
    local hist_table = hist_frame.add({ type = "table", column_count = 8 })
    apply_screen_table_style_0564(hist_table)
    add_order_table_header_0495(hist_table)
    local first = math.max(1, #hist - 13)
    local row_no = 1
    for i = #hist, first, -1 do
      add_order_table_row_0495(hist_table, hist[i], hist[i] and hist[i].status or "mark", row_no)
      row_no = row_no + 1
    end
  end
end

