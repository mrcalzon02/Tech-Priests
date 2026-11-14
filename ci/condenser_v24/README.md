Current evidence: the integrated production source passed the local Factorio 2.1.24 Steam graphical capture on 2026-11-13. See docs/art/local-machine-alignment/integrated-source-validation.json. The previous environment limitations below are historical.

# V24 native Factorio graphics capture

Runs the approved condenser inside a full Factorio 2.1 graphical client, using a new isolated profile. Requires the full client and graphical display; rejects a headless executable. No production saves are touched. The runner validates the active 105-PNG atlas and exact approved V24 source SHA before launch.

```
python3 ci/condenser_v24/visual_capture.py --client /path/to/factorio/bin/x64/factorio --working /absolute/new-profile --output /absolute/new-capture
```

On Linux, run with an active DISPLAY. Windows requires a logged-on desktop session. The isolated scene has four idle and four coal-fueled machines, real connected pipes at independent authored socket positions, and concrete tile pads. After 6000 ticks it verifies real water delivered through every working pipe, then requests 16 genuine engine screenshots: four directions × idle/working × normal/close zoom. No water is injected.

Outputs include original client PNGs, labeled contact sheets, genuine engine log and SHA receipt. Visually inspect flange-to-pipe continuity, body size against the 2×2 tile footprint, all four directions and standard/high quality before accepting scale. Headless tests cannot establish visible sprite alignment.

Current Codex workspace has only Factorio 2.1.24 headless. The full Linux client download redirected to Factorio sign-in and returned HTTP 403. The V24 graphical capture is prepared but has not run. Existing packaged headless flow tests passed all four directions in Auto, High and Standard quality modes.

The capture scene itself passed a headless smoke test with the screenshot stage explicitly disabled: eight condensers, eight connected pipes, and four fueled machines each delivered 30 water by tick 6000. This validates scene setup and operation only, not graphics.
