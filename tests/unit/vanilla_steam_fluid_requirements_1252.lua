-- 1252: prove real, recipe-less vanilla water/steam appliances are
-- inspected by existing 0689; no electricity, steam or inventory is granted.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=100}
storage={tech_priests={pairs_by_station={}}}
local f={index=1}
local surface={index=1}
local pair={station={valid=true,unit_number=100,position={x=0,y=0},force=f,surface=surface},
 priest={valid=true,unit_number=101}}
local function box(contents,flows)
 local fluid={valid=true}
 for i,v in ipairs(flows)do fluid[i]=v end
 fluid.get_prototype=function(i)
  return {object_name="LuaFluidBoxPrototype",
   production_type=flows[i].direction,filter={name=flows[i].filter}}
 end
 fluid.get_fluid_segment_contents=function(i)
  return contents[flows[i].filter] and {[flows[i].filter]=contents[flows[i].filter]}
    or {}
 end
 fluid.get_pipe_connections=function(i)
  return {{target_position={x=i*4,y=0},target=nil}}
 end
 fluid.get_capacity=function()return 100 end
 return fluid
end
local function machine(name,typ,id,flows)
 return {valid=true,name=name,type=typ,unit_number=id,
  surface=surface,force=f,position={x=id,y=0},
  fluidbox=box({},flows)}
end
local boiler=machine("boiler","boiler",102,{
 {direction="input",filter="water"},
 {direction="output",filter="steam"}})
local engine=machine("steam-engine","generator",103,{
 {direction="input",filter="steam"}})
local pump=machine("offshore-pump","offshore-pump",104,{
 {direction="output",filter="water"}})
local mystery=machine("other-power","generator",105,{
 {direction="input",filter="steam"}})
local Doctrine=require("scripts.core.fluid_network_doctrine_0689")
local b=Doctrine.inspect_machine(pair,boiler,true)
assert(b and b.recipe_name=="native-boiler-water-to-steam"
 and #b.fluid_inputs==1 and b.fluid_inputs[1].name=="water"
 and #b.fluid_outputs==1 and b.fluid_outputs[1].name=="steam"
 and b.records[1].direction=="input"
 and b.records[2].direction=="output"
 and #b.missing_inputs==1,
 "boiler without recipe lost water/steam pipeline requirements")
local g=Doctrine.inspect_machine(pair,engine,true)
assert(g and g.recipe_name=="native-generator-steam"
 and #g.fluid_inputs==1 and g.fluid_inputs[1].name=="steam"
 and #g.fluid_outputs==0 and #g.missing_inputs==1,
 "steam engine without recipe was incorrectly declared fluid-ready")
local p=Doctrine.inspect_machine(pair,pump,true)
assert(p and p.recipe_name=="native-offshore-water"
 and #p.fluid_inputs==0
 and #p.fluid_outputs==1 and p.fluid_outputs[1].name=="water",
 "real offshore pump output was invisible to existing 0691")
local absent=Doctrine.inspect_machine(pair,mystery,true)
assert(absent==nil,"unknown recipe-less generator acquired invented steam contract")
assert(boiler.fluidbox.valid and engine.fluidbox.valid
 and pump.fluidbox.valid,
 "read-only energy fluid doctrine mutated physical fluidboxes")
print("[vanilla-steam-fluid-requirements-1252] PASS real recipe-free pump/boiler/engine fluid identities, no synthetic outputs")
