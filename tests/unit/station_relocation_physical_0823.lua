-- Source-module regression for real item recovery, idempotent lease custody,
-- priest identity preservation and reattachment after a save/reload boundary.
package.path = "tech-priests_src/?.lua;tech-priests_src/?/init.lua;" .. package.path
defines = { events = { script_raised_destroy=11, on_entity_died=12 } }
game = { tick = 900 }
local force = {name="player"}
local surface = {index=1,
  find_logistic_network_by_position=function() return nil end}
defines.inventory={chest=1}
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
parent.priest.position={x=7,y=0}
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
local ghost={valid=true,name="entity-ghost",unit_number=700,
  ghost_name="junior-cogitator-station",force=force,
  surface=surface,position={x=40,y=0}}
local rec={id=7,station_item="junior-cogitator-station",
  ghost_unit=700,ghost_position={x=40,y=0}}
child.priest.position={x=10,y=0}
child.priest.force,child.priest.surface=force,surface
local preserved_proxy={valid=true,unit_number=800,
  name="tech-priest-small-arms-proxy",force=force,surface=surface,
  position=child.priest.position,ammunition=17}
child.proxy=preserved_proxy
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
-- Matching position and prototype must not authorize a different ghost.
local genuine_ghost_unit=ghost.unit_number
ghost.unit_number=701
ok,why=M.try_recover(parent,child,rec,ghost,receiver)
assert(not ok and why=="invalid-physical-ghost" and mined_calls==0,
  "same-position replacement ghost must not steal the relocation lease")
ghost.unit_number=genuine_ghost_unit
parent.priest.position={x=30,y=0}
ok,why=M.try_recover(parent,child,rec,ghost,receiver)
assert(not ok and why=="worker-not-in-local-physical-transfer-reach" and mined_calls==0,
  "never teleport recovered station stock from an out-of-reach location")
parent.priest.position={x=7,y=0}
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
assert(child.proxy==preserved_proxy and preserved_proxy.valid
  and preserved_proxy.ammunition==17,
  "same physical proxy and its ammunition must remain with original priest")
assert(not child.relocation_pending_0823 and not M.pending_for_record(rec))
assert(not M.protect_priest(child,child.priest))
assert(receiver.count==1,"no item invented or destroyed by pair reattachment")
assert(not M.claim(rebuilt),"one physical station can only consume one relocation lease")
-- A refused engine mine leaves the original station, pair and stock unchanged.
local another=pair(6,1,"junior-cogitator-station")
another.command_hierarchy_0480.superior_unit=1
storage.tech_priests.pairs_by_station[6]=another
local receiver2=inv()
another.station.position={x=10,y=0}
parent.priest.position={x=7,y=0}
another.station.mine=function()return false end
local rec2={id=8,station_item="junior-cogitator-station",
  ghost_unit=700,ghost_position={x=40,y=0}}
ok,why=M.try_recover(parent,another,rec2,ghost,receiver2)
assert(not ok and why=="engine-mining-refused")
assert(another.station.valid and another.priest.valid)
assert(storage.tech_priests.pairs_by_station[6]==another and receiver2.count==0)
assert(not M.pending_for_record(rec2))
-- Remote subordinate: the worker is 55 tiles from its own station.
-- It must walk to the subordinate and mine directly into the worker's
-- engine-owned cargo, NOT remotely into the parent station inventory.
local Cargo=require("scripts.core.station_cargo_0824")
local bags={}
game.create_inventory=function(size)
  assert(size==1)
  local bag={valid=true,stock=0}
  bag.get_item_count=function(name)assert(name=="junior-cogitator-station");return bag.stock end
  bag.insert=function(stack)
    local n=math.min(stack.count,1-bag.stock)
    bag.stock=bag.stock+n
    return n
  end
  bag.remove=function(stack)
    local n=math.min(stack.count,bag.stock)
    bag.stock=bag.stock-n
    return n
  end
  bag.destroy=function()assert(bag.stock==0);bag.valid=false end
  bags[#bags+1]=bag
  return bag
end
local remote=pair(9,1,"junior-cogitator-station")
remote.station.position={x=60,y=0}
remote.priest.position={x=60,y=0}
remote.priest.force,remote.priest.surface=force,surface
remote.proxy={valid=true,unit_number=809,name="tech-priest-small-arms-proxy",
  force=force,surface=surface,position=remote.priest.position,ammunition=9}
local remote_proxy=remote.proxy
local function hidden_cache(name,id,position)
  local h={valid=true,name=name,unit_number=id,force=force,surface=surface,
    position=position}
  h.get_inventory=function()
    return {valid=true,get_contents=function() return {} end}
  end
  h.destroy=function(args)
    assert(args.raise_destroy==false)
    h.valid=false
  end
  return h
end
local old_requester=hidden_cache("tech-priests-cogitator-requester-cache",810,remote.station.position)
local old_return=hidden_cache("tech-priests-cogitator-return-cache",811,remote.station.position)
remote.logistic_requester=old_requester
remote.logistic_return_cache=old_return
remote.command_hierarchy_0480.superior_unit=1
storage.tech_priests.pairs_by_station[9]=remote
storage.tech_priests.pairs_by_priest[109]=remote
storage.tech_priests.station_by_priest[109]=9
local rec3={id=9,station_item="junior-cogitator-station",
  ghost_unit=700,ghost_position={x=40,y=0}}
local remote_mines=0
remote.station.mine=function(args)
  remote_mines=remote_mines+1
  assert(args.inventory==bags[#bags] and args.force==true,
    "real mining must target the priest's carried LuaInventory")
  assert(M.intercept_removed(remote.station,{name=defines.events.script_raised_destroy}))
  remote.station.valid=false
  args.inventory.stock=args.inventory.stock+1
  error("post-mining engine callback exception")
end
parent.priest.position={x=5,y=0}
local initial_bags=#bags
-- The long-distance mining authority must reject an impostor ghost before
-- creating cargo, even when the worker has reached the real old station.
parent.priest.position={x=60,y=0}
ghost.unit_number=701
ok,why=M.try_recover_carried(parent,remote,rec3,ghost)
assert(not ok and why=="invalid-physical-ghost"
  and remote_mines==0 and #bags==initial_bags,
  "remote recovery accepted an unreserved same-position ghost")
ghost.unit_number=genuine_ghost_unit
parent.priest.position={x=5,y=0}
ok,why=M.try_recover_carried(parent,remote,rec3,ghost)
assert(not ok and why=="worker-not-at-recovery-site"
  and remote_mines==0 and #bags==initial_bags,
  "remote station may not be mined until the priest physically arrives")
parent.priest.position={x=60,y=0}
old_return.get_inventory=function()
  return {valid=true,get_contents=function() return {["iron-plate"]=1} end}
end
ok,why=M.try_recover_carried(parent,remote,rec3,ghost)
assert(not ok and why=="linked-helper-cargo:logistic_return_cache"
  and remote_mines==0 and remote.station.valid,
  "occupied helper blocks mine without destroying items")
old_return.get_inventory=function()
  return {valid=true,get_contents=function() return {} end}
end
ok,why=M.try_recover_carried(parent,remote,rec3,ghost)
assert(ok and why=="physical-station-mined-to-carrier"
  and remote_mines==1 and #bags==initial_bags+1
  and bags[#bags].stock==1 and Cargo.has_record(rec3)
  and not old_requester.valid and not old_return.valid
  and remote.logistic_requester==nil and remote.logistic_return_cache==nil,
  "post-mining item custody and empty helper retirement must both hold")
assert(storage.tech_priests.pairs_by_station[9]==nil
  and storage.tech_priests.pairs_by_priest[109]==remote
  and remote.priest.valid and M.protect_priest(remote,remote.priest),
  "the original priest must survive the physical remote mine")
ok,why=M.try_recover_carried(parent,remote,rec3,ghost)
assert(ok and why=="existing-relocation-mined" and remote_mines==1,
  "retry must not mine the same station twice")
package.loaded["scripts.core.station_cargo_0824"]=nil
package.loaded["scripts.core.station_relocation_0823"]=nil
Cargo=require("scripts.core.station_cargo_0824")
M=require("scripts.core.station_relocation_0823")
assert(Cargo.get(parent,rec3) and M.pending_for_record(rec3),
  "save/reload must preserve the real cargo and living priest lease")
parent.priest.position={x=40,y=0}
_G.ensure_pair_logistic_caches=function(p)
  p.logistic_requester=hidden_cache("tech-priests-cogitator-requester-cache",812,p.station.position)
  p.logistic_return_cache=hidden_cache("tech-priests-cogitator-return-cache",813,p.station.position)
  return true
end
assert(Cargo.begin_build(parent,rec3) and M.begin_build(rec3,parent))
local rebuilt_remote={valid=true,unit_number=90,
  name="junior-cogitator-station",force=force,surface=surface,
  position={x=40,y=0}}
assert(M.claim(rebuilt_remote) and Cargo.complete(parent,rec3))
assert(remote.station==rebuilt_remote and remote.priest.unit_number==109
  and remote.proxy==remote_proxy and remote_proxy.valid and remote_proxy.ammunition==9
  and remote.logistic_requester and remote.logistic_requester.valid
  and remote.logistic_requester~=old_requester
  and remote.logistic_return_cache and remote.logistic_return_cache.valid
  and remote.logistic_return_cache~=old_return
  and remote.logistic_requester.position==rebuilt_remote.position
  and storage.tech_priests.station_by_priest[109]==90
  and not Cargo.has_record(rec3) and not M.pending_for_record(rec3)
  and not bags[#bags].valid,
  "real recovered item must be consumed once, priest rebound once")
local remote_refused=pair(10,1,"junior-cogitator-station")
remote_refused.station.position={x=65,y=0}
remote_refused.command_hierarchy_0480.superior_unit=1
storage.tech_priests.pairs_by_station[10]=remote_refused
remote_refused.station.mine=function()return false end
local rec4={id=10,station_item="junior-cogitator-station",
  ghost_unit=700,ghost_position={x=40,y=0}}
parent.priest.position={x=65,y=0}
ok,why=M.try_recover_carried(parent,remote_refused,rec4,ghost)
assert(not ok and why=="engine-mining-refused"
  and remote_refused.station.valid and remote_refused.priest.valid
  and not Cargo.has_record(rec4) and not M.pending_for_record(rec4)
  and bags[#bags].valid==false,
  "engine-refused mine must destroy only the EMPTY hold and keep the station")
-- Engine-confirmed collision standoff (1.533 tiles) must not keep a real
-- station-item carrier issuing unreachable go_to_location commands forever.
-- The actual 0824 cargo authority independently requires <=5 tiles and a
-- physical item count of exactly one before any new station may be built.
local expansion=require("scripts.magos_station_expansion")
local ghost_site={x=40,y=0}
assert(expansion.is_at_ghost_build_standoff({x=41.5,y=40/40}, {x=40,y=1})
    and not expansion.is_at_ghost_build_standoff({x=43,y=1},{x=40,y=1}),
  "station ghost standoff cutoff rejected reachable unit or allowed remote site")
local measured=math.sqrt(2.3502349853516)
assert(expansion.is_at_ghost_build_standoff({x=measured,y=0},{x=0,y=0})
    and TECH_PRIESTS_STATION_EXPANSION_APPROACH_RADIUS_0256<=math.sqrt(Cargo.reach_sq),
  "real headless ghost collision standoff must be inside physical item-build range")
print("station relocation 0825: distant walk/recovery, real carried item, save/reload, rebind and refusal PASS")
print("station relocation 0823: physical mine, inventory, lease, save/reload and identity PASS")
