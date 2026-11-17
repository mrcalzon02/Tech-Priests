# Metallicized hydrogen production

## Fuel production in Tech Priests 0.1.686

Research **Metallicized hydrogen production** after **Nuclear power** and **Production science pack**. Each 8-second compressor cycle liquefies **500 hydrogen gas into 10 metallization-grade liquid hydrogen**. The crucible consumes **20 liquid hydrogen** in 8 seconds to make a single raw pellet. The pelletization forge forms it and the canister assembler seals it in a pressure shell. One sealed canister supplies **240 MJ**. At full load it powers a normal Minoris for 4 minutes at 1 MW, a Majoris for 2 minutes at 2 MW, or a Maximus for 1 minute at 4 MW. Burning consumes the shell. Unsealing recovers the shell and the original remaining pellet lifetime.

One sealed canister requires **1,020 water and 2 steel plates**, assuming every pellet reaches the sealer. Electrolysis converts 1,000 purified water into 1,000 hydrogen gas and 500 oxygen across 50 cycles. The pressure-vessel fabricator consumes the remaining 20 water and 2 steel to make the shell. At crafting speed 1, one purifier and one electrolyzer together supply one pellet every 200 seconds in steady state (0.30/minute). The seven stages consume **97.2 MJ of active recipe work per canister** when sealing one at a time, before machine drain, inserters and steelmaking. A cold line needs power to produce its first canister. Active draws in production order are 50 kW for the purifier, 200 kW for the electrolyzer, 375 kW for the compressor, 2.5 MW for the crucible, 200 kW for the forge, 150 kW for the shell fabricator, and 125 kW for the canister assembler.

At crafting speed 1, the forge forms one live pellet every **24 seconds** (2.5/minute). A pressure-vessel fabricator takes **96 seconds** per shell (0.625/minute). **Four fabricators supply one fully loaded forge.** Eight purifier/electrolyzer pairs supply enough gas for 2.4 pellets/minute. Three fabricators cap this line at 1.875 shells/minute; four can supply 2.5. Forge and fabricator motions repeat three and eight times respectively while each recipe runs.

Decay starts when the crucible discharges a raw pellet and continues throughout the press cycle and any wait for a shell. A fresh pellet loses a stage every 15–30 seconds and becomes inert after four stages (60–120 seconds total). An inert pellet yields no fuel. The sealer pauses decay at the individual sealing stroke. Keeping reserve shells or holding material as liquid hydrogen until a shell is available protects the yield.

The canister assembler can work as soon as it has one formed pellet and one shell. It pauses incoming shells once a batch of three is waiting for pellets, allowing the shell infeed to stay connected during cold startup. It likewise pauses incoming pellets while waiting for shells.

The main mod owns all seven animated machines, their sounds, research, player controls, and fuel behavior. Existing pipes, tanks, barrels and blueprints retain their fluid prototype ID. If upgrading a save with both former prototype add-ons, disable them together to transfer the existing material inventories and in-progress jobs to Tech Priests. Keeping the production prototype add-on enabled applies the new fluid recipes and power values but leaves its old assembler controller in charge. Native validation covers the base game and Space Age, all three reactors under load, and a save with both the forge and the canister assembler mid-cycle.

In a connected eight-pair plant on Factorio 2.1.24, one, two, three and four hydroformers exported 35, 20, 6 and 0 inert pellets respectively between game minutes 10 and 30. Over a separate 15-minute window with matching material inventories, four hydroformers delivered all 36 pellets as fuel. At that measured production rate of 144 canisters per hour, the 240 MJ recipe supplies one of each normal reactor at full load (105 canisters per hour) and leaves 39 canisters per hour for storage or export. A previously started forge job and shell job each completed once when a 0.1.684 save was loaded in 0.1.685.

[Four-hydroformer production, electricity and upgrade measurements](../../../tests/evidence/metallicized-hydrogen/four-hydroformers.json) · [0.1.683 production rates, electricity meters and upgrade tests](../../../tests/evidence/metallicized-hydrogen/rebalanced-line.json) · [Original 0.1.682 measurements](../../../tests/evidence/metallicized-hydrogen/integrated-line.json) · [Active-job upgrade comparison](../../../tests/evidence/metallicized-hydrogen/prototype-migration.json)

## Supplying a space platform

In Space Age the three reactors can be built on platform foundation. Launch reactor chassis and sealed fuel from a planetary silo. A platform inserter can feed canisters from the hub into a reactor to supply the ship’s electrical network.

| Normal reactor | Full output | Canisters per hour | Full-load time per ten-canister rocket |
| --- | ---: | ---: | ---: |
| Minoris | 1 MW | 15 | 40 min |
| Majoris | 2 MW | 30 | 20 min |
| Maximus | 4 MW | 60 | 10 min |

| Material | Items per slot | Mass per item | Reactor energy per occupied slot |
| --- | ---: | ---: | ---: |
| Live raw or formed pellet, any stage | 1 | 2 kg | Requires a shell |
| Inert pellet residue | 100 | 2 kg | 0 MJ |
| Empty pressure shell | 20 | 50 kg | 0 MJ |
| Sealed canister | 1 | 100 kg | 240 MJ |

A dedicated one-tonne launch carries ten canisters, **2.4 GJ per rocket** or **2.4 MJ/kg**. For comparison, conventional rocket fuel also fits these reactors. It carries 100 MJ per item at 10 kg each, so a dedicated launch of 100 units supplies 10 GJ. Each live pellet has its own countdown. A spent pellet becomes inert residue. Keeping its existing prototype and stack size preserves stored waste and inserter filters on upgrade. A late seal preserves the remaining life and condition, and even a critical pellet delivers the full 240 MJ if sealed in time.

## Modules and quality

The raw-water purifier has no module slots. The electrolyzer, hydrogen compressor, metallization crucible, pelletization forge, pressure-vessel fabricator and canister assembler each have four slots at every machine quality. The hydroformer qualifies because it shapes steel plate into an intermediate shell. Speed and efficiency modules work downstream. With Quality enabled, the crucible can roll higher-grade pellets and the fabricator can roll higher-grade shells. The forge carries a pellet’s current grade through forming. At different effective crafting speeds the required hydroformer count is four times the forge speed divided by the hydroformer speed, rounded up.

Any sound shell can accept any live pellet. The finished canister takes the lower of the shell and pellet grades. For example, a rare pellet sealed in an uncommon shell yields an uncommon canister. Unsealing restores the rare pellet and uncommon shell, including the pellet’s remaining lifetime. The same rule works across all five standard grades. A sealed canister delivers 240 MJ at every quality. Reactor chassis quality multiplies the maximum electrical output by 1, 1.3, 1.6, 1.9 or 2.5 from normal through legendary. A legendary Maximus therefore supplies 10 MW for 24 seconds from one 240 MJ canister at full load.

[Factorio 2.1.24 orbital freight, power, quality and save-upgrade measurements](../../../tests/evidence/metallicized-hydrogen/orbital-plasma.json)

## Archived prototype checkpoints

The seven accepted machine sources now have a composed addon candidate under `build/model-completion/metallic-hydrogen-chain/production-addon-v11-visible-fittings`. The later player-controls delivery below is the current tested prototype; it is not installed automatically into the real mod.

Actual native runs supply only water, steel plates and electricity to a connected seven-machine line. Real pipes and inserters produce six collected contained pellets; formation and sealing retain health, quality, decay phase and remaining lifetime. All machines stop advancing during the measured electricity interruption. Complete histories match after an actual tick-3500 save/reload. A separate critical-pellet probe expires natively in a chest and then travels through actual forge/assembler inserters as inert material, without consuming a shell or reviving the contents.

These runs pass both standalone and alongside Tech Priests/Space Age. The published-main snapshot is pinned in `build/hc-main-published/SOURCE.json`; latest complete behavior evidence is in `build/hc-final-published-01` and `build/hc-final-published-02-reload`. Production code includes no world creation/clearing or fixture stock. Native URI checks now catch missing graphics files that headless Factorio does not load. Early namespace and Windows long-path graphical studies are retained privately.

The candidate uses real electric sources, research-gated machine construction recipes and existing original machinery audio. The compressor retains its 1.15 gain, widest reach and priority 16. Resource icons are exact copied own-project renders, with origin hashes. Initial power, construction cost and science values are tuning candidates, not final balance approval.

## Historical defects (superseded by the completed checkpoints below)

- **Purifier native rotations:** the original fixed-north prototype had not established rotated pipe seating. The first normal-addon views expose a short front mouth and a rear pipe drawing over the bowl. The accepted V16 body and camera remain locked. `purifier_native_fittings.py` moves each original ten-mesh mouth rigidly and adds two real constant-bore sleeves to compensate native foreshortening; the capture derivative and new object-layer placement require native review. Staging captures are `purifier-native-fitting-captures-02`. No whole-body stretch or bitmap pipe patch is allowed.
- **Purifier clock:** six machine clocks pass private native counter decoding. The purifier counter repeats one boundary cell late in the sampled run. Preserve `build/hc-clock-02/clock-readback.json` as failed evidence; distinguish boundary sampling from actual drift with an offset probe before asserting a pass. Do not relax the period gate.
- **Player controls:** the forge/assembler retain private clock/intake/presentation recipes internally. A normal player interface must hide those implementation details while allowing real input/output interactions without healing, quality gain or timer reset. This is not yet complete.
- **Final balance and presentation:** complete the normal player/research flow and final energy/recipe tuning; retain the known limitation that native graphics and sound have per-entity phase offsets rather than proven process synchronization.

The reactor V14 ZIP/reference recovery, three reactor refinements and remaining sprite-only buildings remain in the original active goal. The linked Library currently requires sign-in in the available browser; a local path was requested once. Continue independent integration work while that source is unresolved, without substituting a new supposedly preserved ring.

## Resume reconciliation — 2026-11-15

The owner requested reconciliation and continuation of the existing goal. Preserve the fabricator's exposed welded sheets, edge clamps and open frame. The seven saved machine sources are not seven finished ordinary-game integrations; player controls, tuning, native review and the reactor/building follow-on remain open.

The purifier fitting adapter was moving hidden historical collar/throat meshes while leaving their rendered UV-surfaced replacements behind. The bolts moved without their visible supports. The corrected adapter explicitly selects the two visible surfaced fittings and eight original bolts per mouth and rejects hidden components. `build/purifier-native-fitting-readback-05.json` passes all four rigid world-transform checks, unchanged accepted mesh/body/camera checks and 72 bounded bore rays. The four-angle `purifier-native-fitting-pilot-05` was rendered, reopened and visually inspected; bolts now seat on the actual flanges. Full 36-frame captures are in progress under `purifier-native-fitting-captures-03`; actual game pipe seating remains a separate gate. Failed earlier capture studies are retained and must not be promoted.

The ordinary addon builder now requires a complete fitted purifier capture, checks its source/camera, frame hashes and capture/reopen gates, and records the actual derivative capture manifest instead of the old accepted-source manifest. This prevents silent fallback to the known unfitted rotations. Native fitting review is still required before delivery.

## Completed fitting and clock checkpoint

[Purifier V17 native fitting delivery](../../../art/source-to-3d/metallic-hydrogen-chain/water-purifier/v17-native-rotated-fittings/README.md) preserves accepted V16 bytes/body/camera and contains the corrected rendered-mouth capture derivative, 36 frames, six atlases, reopened master and clean native sprites. The four actual main-mod rotations were independently viewed. Front pipes meet receivers with exposed pipe barrels, rear pipes draw behind the bowl, and bolts stay seated. Earlier hidden-collar/short-mouth studies remain failed evidence.

`build/hydrogen-integration-readback-04.json` now passes actual published-main connected-line production, condition/lifetime conservation, electricity interruption, inert logistics, full-history save/reload equality, clean/counter body-pixel equivalence and exact main-mod graphical/pipe prototype equivalence. Both continuous and reloaded runs collect six contained pellets. `build/hc-cm-04` retains 487 private native images; public inspection records contain hashes only. All seven clocks pass the strict 32-second counter study: 240/240/480/480/480/720/960 ticks respectively. Sampling the purifier eight ticks away from the previous boundary resolves the repeat without changing production playback or relaxing the period gate.

The standalone graphical profile passed clocks but could not prove full pipe-definition equivalence because Space Age adds frozen pipe pictures. It remains a limited study. A separate graphical run with the actual published main and Space Age passes the unchanged full-definition gate; no fields were omitted from the comparison.

**Resume with normal forge/assembler player controls.** Final economy and process/audio phase policy remain open, followed by actual reactor-source recovery/refinement and remaining sprite-only buildings. The app goal API still reports paused; this turn resumed work, but the user-controlled Resume action is needed for automatic goal continuation.

## Completed fitting and clock checkpoint

[Purifier V17 native fitting delivery](../../../art/source-to-3d/metallic-hydrogen-chain/water-purifier/v17-native-rotated-fittings/README.md) preserves accepted V16 bytes/body/camera and contains the corrected rendered-mouth capture derivative, 36 frames, six atlases, reopened master and clean native sprites. Four actual main-mod rotations were independently viewed: front pipes meet receivers with exposed barrels, rear pipes draw behind the bowl, and bolts stay seated. Earlier hidden-collar/short-mouth studies remain failed evidence.

`build/hydrogen-integration-readback-04.json` passes published-main connected-line production, condition/lifetime conservation, electricity interruption, inert logistics, full-history save/reload equality, clean/counter body-pixel equivalence and exact main-mod graphical/pipe prototype equivalence. Both continuous and reloaded runs collect six contained pellets. `build/hc-cm-04` retains 487 private native images; public records contain hashes only. All seven clocks pass the strict 32-second study: 240/240/480/480/480/720/960 ticks respectively. Sampling the purifier eight ticks away from the previous boundary resolves the repeat without changing playback or relaxing the period gate.

The standalone graphical profile passed clocks but lacked Space Age frozen pipe pictures, so full pipe-definition equivalence failed there. A separate graphical run with actual published main and Space Age passes the unchanged full-definition gate. No fields were omitted.

**Resume with normal forge/assembler player controls.** Final economy and process/audio phase policy remain open, followed by actual reactor-source recovery/refinement and remaining sprite-only buildings. The app goal API still reports paused; this turn resumed work, but the user-controlled Resume action is needed for automatic goal continuation.

## Normal player controls completed

The [packaged prototype](../../../art/source-to-3d/metallic-hydrogen-chain/ordinary-integration/v01-player-controls/README.md) separates two safe production addons from destructive fresh-world fixtures. Forge and assembler entity-open events now show material slots, actual operation progress, completed count and the player's inventory. Internal clock/filter recipes stay hidden. Click/Shift-click transfers the original stacks; active press material and reserved shell stacks stay locked. Tooltips display quality, integrity and remaining decay time.

Fifteen actual native checks pass. Continuous standalone execution and an actual tick-600 active-job/UI save/reload alongside published main yield identical complete material results. They cover exact manual round trips, wrong-material rejection, unrelated-window/reach handling, active locks, full inventories, repeat collection, sealed metadata, real expiration while open, and exact lifetime/shell restoration. The native GUI was rendered and privately inspected at the client's actual display size. Real Lua GUI elements go through the registered click handler; physical mouse automation and two simultaneously connected players were not tested.

`build/hydrogen-player-controls-validation-01.json` binds the tested candidate, two UI runs, current main-mod connected line and private images. All 105 art/audio/spec files and all seven native visual prototype definitions match the preceding exact-clock checkpoint; no art or fitting review is reopened. Runtime byte reproduction from the packaged own-project resource icons passes for all 123 files, allowing clean authoring without publishing unrelated resource/weapon work. Original decay/seal behavior is unchanged; dependency 0.0.5 adds guarded stock access.

The normal prototype portion is complete at the documented starting tuning. Native working graphics/sound follow the engine phase-offset policy; exact per-instance press/seal/audio phase synchronization is not claimed. Final game-wide economy balancing is a separate tuning concern. The owner has explicitly closed the purifier. Move on to reactor-source recovery/refinement and remaining building inventory/model production. The full goal is active and incomplete.
