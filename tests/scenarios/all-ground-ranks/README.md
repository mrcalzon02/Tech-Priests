# Ground-rank Factorio runtime fixture

This is a **test-only Factorio mod**, not a distributable release or native scenario package. Copy the directory to an isolated Factorio mods directory as `tp-ground-rank-test` alongside `tech-priests`. It deliberately depends on Tech-Priests and exercises station-created priest pairs, excluding the Void rank.

The fixture places four Cogitator Stations and patches of iron ore, copper ore, coal, stone, uranium ore, and crude oil. It logs `[TP-GROUND-RANK-TEST] PASS` after checking station/priest pairs at tick 300; the CI runner must require that marker and reject `[TP-GROUND-RANK-TEST]` errors. This is a spawn-and-pair gate, **not** evidence of completed mining, logistics, or construction tasks. A persistent playable scenario/save and behavioral assertions remain subsequent gates.

Run in a fresh, disposable test world only. Do not enable this fixture in normal gameplay.
