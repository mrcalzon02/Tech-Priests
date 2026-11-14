package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};storage={tech_priests={pairs_by_station={}}}
defines={inventory={chest=1}};prototypes={item={["senior-cogitator-station"]={place_result={}}}}
local force={index=1,recipes={}};local surface={index=1}
local empty={valid=true,get_item_count=function()return 0 end}
local pair={station={valid=true,unit_number=1,position={x=0,y=0},force=force,surface=surface,get_inventory=function()return empty end},
 priest={valid=true,unit_number=2,position={x=4,y=0},force=force,surface=surface}}
local rec={id=7,station_item="senior-cogitator-station",status="active",worker_station_unit=1,requester_station_unit=1}
pair.station_expansion_0256=rec
local calls=0
local Exp={allowed_station_item_for_pair=function()return rec.station_item end,
 request_station_expansion=function()return true end,
 service_station_expansion_assignment=function(p)assert(p==pair);calls=calls+1;return true end}
package.loaded["scripts.magos_station_expansion"]=Exp
local hold={valid=true,get_item_count=function()return 1 end}
storage.tech_priests.station_cargo_0824={[7]={record_id=7,station_unit=1,priest_unit=2,item=rec.station_item,
 inventory=hold,force=force,surface=surface,status="carrying"}}
local Contract=require("scripts.core.logistics_construction_contract_0519");Contract.install()
assert(Exp.service_station_expansion_assignment(pair)and calls==1,
 "last physical station kit was blocked because source storage was now empty")
storage.tech_priests.station_cargo_0824[7]=nil
Exp.service_station_expansion_assignment(pair)
assert(calls==1 and rec.phase=="deferred-missing-station-item",
 "unfunded station expansion bypassed its existing availability contract")
print("PASS existing real station cargo reaches original owner; unfunded new kit remains deferred")
