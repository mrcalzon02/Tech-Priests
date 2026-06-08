-- scripts/core/status_display_authority_0459.lua
-- Tech Priests 0.1.459 - canonical overhead status display governor.
-- Keeps legacy emergency/status bubbles from contradicting the Cogitator Work
-- State panel after a pair has returned to idle/no-managed-priority-claimed.

local M = {}
M.version = "0.1.459"
M.installed = false

local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end

local function idle_like(mode)
  mode = tostring(mode or "")
  return mode == "" or mode == "idle" or mode == "no-managed-priority-claimed" or mode == "scheduler-0277" or mode == "no-managed-priority"
end

local function canonical_mode(pair)
  if not pair then return "idle" end
  return tostring(pair.visual_state_0276 or pair.mode or "idle")
end

local function has_active_task(pair)
  if not pair then return false end
  local task = pair.active_task or pair.active_task_0285
  if type(task) == "table" then return tostring(task.type or task.kind or "") ~= "idle" end
  if task ~= nil and task ~= false and tostring(task) ~= "idle" then return true end
  local kind = tostring(pair.task_kind_0276 or "")
  if kind ~= "" and kind ~= "idle" then return true end
  return false
end

function M.is_workstate_idle(pair)
  if not pair then return true end
  if not idle_like(canonical_mode(pair)) then return false end
  if has_active_task(pair) then return false end
  return true
end

local function destroy_channel(pair, channel)
  if not pair then return end
  pair.tech_priests_status_render_0215 = pair.tech_priests_status_render_0215 or {}
  local obj = pair.tech_priests_status_render_0215[channel]
  if obj then pcall(function() if obj.valid then obj.destroy() end end) end
  pair.tech_priests_status_render_0215[channel] = nil
end

local function should_suppress(pair, text)
  local lower = string.lower(tostring(text or ""))
  if lower:find("no%-managed%-priority%-claimed", 1, false) then return true end
  if lower:find("placing emergency facility", 1, false) and M.is_workstate_idle(pair) then return true end
  if lower:find("emergency facility", 1, false) and M.is_workstate_idle(pair) then return true end
  return false
end

local function draw_status(pair, text, color, ttl, scale, channel)
  channel = channel or "emergency"
  if should_suppress(pair, text) then
    destroy_channel(pair, channel)
    return true
  end
  if _G.tech_priests_draw_stacked_status_text_0211 then
    return _G.tech_priests_draw_stacked_status_text_0211(pair, text, color, ttl, scale, channel)
  end
  if not (pair and valid(pair.priest) and text and rendering and rendering.draw_text) then return false end
  local ok, obj = pcall(function()
    return rendering.draw_text({
      text = tostring(text),
      target = { entity = pair.priest, offset = { 0, -2.70 } },
      surface = pair.priest.surface,
      color = color or { r = 1.0, g = 0.55, b = 0.12, a = 0.88 },
      scale = scale or 0.54,
      alignment = "center",
      time_to_live = ttl or 90,
      use_rich_text = true
    })
  end)
  if ok and obj then
    pair.tech_priests_status_render_0215 = pair.tech_priests_status_render_0215 or {}
    pair.tech_priests_status_render_0215[channel] = obj
  end
  return ok
end

function M.install()
  if M.installed then return true end
  _G.TECH_PRIESTS_STATUS_DISPLAY_AUTHORITY_0459 = M
  _G.tech_priests_is_pair_workstate_idle_0459 = M.is_workstate_idle
  _G.tech_priests_draw_emergency_operation_status_0184 = function(pair, text)
    return draw_status(pair, text, { r = 1.0, g = 0.55, b = 0.12, a = 0.88 }, 90, 0.54, "emergency")
  end
  _G.tech_priests_task_force_snippet_0187 = function(pair, text)
    return draw_status(pair, text, { r = 1.0, g = 0.78, b = 0.22, a = 0.88 }, 110, 0.52, "task-force")
  end
  if commands and commands.add_command then
    pcall(function() if commands.remove_command then commands.remove_command("tp-status-display-0459") end end)
    pcall(function()
      commands.add_command("tp-status-display-0459", "Tech Priests 0.1.459: report selected pair overhead/workstate display authority.", function(event)
        local player = event and event.player_index and game.get_player(event.player_index) or nil
        local selected = player and player.valid and player.selected or nil
        local pair = nil
        if selected and selected.valid and storage and storage.tech_priests then
          local unit = selected.unit_number
          if unit then
            pair = (storage.tech_priests.pairs_by_station or {})[unit] or (storage.tech_priests.pairs_by_priest or {})[unit]
            if not pair and storage.tech_priests.station_by_priest and storage.tech_priests.station_by_priest[unit] then
              pair = (storage.tech_priests.pairs_by_station or {})[storage.tech_priests.station_by_priest[unit]]
            end
          end
        end
        if not (player and player.valid) then return end
        if not pair then player.print("[tp-status-display-0459] no selected/hovered tracked pair."); return end
        player.print("[tp-status-display-0459] mode=" .. safe(pair.mode) .. " visual=" .. safe(pair.visual_state_0276) .. " kind=" .. safe(pair.task_kind_0276) .. " active=" .. safe(pair.active_task and (type(pair.active_task) == "table" and (pair.active_task.type or pair.active_task.kind) or pair.active_task)) .. " workstate_idle=" .. safe(M.is_workstate_idle(pair)))
      end)
    end)
  end
  M.installed = true
  if log then log("[Tech-Priests 0.1.459] overhead status display authority installed") end
  return true
end

return M
