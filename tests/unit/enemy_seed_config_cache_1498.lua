-- T1-07: per-surface map generation snapshots are short-lived and invalidatable.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
local Cache=require('scripts.core.enemy_seed_config_1498')
game={tick=100}
local copies,settings_reads,seed=0,0,123
local allowed=true
local Options={
  allowed_planet=function(planet)
    assert(planet=='nauvis')
    settings_reads=settings_reads+1
    return allowed
  end,
  get=function(key,default)
    settings_reads=settings_reads+1
    local map={['other-spacing']=6,['priority-spacing']=4,
      ['respect-peaceful']=true,['spawn-clearance']=32,
      ['base-clearance']=64,['colony-clearance']=96}
    return map[key] or default
  end,
}
local surface=setmetatable({valid=true,index=7,name='nauvis'}, {
  __index=function(_,key)
    if key=='map_gen_settings' then
      copies=copies+1
      return {seed=seed}
    end
  end,
})
local first=Cache.for_surface(surface,Options)
assert(first.seed==123 and first.spacing==6 and first.allowed
  and first.spawn_clearance==32 and first.base_clearance==64
  and first.colony_clearance==96 and first.respect_peaceful==true)
assert(copies==1 and settings_reads==6,'initial config was read incorrectly')
for i=1,5000 do
  assert(Cache.for_surface(surface,Options)==first)
end
assert(copies==1 and settings_reads==6,
  'per-chunk access recopied expensive map-generation settings')
seed=456;allowed=false;game.tick=699
assert(Cache.for_surface(surface,Options)==first,'TTL cache expired too early')
game.tick=700
local second=Cache.for_surface(surface,Options)
assert(second~=first and second.seed==456 and not second.allowed,
  'TTL failed to refresh changed seed and planet permissions')
assert(copies==2 and settings_reads==12)
Cache.invalidate(surface.index)
local third=Cache.for_surface(surface,Options)
assert(third~=second and copies==3,'surface invalidation ignored')
local replacement=setmetatable({valid=true,index=7,name='nauvis'},getmetatable(surface))
Cache.for_surface(replacement,Options)
assert(copies==4,'re-used surface index reused deleted surface object')
Cache.invalidate_all()
assert(Cache.for_surface(replacement,Options).tick==700 and copies==5,
  'runtime settings invalidation did not rebuild per-surface config')
game.tick=650
assert(Cache.for_surface(replacement,Options)~=third and copies==6,
  'nonmonotonic clock reused future cache entry')
assert(Cache.for_surface(nil,Options)==nil)
print('[enemy-seed-config-cache-1498] PASS')
