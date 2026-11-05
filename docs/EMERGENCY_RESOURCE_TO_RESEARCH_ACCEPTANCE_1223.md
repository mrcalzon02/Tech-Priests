# Emergency resources → physical infrastructure → continuous research

## Scope and authorities

Applies to all Cogitator ranks. The authoritative source is the real Factorio
force/surface inventory, machinery, technology, and production ledger. The
0644 central planner surveys the full local supply inventory; 0640 gives
pre-stocked *placeable* standard machinery priority over primitive 0647
ingredient requests. The existing 0338 physical builder still finds the real
source, walks there, removes exactly one item, and constructs at a legal site.
The 0513 miner still mines and deposits ore physically. Neither planning nor
CI diagnostics may create items, research, power, roles, or progress.

### Decision priority for each missing infrastructure role

1. **Built and usable:** the same-force machine already exists in the
   station's authorized working area. Do not build a duplicate.
2. **Finished machine in local generic storage:** verify that the item has a
   real `place_result` and is counted through 0686 force/surface-bound generic
   containers. Request ordinary 0338 installation. Never hand-mine iron to
   manufacture an emergency substitute while a compatible standard kit waits.
3. **Standard recipe ingredients available:** pursue its researched/enabled
   real machine recipe and ingredient delivery. Do not declare the kit already
   installed or create synthetic inventory credit.
4. **Real ingredient gap:** descend the actual enabled recipe dependency graph,
   consume stocked intermediates first, seek remaining ore/fuel through physical
   0513 acquisition. A cheaper emergency machine is appropriate only when no
   usable kit or immediately constructible standard route exists.
5. **No viable source/research/site:** stay blocked with a named, observable
   reason. Never promote a ghost, a planned recipe, or a distant/foreign chest
   into real available equipment.

An electric drill in a crate is **installable stock**, not proof of a powered
or producing miner. Likewise, a built lab with zero energy is not research
readiness. The placement, power, machine-feed, and runtime checks are separate.

### Emergency acquisition acceptance / exit

The acquisition phase is justified only by an observed missing physical
resource after checking the above local sources and currently committed duties.
The physical exit diagnostic requires a built mining/smelting/assembling spine,
no outstanding raw courier duties, **and** either actual native mined ore
output or counted physical raw/intermediate input supply. It is a milestone,
not permission to erase an in-flight movement or carried item.

Negative regressions: a stocked drill/furnace must prevent needless emergency
craft; recipes with real stocked ingredients must not schedule speculative raw
reserves; absent hardware must retain the emergency fallback; equipment in
foreign, remote, or different-surface containers must not count; an
unfinished physical transfer cannot be silently retired.

### Research acceptance / exit

Research transitions have intentionally different gates:

| Gate | Required independent engine observations |
|---|---|
| 1. Industrial spine | Actual built mining, furnace and assembler entities; storage alone does not pass |
| 2. Lab powered | Real lab with positive energy or burning fuel; a ghost or unpowered lab does not pass |
| 3. Research selected | A real, eligible force technology is currently selected; does not itself claim production |
| 4. Science manufactured | Real Factorio force/surface per-minute input production statistic > 0 for a science pack; stocked packs are not production |
| 5. Research progressing | Positive native research progress or a registered genuine research completion |
| 6. Research sustained | Two **different** engine checkpoints show native science production and powered labs, with research progress increasing or a real technology completing |
| 7. Milestone completed | An `on_research_finished` callback confirms actual completion; it does not imply target SPM |
| 8. Full midgame factory | At least 5 native SPM **each** for automation, logistic, and military science at the final checkpoint, plus genuine research completion |

The pure observer `bootstrap_research_exit_1224.lua` produces separate booleans
for industrial exit, research entry, sustained research, and completion. It
changes no production state, force research, inventory or work orders. The
midgame engine checkpoint includes its evidence and prints
`BOOTSTRAP_RESEARCH_GATE`, plus the physical starter hardware still stocked
near each rank. A successful scenario/checkpoint artifact with zero SPM remains
**factory-objective-unmet**; source tests alone cannot satisfy these gates.

### Test matrix and evidence

- `tests/unit/stocked_equipment_priority_1223.lua`: same-force real stocked
  furnace and drill priority, no emergency craft, remote/foreign container
  rejection, empty-stock emergency fallback, ingredient-complete standard
  route, and electric-drill installable-vs-operational distinction.
- `tests/unit/bootstrap_research_exit_1224.lua`: active emergency duty
  protection, never treating crates/ghosts as machines, mine-or-stock exit,
  unpowered lab refusal, native output requirement, progress across two
  checkpoints, completed research, and stalled-progress refusal.
- Existing `tests/unit/construction_distinct_inventory_sources_1200.lua`:
  distinct real chest pickup and exact real item debit.
- Existing `tests/unit/master_infrastructure_bootstrap_assistance.lua`:
  first-plate scarcity, standard upgrade and physically stocked science.
- Existing `midgame-science` Factorio 2.0.77 scenario: genuine engine-placed
  equipment, production counters, selected research and completion callbacks,
  stocked-equipment diagnostics, and two-checkpoint research exit contract.
- Existing `factorio-runtime-tests` and `stocked-coverage` workflows retain
  save/reload custody, rank expansion and counted physical construction proof.

**Acceptance rule:** no emergency/research milestone is complete until a native
engine run presents the relevant measured evidence. Do not promote a passing
unit test, artifact upload or a visual schematic into in-game research output.
Preserve the user's release-gate policy: missing SPM or incomplete strategic
coverage is a documented development diagnostic, not a build/launch blocker.
