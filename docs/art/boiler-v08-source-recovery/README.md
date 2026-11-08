# Boiler V08 editable source recovered locally

`art/source-to-3d/boiler-v08/production-source.blend` now exists at the exact path expected by the production profile. It was reconstructed from approved V07b SHA-256 `0fae930858a9f8c92a5f85e2cfb1e8bd08317542470a09f6fc049de9c39306f4`, using the unchanged committed animation, camera cleanup and cold-frame preparation scripts. This is a new reconstructed binary, not a claim to have downloaded or reproduced the historical Library binary byte for byte.

The independent prepared-source reopen gate checks all 270 original mesh vertex hashes, the historical animation target/group/nozzle/puff metadata, all packed image dependencies, cold frame zero, active frame 25, one camera, sampled motion/emission ranges and the 1/97 animation endpoint. The earlier animated-file validator also passes. Three pressure/canister rigs, 11 animated material targets and 16 steam puffs remain present.

The actual common renderer captured cold frame 0 and working frame 25 at all four source yaws. All eight RGBA PNGs were decoded and their capture hashes checked, then visually inspected in `source-pilot.png`. Camera, Cycles samples/seed, lighting, canvas and geometry use the existing production contract. Source-yaw ordering differs from native N/E/S/W: the production job retains `[0,3,2,1]`. These eight pilot captures are not a complete 388-frame re-export or final state-layer acceptance.

`pilot-atlas-comparison.json` compares each pilot with its corresponding installed 256px atlas cell. None is byte-identical. Per-channel means are small, but raw maxima include unassociated transparent RGB and are retained honestly. No existing production PNG or Lua was replaced. In particular, the accepted four-way pipe scale/placement remains unchanged.

## Rebuild without Library access

Run locally with Blender 5.0.1 and the exact approved V07b file:

```text
python tools/art/rebuild_boiler_source.py --source PATH_TO_APPROVED_V07B.blend --blender PATH_TO_BLENDER --out FRESH_SCRATCH_DIRECTORY
```

The tool refuses a mismatched source or an existing output directory, runs the original scripts in a scratch mirror, prepares the cold frame and invokes the independent reopen gate. It never installs sprites, changes gameplay, commits, pushes or dispatches Actions. The actual committed tool was exercised end to end in a separate fresh directory. Blender saves can have different binary hashes; geometry and animation evidence must be checked for each result.

The missing editable-source gate is resolved for this boiler. Cold/working graphics-state separation, wire-anchor support and complete asset acceptance remain open. See the separate native state-layer investigation before promoting a new atlas. The full model ledger remains authoritative for other assets.
