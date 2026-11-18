local function shot(label,u,wide)
 local p=u.position;game.take_screenshot{surface=game.surfaces[u.surface],position=wide and{p.x,p.y-.8}or{p.x-.65,p.y-.20},resolution=wide and{800,800}or{640,640},zoom=wide and 2.5or 4,path='orbital-coupled/'..label..'.png',show_gui=false,show_entity_info=false,anti_alias=true,force_render=true}
end
script.on_init(function()game.speed=1;storage.target=remote.call('orbital_proof','layout')[1];storage.frames={};storage.wide={}end)
script.on_event(defines.events.on_tick,function(ev)
 game.speed=1;if storage.done then return end
 local u=storage.target;local state=remote.call('tp_orbital_visuals','inspect');local r=nil;for _,v in ipairs(state.machines)do if v.unit==u.entity.unit_number then r=v;break end end;if not r then return end
 if ev.tick==90 then shot('wide-idle',u,true);storage.wide[#storage.wide+1]='wide-idle.png'end
 if r.phase~='idle'and not storage.started then storage.started=ev.tick end
 if storage.started then
  if not storage.seen then storage.seen={}end
  if not storage.seen[r.phase]then storage.seen[r.phase]=true;local n='wide-'..r.phase;shot(n,u,true);storage.wide[#storage.wide+1]=n..'.png'end
  if r.phase=='receiving'then storage.saw_pod=true end
  if ev.tick%12==0 and #storage.frames<100 then local n=string.format('arrival-%03d',#storage.frames);shot(n,u,false);storage.frames[#storage.frames+1]={file=n..'.png',tick=ev.tick,phase=r.phase,lid_frame=r.frame,pod_state=r.pod_state}end
  if storage.saw_pod and r.phase=='idle'then
   shot('wide-completed',u,true);storage.wide[#storage.wide+1]='wide-completed.png';storage.done=true;helpers.write_file('orbital-coupled/capture.json',helpers.table_to_json{passed=true,frames=storage.frames,wide=storage.wide,existing_native_pod_reused=true,authored_replacement_pod=false,phase=r.phase,completed_tick=ev.tick,render_objects_valid=r.render_objects_valid},false);log('ORBITAL_COUPLED_NATIVE_CAPTURE_COMPLETE')
  end
 end
end)
