# V16 — degenerate geometry cleanup

Local Blender 5.0.1 geometry correction derived from V15. **Still an incomplete, unintegrated turret candidate.** No firing, loader motion, gameplay code or Actions work was added.

Removed 1,764 degenerate triangles from 24 existing parts: hatch recess backs, one chute, a cable clip, and mounting-bolt seats. Degenerate means a world-space triangle cross-product length below the existing verifier threshold of `1e-12`; the threshold was not weakened. Only affected objects have their evaluated modifiers baked. V15 retains the editable pre-cleanup modifier history. All surviving vertex positions, UV values and material indices match their evaluated source exactly; source parenting and world frames remain unchanged.

Independent native reopen and GLB import each report **320 meshes, 455,748 triangles, zero degenerate triangles**, all meshes with UVs, finite world coordinates, unchanged model bounds, and six retained recoil controls. This passes the degenerate-geometry gate, not every final asset acceptance gate.

`local-proof.png` shows actual local Blender source/candidate and GLB rear/clay renders. The matched source/candidate camera, authored lighting, seed and sample count produce identical alpha and a maximum RGB change of one 8-bit value. Inspect `pixel-comparison.json`, `cleanup-validation.json`, `independent-validation.json` and `render-review.json` for hash-bound evidence and limitations. No fresh fidelity approval against the owner's original sketch is claimed.

From the repository root, with a compatible local Blender executable:

```powershell
& $blender --factory-startup -b -t 6 --python-exit-code 12 --python tools/art/clean_lobber_degenerate_geometry.py -- --source art/source-to-3d/martian-bunker/alternatives/v15/six_lobber_independent_recoil_v15.blend --out build/model-completion/lobber-v16
& $blender --factory-startup -b -t 6 --python-exit-code 12 --python tools/art/verify_lobber_clean_geometry.py -- --source art/source-to-3d/martian-bunker/alternatives/v15/six_lobber_independent_recoil_v15.blend --candidate build/model-completion/lobber-v16
```

Next: independently rig one loader/hatch/belt/grenade/hose station, animate and inspect it, then propagate the approved cycle according to `../animation/LOBBER_ANIMATION_PLAN.md`. The full bunker base, native game sprite export and prototype integration remain separate open steps.
