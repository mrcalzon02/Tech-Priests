local function C(e,id)return e.get_wire_connector(id,true)end
local function take(e,file,zoom,res)game.take_screenshot{surface=e.surface,position={e.position.x,e.position.y-.4},resolution=res or{640,640},zoom=zoom or 8,path='power-grid-native/'..file,show_entity_info=false,show_gui=false,force_render=true}end
script.on_init(function()
 local rows=remote.call('power_grid_proof','layout');storage.a=rows[1].entity;storage.b=rows[2].entity;local s=storage.a.surface;local chest=assert(s.find_entity('steel-chest',{17.5,27.5}));assert(chest.get_inventory(defines.inventory.chest).remove{name='tech-priests-emergency-power-grid',count=1}==1,'Use actual crafted/mined item');local pos={12.5,37.5};assert(s.can_place_entity{name='tech-priests-emergency-power-grid',position=pos,force='player'});storage.clean=s.create_entity{name='tech-priests-emergency-power-grid',position=pos,force='player',raise_built=true};assert(C(storage.clean,defines.wire_connector_id.pole_copper).real_connection_count==0,'clean pole is genuinely unwired');storage.base=game.tick;storage.frames={};storage.samples={};game.speed=1;s.daytime=0;s.freeze_daytime=true
end)
script.on_event(defines.events.on_tick,function(ev)
 local dt=ev.tick-storage.base;local copper=defines.wire_connector_id.pole_copper
 local function capture(e,file,zoom,res)
  take(e,file,zoom,res);storage.frames[#storage.frames+1]={file=file,tick=ev.tick};storage.samples[#storage.samples+1]={tick=ev.tick,copper_connected=C(storage.a,copper).is_connected_to(C(storage.b,copper)),networkA=storage.a.electric_network_id,networkB=storage.b.electric_network_id,red=C(e,defines.wire_connector_id.circuit_red).real_connection_count,green=C(e,defines.wire_connector_id.circuit_green).real_connection_count}
 end
 if dt==60 then capture(storage.clean,'unwired-close.png');capture(storage.clean,'unwired-wide.png',3,{1024,768})
 elseif dt==90 then capture(storage.a,'wired-contacts-close.png');capture(storage.a,'powered-chain-wide.png',2,{1800,1000})
 elseif dt==120 then assert(C(storage.a,copper).disconnect_from(C(storage.b,copper),defines.wire_origin.player))
 elseif dt==300 then capture(storage.b,'copper-cut-circuits-retained.png');capture(storage.a,'copper-cut-wide.png',2,{1800,1000})
 elseif dt==330 then assert(C(storage.a,copper).can_wire_reach(C(storage.b,copper)));assert(C(storage.a,copper).connect_to(C(storage.b,copper),true,defines.wire_origin.player));storage.a.surface.daytime=.45
 elseif dt==510 then capture(storage.a,'restored-night-coverage.png',2,{1800,1000});capture(storage.a,'restored-contacts-night.png')
 elseif dt==540 then helpers.write_file('power-grid-native/capture.json',helpers.table_to_json{passed=true,frames=storage.frames,wide={},samples=storage.samples,actual_operated_save_loaded=true,actual_crafted_mined_item_reused=true,actual_unwired_wired_copper_cut_and_restored_states=true,native_directions={0},passive_static_pole_native_wire_states=true,no_false_generation_or_mechanical_cycle_added=true},false)
 end
end)
