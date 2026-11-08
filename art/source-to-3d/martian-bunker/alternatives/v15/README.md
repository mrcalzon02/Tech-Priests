# V15 — independent cannon recoil rig preparation

**Candidate checkpoint only. No firing/reload animation, final art approval or game integration.** Derived from the unchanged V14 bolted mounting plate source, using local Blender 5.0.1. The bunker base is not in this turret-only source and was not changed.

Nine mirrored source objects (three cast cannon pairs, muzzle pairs and feed-socket pairs) become 18 independent evaluated meshes under `RECOIL_TOP_R`, `RECOIL_TOP_L`, `RECOIL_MID_R`, `RECOIL_MID_L`, `RECOIL_BOT_R`, `RECOIL_BOT_L`. All 302 other source meshes retain geometry, material assignments and world matrices. Original editable modifiers remain available in V14; the separated surfaces are baked from their evaluated output to preserve bevel-generated UVs and exact triangulation.

The script checks the 40,680 affected world triangles, material assignment and UVs. UV interpolation differs by at most 1.1920928955078125e-7 (numerical tolerance 1e-6); world positions are compared to 1e-5 tile. A transform probe moves exactly the three TOP_R meshes, then restores the rest pose. No keys are authored. Other loader assemblies, belts, hatches and hoses remain static and **must be rigged before recoil motion is promoted**.

Independent reopened native and GLB metrics: 320 meshes, 457,512 triangles, 320 UV-bearing meshes, two embedded image textures, unchanged export bounds. The 1,764 inherited degenerate triangles remain an open geometry defect; preservation/readback pass does not claim production geometry acceptance. Source fidelity to the owner sketch and mounted/game appearance also remain unapproved.

`local-proof.png` is a six-view board of real local Blender renders. The bottom row shows the actual reimported GLB in independent lighting, including a neutral clay view. `render-review.json` binds review scores and limitations to native/export/reference/render SHA-256 hashes. Full results are in `rig-validation.json` and `roundtrip-validation.json`.

From repository root (provide a compatible local Blender 5.0.1+ executable):

```powershell
& $blender --factory-startup -b -t 6 --python-exit-code 12 --python tools/art/prepare_lobber_station_rig.py -- --source art/source-to-3d/martian-bunker/alternatives/v14/six_lobber_bolted_mount_v14.blend --out build/model-completion/lobber-v15
& $blender --factory-startup -b -t 6 --python-exit-code 12 --python tools/art/verify_lobber_station_rig.py -- --candidate build/model-completion/lobber-v15
```

View and review newly generated images after reruns. Do not copy the old review onto changed hashes. Next work follows `../animation/LOBBER_ANIMATION_PLAN.md`: one complete independent station first, then six offset cycles, eight-second steady loop and boundary continuity. Keep the fixed fin, mounting plate and bunker out of recoil.
