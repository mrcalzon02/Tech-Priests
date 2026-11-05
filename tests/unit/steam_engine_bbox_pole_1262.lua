-- 1262: the first real generator pole must reach a tile of a physical
-- steam engine, not necessarily its center. All physical building remains
-- the sole 0338 executor's responsibility; no inventory/power is created.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=36000}
local force={index=1,name="player"}
local surface={valid=true,index=1}
local station={valid=true,unit_number=1,name="planetary-magos-cogitator-station",
 position={x=0,y=0},force=force,surface=surface}
local priest={valid=true,unit_number=2,position={x=0,y=1},
 force=force,surface=surface}
local pair={station=station,priest=priest,radius=38}
storage={tech_priests={pairs_by_station={[1]=pair}}}
local lab={valid=true,unit_number=3,name="lab",type="lab",
 position={x=4,y=4},energy=0,force=force,surface=surface}
local pump={valid=true,unit_number=4,name="offshore-pump",type="offshore-pump",
 position={x=8,y=0},force=force,surface=surface}
local boiler={valid=true,unit_number=5,name="boiler",type="boiler",
 position={x=11,y=0},force=force,surface=surface}
local engine={valid=true,unit_number=6,name="steam-engine",type="generator",
 position={x=16,y=0},force=force,surface=surface,
 bounding_box={left_top={x=14.5,y=-2.5},
               right_bottom={x=17.5,y=2.5}}}
local entities={lab,pump,boiler,engine}
surface.find_entities_filtered=function(spec)
 local wanted={}
 for _,typ in ipairs(type(spec.type)=="table" and spec.type or{spec.type})do
  wanted[typ]=true
 end
 local out={}
 for _,e in ipairs(entities)do if e.valid and wanted[e.type]then out[#out+1]=e end end
 return out
end
local legal_pole={x=19.5,y=0.5}
local allow=true
surface.can_place_entity=function(spec)
 assert(spec.force==force and spec.name=="small-electric-pole",
  "pole planning unexpectedly creates or queries a different machine")
 return allow and spec.position.x==legal_pole.x
   and spec.position.y==legal_pole.y
end
prototypes={item={
 ["small-electric-pole"]={place_result={name="small-electric-pole"}},
},entity={
 ["small-electric-pole"]={supply_area_distance=2.5},
}}
local stock=2
_G.TechPriestsStorageRoleAuthority0686={
 generic_item_count=function(p,item)
  assert(p==pair and item=="small-electric-pole")
  return stock
 end,
}
local Power=require("scripts.core.power_setup_1252")
-- Center-to-center distance is 3.5, beyond a 2.5-tile pole radius.
-- The real collision box right edge is 17.5, only 2.0 tiles away.
assert(math.abs(legal_pole.x-engine.position.x)>2.5
 and legal_pole.x-engine.bounding_box.right_bottom.x<=2.5,
 "test does not isolate real footprint-versus-center coverage")
local ok,reason=Power.service_pair(pair)
local req=pair.structure_construction_requested_item
assert(ok and reason==
 "physical-power-build-requested:generation-output-pole:small-electric-pole"
 and req and req.owner=="power-setup-1252"
 and req.position.x==legal_pole.x and req.position.y==legal_pole.y
 and req.site_reason=="physical-steam-power-1252:generation-output-pole"
 and stock==2 and pair.construction_task_0338==nil
 and lab.energy==0,
 "native engine footprint pole site was lost or physical stock fabricated")
local repeat_ok,repeat_reason=Power.service_pair(pair)
assert(repeat_ok and repeat_reason==
 "power-build-awaiting-original-0338:small-electric-pole"
 and pair.structure_construction_requested_item==req,
 "repeated scan replaced the exact pending 0338 request")
-- Only the original builder may physically install it. Simulate its receipt
-- without changing actual inventory, electricity or lab readiness here.
pair.structure_construction_requested_item=nil
local pole={valid=true,unit_number=7,name="small-electric-pole",
 type="electric-pole",position=legal_pole,force=force,surface=surface,
 prototype={supply_area_distance=2.5},electric_network_id=200}
entities[#entities+1]=pole
local after,after_reason=Power.service_pair(pair)
assert(not after and after_reason=="steam-machinery-present-await-fluid-fuel-or-grid"
 and pair.structure_construction_requested_item==nil and lab.energy==0
 and stock==2,
 "installed footprint-covering pole was duplicated or credited with power")
-- 1263: an installed, geometrically covering pole on a DIFFERENT native
-- copper network must NOT close the generator distribution step.
engine.is_connected_to_electric_network=function()return false end
engine.electric_network_id=201
legal_pole={x=13.5,y=0.5}
local split,split_reason=Power.service_pair(pair)
assert(split and split_reason==
 "physical-power-build-requested:generation-output-pole:small-electric-pole"
 and pair.structure_construction_requested_item
 and pair.structure_construction_requested_item.position.x==13.5,
 "wrong-network nearby pole suppressed generator construction")
pair.structure_construction_requested_item=nil
engine.electric_network_id=200
local same,same_reason=Power.service_pair(pair)
assert(not same and same_reason=="steam-machinery-present-await-fluid-fuel-or-grid"
 and pair.structure_construction_requested_item==nil,
 "identical real native generator/pole network was not recognized")
engine.electric_network_id=nil
local disconnected,disconnected_reason=Power.service_pair(pair)
assert(disconnected and disconnected_reason==
 "physical-power-build-requested:generation-output-pole:small-electric-pole"
 and pair.structure_construction_requested_item,
 "native unconnected generator passed a purely geometric network guess")
pair.structure_construction_requested_item=nil
-- Engine removal of that pole plus a blocked terrain test must fail closed.
pole.valid=false
allow=false
local denied,why=Power.service_pair(pair)
assert(not denied and why=="site-not-verified:small-electric-pole"
 and pair.structure_construction_requested_item==nil and stock==2,
 "engine-rejected pole site created imaginary power infrastructure")
-- Even an otherwise buildable pole cannot count as supplying this engine
-- when the generator's real footprint does not intersect its supply square.
allow=true
legal_pole={x=23.5,y=0.5}
local outside,outside_reason=Power.service_pair(pair)
assert(not outside and outside_reason=="site-not-verified:small-electric-pole"
 and pair.structure_construction_requested_item==nil and stock==2,
 "out-of-range real pole candidate was credited with engine coverage")
print("[steam-engine-bbox-pole-1262] PASS actual engine-box supply overlap, legal site, persistent request, no phantom generator power and rejected sites")
