# Force projection: first behavior review

The initial campaigns did not demonstrate autonomous expansion or combat.

## Native evidence reviewed

- Local run 43544275966 reached 36000 active ticks. Both original priests and
  stations survived. There were zero recorded build events, zero reported ore
  production/research and no cross-force damage. The rolling census was saturated
  by neutral resource entities, so it cannot establish exact building totals.
- Hosted runs 43544665741 and 43545120124 reached the one-minute smoke terminal
  samples, including real 3/5 Senior-kit starting stock in the latter. Both
  failed at saving: the private write-data `saves` directory did not exist.
- Native saved-state inspection found the same automatic firearm-magazine
  incumbent on both priests. Ingredient fanout repeatedly requested iron plates,
  but the queue/retention owner refused activation. The fanout caller still
  reported success and advanced the operation label. One station also retained
  a smelter request waiting for four stone. No physical material completion was
  demonstrated by those planning records.

## Changes in this increment

1. Create isolated saves/script-output directories before starting Factorio.
2. Filter the rolling census to participating forces BEFORE its entity limit.
3. Self-fanout requires accepted, actually active exact-task ownership before
   launching acquisition or claiming assignment progress. Rejected or queued
   work reports an explicit refusal. The incumbent is not cancelled by fanout.
   The existing caller decides how to handle the returned refusal.
4. Samples now expose the actual dispatcher, recipe missing item, gate, order,
   fanout refusal, movement ownership and source-fetch target. No new periodic
   scanner or mutation of physical custody is introduced.

## Verification and limits

The executable production-function regression covers rejection, queue-only
acceptance, active exact-task acceptance and legacy no-queue compatibility.
All five layout mocks and the telemetry parser regressions passed.

A fresh native Factorio 2.1.24 private-server check completed setup and 3600
active ticks, passed the combined-process verifier and wrote a CRC-verified
final save. Its evidence summary is
`docs/benchmarks/force-projection-save-and-fanout-review.json`.
It deliberately used a disposable speed=20 override to validate functionality;
it is NOT a normal-speed performance measurement or an endurance result.
The native probe used the working tree and records hashes of the changed
runtime files; do not relabel its base Git HEAD as a fully tested release SHA.

The probe still recorded zero construction, mining and research, with the
3/5 Senior kits unspent and no combat contact. The new refusal fields now
confirm the ownership conflict. The existing fallback reaches a known-source
logistics fetch on one priest, but actual movement/pickup/deposit is not yet
proven. Full dependency-aware parent/ingredient scheduling and physical fetch
completion remain OPEN. No battle outcome can be assessed before expansion
and contact occur. Run the corrected normal-speed campaigns next; retain
no-progress observations rather than injecting successful construction.

## November 19, 2026 — bounded native observability continuation

The earlier [hosted 3-seed run](https://github.com/mrcalzon02/Tech-Priests/actions/runs/43547358217)
observed one full 36,000-active-tick seed (`534526259`) with no native
construction, mining, research, or cross-force contact. The next seed
(`534526260`) failed during original Magos/priest pairing at setup tick
26,520. This is **a native fixture failure, not a combat verdict**. Neither
source test success nor a successful final ZIP proves autonomous growth.

Changes after that evidence:
- The fixture emits `PAIR_FAILURE` with bounded native spawn-search, legal
  east-side placement, station identity, and pair-record diagnostics before
  preserving the original hard failure. It does not create a substitute priest.
- The Python driver accepts completed native lines incrementally instead of
  rebuilding/searching an ever-growing in-memory engine log every second.
  The complete original `native-server.log` remains authoritative; fragmented
  log lines cannot fire partial success/failure markers.
- On a native pairing refusal the driver emits and retains the original
  `PAIR_FAILURE` receipt in `result.json`, fails closed, and cannot
  classify an artificial terminal `COMPLETE` as a pass.
- The evidence parser now requires per-force native build, ore-input-stat,
  research, damage, survival, station and Senior-kit readbacks at the exact
  terminal tick. Malformed/duplicated/foreign combat contacts are rejected.
- `observed_progress` adds *diagnostic* sums and distinguishes hostile-team
  contact from generic cross-force damage; this is not physical material
  delivery, technology research output, territorial victory or method I/II/III
  acceptance.
- The approved Dens-Mortis Core30 worker now writes low-frequency arena
  phase/completed-preset milestones into its existing heartbeat. No new job,
  scheduled trigger, privileged runner action, or synthetic game progress.

The first native replay, [Core30 #44605124898](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/44605124898),
used the previous source `cfa32551`, and the separately submitted
[pair-failure diagnostic #44607157618](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/44607157618)
was pinned to `9f4dc2eb`. Both must be judged from **their own** workflow/job
receipts, not retroactively credited with later source improvements.

**Next native gates:** reproduce the exact pairing refusal with recorded
collision/spawn checks; verify all final sample counters on a corrected
full native observation; then isolate physical material acquisition and actual
Senior kit deployment before longer combat/endurance campaigns. A heartbeat
alone is not progress, and an observation-only PASS is not a resource/combat
PASS.
