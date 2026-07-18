-- scripts/core/visual_intent_line_authority_0657.lua
-- Tech Priests 0.1.674-dev recovery.
-- Read-only selected-pair intent rendering sourced from canonical_action_0744 or
-- the current canonical movement request. Broker-owned; no direct timing route.

local M={version="0.1.674-dev",storage_key="visual_intent_line_authority_0657",refresh_period=5,ttl=30,max_drawn=64}
local function valid(e)return e and e.valid end
local function now()return game and game.tick or 0 end
local function safe(v)if v==nil then return"nil"end;local ok,out=pcall(tostring,v);return ok and out or"?"end
local function pair_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function priest_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_priest or{}end
local function valid_pair(pair)return type(pair)=="table"and valid(pair.station)and valid(pair.priest)end
local function root()
 storage.tech_priests=storage.tech_priests or{};storage.tech_priests[M.storage_key]=storage.tech_priests[M.storage_key]or{version=M.version,enabled=true,patched=false,stats={}}
 local r=storage.tech_priests[M.storage_key];r.version=M.version;if r.enabled==nil then r.enabled=true end;r.stats=r.stats or{};return r
end
local function network_root()
 storage.tech_priests=storage.tech_priests or{};storage.tech_priests.network_visuals_0333=storage.tech_priests.network_visuals_0333 or{pair_link_objects_by_player={},stats={}}
 local r=storage.tech_priests.network_visuals_0333;r.pair_link_objects_by_player=r.pair_link_objects_by_player or{};r.stats=r.stats or{};return r
end
local function safe_destroy(obj)if obj then pcall(function()if obj.valid then obj.destroy()end end)end end
local function clear_player(index)local nr=network_root();local list=nr.pair_link_objects_by_player[index];if list then for _,obj in pairs(list)do safe_destroy(obj)end end;nr.pair_link_objects_by_player[index]=nil end
local function selected_pair(player)
 if not(player and player.valid)then return nil end;local selected=player.selected
 if selected and selected.valid and selected.unit_number then return pair_map()[selected.unit_number]or priest_map()[selected.unit_number]end
 if _G.selected_pair_for_player then local ok,pair=pcall(_G.selected_pair_for_player,player);if ok and pair then return pair end end;return nil
end
local function active_target(pair)
 if not valid_pair(pair)then return nil end
 local action=pair.canonical_action_0744
 if type(action)=="table"and action.updated_tick and now()-(tonumber(action.updated_tick)or 0)<=180 then
  local status=tostring(action.status or"");if status~="idle"and status~="failed"and status~="complete"and status~="cancelled"then
   local label=action.phase or action.family or action.detail or"active action";local kind=action.family or"action"
   if valid(action.target)then return{entity=action.target,label=label,kind=kind,source="canonical-action"}end
   if action.position and action.position.x and action.position.y then return{position={x=action.position.x,y=action.position.y},label=label,kind=kind,source="canonical-action"}end
  end
 end
 local req=pair.movement_request_0418
 if type(req)=="table"and req.x and req.y and(not req.expires_tick or req.expires_tick>=now())then return{position={x=req.x,y=req.y},label=req.reason or req.owner or"movement",kind="movement",source="movement-request"}end
 return nil
end
local function color_for(kind)
 if kind=="construction"then return{r=.30,g=1,b=.45,a=.95}end
 if kind=="consecration"then return{r=.55,g=1,b=.95,a=.95}end
 if kind=="logistics"then return{r=1,g=.78,b=.18,a=.95}end
 if kind=="direct-acquisition"or kind=="acquisition"then return{r=1,g=.55,b=.10,a=.95}end
 if kind=="repair"or kind=="combat-repair"then return{r=.45,g=1,b=.60,a=.95}end
 return{r=1,g=.62,b=.16,a=.85}
end
local function draw_pair_for_player(player,pair,out)
 if not(player and player.valid and valid_pair(pair)and rendering and rendering.draw_line)then return 0 end
 if pair.station.force~=player.force or pair.station.surface~=player.surface or pair.priest.surface~=player.surface then return 0 end
 local before=#out;local target=active_target(pair)
 if target then
  local color=color_for(target.kind);local spec={surface=player.surface,from={entity=pair.priest,offset={0,-.85}},color=color,width=3,time_to_live=M.ttl,players={player}}
  if valid(target.entity)then spec.to={entity=target.entity,offset={0,-.25}}else spec.to=target.position end
  local ok,obj=pcall(function()return rendering.draw_line(spec)end);if ok and obj then out[#out+1]=obj end
  if rendering.draw_text and target.label then local ok2,txt=pcall(function()return rendering.draw_text{surface=player.surface,target=valid(target.entity)and{entity=target.entity,offset={0,-1.15}}or target.position,text=tostring(target.label),color=color,scale=.62,alignment="center",time_to_live=M.ttl,players={player}}end);if ok2 and txt then out[#out+1]=txt end end
 else
  local ok,obj=pcall(function()return rendering.draw_line{surface=pair.station.surface,from={entity=pair.station,offset={0,-.20}},to={entity=pair.priest,offset={0,-.85}},color={r=.55,g=.55,b=.55,a=.28},width=1,time_to_live=M.ttl,players={player}}end);if ok and obj then out[#out+1]=obj end
 end
 return #out-before
end
function M.refresh_pair_links()
 local r=root();if r.enabled==false or not(game and game.connected_players and rendering)then return{processed=0,acted=0,detail="disabled-or-no-rendering"}end
 local nr=network_root();local total,players=0,0
 for _,player in pairs(game.connected_players)do if player and player.valid then players=players+1;clear_player(player.index);local out={};local pair=selected_pair(player)
  if pair then draw_pair_for_player(player,pair,out)elseif nr.pair_link_always_on then for _,p in pairs(pair_map())do draw_pair_for_player(player,p,out);if #out>=M.max_drawn then break end end end
  nr.pair_link_objects_by_player[player.index]=out;total=total+#out end end
 nr.stats.pair_links_drawn=total;nr.stats.pair_link_mode="canonical-intent-line-0657";r.stats.drawn=total;r.stats.players=players;r.stats.last_tick=now();return{processed=players,acted=total,detail="drawn="..total.." players="..players}
end
local function patch_network_visuals()
 local ok,visuals=pcall(require,"scripts.core.network_visuals");if not(ok and visuals and type(visuals)=="table")then return false end
 if visuals.TECH_PRIESTS_0657_PATCHED then return true end;visuals.TECH_PRIESTS_0657_PRE_REFRESH_PAIR_LINKS=visuals.refresh_pair_links;visuals.refresh_pair_links=M.refresh_pair_links;visuals.TECH_PRIESTS_0657_PATCHED=true;root().patched=true;return true
end
function M.install()
 root();local patched=patch_network_visuals();local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600");if not(broker and type(broker.register_service)=="function")then return false end
 local service=broker.register_service{name="visual_intent_line_authority_0657",category="visuals",interval=M.refresh_period,priority=25,budget=4,fn=function()patch_network_visuals();return M.refresh_pair_links()end,note="render selected pair intent from canonical action or movement request"}
 if not service then return false end;_G.TechPriestsVisualIntentLineAuthority0657=M;if log then log("[Tech-Priests 0.1.674-dev] canonical visual intent line authority installed")end;return patched==true
end
return M
