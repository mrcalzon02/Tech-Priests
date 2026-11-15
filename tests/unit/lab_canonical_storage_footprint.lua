package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};defines={inventory={chest=1,lab_input=3},command={stop=1,go_to_location=2},distraction={none=0}}
storage={tech_priests={pairs_by_station={}}}
local force={index=1,current_research={valid=true,name="automation",
 research_unit_ingredients={{name="automation-science-pack",amount=1}}}}
local surface={index=1,valid=true,name="nauvis"};local stock,delivered=5,0
local same_text={__tostring=function()return "LuaInventory"end}
local empty=setmetatable({valid=true,get_item_count=function()return 0 end},same_text)
local cache_inv=setmetatable({valid=true,get_item_count=function()return stock end,
 remove=function(spec)local n=math.min(stock,spec.count);stock=stock-n;return n end},same_text)
local station={valid=true,unit_number=1,position={x=0,y=0},force=force,surface=surface,
 get_inventory=function()return empty end}
local cache={valid=true,unit_number=4,position={x=5,y=0},force=force,surface=surface,
 bounding_box={left_top={x=2,y=-3},right_bottom={x=8,y=3}}}
local input={valid=true,get_item_count=function()return delivered end,can_insert=function()return true end,
 insert=function(spec)delivered=delivered+spec.count;return spec.count end}
local lab={valid=true,unit_number=5,name="lab",type="lab",position={x=10,y=0},force=force,surface=surface,
 bounding_box={left_top={x=8.5,y=-1},right_bottom={x=11.5,y=1}},
 get_inventory=function(id)assert(id==3);return input end}
surface.find_entities_filtered=function(spec)
 for _,kind in ipairs(spec.type or{})do if kind=="lab"then return {lab}end end
 return {}
end
local pair={station=station,priest={valid=true,unit_number=2,position={x=0,y=0}},radius=40}
TechPriestsScanRouting0610={find_entities=function(s,filters)return s.find_entities_filtered(filters)end}
storage.tech_priests.pairs_by_station[1]=pair
prototypes={item={["automation-science-pack"]={type="tool"}}}
TechPriestsStorageRoleAuthority0686={generic_storage_sources=function()
 return {{entity=station,inv=empty},{entity=cache,inv=cache_inv}}end}
TechPriestsWorkReservations0601={categories={},root=function()return {}end,
 claim=function()return true end,release=function()return true end}
local services={}
TechPriestsRuntimeTickBroker0600={register_service=function(spec)services[spec.name]=spec;return spec end}
local Movement=require("scripts.core.movement_controller")
TECH_PRIESTS_MOVEMENT_CONTROLLER_0418=Movement
tech_priests_request_movement_0418=function(p,pos,reason,opts)return Movement.request(p,pos,reason,opts)end
local Items=require("scripts.core.item_family_logistics_0702")
assert(Items.install())
services.item_family_discovery_0702.fn(nil,1)
assert(pair.item_family_candidate_0702.source.entity==cache and stock==5,
 "science cache was hidden by an identical inventory display name")
Items.service_pair(pair)
assert(pair.movement_request_0418.x==2,"science pickup targeted solid container center")
pair.priest.position={x=.5,y=0};Items.service_pair(pair)
assert(stock==0 and delivered==0 and pair.item_family_custody_0702.count==5,
 "science packs were remotely delivered or lost at physical pickup")
assert(pair.movement_request_0418.x==8.5,"science pickup lease blocked physical delivery")
pair.priest.position={x=8,y=0};Items.service_pair(pair)
assert(delivered==5 and not pair.item_family_custody_0702 and not pair.movement_request_0418,
 "real laboratory did not receive the exact carried science packs")
force.current_research=nil;defines.inventory.turret_ammo=4
prototypes.item["firearm-magazine"]={type="ammo"}
stock=10
cache_inv.insert=function(spec)stock=stock+spec.count;return spec.count end
local proxy={valid=true,unit_number=8,name="tech-priest-small-arms-proxy",type="ammo-turret",
 position={x=10,y=0},surface=surface,force=force,
 get_inventory=function(id)assert(id==4);return {valid=true,can_insert=function()return true end,
 get_item_count=function()return 0 end,get_contents=function()return {}end}end}
surface.find_entities_filtered=function(spec)
 for _,kind in ipairs(spec.type or{})do if kind=="ammo-turret"then return {proxy}end end
 return {}
end
game.tick=game.tick+1000;services.item_family_discovery_0702.fn(nil,1)
assert(not pair.item_family_candidate_0702,"hidden proxy captured a visible turret job")
proxy.name="gun-turret"
game.tick=game.tick+1000;services.item_family_discovery_0702.fn(nil,1)
assert(pair.item_family_candidate_0702 and pair.item_family_candidate_0702.item=="firearm-magazine",
 "visible turret lost its real ammunition supply")
Items.service_pair(pair);proxy.name="tech-priest-small-arms-proxy"
Items.service_pair(pair)
assert(not pair.item_family_logistics_0702 and stock==10,
 "old unladen proxy task was not retired safely")
-- An old save may already carry counted ammunition for the wrong owner.
stock=8
pair.item_family_logistics_0702={family="turret-ammo",phase="move-to-target",
 target=proxy,item="firearm-magazine",carried={item="firearm-magazine",count=2},
 source_entity=cache,source_inv=cache_inv}
Items.service_pair(pair)
assert(stock==10 and not pair.item_family_logistics_0702 and not pair.item_family_custody_0702,
 "proxy-owner migration discarded carried ammunition")
print("PASS counted laboratory science from canonical storage through real movement phase handoff")
print("PASS hidden proxy exclusion, visible turret admission and exact legacy ammunition refund")

pair.independent_emergency_operation_0184={enabled=true}
force.current_research={valid=true,name="automation",
 research_unit_ingredients={{name="automation-science-pack",amount=1}}}
stock=0
local waiting={family="lab-science",phase="waiting-source",target=lab,
 item="automation-science-pack",count=5,request_tick=game.tick}
pair.item_family_logistics_0702=waiting
assert(Items.recommend_action(pair)==nil and pair.item_family_logistics_0702==waiting,
 "source-less laboratory intent monopolized factory production or lost its identity")
stock=5
pair.machine_logistics_custody_0528={item="iron-plate",count=2}
assert(Items.recommend_action(pair)==nil,
 "new science stock interrupted another physical carrier's delivery")
pair.machine_logistics_custody_0528=nil
assert(Items.recommend_action(pair).active and pair.item_family_logistics_0702==waiting,
 "same laboratory request did not resume after real science stock became available")
stock=0
pair.independent_emergency_operation_0184.enabled=false
assert(Items.recommend_action(pair).active,"player assistance behavior changed")
print("PASS independent source-less laboratory request yields and resumes without discarding custody")
pair.item_family_logistics_0702=nil;pair.item_family_candidate_0702=nil
pair.independent_emergency_operation_0184.enabled=true
pair.priest.name="test-priest";pair.priest.position={x=0,y=0};stock=5
surface.find_entities_filtered=function(spec)
 for _,kind in ipairs(spec.type or{})do if kind=="lab"then return{lab}end end
 return{}
end
surface.can_place_entity=function(spec)
 local p=spec.position
 return p.x>8 and p.y==0 -- Closest face is blocked by other real machinery.
end
delivered=0;game.tick=game.tick+1000
services.item_family_discovery_0702.fn(nil,1)
Items.service_pair(pair)
local source_contact=pair.movement_request_0418
assert(source_contact and source_contact.x>8 and source_contact.radius==.25
 and stock==5,"science pickup did not choose a real clear side of its blocked source")
game.tick=game.tick+5;pair.priest.position={x=0,y=1}
Items.service_pair(pair)
assert(pair.movement_request_0418.x==source_contact.x and pair.movement_request_0418.y==source_contact.y,
 "moving priest changed its science source contact before reaching it")
pair.priest.position={x=source_contact.x,y=source_contact.y};game.tick=game.tick+5
Items.service_pair(pair)
assert(stock==0 and pair.item_family_custody_0702.count==5,
 "collision-clear source arrival did not pick up exact science stock")
local lab_contact=pair.movement_request_0418
assert(lab_contact and lab_contact.x>11.5 and lab_contact.radius==.25,
 "science delivery retained the source route or aimed into a blocked laboratory")
pair.priest.position={x=lab_contact.x,y=lab_contact.y};game.tick=game.tick+5
Items.service_pair(pair)
assert(delivered==5 and not pair.item_family_custody_0702 and not pair.movement_request_0418,
 "walkable laboratory contact failed actual science delivery and terminal route release")
print("PASS obstructed science sources and labs use stable walkable contacts within original physical reach")
