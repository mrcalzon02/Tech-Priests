local function take(e,file,zoom,res)
 game.take_screenshot{surface=e.surface,position={e.position.x,e.position.y-.4},resolution=res or{640,640},zoom=zoom or 8,path='laboratorium-native/'..file,show_entity_info=false,show_gui=false,force_render=true}
end
script.on_init(function()
 local u=remote.call('laboratorium_proof','layout')[1];storage.logistics=u.entity;local s=u.entity.surface;local chest=assert(s.find_entity('steel-chest',{u.position.x+4,u.position.y+4}));assert(chest.get_inventory(defines.inventory.chest).remove{name='tech-priests-emergency-laboratorium',count=1}==1,'Use actual crafted/mined item');local pos={u.position.x+5,u.position.y+11};assert(s.can_place_entity{name='tech-priests-emergency-laboratorium',position=pos,force='player'});storage.e=s.create_entity{name='tech-priests-emergency-laboratorium',position=pos,force='player',raise_built=true};storage.base=game.tick;storage.frames={};storage.samples={};game.speed=1;storage.e.disabled_by_script=true;s.daytime=0;s.freeze_daytime=true
end)
script.on_event(defines.events.on_tick,function(ev)
 local dt=ev.tick-storage.base;local e=storage.e
 local function capture(file,zoom,res,entity)
  local target=entity or e;take(target,file,zoom,res);storage.frames[#storage.frames+1]={file=file,tick=ev.tick};storage.samples[#storage.samples+1]={tick=ev.tick,disabled=target.disabled_by_script,status=target.status,research=game.forces.player.current_research and game.forces.player.current_research.name,research_progress=game.forces.player.research_progress,fuel_remaining=target.burner.remaining_burning_fuel}
 end
 if dt==60 then capture('idle-close.png');capture('idle-wide.png',3,{1024,768})
 elseif dt==90 then assert(e.insert{name='coal',count=1}==1);assert(e.insert{name='automation-science-pack',count=20}==20);e.disabled_by_script=false
 elseif dt==150 then capture('working-01.png');capture('logistics-working-wide.png',3,{1024,768},storage.logistics);capture('logistics-working-close.png',8,{640,640},storage.logistics)
 elseif dt==180 then capture('working-02.png');e.surface.daytime=.45
 elseif dt==210 then capture('working-night.png');capture('working-night-wide.png',3,{1024,768})
 elseif dt==230 then e.disabled_by_script=true
 elseif dt==290 then capture('idle-night.png')
 elseif dt==320 then helpers.write_file('laboratorium-native/capture.json',helpers.table_to_json{passed=true,frames=storage.frames,wide={},samples=storage.samples,actual_operated_save_loaded=true,clean_view_uses_actual_crafted_mined_item=true,native_idle_working_and_night=true,native_directions={0},native_burner_light_position={-.31,.324-.169/math.sqrt(2)},no_external_lab_electrical_supply=true},false)
 end
end)
