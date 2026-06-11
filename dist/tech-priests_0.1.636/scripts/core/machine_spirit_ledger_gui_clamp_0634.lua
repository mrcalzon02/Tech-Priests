-- scripts/core/machine_spirit_ledger_gui_clamp_0634.lua
-- Tech Priests 0.1.634
--
-- Post-build containment clamp for the Machine-Spirit State Ledger. The 0567
-- sliced cogitator shell is intentionally ornate, but the inner work ledger was
-- allowed to demand wider content than the shell body, causing bleed and an
-- extra dark inner frame on wide/manual-DPI displays.

local M = {}
M.version = "0.1.634"
M.storage_key = "machine_spirit_ledger_gui_clamp_0634"

local FRAME_NAME = "tech_priests_consecration_history_0422"
local INNER_SCREEN = "tech_priests_machine_spirit_inner_screen_0565"

local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version=M.version, enabled=true, stats={} }
  storage.tech_priests[M.storage_key] = r
  r.version=M.version
  if r.enabled == nil then r.enabled=true end
  r.stats=r.stats or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end

local function children_of(e)
  local ok, children = pcall(function() return e.children end)
  if ok and type(children)=="table" then return children end
  return {}
end

local function set_width(e, width)
  if not (valid(e) and e.style and width) then return end
  pcall(function() e.style.width = width end)
  pcall(function() e.style.minimal_width = width end)
  pcall(function() e.style.maximal_width = width end)
end

local function set_max_width(e, width)
  if not (valid(e) and e.style and width) then return end
  pcall(function() e.style.maximal_width = width end)
  pcall(function() if e.style.minimal_width and e.style.minimal_width > width then e.style.minimal_width = width end end)
end

local function set_height_bounds(e, height)
  if not (valid(e) and e.style and height) then return end
  pcall(function() e.style.maximal_height = height end)
  pcall(function() if e.style.minimal_height and e.style.minimal_height > height then e.style.minimal_height = height end end)
end

local function clamp_tree(e, depth)
  if not valid(e) or (depth or 0) > 48 then return end
  local name = ""
  pcall(function() name = e.name or "" end)
  local typ = ""
  pcall(function() typ = e.type or "" end)

  if name == INNER_SCREEN then
    -- The outer sliced bezel already provides the frame. Make this layer purely
    -- a content host so we do not draw a redundant heavy inner frame.
    pcall(function() e.style = "invisible_frame" end)
    pcall(function() e.style.padding = 0 end)
    set_width(e, 692)
    set_height_bounds(e, 640)
    stat("inner_screen_clamped")
  elseif name == "tech_priests_machine_spirit_tabs_0526" then
    set_width(e, 680)
    set_height_bounds(e, 620)
    stat("tabs_clamped")
  elseif name:find("machine_spirit_", 1, true) or name:find("consecration_history", 1, true) then
    set_max_width(e, 700)
  end

  if typ == "scroll-pane" then
    set_max_width(e, 670)
    set_height_bounds(e, 610)
  elseif typ == "table" then
    pcall(function() e.style.cell_padding = 2 end)
    set_max_width(e, 660)
  elseif typ == "label" then
    set_max_width(e, 650)
    pcall(function() e.style.single_line = false end)
  end

  for _, child in pairs(children_of(e)) do clamp_tree(child, (depth or 0)+1) end
end

function M.clamp_player(player)
  if M.root().enabled == false then return false end
  local frame = player and player.valid and player.gui and player.gui.screen and player.gui.screen[FRAME_NAME] or nil
  if not valid(frame) then return false end
  set_width(frame, 920)
  pcall(function() frame.style.maximal_height = 880 end)
  clamp_tree(frame, 0)
  stat("frames_clamped")
  return true
end

function M.wrap_history_gui()
  local ok, History = pcall(require, "scripts.core.consecration.history_gui")
  if not (ok and History and type(History.open_for_player)=="function") then return false end
  if History.TECH_PRIESTS_0634_LEDGER_GUI_CLAMP_WRAPPED then return true end
  History.TECH_PRIESTS_0634_LEDGER_GUI_CLAMP_WRAPPED = true
  History.TECH_PRIESTS_0634_PRE_OPEN_FOR_PLAYER = History.open_for_player
  History.open_for_player = function(player, entity, ...)
    local result = History.TECH_PRIESTS_0634_PRE_OPEN_FOR_PLAYER(player, entity, ...)
    pcall(M.clamp_player, player)
    return result
  end
  return true
end

local function install_command()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-ledger-gui-clamp-0634") end end)
  commands.add_command("tp-ledger-gui-clamp-0634", "Tech Priests 0.1.634: clamp the open Machine-Spirit ledger GUI.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local ok = M.clamp_player(player)
    if player and player.valid then player.print("[tp-ledger-gui-clamp-0634] clamped="..safe(ok).." total="..safe(M.root().stats.frames_clamped or 0)) end
  end)
end

function M.install()
  M.root()
  M.wrap_history_gui()
  install_command()
  _G.TechPriestsMachineSpiritLedgerGuiClamp0634 = M
  if log then log("[Tech-Priests 0.1.634] Machine-Spirit ledger GUI containment clamp installed") end
  return true
end

return M