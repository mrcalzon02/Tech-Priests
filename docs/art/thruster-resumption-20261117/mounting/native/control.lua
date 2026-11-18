local names={'hydrogen-thruster','thetazine-thruster','void-fusion-thruster','large-void-fusion-thruster'}
local fluids={{'liquid-hydrogen','liquid-oxygen'},{'thetazine-fuel','water'}}
local Operation=require('__tech-priests__/scripts/core/void_fusion_operation')
local reloaded=false
local function write(name,data)helpers.write_file('thruster-resume/'..name..'.json',helpers.table_to_json(data),false)end
local function sample(row,t)
 local e=row.entity
 local sinks=row.surface.find_entities_filtered{name='void-fusion-thruster-power-sink'}
 local ports={}
 for i in ipairs(e.prototype.fluidbox_prototypes)do
  for _,p in ipairs(e.get_fluid_box_pipe_connections(i)or{})do ports[#ports+1]={position=p.position,target_position=p.target_position,connected=p.target and p.target.name or false}end
 end
 return {tick=t,name=e.name,unit=e.unit_number,position=e.position,status=e.status,platform_speed=row.platform.speed,platform_state=row.platform.state,platform_paused=row.platform.paused,platform_weight=row.platform.weight,platform_distance=row.platform.distance,location=row.platform.space_location and row.platform.space_location.name or false,connection=row.platform.space_connection and row.platform.space_connection.name or false,fluid1=e.get_fluid(1),fluid2=e.get_fluid(2),sink_count=#sinks,sink_unit=sinks[1]and sinks[1].unit_number or false,sink_energy=sinks[1]and sinks[1].energy or 0,power_usage_watts=sinks[1]and sinks[1].power_usage*60 or 0,ports=ports}
end
local function power(row)
 row.power=assert(row.surface.create_entity{name='thruster-proof-power',position={12,-4},force='player'})
 row.power.energy=100000000
end
script.on_load(function()reloaded=storage.complete or false end)
script.on_init(function()
 if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true);remote.call('freeplay','set_disable_crashsite',true)end
 storage.start=game.tick;storage.rows={};storage.samples={};storage.result={rows={}}
 local force=game.forces.player;force.unlock_space_location('vulcanus')
 for i,name in ipairs(names)do
  local p=assert(force.create_space_platform{name='Four-drive proof '..name,planet='nauvis',starter_pack='space-platform-starter-pack'})
  p.apply_starter_pack(true);local s=p.surface;s.request_to_generate_chunks({0,0},3);s.force_generate_chunk_requests()
  local tiles={};for x=-4,20 do for y=-5,4 do tiles[#tiles+1]={name='space-platform-foundation',position={x,y}}end end;s.set_tiles(tiles)
  local edge=0 -- Both sealed drives now hang over the deck edge. Only fore rows remain foundation.
  local void={};for x=12,20 do for y=edge+1,100 do void[#void+1]={name='empty-space',position={x,y}}end end;s.set_tiles(void)
  if i==3 then
   local trim={};for x=-4,20 do for y=-5,4 do
    local hub=x>=-3 and x<=3 and y>=-3 and y<=3
    local corridor=x>=4 and x<=16 and y>=-1 and y<=1
    local spine=x==16 and y>=-4 and y<=4
    if not(hub or corridor or spine)then trim[#trim+1]={name='empty-space',position={x,y}}end
   end end;s.set_tiles(trim)
  end
  local pos=i==2 and {16.5,.5}or i==3 and {16.5,.5}or {16,0}
  local legal=s.can_place_entity{name=name,position=pos,direction=defines.direction.north,force='player'}
  assert(legal,'Illegal actual thruster site '..name)
  local e=assert(s.create_entity{name=name,position=pos,direction=defines.direction.north,force='player',raise_built=true})
  e.destructible=false
  local row={name=name,entity=e,surface=s,platform=p,legal=legal,cycle_samples={}};storage.rows[i]=row
  if i<=2 then
   for n,f in ipairs(fluids[i])do assert(e.set_fluid(n,{name=f,amount=e.get_fluid_capacity(n)*.85})>0)end
   for n in ipairs(e.prototype.fluidbox_prototypes)do for _,c in ipairs(e.get_fluid_box_pipe_connections(n)or{})do local t=c.target_position;assert(s.create_entity{name='pipe',position=t,force='player'})end end
  else
   assert(s.create_entity{name='substation',position={13,-1},force='player'})
   row.expected_operation={};Operation.sample(row.expected_operation,storage.start+10,e.unit_number)
  end
  row.initial=sample(row,0)
  p.schedule={current=1,records={{station='vulcanus',wait_conditions={{type='time',ticks=3600}}}}};p.paused=false
 end
end)
script.on_event(defines.events.on_tick,function()
 local t=game.tick-storage.start
 if t%30==0 then for _,r in ipairs(storage.rows)do r.platform.destroy_asteroid_chunks{};for _,e in pairs(r.surface.find_entities_filtered{type='asteroid'})do e.destroy()end end end
 if t==120 then
  for i,r in ipairs(storage.rows)do
   r.unpowered=sample(r,t)
   if i>=3 then power(r)end
  end
 end
 if t==600 then for _,r in ipairs(storage.rows)do r.working=sample(r,t)end end
 if t==720 then for i,r in ipairs(storage.rows)do if i>=3 then r.power.destroy();r.power=nil end end end
 if t==1020 then for i,r in ipairs(storage.rows)do if i>=3 then r.drained=sample(r,t);r.entity.clear_fluid_inside()end end end
 if t==1080 then for i,r in ipairs(storage.rows)do if i>=3 then r.cut=sample(r,t);power(r)end end end
 if t==1260 then for i,r in ipairs(storage.rows)do if i>=3 then local sink=r.surface.find_entities_filtered{name='void-fusion-thruster-power-sink'}[1];r.removed_sink_unit=sink.unit_number;sink.destroy{raise_destroy=true}end end end
 if t==1290 then for i,r in ipairs(storage.rows)do if i>=3 then r.repaired=sample(r,t)end end end
 if t==1380 then for _,r in ipairs(storage.rows)do r.restarted=sample(r,t)end end
 if t>=10 and t<=1560 and t%10==0 then for i,r in ipairs(storage.rows)do if i>=3 then
  local v=sample(r,t);local factor,watts,amount=Operation.sample(r.expected_operation,game.tick,r.entity.unit_number)
  v.expected_factor=factor;v.expected_power_watts=watts;v.expected_fluid_amount=amount
  r.cycle_samples[#r.cycle_samples+1]=v
 end end end
 if t==1500 then
  local result=storage.result;result.passed=true;result.scope='Native ordinary four thrusters; isolated Space Age platforms. Liquid drive original finite charge, fusion original runtime servicing using an actual disposable native electric network; no direct internal fusion fluid writes except clearing after power cut.'
  for i,r in ipairs(storage.rows)do
   local working=r.working;local out={name=r.name,placement_legal=r.legal,initial=r.initial,unpowered=r.unpowered,working=working,restarted=r.restarted}
   out.movement=math.abs(working.platform_speed)>0 and working.connection~=false
   if i<=2 then
    out.native_consumption=working.fluid1 and working.fluid2 and working.fluid1.amount<r.initial.fluid1.amount and working.fluid2.amount<r.initial.fluid2.amount
    out.connected_ports=#working.ports==2 and working.ports[1].connected=='pipe'and working.ports[2].connected=='pipe'
    out.passed=out.placement_legal and out.movement and out.native_consumption and out.connected_ports
   else
    out.drained=r.drained;out.cut=r.cut
    out.unpowered_refusal=not r.unpowered.fluid1 and not r.unpowered.fluid2
    out.powered_service=working.sink_count==1 and working.sink_energy>0 and working.fluid1 and working.fluid2 and working.fluid1.amount>0 and working.fluid2.amount>0
    out.no_visible_ports=#working.ports==0
    out.power_cut_refusal=r.drained.sink_energy<250000 and not r.cut.fluid1 and not r.cut.fluid2
    out.power_recovery=r.restarted.fluid1 and r.restarted.fluid2 and r.restarted.sink_energy>0
    out.repaired=r.repaired;out.sink_replaced=r.repaired.sink_count==1 and r.repaired.sink_unit~=r.removed_sink_unit
    out.movement=false
    for _,v in ipairs(r.cycle_samples)do if v.connection~=false and v.platform_distance and v.platform_distance>0 and v.platform_speed>0 then out.movement=true end end
    out.native_cycle=true;out.power_bounds=true;out.minimum_power_watts=math.huge;out.maximum_power_watts=0;out.minimum_fluid=math.huge;out.maximum_fluid=0;out.cycle_samples=r.cycle_samples
    for _,v in ipairs(r.cycle_samples)do
     if v.tick~=1260 then
      out.native_cycle=out.native_cycle and math.abs(v.power_usage_watts-v.expected_power_watts)<.01
      out.power_bounds=out.power_bounds and v.power_usage_watts>=6000000 and v.power_usage_watts<=18000000
      out.minimum_power_watts=math.min(out.minimum_power_watts,v.power_usage_watts);out.maximum_power_watts=math.max(out.maximum_power_watts,v.power_usage_watts)
      if v.fluid1 and v.fluid2 and v.tick~=1270 and(v.tick>=150 and v.tick<=700 or v.tick>=1120)then
       out.native_cycle=out.native_cycle and math.abs(v.fluid1.amount-v.expected_fluid_amount)<25 and math.abs(v.fluid2.amount-v.expected_fluid_amount)<25
       out.minimum_fluid=math.min(out.minimum_fluid,v.fluid1.amount);out.maximum_fluid=math.max(out.maximum_fluid,v.fluid1.amount)
      end
     end
    end
    out.significant_variation=out.maximum_power_watts-out.minimum_power_watts>4000000 and out.maximum_fluid-out.minimum_fluid>200
    out.passed=out.placement_legal and out.movement and out.unpowered_refusal and out.powered_service and out.no_visible_ports and out.power_cut_refusal and out.power_recovery and out.sink_replaced and out.native_cycle and out.power_bounds and out.significant_variation
   end
   result.rows[#result.rows+1]=out;result.passed=result.passed and out.passed or false
  end
  result.independent_phase=false
  for n,a in ipairs(storage.rows[3].cycle_samples)do local b=storage.rows[4].cycle_samples[n];if b and math.abs(a.power_usage_watts-b.power_usage_watts)>1000000 then result.independent_phase=true end end
  result.passed=result.passed and result.independent_phase
  storage.complete=true;write('native-results',result);game.auto_save('thruster-resume-complete')
 elseif t==1560 then
  local result={passed=storage.result.passed,rows={}}
  for _,r in ipairs(storage.rows)do local v=sample(r,t);v.entity_identity_preserved=v.unit==r.initial.unit;v.passed=v.entity_identity_preserved and v.fluid1~=nil and v.fluid2~=nil;if r.name:find('void%-fusion')then v.passed=v.passed and v.sink_count==1;v.operation_samples=r.cycle_samples end;result.rows[#result.rows+1]=v;result.passed=result.passed and v.passed or false end
  write(reloaded and 'reload-results'or'continuous-results',result)
 end
end)
