-- Regression 1489 / Claude T2-01: a truthful Auspex cache hit rate
-- counts every known miss reason, not just dirty/unknown cells.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={}}
game={tick=1}
local M=require("scripts.core.efficiency_economy_0579")
local initial=M.cache_effectiveness()
assert(initial.hits==0 and initial.misses==0 and initial.total==0
  and initial.hit_percent==nil,
  "idle save must report unmeasured cache efficiency")
local stats=M.root().stats
stats.area_index_hits=4
stats.area_index_miss_no_surface=1
stats.area_index_miss_dirty_or_unknown=3
stats.area_index_miss_cell_budget=1
stats.area_index_miss_result_cap=1
stats.partial_cells_not_certified=12
stats.uncertified_observations_preserved=7
local e=M.cache_effectiveness()
assert(e.hits==4 and e.misses==6 and e.total==10 and e.hit_percent==40,
  "hit percentage excluded a miss path")
assert(e.no_surface==1 and e.unknown==3 and e.cell_budget==1
  and e.result_cap==1 and e.partial_cells==12 and e.observed_only==7,
  "a diagnostic category was lost")
stats.area_index_hits=0
e=M.cache_effectiveness()
assert(e.hit_percent==0 and e.total==6,
  "zero-hit cache should report 0 percent rather than unmeasured")
stats.area_index_hits=6
stats.area_index_miss_no_surface=0
stats.area_index_miss_dirty_or_unknown=0
stats.area_index_miss_cell_budget=0
stats.area_index_miss_result_cap=0
e=M.cache_effectiveness()
assert(e.hit_percent==100 and e.total==6,
  "all-hit cache should report 100 percent")
print("[spatial-cache-effectiveness-1489] PASS")
