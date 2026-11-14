package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={}};game={tick=100};defines={inventory={chest=1,turret_ammo=2}}
prototypes={item={["cannon-shell"]={type="ammo"},["firearm-magazine"]={type="ammo"},["mod-bullet"]={type="ammo"}}}
local stock={["cannon-shell"]=20,["mod-bullet"]=5}
local removed,loaded=0,0
local source={valid=true,get_item_count=function(item)return stock[item]or 0 end,
 remove=function(s)assert(s.name~="cannon-shell","incompatible shell withdrawn");local n=math.min(stock[s.name]or 0,s.count);stock[s.name]=stock[s.name]-n;removed=removed+n;return n end}
local ammo={valid=true,get_item_count=function()return loaded end,
 can_insert=function(s)return s.name=="mod-bullet"end,
 insert=function(s)assert(s.name=="mod-bullet");loaded=loaded+s.count;return s.count end}
local force,surface={},{}
local pair={station={valid=true,unit_number=1,force=force,surface=surface,get_inventory=function()return source end},
 proxy={valid=true,get_inventory=function()return ammo end}}
local M=require("scripts.core.proxy_ammo_hardener_0649")
assert(not M.station_has_ammo(pair),"cannon shells were advertised as proxy firearm ammunition")
assert(M.load_proxy_from_station(pair,"test"))
assert(removed==5 and loaded==5 and stock["cannon-shell"]==20,"native-compatible ammo was not transferred exactly")
print("PASS incompatible cannon shells preserved and native-compatible mod ammunition loaded exactly")
