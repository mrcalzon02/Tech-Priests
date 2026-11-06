# Fortified Martian Heavy-Weapon Bunker — 3D development

## v0.5 — two-pass front turret refinement

**Current modeling candidate:** v0.5 pass 2, an actual change to the armored gun carriage. [See both passes in the GitHub development gallery](gallery/README.md). [Rebuildable source archive](revisions/v05/martian_bunker_turret_front_v05_source.zip) contains one source generator with explicit `BUNKER_TURRET_PASS=1|2`, hull assertions and clean export tests. The native Blender workflow builds both versions and publishes each editable master, inspected renders, and the pass-two export GLB. All existing v0.4 hull/roof/magazine geometry is intentionally preserved. **Verified Blender output:** [editable pass-one master](src/v05/martian_heavy_weapon_bunker_pass1_v05.blend), [editable pass-two master](src/v05/martian_heavy_weapon_bunker_v05.blend), [final exported GLB](src/v05/martian_heavy_weapon_bunker_v05_blender_export.glb), [passing CI](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42164290455). No Factorio sprites or gameplay code are changed.


**Previous hull-baseline revision: v0.4 — beveled-hull conformance.** No gameplay, recipes, entity prototypes or existing sprites changed.

[Construction doctrine](../../../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md) · [Development gallery](gallery/README.md) · [Reproducible v0.4 source ZIP](revisions/v04/martian_bunker_v04_source.zip)

**v0.4 delivers actual geometry changes** rather than a task brief: four octagonal corner armor buttresses slope inward (and are supported by eight tapered buttress/foot bodies); front hatch, thermal sensing, structural bracing, east panel, breaker, anchored conduit, west condition gauge, rear vent, louvers and controller access plate are rebuilt from the actual z-dependent exterior face planes; the controller cabinet and certificate were moved below the roof edge. Bolts and secondary attachments are fitted to their parent equipment. The base remains 3×3 and the gun/turret/antenna remain attached and unchanged.

**Geometry testing:** 22 fitted external assemblies, eight sloped corner/foot bodies, 131 source meshes, 42 moving turret meshes, Z-up registration, fixed magazine below rotating platform. Run `python build_blockout.py && python verify_hull_conformance.py` in the extracted source.

**Historical v0.4 Blender pipeline:** the former [GitHub Action](../../../.github/workflows/martian-bunker-3d.yml) imports original geometry into native Blender, performs the hull/transform checks again, exports a GLB, reimports it into a clean Blender scene, renders four ortho inspections, and publishes native `.blend`, GLB, validation report and gallery renders on successful verification.

**Unapproved:** actual Factorio-scale art quality, PBR texture wear, deep static-system collision/intersection tests beyond face contacts, recoil animation and final sprite replacement.
