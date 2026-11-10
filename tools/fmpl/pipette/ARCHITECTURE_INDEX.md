# FMPL Pipette — Architecture Index (v1.0)

> **Status: indexed, not yet fully modeled.** This is the authoritative source-visible work list for the next geometry-generation stage. The existing Pipette v0.1 mesh builder and its four earlier Blender proofs remain unchanged. The 140 variants below are specifications and *not* claims of completed Blender assets, approved materials, game-native connections or engineering certification.

**Machine-readable companions:** [architecture types](architecture_catalog.v1.json) · [77 joint types](joint_catalog.v1.json) · [20 stiffness profiles](stiffness_profiles.v1.json) · [nine canonical comparison fixtures](comparison_fixture.v1.json) · [original v0.1 type registry](type_registry.json).

## Design principle

Keep four axes distinct: **carrier construction** (what the section looks like), **surface material** (what it is visually made of), **deformation behavior** (how its shape changes between fixed endpoints), and **joint/termination** (what physical geometry mates it). These are composable, but incompatible combinations must refuse to build rather than silently substituting generic tubes, brass rings, or unconnected wire branches.

The baseline v0.1 code knows eight broad carrier families. These newly indexed subtypes prescribe distinct cross-section profiles, joint choices and stiffness rules; they are awaiting specific procedural generators and approval.

## Summary

| Group | Profiles |
|:---|---:|
| Metal process and legacy piping | 18 |
| Polymer, composite, glass and ceramic piping | 14 |
| Instrumentation and fine tubing | 12 |
| Flexible fluid and process hoses | 14 |
| Electrical metal and polymer conduits | 18 |
| Individual wires and multicore cables | 23 |
| Wiring housings, protection sleeves and open channels | 18 |
| Cables, ropes and mechanical tension members | 11 |
| Reinforcing bars, meshes and cages | 12 |
| **Total** | **140** |

The other axis counts are **77 physically distinguished connection types** and **20 deformation/stiffness presets**. These are indices, not tested geometry completion counts.

## Mandatory standardized demonstration rig

All comparable material and construction samples share exactly the same **nominal 0.12 Blender-unit outer envelope**, common center `(0, 0, 0.65)`, and **1.2 Blender-unit radial endpoint distance** from the junction. Public socket coordinates and outward normals come **only** from [comparison_fixture.v1.json](comparison_fixture.v1.json). Per-material fitted hardware and internal conductors may differ, but their public sockets cannot move. The fixture is for visual comparison, *not* an implicit Factorio tile or real-world dimension conversion.

### Canonical Y / wye ports

| Port | X (BU) | Y (BU) | Z (BU) | Normal XY |
|:---|---:|---:|---:|:---|
| A | -1.200000000 | 0.000000000 | 0.650000000 | (-1, 0) |
| B | 0.848528137 | 0.848528137 | 0.650000000 | (0.707106781, 0.707106781) |
| C | 0.848528137 | -0.848528137 | 0.650000000 | (0.707106781, -0.707106781) |

The hub is exactly `(0, 0, 0.65)`. A single-wire Y, eight-wire breakout Y, historical cast/wiped lead-pipe Y, galvanized steel Y and corrugated conduit Y all use these *same named endpoint placements*. Their junction meshes are **not** interchangeable. A wire Y is an insulated splice/branch block; a fluid Y has a true shared bore; a protective-conduit Y has an actual Y-shaped sheath and a compatible cable entry, with the contents' electrical connectivity handled separately.

Nine fixture shapes: `straight` · `elbow_45` · `elbow_90` · `tee` · `wye` · `cross_connected` · `cross_isolated` · `reducer` · `bulkhead`.

### Eight-wire example: deliberate differential slack

Eight individual conductors leave a common *public* socket envelope, but must have their own internal anchor offsets, paths and natural sag. Use the deterministic seed `17021` and the per-wire sag multipliers:

```text
0.71, 0.9, 1.12, 0.83, 1.25, 1.03, 1.36, 0.97
```

For normalized span coordinate `t` between 0 and 1, start with a smooth gravity-like visible drape of `-4 * sag_i * t * (1-t)` in Z, where `sag_i` is the span-scaled visual slack of that conductor. Add *small*, bounded lateral offsets multiplied by a zero-at-ends envelope; keep the eight wires mutually coherent and constrain crossings. **All exterior endpoint XYZ positions remain exact.** This is a visual deformation rule, not simulated load-bearing elasticity.

## All indexed architecture types

Each `Section model` is a distinct geometry target. Some share manufacturing shapes but differ in wall layers, port hardware or visible profile. `Joint choices` are catalog eligibility requests pending measured mating fit, not automatic v0.1 supported fittings.

### Metal process and legacy piping (18)

| Architecture ID | Section model | Stiffness | Eligible joints |
|:---|:---|:---|:---|
| **Flanged cast-iron pipe** `pipe_cast_iron_flanged` | `cast_hollow_annulus` | `fixed` | `flange`, `union` |
| **Cast-iron bell-spigot line** `pipe_cast_iron_bell_spigot` | `bell_end_hollow` | `fixed` | `bell_spigot`, `caulked_hub` |
| **Threaded galvanized-steel pipe** `pipe_galvanized_threaded` | `threaded_hollow` | `fixed` | `threaded`, `union` |
| **Threaded black iron pipe** `pipe_black_iron_threaded` | `threaded_hollow` | `fixed` | `threaded`, `union` |
| **Seamless carbon-steel process pipe** `pipe_carbon_steel_seamless` | `smooth_hollow` | `fixed` | `butt_weld`, `flange` |
| **Seam-welded steel process pipe** `pipe_carbon_steel_welded` | `longitudinal_welded_hollow` | `fixed` | `butt_weld`, `flange` |
| **Stainless process piping** `pipe_stainless_process` | `smooth_hollow` | `fixed` | `butt_weld`, `flange` |
| **Sanitary stainless process tube** `pipe_stainless_sanitary` | `smooth_hollow` | `fixed` | `sanitary_clamp`, `union` |
| **Rigid drawn copper pipe** `pipe_copper_hard` | `smooth_hollow` | `formed_metal` | `solder`, `braze` |
| **Soft annealed copper pipe** `pipe_copper_annealed` | `smooth_hollow` | `semi_rigid` | `flare`, `compression` |
| **Brass small-bore hardline** `pipe_brass_hardline` | `small_smooth_hollow` | `formed_metal` | `bite_ferrule`, `compression` |
| **Lightwall aluminum tube** `pipe_aluminum_lightwall` | `thin_hollow` | `formed_metal` | `compression`, `flange` |
| **Bronze cast conduit-pipe** `pipe_bronze_cast` | `cast_hollow_annulus` | `fixed` | `threaded`, `flange` |
| **Historical lead service pipe** `pipe_lead_historical` | `soft_deformed_hollow` | `semi_rigid` | `lead_wiped_joint`, `bell_spigot` |
| **Jacketed double-wall process pipe** `pipe_jacketed_double_wall` | `concentric_hollow_bores` | `fixed` | `flange`, `butt_weld` |
| **Lined process steel pipe** `pipe_lined_chemical` | `liner_inside_steel_annulus` | `fixed` | `flange`, `union` |
| **Lagged insulated steam pipe** `pipe_insulated_steam` | `insulation_over_hollow` | `fixed` | `flange`, `butt_weld` |
| **Metal accordion expansion section** `pipe_metal_bellows` | `annular_corrugated_hollow` | `spring_metal_flex` | `bellows_flange`, `expansion_joint` |

### Polymer, composite, glass and ceramic piping (14)

| Architecture ID | Section model | Stiffness | Eligible joints |
|:---|:---|:---|:---|
| **PVC pressure pipe** `pipe_pvc_pressure` | `smooth_hollow` | `fixed` | `solvent_weld`, `union` |
| **CPVC process pipe** `pipe_cpvc` | `smooth_hollow` | `fixed` | `solvent_weld`, `union` |
| **ABS drain and vent pipe** `pipe_abs_drain` | `smooth_hollow` | `fixed` | `solvent_weld`, `bell_spigot` |
| **HDPE fused pipe** `pipe_hdpe_fused` | `smooth_hollow` | `semi_rigid` | `heat_fusion`, `electrofusion` |
| **Corrugated HDPE drainage pipe** `pipe_hdpe_corrugated` | `annular_corrugated_hollow` | `corrugated_polymer` | `bell_spigot`, `slip_coupler` |
| **PEX water supply tube** `pipe_pex_flexible` | `smooth_hollow` | `semi_rigid` | `pex_crimp`, `push_fit` |
| **Polypropylene fusion pipe** `pipe_pp_fused` | `smooth_hollow` | `semi_rigid` | `heat_fusion`, `union` |
| **PVDF chemical pipe** `pipe_pvdf` | `smooth_hollow` | `semi_rigid` | `heat_fusion`, `flange` |
| **Glass-fiber composite pipe** `pipe_fiber_reinforced` | `laminated_hollow` | `fixed` | `flange`, `bell_spigot` |
| **Multilayer PEX/aluminum tube** `pipe_pex_al_pex` | `multilayer_hollow` | `semi_rigid` | `compression`, `pex_crimp` |
| **Acrylic clear process pipe** `pipe_transparent_acrylic` | `transparent_hollow` | `fixed` | `flange`, `compression` |
| **Borosilicate glass pipe** `pipe_borosilicate_glass` | `transparent_hollow` | `fixed` | `glass_ground_joint`, `compression` |
| **Vitrified ceramic pipe** `pipe_vitrified_clay` | `thick_bell_hollow` | `fixed` | `ceramic_gasket`, `bell_spigot` |
| **Reinforced concrete culvert** `pipe_concrete_culvert` | `thick_cast_hollow` | `fixed` | `bell_spigot`, `ceramic_gasket` |

### Instrumentation and fine tubing (12)

| Architecture ID | Section model | Stiffness | Eligible joints |
|:---|:---|:---|:---|
| **Stainless capillary tube** `tube_stainless_capillary` | `fine_smooth_hollow` | `formed_metal` | `bite_ferrule`, `compression` |
| **Copper capillary tube** `tube_copper_capillary` | `fine_smooth_hollow` | `semi_rigid` | `braze`, `compression` |
| **Brass instrument tube** `tube_brass_instrument` | `fine_smooth_hollow` | `formed_metal` | `compression`, `flare` |
| **Nylon pneumatic tube** `tube_nylon_pneumatic` | `fine_smooth_hollow` | `flex_polymer` | `push_fit`, `compression` |
| **Polyurethane pneumatic tube** `tube_pu_pneumatic` | `fine_smooth_hollow` | `soft_hose` | `push_fit`, `quick_fluid_disconnect` |
| **PTFE chemical microtubing** `tube_ptfe_chemical` | `fine_smooth_hollow` | `semi_rigid` | `compression`, `flare` |
| **Soft silicone laboratory tubing** `tube_silicone_soft` | `translucent_hollow` | `soft_hose` | `hose_barb_clamp`, `hose_crimp` |
| **Flexible clear vinyl tubing** `tube_vinyl_clear` | `transparent_hollow` | `soft_hose` | `hose_barb_clamp`, `push_fit` |
| **Multi-lumen instrument tube** `tube_multi_lumen` | `multiple_parallel_bores` | `flex_polymer` | `push_fit`, `compression` |
| **Retractile helical pneumatic tube** `tube_retractile_coil` | `helical_coil_hollow` | `spring_guarded` | `quick_fluid_disconnect`, `push_fit` |
| **Glass diagnostic capillary** `tube_glass_capillary` | `fine_transparent_hollow` | `fixed` | `glass_ground_joint`, `compression` |
| **Formed copper instrument manifold** `tube_copper_manifold` | `smooth_hollow` | `formed_metal` | `braze`, `solder` |

### Flexible fluid and process hoses (14)

| Architecture ID | Section model | Stiffness | Eligible joints |
|:---|:---|:---|:---|
| **Soft rubber coolant hose** `hose_rubber_coolant` | `smooth_hollow` | `soft_hose` | `hose_barb_clamp`, `hose_crimp` |
| **Preformed radiator hose** `hose_molded_radiator` | `molded_elbow_hollow` | `semi_rigid` | `hose_barb_clamp`, `hose_crimp` |
| **Braided hydraulic hose** `hose_hydraulic_braided` | `multi_layer_braided_hollow` | `reinforced_hose` | `hose_crimp`, `flare` |
| **Spiral-wire hydraulic hose** `hose_hydraulic_spiral` | `helical_wire_reinforced_hollow` | `reinforced_hose` | `hose_crimp`, `flange` |
| **Transparent braided PVC hose** `hose_pvc_braided` | `transparent_mesh_reinforced_hollow` | `soft_hose` | `hose_barb_clamp`, `hose_crimp` |
| **Spring-reinforced suction hose** `hose_wire_suction` | `helical_wire_reinforced_hollow` | `spring_guarded` | `hose_barb_clamp`, `hose_crimp` |
| **Stainless braided flexible hose** `hose_stainless_braided` | `braided_over_inner_hollow` | `spring_metal_flex` | `flare`, `hose_crimp` |
| **Annular corrugated metal hose** `hose_metal_annular` | `annular_corrugated_hollow` | `spring_metal_flex` | `bellows_flange`, `hose_crimp` |
| **Helical corrugated metal hose** `hose_metal_helical` | `helical_corrugated_hollow` | `spring_metal_flex` | `bellows_flange`, `hose_crimp` |
| **Layflat discharge hose** `hose_layflat` | `flattened_hollow_web` | `soft_hose` | `camlock`, `hose_barb_clamp` |
| **Vacuum cleaner corrugated hose** `hose_vacuum_corrugated` | `annular_corrugated_hollow` | `spring_guarded` | `hose_barb_clamp`, `quick_fluid_disconnect` |
| **Insulated flexible hot hose** `hose_insulated_hot` | `insulated_multilayer_hollow` | `reinforced_hose` | `hose_crimp`, `flange` |
| **Fabric expansion bellows boot** `hose_fabric_expansion` | `fabric_accordion_hollow` | `soft_hose` | `bellows_flange`, `expansion_joint` |
| **Twin bonded fluid hose** `hose_twin_bonded` | `parallel_dual_hollow` | `reinforced_hose` | `hose_barb_clamp`, `hose_crimp` |

### Electrical metal and polymer conduits (18)

| Architecture ID | Section model | Stiffness | Eligible joints |
|:---|:---|:---|:---|
| **Rigid metal conduit RMC** `conduit_rmc_threaded` | `heavy_hollow_metal` | `fixed` | `rigid_threaded_hub`, `locknut_bushing` |
| **Intermediate metal conduit IMC** `conduit_imc_threaded` | `medium_hollow_metal` | `fixed` | `rigid_threaded_hub`, `compression_conduit` |
| **Thinwall EMT electrical tubing** `conduit_emt_thinwall` | `thin_hollow_metal` | `formed_metal` | `compression_conduit`, `locknut_bushing` |
| **FMC helical flexible metal conduit** `conduit_fmc_interlocked` | `interlocked_helical_metal_strip` | `spring_metal_flex` | `flex_conduit_connector`, `compression_conduit` |
| **Flexible metallic tubing FMT** `conduit_fmt_light_flex` | `thin_interlocked_helical_strip` | `spring_metal_flex` | `flex_conduit_connector`, `compression_conduit` |
| **LFMC liquidtight coated metal flex** `conduit_lfmc_jacketed` | `interlocked_metal_core_and_jacket` | `flex_polymer` | `liquidtight_connector`, `cable_gland` |
| **Rigid PVC electrical conduit** `conduit_pvc_rigid` | `smooth_hollow_polymer` | `fixed` | `solvent_conduit_coupler`, `locknut_bushing` |
| **ENT corrugated nonmetallic tubing** `conduit_ent_corrugated` | `annular_corrugated_polymer` | `corrugated_polymer` | `snap_conduit`, `locknut_bushing` |
| **Layered liquidtight nonmetallic flex** `conduit_lfnc_layered` | `smooth_jacket_reinforced_core` | `corrugated_polymer` | `liquidtight_connector`, `cable_gland` |
| **Integral-rib nonmetallic flex conduit** `conduit_lfnc_integral` | `corrugated_outer_smooth_inner` | `corrugated_polymer` | `liquidtight_connector`, `flex_conduit_connector` |
| **Double-corrugated nonmetallic conduit** `conduit_lfnc_double` | `corrugated_inner_outer` | `corrugated_polymer` | `liquidtight_connector`, `flex_conduit_connector` |
| **HDPE underground electrical duct** `conduit_hdpe_underground` | `smooth_hollow_polymer` | `semi_rigid` | `solvent_conduit_coupler`, `compression_conduit` |
| **Corrugated split harness tubing** `conduit_split_corrugated_loom` | `slit_annular_corrugated_shell` | `corrugated_polymer` | `split_loom_clip`, `panel_grommet` |
| **Closed corrugated harness tubing** `conduit_unsplit_corrugated_loom` | `annular_corrugated_closed_shell` | `corrugated_polymer` | `sleeve_overlap`, `panel_grommet` |
| **Open spiral plastic tubing** `conduit_helical_plastic_wrap` | `open_spiral_polymer_strip` | `flex_polymer` | `sleeve_overlap`, `split_loom_clip` |
| **Square-lock metal strip conduit** `conduit_squarelock_metal` | `squarelock_helical_strip` | `spring_metal_flex` | `flex_conduit_connector`, `cable_gland` |
| **Jointed metal or polymer conduit** `conduit_articulated_segmented` | `discrete_socketed_rings` | `segmented_joint` | `flex_conduit_connector`, `cable_gland` |
| **Ball-link articulated protective sheath** `conduit_ball_joint_armored` | `discrete_ball_socket_shells` | `segmented_joint` | `flex_conduit_connector`, `panel_grommet` |

### Individual wires and multicore cables (23)

| Architecture ID | Section model | Stiffness | Eligible joints |
|:---|:---|:---|:---|
| **Bare solid copper wire** `wire_single_bare_copper` | `solid_round_conductor` | `loose_wire` | `wire_solder_splice`, `ring_lug` |
| **Insulated solid conductor** `wire_single_insulated_solid` | `solid_core_insulated` | `loose_wire` | `crimp_butt`, `ring_lug` |
| **Insulated stranded copper wire** `wire_single_insulated_stranded` | `multi_strand_insulated` | `high_flex_cord` | `crimp_butt`, `spade_lug` |
| **Fine tinsel high-flex lead** `wire_tinsel_high_flex` | `tinsel_conductor_in_jacket` | `high_flex_cord` | `crimp_butt`, `plug_socket` |
| **Twisted-pair cable** `wire_twisted_pair` | `two_helically_twisted_cores` | `twisted_bundle` | `crimp_ferrule`, `terminal_block` |
| **Four-core twisted quad** `wire_twisted_quad` | `four_cores_helix` | `twisted_bundle` | `plug_socket`, `crimp_ferrule` |
| **Eight-core four-pair data cable** `wire_four_pair_data` | `four_twisted_pairs_in_jacket` | `jacketed_cable` | `plug_socket`, `insulation_displacement` |
| **Flat parallel ribbon cable** `wire_flat_ribbon` | `flat_parallel_cores` | `ribbon_flex` | `insulation_displacement`, `plug_socket` |
| **Parallel zip flex cord** `wire_zip_parallel` | `two_fused_parallel_jackets` | `high_flex_cord` | `crimp_butt`, `ring_lug` |
| **Coaxial shielded RF cable** `wire_coax` | `concentric_conductors_and_dielectric` | `jacketed_cable` | `coax_connector`, `cable_gland` |
| **Triaxial electrical cable** `wire_triax` | `triple_coaxial_layer` | `jacketed_cable` | `coax_connector`, `cable_gland` |
| **Jacketed multicore control cable** `wire_multicore_jacketed` | `jacketed_multi_core` | `jacketed_cable` | `cable_gland`, `plug_socket` |
| **Eight-wire loose harness** `wire_eight_loose_bundle` | `eight_independent_curves` | `loose_bundle` | `crimp_butt`, `terminal_block` |
| **Eight-wire periodically tied loom** `wire_eight_laced_loom` | `eight_cores_periodic_ties` | `flex_bundle` | `terminal_block`, `plug_socket` |
| **Eight-wire jacketed harness** `wire_eight_sheathed` | `eight_cores_under_jacket` | `jacketed_cable` | `cable_gland`, `plug_socket` |
| **Braided shield instrumentation cable** `wire_braided_shield` | `inner_cores_metal_braid_shield` | `jacketed_cable` | `shield_termination`, `cable_gland` |
| **Mineral insulated metal sheath cable** `wire_mineral_insulated` | `metal_jacket_with_insulated_cores` | `semi_rigid` | `compression_conduit`, `cable_gland` |
| **Heavy shielded power cable** `wire_hv_screened_power` | `insulated_metal_shielded_heavy_core` | `reinforced_hose` | `ring_lug`, `shield_termination` |
| **Single optical fiber** `wire_optical_single` | `glass_core_and_buffer` | `high_flex_cord` | `fiber_splice`, `fiber_bulkhead` |
| **Multifiber optical bundle** `wire_optical_bundle` | `multiple_glass_cores_in_tube` | `jacketed_cable` | `fiber_splice`, `fiber_bulkhead` |
| **Flat flex film circuit** `wire_flat_flex_pcb` | `flat_film_conductor_traces` | `ribbon_flex` | `plug_socket`, `insulation_displacement` |
| **Flat braided earth strap** `wire_ground_braid` | `flat_copper_braid` | `high_flex_cord` | `ring_lug`, `busbar_bolt` |
| **Flat copper busbar** `wire_busbar_flat` | `rigid_flat_metal_bar` | `fixed` | `busbar_bolt`, `terminal_block` |

### Wiring housings, protection sleeves and open channels (18)

| Architecture ID | Section model | Stiffness | Eligible joints |
|:---|:---|:---|:---|
| **Expandable PET braided sleeving** `housing_pet_braided_sleeve` | `open_diamond_braid_sleeve` | `flex_polymer` | `sleeve_overlap`, `heatshrink_breakout` |
| **Metal armored braid sleeve** `housing_metal_braided_sleeve` | `woven_metal_armor_shell` | `flex_polymer` | `shield_termination`, `cable_gland` |
| **Open expandable cable mesh** `housing_mesh_guard` | `large_open_mesh_sleeve` | `flex_polymer` | `sleeve_overlap`, `heatshrink_breakout` |
| **Heatshrink splice sleeve** `housing_heatshrink` | `form_fitted_smooth_sleeve` | `semi_rigid` | `heatshrink_breakout`, `panel_grommet` |
| **Longitudinal split loom cover** `housing_split_loom` | `slitted_annular_corrugated_shell` | `corrugated_polymer` | `split_loom_clip`, `sleeve_overlap` |
| **Spiral harness wrap** `housing_spiral_wrap` | `open_helical_plastic_strip` | `flex_polymer` | `sleeve_overlap`, `split_loom_clip` |
| **Fabric-wrapped cable loom** `housing_harness_tape` | `overlapping_helix_tape` | `flex_bundle` | `lacing`, `strap_bracket` |
| **Traditional laced wire harness** `housing_laced_harness` | `laced_separate_cable_cores` | `flex_bundle` | `lacing`, `strap_bracket` |
| **Articulated drag-chain cable carrier** `housing_drag_chain` | `open_hinged_cable_track` | `segmented_joint` | `drag_chain_link`, `strap_bracket` |
| **Rigid enclosed wire track** `housing_rigid_track` | `closed_u_channel_and_lid` | `fixed` | `tray_splice`, `strap_bracket` |
| **Open ladder cable tray** `housing_ladder_tray` | `parallel_rails_rung_tray` | `fixed` | `tray_splice`, `strap_bracket` |
| **Perforated metal cable tray** `housing_perforated_tray` | `folded_perforated_sheet` | `fixed` | `tray_splice`, `strap_bracket` |
| **Welded wire cable basket** `housing_mesh_basket` | `open_welded_wire_grid` | `fixed` | `tray_splice`, `strap_bracket` |
| **Metal wireway with hinged lid** `housing_metal_wireway` | `closed_rectangular_box` | `fixed` | `wireway_hinge`, `locknut_bushing` |
| **Slotted panel wiring duct** `housing_slotted_duct` | `u_channel_with_slotted_ribs` | `fixed` | `snap_conduit`, `wireway_hinge` |
| **Rectangular surface raceway** `housing_rectangular_raceway` | `rectangular_snap_cover` | `fixed` | `snap_conduit`, `panel_grommet` |
| **Multiport wiring junction box** `housing_junction_box` | `closed_box_seated_cable_ports` | `fixed` | `conduit_junction_box`, `locknut_bushing` |
| **Open helical metal cable guard** `housing_spring_guard` | `exposed_helical_spring` | `spring_guarded` | `sleeve_overlap`, `panel_grommet` |

### Cables, ropes and mechanical tension members (11)

| Architecture ID | Section model | Stiffness | Eligible joints |
|:---|:---|:---|:---|
| **Steel wire rope 1 by 7** `cable_steel_1x7` | `seven_strand_rope` | `tensioned` | `swaged_eye`, `thimble_eye` |
| **Flexible steel wire rope 7 by 19** `cable_steel_7x19` | `multi_strand_wire_rope` | `tensioned` | `swaged_eye`, `wire_rope_clip` |
| **Galvanized guy-wire** `cable_guy_galvanized` | `galvanized_twisted_strand` | `tensioned` | `turnbuckle`, `swaged_eye` |
| **Plastic-coated steel tension cable** `cable_coated_steel` | `steel_rope_jacket` | `tensioned` | `swaged_eye`, `turnbuckle` |
| **Braided synthetic cord** `cable_synthetic_braid` | `fine_plant_or_synthetic_braid` | `rope_soft` | `thimble_eye`, `rope_knot` |
| **Three-ply hemp rope** `cable_hemp_threeply` | `three_large_helical_strands` | `rope_soft` | `rope_knot`, `thimble_eye` |
| **Linked steel chain** `cable_steel_chain` | `solid_interlocked_oval_links` | `segmented_joint` | `chain_shackle`, `clevis` |
| **Adjustable steel tie rod** `cable_turnbuckle_rod` | `rod_two_ended_turnbuckle` | `tensioned` | `turnbuckle`, `clevis` |
| **Bowden mechanical control cable** `cable_bowden` | `inner_cable_helical_sheath` | `flex_polymer` | `bowden_end`, `swaged_eye` |
| **Spring-coiled tension tether** `cable_coiled_tether` | `helical_solid_tether` | `spring_guarded` | `swaged_eye`, `thimble_eye` |
| **Flat woven tension strap** `cable_flat_webbing` | `flat_woven_web` | `rope_soft` | `harness_sewn_loop`, `clevis` |

### Reinforcing bars, meshes and cages (12)

| Architecture ID | Section model | Stiffness | Eligible joints |
|:---|:---|:---|:---|
| **Plain round reinforcing bar** `rebar_plain_round` | `solid_round_bar` | `formed_rebar` | `rebar_lap`, `rebar_mechanical_coupler` |
| **Deformed ribbed reinforcing steel** `rebar_deformed_ribbed` | `solid_deformed_ribbed` | `formed_rebar` | `rebar_lap`, `rebar_threaded_coupler` |
| **Historical twisted deformed bar** `rebar_twisted_legacy` | `solid_twisted_nonround` | `formed_rebar` | `rebar_lap`, `rebar_mechanical_coupler` |
| **Stainless reinforcing bar** `rebar_stainless` | `solid_deformed_ribbed` | `formed_rebar` | `rebar_threaded_coupler`, `rebar_lap` |
| **Galvanized reinforcing bar** `rebar_galvanized` | `solid_deformed_ribbed` | `formed_rebar` | `rebar_mechanical_coupler`, `rebar_lap` |
| **Epoxy coated rebar** `rebar_epoxy` | `solid_deformed_ribbed` | `formed_rebar` | `rebar_mechanical_coupler`, `rebar_lap` |
| **Glass-fiber composite rebar** `rebar_fiber_glass` | `solid_helical_composite_ribs` | `formed_rebar` | `rebar_lap`, `rebar_mechanical_coupler` |
| **Bent hooked rectangular stirrup** `rebar_stirrup` | `bent_solid_rebar_loop` | `formed_rebar` | `rebar_hook`, `tie_wire` |
| **Welded reinforcing mesh** `rebar_welded_mesh` | `solid_grid_crossbars` | `fixed` | `welded_mesh`, `tie_wire` |
| **Cylindrical rebar cage** `rebar_circular_cage` | `bars_and_ring_ties` | `fixed` | `tie_wire`, `rebar_lap` |
| **Threaded reinforcement splice** `rebar_threaded_splice` | `solid_ribs_threaded_coupler` | `formed_rebar` | `rebar_threaded_coupler`, `rebar_mechanical_coupler` |
| **Steel prestress tendon** `rebar_prestress_tendon` | `solid_strand_tendon` | `tensioned` | `mechanical_wedge`, `swaged_eye` |

## Joint/termination index

The 77 entries cover fluid/pipe interfaces, raceway entries, electrical contacts, mechanical anchors and reinforcement splices. End hardware and branch *topology* are independent choices; no universal joining ring exists.

| Joint ID | Typed domains | Required visible fitting geometry |
|:---|:---|:---|
| `flange` | fluid | Pipe walls remain hollow; bore clear through gasket |
| `union` | fluid | Two coaxial mating halves and service nut |
| `threaded` | fluid | Matched male and female threaded shoulders |
| `butt_weld` | fluid | Aligned hollow pipe annuli and visible weld bead |
| `socket_weld` | fluid | Real socket insertion and external fillet |
| `grooved_coupling` | fluid | Two grooved pipe ends and gasketed clamp |
| `bell_spigot` | fluid | Enlarged socket and seated spigot |
| `caulked_hub` | fluid | Historic lead-style packed hub visual only |
| `compression` | fluid | Ferrule around inserted tube, not decorative ring |
| `bite_ferrule` | fluid | Two ferrules with receiving boss |
| `sanitary_clamp` | fluid | Pair of ferrules and clamp |
| `solder` | fluid | Copper cup and discrete solder line |
| `braze` | fluid | Joint brazing ring and continuous hollow bore |
| `lead_wiped_joint` | fluid | Historically representative bulged solder seam, not installation advice |
| `solvent_weld` | fluid | Molded polymer socket and inserted pipe |
| `heat_fusion` | fluid | Fused thermoplastic hollow wall |
| `electrofusion` | fluid | Fused pipe sleeves, optional electrotab |
| `pex_crimp` | fluid | Inside barb and outside retained crimp |
| `push_fit` | fluid | Push-in collet and positive socket stop |
| `flare` | fluid | Conical tube flare and compression nut |
| `hose_barb_clamp` | fluid | Barbed insertion and band/clamp hardware |
| `hose_crimp` | fluid | Crimp metal ferrule and inserted tail |
| `camlock` | fluid | Real paired grooves, cam handles and seal |
| `quick_fluid_disconnect` | fluid | Locking collar with positive stop |
| `bellows_flange` | fluid | Bellows corrugation seats inside flange |
| `expansion_joint` | fluid | Axial movement allowance between fixed flanges |
| `glass_ground_joint` | fluid | Mating glass tapered ends |
| `ceramic_gasket` | fluid | Thick ceramic annular socket |
| `slip_coupler` | fluid | Overlapping tubular sleeve |
| `rigid_threaded_hub` | enclosure | Receiving metal hub and locknut |
| `compression_conduit` | enclosure | Compression raceway gland not fluid hardware |
| `locknut_bushing` | enclosure | Insulated entry lip and thread locknut |
| `flex_conduit_connector` | enclosure | Terminator captures conduit winding |
| `liquidtight_connector` | enclosure | Gasketed raceway entry and strain relief |
| `cable_gland` | enclosure, electrical | Cable diameter-matched grommet with compression shell |
| `solvent_conduit_coupler` | enclosure | Rigid polymer receiving socket |
| `snap_conduit` | enclosure | Real latching lip and receiving slot |
| `split_loom_clip` | enclosure | Clips retain accessible split loom seam |
| `sleeve_overlap` | enclosure | Sleeve overlaps underlying protected line |
| `panel_grommet` | enclosure | Grommet seats in declared panel thickness |
| `heatshrink_breakout` | enclosure, electrical | Branch boot surrounds separate insulated members |
| `lacing` | enclosure, electrical | Deterministic ties at interval |
| `strap_bracket` | enclosure | Support attached to declared host object |
| `drag_chain_link` | enclosure | Rigid articulated cable carrier links with known hinges |
| `tray_splice` | enclosure | Bolted plate joins open tray rails |
| `wireway_hinge` | enclosure | Separate hinged or removable lid |
| `conduit_junction_box` | enclosure | Enclosed body with distinct socket openings |
| `crimp_butt` | electrical | Two conductors enter opposed crimp barrel |
| `wire_solder_splice` | electrical | Stripped localized copper joint and insulating shell |
| `lever_terminal` | electrical | Lever and inserted wire contact |
| `terminal_block` | electrical | Electrical screw and contact seat |
| `ring_lug` | electrical | Flat terminal eye with barrel |
| `spade_lug` | electrical | Flat fork terminal |
| `crimp_ferrule` | electrical | Crimp barrel at wire end |
| `insulation_displacement` | electrical | Blade slot aligned with insulated core |
| `plug_socket` | electrical | Multiple pins and keyed housing |
| `coax_connector` | electrical | Concentric signal core and shield at contact |
| `fiber_splice` | electrical | Precision optical alignment, no ad-hoc Y of bare glass |
| `fiber_bulkhead` | electrical | Fiber ferrule seated in panel |
| `shield_termination` | electrical | Braided shield electrically terminated to rim |
| `busbar_bolt` | electrical | Solid flat busbars and retained bolt |
| `mechanical_wedge` | mechanical | Solid cable secured in tapered wedge |
| `swaged_eye` | mechanical | Return loop and swaged crimp sleeve |
| `thimble_eye` | mechanical | Return cable around visible thimble |
| `wire_rope_clip` | mechanical | True U-bolt and saddled returning cable |
| `clevis` | mechanical | Load pin through matching eye |
| `turnbuckle` | mechanical | Tension adjustment with opposing threads |
| `chain_shackle` | mechanical | Pinned link attachment for steel chain |
| `rope_knot` | mechanical | Recognizable tied rope geometry |
| `bowden_end` | mechanical | Sleeve termination while inner cable continues |
| `harness_sewn_loop` | mechanical | Folded webbing with load-stitch pattern |
| `rebar_lap` | reinforcement | Two solid bars with designed overlap |
| `rebar_threaded_coupler` | reinforcement | Mechanical thread sleeve around solid rebar |
| `rebar_mechanical_coupler` | reinforcement | No hollow fluid bore; solid bar seating |
| `welded_mesh` | reinforcement | Solid transverse bars and contact welds |
| `rebar_hook` | reinforcement | Continuous bent solid bar |
| `tie_wire` | reinforcement | Fine loops around rebar joint |

## Stiffness/deformation index

Sag is a **visual normalized fraction of the free span**, not an engineering property. Radius values are relative to visible outer diameter; null indicates geometry defined by joints or rigid authored bends rather than free hose-like curvature.

| Preset | Nominal free sag / span | Visual minimum bend radius (× OD) | Geometry behavior |
|:---|---:|---:|:---|
| `fixed` | 0.0% | 0 | formed rigid, no drape |
| `formed_metal` | 1.2% | 3 | retains bent metal shape, tiny unsupported bow |
| `semi_rigid` | 3.0% | 5 | curved polymer or annealed tube remembers a shape |
| `spring_metal_flex` | 5.5% | 4 | metal interlocking helix retains visible spring stiffness |
| `corrugated_polymer` | 9.5% | 3 | distributed polymer corrugation bends, not a sharp elbow |
| `flex_polymer` | 11.0% | 3 | flex sheath with drooping centerline |
| `soft_hose` | 14.5% | 3 | soft drape; centerline cannot collapse bore |
| `reinforced_hose` | 8.0% | 5 | reinforcement limits tight bends and droop |
| `spring_guarded` | 6.5% | 4 | coiled reinforcement pitch independent of path shape |
| `loose_wire` | 16.5% | 2 | small wire hangs naturally between fixed terminals |
| `loose_bundle` | 11.0% | 2 | independent core sag from shared coherent bundle frame |
| `flex_bundle` | 10.0% | 3 | moderate group sag with independent core slack between ties |
| `twisted_bundle` | 11.0% | 3 | group droop plus continuous twisted-pair lay |
| `jacketed_cable` | 9.5% | 4 | cable jacket bows as a coherent tube; inner cores fan only at terminals |
| `high_flex_cord` | 18.0% | 2 | soft gravity-like drape, fixed terminal seats |
| `ribbon_flex` | 7.5% | 3 | main bending around flat ribbon preferred axis |
| `tensioned` | 1.2% | authored/NA | near-straight taut line with no hose-like catenary |
| `rope_soft` | 16.0% | 2 | soft drape in braided rope/webbing |
| `segmented_joint` | 4.5% | 4 | bending occurs at constrained articulated joints |
| `formed_rebar` | 0.0% | 3 | solid bar, no unsupported sag; explicitly authored bends only |

## Production geometry implementation order

1. **Cross-section kernels** — true hollow annuli, multibore, split wall, rectangular raceway, open mesh/tray, metal helix, annular rings, layered sleeves, solid rope/rebar. Preserve the section's actual interior and openings only where visible or functionally necessary.
2. **Typed connector and junction kernel** — every end fitting has correct mating geometry. For Y/T/4-way, create material-correct core/hollow/insulated branch geometry with **shared frozen fixture socket positions**. No unseated collar-only stand-ins.
3. **Stiffness and drape kernel** — stable centerlines; rigid/semirigid/soft/segmented behaviors; natural per-wire loose-bundle slack variation. Support two anchors, multi-branch paths and explicit stop/strain relief.
4. **Native Blender verification** — generate a structured contact sheet or gallery across equivalent topologies; reopen each .blend and GLB, verify true hollow bores and contact offsets, inspect Cycles renders at FMPL 45° and closeups.
5. **Approved PBR materials and game adapters** — resolve materials through approved FMPL sources; only then test actual Factorio tile-relative external pipe mouths, fluidboxes and game-native connectivity. Do not bind ordinary wires to Factorio pipe diameter.

## External reference and licensing rules

Engineering references below describe construction, but **their photos/diagrams are not automatically CC0** and must not be copied into production assets:

- [EC&M: metal raceway construction](https://www.ecmweb.com/national-electrical-code/code-basics/article/55371892/nec-requirements-for-metal-raceways) — independent metallic conduit types including rigid, intermediate, EMT and spiral flexible.
- [Electri-Flex product families](https://www.electriflex.com/flexible-conduits/) — surface differences between jacketed metal, unjacketed spiral metal and nonmetallic flex.
- [Pipe Drafting & Design: fitting functions](https://www.sciencedirect.com/topics/engineering/pipe-fittings) — elbows, tees, reducers, branch types and mechanical joints.

Potential **CC0 material** sources: [Poly Haven license](https://polyhaven.com/license) and [ambientCG license](https://docs.ambientcg.com/license/). These publishers explicitly state their library assets are CC0; **do not assert that manufacturer photos or unidentified search thumbnails are CC0**. Each selected source asset still needs source URL and approved FMPL material mapping.

## Validation / scope boundary

The catalog is design data only. New connector names do not expand the existing v0.1 planner's executable fitting enum. Special cross-domain terminations (e.g. a metal-jacketed electrical line using a conduit compression collar) need explicit socket-domain review. Optical fiber Y branching requires an intentional optical splitter, not a bare glass fork; reinforcement and tension elements require anchor-specific nodes. Real mechanical force, pressure, insulation rating and ampacity are not implied.

**Repository policy:** main branch only, no new workflow, no destructive model overwrite. Existing four native Pipette prototypes are not represented here as approval of the remaining 140 indexed constructions.
