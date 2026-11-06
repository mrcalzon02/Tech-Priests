# Fortified Martian Heavy-Weapon Bunker — 3D development

**Active modeling revision: v0.4 — beveled-hull conformance.** No gameplay, recipes, entity prototypes or existing sprites changed.

[Construction doctrine](../../../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md) · [Development gallery](gallery/README.md) · [Reproducible v0.4 source ZIP](revisions/v04/martian_bunker_v04_source.zip)

**v0.4 delivers actual geometry changes** rather than a task brief: four octagonal corner armor buttresses slope inward (and are supported by eight tapered buttress/foot bodies); front hatch, thermal sensing, structural bracing, east panel, breaker, anchored conduit, west condition gauge, rear vent and louvers are rebuilt from the actual z-dependent exterior face planes. Bolts and secondary attachments are fitted to their parent equipment. The base remains 3×3 and the gun/turret/antenna remain attached and unchanged.

**Geometry testing:** 20 fitted external assemblies, eight sloped corner/foot bodies, 131 source meshes, 42 moving turret meshes, Z-up registration, fixed magazine below rotating platform. Run `python build_blockout.py && python verify_hull_conformance.py` in the extracted source.

**Blender pipeline:** the single [GitHub Action](../../../.github/workflows/martian-bunker-3d.yml) imports original geometry into native Blender, performs the hull/transform checks again, exports a GLB, reimports it into a clean Blender scene, renders four ortho inspections, and publishes native `.blend`, GLB, validation report and gallery renders on successful verification.

**Unapproved:** actual Factorio-scale art quality, PBR texture wear, deep static-system collision/intersection tests beyond face contacts, recoil animation and final sprite replacement.
