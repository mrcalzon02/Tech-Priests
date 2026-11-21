-- Isolated Factorio 2.1 fortification acceptance: 1/2/3-tile native wall rings,
-- measured turret-to-wall clearance, seven mono tower types, explicit mixed
-- tower ratios, and typed 0/6/12/24 AAI defender formations.
-- All damage, targeting, wall destruction, and movement are native engine events.
-- Fixture supplies are only initial equipment, never factory recruitment proof.
local Registry=require("scripts.core.runtime_event_registry")
local Catalog=require("shared.combat_roster_catalog")
local Bridge=require("scripts.core.combat_roster_bridge")
local MARK="[TP-FORT] "
local TOWERS={
 autocannon={"tech-priests-bunker-autocannon","tech-priests-autocannon-magazine"},
 chicago={"tech-priests-bunker-chicago-piano","firearm-magazine"},
 minigun={"tech-priests-bunker-twin-minigun","firearm-magazine"},
 cannon={"tech-priests-bunker-twin-cannon","cannon-shell"},
 lobber={"tech-priests-bunker-lobber","tech-priests-lobber-grenade-magazine"},
 rocket={"tech-priests-bunker-rocket-salvo","rocket"},
 dish={"tech-priests-bunker-energy-dish",nil},
}
local MONO={autocannon=true,chicago=true,minigun=true,cannon=true,
 lobber=true,rocket=true,dish=true}
local CLIPS={
 {id="01-massed-units",start=80,stop=1568,step=48,x=0,y=0,zoom=.26},
 {id="02-bunker-lines",start=96,stop=1584,step=48,x=0,y=-18,zoom=.40},
 {id="03-enemy-flank",start=112,stop=1600,step=48,x=0,y=18,zoom=.40},
}
local function require_native(ok,reason)
 assert(ok,MARK.."FAIL "..tostring(reason))
end
local function tower_key(preset,index)
 if string.sub(preset,1,5)=="mono-" then
  local key=string.sub(preset,6)
  require_native(MONO[key],"unknown mono tower "..tostring(key))
  return key
 end
 if preset=="mix-autocannon-minigun-3to1" then
  return index%4==0 and "minigun" or "autocannon"
 elseif preset=="mix-autocannon-minigun-1to1" then
  return index%2==0 and "minigun" or "autocannon"
 elseif preset=="mix-autocannon-minigun-1to3" then
  return index%4==0 and "autocannon" or "minigun"
 elseif preset=="mix-rocket-dish-3to1" then
  return index%4==0 and "dish" or "rocket"
 elseif preset=="mix-all-seven" then
  local keys={"autocannon","chicago","minigun","cannon",
    "lobber","rocket","dish"}
  return keys[(index-1)%7+1]
 end
 require_native(false,"unknown tower mix "..tostring(preset))
end
local function defender_types(preset)
 local def={
  none={},
  ["guardsmen-6"]={"guardsman","guardsman","guardsman","guardsman","guardsman","guardsman"},
  ["guardsmen-12"]={"guardsman"},
  ["rangers-12"]={"skitarii-ranger"},
  ["breachers-12"]={"kataphron-breacher"},
  ["sisters-12"]={"battle-sister"},
  ["mixed-12"]={"guardsman","skitarii-ranger","battle-sister","kataphron-breacher"},
  ["mixed-24"]={"guardsman","skitarii-ranger","battle-sister","kataphron-breacher"},
 }
 local list=def[preset]
 require_native(list~=nil,"unknown defender preset "..tostring(preset))
 local count=preset=="none" and 0 or
   (preset=="guardsmen-6" and 6 or preset=="mixed-24" and 24 or 12)
 local result={}
 for i=1,count do result[#result+1]=list[(i-1)%#list+1] end
 return result
end
local function evolve_weight(points,evolution)
 if not points or #points==0 or evolution<points[1].evolution_factor then return 0 end
 for i=2,#points do
  local a,b=points[i-1],points[i]
  if evolution<=b.evolution_factor then
   local fraction=(evolution-a.evolution_factor)/
     math.max(0.0000001,b.evolution_factor-a.evolution_factor)
   return a.weight+(b.weight-a.weight)*fraction
  end
 end
 return points[#points].weight
end
local function native_spawn_profile(spawner,evolution)
 local proto=prototypes.entity[spawner]
 require_native(proto and proto.result_units,"native spawner missing "..spawner)
 local profile={}
 for _,rule in pairs(proto.result_units)do
  local weight=evolve_weight(rule.spawn_points,evolution)
  if weight>0 then profile[#profile+1]={name=rule.unit,weight=weight} end
 end
 table.sort(profile,function(a,b)return a.name<b.name end)
 return profile
end
local function pick_native_unit(profile,index,count)
 local total=0
 for _,row in ipairs(profile)do total=total+row.weight end
 require_native(total>0,"evolution produced zero native enemy weights")
 local threshold=((index-0.5)/count)*total
 local value=0
 for _,row in ipairs(profile)do
  value=value+row.weight
  if threshold<value then return row.name end
 end
 return profile[#profile].name
end
local function include_extent(bounds,entity)
 local box=entity.bounding_box
 require_native(box and box.left_top and box.right_bottom,
  "physical bounding box unavailable "..entity.name)
 bounds.x=math.max(bounds.x,math.abs(box.left_top.x),math.abs(box.right_bottom.x))
 bounds.y=math.max(bounds.y,math.abs(box.left_top.y),math.abs(box.right_bottom.y))
end
local function init()
 local settings=TP_FORT_CONFIG
 require_native(type(settings)=="table","fortification config missing")
 require_native(settings.thickness==1 or settings.thickness==2 or settings.thickness==3,
  "wall thickness must be 1/2/3")
 require_native(settings.clearance==3 or settings.clearance==7 or settings.clearance==13,
  "wall clearance must be 3/7/13")
 require_native(type(settings.evolution)=="number" and
  settings.evolution>=0 and settings.evolution<=1,"evolution outside 0..1")
 require_native(type(settings.towers)=="string" and
  type(settings.defenders)=="string","tower/defender presets required")
 if remote.interfaces.freeplay and remote.interfaces.freeplay.set_skip_intro then
  remote.call("freeplay","set_skip_intro",true)
  remote.call("freeplay","set_disable_crashsite",true)
 end
 log(MARK.."SETUP_BEGIN "..helpers.table_to_json(settings))
 local s=game.create_surface("combat-fortification-2_1-proof",{
  water=0,starting_area=0,default_enable_all_autoplace_controls=false,
  autoplace_settings={entity={treat_missing_as_default=false,settings={}}}})
 s.always_day=true;s.peaceful_mode=false
 s.request_to_generate_chunks({x=0,y=0},5)
 s.force_generate_chunk_requests()
 for _,entity in pairs(s.find_entities_filtered{area={{-104,-104},{104,104}}})do
  if entity.valid and entity.type~="character" then entity.destroy() end
 end
 local tiles={}
 for x=-98,98 do for y=-98,98 do
  tiles[#tiles+1]={name="refined-concrete",position={x=x,y=y}}
 end end
 s.set_tiles(tiles)
 local player=game.forces.player
 local enemy=game.forces.enemy
 player.set_friend(enemy,false);enemy.set_friend(player,false)
 player.set_cease_fire(enemy,false);enemy.set_cease_fire(player,false)
 enemy.set_evolution_factor(settings.evolution,s)
 local observed=enemy.get_evolution_factor(s)
 require_native(math.abs(observed-settings.evolution)<0.00001,
  "surface enemy evolution readback mismatch")
 local t={ready=false,done=false,start=game.tick,surface=s.index,
  settings=settings,evolution_initial=observed,walls={},tower_units={},
  wall_units={},towers={},defenders={},attackers={},
  defender_roster={},tower_roster={},enemy_roster={},samples={},damage={
   wall=0,tower=0,defender=0,enemy=0,other=0},
  damage_by_attacker={},damage_by_tower={},wall_losses_by_layer={},
  wall_first_loss_tick=nil,wall_first_inner_loss_tick=nil,
  enemy_first_inside_tick=nil,clips={},bounds={x=0,y=0},
  ammo_consumed=0,attacker_losses=0}
 -- 12 actual bunkers in four columns by three rows, identical positions
 -- across every mono/mixed ratio. All turrets are genuine native entities.
 for i=1,12 do
  local kind=tower_key(settings.towers,i)
  local def=TOWERS[kind]
  require_native(def~=nil,"turret prototype unresolved "..kind)
  local col=(i-1)%4
  local row=math.floor((i-1)/4)
  local position={x=(col-1.5)*20,y=(row-1)*19}
  local gun=s.create_entity{name=def[1],position=position,force=player,
    direction=defines.direction.north,raise_built=true}
  require_native(gun and gun.valid,"native turret placement failed "..kind.." slot="..i)
  log(MARK.."SETUP_TURRET_VALID slot="..i.." kind="..kind)
  -- The raised native build event installs the production visual hook.
  local rec={entity=gun,unit=gun.unit_number,kind=kind,name=def[1],
    initial_health=gun.health,ammo=def[2],initial_ammo=0}
  if def[2] then
   local count=gun.insert{name=def[2],count=80}
   require_native(count>0,"real turret refused ammunition "..kind)
   rec.initial_ammo=count
  else
   -- Self-contained, test-only native power source, never counted as a tower.
   local power=s.create_entity{name="electric-energy-interface",
    position={x=position.x+5,y=position.y+5},force=player}
   local pole=s.create_entity{name="substation",
    position={x=position.x+5,y=position.y+2},force=player}
   require_native(power and power.valid and pole and pole.valid,
    "electric dish physical supply unavailable")
   power.power_production=1000000000
   power.electric_buffer_size=1000000000
   power.energy=1000000000
   include_extent(t.bounds,power);include_extent(t.bounds,pole)
  end
  include_extent(t.bounds,gun)
  t.towers[#t.towers+1]=rec
  if rec.unit then t.tower_units[rec.unit]=kind end
  t.tower_roster[kind]=(t.tower_roster[kind] or 0)+1
 end
 require_native(#t.towers==12,"physical turret count differs from 12")
 log(MARK.."SETUP_TOWERS_READY count="..#t.towers)
 local requested=defender_types(settings.defenders)
 for i,id in ipairs(requested)do
  local unit=Catalog.by_id[id]
  require_native(unit and unit.name,"unknown integrated AAI defender "..id)
  local x,y
  if #requested==24 then
   x=((i-1)%12-5.5)*6
   y=i<=12 and -10 or 10
  else
   x=((i-1)%6-2.5)*10
   y=i<=6 and -10 or 10
  end
  local car=s.create_entity{name=unit.name,position={x=x,y=y},
   force=player,raise_built=true}
  require_native(car and car.valid,"native AAI defender placement failed "..id.."/"..i)
  local registered=Bridge.unit(car)
  require_native(registered and registered.unit_id,
   "unmanaged native AAI defender "..id.."/"..i)
  local ammo=Catalog.ammo[unit.ammo_family]
  require_native(ammo and ammo.name,"canonical defender ammunition missing "..id)
  local inventory=car.get_inventory(defines.inventory.car_ammo)
  local fuel_inventory=car.get_fuel_inventory()
  require_native(inventory and fuel_inventory,"native AAI car inventories missing "..id)
  local armed=inventory.insert{name=ammo.name,count=8}
  local fueled=fuel_inventory.insert{name="tech-priests-field-supply-pack",count=12}
  require_native(armed==8 and fueled==12,"native defender refused ammo/fuel "..id)
  -- AAI Bridge.command may replace the original LuaEntity immediately.
  -- Capture its physical collision envelope BEFORE that ownership handoff.
  require_native(car.valid,"native vehicle invalid before AAI command "..id)
  include_extent(t.bounds,car)
  log(MARK.."SETUP_AAI_PRECOMMAND slot="..i.." id="..id)
  -- Position goal remains inside the courtyard. Movement and shooting are
  -- delegated to AAI; the fixture cannot apply scripted damage or teleport.
  local goal={x=x+(x<0 and 1 or -1),y=y}
  local ok,reason=Bridge.command(car,player,{position=goal})
  require_native(ok==true,"native AAI defender command refused "..id.."/"..tostring(reason))
  -- Never dereference the possibly replaced original car after issuing AAI orders.
  t.defenders[#t.defenders+1]={unit=registered.unit_id,id=id,
    initial_ammo=armed,initial_fuel=fueled}
  t.defender_roster[id]=(t.defender_roster[id] or 0)+1
 end
 log(MARK.."SETUP_AAI_DEFENDERS_READY count="..#t.defenders)
 local inner_x=math.ceil(t.bounds.x+settings.clearance+0.5)
 local inner_y=math.ceil(t.bounds.y+settings.clearance+0.5)
 require_native(inner_x<=66 and inner_y<=66,
  "walled courtyard exceeds bounded isolated test surface")
 t.inner_half={x=inner_x,y=inner_y}
 local first_wall_distance=math.min(inner_x-0.5-t.bounds.x,
  inner_y-0.5-t.bounds.y)
 require_native(first_wall_distance>=settings.clearance-0.00001,
  "first wall ring closer to native defenses than required clearance")
 t.measured_min_clearance=first_wall_distance
 -- Continuous closed concentric rectangles: no gates, pre-placed breaches,
 -- or fake wall health. Every tile is a physically placed stone-wall entity.
 for layer=0,settings.thickness-1 do
  local hx,hy=inner_x+layer,inner_y+layer
  local function place_wall(x,y)
   local wall=s.create_entity{name="stone-wall",position={x=x,y=y},force=player}
   require_native(wall and wall.valid,
    string.format("physical wall missing layer=%d x=%d y=%d",layer,x,y))
   t.walls[#t.walls+1]={entity=wall,unit=wall.unit_number,layer=layer,
    initial_health=wall.health}
   if wall.unit_number then t.wall_units[wall.unit_number]=layer end
  end
  for x=-hx,hx do place_wall(x,-hy);place_wall(x,hy) end
  for y=-hy+1,hy-1 do place_wall(-hx,y);place_wall(hx,y) end
  t.wall_losses_by_layer[layer+1]=0
 end
 local expected_walls=0
 for layer=0,settings.thickness-1 do
  expected_walls=expected_walls+4*((inner_x+layer)+(inner_y+layer))
 end
 require_native(#t.walls==expected_walls,
  "continuous native wall ring identity/quantity mismatch")
 log(MARK.."SETUP_NATIVE_WALLS_READY count="..#t.walls)
 -- 48 exactly, native spawner-weighted for the requested surface evolution,
 -- with attack corridors originating on all four sides of the compound.
 local biters=native_spawn_profile("biter-spawner",observed)
 local spitters=native_spawn_profile("spitter-spawner",observed)
 local spitter_total=#spitters>0 and 16 or 0
 local n_biter,n_spitter=0,0
 for i=1,48 do
  local name
  if spitter_total>0 and i%3==0 then
   n_spitter=n_spitter+1
   name=pick_native_unit(spitters,n_spitter,spitter_total)
  else
   n_biter=n_biter+1
   name=pick_native_unit(biters,n_biter,48-spitter_total)
  end
  local side=(i-1)%4
  local offset=(math.floor((i-1)/4)-5.5)*5
  local outside_x=inner_x+settings.thickness+14
  local outside_y=inner_y+settings.thickness+14
  local px,py
  if side==0 then px,py=offset,-outside_y
  elseif side==1 then px,py=outside_x,offset
  elseif side==2 then px,py=offset,outside_y
  else px,py=-outside_x,offset end
  local b=s.create_entity{name=name,position={x=px,y=py},force=enemy}
  require_native(b and b.valid,"native evolution biter placement failed "..i)
  local commander=b.commandable
  require_native(commander and commander.valid,"native enemy commandable missing "..i)
  commander.set_command{type=defines.command.attack_area,destination={x=0,y=0},
    radius=6,distraction=defines.distraction.by_enemy}
  t.attackers[#t.attackers+1]={entity=b,name=name}
  t.enemy_roster[name]=(t.enemy_roster[name] or 0)+1
 end
 require_native(#t.attackers==48,"exact native hostile wave not staged")
 t.ready=true
 storage.tp_fortification_native=t
 log(MARK.."SETUP_READY "..helpers.table_to_json{
  evolution=observed,thickness=settings.thickness,
  clearance_requested=settings.clearance,measured_clearance=t.measured_min_clearance,
  walls=#t.walls,expected_walls=expected_walls,towers=t.tower_roster,
  defenders=t.defender_roster,enemies=t.enemy_roster,
  wall_inner_half=t.inner_half,defender_count=#t.defenders})
end
local function status(t)
 local native_ok,managed=pcall(remote.call,"aai-programmable-vehicles","get_units")
 native_ok=native_ok and type(managed)=="table"
 local active_defenders,active_towers,active_enemies,active_walls=0,0,0,0
 local defenders_by_type,towers_by_type,ammunition_by_type={}, {}, {}
 for _,rec in ipairs(t.defenders)do
  local owned=native_ok and managed[rec.unit] or nil
  local car=owned and owned.vehicle or nil
  if car and car.valid and car.force.name=="player" then
   active_defenders=active_defenders+1
   defenders_by_type[rec.id]=(defenders_by_type[rec.id] or 0)+1
  end
 end
 for _,rec in ipairs(t.towers)do
  local gun=rec.entity
  if gun and gun.valid then
   active_towers=active_towers+1
   towers_by_type[rec.kind]=(towers_by_type[rec.kind] or 0)+1
   if rec.ammo then
    local used=math.max(0,rec.initial_ammo-gun.get_item_count(rec.ammo))
    ammunition_by_type[rec.kind]=(ammunition_by_type[rec.kind] or 0)+used
   end
  end
 end
 for _,rec in ipairs(t.walls)do if rec.entity.valid then active_walls=active_walls+1 end end
 local s=game.surfaces[t.surface]
 local inside=0
 for _,rec in ipairs(t.attackers)do
  local b=rec.entity
  if b.valid then
   active_enemies=active_enemies+1
   if math.abs(b.position.x)<t.inner_half.x-1 and
     math.abs(b.position.y)<t.inner_half.y-1 then
    inside=inside+1
   end
  end
 end
 if inside>0 and not t.enemy_first_inside_tick then
  t.enemy_first_inside_tick=game.tick-t.start
  log(MARK.."NATIVE_BREACH tick="..t.enemy_first_inside_tick.." enemies_inside="..inside)
 end
 local by_layer={}
 for i=1,t.settings.thickness do by_layer[i]=0 end
 for _,rec in ipairs(t.walls)do
  if rec.entity.valid then by_layer[rec.layer+1]=by_layer[rec.layer+1]+1 end
 end
 return {defenders_alive=active_defenders,towers_alive=active_towers,
  enemies_alive=active_enemies,walls_alive=active_walls,
  defenders_by_type=defenders_by_type,towers_by_type=towers_by_type,
  surviving_walls_by_layer=by_layer,
  ammo_spent_by_surviving_towers=ammunition_by_type,
  enemies_inside=inside,registry_available=native_ok}
end
local function capture(t,elapsed)
 if TP_COMBAT_BATCH_VISUALS~=true then return end
 for _,clip in ipairs(CLIPS)do
  if elapsed>=clip.start and elapsed<=clip.stop and
    (elapsed-clip.start)%clip.step==0 then
   local index=math.floor((elapsed-clip.start)/clip.step)
   local path=string.format("combat-roster/batch-native/%s/frame-%04d.png",clip.id,index)
   game.take_screenshot{surface=game.surfaces[t.surface],
    position={x=clip.x,y=clip.y},resolution={1280,720},
    zoom=clip.zoom,path=path,show_gui=false,force_render=true,daytime=0}
   t.clips[clip.id]=t.clips[clip.id] or {}
   t.clips[clip.id][#t.clips[clip.id]+1]={frame=index,tick=game.tick}
  end
 end
end
local function tick(event)
 local t=storage.tp_fortification_native
 if not(t and t.ready) or t.done then return end
 local elapsed=game.tick-t.start
 capture(t,elapsed)
 -- Detect the first real hostile crossing every tick, not only at sampled
 -- 300-tick checkpoints; a brief breach must not disappear between samples.
 if not t.enemy_first_inside_tick then
  for _,rec in ipairs(t.attackers)do
   local b=rec.entity
   if b.valid and math.abs(b.position.x)<t.inner_half.x-1 and
    math.abs(b.position.y)<t.inner_half.y-1 then
    t.enemy_first_inside_tick=elapsed
    log(MARK.."NATIVE_BREACH tick="..elapsed.." attacker="..rec.name)
    break
   end
  end
 end
 if elapsed>0 and elapsed%120==0 then
  log(MARK.."HEARTBEAT elapsed="..elapsed.." engine_tick="..game.tick)
 end
 if elapsed>0 and elapsed%300==0 then
  local sample=status(t)
  t.samples[#t.samples+1]={tick=elapsed,state=sample}
  log(MARK.."SAMPLE "..helpers.table_to_json{
   elapsed=elapsed,defenders=sample.defenders_alive,
   towers=sample.towers_alive,walls=sample.walls_alive,
   enemies=sample.enemies_alive,inside=sample.enemies_inside})
 end
 if elapsed>=3600 then
  local final=status(t)
  local measured=game.forces.enemy.get_evolution_factor(game.surfaces[t.surface])
  local blockers={}
  local function verify(ok,why)
   if not ok then blockers[#blockers+1]=why end
  end
  verify(#t.samples>=10,"native 3600-tick combat samples missing")
  verify(final.registry_available,"AAI native defender registry unavailable")
  verify(math.abs(measured-t.settings.evolution)<0.015,
   "native enemy evolution factor drifted beyond acceptance")
  verify(#t.walls>0 and #t.towers==12 and #t.attackers==48,
   "genuine turret/wall/hostile setup count mismatch")
  local lost_walls=#t.walls-final.walls_alive
  local defense_held=final.enemies_alive==0 and final.enemies_inside==0
  local result={schema="tech-priests.native-fortification.v1",
   status=#blockers==0 and "PASS" or "FAIL",
   native=true,game_engine=script.active_mods.base,
   scenario="physical-walls-12-defenses-aai-and-native-evolution-hostiles",
   source="Factorio 2.1 engine",no_scripted_damage=true,
   config=t.settings,evolution_initial=t.evolution_initial,
   evolution_final=measured,
   towers_requested=12,defenders_requested=#t.defenders,
   walls_requested=#t.walls,enemies_requested=48,
   measured_min_wall_clearance=t.measured_min_clearance,
   wall_inner_half=t.inner_half,tower_roster=t.tower_roster,
   defender_roster=t.defender_roster,enemy_roster=t.enemy_roster,
   final=final,damage=t.damage,damage_by_attacker=t.damage_by_attacker,
   damage_by_tower=t.damage_by_tower,
   wall_losses_by_layer=t.wall_losses_by_layer,
   first_wall_loss_tick=t.wall_first_loss_tick,
   first_inner_wall_loss_tick=t.wall_first_inner_loss_tick,
   first_enemy_inside_tick=t.enemy_first_inside_tick,
   defense_held=defense_held,
   wall_held=t.enemy_first_inside_tick==nil,
   samples=t.samples,frames=t.clips,blockers=blockers}
  local file=TP_COMBAT_BATCH_VISUALS and
    "combat-roster/batch-native/manifest.json" or
    "combat-roster/fortification-native/manifest.json"
  -- The visual encoder expects the same authentic original screenshot receipt
  -- shape as the proven native battle batch. Headless reports are separate.
  if TP_COMBAT_BATCH_VISUALS then
   result.expected={aai_actors=#t.defenders,types=12,native_bunkers=12,
    native_biters=48,forces=2}
   result.counts={actors_alive=final.defenders_alive,
    turrets_alive=final.towers_alive,biters_alive=final.enemies_alive,
    aai_registry_available=final.registry_available}
   result.damage={player=t.damage.wall+t.damage.tower+t.damage.defender,
    renegade=0,enemy=t.damage.enemy,protected=0}
   result.hits={player=0,renegade=0,enemy=0}
   result.samples=#t.samples
  end
  helpers.write_file(file,helpers.table_to_json(result),false)
  t.done=true
  log(MARK.."NATIVE_COMBAT_COMPLETE "..helpers.table_to_json{
   status=result.status,config=t.settings,defense_held=defense_held,
   wall_held=result.wall_held,first_enemy_inside=t.enemy_first_inside_tick,
   survivors=final,blockers=blockers})
  if TP_COMBAT_BATCH_VISUALS then game.auto_save("fortification-native-proof") end
 end
end
local function on_damaged(event)
 local t=storage.tp_fortification_native
 if not(t and t.ready) or not event.entity or
  not event.final_damage_amount or event.final_damage_amount<=0 then return end
 local entity=event.entity
 local n=entity.unit_number
 local amount=event.final_damage_amount
 if n and t.wall_units[n]~=nil then
  t.damage.wall=t.damage.wall+amount
 elseif n and t.tower_units[n] then
  t.damage.tower=t.damage.tower+amount
 else
  local force=entity.force and entity.force.name
  if force=="enemy" then t.damage.enemy=t.damage.enemy+amount
  elseif force=="player" then t.damage.defender=t.damage.defender+amount
  else t.damage.other=t.damage.other+amount end
 end
 local attacker=event.cause
 local attacker_name=attacker and attacker.valid and attacker.name or "unattributed"
 t.damage_by_attacker[attacker_name]=(t.damage_by_attacker[attacker_name] or 0)+amount
 if attacker and attacker.valid and t.tower_units[attacker.unit_number] then
  local kind=t.tower_units[attacker.unit_number]
  t.damage_by_tower[kind]=(t.damage_by_tower[kind] or 0)+amount
 end
end
local function on_died(event)
 local t=storage.tp_fortification_native
 if not(t and t.ready) or not event.entity then return end
 local unit=event.entity.unit_number
 if unit and t.wall_units[unit]~=nil then
  local layer=t.wall_units[unit]
  t.wall_losses_by_layer[layer+1]=t.wall_losses_by_layer[layer+1]+1
  if not t.wall_first_loss_tick then t.wall_first_loss_tick=game.tick-t.start end
  if layer==0 and not t.wall_first_inner_loss_tick then
   t.wall_first_inner_loss_tick=game.tick-t.start
  end
 end
end
Registry.on_init(init,{owner="fortification-native",route="setup",priority=2200})
Registry.on_event(defines.events.on_tick,tick,nil,
 {owner="fortification-native",route="record-proof",priority=2200})
Registry.on_event(defines.events.on_entity_damaged,on_damaged,nil,
 {owner="fortification-native",route="native-damage",priority=2200})
Registry.on_event(defines.events.on_entity_died,on_died,nil,
 {owner="fortification-native",route="native-wall-destroy",priority=2200})
