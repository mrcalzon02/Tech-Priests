-- Orbital Trader visuals: existing native cargo-pod/procession, authored hatch only.
-- This module does not alter crafting, inventories, fuel, power or native wires.
local M={}
local NAME='orbital-trader'
local POD='tp-orbital-native-cargo-pod'
local OPEN_TICKS,CLOSE_TICKS=90,90
local function state()
 storage.tp_orbital_visuals=storage.tp_orbital_visuals or{machines={},native_arrivals=0,cycles=0}
 return storage.tp_orbital_visuals
end
local function valid(x)return x and x.valid end
local function destroy(x)if valid(x)then x.destroy()end end
local function clear(r)
 destroy(r.back);destroy(r.front);destroy(r.mask)
 -- This pod is an owned empty visual instance, never a real delivery shipment.
 destroy(r.pod);r.pod=nil
end
local function register(e)
 if not(valid(e)and e.name==NAME and e.unit_number)then return end
 local s=state();if s.machines[e.unit_number]then return end
 s.machines[e.unit_number]={entity=e,phase='idle',phase_tick=game.tick,job=0,last_progress=0,last_recipe=false}
end
local function scan()
 state().initialized=true
 for _,surface in pairs(game.surfaces)do for _,e in pairs(surface.find_entities_filtered{name=NAME})do register(e)end end
end
local function built(ev)register(ev.created_entity or ev.entity or ev.destination)end
local function removed(ev)
 local e=ev.entity;if not(e and e.unit_number)then return end
 local s=state();local r=s.machines[e.unit_number];if r then clear(r);s.machines[e.unit_number]=nil end
end
local function frame(r,k)
 local e=r.entity
 local function layer(key,prototype,target,render_layer)
  local obj=r[key]
  if not valid(obj)then obj=rendering.draw_animation{animation=prototype,target=target,surface=e.surface,animation_speed=0,animation_offset=k,render_layer=render_layer};r[key]=obj
  elseif obj.animation_offset~=k then obj.animation_offset=k end
 end
 layer('back','tp-orbital-hatch-back-v1',e,'cargo-hatch')
 -- A compensated target offset sorts the front leaves ahead of the native pod
 -- on air-object, while the sprite shift retains the measured world position.
 layer('front','tp-orbital-hatch-front-v1',{entity=e,offset={0,3}},'air-object')
 if not valid(r.mask)then r.mask=rendering.draw_sprite{sprite='tp-orbital-front-wall-mask-v1',target={entity=e,offset={0,3}},surface=e.surface,render_layer='air-object'}end
 r.mask.visible=r.phase=='receiving'and valid(r.pod)or false
 r.frame=k
end
local function recipe_name(e)
 local r=e.get_recipe();local n=r and r.name
 if n and type(n)~='string'then n=n.name end
 return n or false
end
local function spawn(r,tick)
 local e=r.entity
 local p=e.surface.create_entity{name=POD,position={e.position.x-.65,e.position.y+1},force=e.force}
 if not valid(p)then r.phase='closing';r.phase_tick=tick;r.spawn_failed=true;return end
 r.pod=p;r.spawn_tick=tick;r.phase='receiving';r.received_tick=nil
 -- Native Factorio chooses and executes the existing landing procession.
 p.cargo_pod_destination={type=defines.cargo_destination.surface,surface=e.surface,position={e.position.x-.65,e.position.y+1},land_at_exact_position=true}
 p.force_finish_ascending()
end
local function delivered(ev)
 local p=ev.cargo_pod;if not(valid(p)and p.name==POD)then return end
 for _,r in pairs(state().machines)do if r.pod==p then
  r.received_tick=ev.tick;state().native_arrivals=state().native_arrivals+1
  local box=ev.spawned_container
  if valid(box)and box.get_item_count()==0 then box.destroy()end
  return
 end end
end
local function update(ev)
 local s=state()
 if not s.initialized then scan()end
 for id,r in pairs(s.machines)do
  local e=r.entity
  if not valid(e)then clear(r);s.machines[id]=nil
  else
   local recipe=recipe_name(e);local progress=e.crafting_progress or 0
   local advancing=progress>(r.last_progress or 0)+1e-8
   if recipe~=r.last_recipe or(progress<r.last_progress-.01 and r.last_progress>.5)then r.job=r.job+1 end
   r.last_recipe=recipe;r.last_progress=progress
   if r.phase=='idle'then
    frame(r,0)
    if recipe and advancing and e.is_crafting()and r.started_job~=r.job then
     r.started_job=r.job;r.phase='opening';r.phase_tick=ev.tick;r.spawn_failed=nil;s.cycles=s.cycles+1
    end
   elseif r.phase=='opening'then
    local p=math.min(1,(ev.tick-r.phase_tick)/OPEN_TICKS);frame(r,math.floor(p*20+.5))
    if p>=1 then spawn(r,ev.tick)end
   elseif r.phase=='receiving'then
    frame(r,20)
    -- Do not close through an existing capsule. The engine's entire native
    -- landing/parking sequence finishes before the doors are allowed to close.
    if not valid(r.pod)then r.pod=nil;r.phase='closing';r.phase_tick=ev.tick end
   elseif r.phase=='closing'then
    local p=math.min(1,(ev.tick-r.phase_tick)/CLOSE_TICKS);frame(r,20-math.floor(p*20+.5))
    if p>=1 then r.phase='idle';r.phase_tick=ev.tick end
   end
  end
 end
end
function M.inspect()
 local s=state();local rows={}
 for id,r in pairs(s.machines)do rows[#rows+1]={unit=id,phase=r.phase,frame=r.frame,job=r.job,received_tick=r.received_tick,pod_valid=valid(r.pod)or false,pod_state=valid(r.pod)and r.pod.cargo_pod_state or false,entity_valid=valid(r.entity)or false,render_objects_valid=valid(r.front)and valid(r.back)and valid(r.mask)or false,spawn_failed=r.spawn_failed or false}end
 return{machines=rows,native_arrivals=s.native_arrivals,cycles=s.cycles,native_pod_reused=true,authored_replacement_pod=false}
end
function M.install_main(registry)
 local function opts(route)return{owner='orbital_trader_visuals',route=route,id='orbital-trader-visuals:'..route,category='visuals'}end
 registry.on_init(scan,opts('initial-scan'));registry.on_configuration_changed(scan,opts('configuration-scan'));-- Live entity visuals use the canonical event path, like existing weapon visuals.
 -- Passive nth-tick services are intentionally dormant-gated before a priest exists.
 registry.on_event(defines.events.on_tick,function(ev)if ev.tick%6==0 then update(ev)end end,nil,opts('hatch-and-native-pod'))
 for _,name in ipairs({'on_built_entity','on_robot_built_entity','script_raised_built','script_raised_revive','on_space_platform_built_entity','on_entity_cloned'})do local id=defines.events[name];if id then registry.on_event(id,built,nil,opts('built-'..name))end end
 for _,name in ipairs({'on_player_mined_entity','on_robot_mined_entity','on_entity_died','script_raised_destroy'})do local id=defines.events[name];if id then registry.on_event(id,removed,nil,opts('removed-'..name))end end
 registry.on_event(defines.events.on_cargo_pod_delivered_cargo,delivered,nil,opts('owned-native-pod-delivery'))
 remote.add_interface('tp_orbital_visuals',{inspect=M.inspect})
 return true
end
return M
