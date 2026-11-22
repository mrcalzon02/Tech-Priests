-- Regression: isolated quality firing must run on the canonical broker even
-- with no Cogitator station, and must stop waking once it has a terminal result.
-- This exercises the real fixture install contract, not simulated gunfire.
local KEY="ci_quality_turret_firing"
storage={tech_priests={}}
local registered,init_handler=nil,nil
_G.TechPriestsRuntimeEventRegistry={
  on_init=function(fn,options)
    assert(type(fn)=="function" and options.owner==KEY)
    init_handler=fn
    return true
  end
}
_G.TechPriestsRuntimeTickBroker0600={
  register_service=function(spec)
    registered=spec
    return spec
  end
}
log=function()end
local M=dofile("tests/scenarios/quality-turret-fire/fixture.lua")
assert(M.install()==true and type(init_handler)=="function")
assert(registered and registered.name==KEY and registered.category=="diagnostics")
assert(registered.run_while_dormant==true,
  "native gunfire observer is asleep in a stationless fixture")
assert(type(registered.dormant_active)=="function",
  "broker has no bounded dormant-work predicate")
assert(registered.dormant_active()==false,
  "observer woke before initialization")
storage.tech_priests[KEY]={started=0}
assert(registered.dormant_active()==true,
  "observer did not wake with a pending native test")
storage.tech_priests[KEY].passed=true
assert(registered.dormant_active()==false,
  "observer remained awake after successful native receipt")
storage.tech_priests[KEY]={started=0,failed="native error"}
assert(registered.dormant_active()==false,
  "observer remained awake after terminal failure")
print("[quality-turret-dormant-service] PASS canonical bounded wake/stop only")
