package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};storage={tech_priests={pairs_by_station={}}};defines={inventory={chest=1}}
prototypes={item={["iron-ore"]={}},entity={["wooden-chest"]={}}}
local function inventory(cap)
 local n=0;local i={valid=true,object_name="LuaInventory"}
 i.get_item_count=function()return n end
 -- The real API answers ANY portion, even if the requested stack is larger.
 i.can_insert=function(s)return cap-n>0 end
 i.get_insertable_count=function()return cap-n end
 i.insert=function(s)local x=math.min(s.count,(i.limit or cap)-n);n=n+x;return x end
 i.remove=function(s)local x=math.min(s.count,n);n=n-x;return x end
 return i
end
local force={index=1,name="player"};local surface={index=1}
local station_inv=inventory(0);local first=inventory(10);local second=inventory(100)
local function entity(id,x,inv)return{valid=true,name="wooden-chest",type="container",unit_number=id,
 force=force,surface=surface,position={x=x,y=0},get_inventory=function(k)if k==1 then return inv end end}end
local station=entity(1,0,station_inv);local a=entity(3,2,first);local b=entity(4,4,second)
surface.find_entities_filtered=function()return{a,b}end
local pair={station=station,priest={valid=true,unit_number=2,force=force,surface=surface,position={x=1,y=0}},radius=28}
storage.tech_priests.pairs_by_station[1]=pair
local Authority=require("scripts.core.storage_role_authority_0686")
assert(first.can_insert{name="iron-ore",count=50}and first.get_insertable_count("iron-ore")==10)
local accepted,why,n=Authority.deposit_exact(pair,"iron-ore",50,"machine-output-deposit-0528",{role="retention"})
assert(accepted and n==50 and first.get_item_count("iron-ore")==10 and second.get_item_count("iron-ore")==40,
 "native partial capacity caused an infinite atomic rollback instead of a split exact deposit: "..tostring(why))
-- Capacity observations can race. Keep the existing rollback, with no credit.
second.get_insertable_count=function()return 100 end
second.limit=45
local refused,reason,credited=Authority.deposit_exact(pair,"iron-ore",50,"native-capacity-race",{role="retention"})
assert(not refused and reason=="atomic-insert-failed"and credited==0
 and first.get_item_count("iron-ore")==10 and second.get_item_count("iron-ore")==40)
station_inv.get_insertable_count=nil;station_inv.can_insert=function()return true end
local blocked=Authority.deposit_exact(pair,"iron-ore",1,"native-capacity-unobservable",{station_only=true})
assert(not blocked,"unobservable native capacity received fabricated insertable space")
print("PASS native partial-stack capacity, split exact deposit, race rollback and fail-closed native reads")
