> **Current production authority:** continue locally using [LOCAL_BLENDER_CAPTURE.md](../../../../../docs/art/LOCAL_BLENDER_CAPTURE.md). The cloud recovery description below is historical; its active run was cancelled. Do not dispatch Actions or invoke the destructive assembler directly on verified captures. Use the capture-preserving local staging wrapper.

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

The original 64-heading run remains at https://github.com/mrcalzon02/Tech-Priests/actions/runs/42429529804 . Its old workflow definitions were removed from main during the workflow cleanup; the source and valid render artifacts are retained. The sole replacement workflow for this export is `.github/workflows/lobber-export-recovery.yml`.

The recovery workflow has a narrow push trigger on its own file, manual dispatch, and a completion hook restricted to the original source run. The cleanup cancelled the unfinished original capture. Recovery preserves successful chunks and resumes at most eight missing chunks per run, with eight simultaneous workers. After a successful batch, verified artifact progress permits exactly one next dispatch. No progress or any failed batch stops continuation. The chain is bounded to 64 waves (48 suffice for an entirely missing 384-chunk capture); no hundreds-job matrix or polling runner is created. A missing original chunk inventory is rejected rather than guessed.

Pinned Blender 5.0.1 is restored from cache or fetched through the official mirror service with the original download server as fallback. Its official archive SHA-256 is checked; HTTP failures including 403 receive bounded retries. Valid partial frame caches and uploaded partial artifacts are reused only with matching pixel identities. Completed repairs receive a distinct complete-artifact name after every expected pass is checked.

Finalization runs after repairs and again when the original source run completes. If either side is still incomplete, it records the state and exits without holding a waiting runner. Once every chunk is covered, it merges original frames and repairs, validates the complete output, assembles engine-safe sheets and publishes the recovered release. The checked delivery record makes repeated completion events idempotent. No other removed workflows are restored.

Video encoding streams frames directly to ffmpeg. Raw assembly working copies are removed only after their sheets are written; sheet PNG working copies are removed after their delivery ZIP passes CRC verification, keeping disk use bounded. Raw frames remain available in individual capture-job artifacts.

The assembler requires every expected image, consistent identities, correct RGBA dimensions and clear alpha margins. It writes six 32-frame colour/emission sheets and twelve 16-frame shadow sheets per heading, separate entry/settle sheets, rotation sheets (four pages for shadow; one for colour/emission), a 360° GIF, an all-heading firing movie, eight-heading contact sheet, registration metadata and SHA-256 checksums. Release ZIPs are split by pass below a conservative payload budget. A complete verified batch publishes a prerelease and commits its delivery record; incomplete captures cannot reach that job.

## Reproduction

Restore source, then run Blender with the saved scene and `validate_scene.py`. Run `render_capture.py -- --direction 0 --chunk 0 --out rendered`, varying direction 0–63 and chunk 0–5. `--pilot` captures idle plus firing/flex samples. Run `verify_pilot.py` after the pilot and `assemble_capture.py --input rendered --output delivery` only after all chunks complete.

`prepare_capture.py` is the provenance/rebuild step and takes `LOBBER_SOURCE` and `BUNKER_CAPTURE_REFERENCE` paths. The original bunker reference SHA-256 is fixed in that script. All textures are packed in the reconstructed source; Python auto-execution is unnecessary for ordinary native playback.

Every delivered sprite sheet is at most 5120 pixels on either axis, below the engine's 8192-pixel input-width limit. The recovery workflow uses this corrected assembler for final delivery; raw render frames and capture identities are unchanged.

## Recovery checks

Run `python -m pip install Pillow PyYAML`, then `python test_recovery.py`. Tests cover failed-chunk selection, completed-frame reuse, completion gating, bounded work, artifact identities, credential-safe redirects, transient HTTP retries, and installer mirror/cache/checksum behavior. The optional real-pilot importer test is skipped in checkouts without the earlier local pilot frames.
