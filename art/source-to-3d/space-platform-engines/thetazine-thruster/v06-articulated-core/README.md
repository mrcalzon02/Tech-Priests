# Thetazine V06 articulated core

The central body now has axial sine/noise travel and a small sinusoidal twist about its thrust axis. The two side actuators extend, retract and swivel from their actual attachment pins. The platform frame, tanks, feet and external fluid interfaces retain their original placement. Localized bearing caps and crossbar ties complete the requested passive bracket pass.

- [Packed Blender source](thetazine-v06-articulated-core.blend)
- [Animated physical GLB](thetazine-v06-articulated-core.glb)
- [Full-color motion video](motion-preview/thetazine-v06-mechanism-cycle.mp4)
- [Looping GIF](motion-preview/thetazine-v06-mechanism-cycle.gif)
- [Four working poses](motion-preview/thetazine-v06-mechanism-poses.png)

Use working frames 1–64 at 30 fps. Frame 0 is cold and 65 is the wrap witness. The MP4 repeats the 64 working poses three times. The saved source retains the original scene range 1–65; the export tool explicitly includes 0–65.

All 3,202 physical meshes match the actual reimported export across all 66 poses within 0.000002002 BU. Working poses 1 and 65 are bit-exact in source and GLB. The export preserves 21 assembly empties and 150 animation channels. Reopening the packaged native source confirmed all 27 material image maps are packed and loaded.

The scoped moving-clearance review found no new unrelated interference or shaft-corridor breach. It retains original joint-region overlap, one related left hose-terminal touch, a separated right terminal near-contact and an original whole-bolt containment. Exact source/export witnesses and the strict outside-fitting measurements remain in [the bound acceptance receipt](evidence/actuator-interface-nonmates.json). These are disclosed local assembly limits.

The physical GLB excludes the original source-only raymarched combustion volume. That volume remains editable in the Blender source and follows the core carrier.

This is a local model and animation archive. **Ordinary game sprites remain V04/source35.** V06 native sprite capture/integration, owner appearance feedback and the family remnant/icon work remain open.

The [canonical manifest](canonical-manifest.json) is authoritative for current file pins. `provenance` preserves original construction records, including earlier stage labels. `tooling` contains snapshots of the repository toolchain; those scripts use the surrounding repository helpers.
