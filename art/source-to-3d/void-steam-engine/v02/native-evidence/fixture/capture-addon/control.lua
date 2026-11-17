local layout=nil
local faces={[0]='north',[4]='east'}
local delta=.36/math.sqrt(2)-.046875
local pipe={[0]={-1,.453125},[4]={-.5,-1.046875}}
local exhaust={[0]={.82,-.82-1.75/math.sqrt(2)+delta},[4]={.82,.82-1.75/math.sqrt(2)+delta}}
local console={[0]={0,.67-.66/math.sqrt(2)+delta},[4]={-.67,-.66/math.sqrt(2)+delta}}
local function shot(name,u,offset,zoom)
 local p=u.position;game.take_screenshot{surface=game.surfaces[u.surface],position={p.x+(offset and offset[1]or 0),p.y+(offset and offset[2]or 0)},resolution=zoom and{512,512}or{768,768},zoom=zoom or 2.5,path='void-v1/'..faces[u.direction]..'-'..name..'.png',show_gui=false,show_entity_info=false,anti_alias=true}
end
local schedule={[60]='empty-a',[90]='empty-b',[240]='working',[660]='stopped-a',[720]='stopped-b',[1200]='restarted',[1500]='full-a',[1620]='full-b',[2100]='load-recovery',[3000]='starved-a',[3060]='starved-b',[3500]='resupplied',[3660]='cold-steam-a',[3780]='cold-steam-b',[4100]='hot-recovered'}
script.on_event(defines.events.on_tick,function(e)
 if not layout then layout=remote.call('void_proof','layout');game.speed=1 end
 if schedule[e.tick]then for _,u in ipairs(layout.units)do shot(schedule[e.tick],u)end end
 if e.tick==240 then for _,u in ipairs(layout.units)do shot('pipe',u,pipe[u.direction],8);shot('exhaust',u,exhaust[u.direction],8);shot('console',u,console[u.direction],8)end end
 for k=0,31 do if e.tick==240+math.floor(k*7.5)then for _,u in ipairs(layout.units)do shot(string.format('motion-%02d',k),u)end end end
 if e.tick==500 then game.speed=4 end
 if e.tick==4260 then log('VOID_GUI_FINAL_OPERATED_STATE')end
end)
