-- 0879: a budgeted hidden equipment heartbeat must eventually reach every
-- live priest, especially later stations in a populated Factorio save.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local Alignment=require("scripts.core.proxy_turret_alignment")
local surface,force={},{}
local spawned,teleports=0,0
local actors={}
storage={tech_priests={pairs_by_station={}}}
game={tick=1000}
for id=1,37 do
  local original={x=id*13,y=5}
  local priest={valid=true,unit_number=1000+id,position=original,
    surface=surface,force=force}
  local proxy={valid=true,unit_number=2000+id,
    name="tech-priest-small-arms-proxy",
    position={x=original.x+11,y=original.y+3},
    force=force,surface=surface,ammo={["firearm-magazine"]=id}}
  proxy.teleport=function(destination)
    teleports=teleports+1
    proxy.position={x=destination.x,y=destination.y}
    return true
  end
  local pair={station={valid=true,unit_number=id,position=original,
      surface=surface,force=force},
    priest=priest,proxy=proxy}
  storage.tech_priests.pairs_by_station[id]=pair
  actors[#actors+1]={priest=priest,proxy=proxy,pair=pair,position=original}
end
local visited={}
for cycle=1,10 do
  local outcome=Alignment.heartbeat_service(nil,cycle==10 and 1 or 4)
  assert(outcome.processed==4 or cycle==10 and outcome.processed==1,
    "heartbeat budget must apply to real live pairs")
  local n=0
  for i,entry in ipairs(actors) do
    if entry.pair.last_proxy_alignment_0430 then
      if not visited[i] then n=n+1 end
      visited[i]=true
    end
  end
  if cycle<10 then assert(n==4,"a heartbeat must reach four new pairs") end
  game.tick=game.tick+90
end
for i,entry in ipairs(actors) do
  assert(visited[i] and entry.pair.proxy==entry.proxy
    and entry.proxy.valid and entry.proxy.position.x==entry.position.x
    and entry.proxy.position.y==entry.position.y
    and entry.priest.position==entry.position
    and entry.proxy.ammo["firearm-magazine"]==i,
    "0879 physical proxy/priest/ammo conservation at pair "..i)
end
assert(teleports==37 and spawned==0,
  "each existing hidden proxy must be aligned exactly once")
local saved=storage.tech_priests[Alignment.storage_key]
assert(saved.heartbeat_cursor==37,
  "cursor must complete a deterministic entire roster")
-- A save/reload persistent cursor must continue where it left off, even if
-- one old station disappears and a new one is registered.
storage.tech_priests.pairs_by_station[1]=nil
actors[1].pair.station.valid=false
local extra={valid=true,unit_number=9999,
  position={x=999,y=0},surface=surface,force=force}
storage.tech_priests.pairs_by_station[9999]={
  station={valid=true,unit_number=9999,surface=surface,force=force},
  priest={valid=true,unit_number=9998,position=extra.position,
    surface=surface,force=force},
  proxy=extra
}
local ok,status=pcall(Alignment.heartbeat_service,nil,4)
assert(ok and status.processed==4 and storage.tech_priests[Alignment.storage_key]
  .heartbeat_cursor~=nil,"roster churn must not break persistent rotation")
print("[proxy-heartbeat-fairness-0879] PASS bounded rotating owner coverage, 37 original proxies and ammo preserved, save/reload cursor survives roster changes")

-- 0880: second-Junior station recycling must remain blocked until a real
-- idle, exclusive, attached proxy's stale combat target is observably cleared.
-- Active combat, recent combat, shared proxies and rejected writes fail closed.
local Recovery=require("scripts.core.station_recycling_0822")
local domain={find_logistic_network_by_position=function() return nil end}
local faction={}
local function recovery_pair(id,rank,name)
  local pos={x=id*8,y=0}
  return {rank=rank,mode="idle",
    station={valid=true,unit_number=id,name=name,position=pos,
      force=faction,surface=domain,minable=true,
      prototype={mineable_properties={products={{name=name,type="item",amount=1}}}}},
    priest={valid=true,unit_number=id+100,position=pos,force=faction,surface=domain},
    command_hierarchy_0480={superior_unit=nil,direct_subordinate_units={},peer_units={}}}
end
local parent=recovery_pair(1,2,"intermediate-cogitator-station")
local candidate=recovery_pair(2,1,"junior-cogitator-station")
candidate.command_hierarchy_0480.superior_unit=1
local attached={valid=true,unit_number=2200,name="tech-priest-small-arms-proxy",
  position=candidate.priest.position,force=faction,surface=domain,
  ammo={["firearm-magazine"]=17},shooting_target={valid=true}}
candidate.proxy=attached
storage={tech_priests={pairs_by_station={[1]=parent,[2]=candidate},
  station_expansion_0256={}}}
game.tick=6000
defines={inventory={chest=1}}
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  rank=function(p) return p.rank end,
  is_direct_subordinate=function(p,c)
    return c.command_hierarchy_0480.superior_unit==p.station.unit_number
  end}
_G.tech_priests_0358_station_sources_for_pair=function(p)
  return {{owner=p.station,inv={valid=true,get_contents=function() return {} end}}}
end
local function preflight()
  return Recovery.check_candidate(parent,candidate,"junior-cogitator-station")
end
local eligible,reason=preflight()
assert(not eligible and reason=="linked-helper-needs-lifecycle:proxy",
  "0822 must refuse a real proxy with stale shooting target")
local quiet=Alignment.heartbeat_service(nil,2)
assert(quiet.acted==1 and attached.shooting_target==nil
  and attached.valid and candidate.proxy==attached
  and attached.ammo["firearm-magazine"]==17
  and candidate.last_proxy_idle_target_clear_0880.proxy_unit==2200,
  "quiet heartbeat must clear only the obsolete target, preserving proxy and ammunition")
assert(preflight(),"0822 must accept only after verified idle proxy readback")
local hostile={valid=true}
candidate.combat_target=hostile
candidate.mode="combat"
attached.shooting_target=hostile
Alignment.heartbeat_service(nil,2)
assert(attached.shooting_target==hostile,
  "live combat target must not be cleared to permit station mining")
candidate.combat_target=nil
candidate.mode="idle"
candidate.last_proxy_combat_sustain_0430={tick=game.tick}
Alignment.heartbeat_service(nil,2)
assert(attached.shooting_target==hostile,
  "recently sustained combat requires a quiet grace period")
game.tick=game.tick+181
Alignment.heartbeat_service(nil,2)
assert(attached.shooting_target==nil,
  "quiet post-combat proxy target must eventually be cleared")
parent.proxy=attached
attached.shooting_target={valid=true}
local shared_mutations=0
attached.teleport=function() shared_mutations=shared_mutations+1; return true end
attached.destroy=function() shared_mutations=shared_mutations+1 end
Alignment.heartbeat_service(nil,2)
assert(attached.shooting_target~=nil and shared_mutations==0
  and parent.proxy==attached and candidate.proxy==attached,
  "shared proxy must not be moved, destroyed or cleared to force mining eligibility")
parent.proxy=nil
Alignment.heartbeat_service(nil,2)
assert(attached.shooting_target==nil,
  "exclusively owned proxy must become eligible after shared custody ends")
local held={valid=true}
local refused={valid=true,unit_number=2300,name=attached.name,
  position=candidate.priest.position,force=faction,surface=domain,
  ammo={["firearm-magazine"]=23}}
setmetatable(refused,{
  __index=function(_,key) if key=="shooting_target" then return held end end,
  __newindex=function(t,key,value)
    if key=="shooting_target" then error("Factorio target write refused") end
    rawset(t,key,value)
  end})
candidate.proxy=refused
local safe,status=pcall(Alignment.heartbeat_service,nil,2)
assert(safe and status.acted==0 and refused.shooting_target==held
  and refused.ammo["firearm-magazine"]==23,
  "failed target mutation must not destroy or replace real proxy/ammunition")
eligible,reason=preflight()
assert(not eligible and reason=="linked-helper-needs-lifecycle:proxy",
  "failed target write must keep station mining fail-closed")
print("[proxy-idle-target-recovery-0880] PASS second-Junior preflight, stale target cleanup, active/recent combat, shared ownership, refused write and ammunition custody")
