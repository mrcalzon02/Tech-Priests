-- scripts/core/gui_nested_frame_repair_0635.lua
-- Tech Priests 0.1.635
--
-- Structural GUI repair for Cogitator/ledger panels. The first outer reliquary
-- shell remains ornate. Nested menu/content surfaces are flattened so the UI no
-- longer draws display-frame-inside-display-frame stacks. The shared inner panel
-- asset registered as tech-priests-gui-inner-panel-0635 is kept available for
-- future full background conversion; this runtime pass removes the redundant
-- native inner frames and clamps their content surfaces now.

local M = {}
M.version = "0.1.635"
M.storage_key = "gui_nested_frame_repair_0635"

local HISTORY_FRAME = "tech_priests_consecration_history_0422"
local WORKSTATE_FRAME = "tech_priests_workstate_reliquary_0358"
local INNER_SPRITE = "tech-priests-gui-inner-panel-0635"

local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function children(e) local ok,c=pcall(function() return e.children end); if ok and type(c)=="table" then return c end; return {} end
local function elem_name(e) local ok,n=pcall(function() return e.name end); return ok and tostring(n or "") or "" end
local function elem_type(e) local ok,t=pcall(function() return e.type end); return ok and tostring(t or "") or "" end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version=M.version, enabled=true, stats={}, recent={} }
  storage.tech_priests[M.storage_key]=r
  r.version=M.version
  if r.enabled == nil then r.enabled=true end
  r.stats=r.stats or {}; r.recent=r.recent or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(action, detail)
  local r=M.root(); stat(action)
  r.recent[#r.recent+1]={tick=game and game.tick or 0, action=tostring(action or "event"), detail=tostring(detail or "")}
  while #r.recent>60 do table.remove(r.recent,1) end
end

local function set_width(e, w)
  if not (valid(e) and e.style and w) then return end
  pcall(function() e.style.width = w end)
  pcall(function() e.style.minimal_width = w end)
  pcall(function() e.style.maximal_width = w end)
end
local function set_max_width(e, w)
  if not (valid(e) and e.style and w) then return end
  pcall(function() e.style.maximal_width = w end)
  pcall(function() if e.style.minimal_width and e.style.minimal_width > w then e.style.minimal_width = w end end)
end
local function set_max_height(e, h)
  if not (valid(e) and e.style and h) then return end
  pcall(function() e.style.maximal_height = h end)
  pcall(function() if e.style.minimal_height and e.style.minimal_height > h then e.style.minimal_height = h end end)
end

local function flatten_redundant_frame(e, target_w, target_h)
  if not valid(e) then return end
  -- The authored slice shell is already the frame. These are the extra native
  -- frames causing the visible second nested menu and right-side bleed.
  pcall(function() e.style = "invisible_frame" end)
  pcall(function() e.style.padding = 0 end)
  pcall(function() e.style.margin = 0 end)
  set_width(e, target_w)
  set_max_height(e, target_h)
  stat("native_inner_frames_flattened")
end

local function clamp_subtree(e, target_w, target_h, depth)
  if not valid(e) or (depth or 0) > 64 then return end
  local name = elem_name(e)
  local typ = elem_type(e)

  if name == "tech_priests_machine_spirit_gui_body_0567" or
     name == "tech_priests_machine_spirit_inner_screen_0565" or
     name == "tech_priests_workstate_gui_body_0536" or
     name == "tech_priests_workstate_gui_body_0487" then
    flatten_redundant_frame(e, target_w, target_h)
  elseif typ == "scroll-pane" then
    set_max_width(e, target_w - 22)
    set_max_height(e, target_h - 62)
    pcall(function() e.style.padding = 4 end)
  elseif typ == "tabbed-pane" then
    set_width(e, target_w - 12)
    set_max_height(e, target_h - 42)
  elseif typ == "table" then
    set_max_width(e, target_w - 34)
    pcall(function() e.style.cell_padding = 2 end)
  elseif typ == "label" then
    set_max_width(e, target_w - 44)
    pcall(function() e.style.single_line = false end)
  elseif typ == "flow" then
    set_max_width(e, target_w)
  end

  for _, child in pairs(children(e)) do clamp_subtree(child, target_w, target_h, (depth or 0)+1) end
end

local function frame_by_name(player, name)
  return player and player.valid and player.gui and player.gui.screen and player.gui.screen[name] or nil
end

function M.repair_machine_spirit(player)
  if M.root().enabled == false then return false end
  local frame = frame_by_name(player, HISTORY_FRAME)
  if not valid(frame) then return false end
  set_width(frame, 900)
  set_max_height(frame, 880)
  clamp_subtree(frame, 680, 650, 0)
  record("machine-spirit-ledger-structural-repair", "outer=900 inner=680")
  return true
end

function M.repair_workstate(player)
  if M.root().enabled == false then return false end
  local frame = frame_by_name(player, WORKSTATE_FRAME)
  if not valid(frame) then return false end
  set_width(frame, 1100)
  set_max_height(frame, 960)
  clamp_subtree(frame, 850, 720, 0)
  record("workstate-reliquary-structural-repair", "outer=1100 inner=850")
  return true
end

function M.repair_player(player)
  local a = M.repair_machine_spirit(player)
  local b = M.repair_workstate(player)
  return a or b
end

function M.wrap_guis()
  local ok_h, History = pcall(require, "scripts.core.consecration.history_gui")
  if ok_h and History and type(History.open_for_player)=="function" and not History.TECH_PRIESTS_0635_STRUCTURAL_GUI_WRAPPED then
    History.TECH_PRIESTS_0635_STRUCTURAL_GUI_WRAPPED = true
    History.TECH_PRIESTS_0635_PRE_OPEN_FOR_PLAYER = History.open_for_player
    History.open_for_player = function(player, entity, ...)
      local result = History.TECH_PRIESTS_0635_PRE_OPEN_FOR_PLAYER(player, entity, ...)
      pcall(M.repair_machine_spirit, player)
      return result
    end
  end
  local ok_w, Work = pcall(require, "scripts.core.station_work_inventory")
  if ok_w and Work and type(Work.show_gui)=="function" and not Work.TECH_PRIESTS_0635_STRUCTURAL_GUI_WRAPPED then
    Work.TECH_PRIESTS_0635_STRUCTURAL_GUI_WRAPPED = true
    Work.TECH_PRIESTS_0635_PRE_SHOW_GUI = Work.show_gui
    Work.show_gui = function(player, pair, selected_tab_index, ...)
      local result = Work.TECH_PRIESTS_0635_PRE_SHOW_GUI(player, pair, selected_tab_index, ...)
      pcall(M.repair_workstate, player)
      return result
    end
  end
  return true
end

local function install_command()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-gui-structural-repair-0635") end end)
  commands.add_command("tp-gui-structural-repair-0635", "Tech Priests 0.1.635: flatten nested ledger/workstate frames for the current player.", function(event)
    local player=event and event.player_index and game.get_player(event.player_index) or nil
    local ok=M.repair_player(player)
    if player and player.valid then player.print("[tp-gui-structural-repair-0635] repaired="..safe(ok).." flattened="..safe(M.root().stats.native_inner_frames_flattened or 0).." inner_sprite="..INNER_SPRITE) end
  end)
end

function M.install()
  M.root()
  M.wrap_guis()
  install_command()
  _G.TechPriestsGuiNestedFrameRepair0635 = M
  if log then log("[Tech-Priests 0.1.635] nested GUI frame structural repair installed; inner menus flattened after outer reliquary shell") end
  return true
end

return M