-- Factorio 2.1 fluidbox removal: test EXACT native Void-Fusion service code.
local file=assert(io.open("tech-priests_src/scripts/generated/control_legacy_part_002.lua","rb"))
local source=file:read("*a"); file:close()
local start=assert(source:find("function fill_void_fusion_thruster_fluidbox(",1,true))
local finish=assert(source:find("\nfunction service_void_fusion_thrusters()",start,true))
local selected=source:sub(start,finish-1)
local env={pcall=pcall,type=type,VOID_FUSION_THRUSTER_FILL_AMOUNT=80}
setmetatable(env,{__index=_G})
local fn=assert(load(selected.."\nreturn fill_void_fusion_thruster_fluidbox",
  "native-fluid-1278","t",env))()
local accepted=0
local modern={valid=true,set_fluid=function(index,fluid)
  assert(index==2 and fluid.name=="reaction-fluid"
    and fluid.amount==80 and fluid.temperature==15)
  accepted=accepted+1
  return 80
end}
assert(fn(modern,2,"reaction-fluid") and accepted==1,
  "2.1 native fluid amount was not observed")
modern.set_fluid=function()return 0 end
assert(fn(modern,2,"reaction-fluid")==false,
  "2.1 rejected native fluid transfer was claimed successful")
local old={valid=true,fluidbox={}}
assert(fn(old,1,"charge-fluid")==true
 and old.fluidbox[1].name=="charge-fluid"
 and old.fluidbox[1].amount==80,
 "2.0 LuaFluidBox fallback lost")
assert(fn(old,nil,"charge-fluid")==false
 and fn(old,1,nil)==false, "invalid native fluid arguments not refused")
assert(fn({valid=true},1,"charge-fluid")==false,
 "missing native fluid mechanism reported success")
print("[native-thruster-fluid-1278] PASS native 2.1 fluid amount/refusal and 2.0 fluidbox")
