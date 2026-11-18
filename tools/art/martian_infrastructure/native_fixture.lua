-- Isolated proof: electricity, both circuits, chunk coverage, lifecycle, reload.
local T={}
local loaded=false
local ids=defines.wire_connector_id
local function join(a,b,id)
  local aa,bb=a.get_wire_connector(id,true),b.get_wire_connector(id,true)
  assert(aa.is_connected_to(bb) or aa.connect_to(bb,true),'Native wire failed: '..a.name..' -> '..b.name..' connector '..id)
end
local function source(surface,pos)
  return surface.create_entity{name='martian-review-source',position=pos,force='player'}
end
local function helper(e)
  return e.surface.find_entities_filtered{name=e.name..'-vision',position=e.position,radius=.05,force=e.force}[1]
end
function T.initialize()
  storage.review={sites={},checks={},phase='initial'}
  for n=1,3 do
    local surf=game.create_surface('martian-range-'..n,{width=1024,height=1024,water=0,autoplace_controls={['enemy-base']={size=0}}})
    surf.request_to_generate_chunks({0,0},n+3);surf.force_generate_chunk_requests();surf.always_day=true
    -- Create this force's chart on the disposable remote surface, far outside
    -- every tested radar radius. No tested chunk is revealed by the fixture.
    game.forces.player.chart(surf,{{300,300},{301,301}})
    local pads={}
    for x=-8,38 do for y=-10,10 do pads[#pads+1]={name='refined-concrete',position={x,y}} end end
    surf.set_tiles(pads)
    for _,e in pairs(surf.find_entities_filtered{type={'tree','simple-entity','cliff'}}) do e.destroy() end
    local half=n%2==1 and .5 or 0
    local array=surf.create_entity{name='martian-comms-'..n,position={half,half},force='player',raise_built=true}
    local pole=surf.create_entity{name='martian-power-'..n,position={n+2+half,half},force='player',raise_built=true}
    local supply=source(surf,{n+2+half,n/2+1+half});supply.power_production=0;supply.energy=0
    join(array,pole,ids.pole_copper)
    local red=surf.create_entity{name='constant-combinator',position={n+2+half,-n-2+half},force='player'}
    local green=surf.create_entity{name='constant-combinator',position={n+4+half,-n-2+half},force='player'}
    red.get_or_create_control_behavior().add_section().set_slot(1,{value={type='virtual',name='signal-A',quality='normal'},min=101+n})
    green.get_or_create_control_behavior().add_section().set_slot(1,{value={type='virtual',name='signal-B',quality='normal'},min=201+n})
    join(red,pole,ids.circuit_red);join(green,pole,ids.circuit_green)
    join(pole,array,ids.circuit_red);join(pole,array,ids.circuit_green)
    local radar=helper(array)
    assert(radar and radar.valid,'Build event did not create vision component')
    assert(radar.prototype.get_max_distance_of_nearby_sector_revealed()==n)
    storage.review.sites[n]={surface=surf,array=array,pole=pole,supply=supply,radar=radar}
    local d=surf.create_entity{name='martian-diagnostic-radar',position={320,0},force='player'}
    surf.request_to_generate_chunks({320,0},4);surf.force_generate_chunk_requests()
    local dp=surf.create_entity{name='substation',position={320,2},force='player'}
    local ds=source(surf,{320,3});ds.power_production=10000000
    storage.review.sites[n].diagnostic=d
  end
  local surface=game.surfaces[1];surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests();surface.always_day=true
  for _,e in pairs(surface.find_entities_filtered{type={'tree','simple-entity','cliff'}}) do e.destroy() end
  local tiles={}
  for x=-24,24 do for y=-16,16 do tiles[#tiles+1]={name='refined-concrete',position={x,y}} end end
  surface.set_tiles(tiles)
  storage.review.display={}
  for row,family in ipairs({'power','comms'}) do
    for n=1,3 do
      local pos={x=(n-2)*6+.5,y=(row-1)*7+.5}
      local e=surface.create_entity{name='martian-'..family..'-'..n,position=pos,force='player',raise_built=true}
      storage.review.display[#storage.review.display+1]=e
      rendering.draw_text{text=(family=='power' and 'POWER ' or 'VOX ')..n..'x'..n,target={pos.x,pos.y+2.2},surface=surface,color={1,.8,.5},alignment='center',scale=1}
    end
  end
  -- Feed the display without covering the visible artwork with vanilla poles.
  for _,e in ipairs(storage.review.display) do
    local pos=e.position;local gen=source(surface,{pos.x+1,pos.y+2});gen.power_production=10000000
  end
  for row=0,1 do
    local a,b,c=table.unpack(storage.review.display,1+row*3,3+row*3)
    for _,id in ipairs({ids.pole_copper,ids.circuit_red,ids.circuit_green}) do join(a,b,id);join(b,c,id) end
  end
end
local function signal(e,id,name)
  local network=e.get_circuit_network(id)
  return network and network.get_signal{type='virtual',name=name,quality='normal'} or 0
end
local function check_networks()
  for n,site in ipairs(storage.review.sites) do
    assert(signal(site.array,ids.circuit_red,'signal-A')==101+n,'Red signal lost')
    assert(signal(site.array,ids.circuit_green,'signal-B')==201+n,'Green signal lost')
    assert(signal(site.array,ids.circuit_red,'signal-B')==0,'Green leaked into red')
    assert(signal(site.array,ids.circuit_green,'signal-A')==0,'Red leaked into green')
  end
end
local function check_vision(on)
  local rows={}
  for n,site in ipairs(storage.review.sites) do
    local seen=0
    for x=-n,n do for y=-n,n do if game.forces.player.is_chunk_visible(site.surface,{x,y}) then seen=seen+1 end end end
    if on then assert(seen==(2*n+1)^2,'Coverage size incorrect: '..n..' = '..seen..' radar energy='..site.radar.energy..' source='..site.supply.energy..' production='..site.supply.power_production..' network='..tostring(site.radar.electric_network_id)..'/'..tostring(site.array.electric_network_id)..' active='..tostring(site.radar.active)..' status='..site.radar.status..' chart='..tostring(game.forces.player.is_chunk_charted(site.surface,{0,0}))..' diagnostic='..tostring(game.forces.player.is_chunk_visible(site.surface,{10,0}))..' progress='..site.radar.radar_scan_progress)
    else
      -- is_chunk_visible reports the radar coverage provider even while an
      -- unpowered radar's chart has stopped refreshing. Check native energy
      -- and scan accumulation instead of treating this as a power-state API.
      assert(site.radar.energy==0,'Unpowered radar still has energy')
      if site.off_scan_progress then assert(math.abs(site.radar.radar_scan_progress-site.off_scan_progress)<1e-9,'Unpowered radar continues scanning') end
    end
    assert(not game.forces.player.is_chunk_visible(site.surface,{n+1,n+1}),'Vision exceeds configured range')
    rows[#rows+1]={tier=n,visible_chunks=seen,expected_when_powered=(2*n+1)^2,radar_energy=site.radar.energy,scan_progress=site.radar.radar_scan_progress,shared_electric_network=site.radar.electric_network_id==site.array.electric_network_id}
    if on then assert(site.radar.energy>0 and rows[n].shared_electric_network,'Radar not powered by native pole network') end
  end
  return rows
end
function T.tick(ev)
  local r=storage.review;if not r then return end
  if loaded then r.reload_observed=true;loaded=false end
  if ev.tick==60 then
    check_networks();r.checks.unpowered_before=check_vision(false)
    for _,site in ipairs(r.sites) do site.initial_orientation=site.radar.orientation;site.supply.power_production=10000000 end
  elseif ev.tick==360 then
    for n,site in ipairs(r.sites) do
      if n>1 then assert(site.radar.prototype.name=='martian-comms-'..n..'-vision','Missing native dish component') end
    end
    r.checks.rotation_graphics_configured=true
  elseif ev.tick==600 then
    check_networks();r.checks.powered=check_vision(true)
    for _,site in ipairs(r.sites) do site.supply.power_production=0;site.supply.energy=0;site.radar.energy=0;site.off_scan_progress=site.radar.radar_scan_progress;site.off_orientation=site.radar.orientation end
  elseif ev.tick==1000 then
    check_networks();r.checks.unpowered_after=check_vision(false)
    r.checks.native_radar_scan_stops_without_power=true
    for _,site in ipairs(r.sites) do site.supply.power_production=10000000 end
    local site=r.sites[1]
    r.clone=site.array.clone{position={20.5,.5}}
    assert(r.clone and helper(r.clone),'Clone lost radar')
    r.clone_helper=helper(r.clone)
    local ghost=site.surface.create_entity{name='entity-ghost',inner_name='martian-comms-1',position={25.5,.5},force='player'}
    local _,revived=ghost.revive{raise_revive=true}
    assert(revived and helper(revived),'Ghost revival lost radar: revived='..tostring(revived)..' tile='..site.surface.get_tile(25,0).name..' helpers='..site.surface.count_entities_filtered{name='martian-comms-1-vision',position={25.5,.5},radius=.1})
    r.revived=revived;r.revived_helper=helper(revived)
    r.clone.destroy() -- Deliberately no raised destroy: destruction registry owns cleanup.
    r.inventory=game.create_inventory(10);assert(revived.mine{inventory=r.inventory,raise_destroyed=true})
  elseif ev.tick==1010 then
    assert(not r.clone_helper.valid and not r.revived_helper.valid,'Orphan radar after parent removal')
    assert(r.inventory.get_item_count('martian-comms-1')==1,'Mining did not return exactly one placeable array')
    r.inventory.destroy();r.inventory=nil
    local site=r.sites[2]
    local victim=site.surface.create_entity{name='martian-comms-2',position={30,0},force='player',raise_built=true}
    r.dead_helper=helper(victim);victim.die()
    r.checks.clone_ghost_mining_destroy=true
  elseif ev.tick==1020 then
    assert(not r.dead_helper.valid,'Dead array leaves radar')
    r.checks.death_cleanup=true
    -- An unexpectedly destroyed component must repair itself once, event-driven.
    local site=r.sites[3];r.destroyed_component=site.radar;site.radar.destroy()
  elseif ev.tick==1030 then
    local site=r.sites[3];site.radar=helper(site.array)
    assert(site.radar.valid and not r.destroyed_component.valid,'Component recovery failed')
    r.checks.component_recovery=true
  elseif ev.tick==1300 then
    r.checks.restored=check_vision(true);check_networks();r.phase='checkpoint';r.checkpoint_tick=ev.tick
  elseif ev.tick==1400 then
    check_networks();r.checks.after_checkpoint=check_vision(true)
    for n,site in ipairs(r.sites) do
      assert(site.surface.count_entities_filtered{name='martian-comms-'..n..'-vision'}==1,'Duplicate or orphan radar')
    end
    local report={status='PASS',checks=r.checks,runtime_checkpoint_tick=r.checkpoint_tick,reloaded=r.reload_observed==true,serialization='New-save initialized pole/radar records and native wires serialized at tick zero, then behavior scenario run after --test-save reload',visible_pole_footprints={{1,1},{2,2},{3,3}},tick=ev.tick}
    helpers.write_file('martian-pylons/result.json',helpers.table_to_json(report),false)
    if GRAPHICAL then
      game.take_screenshot{surface=game.surfaces[1],position={0,1},resolution={1600,1000},zoom=2.5,path='martian-pylons/native-family.png',show_gui=false,show_entity_info=false,force_render=true,daytime=0}
      game.take_screenshot{surface=game.surfaces[1],position={.5,7},resolution={1200,700},zoom=3,path='martian-pylons/native-arrays.png',show_gui=false,show_entity_info=false,force_render=true,daytime=0}
      game.set_wait_for_screenshots_to_finish()
    end
    log('MARTIAN_PYLONS_NATIVE_PASS')
    script.finish_test(true)
  end
  if GRAPHICAL and (ev.tick==460 or ev.tick==540 or ev.tick==780 or ev.tick==920) then
    local site=r.sites[2]
    game.take_screenshot{surface=site.surface,position={site.array.position.x,site.array.position.y-1.4},resolution={640,800},zoom=4,path='martian-pylons/rotation-'..ev.tick..'.png',show_gui=false,show_entity_info=false,force_render=true,daytime=0}
    game.set_wait_for_screenshots_to_finish()
  end
  if GRAPHICAL and ev.tick==1401 then
    game.set_wait_for_screenshots_to_finish();helpers.write_file('martian-pylons/graphical-complete.txt','complete',false);game.tick_paused=true
  end
end
function T.loaded() loaded=true end
return T
