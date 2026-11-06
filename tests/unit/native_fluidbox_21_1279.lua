-- 2.1 native read-only fluid network proof + 2.0 original passthrough.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local native=require("scripts.core.native_fluidbox_1279")
local oldbox={valid=true}
assert(native.observe({valid=true,fluidbox=oldbox})==oldbox,
 "2.0 real LuaFluidBox must be returned untouched")
local real_pipe={valid=true,name="pipe"}
local counts={segment=0,pipe=0,fluid=0}
local modern={
 valid=true,fluids_count=2,
 get_fluid_box_prototype=function(i)
  if i==1 then return {production_type="input",filter={name="water"}} end
 end,
 get_fluid=function(i)
  counts.fluid=counts.fluid+1
  if i==1 then return {name="water",amount=25,temperature=15} end
 end,
 get_fluid_segment_fluid=function(i)
  counts.segment=counts.segment+1
  if i==1 then return {name="water",amount=75,temperature=15} end
 end,
 get_fluid_segment_id=function(i)if i==1 then return 117 end end,
 get_fluid_capacity=function(i)if i==1 then return 100 end end,
 get_fluid_filter=function(i)if i==1 then return {name="water"} end end,
 get_fluid_box_pipe_connections=function(i)
  counts.pipe=counts.pipe+1
  if i==1 then
    return {{target=real_pipe,target_position={x=2,y=3}}}
  end
  return {}
 end,
 get_fluid_box_neighbours=function(i)
  if i==1 then return {{entity=real_pipe,index=1}} end
  return {}
 end,
}
local box=native.observe(modern)
assert(box and box.valid and #box==1,"2.1 internal buffer counted as pipe")
assert(box.get_prototype(1).production_type=="input"
  and box.get_filter(1).name=="water" and box.get_locked_fluid(1)=="water")
assert(box.get_capacity(1)==100 and box.get_fluid_segment_id(1)==117)
assert(box.get_fluid_segment_contents(1).water==75
  and box[1].amount==25,"native fluid source was replaced or omitted")
local ports=box.get_pipe_connections(1)
assert(#ports==1 and ports[1].target.owner==real_pipe
  and ports[1].target_position.x==2 and #box.get_connections(1)==1
  and box.get_connections(1)[1]==real_pipe,
 "native connection identity or target position lost")
assert(counts.segment==1 and counts.pipe==1 and counts.fluid==1)
local disconnected=native.observe({
 valid=true,fluids_count=1,
 get_fluid_box_prototype=function()return {} end,
 get_fluid_box_pipe_connections=function()return {} end,
})
assert(disconnected and #disconnected.get_pipe_connections(1)==0,
 "unknown native pipe was falsely connected")
assert(native.observe({
 valid=true,fluids_count=1,
 get_fluid_box_prototype=function()return nil end,
})==nil,"internal-only buffer claimed to be a pipe")
assert(native.observe({valid=false,fluids_count=1})==nil)
print("[native-fluidbox-21-1279] PASS real 2.1 fluids and connections, 2.0 intact")
