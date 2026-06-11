-- scripts/core/visual_lease_cleanup_0487.lua
-- Tech Priests 0.1.487
-- Final lease cleanup for station radius circles and connection lines.  These
-- overlays are context tools, not permanent map decoration: they remain while
-- selecting/hovering a Cogitator/Priest or holding a Cogitator station, then
-- decay/clear promptly once the context ends.

local M = {}
M.version = "0.1.487"
M.storage_key = "visual_lease_cleanup_0487"
M.tick_interval = 10
M.overlay_ttl = 75
M.redraw_period = 45

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function lower(v) return string.lower(tostring(v or "")) end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  return r
end

local function stat(k, d) local r = root(); r.stats[k] = (r.stats[k] or 0) + (d or 1) end

local function held_station_name(player)
  if not (player and player.valid) then return nil end
  local stack = player.cursor_stack
  if stack and stack.valid_for_read then
    local name = tostring(stack.name or "")
    if name:find("cogitator%-station") then return name end
  end
  return nil
end

local function selected_is_station_or_priest(player)
  local e = player and player.valid and player.selected or nil
  if not valid(e) then return false end
  local n = tostring(e.name or "")
  return n:find("cogitator%-station") ~= nil or n:find("tech%-priest") ~= nil or n:find("magos%-tech%-priest") ~= nil
end

local function alt_enabled(player)
  local ok, value = pcall(function() return player.game_view_settings and player.game_view_settings.show_entity_info end)
  return ok and value == true
end

local function destroy_list(list)
  if not list then return end
  for _, obj in pairs(list) do
    pcall(function() if obj and obj.valid then obj.destroy() end end)
  end
end

function M.patch_visual_authority()
  local vis = rawget(_G, "TECH_PRIESTS_ALT_WRIT_VISUAL_STABILITY_0474")
  if vis then
    vis.ttl = M.overlay_ttl
    vis.redraw_period = M.redraw_period
    vis.refresh_period = math.min(tonumber(vis.refresh_period or M.tick_interval) or M.tick_interval, M.tick_interval)
  end
end

function M.clear_player_overlays(player, redraw_alt_icons)
  if not (player and player.valid and storage and storage.tech_priests) then return false end
  local vroot = storage.tech_priests.alt_writ_visual_stability_0474
  if not vroot then return false end
  local list = vroot.objects_by_player and vroot.objects_by_player[player.index]
  if list then
    destroy_list(list)
    vroot.objects_by_player[player.index] = nil
    stat("objects_cleared")
  end
  if vroot.signature_by_player then vroot.signature_by_player[player.index] = nil end
  if redraw_alt_icons then
    local vis = rawget(_G, "TECH_PRIESTS_ALT_WRIT_VISUAL_STABILITY_0474")
    if vis and type(vis.refresh_player) == "function" then pcall(vis.refresh_player, player) end
  end
  return true
end

function M.tick()
  local r = root()
  if r.enabled == false or not (game and game.connected_players) then return end
  M.patch_visual_authority()
  for _, player in pairs(game.connected_players) do
    if player and player.valid then
      local context = selected_is_station_or_priest(player) or held_station_name(player) ~= nil
      if context then
        r.stats.last_context_tick = now()
      else
        -- Clear station radius circles, interstation lines, and station-priest
        -- links as soon as there is no selection/placement context.  If Alt
        -- mode is active, immediately redraw Alt-only station writ icons; the
        -- 0.1.474 authority will not redraw radius/link overlays without context.
        M.clear_player_overlays(player, alt_enabled(player))
      end
    end
  end
end

function M.describe()
  local r = root()
  return "enabled=" .. tostring(r.enabled) .. " ttl=" .. tostring(M.overlay_ttl) .. " redraw=" .. tostring(M.redraw_period) .. " cleared=" .. tostring(r.stats.objects_cleared or 0)
end

function M.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-visual-lease-0487") end end)
  pcall(function()
    commands.add_command("tp-visual-lease-0487", "Tech Priests: inspect or force-clear Cogitator radius/link visual leases.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      local p = lower(event and event.parameter or "status")
      local r = root()
      if p == "off" or p == "disable" then r.enabled = false end
      if p == "on" or p == "enable" then r.enabled = true end
      if p == "clear" and player then M.clear_player_overlays(player, alt_enabled(player)) end
      if player and player.valid then player.print("[tp-visual-lease-0487] " .. M.describe()) end
    end)
  end)
end

function M.install()
  if M._installed then return true end
  M._installed = true
  root()
  M.patch_visual_authority()
  _G.TECH_PRIESTS_VISUAL_LEASE_CLEANUP_0487 = M
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(M.tick_interval, function() M.tick() end, { owner = "visual_lease_cleanup_0487", category = "visuals", priority = "last" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(M.tick_interval, function() M.tick() end) end)
  end
  if registry and registry.on_event and defines and defines.events then
    if defines.events.on_selected_entity_changed then registry.on_event(defines.events.on_selected_entity_changed, function(event) local p = game.get_player(event.player_index); if p then M.tick() end end, nil, { owner = "visual_lease_cleanup_0487", category = "visuals", priority = "last" }) end
    if defines.events.on_player_cursor_stack_changed then registry.on_event(defines.events.on_player_cursor_stack_changed, function(event) local p = game.get_player(event.player_index); if p then M.tick() end end, nil, { owner = "visual_lease_cleanup_0487", category = "visuals", priority = "last" }) end
  end
  M.register_commands()
  if log then log("[Tech-Priests 0.1.487] visual lease cleanup installed; station radius and link lines decay after context ends") end
  return true
end

return M
