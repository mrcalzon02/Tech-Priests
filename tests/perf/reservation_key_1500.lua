-- Diagnostic only: direct stable-unit lookup versus repeated target-key derivation.
-- Synthetic Lua timing, not native Factorio UPS; execute from repository root.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
storage={tech_priests={}}
game={tick=10}
local R=require('scripts.core.work_reservations')
local surface={index=1,name='nauvis'}
local force={index=1,name='player'}
local target={valid=true,unit_number=997,position={x=4.5,y=7.5},
  name='assembling-machine-1',type='assembling-machine',surface=surface,force=force}
local owner={station={valid=true,unit_number=10}}
local other={station={valid=true,unit_number=11}}
assert(R.claim('repair',target,owner,6000))
local key=R.target_key(target)
local N=150000
local function bench(fn)
  local begin=os.clock()
  for i=1,N do assert(fn()) end
  return (os.clock()-begin)*1000
end
local old_ms=bench(function()return R.is_claimed('repair',target,other)end)
local new_ms=bench(function()return R.is_claimed_key('repair',key,other)end)
print(string.format('[reservation-key-1500-perf] %d checks; legacy_ms=%.3f keyed_ms=%.3f ratio=%.2fx (Lua-only)',N,old_ms,new_ms,old_ms/new_ms))
