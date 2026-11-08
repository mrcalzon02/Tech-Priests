# Native structure attachment review — Factorio 2.1.24

**Boiler visual baseline rejected:** physical pipe coordinates did not prove sprite-mouth alignment. See [the subsequent four-direction visual correction](../boiler-v08-visual-alignment/README.md).

The actual installed graphical client loaded an exact tracked working-tree mod copy and captured the dedicated placement scenario. High sprite quality was retained with low VRAM residency so four existing Blender workers could continue. The isolated config, mods, new map and autosave stay in the task scratch folder; the user's normal Factorio profile and saves are untouched. The installed Mechanicus Reborn 0.0.3 ZIP is enabled only in the review profile because the mod's character sprites reference it. No vendor art or dependency ZIP is committed here.

## Corrected native integration

`thruster-mounting-visuals.lua` previously looked for `enable_working_visualisations` on a fluid box. The installed native prototype puts that gate on each pipe connection. The final pass now selects the matching west/east donor connection, copies its named cap visual, translates its draw shift, and binds the names to the corresponding custom connection. Native cap PNGs remain referenced through `__space-age__`; they are not copied into the mod.

Final local socket centres: hydrogen west/east `(-1.5,-0.5)` / `(1.5,-0.5)` for its integer-origin 4x4 body; Thetazine `(-2,-1)` / `(2,-1)` for its half-tile-origin 5x5 body. These preserve the actual adjacent ordinary-pipe centres seen in the baseline. The old hydrogen intended endpoint was 0.5 tile above the snapped pipe centre; Thetazine had a 0.09765625-tile horizontal discrepancy after engine quantization. All four corrected endpoints match the connected pipe centre exactly. Filters, counts, flow direction, performance and runtime servicing are unchanged.

The final pass also fits the native supported-body / clear-aft tile masks to each body's actual dimensions. Native placement was tried on empty probe sites with last foundation rows -1 through 6. Baseline hydrogen 4x4, narrow electric 1x9 and large electric 4x4 had no legal edge in that sweep. Corrected legal rows are respectively 1, 4 and 1. The 5x5 Thetazine and vanilla control still accept row 2. Each rejects the other swept rows, preserving required aft void clearance. The probe sites contain no pre-existing entity collision. The electric variants keep zero visible fluid ports.

`baseline/` and `corrected/` retain actual unretouched screenshots and engine connection/placement readbacks. The proof board only crops/resizes and labels these screenshots. Connected and disconnected frames were taken at ticks 120 and 150; asteroids were cleared only inside the new review map before capture. `native-attachment-validation.json` records exact module/image hashes and check scope. Boiler V08 has four actual unfuelled placement views and eight exact pipe-centre joins.

## Open work

The thruster bodies are still the original primitive sprites: authored 3D body geometry, model-specific surfacing, export and final visual acceptance remain open. No Blender model has been silently substituted by this graphics repair. Boiler V08's cold-idle/working graphics separation and circuit-wire anchors remain unapproved; its current module references the working atlas as `structure` and does not reference the idle atlas. Resolve that in the model/export/native-state design before claiming full boiler completion. No fuel consumption, power, thrust, AI, logistics or combat behavior/regression suite was invoked.

## Repeat locally

Prepare with `python tools/art/native_visual_review/prepare.py --repo CHECKOUT --workdir SCRATCH --sprite-dependency INSTALLED_MECHANICUS_ZIP`. The fixture helper copies tracked **working-tree bytes**, so keep the relevant source hash with each run. Use a new scratch root or preserve baseline/candidate folders before repeating. Run `tools/art/native_visual_review/launch.ps1 -ReviewRoot SCRATCH` through PowerShell. It starts the installed client through Steam and replaces only a client whose command line identifies that exact scratch config. Do not automate Steam authentication or warnings.

After the capture requests finish, preserve `SCRATCH/userdata/script-output/model-visual-review` as the baseline or candidate evidence. The map pauses and saves after both states. To compare the original module, restore its exact Git blob into the isolated mod copy only; never overwrite the real checkout or unrelated work. The native API definitions used are the installed client's `doc-html/runtime-api.json` and `prototype-api.json`.

Run `python tools/art/native_visual_review/verify.py --fixture-root SCRATCH --baseline BASELINE --candidate CANDIDATE --repo CHECKOUT --outputs OUTPUTS`. It checks receipt geometry, input hashes and PNG integrity and produces proof boards. Its initial status requires actual visual review; inspect the images and bind the review to their hashes. Keep normal user saves and active Blender processes out of fixture cleanup. No Actions are used.
