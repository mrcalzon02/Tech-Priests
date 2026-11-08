# Boiler V06 — rear interface manifolds

V05's continuously tapered external elbows were rejected. V06 replaces them with two separate cast interface chambers behind the machinery. The left chamber carries water into the main vessel; the right chamber carries steam from the separate pressure chamber. Their fluid spaces are independent.

The large external pipes retain their native dimensions all the way into each manifold: 0.57 tile outer diameter, 0.49 tile bore, 0.68 tile flange, centerline Z=0.36. External mouths remain at Blender (-1,0.5,0.36) and (1,0.5,0.36). Inside each manifold, a smaller 0.20-tile outer-diameter fitting connects to the existing machine-side vessel seat. That size change occurs in a chamber, not in a stretched or tapered hose.

Each manifold is a single connected closed shell with its full-size inlet neck and smaller machine fitting fused into it. It includes an empty plenum, cast edge breaks, mounting foot and bolted removable top cover. There are no modeled internal mechanisms. The 202 existing boiler core meshes retain their V05 world geometry. The existing vessel receivers are preserved.

The manifold housing uses the existing boiler material family. The full-size external collar uses the same material as the adjacent pipe collar. This revision removes the rejected reducing-elbow design.

Open `tech_priests_emergency_boiler_v06.blend` to inspect the editable geometry. The `BOILER_REFERENCE_ADJACENT_PIPES` collection can be hidden; references are excluded from the GLB. Previews use the 45-degree orthographic export camera, including front and rear cardinal views.

Validation checks closed, single-component manifold meshes, preserved core geometry, native-size mouth rings, native reopen and GLB mesh/bounds readback. This is a model review revision. Runtime integration and animation remain pending.

The complete archive includes the preserved V05 source and the V05 geometry helpers used by the revision script. From the extracted root:

```
blender --background --threads 6 --python build_boiler_v06.py
blender --background --threads 4 --python readback_boiler_v06.py
```

Validated with Blender 4.3.2.

## Saved assets

- [Editable boiler V06](https://chatgpt.com/library?file_id=libfile_a76488dcaadc8191a3a38ae50b31f8ab&account_id=personal)
- [Complete manifold package with source and helpers](https://chatgpt.com/library?file_id=libfile_6dfdf1c2a7a0819183c61107877418c8&account_id=personal)
- [Asset-only GLB](https://chatgpt.com/library?file_id=libfile_28690160587081918b57fc963558ecca&account_id=personal)

Packed native files are linked above. This directory stores the reconstruction scripts, hashes and validation records; run the scripts from the complete archive layout.
