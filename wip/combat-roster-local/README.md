# Local combat roster: source retained, runtime disabled

This snapshot preserves the existing local actor and AAI implementation. Nothing
under `wip/` is required by the shipped mod. Its actor registration, AAI composite
finalization, bridge, muster GUI, orders and reinforcement recipes are not enabled.
The original module requires AAI-generated composites and must not be called on
an installation without AAI. The source intentionally remains unchanged.

The ready mod contains the original local gun, ammunition, supply and research
definitions separated into `prototypes/combat_armory.lua`. It preserves their
existing placeholder balance/effects; the separately tested finished arsenal
below is not yet mapped into these canonical weapons or AAI actors. No claim of
completed actor weapon integration is made. See `ACTUAL-UNIT-AAI-HANDOFF.md`.

Shared catalogs, character rendering, skins, factories and icon assets live in
the normal source tree. Other existing worker/logistics owners remain those on
published main. Do not apply the old local source tree as an overlay to main.
