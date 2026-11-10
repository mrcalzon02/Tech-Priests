# Emergency Miner — V21 baseline and V22 owner-directed motion refinement

**Approval state: not rendered or visually approved until a native Blender receipt is attached.** The unmodified original Factorio art and prototypes remain the active rollback; no gameplay changes are permitted in this study.

## What this machine is

A badly overpowered, face-down, frequency-modulated laser ablator that slowly reconstitutes poor scrap from contaminated ground. The owner's description is **the world's angriest photocopier**. It is not a mechanical excavator. We animate the external reaction to an unseen internal scan; never add an emitter array, moving laser arm, auger or fabricated underside.

Source geometry authority: `build_model.py` V21 and `SPRITE_LOCKED_FEATURE_REGISTER.md`. The model is still a visually unapproved reconstruction; animation is a separate question from model fidelity.

## Exact mechanical partition

| Group | Existing real objects | Motion | Maximum intended apparent displacement |
| --- | --- | --- | --- |
| Static floor | foundation steel slab/rim, two SOURCE FOUNDATION feet, six source anchor bolts | none | 0 |
| Central armor | real LAYER_2 casting, original two front screws | low-amplitude 3-axis vibration and tiny torsion | about 0.002 scene units; under 0.4 degrees |
| Upper assembly | raised LAYER_3 casting, the actual controls, rear clamp wiring, side corrugated hoses and mounted equipment | delayed secondary shudder | about 0.003 scene units; under 0.6 degrees combined |
| Maintenance cover | existing mid service cover, no new support plate | fine independent rattle around real seated position | under 0.001 scene units |
| Status optics | LCD, original four indicator lenses | emission/intensity flicker only | geometry remains registered |
| Service seam scan | small transient FX-only slit highlight at the real mid-service/control join; second smaller front-case leak | left-right traveling pale blue-white hotspot, limited spread | only existing seams may emit light |
| Steam | two real source vent apertures and original right inspection-cover edge | short, small, physically 3D FMPL feathered-volume wisps, not bright cone shells | bounded inside machine footprint / nearby overhang |

The scan-beam mechanism is *not visible geometry*. A moving light leak and locally illuminated casting produce the impression of scanning. The emission objects belong to `ANIMATION_ONLY__NON_GAMEPLAY`, not the machine source collection.

## Two deliberately separate hypotheses

- **A / constant industrial fury** — continuous uneven 6-13 harmonic body rumble, one broad left-to-right optical sweep, diagnostic blink sequence and two mild pressure-breath events. It should feel forceful but sustainable.
- **B / stuttering ablation** — weaker baseline rumble interrupted by two small load shocks, two much narrower and sharper optical sweeps, urgent flicker and shortened steam release. It should look as though the machine is nearly overdriving itself.

Both use the **same unrotated V21 geometry**, the **same FMPL 45-degree orthographic grid-aligned camera** (0 azimuth, no lens shift), the same 384×384 review resolution and a 16-sample 8fps loop with exact closing key at frame 97. Variants are separate editable .blend files. **No four-direction atlas is authorized yet.**

## Reproducible source construction

```text
blender -b --factory-startup --python-exit-code 1 \
  --python art/source-to-3d/emergency-miner/animate_preview.py \
  -- --out <new-clean-output-dir>
```

The script imports the existing native V21 construction functions (including the original mesh booleans and source hash guard), installs the one canonical FMPL camera, and saves an untouched review-only baseline. Each variant is then opened from the same baseline, physically keyed, saved as a separately editable Blender source, independently reopened and rendered.

Per-variant deliverables:
- `miner_motion_A.png` / `miner_motion_B.png`: animated PNG files with 16 **real Blender frames** each.
- `miner_motion_A.blend` / `miner_motion_B.blend`: keyed source scenes with a single FMPL canonical camera.
- `A/frame_001.png` etc.: actual 384px fixed-angle evidence; native 43px swatches for game-readability.
- `motion_manifest.json`: model hash, camera receipt, counts, rendered frame hashes and proof that the foundation transform never changes.

## Acceptance gates before any four-view export

1. Compare A and B side by side **in the chat**, from actual Blender output, including idle, peak scan, steam release and native 43px versions. Links or artifacts alone are insufficient.
2. Source-object identity and positions: no additional decorative machinery, no mechanical drilling apparatus, no invisible mechanism mesh, no original sprite or prototype mutations.
3. Steam starts at existing real openings rather than floating in front of the chassis; no conical surface/sprite card or fog swallowing the machine.
4. Two separate light leaks stay seated in real casing seams. If either emits through a solid panel rather than a cut or visible joint, correct the **FX anchor**, not the source enclosure silhouette.
5. No clipping, mount tear, hose disconnection, or floor-plate motion; animation includes an exact closed loop.
6. Readable at 43px, with no runaway emission washing out the LCD or known four lamps. The user decides which variant to continue.
7. Only then: four model rotations under one stationary FMPL camera; HR/standard atlases, alpha/shadow/emission layers, native prototype frame/direction/speed mapping, in-game startup/runtime validation and fallback preservation.

**No workflow sprawl.** Target the already-authorized Dens Mortis single-job local Blender controller and pin the Tech-Priests commit. An Actions-success receipt is not visual acceptance.

## V22 — owner-directed console, laser and capacitor correction (2026-11-10)

The owner reviewed the first actual fixed-view animated samples and directed three concrete changes:
1. Raise **only the original console bank and its real supporting front upper casting** by 0.014 Blender units, allowing a little more of the middle chassis edge to be read. Do not add a new fascia/false intermediate plate, move the foundation or alter component counts.
2. The three existing recessed capacitor mouths must face **up toward the fixed 45-degree Factorio camera**, not lie horizontally. Rotate their real shells, lips and inset ends together about physically retained rear supports. Validate a camera-axis dot product at least 0.94 in reopened Blender, and preserve precisely three mouths.
3. **Remove BOTH former roaming laser highlight surfaces** from the upper service cover/console and front chassis. Replace with just THREE small emissive inserts underneath the three Boolean-cut original vent apertures. A hidden scanning energy source may animate their brightness in sequence, but no light bar, tracking glow or invented laser mechanism may appear on any solid panel or across the middle chassis.

The dedicated code authority is `build_model.py:apply_owner_v22_geometry()`, called by the V22 master build and `animate_preview.py`. The source sprite and playable prototype remain unaltered. `verify_animation.py` separately reopens each keyed Blender file, checks the original three capacitor axes and all three vent-only emitters, and forbids the earlier surface-panning lights.

Render first from ONE FMPL 45-degree orthographic camera using A/B review cycles. A bounded `--quick-review` run retains the complete 16 authored motion samples at eight samples per second but reduces preview-only Cycles cost and resolution percentage; it does not change the camera, permanent mesh geometry or source registration. Human visual approval is required before any directional atlas, HR/SD sprites or in-game replacement.

**Revision history discipline:** V21 remains available in Git history and the V21 runner artifact. V22 is a new, unapproved candidate; no previous accepted source asset is overwritten.
