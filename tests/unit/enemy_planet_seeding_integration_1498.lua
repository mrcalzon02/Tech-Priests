-- T1-07: repeated chunk generation and charting remain placement-equivalent.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
storage={tech_priests={}}
settings={global={['tech-priests-enemy-planetary-spawning']={value=true}}}
local generated,settings_changed,deleted,renamed=100,101,102,103
local current_seed,seed_reads,option_reads=4242,0,0
local option_values={['other-spacing']=5,['priority-spacing']=3,
 ['spawn-clearance']=0,['base-clearance']=16,['colony-clearance']=16,
 ['respect-peaceful']=true}
local allowed_planet='nauvis'
local allowed_queries=0
package.preload['scripts.core.enemy_colony_options']=function()
 return {get=function(key,default)
   option_reads=option_reads+1
   local v=option_values[key]
   if v==nil then return default end
   return v
 end,
 allowed_planet=function(planet)
   allowed_queries=allowed_queries+1
   return planet==allowed_planet
 end,
 admit_colony=function()return true end}
end
local placed,can_place_calls={},0
package.preload['scripts.core.enemy_colony']=function()
 return {can_place=function() can_place_calls=can_place_calls+1;return true end,
 create=function(surface,position,planet)
   local value={surface_index=surface.index,x=position.x,y=position.y,planet=planet}
   placed[#placed+1]=value
   return value
 end}
end
local callbacks={}
package.preload['scripts.core.runtime_event_registry']=function()
 return {on_event=function(id,handler,filter,opts)
  assert(opts.owner=='enemy_planetary_seeding')
  assert(not callbacks[id],'unexpected duplicate handler registration')
  callbacks[id]=handler
  return true
 end}
end
local surf=setmetatable({valid=true,index=1,name='nauvis',peaceful_mode=false,
 count_entities_filtered=function(args)
  assert(args.radius==16)
  return 0
 end},
 {__index=function(_,key)
   if key=='map_gen_settings' then seed_reads=seed_reads+1;return {seed=current_seed} end
 end})
local player={name='player',get_spawn_position=function()return {x=100000,y=100000} end}
game={tick=1,forces={player},surfaces={[1]=surf}}
defines={events={on_chunk_generated=generated,on_chunk_charted=generated+1,
 on_surface_deleted=generated+2,on_surface_renamed=generated+3,
 on_runtime_mod_setting_changed=generated+4}}
local M=require('scripts.core.enemy_planetary_seeding')
assert(M.install())
local function qualifies(x,y,size,seed)
 local rx,ry=math.floor(x/size),math.floor(y/size)
 local hash=(rx*73856093+ry*19349663+seed)%2147483647
 return x%size==hash%size and y%size==math.floor(hash/size)%size
end
local candidate
for x=-60,60 do for y=-60,60 do
 if qualifies(x,y,5,current_seed) then candidate={x=x,y=y};break end
end if candidate then break end end
assert(candidate,'no candidate chunk found')
-- Most chunk events are rejected by the cheap hash before proximity queries.
for x=1,100 do for y=1,100 do M.seed_chunk(surf,{x=x,y=y}) end end
assert(seed_reads==1,'generated map settings were copied per chunk')
assert(allowed_queries==1 and option_reads==5,
  'planet/options configuration was rederived per chunk')
local initial_count=#placed
callbacks[generated]({surface=surf,position=candidate})
local after=#placed
assert(after==initial_count or after==initial_count+1)
callbacks[generated+1]({surface_index=1,position=candidate})
assert(#placed==after,'generated/charted same chunk caused duplicate colony')
local before=seed_reads
callbacks[generated+4]({setting='irrelevant-mod-option'})
M.seed_chunk(surf,{x=1,y=1})
assert(seed_reads==before,'unrelated settings invalidated cached seed')
current_seed=987;option_values['other-spacing']=7
callbacks[generated+4]({setting='tech-priests-enemy-other-spacing'})
M.seed_chunk(surf,{x=1,y=1})
assert(seed_reads==before+1 and allowed_queries==2,
 'runtime enemy settings change did not invalidate cached placement parameters')
settings.global['tech-priests-enemy-planetary-spawning'].value=false
M.seed_chunk(surf,{x=1,y=1})
assert(seed_reads==before+1,'global disable was not immediately honored')
settings.global['tech-priests-enemy-planetary-spawning'].value=true
surf.peaceful_mode=true
local n=#placed
M.seed_chunk(surf,{x=1,y=1})
assert(#placed==n,'peaceful world admitted colony')
surf.peaceful_mode=false
callbacks[generated+3]({surface_index=1})
M.seed_chunk(surf,{x=1,y=1})
assert(seed_reads==before+2,'surface rename did not invalidate config')
callbacks[generated+2]({surface_index=1})
assert(storage.tech_priests.enemy_planetary_seeding[1]==nil,
 'surface deletion preserved obsolete colonies')
M.seed_chunk(surf,{x=1,y=1})
assert(seed_reads==before+3,'surface deletion kept stale config')
-- Expiry recovers from procedural map settings changed by another script.
game.tick=601
current_seed=73
M.seed_chunk(surf,{x=1,y=1})
assert(seed_reads==before+4,'cache TTL ignored a changed world seed')
print('[enemy-planet-seeding-integration-1498] PASS')
