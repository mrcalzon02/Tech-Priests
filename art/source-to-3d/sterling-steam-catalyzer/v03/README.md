# Sterling Steam Catalyzer V03 checkpoint

The actual Space Age prototype is a platform-only chemical boiler: 4x2,
600 kW, 165 C steam, chemical fuel in one slot. Native fluid heat capacities
produce a 10:1 steam/water volume ratio: nominally water2/s -> steam20/s.
It is not a Stirling power generator or an assembler. Building recipe is
pipe10 + boiler1 + offworld-cogitator-components2 + servitor-parts1, 12s,
disabled until hydrogen-thruster-propulsion. Preserve the platform surface
restriction and normal player-grid pipes.

The original half-axis ports appeared connected to ordinary pipes but passed
no fluid. On a genuine space platform, ordinary placement succeeds in all
four facings; moving only both port Y positions from0 to0.5 restores actual
flow and natural full-output stopping. Baseline and repaired raw evidence is
retained. Exact committed source bytes were tested without a data-stage override.
The earlier ground fixture was not legal placement evidence.

No original editable Sterling model was located among the named current
repository sources. The original body/shadow sprite is the design reference;
the separate Emergency Boiler was inspected, not substituted or modified.
This authored candidate preserves the horizontal pressure shell, bands,
bolted end covers, return manifold, cap castings and green front console.
Full-bore water/steam sockets, supported firebox, instrument impulse line,
pressure needle and visible coal flames explain the actual operation.
Two inherited geometry helper modules are copied from the Tanks primitive
pump production tools; Sterling geometry and all nine surface roles are new.
The 27 packed PBR images distinguish casting, bronze, water steel, red serviced
enamel, instrument ceramic, phosphor and refractory. No unrelated machinery
or invented power-generation drive is added.

The packed source was reopened; the actual GLB was independently imported.
Six poses, embedded images, UV/finite/triangle checks and the working loop pass.
Source and actual-export front/alternate renders were viewed. V01/V02 studies
remain local; V03 repairs pipe/end-cover clearance and exposes the flame roots.
This is a source checkpoint, not completed art delivery or owner approval.
The production sprites are unchanged. Pending gates are explicit in checkpoint.json.
Run build_sterling.py and inspect_export.py with Blender 5.0 from this directory.
The canonical FMPL camera helpers live at tools/fmpl in the repository.
