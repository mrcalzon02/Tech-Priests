# Thetazine V06 articulated core

This revision adds the requested axial stroke, small sinusoidal twist and moving side actuators to the completed V05 model. It also adds the localized passive side-bracket and crossbar details requested after the general greeble pass ended.

The checked local package is [V06 articulated core](../../../art/source-to-3d/space-platform-engines/thetazine-thruster/v06-articulated-core). It contains the packed editable source, animated physical GLB, full-color video, GIF and validation records. The ordinary runtime sprites remain V04/source35; V06 native sprite capture and integration remain open.

## Motion

- The central assembly travels approximately 0.29 BU from one stroke extreme to the other, with a small twist around its thrust axis (approximately one degree).
- The stroke combines a sine wave, a second harmonic and mild seeded periodic noise. The original occasional lateral knocks remain.
- The platform gantry, tanks, deck feet and external fluid interfaces stay fixed.
- The two outer actuators pivot at their actual pin centers. Rigid rods slide within hollow fore barrels; stepped shoulders seat in the existing collars. Shaft sections match the retained collars' actual centerlines and 48-sided circular geometry.
- The working loop is frames 1–64 at 30 fps. Frame 0 is cold; frame 65 is the working-wrap witness.

## Interfaces and mounting

The original 84 routes remain. Twenty-four world-baked leaf flexes now belong to the moving core without applying its old motion twice. Eight fixed-to-core hoses retain their original tube topology, cross sections, UVs, materials and captive unions; Pipette validates their typed socket/centerline contract at every pose. Four injector support pieces follow their actual moving receivers. Four pumpbed support pieces correctly stay on the fixed diagonal shoulders.

The localized bracket pass adds shallow bearing-shoe caps with access to the retained old bolt heads, short fore-crossbar ties and retained lower-end plates. It preserves the previous overall width and adds no general decorative batch beyond those requested joints.

## Evidence

The independently reopened leaf-flex and hose/support checks passed all 66 source poses. Exact final assembly lineage binds those measured interfaces to the later candidate. All 168 static bracket mating declarations passed; the 110 new fixed details also clear the moving assembly across 66 poses. The four replacement shaft surfaces have separate actual collar, bore, overlap and clevis checks.

All 3,202 physical meshes match the actual reimported GLB across all 66 poses within 0.000002002 BU (threshold 0.00001 BU). Working poses 1 and 65 are bit-exact in both source and export. The export preserves 21 assembly empties, 150 animation channels and all 66 cold/working/wrap timestamps.

The scoped clearance checks cover the core against the original frame and machinery, the new fixed brackets against moving parts, and all 32 changed actuator/span parts against nearby geometry. They retain documented original joint-region overlap. One related terminal-neck touch, its mirrored near-contact and an original bolt containment have separate source/export evidence; these are disclosed as retained local assembly roughness. No new unrelated interference or shaft-corridor breach was found. Original build and intermediate reports remain in the build history.

The physical GLB follows the existing policy of excluding the source-only raymarched combustion volume. Source animation previews and runtime sprite integration are distinct deliverables.

For playback, use working frames 1–64 at 30 fps. The saved scene retains the earlier capture range 1–65; frame 0 and the wrap witness 65 are exported explicitly by the export tool. The MP4 repeats the 64 working poses three times in full color. Tooling snapshots record the repository toolchain used for this revision.
