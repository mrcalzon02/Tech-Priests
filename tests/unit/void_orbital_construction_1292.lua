package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};storage={tech_priests={pairs_by_station={}}};defines={inventory={hub_main=1},distraction={none=0}}
local function inventory(items)
 local inv={valid=true}
 inv.get_item_count=function(n)return items[n]or 0 end
 inv.remove=function(s)local n=math.min(items[s.name]or 0,s.count);items[s.name]=(items[s.name]or 0)-n;return n end
 inv.insert=function(s)items[s.name]=(items[s.name]or 0)+s.count;return s.count end
 inv.is_empty=function()for _,n in pairs(items)do if n>0 then return false end end;return true end
 inv.destroy=function()assert(inv.is_empty());inv.valid=false end
 return inv
end
game.create_inventory=function(n)assert(n==1);return inventory({})end
local force={index=1};local surface={index=2};local items={["space-platform-foundation"]=10,["solar-panel"]=0}
local inv=inventory(items);local tiles={};local panels={};local paid_tiles=0
local pair
local function key(p)return p.x..":"..p.y end
for x=-5,4 do for y=-5,4 do tiles[key{x=x,y=y}]=true end end
surface.get_tile=function(p)return{name=tiles[key(p)]and"space-platform-foundation"or"empty-space"}end
surface.find_entities_filtered=function(spec)
 if spec.name=="void-cogitator-station"then return pair and{pair.station}or{}end
 if spec.name=="solar-panel"then local e=panels[key(spec.position)];return e and{e}or{}end
 return{}
end
surface.can_place_entity=function()return true end
local hub={valid=true,name="space-platform-hub",unit_number=3,force=force,surface=surface,position={x=0,y=0},
 bounding_box={left_top={x=-3.9,y=-3.9},right_bottom={x=3.9,y=3.9}},get_inventory=function(id)assert(id==1);return inv end}
local platform={valid=true,index=4,force=force,surface=surface,hub=hub};surface.platform=platform
pair={station={valid=true,name="void-cogitator-station",unit_number=5,force=force,surface=surface,position={x=6,y=0}},
 priest={valid=true,name="void-tech-priest",unit_number=6,force=force,surface=surface,position={x=6,y=0}},radius=40,
 independent_emergency_operation_0184={enabled=true}}
storage.tech_priests.pairs_by_station[5]=pair
surface.set_tiles=function(list,correct,remove)
 assert(correct==false and remove==false and #list==1)
 local tile=list[1];assert(tile.name=="space-platform-foundation"and not tiles[key(tile.position)])
 assert(items["space-platform-foundation"]==9-paid_tiles,"foundation appeared before actual hub debit")
 paid_tiles=paid_tiles+1;tiles[key(tile.position)]=true
end
surface.create_entity=function(spec)
 assert(spec.name=="solar-panel"and spec.force==force and items["solar-panel"]==0,
  "structure appeared before real item pickup")
 local e={valid=true,name=spec.name,position=spec.position,force=force,surface=surface,unit_number=7}
 panels[key(spec.position)]=e;return e
end
local move
tech_priests_request_movement_0418=function(p,pos,reason,opts)
 assert(p==pair and opts.owner=="construction-planner-0338");move=pos;return true
end
local Builder=require("scripts.core.construction_planner");TechPriestsConstructionPlanner0338=Builder
local Void=require("scripts.core.void_orbital_construction_1292")
-- The shared constructor must reject terrestrial and unbound actors even
-- when a generic robot-network request bypasses the local bootstrap planner.
pair.robot_network_request_0338={position={x=0,y=0}}
pair.priest.name="senior-tech-priest"
assert(not Builder.recommend_action(pair),"terrestrial priest received generic orbital construction")
assert(Builder.service_pair(pair).detail=="orbital-void-manager-required")
pair.priest.name="void-tech-priest"
local own_surface=pair.priest.surface;pair.priest.surface={index=99}
assert(not Builder.recommend_action(pair),"absent Void received generic orbital construction")
assert(Builder.service_pair(pair).detail=="orbital-void-manager-required")
pair.priest.surface=own_surface
pair.priest.force={index=99};assert(not Builder.recommend_action(pair),"foreign Void received orbital construction")
pair.priest.force=force
-- An existing task is dispatched only for termination and physical restitution.
pair.priest.name="senior-tech-priest";pair.construction_task_0338={phase="waiting-source",item_name="solar-panel"}
assert(Builder.recommend_action(pair).reason=="orbital-void-manager-required")
assert(Builder.service_pair(pair).detail=="orbital-void-manager-required")
assert(not pair.construction_task_0338 and not pair.construction_custody_0338)
pair.priest.name="void-tech-priest";pair.robot_network_request_0338=nil
assert(Void.offer(pair)and not pair.construction_task_0338 and paid_tiles==0 and items["space-platform-foundation"]==10)
assert(not Void.material_request(platform),"remote inspection invented a local Void plan")
pair.station.name="senior-cogitator-station";assert(not Void.offer(pair));pair.station.name="void-cogitator-station"
pair.priest.name="senior-tech-priest";assert(not Void.offer(pair));pair.priest.name="void-tech-priest"
pair.independent_emergency_operation_0184.enabled=false;assert(not Void.offer(pair));pair.independent_emergency_operation_0184.enabled=true
pair.active_order_0469={kind="movement",status="active",source="player"};assert(not Void.offer(pair));pair.active_order_0469=nil
local action=Builder.recommend_action(pair);assert(action.void_orbital_1292 and not action.active)
assert(Builder.service_pair(pair).detail=="void-moving-to-real-hub-stock"and items["space-platform-foundation"]==10)
pair.priest.position=move
assert(Builder.service_pair(pair).detail=="void-real-build-item-picked-up"and items["space-platform-foundation"]==9 and paid_tiles==0)
local bag=pair.construction_custody_0338.native_inventory;assert(bag.get_item_count("space-platform-foundation")==1)
-- Reload/orphan recovery returns the same native item, never virtual stock.
pair.construction_task_0338=nil
assert(Builder.service_pair(pair).detail=="void-build-actual-item-returned"and not bag.valid
 and items["space-platform-foundation"]==10 and paid_tiles==0)
game.tick=game.tick+301
for _=1,100 do
 local rec=Builder.recommend_action(pair)
 if not rec then break end
 move=nil;Builder.service_pair(pair)
 if move then pair.priest.position=move end
 game.tick=game.tick+5
end
assert(paid_tiles==9 and items["space-platform-foundation"]==1 and items["solar-panel"]==0)
local demand=Void.material_request(platform);assert(demand.item=="solar-panel"and demand.count==1 and demand.manager_station==5)
pair.priest.name="senior-tech-priest";assert(not Void.material_request(platform));pair.priest.name="void-tech-priest"
pair.active_order_0469={kind="movement",status="active",source="player"};assert(not Void.material_request(platform));pair.active_order_0469=nil
items["solar-panel"]=1
for _=1,30 do
 if not Builder.recommend_action(pair)then break end
 move=nil;Builder.service_pair(pair);if move then pair.priest.position=move end;game.tick=game.tick+5
end
assert(paid_tiles==9 and items["space-platform-foundation"]==1 and items["solar-panel"]==0
 and not pair.construction_task_0338 and not pair.construction_custody_0338 and not Void.next_need(pair))
local found=0;for _ in pairs(panels)do found=found+1 end;assert(found==1)
assert(pair.void_orbital_construction_last_1292.result=="void-paid-solar-built")
print("PASS local Void physical hub pickup, native custody restitution and nine paid tiles plus one paid solar panel")
