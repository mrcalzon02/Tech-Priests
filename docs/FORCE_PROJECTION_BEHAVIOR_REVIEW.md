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
