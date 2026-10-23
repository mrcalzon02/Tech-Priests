-- Factorio 2.0: enemy commands are LuaCommandable methods, not LuaEntity.
local M=dofile("tests/scenarios/all-ground-ranks/ground_rank_harness.lua")
assert(type(M.test_command_biter_attack)=="function",
  "CI combat harness does not expose actual biter attack command")
defines={command={attack=17},distraction={by_enemy=2,none=0}}
local station={valid=true,name="planetary-magos-cogitator-station"}
local selected=nil
local called=0
local commandable={valid=true,set_command=function(cmd)
  called=called+1;selected=cmd
end}
local biter={valid=true,name="small-biter",commandable=commandable,
  set_command=function()error("removed LuaEntity.set_command invoked")end}
M.test_command_biter_attack(biter,station)
assert(called==1 and selected.type==defines.command.attack
  and selected.target==station
  and selected.distraction==defines.distraction.none,
  "Factorio 2.x commandable did not receive station-targeted hostile attack")
local ok,err=pcall(M.test_command_biter_attack,
  {valid=true,name="small-biter"},station)
assert(not ok and tostring(err):find("COMBAT_SPAWNED_UNIT_NOT_COMMANDABLE",1,true),
  "missing LuaCommandable must fail closed, not mark a simulated attack")
print("[combat-biter-command-2x] PASS engine-owned LuaCommandable targeting")
