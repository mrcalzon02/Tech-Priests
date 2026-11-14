package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={pairs_by_station={}}};game={tick=1000}
prototypes={item={stone={},coal={}}}
local bag
game.create_inventory=function(size)
 assert(size==64);local items={};bag={valid=true}
 bag.get_item_count=function(name)return items[name]or 0 end
 bag.get_contents=function()local r={};for n,c in pairs(items)do if c>0 then r[#r+1]={name=n,count=c,quality="normal"}end end;return r end
 bag.insert=function(s)items[s.name]=(items[s.name]or 0)+s.count;return s.count end
 bag.remove=function(s)local n=math.min(items[s.name]or 0,s.count);items[s.name]=(items[s.name]or 0)-n;return n end
 bag.is_empty=function()for _,n in pairs(items)do if n>0 then return false end end;return true end
 bag.destroy=function()assert(bag.is_empty(),"nonempty native custody destroyed");bag.valid=false end
 return bag
end
local force,surface={index=1},{index=1}
local rock={valid=true,name="big-rock",type="simple-entity",position={x=1,y=0},surface=surface,force={index=2},
 prototype={mineable_properties={products={{name="stone",type="item",amount_min=5,amount_max=20},{name="coal",type="item",amount=7}}}}}
local mined=0
rock.mine=function(spec)
 assert(spec.inventory==bag and spec.force==false and spec.raise_destroyed==true)
 mined=mined+1;bag.insert{name="stone",count=13};bag.insert{name="coal",count=7};rock.valid=false;return true
end
local pair={station={valid=true,name="senior-cogitator-station",unit_number=1,position={x=0,y=0},force=force,surface=surface},
 priest={valid=true,unit_number=2,position={x=1,y=0},force=force,surface=surface},radius=32,
 emergency_craft={output_item="stone",required_count=1,current={kind="direct-mine-0336",entity=rock,output_item="stone"}}}
tech_priests_stop_movement_0418=function()return true end
local blocked=true;local deposited={}
tech_priests_safe_deposit_item=function(_,name,n)
 if blocked then return false,"full",0 end
 deposited[name]=(deposited[name]or 0)+n;return true,"deposited",n
end
local Direct=require("scripts.core.direct_acquisition_executor_0513")
assert(Direct.service_pair(pair))
game.tick=1091
Direct.service_pair(pair)
assert(mined==1 and not rock.valid and bag.valid and bag.get_item_count("stone")==13,
 "real native rock yield was lost after refused storage")
assert(pair.direct_acquisition_custody_0513.native_inventory==bag and pair.direct_acquisition_custody_0513.count==13)
package.loaded["scripts.core.direct_acquisition_executor_0513"]=nil
Direct=require("scripts.core.direct_acquisition_executor_0513")
local Guard=require("scripts.core.direct_acquisition_physical_guard_0649")
local parent=pair.emergency_craft
local _,guard_reason=Guard.service_pair(pair,"rock-already-consumed")
assert(guard_reason=="physical-custody-owned"and pair.emergency_craft==parent,
 "physical target guard retired the parent while actual mined cargo was held")
blocked=false;game.tick=1100;Direct.service_pair(pair)
assert(deposited.stone==13 and deposited.coal==7 and not bag.valid and not pair.direct_acquisition_custody_0513,
 "multi-item native mining custody did not survive reload and exact return")
assert(mined==1,"native rock was mined twice")
print("PASS real random rock yield, secondary coal, refused deposit, reload and exact physical custody")
