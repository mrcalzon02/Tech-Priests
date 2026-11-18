local NAME='tech-priests-emergency-miner'
script.on_init(function()storage.start=game.tick;game.speed=1;storage.rows=game.surfaces[1].find_entities_filtered{name=NAME};storage.rows=storage.rows or{};storage.frames={};storage.wide={};for _,e in ipairs(storage.rows)do e.disabled_by_script=true end end)
local function shot(e,file,zoom)
 game.take_screenshot{surface=e.surface,position=e.position,resolution={768,768},zoom=zoom,path='miner-native/'..file,show_gui=false,show_entity_info=false,anti_alias=true}
end
script.on_event(defines.events.on_tick,function(ev)
 local t=ev.tick-storage.start;local e=storage.rows[9];if not e or not e.valid then return end
 if t==60 then shot(e,'idle-close.png',4);storage.frames[#storage.frames+1]={file='idle-close.png',status=e.status,working=e.is_crafting()};shot(storage.rows[5],'idle-gallery.png',1);storage.wide[#storage.wide+1]='idle-gallery.png'
 elseif t==120 then for _,r in ipairs(storage.rows)do r.disabled_by_script=false end
 elseif t>=180 and t<308 and (t-180)%8==0 then local n=(t-180)/8;local file=string.format('working-%02d.png',n);shot(e,file,4);storage.frames[#storage.frames+1]={file=file,status=e.status,working=e.is_crafting(),progress=e.crafting_progress}
 elseif t==320 then shot(storage.rows[5],'working-gallery.png',1);storage.wide[#storage.wide+1]='working-gallery.png'
 elseif t==360 then helpers.write_file('miner-native/capture.json',helpers.table_to_json{passed=#storage.frames==17,frames=storage.frames,wide=storage.wide,actual_native_direction=0,sprites_replaced=false},false)
 end
end)
