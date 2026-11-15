package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=100};storage={tech_priests={pairs_by_station={}}}
local surface={index=1,name="nauvis"};local force={index=1,name="player"}
local pair={station={valid=true,unit_number=1,position={x=0,y=0},surface=surface,force=force},
 priest={valid=true,unit_number=2},mode="crafting",
 emergency_craft={output_item="iron-plate",facility_only_0647=true},
 dispatcher_0510={tick=100,family="station-craft"}}
storage.tech_priests.pairs_by_station[1]=pair
TechPriestsRuntimeEventRegistry={on_nth_tick=function()end}
local Queue=require("scripts.core.order_queue_0469")
local Contract=require("scripts.core.scheduler_contract_0512")
assert(Contract.install())
local function order(key,expires,target)
 local o={key=key,kind="logistics",item="repair-pack",count=1,priority=600,
   source="player",created_tick=100,expires_tick=expires,target=target}
 assert(Queue.submit(pair,o));return o
end
local production=pair.emergency_craft
local expired=order("expired",99)
Queue.tick_pair(pair,"expired-native-repair-pack")
assert(expired.status=="failed"and expired.finish_reason=="expired"
 and not pair.order_queue_0469.current and not pair.active_order_0469
 and pair.emergency_craft==production,
 "expired request resurrected against unrelated active production")
local invalid=order("invalid",1000,{valid=false})
Queue.tick_pair(pair,"invalid-target")
assert(invalid.status=="failed"and not pair.order_queue_0469.current,
 "invalid target failure was resurrected by the dispatcher lease")
pair.mode="idle"
local done=order("surface-cleared",1000)
Queue.tick_pair(pair,"surface-cleared")
assert(done.status=="complete"and not pair.order_queue_0469.current,
 "real queue completion was undone by an unrelated production intent")
pair.mode="crafting"
local living=order("living",1000)
Queue.tick_pair(pair,"still-active")
assert(pair.order_queue_0469.current==living and living.status=="active",
 "unexpired explicit order lost its actual queue ownership")
local original=Queue.TECH_PRIESTS_0512_PRE_TICK_PAIR
Queue.TECH_PRIESTS_0512_PRE_TICK_PAIR=function(p)
 p.order_queue_0469.current=nil;p.active_order_0469=nil;return true end
Queue.tick_pair(pair,"nonterminal-compatibility-clear")
Queue.TECH_PRIESTS_0512_PRE_TICK_PAIR=original
assert(pair.order_queue_0469.current==living and living.status=="active",
 "nonterminal accidental clear lost its valid active-work lease")
print("PASS terminal queue decisions stay terminal; live explicit and nonterminal leases remain owned")
