-- 1255: genuine recipe-free offshore pump/boiler outputs start dry.
-- Verify that 0689 may PLAN real 0691 pipes without crediting any fluid.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=3000}
local force={valid=true,index=1}
local surface={valid=true,index=1}
storage={tech_priests={pairs_by_station={}}}
local pair={station={valid=true,unit_number=10,
 position={x=0,y=0},surface=surface,force=force},
 priest={valid=true,unit_number=11}}
local function fluidbox(ports)
 local box={valid=true}
 for i,_ in ipairs(ports)do box[i]=true end
 box.get_prototype=function(i)
  return {object_name="LuaFluidBoxPrototype",
   production_type=ports[i].direction,
   filter={name=ports[i].filter}}
 end
 box.get_filter=function(i)return ports[i].filter end
 box.get_fluid_segment_contents=function(i)return ports[i].contents or {} end
 box.get_pipe_connections=function(i)
  return {{target_position={x=ports[i].x,y=ports[i].y},target=nil}}
 end
 box.get_capacity=function()return 100 end
 return box
end
local pump={valid=true,unit_number=21,name="offshore-pump",
 type="offshore-pump",position={x=4,y=0},surface=surface,force=force,
 fluidbox=fluidbox({{direction="output",filter="water",x=6,y=0}})}
local boiler={valid=true,unit_number=22,name="boiler",
 type="boiler",position={x=10,y=0},surface=surface,force=force,
 fluidbox=fluidbox({
  {direction="input",filter="water",x=9,y=0},
  {direction="output",filter="steam",x=13,y=0},
 })}
local engine={valid=true,unit_number=23,name="steam-engine",
 type="generator",position={x=17,y=0},surface=surface,force=force,
 fluidbox=fluidbox({{direction="input",filter="steam",x=16,y=0}})}
local foreign={valid=true,unit_number=24,name="fictional-generator",
 type="generator",position={x=20,y=4},surface=surface,force=force,
 fluidbox=fluidbox({{direction="output",filter="steam",x=21,y=4}})}
local all={pump,boiler,engine,foreign}
surface.find_entities_filtered=function(spec)
 local kinds={}
 for _,name in ipairs(type(spec.type)=="table"and spec.type or{spec.type})do
  kinds[name]=true
 end
 local result={}
 for _,ent in ipairs(all)do
  if kinds[ent.type]then result[#result+1]=ent end
 end
 return result
end
local Doctrine=require("scripts.core.fluid_network_doctrine_0689")
local observed=Doctrine.scan_pair(pair,true)
local function describe_machine(e)
 local report,reason=Doctrine.inspect_machine(pair,e,true)
 return tostring(e.name)..":"..tostring(reason)..":"..
   tostring(report and #report.records or "missing")
end
assert(observed.processed>=3,"dry real pump or boiler was not inspected"
 .." processed="..tostring(observed.processed)
 .." reason="..tostring(observed.detail)
 .." pump="..describe_machine(pump)
 .." boiler="..describe_machine(boiler)
 .." engine="..describe_machine(engine))
local found_water,found_steam=nil,nil
for _,proposal in ipairs(pair.fluid_connection_proposals_0689 or{})do
 if proposal.machine==boiler and proposal.fluid=="water"then
  found_water=proposal
 elseif proposal.machine==engine and proposal.fluid=="steam"then
  found_steam=proposal
 end
end
assert(found_water and found_water.source.entity==pump
 and found_steam and found_steam.source.entity==boiler,
 "dry native water/steam outputs did not produce legitimate pipe proposals")
local ready_w,why_w=Doctrine.validate_proposal(pair,found_water)
local ready_s,why_s=Doctrine.validate_proposal(pair,found_steam)
assert(ready_w and ready_s
 and why_w=="safe" and why_s=="safe",
 "unfilled source prevented physical pipe routing")
-- No fluid was inserted and nothing is considered an operating generator.
assert(next(pump.fluidbox.get_fluid_segment_contents(1))==nil
 and next(boiler.fluidbox.get_fluid_segment_contents(1))==nil
 and next(boiler.fluidbox.get_fluid_segment_contents(2))==nil
 and next(engine.fluidbox.get_fluid_segment_contents(1))==nil,
 "dry pipe planning fabricated water or steam")
-- A foreign/unknown boiler-type generator cannot acquire a source contract.
local unknown=Doctrine.inspect_machine(pair,foreign,true)
assert(unknown==nil,"unknown dry generator received fabricated steam authority")
-- Once the actual port switches to a foreign filtered fluid, the original
-- proposal must fail closed; no pipe may be planned from stale identity.
pump.fluidbox=fluidbox({
 {direction="output",filter="crude-oil",x=6,y=0}})
local unsafe=Doctrine.validate_proposal(pair,found_water)
assert(not unsafe,"wrong-fluid source was treated as empty water")
-- Opposite failure: output may be a real owned boiler but empty and UNFILTERED.
-- Its unknown segment cannot be assumed to contain steam.
boiler.fluidbox=fluidbox({
 {direction="input",filter="water",x=9,y=0},
 {direction="output",filter=nil,x=13,y=0},
})
local uncertain=Doctrine.validate_proposal(pair,found_steam)
assert(not uncertain,"unfiltered empty boiler output was credited as steam")
print("[native-dry-steam-pipe-bootstrap-1255] PASS real empty pump/boiler ports propose water/steam pipes; foreign, unfiltered and missing-fluid production remain refused")
