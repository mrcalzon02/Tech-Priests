# Martian Atmospheric Water Condenser V22C — native four-direction physical acceptance

**Result: PASS — four native Factorio 2.1.24 pipe connections.**
**Limit: physical pipe/socket proof, not graphical in-game screenshots or verified water transfer.**

## Immutable evidence

- Real engine run: https://github.com/mrcalzon02/Dens-Mortis/actions/runs/43299437461
- Success line printed by the actual Core30 job:
  CONDENSER_V22C_NATIVE_FOUR_WAY_CONNECTED_PASS source=fb3b1b267c64897362914a9b1f0bc9b1d6f79507 connected_pipes=4 formed_fluid_segments=0 unformed_segments=0 forming_segments=4
- Registered runner: OLD-CORE30-homebrew, Windows x64, locally installed Steam Factorio 2.1.24.
- Isolated public test source commit: fb3b1b267c64897362914a9b1f0bc9b1d6f79507.
- Controller workflow commit: c50df0cef86671a2fb7a12b6d5343212e52627e8.
- Approved Blender V21 master SHA-256: 1ccd8093e5b153d80b7ac66cb77b364f05e7ee46a5f236efe189498b71dd052b.
- Mod: Tech Priests, existing source prototype tech-priests-atmospheric-water-condenser, 2x2 footprint, existing output recipe tech-priests-atmospheric-water-condensing.
- Native validation fixture: [tests/scenarios/condenser-v22c-physical/fixture.lua](../../../tests/scenarios/condenser-v22c-physical/fixture.lua).
- Native driver and fail-closed parsing: [tools/run_factorio_isolated_service_scenario.py](../../../tools/run_factorio_isolated_service_scenario.py).
- Parser positive and negative controls: [tests/unit/test_condenser_v22c_native_verdict.py](../../../tests/unit/test_condenser_v22c_native_verdict.py).
- Genuine Blender four-way Cycles proof: [Condenser_V22C_Four_Way_Integration_Proof.png](captures/v22c/Condenser_V22C_Four_Way_Integration_Proof.png).

## Actual native placements

Each machine was created by the real Factorio engine, received the genuine fluid-producing recipe, and had one engine-reported output port. The fixture placed a separate native pipe at the engine-reported target_position and required two independent connections: get_fluid_box_pipe_connections(1) must point to the pipe, and get_fluid_box_neighbours(1) must identify the same pipe.

| Facing | Machine ID | Pipe ID | Machine centre (tile x, y) | Native pipe/socket point (tile x, y) | Segment on on_init |
| --- | ---: | ---: | --- | --- | --- |
| North | 1 | 2 | (0, 0) | (1.5, -0.5) | forming |
| East | 3 | 4 | (18, 0) | (18.5, 1.5) | forming |
| South | 5 | 6 | (0, 18) | (-1.5, 18.5) | forming |
| West | 7 | 8 | (18, 18) | (17.5, 16.5) | forming |

The real engine save creation exited 0 and the 720-tick benchmark exited 0. The isolated native test emitted four independent NATIVE_CONNECTED records and a single PASS four original 2x2 V22C condensers with native direction-rotated output pipes marker; the strict verifier accepted all four directions and eight distinct entity IDs.

**Boundary:** On the creation tick the fluid segments had not fully joined: formed_fluid_segments=0, forming_segments=4. No simulated water, inferred fluid transfer, or invented positive segment IDs are credited. A future fluid-flow acceptance must sample the fully formed runtime segments and real fuel-fed water production after ticks.

## Existing animated Blender delivery

- Blender 5.2.3, Cycles, seamless 12-second motion cycle.
- Eight separate cylinders piston in sequence, forty incoming mist elements draw inward during intake, indicator lights blink and the housing vibrates subtly.
- Four Wube-style 45-degree camera orientations, 96 native rendered frames per orientation before Factorio atlas subsampling.
- Factorio uses 32 active frames per direction over 12 seconds in HR 512px and standard 256px atlas sheets.
- Forty atlas PNGs plus a 64px icon (41 assets) are committed and were verified in the packed-release workflow.
- Output flange local Blender tile point (1, -0.5); Factorio output prototype local position (0.5, -0.5), originally east-facing and rotated with the entity.
- The model geometry, burner recipe, existing energy mechanics, 2x2 collision box, and gameplay logic were not modified in this acceptance job.

## Artifact delivery and remaining checks

The valid native receipt and exact JSON verdict are preserved in the GitHub Actions job log linked above. A separate GitHub Actions artifact upload was rejected because the artifact-storage quota is exhausted; upload delivery is NOT claimed to have succeeded.

Blender source, native render, atlas integration, production ZIP packaging, and four-way physical Factorio pipe/socket alignment are validated. Graphical in-game sprite alignment against neighboring pipes, actual fluid flow after segment formation, and full graphical client animation are **still open**. A headless engine receipt is not a substitute for a real headful in-game screenshot.
