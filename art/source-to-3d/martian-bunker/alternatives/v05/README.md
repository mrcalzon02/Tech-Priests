# Loose pineapple grenade loader concept — V05

The six V04 cast-iron cannons keep their mesh shapes, UVs, aim angles and lateral positions. The lower pair stays fixed. The middle pair is raised slightly and the upper pair twice that amount, increasing the station separation to fit the new exterior loader. Each existing pneumatic pipe and its mounting hardware translates intact with its cannon. The central fin grows vertically to support the taller arrangement.

Each cannon gains an open cradle with three loose olive-green pineapple grenades. Raised green body segments, dark grooves, attached grey spoon levers and pull rings make the classic grenade form visible. A broad open guide trough leads from the cradle to an exterior side-loading hood, with an additional intact grenade posed at the presentation point. This is a visual game-asset loading concept; the hood conceals the fictional transfer into the cannon. The original bottom pipes remain the pneumatic air connections.

The native model retains mirrored halves and editable grenade parts. No original cannon, muzzle or air-pipe mesh is rebuilt. The source asserts their geometry and UV hashes and checks that all pose changes are vertical station translations only. The bunker is not loaded, approximated or modified in this head-only pass.

## Files and reproduction

The Actions run produces a packed Blender model, reimport-tested GLB, five actual Blender views, a four-panel review PNG and a ZIP. The close-up is deliberately cropped to the upper loading area. Whole-model views are checked for border clipping. Current validation is in `model_validation.json`.

Use Blender 5.0.1 from the repository root. The V04 packed Blender model is the preserved baseline:

```sh
blender -b --factory-startup -t 4 --python-exit-code 12 --python art/source-to-3d/martian-bunker/alternatives/v05/build_loose_loader.py
python art/source-to-3d/martian-bunker/alternatives/v05/make_review.py
```

Default review settings are 1100 pixels and 32 Cycles samples. The Actions preview uses 900 pixels and 16 denoised samples through environment overrides. Both use the same geometry, materials, camera positions and native preservation checks.
