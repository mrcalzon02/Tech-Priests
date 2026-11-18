# Lowered frame and surrounding fore ledges

This is the current native placement receipt following the owner's lower-frame
and surrounding-platform bracing correction. The preceding `native/` run remains
historical. Current compact evidence is in `low-frame-native/`.

The nominal narrow core still snaps on a 1x9 grid. Its low side-cheek mounting
flanges extend onto the surrounding fore ledges, so the ground requirement now
includes the neighboring columns on both sides. The fore collision region also
reserves space for those braces. The aft core/field corridor remains one column
of empty space. The wide drive keeps its 4x4 snap grid and reserves its wider
fore landings. Source core size, bracket reach and native snap grid are distinct
measurements; the engine performance curves are preserved.

An actual native missing-side-landing case is refused. All four ordinary drives
then pass legal edge placement and real flight, including both fusion drives'
independent power/feed variation, unpowered refusal, recovery and hidden-sink
repair. A real autosave at tick1500 is reloaded in a separate engine process;
its full tick1560 state exactly equals the uninterrupted result. The genuine
pre-correction save also loads with all original engines operational.

Eight current source/prototype files match the tested hashes. The private server
was stopped after the verified save. No normal save/profile was changed.

The source model contract retains deck edge Y=0, top Z=0, +Y fore. Lowered
cradles sit inside a real U-shaped installation bay, supported by side-ledges and
fore braces, while roughly half the physical body hangs aft. Model-to-native
camera/shift, deck recess/underlay and occlusion registration remain explicit new
art gates. This test uses the ordinary existing sprites, not the new models.

For a fresh reproduction, run the commands in `README.md` from
`low-frame-native/`, using the current source checkout, and pass
`--fixture flight_low.lua` to `verify.py`. The stored control fixture is the
actual lower-flange flight test, including the missing-ledge refusal assertion.
Large snapshots/logs and the real save remain in
`local-validation/thruster-low-flange-mount-20261117/`.
