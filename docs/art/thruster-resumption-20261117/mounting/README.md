# Fore-supported engines over the ship edge

**Current follow-on:** the [lowered-frame and surrounding-ledge receipt](LOW_FRAME_NATIVE.md)
supersedes the earlier narrow single-column mounting layout. Its portable native
proof is in `low-frame-native/`; the earlier `native/` artifacts remain preserved.

The owner requires roughly half of each fusion engine's physical structure to
hang off the back of the ship. The former five narrow soles and four wide feet
around the whole body were an incorrect modeling assumption. The refined models
use fore-only anchors and actual cantilever load paths. Their review deck exists
only at source Y>=0, top Z=0; -Y is open aft space. Aft saddles sit on the engine
frame, with no hidden foundation or rear legs.

This is measured against the **physical axial envelope**, not a claim about mesh
volume, mass, screen pixels or nominal prototype tile count. Current model
checkpoints bind their exact proportions and contacts. Deck-edge, side and
underside views must make the overhang visible.

## Native placement correction

`thruster-mounting-visuals.lua` previously required foundation under the sealed
engines' full nominal bodies. It now requires a supported fore region and clear
aft space, with fore-only collision boxes. The fixed north direction, nominal
1x9/4x4 grids, hidden fluid policy and native performance are preserved.

Actual Factorio 2.1.24 probes show that the entity origin must retain foundation.
The legal cuts are native local Y=+0.5 for the odd 1x9 origin and +1 for the even
4x4 origin. Both final ordinary sites have last foundation row 0 and empty aft
rows beginning at 1. Exact-center cuts were tested and rejected by the engine.

The authored model's source edge **Y=0 must be registered to these legal native
cuts** using the measured final sprite camera/shift. Five supported nominal rows
on the narrow grid or three on the wide grid do not mean that proportion of the
actual visible structure sits on the ship. Neither an assumed 1:1 source/tile
mapping nor a full foundation hidden behind the art is an acceptable substitute.
That final new-art registration remains an explicit integration gate.

## Actual operation and reload

The [native receipt](native/mounting-validation-summary.json) verifies all four
ordinary drives on legal edge sites. Both fusion drives retain independent
50–150% power/feed cycles, power-loss refusal, buffer drain, restart and hidden
sink repair. A real tick-1500 engine autosave was reloaded by a separate process;
the entire tick-1560 result exactly equals uninterrupted execution. The private
loopback server was stopped and no normal profile/save was changed.

The frozen input set has 5,437 files plus the exact recorded mounting-module
update. Eight current runtime/prototype files match the tested hashes. The prior
full-nominal-body test remains historical evidence in `../native/`; this receipt
supersedes its fusion placement layout without relabeling that earlier run.

New authored model sprites were not installed for this test. This proves native
placement and operation, not final camera fitting or finished art.

The genuine pre-correction save, with foundation under the engines' whole
nominal footprints, was also loaded using the new rules. All four original
entities and their operating readbacks survive. The compact
`native/legacy-load-summary.json` records this separate compatibility check;
the existing save is not carved or migrated.

## Reproduce

The portable runner, flight fixture, electric fixture and verifier are in
`native/`. From that directory, use a fresh disposable output directory:

```powershell
$proof = 'C:\Users\Admin\Documents\ChatGPT\Tech priests\local-validation\half-mount-fresh'
$source = 'C:\Users\Admin\Documents\ChatGPT\Tech priests\model-production'
python run.py prepare --source-root $source --output-root $proof
python run.py create --source-root $source --output-root $proof
python run.py test --source-root $source --output-root $proof
python run.py server --source-root $source --output-root $proof
python run.py reload --source-root $source --output-root $proof
python verify.py $proof --repo $source
```

Reproduction takes a single fresh source snapshot. The retained run used an
initial source snapshot plus `mounting-source-binding.json`; the verifier supports
both. The original exploratory clone profiles and their row-by-row placement
results are retained separately under `probe-only/` in the raw test directory;
the compact result is included here. The probe templates are in
`tools/art/thruster_resumption/mounting/`. They test alternative cuts without
editing ordinary prototypes.

Raw logs, the full mod snapshot and CRC-verified save remain under
`local-validation/thruster-half-mount-20261117/`; compact results and exact hashes
are copied here. Review fixtures and supplied-reference comparison images are
not engine assets.
