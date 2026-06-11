-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2821-2844
function M.install()
  _G.TECH_PRIESTS_STATION_WORK_INVENTORY_0358 = M
  _G.tech_priests_0358_station_sources_for_pair = M.station_sources
  _G.tech_priests_0358_station_item_count = M.station_item_count
  _G.tech_priests_0358_try_remove_from_station = M.try_remove_from_station
  _G.tech_priests_0358_try_deposit_to_station = M.try_deposit_to_station
  _G.tech_priests_0358_describe_workstate = M.describe_pair
  _G.tech_priests_0366_observe_station_task_state = observe_task_state
  _G.tech_priests_0367_profile_for_pair = profile_for_pair
  _G.tech_priests_0412_note_priest_conversation = M.note_priest_conversation
  M.install_commands()
  if script and defines and defines.events then
    script.on_event(defines.events.on_gui_opened, M.handle_gui_opened)
    script.on_event(defines.events.on_gui_closed, M.handle_gui_closed)
    script.on_event(defines.events.on_gui_click, M.handle_gui_click)
  end
  if script and script.on_nth_tick then
    script.on_nth_tick(M.boot_refresh_ticks, function() M.service_boot_displays() end)
  end
  if log then log("[Tech-Priests 0.1.526] station-bound Work-State Reliquary loaded; UI/logistics polish active") end
  return true
end

return M
