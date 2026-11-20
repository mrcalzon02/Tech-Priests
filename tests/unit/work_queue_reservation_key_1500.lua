-- Regression 1500: work-queue stable entities use direct key lookup; positional fallback remains.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
storage={tech_priests={}}
game={tick=30}
local R=require('scripts.core.work_reservations')
local Q=require('scripts.core.work_queue_authority')
local surface={valid=true,index=1,name='nauvis'}
local force={valid=true,index=1,name='player'}
local station={valid=true,unit_number=50,position={x=0,y=0},surface=surface,force=force}
local pair={station=station,station_unit=50,radius=40}
local unit_target={valid=true,unit_number=900,position={x=8,y=8},
  surface=surface,force=force,name='stone-wall',type='wall'}
local ok,why,order=Q.submit('repair',unit_target,{id='repair:unit-900',priority=400,expires_tick=1000})
assert(ok and why=='submitted' and order.reservation_lookup_key_1500==R.target_key(unit_target),
  'stable unit target key not captured at submit time')
local fast_calls,slow_calls=0,0
local original_fast,original_slow=R.is_claimed_key,R.is_claimed
R.is_claimed_key=function(...)fast_calls=fast_calls+1;return original_fast(...)end
R.is_claimed=function(...)slow_calls=slow_calls+1;return original_slow(...)end
local chosen,status=Q.claim_nearest(pair,'repair',{search_radius=40})
assert(status=='claimed' and chosen==order,'stable target not claimed through queue')
assert(fast_calls>=1 and slow_calls==0,
  'queue reconstructed target identity despite a stable reservation key')
assert(chosen.reservation_key==R.target_key(unit_target),
  'claimed reservation did not preserve authoritative key')
local positional={position={x=9,y=7},surface_index=1,force_index=1}
ok,why,order=Q.submit('pickup',positional,{id='pickup:pos',priority=300,expires_tick=1000})
assert(ok and order and order.reservation_lookup_key_1500==nil,
  'positional order incorrectly retained a stale unit key')
chosen,status=Q.claim_nearest(pair,'pickup',{search_radius=40})
assert(status=='claimed' and chosen==order and slow_calls>=1,
  'position-only target did not use existing scoped fallback')
-- A pre-upgrade saved queue entry has no derived key; it must still work.
local second={valid=true,unit_number=901,position={x=10,y=10},
  surface=surface,force=force,name='stone-wall',type='wall'}
_,_,order=Q.submit('repair',second,{id='repair:unit-901',priority=500,expires_tick=1000})
order.reservation_lookup_key_1500=nil
local before=slow_calls
chosen,status=Q.claim_nearest(pair,'repair',{search_radius=40})
assert(status=='claimed' and chosen==order and slow_calls>before,
  'older unindexed queue entry lost fallback reservation lookup')
print('[work-queue-reservation-key-1500] PASS')
