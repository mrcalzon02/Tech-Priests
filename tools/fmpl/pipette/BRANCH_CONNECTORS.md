# Pipette physical branch junctions — no generic connector cubes

**Status:** `wire_eight_loose_bundle` and `wire_eight_laced_loom` have a dedicated 8-to-4+4 Y/tee **geometry builder**. Other multiport types remain pending real material-appropriate branch hardware. A wire branch is not a fluid manifold, and a three-port shape is not evidence of electrical connectivity.

## The corrected eight-wire Y

The old `library_geometry.build_demo()` synthesized a 0.42 BU-wide **solid cube** at every non-fluid branch junction, then Blender attached an eight-way terminal block to each of the three external ends. Its wires were three independent eight-conductor segments that all stopped at the hub: **24 conductor meshes pretending to be an eight-wire split**. Source/tests could pass despite visually absurd geometry.

This behavior is removed. The physical Y uses:

- **Eight individually continuous conductor meshes**, one per insulated wire. A carries eight; B receives four and C receives four. Each conductor runs directly from A to its assigned destination through a compact central fanout. No cloning, truncated paths, implicit electrical splice, hidden resistor, or generic terminal housing.
- **Independent deterministic visual slack** on trunk and branch segments, using the established eight-core fixture multipliers and lateral offsets. Wires look naturally different without random spaghetti or coincident strands.
- **Three compact, tapered, true-hollow strain-relief boots** at the trunk and two exits. Their centroids follow the actual draped bundles, rather than floating at a theoretical junction height. The laced-loom variant adds two narrow retaining ties; no giant central cube.
- **Sixteen individual miniature annular ferrules**: eight at inlet A, four at outlet B, and four at outlet C. All stay inward of the declared connector faces. They are small architectural details, not a claim of rated electrical termination or a substitute for the host socket.
- **Exact shared port geometry**: A=(-1.2,0,0.65), B=(0.848528137,0.848528137,0.65), C=(0.848528137,-0.848528137,0.65) BU; all outward normals and camera constraints remain frozen in `comparison_fixture.v1.json`. Individual local strand offsets remain within each public port's nominal 0.12 BU envelope.

The whole branch is built from `library_branches.build_eight_wire_y()`. `library_geometry.build_demo()` delegates wire Y/tee requests to that implementation. `library_blender.py` deliberately **skips outer terminal blocks** for an embedded breakout, since the miniature fittings are included in the generated assembly.

## Failure policy for other branches

Pipette must no longer invent generic boxes as a fallback. If a multiport carrier has no physically constructed join, the model receives `branch_junction_status: unresolved-branch-hardware-no-fallback-block`. Its separate visible line segments are a **construction preview only**, never a supposedly functional junction. Hollow fluid Y bodies must instead go through Blender's connected/watertight, unobstructed CSG manifold builder. Only specifically supported wire bundles use the eight-to-four-plus-four breakout.

Branch type choice stays independent of **terminal** hardware. Examples under separate development: 2-wire solder/insulated splice, four-core grommeted breakout, jacketed eight-core heatshrink Y, metal-conduit junction box with correctly sealed raceway entries, optical-fiber splitter enclosure, shaped hollow fluid Y, hose branch union, and rebar/structural tension anchors. These should be modeled only when the underlying interaction is declared and their geometry is testable.

## Reuse and verification

- `test_library_branches.py`: 15 source-level tests for continuity, exact wire counts, connector geometry, deterministic sag, facing, and no cubes
- `library_verify.py`: independent native Blender/GLB validation checks exactly eight connected conductor meshes, correct A/B/C route mapping, 16 mini ferrules, three or five wraps, complete Blender metadata, and **zero block-shaped terminal housing meshes**
- `library_geometry.export_obj()`: editable preview geometry for external inspection
- `library_blender.py`: new editable `.blend`, `.glb` and Cycles PNG in the existing FMPL module; no source overwrite, no new GitHub workflow, no plugin install

**Approval boundary:** A visually good Y is still not an electrically certified splice, circuit net, tensile-rated support, or in-game Factorio connection. Native validation must pass and an actual render must be inspected before this geometry can be promoted beyond preview.

## Ordered-lane clearance rule

The eight incoming conductors are deliberately sorted by their **physical cross-section position**, not arbitrarily by original wire number. The upper half of the circular trunk bundle follows the upper branch, the lower half follows the other. Each wire retains its local winding index as the tangent turns into its target port, avoiding the tangles that arise from reassigning four random wires to each exit.

There are eight continuous source-to-exit centerlines, each with bounded deterministic sag variation. The builder samples **51 positions per trunk section and 51 per branch section** for all relevant wire pairs, measures their shortest normalized cross-section center distance, and requires a positive clearance beyond the actual insulated strand diameter. The proof receipt includes the minimum center-to-center distance and corresponding surface gap; failure is explicit rather than replacing intersecting geometry with a cosmetic jacket.

The three primary harness boots are short **tapered hollow tubes**, with interior diameters checked against the conductor envelope. Mini ferrules also have a real annular clearance around each insulated strand. They are distinct from electrical terminal blocks, and none extend the standardized public connection point outside the nominal fixture.
