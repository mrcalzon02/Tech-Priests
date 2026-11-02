-- 1091: actual live gun/laser/flame/wall accounting, never fixture-credit.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
defines={inventory={turret_ammo=1}}
local M=require("scripts.core.defense_layer_audit_1091")
local force={index=1}
local other={index=2}
local surface={}
local entities={}
local next_id=100
local function add(name,opts)
  opts=opts or {}
  next_id=next_id+1
  local e={name=name,valid=true,unit_number=next_id,
    force=opts.force or force,surface=surface,
    position={x=1,y=2},energy=opts.energy,
    electric_network_id=opts.grid,fluidbox=opts.fluidbox,
    health=opts.health,prototype={max_health=opts.max_health},
    is_connected_to_electric_network=function()
      return opts.connected==true end,
    get_inventory=function()
      return {valid=true,get_item_count=function(item)
        return item=="firearm-magazine" and (opts.rounds or 0) or 0
      end}
    end}
  entities[#entities+1]=e
  return e
end
function surface.find_entities_filtered(spec)
  assert(spec.limit==128 and spec.force==force
    and #spec.type==4 and spec.area,
    "battle audit used unsafe/unbounded or wrong-force scan")
  local out={}
  for _,e in ipairs(entities)do
    if e.valid and e.force==spec.force then out[#out+1]=e end
  end
  return out
end
local gun=add("gun-turret",{rounds=20})
local empty=add("gun-turret")
local laser=add("laser-turret",{grid=7,energy=100,connected=true})
local disconnected=add("laser-turret",{grid=7,energy=100})
local flame=add("flamethrower-turret",{
  fluidbox={{name="light-oil",amount=30}}})
local empty_flame=add("flamethrower-turret",{fluidbox={}})
local wall=add("stone-wall",{health=230,max_health=350})
local healthy=add("stone-wall",{health=350,max_health=350})
local hostile=add("laser-turret",{force=other,grid=7,energy=100,
  connected=true})
local out=assert(M.inspect(surface,force,{x=0,y=0},40))
assert(out.guns==2 and out.loaded_guns==1 and out.gun_rounds==20,
  "gun turret count was incorrectly treated as ammunition supply")
assert(out.lasers==2 and out.energized_lasers==1,
  "laser hardware falsely counted disconnected lasers as usable")
assert(out.flames==2 and out.fueled_flames==1
  and out.flamethrower_fuel==30 and out.fluid_types["light-oil"]==1,
  "flamethrower pipe or body falsely counted as actual fuel")
assert(out.walls==2 and out.damaged_walls==1
  and out.unit_count==8 and out.truncated==false
  and out.wall_health_by_unit[wall.unit_number]==230
  and out.wall_health_by_unit[healthy.unit_number]==350
  and out.gun_rounds_by_unit[gun.unit_number]==20
  and out.gun_rounds_by_unit[empty.unit_number]==0,
  "real defense entity identity, wall health or round-custody snapshots incorrect")
gun.get_inventory=function()
  return {valid=true,get_item_count=function()return 0 end}
end
laser.energy=0
flame.fluidbox[1]={name="water",amount=100}
wall.health=350
local disabled=assert(M.inspect(surface,force,{x=0,y=0},40))
assert(disabled.loaded_guns==0 and disabled.energized_lasers==0
  and disabled.fueled_flames==0
  and disabled.fluid_types["unusable:water"]==1
  and disabled.damaged_walls==0,
  "outage/empty ammunition/fluid contamination/repair recovery missed")
empty.valid=false
disconnected.valid=false
empty_flame.valid=false
healthy.valid=false
assert(M.inspect(surface,force,{x=0,y=0},40).unit_count==4,
  "destroyed defenses were still claimed as real")
print("[defense-layer-audit-1091] PASS distinct live guns, laser power, actual flame oil, wall damage, outage and contamination")
