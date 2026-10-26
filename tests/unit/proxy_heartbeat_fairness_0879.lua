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
