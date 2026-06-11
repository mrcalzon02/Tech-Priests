-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2420-2444
local function add_diegetic_workstate_body_0482(parent, panel_w, panel_h)
  -- 0.1.536: Assemble the approved mechanically sliced Cogitator frame as a
  -- visual shell around the existing Work-State content.  This is a display
  -- wrapper only: it does not add a new controller, scheduler, task owner, or
  -- behavior loop.
  if GUI_FRAME_0536.enabled then
    local ok, body, content_w, content_h = pcall(add_sliced_cogitator_shell_0536, parent, panel_w, panel_h)
    if ok and body and body.valid then
      return body, content_w, content_h
    end
    if log then log("[Tech-Priests 0.1.536] sliced Cogitator GUI shell failed; falling back to tinted native frame") end
  end

  -- 0.1.532 fallback: real inner frame rather than a bare flow so the
  -- Cogitator GUI can have a brown outer shell and a dark green instrument bay.
  local body = parent.add({ type = "frame", name = "tech_priests_workstate_gui_body_0487", direction = "vertical" })
  apply_display_frame_style_0540(body)
  body.style.horizontally_stretchable = true
  body.style.vertically_stretchable = true
  pcall(function() body.style.minimal_width = math.max(760, (panel_w or 860) - 40) end)
  pcall(function() body.style.maximal_width = math.max(760, (panel_w or 860) - 40) end)
  pcall(function() body.style.minimal_height = math.max(620, (panel_h or 820) - 60) end)
  return body, math.max(760, (panel_w or 860) - 40), math.max(620, (panel_h or 820) - 60)
end

