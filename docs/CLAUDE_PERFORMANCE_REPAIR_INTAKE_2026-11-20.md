# Claude performance/leak repair audit — tracked intake

**Source:** User-provided 10-page Claude static review of `mrcalzon02/Tech-Priests`, originally inspected at `b44d183` (2026-11-20 00:07 UTC).  
**Status:** Source fixes and diagnostic instrumentation only. No native UPS win, save-size improvement, or release authorization is established by this checklist.  
**Authority:** `RECOVERY_REPAIR_SEQUENCE.md`, `docs/RECOVERY_RUNTIME_EVIDENCE.md`, and `tech-priests_src/docs/CURRENT_TESTING_GOALS.md` still control Stage 5.

## Already repaired before intake — do not repeat

- `0594`/`0598`: per-route callback pulse fairness, no stacked throttling, cached pair load.
- `0599`: shared registry wake hooks, stale sleep/dirty cleanup.
- Event registry: profile-key and primitive/filter hot paths.
- Broker: reporting-window rotation.
- `0579`: derived index reseed, incomplete scan fail-closed, ten-second cache age, cell bounds.

These are **source implementation claims**, not proof of native performance.

## Claude item register

| ID | Topic | Current status / gate |
| --- | --- | --- |
| T1-01 | 0594 reclassifies routes per pulse | Open; cache route identity/class once, validate settings refresh |
| T1-02 | 0599 sleep observation costs | Open; preserve visible and damage wake latency |
| T1-03 | 0595 prototype-name string tests | **Source fixed** `98629c9`; regression `1487`; native validation pending |
| T1-04 | Work-queue duplicate submissions invalidate no-work caches | **Source fixed** `11f7985`: suppress generation bumps on unchanged repeats; preserve new/priority/expired wakes. Policy regression `1490` passed locally; integration fixture `1490` pending |
| T1-05 | Reservation target-key work | Open; optimize after key stability review |
| T1-06 | Scan-routing negative-cache retention | **Source fixed** `7fedb01`; regression `1488`; native save-size validation pending. The cached scan already honored `filters.limit` on the audited head; do not redo that subclaim |
| T1-07 | Chunk seeding map settings copy per event | Open |
| T1-08 | Station catalog per-entity inventory, wire and tag work | **Partial source fix** `a70250d`: settings per sweep, connector IDs reused, non-inventory wire checks skipped, distance per inventory source cached; legacy tag cleanup retained. Fixture `1493` committed; full/native behavior pending. Dynamic wired connectivity is never TTL-cached |
| T1-09 | Broker telemetry formatting and budgeting | Open; benchmark on 80+ pairs first |
| T1-10 | 0579 expanded-cache comparator key regeneration | Open; optimize only if T2-01 hit data justifies it |
| T1-11 | Dispatcher per-priest record churn | Open; preserve action reporting and custody evidence |
| T1-12 | 0582 active-order and reason helper allocations | **Partial source fix** `81bc0f1`: hoisted active field list and 128-entry bounded reason memo; policy regression `1492` passed locally; other helper costs/UPS pending |
| T2-01 | Nonaligned station scans may miss 0579 cache indefinitely | **Counters enhanced** `0a8f06b`; regression `1489`; native hit-rate baseline needed before geometry change |
| T2-02 | 0582 globally invalidates every priest on ordinary world events | **Stage 1 source fix** `98e2189`: epoch-based lazy invalidation eliminates whole-table allocation/history churn; pure regression `1491` passed locally, integration `1491` pending. Still globally wakes all priests logically; localized work needed |
| T2-03 | Catalog prune/cleanup scans all owned-resource keys | Open; retain per-owner lookup and slow rotating prune |
| T2-04 | Uncertified scans dirty fully known 0579 cells | **Source fixed** `0ec9fca`; regression `1486`; native validation pending |
| T2-05 | Narrow filtered query loops all cached entities | Open; direct-vs-cache comparison needed |
| T2-06 | Repair discovery stops after first 32 entities | Open; preserve discovery coverage, audit event feeder |
| T2-07 | Overlapping 0582/0599 idle/sleep authorities | Open; architectural change requires behavior-equivalence tests |
| T2-08 | Pair-bucket limited iteration fairness and repeated normalization | Open; verify actual limited-bucket callers before cursor change |
| T2-09 | Catalog duplicate owned keys and per-scan subordinate O(P²) work | Open; migrate persisted ownership carefully |
| T2-10 | Dispatcher rail branch duplication and roster scans | Open; lifecycle-version API needed before replacing live checks |
| T3-01 | Consolidate 22 economy shims | Deferred until native baseline and Tier 1/2 validation |
| T3-02 | Make tick_pair/dispatcher wrapper order explicit | Deferred; high behavior risk |
| T3-03 | Move rebuildable derived tables out of persisted storage | Deferred; compare save size/load time and migration |
| T3-04 | Unify multiple spatial dirty indexes | Deferred; requires shared event ownership |
| T3-05 | Retire generated legacy paths/stubs | Deferred; prove call reachability and test before deletion |
| T3-06 | Remove persisted pair-level diagnostics | Deferred; preserve recovery evidence |

## Measurements required before claiming a performance win

1. Pin one exact `main` SHA and use a populated save with **at least 80 priest pairs**. Run `/tp-runtime-report` and the status commands for `-0579`, `-0582`, `-0598`, and `-0599`. Enable the existing broker/registry profiler and retain per-service time, UPS and scan counters.
2. In `/tp-efficiency-economy-0579 status`, capture `hits`, **total** `misses`, `hit-pct`, `partial-cells`, `capped`, `observations-preserved`, and the miss-reason counters. Determine whether nonaligned stations actually achieve cache hits; do not assume improvement.
3. Capture counts of `negative_until`, `dirty_cells`, `owned_resources`, `windows` and `r.pair`, plus save-byte size, at start and after **two hours of game time**.
4. After each individual fix, run `python tests/run_hotpath_regressions.py --all` from a full checkout, compare the same profilers and counters, and retain the before/after source SHAs. Manual-only self-hosted workflow: `.github/workflows/manual-hotpath-lua.yml`.
5. An index/caching acceptance test must demonstrate an identical second query can hit **and** an in-area build, mine or death causes a miss. For idle-cache changes, prove active orders, repair, combat, manual control and visible nearby work are never suppressed.

## Next recommended execution order

1. **Evidence:** T2-01 real hit/miss baseline; T1-06 save growth baseline.
2. **High-value scheduling:** T2-02 together with T1-12, test active-work wake latency.
3. **Catalog overhead:** T1-08 with T2-03, including per-scan profiler results.
4. **Per-priest hot paths:** T1-02, T1-04, T1-05 and T1-11, one bounded commit at a time.
5. Then remaining Tier 1, remaining Tier 2, and Tier 3 after profiler/compatibility evidence.

**Release gate:** The 0.1.672 packaged baseline remains protected. These static fixes and Lua fixtures are not native Factorio acceptance.
