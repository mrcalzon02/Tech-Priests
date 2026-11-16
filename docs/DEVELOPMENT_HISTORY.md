## 2026-11-15 - User-requested AI behavior checkpoint and stop

Paused at the user's explicit request. Published native-validated behavior is retained through 27296701. The final water-tree-clearance equality correction is checkpointed with regression evidence but remains unvalidated in Factorio. Its prior native attempt was intentionally saved and stopped at tick 140376; no successful force-3 water connection is credited. The exact published power-kit continuation completed its tick-144000 save and force 2 reached 15 native red science, while force 3 remained at zero. Full campaign and orbital science acceptance remain open. See docs/AI_BEHAVIOR_CHECKPOINT_2026-11-15.md for code scope, evidence identities and remaining work. Do not resume automatically.

## 2026-11-15 - Manufacture missing power kits without losing native science work

Independent terrestrial priests now treat an observed missing pump, boiler, steam engine or pole as an actual dependency of an engine-only lab/science task. The existing governor retains the exact parent task and gate, including its target, original start time and native machine state. Its existing recipe ancestry selects the real enabled power-kit recipe and missing ingredients; original 0514 owns the counted ingredient transaction and original 0338 owns paid pickup, carrying and native placement. Machine buffers remain untouched. After physical installation and release of active duties, the same parent task resumes. The urgent dependency is protected from unrelated cooperative jobs. Active orders, other tasks, physical cargo, movement, maintenance mode, platforms, locked recipes and stale observations refuse a new suspension. Context, ancestry and actual installation gate resumption.

Exact-source contact-arena-power-kit-ownership-1297-final resumed the protected tick-120000 save and produced a verified tick-126000 native save without modifying its input. It retained force 2's real lab task at tick 120080, completed the ingredient-conserving station craft for one missing steam-engine kit at tick 121025, then physically built the generator and the ordinary power network. The retained lab task resumed at tick 125430 with target stock 3 and its original tick-120055 start and facility-start timestamps. Reloading that exact save in contact-arena-power-kit-reload-1297 preserved both the completion receipt and the same parent fields at tick 126426. No actor task, movement, build, research or item commands were injected. The earlier baseline still had no generator and zero science through tick 138009.

Selected regressions pass 71 Lua groups and 7 Python tests. New cases cover exact parent identity, recipe-ingredient conservation, ordinary physical installation, dependency ancestry, stale/locked/context refusal, foreign requests, active work, cargo and maintenance guards. Exact-source maintenance-power-kit-ownership-1297-final passes all four ranks. All 385 runtime Lua modules match the final recovery, maintenance and reload profiles; their control.lua observer additions remain isolated. This verifies paid power-kit construction and parent resumption, not all-force science production. Force 3 still reports no water route through native obstacles; that failure and the full rocket/space-science campaign remain open.

## 2026-11-15 - Preload laboratory electricity authority for native planning

Native service-result telemetry exposed a swallowed exception on every force-2 governor pass: request_installed_lab_power_pole_1251 called require after control.lua parsing. The electricity authority is now preloaded beside the other canonical dependencies. service_all persists each pair's last real result or caught error so a protected replay can distinguish an active wait from a failed planner. The laboratory pole regression now disables runtime require after loading the module; it fails on the previous source and passes the fix.

Exact-source contact-arena-governor-preload-1296-final resumed the protected final contact-arena save and verified a new tick-112000 native save, leaving the input unchanged. Force 2 autonomously reopened its real lab recipe at tick 110070 under the existing science-priority rules; passive tick-111281 telemetry shows a canonical strict facility-only lab task and no require exception. The unchanged 2e9090aa baseline remained stopped and at zero science through tick 128046. No agent task, build, movement, research or item commands were used. This verifies restored planning, not completion of the still-unpowered lab or all-force science production.

Selected regressions pass 70 Lua groups and 7 Python tests. Exact-source maintenance-governor-preload-1296-final passes all four ranks. Runtime governor bytes match both copied profiles. Native boiler/engine/pipe recovery remains a separate paid-construction proof; force-2 missing steam-engine supply and full science throughput remain open. Full fresh campaign, four-force factory acceptance and orbital science production/delivery/consumption are not accepted.

## 2026-11-15 - Search bounded native boiler sites after sparse failure

The completed contact arena left force 3 at zero science with site-not-verified:boiler. A passive native audit at tick 113506 found 719 legal boiler positions within the same territory and with clear native fluid connections, despite the original sixteen-offset search failing. The existing bounded plus/minus-sixteen-tile generator fallback now also searches boilers, with a separate ten-second refusal cache. It retains native footprint, inlet, steam escape and territory checks. Only original 0338 spends the real machine kit and constructs it.

The same protected final arena save, copied into contact-arena-boiler-search-1295, autonomously built native boiler 312 at (-59,39.5), direction east, by tick 111956. By tick 114406 it had progressed through the steam-engine request to physical steam-pipe construction. The unchanged 2e9090aa baseline still had no boiler and remained on the strict lab recipe at tick 118780. No agent actor commands or resource grants were used. This proves repair of the missed placement and subsequent work, not completed power commissioning, science throughput or fresh arena acceptance.

Selected regressions pass 70 Lua groups and 7 Python tests. The new boiler cases verify a usable site beyond sparse offsets, native refusal backoff, later retry and unchanged kit stock during planning. Exact-source native maintenance-boiler-search-1295 passes all four ranks. The ongoing recovery retains its protected source and input manifest; full campaign and orbital science acceptance remain open.

## 2026-11-15 - Require a local Void manager across orbital construction paths

The shared 0338 constructor now gates generic and robot-network work on platforms as well as the local bootstrap. A physically present same-force Void Priest bound to its own Void Cogitator and platform hub is required. Terrestrial, absent and foreign actors cannot receive new orbital construction. Existing tasks are dispatched only to abort and preserve or physically restitute their actual custody. Ground construction and local Void bootstrap custody retain their established owners.

Selected regressions pass 70 Lua groups and 7 Python tests, including generic robot-request rejection for terrestrial, absent and foreign actors and termination of an inadmissible existing task. Exact-source native void-manager-construction-guard-1294 passes autonomous nine-tile and solar construction from real hub stock. maintenance-void-manager-guard-1294 passes all four ranks. These component and maintenance checks do not claim full orbital production or fresh campaign acceptance. The older 8d1e4db5 contact arena completed all 108000 active ticks with a verified final save and genuine combat, but forces 2 and 3 still produced no science; its all-force factory gate remains failed and its source identity is unchanged.

## 2026-11-15 - Native capacity and bounded recovery unblock autonomous science

Native inventory can_insert accepts a partial stack. Storage authority now uses native get_insertable_count for exact capacity, splits paid deposits across available containers and fails closed when native capacity cannot be observed. Atomic rollback remains in force. Ranked mining-output returns now restore the same physical hold after a verified unchanged capacity refusal; ambiguous or partial mutations remain quarantined. Existing bounded same-surface movement recovery omits the optional surface and grid snapping, preserving cargo and character exclusions and the clear forward destination checks.

Exact-source native recovery native-capacity-recovery-1293-final resumed the protected tick-145048 save and produced a verified tick-149048 native save without changing its input. Force 1 resumed from 160 to 165 red science and added a building. Force 3 resumed from 2 to 5 red science, built its second station and added two buildings. The unchanged 5b79acf baseline science-return-contact-diagnosis-1292 remained at 160 and 2 through tick 151083. Passive observations verified the blocked 50-ore hold cleared and the pole constructor moved. No actor task, movement, build or research commands were injected. The longer native-capacity-movement-recovery-1293 run omits the final ranked-return guard and is a separately qualified variant.

Selected regressions pass 70 Lua groups and 7 Python tests, including native partial-capacity, rollback-race, unavailable-capacity and ranked physical-refund cases. Exact-source native maintenance-capacity-recovery-1293-final passes all four ranks. All 384 runtime Lua modules match both copied profiles; control.lua differs only by the verified isolated CI observer suffix. These are protected brownfield recovery and maintenance proofs, not fresh campaign, all-force arena, rocket-to-space-science or research-consumption acceptance. Default platforms already commission one canonical Void Priest and local orbital paid construction remains owned by that resident priest.

## 2026-11-15 - Local Void construction and real ground-to-ship material flight

Original 0338 now offers a ship bootstrap only to a physically present, bound Void Priest on its own platform, in independent mode. It plans a connected nine-tile foundation pad and one solar panel. The priest approaches the real hub, debits an actual item into a persistent native inventory, travels to the site and places only that paid tile/entity. Native world readback verifies construction. Changed ownership, orders, sites, missing sources and orphaned custody retain or physically return actual items. Ground priests cannot publish or execute this orbital construction. The local priest's committed plan and actual remaining stock create material demand for the ground silo owner.

Original 0710 can now load that exact local demand and execute another native rocket flight to the existing hub. Starter flights target space_platform; ordinary cargo targets station with the real hub. A force retains its supply silo, foreign cargo refuses launch, and an observed native pod prevents duplicate flights. Pod termination is not material credit: actual local world, hub stock and the Void Priest's held inventory decide remaining demand and loss recovery. No scripted material production, remote building ghosts or item grants are used by the runtime.

Native validation exposed a previously unusable Void movement handoff. Its stepped relocation now omits the optional surface for same-surface platform units, disables grid snapping and verifies actual position. The canonical controller still owns requests, bounds and priorities; cross-surface changes cancel movement. A staged initial-platform component proves nine actual foundation debits plus one solar debit. A separate full native launch sequence on the exact final runtime proves a paid starter flight, default Void station 13/priest 14, nine local paid tiles, a second genuine rocket carrying the priest's requested solar panel, and local pickup/construction of that panel. Foundation stock falls from ten to one; warehouse and hub solar stock fall to zero. The fixture declares its late-stage starting stock/preset and observes; it issues no actor jobs, movement, placement or launch commands. This is a real two-flight/local-construction diagnostic, not fresh ore-to-rocket research or space-science acceptance.

All 69 selected Lua groups and seven Python tests pass, including local-role/foreign-order refusal, exact native cargo restitution, manager-driven demand, flight exclusion, correct hub destination and uncredited lost-pod recovery. Exact final runtime four-rank maintenance passes. The earlier ground recovery finished with a genuine protected tick-145048 save and two real red packs in the formerly stalled faction; throughput remains failed. The separate fresh four-way contact diagnostic retains its original 8d1e4db5 source and continues; participant combat occurred, but two factions still lacked science in the latest sample. Orbital asteroid collection/processing, factory recipe/transfer chains, space-science production/return/research, sustained post-launch supply and fresh all-force campaign acceptance remain ACTIVE and unproven.

## 2026-11-15 - Native power commissioning and real lab production recovered

The exact 8d1e4db5 runtime autonomously finished the twenty-one-tile steam route and its one-tile water reconnection, then selected and delivered real coal through original 0707. At tick 120471 the boiler held 44 coal and the actual steam engine reported 1291.666666666666 energy_generated_last_tick. At tick 120771 engine 174 contained native steam and energy, and assembler 148 was powered on the same real network. Its native lab recipe had finished three products; original output custody collected them. The strict lab parent completed at tick 119975. By tick 123471 a real lab existed, with ordinary paid power-bridge construction requested next. No science/research completion is credited from these commissioning observations.

The original protected recovery remains live through target 127048. A separate fresh four-way contact diagnostic on 8d1e4db5 has started with 64-tile spacing, 108000 active ticks, and both all-force factory and participant combat gates required. It retains its own manifest and never substitutes for the default-spacing gate or the full rocket/space-science campaign. This is continued autonomous behavior validation, with no injected actor orders. Local Void Priest startup and ship-construction authority remain required.

## 2026-11-15 - Clear a strict recipe's own native pipe supply access

A protected four-way continuation reached fourteen paid steam-route tiles, then stranded its pipe builder at a tree-obstructed supply container. The original source-clearance owner rejected every request whenever emergency_craft existed, even though the pending strict lab recipe depended on those very pipes for power. Original 0338 now admits clearance only for its exact active native fluid plan: the same request pointer and route ID, a pipe task, owned live endpoints, and a strict facility recipe retained by identity. A matching lower-priority adopted production order may yield through the existing lossless queue. Foreign orders, other cargo, changed requests and replacement production parents still refuse new mining.

Measured source-approach stalls now use the same physical clearance path as outbound and restitution stalls. Original 0469 selects the child, original 0513 mines native wood and returns its real inventory, and 0338 retains and resumes the actual parent task. No operating-radius expansion, material credit, artificial movement or injected actor tasks is used.

The canonical queue/dispatcher regression proves a strict lab parent survives actual native-shaped wood custody and deposit; stale plans and foreign orders refuse, and replacing the recipe revokes its unmined child. All 67 selected Lua groups and seven Python tests pass; native four-rank maintenance passes on the exact runtime. Native protected recovery selected clearance at tick 109355, advanced from steam tile 15 through all 21 paid tiles, then built the one paid water reconnection. By tick 118071 the original boiler report became fuel-service-eligible, and by tick 118446 its ordinary energy owner was approaching real coal stock. Native energy generation, finished lab and science are still pending at this checkpoint; this recovery is not fresh acceptance. The Void Priest starter requirement remains in force, and the full rocket/space-science objective remains ACTIVE.

## 2026-11-15 - Native platform starter includes its local Void Priest

New default Space Age platforms now include one Void Cogitator on an attached 2x2 foundation berth, declared directly in the native starter pack's structures and tiles. The paid starter flight creates that structure. Its native trigger-created event enters the ordinary built-station lifecycle, which creates and binds exactly one Void Priest on the platform. Duplicate events remain idempotent. An independent campaign's local Void Priest inherits that expedition's mode through the existing emergency-operation API; unrelated player platforms retain their own mode.

The user's required authority is explicit in the campaign specification: ground priests may supply ships, but a physically present local Void Priest must manage and build subsequent orbital structures. The uncommitted ground-controlled orbital construction experiment was removed after that clarification; its disposable diagnostics are retained as withdrawn and cannot satisfy acceptance. Local Void ship planning, paid orbital production/material processing and genuine space-science return/research are still required.

The exact new runtime passes a real full native rocket and paid starter arrival: hub 12, Void Cogitator 13 and bound Void Priest 14, exactly one local priest and independent-mode inheritance. The fixture only declares its starting stock/preset and observes; it creates no Void station/priest or actor jobs. The initial prototype-schema failure is retained separately and corrected using the native tile field. All 67 selected Lua groups and seven Python tests pass, including starter idempotence, ground/foreign-context refusal and unrelated player-mode preservation. Exact runtime native four-rank maintenance also passes. This proves the new ship's local crew, not autonomous orbital factory or campaign completion; the full goal remains ACTIVE.

## 2026-11-15 - Reconnect buffered native boiler water before fuel admission

Protected autonomous outlet recovery exposed a second circular wait: the rotated boiler retained 200 water but had no connected inlet. The native energy owner correctly refused fuel before a physical water connection; fluid doctrine waited for that stored water to be consumed before proposing the inlet. Original 0689 now reports a disconnected vanilla boiler water inlet as a missing connection even with retained water. Other buffered recipe inputs retain their existing behavior. The observer neither drains nor inserts fluid and original paid 0691/0338 still constructs the pipe.

The new regression retains the 200-water buffer and proves a valid physical water proposal without mutation. All 66 selected Lua groups and seven Python tests pass. The protected native continuation independently published its boiler-water proposal at tick 73480 while the original steam route continued. The route has 21 paid tiles; one-piece supply trips remain a measured throughput concern. The previous genuine checkpoint at tick 73048 protects actual mined/returned wood, native boiler rotation and paid pipe progress. Current continuation native-water-inlet-recovery-1288 is autonomous and remains open through real power and science; no completion is inferred from discovery alone.

## 2026-11-15 - Autonomous recovery of an unusable native steam outlet

The fourth fresh-arena faction could not power its lab assembler: its paid boiler faced a two-tile pocket bounded by its own footprint, shore and the pipe planner's station interior. New boiler placement now requires steam escape inside that same interior. When an independent cold, unautomated boiler has no steam route, the original fluid planner may prove a native half-turn route and publish a prerequisite to the original construction owner. It refuses maintenance mode, foreign orders, other cargo, burning fuel and attached inserter/loader ownership. No agent supplies actor tasks or world mutations.

If exactly one neutral wood tree blocks the alternative outlet, planning checks native tile/object collision and the complete conditional route. The original construction owner submits its own clearance child to 0469; original 0513 mines into real cargo and returns actual wood before rotation. Its bounds exception names only that exact construction tree inside the station interior; unrelated ore retains its ordinary cap. Original 0338 approaches the actual boiler, rechecks the route, invokes native rotate and verifies the same entity/position. Ordinary paid pipe construction resumes afterward. The route search starts at the more constrained legal endpoint to avoid scanning an entire factory for a shoreline pocket.

Native protected-save recovery on the exact runtime selected and mined the tree (four actual wood), returned the cargo, preserved the strict lab parent and boiler water, then rotated boiler 166 from direction 8 to 0 at tick 67610. Factorio completed that half-turn in one native rotation. By tick 69778 the ordinary paid steam route had advanced to its second tile. Full steam, powered lab and resumed science remain unproven at this checkpoint; construction continues in native-steam-tree-recovery-1288b. This is a recovery diagnostic, never fresh campaign acceptance. All 66 selected Lua groups and seven Python tests pass; the new test also rejects maintenance and burning-boiler rotation. Exact runtime files match the passing four-rank native maintenance and full native rocket/starter-delivery scenarios.

State reconciliation: the original 4ac48675 fresh four-way run finished all 108000 active ticks with a verified final save. Three factions produced red science; faction 3 produced none, and no faction combat occurred. Factory and combat gates fail. Historical source identities are retained and terminal sessions are no longer marked running. The sandbox-only recovery attempt failed to open its loopback socket; the independently authorized native run is recorded separately. Autonomous progression through rocket prerequisites, construction and space-science production/return/research remains ACTIVE and unaccepted.

## 2026-11-15 - Independent native launch and paid platform startup

Original 0710 now carries independent rocket manufacture, starter-pack loading and launch selection through its existing discovery, canonical classifier and physical delivery owner. A force-scoped orbital campaign record proposes only an unbuilt native platform order after a real starter pack is physically loaded. Native launch transports and consumes that payload; no script supplies rocket parts, applies a free starter pack, creates orbital structures or credits science. Standard-player maintenance cannot launch, external silo automation retains ownership, foreign orders and force/surface changes refuse new launch work, and another worker cannot duplicate an already paid flight. Native hub arrival, rather than a successful launch request, establishes delivered starter state.

Native iteration exposed three genuine blockers: generic managed supplies were absent from silo source discovery; inventory stringification collapsed different native containers behind an empty station; and the native part counter resets when a completed rocket is created. The source list now uses canonical storage authority plus real container identity. Readiness distinguishes rocket_ready from an active launch sequence and uses that native state after counters reset. Starter loading selects the actual inventory that contains or accepts the item, rather than assuming an attached cargo inventory is writable. Counted silo goods finish before a later strict recipe can strand them.

Independent ingredient buffers now use remaining native parts, native ingredient stack sizes and the existing transfer limit, capped at ten production cycles. Standard maintenance retains its two-cycle buffer. With identical native costs, the isolated full supply-to-flight scenario reduced its ready point from roughly 117000 ticks to about 33000. Its declared initial machines/power/warehouse ingredients are explicit late-stage diagnostics, not autonomous campaign research/construction evidence. The fixture issues no actor tasks or executor/movement/build/launch commands. The runtime itself supplied 152 items, manufactured the complete native fifty-part rocket, loaded one paid starter pack, executed native flight and delivered to real platform hub 12. The exact final runtime passes the native full-cycle scenario and four-rank maintenance; all 65 selected Lua groups and seven Python tests pass.

The full objective remains ACTIVE and OPEN. This proves a staged native launch and paid platform startup, not fresh ore-to-rocket campaign completion. Orbital factory layout, cargo production/transport, asteroid/material processing, genuine space-science production, return/research consumption and lost-flight recovery still need implementation/validation. The full fresh four-way run remains on published 4ac48675; its fourth faction still lacks science while the other factions are producing red science. A protected midpoint diagnosis observes a connected power network and water-filled boiler but no steam/boiler fuel, identifying the next early-game supply dependency to resolve. Three inherited clean-main rail failures remain separately tracked.

## 2026-11-15 - Physical silo supply access and native rocket-part production

Inspection of the downstream campaign path found original 0710 silo logistics required proximity to solid entity centers for source pickup, silo delivery and restitution. A real nine-tile silo makes its center unreachable. Original 0710 now measures custody reach to native collision footprints, resolves hidden backing caches to their physical host, and selects engine-clear exterior contacts within the existing 1.6-tile transfer reach. Contacts stay stable during measured progress and rotate after a genuine 180-tick stall. Stored contact alignment bounds the alternatives. No reach, material or launch shortcut is introduced.

Target force/surface and cached source force/surface are revalidated before mutation. Lost target authority routes actual held goods back through original restitution, and a reassigned source cannot receive an enemy inventory refund or supply an unauthorized pickup. The unit regression fails on the published pre-change source at physical large-storage pickup and passes after the fix, covering exact paid delivery, no remote mutations, legal exterior approach, lateral stalls, reload restitution, and target/source reassignment guards.

A new isolated native rocket-silo-access scenario declares only its initial station, silo, electric supply and native recipe ingredients. Its fixture issues no actor tasks, movement commands, direct executor calls or runtime refills. Ordinary discovery/classification/dispatch delivered six actual items and native rocket parts increased from zero to one. The test passes through tools/run_factorio_isolated_service_scenario.py. This staged late-game diagnostic does not establish autonomous research, silo construction, a launch, or orbital science. All 64 selected Lua groups and seven Python tests pass. The separate protected four-way commissioning continuation remains running on 1d808f5c, with no fresh campaign acceptance claimed.

## 2026-11-15 - Clear construction travel and finish actual acquisition returns

Native source clearance exposed a second dependency: four real mined wood remained in engine inventory because original 0513 cached one unreachable station contact forever. Return contact selection now preserves a goal during directed progress and rotates to another engine-clear contact after a measured 180-tick stall. Physical deposit still requires the original two-tile station range. Completed atomic deposit releases only its own 0513 movement request, preventing its higher-priority 600-tick return lease from blocking subsequent machine logistics. A foreign safety/combat route is preserved.

Original-0338 access dependencies now also cover measured stalls while delivering or returning a single exact paid kit. The parent retains its kit in construction custody while original 0513 exclusively owns native mined wood. Matching parent phase, source, exact child order and neutral tree are revalidated; the classifier admits only that authorized dependency ahead of the parent's otherwise blocking custody. Finite tree counts and travel allowance remain. The integrated regression exercises both outbound and restitution access with unchanged paid-kit custody. A separate regression verifies stable progress, lateral-stall rotation, exact four-wood deposit and ownership-specific terminal movement release.

The protected native arena replay observed autonomous clearance at tick 73195, native wood custody of four, subsequent deposit of the same four, another clearance request at 78185, and actual assembling-machine-1 entity 227 with stored assembler kits reduced from eight to seven. No task, movement, build or research orders were issued through diagnostics. The faction then independently selected a paid offshore-pump build for power. This native replay includes the paid-kit and contact-rotation changes; it predates the final deposit-lease release addition. That addition is covered by the ownership regression and exact-final-runtime four-rank native maintenance. All 63 selected Lua groups and seven Python tests pass. Factory commissioning, science throughput, launches and orbital science remain unproven; recovery evidence is not fresh campaign acceptance.

## 2026-11-15 - Construction selects physical supply-access clearance

An unreachable source contact now receives a finite alternative-face retry only after measured approach progress stalls. When all clear contacts are exhausted, an independent, unladen original-0338 builder can request one nearby neutral wood tree on its actual supply corridor through the existing order queue and canonical acquisition owner. Original 0513 performs native mining, inventory custody and real return/deposit; construction retains its original paid request and cannot debit the kit remotely. Clearance is bounded, refuses foreign orders/cargo/combat, and revalidates its exact parent, source, tree and own order before new extraction. Lost parent authority cannot erase already mined cargo or terminate a foreign order.

The integrated regression exercises the original queue, classifier, dispatcher, builder and native-inventory-shaped acquisition executor: admission refusals, no premature stock debit, real wood yield, refused deposit, parent revocation with retained cargo, exact return, resumed construction pickup, and foreign-order protection. All 62 selected Lua groups and seven Python tests pass; isolated native four-rank maintenance also passes. The native arena recovery is diagnostic and still running: faction 3 genuinely collected its assembler but subsequently timed out while approaching the build site and is returning the same kit. No native tree-clearance success or science recovery is claimed. This exposes a separate carried-kit route/access blocker for the next iteration. Full autonomous rocket/space-science campaign acceptance remains OPEN.

# Tech Priests Development History

## 2026-11-15 - Require autonomous decisions and native science production

The user reiterated that completion must be driven by the Tech-Priests' own autonomous behavior, not by the agent issuing their actions. The campaign acceptance specification now explicitly excludes injected tasks, forced leases, manual executor calls and directed movement/build/research/attack commands. Declared starting presets, passive telemetry, time acceleration and save checkpoints remain diagnostic infrastructure; recovery observations do not become fresh campaign acceptance. Current native recovery inspection reads the actors' own planning/dispatch decisions and does not issue their jobs.

Inspection also found a science fidelity gap: the governor marked only red/green packs as facility-only, so later science could take the existing ingredient-conserving timed station fallback. All science-pack families are now native-facility-only, both at request creation and when loading legacy tasks into the original production owner. Elapsed time is not substituted for a real compatible factory or required orbital surface. The regression reproduced the previous military failure before the change, then verifies military, chemical, production, utility and space science retain their parent and ingredients and produce no timed fallback output when no native machine exists. This prevents a shortcut; it does not implement the still-missing orbital factory and launch chain.


## 2026-11-15 - Install and commission paid mining capacity for planned raw deficits

A long bootstrap hand-mining batch excluded the Magos science planner from installing stocked equipment for that same resource. Existing generic miner siting also always favored iron before other resources. The existing capacity-request coordinator now allows an explicitly independent, unladen, non-extracting planned raw batch to publish one funded original-0338 miner request. It retains the raw parent, checks actual researched hardware stock, subtracts native resource-specific installed capacity using native mining yields and speed, and refuses foreign orders, cargo, construction and combat. Resource-name intent survives original construction normalization and native siting; requested stone cannot be silently placed on an iron patch. All native placement, territory, collision, source pickup and paid construction gates remain unchanged.

The original 0338 terminal boundary retains the exact paid raw-miner receipt. The existing 0528 discovery/dispatcher can then commission coal for that same planned raw dependency instead of repeatedly cancelling it behind hand acquisition. This also covers the exact ingredient of an incumbent strict native smelting task. Fuel and connected finished mining output are admitted ahead of unrelated aged jobs only after original paid ownership, live target resource, actual native inventory/provenance and cargo/order checks. The original owners alone perform pickup, movement, engine-held output custody and deposit. A new regression exercises real 0488/0510/0528 selection, exact coal debit/custody/delivery, parent resumption, connected-output discovery and refusal of empty/disconnected output. Existing output conservation and reload regressions remain passing.

Native protected-save tests installed two real stone-targeted burner drills with output buffers, reducing actual drill stock from 23 to 21. Paid stone-capacity/fuel recovery observed genuine engine stone production, reaching 74; the exact-final-source output-priority continuation subsequently observed 79 and returned mined material to managed storage. This is actual construction/commissioning/output recovery, not a sustained science-throughput result. Its original saves remain hash-protected. The current stock preference uses researched stocked burners for this commissioning path; electric generation, wider workforce coordination and all later campaign milestones still require validation/iteration.

All 61 Lua groups and seven Python tests pass on the final runtime source, including the added miner-site and original drill-fuel/custody checks. The exact runtime also passes isolated four-rank native maintenance. A separate fresh default-spacing four-way arena on published 6da25f5a timed out at 1800 wall seconds before its required 108000 active ticks; one faction still had zero native science. It is incomplete, never a factory/combat pass. The latest three inherited rail failures remain separately recorded as reproducing on clean main. The campaign goal remains active and OPEN through actual rocket launches and space-science research.


## 2026-11-15 - Deliver counted science before resuming strict manufacturing

The reconciled cd34f304 source passes native four-rank maintenance. Its protected factory continuation reproduced a circular wait: at tick 107701 the Magos still held two red science packs picked up at tick 79715 for lab 65, while 0488 classified a later strict stone-brick task as crafting. The raw governor correctly refused another acquisition because item_family_custody_0702 was held. Research remained at 0.3666666667 and all downstream supply waited.

The classifier now refuses the crafting surface while that counted item-family cargo exists, allowing the original 0702 delivery owner to finish. It does not clear the parent, manufacture packs, relax transfer distance or take over item custody. The regression creates a strict brick parent after an actual source pickup and uses original 0488/0510/0702 through exact lab delivery, then proves the same strict parent resumes.

The exact tick-107811 protected checkpoint was replayed with the fix. Native observations confirm empty science custody and resumed canonical stone acquisition. By tick 119886 native red production rose 118 to 137 and actual research progressed 0.3666666667 to 0.9988910561. Green stayed 12 and military stayed zero: the supply-capacity bottleneck remains and this recovery is not a fresh throughput or campaign pass. All 58 Lua groups and seven Python tests pass. The three separately recorded rail checks remain pre-existing main failures. Evidence: arena-evidence/science-cargo-circular-wait-recovery. The original save remains hash-verified unchanged.


## 2026-11-15 - Reconcile autonomy validation with current main and native process state

Resumed the autonomous rocket/space-science goal and reconciled the validation checkout with main 12e434995b7af0c6b477ccaeacd689a4b82a0c78. The published behavior tip 80fd71ae was 34 commits ahead of, and missing 78 commits from, main. Integration retains the behavior fixes and main's colony/research, remote-rail, combat and asset deliveries. The sole content conflict in the original 0338 terminal path was resolved by retaining both the factory-output-link receipt and the independently verified paid remote-drill receipt; neither owner replaces the other.

The existing 58 Lua behavior groups and seven Python tests pass on the combined source. Additional construction/dispatcher handoff checks pass. Three additional rail checks fail identically on a clean archived main snapshot and the integrated checkout: rail_track_frontier_0836's fixture source-string assertion, remote_rail_outpost_0835's diagonal clearance expectation, and movement_overleash_return_continuity's included rail_expedition_transit_1401 waypoint assertion. These are preserved as existing failures, not silently reported as a fully passing suite. The native maintenance and factory evidence from 80fd71ae remains attributed to that exact source until the integrated source is run natively.

The old parent-output matrix's running status was stale: its isolated default arena process is absent and there is no final result. Reconciliation must mark it interrupted/incomplete, preserve its failed science and timed-out contact evidence, and keep each run's original source identity. No live validation server was found for those job names. Existing recovery saves remain protected. The full campaign goal is active and unaccepted; no merge, early-science recovery or maintenance result proves rocket launching or orbital space science.


## 2026-11-15 - Revalidate occupied mining contacts and preserve autonomous recipe handoff

Continued native behavior validation against the rocket/space-science campaign goal. The failed earlier factory run had an empty boiler while a strict manufacturing task retained the priest. The arbiter now permits existing canonical fuel service for strict recipes even without the separate facility-only flag. Physical construction, recipe-feed, station cargo, silo/artillery/roboport cargo and refund holds retain their protection. The dispatcher regression executes the original fuel owner through real-shaped source debit, counted coal custody, delivery and resumption of the same strict parent. This establishes admission/custody behavior; it is not an end-to-end native rocket or throughput result.

A fresh isolated baseline reproduced another hard blocker: Senior station 2 repeatedly routed to an old ore contact at approximately 81.3838,20.6162, now inside an actually constructed electric mining drill. The engine reported can_place_entity=false there, and native unit AI wandered away. The direct-acquisition owner now rechecks a cached contact before refreshing its path and selects another clear point within the unchanged 1.5-tile mining reach. A completely blocked target replans without extracting remote ore, teleporting or expanding authority.

The protected tick-67211 checkpoint was replayed with the contact fix. The original Senior physically mined and deposited ore, exposing a subsequent station-craft-order-transition-failed at tick 70840: an autonomous legacy task had no queue current, but the loaded queue module was treated as proof that there was an order to transition. The handoff now preserves that task's existing recipe owner when no order exists; actual current orders still use the original transition/refusal path. Tests execute both branches against the genuine queue module.

The final matched native replay of the same protected save records station-craft-handoff at tick 70840 and a real iron-ore deposit. It completed to tick 79294, with red production rising 82 to 102; green remained 12 and military remained zero. This is narrow physical recovery evidence, not the 5-SPM factory gate. A separate established-factory continuation reached tick 582046 with red 569 to 586, green 179 to 195 and military 80 to 90, completing flammables research and progressing landfill. That earlier continuation predates the last handoff change and must not be cited as exact-final-source acceptance.

All 58 Lua regression groups and seven Python tests pass. The exact-final-source isolated four-rank maintenance scenario passes: native production, naturally occurring degradation, paid repair and consecration all complete. Evidence is retained under arena-evidence/cached-ore-contact-handoff-native-recovery and maintenance-fuel-contact-handoff. The original baseline save is hash-verified unchanged. Campaign acceptance remains OPEN: sustained factory throughput, four-way arena completion, autonomous launching and orbital space-science operation are still unproven or missing.


## 2026-11-15 - Campaign goal is autonomous rocket launch and space-science research

The user clarified the final goal: autonomous operation all the way through actual rocket launching and space science. Early red/green/military throughput and four-way arena results are prerequisite tests. They cannot establish campaign completion. Standard player mode remains autonomous maintenance and assistance; independent player mode and non-player factions must plan, construct, supply, research and defend their own force-wide industry through the endpoint.

Acceptance requires native progression through the science actually required by the enabled profile, paid silo construction, genuine rocket parts and valid payloads, a successful native launch, actual space-science production, delivery to laboratories and completed research consuming that science. Continued supply and recovery must work after the first launch. Launches should follow real demand, rather than wasting rockets to satisfy an artificial count. The profile's native research order is authoritative.

The current isolated profile enables Space Age. The installed 2.1.24 recipe for space-science-pack requires gravity zero and real iron plates, carbon and ice. Its acceptance therefore includes paid orbital construction, asteroid/material processing and return science delivery. Base-game launch products are a separate profile. Do not add production/utility science as synthetic prerequisites to Space Age's earlier rocket unlock.

Inspection found another actual planning ceiling: the autonomous portfolio maintained only red, green and military capacity outside the current research basket. It now retains each actually unlocked chemical, production and utility science chain too. Locked recipes remain excluded and native current-research ingredients remain authoritative. Tests cover later unlocked production during red-only research and refusal of locked utility science. Space science is not treated as an ordinary ground-assembler portfolio recipe.

The exact endpoint and evidence rules are recorded in tests/fixtures/autonomous_campaign_goal.json, explicitly unvalidated. Midgame objective reports now identify their prerequisite scope and always state campaign_accepted=false, including when the early factory gate passes. All 58 Lua groups and seven Python tests pass, and the native-checkpoint audit self-test passes. This does not prove advanced science production, launches or orbital operation. Silo logistics currently stops at rocket-ready-monitor; there is no autonomous launch call in the runtime scripts. Launch ownership, orbital planning and end-to-end space-science validation remain required work. The queued 2317972 science run failed its three-family throughput goal; its contact diagnostic timed out. Preserve these failures while working toward the full campaign goal.


## 2026-11-14 - Collect real parent output and unblock previous furnace products

The native factory exposed a definite material-flow deadlock: its owned furnace held iron ore and coal but remained in full_output because two old stone bricks occupied its result slots. A facility-only iron parent had no strict_recipe flag, ordinary output collection could not preempt it, and collecting only ingredients or the requested product could never clear the old bricks. The native before state had zero stored iron; no missing-resource assumption was needed.

Original 0528 discovery now prioritizes an owned strict/facility parent's actual completed output over unrelated aged jobs. It may also collect a previous furnace product only when the real engine reports full_output and the furnace's current recipe matches the parent. Already functioning paid output automation is preserved. The canonical classifier handles such production surfaces without requiring an explicit queued crafting order, and counted output cargo retains its original return journey. Foreign explicit orders, other physical cargo, foreign movement leases and unowned machines remain protected; only the recently serviced parent's own legacy move may yield. No product cleanup credits the parent's desired output or completes its order.

Native recovery proves the two old bricks moved into real general storage (50 to 52), the furnace changed from full_output to working, and real iron stock rose from zero to three. Subsequent actual smelting and science continued with the original owners. All 58 Lua groups and seven Python tests pass, including full discovery/classification/pickup/return/deposit coverage, prior-product cleanup, absent queue orders, foreign custody/order refusal and no imaginary iron credit. Native maintenance still passes all four ranks.

The fresh 1eb2ab1 compact contact diagnostic also records actual five-damage hits in both directions: faction 1 to faction 2 at tick 41887 and the return hit at 48324. That confirms fresh participant combat at 64-tile spacing; full four-factory acceptance and the unchanged default-spacing combat gate remain separate and open. Full science and arena reruns of this further furnace correction are still required; do not count earlier source snapshots or partial rates as acceptance.


## 2026-11-14 - Native output flow, measured staffing and counted-stock fetch recovery

Native paid output automation now works: original construction placed two verified powered inserters, with twenty-nine real gears and twelve red science packs observed in their respective output chests at tick 541176. Recovery later reached 534 red, 152 green and seventy-four military packs. Temporarily occupied inserter sites retain their paid chest for bounded retry. Optional mining-capacity requests refused by the original builder with no-miner-site yield for one minute, retaining strategic intent, so an impossible extra drill cannot monopolize the shared construction request slot.

Staffing now recognizes a commissioned eight-machine factory's measured shortfall. It requires actual science production history, a powered local lab and a minute below target, preferring the native ten-minute rate to a misleading one-minute burst. Exact paid kits, immediate lower-rank hierarchy, capacity and physical-custody rules remain unchanged; the first furnace cannot trigger this exception. Native default-arena recovery has physically constructed Senior assistants in three forces, and further intermediate requests retain the original paid rank ladder. This is recovery evidence, not a fresh acceptance pass.

One force repeatedly fetched one of its two already-counted science packs toward a three-pack total target. Its counted total never changed and the high-priority fetch wrapper prevented ordinary planning. Fetch source selection now excludes canonical inventories whose stock already contributes to that target, while still finding genuinely uncounted storage and ground items. Native Factorio inventory wrappers compare equal but have different raw table-key identity; stable entity units and explicit inventory equality are required. Regression coverage reproduces that distinction. The previously looping force stopped fetching, resumed science from 54 to 64 packs, and physically built its Senior assistant.

Native forest/shoreline diagnosis also found sixteen sampled generator offsets were not a complete site search. A bounded cached local grid fallback now verifies real steam-engine footprints and inlet contacts. The actual nearest viable generator was fourteen tiles from the boiler. The fourth default-arena force physically built that engine and advanced to its output-pole request; full power, research and first science remain to be verified. Moving machine-service detours retain a fixed bounded contact allowance; stationary or expired paths still replan without changing cargo.

Verification: all 57 Lua groups and seven Python tests pass; native maintenance passes all four ranks. Preserve both completed baseline failures: fresh-first-craft-output-science-gate reached all nine observer marks but had zero final-minute red/green/military SPM, and four-way-paid-output-default-gate finished with one force lacking science and no participant combat. Fresh repaired science and both arena spacing profiles still require full native acceptance. The previous single five-damage compact contact and recovered factories do not close those gates.


## 2026-11-14 - Physical intake clearance, first-craft fairness and paid output automation

The blocked arena intake now admits only its exact observed neutral wood tree through the original raw acquisition and direct executor. Native mining, carried wood and actual return remain under their original owners; the strict infrastructure parent and matching adopted production order survive. The original priest harvested and deposited four real wood at tick 98180. A genuine compact-arena continuation now proves red output for all four factions (89/74/10/75 at tick 120068). This does not pass the original 108000-tick deadline or default-spacing combat gate.

Item-family and laboratory fetching now select collision-clear stable contacts around actual storage footprints. Native diagnosis then exposed coal-first multi-input starvation: seventy coal and zero iron in a grenade assembler still selected coal-buffer top-ups. Ingredient discovery now completes one craft before transport-buffer top-ups and yields when an unavailable first-craft ingredient is missing. Existing stock, custody and native insertable-space limits remain authoritative. Native recovery resumed military production from fifty to fifty-two packs after this correction; sustained throughput remains unproven.

The ratio planner now coordinates funded output chests and inserters for exact owned configured recipe machines through original 0338 construction. Dedicated builds retain each real paid configuration receipt, separately from the general emergency workshop ledger. Output links verify original construction identity, exact grid-aligned positions, current native recipe, actual inserter pickup/drop targets, power and chest space. Their verified outgoing inserters permit manual ingredient supply; foreign or incoming automation remains excluded. Unpowered or full output storage retains manual collection fallback. Output siting uses actual machine footprints; the first native integer-position request exposed engine snapping and was refused, preserved, and corrected. Functional native output-link verification remains open.

Verification: 56 Lua groups and seven Python tests pass. Native all-rank maintenance passes with the output coordination changes. Strict science acceptance is recorded before optional visual rendering so a missing Pillow installation cannot conceal its native result. The completed fresh warm-plant run still fails simultaneous red/green/military 5 SPM despite working generation and actual research. Fresh full science and unchanged default-spacing four-way factory/combat runs continue, with exact copied source manifests. No continuation or partial construction substitutes for those gates.


## 2026-11-14 - Native fluid-aware plant placement and sustained service reserves

Fresh native diagnosis showed a water line enclosing the steam exit against a shoreline. Power planning now reads real fluidbox prototype connection positions and native tile dimensions, aligns the machine to its actual grid, verifies both boiler ports, keeps a forward steam contact clear and prioritizes the real source-to-inlet distance over station proximity. Three fresh arena factions produced red science with powered laboratories and actual research by tick 48843. The fourth exposed a tree obstructing its pump outlet. New pump sites verify their native outlet and onward pipe contact; an observed blocked existing intake may request a separately funded replacement through original 0338. Fluid source selection skips physically blocked free outlets. Native continuation physically built the replacement and selected it, but a remaining water-route refusal is still open; this is not four-faction acceptance.

Native science checkpoints also showed boiler fuel exhausted between eight-coal trips. Vanilla coal boilers now request service below a sixteen-coal reserve even while burning and use a maximum fifty-coal paid trip. Other fuels, unverified modded burners and connected inserter/loader ownership retain their original rules. Burner prototype names are read safely for native Lua objects. Actual native observation at tick 444736 confirms a working boiler holding forty-four real coal and powered science assemblers.

A completed trip delivering only one ingredient no longer erases a multi-input recipe's waiting priority. Credit resets after usable real inputs or deposited recipe output; refunded and incomplete deliveries do not claim a serviced recipe. Measured completed service-round durations size two-to-ten-minute input buffers, bounded by native insertable space and the original fifty-item trip cap. Full input slots cannot monopolize futile trips. The dispatcher now asks repair to relinquish a stale route when an already-started machine transaction resumes; real repair orders, held packs and timed work remain protected.

Verification: all 54 Lua groups and seven Python tests pass, including real movement/custody handoffs, native geometry cases, fuel reserve ownership, output-yield-aware transport and blocked-source selection. Native maintenance still passes all four ranks. Recovery science has reached 489 red, 122 green and fifty military packs, with real research. Fresh simultaneous 5-SPM throughput and complete four-faction factory/combat gates remain open. The superseded 216000-update benchmark omitted its final scheduled observer pulse and remains a failure; new strict full runs use 216060 updates and the explicit factory-objective gate. Preserve all failed deadlines and native input saves.


## 2026-11-14 - Physical construction handoffs and actual faction combat

Native continuation identified a third faction pinned to a hidden zero-size Cogitator backing inventory. Construction now approaches and measures reach against that exact same-force, same-surface host station while debiting/returning the original inventory. The faction advanced from two builds into a real boiler, engine and steam-route installation; paid workforce expansion also created a real subordinate station. A carried construction item may now advance its own source movement lease directly to its site after the canonical task changes phase. Same-phase churn, unpaid tasks and foreign routes retain normal arbitration.

Working autonomous factories now periodically observe actual local hostiles, submit through the existing lossless order queue and invoke the original combat owner. Physical cargo and active station construction retain their owners. Exact adopted recipe assignments survive preemption and resume without a destructive legacy combat assignment. Repair terminal routes release only their own lease, and stale repair walks yield to an already selected physical machine trip. Missing native workshops can admit their exact funded bootstrap construction after a recent original production refusal.

The 64-tile diagnostic recorded actual participant damage at native tick 81474: tp-arena-1 hit tp-arena-2 for five damage. No scripted attacks, teleports or free output were introduced. Subsequent native observation exposed invulnerable proxy targets; the canonical safety predicate now rejects native destructible=false targets, including persisted targets. This contact continuation is evidence of real combat, not acceptance of the unchanged fresh default-spacing arena.

Water routing also exposed incompatible placement margins: a legal pump's observed pipe outlet lay outside the ordinary pipe inset. Only the exact same-domain native water outlet may use a half-tile inset; route interiors retain their original margin. Native geometry then showed that a previously built steam pipe had sealed the boiler's unbuilt water inlet. New routes preserve the distinct boiler port and its adjacent connection cells and reject differently filtered ports even while empty. Fresh reruns must verify this prevention; already sealed legacy routes are not claimed repaired.

Verification: 54 Lua groups plus seven Python tests pass. Native all-rank maintenance passes using real stocked items. A completed fresh science run reached 230 red, 24 green and eight military packs at tick 216071; a later recovery reached 410/102/30. Sustained simultaneous 5-SPM throughput and full fresh four-faction factory/combat acceptance remain open. Fresh native-port science and 64-tile arena runs are underway; preserve their real deadlines and failures.


## 2026-11-14 - Retire terminal orders and unblock real power prerequisites

The 0512 lease wrapper resurrected queue-expired repair requests while unrelated factory work existed, keeping requests created near tick 6000 active past tick 110000. Terminal queue decisions now remain terminal; genuinely nonterminal active-work leases remain protected. Exact adopted recipe-fanout assignments route to their canonical native production owner, complete only against actual output, and clear only the matching old assignment aliases. Unladen source-approach construction planning no longer vetoes an incumbent native furnace's exact raw child. Canonical raw tasks whose blocked targets were cleared now retarget the same task to reachable real resources, preserving counts, timers, explicit orders and actual custody.

Maintenance supply/reserve accounting and repair consumption now use the canonical bounded, same-force storage authority. Native inventory equality replaces shared display-string deduplication. Existing repair packs in a nearby cargo store resolve supply intents; repair/consecration actions themselves remain open until their real executor completes. Native all-rank maintenance still passes. Paid workforce planning now accounts for the commander's own eight-machine service capacity before recruiting, avoiding duplicate early bootstrap factories. Eligible factory input trips carry a two-minute demand buffer, honoring native recipe product yield and the existing transfer cap.

Native diagnosis found a fully supplied first-lab assembler with zero electricity while its strict recipe starved an existing steam pipe. The classifier now admits only the matching funded native power/steam request for an actually owned, configured, unpowered workshop, with foreign orders and held cargo protected. The original 0338 builder paid for and built the route; the assembler completed its laboratory, Factorio unlocked red science and the first recovered faction produced six actual red packs by tick 286628. All four recovered factions now have native Steam Power and Electronics. These late continuations do not pass the original fresh arena deadline.

The canonical threat query also filtered only the literal enemy force. It now scans forces currently hostile under native diplomacy, retaining the original target safety checks. The actual selector regression detects a hostile priest force and drops it when diplomacy changes. A separate equal-stock 64-tile arena is under validation; smaller spacing is refused because authored resource patches can overlap. Default arena spacing and success gates remain unchanged.

Verification: 49 Lua groups and seven Python tests pass, including 75 production, 25 dispatch and actual canonical repair-debit/health cases. Native recovery has reached 394 red, 92 green and 30 military packs, but fresh sustained factory throughput and real participant combat remain unaccepted. Continue native iteration; do not equate these diagnostic recoveries with full completion.


## 2026-11-14 - Native production ownership and starvation-free factory trips

Facility-only furnace work was blocked from legacy execution but still absent from canonical craft classification. Such native tasks now receive the same canonical dispatcher ownership as strict production, while their expressly marked raw-material child and physically held construction/mining items retain priority. A redundant native plate-trigger batch may close only after the actual force technology is researched and a real plate is held; it never manufactures output. Satisfied, unladen independent legacy scavenging intents also retire against counted stock instead of indefinitely walking into a container.

Military intermediates still starved when bounded waiting credit saturated during ordinary walking rounds. Eligible configured factory trips now receive linear waiting credit, reset only after the existing owner verifies completed supply/deposit. Native diagnostic continuation then reached 320 red, 62 green and four military packs, with actual firearm, piercing-magazine and stone-wall production. This establishes real military-chain execution, not the original fresh throughput/deadline objective. The simultaneous fresh run remained below target and still had zero military at its last recorded checkpoint.

The existing arena harness accepts an explicitly labeled optional --force-spacing 48-192 only for compact four-way diagnostics. Default 192-tile spacing, supplies and all factory/combat assertions are unchanged. A 64-tile diagnostic uses identical counted supplies and unbuilt station kits, existing hostility and natural combat discovery; it issues no attacks or movement and grants no science/research. All 47 Lua groups and seven Python tests pass, including default/contact geometry and conservation checks. Preserve failed arena/science outcomes and continue native iteration.


## 2026-11-14 - Productive service admissions and paid ranked workforce

Native inspection found that repeated fresh repair discovery starved funded factory ingredient trips. Independent commanders now alternate maintenance and funded factory-service admissions through the existing dispatcher. Existing orders, physical cargo and hostile incidents retain their owners. A source-less laboratory request also yields its recommendation while retaining its original target/request identity; it resumes when real science stock exists and the intervening carrier has finished its cargo.

Independent commanders now request immediate lower-rank workforce stations against actual local factory load, free command capacity and counted station kits or a verified physical surplus donor. Existing 0256/0824 construction owns travel, native placement, one-kit custody/debit, pairing and exact hierarchy validation. Only after the real child is linked does the existing emergency-operation owner enable its independent planning. Player assistance mode does not recruit workers. Explicit orders, held items and reserved recovery/courier workers prevent recruitment.

Validation: 47 Lua groups and seven Python arena tests pass, including paid physical station construction and inherited child autonomy. The native all-rank maintenance regression passes with 120 operations, eight repairs and natural decay at all four ranks. The first fresh workforce arena physically built two stations per faction but still FAILED factory/combat gates: zero science and zero participant contacts by tick 110040. This failure remains evidence; ranked construction alone is not autonomous factory acceptance. A diagnostic factory continuation increased green production from 12 to 32 while military remained zero; a source-less laboratory wait was then identified and repaired. Fresh science, force-wide production and actual arena combat remain open.


## 2026-11-14 - Fulfilled reserves and physical ore access

Native science recovery still retained an unladen twelve-stone bootstrap task with 403 usable stone. The raw governor now retires only its own automatic, already-funded reserve, preserving active explicit orders, timed extraction and actual mining custody. Independent furnace-only iron/copper recipes now request bounded ore/fuel through the canonical raw child when generic reserve sweeping is disabled. An obsolete parent ingredient wait cannot replace that active furnace dependency. The furnace recipe and its exact raw child remain separate owners.

Native inspection also found mining waypoints inside working burner drills. Direct acquisition now selects a collision-clear approach within its unchanged 1.5-tile extraction distance, with actual authority bounds checked. Travel arrival uses the executor's precise radius. The behavior observer releases only its own obsolete route and delegates movement to the canonical mining/production owner.

Observed recovery: both science furnaces changed from empty/idle to actual stone-brick recipes, with 43 real bricks measured at tick 185346. In the previously blocked arena, tick 115976 measured actual iron production 51/42/44/52 across the four forces after the mining-contact repair; two had completed Steam Power at that observation. These are diagnostic continuations, not a fresh full-factory or combat acceptance. The preceding 2f6f299 fresh science run completed eight research technologies but failed sustained science and military production. Latest source/unit verification retains all 46 Lua groups and seven Python arena tests; full fresh gates continue.


## 2026-11-14 - Real technology prerequisites, recipe recovery and mining capacity

The repaired arena exposed a second genuine boundary: supplied copper, iron, labs and generators do not satisfy native craft-item technology triggers. The bootstrap owner now demands real ten-copper and fifty-iron production above existing stock until Factorio completes Electronics and Steam Power. Its existing completion handoff releases only an actually researched plate batch with physical plate stock present. A native diagnostic continuation at tick 163642 measured Steam Power, Electronics and red-science unlocks on three factions, with actual red output 3/2/2; the fourth remained at eight copper plates. This is late recovery evidence, not a passing original deadline or four-way combat gate.

Three factions also retained an impossible circuit craft for tens of thousands of ticks: native inspection measured two usable cable against a three-cable ingredient requirement. A strict transaction refused before any debit now restores that missing dependency and its original parent to infrastructure planning. It does not cancel committed ingredient/output custody or credit completion. Legacy mining callbacks and lifecycle aliases now yield both strict recipes and furnace-only production to their canonical owners; explicit raw-material tasks remain separate.

Native prototype reads measured one-second iron/copper/coal/stone mining, burner speed 0.25 and electric speed 0.5. Ratio planning previously hardcoded a five-second ore estimate, overstating drill demand and consuming construction time. It now uses resource mining time and expected item yield, retaining the compatibility estimate only when no mapped native resource exists. Established, physically configured science with measured prior production also relinquishes FIRST-science bootstrap priority; consuming a red pack must not indefinitely suppress a wall assembler's real brick shortage.

All 46 focused Lua groups and seven Python arena tests pass, including 73 bootstrap cases. The full native maintenance regression passed all four ranks after the physical-contact changes, with real operating machines, natural decay, rites and eight repairs per rank. Fresh science and four-way tests continue. Full sustained science, all-faction research, rank-linked expansion and actual participant combat remain unaccepted.


## 2026-11-14 - Native material waits and inaccessible factory contacts

The isolated aac3fc8 fresh science run reached nine checkpoints and six actual research completions, but its factory objective failed: 129 red packs, 10 green, zero military, and zero final science rates. Fixture-observer PASS is not factory acceptance. The isolated compact four-way baseline also failed factory progress and participant combat.

Native inspection proved each arena faction had 40 usable wood in a canonical supply crate. Raw-material readiness nevertheless counted only station buffers. Readiness now includes genuine general-container inventories, retains legacy bootstrap buffer accounting, and deduplicates native inventory wrappers by equality. The new regression fails on the preceding source. The native rerun passed the former three-build stall, exposing further access failures.

Passive native path observation exposed failed station returns and boiler approaches. Station crafting now chooses a collision-clear point inside its original reach. Energy logistics selects and retains a clear external service contact, avoiding plumbing-blocked corners. Construction verifies source contact clearance. Production and construction arrival no longer add loiter padding outside physical work reach. Actual cargo, ingredients, fuel and build-item debits remain with their original owners. Native fuel delivery and construction have resumed; throughput, ranked expansion and combat gates remain open.

Validation: 46 focused Lua groups and seven Python arena tests passed. New tests cover crate wood, walkable station crafting, a blocked boiler corner, blocked construction-source access, and arrival/reach agreement. Exact source manifests, observations and CRC-checked saves remain in workspace arena-evidence. Work is isolated on behavior/arena-capacity-20261114 from concurrent enemy-planet changes in the older checkout.


**Status:** Canonical narrative development history  
**Authoritative branch:** `main`  
**Packaged baseline:** `0.1.672`  
**Active development lane:** `0.1.674-dev`

## History Policy

This file is the single canonical narrative record of significant Tech Priests development. Focused maps, ledgers, manifests, runbooks, and `RECOVERY_REPAIR_SEQUENCE.md` are supporting evidence rather than competing histories.

Source implementation, source validation, Factorio loading, migration, save/reload, behavioral validation, profiler evidence, packaging, packaged-load testing, and publication are separate states. None substitutes for another.

## Artifact Truth

`tech-priests_src/info.json` remains at `0.1.672` while recovery gates remain open.

Experimental `0.1.674` prerelease artifacts exist. The committed and published `v0.1.674-rc.3` records `prerelease=true` and `runtime_validation_complete=false`. It is not a verified release candidate or verified release.

An unpackaged `0.1.673` copy may be generated only for migration testing. It is not distributable.

No accepted Factorio runtime logs have yet been recorded in this history.

## Machine-Output Custody Versus Strict-Craft Arbitration — 2026-10-20

Source inspection found a physical-custody arbitration defect: a due strict
craft was classified before a nonterminal machine-logistics return, while
the machine recommendation rejected explicit crafting orders. Ore already
removed from a real machine could therefore remain carried indefinitely
instead of returning to station storage. The 0488 classifier now suppresses
crafting while 0528 holds physical custody and allows that custody to bypass
only the order-kind gate and the ordinary unladen-mining output gate.
Combat priority and candidate-only craft exclusion remain unchanged.
The existing machine-output handoff regression now covers strict crafting,
active acquisition, and craft resumption after custody clears.

This is a source-level repair and regression addition, not proof of Factorio
runtime recovery. The 36,000-tick electronics/science endurance gate, engine
save/reload, migration, and profiler evidence remain open.

## Re-Imprint Boundary Validator Contract Repair — 2026-10-20

Exact-head source validation at `f490db9` (run `39413419019`)
passed the sparse-acquisition Lua regressions but failed the retired-0426
boundary audit: the checker still required the legacy
`tech_priests_0298_enter_reimprint` token in `pair_lifecycle.lua`.
That contradicted the previously implemented canonical-0499-only facade
and its regression proving the legacy helper must never be called.
The boundary checker now requires the 0499 authority declaration,
canonical `begin_reimprint` delegation, and literal-boolean success;
it rejects reintroduction of the legacy helper in the facade. The
runtime facade is unchanged. This is an authoritative validation-contract
repair, not a reversion to a deprecated lifecycle route. A fresh exact-head
source-validation pass and Factorio runtime proof remain separate gates.

## Sparse Direct-Acquisition Item and Action-Target Resolution — 2026-10-20

Source inspection found two Lua sparse-array defects in the recovered action
path. The physical direct-acquisition executor iterated optional child and
parent item fields with `ipairs`; when the first child field was absent,
iteration stopped before reaching a valid parent item. This incorrectly failed
otherwise valid physical mining with `explicit-output-item-required`.
The executor now checks each named field child-first, then parent, without
silently accepting a physical output mismatch. The action classifier likewise
used `ipairs` on a sparse target-priority list; an absent order target could
hide a real direct-acquisition leaf or the pair's fallback target. Dense false
sentinels now preserve the existing target precedence and read-only behavior.

The existing direct physical-guard regression now exercises parent-only ore
extraction through real resource decrement, exact station deposit and cleared
custody, plus child-item mismatch rejection before physical mutation. The
existing machine-output arbitration regression now checks sparse direct leaf,
explicit order, and pair-fallback target selection. These are source and
focused-regression repairs, **not** proof that Factorio electronic-circuit or
science production has recovered. Re-run the unchanged ground-rank endurance
and save/reload gates; no release authorization follows from this slice.

## Headless Ground-Waypoint and Safety-Return Recovery — 2026-10-20

The Factorio ground-rank headless endurance tests exposed sustained
movement-command churn and off-station drift, with no circuit or science
production. Run `39399124884` finished with four priests roughly
109–254 tiles from their stations and 2,173 engine commands. Later
run `39400987217`, after movement priority and segmentation work,
finished with all four priests roughly 5–11 tiles from their stations;
it still failed the unchanged production gate with 53 ore, 33 plates,
zero circuits and zero science. This is **improved movement evidence,
not a passing Factorio runtime test**.

The native `movement_controller` now prevents lower-priority owners from
stealing active higher-priority routes after the retarget hold expires;
retains live overleash recovery routes instead of repeatedly stopping
them; issues a fresh go-to command only when physical movement stalls;
and uses nondistracted engine navigation for ordinary movement. Long
station-return paths are divided into bounded segments even in headless
runs, and the same controller automatically advances the next waypoint
until the final destination is physically reached. A discovered root
defect relabeled return routes as `ground-route-waypoint-0633`, causing
the boundary checker to reject distant homeward waypoints. The original
movement reason is now retained. The ground-route source checker rejects
reintroduction of this unsafe relabeling.

The same runtime diagnostics exposed 7,362 denied lower-priority movement
requests in a 36,000-tick recovery run. The canonical
`logistics_machine_fulfillment_0528` terminal transition previously
released its machine claim but retained its priority-740 movement lease.
It now releases that route through the canonical movement controller
only when it still owns the active request, protecting foreign movement
from accidental cancellation. Two additional ownership regressions
in `tests/unit/machine_output_acquisition_handoff.lua` passed under
isolated Lua 5.3 (7 total scenarios, exit 0), using verified Git blobs.
GitHub Actions source validation also passed at
`28ae3463a8e218816beeabc60e767e37ed7edb6e` (run
`39401829390`). The subsequent headless Factorio endurance outcome
must still be assessed independently.

The Lua 5.3 isolated `movement_overleash_return_continuity.lua` test
passed **13 scenarios**, covering priority ownership, uninterrupted
pathfinding, stall-repath cadence, long headless recovery hops and
physical arrival. GitHub Actions source validation passed at
`a7deefc4d5f021ec7c7741a82cb4f0f03bbbb6d0` (run
`39401200605`). The headless fixture also exposes per-route waypoint
and priority counters for subsequent real-engine checks. No completed
electronics/science recovery, live save/reload, migration, profiler,
release package, or release authorization is claimed.

## Consecration Reservation Identity and Fail-Closed Claims — 2026-10-20

The shared reservation authority no longer treats disabled claims as successful.
The shared work queue now requires a reservation-capable authority, captures
the authority-issued key on successful claims, and retains that key on the
selected order so release does not depend on reading a destroyed entity.
When a successful claim omits its identity, the queue uses a preclaim key
snapshot for owner-checked rollback rather than silently retaining custody.
The consecration executor revalidates post-selection eligibility, releases
an invalidated selection using its stored key, and consumes the reservation
authority's issued key for its direct claim path as well.

The shared work queue additionally rejects a target that becomes invalid
*inside* successful claim acquisition, releases the authority-issued key,
removes that invalid work order, and requires a release-key interface before
allowing any family claim. Direct consecration admission now carries the
shared or explicit provisional key through queue submission and rejection;
it revalidates target life after the claim and never regenerates a release
key from a destroyed entity.

Ten regression scenarios were added to
`tests/unit/consecration_queue_reconciliation.lua`: fail-closed authority
and interface checks, successful claim without an identity, owner-keyed
rollback, post-destruction release, invalidation during shared and explicit
claim, direct executor renewal, queue-rejection restitution, and the generic
shared-work family boundary.

**Isolated focused regression evidence:** On 2026-10-20 the actual seven
source/test Lua files were retrieved from GitHub `main` at
`ba9d7a744b89f17835ae23ac2a3c1fa9a56d9b60`, and their exact Git
blob SHA-1 hashes were verified after transfer. Running
`texlua tests/unit/consecration_queue_reconciliation.lua` from the
repository-root layout with Lua 5.3 produced **38 PASS scenarios**, exit 0.
This validates the focused suite against its exact fetched module contents,
not the complete source-validation pipeline or the Factorio engine.
The seven-file isolated test environment does not prove that all other
optional modules load and integrate in a complete game install.
Factorio load, migration, save/reload, in-game behavior, profiler result,
packaged-load, and release authorization remain unaccepted. Stage 5
remains open; the protected `0.1.672` packaged baseline is unchanged.

## Pair Lifecycle Installation Integrity — 2026-10-18

The pair lifecycle facade previously set its installed flag before loading
and installing spawn-position and naming dependencies. An exception or
false/empty dependency result could leave a falsely successful facade that
silently skipped subsequent installation attempts. Dependency loading and
installation now use explicit protected checks, require literal success, and
publish the lifecycle facade only after both dependencies initialize.
The bootstrap caller now requires literal `true` from the facade installer and
raises an initialization error instead of logging a false successful load.

The standalone Lua 5.2+ regression at
`tests/unit/pair_lifecycle_install.lua` covers successful installation,
idempotence, missing installers, false/nil results, exceptions, and retry
after a failed dependency. An isolated Lua 5.3 reproduction passed locally;
Factorio loading, save/reload, migration, behavioral integration, profiler,
packaged-load, and release evidence remain unaccepted. The protected
`0.1.672` baseline is unchanged.

## Emergency Facility Physical Feed Accounting — 2026-10-18

The station-to-emergency-facility fuel and ingredient paths removed real
Cogitator stock before inserting it into a destination inventory. A partial
or refused insertion could erase the difference. The source now preflights
destination capacity, refunds unaccepted items, and records a primitive,
saveable `emergency_facility_feed_custody_0357` when the refund is blocked.
Outstanding custody is restored to station inventory before any further
facility feed; malformed custody fails closed rather than disappearing.

A standalone mocked-Lua regression covers full destinations, partial
insertion, blocked refunds with later recovery, and inventory preflight
failure. The test is available at
`tests/unit/emergency_facility_feed_accounting.lua`.

**Evidence:** source implementation and test addition only. Factorio loading,
migration, behavioral/save-reload, profiler, packaged-load, and release
authorization remain unaccepted. The protected `0.1.672` version is unchanged.

## Foundation Before Recovery

The 0659–0675 Mermaid and function-map series documented dispatcher, arbiter, order queue, movement, acquisition, construction, infrastructure, production, consecration, repair, and combat repair. They exposed overlapping state writers, wrapper-order sensitivity, scheduler ambiguity, and incomplete cleanup.

Later development added physical machine and item logistics, storage roles, real fluid-network planning, energy systems, silos, artillery, roboports, fluid turrets, movement truth, repair integrity, lifecycle checks, migration tooling, command cleanup, and automatic diagnostics. These systems remain runtime-unproven.

## Void Priest Movement Staged Repair

- `ce672614eac3cdec3433620981e5220582aa1926` — began movement sovereignty and request-lifecycle repair.
- `a05942eead55674efc89a240a46cf0caa1099835` — added `docs/VOID_PRIEST_MOVEMENT_REPAIR_PLAN.md`.
- `6c2643804cdbbd7ce267a5d40ff92190d56fe4a8` — preserved corridor authorization while removing ground-leash ownership.

Void movement remains source-only pending obstruction, proxy, fairness, save/load, and runtime proof.

## Base-State Recovery and Unification Directive — 2026-07-17

A Mermaid-guided, source-wide audit determined that feature growth had to stop until base-state integrity, runtime ownership, performance, and evidence were recovered. It identified production transaction defects, untruthful queue acceptance, unsafe event composition, fail-open hardener installation, mutable classification, direct state rewrites, periodic and scan pressure, stale map coverage, and contradictory artifact language.

The project owner authorized one standalone top-level recovery document as a deliberate exception to normal documentation practice.

### Governance and documentation connection

- `38aca217102d5dbc386f5a65c04416005239d1be` — created `RECOVERY_REPAIR_SEQUENCE.md`.
- `8db2150978cb2368a13112bdc00f73479f1f32f0` — authorized the exception in permanent standards.
- `6ef3f92be0c172c16f6d9c742b06ff4f5933011d` — connected packaged-source standards.
- `f734adf4e90d29d529b584f1e0b2cc77a03330be` — made README the documentation entrypoint.
- `4e266964f67bfeea1a0e872481dbd0ac0e106d36` — aligned runtime continuity.
- `9c6244331b707ef02d4ae182bcc73dd02e3946c6` — made recovery the active testing order.
- `5ebd1a2af48b6edd62cf018dcd3c4674301d5cd0` — added the current recovery Mermaid map.
- `0ade5c8b3915efe59447c3aecedc7b30b45ed290` and `b5755e827eb5e7b84cf802abc056a467d5498382` — added and wired recovery architecture validation.
- `e0f825356016d78b6ff08ce6d57cb385b72b279e`, `963ea1b59a9d5b2e241f2f9eb157ea95703d462d`, and `5545b41edd9ca05ce51f209e519104f713298ce3` — reconciled artifact truth and repository navigation.

## Recovery Stage 1 — Physical State and Scheduler Truth

### Emergency production

- `091fcde83d1ed95a21da21b453f197b6f58d1b6a` — strict recipe metadata, planned removal, rollback, custody, atomic storage, and output-only collection.
- `3add1e59339b4eb6c874eb2c7065991896778210` — canonical completion and recipe metadata preservation.
- `73bcd80e2934191d87097e974a92a594c6a0d439` — explicit movement success and removal of unconditional legacy success.
- `821c2f60a35dc47d0ddb9ba8466bcd46615cb6ba` — `output-deposited` custody prevents duplicate output while canonical queue completion is blocked.
- `affa2dced8915b05e339a1c6e05168b014215d14` — regression checks forbid direct queue mutation and loose-success paths.

### Order queue

- `640ec98b345e6baf90794e7dfcf6c6ede96ec099` — truthful queue-full rejection, target identity, duplicate refresh, lossless preemption, terminal truth, promotion, and fairness.
- `283a7ba82cea6bd948f00efa180d48644bf496ac` — exactly-once caller and queue callback ownership.
- `2c4e0fc69e5ece69da55c490e9fead5f5fff1ac1` — obsolete task references can be explicitly cleared during transition.

### Consecration

- `fb2f690fec93d9dd54415c240e7de40bd3764596` — stored-key claims, pre-selection cooldown, timer cleanup, verified admission, refunds, custody, and terminal cleanup.
- `9fc3f2c77f3cca4d4c1fbbd386485c475e5053c3` — explicit movement acceptance is mandatory.

### Direct acquisition

- `86fe041e` and `608a3aa9` — physical custody, real return, atomic deposit, and scheduler-owned production transition.
- `e9535cb366f32cc4d14292a6126b7020d3be73c2` — fail-closed bounds, explicit movement and clamp success, non-action failures, obsolete-order cleanup, and canonical transfer to `p.emergency_craft`.

## Recovery Stage 2 — Shared Runtime Spine

Source recovery established owner/route-keyed event registration, deterministic priority, route-local filters, owner-specific removal, handler isolation, structured broker results, truthful action accounting, cadence preservation, post-loader hardener verification, and family-specific degraded-mode quarantine.

Key commits include `b27494ec` for the event registry and `d727553f` for broker truth.

## Recovery Stage 3 — Behavioral Authority

- `6a2c395349083f295674635abedb3332ea6fc0d9` — made `action_state_arbiter_0488` read-only.
- `665deed8570611e43a1ccc7d38a99ec4e68a1e80` — established `single_dispatcher_0510` and `canonical_action_0744`.

The dispatcher owns one fair service for recovered families and gates matching legacy behavior while owned work is nonterminal. Specialized families remain source-unproven until both their ownership and live scenarios are accepted.

## Recovery Stage 4 — Static Runtime-Pressure Protection

- `bb6dce27aae583ec715c8c83bde0cb876262d73c` — froze the pre-recovery authority-surface baseline.
- `659cbf63aa522db13ec553e3252f328de39e95bb` — added UPS regression checks to source validation.
- `78c8bd1bcd6990b622dc62f2eb3e128422259a30` — enforced canonical authority and UPS contracts.

This is source regression protection, not profiler evidence.

## Recovery Stage 5 — Evidence and Release Machinery

- `60b7e42e3f1f33079a9730f625f3fb42629248d5` and `a63c51a3e9c78f4fbfa1f935fc784126e9a666d2` — complete evidence validator and self-test.
- `573d1f5cda0dce80b56c5e75dc9bec9940c38223` — stable evidence runbook.
- `3676e4f4369c14ae6db71c5b2a73eeb4dc1d086d` and `63aa4c35c61ed7ce5665b6bc11f8c2ad7b232fe9` — exact evidence template and self-test.
- `cbd658d165fb61248ea4d7961311b7ab89468305`, `a12bedd335338080fe0512819d5fc51c5b2c5484`, and `158c2c146d390238de11c94e551af0a8509aaf19` — documentation and evidence wiring.
- `66122a7640caf9b98cb00f2a3f43bb8079f7fc25` — restored the complete Stage 5 testing matrix after truncation.
- `c47e71ab34394e7af3513cdbecbc5ed51190a311`, `e8140bb1e88a31dcbed31884db138c623505cf2c`, and `4d1a27ee0ea9973a46026d823f9b1617c65d4701` — verified-release authorization and archived publishing workflows.

Packaging remains fail-closed while source is protected `0.1.672` and accepted evidence is absent.

## Authority Consolidation — 2026-07-18 to 2026-07-20

The recovery audit continued from literal contracts into the active loader graph and found that several hardeners were themselves parallel schedulers or executors. Source was consolidated rather than adding another wrapper.

### Broker, evidence, and release controls

- `c24d9b4d`, `7dceba7f`, `a4b5b8a1`, `8cd3b464`, and `004e1e24` — made the broker registry-only, required one exact central route, and established broker-before-prearm ordering.
- `a3c9ae6c` — made proxy ammunition broker-owned with exact removal, checked insertion, atomic remainder return, and persistent refund custody.
- `33d32092` — changed visual intent to observe `canonical_action_0744` rather than mutable leaf-task authority.
- `77ffcdaf`, `f876e54b`, `9d509b98`, and related v2 commits — bound release authorization and the canonical packager to accepted digest-bound evidence with no safety bypasses.

### Retired authorities

- `36c46de5` — retired the six direct movement, mutable leaf, and remote-salvage authorities.
- `796d3b1d` — retired `construction_placement_authority_0656`, which had independently cleared acquisition state, written movement storage, issued commands, and reported unconditional action.
- `ec2a2802` — retired `repair_executor_integrity_0673`, `combat_repair_integrity_0676`, and `combat_repair_terminal_cleanup_0677` after their responsibilities were consolidated.
- `7cf730193068efbca269a2132eeb63ca95f03637` — retired the three machine-logistics wrappers after discovery, movement, custody, and terminal ownership were consolidated into `0528`.
- `0a66df06e9f163bef1b60ea1fd044dfcac786bf9` — retired `item_family_integrity_0703` after its compatibility, research-change, reservation, custody, and terminal responsibilities were consolidated into `0702`.
- `1ab40ec53dcfa697a091846667510ea160755dd4` — retired the four energy patch/assertion authorities after their policy and interruption responsibilities were consolidated into `0705` and `0707`.
- `55b301e8dea4ba65efd7c3bc26a1e39fcfdbd446` and `23f709fd3657d1d659d1774525734c0f7de207cc` — retired `rocket_silo_live_ownership_guard_0728` and corrected the planning-radius contract after the full authority-table rewrite.
- `8af42ffb50f7d615fcb8af7fedb148602d49ae73` — retired `artillery_train_validity_guard_0724` after train validity, automation ownership, interruption, and custody were consolidated into `0712` and `0713`.

At that milestone, the declarative loader contained **35 active hardeners and 20 explicitly retired source-only authorities**.

### Consolidated repair authority

- `5206b01b` and `bede0df6` — rebuilt `repair_executor_0516` as the sole physical repair owner with literal movement acceptance, shared reservations, exact pack removal, persistent `repair_pack_custody_0516`, verified health mutation, atomic refund, abort-after-refund retry, and canonical order-queue terminal calls.
- `57c160b0` — reduced `combat_repair_doctrine_0517` to tactical target, cover, and cluster selection while delegating every physical effect and interruption cleanup to `0516`.
- `2e82e936` and `e7fc917e` — made both source gates reject direct repair cadence, spilled packs, queue-internal terminal writes, or combat-doctrine movement/task ownership.

### Consolidated machine and storage authority

- `d247d37b17cc59809ee67f07cfb340590e97796b` — consolidated machine discovery, physical execution, and custody into `logistics_machine_fulfillment_0528`.
- `d239649807f01173da3f4c58693e229e3722639e` and `665655dcc3a526fb19924ad4d2db459ff711dba2` — added pure machine classification and dispatcher execution.
- `4081b002e0184736dc29676eee1653f0bd6f56ba` — made generic storage container-only.
- `8cf56944d62621029e5a296f8d8e3a505c5425b0` — made accidental priest-cargo transfer persistent and lossless through `inventory_transfer_custody_0687`.
- `33a48e864ccd73aaf16103329d92c4663bcfbe12`, `6b9e6137b568102bfd4e5a5f5f2b2e3506e2d4b9`, and the storage boundary gates — added focused source regression checks.

### Consolidated visible item-family authority

The audit found that `item_family_logistics_0702` was a free-running executor that wrote pair targets and modes, accepted loose movement success, patched hidden proxy ammunition, depended on retired leaf state, and returned non-structured broker truth. `item_family_integrity_0703` then wrapped the same executor and independently canceled tasks, cleared requests, rewrote task item/phase state, and released reservations.

- `1f05c01c935002cca3993ed51d58c0bcfef5b6e3` — rebuilt `item_family_logistics_0702` as the sole visible turret/laboratory logistics owner. Its broker service performs bounded discovery only; physical execution requires literal-true movement, exact home-source removal, persistent `item_family_custody_0702`, checked visible-target insertion, and exact return.
- `66348c59af031a58b4aa33e3359a133d8f95aae2` — added pure item-family recommendation to `action_state_arbiter_0488` without requiring or mutating the module.
- `30b8dfc34d02bcc1b13143dc7a6d139b69674ab9` — made `single_dispatcher_0510` the sole item-family executor caller and canonical-action owner.
- `0a66df06e9f163bef1b60ea1fd044dfcac786bf9` — retired `item_family_integrity_0703`.
- `d642d9548e367e11e8863ed56addb6b7f2fd7875`, `10ebc118a791a34f62629aead681527dd2954d03`, `8228e3a6129dd14ceb4b70f4eb5fc6fb1e16635f`, and `7f2af9454a4cc4da017622455141a4822a75cea5` — enforced the 41/14 graph, focused item-family ownership, and workflow integration.
- `3ffefb0a9fa246f3477ab3f31e2d1be4c156dea9` and `f42f593b8d598fdd8cad87ed035d82617cc2bfe8` — synchronized the Mermaid authority map and runtime continuity rules.

Hidden proxy ammunition remains exclusively owned by `proxy_ammo_hardener_0649`. `0702` owns only visible unautomated ammunition turrets and laboratories.

### Consolidated energy-family authority

The audit found a useful read-only readiness doctrine and physical energy executor buried beneath four install-order-dependent wrappers. `fusion_reactor_readiness_guard_0727` patched fusion heat semantics; `energy_readiness_diagnostics_0711` patched counters; `energy_item_automation_guard_0722` wrapped readiness and execution while independently aborting tasks and releasing reservations; and `energy_automation_guard_install_assertion_0726` existed only to prove those patches happened in order.

- `45ebb48e12b89bb80a3445d4a02bbf4ef4ab064c` — consolidated fusion semantics, connected inserter/loader ownership, and corrected diagnostics into read-only `energy_family_readiness_0705`. Its broker service reports structured inspection truth with `acted=0`.
- `9ec8a04c81215ed4da887dfe005d5fd6db3bd1a2` — rebuilt `energy_family_logistics_0707` as the sole physical fuel and burnt-result executor with dedicated reservations, literal-true movement, exact removal, persistent `energy_family_custody_0707`, checked insertion, and exact return. Its broker service is discovery-only.
- `43d9535ace095d77204bbb5965fd4e5c9b8a00e0` and `c4f3e49b2a79e1ed35db582f2707a7441f406f7b` — added pure energy recommendation and made `single_dispatcher_0510` the sole energy executor caller.
- `f8858b345bf1bf51d393e3f827186bb6397c0288`, `0d0b7216692712591f6d96f609f6000646b2559f`, `fff440816c2fd8f0ffd5f7d02e93e4d6d1a62309`, `65f72756f72e90ab0805ba0f5ade80d519c54caf`, and `f6666ac43a86e85916e56423c64f532ab3fd6c6a` — added and aligned focused, integration, workflow, and broad architecture gates for the 37/18 graph.
- `5abd859c07b18b1b5c4372cac39a53379766f19f` and `ee2c5bbd950a48126f53b7a3e58b6e44a9700996` — synchronized runtime continuity and the current Mermaid authority map.

Energy readiness is policy and observation only. Energy logistics discovery may cache candidates only. The dispatcher owns execution, and the four retired energy wrappers may not be reactivated.

### Consolidated rocket-silo authority

The audit found that `rocket_silo_logistics_0710` was a free-running executor that used the shared machine reservation category, wrote `pair.target`, accepted any movement result except literal `false`, patched retired leaf truth, and returned boolean broker execution. `rocket_silo_live_ownership_guard_0728` then wrapped readiness, logistics, diagnostics, reservations, requests, and task phases to enforce launch and external-logistics ownership.

- `853933ae235fbfacbbcce2b34d12c598fd762f57` — rebuilt `rocket_silo_readiness_0709` as the canonical read-only recipe, trash, payload, fluid, launch, inserter/loader, logistic-network, and transitional-request doctrine. Its broker service reports structured inspection truth with `acted=0`.
- `feef94265790e379f8575b63c8f9c3b125c99cb7` — rebuilt `rocket_silo_logistics_0710` as the sole physical manual input/trash executor with dedicated `rocket-silo-logistics` reservations, literal-true movement, exact removal, persistent `rocket_silo_custody_0710`, checked insertion, exact source return, and integrated launch/external-ownership interruption. Its broker service is discovery-only.
- `47a211dfc2e5023748cf552375f0966b8cbc480f` and `de99092f54286d31c50da20c47db032342ed16d8` — added pure silo recommendation and made `single_dispatcher_0510` the sole silo executor caller.
- `55b301e8dea4ba65efd7c3bc26a1e39fcfdbd446` — retired `rocket_silo_live_ownership_guard_0728`; `23f709fd3657d1d659d1774525734c0f7de207cc` corrected the planning-radius argument after that full-table rewrite.
- `fe2590106da7c37b3a8f69efa2991f5fca777c88`, `dfcc902c877d8b495afbe263fb40920b754c0b51`, `44d61ee4a30a7b5743a8eb8aa6489574ecf31150`, and `298227216f1a7ed565b874491884f2f4f3139002` — added and aligned focused, integration, workflow, and broad architecture gates for the 36/19 graph.
- `7a378ec7f02f39ea41d16ff74dfd059c28e9285a` and `6f3fad62d9147699b927261f40f06f4a342df6ab` — synchronized runtime continuity and the current Mermaid authority map.

Rocket-silo readiness is policy and observation only. Silo logistics discovery may cache candidates only. The dispatcher owns execution, and retired `0728` may not be reactivated.

### Consolidated artillery authority

The audit found that `artillery_logistics_0713` was a free-running physical broker executor that used the shared machine reservation category, wrote `pair.target`, accepted any movement result except literal `false`, patched retired leaf truth, and returned boolean broker execution. `artillery_train_validity_guard_0724` then wrapped readiness, logistics, diagnostics, reservations, requests, and task phases to prevent service of detached, moving, or automatic-mode wagons.

- `2e478b3a41b37bf60f97786802ef1c1bb394c307` — rebuilt `artillery_readiness_0712` as the canonical read-only fixed-turret and wagon doctrine with compatible-ammunition checks, connected automation ownership, and integrated detached, moving, and automatic-mode train validity. Its broker service reports structured inspection truth with `acted=0`.
- `663b6fe54e2f170e82c19fdaf79d7402358abe81` — rebuilt `artillery_logistics_0713` as the sole physical ammunition executor with dedicated `artillery-logistics` reservations, literal-true movement, exact source removal, persistent `artillery_custody_0713`, checked insertion, exact source return, and integrated unsafe-train interruption. Its broker service is discovery-only.
- `36c4a510ef774451fc43ef853135f0d7df04588e` and `dd67ffcd88975630963b3a294b85b29283d409a3` — added pure artillery recommendation and made `single_dispatcher_0510` the sole artillery executor caller.
- `8af42ffb50f7d615fcb8af7fedb148602d49ae73` — retired `artillery_train_validity_guard_0724`.
- `dced102de52576b66bb637f886c0adf923252a20`, `b465254f050324e270a45b3777bdb31e051ee282`, `692e71d10021fd729d52a86aec01e88972035fab`, and `530a08ff9e69fd1a1497cd61adb2a688e22b313c` — added and aligned focused, integration, workflow, and broad architecture gates for the 35/20 graph.

Artillery readiness is policy and observation only. Artillery discovery may cache candidates only. The dispatcher owns execution, and retired `0724` may not be reactivated.

### Consolidated construction and roboport authority

- `b374fb98221e5577cbb04dea9e8637cdeec71870` — made construction a pure classified action, including candidate and active-custody targeting.
- `de1a5bf62965aa7407d53a05892e5f6fb72a3a0a` — made `single_dispatcher_0510` own physical construction.
- `1c01a3a809e48e751b6d4d52b915c66a8640fdc0` — rebuilt `construction_planner.lua` as the sole physical owner with positional reservations, literal-true movement, exact placeable-item removal, `construction_custody_0338`, direction preservation, exact-site effectiveness revalidation, source/station return, combat interruption, and broker-only discovery.
- `b41bfe97c4ba7a447b695922e352e9a463a5bed4` — removed the obsolete one-shot construction repair workflow.
- `cb7a83b9a09dd9c6376b3020ade39bde31e4b271`, `dcbd9d01`, `b90b58599bd6fb10034aeec3a5a99606d2200850`, `b912ec4e47fc4f0547eeba78f0d94c288ca2b074`, and `6c7abbf88811f833edf8e4f84eec2544aa970bab` — added and aligned construction, broad architecture, integration, and workflow gates.

`construction_site_planner.lua` owns read-only placement effectiveness. `construction_planner.lua` alone moves, removes stock, retains custody, and places structures. Roboport placement belongs to construction; roboport `0714/0715` inspect and supply existing ports only.

### Consolidated fluid-turret authority

The audit found three patch-order wrappers around the useful fluid-turret authorities. `fluid_turret_internal_buffer_guard_0731` patched buffer arithmetic, `fluid_turret_proposal_integrity_0718` wrapped proposals for endpoint validation, and `fluid_turret_planner_integrity_0730` wrapped route and construction behavior. The old `0719` also wrapped `construction_planner.service_pair` and `install`, making correctness depend on load order.

- `06d195778360d08a8ccfa970986ff4cfe3f2bdea` — consolidated corrected internal-buffer semantics into read-only `fluid_turret_readiness_0716`, using entity aggregate fluid minus local fluidbox contents and structured `acted=0` scan truth.
- `eb47acc59bbe8dde4e7f52463e68881ec0952c30` — consolidated exact force, surface, entity, fluidbox, segment, fluid identity, free-interface, and freshness validation into read-only `fluid_turret_connection_proposals_0717`.
- `bdea7a370f38b3521d7a4917ca276b1931e77e74` — rebuilt `fluid_turret_connection_planner_0719` as a wrapper-free route coordinator.
- `6119e9100aa4c58b30d0a16468ed8a0757543628` — retired `0731`, `0718`, and `0730`, reducing the declarative graph to **32 active hardeners and 23 explicitly retired source-only authorities**.
- `bdea7a370f38b3521d7a4917ca276b1931e77e74` and the follow-up construction-request integration — made `0719` publish one identified fixed-position `construction_request` at a time and observe `construction_last_task_0338`, while construction remains the sole movement, custody, and pipe-placement owner.
- `e33e6c150352a27d606e353caf5b712fec87c548`, `c758f8d284a4c173b674c261053258eb47f92a53`, `9422734ae01f5ef9b6ec7ab41d69c05cd2f7a0b5`, and `c6be108116fc17040a5859362ab6f2b60c1e3eab` — added and aligned focused, workflow, integration, and broad architecture gates.
- `9112cb40f0f48ebd7ffe3483b3415afad68b1acb`, `c86cc567f02adce7f462dda2115f059bc8395b62`, and `60acc903552bb9b54e207599ee9d15fd7ae52075` — synchronized the current map, continuity rules, and active testing matrix.

`0716` owns corrected readiness. `0717` owns exact safe proposals. `0719` owns route search, route reservations, identified construction requests, bounded retries, and final connection verification. None may wrap construction or perform physical item or entity mutations.


### Consolidated standard-fluid authority

The standard-fluid audit found six overlapping compatibility authorities around machine fluid context, source/sink discovery, route execution, positional reservations, shared-port collision checks, and active-machine context refresh. Five modules wrapped `construction_planner.service_pair` or related APIs, while the reservation scope module wrapped the shared reservation authority. Correctness depended on installer order and several modules could clear tasks, requests, reservations, or proposal state outside the canonical owners.

- `5956b037216dcb7b1de6d678083022aa29601501` — moved surface-scoped positional keys directly into `work_reservations.lua`.
- `da4b5c470d3da52691bcf9637e52ebc093d34bfc` — rebuilt `fluid_network_doctrine_0689` as the sole read-only standard-fluid machine-context, endpoint-safety, source/sink discovery, and exact input/output proposal authority.
- `9648610edbe603629e3c9fc2a68c4e3a4b93b304` — rebuilt `fluid_connection_planner_0691` as the sole wrapper-free input/output route coordinator using identified `construction_request` records and `construction_last_task_0338`.
- `b47aecb4a80270f76fba79c5651acdbcc3372fa6`, `24a1c718eb45f85c7b5cad7d269605e6bea56b5a`, `804dc78cffd2ed58b39164cf48efa231b5667ebe`, `244d55603848c84c772e085fd4e972ae0c7c978d`, `1a66e4a3fb0e95e592494a8c4dee59791e4d1c11`, and `d424fd24eb0ac4712d4cab7fee0af3f1349e0b3c` — converted `0694`, `0697`, `0692`, `0696`, `0699`, and `0700` into inert source-preserved retirement stubs.
- `0d166365954be3ac38e503ce09d008c37fe138c9` — removed those six modules from the active loader and established **26 active hardeners and 29 explicitly retired source-only authorities**.
- `d903674ac5eaab75c8c4531e0385129126683d42`, `404bf506a3ef1860ebadf55993e5f17ef71de300`, `1dbc16a1c08fa2f3facc89faff2a5f22b269f8a3`, and `ffaf4c85338bd95bb470b833b73341c21b4f4aef` — added the focused standard-fluid boundary audit, wired it into source validation, and aligned both global graph gates.
- `6d6b963a5b3f01a9132f139ff3aa7e32ff00108c`, `3e4b4452e2a77a3a5df883aa1ab3e94ed7eaab4d`, and `a00a75c8d163d5189046cdc94dfbcf740cb10b06` — synchronized the current authority map, runtime continuity rules, and active testing matrix.

`0689` now owns read-only standard-fluid truth and proposals. `0691` owns route search, surface-scoped route reservations, request identity, cooldowns, retries, and final connection verification. `construction_planner` alone moves priests, removes pipe items, retains custody, and places entities. The retired standard-fluid modules have no installer, cadence, wrapper hook, or mutation path.

This is source implementation and source-contract work. No complete GitHub Actions result, Factorio load, migration, save/reload, behavioral scenario, profiler run, package test, or release proof is claimed by this slice.

These changes are source implementation and source-contract work. No repository-wide Lua 5.2 parse, GitHub Actions success, Factorio load, migration, save/reload, behavioral test, profiler run, package test, or release proof is claimed unless separately recorded below.

### Retired-source and publisher closure

- `91478cb3cf8c05f9c0ef999bb88e9fd676aee142` — converted all older retired authorities into inert source-preserved stubs with no installer, cadence, wrapper hook, movement call, command path, state mutation, or physical execution surface. Together with the six previously retired standard-fluid wrappers, all 29 retired authorities now satisfy one source-level retirement contract.
- `7a991688130f365f887903a9fc64b525a7c39f1f`, `5470230f6806dc086aa636bb62b984cee7ed8f0b`, and `77a16e752fd488cda2b3782bee07521ebff87919` — archived the remaining baseline, RC1, and RC2 publisher workflows as manual, read-only, fail-closed guards. RC3 was already archived. Historical publisher workflows can no longer publish or write repository contents.

### Gate 1 source validation accepted — 2026-07-20

- **Exact source SHA:** `fdf6039be809a80865e8ea96c551dc0d0797d181`
- **Workflow run:** `https://github.com/mrcalzon02/Tech-Priests/actions/runs/29779229966`
- **Result:** complete `Source validation` success.
- **Observed gates:** Lua 5.2 parsing, JSON validation, Python compilation, governance, recovery architecture, static UPS baseline, inventory safety, storage, machine, priest cargo, item, energy, silo, artillery, roboport, construction, fluid-turret, standard-fluid, global integration, migration lifecycle, evidence self-tests, evidence wiring, archived publisher and packaging controls, release-authorization self-test, blocked-release proof, and migration-test builder verification all passed for the same SHA.

This is accepted static source evidence only. It does not claim Factorio loading, migration success, save/reload behavior, scenario completion, profiler evidence, package load, or release authorization.

### Consolidated movement cadence authority

The movement audit found that `movement_cadence_contract_0518` contradicted its observer-only description: it replaced the global movement request API, wrote a second lease record, refreshed and cleared requests from its own cadence, installed a diagnostic command, wrapped diagnostics, and retained a direct timer fallback.

The useful cadence rules were consolidated into `movement_controller.lua`: 45-tick command refresh, 90-tick ordinary retarget suppression, one-tile target collapse, owner/priority/TTL request identity, eight-second long-action leases, and a sixty-point priority threshold for cross-owner lease preemption. The controller now requires the canonical broker for both movement service and displacement sampling. `0518` is source-preserved but inert and is no longer loaded by `control.lua`.

This changes the declarative recovery record to **26 active hardeners and 30 explicitly retired source-only authorities**. It is source implementation only and requires a new complete Source validation result before the changed head can be used for Gate 2 evidence.

### Removed `0472` movement and timer ownership

`combat_magos_movement_authority_0472` no longer replaces `tech_priests_request_movement_0418`, no longer intercepts `issue_priest_command`, and no longer registers through the runtime event registry or direct `script.on_nth_tick`. Its bounded hidden-proxy sustain now runs as the named broker service `combat_proxy_sustain_0472` with structured processed/acted accounting.

This is a deliberate intermediate consolidation. `0472` still contains historical radar and legacy combat-entry wrappers; those remain explicitly open for direct integration into command hierarchy, proxy alignment, and canonical combat ownership before the module can be retired.

This is source implementation only. A new complete Source validation result is required for the changed exact SHA, and no Factorio runtime, migration, behavioral, profiler, package, or release evidence is claimed.

### Retired `0472` and consolidated combat proxy ownership

The remaining `combat_magos_movement_authority_0472` wrappers were removed rather than preserved as another compatibility layer. Direct-subordinate territory is now native to `command_hierarchy_0480` and is read directly by the legacy radar membership function. Proxy-prime cooldown belongs to the existing `movement_controller` wrapper, force-combat cooldown and staggering belong to the existing `behavior_mutex_0466` wrapper, and hidden-proxy identity, alignment, attachment recovery, and target sustain belong to `proxy_turret_alignment` through broker services.

`command_hierarchy_0480` and `proxy_turret_alignment` no longer retain registry or direct `script.on_nth_tick` fallbacks. `combat_magos_movement_authority_0472.lua` is source-preserved but inert and is no longer loaded by `control.lua`. The declarative graph is now **26 active hardeners and 31 explicitly retired source-only authorities**.

This is source implementation only. A complete Source validation result is required for the exact changed SHA; Factorio load, migration, save/reload, behavioral, profiler, package, and release evidence remain open.

### Consolidated combat command safety into movement routing

`combat_safety.lua` remains the canonical friendly/allied/cease-fire/neutral target predicate authority, but it no longer replaces `issue_priest_command` or either proxy-prime function. Those checks now execute inside the existing `movement_controller` command and proxy-prime wrappers before any engine command or combat movement intent is accepted.

This removes three overlapping global wrappers without weakening friendly-fire protection. Combat safety remains responsible for target classification, state cleanup, direct-mining safety, enemy-query filtering, and laser validation. Movement remains the sole ground command and combat-position routing authority.

Source validation must pass for the exact changed SHA. Factorio runtime and behavioral evidence remain open.

### Retired `0511` and made direct-acquisition bounds native

`movement_bounds_contract_0511` combined target filtering, movement-request wrapping, an older executor wrapper, three legacy direct-function wrappers, registry surgery, direct engine commands, diagnostics, commands, and a periodic service. Its useful policy is now located in the canonical owners instead of another late layer.

`direct_acquisition_executor_0513` now owns tier-capped target bounds, authority-corridor allowance, and active direct-task overleash return alongside its existing movement, extraction, custody, station return, atomic deposit, replan, and terminal transitions. `runtime_command_cleanup_0720` removes the exact obsolete 61-tick direct-gather route and historical bounds command. `0511` is source-preserved but inert and is no longer loaded.

The declarative graph is now **26 active hardeners and 32 explicitly retired source-only authorities**. Complete Source validation and Factorio runtime evidence remain separately required.

### Retired `0566` and converted Void movement into a delegated backend

`movement_enforcement_0566` was another late wrapper around the canonical request API, direct engine commands, mutable movement/task state, a diagnostic command, a periodic route, and a hidden installer for the Void movement authority. Its useful ground-envelope policy is now native to `movement_controller`, including destination rejection, stale-request cleanup, far combat-target cleanup, and overleash return through the canonical request path.

`void_movement_authority_0630` remains because Void/platform priests require a distinct stepped-relocation implementation, but it is now a broker-only backend delegated by `movement_controller`. It no longer patches `0511`, `0566`, the public request/stop/status APIs, or `move_priest_to`; it no longer owns a command, registry fallback, or child installer. `control.lua` installs `0630` and `0631` explicitly. The declarative graph is now **26 active hardeners and 33 explicitly retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

### Converted `0574` from movement wrapper to route planner

`authority_corridor_pathing_0574` previously replaced the canonical request API, cleared movement compatibility fields, directly stopped priests, initiated return movement, scanned every pair on a periodic route, and installed its own command. Its actual distinct value is authorization and waypoint selection, not execution.

The module is now an observer-only route planner. `movement_controller` calls it before request acceptance, preserves proposed final-destination metadata on the canonical request, and remains solely responsible for rejection, return routing, request state, and engine commands. The obsolete corridor command is removed by runtime cleanup. The authority count remains **26 active / 33 retired** because `0574` remains a useful non-mutating planner rather than being retired.

Complete Source validation and Factorio runtime evidence remain separately required.

### Retired movement-economy wrappers `0572` and `0577`

`efficiency_economy_0572` replaced visible ground walking with same-surface teleportation whenever no connected player was deemed close enough to observe the priest, destination, or station. That optimization is incompatible with the project’s physical-honesty rules and has been retired without replacement.

`efficiency_economy_0577` wrapped eleven executor `service_pair` methods, the global movement request API, a deferred movement queue, a command, and a periodic route. Canonical executor services already receive broker budgets. Its one distinct useful policy—deferring low-priority path corrections when the shared path budget is exhausted—is now applied inside `movement_controller` immediately before an engine command. Both source files are inert and no longer loaded. The graph is now **26 active hardeners and 35 explicitly retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

### Retired `0632`/`0633` and flattened hidden repair loaders

`direct_acquisition_pulse_0631` previously installed `direct_acquisition_recall_guard_0632`, which wrapped the canonical direct executor using obsolete `0566` compatibility state. `efficiency_economy_0575` installed `ground_route_authority_0633`, which wrapped the movement request API and silently installed seven unrelated repair modules.

Visible route chunking and old pair-state cleanup are now native to `movement_controller`. `0631` is broker-only and no longer installs a command, timer fallback, or recall wrapper. `0632` and `0633` are inert. The `0634`, `0635`, `0638`, `0639`, `0640`, `0643`, `0642`, and `0637` repairs are loaded explicitly from `control.lua` in their previous order. The same slice corrected `movement_controller` so its local `lower` helper is declared before `budget_exempt`, preventing an otherwise invisible runtime global lookup.

The declarative graph is now **26 active hardeners and 37 explicitly retired source-only authorities**. Complete Source validation and Factorio runtime evidence remain separately required.

### Retired `0502` station-side acquisition and movement quarantine

`priest_vanish_guard_0502` was a historical emergency layer that duplicated direct acquisition, movement requests, engine commands, mutable task and mode fields, watchdog recovery, diagnostics, and anti-slam state. Direct acquisition and movement are now owned by `0513` and `movement_controller`; missing-priest detection and controlled rescue remain available through the still-active lifecycle authorities.

`0502` is now inert and no longer loaded. `behavior_stack_cleanup_0509` was rewritten as broker-only passive maintenance for pair reverse maps and UI/cascade debounce, removing all `0502`, direct-acquisition, movement-request, engine-command, registry, and direct-timer ownership. The graph is now **26 active hardeners and 38 explicitly retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

### Retired `0495` pair-link rescue wrapper

`pair_link_hardening_0495` duplicated reverse-map repair, orphan discovery, missing-priest observation, ensure/respawn wrappers, direct rescue attempts, a diagnostic command, and a separate timer. Its broad 96-tile orphan search and direct replacement calls were not retained.

`priest_lifecycle_authority_0499` now natively owns reverse-map truth, conservative nearby orphan rebinding, and rate-limited missing-priest observation through the runtime broker. Replacement remains disabled until the authoritative creation path is repaired. The graph is now **26 active hardeners and 39 explicitly retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

### Retired `0500` lifecycle seal into canonical source

`priest_lifecycle_seal_0500` wrapped creation, removal, respawn, ensure, recall, platform replacement, recovery modules, events, diagnostics, commands, and a 17-tick watchdog. Its one legitimate rule—paired priests may be destroyed only during real Cogitator Station cleanup—now lives in `priest_lifecycle_authority_0499` and the original lifecycle functions.

Canonical `create_pair` now establishes both reverse maps and immediately preserves the priest. Respawn, mobility upgrade, and platform recreation check replacement authorization before creating a duplicate. Station removal is the sole paired-priest destruction route; orphan purge and the former `0503` mobility-swap cleanup fail closed. The graph is now **26 active hardeners and 40 explicitly retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

### Retired `0501` vanish and recovery wrapper

`priest_vanish_guard_0501` wrapped four direct-mining functions, the canonical movement request API, respawn and ensure, pair-link and mining-safety recovery, diagnostics, events, commands, and a 31-tick rescue loop. Those responsibilities now have canonical owners.

`direct_acquisition_executor_0513` natively rejects priests, stations, owned simple entities, unsupported target types, and physical-output mismatches before movement or extraction. `direct_mining_safety_0490` remains only as legacy literal-mining and no-spill protection; its missing-priest rescue, lifecycle event route, command, and 113-tick timer are removed. `0499` remains the sole disappearance observer. The graph is now **26 active hardeners and 41 explicitly retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

### Retired overlapping `0506` and `0508` recovery movement wrappers

`mobility_recovery_contract_0506` and `movement_recovery_authority_0508` both repaired reverse maps, cleared recovery flags, moved direct-acquisition priests, wrapped legacy executors, wrapped ensure and respawn, modified diagnostics, installed commands, and registered periodic services with registry/direct-timer fallbacks. `0508` additionally disabled `0506`, demonstrating that the pair was an accumulated compatibility stack rather than two independent authorities.

Both modules are now inert and unloaded. `action_stack_contract_0507` names `movement_controller` as the sole movement owner and `0499` plus `0503` as the temporary lifecycle/recovery pair. Economy modules no longer require or wrap the retired services. The graph is now **26 active hardeners and 43 explicitly retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

### Narrowed `0503` to one-shot missing-priest recovery

`priest_recovery_safety_0503` previously combined reverse-map repair, valid-priest recall teleports, nearby rebinding, direct entity creation, mobility replacement, global ensure/respawn/recall wrappers, watchdog restoration, diagnostics, a command, and a 41-tick route. It is now a broker-owned executor for one case only: a Cogitator Station remains valid, its priest has been observed missing by `0499`, conservative orphan rebinding failed, and the observation delay and retry cooldown have elapsed.

`0499` issues an exact-owner, exact-kind, short-lived, one-shot replacement lease. The authoritative generated `respawn_pair_priest` consumes that lease before creation, refuses to replace a valid priest, restores `pairs_by_station`, `pairs_by_priest`, and `station_by_priest`, preserves the new priest, and reports recovery back to `0499`. It no longer commands the priest to return to a station after spawning beside it. The declarative graph remains **26 active hardeners and 43 retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

### Retired `0498` task/pair audit into canonical order and lifecycle owners

`task_pair_audit_0498` wrapped direct-target discovery, dirt fallback, worker activation, emergency craft, respawn, ensure, diagnostics, lifecycle removal events, a command, and a 29-tick audit loop. It also maintained a parallel reverse map, logged movement jumps, cleared broad task state, and placed the current order into an ad hoc missing-priest status.

`order_queue_0469` now owns an indefinite `missing-priest` pause and explicit post-recovery resume. `priest_lifecycle_authority_0499` invokes those transitions when the priest becomes missing, is conservatively rebound, or is restored through the one-shot `0503` lease. `0498` is inert and unloaded; its cadence and command are removed. The graph is now **26 active hardeners and 44 explicitly retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

### Retired `0505` behavior-execution wrapper into canonical production

`behavior_execution_doctrine_0505` combined direct-acquisition interception, direct engine commands, mutable mode/target state, smoke and scan-line wrappers, emergency-craft wrapping, ensure/recovery wrapping, diagnostics, a command, and a periodic service with registry/direct-timer fallbacks. Those surfaces duplicated current canonical owners.

The surviving doctrine was already implemented more completely in `emergency_production_executor_0514`: facility-first production, controller-routed station return, visible timed fallback, strict recipe-backed ingredient transactions, persistent rollback/output custody, atomic deposit, and canonical order completion. `0514` now explicitly records that integration and clears stale serialized `0505` task flags. `0505` is inert and unloaded; direct-target truth remains in `0513`, movement in `movement_controller`, and recovery in `0499`/`0503`. The graph is now **26 active hardeners and 45 explicitly retired source-only authorities**.

This is source implementation only. Complete Source validation must pass for the exact changed SHA; Factorio load, migration, save/reload, behavioral, profiler, package, and release evidence remain open.

## Current Gate State

### Gate 1 — Full source validation

Passed for exact SHA `fdf6039be809a80865e8ea96c551dc0d0797d181` in workflow run `29779229966`. All source-validation steps completed successfully. This closes static Gate 1 only; runtime and packaging gates remain open.

### Gate 2 — New save, migration, and reload

Open. Clean Factorio 2.x and real `0.1.672` upgrade scenarios, configuration-change verification, separate logs, and both reloads are required.

### Gate 3 — Stage 1 behavior

Open. Production, queue, consecration, direct acquisition, repair, combat repair, construction, specialized logistics, custody, terminal transitions, and save/load require complete evidence.

### Gate 4 — Runtime spine and canonical action

Open. Event ownership, handler isolation, broker truth, cadence, hardener completion, action agreement, fairness, and diagnostic cost require live evidence.

### Gate 5 — Specialized families and movement

Open. Construction placement effectiveness, standard fluid input/output planning, fluid-turret route recovery, combat, overlap, ordinary movement, and Void movement remain unevidenced. Machine, item, energy, silo, artillery, roboport, construction, and fluid-turret source ownership is consolidated but still lacks accepted live evidence.

### Gate 6 — Performance

Open. Idle, active, and high-count profiles remain unevidenced.

### Gate 7 — Verified package and release

Blocked. No verified release authorization exists, source metadata remains `0.1.672`, and no new package has been built during recovery.

## Next Sequential Work

1. Execute clean new-save and real `0.1.672` upgrade loads with configuration-change and save/reload evidence for one exact source SHA.
2. Repair any exact Factorio load, migration, serialization, authority-duplication, or custody failure and rerun affected scenarios.
3. Run the complete behavioral, specialized-family, construction, standard-fluid, fluid-turret, movement, fairness, and profiler matrices.
4. Continue source consolidation into remaining movement, lifecycle, direct-command, and compatibility-state writers identified by the UPS and authority maps when runtime evidence does not take priority.
5. Validate the evidence directory and create verified release authorization only after acceptance.
6. Advance version, package, package-load test, and publish only under the proven artifact class.


### Retired `0426` death/re-imprint wrapper into canonical lifecycle recovery

`pair_death_and_respawn_0426` duplicated priest-death events, global removal wrappers, global ensure/respawn gates, re-imprint completion, a diagnostic command, and a second 47-tick route. Its completion path had become invalid after canonical respawn was restricted to one-shot `0499` leases, while `0503` could otherwise mistake an intentionally dead priest for an ordinary disappearance.

`priest_lifecycle_authority_0499` now owns the first-priority priest-death event and enters the existing generated `0298` re-imprint state before legacy linked-removal cleanup. Generated `0298` duration, text, rendering, research adjustment, and overview status remain, but its ensure/respawn wrappers and independent completion timer are removed. Broker-owned `0503` waits for `finish_tick`, then consumes the same exact one-shot lease and canonical respawn used for a proven missing priest. Recovery clears the render/state, restores identity and health, repairs all reverse maps, and resumes the canonical order. The graph is now **26 active hardeners and 46 explicitly retired source-only authorities**.

This is source implementation only. Complete Source validation must pass for the exact changed SHA; Factorio load, intentional priest-death timing, migration, save/reload, behavior, profiler, package, and release evidence remain open.


### Retired `0363` station-pair recovery wrapper

`station_pair_recovery_0363` is now source-preserved and inert. Its global create/respawn wrappers, immediate ensure call, broad mode/target normalization, automatic cargo evacuation, command/report path, and independent 601-tick audit are removed. `station_pair_state_0362` remains the canonical ledger owner; the authoritative generated `create_pair` path and `priest_lifecycle_authority_0499.note_recovered_priest` now refresh that ledger directly. Reverse-map truth and missing-priest recovery remain with `0499`/`0503`, migration auditing with `migration_pair_integrity_0734`, and inventory custody with the canonical steward/logistics owners. The declarative graph is now **26 active hardeners and 47 explicitly retired source-only authorities**. This is source implementation only until exact-head Source validation and Factorio runtime evidence pass.

### Removed generated `0302` and `0305` lifecycle wrappers

Generated fixed-armor `0302` and sub-equipment `0305` each wrapped `ensure_pair_priest` solely to refresh derived equipment state, adding two more order-sensitive layers to the replacement chain. Both also exposed legacy diagnostic commands. Canonical `create_pair` and `priest_lifecycle_authority_0499.note_recovered_priest` now refresh `0302` armor and `0305` equipment directly alongside pair-ledger refresh. The ensure wrappers and `tp-armor-0302` / `tp-grid-0305` registrations are removed; command cleanup removes stale saved registrations. Damage mitigation and the existing equipment cadences remain unchanged and are the next separate periodic-ownership audit. The declarative graph remains **26 active hardeners and 47 explicitly retired source-only authorities**.

This is source implementation only. Complete Source validation and Factorio runtime evidence remain separately required.


### Consolidated `0306` visible-grid reader into canonical `0305`

`0306` previously replaced `tech_priests_0305_refresh_pair_equipment` after the generated fragment boundary, making equipment truth depend on load order. Canonical `0305` now consumes the visible scripted bay first and station inventory only as an explicitly named compatibility source under one capacity and allow/deny policy. `0306` retains GUI and bay presentation only; its refresh replacement is retired, while `runtime_command_cleanup_0720` removes `tp-grid-0306`. The declarative graph remains **26 active hardeners and 47 explicitly retired source-only authorities**.

This is source implementation only. Complete Source validation and Factorio runtime evidence remain separately required.


### Consolidated final `0313` research-equipment doctrine into `0305/0306`

The earlier `0305` scripted equipment effects and `0306` visible bay were later disabled by `0313`, but the disablement was implemented as another stack of global function replacements, a second 83-tick route, a second damage handler, and replacement GUI handlers. Canonical `0305` now owns the final research-bonus, station-inventory-only summary, disabled active defense, sole armor-safe damage route, and sole 83-tick research refresh. Canonical `0306` now keeps the experimental side panel disabled and preserves ordinary station inventory GUI routing directly. `0313` retains research-policy helpers only; its equipment, active-defense, cadence, damage, and GUI replacement surfaces are retired. The declarative graph remains **26 active hardeners and 47 explicitly retired source-only authorities**.

This is source implementation only. Complete Source validation and Factorio runtime evidence remain separately required.


### Retired generated glow and research diagnostic commands

The generated `tp-glow-0307`, `tp-glow-0308`, and `tp-upgrades-0313` commands exposed manual refresh and inspection paths after the runtime had adopted automatic glow and research-bonus ownership. Their registrations are removed from source, explicit retirement markers preserve the historical boundary, and `runtime_command_cleanup_0720` removes stale saved registrations. The existing 19-tick glow refresh and 37-tick research-bonus service remain unchanged for a later cadence audit. The declarative graph remains **26 active hardeners and 47 explicitly retired source-only authorities**.

This is source implementation only. Complete Source validation and Factorio runtime evidence remain separately required.


### Consolidated generated glow ownership into canonical `0307`

The generated glow path had accumulated the original `0307` light renderer, a `0310` daylight sprite-aura wrapper, a predecessor capture in `0313`, and a final `0315` function replacement. Canonical `0307` now owns the final low-intensity, night-clamped ambient and mode lights directly, including cleanup of historical daylight render handles. The `0310` daylight wrapper, `0313` predecessor capture, and `0315` glow replacement are retired. The existing single 19-tick runtime-registry cadence remains unchanged. The declarative graph remains **26 active hardeners and 47 explicitly retired source-only authorities**.

This is source implementation only. Complete Source validation and Factorio runtime evidence remain separately required.


### Retired generated `0310`–`0312` commands and duplicate damage route

The generated `tp-gui-0310`, `tp-0311`, and `tp-laser-0312` commands exposed manual GUI, marker, and combat-laser paths after automatic runtime ownership was established. Their registrations are removed and stale saved names are handled by `runtime_command_cleanup_0720`. The same slice retires the `0310` damage wrapper and its second `on_entity_damaged` registration because station-damage bookkeeping is already native to canonical `0305`; retaining the wrapper could execute fixed-armor mitigation twice. Automatic GUI routing, fallback-laser behavior, canonical station bookkeeping, and canonical armor mitigation remain. The declarative graph remains **26 active hardeners and 47 explicitly retired source-only authorities**.

This is source implementation only. Complete Source validation and Factorio runtime evidence remain separately required.


### Consolidated generated GUI ownership into canonical `0306`

`0310` still replaced `tech_priests_0306_open_gui` to reopen the abandoned scripted equipment side panel and registered a second opened/closed/click handler family. Canonical `0306` already preserves the normal Cogitator inventory, clears obsolete scripted frames, applies ranked names, and forwards command-overview clicks through one GUI-router registration family. The later `0310` side-panel replacement and duplicate router handlers are retired; the `0310` overview-click helper remains available to canonical `0306`. The declarative graph remains **26 active hardeners and 47 explicitly retired source-only authorities**.

This is source implementation only. Complete Source validation and Factorio runtime evidence remain separately required.


## 2026-07-21 — Milestone 0784: Canonical Generated Mining Beam and Extraction Ownership

Consolidated the final 0.1.315 mining-beam and direct-extraction implementation into canonical 0.1.312 ownership. The original 0.1.127 scan-line function now owns the later 0.1.177 task-audio behavior and final direct-mining/item suppression policy. Canonical 0.1.312 now owns beam safety invocation, raised-origin rendering, research-scaled pulse behavior, loose-item pickup, combat interruption, movement clamping, extraction timing, deposit, and save-compatible 0315 state cleanup. The 0.1.177 audio wrapper, 0.1.315 scan/beam/service/handler replacements, and 0.1.322 beam/service safety wrappers are retired. Friendly-fire protection remains supplied through named combat-safety predicates, including explicit allowance for loose-item pickup without allowing item entities to become laser targets. Mining and combat-safety debug commands are retired through runtime command cleanup. Static Source validation does not constitute Factorio runtime proof.


## 2026-07-21 — Milestone 0785: Canonical Combat Safety Predicate Ownership

Consolidated the remaining combat-safety target and combat wrappers into their authoritative source functions. Fragment 014 now owns one cache-aware plus live enemy query; fragment 003 owns one station-radius predicate and one combat service with direct before/after invalid-state cleanup hooks; fragment 013 owns one station-enemy predicate. combat_safety.lua now exports named hostile-target and invalid-state predicates instead of redefining find_enemy_target, enemy_inside_station_radius, tech_priests_0248_is_enemy_of_station, or handle_combat. The 0248 predecessor capture and all 0322 target/combat wrappers are explicitly retired. Static Source validation does not constitute Factorio runtime proof.


## 2026-07-21 — Milestone 0786: Canonical Cached Repair and Consecration Selectors

Consolidated the 0.1.248 repair and consecration target predecessor wrappers into one cache-aware canonical selector for each work family. Fragment 014 now owns cache-first selection plus the original live fallback scans. Cached repair candidates must satisfy force, health, priest/proxy exclusion, useful repair-pack damage, and current station-radius bounds. Cached consecration candidates must satisfy current radius, sanctification record state, incomplete progress, station supply, and useful-item rules before selection. The original fragment 003 selectors and both 0248 predecessor captures are explicitly retired. Static Source validation does not constitute Factorio runtime proof.


## 2026-07-21 — Milestone 0787: Canonical Idle Availability Predicates

Consolidated the idle-scan and idle-conversation availability predecessor stacks into one authoritative predicate per behavior. Fragment 014 now owns idle-scan availability with direct 0248 higher-priority cancellation, 0246 quarantine, settings, validity, mode, and conflicting-state checks. The final editable idle_priest_conversations.lua module now owns conversation availability with direct 0249 visibility cancellation, 0248 probing, 0246 quarantine, settings, validity, listener timing, cooldown, mode, and conflicting-state checks. The base 0167/idle-scan definitions, 0246 wrappers, 0248 wrappers, and 0249 predecessor capture are explicitly retired. tick_pair, conversation start/update, and movement behavior remain unchanged. Static Source validation does not constitute Factorio runtime proof.


## 2026-07-21 — Milestone 0788: Priority, Sweep, and Logistics Command Retirement

Retired the manual 0.1.246 priority dump, state dump, registry rebuild, and forced station scan commands together with the 0.1.248 sweep-cache dump and 0.1.249 logistics report command. Automatic priority diagnostics, the 73-tick diagnostic heartbeat, registry and scan helper functions, station sweep updates, logistics behavior, and later recovery authorities remain active. All six stale command names are now removed by runtime_command_cleanup_0720. Static Source validation does not constitute Factorio runtime proof.


## 2026-07-21 — Milestone 0789: 0250–0255 Diagnostic Command Retirement

Retired five manual diagnostic commands covering the Emergency Micro-Miner, ranked assignment delegation, powered Laboratorium chain, Martian fuel bootstrap, and Planetary Magos standard-industry planner. Their reporter and runtime helper functions, assignment tick service, emergency-operation wrappers, power-chain selection, fuel bootstrap behavior, and Magos planner behavior remain active. All five stale command names are removed through runtime_command_cleanup_0720. Static Source validation does not constitute Factorio runtime proof.


## 2026-07-21 — Milestone 0790: Legacy Observability Command Retirement

Completed the retirement ledger for eight report-only legacy commands: live priest diagnostics, rank-radius reporting, spawn and last-spawn dumps, active pair and name listings, legacy task snapshots, and Cogitator inventory summaries. The registrations were already absent; this repair adds explicit source retirement markers and stale-command cleanup without modifying any existing runtime helper or behavior body. Static Source validation does not constitute Factorio runtime proof.


## 2026-07-23 — Post-Cleanup Inventory and Documentation Reconciliation

Accepted milestones 0779–0790 at exact cleanup SHA `511254d59e76980706921c0a518c7b7f9440d214` after complete Source validation run `29875375384`. A subsequent read-only inventory at `de8630c5307348f812c06edcd08cf85700731244` scanned 306 Lua files and found 171 unique command registrations, including 38 in generated fragments, plus 109 direct `script.on_*` routes. No duplicate command names were present and none of the 0779–0790 retired commands had reappeared. This closes the targeted cleanup tranche while keeping the broader recovery cleanup open. The next bounded audit begins with generated fragments 015–020 and direct event/timer route classification. No Factorio runtime, migration, save/reload, behavioral, profiler, packaged-load, or release evidence is claimed.


## 2026-07-23 — Milestone 0791: Dynamic Governance Evidence Consistency

Repaired the governance prerequisite audit so accepted Source-validation evidence is parsed and compared across CURRENT_TESTING_GOALS.md, RECOVERY_AUTHORITY_MAP_CURRENT.md, and the canonical development history instead of being hard-coded to the July 20 SHA. The audit now requires the synchronized post-cleanup inventory markers, the 47-retired authority diagram, and a consistent 40-character SHA plus workflow run. Its success summary now reports 26 active and 47 retired authorities. Static validation remains distinct from Factorio runtime evidence.


## 2026-07-23 — Milestone 0792: Generated Command Surface Retirement

Retired all 31 manual command registrations in generated fragments 015–020. The removed surfaces covered emergency forcing and reporting, bootstrap forcing, fast/raw fallback diagnostics, order refresh, gather replanning, scheduler and radar reports, station craft and acquisition forcing, combat and retreat forcing, supply sanitation, armor refresh, re-imprint servicing, and cell-preservation inspection. The transformation changed no automatic event or cadence route: the fragments retain 31 TechPriestsRuntimeEventRegistry routes and zero direct script.on_* fallbacks. All underlying service and helper functions remain in their authoritative source locations, and runtime_command_cleanup_0720 removes every stale name. Static validation does not constitute Factorio runtime proof.


## 2026-07-23 — Milestone 0793: Generated Command Closure

Retired the seven remaining generated command registrations: event-registry summary, special-movement summary, consecration modularization report, emergency-operation console toggle, priest-mapping debug audit, lifecycle-log toggle/flush, and nearby registration report. Automatic ownership remains unchanged: generated fragments retain 69 TechPriestsRuntimeEventRegistry routes and zero direct script.on_* routes. The emergency doctrine remains controllable through its station GUI, mapping and lifecycle audits remain automatic, and all supporting functions remain in source. runtime_command_cleanup_0720 now recognizes three exact historical tech-priests-* names before applying the newer tp- prefix rule. Static validation does not constitute Factorio runtime proof.


## 2026-07-23 — Milestone 0794: Consecration Route Ownership

Removed six direct event/timer routes from the consecration family. history_gui now registers one labeled handler per GUI kind through the canonical GUI router and one 121-tick refresh through runtime_event_registry. runtime_bridge retains its built, removal, and 89-tick scan routes exclusively through the registry. mining_sensor_0495 registers its cadence before setting installed state or publishing globals. All three installers fail closed when canonical route registration is unavailable. Existing consecration commands and behavior helpers remain unchanged. Static validation does not constitute Factorio runtime proof.


## 2026-07-23 — Milestone 0795: Startup Provisioning Route Ownership

Migrated startup_provisioning from two direct player-event routes and one direct 67-tick service to three stable runtime_event_registry routes owned by startup-provisioning-0324. Installation now fails closed when the registry is unavailable and sets installed state only after route acceptance. Starter station grants, delayed retries, current-player repair scheduling, special-name awareness, compatibility redirection, and both startup diagnostics remain unchanged. Static validation does not constitute Factorio runtime proof.


## 2026-07-23 — Milestone 0796: Acquisition Route Ownership

Removed three direct nth-tick fallbacks from acquisition_executor, acquisition_repair, and acquisition_unstick. The modules now own stable 30-, 90-, and 120-tick runtime-event-registry routes and fail closed when canonical registration is unavailable. Commands, emergency-acquisition wrapping, pulse reasons, repair state, and unstick behavior are installed only after route acceptance; installed flags are published last. Static validation does not constitute Factorio runtime proof.


## 2026-07-24 — Milestone 0797: Stable Visual Route Ownership

Removed the direct periodic fallback from alt_writ_visual_stability_0474 and consolidated its periodic refresh, cursor-stack refresh, runtime-setting refresh, and selected-entity refresh under four stable runtime-event-registry routes. The module now fails closed when canonical routing is unavailable and publishes storage-backed state, legacy visual patches, globals, commands, and its installed flag only after all routes are accepted. Static validation does not constitute Factorio runtime proof.


## 2026-07-24 — Milestone 0798: Behavior Mutex Route Ownership

Removed the direct 11-tick fallback from behavior_mutex_0466 and established one stable runtime-event-registry cadence for combat/acquisition mutual exclusion and invalid target cleanup. The module now fails closed when canonical routing is unavailable and initializes storage, installs wrappers and commands, publishes global APIs, and marks itself installed only after route acceptance. Static validation does not constitute Factorio runtime proof.


## 2026-07-24 — Milestone 0799: Behavior Contracts Route Ownership

Removed the direct cadence fallback from behavior_contracts_0479 and established one stable runtime-event-registry route for movement-before-beam and related behavior enforcement. The module now fails closed when canonical routing is unavailable and initializes storage, installs scan-line, laser, and diagnostic wrappers, publishes its global API and commands, and marks itself installed only after route acceptance. Static validation does not constitute Factorio runtime proof.


## 2026-07-24 — Milestone 0800: Behavior-Tree Monitor Route Ownership

Removed the direct 17-tick fallback from behavior_tree_monitor_0642. The monitor now registers first with runtime_tick_broker and uses one named runtime-event-registry cadence only when broker registration is unavailable or rejected. It fails closed if neither owner accepts the service and publishes storage-backed state, exported globals, route-owner metadata, and its installed flag only after ownership succeeds. Static validation does not constitute Factorio runtime proof.


## 2026-07-24 — Milestone 0801: Bootstrap Resource Governor Route Ownership

Removed the direct cadence fallback from bootstrap_resource_governor_0637 and established one runtime-event-registry route. The governor remains disabled by default, and storage, command registration, global publication, and installed state now occur after route acceptance. Static validation does not constitute Factorio runtime proof.


## 2026-07-24 — Milestone 0802: Construction Ghost Planner Ownership

Removed the direct 83-tick fallback from construction_bootstrap_ghost_planner_0645. The planner now registers with runtime_tick_broker first and uses one named runtime-event-registry cadence only as fallback. Global and installed state publish after ownership acceptance. Static validation does not constitute Factorio runtime proof.


## 2026-07-24 — Milestone 0803: Audio Route Ownership

Removed seven direct audio event/timer fallbacks across conversation_voice_0530, operational_sounds_0531, and placeholder_audio_0533. The modules now own ten named runtime-event-registry routes, use the correct registry metadata argument, fail closed when routing is unavailable, and publish commands, wrappers, globals, and installed state only after route acceptance. Static validation does not constitute Factorio runtime proof.

## Milestone 0804 — GUI and visual route consolidation

- Removed raw GUI/timer ownership from Work State, catalog, legacy network visuals, station overlay, 0465 recovery handlers, GUI bus, and 0476 visual leasing.
- Integrated the intended 0476 visual timing directly into canonical 0474 and folded command-camera refresh into its cadence.
- Registered Work State through the GUI router, made router installation fail closed, and moved final binding to the late 0465 bootstrap after generated installers.
- Added grouped permanent checker `check_gui_visual_route_ownership_0804.py` and dedicated status lane.
- Source version remains protected at 0.1.672; no runtime or packaging proof is claimed.

## Milestone 0805 — Frequent route ownership

Consolidated the remaining active sub-30-tick fallback authorities. Station crafting now registers its cadence before storage, wrappers, commands, or installed-state publication and no longer calls `LuaEntity.set_command` directly. The 0471 governor exclusively owns periodic overhead refresh, while 0473 is a route-free late compatibility authority with its pending-state loop retired. Added `check_frequent_route_ownership_0805.py`; runtime proof and release authorization remain outstanding.

## Milestone 0806 — Infrastructure route ownership

Consolidated master infrastructure planning and infrastructure-first enforcement under broker-first ownership. Both modules now fail over to one named runtime-registry cadence only when broker registration is unavailable, publish state only after an owner succeeds, and use typed station-local facility scans. Added `check_infrastructure_route_ownership_0806.py`; runtime proof and release authorization remain outstanding.

## Milestone 0807 — Status-State Sanity Ownership — 2026-07-26

- `64a35abe1244310561d736f272eda1179a80fd2c` — consolidated `status_state_sanity_0448` under one fail-closed `runtime_event_registry` cadence, removed its raw `script.on_nth_tick` fallback, delayed global and wrapper publication until route acceptance, returned structured service truth, and made the visual-classifier adapter read-only.
- `223f47558a4db07a12ca3524fd16a441b34c951e` — added `check_status_state_sanity_ownership_0807.py` to forbid raw route fallback, mutable visual classification, publication before route acceptance, and unstructured service results.
- `28a875c3f9bd5b333a81710d43d564c674e39bd2` — added the dedicated ownership validation lane. At this exact source head, `tech-priests/status-state-sanity-ownership` passed in workflow run `30190776270`, and the then-current full `tech-priests/source-validation` passed in run `30190776290`.

The focused checker is prepared for registration in canonical Source validation through the workflow-authorized GitHub connector. This is static source evidence only. No Factorio load, configuration-change, migration, save/reload, behavioral, profiler, packaging, or release claim is made. The next bounded source audit is station supply and inventory stewardship ownership, beginning with `station_supply_satisfaction_0639`, `emergency_supply_reserve_0497`, `inventory_steward`, and `stone_cache_filter_0534`.


## Milestone 0808 — Canonical Station Inventory Stewardship — 2026-07-26

Consolidated persistent priest-cargo custody directly into `inventory_steward`, replaced the active `inventory_transfer_integrity_0687` hardener one-for-one, and retired `0687` as inert source-only history. `storage_role_authority_0686` now exposes direct storage-source and stash APIs instead of wrapping the steward or filtered-cache module. Filtered caches remove wrong items before exact rerouting and retain/restore custody rather than spilling or silently clearing stacks. Station supply satisfaction and emergency reserve now acquire canonical route ownership before publishing runtime behavior and retain no raw event/timer fallback.

The declarative recovery graph remains 26 active hardeners and 48 explicitly retired source-only authorities. Added `check_inventory_steward_consolidation_0808.py` and updated the inventory transfer boundary checker. This is source implementation only; exact-head Source validation and Factorio runtime evidence remain required.

## Milestone 0809 — Runtime Invalidation Route Ownership — 2026-07-26

Consolidated `runtime_config_0626` and `station_area_change_invalidator_0634` under named `runtime_event_registry` routes. Runtime settings now acquire the `runtime-setting-changed` route before creating the initial storage-backed snapshot or publishing global APIs. Station-area invalidation now acquires three grouped routes—`build-created`, `removed-destroyed`, and `player-inventory-change`—before initializing storage, registering its manual command, or publishing its module global. Both installers fail closed and remove accepted routes when later initialization fails; neither retains a raw `script.on_event` fallback.

The declarative recovery graph remains 26 active hardeners and 48 explicitly retired source-only authorities. Added `check_runtime_invalidation_route_ownership_0809.py` and a dedicated validation lane. No Factorio runtime proof is claimed: configuration-change uniqueness, save/reload route persistence, profiler switching, and physical station-area invalidation remain live runtime evidence targets.

## Milestone 0810 — Bootstrap and Chatter Route Ownership — 2026-07-26

Consolidated the historical bootstrap consecration event surface and background chatter cadences under named `runtime_event_registry` routes. `bootstrap_runtime.lua` now registers the final composite build, removal, selection, explicit-capsule, and 149-tick watchdog handlers as `explicit-consecration-capsule`, `consecration-build-chain`, `consecration-remove-chain`, `consecration-selection-chain`, and `consecration-watchdog`. The composite handlers retain their preceding legacy wrapper calls exactly once, while raw `script.on_event` and `script.on_nth_tick` registrations are removed.

`chatter.lua` now acquires `background-pulse` and `pending-line-visibility` cadences before initializing storage, registering commands, or publishing global APIs. The direct-tap wrapper remains part of the final bootstrap selection chain instead of independently replacing Factorio's selected-entity handler. Partial chatter or bootstrap route acquisition is rolled back, and neither file retains a raw route fallback.

The declarative recovery graph remains 26 active hardeners and 48 explicitly retired source-only authorities. Added `check_bootstrap_chatter_route_ownership_0810.py` and a dedicated validation lane. No Factorio runtime proof is claimed: exact-once build/remove/selection/capsule dispatch, chatter interval behavior, pending-line visibility, save/reload route uniqueness, and composite legacy-chain preservation remain live runtime evidence targets.

## Stage 5 Smoke-Tooling Authority Reconciliation — 2026-10-06

Repaired the local Stage 5 smoke gate so it no longer enforces superseded movement architecture or the obsolete `0.1.628` pre-smoke version. `check_stage5_smoke_bundle.py` now dispatches the canonical `check_movement_enforcement_void_boundary_0765.py` boundary audit. `check_stage5_package_readiness.py` now requires the canonical movement controller, broker-only Void backend, inert `0566` retirement marker, and the protected `0.1.672` packaged baseline.

The Stage 5 smoke checklist and GitHub file manifest now match the current authority graph: `movement_controller.lua` owns the public movement API, ground movement, and enforcement; `void_movement_authority_0630.lua` is delegated broker-only authority for Void pairs; `movement_enforcement_0566.lua` remains source-preserved and inert. The checklist no longer requires the retired `/tp-void-movement-0630` command and no longer suggests that a narrow smoke load authorizes a version bump.

This slice is source/static validation-tooling repair only. It does not claim a new Factorio load, migration, save/reload, behavioral, profiler, packaged-load, release-candidate, or release result. Those Stage 5 evidence gates remain open until independently observed and accepted.

## Stage 5 Unpackaged Smoke Boundary and Checker Path Repair — 2026-10-07

Replaced the smoke checklist's manual ZIP/PowerShell `Compress-Archive` and Bash `zip` recipe with an isolated, unpacked Factorio mod-directory procedure. The prior recipe could create a ZIP without passing the canonical fail-closed `tools/package_local.py` release-authorization gate, despite the standards explicitly forbidding that bypass. The new procedure refuses an existing staging destination, preserves the protected `0.1.672` baseline, requires separate dependencies and disposable saves, and identifies `--mod-directory` as the development-only load route.

Hardened `check_stage5_package_readiness.py` to verify the mod name and Factorio target as well as the protected version, changed its messages and the bundle's success message to avoid implying package authorization, and corrected the movement-failure and proximity checkers to resolve their source roots relative to their own script paths rather than the caller's working directory. Updated the current testing target and recovery authority map with the same evidence boundary.

This is a source/tooling/documentation repair, not a runtime or release result. No new full source-validation run, Factorio load, migration, save/reload, behavior, profiler evidence, package, or publication is claimed. The smoke gate remains subordinate to the complete Stage 5 recovery evidence and verified release-authorization process.

## Stage 5 Release-Evidence Integrity Repair — 2026-10-09

Corrected two fail-closed release-gate defects. The release-authorization checker previously allowed an arbitrary `recovery_evidence.manifest` path to supply the authorized SHA-256 even though the runtime evidence checker always reads `recovery-evidence.json`. Authorization now requires and hashes the canonical file, and a negative self-test rejects a parent-directory decoy manifest. The runtime evidence validator now rejects `NaN` and `Infinity` JSON constants and finite-syntax numeric exponents that overflow to infinity in profiler metrics; negative self-tests cover both paths. The evidence runbook and active Stage 5 testing target were synchronized.

These are source/tooling and documentation changes. No exact-head full source-validation run or Factorio load, migration, save/reload, behavioral, profiler, package, or publication evidence is claimed. The protected `0.1.672` baseline and release authorization remain unchanged.

## Milestone 0811 — Economy Housekeeping Route Ownership — 2026-10-08

Removed the raw Factorio cadence fallback from twelve passive economy modules: `0568`, `0569`, `0570`, `0571`, `0575`, `0576`, `0578`, `0579`, `0582`, `0585`, `0593`, and `0594`. Cache pruning, dirty-region cleanup, corridor-cache service, machine-claim cleanup, prototype/index housekeeping, calm-cache cleanup, dirty-event flush, performance-cache prune, and adaptive-route rescan now require stable owner/route identities in `runtime_event_registry`. `0576` also moved its runtime diagnostic-setting listener to a required named registry route.

Updated the corresponding `control.lua` loaders so a missing installer or any non-literal-true install result is treated as failure instead of being silently ignored. Added `check_economy_housekeeping_route_ownership_0811.py` to prevent raw-route regression and to keep the temporary `0596` early nth-tick hook visible rather than pretending the entire direct-route inventory has already been retired.

This is source implementation and static-checker coverage only. No Factorio cadence execution, configuration-change uniqueness, save/reload, profiler, migration, packaged-load, or release evidence is claimed. The protected `0.1.672` baseline is unchanged.

## Milestone 0812 — Dormant Wake-Event Route Ownership — 2026-10-08

Removed the final ordinary raw event fallback from the active efficiency family. `efficiency_economy_0595` now registers Tech-Priest build, removal, and research wake events only through `runtime_event_registry`, using stable `wake-build`, `wake-remove`, and `wake-research` route identities. Registration records are retained during installation so any later route rejection rolls back already-accepted routes.

Moved 0595 global wake API and command publication after successful route acquisition and made the `control.lua` loader treat non-literal-true installation as failure. Added `check_dormant_wake_route_ownership_0812.py`. The `0596` early nth-tick monkeypatch remains intentionally present because it intercepts legacy registrations that occur before the registry-backed runtime spine is fully installed; its retirement requires a complete active raw-route inventory outside the efficiency family.

This is source implementation and static-checker coverage only. No Factorio wake-event, configuration-change, save/reload, profiler, migration, packaged-load, or release evidence is claimed.

## Stage 5 Ground Overleash Return Continuity — 2026-10-20

The Factorio four-rank endurance run `39399124884` at source commit `bf7d3fb412f8bfaaeac199c2ce7251392a055cab` reached tick 36000 with four living pairs, physical ore and plate production, but zero electronic circuits or science. Diagnostics showed distant priests repeatedly in canonical overleash-return mode with retarget holds. The movement controller stopped and recreated the same active return every 89-tick enforcement pass, resetting the Factorio pathfinder before a long route could settle. The canonical owner now preserves a valid, unexpired return to the current station, replaces it if the station moves, and releases its high-priority safety claim after reentry into the work envelope. Lower-priority same-target callers also cannot rename that active safety route.

A focused Lua 5.2 regression for return continuity, ownership, relocation, and release is wired into existing source validation. This is source repair and regression coverage, not accepted Factorio endurance proof: the full circuit/science failure, new-save and migration/reload, behavior, profiler, package, and release gates remain open until exact-commit runtime evidence passes.

## Method I 0855 — Fourth-stage saved-plan integrity (2026-10-25)

Factorio run 40225967229 passed on 6d5bc457, but did not exercise five-station reversal; 30d279b0 adds the fourth-stage Senior source implementation. The Senior owner previously dereferenced a missing saved predecessor descriptor before validating it, which could interrupt the runtime tick. It now rejects invalid descriptors without moving or debiting items. Added regression coverage after four source-fixture depot handoffs asserting no exception, duplicate mines, lost depot items or original priests. This commit's own source and engine workflow outcomes are separate and must be checked before marking validation; dedicated reversal engine/save-reload/reconstruction proof remains open.

## Method I 0856 — Real-engine wrong-direction fixture (2026-10-25)

Extended the existing CI-only Factorio save/reload harness (no new workflow) to place a distinct five-station Magos→Senior→Intermediate→Junior→Junior peer fixture with the line directed away from *untouched naturally generated* ore. The engine must pair and rank each priest and establish actual 0480 hierarchy/peer edges, confirm no spare station items or initial crafting components in the fixture chests, and observe a still-existing ore target. The production 0850 preflight is called read-only and its reason logged; legitimate busy-duty refusal is not bypassed. The existing Python smoke runner requires an explicit topology-only marker. This fixture is not evidence that the AI built those five stations, mined or returned a station item, or rebuilt toward ore. Confirm the new commit's Factorio 2.0.77 result before acceptance; retain the four-stage physical reversal, independent reload and methods II/III as outstanding.

## Method I — 0480 / 0850 geometry reconciliation (2026-10-25)

Full engine run 40228548242 at b54ed7cf passed but its new topology marker included `preflight_ready=false` with `ambiguous-intermediate-subordinates`. Under 0480's 220-tile range an Intermediate 40 tiles from the terminal Junior owns both rank-1 Juniors. Corrected the CI-only station geometry so the terminal peer is outside the Intermediate's direct-link range but still inside the Junior peer range, and strengthened fixture assertions to require exact parent/peer cardinality and an actual 0850 four-stage reversal preflight. Preflight-denial diagnostics preserve legitimate work rather than force a pass. Engine result for the new commit remains outstanding.

## 0857 — Production first Junior mine and Magos depot runtime fixture (2026-10-25)

Extended CI-only Factorio test to issue a real 0256 construction ghost/writ to the original Planetary Magos after live 0850 preflight. The production executor owns actual movement, physical station mine, cargo inventory and 0852 depot receipt, while the fixture only observes original-priest and counted-item identity. The smoke runner now requires explicit first-Junior physical-depot evidence after the existing endurance, relocation, ore return, topology and reload gates. The final process permits 36,000 ticks for actual travel. Status remains engine-pending until this commit's run passes, and full four-station reversal/rebuild remains open.

## 0858 — Safe real-writ ownership in five-station engine fixture (2026-10-25)

Followed up the 0857 first-Junior engine fixture with a CI-only mission-state integrity correction. The fixture previously populated just the known resource and root fields before issuing 0256 work, leaving 0820's periodic service without `segments` or `pending_expansion_id`. The fixture now models the persisted 0820 state exactly, binds the actual active 0256 writ ID before future 0820 service, and verifies ore is outside the root's real radius. No extra recovery scheduler, fabricated material, or runtime behavior changes were made; check exact-head source and Factorio 2.0.77 results before accepting the first-depot proof.

## 0859 — Second leaf-first physical depot engine checkpoint (2026-10-25)

Extended the existing CI-only five-station starvation scenario with an independent second-Junior physical mine/receipt checkpoint through the existing 0853 owner. This gate follows and rechecks the first verified 0852 depot, invokes the normal 0256 executor under the same live writ, and requires two distinct counted Magos inventories and both original living Junior priests. It neither moves items in test code nor resets legitimate ongoing duties. The Python save/reload runner requires the second marker after retained industrial, physical ore-return and first recovery assertions, with 48,000 final-process simulation ticks. Source/Factorio status must be read from the exact new HEAD before acceptance.

## 0860 — Reversal failure evidence exposed in Actions (2026-10-25)

Expanded the existing Factorio smoke-runner failure-evidence filter to include `REVERSAL_ENGINE_*` markers as well as existing ore-courier and error lines. A real first/second Junior-station recovery rejection, timeout or custody blockage is now visible in the Actions job's bounded diagnostic output without requiring artifact download. This changes observability only; the industrial/endurance, save/reload, four-rank ore return and ranked reversal assertions remain untouched and must still pass on the same exact source HEAD.

## Method I 0861 — Future-work reversal arbitration correction (2026-10-25)

Inspected completed Factorio 2.0.77 run 40230982911 (`7fab8e88`): its independent-process stage failed, reporting `REVERSAL_ENGINE_FIRST_DEPOT_TIMEOUT phase=assigned`. The downloaded engine log showed 0256 created the legitimate resource ghost/writ and 0640 immediately scheduled new bootstrap-smelting tasks for the entire five-station test chain. Introduced a read-only active-reversal participant reservation in existing 0850, enforced by the canonical 0640 ordinary planner before assigning new work, plus explicit 0256 high-priority deferral diagnostics. All 0822/0823 physical custody checks, current duties, actual Factorio movement, ore targets, and station item ownership remain unchanged. Added Lua regression for active, foreign, completed and corrupt-plan cases. This is a root-cause scheduling repair requiring fresh source and Factorio acceptance, not a claim of recovered physical stations or completed Method I.

## 0862 — Actual 0640 reservation assertion and 0248 blockage telemetry (2026-10-25)

Tightened the 0861 regression to call the production 0640 governor for each of the five original rank/peer pairs and require a future-work reservation without assigning a new ordinary task. Added CI-only read-only 600-tick recovery diagnostics reporting 0248 higher-priority arbitration, current root/Junior modes and duties, and 0851 stage phase. The diagnostics never teleport, manufacture a station item, cancel an ongoing duty, or substitute for the required physical Magos depot receipts. Source and Factorio exact-head validation remain separate gates.

## 0863 — Correct physical-recovery runner wall-time limit (2026-10-25)

The independent final Factorio 2.0.77 recovery process previously requested up to 48,000 simulated ticks but inherited the smoke runner's 300-second wall-clock timeout. Real failed Actions logs (including 40231979535) showed this timer firing while the scripted headless process was still active, masking late-stage recovery evidence. Updated only the existing canonical Factorio workflow's final smoke invocation to supply a deliberate 900-second subprocess budget, within its unchanged 45-minute job limit. No alternative engine path, invented inventory, removed validation or altered simulation tick count. Exact-head acceptance remains pending.

## Method I 0865 — Preserve real combat priority while repairing engine recovery fixture (2026-10-25)

Examined completed Factorio run 40233127012 (b7587982): independent-engine recovery failed `REVERSAL_ENGINE_FIRST_DEPOT_TIMEOUT phase=reversal-deferred-higher-priority:attack`. Root was legitimately distracted by a nearby hostile, so relaxing 0248 attack precedence would have been a dangerous production fix. Adjusted only the CI five-station natural-ore site search: require five genuine placeable station positions **and** a non-hostile 110-tile buffer around each via actual `surface.find_entities_filtered{force="enemy"}`. Pairing rechecks each station's actual radius plus safety margin. Selection and rejection counters are logged; no entity is removed or artificially disabled. Later emergent threats still preempt as designed. Await new exact-HEAD 2.0.77 validation before marking first/second physical depot passed.

## 0866 — Strict production survival-priority gate (2026-10-25)

Extended the live five-station Factorio CI scenario to query the actual 0248 higher-priority authority for every original pair after hierarchy pairing. Even if geometric enemy filtering succeeds, the experiment fails immediately with observed priority and target identity/coordinates if any priest has real attack, repair or consecration priority. The existing smoke runner requires this additional exact-process evidence alongside the quiet-site marker and the two independently counted physical recovery receipts. No synthetic materials, canceled duties, artificial peaceful state or changed production safety behavior. Source/Factorio result must be checked at this exact commit before acceptance.

## 0867 — Read-only four-depot custody prerequisite (2026-10-25)

Created a new read-only production audit for the four 0852 engine-owned inventories and four original living priests after the Magos completes the Senior return. Integrated at the existing 0855 stored-state branch; four-stage mock regression exercises exact item/ID order, missing physical item, duplicate inventory alias and restoration, and separate-module reload. This prevents a later outward reconstruction owner from assuming the station objects exist merely because the saved plan says so. No station items are moved or credited and no new work takes authority from current 0823/0824 custody. The first/second Junior live-engine recovery is still under validation and cannot be claimed from this source change.

## 0869 — Fix unsuitable recovery-site geometry without weakening production survival (2026-10-25)

Real Factorio 2.0.77 run 40234828103 at 3c5d failed with `REVERSAL_ENGINE_NATURAL_ORE_WRONG_WAY_SITE_UNAVAILABLE hostile_rejections=5769 terrain_rejections=27895`, before any ore-targeted Magos recovery started. The previous far-Nauvis search was dominated by natural hostile bases and non-generated corridor endpoints. Replaced only the isolated recovery fixture's terrain source with a dedicated persistent Factorio 2.0-generated surface: copied ordinary source ore and terrain generation, fixed seed 1342025, disabled only new enemy-base generation on that test surface, and constrained candidate ore to generated 365-tile corridors. No enemy entities are deleted, no peaceful mode or production 0248 priority altered, and prior Nauvis biter defenses/endurance scenarios are retained. Demand real 2.0.77 engine outcome before calling the first/second physical stage successful.

## 0873 — Diagnosed physical return arbitration from latest failed engine (2026-10-25)

Reconciled current `main` HEAD 665291c2 with most recent completed Factorio runtime run 40250345448 at 56257b87. Its independent reload test got past natural ore, topology, 0248 idle and first actual Junior station mine, then timed out at the first Magos depot: `higher-priority-movement-owned` recurred while the carrier was transporting the real station item. Diagnosed a distinct 0418 safety governor problem: when a legitimate carrier walks beyond the hard leash from its still-standing original Junior station, 0566 safety submits a priority-840 return **to that Junior**, defeating the item-conserving 0851 return to the Magos. Introduced a narrow 0418 custody guard for an active, exactly matched 0256 writ, physically staged 0823 lease, original surviving priest and a real one-item 0824 cargo inventory. Generic overleash safety cannot steal the active transport, but normal safety resumes for invalid cargo, changed owner or lease. It can release only a preexisting 0566 generic overleash request, not real combat or other emergency owners. Added actual movement-controller regression cases for these boundaries. Continue real-engine testing; second Junior, Intermediate/Senior, independent four-inventory save/reload and outward rebuild remain unverified.

## 0873 regression follow-up — unreadable engine inventory fails closed (2026-10-25)

The initial 0873 source run 40254876595 failed in the new test fixture because a Lua closure referenced a global `physical` while its local was still being initialized. Corrected the fixture to declare the inventory before attaching its `get_item_count` closure. Also wrapped physical-count readback in the 0418 enforcement custody preflight with `pcall`: if Factorio invalidated the LuaInventory between callbacks, overleash safety must resume, not crash the runtime tick or grant a bogus exemption. Added a negative regression for a throwing inventory read. This changes no engine-owned item, station position, or accepted return distance.

## 2026-11-05 — Fortified Martian bunker v0.2 art gallery

Published the independent 3×3-footprint Fortified Martian Heavy-Weapon Bunker modeling checkpoint in `art/source-to-3d/martian-bunker/`, with a v0.1 front-view baseline, v0.2 front/rear/256px engineering gallery, reproducible source-and-GLB ZIP, and one focused Blender GitHub Actions workflow. Owner-directed v0.2 revisions preserve the 3×3 foundation while strengthening lower concrete bevels, narrowing the upper roof, lowering the fixed rear magazine/controls below the turning platform, and placing the connected telemetry antenna on the rear of the **co-rotating turret casing**. The source manifest asserts at least 0.10 tile-unit separation between stationary rear equipment bodies and the moving assembly; the fixed-to-rotating signal coupling is an intentionally closer slip-ring interface.

GitHub Actions run [42151882030](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42151882030) **passed** the geometry checks, installed and ran real Blender headlessly, saved a verified native editable `.blend` (131 imported mesh objects; 42 in the rotating group), produced actual 900×900 Blender front/rear renders and a 256px preview, and committed those files to `main` as [`ab856fdd5d6ff9aa7563c2a9ffac342c4f084114`](https://github.com/mrcalzon02/Tech-Priests/commit/ab856fdd5d6ff9aa7563c2a9ffac342c4f084114). Initial run failed only because Ubuntu Blender lacked OpenImageDenoiser; source was repaired to disable optional denoising, then rerun successfully. **Not yet accepted as final Factorio-quality sprite**: finish PBR materials, real 360-degree mechanical collision review and in-game scale/lighting comparison before any sprite replacement. No gameplay, recipe, entity prototype or existing mod sprite changed.

## 2026-11-05 — Martian bunker Blender v0.2 visual rejection and verified v0.3 correction

**Failure / regression:** The first native Blender output for the Fortified Martian Heavy-Weapon Bunker v0.2 was sideways, monochrome, and showed visually detached parts, despite passing an insufficient mesh-count/parent-count CI job. The imported trimesh GLB was treated as though its coordinates and colors were already Blender-native. The script failed to check actual world-space base/muzzle/turret/mast positions and did not explicitly construct source-identity Principled BSDF materials. This was **not** a valid art acceptance result. The v0.2 source geometry and manual blockout remain as references; v0.2 Blender renders in the gallery are clearly marked rejected.

**Corrective implementation:** v0.3 reconstructs native Blender meshes directly from the 131 named original **Z-up** source meshes and their 16 explicit material identities. The turret mount at Z=1.70 uses inverse-parenting to preserve world placement, including cannon, optics, and mast; rear magazine and controller stay stationary. Blender scripts assert base footprint, shell/muzzle/mast coordinates, vertical clearances, mounting contact, and 15-degree steps through 360-degree traverse. Material inputs explicitly convert source sRGB hex colors into the linear RGB required by Blender shaders, restoring actual industrial gray and deep Martian-red surface identity rather than blown-out pale gray and pink. The final GLB is **exported by Blender** and then imported into a clean Blender session to verify all 131 meshes remain upright, attached and correctly colored. Real Cycles front/rear renders and 256px reduction are published to the [gallery](https://github.com/mrcalzon02/Tech-Priests/tree/main/art/source-to-3d/martian-bunker/gallery).

**Evidence:** [GitHub Actions run 42153818744](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42153818744) succeeded on Blender 4.0.2, including independent GLB re-import and actual material/render pixel checks. V0.3 front and rear have 250,384 and 259,817 visible pixels, including 46,345 and 42,616 Martian-red pixels respectively. A true editable `.blend`, Blender-exported `.glb`, reproducible scripts, original coordinate-mesh payload, validation JSON and verified renders were published to `main`; development gallery and v0.2 rejection notes committed in [`da9046671cade9b4f2ae668c8192e12011f3f41a`](https://github.com/mrcalzon02/Tech-Priests/commit/da9046671cade9b4f2ae668c8192e12011f3f41a). **This resolves the broken orientation/color/attachment conversion, not final Factorio sprite quality or in-game testing.** Original gameplay, prototypes, recipes and sprite assets remain unchanged.

## 2026-11-05 — Fortified bunker v0.4 hull-surface conformance and angled corner load paths

**Owner-directed asset refinement:** Four formerly upright rectangular corner posts have been replaced with octagonal eight-vertex-section, physically **inward-leaning and chamfered ferrocrete buttresses** paired with tapered spread footings. Their top cross sections move inward on both x/y axes; the concrete foundation stays at its original 3×3 footprint. All visibly external fixtures affected by the newly sloped outer hull were re-seated using the geometric wall-surface plane at their own heights instead of obsolete fixed flat-wall offsets. Corrected surfaces and equipment include front armored maintenance hatch, four bolts and closing spine, approach sensor/lens, structural gothic access ribs/anchors/keystone, east controller side plate and fasteners, power entry and breaker with status light, west condition gauge/lens, rear guarded vent and louvers, and the remote-control access cover/certificate. During actual render review, a red controller panel was visibly clipping a rear roof chamfer. The cabinet and panel were relocated below the roof to an unobstructed part of the north-facing sloped wall, and both power/data service connections were rerouted to actual fixtures, not left hanging.

**Objective verification:** Original editable geometry pipeline retained Z-up axes, 131 independently named meshes and 42 rotating turret meshes. The new `verify_hull_conformance.py` uses actual source vertices to prove top-and-bottom overlap for **22 surface-mounted equipment or structural assemblies** and both-axis inward taper for **8 corner buttress/foot objects**, with a strict 3×3 foundation. GitHub Actions [run 42159959336](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42159959336) passed source construction, contact tests, native Blender assembly, independent GLB re-import, and all four 900×900 actual Blender camera renders with color/framing checks. The verified native `.blend`, Blender-exported `.glb`, full geometry source and manifest, four camera views, 256px preview and before/after gallery were pushed to `main` by [`3fc0fc2292f1630941d60083b768e7194ee58533`](https://github.com/mrcalzon02/Tech-Priests/commit/3fc0fc2292f1630941d60083b768e7194ee58533). [Source gallery](https://github.com/mrcalzon02/Tech-Priests/tree/main/art/source-to-3d/martian-bunker/gallery).

**Scope limits:** This validates source-to-Blender hull attachment, moving turret grouping and render integrity—not final production-ready Factorio sprite art, deep subsystem swept-volume collision testing, PBR dirt/finish, gameplay behavior, or replacement of mod sprites. Existing gameplay and Factorio code were untouched.

## 2026-11-05 — Fortified Martian bunker turret front v0.5 two-pass refinement

**User-directed art geometry work:** Continued the owner-approved v0.4 3×3 fortified bunker with **two actual successive front-turret geometry passes**. Pass one replaces square armor cheeks with sloped cast plates, a four-piece faceted mantlet with a genuinely hollow 0.205-tile-radius central bearing aperture, a supported angled roof/brow transition, and an optic head moved into the protected forward line of sight. Pass two adds two anchored trunnion pivot caps and guards, service fasteners, actual recoil housing brackets and cylinder collars, barrel-transition/heat-shroud rings, and a small calibrated elevation-travel index. All details have named protection, targeting, actuation or service functions; the reinforced 3×3 foundation, 22 sloped-wall mounts, eight lower buttress/foot sections, fixed magazines and rear-mounted co-traversing antenna are preserved. All new barrel, brow, socket, cheek and instrument meshes follow the actual turret traverse pivot.

**Observed defects corrected during real Blender inspection:** Initial workflow run failed because Trimesh's normal-repair path used SciPy but the runner did not have it; the existing single Blender job now installs SciPy. Second run caught the new mantlet/socket meshes lacking rotating-parent assignment at 15 degrees; the source and automated rotation check were corrected. Later actual Cycles closeups showed a solid black strip above the gun; ray-tested mesh intersections traced this to *two coplanar overlapping brows*, not a missing roof. Removed the redundant old brow, retained the properly fitted roof-to-mantlet transition, and added a regression check banning the obsolete duplicate. The final delivered closeup's previously black ROI has **zero** opaque black pixels (versus ~4,989 in the earlier failed visual candidate).

**Verified completion:** [GitHub Actions run 42164290455](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42164290455) **succeeded** after rerendering BOTH passes with native Blender, verifying source mesh volumes and open bore, checking group rotation every 15°, reimporting each Blender-exported GLB independently, and comparing front close-up renders. The final committed model contains **136 meshes in pass one, 152 in pass two**, with **47 and 63 co-rotating meshes**, respectively. The report verifies that the two closeups differ in 31,955 pixels above the specified threshold. Both editable `.blend` masters, their GLB exports, full source scripts, validation report and a three-stage/cropped turret gallery were committed to `main` by [`e0c4924949069708bae9ae20357768fb9fbea2f1`](https://github.com/mrcalzon02/Tech-Priests/commit/e0c4924949069708bae9ae20357768fb9fbea2f1). [View gallery](https://github.com/mrcalzon02/Tech-Priests/tree/main/art/source-to-3d/martian-bunker/gallery).

**Limits:** Correct geometry, assembly, color, render identity, pivot hierarchy and export integrity are demonstrated; this does *not* prove physical recoil animation, true ballistic performance, final high-frequency PBR finish, full swept-volume collision against every moving degree of freedom, or final in-game sprite approval. No gameplay prototypes, recipes or existing sprites were altered.

## 2026-11-06 — Fortified Martian turret v0.9 subtractive quality correction

**User-directed corrective work:** v0.8 over-produced decorative hard-surface meshes and treated part-count growth as detail. Built an actual v0.9 source geometry revision removing **55 mesh components (254 → 199)**, including surplus concentric band layers, ornamental cog/teeth, redundant periscope hood and optical bezels, unsupported barrel heat rails and muzzle ribs, redundant recoil collars, raised faux paint damage, and fake stencil geometry. The rounded cylindrical gun jacket, true open muzzle, structural mantlet bearing, six genuine shield bolts, fitted curved access hatch, seated operational optics, original visor, fixed rear services, antenna, 22 hull attachments, eight sloped corner/foot castings, and 3×3 base remain. Co-rotating objects reduced **165 → 110**. New regression explicitly fails if removed families reappear rather than rewarding extra objects.

**Verification evidence:** local rebuild, actual same-camera v0.8/v0.9 geometry render, roundness/bore checks, geometry attachment checks and PBR map generation passed. Native Blender 4.x run [42314299022](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42314299022) passed flat and textured scene builds, independently reopened both GLBs, tested co-rotation and verified the gallery. Generated Blender source — 23,150,305-byte packed-texture .blend — and 15,098,132-byte PBR GLB are published to main in [97b39caa](https://github.com/mrcalzon02/Tech-Priests/commit/97b39caa4a44ff6e706e8ee65cbb1fdf3699a49e). **First CI iteration failed only because Blender validation still expected a deleted crown rib; this was corrected and the second CI iteration succeeded.**

**Visual inspection still rejects final art quality:** the turret roof and armor silhouette remain too flat/basic relative to the user-provided high-detail visual reference; PBR paint damage is too uniformly noisy; sensor status glass is too bright and too large. Further work should address larger canonical shapes and purposeful texture painting, not increase the number of concentric tubes, rings, or decorative hardware. Native Factorio game-size/sprite quality and animation remain unapproved. No mod gameplay prototype or existing game sprite was modified.

## 2026-11-06 — Martian bunker v1.0: reference-locked elimination of invented muzzle and roof slab

**Direct owner correction:** The user-selected original turret image is the **mandatory geometry target**. V0.9 introduced a giant bulb-shaped heat-blue muzzle and a large raised rear upper turret roof access slab with four bolts that **do not occur in the target image**. Both are rejected as unauthorized speculation. The v1.0 source makes exactly two feature changes: re-profiles the existing `23_muzzle_reinforcement` to a slender hollow crown (outer radius **0.159 → 0.110** while retaining bore and barrel length), and **deletes** `87_roof_red_inspection_armor` and **four** attached roof bolts without replacement. There are **zero added objects**. A strict vertex/face comparison against the committed v0.9 source GLB proves that all **193 other surviving meshes are geometrically identical**. Total mesh count **199 → 194**, co-rotating objects **110 → 105**. The 3×3 foundation, 22 wall attachments, eight sloping buttress/foot objects, existing mechanical gun bearing, antenna, sensors, roof original geometry, and materials remain unchanged.

**Evidence:** [Source-to-reference three-way comparison](https://github.com/mrcalzon02/Tech-Priests/blob/main/art/source-to-3d/martian-bunker/gallery/v10_target_vs_v09_vs_v10.png), real source-mesh before/after close view, [editable textured Blender master](https://github.com/mrcalzon02/Tech-Priests/blob/main/art/source-to-3d/martian-bunker/src/v10/martian_heavy_weapon_bunker_v10_textured.blend), GLB and 69 original PBR maps. GitHub Actions [run 42316826089](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42316826089) **passed** Python source-geometry diff, Blender reconstruction, flat and textured Blender exports, independent GLB reimport, color/framing and render comparison. Native editable asset and final outputs committed to `main` at [`93931e37281cb52e9e35d0a62c5cb417ad27758e`](https://github.com/mrcalzon02/Tech-Priests/commit/93931e37281cb52e9e35d0a62c5cb417ad27758e). A reproducible v1.0 source ZIP contains the original generator, strict comparison test and actual GLB, not an AI-generated image.

**Mandatory next-process constraint:** Do not add any feature that is not visible in the owner-selected image unless separately and explicitly approved. For source-to-model fidelity work, identify the exact reference geometry and existing host, edit only that geometry, verify unchanged parts by vertex-level diff, and present an **actual model render** directly in chat before any acceptance. Decorative annuli, bolts, plates, lamps, inaccurate silhouettes, and procedural texture noise do not substitute for modeling what appears in the reference. **This pass fixes the two specific user-identified defects only.** The model still differs substantially in broader silhouette and high-frequency weathering and remains **NOT visually approved** as final Factorio art. Existing game sprites and prototypes were not changed.

## 2026-11-08 — Licensed priest sprite namespace load repair

`entity.lua` referenced an optional Mechanicus resource namespace unconditionally, matching the owner's missing-enabled-mod startup error. Five unchanged upstream MIT PNG sheets are now bundled in the local Tech-Priests namespace with authorship, official release checksum, per-file hashes and the full permission notice. Only the resource prefix/local variable changes in the entity definitions; unit/corpse animation parameters and behavior logic are preserved. The graphics-review preparer supports a physically absent dependency by default and the existing explicit coexistence option.

Native Factorio 2.1.24 graphics-only fixtures loaded both absent and enabled configurations with identical 10-unit/5-corpse graphic definitions. Eight requested headings, normal/belt-immune ranks, corpses and four boiler views were captured; displayed units were suppressed and no AI/work/attack commands or behavior assertions were issued. Evidence and the relevant resource-flow map are in [priest-sprite-import](art/priest-sprite-import/README.md). Source import/load evidence is not behavior/regression validation, final priest model approval, a packaged release or completion of the wider recovery/model milestones.

## 2026-11-08 — Boiler static cold-pose GLB inspection and numerical geometry/UV repairs

Added a separately editable cold-pose interchange branch and actual GLB, retaining the production animation source and all runtime boiler graphics. Independent raw GLB inspection exposed collapsed geometric triangles, ten UV-less fittings, collapsed manifold/chassis/fastener UVs and GLB quantization failures. The accepted branch removes only measured numerical slivers, adds fitting UVs and repairs unstable UV faces. All surviving triangle/material assignments and indexed source world vertices are verified. The actual GLB reopens with 264 meshes / 224,311 triangles, 13 embedded images / 29 materials; source and reimport position/UV tolerances, ground/bounds, outer flange planes and the fixed circuit mount pass. Existing four-direction sprite placement is preserved and reprojected from imported sockets.

Eight real local CPU source/GLB/clay images were inspected; compact failed audits and exact artifact/render hashes are retained. Portable build/audit/reimport/render commands and a source-to-export diagram are in [G5 evidence](art/boiler-v08-glb/README.md). This accepts static interchange only, not GLB animation, behavior/regression, a release or the wider completion goal. Existing A02 workers were not restarted; latest independently hashed checkpoint is 239/384 chunks.

## 2026-11-08 — Authored hydrogen thruster V01 model and graphics integration

Replaced the hydrogen source graphics through a late exact-target module, retaining original sheets for rollback. Added a packed editable 3D source, actual static GLB, source-faithful primary component groups, explicit socket necks/support feet and 18 authored PBR maps. Independent GLB reimport/UV/material/normal checks, actual flange/foot/contact inspection, 7+7 beauty/emission captures, 28 exact atlas-cell checks and registered geometry-shadow inspection pass. The bell's larger drawn extent expands only the visual culling box; all physical/nonvisual prototype fields and native cap definitions remain unchanged. Reimported GLB oblique/rear/clay images were viewed.

The actual tracked mod copy loads through the real late import in isolated Factorio 2.1.24. Native connected/disconnected caps, night glow and seven frozen working source-frame variants are reviewed. Sequential cold screenshots are explicitly not proof of working-clock progression; no propellant/thrust/behavior/regression assertions were run. Full evidence, reasoned review, resource-flow diagram, local commands and limits are in [hydrogen V01](art/hydrogen-thruster-v01/README.md). The normal user profile, release version and other assets remain untouched; other thruster bodies are not complete.


## 2026-11-13 � V24 condenser native alignment integration

Integrated the owner-accepted four-facing V24 96-frame Cycles condenser at HR .24 / SD .48 scale with measured per-facing shifts. The original 105 PNGs and 12-second animation are unchanged. Current-main Tech Priests and Tanks 1.8.103 ran together in the local Factorio 2.1.24 Steam client: 104 genuine PNGs, 20 connected pipes, real fuel-fed condenser water and pump water/full-output/landfill checks passed. Every production file in the isolated runtime matches the integrated source by SHA-256. Evidence: docs/art/local-machine-alignment/integrated-source-validation.json. The Beach Pump underwater-layer visual defect remains open. No release or general runtime-completion claim.

## 2026-11-14 - Requested automatic hostile planetary outposts

Implemented the owner's request for automatic enemy Tech-Priest seeding, particularly Fulgora and Vulcanus. Native ranged enemy units reuse Senior priest artwork; native unit-spawner outposts reuse cogitator artwork and recruit up to six local defenders. They use the existing enemy force and remain outside friendly station/pair task ownership.

The sole placement owner, scripts/core/enemy_planetary_seeding.lua, uses shared registry chunk-generation/chart events. One candidate per 8x8 chunk region on Fulgora/Vulcanus; one per 12x12 on Nauvis/Gleba. Placement requires valid terrain, 384 tiles from origin/force spawn, 96 tiles from player-force entities and 192 tiles from other outposts. Successful placements persist per surface/chunk, including after destruction. No forced terrain changes, friendly inventory grants, periodic scan or new scheduler. Peaceful surfaces and space platforms are excluded. The default-enabled runtime setting stops future placement when disabled. Existing saves receive placements through generation/chart events; no retroactive full-map sweep. Aquilo and modded planets are outside this first scope.

Validation: python tools/run_enemy_planetary_probe.py uses a disposable profile and Factorio 2.1.24 with Space Age, seed 4242. Native create/save and separate-process reload passed four-planet placement, duplicate/cleared-site protection, peaceful and occupied-site rejection, runtime disabling, actual chunk-generated delivery, native ranged damage and reinforcement recruitment over 2,200 ticks. Untouched native terrain accepted 17 of 48 Fulgora candidates and 48 of 48 Vulcanus candidates. Evidence: build/enemy-planets-probe/space-age-create.log and space-age-reload.log. A base-only exploratory load exposed an existing emergency-miner surface-condition requirement; no base-only compatibility claim is made. Installation, release packaging, publication, existing-user-save migration and long-run balance remain unclaimed.

Additional accepted proof: real on_chunk_charted delivery seeded previously generated terrain in a native --test-save player session. The runner uses --test-save/--test-ticks for loaded gameplay because benchmark mode does not process chart updates. Both native chunk generation and charting routes are now exercised without manufactured events.

## 2026-11-14 - Owner clarification: working enemy colonies replace combat nests

The owner clarified that seeding means clustered autonomous factories with the same bound station/priest behavior as friendly priests. This supersedes the combat-spawner design above. enemy_colony.lua seeds three standard stations (Magos, Senior, Intermediate) through the existing on_built lifecycle owner, uses the canonical independent/emergency operation authorization, and delegates all subsequent planning, paid construction, logistics, research and defense to normal runtime authorities. No alternate colony scheduler or recurring supplies are added.

Each initial cluster contains two stocked steel chests, two assemblers with starter ingredients, two fueled furnaces, two loaded turrets, a lab with finite starter science, solar panels, accumulators, poles, and four nine-tile ore deposits (iron/copper/coal/stone). One hostile research force per planet avoids exhausting Factorio's force limit. Colony forces ally with one another and native enemies; they are hostile to player forces. Candidate spacing is now 16x16 chunks on Fulgora/Vulcanus and 24x24 on Nauvis/Gleba to account for normal worker cost. Full footprints are collision-checked before initial placement; the seeder does not terraform. Native combat-spawner prototypes remain for compatibility but are no longer seeded.

The updated probe checks actual colony structures, all three original bound pairs, separate forces, ore patches, physical production statistics and native research progress after a separate-process load. Old combat-outpost test results do not establish the clarified colony behavior. No package or user installation has been changed.

Correction to the implementation note above: the unused combat-spawner prototype module was removed before packaging. Colonies now use only standard priest and station prototypes; no special enemy-worker type remains.

Colony initialization establishes the three introductory 2.1 trigger technologies (steam-power, electronics, automation-science-pack) as explicit starting knowledge for the already-built settlement, then queues Automation through LuaForce.add_research. It does not grant Automation or recurring research progress. Real lab packs and electricity pay research costs; later selection uses ordinary priest authorities. This is a finite initial settlement baseline, alongside its finite physical starter stock.

Clarified colony validation result: native Factorio 2.1.24 create/save and a separate --test-save session passed on all four planets. The 1,201-tick focused check confirms clustered seed contents, ordinary bound pairs after load, own-force item production and paid native research progress beyond the introductory seeded baseline. Full-structure power coverage was corrected during testing. An earlier 12,001-tick attempt exceeded the 180-second test timeout and is not accepted endurance evidence. Long-term colony growth, completed construction/research chains and natural-terrain colony-fit frequency remain separate validation work; the prior single-spawner terrain counts do not apply to the larger colony footprint. No installed mod or user gameplay save changed.

## 2026-11-14 - Runtime controls for integrated enemy colonies

Added runtime-global options for allowed planet names (blank disables new seeding), global/per-planet priest binding caps, global/per-planet active seeded colony caps, Fulgora/Vulcanus and other-planet spacing, spawn/base/colony clearance distances, starter stock multiplier, per-tile starter ore and peaceful-mode respect. Defaults retain the four initial planets, 16/24 chunk spacing, 384/96/192 tile clearances, 1x supplies and 1500 ore per tile; new population defaults are 96 priests globally / 24 per planet and 24 colonies globally / 6 per planet. Population and colony limit value 0 means unlimited.

The read-only enemy_colony_options module is shared by the existing seeder and canonical create_pair owner. Admission checks include normal enemy expansion, not just initial groups of three. Existing valid bound stations reserve their priest slots during recovery; friendly forces and existing-pair recovery remain unaffected. Reducing a limit does not cull priests, delete factories, withdraw research or rewrite inventory. Stations built at capacity remain unbound while capacity is unavailable. Active colony slots count while an original station survives; destroyed sites remain recorded. Supply, ore, planet and spacing controls apply to future seeding; there is no automatic whole-map reseed or retroactive resource grant.

The focused native fixture exercises empty allowed-planets, global and per-planet seed admission, global and per-planet colony admission, actual canonical new-pair rejection at capacity and zero-as-unlimited behavior on all four planets. Source settings load through Factorio 2.1.24; native production/research and separate-process persistence remain part of the same focused scenario. No new tick handler, movement authority, inventory owner or independent population controller was added.

Validation accepted: Factorio 2.1.24 loaded all new setting prototypes, passed all four planets' admission/canonical expansion-cap checks, and retained normal own-force production, paid research and bound pairs in the separate 1,201-tick loaded session. Evidence: local-validation/integration-staging/colony-default/space-age-create.log and space-age-reload.log in the workspace. General endurance and non-default terrain/supply balance are not claimed.

## 2026-11-14 - Enemy research noospheric chat intercepts

Added a default-on Map setting, Enemy research intercepts in chat, with Off / All technologies / Major discoveries only. Eight localized Martian Gothic transmissions name the renegade planetary synod and the completed technology (including its icon). Major discoveries include automation tiers, new science packs, planet discoveries and selected named military/energy/space advances. Only connected players hostile to the completing colony force receive the message; friendly research, allied/cease-fire recipients and scripted starter research grants are excluded.

The enemy_research_announcements module subscribes once, by stable owner/route, to the shared on_research_finished event. It is read-only and adds no tick loop, timer, persisted backlog, research mutation or gameplay RNG consumption. Normal save/reload does not replay old completions. Each genuine engine completion is eligible for a transmission, including repeated technology levels.

Validation accepted: native Factorio 2.1.24 settings/load and a separate 601-tick real-player test-save session passed off/all/milestone filters, scripted-grant silence, friendly-force exclusion, recipient friendship/cease-fire exclusion and exactly one actual powered-lab Automation completion event. The observer-only test begins at 0.999 research progress to shorten execution; the final completion is engine-driven, not a fabricated event. This does not claim a full from-zero research chain. Reproduce with python tools/run_enemy_planetary_probe.py --research-intercepts; no test fixture is part of the installed mod.

## 2026-11-14 - Real colony research and construction verified from zero

Added a reproducible full-research native fixture and hash-bound, unedited evidence under tests/evidence/enemy-research-from-zero. The installed ordinary colony implementation completed Automation from exactly zero progress at tick 6647, through a real powered lab using its finite initial science stock. The ordinary research-finished event generated an eligible noospheric intercept. By tick 12000 the three normal bound priests had built two new physical structures. Player research was unchanged. No forced progress/completion, fabricated research event, direct worker command or recurring supply was used. The disposable Vulcanus terrain pad was cleared; its normal power/day cycle remained active.

Reproduce with python tools/run_enemy_planetary_probe.py --full-research. Evidence is from source b2d3a867e95959e9eb0de92b837cfbcac873e01c, Factorio 2.1.24 and seed 4242. This verifies a complete initial paid cycle, not just the earlier accelerated notification observer. Native science production remained zero during this run; sustained science production, longer research chains and indefinite colony self-sufficiency remain unverified. No gameplay change was necessary for the demonstrated capability. An optional starting-inventory redistribution comparison was not promoted; normal colony starting inventories remain unchanged.


## 2026-11-14 — Bunker stanchion ownership masks and twin-cannon runtime pilot

Recovered the original four corner-buttress meshes and rendered calibrated depth-occluded coverage. Registered neutral force-tinted stanchion masks on the shared bunker foundation. Actual Factorio graphical evidence shows all six bunker weapons across four forces/base orientations; red armour and concrete are unchanged. Hash-bound evidence: docs/prototypes/bunker-team-colour-assets.json. Earlier render delivery masks had not been wired into the prototypes.

The twin cannon now has a real animated two-heading runtime pilot: four native ammunition types, strict independent shot-driven recoil/settle states, separate depth-occluded flexible aerials, actual static cap shadows, and a visible native inventory preview. Physics tests cover 36 sites and unarmed traverse-driven aerial flex. A user-requested 0.08-tile flash lead is confirmed by before/after native pixel movement; projectile launch points are unchanged. Full 64-direction body/aerial capture and final package verification remain in progress. No full-goal completion, release-version change or remote publication is claimed. See docs/prototypes/twin-cannon-progress.md.


## 2026-11-15 — Six bunker weapons integrated into Tech Priests main

Registered the lobber, energy dish, Chicago piano, twin minigun and completed
twin siege cannon alongside the existing autocannon in the actual main mod.
Finalization runs before the existing recipe-schema sanitizer. Weapon callbacks
use the canonical runtime event registry; all 180 pre-existing event routes are
preserved. Added the original cannon source/GLB and all runtime atlases, native
preview cores, icons, recipe/technology and shared force-coloured stanchions.

The full 0.1.681 Tech Priests source, based on ab7e878, passed Factorio 2.1.24
headless, graphical and separate-process mid-fire reload tests with official
Space Age/Quality/Elevated Rails/Recycler enabled: 32 cannon sites, four native
shell types, all 64 headings, research, ammo exhaustion and all five older
weapon regressions. Final native flash lead is 0.16 tile with facing-dependent
depth; projectile origins remain unchanged. Main evidence is retained under
docs/prototypes/twin-cannon-main-evidence. The earlier two-heading pilot entry
is historical and superseded by these full-direction results.

This is source integration, not a new full-mod release/version bump or a claim
about unrelated priest logistics gates. Rocket, artillery, radium, grav, plasma
and flamer weapon families remain unbuilt. Publication is verified separately
against the resulting GitHub main commit.
