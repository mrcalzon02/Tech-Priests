# Condenser V24 — turbulent intake mist approval candidate

November 13, 2026. The owner accepted the atmospheric intake direction, rippling pistons and overall intake timing, and requested less uniformly oval clouds with noisy edges and visible stretching toward the inlet.

## Changes

- Turbulent noise now distorts the alpha boundary, rather than varying density only inside a smooth oval envelope.
- Each particle has a distinct noise seed and slowly evolving, seamless material noise.
- Broken elongated density features provide internal wisps.
- Each camera-facing particle turns its long axis toward a real inlet target. The orientation constraints work under cardinal model rotation.
- Particle length grows during intake, then contracts near the mouth so mist does not extend through the inlet. The cross section narrows as it approaches.
- An outer alpha guard fades before the particle quad border, preventing rectangular clipping.

The source is the SHA-locked V23 inlet review: `5b7a8bb22a23463db555eba8cdb9327180a67939dc151ec59e0d44ec1461d554`. The V23 inlet geometry, hardware, all eight piston strokes, mist centre trajectories, indicators and output flange remain unchanged. Forty effect-only target empties are added; no hardware mesh is added or edited.

## Verification and approval renders

Independent reopening compares all 203 hardware meshes against V23 and checks their world matrices at every frame 1–97. The receipt records exact measured results. Rendering uses real Blender 5.2.3 LTS Cycles with the existing 45-degree orthographic camera. Four cardinal stills use the model turntable and rotate original loose-root output hardware consistently.

The approval set contains a full 96-frame, 8-FPS, 12-second north-facing cycle at 384px, a 24-frame, three-second diagnostic close-up at 512px, and four 512px cardinal stills. Cycle and close-up use 12 Cycles samples with denoising and persistent data; the four stills were rendered at 20 samples. Diagnostic close-up framing is not the game export camera. GIF durations alternate 120/130 ms to preserve eight frames per second exactly.

This is a review candidate, not a game integration. Owner approval remains pending. After review, the authorized V23 geometry delta still needs its explicit export contract, HR/standard atlases and real Factorio playback/fluid-output verification.

## Reproduction

Run `revise_condenser_v24_mist.py --source <V23 blend> --out <V24 blend>` with Blender `--python`, passing the script arguments after `--`. Render using `render_condenser_v24_review.py --source <V24 blend> --out <capture directory> --mode cycle`, `close`, or `stills`.
