# Original bunker turret: full rotation and directional firing

Capture source: the saved M2 V10 original cannon turret, with its existing two-stage recoil, fixed hydraulic mounting rings, housing reaction and gentle antenna flex. Rejected planetary glyphs are removed. The intact bunker base is preserved separately and excluded from this capture copy. No alternative lobber or energy turret is used.

64 clockwise headings cover 360 degrees at 5.625 degree intervals. Direction 0 is north, 16 east, 32 south and 48 west. A heading's resting rotation image is exactly frame 1 of its firing animation, so switching from turning to firing preserves registration. Each heading has 32 frames at 24 fps. Camera, lighting, pivot and 640 x 640 transparent canvas remain fixed. Smoke follows the selected heading; its original animation was authored in east-facing world space and now inherits traverse through a preserving parent inverse.

The source is split into verified binary parts only for reliable transfer. Run `python3 restore_source.py` in this folder to reconstruct the original packed `.blend` byte for byte. `source_manifest.json` verifies every part and the complete source. The workflow performs the reconstruction automatically.

Run Blender 5.0.1 with the restored scene and `validate_scene.py`, then `render_capture.py -- --directions all --frames all --out rendered`. The batch workflow renders one heading per worker, preserves every completed heading as an artifact even when another worker fails, validates all 2,048 frames, assembles the rotation atlas and per-heading firing atlases, and creates a full rotation/firing review movie. The package includes the editable native source.

Outputs are capture assets and registration metadata. Installing them in a Factorio turret prototype is a separate integration step. The final job publishes a GitHub Release asset and a checksummed delivery record to main only after all images have passed validation. Draft releases are not used.
