# v0.4 — sloped bunker load paths and beveled-hull equipment conformance

**Authority:** [Red Tech Priests construction doctrine](../../../../../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md). This is original, editable, independently generated geometry; no third-party model, Factorio art or copyrighted Wube mesh is embedded.

## What changed from v0.3

- Maintained the **3×3** outer foundation (same dimensions, material IDs, turret and gun configuration).
- Replaced **four vertical corner posts** and their rectangular lower shoes with eight separately beveled, lofted, leaning structural buttress/foot meshes. Corners physically overlap the bunker’s diagonal shell and shift inward on both axes as height increases.
- Reconstructed the front service hatch, locking spine, thermal approach sensor and glazing as **real inclined-geometry plates** with inside faces recessed into their supporting shell or overlapping the prior plate. Moved the four hatch bolts accordingly.
- Rebuilt the four front gothic compression members/keystone/feet around the actual front wall plane, not a floating, constant-Y plane.
- Re-seated the **east armored service plate**, cover stiffener, fasteners, power entry cable, supply breaker and status indicator against the lofted east wall instead of fixed X world offsets.
- Re-seated the **west bunker monitoring gauge and lens** against the opposite shell.
- Re-seated the **north rear vent guard and four louvers** against the changing north wall, and moved the service certificate onto the controller cover.
- Preserved the **co-traversing antenna** and low fixed rear magazine. No new decorative random boxes.

## Reproducible checks

Run `python build_blockout.py` then `python verify_hull_conformance.py`. The latter inspects the actual raw mesh vertices at the top and bottom of **20 hull-mounted parts**, proves the side-plane slope, checks the eight corner/foot meshes, preserves 131 named parts and 42 rotating objects, and fails on even slight detached panels.

Blender Actions then constructs the native editable `.blend`, renders front/rear/other corners, exports `.glb`, opens the exported model in a **clean Blender instance**, and checks its geometry, color and corner taper again. Source previews are diagnostic only. No existing Factorio sprite or gameplay prototype is modified.

**Pending:** artistic acceptance, weathered textures/normal maps, real in-game perspective/scale comparison, and deeper intersection/swept-volume testing for every static utility. Geometry conformance does not imply sprite-quality acceptance.
