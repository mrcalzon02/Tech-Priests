# Fortified Martian Heavy-Weapon Bunker — 3D development

## Alternative turret blockouts — V01

Owner-sketch energy dish and twelve-tube grenade lobber, fitted to the established M2 bunker base. Independent editable Blender assemblies, turret-only mapped GLBs, packed committed textures and real mounted/front/rear review renders. Primitive massing checkpoint; twelve tubes verified as three rows of four. Base mesh geometry and world transforms are preserved. Saved native files reopen, GLBs reimport and turret traversal leaves the base fixed.

[Review board](alternatives/v01/Turret_Blockouts_V01_Review.png) · [Models, provenance and reproduction](alternatives/v01/README.md) · [Executed verification](alternatives/v01/reopen_validation.json).

## CURRENT: v1.0 (v10 source folder) reference-conformance correction

The user-selected image in [style-references/visual-target-v08.png](style-references/visual-target-v08.png) is the reference, not a license to add speculative components. The previous v09 Blender gun had a giant knob at the end and an unnecessary raised red service armor slab on its roof. These were absent from the source image.

**Exact approved scope:** change ONE muzzle crown mesh to a thin open-bore profile, remove ONE invented roof plate and FOUR bolts. Exactly 193 other source meshes remain unchanged, verified by comparison with previous named GLB geometry. No new parts, panels, clamps, decorative rings, fake damage, or extra lights.

[Actual model/source ZIP](revisions/v10/martian_bunker_v10_reference_bound_source.zip) · [same-camera geometry proof](gallery/v10_reference_vs_existing_vs_corrected.png) · [reference rules and regression](revisions/v10/martian_bunker_v10_reference_bound_source.zip) · [native Blender pipeline](../../../.github/workflows/martian-bunker-3d.yml).

No production sprite or gameplay code changed. High-detail target matching still requires your visual approval after inspecting real Blender renders.


## Current revision: v0.9 subtractive turret cleanup

**Real editable mesh work, not AI image generation.** The previous v0.8 attempt accumulated unnecessary concentric rings and decorative parts. The new source eliminates 55 pieces while preserving the entire bunker, gun bore, turret rotation, sensors and required armor load paths.

[Actual v0.8-v0.9 geometry comparison](gallery/v09_before_after_mesh.png) · [v0.9 source package](revisions/v09/martian_bunker_v09_subtractive_model_source.zip) · [Blender gallery and progress](gallery/README.md).

The one native Blender workflow independently exports and imports actual model geometry, verifies attached functional parts and generated PBR texture maps, and publishes the verified editable masters and camera renders. Not yet accepted as final reference fidelity or native Factorio sprite.


## v0.8 — real editable geometry toward owner-selected appearance

**Current modeling revision.** [Source visual target](style-references/visual-target-v08.png) (reference only), [native Blender development gallery](gallery/README.md) and [reproducible actual 3D source](revisions/v08/martian_bunker_v08_actual_model_source.zip). This is **not** image generation: the 172-part v0.7 mesh is extended to 254 real independent parts; circular gun mantlet, 12 attached ring fasteners, two bolted round sightheads, headlight/status brackets, gun cover, 5 turned collars, roof access armor, recoil seal hardware, and original machine cog are modeled as physical parts, moving with the turret. A full 23-material procedural PBR atlas is regenerated and assigned in Blender. The v0.7 bunker, footprint and service cabling remain.

**Quality contract:** the existing single Blender CI renders both flat and weathered variants, reimports both GLBs, and publishes the actual .blend, exported GLB, close-ups and Factorio-size diagnostic only after geometry/material checks. The owner's selected screenshot is held as a comparison target, not as a substitute for model work. No Factorio sprites or gameplay code changed.


## Active v0.7 — replace square gun jacket in the editable Blender asset

The v0.6 barrel refinement left `21_gun_tube_outer_shroud` as a **literal cuboid**. This source error is now fixed in v0.7, not just in a reference image: the box is removed, replaced with a 48-sided tapered, hollow cylindrical gun jacket and circular connectors, seated into the mantlet and attached to the moving turret pivot. The original three user-provided weathering reference views guide 512×512 deterministic painted armor/steel/ferrocrete PBR map regeneration.

[View actual v0.7 gallery](gallery/README.md) · [Buildable source](revisions/v07/martian_bunker_v07_round_jacket_source.zip) · [Native Blender CI](../../../.github/workflows/martian-bunker-3d.yml) · [Reference images and style rules](style-references/README.md)

The latest model is **not** a gameplay entity replacement or an approved production Factorio sprite.


## v0.6 — barrel and original PBR materials

**Latest asset candidate.** Builds from v0.5 without changing the hull or turret mount. An actual open-bore lathed pressure barrel, stepped heat-treated muzzle crown and fitted collar/bracket details replace the earlier blunt disk. The connected single-job Blender workflow builds flat-vs-textured comparisons with **60 original albedo/ORM/normal maps** generated from reproducible Python source; packs them into editable Blender and final GLB. [Source ZIP](revisions/v06/martian_bunker_barrel_texture_v06_source.zip) · [Development gallery](gallery/README.md) · [Single Blender workflow](../../../.github/workflows/martian-bunker-3d.yml). Source image provided by the owner is a *style guide*, not copied/repackaged material. No gameplay or sprite change.


## v0.5 — two-pass front turret refinement

**Current modeling candidate:** v0.5 pass 2, an actual change to the armored gun carriage. [See both passes in the GitHub development gallery](gallery/README.md). [Rebuildable source archive](revisions/v05/martian_bunker_turret_front_v05_source.zip) contains one source generator with explicit `BUNKER_TURRET_PASS=1|2`, hull assertions and clean export tests. The native Blender workflow builds both versions and publishes each editable master, inspected renders, and the pass-two export GLB. All existing v0.4 hull/roof/magazine geometry is intentionally preserved. **Verified Blender output:** [editable pass-one master](src/v05/martian_heavy_weapon_bunker_pass1_v05.blend), [editable pass-two master](src/v05/martian_heavy_weapon_bunker_v05.blend), [final exported GLB](src/v05/martian_heavy_weapon_bunker_v05_blender_export.glb), [passing CI](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42164290455). No Factorio sprites or gameplay code are changed.


**Previous hull-baseline revision: v0.4 — beveled-hull conformance.** No gameplay, recipes, entity prototypes or existing sprites changed.

[Construction doctrine](../../../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md) · [Development gallery](gallery/README.md) · [Reproducible v0.4 source ZIP](revisions/v04/martian_bunker_v04_source.zip)

**v0.4 delivers actual geometry changes** rather than a task brief: four octagonal corner armor buttresses slope inward (and are supported by eight tapered buttress/foot bodies); front hatch, thermal sensing, structural bracing, east panel, breaker, anchored conduit, west condition gauge, rear vent, louvers and controller access plate are rebuilt from the actual z-dependent exterior face planes; the controller cabinet and certificate were moved below the roof edge. Bolts and secondary attachments are fitted to their parent equipment. The base remains 3×3 and the gun/turret/antenna remain attached and unchanged.

**Geometry testing:** 22 fitted external assemblies, eight sloped corner/foot bodies, 131 source meshes, 42 moving turret meshes, Z-up registration, fixed magazine below rotating platform. Run `python build_blockout.py && python verify_hull_conformance.py` in the extracted source.

**Historical v0.4 Blender pipeline:** the former [GitHub Action](../../../.github/workflows/martian-bunker-3d.yml) imports original geometry into native Blender, performs the hull/transform checks again, exports a GLB, reimports it into a clean Blender scene, renders four ortho inspections, and publishes native `.blend`, GLB, validation report and gallery renders on successful verification.

**Unapproved:** actual Factorio-scale art quality, PBR texture wear, deep static-system collision/intersection tests beyond face contacts, recoil animation and final sprite replacement.
