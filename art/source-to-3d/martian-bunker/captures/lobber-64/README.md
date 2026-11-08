# Alternate bunker topper — six-cannon lobber capture

The [approved A02 source package](https://chatgpt.com/library?file_id=libfile_2dbbd397c3f08191a917a7192f12fa28&account_id=personal) supplies the native lobber: recessed inward-sliding hatches, six independent firing/reload stations, chassis rock, flexible antennas and existing muzzle effects. The original bunker capture's packed camera, area lights, world and AgX colour settings are copied without resizing the lobber. Mounting pivot remains at world (0, 0, 1.70). Concrete bunker geometry is excluded.

## Capture contract

- Blender 5.0.1 / Cycles / 16 denoised samples.
- Fixed 45-degree orthographic camera; original scale 6.20.
- 64 clockwise headings, 5.625 degrees per step; N=0, E=16, S=32, W=48.
- Transparent 640×640 colour and emission cells.
- Transparent 1280×1280 ground shadow cells with camera scale doubled: identical pixels per world unit, centre offset (-320, -320) relative to the colour cell. The larger shadow canvas avoids shrinking the topper to accommodate its projected shadow. A registered soft receiver footprint fades the very distant ambient-shadow tails before the sprite edge; it does not rescale or move the shadow.
- 192 frames at 24 fps for each eight-second six-shot cycle. The 60-fps native keys are sampled at 2.5-tick intervals, preserving 1⅓-second shot spacing.
- 64 clean idle poses, 15 entry frames and 15 settling frames per heading. Idle disables firing effects and closes all hatches. Entry removes reactions and reloads from the preceding loop. Settling finishes the last reload/smoke/antenna reaction without starting a seventh shot.
- 14,272 three-pass poses / 42,816 PNG images in the complete delivery.

The repeating cycle retains the last barrel's reload across the seam. Entry replaces the first 15 cyclic frames when firing begins from idle; continue with cycle frame 15 onward. At stopping, play the settling clip after the end of the cycle. Its final pose matches idle. These are graphics assets and metadata; gameplay prototype integration is a subsequent step.

## Execution and recovery

`restore_source.py` reconstructs the packed native scene from individually checksummed parts and checks the complete SHA-256. `validate_scene.py` reopens and checks camera, packed textures, all 64 idle orientations, six firing events, clean transitions, fixed lighting and eight-heading motion bounds. `render_capture.py` renders one heading and one 32-frame chunk, with idle/entry on chunk 0 and settling on chunk 5. Cached images are reused only with matching source/config/renderer identities and valid PNG CRCs/dimensions.

The GitHub workflow `.github/workflows/lobber-bunker-capture.yml` first runs four cardinal pilot jobs. Missing passes, absent flash emission, clipped alpha and an excessive projected chunk runtime fail that gate. The full capture then runs two matrices of 32 headings × 6 chunks, each under GitHub's matrix job count cap, with 20 workers total. Native scene validation is performed in the pilot rather than repeated in every chunk. Chunks preserve partial outputs and use attempt-specific caches for bounded retries.

Video encoding streams frames directly to ffmpeg. Raw assembly working copies are removed only after their sheets are written; sheet PNG working copies are removed after their delivery ZIP passes CRC verification, keeping disk use bounded. Raw frames remain available in individual capture-job artifacts.

The assembler requires every expected image, consistent identities, correct RGBA dimensions and clear alpha margins. It writes six 32-frame cycle sheets per heading/pass, separate entry/settle sheets, rotation sheets, a 360° GIF, an all-heading firing movie, eight-heading contact sheet, registration metadata and SHA-256 checksums. Release ZIPs are split by pass below a conservative payload budget. A complete verified batch publishes a prerelease and commits its delivery record; incomplete captures cannot reach that job.

## Reproduction

Restore source, then run Blender with the saved scene and `validate_scene.py`. Run `render_capture.py -- --direction 0 --chunk 0 --out rendered`, varying direction 0–63 and chunk 0–5. `--pilot` captures idle plus firing/flex samples. Run `verify_pilot.py` after the pilot and `assemble_capture.py --input rendered --output delivery` only after all chunks complete.

`prepare_capture.py` is the provenance/rebuild step and takes `LOBBER_SOURCE` and `BUNKER_CAPTURE_REFERENCE` paths. The original bunker reference SHA-256 is fixed in that script. All textures are packed in the reconstructed source; Python auto-execution is unnecessary for ordinary native playback.
