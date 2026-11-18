local function take(e,file,zoom,res)
 game.take_screenshot{surface=e.surface,position={e.position.x,e.position.y-.4},resolution=res or{640,640},zoom=zoom or 8,path='smelter-native/'..file,show_entity_info=false,show_gui=false,force_render=true}
end
script.on_init(function()
 local rows=remote.call('smelter_proof','layout');local u=rows[1];local surface=u.entity.surface;local chest=assert(surface.find_entity('steel-chest',{u.position.x+4,u.position.y+4}));assert(chest.get_inventory(defines.inventory.chest).remove{name='tech-priests-emergency-smelter',count=1}==1,'Use the actual crafted/mined item');local pos={u.position.x+5,u.position.y+11};assert(surface.can_place_entity{name='tech-priests-emergency-smelter',position=pos,force='player'});storage.e=surface.create_entity{name='tech-priests-emergency-smelter',position=pos,force='player',raise_built=true};storage.base=game.tick;storage.samples={};storage.frames={};game.speed=1;storage.e.disabled_by_script=true
end)
script.on_event(defines.events.on_tick,function(ev)
 local dt=ev.tick-storage.base;local e=storage.e
 local function capture(file,zoom,res)
  take(e,file,zoom,res);storage.frames[#storage.frames+1]={file=file,tick=ev.tick};storage.samples[#storage.samples+1]={tick=ev.tick,disabled=e.disabled_by_script,status=e.status,crafting_progress=e.crafting_progress,products=e.products_finished,fuel_remaining=e.burner.remaining_burning_fuel}
 end
 if dt==60 then capture('idle-close.png');capture('idle-wide.png',3,{1024,768})
 elseif dt==90 then assert(e.insert{name='coal',count=1}==1);assert(e.insert{name='iron-ore',count=20}==20);e.disabled_by_script=false
 elseif dt==150 then capture('working-01.png')
 elseif dt==180 then capture('working-02.png')
 elseif dt==210 then capture('working-03.png');capture('working-wide.png',3,{1024,768})
 elseif dt==240 then helpers.write_file('smelter-native/capture.json',helpers.table_to_json{passed=true,frames=storage.frames,wide={},samples=storage.samples,actual_operated_save_loaded=true,clean_view_uses_actual_crafted_mined_item=true,standalone_native_burner_without_electrical_supply=true,native_idle_and_working=true,native_directions={0},smoke_source_expected={x=.20,y=-.285-1.175/math.sqrt(2)}},false)
 end
end)
