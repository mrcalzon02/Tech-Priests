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

print("PASS pair lifecycle installation integrity")
