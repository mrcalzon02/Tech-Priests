package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local M=require("scripts.core.native_fluid_tree_clearance_1298")
local a,b,c={id=1},{id=2},{id=3}
local route,trees=M.search({x=0,y=0},{x=4,y=0},function(q)
 if q.x<0 or q.x>4 or(q.y~=0 and q.y~=1)then return false end
 local tree=q.y==0 and q.x==2 and a or q.y==1 and q.x==1 and b or q.y==1 and q.x==3 and c
 return true,"conditional",tree
end)
assert(route and #route==5 and #trees==1 and trees[1].tree==a,"clearance search failed to prefer the least tree cost")
assert(not M.search({x=0,y=0},{x=4,y=0},function(q)
 if q.x<0 or q.x>4 or(q.y~=0 and q.y~=1)then return false end
 return true,"clear",q.y==1 and a or nil
end),"a clear route authorized unnecessary tree mining")
assert(not M.search({x=0,y=0},{x=4,y=0},function(q)return q.y==0 and q.x>=0 and q.x<=4 and q.x~=2 end),
 "a solid unmineable barrier became a conditional route")
assert(not M.search({x=0,y=0},{x=10,y=0},function(q)
 if q.y~=0 or q.x<0 or q.x>10 then return false end
 return true,"tree",q.x>0 and q.x<10 and a or nil
end),"conditional route exceeded its finite clearance budget")
game={tick=1000};storage={tech_priests={pairs_by_station={}}}
prototypes={entity={pipe={collision_mask={layers={object=true}}}}}
local force={index=1};local neutral={name="neutral"};local surface={index=2}
local tree={valid=true,name="tree-01",type="tree",force=neutral,surface=surface,position={x=2,y=0},
 prototype={mineable_properties={products={{name="wood",amount=4}}}}}
tree.destroy=function()error("discovery destroyed a tree")end
local entity_meta={__eq=function(x,y)return x._identity==y._identity end}
tree._identity=123;tree.object_name="LuaEntity";setmetatable(tree,entity_meta)
local function wrapper()
 local e={};for k,v in pairs(tree)do e[k]=v end;return setmetatable(e,entity_meta)
end
local proxy=wrapper();assert(proxy==tree and not rawequal(proxy,tree)and not({[tree]=true})[proxy])
local wrapped_route,wrapped_trees=M.search({x=0,y=0},{x=4,y=0},function(q)
 if q.y~=0 or q.x<0 or q.x>4 then return false end
 return true,"tree",(q.x==2 or q.x==3)and wrapper()or nil
end)
assert(wrapped_route and #wrapped_trees==1,"equal native tree wrappers were counted as distinct trees")
local obstacle
surface.can_place_entity=function(spec)return not(spec.position.x==2 and spec.position.y==0)end
surface.get_tile=function()return{prototype={collision_mask={layers={}}}}end
surface.find_entities_filtered=function(spec)
 local pos=spec.area and spec.area[1];local near=not pos or(math.abs(pos[1]+.3-tree.position.x)<.01 and math.abs(pos[2]+.3-tree.position.y)<.01)
 if near then return obstacle and{wrapper(),obstacle}or{wrapper()}end
 return{}
end
local stock=10
TechPriestsStorageRoleAuthority0686={generic_item_count=function(_,item)assert(item=="pipe");return stock end}
local station={valid=true,name="planetary-magos-cogitator-station",unit_number=3,force=force,surface=surface,position={x=0,y=0}}
local boiler={valid=true,name="boiler",type="boiler",force=force,surface=surface,direction=4}
local pump={valid=true,name="offshore-pump",type="offshore-pump",force=force,surface=surface,direction=8}
local parent={output_item="lab",strict_recipe_0647=true,facility_only_0647=true,infrastructure_first_0640=true}
local p={station=station,priest={valid=true,name="planetary-magos-tech-priest",force=force,surface=surface},
 independent_emergency_operation_0184={enabled=true},emergency_craft=parent,radius=40}
storage.tech_priests.pairs_by_station[3]=p
local proposal={direction="input",fluid="water",machine=boiler,source={entity=pump}}
assert(M.tree_at(p,{x=2,y=0})==tree)
local preview={clearance_scan_1298=true,direction="input",fluid="water",machine=boiler,remote={entity=pump}}
local r=M.propose(p,proposal,preview,{{x=0,y=0},{x=1,y=0},{x=2,y=0},{x=3,y=0}},{{tree=tree,position={x=2,y=0}}},4)
assert(r and r.parent_recipe==parent and r.pipe_count==4 and M.valid_request(p,r))
TechPriestsFluidNetworkDoctrine0689={validate_proposal=function(q,v)assert(q==p and v==proposal);return true end}
TechPriestsFluidConnectionPlanner0691=require("scripts.core.fluid_connection_planner_0691")
assert(TechPriestsFluidConnectionPlanner0691.clearance_request_valid_1298(p,r,true),
 "equal but nonidentical native entity wrappers broke full route revalidation")
TECH_PRIESTS_ORDER_QUEUE_0469={submit=function(q,o)o.status="active";q.order_queue_0469={current=o};return true end}
local Builder=require("scripts.core.construction_planner")
assert(Builder.recommend_action(p).fluid_route_clearance_1298)
assert(Builder.service_pair(p).detail=="native-water-route-tree-clearance-requested")
local child=p.direct_acquisition_task_0336
assert(child.current.entity==tree and child.output_item=="wood"and p.emergency_craft==parent and tree.valid and stock==10)
assert(Builder.source_clearance_active_1285(p),"canonical direct executor cannot admit its exact tree prerequisite")
game.tick=4000
assert(Builder.source_clearance_active_1285(p),"an admitted physical child lost ownership merely because discovery expired")
tree.valid=false;p.direct_acquisition_custody_0513={item="wood",count=4,native_inventory={valid=true}}
assert(Builder.source_clearance_active_1285(p),"actual wood custody lost its original return owner")
p.direct_acquisition_custody_0513.item="stone";assert(not Builder.source_clearance_active_1285(p))
p.direct_acquisition_custody_0513=nil;p.direct_acquisition_task_0336=nil;p.order_queue_0469=nil;p.construction_source_clearance_1285=nil
tree.valid=true;game.tick=1000
obstacle={valid=true,type="container"};assert(not M.tree_at(p,{x=2,y=0}),"protected structure disappeared in a tree counterfactual")
obstacle=nil;tree.prototype.mineable_properties.products[2]={name="stone",amount=1}
assert(not M.tree_at(p,{x=2,y=0}),"unrepresented mining output was authorized")
tree.prototype.mineable_properties.products[2]=nil
stock=0;assert(not M.admitted(p,proposal),"unfunded route authorized clearance")
stock=10;p.independent_emergency_operation_0184.enabled=false
assert(not M.admitted(p,proposal),"maintenance priest accepted autonomous terrain work")
p.independent_emergency_operation_0184.enabled=true;p.active_order_0469={status="active",kind="movement",source="player"}
assert(not M.admitted(p,proposal),"player order lost ownership")
p.active_order_0469=nil;surface.platform={valid=true};assert(not M.admitted(p,proposal))
print("PASS bounded least-clearance water route, original constructor/direct handoff, retained lab, real wood-return identity and foreign/custody/terrain guards")
