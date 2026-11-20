-- Full-authority regression: repair discovery must reach damaged targets past
-- a dense-base prefix without falsely caching unknown areas as empty.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
storage={tech_priests={}}
game={tick=10}
local surface={valid=true,index=1,name='nauvis'}
local force={valid=true,index=1,name='player'}
local station={valid=true,unit_number=10,position={x=32,y=32},surface=surface,force=force}
local pair={station=station,station_unit=10,radius=32}
local all={}
for i=1,100 do
  all[i]={valid=true,unit_number=1000+i,type='wall',name='stone-wall',
    surface=surface,force=force,position={x=10+(i%16),y=10+math.floor(i/16)},
    health=i==100 and 50 or 100,max_health=100}
end
local negatives,recorded={},0
local scans=0
_G.TechPriestsScanRouting0610={
  find_entities=function(s,filters,opts)
    assert(s==surface and filters.force==force)
    assert(opts.record_negative==false and opts.negative_key:find('repair%-sweep%-1503'))
    scans=scans+1
    if (negatives[opts.negative_key] or 0)>game.tick then return {},'negative-skip' end
    return all,'direct-scan'
  end,
  record_negative=function(category,key,ttl)
    assert(category=='repair')
    recorded=recorded+1
    negatives[key]=game.tick+ttl
  end,
}
package.preload['scripts.core.work_reservations']=function()
  return {target_key=function(target)
    return target.unit_number and 'unit:'..target.unit_number or 'no-unit'
  end}
end
local Q=require('scripts.core.work_queue_authority')
negatives['repair:1:1:10']=game.tick+1000 -- legacy false empty must not skip newer discovery.
for i=1,3 do
  local n,detail=Q.discover_repair_near(pair,{limit=32})
  assert(n==0 and detail:find('checked=32',1,true), 'dense partial inspection exceeded limit')
  assert(recorded==0,'incomplete prefix falsely certified no repair work')
end
local n,detail=Q.discover_repair_near(pair,{limit=32})
assert(n==1 and detail:find('checked=32',1,true),
 'damaged wall outside first 96 returned entities never discovered')
assert(Q.count('repair')==1,'missing queued order for tail damaged wall')
local r=Q.root()
assert((r.stats.repair_discovery_partial_windows_1503 or 0)==4)
assert(r.stats.repair_discovery_checked==128)
assert(recorded==0,'partial full cycle did not preserve negative-cache safety')
local clearPair={station=station,station_unit=10,radius=32}
all={all[1],all[2],all[3]}
local count,why=Q.discover_repair_near(clearPair,{limit=3})
assert(count==0 and why:find('complete=true',1,true))
assert(recorded==1 and r.stats.repair_discovery_full_windows_1503==1,
 'complete no-damage inspection failed to cache short negative')
local saved_until
for _,value in pairs(negatives)do
  if value==game.tick+240 then saved_until=value end
end
assert(saved_until)
local before=recorded
for i=1,50 do
  game.tick=game.tick+1
  local n,reason=Q.discover_repair_near(clearPair,{limit=3})
  assert(n==0 and reason:find('negative-skip',1,true))
end
assert(recorded==before,'negative skip kept extending its own expiry indefinitely')
game.tick=saved_until+1
Q.discover_repair_near(clearPair,{limit=3})
assert(recorded==before+1,'expired full-scan negative was never refreshed')
-- If a damaged candidate exists but submission fails, do not record absence.
local deniedPair={station=station,station_unit=10,radius=32}
all={all[1]};all[1].health=1
local submit=Q.submit
Q.submit=function()return false,'denied' end
local prev=recorded
game.tick=saved_until+241 -- let the second short negative expire
local matches=Q.discover_repair_near(deniedPair,{limit=3})
assert(matches==0 and recorded==prev,'damaged-but-unqueueable work marked absent')
Q.submit=submit
-- Confirm limits are clamped, including callers that request unbounded work.
all={}
for i=1,500 do all[i]={valid=true,unit_number=2000+i,
  name='stone-wall',type='wall',surface=surface,force=force,
  position={x=i%17,y=i%19},health=100,max_health=100} end
local n,txt=Q.discover_repair_near({station=station,station_unit=10,radius=32},{limit=1000000})
assert(n==0 and txt:find('checked=128',1,true),'unbounded option bypassed Lua inspection cap')
print('[repair-discovery-rotation-1503] PASS')
