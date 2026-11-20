-- Diagnostic only: static per-surface config lookup, not native Factorio UPS.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
local C=require('scripts.core.enemy_seed_config_1498')
game={tick=1200}
local map_reads,option_reads,allow_reads=0,0,0
local opts={
  ['other-spacing']=24,['priority-spacing']=12,
  ['spawn-clearance']=384,['base-clearance']=96,
  ['colony-clearance']=192,['respect-peaceful']=true,
}
local Options={
  allowed_planet=function(name)
    allow_reads=allow_reads+1
    return name=='nauvis'
  end,
  get=function(key,default)
    option_reads=option_reads+1
    if opts[key] == nil then return default end
    return opts[key]
  end,
}
local surface=setmetatable({valid=true,index=1,name='nauvis'}, {
  __index=function(_,key)
    if key=='map_gen_settings' then
      map_reads=map_reads+1
      return {seed=9909}
    end
  end,
})
local N=30000
local function eligible(x,y,size,seed)
  local rx,ry=math.floor(x/size),math.floor(y/size)
  local hash=(rx*73856093+ry*19349663+seed)%2147483647
  return x%size==hash%size and y%size==math.floor(hash/size)%size
end
local function old_run()
  local count=0
  for i=1,N do
    local planet=surface.planet and surface.planet.name or surface.name
    local allowed=Options.allowed_planet(planet)
    local size=Options.get('other-spacing',24)
    local seed=surface.map_gen_settings.seed or 0
    Options.get('spawn-clearance',384)
    Options.get('base-clearance',96)
    Options.get('colony-clearance',192)
    Options.get('respect-peaceful',true)
    if allowed and eligible(i%500,math.floor(i/500),size,seed) then count=count+1 end
  end
  return count
end
local function new_run()
  local count=0
  for i=1,N do
    local c=C.for_surface(surface,Options)
    if c.allowed and eligible(i%500,math.floor(i/500),c.spacing,c.seed) then count=count+1 end
  end
  return count
end
local start=os.clock()
local old_count=old_run()
local old_ms=(os.clock()-start)*1000
local old_map,old_opts,old_allow=map_reads,option_reads,allow_reads
map_reads,option_reads,allow_reads=0,0,0
start=os.clock()
local new_count=new_run()
local new_ms=(os.clock()-start)*1000
assert(old_count==new_count, 'cached configuration changed chunk eligibility')
assert(old_map==N and map_reads==1, 'unexpected map settings copy count')
assert(old_opts==N*5 and option_reads==5, 'option lookups were not amortized')
assert(old_allow==N and allow_reads==1, 'planet permission checks were not amortized')
print(string.format('[enemy-seed-config-1498-perf] events=%d candidates=%d old-map-copies=%d new-map-copies=%d old-options=%d new-options=%d', N, new_count,old_map,map_reads,old_opts,option_reads))
print(string.format('[enemy-seed-config-1498-perf] synthetic Lua old_ms=%.3f new_ms=%.3f ratio=%.2fx (not Factorio UPS)',old_ms,new_ms,old_ms/new_ms))
