# Local A02 continuation — approved source, existing frames, remaining capture

## Source authority correction

The initial completion audit missed native Blender files represented by `source_manifest.json` plus `source_parts/*.bin`. The main branch contains two fully checksummed segmented sources: the original bunker turret/camera and the A02 six-cannon lobber. The approved animation is therefore **present and recoverable**, not plan-only or missing from Library. V15/V16 are historical static rig/cleanup studies; do not replace A02 with them or rebuild its existing six independent animation stations.

Verified A02 native SHA-256: `0c9ebf42b16ddd53a8162d836bb88a052c77f16c28f4e7265172300797e372ed` (11,179,678 bytes, 16 verified parts). Original turret/camera source: `827885c9c42cb752dea9bae1a0d31cb957f144f21d945ad019c507aaa6e2b9a3` (54,303,119 bytes, 78 parts). The updated inventory verifies all part hashes and the assembled hashes; source-file extension alone is insufficient for future inventories.

The A02 scene already includes six firing/reload stations, sliding hatches, belt travel, whole grenade props, hose deformation, muzzle effects, chassis reactions and antennas. Its original capture contract is the authority. `validate_scene.py` was run locally and passed all 64 idle rotations, six independent flashes, transition checks, packed-image checks, fixed camera/light checks and eight-heading extreme bounds. A new local heading-16 pilot passed all three passes and alpha/emission checks. Its median three-pass pose time was 30.343 seconds with four render threads; this is a measured pilot, not a complete export.

## Required final output (still open)

64 headings × 192 cycle frames, plus 64 idle poses and 15 entry / 15 settling frames per heading: 14,272 poses and **42,816 PNG images** across beauty, emission and registered shadow passes. Keep the original 640px beauty/emission, 1280px shadow, 6.20 orthographic camera, 16-sample Cycles and 24fps sampling of the 60fps master. Do not shrink this contract to the four cardinals or replace it with the static V16 scene.

After all frames pass source identity, full PNG checks and alpha margins, use the established assembler. It writes engine-safe sheets at most 5120px wide/high, entry/settle states, rotation pages, registration and preview movies. Inspect actual output, then add exact native prototype graphics registration. Do not claim capture completion, final fidelity, or game integration from the local pilot or a subset of headings.

## Local execution

Use `tools/art/restore_segmented_capture.py --repo <checkout> --capture art/source-to-3d/martian-bunker/captures/lobber-64 --out <operational-pipeline>` to restore the exact source and Git-byte scripts. The operational copy uses original line endings so render/cache identity is unchanged on Windows. Existing differing operational files fail closed. Keep generated output under `build/model-completion/` or the current chat's persistent `work/` folder.

The active run's persistent root is `C:\Users\Admin\Documents\Codex\2026-11-07\referenced-chatgpt-conversation-this-is-an\work`:

- `lobber-a02/`: verified source and original pipeline copy.
- `lobber-a02-pilot/`: the actual new local pilot, with validation in `a02-local-pilot-validation.json`.
- `lobber-artifacts/`: existing output downloaded using authenticated `gh run download`; no dispatch. Per-artifact completion/partial markers preserve recovery progress.
- `lobber-a02-rendered/`: identity-verified imported output and new local captures.
- `lobber-a02-rendered/local-capture-state.json`: manager and worker PIDs, logs, pending/complete chunks and terminal failures.
- `lobber-a02/verified-seed-complete.json`: written only after all available downloaded output is inspected; missing/invalid frames remain pending for local rendering.

`tools/art/run_local_lobber_capture.py` manages the full 384-chunk target with at most four local workers, four render threads each, and one worker per heading. One-per-heading is essential: the established renderer shares an emission temporary folder per heading. Source/config/renderer identities are checked before reuse; completed chunks get frame SHA-256 records. The controller inspects every process exit and bounds retries. An observation timeout is not a reason to restart it: verify the recorded PID/command and tool session first. After a real terminal failure, reuse valid partial captures.

The first local chunks at headings 16,48,24,40 completed and passed verification. Initial artifact import added 4,334 valid PNGs and 35 complete chunks, for an initial 39/384 verified checkpoint. Further recovery is in progress. The seeder excludes those four local headings. A JSON `artifact-import.lock` can reserve only `held_headings` while workers continue other headings; a non-JSON lock conservatively pauses all new starts. Release this task-generated lock only after the importer exits successfully. The manager independently verifies cached frames before skipping each pending chunk. Artifact names never prove completion.

Heading 0 has been separately verified: all six chunks, 669 PNGs (192 cycle, one idle, 15 entry, 15 settling poses, three passes), original identity and full decode/alpha checks. `lobber-a02-heading-00-validation.json` records every frame hash. The eight-second GIF is a cropped viewing preview of the real 192 sampled cycle frames; the raw images are unchanged. This proves one heading, not the full export.

An attempted live controller handoff stopped four unfinished child renders. Their already completed images were preserved and reused. Do not repeat that handoff: observe the actual manager/worker processes and wait for no live jobs before changing the execution setup. The subsequent CPU batch completed, then the GPU manager was started with no old workers live.

### Optional local OptiX profile

`--optix-setup <path>/enable_local_optix.py` selects existing OptiX devices for this process without saving preferences. The tested machine has an RTX 5070 (12GB). Blender 5.0.1, the native source, original scripts/config, samples, denoising, camera, resolution, animation and CPU compositor remain unchanged. The local pilot passes; median three-pass pose time was 21.172 seconds versus 30.343 seconds on CPU. Four workers have been observed writing frames successfully; these pilot timings are not a whole-capture completion estimate.

GPU and CPU images are not byte-identical. The nine-image pilot comparison records sparse numerical/noise differences (maximum RGBA deltas [22,21,20,32], worst mean channel difference 0.0047583/255). The checkpoint records the selected backend and setup hash for newly generated frames, and per-frame records distinguish retained pre-existing bytes. Do not rewrite source identity or silently label recovered CPU pixels as GPU-generated. See `lobber-a02-optix-pilot-validation.json` and `lobber-a02-execution-profile-comparison.json`.

The old cloud render chain was found running independently of skip-CI commits. Run `42459758206` was cancelled and independently observed `completed/cancelled`. Do not dispatch its workflow, enable continuations, edit workflows, or publish a release. Continue all remaining work locally. Downloading existing output is permitted and preserves already-spent rendering work.

## Completion and recovery

Read the current process state and verify actual live PIDs before starting anything. Do not launch duplicate managers. Keep the full source/camera/renderer identity in every checkpoint. After worker completion verify all expected frames independently, assemble the real atlases and previews, inspect them, integrate graphics on main, push with `[skip ci]`, and read back the exact SHA and bytes. Keep issue #13 open until the remaining assets and model/render/integration gates are evidenced. No behavior or regression tests belong to this task.
