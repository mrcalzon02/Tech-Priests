# Rocket candidate 02 - shutter clearance repair

Repairs the owner-reported flap collision in candidate-v01. The cassette now
withdraws before opening, feeds while fully raised, withdraws before closing,
and parks behind the closed shutter. The panel clears the guide rails and the
loading ram is outboard. Actual source-rendered animation: shutter-clearance.gif.

Evaluated bevelled meshes were tested at 481 half-frame positions. The original
study produces 2,048 frame/part intersections; this revision produces zero.
Only the two intended hinge-pin contacts are exempt. This is sampled triangle
intersection evidence, not a continuous collision solver or acceptance of all
other moving parts. Original failure data is retained alongside the new report.

Editable source, static GLB and independent front/rear/clay inspections are
included. No rocket native firing implementation is present in this checkpoint.
The original candidate is superseded; its limited source checks did not prove
collision clearance. Owner visual approval remains pending.
