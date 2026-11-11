# Condenser V22 — ordered atmospheric intake strokes (native Blender review candidate)

**Approved model source stays V21.** Required exact editable source: `tech_priests_water_condenser_v21.blend`, SHA-256 `1ccd8093e5b153d80b7ac66cb77b364f05e7ee46a5f236efe189498b71dd052b`. Its 152 approved machine meshes, eight caps and seats, colored indicators, display, worn metalwork, right pipe union at Blender `(1,-0.5,0.36)`, 2×2 footprint, four silhouettes, reference-pipe exclusion and fixed foundation remain authoritative. The source is linked through the prior V21 asset Library package; **it is not bundled in Git**. Never approximate/rebuild a replacement if the exact bytes cannot be accessed.

## Motion brief (replaces obsolete unified-rack animation)

The eight **existing individual capped canisters**, not their seats, lift one after the other across the 4×2 rack. The timed order follows actual world-space rows: four left-to-right along one row, then four right-to-left along the other. Each head lifts a maximum **0.058 scene units**, holds while drawing air, seats smoothly, and hands off with no simultaneous piston strokes. Eight 12-frame slots at 8 fps yield a **12-second seamless loop** (frames 1 and 97 identical). All mechanical displacement is encoded in editable source-derived Blender transforms.

When a head opens, three short tapered cool-white/light-blue atmosphere wisps follow **outside-to-inside** curves, with their visible segments travelling *toward the exposed seat*. They do not shoot outward, vent pressurized steam, create any external pipe, or suggest a machine leak. Only the active head has visible vapor, with the streaks retracting before closure. These 24 extra **FX curves are not machinery meshes** and do not change the original geometry. The LCD breathes lightly, the existing red/amber/green lamp covers blink/pulse via temporary material copies and lights, and the internal **rack alone** vibrates by a few thousandths of a tile. Concrete/foundation, main chassis, exterior pipe and hose fittings remain absolutely stationary; no ground/base shaking.

## Source-locked operation

From the repository root, using native Blender on a machine with access to the exact V21 source:

```bash
python art/source-to-3d/condenser-v21/test_condenser_v22_timing.py
blender --background --threads 4 --python art/source-to-3d/condenser-v21/animate_condenser_v22.py -- \
  --source-blend /absolute/path/to/tech_priests_water_condenser_v21.blend \
  --out /absolute/path/to/condenser_v22_review
blender --background /absolute/path/to/condenser_v22_review/condenser_v22_motion_review.blend \
  --threads 4 --python art/source-to-3d/condenser-v21/verify_condenser_v22.py -- \
  --out /absolute/path/to/condenser_v22_review
```

The SHA/source-object gate fails closed; source bytes are never modified. This uses **one canonical FMPL fixed 45° orthographic camera**. Rotation is applied only to the entity via a reversible turntable. It writes an editable animated `.blend`, 16 evenly sampled temporal `frame_*.png`, a genuine idle and raised-head Cycles still for each of the four cardinal directions, another eight actual game-scale renders at **43 px/tile** (86×86 for 2×2), source hash and frame hash manifest, then a separate Blender-reopen validation receipt. A 16-frame study is a *sampled proof*, not a full 96-frame video at natural timing.

## Approval and release gates

1. Review the **actual Blender source-derived** 12s loop, four camera orientations and 86px previews. Check real visible inward vapor, separate head lift, seating, tiny rack shake, blinking covers and a completely stable outlet/base. Adjust visible effects as needed.
2. Independently reopen the native derivative and check 8 independent pistons, 24 inward vapor FX curves, frame 97 closure, original foundation/outlet immobility, camera and source hash. Inspector reports native correctness, **not human art approval**.
3. Only on separate owner visual acceptance, export four 45° directions with HR/SD Factorio sprite atlases, check entity graphics and native fluidbox alignment in Factorio, and preserve a one-step rollback to the previous sprite. **No current Factorio replacement, finished render, visual approval or gameplay test is claimed.**

Do not launch more GitHub workflows, modify unrelated machines, or release an unreviewed animation. Blender and the exact original .blend are required for real graphics; static Python tests alone cannot substitute for native renders.
