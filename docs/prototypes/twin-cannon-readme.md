# Twin siege cannon in Tech Priests

The six bunker weapons are now registered in the main Tech Priests source:
autocannon, lobber, energy dish, Chicago piano, twin minigun and twin cannon.
Use the main mod alone for these weapons. The separately verified 0.4.0
standalone prototype remains a development comparison package.

Main-mod verification: twin-cannon-main-evidence. Runtime ownership:
bunker-runtime-map.md. Editable cannon source: art/bunker-twin-cannon.
No full-mod release/version bump is included in this source checkpoint.

# Standalone prototype 0.4.0

Six playable fortified weapons for Factorio 2.1: autocannon, grenade lobber,
energy dish, Chicago piano, twin minigun and the new **twin siege cannon**.
Enable this prototype add-on with base. It uses the same mod name as 0.3.0;
Factorio selects the newer version. It does not replace the full Tech Priests
release or add the unbuilt artillery and missile designs.

Research **Fortified twin siege cannons** after tank and concrete, then craft
the turret. It uses the four existing cannon ammunition types directly:
cannon shells, explosive cannon shells, uranium cannon shells and explosive
uranium cannon shells. There is no new cannon ammunition or conversion recipe.

Two guns fire alternately every 45 ticks (0.75 seconds) before shooting-speed
research. Each shot consumes one shell. Range is 36 tiles, with an 8-tile
minimum; the native ammunition's range modifier still applies. AP shells
engage heavy armour and can pierce a line of enemies. The turret aims at a
farther aligned enemy of the same priority type when this gives the original
shell room to continue through nearer enemies. Explosive shells retain their
normal blast behaviour. Native projectile damage, quality and research apply.

The cannon has separate mantlets seated in a shared casting, enclosed curved
mesh-covered rear shell feeds, supported optics and aerials. Each barrel
recoils deeply and returns slowly. The fixed concrete bunker stays still.
Radio whips respond to firing and turning, then settle. The native flash
artwork follows the active barrel, slightly forward of its muzzle; draw order
changes with facing so the barrel can occlude the flash.

The four corner stanchions show the owning force's colour on all six weapons.
Red armour, concrete, fixtures and effects keep their original colours.

The recipe uses two gun turrets, 150 concrete, 150 steel plates, 20 engines,
30 gears and 20 advanced circuits. Balance remains provisional. The native
preview uses a solid part of the cap shared by all firing poses, preventing
a second stationary barrel from showing through the animated world graphics.
Cap shadows are static per heading; gun mechanisms and antenna motion animate.

The Chicago piano retains its four staggered shots and half-second recycle;
the twin minigun retains paired fire and double ammunition use. The lobber
uses six-round grenade packs, and the dish retains its charge/discharge cycle.

The editable cannon source is the packed Blender file; its GLB is a static
inspection export. Native cannon-effect graphics are referenced from Factorio
and are not included in the editable model. Test targets and automatic ammo,
power or research helpers are excluded from the playable archive.
