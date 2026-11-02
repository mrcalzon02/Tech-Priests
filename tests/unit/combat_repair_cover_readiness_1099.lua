-- 1099: live defensive cover must not be inferred from buffered
-- electric energy or fuel without the native grid/0716 pipeline.
-- Source fixtures test the production 0517 selector; actual Factorio
-- attack, delivery and physical 0516 healing remain independent gates.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Doctrine=require("scripts.core.combat_repair_doctrine_0517")
game={tick=100}
defines={inventory={turret_ammo=1},entity_status={no_power=9}}
local player={name="player",index=1}
local hostile={name="enemy",index=2}
function player.is_enemy(other) return other==hostile end
local surface={valid=true,index=1}
local station={valid=true,name="planetary-magos-cogitator-station",
  unit_number=11,position={x=0,y=0},surface=surface,force=player}
local priest={valid=true,name="tech-priest",unit_number=12,
  position={x=0,y=0},surface=surface,force=player}
local wall={valid=true,name="stone-wall",type="wall",unit_number=40,
  health=100,max_health=270,position={x=3,y=0},
  surface=surface,force=player}
local enemy={valid=true,name="small-biter",type="unit",unit_number=50,
  position={x=6,y=0},surface=surface,force=hostile}
local pair={station=station,priest=priest,radius=24}
storage={tech_priests={pairs_by_station={[11]=pair}}}
_G.station_has_repair_pack=function(e) return e==station end
local objects={}
function surface.find_entities_filtered(spec)
  local result={}
  for _,entity in ipairs(objects) do
    local x,y=entity.position.x,entity.position.y
    local area=spec.area
    local within=not area or (x>=area[1][1] and x<=area[2][1]
      and y>=area[1][2] and y<=area[2][2])
    if within and (not spec.force or spec.force==entity.force) then
      result[#result+1]=entity
    end
  end
  return result
end
local function set_cover(turret)
  objects={wall,enemy,turret}
end
local function eligible(expected,label)
  local found=Doctrine.find_combat_repair_target(pair)
  assert((found==wall)==expected,label)
end

local connected=false
local laser={valid=true,name="laser-turret",type="electric-turret",
  unit_number=61,position={x=4,y=0},surface=surface,force=player,
  energy=20000,electric_network_id=7,active=true,
  shooting_target=enemy,
  is_connected_to_electric_network=function()return connected end}
set_cover(laser)
eligible(false,"disconnected laser buffer and stale target were counted as cover")
connected=true
eligible(true,"live powered laser incorrectly rejected as cover")
laser.electric_network_id=0
eligible(false,"unidentified electrical grid was counted as cover")
laser.electric_network_id=7
laser.energy=0
eligible(false,"empty connected laser was counted as cover")
laser.energy=20000
laser.status=defines.entity_status.no_power
eligible(false,"native no-power status was counted as cover")
laser.status=nil

local fluid_state="input-pipeline-unconnected"
local calls=0
local flame={valid=true,name="flamethrower-turret",type="fluid-turret",
  unit_number=62,position={x=4,y=0},surface=surface,force=player,
  active=true,shooting_target=enemy,
  fluidbox={{name="light-oil",amount=200}}}
set_cover(flame)
_G.TechPriestsFluidTurretReadiness0716=nil
eligible(false,"internal flame oil alone authorized unsafe repair")
_G.TechPriestsFluidTurretReadiness0716={
  inspect_entity=function(p,e,fresh)
    assert(p==pair and e==flame and fresh==true,
      "0517 bypassed canonical fresh fluid-readiness inspection")
    calls=calls+1
    return {state=fluid_state}
  end}
eligible(false,"disconnected oil pipe was counted as covering fire")
fluid_state="wrong-fluid-contamination"
eligible(false,"contaminated flamethrower was counted as covering fire")
fluid_state="fluid-ammunition-ready"
eligible(true,"0716-confirmed live flamethrower was not counted as cover")
assert(calls>=3,"0716 was not consulted for live flame readiness")

local rounds=0
local ammo={valid=true,is_empty=function()return rounds==0 end}
local gun={valid=true,name="gun-turret",type="ammo-turret",
  unit_number=63,position={x=4,y=0},surface=surface,force=player,
  active=true,shooting_target=enemy,
  get_inventory=function(id)
    if id==defines.inventory.turret_ammo then return ammo end
  end}
set_cover(gun)
eligible(false,"empty gun was counted due solely to a stale target")
rounds=10
eligible(true,"physically loaded gun rejected as cover")
objects={wall,gun}
eligible(false,"defensive repair accepted a wall without nearby hostiles")
-- Quiet inter-wave repair is permitted ONLY against 0817's real, local,
-- recent hostile-damage record, not arbitrary damage or another station.
local remembered={
  id=88,station_unit=station.unit_number,
  force_name=player.name,surface_index=surface.index,
  position={x=wall.position.x,y=wall.position.y},
  last_tick=game.tick,active_until=game.tick+600,
  hit_count=1}
pair.defense_perimeter_0259={hostile_incidents_0817={remembered}}
local selected,context=Doctrine.find_combat_repair_target(pair)
assert(selected==wall and context.post_assault_window==true
  and context.hostile_incident_id==88,
  "recent real hostile hit failed to authorize inter-wave wall repair")
remembered.force_name=hostile.name
eligible(false,"another force's incident authorized wall repair")
remembered.force_name=player.name
remembered.surface_index=2
eligible(false,"another surface's incident authorized wall repair")
remembered.surface_index=surface.index
remembered.station_unit=99
eligible(false,"another station's incident authorized wall repair")
remembered.station_unit=station.unit_number
remembered.position={x=100,y=100}
eligible(false,"unrelated distant hostile incident authorized wall repair")
remembered.position={x=wall.position.x,y=wall.position.y}
remembered.hit_count=0
eligible(false,"unverified zero-hit incident authorized wall repair")
remembered.hit_count=1
game.tick=remembered.active_until
eligible(false,"cooled incident continued authorizing combat repair")
-- New actual enemies still permit the original under-fire selection;
-- the historical incident is never a replacement for real covering fire.
game.tick=100
objects={wall,enemy,gun}
eligible(true,"active biter attack stopped authorizing covered wall repair")
print("[combat-repair-cover-readiness-1099] PASS native laser grid, canonical connected oil, ammo and bounded 0817 post-assault repair")
