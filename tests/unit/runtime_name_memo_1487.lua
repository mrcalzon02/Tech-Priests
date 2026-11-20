-- Regression 1487 / Claude T1-03: 0595 keeps identical wake behavior
-- over repeated prototype names without putting lookup tables in storage.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={}}
game={tick=10}
local M=require("scripts.core.efficiency_economy_0595")
local cases={
 {"void-fusion-thruster",true},
 {"large-void-fusion-thruster",true},
 {"small-cogitator-station",true},
 {"tech-priests-plasma-reactor",true},
 {"tech-priest-proxy-turret",true},
 {"conclave-center",true},
 {"martian-micro-assembler",true},
 {"machine-spirit-node",true},
 {"transport-belt",false},
 {"spidertron",false},
 {"enemy-biter-spawner",false},
 {"logistic-robot",false},
 {"iron-ore",false},
 {"",false},
}
local matched=0
for iteration=1,200 do
  game.tick=iteration
  for _,case in ipairs(cases)do
    local result=M.mark_event({entity={valid=true,name=case[1]}},"fixture")
    assert((result==true)==case[2],
      "prototype name classification changed: "..case[1])
    if case[2] then matched=matched+1 end
  end
end
assert(M.mark_event({entity={valid=false,name="cogitator-station"}})==false,
  "invalid entity unexpectedly activated dormant gate")
local state=storage.tech_priests.efficiency_economy_0595
assert(state.active and state.stats.awaken==matched,
  "memoized classification altered dormant awaken count")
assert(state.next_probe==200+60*30,
  "memoized name classification changed wake probe deadline")
assert(state.is_runtime_name==nil,
  "derived name memo leaked into persisted storage")
print("[runtime-name-memo-1487] PASS: cached known and unrelated names")
