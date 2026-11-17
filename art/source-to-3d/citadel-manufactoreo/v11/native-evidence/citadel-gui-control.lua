local layout=nil
local function shot(name,u,offset,zoom,res,alt)
 local p=u.position;game.take_screenshot{surface=game.surfaces[u.surface],position={p.x+(offset and offset[1]or 0),p.y+(offset and offset[2]or-1.5)},resolution=res or{768,768},zoom=zoom or 2.5,path='citadel-v1/'..u.recipe..'-'..name..'.png',show_gui=false,show_entity_info=alt or false,anti_alias=true}
end
local schedule={[60]='empty-a',[90]='empty-b',[1200]='working',[14820]='stopped-a',[14940]='stopped-b',[16000]='restarted',[19860]='blocked-a',[20040]='blocked-b',[21000]='output-released',[22860]='unpowered-a',[23040]='unpowered-b',[24000]='power-restored',[27960]='starved-a',[28140]='starved-b',[29000]='resupplied',[30780]='circuit-disabled-a',[30960]='circuit-disabled-b',[32000]='signal-restored',[33480]='completed'}
script.on_event(defines.events.on_tick,function(ev)
 if not layout then layout=remote.call('citadel_proof','layout');game.speed=8 end
 if ev.tick==1160 then game.speed=1 end
 if ev.tick==1460 then game.speed=8 end
 if schedule[ev.tick]then for _,u in ipairs(layout.units)do shot(schedule[ev.tick],u);shot('mechanism-'..schedule[ev.tick],u,{1.85,2.04-2.67/math.sqrt(2)},8,{512,512})end end
 if ev.tick==1200 then for _,u in ipairs(layout.units)do
  shot('console',u,{-1.85,1.55},8,{512,512});shot('circuits',u,{-1.53,1.54},8,{512,512});shot('logistics',u,{0,0},1.4,{1280,1280},true)
 end end
 for k=0,31 do if ev.tick==1200+math.floor(k*7.5)then for _,u in ipairs(layout.units)do shot(string.format('motion-%02d',k),u);shot(string.format('mechanism-motion-%02d',k),u,{1.85,2.04-2.67/math.sqrt(2)},8,{512,512})end end end
end)
