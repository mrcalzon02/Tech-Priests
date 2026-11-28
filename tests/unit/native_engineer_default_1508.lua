-- Native Engineer ownership contract: exact prototype, no automatic overlay,
-- third-party bodies, legacy default migration and owned render cleanup.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local function copy(v,seen)
  if type(v)~="table" then return v end
  seen=seen or {};if seen[v] then return seen[v] end
  local r={};seen[v]=r
  for k,x in pairs(v) do r[copy(k,seen)]=copy(x,seen) end
  return r
end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~="table" then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
table.deepcopy=copy
settings={startup={}}
-- Nonstandard animation layout models a third-party Engineer skin. The picker
-- must not export, validate, rewrite or assume its atlas layout.
local native={type="character",name="character",running_speed=.234,inventory_size=87,
 animations={{running={filenames={"other-mod-atlas.png"},direction_count=7,
  frame_count=13,lines_per_file=3,tint={r=.4,g=.6,b=.8,a=.9},apply_runtime_tint=true}}},
 light={{intensity=.9}},footprint_particles={{name="other-mod-dust"}}}
local other=copy(native);other.name="another-mod-character"
local corpse={type="character-corpse",name="character-corpse",picture={filename="mod-corpse.png",size=24}}
data={raw={character={character=native,[other.name]=other},["character-corpse"]={["character-corpse"]=corpse},unit={},corpse={}}}
function data:extend(rows)
 for _,row in ipairs(rows) do
  self.raw[row.type]=self.raw[row.type] or {};self.raw[row.type][row.name]=row
 end
end
local before,other_before,corpse_before=copy(native),copy(other),copy(corpse)
local P=require("prototypes.character_skins");P.register()
assert(data.raw.character.character==native and equal(native,before),"default prototype was modified")
assert(equal(other,other_before) and equal(corpse,corpse_before),"third-party character or corpse changed")
local host=data.raw.character[P.host_name]
assert(host and host.animations~=native.animations and equal(host.animations,native.animations),"legacy host not visible native copy")
assert(host.running_speed==native.running_speed and host.inventory_size==native.inventory_size)
assert(not data.raw["mod-data"],"native art must not be re-exported")
local routes={}
local function route(fn,opts)routes[#routes+1]={fn=fn,priority=opts.priority or 0}end
package.loaded["scripts.core.runtime_event_registry"]={
 on_init=route,on_configuration_changed=function()return true end,on_event=function()return true end}
package.loaded["scripts.core.runtime_tick_broker"]={installed=true,register_service=function()return true end}
package.loaded["mod-gui"]={get_button_flow=function()return {}end}
package.loaded["shared.combat_roster_catalog"]={for_entity_name=function()return nil end}
defines={events=setmetatable({},{__index=function(_,k)return k end}),shooting={not_shooting=0}}
storage={tech_priests={}}
local next_id,drawn,objects=0,0,{}
rendering={get_object_by_id=function(id)return objects[id]end}
function rendering.draw_animation(spec)
 next_id=next_id+1;drawn=drawn+1
 local o={id=next_id,valid=true,animation=spec.animation,animation_speed=spec.animation_speed,color=spec.tint}
 o.destroy=function()o.valid=false end;objects[next_id]=o;return o
end
local function body(id,name)
 return {valid=true,type="character",unit_number=id,name=name or "character",position={x=0,y=0},
  surface={index=1,find_entities_filtered=function()error("forbidden native body scan")end},
  force={color={r=1,g=1,b=1}},orientation=0,walking_state={walking=false},
  shooting_state={state=0},mining_state={mining=false}}
end
local function player(id,e)
 local screen={}
 screen.add=function(spec)local o={valid=true,style={}};o.destroy=function()o.valid=false end;screen[spec.name]=o;return o end
 local p={index=id,valid=true,connected=true,character=e,gui={screen=screen},color={r=1,g=1,b=1},
  display_resolution={width=1280,height=720},display_scale=1}
 e.player=p
 return p
end
local a=player(1,body(101));local b=player(2,body(102,other.name))
game={tick=1,players={a,b},connected_players={a,b},get_player=function(i)return ({a,b})[i]end}
local V=require("scripts.core.character_visuals")
local Picker=require("scripts.core.character_skin_picker")
assert(Picker.install())
table.sort(routes,function(x,y)return x.priority<y.priority end)
-- Mimic an older save with the automatic Enginseer and an old default draw.
local old=rendering.draw_animation{animation="obsolete-engineer",animation_speed=1}
storage.tech_priests.character_visuals={actors={[101]={entity=a.character,model="vanilla",renders={old.id},player_index=1}},stats={}}
storage.tech_priests.character_skin_picker={selected={[1]="enginseer"},pending={},reasons={},characters={[1]=a.character}}
for _,r in ipairs(routes) do r.fn() end
assert(not old.valid and Picker.selected(a)=="vanilla","legacy automatic default not retired")
assert(Picker.default_skin()=="vanilla" and Picker.selected(b)=="vanilla")
assert(not storage.tech_priests.character_visuals.actors[101] and not V.needs_dormant_tick())
local initial=drawn
assert(Picker.choose(b,"vanilla") and drawn==initial,"third-party default was rejected or redrawn")
assert(not Picker.choose(b,"enginseer"),"third-party native body was appropriated")
assert(Picker.choose(a,"enginseer"),"explicit skin selection failed")
assert(a.character.unit_number==101 and drawn==initial+3 and V.needs_dormant_tick())
assert(storage.tech_priests.character_skin_picker.explicit[1])
local rec=storage.tech_priests.character_visuals.actors[101]
local ids=copy(rec.renders)
assert(Picker.choose(a,"vanilla"))
for _,id in pairs(ids) do assert(not objects[id].valid,"owned overlay survived native restoration")end
assert(Picker.selected(a)=="vanilla" and not V.needs_dormant_tick())
assert(not V.track(body(200),"enginseer"),"unowned native Engineer was enrolled")
assert(Picker.choose(a,"enginseer"))
local oldbody=a.character
local oldids=copy(storage.tech_priests.character_visuals.actors[101].renders)
a.character=body(103);a.character.player=a;oldbody.player=nil
assert(V.refresh_player(a,"enginseer"))
assert(not storage.tech_priests.character_visuals.actors[101])
for _,id in pairs(oldids) do assert(not objects[id].valid)end
a.character.player=b;a.character=nil
assert(not V.refresh_player(a,"enginseer"),"stale body must not be reused")
assert(not V.needs_dormant_tick())
assert(Picker.choose(a,"vanilla") and Picker.selected(a)=="vanilla","native default needs no body")
print("native_engineer_default_1508 PASS: exact default and modded prototypes, explicit choice, legacy cleanup, stale-body ownership, dormant default")
