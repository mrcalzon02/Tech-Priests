# Combat Repair 0517: Tactical Selection and 0516 Delegation

**Reviewed:** 2026-11-25. This is a source map, not native behavior or performance acceptance.
The number in this filename is retained for existing links; it is not a claim that the old implementation is still active.

Use the [complete source inventory](BEHAVIOR_SOURCE_INVENTORY.md) and its
[content hashes and source sites](BEHAVIOR_SOURCE_INVENTORY.json) for the full module/function/registration index.
Potential reachability, conditional wrappers, and retired source are distinguished there.
Source presence does not prove that a callback installed or ran in Factorio.

## Current ownership

0517 decides whether a damaged wall is safe/useful to repair under hostile pressure and reserves a local cluster. It owns tactical state and cluster bookkeeping. 0516 owns movement, packs, health application, refunds and repair order completion. No independent combat-repair timer is installed.

```mermaid
flowchart TD
    Query["0488 recommendation or 0510 service"] --> Candidate["Existing wall or bounded candidate search"]
    Candidate --> Context["Hostiles, recent damage, cover and available packs"]
    Context --> Safe{"Eligible defended damaged wall?"}
    Safe -->|"no"| None["No target or abort existing tactical task"]
    Safe -->|"yes"| Claim["Reserve tactical cluster"]
    Claim --> Repair["0516 service_pair with selected wall"]
    Repair --> Result{"Repair result and updated safety"}
    Result -->|"continue"| Context
    Result -->|"complete"| Complete["Release cluster and tactical target"]
    Result -->|"unsafe or failed"| Abort["0517 abort delegates pack cleanup to 0516"]
    Result -->|"blocked"| Blocked["Release cluster and record blocker"]
```

## Selection and state details

| Concern | Current source contract |
| --- | --- |
| Recommendation | `recommend_action` returns `combat-repair`, target, repair-pack item, tactical priority and context. It may search/evaluate candidates. |
| Search | `find_combat_repair_target`, wall eligibility, enemy/cover probes and score. |
| Nominal constants | Search radius 26, candidate limit 120, wall enemy radius 9, cover radius 8, cluster size 3, cluster TTL 150 ticks. |
| Tactical state | `combat_repair_0517`, `combat_repair_target_0517`, cluster reservation/cooldown state. |
| Physical work | `repair_executor_0516.service_pair(pair, reason, target)`. |
| Abort | Releases cluster, delegates matching target abort/refund, clears tactical state and returns to combat/idle as appropriate. |
| Completion | Checks updated missing health or repair completion result, releases cluster and publishes tactical completion. |

A loaded turret is not automatically effective cover: eligibility includes current turret/proxy state and hostile context. The diagram does not replace actual force/hostility rules.

## Performance boundary

Recommendation can run before the classifier selects another action, and wall eligibility may perform multiple enemy/cover queries. The top-level candidate count is not the full native-query count. Attribute recommendation/search cost separately from the physical pack loop. Preserve urgent combat/repair response while controlling repeated scans through existing discovery timing and caches.

Retired 0676 and 0677 wrappers must not resume independent health changes, movement or terminal cleanup. The canonical delegation above is the repair boundary.

## Fixed-rank priest armor 0302

The adjacent damage path is owned by generated 0302, independently of tactical wall repair. It selects heavy armor for junior priests, modular armor for intermediate, power armor for senior, power armor mk2 for planetary magos and mech armor for Void. If the mech item prototype is absent, the existing power-armor-mk2 fallback applies. Current recipe enablement gates the fixed rank; a higher unlocked armor does not replace that rank's armor.

| Entry | Current behavior |
| --- | --- |
| Damage event | `tech_priests_0302_mitigate_damage` refreshes the pair's fixed-rank profile, applies the existing resistance calculation and records mitigation. This remains a direct registry event response. |
| Build compatibility | `tech_priests_0297_apply_profile_to_pair` delegates to `tech_priests_0302_refresh_pair_fixed_armor` when that owner exists. Historical callable names remain available. |
| Creation, recovery, research/reset | Existing lifecycle and compatibility refresh paths continue to reach the fixed-rank owner. |
| Periodic maintenance | The existing 887-tick callback refreshes every pair; it is not an internally bounded work queue. |
| Retired periodic work | The superseded 811-tick force-wide best-armor traversal is no longer registered. |
| Explicit legacy profile helpers | 0297 retains immutable armor names, scores and resistance facts in module-local metadata. Its public force-profile helpers share 0646 recipe membership, check current enablement and publish fresh profile/resistance tables. Direct-name and light-armor compatibility, prototype order and first-wins score ties remain. These helpers do not install a replacement timer. |
| Alias recipe lookup | The direct enabled recipe remains the fast path. Otherwise 0302 uses `planning_constraints_0646.recipe_names_for_item(..., true)` and reads candidate enablement live. Legacy lookup remains only when that API is unavailable or fails. |

0646 retains immutable product membership, including disabled producers; it does not cache a same-tick armor-unlocked answer. Cold membership/armor-metadata construction and per-pair resistance reads still have costs. The [legacy metadata regression](../tests/unit/armor_profile_metadata_0297.lua) explicitly refreshes the retained helper and checks live unlocks and independent force profiles; it does not require the retired timer. The full-fragment [Lua regression](../tests/unit/fixed_rank_armor_existing_authority.lua) covers timer ownership, rank gating, same-tick alias unlock/disable and damage behavior. The [native fixture](../tests/scenarios/fixed-rank-armor/control.lua) exercises an actual damage event and save/reload on Factorio 2.1.25. These checks preserve behavior; the owner-save comparison must establish the performance effect.

## Audited exported entry points

These names are taken from the current source; local helpers and call sites are in the full inventory. A callable helper is not an independently scheduled service.

| Module | Exported functions |
| --- | --- |
| [combat_repair_doctrine_0517](../tech-priests_src/scripts/core/combat_repair_doctrine_0517.lua) | `M.root`, `M.inspect_wall_eligibility`, `M.find_combat_repair_target`, `M.active`, `M.recommend_action`, `M.abort_pair`, `M.service_pair`, `M.install` |
| [repair_executor_0516](../tech-priests_src/scripts/core/repair_executor_0516.lua) | `M.root`, `M.abort_pair`, `M.active`, `M.submit_or_assign_repair_task`, `M.service_pair`, `M.service_repair_bucket`, `M.install` |
| [generated armor compatibility](../tech-priests_src/scripts/generated/control_legacy_part_019.lua) | `tech_priests_0297_apply_profile_to_pair`, `tech_priests_0297_find_best_force_armor_profile`, `tech_priests_0297_refresh_force_armor_profile` |
| [generated fixed-rank armor](../tech-priests_src/scripts/generated/control_legacy_part_020.lua) | `tech_priests_0302_force_can_use_armor`, `tech_priests_0302_refresh_pair_fixed_armor`, `tech_priests_0302_mitigate_damage` |
| [planning_constraints_0646](../tech-priests_src/scripts/core/planning_constraints_0646.lua) | `M.recipe_names_for_item` |

## Update and evidence rule

Change the relevant diagram and ownership/exit description with the source change. Regenerate the source inventory with `python tools/audit_ups_hotspots_0743.py --write-behavior-maps`, explicitly acknowledge the reviewed curated maps with `--acknowledge-behavior-map-review`, then run `--check-behavior-maps` through the same tool. Generation alone does not bless a changed manual diagram. Follow the [performance validation protocol](UPS_VALIDATION_RUNBOOK_0742.md) for exact source, save, engine version, population, profiling settings, sample window and artifacts. A clean map check proves freshness only.
