-- 1096: consecutive real 0516 repair-pack debits on one defensive wall.
-- This drives the PRODUCTION repair executor with simulated Factorio objects,
-- not a substitute healing implementation or a scripted combat success.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Repair=require("scripts.core.repair_executor_0516")
game={tick=100}
defines={inventory={chest=1},distraction={none=0}}
local stocked=3
local inventory={valid=true}
function inventory.get_item_count(item)
  return item=="repair-pack" and stocked or 0
end
function inventory.remove(stack)
  assert(stack.name=="repair-pack" and stack.count==1)
  local removed=math.min(stocked,stack.count)
  stocked=stocked-removed
  return removed
end
function inventory.insert(stack)
  assert(stack.name=="repair-pack" and stack.count>0)
  stocked=stocked+stack.count
  return stack.count
end
local surface={valid=true,index=1}
local force={name="player",index=1}
local other={name="enemy",index=2}
local station={valid=true,name="planetary-magos-cogitator-station",
  unit_number=11,position={x=0,y=0},surface=surface,force=force,
  get_inventory=function(id)
    if id==defines.inventory.chest then return inventory end
  end}
local priest={valid=true,name="tech-priest",unit_number=12,
  position={x=1,y=0},surface=surface,force=force}
local wall={valid=true,name="stone-wall",type="wall",
  unit_number=51,health=100,max_health=270,
  position={x=2,y=0},surface=surface,force=force}
local pair={station=station,priest=priest,radius=28}
storage={tech_priests={pairs_by_station={[station.unit_number]=pair}}}
local claimed,released=0,0
_G.TechPriestsWorkReservations0601={
  claim=function(kind,target,owner)
    assert(kind=="repair" and target==wall and owner==pair)
    claimed=claimed+1
    return true
  end,
  release=function(kind,target,owner)
    assert(kind=="repair" and target==wall and owner==pair)
    released=released+1
    return true
  end,
  is_claimed=function()return false end}
local first=Repair.service_pair(pair,"first-hostile-wave",wall)
assert(first.waiting==1 and wall.health==100 and stocked==3,
  "repair progress silently healed or debited prior to physical repair work")
game.tick=game.tick+Repair.pack_interval_ticks
local a=Repair.service_pair(pair,"first-pack",wall)
assert(a.acted==1 and wall.health==175 and stocked==2
  and pair.repair_0516.packs_used==1
  and pair.repair_pack_custody_0516==nil,
  "first wall repair did not debit exactly one physical repair pack")
game.tick=game.tick+Repair.pack_interval_ticks
local b=Repair.service_pair(pair,"second-pack",wall)
assert(b.acted==1 and wall.health==250 and stocked==1
  and pair.repair_0516.packs_used==2,
  "continuous wall repair stopped after the first physical pack")
game.tick=game.tick+Repair.pack_interval_ticks
local c=Repair.service_pair(pair,"third-pack",wall)
assert(c.acted==1 and wall.health==wall.max_health and stocked==0
  and pair.repair_0516.phase=="complete"
  and pair.repair_pack_custody_0516==nil
  and Repair.root().stats["packs-applied"]==3,
  "third physical pack did not complete actual wall restoration")
-- Renewed actual biter damage must not be repaired with a virtual pack.
game.tick=game.tick+Repair.target_cooldown_ticks+5
wall.health=190
local empty=Repair.service_pair(pair,"second-hostile-wave",wall)
assert(empty.blocked==1 and wall.health==190 and stocked==0
  and pair.repair_0516.phase=="need-item",
  "zero repair packs manufactured health under renewed attack")
-- Once new stock is physically present, repair resumes the SAME wall.
stocked=2
game.tick=game.tick+1
local resumed=Repair.service_pair(pair,"restocked",wall)
assert(resumed.waiting==1 and stocked==2 and wall.health==190,
  "restock prematurely consumed a pack before the physical repair delay")
game.tick=game.tick+Repair.pack_interval_ticks
local fourth=Repair.service_pair(pair,"fourth-pack",wall)
assert(fourth.acted==1 and wall.health==265 and stocked==1,
  "restocked physical pack did not restore damaged original wall")
game.tick=game.tick+Repair.pack_interval_ticks
local fifth=Repair.service_pair(pair,"fifth-pack",wall)
assert(fifth.acted==1 and wall.health==270 and stocked==0
  and pair.repair_0516.phase=="complete"
  and Repair.root().stats["packs-applied"]==5,
  "repeat-assault repair failed to consume the second batch correctly")
local enemy_wall={valid=true,name="stone-wall",type="wall",
  unit_number=72,health=10,max_health=200,
  position={x=2,y=0},surface=surface,force=other}
stocked=1
game.tick=game.tick+1
local denied=Repair.service_pair(pair,"hostile-wall",enemy_wall)
assert(denied.acted==0 and wall.health==270 and
    enemy_wall.health==10 and stocked==1,
  "repair packs were consumed for an enemy structure")
-- Simulate save/reload interruption exactly AFTER an existing physical pack
-- was removed but BEFORE its health write. Abort must restore custody.
stocked=stocked-1
pair.repair_pack_custody_0516={
  phase="pack-held",item="repair-pack",count=1,
  target=wall,target_unit=wall.unit_number,
  before_health=180,expected_health=255}
_G.tech_priests_safe_deposit_item=function(owner,item,amount)
  assert(owner==pair and item=="repair-pack" and amount==1)
  stocked=stocked+amount
  return true,"restored",amount
end
local abandoned=Repair.abort_pair(pair,"interrupted-before-health-write")
assert(abandoned.acted==1 and stocked==1
  and wall.health==270 and pair.repair_pack_custody_0516==nil
  and (Repair.root().stats["packs-refunded"]or 0)==1,
  "interrupted repair pack was lost, duplicated, or applied without proof")
assert(claimed>=7 and released>=2,
  "native-style reservation custody was never acquired and released")
print("[combat-physical-repair-endurance-1096] PASS same wall five physical packs, two assaults, no phantom healing, enemy wall refusal, interruption refund")
