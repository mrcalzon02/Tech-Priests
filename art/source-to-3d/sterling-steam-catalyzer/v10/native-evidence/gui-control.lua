local layout=nil
local mouths={
 [0]={{-2,.453125},{2,.453125}},[4]={{-.5,-2.046875},{-.5,1.953125}},
 [8]={{2,-.546875},{-2,-.546875}},[12]={{.5,1.953125},{.5,-2.046875}}
}
local smoke={[0]={.45,-1.8073270523},[4]={.82,-.5373270714},[8]={-.45,-.167327007},[12]={-.82,-1.437327018}}
local console={[0]={0,.7-.95/math.sqrt(2)+.36/math.sqrt(2)-.046875},[4]={-.7,-.95/math.sqrt(2)+.36/math.sqrt(2)-.046875},[8]={0,-.7-.95/math.sqrt(2)+.36/math.sqrt(2)-.046875},[12]={.7,-.95/math.sqrt(2)+.36/math.sqrt(2)-.046875}}
local names={[0]='north',[4]='east',[8]='south',[12]='west'}
local function find(state,direction)
 for _,u in ipairs(layout.units) do if u.state==state and u.direction==direction then return u end end;error('STERLING_GUI missing '..state..' '..direction)
end
local function shot(name,u,offset,zoom)
 local p=u.position;game.take_screenshot{surface=game.surfaces[layout.surface],position={p.x+(offset and offset[1] or 0),p.y+(offset and offset[2] or 0)},resolution=zoom and {512,512} or {768,768},zoom=zoom or 2.5,path='sterling-v1/'..name..'.png',show_gui=false,show_entity_info=false,anti_alias=true}
end
script.on_event(defines.events.on_tick,function(e)
 if not layout then layout=remote.call('sterling_proof','layout');game.speed=1 end
 if e.tick==600 then
  for _,d in ipairs({0,4,8,12}) do
   local u=find('working',d);shot(names[d]..'-working',u);shot(names[d]..'-console',u,console[d],8)
   for i,p in ipairs(mouths[d]) do shot(names[d]..'-pipe-'..i,u,p,8) end
   shot(names[d]..'-smoke',u,smoke[d],8)
   for _,state in ipairs({'no-fuel','no-water','disabled'}) do shot(names[d]..'-'..state,find(state,d)) end
  end
 elseif e.tick==660 then for _,d in ipairs({0,4,8,12}) do shot(names[d]..'-stopped',find('stop-restart',d)) end
 elseif e.tick==720 then shot('north-stopped-b',find('stop-restart',0))
 elseif e.tick==960 then for _,d in ipairs({0,4,8,12}) do shot(names[d]..'-restarted',find('stop-restart',d)) end
 elseif e.tick==1020 then game.speed=64
 elseif e.tick==2460 then for _,d in ipairs({0,4,8,12}) do shot(names[d]..'-full-output',find('full-output',d)) end
 elseif e.tick==2520 then shot('north-full-output-b',find('full-output',0))
 elseif e.tick==3660 then for _,d in ipairs({0,4,8,12}) do for _,state in ipairs({'no-fuel','no-water','full-output'}) do shot(names[d]..'-resumed-'..state,find(state,d)) end end
 elseif e.tick==4260 then game.speed=1;log('STERLING_GUI_FINAL_OPERATED_STATE')
 end
 if e.tick>=600 and e.tick<840 and (e.tick-600)%15==0 then
  for _,d in ipairs({0,4,8,12}) do shot(string.format('%s-motion-%02d',names[d],(e.tick-600)/15),find('working',d)) end
 end
end)
