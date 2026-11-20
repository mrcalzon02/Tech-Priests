-- Regression 1500: direct stable target-key checks preserve reservation semantics.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
storage={tech_priests={}}
game={tick=10}
local R=require('scripts.core.work_reservations')
local surface={index=1,name='nauvis'}
local force={index=1,name='player'}
local target={valid=true,unit_number=300,name='stone-wall',type='wall',
  surface=surface,force=force,position={x=4,y=5}}
local a={station={valid=true,unit_number=11}}
local b={station={valid=true,unit_number=22}}
local key=R.target_key(target)
assert(key=='unit:300','unit reservation format changed')
assert(R.is_claimed_key('repair',key,b)==false,'unclaimed item reported taken')
assert(R.claim('repair',target,a,30))
local fast,record=R.is_claimed_key('repair',key,b)
assert(fast and record and record.key==key,'direct key failed to locate claim')
assert(R.is_claimed('repair',target,b)==true,'legacy lookup differs from direct key')
assert(R.is_claimed_key('repair',key,a)==false,'own active claim reported taken')
assert(R.is_claimed_key('repair','unit:999',b)==false)
assert(R.is_claimed_key('repair',nil,b)==false)
assert(R.is_claimed_key('repair','',b)==false)
game.tick=40
assert(R.is_claimed_key('repair',key,b)==false,'expired claim reported taken')
assert(R.get('repair',target)==nil,'expired reservation was not removed')
assert(R.root().stats.expired_seen==1,'expiry pruning not counted exactly once')
assert(R.claim('repair',target,b,100),'target not reservable after expiry')
assert(R.is_claimed_key('repair',key,a)==true)
assert(R.release_key('repair',key,b),'direct release by key failed')
assert(R.is_claimed_key('repair',key,a)==false)
local pos={surface_index=1,force_index=1,position={x=2.5,y=8}}
assert(R.claim('pickup',pos,a,100))
assert(R.is_claimed('pickup',pos,b)==true,'scoped position claim lost')
assert(R.is_claimed_key('pickup',R.target_key(pos),b)==true)
local another={surface_index=2,force_index=1,position={x=2.5,y=8}}
assert(R.is_claimed('pickup',another,b)==false,'different surface shared a positional reservation')
print('[reservation-key-lookup-1500] PASS')
