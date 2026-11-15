local NAME='tp-mh7-review-electrolyzer'
local ROOT='tp-mh7-electrolyzer-review/'
local function check(ok,message) if not ok then error('TP_MH7_ELECTROLYZER FAIL '..message,0) end end
local function write(name,value) helpers.write_file(ROOT..name..'.json',helpers.table_to_json(value),false) end
local function rotate(v,r)
 local x,y=v[1],v[2]
 for _=1,r do x,y=-y,x end
 return {x=x,y=y}
end
local directions={defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west}
local labels={'north','east','south','west'}
local ports={
 {id='water_input',target={0,2.5},plane={0,2},fluid='tp-mh7-review-purified-water'},
 {id='hydrogen_output',target={-2,-.5},plane={-1.5,-.5},fluid='tp-mh7-review-hydrogen-gas'},
 {id='oxygen_output',target={2,-.5},plane={1.5,-.5},fluid='tp-mh7-review-oxygen-gas'},
}
script.on_init(function()
 local s=game.surfaces[1];s.peaceful_mode=true;s.always_day=true
 s.request_to_generate_chunks({35,21},4);s.force_generate_chunk_requests()
 for _,e in pairs(s.find_entities_filtered{area={{-8,-8},{78,52}}}) do if e.valid then e.destroy() end end
 local tiles={};for x=-8,78 do for y=-8,52 do tiles[#tiles+1]={name='concrete',position={x,y}} end end
 s.set_tiles(tiles,true)
 storage.mh7_electrolyzer={sites={},complete=false,shots={}}
 local rows={}
 for r=0,3 do for mask=0,7 do
  local center={x=mask*10+(r%2==0 and .5 or 0),y=r*14+(r%2==1 and .5 or 0)}
  local m=assert(s.create_entity{name=NAME,position=center,direction=directions[r+1],force=game.forces.player})
  m.set_recipe('tp-mh7-review-electrolyze')
  check(m.direction==directions[r+1],'native direction')
  check(m.get_recipe() and m.get_recipe().name=='tp-mh7-review-electrolyze','recipe assignment')
  local site={machine=m,pipes={},mask=mask,rotation=r,observed={0,0},direction=labels[r+1]}
  local row={mask=mask,direction=labels[r+1],center=m.position,ports={}}
  for index,port in ipairs(ports) do
   local delta=rotate(port.target,r);local desired={x=m.position.x+delta.x,y=m.position.y+delta.y}
   local links=m.get_fluid_box_pipe_connections(index)
   check(#links==1 and links[1].target_position,'one actual socket per fluidbox')
   local actual=links[1].target_position
   check(math.abs(actual.x-desired.x)<.00001 and math.abs(actual.y-desired.y)<.00001,'rotated target '..port.id)
   local connected=bit32.band(mask,2^(index-1))~=0
   local pipe=nil
   if connected then
    pipe=assert(s.create_entity{name='pipe',position=desired,force=game.forces.player})
    site.pipes[index]=pipe
    local linked=m.get_fluid_box_pipe_connections(index)
    check(linked[1].target==pipe,'actual target entity '..port.id)
    local neighbor=false
    for _,record in pairs(m.get_fluid_box_neighbours(index) or {}) do if record.entity==pipe then neighbor=true end end
    check(neighbor,'actual fluid neighbour '..port.id)
   end
   row.ports[index]={id=port.id,fluid=port.fluid,target=desired,connected=connected,
      effective_plane_relative=rotate(port.plane,r),flow_direction=links[1].flow_direction,
      native_fluidbox_index=index,graphical_seating_verified=false}
  end
  storage.mh7_electrolyzer.sites[#storage.mh7_electrolyzer.sites+1]=site;rows[#rows+1]=row
 end end
 write('physical-ports',{passed=true,entity=NAME,sites=rows,orientation_count=4,connection_masks=8,
  scope='Actual isolated 3x4 prototype, all three ports, all bitmasks and native directions; not graphical seating or normal economy',
  native_fluids_are_review_only=true,ordinary_mod_changed=false})
 log('TP_MH7_ELECTROLYZER PHYSICAL_PORTS_PASS sites=32')
end)
script.on_event(defines.events.on_tick,function(event)
 local state=storage.mh7_electrolyzer;if not state then return end
 if event.tick%30==0 and not state.complete then
  for _,site in ipairs(state.sites) do if site.mask==7 then
   site.pipes[1].set_fluid(1,{name=ports[1].fluid,amount=100})
   for index=2,3 do
    local fluids=site.pipes[index].get_fluid_contents()
    for name,amount in pairs(fluids) do
     check(name==ports[index].fluid,'cross-contaminated gas pipe')
     site.observed[index-1]=site.observed[index-1]+amount
    end
    site.pipes[index].remove_fluid(1,1000000)
   end
  end end
 end
 if event.tick==120 then
  for _,site in ipairs(state.sites) do if site.mask==0 or site.mask==7 then
   local path=ROOT..site.direction..'-'..(site.mask==0 and 'disconnected' or 'working')..'.png'
   game.take_screenshot{player=game.players[1],surface=site.machine.surface,position=site.machine.position,
    resolution={800,800},zoom=3,daytime=0,show_gui=false,force_render=true,path=path}
   state.shots[#state.shots+1]=path
  end end
 end
 if event.tick>=600 and not state.complete then
  local flows={}
  for _,site in ipairs(state.sites) do if site.mask==7 then
   check(site.machine.products_finished>0 and site.observed[1]>0 and site.observed[2]>0,'both gases delivered '..site.direction)
   flows[#flows+1]={direction=site.direction,products_finished=site.machine.products_finished,
    hydrogen_seen=site.observed[1],oxygen_seen=site.observed[2]}
  end end
  write('flow',{passed=true,tick=event.tick,orientations=flows,source_cycle_seconds=4,animation_speed=8/(60*4),
    scope='genuine split output delivered to each assigned native pipe; fixture quantities only, not production balancing'})
  write('screenshots',{requested=state.shots,decoded=false,graphical_seating_verified=false})
  state.complete=true;log('TP_MH7_ELECTROLYZER REAL_SPLIT_FLOW_PASS orientations=4')
 end
end)
