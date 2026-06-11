-- Tech Priests 0.1.324
-- Startup provisioning and player-awareness module.
-- This is the first extraction pass for player-created/player-joined startup
-- doctrine: starter station grants, delayed freeplay inventory settlement,
-- special name detection, and related player-start concerns belong here rather
-- than being scattered through control.lua.

local M = {}

M.version = "0.1.326"
M.retry_ticks = 60
M.initial_delay_ticks = 90
M.service_period = 67

M.station_kit = {
  "junior-cogitator-station",
  "intermediate-cogitator-station",
  "senior-cogitator-station",
  "planetary-magos-cogitator-station"
}

local function ensure_mod_storage()
  if _G.ensure_storage then pcall(_G.ensure_storage) end
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.starting_station_kit_granted_0324 = storage.tech_priests.starting_station_kit_granted_0324 or {}
  storage.tech_priests.pending_starting_station_kit_0324 = storage.tech_priests.pending_starting_station_kit_0324 or {}
end

local function item_exists(name)
  if not name then return false end
  if _G.get_item_prototype then
    local ok, proto = pcall(function() return _G.get_item_prototype(name) end)
    if ok and proto then return true end
  end
  if prototypes and prototypes.item then
    local ok, proto = pcall(function() return prototypes.item[name] end)
    if ok and proto then return true end
  end
  return false
end

local function safe_insert(player, stack)
  if not (player and player.valid and stack and stack.name and stack.count and stack.count > 0) then return 0 end
  if not item_exists(stack.name) then return 0 end
  if _G.safe_insert_into_player_inventory then
    local ok, inserted = pcall(function() return _G.safe_insert_into_player_inventory(player, stack) end)
    if ok and type(inserted) == "number" then return inserted end
  end
  local ok, inserted = pcall(function() return player.insert(stack) end)
  if ok and type(inserted) == "number" then return inserted end
  return 0
end

function M.grant_station_kit(player)
  if not (player and player.valid) then return false end
  ensure_mod_storage()
  local player_index = player.index
  if storage.tech_priests.starting_station_kit_granted_0324[player_index] then return true end

  local all_ok = true
  for _, station_name in ipairs(M.station_kit) do
    if item_exists(station_name) then
      local inserted = safe_insert(player, { name = station_name, count = 1 }) or 0
      if inserted <= 0 then all_ok = false end
    end
  end

  if all_ok then
    storage.tech_priests.starting_station_kit_granted_0324[player_index] = true
    storage.tech_priests.pending_starting_station_kit_0324[player_index] = nil
    if player.print then
      pcall(function()
        player.print("[Tech Priests] Starter cogitator kit issued: junior, intermediate, senior, and planetary Magos stations. Void station remains research-gated.")
      end)
    end
    return true
  end

  storage.tech_priests.pending_starting_station_kit_0324[player_index] = (game and game.tick or 0) + M.retry_ticks
  return false
end

function M.schedule(player_index, delay_ticks)
  if not player_index then return end
  ensure_mod_storage()
  storage.tech_priests.pending_starting_station_kit_0324[player_index] = (game and game.tick or 0) + math.max(1, delay_ticks or M.initial_delay_ticks)
end

function M.service_pending()
  ensure_mod_storage()
  local pending = storage.tech_priests.pending_starting_station_kit_0324
  for player_index, due_tick in pairs(pending or {}) do
    if (game and game.tick or 0) >= (due_tick or 0) then
      local player = game.get_player(player_index)
      if player and player.valid then
        if not M.grant_station_kit(player) then
          pending[player_index] = (game and game.tick or 0) + M.retry_ticks
        end
      else
        pending[player_index] = nil
      end
    end
  end
end

local function run_player_awareness(player)
  if not (player and player.valid) then return end
  if _G.tech_priests_0227_release_special_name_for_player then pcall(function() _G.tech_priests_0227_release_special_name_for_player(player) end) end
  if _G.tech_priests_0228_register_annoyatron_player then pcall(function() _G.tech_priests_0228_register_annoyatron_player(player) end) end
end

local function enable_force_startup(player)
  if player and player.valid and player.force and _G.enable_tech_priest_emergency_micro_industry_for_force then
    pcall(function() _G.enable_tech_priest_emergency_micro_industry_for_force(player.force) end)
  end
end

function M.handle_player_created(event)
  if not (event and event.player_index) then return end
  local player = game.get_player(event.player_index)
  enable_force_startup(player)
  run_player_awareness(player)
  -- 0.1.467: do not schedule the older Senior-only starter bonus. The one-of-each
  -- non-void station kit below is now the sole station-startup authority.
  M.schedule(event.player_index, M.initial_delay_ticks)
end

function M.handle_player_joined(event)
  if not (event and event.player_index) then return end
  local player = game.get_player(event.player_index)
  enable_force_startup(player)
  run_player_awareness(player)
  if player and player.valid then
    -- Joining an existing save should repair missing starter grants but should not
    -- duplicate them because grant tables are per-player-index.
    -- 0.1.467: do not call the older Senior-only grant helper on join.
    M.schedule(event.player_index, M.initial_delay_ticks)
  end
end

function M.install()
  -- Do not touch storage at install/load time; storage is initialized safely
  -- from runtime event callbacks and the grant/schedule service paths.

  if _G.grant_tech_priest_first_spawn_bonus and not _G.TECH_PRIESTS_0324_PRE_GRANT_FIRST_SPAWN_BONUS then
    _G.TECH_PRIESTS_0324_PRE_GRANT_FIRST_SPAWN_BONUS = _G.grant_tech_priest_first_spawn_bonus
    _G.grant_tech_priest_first_spawn_bonus = function(player)
      -- 0.1.467: the legacy helper used to insert one extra Senior station. Keep
      -- this compatibility function as a redirect to the intended one-of-each kit.
      return M.grant_station_kit(player)
    end
  end

  if script and script.on_event and defines and defines.events then
    script.on_event(defines.events.on_player_created, M.handle_player_created)
    script.on_event(defines.events.on_player_joined_game, M.handle_player_joined)
  end

  if script and script.on_nth_tick then
    script.on_nth_tick(M.service_period, function()
      M.service_pending()
    end)
  end

  if game and game.players then
    for _, player in pairs(game.players) do
      if player and player.valid then
        M.schedule(player.index, M.initial_delay_ticks)
        run_player_awareness(player)
      end
    end
  end

  if commands and commands.add_command then
    pcall(function()
      commands.add_command("tp-startup-0324", "Tech Priests: inspect/repair 0.1.324 startup station provisioning for this player.", function(event)
        local player = game and game.get_player(event.player_index)
        if not player then return end
        ensure_mod_storage()
        local granted = storage.tech_priests.starting_station_kit_granted_0324[player.index]
        player.print("[Tech Priests 0.1.324] station-kit-granted=" .. tostring(granted) .. " pending=" .. tostring(storage.tech_priests.pending_starting_station_kit_0324[player.index] or "none"))
        if not granted then M.grant_station_kit(player) end
      end)
    end)
    pcall(function()
      commands.add_command("tp-startup-0326", "Tech Priests: inspect/repair 0.1.326 freeplay non-void station kit for this player.", function(event)
        local player = game and game.get_player(event.player_index)
        if not player then return end
        ensure_mod_storage()
        local granted = storage.tech_priests.starting_station_kit_granted_0324[player.index]
        player.print("[Tech Priests 0.1.326] freeplay-station-kit-granted=" .. tostring(granted) .. " pending=" .. tostring(storage.tech_priests.pending_starting_station_kit_0324[player.index] or "none") .. " kit=junior,intermediate,senior,planetary-magos; void=false")
        if not granted then M.grant_station_kit(player) end
      end)
    end)
  end

  if log then log("[Tech-Priests 0.1.324] startup provisioning/player-awareness module installed") end
end

return M
