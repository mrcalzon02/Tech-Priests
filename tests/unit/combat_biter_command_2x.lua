-- Factorio 2.0: enemy commands are LuaCommandable methods, not LuaEntity.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
-- Load the same late-combat native observer without executing an engine run.
_G.TP_CI_LATE_COMBAT=true
local M=dofile("tests/scenarios/all-ground-ranks/ground_rank_harness.lua")
_G.TP_CI_LATE_COMBAT=nil
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
-- 1128 regression: third-wave native entity-death fanout used to return
-- before counting the dead biter. Every physically observed tracked death
-- counts exactly once; only a FRIENDLY TURRET kill is defense engagement.
assert(type(M.test_combat_biter_died)=="function",
  "native combat fixture death observer not exported for regression")
local friendly={name="player"}
local hostile={name="enemy"}
game={tick=123456,forces={player=friendly}}
storage={tech_priests={ci_ground_rank_test={combat_sites={
  ["planetary-magos-cogitator-station"]={
    escalation_units_1092={991,992},
    physical_attack_target_units={},
    created_biter_units={},reassault_units={}
  }
}}}}
local logs={}
log=function(message) logs[#logs+1]=message end
local audit=storage.tech_priests.ci_ground_rank_test.combat_sites
  ["planetary-magos-cogitator-station"]
M.test_combat_biter_died({entity={unit_number=991},
  cause={valid=true,name="gun-turret",force=friendly}})
assert(audit.escalation_enemy_deaths_1092==1
  and audit.escalation_engagements_1092==1
  and audit.escalation_dead_units_1128[991]==true,
  "real gun-turret kill not counted as one physical enemy death")
M.test_combat_biter_died({entity={unit_number=991},
  cause={valid=true,name="gun-turret",force=friendly}})
assert(audit.escalation_enemy_deaths_1092==1
  and audit.escalation_engagements_1092==1,
  "duplicate native entity-death event counted twice")
M.test_combat_biter_died({entity={unit_number=992},
  cause={valid=true,name="small-biter",force=hostile}})
assert(audit.escalation_enemy_deaths_1092==2
  and audit.escalation_engagements_1092==1
  and audit.escalation_dead_units_1128[992]==true,
  "genuine enemy death wrongly requires a friendly turret attacker")
M.test_combat_biter_died({entity={unit_number=993},
  cause={valid=true,name="gun-turret",force=friendly}})
assert(audit.escalation_enemy_deaths_1092==2
  and audit.escalation_engagements_1092==1,
  "untracked biter kill contaminated actual escalation counts")
print("[combat-biter-command-2x] PASS engine-owned attack commands and non-duplicated native escalation death accounting")
