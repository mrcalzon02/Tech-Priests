-- Commandless player entry point. Existing physical and tactical owners execute.
local Registry=require("scripts.core.runtime_event_registry")
local Orders=require("scripts.core.combat_roster_orders")
local C=require("shared.combat_roster_catalog")
local mod_gui=require("mod-gui")
local M={button="tech-priests-muster-button",frame="tech-priests-muster-frame",tool="tech-priests-muster-order-tool"}
local function valid(e) return e and e.valid end
local function state()
 storage.tech_priests=storage.tech_priests or {}
 local tp=storage.tech_priests;tp.combat_muster_gui=tp.combat_muster_gui or {pending={}}
 return tp.combat_muster_gui
end
function M.button_for(player)
 local flow=mod_gui.get_button_flow(player)
 if not flow[M.button] then flow.add{type="sprite-button",name=M.button,style=mod_gui.button_style,
  sprite="tech-priests-skin-portrait-enginseer",tooltip={"tech-priests-combat.muster"},tags={combat_muster_action="open"}} end
end
function M.close(player)
 local f=player.gui.screen[M.frame];if valid(f) then f.destroy() end
end
function M.open(player)
 M.close(player)
 local entries={}
 for key,pair in pairs(storage.tech_priests.pairs_by_station or {}) do
  if valid(pair.station) and valid(pair.priest) and pair.station.force==player.force and pair.station.surface==player.surface then
   entries[#entries+1]={key=key,pair=pair}
  end
 end
 table.sort(entries,function(a,b)
  local function d(e) local p=e.pair.station.position;return (p.x-player.position.x)^2+(p.y-player.position.y)^2 end
  return d(a)<d(b)
 end)
 if #entries==0 then player.print({"tech-priests-combat.no-station"});return false end
 local labels,keys={},{}
 for i,entry in ipairs(entries) do
  if i>128 then break end
  local p=entry.pair.station.position
  labels[#labels+1]={"",entry.pair.station.localised_name," (",math.floor(p.x),", ",math.floor(p.y),")"}
  keys[#keys+1]=entry.key
 end
 local ids,names={},{}
 for _,u in ipairs(C.units) do
  if player.force.recipes[u.name] and player.force.recipes[u.name].enabled then
   ids[#ids+1]={id=u.id,quality="normal"};names[#names+1]=u.label
   -- The reinforced recipes remain physically craftable as item-with-entity-data
   -- through the native building UI. Automated uncommon deployment is withheld
   -- until 0338 can debit and place the exact original quality stack.
  end
 end
 if #ids==0 then player.print({"tech-priests-combat.no-units"});return false end
 local f=player.gui.screen.add{type="frame",name=M.frame,direction="vertical",caption={"tech-priests-combat.muster"},tags={stations=keys,units=ids}}
 f.auto_center=true
 f.add{type="label",caption={"tech-priests-combat.station"}}
 f.add{type="drop-down",name="station",items=labels,selected_index=1}
 f.add{type="label",caption={"tech-priests-combat.unit"}}
 f.add{type="drop-down",name="unit",items=names,selected_index=1}
 local text=f.add{type="label",caption={"tech-priests-combat.instructions"}}
 text.style.single_line=false;text.style.maximal_width=460
 local buttons=f.add{type="flow"}
 buttons.add{type="button",caption={"tech-priests-combat.choose-sites"},tags={combat_muster_action="place"}}
 buttons.add{type="button",caption={"gui.close"},tags={combat_muster_action="close"}}
 player.opened=f;return true
end
function M.begin(player)
 local frame=player.gui.screen[M.frame]
 if not valid(frame) then return false end
 local tags=frame.tags
 local selected=tags.units[frame.unit.selected_index]
 local unit=type(selected)=="table" and selected.id or selected
 local quality=type(selected)=="table" and selected.quality or "normal"
 local station=tags.stations[frame.station.selected_index]
 if not player.clear_cursor() then return false end
 if not player.cursor_stack.set_stack{name=M.tool,count=1} then return false end
 state().pending[player.index]={station=station,unit=unit,quality=quality,surface=player.surface.index,phase="deploy"}
 M.close(player);player.print({"tech-priests-combat.select-deploy"});return true
end
function M.selected(event)
 if event.item~=M.tool then return end
 local player=game.get_player(event.player_index);local s=state();local order=s.pending[player.index]
 if not order then return true end
 local pair=storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[order.station]
 if not(pair and valid(pair.station) and pair.station.force==player.force and pair.station.surface==player.surface
   and player.surface.index==order.surface) then
  s.pending[player.index]=nil;player.print({"tech-priests-combat.order-invalid"});return true
 end
 local a=event.area;local p={x=(a.left_top.x+a.right_bottom.x)/2,y=(a.left_top.y+a.right_bottom.y)/2}
 if order.phase=="deploy" then order.deploy=p;order.phase="rally";player.print({"tech-priests-combat.select-rally"})
 else
  local ok,why=Orders.request(pair,order.unit,order.deploy,p,order.quality)
  player.print(ok and {"tech-priests-combat.order-accepted"} or {"tech-priests-combat.order-refused",why})
  s.pending[player.index]=nil
  if player.cursor_stack.valid_for_read and player.cursor_stack.name==M.tool then player.cursor_stack.clear() end
 end
 return true
end
function M.install()
 local function initialize() state();for _,p in pairs(game.players) do M.button_for(p) end end
 Registry.on_init(initialize,{owner="combat_muster_gui",route="initialize",priority=700})
 Registry.on_configuration_changed(initialize,{owner="combat_muster_gui",route="configuration",priority=700})
 Registry.on_event({defines.events.on_player_created,defines.events.on_player_joined_game},function(e) M.button_for(game.get_player(e.player_index)) end,nil,
  {owner="combat_muster_gui",route="player-lifecycle"})
 Registry.on_event(defines.events.on_gui_click,function(e)
  if not valid(e.element) then return end
  local action=e.element.tags.combat_muster_action;if not action then return end
  local p=game.get_player(e.player_index)
  if action=="open" then M.open(p) elseif action=="close" then M.close(p) elseif action=="place" then M.begin(p) end
  return true
 end,nil,{owner="combat_muster_gui",route="click",priority=-100,stop_on_truthy=true})
 Registry.on_event(defines.events.on_gui_closed,function(e)
  if valid(e.element) and e.element.name==M.frame then M.close(game.get_player(e.player_index));return true end
 end,nil,{owner="combat_muster_gui",route="close-frame",stop_on_truthy=true})
 Registry.on_event(defines.events.on_player_selected_area,M.selected,nil,{owner="combat_muster_gui",route="muster-sites"})
 Registry.on_event(defines.events.on_player_alt_selected_area,function(e)
  if e.item==M.tool then state().pending[e.player_index]=nil;game.get_player(e.player_index).clear_cursor();return true end
 end,nil,{owner="combat_muster_gui",route="cancel-sites"})
 return true
end
return M
