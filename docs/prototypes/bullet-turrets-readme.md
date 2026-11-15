# Chicago piano and twin minigun prototypes

These are playable prototypes in the isolated **Bunker Family Prototypes**
add-on, alongside the existing autocannon, grenade lobber and energy dish.
They do not replace the protected full-mod release. Enable the add-on with
Factorio 2.1 and base; its experimental balance remains provisional.

Research **Fortified quad burst guns** or **Fortified twin rotary guns**
after military 3 and concrete, then craft and place the corresponding
fortified turret. Both accept ordinary bullet magazines and benefit from
vanilla bullet damage and gun-turret research. Their bunker foundation
remains stationary while the weapon mount traverses independently.

The **Chicago piano** has four individual receivers with side-entry belt
tracks rising from below. It fires four staggered shots at submachine-gun
cadence, then recycles for half a second. Unresearched timing is six ticks
between those shots, then thirty ticks from the fourth to the next first.
With fractional shooting-speed research the engine quantizes the recycle
to 29–31 ticks, averaging thirty.

The **twin minigun** has two six-barrel rotary guns, cylindrical receivers,
curved armor and ammunition drums. It fires paired volleys at stock turret
cadence and consumes two rounds for every pulse. Each rotary gun flashes at
one fixed muzzle point while its barrel bank rotates. Each pulse currently
uses one native impact at twice stock damage, so flat armor is applied once
rather than independently to two bullets.

Both use separate cap body, depth-occluded muzzle-flash and shadow passes,
captured at sixty-four headings. Runtime body animation uses thirty frames
per second, sampled from editable sixty-frame-per-second Blender keys.
Native preview cores remain visible when the entity inventory is opened.
The saved GLBs are static inspection exports; editable animation lives in
the accompanying Blender sources.

Recipes are provisional: four stock turrets for the piano or two for the
twin, plus 100 concrete, 100 steel, 20 gears and 10 advanced circuits.
Research costs 200 red/green/military science packs. This prototype add-on
does not contain the test targets or automatic ammunition used by the
validation scenario.
