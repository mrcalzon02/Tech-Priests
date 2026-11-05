-- Native copper-network bridge planning. A pole on each endpoint is
-- insufficient unless Factorio's electric_network_id proves they join.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=17000}
local force={index=1}
local surface={index=1}
local station={valid=true,unit_number=1,name="planetary-magos-cogitator-station",
 position={x=0,y=0},force=force,surface=surface}
local priest={valid=true,unit_number=2,position={x=0,y=1},
 force=force,surface=surface}
local pair={station=station,priest=priest,radius=40}
storage={tech_priests={pairs_by_station={[1]=pair}}}
local entities={
 {valid=true,unit_number=3,name="lab",type="lab",
   position={x=20,y=0},energy=0,surface=surface,force=force},
 {valid=true,unit_number=4,name="offshore-pump",type="offshore-pump",
   position={x=-10,y=0},surface=surface,force=force},
 {valid=true,unit_number=5,name="boiler",type="boiler",
   position={x=-4,y=0},surface=surface,force=force},
 {valid=true,unit_number=6,name="steam-engine",type="generator",
   position={x=2,y=0},surface=surface,force=force},
 {valid=true,unit_number=7,name="small-electric-pole",type="electric-pole",
   position={x=4,y=0},surface=surface,force=force,
   prototype={supply_area_distance=2.5,maximum_wire_distance=7.5},
   electric_network_id=100},
 {valid=true,unit_number=8,name="small-electric-pole",type="electric-pole",
   position={x=18,y=0},surface=surface,force=force,
   prototype={supply_area_distance=2.5,maximum_wire_distance=7.5},
   electric_network_id=200},
}
surface.find_entities_filtered=function(spec)
 local names={}
 for _,name in ipairs(type(spec.type)=="table"and spec.type or {spec.type})do
  names[name]=true
 end
 local out={}
 for _,entity in ipairs(entities)do
  if names[entity.type]then out[#out+1]=entity end
 end
 return out
end
local can_place=true
surface.can_place_entity=function(spec)
 return can_place and spec.name=="small-electric-pole"
end
prototypes={item={["small-electric-pole"]={
 place_result={name="small-electric-pole"}}},
 entity={["small-electric-pole"]={maximum_wire_distance=7.5}}}
local stock=6
_G.TechPriestsStorageRoleAuthority0686={
 generic_item_count=function(p,item)
  assert(p==pair and item=="small-electric-pole")
  return stock
 end,
}
local Power=require("scripts.core.power_setup_1252")
local requested,detail=Power.service_pair(pair)
local req=pair.structure_construction_requested_item
assert(requested and detail=="physical-power-build-requested:"..
 "native-copper-network-bridge:small-electric-pole"
 and req and req.owner=="power-setup-1252"
 and req.power_setup_stage_1252=="native-copper-network-bridge"
 and req.position.x>4 and req.position.x<18
 and (req.position.x-4)^2+req.position.y^2<7.5^2
 and stock==6,
 "isolated generator/consumer network did not request one buildable bridge")
local again,why=Power.service_pair(pair)
assert(again and pair.structure_construction_requested_item==req
 and why=="power-build-awaiting-original-0338:small-electric-pole",
 "persistent bridge construction was replaced/duplicated")
pair.structure_construction_requested_item=nil
entities[6].electric_network_id=100
local joined,joined_why=Power.service_pair(pair)
assert(not joined
 and joined_why=="shared-native-electric-network-await-fuel-or-generation"
 and pair.structure_construction_requested_item==nil,
 "identical native copper-network ID still demanded bridges")
entities[6].electric_network_id=200
entities[5].electric_network_id=nil
local unknown,unknown_why=Power.service_pair(pair)
assert(not unknown
 and unknown_why=="unobservable-electric-pole-copper-network-or-wire-reach",
 "missing native generator-network proof caused imaginary link")
entities[5].electric_network_id=100
entities[6].position={x=9,y=0}
-- Keep the lab covered by the actual consumer pole, not accidentally by
-- the new generator-side bridge pole. Otherwise the latter may genuinely
-- serve the lab even while the old isolated consumer network stays separate.
entities[1].position={x=12,y=0}
local adjacent,adjacent_why=Power.service_pair(pair)
local nearby_request=pair.structure_construction_requested_item
assert(adjacent and adjacent_why=="physical-power-build-requested:"..
 "native-copper-network-bridge:small-electric-pole"
 and nearby_request and nearby_request.owner=="power-setup-1252"
 and nearby_request.position.x>4 and nearby_request.position.x<9
 and (nearby_request.position.x-4)^2+nearby_request.position.y^2<7.5^2
 and (nearby_request.position.x-9)^2+nearby_request.position.y^2<7.5^2,
 "separate native networks within wire range failed physical bridge repair")
assert(entities[5].electric_network_id==100
 and entities[6].electric_network_id==200 and stock==6,
 "repair proposal fabricated a network connection or pole stock")
pair.structure_construction_requested_item=nil
-- If Factorio physically builds the repair pole but it still only belongs
-- to the source network, preserve the measured split and stop the planner
-- from burning hundreds of real poles in the same obstructed gap.
entities[#entities+1]={valid=true,unit_number=57,
 name="small-electric-pole",type="electric-pole",
 position={x=nearby_request.position.x,y=nearby_request.position.y},
 force=force,surface=surface,
 prototype={supply_area_distance=2.5,maximum_wire_distance=7.5},
 electric_network_id=100}
local still_split,split_why=Power.service_pair(pair)
assert(not still_split
 and split_why=="physical-adjacent-bridge-did-not-join-sink-network"
 and pair.structure_construction_requested_item==nil and stock==6,
 "an installed but unjoined close-gap bridge spent another real pole")
table.remove(entities)
entities[6].position={x=18,y=0}
entities[1].position={x=20,y=0}
can_place=false
local illegal,illegal_why=Power.service_pair(pair)
assert(not illegal and illegal_why=="no-legal-physical-wire-bridge-site"
 and pair.structure_construction_requested_item==nil,
 "engine-refused bridge candidate passed physical construction")
can_place=true
stock=0
local empty,empty_why=Power.service_pair(pair)
assert(not empty and empty_why=="equipment-shortage:small-electric-pole"
 and pair.structure_construction_requested_item==nil,
 "empty box funded an invented copper-wire bridge")
print("[power-copper-bridge-1253] PASS real network IDs, nearby disconnected pole repair, no repeated unjoined poles, measured wire reach, native legal sites, zero synthetic stock")
