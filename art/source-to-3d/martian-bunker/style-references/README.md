# HARD texture-style references — user provided

These three user-supplied photos are explicit **hard visual reference images** for the texture style of the **Fortified Martian Heavy-Weapon Bunker**. They are not 3D source geometry, source albedo/normal maps, decal bitmaps, or Factorio sprite sources. File licensing/ownership is not established; keep them confined to development reference and **do not package in released Factorio mod assets** until redistribution permission is verified.

![Overhead armor style](user-reference-overhead.png)

![Three-quarter painted armor style](user-reference-three-quarter.png)

![Side, turret steel and exposed weathering style](user-reference-side.png)

## Material rules (enforced for asset decisions)

- Martian red armor: deeply muted red enamel, large but irregular chips at exposed edges and service points, dark undercoat, rare bright exposed steel, panel-seam grime and dust. Avoid uniform white noise.
- Cannon: **cylindrical continuous machined metal** with concentric collars, realistic longitudinal/circumferential scuffs, oily working joints and blue-brown tempering at the crown. Never use a box to approximate the gun tube.
- Ferrocrete: rough large-scale aggregate, moderate pitting, fine fracturing, Martian dust in horizontal ledges, much less metallic specularity than the turret.
- Blackened equipment: separate dark steel, grease, glass lens and brass materials; lighting can indicate operational function, never decorative floating LEDs.
- Texture implementation: original/generated PBR albedo/ORM/normal maps with correct UVs and bounded normal intensity, paired with physically connected mount details. Reference pixels must not be copied into shipped materials.
- Legibility: inspect at native Factorio game-camera projection and ~256 px before accepting microdetails; all nonfunctional busywork is rejected under the construction doctrine.

**Current asset:** [v0.7 cylindrical barrel Blender model](../gallery/README.md). [Construction doctrine](../../../../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md).
