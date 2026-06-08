-- scripts/core/startup_catalog_authority_0467.lua
-- Tech Priests 0.1.467
-- Final authority shim for two legacy overlaps:
--   1. The pre-0.1.324 first-spawn bonus still inserted one extra Senior
--      Cogitator Station on top of the newer one-of-each non-void station kit.
--   2. The old standalone Known Resources GUI still auto-opened as its own
--      "Refresh radar catalog" window, even though the catalog now belongs inside
--      the Cogitator Dictator Work State tabbed display.

local M = {}
M.version = "0.1.467"

local function ensure_mod_storage()
  if _G.ensure_storage then pcall(_G.ensure_storage) end
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.starting_bonus_granted_by_player_index = storage.tech_priests.starting_bonus_granted_by_player_index or {}
  storage.tech_priests.starting_field_kit_granted_0266 = storage.tech_priests.starting_field_kit_granted_0266 or {}
  storage.tech_priests.pending_starting_bonus_by_player_index_0190 = storage.tech_priests.pending_starting_bonus_by_player_index_0190 or {}
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

local function oil_name()
  if _G.tech_priests_0266_get_oil_name then
    local ok, name = pcall(_G.tech_priests_0266_get_oil_name)
    if ok and name then return name end
  end
  if _G.SACRED_OIL_NAME then return _G.SACRED_OIL_NAME end
  if item_exists("sacred-machine-oil") then return "sacred-machine-oil" end
  return nil
end

local function ammo_name()
  if _G.tech_priests_0266_get_ammo_name then
    local ok, name = pcall(_G.tech_priests_0266_get_ammo_name)
    if ok and name then return name end
  end
  if _G.get_starting_bonus_ammo_name then
    local ok, name = pcall(_G.get_starting_bonus_ammo_name)
    if ok and name then return name end
  end
  if item_exists("firearm-magazine") then return "firearm-magazine" end
  return nil
end

local function grant_field_supplies_only(player)
  if not (player and player.valid) then return false end
  ensure_mod_storage()
  local player_index = player.index

  -- Mark the old 0.1.190 station-bonus ledger as satisfied so its retry queue
  -- cannot keep attempting to insert STARTING_BONUS_STATION_NAME. The new
  -- station kit has a separate 0.1.324 ledger and remains authoritative.
  storage.tech_priests.starting_bonus_granted_by_player_index[player_index] = true
  storage.tech_priests.pending_starting_bonus_by_player_index_0190[player_index] = nil

  if storage.tech_priests.starting_field_kit_granted_0266[player_index] then return true end

  safe_insert(player, { name = "repair-pack", count = _G.STARTING_BONUS_MULTIPLAYER_REPAIR_PACKS or 10 })
  local oil = oil_name()
  if oil then safe_insert(player, { name = oil, count = _G.STARTING_BONUS_MULTIPLAYER_SACRED_OIL or 10 }) end
  local ammo = ammo_name()
  if ammo then
    local count = 100
    if _G.get_item_prototype then
      local ok, proto = pcall(function() return _G.get_item_prototype(ammo) end)
      if ok and proto and proto.stack_size then count = math.max(1, proto.stack_size) end
    end
    safe_insert(player, { name = ammo, count = count })
  end
  storage.tech_priests.starting_field_kit_granted_0266[player_index] = true
  return true
end

local function install_startup_authority()
  _G.TECH_PRIESTS_0467_LEGACY_STATION_BONUS_DISABLED = true
  _G.TECH_PRIESTS_0467_PRE_GRANT_FIRST_SPAWN_BONUS = _G.grant_tech_priest_first_spawn_bonus

  _G.grant_tech_priest_first_spawn_bonus = function(player)
    return grant_field_supplies_only(player)
  end

  _G.schedule_tech_priest_first_spawn_bonus_0190 = function(player_index, delay_ticks)
    if not player_index then return false end
    ensure_mod_storage()
    -- The old delayed Senior-only queue is intentionally drained. The 0.1.324
    -- startup_station_kit queue still grants Junior/Intermediate/Senior/Magos.
    storage.tech_priests.pending_starting_bonus_by_player_index_0190[player_index] = nil
    return false
  end

  _G.service_tech_priest_starting_bonus_queue_0190 = function()
    ensure_mod_storage()
    for k in pairs(storage.tech_priests.pending_starting_bonus_by_player_index_0190 or {}) do
      storage.tech_priests.pending_starting_bonus_by_player_index_0190[k] = nil
    end
  end
end

local function clear_catalog_window(player)
  if not (player and player.valid and player.gui and player.gui.screen) then return end
  for _, name in ipairs({ "tech_priests_known_resources_0326", "tech_priests_known_resources_frame_0326" }) do
    local frame = player.gui.screen[name]
    if frame and frame.valid then frame.destroy() end
  end
end

local function install_catalog_window_suppression()
  local ok, Catalog = pcall(require, "scripts.core.station_catalog")
  if ok and Catalog then
    Catalog.show_gui = function(player, pair)
      clear_catalog_window(player)
      return false
    end
  end

  -- These globals are left present for compatibility, but the standalone window
  -- path is suppressed. Catalog scanning remains available through
  -- tech_priests_0327_scan_station_catalog / get_station_catalog and through the
  -- Dictator Work State Known Resources tab.
  _G.tech_priests_0327_catalog_gui_opened = function(event)
    local player = event and event.player_index and game and game.get_player(event.player_index) or nil
    clear_catalog_window(player)
    if _G.tech_priests_0313_on_gui_opened then pcall(_G.tech_priests_0313_on_gui_opened, event) end
    return false
  end
end

function M.install()
  install_startup_authority()
  install_catalog_window_suppression()
  if log then log("[Tech-Priests 0.1.467] startup inventory and standalone catalog-window authority installed") end
  return true
end

return M
