# Faction production facilities

Current authored assets for the three agreed troop-production building types.
Source meshes, procedural materials, packed image maps, GLB exports and renders
are retained under `candidates/<model>/`. The reviewed runtime body/shadow and
working-effect atlases live in `tech-priests_src/graphics/entity/faction-factories`.

| Facility | Footprint | Availability | Native active power |
| --- | --- | --- | --- |
| Martian Manufactorum | 4 x 4 | Default building recipe | 150 kW |
| Imperial Guard Muster Hall | 5 x 5 | Guard Muster, red science | 250 kW |
| Sororitas Convent | 6 x 6 | Militant Orders, red/green/military/chemical | 800 kW |

All are real assembling-machine prototypes, with exclusive faction crafting
categories and a real directional reagent/coolant input. Native item and fluid
processing is tested with isolated fixture recipes. Troop, weapon and ammo
recipes remain the separate roster implementation; the fixture does not ship
those test recipes or establish autonomous Tech-Priest logistics acceptance.

Inventory icons are explicitly deferred. The item/prototype definitions refer
temporarily to Factorio's existing assembler icon; no new inventory art is made.

## Source and art contract

- Original project-authored architecture and surfaces; no extracted Gladius
  building meshes or texture images are used. Existing character-donor copyright
  notices remain in the project. Franchise names/trademarks retain their owners.
- Metres, Blender Z up, front -Y; editable scene origin is floor-centred in world
  space. GLB is Y up with transforms retained. Bounds/ground contact are measured
  after importing the actual export, not inferred from the source scene.
- Separate paint, cast metal, copper/bronze, stone, slate, timber, canvas and glass
  regions. Area-weighted UV packing and 2048-pixel base-colour, metallic,
  roughness, tangent-normal and emission maps are baked and packed in sources.
- The Martian servo is a static posed assembly with editable named component
  meshes, gearbox covers and fasteners, bored paired links, actuator/clevis,
  conduits, wrist coupling and lead-screw gripper. Joint frames are recorded in
  source/GLB extras. An animated or mechanically load-rated robot is not claimed.
- Four cardinal body/shadow captures from a fixed 45-degree orthographic camera.
  Sun rays `(4,6,-8)`, fixed world lighting; body images retain their recorded
  registration. Only the shadow catcher's alpha tail below 8/255 is cleared.

## Working animation

The native main working animation provides production smoke; two native
`working_visualisations` layers provide emissive sprite flicker and a flickering
light. Body/shadow repeat through the 24-frame cycle; idle omits smoke.
No Lua effect timer,
emitter scan, damage effect or simulated pollution system is installed.

Smoke is a 24-frame, two-second Cycles volume cycle at 12 fps with constant world
wind, model-specific source sockets and the actual building as holdout geometry.
Mars uses its two stacks, the Guard hall its ridge louvre, and the Convent its
rear forge flues. Real roofs and walls occlude the cloud render.

Glow is extracted from exported emissive material regions. Non-emissive surfaces
are holdouts so rear windows do not shine through solid walls. Gentle 0.78..1.0
alpha flicker and native light flicker operate only during native working state.
Smoke uses 512-pixel cells at scale 0.75; glow/body use 768-pixel cells at scale
0.5. All layers share the same world-origin registration.

## Rebuild and verify

Run Blender with `--factory-startup --background --python` and these scripts:

1. `tools/art/build_faction_factories_animated.py -- --model <martian|guard|sororitas>`
2. `tools/art/verify_faction_factory_sources.py`
3. `tools/art/render_factory_working_fx.py -- --model <model>`

Then use normal Python:

1. `tools/art/review_faction_factories.py` for front/rear/close/clay and four-way sheets.
2. Record actual visual findings and current artifact/render hashes in
   `visual-review.json`; the promotion tool never invents review scores.
3. `tools/art/review_faction_factories.py --promote` for body/shadow sprites.
4. `tools/art/pack_factory_working_fx.py` for smoke/glow atlases and filmstrip.
5. `tools/run_faction_factories_native.py` for isolated complete-mod loading,
   research, placement, power, item and pipe-fluid production, animation captures
   and separate-process save/reload.
6. `tools/art/preserve_factory_native_evidence.py` to preserve logs, day/night
   GIFs, source hashes and independent per-building pixel-change checks.

Read `source-readback.json`, each `inspection.json`, `visual-review.json`,
`promotion.json`, `working-fx-runtime.json`, and the native evidence separately.
Technical passes, assistant art review, native behavior and owner art approval
are distinct. A scored local-engine review is not a claim of owner approval or
publication. The original rejected studies are preserved locally under the
earlier version folders; see their status manifests and the canonical project
development history.
