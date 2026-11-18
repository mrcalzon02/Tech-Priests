# V11 current surface plan

This records the surfaces already present in the immutable V11e source; it does
not authorize or perform another material pass. Exact material/image bindings and
color spaces are in `canonical-packed-source-audit.json`; current bake receipts
are extracted without alteration in `surface-plan.json`.

| Region | Current surface and placement |
| --- | --- |
| Seven Noctilith groups | Seven unique 768px atlases, broad angular charcoal/olive face mottling, interrupted variable-width ochre mineral web, granular tangent normals/roughness, chipped edges and measured contact-pressure masks. Mineral is nonmetallic; ochre seams are mineral, not brass. |
| Energized cleavage faces | Actual recessed inner fracture geometry with distinct green emission slots/maps. Cold mineral remains readable independently of emission. No floating neon wire substitutes. |
| Cage, keels and fore mounting | Blackened cast iron and satin load rails; unique geometry-aware atlas placement, restrained edge wear and localized contact darkening. No uniform metallic stripe across unrelated parts. |
| Dish tiers, carrier and hub | Cast/satin metal with geometry-specific edge/contact bakes; substantial segmented rims, cast webs and ceramic receiver joints provide construction highlights. Cold dishes remain nonemissive source metal; captured green rim FX are a separately declared derivative. |
| Six receiver covers | Current closed-cover machining atlas, uniquely unwrapped from actual corrected pockets and reliefs. Cast faces, restrained machined edge wear and contact masks; split plates/joints remain physically separate. |
| Retained engine pan and cover plates | Dedicated constructed-surface atlas, with real raised returns, retained plates and contact-localized finish. The pan remains engine machinery across the hanging half. |
| Guides and fasteners | Distinct blackened cast receivers, compressed ceramic sleeves, dark protective polymer clips, machined satin fasteners and compressed split joints. Arc-length/circumferential route UVs and fixture-local UVs are retained. |
| Conductors, contact shoes and insulators | Existing copper/bronze/olive ceramic material assignments and compatible Pipette terminal/route construction preserved. No invented fluid fittings or gameplay sockets. |
| Embedded skull reliefs | Supplied DGordillo skull anatomy, original UV/sculpt normal and attribution retained; bronze cast finish inside cog receivers, at least half embedded along the actual support normal. |
| Separate deep installation well | Bounded dark fore floor/side/fore-back surfaces and rim, below the body with measured clearance. It is separate from the engine pan and contains no aft floor. |

Base-color PNGs use explicit linear-to-sRGB encoding. Tangent normals and
metal/roughness data remain Non-Color; metal/roughness packing is R=1, G=roughness,
B=metallic. Grain/crushed/pressure maps are retained authoring masks. Semantic
decoded-map tests supplement file presence/size checks. Current source reopening
finds 74 packed images (34 sRGB, 40 Non-Color) and 36 used materials.

`source-contract.json` preserves the development history. Its early
`authored_refinement.surface_plan` dark rock constants and early
`finish_repair.uv_bakes` mineral records are superseded by
`bounded_mineral_pass`, including the explicit base-color encoding correction.
The current closed receiver bake is
`functional_detail_v10.closed_case_repair.case_surface_bake`. No historical
rejected blank or near-black map is presented as the current surface plan.

The reference is the hash-pinned original blackstone icons and cold/run fusion
rock windows in `noctilith-reference.json`. The gray asteroid family was excluded.
The supplied emitter screenshot is mapped to a clean committed legacy sprite in
`stacked-dish-reference.json`; no private clipboard raster is redistributed.
