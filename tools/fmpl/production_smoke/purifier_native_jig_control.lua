-- Native physical connection/flow evidence. Disconnected sites stay idle.
local NAME='tp-mh7-review-purifier'
local RECIPE='tp-mh7-review-purify'
local PREFIX='TP_MH7_NATIVE_JIG '
local function check(ok,message) if not ok then error(PREFIX..'FAIL '..message,0) end end
local function write(name,data) helpers.write_file('tp-mh7-purifier-review/'..name..'.json',helpers.table_to_json(data),false) end
local function near(a,b) return math.abs(a-b)<.00001 end
script.on_init(function()
  local s=game.surfaces[1];s.peaceful_mode=true;s.always_day=true
  s.request_to_generate_chunks({16,0},2);s.force_generate_chunk_requests()
  for _,e in pairs(s.find_entities_filtered{area={{-10,-10},{50,10}}}) do if e.valid then e.destroy() end end
  local tiles={}
  for x=-8,48 do for y=-8,8 do tiles[#tiles+1]={name='concrete',position={x,y}} end end
  s.set_tiles(tiles,true)
  storage.mh7_jig={sites={},completed=false,seen_output=false,observed_output=0}
  local rows={}
  local cases={{'disconnected',false,false},{'both-connected',true,true},
               {'input-only',true,false},{'output-only',false,true}}
  for i,case in ipairs(cases) do
    local center={x=(i-1)*12+.5,y=.5}
    local m=assert(s.create_entity{name=NAME,position=center,force=game.forces.player})
    m.set_recipe(RECIPE);check(m.get_recipe() and m.get_recipe().name==RECIPE,'recipe assignment')
    local changed=m.rotate();check(not changed and m.direction==defines.direction.north,'fixed machine rotation')
    local site={machine=m,label=case[1],pipes={}}
    local row={label=case[1],center=center,ports={}}
    for index,sign in ipairs({-1,1}) do
      local links=m.get_fluid_box_pipe_connections(index)
      check(#links==1,'expected one socket per box')
      local desired={x=center.x+sign*2,y=center.y}
      check(links[1].target_position and near(links[1].target_position.x,desired.x)
          and near(links[1].target_position.y,desired.y),'socket target differs from independent model-plane jig')
      local connected=case[index+1]
      local pipe=nil
      if connected then
        pipe=assert(s.create_entity{name='pipe',position=desired,force=game.forces.player})
        site.pipes[index]=pipe
        local linked=m.get_fluid_box_pipe_connections(index)
        check(linked[1].target==pipe,'actual pipe did not connect')
        local neighbor=false
        for _,record in pairs(m.get_fluid_box_neighbours(index) or {}) do if record.entity==pipe then neighbor=true end end
        check(neighbor,'no native fluidbox neighbor')
      end
      row.ports[index]={role=index==1 and 'raw-water-input' or 'purified-water-output',
        target=desired,connected=connected,flow_direction=links[1].flow_direction,
        model_mouth_relative={x=sign*1.5,y=0,z=.36},
        effective_plane_relative={x=sign*1.5,y=0},
        graphical_cap_seating_verified=false}
    end
    storage.mh7_jig.sites[i]=site;rows[i]=row
  end
  write('physical-ports',{passed=true,sites=rows,entity=NAME,
    scope='isolated review prototype; physical connection proof only; graphical fitting still requires native screenshots',
    ordinary_mod_changed=false,source_graphics='V14 geometry jig; later finishing atlases not yet substituted'})
  log(PREFIX..'PHYSICAL_PORTS_PASS sites=4')
end)
script.on_event(defines.events.on_tick,function(event)
  local state=storage.mh7_jig
  if not state or state.completed then return end
  local site=state.sites[2]
  if event.tick%30==0 then
    site.pipes[1].set_fluid(1,{name='water',amount=100})
    local output=site.pipes[2].get_fluid_contents()['tp-mh7-review-purified-water'] or 0
    if output>0 then state.seen_output=true;state.observed_output=state.observed_output+output end
    site.pipes[2].remove_fluid(1,1000000)
  end
  if event.tick>=600 then
    local m=site.machine
    check(m.products_finished>0 and state.seen_output,'no genuine purified fluid delivered to native pipe')
    write('flow',{passed=true,tick=event.tick,products_finished=m.products_finished,
      actual_output_seen_in_pipe=state.observed_output,recipe=RECIPE,
      source_cycle_seconds=4,declared_animation_speed=8/(60*4),
      native_graphical_frame_clock_verified=false,ordinary_recipe_or_economy_changed=false})
    state.completed=true
    log(PREFIX..'REAL_FLOW_PASS products='..m.products_finished)
  end
end)
