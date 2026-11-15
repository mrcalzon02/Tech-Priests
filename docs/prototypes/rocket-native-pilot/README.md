# Rocket native pilot

Native targeting/projectiles/ammunition remain engine owned. The controller
chooses successive cells and inserts the agreed reload interruption. Real
projectiles are moved to sockets extracted from the checked candidate-v02.

Fresh and separate-process reload physics pass: 23 sites, two stock ammunition
types, eight directions, 10-tick intra-salvo gaps / 190-tick last-to-next gap,
research-scaled cadence and exact native damage, target loss, partial resupply,
external disable, destruction/rebuild and untouched stock launcher origins.
The saved tick is observed from serialized state; autosave completion can lag
its request. Reload resumes on the actual saved tick plus one.

Eight real-art sites pass with four captured headings, real rendering objects,
empty cells and the corrected cassette/shutter sequence. Native screenshots
were viewed, including the full turret in its inventory preview and coloured
corner stanchions. Source-proof.json binds the exercised production modules.

This remains an isolated pilot, not a main-mod registration or full delivery.
Four directions and settled-only cap shadows are temporary pilot limitations.
Full body capture is continuing; moving shadows and full-mod regression remain.
The previously completed six main-mod weapons are unchanged.

Reproduce with a local Factorio 2.1 installation:
- python tools/run_rocket_salvo_physics.py
- python tools/run_rocket_salvo_physics.py --graphical (generates real mid-reload save)
- python tools/run_rocket_salvo_physics.py --reload
- python tools/run_rocket_salvo_animated.py [--graphical]

Graphical fixtures pause after their PASS report; close only their recorded
fixture PID after observing the result. The animated runner can use the
published partial art under art/bunker-rocket-salvo/runtime-pilot-v1.
