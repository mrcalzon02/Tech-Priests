-- scripts/core/task_auspex_0622.lua
-- Tech Priests 0.1.644
-- Diegetic task/debug auspex tab for the Conclave/Command Overview.
--
-- This module is UI-only. It reads existing telemetry from the runtime broker,
-- work queues, reservations, buckets, sleep/dirty/cache authorities, movement
-- controller, event feeder, and survey-only infrastructure planner. It must not
-- own scheduling, tasks, queues, reservations, sleep states, movement, or cache
-- invalidation.

local M = {}
M.version = "0.1.644"
M.storage_key = "task_auspex_0622"
M.tab_key = "task_auspex"
M.refresh_button = "tech_priests_task_auspex_refresh_0622"
M.button_prefix = "tech_priests_task_auspex_section_0622_"
M.command_name = "tp-task-auspex"
M.min_refresh_ticks = 30

local original_build = nil

local function safe(v)
  if v == nil then return "nil" end
  local ok, out = pcall(function() return tostring(v) end)
  return ok and out or "?"
end

local function count_table(t)
  local n = 0
  if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
  return n
end

local function now() return game and game.tick or 0 end

local function auspex_enabled()
  local cfg = rawget(_G or {}, "TechPriestsRuntimeConfig0626")
  if cfg and cfg.is_debug_enabled then
    local ok, enabled = pcall(cfg.is_debug_enabled, "summary")
    if ok then return enabled == true end
  end
  return true
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    stats = {},
    player_section = {},
    player_last_refresh_tick = {}
  }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  r.stats = r.stats or {}
  r.player_section = r.player_section or {}
  r.player_last_refresh_tick = r.player_last_refresh_tick or {}
  return r
end

local function stat(name, delta)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (delta or 1)
end

local function selected_section(player)
  local r = root()
  return tostring(r.player_section[player.index] or "overview")
end

local function set_section(player, section)
  local r = root()
  r.player_section[player.index] = tostring(section or "overview")
end

local function refresh_allowed(player, reason)
  local r = root()
  r.player_last_refresh_tick = r.player_last_refresh_tick or {}
  local idx = player and player.index
  if not idx then return true end
  local last = tonumber(r.player_last_refresh_tick[idx] or -999999) or -999999
  local tick = now()
  if tick - last < M.min_refresh_ticks then
    stat("refresh_throttled")
    r.stats.last_throttle_reason = tostring(reason or "refresh")
    return false
  end
  r.player_last_refresh_tick[idx] = tick
  return true
end

local function select_task_tab(player)
  if _G.tech_priests_command_overview_set_selected_tab_0371 then
    pcall(_G.tech_priests_command_overview_set_selected_tab_0371, player, M.tab_key)
  else
    storage.tech_priests.command_overview_tab_0371 = storage.tech_priests.command_overview_tab_0371 or {}
    storage.tech_priests.command_overview_tab_0371[player.index] = M.tab_key
  end
end

local function add_label(parent, caption, width)
  local e = parent.add({ type = "label", caption = caption })
  e.style.single_line = false
  if width then e.style.width = width end
  return e
end

local function add_heading(parent, caption)
  local e = parent.add({ type = "label", caption = "[color=green]" .. caption .. "[/color]" })
  e.style.single_line = false
  return e
end

local function add_subtle(parent, caption)
  local e = parent.add({ type = "label", caption = "[color=0.72,0.9,0.72]" .. caption .. "[/color]" })
  e.style.single_line = false
  return e
end

local function add_kv_table(parent, rows)
  local t = parent.add({ type = "table", column_count = 2 })
  t.style.horizontally_stretchable = true
  for _, row in ipairs(rows or {}) do
    local k = t.add({ type = "label", caption = "[color=green]" .. safe(row[1]) .. "[/color]" })
    k.style.width = 230
    k.style.single_line = false
    local v = t.add({ type = "label", caption = safe(row[2]) })
    v.style.width = 730
    v.style.single_line = false
  end
  return t
end

local function external_stats()
  local ok, Broker = pcall(require, "scripts.core.runtime_tick_broker")
  if ok and Broker and Broker.root then
    local br = Broker.root()
    return br.external_stats or {}, br, Broker
  end
  local tp = storage and storage.tech_priests or {}
  local br = tp.runtime_tick_broker_0600 or tp.runtime_tick_broker or {}
  return br.external_stats or {}, br, nil
end

local function call_report(modname)
  local ok, mod = pcall(require, modname)
  if ok and mod and type(mod.report_lines) == "function" then
    local ok2, lines = pcall(mod.report_lines)
    if ok2 and type(lines) == "table" then return lines end
  end
  return {}
end

local function add_lines(parent, lines, max_lines)
  local n = 0
  for _, line in ipairs(lines or {}) do
    n = n + 1
    if max_lines and n > max_lines then
      add_label(parent, "... +" .. tostring(#lines - max_lines) .. " more lines suppressed", 980)
      break
    end
    add_label(parent, tostring(line), 980)
  end
end

local function selected_pair(player)
  if not (player and player.valid) then return nil end
  local selected = nil
  if _G.tech_priests_command_overview_storage_0189 then
    local ok, map = pcall(_G.tech_priests_command_overview_storage_0189)
    if ok and type(map) == "table" then selected = map[player.index] end
  end
  local tp = storage and storage.tech_priests or {}
  if selected and tp.pairs_by_station and tp.pairs_by_station[selected] then return tp.pairs_by_station[selected] end
  if player.selected and player.selected.valid then
    local e = player.selected
    if tp.pairs_by_station and tp.pairs_by_station[e.unit_number] then return tp.pairs_by_station[e.unit_number] end
    if tp.pairs_by_priest and tp.pairs_by_priest[e.unit_number] then return tp.pairs_by_priest[e.unit_number] end
    if _G.find_pair_for_entity then local ok, p = pcall(_G.find_pair_for_entity, e); if ok and p then return p end end
  end
  return nil
end

local function entity_name(e)
  return e and e.valid and (safe(e.name) .. "#" .. safe(e.unit_number or 0)) or "none"
end

local function order_label(order)
  if type(order) ~= "table" then return "none" end
  return safe(order.kind or order.type or order.source or "order")
    .. " key=" .. safe(order.key)
    .. " status=" .. safe(order.status)
    .. " target=" .. entity_name(order.target or order.entity or order.source_entity)
end

local function add_selected_pair(parent, player)
  local pair = selected_pair(player)
  add_heading(parent, "Selected task slate")
  if not pair then
    add_label(parent, "No selected Cogitator/Tech-Priest pair. Select a unit in the roster or select one in the world.", 980)
    return
  end
  local unit = pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number) or "?"
  add_kv_table(parent, {
    {"Station", entity_name(pair.station)},
    {"Priest", entity_name(pair.priest)},
    {"Mode", pair.mode or "idle"},
    {"Target", entity_name(pair.target)},
    {"Combat target", entity_name(pair.combat_target)},
    {"Station unit", unit},
  })

  if pair.master_infrastructure_plan_0644 then
    local plan = pair.master_infrastructure_plan_0644
    local target = plan.target or {}
    add_heading(parent, "Master infrastructure plan 0644")
    add_kv_table(parent, {
      {"Stage", plan.stage or "unknown"},
      {"Resources", plan.resource_summary or "none"},
      {"Roles", plan.role_summary or "none"},
      {"Next target", safe(target.class) .. " / " .. safe(target.preferred_item)},
      {"Fallback", target.fallback_item or "none"},
      {"Blocker", target.blocker or "none"},
      {"Delivery", target.delivery or "none"},
      {"Reason", target.reason or "none"},
    })
  end

  local q = pair.order_queue_0469
  if q then
    add_heading(parent, "Order queue execution stack")
    add_kv_table(parent, {
      {"Current", order_label(q.current)},
      {"Pending", #(q.pending or {})},
      {"Completed", (q.stats or {}).completed or 0},
      {"Duplicates blocked", (q.stats or {}).duplicates_blocked or 0},
      {"Preemptions", (q.stats or {}).preemptions or 0},
      {"Promotions", (q.stats or {}).promotions or 0},
    })
    for i, order in ipairs(q.pending or {}) do
      if i > 8 then add_label(parent, "... additional pending orders hidden", 980); break end
      add_label(parent, "pending[" .. tostring(i) .. "] " .. order_label(order), 980)
    end
    if type(q.history) == "table" and #q.history > 0 then
      add_heading(parent, "Recent order history")
      for i = 1, math.min(#q.history, 8) do
        local h = q.history[i]
        if type(h) == "table" then
          add_label(parent, "tick " .. safe(h.tick or h.finished_tick) .. " · " .. safe(h.status) .. " · " .. safe(h.reason or h.finish_reason) .. " · " .. order_label(h.order or h), 980)
        end
      end
    end
  else
    add_label(parent, "This pair has no order_queue_0469 slate yet.", 980)
  end
end

local function add_runtime(parent)
  local xs, br, Broker = external_stats()
  local stats = br.stats or {}
  add_heading(parent, "Runtime broker / budget pressure")
  add_kv_table(parent, {
    {"Broker enabled", br.enabled},
    {"Services registered", Broker and #(Broker.services or {}) or "unknown"},
    {"Pulses", stats.pulses or 0},
    {"Services run", stats.services_run or 0},
    {"Skipped empty", stats.skipped_empty or 0},
    {"Skipped sleeping", stats.skipped_sleeping or 0},
    {"Budget exhausted", stats.budget_exhausted or 0},
    {"Errors", stats.errors or 0},
    {"Adaptive boosts", stats.adaptive_budget_boosts or 0},
  })
  if Broker and Broker.rolling_sum then
    add_subtle(parent, "Rolling 60-second auspex")
    add_kv_table(parent, {
      {"Services run", Broker.rolling_sum("services_run", 1)},
      {"Errors", Broker.rolling_sum("errors", 1)},
      {"Path requests", Broker.rolling_sum("path_requests", 1)},
      {"Direct scans", Broker.rolling_sum("direct_surface_scans", 1)},
      {"Cache hits", Broker.rolling_sum("indexed_cache_hits", 1)},
      {"Cache misses", Broker.rolling_sum("indexed_cache_misses", 1)},
      {"Directed wakeups", Broker.rolling_sum("directed_wake_issued", 1)},
    })
  end
end

local function compact_summary(parent)
  local xs, br, Broker = external_stats()
  local stats = br.stats or {}
  add_heading(parent, "Compact runtime summary")
  add_kv_table(parent, {
    {"Broker services", Broker and #(Broker.services or {}) or "unknown"},
    {"Services run", stats.services_run or 0},
    {"Budget exhausted", stats.budget_exhausted or 0},
    {"Errors", stats.errors or 0},
    {"Queue claims", xs.work_queue_claim_attempts or xs.queue_claim_attempts or 0},
    {"Directed wakeups", xs.directed_wake_issued or 0},
    {"Estimated scans avoided", (xs.indexed_cache_hits or 0) + (xs.negative_cache_skips or 0)},
    {"Path requests", xs.path_requests or 0},
  })
  add_subtle(parent, "Open a submenu for detailed task economy, sleep/wake, scan/path, or selected-pair ledgers. Overview mode intentionally avoids rendering every heavy ledger at once.")
end

local function add_tasks(parent)
  add_heading(parent, "Shared task economy")
  add_lines(parent, call_report("scripts.core.pair_bucket_registry"), 12)
  add_lines(parent, call_report("scripts.core.work_queue_authority"), 12)
  add_lines(parent, call_report("scripts.core.work_reservations"), 12)
end

local function add_sleep_wake(parent)
  local tp = storage and storage.tech_priests or {}
  local e0595 = tp.efficiency_economy_0595 or {}
  local e0599 = tp.efficiency_economy_0599 or {}
  local e0582 = tp.efficiency_economy_0582 or {}
  local xs = external_stats()
  add_heading(parent, "Sleep / wake litany")
  add_kv_table(parent, {
    {"Dormant whole-runtime gate 0595", "enabled=" .. safe(e0595.enabled) .. " dormant=" .. safe(e0595.dormant) .. " wakes=" .. safe((e0595.stats or {}).wake or (e0595.stats or {}).wakes or 0)},
    {"Adaptive priest sleep 0599", "enabled=" .. safe(e0599.enabled) .. " pair_states=" .. safe(count_table(e0599.pair_state)) .. " sleeps=" .. safe((e0599.stats or {}).sleep or 0) .. " wake_dirty=" .. safe((e0599.stats or {}).wake_dirty or 0)},
    {"Idle compatibility shim 0582", "enabled=" .. safe(e0582.enabled) .. " tracked=" .. safe(count_table(e0582.pair)) .. " dispatcher_skipped=" .. safe((e0582.stats or {}).dispatcher_idle_skipped or 0)},
    {"Directed wakeups", "issued=" .. safe(xs.directed_wake_issued or 0) .. " already_awake=" .. safe(xs.directed_wake_already_awake or 0) .. " no_pair=" .. safe(xs.directed_wake_no_pair or 0)},
    {"Negative knowledge clears", xs.negative_cache_clears_from_event or 0},
  })
  add_lines(parent, call_report("scripts.core.event_driven_work_feeder_0608"), 10)
end

local function add_scan_path(parent)
  local xs = external_stats()
  add_heading(parent, "Scan/cache and movement pressure")
  add_kv_table(parent, {
    {"Scans attempted", xs.scans_attempted or 0},
    {"Redirected to cache", xs.scans_redirected_to_cache or 0},
    {"Indexed cache hits", xs.indexed_cache_hits or 0},
    {"Indexed cache misses", xs.indexed_cache_misses or 0},
    {"Negative cache skips", xs.negative_cache_skips or 0},
    {"Direct surface scans", xs.direct_surface_scans or 0},
    {"Estimated scans avoided", (xs.indexed_cache_hits or 0) + (xs.negative_cache_skips or 0)},
    {"Path requests", xs.path_requests or 0},
    {"Path requests collapsed", xs.path_requests_collapsed or 0},
    {"Retargets held", xs.path_retargets_held or 0},
    {"Engine commands", xs.path_engine_commands or 0},
  })
  add_lines(parent, call_report("scripts.core.scan_routing_0610"), 8)
  add_lines(parent, call_report("scripts.core.movement_controller"), 8)
  add_lines(parent, call_report("scripts.core.spatial_interest_0609"), 8)
end

local function add_profiler(parent)
  add_heading(parent, "Profiler / slow-service auspex")
  add_subtle(parent, "Observation-only: samples broker services and registry callbacks with Factorio profilers. It does not change service behavior.")
  local okB, Broker = pcall(require, "scripts.core.runtime_tick_broker")
  if okB and Broker and type(Broker.profiler_report_lines) == "function" then
    add_lines(parent, Broker.profiler_report_lines(12), 16)
  else
    add_label(parent, "Runtime broker profiler not available yet.", 980)
  end
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if R and type(R.profiler_report_lines) == "function" then
    add_lines(parent, R.profiler_report_lines(12), 16)
  else
    add_label(parent, "Runtime registry profiler not available yet.", 980)
  end
end

local function add_section_buttons(parent, player)
  local flow = parent.add({ type = "flow", direction = "horizontal" })
  local sections = {
    {"overview", "General Auspex"},
    {"tasks", "Task Economy"},
    {"sleep", "Sleep/Wake"},
    {"scanpath", "Scan/Path"},
    {"profiler", "Profiler"},
    {"selected", "Selected Pair"},
  }
  local active = selected_section(player)
  for _, sec in ipairs(sections) do
    local caption = (active == sec[1] and "▶ " or "") .. sec[2]
    flow.add({ type = "button", name = M.button_prefix .. sec[1], caption = caption })
  end
  flow.add({ type = "button", name = M.refresh_button, caption = "Re-read noosphere" })
end

function M.render(parent, player)
  if not (parent and parent.valid and player and player.valid) then return false end
  if not auspex_enabled() then stat("disabled_blocks"); return false end
  stat("renders")
  add_section_buttons(parent, player)
  add_subtle(parent, "Task Auspex reads existing telemetry only. It does not schedule, claim, queue, reserve, move, scan, sleep, or wake work by itself.")

  local scroll = parent.add({ type = "scroll-pane", name = "tech_priests_task_auspex_scroll_0622", direction = "vertical" })
  scroll.style.horizontally_stretchable = true
  scroll.style.vertically_stretchable = true
  scroll.style.height = 590
  scroll.style.maximal_height = 590
  scroll.style.width = 1040

  local section = selected_section(player)
  if section == "tasks" then
    add_tasks(scroll)
  elseif section == "sleep" then
    add_sleep_wake(scroll)
  elseif section == "scanpath" then
    add_scan_path(scroll)
  elseif section == "profiler" then
    add_profiler(scroll)
  elseif section == "selected" then
    add_selected_pair(scroll, player)
  else
    add_heading(scroll, "Conclave Task Auspex")
    compact_summary(scroll)
    add_runtime(scroll)
  end
  return true
end

local function attach_tab(player)
  if not (player and player.valid and player.gui and player.gui.screen) then return false end
  local frame_name = rawget(_G, "TECH_PRIESTS_COMMAND_OVERVIEW_FRAME_0189") or "tech_priests_command_overview_0189"
  local tabs_name = rawget(_G, "TECH_PRIESTS_COMMAND_OVERVIEW_TABS_0371") or "tech_priests_command_overview_tabs_0371"
  local frame = player.gui.screen[frame_name]
  if not (frame and frame.valid) then return false end
  local tabs = frame[tabs_name]
  if not (tabs and tabs.valid and tabs.add_tab) then return false end
  if tabs["tech_priests_task_auspex_page_0622"] then return true end

  local tab = tabs.add({ type = "tab", caption = "Task Auspex / Debug Readout" })
  local page = tabs.add({ type = "flow", name = "tech_priests_task_auspex_page_0622", direction = "vertical" })
  page.style.vertically_stretchable = true
  page.style.horizontally_stretchable = true
  page.style.height = 640
  tabs.add_tab(tab, page)

  local ok, err = pcall(M.render, page, player)
  if not ok then page.add({ type = "label", caption = "Task Auspex failed to render: " .. tostring(err) }) end
  local selected = nil
  if _G.tech_priests_command_overview_selected_tab_0371 then
    local ok2, v = pcall(_G.tech_priests_command_overview_selected_tab_0371, player)
    if ok2 then selected = v end
  end
  if tostring(selected) == M.tab_key then pcall(function() tabs.selected_tab_index = 3 end) end
  return true
end

function M.open(player)
  if not (player and player.valid) then return false end
  if not auspex_enabled() then stat("disabled_blocks"); player.print("[Tech Priests] Task Auspex is disabled by the master debug mode setting."); return false end
  select_task_tab(player)
  if _G.tech_priests_build_command_overview_0189 then
    pcall(_G.tech_priests_build_command_overview_0189, player)
    attach_tab(player)
    return true
  end
  return false
end

local function rebuild(player)
  if not (player and player.valid) then return end
  select_task_tab(player)
  if _G.tech_priests_build_command_overview_0189 then
    pcall(_G.tech_priests_build_command_overview_0189, player)
  end
end

function M.handle_click(event)
  local element = event and event.element
  if not (element and element.valid and element.name) then return false end
  local name = element.name
  if name ~= M.refresh_button and string.sub(name, 1, #M.button_prefix) ~= M.button_prefix then return false end
  local player = event.player_index and game.get_player(event.player_index) or nil
  if not (player and player.valid) then return false end
  if name == M.refresh_button then
    if not refresh_allowed(player, "manual-refresh") then return true end
    stat("manual_refreshes")
    rebuild(player)
    return true
  end
  local section = string.sub(name, #M.button_prefix + 1)
  set_section(player, section)
  stat("section_changes")
  if not refresh_allowed(player, "section-change") then return true end
  rebuild(player)
  return true
end

local function wrap_command_overview()
  if original_build then return true end
  if type(rawget(_G, "tech_priests_build_command_overview_0189")) ~= "function" then return false end
  original_build = rawget(_G, "tech_priests_build_command_overview_0189")
  _G.TECH_PRIESTS_0622_PRE_BUILD_COMMAND_OVERVIEW = original_build
  _G.tech_priests_build_command_overview_0189 = function(player)
    local result = original_build(player)
    if auspex_enabled() then pcall(attach_tab, player) end
    return result
  end
  return true
end

function M.report_lines()
  local r = root()
  return { "[tp-runtime-report] task-auspex-0622 enabled=" .. safe(auspex_enabled()) .. " renders=" .. safe(r.stats.renders or 0) .. " section_changes=" .. safe(r.stats.section_changes or 0) .. " manual_refreshes=" .. safe(r.stats.manual_refreshes or 0) .. " refresh_throttled=" .. safe(r.stats.refresh_throttled or 0) .. " disabled_blocks=" .. safe(r.stats.disabled_blocks or 0) .. " last_throttle=" .. safe(r.stats.last_throttle_reason or "none") }
end

local function install_infrastructure_plan_0644()
  local ok, Plan0644 = pcall(require, "scripts.core.master_infrastructure_plan_0644")
  if ok and Plan0644 and type(Plan0644.install) == "function" then
    local ok2, err2 = pcall(Plan0644.install)
    if ok2 then stat("infra_plan_0644_installed"); return true end
    if log then log("[Tech-Priests 0.1.644] master_infrastructure_plan_0644 install failed: " .. tostring(err2)) end
    stat("infra_plan_0644_install_failed")
    return false
  end
  if log then log("[Tech-Priests 0.1.644] master_infrastructure_plan_0644 unavailable: " .. tostring(Plan0644)) end
  stat("infra_plan_0644_missing")
  return false
end

function M.install()
  root()
  install_infrastructure_plan_0644()
  wrap_command_overview()
  local okR, Router = pcall(require, "scripts.gui.gui_router")
  if okR and Router and Router.register then
    Router.register("click", M.handle_click, "task-auspex-0622-click")
  end
  if commands and commands.add_command then
    pcall(function() if commands.remove_command then commands.remove_command(M.command_name) end end)
    pcall(function()
      commands.add_command(M.command_name, "Tech Priests: open the Conclave Task Auspex debug readout tab.", function(event)
        local player = event and event.player_index and game.get_player(event.player_index) or nil
        if not player then return end
        if not auspex_enabled() then
          stat("disabled_blocks")
          player.print("[Tech Priests] Task Auspex is disabled. Set Tech Priests debug mode to summary, verbose, or profiler to open the live debug readout.")
          return
        end
        M.open(player)
      end)
    end)
  end
  _G.tech_priests_0622_open_task_auspex = M.open
  _G.tech_priests_0622_render_task_auspex = M.render
  if log then log("[Tech-Priests 0.1.644] Conclave Task Auspex debug readout tab installed; master infrastructure planner loader invoked") end
  return true
end

return M
