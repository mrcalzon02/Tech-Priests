-- 1153: exact 0338-paid assembler may offer the original 0528
-- a real ingredient candidate. Offer cannot move or create ore/plates.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local M=require("scripts.core.logistics_machine_fulfillment_0528")
local saved_stock=rawget(_G,"TechPriestsStorageRoleAuthority0686")
local saved_prototypes=rawget(_G,"prototypes")
local saved_defines=rawget(_G,"defines")
local saved_storage=rawget(_G,"storage")
local saved_game=rawget(_G,"game")
local saved_courier=rawget(_G,"TechPriestsResourceReturnCourier0837")
game={tick=11530}
defines={inventory={assembling_machine_input=1,furnace_source=2}}
prototypes={item={["iron-plate"]={}}}
local force,surface={index=1},{index=1}
local machine
surface.find_entities_filtered=function(args)
 assert(args.force==force and args.type and args.limit==64,
   "0528 automation must inspect physically connected inserters/loaders")
 return {}
end
local pair={
 station={valid=true,unit_number=100,force=force,surface=surface,
   position={x=0,y=0}},
 priest={valid=true,unit_number=101,force=force,surface=surface,
   position={x=0,y=1}},
}
local station_stock=5
TechPriestsStorageRoleAuthority0686={
 generic_item_count=function(p,item)
  assert(p==pair and item=="iron-plate")
  return station_stock
 end,
}
TechPriestsResourceReturnCourier0837=nil
storage={tech_priests={pairs_by_station={[100]=pair}}}
local machine_input_count=0
local input={valid=true,get_item_count=function(item)
 assert(item=="iron-plate")
 return machine_input_count
end}
local live_recipe="iron-gear-wheel"
local recipe={name="iron-gear-wheel",ingredients={
  {name="iron-plate",type="item",amount=2}}}
machine={valid=true,type="assembling-machine",
 name="assembling-machine-1",unit_number=1153,
 surface=surface,force=force,position={x=5,y=5},
 get_inventory=function(id)if id==1 then return input end end,
 get_recipe=function()
  if live_recipe==recipe.name then return recipe end
  return {name=live_recipe,ingredients=recipe.ingredients}
 end}
local receipt={configured=true,built_entity=machine,entity_unit=1153,
 station_unit=100,recipe="iron-gear-wheel"}
pair.factory_component_last_receipt_1150=receipt
station_stock=0
local ok,why=M.offer_factory_component_feed_1153(
 pair,machine,"iron-gear-wheel")
assert(not ok and why=="no-physical-local-ingredient-stock"
 and pair.machine_logistics_candidate_0528==nil
 and machine_input_count==0,
 "factory planner offered imaginary intermediate stock")
station_stock=5
ok,why=M.offer_factory_component_feed_1153(
 pair,machine,"iron-gear-wheel")
local candidate=pair.machine_logistics_candidate_0528
assert(ok and why=="exact-physical-ingredient-delivery-candidate-offered"
 and candidate and candidate.source=="factory-component-feed-1153"
 and candidate.action=="supply-ingredient" and candidate.item=="iron-plate"
 and candidate.machine==machine and candidate.count==2
 and candidate.expires_tick>game.tick
 and station_stock==5 and machine_input_count==0,
 "original 0528 candidate was not sourced from real local plates")
local action=M.recommend_action(pair)
assert(action and action.kind=="machine-logistics"
 and action.target==machine and action.item=="iron-plate",
 "canonical dispatcher did not see the real 0528 ingredient candidate")
ok,why=M.offer_factory_component_feed_1153(
 pair,machine,"iron-gear-wheel")
assert(ok and why=="existing-exact-factory-feed-candidate"
 and pair.machine_logistics_candidate_0528==candidate,
 "repeat factory discovery doubled or replaced pending original delivery")
local other={valid=true}
pair.machine_logistics_candidate_0528={
 source="remote-drill-fuel-1016",machine=other,
 expires_tick=game.tick+100,action="supply-fuel",item="coal"}
local original=pair.machine_logistics_candidate_0528
ok,why=M.offer_factory_component_feed_1153(
 pair,machine,"iron-gear-wheel")
assert(not ok and why=="unrelated-machine-candidate-preserved"
 and pair.machine_logistics_candidate_0528==original,
 "a new science feed seized an unrelated fuel candidate")
pair.machine_logistics_candidate_0528=nil
receipt.configured=false
ok,why=M.offer_factory_component_feed_1153(pair,machine,"iron-gear-wheel")
assert(not ok and why=="factory-feed-original-0338-receipt-unverified",
 "unverified machine was accepted as a paid science asset")
receipt.configured=true
live_recipe="automation-science-pack"
ok,why=M.offer_factory_component_feed_1153(pair,machine,"iron-gear-wheel")
assert(not ok and why=="factory-feed-live-recipe-mismatch",
 "changed recipe was treated as original gear-production machine")
live_recipe="iron-gear-wheel"
pair.machine_logistics_custody_0528={item="copper-ore",count=1}
ok,why=M.offer_factory_component_feed_1153(pair,machine,"iron-gear-wheel")
assert(not ok and why=="existing-machine-or-construction-custody",
 "feed candidate preempted existing physical cargo")
pair.machine_logistics_custody_0528=nil
surface.find_entities_filtered=function(args)
 return {{valid=true,type="inserter",pickup_target=machine,
  position={x=6,y=5}}}
end
ok,why=M.offer_factory_component_feed_1153(pair,machine,"iron-gear-wheel")
assert(not ok and why=="real-inserter-or-loader-already-connected",
 "manual priest feed stole an already automated machine")
assert(station_stock==5 and machine_input_count==0,
 "read-only candidate discovery modified real stock or machine contents")
TechPriestsStorageRoleAuthority0686=saved_stock
prototypes=saved_prototypes
defines=saved_defines
storage=saved_storage
game=saved_game
TechPriestsResourceReturnCourier0837=saved_courier
print("[magos-factory-feed-offer-1153] PASS real stock, exact built recipe, source-only 0528 candidate, original custody and automation guards")
