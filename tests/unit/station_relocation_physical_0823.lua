-- Source-module regression for real item recovery, idempotent lease custody,
-- priest identity preservation and reattachment after a save/reload boundary.
package.path = "tech-priests_src/?.lua;tech-priests_src/?/init.lua;" .. package.path
defines = { events = { script_raised_destroy=11, on_entity_died=12 } }
game = { tick = 900 }
local force = {name="player"}
local surface = {index=1}
local function inv()
  local i = {valid=true, count=0, room=1}
  i.get_item_count=function(item) assert(item=="junior-cogitator-station");return i.count end
  i.get_insertable_count=function(item) assert(item=="junior-cogitator-station");return i.room end
  return i
end
local function pair(id, rank, name)
  local station = {
    valid=true, unit_number=id, name=name, force=force, surface=surface,
    position={x=id*5,y=0}, minable=true,
    prototype={mineable_properties={products={{name=name,amount=1,type="item"}}}}
  }
  local priest = {valid=true,unit_number=id+100,
    get_main_inventory=function() return {valid=true,get_contents=function() return {} end} end}
  return {station=station,priest=priest,rank=rank,mode="idle",
    inventory={valid=true,get_contents=function() return {} end},
    command_hierarchy_0480={superior_unit=nil,direct_subordinate_units={},peer_units={}}}
end
local parent = pair(1,2,"intermediate-cogitator-station")
local child = pair(2,1,"junior-cogitator-station")
child.command_hierarchy_0480.superior_unit=1
storage={tech_priests={
  pairs_by_station={[1]=parent,[2]=child},
  pairs_by_priest={[101]=parent,[102]=child},
  station_by_priest={[101]=1,[102]=2},
  station_expansion_0256={}
}}
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  rank=function(p)return p.rank end,
  is_direct_subordinate=function(p,c)return c.command_hierarchy_0480.superior_unit==p.station.unit_number end,
  peers=function()return {} end,
  rebuild=function()return true end
}
_G.tech_priests_0358_station_sources_for_pair=function(p)
  return {{owner=p.station,inv=p.inventory}}
end
local M=require("scripts.core.station_relocation_0823")
local ghost={valid=true,ghost_name="junior-cogitator-station",force=force,
  surface=surface,position={x=40,y=0}}
local rec={id=7,station_item="junior-cogitator-station",ghost_position={x=40,y=0}}
local receiver=inv()
local mined_calls=0
child.station.mine=function(args)
  mined_calls=mined_calls+1
  assert(args.inventory==receiver and args.force==true)
  assert(M.intercept_removed(child.station,{name=defines.events.script_raised_destroy}),
    "physical station mining must bypass destructive legacy pair cleanup")
  assert(not M.intercept_removed(child.station,{name=defines.events.on_entity_died}),
    "actual station death is never a relocation")
  child.station.valid=false
  receiver.count=receiver.count+1
  return true
end
receiver.room=0
local ok,why=M.try_recover(parent,child,rec,ghost,receiver)
assert(not ok and why=="receiver-full" and mined_calls==0)
receiver.room=1
child.combat_target={valid=true}
ok,why=M.try_recover(parent,child,rec,ghost,receiver)
assert(not ok and why=="active-pair-duty:combat_target" and mined_calls==0)
child.combat_target=nil
ghost.ghost_name="senior-cogitator-station"
ok,why=M.try_recover(parent,child,rec,ghost,receiver)
assert(not ok and why=="invalid-physical-ghost" and mined_calls==0)
ghost.ghost_name="junior-cogitator-station"
ok,why=M.try_recover(parent,child,rec,ghost,receiver)
assert(ok and why=="physical-station-mined" and mined_calls==1)
assert(receiver.count==1 and child.priest.valid and child.priest.unit_number==102)
assert(storage.tech_priests.pairs_by_station[2]==nil)
assert(storage.tech_priests.pairs_by_priest[102]==child)
assert(storage.tech_priests.station_by_priest[102]==nil)
assert(M.protect_priest(child,child.priest),"priest must remain protected until rebound")
ok,why=M.try_recover(parent,child,rec,ghost,receiver)
assert(ok and why=="existing-relocation-mined" and mined_calls==1,
  "retries must not duplicate physical station items")
assert(M.begin_build(rec,parent))
local wrong={valid=true,unit_number=3,name="junior-cogitator-station",force=force,
  surface=surface,position={x=50,y=0}}
assert(not M.claim(wrong),"wrong site must never steal a preserved priest")
M.build_failed(rec)
assert(not M.claim({valid=true,unit_number=4,name="junior-cogitator-station",
  force=force,surface=surface,position={x=40,y=0}}),
  "failed physical build cannot claim the priest")
-- Reload the module without resetting Factorio persistent storage.
package.loaded["scripts.core.station_relocation_0823"]=nil
M=require("scripts.core.station_relocation_0823")
assert(M.pending_for_record(rec) and M.protect_priest(child,child.priest))
assert(M.begin_build(rec,parent))
local rebuilt={valid=true,unit_number=5,name="junior-cogitator-station",
  force=force,surface=surface,position={x=40,y=0}}
assert(M.claim(rebuilt))
assert(storage.tech_priests.pairs_by_station[5]==child)
assert(storage.tech_priests.station_by_priest[102]==5)
assert(storage.tech_priests.pairs_by_priest[102]==child)
assert(child.priest.unit_number==102 and child.station==rebuilt)
assert(not child.relocation_pending_0823 and not M.pending_for_record(rec))
assert(not M.protect_priest(child,child.priest))
assert(receiver.count==1,"no item invented or destroyed by pair reattachment")
assert(not M.claim(rebuilt),"one physical station can only consume one relocation lease")
-- A refused engine mine leaves the original station, pair and stock unchanged.
local another=pair(6,1,"junior-cogitator-station")
another.command_hierarchy_0480.superior_unit=1
storage.tech_priests.pairs_by_station[6]=another
local receiver2=inv()
another.station.mine=function()return false end
local rec2={id=8,station_item="junior-cogitator-station",ghost_position={x=40,y=0}}
ok,why=M.try_recover(parent,another,rec2,ghost,receiver2)
assert(not ok and why=="engine-mining-refused")
assert(another.station.valid and another.priest.valid)
assert(storage.tech_priests.pairs_by_station[6]==another and receiver2.count==0)
assert(not M.pending_for_record(rec2))
print("station relocation 0823: physical mine, inventory, lease, save/reload and identity PASS")
