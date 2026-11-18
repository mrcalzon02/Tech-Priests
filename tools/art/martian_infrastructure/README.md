# Martian infrastructure native proof

Run `python tools/art/martian_infrastructure/run_native.py` from any directory with Factorio 2.1 installed at the runner's configured path. `--source PATH` selects an isolated Tech Priests source tree; `--output PATH` keeps disposable profiles and results outside production. `--packaged ZIP` tests a prepared release archive.

The fixture exercises all three native electric pole tiers and all three composed Vox array tiers, technology/recipe/health contracts, copper/red/green connections, powered coverage and native scanning, unpowered scan suspension, clone/ghost revival, mining, unraised destruction, death, helper component recovery and duplicate prevention. Production controllers retain event ownership; only the private proof mod polls ticks.

The reload run serializes initialized records and native wires at tick zero, then executes the scenario after loading. It does not claim a mid-scenario active-state continuation. Historical reviewed model and dish rotation evidence remains in `docs/art/martian-infrastructure`.
