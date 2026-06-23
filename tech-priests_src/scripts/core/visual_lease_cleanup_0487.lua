-- scripts/core/visual_lease_cleanup_0487.lua
-- Tech Priests 0.1.663
-- Final lease cleanup for station radius circles and connection lines. These
-- overlays are context tools, not permanent map decoration: they remain while
-- selecting/hovering a Cogitator/Priest or holding a Cogitator station, then
-- decay/clear promptly once the context ends. This late visual authority also
-- installs the aggregate claimed-resource field map and centralized range buff.

local M = {}
M.version = "0.1.663"
M.storage_key = "visual_lease_cleanup_0487"
M.tick_interval = 10
M.overlay_ttl = 75
M.redraw_period = 45

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
  }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  return r
end

local function stat(key, amount)
  local r = root()
  r.stats[key] = (r.stats[key] or 0) + (amount or 1)
end

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
  local entity = player and player.valid and player.selected or nil
  if not valid(entity) then return false end
  local name = tostring(entity.name or "")
  return name:find("cogitator%-station") ~= nil
    or name:find("tech%-priest") ~= nil
    or name:find("magos%-tech%-priest") ~= nil
end

local function alt_enabled(player)
  local ok, value = pcall(function()
    return player.game_view_settings and player.game_view_settings.show_entity_info
  end)
  return ok and value == true
end

local function destroy_list(list)
  if not list then return end
  for _, object in pairs(list) do
    pcall(function()
      if object and object.valid then object.destroy() end
    end)
  end
end

local function install_module(module_name, label)
  local ok, module = pcall(require, module_name)
  if not ok or not module or type(module.install) ~= "function" then
    if log then log("[Tech-Priests 0.1.663] " .. tostring(label) .. " unavailable: " .. tostring(module)) end
    return false
  end
  local installed, why = pcall(module.install)
  if not installed and log then
    log("[Tech-Priests 0.1.663] " .. tostring(label) .. " install failed: " .. tostring(why))
  end
  return installed
end

function M.patch_visual_authority()
  local visual = rawget(_G, "TECH_PRIESTS_ALT_WRIT_VISUAL_STABILITY_0474")
  if visual then
    visual.ttl = M.overlay_ttl
    visual.redraw_period = M.redraw_period
    visual.refresh_period = math.min(
      tonumber(visual.refresh_period or M.tick_interval) or M.tick_interval,
      M.tick_interval
    )
  end
end

function M.clear_player_overlays(player, redraw_alt_icons)
  if not (player and player.valid and storage and storage.tech_priests) then return false end
  local visual_root = storage.tech_priests.alt_writ_visual_stability_0474
  if not visual_root then return false end
  local list = visual_root.objects_by_player and visual_root.objects_by_player[player.index]
  if list then
    destroy_list(list)
    visual_root.objects_by_player[player.index] = nil
    stat("objects_cleared")
  end
  if visual_root.signature_by_player then visual_root.signature_by_player[player.index] = nil end
  if redraw_alt_icons then
    local visual = rawget(_G, "TECH_PRIESTS_ALT_WRIT_VISUAL_STABILITY_0474")
    if visual and type(visual.refresh_player) == "function" then
      pcall(visual.refresh_player, player)
    end
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
        -- Clear radius/link overlays as soon as selection/placement context ends.
        -- When ALT is active, the patched 0.1.474 refresh redraws station writs
        -- and the 0.1.663 aggregate claimed-resource fields only.
        M.clear_player_overlays(player, alt_enabled(player))
      end
    end
  end
end

function M.describe()
  local r = root()
  return "enabled=" .. tostring(r.enabled)
    .. " ttl=" .. tostring(M.overlay_ttl)
    .. " redraw=" .. tostring(M.redraw_period)
    .. " cleared=" .. tostring(r.stats.objects_cleared or 0)
end

function M.register_commands()
  -- Visual inspection is automatic through ALT mode and pair-dump diagnostics.
  -- Retire the old debug toggles rather than preserving a command-only control
  -- path that can silently disable the player-facing ownership map.
  if commands and commands.remove_command then
    pcall(commands.remove_command, "tp-visual-lease-0487")
    pcall(commands.remove_command, "tp-visual-stability-0474")
  end
end

function M.install()
  if M._installed then return true end
  M._installed = true
  root()
  M.patch_visual_authority()

  -- Range first: catalog scans and the field overlay must read the same effective
  -- operating area before the aggregate ownership map is rebuilt.
  install_module("scripts.core.station_range_authority_0680", "station_range_authority_0680")
  install_module("scripts.core.alt_resource_field_overlay_0679", "alt_resource_field_overlay_0679")

  -- The 0.1.474 renderer may already have created hundreds of per-node ALT
  -- objects before the replacement layer installed. Retire them immediately and
  -- redraw through the patched field authority instead of waiting for TTL expiry.
  local visual = rawget(_G, "TECH_PRIESTS_ALT_WRIT_VISUAL_STABILITY_0474")
  if visual and type(visual.clear_all) == "function" then pcall(visual.clear_all) end
  if visual and type(visual.refresh_all) == "function" then pcall(visual.refresh_all) end

  _G.TECH_PRIESTS_VISUAL_LEASE_CLEANUP_0487 = M
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    pcall(function() registry = require("scripts.core.runtime_event_registry") end)
  end
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(M.tick_interval, function() M.tick() end, {
      owner = "visual_lease_cleanup_0487",
      category = "visuals",
      priority = "last",
    })
  elseif script and script.on_nth_tick then
    pcall(function()
      script.on_nth_tick(M.tick_interval, function() M.tick() end)
    end)
  end
  if registry and registry.on_event and defines and defines.events then
    if defines.events.on_selected_entity_changed then
      registry.on_event(defines.events.on_selected_entity_changed, function(event)
        local player = game.get_player(event.player_index)
        if player then M.tick() end
      end, nil, {
        owner = "visual_lease_cleanup_0487",
        category = "visuals",
        priority = "last",
      })
    end
    if defines.events.on_player_cursor_stack_changed then
      registry.on_event(defines.events.on_player_cursor_stack_changed, function(event)
        local player = game.get_player(event.player_index)
        if player then M.tick() end
      end, nil, {
        owner = "visual_lease_cleanup_0487",
        category = "visuals",
        priority = "last",
      })
    end
  end
  M.register_commands()
  if log then
    log("[Tech-Priests 0.1.663] visual lease cleanup installed; aggregate ALT resource fields and +5 station range authority active")
  end
  return true
end

return M
