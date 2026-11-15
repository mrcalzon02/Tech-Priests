package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local force={name="player"}
local surface={index=1}
local kits,capacity,load,ghosts=2,2,12,0
local station={valid=true,unit_number=100,name="planetary-magos-cogitator-station",
 position={x=0,y=0},force=force,surface=surface}
local pair={station=station,priest={valid=true,unit_number=101,force=force,surface=surface},
 rank_test=4,radius=40,independent_emergency_operation_0184={enabled=true}}
storage={tech_priests={pairs_by_station={[100]=pair}}}
game={tick=100}
tech_priests_0252_rank_number=function(p)return p.rank_test end
tech_priests_get_item_prototype_0440=function(name)return{name=name}end
tech_priests_get_entity_prototype_0440=function(name)return{name=name}end
tech_priests_surface_supports_martian_emergency_doctrine_0184=function()return true end
surface.can_place_entity=function()return true end
surface.find_entities_filtered=function()return{}end
surface.count_entities_filtered=function(args)
 assert(args.force==force and args.radius==40)
 return load
end
surface.create_entity=function(args)
 assert(args.name=="entity-ghost","planning cannot spawn a physical station")
 ghosts=ghosts+1
 return{valid=true,unit_number=1000+ghosts,position=args.position,
  ghost_name=args.inner_name,name=args.name,force=force,surface=surface}
end
local children={}
TECH_PRIESTS_COMMAND_HIERARCHY_0480={
 direct_capacity_remaining=function(p)assert(p==pair)return capacity end,
 direct_subordinates=function(p)assert(p==pair)return children end,
 is_direct_subordinate=function(p,c)return c.parent==p end,
}
TechPriestsStorageRoleAuthority0686={generic_item_count=function(p,item)
 assert(p==pair and item=="senior-cogitator-station")return kits end}
-- An absent kit cannot be replaced by a fictitious donor in this fixture.
package.loaded["scripts.core.station_surplus_resupply_1208"]={find_donor=function()return nil end}
local Expansion=dofile("tech-priests_src/scripts/magos_station_expansion.lua")
local function denied(reason)
 local issued,why=Expansion.request_factory_workforce(pair)
 assert(not issued and why==reason,tostring(why))
 assert(ghosts==0 and kits==2,"refused admission changed inventory or ghost count")
end
pair.independent_emergency_operation_0184.enabled=false
denied("workforce-not-autonomous-commander")
pair.independent_emergency_operation_0184.enabled=true
pair.direct_acquisition_custody_0513={}
denied("workforce-incumbent:direct_acquisition_custody_0513")
pair.direct_acquisition_custody_0513=nil
pair.order_queue_0469={current={status="active",source="player"}}
denied("workforce-explicit-order-owned")
pair.order_queue_0469=nil
capacity=0;denied("workforce-command-capacity-full");capacity=2
load=0;denied("workforce-no-factory-load");load=12
load=1;denied("workforce-current-coverage-sufficient");load=12
TechPriestsResourceReturnCourier0837={worker_reserved=function()return true end}
denied("workforce-resource-courier-reserved")
TechPriestsResourceReturnCourier0837=nil
kits=0
local issued,why=Expansion.request_factory_workforce(pair)
assert(not issued and why=="workforce-no-counted-kit"and ghosts==0 and kits==0)
kits=2
load=8
local total,rate,power=0,1,100
defines={flow_precision_index={ten_minutes=2}}
tech_priests_1133_observe_science_spm=function(p,item)
 assert(p==pair and item=="automation-science-pack");return 8 end -- short production burst
force.get_item_production_statistics=function(s)
 assert(s==surface);return{get_input_count=function(item)
 assert(item=="automation-science-pack");return total end,get_flow_count=function(spec)
 assert(spec.precision_index==2 and spec.category=="input");return rate end}end
surface.find_entities_filtered=function(args)
 if args.type=="lab"then return{{valid=true,energy=power}}end
 return{}end
denied("workforce-current-coverage-sufficient") -- stored packs cannot substitute for native output
total=10;power=0;denied("workforce-current-coverage-sufficient")
power=100;rate=5;denied("workforce-current-coverage-sufficient")
rate=1;denied("workforce-current-coverage-sufficient")
game.tick=3699;denied("workforce-current-coverage-sufficient")
game.tick=3700
assert(Expansion.request_factory_workforce(pair))
local rec=pair.station_expansion_0256
assert(rec and rec.workforce_bootstrap_1172 and rec.commander_bootstrap
 and rec.worker_station_unit==100 and rec.required_worker_rank==3
 and rec.station_item=="senior-cogitator-station")
assert(rec.ghost_position.x^2+rec.ghost_position.y^2<=400,
 "support station must share its parent's physical supply area")
assert(kits==2 and ghosts==1,"planning must not debit or fabricate station kits")
assert(pair.factory_workforce_plan_1172.desired==1,
 "measured commissioned factory shortfall did not request its first paid assistant")
assert(not Expansion.request_factory_workforce(pair)and ghosts==1 and kits==2,
 "repeated planning duplicated a reserved workforce writ")
print("[factory-workforce-ranked-bootstrap] PASS mode, custody, hierarchy, counted kits and one physical writ")
