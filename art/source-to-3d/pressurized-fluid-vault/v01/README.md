# Pressurized Fluid Vault V01

Packed source: `pressurized-fluid-vault-v01.blend`; actual export:
`pressurized-fluid-vault-v01.glb`. Original sprites recovered; original editable
fluid-vault source unavailable. The authored Item Vault hatch and stone enclosure
are reused with a new sealed iron liner/floor, through-wall sleeves, load-bearing
wall arches, concave pipe saddles and a supported pressure gauge tap.

Both ports have 0.56-unit open bores, 0.60 throats and 0.84 collars. Axis height
0.44 keeps the full collar above ground. Raising the pressure deck provides full
bore clearance into the cavity. The gauge tap is bored through the gasket/leaf;
its needle is static and does not claim a pressure simulation. The skull/cog is
remounted onto the centered front part of the hatch, clear of the fluid mouth.
Donor attribution and original skull UVs remain intact.

The native storage-tank has volume1000, collision +/-1.1 and selection +/-1.15.
Actual native tile placement is **3x3**, at half-grid centers such as (0.5,0.5).
Normal rotation alternates native0/north and4/east; requests8/12 normalize to0/4.
The opposed native local ports +/-1 connect normal pipes at local +/-2. Genuine
body/shadow captures d0/d1 are used in production. d2/d3 are review-only views;
south/west runtime picture aliases use the two actual native states.

Sprite-only square-ground Y projection follows the established FMPL native pipe
workflow. It does not deform the saved source or GLB. Measured source/export mouth
projections match actual native joint planes in both supported orientations.
Native in-game captures confirm joined ordinary pipes. The inherited larger-tank
circuit draw anchors are registered to actual modeled posts and LED bezels;
only drawing coordinates and backing/pin artwork change. Wire reach, native
amount/temperature behavior, fluidbox, research and recipe remain unchanged.

Technical gates: `inspection.json`, `port-audit.json`, `integration.json`,
`visual-review.json`, `native-preflight.json` and `native-evidence/review.json`.
Native proof covers water/steam through both ends in both orientations, normal
pipe placement, conservation, 1000-capacity clamping/unblocking, both circuit
colors and temperature, loaded rotation/reconnection, mining and settled-fluid
reload. Private proof fixtures never ship in production. Aquilo freezing was not
separately exercised; inherited heating/frozen-pipe fields are unchanged.

Owner called construction close to done and requested directional capture and
integration. Final native visual approval remains separate. This does not mark
the full queue complete. Next: the ten filtered stone caches, each with its own
actual filter contract and distinctive fittings. Sterling V03 exists elsewhere
on current main and must be reconciled rather than duplicated.
