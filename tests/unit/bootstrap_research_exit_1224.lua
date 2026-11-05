-- Read-only 1224 acceptance contract: no science from crates/ghosts,
-- no research from selection alone, and two separate real engine snapshots.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local M=require("scripts.core.bootstrap_research_exit_1224")
local function check(v,msg)assert(v,"research-exit-1224: "..msg)end
local base={
 tick=9000,
 entity_counts={["mining-drill"]=1,furnace=1,
    ["assembling-machine"]=1,lab=1},
 powered_labs=0,
 selected_research="automation",
 native_science_spm={["automation-science-pack"]=0},
 research_progress=0,research_finishes=0,
 physical_stored_inputs_ready=true,
 active_emergency_raw_tasks=0,
 native_mined_ore_per_min=0,
}
local function clone(t)
 local c={};for k,v in pairs(t)do c[k]=v end;return c
end
local stocked=M.evaluate(base)
check(stocked.physical_industry and stocked.emergency_acquisition_exit,
  "installed factory with counted stock failed safe emergency exit")
check(not stocked.physical_lab_powered and not stocked.first_science_manufactured
 and not stocked.native_research_progressed and not stocked.sustained_research,
 "stocked hardware or fixture ingredients fabricated native research")
local claimed=clone(base)
claimed.active_emergency_raw_tasks=1
local busy=M.evaluate(claimed)
check(not busy.emergency_acquisition_exit
 and busy.blocker=="physical-emergency-duty-still-active",
 "an ongoing emergency courier was silently retired")
claimed=clone(base)
claimed.entity_counts={["mining-drill"]=0,furnace=1,
  ["assembling-machine"]=1,lab=1}
check(not M.evaluate(claimed).emergency_acquisition_exit,
 "a chest with uninstalled drills became physical mining machinery")
claimed=clone(base)
claimed.physical_stored_inputs_ready=false
check(not M.evaluate(claimed).emergency_acquisition_exit,
 "no ore production and no counted input claimed operational exit")
claimed=clone(base)
claimed.native_mined_ore_per_min=2
check(M.evaluate(claimed).emergency_acquisition_exit,
 "real mined ore failed an operational-industry exit")
local started=clone(base)
started.powered_labs=1
started.research_progress=0.1
started.native_science_spm={["automation-science-pack"]=0}
check(not M.evaluate(started).native_research_progressed,
 "stocked starter science or progress alone was counted as production")
started.native_science_spm={["automation-science-pack"]=3}
local first=M.evaluate(started)
check(first.native_research_progressed and not first.sustained_research,
 "one engine snapshot falsely proved a sustained science chain")
local next=clone(started)
next.tick=18000
next.research_progress=0.24
local stable=M.evaluate(next,first)
check(stable.sustained_research
 and stable.blocker=="research-transition-proven",
 "two actual productive, progressing checkpoints failed stable research gate")
local stalled=clone(next)
stalled.tick=36000
stalled.research_progress=next.research_progress
check(not M.evaluate(stalled,stable).sustained_research,
 "repeated static checkpoint fabricated research progress")
local finished=clone(next)
finished.tick=36000
finished.selected_research="new-research"
finished.research_progress=0.01
finished.research_finishes=1
local completed=M.evaluate(finished,stable)
check(completed.sustained_research and completed.research_completed,
 "real research completion was ignored across technology switch")
local powerless=clone(finished)
powerless.powered_labs=0
check(not M.evaluate(powerless,stable).native_research_progressed,
 "unpowered lab passed research transition")
local absent=clone(finished)
absent.selected_research="none"
check(not M.evaluate(absent,stable).sustained_research,
 "no selected research passed sustained gate")
check(M.evaluate({tick=99})~=nil
 and not M.evaluate({tick=99}).research_completed,
 "empty read-only evidence fabricated production")
print("[bootstrap-research-exit-1224] PASS stocked industrial exit, active custody, actual science, power, progress and two checkpoints")
