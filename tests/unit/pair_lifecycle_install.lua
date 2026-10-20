-- Standalone Lua 5.2+ regression, from repository root:
-- lua tests/unit/pair_lifecycle_install.lua
local source=(arg and arg[1]) or "tech-priests_src/scripts/core/pair_lifecycle.lua"
local spawn_key="scripts.core.pair_spawn_positions"
local naming_key="scripts.core.pair_naming"
local function scenario(spawn,naming)
  package.loaded[spawn_key]=nil
  package.loaded[naming_key]=nil
  package.preload[spawn_key]=function() return spawn end
  package.preload[naming_key]=function() return naming end
  _G.TechPriestsPairLifecycle=nil
  return dofile(source)
end
local function uninstalled(m)
  assert(m.installed==false)
  assert(_G.TechPriestsPairLifecycle==nil)
end
local m=scenario({install=function() return true end},{install=function() return true end})
assert(m.install()==true and m.installed==true)
assert(_G.TechPriestsPairLifecycle==m)
assert(m.install()==true)

m=scenario({install=function() return false end},{install=function() return true end})
assert(m.install()==false)
uninstalled(m)

m=scenario({install=function() error("spawn initialization failed") end},{install=function() return true end})
assert(m.install()==false)
uninstalled(m)

m=scenario({install=function() return true end},{install=function() return nil end})
assert(m.install()==false)
uninstalled(m)

m=scenario({install=function() return true end},{install=function() error("naming failed") end})
assert(m.install()==false)
uninstalled(m)

m=scenario({}, {install=function() return true end})
assert(m.install()==false)
uninstalled(m)

-- An earlier failure must not permanently poison installation state.
local naming={install=function() return false end}
m=scenario({install=function() return true end},naming)
assert(m.install()==false)
uninstalled(m)
naming.install=function() return true end
assert(m.install()==true and m.installed==true)
assert(_G.TechPriestsPairLifecycle==m)

-- Only the canonical 0499 authority may initiate re-imprint.
local old_authority=rawget(_G,"TechPriestsPriestLifecycleAuthority0499")
local old_legacy=rawget(_G,"tech_priests_0298_enter_reimprint")
local legacy_calls=0
_G.tech_priests_0298_enter_reimprint=function()
  legacy_calls=legacy_calls+1
  return true
end
_G.TechPriestsPriestLifecycleAuthority0499=nil
assert(m.enter_reimprint({},{},"missing-authority")==false)
assert(legacy_calls==0)

local pair,priest={},{}
local received
_G.TechPriestsPriestLifecycleAuthority0499={
  begin_reimprint=function(p,e,reason)
    received={p,e,reason}
    return true
  end
}
assert(m.enter_reimprint(pair,priest,"canonical")==true)
assert(received[1]==pair and received[2]==priest and received[3]=="canonical")
_G.TechPriestsPriestLifecycleAuthority0499.begin_reimprint=function()
  return 1
end
assert(m.enter_reimprint(pair,priest)==false)
_G.TechPriestsPriestLifecycleAuthority0499.begin_reimprint=function()
  error("canonical failure")
end
assert(m.enter_reimprint(pair,priest)==false)
assert(legacy_calls==0)
_G.TechPriestsPriestLifecycleAuthority0499=old_authority
_G.tech_priests_0298_enter_reimprint=old_legacy

print("PASS pair lifecycle installation integrity")
