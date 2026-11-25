# Consecration Executor 0515, Target Eligibility and Refund Custody

**Reviewed:** 2026-11-25. This is a source map, not native behavior or performance acceptance.
The number in this filename is retained for existing links; it is not a claim that the old implementation is still active.

Use the [complete source inventory](BEHAVIOR_SOURCE_INVENTORY.md) and its
[content hashes and source sites](BEHAVIOR_SOURCE_INVENTORY.json) for the full module/function/registration index.
Potential reachability, conditional wrappers, and retired source are distinguished there.
Source presence does not prove that a callback installed or ran in Factorio.

## Eligibility and ownership

0515 executes an accepted active consecration order. Shared `work_reservations` owns the `sanctify` claim; the old private claim ledger is reconciled/retired by `M.root`. `work_queue_authority` supplies shared candidate admission. Neither a stale target field nor a diagnostic request authorizes a new rite.

The target predicate is [consecration/registry.lua](../tech-priests_src/scripts/core/consecration/registry.lua). It excludes `unit`, `character`, the complete combat roster and its AAI composite forms **before** vehicle/name allowlists. Native car bodies used for infantry do not make those actors consecratable machines. Existing invalid records are removed through the registry's reconciliation path, including owned rendering/status cleanup.

```mermaid
flowchart TD
    Entry["0515 service_pair"] --> Refund{"Refund custody exists?"}
    Refund -->|"yes"| Return["Retry counted refund after backoff"]
    Return -->|"refused"| Hold["Retain custody and release work claim"]
    Return -->|"accepted"| Terminal["Finish original order terminal handoff"]
    Refund -->|"no"| Order["Require same active consecration order"]
    Order --> Target["Ordered target or shared discovered candidate"]
    Target --> Eligible["Machine predicate, force, range, stock and cooldown"]
    Eligible --> Claim["Shared sanctify reservation"]
    Claim --> Travel["0418 movement and physical reach"]
    Travel --> Rite["90-tick rite preparation"]
    Rite --> Consume["Remove one actual rite item"]
    Consume --> Apply["Apply to the same valid machine"]
    Apply -->|"failed"| Return
    Apply -->|"accepted"| Cooldown["Pair and target cooldown"]
    Cooldown --> Terminal
    Order -->|"changed or invalid"| Cleanup["Release claim, clear timer or await own terminal"]
```

## Function and state contract

| Concern | Current behavior |
| --- | --- |
| Target identity | Order key and original ordered target are retained; invalid ordered target fails instead of silently substituting another machine. |
| Reservation | Shared `sanctify` category, exact owner and target key; private shadow claims are retired. |
| Movement | Requires literal accepted 0418 request; outside physical reach resets preparation timer. |
| Timing | 90-tick service, 45-tick pair cooldown, 480-tick target cooldown. |
| Supply/refund retry | Missing item and refund retries use 300-tick backoff. |
| Custody | `consecration_refund_custody_0515` retains a removed item when application/refund cannot finish. |
| Terminal | `on_order_released` and executor `terminal` keep matching-order cleanup; cannot complete an unrelated preempting order. |
| Submission | `submit_or_assign_consecration_task` creates/adopts an accepted order and releases provisional claims on refusal. |

## Discovery cost and limits

`find_target` prefers an explicit ordered target. Otherwise it uses scan routing or a direct native query and then examines up to `max_candidates=96`. **The direct query has no native `limit` field in this path**; the Lua loop cap does not prevent the engine from returning a larger list. Record query size and cache behavior before claiming discovery is bounded to 96 entities.

No separate periodic executor is installed by 0515. Legacy scheduler/rite adapters call the queue/executor through existing entry points. Native target exclusion, old-save cleanup and refund/terminal scenarios require their own evidence; a map change proves none of those at runtime.

## Audited exported entry points

These names are taken from the current source; local helpers and call sites are in the full inventory. A callable helper is not an independently scheduled service.

| Module | Exported functions |
| --- | --- |
| [consecration_executor_0515](../tech-priests_src/scripts/core/consecration_executor_0515.lua) | `M.root`, `M.on_order_released`, `M.active`, `M.service_pair`, `M.submit_or_assign_consecration_task`, `M.install` |
| [consecration/registry](../tech-priests_src/scripts/core/consecration/registry.lua) |  |
| [work_reservations](../tech-priests_src/scripts/core/work_reservations.lua) | `M.target_key`, `M.pair_id`, `M.root`, `M.get`, `M.is_claimed`, `M.is_claimed_key`, `M.claim`, `M.release_key`, `M.release`, `M.cleanup_expired`, `M.count`, `M.report_lines`, `M.install` |

## Update and evidence rule

Change the relevant diagram and ownership/exit description with the source change. Regenerate the source inventory with `python tools/audit_ups_hotspots_0743.py --write-behavior-maps`, explicitly acknowledge the reviewed curated maps with `--acknowledge-behavior-map-review`, then run `--check-behavior-maps` through the same tool. Generation alone does not bless a changed manual diagram. Follow the [performance validation protocol](UPS_VALIDATION_RUNBOOK_0742.md) for exact source, save, engine version, population, profiling settings, sample window and artifacts. A clean map check proves freshness only.
