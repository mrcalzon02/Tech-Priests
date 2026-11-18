# Preserved FX recipe

The packed master contains imported static body/well, canonical camera, packed
PBR images, lightning ribbon meshes, particle glints and volume wisps. It opens
without external image files.

The exact helpers and JSON state in capture-receipt.json define animation.
Changing Blender frames alone is not baked animation: the driver explicitly
calls set_electric_arcs_phase and set_particle_plume_phase after scene evaluation,
retaining per-arc visibility. Phase=index/64 for0..63; index64 independently
renders the wrap at phase1=phase0. Only fast local crackle/advection uses this
two-second cycle. Actual native electrical draw owns the global envelope.

Fresh processes separate static/energy Cycles and field-only Eevee. Camera,
exposure, evaluated scene frame, analytic phase and physical digest are recorded
per output. Eevee keeps its sampling frame fixed while explicit helper phases
move FX. This is analytic advection, not an uncontrolled simulation.

tooling/tools/art/thruster_resumption/animation/ preserves exact capture, particle,
electric arc, emitter, launcher, packager and final-verifier versions.
tooling/tools/fmpl/ preserves the bound canonical camera authority/policy.
Keep that repository-relative hierarchy when using these snapshots. Blender
provides bpy/numpy; packaging/verification also needs Pillow. Those applications
are not bundled or installed by this archive.

Rebuild only into a NEW profile/output. external-source-pins.json maps original
staging references to canonical identical body/well and validation/aperture
records. A changed path/profile creates a new binding. A regenerated Blender
serialization can have a new hash and needs fresh checks; never rewrite or
relabel these frozen original receipts.

Static source geometry, half-hanging mount, deep fore well, opaque core, Noctilith,
Pipette conductors and embedded skulls remain immutable inputs. No new gameplay
ports/physical wires, animated physical GLB or real background refraction is
claimed.
