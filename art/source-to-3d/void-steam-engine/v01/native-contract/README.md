# Void Steam Engine native contract and inlet repair checkpoint

Actual entity generator/void-steam-engine, platform-only2x2. No chemical
burner, processing recipe, fluid output, circuit connector or manual power-wire
endpoint. It consumes steam heat and supplies the actual platform electrical
network. Native cap300kW, maximum165C, effectivity1, fluid usage0.5/tick,
scale_fluid_usage=false. Do not infer10 steam/s from the cap: actual full-load
measurement is30 steam/s for300kW.200 steam165C yields2MJ into a real accumulator.
These existing values are preserved, not balanced or replaced.

Only north0 and east4 are actual native orientations. South/west placement
requests normalize to them; rotation toggles0/4. The real disabled12s crafting
recipe is steam-engine1 + pipe10 + offworld-cogitator-components2 + servitor-parts1.
Hydrogen-thruster-propulsion unlocks it,350 units of four science packs at45s,
with space-platform-thruster and blackstone-citadel-manufacture prerequisites.
Actual zero-gravity/pressure surface restrictions and existing item remain.

Baseline ordinary pipes report a target but remain half a tile off the actual
fluid grid. Across all four requested placements,200 steam stays in two normal
pipes, the generator receives none, and the fresh accumulator receives no energy.
Changing only the inlet localY0->0.5 restores true flow and electrical charging.
The repaired probe consumes exactly200 steam per engine and charges each load
to2MJ, without assigning energy to the target or its accumulator.

The four engines and accumulators share one real platform electrical network;
the steady60->120 tick aggregate changes divided by four give30 steam/s and
300kW. They are not four isolated-demand tests. Full operational state tests
must use separate platforms for independent no-demand/full-load cases.

The current main art/tools inventory has no named editable Void Steam Engine
source. The existing1024px sprite is the construction reference; preserve the
separate emergency steam engine and all accepted/concurrent work. No model,
animation, new sprites, full native-state/reload delivery or FMPL registration
is claimed by this checkpoint. Continue this same machine through delivery.
