local Catalog=require("shared.character_skin_catalog")
local Registry=require("scripts.core.runtime_event_registry")
local Visuals=require("scripts.core.character_visuals")
local Transfer=require("scripts.core.character_skin_transfer")
local mod_gui=require("mod-gui")
local M={frame_name="tech-priests-character-picker",button_name="tech-priests-character-picker-button",input_name="tech-priests-open-character-picker"}
local installed=false
local function root()
  storage.tech_priests=storage.tech_priests or {}
  local tp=storage.tech_priests
  tp.character_skin_picker=tp.character_skin_picker or {selected={},pending={},reasons={},characters={}}
  tp.character_skin_picker.characters=tp.character_skin_picker.characters or {}
  return tp.character_skin_picker
end
function M.enabled()
  local flag=settings.startup["tech-priests-character-picker-enabled"]
  return not flag or flag.value~=false
end
function M.allowed(id)
  return id=="vanilla" or M.enabled() and Catalog.allowed(id,settings.startup)
end
function M.selected(player) return root().selected[player.index] or "vanilla" end
function M.default_skin()
  if not M.enabled() then return "vanilla" end
  if M.allowed("enginseer") then return "enginseer" end
  for _,skin in ipairs(Catalog.skins) do if M.allowed(skin.id) then return skin.id end end
  return "vanilla"
end
function M.ensure_button(player)
  -- Remove the previous upper-left mod-gui entry on upgrades.
  local legacy=mod_gui.get_button_flow(player)[M.button_name]
  if legacy and legacy.valid then legacy.destroy() end
  local button=player.gui.screen[M.button_name]
  if not M.enabled() then if button and button.valid then button.destroy() end;return end
  if not (button and button.valid) then
    button=player.gui.screen.add{type="sprite-button",name=M.button_name,style="slot_button",
      sprite="tech-priests-skin-portrait-enginseer",tooltip={"tech-priests-skins.open-hotkey"},
      tags={tech_priests_skin_action="open"}}
    button.style.width=48;button.style.height=48
  end
  local resolution=player.display_resolution
  local scale=player.display_scale
  button.location={x=math.max(0,math.floor(resolution.width-64*scale)),
    y=math.max(0,math.min(math.floor(resolution.height*.38),math.floor(resolution.height-64*scale)))}
end
function M.close(player)
  local frame=player.gui.screen[M.frame_name]
  if frame and frame.valid then
    if player.opened==frame then player.opened=nil end
    frame.destroy()
  end
end
function M.open(player)
  if not M.enabled() then player.print({"tech-priests-skins.disabled"});return false end
  M.close(player)
  local frame=player.gui.screen.add{type="frame",name=M.frame_name,direction="vertical"}
  frame.auto_center=true
  local title=frame.add{type="flow",direction="horizontal"}
  title.drag_target=frame
  title.add{type="label",caption={"tech-priests-skins.title"},style="frame_title"}.drag_target=frame
  local drag=title.add{type="empty-widget",style="draggable_space_header"}
  drag.style.horizontally_stretchable=true
  drag.drag_target=frame
  title.add{type="sprite-button",sprite="utility/close",style="frame_action_button",
    tags={tech_priests_skin_action="close"},tooltip={"gui.close"}}
  frame.add{type="label",caption={"tech-priests-skins.cosmetic"}}
  local current=M.selected(player)
  local name=Catalog.by_id[current] and Catalog.by_id[current].label or {"tech-priests-skins.vanilla"}
  frame.add{type="label",caption={"tech-priests-skins.current",name}}
  local pending=root().pending[player.index]
  if pending then frame.add{type="label",caption={"tech-priests-skins.queued",Catalog.by_id[pending] and Catalog.by_id[pending].label or {"tech-priests-skins.vanilla"}}} end
  local pane=frame.add{type="scroll-pane",direction="vertical"}
  pane.style.maximal_height=610
  pane.style.minimal_width=620
  local grid=pane.add{type="table",column_count=4}
  local function card(id,label,sprite,faction)
    local box=grid.add{type="frame",direction="vertical"}
    box.style.width=145
    local button=box.add{type="sprite-button",sprite=sprite,style="slot_button",
      tags={tech_priests_skin_action="choose",skin=id},tooltip={"tech-priests-skins.choose",label}}
    button.style.width=112;button.style.height=112
    button.toggled=id==current
    local text=box.add{type="label",caption=label}
    text.style.single_line=false;text.style.maximal_width=132
    if faction then local description=box.add{type="label",caption=faction};description.style.font_color={.7,.7,.7};description.style.single_line=false;description.style.maximal_width=132 end
  end
  card("vanilla",{"tech-priests-skins.vanilla"},"entity/character")
  local added={}
  for _,id in ipairs({"enginseer","datasmith","manipulus","dominus"}) do
    local skin=Catalog.by_id[id]
    if M.allowed(id) then card(id,skin.label,"tech-priests-skin-portrait-"..id,skin.faction);added[id]=true end
  end
  for _,skin in ipairs(Catalog.skins) do
    if not added[skin.id] and M.allowed(skin.id) then card(skin.id,skin.label,"tech-priests-skin-portrait-"..skin.id,skin.faction) end
  end
  player.opened=frame
  return true
end
function M.try_pending(player)
  local r=root()
  local id=r.pending[player.index]
  if not id then return true end
  if not M.allowed(id) then r.pending[player.index]=nil;return false,"restricted" end
  local character=Visuals.player_character(player)
  if not (character and character.valid) then return false,"no-character" end
  local target=id=="vanilla" and "character" or Transfer.host_name
  local ok,reason
  if character.name==target then ok=true
  else ok,reason=Transfer.switch(player,target) end
  if not ok then r.reasons[player.index]=reason;return false,reason end
  r.selected[player.index]=id
  r.characters[player.index]=player.character or character
  r.pending[player.index]=nil
  r.reasons[player.index]=nil
  if id~="vanilla" then Visuals.refresh_player(player,id) end
  return true
end
function M.choose(player,id)
  if not M.allowed(id) then return false,"restricted" end
  local r=root()
  r.pending[player.index]=id
  local ok,reason=M.try_pending(player)
  if not ok and (reason=="other-character" or reason=="transfer" or reason=="placement") then
    r.pending[player.index]=nil
    return false,reason
  end
  return true,ok and "applied" or "queued"
end
function M.pending_tick()
  local tp=storage.tech_priests
  local r=tp and tp.character_skin_picker
  if not r then return end
  for index in pairs(r.pending) do
    local player=game.get_player(index)
    if player and player.valid then
      local ok=M.try_pending(player)
      if ok and player.gui.screen[M.frame_name] then M.open(player) end
    end
  end
end
local function player_event(event)
  local player=game.get_player(event.player_index)
  if not (player and player.valid) then return end
  if Transfer.in_progress(player.index) then return end
  M.ensure_button(player)
  local r=root()
  local selected=r.selected[player.index]
  -- An absent choice is a first use, including saves upgraded from a package
  -- without the picker. An explicit vanilla choice remains a saved choice.
  if selected==nil and not r.pending[player.index] then
    r.pending[player.index]=M.default_skin()
  end
  if not r.pending[player.index] and selected and selected~="vanilla" then
    r.pending[player.index]=M.allowed(selected) and selected or "vanilla"
  end
  M.try_pending(player)
end
local function initialize()
  root()
  for _,player in pairs(game.players) do player_event{player_index=player.index} end
end
M.restore_player=function(player) player_event{player_index=player.index} end
local function click(event)
  local element=event.element
  if not (element and element.valid) then return end
  local tags=element.tags
  local action=tags and tags.tech_priests_skin_action
  if not action then return end
  local player=game.get_player(event.player_index)
  if action=="open" then M.open(player)
  elseif action=="close" then M.close(player)
  elseif action=="choose" then
    local ok,reason=M.choose(player,tostring(tags.skin or ""))
    if not ok then player.print({"tech-priests-skins.error-"..reason}) end
    M.open(player)
  end
  return true
end
function M.install()
  if installed then return true end
  installed=true
  assert(Visuals.install())
  Visuals.set_pending_processor(M.pending_tick)
  Registry.on_init(initialize,{owner="character_skin_picker",route="initialize",category="gui",priority=500})
  Registry.on_configuration_changed(initialize,{owner="character_skin_picker",route="settings-migration",category="gui",priority=500})
  Registry.on_event({defines.events.on_player_created,defines.events.on_player_joined_game,
    defines.events.on_player_respawned,defines.events.on_player_controller_changed,
    defines.events.on_player_driving_changed_state},player_event,nil,{owner="character_skin_picker",route="player-lifecycle",category="gui",priority=500})
  Registry.on_event(M.input_name,function(event)
    local player=game.get_player(event.player_index)
    if player and player.valid then M.open(player) end
  end,nil,{owner="character_skin_picker",route="picker-hotkey",category="gui"})
  local display_events={defines.events.on_player_display_resolution_changed,defines.events.on_player_display_scale_changed}
  if defines.events.on_player_display_density_scale_changed then
    display_events[#display_events+1]=defines.events.on_player_display_density_scale_changed
  end
  Registry.on_event(display_events,function(event)
    local player=game.get_player(event.player_index)
    if player and player.valid then M.ensure_button(player) end
  end,nil,{owner="character_skin_picker",route="picker-button-position",category="gui"})
  Registry.on_event(defines.events.on_gui_click,click,nil,{owner="character_skin_picker",route="picker-click",category="gui",priority=-100,stop_on_truthy=true})
  Registry.on_event(defines.events.on_gui_closed,function(event)
    if event.element and event.element.valid and event.element.name==M.frame_name then M.close(game.get_player(event.player_index));return true end
  end,nil,{owner="character_skin_picker",route="close-picker",category="gui",stop_on_truthy=true})
  return true
end
return M
